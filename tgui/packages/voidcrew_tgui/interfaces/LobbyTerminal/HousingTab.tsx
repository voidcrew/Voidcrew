/**
 * HOUSING tab: player outposts taking residents (DM: lobby_housing.dm).
 * Draws only with the term.tsx primitives.
 */
import { Fragment, type ReactNode, useState } from 'react';
import { useBackend } from 'tgui/backend';

import {
  Blocks,
  Btn,
  type Cls,
  Field,
  Frame,
  Put,
  Rule,
  TOP,
  useGrid,
} from './term';
import type { LobbyData, Outpost, OutpostMode } from './types';

const MODES: Record<OutpostMode, [string, Cls]> = {
  open: ['OPEN', ''],
  password: ['CODE', 'amb'],
  approved: ['INVITE', 'amb'],
  closed: ['CLOSED', 'red'],
};

/** Cuts a name to n cells, ending a cut in '.'. */
function cutName(name: string, n: number): string {
  return name.length <= n ? name : `${name.slice(0, n - 1).trimEnd()}.`;
}

/** Width of the code field between its brackets. */
const FIELD = 10;
const MOVE_IN = '[ MOVE IN ]';
/** Widest key group at the right of a row: CODE [field] [ MOVE IN ]. */
const KEYS_W = 5 + FIELD + 3 + MOVE_IN.length;

export function HousingTab() {
  const { act, data } = useBackend<LobbyData>();
  const { cols, rows, narrow } = useGrid();
  const [codes, setCodes] = useState<Record<string, string>>({});
  const [page, setPage] = useState(0);
  const outposts = data.outposts || [];

  const h = rows - 1 - TOP;
  const bottom = TOP + h - 1;
  const hy = TOP + 1;
  const right = cols - 4;
  // The mockup's columns on a wide screen; tighter on a narrow one, with the keys on a second line.
  const colA = narrow ? Math.min(22, Math.floor(cols * 0.42)) : 30;
  const colR = narrow ? colA + 9 : 44;
  const nameW = colA - 5;
  const step = narrow ? 4 : 3;
  const perPage = Math.max(1, Math.floor((bottom - 1 - (hy + 2)) / step));
  const pages = Math.max(1, Math.ceil(outposts.length / perPage));
  const shownPage = Math.min(page, pages - 1);
  const shown = outposts.slice(
    shownPage * perPage,
    shownPage * perPage + perPage,
  );
  const blockEnd = narrow ? cols - 3 : right - KEYS_W - 2;
  const blockRoom = Math.max(0, Math.floor((blockEnd - (colR + 5)) / 2));

  const moveIn = (o: Outpost) => {
    act('home_move_in', { outpost: o.ref, code: codes[o.ref] || '' });
    setCodes({ ...codes, [o.ref]: '' });
  };

  const codeKeys = (o: Outpost, y: number) => {
    const locked = (o.code_wait || 0) > 0;
    const code = codes[o.ref] || '';
    const fx = right - MOVE_IN.length - 2 - FIELD;
    const cls = locked ? 'faint' : 'amb';
    return (
      <>
        <Put x={fx - 6} y={y} cls={cls}>
          CODE
        </Put>
        <Field
          x={fx - 1}
          y={y}
          w={FIELD}
          value={code}
          max={64}
          disabled={locked}
          secret
          onChange={(value) => setCodes({ ...codes, [o.ref]: value })}
          onEnter={() => moveIn(o)}
        />
        <Btn
          x={right}
          y={y}
          right
          label="MOVE IN"
          auto={o === shown[0] ? 1 : undefined}
          amber
          lit={code.length > 0}
          disabled={locked}
          onClick={() => moveIn(o)}
        />
      </>
    );
  };

  const keys = (o: Outpost, y: number) => {
    if (o.mode === 'password' && !o.cleared && !o.denial) {
      return codeKeys(o, y);
    }
    const ax = right - MOVE_IN.length - 2;
    let ask: ReactNode = null;
    if (o.can_ask) {
      ask = o.asked ? (
        <Btn x={ax} y={y} right label="ASKED" disabled />
      ) : (
        <Btn
          x={ax}
          y={y}
          right
          label="REQUEST"
          amber
          onClick={() => act('home_request', { outpost: o.ref })}
        />
      );
    }
    return (
      <>
        {ask}
        {o.denial ? (
          // Faint, but a press still answers with the reason as a notice.
          <Put
            x={right - MOVE_IN.length}
            y={y}
            cls="faint"
            title={o.denial}
            onClick={() => act('home_move_in', { outpost: o.ref })}
          >
            {MOVE_IN}
          </Put>
        ) : (
          <Btn
            x={right}
            y={y}
            right
            label="MOVE IN"
            lit
            auto={o === shown[0] ? 1 : undefined}
            onClick={() => moveIn(o)}
          />
        )}
      </>
    );
  };

  return (
    <Frame x={0} y={TOP} w={cols} h={h} title={`OUTPOSTS  ${outposts.length}`}>
      {outposts.length === 0 ? (
        <Put x={3} y={hy + 1} cls="dim">
          NO ROOMS TO LET.
        </Put>
      ) : (
        <>
          <Put x={3} y={hy} cls="dim">
            OUTPOST
          </Put>
          <Put x={colA} y={hy} cls="dim">
            ADMITS
          </Put>
          <Put x={colR} y={hy} cls="dim">
            {narrow ? 'RES' : 'RESIDENTS'}
          </Put>
        </>
      )}
      {shown.map((o, i) => {
        const y = hy + 2 + i * step;
        const [mode, modeCls] = MODES[o.mode] || MODES.closed;
        const blocks = Math.max(0, Math.min(o.residents, blockRoom));
        return (
          <Fragment key={o.ref}>
            <Put x={3} y={y}>
              {cutName(o.name.toUpperCase(), nameW)}
            </Put>
            <Put x={colA} y={y} cls={modeCls}>
              {mode}
            </Put>
            <Put x={colR} y={y}>
              {String(o.residents).padStart(3, ' ')}
            </Put>
            {Array.from({ length: blocks }, (_, k) => (
              <Blocks
                key={k}
                x={colR + 5 + k * 2}
                y={y}
                n={1}
                cls="dim"
                frac={0.5}
              />
            ))}
            {keys(o, narrow ? y + 1 : y)}
            {i < shown.length - 1 && (
              <Rule x={1} y={y + step - 1.5} w={cols - 2} />
            )}
          </Fragment>
        );
      })}
      {pages > 1 && (
        <>
          <Btn
            x={right - 13}
            y={bottom - 1}
            right
            label="<"
            disabled={shownPage === 0}
            onClick={() => setPage(shownPage - 1)}
          />
          <Put x={right - 11} y={bottom - 1} cls="dim">
            {`${shownPage + 1}/${pages}`}
          </Put>
          <Btn
            x={right}
            y={bottom - 1}
            right
            label=">"
            disabled={shownPage >= pages - 1}
            onClick={() => setPage(shownPage + 1)}
          />
        </>
      )}
    </Frame>
  );
}
