/**
 * HULL RECORD (spec 02, 3.4). It replaces the list in the same box, captioned with the hull's
 * full name. Left: the hull in its stock fit over its description. Right, past a rule: the
 * berths as the big figure, the rooms and finishes (by name when the column has the rows, else
 * counts), the price by class, and the big FIT OUT key (BILL for a hull with nothing to fit).
 *
 * The tab row's right zone ([ BACK ] and the hull stepper) is drawn by YardTab. PageUp and
 * PageDown step through the catalog in list order here.
 *
 * FIT OUT keeps a fit that already belongs to this hull (YardTab's go.fitOut); only another
 * hull starts from stock.
 */
import type { ReactNode } from 'react';

import { usePager } from './nav';
import { ShipPic } from './ShipPic';
import {
  Big,
  bodyRows,
  BODY_Y,
  Box,
  BOX_Y,
  cut,
  Key,
  Put,
  RPut,
  safe,
  useGrid,
  VRule,
  wrap,
  wrapMax,
} from './term';
import type { Hull, PartClass } from './types';
import {
  crewCount,
  fittable,
  hullOwned,
  PART_ORDER,
  stockFit,
  usePreview,
  type YardCtx,
} from './YardTab';

/** Left column: columns 1 to 39. */
const LW = 39;
/** Right column: columns 43 to 61. */
const RX = 43;
const RW = 19;
/** Right-aligned figures end on column 61. */
const R_END = 62;

/** The figure a parts count draws as: 9999+ above 9999. */
const figure = (n: number) => (n > 9999 ? '9999+' : String(n));

/** PageUp / PageDown step through the catalog while the record is open. */
function useHullKeys(ctx: YardCtx, hull: Hull) {
  usePager((d) => {
    const { catalog } = ctx;
    const at = catalog.findIndex((h) => h.id === hull.id);
    const to = at + d;
    if (at >= 0 && to >= 0 && to < catalog.length && !ctx.view.leave) {
      ctx.go.record(catalog[to].id);
    }
  });
}

/** The record always takes the whole main box. */
export function HullRecord(props: { ctx: YardCtx; hull: Hull }) {
  const { ctx, hull } = props;
  const { rows } = useGrid();
  usePreview(hull.id);
  useHullKeys(ctx, hull);
  const M = rows;
  const B = bodyRows(M);
  const fit = stockFit(hull);
  const out: ReactNode[] = [];

  out.push(
    <Box
      key="box"
      x={0}
      y={BOX_Y}
      w={63}
      h={M - 3.5}
      caption={safe(hull.name).toUpperCase()}
    />,
    <VRule key="vr" x={41} y={BOX_Y} h={M - 3.5} />,
  );

  // Left: the picture takes every row the description leaves, never under 7.
  const desc = safe(hull.desc);
  const lines = desc ? wrap(desc, LW).length : 0;
  const L = Math.min(lines, Math.max(0, Math.floor(B - 0.5 - 7)));
  const P = L > 0 ? B - L - 0.5 : B;
  out.push(<ShipPic key="pic" x={1} y={BODY_Y} w={LW} h={P} fit={fit} />);
  if (L > 0) {
    wrapMax(desc, LW, L).forEach((line, i) => {
      out.push(
        <Put key={`d${i}`} x={1} y={BODY_Y + 0.5 + P + i}>
          {line}
        </Put>,
      );
    });
  }

  // Right: names when the column has the rows, else counts.
  const rooms = fit.slots.map((sl) => sl.label);
  const finishes = hull.finishes.map((f) => safe(f.name).toUpperCase());
  const owned = hullOwned(ctx.own, hull);
  const priced: PartClass[] = owned
    ? []
    : PART_ORDER.filter((k) => (hull.cost?.[k] || 0) > 0);
  const priceRows = Math.max(1, priced.length);
  const need =
    3.75 +
    (rooms.length ? rooms.length + 1.5 : 0) +
    (finishes.length ? finishes.length + 1.5 : 0) +
    1 +
    priceRows +
    2.5;
  const names = need <= B;
  // Spare rows spread the name and price rows apart (pitch up to 1.5), so a tall pane's
  // column does not end in a large empty block above the key.
  const listed = rooms.length + finishes.length + priceRows;
  const lp = names
    ? Math.min(1.5, 1 + Math.floor(((B - need) / Math.max(1, listed)) * 4) / 4)
    : 1;

  let y = BODY_Y;
  const berths = Math.min(999, crewCount(fit));
  out.push(
    <Big
      key="bn"
      x={RX}
      w={RW}
      y={y}
      scale={2.25}
      align="center"
      cls="acc"
    >
      {String(berths)}
    </Big>,
    <Put key="bw" x={RX + Math.floor((RW - 6) / 2)} y={y + 2.25}>
      BERTHS
    </Put>,
  );
  y += 3.25 + (names ? 0.5 : 0.25);

  if (names) {
    if (rooms.length) {
      out.push(
        <Put key="rh" x={RX} y={y} cls="dim">
          ROOMS
        </Put>,
      );
      y += 1;
      rooms.forEach((label, i) => {
        out.push(
          <Put key={`r${i}`} x={RX} y={y}>
            {cut(label, RW)}
          </Put>,
        );
        y += lp;
      });
      // A section ends half a row past its last line, so it reads apart from the next head
      // even when spare rows widen the line pitch.
      y += 0.5;
    }
    if (finishes.length) {
      out.push(
        <Put key="fh" x={RX} y={y} cls="dim">
          FINISHES
        </Put>,
      );
      y += 1;
      finishes.forEach((name, i) => {
        out.push(
          <Put key={`f${i}`} x={RX} y={y}>
            {cut(name, RW)}
          </Put>,
        );
        y += lp;
      });
      y += 0.5;
    }
  } else {
    const counts: [string, number][] = [];
    if (rooms.length) {
      counts.push(['ROOMS', rooms.length]);
    }
    if (finishes.length) {
      counts.push(['FINISHES', finishes.length]);
    }
    counts.forEach(([word, n], i) => {
      out.push(
        <Put key={`ch${i}`} x={RX} y={y} cls="dim">
          {word}
        </Put>,
        <RPut key={`cv${i}`} x={R_END} y={y}>
          {String(Math.min(99, n))}
        </RPut>,
      );
      y += 1;
    });
    if (counts.length) {
      y += 0.25;
    }
  }

  out.push(
    <Put key="ph" x={RX} y={y} cls="dim">
      PRICE
    </Put>,
  );
  y += 1;
  if (owned || !priced.length) {
    out.push(
      <Put key="pw" x={RX} y={y} cls="dim">
        {hullWord(ctx, hull)}
      </Put>,
    );
  } else {
    priced.forEach((k) => {
      out.push(
        <Put key={`pk-${k}`} x={RX} y={y} cls="dim">
          {k.toUpperCase()}
        </Put>,
        <RPut key={`pv-${k}`} x={R_END} y={y} cls="amb">
          {figure(hull.cost?.[k] || 0)}
        </RPut>,
      );
      y += lp;
    });
  }

  const canFit = fittable(hull);
  out.push(
    <Key
      key={`fit-${hull.id}`}
      kind="big"
      x={RX}
      y={M - 3.25}
      w={RW}
      h={2}
      label={canFit ? 'FIT OUT' : 'BILL'}
      auto={1}
      onClick={() => ctx.go.fitOut(hull)}
    />,
  );

  return <>{out}</>;
}

/** FREE for a hull that costs nothing (or under free ships), OWNED for one bought earlier. */
function hullWord(ctx: YardCtx, hull: Hull): 'FREE' | 'OWNED' {
  if (ctx.own.free || !!hull.free) {
    return 'FREE';
  }
  const anyCost = PART_ORDER.some((k) => (hull.cost?.[k] || 0) > 0);
  return anyCost ? 'OWNED' : 'FREE';
}
