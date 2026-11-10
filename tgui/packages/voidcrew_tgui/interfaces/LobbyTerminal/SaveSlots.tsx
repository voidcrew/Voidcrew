/**
 * SAVED SHIPS box on the shipyard home: one card per slot with the ship's floor plan,
 * name, class, what it carries and LOAD, a denial line, or UNDER WAY. Too narrow for three
 * cards, it becomes a one-line-per-slot list.
 */
import type { ReactNode } from 'react';
import { useBackend } from 'tgui/backend';

import { PlanPic } from './PlanPic';
import { Blocks, Frame, Put, pad, RPut, wrap } from './term';
import type { LobbyData, SaveCard } from './types';
import { Key, thousands, type YardCtx } from './YardTab';

const MIN_CARD = 26;

type Props = {
  saves: (SaveCard | null)[];
  x: number;
  y: number;
  w: number;
  h: number;
  ctx: YardCtx;
};

/** LOAD, or CONFIRM after the first press when loading leaves a crew. */
function useLoad(ctx: YardCtx) {
  const { act } = useBackend<LobbyData>();
  return (sv: SaveCard) => {
    const key = `load${sv.slot}`;
    if (ctx.crewChange && ctx.view.confirm !== key) {
      ctx.set({ confirm: key });
      return;
    }
    ctx.set({ confirm: null });
    act('yard_load', { slot: sv.slot, leave_crew: ctx.crewChange ? 1 : 0 });
  };
}

export function SaveSlots(props: Props) {
  const { saves, x, y, w, h, ctx } = props;
  const gap = 2;
  const n = Math.max(1, saves.length);
  const cardW = Math.floor((w - 4 - gap * (n - 1)) / n);
  if (cardW < MIN_CARD || h < 14) {
    return <SaveList {...props} />;
  }
  return (
    <Frame x={x} y={y} w={w} h={h} title="SAVED SHIPS">
      {saves.map((sv, i) => (
        <Card
          key={i}
          sv={sv}
          n={sv?.slot || i + 1}
          x={x + 2 + i * (cardW + gap)}
          y={y + 1}
          w={cardW}
          h={h - 2}
          ctx={ctx}
        />
      ))}
    </Frame>
  );
}

function Card(props: {
  sv: SaveCard | null;
  n: number;
  x: number;
  y: number;
  w: number;
  h: number;
  ctx: YardCtx;
}) {
  const { sv, n, x, y, w, h, ctx } = props;
  const load = useLoad(ctx);
  const out: ReactNode[] = [];
  if (!sv) {
    return (
      <Frame x={x} y={y} w={w} h={h} title={`SLOT ${n}`} dim>
        <Put
          x={x + Math.floor((w - 5) / 2)}
          y={y + Math.floor(h / 2)}
          cls="faint"
        >
          EMPTY
        </Put>
      </Frame>
    );
  }
  const ix = x + 2;
  const iw = w - 4;
  const denied = !!sv.denial;
  const fit = sv.fit || [];

  const lines: [string, number | null, string][] = fit.map((f) => [
    f[0],
    f[1],
    f[2] ?? 'red',
  ]);
  if (sv.lab) {
    lines.push(['Lab machines', sv.lab, '']);
  }
  if (sv.cargo) {
    lines.push(['Cargo machines', sv.cargo, 'amb']);
  }
  if (sv.research) {
    lines.push([`Research, ${sv.research} nodes`, null, '']);
  }
  if (sv.funds) {
    lines.push([`Holds ${thousands(sv.funds)} cr`, null, 'amb']);
  }

  const nameRows = Math.min(2, wrap(sv.name.toUpperCase(), iw).length);
  const hasStats = sv.mass !== undefined || sv.crew !== undefined;
  // Rows below the lines: the key, or a two-line denial, or LEAVES + the key.
  const foot = denied ? 2 : 1 + (ctx.crewChange ? 1 : 0);
  // The plan shrinks (to 3 rows) before the first few fit lines are cut.
  // Short cards drop the blank row under the stats.
  const statRows = hasStats ? (h < 15 ? 1 : 2) : 1;
  const fixed = 4 + nameRows + 1 + statRows + foot;
  const prH = Math.max(2, Math.min(11, h - fixed - Math.min(4, lines.length)));
  if (sv.plan) {
    out.push(
      <PlanPic
        key="plan"
        x={ix}
        y={y + 1.5}
        w={iw}
        h={prH - 0.5}
        plan={sv.plan}
        faded={denied}
      />,
    );
  }
  let yy = y + 1 + prH + 1;
  const nameLines = wrap(sv.name.toUpperCase(), iw);
  const nm = nameLines.slice(0, 2);
  if (nameLines.length > 2) {
    nm[1] = `${pad(nm[1], iw - 1)}.`;
  }
  nm.forEach((l, i) => {
    out.push(
      <Put key={`n${i}`} x={ix} y={yy++} cls={denied ? 'dim' : ''}>
        {l}
      </Put>,
    );
  });
  out.push(
    <Put key="cls" x={ix} y={yy++} cls="dim">
      {pad(sv.class, iw)}
    </Put>,
  );
  if (hasStats) {
    if (sv.mass !== undefined) {
      out.push(
        <Put key="ml" x={ix} y={yy} cls="dim">
          MASS
        </Put>,
        <Put key="mv" x={ix + 5} y={yy} cls={denied ? 'dim' : ''}>
          {`${thousands(sv.mass)} t`}
        </Put>,
      );
    }
    if (sv.crew !== undefined) {
      const cx = sv.mass !== undefined ? ix + 16 : ix;
      out.push(
        <Put key="cl" x={cx} y={yy} cls="dim">
          CREW
        </Put>,
        <Put key="cv" x={cx + 5} y={yy} cls={denied ? 'dim' : ''}>
          {String(sv.crew)}
        </Put>,
      );
    }
    yy += statRows;
  } else {
    yy += 1;
  }

  const room = Math.max(0, y + h - 2 - foot - yy);
  const show =
    lines.length > room ? lines.slice(0, Math.max(0, room - 1)) : lines;
  show.forEach(([label, count, cls], i) => {
    out.push(
      <Blocks
        key={`b${i}`}
        x={ix}
        y={yy}
        n={1}
        cls={cls === 'red' ? 'rblk' : cls === 'amb' ? 'ablk' : 'dim'}
        frac={0.35}
      />,
      <Put key={`l${i}`} x={ix + 2} y={yy} cls={denied ? 'faint' : 'dim'}>
        {pad(label, iw - 6)}
      </Put>,
    );
    if (count) {
      out.push(
        <RPut key={`c${i}`} x={ix + iw} y={yy} cls={denied ? 'faint' : ''}>
          {String(count)}
        </RPut>,
      );
    }
    yy++;
  });
  if (room > 0 && show.length < lines.length) {
    out.push(
      <Put key="more" x={ix + 2} y={yy++} cls="faint">
        {`+${lines.length - show.length} more`}
      </Put>,
    );
  }

  const by = y + h - 2;
  if (sv.denial) {
    wrap(sv.denial, iw)
      .slice(-2)
      .reverse()
      .forEach((l, i) => {
        out.push(
          <Put key={`d${i}`} x={ix} y={by - i} cls="amb">
            {l}
          </Put>,
        );
      });
  } else if (sv.locked) {
    out.push(
      <Put key="uw" x={ix} y={by} cls="faint">
        UNDER WAY
      </Put>,
    );
  } else {
    const confirming = ctx.view.confirm === `load${sv.slot}`;
    if (ctx.crewChange && confirming) {
      out.push(
        <Put key="lv" x={ix} y={by - 1} cls="amb">
          {pad(`LEAVES ${ctx.crewChange.toUpperCase()}`, iw)}
        </Put>,
      );
    }
    out.push(
      <Key
        key="load"
        x={ix}
        y={by}
        label={confirming ? 'CONFIRM' : 'LOAD'}
        cls="inv"
        disabled={!ctx.open}
        onClick={() => load(sv)}
      />,
    );
  }

  return (
    <Frame x={x} y={y} w={w} h={h} title={`SLOT ${n}`} dim>
      {out}
    </Frame>
  );
}

/** Narrow windows: one line per slot. */
function SaveList(props: Props) {
  const { saves, x, y, w, h, ctx } = props;
  const load = useLoad(ctx);
  const out: ReactNode[] = [];
  let yy = y + 2;
  const keyW = 12;
  saves.forEach((sv, i) => {
    if (yy > y + h - 2) {
      return;
    }
    const n = sv?.slot || i + 1;
    out.push(
      <Put key={`s${i}`} x={x + 3} y={yy} cls="dim">
        {String(n)}
      </Put>,
    );
    if (!sv) {
      out.push(
        <Put key={`e${i}`} x={x + 6} y={yy} cls="faint">
          EMPTY
        </Put>,
      );
      yy += 2;
      return;
    }
    const nameW = Math.max(4, w - 6 - keyW - 4);
    out.push(
      <Put key={`n${i}`} x={x + 6} y={yy} cls={sv.denial ? 'dim' : ''}>
        {pad(sv.name.toUpperCase(), nameW)}
      </Put>,
    );
    if (sv.denial) {
      out.push(
        <Put key={`d${i}`} x={x + 6} y={yy + 1} cls="amb">
          {pad(sv.denial, w - 9)}
        </Put>,
      );
    } else if (sv.locked) {
      out.push(
        <RPut key={`u${i}`} x={x + w - 3} y={yy} cls="faint">
          UNDER WAY
        </RPut>,
      );
    } else {
      const confirming = ctx.view.confirm === `load${sv.slot}`;
      out.push(
        <Put key={`c${i}`} x={x + 6} y={yy + 1} cls="dim">
          {pad(sv.class, w - 9)}
        </Put>,
        <Key
          key={`k${i}`}
          x={x + w - 3}
          y={yy}
          right
          label={confirming ? 'CONFIRM' : 'LOAD'}
          cls="inv"
          disabled={!ctx.open}
          onClick={() => load(sv)}
        />,
      );
    }
    yy += 3;
  });
  if (ctx.crewChange && ctx.view.confirm?.startsWith('load')) {
    out.push(
      <Put key="lv" x={x + 3} y={y + h - 2} cls="amb">
        {pad(`LEAVES ${ctx.crewChange.toUpperCase()}`, w - 6)}
      </Put>,
    );
  }
  return (
    <Frame x={x} y={y} w={w} h={h} title="SAVED SHIPS">
      {out}
    </Frame>
  );
}
