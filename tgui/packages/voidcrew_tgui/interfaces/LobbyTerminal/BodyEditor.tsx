/**
 * BODY (design 03 section 4): two groups, IDENTITY and LOOKS, in the ID column under the
 * viewscreen; the open group's rows in the work column. Rows come from CharData.prefs (the
 * server's accessibility rules pick them), in IDENTITY_KEYS / LOOKS_KEYS order. A row opens
 * its list picker or colour panel in the work column (level 2), flips a two-way choice, or
 * types a number. `<` and `>` on a row are mouse targets; the arrows always move the focus.
 *
 * Every change is a char_set and waits for the push; only typed text and a dragged colour are
 * held on the page.
 */
import { type ReactNode, useEffect, useState } from 'react';
import { useBackend } from 'tgui/backend';
import type { ServerData } from 'tgui/interfaces/PreferencesMenu/types';

import {
  clamp,
  ID_W,
  ID_X,
  IdColumn,
  planId,
  q,
  useChar,
  WORK_W,
  WORK_X,
} from './CharFrame';
import { ColourPanel, ListPicker } from './CharPickers';
import { parseHex } from './ColorEntry';
import { sfx, useChanged } from './motion';
import {
  Big,
  BODY_Y,
  bodyRows,
  cut,
  Field,
  FlashAt,
  HRule,
  Key,
  Pager,
  Put,
  Slab,
  Swatch,
  safe,
  useGrid,
  WipeAt,
  wrapMax,
} from './term';
import {
  AGE_MAX,
  AGE_MIN,
  IDENTITY_KEYS,
  LOOKS_KEYS,
  type LobbyData,
  NAME_MAX,
  NATIVE_COLOR_KEYS,
} from './types';
import {
  choicesOf,
  namedHex,
  nameOf,
  usePrefsCatalog,
  voiceShort,
} from './usePrefsCatalog';

export type BodyGroup = 'identity' | 'looks';

const LABELS: Record<string, string> = {
  age: 'AGE',
  species: 'SPECIES',
  body_type: 'BUILD',
  gender: 'PRONOUNS',
  background: 'BACKGROUND',
  voice_pack: 'VOICE',
  bark_speech_pitch: 'PITCH',
  bark_speech_speed: 'SPEED',
  skin_tone: 'SKIN',
  hairstyle_name: 'HAIR',
  hair_gradient: 'GRADIENT',
  facial_style_name: 'FACIAL',
  feature_mcolor: 'SCALES',
  feature_ethcolor: 'GLOW',
  eye_color: 'EYES',
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

/** Colour rows that sit under their style (labelled COLOUR, indented). */
const PAIRED = new Set([
  'hair_color',
  'hair_gradient_color',
  'facial_hair_color',
  'underwear_color',
]);

/** The colour panel's head (and crumb) for each body colour. */
const COLOUR_LABELS: Record<string, string> = {
  hair_color: 'HAIR COLOUR',
  hair_gradient_color: 'GRADIENT COLOUR',
  facial_hair_color: 'FACIAL COLOUR',
  underwear_color: 'UNDERWEAR COLOUR',
  eye_color: 'EYES',
  feature_mcolor: 'SCALES',
};

/** Named-colour lists that show a chip per choice. */
const PALETTES = new Set(['skin_tone', 'feature_ethcolor']);

/** Typed numbers: range and the step of `<` `>`. */
const NUMBERS: Record<string, { lo: number; hi: number; step: number }> = {
  age: { lo: AGE_MIN, hi: AGE_MAX, step: 1 },
  bark_speech_pitch: { lo: 0.4, hi: 2, step: 0.1 },
  bark_speech_speed: { lo: 4, hi: 16, step: 0.5 },
};

export const labelOf = (key: string) =>
  LABELS[key] ||
  COLOUR_LABELS[key] ||
  cut(
    key
      .replace(/^feature_/, '')
      .replace(/_/g, ' ')
      .toUpperCase(),
    10,
  );

type Kind =
  | 'name'
  | 'number'
  | 'species'
  | 'build'
  | 'voice'
  | 'palette'
  | 'colour'
  | 'list'
  | 'flip'
  | 'fixed';

/** How a row behaves, from its key and the catalog. Null: no row. */
function kindOf(
  cat: ServerData | null,
  key: string,
  value: unknown,
): Kind | null {
  if (key === 'real_name') {
    return 'name';
  }
  if (key in NUMBERS) {
    return 'number';
  }
  if (key === 'species') {
    return 'species';
  }
  if (key === 'body_type') {
    return 'build';
  }
  if (key === 'voice_pack') {
    return 'voice';
  }
  const list = choicesOf(cat, key);
  if (list) {
    if (PALETTES.has(key)) {
      return 'palette';
    }
    return list.length >= 3 ? 'list' : list.length === 2 ? 'flip' : 'fixed';
  }
  if (parseHex(String(value ?? ''))) {
    return 'colour';
  }
  // A key the catalog doesn't describe (a new preference): its value, read only.
  return typeof value === 'string' || typeof value === 'number'
    ? 'fixed'
    : null;
}

/** The keys of a group that show for this character, in order. */
export function groupKeys(
  cat: ServerData | null,
  prefs: Record<string, any>,
  group: BodyGroup,
): string[] {
  const species = String(prefs.species ?? '');
  const enabled = cat?.species?.[species]?.enabled_features;
  const shown = (k: string) =>
    k in prefs &&
    (!k.startsWith('feature_') ||
      !Array.isArray(enabled) ||
      enabled.includes(k));
  const named = new Set<string>([...IDENTITY_KEYS, ...LOOKS_KEYS]);
  const extra = Object.keys(prefs)
    .filter((k) => k.startsWith('feature_') && !named.has(k))
    .sort();
  const order: string[] =
    group === 'identity'
      ? [...IDENTITY_KEYS]
      : LOOKS_KEYS.flatMap((k) => (k === '@features' ? extra : [k]));
  const bald = prefs.hairstyle_name === 'Bald';
  const hidden = (k: string) =>
    (bald &&
      (k === 'hair_color' ||
        k === 'hair_gradient' ||
        k === 'hair_gradient_color')) ||
    (k === 'hair_gradient_color' && prefs.hair_gradient === 'None') ||
    (k === 'facial_hair_color' && prefs.facial_style_name === 'Shaved') ||
    (k === 'underwear_color' && prefs.underwear === 'Nude');
  return order.filter(
    (k) => shown(k) && !hidden(k) && kindOf(cat, k, prefs[k]) !== null,
  );
}

/** Every colour on this file (body and kit), for the colour panel's recent chips. */
export function fileColours(char: LobbyData['char']): string[] {
  if (!char) {
    return [];
  }
  return [
    ...Object.values(char.prefs),
    ...Object.values(char.kit || {}).flatMap((it) =>
      String(it.greyscale || '').split('#'),
    ),
  ]
    .map((c) => parseHex(String(c)))
    .filter((c): c is string => !!c);
}

/** Skin tones light to dark; other palettes in the server's order. */
function sortPalette(cat: ServerData | null, key: string, list: string[]) {
  if (key !== 'skin_tone') {
    return list;
  }
  const luma = (c: string) => {
    const n = parseInt((namedHex(cat, key, c) || '#000000').slice(1), 16);
    return 0.3 * (n >> 16) + 0.59 * ((n >> 8) & 255) + 0.11 * (n & 255);
  };
  return [...list].sort((a, b) => luma(b) - luma(a));
}

/** What BUILD shows: "Use gender" resolves to the build it gives. */
function buildFem(prefs: Record<string, any>) {
  const v = prefs.body_type;
  return v === 'female' || (v !== 'male' && prefs.gender === 'female');
}

// ---------------------------------------------------------------------------
// Level 2 screens. Each reads live data, so the frame can keep the element as it was opened.

/** A list picker on a BODY key. Closes when its row goes away (species changed in tg's window). */
export function BodyListPick(props: { k: string }) {
  const { k } = props;
  const { act, data } = useBackend<LobbyData>();
  const cat = usePrefsCatalog();
  const { closeSub } = useChar();
  const prefs = data.char?.prefs || {};
  const gone = !(k in prefs);
  useEffect(() => {
    if (gone) {
      closeSub();
    }
  }, [gone]);
  const list = choicesOf(cat, k) || [];
  const palette = PALETTES.has(k);
  return (
    <ListPicker
      x={WORK_X}
      w={WORK_W}
      label={labelOf(k)}
      choices={palette ? sortPalette(cat, k, list) : list}
      value={String(prefs[k] ?? '')}
      nameOf={(v) => nameOf(cat, k, v)}
      hexOf={palette ? (v) => namedHex(cat, k, v) : undefined}
      onPick={(v) => {
        if (v !== String(prefs[k] ?? '')) {
          act('char_set', { key: k, value: v });
        }
        // A voice plays as it is picked (picking the current one plays it again).
        if (k === VOICE_KEY) {
          act('char_voice_play');
        }
      }}
      onClose={closeSub}
    />
  );
}

/** The voice pack preference: picking or stepping it plays the voice. */
const VOICE_KEY = 'voice_pack';

/** The colour panel on a BODY colour key. */
export function BodyColour(props: { k: string }) {
  const { k } = props;
  const { act, data } = useBackend<LobbyData>();
  const { closeSub } = useChar();
  const char = data.char;
  const prefs = char?.prefs || {};
  const gone = !(k in prefs);
  useEffect(() => {
    if (gone) {
      closeSub();
    }
  }, [gone]);
  return (
    <ColourPanel
      x={WORK_X}
      w={WORK_W}
      label={labelOf(k)}
      value={String(prefs[k] ?? '#000000')}
      recent={fileColours(char)}
      native={(NATIVE_COLOR_KEYS as readonly string[]).includes(k)}
      onApply={(hex) => act('char_set', { key: k, value: hex })}
      onPicker={() => act('char_color_pick', { key: k })}
      onClose={closeSub}
    />
  );
}

/** The species picker (design 03 section 4.6): one column, the focused species' description. */
export function SpeciesPick() {
  const { act, data } = useBackend<LobbyData>();
  const cat = usePrefsCatalog();
  const { rows: M } = useGrid();
  const value = String(data.char?.prefs.species ?? '');
  const list = choicesOf(cat, 'species') || [];
  const [over, setOver] = useState(value);
  const B = bodyRows(M);
  // Rows stretch into the room the longest description leaves (at most 7 lines), so a tall
  // pane fills instead of leaving the foot empty; short panes keep 1.25-row rows.
  const longest = Math.max(
    2,
    ...list.map(
      (id) =>
        wrapMax(safe(String(cat?.species?.[id]?.desc ?? '')), WORK_W, 7).length,
    ),
  );
  const rowsRoom = M - 1.25 - 5.25 - 0.75 - longest;
  const h =
    B < 20
      ? 1.25
      : clamp(q((rowsRoom + 0.25) / Math.max(1, list.length) - 0.25), 1.5, 3);
  const pitch = B < 20 ? 1.25 : h + 0.25;
  // Rows that leave at least two lines of description under them.
  const room = Math.floor((M - 1.25 - 2 - 0.75 - 5.25 + (pitch - h)) / pitch);
  const fits = list.length <= room;
  const per = Math.max(
    1,
    fits
      ? list.length
      : Math.floor((M - 1.25 - 2 - 0.75 - 5.25 - 1.25 + (pitch - h)) / pitch),
  );
  const pages = Math.max(1, Math.ceil(list.length / per));
  const [page, setPage] = useState(() =>
    Math.max(0, Math.floor(list.indexOf(value) / per)),
  );
  const pg = Math.min(page, pages - 1);
  const slice = list.slice(pg * per, pg * per + per);
  const step = (by: number) => {
    const n = list.length;
    const at = list.indexOf(value);
    if (n) {
      act('char_set', {
        key: 'species',
        value: list[(((at < 0 ? 0 : at + by) % n) + n) % n],
      });
    }
  };
  const descY = 5.25 + slice.length * pitch - (pitch - h) + 0.75;
  const descRows = Math.floor(M - 1.25 - descY - (pages > 1 ? 1.25 : 0));
  const desc = safe(String(cat?.species?.[over]?.desc ?? ''));
  return (
    <>
      <Big x={WORK_X} y={3.125} scale={1.25} cls="wht lt-name">
        {'SPECIES'}
      </Big>
      <Key
        x={WORK_X + WORK_W - 6}
        y={BODY_Y}
        w={3}
        kind="cap"
        label="<"
        onClick={() => step(-1)}
      />
      <Key
        x={WORK_X + WORK_W - 3}
        y={BODY_Y}
        w={3}
        kind="cap"
        label=">"
        onClick={() => step(1)}
      />
      <HRule x={WORK_X} y={4.75} w={WORK_W} />
      {slice.map((id, i) => {
        const y = 5.25 + i * pitch;
        const on = id === value;
        return (
          <Slab
            key={id}
            x={WORK_X}
            y={y}
            w={WORK_W}
            h={h}
            variant="row"
            alt={pitch === h && i % 2 === 1}
            on={on}
            auto={on ? 5 : undefined}
            onFocus={(f) => f && setOver(id)}
            onClick={() => act('char_set', { key: 'species', value: id })}
          >
            {h >= 2.25 ? (
              <Big
                x={WORK_X + 2}
                y={y + (h - 1.25) / 2}
                scale={1.25}
                cls={on ? 'wht' : ''}
              >
                {cut(safe(nameOf(cat, 'species', id)).toUpperCase(), 28)}
              </Big>
            ) : (
              <Put x={WORK_X + 2} y={y + (h - 1) / 2} cls={on ? 'wht' : ''}>
                {cut(safe(nameOf(cat, 'species', id)).toUpperCase(), 36)}
              </Put>
            )}
          </Slab>
        );
      })}
      {wrapMax(desc, WORK_W, Math.max(0, descRows)).map((line, i) => (
        <Put key={i} x={WORK_X} y={descY + i}>
          {line}
        </Put>
      ))}
      <Pager
        x={WORK_X + WORK_W}
        y={M - 2.25}
        page={pg + 1}
        pages={pages}
        onPage={(p) => setPage(p - 1)}
        right
      />
      <WipeAt
        x={WORK_X}
        y={5.25}
        w={WORK_W}
        h={slice.length * pitch}
        k={pg}
      />
      {!list.length && (
        <Put x={WORK_X} y={5.375} cls="dim">
          {'NO MATCH'}
        </Put>
      )}
    </>
  );
}

// ---------------------------------------------------------------------------
// Rows

/** One BODY row: the slab, its label, the value and the mouse-only `<` `>`. */
function Row(props: {
  y: number;
  h: number;
  alt: boolean;
  label: string;
  paired?: boolean;
  /** Enter or a click on the row; null: the row is not a focus stop (a typed number). */
  onPress: (() => void) | null;
  onStep?: (by: number) => void;
  auto?: number;
  /** Draws the value; ty = the text row (centred), by = the 1.25 Big row. */
  value: (ty: number, by: number, focused: boolean) => ReactNode;
}) {
  const { y, h, alt, label, paired, onPress, onStep, auto, value } = props;
  const [focused, setFocused] = useState(false);
  const ty = y + (h - 1) / 2;
  const by = y + (h - 1.25) / 2;
  return (
    <Slab
      x={WORK_X}
      y={y}
      w={WORK_W}
      h={h}
      variant="row"
      alt={alt}
      auto={auto}
      onFocus={setFocused}
      onClick={onPress || undefined}
    >
      <Put x={paired ? 27 : 25} y={ty} cls={focused ? 'wht' : 'dim'}>
        {cut(label, paired ? 8 : 10)}
      </Put>
      {value(ty, by, focused)}
      {!!onStep && (
        <>
          <Key
            x={56}
            y={y}
            w={3}
            h={h}
            kind="cap"
            label="<"
            mouseOnly
            onClick={() => onStep(-1)}
          />
          <Key
            x={59}
            y={y}
            w={3}
            h={h}
            kind="cap"
            label=">"
            mouseOnly
            onClick={() => onStep(1)}
          />
        </>
      )}
    </Slab>
  );
}

/** A row's value as text: Big when the row is tall and the text short. */
function ValueText(props: {
  x: number;
  w: number;
  h: number;
  ty: number;
  by: number;
  text: string;
  cls?: string;
  /** The page's value size (BodyEditor `big`); else the row decides alone. */
  big?: boolean;
}) {
  const { x, w, h, ty, by, text, cls = '', big } = props;
  // The value flashes when it changes, whoever changed it (this page or tg's own window).
  if ((big ?? h >= 2.25) && text.length <= 15 && text.length * 1.25 <= w) {
    return (
      <Big x={x} y={by} scale={1.25} cls={cls} pulse={text}>
        {text}
      </Big>
    );
  }
  return (
    <Put x={x} y={ty} cls={cls} pulse={text}>
      {cut(text, w)}
    </Put>
  );
}

/** A typed number (AGE, PITCH, SPEED): digits and one dot; Enter submits, leaving restores. */
function NumberField(props: {
  k: string;
  y: number;
  h: number;
  value: number;
  big?: boolean;
  onSet: (v: number) => void;
}) {
  const { k, y, h, value, big, onSet } = props;
  const spec = NUMBERS[k];
  const shown = k === 'age' ? String(Math.round(value)) : value.toFixed(1);
  const [text, setText] = useState(shown);
  useEffect(() => setText(shown), [shown]);
  const fh = Math.min(1.5, h);
  return (
    <div onBlur={() => setText(shown)}>
      <Field
        x={36}
        y={y + (h - fh) / 2}
        w={8}
        h={fh}
        value={text}
        max={4}
        pulse={value}
        big={big}
        onChange={(v) => {
          const clean = v.replace(/[^0-9.]/g, '');
          const dot = clean.indexOf('.');
          setText(
            dot < 0
              ? clean
              : clean.slice(0, dot + 1) +
                  clean.slice(dot + 1).replace(/\./g, ''),
          );
        }}
        onEnter={() => {
          const n = Number(text);
          if (!text || !Number.isFinite(n)) {
            setText(shown);
            return;
          }
          const stepped = Math.round(n / spec.step) * spec.step;
          const v = clamp(Math.round(stepped * 100) / 100, spec.lo, spec.hi);
          setText(k === 'age' ? String(v) : v.toFixed(1));
          if (v !== value) {
            onSet(v);
          }
        }}
      />
    </div>
  );
}

/** The NAME row: a 3-row slab with [ RANDOM ] and the name field. */
function NameRow(props: { auto?: number }) {
  const { act, data } = useBackend<LobbyData>();
  const real = String(data.char?.prefs.real_name ?? '');
  const slot = data.char?.slot;
  const [text, setText] = useState(real);
  const [typing, setTyping] = useState(false);
  // A push sets the field unless the player is typing in it; a slot change always does.
  useEffect(() => {
    if (!typing) {
      setText(real);
    }
  }, [real]);
  useEffect(() => {
    setText(real);
  }, [slot]);
  // The name was accepted (typed here, RANDOM, or tg's window): the field's band flashes once.
  const [accepted, setAccepted] = useState(0);
  useChanged(`${slot}|${real}`, (was) => {
    if (was.split('|')[0] === String(slot)) {
      setAccepted((n) => n + 1);
      sfx('ok', { own: true });
    }
  });
  const commit = () => {
    const next = text.trim();
    if (next && next !== real) {
      act('char_set', { key: 'real_name', value: next });
    } else {
      setText(real);
    }
  };
  const y = BODY_Y;
  return (
    <>
      <Slab x={WORK_X} y={y} w={WORK_W} h={3} variant="row" />
      <Put x={25} y={y + 0.25} cls="dim">
        {'NAME'}
      </Put>
      <Key
        x={50}
        y={y}
        w={12}
        kind="cap"
        label="[ RANDOM ]"
        onClick={() => act('char_random_name')}
      />
      <div
        onFocus={() => setTyping(true)}
        onBlur={() => {
          setTyping(false);
          commit();
        }}
      >
        <Field
          x={25}
          y={y + 1.5}
          w={36}
          h={1.5}
          value={text}
          max={NAME_MAX}
          auto={props.auto}
          onChange={setText}
          onEnter={commit}
        />
      </div>
      <FlashAt x={25} y={y + 1.5} w={36} h={1.5} k={accepted} />
    </>
  );
}

export function BodyEditor(props: {
  group: BodyGroup;
  setGroup: (g: BodyGroup) => void;
}) {
  const { group, setGroup } = props;
  const { act, data } = useBackend<LobbyData>();
  const cat = usePrefsCatalog();
  const { sub, subOpen, closeSub, from, quiet } = useChar();
  const { rows: M } = useGrid();
  const char = data.char!;
  const prefs = char.prefs;
  // First focus: NAME when BODY opens; a row coming back from its picker; nothing on a group switch.
  const [fresh, setFresh] = useState(true);
  const [page, setPage] = useState(0);

  const set = (key: string, value: unknown) => act('char_set', { key, value });
  // The species changed, with or without the dialog.
  useChanged(String(prefs.species ?? ''), () => sfx('ok', { own: true }));

  // ---- ID column: the two group slabs
  let gh = 1.25;
  const plan = planId(M, 2.75, (la) => {
    gh = clamp(q((la + 0.25) / 2 - 0.25), 1.25, 4.5);
    return 2 * gh + 0.25;
  });
  const groups: [BodyGroup, string][] = [
    ['identity', 'IDENTITY'],
    ['looks', 'LOOKS'],
  ];
  const idList = groups.map(([g, label], i) => {
    const y = plan.top + i * (gh + 0.25);
    return (
      <Slab
        key={g}
        x={ID_X}
        y={y}
        w={ID_W}
        h={gh}
        variant="block"
        on={g === group}
        onClick={() => {
          // A group press leaves an open picker or colour panel.
          if (subOpen) {
            closeSub();
          }
          if (g !== group) {
            setFresh(false);
            setPage(0);
            setGroup(g);
          }
        }}
      >
        <Big x={3} y={y + (gh - 1.25) / 2} scale={1.25} cls="wht">
          {label}
        </Big>
      </Slab>
    );
  });

  if (subOpen) {
    return <IdColumn pv={plan.pv}>{idList}</IdColumn>;
  }

  // ---- work column: the rows
  const B = bodyRows(M);
  const keys = groupKeys(cat, prefs, group).filter((k) => k !== 'real_name');
  const fixed = group === 'identity' ? 3.25 : 0;
  const room = B - fixed;
  const n = Math.max(1, keys.length);
  let h = clamp(q((room + 0.25) / n - 0.25), 1.25, 4.5);
  let pitch = h + 0.25;
  let alt = false;
  if (n * pitch - 0.25 > room + 1e-6) {
    h = 1.25;
    pitch = 1.25;
    alt = true;
  }
  let per = n;
  if (n * 1.25 > room + 1e-6) {
    per = Math.max(1, Math.floor((room - 1.25) / 1.25));
  }
  const pages = Math.ceil(keys.length / per);
  const pg = Math.min(page, Math.max(0, pages - 1));
  const shownKeys = keys.slice(pg * per, pg * per + per);
  const y0 = BODY_Y + fixed;
  // One value size for the page: 1.25x when the rows are tall and every value fits it whole,
  // else every value at normal size.
  const fits = (s: string, w: number) => s.length <= 15 && s.length * 1.25 <= w;
  const big =
    h >= 2.25 &&
    shownKeys.every((k) => {
      const v = prefs[k];
      switch (kindOf(cat, k, v)) {
        case 'number':
        case 'build':
        case 'colour':
          return true;
        case 'voice':
          return fits(safe(voiceShort(nameOf(cat, k, v))), 10);
        case 'palette':
          return fits(safe(nameOf(cat, k, v)), 16);
        default:
          return fits(safe(nameOf(cat, k, v)), 19);
      }
    });

  const rows = shownKeys.map((k, i) => {
    const y = y0 + i * pitch;
    const value = prefs[k];
    const kind = kindOf(cat, k, value)!;
    const label = PAIRED.has(k) ? 'COLOUR' : labelOf(k);
    const list = choicesOf(cat, k) || [];
    const step = (by: number) => {
      if (list.length) {
        const at = list.indexOf(String(value));
        const nn = list.length;
        set(k, list[(((at < 0 ? 0 : at + by) % nn) + nn) % nn]);
      }
    };
    const auto = !quiet && from === k ? 5 : undefined;
    const common = {
      y,
      h,
      alt: alt && i % 2 === 1,
      label,
      paired: PAIRED.has(k),
      auto,
    };
    const text = (s: string) => (ty: number, by: number) => (
      <ValueText x={36} w={19} h={h} ty={ty} by={by} text={safe(s)} big={big} />
    );
    switch (kind) {
      case 'number': {
        const spec = NUMBERS[k];
        const v = Number(value) || spec.lo;
        return (
          <Row
            key={k}
            {...common}
            onPress={null}
            onStep={(by) => {
              const next = clamp(
                Math.round((v + by * spec.step) * 100) / 100,
                spec.lo,
                spec.hi,
              );
              if (next !== v) {
                set(k, next);
              }
            }}
            value={() => (
              <NumberField
                k={k}
                y={y}
                h={h}
                value={v}
                big={big}
                onSet={(nv) => set(k, nv)}
              />
            )}
          />
        );
      }
      case 'species':
        return (
          <Row
            key={k}
            {...common}
            onPress={() => sub(<SpeciesPick />, 'SPECIES', k)}
            onStep={step}
            value={text(nameOf(cat, k, value))}
          />
        );
      case 'build': {
        const fem = buildFem(prefs);
        const flip = () => set(k, fem ? 'male' : 'female');
        return (
          <Row
            key={k}
            {...common}
            onPress={flip}
            onStep={flip}
            value={text(fem ? 'Feminine' : 'Masculine')}
          />
        );
      }
      case 'voice':
        return (
          <Row
            key={k}
            {...common}
            onPress={() => sub(<BodyListPick k={k} />, label, k)}
            onStep={(by) => {
              step(by);
              act('char_voice_play');
            }}
            value={(ty, by) => (
              <ValueText
                x={36}
                w={19}
                h={h}
                ty={ty}
                by={by}
                text={safe(voiceShort(nameOf(cat, k, value)))}
                big={big}
              />
            )}
          />
        );
      case 'palette': {
        const hex = namedHex(cat, k, value) || '#000000';
        return (
          <Row
            key={k}
            {...common}
            onPress={() => sub(<BodyListPick k={k} />, label, k)}
            onStep={(by) => {
              const sorted = sortPalette(cat, k, list);
              const at = sorted.indexOf(String(value));
              const nn = sorted.length;
              if (nn) {
                set(k, sorted[(((at < 0 ? 0 : at + by) % nn) + nn) % nn]);
              }
            }}
            value={(ty, by) => (
              <>
                <Swatch x={36} y={ty} w={2} hex={hex} />
                <ValueText
                  x={39}
                  w={16}
                  h={h}
                  ty={ty}
                  by={by}
                  text={safe(nameOf(cat, k, value))}
                  big={big}
                />
              </>
            )}
          />
        );
      }
      case 'colour': {
        const hex = parseHex(String(value)) || '#000000';
        return (
          <Row
            key={k}
            {...common}
            onPress={() => sub(<BodyColour k={k} />, labelOf(k), k)}
            value={(ty, by) => (
              <>
                <Swatch x={36} y={ty} w={4} hex={hex} />
                <ValueText
                  x={41}
                  w={14}
                  h={h}
                  ty={ty}
                  by={by}
                  text={hex.toUpperCase()}
                  cls="dim"
                  big={big}
                />
              </>
            )}
          />
        );
      }
      case 'list':
        return (
          <Row
            key={k}
            {...common}
            onPress={() => sub(<BodyListPick k={k} />, label, k)}
            onStep={step}
            value={text(nameOf(cat, k, value))}
          />
        );
      case 'flip':
        return (
          <Row
            key={k}
            {...common}
            onPress={() => step(1)}
            onStep={step}
            value={text(nameOf(cat, k, value))}
          />
        );
      default:
        return (
          <Row
            key={k}
            {...common}
            onPress={null}
            value={text(nameOf(cat, k, value))}
          />
        );
    }
  });

  return (
    <>
      <IdColumn pv={plan.pv}>{idList}</IdColumn>
      {group === 'identity' && (
        <NameRow auto={!quiet && fresh && !from ? 5 : undefined} />
      )}
      {rows}
      <Pager
        x={62}
        y={M - 2.25}
        page={pg + 1}
        pages={pages}
        onPage={(p) => setPage(p - 1)}
        right
      />
      {/* The other group, or another page of rows, turns the page of the rows only. */}
      <WipeAt
        x={WORK_X}
        y={y0}
        w={WORK_W}
        h={M - 1.25 - y0 - (pages > 1 ? 1.25 : 0)}
        k={`${group}:${pg}`}
        n={(group === 'looks' ? 1000 : 0) + pg}
      />
    </>
  );
}
