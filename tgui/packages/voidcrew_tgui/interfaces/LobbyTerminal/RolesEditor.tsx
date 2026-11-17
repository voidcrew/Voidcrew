/**
 * ROLES (CHARACTER-PLAN 2.6): one row per ship role category, NEVER/LOW/MED/HIGH, char_role.
 * Owner: C4.
 *
 * The box is the editor's frame as CharacterTab draws it: x and w are the frame's outer
 * columns, y is the row under the frame's top line, y + h - 1 the frame's bottom line.
 * Only one category may be HIGH; the server demotes the old HIGH to MED (Q3). A click
 * shows that at once and the next push overwrites it.
 */
import { Fragment, useEffect, useState } from 'react';
import { useBackend } from 'tgui/backend';

import { Blocks, Hit, Put, pad, useGrid } from './term';
import type { CellBox, LobbyData, RoleLevel } from './types';

const LEVELS = ['NEVER', 'LOW', 'MED', 'HIGH'] as const;
/** Cells per level column. */
const COL = 7;

type Levels = Record<string, RoleLevel>;

/** An empty level cell: a faint outline the size of the lit block. */
function Slot(props: { x: number; y: number }) {
  const { x, y } = props;
  const { cw, ch, s } = useGrid();
  return (
    <div
      style={{
        position: 'absolute',
        boxSizing: 'border-box',
        left: x * cw,
        top: y * ch + ch * 0.2,
        width: 2 * cw - 2,
        height: ch * 0.6,
        border: `${Math.max(1, Math.round(s) - 1)}px solid var(--lt-faint)`,
      }}
    />
  );
}

export function RolesEditor(props: CellBox) {
  const { x, y, w, h } = props;
  const { act, data } = useBackend<LobbyData>();
  const char = data.char;
  const roles = data.char_static?.roles || [];
  // Local copy after a click, dropped on the next push (a refused edit pushes too).
  const [local, setLocal] = useState<Levels | null>(null);
  useEffect(() => setLocal(null), [char]);
  if (!char) {
    return null;
  }
  const levels: Levels = local || char.roles || {};

  const set = (category: string, level: 0 | RoleLevel) => {
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

  const L = x + 3;
  const cols = x + w - 3 - 4 * COL;
  const nameW = 13;
  const exW = cols - L - nameW - 3;
  const hy = y + 1;
  // Double spacing when the rows fit, as the mockup.
  const step = h - 3 >= roles.length * 2 ? 2 : 1;
  const first = hy + 1 + (step === 2 ? 1 : 0);

  return (
    <>
      {LEVELS.map((label, i) => (
        <Put
          key={label}
          x={cols + i * COL + Math.floor((6 - label.length) / 2)}
          y={hy}
          cls="dim"
        >
          {label}
        </Put>
      ))}
      {roles.map(([category, examples], ri) => (
        <RoleRow
          key={category}
          x={L}
          y={first + ri * step}
          cols={cols}
          nameW={nameW}
          exW={exW}
          category={category}
          examples={examples}
          level={levels[category] || 0}
          onSet={(lv) => set(category, lv)}
        />
      ))}
    </>
  );
}

function RoleRow(props: {
  x: number;
  y: number;
  cols: number;
  nameW: number;
  exW: number;
  category: string;
  examples: string;
  level: 0 | RoleLevel;
  onSet: (level: 0 | RoleLevel) => void;
}) {
  const { x, y, cols, nameW, exW, category, examples, level, onSet } = props;
  return (
    <>
      <Put x={x} y={y} cls={level ? '' : 'dim'}>
        {pad(category.toUpperCase(), nameW)}
      </Put>
      {exW >= 12 && !!examples && (
        <Put x={x + nameW + 1} y={y} cls="faint">
          {pad(examples, exW)}
        </Put>
      )}
      {LEVELS.map((label, i) => {
        const cx = cols + i * COL + 2;
        const on = i === level;
        return (
          <Fragment key={label}>
            {on ? (
              <Blocks
                x={cx}
                y={y}
                n={2}
                cls={i === 3 ? 'ablk' : i === 0 ? 'faint' : ''}
                frac={0.6}
              />
            ) : (
              <Slot x={cx} y={y} />
            )}
            <Hit
              x={cx - 1}
              y={y}
              w={4}
              h={1}
              onClick={() => {
                if (!on) {
                  onSet(i as 0 | RoleLevel);
                }
              }}
            />
          </Fragment>
        );
      })}
    </>
  );
}
