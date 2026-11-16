/**
 * KIT (design 03b section 3): tg's stock loadout. The ID column lists PACKED and tg's
 * categories under the preview; the work column lists the open one's items, each with its own
 * picture. A packed item has one row an option under it: COLOUR (one a slot, through the shared
 * colour panel), STYLE (reskins), NAME (renaming), WORN (an accessory over or under the suit)
 * and LIPS (where the lipstick sits). Nothing here has a price.
 *
 * A press packs or unpacks at once from a local copy with tg's rule (one item a category, two
 * in Other, the oldest pick goes); the next push replaces the copy.
 */
import { type ReactNode, useEffect, useState } from 'react';
import { useBackend } from 'tgui/backend';
import type {
  LoadoutCategory,
  LoadoutItem,
} from 'tgui/interfaces/PreferencesMenu/CharacterPreferences/loadout/base';

import { fileColours } from './BodyEditor';
import {
  clamp,
  ID_W,
  ID_X,
  IdColumn,
  perPage,
  planId,
  q,
  useChar,
  WORK_W,
  WORK_X,
} from './CharFrame';
import { ColourPanel, ListPicker } from './CharPickers';
import { ItemPic } from './ItemPic';
import {
  BODY_Y,
  bodyRows,
  cut,
  Field,
  Key,
  NameLine,
  Pager,
  Put,
  RPut,
  Slab,
  Swatch,
  safe,
  useGrid,
  wrapMax,
} from './term';
import {
  type CellBox,
  type CharKitItem,
  KIT_NAME_MAX,
  type LobbyData,
} from './types';
import { decodeName, usePrefsCatalog } from './usePrefsCatalog';

type Kit = Record<string, CharKitItem>;

/** The category whose items stay at two (tg: /datum/loadout_category/pocket). */
const TWO_ALLOWED = 'Other';
const LIPS = ['Upper', 'Middle', 'Lower'] as const;
type Lip = (typeof LIPS)[number];

/** The colours of a packed item, one a slot, "#rrggbb". */
function slotColors(item: CharKitItem | undefined, slots: number): string[] {
  const found = (item?.greyscale || '').match(/#[0-9a-f]{6}/gi) || [];
  const out: string[] = [];
  for (let i = 0; i < slots; i++) {
    out.push((found[i] || '#ffffff').toLowerCase());
  }
  return out;
}

/** One option row under a packed item. */
type Opt =
  | { kind: 'colour'; slot: number; slots: number }
  | { kind: 'style' }
  | { kind: 'name' }
  | { kind: 'worn' }
  | { kind: 'lips' };

function optionsOf(item: LoadoutItem, slots: number): Opt[] {
  const out: Opt[] = [];
  for (let s = 0; s < slots; s++) {
    out.push({ kind: 'colour', slot: s, slots });
  }
  if (item.reskins?.length) {
    out.push({ kind: 'style' });
  }
  const acts = (item.buttons || []).map((b) => b.act_key);
  if (acts.includes('set_name')) {
    out.push({ kind: 'name' });
  }
  if (acts.includes('set_layer')) {
    out.push({ kind: 'worn' });
  }
  if (acts.includes('select_lipstick_style')) {
    out.push({ kind: 'lips' });
  }
  return out;
}

const optKey = (path: string, o: Opt) =>
  `${path}#${o.kind}${o.kind === 'colour' ? o.slot : ''}`;

/** The skin shown for an item: the stored one, else the one matching its icon, else the first. */
function skinOf(item: LoadoutItem, stored?: string) {
  const skins = item.reskins || [];
  return (
    skins.find((s) => s.name === stored) ||
    skins.find((s) => s.skin_icon_state === item.icon_state) ||
    skins[0]
  );
}

// ---------------------------------------------------------------------------
// Level 2 screens. Each reads live data, so the frame can keep the element as it was opened.

/** Closes the level-2 screen when its item is unpacked (here or in tg's window). */
function useGoneClose(path: string) {
  const { data } = useBackend<LobbyData>();
  const { closeSub } = useChar();
  const gone = !(path in (data.char?.kit || {}));
  useEffect(() => {
    if (gone) {
      closeSub();
    }
  }, [gone]);
}

function KitColour(props: { path: string; slot: number; slots: number; label: string }) {
  const { path, slot, slots, label } = props;
  const { act, data } = useBackend<LobbyData>();
  const { closeSub } = useChar();
  useGoneClose(path);
  const char = data.char;
  const kit = char?.kit || {};
  const kitColors = data.char_static?.kit_colors || {};
  const recent = [
    ...fileColours(char),
    ...Object.keys(kit).flatMap((p) => slotColors(kit[p], kitColors[p] || 0)),
  ].filter((c, i, all) => all.indexOf(c) === i);
  return (
    <ColourPanel
      x={WORK_X}
      w={WORK_W}
      label={label}
      value={slotColors(kit[path], slots)[slot]}
      recent={recent}
      onApply={(color) => act('char_kit_color', { path, slot, color })}
      onClose={closeSub}
    />
  );
}

function KitStyle(props: { item: LoadoutItem }) {
  const { item } = props;
  const { act, data } = useBackend<LobbyData>();
  const { closeSub } = useChar();
  useGoneClose(item.path);
  const skins = item.reskins || [];
  const current = skinOf(item, data.char?.kit?.[item.path]?.reskin);
  return (
    <ListPicker
      x={WORK_X}
      w={WORK_W}
      label="STYLE"
      choices={skins.map((s) => s.name)}
      value={current?.name || ''}
      nameOf={(v) => v}
      onPick={(skin) => act('char_kit_skin', { path: item.path, skin })}
      onClose={closeSub}
    />
  );
}

/** NAME: typing; Enter or leaving the field submits; empty clears. */
function NameField(props: { path: string; y: number; h: number; auto?: number }) {
  const { path, y, h } = props;
  const { act, data } = useBackend<LobbyData>();
  const stored = decodeName(data.char?.kit?.[path]?.name || '');
  const [text, setText] = useState(stored);
  const [typing, setTyping] = useState(false);
  useEffect(() => {
    if (!typing) {
      setText(stored);
    }
  }, [stored]);
  const commit = () => {
    const next = text.trim();
    if (next !== stored) {
      // The server decides: a refused name comes back as a notice and the old name.
      act('char_kit_name', { path, name: next });
    } else {
      setText(stored);
    }
  };
  return (
    <div
      onFocus={() => setTyping(true)}
      onBlur={() => {
        setTyping(false);
        commit();
      }}
    >
      <Field
        x={41}
        y={y}
        w={20}
        h={h}
        value={text}
        max={KIT_NAME_MAX}
        auto={props.auto}
        onChange={setText}
        onEnter={commit}
      />
    </div>
  );
}

// ---------------------------------------------------------------------------

/** One drawn piece of the item list. */
type Line =
  | { kind: 'group'; text: string; first: boolean }
  | { kind: 'item'; item: LoadoutItem; opts: Opt[] };

export function KitEditor(_props: Partial<CellBox>) {
  const { act, data } = useBackend<LobbyData>();
  const catalog = usePrefsCatalog();
  const { sub, subOpen, from, quiet } = useChar();
  const { rows: M, ch } = useGrid();
  const char = data.char;
  const kitColors = data.char_static?.kit_colors || {};
  // Local copy after a press, dropped on the next push (a refused edit pushes too).
  const [local, setLocal] = useState<Kit | null>(null);
  useEffect(() => setLocal(null), [char]);
  const kit: Kit = local || char?.kit || {};
  const packedAtOpen = Object.keys(char?.kit || {}).length > 0;
  /** -1 is PACKED, else a tab index. */
  const [open, setOpen] = useState(packedAtOpen ? -1 : 0);
  const [page, setPage] = useState(0);
  const [catPage, setCatPage] = useState<number | null>(null);
  const [fresh, setFresh] = useState(true);

  const tabs: LoadoutCategory[] = catalog?.loadout?.loadout_tabs || [];
  if (!char || !tabs.length) {
    return null;
  }
  const tabOf = (path: string) =>
    tabs.find((t) => t.contents.some((it) => it.path === path));
  const itemOf = (path: string) =>
    tabOf(path)?.contents.find((it) => it.path === path);

  const toggle = (item: LoadoutItem) => {
    const on = !(item.path in kit);
    const next: Kit = { ...kit };
    if (on) {
      const tab = tabOf(item.path);
      const same = Object.keys(next).filter(
        (p) => p !== item.path && !!tab?.contents.some((it) => it.path === p),
      );
      const limit = tab?.name === TWO_ALLOWED ? 2 : 1;
      while (same.length >= limit) {
        delete next[same.shift() as string];
      }
      next[item.path] = {};
    } else {
      delete next[item.path];
    }
    setLocal(next);
    act('char_kit', { path: item.path, on: on ? 1 : 0 });
  };

  // ---- ID column: PACKED and the categories, bottom-anchored (paged when short).
  const entries: [label: string, count: number][] = [
    ['PACKED', Object.keys(kit).length],
    ...tabs.map(
      (t) =>
        [
          t.name,
          Object.keys(kit).filter((p) => t.contents.some((it) => it.path === p))
            .length,
        ] as [string, number],
    ),
  ];
  const c = entries.length;
  let gh = 1.25;
  let paged = false;
  let per = c;
  const plan = planId(M, 1.5 * c - 0.25, (la) => {
    const h = clamp(q((la + 0.25) / c - 0.25), 1.25, 2);
    const used = c * (h + 0.25) - 0.25;
    if (used > la + 1e-6) {
      paged = true;
      per = perPage(la, 0);
      return la;
    }
    gh = h;
    return used;
  });
  const catPages = paged ? Math.ceil(c / per) : 1;
  const openPage = Math.floor((open + 1) / per);
  const cpg = Math.min(catPage ?? openPage, catPages - 1);
  const catTop = paged ? BODY_Y + plan.pv + 2.25 : plan.top;
  const idList: ReactNode[] = entries
    .map((e, i) => [e, i] as [[string, number], number])
    .slice(cpg * per, cpg * per + per)
    .map(([[label, count], i], k) => {
      const y = catTop + k * (gh + 0.25);
      const idx = i - 1;
      return (
        <Slab
          key={label}
          x={ID_X}
          y={y}
          w={ID_W}
          h={gh}
          variant="row"
          alt={k % 2 === 1}
          on={idx === open}
          onClick={() => {
            if (idx !== open) {
              setFresh(false);
              setOpen(idx);
              setPage(0);
            }
          }}
        >
          <Put x={3} y={y + (gh - 1) / 2} cls={idx === open ? 'wht' : ''}>
            {cut(safe(label).toUpperCase(), 15)}
          </Put>
          {count > 0 && (
            <RPut x={21} y={y + (gh - 1) / 2} cls="acc">
              {String(count)}
            </RPut>
          )}
        </Slab>
      );
    });
  if (paged) {
    idList.push(
      <Pager
        key="catpager"
        x={ID_X + ID_W}
        y={M - 2.25}
        page={cpg + 1}
        pages={catPages}
        onPage={(p) => setCatPage(p - 1)}
        right
      />,
    );
  }

  if (subOpen) {
    return <IdColumn pv={plan.pv}>{idList}</IdColumn>;
  }

  // ---- work column: the items
  const B = bodyRows(M);
  const roomy = B >= 20;
  const ih = roomy ? 2.25 : 1.25;
  const oh = roomy ? 1.5 : 1.25;
  const gap = roomy ? 0.25 : 0;

  let items: LoadoutItem[];
  let multi = false;
  if (open < 0) {
    items = Object.keys(kit)
      .map((p) => itemOf(p))
      .filter((it): it is LoadoutItem => !!it);
  } else {
    const tab = tabs[Math.min(open, tabs.length - 1)];
    const order: string[] = [];
    for (const it of tab.contents) {
      const g = it.group || tab.name;
      if (!order.includes(g)) {
        order.push(g);
      }
    }
    multi = order.length > 1;
    items = [...tab.contents].sort(
      (a, b) =>
        order.indexOf(a.group || tab.name) - order.indexOf(b.group || tab.name),
    );
  }
  const groupOf = (it: LoadoutItem) => it.group || '';
  const blockSize = (it: LoadoutItem) =>
    ih + (it.path in kit ? optionsOf(it, kitColors[it.path] || 0).length : 0) * oh;

  // Pages hold whole items with their option rows; a page that opens inside a group repeats its head.
  const layout = (room: number) => {
    const pages: Line[][] = [[]];
    let used = 0;
    let group: string | null = null;
    for (const it of items) {
      const opts = it.path in kit ? optionsOf(it, kitColors[it.path] || 0) : [];
      const cur = pages[pages.length - 1];
      const g = groupOf(it);
      const newGroup = multi && g !== group;
      // A group head is one row with 0.25 above it unless it starts the page; items are `gap` apart.
      const need =
        (newGroup ? (cur.length ? 1.25 : 1) : cur.length ? gap : 0) +
        blockSize(it);
      if (cur.length && used + need > room + 1e-6) {
        const next: Line[] = [];
        if (multi) {
          next.push({ kind: 'group', text: g, first: true });
        }
        next.push({ kind: 'item', item: it, opts });
        pages.push(next);
        used = (multi ? 1 : 0) + blockSize(it);
      } else {
        if (newGroup) {
          cur.push({ kind: 'group', text: g, first: !cur.length });
        }
        cur.push({ kind: 'item', item: it, opts });
        used += need;
      }
      group = g;
    }
    return pages;
  };
  let pages = layout(B);
  if (pages.length > 1) {
    pages = layout(B - 1.25);
  }
  const pg = Math.min(page, pages.length - 1);
  const lines = pages[pg] || [];

  const rows: ReactNode[] = [];
  let y = BODY_Y;
  let firstItem = true;
  lines.forEach((line, i) => {
    if (line.kind === 'group') {
      if (!line.first) {
        y += 0.25;
      }
      rows.push(
        <Put key={`g${i}`} x={WORK_X} y={y} cls="dim">
          {cut(safe(line.text).toUpperCase(), WORK_W)}
        </Put>,
      );
      y += 1;
      return;
    }
    const { item, opts } = line;
    if (i > 0 && lines[i - 1].kind === 'item') {
      y += gap;
    }
    const packed = item.path in kit;
    const iy = y;
    const name = safe(item.name);
    const nameLines = roomy ? wrapMax(name, 26, 2) : [cut(name, 32)];
    const ty = iy + (ih - nameLines.length) / 2;
    rows.push(
      <Slab
        key={item.path}
        x={WORK_X}
        y={iy}
        w={WORK_W}
        h={ih}
        variant="row"
        alt={!roomy && i % 2 === 1}
        on={packed}
        auto={!quiet && fresh && !from && firstItem && pg === 0 ? 5 : undefined}
        onClick={() => toggle(item)}
      >
        {!!roomy && !!item.icon && !!item.icon_state && (
          <ItemPic
            x={25}
            y={iy}
            w={5}
            h={ih}
            icon={item.icon}
            icon_state={item.icon_state}
            scale={Math.max(1, Math.floor((ih * ch) / 32))}
          />
        )}
        {nameLines.map((l, j) => (
          <Put key={j} x={roomy ? 31 : 25} y={ty + j} cls={packed ? 'wht' : ''}>
            {l}
          </Put>
        ))}
        <Put x={58} y={iy + (ih - 1) / 2} cls={packed ? 'acc' : 'dim'}>
          {packed ? '[#]' : '[ ]'}
        </Put>
      </Slab>,
    );
    firstItem = false;
    y += ih;
    opts.forEach((o) => {
      const oy = y;
      const k = optKey(item.path, o);
      const ty2 = oy + (oh - 1) / 2;
      const auto = !quiet && from === k ? 5 : undefined;
      let label = '';
      let onPress: (() => void) | undefined;
      let value: ReactNode = null;
      const entry = kit[item.path] || {};
      switch (o.kind) {
        case 'colour': {
          label = o.slots > 1 ? `COLOUR ${o.slot + 1}` : 'COLOUR';
          const hex = slotColors(entry, o.slots)[o.slot];
          const lbl = label;
          onPress = () =>
            sub(
              <KitColour path={item.path} slot={o.slot} slots={o.slots} label={lbl} />,
              lbl,
              k,
            );
          value = (
            <>
              <Swatch x={41} y={ty2} w={4} hex={hex} />
              <Put x={46} y={ty2} cls="dim">
                {hex.toUpperCase()}
              </Put>
            </>
          );
          break;
        }
        case 'style': {
          label = 'STYLE';
          const skins = item.reskins || [];
          const cur = skinOf(item, entry.reskin);
          const step = (by: number) => {
            const n = skins.length;
            const at = Math.max(0, skins.indexOf(cur!));
            act('char_kit_skin', {
              path: item.path,
              skin: skins[(((at + by) % n) + n) % n].name,
            });
          };
          onPress = () => sub(<KitStyle item={item} />, 'STYLE', k);
          value = (
            <>
              <Put x={41} y={ty2}>
                {cut(safe(cur?.name || ''), 14)}
              </Put>
              <Key x={56} y={oy} w={3} h={oh} kind="cap" label="<" mouseOnly onClick={() => step(-1)} />
              <Key x={59} y={oy} w={3} h={oh} kind="cap" label=">" mouseOnly onClick={() => step(1)} />
            </>
          );
          break;
        }
        case 'name':
          label = 'NAME';
          value = <NameField path={item.path} y={oy} h={oh} auto={auto} />;
          break;
        case 'worn': {
          label = 'WORN';
          const over = entry.layer === 1 || (entry.layer as unknown) === true;
          onPress = () => act('char_kit_layer', { path: item.path });
          value = <Put x={41} y={ty2}>{over ? 'OVER SUIT' : 'UNDER SUIT'}</Put>;
          break;
        }
        case 'lips': {
          label = 'LIPS';
          const curLip: Lip = (LIPS as readonly string[]).includes(String(entry.layer))
            ? (entry.layer as Lip)
            : 'Middle';
          onPress = () =>
            act('char_kit_lip', {
              path: item.path,
              style: LIPS[(LIPS.indexOf(curLip) + 1) % LIPS.length],
            });
          value = <Put x={41} y={ty2}>{curLip.toUpperCase()}</Put>;
          break;
        }
      }
      rows.push(
        <Slab
          key={k}
          x={WORK_X}
          y={oy}
          w={WORK_W}
          h={oh}
          variant="row"
          alt={!roomy && i % 2 === 1}
          on
          auto={o.kind === 'name' ? undefined : auto}
          onClick={onPress}
        >
          <Put x={31} y={ty2} cls="dim">
            {label}
          </Put>
          {value}
        </Slab>,
      );
      y += oh;
    });
  });

  const empty = open < 0 && !items.length;
  return (
    <>
      <IdColumn pv={plan.pv}>{idList}</IdColumn>
      {empty ? (
        <>
          <Slab x={WORK_X} y={BODY_Y} w={WORK_W} h={4.75} variant="block" dead />
          <NameLine
            x={WORK_X + 2}
            y={BODY_Y + 1.75}
            w={35}
            text="NOTHING PACKED."
            cls="dim"
          />
        </>
      ) : (
        rows
      )}
      <Pager
        x={62}
        y={M - 2.25}
        page={pg + 1}
        pages={pages.length}
        onPage={(p) => {
          setFresh(false);
          setPage(p - 1);
        }}
        right
      />
    </>
  );
}
