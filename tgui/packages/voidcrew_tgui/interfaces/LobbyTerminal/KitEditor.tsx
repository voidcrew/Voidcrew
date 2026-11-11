/**
 * KIT (CHARACTER-PLAN 2.8): tg's loadout categories and items, char_kit. A packed item
 * shows its options under it: one ColorEntry per GAGS colour slot (char_kit_color), a
 * STYLE cycler for reskins (char_kit_skin) and a NAME field where tg allows renaming
 * (char_kit_name). Nothing here has a price. Owner: C4.
 *
 * Box: x and w are the editor frame's outer columns, y the row under its top line,
 * y + h - 1 its bottom line.
 */
import { useEffect, useState } from 'react';
import { useBackend } from 'tgui/backend';
import type {
  LoadoutCategory,
  LoadoutItem,
} from 'tgui/interfaces/PreferencesMenu/CharacterPreferences/loadout/base';

import { ColorEntry } from './ColorEntry';
import { fileColors } from './TraitsEditor';
import {
  Btn,
  Cycler,
  Field,
  Frame,
  Hit,
  Put,
  pad,
  Swatch,
  useGrid,
} from './term';
import {
  type CellBox,
  type CharKitItem,
  KIT_NAME_MAX,
  type LobbyData,
} from './types';
import { usePrefsCatalog } from './usePrefsCatalog';

type Kit = Record<string, CharKitItem>;

/** Category column width. */
const CAT_W = 13;
/** PACKED box width on wide screens. */
const PACK_W = 30;
/** Label column of the option rows under a packed item. */
const OPT_W = 9;
/** Names the server takes for a kit item (empty clears). */
const NAME_OK = /^[\x20-\x7e]*$/;
const NAME_BAD = /[<>/\\]/;
/** The category whose items stay at two (tg: /datum/loadout_category/pocket). */
const TWO_ALLOWED = 'Other';

/** The colours of a packed item, one per slot, "#rrggbb". */
function slotColors(item: CharKitItem | undefined, slots: number): string[] {
  const found = (item?.greyscale || '').match(/#[0-9a-f]{6}/gi) || [];
  const out: string[] = [];
  for (let i = 0; i < slots; i++) {
    out.push((found[i] || '#ffffff').toLowerCase());
  }
  return out;
}

/** The server stores names html-escaped; show them as typed. */
function unescapeName(text: string): string {
  return text
    .replace(/&#(\d+);/g, (_, n) => String.fromCharCode(Number(n)))
    .replace(/&#x([0-9a-f]+);/gi, (_, n) =>
      String.fromCharCode(parseInt(n, 16)),
    )
    .replace(/&quot;/g, '"')
    .replace(/&lt;/g, '<')
    .replace(/&gt;/g, '>')
    .replace(/&amp;/g, '&');
}

/** One drawn line of the item list. */
type Line =
  | { kind: 'group'; text: string }
  | { kind: 'item'; item: LoadoutItem }
  | { kind: 'color'; item: LoadoutItem; slot: number; slots: number }
  | { kind: 'skin'; item: LoadoutItem }
  | { kind: 'name'; item: LoadoutItem }
  | { kind: 'gap' };

export function KitEditor(props: CellBox) {
  const { x, y, w, h } = props;
  const { act, data } = useBackend<LobbyData>();
  const { narrow } = useGrid();
  const catalog = usePrefsCatalog();
  const char = data.char;
  const kitColors = data.char_static?.kit_colors || {};
  const [cat, setCat] = useState(0);
  const [page, setPage] = useState(1);
  // Local copy after a click, dropped on the next push (a refused edit pushes too).
  const [local, setLocal] = useState<Kit | null>(null);
  useEffect(() => setLocal(null), [char]);

  if (!char || !catalog) {
    return null;
  }
  const tabs: LoadoutCategory[] = catalog.loadout?.loadout_tabs || [];
  if (!tabs.length) {
    return null;
  }
  const kit: Kit = local || char.kit || {};
  const ci = Math.min(cat, tabs.length - 1);
  const tab = tabs[ci];
  const tabOf = (path: string) =>
    tabs.findIndex((t) => t.contents.some((it) => it.path === path));

  const toggle = (item: LoadoutItem) => {
    const on = !(item.path in kit);
    const next: Kit = { ...kit };
    if (on) {
      // Show tg's duplicate rule at once: one per category, two in Other (oldest goes).
      const same = Object.keys(next).filter(
        (p) => tab.contents.some((it) => it.path === p) && p !== item.path,
      );
      const limit = tab.name === TWO_ALLOWED ? 2 : 1;
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

  const wide = !narrow && w >= 70;
  const packW = wide ? PACK_W : 0;
  const ix = x + CAT_W + 3;
  const iw = w - CAT_W - 5 - packW;
  const top = y + 1;
  const bottom = y + h - 3;
  const catStep = h - 2 >= tabs.length * 2 ? 2 : 1;

  // ---- the item lines of this category ----
  const multiGroup =
    new Set(tab.contents.map((it) => it.group || tab.name)).size > 1;
  // Items grouped as tg's menu groups them, groups in order of first appearance.
  const groupOrder: string[] = [];
  for (const it of tab.contents) {
    const g = it.group || tab.name;
    if (!groupOrder.includes(g)) {
      groupOrder.push(g);
    }
  }
  const items = [...tab.contents].sort(
    (a, b) =>
      groupOrder.indexOf(a.group || tab.name) -
      groupOrder.indexOf(b.group || tab.name),
  );
  const blocksOf: Line[][] = [];
  let group: string | null = null;
  for (const item of items) {
    const block: Line[] = [];
    const g = item.group || tab.name;
    if (multiGroup && g !== group) {
      block.push({ kind: 'group', text: g });
    }
    group = g;
    block.push({ kind: 'item', item });
    if (item.path in kit) {
      const slots = kitColors[item.path] || 0;
      for (let s = 0; s < slots; s++) {
        block.push({ kind: 'color', item, slot: s, slots });
      }
      if (item.reskins?.length) {
        block.push({ kind: 'skin', item });
      }
      if (item.buttons?.some((b) => b.act_key === 'set_name')) {
        block.push({ kind: 'name', item });
      }
    }
    blocksOf.push(block);
  }
  // Double spacing when the whole category fits that way, as the mockup.
  const room = bottom - top + 1;
  const total = blocksOf.reduce((n, b) => n + b.length, 0);
  const spaced = total + blocksOf.length - 1 <= room;
  // Pages hold whole items.
  const pages: Line[][] = [[]];
  for (const block of blocksOf) {
    const cur = pages[pages.length - 1];
    const need = block.length + (spaced && cur.length ? 1 : 0);
    if (cur.length && cur.length + need > room - 1) {
      // A page that opens mid-group repeats the group's name.
      const g = block[0].kind === 'item' && block[0].item.group;
      const head: Line[] =
        multiGroup && block[0].kind !== 'group'
          ? [{ kind: 'group', text: g || tab.name }]
          : [];
      pages.push([...head, ...block]);
    } else {
      if (spaced && cur.length) {
        cur.push({ kind: 'gap' });
      }
      cur.push(...block);
    }
  }
  const pg = Math.min(pages.length, page);
  const lines = pages[pg - 1];
  const recent = fileColors(
    char.prefs,
    Object.keys(kit).flatMap((p) => slotColors(kit[p], kitColors[p] || 0)),
  );

  return (
    <>
      {tabs.map((t, i) => {
        const n = Object.keys(kit).filter((p) =>
          t.contents.some((it) => it.path === p),
        ).length;
        return (
          <CatRow
            key={t.name}
            x={x}
            y={top + i * catStep}
            name={t.name}
            count={n}
            cur={i === ci}
            onClick={() => {
              setCat(i);
              setPage(1);
            }}
          />
        );
      })}
      {lines.map((line, i) => {
        const ly = top + i;
        if (line.kind === 'gap') {
          return null;
        }
        if (line.kind === 'group') {
          return (
            <Put key={`g${i}`} x={ix} y={ly} cls="faint">
              {pad(line.text.toUpperCase(), iw)}
            </Put>
          );
        }
        const item = line.item;
        if (line.kind === 'item') {
          return (
            <ItemRow
              key={item.path}
              x={ix}
              y={ly}
              w={iw}
              name={item.name}
              on={item.path in kit}
              onClick={() => toggle(item)}
            />
          );
        }
        if (line.kind === 'color') {
          const cols = slotColors(kit[item.path], line.slots);
          return (
            <ColorEntry
              key={`${item.path}c${line.slot}`}
              x={ix + 4}
              y={ly}
              w={iw - 4}
              label={pad(
                line.slots > 1 ? `COLOUR ${line.slot + 1}` : 'COLOUR',
                OPT_W,
              )}
              value={cols[line.slot]}
              recent={recent}
              onSet={(color) =>
                act('char_kit_color', {
                  path: item.path,
                  slot: line.slot,
                  color,
                })
              }
            />
          );
        }
        if (line.kind === 'skin') {
          return (
            <SkinRow
              key={`${item.path}s`}
              x={ix + 4}
              y={ly}
              w={iw - 4}
              item={item}
              current={kit[item.path]?.reskin}
              onSkin={(skin) => act('char_kit_skin', { path: item.path, skin })}
            />
          );
        }
        return (
          <NameRow
            key={`${item.path}n`}
            x={ix + 4}
            y={ly}
            w={iw - 4}
            current={unescapeName(kit[item.path]?.name || '')}
            onName={(name) => act('char_kit_name', { path: item.path, name })}
          />
        );
      })}
      {pages.length > 1 && (
        <KitPager
          x={ix + iw - 11}
          y={bottom}
          page={pg}
          pages={pages.length}
          onPage={setPage}
        />
      )}
      {!!wide && (
        <Packed
          x={x + w - packW - 2}
          y={y}
          w={packW}
          h={h - 2}
          tabs={tabs}
          kit={kit}
          kitColors={kitColors}
          onJump={(path) => {
            const t = tabOf(path);
            if (t >= 0) {
              setCat(t);
              setPage(1);
            }
          }}
        />
      )}
    </>
  );
}

function CatRow(props: {
  x: number;
  y: number;
  name: string;
  count: number;
  cur: boolean;
  onClick: () => void;
}) {
  const { x, y, name, count, cur, onClick } = props;
  return (
    <>
      {!!cur && (
        <Put x={x + 1} y={y} cls="inv">
          {' '.repeat(CAT_W)}
        </Put>
      )}
      <Put x={x + 2} y={y} cls={cur ? 'inv' : 'dim'}>
        {pad(name.toUpperCase(), CAT_W - 3)}
      </Put>
      {count > 0 && (
        <Put x={x + CAT_W - 1} y={y} cls={cur ? 'inv' : 'amb'}>
          {String(count)}
        </Put>
      )}
      <Hit x={x + 1} y={y} w={CAT_W} h={1} onClick={onClick} />
    </>
  );
}

function ItemRow(props: {
  x: number;
  y: number;
  w: number;
  name: string;
  on: boolean;
  onClick: () => void;
}) {
  const { x, y, w, name, on, onClick } = props;
  const [hover, setHover] = useState(false);
  const label = pad(name, Math.max(4, w - 4));
  return (
    <>
      <Put x={x} y={y} cls={hover ? 'inv' : on ? 'amb' : 'dim'}>
        {on ? '[*]' : '[ ]'}
      </Put>
      <Put x={x + 4} y={y} cls={on ? '' : 'dim'}>
        {label}
      </Put>
      <Hit
        x={x}
        y={y}
        w={Math.min(w, label.trimEnd().length + 4)}
        h={1}
        onClick={onClick}
        onHover={setHover}
      />
    </>
  );
}

function SkinRow(props: {
  x: number;
  y: number;
  w: number;
  item: LoadoutItem;
  current?: string;
  onSkin: (skin: string) => void;
}) {
  const { x, y, w, item, current, onSkin } = props;
  const skins = item.reskins || [];
  let i = skins.findIndex((s) => s.name === current);
  if (i < 0) {
    i = Math.max(
      0,
      skins.findIndex((s) => s.skin_icon_state === item.icon_state),
    );
  }
  const step = (d: number) =>
    onSkin(skins[(i + d + skins.length) % skins.length].name);
  return (
    <>
      <Put x={x} y={y} cls="dim">
        {'STYLE'}
      </Put>
      <Cycler
        x={x + OPT_W + 1}
        y={y}
        w={Math.max(6, Math.min(22, w - OPT_W - 5))}
        value={skins[i]?.name || ''}
        onPrev={() => step(-1)}
        onNext={() => step(1)}
      />
    </>
  );
}

function NameRow(props: {
  x: number;
  y: number;
  w: number;
  current: string;
  onName: (name: string) => void;
}) {
  const { x, y, w, current, onName } = props;
  const [text, setText] = useState(current);
  useEffect(() => setText(current), [current]);
  const dirty = text.trim() !== current;
  // The field takes the row; SET (9 cells) takes its end while there is an edit.
  const fw = Math.max(8, Math.min(KIT_NAME_MAX, w - 7 - (dirty ? 9 : 0)));
  // The server refuses markup characters, slashes and anything outside printable ASCII.
  const ok =
    text.trim().length <= KIT_NAME_MAX &&
    NAME_OK.test(text) &&
    !NAME_BAD.test(text);
  const send = () => {
    if (ok) {
      onName(text.trim());
    }
  };
  return (
    <>
      <Put x={x} y={y} cls="dim">
        {'NAME'}
      </Put>
      <Field
        x={x + 5}
        y={y}
        w={fw}
        value={text}
        max={KIT_NAME_MAX}
        onChange={setText}
        onEnter={send}
      />
      {!!dirty && (
        <Btn x={x + fw + 8} y={y} label="SET" disabled={!ok} onClick={send} />
      )}
    </>
  );
}

function KitPager(props: {
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

function Packed(props: {
  x: number;
  y: number;
  w: number;
  h: number;
  tabs: LoadoutCategory[];
  kit: Kit;
  kitColors: Record<string, number>;
  onJump: (path: string) => void;
}) {
  const { x, y, w, h, tabs, kit, kitColors, onJump } = props;
  const names: Record<string, string> = {};
  for (const t of tabs) {
    for (const it of t.contents) {
      names[it.path] = it.name;
    }
  }
  const packed = Object.keys(kit).filter((p) => !!names[p]);
  const max = Math.max(0, h - 3);
  return (
    <>
      <Frame x={x} y={y} w={w} h={h} title="PACKED" dim />
      {packed.slice(0, max).map((path, i) => {
        const slots = kitColors[path] || 0;
        const own = kit[path]?.name;
        return (
          <Packline
            key={path}
            x={x + 3}
            y={y + 2 + i}
            w={w - 8}
            name={own ? unescapeName(own) : names[path]}
            color={slots ? slotColors(kit[path], slots)[0] : null}
            onClick={() => onJump(path)}
          />
        );
      })}
    </>
  );
}

function Packline(props: {
  x: number;
  y: number;
  w: number;
  name: string;
  color: string | null;
  onClick: () => void;
}) {
  const { x, y, w, name, color, onClick } = props;
  return (
    <>
      <Put x={x} y={y} hoverCls="inv" onClick={onClick}>
        {pad(name, w)}
      </Put>
      {!!color && <Swatch x={x + w + 0} y={y} hex={color} />}
    </>
  );
}
