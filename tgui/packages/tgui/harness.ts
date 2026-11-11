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

// ---------------------------------------------------------------------------------------------
// layout: finds text that runs out of its box, crosses a frame line, is cut off, or overlaps other
// text. It works on glyph boxes (a Range over each text node, whitespace trimmed), so absolutely
// placed text grids (the lobby terminal) and ordinary flow layouts are checked the same way.
// ---------------------------------------------------------------------------------------------

type Box = { l: number; t: number; r: number; b: number };

const MAX_FINDINGS = 60;

const boxOf = (r: DOMRect): Box => ({
  l: r.left,
  t: r.top,
  r: r.right,
  b: r.bottom,
});

const rectOf = (b: Box) =>
  [b.l, b.t, b.r - b.l, b.b - b.t].map((n) => Math.round(n));

const clipTo = (a: Box, c: Box): Box | null => {
  const out = {
    l: Math.max(a.l, c.l),
    t: Math.max(a.t, c.t),
    r: Math.min(a.r, c.r),
    b: Math.min(a.b, c.b),
  };
  return out.r > out.l && out.b > out.t ? out : null;
};

/** How far [a] pokes out of [c] on its worst side, in px (0 if inside). */
const pokesOut = (a: Box, c: Box) =>
  Math.max(c.l - a.l, a.r - c.r, c.t - a.t, a.b - c.b, 0);

/** The smaller of the two overlap extents (<= 0 when they don't overlap). */
const overlapBy = (a: Box, b: Box) =>
  Math.min(
    Math.min(a.r, b.r) - Math.max(a.l, b.l),
    Math.min(a.b, b.b) - Math.max(a.t, b.t),
  );

const alphaOf = (color: string) => {
  if (!color || color === 'transparent') {
    return 0;
  }
  const m = color.match(/rgba?\(([^)]+)\)/);
  if (!m) {
    return 1;
  }
  const parts = m[1].split(/[,\s/]+/).filter((p) => p);
  return parts.length > 3 ? Number(parts[3]) : 1;
};

const pathOf = (el: Element | null) => {
  const parts: string[] = [];
  let e = el;
  while (e && e !== document.body && parts.length < 5) {
    let part = e.tagName.toLowerCase();
    if (e.id) {
      parts.unshift(`${part}#${e.id}`);
      break;
    }
    const cls = Array.from(e.classList).slice(0, 2);
    if (cls.length) {
      part += `.${cls.join('.')}`;
    }
    const parent: Element | null = e.parentElement;
    if (parent) {
      part += `:nth-child(${Array.from(parent.children).indexOf(e) + 1})`;
    }
    parts.unshift(part);
    e = parent;
  }
  return parts.join('>');
};

/** ignore= is a JSON list of selectors, or selectors joined with "||". */
const parseIgnore = (raw: string | undefined): string[] => {
  if (!raw) {
    return [];
  }
  if (raw.trim().startsWith('[')) {
    const list = JSON.parse(raw);
    return Array.isArray(list) ? list.map(String) : [];
  }
  return raw
    .split('||')
    .map((s) => s.trim())
    .filter((s) => s);
};

type TextItem = {
  el: Element;
  text: string;
  /** Visible part of each line's glyph box. */
  boxes: Box[];
};

type Finding = {
  kind: string;
  text: string;
  rect: number[];
  path: string;
  by: number;
  other?: { text?: string; rect: number[]; path: string };
};

const SIDES = ['top', 'right', 'bottom', 'left'];

const layout = (args: Args) => {
  const tol = Math.max(0, Number(args.tolerance ?? 1));
  // Share of the font size a line's ink fills; the rest of a Range box is leading.
  const ink = Math.min(Math.max(Number(args.ink ?? 0.9), 0.3), 1.5);
  const max = Math.min(Number(args.max || 40), MAX_FINDINGS);
  // Borders thicker than this are a surround (a bezel, a padded panel edge), not a line.
  const maxLine = Number(args.max_line ?? 12);
  const ignore = parseIgnore(args.ignore);
  const root =
    (args.root ? document.querySelector(args.root) : null) || document.body;
  const viewport: Box = {
    l: 0,
    t: 0,
    r: window.innerWidth,
    b: window.innerHeight,
  };

  const styles = new Map<Element, CSSStyleDeclaration>();
  const styleOf = (el: Element) => {
    let s = styles.get(el);
    if (!s) {
      s = window.getComputedStyle(el);
      styles.set(el, s);
    }
    return s;
  };
  const hiddenCache = new Map<Element, boolean>();
  const isHidden = (el: Element | null): boolean => {
    if (!el || el === document.documentElement) {
      return false;
    }
    const known = hiddenCache.get(el);
    if (known !== undefined) {
      return known;
    }
    const s = styleOf(el);
    const out =
      s.display === 'none' ||
      s.visibility === 'hidden' ||
      Number(s.opacity) < 0.05 ||
      isHidden(el.parentElement);
    hiddenCache.set(el, out);
    return out;
  };
  const ignored = (el: Element) =>
    ignore.some((sel) => {
      try {
        return !!el.closest(sel);
      } catch {
        return false;
      }
    });
  const clips = (s: CSSStyleDeclaration) =>
    s.overflowX !== 'visible' || s.overflowY !== 'visible';
  const scrolls = (s: CSSStyleDeclaration) =>
    /auto|scroll/.test(s.overflowX) || /auto|scroll/.test(s.overflowY);
  const paddingBox = (el: Element): Box => {
    const r = el.getBoundingClientRect();
    const l = r.left + el.clientLeft;
    const t = r.top + el.clientTop;
    return { l, t, r: l + el.clientWidth, b: t + el.clientHeight };
  };
  const isBlock = (s: CSSStyleDeclaration) =>
    s.display !== 'inline' && s.display !== 'contents';
  const hasBackground = (el: Element) =>
    alphaOf(styleOf(el).backgroundColor) >= 0.5;
  const borderWidth = (s: CSSStyleDeclaration, side: string) =>
    !/none|hidden/.test(s.getPropertyValue(`border-${side}-style`)) &&
    alphaOf(s.getPropertyValue(`border-${side}-color`)) > 0.1
      ? parseFloat(s.getPropertyValue(`border-${side}-width`)) || 0
      : 0;
  const hasBorder = (s: CSSStyleDeclaration) =>
    SIDES.some((side) => borderWidth(s, side) >= 1);

  const findings: Finding[] = [];
  let total = 0;
  const seen = new Set<string>();
  const add = (key: string, f: Finding) => {
    if (seen.has(key)) {
      return;
    }
    seen.add(key);
    total++;
    if (findings.length < max) {
      findings.push(f);
    }
  };
  const short = (text: string) =>
    text.length > 60 ? `${text.slice(0, 59)}~` : text;

  // 1. Every visible text node, as one glyph box per line, checked against the boxes holding it.
  const items: TextItem[] = [];
  const walker = document.createTreeWalker(root, NodeFilter.SHOW_TEXT);
  const range = document.createRange();
  for (let node = walker.nextNode(); node; node = walker.nextNode()) {
    const raw = node.nodeValue || '';
    const start = raw.search(/\S/);
    if (start < 0) {
      continue;
    }
    const el = node.parentElement;
    if (
      !el ||
      /^(SCRIPT|STYLE|NOSCRIPT|TEXTAREA|OPTION|TITLE)$/.test(el.tagName) ||
      isHidden(el) ||
      ignored(el)
    ) {
      continue;
    }
    range.setStart(node, start);
    range.setEnd(node, raw.trimEnd().length);
    const fontSize = parseFloat(styleOf(el).fontSize) || 12;
    const text = squash(raw);
    const path = pathOf(el);
    const boxes: Box[] = [];
    for (const r of Array.from(range.getClientRects())) {
      if (r.width < 0.5 || r.height < 0.5) {
        continue;
      }
      const inset = Math.max(0, (r.height - fontSize * ink) / 2);
      let line: Box | null = {
        l: r.left,
        t: r.top + inset,
        r: r.right,
        b: r.bottom - inset,
      };
      let ownBox = false;
      for (let a: Element | null = el; a && line; a = a.parentElement) {
        if (a === document.documentElement || a === document.body) {
          break;
        }
        const s = styleOf(a);
        if (clips(s)) {
          const pad = paddingBox(a);
          const by = pokesOut(line, pad);
          const visible = clipTo(line, pad);
          // Cut with an ellipsis is a bounded cut; scrolled out of view is not a cut.
          if (
            by > tol &&
            visible &&
            !scrolls(s) &&
            s.textOverflow !== 'ellipsis'
          ) {
            add(`clip:${path}:${Math.round(line.t)}`, {
              kind: 'clipped',
              text: short(text),
              rect: rectOf(line),
              path,
              by: Math.round(by),
              other: { rect: rectOf(pad), path: pathOf(a) },
            });
          }
          line = visible;
          ownBox = true;
          continue;
        }
        if (!isBlock(s)) {
          continue;
        }
        // The first block box is the text's own. Past it, only boxes you can see (a border or a
        // background) count: an invisible layout box overflowing harms nothing by itself.
        const own = !ownBox;
        ownBox = true;
        if (!(own || hasBorder(s) || hasBackground(a))) {
          continue;
        }
        const box = boxOf(a.getBoundingClientRect());
        const by = pokesOut(line, box);
        if (by > tol) {
          add(`past:${path}:${pathOf(a)}`, {
            kind: 'past_box',
            text: short(text),
            rect: rectOf(line),
            path,
            by: Math.round(by),
            other: { rect: rectOf(box), path: pathOf(a) },
          });
        }
      }
      if (!line) {
        continue;
      }
      const by = pokesOut(line, viewport);
      const visible = clipTo(line, viewport);
      if (by > tol && visible) {
        add(`off:${path}:${Math.round(line.t)}`, {
          kind: 'offscreen',
          text: short(text),
          rect: rectOf(line),
          path,
          by: Math.round(by),
        });
      }
      if (visible) {
        boxes.push(visible);
      }
    }
    if (boxes.length) {
      items.push({ el, text, boxes });
    }
  }

  // 2. Frame lines: every visible border side, as a strip. Text may not cross one it isn't inside.
  type Strip = { el: Element; box: Box; across: boolean };
  const strips: Strip[] = [];
  for (const el of Array.from(root.querySelectorAll('*'))) {
    if (isHidden(el) || ignored(el)) {
      continue;
    }
    const s = styleOf(el);
    // Image borders are artwork (the lobby's bezel), drawn under the screen that sits in them.
    if (!hasBorder(s) || s.getPropertyValue('border-image-source') !== 'none') {
      continue;
    }
    const r = el.getBoundingClientRect();
    if (r.width <= 0 || r.height <= 0) {
      continue;
    }
    const [top, right, bottom, left] = SIDES.map((side) => {
      const width = borderWidth(s, side);
      return width > maxLine ? 0 : width;
    });
    const push = (box: Box, across: boolean) => {
      if (box.r - box.l >= 1 && box.b - box.t >= 1) {
        strips.push({ el, box, across });
      }
    };
    push({ l: r.left, t: r.top, r: r.right, b: r.top + top }, true);
    push({ l: r.left, t: r.bottom - bottom, r: r.right, b: r.bottom }, true);
    push({ l: r.left, t: r.top, r: r.left + left, b: r.bottom }, false);
    push({ l: r.right - right, t: r.top, r: r.right, b: r.bottom }, false);
  }
  for (const item of items) {
    // A label that paints its own background over a horizontal line is a legend (a frame title).
    const legend = hasBackground(item.el);
    const path = pathOf(item.el);
    for (const strip of strips) {
      if (strip.el.contains(item.el) || (legend && strip.across)) {
        continue;
      }
      for (const line of item.boxes) {
        const by = overlapBy(line, strip.box);
        // A border can be thinner than the tolerance, so crossing most of its width is enough.
        const thin = strip.across
          ? strip.box.b - strip.box.t
          : strip.box.r - strip.box.l;
        if (by > Math.min(tol, thin - 0.5)) {
          add(`line:${path}:${pathOf(strip.el)}`, {
            kind: 'crosses_line',
            text: short(item.text),
            rect: rectOf(line),
            path,
            by: Math.round(by * 10) / 10,
            other: { rect: rectOf(strip.box), path: pathOf(strip.el) },
          });
          break;
        }
      }
    }
  }

  // 3. Text over other text.
  type Line = { item: TextItem; box: Box };
  const lines: Line[] = [];
  for (const item of items) {
    for (const box of item.boxes) {
      lines.push({ item, box });
    }
  }
  lines.sort((a, b) => a.box.l - b.box.l);
  for (let i = 0; i < lines.length; i++) {
    const a = lines[i];
    for (
      let j = i + 1;
      j < lines.length && lines[j].box.l < a.box.r - tol;
      j++
    ) {
      const b = lines[j];
      if (
        a.item === b.item ||
        a.item.el.contains(b.item.el) ||
        b.item.el.contains(a.item.el)
      ) {
        continue;
      }
      const by = overlapBy(a.box, b.box);
      if (by <= tol) {
        continue;
      }
      // The same text drawn twice in one place is a deliberate layer (a glow or a ghost copy).
      if (
        a.item.text === b.item.text &&
        Math.abs(a.box.l - b.box.l) <= 2 &&
        Math.abs(a.box.t - b.box.t) <= 2
      ) {
        continue;
      }
      const [first, second] =
        a.box.t < b.box.t || (a.box.t === b.box.t && a.box.l <= b.box.l)
          ? [a, b]
          : [b, a];
      const p1 = pathOf(first.item.el);
      const p2 = pathOf(second.item.el);
      add(`over:${p1}:${p2}`, {
        kind: 'overlap',
        text: short(first.item.text),
        rect: rectOf(first.box),
        path: p1,
        by: Math.round(by),
        other: {
          text: short(second.item.text),
          rect: rectOf(second.box),
          path: p2,
        },
      });
    }
  }

  return {
    clean: total === 0,
    total,
    findings,
    checked: { texts: items.length, lines: strips.length },
    tolerance: tol,
    size: [window.innerWidth, window.innerHeight],
    screen: [window.screenX, window.screenY, window.devicePixelRatio],
  };
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
  layout,
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
    Number(args.settle ?? (op === 'query' || op === 'layout' ? 0 : 400)),
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
