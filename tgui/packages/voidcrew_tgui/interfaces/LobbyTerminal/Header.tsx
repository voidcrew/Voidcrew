import { Fragment, useEffect, useState } from 'react';
import { useBackend } from 'tgui/backend';

import { sfx, useChanged } from './motion';
import { Band, cut, HRule, Put, RPut, useGrid } from './term';
import type { LobbyData, TabId } from './types';

/**
 * The screens in keyboard order: 1 to 4 and Tab step through them. Only the first three are
 * tabs; CHARACTER is opened from the menu and lights no tab.
 */
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

/** The departure clock's last seconds: the clock ticks and turns amber every other second. */
const LAST_SECONDS = 10;

/**
 * Header band (its own region, 1.5 rows): BERTH OFFICE at column 2, the counts and the clock
 * ending at column cols - 3. The clock and the admin counts always draw; the title gives way
 * whole, then the online count.
 *
 * In the last ten seconds before departure the clock is amber and white in turn, with a tick
 * a second that rises in pitch; DEPARTING blinks three times when it appears.
 */
export function HeaderBand() {
  const { data } = useBackend<LobbyData>();
  const { cols } = useGrid();
  const elapsed = useElapsed(data.clock);
  const clock = clockText(data, elapsed);
  const counting =
    (data.phase === 'loading' || data.phase === 'pregame') && data.clock > 0;
  const left = counting ? Math.max(0, Math.floor(data.clock - elapsed)) : -1;
  const last = left > 0 && left <= LAST_SECONDS ? left : 0;
  useChanged(last, (_, now) => {
    if (now > 0) {
      sfx('clock', { rate: 1 + (LAST_SECONDS - now) * 0.05 });
    }
  });
  const departing = data.phase === 'setup';
  const clockCls = `${last % 2 === 1 ? 'amb' : 'wht'} nog${departing ? ' lt-blink3' : ''}`;
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
  // The clock is its own piece of text, so it can change colour and blink by itself.
  const whole = right.length <= room && right.endsWith(clock);
  const before = whole ? right.slice(0, right.length - clock.length) : '';
  return (
    <>
      <Band x={0} y={0} w={cols} h={1.5} tone="bar" />
      {!!title && (
        <Put x={2} y={0.25} cls="wht nog">
          {title}
        </Put>
      )}
      {!!before && (
        <RPut x={cols - 2 - clock.length} y={0.25} cls="wht nog">
          {before}
        </RPut>
      )}
      <RPut
        key={departing ? 'departing' : 'clock'}
        x={cols - 2}
        y={0.25}
        cls={whole ? clockCls : 'wht nog'}
      >
        {whole ? clock : cut(right, room)}
      </RPut>
    </>
  );
}

/** Tab blocks in main-region columns: [first column, width]. */
const TAB_BLOCKS: Partial<Record<TabId, [number, number]>> = {
  crews: [0, 7],
  shipyard: [8, 10],
  housing: [19, 9],
};

/**
 * Tab row at the top of the main region (rows 0 to 1.5) and the rule under it. While the
 * CHARACTER screen is open no tab is lit. `claim`: the open tab claims the first focus at that
 * priority (nav.tsx FocusOpts.auto).
 */
export function TabRow(props: {
  tab: TabId;
  setTab: (tab: TabId) => void;
  claim?: number;
}) {
  const { tab, setTab, claim } = props;
  const { cols } = useGrid();
  return (
    <>
      {TABS.map(([id, label]) => {
        const block = TAB_BLOCKS[id];
        if (!block) {
          return null;
        }
        const [bx, bw] = block;
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
              auto={open ? claim : undefined}
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
