/**
 * A saved ship as a line drawing from its survey plan string (spec 02, 5.2): rows split by '/',
 * each a run-length list of cells (`12o` = twelve floor). '#' wall, 'g' window, 'o' floor,
 * 'e' engine, 'w' weapon, 's' sensor, 't' cargo, '.' nothing. Walls are joined centre to
 * centre. The plan is drawn whichever way round gives the larger scale. Drawn in theme
 * colours; `faded` for a save that cannot load.
 */
import { type CSSProperties, useMemo } from 'react';

import { useGrid } from './term';

function parsePlan(plan: string): string[][] {
  return plan.split('/').map((row) => {
    const out: string[] = [];
    for (const m of row.matchAll(/(\d*)(\D)/g)) {
      const n = m[1] ? Math.min(512, Number(m[1])) : 1;
      for (let i = 0; i < n; i++) {
        out.push(m[2]);
      }
    }
    return out;
  });
}

/** Turned a quarter turn clockwise. */
function turn(rows: string[][], W: number, H: number): string[][] {
  const rot: string[][] = [];
  for (let cx = 0; cx < W; cx++) {
    rot.push([]);
    for (let cy = H - 1; cy >= 0; cy--) {
      rot[cx].push(rows[cy][cx] || '.');
    }
  }
  return rot;
}

export function PlanPic(props: {
  /** Cells, from the parent's top-left corner (the Well). */
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
  const aw = Math.max(1, w * cw);
  const ah = Math.max(1, h * ch);

  const drawing = useMemo(() => {
    let rows = parsePlan(plan);
    let W = Math.max(0, ...rows.map((r) => r.length));
    let H = rows.length;
    if (!W || !H) {
      return null;
    }
    // Whichever way round gives the larger scale.
    if (Math.min(aw / H, ah / W) > Math.min(aw / W, ah / H) * 1.001) {
      rows = turn(rows, W, H);
      [W, H] = [H, W];
    }
    const k = Math.min(aw / W, ah / H);
    const at = (cx: number, cy: number) => rows[cy]?.[cx] || '.';
    const wall = (c: string) => c === '#' || c === 'g';
    let floor = '';
    let lines = '';
    let glass = '';
    let eng = '';
    const dots: [number, number][] = [];
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
          dots.push([px, py]);
        }
      }
    }
    return { W, H, k, floor, lines, glass, eng, dots };
  }, [plan, aw, ah]);

  if (!drawing) {
    return null;
  }
  const { W, H, k, floor, lines, glass, eng, dots } = drawing;
  const small = k < 3;
  const wallC = faded ? 'var(--lt-faint)' : 'var(--lt-fg)';
  const markC = faded ? 'var(--lt-edge-dead)' : 'var(--lt-dim)';
  const dotC = faded ? 'var(--lt-edge-dead)' : 'var(--lt-acc)';
  const sw = small ? 1 : Math.max(1.2, k * 0.18);
  const stroke = (c: string, extra?: CSSProperties): CSSProperties => ({
    stroke: c,
    strokeWidth: sw,
    fill: 'none',
    ...extra,
  });
  return (
    <div
      style={{
        position: 'absolute',
        left: Math.round(x * cw + (aw - W * k) / 2),
        top: Math.round(y * ch + (ah - H * k) / 2),
        filter: faded ? 'none' : 'drop-shadow(0 0 2px rgba(190,140,255,.6))',
      }}
    >
      <svg width={W * k} height={H * k} style={{ overflow: 'visible' }}>
        <path
          d={floor}
          style={{ fill: wallC, fillOpacity: small ? 0.2 : 0.07 }}
        />
        <path
          d={glass}
          style={stroke(markC, {
            strokeDasharray: `${k * 0.35} ${k * 0.25}`,
          })}
        />
        <path d={lines} style={stroke(wallC, { strokeLinecap: 'square' })} />
        <path d={eng} style={stroke(markC)} />
        {dots.map(([cx, cy], i) => (
          <circle
            key={i}
            cx={cx}
            cy={cy}
            r={Math.max(0.8, k * 0.22)}
            style={{ fill: dotC }}
          />
        ))}
      </svg>
    </div>
  );
}
