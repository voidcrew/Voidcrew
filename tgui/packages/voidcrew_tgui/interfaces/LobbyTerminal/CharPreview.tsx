/**
 * The character preview (CHARACTER-PLAN 2.5 / 3): a viewscreen over cells (x, y, w, h)
 * showing the server's render of the dressed mannequin facing dir, on the dark floor tile.
 * Keeps a client cache of char_preview pushes (key -> dir -> png, last 6 looks) and sends
 * char_turn only for a facing it doesn't have for the current look. Keeps the last image on
 * screen while a new one is on its way. The turn keys and dress label around it belong to
 * CharacterTab. Owner: C2.
 */
import { type CSSProperties, useEffect, useRef, useState } from 'react';
import { resolveAsset } from 'tgui/assets';
import { useBackend } from 'tgui/backend';

import { useGrid } from './term';
import type { CellBox, CharDir, LobbyData } from './types';

/** Looks kept client side, as many as the server keeps. */
const LOOKS = 6;
/** Mannequin tile, in sprite pixels. */
const TILE = 32;
/** An unanswered char_turn may be sent again after this long (ms). */
const ASK_AGAIN = 3000;
/** char_face (a turn to a cached facing) goes out at most this often (ms). */
const FACE_EVERY = 400;

type Look = Partial<Record<CharDir, string>>;

export function CharPreview(props: CellBox & { dir: CharDir }) {
  const { x, y, w, h, dir } = props;
  const { cw, ch } = useGrid();
  const { data, act } = useBackend<LobbyData>();
  const pushed = data.char_preview;

  // key -> look, oldest first.
  const cache = useRef(new Map<string, Look>());
  // "key:dir" -> when char_turn asked for it.
  const asked = useRef(new Map<string, number>());
  // The facing the server last heard about (char_turn or char_face), and the one on screen.
  const told = useRef<{ sent: CharDir; want: CharDir; timer: number | null }>({
    sent: 2,
    want: 2,
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
  const [current, setCurrent] = useState<string | null>(null);
  const [shown, setShown] = useState<string | null>(null);
  const [size, setSize] = useState<[number, number]>([TILE, TILE]);

  // Every push goes into the cache; its key becomes the current look.
  useEffect(() => {
    if (!pushed?.png) {
      return;
    }
    const looks = cache.current;
    const look = looks.get(pushed.key) || {};
    look[pushed.dir] = pushed.png;
    looks.delete(pushed.key);
    looks.set(pushed.key, look);
    while (looks.size > LOOKS) {
      looks.delete(looks.keys().next().value as string);
    }
    asked.current.delete(`${pushed.key}:${pushed.dir}`);
    setCurrent(pushed.key);
  }, [pushed?.key, pushed?.dir, pushed?.png]);

  // Show the facing if this look has it; otherwise ask once and keep the last image.
  const png = current ? cache.current.get(current)?.[dir] : undefined;
  useEffect(() => {
    if (png) {
      setShown(png);
      // A cached facing: only tell the server which side is on screen, at most every FACE_EVERY ms.
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
    told.current.sent = dir;
    told.current.want = dir;
    const ask = `${current || ''}:${dir}`;
    const at = asked.current.get(ask);
    if (at === undefined || Date.now() - at > ASK_AGAIN) {
      asked.current.set(ask, Date.now());
      act('char_turn', { dir });
    }
  }, [current, dir, png]);

  const sx = Math.round(x * cw);
  const sy = Math.round(y * ch);
  const sw = Math.round(w * cw);
  const sh = Math.round(h * ch);

  // Largest whole scale that leaves a margin round the tile, as the mockup draws it.
  const k = Math.max(1, Math.floor(Math.min(sw * 0.82, sh * 0.86) / TILE));
  const t = TILE * k;
  const ox = Math.round((sw - t) / 2);
  const oy = Math.round((sh - t) / 2) + Math.round(t * 0.08);
  const [iw, ih] = size;

  const floor: CSSProperties = {
    position: 'absolute',
    inset: 0,
    opacity: 0.38,
    backgroundImage: `url(${resolveAsset('char_floor.png')})`,
    backgroundSize: `${t}px ${t}px`,
    backgroundPosition: `${ox}px ${oy}px`,
    imageRendering: 'pixelated',
  };

  return (
    <div
      className="lt-vscreen"
      style={{ left: sx, top: sy, width: sw, height: sh }}
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
            zIndex: 1,
          }}
        />
      )}
      <div className="lt-vscan" />
    </div>
  );
}
