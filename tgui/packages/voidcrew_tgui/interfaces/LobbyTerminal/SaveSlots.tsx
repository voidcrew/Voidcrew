/**
 * SAVED SHIPS on the shipyard home (spec 02, 3.2): always three slot slabs. Full slots carry
 * the saved hull's plan in a well, the name, the class line, what the save carries and
 * [ LOAD ]; compact rows (short panes) carry two lines and the key. States: EMPTY, ready,
 * ready before the port opens (LOAD dead), UNDER WAY, refused (the reason in amber, the plan
 * faded). The box itself: `wait` draws three blank slabs, `off` one ghost block.
 */
import type { ReactNode } from 'react';

import { PlanPic } from './PlanPic';
import {
  Big,
  CUT,
  cut,
  Key,
  NameLine,
  Put,
  RPut,
  SEP,
  Slab,
  safe,
  Well,
  wrapMax,
} from './term';
import type { SaveCard, YardSaves } from './types';
import type { HomeForm } from './YardHome';
import type { YardCtx } from './YardTab';

/** Carries text: columns 18 to 46. */
const CARRY_W = 29;
/** Full slot name: columns 18 to 60. */
const NAME_W = 43;
/** Class line: 35, then the cut mark. */
const CLASS_W = 35;
/** Compact row text: columns 3 to 46; a refusal runs to 60. */
const ROW_W = 44;
const ROW_DENIAL_W = 58;

type SlotState = 'empty' | 'blank' | 'ready' | 'under' | 'refused';

function stateOf(card: SaveCard | null, blank: boolean): SlotState {
  if (blank) {
    return 'blank';
  }
  if (!card) {
    return 'empty';
  }
  if (card.locked) {
    return 'under';
  }
  return card.denial ? 'refused' : 'ready';
}

/** `<Class> • <n> berths`; the class drops out when the name starts with it. */
function classLine(card: SaveCard, name: string): string {
  const cls = safe(card.class).trim();
  const n = Math.max(0, Math.min(999, Math.floor(card.crew || 0)));
  const berths = `${n} ${n === 1 ? 'berth' : 'berths'}`;
  if (!cls || name.startsWith(cls.toUpperCase())) {
    return berths;
  }
  return `${cls} ${SEP} ${berths}`;
}

/** As many whole items as fit `w` from item `i`; an item longer than `w` is cut. */
function fitItems(items: string[], i: number, w: number): [string, number] {
  let text = '';
  let j = i;
  while (j < items.length) {
    const next = text ? `${text} ${SEP} ${items[j]}` : items[j];
    if (next.length > w) {
      break;
    }
    text = next;
    j++;
  }
  if (!text && j < items.length) {
    return [cut(items[j], w), j + 1];
  }
  return [text, j];
}

/**
 * The carries run in at most `n` lines of `w`: whole items joined by ` • `; when items are
 * left over, the last line ends in the cut mark.
 */
export function carryLines(items: string[], n: number, w: number): string[] {
  const out: string[] = [];
  let i = 0;
  for (let l = 0; l < n && i < items.length; l++) {
    let [text, next] = fitItems(items, i, w);
    if (l === n - 1 && next < items.length) {
      [text, next] = fitItems(items, i, w - 1);
      if (!text.endsWith(CUT)) {
        text += CUT;
      }
    }
    out.push(text);
    i = next;
  }
  return out;
}

function itemsOf(card: SaveCard): string[] {
  return (card.carries || [])
    .slice(0, 12)
    .map((s) => safe(s).replace(/\s+/g, ' ').trim())
    .filter(Boolean);
}

export function SaveSlots(props: {
  ctx: YardCtx;
  state: YardSaves['state'];
  /** ok: three entries, null for an empty slot. */
  slots: (SaveCard | null)[];
  plans: (string | null)[];
  form: HomeForm;
}) {
  const { ctx, state, slots, plans, form } = props;
  const { yB } = form;
  if (state === 'off') {
    return (
      <Slab x={1} y={yB} w={61} h={4.75} variant="block" dead>
        <NameLine
          x={3}
          y={yB + 0.25}
          w={57}
          text="YARD RECORDS OFFLINE."
          cls="dim"
        />
      </Slab>
    );
  }
  const blank = state !== 'ok';
  const live = ctx.open && !ctx.sent;
  const load = (card: SaveCard) =>
    ctx.found({
      action: 'yard_load',
      params: { slot: card.slot },
      label: 'LOAD',
      restores: !!card.restores,
    });
  const out: ReactNode[] = [];
  for (let i = 0; i < 3; i++) {
    const card = blank ? null : slots[i] || null;
    const st = stateOf(card, blank);
    const n = card?.slot || i + 1;
    if (form.full) {
      const h = form.slotH;
      out.push(
        <FullSlot
          key={i}
          n={n}
          card={card}
          st={st}
          ys={yB + i * (h + 0.25)}
          h={h}
          plan={plans[i] || null}
          live={live}
          onLoad={load}
        />,
      );
    } else {
      out.push(
        <RowSlot
          key={i}
          n={n}
          card={card}
          st={st}
          ys={yB + i * 2.5}
          alt={i % 2 === 1}
          live={live}
          onLoad={load}
        />,
      );
    }
  }
  return <>{out}</>;
}

/**
 * Seam workaround: `.lt-vscreen` has no z-index, so a Well inside a Slab (z-index 1) draws under
 * the slab's fill. This lifts it to the text layer without catching the mouse.
 */
function Lift(props: { children: ReactNode }) {
  return (
    <div
      style={{
        position: 'absolute',
        inset: 0,
        zIndex: 2,
        pointerEvents: 'none',
      }}
    >
      {props.children}
    </div>
  );
}

function FullSlot(props: {
  n: number;
  card: SaveCard | null;
  st: SlotState;
  ys: number;
  h: number;
  plan: string | null;
  live: boolean;
  onLoad: (card: SaveCard) => void;
}) {
  const { n, card, st, ys, h, plan, live, onLoad } = props;
  const p = h >= 4.75 ? 0.25 : 0.125;
  const wellH = h - 2 * p;
  const nC = Math.max(1, Math.min(4, Math.floor(h - 2 * p - 2.25)));
  const dead = st === 'empty' || st === 'blank';
  let well: ReactNode;
  if (dead) {
    well = <Well x={3} y={ys + p} w={14} h={wellH} />;
  } else if (plan) {
    well = (
      <Well x={3} y={ys + p} w={14} h={wellH}>
        <PlanPic
          x={1}
          y={0.25}
          w={12}
          h={wellH - 0.5}
          plan={plan}
          faded={st === 'refused'}
        />
      </Well>
    );
  } else {
    well = <Well x={3} y={ys + p} w={14} h={wellH} note="NO PLAN ON FILE" />;
  }
  const body: ReactNode[] = [];
  if (st === 'empty') {
    body.push(
      <NameLine key="n" x={18} y={ys + p} w={30} text="EMPTY" cls="dim" />,
      <RPut key="s" x={61} y={ys + p + 0.125} cls="dim">
        {`SLOT ${n}`}
      </RPut>,
    );
  } else if (card) {
    const name = safe(card.name).toUpperCase();
    const quiet = st !== 'ready';
    body.push(
      <NameLine
        key="n"
        x={18}
        y={ys + p}
        w={NAME_W}
        text={name}
        cls={quiet ? 'dim' : undefined}
      />,
      <Put key="c" x={18} y={ys + p + 1.25} cls="dim">
        {cut(classLine(card, name), CLASS_W)}
      </Put>,
      <RPut key="s" x={61} y={ys + p + 1.25} cls="dim">
        {`SLOT ${n}`}
      </RPut>,
    );
    if (st === 'refused') {
      wrapMax(safe(card.denial), NAME_W, Math.min(2, nC)).forEach((t, j) =>
        body.push(
          <Put key={`d${j}`} x={18} y={ys + p + 2.25 + j} cls="amb">
            {t}
          </Put>,
        ),
      );
    } else {
      carryLines(itemsOf(card), nC, CARRY_W).forEach((t, j) =>
        body.push(
          <Put
            key={`k${j}`}
            x={18}
            y={ys + p + 2.25 + j}
            cls={st === 'under' ? 'dim' : ''}
          >
            {t}
          </Put>,
        ),
      );
    }
    if (st === 'ready') {
      body.push(
        <Key
          key="l"
          kind="cap"
          x={49}
          y={ys + h - p - 1.5}
          w={12}
          label="[ LOAD ]"
          state={live ? 'idle' : 'dead'}
          onClick={() => onLoad(card)}
        />,
      );
    } else if (st === 'under') {
      body.push(
        <Big
          key="u"
          x={49}
          w={12}
          y={ys + h - p - 1.375}
          scale={1.25}
          align="right"
          cls="dim"
        >
          UNDER WAY
        </Big>,
      );
    }
  }
  return (
    <Slab x={1} y={ys} w={61} h={h} variant="block" dead={dead}>
      <Lift>{well}</Lift>
      {body}
    </Slab>
  );
}

function RowSlot(props: {
  n: number;
  card: SaveCard | null;
  st: SlotState;
  ys: number;
  alt: boolean;
  live: boolean;
  onLoad: (card: SaveCard) => void;
}) {
  const { n, card, st, ys, alt, live, onLoad } = props;
  const dead = st === 'empty' || st === 'blank';
  const body: ReactNode[] = [];
  if (st === 'empty') {
    body.push(
      <Put key="n" x={3} y={ys + 0.125} cls="dim">
        EMPTY
      </Put>,
      <RPut key="s" x={61} y={ys + 0.125} cls="dim">
        {`SLOT ${n}`}
      </RPut>,
    );
  } else if (card) {
    const name = safe(card.name).toUpperCase();
    body.push(
      <Put key="n" x={3} y={ys + 0.125} cls={st === 'ready' ? 'wht' : 'dim'}>
        {cut(name, ROW_W)}
      </Put>,
    );
    if (st === 'refused') {
      body.push(
        <Put key="d" x={3} y={ys + 1.125} cls="amb">
          {cut(safe(card.denial), ROW_DENIAL_W)}
        </Put>,
      );
    } else {
      const items = itemsOf(card);
      const head = classLine(card, name);
      // Whole items only: a figure cut short ("1,85…") would misread.
      const room = ROW_W - head.length - 3;
      const [run, next] = fitItems(items, 0, room - 1);
      const whole = next > 0 && !run.endsWith(CUT);
      const text = whole
        ? `${head} ${SEP} ${run}${next < items.length ? CUT : ''}`
        : head;
      body.push(
        <Put key="c" x={3} y={ys + 1.125} cls="dim">
          {cut(text.trimEnd(), ROW_W)}
        </Put>,
      );
    }
    if (st === 'under') {
      body.push(
        <RPut key="u" x={61} y={ys + 0.125} cls="dim">
          UNDER WAY
        </RPut>,
      );
    } else if (st === 'ready') {
      body.push(
        <Key
          key="l"
          kind="cap"
          x={49}
          y={ys + 0.375}
          w={12}
          label="[ LOAD ]"
          state={live ? 'idle' : 'dead'}
          onClick={() => onLoad(card)}
        />,
      );
    }
  }
  return (
    <Slab x={1} y={ys} w={61} h={2.25} variant="row" alt={alt} dead={dead}>
      {body}
    </Slab>
  );
}
