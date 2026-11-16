/**
 * The personnel file (design 03 section 3): FILES under the viewscreen, the name and the four
 * section blocks (BODY, ROLES, TRAITS, KIT) in the work column. A block press opens its editor.
 */
import { type ReactNode, useState } from 'react';
import { useBackend } from 'tgui/backend';
import type { ServerData } from 'tgui/interfaces/PreferencesMenu/types';

import {
  clamp,
  ID_W,
  ID_X,
  IdColumn,
  perPage,
  planId,
  q,
  type Section,
  useChar,
  useListPager,
  WORK_W,
  WORK_X,
} from './CharFrame';
import {
  Big,
  BODY_Y,
  cut,
  Pager,
  Put,
  RPut,
  SEP,
  Slab,
  safe,
  useGrid,
  WipeAt,
  wrapMax,
} from './term';
import type { CharData, CharStatic, LobbyData } from './types';
import {
  decodeName,
  kitName,
  nameOf,
  quirkOf,
  voiceShort,
} from './usePrefsCatalog';

const SECTIONS: [Section, string][] = [
  ['body', 'BODY'],
  ['roles', 'ROLES'],
  ['traits', 'TRAITS'],
  ['kit', 'KIT'],
];

/** Text of one block: lines (with a class each), the right item, and the empty text. */
type BlockText = { lines: [string, string][]; right?: string };

/** Points the taken traits leave to spend (tg: a quirk's value is what it costs). */
export function traitPoints(cat: ServerData | null, quirks: string[]) {
  return -quirks.reduce((sum, k) => sum + (quirkOf(cat, k)?.value || 0), 0);
}

function bodyText(
  cat: ServerData | null,
  char: CharData,
  L: number,
): BlockText {
  const p = char.prefs;
  const pron = nameOf(cat, 'gender', p.gender).toLowerCase();
  const first = [nameOf(cat, 'species', p.species), String(p.age ?? ''), pron]
    .filter(Boolean)
    .join(` ${SEP} `);
  const lines: [string, string][] = [[cut(safe(first), 36), '']];
  if ('voice_pack' in p) {
    const voice = voiceShort(nameOf(cat, 'voice_pack', p.voice_pack));
    lines.push([cut(safe(`${voice} voice`), 36), '']);
  }
  if ('background' in p) {
    lines.push([cut(safe(nameOf(cat, 'background', p.background)), 36), '']);
  }
  return { lines: lines.slice(0, L) };
}

function rolesText(
  stat: CharStatic | undefined,
  char: CharData,
  L: number,
): BlockText {
  const order = stat?.roles.map((r) => r[0]) || Object.keys(char.roles);
  const at = (lvl: number) => order.filter((r) => char.roles[r] === lvl);
  const high = at(3)[0];
  const rest = [...at(2), ...at(1)].map(safe);
  if (!high && !rest.length) {
    return { lines: [['ANY BERTH', 'dim']] };
  }
  if (!high) {
    return {
      lines: wrapMax(rest.join(', '), 36, L).map(
        (l) => [l, ''] as [string, string],
      ),
    };
  }
  const HIGH = safe(high).toUpperCase();
  if (!rest.length) {
    return { lines: [[cut(HIGH, 36), 'acc']] };
  }
  if (L === 1) {
    // One line: the HIGH role, then the rest after the separator.
    return {
      lines: [[cut(`${HIGH} ${SEP} ${rest.join(', ')}`, 36), 'acc-split']],
    };
  }
  return {
    lines: [
      [HIGH, 'acc'],
      ...wrapMax(`then ${rest.join(', ')}`, 36, L - 1).map(
        (l) => [l, ''] as [string, string],
      ),
    ],
  };
}

function listText(names: string[], empty: string, L: number): BlockText {
  if (!names.length) {
    return { lines: [[empty, 'dim']] };
  }
  return {
    lines: wrapMax(names.map(safe).join(', '), 36, L).map(
      (l) => [l, ''] as [string, string],
    ),
  };
}

export function CharFile(props: {
  cat: ServerData | null;
  /** Opens an editor. */
  open: (section: Section) => void;
  /** The section to give the focus to (coming back from it, or BODY on a fresh open). */
  focus: Section | null;
  /** A file switch is on its way: FILES are dead. */
  switching: boolean;
  onSlot: (slot: number) => void;
  /** Drawn in the work column instead of the name and blocks (the records didn't answer). */
  ghost?: ReactNode;
}) {
  const { cat, open, focus, switching, onSlot, ghost } = props;
  const { data } = useBackend<LobbyData>();
  const { rows: M } = useGrid();
  const { quiet } = useChar();
  const char = data.char!;
  const stat = data.char_static;
  const slots = char.slots || [];
  const n = Math.max(1, slots.length);
  const name = safe(String(char.prefs.real_name ?? ''));
  const NAME = name.toUpperCase();

  // ---- FILES: one slab a slot, bottom-anchored under the uniform row.
  let slabH = 1.25;
  let paged = false;
  let per = n;
  const plan = planId(M, 1 + 1.5 * n, (la) => {
    const h = clamp(q((la - 1) / n - 0.25), 1.25, 4.5);
    const used = 1.25 + n * (h + 0.25) - 0.25;
    if (used > la + 1e-6) {
      paged = true;
      per = perPage(la, 1.25);
      slabH = 1.25;
      return la;
    }
    slabH = h;
    return used;
  });
  const pages = paged ? Math.ceil(n / per) : 1;
  const [page, setPage] = useState(() =>
    paged ? Math.floor((char.slot - 1) / per) : 0,
  );
  const pg = Math.min(page, pages - 1);
  useListPager(pg, pages, setPage);
  const listTop = paged ? BODY_Y + plan.pv + 2.25 : plan.top;
  const shownSlots = slots
    .map((s, i) => [s, i] as [string | null, number])
    .slice(pg * per, pg * per + per);

  const files: ReactNode[] = [
    <Put key="head" x={ID_X} y={listTop} cls="dim">
      {'FILES'}
    </Put>,
  ];
  shownSlots.forEach(([saved, i], k) => {
    const y = listTop + 1.25 + k * (slabH + 0.25);
    const cur = i + 1 === char.slot;
    const label = cur ? NAME : saved ? safe(saved).toUpperCase() : 'NEW FILE';
    const lines = wrapMax(label, 16, clamp(Math.floor(slabH), 1, 3));
    const ty = y + (slabH - lines.length) / 2;
    files.push(
      <Slab
        key={`s${i}`}
        x={ID_X}
        y={y}
        w={ID_W}
        h={slabH}
        variant="row"
        alt={k % 2 === 1}
        on={cur}
        dead={!cur && switching}
        onClick={cur ? undefined : () => onSlot(i + 1)}
      >
        <Put x={3} y={ty} cls="dim">
          {String(i + 1)}
        </Put>
        {lines.map((line, j) => (
          <Put key={j} x={5} y={ty + j} cls={cur ? 'wht' : saved ? '' : 'dim'}>
            {line}
          </Put>
        ))}
      </Slab>,
    );
  });
  if (paged) {
    files.push(
      <Pager
        key="pager"
        x={ID_X + ID_W}
        y={M - 2.25}
        page={pg + 1}
        pages={pages}
        onPage={(p) => setPage(p - 1)}
        right
      />,
      // A page of files turning wipes the list only.
      <WipeAt
        key="turn"
        x={ID_X}
        y={listTop + 1.25}
        w={ID_W}
        h={M - 2.5 - (listTop + 1.25)}
        k={pg}
      />,
    );
  }

  // ---- the name, never cut
  let nameNode: ReactNode;
  if (NAME.length <= 31) {
    nameNode = (
      <Big x={WORK_X} y={3.625} scale={1.25} cls="wht lt-name">
        {NAME}
      </Big>
    );
  } else if (NAME.length <= 39) {
    nameNode = (
      <Put x={WORK_X} y={3.75} cls="wht lt-name">
        {NAME}
      </Put>
    );
  } else {
    const two = wrapMax(NAME, 39, 2);
    nameNode = two.map((line, i) => (
      <Put key={i} x={WORK_X} y={3.25 + i} cls="wht lt-name">
        {line}
      </Put>
    ));
  }

  // ---- the four blocks
  const h = q((M - 7.75) / 4);
  const p = h >= 4.75 ? 0.25 : 0.125;
  const L = clamp(Math.floor(h - 1.25 - 2 * p), 1, 6);
  const points = traitPoints(cat, char.quirks || []);
  const pointsOn = cat?.quirks?.points_enabled !== false;
  const texts: Record<Section, BlockText> = {
    body: bodyText(cat, char, L),
    roles: rolesText(stat, char, L),
    traits: {
      ...listText(
        (char.quirks || []).map((k) => quirkOf(cat, k)?.name || k),
        'NONE',
        L,
      ),
      right:
        pointsOn && points > 0 ? `${Math.min(999, points)} POINTS` : undefined,
    },
    kit: listText(
      Object.entries(char.kit || {}).map(([path, it]) =>
        it.name ? decodeName(it.name) : kitName(cat, path),
      ),
      'NOTHING PACKED',
      L,
    ),
  };

  const blocks = SECTIONS.map(([sec, title], i) => {
    const y = 5.75 + i * (h + 0.25);
    const t = texts[sec];
    return (
      <Slab
        key={sec}
        x={WORK_X}
        y={y}
        w={WORK_W}
        h={h}
        variant="block"
        dead={!cat}
        auto={!quiet && focus === sec ? 5 : undefined}
        onClick={() => open(sec)}
      >
        <Big x={WORK_X + 2} y={y + p} scale={1.25} cls="wht">
          {title}
        </Big>
        {!!t.right && (
          <RPut x={61} y={y + p + 0.125} cls="dim" pulse={t.right}>
            {t.right}
          </RPut>
        )}
        {t.lines.map(([line, cls], j) => {
          const ly = y + p + 1.25 + j;
          if (cls === 'acc-split') {
            // HIGH role in accent, the rest in fg, on one line.
            const cutAt = line.indexOf(` ${SEP} `);
            const head = cutAt < 0 ? line : line.slice(0, cutAt);
            return (
              <span key={j}>
                <Put x={WORK_X + 2} y={ly} cls="acc">
                  {head}
                </Put>
                {cutAt >= 0 && (
                  <Put x={WORK_X + 2 + head.length} y={ly}>
                    {line.slice(cutAt)}
                  </Put>
                )}
              </span>
            );
          }
          return (
            <Put key={j} x={WORK_X + 2} y={ly} cls={cls}>
              {line}
            </Put>
          );
        })}
      </Slab>
    );
  });

  return (
    <>
      <IdColumn pv={plan.pv}>{files}</IdColumn>
      {ghost || (
        <>
          {nameNode}
          {blocks}
        </>
      )}
      {/* Another file opening turns the page of the work column. */}
      <WipeAt
        x={WORK_X}
        y={BODY_Y}
        w={WORK_W}
        h={M - 1.25 - BODY_Y}
        k={char.slot}
      />
    </>
  );
}
