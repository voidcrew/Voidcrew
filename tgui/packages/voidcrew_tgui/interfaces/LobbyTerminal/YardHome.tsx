/**
 * SHIPYARD home: NEW SHIP with the parts on account, the surplus hull, SAVED SHIPS.
 * Still the old layout (compatibility path) until its redesign lands.
 */
import type { ReactNode } from 'react';
import { useBackend } from 'tgui/backend';

import { SaveSlots } from './SaveSlots';
import {
  Btn,
  Frame,
  LEGACY_NARROW,
  Put,
  RPut,
  LEGACY_TOP as TOP,
  useGrid,
} from './term';
import type { LobbyData } from './types';
import { PART_ORDER, type YardCtx } from './YardTab';

export function YardHome(props: { ctx: YardCtx }) {
  const { ctx } = props;
  const { data } = useBackend<LobbyData>();
  const { cols, rows } = useGrid();
  const narrow = LEGACY_NARROW;
  const bottom = rows - 1;
  const req = !!data.can_requisition;
  const account = data.account || {};
  const reqLine = ctx.crewChange
    ? `LEAVES ${ctx.crewChange.toUpperCase()}`
    : 'SURPLUS HULL';

  const requisition = () =>
    ctx.found({ action: 'yard_requisition', params: {}, label: 'REQUISITION' });
  const newShip = () => ctx.go.hulls();

  const out: ReactNode[] = [];
  let th = 5;
  const y = TOP + 2;
  if (narrow) {
    // One box: NEW SHIP and the parts on account, the surplus hull below.
    th = req ? 6 : 5;
    out.push(
      <Frame key="ns" x={0} y={TOP} w={cols} h={th} title="NEW SHIP" />,
      <Btn key="nsk" x={3} y={y} label="NEW SHIP" lit onClick={newShip} auto={1} />,
    );
    const short = PART_ORDER.map(
      (k) => `${k.slice(0, 3).toUpperCase()} ${account[k] || 0}`,
    ).join('  ');
    if (cols - 20 >= short.length) {
      out.push(
        <RPut key="nsp" x={cols - 3} y={y} cls="dim">
          {short}
        </RPut>,
      );
    }
    if (req) {
      out.push(
        <Put key="rl" x={3} y={y + 1} cls="amb">
          {reqLine.slice(0, cols - 24)}
        </Put>,
        <Btn
          key="rk"
          x={cols - 3}
          y={y + 1}
          right
          label="REQUISITION"
          disabled={!ctx.open || ctx.sent}
          onClick={requisition}
        />,
      );
    }
  }

  const saves = data.saves;
  if (saves?.state === 'ok') {
    out.push(
      <SaveSlots
        key="saves"
        saves={saves.slots}
        x={0}
        y={TOP + th}
        w={cols}
        h={bottom - TOP - th}
        ctx={ctx}
      />,
    );
  }
  return <>{out}</>;
}
