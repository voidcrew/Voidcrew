/**
 * SETTINGS: the terminal's own screen for the game preferences (OPTIONS) and the keybindings
 * (KEYS). Opened from the menu like CHARACTER, in the same box; the tab row stays.
 *
 * Columns of the main region: the list column is 1 to 15 (LIST_X, LIST_W) with the group switch
 * OPTIONS | KEYS on top and the categories of the open group under it; column 16 is a gap; the
 * work column is 17 to 61 (WORK_X, WORK_W): the open category's rows, the page mark and, at the
 * foot, the description strip (two dim lines about the focused or hovered row).
 *
 * A row: the name in 19 to 42 (NAME_X, NAME_W), wrapped to two lines in a taller row when
 * longer (rowHeight(); never more than two, the second then ends in the cut mark); the value in
 * 44 to 61 (VALUE_X, VALUE_W).
 *
 * ## The contract for KEYS (SettingsKeys.tsx, lobby_settings_keys.dm)
 *
 * SettingsKeys is drawn instead of the OPTIONS pane while the group is KEYS. It owns its data
 * (its own settings_keys_* actions; settings_act() routes them to settings_keys_act()) and
 * draws the same two columns with <SettingsColumns>:
 *   cats      its categories for the left list ({id, label}; labels at most 13 characters)
 *   cat       the open one (keep it in your own state); onCat(id) opens another
 *   rows      SettingsRowSpec[]: key, name (upper case), desc, value(ty, focused) drawing in the
 *             value zone, onPress (Enter or a click), onStep (Left/Right and the mouse arrows),
 *             muted; typing rows can render a <Field> from value() (see OPTIONS' number rows)
 *   focusKey  the row that takes the focus when the rows mount (back from a level-2 screen);
 *             a row's own `claim` does the same when it turns on
 * SettingsColumns does the list, its paging, the rows' paging (PageUp/PageDown and the page
 * mark), the description strip and the page wipes, so both groups look and move the same.
 * useSettings() gives sub(node, crumb, from) for a level-2 screen in the work column (the frame
 * then draws `node` there and the crumbs SETTINGS / <category> / <crumb>, and Escape or [ BACK ]
 * closes it; `node` must read live data itself), closeSub(), subOpen, from (the row that opened
 * the last one, to give the focus back), setCrumb(label) (the open category's name for the
 * crumbs) and home (bumped when SETTINGS is pressed while open: go back to your top state).
 */
import {
  createContext,
  type ReactNode,
  useContext,
  useEffect,
  useState,
} from 'react';
import { useBackend } from 'tgui/backend';

import { type Crumb, Crumbs, clamp, useListPager } from './CharFrame';
import { useChanged, useScreen } from './motion';
import { useBack } from './nav';
import { SettingsKeys } from './SettingsKeys';
import { SettingsOptions } from './SettingsOptions';
import {
  BODY_Y,
  Box,
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
import type { LobbyData } from './types';

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

/** The rows' top; the list's first slab sits under the group switch. */
const ROWS_Y = BODY_Y;
const LIST_Y = BODY_Y + 2;
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
  /** Left and Right on the focused row. */
  onStep?: (by: number) => void;
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
export const rowHeight = (name: string) => (name.length > NAME_W ? 2.25 : 1.25);

/** The name's lines in its zone (at most two; a longer one ends in the cut mark). */
export const nameLines = (name: string) => wrapMax(name, NAME_W, 2);

/** tg's own order: by name, as a plain string compare (GamePreferencesPage binaryInsert). */
export const byName = (a: string, b: string) => (a < b ? -1 : a > b ? 1 : 0);

/** The box, with SAVED on the border for two seconds after a save. */
function SettingsBox() {
  const { rows } = useGrid();
  const { data } = useBackend<LobbyData>();
  const [saved, setSaved] = useState(false);
  useChanged(data.settings_saved ?? 0, () => setSaved(true));
  useEffect(() => {
    if (!saved) {
      return;
    }
    const t = window.setTimeout(() => setSaved(false), 2000);
    return () => window.clearTimeout(t);
  }, [saved, data.settings_saved]);
  return (
    <>
      <Box x={0} y={2.5} w={63} h={rows - 3.5} caption="SETTINGS" />
      {!!saved && (
        <Put x={53} y={2} cls="dim" bg>
          {' SAVED '}
        </Put>
      )}
    </>
  );
}

/** OPTIONS | KEYS, side by side at the top of the list column. */
function GroupSwitch(props: {
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

/** The categories under the group switch, paged when they don't fit. */
function CategoryList(props: {
  cats: SettingsCat[];
  cat: string | null;
  onCat: (id: string) => void;
  claim?: number;
}) {
  const { cats, cat, onCat, claim } = props;
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
  return (
    <>
      {shown.map((c, i) => {
        const y = LIST_Y + i * SLAB_PITCH;
        const on = c.id === cat;
        return (
          <Slab
            key={c.id}
            x={LIST_X}
            y={y}
            w={LIST_W}
            h={SLAB_H}
            variant="block"
            on={on}
            auto={on ? claim : undefined}
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
    </>
  );
}

/** One row of the work column: the slab, the name, the value. */
function SettingRow(props: {
  spec: SettingsRowSpec;
  y: number;
  h: number;
  alt: boolean;
  auto?: number;
  onSeen: (key: string) => void;
}) {
  const { spec, y, h, alt, auto, onSeen } = props;
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
          if (on) {
            onSeen(spec.key);
          }
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
}) {
  const { cats, cat, onCat, rows, focusKey, empty } = props;
  const { subOpen, closeSub } = useSettings();
  const { rows: M } = useGrid();
  const [page, setPage] = useState(0);
  const [seen, setSeen] = useState<string | null>(null);

  // A new category starts on its first page with no description.
  useEffect(() => {
    setPage(0);
    setSeen(null);
  }, [cat]);

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

  const onCatPress = (id: string) => {
    if (subOpen) {
      closeSub();
    }
    if (id !== cat) {
      onCat(id);
    }
  };
  const list = (
    <CategoryList
      cats={cats}
      cat={cat}
      onCat={onCatPress}
      claim={focusKey ? undefined : 5}
    />
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
      />
    );
    y += h;
    return row;
  });

  const desc = safe(rows.find((r) => r.key === seen)?.desc || '').toUpperCase();
  const descLines = desc ? wrapMax(desc, DESC_W, 2) : [];
  const rowsBottom = paged ? M - 4.75 : M - 3.5;

  return (
    <>
      {list}
      {drawn}
      {!rows.length && !!empty && (
        <NameLine
          x={NAME_X}
          y={ROWS_Y + 0.625}
          w={DESC_W}
          text={empty}
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

type Sub = { node: ReactNode; crumb: string; from: string | null };

/**
 * The screen. home: bumped when SETTINGS is pressed while open (back to the top state);
 * onLeave: Escape at the top state (back to the tab that was open before).
 */
export function Settings(props: { home: number; onLeave?: () => void }) {
  const { home, onLeave } = props;
  const { act } = useBackend<LobbyData>();
  const { rows: M } = useGrid();
  const [group, setGroup] = useState<SettingsGroup>('options');
  const [sub, setSub] = useState<Sub | null>(null);
  const [from, setFrom] = useState<string | null>(null);
  const [crumb, setCrumb] = useState('');

  useEffect(() => {
    act('settings_open');
    return () => act('settings_close');
  }, []);

  const closeSub = () => {
    setFrom(sub?.from ?? null);
    setSub(null);
  };
  useEffect(() => {
    setSub(null);
    setFrom(null);
  }, [home]);

  useBack(sub ? closeSub : onLeave || null);
  useScreen(`settings/${group}`, 0);

  const nav: SettingsNav = {
    sub: (node, label, at) => {
      setFrom(null);
      setSub({ node, crumb: label, from: at ?? null });
    },
    closeSub,
    subOpen: !!sub,
    from,
    setCrumb,
    home,
  };
  const crumbs: Crumb[] = [
    ['SETTINGS', closeSub],
    [crumb, closeSub],
  ];
  if (sub) {
    crumbs.push([sub.crumb, null]);
  }

  return (
    <SettingsContext.Provider value={nav}>
      <SettingsBox />
      {!!sub && <Crumbs crumbs={crumbs} onBack={closeSub} />}
      <GroupSwitch
        group={group}
        onGroup={(g) => {
          setSub(null);
          setFrom(null);
          setGroup(g);
        }}
      />
      {group === 'options' ? <SettingsOptions /> : <SettingsKeys />}
      {!!sub && sub.node}
      {/* A picker or a colour panel wipes the work column only. */}
      <WipeAt
        kind="screen"
        x={WORK_X}
        y={BODY_Y}
        w={WORK_W}
        h={M - 1.25 - BODY_Y}
        k={sub ? sub.crumb : ''}
        n={sub ? 1 : 0}
      />
    </SettingsContext.Provider>
  );
}
