/** Flyable chart coordinates are 2..size-1; the outer ring is a transport seam. */
export const wrapTile = (value: number, size: number) => {
  const period = size - 2;
  return ((((value - 2) % period) + period) % period) + 2;
};

/** Signed shortest displacement, also valid after panning through several copies. */
export const wrappedDelta = (delta: number, period: number) =>
  delta - Math.floor(delta / period + 0.5) * period;

/** Place a canonical coordinate in the copy nearest an unbounded camera/ship. */
export const nearestImage = (value: number, anchor: number, period: number) =>
  anchor + wrappedDelta(value - anchor, period);

/** Copies touching a viewport, with one tile of room for marks and interpolation. */
export const visibleCopies = (
  focus: number,
  halfSpan: number,
  period: number,
) => {
  const copies: number[] = [];
  const first = Math.floor((focus - halfSpan - 2) / period);
  const last = Math.floor((focus + halfSpan) / period);
  for (let copy = first; copy <= last; copy++) copies.push(copy);
  return copies;
};
