/**
 * TRAITS (CHARACTER-PLAN 2.7): GOOD/BAD/OTHER quirk list with values, the hovered or selected
 * quirk's first sentence, the TAKEN box with POINTS and the positive count, char_quirk.
 * Options of a taken quirk (customization_options) show under its description as ordinary
 * char_set rows. Owner: C4.
 *
 * Box: x and w are the editor frame's outer columns, y the row under its top line,
 * y + h - 1 its bottom line. Points and caps are worked out here for display only, with
 * tg's own rules (QuirksPage.tsx); the server decides.
 */
import { type ReactNode, useState } from 'react';
import { useBackend } from 'tgui/backend';
import type { Quirk } from 'tgui/interfaces/PreferencesMenu/types';

import { ColorEntry } from './ColorEntry';
import {
  Cycler,
  Frame,
  Hit,
  lpad,
  Put,
  pad,
  RPut,
  Rule,
  useGrid,
  wrap,
} from './term';
import type { CellBox, LobbyData } from './types';
import { usePrefsCatalog } from './usePrefsCatalog';

type Filter = 'good' | 'bad' | 'other';
const FILTERS: [Filter, string][] = [
  ['good', 'GOOD'],
  ['bad', 'BAD'],
  ['other', 'OTHER'],
];

const HEX = /^#?[0-9a-f]{6}$/i;

/** The first sentence of a description. */
export function firstSentence(text: string): string {
  const flat = (text || '').replace(/\s+/g, ' ').trim();
  const m = flat.match(/^(.+?[.!?])(\s|$)/);
  return m ? m[1] : flat;
}

/** A savefile key as a row label: "prosthetic_organ" -> "PROSTHETIC ORGAN". */
function keyLabel(key: string): string {
  return key.replace(/_/g, ' ').toUpperCase();
}

/** Every "#rrggbb" already on the file, for the colour entry's recent row. */
export function fileColors(
  prefs: Record<string, any>,
  extra: string[] = [],
): string[] {
  const out: string[] = [];
  const add = (v: unknown) => {
    if (typeof v !== 'string' || !HEX.test(v)) {
      return;
    }
    const hex = (v[0] === '#' ? v : `#${v}`).toLowerCase();
    if (!out.includes(hex)) {
      out.push(hex);
    }
  };
  extra.forEach(add);
  Object.values(prefs || {}).forEach(add);
  return out.slice(0, 8);
}

export function TraitsEditor(props: CellBox) {
  const { x, y, w, h } = props;
  const { act, data } = useBackend<LobbyData>();
  const { narrow } = useGrid();
  const catalog = usePrefsCatalog();
  const char = data.char;
  const [filter, setFilter] = useState<Filter>('good');
  const [page, setPage] = useState(1);
  const [sel, setSel] = useState<string | null>(null);
  const [hover, setHover] = useState<string | null>(null);

  if (!char || !catalog) {
    return null;
  }
  const {
    quirk_info: info,
    max_positive_quirks: maxGood,
    quirk_blacklist: blacklist,
    points_enabled: pointsOn,
  } = catalog.quirks;

  const taken = (char.quirks || []).filter((k) => !!info[k]);
  let balance = 0;
  let good = 0;
  for (const k of taken) {
    balance += info[k].value;
    if (info[k].value > 0) {
      good++;
    }
  }
  const points = -balance;
  const takenNames = taken.map((k) => info[k].name);
  const blocked = char.quirks_blocked || [];

  const canAdd = (k: string) => {
    const q = info[k];
    if (blocked.includes(k) || blocked.includes(q.name)) {
      return false;
    }
    if (q.value > 0) {
      if (maxGood !== -1 && good >= maxGood) {
        return false;
      }
      if (pointsOn && balance + q.value > 0) {
        return false;
      }
    }
    for (const group of blacklist || []) {
      if (!group.includes(q.name)) {
        continue;
      }
      if (group.some((n) => n !== q.name && takenNames.includes(n))) {
        return false;
      }
    }
    return true;
  };
  const canRemove = (k: string) => !(pointsOn && balance - info[k].value > 0);

  const toggle = (k: string) => {
    const on = !taken.includes(k);
    if (on ? !canAdd(k) : !canRemove(k)) {
      return;
    }
    act('char_quirk', { quirk: k, on: on ? 1 : 0 });
  };

  const split = !narrow && w >= 80;
  const takenW = split ? Math.floor(w * 0.42) : w;
  const ax = x;
  const aw = split ? w - takenW : w;

  // ---- TAKEN ----
  const tx = split ? x + aw : x;
  const TW = split ? takenW - 2 : w;
  const takenRows: ReactNode[] = [];
  let ty = y + (split ? 2 : 1);
  takenRows.push(
    <TakenHead
      key="head"
      x={tx}
      y={ty}
      w={TW}
      points={pointsOn ? points : null}
      good={good}
      maxGood={maxGood}
    />,
  );
  ty += 2;
  const takenMax = split
    ? y + h - 4 - ty
    : Math.max(2, Math.min(taken.length, Math.floor((h - 12) / 2)));
  const shownTaken = taken.slice(0, Math.max(0, takenMax));
  for (const k of shownTaken) {
    const q = info[k];
    const can = canRemove(k);
    takenRows.push(
      <TakenRow
        key={k}
        x={tx}
        y={ty}
        w={TW}
        quirk={q}
        sel={k === sel}
        canRemove={can}
        onSelect={() => setSel(k)}
        onRemove={() => toggle(k)}
      />,
    );
    ty++;
  }
  if (taken.length > shownTaken.length) {
    takenRows.push(
      <Put key="more" x={tx + 3} y={ty} cls="faint">
        {`+${taken.length - shownTaken.length}`}
      </Put>,
    );
    ty++;
  }

  // ---- list ----
  let yy = split ? y + 1 : ty + 1;
  const ruleY = yy - 0.5;
  if (!split) {
    yy += 1;
  }
  const filterY = yy;
  yy += 2;

  // The quirk whose words show at the bottom: the hovered row, else the selected one.
  const shown = hover && info[hover] ? hover : sel && info[sel] ? sel : null;
  const options =
    sel && taken.includes(sel) && shown === sel
      ? (info[sel].customization_options || []).filter(
          (key) => key in (char.prefs || {}),
        )
      : [];
  const descLines = shown
    ? wrap(firstSentence(info[shown].description), aw - 6).slice(
        0,
        options.length ? 1 : 2,
      )
    : [];
  const descH = 3 + options.length;

  const list = Object.keys(info).filter((k) => {
    const v = info[k].value;
    return filter === 'good' ? v > 0 : filter === 'bad' ? v < 0 : v === 0;
  });
  list.sort((a, b) => {
    const va = Math.abs(info[a].value);
    const vb = Math.abs(info[b].value);
    if (va !== vb) {
      return vb - va;
    }
    return info[a].name < info[b].name ? -1 : 1;
  });
  const room = Math.max(3, Math.floor(y + h - 2 - descH - yy));
  const pages = Math.max(1, Math.ceil(list.length / room));
  const pg = Math.min(pages, page);
  const rows = list.slice((pg - 1) * room, pg * room);
  const py = y + h - 2 - descH;
  const descY = y + h - 1 - descH;
  const recent = fileColors(char.prefs);

  return (
    <>
      {!!split && <Frame x={tx} y={y} w={TW} h={h - 2} title="TAKEN" dim />}
      {takenRows}
      {!split && <Rule x={x + 1} y={ruleY} w={w - 2} />}
      <FilterKeys
        x={ax + 3}
        y={filterY}
        filter={filter}
        onFilter={(f) => {
          setFilter(f);
          setPage(1);
          setHover(null);
        }}
      />
      {rows.map((k, i) => {
        const isTaken = taken.includes(k);
        return (
          <QuirkRow
            key={k}
            x={ax}
            y={yy + i}
            w={aw}
            quirk={info[k]}
            taken={isTaken}
            cant={!isTaken && !canAdd(k)}
            locked={isTaken && !canRemove(k)}
            sel={k === sel}
            onClick={() => {
              setSel(k);
              toggle(k);
            }}
            onHover={(over) => setHover(over ? k : null)}
          />
        );
      })}
      {pages > 1 && (
        <Pager
          x={ax + aw - 15}
          y={py}
          page={pg}
          pages={pages}
          onPage={(p) => {
            setPage(p);
            setHover(null);
          }}
        />
      )}
      {descLines.map((line, i) => (
        <Put key={`d${i}`} x={ax + 3} y={descY + i} cls="dim">
          {line}
        </Put>
      ))}
      {options.map((key, i) => (
        <QuirkOption
          key={key}
          x={ax + 3}
          y={descY + descLines.length + i}
          w={aw - 6}
          prefKey={key}
          value={char.prefs[key]}
          serverData={catalog[key] as any}
          recent={recent}
          onSet={(value) => act('char_set', { key, value })}
        />
      ))}
    </>
  );
}

function TakenHead(props: {
  x: number;
  y: number;
  w: number;
  points: number | null;
  good: number;
  maxGood: number;
}) {
  const { x, y, w, points, good, maxGood } = props;
  const capped = maxGood !== -1 && good >= maxGood;
  return (
    <>
      {points !== null && (
        <>
          <Put x={x + 3} y={y} cls="dim">
            {'POINTS'}
          </Put>
          <Put
            x={x + 10}
            y={y}
            cls={points < 0 ? 'red' : points > 0 ? 'amb' : ''}
          >
            {lpad(points, 3)}
          </Put>
        </>
      )}
      {maxGood !== 0 && (
        <RPut x={x + w - 3} y={y} cls={capped ? 'amb' : 'dim'}>
          {maxGood === -1 ? `GOOD ${good}` : `GOOD ${good}/${maxGood}`}
        </RPut>
      )}
    </>
  );
}

function TakenRow(props: {
  x: number;
  y: number;
  w: number;
  quirk: Quirk;
  sel: boolean;
  canRemove: boolean;
  onSelect: () => void;
  onRemove: () => void;
}) {
  const { x, y, w, quirk, sel, canRemove, onSelect, onRemove } = props;
  const v = quirk.value;
  return (
    <>
      <Put
        x={x + 3}
        y={y}
        cls={sel ? 'inv' : ''}
        hoverCls="inv"
        onClick={onSelect}
      >
        {pad(quirk.name, w - 13)}
      </Put>
      <Put x={x + w - 9} y={y} cls={v > 0 ? 'amb' : v < 0 ? 'dim' : 'faint'}>
        {lpad(v, 3)}
      </Put>
      {canRemove ? (
        <Put x={x + w - 5} y={y} cls="dim" hoverCls="inv" onClick={onRemove}>
          {'[X]'}
        </Put>
      ) : (
        <Put x={x + w - 5} y={y} cls="faint">
          {'[X]'}
        </Put>
      )}
    </>
  );
}

function FilterKeys(props: {
  x: number;
  y: number;
  filter: Filter;
  onFilter: (f: Filter) => void;
}) {
  const { x, y, filter, onFilter } = props;
  let fx = x;
  return (
    <>
      {FILTERS.map(([key, label]) => {
        const at = fx;
        fx += label.length + 4;
        return (
          <Put
            key={key}
            x={at}
            y={y}
            cls={key === filter ? 'inv' : 'dim'}
            hoverCls="inv"
            onClick={() => onFilter(key)}
          >
            {` ${label} `}
          </Put>
        );
      })}
    </>
  );
}

function QuirkRow(props: {
  x: number;
  y: number;
  w: number;
  quirk: Quirk;
  taken: boolean;
  /** Can't be taken now: dim, and a click only selects it. */
  cant: boolean;
  /** Taken but can't be dropped now. */
  locked: boolean;
  sel: boolean;
  onClick: () => void;
  onHover: (over: boolean) => void;
}) {
  const { x, y, w, quirk, taken, cant, sel, onClick, onHover } = props;
  const v = quirk.value;
  const nameCls = sel ? 'inv' : taken ? 'amb' : cant ? 'faint' : '';
  const valCls = sel ? 'inv' : cant ? 'faint' : v > 0 ? 'amb' : 'dim';
  return (
    <>
      {!!sel && (
        <Put x={x + 1} y={y} cls="inv">
          {' '.repeat(Math.max(0, w - 2))}
        </Put>
      )}
      <Put x={x + 1} y={y} cls={sel ? 'inv' : 'amb'}>
        {taken ? '*' : ' '}
      </Put>
      <Put x={x + 3} y={y} cls={nameCls}>
        {pad(quirk.name, w - 10)}
      </Put>
      <RPut x={x + w - 3} y={y} cls={valCls}>
        {String(v)}
      </RPut>
      <Hit
        x={x + 1}
        y={y}
        w={w - 2}
        h={1}
        onClick={onClick}
        onHover={onHover}
      />
    </>
  );
}

function Pager(props: {
  x: number;
  y: number;
  page: number;
  pages: number;
  onPage: (page: number) => void;
}) {
  const { x, y, page, pages, onPage } = props;
  return (
    <>
      {page > 1 ? (
        <Put x={x} y={y} cls="inv" onClick={() => onPage(page - 1)}>
          {' < '}
        </Put>
      ) : (
        <Put x={x} y={y} cls="faint">
          {' < '}
        </Put>
      )}
      <Put x={x + 4} y={y} cls="dim">
        {`${page}/${pages}`}
      </Put>
      {page < pages ? (
        <Put x={x + 8} y={y} cls="inv" onClick={() => onPage(page + 1)}>
          {' > '}
        </Put>
      ) : (
        <Put x={x + 8} y={y} cls="faint">
          {' > '}
        </Put>
      )}
    </>
  );
}

type OptionServerData = {
  choices?: string[];
  display_names?: Record<string, string>;
  minimum?: number;
  maximum?: number;
  step?: number;
} | null;

/** One quirk option row: a choice cycler, a number stepper, a yes/no, or a colour. */
function QuirkOption(props: {
  x: number;
  y: number;
  w: number;
  prefKey: string;
  value: any;
  serverData: OptionServerData;
  recent: string[];
  onSet: (value: unknown) => void;
}) {
  const { x, y, w, prefKey, value, serverData, recent, onSet } = props;
  const label = keyLabel(prefKey);
  const lw = 18;
  const cw = Math.max(8, Math.min(24, w - lw - 4));
  const labelRow = (
    <Put x={x} y={y} cls="dim">
      {pad(label, lw - 1)}
    </Put>
  );
  if (serverData?.choices?.length) {
    const choices = serverData.choices;
    const i = Math.max(0, choices.indexOf(value));
    const name = (v: string) => serverData.display_names?.[v] || v;
    const step = (d: number) =>
      onSet(choices[(i + d + choices.length) % choices.length]);
    return (
      <>
        {labelRow}
        <Cycler
          x={x + lw}
          y={y}
          w={cw}
          value={name(choices[i])}
          onPrev={() => step(-1)}
          onNext={() => step(1)}
        />
      </>
    );
  }
  if (typeof serverData?.minimum === 'number') {
    const lo = serverData.minimum;
    const hi = serverData.maximum ?? lo;
    const st = serverData.step || 1;
    const n = Number(value) || 0;
    return (
      <>
        {labelRow}
        <Cycler
          x={x + lw}
          y={y}
          w={6}
          value={String(n)}
          onPrev={() => onSet(Math.max(lo, n - st))}
          onNext={() => onSet(Math.min(hi, n + st))}
        />
      </>
    );
  }
  if (typeof value === 'string' && HEX.test(value)) {
    const hex = value[0] === '#' ? value : `#${value}`;
    return (
      <ColorEntry
        x={x}
        y={y}
        w={w}
        label={pad(label, lw - 1)}
        value={hex}
        recent={recent}
        onSet={(c) => onSet(c)}
      />
    );
  }
  if (typeof value === 'number') {
    const flip = () => onSet(value ? 0 : 1);
    return (
      <>
        {labelRow}
        <Cycler
          x={x + lw}
          y={y}
          w={4}
          value={value ? 'YES' : 'NO'}
          onPrev={flip}
          onNext={flip}
        />
      </>
    );
  }
  return null;
}
