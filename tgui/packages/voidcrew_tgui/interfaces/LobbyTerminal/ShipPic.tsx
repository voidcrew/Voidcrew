/**
 * The yard's real full-colour preview on a recessed viewscreen: the finish's hull picture
 * with each picked module laid on its slot, the same compositing as ShipPreview in
 * ShipUpgradeSelector.tsx (module connector tile onto the slot marker tile).
 *
 * Scale: whole screen pixels per tile. 32 px tiles or more snap to a multiple of 32 and
 * draw pixelated; anything smaller is a smooth downscale at a whole number of px per tile,
 * so tiles never land between pixels.
 */
import type { CSSProperties, ReactNode } from 'react';
import { resolveAsset } from 'tgui/assets';

import { useGrid } from './term';
import type { ShipFit } from './YardTab';

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

const PAD = 10;

export function ShipPic(props: {
  /** Cells; fractions allowed. */
  x: number;
  y: number;
  w: number;
  h: number;
  fit: ShipFit;
  /** Slot key to outline in amber, or null. */
  hiSlot?: string | null;
}) {
  const { x, y, w, h, fit, hiSlot } = props;
  const { cw, ch } = useGrid();
  const sx = Math.round(x * cw);
  const sy = Math.round(y * ch);
  const sw = Math.round(w * cw);
  const sh = Math.round(h * ch);
  const frame: CSSProperties = {
    left: sx,
    top: sy,
    width: sw,
    height: sh,
  };

  const pv = fit.hull.preview as PreviewData | null;
  const themeKey = fit.finish?.id || '';
  const hull = pv?.hulls?.[themeKey] || pv?.hulls?.[''];
  if (!pv || !hull || sw <= PAD * 2 || sh <= PAD * 2) {
    return (
      <div className="lt-vscreen" style={frame}>
        <div className="lt-vscan" />
      </div>
    );
  }

  const tile = pv.tile_px || 32;
  const aw = sw - PAD * 2;
  const ah = sh - PAD * 2;
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
    <img
      key="hull"
      src={resolveAsset(hull.png)}
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
  for (const slot of fit.slots) {
    const marker = hull.slots?.[slot.key];
    const mod = slot.pick ? pv.modules?.[slot.pick.id] : undefined;
    if (!marker || !mod) {
      continue;
    }
    const g = (themeKey && mod.themes?.[themeKey]) || mod;
    const [cx, cy] = g.connector || [1, 1];
    const l = (marker[0] - cx) * d;
    const t = (hull.height - (marker[1] - cy) - g.height) * d;
    layers.push(
      <img
        key={`m-${slot.key}`}
        src={resolveAsset(g.png)}
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
      layers.push(
        <div
          key={`hi-${slot.key}`}
          style={{
            position: 'absolute',
            left: l - 2,
            top: t - 2,
            width: g.width * d,
            height: g.height * d,
            border: '2px solid var(--lt-amb)',
            boxShadow:
              '0 0 8px rgba(255,196,31,.6), inset 0 0 8px rgba(255,196,31,.35)',
            zIndex: 2,
          }}
        />,
      );
    }
  }

  return (
    <div className="lt-vscreen" style={frame}>
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
      <div className="lt-vscan" />
    </div>
  );
}
