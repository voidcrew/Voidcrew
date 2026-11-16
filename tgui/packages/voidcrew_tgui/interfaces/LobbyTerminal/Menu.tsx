/**
 * The side menu (side mode) and the key bar with its MENU list (bar mode).
 *
 * Side menu, rows of the menu region: the symbol, the wordmark, READY/JOIN, OBSERVE, CHARACTER
 * with the character's name under it, a rule, the five utility items, START for a local admin,
 * and the station name at the foot. Its box ends level with the main box.
 *
 * Bar mode keeps READY/JOIN, OBSERVE, CHARACTER and START as keys along the bottom and folds
 * the utility items into MENU. The symbol, wordmark, station name and character name are cut.
 */
import { useEffect, useState } from 'react';
import { useBackend } from 'tgui/backend';

import { Emblem } from './Emblem';
import { sfx, useBlink, useChanged } from './motion';
import { FocusScope, useBack } from './nav';
import {
  Box,
  type Cls,
  cut,
  HRule,
  Key,
  type KeyKind,
  type KeyState,
  Put,
  RPut,
  safe,
  useGrid,
  WipeAt,
  wrapMax,
} from './term';
import type { LobbyData } from './types';

/** How long READY's fill takes to sweep in, and to retract, in ms. */
const READY_ON_MS = 180;
const READY_OFF_MS = 120;

/** READY before the round, JOIN once it runs. */
function topKey(data: LobbyData, sweep: 'on' | 'off' | null, now: boolean) {
  const { phase } = data;
  const ready = !!data.ready;
  if (phase === 'loading' || phase === 'pregame' || phase === 'setup') {
    // While the fill sweeps in the key keeps its rest look under it; [#] shows when it lands.
    const on = ready && sweep !== 'on';
    return {
      label: 'READY',
      right: on ? '[#]' : '[ ]',
      rightCls: undefined as Cls | undefined,
      state: (phase === 'setup' ? 'dead' : on ? 'on' : 'idle') as KeyState,
      action: 'ready',
    };
  }
  let right = '';
  if (phase === 'playing' && data.queue_go) {
    right = 'NOW';
  } else if (phase === 'playing' && data.queue > 0) {
    right = `LINE ${Math.min(999, data.queue)}`;
  }
  return {
    label: 'JOIN',
    right,
    rightCls: 'amb' as Cls,
    // First in line with a place free: the key takes the accent fill every other half second.
    state: (phase !== 'playing' ? 'dead' : now ? 'on' : 'idle') as KeyState,
    action: 'join',
  };
}

/**
 * The READY / JOIN key of the side menu and of the key bar.
 *
 * READY's fill follows what the server says, not the press: it sweeps in left to right when
 * the player becomes ready and retracts when they stop. In line, the place flashes when it
 * changes, and the key blinks when the player is first and a place is free.
 */
function TopKey(props: {
  x: number;
  y: number;
  w: number;
  h?: number;
  kind: KeyKind;
}) {
  const { data, act } = useBackend<LobbyData>();
  const { phase } = data;
  const before = phase === 'loading' || phase === 'pregame';
  const [sweep, setSweep] = useState<'on' | 'off' | null>(null);
  useChanged(!!data.ready, (_, ready) => {
    if (before) {
      setSweep(ready ? 'on' : 'off');
      sfx(ready ? 'ready_on' : 'ready_off');
    }
  });
  useEffect(() => {
    if (!sweep) {
      return;
    }
    const id = setTimeout(
      () => setSweep(null),
      sweep === 'on' ? READY_ON_MS : READY_OFF_MS,
    );
    return () => clearTimeout(id);
  }, [sweep]);
  const queue = phase === 'playing' ? data.queue : 0;
  useChanged(queue, (_, place) => {
    if (place > 0) {
      sfx('queue');
    }
  });
  const now = useBlink(phase === 'playing' && !!data.queue_go, 500);
  const top = topKey(data, before ? sweep : null, now);
  return (
    <Key
      {...props}
      label={top.label}
      right={top.right}
      rightCls={top.rightCls}
      rightPulse={queue}
      state={top.state}
      sweep={before ? sweep : null}
      auto={beforeRound(data) ? 9 : undefined}
      zone="menu"
      onClick={() => act(top.action)}
    />
  );
}

type Util = {
  label: string;
  action: string;
  state: KeyState;
  right?: string;
};

/** WIKI, POLLS, MANIFEST, SETTINGS, CHANGELOG: they open the game's own windows. */
function utilities(data: LobbyData): Util[] {
  return [
    { label: 'WIKI', action: 'wiki', state: data.wiki ? 'idle' : 'dead' },
    {
      label: 'POLLS',
      action: 'polls',
      state: data.polls ? 'idle' : 'dead',
      right: data.polls === 2 ? 'NEW' : undefined,
    },
    { label: 'MANIFEST', action: 'manifest', state: 'idle' },
    {
      label: 'SETTINGS',
      action: 'settings',
      state: data.prefs_ready ? 'idle' : 'dead',
    },
    { label: 'CHANGELOG', action: 'changelog', state: 'idle' },
  ];
}

const canStart = (data: LobbyData) =>
  !!data.localhost_admin &&
  (data.phase === 'loading' || data.phase === 'pregame');

const beforeRound = (data: LobbyData) =>
  data.phase === 'loading' || data.phase === 'pregame';

type MenuProps = {
  /** The CHARACTER screen is open. */
  charOpen: boolean;
  onCharacter: () => void;
  onObserve: () => void;
};

/** The side menu, drawn in the 19-column menu region. */
export function SideMenu(props: MenuProps) {
  const { charOpen, onCharacter, onObserve } = props;
  const { data, act } = useBackend<LobbyData>();
  const { rows, cw, ch } = useGrid();
  const prefs = !!data.prefs_ready;
  // The box ends level with the main box (one row above the region's foot).
  const boxH = rows - 1;
  const k = Math.max(1, Math.floor((15 * cw) / 64));
  const name = cut(safe(data.char_name).toUpperCase(), 15);
  const port = wrapMax(safe(data.port).toUpperCase(), 17, 2);
  // The last line sits half a row above the box's foot; one-line names sit on the lower line.
  const portY = boxH - 0.5 - port.length;
  // Utility rows: 1.25 rows each when the menu has room (as in the approved stills), else 1.
  // Two station-name lines and half a row are always kept free above the foot.
  const start = canStart(data);
  const items = utilities(data).length + (start ? 1 : 0);
  const room = boxH - 2.5 - 0.5 - 15.5;
  const step = room >= items * 1.25 ? 1.25 : 1;
  return (
    <>
      <Box x={0} y={0} w={19} h={boxH} tone="menu" />
      <Emblem
        size={64}
        px={k}
        speed={0.5}
        fps={12}
        className="lt-emblem"
        style={{
          left: Math.round(9.5 * cw - 32 * k),
          top: Math.round(3.5 * ch - 32 * k),
        }}
      />
      <Put x={2} y={6.75} cls="wht lt-wordmark">
        V O I D C R E W
      </Put>
      <TopKey x={1} y={8.25} w={17} h={2} kind="big" />
      <Key
        x={1}
        y={10.5}
        w={17}
        kind="box"
        label="OBSERVE"
        state={data.can_observe ? 'idle' : 'dead'}
        zone="menu"
        onClick={onObserve}
      />
      <Key
        x={1}
        y={12.25}
        w={17}
        kind="box"
        label="CHARACTER"
        state={!prefs ? 'dead' : charOpen ? 'lit' : 'idle'}
        zone="menu"
        onClick={onCharacter}
      />
      {!!name && (
        <RPut x={17} y={13.75} cls="dim">
          {name}
        </RPut>
      )}
      <HRule x={1} y={15} w={17} />
      {utilities(data).map((u, i) => (
        <Key
          key={u.label}
          x={1}
          y={15.5 + i * step}
          w={17}
          h={step}
          kind="plain"
          label={u.label}
          right={u.right}
          rightCls="amb"
          state={u.state}
          zone="menu"
          onClick={() => act(u.action)}
        />
      ))}
      {!!start && (
        <Key
          x={1}
          y={15.5 + (items - 1) * step}
          w={17}
          h={step}
          kind="plain"
          label="START"
          labelCls="wht"
          zone="menu"
          onClick={() => act('start_now')}
        />
      )}
      {port.map((line, i) => (
        <Put
          key={i}
          x={1 + Math.floor((17 - line.length) / 2)}
          y={portY + i}
          cls="dim"
        >
          {line}
        </Put>
      ))}
    </>
  );
}

/** The key bar along the bottom in bar mode (its own 1.5-row region). */
export function KeyBar(
  props: MenuProps & { menuOpen: boolean; onMenu: () => void },
) {
  const { charOpen, onCharacter, onObserve, menuOpen, onMenu } = props;
  const { data, act } = useBackend<LobbyData>();
  return (
    <>
      <TopKey x={0} y={0} w={15} kind="box" />
      <Key
        x={16}
        y={0}
        w={9}
        kind="box"
        label="OBSERVE"
        state={data.can_observe ? 'idle' : 'dead'}
        zone="menu"
        onClick={onObserve}
      />
      <Key
        x={26}
        y={0}
        w={11}
        kind="box"
        label="CHARACTER"
        state={!data.prefs_ready ? 'dead' : charOpen ? 'lit' : 'idle'}
        zone="menu"
        onClick={onCharacter}
      />
      {!!canStart(data) && (
        <Key
          x={38}
          y={0}
          w={7}
          kind="box"
          label="START"
          labelCls="wht"
          zone="menu"
          onClick={() => act('start_now')}
        />
      )}
      <Key
        x={57}
        y={0}
        w={6}
        kind="box"
        label="MENU"
        labelCls={data.polls === 2 ? 'amb' : undefined}
        state={menuOpen ? 'lit' : 'idle'}
        zone="menu"
        onClick={onMenu}
      />
    </>
  );
}

/** MENU's list in bar mode, over the bottom right of the main region. */
export function MenuPopup(props: { onClose: () => void }) {
  const { onClose } = props;
  const { data, act } = useBackend<LobbyData>();
  const { rows } = useGrid();
  useBack(onClose);
  const y = rows - 6;
  const items = utilities(data);
  const first = items.findIndex((u) => u.state !== 'dead');
  return (
    <>
      <div
        className="lt-sheet"
        onClick={(e) => {
          e.stopPropagation();
          onClose();
        }}
      />
      <div className="lt-dialog">
        <Box x={44} y={y} w={19} h={6} tone="bg" bright />
        <WipeAt x={44} y={y} w={19} h={6} k={0} kind="screen" first z={9} />
        <FocusScope>
          {items.map((u, i) => (
            <Key
              key={u.label}
              x={45}
              y={y + 0.5 + i}
              w={17}
              kind="plain"
              label={u.label}
              right={u.right}
              rightCls="amb"
              state={u.state}
              auto={i === first ? 9 : undefined}
              zone="menu"
              onClick={() => {
                onClose();
                act(u.action);
              }}
            />
          ))}
        </FocusScope>
      </div>
    </>
  );
}
