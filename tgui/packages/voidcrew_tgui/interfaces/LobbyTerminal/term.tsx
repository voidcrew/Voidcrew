/**
 * Text-grid primitives for the dock terminal, ported from the approved mockup.
 *
 * Everything on the screen is placed on a cell grid: x is a column, y a row (fractions are
 * allowed, as in the mockup). Tabs draw only through these, so every tab matches the
 * mockup look without touching the shell.
 *
 * Colour classes: '' (phosphor), 'dim', 'faint', 'amb', 'red', 'inv' (inverse phosphor),
 * 'inva' (inverse amber).
 */
import {
  type CSSProperties,
  createContext,
  type ReactNode,
  useContext,
  useState,
} from 'react';

export type Grid = {
  cols: number;
  rows: number;
  /** Cell size in CSS px. */
  cw: number;
  ch: number;
  /** Bezel pixel scale; line weights follow it. */
  s: number;
  /** Too small for side-by-side panels: use one panel at a time with [ BACK ]. */
  narrow: boolean;
};

export const GridContext = createContext<Grid>({
  cols: 110,
  rows: 30,
  cw: 9,
  ch: 19,
  s: 2,
  narrow: false,
});

/** {cols, rows, cw, ch, s, narrow} of the current screen. */
export const useGrid = () => useContext(GridContext);

/** Rows used by the header and tab bar. Tab content starts here. */
export const TOP = 4;

export type Cls = '' | 'dim' | 'faint' | 'amb' | 'red' | 'inv' | 'inva';

const cx = (cls?: string) => (cls ? cls : undefined);

type PutProps = {
  x: number;
  y: number;
  /** Colour class. */
  cls?: Cls | string;
  children: ReactNode;
  onClick?: () => void;
  /** Class while hovered (clickable keys light up). */
  hoverCls?: Cls | string;
  /** Paint the terminal background behind the text (over frame lines). */
  bg?: boolean;
  title?: string;
};

/** Text at a cell. */
export function Put(props: PutProps) {
  const { x, y, cls, children, onClick, hoverCls, bg, title } = props;
  const { cw, ch } = useGrid();
  const [hover, setHover] = useState(false);
  const style: CSSProperties = {
    left: Math.round(x * cw),
    top: Math.round(y * ch),
  };
  if (bg) {
    style.background = 'var(--lt-bg)';
  }
  if (onClick) {
    style.cursor = 'pointer';
    style.zIndex = 5;
  }
  const shown = hover && hoverCls ? hoverCls : cls;
  return (
    <span
      className={cx(shown)}
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
      onMouseEnter={hoverCls ? () => setHover(true) : undefined}
      onMouseLeave={hoverCls ? () => setHover(false) : undefined}
    >
      {children}
    </span>
  );
}

/** Text ending just before column x (right-aligned). */
export function RPut(props: PutProps & { children: string }) {
  return <Put {...props} x={props.x - props.children.length} />;
}

type BtnProps = {
  x: number;
  y: number;
  label: string;
  /** Right-align: the button ends just before column x. */
  right?: boolean;
  /** Lit (inverse) at rest, like the mockup's primary keys. */
  lit?: boolean;
  /** Amber variant (CODE / APPLY rows). */
  amber?: boolean;
  disabled?: boolean;
  onClick?: () => void;
};

/** A `[ LABEL ]` key on the grid. Disabled keys draw faint and ignore clicks. */
export function Btn(props: BtnProps) {
  const { x, y, label, right, lit, amber, disabled, onClick } = props;
  const text = `[ ${label} ]`;
  const at = right ? x - text.length : x;
  if (disabled) {
    return (
      <Put x={at} y={y} cls="faint">
        {text}
      </Put>
    );
  }
  const rest = lit ? (amber ? 'inva' : 'inv') : amber ? 'amb' : '';
  const hover = amber ? 'inva' : 'inv';
  return (
    <Put x={at} y={y} cls={rest} hoverCls={hover} onClick={onClick}>
      {text}
    </Put>
  );
}

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

/** Double-line box from cell (x, y), w columns by h rows, with an optional title. */
export function Frame(props: FrameProps) {
  const { x, y, w, h, title, dim, children } = props;
  const { cw, ch, s } = useGrid();
  const bw = Math.max(3, Math.round(s) + 1);
  const style: CSSProperties = {
    borderWidth: bw,
    left: x * cw + cw / 2 - bw / 2,
    top: y * ch + ch / 2 - bw / 2,
    width: Math.max(0, (w - 1) * cw - bw),
    height: Math.max(0, (h - 1) * ch - bw),
  };
  return (
    <>
      <div className={dim ? 'lt-box dimb' : 'lt-box'} style={style} />
      {!!title && (
        <Put x={x + 2} y={y} cls={dim ? 'dim' : ''} bg>
          {` ${title} `}
        </Put>
      )}
      {children}
    </>
  );
}

/** Horizontal rule through the middle of row y. */
export function Rule(props: { x: number; y: number; w: number }) {
  const { x, y, w } = props;
  const { cw, ch, s } = useGrid();
  return (
    <div
      className="lt-rule"
      style={{
        borderTopWidth: Math.max(1, Math.round(s) - 1),
        left: x * cw,
        top: y * ch + ch / 2,
        width: w * cw,
      }}
    />
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
export function Hit(props: {
  x: number;
  y: number;
  w: number;
  h: number;
  onClick: () => void;
  onHover?: (over: boolean) => void;
}) {
  const { x, y, w, h, onClick, onHover } = props;
  const { cw, ch } = useGrid();
  return (
    <div
      style={{
        position: 'absolute',
        left: x * cw,
        top: y * ch,
        width: w * cw,
        height: h * ch,
        cursor: 'pointer',
        zIndex: 4,
      }}
      onClick={onClick}
      onMouseEnter={onHover ? () => onHover(true) : undefined}
      onMouseLeave={onHover ? () => onHover(false) : undefined}
    />
  );
}

/** Pads or cuts to n characters; a cut ends in '.'. */
export function pad(str: string | number, n: number): string {
  const s = String(str);
  if (n <= 0) {
    return '';
  }
  return s.length > n ? `${s.slice(0, n - 1)}.` : s + ' '.repeat(n - s.length);
}

/** Left-pads to n characters. */
export function lpad(str: string | number, n: number): string {
  const s = String(str);
  return ' '.repeat(Math.max(0, n - s.length)) + s;
}

/** Word-wraps to lines of at most w characters. */
export function wrap(text: string, w: number): string[] {
  const out: string[] = [];
  let line = '';
  for (const word of text.split(' ')) {
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

/** Terminal CSS. Scoped under .lt-tui so the short class names can't leak. */
export const TERM_CSS = `
.lt-crt { position: absolute; inset: 0; overflow: hidden;
  background: radial-gradient(ellipse at 50% 45%, #0c2018 0%, var(--lt-bg) 60%, #040a07 100%); }
.lt-tui { --lt-ph: #7effbf; --lt-dim: #3f9a76; --lt-faint: #2b6450; --lt-amb: #ffc41f; --lt-red: #ff5f6f;
  position: absolute; font-family: 'VCR', 'Consolas', monospace; color: var(--lt-ph); white-space: pre;
  text-shadow: 0 0 3px rgba(126,255,191,.55), 0 0 9px rgba(126,255,191,.18); user-select: none; }
.lt-tui span { position: absolute; }
.lt-tui .dim { color: var(--lt-dim); text-shadow: 0 0 3px rgba(63,154,118,.45); }
.lt-tui .faint { color: var(--lt-faint); text-shadow: none; }
.lt-tui .amb { color: var(--lt-amb); text-shadow: 0 0 3px rgba(255,196,31,.55), 0 0 9px rgba(255,196,31,.2); }
.lt-tui .red { color: var(--lt-red); text-shadow: 0 0 3px rgba(255,95,111,.55), 0 0 9px rgba(255,95,111,.2); }
.lt-tui .inv { background: var(--lt-ph); color: var(--lt-bg); text-shadow: 0 0 6px rgba(126,255,191,.6); box-shadow: 0 0 8px rgba(126,255,191,.35); }
.lt-tui .inva { background: var(--lt-amb); color: #160f02; box-shadow: 0 0 8px rgba(255,196,31,.35); text-shadow: none; }
.lt-tui .lt-box { position: absolute; border-style: double; border-color: var(--lt-ph);
  box-shadow: 0 0 5px rgba(126,255,191,.35), inset 0 0 5px rgba(126,255,191,.18); }
.lt-tui .lt-box.dimb { border-color: var(--lt-dim); box-shadow: 0 0 4px rgba(63,154,118,.3); }
.lt-tui .lt-rule { position: absolute; border-top-style: solid; border-color: var(--lt-faint); }
.lt-tui .lt-blk { position: absolute; background: var(--lt-ph); box-shadow: 0 0 6px rgba(126,255,191,.5); }
.lt-tui .lt-blk.dim { background: var(--lt-dim); box-shadow: none; }
.lt-tui .lt-blk.ablk { background: var(--lt-amb); box-shadow: 0 0 6px rgba(255,196,31,.5); }
.lt-tui .lt-blk.rblk { background: var(--lt-red); box-shadow: 0 0 6px rgba(255,95,111,.5); }
.lt-tui .lt-blk.faint { background: var(--lt-faint); box-shadow: none; }
.lt-glass { position: absolute; inset: 0; z-index: 2; pointer-events: none;
  background: radial-gradient(ellipse at 28% 18%, rgba(255,255,255,.045), transparent 38%),
    radial-gradient(ellipse at center, transparent 55%, rgba(0,0,0,.55) 100%); }
.lt-scan { position: absolute; inset: 0; z-index: 2; pointer-events: none; }
.lt-vscreen { position: absolute; box-sizing: border-box; overflow: hidden; background: #050607;
  border: 1px solid #1d3a2e; outline: 3px solid #0a1410; outline-offset: 0;
  box-shadow: 0 0 0 4px #1d3a2e, inset 0 0 18px rgba(0,0,0,.9), inset 0 2px 6px rgba(0,0,0,.8); }
.lt-vscan { position: absolute; inset: 0; pointer-events: none; z-index: 3;
  background: repeating-linear-gradient(to bottom, rgba(0,0,0,.10) 0 1px, transparent 1px 3px),
    radial-gradient(ellipse at 30% 15%, rgba(255,255,255,.04), transparent 45%);
  box-shadow: inset 0 0 14px rgba(0,0,0,.75); }
`;
