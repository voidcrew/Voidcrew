/**
 * A saved ship as a line drawing from its survey plan string: rows split by '/', each a
 * run-length list of cells (`12o` = twelve floor). '#' wall, 'g' window, 'o' floor,
 * 'e' engine, 'w' weapon, 's' sensor, 't' cargo, '.' nothing. Walls are joined centre to
 * centre. A tall hull lies on its side when the space is wide.
 */
import { useMemo } from 'react';

import { useGrid } from './term';

function parsePlan(plan: string): string[][] {
  return plan.split('/').map((row) => {
    const out: string[] = [];
    for (const m of row.matchAll(/(\d*)(\D)/g)) {
      const n = m[1] ? Number(m[1]) : 1;
      for (let i = 0; i < n; i++) {
        out.push(m[2]);
      }
    }
    return out;
  });
}

export function PlanPic(props: {
  x: number;
  y: number;
  w: number;
  h: number;
  plan: string;
  /** Drawn dark (the ship can't be loaded). */
  faded?: boolean;
}) {
  const { x, y, w, h, plan, faded } = props;
  const { cw, ch } = useGrid();
  const aw = w * cw;
  const ah = h * ch;

  const drawing = useMemo(() => {
    let rows = parsePlan(plan);
    let W = Math.max(0, ...rows.map((r) => r.length));
    let H = rows.length;
    if (!W || !H) {
      return null;
    }
    if (H > W * 1.15 && aw > ah) {
      const rot: string[][] = [];
      for (let cx = 0; cx < W; cx++) {
        rot.push([]);
        for (let cy = H - 1; cy >= 0; cy--) {
          rot[cx].push(rows[cy][cx] || '.');
        }
      }
      rows = rot;
      [W, H] = [H, W];
    }
    const k = Math.min(aw / W, ah / H);
    const at = (cx: number, cy: number) => rows[cy]?.[cx] || '.';
    const wall = (c: string) => c === '#' || c === 'g';
    let floor = '';
    let lines = '';
    let glass = '';
    let eng = '';
    const dots: [number, number, string][] = [];
    for (let cy = 0; cy < H; cy++) {
      for (let cx = 0; cx < W; cx++) {
        const c = at(cx, cy);
        if (c === '.') {
          continue;
        }
        const px = (cx + 0.5) * k;
        const py = (cy + 0.5) * k;
        floor += `M${cx * k} ${cy * k}h${k}v${k}h-${k}z`;
        if (wall(c)) {
          let lone = true;
          for (const [dx, dy] of [
            [1, 0],
            [0, 1],
          ]) {
            const n = at(cx + dx, cy + dy);
            if (wall(n)) {
              const seg = `M${px} ${py}L${px + dx * k} ${py + dy * k}`;
              if (c === 'g' || n === 'g') {
                glass += seg;
              } else {
                lines += seg;
              }
              lone = false;
            }
          }
          if (wall(at(cx - 1, cy)) || wall(at(cx, cy - 1))) {
            lone = false;
          }
          if (lone) {
            lines += `M${px - k * 0.3} ${py}h${k * 0.6}`;
          }
        } else if (c === 'e') {
          eng += `M${cx * k + k * 0.15} ${cy * k + k * 0.15}h${k * 0.7}v${k * 0.7}h-${k * 0.7}z`;
        } else if (c === 'w' || c === 's' || c === 't') {
          dots.push([px, py, c]);
        }
      }
    }
    return { W, H, k, floor, lines, glass, eng, dots };
  }, [plan, aw, ah]);

  if (!drawing) {
    return null;
  }
  const { W, H, k, floor, lines, glass, eng, dots } = drawing;
  const ph = faded ? '#2b6450' : '#7effbf';
  const dim = faded ? '#1d4636' : '#3f9a76';
  const amb = faded ? '#5a4a15' : '#ffc41f';
  const red = faded ? '#5a2a30' : '#ff5f6f';
  const sw = Math.max(1.2, k * 0.18);
  return (
    <div
      style={{
        position: 'absolute',
        left: Math.round(x * cw + (aw - W * k) / 2),
        top: Math.round(y * ch + (ah - H * k) / 2),
        filter: faded ? 'none' : 'drop-shadow(0 0 2px rgba(126,255,191,.6))',
      }}
    >
      <svg width={W * k} height={H * k} style={{ overflow: 'visible' }}>
        <path d={floor} fill={ph} fillOpacity={0.07} />
        <path
          d={glass}
          stroke={dim}
          strokeWidth={sw}
          strokeDasharray={`${k * 0.35} ${k * 0.25}`}
          fill="none"
        />
        <path
          d={lines}
          stroke={ph}
          strokeWidth={sw}
          strokeLinecap="square"
          fill="none"
        />
        <path d={eng} stroke={amb} strokeWidth={sw} fill="none" />
        {dots.map(([cx, cy, c], i) => (
          <circle
            key={i}
            cx={cx}
            cy={cy}
            r={k * 0.22}
            fill={c === 'w' ? red : c === 't' ? amb : ph}
          />
        ))}
      </svg>
    </div>
  );
}
