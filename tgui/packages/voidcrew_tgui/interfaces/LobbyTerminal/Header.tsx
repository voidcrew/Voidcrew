import { Fragment, useEffect, useState } from 'react';
import { useBackend } from 'tgui/backend';

import { Band, cut, HRule, Put, RPut, useGrid } from './term';
import type { LobbyData, TabId } from './types';

export const TABS: [TabId, string][] = [
  ['crews', 'CREWS'],
  ['shipyard', 'SHIPYARD'],
  ['housing', 'HOUSING'],
  ['character', 'CHARACTER'],
];

const two = (n: number) => String(Math.floor(n)).padStart(2, '0');

function hms(seconds: number) {
  const t = Math.max(0, Math.floor(seconds));
  return `${two(t / 3600)}:${two((t % 3600) / 60)}:${two(t % 60)}`;
}

function ms(seconds: number) {
  const t = Math.max(0, Math.floor(seconds));
  return `${two(t / 60)}:${two(t % 60)}`;
}

/** Seconds since the last server value arrived, ticking once a second. */
function useElapsed(stamp: number) {
  const [since, setSince] = useState(() => Date.now());
  const [now, setNow] = useState(() => Date.now());
  useEffect(() => {
    setSince(Date.now());
    setNow(Date.now());
  }, [stamp]);
  useEffect(() => {
    const id = setInterval(() => setNow(Date.now()), 1000);
    return () => clearInterval(id);
  }, []);
  return Math.max(0, (now - since) / 1000);
}

function clockText(data: LobbyData, elapsed: number): string {
  const { phase, clock } = data;
  switch (phase) {
    case 'playing':
      return hms(clock / 10 + elapsed);
    case 'loading':
    case 'pregame':
      if (clock < 0) {
        return 'DEPARTURE DELAYED';
      }
      return clock > 0 ? `DEPARTURE ${ms(clock - elapsed)}` : 'DEPARTURE SOON';
    case 'setup':
      return 'DEPARTING';
    default:
      return 'PORT CLOSED';
  }
}

/**
 * Header band (its own region, 1.5 rows): BERTH OFFICE at column 2, the counts and the clock
 * ending at column cols - 3. The clock and the admin counts always draw; the title gives way
 * whole, then the online count.
 */
export function HeaderBand() {
  const { data } = useBackend<LobbyData>();
  const { cols } = useGrid();
  const elapsed = useElapsed(data.clock);
  const clock = clockText(data, elapsed);
  const admin = data.admin_ready
    ? `${data.admin_ready[0]} READY  ${data.admin_ready[1]}/${data.admin_ready[2]} ADM`
    : '';
  const online = `${data.online} ONLINE`;
  const room = cols - 4;
  const join = (parts: string[]) => parts.filter(Boolean).join('   ');
  let right = join([admin, online, clock]);
  let title = 'BERTH OFFICE';
  if (title.length + 3 + right.length > room) {
    title = '';
  }
  if (right.length > room) {
    right = join([admin, clock]);
  }
  return (
    <>
      <Band x={0} y={0} w={cols} h={1.5} tone="bar" />
      {!!title && (
        <Put x={2} y={0.25} cls="wht nog">
          {title}
        </Put>
      )}
      <RPut x={cols - 2} y={0.25} cls="wht nog">
        {cut(right, room)}
      </RPut>
    </>
  );
}

/** Tab blocks in main-region columns: [first column, width]. */
const TAB_BLOCKS: Record<TabId, [number, number]> = {
  crews: [0, 7],
  shipyard: [8, 10],
  housing: [19, 9],
  // Until the side menu's CHARACTER key exists, CHARACTER stays reachable here.
  character: [30, 11],
};

/** Tab row at the top of the main region (rows 0 to 1.5) and the rule under it. */
export function TabRow(props: { tab: TabId; setTab: (tab: TabId) => void }) {
  const { tab, setTab } = props;
  const { cols } = useGrid();
  return (
    <>
      {TABS.map(([id, label]) => {
        const [bx, bw] = TAB_BLOCKS[id];
        const open = id === tab;
        return (
          <Fragment key={id}>
            {!!open && <Band x={bx} y={0} w={bw} h={1.5} tone="accent" />}
            <Put
              x={bx + 1}
              y={0.25}
              cls={open ? 'ink' : 'dim'}
              hoverCls={open ? 'ink' : ''}
              onClick={() => setTab(id)}
              tab
            >
              {label}
            </Put>
          </Fragment>
        );
      })}
      <HRule x={0} y={1.75} w={cols} />
    </>
  );
}
