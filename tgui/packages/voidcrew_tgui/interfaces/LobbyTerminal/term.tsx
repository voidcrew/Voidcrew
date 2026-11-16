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
  useContext,
  useEffect,
  useRef,
  useState,
} from 'react';

import type { Mode } from './layout';
import { type FocusOpts, FocusScope, useFocusable } from './nav';

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

/**
 * Compatibility for screens not yet redesigned: the row their old frames start on, so the
 * frame's top border lands on the box's top edge (BOX_Y). Remove with its last caller.
 */
export const LEGACY_TOP = 2;
/** Compatibility: screens not yet redesigned take their one-panel (narrow) layout. */
export const LEGACY_NARROW: boolean = true;

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
export type NavProps = Pick<FocusOpts, 'auto' | 'edge' | 'tab' | 'mouseOnly'>;

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
      ref={focus.ref}
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
  children: string;
}) {
  const { x, y, scale, w, align = 'left', cls, children } = props;
  const { cw, ch } = useGrid();
  const k = align === 'center' ? 0.5 : align === 'right' ? 1 : 0;
  const left = w === undefined ? x : x + (w - children.length * scale) * k;
  return (
    <span
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
}) {
  const { x, y, w, h, tone } = props;
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
  return <div className={`lt-band lt-band-${tone}`} style={style} />;
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
    onClick?: () => void;
    /** Told when the slab gains or loses the focus (mouse or keys). */
    onFocus?: (on: boolean) => void;
    children?: ReactNode;
  },
) {
  const { x, y, w, h, variant, alt, dead, onClick, onFocus, children } = props;
  const { cw, ch, lw } = useGrid();
  const live = !!onClick && !dead;
  const focus = useFocusable<HTMLDivElement>(live, {
    activate: () => onClick?.(),
    auto: props.auto,
    edge: props.edge,
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
    dead ? 'is-dead' : '',
    focus.focused ? 'is-foc' : '',
  ]
    .filter(Boolean)
    .join(' ');
  const style: CSSProperties = {
    ...box,
    borderWidth: variant === 'block' ? lw : 0,
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
    /** A layout zone for the keyboard rules (nav.tsx FocusOpts.zone). */
    zone?: string;
    title?: string;
  },
) {
  const { x, y, w, label, labelCls, right, rightCls, kind, onClick, zone } =
    props;
  const { title } = props;
  const state = props.state || 'idle';
  const h = props.h ?? (kind === 'big' ? 2 : kind === 'plain' ? 1 : 1.5);
  const { cw, ch, lw } = useGrid();
  const dead = state === 'dead';
  const [pressed, setPressed] = useState(false);
  const timer = useRef<ReturnType<typeof setTimeout> | null>(null);
  useEffect(
    () => () => {
      if (timer.current) {
        clearTimeout(timer.current);
      }
    },
    [],
  );
  const press = () => {
    setPressed(true);
    if (timer.current) {
      clearTimeout(timer.current);
    }
    timer.current = setTimeout(() => setPressed(false), 80);
    onClick();
  };
  const focus = useFocusable<HTMLDivElement>(!dead, {
    activate: press,
    auto: props.auto,
    edge: props.edge,
    tab: props.tab,
    mouseOnly: props.mouseOnly,
    zone,
  });
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
    pressed ? 'is-press' : '',
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
      <span
        className={cx(state === 'dead' ? undefined : labelCls)}
        style={{ left: px(lx - bl), top: px(ty) }}
      >
        {label}
      </span>
      {!!right && (
        <span
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
  children?: ReactNode;
}) {
  const { w, h, caption, children } = props;
  const { cols, cw, ch } = useGrid();
  const x = Math.floor((cols - w) / 2);
  const y = BODY_Y + 2;
  return (
    <div className="lt-dialog">
      <div
        className="lt-dialog-block"
        style={rect(x, y, w, h, cw, ch)}
        onClick={(e) => e.stopPropagation()}
      />
      <Box x={x} y={y} w={w} h={h} caption={caption} tone="bg" bright />
      <FocusScope>{children}</FocusScope>
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
  onChange: (value: string) => void;
  onEnter: () => void;
};

/** The text input over a field, shared by Field and LegacyField. */
function FieldInput(
  props: FieldProps & {
    left: number;
    top: number;
    width: number;
    height: number;
    cls: string;
  },
) {
  const { value, max, disabled, secret, onChange, onEnter } = props;
  const input = useRef<HTMLInputElement | null>(null);
  const focus = useFocusable<HTMLInputElement>(!disabled, {
    activate: () => input.current?.focus(),
    auto: props.auto,
    input,
  });
  return (
    <input
      ref={(el) => {
        input.current = el;
        focus.ref.current = el;
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
      onChange={(e) => onChange(e.target.value)}
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
      <Band x={x} y={y} w={w} h={h} tone="field" />
      {!value && (
        <Put x={x + 1} y={y + (h - 1) / 2} cls={disabled ? 'faint' : 'dim'}>
          {'.'.repeat(Math.max(0, w - 2))}
        </Put>
      )}
      <FieldInput
        {...props}
        cls={`lt-field${disabled ? ' is-dead' : ''}`}
        left={box.left + px(cw)}
        top={box.top}
        width={Math.max(0, box.width - px(2 * cw))}
        height={box.height}
      />
    </>
  );
}

/**
 * Compatibility for screens not yet redesigned: the old one-row `[          ]` field. x is
 * the opening bracket, w the cells between the brackets.
 */
export function LegacyField(props: FieldProps) {
  const { x, y, w, disabled } = props;
  const { cw, ch } = useGrid();
  return (
    <>
      <Put x={x} y={y} cls={disabled ? 'faint' : 'amb'}>
        {`[${' '.repeat(w)}]`}
      </Put>
      <FieldInput
        {...props}
        cls={`lt-field lt-field-old${disabled ? ' is-dead' : ''}`}
        left={px((x + 1) * cw)}
        top={px(y * ch)}
        width={px(w * cw)}
        height={ch}
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

// ---------------------------------------------------------------------------
// Kept for screens not yet redesigned
// ---------------------------------------------------------------------------

type FrameProps = {
  x: number;
  y: number;
  w: number;
  h: number;
  title?: string;
  /** Dim border. */
  dim?: boolean;
  children?: ReactNode;
};

/**
 * Old box from cell (x, y), w columns by h rows, the border through the middle of the edge
 * cells, with an optional title. Drawn as a single lw line; new work uses Box.
 */
export function Frame(props: FrameProps) {
  const { x, y, w, h, title, dim, children } = props;
  const { cw, ch, lw } = useGrid();
  const style: CSSProperties = {
    borderWidth: lw,
    left: px(x * cw + cw / 2 - lw / 2),
    top: px(y * ch + ch / 2 - lw / 2),
    width: Math.max(0, px((w - 1) * cw + lw)),
    height: Math.max(0, px((h - 1) * ch + lw)),
  };
  return (
    <>
      <div className={dim ? 'lt-box dimb' : 'lt-box'} style={style} />
      {!!title && (
        <Put x={x + 2} y={y} cls={dim ? 'dim' : 'wht'} bg>
          {` ${cut(title, Math.max(1, w - 6))} `}
        </Put>
      )}
      {children}
    </>
  );
}

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
 * A colour chip filling w cells (default 2) of row y. sel draws it with a lit border. hex must
 * be a CSS colour; the server sanitises every stored colour.
 */
export function Swatch(props: {
  x: number;
  y: number;
  hex: string;
  sel?: boolean;
  /** Width in cells. */
  w?: number;
  onClick?: () => void;
}) {
  const { x, y, hex, sel, w = 2, onClick } = props;
  const { cw, ch, s } = useGrid();
  const focus = useFocusable<HTMLDivElement>(!!onClick, {
    activate: () => onClick?.(),
    auto: sel ? 1 : undefined,
  });
  const lit = sel || focus.focused;
  const bw = lit ? Math.max(2, Math.round(s)) : Math.max(1, Math.round(s) - 1);
  return (
    <div
      ref={focus.ref}
      className={focus.focused ? 'lt-hitfoc' : undefined}
      onMouseEnter={focus.onMouseEnter}
      style={{
        position: 'absolute',
        boxSizing: 'content-box',
        left: x * cw + 1,
        top: y * ch + ch * 0.12,
        width: Math.max(0, w * cw - 4 - 2 * bw),
        height: Math.max(0, ch * 0.76 - 2 * bw),
        background: hex,
        border: `${bw}px solid ${lit ? 'var(--lt-fg)' : 'var(--lt-faint)'}`,
        boxShadow: sel
          ? '0 0 6px rgba(190,140,255,.7), inset 0 0 0 1px var(--lt-bg)'
          : 'inset 0 0 0 1px var(--lt-bg)',
        cursor: onClick ? 'pointer' : undefined,
        zIndex: 4,
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

/**
 * A framed overlay for screens not yet redesigned: paints the background over cells
 * (x, y, w, h), draws a Frame and puts its children above everything under it. New work
 * uses Dialog.
 */
export function Panel(props: {
  x: number;
  y: number;
  w: number;
  h: number;
  title?: string;
  children?: ReactNode;
}) {
  const { x, y, w, h, title, children } = props;
  const { cw, ch } = useGrid();
  return (
    <div style={{ position: 'absolute', left: 0, top: 0, zIndex: 8 }}>
      <div
        style={{
          position: 'absolute',
          left: x * cw,
          top: y * ch,
          width: w * cw,
          height: h * ch,
          background: 'var(--lt-bg)',
        }}
        onClick={(e) => e.stopPropagation()}
      />
      <Frame x={x} y={y} w={w} h={h} title={title} />
      <FocusScope>{children}</FocusScope>
    </div>
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

/** Left-pads to n characters. */
export function lpad(str: string | number, n: number): string {
  const s = String(str);
  return ' '.repeat(Math.max(0, n - s.length)) + s;
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
.lt-tui .lt-band-warn { background: rgba(255,196,31,.10); border-left-style: solid; border-color: var(--lt-amb); }
.lt-tui .lt-band-bad { background: var(--lt-red); }
.lt-tui .lt-band-bg { background: var(--lt-bg); }
.lt-tui .lt-slab { border-style: solid; border-color: var(--lt-edge); background: var(--lt-panel); }
.lt-tui .lt-slab-row.is-alt { background: var(--lt-panel-alt); }
.lt-tui .lt-slab.is-foc { border-color: var(--lt-fg); background: var(--lt-panel-foc); box-shadow: var(--lt-glow-foc); }
.lt-tui .lt-slab.is-dead { border-color: var(--lt-edge-dead); background: rgba(30,12,58,.36); }
.lt-tui .lt-hit { position: absolute; z-index: 4; cursor: pointer; }
.lt-tui .lt-k { position: absolute; box-sizing: border-box; z-index: 4; cursor: pointer; border-style: solid;
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
.lt-tui .lt-k.is-press { background: #fff; border-color: #fff; }
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
  background: transparent; color: var(--lt-fg); caret-color: var(--lt-fg); font: inherit; letter-spacing: 0;
  text-shadow: inherit; user-select: text; }
.lt-tui .lt-field-old { color: var(--lt-amb); caret-color: var(--lt-amb); }
.lt-tui .lt-field.is-dead { color: var(--lt-faint); }
.lt-tui .lt-blk { position: absolute; background: var(--lt-fg); box-shadow: 0 0 6px rgba(190,140,255,.5); }
.lt-tui .lt-blk.dim { background: var(--lt-dim); box-shadow: none; }
.lt-tui .lt-blk.ablk { background: var(--lt-amb); box-shadow: 0 0 6px rgba(255,196,31,.5); }
.lt-tui .lt-blk.rblk { background: var(--lt-red); box-shadow: 0 0 6px rgba(255,95,111,.5); }
.lt-tui .lt-blk.faint { background: var(--lt-faint); box-shadow: none; }
.lt-vscreen { position: absolute; box-sizing: border-box; overflow: hidden; background: #07030d;
  border: 1px solid #3a2466; outline: 3px solid #0c0616; outline-offset: 0;
  box-shadow: 0 0 0 4px #3a2466, inset 0 0 18px rgba(0,0,0,.9), inset 0 2px 6px rgba(0,0,0,.8); }
.lt-vscan { position: absolute; inset: 0; pointer-events: none; z-index: 3;
  background: repeating-linear-gradient(to bottom, rgba(0,0,0,.10) 0 1px, transparent 1px 3px),
    radial-gradient(ellipse at 30% 15%, rgba(255,255,255,.04), transparent 45%);
  box-shadow: inset 0 0 14px rgba(0,0,0,.75); }
`;
