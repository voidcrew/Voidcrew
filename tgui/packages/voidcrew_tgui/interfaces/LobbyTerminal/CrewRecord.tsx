/**
 * The record of one crew, in place of the CREWS list: class and aboard, the memo, BERTHS
 * (one row a job with its SIGN ON key, paged) beside ABOARD (names, captains marked), and
 * under the berths the CODE and NOTE rows of a locked crew or PING CREW for a full one.
 * `[ BACK ]` and the ship stepper sit in the tab row's right zone.
 *
 * Main-region rows: box from BOX_Y, body from BODY_Y to rows - 1.25, the notice row at
 * rows - 1. Columns: BERTHS 1 to 41, a rule in 43, ABOARD 45 to 61.
 */
import { type ReactNode, useEffect, useRef, useState } from 'react';
import { useBackend } from 'tgui/backend';

import { sfx, useChanged, useChangedNow } from './motion';
import { useBack, usePager } from './nav';
import {
  Band,
  BODY_Y,
  BOX_Y,
  Big,
  Box,
  Btn,
  bodyRows,
  cut,
  Field,
  FlashAt,
  HRule,
  Key,
  NameLine,
  Pager,
  Put,
  RPut,
  SEP,
  Slab,
  safe,
  useCellRect,
  useGrid,
  VRule,
  WipeAt,
  wrapMax,
} from './term';
import type { Crew, CrewJob, LobbyData } from './types';

/** SHIP_JOIN_PASSWORD_MAX_LEN and SHIP_APPLICATION_MESSAGE_MAX_LEN (voidcrew/_DEFINES/overmap.dm). */
const CODE_MAX = 24;
const NOTE_MAX = 200;

const YOUR_CREW = ' YOUR CREW ';
const DOORS = 'DOORS  CREW ONLY';
/** Line 1's left part. */
const LINE1_W = 43;
/** Memo width: columns 1 to 61. */
const MEMO_W = 61;
/**
 * Berth rows: title columns 3 to 24, count ending at 27, key 29 to 41 (13 wide, so the
 * 11-character label has a column clear of the key's edge on each side, as in the stills).
 */
const TITLE_W = 22;
const KEY_X = 29;
const KEY_W = 13;
/** CODE and NOTE fields: columns 6 to 27. */
const FIELD_W = 22;
const BERTH_PITCH = 1.75;
const BERTH_H = 1.5;
/** The widest pitch berth rows stretch to when they all fit, and the row height from which
 * a row may take the larger title and count. */
const BERTH_PITCH_MAX = 4;
const BERTH_TALL = 2.25;
/** ABOARD: columns 45 to 61. */
const ABOARD_X = 45;
const NAME_W = 17;
const CAPT_NAME_W = 12;

/** Seconds as m:ss. */
export function clock(seconds: number): string {
  const t = Math.max(0, Math.floor(seconds));
  const m = Math.floor(t / 60);
  const s = t % 60;
  return `${m}:${s < 10 ? '0' : ''}${s}`;
}

/** Locked and not yet cleared to board. */
export const isLocked = (c: Crew) => !!c.locked && !c.cleared;

/** `<Class> • <n> aboard`; the class drops out when the name already starts with it. */
export function classLine(c: Crew, name: string): string {
  const cls = safe(c.cls).trim();
  const aboard = `${Math.min(999, Math.max(0, c.crew || 0))} aboard`;
  if (!cls || name.toUpperCase().startsWith(cls.toUpperCase())) {
    return aboard;
  }
  return `${cls} ${SEP} ${aboard}`;
}

/**
 * A server countdown in seconds, ticking down once a second in the page from the last value
 * the server sent.
 */
function useCountdown(value: number): number {
  const base = useRef({ value, at: Date.now() });
  if (base.current.value !== value) {
    base.current = { value, at: Date.now() };
  }
  const [, tick] = useState(0);
  const live = value > 0;
  useEffect(() => {
    if (!live) {
      return;
    }
    const id = setInterval(() => tick((n) => n + 1), 1000);
    return () => clearInterval(id);
  }, [live]);
  if (!live) {
    return 0;
  }
  const gone = Math.floor((Date.now() - base.current.at) / 1000);
  return Math.max(0, base.current.value - gone);
}

/** A berth row coming alive after the code was accepted: its dead look lifts 40 ms after `delay`. */
function Light(props: { y: number; h: number; delay: number }) {
  const style = useCellRect(1, props.y, 41, props.h);
  return (
    <div
      className="lt-light"
      style={{ ...style, animationDelay: `${props.delay}ms` }}
    />
  );
}

/** Berth rows light this far apart, top to bottom, when a code is accepted. */
const LIGHT_GAP = 40;

type Props = {
  crew: Crew;
  /** 1-based place of this ship in the list order, and the list's length. */
  index: number;
  total: number;
  /** Open the ship at this 1-based place in the list order. */
  onStep: (to: number) => void;
  onClose: () => void;
};

export function CrewRecord(props: Props) {
  const { crew: c, index, total, onStep, onClose } = props;
  const { data, act } = useBackend<LobbyData>();
  const { rows } = useGrid();
  const [code, setCode] = useState('');
  const [note, setNote] = useState('');
  const [berthPage, setBerthPage] = useState(1);
  /** The job whose SIGN ON takes the focus when it mounts (paging). */
  const [claimJob, setClaimJob] = useState<string | null>(null);
  /** The berth last pressed, lit while the join is under way. */
  const [pressed, setPressed] = useState<string | null>(null);
  const lastWheel = useRef(0);
  useBack(onClose);

  const pingWait = useCountdown(c.ping_wait || 0);
  const rejoinWait = useCountdown(c.rejoin_wait || 0);
  const codeWait = useCountdown(c.code_wait || 0);

  // PageUp and PageDown step to the previous and next ship.
  usePager((step) => {
    const to = index + step;
    if (to >= 1 && to <= total) {
      onStep(to);
    }
  });

  const name = safe(c.name).toUpperCase();
  const playing = data.phase === 'playing';
  const joining = !!data.joining;
  const locked = isLocked(c);
  const applied = locked && !!c.applied;

  // The code was accepted: the berth rows light top to bottom.
  const [lights, setLights] = useState(0);
  useChangedNow(locked, (was, now) => {
    if (was && !now && !!c.cleared) {
      setLights((n) => n + 1);
      sfx('ok', { own: true });
    }
  });
  useEffect(() => {
    if (!lights) {
      return;
    }
    const id = setTimeout(() => setLights(0), 1500);
    return () => clearTimeout(id);
  }, [lights]);
  // An application or a ping went through: its row flashes once.
  useChanged(applied, (_, now) => {
    if (now) {
      sfx('ok', { own: true });
    }
  });
  const pinged = (c.ping_wait || 0) > 0;
  useChanged(pinged, (_, now) => {
    if (now) {
      sfx('ok', { own: true });
    }
  });
  const jobs = c.jobs || [];
  const full = !jobs.length;
  const end = BODY_Y + bodyRows(rows);
  const out: ReactNode[] = [];

  // Tab row, right zone: [ BACK ], three spaces, the stepper; right-aligned to column 62.
  const stepText =
    total > 1 ? `< ${Math.min(99, index)}/${Math.min(99, total)} >` : '';
  const backEnd = 63 - (stepText ? stepText.length + 3 : 0);
  let firstFocus: 'sign' | 'code' | 'ping' | 'back' = 'back';

  // Line 1: class and aboard, YOUR CREW, DOORS CREW ONLY. Half a row under the caption, as
  // in the stills; flush under it the line crowds the ship's name.
  let y = BODY_Y + 0.5;
  const tag = c.mine ? YOUR_CREW.length + 2 : 0;
  const line1 = cut(classLine(c, name), LINE1_W - tag);
  out.push(
    <Put key="l1" x={1} y={y} cls="dim">
      {line1}
    </Put>,
  );
  if (c.mine) {
    out.push(
      <Put key="mine" x={1 + line1.length + 2} y={y} cls="inv">
        {YOUR_CREW}
      </Put>,
    );
  }
  if (c.doors) {
    out.push(
      <RPut key="doors" x={62} y={y} cls="amb">
        {DOORS}
      </RPut>,
    );
  }
  y += 1.5;

  // The memo, in quotes.
  const memo = safe(c.memo).replace(/\s+/g, ' ').trim();
  if (memo) {
    const lines = wrapMax(`"${memo}"`, MEMO_W, bodyRows(rows) >= 20 ? 4 : 2);
    lines.forEach((text, i) => {
      out.push(
        <Put key={`m${i}`} x={1} y={y + i}>
          {text}
        </Put>,
      );
    });
    y += lines.length + 0.5;
  }

  // Divider, heads, and the rule between the columns.
  const ruleY = y + 0.25;
  out.push(
    <HRule key="div" x={1} y={ruleY} w={61} />,
    <VRule key="vr" x={43} y={ruleY} h={rows - 1 - ruleY} />,
  );
  y += 0.75;
  out.push(
    <Put key="hb" x={1} y={y} cls="dim">
      BERTHS
    </Put>,
    <Put key="ha" x={ABOARD_X} y={y} cls="dim">
      ABOARD
    </Put>,
  );
  y += 1.25;
  const colTop = y;

  // ABOARD: names only, captains first and marked.
  const roster = data.roster && data.roster.ref === c.ref ? data.roster : null;
  if (roster) {
    const names = roster.names || [];
    const room = Math.max(1, Math.floor(end - colTop));
    const known = names.length + Math.max(0, roster.more || 0);
    const crewN = Math.max(known, c.crew || 0);
    const shown =
      crewN > names.length || names.length > room
        ? Math.min(names.length, room - 1)
        : names.length;
    names.slice(0, shown).forEach(([who, capt], i) => {
      const text = safe(who).toUpperCase();
      out.push(
        <Put key={`a${i}`} x={ABOARD_X} y={colTop + i}>
          {cut(text, capt ? CAPT_NAME_W : NAME_W)}
        </Put>,
      );
      if (capt) {
        out.push(
          <RPut key={`c${i}`} x={62} y={colTop + i} cls="acc">
            CAPT
          </RPut>,
        );
      }
    });
    if (crewN > shown) {
      out.push(
        <Put key="amore" x={ABOARD_X} y={colTop + shown} cls="dim">
          {`+${Math.min(999, crewN - shown)} MORE`}
        </Put>,
      );
    }
  }

  // BERTHS.
  let by = colTop;
  if (rejoinWait > 0 && !locked && !full) {
    out.push(
      <Put key="rejoin" x={1} y={by} cls="amb">
        {`BACK ABOARD IN ${clock(rejoinWait)}`}
      </Put>,
    );
    by += 1.25;
  }
  const tail = !locked ? 0 : applied ? 3 : 3.5;
  let t0 = by;

  if (full) {
    out.push(
      <Slab key="nob" x={1} y={by} w={41} h={BERTH_H} variant="row" dead />,
      <Put key="nobt" x={3} y={by + 0.25} cls="dim">
        NO BERTHS OPEN
      </Put>,
    );
    const pingLive = pingWait <= 0;
    out.push(
      <Key
        key="ping"
        x={1}
        y={by + 2}
        w={13}
        kind="box"
        label="PING CREW"
        state={pingLive ? 'idle' : 'dead'}
        auto={pingLive && !locked ? 2 : undefined}
        onClick={() => act('crew_ping', { ship: c.ref })}
      />,
    );
    if (!pingLive) {
      out.push(
        <Put key="pingw" x={16} y={by + 2.25} cls="amb">
          {clock(pingWait)}
        </Put>,
      );
    } else if (!locked) {
      firstFocus = 'ping';
    }
    out.push(<FlashAt key="pingf" x={1} y={by + 2} w={41} h={1.5} k={pinged} />);
    t0 = by + 3.5;
  } else {
    const A = end - by - tail;
    const fit = Math.max(1, Math.floor((A + 0.25) / BERTH_PITCH));
    const paged = jobs.length > fit;
    const per = paged
      ? Math.max(1, Math.floor((A - 1) / BERTH_PITCH))
      : jobs.length;
    // When every berth fits on one page, the rows share the column: a pitch up to
    // BERTH_PITCH_MAX in quarter rows, with the CREWS list's row rule (a half-row gap once the
    // pitch reaches 3).
    const pitch = paged
      ? BERTH_PITCH
      : Math.max(
          BERTH_PITCH,
          Math.min(
            BERTH_PITCH_MAX,
            Math.floor(((A + 0.25) / Math.max(1, jobs.length)) * 4) / 4,
          ),
        );
    const gap = pitch >= 3 ? 0.5 : 0.25;
    const rowH = pitch - gap;
    const tall = rowH >= BERTH_TALL;
    const pages = Math.max(1, Math.ceil(jobs.length / per));
    const pg = Math.min(pages, Math.max(1, berthPage));
    const first = (pg - 1) * per;
    const shown = jobs.slice(first, first + per);
    const turn = (to: number, last = false) => {
      if (to < 1 || to > pages || to === pg) {
        return false;
      }
      const at = (to - 1) * per;
      const target = last
        ? jobs[Math.min(jobs.length - 1, at + per - 1)]
        : jobs[at];
      setClaimJob(target ? target.ref : null);
      setBerthPage(to);
      return true;
    };
    const canSign = (job: CrewJob) =>
      playing && !locked && !!job.ok && rejoinWait <= 0 && !joining;
    const firstLive = shown.find(canSign);
    if (firstLive) {
      firstFocus = 'sign';
    }
    // The berth rows go in their own layer so the mouse wheel over them turns their page.
    const rowsOut: ReactNode[] = [];
    shown.forEach((job, i) => {
      const yy = by + i * pitch;
      const live = canSign(job);
      const lit = joining && pressed === job.ref;
      const titleCls = locked ? 'faint' : job.ok ? '' : 'dim';
      const claim = claimJob ? claimJob === job.ref : job === firstLive;
      // The title stops two cells short of the open count as the count is drawn. On a tall row
      // the two go 1.25x together when the whole title fits that large; a title that does not
      // keeps both at normal size, so a long title never runs up to a big count.
      const openN = String(Math.min(99, Math.max(0, job.open || 0)));
      const fullTitle = safe(job.title).toUpperCase();
      const big =
        tall &&
        fullTitle.length * 1.25 <= Math.floor(28 - openN.length * 1.25 - 4.75);
      const titleW = Math.min(
        TITLE_W,
        Math.floor(28 - openN.length * (big ? 1.25 : 1) - 4.75),
      );
      const title = cut(fullTitle, titleW);
      // The key fills the row, however far the rows stretch.
      const keyH = rowH;
      rowsOut.push(
        <Slab
          key={`r${job.ref}`}
          x={1}
          y={yy}
          w={41}
          h={rowH}
          variant="row"
          dead={locked}
        />,
        big ? (
          <NameLine
            key={`t${job.ref}`}
            x={3}
            y={yy + (rowH - 1.25) / 2}
            w={titleW}
            text={title}
            cls={titleCls}
          />
        ) : (
          <Put
            key={`t${job.ref}`}
            x={3}
            y={yy + (rowH - 1) / 2}
            cls={titleCls}
          >
            {title}
          </Put>
        ),
        // The open count stays in accent on every row, a locked crew's too. Beside a 1.25x title
        // it is 1.25x too, still ending at column 28.
        big ? (
          <Big
            key={`n${job.ref}`}
            x={25}
            y={yy + (rowH - 1.25) / 2}
            w={3}
            align="right"
            scale={1.25}
            cls="acc"
            pulse={job.open}
          >
            {String(Math.min(99, Math.max(0, job.open || 0)))}
          </Big>
        ) : (
          <RPut
            key={`n${job.ref}`}
            x={28}
            y={yy + (rowH - 1) / 2}
            cls="acc"
            pulse={job.open}
          >
            {String(Math.min(99, Math.max(0, job.open || 0)))}
          </RPut>
        ),
        <Key
          // Remount when the key comes alive, so a code accepted moves the focus onto it.
          key={`k${job.ref}-${live ? 1 : 0}`}
          x={KEY_X}
          y={yy + (rowH - keyH) / 2}
          w={KEY_W}
          h={keyH}
          kind="cap"
          label="[ SIGN ON ]"
          state={lit ? 'lit' : live ? 'idle' : 'dead'}
          // On its way: the label blinks at the STAND BY cadence until the answer comes.
          busy={lit}
          auto={live && claim ? 2 : undefined}
          edge={{
            down:
              i === shown.length - 1 && paged ? () => turn(pg + 1) : undefined,
            up: i === 0 && paged ? () => turn(pg - 1, true) : undefined,
          }}
          onClick={() => {
            setPressed(job.ref);
            act('crew_sign_on', { ship: c.ref, job: job.ref });
          }}
        />,
      );
      if (lights > 0) {
        rowsOut.push(
          <Light
            key={`lit${lights}-${job.ref}`}
            y={yy}
            h={rowH}
            delay={i * LIGHT_GAP}
          />,
        );
      }
    });
    out.push(
      <div
        key="brows"
        className="lt-wheel"
        onWheel={(e) => {
          if (!paged || !e.deltaY) {
            return;
          }
          const now = Date.now();
          if (now - lastWheel.current < 150) {
            return;
          }
          lastWheel.current = now;
          turn(pg + (e.deltaY > 0 ? 1 : -1));
        }}
      >
        {rowsOut}
      </div>,
    );
    // A page of berths turning wipes the rows only.
    out.push(
      <WipeAt
        key="bturn"
        x={1}
        y={by}
        w={41}
        h={shown.length * pitch - gap}
        k={pg}
      />,
    );
    if (paged) {
      out.push(
        <Pager
          key="bpg"
          x={42}
          y={by + per * BERTH_PITCH}
          page={pg}
          pages={pages}
          right
          onPage={(to) => turn(to)}
        />,
      );
      t0 = by + per * BERTH_PITCH + 1;
    } else {
      t0 = by + shown.length * pitch - gap;
    }
  }

  // Locked: CODE (and NOTE, or APPLICATION SENT).
  if (locked) {
    const cy = t0 + 0.25;
    const waiting = codeWait > 0;
    const sendCode = () => {
      if (!code.trim() || waiting) {
        return;
      }
      act('crew_code', { ship: c.ref, code });
      setCode('');
    };
    out.push(
      <Put key="codel" x={1} y={cy + 0.25}>
        CODE
      </Put>,
    );
    if (waiting) {
      out.push(
        <Band key="codeb" x={6} y={cy} w={FIELD_W} h={1.5} tone="field" />,
        <Put key="codew" x={7} y={cy + 0.25} cls="amb">
          {`WAIT ${clock(codeWait)}`}
        </Put>,
      );
    } else {
      out.push(
        <Field
          key="codef"
          x={6}
          y={cy}
          w={FIELD_W}
          value={code}
          max={CODE_MAX}
          secret
          auto={firstFocus === 'back' ? 2 : undefined}
          onChange={setCode}
          onEnter={sendCode}
        />,
      );
      if (firstFocus === 'back') {
        firstFocus = 'code';
      }
    }
    out.push(
      <Key
        key="codek"
        x={KEY_X}
        y={cy}
        w={KEY_W}
        kind="cap"
        label="[ ENTER ]"
        state={waiting ? 'dead' : 'idle'}
        onClick={sendCode}
      />,
    );
    const ny = cy + 1.75;
    out.push(<FlashAt key="appf" x={1} y={ny} w={41} h={1.5} k={applied} />);
    if (applied) {
      out.push(
        <Put key="sent" x={1} y={ny} cls="amb">
          APPLICATION SENT
        </Put>,
      );
    } else {
      const sendNote = () => act('crew_apply', { ship: c.ref, note });
      out.push(
        <Put key="notel" x={1} y={ny + 0.25}>
          NOTE
        </Put>,
        <Field
          key="notef"
          x={6}
          y={ny}
          w={FIELD_W}
          value={note}
          max={NOTE_MAX}
          onChange={setNote}
          onEnter={sendNote}
        />,
        <Key
          key="notek"
          x={KEY_X}
          y={ny}
          w={KEY_W}
          kind="cap"
          label="[ APPLY ]"
          onClick={sendNote}
        />,
      );
    }
  }

  return (
    <>
      <Btn
        x={backEnd}
        y={0.25}
        right
        label="BACK"
        auto={firstFocus === 'back' ? 1 : undefined}
        onClick={onClose}
      />
      {!!stepText && (
        <Pager
          x={63}
          y={0.25}
          page={index}
          pages={total}
          right
          onPage={onStep}
        />
      )}
      <Box x={0} y={BOX_Y} w={63} h={rows - 3.5} caption={cut(name, 57)} />
      {out}
    </>
  );
}
