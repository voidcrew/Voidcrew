/**
 * CREWS tab: one line per crew, and the record of the selected one beside it (or in its
 * place on a narrow screen). Package P2. Draws only with the term.tsx primitives; content
 * lives between rows TOP and rows - 2 (rows - 1 is the shell's notice line).
 */
import { type ReactNode, useState } from 'react';
import { useBackend } from 'tgui/backend';

import { CrewRecordPane, isLocked } from './CrewRecord';
import { useBack } from './nav';
import { Frame, Hit, lpad, Put, pad, TOP, useGrid } from './term';
import type { Crew, LobbyData } from './types';

function openSlots(c: Crew): number {
  return c.jobs.reduce((sum, job) => sum + job.open, 0);
}

/** Status word and its colour, as in the mockup. Open crews show nothing. */
function status(c: Crew): [string, string] | null {
  if (!c.jobs.length) {
    return ['FULL', 'red'];
  }
  if (c.applied) {
    return ['APPLIED', 'amb'];
  }
  if (isLocked(c)) {
    return ['LOCKED', 'amb'];
  }
  return null;
}

export function CrewsTab() {
  const { data } = useBackend<LobbyData>();
  const { cols, rows, narrow } = useGrid();
  const crews = data.crews || [];
  const [selRef, setSelRef] = useState<string | null>(null);
  const [page, setPage] = useState(1);
  /** Which row of a new page takes the focus: the last when paging up with the arrow keys. */
  const [enterLast, setEnterLast] = useState(false);

  const selected = crews.find((c) => c.ref === selRef) || null;
  const h = rows - 1 - TOP;
  // The record's own BACK (CrewRecord) wins while it is open; this only covers a stale selection.
  useBack(selected ? () => setSelRef(null) : null);

  if (selected && narrow) {
    return (
      <CrewRecordPane
        crew={selected}
        x={0}
        w={cols}
        h={h}
        narrow
        onClose={() => setSelRef(null)}
      />
    );
  }

  const split = !!selected;
  // The mockup splits 64 | 46 at 110 columns.
  const lw = split ? Math.round((cols * 64) / 110) : cols;
  const showMemo = !split && !narrow;
  // Fixed-width columns are placed from the right; the class column takes a share of the rest.
  // With the memo column it starts at the mockup's share of the width (column 70 of 126).
  const memo = Math.round((cols * 70) / 126);
  const st = showMemo ? memo - 10 : lw - 11;
  const open = st - (showMemo ? 7 : 6);
  const crewCol = open - (showMemo ? 7 : 6);
  const name = 3;
  const cls = name + Math.min(26, Math.round((crewCol - name) * 0.58));

  const hy = TOP + 1;
  const fit = Math.max(1, h - 3);
  const pages = Math.max(1, Math.ceil(crews.length / fit));
  const pg = Math.min(pages, Math.max(1, page));
  const shown = crews.slice((pg - 1) * fit, pg * fit);

  const out: ReactNode[] = [];
  out.push(
    <Put key="hn" x={name} y={hy} cls="dim">
      SHIP
    </Put>,
    <Put key="hc" x={cls} y={hy} cls="dim">
      CLASS
    </Put>,
    <Put key="hr" x={crewCol} y={hy} cls="dim">
      CREW
    </Put>,
    <Put key="ho" x={open} y={hy} cls="dim">
      OPEN
    </Put>,
  );
  if (showMemo) {
    out.push(
      <Put key="hm" x={memo} y={hy} cls="dim">
        MEMO
      </Put>,
    );
  }

  if (!crews.length) {
    out.push(
      <Put key="none" x={3} y={hy + 2} cls="dim">
        {data.phase === 'playing'
          ? 'NO CREWS ARE SIGNING ON.'
          : 'CREWS SIGN ON ONCE THE PORT OPENS.'}
      </Put>,
    );
  }

  shown.forEach((c, i) => {
    const y = hy + 1 + i;
    const isSel = c.ref === selRef;
    const k = isSel ? 'inv' : '';
    const slots = openSlots(c);
    const stat = status(c);
    if (isSel) {
      out.push(
        <Put key={`bar${c.ref}`} x={1} y={y} cls="inv">
          {' '.repeat(Math.max(0, lw - 3))}
        </Put>,
      );
    }
    out.push(
      <Put key={`p${c.ref}`} x={1} y={y} cls={k}>
        {isSel ? '>' : ' '}
      </Put>,
      <Put key={`n${c.ref}`} x={name} y={y} cls={k}>
        {pad(c.name.toUpperCase(), cls - name - 1)}
      </Put>,
      <Put key={`c${c.ref}`} x={cls} y={y} cls={isSel ? 'inv' : 'dim'}>
        {pad(c.cls, crewCol - cls - 1)}
      </Put>,
      <Put key={`r${c.ref}`} x={crewCol} y={y} cls={k}>
        {lpad(c.crew, 3)}
      </Put>,
      <Put
        key={`o${c.ref}`}
        x={open}
        y={y}
        cls={isSel ? 'inv' : slots ? '' : 'faint'}
      >
        {lpad(slots || '-', 3)}
      </Put>,
    );
    if (stat) {
      out.push(
        <Put key={`s${c.ref}`} x={st} y={y} cls={isSel ? 'inv' : stat[1]}>
          {stat[0]}
        </Put>,
      );
    }
    if (showMemo) {
      out.push(
        <Put key={`m${c.ref}`} x={memo} y={y} cls={isSel ? 'inv' : 'dim'}>
          {pad(c.memo, cols - memo - 2)}
        </Put>,
      );
    }
    const firstRow = i === 0;
    const lastRow = i === shown.length - 1;
    out.push(
      <Hit
        key={`h${pg}-${c.ref}`}
        x={1}
        y={y}
        w={lw - 3}
        h={1}
        onClick={() => setSelRef(isSel ? null : c.ref)}
        auto={(enterLast ? lastRow : firstRow) ? 1 : undefined}
        edge={{
          down:
            lastRow && pg < pages
              ? () => {
                  setEnterLast(false);
                  setPage(pg + 1);
                  return true;
                }
              : undefined,
          up:
            firstRow && pg > 1
              ? () => {
                  setEnterLast(true);
                  setPage(pg - 1);
                  return true;
                }
              : undefined,
        }}
      />,
    );
  });

  if (pages > 1) {
    const py = TOP + h - 1;
    const label = ` ${pg}/${pages} `;
    out.push(
      <Put
        key="prev"
        x={lw - 14}
        y={py}
        cls={pg > 1 ? 'inv' : 'faint'}
        bg={pg <= 1}
        onClick={
          pg > 1
            ? () => {
                setEnterLast(false);
                setPage(pg - 1);
              }
            : undefined
        }
      >
        {' < '}
      </Put>,
      <Put key="pg" x={lw - 11} y={py} bg>
        {label}
      </Put>,
      <Put
        key="next"
        x={lw - 11 + label.length}
        y={py}
        cls={pg < pages ? 'inv' : 'faint'}
        bg={pg >= pages}
        onClick={
          pg < pages
            ? () => {
                setEnterLast(false);
                setPage(pg + 1);
              }
            : undefined
        }
      >
        {' > '}
      </Put>,
    );
  }

  return (
    <>
      <Frame x={0} y={TOP} w={lw} h={h} title={`CREWS  ${crews.length}`}>
        {out}
      </Frame>
      {!!selected && (
        <CrewRecordPane
          crew={selected}
          x={lw + 1}
          w={cols - lw - 1}
          h={h}
          narrow={false}
          onClose={() => setSelRef(null)}
        />
      )}
    </>
  );
}
