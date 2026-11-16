/**
 * The viewscreen (design 03 section 2): the server's render of the dressed mannequin facing
 * dir, on the violet floor tile, over cells (x, y, w, h). One focus stop: Enter turns it
 * clockwise. `«` and `»` inside the picture are mouse targets.
 *
 * Keeps a page cache of char_preview pushes (look key -> dir -> png, last LOOKS looks) and
 * sends char_turn only for a facing it doesn't hold for the current look (char.look). While a
 * render is on its way the last picture stays; after PENDING_MS it dims and SCANNING shows.
 */
import { type CSSProperties, useEffect, useRef, useState } from 'react';
import { resolveAsset } from 'tgui/assets';
import { useBackend } from 'tgui/backend';

import { useFocusable } from './nav';
import { Put, useGrid } from './term';
import type { CharDir, LobbyData } from './types';

/** Looks kept page side, as many as the server keeps (LOBBY_CHAR_CACHE_LOOKS). */
const LOOKS = 10;
/** Mannequin tile, in sprite pixels. */
const TILE = 32;
/** An unanswered char_turn is sent again after this long (ms). */
const ASK_AGAIN = 3000;
/** char_face (a turn to a held facing) goes out at most this often (ms). */
const FACE_EVERY = 400;
/** A render this late dims the last picture and shows SCANNING (ms). */
const PENDING_MS = 250;
/** Rows past this only add floor below the picture: the body never jumps between screens. */
const PIC_ROWS = 10.5;

/** Facings in clockwise order: S, W, N, E. */
export const TURN: CharDir[] = [2, 8, 1, 4];

/** The facing `by` steps clockwise from dir. */
export function turned(dir: CharDir, by: number): CharDir {
  const i = TURN.indexOf(dir);
  return TURN[((((i < 0 ? 0 : i) + by) % 4) + 4) % 4];
}

type Look = Partial<Record<CharDir, string>>;

// Kept across mounts while the window lives: switching screens never loses held facings.
const cache = new Map<string, Look>();
const asked = new Map<string, number>();

function store(key: string, dir: CharDir, png: string) {
  const look = cache.get(key) || {};
  look[dir] = png;
  cache.delete(key);
  cache.set(key, look);
  while (cache.size > LOOKS) {
    cache.delete(cache.keys().next().value as string);
  }
  asked.delete(`${key}:${dir}`);
}

export function Viewscreen(props: {
  x: number;
  y: number;
  w: number;
  h: number;
  dir: CharDir;
  /** Turn by one facing: 1 clockwise (`»`, Enter), -1 back (`«`). */
  onTurn: (by: 1 | -1) => void;
  auto?: number;
}) {
  const { x, y, w, h, dir, onTurn } = props;
  const { cw, ch } = useGrid();
  const { data, act } = useBackend<LobbyData>();
  const pushed = data.char_preview;
  const [, setTick] = useState(0);

  // Every push goes into the cache.
  useEffect(() => {
    if (pushed?.png) {
      store(pushed.key, pushed.dir, pushed.png);
      setTick((t) => t + 1);
    }
  }, [pushed?.key, pushed?.dir, pushed?.png]);

  // The look the character has now: char.look, or the last pushed key from an older server.
  const look = data.char?.look || pushed?.key || '';
  const png = look ? cache.get(look)?.[dir] : undefined;

  // The picture on screen: the held facing, else the last one shown.
  const last = useRef<string | null>(null);
  if (png) {
    last.current = png;
  }
  const shown = png || last.current;

  // The server renders its current facing on every edit, so a new look counts as asked.
  const seen = useRef('');
  if (look && look !== seen.current) {
    seen.current = look;
    if (!asked.has(`${look}:${dir}`)) {
      asked.set(`${look}:${dir}`, Date.now());
    }
  }

  const told = useRef<{ sent: CharDir; want: CharDir; timer: number | null }>({
    sent: dir,
    want: dir,
    timer: null,
  });
  useEffect(
    () => () => {
      if (told.current.timer !== null) {
        window.clearTimeout(told.current.timer);
      }
    },
    [],
  );

  // Held: tell the server which side is on screen (rarely). Not held: ask, then every 3 s.
  const [late, setLate] = useState(false);
  useEffect(() => {
    if (!look) {
      return;
    }
    if (png) {
      setLate(false);
      const t = told.current;
      t.want = dir;
      if (t.timer === null) {
        t.timer = window.setTimeout(() => {
          t.timer = null;
          if (t.want !== t.sent) {
            t.sent = t.want;
            act('char_face', { dir: t.want });
          }
        }, FACE_EVERY);
      }
      return;
    }
    const ask = () => {
      const at = asked.get(`${look}:${dir}`);
      if (at === undefined || Date.now() - at >= ASK_AGAIN) {
        asked.set(`${look}:${dir}`, Date.now());
        told.current.sent = dir;
        told.current.want = dir;
        act('char_turn', { dir });
      }
    };
    ask();
    const dim = window.setTimeout(() => setLate(true), PENDING_MS);
    const again = window.setInterval(ask, 500);
    return () => {
      window.clearTimeout(dim);
      window.clearInterval(again);
    };
  }, [look, dir, !!png]);

  const focus = useFocusable<HTMLDivElement>(true, {
    activate: () => onTurn(1),
    auto: props.auto,
  });

  const sx = Math.round(x * cw);
  const sy = Math.round(y * ch);
  const sw = Math.round((x + w) * cw) - sx;
  const sh = Math.round((y + h) * ch) - sy;

  // Scale and tile centre come from at most PIC_ROWS rows, so the body holds still between screens.
  const ph = Math.min(sh, Math.round(PIC_ROWS * ch));
  const k = Math.max(1, Math.floor((Math.min(sw, ph) * 0.93) / TILE));
  const t = TILE * k;
  const ox = Math.round((sw - t) / 2);
  const oy = Math.round((ph - t) / 2);
  const [size, setSize] = useState<[number, number]>([TILE, TILE]);
  const [iw, ih] = size;

  const pending = !png && (late || !shown);
  const floor: CSSProperties = {
    position: 'absolute',
    inset: 0,
    opacity: 0.5,
    backgroundImage: `url(${resolveAsset('char_floor.png')})`,
    backgroundSize: `${t}px ${t}px`,
    backgroundPosition: `${ox}px ${oy}px`,
    imageRendering: 'pixelated',
  };
  const markY = y + h - 1.25;

  return (
    <>
      <div
        ref={focus.ref}
        className={`lt-vscreen${focus.focused ? ' lt-hitfoc' : ''}`}
        style={{ left: sx, top: sy, width: sw, height: sh, cursor: 'pointer' }}
        onMouseEnter={focus.onMouseEnter}
        onClick={(e) => {
          e.stopPropagation();
          onTurn(1);
        }}
      >
        <div style={floor} />
        {!!shown && (
          <img
            src={`data:image/png;base64,${shown}`}
            onLoad={(e) =>
              setSize([
                e.currentTarget.naturalWidth,
                e.currentTarget.naturalHeight,
              ])
            }
            style={{
              position: 'absolute',
              // A render bigger than one tile stays centred on it, feet on the tile.
              left: ox - Math.round(((iw - TILE) * k) / 2),
              top: oy - (ih - TILE) * k,
              width: iw * k,
              height: ih * k,
              imageRendering: 'pixelated',
              opacity: pending ? 0.45 : 1,
              zIndex: 1,
            }}
          />
        )}
        <div className="lt-vscan" />
      </div>
      {pending ? (
        <Put x={x + Math.floor((w - 10) / 2)} y={markY} cls="dim lt-vmark">
          {'SCANNING'}
          <span className="lt-in lt-vblink" />
        </Put>
      ) : (
        <>
          <Put
            x={x + 1}
            y={markY}
            cls="dim lt-vmark"
            hoverCls="inv lt-vmark"
            mouseOnly
            onClick={() => onTurn(-1)}
          >
            {'«'}
          </Put>
          <Put
            x={x + w - 2}
            y={markY}
            cls="dim lt-vmark"
            hoverCls="inv lt-vmark"
            mouseOnly
            onClick={() => onTurn(1)}
          >
            {'»'}
          </Put>
        </>
      )}
    </>
  );
}
