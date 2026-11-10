/**
 * Terminal geometry: bezel scale, the screen rect and the text grid, from the pane size.
 *
 * Bezel: integer pixel-art scale s = clamp(min(floor(H / 360), floor(W / 472)), 1, 4),
 * snapped to whole device pixels so Windows display scaling doesn't blur the art.
 * Grid: font size aims at about 110 columns, independent of s.
 */

/** 1x pixel numbers of the bezel (bezel.json). */
export const BEZEL = {
  baseHeight: 360,
  minWidth: 472,
  screenTop: 15,
  screenSide: 13,
  screenBottom: 52,
  deck: 49,
} as const;

/** Below this many columns or rows, tabs use their narrow (one panel at a time) layout. */
export const NARROW_COLS = 96;
export const NARROW_ROWS = 22;

export type Layout = {
  /** CSS pixels per art pixel (a whole number of device pixels). */
  s: number;
  dpr: number;
  /** Screen rect in CSS px, relative to the pane. */
  screen: { x: number; y: number; w: number; h: number };
  fs: number;
  /** Cell size in CSS px. */
  cw: number;
  ch: number;
  cols: number;
  rows: number;
  /** Grid origin inside the screen. */
  ox: number;
  oy: number;
  narrow: boolean;
};

const clamp = (v: number, lo: number, hi: number) =>
  Math.max(lo, Math.min(hi, v));

/**
 * @param advance width of one character at 1px font size (measured from the real font).
 */
export function computeLayout(
  paneW: number,
  paneH: number,
  dpr: number,
  advance: number,
): Layout {
  const ratio = dpr > 0 ? dpr : 1;
  const sCss = clamp(
    Math.min(
      Math.floor(paneH / BEZEL.baseHeight),
      Math.floor(paneW / BEZEL.minWidth),
    ),
    1,
    4,
  );
  const sDevice = Math.max(1, Math.round(sCss * ratio));
  const s = sDevice / ratio;

  const sx = BEZEL.screenSide * s;
  const sy = BEZEL.screenTop * s;
  const sw = Math.max(0, paneW - 2 * sx);
  const sh = Math.max(0, paneH - sy - BEZEL.screenBottom * s);

  const fs = clamp(Math.floor(sw / (0.6 * 110)), 11, 24);
  const cw = fs * advance;
  const ch = Math.round(fs * 1.2);
  const cols = Math.max(20, Math.floor((sw - 2 * cw) / cw));
  const rows = Math.max(8, Math.floor((sh - ch) / ch));
  const ox = Math.floor((sw - cols * cw) / 2);
  const oy = Math.floor((sh - rows * ch) / 2);
  return {
    s,
    dpr: ratio,
    screen: { x: sx, y: sy, w: sw, h: sh },
    fs,
    cw,
    ch,
    cols,
    rows,
    ox,
    oy,
    narrow: cols < NARROW_COLS || rows < NARROW_ROWS,
  };
}
