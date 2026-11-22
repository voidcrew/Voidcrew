/**
 * The Voidcrew symbol at rest: the finished mark with its orbit ring slowly turning.
 *
 *   <Emblem px={2} />                     64 art pixels square, drawn 128 CSS px square
 *   <Emblem size={64} px={s} still />     one frame, no animation
 *
 * Props:
 *   size   canvas side in art pixels (default 64; the design is scaled to fit it)
 *   px     CSS pixels per art pixel. Use a whole number of device pixels (the bezel scale
 *          `layout.s`, or a multiple of it) so the pixels stay square and sharp. Default 1.
 *   speed  how fast the ring's highlight travels, in radians per second (default 0.5)
 *   fps    redraws per second (default 12). It only redraws while the page is showing.
 *   still  draw once and stop
 *   style  merged onto the canvas; position it from the caller (it is a plain inline block)
 *
 * It takes no input and has no focus. The drawing itself is emblemDraw.ts.
 */
import { type CSSProperties, useEffect, useRef } from 'react';

import { renderEmblem } from './emblemDraw';

/** Redraws per second at rest. */
export const EMBLEM_FPS = 12;
/** Design scale that fits the whole symbol (ring, moon and glint) in a `size` px canvas. */
export const emblemScale = (size: number) => (size * 0.62) / 64;

export function Emblem(props: {
  size?: number;
  px?: number;
  speed?: number;
  fps?: number;
  still?: boolean;
  className?: string;
  style?: CSSProperties;
}) {
  const {
    size = 64,
    px = 1,
    speed = 0.5,
    fps = EMBLEM_FPS,
    still,
    className,
    style,
  } = props;
  const ref = useRef<HTMLCanvasElement | null>(null);

  useEffect(() => {
    const canvas = ref.current;
    if (!canvas) {
      return;
    }
    const k = emblemScale(size);
    const draw = (t: number) => {
      try {
        renderEmblem(canvas, {
          t,
          k,
          grow: 1,
          yaw: 0,
          v: true,
          ring: t * speed,
          hud: 0,
        });
      } catch {
        // A canvas the browser won't draw is left blank; the lobby works without the symbol.
      }
    };
    if (still) {
      draw(1);
      return;
    }
    let raf = 0;
    let last = -1;
    const frame = (now: number) => {
      const step = Math.floor((now / 1000) * fps);
      if (step !== last) {
        last = step;
        draw(step / fps);
      }
      raf = requestAnimationFrame(frame);
    };
    raf = requestAnimationFrame(frame);
    return () => cancelAnimationFrame(raf);
  }, [size, speed, fps, still]);

  return (
    <canvas
      ref={ref}
      className={className}
      width={size}
      height={size}
      style={{
        display: 'inline-block',
        width: size * px,
        height: size * px,
        imageRendering: 'pixelated',
        pointerEvents: 'none',
        ...style,
      }}
    />
  );
}
