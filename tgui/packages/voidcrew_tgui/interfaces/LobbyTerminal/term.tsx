/**
 * Text-grid primitives for the dock terminal.
 *
 * Everything on the screen is placed on a cell grid: x is a whole column, y a row in quarter
 * steps. Coordinates are cells of the current Region (the shell wraps each screen in the main
 * region, so a screen's (0, 0) is the main area's top-left cell and useGrid() gives 63 x M).
 *
 * Text is one size on one grid, plus Big at 1.25x or 2.25x. Weight comes from filled shapes
 * under the text: Band, Slab, Key, Box, rules `lw` px thick.
 *
 * Layers: shapes 1, text 2, focus targets 4, open text with onClick 5, fields 6, dialogs 8.
 *
 * Colour classes: '' (fg), 'dim', 'faint' (dead), 'wht' (names), 'acc' (magenta), 'amb',
 * 'red', 'inv' (fg fill, ink text), 'invx' (accent fill), 'inva' (amber fill).
 */
import {
  type CSSProperties,
  createContext,
  type ReactNode,
  type PointerEvent as ReactPointerEvent,
  useCallback,
  useContext,
  useEffect,
  useLayoutEffect,
  useRef,
  useState,
} from 'react';

import type { Mode } from './layout';
import {
  closeDialogFx,
  Flash,
  type SfxName,
  sfx,
  usePulse,
  Wipe,
  type WipeKind,
} from './motion';
import { type FocusOpts, FocusScope, useBack, useFocusable } from './nav';
import type { PartClass, Parts } from './types';

export type Grid = {
  cols: number;
  rows: number;
  /** Cell size in CSS px (cw fractional, ch whole). */
  cw: number;
  ch: number;
  /** Bezel pixel scale. */
  s: number;
  /** Line weight in px: every border and rule. */
  lw: number;
  mode: Mode;
};

export const GridContext = createContext<Grid>({
  cols: 63,
  rows: 30,
  cw: 9.43,
  ch: 19,
  s: 1,
  lw: 2,
  mode: 'side',
});

/** {cols, rows, cw, ch, s, lw, mode} of the current region. */
export const useGrid = () => useContext(GridContext);

/** Main region rows (see the layout rule): the box, the body inside it. */
export const BOX_Y = 2.5;
export const BODY_Y = 3;
export const BODY_X = 1;
export const BODY_W = 61;
/** Body rows for a main region of `rows` rows. */
export const bodyRows = (rows: number) => rows - 4.25;


export type Cls =
  | ''
  | 'dim'
  | 'faint'
  | 'wht'
  | 'acc'
  | 'amb'
  | 'red'
  | 'inv'
  | 'invx'
  | 'inva';

const cx = (cls?: string) => (cls ? cls : undefined);
const px = (v: number) => Math.round(v);

/** Keyboard focus options a clickable item can pass on (see nav.tsx). */
export type NavProps = Pick<
  FocusOpts,
  'auto' | 'edge' | 'tab' | 'mouseOnly' | 'entry'
>;

// ---------------------------------------------------------------------------
// Regions and text
// ---------------------------------------------------------------------------

/** A canvas rect that is its own grid: children see cols = w, rows = h. */
export function Region(props: {
  x: number;
  y: number;
  w: number;
  h: number;
  children?: ReactNode;
}) {
  const { x, y, w, h, children } = props;
  const grid = useGrid();
  return (
    <div
      className="lt-region"
      style={{
        left: px(x * grid.cw),
        top: px(y * grid.ch),
        width: px(w * grid.cw),
        height: px(h * grid.ch),
      }}
    >
      <GridContext.Provider value={{ ...grid, cols: w, rows: h }}>
        {children}
      </GridContext.Provider>
    </div>
  );
}

type PutProps = NavProps & {
  x: number;
  y: number;
  /** Colour class. */
  cls?: Cls | string;
  children: ReactNode;
  onClick?: () => void;
  /** Class while focused or hovered (clickable keys light up). */
  hoverCls?: Cls | string;
  /** Paint the terminal background behind the text (over frame lines). */
  bg?: boolean;
  title?: string;
  /** The text flashes white for 200 ms when this value changes (a count, a figure, a value). */
  pulse?: unknown;
};

/** Text at a cell. With onClick it is focusable: hover or the arrow keys light it. */
export function Put(props: PutProps) {
  const { x, y, cls, children, onClick, hoverCls, bg, title } = props;
  const { cw, ch } = useGrid();
  const focus = useFocusable<HTMLSpanElement>(!!onClick, {
    activate: () => onClick?.(),
    auto: props.auto,
    edge: props.edge,
    tab: props.tab,
    mouseOnly: props.mouseOnly,
  });
  const pulse = usePulse<HTMLSpanElement>(props.pulse);
  const setRef = useCallback((el: HTMLSpanElement | null) => {
    focus.ref.current = el;
    pulse.current = el;
  }, []);
  const style: CSSProperties = {
    left: px(x * cw),
    top: px(y * ch),
  };
  if (bg) {
    style.background = 'var(--lt-bg)';
  }
  if (onClick) {
    style.cursor = 'pointer';
    style.zIndex = 5;
  }
  const shown = focus.focused && hoverCls ? hoverCls : cls;
  return (
    <span
      ref={setRef}
      className={cx(focus.focused ? `${shown || ''} lt-foc` : shown)}
      style={style}
      title={title}
      onClick={
        onClick
          ? (e) => {
              e.stopPropagation();
              onClick();
            }
          : undefined
      }
      onMouseEnter={focus.onMouseEnter}
    >
      {children}
    </span>
  );
}

/** Text ending just before column x (right-aligned). */
export function RPut(props: PutProps & { children: string }) {
  return <Put {...props} x={props.x - props.children.length} />;
}

/**
 * Scaled text, 1.25x or 2.25x. Each character is `scale` columns wide and the line is `scale`
 * rows tall, so a Big at (x, y) covers ceil(len * scale) columns by `scale` rows. With w it is
 * aligned inside w columns.
 */
export function Big(props: {
  x: number;
  y: number;
  scale: 1.25 | 2.25;
  w?: number;
  align?: 'left' | 'center' | 'right';
  cls?: Cls | string;
  /** The text flashes white for 200 ms when this value changes. */
  pulse?: unknown;
  children: string;
}) {
  const { x, y, scale, w, align = 'left', cls, children } = props;
  const { cw, ch } = useGrid();
  const pulse = usePulse<HTMLSpanElement>(props.pulse);
  const k = align === 'center' ? 0.5 : align === 'right' ? 1 : 0;
  const left = w === undefined ? x : x + (w - children.length * scale) * k;
  return (
    <span
      ref={pulse}
      className={cls ? `lt-big ${cls}` : 'lt-big'}
      style={{
        left: px(left * cw),
        top: px(y * ch),
        fontSize: `${scale}em`,
        lineHeight: `${px(scale * ch)}px`,
      }}
    >
      {children}
    </span>
  );
}

/**
 * A name in a 1.25-row band: 1.25x when it fits w columns, else normal size centred in the
 * band, else normal size cut with the cut mark. White with the name glow unless cls says.
 */
export function NameLine(props: {
  x: number;
  y: number;
  w: number;
  text: string;
  cls?: Cls | string;
}) {
  const { x, y, w, text, cls = 'wht lt-name' } = props;
  if (text.length * 1.25 <= w) {
    return (
      <Big x={x} y={y} scale={1.25} cls={cls}>
        {text}
      </Big>
    );
  }
  return (
    <Put x={x} y={y + 0.125} cls={cls}>
      {cut(text, w)}
    </Put>
  );
}

// ---------------------------------------------------------------------------
// Shapes
// ---------------------------------------------------------------------------

export type BandTone =
  | 'bar'
  | 'accent'
  | 'fg'
  | 'panel'
  | 'field'
  | 'warn'
  | 'bad'
  | 'bg';

/** A filled rect under text. */
export function Band(props: {
  x: number;
  y: number;
  w: number;
  h: number;
  tone: BandTone;
  /** An animation class (motion.ts), e.g. the notice band drawing left to right. */
  fx?: string;
  /** Drawn at half strength (a dead field). */
  dead?: boolean;
}) {
  const { x, y, w, h, tone, fx, dead } = props;
  const { cw, ch, lw } = useGrid();
  const style: CSSProperties = {
    left: px(x * cw),
    top: px(y * ch),
    width: px((x + w) * cw) - px(x * cw),
    height: px((y + h) * ch) - px(y * ch),
  };
  if (tone === 'warn') {
    style.borderLeftWidth = 3 * lw;
  }
  return (
    <div
      className={`lt-band lt-band-${tone}${fx ? ` ${fx}` : ''}${dead ? ' is-dead' : ''}`}
      style={style}
    />
  );
}

/** A rect in px snapped so neighbours meet without gaps. */
function rect(
  x: number,
  y: number,
  w: number,
  h: number,
  cw: number,
  ch: number,
) {
  const l = px(x * cw);
  const t = px(y * ch);
  return {
    left: l,
    top: t,
    width: px((x + w) * cw) - l,
    height: px((y + h) * ch) - t,
  };
}

/** The px rect of cells (x, y, w, h) in the current region. */
export function useCellRect(x: number, y: number, w: number, h: number) {
  const { cw, ch } = useGrid();
  return rect(x, y, w, h, cw, ch);
}

/**
 * The inside of the main box, in px: what a screen change covers. From the body's first row
 * (so the caption on the top border stays whole) to the box's bottom and side borders.
 */
export function useBoxInside() {
  const { cw, ch, lw, rows } = useGrid();
  const box = rect(0, BODY_Y, 63, rows - 1 - BODY_Y, cw, ch);
  return {
    left: box.left + lw,
    top: box.top,
    width: Math.max(0, box.width - 2 * lw),
    height: Math.max(0, box.height - lw),
  };
}

/**
 * A cover over cells (x, y, w, h) that plays when `k` changes (motion.ts Wipe): a page of a
 * list turning ('page', the default here), a screen or column opening ('screen'), a line of
 * text being drawn ('draw').
 */
export function WipeAt(props: {
  x: number;
  y: number;
  w: number;
  h: number;
  k: unknown;
  n?: number;
  kind?: WipeKind;
  dir?: 'down' | 'up';
  quiet?: boolean;
  first?: boolean;
  z?: number;
}) {
  const { x, y, w, h, kind = 'page', ...rest } = props;
  const style = useCellRect(x, y, Math.max(0, w), Math.max(0, h));
  return <Wipe {...rest} kind={kind} style={style} />;
}

/**
 * A white bar over cells (x, y, w, h) for 200 ms when `k` changes: the row that changed.
 * `bar`: only the slab's heavy left bar, 3 lw wide.
 */
export function FlashAt(props: {
  x: number;
  y: number;
  w: number;
  h: number;
  k: unknown;
  bar?: boolean;
  z?: number;
}) {
  const { x, y, w, h, k, bar, z } = props;
  const { lw } = useGrid();
  const style = useCellRect(x, y, w, h);
  if (bar) {
    style.width = 3 * lw;
  }
  return <Flash k={k} z={z} style={style} />;
}

/**
 * The list panel. 'block': an lw border with a 3 * lw left bar. 'row': the left bar only
 * (alt = the alternate fill). With onClick it is a focus target and draws its focused look.
 * Children use region coordinates as usual and draw over it.
 */
export function Slab(
  props: NavProps & {
    x: number;
    y: number;
    w: number;
    h: number;
    variant: 'block' | 'row';
    alt?: boolean;
    dead?: boolean;
    /** Yours or open: accent bar, first text line white (the caller draws the text). */
    on?: boolean;
    /** Dead colours, but still focusable and pressable. */
    muted?: boolean;
    onClick?: () => void;
    /** Told when the slab gains or loses the focus (mouse or keys). */
    onFocus?: (on: boolean) => void;
    children?: ReactNode;
  },
) {
  const { x, y, w, h, variant, alt, dead, on, muted, onClick, onFocus } = props;
  const { children } = props;
  const { cw, ch, lw } = useGrid();
  const live = !!onClick && !dead;
  const focus = useFocusable<HTMLDivElement>(live, {
    activate: () => onClick?.(),
    auto: props.auto,
    edge: props.edge,
    entry: props.entry,
  });
  const was = useRef(false);
  useEffect(() => {
    if (was.current !== focus.focused) {
      was.current = focus.focused;
      onFocus?.(focus.focused);
    }
  }, [focus.focused]);
  const box = rect(x, y, w, h, cw, ch);
  const cls = [
    'lt-slab',
    `lt-slab-${variant}`,
    alt ? 'is-alt' : '',
    dead || muted ? 'is-dead' : '',
    on ? 'is-on' : '',
    focus.focused ? 'is-foc' : '',
  ]
    .filter(Boolean)
    .join(' ');
  const style: CSSProperties = {
    ...box,
    // A focused muted row gains a whole border: its dead fill alone hides where the focus is.
    borderWidth: variant === 'block' || (muted && focus.focused) ? lw : 0,
    borderLeftWidth: 3 * lw,
  };
  return (
    <>
      <div className={cls} style={style} />
      {children}
      {!!live && (
        <div
          ref={focus.ref}
          className="lt-hit"
          style={box}
          onClick={(e) => {
            e.stopPropagation();
            onClick?.();
          }}
          onMouseEnter={focus.onMouseEnter}
        />
      )}
    </>
  );
}

export type KeyKind = 'box' | 'big' | 'plain' | 'cap';
export type KeyState = 'idle' | 'lit' | 'on' | 'dead';

/**
 * A key on the grid. 'box': bordered, label one column in. 'big': the same with a bright border
 * and white label, 2 rows. 'plain': no border, 1 row, dim label. 'cap': filled with a left
 * border, label centred (pass the brackets: '[ SIGN ON ]'). `right` is right-aligned one
 * column in.
 */
export function Key(
  props: NavProps & {
    x: number;
    y: number;
    w: number;
    h?: number;
    label: string;
    /** Colour class of the label at rest (focus, lit and on states override it). */
    labelCls?: Cls | string;
    right?: string;
    rightCls?: Cls | string;
    kind: KeyKind;
    state?: KeyState;
    onClick: () => void;
    /** Told when the key gains or loses the focus (mouse or keys). */
    onFocus?: (on: boolean) => void;
    /** A layout zone for the keyboard rules (nav.tsx FocusOpts.zone). */
    zone?: string;
    title?: string;
    /** Pressed and waiting on its answer: the label blinks at the STAND BY cadence. */
    busy?: boolean;
    /** The accent fill sweeping in under the label ('on') or retracting ('off'). */
    sweep?: 'on' | 'off' | null;
    /** The right text flashes inverse amber for 240 ms when this value changes. */
    rightPulse?: unknown;
  },
) {
  const { x, y, w, label, labelCls, right, rightCls, kind, onClick, zone } =
    props;
  const { title, busy, sweep } = props;
  const state = props.state || 'idle';
  const h = props.h ?? (kind === 'big' ? 2 : kind === 'plain' ? 1 : 1.5);
  const { cw, ch, lw } = useGrid();
  const dead = state === 'dead';
  const rightRef = usePulse<HTMLSpanElement>(props.rightPulse, 'inva');
  // The white flash and the sound of a press are the focus system's (nav.tsx), for every item.
  const press = onClick;
  const focus = useFocusable<HTMLDivElement>(!dead, {
    activate: press,
    auto: props.auto,
    edge: props.edge,
    tab: props.tab,
    mouseOnly: props.mouseOnly,
    zone,
  });
  const was = useRef(false);
  useEffect(() => {
    if (was.current !== focus.focused) {
      was.current = focus.focused;
      props.onFocus?.(focus.focused);
    }
  }, [focus.focused]);
  const box = rect(x, y, w, h, cw, ch);
  // Border widths, so the label sits on the grid inside the padding box.
  const bl = kind === 'plain' ? 0 : lw;
  const bt = kind === 'box' || kind === 'big' ? lw : 0;
  const ty = ((h - 1) / 2) * ch - bt;
  // A cap centres its label to the half cell in the room right of its border, so an odd margin
  // never puts the opening bracket on the border.
  const lx =
    kind === 'cap'
      ? bl + Math.max(0, (w * cw - bl - label.length * cw) / 2)
      : cw;
  const cls = [
    'lt-k',
    `lt-k-${kind}`,
    `is-${state}`,
    focus.focused ? 'is-foc' : '',
    busy ? 'is-busy' : '',
  ]
    .filter(Boolean)
    .join(' ');
  return (
    <div
      ref={focus.ref}
      className={cls}
      data-zone={zone}
      title={title}
      style={{ ...box, borderWidth: bt, borderLeftWidth: bl }}
      onClick={
        dead
          ? undefined
          : (e) => {
              e.stopPropagation();
              press();
            }
      }
      onMouseEnter={focus.onMouseEnter}
    >
      {!!sweep && <i key={sweep} className={`lt-fill is-${sweep}`} />}
      <span
        className={cx(state === 'dead' ? undefined : labelCls)}
        style={{ left: px(lx - bl), top: px(ty) }}
      >
        {label}
      </span>
      {!!right && (
        <span
          ref={rightRef}
          className={cx(rightCls)}
          style={{
            left: px((w - 1 - right.length) * cw - bl),
            top: px(ty),
          }}
        >
          {right}
        </span>
      )}
    </div>
  );
}

type BtnProps = NavProps & {
  x: number;
  y: number;
  label: string;
  /** Right-align: the button ends just before column x. */
  right?: boolean;
  /** Lit (inverse) at rest. */
  lit?: boolean;
  /** Old amber variant; kept for screens not yet redesigned. */
  amber?: boolean;
  disabled?: boolean;
  onClick?: () => void;
};

/** A `[ LABEL ]` key drawn as text. Disabled keys draw faint and ignore clicks. */
export function Btn(props: BtnProps) {
  const { x, y, label, right, lit, amber, disabled, onClick, auto, edge } =
    props;
  const text = `[ ${label} ]`;
  const at = right ? x - text.length : x;
  if (disabled) {
    return (
      <Put x={at} y={y} cls="faint">
        {text}
      </Put>
    );
  }
  const rest = lit ? (amber ? 'inva' : 'inv') : amber ? 'amb' : 'wht';
  const hover = amber ? 'inva' : 'inv';
  return (
    <Put
      x={at}
      y={y}
      cls={rest}
      hoverCls={hover}
      onClick={onClick}
      auto={auto}
      edge={edge}
    >
      {text}
    </Put>
  );
}

export type BoxTone = 'box' | 'menu' | 'bg';

/**
 * A single-line border lw px on the outer edge of the cell rect, filled by tone. Caption
 * ` TEXT ` at column x + 2 on the top border. Content: columns x + 1 to x + w - 2, rows
 * y + 0.5 to y + h - 0.25.
 */
export function Box(props: {
  x: number;
  y: number;
  w: number;
  h: number;
  caption?: string;
  tone?: BoxTone;
  /** Bright border (dialogs). */
  bright?: boolean;
  children?: ReactNode;
}) {
  const { x, y, w, h, caption, tone = 'box', bright, children } = props;
  const { cw, ch, lw } = useGrid();
  return (
    <>
      <div
        className={`lt-boxs lt-boxs-${tone}${bright ? ' is-bright' : ''}`}
        style={{ ...rect(x, y, w, h, cw, ch), borderWidth: lw }}
      />
      {!!caption && (
        <Put x={x + 2} y={y - 0.5} cls="wht" bg>
          {` ${cut(caption, Math.max(1, w - 6))} `}
        </Put>
      )}
      {children}
    </>
  );
}

/**
 * A modal box centred in the main region, opaque and above everything in it, inside a
 * FocusScope. Clicks never reach what is under it.
 */
export function Dialog(props: {
  w: number;
  h: number;
  caption?: string;
  /**
   * The sound it opens with; the wipe by default. It always wipes in. `null`: silent, and its
   * closing is left to the screen that follows (the CONFIRMED box).
   */
  sound?: SfxName | null;
  children?: ReactNode;
}) {
  const { w, h, caption, children } = props;
  const sound = props.sound === undefined ? 'wipe' : props.sound;
  const { cols, cw, ch, lw } = useGrid();
  const x = Math.floor((cols - w) / 2);
  const y = BODY_Y + 2;
  const box = rect(x, y, w, h, cw, ch);
  // What the wipe covers: inside the border, from the first content row (the caption stays whole).
  const head = px(0.5 * ch);
  const inside = {
    left: box.left + lw,
    top: box.top + head,
    width: Math.max(0, box.width - 2 * lw),
    height: Math.max(0, box.height - head - lw),
  };
  const last = useRef({ inside, sound });
  last.current = { inside, sound };
  // A layout effect, so the closing cover is up in the very frame the box goes.
  useLayoutEffect(() => {
    if (sound) {
      sfx(sound);
    }
    // Closing: the wipe runs back over where the box was (unless the next screen has its own).
    return () => {
      if (last.current.sound !== null) {
        closeDialogFx(last.current.inside);
      }
    };
  }, []);
  return (
    <div className="lt-dialog">
      <div
        className="lt-dialog-block"
        style={box}
        onClick={(e) => e.stopPropagation()}
      />
      <Box x={x} y={y} w={w} h={h} caption={caption} tone="bg" bright />
      <FocusScope>{children}</FocusScope>
      <Wipe k={0} first quiet z={9} style={inside} />
    </div>
  );
}

/** A line lw px thick, centred on row y, columns x to x + w - 1. */
export function HRule(props: { x: number; y: number; w: number }) {
  const { x, y, w } = props;
  const { cw, ch, lw } = useGrid();
  return (
    <div
      className="lt-rule"
      style={{
        left: px(x * cw),
        top: px(y * ch - lw / 2),
        width: px((x + w) * cw) - px(x * cw),
        height: lw,
      }}
    />
  );
}

/** A line lw px thick down the middle of column x, rows y to y + h. */
export function VRule(props: { x: number; y: number; h: number }) {
  const { x, y, h } = props;
  const { cw, ch, lw } = useGrid();
  return (
    <div
      className="lt-rule"
      style={{
        left: px((x + 0.5) * cw - lw / 2),
        top: px(y * ch),
        width: lw,
        height: px((y + h) * ch) - px(y * ch),
      }}
    />
  );
}

/**
 * Compatibility for screens not yet redesigned: a rule through the middle of row y, as the
 * old Rule drew it. New work uses HRule, which centres on y itself.
 */
export function Rule(props: { x: number; y: number; w: number }) {
  return <HRule {...props} y={props.y + 0.5} />;
}

type FieldProps = Pick<NavProps, 'auto'> & {
  x: number;
  y: number;
  w: number;
  /** Rows; 1.5 by default. */
  h?: number;
  value: string;
  max: number;
  disabled?: boolean;
  /** Mask the text (codes). */
  secret?: boolean;
  /** The text flashes white for 200 ms when this value changes (a value set from outside). */
  pulse?: unknown;
  /** Text at 1.25x, matching Big values beside it. */
  big?: boolean;
  /** A word shown faint while the field is empty (in place of the dots). */
  hint?: string;
  onChange: (value: string) => void;
  onEnter: () => void;
};

/** The text input over a field. */
function FieldInput(
  props: FieldProps & {
    left: number;
    top: number;
    width: number;
    height: number;
    cls: string;
    /** Inner padding left and right, px. */
    pad?: number;
    /** Columns the text has inside the padding. */
    cells: number;
  },
) {
  const { value, max, disabled, secret, onChange, onEnter } = props;
  // Text longer than the field shrinks to fit it (down to 0.7x), so a long name stays whole.
  const size = props.big ? 1.25 : 1;
  const fit = Math.max(
    0.7,
    Math.min(size, (props.cells - 0.5) / Math.max(1, value.length)),
  );
  const input = useRef<HTMLInputElement | null>(null);
  const focus = useFocusable<HTMLInputElement>(!disabled, {
    activate: () => input.current?.focus(),
    auto: props.auto,
    input,
  });
  const pulse = usePulse<HTMLInputElement>(props.pulse);
  return (
    <input
      ref={(el) => {
        input.current = el;
        focus.ref.current = el;
        pulse.current = el;
      }}
      className={`${props.cls}${focus.focused ? ' lt-fieldfoc' : ''}`}
      onMouseEnter={focus.onMouseEnter}
      onFocus={focus.take}
      type={secret ? 'password' : 'text'}
      value={value}
      maxLength={max}
      disabled={disabled}
      spellCheck={false}
      autoComplete="off"
      onChange={(e) => {
        sfx('type');
        onChange(e.target.value);
      }}
      onKeyDown={(e) => {
        if (e.key === 'Enter') {
          e.preventDefault();
          onEnter();
        }
      }}
      style={{
        left: props.left,
        top: props.top,
        width: props.width,
        height: props.height,
        lineHeight: `${props.height}px`,
        ...(props.pad
          ? {
              paddingLeft: props.pad,
              paddingRight: props.pad,
              boxSizing: 'border-box' as const,
            }
          : {}),
        ...(fit !== 1 ? { fontSize: `${fit}em` } : {}),
      }}
    />
  );
}

/**
 * A filled band with a text input over it, text one column in. Empty and unfocused it shows
 * dim dots. Enter submits. tgui-core's key passthrough ignores keys typed into an input, so
 * typing here never reaches the player's BYOND hotkeys.
 */
export function Field(props: FieldProps) {
  const { x, y, w, value, disabled } = props;
  const h = props.h ?? 1.5;
  const { cw, ch } = useGrid();
  const box = rect(x, y, w, h, cw, ch);
  return (
    <>
      <Band x={x} y={y} w={w} h={h} tone="field" dead={disabled} />
      {!value && !disabled && (
        <Put x={x + 1} y={y + (h - 1) / 2} cls={props.hint ? 'faint' : 'dim'}>
          {props.hint
            ? props.hint.slice(0, Math.max(0, w - 2))
            : '.'.repeat(Math.max(0, w - 2))}
        </Put>
      )}
      {/* The input covers the band, its text one cell in from both ends, so the focus ring
          frames the band and typed text never runs onto it. */}
      <FieldInput
        {...props}
        cls={`lt-field${disabled ? ' is-dead' : ''}`}
        left={box.left}
        top={box.top}
        width={box.width}
        height={box.height}
        pad={px(cw)}
        cells={w - 2}
      />
    </>
  );
}

/**
 * `< 2/3 >`: one focus stop. Left and Right page while it is focused, Enter pages forward
 * (wrapping). `<` and `>` are their own mouse targets and draw faint at the ends. Not drawn
 * when pages <= 1. `right`: the control ends just before column x.
 */
export function Pager(props: {
  x: number;
  y: number;
  /** 1-based. */
  page: number;
  pages: number;
  onPage: (page: number) => void;
  right?: boolean;
}) {
  const { y, page, pages, onPage, right } = props;
  const { cw, ch } = useGrid();
  const live = pages > 1;
  const go = (to: number) => {
    if (to >= 1 && to <= pages && to !== page) {
      onPage(to);
    }
  };
  const focus = useFocusable<HTMLSpanElement>(live, {
    activate: () => onPage(page >= pages ? 1 : page + 1),
    edge: {
      left: () => {
        go(page - 1);
        return true;
      },
      right: () => {
        go(page + 1);
        return true;
      },
    },
  });
  if (!live) {
    return null;
  }
  const mid = ` ${Math.min(99, page)}/${Math.min(99, pages)} `;
  const text = `<${mid}>`;
  const x = right ? props.x - text.length : props.x;
  const ends = (on: boolean) => (focus.focused ? undefined : on ? '' : 'faint');
  return (
    <span
      ref={focus.ref}
      className={focus.focused ? 'inv lt-pager' : 'lt-pager'}
      style={{ left: px(x * cw), top: px(y * ch) }}
      onMouseEnter={focus.onMouseEnter}
    >
      <span
        className={cx(`lt-in ${ends(page > 1) ?? ''}`.trim())}
        onClick={(e) => {
          e.stopPropagation();
          go(page - 1);
        }}
      >
        {'<'}
      </span>
      <span className="lt-in">{mid}</span>
      <span
        className={cx(`lt-in ${ends(page < pages) ?? ''}`.trim())}
        onClick={(e) => {
          e.stopPropagation();
          go(page + 1);
        }}
      >
        {'>'}
      </span>
    </span>
  );
}

/**
 * The recessed picture screen, sized in cells with square corners. Children are drawn inside it
 * in px from its top-left corner (ShipPic, PlanPic). `note`: a dim line centred in an empty
 * well. Never focusable.
 */
export function Well(props: {
  x: number;
  y: number;
  w: number;
  h: number;
  note?: string;
  children?: ReactNode;
}) {
  const { x, y, w, h, note, children } = props;
  const { cw, ch } = useGrid();
  const box = rect(x, y, w, h, cw, ch);
  const text = note ? cut(note, Math.max(1, w - 2)) : '';
  return (
    <div className="lt-vscreen lt-well" style={box}>
      {children}
      {!!text && (
        <span
          className="dim"
          style={{
            left: px(Math.floor((w - text.length) / 2) * cw),
            top: px(Math.floor((h - 1) / 2) * ch),
          }}
        >
          {text}
        </span>
      )}
      <div className="lt-vscan" />
    </div>
  );
}

/** The part classes, always in this order. */
export const PART_CLASSES: PartClass[] = ['combat', 'science', 'trade', 'misc'];

/**
 * Class columns: the column each class's head and figure end on. R: the home and every row of
 * the bill. F: the fit's total strip.
 */
export const CLASS_EDGES: Record<'R' | 'F', number[]> = {
  R: [35, 44, 52, 60],
  F: [13, 22, 29, 36],
};

/** A parts figure: a whole number, `9999+` above 9999, nothing for zero. */
export function fig(n: number | null | undefined): string {
  const v = Math.max(0, Math.floor(n || 0));
  if (!v) {
    return '';
  }
  return v > 9999 ? '9999+' : String(v);
}

/** The four class heads, dim, right-aligned to the columns of the set. */
export function ClassHeads(props: { y: number; set: 'R' | 'F' }) {
  const { y, set } = props;
  return (
    <>
      {PART_CLASSES.map((k, i) => (
        <RPut key={k} x={CLASS_EDGES[set][i] + 1} y={y} cls="dim">
          {k.toUpperCase()}
        </RPut>
      ))}
    </>
  );
}

/**
 * The four figures of a set, right-aligned under ClassHeads. Zero draws nothing (unless
 * `zero`). `cls`: one colour class, or one per class. `big`: Big 1.25, one row band tall.
 * With `pulse` a figure flashes when it changes, also when it appears or goes (its place is
 * kept, empty, while it is zero).
 */
export function ClassFigures(props: {
  y: number;
  set: 'R' | 'F';
  values: Parts | null | undefined;
  cls?: Cls | string | Partial<Record<PartClass, Cls | string>>;
  big?: boolean;
  zero?: boolean;
  /** Each figure flashes white for 200 ms when it changes (a total, the account). */
  pulse?: boolean;
}) {
  const { y, set, values, cls, big, zero, pulse } = props;
  return (
    <>
      {PART_CLASSES.map((k, i) => {
        const text = fig(values?.[k]) || (zero ? '0' : '');
        if (!text && !pulse) {
          return null;
        }
        const c = typeof cls === 'object' ? cls[k] : cls;
        const edge = CLASS_EDGES[set][i] + 1;
        if (big) {
          return (
            <Big
              key={k}
              x={edge - 8}
              w={8}
              y={y}
              scale={1.25}
              align="right"
              cls={c}
              pulse={pulse ? text : undefined}
            >
              {text}
            </Big>
          );
        }
        return (
          <RPut key={k} x={edge} y={y} cls={c} pulse={pulse ? text : undefined}>
            {text}
          </RPut>
        );
      })}
    </>
  );
}

// ---------------------------------------------------------------------------
// Kept for screens not yet redesigned
// ---------------------------------------------------------------------------

/** n filled cells (block characters drawn as boxes on the grid). frac = height share of a row. */
export function Blocks(props: {
  x: number;
  y: number;
  n: number;
  cls?: '' | 'dim' | 'faint' | 'ablk' | 'rblk';
  frac?: number;
}) {
  const { x, y, n, cls, frac = 0.7 } = props;
  const { cw, ch } = useGrid();
  return (
    <div
      className={cls ? `lt-blk ${cls}` : 'lt-blk'}
      style={{
        left: x * cw,
        top: y * ch + (ch * (1 - frac)) / 2,
        width: n * cw - 2,
        height: ch * frac,
      }}
    />
  );
}

/** Invisible click target over a block of cells (whole list rows). */
export function Hit(
  props: NavProps & {
    x: number;
    y: number;
    w: number;
    h: number;
    onClick: () => void;
    /** Told when the row gains or loses the focus (mouse or keys). */
    onHover?: (over: boolean) => void;
  },
) {
  const { x, y, w, h, onClick, onHover } = props;
  const { cw, ch } = useGrid();
  const focus = useFocusable<HTMLDivElement>(true, {
    activate: onClick,
    auto: props.auto,
    edge: props.edge,
    tab: props.tab,
    entry: props.entry,
  });
  const was = useRef(false);
  useEffect(() => {
    if (was.current !== focus.focused) {
      was.current = focus.focused;
      onHover?.(focus.focused);
    }
  }, [focus.focused]);
  return (
    <div
      ref={focus.ref}
      className={focus.focused ? 'lt-hit lt-hitfoc' : 'lt-hit'}
      style={{
        left: x * cw,
        top: y * ch,
        width: w * cw,
        height: h * ch,
      }}
      onClick={onClick}
      onMouseEnter={focus.onMouseEnter}
    />
  );
}

/**
 * A colour chip: a filled rect w cells (default 2) by h rows (default 1), inset 2 px, with an
 * lw border in --lt-edge; selected or focused it is --lt-fg. hex must be a CSS colour; the
 * server sanitises every stored colour.
 */
export function Swatch(
  props: Pick<NavProps, 'auto' | 'mouseOnly'> & {
    x: number;
    y: number;
    hex: string;
    sel?: boolean;
    /** Width in cells. */
    w?: number;
    /** Height in rows. */
    h?: number;
    onClick?: () => void;
  },
) {
  const { x, y, hex, sel, w = 2, h = 1, onClick } = props;
  const { cw, ch, lw } = useGrid();
  const focus = useFocusable<HTMLDivElement>(!!onClick, {
    activate: () => onClick?.(),
    auto: props.auto,
    mouseOnly: props.mouseOnly,
  });
  const lit = sel || focus.focused;
  const box = rect(x, y, w, h, cw, ch);
  return (
    <div
      ref={focus.ref}
      className={`lt-swatch${lit ? ' is-lit' : ''}${focus.focused ? ' is-foc' : ''}`}
      onMouseEnter={focus.onMouseEnter}
      style={{
        left: box.left + 2,
        top: box.top + 2,
        width: Math.max(0, box.width - 4),
        height: Math.max(0, box.height - 4),
        background: hex,
        borderWidth: lw,
        cursor: onClick ? 'pointer' : undefined,
      }}
      onClick={
        onClick
          ? (e) => {
              e.stopPropagation();
              onClick();
            }
          : undefined
      }
    />
  );
}

/**
 * A drawn checkbox at x, y, two cells wide: an empty frame, or the frame with a filled centre.
 * Not a focus stop and not a click target: the row it sits in is.
 */
export function Check(props: {
  x: number;
  y: number;
  on: boolean;
  /** The accent colour when on (packed, taken), else white. */
  acc?: boolean;
}) {
  const { x, y, on, acc } = props;
  const { cw, ch, lw } = useGrid();
  const side = Math.max(8, Math.round(Math.min(2 * cw, ch) * 0.86));
  const gap = Math.max(1, Math.round(side * 0.18));
  return (
    <div
      className={`lt-check${on ? ' is-on' : ''}${acc ? ' is-acc' : ''}`}
      style={{
        left: Math.round(x * cw),
        top: Math.round(y * ch + (ch - side) / 2),
        width: side,
        height: side,
        borderWidth: Math.max(1, lw),
      }}
    >
      {!!on && <i style={{ inset: gap }} />}
    </div>
  );
}

/**
 * A slider's track in a row, w cells wide, with its fill and thumb at value (0 to 1). Mouse
 * only: dragging or clicking calls onChange, letting go calls onRelease. Not a focus stop: the
 * row steps the value with Left and Right.
 */
export function Slide(props: {
  x: number;
  y: number;
  w: number;
  value: number;
  /** The row has the focus: the fill brightens. */
  lit?: boolean;
  onChange: (value: number) => void;
  onRelease: (value: number) => void;
}) {
  const { x, y, w, value, lit, onChange, onRelease } = props;
  const { cw, ch, lw } = useGrid();
  const last = useRef(value);
  const clamp = (v: number) => Math.max(0, Math.min(1, v));
  const box = rect(x, y, w, 1, cw, ch);
  const th = Math.max(3, Math.round(ch * 0.3));
  const knobH = Math.max(th + 4, Math.round(ch * 0.7));
  const knobW = Math.max(3, lw * 2);
  const at = (e: ReactPointerEvent<HTMLDivElement>) => {
    const r = e.currentTarget.getBoundingClientRect();
    const v = clamp((e.clientX - r.left) / Math.max(1, r.width));
    last.current = v;
    onChange(v);
  };
  const shown = `${(clamp(value) * 100).toFixed(2)}%`;
  return (
    <div
      className={lit ? 'lt-slide is-lit' : 'lt-slide'}
      style={box}
      onPointerDown={(e) => {
        e.stopPropagation();
        e.currentTarget.setPointerCapture(e.pointerId);
        at(e);
      }}
      onPointerMove={(e) => {
        if (e.currentTarget.hasPointerCapture(e.pointerId)) {
          at(e);
        }
      }}
      onPointerUp={(e) => {
        if (e.currentTarget.hasPointerCapture(e.pointerId)) {
          e.currentTarget.releasePointerCapture(e.pointerId);
          onRelease(last.current);
        }
      }}
      onClick={(e) => e.stopPropagation()}
    >
      <div
        className="lt-slide-track"
        style={{
          top: Math.round((box.height - th) / 2),
          height: th,
          borderWidth: Math.max(1, Math.floor(lw / 2)),
        }}
      >
        <div className="lt-slide-fill" style={{ width: shown }} />
      </div>
      <div
        className="lt-slide-thumb"
        style={{
          left: `calc(${shown} - ${knobW / 2}px)`,
          top: Math.round((box.height - knobH) / 2),
          width: knobW,
          height: knobH,
        }}
      />
    </div>
  );
}

/**
 * A filled strip w cells wide with an lw-wide fg thumb at value (0 to 1). Dragging calls
 * onChange; letting go calls onRelease. One focus stop: Enter grabs it, Left and Right then
 * move it one step, Enter or Escape lets go (and calls onRelease).
 */
export function Bar(props: {
  x: number;
  y: number;
  w: number;
  h: number;
  value: number;
  /** CSS background for the strip. */
  gradient: string;
  /** Keyboard step, as a share of the strip. */
  step?: number;
  /** First-focus claim (see nav.tsx). */
  auto?: number;
  onChange: (value: number) => void;
  onRelease: (value: number) => void;
}) {
  const { x, y, w, h, value, gradient, onChange, onRelease } = props;
  const step = props.step ?? 1 / 32;
  const { cw, ch, lw } = useGrid();
  const [grabbed, setGrabbed] = useState(false);
  const last = useRef(value);
  last.current = value;
  const clamp = (v: number) => Math.max(0, Math.min(1, v));
  const letGo = () => {
    setGrabbed(false);
    onRelease(last.current);
  };
  const nudge = (by: number) => {
    const v = clamp(last.current + by);
    last.current = v;
    onChange(v);
    return true;
  };
  const focus = useFocusable<HTMLDivElement>(true, {
    activate: () => (grabbed ? letGo() : setGrabbed(true)),
    auto: props.auto,
    edge: grabbed
      ? {
          left: () => nudge(-step),
          right: () => nudge(step),
          up: () => true,
          down: () => true,
        }
      : undefined,
  });
  useBack(grabbed ? letGo : null);
  useEffect(() => {
    if (grabbed && !focus.focused) {
      letGo();
    }
  }, [focus.focused]);
  const box = rect(x, y, w, h, cw, ch);
  const at = (e: ReactPointerEvent<HTMLDivElement>) => {
    const r = e.currentTarget.getBoundingClientRect();
    const v = clamp((e.clientX - r.left) / Math.max(1, r.width));
    last.current = v;
    onChange(v);
  };
  return (
    <div
      ref={focus.ref}
      className={`lt-bar${focus.focused ? ' is-foc' : ''}${grabbed ? ' is-grab' : ''}`}
      onMouseEnter={focus.onMouseEnter}
      style={{ ...box, borderWidth: lw, background: gradient }}
      onPointerDown={(e) => {
        e.stopPropagation();
        e.currentTarget.setPointerCapture(e.pointerId);
        at(e);
      }}
      onPointerMove={(e) => {
        if (e.currentTarget.hasPointerCapture(e.pointerId)) {
          at(e);
        }
      }}
      onPointerUp={(e) => {
        if (e.currentTarget.hasPointerCapture(e.pointerId)) {
          e.currentTarget.releasePointerCapture(e.pointerId);
          onRelease(last.current);
        }
      }}
      onClick={(e) => e.stopPropagation()}
    >
      <div
        className="lt-bar-thumb"
        style={{
          left: `calc(${(clamp(value) * 100).toFixed(2)}% - ${lw / 2}px)`,
          width: lw,
        }}
      />
    </div>
  );
}

/**
 * `< VALUE >` stepper: `<` at x, the value in w cells from x + 2, `>` at x + 3 + w. The whole
 * control is w + 4 cells wide. onValue makes the value itself clickable (long lists open a
 * picker there).
 */
export function Cycler(props: {
  x: number;
  y: number;
  /** Cells for the value. */
  w: number;
  value: string;
  onPrev: () => void;
  onNext: () => void;
  onValue?: () => void;
  disabled?: boolean;
}) {
  const { x, y, w, value, onPrev, onNext, onValue, disabled } = props;
  const text = pad(value.toUpperCase(), w);
  // The value takes the focus; Left and Right step it, Enter opens the picker (or steps on).
  const step = {
    left: () => {
      onPrev();
      return true;
    },
    right: () => {
      onNext();
      return true;
    },
  };
  if (disabled) {
    return (
      <Put x={x} y={y} cls="faint">
        {`< ${text} >`}
      </Put>
    );
  }
  return (
    <>
      <Put x={x} y={y} cls="dim" hoverCls="inv" onClick={onPrev} mouseOnly>
        {'<'}
      </Put>
      <Put
        x={x + 2}
        y={y}
        hoverCls="inv"
        onClick={onValue || onNext}
        edge={step}
      >
        {text}
      </Put>
      <Put
        x={x + 3 + w}
        y={y}
        cls="dim"
        hoverCls="inv"
        onClick={onNext}
        mouseOnly
      >
        {'>'}
      </Put>
    </>
  );
}

// ---------------------------------------------------------------------------
// Text helpers
// ---------------------------------------------------------------------------

/** The cut mark: one cell, never mistaken for a full stop. */
export const CUT = '…';
/** The separator dot (the font has no middle dot). */
export const SEP = '•';

/** Pads or cuts to n characters; a cut ends in the cut mark. */
export function pad(str: string | number, n: number): string {
  const s = String(str);
  if (n <= 0) {
    return '';
  }
  return s.length > n
    ? `${s.slice(0, n - 1)}${CUT}`
    : s + ' '.repeat(n - s.length);
}

/** Cuts to n characters without padding; a cut ends in the cut mark. */
export function cut(str: string, n: number): string {
  if (n <= 0) {
    return '';
  }
  // A cut never leaves a gap before the mark.
  return str.length > n
    ? `${str.slice(0, Math.max(0, n - 1)).trimEnd()}${CUT}`
    : str;
}

/**
 * Wraps to at most n lines. When lines are dropped the last shown line always ends in the cut
 * mark (replacing its last character when the line is full).
 */
export function wrapMax(text: string, w: number, n: number): string[] {
  const lines = wrap(text, w);
  if (lines.length <= n) {
    return lines;
  }
  const out = lines.slice(0, Math.max(0, n));
  if (out.length) {
    const last = out[out.length - 1];
    out[out.length - 1] =
      last.length >= w
        ? `${last.slice(0, w - 1).trimEnd()}${CUT}`
        : `${last}${CUT}`;
  }
  return out;
}

/** Word-wraps to lines of at most w characters. */
export function wrap(text: string, w: number): string[] {
  const out: string[] = [];
  if (w <= 0) {
    return out;
  }
  let line = '';
  const words: string[] = [];
  for (const word of text.split(/\s+/)) {
    // A word longer than a line is split, so nothing runs past the box.
    for (let i = 0; i < word.length; i += w) {
      words.push(word.slice(i, i + w));
    }
  }
  for (const word of words) {
    if (`${line} ${word}`.trim().length > w) {
      if (line.trim()) {
        out.push(line.trim());
      }
      line = word;
    } else {
      line += ` ${word}`;
    }
  }
  if (line.trim()) {
    out.push(line.trim());
  }
  return out;
}

/** Characters outside printable ASCII and Latin-1 letters that the font does have. */
const FONT_EXTRA = new Set(['…', '•', '«', '»', '►', '°', '¦', '→']);
const SWAP: Record<string, string> = {
  '—': '-',
  '–': '-',
  '‘': "'",
  '’': "'",
  '“': '"',
  '”': '"',
  '·': '•',
};

/**
 * Maps characters the terminal font lacks before drawing game or player text. A fallback
 * glyph has another width and breaks the cell.
 */
export function safe(str: string | null | undefined): string {
  if (!str) {
    return '';
  }
  let out = '';
  for (const c of str) {
    const code = c.codePointAt(0) || 0;
    if (SWAP[c]) {
      out += SWAP[c];
    } else if (code >= 0x20 && code <= 0x7e) {
      out += c;
    } else if (code >= 0xc0 && code <= 0xff && code !== 0xd7 && code !== 0xf7) {
      out += c;
    } else if (FONT_EXTRA.has(c)) {
      out += c;
    } else if (c === '\n' || c === '\t') {
      out += ' ';
    } else {
      out += '?';
    }
  }
  return out;
}

// ---------------------------------------------------------------------------
// Theme
// ---------------------------------------------------------------------------

/** Glass layers inside the screen: gradient (on .lt-crt), nebula, stars, scanlines, vignette. */
export const STAR_COUNT = 70;

/** The fixed star field: [left %, top %, opacity]. */
export const STARS: [number, number, number][] = (() => {
  let seed = 7;
  const rnd = () => {
    seed = (seed * 16807) % 2147483647;
    return seed / 2147483647;
  };
  const out: [number, number, number][] = [];
  for (let i = 0; i < STAR_COUNT; i++) {
    out.push([rnd() * 100, rnd() * 100, 0.2 + rnd() * 0.3]);
  }
  return out;
})();

/** Terminal CSS. Scoped under .lt-tui so the short class names can't leak. */
export const TERM_CSS = `
.lt-crt { position: absolute; inset: 0; overflow: hidden;
  background: radial-gradient(ellipse at 50% 45%, #1a0a30, #05010b 85%); }
.lt-nebula { position: absolute; inset: 0; pointer-events: none;
  background: radial-gradient(ellipse 40% 45% at 92% 94%, rgba(255,80,210,.06), transparent 70%),
    radial-gradient(ellipse 50% 45% at 30% 20%, rgba(90,60,255,.16), transparent 70%); }
.lt-stars { position: absolute; inset: 0; pointer-events: none; }
.lt-stars i { position: absolute; background: #a88fe0; }
.lt-scan { position: absolute; inset: 0; z-index: 22; pointer-events: none;
  background: repeating-linear-gradient(0deg, rgba(0,0,0,.18) 0 1px, transparent 1px 3px); }
.lt-vign { position: absolute; inset: 0; z-index: 23; pointer-events: none;
  box-shadow: inset 0 0 calc(var(--s) * 26px) #000; }
.lt-tui { --lt-fg: #dfc4ff; --lt-ph: var(--lt-fg); --lt-dim: #8f6fc8; --lt-faint: #4d3a73; --lt-wht: #ffffff;
  --lt-acc: #ff66d6; --lt-amb: #ffc41f; --lt-red: #ff5f6f; --lt-bar: #7b2fbf; --lt-ink: #1a0420;
  --lt-bg: #0f0620; --lt-edge: rgba(223,196,255,.34); --lt-edge-dead: #2c2142;
  --lt-panel: rgba(30,12,58,.72); --lt-panel-alt: rgba(44,20,82,.60); --lt-panel-foc: rgba(70,34,120,.85);
  --lt-key: rgba(223,196,255,.07); --lt-cap: rgba(223,196,255,.16); --lt-field: rgba(223,196,255,.10);
  --lt-menu: rgba(8,3,16,.62); --lt-box: rgba(8,3,16,.40);
  --lt-glow-foc: 0 0 calc(var(--s) * 6px) rgba(190,140,255,.35);
  position: absolute; z-index: 5; font-family: 'VCR', 'Consolas', monospace; color: var(--lt-fg); white-space: pre;
  text-shadow: 0 0 4px rgba(190,140,255,.75); user-select: none; }
.lt-tui span { position: absolute; z-index: 2; }
.lt-tui span.lt-in { position: static; }
.lt-tui .lt-region { position: absolute; }
.lt-tui .dim { color: var(--lt-dim); text-shadow: 0 0 3px rgba(143,111,200,.5); }
.lt-tui .faint { color: var(--lt-faint); text-shadow: none; }
.lt-tui .wht { color: var(--lt-wht); text-shadow: 0 0 5px #a070ff; }
.lt-tui .acc { color: var(--lt-acc); text-shadow: 0 0 8px rgba(255,102,214,.7); }
.lt-tui .amb { color: var(--lt-amb); text-shadow: 0 0 4px rgba(255,196,31,.55); }
.lt-tui .red { color: var(--lt-red); text-shadow: none; }
.lt-tui .inv { background: var(--lt-fg); color: var(--lt-ink); text-shadow: none; }
.lt-tui .invx { background: var(--lt-acc); color: var(--lt-ink); text-shadow: none; }
.lt-tui .inva { background: var(--lt-amb); color: var(--lt-ink); text-shadow: none; }
.lt-tui .ink { color: var(--lt-ink); text-shadow: none; }
.lt-tui .nog { text-shadow: none; }
.lt-tui .lt-big { white-space: pre; }
.lt-tui .lt-band, .lt-tui .lt-slab, .lt-tui .lt-boxs, .lt-tui .lt-rule, .lt-tui .lt-box {
  position: absolute; box-sizing: border-box; z-index: 1; }
.lt-tui .lt-band-bar { background: var(--lt-bar); }
.lt-tui .lt-band-accent { background: var(--lt-acc); }
.lt-tui .lt-band-fg { background: var(--lt-fg); }
.lt-tui .lt-band-panel { background: var(--lt-panel); }
.lt-tui .lt-band-field { background: var(--lt-field); }
.lt-tui .lt-band-field.is-dead { background: rgba(223,196,255,.05); }
.lt-tui .lt-band-warn { background: rgba(255,196,31,.10); border-left-style: solid; border-color: var(--lt-amb); }
.lt-tui .lt-band-bad { background: var(--lt-red); }
.lt-tui .lt-band-bg { background: var(--lt-bg); }
.lt-tui .lt-slab { border-style: solid; border-color: var(--lt-edge); background: var(--lt-panel); }
.lt-tui .lt-slab-row.is-alt { background: var(--lt-panel-alt); }
.lt-tui .lt-slab.is-foc { border-color: var(--lt-fg); background: var(--lt-panel-foc); box-shadow: var(--lt-glow-foc); }
.lt-tui .lt-slab.is-dead { border-color: var(--lt-edge-dead); background: rgba(30,12,58,.36); }
.lt-tui .lt-slab.is-dead.is-foc { border-color: var(--lt-fg); box-shadow: var(--lt-glow-foc); }
.lt-tui .lt-slab.is-on { border-left-color: var(--lt-acc); }
.lt-tui .lt-slab.is-on.is-foc { border-left-color: var(--lt-acc); }
.lt-tui .lt-swatch { position: absolute; box-sizing: border-box; z-index: 4; border-style: solid;
  border-color: var(--lt-edge); }
.lt-tui .lt-swatch.is-lit { border-color: var(--lt-fg); }
.lt-tui .lt-swatch.is-foc { box-shadow: var(--lt-glow-foc); }
.lt-tui .lt-bar { position: absolute; box-sizing: border-box; z-index: 4; border-style: solid;
  border-color: var(--lt-edge); cursor: pointer; touch-action: none; }
.lt-tui .lt-bar.is-foc { border-color: var(--lt-fg); box-shadow: var(--lt-glow-foc); }
.lt-tui .lt-bar-thumb { position: absolute; top: -3px; bottom: -3px; background: var(--lt-fg);
  box-shadow: 0 0 0 1px var(--lt-bg), 0 0 6px rgba(190,140,255,.8); }
.lt-tui .lt-bar.is-grab .lt-bar-thumb { background: #fff; }
.lt-tui .lt-check { position: absolute; box-sizing: border-box; z-index: 2; border-style: solid;
  border-color: var(--lt-dim); pointer-events: none; }
.lt-tui .lt-check.is-on { border-color: var(--lt-wht); box-shadow: 0 0 5px rgba(160,112,255,.7); }
.lt-tui .lt-check i { position: absolute; background: var(--lt-wht); }
.lt-tui .lt-check.is-acc.is-on { border-color: var(--lt-acc); box-shadow: 0 0 6px rgba(255,102,214,.6); }
.lt-tui .lt-check.is-acc i { background: var(--lt-acc); }
.lt-tui .lt-slide { position: absolute; z-index: 5; cursor: pointer; touch-action: none; }
.lt-tui .lt-slide-track { position: absolute; left: 0; right: 0; box-sizing: border-box; overflow: hidden;
  border-style: solid; border-color: var(--lt-edge); background: var(--lt-field); }
.lt-tui .lt-slide-fill { position: absolute; left: 0; top: 0; bottom: 0; background: var(--lt-dim); }
.lt-tui .lt-slide.is-lit .lt-slide-fill { background: var(--lt-fg); }
.lt-tui .lt-slide-thumb { position: absolute; background: var(--lt-wht);
  box-shadow: 0 0 0 1px var(--lt-bg), 0 0 6px rgba(190,140,255,.8); }
.lt-tui .lt-hit { position: absolute; z-index: 4; cursor: pointer; }
.lt-tui .lt-k { position: absolute; box-sizing: border-box; z-index: 5; cursor: pointer; border-style: solid;
  border-color: var(--lt-edge); }
.lt-tui .lt-k span { z-index: auto; }
.lt-tui .lt-k-box { background: var(--lt-key); }
.lt-tui .lt-k-big { background: var(--lt-key); border-color: var(--lt-fg); color: var(--lt-wht); text-shadow: 0 0 5px #a070ff; }
.lt-tui .lt-k-plain { color: var(--lt-dim); text-shadow: 0 0 3px rgba(143,111,200,.5); }
.lt-tui .lt-k-cap { background: var(--lt-cap); color: var(--lt-wht); text-shadow: 0 0 5px #a070ff; }
.lt-tui .lt-k.is-lit { background: var(--lt-dim); border-color: var(--lt-dim); color: var(--lt-ink); text-shadow: none; }
.lt-tui .lt-k.is-foc { background: var(--lt-fg); border-color: var(--lt-fg);
  color: var(--lt-ink); text-shadow: none; }
.lt-tui .lt-k.is-foc { box-shadow: var(--lt-glow-foc); }
.lt-tui .lt-k.is-on { background: var(--lt-acc); border-color: var(--lt-acc); color: var(--lt-ink); text-shadow: none; }
.lt-tui .lt-k.is-on.is-foc { border-color: var(--lt-fg); }
.lt-tui .lt-k.is-foc span, .lt-tui .lt-k.is-lit span, .lt-tui .lt-k.is-on span { color: inherit; text-shadow: none; }
.lt-tui .lt-k.is-dead { color: var(--lt-faint); border-color: var(--lt-edge-dead); text-shadow: none; cursor: default; }
.lt-tui .lt-boxs { border-style: solid; border-color: var(--lt-edge); }
.lt-tui .lt-boxs.is-bright { border-color: var(--lt-fg); }
.lt-tui .lt-boxs-box { background: var(--lt-box); }
.lt-tui .lt-boxs-menu { background: var(--lt-menu); }
.lt-tui .lt-boxs-bg { background: var(--lt-bg); }
.lt-tui .lt-dialog { position: absolute; left: 0; top: 0; z-index: 8; }
.lt-tui .lt-dialog-block { position: absolute; }
.lt-tui .lt-dimsheet { position: absolute; inset: 0; z-index: 7; background: rgba(5,1,11,.65); }
.lt-tui .lt-sheet { position: absolute; inset: 0; z-index: 7; }
.lt-tui .lt-emblem { position: absolute; z-index: 2; }
.lt-tui .lt-rule { background: var(--lt-edge); }
.lt-tui .lt-pager { cursor: pointer; z-index: 5; }
.lt-tui .lt-box { border-style: solid; border-color: var(--lt-edge); }
.lt-tui .lt-box.dimb { border-color: var(--lt-edge-dead); }
.lt-tui .lt-field { position: absolute; z-index: 6; padding: 0; margin: 0; border: none; outline: none;
  background: transparent; color: var(--lt-fg); caret-color: var(--lt-fg); caret-shape: block; font: inherit;
  letter-spacing: 0; text-shadow: inherit; user-select: text; }
.lt-tui .lt-field.is-dead { color: var(--lt-faint); }
.lt-tui .lt-blk { position: absolute; background: var(--lt-fg); box-shadow: 0 0 6px rgba(190,140,255,.5); }
.lt-tui .lt-blk.dim { background: var(--lt-dim); box-shadow: none; }
.lt-tui .lt-blk.ablk { background: var(--lt-amb); box-shadow: 0 0 6px rgba(255,196,31,.5); }
.lt-tui .lt-blk.rblk { background: var(--lt-red); box-shadow: 0 0 6px rgba(255,95,111,.5); }
.lt-tui .lt-blk.faint { background: var(--lt-faint); box-shadow: none; }
.lt-vscreen { position: absolute; z-index: 2; box-sizing: border-box; overflow: hidden; background: #07030d;
  border: 1px solid #3a2466; outline: 3px solid #0c0616; outline-offset: 0;
  box-shadow: 0 0 0 4px #3a2466, inset 0 0 18px rgba(0,0,0,.9), inset 0 2px 6px rgba(0,0,0,.8); }
.lt-vscan { position: absolute; inset: 0; pointer-events: none; z-index: 3;
  background: repeating-linear-gradient(to bottom, rgba(0,0,0,.10) 0 1px, transparent 1px 3px),
    radial-gradient(ellipse at 30% 15%, rgba(223,196,255,.04), transparent 45%);
  box-shadow: inset 0 0 14px rgba(0,0,0,.75); }
.lt-tui .lt-vmark { z-index: 3; }
.lt-tui .lt-vblink { display: inline-block; width: 0.586em; height: 0.75em; margin-left: 0.586em;
  background: currentColor; vertical-align: -0.05em; animation: lt-vblink 1.06s steps(1) infinite; }
@keyframes lt-vblink { 0% { opacity: 1; } 50% { opacity: 0; } }
`;
