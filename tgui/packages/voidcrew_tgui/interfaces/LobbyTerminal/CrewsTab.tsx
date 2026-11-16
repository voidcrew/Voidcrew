/**
 * CREWS: every crew signing on, as full blocks when they all fit the box and as two-line
 * compact rows otherwise (paged when they overflow). Opening a ship shows its record in place
 * of the list.
 *
 * Main-region rows: box from BOX_Y, body from BODY_Y (columns 1 to 61, bodyRows(M) rows),
 * the shell's notice row at M - 1.
 */
import { type ReactNode, useEffect, useMemo, useRef, useState } from 'react';
import { useBackend } from 'tgui/backend';

import { CrewRecord, classLine, isLocked } from './CrewRecord';
import { useScreen } from './motion';
import { usePager } from './nav';
import {
  Big,
  BODY_Y,
  BOX_Y,
  Box,
  bodyRows,
  cut,
  Key,
  NameLine,
  Pager,
  Put,
  RPut,
  SEP,
  Slab,
  safe,
  useGrid,
  WipeAt,
  wrapMax,
} from './term';
import type { Crew, LobbyData, TabId } from './types';

type Status = 'OPEN' | 'LOCKED' | 'APPLIED' | 'FULL';

const STATUS_CLS: Record<Status, string> = {
  OPEN: '',
  LOCKED: 'amb',
  APPLIED: 'amb',
  FULL: 'dim',
};

/** Order groups: own crew, then open, then locked or applied, then full. */
const STATUS_RANK: Record<Status, number> = {
  OPEN: 1,
  LOCKED: 2,
  APPLIED: 2,
  FULL: 3,
};

const YOUR_CREW = ' YOUR CREW ';
/** Block text columns 3 to 49; compact line 2 columns 3 to 60. */
const BLOCK_TEXT_W = 47;
const ROW_TEXT_W = 58;
const ROW_NAME_W = 46;

function openSlots(c: Crew): number {
  return (c.jobs || []).reduce((sum, job) => sum + (job.open || 0), 0);
}

function statusOf(c: Crew): Status {
  if (openSlots(c) <= 0) {
    return 'FULL';
  }
  if (isLocked(c)) {
    return c.applied ? 'APPLIED' : 'LOCKED';
  }
  return 'OPEN';
}

const count = (n: number) => String(Math.min(999, Math.max(0, n)));

type Shown = {
  c: Crew;
  name: string;
  status: Status;
  open: number;
  mine: boolean;
};

export function CrewsTab(props: { setTab?: (tab: TabId) => void }) {
  const { setTab } = props;
  const { data, act } = useBackend<LobbyData>();
  const { cols, rows } = useGrid();
  const crews = data.crews || [];
  const [selRef, setSelRef] = useState<string | null>(null);
  const [page, setPage] = useState(1);
  /** The ship that last held the focus; the page follows it when it changes group. */
  const [focRef, setFocRef] = useState<string | null>(null);
  /** The ship whose slab takes the focus when it mounts (paging, following). */
  const [claimRef, setClaimRef] = useState<string | null>(null);
  const lastWheel = useRef(0);

  const sorted: Shown[] = useMemo(() => {
    const list = crews.map((c, i) => {
      const status = statusOf(c);
      const mine = !!c.mine;
      return {
        c,
        i,
        name: safe(c.name).toUpperCase(),
        status,
        open: openSlots(c),
        mine,
        rank: mine ? 0 : STATUS_RANK[status],
      };
    });
    list.sort((a, b) => a.rank - b.rank || a.i - b.i);
    return list;
  }, [crews]);

  const selected = crews.find((c) => c.ref === selRef) || null;
  // The record opens with the wipe and closes with it run back; the ship stepper turns a page.
  const selAt = selected
    ? sorted.findIndex((x) => x.c.ref === selected.ref)
    : -1;
  useScreen(
    selected ? 'crews/record' : 'crews',
    selected ? 1 : 0,
    selected ? selected.ref : '',
    selAt,
  );

  // The server sends the roster only for the open record: tell it which one, and when it closes.
  const openSent = useRef<string | null>(null);
  useEffect(() => {
    if (selRef && selRef !== openSent.current) {
      act('crew_open', { ship: selRef });
      openSent.current = selRef;
    } else if (!selRef && openSent.current) {
      act('crew_close');
      openSent.current = null;
    }
  }, [selRef]);
  useEffect(
    () => () => {
      if (openSent.current) {
        act('crew_close');
      }
    },
    [],
  );
  // A ship that has left closes its record.
  useEffect(() => {
    if (selRef && !selected) {
      setSelRef(null);
    }
  }, [selRef, !!selected]);

  const n = sorted.length;
  const B = bodyRows(rows);
  const fullFit = Math.floor((B + 0.25) / 4.75);
  const rowFit = Math.floor((B + 0.25) / 2.5);
  const form: 'block' | 'row' = n <= fullFit ? 'block' : 'row';
  const per =
    form === 'block'
      ? Math.max(1, n)
      : n <= rowFit
        ? rowFit
        : Math.max(1, Math.floor((B - 1) / 2.5));
  const pages = Math.max(1, Math.ceil(n / per));
  const pg = Math.min(pages, Math.max(1, page));
  const first = (pg - 1) * per;
  const shown = sorted.slice(first, first + per);

  // The page follows the focused ship when the order moves it to another page.
  const focIdx = focRef ? sorted.findIndex((x) => x.c.ref === focRef) : -1;
  const lastIdx = useRef(focIdx);
  useEffect(() => {
    if (focIdx !== lastIdx.current) {
      lastIdx.current = focIdx;
      if (focIdx >= 0) {
        const want = Math.floor(focIdx / per) + 1;
        if (want !== pg) {
          setClaimRef(focRef);
          setPage(want);
        }
      }
    }
  }, [focIdx, per]);

  const turn = (to: number, last = false) => {
    if (to < 1 || to > pages || to === pg) {
      return false;
    }
    const at = (to - 1) * per;
    const target = last ? sorted[Math.min(n - 1, at + per - 1)] : sorted[at];
    setClaimRef(target ? target.c.ref : null);
    setPage(to);
    return true;
  };

  // PageDown and PageUp turn the page from anywhere in the list.
  const listOpen = !selected && pages > 1;
  usePager(listOpen ? (step) => turn(pg + step) : null);

  if (selected) {
    const at = sorted.findIndex((x) => x.c.ref === selected.ref);
    const close = () => {
      // Back to the list with that ship focused, on its page.
      setClaimRef(selected.ref);
      setFocRef(selected.ref);
      lastIdx.current = at;
      setPage(Math.floor(Math.max(0, at) / per) + 1);
      setSelRef(null);
    };
    return (
      <CrewRecord
        key={selected.ref}
        crew={selected}
        index={at + 1}
        total={n}
        onStep={(to) => {
          const next = sorted[to - 1];
          if (next) {
            setSelRef(next.c.ref);
          }
        }}
        onClose={close}
      />
    );
  }

  // First focus in a running round: the first open ship the player can take a berth on.
  const firstPick =
    data.phase === 'playing'
      ? sorted.find(
          (x) =>
            x.status === 'OPEN' &&
            !x.c.rejoin_wait &&
            (x.c.jobs || []).some((j) => !!j.ok),
        ) || sorted[0]
      : sorted[0];
  const claim = claimRef ?? (firstPick ? firstPick.c.ref : null);

  const out: ReactNode[] = [];
  const box = (
    <Box
      key="box"
      x={0}
      y={BOX_Y}
      w={cols}
      h={rows - 3.5}
      caption={`CREWS  ${n}`}
    />
  );

  if (!n) {
    out.push(<EmptyState key="empty" phase={data.phase} setTab={setTab} />);
  } else if (form === 'block') {
    // Blocks stretch to share the body; any rows left over go between them.
    const h = Math.max(
      4.75,
      Math.floor(Math.min(7, (B - 0.25 * (n - 1)) / n) * 4) / 4,
    );
    const gap =
      n > 1 ? Math.max(0.25, Math.min(0.5, (B - n * h) / (n - 1))) : 0;
    shown.forEach((x, i) => {
      out.push(
        <CrewBlock
          key={x.c.ref}
          x={x}
          y0={BODY_Y + i * (h + gap)}
          h={h}
          auto={x.c.ref === claim ? 1 : undefined}
          onOpen={() => setSelRef(x.c.ref)}
          onFocus={() => setFocRef(x.c.ref)}
        />,
      );
    });
  } else {
    // Spare rows go into the gaps between rows (quarter steps, 0.25 to 0.75), so the page
    // fills down to the pager, or to the body's end on a single page.
    const bottom = pages > 1 ? rows - 2.25 - 0.25 : BODY_Y + B;
    const slots = Math.max(1, per - 1);
    let gap = Math.max(
      0.25,
      Math.min(
        0.75,
        Math.floor(((bottom - BODY_Y - per * 2.25) / slots) * 4) / 4,
      ),
    );
    let rowH = 2.25;
    // Fewer ships than a page holds: the rows share the body, as the berth rows do, to a
    // pitch of 4 at most (rows 3.5 tall) so a row never looks bloated.
    if (pages === 1 && n < per) {
      const pitch = Math.max(
        2.5,
        Math.min(4, Math.floor(((B + 0.25) / n) * 4) / 4),
      );
      gap = pitch >= 3 ? 0.5 : 0.25;
      rowH = pitch - gap;
    }
    shown.forEach((x, i) => {
      const firstRow = i === 0;
      const lastRow = i === shown.length - 1;
      out.push(
        <CrewRow
          key={x.c.ref}
          x={x}
          h={rowH}
          y0={BODY_Y + i * (rowH + gap)}
          alt={(first + i) % 2 === 1}
          auto={x.c.ref === claim ? 1 : undefined}
          onOpen={() => setSelRef(x.c.ref)}
          onFocus={() => setFocRef(x.c.ref)}
          edge={{
            down: lastRow ? () => turn(pg + 1) : undefined,
            up: firstRow ? () => turn(pg - 1, true) : undefined,
          }}
        />,
      );
    });
    out.push(
      <Pager
        key="pager"
        x={61}
        y={rows - 2.25}
        page={pg}
        pages={pages}
        right
        onPage={(to) => turn(to)}
      />,
      // A page turn wipes the rows only.
      <WipeAt
        key="turn"
        x={1}
        y={BODY_Y}
        w={61}
        h={bottom - BODY_Y}
        k={pg}
      />,
    );
  }

  return (
    <div
      className="lt-wheel"
      onWheel={(e) => {
        if (pages <= 1 || !e.deltaY) {
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
      {box}
      {out}
    </div>
  );
}

function CrewBlock(props: {
  x: Shown;
  y0: number;
  h: number;
  auto?: number;
  onOpen: () => void;
  onFocus: () => void;
}) {
  const { x, y0, h, auto, onOpen, onFocus } = props;
  const { c, name, status, open, mine } = x;
  const p = h >= 4.75 ? 0.25 : 0.125;
  const line = classLine(c, name);
  const lines = Math.max(2, Math.min(4, Math.floor(h - 2.25 - 2 * p)));
  const memo = wrapMax(safe(c.memo).trim(), BLOCK_TEXT_W, lines);
  const tag = mine ? YOUR_CREW.length + 2 : 0;
  const shownLine = cut(line, BLOCK_TEXT_W - tag);
  return (
    <Slab
      x={1}
      y={y0}
      w={61}
      h={h}
      variant="block"
      auto={auto}
      onClick={onOpen}
      onFocus={(on) => on && onFocus()}
    >
      <NameLine x={3} y={y0 + p} w={BLOCK_TEXT_W} text={name} />
      <Put x={3} y={y0 + p + 1.25} cls="dim">
        {shownLine}
      </Put>
      {!!mine && (
        <Put x={3 + shownLine.length + 2} y={y0 + p + 1.25} cls="inv">
          {YOUR_CREW}
        </Put>
      )}
      {memo.map((text, i) => (
        <Put key={i} x={3} y={y0 + p + 2.25 + i}>
          {text}
        </Put>
      ))}
      {status === 'FULL' ? (
        <Big
          x={52}
          w={9}
          align="center"
          y={y0 + (h - 1.25) / 2}
          scale={1.25}
          cls="dim"
        >
          FULL
        </Big>
      ) : (
        <>
          <Big
            x={52}
            w={9}
            align="center"
            y={y0 + p}
            scale={2.25}
            cls="acc"
            pulse={open}
          >
            {count(open)}
          </Big>
          <Put
            x={52 + Math.floor((9 - status.length) / 2)}
            y={y0 + p + 2.25}
            cls={STATUS_CLS[status]}
          >
            {status}
          </Put>
        </>
      )}
    </Slab>
  );
}

function CrewRow(props: {
  x: Shown;
  y0: number;
  /** Row height, 2.25 unless the rows spread; the two lines stay centred. */
  h?: number;
  alt: boolean;
  auto?: number;
  onOpen: () => void;
  onFocus: () => void;
  edge: { down?: () => boolean; up?: () => boolean };
}) {
  const { x, y0: top, h = 2.25, alt, auto, onOpen, onFocus, edge } = props;
  const y0 = top + (h - 2.25) / 2;
  const { c, name, status, open, mine } = x;
  const right = status === 'FULL' ? 'FULL' : `${count(open)} ${status}`;
  const memo = safe(c.memo).replace(/\s+/g, ' ').trim();
  const tail = [classLine(c, name), memo].filter(Boolean).join(` ${SEP} `);
  const tag = mine ? YOUR_CREW.length + 2 : 0;
  return (
    <Slab
      x={1}
      y={top}
      w={61}
      h={h}
      variant="row"
      alt={alt}
      auto={auto}
      edge={edge}
      onClick={onOpen}
      onFocus={(on) => on && onFocus()}
    >
      <Put x={3} y={y0 + 0.125} cls="wht">
        {cut(name, ROW_NAME_W)}
      </Put>
      <RPut
        x={61}
        y={y0 + 0.125}
        cls={status === 'OPEN' ? 'acc' : STATUS_CLS[status]}
        pulse={open}
      >
        {right}
      </RPut>
      {!!mine && (
        <Put x={3} y={y0 + 1.125} cls="inv">
          {YOUR_CREW}
        </Put>
      )}
      <Put x={3 + tag} y={y0 + 1.125} cls="dim">
        {cut(tail, ROW_TEXT_W - tag)}
      </Put>
    </Slab>
  );
}

const EMPTY_LINE: Record<string, string> = {
  playing: 'NO CREWS ARE SIGNING ON.',
  ended: 'PORT CLOSED.',
};

function EmptyState(props: { phase: string; setTab?: (tab: TabId) => void }) {
  const { phase, setTab } = props;
  const y0 = BODY_Y;
  const line = EMPTY_LINE[phase] || 'CREWS SIGN ON ONCE THE PORT OPENS.';
  return (
    <Slab x={1} y={y0} w={61} h={4.75} variant="block" dead>
      <NameLine x={3} y={y0 + 0.25} w={57} text={line} cls="dim" />
      {phase === 'playing' && !!setTab && (
        <Key
          x={3}
          y={y0 + 2.5}
          w={12}
          kind="box"
          label="SHIPYARD"
          auto={1}
          onClick={() => setTab('shipyard')}
        />
      )}
    </Slab>
  );
}
