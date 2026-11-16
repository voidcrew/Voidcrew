/**
 * Keyboard and mouse focus for the dock terminal.
 *
 * Everything clickable registers here (Put with onClick, Btn, Hit, Field, the bezel keys).
 * One item is focused at a time and draws lit. The mouse and the keyboard share it: hovering
 * an item focuses it, the arrow keys move it to the nearest item in that direction, Enter or
 * Space presses it, Escape or Backspace goes back.
 *
 * Keys reach the page because the terminal's skin control takes keyboard focus when it shows
 * (lobby_terminal show code). tgui-core keeps arrows, Enter, Space, Escape and Tab in the page;
 * a key handled here is preventDefault()ed so tgui-core never passes it on to BYOND either.
 *
 * Sounds play in the page from the terminal's assets (motion.ts), so a key press never costs a
 * round trip: a click when the focus moves, the key-press sound and an 80 ms white flash when
 * an item is pressed, by Enter or by the mouse.
 */
import {
  createContext,
  type ReactNode,
  type RefObject,
  useContext,
  useEffect,
  useId,
  useLayoutEffect,
  useMemo,
  useRef,
  useState,
} from 'react';

import {
  muteSfx,
  noteAction,
  preloadSfx,
  pressFlash,
  pressFx,
  sfx,
} from './motion';

export type Dir = 'up' | 'down' | 'left' | 'right';

export type FocusOpts = {
  /** What Enter, Space or a click does. */
  activate: () => void;
  /**
   * Take the focus when this mounts (the screen's first sensible target). Higher wins when
   * several mount at once; ties go to the first.
   */
  auto?: number;
  /** Arrow keys that leave this item some other way, e.g. paging a list. TRUE = handled. */
  edge?: Partial<Record<Dir, () => boolean>>;
  /** A tab: keeps the focus while the screen under it changes, and switches on arrow focus. */
  tab?: boolean;
  /** Lit by the mouse only; the arrow keys pass it by (a cycler's < and >, which Left/Right drive). */
  mouseOnly?: boolean;
  /** A text field: Enter starts typing in it. */
  input?: RefObject<HTMLInputElement | null>;
  /**
   * Layout zone: 'menu' for the side menu and key bar, 'main' (the default) for the rest. An
   * arrow move from the menu back into the main area returns to the main item that last had
   * the focus, if it is still there.
   */
  zone?: string;
};

type Item = {
  el: () => HTMLElement | null;
  /** The FocusScope it sits in; only the newest open scope's items take the focus. */
  scope: string;
  opts: RefObject<FocusOpts>;
};

/** auto: a stand-in the game picked; claim: a screen's first target. */
type How = 'key' | 'mouse' | 'auto' | 'claim';

type Nav = {
  pushScope: (id: string) => void;
  popScope: (id: string) => void;
  focused: string | null;
  focus: (id: string, how: How) => void;
  register: (id: string, item: Item) => void;
  unregister: (id: string) => void;
  pushBack: (id: string, fn: RefObject<() => void>) => void;
  popBack: (id: string) => void;
  pushPager: (id: string, fn: RefObject<(step: number) => void>) => void;
  popPager: (id: string) => void;
};

const NavContext = createContext<Nav | null>(null);
const ScopeContext = createContext('root');

// ---------------------------------------------------------------------------
// Input lock
// ---------------------------------------------------------------------------

let inputLocked = false;

/**
 * While locked, the keyboard does nothing here and the focus makes no sound: something drawn
 * over the terminal (the start-up screen) owns the keys. The owner must also keep the mouse off
 * what is underneath, and handle or swallow the keys itself.
 */
export function lockNav(locked: boolean) {
  inputLocked = locked;
  muteSfx(locked);
}

// ---------------------------------------------------------------------------
// Geometry
// ---------------------------------------------------------------------------

type Box = { l: number; t: number; r: number; b: number };

function boxOf(item: Item | undefined): Box | null {
  const el = item?.el();
  if (!el) {
    return null;
  }
  const rect = el.getBoundingClientRect();
  if (rect.width <= 0 || rect.height <= 0) {
    return null;
  }
  return { l: rect.left, t: rect.top, r: rect.right, b: rect.bottom };
}

/** Gap between two ranges, 0 when they overlap. */
const gap = (a0: number, a1: number, b0: number, b1: number) =>
  Math.max(0, b0 - a1, a0 - b1);

/** How far `to` is from `from` going `dir`; null when it isn't that way. */
function score(from: Box, to: Box, dir: Dir): number | null {
  const slack = 2;
  const fcx = (from.l + from.r) / 2;
  const fcy = (from.t + from.b) / 2;
  const tcx = (to.l + to.r) / 2;
  const tcy = (to.t + to.b) / 2;
  let main: number;
  let side: number;
  switch (dir) {
    case 'down':
      if (to.t < from.b - slack || tcy <= fcy) {
        return null;
      }
      main = Math.max(0, to.t - from.b);
      side = gap(from.l, from.r, to.l, to.r);
      return main + side * 2 + Math.abs(tcx - fcx) * 0.02;
    case 'up':
      if (to.b > from.t + slack || tcy >= fcy) {
        return null;
      }
      main = Math.max(0, from.t - to.b);
      side = gap(from.l, from.r, to.l, to.r);
      return main + side * 2 + Math.abs(tcx - fcx) * 0.02;
    case 'right':
      if (to.l < from.r - slack || tcx <= fcx) {
        return null;
      }
      main = Math.max(0, to.l - from.r);
      side = gap(from.t, from.b, to.t, to.b);
      return main + side * 6 + Math.abs(tcy - fcy) * 0.02;
    case 'left':
      if (to.r > from.l + slack || tcx >= fcx) {
        return null;
      }
      main = Math.max(0, from.l - to.r);
      side = gap(from.t, from.b, to.t, to.b);
      return main + side * 6 + Math.abs(tcy - fcy) * 0.02;
  }
}

/** How long after a key or click a newly opened screen may take the focus, in ms. */
const CLAIM_WINDOW = 1500;

const KEY_DIRS: Record<string, Dir> = {
  ArrowUp: 'up',
  ArrowDown: 'down',
  ArrowLeft: 'left',
  ArrowRight: 'right',
};

// ---------------------------------------------------------------------------
// Provider
// ---------------------------------------------------------------------------

type ProviderProps = {
  children: ReactNode;
  /** Number keys: 1 is the first tab. */
  onTabNumber?: (n: number) => void;
  /** Tab and Shift+Tab: the next or previous tab. */
  onTabStep?: (step: number) => void;
};

export function NavProvider(props: ProviderProps) {
  const { children } = props;
  const items = useRef(new Map<string, Item>()).current;
  const order = useRef<string[]>([]).current;
  const backs = useRef<[string, RefObject<() => void>][]>([]).current;
  const pagers = useRef<[string, RefObject<(step: number) => void>][]>(
    [],
  ).current;
  /** The last item focused in each zone. */
  const lastInZone = useRef(new Map<string, string>()).current;
  const scopes = useRef<string[]>(['root']).current;
  /** Items in the newest open scope, in mount order. */
  const live = () => {
    const top = scopes[scopes.length - 1];
    return order.filter((id) => {
      const item = items.get(id);
      return item?.scope === top && !item.opts.current.mouseOnly;
    });
  };
  const focusRef = useRef<string | null>(null);
  const lastBox = useRef<Box | null>(null);
  const claim = useRef<{ id: string; prio: number } | null>(null);
  const scheduled = useRef(false);
  /** When the player last pressed a key or clicked. Only then may a new screen take the focus. */
  const lastAction = useRef(0);
  /** How the focus got where it is; one the player never moved may go to a later claim. */
  const focusHow = useRef<How>('auto');
  const [focused, setFocused] = useState<string | null>(null);
  const propsRef = useRef(props);
  propsRef.current = props;

  const nav = useMemo<Nav>(() => {
    const setFocus = (id: string | null, how: How) => {
      if (id === focusRef.current) {
        return;
      }
      focusRef.current = id;
      focusHow.current = how;
      setFocused(id);
      const item = id ? items.get(id) : undefined;
      if (id && item) {
        lastInZone.set(item.opts.current.zone || 'main', id);
      }
      lastBox.current = boxOf(item) || lastBox.current;
      if ((how === 'key' || how === 'mouse') && id && !inputLocked) {
        sfx('move');
      }
      if (how === 'key' && item?.opts.current.tab) {
        item.opts.current.activate();
      }
    };

    /** Settles the focus after a commit: a claim, or a stand-in for an item that went away. */
    const settle = () => {
      scheduled.current = false;
      const current = focusRef.current;
      const top = scopes[scopes.length - 1];
      const found = current ? items.get(current) : undefined;
      const currentItem = found?.scope === top ? found : undefined;
      const pending = claim.current;
      claim.current = null;
      // A claim wins after a key or click (a record or screen the player opened), never because
      // a server update added a row under the focus.
      const untouched = focusHow.current === 'auto';
      const fresh = untouched || Date.now() - lastAction.current < CLAIM_WINDOW;
      if (
        pending &&
        items.get(pending.id)?.scope === top &&
        (!currentItem || fresh)
      ) {
        if (untouched || !currentItem?.opts.current.tab) {
          setFocus(pending.id, 'claim');
          return;
        }
      }
      if (currentItem) {
        return;
      }
      // Nearest to where the focus was, else the first in reading order.
      let best: string | null = null;
      let bestScore = Infinity;
      const from = lastBox.current;
      for (const id of live()) {
        const box = boxOf(items.get(id));
        if (!box) {
          continue;
        }
        const s = from
          ? Math.hypot(
              (box.l + box.r - from.l - from.r) / 2,
              (box.t + box.b - from.t - from.b) / 2,
            )
          : box.t * 10000 + box.l;
        if (s < bestScore) {
          bestScore = s;
          best = id;
        }
      }
      setFocus(best, 'auto');
    };
    const schedule = () => {
      if (!scheduled.current) {
        scheduled.current = true;
        queueMicrotask(settle);
      }
    };

    return {
      focused: null,
      focus: setFocus,
      register: (id, item) => {
        items.set(id, item);
        if (!order.includes(id)) {
          order.push(id);
        }
        const prio = item.opts.current.auto;
        if (
          prio !== undefined &&
          (!claim.current || prio > claim.current.prio)
        ) {
          claim.current = { id, prio };
        }
        schedule();
      },
      unregister: (id) => {
        items.delete(id);
        const at = order.indexOf(id);
        if (at >= 0) {
          order.splice(at, 1);
        }
        if (id === focusRef.current) {
          schedule();
        }
      },
      pushScope: (id) => {
        scopes.push(id);
        schedule();
      },
      popScope: (id) => {
        const at = scopes.indexOf(id);
        if (at > 0) {
          scopes.splice(at, 1);
        }
        schedule();
      },
      pushBack: (id, fn) => {
        backs.push([id, fn]);
      },
      popBack: (id) => {
        const at = backs.findIndex((b) => b[0] === id);
        if (at >= 0) {
          backs.splice(at, 1);
        }
      },
      pushPager: (id, fn) => {
        pagers.push([id, fn]);
      },
      popPager: (id) => {
        const at = pagers.findIndex((b) => b[0] === id);
        if (at >= 0) {
          pagers.splice(at, 1);
        }
      },
    };
  }, []);

  // The start-up screen loads its own sounds first and asks for these when it starts.
  useEffect(() => {
    if (!inputLocked) {
      preloadSfx();
    }
  }, []);

  useEffect(() => {
    const move = (dir: Dir) => {
      const current = focusRef.current;
      const item = current ? items.get(current) : undefined;
      const from = boxOf(item);
      if (!item || !from) {
        const first = live()[0];
        if (first) {
          nav.focus(first, 'key');
        }
        return;
      }
      const edge = item.opts.current.edge?.[dir];
      if (edge?.()) {
        sfx('move');
        return;
      }
      let best: string | null = null;
      let bestScore = Infinity;
      for (const id of live()) {
        if (id === current) {
          continue;
        }
        const box = boxOf(items.get(id));
        if (!box) {
          continue;
        }
        const s = score(from, box, dir);
        if (s !== null && s < bestScore) {
          bestScore = s;
          best = id;
        }
      }
      if (best) {
        // Back from the menu into the main area: the main item that last had the focus.
        const fromZone = item.opts.current.zone || 'main';
        const toZone = items.get(best)?.opts.current.zone || 'main';
        if (fromZone !== toZone && toZone === 'main') {
          const last = lastInZone.get('main');
          if (last && last !== best && live().includes(last)) {
            if (boxOf(items.get(last))) {
              best = last;
            }
          }
        }
        nav.focus(best, 'key');
      }
    };

    const onAction = () => {
      lastAction.current = Date.now();
      noteAction();
    };
    // A click on anything focusable is a press: the sound, and the shape flashes white.
    const onClick = (e: MouseEvent) => {
      onAction();
      if (inputLocked) {
        return;
      }
      const target = e.target as Node | null;
      if (!target) {
        return;
      }
      for (const item of items.values()) {
        const el = item.el();
        if (el?.contains(target)) {
          if (!item.opts.current.input) {
            pressFlash(el);
          }
          pressFx();
          return;
        }
      }
    };
    const onKey = (e: KeyboardEvent) => {
      if (inputLocked) {
        return;
      }
      onAction();
      if (e.ctrlKey || e.altKey || e.metaKey) {
        return;
      }
      const target = e.target as HTMLElement | null;
      const typing =
        !!target &&
        (target.tagName === 'INPUT' || target.tagName === 'TEXTAREA');
      if (typing) {
        // Typing stays typing. Escape or Tab leaves the field, its highlight stays on it.
        if (e.key === 'Escape' || e.key === 'Tab') {
          e.preventDefault();
          target.blur();
        }
        return;
      }
      const dir = KEY_DIRS[e.key];
      if (dir) {
        e.preventDefault();
        move(dir);
        return;
      }
      const current = focusRef.current;
      const item = current ? items.get(current) : undefined;
      if (e.key === 'Enter' || e.key === ' ') {
        e.preventDefault();
        if (e.repeat || !item) {
          return;
        }
        pressFx();
        const input = item.opts.current.input?.current;
        if (input && !input.disabled) {
          input.focus();
          return;
        }
        pressFlash(item.el());
        item.opts.current.activate();
        return;
      }
      if (e.key === 'Escape' || e.key === 'Backspace') {
        e.preventDefault();
        if (e.repeat) {
          return;
        }
        // No key-press sound: going back has its own (the wipe played slower).
        const top = backs[backs.length - 1];
        if (top) {
          top[1].current();
        }
        return;
      }
      if (e.key === 'PageUp' || e.key === 'PageDown') {
        e.preventDefault();
        // No click of its own: a page that turns sounds its tick.
        const top = pagers[pagers.length - 1];
        if (top) {
          top[1].current(e.key === 'PageUp' ? -1 : 1);
        }
        return;
      }
      if (e.key === 'Tab') {
        e.preventDefault();
        propsRef.current.onTabStep?.(e.shiftKey ? -1 : 1);
        return;
      }
      if (/^[1-9]$/.test(e.key) && propsRef.current.onTabNumber) {
        e.preventDefault();
        propsRef.current.onTabNumber(Number(e.key));
      }
    };
    window.addEventListener('keydown', onKey, true);
    window.addEventListener('click', onClick, true);
    return () => {
      window.removeEventListener('keydown', onKey, true);
      window.removeEventListener('click', onClick, true);
    };
  }, []);

  const value = useMemo(() => ({ ...nav, focused }), [nav, focused]);
  return <NavContext.Provider value={value}>{children}</NavContext.Provider>;
}

// ---------------------------------------------------------------------------
// Hooks
// ---------------------------------------------------------------------------

/**
 * Makes an element focusable while `enabled`. Put the returned ref on the element and spread
 * onMouseEnter on it; `focused` says whether to draw it lit.
 */
export function useFocusable<T extends HTMLElement>(
  enabled: boolean,
  opts: FocusOpts,
) {
  const nav = useContext(NavContext);
  const scope = useContext(ScopeContext);
  const id = useId();
  const ref = useRef<T | null>(null);
  const optsRef = useRef(opts);
  optsRef.current = opts;
  const register = nav?.register;
  const unregister = nav?.unregister;
  useLayoutEffect(() => {
    if (!enabled || !register || !unregister) {
      return;
    }
    register(id, { el: () => ref.current, opts: optsRef, scope });
    return () => unregister(id);
  }, [enabled, register, unregister, scope]);
  const focused = enabled && !!nav && nav.focused === id;
  return {
    ref,
    focused,
    onMouseEnter: enabled && nav ? () => nav.focus(id, 'mouse') : undefined,
    /** Moves the focus here, for things that want it after a click. */
    take: () => nav?.focus(id, 'claim'),
  };
}

/**
 * A modal layer (a picker, a confirm box): while it is mounted the arrow keys only reach the
 * items inside it, and the focus goes back to the screen under it when it closes.
 */
export function FocusScope(props: { children: ReactNode }) {
  const nav = useContext(NavContext);
  const id = useId();
  const pushScope = nav?.pushScope;
  const popScope = nav?.popScope;
  useLayoutEffect(() => {
    if (!pushScope || !popScope) {
      return;
    }
    pushScope(id);
    return () => popScope(id);
  }, [pushScope, popScope]);
  return (
    <ScopeContext.Provider value={id}>{props.children}</ScopeContext.Provider>
  );
}

/**
 * What Escape and Backspace do while this is mounted (the newest mounted one wins):
 * close a record, BACK a screen, dismiss a box.
 */
export function useBack(fn: (() => void) | null) {
  const nav = useContext(NavContext);
  const id = useId();
  const fnRef = useRef<() => void>(() => undefined);
  fnRef.current = fn || (() => undefined);
  const active = !!fn;
  useLayoutEffect(() => {
    if (!active || !nav) {
      return;
    }
    nav.pushBack(id, fnRef);
    return () => nav.popBack(id);
  }, [active, nav?.pushBack]);
}

/**
 * What PageUp (-1) and PageDown (+1) do while this is mounted (the newest mounted one wins):
 * page a list, step to the previous or next record.
 */
export function usePager(fn: ((step: number) => void) | null) {
  const nav = useContext(NavContext);
  const id = useId();
  const fnRef = useRef<(step: number) => void>(() => undefined);
  fnRef.current = fn || (() => undefined);
  const active = !!fn;
  useLayoutEffect(() => {
    if (!active || !nav) {
      return;
    }
    nav.pushPager(id, fnRef);
    return () => nav.popPager(id);
  }, [active, nav?.pushPager]);
}

/** The lit-focus look added to whatever is focused (an outline glow in the item's colour). */
export const NAV_CSS = `
.lt-tui .lt-foc { outline: 2px solid currentColor; outline-offset: 1px;
  box-shadow: 0 0 10px rgba(190,140,255,.55); }
.lt-tui .lt-foc.inv, .lt-tui .lt-foc.invx, .lt-tui .lt-foc.inva { outline-color: var(--lt-fg); }
.lt-tui .lt-foc.inva { outline-color: var(--lt-amb); }
.lt-tui .lt-hitfoc { outline: 2px solid var(--lt-fg); outline-offset: -1px;
  box-shadow: 0 0 10px rgba(190,140,255,.45), inset 0 0 8px rgba(190,140,255,.25); }
.lt-tui .lt-fieldfoc { outline: 2px solid var(--lt-fg); outline-offset: 1px;
  box-shadow: 0 0 10px rgba(190,140,255,.55); }
`;
