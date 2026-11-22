/**
 * The Voidcrew symbol, drawn pixel by pixel into a canvas: a two-tone V through a black disc
 * with a dithered glow, an orbit ring that passes behind the disc at the top and in front at
 * the bottom, a moon on the ring and a glint.
 *
 * Every pixel is set whole (no antialiasing). Show the canvas scaled by a whole number of
 * device pixels with `image-rendering: pixelated`; never scale it by a fraction.
 *
 * Coordinates: the design is about 90 units wide (the ring), centred on the canvas and scaled
 * by `k`. The start-up rings (`hud`) are fixed at radius 76 to 90 canvas pixels, so they need a
 * canvas of at least 190 px and are not scaled by `k`.
 */

export type EmblemOpts = {
  /** Seconds. Steps the glint and the start-up rings; quantise it to the frame rate you draw at. */
  t: number;
  /** Design scale inside the canvas. 1.45 fills a 190 px canvas (start-up), 0.62 fits 64 px. */
  k?: number;
  /** 0 to 1: the disc, glow and ring growing in. 1 for the finished symbol. */
  grow: number;
  /** The V's turn about its vertical axis, in radians. 0 faces the viewer. */
  yaw: number;
  /** Draw the V. */
  v: boolean;
  /** Where the highlight sits on the orbit ring, in radians. Advance it to make the ring turn. */
  ring: number;
  /** Start-up rings: 0 off, 0 to 1 the three arcs sweeping in, 1 or more fully drawn. */
  hud: number;
  /** Kept so old call sites read the same. Only the eclipse (1) exists. */
  variant?: 1;
};

type Rgb = readonly [number, number, number];

const hex = (h: string): Rgb => [
  parseInt(h.slice(1, 3), 16),
  parseInt(h.slice(3, 5), 16),
  parseInt(h.slice(5, 7), 16),
];

const C = {
  void: hex('#05010b'),
  ink: hex('#12071f'),
  p0: hex('#2a0f5c'),
  p1: hex('#5b2bc0'),
  p2: hex('#8e5cf0'),
  p3: hex('#b48aff'),
  p4: hex('#dfc4ff'),
  w: hex('#ffffff'),
  m0: hex('#7a2a8c'),
  m1: hex('#c044b0'),
  m2: hex('#ff66d6'),
  m3: hex('#ffb0ee'),
} as const;

const BAYER = [
  [0, 8, 2, 10],
  [12, 4, 14, 6],
  [3, 11, 1, 9],
  [15, 7, 13, 5],
];
const TAU = Math.PI * 2;
/** Light direction for the disc rim and the glow (from the upper left). */
const LX = -0.6;
const LY = -0.8;
const RING_TILT = -0.32;
const RING_STEPS = 1440;

/** Which facet of the V a design point is in: 0 outside, 1 left, 2 right. */
function inV(x: number, y: number): 0 | 1 | 2 {
  if (y < -30 || y > 32) {
    return 0;
  }
  const ax = Math.abs(x);
  const outer = (22 * (32 - y)) / 62;
  const inner = (10 * (4 - y)) / 34;
  if (ax > outer) {
    return 0;
  }
  if (y < 4 && ax < inner) {
    return 0;
  }
  return x <= 0 ? 1 : 2;
}

const tone = (b: number): Rgb =>
  b > 0.8 ? C.w : b > 0.55 ? C.p4 : b > 0.3 ? C.p3 : C.p2;

/** One pixel buffer per canvas, reused every frame. */
const frames = new WeakMap<HTMLCanvasElement, ImageData>();

/** Draws one frame of the symbol, replacing whatever the canvas held. Pixels it does not set are clear. */
export function renderEmblem(canvas: HTMLCanvasElement, o: EmblemOpts): void {
  const W = canvas.width;
  const H = canvas.height;
  const ctx = canvas.getContext('2d');
  if (!ctx || W <= 0 || H <= 0) {
    return;
  }
  let img = frames.get(canvas);
  if (!img || img.width !== W || img.height !== H) {
    img = ctx.createImageData(W, H);
    frames.set(canvas, img);
  } else {
    img.data.fill(0);
  }
  const d = img.data;
  const K = o.k || 1;
  const cx = W / 2;
  const cy = H / 2 + 2 * K;
  const { t, grow } = o;

  const put = (fx: number, fy: number, c: Rgb) => {
    const x = Math.floor(fx);
    const y = Math.floor(fy);
    if (x < 0 || y < 0 || x >= W || y >= H) {
      return;
    }
    const i = (y * W + x) * 4;
    d[i] = c[0];
    d[i + 1] = c[1];
    d[i + 2] = c[2];
    d[i + 3] = 255;
  };
  const blob = (x: number, y: number, c: Rgb, n: number) => {
    for (let a = 0; a < n; a++) {
      for (let b = 0; b < n; b++) {
        put(x + a - n / 2 + 0.5, y + b - n / 2 + 0.5, c);
      }
    }
  };

  const R = 26 * grow;

  // Glow around the disc, dithered.
  if (grow > 0.05) {
    for (let py = 0; py < H; py++) {
      for (let px = 0; px < W; px++) {
        const x = (px + 0.5 - cx) / K;
        const y = (py + 0.5 - cy) / K;
        const r = Math.hypot(x, y);
        const dd = r - R;
        if (dd <= 0 || dd > 11) {
          continue;
        }
        const light = Math.max(0, (x * LX + y * LY) / r);
        const v = (1 - dd / 11) ** 1.6 * (0.45 + 0.75 * light);
        const th = (BAYER[py & 3][px & 3] + 0.5) / 16;
        if (v > th) {
          put(px, py, v > th + 0.45 ? C.p3 : v > th + 0.2 ? C.p2 : C.p1);
        }
      }
    }
  }

  // Orbit ring: the far half first, the near half after the disc and the V.
  const a = 43 * grow;
  const b = a * 0.27;
  const ct = Math.cos(RING_TILT);
  const st = Math.sin(RING_TILT);
  const ring = (front: boolean) => {
    if (grow < 0.3) {
      return;
    }
    for (let k = 0; k < RING_STEPS; k++) {
      const th = (k / RING_STEPS) * TAU;
      if (Math.sin(th) > 0 !== front) {
        continue;
      }
      const hl = Math.cos(th - o.ring);
      let col: Rgb;
      if (front) {
        col = hl > 0.92 ? C.w : hl > 0.6 ? C.m3 : hl > -0.2 ? C.m2 : C.m1;
      } else {
        col = hl > 0.8 ? C.m2 : hl > 0 ? C.m1 : C.m0;
      }
      for (const rr of [a, a - 0.7, a - 1.4]) {
        const ex = rr * Math.cos(th);
        const ey = rr * 0.27 * Math.sin(th);
        put(cx + K * (ex * ct - ey * st), cy + K * (ex * st + ey * ct), col);
      }
    }
  };
  ring(false);

  // Disc, then the V over it with a dark outline.
  const sx = Math.cos(o.yaw);
  const sa = Math.max(Math.abs(sx), 0.07);
  const e = 1.2 / K;
  const vAt = (x: number, y: number) => inV(x / sa, y);
  for (let py = 0; py < H; py++) {
    for (let px = 0; px < W; px++) {
      const x = (px + 0.5 - cx) / K;
      const y = (py + 0.5 - cy) / K;
      const r = Math.hypot(x, y);
      if (r < R) {
        const l = (x * LX + y * LY) / (r || 1);
        if (r > R - 2) {
          put(
            px,
            py,
            l > 0.55 ? C.w : l > 0.1 ? C.p4 : l > -0.45 ? C.p2 : C.p1,
          );
        } else if (r > R - 3 && l > 0.3) {
          put(px, py, C.p0);
        } else {
          put(px, py, C.void);
        }
      }
      if (!o.v) {
        continue;
      }
      const f = vAt(x, y);
      if (f) {
        // The left facet catches the light head on; the right one never goes fully white.
        const lit = f === 1 ? 0.5 + 0.5 * sx : 0.5 - 0.5 * sx;
        put(
          px,
          py,
          tone(lit) === C.w && f === 2
            ? C.p4
            : tone(f === 1 ? lit : 0.32 - 0.32 * sx + 0.1),
        );
      } else if (
        vAt(x - e, y) ||
        vAt(x + e, y) ||
        vAt(x, y - e) ||
        vAt(x, y + e)
      ) {
        put(px, py, C.ink);
      }
    }
  }
  ring(true);

  // Moon on the ring, hidden while it is behind the disc.
  if (grow > 0.6) {
    const th = o.ring * 0.5 + 1;
    const ex = a * Math.cos(th);
    const ey = b * Math.sin(th);
    const rx = ex * ct - ey * st;
    const ry = ex * st + ey * ct;
    if (Math.sin(th) > 0 || Math.hypot(rx, ry) > R + 2) {
      const mx = cx + K * rx;
      const my = cy + K * ry;
      blob(mx, my, C.m3, 3);
      put(mx, my, C.w);
    }
  }

  // Glint, upper right.
  if (o.v && grow > 0.9) {
    const gx = cx + 31 * K;
    const gy = cy - 31 * K;
    const n = 2 + (Math.floor(t * 3) % 3);
    for (let k = 1; k <= n; k++) {
      const c = k < n ? C.p4 : C.p2;
      put(gx + k, gy, c);
      put(gx - k, gy, c);
      put(gx, gy + k, c);
      put(gx, gy - k, c);
    }
    put(gx, gy, C.w);
  }

  // Start-up rings: a stepping tick ring with four markers, and three arcs turning the other way.
  if (o.hud > 0) {
    const rot = Math.floor(t * 8) * (TAU / 96);
    for (let i = 0; i < 60; i++) {
      if (i % 15 === 0) {
        continue;
      }
      const an = (i / 60) * TAU + rot;
      const big = i % 5 === 0;
      for (let rr = big ? 84 : 87; rr <= 90; rr += 0.5) {
        blob(
          cx + rr * Math.cos(an),
          cy + rr * Math.sin(an),
          big ? C.p4 : C.p2,
          big ? 2 : 1,
        );
      }
    }
    for (let i = 0; i < 4; i++) {
      const an = (i / 4) * TAU;
      blob(cx + 88 * Math.cos(an + rot), cy + 88 * Math.sin(an + rot), C.w, 5);
    }
    const rot2 = -Math.floor(t * 12) * (TAU / 120);
    const len = Math.min(1, o.hud) * 1.25;
    for (let j = 0; j < 3; j++) {
      for (let k = 0; k < 400; k++) {
        const an = rot2 + (j * TAU) / 3 + (k / 400) * len;
        for (const rr of [76, 76.7, 77.4]) {
          put(cx + rr * Math.cos(an), cy + rr * Math.sin(an), C.m2);
        }
      }
    }
  }

  ctx.putImageData(img, 0, 0);
}
