/**
 * The colour ship picture (spec 02, 5.1): the yard's real pre-rendered preview inside a Well,
 * the finish's hull picture with each picked module laid on its slot, the same compositing as
 * ShipPreview in ShipUpgradeSelector.tsx (module connector tile onto the slot marker tile).
 *
 * Scale: whole screen pixels per tile, the largest that fits inside a padding of 4 * lw. 32 px
 * tiles or more snap down to a multiple of 32 and draw pixelated; anything smaller is a smooth
 * downscale at a whole number of px per tile, so tiles never land between pixels.
 *
 * Missing pictures: no preview data, a well too small to hold one, or a hull layer that never
 * arrives show `NO PICTURE ON FILE`. While the layers are on their way the well is empty. A
 * module layer that never arrives is left out, so that room shows the bare hull.
 */
import { type CSSProperties, type ReactNode, useEffect, useState } from 'react';
import { resolveAsset } from 'tgui/assets';

import { useGrid, Well } from './term';
import type { ShipFit } from './YardTab';

/** Retries before a layer counts as missing: 20 x 250 ms = 5 s. */
const TRIES = 20;
const RETRY_MS = 250;

export const NO_PICTURE = 'NO PICTURE ON FILE';

/**
 * A preview layer that keeps trying until its file has arrived. The first time a hull is opened
 * its PNGs (and the URL mappings) are still on their way to the client, so the first load can
 * fail; retry, re-resolving the asset name each time. `onMissing` once it gives up.
 */
function PreviewImg(props: {
  name: string;
  style: CSSProperties;
  onMissing?: () => void;
}) {
  const { name, style, onMissing } = props;
  const [tries, setTries] = useState(0);
  const [gone, setGone] = useState(false);
  useEffect(() => {
    if (gone) {
      onMissing?.();
    }
  }, [gone]);
  if (gone) {
    return null;
  }
  // A new key remounts the <img>, so the browser asks for the file again.
  return (
    <img
      key={tries}
      src={resolveAsset(name)}
      style={style}
      onError={() => {
        if (tries < TRIES) {
          setTimeout(() => setTries((n) => n + 1), RETRY_MS);
        } else {
          setGone(true);
        }
      }}
    />
  );
}

type Geom = {
  png: string;
  width: number;
  height: number;
  connector?: [number, number];
};

type PreviewData = {
  tile_px?: number;
  hulls: Record<string, Geom & { slots: Record<string, [number, number]> }>;
  modules: Record<string, Geom & { themes?: Record<string, Geom> }>;
};

export function ShipPic(props: {
  /** Cells; y and h may be quarter rows. */
  x: number;
  y: number;
  w: number;
  h: number;
  fit: ShipFit;
  /** Slot key of the room to mark (the fit's current room), or null. */
  hiSlot?: string | null;
}) {
  const { x, y, w, h, fit, hiSlot } = props;
  const { cw, ch, lw, s } = useGrid();
  const pv = fit.hull.preview as PreviewData | null;
  const themeKey = fit.finish?.id || '';
  const hull = pv?.hulls?.[themeKey] || pv?.hulls?.[''];
  const hullPng = hull?.png || '';
  /** The hull picture that never arrived, if any. */
  const [missing, setMissing] = useState<string | null>(null);

  // The well's inside: its rect less the 1 px screen border on each side.
  const sw = Math.round((x + w) * cw) - Math.round(x * cw) - 2;
  const sh = Math.round((y + h) * ch) - Math.round(y * ch) - 2;
  const pad = 4 * lw;
  const small = sw < 8 * lw + 8 || sh < 8 * lw + 8;
  if (!pv || !hull || small || missing === hullPng) {
    return <Well x={x} y={y} w={w} h={h} note={NO_PICTURE} />;
  }

  const tile = pv.tile_px || 32;
  const aw = sw - pad * 2;
  const ah = sh - pad * 2;
  let d = Math.floor(Math.min(aw / hull.width, ah / hull.height));
  const crisp = d >= tile;
  if (crisp) {
    d = Math.floor(d / tile) * tile;
  }
  d = Math.max(1, d);
  const iw = hull.width * d;
  const ih = hull.height * d;
  const rendering = crisp ? 'pixelated' : 'auto';

  const layers: ReactNode[] = [
    <PreviewImg
      key={`hull-${hullPng}`}
      name={hullPng}
      onMissing={() => setMissing(hullPng)}
      style={{
        position: 'absolute',
        left: 0,
        top: 0,
        width: iw,
        height: ih,
        imageRendering: rendering,
      }}
    />,
  ];
  let mark: { l: number; t: number; w: number; h: number } | null = null;
  for (const slot of fit.slots) {
    const marker = hull.slots?.[slot.key];
    if (!marker) {
      continue;
    }
    const mod = slot.pick ? pv.modules?.[slot.pick.id] : undefined;
    if (!mod) {
      if (slot.key === hiSlot) {
        // No picture for this room: the marker goes round its marker tile alone.
        mark = {
          l: (marker[0] - 1) * d,
          t: (hull.height - marker[1]) * d,
          w: d,
          h: d,
        };
      }
      continue;
    }
    const g = (themeKey && mod.themes?.[themeKey]) || mod;
    const [cx, cy] = g.connector || [1, 1];
    const l = (marker[0] - cx) * d;
    const t = (hull.height - (marker[1] - cy) - g.height) * d;
    layers.push(
      <PreviewImg
        key={`m-${slot.key}-${g.png}`}
        name={g.png}
        style={{
          position: 'absolute',
          left: l,
          top: t,
          width: g.width * d,
          height: g.height * d,
          imageRendering: rendering,
        }}
      />,
    );
    if (slot.key === hiSlot) {
      mark = { l, t, w: g.width * d, h: g.height * d };
    }
  }
  if (mark) {
    // An outline lw wide, one lw outside the room's rect, white with the violet glow. Still.
    layers.push(
      <div
        key="mark"
        style={{
          position: 'absolute',
          left: mark.l - 2 * lw,
          top: mark.t - 2 * lw,
          width: mark.w + 4 * lw,
          height: mark.h + 4 * lw,
          boxSizing: 'border-box',
          border: `${lw}px solid var(--lt-wht)`,
          boxShadow: `0 0 ${Math.round(6 * s)}px rgba(190,140,255,.9)`,
          zIndex: 2,
        }}
      />,
    );
  }

  return (
    <Well x={x} y={y} w={w} h={h}>
      <div
        style={{
          position: 'absolute',
          width: iw,
          height: ih,
          left: Math.round((sw - iw) / 2),
          top: Math.round((sh - ih) / 2),
        }}
      >
        {layers}
      </div>
    </Well>
  );
}
