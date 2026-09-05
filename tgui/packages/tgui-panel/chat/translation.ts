/**
 * @file
 * Client side half of auto-translation.
 *
 * DM shows the message in its original language immediately, marks it as
 * awaiting translation, and sends exactly one `internal/translation` chat
 * payload once the backend answers. Everything here is presentation: finding
 * the line, clearing the pending affordances, and animating the text across.
 *
 * The animation is done here rather than streamed from DM on purpose - a
 * dozen frames per message per client is real traffic for something the
 * browser can do on its own. Runechat has no such option and animates server
 * side; the timings are kept in sync via the `duration` field.
 *
 * See voidcrew/modules/autotranslate/ for the DM side.
 */

import { createLogger } from 'tgui/logging';
import { chatRenderer } from './renderer';
import { highlightNode, linkifyNode } from './replaceInTextNode';

const logger = createLogger('translation');

type TranslationPayload = {
  id: string;
  status: string;
  original?: string | null;
  text?: string | null;
  duration?: number | null;
  scramble?: number | null;
};

/**
 * Validates one incoming payload. Hand-rolled rather than a schema library
 * so tgui-panel picks up no new dependency for one message type.
 * Returns null (and logs) on anything malformed.
 */
function parsePayload(raw: unknown): TranslationPayload | null {
  let value: any = raw;
  if (typeof value === 'string') {
    value = JSON.parse(value);
  }
  if (typeof value !== 'object' || value === null) {
    return null;
  }
  if (typeof value.id !== 'string' || typeof value.status !== 'string') {
    return null;
  }
  const optionalString = (field: unknown) =>
    field === undefined || field === null || typeof field === 'string';
  const optionalNumber = (field: unknown) =>
    field === undefined || field === null || typeof field === 'number';
  if (!optionalString(value.original) || !optionalString(value.text)) {
    return null;
  }
  if (!optionalNumber(value.duration) || !optionalNumber(value.scramble)) {
    return null;
  }
  return value as TranslationPayload;
}

const DEFAULT_DURATION = 500;
const DEFAULT_SCRAMBLE = 3;

/**
 * Characters used for the churning band that rides ahead of the reveal point.
 * ASCII only, matching the DM side - the source text supplies the Cyrillic.
 */
const SCRAMBLE_POOL = Array.from(
  'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789#%*=~',
);

/** How far back through message history to look for a detached node. */
const DETACHED_SEARCH_DEPTH = 60;

/**
 * Translations whose chat line has not been rendered yet.
 *
 * Notices now ride SSchat alongside the chat lines themselves, so they are
 * delivered in sequence and should never arrive first. This is kept as a
 * safety net rather than load-bearing machinery: anything that cannot be
 * placed is held and retried when the next batch renders.
 */
const orphanedTranslations = new Map<
  string,
  { payload: TranslationPayload; stashedAt: number }
>();

/** Cap so a stream of unmatched ids cannot grow this without bound. */
const MAX_ORPHANS = 250;

/** Give up on an orphan whose line never showed up. */
const ORPHAN_TTL = 30000;

function stashOrphan(payload: TranslationPayload): void {
  if (orphanedTranslations.size >= MAX_ORPHANS) {
    // Map preserves insertion order, so this drops the oldest.
    const oldest = orphanedTranslations.keys().next();
    if (!oldest.done) {
      orphanedTranslations.delete(oldest.value);
    }
  }
  orphanedTranslations.set(payload.id, {
    payload,
    stashedAt: Date.now(),
  });
}

/**
 * Retries any held translations after a batch of chat messages is rendered.
 *
 * Subscribing to the renderer's own event rather than having the renderer
 * call into here keeps the dependency one-directional - renderer.jsx knows
 * nothing about translation, and there is no import cycle. Same pattern as
 * chat/helpers.ts.
 */
function flushOrphans(): void {
  if (!orphanedTranslations.size) {
    return;
  }
  const now = Date.now();
  for (const [id, entry] of Array.from(orphanedTranslations.entries())) {
    if (now - entry.stashedAt > ORPHAN_TTL) {
      orphanedTranslations.delete(id);
      continue;
    }
    const targets = findTargets(id);
    if (!targets) {
      continue;
    }
    orphanedTranslations.delete(id);
    applyTranslation(targets.text, targets.pending, entry.payload);
  }
}

chatRenderer.events.on('batchProcessed', flushOrphans);

/**
 * Translation notices arrive as chat payloads rather than on their own tgui
 * channel, because the raw window channel drops messages - that is why SSchat
 * carries sequence numbers and a resend protocol at all. The renderer
 * recognises the internal/translation type and re-emits it here.
 */
chatRenderer.events.on('translation', (payload) => chatTranslation(payload));

/**
 * When this module was evaluated.
 *
 * Used to tell lines rendered this session apart from ones the panel restored
 * out of browser storage - see retireRestoredLines().
 */
const moduleLoadedAt = Date.now();

/** How often the stuck-pending watchdog runs. */
const WATCHDOG_INTERVAL = 2000;

/**
 * How long a line may sit pending before it is called a failure.
 *
 * The server gives up on a request after 8s (TRANSLATION_REQUEST_TIMEOUT),
 * so anything past this means the notice is not coming at all - the client
 * dropped, the panel was reloaded mid-flight, or the handle was destroyed
 * before it could report. Without this those lines animate their dots
 * forever.
 */
const PENDING_TIMEOUT = 15000;

/**
 * Retires pending lines that came back from browser storage.
 *
 * Their round is over, so no translation is ever arriving for them. Left
 * alone they animate forever and, worse, keep their ids available to collide
 * with a fresh message after a server restart.
 *
 * A node is from a previous session if the watchdog already stamped it -
 * data-tsl-seen is written into the html that gets persisted, so anything
 * stamped before this module loaded is history.
 */
function retireRestoredLines(): void {
  const nodes = document.querySelectorAll<HTMLElement>('[data-tsl-id]');
  for (let i = 0; i < nodes.length; i++) {
    const text = nodes[i];
    const seen = Number(text.dataset.tslSeen ?? 0);
    if (!seen || seen >= moduleLoadedAt) {
      continue;
    }
    const id = text.getAttribute('data-tsl-id');
    markFailed(
      text,
      findPendingMarker(text, id),
      'No translation arrived - message restored from an earlier session',
      'timeout',
    );
  }
}

let restoredSweepDone = false;

function sweepStalePending(): void {
  if (!restoredSweepDone) {
    restoredSweepDone = true;
    retireRestoredLines();
  }

  flushOrphans();

  const now = Date.now();
  const nodes = document.querySelectorAll<HTMLElement>('.tsl-pending-text');
  if (!nodes.length) {
    return;
  }

  for (let i = 0; i < nodes.length; i++) {
    const text = nodes[i];
    const seen = Number(text.dataset.tslSeen ?? 0);
    if (!seen) {
      // First sighting. The render time is unknown to us, so start the clock
      // here - worst case that adds one interval to the timeout.
      text.dataset.tslSeen = String(now);
      continue;
    }
    if (now - seen < PENDING_TIMEOUT) {
      continue;
    }
    const id = text.getAttribute('data-tsl-id');
    const pending = findPendingMarker(text, id);
    markFailed(
      text,
      pending,
      'No translation arrived in time - showing the original',
      'timeout',
    );
  }
}

setInterval(sweepStalePending, WATCHDOG_INTERVAL);

/**
 * Locates the span carrying this translation id.
 *
 * The fast path is a document query, which covers any line on the visible
 * page. If the player has switched to a tab that does not accept localchat
 * the node is detached from the document but still referenced by the
 * renderer, so fall back to a bounded walk of recent messages rather than
 * scanning all 2500.
 */
function findTargets(id: string): {
  text: HTMLElement;
  pending: HTMLElement | null;
} | null {
  // Ids are generated server side as "tsl-<boot token>-<counter>", so there
  // is nothing to escape. Calling CSS.escape here would only add a dependency
  // on an API that not every embedded browser ships.
  const selector = `[data-tsl-id="${id}"]`;
  const pendingSelector = `[data-tsl-for="${id}"]`;

  const attached = document.querySelector<HTMLElement>(selector);
  if (attached) {
    return {
      text: attached,
      pending: findPendingMarker(attached, id),
    };
  }

  const messages = chatRenderer.messages;
  const start = Math.max(0, messages.length - DETACHED_SEARCH_DEPTH);
  for (let i = messages.length - 1; i >= start; i--) {
    const node: HTMLElement | undefined = messages[i]?.node;
    if (!node?.querySelector) {
      continue;
    }
    const found = node.querySelector<HTMLElement>(selector);
    if (found) {
      return {
        text: found,
        pending: node.querySelector<HTMLElement>(pendingSelector),
      };
    }
  }

  return null;
}

/**
 * Finds the dots/marker span belonging to a text span.
 *
 * The id lookup is the normal route, but it must not be the only one: if it
 * misses, the dots keep animating on a line that has already given up, which
 * is the worst possible state - the tooltip says it timed out while the
 * animation insists it is still working. DM always emits the marker as the
 * immediate next sibling, so fall back to that.
 */
function findPendingMarker(
  text: HTMLElement,
  id: string | null,
): HTMLElement | null {
  if (id) {
    const byId = document.querySelector<HTMLElement>(`[data-tsl-for="${id}"]`);
    if (byId) {
      return byId;
    }
  }
  const sibling = text.nextElementSibling as HTMLElement | null;
  if (
    sibling &&
    (sibling.hasAttribute('data-tsl-for') ||
      sibling.classList.contains('tsl-pending'))
  ) {
    return sibling;
  }
  return null;
}

/** Drops the underline, the tooltip and the animated dots. */
function clearPendingState(
  text: HTMLElement,
  pending: HTMLElement | null,
): void {
  text.classList.remove('tsl-pending-text');
  text.removeAttribute('title');
  delete text.dataset.tslSeen;
  retireIds(text, pending);
  pending?.remove();
}

/**
 * Marks a line as never going to be translated.
 *
 * Silently dropping back to the original would be indistinguishable from a
 * line that was never up for translation, so failures get their own marker -
 * the player can tell the difference between "this is what they said" and
 * "this is what they said, untranslated, because something broke".
 */
function markFailed(
  text: HTMLElement,
  pending: HTMLElement | null,
  reason: string,
  kind: 'failed' | 'timeout',
): void {
  text.classList.remove('tsl-pending-text');
  text.classList.add(kind === 'timeout' ? 'tsl-timeout' : 'tsl-failed');
  text.setAttribute('title', reason);
  delete text.dataset.tslSeen;

  if (pending) {
    // Reuse the dots node as the marker so the line does not reflow.
    // Dropping tsl-pending is what stops the dots animating - a line that has
    // given up must not keep advertising that it is still working.
    pending.classList.remove('tsl-pending');
    pending.classList.add(
      kind === 'timeout' ? 'tsl-timeout-marker' : 'tsl-failed-marker',
    );
    pending.setAttribute('title', reason);
  }

  retireIds(text, pending);
}

/**
 * Makes a finished line permanently untargetable.
 *
 * Chat is persisted to browser storage and restored next session, ids and
 * all, while the server's counter restarts from zero. Leaving the attributes
 * in place means a future "tsl-...-1" can match a corpse from a previous
 * round - which is exactly the bug this comment exists because of. A line
 * that is done must never be found again.
 */
function retireIds(text: HTMLElement, pending: HTMLElement | null): void {
  text.removeAttribute('data-tsl-id');
  pending?.removeAttribute('data-tsl-for');
}

/**
 * Builds a single frame of the morph.
 *
 * Mirrors build_frame() in text_morph.dm so both surfaces animate the same
 * way: length interpolates between the two strings, characters resolve left
 * to right, and a short scrambled band rides ahead of the reveal point.
 */
function buildFrame(
  from: string[],
  to: string[],
  progress: number,
  scramble: number,
): string {
  if (progress <= 0) {
    return from.join('');
  }
  if (progress >= 1) {
    return to.join('');
  }

  const frameLength = Math.max(
    1,
    Math.round(from.length + (to.length - from.length) * progress),
  );
  const revealed = to.length * progress;
  const out: string[] = [];

  for (let i = 1; i <= frameLength; i++) {
    if (i <= revealed && i <= to.length) {
      out.push(to[i - 1]);
    } else if (i <= revealed + scramble) {
      out.push(SCRAMBLE_POOL[Math.floor(Math.random() * SCRAMBLE_POOL.length)]);
    } else if (i <= from.length) {
      out.push(from[i - 1]);
    } else {
      out.push(SCRAMBLE_POOL[Math.floor(Math.random() * SCRAMBLE_POOL.length)]);
    }
  }

  return out.join('');
}

/**
 * Re-runs the player's text highlights over the settled translation.
 *
 * The original highlight spans are destroyed by the morph, which is correct -
 * they matched Russian text that is no longer there. But a highlight for
 * "sec" should fire on the English the player now sees, so the parsers get
 * another pass once the text stops moving.
 */
function reapplyHighlights(node: HTMLElement): void {
  const parsers = chatRenderer.highlightParsers;
  if (!parsers) {
    return;
  }
  for (const parser of parsers) {
    if (!parser.enabled) {
      continue;
    }
    highlightNode(
      node,
      parser.highlightRegex,
      parser.highlightWords,
      (text: string) => {
        const span = document.createElement('span');
        span.className = 'Chat__highlight';
        span.setAttribute(
          'style',
          `--highlight-color:${parser.highlightColor}`,
        );
        span.textContent = text;
        return span;
      },
    );
  }
}

/** Restore clickable OOC URLs after the morph replaces the original nodes. */
function reapplyFormatting(node: HTMLElement): void {
  reapplyHighlights(node);
  if (node.closest('.linkify')) {
    linkifyNode(node);
  }
}

/**
 * Animates one line from its original text to its translation.
 *
 * Any markup inside the span (emphasis, existing highlights) is replaced by
 * plain text. That is deliberate: the translation is different text, so
 * emphasis positions from the original are meaningless.
 */
function morph(node: HTMLElement, payload: TranslationPayload): void {
  // Take the rendered text, not payload.original: the server sends its copy
  // still html-encoded, so that one would put literal &#34; in the tooltip.
  // The browser has already decoded what is in the DOM.
  const originalText = node.textContent ?? payload.original ?? '';

  // Array.from splits by code point, so Cyrillic and anything astral survive.
  const from = Array.from(originalText);
  const to = Array.from(payload.text ?? '');
  const duration = payload.duration ?? DEFAULT_DURATION;
  const scramble = payload.scramble ?? DEFAULT_SCRAMBLE;

  if (!to.length) {
    return;
  }

  // Nothing to animate between - just settle.
  if (!from.length || duration <= 0) {
    node.textContent = to.join('');
    reapplyFormatting(node);
    return;
  }

  node.classList.add('tsl-morphing');
  const started = performance.now();

  const step = (now: number) => {
    // The node can be pruned out from under us mid-animation.
    if (!node.isConnected && !node.parentNode) {
      return;
    }
    const progress = Math.min(1, (now - started) / duration);
    node.textContent = buildFrame(from, to, progress, scramble);
    if (progress < 1) {
      requestAnimationFrame(step);
      return;
    }
    node.classList.remove('tsl-morphing');
    node.classList.add('tsl-translated');
    // Hovering a translated line shows what was actually said. Only mark it
    // as hoverable if there is genuinely something to show, otherwise the
    // help cursor promises a tooltip that never appears.
    if (originalText) {
      node.setAttribute('title', originalText);
    } else {
      node.removeAttribute('title');
      node.classList.add('tsl-no-tooltip');
    }
    reapplyFormatting(node);
  };

  requestAnimationFrame(step);
}

/** Clears the pending affordances and, on success, runs the morph. */
function applyTranslation(
  text: HTMLElement,
  pending: HTMLElement | null,
  payload: TranslationPayload,
): void {
  if (payload.status !== 'done' || !payload.text) {
    // Backend errored or gave up. Say so rather than silently reverting to a
    // line that looks like it was never eligible for translation.
    markFailed(
      text,
      pending,
      'Translation failed - showing the original',
      'failed',
    );
    return;
  }

  clearPendingState(text, pending);
  morph(text, payload);
}

/** Entry point - fed by the renderer's `translation` event above. */
export function chatTranslation(rawPayload: unknown): void {
  let payload: TranslationPayload | null;
  try {
    payload = parsePayload(rawPayload);
  } catch (err) {
    payload = null;
  }
  if (!payload) {
    logger.error('bad payload', rawPayload);
    return;
  }

  const targets = findTargets(payload.id);
  if (!targets) {
    // The line has not been rendered yet - a cache hit on the server beats
    // its own chat message down the wire. Hold it for the renderer.
    logger.debug('no target yet for', payload.id, '- stashing');
    stashOrphan(payload);
    return;
  }

  logger.debug('applying', payload.id, payload.status);
  applyTranslation(targets.text, targets.pending, payload);
}
