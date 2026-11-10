import { useEffect, useState } from 'react';
import { useBackend } from 'tgui/backend';

import { Put, pad, RPut, Rule, useGrid } from './term';
import type { LobbyData, TabId } from './types';

const TABS: [TabId, string][] = [
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

/** Title bar (row 0), tab bar (row 2) and its rule (row 3). */
export function Header(props: { tab: TabId; setTab: (tab: TabId) => void }) {
  const { tab, setTab } = props;
  const { data } = useBackend<LobbyData>();
  const { cols, narrow } = useGrid();
  const elapsed = useElapsed(data.clock);

  const title = data.port
    ? ` ${data.port.toUpperCase()}  :  BERTH OFFICE`
    : ' BERTH OFFICE';
  let right = clockText(data, elapsed);
  if (data.phase !== 'playing' || !narrow) {
    right = `${data.online} ONLINE   ${right}`;
  }
  if (data.admin_ready) {
    const [ready, admins, adminTotal] = data.admin_ready;
    right = `${ready} READY  ${admins}/${adminTotal} ADM   ${right}`;
  }

  let x = 1;
  const tabs = TABS.map(([id, label]) => {
    const text = ` ${label} `;
    const at = x;
    x += text.length + 3;
    return (
      <Put
        key={id}
        x={at}
        y={2}
        cls={id === tab ? 'inv' : 'dim'}
        hoverCls={id === tab ? 'inv' : ''}
        onClick={() => setTab(id)}
      >
        {text}
      </Put>
    );
  });

  return (
    <>
      <Put x={0} y={0} cls="inv">
        {pad(title, cols)}
      </Put>
      <RPut x={cols - 1} y={0} cls="inv" bg={false}>
        {right}
      </RPut>
      {tabs}
      <Rule x={0} y={3} w={cols} />
    </>
  );
}
