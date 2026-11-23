/**
 * The side menu (side mode) and the key bar with its MENU list (bar mode).
 *
 * Side menu, rows of the menu region: the symbol, the wordmark, READY (or IN LINE), OBSERVE,
 * CHARACTER with the character's name under it, a rule, the five utility items, START for a
 * local admin, and the credit line at the foot. Its box ends level with the main box.
 *
 * Bar mode keeps READY (or IN LINE), OBSERVE, CHARACTER and START as keys along the bottom and
 * folds the utility items into MENU. The symbol, wordmark, credit and character name are cut.
 */
import { useEffect, useState } from 'react';
import { useBackend } from 'tgui/backend';

import { Emblem } from './Emblem';
import { sfx, useBlink, useChanged, useChangedNow } from './motion';
import { Back, FocusScope } from './nav';
import {
  Box,
  type Cls,
  HRule,
  Key,
  type KeyKind,
  type KeyState,
  Put,
  safe,
  useGrid,
  WipeAt,
  wrapMax,
} from './term';
import type { LobbyData } from './types';

/** How long READY's fill takes to sweep in, and to retract, in ms. */
const READY_ON_MS = 180;
const READY_OFF_MS = 120;

/**
 * The top key shows before the round (READY) and, once it runs, only while the player is in
 * the popcap line. Joining itself is SIGN ON, COMMISSION or MOVE IN on the tabs.
 */
const hasTop = (data: LobbyData) =>
  data.phase === 'loading' ||
  data.phase === 'pregame' ||
  data.phase === 'setup' ||
  (data.phase === 'playing' && (data.queue > 0 || !!data.queue_go));

/** READY before the round; IN LINE / YOUR TURN while waiting for a place. */
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
  const go = !!data.queue_go;
  return {
    label: go ? 'YOUR TURN' : 'IN LINE',
    right: go ? '' : String(Math.min(999, data.queue)),
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
  // Before the paint, so the key is never drawn already filled ahead of its sweep.
  useChangedNow(!!data.ready, (_, ready) => {
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
  /** Instead of sending `action`: SETTINGS opens the terminal's own screen. */
  onClick?: () => void;
};

/**
 * WIKI, RULES, DISCORD, POLLS, MANIFEST, SETTINGS, CHANGELOG. SETTINGS opens the terminal's SETTINGS
 * screen (lit while it is open); WIKI, RULES and DISCORD open the server's pages in the player's
 * browser. POLLS, MANIFEST and CHANGELOG are switched off for now and draw dead.
 */
function utilities(
  data: LobbyData,
  settings?: Pick<MenuProps, 'settingsOpen' | 'onSettings'>,
): Util[] {
  return [
    { label: 'WIKI', action: 'wiki', state: data.wiki ? 'idle' : 'dead' },
    { label: 'RULES', action: 'rules', state: data.rules ? 'idle' : 'dead' },
    {
      label: 'DISCORD',
      action: 'discord',
      state: data.discord ? 'idle' : 'dead',
    },
    { label: 'POLLS', action: 'polls', state: 'dead' },
    { label: 'MANIFEST', action: 'manifest', state: 'dead' },
    {
      label: 'SETTINGS',
      action: 'settings',
      state: !data.prefs_ready
        ? 'dead'
        : settings?.settingsOpen
          ? 'lit'
          : 'idle',
      onClick: settings?.onSettings,
    },
    { label: 'CHANGELOG', action: 'changelog', state: 'dead' },
  ];
}

const canStart = (data: LobbyData) =>
  !!data.localhost_admin &&
  (data.phase === 'loading' || data.phase === 'pregame');

/** The credit line at the foot of the side menu. */
const CREDIT = 'AN ORIGINAL SERVER MADE BY JACKRIP';

const beforeRound = (data: LobbyData) =>
  data.phase === 'loading' || data.phase === 'pregame';

type MenuProps = {
  /** The CHARACTER screen is open. */
  charOpen: boolean;
  onCharacter: () => void;
  /** The SETTINGS screen is open. */
  settingsOpen: boolean;
  onSettings: () => void;
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
  const fullName = safe(data.char_name).toUpperCase();
  // Up to two lines under CHARACTER; a second line pushes the rule and the list down a row.
  const name = fullName ? wrapMax(fullName, 15, 2) : [];
  // Without the top key, everything under it moves up into its place.
  const top = hasTop(data);
  const dy = top ? 0 : -2.25;
  // The rule sits a quarter row under the name, as the name sits a quarter row under CHARACTER.
  const ruleY = 15.25 + dy + Math.max(0, name.length - 1);
  // Utility rows: 1.25 rows each when the menu has room (as in the approved stills), else 1.
  const start = canStart(data);
  const utils = utilities(data, props);
  const items = utils.length + (start ? 1 : 0);
  // The foot of the menu carries the server's credit line, with half a row free above it. On a
  // short menu where the list would run into it, the credit gives way.
  const credit = wrapMax(CREDIT, 17, 3);
  const roomWith = boxH - (credit.length + 0.5) - 0.5 - (ruleY + 0.5);
  const port = roomWith >= items ? credit : [];
  const room = port.length ? roomWith : boxH - 0.5 - (ruleY + 0.5);
  // The credit's last line sits half a row above the box's foot.
  const portY = boxH - 0.5 - port.length;
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
      {!!top && <TopKey x={1} y={8.25} w={17} h={2} kind="big" />}
      <Key
        x={1}
        y={10.5 + dy}
        w={17}
        kind="box"
        label="OBSERVE"
        state={data.can_observe ? 'idle' : 'dead'}
        zone="menu"
        onClick={onObserve}
      />
      <Key
        x={1}
        y={12.25 + dy}
        w={17}
        kind="box"
        label="CHARACTER"
        state={!prefs ? 'dead' : charOpen ? 'lit' : 'idle'}
        zone="menu"
        onClick={onCharacter}
      />
      {name.map((line, i) => (
        <Put
          key={i}
          x={2}
          y={14 + dy + i}
          cls={prefs ? 'dim' : 'faint'}
          title={fullName}
        >
          {line}
        </Put>
      ))}
      <HRule x={1} y={ruleY} w={17} />
      {utils.map((u, i) => (
        <Key
          key={u.label}
          x={1}
          y={ruleY + 0.5 + i * step}
          w={17}
          h={step}
          kind="plain"
          label={u.label}
          state={u.state}
          zone="menu"
          onClick={u.onClick || (() => act(u.action))}
        />
      ))}
      {!!start && (
        <Key
          x={1}
          y={ruleY + 0.5 + (items - 1) * step}
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
  // Without the top key the others move left into its place.
  const top = hasTop(data);
  const dx = top ? 0 : -16;
  return (
    <>
      {!!top && <TopKey x={0} y={0} w={15} kind="box" />}
      <Key
        x={16 + dx}
        y={0}
        w={9}
        kind="box"
        label="OBSERVE"
        state={data.can_observe ? 'idle' : 'dead'}
        zone="menu"
        onClick={onObserve}
      />
      <Key
        x={26 + dx}
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
          x={38 + dx}
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
        state={menuOpen ? 'lit' : 'idle'}
        zone="menu"
        onClick={onMenu}
      />
    </>
  );
}

/** MENU's list in bar mode, over the bottom right of the main region. */
export function MenuPopup(
  props: Pick<MenuProps, 'settingsOpen' | 'onSettings'> & {
    onClose: () => void;
  },
) {
  const { onClose } = props;
  const { data, act } = useBackend<LobbyData>();
  const { rows } = useGrid();
  const items = utilities(data, props);
  // One row an item and half a row above and below.
  const h = items.length + 1;
  const y = rows - h;
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
        <Box x={44} y={y} w={19} h={h} tone="bg" bright />
        <WipeAt x={44} y={y} w={19} h={h} k={0} kind="screen" first z={9} />
        <FocusScope>
          <Back fn={onClose} />
          {items.map((u, i) => (
            <Key
              key={u.label}
              x={45}
              y={y + 0.5 + i}
              w={17}
              kind="plain"
              label={u.label}
              state={u.state}
              auto={i === first ? 9 : undefined}
              zone="menu"
              onClick={() => {
                onClose();
                if (u.onClick) {
                  u.onClick();
                } else {
                  act(u.action);
                }
              }}
            />
          ))}
        </FocusScope>
      </div>
    </>
  );
}
