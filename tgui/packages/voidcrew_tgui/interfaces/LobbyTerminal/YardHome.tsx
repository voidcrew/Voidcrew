/**
 * SHIPYARD home (spec 02, 3.2): two stacked boxes. SHIPYARD holds the NEW SHIP slab with the
 * parts on account and, while the yard offers one, the SURPLUS HULL slab. SAVED SHIPS holds
 * the three save slots (SaveSlots.tsx).
 *
 * Forms, the first that fits: 1 tall top slabs and full slots; 2 compact top slabs and full
 * slots; 3 tall top slabs and compact slot rows; 4 compact everything (M = 18 with the
 * surplus hull leaves exactly 7.25 rows for three rows).
 */
import { useBackend } from 'tgui/backend';

import { SaveSlots } from './SaveSlots';
import {
  BOX_Y,
  Box,
  ClassFigures,
  ClassHeads,
  fig,
  Key,
  NameLine,
  PART_CLASSES,
  Put,
  Slab,
  SEP,
  useGrid,
} from './term';
import type { LobbyData, SaveCard } from './types';
import { YARD_OPENS, type YardCtx } from './YardTab';

/** Rounded down to a quarter row. */
const f4 = (v: number) => Math.floor(v * 4) / 4;

const BEFORE_ROUND = ['loading', 'pregame', 'setup'];

/** Compact NEW SHIP figures: `COMBAT n` at 10, `SCIENCE n` at 23, `TRADE n` at 37, `MISC n` at 49. */
const COMPACT_AT = [10, 23, 37, 49];

/** A slot whose ship could load once the port opens. */
export function loadable(card: SaveCard | null): boolean {
  return !!card && !card.denial && !card.locked;
}

export type HomeForm = {
  /** Top slabs tall (h 3) or compact (h 2.25). */
  tall: boolean;
  /** Slots full (plan, h = slotH) or compact rows. */
  full: boolean;
  /** Rows of slabs in the SHIPYARD box. */
  a: number;
  /** First slot row. */
  yB: number;
  /** Rows the slots may use. */
  availB: number;
  /** Full slot height. */
  slotH: number;
};

export function homeForm(M: number, tops: number, foot: number): HomeForm {
  const at = (Ht: number) => {
    const a = tops * Ht + 0.25 * (tops - 1);
    const yB = a + 4.75;
    const availB = M - 1.25 - yB - foot;
    return { a, yB, availB, slotH: f4((availB - 0.5) / 3) };
  };
  const tallF = at(3);
  if (tallF.slotH >= 4) {
    return { tall: true, full: true, ...tallF };
  }
  const compF = at(2.25);
  if (compF.slotH >= 4) {
    return { tall: false, full: true, ...compF };
  }
  if (tallF.availB >= 7.25) {
    return { tall: true, full: false, ...tallF };
  }
  return { tall: false, full: false, ...compF };
}

export function YardHome(props: { ctx: YardCtx }) {
  const { ctx } = props;
  const { data } = useBackend<LobbyData>();
  const { rows: M } = useGrid();
  const req = !!data.can_requisition;
  const saves = data.saves || { state: 'wait', slots: [] };
  const slots: (SaveCard | null)[] =
    saves.state === 'ok' ? [0, 1, 2].map((i) => saves.slots[i] || null) : [];
  const before = BEFORE_ROUND.includes(data.phase);
  const footLine = before && slots.some(loadable);
  const form = homeForm(M, req ? 2 : 1, footLine ? 1.25 : 0);
  const Ht = form.tall ? 3 : 2.25;
  const variant = form.tall ? 'block' : 'row';
  const y0 = 3;
  const y1 = y0 + Ht + 0.25;

  // The parts on account: not drawn while the ledger is read, nor when every hull is free.
  const ledger = data.free_ships ? 'none' : ctx.ledger;
  const account = data.account || {};

  return (
    <>
      <Box
        x={0}
        y={BOX_Y}
        w={63}
        h={form.a + 0.75}
        caption="SHIPYARD"
      />
      <Slab
        x={1}
        y={y0}
        w={61}
        h={Ht}
        variant={variant}
        onClick={ctx.go.hulls}
        auto={1}
      >
        {form.tall ? (
          <NameLine x={3} y={y0 + 0.25} w={22} text="NEW SHIP" />
        ) : (
          <Put x={3} y={y0 + 0.125} cls="wht">
            NEW SHIP
          </Put>
        )}
        {ledger === 'off' && (
          <Put x={3} y={y0 + (form.tall ? 1.5 : 1.125)} cls="dim">
            {form.tall ? 'Ledger offline' : 'LEDGER OFFLINE'}
          </Put>
        )}
        {ledger === 'ok' && !!form.tall && (
          <>
            <Put x={3} y={y0 + 1.5} cls="dim">
              Parts on account
            </Put>
            <ClassHeads y={y0 + 0.375} set="R" />
            <ClassFigures
              y={y0 + 1.5}
              set="R"
              values={account}
              big
              zero
            />
          </>
        )}
        {ledger === 'ok' && !form.tall && (
          <>
            <Put x={3} y={y0 + 1.125} cls="dim">
              PARTS
            </Put>
            {PART_CLASSES.map((k, i) => (
              <Put key={k} x={COMPACT_AT[i]} y={y0 + 1.125} cls="dim">
                {k.toUpperCase()}
              </Put>
            ))}
            {PART_CLASSES.map((k, i) => (
              <Put key={`n${k}`} x={COMPACT_AT[i] + k.length + 1} y={y0 + 1.125}>
                {fig(account[k]) || '0'}
              </Put>
            ))}
          </>
        )}
      </Slab>
      {!!req && (
        <Slab x={1} y={y1} w={61} h={Ht} variant={variant}>
          {form.tall ? (
            <NameLine x={3} y={y1 + 0.25} w={40} text="SURPLUS HULL" />
          ) : (
            <Put x={3} y={y1 + 0.125} cls="wht">
              SURPLUS HULL
            </Put>
          )}
          <Put x={3} y={y1 + (form.tall ? 1.5 : 1.125)} cls="dim">
            {`Yard's choice ${SEP} no charge`}
          </Put>
          <Key
            kind="cap"
            x={44}
            y={y1 + (form.tall ? 0.75 : 0.375)}
            w={17}
            label="[ REQUISITION ]"
            state={!ctx.open || ctx.sent ? 'dead' : 'idle'}
            onClick={() =>
              ctx.found({
                action: 'yard_requisition',
                params: {},
                label: 'REQUISITION',
              })
            }
          />
        </Slab>
      )}
      <Box
        x={0}
        y={form.a + 4.25}
        w={63}
        // Offline: the box closes round its one ghost block, not round an empty pane.
        h={saves.state === 'off' ? 5.5 : M - 5.25 - form.a}
        caption="SAVED SHIPS"
      />
      <SaveSlots
        ctx={ctx}
        state={saves.state}
        slots={slots}
        plans={data.save_plans || []}
        form={form}
      />
      {!!footLine && (
        <Put x={3} y={M - 2.25} cls="amb">
          {YARD_OPENS}
        </Put>
      )}
    </>
  );
}
