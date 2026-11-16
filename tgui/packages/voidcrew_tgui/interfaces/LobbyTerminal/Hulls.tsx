/**
 * HULLS (spec 02, 3.3): the shelf as blocks in the CREWS language (design 01, 6.3), paged,
 * with compact rows only when fewer than three blocks fit. A block opens the hull's record,
 * which is drawn in place of the list (HullRecord.tsx).
 */
import { type ReactNode, useEffect, useMemo, useRef, useState } from 'react';

import { HullRecord } from './HullRecord';
import {
  BODY_Y,
  BOX_Y,
  Big,
  Box,
  bodyRows,
  cut,
  NameLine,
  Pager,
  Put,
  RPut,
  SEP,
  Slab,
  safe,
  useGrid,
  wrapMax,
} from './term';
import type { Hull } from './types';
import {
  crewCount,
  hullOwned,
  type Ownership,
  partsOf,
  stockFit,
  type YardCtx,
} from './YardTab';

/** Rounded down to a quarter row. */
const f4 = (v: number) => Math.floor(v * 4) / 4;

/** Block text: columns 3 to 49. Compact line 2: columns 3 to 60. */
const BLOCK_W = 47;
const ROW_W = 58;

type Shown = {
  hull: Hull;
  name: string;
  /** The full name without the short name, or ''. */
  type: string;
  price: string;
  /** Amber when it costs parts. */
  due: boolean;
  berths: number;
};

function priceOf(own: Ownership, hl: Hull): [string, boolean] {
  if (own.free || !!hl.free || !partsOf(hl.cost)) {
    return ['FREE', false];
  }
  if (hullOwned(own, hl)) {
    return ['OWNED', false];
  }
  return [`${partsOf(hl.cost)} PARTS`, true];
}

function typeOf(hl: Hull): string {
  const name = safe(hl.name).trim();
  const short = safe(hl.short).trim();
  if (short && name.toUpperCase().startsWith(short.toUpperCase())) {
    return name.slice(short.length).trim();
  }
  return short && name.toUpperCase() === short.toUpperCase() ? '' : name;
}

/** The type line's parts in `w` cells: the price is kept, the type is cut. */
function TypeLine(props: { x: number; y: number; s: Shown; w: number }) {
  const { x, y, s, w } = props;
  const tail = s.type ? ` ${SEP} ` : '';
  const type = s.type ? cut(s.type, w - s.price.length - tail.length) : '';
  return (
    <>
      {!!type && (
        <Put x={x} y={y} cls="dim">
          {type + tail}
        </Put>
      )}
      <Put
        x={x + (type ? type.length + tail.length : 0)}
        y={y}
        cls={s.due ? 'amb' : 'dim'}
      >
        {s.price}
      </Put>
    </>
  );
}

export function Hulls(props: { ctx: YardCtx }) {
  const { ctx } = props;
  const { catalog, hull, own, view } = ctx;
  const { rows } = useGrid();
  const lastWheel = useRef(0);

  const list: Shown[] = useMemo(
    () =>
      catalog.map((hl) => {
        const [price, due] = priceOf(own, hl);
        return {
          hull: hl,
          name: safe(hl.short).toUpperCase(),
          type: typeOf(hl),
          price,
          due,
          berths: Math.max(0, Math.min(999, crewCount(stockFit(hl)))),
        };
      }),
    [catalog, own.owned, own.free],
  );

  const N = list.length;
  const B = bodyRows(rows);
  let form: 'block' | 'row';
  let per: number;
  let h: number;
  if (N <= Math.floor((B + 0.25) / 5)) {
    form = 'block';
    per = Math.max(1, N);
    h = Math.min(7, f4((B - 0.25 * (N - 1)) / Math.max(1, N)));
  } else if (Math.floor((B - 1) / 5) >= 3) {
    form = 'block';
    per = Math.floor((B - 1) / 5);
    h = Math.min(7, f4((B - 1.25 - 0.25 * (per - 1)) / per));
  } else {
    form = 'row';
    per = Math.max(1, Math.floor((B - 1) / 2.5));
    h = 2.25;
  }
  const pitch = form === 'block' ? h + 0.25 : 2.5;
  const pages = Math.max(1, Math.ceil(N / per));

  // Opens on the page of the hull last opened, with that hull focused.
  const lastAt = list.findIndex((s) => s.hull.id === view.lastHull);
  const [page, setPage] = useState(() =>
    lastAt >= 0 ? Math.floor(lastAt / per) + 1 : 1,
  );
  const [claimId, setClaimId] = useState<string | null>(
    lastAt >= 0 ? view.lastHull : null,
  );
  const pg = Math.min(pages, Math.max(1, page));
  const first = (pg - 1) * per;
  const shown = list.slice(first, first + per);

  // A pane resize changes `per`: keep the focused hull's page.
  const focId = useRef<string | null>(claimId);
  const lastPer = useRef(per);
  useEffect(() => {
    if (lastPer.current === per) {
      return;
    }
    lastPer.current = per;
    const at = list.findIndex((s) => s.hull.id === focId.current);
    if (at >= 0) {
      setClaimId(focId.current);
      setPage(Math.floor(at / per) + 1);
    }
  }, [per]);

  const turn = (to: number, last = false) => {
    if (to < 1 || to > pages || to === pg) {
      return false;
    }
    const at = (to - 1) * per;
    const target = last ? list[Math.min(N - 1, at + per - 1)] : list[at];
    setClaimId(target ? target.hull.id : null);
    setPage(to);
    return true;
  };

  // PageDown and PageUp turn the page from anywhere in the list.
  const turnRef = useRef(turn);
  turnRef.current = turn;
  const pgRef = useRef(pg);
  pgRef.current = pg;
  const listOpen = !hull && pages > 1;
  useEffect(() => {
    if (!listOpen) {
      return;
    }
    const onKey = (e: KeyboardEvent) => {
      const t = e.target as HTMLElement | null;
      if (t && (t.tagName === 'INPUT' || t.tagName === 'TEXTAREA')) {
        return;
      }
      if (e.key === 'PageDown' || e.key === 'PageUp') {
        e.preventDefault();
        turnRef.current(pgRef.current + (e.key === 'PageDown' ? 1 : -1));
      }
    };
    window.addEventListener('keydown', onKey, true);
    return () => window.removeEventListener('keydown', onKey, true);
  }, [listOpen]);

  if (hull) {
    return <HullRecord ctx={ctx} hull={hull} x={0} w={63} />;
  }

  const claim = claimId ?? (shown[0] ? shown[0].hull.id : null);
  const out: ReactNode[] = [];
  shown.forEach((s, i) => {
    const y0 = BODY_Y + i * pitch;
    const edge = {
      down: i === shown.length - 1 ? () => turn(pg + 1) : undefined,
      up: i === 0 ? () => turn(pg - 1, true) : undefined,
    };
    const common = {
      s,
      y0,
      auto: s.hull.id === claim ? 1 : undefined,
      edge,
      onOpen: () => ctx.go.record(s.hull.id),
      onFocus: () => {
        focId.current = s.hull.id;
      },
    };
    out.push(
      form === 'block' ? (
        <HullBlock key={s.hull.id} {...common} h={h} />
      ) : (
        <HullRow key={s.hull.id} {...common} alt={(first + i) % 2 === 1} />
      ),
    );
  });

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
      <Box x={0} y={BOX_Y} w={63} h={rows - 3.5} caption={`HULLS  ${N}`} />
      {out}
      <Pager
        x={61}
        y={rows - 2.25}
        page={pg}
        pages={pages}
        right
        onPage={(to) => turn(to)}
      />
    </div>
  );
}

type ItemProps = {
  s: Shown;
  y0: number;
  auto?: number;
  edge: { down?: () => boolean; up?: () => boolean };
  onOpen: () => void;
  onFocus: () => void;
};

function HullBlock(props: ItemProps & { h: number }) {
  const { s, y0, h, auto, edge, onOpen, onFocus } = props;
  const p = h >= 4.75 ? 0.25 : 0.125;
  const lines = Math.max(2, Math.min(4, Math.floor(h - 2.25 - 2 * p)));
  const desc = wrapMax(
    safe(s.hull.desc).replace(/\s+/g, ' ').trim(),
    BLOCK_W,
    lines,
  );
  return (
    <Slab
      x={1}
      y={y0}
      w={61}
      h={h}
      variant="block"
      auto={auto}
      edge={edge}
      onClick={onOpen}
      onFocus={(on) => on && onFocus()}
    >
      <NameLine x={3} y={y0 + p} w={BLOCK_W} text={s.name} />
      <TypeLine x={3} y={y0 + p + 1.25} s={s} w={BLOCK_W} />
      {desc.map((t, i) => (
        <Put key={i} x={3} y={y0 + p + 2.25 + i}>
          {t}
        </Put>
      ))}
      <Big x={52} w={9} align="center" y={y0 + p} scale={2.25} cls="acc">
        {String(s.berths)}
      </Big>
      <Put x={53} y={y0 + p + 2.25}>
        BERTHS
      </Put>
    </Slab>
  );
}

function HullRow(props: ItemProps & { alt: boolean }) {
  const { s, y0, alt, auto, edge, onOpen, onFocus } = props;
  return (
    <Slab
      x={1}
      y={y0}
      w={61}
      h={2.25}
      variant="row"
      alt={alt}
      auto={auto}
      edge={edge}
      onClick={onOpen}
      onFocus={(on) => on && onFocus()}
    >
      <Put x={3} y={y0 + 0.125} cls="wht">
        {cut(s.name, 46)}
      </Put>
      <RPut x={61} y={y0 + 0.125} cls="acc">
        {`${s.berths} BERTHS`}
      </RPut>
      <TypeLine x={3} y={y0 + 1.125} s={s} w={ROW_W} />
    </Slab>
  );
}
