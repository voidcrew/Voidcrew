/**
 * The SETTINGS frame pieces shared by both groups: the layout constants, the context, the group
 * switch, the category list and SettingsColumns (rows, paging, description strip). The screen
 * itself and the contract for the KEYS group are in Settings.tsx.
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

import { clamp, StepKeys, useListPager } from './CharFrame';
import { FocusGroup, useBack } from './nav';
import {
  BODY_Y,
  Field,
  Key,
  NameLine,
  Pager,
  Put,
  Slab,
  safe,
  useGrid,
  WipeAt,
  wrapMax,
} from './term';

export const LIST_X = 1;
export const LIST_W = 15;
export const WORK_X = 17;
export const WORK_W = 45;
export const NAME_X = 19;
export const NAME_W = 24;
export const VALUE_X = 44;
export const VALUE_W = 18;
/** The description strip: two lines this wide from NAME_X. */
export const DESC_W = 43;

/** The rows' top; the search field sits under the group switch, the list's first slab under it. */
const ROWS_Y = BODY_Y;
const FIND_Y = BODY_Y + 1.75;
const LIST_Y = BODY_Y + 3.5;
const SLAB_H = 1.5;
const SLAB_PITCH = 1.75;

export type SettingsGroup = 'options' | 'keys';

export type SettingsCat = { id: string; label: string };

export type SettingsRowSpec = {
  key: string;
  /** Upper case, safe()d. */
  name: string;
  desc?: string;
  /** Draws the value in the value zone; ty is the row's first text line. */
  value?: (ty: number, focused: boolean) => ReactNode;
  /** Enter or a click. Without it (and without onStep) the row is not a focus stop. */
  onPress?: () => void;
  /** Left and Right on the focused row; the row then draws its `<` `>` keys (StepKeys). */
  onStep?: (by: number) => void;
  /** A number at its low or high end: that key is drawn dead. */
  ends?: [boolean, boolean];
  /** Dead colours (shown, not changeable), still focusable for its description. */
  muted?: boolean;
  /** The row takes the focus when this turns on (back from typing in it). */
  claim?: boolean;
};

export type SettingsNav = {
  sub: (node: ReactNode, crumb: string, from?: string) => void;
  closeSub: () => void;
  subOpen: boolean;
  from: string | null;
  /** The open category's label, for the crumbs. */
  setCrumb: (label: string) => void;
  /** Bumped when SETTINGS is pressed while open. */
  home: number;
};

export const SettingsContext = createContext<SettingsNav>({
  sub: () => undefined,
  closeSub: () => undefined,
  subOpen: false,
  from: null,
  setCrumb: () => undefined,
  home: 0,
});

export const useSettings = () => useContext(SettingsContext);

/** A row's height: one line, or two when the name wraps. */
const rowHeight = (name: string) => (name.length > NAME_W ? 2.25 : 1.25);

/** The name's lines in its zone (at most two; a longer one ends in the cut mark). */
const nameLines = (name: string) => wrapMax(name, NAME_W, 2);

/** tg's own order: by name, as a plain string compare (GamePreferencesPage binaryInsert). */
export const byName = (a: string, b: string) => (a < b ? -1 : a > b ? 1 : 0);

/** OPTIONS | KEYS, side by side at the top of the list column. */
export function GroupSwitch(props: {
  group: SettingsGroup;
  onGroup: (g: SettingsGroup) => void;
}) {
  const { group, onGroup } = props;
  return (
    <>
      <Key
        x={LIST_X}
        y={BODY_Y}
        w={8}
        kind="cap"
        label="OPTIONS"
        state={group === 'options' ? 'on' : 'idle'}
        onClick={() => onGroup('options')}
      />
      <Key
        x={LIST_X + 9}
        y={BODY_Y}
        w={6}
        kind="cap"
        label="KEYS"
        state={group === 'keys' ? 'on' : 'idle'}
        onClick={() => onGroup('keys')}
      />
    </>
  );
}

/** The mouse wheel turns a paged list's pages, one page a notch (as CREWS does). */
function useWheelPages(page: number, pages: number, set: (p: number) => void) {
  const last = useRef(0);
  return (e: ReactWheelEvent) => {
    if (pages <= 1 || !e.deltaY) {
      return;
    }
    const now = Date.now();
    if (now - last.current < 150) {
      return;
    }
    last.current = now;
    set(clamp(page + (e.deltaY > 0 ? 1 : -1), 0, pages - 1));
  };
}

/** The categories under the group switch, paged when they don't fit. */
function CategoryList(props: {
  cats: SettingsCat[];
  cat: string | null;
  onCat: (id: string) => void;
  claim?: number;
  /** Bumped to give the open category the focus again (Escape on a row). */
  bump?: number;
}) {
  const { cats, cat, onCat, claim, bump = 0 } = props;
  const { rows: M } = useGrid();
  const bottom = M - 1.25;
  const fitAll = Math.floor((bottom - LIST_Y + 0.25) / SLAB_PITCH);
  const paged = cats.length > fitAll;
  const per = paged
    ? Math.max(1, Math.floor((bottom - 1.25 - LIST_Y + 0.25) / SLAB_PITCH))
    : Math.max(1, cats.length);
  const pages = Math.max(1, Math.ceil(cats.length / per));
  const at = cats.findIndex((c) => c.id === cat);
  const [page, setPage] = useState(() => Math.max(0, Math.floor(at / per)));
  useEffect(() => {
    if (at >= 0) {
      setPage(Math.floor(at / per));
    }
  }, [cat, per]);
  const pg = clamp(page, 0, pages - 1);
  const shown = cats.slice(pg * per, pg * per + per);
  const onWheel = useWheelPages(pg, pages, setPage);
  return (
    <div onWheel={onWheel}>
      {shown.map((c, i) => {
        const y = LIST_Y + i * SLAB_PITCH;
        const on = c.id === cat;
        return (
          <Slab
            key={on ? `${c.id}:${bump}` : c.id}
            x={LIST_X}
            y={y}
            w={LIST_W}
            h={SLAB_H}
            variant="block"
            on={on}
            entry={on}
            auto={on ? (bump ? 5 : claim) : undefined}
            onClick={() => onCat(c.id)}
          >
            <Put x={LIST_X + 1} y={y + 0.25} cls={on ? 'wht' : ''}>
              {safe(c.label)
                .toUpperCase()
                .slice(0, LIST_W - 2)}
            </Put>
          </Slab>
        );
      })}
      <Pager
        x={LIST_X + LIST_W}
        y={M - 2.25}
        page={pg + 1}
        pages={pages}
        onPage={(p) => setPage(p - 1)}
        right
      />
      {pages > 1 && (
        <WipeAt
          x={LIST_X}
          y={LIST_Y}
          w={LIST_W}
          h={bottom - 1.25 - LIST_Y}
          k={pg}
        />
      )}
    </div>
  );
}

/** One row of the work column: the slab, the name, the value. */
function SettingRow(props: {
  spec: SettingsRowSpec;
  y: number;
  h: number;
  alt: boolean;
  auto?: number;
  /** The mouse is over the row. */
  onSeen: (key: string) => void;
  /** Told when the row gains or loses the focus. */
  onFocused: (key: string, on: boolean) => void;
}) {
  const { spec, y, h, alt, auto, onSeen, onFocused } = props;
  const [focused, setFocused] = useState(false);
  const lines = nameLines(spec.name);
  const ty = y + 0.125;
  const live = !!spec.onPress || !!spec.onStep;
  const step = spec.onStep;
  return (
    // Hovering anything in the row (its value's own keys too) shows its description.
    <div onMouseOver={() => onSeen(spec.key)}>
      <Slab
        x={WORK_X}
        y={y}
        w={WORK_W}
        h={h}
        variant="row"
        alt={alt}
        muted={spec.muted}
        auto={auto}
        onFocus={(on) => {
          setFocused(on);
          onFocused(spec.key, on);
        }}
        onClick={live ? () => spec.onPress?.() : undefined}
        edge={
          step
            ? {
                left: () => {
                  step(-1);
                  return true;
                },
                right: () => {
                  step(1);
                  return true;
                },
              }
            : undefined
        }
      >
        {lines.map((line, i) => (
          <Put
            key={i}
            x={NAME_X}
            y={ty + i}
            cls={spec.muted ? 'faint' : focused ? 'wht' : 'dim'}
          >
            {line}
          </Put>
        ))}
        {spec.value?.(ty, focused)}
        {!!step && (
          <StepKeys
            x={WORK_X + WORK_W - 6}
            y={y}
            h={h}
            onStep={step}
            ends={spec.ends}
          />
        )}
      </Slab>
    </div>
  );
}

/** Splits rows into pages that fit `room` rows (each row's height from its name). */
function pageRows(heights: number[], room: number): number[][] {
  const pages: number[][] = [];
  let cur: number[] = [];
  let used = 0;
  heights.forEach((h, i) => {
    if (cur.length && used + h > room + 1e-6) {
      pages.push(cur);
      cur = [];
      used = 0;
    }
    cur.push(i);
    used += h;
  });
  if (cur.length || !pages.length) {
    pages.push(cur);
  }
  return pages;
}

/**
 * The list column (under the group switch) and the work column (rows, page mark, description
 * strip) of either group. While a level-2 screen is open only the list is drawn.
 */
export function SettingsColumns(props: {
  cats: SettingsCat[];
  cat: string | null;
  onCat: (id: string) => void;
  rows: SettingsRowSpec[];
  /** The row that takes the focus when the rows mount; else the open category's slab does. */
  focusKey?: string | null;
  /** Drawn in the work column when there are no rows (dim, one line). */
  empty?: string;
  /**
   * The search text and its setter. While it is not empty the caller passes the matching rows
   * of every category, and no category is marked.
   */
  find?: string;
  onFind?: (text: string) => void;
  /** The row whose value is being typed: the strip keeps its description while the keys are in the field. */
  typing?: string | null;
}) {
  const { cats, cat, onCat, rows, focusKey, empty, onFind, typing } = props;
  const find = props.find || '';
  const { subOpen, closeSub } = useSettings();
  const { rows: M } = useGrid();
  const [page, setPage] = useState(0);
  /** The strip describes the row under the mouse, else the focused row, else nothing. */
  const [seen, setSeen] = useState<string | null>(null);
  /** The focused row; Escape then goes up to the list before it leaves the screen. */
  const [focusRow, setFocusRow] = useState<string | null>(null);
  /** The search field's box: a row taking the focus (the mouse, say) takes the keys out of it. */
  const findBox = useRef<HTMLDivElement>(null);
  const [bump, setBump] = useState(0);

  // A new category or search starts on its first page with no description.
  useEffect(() => {
    setPage(0);
    setSeen(null);
  }, [cat, find]);
  useEffect(() => {
    if (subOpen) {
      setFocusRow(null);
    }
  }, [subOpen]);

  const heights = rows.map((r) => rowHeight(r.name));
  const total = heights.reduce((a, b) => a + b, 0);
  // Unpaged the rows may run down to the description strip; paged they leave a row for the mark.
  const openRoom = M - 3.5 - ROWS_Y;
  const paged = total > openRoom + 1e-6;
  const pages = pageRows(heights, paged ? M - 4.75 - ROWS_Y : openRoom);
  // Back from a picker: the page with the row that opened it.
  useEffect(() => {
    if (!focusKey) {
      return;
    }
    const i = rows.findIndex((r) => r.key === focusKey);
    const p = pages.findIndex((list) => list.includes(i));
    if (p >= 0) {
      setPage(p);
    }
  }, [focusKey]);
  const pg = clamp(page, 0, pages.length - 1);
  useListPager(pg, subOpen ? 1 : pages.length, setPage);
  const onWheel = useWheelPages(pg, pages.length, setPage);
  // A row that went away (another page, category or search) never says it lost the focus.
  const shownRow = (key: string | null) =>
    key !== null && pages[pg].some((i) => rows[i].key === key);
  const inRows = shownRow(focusRow);
  useBack(
    subOpen
      ? null
      : find
        ? () => onFind?.('')
        : inRows
          ? () => setBump((n) => n + 1)
          : null,
  );

  const onCatPress = (id: string) => {
    if (subOpen) {
      closeSub();
    }
    if (find) {
      onFind?.('');
    }
    if (id !== cat) {
      onCat(id);
    }
  };
  // The search field and the list are entered as one: sideways from the rows, the open category.
  const list = (
    <FocusGroup>
      {!!onFind && (
        <div ref={findBox}>
          <Field
            x={LIST_X}
            y={FIND_Y}
            w={LIST_W}
            h={1.25}
            value={find}
            max={24}
            hint="SEARCH"
            onChange={(v) => onFind(v.toUpperCase())}
            onEnter={() =>
              (document.activeElement as HTMLElement | null)?.blur()
            }
          />
        </div>
      )}
      <CategoryList
        cats={cats}
        cat={find ? null : cat}
        onCat={onCatPress}
        claim={focusKey || find ? undefined : 5}
        bump={bump}
      />
    </FocusGroup>
  );
  if (subOpen) {
    // The same tree shape as below, so the list stays mounted and keeps the focus where it was.
    return <>{list}</>;
  }

  let y = ROWS_Y;
  const drawn = pages[pg].map((i, n) => {
    const spec = rows[i];
    const h = heights[i];
    const row = (
      <SettingRow
        key={spec.claim ? `${spec.key}*` : spec.key}
        spec={spec}
        y={y}
        h={h}
        alt={n % 2 === 1}
        auto={spec.claim || spec.key === focusKey ? 5 : undefined}
        onSeen={setSeen}
        onFocused={(key, on) => {
          if (on) {
            const typing = document.activeElement;
            if (typing && findBox.current?.contains(typing)) {
              (typing as HTMLElement).blur();
            }
          }
          setFocusRow((was) => (on ? key : was === key ? null : was));
        }}
      />
    );
    y += h;
    return row;
  });

  const described =
    seen ?? (inRows ? focusRow : shownRow(typing ?? null) ? typing : null);
  const desc = safe(
    rows.find((r) => r.key === described)?.desc || '',
  ).toUpperCase();
  const descLines = desc ? wrapMax(desc, DESC_W, 2) : [];
  const rowsBottom = paged ? M - 4.75 : M - 3.5;

  return (
    <>
      {list}
      <div onWheel={onWheel} onMouseLeave={() => setSeen(null)}>
        <FocusGroup>{drawn}</FocusGroup>
      </div>
      {!rows.length && (!!empty || !!find) && (
        <NameLine
          x={NAME_X}
          y={ROWS_Y + 0.625}
          w={DESC_W}
          text={empty || 'NO MATCH.'}
          cls="dim"
        />
      )}
      <Pager
        x={WORK_X + WORK_W}
        y={M - 4.5}
        page={pg + 1}
        pages={pages.length}
        onPage={(p) => setPage(p - 1)}
        right
      />
      {descLines.map((line, i) => (
        <Put key={i} x={NAME_X} y={M - 3.25 + i} cls="dim">
          {line}
        </Put>
      ))}
      {/* Another category, or another page of rows, turns the page of the rows only. */}
      <WipeAt
        x={WORK_X}
        y={ROWS_Y}
        w={WORK_W}
        h={rowsBottom - ROWS_Y}
        k={`${cat}:${pg}`}
      />
    </>
  );
}
