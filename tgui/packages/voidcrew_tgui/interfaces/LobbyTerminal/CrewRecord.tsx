/**
 * The record pane of one crew: memo, berths with SIGN ON, CODE / NOTE + APPLY for locked
 * crews, PING CREW when every berth is taken. Package P2.
 */
import { type ReactNode, useState } from 'react';
import { useBackend } from 'tgui/backend';

import {
  Blocks,
  Btn,
  Field,
  Frame,
  Put,
  pad,
  RPut,
  Rule,
  TOP,
  wrap,
} from './term';
import type { Crew, LobbyData } from './types';

/** SHIP_JOIN_PASSWORD_MAX_LEN and SHIP_APPLICATION_MESSAGE_MAX_LEN (voidcrew/_DEFINES/overmap.dm). */
const CODE_MAX = 24;
const NOTE_MAX = 200;

/** Seconds as m:ss. */
export function clock(seconds: number): string {
  const m = Math.floor(seconds / 60);
  const s = seconds % 60;
  return `${m}:${s < 10 ? '0' : ''}${s}`;
}

/** Cuts to n characters without padding; a cut ends in '.'. */
export function cut(str: string, n: number): string {
  return str.length > n ? `${str.slice(0, Math.max(0, n - 1))}.` : str;
}

/** Locked and not yet cleared to board. */
export const isLocked = (c: Crew) => !!c.locked && !c.cleared;

type Props = {
  crew: Crew;
  x: number;
  w: number;
  h: number;
  /** Narrow layout: the record has the whole screen and closes with BACK. */
  narrow: boolean;
  onClose: () => void;
};

export function CrewRecord(props: Props) {
  const { crew: c, x, w, h, narrow, onClose } = props;
  const { act } = useBackend<LobbyData>();
  const [code, setCode] = useState('');
  const [note, setNote] = useState('');
  const bottom = TOP + h - 1;
  const out: ReactNode[] = [];
  let y = TOP + 2;

  const closeLabel = narrow ? ' BACK ' : ' X ';
  out.push(
    <Put
      key="close"
      x={x + w - 3 - closeLabel.length}
      y={TOP}
      cls="dim"
      hoverCls="inv"
      bg
      onClick={onClose}
    >
      {closeLabel}
    </Put>,
  );

  out.push(
    <Put key="cls" x={x + 3} y={y} cls="dim">
      {pad(c.cls.toUpperCase(), Math.max(1, w - 18))}
    </Put>,
    <RPut key="aboard" x={x + w - 3} y={y} cls="dim">
      {`${c.crew} ABOARD`}
    </RPut>,
  );
  y += 1;
  if (c.doors) {
    out.push(
      <Put key="doors" x={x + 3} y={y} cls="dim">
        DOORS
      </Put>,
      <Put key="doors2" x={x + 10} y={y} cls="amb">
        CREW ONLY
      </Put>,
    );
  }
  y += 2;

  const locked = isLocked(c) && !c.applied;
  // Rows the lower block needs: the code and note rows for a locked crew, one row otherwise.
  const tail = locked ? 7 : c.applied ? 3 : 1;

  if (c.memo) {
    const room = Math.max(1, bottom - y - tail - 6);
    const lines = wrap(`"${c.memo}"`, w - 6).slice(0, Math.min(5, room));
    for (const line of lines) {
      out.push(
        <Put key={`memo${y}`} x={x + 3} y={y}>
          {line}
        </Put>,
      );
      y++;
    }
    y += 1;
  }
  out.push(<Rule key="rule1" x={x + 1} y={y} w={w - 2} />);
  y += 1;

  if (!c.jobs.length) {
    out.push(
      <Put key="full" x={x + 3} y={y + 1} cls="red">
        NO BERTHS OPEN
      </Put>,
    );
    y += 3;
    if (c.ping_wait > 0) {
      out.push(
        <Put key="ping" x={x + 3} y={y} cls="faint">
          [ PING CREW ]
        </Put>,
        <Put key="pingw" x={x + 17} y={y} cls="faint">
          {clock(c.ping_wait)}
        </Put>,
      );
    } else {
      out.push(
        <Btn
          key="ping"
          x={x + 3}
          y={y}
          label="PING CREW"
          lit
          onClick={() => act('crew_ping', { ship: c.ref })}
        />,
      );
    }
    return <>{out}</>;
  }

  if (c.rejoin_wait > 0 && !locked) {
    y += 1;
    out.push(
      <Put key="rejoin" x={x + 3} y={y} cls="amb">
        {`BACK ABOARD IN ${clock(c.rejoin_wait)}`}
      </Put>,
    );
    y += 2;
  }

  const grey = locked || !!c.applied;
  const sign = '[ SIGN ON ]';
  // The job name gets the whole width up to SIGN ON; the open berths sit on the line under it.
  const nameW = Math.max(8, w - 3 - sign.length - 5);
  const maxBlocks = Math.max(1, Math.floor((nameW - 1) / 2));
  // Name, berths and a spacer per job; drop the spacer when that would not fit.
  const step = y + c.jobs.length * 3 + tail <= bottom ? 3 : 2;
  const jobRoom = Math.max(1, Math.floor((bottom - y - tail) / step));
  for (const job of c.jobs.slice(0, jobRoom)) {
    const usable = !grey && !!job.ok && c.rejoin_wait <= 0;
    out.push(
      <Put key={`j${job.ref}`} x={x + 3} y={y} cls={grey ? 'dim' : ''}>
        {pad(job.title.toUpperCase(), nameW)}
      </Put>,
    );
    const shown = Math.min(job.open, maxBlocks);
    for (let i = 0; i < shown; i++) {
      out.push(
        <Blocks
          key={`b${job.ref}-${i}`}
          x={x + 3 + i * 2}
          y={y + 1}
          n={1}
          cls={grey ? 'dim' : ''}
          frac={0.5}
        />,
      );
    }
    out.push(
      <Btn
        key={`s${job.ref}`}
        x={x + w - 3}
        y={y}
        right
        label="SIGN ON"
        disabled={!usable}
        onClick={() => act('crew_sign_on', { ship: c.ref, job: job.ref })}
      />,
    );
    y += step;
  }

  if (locked) {
    out.push(<Rule key="rule2" x={x + 1} y={y} w={w - 2} />);
    y += 2;
    const waiting = c.code_wait > 0;
    const sendCode = () => {
      if (!code.trim() || waiting) {
        return;
      }
      act('crew_code', { ship: c.ref, code });
      setCode('');
    };
    out.push(
      <Put key="codel" x={x + 3} y={y} cls="amb">
        CODE
      </Put>,
      <Field
        key="codef"
        x={x + 9}
        y={y}
        w={10}
        value={code}
        max={CODE_MAX}
        disabled={waiting}
        secret
        onChange={setCode}
        onEnter={sendCode}
      />,
      <Btn
        key="codeb"
        x={x + 22}
        y={y}
        label="ENTER"
        amber
        disabled={waiting}
        onClick={sendCode}
      />,
    );
    if (waiting) {
      out.push(
        <Put key="codew" x={x + 34} y={y} cls="faint">
          {clock(c.code_wait)}
        </Put>,
      );
    }
    y += 2;
    const sendNote = () => {
      act('crew_apply', { ship: c.ref, note });
      setNote('');
    };
    out.push(
      <Put key="notel" x={x + 3} y={y} cls="amb">
        NOTE
      </Put>,
      <Field
        key="notef"
        x={x + 9}
        y={y}
        w={Math.max(8, w - 14)}
        value={note}
        max={NOTE_MAX}
        onChange={setNote}
        onEnter={sendNote}
      />,
    );
    y += 2;
    out.push(
      <Btn
        key="apply"
        x={x + 3}
        y={y}
        label="APPLY"
        lit
        amber
        onClick={sendNote}
      />,
    );
  } else if (c.applied) {
    out.push(<Rule key="rule2" x={x + 1} y={y} w={w - 2} />);
    y += 2;
    out.push(
      <Put key="applied" x={x + 3} y={y} cls="faint">
        [ APPLIED ]
      </Put>,
    );
  }

  return <>{out}</>;
}

/** The record pane with its frame. */
export function CrewRecordPane(props: Props) {
  const { crew, x, w, h } = props;
  return (
    <Frame
      x={x}
      y={TOP}
      w={w}
      h={h}
      title={cut(crew.name.toUpperCase(), w - 14)}
    >
      <CrewRecord key={crew.ref} {...props} />
    </Frame>
  );
}
