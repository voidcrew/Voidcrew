/**
 * BILL: the fitted ship and its crew on the left, the one bill on the right (each line,
 * total, parts on account, any shortfall) and [ COMMISSION ]. When commissioning leaves a
 * crew, one amber LEAVES line shows and the key reads CONFIRM after the first press.
 * Narrow: the bill alone.
 *
 * The client sends the configuration, never prices; the server works out the bill again.
 */
import type { ReactNode } from 'react';

import { ShipPic } from './ShipPic';
import { Frame, lpad, Put, pad, RPut, Rule, TOP, useGrid } from './term';
import type { Hull, LobbyActions } from './types';
import {
  billOf,
  costOf,
  crewOf,
  fitOf,
  Key,
  PART_ORDER,
  partsOf,
  usePreview,
  type YardCtx,
} from './YardTab';

export function Bill(props: {
  ctx: YardCtx;
  hull: Hull;
  onCommission: (params: LobbyActions['yard_commission']) => void;
}) {
  const { ctx, hull, onCommission } = props;
  const { view, set, own } = ctx;
  const { cols, rows, narrow } = useGrid();
  usePreview(hull.id);
  const h = rows - 1 - TOP;
  const fit = fitOf(hull, view.finish, view.picks);
  const bill = billOf(own, fit, ctx.account);
  const crew = crewOf(fit);
  const crewN = crew.reduce((a, l) => a + l[1], 0);
  const out: ReactNode[] = [];

  const lw = narrow ? 0 : Math.floor(cols * 0.5);
  if (!narrow) {
    out.push(
      <Frame
        key="sf"
        x={0}
        y={TOP}
        w={lw}
        h={h}
        title={hull.short.toUpperCase()}
      />,
    );
    const ph = Math.floor(h * 0.55);
    out.push(
      <ShipPic key="pic" x={2} y={TOP + 1.5} w={lw - 4} h={ph - 1} fit={fit} />,
    );
    let y = TOP + ph + 1;
    out.push(<Rule key="r" x={1} y={y} w={lw - 2} />);
    y++;
    out.push(
      <Put key="cl" x={3} y={y} cls="dim">
        CREW
      </Put>,
      <Put key="cv" x={9} y={y}>
        {String(crewN)}
      </Put>,
    );
    y += 2;
    // Two columns only when every job title still fits whole in one; otherwise one column.
    const longest = crew.reduce((m, [job]) => Math.max(m, job.length), 0);
    const twoColW = Math.floor((lw - 6) / 2);
    const columns = twoColW - 5 >= longest ? 2 : 1;
    const colW = columns === 2 ? twoColW : lw - 6;
    const per = Math.max(1, Math.ceil(crew.length / columns));
    crew.forEach(([job, n], i) => {
      const cx = 3 + Math.floor(i / per) * colW;
      const cy = y + (i % per);
      if (cy >= TOP + h - 1) {
        return;
      }
      out.push(
        <Put key={`j${i}`} x={cx} y={cy}>
          {pad(job, colW - 5)}
        </Put>,
        <Put key={`n${i}`} x={cx + colW - 4} y={cy} cls="dim">
          {lpad(n, 2)}
        </Put>,
      );
    });
  }

  const x = narrow ? 0 : lw + 1;
  const w = cols - x;
  out.push(<Frame key="bf" x={x} y={TOP} w={w} h={h} title="BILL" />);
  let y = TOP + 2;
  const by = TOP + h - 3;
  const labelW = Math.min(14, Math.max(8, Math.floor(w * 0.25)));
  const nameX = x + 3 + labelW + 1;
  // Leave the bottom of the box to the total, account, warnings and keys.
  const lineEnd = by - 7;
  bill.lines.forEach(([label, name, cost], i) => {
    if (y >= lineEnd) {
      return;
    }
    const costText = cost ? costOf(cost) || '-' : '-';
    const nameRoom = x + w - 3 - nameX;
    // A long price drops to its own row under the name.
    const own = nameRoom - (costText.length + 2) < 10;
    out.push(
      <Put key={`ll${i}`} x={x + 3} y={y} cls="dim">
        {pad(label, labelW)}
      </Put>,
      <Put key={`ln${i}`} x={nameX} y={y}>
        {pad(
          name,
          own ? nameRoom : nameRoom - Math.max(9, costText.length + 2),
        )}
      </Put>,
    );
    if (own) {
      y++;
    }
    out.push(
      <RPut
        key={`lc${i}`}
        x={x + w - 3}
        y={y}
        cls={cost && partsOf(cost) ? 'amb' : 'faint'}
      >
        {costText.slice(-(w - 6))}
      </RPut>,
    );
    y++;
  });
  y++;
  out.push(<Rule key="br" x={x + 1} y={y} w={w - 2} />);
  y += 2;
  const short = Object.keys(bill.short).length > 0;
  const due = partsOf(bill.total);
  out.push(
    <Put key="tl" x={x + 3} y={y} cls="dim">
      TOTAL
    </Put>,
    <RPut
      key="tv"
      x={x + w - 3}
      y={y}
      cls={short ? 'red' : due ? 'amb' : 'dim'}
    >
      {costOf(bill.total) || '-'}
    </RPut>,
  );
  y++;
  const accountText = PART_ORDER.map(
    (k) =>
      `${ctx.account?.[k] || 0} ${narrow ? k.slice(0, 3).toUpperCase() : k.toUpperCase()}`,
  ).join('  ');
  out.push(
    <Put key="al" x={x + 3} y={y} cls="dim">
      {narrow ? 'HELD' : 'ON ACCOUNT'}
    </Put>,
    <RPut key="av" x={x + w - 3} y={y} cls="dim">
      {accountText}
    </RPut>,
  );

  const confirming = view.confirm === 'commission';
  const blocked = short || !ctx.open;
  if (short) {
    out.push(
      <Put key="sl" x={x + 3} y={by - 2} cls="red">
        SHORT
      </Put>,
      <Put key="sv" x={x + 10} y={by - 2} cls="red">
        {costOf(bill.short)}
      </Put>,
    );
  } else if (!ctx.open) {
    out.push(
      <Put key="wait" x={x + 3} y={by - 2} cls="amb">
        THE YARD OPENS AT DEPARTURE
      </Put>,
    );
  } else if (ctx.crewChange) {
    out.push(
      <Put key="lv" x={x + 3} y={by - 2} cls="amb">
        {pad(`LEAVES ${ctx.crewChange.toUpperCase()}`, w - 6)}
      </Put>,
    );
  }
  const commission = () => {
    if (ctx.crewChange && !confirming) {
      set({ confirm: 'commission' });
      return;
    }
    const modules: Record<string, string> = {};
    for (const s of fit.slots) {
      if (s.pick) {
        modules[s.key] = s.pick.id;
      }
    }
    onCommission({
      hull: hull.id,
      finish: fit.finish?.id || '',
      modules,
      leave_crew: ctx.crewChange ? 1 : 0,
    });
  };
  out.push(
    <Key
      key="com"
      x={x + 3}
      y={by}
      label={confirming ? 'CONFIRM' : 'COMMISSION'}
      cls={confirming ? 'inva' : 'inv'}
      disabled={blocked}
      onClick={commission}
    />,
  );
  // A hull with nothing to fit has no CHANGE FIT.
  if (fit.hull.finishes.length || fit.hull.slots.length) {
    out.push(
      <Key
        key="chg"
        x={x + 20}
        y={by}
        label="CHANGE FIT"
        cls="dim"
        onClick={() => set({ screen: 'fit' })}
      />,
    );
  }

  return <>{out}</>;
}
