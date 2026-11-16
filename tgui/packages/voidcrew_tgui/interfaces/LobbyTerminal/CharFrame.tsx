/**
 * The CHARACTER frame (design 03 section 1): the box, the two columns, the ID column
 * (viewscreen, uniform row, a list per screen), the crumbs on the tab row, the level-2 router
 * and the species confirm dialog.
 *
 * Columns of the main region: the ID column is 1 to 21, column 22 is an empty gap, the work
 * column is 23 to 61 (WORK_X, WORK_W). TRAITS uses the whole body (1 to 61).
 *
 * The seam for the editors (ROLES, TRAITS, KIT): each is a screen that draws its own ID column
 * with <IdColumn pv={planId(...).pv}> and its list, and its work column. A level-2 screen
 * (a picker, a colour panel) is opened with useChar().sub(node, crumb, from): the frame then
 * draws `node` instead of the editor's work column, shows the crumb, and Escape or [ BACK ]
 * closes it. `node` is kept as given, so it must read live data itself (a component that calls
 * useBackend()), not values captured when it was opened. `from` names what opened it; that
 * row is given the focus back (useChar().from).
 */
import {
  createContext,
  type ReactNode,
  type WheelEvent as ReactWheelEvent,
  useContext,
  useEffect,
  useRef,
  useState,
} from 'react';
import { useBackend } from 'tgui/backend';

import { turned, Viewscreen } from './CharPreview';
import { quietDialogClose, useChanged } from './motion';
import { useBack, usePager } from './nav';
import {
  Band,
  BODY_Y,
  Box,
  Btn,
  bodyRows,
  cut,
  Dialog,
  Hit,
  Put,
  safe,
  useGrid,
  wrapMax,
} from './term';
import type { CharDir, LobbyData } from './types';
import { nameOf, usePrefsCatalog } from './usePrefsCatalog';

export const ID_X = 1;
export const ID_W = 21;
export const WORK_X = 23;
export const WORK_W = 39;

/** Rounds down to a quarter row. */
export const q = (v: number) => Math.floor(v * 4 + 1e-6) / 4;
export const clamp = (v: number, lo: number, hi: number) =>
  Math.max(lo, Math.min(hi, v));

/** The open section; null is the file view. */
export type Section = 'body' | 'roles' | 'traits' | 'kit';

export type CharNav = {
  /** The facing on screen (kept while CHARACTER is open). */
  dir: CharDir;
  turn: (by: 1 | -1) => void;
  /** Opens a level-2 screen in the work column. from: what opened it (gets the focus back). */
  sub: (node: ReactNode, crumb: string, from?: string) => void;
  /** Closes the level-2 screen. */
  closeSub: () => void;
  /** TRUE while a level-2 screen is open. */
  subOpen: boolean;
  /** What opened the last level-2 screen, while it is closed again; null otherwise. */
  from: string | null;
  /** First-focus claims are off (the shell opened CHARACTER before the round). */
  quiet: boolean;
};

export const CharContext = createContext<CharNav>({
  dir: 2,
  turn: () => undefined,
  sub: () => undefined,
  closeSub: () => undefined,
  subOpen: false,
  from: null,
  quiet: false,
});

export const useChar = () => useContext(CharContext);

/**
 * The ID column's height rule (design 03 section 1.2). need: the list's smallest unpaged
 * height. layout(la): lays the list out in `la` rows and returns the rows it used.
 * Returns the viewscreen height, the room the list had, and the row the list starts on when
 * it is bottom-anchored.
 */
export function planId(
  M: number,
  need: number,
  layout: (la: number) => number,
) {
  const B = bodyRows(M);
  const pv0 = clamp(q(B - 2.25 - need), 6, 10.5);
  const la = B - pv0 - 2.25;
  const used = Math.min(la, layout(la));
  const spare = Math.max(0, la - used);
  const pv = pv0 + Math.min(spare, 14 - pv0);
  return { pv, la, used, top: M - 1.25 - used };
}

/** Slabs a page when an ID-column list has to page (headRows: 1.25 with a head, else 0). */
export const perPage = (la: number, headRows: number) =>
  Math.max(1, Math.floor((la - headRows - 1) / 1.5));

/**
 * The ID column above its list: the viewscreen and the uniform row. uniform: 'live' (one focus
 * stop, Enter shows the next uniform), 'plain' (a label, as ROLES has it) or 'blank'.
 */
export function IdColumn(props: {
  pv: number;
  uniform?: 'live' | 'plain' | 'blank';
  children?: ReactNode;
}) {
  const { pv, uniform = 'live', children } = props;
  const { act, data } = useBackend<LobbyData>();
  const { dir, turn } = useChar();
  const char = data.char;
  const cats = (data.char_static?.roles || [])
    .map((r) => r[0])
    .filter((c) => c !== 'Silicon');
  const dress = char?.dress || '';
  const step = (by: number) => {
    if (!cats.length) {
      return;
    }
    const at = cats.indexOf(dress);
    const next =
      cats[
        (((at < 0 ? 0 : at + by) % cats.length) + cats.length) % cats.length
      ];
    act('char_dress', { category: next });
  };
  const uy = BODY_Y + pv + 0.25;
  const label = cut(safe(dress).toUpperCase(), 15);
  const show = uniform !== 'blank' && !!char;
  return (
    <>
      <Viewscreen x={ID_X} y={BODY_Y} w={ID_W} h={pv} dir={dir} onTurn={turn} />
      <Band x={ID_X} y={uy} w={ID_W} h={1.5} tone="field" />
      {!!show && (
        <Put x={4 + Math.floor((15 - label.length) / 2)} y={uy + 0.25}>
          {label}
        </Put>
      )}
      {!!show && uniform === 'live' && (
        <>
          <Put
            x={2}
            y={uy + 0.25}
            cls="dim"
            hoverCls="inv"
            mouseOnly
            onClick={() => step(-1)}
          >
            {'<'}
          </Put>
          <Put
            x={20}
            y={uy + 0.25}
            cls="dim"
            hoverCls="inv"
            mouseOnly
            onClick={() => step(1)}
          >
            {'>'}
          </Put>
          <Hit x={ID_X} y={uy} w={ID_W} h={1.5} onClick={() => step(1)} />
        </>
      )}
      {children}
    </>
  );
}

/** One crumb: a label and where it goes (null: the last crumb, white and inert). */
export type Crumb = [label: string, go: (() => void) | null];

/** `[ BACK ]`, two spaces, the crumbs: the tab row's right zone, right-aligned to column 62. */
export function Crumbs(props: { crumbs: Crumb[]; onBack: () => void }) {
  const { onBack } = props;
  let parts = props.crumbs;
  let lead = '';
  const text = () => lead + parts.map((p) => p[0]).join(' / ');
  while (text().length > 23 && parts.length > 1) {
    parts = parts.slice(1);
    lead = '… / ';
  }
  const len = Math.min(23, text().length);
  let x = 63 - len;
  const y = 0.25;
  const out: ReactNode[] = [
    <Btn key="back" x={x - 2} y={y} label="BACK" right onClick={onBack} />,
  ];
  if (lead) {
    out.push(
      <Put key="lead" x={x} y={y} cls="faint">
        {lead}
      </Put>,
    );
    x += lead.length;
  }
  parts.forEach(([label, go], i) => {
    const last = i === parts.length - 1;
    const shown = cut(label, 63 - x);
    out.push(
      <Put
        key={`c${i}`}
        x={x}
        y={y}
        cls={last ? 'wht' : 'dim'}
        hoverCls={!last && go ? 'inv' : undefined}
        onClick={!last && go ? go : undefined}
      >
        {shown}
      </Put>,
    );
    x += shown.length;
    if (!last) {
      out.push(
        <Put key={`s${i}`} x={x} y={y} cls="faint">
          {' / '}
        </Put>,
      );
      x += 3;
    }
  });
  return <>{out}</>;
}

/** The species confirm (design 03 section 4.7), drawn over any CHARACTER screen. */
export function SpeciesConfirm() {
  const { act, data } = useBackend<LobbyData>();
  const cat = usePrefsCatalog();
  const confirm = data.char?.confirm;
  const open = !!confirm;
  useBack(open ? () => act('char_confirm', { ok: 0 }) : null);
  const { cols, rows, cw, ch } = useGrid();
  if (!confirm) {
    return null;
  }
  const species = safe(nameOf(cat, 'species', confirm.value)).toUpperCase();
  const quirks = (confirm.quirks || []).map((n) => safe(n).toUpperCase());
  const lines = wrapMax(quirks.join(', '), 41, 3);
  const w = 45;
  const x = Math.floor((63 - w) / 2);
  const y = BODY_Y + 2;
  const by = y + 2 + lines.length + 0.5;
  return (
    <>
      {/* The screen under the dialog dimmed, as LEAVE CREW does. Clicks stop here. */}
      <div
        style={{
          position: 'absolute',
          left: 0,
          top: 0,
          width: Math.round(cols * cw),
          height: Math.round(rows * ch),
          background: 'rgba(15,6,32,.65)',
          zIndex: 7,
        }}
        onClick={(e) => e.stopPropagation()}
      />
      <Dialog w={w} h={6 + lines.length} caption="SPECIES" sound="warn">
        <Put x={x + 2} y={y + 1} cls="wht">
          {cut(`${species} CAN'T KEEP:`, 41)}
        </Put>
        {lines.map((line, i) => (
          <Put key={i} x={x + 2} y={y + 2 + i}>
            {line}
          </Put>
        ))}
        <Btn
          x={x + 2}
          y={by}
          label="CANCEL"
          lit
          auto={9}
          onClick={() => act('char_confirm', { ok: 0 })}
        />
        <Btn
          x={x + 43}
          y={by}
          label="CHANGE"
          right
          onClick={() => {
            // Answered, not backed out of: the box goes without the back sound.
            quietDialogClose();
            act('char_confirm', { ok: 1 });
          }}
        />
      </Dialog>
    </>
  );
}

/** The box of every CHARACTER screen, with its caption, and SAVED on the border after a save. */
export function CharBox(props: { caption: string }) {
  const { rows } = useGrid();
  const { data } = useBackend<LobbyData>();
  const [saved, setSaved] = useState(false);
  useChanged(data.char_saved ?? 0, () => setSaved(true));
  useEffect(() => {
    if (!saved) {
      return;
    }
    const t = window.setTimeout(() => setSaved(false), 2000);
    return () => window.clearTimeout(t);
  }, [saved, data.char_saved]);
  return (
    <>
      <Box x={0} y={2.5} w={63} h={rows - 3.5} caption={props.caption} />
      {!!saved && (
        <Put x={53} y={2} cls="dim" bg>
          {' SAVED '}
        </Put>
      )}
    </>
  );
}

/** Calls fn once `ms` after `when` turns true, unless it turns false first. */
export function useAfter(when: boolean, ms: number, fn: () => void) {
  const ref = useRef(fn);
  ref.current = fn;
  useEffect(() => {
    if (!when) {
      return;
    }
    const t = window.setTimeout(() => ref.current(), ms);
    return () => window.clearTimeout(t);
  }, [when]);
}

/**
 * PageUp and PageDown (design 03 section 6) for a paged list: steps `page` (0-based) within
 * `pages`, or does nothing on one page.
 */
export function useListPager(
  page: number,
  pages: number,
  set: (p: number) => void,
) {
  usePager(pages > 1 ? (step) => set(clamp(page + step, 0, pages - 1)) : null);
}

/**
 * The mouse wheel for a paged list (as CREWS and SETTINGS have it): one page a notch, at most
 * one turn every 150 ms. Call it before any early return; `wheel(turn)` gives the handler for
 * the list's wrapper, turn(1) the next page. A null turn (one page) does nothing.
 */
export function useWheel() {
  const last = useRef(0);
  return (turn: ((by: 1 | -1) => void) | null) => (e: ReactWheelEvent) => {
    const now = Date.now();
    if (!turn || !e.deltaY || now - last.current < 150) {
      return;
    }
    last.current = now;
    turn(e.deltaY > 0 ? 1 : -1);
  };
}

/**
 * The same for a screen that returns early before its pages are known (hooks can't follow an
 * early return): set `.current` while drawing, null when nothing pages.
 */
export function useLatePager() {
  const ref = useRef<((step: number) => void) | null>(null);
  usePager((step) => ref.current?.(step));
  return ref;
}

/** The facing after a turn, for the router's dir state. */
export const nextDir = turned;
