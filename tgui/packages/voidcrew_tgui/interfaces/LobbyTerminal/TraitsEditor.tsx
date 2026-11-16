/**
 * TRAITS (design 03b section 2): full width, no preview. The list on the left (columns 1 to
 * 31): the filters TAKEN, GOOD, BAD and OTHER, paged trait rows, and under a taken trait one
 * row an option. The panel on the right (33 to 61): points, the focused trait's name, its
 * effect on the points, the reason a press would be refused, and its whole description.
 *
 * Whether a press would go through is worked out with tg's own rules (QuirksPage.tsx: the
 * species list, the cap on good traits, the points, the clash groups) for display only; the
 * server decides and the page redraws on the push. Options are ordinary char_set keys.
 */
import { Fragment, type ReactNode, useEffect, useState } from 'react';
import { useBackend } from 'tgui/backend';
import type { Quirk } from 'tgui/interfaces/PreferencesMenu/types';

import { fileColours } from './BodyEditor';
import { clamp, useChar, useLatePager } from './CharFrame';
import { ColourPanel, ListPicker } from './CharPickers';
import { parseHex } from './ColorEntry';
import { sfx, sfxInstead, useChanged } from './motion';
import {
  Band,
  Big,
  BODY_Y,
  bodyRows,
  cut,
  FlashAt,
  HRule,
  NameLine,
  Pager,
  Put,
  RPut,
  Slab,
  Swatch,
  safe,
  useGrid,
  WipeAt,
  wrapMax,
} from './term';
import type { LobbyData } from './types';
import { choicesOf, nameOf, usePrefsCatalog } from './usePrefsCatalog';

type Filter = 'taken' | 'good' | 'bad' | 'other';
/** Filter, label, text column, block column, block width. */
const FILTERS: [Filter, string, number, number, number][] = [
  ['taken', 'TAKEN', 2, 1, 7],
  ['good', 'GOOD', 10, 9, 6],
  ['bad', 'BAD', 17, 16, 5],
  ['other', 'OTHER', 23, 22, 7],
];

/** The list column. */
const LX = 1;
const LW = 31;
/** The panel. */
const PX = 33;
const PW = 29;

/** Option labels (03b section 2.2). */
const LABELS: Record<string, string> = {
  language: 'LANGUAGE',
  language_speakable: 'SPEAKS IT',
  language_skill: 'FLUENCY',
  csl_strength: 'FLUENCY',
  chipped: 'CHIP',
  paint_color: 'PAINT',
  alcoholic: 'DRINK',
  blindfold_color: 'BLINDFOLD',
  food_allergy: 'ALLERGY',
  hemiplegic: 'SIDE',
  junkie: 'HABIT',
  glasses: 'GLASSES',
  paraplegic: 'LEGS',
  prosthetic: 'LIMB',
  prosthetic_organ: 'ORGAN',
  rds_limit: 'UNLIMITED',
  scarred_eye: 'EYE',
  smoker: 'SMOKES',
  phobia: 'FEAR',
  trans_prosthetic: 'PART',
  heterochromatic: 'ODD EYE',
};

export const optionLabel = (key: string) =>
  LABELS[key] || key.replace(/_/g, ' ').toUpperCase().slice(0, 9);

/** A trait's option keys that this file has (plus Heterochromatic's second eye colour). */
function optionsOf(k: string, q: Quirk, prefs: Record<string, any>) {
  const keys = [...(q.customization_options || [])];
  if (k === 'Heterochromatic' && !keys.includes('heterochromatic')) {
    keys.push('heterochromatic');
  }
  return keys.filter((key) => key in prefs);
}

type OptKind = 'pick' | 'flip' | 'colour' | 'none';

function kindOf(cat: ReturnType<typeof usePrefsCatalog>, key: string, value: unknown): OptKind {
  const list = choicesOf(cat, key);
  if (list && list.length >= 3) {
    return 'pick';
  }
  if (list && list.length === 2) {
    return 'flip';
  }
  if (typeof value === 'string' && parseHex(value)) {
    return 'colour';
  }
  if (typeof value === 'number' || typeof value === 'boolean') {
    return 'flip';
  }
  return 'none';
}

/** The list picker on a trait option (level 2, in the list column). */
function TraitPick(props: { k: string; label: string }) {
  const { k, label } = props;
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
  return (
    <ListPicker
      x={LX}
      w={LW}
      label={label}
      choices={choicesOf(cat, k) || []}
      value={String(prefs[k] ?? '')}
      nameOf={(v) => nameOf(cat, k, v)}
      onPick={(v) => act('char_set', { key: k, value: v })}
      onClose={closeSub}
    />
  );
}

/** The colour panel on a trait option (level 2, in the list column, no native picker). */
function TraitColour(props: { k: string; label: string }) {
  const { k, label } = props;
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
      x={LX}
      w={LW}
      label={label}
      value={parseHex(String(prefs[k] ?? '')) || '#000000'}
      recent={fileColours(char)}
      onApply={(hex) => act('char_set', { key: k, value: hex })}
      onClose={closeSub}
    />
  );
}

/** One drawn block of the list: a trait and its option rows. */
type Block = { k: string; opts: string[] };

export function TraitsEditor() {
  const { act, data } = useBackend<LobbyData>();
  const cat = usePrefsCatalog();
  const { sub, subOpen, from, quiet } = useChar();
  const { rows: M } = useGrid();
  const char = data.char;
  const takenAtOpen = (char?.quirks || []).length > 0;
  const [filter, setFilter] = useState<Filter>(takenAtOpen ? 'taken' : 'good');
  const [page, setPage] = useState(0);
  const [shown, setShown] = useState<string | null>(null);
  const [fresh, setFresh] = useState(true);
  /** Presses the rules refused: each one draws the reason again. */
  const [refused, setRefused] = useState(0);
  const pager = useLatePager();
  // A trait was taken: the accepted sound (its row flashes below).
  useChanged((char?.quirks || []).length, (was, now) => {
    if (now > was) {
      sfx('ok', { own: true });
    }
  });

  if (!char || !cat?.quirks) {
    pager.current = null;
    return null;
  }
  const prefs = char.prefs || {};
  const {
    quirk_info: info,
    max_positive_quirks: maxGood,
    quirk_blacklist: blacklist,
    points_enabled: pointsOnRaw,
  } = cat.quirks;
  const pointsOn = !!pointsOnRaw;

  // char.quirks are quirk_info keys (sanitize_css_class_name), in the order taken.
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
  const species = safe(nameOf(cat, 'species', prefs.species)).toUpperCase();

  /** Why a press on this trait would be refused, or null. */
  const reasonOf = (k: string): string | null => {
    const q = info[k];
    if (taken.includes(k)) {
      return pointsOn && balance - q.value > 0 ? 'ITS POINTS ARE SPENT' : null;
    }
    if (blocked.includes(k) || blocked.includes(q.name)) {
      return `${species || 'YOUR SPECIES'} CAN'T TAKE IT`;
    }
    if (q.value > 0 && maxGood !== -1 && good >= maxGood) {
      return `${maxGood} GOOD TRAITS ALREADY`;
    }
    if (q.value > 0 && pointsOn && balance + q.value > 0) {
      return 'NOT ENOUGH POINTS';
    }
    for (const group of blacklist || []) {
      if (!group.includes(q.name)) {
        continue;
      }
      const other = group.find((n) => n !== q.name && takenNames.includes(n));
      if (other) {
        return `CLASHES WITH ${safe(other).toUpperCase()}`;
      }
    }
    return null;
  };

  const press = (k: string) => {
    setShown(k);
    if (reasonOf(k)) {
      // Refused: the reason draws itself in the panel, with the refusal sound.
      sfxInstead('warn');
      setRefused((n) => n + 1);
      return;
    }
    act('char_quirk', { quirk: k, on: taken.includes(k) ? 0 : 1 });
  };

  // ---- the list
  let keys: string[];
  if (filter === 'taken') {
    keys = taken;
  } else {
    keys = Object.keys(info).filter((k) => {
      const v = info[k].value;
      return filter === 'good' ? v > 0 : filter === 'bad' ? v < 0 : v === 0;
    });
    keys.sort((a, b) => {
      const va = Math.abs(info[a].value);
      const vb = Math.abs(info[b].value);
      if (va !== vb) {
        return vb - va;
      }
      return info[a].name < info[b].name ? -1 : 1;
    });
  }
  const blocks: Block[] = keys.map((k) => ({
    k,
    opts: taken.includes(k) ? optionsOf(k, info[k], prefs) : [],
  }));

  const B = bodyRows(M);
  const roomy = B >= 20;
  const pitch = roomy ? 1.5 : 1.25;
  const gap = pitch - 1.25;
  const sizeOf = (b: Block) => (1 + b.opts.length) * 1.25 + gap;
  const fill = (room: number) => {
    const pages: Block[][] = [[]];
    let used = 0;
    for (const b of blocks) {
      const s = sizeOf(b);
      if (used + s > room + 1e-6 && pages[pages.length - 1].length) {
        pages.push([]);
        used = 0;
      }
      pages[pages.length - 1].push(b);
      used += s;
    }
    return pages;
  };
  const listTop = 5.25;
  let pages = fill(M - 1.25 - listTop + gap);
  if (pages.length > 1) {
    pages = fill(M - 2.25 - 0.25 - listTop + gap);
  }
  const pg = Math.min(page, pages.length - 1);
  const onPage = pages[pg] || [];
  pager.current =
    pages.length > 1 && !subOpen
      ? (step) => {
          setFresh(false);
          setPage(clamp(pg + step, 0, pages.length - 1));
        }
      : null;

  // The panel shows the focused row; on entry the first row.
  const panelKey =
    shown && info[shown] ? shown : onPage[0]?.k || keys[0] || null;

  const rows: ReactNode[] = [];
  let y = listTop;
  onPage.forEach((b, i) => {
    const q = info[b.k];
    const isTaken = taken.includes(b.k);
    const reason = reasonOf(b.k);
    const alt = !roomy && i % 2 === 1;
    const v = q.value;
    const blockY = y;
    rows.push(
      <Slab
        key={b.k}
        x={LX}
        y={blockY}
        w={LW}
        h={1.25}
        variant="row"
        alt={alt}
        on={isTaken}
        muted={!isTaken && !!reason}
        auto={!quiet && fresh && !from && i === 0 && pg === 0 ? 5 : undefined}
        onFocus={(f) => {
          if (f) {
            setShown(b.k);
          }
        }}
        onClick={() => press(b.k)}
      >
        <Put
          x={3}
          y={blockY + 0.125}
          cls={isTaken ? 'wht' : reason ? 'dim' : ''}
        >
          {cut(safe(q.name), 24)}
        </Put>
        {!!pointsOn && v !== 0 && (
          <RPut
            x={31}
            y={blockY + 0.125}
            cls={reason && !isTaken ? 'dim' : v > 0 ? 'amb' : ''}
          >
            {v > 0 ? `-${v}` : `+${-v}`}
          </RPut>
        )}
      </Slab>,
      // The row flashes when it is taken, dropped, or loses its mark to another trait.
      <FlashAt
        key={`f${b.k}`}
        x={LX}
        y={blockY}
        w={LW}
        h={1.25}
        k={isTaken}
      />,
    );
    b.opts.forEach((key, j) => {
      const oy = blockY + 1.25 * (j + 1);
      const value = prefs[key];
      const kind = kindOf(cat, key, value);
      const label = optionLabel(key);
      const list = choicesOf(cat, key) || [];
      let onPress: (() => void) | undefined;
      let shownValue: ReactNode = null;
      if (kind === 'pick') {
        onPress = () => sub(<TraitPick k={key} label={label} />, label, key);
        shownValue = (
          <Put x={15} y={oy + 0.125} pulse={String(value)}>
            {cut(safe(nameOf(cat, key, value)), 16)}
          </Put>
        );
      } else if (kind === 'flip') {
        onPress = () => {
          if (list.length === 2) {
            act('char_set', {
              key,
              value: list[list.indexOf(String(value)) === 0 ? 1 : 0],
            });
          } else {
            act('char_set', { key, value: value ? 0 : 1 });
          }
        };
        shownValue = (
          <Put x={15} y={oy + 0.125} pulse={String(value)}>
            {list.length === 2
              ? cut(safe(nameOf(cat, key, value)), 16)
              : value
                ? 'YES'
                : 'NO'}
          </Put>
        );
      } else if (kind === 'colour') {
        const hex = parseHex(String(value)) || '#000000';
        onPress = () => sub(<TraitColour k={key} label={label} />, label, key);
        shownValue = (
          <>
            <Swatch x={15} y={oy + 0.125} w={4} hex={hex} />
            <Put x={20} y={oy + 0.125} cls="dim" pulse={hex}>
              {hex.toUpperCase()}
            </Put>
          </>
        );
      } else {
        shownValue = (
          <Put x={15} y={oy + 0.125} cls="dim">
            {cut(safe(String(value ?? '')), 16)}
          </Put>
        );
      }
      rows.push(
        <Slab
          key={`${b.k}-${key}`}
          x={LX}
          y={oy}
          w={LW}
          h={1.25}
          variant="row"
          alt={alt}
          on={isTaken}
          auto={!quiet && from === key ? 5 : undefined}
          onFocus={(f) => {
            if (f) {
              setShown(b.k);
            }
          }}
          onClick={onPress}
        >
          <Put x={5} y={oy + 0.125} cls="dim">
            {label}
          </Put>
          {shownValue}
        </Slab>,
      );
    });
    y += sizeOf(b);
  });

  // ---- the panel
  const capped = maxGood !== -1 && good >= maxGood;
  const goodText =
    maxGood === 0 ? '' : maxGood === -1 ? `GOOD ${good}` : `GOOD ${good}/${maxGood}`;
  const pq = panelKey ? info[panelKey] : null;
  const pv = pq?.value || 0;
  const panelReason = panelKey ? reasonOf(panelKey) : null;
  const descLines = pq
    ? wrapMax(
        safe(pq.description).replace(/\s+/g, ' ').trim(),
        PW,
        Math.max(1, Math.floor(M - 11)),
      )
    : [];
  const panel = (
    <>
      {!!pointsOn && (
        <>
          <Big
            x={PX}
            y={3}
            scale={2.25}
            cls={points > 0 ? 'acc' : 'dim'}
            pulse={points}
          >
            {String(Math.min(999, points))}
          </Big>
          <Put x={41} y={3.25} cls="dim">
            {'POINTS'}
          </Put>
        </>
      )}
      {!!goodText && (
        <Put
          x={pointsOn ? 41 : PX}
          y={pointsOn ? 4.25 : 3.25}
          cls={capped ? 'amb' : 'dim'}
          pulse={good}
        >
          {goodText}
        </Put>
      )}
      <HRule x={PX} y={5.5} w={PW} />
      {!!pq && (
        <>
          <NameLine x={PX} y={6} w={PW} text={safe(pq.name).toUpperCase()} />
          {!!pointsOn && pv !== 0 && (
            <Put x={PX} y={7.5} cls={pv > 0 ? 'amb' : ''}>
              {pv > 0 ? `-${pv} POINTS` : `+${-pv} POINTS`}
            </Put>
          )}
          {!!taken.includes(panelKey!) && (
            <RPut x={62} y={7.5} cls="inv">
              {' TAKEN '}
            </RPut>
          )}
          {!!panelReason && (
            <Put x={PX} y={8.5} cls="amb">
              {cut(panelReason, PW)}
            </Put>
          )}
          <WipeAt kind="draw" x={PX} y={8.5} w={PW} h={1} k={refused} />
          {descLines.map((line, i) => (
            <Put key={i} x={PX} y={9.75 + i}>
              {line}
            </Put>
          ))}
        </>
      )}
    </>
  );

  if (subOpen) {
    return panel;
  }

  return (
    <>
      {FILTERS.map(([f, label, tx, bx, bw]) => {
        const open = f === filter;
        return (
          <Fragment key={f}>
            {!!open && <Band x={bx} y={BODY_Y} w={bw} h={1.5} tone="accent" />}
            <Put
              x={tx}
              y={3.25}
              cls={open ? 'ink' : 'dim'}
              hoverCls={open ? 'ink' : 'inv'}
              onClick={() => {
                if (f !== filter) {
                  setFresh(false);
                  setFilter(f);
                  setPage(0);
                }
              }}
            >
              {label}
            </Put>
          </Fragment>
        );
      })}
      <HRule x={LX} y={4.75} w={LW} />
      {keys.length ? (
        rows
      ) : (
        <>
          <Slab x={LX} y={5.25} w={LW} h={4.75} variant="block" dead />
          <NameLine
            x={3}
            y={5.25 + 1.75}
            w={27}
            text="NO TRAITS TAKEN."
            cls="dim"
          />
        </>
      )}
      <Pager
        x={32}
        y={M - 2.25}
        page={pg + 1}
        pages={pages.length}
        onPage={(p) => {
          setFresh(false);
          setPage(p - 1);
        }}
        right
      />
      {/* Another filter, or another page, turns the page of the rows only. */}
      <WipeAt
        x={LX}
        y={listTop}
        w={LW}
        h={M - 2.5 - listTop}
        k={`${filter}:${pg}`}
        n={FILTERS.findIndex((f) => f[0] === filter) * 1000 + pg}
      />
      {panel}
    </>
  );
}
