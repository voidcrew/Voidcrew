/**
 * BILL (spec 02, 3.6): a ledger. The crew, then one slab row an item (the hull, the finish,
 * each room's option) with a fixed column for each part class, then TOTAL, ON ACCOUNT and
 * SHORT under the same columns, then CHANGE FIT and COMMISSION. No free-form price text, so
 * nothing can run into a neighbour. A tall pane puts the fitted ship on top.
 *
 * The page sends the configuration and the total it showed; the server works the bill out
 * again, charges only its own figure and refuses one higher than the page showed.
 */
import { type ReactNode, useState } from 'react';
import { useBackend } from 'tgui/backend';

import { ShipPic } from './ShipPic';
import {
  Band,
  BODY_Y,
  Box,
  BOX_Y,
  bodyRows,
  ClassFigures,
  ClassHeads,
  cut,
  HRule,
  Key,
  Pager,
  Put,
  RPut,
  Slab,
  safe,
  useGrid,
  wrap,
  wrapMax,
} from './term';
import type { LobbyData } from './types';
import {
  crewCount,
  crewText,
  fittable,
  partsOf,
  stepsOf,
  usePreview,
  YARD_OPENS,
  type YardCtx,
} from './YardTab';

/** Rounds down to a quarter row. */
const f4 = (v: number) => Math.floor(v * 4) / 4;
const clamp = (v: number, lo: number, hi: number) =>
  Math.max(lo, Math.min(hi, v));

/** Body columns 1 to 61. */
const W = 61;
/** A line's name: columns 3 to 28. */
const NAME_W = 26;
/** The right end of words in a slab (`STOCK`, `NOTHING DUE`): column 60. */
const WORD_END = 61;

/** `<n> BERTHS` in white, two spaces, the jobs dim, wrapped to at most `max` lines of 61. */
function crewLines(count: number, jobs: string, max: number) {
  const head = `${count} BERTHS`;
  // A stand-in word as wide as the head plus one, so the first line keeps two spaces after it.
  const lead = 'x'.repeat(head.length + 1);
  const all = wrap(jobs ? `${lead} ${jobs}` : lead, W);
  const lines = wrapMax(jobs ? `${lead} ${jobs}` : lead, W, max);
  return { head, need: all.length, lines };
}

export function Bill(props: { ctx: YardCtx }) {
  const { ctx } = props;
  const { data } = useBackend<LobbyData>();
  const { rows } = useGrid();
  const [page, setPage] = useState(1);
  const hull = ctx.hull;
  usePreview(hull?.id || null);
  const fit = ctx.fit;
  const bill = ctx.bill;
  if (!hull || !fit || !bill) {
    return null;
  }

  const M = rows;
  const B = bodyRows(M);
  const tight = B < 18;
  const n = bill.lines.length;
  const due = partsOf(bill.total) > 0;
  const ledgerOk = ctx.ledger === 'ok';
  const short = ledgerOk && Object.keys(bill.short).length > 0;
  const beforeRound =
    data.phase === 'loading' ||
    data.phase === 'pregame' ||
    data.phase === 'setup';
  const canChange = fittable(hull);
  const live = ctx.open && !ctx.sent && !short && (!due || ledgerOk);

  const crew = crewLines(crewCount(fit), safe(crewText(fit)), 2);
  const crewL = tight ? 0 : Math.min(2, crew.need);
  const tableRows = tight
    ? 1 + (due ? 1 : 0) + (short ? 1 : 0)
    : 1.5 + (due ? 1 : 0) + (short ? 1.5 : 0);
  const fixed = tight
    ? 1 + 0.5 + tableRows + 0.25 + 1.5
    : crewL + 0.25 + 1 + 0.25 + 0.75 + tableRows + 0.5 + 2;
  const avail = B - fixed;
  // Lines that don't fit page; nothing is ever hidden behind "+N MORE".
  const per = Math.max(1, Math.min(n, Math.floor(avail)));
  const pages = Math.max(1, Math.ceil(n / per));
  const pg = clamp(page, 1, pages);
  const shown = bill.lines.slice((pg - 1) * per, pg * per);
  // Tight form: pitch 1, stretched to 1.5 when rows are spare so none sit empty.
  const pitch =
    pages > 1 ? 1 : clamp(f4(avail / n), 1, tight ? 1.5 : 2.25);
  const spare = avail - per * pitch;
  const pic = !tight && spare >= 6 ? f4(spare - 0.5) : 0;

  const out: ReactNode[] = [];
  out.push(
    <Box
      key="box"
      x={0}
      y={BOX_Y}
      w={63}
      h={M - 3.5}
      caption={safe(hull.name).toUpperCase()}
    />,
  );
  let y = BODY_Y;

  if (pic > 0) {
    out.push(<ShipPic key="pic" x={1} y={y} w={W} h={pic} fit={fit} />);
    y += pic + 0.5;
  }

  if (crewL > 0) {
    crew.lines.forEach((line, i) => {
      if (i === 0) {
        out.push(
          <Put key="ch" x={1} y={y} cls="wht">
            {crew.head}
          </Put>,
          <Put key="c0" x={1 + crew.head.length + 2} y={y} cls="dim">
            {line.slice(crew.head.length + 2)}
          </Put>,
        );
      } else {
        out.push(
          <Put key={`c${i}`} x={1} y={y + i} cls="dim">
            {line}
          </Put>,
        );
      }
    });
    y += crewL + 0.25;
  }

  // Heads, and the pager when the lines page.
  if (due) {
    out.push(<ClassHeads key="heads" y={y} set="R" />);
  }
  out.push(
    <Pager
      key="pager"
      x={3}
      y={y}
      page={pg}
      pages={pages}
      onPage={setPage}
    />,
  );
  y += tight ? 1 : 1.25;

  // One slab row a line.
  shown.forEach((line, j) => {
    const ly = y + j * pitch;
    const h = pitch >= 1.25 ? pitch - 0.25 : 1;
    const ty = ly + (h - 1) / 2;
    const odd = ((pg - 1) * per + j) % 2 === 1;
    out.push(
      <Slab
        key={`l${j}${line.kind}${line.id}`}
        x={1}
        y={ly}
        w={W}
        h={h}
        variant="row"
        alt={h < 1.25 && odd}
      >
        <Put x={3} y={ty}>
          {cut(safe(line.name).toUpperCase(), NAME_W)}
        </Put>
        {line.cost ? (
          <ClassFigures y={ty} set="R" values={line.cost} cls="amb" />
        ) : (
          <RPut x={WORD_END} y={ty} cls="dim">
            {line.word || ''}
          </RPut>
        )}
      </Slab>,
    );
  });
  y += per * pitch;

  // The rule, then TOTAL, ON ACCOUNT and SHORT under the same columns.
  const ruleH = tight ? 0.5 : 0.75;
  out.push(<HRule key="rule" x={1} y={y + ruleH / 2} w={W} />);
  y += ruleH;

  const rowH = tight ? 1 : 1.5;
  const labelY = tight ? y : y + 0.25;
  const figY = tight ? y : y + 0.125;
  if (due) {
    out.push(
      <Put key="tl" x={3} y={labelY} cls="wht">
        TOTAL
      </Put>,
      <ClassFigures
        key="tf"
        y={figY}
        set="R"
        values={bill.total}
        cls="amb"
        big={!tight}
      />,
    );
  } else {
    out.push(
      <Put key="tl" x={3} y={labelY} cls="dim">
        TOTAL
      </Put>,
      <RPut key="nd" x={WORD_END} y={labelY} cls="dim">
        NOTHING DUE
      </RPut>,
    );
  }
  y += rowH;

  if (due) {
    out.push(
      <Put key="al" x={3} y={y} cls="dim">
        ON ACCOUNT
      </Put>,
    );
    if (ctx.ledger === 'off') {
      out.push(
        <RPut key="ao" x={WORD_END} y={y} cls="dim">
          LEDGER OFFLINE
        </RPut>,
      );
    } else if (ledgerOk) {
      out.push(<ClassFigures key="af" y={y} set="R" values={ctx.account} />);
    }
    y += 1;
  }

  if (short) {
    const sh = tight ? 1 : 1.5;
    out.push(
      <Band key="sb" x={1} y={y} w={W} h={sh} tone="warn" />,
      <Put key="sl" x={3} y={tight ? y : y + 0.25} cls="amb">
        SHORT
      </Put>,
      <ClassFigures
        key="sf"
        y={tight ? y : y + 0.125}
        set="R"
        values={bill.short}
        cls="inva"
        big={!tight}
      />,
    );
    y += sh;
  }

  // The keys, and the one line that says why before the round.
  const yK = tight ? M - 2.75 : M - 3.25;
  const sideY = tight ? yK : yK + 0.5;
  if (beforeRound) {
    out.push(
      <Put key="opens" x={1} y={sideY + 0.25} cls="amb">
        {YARD_OPENS}
      </Put>,
    );
  }
  if (canChange) {
    out.push(
      <Key
        key="chg"
        x={34}
        y={sideY}
        w={12}
        h={1.5}
        kind="box"
        label="CHANGE FIT"
        auto={2}
        onClick={() => ctx.go.fit(Math.max(0, stepsOf(fit) - 1))}
      />,
    );
  }
  out.push(
    <Key
      key="com"
      x={47}
      y={yK}
      w={15}
      h={tight ? 1.5 : 2}
      kind="big"
      label="COMMISSION"
      state={live ? 'idle' : 'dead'}
      // Paying parts always takes a deliberate move to the key: it only starts focused when
      // nothing is due.
      auto={live && !due ? 3 : undefined}
      onClick={() => {
        const modules: Record<string, string> = {};
        for (const s of fit.slots) {
          if (s.pick) {
            modules[s.key] = s.pick.id;
          }
        }
        ctx.found({
          action: 'yard_commission',
          params: {
            hull: hull.id,
            finish: fit.finish?.id || '',
            modules,
            total: bill.total,
          },
          label: 'COMMISSION',
        });
      }}
    />,
  );

  return <>{out}</>;
}
