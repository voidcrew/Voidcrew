/**
 * SHIPYARD tab: the store, the screen router, the tab row's right zone (BACK, crumbs, the hull
 * stepper) and the helpers every shipyard screen shares. One file a screen: YardHome.tsx
 * (home), Hulls.tsx (list) and HullRecord.tsx (record), Fit.tsx, Bill.tsx, and LeaveCrew.tsx
 * (the LEAVE CREW dialog, drawn by the router over any screen).
 *
 * Screens get everything through `ctx: YardCtx`, worked out once a render here:
 *
 *   ctx.view              the store (YardView). Module level: a tab switch or the CONFIRMED
 *                         box keeps it. Taken values live here (finish, picks); the option
 *                         shown on the fit's open step may live here (`shown`) or in the Fit.
 *   ctx.set(patch)        patch the store; `patch` may be a function of the current view.
 *   ctx.go.home()         the home.
 *   ctx.go.hulls()        the hull list; it focuses `view.lastHull` and turns to its page.
 *   ctx.go.record(id)     a hull's record.
 *   ctx.go.fitOut(hull)   FIT OUT: keeps the fit when it belongs to this hull, else starts from
 *                         stock. A hull with nothing to fit goes straight to the bill.
 *   ctx.go.fit(step?)     the fit, at `step` or where it was.
 *   ctx.go.bill()         the bill.
 *   ctx.go.back()         [ BACK ] and Escape (spec 02, 2.3). The router mounts the useBack.
 *   ctx.catalog           the shelf ([] until it arrives; ctx.loaded says whether it has).
 *   ctx.hull              the hull open in the record, fit or bill, or null.
 *   ctx.fit, ctx.bill     that hull's fit as taken (fitOf) and its bill (billOf), or null.
 *   ctx.own, ctx.account, ctx.ledger ('wait' | 'ok' | 'off')
 *   ctx.open              the port is open (2.5). Keys that put the player in the round are
 *                         dead while it is not; YARD_OPENS is the one line that says why.
 *   ctx.sent              a founding key was just sent (2.6): draw those keys dead.
 *   ctx.crewChange        the crew the player would leave, or null.
 *   ctx.found(ask)        press COMMISSION, REQUISITION or LOAD: in a crew it opens LEAVE
 *                         CREW (not for a load that `restores`), otherwise it sends with
 *                         leave_crew 0. Only the dialog's own key ever sends leave_crew 1.
 *
 * Helpers: PART_ORDER, costOf, partsOf, priceText, thousands, hullOwned, finishOwned,
 * moduleOwned, slotLabel, defaultFinish, slotOptions, fitOf, stockFit, fittable, stepsOf,
 * crewOf, crewCount, crewText, billOf (the one place the page works a bill out; its `total` is
 * what yard_commission sends), usePreview. Drawing: ClassHeads, ClassFigures, Well, Slab `on`
 * and fig() are in term.tsx.
 */
import { type ReactNode, useEffect, useMemo, useState } from 'react';
import { useBackend } from 'tgui/backend';

import { Bill } from './Bill';
import { Fit } from './Fit';
import { Hulls } from './Hulls';
import { LeaveCrew } from './LeaveCrew';
import { noteFounding, quietDialogClose, useScreen } from './motion';
import { useBack } from './nav';
import {
  BODY_Y,
  Box,
  BOX_Y,
  Btn,
  NameLine,
  PART_CLASSES,
  Pager,
  Put,
  Slab,
  useGrid,
} from './term';
import type {
  CrewLine,
  Finish,
  Hull,
  LedgerState,
  LobbyActions,
  LobbyData,
  Module,
  Owned,
  PartClass,
  Parts,
} from './types';
import { YardHome } from './YardHome';

// ---------------------------------------------------------------------------
// Numbers and words (spec 02, 2.1)
// ---------------------------------------------------------------------------

export const PART_ORDER: PartClass[] = PART_CLASSES;

/** The line shown before the round, once a tab (2.5). */
export const YARD_OPENS = 'THE YARD OPENS AT DEPARTURE.';

/** "4 COMBAT  2 TRADE", or '' when nothing is due. */
export function costOf(cost?: Parts | null): string {
  return PART_ORDER.filter((k) => (cost?.[k] || 0) > 0)
    .map((k) => `${cost?.[k]} ${k.toUpperCase()}`)
    .join('  ');
}

export function partsOf(cost?: Parts | null): number {
  return PART_ORDER.reduce((a, k) => a + (cost?.[k] || 0), 0);
}

/** A price in `room` cells: by class when it fits, else the sum as `9 PARTS`. */
export function priceText(cost: Parts | null | undefined, room: number): string {
  const byClass = costOf(cost);
  return byClass.length <= room ? byClass : `${partsOf(cost)} PARTS`;
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

/** A hull with finishes or rooms has a fit; one with neither goes from the record to the bill. */
export function fittable(hull: Hull): boolean {
  return !!hull.finishes.length || !!hull.slots.length;
}

/** Steps of a fit: FINISH when the hull has finishes, then one a room. */
export function stepsOf(fit: ShipFit): number {
  return (fit.hull.finishes.length ? 1 : 0) + fit.slots.length;
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

/** The jobs as `Title` or `Title x3`, joined by `, `. */
export function crewText(fit: ShipFit): string {
  return crewOf(fit)
    .filter((l) => l[1] > 0)
    .map(([title, n]) => (n > 1 ? `${title} x${n}` : title))
    .join(', ');
}

/** What a line costs nothing for: a hull that costs nothing, a stock item, one bought earlier. */
export type BillWord = 'FREE' | 'STOCK' | 'OWNED';

export type BillLine = {
  kind: 'hull' | 'finish' | 'module';
  id: string;
  /** HULL, FINISH or the room's label. */
  label: string;
  /** The name of what is built. */
  name: string;
  /** What this line costs now, or null when it costs nothing. */
  cost: Parts | null;
  /** Why it costs nothing (when cost is null). */
  word: BillWord | null;
};

export type ShipBill = {
  lines: BillLine[];
  /** Only the classes due. */
  total: Parts;
  /** Only the classes the account can't cover. Empty when the account isn't known. */
  short: Parts;
};

function lineOf(
  kind: BillLine['kind'],
  id: string,
  label: string,
  name: string,
  cost: Parts,
  stock: boolean,
  owned: boolean,
  free: boolean,
): BillLine {
  let word: BillWord | null = null;
  if (kind === 'hull') {
    word = free || !partsOf(cost) ? 'FREE' : owned ? 'OWNED' : null;
  } else if (stock || !partsOf(cost)) {
    word = 'STOCK';
  } else if (free || owned) {
    word = 'OWNED';
  }
  return { kind, id, label, name, cost: word ? null : cost, word };
}

export function billOf(
  o: Ownership,
  fit: ShipFit,
  account: Parts | null | undefined,
): ShipBill {
  const { hull, finish } = fit;
  const lines: BillLine[] = [
    lineOf(
      'hull',
      hull.id,
      'HULL',
      hull.short,
      hull.cost,
      false,
      !!o.owned?.hulls?.includes(hull.id),
      o.free || !!hull.free,
    ),
  ];
  if (finish) {
    lines.push(
      lineOf(
        'finish',
        finish.id,
        'FINISH',
        finish.name,
        finish.cost,
        !!finish.def,
        finishOwned(o, hull, finish),
        o.free,
      ),
    );
  }
  for (const s of fit.slots) {
    if (s.pick) {
      lines.push(
        lineOf(
          'module',
          s.pick.id,
          s.label,
          s.pick.name,
          s.pick.cost,
          !!s.pick.def,
          moduleOwned(o, hull, s.pick),
          o.free,
        ),
      );
    }
  }
  const total: Parts = {};
  for (const l of lines) {
    for (const k of PART_ORDER) {
      const n = l.cost?.[k] || 0;
      if (n > 0) {
        total[k] = (total[k] || 0) + n;
      }
    }
  }
  const short: Parts = {};
  if (account) {
    for (const k of PART_ORDER) {
      const due = total[k] || 0;
      const have = account[k] || 0;
      if (due > have) {
        short[k] = due - have;
      }
    }
  }
  return { lines, total, short };
}

// ---------------------------------------------------------------------------
// The store
// ---------------------------------------------------------------------------

export type YardScreen = 'home' | 'hulls' | 'fit' | 'bill';

/** A founding key pressed: commission, requisition or load. */
export type FoundAsk =
  | {
      action: 'yard_commission';
      params: Omit<LobbyActions['yard_commission'], 'leave_crew'>;
      label: 'COMMISSION';
    }
  | {
      action: 'yard_requisition';
      params: Record<string, never>;
      label: 'REQUISITION';
    }
  | {
      action: 'yard_load';
      params: { slot: number };
      label: 'LOAD';
      /** The save returns the player to the crew they are in: no question. */
      restores?: boolean;
    };

export type YardView = {
  screen: YardScreen;
  /** On 'hulls': the record open, or null for the list. On 'fit' and 'bill': the hull. */
  hull: string | null;
  /** The hull last opened from the list: the list focuses it and turns to its page. */
  lastHull: string | null;
  /** The hull the fit below belongs to; FIT OUT on any other hull starts from stock. */
  fitHull: string | null;
  /** Taken: the finish id. */
  finish: string | null;
  /** Taken: slot key -> module id. */
  picks: Record<string, string>;
  /** The fit's open step (0 = FINISH when the hull has finishes). */
  step: number;
  /** Shown: the option tried on the open step, or null for the one taken. */
  shown: string | null;
  /** The founding action waiting on the LEAVE CREW dialog, or null. */
  leave: FoundAsk | null;
};

const HOME: YardView = {
  screen: 'home',
  hull: null,
  lastHull: null,
  fitHull: null,
  finish: null,
  picks: {},
  step: 0,
  shown: null,
  leave: null,
};

/** Survives the tab unmounting (tab switch, the CONFIRMED box). */
const store: {
  view: YardView;
  fitSerial: number | null;
  /** The sent-key rule (2.6): the notice it was sent under, and when. */
  sent: { at: number | null; t: number } | null;
} = {
  view: HOME,
  fitSerial: null,
  sent: null,
};
/** Hulls whose preview pictures have been asked for this session. */
const previewed = new Set<string>();

/** How long a sent founding key stays dead when the notice doesn't change. */
const SENT_MS = 4000;

export type SetView = (
  patch: Partial<YardView> | ((view: YardView) => Partial<YardView>),
) => void;

function useYardView(): [YardView, SetView] {
  const [view, setView] = useState<YardView>(store.view);
  const set: SetView = (patch) =>
    setView((prev) => {
      const next = {
        ...prev,
        ...(typeof patch === 'function' ? patch(prev) : patch),
      };
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

export type YardGo = {
  home: () => void;
  hulls: () => void;
  record: (hullId: string) => void;
  fitOut: (hull: Hull) => void;
  fit: (step?: number) => void;
  bill: () => void;
  back: () => void;
};

/** Everything the screens need, worked out once per render. */
export type YardCtx = {
  view: YardView;
  set: SetView;
  go: YardGo;
  catalog: Hull[];
  /** The catalog has arrived (it comes in static data after yard_open). */
  loaded: boolean;
  hull: Hull | null;
  fit: ShipFit | null;
  bill: ShipBill | null;
  own: Ownership;
  account: Parts | null | undefined;
  ledger: LedgerState;
  /** The port is open: commissioning, requisition and loading can run. */
  open: boolean;
  /** A founding key was just sent: draw those keys dead (a courtesy; the server holds the lock). */
  sent: boolean;
  crewChange: string | null;
  found: (ask: FoundAsk) => void;
};

function makeGo(
  view: YardView,
  set: SetView,
  hull: Hull | null,
  fit: ShipFit | null,
): YardGo {
  const go: YardGo = {
    home: () => set({ screen: 'home', hull: null, shown: null }),
    hulls: () =>
      set((v) => ({
        screen: 'hulls',
        hull: null,
        lastHull: v.hull || v.lastHull,
        shown: null,
      })),
    record: (hullId) =>
      set({ screen: 'hulls', hull: hullId, lastHull: hullId, shown: null }),
    fitOut: (hull) =>
      set((v) => {
        const keep = v.fitHull === hull.id;
        const fresh = keep
          ? {}
          : { fitHull: hull.id, finish: null, picks: {}, step: 0 };
        return {
          ...fresh,
          screen: fittable(hull) ? 'fit' : 'bill',
          hull: hull.id,
          lastHull: hull.id,
          step: 0,
          shown: null,
        };
      }),
    fit: (step) =>
      set((v) => ({ screen: 'fit', step: step ?? v.step, shown: null })),
    bill: () => set({ screen: 'bill', shown: null }),
    back: () => {
      const v = view;
      if (v.screen === 'hulls') {
        if (v.hull) {
          set({ hull: null, lastHull: v.hull });
        } else {
          go.home();
        }
      } else if (v.screen === 'fit') {
        set({ screen: 'hulls', shown: null });
      } else if (v.screen === 'bill') {
        // The fit at its last step, or the record for a hull with nothing to fit.
        if (hull && fit && fittable(hull)) {
          go.fit(Math.max(0, stepsOf(fit) - 1));
        } else {
          set({ screen: 'hulls', shown: null });
        }
      }
    },
  };
  return go;
}

// ---------------------------------------------------------------------------
// The tab row's right zone (2.3)
// ---------------------------------------------------------------------------

/** Right edge of the right zone: the box's right edge, column 62. */
const RIGHT_END = 63;
const ZONE_Y = 0.25;

function RightZone(props: { ctx: YardCtx; screen: YardScreen }) {
  const { ctx, screen } = props;
  const { go, hull, catalog } = ctx;
  useBack(screen === 'home' ? null : go.back);
  if (screen === 'home') {
    return null;
  }
  const out: ReactNode[] = [];
  let backEnd = RIGHT_END;
  if (screen === 'hulls' && hull) {
    // The record: [ BACK ], three spaces, the stepper through the catalog in list order.
    const at = catalog.findIndex((h) => h.id === hull.id);
    const n = catalog.length;
    if (n > 1 && at >= 0) {
      const text = `< ${Math.min(99, at + 1)}/${Math.min(99, n)} >`;
      out.push(
        <Pager
          key="step"
          x={RIGHT_END}
          y={ZONE_Y}
          right
          page={at + 1}
          pages={n}
          onPage={(p) => go.record(catalog[p - 1].id)}
        />,
      );
      backEnd = RIGHT_END - text.length - 3;
    }
  } else {
    const crumbs: [string, (() => void) | null][] = [];
    if (screen === 'hulls') {
      crumbs.push(['HULLS', null]);
    } else {
      crumbs.push(['HULLS', go.hulls]);
      const fitting = !!hull && fittable(hull);
      if (fitting) {
        crumbs.push(['FIT', screen === 'fit' ? null : () => go.fit()]);
      }
      crumbs.push(['BILL', screen === 'bill' ? null : go.bill]);
    }
    const width = crumbs.map((c) => c[0]).join(' / ').length;
    let x = RIGHT_END - width;
    backEnd = x - 2;
    crumbs.forEach(([word, onGo], i) => {
      out.push(
        <Put
          key={`c${i}`}
          x={x}
          y={ZONE_Y}
          cls={onGo ? 'dim' : ''}
          hoverCls={onGo ? 'inv' : undefined}
          onClick={onGo || undefined}
        >
          {word}
        </Put>,
      );
      x += word.length;
      if (i < crumbs.length - 1) {
        out.push(
          <Put key={`s${i}`} x={x} y={ZONE_Y} cls="faint">
            {' / '}
          </Put>,
        );
        x += 3;
      }
    });
  }
  out.push(
    // Keyed by screen: it remounts on each screen, so its first-focus claim on the bill
    // registers (the purchase guard: with something due, focus never starts on COMMISSION).
    <Btn
      key={`back-${screen}`}
      x={backEnd}
      y={ZONE_Y}
      right
      label="BACK"
      onClick={go.back}
      auto={screen === 'bill' ? 1 : undefined}
    />,
  );
  return <>{out}</>;
}

// ---------------------------------------------------------------------------
// The catalog not here yet (3.1)
// ---------------------------------------------------------------------------

function Waiting(props: { empty: boolean }) {
  const { rows } = useGrid();
  const [on, setOn] = useState(true);
  useEffect(() => {
    if (props.empty) {
      return;
    }
    const id = setInterval(() => setOn((v) => !v), 530);
    return () => clearInterval(id);
  }, [props.empty]);
  const line = props.empty ? 'NO HULLS ON THE SHELF.' : 'CONTACTING THE YARD.';
  return (
    <>
      <Box x={0} y={BOX_Y} w={63} h={rows - 3.5} caption="HULLS" />
      <Slab x={1} y={BODY_Y} w={61} h={4.75} variant="block" dead>
        <NameLine x={3} y={BODY_Y + 0.25} w={57} text={line} cls="dim" />
        {!props.empty && !!on && (
          <Put x={28} y={BODY_Y + 2.25} cls="inv">
            {' '}
          </Put>
        )}
      </Slab>
    </>
  );
}

// ---------------------------------------------------------------------------
// The router
// ---------------------------------------------------------------------------

export function YardTab(props: { home: number }) {
  const { data, act } = useBackend<LobbyData>();
  const [view, set] = useYardView();
  const [, rerender] = useState(0);
  useEffect(() => {
    act('yard_open');
    // A dialog left open when the tab closed does not come back with it.
    if (store.view.leave) {
      set({ leave: null });
    }
  }, []);
  // SHIPYARD pressed again while on it: back to the yard's front page.
  const [home, setHome] = useState(props.home);
  if (home !== props.home) {
    setHome(props.home);
    if (view.screen !== 'home' || view.leave) {
      set({ screen: 'home', hull: null, shown: null, leave: null });
    }
  }
  // A commission put the player aboard: the fit was built, so forget it. A refusal keeps it.
  const fitSerial = data.fit_serial;
  useEffect(() => {
    if (fitSerial === undefined) {
      return;
    }
    if (store.fitSerial !== null && store.fitSerial !== fitSerial) {
      set(HOME);
    }
    store.fitSerial = fitSerial;
  }, [fitSerial]);

  // The sent-key rule (2.6): dead until the notice changes or SENT_MS pass.
  const noticeAt = data.notice ? data.notice.at : null;
  const sentLeft = store.sent ? store.sent.t + SENT_MS - Date.now() : 0;
  const sent = !!store.sent && store.sent.at === noticeAt && sentLeft > 0;
  useEffect(() => {
    if (!sent) {
      return;
    }
    const id = setTimeout(() => rerender((n) => n + 1), sentLeft + 20);
    return () => clearTimeout(id);
  }, [sent, noticeAt]);

  const send = (ask: FoundAsk, leave: boolean) => {
    // The CONFIRMED box that answers this starts a long job (motion.ts).
    noteFounding();
    store.sent = { at: noticeAt, t: Date.now() };
    rerender((n) => n + 1);
    act(ask.action, { ...ask.params, leave_crew: leave ? 1 : 0 });
  };
  const crewChange = data.crew_change || null;
  const found = (ask: FoundAsk) => {
    if (sent) {
      return;
    }
    const restores = ask.action === 'yard_load' && !!ask.restores;
    if (crewChange && !restores) {
      set({ leave: ask });
      return;
    }
    send(ask, false);
  };

  const loaded = !!data.catalog;
  const catalog = useMemo(() => data.catalog || [], [data.catalog]);
  const hull = useMemo(
    () => catalog.find((h) => h.id === view.hull) || null,
    [catalog, view.hull],
  );
  const own: Ownership = { owned: data.owned, free: !!data.free_ships };
  const fit = hull
    ? view.fitHull === hull.id
      ? fitOf(hull, view.finish, view.picks)
      : stockFit(hull)
    : null;
  const bill = fit ? billOf(own, fit, data.account) : null;
  const ctx: YardCtx = {
    view,
    set,
    go: makeGo(view, set, hull, fit),
    catalog,
    loaded,
    hull,
    fit,
    bill,
    own,
    account: data.account,
    ledger: data.ledger || 'wait',
    open: data.phase === 'playing',
    sent,
    crewChange,
    found,
  };
  let screen = view.screen;
  if (screen !== 'home' && loaded && view.hull && !hull) {
    // The hull left the shelf.
    screen = 'hulls';
  }
  // Each screen is a step further in: going on wipes forward, BACK and an earlier crumb wipe
  // back, and the hull stepper turns a page.
  const onRecord = screen === 'hulls' && !!hull;
  useScreen(
    `shipyard/${onRecord ? 'record' : screen}`,
    onRecord ? 2 : { home: 0, hulls: 1, fit: 3, bill: 4 }[screen],
    onRecord && hull ? hull.id : '',
    onRecord && hull ? catalog.indexOf(hull) : 0,
  );
  let body: ReactNode;
  if (screen === 'home') {
    body = <YardHome ctx={ctx} />;
  } else if (!loaded || !catalog.length) {
    body = <Waiting empty={loaded} />;
  } else if (screen === 'hulls') {
    body = <Hulls ctx={ctx} />;
  } else if (screen === 'fit' && hull) {
    body = <Fit ctx={ctx} hull={hull} />;
  } else if (hull) {
    body = <Bill ctx={ctx} />;
  }

  const leave = view.leave;
  return (
    <>
      <RightZone ctx={ctx} screen={screen} />
      {body}
      {!!leave && !!crewChange && (
        <LeaveCrew
          crew={crewChange}
          label={leave.label}
          onStay={() => set({ leave: null })}
          onGo={() => {
            // Answered, not backed out of: the box goes without the back sound.
            quietDialogClose();
            set({ leave: null });
            send(leave, true);
          }}
        />
      )}
    </>
  );
}
