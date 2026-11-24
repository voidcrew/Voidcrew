/**
 * Motion and sound for the dock terminal.
 *
 * Every animation is stepped, 80 to 240 ms long, and moves only opacity, a transform or a
 * cover. Nothing waits for one: the new state is mounted and focusable at once and the
 * animation only reveals it. No cover can be left on the screen: each one ends outside its
 * clip, and a timer takes it away whether or not the animation ran. While the page is hidden
 * nothing starts and nothing sounds.
 *
 *   sfx('wipe')                              a named sound at its level; a no-op when it may not play
 *   pressFx() / sfxInstead('slot')           the key-press sound, or the sound a press has instead
 *   <Wipe k={page} kind="page" style={px} /> a cover over a px rect that plays when k changes
 *   <Flash k={asked} style={px} />           a white bar over a px rect when k changes
 *   const ref = usePulse(count)              flashes ref's element white when count changes
 *   useScreen('crews/record', 1, ref)        says which screen the main box shows; ScreenWipe covers the change
 *   useBlink(on, 500)                        TRUE and FALSE in turn while on
 */
import {
  type CSSProperties,
  createElement,
  useEffect,
  useLayoutEffect,
  useRef,
  useState,
} from 'react';

import { play, preload } from './audio';

// ---------------------------------------------------------------------------
// Sound
// ---------------------------------------------------------------------------

/**
 * The start-up clips are baked at their approved levels and play at a master gain of 1. Every
 * other sound of the terminal is scaled by this instead, so the lobby sits under them.
 */
const LOBBY_GAIN = 0.8;

/** The start-up screen's eight keystroke rates, used in turn for typing. */
const TYPE_RATES = [1, 0.97, 1.04, 0.99, 1.02, 0.96, 1.03, 1];

type Sound = {
  /** Asset names (lobby_assets.dm); several are played in turn. */
  ids: string[];
  gain: number;
  rate?: number;
  /** Rates used in turn. */
  rates?: number[];
  /** At most one play per this many ms. */
  gap?: number;
  /** Restarts the clip instead of layering it. */
  solo?: boolean;
};

const SOUNDS = {
  /** The focus moves. */
  move: {
    ids: ['lt_key1.ogg', 'lt_key2.ogg', 'lt_key3.ogg'],
    gain: 0.22,
    gap: 55,
    solo: true,
  },
  /** A key, slab or tab is pressed. */
  press: { ids: ['lt_press.ogg'], gain: 0.3, solo: true },
  /** A screen opens; `back` is the same clip slowed. */
  wipe: { ids: ['lt_wipe.ogg'], gain: 0.3 },
  back: { ids: ['lt_wipe.ogg'], gain: 0.3, rate: 0.85 },
  /** A page turns, a stepper steps. */
  page: { ids: ['lt_boot_tick.ogg'], gain: 0.5 },
  ready_on: { ids: ['lt_ready_on.ogg'], gain: 0.5 },
  ready_off: { ids: ['lt_ready_off.ogg'], gain: 0.45 },
  /** The departure clock's last seconds. */
  clock: { ids: ['lt_boot_tick.ogg'], gain: 0.35 },
  /** The CONFIRMED box. */
  stamp: { ids: ['lt_stamp.ogg'], gain: 0.6 },
  /** A long job starts under STAND BY. */
  working: { ids: ['lt_working.ogg'], gain: 0.25 },
  warn: { ids: ['lt_warn.ogg'], gain: 0.45 },
  bad: { ids: ['lt_bad.ogg'], gain: 0.5 },
  /** Something was accepted: a code, an application, a ping, a name, a trait. */
  ok: { ids: ['lt_ok.ogg'], gain: 0.4 },
  /** The place in line changes. */
  queue: { ids: ['lt_key1.ogg'], gain: 0.3 },
  /** A character typed in a field. */
  type: { ids: ['lt_boot_key.ogg'], gain: 0.35, gap: 30, rates: TYPE_RATES },
  /** An option is fitted in the shipyard. */
  slot: { ids: ['lt_slot.ogg'], gain: 0.4 },
  /** The character picture turns. */
  turn: { ids: ['lt_turn.ogg'], gain: 0.35 },
} satisfies Record<string, Sound>;

export type SfxName = keyof typeof SOUNDS;

export type SfxOpts = {
  /** Multiplies the sound's own rate. */
  rate?: number;
  /** Seconds from now. */
  when?: number;
  /**
   * Only when the player pressed a key or clicked a moment ago: for sounds that answer an
   * action but are set off by the server's reply, so a change made elsewhere stays silent.
   */
  own?: boolean;
};

/** Stand-in clips: asset name -> [rate, gain scale], sent by the server with the clip list. */
let tune: Record<string, [number, number]> = {};
/** The start-up screen is up: it plays its own sounds and the terminal under it stays silent. */
let muted = false;
const lastPlayed: Partial<Record<SfxName, number>> = {};
const turns: Partial<Record<SfxName, number>> = {};
/** When the player last pressed a key or clicked. */
let actedAt = 0;
/** How long after a key or click a sound marked `own` still counts as its answer. */
const OWN_WINDOW = 4000;

const hidden = () => typeof document !== 'undefined' && document.hidden;

/** Notes a key press or click (nav.tsx calls it). */
export function noteAction() {
  actedAt = Date.now();
}

/** Silences the terminal's sounds while something drawn over it owns the screen. */
export function muteSfx(on: boolean) {
  muted = on;
}

/** Playback tuning for clips that are stand-ins (ShellStatic.sfx_tune). */
export function setSfxTune(next: Record<string, [number, number]> | undefined) {
  tune = next || {};
}

/** Fetches and decodes every sound of the terminal. Safe to call again. */
export function preloadSfx() {
  const ids = new Set<string>();
  for (const sound of Object.values(SOUNDS) as Sound[]) {
    for (const id of sound.ids) {
      ids.add(id);
    }
  }
  preload(Array.from(ids)).catch(() => undefined);
}

/** Plays a named sound. Returns TRUE when it was started. Never throws. */
export function sfx(name: SfxName, opts: SfxOpts = {}): boolean {
  try {
    if (muted || hidden()) {
      return false;
    }
    const now = Date.now();
    if (opts.own && now - actedAt > OWN_WINDOW) {
      return false;
    }
    const sound: Sound = SOUNDS[name];
    if (sound.gap && now - (lastPlayed[name] || 0) < sound.gap) {
      return false;
    }
    lastPlayed[name] = now;
    const turn = turns[name] || 0;
    turns[name] = turn + 1;
    const id = sound.ids[turn % sound.ids.length];
    const [tuneRate, tuneGain] = tune[id] || [1, 1];
    const rate =
      (sound.rate || 1) *
      (sound.rates ? sound.rates[turn % sound.rates.length] : 1) *
      (opts.rate || 1) *
      (tuneRate || 1);
    return play(id, {
      gain: sound.gain * LOBBY_GAIN * (tuneGain || 1),
      rate,
      when: opts.when,
      solo: sound.solo,
    });
  } catch {
    return false;
  }
}

let pressQueued = false;
let pressTaken = false;

/**
 * The key-press sound, for a press about to be handled. It plays just after the handler has
 * run, so a handler with a sound of its own can take its place (sfxInstead).
 */
export function pressFx() {
  if (pressQueued) {
    return;
  }
  pressQueued = true;
  pressTaken = false;
  setTimeout(() => {
    pressQueued = false;
    if (!pressTaken) {
      sfx('press');
    }
  }, 0);
}

/** Plays a sound in place of the key-press sound of the press being handled. */
export function sfxInstead(name: SfxName, opts?: SfxOpts) {
  pressTaken = true;
  sfx(name, opts);
}

/** Drops the key-press sound of the press being handled (it did nothing). */
export function noPressFx() {
  pressTaken = true;
}

const PRESS_MS = 80;

/** The shape flashes white for 80 ms. Set on the element itself, so a re-render never cuts it. */
export function pressFlash(el: Element | null | undefined) {
  if (!el || hidden()) {
    return;
  }
  try {
    el.setAttribute('data-press', '');
    setTimeout(() => el.removeAttribute('data-press'), PRESS_MS);
  } catch {
    // An element that went away mid-press has nothing to flash.
  }
}

// ---------------------------------------------------------------------------
// A long job (commission, requisition, load) sent just now
// ---------------------------------------------------------------------------

let foundingAt = 0;

/** A founding key was sent: the CONFIRMED box that answers it starts a long job. */
export function noteFounding() {
  foundingAt = Date.now();
}

/** TRUE when a founding key was sent in the last few seconds. */
export function foundingSent() {
  return Date.now() - foundingAt < 15000;
}

// ---------------------------------------------------------------------------
// Triggers
// ---------------------------------------------------------------------------

type Run = { serial: number; back: boolean };

/**
 * A run counter that starts when `k` changes (and on mount with `first`) and ends by timer
 * `ms` later. Starting happens before the browser paints, so a cover is up in the same frame
 * as what it covers. `n` orders the values: a lower one than before runs as `back`.
 */
function useRun(
  k: unknown,
  n: number | undefined,
  ms: number,
  first: boolean | undefined,
  onStart?: (back: boolean) => void,
): Run | null {
  const [run, setRun] = useState<Run | null>(null);
  const prev = useRef<{ k: unknown; n: number | undefined } | null>(null);
  const serial = useRef(0);
  const timer = useRef<ReturnType<typeof setTimeout> | null>(null);
  const started = useRef(onStart);
  started.current = onStart;
  useLayoutEffect(() => {
    const was = prev.current;
    prev.current = { k, n };
    if (was ? Object.is(was.k, k) : !first) {
      return;
    }
    if (hidden()) {
      return;
    }
    const order = typeof n === 'number' ? n : typeof k === 'number' ? k : null;
    const wasOrder = !was
      ? null
      : typeof was.n === 'number'
        ? was.n
        : typeof was.k === 'number'
          ? was.k
          : null;
    const back = order !== null && wasOrder !== null && order < wasOrder;
    serial.current += 1;
    setRun({ serial: serial.current, back });
    if (timer.current) {
      clearTimeout(timer.current);
    }
    timer.current = setTimeout(() => {
      timer.current = null;
      setRun(null);
    }, ms + 50);
    started.current?.(back);
  }, [k]);
  useEffect(
    () => () => {
      if (timer.current) {
        clearTimeout(timer.current);
      }
    },
    [],
  );
  return run;
}

// ---------------------------------------------------------------------------
// The wipe
// ---------------------------------------------------------------------------

export type WipeKind = 'screen' | 'page' | 'slot' | 'draw';

/** Duration in ms of each kind; the step counts are in MOTION_CSS. */
const WIPE_MS: Record<WipeKind, number> = {
  screen: 160,
  page: 100,
  slot: 120,
  draw: 120,
};

type Px = { left: number; top: number; width: number; height: number };

function cover(
  run: Run | null,
  kind: WipeKind,
  up: boolean,
  tone: 'bg' | 'well',
  style: Px,
  z: number | undefined,
) {
  if (!run) {
    return null;
  }
  const clip: CSSProperties = { ...style };
  if (z !== undefined) {
    clip.zIndex = z;
  }
  return createElement(
    'div',
    { className: 'lt-wipe', style: clip },
    createElement('div', {
      key: run.serial,
      className: `lt-wipe-c is-${kind} is-${up ? 'up' : 'down'} is-${tone}`,
    }),
  );
}

/**
 * A cover over a px rect of the positioned parent, played when `k` changes: it starts whole
 * and retracts in steps with a bright line on its leading edge, showing what is under it.
 *
 *   screen  160 ms, 8 steps; forward it retracts top to bottom, back bottom to top; the wipe sound
 *   page    100 ms, 5 steps, always top to bottom; the tick, lower going back
 *   slot    120 ms, 4 steps, top to bottom; no sound of its own
 *   draw    120 ms, 6 steps, left to right (a line of text being drawn); no sound of its own
 *
 * Back is a lower `n` (or a lower numeric `k`) than before, or `dir="up"`.
 */
export function Wipe(props: {
  k: unknown;
  n?: number;
  kind?: WipeKind;
  dir?: 'down' | 'up';
  /** The cover's colour: the terminal background, or a picture well's. */
  tone?: 'bg' | 'well';
  /** No sound. */
  quiet?: boolean;
  /** Also plays when it mounts. */
  first?: boolean;
  z?: number;
  style: Px;
}) {
  const { k, n, kind = 'screen', dir, tone = 'bg', quiet, first, z } = props;
  /** The direction of the run under way, fixed when it starts. */
  const up = useRef(false);
  const run = useRun(k, n, WIPE_MS[kind], first, (back) => {
    const goingBack = dir ? dir === 'up' : back;
    up.current = kind === 'screen' && goingBack;
    if (quiet || kind === 'slot' || kind === 'draw') {
      return;
    }
    if (kind === 'page') {
      sfx('page', { rate: goingBack ? 0.9 : 1 });
    } else {
      sfx(goingBack ? 'back' : 'wipe');
    }
  });
  return cover(run, kind, up.current, tone, props.style, z);
}

/** A white bar over a px rect for 200 ms when `k` changes: the row that changed. */
export function Flash(props: {
  k: unknown;
  first?: boolean;
  z?: number;
  style: Px;
}) {
  const run = useRun(props.k, undefined, 200, props.first);
  if (!run) {
    return null;
  }
  const style: CSSProperties = { ...props.style };
  if (props.z !== undefined) {
    style.zIndex = props.z;
  }
  return createElement('div', {
    key: run.serial,
    className: 'lt-flashbar',
    style,
  });
}

// ---------------------------------------------------------------------------
// The screen in the main box
// ---------------------------------------------------------------------------

type Screen = { id: string; depth: number; item: string; order: number };
/** rect: a px rect of the main region to cover instead of the box (a dialog that closed). */
type ScreenPlay = { serial: number; kind: WipeKind; up: boolean; rect?: Px };

let screen: Screen | null = null;
let screenSerial = 0;
let screenWipeAt = 0;
/** Hints for the screen change about to happen; each lapses if no change follows at once. */
let quietUntil = 0;
let backUntil = 0;
const HINT_MS = 500;
const screenSubs = new Set<(play: ScreenPlay) => void>();

function playMain(play: Omit<ScreenPlay, 'serial'>) {
  screenSerial += 1;
  const next = { ...play, serial: screenSerial };
  for (const fn of Array.from(screenSubs)) {
    fn(next);
  }
}

const tabOf = (id: string) => id.split('/')[0];

/** The screen change about to happen makes no sound and draws no cover (the shell moved, not the player). */
export function quietNextScreen() {
  quietUntil = Date.now() + HINT_MS;
}

/** The screen change about to happen is a step back, whatever the screens' depths say. */
export function backNextScreen() {
  backUntil = Date.now() + HINT_MS;
}

function reportScreen(next: Screen, quiet: boolean) {
  const was = screen;
  screen = next;
  if (!was || (was.id === next.id && was.item === next.item)) {
    return;
  }
  const now = Date.now();
  const silent = quiet || now < quietUntil;
  const forcedBack = now < backUntil;
  quietUntil = 0;
  backUntil = 0;
  if (silent || muted || hidden()) {
    return;
  }
  let kind: WipeKind = 'screen';
  let up = false;
  if (was.id === next.id) {
    // The same screen on another record: a stepper.
    kind = 'page';
    up = next.order < was.order;
  } else if (forcedBack || was.id === 'confirmed') {
    up = true;
  } else if (tabOf(was.id) === tabOf(next.id)) {
    up = next.depth < was.depth;
  }
  if (kind === 'page') {
    sfx('page', { rate: up ? 0.9 : 1 });
  } else {
    sfx(up ? 'back' : 'wipe');
  }
  screenWipeAt = Date.now();
  playMain({ kind, up: kind === 'screen' && up });
}

let quietCloseUntil = 0;

/** The dialog about to close was answered, not backed out of: it goes without the back sound. */
export function quietDialogClose() {
  quietCloseUntil = Date.now() + 4000;
}

/**
 * A dialog closed: the wipe runs back over the px rect of the main region where it was, with
 * the back sound, unless it was answered (quietDialogClose) or the screen under it changed in
 * the same moment (that change has its own wipe).
 */
export function closeDialogFx(rect: Px) {
  const answered = Date.now() < quietCloseUntil;
  quietCloseUntil = 0;
  if (muted || hidden()) {
    return;
  }
  playMain({ kind: 'screen', up: true, rect });
  if (answered) {
    return;
  }
  setTimeout(() => {
    if (Date.now() - screenWipeAt > 100) {
      sfx('back');
    }
  }, 0);
}

/**
 * Tells the shell which screen the main box shows. id: 'tab/screen'; depth: how far in it is
 * (a deeper screen opens forward, a shallower one is a step back); item and order: the record
 * a stepper is on and its place in the list. quiet: the shell opened it, not the player.
 */
export function useScreen(
  id: string,
  depth = 0,
  item = '',
  order = 0,
  quiet = false,
) {
  useLayoutEffect(() => {
    reportScreen({ id, depth, item, order }, quiet);
  }, [id, depth, item, order]);
}

/** Forgets the screen, so the next one reported opens without a cover (the page starting over). */
export function resetScreen() {
  screen = null;
}

/**
 * The shell's cover over the main box, played when the reported screen changes; also the
 * cover over a dialog that has just closed. Mount it once, in the main region.
 */
export function ScreenWipe(props: { style: Px; z?: number }) {
  const [run, setRun] = useState<ScreenPlay | null>(null);
  const timer = useRef<ReturnType<typeof setTimeout> | null>(null);
  useLayoutEffect(() => {
    const onPlay = (next: ScreenPlay) => {
      setRun(next);
      if (timer.current) {
        clearTimeout(timer.current);
      }
      timer.current = setTimeout(
        () => {
          timer.current = null;
          setRun(null);
        },
        WIPE_MS[next.kind] + 50,
      );
    };
    screenSubs.add(onPlay);
    return () => {
      screenSubs.delete(onPlay);
      if (timer.current) {
        clearTimeout(timer.current);
      }
    };
  }, []);
  return cover(
    run ? { serial: run.serial, back: run.up } : null,
    run ? run.kind : 'screen',
    !!run?.up,
    'bg',
    run?.rect || props.style,
    run?.rect ? 9 : props.z,
  );
}

// ---------------------------------------------------------------------------
// Pulses and blinks
// ---------------------------------------------------------------------------

export type PulseKind = 'w' | 'inva' | 'blink3';

const PULSE_MS: Record<PulseKind, number> = {
  w: 200,
  inva: 240,
  blink3: 960,
};

/**
 * Restarts a short animation on the returned ref's element when `value` changes (never when
 * it first appears). 'w': the text flashes white for 200 ms. 'inva': inverse amber for 240 ms.
 * 'blink3': blinks three times, 160 ms on and 160 ms off.
 */
export function usePulse<T extends HTMLElement>(
  value: unknown,
  kind: PulseKind = 'w',
) {
  const ref = useRef<T | null>(null);
  const prev = useRef(value);
  useEffect(() => {
    const was = prev.current;
    prev.current = value;
    if (Object.is(was, value) || was === undefined || was === null) {
      return;
    }
    const el = ref.current;
    if (!el || hidden()) {
      return;
    }
    el.removeAttribute('data-pulse');
    // Reading the box restarts the animation when the attribute comes back.
    void el.offsetWidth;
    el.setAttribute('data-pulse', kind);
    const id = setTimeout(
      () => el.removeAttribute('data-pulse'),
      PULSE_MS[kind] + 40,
    );
    return () => clearTimeout(id);
  }, [value]);
  return ref;
}

/** TRUE and FALSE in turn, `ms` each, while `on` and the page is showing; FALSE otherwise. */
export function useBlink(on: boolean, ms: number): boolean {
  const [lit, setLit] = useState(false);
  useEffect(() => {
    if (!on) {
      setLit(false);
      return;
    }
    const id = setInterval(() => {
      setLit((v) => (hidden() ? false : !v));
    }, ms);
    return () => clearInterval(id);
  }, [on, ms]);
  return on && lit;
}

/** Calls fn when `value` changes (never when it first appears), with the value before. */
export function useChanged<T>(value: T, fn: (was: T, now: T) => void) {
  const prev = useRef(value);
  const ref = useRef(fn);
  ref.current = fn;
  useEffect(() => {
    const was = prev.current;
    prev.current = value;
    if (!Object.is(was, value)) {
      ref.current(was, value);
    }
  }, [value]);
}

/**
 * The same, before the browser paints: for a change whose animation must start in the very
 * frame the new value shows, so the end state is never seen ahead of it. State set in fn is
 * drawn in that same frame.
 */
export function useChangedNow<T>(value: T, fn: (was: T, now: T) => void) {
  const prev = useRef(value);
  const ref = useRef(fn);
  ref.current = fn;
  useLayoutEffect(() => {
    const was = prev.current;
    prev.current = value;
    if (!Object.is(was, value)) {
      ref.current(was, value);
    }
  }, [value]);
}

/** Pauses every running animation under the returned ref's element while the page is hidden. */
export function usePauseWhenHidden<T extends HTMLElement>() {
  const ref = useRef<T | null>(null);
  useEffect(() => {
    const sync = () => {
      const el = ref.current;
      if (!el) {
        return;
      }
      if (document.hidden) {
        el.setAttribute('data-paused', '');
      } else {
        el.removeAttribute('data-paused');
      }
    };
    sync();
    document.addEventListener('visibilitychange', sync);
    return () => document.removeEventListener('visibilitychange', sync);
  }, []);
  return ref;
}

/**
 * Keyframes and classes. --lw (the line weight in px) is set on .lt-tui by the shell.
 *
 * Step counts: a cover uses steps(n, end), so it shows n positions, the first of them whole, and
 * is gone at the end; READY's fill does too, so it lands at the very end, when [#] appears. A band
 * being drawn uses steps(n, start), so its first step shows at once and it is whole for the last.
 */
export const MOTION_CSS = `
[data-paused] * { animation-play-state: paused !important; }
.lt-tui [data-press] { background: #fff !important; border-color: #fff !important; color: var(--lt-ink) !important;
  text-shadow: none !important; }
.lt-tui [data-press] span { color: var(--lt-ink) !important; text-shadow: none !important; }
.lt-tui .lt-hit[data-press] { background: rgba(255,255,255,.8) !important; }
.lt-tui .lt-vscreen[data-press] { background: #07030d !important; border-color: #3a2466 !important; }
.lt-tui input[data-press] { background: transparent !important; color: var(--lt-fg) !important; }
.lt-wipe { position: absolute; overflow: hidden; pointer-events: none; z-index: 6; }
.lt-wipe-c { position: absolute; left: 0; top: 0; width: 100%; height: 100%; box-sizing: border-box;
  background: var(--lt-bg, #0f0620); border: 0 solid var(--lt-fg, #dfc4ff); animation-fill-mode: forwards; }
.lt-wipe-c.is-well { background: #07030d; }
.lt-wipe-c.is-down { border-top-width: var(--lw, 2px); animation-name: lt-wipe-down;
  box-shadow: 0 calc(var(--lw, 2px) * -1) calc(var(--lw, 2px) * 3) rgba(190,140,255,.55); }
.lt-wipe-c.is-up { border-bottom-width: var(--lw, 2px); animation-name: lt-wipe-up;
  box-shadow: 0 var(--lw, 2px) calc(var(--lw, 2px) * 3) rgba(190,140,255,.55); }
.lt-wipe-c.is-screen { animation-duration: 160ms; animation-timing-function: steps(8, end); }
.lt-wipe-c.is-page { animation-duration: 100ms; animation-timing-function: steps(5, end); }
.lt-wipe-c.is-slot { animation-duration: 120ms; animation-timing-function: steps(4, end); }
.lt-wipe-c.is-draw { border-top-width: 0; border-left-width: var(--lw, 2px); box-shadow: none;
  animation: lt-wipe-right 120ms steps(6, end) forwards; }
@keyframes lt-wipe-down { from { transform: translateY(0); } to { transform: translateY(100%); } }
@keyframes lt-wipe-up { from { transform: translateY(0); } to { transform: translateY(-100%); } }
@keyframes lt-wipe-right { from { transform: translateX(0); } to { transform: translateX(100%); } }
.lt-flashbar { position: absolute; z-index: 6; pointer-events: none; background: #fff;
  animation: lt-flashbar 200ms steps(2, end) forwards; }
@keyframes lt-flashbar { from { opacity: .9; } to { opacity: 0; } }
.lt-tui [data-pulse="w"] { animation: lt-pulse-w 200ms steps(1, end); }
@keyframes lt-pulse-w { from, to { color: #fff; text-shadow: 0 0 6px #fff; } }
.lt-tui [data-pulse="inva"] { animation: lt-pulse-inva 240ms steps(1, end); }
@keyframes lt-pulse-inva { from, to { background: var(--lt-amb); color: var(--lt-ink); text-shadow: none; } }
@keyframes lt-draw { from { transform: scaleX(0); } to { transform: scaleX(1); } }
.lt-tui [data-pulse="blink3"], .lt-tui .lt-blink3 { animation: lt-blink3 320ms steps(1, end) 3; }
@keyframes lt-blink3 { 0% { opacity: 1; } 50% { opacity: 0; } }
.lt-tui .lt-draw { transform-origin: 0 50%; animation: lt-draw 120ms steps(6, start); }
.lt-tui .lt-draw-bad { transform-origin: 0 50%;
  animation: lt-draw 120ms steps(6, start), lt-blink2 240ms steps(1, end) 120ms 2; }
@keyframes lt-blink2 { 0% { opacity: .55; } 50% { opacity: 1; } }
.lt-tui .lt-fill { position: absolute; left: 0; top: 0; width: 100%; height: 100%; background: var(--lt-acc);
  transform-origin: 0 50%; pointer-events: none; animation-fill-mode: forwards; }
.lt-tui .lt-fill.is-on { animation: lt-fill-on 180ms steps(6, end) forwards; }
.lt-tui .lt-fill.is-off { animation: lt-fill-off 120ms steps(4, end) forwards; }
@keyframes lt-fill-on { from { transform: scaleX(0); } to { transform: scaleX(1); } }
@keyframes lt-fill-off { from { transform: scaleX(1); } to { transform: scaleX(0); } }
.lt-tui .lt-k.is-busy span { animation: lt-vblink 1.06s steps(1) infinite; }
.lt-tui .lt-light { position: absolute; z-index: 5; pointer-events: none; background: var(--lt-bg);
  animation: lt-light 40ms steps(1, end) both; }
@keyframes lt-light { from { opacity: .62; } to { opacity: 0; } }
.lt-tui .lt-turn-a { animation: lt-turn-a 60ms steps(2, start) forwards; }
.lt-tui .lt-turn-b { animation: lt-turn-b 60ms steps(2, end) forwards; }
.lt-tui .lt-turn-hold { transform: scaleX(.2); }
@keyframes lt-turn-a { from { transform: scaleX(1); } to { transform: scaleX(.2); } }
@keyframes lt-turn-b { from { transform: scaleX(.2); } to { transform: scaleX(1); } }
`;
