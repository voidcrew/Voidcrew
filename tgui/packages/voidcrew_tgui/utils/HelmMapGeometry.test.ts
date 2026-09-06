import { describe, expect, test } from 'bun:test';
import {
  nearestImage,
  visibleCopies,
  visibleCourseSegments,
  wrappedDelta,
  wrapTile,
} from './HelmMapGeometry';

describe('seamless helm coordinates', () => {
  test('canonical clicks cross either seam, even after repeated panning', () => {
    expect(wrapTile(1, 51)).toBe(50);
    expect(wrapTile(51, 51)).toBe(2);
    expect(wrapTile(-48, 51)).toBe(50);
    expect(wrapTile(149, 51)).toBe(2);
    for (let tile = 2; tile <= 50; tile++) {
      for (let lap = -5; lap <= 5; lap++) {
        expect(wrapTile(tile + lap * 49, 51)).toBe(tile);
      }
    }
  });
  test('camera, contacts and drift travel one tile through the seam', () => {
    expect(nearestImage(2, 50, 49)).toBe(51);
    expect(nearestImage(50, 2, 49)).toBe(1);
    expect(nearestImage(3, 51, 49)).toBe(52);
    expect(wrappedDelta(50 - 2, 49)).toBe(-1);
    expect(wrappedDelta(2 - 50, 49)).toBe(1);
    let position = 50;
    for (let step = 1; step <= 150; step++) {
      position = nearestImage(wrapTile(50 + step, 51), position, 49);
      expect(position).toBe(50 + step);
    }
  });
  test('visible copies cover the viewport continuously at all zoom levels', () => {
    for (const focus of [-150, 1, 2, 25, 50, 51, 200]) {
      for (const span of [5, 13, 49]) {
        const copies = visibleCopies(focus, span / 2 + 1, 49);
        for (
          let tile = Math.floor(focus - span / 2);
          tile <= Math.ceil(focus + span / 2);
          tile++
        ) {
          expect(
            copies.some(
              (copy) => tile >= 2 + copy * 49 && tile <= 50 + copy * 49,
            ),
          ).toBe(true);
        }
        expect(copies.length).toBeLessThanOrEqual(3);
      }
    }
  });
});

describe('autopilot route overlay', () => {
  test('shows the planned detour instead of a straight line to the destination', () => {
    const course: [number, number][] = [
      [11, 26],
      [12, 26],
      [13, 25],
    ];
    expect(visibleCourseSegments([10, 25], course, [12, 25], 5, 49)).toEqual([
      { from: [10, 25], to: [11, 26], step: 0 },
      { from: [11, 26], to: [12, 26], step: 1 },
      { from: [12, 26], to: [13, 25], step: 2 },
    ]);
    expect(course).toEqual([
      [11, 26],
      [12, 26],
      [13, 25],
    ]);
  });

  test('joins the route through either seam and through corners in both directions', () => {
    for (const [from, to] of [
      [
        [50, 25],
        [2, 25],
      ],
      [
        [25, 50],
        [25, 2],
      ],
      [
        [50, 50],
        [2, 2],
      ],
      [
        [2, 25],
        [50, 25],
      ],
      [
        [25, 2],
        [25, 50],
      ],
      [
        [2, 2],
        [50, 50],
      ],
    ] as [number, number][][]) {
      for (const lap of [-3, 0, 4]) {
        const camera: [number, number] = [
          from[0] + lap * 49,
          from[1] - lap * 49,
        ];
        const segments = visibleCourseSegments(from, [to], camera, 3, 49);
        expect(segments).toHaveLength(1);
        expect(segments[0].from).toEqual(camera);
        expect(segments[0].to).toEqual([
          camera[0] + wrappedDelta(to[0] - from[0], 49),
          camera[1] + wrappedDelta(to[1] - from[1], 49),
        ]);
      }
    }
  });

  test('keeps a detour longer than half the map continuous without shortcutting it', () => {
    const course: [number, number][] = Array.from({ length: 35 }, (_, i) => [
      i + 3,
      25,
    ]);
    const segments = visibleCourseSegments([2, 25], course, [26, 26], 24, 49);
    expect(segments).toHaveLength(35);
    segments.forEach(({ from, to }, step) => {
      expect(from).toEqual([step + 2, 25]);
      expect(to).toEqual([step + 3, 25]);
    });
  });

  test('shows both visible images of a seam crossing at full zoom out', () => {
    expect(
      visibleCourseSegments([50, 25], [[2, 25]], [26, 26], 24.5, 49),
    ).toEqual([
      { from: [1, 25], to: [2, 25], step: 0 },
      { from: [50, 25], to: [51, 25], step: 0 },
    ]);
  });

  test('drops distant edges, reached nodes and cleared courses', () => {
    expect(
      visibleCourseSegments([10, 10], [[11, 10]], [30, 30], 3, 49),
    ).toEqual([]);
    expect(
      visibleCourseSegments(
        [10, 10],
        [
          [10, 10],
          [11, 10],
        ],
        [10, 10],
        3,
        49,
      ),
    ).toEqual([{ from: [10, 10], to: [11, 10], step: 1 }]);
    expect(visibleCourseSegments([10, 10], [], [10, 10], 3, 49)).toEqual([]);
  });
});
