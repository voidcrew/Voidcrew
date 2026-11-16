/**
 * HULLS registry. Wide: the list, and the selected hull's record beside it. Narrow: the
 * list, or the record on its own screen ([ BACK ] returns to the list).
 */
import { type ReactNode, useMemo, useState } from 'react';

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
  const [page, setPage] = useState(1);
  const [enterLast, setEnterLast] = useState(false);

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
  // Rows below the header, less one for the pager when the list runs over.
  let maxRows = Math.max(1, TOP + h - 2 - hy);
  if (catalog.length > maxRows) {
    maxRows = Math.max(1, maxRows - 1);
  }
  const pages = Math.max(1, Math.ceil(catalog.length / maxRows));
  const pg = Math.min(pages, Math.max(1, page));
  const goPage = (to: number, last: boolean) => {
    setEnterLast(last);
    setPage(to);
  };
  const shown = catalog.slice((pg - 1) * maxRows, pg * maxRows);
  shown.forEach((hl, n) => {
    const i = (pg - 1) * maxRows + n;
    const y = hy + 1 + n;
    const firstRow = n === 0;
    const lastRow = n === shown.length - 1;
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
        {pad(priceText, lw - 3 - price)}
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
        key={`hit${pg}-${i}`}
        x={1}
        y={y}
        w={lw - 3}
        h={1}
        onClick={() => ctx.set({ hull: sel ? null : hl.id })}
        auto={(enterLast ? lastRow : firstRow) && !hull ? 1 : undefined}
        edge={{
          down:
            lastRow && pg < pages
              ? () => {
                  goPage(pg + 1, false);
                  return true;
                }
              : undefined,
          up:
            firstRow && pg > 1
              ? () => {
                  goPage(pg - 1, true);
                  return true;
                }
              : undefined,
        }}
      />,
    );
  });
  if (pages > 1) {
    const py = TOP + h - 1;
    const label = ` ${pg}/${pages} `;
    out.push(
      <Put
        key="prev"
        x={lw - 14}
        y={py}
        cls={pg > 1 ? 'inv' : 'faint'}
        bg={pg <= 1}
        onClick={pg > 1 ? () => goPage(pg - 1, false) : undefined}
      >
        {' < '}
      </Put>,
      <Put key="pg" x={lw - 11} y={py} bg>
        {label}
      </Put>,
      <Put
        key="next"
        x={lw - 11 + label.length}
        y={py}
        cls={pg < pages ? 'inv' : 'faint'}
        bg={pg >= pages}
        onClick={pg < pages ? () => goPage(pg + 1, false) : undefined}
      >
        {' > '}
      </Put>,
    );
  }

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
