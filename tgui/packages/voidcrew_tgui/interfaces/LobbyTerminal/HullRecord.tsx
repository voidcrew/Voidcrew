/**
 * One hull's record: the stock fit on the viewscreen, model name, description, crew,
 * rooms, finishes, price and [ FIT OUT ].
 */
import type { ReactNode } from 'react';

import { ShipPic } from './ShipPic';
import { Frame, Put, TOP, useGrid, wrap } from './term';
import type { Hull } from './types';
import {
  costOf,
  crewCount,
  hullOwned,
  Key,
  stockFit,
  usePreview,
  type YardCtx,
} from './YardTab';

export function HullRecord(props: {
  ctx: YardCtx;
  hull: Hull;
  x: number;
  w: number;
}) {
  const { ctx, hull, x, w } = props;
  const { rows, narrow } = useGrid();
  usePreview(hull.id);
  const h = rows - 1 - TOP;
  const fit = stockFit(hull);
  const picH = Math.max(6, Math.floor(h * 0.42));
  const out: ReactNode[] = [];

  out.push(
    <ShipPic key="pic" x={x + 2} y={TOP + 1.5} w={w - 4} h={picH} fit={fit} />,
  );
  let y = TOP + 2 + picH;
  out.push(
    <Put key="name" x={x + 3} y={y++}>
      {hull.name.toUpperCase().slice(0, w - 6)}
    </Put>,
  );
  y++;
  const by = TOP + h - 3;
  const owned = hullOwned(ctx.own, hull);
  // Leave room for the stats line and the price above the key.
  const descRows = Math.max(1, by - (owned ? 1 : 3) - 2 - y);
  wrap(hull.desc, w - 6)
    .slice(0, descRows)
    .forEach((l, i) => {
      out.push(
        <Put key={`d${i}`} x={x + 3} y={y++} cls="dim">
          {l}
        </Put>,
      );
    });
  y++;
  if (y < by - (owned ? 0 : 2)) {
    out.push(
      <Put key="cl" x={x + 3} y={y} cls="dim">
        CREW
      </Put>,
      <Put key="cv" x={x + 9} y={y}>
        {String(crewCount(fit))}
      </Put>,
      <Put key="rl" x={x + 14} y={y} cls="dim">
        ROOMS
      </Put>,
      <Put key="rv" x={x + 21} y={y}>
        {String(hull.slots.length)}
      </Put>,
    );
    if (hull.finishes.length && w >= 44) {
      out.push(
        <Put key="fl" x={x + 26} y={y} cls="dim">
          FINISHES
        </Put>,
        <Put key="fv" x={x + 36} y={y}>
          {String(hull.finishes.length)}
        </Put>,
      );
    }
  }
  if (!owned) {
    out.push(
      <Put key="pl" x={x + 3} y={by - 2} cls="dim">
        PRICE
      </Put>,
      <Put key="pv" x={x + 10} y={by - 2} cls="amb">
        {costOf(hull.cost)}
      </Put>,
    );
  }
  out.push(
    <Key
      key="fit"
      x={x + 3}
      y={by}
      label="FIT OUT"
      cls="inv"
      onClick={() =>
        ctx.set({
          // A hull with no finishes and no rooms has nothing to fit: straight to the bill.
          screen:
            hull.finishes.length || hull.slots.length ? 'fit' : 'bill',
          finish: null,
          picks: {},
          step: 0,
        })
      }
    />,
  );
  if (!narrow) {
    out.push(
      <Put
        key="x"
        x={x + w - 6}
        y={TOP}
        cls="dim"
        hoverCls="inv"
        bg
        onClick={() => ctx.set({ hull: null })}
      >
        {' X '}
      </Put>,
    );
  }

  return (
    <Frame x={x} y={TOP} w={w} h={h} title={hull.short.toUpperCase()}>
      {out}
    </Frame>
  );
}
