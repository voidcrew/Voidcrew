/**
 * UI test harness, page side (dev builds only).
 *
 * Servers built with -DUI_HARNESS (voidcrew/modules/ui_harness) can send this window
 * "harness/run" messages so local tools can click, type and read the page without
 * the real mouse or keyboard. It fires ordinary DOM events, so the interface's own
 * handlers run, and answers with a "harness/result" message.
 *
 * It does nothing until the server sends "harness/enable", which only harness
 * builds ever do.
 */

type Store = { getState: () => any };
type Args = Record<string, string | undefined>;

const MAX_TEXT = 4000;
const MAX_SETTLE_MS = 5000;

// Topic links get cut off past ~2 KB, so replies go back in pieces like tgui's own oversized payloads.
const CHUNK_BUDGET = 900;

let enabled = false;

const sendChunked = (id: string, json: string) => {
  const chunks: string[] = [];
  let current = '';
  let cost = 0;
  for (const char of json) {
    const charCost = encodeURIComponent(JSON.stringify(char)).length - 6;
    if (cost + charCost > CHUNK_BUDGET && current) {
      chunks.push(current);
      current = '';
      cost = 0;
    }
    current += char;
    cost += charCost;
  }
  chunks.push(current);
  chunks.forEach((chunk, part) =>
    Byond.sendMessage('harness/result', {
      id,
      part: part + 1,
      parts: chunks.length,
      chunk,
    }),
  );
};

const KEY_CODES: Record<string, number> = {
  Backspace: 8,
  Tab: 9,
  Enter: 13,
  Shift: 16,
  Control: 17,
  Alt: 18,
  Escape: 27,
  ' ': 32,
  PageUp: 33,
  PageDown: 34,
  End: 35,
  Home: 36,
  ArrowLeft: 37,
  ArrowUp: 38,
  ArrowRight: 39,
  ArrowDown: 40,
  Delete: 46,
};

const squash = (text: string | null | undefined) =>
  (text || '').replace(/\s+/g, ' ').trim();

const isVisible = (el: Element) => {
  const rect = el.getBoundingClientRect();
  if (rect.width <= 0 || rect.height <= 0) {
    return false;
  }
  const style = window.getComputedStyle(el);
  return style.visibility !== 'hidden' && style.display !== 'none';
};

const describe = (el: Element | null) => {
  if (!el) {
    return null;
  }
  const rect = el.getBoundingClientRect();
  return {
    tag: el.tagName.toLowerCase(),
    id: el.id || undefined,
    className: String(el.className || '').slice(0, 120) || undefined,
    text: squash((el as HTMLElement).innerText).slice(0, 120),
    value: (el as HTMLInputElement).value,
    rect: [rect.left, rect.top, rect.width, rect.height].map(Math.round),
  };
};

/** Visible elements whose text matches, innermost only, in document order. */
const findByText = (text: string, exact: boolean) => {
  const want = squash(text).toLowerCase();
  const matches = (el: Element) => {
    const have = squash((el as HTMLElement).innerText).toLowerCase();
    return exact ? have === want : have.includes(want);
  };
  const hits = Array.from(document.body.querySelectorAll('*')).filter(
    (el) => isVisible(el) && matches(el),
  );
  return hits.filter((el) => !hits.some((o) => o !== el && el.contains(o)));
};

/** Resolves the element a command acts on, from selector, text or point. */
const findTarget = (args: Args): Element | null => {
  const nth = Number(args.nth || 0);
  if (args.x !== undefined && args.y !== undefined) {
    return document.elementFromPoint(Number(args.x), Number(args.y));
  }
  let list: Element[] = [];
  if (args.selector) {
    list = Array.from(document.querySelectorAll(args.selector)).filter(
      isVisible,
    );
  } else if (args.text !== undefined) {
    list = findByText(args.text, args.exact !== '0');
  } else if (args.placeholder) {
    list = Array.from(
      document.querySelectorAll(
        `[placeholder*="${CSS.escape(args.placeholder)}"]`,
      ),
    ).filter(isVisible);
  } else {
    return null;
  }
  return list[nth] || null;
};

const centerOf = (el: Element) => {
  const rect = el.getBoundingClientRect();
  return { x: rect.left + rect.width / 2, y: rect.top + rect.height / 2 };
};

const mouse = (
  target: Element,
  type: string,
  x: number,
  y: number,
  buttons: number,
) => {
  const init = {
    bubbles: true,
    cancelable: true,
    composed: true,
    view: window,
    clientX: x,
    clientY: y,
    button: 0,
    buttons,
  };
  const event = type.startsWith('pointer')
    ? new PointerEvent(type, {
        ...init,
        pointerId: 1,
        pointerType: 'mouse',
        isPrimary: true,
      })
    : new MouseEvent(type, init);
  target.dispatchEvent(event);
};

/** Clicks the topmost element at the target's centre, as a real click would. */
const click = (args: Args) => {
  const found = findTarget(args);
  if (!found) {
    throw new Error('nothing matched');
  }
  found.scrollIntoView?.({ block: 'nearest' });
  const point =
    args.x !== undefined
      ? { x: Number(args.x), y: Number(args.y) }
      : centerOf(found);
  const hit = document.elementFromPoint(point.x, point.y) || found;
  mouse(hit, 'pointerover', point.x, point.y, 0);
  mouse(hit, 'mouseover', point.x, point.y, 0);
  mouse(hit, 'pointerdown', point.x, point.y, 1);
  mouse(hit, 'mousedown', point.x, point.y, 1);
  if (hit instanceof HTMLElement) {
    hit.focus({ preventScroll: true });
  }
  mouse(hit, 'pointerup', point.x, point.y, 0);
  mouse(hit, 'mouseup', point.x, point.y, 0);
  mouse(hit, 'click', point.x, point.y, 0);
  if (args.double === '1') {
    mouse(hit, 'dblclick', point.x, point.y, 0);
  }
  return { matched: describe(found), hit: describe(hit) };
};

const keyCodeOf = (key: string) =>
  KEY_CODES[key] ?? (key.length === 1 ? key.toUpperCase().charCodeAt(0) : 0);

const pressKey = (target: Element, key: string) => {
  const keyCode = keyCodeOf(key);
  const init = {
    key,
    code: key.length === 1 ? `Key${key.toUpperCase()}` : key,
    keyCode,
    which: keyCode,
    bubbles: true,
    cancelable: true,
    composed: true,
    view: window,
  };
  target.dispatchEvent(new KeyboardEvent('keydown', init));
  if (key.length === 1) {
    target.dispatchEvent(new KeyboardEvent('keypress', init));
  }
  target.dispatchEvent(new KeyboardEvent('keyup', init));
};

const key = (args: Args) => {
  if (!args.key) {
    throw new Error('key= is required');
  }
  const target =
    (args.selector || args.text !== undefined || args.placeholder
      ? findTarget(args)
      : document.activeElement) || document.body;
  pressKey(target, args.key);
  return { hit: describe(target) };
};

/** Sets an input's value the way typing does, so React's onChange/onInput run. */
const type = (args: Args) => {
  const target = (
    args.selector || args.text !== undefined || args.placeholder
      ? findTarget(args)
      : document.activeElement
  ) as HTMLInputElement | HTMLTextAreaElement | null;
  if (
    !(
      target instanceof HTMLInputElement ||
      target instanceof HTMLTextAreaElement
    )
  ) {
    throw new Error(`not a text field: ${JSON.stringify(describe(target))}`);
  }
  target.focus({ preventScroll: true });
  const text = args.value ?? '';
  const next = args.append === '1' ? target.value + text : text;
  const setter = Object.getOwnPropertyDescriptor(
    Object.getPrototypeOf(target),
    'value',
  )?.set;
  setter?.call(target, next);
  target.dispatchEvent(
    new InputEvent('input', {
      bubbles: true,
      data: text,
      inputType: 'insertText',
    }),
  );
  target.dispatchEvent(new Event('change', { bubbles: true }));
  if (args.enter === '1') {
    pressKey(target, 'Enter');
  }
  if (args.blur === '1') {
    target.blur();
  }
  // A background window gets no real focus events, so inputs that commit on blur would never commit.
  if ((args.enter === '1' || args.blur === '1') && !document.hasFocus()) {
    target.dispatchEvent(new FocusEvent('blur'));
    target.dispatchEvent(new FocusEvent('focusout', { bubbles: true }));
  }
  return { hit: describe(target) };
};

const canScroll = (el: Element) =>
  el.scrollHeight > el.clientHeight + 1 &&
  /auto|scroll/.test(window.getComputedStyle(el).overflowY);

/** Scrolls the nearest scrollable box around the target, or the biggest one on the page. */
const scroll = (args: Args) => {
  let el: Element | null = findTarget(args);
  while (el && !canScroll(el)) {
    el = el.parentElement;
  }
  if (!el) {
    const boxes = Array.from(document.body.querySelectorAll('*')).filter(
      (box) => isVisible(box) && canScroll(box),
    );
    const area = (box: Element) => box.clientWidth * box.clientHeight;
    el = boxes.sort((a, b) => area(b) - area(a))[0] || null;
  }
  if (!el) {
    throw new Error('nothing scrollable');
  }
  if (args.to === 'top') {
    el.scrollTop = 0;
  } else if (args.to === 'bottom') {
    el.scrollTop = el.scrollHeight;
  } else {
    el.scrollTop += Number(args.by || 300);
  }
  el.dispatchEvent(new Event('scroll', { bubbles: true }));
  return { hit: describe(el), scrollTop: el.scrollTop };
};

const summary = (store: Store, args: Args, full: boolean) => {
  const config = store.getState()?.backend?.config || {};
  const limit = Math.min(Number(args.limit || 1500), MAX_TEXT);
  const out: Record<string, unknown> = {
    windowId: Byond.windowId,
    interface: config.interface?.name,
    title: config.title,
    activeTabs: Array.from(document.querySelectorAll('.Tab--selected'))
      .filter(isVisible)
      .map((el) => squash((el as HTMLElement).innerText)),
    focused: describe(document.activeElement),
    text: squash(document.body.innerText).slice(0, limit),
  };
  if (full) {
    out.url = window.location.href;
    out.size = [window.innerWidth, window.innerHeight];
    out.buttons = Array.from(document.querySelectorAll('.Button'))
      .filter(isVisible)
      .map((el) => squash((el as HTMLElement).innerText))
      .filter((text) => text)
      .slice(0, 80);
    out.inputs = Array.from(document.querySelectorAll('input, textarea'))
      .filter(isVisible)
      .map(describe)
      .slice(0, 20);
  }
  return out;
};

const ACTIONS: Record<string, (args: Args) => unknown> = {
  click,
  key,
  type,
  scroll,
  query: () => ({}),
};

const run = (store: Store, payload: any) => {
  const id = payload?.id;
  const op = String(payload?.op || '');
  const args: Args = payload?.args || {};
  const reply = (body: Record<string, unknown>) =>
    sendChunked(id, JSON.stringify({ id, op, ...body }));
  const action = ACTIONS[op];
  if (!action) {
    reply({ ok: false, error: `unknown op ${op}` });
    return;
  }
  let result: unknown;
  try {
    result = action(args);
  } catch (err) {
    reply({
      ok: false,
      error: String((err as Error)?.message || err),
      page: summary(store, args, true),
    });
    return;
  }
  // Give the interface time to re-render (and the server time to answer an act) before reading it back.
  const settle = Math.min(
    Number(args.settle ?? (op === 'query' ? 0 : 400)),
    MAX_SETTLE_MS,
  );
  setTimeout(() => {
    try {
      reply({ ok: true, result, page: summary(store, args, op === 'query') });
    } catch (err) {
      reply({ ok: false, error: String((err as Error)?.message || err) });
    }
  }, settle);
};

export const setupUiHarness = (store: Store) => {
  Byond.subscribe((type, payload) => {
    if (type === 'harness/enable') {
      enabled = true;
      return;
    }
    if (type === 'harness/run' && enabled) {
      run(store, payload);
    }
  });
};
