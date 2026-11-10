/**
 * HULLS registry. Wide: the list, and the selected hull's record beside it. Narrow: the
 * list, or the record on its own screen ([ BACK ] returns to the list).
 */
import { type ReactNode, useMemo } from 'react';

import { HullRecord } from './HullRecord';
import { Frame, Hit, lpad, Put, pad, TOP, useGrid } from './term';
import {
  crewCount,
  hullOwned,
  partsOf,
  stockFit,
  type YardCtx,
} from './YardTab';

export function Hulls(props: { ctx: YardCtx }) {
  const { ctx } = props;
  const { catalog, hull, own } = ctx;
  const { cols, rows, narrow } = useGrid();
  const h = rows - 1 - TOP;
  const crews = useMemo(
    () => catalog.map((hl) => crewCount(stockFit(hl))),
    [catalog],
  );

  if (narrow && hull) {
    return <HullRecord ctx={ctx} hull={hull} x={0} w={cols} />;
  }

  const split = !!hull && !narrow;
  const lw = split ? Math.max(40, Math.floor(cols * 0.41)) : cols;
  // Columns, right to left from the price.
  const price = lw - 14;
  const rooms = price - 8;
  const crew = rooms - 6;
  const fin = split ? 0 : price - 9;
  const showModel = !split && crew - 28 >= 20;
  const showFin = !split && !narrow;
  const roomsAt = showFin ? fin - 8 : rooms;
  const crewAt = showFin ? roomsAt - 7 : crew;
  const nameEnd = showModel ? 27 : crewAt - 1;

  const out: ReactNode[] = [];
  const hy = TOP + 1;
  out.push(
    <Put key="hh" x={3} y={hy} cls="dim">
      HULL
    </Put>,
    <Put key="hc" x={crewAt} y={hy} cls="dim">
      CREW
    </Put>,
    <Put key="hr" x={roomsAt} y={hy} cls="dim">
      ROOMS
    </Put>,
    <Put key="hp" x={price} y={hy} cls="dim">
      PRICE
    </Put>,
  );
  if (showModel) {
    out.push(
      <Put key="hm" x={28} y={hy} cls="dim">
        MODEL
      </Put>,
    );
  }
  if (showFin) {
    out.push(
      <Put key="hf" x={fin} y={hy} cls="dim">
        FINISH
      </Put>,
    );
  }
  const maxRows = Math.max(0, TOP + h - 2 - hy);
  catalog.slice(0, maxRows).forEach((hl, i) => {
    const y = hy + 1 + i;
    const sel = hull?.id === hl.id;
    const k = sel ? 'inv' : '';
    const owned = hullOwned(own, hl);
    const cost = partsOf(hl.cost);
    const priceText = owned
      ? cost && !hl.free && !own.free
        ? 'OWNED'
        : 'FREE'
      : `${cost} PARTS`;
    if (sel) {
      out.push(
        <Put key={`bar${i}`} x={1} y={y} cls="inv">
          {' '.repeat(lw - 3)}
        </Put>,
      );
    }
    out.push(
      <Put key={`m${i}`} x={1} y={y} cls={k}>
        {sel ? '>' : ' '}
      </Put>,
      <Put key={`n${i}`} x={3} y={y} cls={k}>
        {pad(hl.short.toUpperCase(), nameEnd - 3)}
      </Put>,
      <Put key={`c${i}`} x={crewAt} y={y} cls={k}>
        {lpad(crews[i], 3)}
      </Put>,
      <Put key={`r${i}`} x={roomsAt} y={y} cls={k}>
        {lpad(hl.slots.length, 3)}
      </Put>,
      <Put
        key={`p${i}`}
        x={price}
        y={y}
        cls={sel ? 'inv' : owned ? 'dim' : 'amb'}
      >
        {priceText}
      </Put>,
    );
    if (showModel) {
      out.push(
        <Put key={`md${i}`} x={28} y={y} cls={sel ? 'inv' : 'dim'}>
          {pad(hl.name, crewAt - 29)}
        </Put>,
      );
    }
    if (showFin) {
      out.push(
        <Put key={`f${i}`} x={fin} y={y} cls={k}>
          {lpad(hl.finishes.length || '-', 3)}
        </Put>,
      );
    }
    out.push(
      <Hit
        key={`hit${i}`}
        x={1}
        y={y}
        w={lw - 3}
        h={1}
        onClick={() => ctx.set({ hull: sel ? null : hl.id })}
      />,
    );
  });

  return (
    <>
      <Frame x={0} y={TOP} w={lw} h={h} title={`HULLS  ${catalog.length}`} />
      {out}
      {split && !!hull && (
        <HullRecord ctx={ctx} hull={hull} x={lw + 1} w={cols - lw - 1} />
      )}
    </>
  );
}
