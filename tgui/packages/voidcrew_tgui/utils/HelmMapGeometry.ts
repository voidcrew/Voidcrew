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

type ChartPoint = readonly [number, number];

export type CourseSegment = {
  from: ChartPoint;
  to: ChartPoint;
  step: number;
};

/**
 * Draw the server's course one adjacent step at a time. Unwrap each edge around
 * its own start: placing every node nearest the ship would cut long detours in
 * half. Only emit copies of edges touching the viewport, including either seam.
 */
export const visibleCourseSegments = (
  from: ChartPoint,
  course: readonly ChartPoint[],
  camera: ChartPoint,
  halfSpan: number,
  period: number,
) => {
  const segments: CourseSegment[] = [];
  let previous = from;
  course.forEach((node, step) => {
    const next: ChartPoint = [
      nearestImage(node[0], previous[0], period),
      nearestImage(node[1], previous[1], period),
    ];
    if (next[0] !== previous[0] || next[1] !== previous[1]) {
      const firstX = Math.ceil(
        (camera[0] - halfSpan - Math.max(previous[0], next[0])) / period,
      );
      const lastX = Math.floor(
        (camera[0] + halfSpan - Math.min(previous[0], next[0])) / period,
      );
      const firstY = Math.ceil(
        (camera[1] - halfSpan - Math.max(previous[1], next[1])) / period,
      );
      const lastY = Math.floor(
        (camera[1] + halfSpan - Math.min(previous[1], next[1])) / period,
      );
      for (let copyX = firstX; copyX <= lastX; copyX++) {
        for (let copyY = firstY; copyY <= lastY; copyY++) {
          segments.push({
            from: [previous[0] + copyX * period, previous[1] + copyY * period],
            to: [next[0] + copyX * period, next[1] + copyY * period],
            step,
          });
        }
      }
    }
    previous = node;
  });
  return segments;
};
