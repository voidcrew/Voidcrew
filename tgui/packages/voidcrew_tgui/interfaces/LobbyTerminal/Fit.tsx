/**
 * FIT (spec 02, 3.5): one step a page. FINISH when the hull has finishes, then one step a room
 * the taken finish offers. Each page: the picture with the current room marked and the steps
 * column beside it, this step's options as slab rows, the shown option's description, the
 * total strip in the class columns, PREV and NEXT.
 *
 * Shown is not taken. Each step has one option TAKEN (in the store: `[#]`, the slab `on`). The
 * option SHOWN is the focused one while the focus is on an option row, else the taken one; it
 * is local here. The picture and the description read the shown option; the total, the `[#]`
 * and the commission read the taken one (ctx.fit and ctx.bill). Enter or a click takes an
 * option; on the option already taken it goes to the next step (the bill after the last).
 *
 * Three regimes by body height B = M - 4.25: normal (B >= 18), small (14.75 <= B < 18, a 6-row
 * picture) and tight (B < 14.75, no picture, the steps in two columns). The layout is worked out
 * once a hull from its largest step and longest text, so nothing moves between steps.
 */
import { type ReactNode, useMemo, useRef, useState } from 'react';

import { sfxInstead } from './motion';
import { usePager } from './nav';
import { ShipPic } from './ShipPic';
import {
  bodyRows,
  BODY_Y,
  Box,
  BOX_Y,
  ClassFigures,
  ClassHeads,
  cut,
  Key,
  Pager,
  Put,
  RPut,
  Slab,
  safe,
  useGrid,
  WipeAt,
  wrap,
  wrapMax,
} from './term';
import type { Hull, Parts } from './types';
import {
  billOf,
  crewCount,
  crewText,
  finishOwned,
  fitOf,
  moduleOwned,
  PART_ORDER,
  partsOf,
  priceText,
  type ShipFit,
  slotOptions,
  stockFit,
  usePreview,
  type YardCtx,
} from './YardTab';

/** Rounds down to a quarter row. */
const f4 = (v: number) => Math.floor(v * 4) / 4;
const clamp = (v: number, lo: number, hi: number) =>
  Math.max(lo, Math.min(hi, v));

/** Body columns 1 to 61. */
const W = 61;
/** An option's name: columns 7 to 32. */
const NAME_W = 26;
/** An option's tag ends on column 60; at most 26 cells. */
const TAG_END = 61;
const TAG_W = 26;

type Opt = {
  id: string;
  name: string;
  desc: string;
  tag: string;
  tagCls: 'dim' | 'amb';
};

type Step = {
  label: string;
  /** The room's slot key, or null for FINISH. */
  slot: string | null;
  opts: Opt[];
  /** The option taken on this step. */
  taken: string | null;
};

/** `STOCK`, `OWNED` (dim) or the price (amber), as the option row shows it. */
function tagOf(
  stock: boolean,
  owned: boolean,
  cost: Parts | null | undefined,
): [string, 'dim' | 'amb'] {
  if (stock || !partsOf(cost)) {
    return ['STOCK', 'dim'];
  }
  if (owned) {
    return ['OWNED', 'dim'];
  }
  return [priceText(cost, TAG_W), 'amb'];
}

function stepsOfFit(ctx: YardCtx, hull: Hull, taken: ShipFit): Step[] {
  const steps: Step[] = [];
  if (hull.finishes.length) {
    steps.push({
      label: 'FINISH',
      slot: null,
      taken: taken.finish?.id ?? null,
      opts: hull.finishes.map((f) => {
        const [tag, tagCls] = tagOf(
          !!f.def,
          finishOwned(ctx.own, hull, f),
          f.cost,
        );
        return {
          id: f.id,
          name: safe(f.name).toUpperCase(),
          desc: safe(f.desc),
          tag,
          tagCls,
        };
      }),
    });
  }
  for (const sl of taken.slots) {
    steps.push({
      label: safe(sl.label),
      slot: sl.key,
      taken: sl.pick?.id ?? null,
      opts: sl.options.map((m) => {
        const [tag, tagCls] = tagOf(
          !!m.def,
          moduleOwned(ctx.own, hull, m),
          m.cost,
        );
        return {
          id: m.id,
          name: safe(m.name).toUpperCase(),
          desc: safe(m.desc),
          tag,
          tagCls,
        };
      }),
    });
  }
  return steps;
}

/** `<n> BERTHS` in white, two spaces, the jobs dim, wrapped to at most `max` lines of 61. */
function crewLines(fit: ShipFit, max: number) {
  const head = `${crewCount(fit)} BERTHS`;
  const jobs = safe(crewText(fit));
  // A stand-in word as wide as the head plus one, so the first line keeps two spaces after it.
  const lead = 'x'.repeat(head.length + 1);
  const text = jobs ? `${lead} ${jobs}` : lead;
  return {
    head,
    lead,
    need: wrap(text, W).length,
    lines: max > 0 ? wrapMax(text, W, max) : [],
  };
}

/** The most options on any step of a hull, every finish counted, and the longest text. */
function measure(hull: Hull) {
  let nOpt = hull.finishes.length;
  let lines = 0;
  const finishes = hull.finishes.length ? hull.finishes : [null];
  for (const f of finishes) {
    const keys = f ? f.slots : hull.slots.map((s) => s.key);
    for (const key of keys) {
      nOpt = Math.max(nOpt, slotOptions(hull, key, f).length);
    }
  }
  for (const m of hull.modules) {
    lines = Math.max(lines, wrap(safe(m.desc), W).length);
  }
  for (const f of hull.finishes) {
    const crew = crewLines(fitOf(hull, f.id, {}), 2).need;
    lines = Math.max(
      lines,
      wrap(safe(f.desc), W).length + Math.min(2, crew),
    );
  }
  return { nOpt: Math.max(1, nOpt), Dwant: Math.min(8, lines) };
}

type Regime = {
  kind: 'normal' | 'small' | 'tight';
  /** Picture rows (0 when tight). */
  T: number;
  /** Steps rows when tight. */
  S: number;
  /** Option pitch. */
  po: number;
  /** Option rows on a page. */
  rowsO: number;
  /** The options page (a Pager row under them). */
  paged: boolean;
  /** Description lines. */
  D: number;
};

/**
 * The body ends a quarter row above the other screens' (LIFT): the total strip sits that much
 * higher, so its figure row keeps half a row clear of the box bottom. The regime is still
 * chosen on the whole body; the quarter row comes out of the picture.
 */
const LIFT = 0.25;

function regimeOf(
  Bfull: number,
  nOpt: number,
  Dwant: number,
  steps: number,
): Regime {
  const B = Bfull - LIFT;
  if (Bfull >= 18) {
    let po = 1.75;
    let D = Dwant;
    let T = B - 3 - nOpt * po - D;
    let rowsO = nOpt;
    let paged = false;
    if (T < 8.5) {
      po = 1;
      T = B - 3 - nOpt - D;
    }
    if (T < 8.5) {
      D = Math.max(2, D - Math.ceil(8.5 - T));
      T = B - 3 - nOpt - D;
    }
    if (T < 8.5) {
      T = 8.5;
      rowsO = Math.floor(B - 12.5 - D);
      paged = true;
    }
    return { kind: 'normal', T: f4(T), S: 0, po, rowsO, paged, D };
  }
  let kind: Regime['kind'];
  let T = 0;
  let S = 0;
  let rowsO: number;
  let D: number;
  if (Bfull >= 14.75) {
    kind = 'small';
    T = 6 - LIFT;
    rowsO = Math.min(nOpt, Math.floor(Bfull - 10.75));
    D = Math.floor(Bfull - 8.75 - rowsO);
  } else {
    kind = 'tight';
    S = Math.ceil(steps / 2);
    rowsO = Math.min(nOpt, Math.floor(B - 3.75 - S));
    D = Math.floor(B - 2.75 - S - rowsO);
  }
  const paged = nOpt > rowsO;
  if (paged) {
    // The pager takes one of the description's rows; keep two lines of description.
    D -= 1;
    if (D < 2) {
      rowsO = Math.max(1, rowsO - (2 - D));
      D = 2;
    }
  }
  return { kind, T, S, po: 1, rowsO, paged, D };
}

export function Fit(props: { ctx: YardCtx; hull: Hull }) {
  const { ctx, hull } = props;
  const { rows } = useGrid();
  usePreview(hull.id);
  const M = rows;
  const B = bodyRows(M);

  // Taken: the store's fit of this hull.
  const taken: ShipFit =
    ctx.fit && ctx.fit.hull.id === hull.id ? ctx.fit : stockFit(hull);
  const bill =
    ctx.bill && ctx.fit && ctx.fit.hull.id === hull.id
      ? ctx.bill
      : billOf(ctx.own, taken, ctx.account);
  const steps = stepsOfFit(ctx, hull, taken);
  const n = steps.length;
  const at = clamp(ctx.view.step, 0, Math.max(0, n - 1));
  const step: Step | undefined = steps[at];
  const last = at >= n - 1;

  const { nOpt, Dwant } = useMemo(() => measure(hull), [hull]);
  const rg = regimeOf(B, nOpt, Dwant, n);
  /** Options taken so far on this screen: each one is shown being fitted in the picture. */
  const [took, setTook] = useState(0);
  const lastWheel = useRef(0);

  // Local: the option focused (shown), the options page, and focus claims. Reset a step.
  const stepKey = `${hull.id}:${at}`;
  const [loc, setLoc] = useState({
    key: stepKey,
    focus: null as string | null,
    page: 0,
    claim: null as string | null,
    toSteps: 0,
    toNext: 0,
  });
  let cur = loc;
  if (loc.key !== stepKey) {
    cur = {
      key: stepKey,
      focus: null,
      page: 0,
      claim: null,
      toSteps: 0,
      toNext: 0,
    };
    setLoc(cur);
  }

  const opts = step ? step.opts : [];
  const per = Math.max(1, rg.rowsO);
  const pages = Math.max(1, Math.ceil(opts.length / per));
  const takenAt = Math.max(
    0,
    opts.findIndex((o) => o.id === step?.taken),
  );
  // Entering a step: the page holding the option taken.
  const page = clamp(cur.page || Math.floor(takenAt / per) + 1, 1, pages);
  const pageOpts = opts.slice((page - 1) * per, page * per);
  const claim = cur.claim ?? step?.taken ?? null;

  const shownId =
    cur.focus && opts.some((o) => o.id === cur.focus)
      ? cur.focus
      : step?.taken ?? null;
  const shownOpt = opts.find((o) => o.id === shownId) || null;
  const takenFinish = taken.finish?.id ?? null;
  const picks: Record<string, string> = {};
  for (const sl of taken.slots) {
    if (sl.pick) {
      picks[sl.key] = sl.pick.id;
    }
  }
  let shownFit: ShipFit = taken;
  if (step && shownId && shownId !== step.taken) {
    shownFit =
      step.slot === null
        ? fitOf(hull, shownId, picks)
        : fitOf(hull, takenFinish, { ...picks, [step.slot]: shownId });
  }

  const goStep = (i: number) => {
    if (i >= n) {
      ctx.go.bill();
    } else if (i >= 0) {
      ctx.go.fit(i);
    }
  };
  const take = (o: Opt) => {
    if (!step) {
      return;
    }
    if (o.id === step.taken) {
      goStep(at + 1);
      return;
    }
    // The part seating, in place of the key press; the picture shows it going in.
    sfxInstead('slot');
    setTook((t) => t + 1);
    const slot = step.slot;
    ctx.set((v) => {
      const mine = v.fitHull === hull.id;
      const base = mine ? v.picks : {};
      return slot === null
        ? { fitHull: hull.id, finish: o.id, picks: base }
        : {
            fitHull: hull.id,
            finish: mine ? v.finish : takenFinish,
            picks: { ...base, [slot]: o.id },
          };
    });
  };
  const turn = (to: number, claimId: string | null) => {
    setLoc((l) => ({ ...l, page: to, claim: claimId }));
    return true;
  };

  // PageDown / PageUp: NEXT / PREV.
  usePager((d) => {
    if (!ctx.view.leave) {
      goStep(d > 0 ? at + 1 : at > 0 ? at - 1 : -1);
    }
  });

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
  );

  // A step: a focus target (not a tab item); Enter or a click opens it.
  const stepRow = (
    s: Step,
    i: number,
    x: number,
    y: number,
    w: number,
    h: number,
    alt: boolean,
  ) => {
    const on = i === at;
    return (
      <Slab
        key={`st-${i}-${on ? cur.toSteps : 0}`}
        variant="row"
        x={x}
        y={y}
        w={w}
        h={h}
        alt={alt}
        on={on}
        auto={on && cur.toSteps > 0 ? 3 : undefined}
        onClick={() => goStep(i)}
      >
        <Put x={x + 2} y={y + (h - 1) / 2} cls={on ? 'wht' : 'dim'}>
          {cut(s.label.toUpperCase(), w - 3)}
        </Put>
      </Slab>
    );
  };

  // The picture and the steps.
  if (rg.kind !== 'tight') {
    out.push(
      <ShipPic
        key="pic"
        x={1}
        y={BODY_Y}
        w={38}
        h={rg.T}
        fit={shownFit}
        hiSlot={step?.slot ?? null}
        took={took}
      />,
    );
    // Spec 3.5 caps the pitch at 1.75; a tall picture left the column half empty, so it
    // runs to 2.25 (the slab 2 rows, its label centred).
    const ps = rg.kind === 'small' ? 1 : clamp(f4(rg.T / n), 1, 2.25);
    const sh = ps < 1.25 ? 1 : ps - 0.25;
    const vis = Math.min(n, Math.max(1, Math.floor((rg.T + 0.25) / ps)));
    const first = clamp(at - Math.floor(vis / 2), 0, n - vis);
    for (let j = 0; j < vis; j++) {
      const i = first + j;
      out.push(
        stepRow(
          steps[i],
          i,
          40,
          BODY_Y + j * ps,
          22,
          sh,
          ps < 1.25 && j % 2 === 1,
        ),
      );
    }
  } else {
    for (let i = 0; i < n; i++) {
      const col = i < rg.S ? 0 : 1;
      const row = col ? i - rg.S : i;
      out.push(
        stepRow(
          steps[i],
          i,
          col ? 32 : 1,
          BODY_Y + row,
          30,
          1,
          row % 2 === 1,
        ),
      );
    }
  }

  // The options.
  const yO = BODY_Y + 0.25 + (rg.kind === 'tight' ? rg.S : rg.T);
  const oh = rg.po === 1.75 ? 1.5 : 1;
  const optRows: ReactNode[] = [];
  pageOpts.forEach((o, j) => {
    const y = yO + j * rg.po;
    const isTaken = o.id === step?.taken;
    const first = j === 0;
    const lastRow = j === pageOpts.length - 1;
    const ty = y + (oh - 1) / 2;
    optRows.push(
      <Slab
        key={`o-${stepKey}-${page}-${o.id}`}
        variant="row"
        x={1}
        y={y}
        w={W}
        h={oh}
        alt={rg.po === 1 && j % 2 === 1}
        on={isTaken}
        auto={o.id === claim ? 2 : undefined}
        onClick={() => take(o)}
        onFocus={(f) =>
          setLoc((l) =>
            f
              ? { ...l, focus: o.id }
              : l.focus === o.id
                ? { ...l, focus: null }
                : l,
          )
        }
        edge={{
          // Up from the first row: the page before, or on the first page the step being
          // fitted (not whichever step row happens to sit nearest above).
          up: () => {
            if (!first) {
              return false;
            }
            if (page > 1) {
              return turn(page - 1, opts[(page - 1) * per - 1].id);
            }
            setLoc((l) => ({ ...l, toSteps: l.toSteps + 1 }));
            return true;
          },
          down: () => {
            if (!lastRow) {
              return false;
            }
            if (page < pages) {
              return turn(page + 1, opts[page * per].id);
            }
            setLoc((l) => ({ ...l, toNext: l.toNext + 1 }));
            return true;
          },
          right: () => {
            setLoc((l) => ({ ...l, toSteps: l.toSteps + 1 }));
            return true;
          },
        }}
      >
        <Put x={3} y={ty} cls={isTaken ? 'acc' : 'dim'}>
          {isTaken ? '[#]' : '[ ]'}
        </Put>
        <Put x={7} y={ty} cls={isTaken ? 'wht' : ''}>
          {cut(
            o.name,
            // The row's free width: up to two cells before the tag.
            Math.max(NAME_W, TAG_END - Math.min(TAG_W, o.tag.length) - 9),
          )}
        </Put>
        <RPut x={TAG_END} y={ty} cls={o.tagCls}>
          {cut(o.tag, TAG_W)}
        </RPut>
      </Slab>,
    );
  });
  // The mouse wheel over the options turns their page, as the pager does.
  out.push(
    <div
      key="owheel"
      className="lt-wheel"
      onWheel={(e) => {
        if (pages <= 1 || !e.deltaY) {
          return;
        }
        const now = Date.now();
        if (now - lastWheel.current < 150) {
          return;
        }
        lastWheel.current = now;
        const to = page + (e.deltaY > 0 ? 1 : -1);
        if (to >= 1 && to <= pages) {
          turn(to, opts[(to - 1) * per].id);
        }
      }}
    >
      {optRows}
    </div>,
  );
  let yD = yO + rg.rowsO * rg.po + 0.25;
  if (rg.paged) {
    if (pages > 1) {
      out.push(
        <Pager
          key="opg"
          x={TAG_END}
          y={yO + rg.rowsO * rg.po}
          right
          page={page}
          pages={pages}
          onPage={(p) => turn(p, opts[(p - 1) * per].id)}
        />,
      );
    }
    yD += 1;
  }

  // The description of the shown option; on FINISH, the crew it brings under it.
  if (shownOpt) {
    let lines: string[] = [];
    let crew: ReturnType<typeof crewLines> | null = null;
    if (step?.slot === null) {
      const need = crewLines(shownFit, 2).need;
      const c = Math.max(0, Math.min(2, need, rg.D - 1));
      crew = crewLines(shownFit, c);
      lines = shownOpt.desc ? wrapMax(shownOpt.desc, W, rg.D - c) : [];
    } else {
      lines = shownOpt.desc ? wrapMax(shownOpt.desc, W, rg.D) : [];
    }
    let y = yD;
    lines.forEach((line, i) => {
      out.push(
        <Put key={`d${i}`} x={1} y={y}>
          {line}
        </Put>,
      );
      y += 1;
    });
    if (crew) {
      crew.lines.forEach((line, i) => {
        if (i === 0) {
          out.push(
            <Put key="ch" x={1} y={y} cls="wht">
              {crew.head}
            </Put>,
            <Put key="c0" x={1 + crew.lead.length} y={y} cls="dim">
              {line.slice(crew.lead.length).trimStart()}
            </Put>,
          );
        } else {
          out.push(
            <Put key={`c${i}`} x={1} y={y} cls="dim">
              {line}
            </Put>,
          );
        }
        y += 1;
      });
    }
  }

  // A step change, and a page of options turning, wipe the options and the description only:
  // the picture and the steps stay, with the marker on the new room.
  const yK = M - 3.25;
  out.push(
    <WipeAt
      key="turn"
      x={1}
      y={yO}
      w={W}
      h={yK - 0.25 - yO}
      k={`${stepKey}:${page}`}
      n={at * 1000 + page}
    />,
  );

  // The total strip: what the fit as taken costs now, in set F.
  const yT = yK - LIFT;
  const due = partsOf(bill.total) > 0;
  if (due) {
    const short = ctx.ledger === 'ok' ? bill.short : {};
    const cls: Record<string, string> = {};
    for (const k of PART_ORDER) {
      cls[k] = (short[k] || 0) > 0 ? 'inva' : 'amb';
    }
    out.push(
      <Put key="tt" x={1} y={yT} cls="dim">
        TOTAL
      </Put>,
      <ClassHeads key="th" y={yT} set="F" />,
      <ClassFigures
        key="tf"
        y={yT + 1}
        set="F"
        values={bill.total}
        cls={cls}
        pulse
      />,
    );
  } else {
    out.push(
      <Put key="nd" x={1} y={yT + 1} cls="dim">
        NOTHING DUE
      </Put>,
      // Kept mounted (empty), so the first figure due flashes as it appears.
      <ClassFigures key="tf" y={yT + 1} set="F" values={{}} pulse />,
    );
  }
  out.push(
    <Key
      key="prev"
      kind="box"
      x={39}
      y={yK + 0.5}
      w={8}
      h={1.5}
      label="PREV"
      state={at > 0 ? 'idle' : 'dead'}
      onClick={() => goStep(at - 1)}
    />,
    <Key
      key={`next-${cur.toNext}`}
      kind="big"
      x={48}
      y={yK}
      w={14}
      h={2}
      label={last ? 'BILL' : 'NEXT'}
      auto={cur.toNext > 0 ? 3 : undefined}
      onClick={() => goStep(at + 1)}
    />,
  );

  return <>{out}</>;
}
