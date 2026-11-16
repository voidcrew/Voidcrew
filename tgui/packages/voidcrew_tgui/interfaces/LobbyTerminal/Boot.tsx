/**
 * The terminal's start-up screen: the tube powers on, the Voidcrew symbol assembles, the name
 * types out, a bar fills, and a LOGIN button waits for the player. Shown once per connection
 * (data.boot, lobby_bezel.dm); LOGIN tells the server it has been seen.
 *
 * Mount it inside the screen glass. It fills its parent and sizes itself from the glass rect
 * alone, so the frame around it can change freely. It sits at z-index 20 in the glass's
 * stacking order, above everything the terminal draws. Its children are drawn over it: pass
 * the tube's scanline and glass layers when they sit lower than that, or it would hide them.
 * While it is up it owns the keyboard (lockNav) and a clear sheet over the whole page keeps
 * the mouse off the lobby underneath.
 *
 * It can never hold a player out of the lobby: with no sound it plays silent, and if anything
 * throws it steps aside.
 */
import {
  Component,
  type ReactNode,
  useEffect,
  useLayoutEffect,
  useRef,
  useState,
} from 'react';
import { createPortal } from 'react-dom';
import { useBackend } from 'tgui/backend';

import { audioState, isLoaded, play, preload, stop, unload } from './audio';
import { renderEmblem } from './emblemDraw';
import { lockNav } from './nav';
import type { LobbyData } from './types';

// ---------------------------------------------------------------------------
// Timeline. Seconds from the moment the power-on line appears.
// ---------------------------------------------------------------------------

const FPS = 24;
/** Sounds are scheduled this far ahead and the picture waits as long, so no sound loses its first instant. */
const LEAD = 0.1;
/** The power-on line holds, then collapses to the centre. */
const LINE_HOLD = 0.25;
const LINE_END = 0.45;
/** The disc grows in. */
const DISC_AT = 0.45;
const DISC_TIME = 1.1;
/** The V appears, spinning, and comes to rest at LOCK_AT. */
const V_AT = 0.9;
const V_TURNS = 5;
const LOCK_AT = 3.2;
const FLASH_TIME = 0.12;
/** The tick ring and the three arcs sweep in. */
const HUD_AT = 1.0;
const HUD_TIME = 1.2;
/** One letter of the name, and one block of the bar, every STEP. */
const STEP = 0.09;
const NAME = 'VOIDCREW';
const BAR_SHOWN_AT = 3.4;
const BAR_AT = 4.0;
const BLOCKS = 16;
const DONE_AT = 5.56;
const LOGIN_AT = 5.7;
/** After LOGIN: a beat, then the fade to the lobby. */
const FADE_HOLD = 0.15;
const FADE_TIME = 0.45;

/** Canvas the symbol and its start-up rings are drawn in, in art pixels, and the symbol's scale in it. */
const CANVAS = 190;
const CANVAS_K = 1.45;

const SND_POWER = 'lt_boot_power.ogg';
const SND_SEQ = 'lt_boot_seq.ogg';
const SND_KEY = 'lt_boot_key.ogg';
const SND_TICK = 'lt_boot_tick.ogg';
const SND_DONE = 'lt_boot_done.ogg';
const SND_LOGIN = 'lt_boot_login.ogg';
const SOUNDS = [SND_POWER, SND_SEQ, SND_KEY, SND_TICK, SND_DONE, SND_LOGIN];
/** Only the start-up screen plays these; the keystroke and the tick stay loaded for the lobby. */
const ONE_TIME_SOUNDS = [SND_POWER, SND_SEQ, SND_DONE, SND_LOGIN];

type Cue = {
  t: number;
  id: string;
  rate?: number;
  /** A long clip: if its moment has passed it joins part-way in instead of being dropped. */
  long?: boolean;
};

const KEY_RATES = [1, 0.97, 1.04, 0.99, 1.02, 0.96, 1.03, 1];

const CUES: Cue[] = [
  { t: 0, id: SND_POWER },
  { t: DISC_AT, id: SND_SEQ, long: true },
  // One keystroke per letter.
  ...KEY_RATES.map((rate, i) => ({
    t: LOCK_AT + STEP * (i + 1),
    id: SND_KEY,
    rate,
  })),
  // One tick per block, rising in pitch.
  ...Array.from({ length: BLOCKS }, (_, i) => ({
    t: BAR_AT + STEP * (i + 1),
    id: SND_TICK,
    rate: 1 + i * 0.035,
  })),
  { t: DONE_AT, id: SND_DONE },
];

/** With sound running, cues are handed to the audio clock this far ahead, so a busy page can't delay them. */
const CUE_AHEAD = 1;
/** A short cue this late is dropped; playing it now would be out of step with the picture. */
const CUE_LATE = 0.05;

/** The screen stays dark this long at most waiting for its sounds and font, then starts anyway. */
const HOLD_FOR_ASSETS_MS = 6000;
/** And this long at most for the server to say the screen is showing. */
const HOLD_FOR_SHOWN_MS = 12000;

const ease = (x: number) => 1 - (1 - Math.min(1, Math.max(0, x))) ** 3;

/**
 * CSS px per art pixel for the start-up screen: the largest whole number of device pixels
 * that keeps the symbol, the name and LOGIN clear of each other inside the glass.
 */
export function bootPixel(glassW: number, glassH: number, dpr: number) {
  const ratio = dpr > 0 ? dpr : 1;
  const fit = Math.floor(Math.min(glassH / 270, glassW / 250));
  const css = Math.max(1, Math.min(8, fit));
  return Math.max(1, Math.round(css * ratio)) / ratio;
}

/** TRUE once the terminal font has loaded, so the name never draws in a stand-in font. */
function fontReady() {
  try {
    for (const face of Array.from(document.fonts)) {
      if (
        face.family.replace(/["']/g, '') === 'VCR' &&
        face.status === 'loaded'
      ) {
        return true;
      }
    }
  } catch {
    return true;
  }
  return false;
}

type Stage = 'hold' | 'run' | 'off';

type Props = {
  /** The screen glass, in CSS px. */
  glassW: number;
  glassH: number;
  dpr: number;
  /** Layers drawn over the start-up screen (scanlines, glass). */
  children?: ReactNode;
};

/** The start-up screen. Draws nothing once it has played or when the server says it already has. */
export function Boot(props: Props) {
  const { data, act } = useBackend<LobbyData>();
  const [stage, setStage] = useState<Stage>(() => (data.boot ? 'hold' : 'off'));
  /** What the run started with, sent with LOGIN so the server log can say whether clients get the sound. */
  const report = useRef({ sound: 'none', clips: 0, wait: 0 });
  const leave = () => {
    act('boot_done', { ...report.current, failed: 1 });
    setStage('off');
  };
  if (stage === 'off') {
    return null;
  }
  return (
    <BootGuard onError={leave}>
      <BootScreen
        {...props}
        stage={stage}
        shown={data.boot === 2}
        seen={!data.boot}
        onRun={(wait) => {
          report.current = {
            sound: audioState(),
            clips: SOUNDS.filter(isLoaded).length,
            wait: Math.round(wait),
          };
          setStage('run');
        }}
        onLogin={() => act('boot_done', report.current)}
        onDone={() => setStage('off')}
      />
    </BootGuard>
  );
}

/** A render error in the start-up screen must never take the lobby with it. */
class BootGuard extends Component<
  { children: ReactNode; onError: () => void },
  { failed: boolean }
> {
  state = { failed: false };
  static getDerivedStateFromError() {
    return { failed: true };
  }
  componentDidCatch() {
    lockNav(false);
    this.props.onError();
  }
  render() {
    return this.state.failed ? null : this.props.children;
  }
}

function BootScreen(
  props: Props & {
    stage: Stage;
    /** The server says the terminal is on the player's screen. */
    shown: boolean;
    /** The server says this connection has already seen it. */
    seen: boolean;
    /** Starts the run; `waited` is how long the screen stayed dark, in ms. */
    onRun: (waited: number) => void;
    onLogin: () => void;
    onDone: () => void;
  },
) {
  const { glassW, glassH, dpr, stage, shown, seen, children } = props;
  const px = bootPixel(glassW, glassH, dpr);
  const snap = (v: number) => Math.round(v * dpr) / dpr;

  const root = useRef<HTMLDivElement | null>(null);
  const canvas = useRef<HTMLCanvasElement | null>(null);
  const line = useRef<HTMLDivElement | null>(null);
  const word = useRef<HTMLDivElement | null>(null);
  const blocks = useRef<HTMLDivElement | null>(null);
  const login = useRef<HTMLDivElement | null>(null);
  const shield = useRef<HTMLDivElement | null>(null);
  /** The callbacks change every render; the loops below read them from here. */
  const live = useRef(props);
  live.current = props;

  // The keyboard and the mouse belong to this screen for as long as it is up.
  useLayoutEffect(() => {
    lockNav(true);
    return () => lockNav(false);
  }, []);

  // Dark until the screen is showing and its sounds and font are in, or the wait runs out.
  const [assets, setAssets] = useState(false);
  const mountedAt = useRef(performance.now());
  useEffect(() => {
    let alive = true;
    preload(SOUNDS).then(() => alive && setAssets(true));
    return () => {
      alive = false;
    };
  }, []);
  useEffect(() => {
    if (stage !== 'hold') {
      return;
    }
    if (seen) {
      live.current.onDone();
      return;
    }
    const check = () => {
      const waited = performance.now() - mountedAt.current;
      const loaded = (assets && fontReady()) || waited > HOLD_FOR_ASSETS_MS;
      if ((shown && loaded) || waited > HOLD_FOR_SHOWN_MS) {
        live.current.onRun(waited);
      }
    };
    check();
    const timer = setInterval(check, 50);
    return () => clearInterval(timer);
  }, [stage, shown, seen, assets]);

  // The run: one loop draws the picture at 24 frames a second and hands the sounds to the audio clock.
  const loginAt = useRef<number | null>(null);
  const loginUp = useRef(false);
  const pressLogin = useRef<() => void>(() => undefined);
  useEffect(() => {
    if (stage !== 'run') {
      return;
    }
    const start = performance.now() + LEAD * 1000;
    const pending = CUES.slice();
    let raf = 0;
    let lastStep = -1;
    let ended = false;

    const finish = () => {
      if (ended) {
        return;
      }
      ended = true;
      cancelAnimationFrame(raf);
      unload(ONE_TIME_SOUNDS);
      live.current.onDone();
    };

    const cue = (now: number) => {
      const at = (now - start) / 1000;
      const ahead = audioState() === 'running' ? CUE_AHEAD : 0;
      while (pending.length && pending[0].t - at <= ahead) {
        const next = pending.shift() as Cue;
        const wait = next.t - at;
        if (wait >= -CUE_LATE) {
          play(next.id, { when: Math.max(0, wait), rate: next.rate });
        } else if (next.long && isLoaded(next.id)) {
          play(next.id, { offset: -wait, rate: next.rate });
        }
      }
    };

    const draw = (tau: number) => {
      const lineEl = line.current;
      if (lineEl) {
        lineEl.style.display = tau >= 0 && tau < LINE_END ? 'block' : 'none';
        const width =
          tau < LINE_HOLD
            ? 1
            : Math.max(0, 1 - (tau - LINE_HOLD) / (LINE_END - LINE_HOLD));
        lineEl.style.transform = `scaleX(${width})`;
      }
      const canvasEl = canvas.current;
      if (canvasEl) {
        if (tau < 0) {
          canvasEl.style.visibility = 'hidden';
        } else {
          canvasEl.style.visibility = 'visible';
          renderEmblem(canvasEl, {
            t: tau,
            k: CANVAS_K,
            grow: tau < DISC_AT ? 0 : ease((tau - DISC_AT) / DISC_TIME),
            yaw: (1 - ease(tau / LOCK_AT)) * V_TURNS * Math.PI * 2,
            v: tau > V_AT,
            ring: tau * 2.4,
            hud: tau < HUD_AT ? 0 : (tau - HUD_AT) / HUD_TIME,
          });
          const flash = tau > LOCK_AT && tau < LOCK_AT + FLASH_TIME;
          canvasEl.style.filter = flash ? 'brightness(2.2)' : '';
        }
      }
      const wordEl = word.current;
      if (wordEl) {
        const letters = Math.max(
          0,
          Math.min(NAME.length, Math.floor((tau - LOCK_AT) / STEP)),
        );
        const text = NAME.slice(0, letters) + ' '.repeat(NAME.length - letters);
        if (wordEl.textContent !== text) {
          wordEl.textContent = text;
        }
      }
      const blocksEl = blocks.current;
      if (blocksEl) {
        const filled = Math.max(0, Math.floor((tau - BAR_AT) / STEP));
        for (let i = 0; i < blocksEl.children.length; i++) {
          blocksEl.children[i].classList.toggle('f', i < filled);
        }
        blocksEl.style.visibility =
          tau > BAR_SHOWN_AT && tau < LOGIN_AT ? 'visible' : 'hidden';
      }
      const loginEl = login.current;
      if (loginEl) {
        loginUp.current = tau >= LOGIN_AT;
        loginEl.style.visibility = loginUp.current ? 'visible' : 'hidden';
      }
    };

    const frame = (now: number) => {
      try {
        if (loginAt.current !== null) {
          const since = (now - loginAt.current) / 1000;
          if (since > FADE_HOLD + FADE_TIME + 0.05) {
            finish();
            return;
          }
          if (root.current) {
            root.current.style.opacity = String(
              Math.max(0, Math.min(1, 1 - (since - FADE_HOLD) / FADE_TIME)),
            );
          }
        }
        cue(now);
        const step = Math.floor(((now - start) / 1000) * FPS);
        if (step !== lastStep) {
          lastStep = step;
          draw(step / FPS);
        }
        raf = requestAnimationFrame(frame);
      } catch {
        // A browser that can't draw this still gets its lobby.
        if (loginAt.current === null) {
          live.current.onLogin();
        }
        finish();
      }
    };

    pressLogin.current = () => {
      if (!loginUp.current || loginAt.current !== null || ended) {
        return;
      }
      loginAt.current = performance.now();
      play(SND_LOGIN);
      live.current.onLogin();
    };
    raf = requestAnimationFrame(frame);
    return () => {
      ended = true;
      cancelAnimationFrame(raf);
      pressLogin.current = () => undefined;
      for (const id of SOUNDS) {
        stop(id);
      }
    };
  }, [stage]);

  // Keys: Enter or Space presses LOGIN; the terminal's other keys do nothing until then.
  useEffect(() => {
    const onKey = (e: KeyboardEvent) => {
      if (e.ctrlKey || e.altKey || e.metaKey) {
        return;
      }
      if (e.key === 'Enter' || e.key === ' ') {
        e.preventDefault();
        if (!e.repeat && loginUp.current && loginAt.current === null) {
          const el = login.current;
          el?.classList.add('down');
          setTimeout(() => el?.classList.remove('down'), 120);
          pressLogin.current();
        }
        return;
      }
      if (
        e.key.startsWith('Arrow') ||
        e.key === 'Escape' ||
        e.key === 'Backspace' ||
        e.key === 'Tab'
      ) {
        e.preventDefault();
      }
    };
    window.addEventListener('keydown', onKey, true);
    return () => window.removeEventListener('keydown', onKey, true);
  }, []);

  // Mouse: the sheet over the page takes every click; LOGIN is the one place a click does anything.
  const overLogin = (x: number, y: number) => {
    const el = login.current;
    if (!el || !loginUp.current) {
      return false;
    }
    const box = el.getBoundingClientRect();
    return x >= box.left && x < box.right && y >= box.top && y < box.bottom;
  };
  const hover = (x: number, y: number, down?: boolean) => {
    const over = overLogin(x, y);
    login.current?.classList.toggle('hover', over);
    if (down !== undefined || !over) {
      login.current?.classList.toggle('down', over && !!down);
    }
    if (shield.current) {
      shield.current.style.cursor = over ? 'pointer' : 'default';
    }
    return over;
  };

  const size = CANVAS * px;
  const fontPx = Math.round(12 * px);
  const barW = (BLOCKS * 5 + (BLOCKS - 1) * 2) * px;
  return (
    <div
      ref={root}
      className="lt-boot"
      style={{ fontSize: fontPx, ['--bp' as string]: `${px}px` }}
    >
      <style>{BOOT_CSS}</style>
      <canvas
        ref={canvas}
        width={CANVAS}
        height={CANVAS}
        style={{
          left: snap((glassW - size) / 2),
          top: snap(glassH * 0.38 - size / 2),
          width: size,
          height: size,
          visibility: 'hidden',
        }}
      />
      <div
        ref={line}
        className="lt-boot-line"
        style={{ top: snap(glassH / 2), display: 'none' }}
      />
      <div ref={word} className="lt-boot-word" />
      <div
        ref={blocks}
        className="lt-boot-bar"
        style={{ left: snap((glassW - barW) / 2), visibility: 'hidden' }}
      >
        {Array.from({ length: BLOCKS }, (_, i) => (
          <i key={i} />
        ))}
      </div>
      <div className="lt-boot-row">
        <div
          ref={login}
          className="lt-boot-login"
          style={{ visibility: 'hidden' }}
        >
          LOGIN
        </div>
      </div>
      {children}
      {createPortal(
        <div
          ref={shield}
          className="lt-boot-shield"
          onMouseMove={(e) => hover(e.clientX, e.clientY)}
          onMouseDown={(e) => {
            e.preventDefault();
            hover(e.clientX, e.clientY, true);
          }}
          onMouseUp={(e) => hover(e.clientX, e.clientY, false)}
          onMouseLeave={() => hover(-1, -1, false)}
          onClick={(e) => {
            e.stopPropagation();
            if (overLogin(e.clientX, e.clientY)) {
              pressLogin.current();
            }
          }}
        />,
        document.body,
      )}
    </div>
  );
}

/**
 * Sizes are art pixels times --bp (see bootPixel) or em of the start-up screen's own font
 * size, 12 art pixels.
 */
const BOOT_CSS = `
.lt-boot { position: absolute; inset: 0; z-index: 20; overflow: hidden; background: #030008;
  font-family: 'VCR', 'Consolas', monospace; line-height: 1.25; color: #dfc4ff; user-select: none;
  text-shadow: 0 0 calc(var(--bp) * 1.5) rgba(190,140,255,.55); }
.lt-boot canvas { position: absolute; image-rendering: pixelated; }
.lt-boot-line { position: absolute; left: 0; right: 0; height: var(--bp); background: #fff;
  box-shadow: 0 0 12px #c79bff; }
.lt-boot-word { position: absolute; left: 0; right: 0; top: 74%; text-align: center; white-space: pre;
  font-size: 2.1333em; letter-spacing: .5em; padding-left: .5em; color: #fff;
  text-shadow: 0 0 calc(var(--bp) * 3) #a070ff; }
.lt-boot-bar { position: absolute; top: 89%; display: flex; gap: calc(var(--bp) * 2); }
.lt-boot-bar i { display: block; box-sizing: border-box; width: calc(var(--bp) * 5); height: calc(var(--bp) * 5);
  border: var(--bp) solid #5b3f8c; }
.lt-boot-bar i.f { background: #dfc4ff; border-color: #dfc4ff; }
.lt-boot-row { position: absolute; left: 0; right: 0; top: 87%; display: flex; justify-content: center; }
.lt-boot-login { box-sizing: border-box; white-space: pre; letter-spacing: .4em; padding: .25em 1.1em .25em 1.5em;
  color: #dfc4ff; background: rgba(223,196,255,.08); border: var(--bp) solid #dfc4ff;
  animation: lt-boot-pulse 1.2s steps(2) infinite; }
@keyframes lt-boot-pulse { 50% { border-color: #8a66c4; } }
.lt-boot-login.hover { background: #ff66d6; border-color: #ff66d6; color: #1a0420; text-shadow: none; animation: none; }
.lt-boot-login.down { background: #fff; border-color: #fff; color: #1a0420; text-shadow: none; animation: none;
  transform: translateY(var(--bp)); }
.lt-boot-shield { position: fixed; inset: 0; z-index: 2147483000; background: transparent; cursor: default; }
`;
