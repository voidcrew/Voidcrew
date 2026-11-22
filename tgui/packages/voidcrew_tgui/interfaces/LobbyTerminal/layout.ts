/**
 * Terminal geometry: bezel scale, the glass rect and the text grid, from the pane size.
 *
 * Bezel: integer pixel-art scale s = clamp(min(floor(H / 360), floor(W / 472)), 1, 4),
 * snapped to whole device pixels so Windows display scaling doesn't blur the art.
 *
 * Grid: a fixed column count. Side mode is exactly 84 columns (a 19-column menu, a 2-column
 * gap and the 63-column main area); bar mode is exactly 63. The text size is the largest that
 * fits those columns plus one margin cell each side, so only the row count changes with the
 * pane. Text sizes are fractional; the cell height is whole pixels.
 */

/** 1x pixel numbers of the bezel (bezel.json). The frame covers the whole pane. */
export const BEZEL = {
  baseHeight: 360,
  minWidth: 472,
  screenTop: 15,
  screenSide: 13,
  screenBottom: 3,
} as const;

/** Canvas columns in side-menu mode. */
export const SIDE_COLS = 84;
/** The main area in both modes; the whole canvas in bar mode. */
export const MAIN_COLS = 63;
/** The side menu; then a 2-column gap; then the main area at column 21. */
export const MENU_COLS = 19;
export const MAIN_X = MENU_COLS + 2;
export const SIDE_MIN_ROWS = 28;
export const BAR_MIN_ROWS = 22;
export const MAX_ROWS = 48;
export const SIDE_MIN_FS = 14;
export const BAR_MIN_FS = 9;
export const MAX_FS = 40;

export type Mode = 'side' | 'bar';

export type Layout = {
  /** CSS pixels per art pixel (a whole number of device pixels). */
  s: number;
  dpr: number;
  /** Glass rect in CSS px, relative to the pane. */
  screen: { x: number; y: number; w: number; h: number };
  /** Font size in CSS px (fractional). */
  fs: number;
  /** Cell size in CSS px: cw fractional, ch whole. */
  cw: number;
  ch: number;
  cols: number;
  rows: number;
  /** Canvas origin inside the glass. */
  ox: number;
  oy: number;
  mode: Mode;
  /** Line weight in px: every border and rule. */
  lw: number;
};

/** A rect in canvas cells. */
export type CellRect = { x: number; y: number; w: number; h: number };

const clamp = (v: number, lo: number, hi: number) =>
  Math.max(lo, Math.min(hi, v));

function fitGrid(
  sw: number,
  sh: number,
  advance: number,
  cols: number,
  minRows: number,
) {
  const chMax = Math.max(1, Math.floor(sh / (minRows + 1)));
  const fs =
    Math.floor(
      Math.min(sw / ((cols + 2) * advance), chMax / 1.2, MAX_FS) * 100,
    ) / 100;
  return { fs, chMax };
}

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

  let mode: Mode = 'side';
  let cols = SIDE_COLS;
  let { fs, chMax } = fitGrid(sw, sh, advance, SIDE_COLS, SIDE_MIN_ROWS);
  if (fs < SIDE_MIN_FS) {
    mode = 'bar';
    cols = MAIN_COLS;
    ({ fs, chMax } = fitGrid(sw, sh, advance, MAIN_COLS, BAR_MIN_ROWS));
    fs = Math.max(BAR_MIN_FS, fs);
  }
  const ch = Math.max(1, Math.min(chMax, Math.round(fs * 1.2)));
  const cw = fs * advance;
  const minRows = mode === 'side' ? SIDE_MIN_ROWS : BAR_MIN_ROWS;
  // Below the supported minimum the canvas keeps its minimum rows and clips.
  const rows = clamp(Math.floor(sh / ch) - 1, minRows, MAX_ROWS);
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
    mode,
    lw: Math.round(s) + 1,
  };
}

/** Canvas regions (cells) for a layout: header band, side menu, main area, key bar. */
export function regions(mode: Mode, rows: number) {
  if (mode === 'side') {
    return {
      header: { x: 0, y: 0, w: SIDE_COLS, h: 1.5 } as CellRect,
      menu: { x: 0, y: 2, w: MENU_COLS, h: rows - 2 } as CellRect | null,
      main: { x: MAIN_X, y: 2, w: MAIN_COLS, h: rows - 2 } as CellRect,
      bar: null as CellRect | null,
    };
  }
  return {
    header: { x: 0, y: 0, w: MAIN_COLS, h: 1.5 } as CellRect,
    menu: null as CellRect | null,
    main: { x: 0, y: 2, w: MAIN_COLS, h: rows - 4 } as CellRect,
    bar: { x: 0, y: rows - 1.5, w: MAIN_COLS, h: 1.5 } as CellRect | null,
  };
}
