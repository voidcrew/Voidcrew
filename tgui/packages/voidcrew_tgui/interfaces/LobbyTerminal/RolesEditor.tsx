/**
 * ROLES (design 03b section 1): one row a role with four labelled keys, NEVER, LOW, MED and
 * HIGH (char_role). The ID column shows the focused role's uniform on the body and, under it,
 * the berths that role covers (char_static.roles titles).
 *
 * Only one role may be HIGH: the server drops the old HIGH to MED. A press shows that at once
 * from a local copy; the next push replaces it.
 *
 * The preview follows the focus: 250 ms after the focus rests on a row the page sends
 * char_dress for that role, and char_dress '' when ROLES closes.
 */
import { useEffect, useRef, useState } from 'react';
import { useBackend } from 'tgui/backend';

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
import { BODY_Y, bodyRows, cut, Key, Put, Slab, safe, useGrid } from './term';
import type { LobbyData, RoleLevel } from './types';

type Levels = Record<string, RoleLevel>;

/** The four keys: label, first column, width. */
const KEYS: [label: string, x: number, w: number][] = [
  ['NEVER', 39, 7],
  ['LOW', 46, 5],
  ['MED', 51, 5],
  ['HIGH', 56, 6],
];

/** How long the focus rests on a row before the preview is dressed in its uniform. */
const DRESS_MS = 250;

/** The berth titles of a char_static.roles entry (older servers sent one joined string). */
function titlesOf(entry: [string, string[] | string]): string[] {
  const t = entry[1];
  if (Array.isArray(t)) {
    return t;
  }
  return t ? String(t).split(', ') : [];
}

export function RolesEditor() {
  const { act, data } = useBackend<LobbyData>();
  const { quiet } = useChar();
  const { rows: M } = useGrid();
  const char = data.char;
  const roles = (data.char_static?.roles || []).filter(
    (r) => titlesOf(r).length > 0,
  );
  // Local copy after a press, dropped on the next push (a refused edit pushes too).
  const [local, setLocal] = useState<Levels | null>(null);
  useEffect(() => setLocal(null), [char]);
  const levels: Levels = local || char?.roles || {};

  // First focus: the lit key of the highest role, else the first row's NEVER.
  let top = 0;
  let topLevel = 0;
  roles.forEach(([cat], i) => {
    const lv = levels[cat] || 0;
    if (lv > topLevel) {
      top = i;
      topLevel = lv;
    }
  });
  const [focusRow, setFocusRow] = useState(top);
  const row = Math.min(focusRow, Math.max(0, roles.length - 1));
  const focusCat = roles[row]?.[0] || '';

  // Dress the preview in the focused row's uniform once the focus rests there.
  const dress = char?.dress || '';
  const sent = useRef(false);
  useEffect(() => {
    if (!focusCat || focusCat === dress) {
      return;
    }
    const t = window.setTimeout(() => {
      sent.current = true;
      act('char_dress', { category: focusCat });
    }, DRESS_MS);
    return () => window.clearTimeout(t);
  }, [focusCat, dress]);
  useEffect(
    () => () => {
      if (sent.current) {
        act('char_dress', { category: '' });
      }
    },
    [],
  );

  if (!char) {
    return null;
  }

  const set = (category: string, level: 0 | RoleLevel) => {
    if ((levels[category] || 0) === level) {
      return;
    }
    const next: Levels = {};
    for (const [cat, lv] of Object.entries(levels)) {
      next[cat] = level === 3 && lv === 3 ? 2 : lv;
    }
    if (level) {
      next[category] = level;
    } else {
      delete next[category];
    }
    setLocal(next);
    act('char_role', { category, level });
  };

  // ---- ID column: BERTHS under the picture, top-anchored.
  const most = Math.max(1, ...roles.map((r) => titlesOf(r).length));
  const plan = planId(
    M,
    4.25,
    (la) => 1.25 + Math.min(most, Math.max(1, Math.floor(la - 1.25)), 7),
  );
  const listY = BODY_Y + plan.pv + 2.25;
  const room = M - 1.25 - listY;
  const titles = roles[row] ? titlesOf(roles[row]) : [];
  const lines = Math.min(titles.length, Math.max(1, Math.floor(room - 1.25)), 7);
  const over = titles.length > lines;
  const shown = titles.slice(0, over ? lines - 1 : lines);
  const berths = (
    <>
      <Put x={ID_X} y={listY} cls="dim">
        {'BERTHS'}
      </Put>
      {shown.map((t, i) => (
        <Put key={t} x={ID_X} y={listY + 1.25 + i}>
          {cut(safe(t), ID_W)}
        </Put>
      ))}
      {!!over && (
        <Put x={ID_X} y={listY + 1.25 + lines - 1} cls="dim">
          {`+${titles.length - shown.length} MORE`}
        </Put>
      )}
    </>
  );

  // ---- work column: one row a role.
  const B = bodyRows(M);
  const r = Math.max(1, roles.length);
  const h = clamp(q((B + 0.25) / r - 0.25), 1.25, 4.5);
  const pitch = h + 0.25;

  return (
    <>
      <IdColumn pv={plan.pv} uniform="plain">
        {berths}
      </IdColumn>
      {roles.map(([cat], i) => {
        const y = BODY_Y + i * pitch;
        const level = levels[cat] || 0;
        return (
          <Slab
            key={cat}
            x={WORK_X}
            y={y}
            w={WORK_W}
            h={h}
            variant="row"
            on={level === 3}
          >
            <Put x={25} y={y + (h - 1) / 2} cls={level ? 'wht' : 'dim'}>
              {cut(safe(cat).toUpperCase(), 13)}
            </Put>
            {KEYS.map(([label, kx, kw], li) => (
              <Key
                key={label}
                x={kx}
                y={y}
                w={kw}
                h={h}
                kind="cap"
                label={label}
                state={
                  li === 0 || li !== level ? 'idle' : li === 3 ? 'on' : 'lit'
                }
                auto={!quiet && i === top && li === topLevel ? 5 : undefined}
                onClick={() => set(cat, li as 0 | RoleLevel)}
                onFocus={(on) => on && setFocusRow(i)}
              />
            ))}
          </Slab>
        );
      })}
    </>
  );
}
