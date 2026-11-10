/**
 * CHARACTER tab, layout A "personnel file" (CHARACTER-PLAN 2.2): FILES, the preview, the
 * PERSONNEL FILE cells and the crumbs; one editor sub-screen at a time.
 * Owner: C3.
 *
 * Editors get the inside of the frame CharacterTab draws for them: CellBox (x, y = frame top
 * + 1, w = frame width, h = frame height - 1), as the mockup's editors do. BODY, ROLES and KIT
 * keep the preview on the left; TRAITS and every narrow screen use the full width.
 */
import { type ReactNode, useEffect, useState } from 'react';
import { useBackend } from 'tgui/backend';

import { BodyEditor } from './BodyEditor';
import { CharPreview } from './CharPreview';
import { parseHex } from './ColorEntry';
import { KitEditor } from './KitEditor';
import { RolesEditor } from './RolesEditor';
import { TraitsEditor } from './TraitsEditor';
import {
  Frame,
  Hit,
  Put,
  pad,
  RPut,
  Rule,
  Swatch,
  TOP,
  useGrid,
  wrap,
} from './term';
import type {
  CellBox,
  CharData,
  CharDir,
  CharSection,
  CharStatic,
  LobbyData,
} from './types';
import {
  kitName,
  namedHex,
  nameOf,
  quirkOf,
  usePrefsCatalog,
} from './usePrefsCatalog';

const SECTIONS: [CharSection, string][] = [
  ['body', 'BODY'],
  ['roles', 'ROLES'],
  ['traits', 'TRAITS'],
  ['kit', 'KIT'],
];
const PRIO = ['NEVER', 'LOW', 'MED', 'HIGH'];
/** Facings in clockwise order: S, W, N, E. */
const TURN: CharDir[] = [2, 8, 1, 4];

/** A `[ LABEL ]` key, dim at rest, lit on hover (the mockup's key()). */
function Key(props: {
  x: number;
  y: number;
  label: string;
  cls?: string;
  bg?: boolean;
  onClick: () => void;
}) {
  const { x, y, label, cls = 'dim', bg, onClick } = props;
  return (
    <Put x={x} y={y} cls={cls} hoverCls="inv" bg={bg} onClick={onClick}>
      {label}
    </Put>
  );
}

/** The category with the highest level (first in role order on a tie), or null. */
function topRole(char: CharData, stat?: CharStatic) {
  let best: string | null = null;
  let lvl = 0;
  const order = stat?.roles.map((r) => r[0]) || Object.keys(char.roles);
  for (const cat of order) {
    const v = char.roles[cat] || 0;
    if (v > lvl) {
      lvl = v;
      best = cat;
    }
  }
  return best;
}

export function CharacterTab(props: { home: number }) {
  const { home } = props;
  const { act, data } = useBackend<LobbyData>();
  const { cols, rows, narrow } = useGrid();
  const cat = usePrefsCatalog();
  const [section, setSection] = useState<CharSection | null>(null);
  const [dir, setDir] = useState<CharDir>(2);

  useEffect(() => {
    act('char_open');
  }, []);
  useEffect(() => {
    setSection(null);
  }, [home]);

  const char = data.char;
  const stat = data.char_static;
  const h = rows - 1 - TOP;
  const name = String(char?.prefs.real_name ?? '');
  const NAME = name.toUpperCase();

  // ---- the preview with its turn keys and dress label
  const preview = (x: number, y: number, w: number, ph: number) => {
    const ky = Math.ceil(y + ph) + 1;
    const turn = (by: number) => {
      const i = TURN.indexOf(dir);
      setDir(TURN[(i + by + TURN.length) % TURN.length]);
    };
    const out: ReactNode[] = [
      <CharPreview key="pv" x={x} y={y} w={w} h={ph} dir={dir} />,
      <Key key="tl" x={x} y={ky} label="[ < ]" onClick={() => turn(-1)} />,
      <Key
        key="tr"
        x={x + w - 5}
        y={ky}
        label="[ > ]"
        onClick={() => turn(1)}
      />,
    ];
    if (char?.dress) {
      const dress = char.dress.toUpperCase();
      const off = char.dress !== (topRole(char, stat) ?? char.dress);
      const cats = (stat?.roles.map((r) => r[0]) || []).filter(
        (c) => c !== 'Silicon',
      );
      // Past the last category the preview goes back to automatic (the top role).
      const at = cats.indexOf(char.dress);
      const next = !cats.length
        ? null
        : at === cats.length - 1
          ? ''
          : cats[at + 1];
      const lab = pad(dress, Math.max(1, w - 12)).trimEnd();
      out.push(
        <Put
          key="dress"
          x={x + Math.floor((w - lab.length) / 2)}
          y={ky}
          cls={off ? 'amb' : ''}
          hoverCls={next !== null ? 'inv' : undefined}
          onClick={
            next !== null
              ? () => act('char_dress', { category: next })
              : undefined
          }
        >
          {lab}
        </Put>,
      );
    }
    return out;
  };

  // ---- crumbs and [ BACK ] on the tab row
  const crumbs = (label: string) => {
    const seg: [string, (() => void) | null][] = [
      ['CHARACTER', () => setSection(null)],
      [NAME || 'FILE', () => setSection(null)],
      [label, null],
    ];
    const room = cols - 1 - 42 - 12;
    const width = () => seg.map((s) => s[0]).join(' / ').length;
    while (seg.length > 1 && width() > room) {
      seg.shift();
    }
    const fits = width() <= room;
    let x = cols - 1 - (fits ? width() : 0);
    const out: ReactNode[] = [
      <Key
        key="back"
        x={x - 12}
        y={2}
        label="[ BACK ]"
        onClick={() => setSection(null)}
      />,
    ];
    if (fits) {
      seg.forEach(([lab, go], i) => {
        const last = i === seg.length - 1;
        out.push(
          <Put
            key={`c${i}`}
            x={x}
            y={2}
            cls={last ? '' : 'dim'}
            hoverCls={go && !last ? '' : undefined}
            onClick={go && !last ? go : undefined}
          >
            {lab}
          </Put>,
        );
        x += lab.length;
        if (!last) {
          out.push(
            <Put key={`s${i}`} x={x} y={2} cls="faint">
              {' / '}
            </Put>,
          );
          x += 3;
        }
      });
    }
    return out;
  };

  // ---- a section open
  if (section && char) {
    const label = SECTIONS.find((s) => s[0] === section)![1];
    const full = section === 'traits' || narrow;
    const pw = full ? 0 : Math.min(40, Math.floor(cols * 0.3));
    const ex = full ? 0 : pw + 1;
    const ew = cols - ex;
    const box: CellBox = { x: ex, y: TOP + 1, w: ew, h: h - 1 };
    let editor: ReactNode = null;
    if (section === 'body') {
      editor = <BodyEditor {...box} />;
    } else if (section === 'roles') {
      editor = <RolesEditor {...box} />;
    } else if (section === 'traits') {
      editor = <TraitsEditor {...box} />;
    } else {
      editor = <KitEditor {...box} />;
    }
    return (
      <>
        {crumbs(label)}
        {!full && (
          <Frame x={0} y={TOP} w={pw} h={h} title={pad(NAME, pw - 6).trimEnd()}>
            {preview(2, TOP + 1.5, pw - 4, h - 5.5)}
          </Frame>
        )}
        <Frame x={ex} y={TOP} w={ew} h={h} title={label} />
        {editor}
      </>
    );
  }

  // ---- the file
  const slots = char?.slots || [];
  const pw = Math.min(40, Math.floor(cols * 0.3));
  const files = (
    <Frame x={0} y={TOP} w={pw} h={h} title="FILES">
      {slots.map((s, i) => {
        const cur = i + 1 === char?.slot;
        const shown = cur ? name : s;
        const yy = TOP + 1 + i;
        return (
          <span key={i}>
            {!!cur && (
              <Put x={1} y={yy} cls="inv">
                {' '.repeat(pw - 2)}
              </Put>
            )}
            <Put x={2} y={yy} cls={cur ? 'inv' : 'dim'}>
              {String(i + 1)}
            </Put>
            <Put x={4} y={yy} cls={cur ? 'inv' : shown ? '' : 'faint'}>
              {pad(shown ? shown.toUpperCase() : '-- EMPTY --', pw - 6)}
            </Put>
            {!cur && (
              <Hit
                x={1}
                y={yy}
                w={pw - 2}
                h={1}
                onClick={() => act('char_slot', { slot: i + 1 })}
              />
            )}
          </span>
        );
      })}
    </Frame>
  );
  const n = Math.max(3, slots.length);
  const py = TOP + 2 + n;
  const ph = h - 6.5 - n;

  const x = pw + 1;
  const w = cols - x;
  const gx = x + 2;
  const gw = Math.floor((w - 5) / 2);
  const gy = TOP + 4;
  const gh = Math.floor((h - 5) / 2);
  const compact = gh < 6;
  // Tall cells leave a blank row under the title, as the mockup does.
  const inset = gh >= 9 ? 2 : 1;

  const body = char ? identity(char) : null;
  const cell = (
    i: number,
    title: string,
    sec: CharSection,
    fill: (cx: number, cy: number, cw: number, rh: number) => ReactNode,
  ) => {
    const cx = gx + (i % 2) * (gw + 1);
    const cy = gy + Math.floor(i / 2) * gh;
    return (
      <span key={sec}>
        <Frame x={cx} y={cy} w={gw} h={gh} title={title} dim />
        <Key
          x={cx + gw - 11}
          y={cy}
          label="[ EDIT ]"
          cls=""
          bg
          onClick={() => setSection(sec)}
        />
        {fill(cx + 3, cy + inset, gw - 6, gh - 1 - inset)}
      </span>
    );
  };

  function identity(c: CharData) {
    const p = c.prefs;
    const voice = nameOf(cat, 'voice_pack', p.voice_pack);
    const lines: [string, string][] = [
      ['SPECIES', nameOf(cat, 'species', p.species)],
      ['AGE', String(p.age ?? '')],
      ['PRONOUNS', nameOf(cat, 'gender', p.gender)],
      ['VOICE', voice.includes(': ') ? voice.split(': ').pop()! : voice],
    ];
    const chips: [string, string][] = [];
    const add = (lab: string, hex: string | null) => {
      if (hex) {
        chips.push([lab, hex]);
      }
    };
    if ('skin_tone' in p) {
      add('SKIN', namedHex(cat, 'skin_tone', p.skin_tone));
    }
    if ('hairstyle_name' in p && 'hair_color' in p) {
      add('HAIR', parseHex(p.hair_color));
    }
    if ('feature_mcolor' in p) {
      add('SCALES', parseHex(p.feature_mcolor));
    }
    if ('feature_ethcolor' in p) {
      add('GLOW', namedHex(cat, 'feature_ethcolor', p.feature_ethcolor));
    }
    if ('eye_color' in p) {
      add('EYES', parseHex(p.eye_color));
    }
    return { lines, chips };
  }

  const bodyCell = (cx: number, cy: number, cw: number, rh: number) => {
    if (!body) {
      return null;
    }
    const out: ReactNode[] = [];
    body.lines.slice(0, Math.max(0, rh - 1)).forEach(([k, v], i) => {
      out.push(
        <Put key={`k${i}`} x={cx} y={cy + i} cls="dim">
          {k}
        </Put>,
        <Put key={`v${i}`} x={cx + 11} y={cy + i}>
          {pad(v, cw - 11)}
        </Put>,
      );
    });
    let sx = cx;
    const sy = cy + Math.min(body.lines.length, Math.max(0, rh - 1));
    for (const [k, hex] of body.chips) {
      if (sx + k.length + 3 > cx + cw) {
        break;
      }
      out.push(
        <Put key={`ck${k}`} x={sx} y={sy} cls="dim">
          {k}
        </Put>,
        <Swatch key={`cs${k}`} x={sx + k.length + 1} y={sy} hex={hex} />,
      );
      sx += k.length + 5;
    }
    return out;
  };

  const rolesCell = (cx: number, cy: number, cw: number, rh: number) => {
    if (!char) {
      return null;
    }
    const order = stat?.roles.map((r) => r[0]) || Object.keys(char.roles);
    const out: ReactNode[] = [];
    let yy = cy;
    for (let lvl = 3; lvl >= 1 && yy < cy + rh; lvl--) {
      const names = order.filter((r) => char.roles[r] === lvl);
      if (!names.length) {
        continue;
      }
      out.push(
        <Put key={`p${lvl}`} x={cx} y={yy} cls={lvl === 3 ? 'amb' : 'dim'}>
          {PRIO[lvl]}
        </Put>,
      );
      for (const l of wrap(names.join(', '), cw - 7).slice(0, cy + rh - yy)) {
        out.push(
          <Put key={`r${yy}`} x={cx + 6} y={yy} cls={lvl === 3 ? 'amb' : ''}>
            {l}
          </Put>,
        );
        yy++;
      }
    }
    if (yy === cy) {
      out.push(
        <Put key="any" x={cx} y={cy} cls="dim">
          {'ANY BERTH'}
        </Put>,
      );
    }
    return out;
  };

  const points = () =>
    -(char?.quirks || []).reduce(
      (sum, q) => sum + (quirkOf(cat, q)?.value || 0),
      0,
    );

  const traitsCell = (cx: number, cy: number, cw: number, rh: number) => {
    if (!char) {
      return null;
    }
    const pts = points();
    const out: ReactNode[] = char.quirks
      .slice(0, Math.max(0, rh - 2))
      .map((q, i) => {
        const info = quirkOf(cat, q);
        const v = info?.value || 0;
        return (
          <span key={q}>
            <Put x={cx} y={cy + i}>
              {pad(info?.name || q, cw - 5)}
            </Put>
            <RPut x={cx + cw} y={cy + i} cls={v > 0 ? 'amb' : 'dim'}>
              {String(v)}
            </RPut>
          </span>
        );
      });
    if (!char.quirks.length) {
      out.push(
        <Put key="none" x={cx} y={cy} cls="faint">
          {'NONE'}
        </Put>,
      );
    }
    if (cat?.quirks?.points_enabled !== false) {
      out.push(
        <Put key="pl" x={cx} y={cy + rh - 1} cls="dim">
          {'POINTS'}
        </Put>,
        <RPut key="pv" x={cx + cw} y={cy + rh - 1} cls={pts ? 'amb' : ''}>
          {String(pts)}
        </RPut>,
      );
    }
    return out;
  };

  const kitCell = (cx: number, cy: number, cw: number, rh: number) => {
    const items = Object.keys(char?.kit || {});
    if (!items.length) {
      return (
        <Put x={cx} y={cy} cls="faint">
          {'NOTHING PACKED'}
        </Put>
      );
    }
    return items.slice(0, rh).map((p, i) => (
      <Put key={p} x={cx} y={cy + i}>
        {pad(kitName(cat, p), cw)}
      </Put>
    ));
  };

  /** One line per section when the cells don't fit (short screens). */
  const compactList = () => {
    if (!char) {
      return null;
    }
    const top = topRole(char, stat);
    const lines: [CharSection, string, string][] = [
      [
        'body',
        'BODY',
        body
          ? body.lines
              .slice(0, 3)
              .map((l) => l[1])
              .join(', ')
          : '',
      ],
      ['roles', 'ROLES', top ? `${top}` : 'Any berth'],
      [
        'traits',
        'TRAITS',
        char.quirks.map((q) => quirkOf(cat, q)?.name || q).join(', ') || 'None',
      ],
      [
        'kit',
        'KIT',
        Object.keys(char.kit)
          .map((p) => kitName(cat, p))
          .join(', ') || 'Nothing packed',
      ],
    ];
    const step = h - 4 >= 8 ? 2 : 1;
    return lines.map(([sec, lab, sum], i) => {
      const yy = TOP + 3 + i * step;
      return (
        <span key={sec}>
          <Put x={x + 3} y={yy} cls="dim">
            {lab}
          </Put>
          <Put x={x + 11} y={yy}>
            {pad(sum, Math.max(1, w - 25))}
          </Put>
          <Key
            x={x + w - 11}
            y={yy}
            label="[ EDIT ]"
            cls=""
            onClick={() => setSection(sec)}
          />
        </span>
      );
    });
  };

  return (
    <>
      {files}
      <Rule x={1} y={py - 1} w={pw - 2} />
      {ph >= 3 && preview(2, py, pw - 4, ph)}
      <Frame x={x} y={TOP} w={w} h={h} title="PERSONNEL FILE" />
      {!!char && (
        <>
          <Put x={x + 3} y={TOP + (compact ? 1 : 2)}>
            {pad(NAME, Math.max(1, w - 20))}
          </Put>
          <RPut x={x + w - 3} y={TOP + (compact ? 1 : 2)} cls="dim">
            {`FILE ${char.slot} OF ${char.slots.length}`}
          </RPut>
          {compact
            ? compactList()
            : [
                cell(0, 'BODY', 'body', bodyCell),
                cell(1, 'ROLES', 'roles', rolesCell),
                cell(2, 'TRAITS', 'traits', traitsCell),
                cell(3, 'KIT', 'kit', kitCell),
              ]}
        </>
      )}
    </>
  );
}
