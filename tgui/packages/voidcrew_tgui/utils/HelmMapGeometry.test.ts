import { describe, expect, test } from 'bun:test';
import { nearestImage, visibleCopies, wrappedDelta, wrapTile } from './HelmMapGeometry';

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
        for (let tile = Math.floor(focus - span / 2); tile <= Math.ceil(focus + span / 2); tile++) {
          expect(copies.some((copy) => tile >= 2 + copy * 49 && tile <= 50 + copy * 49)).toBe(true);
        }
        expect(copies.length).toBeLessThanOrEqual(3);
      }
    }
  });
});
