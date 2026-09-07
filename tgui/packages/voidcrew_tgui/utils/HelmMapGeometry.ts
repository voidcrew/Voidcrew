/** Flyable chart coordinates exclude the outer ring of looping barriers. */
export const isChartTile = (x: number, y: number, size: number) =>
  x >= 2 && x < size && y >= 2 && y < size;

/** Actual contact distance/bearing still uses the shorter path around the map. */
export const wrappedDelta = (delta: number, period: number) =>
  delta - Math.floor(delta / period + 0.5) * period;

/** Keep the visible interval inside the single chart, including at full zoom out. */
export const clampCameraAxis = (
  focus: number,
  visibleSpan: number,
  extent: number,
) => {
  const halfSpan = Math.min(visibleSpan, extent) / 2;
  return Math.max(halfSpan, Math.min(extent - halfSpan, focus));
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
