/**
 * FIT: the finish, then each module slot. Wide: the step list with the running total and
 * crew on the left, the viewscreen and this step's options on the right. Narrow: the
 * viewscreen above the options, PREV/NEXT between steps.
 */
import { type ReactNode, useEffect } from 'react';

import { ShipPic } from './ShipPic';
import {
  Frame,
  Hit,
  lpad,
  Put,
  pad,
  RPut,
  Rule,
  TOP,
  useGrid,
  wrap,
} from './term';
import type { CrewLine, Finish, Hull, Module } from './types';
import {
  billOf,
  costOf,
  crewOf,
  finishOwned,
  fitOf,
  Key,
  moduleOwned,
  partsOf,
  type ShipFit,
  usePreview,
  type YardCtx,
} from './YardTab';

type Step = {
  label: string;
  /** Finish step, or the slot key. */
  slot: string | null;
  opts: (Finish | Module)[];
  pick: number;
};

function jobsText(jobs: CrewLine[]): string {
  return jobs.map(([t, n]) => (n > 1 ? `${t} x${n}` : t)).join(', ');
}

function stepsOf(fit: ShipFit): Step[] {
  const steps: Step[] = [];
  const { hull, finish } = fit;
  if (hull.finishes.length) {
    steps.push({
      label: 'FINISH',
      slot: null,
      opts: hull.finishes,
      pick: Math.max(
        0,
        hull.finishes.findIndex((f) => f.id === finish?.id),
      ),
    });
  }
  for (const s of fit.slots) {
    steps.push({
      label: s.label,
      slot: s.key,
      opts: s.options,
      pick: Math.max(
        0,
        s.options.findIndex((m) => m.id === s.pick?.id),
      ),
    });
  }
  return steps;
}

export function Fit(props: { ctx: YardCtx; hull: Hull }) {
  const { ctx, hull } = props;
  const { view, set, own } = ctx;
  const { cols, rows, narrow } = useGrid();
  usePreview(hull.id);
  const h = rows - 1 - TOP;
  const fit = fitOf(hull, view.finish, view.picks);
  const steps = stepsOf(fit);
  // Nothing to fit (no finishes, no rooms): show the bill instead of a blank screen.
  useEffect(() => {
    if (!steps.length) {
      set({ screen: 'bill' });
    }
  }, [steps.length]);
  if (!steps.length) {
    return null;
  }
  const st = Math.min(steps.length - 1, Math.max(0, view.step));
  const S = steps[st];
  const bill = billOf(own, fit, ctx.account);
  const crew = crewOf(fit);
  const crewN = crew.reduce((a, l) => a + l[1], 0);
  const out: ReactNode[] = [];

  const ownedOpt = (o: Finish | Module) =>
    S.slot === null
      ? finishOwned(own, hull, o as Finish)
      : moduleOwned(own, hull, o as Module);
  const choose = (j: number) => {
    const o = S.opts[j];
    if (S.slot === null) {
      set({ finish: o.id });
    } else {
      set({ picks: { ...view.picks, [S.slot]: o.id } });
    }
  };
  const last = st === steps.length - 1;
  const next = () => (last ? set({ screen: 'bill' }) : set({ step: st + 1 }));

  const x = narrow
    ? 0
    : Math.min(48, Math.max(34, Math.floor(cols * 0.36))) + 1;
  const w = cols - x;
  const lw = x - 1;

  // The viewscreen takes what the busiest step's options leave, so it doesn't jump.
  const descRows = (o: Finish | Module) =>
    Math.min(2, wrap(o.desc, w - 6).length);
  const need =
    Math.max(
      ...steps.map((s) => {
        let n = s.opts.length + Math.max(0, ...s.opts.map(descRows));
        if (s.slot === null) {
          n += Math.max(
            0,
            ...s.opts.map(
              (o) =>
                Math.min(2, wrap(jobsText((o as Finish).jobs), w - 12).length) +
                1,
            ),
          );
        }
        return n;
      }),
    ) + (narrow ? 7 : 6);
  const ph = Math.max(narrow ? 6 : 9, Math.min(Math.floor(h * 0.62), h - need));

  if (!narrow) {
    // Step list, total and crew.
    out.push(
      <Frame
        key="steps"
        x={0}
        y={TOP}
        w={lw}
        h={h}
        title={`FIT  ${hull.short.toUpperCase()}`}
      />,
    );
    // Two rows a step when there is room, one when not.
    const pitch = TOP + 2 + steps.length * 2 + 8 <= TOP + h ? 2 : 1;
    let y = TOP + 2;
    steps.forEach((s, i) => {
      const o = s.opts[s.pick];
      const cur = i === st;
      const paid =
        !!o &&
        !(s.slot === null
          ? finishOwned(own, hull, o as Finish)
          : moduleOwned(own, hull, o as Module));
      if (cur) {
        out.push(
          <Put key={`sb${i}`} x={1} y={y} cls="inv">
            {' '.repeat(lw - 3)}
          </Put>,
        );
      }
      out.push(
        <Put key={`sm${i}`} x={1} y={y} cls={cur ? 'inv' : ''}>
          {cur ? '>' : ' '}
        </Put>,
        <Put key={`sl${i}`} x={3} y={y} cls={cur ? 'inv' : 'dim'}>
          {pad(s.label, 14)}
        </Put>,
        <Put key={`sn${i}`} x={18} y={y} cls={cur ? 'inv' : paid ? 'amb' : ''}>
          {pad(o ? o.name : '-', lw - 21)}
        </Put>,
        <Hit
          key={`sh${i}`}
          x={1}
          y={y}
          w={lw - 3}
          h={1}
          onClick={() => set({ step: i })}
        />,
      );
      y += pitch;
    });
    if (pitch === 1) {
      y++;
    }
    out.push(<Rule key="rule" x={1} y={y - 1} w={lw - 2} />);
    const tot = costOf(bill.total) || 'NOTHING DUE';
    const totLines = wrap(tot, lw - 13);
    const short = Object.keys(bill.short).length > 0;
    out.push(
      <Put key="tl" x={3} y={y + 1} cls="dim">
        TOTAL
      </Put>,
    );
    totLines.forEach((l, i) => {
      out.push(
        <Put
          key={`tv${i}`}
          x={10}
          y={y + 1 + i}
          cls={partsOf(bill.total) ? (short ? 'red' : 'amb') : 'dim'}
        >
          {l}
        </Put>,
      );
    });
    let cy = y + 3 + Math.max(0, totLines.length - 1);
    const stop = TOP + h - 4;
    if (cy + 2 < stop) {
      out.push(
        <Put key="cl" x={3} y={cy} cls="dim">
          CREW
        </Put>,
        <Put key="cv" x={10} y={cy}>
          {String(crewN)}
        </Put>,
      );
      cy += 2;
      if (cy + crew.length <= stop) {
        crew.forEach(([job, n], i) => {
          out.push(
            <Put key={`cj${i}`} x={3} y={cy}>
              {pad(job, lw - 10)}
            </Put>,
            <Put key={`cn${i}`} x={lw - 6} y={cy++} cls="dim">
              {lpad(n, 2)}
            </Put>,
          );
        });
      }
    }
    out.push(
      <Key
        key="bill"
        x={3}
        y={TOP + h - 3}
        label="BILL"
        cls="inv"
        onClick={() => set({ screen: 'bill' })}
      />,
    );
  }

  // Viewscreen.
  out.push(
    <Frame
      key="pf"
      x={x}
      y={TOP}
      w={w}
      h={ph}
      title={(fit.finish?.name || hull.short).toUpperCase()}
    />,
    <ShipPic
      key="pic"
      x={x + 2}
      y={TOP + 1.5}
      w={w - 4}
      h={ph - 2.5}
      fit={fit}
      hiSlot={S.slot}
    />,
  );

  // This step's options.
  const oy = TOP + ph;
  const oh = h - ph;
  const title = narrow ? `${S.label}  ${st + 1}/${steps.length}` : S.label;
  out.push(<Frame key="of" x={x} y={oy} w={w} h={oh} title={title} />);
  let y = oy + 2;
  const tagW = 18;
  S.opts.forEach((o, j) => {
    const sel = j === S.pick;
    const owned = ownedOpt(o);
    if (sel) {
      out.push(
        <Put key={`ob${j}`} x={x + 1} y={y} cls="inv">
          {' '.repeat(w - 3)}
        </Put>,
      );
    }
    const tag = o.def ? 'STOCK' : owned ? 'OWNED' : costOf(o.cost);
    out.push(
      <Put key={`om${j}`} x={x + 1} y={y} cls={sel ? 'inv' : ''}>
        {sel ? '>' : ' '}
      </Put>,
      <Put key={`on${j}`} x={x + 3} y={y} cls={sel ? 'inv' : ''}>
        {pad(o.name, w - 6 - Math.min(tagW, tag.length + 2))}
      </Put>,
      <RPut
        key={`ot${j}`}
        x={x + w - 3}
        y={y}
        cls={sel ? 'inv' : owned ? 'dim' : 'amb'}
      >
        {tag}
      </RPut>,
      <Hit
        key={`oh${j}`}
        x={x + 1}
        y={y}
        w={w - 3}
        h={1}
        onClick={() => choose(j)}
      />,
    );
    y++;
  });
  y++;
  const o = S.opts[S.pick];
  const by = oy + oh - 2;
  if (o) {
    const jl =
      S.slot === null ? wrap(jobsText((o as Finish).jobs), w - 12) : [];
    const rowsFree =
      by - (narrow ? 2 : 1) - y - (jl.length ? jl.length + 1 : 0);
    wrap(o.desc, w - 6)
      .slice(0, Math.max(1, rowsFree))
      .forEach((l, i) => {
        out.push(
          <Put key={`od${i}`} x={x + 3} y={y++} cls="dim">
            {l}
          </Put>,
        );
      });
    if (jl.length) {
      y++;
      out.push(
        <Put key="ocl" x={x + 3} y={y} cls="dim">
          CREW
        </Put>,
      );
      jl.slice(0, Math.max(1, by - (narrow ? 2 : 1) - y)).forEach((l, i) => {
        out.push(
          <Put key={`oc${i}`} x={x + 9} y={y++}>
            {l}
          </Put>,
        );
      });
    }
  }
  if (narrow) {
    const tot = costOf(bill.total);
    const short = Object.keys(bill.short).length > 0;
    out.push(
      <Put key="ntl" x={x + 3} y={by - 1} cls="dim">
        {`CREW ${crewN}`}
      </Put>,
    );
    if (tot) {
      out.push(
        <Put key="ntv" x={x + 12} y={by - 1} cls={short ? 'red' : 'amb'}>
          {tot.slice(0, w - 15)}
        </Put>,
      );
    }
    if (!last) {
      out.push(
        <Key
          key="nbill"
          x={x + 3}
          y={by}
          label="BILL"
          cls="dim"
          onClick={() => set({ screen: 'bill' })}
        />,
      );
    }
  }
  if (st > 0) {
    out.push(
      <Key
        key="prev"
        x={x + w - 26}
        y={by}
        label="PREV"
        cls="dim"
        bg
        onClick={() => set({ step: st - 1 })}
      />,
    );
  }
  out.push(
    <Key
      key="next"
      x={x + w - 15}
      y={by}
      label={last ? 'BILL' : 'NEXT'}
      cls="inv"
      onClick={next}
    />,
  );

  return <>{out}</>;
}
