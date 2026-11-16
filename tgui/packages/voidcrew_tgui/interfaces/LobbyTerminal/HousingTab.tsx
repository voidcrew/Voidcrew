/**
 * HOUSING: player outposts taking residents (DM: lobby_housing.dm), as blocks like the CREWS
 * list. Everything a player can do is on the outpost's block: the word says how it admits, the
 * key moves in or asks, a code outpost has its field beside the key. Paged when the blocks
 * would get shorter than 3.75 rows.
 *
 * Main-region rows: box from BOX_Y, body from BODY_Y (columns 1 to 61, bodyRows(M) rows), the
 * shell's notice row at M - 1.
 */
import { type ReactNode, useEffect, useRef, useState } from 'react';
import { useBackend } from 'tgui/backend';

import { sfx, useChanged, useScreen } from './motion';
import { usePager } from './nav';
import {
  BODY_Y,
  BOX_Y,
  Band,
  Big,
  Box,
  bodyRows,
  cut,
  Field,
  FlashAt,
  Key,
  NameLine,
  Pager,
  Put,
  Slab,
  safe,
  useGrid,
  WipeAt,
  wrapMax,
} from './term';
import type { LobbyData, Outpost, OutpostMode } from './types';

/** Name: 1.25x to 36 characters, normal size to 45, two lines past that on a tall block. */
const NAME_W = 45;
/** Every key on a block: `[ MOVE IN ]` or `[ REQUEST ]`, centred in 12 columns. */
const KEY_X = 49;
const KEY_W = 12;
/** The code field, columns 24 to 46. */
const FIELD_X = 24;
const FIELD_W = 23;
const CODE_MAX = 64;
/** A sent move-in keeps the key dead this long, or until the notice changes. */
const SENT_MS = 4000;

const f4 = (v: number) => Math.floor(v * 4) / 4;

const WORD: Record<OutpostMode, [string, string]> = {
  open: ['OPEN', 'acc'],
  password: ['CODE', 'amb'],
  approved: ['INVITE', 'amb'],
  closed: ['CLOSED', 'dim'],
};

type Act = 'move' | 'code' | 'request' | 'none';

type View = {
  word: string;
  wordCls: string;
  act: Act;
  /** The reason drawn on the block, amber. */
  why: string;
};

/** The block's word, its key and its reason (design 02, 4.3). */
function viewOf(o: Outpost): View {
  const why = o.blocked ? safe(o.why).trim().toUpperCase() : '';
  if (o.mode === 'closed') {
    return { word: 'CLOSED', wordCls: 'dim', act: 'none', why: '' };
  }
  const mode: OutpostMode = o.cleared ? 'open' : o.mode;
  const [word, wordCls] = WORD[mode] || WORD.closed;
  if (why) {
    return { word, wordCls: 'dim', act: 'none', why };
  }
  if (mode === 'approved' && o.asked) {
    return { word: 'ASKED', wordCls: 'amb', act: 'none', why: '' };
  }
  const act: Act =
    mode === 'password' ? 'code' : mode === 'approved' ? 'request' : 'move';
  return { word, wordCls, act, why: '' };
}

const wait = (s: number) =>
  `WAIT ${Math.floor(s / 60)}:${String(s % 60).padStart(2, '0')}`;

const residents = (n: number) => {
  const v = Math.min(999, Math.max(0, Math.floor(n || 0)));
  return v === 1 ? '1 resident' : `${v} residents`;
};

const EMPTY_LINE: Record<string, string> = {
  playing: 'NO ROOMS TO LET.',
  ended: 'PORT CLOSED.',
};
const PREGAME_LINE = 'ROOMS LET ONCE THE PORT OPENS.';

/**
 * Keypad lockouts count down in the page from the last value the server sent, as CREWS does
 * for cryo. Returns the seconds left for an outpost.
 */
function useCountdown(outposts: Outpost[]) {
  const seen = useRef<Record<string, { v: number; t: number }>>({});
  const [now, setNow] = useState(Date.now());
  const any = outposts.some((o) => (o.code_wait || 0) > 0);
  for (const o of outposts) {
    const v = o.code_wait || 0;
    const was = seen.current[o.ref];
    if (!was || was.v !== v) {
      seen.current[o.ref] = { v, t: Date.now() };
    }
  }
  useEffect(() => {
    if (!any) {
      return;
    }
    const id = setInterval(() => setNow(Date.now()), 1000);
    return () => clearInterval(id);
  }, [any]);
  return (ref: string) => {
    const was = seen.current[ref];
    if (!was || was.v <= 0) {
      return 0;
    }
    return Math.max(0, was.v - Math.floor((now - was.t) / 1000));
  };
}

export function HousingTab() {
  const { act, data } = useBackend<LobbyData>();
  const { rows } = useGrid();
  const outposts = data.outposts || [];
  const phase = data.phase;
  const open = phase === 'playing';
  const noticeAt = data.notice ? data.notice.at : null;

  const [codes, setCodes] = useState<Record<string, string>>({});
  const [page, setPage] = useState(1);
  const [claimRef, setClaimRef] = useState<string | null>(null);
  const [sent, setSent] = useState<{ at: number | null } | null>(null);
  const lastWheel = useRef(0);
  const left = useCountdown(outposts);
  useScreen('housing', 0);

  // A sent move-in: every key is dead until the notice changes or 4 seconds pass.
  useEffect(() => {
    if (!sent) {
      return;
    }
    const id = setTimeout(() => setSent(null), SENT_MS);
    return () => clearTimeout(id);
  }, [sent]);
  const busy = !!sent && sent.at === noticeAt;

  const n = outposts.length;
  const M = rows;
  const B = bodyRows(M);
  const foot = !open && phase !== 'ended' && n > 0 ? 1.25 : 0;
  const R = B - foot;
  const onePage = n <= Math.floor((R + 0.25) / 3.75);
  const per = onePage
    ? Math.max(1, n)
    : Math.max(1, Math.floor((B - 1.25 + 0.25) / 3.75));
  const h = onePage
    ? Math.min(5.75, f4((R - 0.25 * (n - 1)) / Math.max(1, n)))
    : Math.min(5.75, f4((B - 1.25 - 0.25 * (per - 1)) / per));
  const pages = Math.max(1, Math.ceil(n / per));
  const pg = Math.min(pages, Math.max(1, page));
  const first = (pg - 1) * per;
  const shown = outposts.slice(first, first + per);

  const turn = (to: number, last = false) => {
    if (to < 1 || to > pages || to === pg) {
      return false;
    }
    const at = (to - 1) * per;
    const target = last ? outposts[Math.min(n - 1, at + per - 1)] : outposts[at];
    setClaimRef(target ? target.ref : null);
    setPage(to);
    return true;
  };

  // PageDown and PageUp turn the page from anywhere in the list.
  usePager(pages > 1 ? (step) => turn(pg + step) : null);

  const moveIn = (o: Outpost) => {
    act('home_move_in', { outpost: o.ref, code: codes[o.ref] || '' });
    setCodes({ ...codes, [o.ref]: '' });
    setSent({ at: noticeAt });
  };

  const live = (o: Outpost) => {
    const v = viewOf(o);
    if (!open || busy || v.act === 'none') {
      return false;
    }
    return v.act !== 'code' || left(o.ref) <= 0;
  };
  // First focus: the first live key or field from the top; a page turn claims the block it lands on.
  const claim =
    claimRef && shown.some((o) => o.ref === claimRef && live(o))
      ? claimRef
      : (shown.find(live) || { ref: null }).ref;

  const box = (
    <Box
      key="box"
      x={0}
      y={BOX_Y}
      w={63}
      h={M - 3.5}
      caption={`OUTPOSTS  ${n}`}
    />
  );

  const out: ReactNode[] = [];
  if (!n) {
    const y0 = BODY_Y;
    out.push(
      <Slab key="empty" x={1} y={y0} w={61} h={4.75} variant="block" dead>
        <NameLine
          x={3}
          y={y0 + 0.25}
          w={57}
          text={EMPTY_LINE[phase] || PREGAME_LINE}
          cls="dim"
        />
      </Slab>,
    );
  } else {
    shown.forEach((o, i) => {
      const lastRow = i === shown.length - 1;
      out.push(
        <OutpostBlock
          key={o.ref}
          o={o}
          y0={BODY_Y + i * (h + 0.25)}
          h={h}
          open={open}
          busy={busy}
          wait={left(o.ref)}
          code={codes[o.ref] || ''}
          auto={o.ref === claim ? 1 : undefined}
          edge={{
            down: lastRow ? () => turn(pg + 1) : undefined,
            up: i === 0 ? () => turn(pg - 1, true) : undefined,
          }}
          onCode={(value) => setCodes({ ...codes, [o.ref]: value })}
          onMove={() => moveIn(o)}
          onRequest={() => act('home_request', { outpost: o.ref })}
        />,
      );
    });
    if (foot) {
      out.push(
        <Put key="foot" x={3} y={M - 2.25} cls="amb">
          {PREGAME_LINE}
        </Put>,
      );
    }
    out.push(
      <Pager
        key="pager"
        x={61}
        y={M - 2.25}
        page={pg}
        pages={pages}
        right
        onPage={(to) => turn(to)}
      />,
      // A page turn wipes the blocks only.
      <WipeAt
        key="turn"
        x={1}
        y={BODY_Y}
        w={61}
        h={M - 2.5 - BODY_Y}
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

function OutpostBlock(props: {
  o: Outpost;
  y0: number;
  h: number;
  open: boolean;
  busy: boolean;
  /** Seconds left on this outpost's keypad lockout. */
  wait: number;
  code: string;
  auto?: number;
  edge: { down?: () => boolean; up?: () => boolean };
  onCode: (value: string) => void;
  onMove: () => void;
  onRequest: () => void;
}) {
  const { o, y0, h, open, busy, wait: lock, code, auto, edge } = props;
  const p = h >= 4.75 ? 0.25 : 0.125;
  const v = viewOf(o);
  const name = safe(o.name).trim().toUpperCase();
  const twoLines = name.length > NAME_W && h >= 4.75;
  const nameLines = twoLines ? wrapMax(name, NAME_W, 2) : [];
  const resY = y0 + p + (twoLines ? 2.25 : 1.25);
  const keyY = y0 + h - p - 1.5;
  const dead = !open || busy;
  const locked = v.act === 'code' && lock > 0;
  // A request went out: the block's bar flashes once.
  const asked = !!o.asked;
  useChanged(asked, (_, now) => {
    if (now) {
      sfx('ok', { own: true });
    }
  });

  let keys: ReactNode = null;
  if (v.act === 'move') {
    keys = (
      <Key
        x={KEY_X}
        y={keyY}
        w={KEY_W}
        kind="cap"
        label="[ MOVE IN ]"
        state={dead ? 'dead' : 'idle'}
        auto={auto}
        edge={edge}
        onClick={props.onMove}
      />
    );
  } else if (v.act === 'request') {
    keys = (
      <Key
        x={KEY_X}
        y={keyY}
        w={KEY_W}
        kind="cap"
        label="[ REQUEST ]"
        state={dead ? 'dead' : 'idle'}
        auto={auto}
        edge={edge}
        onClick={props.onRequest}
      />
    );
  } else if (v.act === 'code') {
    keys = (
      <>
        {locked ? (
          <>
            <Band x={FIELD_X} y={keyY} w={FIELD_W} h={1.5} tone="field" />
            <Put x={FIELD_X + 1} y={keyY + 0.25} cls="amb">
              {wait(lock)}
            </Put>
          </>
        ) : (
          <Field
            x={FIELD_X}
            y={keyY}
            w={FIELD_W}
            value={code}
            max={CODE_MAX}
            secret
            disabled={dead}
            auto={auto}
            onChange={props.onCode}
            onEnter={() => {
              if (!dead && code.length > 0) {
                props.onMove();
              }
            }}
          />
        )}
        <Key
          x={KEY_X}
          y={keyY}
          w={KEY_W}
          kind="cap"
          label="[ MOVE IN ]"
          state={dead || locked || !code.length ? 'dead' : 'idle'}
          edge={edge}
          onClick={props.onMove}
        />
      </>
    );
  }

  return (
    <Slab x={1} y={y0} w={61} h={h} variant="block">
      {twoLines ? (
        nameLines.map((line, i) => (
          <Put key={i} x={3} y={y0 + p + 0.125 + i * 1.125} cls="wht lt-name">
            {line}
          </Put>
        ))
      ) : (
        <NameLine x={3} y={y0 + p} w={NAME_W} text={name} />
      )}
      <Put x={3} y={resY} cls="dim" pulse={o.residents}>
        {residents(o.residents)}
      </Put>
      <FlashAt x={1} y={y0} w={61} h={h} k={asked} bar />
      {!!v.why && (
        <Put x={3} y={resY + 1} cls="amb">
          {cut(v.why, NAME_W)}
        </Put>
      )}
      <Big
        x={KEY_X}
        w={KEY_W}
        align="center"
        y={y0 + p}
        scale={1.25}
        cls={v.wordCls}
      >
        {v.word}
      </Big>
      {keys}
    </Slab>
  );
}
