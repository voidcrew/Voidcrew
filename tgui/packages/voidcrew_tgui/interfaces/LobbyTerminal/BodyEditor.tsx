/**
 * BODY (CHARACTER-PLAN 2.3/2.4): data-driven rows from CharData.prefs in BODY_KEYS order, char_set, the species confirm line, ColorEntry for free colours.
 * Owner: C3. The props are fixed.
 *
 * A row shows only when the server sent its key (its accessibility rules pick the rows);
 * species feature keys are also checked against the species' enabled_features in the
 * catalog. Rows flow down one column, into a second when the box is too short, and onto
 * pages when even that is not enough. Choice lists longer than PICK_OVER open a paged list
 * when their value is clicked.
 */
import { type ReactNode, useEffect, useState } from 'react';
import { useBackend } from 'tgui/backend';

import { ColorEntry, parseHex } from './ColorEntry';
import { useBack } from './nav';
import { Btn, Cycler, Field, Panel, Put, pad, Swatch, wrap } from './term';
import {
  AGE_MAX,
  AGE_MIN,
  BODY_KEYS,
  type CellBox,
  type LobbyData,
  NAME_MAX,
  NATIVE_COLOR_KEYS,
} from './types';
import {
  choicesOf,
  namedHex,
  nameOf,
  stepChoice,
  usePrefsCatalog,
} from './usePrefsCatalog';

const LABELS: Record<string, string> = {
  real_name: 'NAME',
  age: 'AGE',
  species: 'SPECIES',
  body_type: 'BODY',
  gender: 'PRONOUNS',
  background: 'BACKGROUND',
  skin_tone: 'SKIN',
  hairstyle_name: 'HAIR',
  hair_color: 'HAIR',
  hair_gradient: 'GRADIENT',
  hair_gradient_color: 'GRADIENT',
  facial_style_name: 'FACIAL HAIR',
  facial_hair_color: 'FACIAL HAIR',
  feature_mcolor: 'SCALES',
  feature_ethcolor: 'GLOW',
  eye_color: 'EYES',
  voice_pack: 'VOICE',
  bark_speech_pitch: 'PITCH',
  bark_speech_speed: 'SPEED',
  backpack: 'BAG',
  jumpsuit_style: 'UNIFORM',
  underwear: 'UNDERWEAR',
  undershirt: 'UNDERSHIRT',
  socks: 'SOCKS',
  feature_human_ears: 'EARS',
  feature_human_tail: 'TAIL',
  feature_lizard_snout: 'SNOUT',
  feature_lizard_horns: 'HORNS',
  feature_lizard_frills: 'FRILLS',
  feature_lizard_spines: 'SPINES',
  feature_lizard_body_markings: 'MARKINGS',
  feature_lizard_legs: 'LEGS',
  feature_lizard_tail: 'TAIL',
  feature_moth_wings: 'WINGS',
  feature_moth_antennae: 'ANTENNAE',
  feature_moth_markings: 'MARKINGS',
};

/** Species feature rows, in this order after SCALES; unknown ones follow, by key. */
const FEATURE_ORDER = [
  'feature_human_ears',
  'feature_human_tail',
  'feature_lizard_snout',
  'feature_lizard_horns',
  'feature_lizard_frills',
  'feature_lizard_spines',
  'feature_lizard_body_markings',
  'feature_lizard_legs',
  'feature_lizard_tail',
  'feature_moth_wings',
  'feature_moth_antennae',
  'feature_moth_markings',
];

/** Colours drawn on their style's row. */
const PAIRED: Record<string, string> = {
  hairstyle_name: 'hair_color',
  hair_gradient: 'hair_gradient_color',
  facial_style_name: 'facial_hair_color',
  underwear: 'underwear_color',
};

/** Named lists that show a swatch per choice. */
const PALETTES = new Set(['skin_tone', 'feature_ethcolor']);

/** Numeric rows and the amount one click moves them. */
const NUMERIC_STEPS: Record<string, number> = {
  bark_speech_pitch: 0.1,
  bark_speech_speed: 0.5,
};

/** Lists longer than this open the paged list when the value is clicked. */
const PICK_OVER = 12;
/** Label column width. */
const LW = 12;

const labelOf = (key: string) =>
  LABELS[key] ||
  key
    .replace(/^feature_/, '')
    .replace(/_/g, ' ')
    .toUpperCase();

type Row = {
  key: string;
  h: number;
  draw: (L: number, V: number, y: number, end: number) => ReactNode;
};

export function BodyEditor(props: CellBox) {
  const { x, y, w, h } = props;
  const { act, data } = useBackend<LobbyData>();
  const cat = usePrefsCatalog();
  const char = data.char;
  const prefs = char?.prefs || {};
  const [name, setName] = useState(String(prefs.real_name ?? ''));
  const [page, setPage] = useState(0);
  const [picker, setPicker] = useState<string | null>(null);

  useEffect(() => {
    setName(String(prefs.real_name ?? ''));
  }, [prefs.real_name, char?.slot]);

  if (!char) {
    return null;
  }

  const set = (key: string, value: unknown) => act('char_set', { key, value });
  const commitName = () => {
    const next = name.trim();
    if (next && next !== prefs.real_name) {
      set('real_name', next);
    } else {
      setName(String(prefs.real_name ?? ''));
    }
  };

  const species = String(prefs.species ?? '');
  const enabled = cat?.species?.[species]?.enabled_features;
  const shown = (k: string) =>
    k in prefs &&
    (!k.startsWith('feature_') ||
      !Array.isArray(enabled) ||
      enabled.includes(k));
  const isColour = (k: string) =>
    !choicesOf(cat, k) && !!parseHex(String(prefs[k] ?? ''));

  // Every colour on this file, offered in the colour panel's recent row.
  const fileColours = [
    ...Object.values(prefs),
    ...Object.values(char.kit || {}).flatMap((it) =>
      String(it.greyscale || '').split('#'),
    ),
  ]
    .map((c) => parseHex(String(c)))
    .filter((c): c is string => !!c);

  const colour = (key: string, cx: number, cy: number, end: number) => (
    <ColorEntry
      key={`${key}-c`}
      x={cx}
      y={cy}
      w={end - cx}
      label=""
      value={String(prefs[key] ?? '')}
      recent={fileColours}
      native={(NATIVE_COLOR_KEYS as readonly string[]).includes(key)}
      onSet={(hex) => set(key, hex)}
      onPicker={() => act('char_color_pick', { key })}
    />
  );

  /** Cycler width for a row whose controls start at V and must end by end. */
  const widthFor = (V: number, end: number, extra: number) =>
    Math.max(6, Math.min(20, end - V - 4 - extra));

  const choiceRow = (key: string): Row => {
    const list = choicesOf(cat, key);
    const value = prefs[key];
    const pair = PAIRED[key] && shown(PAIRED[key]) ? PAIRED[key] : null;
    const palette = PALETTES.has(key) && list ? sortPalette(key, list) : null;
    let shownValue = nameOf(cat, key, value);
    if (key === 'voice_pack') {
      // "Group: Name" in the list; the row shows the name.
      shownValue = shownValue.split(': ').pop() || shownValue;
    }
    let prev = () => list && set(key, stepChoice(list, value, -1));
    let next = () => list && set(key, stepChoice(list, value, 1));
    if (key === 'body_type') {
      const fem =
        value === 'female' || (value !== 'male' && prefs.gender === 'female');
      shownValue = fem ? 'Feminine' : 'Masculine';
      prev = () => set(key, fem ? 'male' : 'female');
      next = prev;
    }
    const long = !!list && list.length > PICK_OVER;
    return {
      key,
      // A palette that can't sit beside the cycler gets more rows (heightOf).
      h: 1,
      draw: (L, V, ry, end) => {
        let VW = widthFor(V, end, pair ? 11 : key === 'voice_pack' ? 9 : 0);
        if (pair && VW < 12) {
          VW = widthFor(V, end, 3);
        }
        const after = V + VW + 5;
        const out: ReactNode[] = [
          <Put key={`${key}-l`} x={L} y={ry} cls="dim">
            {labelOf(key)}
          </Put>,
          <Cycler
            key={`${key}-v`}
            x={V}
            y={ry}
            w={VW}
            value={shownValue}
            disabled={!list && key !== 'body_type'}
            onPrev={prev}
            onNext={next}
            onValue={long ? () => setPicker(key) : undefined}
          />,
        ];
        if (pair) {
          out.push(colour(pair, after, ry, end));
        }
        if (key === 'voice_pack' && after + 8 <= end) {
          out.push(
            <Btn
              key="play"
              x={after}
              y={ry}
              label="PLAY"
              onClick={() => act('char_voice_play')}
            />,
          );
        }
        if (palette) {
          out.push(...paletteChips(key, palette, after, ry, end, V));
        }
        return out;
      },
    };
  };

  /** Skin tones light to dark; other palettes in the server's order. */
  const sortPalette = (key: string, list: string[]) => {
    if (key !== 'skin_tone') {
      return list;
    }
    const luma = (c: string) => {
      const n = parseInt((namedHex(cat, key, c) || '#000000').slice(1), 16);
      return 0.3 * (n >> 16) + 0.59 * ((n >> 8) & 255) + 0.11 * (n & 255);
    };
    return [...list].sort((a, b) => luma(b) - luma(a));
  };

  /** Swatches for a named-colour list: beside the cycler when they fit, else one more row. */
  const paletteChips = (
    key: string,
    list: string[],
    after: number,
    ry: number,
    end: number,
    V: number,
  ) => {
    const beside = after + list.length * 2 <= end;
    const per = Math.max(1, Math.floor((end - V) / 2));
    return list.map((c, i) => {
      const hex = namedHex(cat, key, c) || '#000000';
      const sx = beside ? after + i * 2 : V + (i % per) * 2;
      const sy = beside ? ry : ry + 1 + Math.floor(i / per);
      return (
        <Swatch
          key={`${key}-${c}`}
          x={sx}
          y={sy}
          hex={hex}
          sel={c === prefs[key]}
          onClick={() => set(key, c)}
        />
      );
    });
  };

  /** A numeric preference (bark pitch, speed): steps within the catalog's range. */
  const numberRow = (key: string): Row => {
    const spec = (cat?.[key] || {}) as { minimum?: number; maximum?: number };
    const step = NUMERIC_STEPS[key];
    const lo = spec.minimum ?? 0;
    const hi = spec.maximum ?? lo + step * 20;
    const value = Number(prefs[key]) || lo;
    const to = (v: number) =>
      set(key, Math.round(Math.min(hi, Math.max(lo, v)) * 100) / 100);
    const text = value.toFixed(1);
    return {
      key,
      h: 1,
      draw: (L, V, ry) => [
        <Put key={`${key}-l`} x={L} y={ry} cls="dim">
          {labelOf(key)}
        </Put>,
        <Cycler
          key={`${key}-v`}
          x={V}
          y={ry}
          w={text.length}
          value={text}
          onPrev={() => value > lo && to(value - step)}
          onNext={() => value < hi && to(value + step)}
        />,
      ],
    };
  };

  const colourRow = (key: string): Row => ({
    key,
    h: 1,
    draw: (L, V, ry, end) => [
      <Put key={`${key}-l`} x={L} y={ry} cls="dim">
        {labelOf(key)}
      </Put>,
      colour(key, V, ry, end),
    ],
  });

  // ---- the rows, top to bottom
  const extraFeatures = Object.keys(prefs)
    .filter(
      (k) =>
        k.startsWith('feature_') &&
        !(BODY_KEYS as readonly string[]).includes(k),
    )
    .sort((a, b) => {
      const ia = FEATURE_ORDER.indexOf(a);
      const ib = FEATURE_ORDER.indexOf(b);
      if (ia < 0 && ib < 0) {
        return a < b ? -1 : 1;
      }
      return (ia < 0 ? 99 : ia) - (ib < 0 ? 99 : ib);
    });
  const order: string[] = [];
  for (const k of BODY_KEYS) {
    if (k === 'real_name') {
      continue;
    }
    if (k === 'voice_pack' && species === 'plasmaman') {
      order.push('@suit');
    }
    order.push(k);
    if (k === 'feature_mcolor') {
      order.push(...extraFeatures);
    }
  }
  const pairedShown = new Set(
    Object.entries(PAIRED)
      .filter(([style]) => shown(style))
      .map(([, c]) => c),
  );

  const rows: Row[] = [];
  for (const k of order) {
    if (k === '@suit') {
      rows.push({
        key: k,
        h: 1,
        draw: (L, V, ry) => [
          <Put key="suit-l" x={L} y={ry} cls="dim">
            {'SUIT'}
          </Put>,
          <Put key="suit-v" x={V + 2} y={ry} cls="dim">
            {'ENVIROSUIT'}
          </Put>,
        ],
      });
      continue;
    }
    if (!shown(k) || pairedShown.has(k)) {
      continue;
    }
    if (k === 'age') {
      const age = Number(prefs.age) || AGE_MIN;
      rows.push({
        key: k,
        h: 1,
        draw: (L, V, ry) => [
          <Put key="age-l" x={L} y={ry} cls="dim">
            {'AGE'}
          </Put>,
          <Cycler
            key="age-v"
            x={V}
            y={ry}
            w={String(age).length}
            value={String(age)}
            onPrev={() => age > AGE_MIN && set('age', age - 1)}
            onNext={() => age < AGE_MAX && set('age', age + 1)}
          />,
        ],
      });
      continue;
    }
    if (k in NUMERIC_STEPS) {
      rows.push(numberRow(k));
      continue;
    }
    const row = isColour(k) ? colourRow(k) : choiceRow(k);
    rows.push(row);
    if (k === 'species' && char.confirm) {
      rows.push(confirmRow());
    }
  }

  function confirmRow(): Row {
    const c = char!.confirm!;
    const text = `${nameOf(cat, 'species', c.value)} can't keep: ${c.quirks.join(', ')}`;
    return {
      key: '@confirm',
      h: 0, // set when laid out (depends on the column width)
      draw: (L, _V, ry, end) => {
        const lines = wrap(text.toUpperCase(), Math.max(10, end - L));
        return [
          ...lines.map((l, i) => (
            <Put key={`cf${i}`} x={L} y={ry + i} cls="amb">
              {l}
            </Put>
          )),
          <Btn
            key="cf-ok"
            x={L}
            y={ry + lines.length}
            label="CHANGE"
            amber
            onClick={() => act('char_confirm', { ok: 1 })}
          />,
          <Btn
            key="cf-no"
            x={L + 12}
            y={ry + lines.length}
            label="CANCEL"
            onClick={() => act('char_confirm', { ok: 0 })}
          />,
        ];
      },
    };
  }

  // ---- layout: one column, two, or pages
  const nameY = y + 1;
  const flowTop = nameY + (h >= 20 ? 2 : 1);
  const last = y + h - 2;
  const L0 = x + 3;

  const heightOf = (r: Row, colEnd: number, L: number, V: number) => {
    if (r.key === '@confirm') {
      return (
        wrap(
          `${nameOf(cat, 'species', char.confirm?.value)} can't keep: ${char.confirm?.quirks.join(', ')}`,
          Math.max(10, colEnd - L),
        ).length + 1
      );
    }
    if (PALETTES.has(r.key)) {
      const list = choicesOf(cat, r.key);
      if (list) {
        const VW = widthFor(V, colEnd, 0);
        const after = V + VW + 5;
        if (after + list.length * 2 > colEnd) {
          const per = Math.max(1, Math.floor((colEnd - V) / 2));
          return 1 + Math.ceil(list.length / per);
        }
      }
    }
    return r.h;
  };

  type Placed = { row: Row; L: number; V: number; y: number; end: number };
  const layout = (ncol: number, cap: number): Placed[][] => {
    const colW = Math.floor((w - 2) / ncol);
    const pages: Placed[][] = [[]];
    let col = 0;
    let yy = flowTop;
    for (const r of rows) {
      const L = L0 + col * colW;
      const end = x + (col + 1) * colW - 1;
      const rh = heightOf(r, end, L, L + LW);
      if (yy + rh - 1 > flowTop + cap - 1 && yy > flowTop) {
        col++;
        yy = flowTop;
        if (col >= ncol) {
          col = 0;
          pages.push([]);
        }
      }
      const L2 = L0 + col * colW;
      const end2 = x + (col + 1) * colW - 1;
      pages[pages.length - 1].push({
        row: r,
        L: L2,
        V: L2 + LW,
        y: yy,
        end: end2,
      });
      yy += rh;
    }
    return pages;
  };
  const cap = last - flowTop + 1;
  let pages = layout(1, cap);
  if (pages.length > 1 && w >= 64) {
    pages = layout(2, cap);
  }
  if (pages.length > 1) {
    pages = layout(w >= 64 ? 2 : 1, cap - 1);
  }
  const pg = Math.min(page, pages.length - 1);

  // ---- NAME, across the top
  const V0 = L0 + LW;
  const fw = Math.max(8, Math.min(24, x + w - V0 - 16));
  const nameRow = (
    <div onBlur={commitName}>
      <Put x={L0} y={nameY} cls="dim">
        {'NAME'}
      </Put>
      <Field
        x={V0}
        y={nameY}
        w={fw}
        value={name}
        max={NAME_MAX}
        onChange={setName}
        onEnter={commitName}
      />
      <Btn
        x={V0 + fw + 3}
        y={nameY}
        label="RANDOM"
        onClick={() => act('char_random_name')}
      />
    </div>
  );

  return (
    <>
      {nameRow}
      {pages[pg].map((p) => (
        <span key={p.row.key}>{p.row.draw(p.L, p.V, p.y, p.end)}</span>
      ))}
      {pages.length > 1 && (
        <Pager
          x={x + w - 3}
          y={last}
          page={pg}
          pages={pages.length}
          onPage={setPage}
        />
      )}
      {!!picker && (
        <ListPicker
          box={props}
          title={labelOf(picker)}
          list={choicesOf(cat, picker) || []}
          value={String(prefs[picker] ?? '')}
          nameOf={(v) => nameOf(cat, picker, v)}
          onPick={(v) => {
            setPicker(null);
            if (v !== prefs[picker]) {
              set(picker, v);
            }
          }}
          onClose={() => setPicker(null)}
        />
      )}
    </>
  );
}

/** ` < ` n/m ` > `, ending just before column x. */
function Pager(props: {
  x: number;
  y: number;
  page: number;
  pages: number;
  onPage: (p: number) => void;
}) {
  const { x, y, page, pages, onPage } = props;
  const label = `${page + 1}/${pages}`;
  const px = x - 8 - label.length;
  return (
    <>
      {page > 0 ? (
        <Put x={px} y={y} cls="inv" onClick={() => onPage(page - 1)}>
          {' < '}
        </Put>
      ) : (
        <Put x={px} y={y} cls="faint">
          {' < '}
        </Put>
      )}
      <Put x={px + 4} y={y} cls="dim">
        {label}
      </Put>
      {page < pages - 1 ? (
        <Put
          x={px + 5 + label.length}
          y={y}
          cls="inv"
          onClick={() => onPage(page + 1)}
        >
          {' > '}
        </Put>
      ) : (
        <Put x={px + 5 + label.length} y={y} cls="faint">
          {' > '}
        </Put>
      )}
    </>
  );
}

/**
 * The long-list picker (hairstyles and the like): a panel over the editor with a FIND field,
 * the choices in columns, paged, the current one lit. Click picks; Escape or CANCEL closes.
 */
function ListPicker(props: {
  box: CellBox;
  title: string;
  list: string[];
  value: string;
  nameOf: (v: string) => string;
  onPick: (v: string) => void;
  onClose: () => void;
}) {
  const { box, title, list, value, nameOf: show, onPick, onClose } = props;
  const px = box.x + 2;
  const py = box.y;
  const pw = Math.max(20, box.w - 4);
  const ph = Math.max(8, box.h - 1);
  const colW = Math.min(28, pw - 6);
  const ncol = Math.max(1, Math.floor((pw - 4) / (colW + 2)));
  const listTop = py + 4;
  const listRows = Math.max(1, py + ph - 3 - listTop);
  const per = listRows * ncol;

  const [find, setFind] = useState('');
  const [page, setPage] = useState(() =>
    Math.max(0, Math.floor(list.indexOf(value) / per)),
  );

  useBack(onClose);

  const needle = find.trim().toLowerCase();
  const shown = needle
    ? list.filter((v) => show(v).toLowerCase().includes(needle))
    : list;
  const pages = Math.max(1, Math.ceil(shown.length / per));
  const pg = Math.min(page, pages - 1);
  const slice = shown.slice(pg * per, (pg + 1) * per);

  return (
    <Panel x={px} y={py} w={pw} h={ph} title={title}>
      <Put x={px + 3} y={py + 2} cls="dim">
        {'FIND'}
      </Put>
      <Field
        x={px + 8}
        y={py + 2}
        w={Math.min(24, pw - 12)}
        value={find}
        max={32}
        onChange={(v) => {
          setFind(v);
          setPage(0);
        }}
        onEnter={() => slice.length === 1 && onPick(slice[0])}
      />
      {slice.map((v, i) => {
        const cx = px + 3 + Math.floor(i / listRows) * (colW + 2);
        const cy = listTop + (i % listRows);
        const cur = v === value;
        return (
          <Put
            key={v}
            x={cx}
            y={cy}
            cls={cur ? 'inv' : ''}
            hoverCls="inv"
            onClick={() => onPick(v)}
            auto={cur ? 1 : undefined}
          >
            {pad(show(v).toUpperCase(), colW)}
          </Put>
        );
      })}
      {!slice.length && (
        <Put x={px + 3} y={listTop} cls="faint">
          {'NO MATCH'}
        </Put>
      )}
      <Pager
        x={px + pw - 14}
        y={py + ph - 2}
        page={pg}
        pages={pages}
        onPage={setPage}
      />
      <Btn
        x={px + pw - 2}
        y={py + ph - 2}
        label="CANCEL"
        right
        onClick={onClose}
      />
    </Panel>
  );
}
