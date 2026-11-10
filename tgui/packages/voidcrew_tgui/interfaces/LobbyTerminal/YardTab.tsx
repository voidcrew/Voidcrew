/**
 * SHIPYARD tab: home (new ship, requisition, saved ships), then HULLS -> hull record ->
 * FIT -> BILL. Where the player is and what they picked stays in React (a module-level
 * store, so it survives a tab switch); only yard_* actions reach DM.
 *
 * The catalog arrives in static data only after `yard_open`. Keys: see types.ts.
 */
import { type ReactNode, useEffect, useMemo, useState } from 'react';
import { useBackend } from 'tgui/backend';

import { Bill } from './Bill';
import { Fit } from './Fit';
import { Hulls } from './Hulls';
import { SaveSlots } from './SaveSlots';
import { Frame, Put, RPut, TOP, useGrid } from './term';
import type {
  CrewLine,
  Finish,
  Hull,
  LobbyData,
  Module,
  Owned,
  PartClass,
  Parts,
} from './types';

// ---------------------------------------------------------------------------
// Catalog helpers (shared by Hulls, HullRecord, Fit and Bill).
// ---------------------------------------------------------------------------

export const PART_ORDER: PartClass[] = ['combat', 'science', 'trade', 'misc'];

/** "4 COMBAT  2 TRADE", or '' when nothing is due. */
export function costOf(cost?: Parts | null): string {
  return PART_ORDER.filter((k) => (cost?.[k] || 0) > 0)
    .map((k) => `${cost?.[k]} ${k.toUpperCase()}`)
    .join('  ');
}

export function partsOf(cost?: Parts | null): number {
  return PART_ORDER.reduce((a, k) => a + (cost?.[k] || 0), 0);
}

/** 1,850 */
export function thousands(n: number): string {
  return String(Math.round(n)).replace(/\B(?=(\d{3})+(?!\d))/g, ',');
}

export type Ownership = {
  owned: Owned | null | undefined;
  /** FREE_SHIPS config: everything is free. */
  free: boolean;
};

export function hullOwned(o: Ownership, hull: Hull): boolean {
  return (
    o.free ||
    !!hull.free ||
    !partsOf(hull.cost) ||
    !!o.owned?.hulls?.includes(hull.id)
  );
}

export function finishOwned(o: Ownership, hull: Hull, f: Finish): boolean {
  return (
    o.free ||
    !!f.def ||
    !partsOf(f.cost) ||
    !!o.owned?.finishes?.[hull.id]?.includes(f.id)
  );
}

export function moduleOwned(o: Ownership, hull: Hull, m: Module): boolean {
  return (
    o.free ||
    !!m.def ||
    !partsOf(m.cost) ||
    !!o.owned?.modules?.[hull.id]?.includes(m.id)
  );
}

/** Upper-case label for a slot key: from the catalog, else the key without its hull prefix. */
export function slotLabel(hull: Hull, key: string): string {
  const known = hull.slots.find((s) => s.key === key);
  let s = (known?.label || key).toLowerCase();
  const pre = `${key.split('_')[0]}_`;
  if (!known && s.startsWith(pre)) {
    s = s.slice(pre.length);
  }
  return s.replace(/_s_/g, "'s ").replace(/_/g, ' ').toUpperCase();
}

/** The default finish, or the first, or null for a hull without finishes. */
export function defaultFinish(hull: Hull): Finish | null {
  return hull.finishes.find((f) => !!f.def) || hull.finishes[0] || null;
}

/** Modules for a slot under a finish, the stock one first. */
export function slotOptions(
  hull: Hull,
  key: string,
  finish: Finish | null,
): Module[] {
  const opts = hull.modules.filter(
    (m) =>
      m.slot === key && (!m.themes || !finish || m.themes.includes(finish.id)),
  );
  return [...opts.filter((m) => !!m.def), ...opts.filter((m) => !m.def)];
}

export type FitSlot = {
  key: string;
  label: string;
  options: Module[];
  pick: Module | null;
};

export type ShipFit = {
  hull: Hull;
  finish: Finish | null;
  slots: FitSlot[];
};

/**
 * The configuration as it would be built. A pick the finish doesn't offer falls back to
 * that finish's stock module, as the server resets picks on a finish change.
 */
export function fitOf(
  hull: Hull,
  finishId: string | null,
  picks: Record<string, string>,
): ShipFit {
  const finish =
    hull.finishes.find((f) => f.id === finishId) || defaultFinish(hull);
  const keys: string[] = finish ? finish.slots : hull.slots.map((s) => s.key);
  const slots = keys.map((key) => {
    const options = slotOptions(hull, key, finish);
    const pick = options.find((m) => m.id === picks[key]) || options[0] || null;
    return { key, label: slotLabel(hull, key), options, pick };
  });
  return { hull, finish, slots };
}

/** The stock fit of a hull. */
export function stockFit(hull: Hull): ShipFit {
  return fitOf(hull, null, {});
}

/** Crew manifest of a fit, same titles summed. */
export function crewOf(fit: ShipFit): CrewLine[] {
  const out: CrewLine[] = [];
  const add = (lines?: CrewLine[]) => {
    for (const [title, n] of lines || []) {
      const have = out.find((l) => l[0] === title);
      if (have) {
        have[1] += n;
      } else {
        out.push([title, n]);
      }
    }
  };
  add(fit.finish ? fit.finish.jobs : fit.hull.jobs);
  for (const s of fit.slots) {
    if (s.pick) {
      const jobs = s.pick.jobs || {};
      add((fit.finish && jobs[fit.finish.id]) || jobs[''] || []);
    }
  }
  return out;
}

export function crewCount(fit: ShipFit): number {
  return crewOf(fit).reduce((a, l) => a + l[1], 0);
}

/** [label, name, cost or null when owned] */
export type BillLine = [string, string, Parts | null];

export type ShipBill = {
  lines: BillLine[];
  total: Parts;
  short: Parts;
};

export function billOf(
  o: Ownership,
  fit: ShipFit,
  account: Parts | null | undefined,
): ShipBill {
  const { hull, finish } = fit;
  const lines: BillLine[] = [
    ['HULL', hull.short, hullOwned(o, hull) ? null : hull.cost],
  ];
  if (finish) {
    lines.push([
      'FINISH',
      finish.name,
      finishOwned(o, hull, finish) ? null : finish.cost,
    ]);
  }
  for (const s of fit.slots) {
    if (s.pick) {
      lines.push([
        s.label,
        s.pick.name,
        moduleOwned(o, hull, s.pick) ? null : s.pick.cost,
      ]);
    }
  }
  const total: Parts = {};
  for (const l of lines) {
    for (const k of PART_ORDER) {
      const n = l[2]?.[k] || 0;
      if (n) {
        total[k] = (total[k] || 0) + n;
      }
    }
  }
  const short: Parts = {};
  for (const k of PART_ORDER) {
    const due = total[k] || 0;
    const have = account?.[k] || 0;
    if (due > have) {
      short[k] = due - have;
    }
  }
  return { lines, total, short };
}

// ---------------------------------------------------------------------------
// UI-local state.
// ---------------------------------------------------------------------------

export type YardScreen = 'home' | 'hulls' | 'fit' | 'bill';

export type YardView = {
  screen: YardScreen;
  /** Selected hull id (HULLS record, FIT, BILL). */
  hull: string | null;
  finish: string | null;
  /** slot key -> module id */
  picks: Record<string, string>;
  step: number;
  /** The key that has been pressed once and now reads CONFIRM. */
  confirm: string | null;
};

const HOME: YardView = {
  screen: 'home',
  hull: null,
  finish: null,
  picks: {},
  step: 0,
  confirm: null,
};

/** Survives the tab unmounting (tab switch, the CONFIRMED box). */
const store: { view: YardView } = { view: HOME };
/** Hulls whose preview pictures have been asked for this session. */
const previewed = new Set<string>();

export type SetView = (patch: Partial<YardView>) => void;

function useYardView(): [YardView, SetView] {
  const [view, setView] = useState<YardView>(store.view);
  const set: SetView = (patch) =>
    setView((prev) => {
      const next = { ...prev, confirm: null, ...patch };
      store.view = next;
      return next;
    });
  return [view, set];
}

/** Ask once per hull for its preview pictures. */
export function usePreview(hullId: string | null) {
  const { act } = useBackend<LobbyData>();
  useEffect(() => {
    if (hullId && !previewed.has(hullId)) {
      previewed.add(hullId);
      act('yard_preview', { hull: hullId });
    }
  }, [hullId]);
}

/** Everything the screens need, worked out once per render. */
export type YardCtx = {
  view: YardView;
  set: SetView;
  catalog: Hull[];
  hull: Hull | null;
  own: Ownership;
  account: Parts | null | undefined;
  /** Commissioning, requisition and loading are open (round running). */
  open: boolean;
  crewChange: string | null;
};

// ---------------------------------------------------------------------------
// Shared bits of drawing.
// ---------------------------------------------------------------------------

/** A `[ LABEL ]` key in any colour class; faint and dead when disabled. */
export function Key(props: {
  x: number;
  y: number;
  label: string;
  cls?: string;
  right?: boolean;
  disabled?: boolean;
  bg?: boolean;
  onClick?: () => void;
}) {
  const { x, y, label, cls = '', right, disabled, bg, onClick } = props;
  const text = `[ ${label} ]`;
  const at = right ? x - text.length : x;
  if (disabled) {
    return (
      <Put x={at} y={y} cls="faint" bg={bg}>
        {text}
      </Put>
    );
  }
  const amber = cls === 'amb' || cls === 'inva';
  return (
    <Put
      x={at}
      y={y}
      cls={cls}
      hoverCls={amber ? 'inva' : 'inv'}
      bg={bg}
      onClick={onClick}
    >
      {text}
    </Put>
  );
}

/** Breadcrumb and [ BACK ] on the tab row, right-aligned. */
function Crumbs(props: { ctx: YardCtx; screen: YardScreen }) {
  const { ctx, screen } = props;
  const { view, set, hull } = ctx;
  const { cols } = useGrid();
  const seg: [string, (() => void) | null][] = [
    ['SHIPYARD', () => set({ screen: 'home', hull: null })],
    [
      'HULLS',
      () =>
        set({
          screen: 'hulls',
          hull: screen === 'hulls' ? null : view.hull,
        }),
    ],
  ];
  if (hull && screen !== 'hulls') {
    seg.push([hull.short.toUpperCase(), () => set({ screen: 'hulls' })]);
  }
  if (screen === 'fit' || screen === 'bill') {
    seg.push(['FIT', () => set({ screen: 'fit' })]);
  }
  if (screen === 'bill') {
    seg.push(['BILL', null]);
  }
  // The tab names end near column 41; drop leading crumbs until the rest fits.
  const room = cols - 1 - 42 - 12;
  const width = () => seg.map((s) => s[0]).join(' / ').length;
  while (seg.length > 1 && width() > room) {
    seg.shift();
  }
  const showCrumbs = width() <= room;
  const back: Record<YardScreen, Partial<YardView>> = {
    home: {},
    hulls: view.hull ? { hull: null } : { screen: 'home', hull: null },
    fit: { screen: 'hulls' },
    bill: { screen: 'fit' },
  };
  const out: ReactNode[] = [];
  let x = cols - 1 - (showCrumbs ? width() : 0);
  out.push(
    <Key
      key="back"
      x={x - 12}
      y={2}
      label="BACK"
      cls="dim"
      onClick={() => set(back[screen])}
    />,
  );
  if (showCrumbs) {
    seg.forEach(([label, go], i) => {
      const last = i === seg.length - 1;
      out.push(
        <Put
          key={`c${i}`}
          x={x}
          y={2}
          cls={last ? '' : 'dim'}
          hoverCls={last ? undefined : ''}
          onClick={last || !go ? undefined : go}
        >
          {label}
        </Put>,
      );
      x += label.length;
      if (!last) {
        out.push(
          <Put key={`s${i}`} x={x} y={2} cls="faint">
            {' / '}
          </Put>,
        );
        x += 3;
      }
    });
  }
  return <>{out}</>;
}

// ---------------------------------------------------------------------------
// Home: NEW SHIP, REQUISITION, SAVED SHIPS.
// ---------------------------------------------------------------------------

function Home(props: { ctx: YardCtx }) {
  const { ctx } = props;
  const { data, act } = useBackend<LobbyData>();
  const { cols, rows, narrow } = useGrid();
  const bottom = rows - 1;
  const req = !!data.can_requisition;
  const account = data.account || {};
  const confirmReq = ctx.view.confirm === 'req';
  const reqLine = ctx.crewChange
    ? `LEAVES ${ctx.crewChange.toUpperCase()}`
    : 'SURPLUS HULL';

  const requisition = () => {
    if (ctx.crewChange && !confirmReq) {
      ctx.set({ confirm: 'req' });
      return;
    }
    ctx.set({ confirm: null });
    act('yard_requisition', { leave_crew: ctx.crewChange ? 1 : 0 });
  };
  const newShip = () => ctx.set({ screen: 'hulls', hull: null });

  const out: ReactNode[] = [];
  let th = 5;
  const y = TOP + 2;
  if (narrow) {
    // One box: NEW SHIP and the parts on account, the surplus hull below.
    th = req ? 6 : 5;
    out.push(
      <Frame key="ns" x={0} y={TOP} w={cols} h={th} title="NEW SHIP" />,
      <Key
        key="nsk"
        x={3}
        y={y}
        label="NEW SHIP"
        cls="inv"
        onClick={newShip}
      />,
    );
    const short = PART_ORDER.map(
      (k) => `${k.slice(0, 3).toUpperCase()} ${account[k] || 0}`,
    ).join('  ');
    if (cols - 20 >= short.length) {
      out.push(
        <RPut key="nsp" x={cols - 3} y={y} cls="dim">
          {short}
        </RPut>,
      );
    }
    if (req) {
      out.push(
        <Put key="rl" x={3} y={y + 1} cls="amb">
          {reqLine.slice(0, cols - 24)}
        </Put>,
        <Key
          key="rk"
          x={cols - 3}
          y={y + 1}
          right
          label={confirmReq ? 'CONFIRM' : 'REQUISITION'}
          cls="inva"
          disabled={!ctx.open}
          onClick={requisition}
        />,
      );
    }
  } else {
    const lw = req ? Math.floor(cols * 0.62) : cols;
    out.push(
      <Frame key="ns" x={0} y={TOP} w={lw} h={th} title="NEW SHIP" />,
      <Key
        key="nsk"
        x={3}
        y={y}
        label="NEW SHIP"
        cls="inv"
        onClick={newShip}
      />,
    );
    const segs = PART_ORDER.map((k) => [
      k.toUpperCase(),
      String(account[k] || 0),
    ]);
    const partsW =
      7 +
      segs.reduce((a, [k, n]) => a + k.length + 1 + n.length, 0) +
      3 * (segs.length - 1);
    let x = lw - 3 - partsW;
    out.push(
      <Put key="pl" x={x} y={y} cls="dim">
        PARTS
      </Put>,
    );
    x += 7;
    for (const [k, n] of segs) {
      out.push(
        <Put key={`pk${k}`} x={x} y={y} cls="dim">
          {k}
        </Put>,
        <Put key={`pn${k}`} x={x + k.length + 1} y={y}>
          {n}
        </Put>,
      );
      x += k.length + 1 + n.length + 3;
    }
    if (req) {
      const rx = lw + 1;
      const rw = cols - lw - 1;
      out.push(
        <Frame key="rq" x={rx} y={TOP} w={rw} h={th} title="REQUISITION" />,
        <Put key="rl" x={rx + 3} y={y} cls="amb">
          {reqLine.slice(0, Math.max(0, rw - 23))}
        </Put>,
        <Key
          key="rk"
          x={rx + rw - 3}
          y={y}
          right
          label={confirmReq ? 'CONFIRM' : 'REQUISITION'}
          cls="inva"
          disabled={!ctx.open}
          onClick={requisition}
        />,
      );
    }
  }

  if (data.saves) {
    out.push(
      <SaveSlots
        key="saves"
        saves={data.saves}
        x={0}
        y={TOP + th}
        w={cols}
        h={bottom - TOP - th}
        ctx={ctx}
      />,
    );
  }
  return <>{out}</>;
}

// ---------------------------------------------------------------------------

function Waiting() {
  const { cols, rows } = useGrid();
  return (
    <Frame x={0} y={TOP} w={cols} h={rows - 1 - TOP} title="HULLS">
      <Put x={3} y={TOP + 2} cls="dim">
        CONTACTING THE YARD...
      </Put>
    </Frame>
  );
}

export function YardTab() {
  const { data, act } = useBackend<LobbyData>();
  const [view, set] = useYardView();
  useEffect(() => {
    act('yard_open');
  }, []);

  const catalog = useMemo(() => data.catalog || [], [data.catalog]);
  const hull = useMemo(
    () => catalog.find((h) => h.id === view.hull) || null,
    [catalog, view.hull],
  );
  const ctx: YardCtx = {
    view,
    set,
    catalog,
    hull,
    own: { owned: data.owned, free: !!data.free_ships },
    account: data.account,
    open: data.phase === 'playing',
    crewChange: data.crew_change || null,
  };

  let screen = view.screen;
  if ((screen === 'fit' || screen === 'bill') && !hull && !!data.catalog) {
    screen = 'hulls';
  }
  let body: ReactNode;
  if (screen === 'home') {
    body = <Home ctx={ctx} />;
  } else if (!data.catalog) {
    body = <Waiting />;
  } else if (screen === 'hulls') {
    body = <Hulls ctx={ctx} />;
  } else if (screen === 'fit' && hull) {
    body = <Fit ctx={ctx} hull={hull} />;
  } else if (hull) {
    body = (
      <Bill
        ctx={ctx}
        hull={hull}
        onCommission={(params) => {
          // The client forgets the fit once it is sent.
          set(HOME);
          act('yard_commission', params);
        }}
      />
    );
  }

  return (
    <>
      {screen !== 'home' && <Crumbs ctx={ctx} screen={screen} />}
      {body}
    </>
  );
}
