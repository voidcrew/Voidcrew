/**
 * Pure helm chart geometry. Kept free of the backend import so it can be unit
 * tested without a BYOND window; hooks.ts re-exports it for consumer use.
 */

/** Flyable chart coordinates exclude the outer ring of looping barriers. */
export const isChartTile = (x: number, y: number, size: number) =>
  x >= 2 && x < size && y >= 2 && y < size;

/** Actual contact distance/bearing still uses the shorter path around the map. */
export const wrappedDelta = (delta: number, period: number) =>
  delta - Math.floor(delta / period + 0.5) * period;

export const clamp = (value: number, low: number, high: number) =>
  Math.max(low, Math.min(high, value));

/** Which concentric band a tile falls in, as calculate_zone_for_turf() decides it. */
export const bandOf = (
  tileX: number,
  tileY: number,
  centre: number,
  maxRadius: number,
  ringInner: number,
  ringMiddle: number,
) => {
  const normalized = Math.hypot(tileX - centre, tileY - centre) / maxRadius;
  if (normalized < ringInner) return 0;
  if (normalized < ringMiddle) return 1;
  return 2;
};

type ChartPoint = readonly [number, number];

export type CourseSegment = {
  from: ChartPoint;
  to: ChartPoint;
  step: number;
};

/**
 * Draw the server's course at its chart coordinates. A non-adjacent step is a
 * barrier crossing: leave a break there instead of drawing across the map or
 * inventing another copy. The remaining route resumes at the arrival side.
 */
export const visibleCourseSegments = (
  from: ChartPoint,
  course: readonly ChartPoint[],
  camera: ChartPoint,
  halfSpan: number,
) => {
  const segments: CourseSegment[] = [];
  let previous = from;
  course.forEach((node, step) => {
    const distance = Math.max(
      Math.abs(node[0] - previous[0]),
      Math.abs(node[1] - previous[1]),
    );
    if (
      distance > 0 &&
      distance <= 1 &&
      Math.max(previous[0], node[0]) >= camera[0] - halfSpan &&
      Math.min(previous[0], node[0]) <= camera[0] + halfSpan &&
      Math.max(previous[1], node[1]) >= camera[1] - halfSpan &&
      Math.min(previous[1], node[1]) <= camera[1] + halfSpan
    ) {
      segments.push({ from: previous, to: node, step });
    }
    previous = node;
  });
  return segments;
};
