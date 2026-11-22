/**
 * SETTINGS, OPTIONS group: every game preference tg's own window lists on its game page, by
 * tg's categories, edited in place.
 *
 * Names, categories and descriptions come from tg's TSX feature registry (so they never drift
 * from tg's window); kind, value and limits from the server's settings block
 * (lobby_settings.dm); choices and their display names from tg's preferences.json catalog.
 * Labelled dropdowns that tg builds in TSX (createDropdownInput: pixel scaling, scaling method,
 * multi-z depth) give their labels by calling the registry's component once outside React and
 * reading its Dropdown's options; it is a plain function with no hooks.
 *
 * Controls by kind: a toggle (a drawn checkbox) flips on Enter or a click; a choice steps with
 * Left and Right or the mouse arrows, and Enter opens the list picker when it has more than
 * HANDFUL choices or a choice's name is too long for the value zone (the picker shows names
 * whole; the row cuts them with the mark), else steps on; a number steps the same way, and Enter
 * or a click types it; a volume (tg's slider) is a track the mouse drags, with Left and Right
 * stepping a twentieth of its range; a colour opens the colour panel; a text types.
 */
import { useEffect, useRef, useState } from 'react';
import { useBackend } from 'tgui/backend';
import { features } from 'tgui/interfaces/PreferencesMenu/preferences/features';
import {
  CheckboxInput,
  CheckboxInputInverse,
  FeatureColorInput,
  FeatureNumberInput,
  FeatureShortTextInput,
  FeatureSliderInput,
} from 'tgui/interfaces/PreferencesMenu/preferences/features/base';
import { FeatureDropdownInput } from 'tgui/interfaces/PreferencesMenu/preferences/features/dropdowns';

import { clamp } from './CharFrame';
import { ColourPanel, ListPicker } from './CharPickers';
import { parseHex } from './ColorEntry';
import {
  byName,
  type SettingsCat,
  SettingsColumns,
  type SettingsRowSpec,
  useSettings,
  VALUE_X,
  WORK_W,
  WORK_X,
} from './SettingsFrame';
import { Check, cut, Field, Put, Slide, Swatch, safe } from './term';
import type { LobbyData, SettingRow } from './types';
import { choicesOf, nameOf, usePrefsCatalog } from './usePrefsCatalog';

/** A choice with more values than this opens the list picker on Enter. */
const HANDFUL = 6;
/** The value's text: from VALUE_X, this many cells beside the row's `<` `>` keys (column 56). */
const VALUE_TEXT_X = VALUE_X;
const VALUE_TEXT_W = 11;
/** A value with no keys beside it runs to the row's end. */
const VALUE_WIDE_W = 18;
/** A choice with a value name longer than this opens the list picker on Enter. */
const PICK_W = 14;
/** A slider's track, with the number in the four cells after it. */
const SLIDE_X = VALUE_X;
const SLIDE_W = 7;
/** The category tg's window puts last here. */
const LAST_CAT = 'ADMIN';

const BASE_INPUTS = new Set<unknown>([
  CheckboxInput,
  CheckboxInputInverse,
  FeatureColorInput,
  FeatureNumberInput,
  FeatureSliderInput,
  FeatureShortTextInput,
  FeatureDropdownInput,
]);

const optionCache: Record<string, [string, string][] | null> = {};

/**
 * [value, label] of a preference tg draws with createDropdownInput, or null. The component is
 * called once, outside React: a plain function returning a Dropdown whose options carry the
 * labels. Anything else (a component with hooks, another shape) gives null.
 */
function dropdownOptions(key: string): [string, string][] | null {
  if (key in optionCache) {
    return optionCache[key];
  }
  let out: [string, string][] | null = null;
  const comp = features[key]?.component as unknown;
  if (typeof comp === 'function' && !BASE_INPUTS.has(comp)) {
    try {
      const el = (comp as (p: object) => any)({
        featureId: key,
        value: undefined,
        serverData: undefined,
        handleSetValue: () => undefined,
      });
      const opts = el?.props?.options;
      if (
        Array.isArray(opts) &&
        opts.length &&
        opts.every(
          (o) =>
            !!o &&
            typeof o === 'object' &&
            'value' in o &&
            typeof o.displayText === 'string',
        )
      ) {
        out = opts.map((o) => [String(o.value), o.displayText]);
      }
    } catch {
      out = null;
    }
  }
  optionCache[key] = out;
  return out;
}

/** What a setting is called, where it goes and what it says, from tg's registry. */
function featureOf(key: string) {
  const f = features[key];
  return {
    name: f?.name || key,
    cat: (f?.category || 'OTHER').toUpperCase(),
    desc: f?.description || '',
  };
}

const upper = (s: string) => safe(s).toUpperCase();

/** A choice row's values and their names (labelled numbers count as choices). */
function choiceSpec(
  cat: ReturnType<typeof usePrefsCatalog>,
  row: SettingRow,
): { list: string[]; name: (v: string) => string } | null {
  const labelled = dropdownOptions(row.key);
  const labels = labelled ? Object.fromEntries(labelled) : null;
  let list: string[] | null = null;
  if (row.kind === 'choice') {
    list = choicesOf(cat, row.key) || row.choices || null;
    if (!list && labelled) {
      list = labelled.map((o) => o[0]);
    }
  } else if (row.kind === 'number' && labelled) {
    list = labelled.map((o) => o[0]);
  }
  if (!list || !list.length) {
    return null;
  }
  return {
    list: list.map(String),
    name: (v) => {
      const shown = nameOf(cat, row.key, v);
      return shown !== v ? shown : (labels?.[v] ?? v);
    },
  };
}

/** What a number row shows: -1 on a preference whose least is -1 is "use the default". */
function numberText(row: SettingRow, v: number) {
  if (row.min === -1 && v === -1) {
    return 'AUTO';
  }
  return String(Math.round(v * 100) / 100);
}

/**
 * A number or text being typed, over the value zone. Enter sends it; leaving the field (Escape,
 * a click elsewhere) drops it.
 */
function TypeIn(props: {
  ty: number;
  start: string;
  max: number;
  numeric: boolean;
  /** Cells for the field. */
  w: number;
  onDone: (text: string | null) => void;
}) {
  const { ty, start, max, numeric, w, onDone } = props;
  const [text, setText] = useState(start);
  const wrap = useRef<HTMLDivElement>(null);
  const done = useRef(false);
  const finish = (value: string | null) => {
    if (!done.current) {
      done.current = true;
      onDone(value);
    }
  };
  useEffect(() => {
    const input = wrap.current?.querySelector('input');
    input?.focus();
    input?.select();
  }, []);
  return (
    <div ref={wrap} onBlur={() => finish(null)}>
      <Field
        x={VALUE_X}
        y={ty - 0.125}
        w={w}
        h={1.25}
        value={text}
        max={max}
        onChange={(v) =>
          setText(numeric ? v.toUpperCase().replace(/[^0-9.\-AUTO]/g, '') : v)
        }
        onEnter={() => finish(text)}
      />
    </div>
  );
}

/** The open setting's row, or null once it is gone (a parent toggle hid it). */
function useSettingRow(k: string) {
  const { data } = useBackend<LobbyData>();
  const { closeSub } = useSettings();
  const row = data.settings?.rows.find((r) => r.key === k) || null;
  const gone = !row;
  useEffect(() => {
    if (gone) {
      closeSub();
    }
  }, [gone]);
  return row;
}

/** Level 2: the list picker on a choice. */
function OptionPick(props: { k: string }) {
  const { k } = props;
  const { act } = useBackend<LobbyData>();
  const cat = usePrefsCatalog();
  const { closeSub } = useSettings();
  const row = useSettingRow(k);
  if (!row) {
    return null;
  }
  const spec = choiceSpec(cat, row);
  const value = String(row.value);
  return (
    <ListPicker
      x={WORK_X}
      w={WORK_W}
      label={upper(featureOf(k).name)}
      choices={spec?.list || []}
      value={value}
      nameOf={(v) => upper(spec ? spec.name(v) : v)}
      onPick={(v) => {
        if (v !== value) {
          act('settings_set', {
            key: k,
            value: row.kind === 'number' ? Number(v) : v,
          });
        }
      }}
      onClose={closeSub}
    />
  );
}

/** Level 2: the colour panel on a colour. */
function OptionColour(props: { k: string }) {
  const { k } = props;
  const { act } = useBackend<LobbyData>();
  const { closeSub } = useSettings();
  const row = useSettingRow(k);
  if (!row) {
    return null;
  }
  return (
    <ColourPanel
      x={WORK_X}
      w={WORK_W}
      label={upper(featureOf(k).name)}
      value={parseHex(String(row.value)) || '#000000'}
      recent={[]}
      onApply={(hex) => act('settings_set', { key: k, value: hex })}
      onClose={closeSub}
    />
  );
}

export function SettingsOptions() {
  const { act, data } = useBackend<LobbyData>();
  const catalog = usePrefsCatalog();
  const { sub, from, setCrumb, home } = useSettings();
  const [open, setOpen] = useState<string | null>(null);
  /** The row being typed in, and the row that gets the focus back after. */
  const [typing, setTyping] = useState<string | null>(null);
  const [back, setBack] = useState<string | null>(null);
  /** A slider being dragged, or let go and waiting for the server's value. */
  const [drag, setDrag] = useState<{
    key: string;
    v: number;
    held: boolean;
  } | null>(null);
  const rev = data.settings?.rev;
  useEffect(() => {
    setDrag((d) => (d && !d.held ? null : d));
  }, [rev]);
  const rows = data.settings?.rows || [];
  const [find, setFind] = useState('');
  const needle = find.trim().toUpperCase();

  const items = rows.map((row) => ({ row, ...featureOf(row.key) }));
  const cats: SettingsCat[] = Array.from(new Set(items.map((it) => it.cat)))
    .sort((a, b) => (a === LAST_CAT ? 1 : b === LAST_CAT ? -1 : byName(a, b)))
    .map((id) => ({ id, label: id }));
  const cat = cats.some((c) => c.id === open) ? open : cats[0]?.id || null;

  useEffect(() => {
    setCrumb(needle ? 'SEARCH' : cat || '');
  }, [cat, needle]);
  useEffect(() => {
    setTyping(null);
    setBack(null);
  }, [cat, home]);

  const set = (key: string, value: unknown) =>
    act('settings_set', { key, value });

  const specs: SettingsRowSpec[] = items
    .filter((it) => (needle ? upper(it.name).includes(needle) : it.cat === cat))
    .sort((a, b) => byName(a.name, b.name))
    .map(({ row, name, desc }) => {
      const key = row.key;
      const NAME = upper(name);
      const base = { key, name: NAME, desc, claim: back === key };
      if (row.locked) {
        const shown = choiceSpec(catalog, row);
        return {
          ...base,
          muted: true,
          value: (ty: number) => (
            <Put x={VALUE_TEXT_X} y={ty} cls="faint">
              {cut(
                upper(
                  shown ? shown.name(String(row.value)) : String(row.value),
                ),
                VALUE_WIDE_W,
              )}
            </Put>
          ),
        };
      }
      const typeIn =
        (
          start: string,
          max: number,
          numeric: boolean,
          send: (t: string) => void,
        ) =>
        (ty: number) => (
          <TypeIn
            ty={ty}
            start={start}
            max={max}
            numeric={numeric}
            w={numeric ? VALUE_TEXT_W : VALUE_WIDE_W}
            onDone={(t) => {
              setTyping(null);
              setBack(key);
              if (t !== null) {
                send(t);
              }
            }}
          />
        );
      switch (row.kind) {
        case 'toggle': {
          const inverse = features[key]?.component === CheckboxInputInverse;
          const on = inverse ? !row.value : !!row.value;
          return {
            ...base,
            onPress: () => set(key, row.value ? 0 : 1),
            value: (ty: number) => <Check x={VALUE_TEXT_X} y={ty} on={on} />,
          };
        }
        case 'choice':
        case 'number': {
          const spec = choiceSpec(catalog, row);
          if (spec) {
            const value = String(row.value);
            const step = (by: number) => {
              const n = spec.list.length;
              const at = spec.list.indexOf(value);
              const next = spec.list[(((at < 0 ? 0 : at + by) % n) + n) % n];
              set(key, row.kind === 'number' ? Number(next) : next);
            };
            return {
              ...base,
              onStep: step,
              onPress:
                spec.list.length > HANDFUL ||
                spec.list.some((c) => upper(spec.name(c)).length > PICK_W)
                  ? () => sub(<OptionPick k={key} />, NAME, key)
                  : () => step(1),
              value: (ty: number) => (
                <Put x={VALUE_TEXT_X} y={ty} pulse={value}>
                  {cut(upper(spec.name(value)), VALUE_TEXT_W)}
                </Put>
              ),
            };
          }
          if (row.kind === 'choice') {
            // No catalog yet: the value alone.
            return {
              ...base,
              value: (ty: number) => (
                <Put x={VALUE_TEXT_X} y={ty} cls="dim">
                  {cut(upper(String(row.value)), VALUE_WIDE_W)}
                </Put>
              ),
            };
          }
          const v = Number(row.value) || 0;
          const lo = row.min ?? 0;
          const hi = row.max ?? 0;
          const st = row.step || 1;
          const step = (by: number) => {
            const next = clamp(Math.round((v + by * st) * 100) / 100, lo, hi);
            if (next !== v) {
              set(key, next);
            }
          };
          const send = (t: string) => {
            if (lo === -1 && t.trim() === 'AUTO') {
              if (v !== -1) {
                set(key, -1);
              }
              return;
            }
            const n = Number(t);
            if (!t.trim() || !Number.isFinite(n)) {
              return;
            }
            const stepped = lo + Math.round((n - lo) / st) * st;
            const next = clamp(Math.round(stepped * 100) / 100, lo, hi);
            if (next !== v) {
              set(key, next);
            }
          };
          // tg draws these as sliders (the volumes): a track the mouse drags, coarse key steps.
          if (features[key]?.component === FeatureSliderInput && hi > lo) {
            const span = hi - lo;
            const snap = (share: number) =>
              clamp(
                Math.round((lo + Math.round((share * span) / st) * st) * 100) /
                  100,
                lo,
                hi,
              );
            const coarse = Math.max(1, Math.round(span / 20 / st));
            const held = drag?.key === key ? drag.v : null;
            const now = held ?? v;
            return {
              ...base,
              onStep: (by: number) => step(by * coarse),
              ends: [now <= lo, now >= hi],
              onPress: () => setTyping(key),
              value:
                typing === key
                  ? typeIn(numberText(row, v), 6, true, send)
                  : (ty: number, focused: boolean) => {
                      const text = numberText(row, now);
                      return (
                        <>
                          <Slide
                            x={SLIDE_X}
                            y={ty}
                            w={SLIDE_W}
                            value={(now - lo) / span}
                            lit={focused}
                            onChange={(share) =>
                              setDrag({ key, v: snap(share), held: true })
                            }
                            onRelease={(share) => {
                              const next = snap(share);
                              setDrag({ key, v: next, held: false });
                              if (next !== v) {
                                set(key, next);
                              } else {
                                setDrag(null);
                              }
                            }}
                          />
                          <Put
                            x={SLIDE_X + SLIDE_W + 4 - Math.min(4, text.length)}
                            y={ty}
                            cls={focused ? 'wht' : ''}
                          >
                            {text.slice(0, 4)}
                          </Put>
                        </>
                      );
                    },
            };
          }
          return {
            ...base,
            onStep: step,
            ends: [v <= lo, v >= hi],
            onPress: () => setTyping(key),
            value:
              typing === key
                ? typeIn(numberText(row, v), 6, true, send)
                : (ty: number) => (
                    <Put x={VALUE_TEXT_X} y={ty} pulse={v}>
                      {cut(numberText(row, v), VALUE_TEXT_W)}
                    </Put>
                  ),
          };
        }
        case 'color': {
          const hex = parseHex(String(row.value)) || '#000000';
          return {
            ...base,
            onPress: () => sub(<OptionColour k={key} />, NAME, key),
            value: (ty: number) => (
              <>
                <Swatch x={VALUE_TEXT_X} y={ty} w={2} hex={hex} />
                <Put x={VALUE_TEXT_X + 3} y={ty} cls="dim" pulse={hex}>
                  {hex.toUpperCase()}
                </Put>
              </>
            ),
          };
        }
        case 'text': {
          const text = String(row.value ?? '');
          return {
            ...base,
            onPress: () => setTyping(key),
            value:
              typing === key
                ? typeIn(
                    text,
                    Math.max(1, (row.max_length || 256) - 1),
                    false,
                    (t) => {
                      if (t !== text) {
                        set(key, t);
                      }
                    },
                  )
                : (ty: number) => (
                    <Put x={VALUE_TEXT_X} y={ty} pulse={text}>
                      {cut(upper(text), VALUE_WIDE_W)}
                    </Put>
                  ),
          };
        }
        default:
          return {
            ...base,
            muted: true,
            value: (ty: number) => (
              <Put x={VALUE_TEXT_X} y={ty} cls="faint">
                {cut(upper(String(row.value ?? '')), VALUE_WIDE_W)}
              </Put>
            ),
          };
      }
    });

  return (
    <SettingsColumns
      cats={cats}
      cat={cat}
      onCat={setOpen}
      rows={specs}
      focusKey={from}
      find={find}
      onFind={setFind}
      typing={typing}
      empty={data.settings ? undefined : 'FETCHING SETTINGS.'}
    />
  );
}
