/**
 * Free colour entry for BODY and KIT (CHARACTER-PLAN 2.9). The row reads
 * `LABEL  [##] #RRGGBB`; clicking the chip or the hex opens the H/S/V panel. Only SET sends.
 * Owner: C3. The props are the contract C4's KitEditor builds against; keep them.
 *
 * An empty label draws just the chip and hex (for a colour that sits after a cycler on the
 * same row, as HAIR does); the panel is then titled COLOUR. The panel places itself under the
 * row and stays on the screen. Dragging on a bar only changes local state: nothing is sent
 * until SET, so the server never renders a colour that was dragged past.
 */
import { type PointerEvent as ReactPointerEvent, useState } from 'react';

import { useBack } from './nav';
import { Btn, Field, lpad, Panel, Put, Swatch, TOP, useGrid } from './term';

export type ColorEntryProps = {
  /** Column and row of the label. */
  x: number;
  y: number;
  /** Cells the row may use. */
  w: number;
  label: string;
  /** Current colour, "#rrggbb". */
  value: string;
  /** Colours offered in the recent row (already on this file, plus the viewer's last ones). */
  recent: string[];
  /** Show [ PICKER ] (BYOND's native dialog). BODY colours only. */
  native?: boolean;
  /** SET pressed with a valid colour. */
  onSet: (hex: string) => void;
  /** [ PICKER ] pressed. */
  onPicker?: () => void;
};

// ---------------------------------------------------------------------------
// Colour maths

type HSV = { h: number; s: number; v: number };

/** "#rrggbb", "rrggbb", "#rgb" or "rgb" to "#rrggbb" (lower case), else null. */
export function parseHex(text: string): string | null {
  let t = String(text ?? '')
    .trim()
    .toLowerCase();
  if (t.startsWith('#')) {
    t = t.slice(1);
  }
  if (/^[0-9a-f]{3}$/.test(t)) {
    t = t
      .split('')
      .map((c) => c + c)
      .join('');
  }
  return /^[0-9a-f]{6}$/.test(t) ? `#${t}` : null;
}

function hexToHsv(hex: string): HSV {
  const n = parseInt(hex.slice(1), 16);
  const r = ((n >> 16) & 255) / 255;
  const g = ((n >> 8) & 255) / 255;
  const b = (n & 255) / 255;
  const max = Math.max(r, g, b);
  const d = max - Math.min(r, g, b);
  let h = 0;
  if (d) {
    if (max === r) {
      h = ((g - b) / d) % 6;
    } else if (max === g) {
      h = (b - r) / d + 2;
    } else {
      h = (r - g) / d + 4;
    }
    h *= 60;
    if (h < 0) {
      h += 360;
    }
  }
  return { h, s: max ? d / max : 0, v: max };
}

function hsvToHex({ h, s, v }: HSV): string {
  const f = (k: number) => {
    const t = (k + h / 60) % 6;
    return v - v * s * Math.max(0, Math.min(t, 4 - t, 1));
  };
  const c = (x: number) =>
    Math.round(x * 255)
      .toString(16)
      .padStart(2, '0');
  return `#${c(f(5))}${c(f(3))}${c(f(1))}`;
}

// ---------------------------------------------------------------------------
// The viewer's last colours (per viewer, browser storage; the panel works without it)

const STORE = 'lt-recent-colours';
const KEEP = 8;

function readStored(): string[] {
  try {
    const raw = JSON.parse(window.localStorage.getItem(STORE) || '[]');
    return Array.isArray(raw)
      ? raw.map((c) => parseHex(String(c))).filter((c): c is string => !!c)
      : [];
  } catch {
    return [];
  }
}

function remember(hex: string) {
  try {
    const next = [hex, ...readStored().filter((c) => c !== hex)].slice(0, KEEP);
    window.localStorage.setItem(STORE, JSON.stringify(next));
  } catch {
    // Storage blocked: the row just shows the file's colours.
  }
}

// ---------------------------------------------------------------------------

const PANEL_W = 44;
const PANEL_H = 11;
const BAR = 24;
const CHANNELS: ['h' | 's' | 'v', string, number][] = [
  ['h', 'H', 360],
  ['s', 'S', 100],
  ['v', 'V', 100],
];

/** The CSS gradient a bar shows: its channel swept with the other two held. */
function barGradient(ch: 'h' | 's' | 'v', hsv: HSV): string {
  const stops: string[] = [];
  for (let i = 0; i <= 12; i++) {
    const t = i / 12;
    const at =
      ch === 'h'
        ? { ...hsv, h: t * 359.9 }
        : ch === 's'
          ? { ...hsv, s: t }
          : { ...hsv, v: t };
    stops.push(hsvToHex(at));
  }
  return `linear-gradient(to right, ${stops.join(', ')})`;
}

/** One H/S/V bar: BAR cells, click or drag to set. */
function Bar(props: {
  x: number;
  y: number;
  ch: 'h' | 's' | 'v';
  hsv: HSV;
  onChange: (t: number) => void;
}) {
  const { x, y, ch, hsv, onChange } = props;
  const { cw, ch: rh } = useGrid();
  const t = ch === 'h' ? hsv.h / 360 : ch === 's' ? hsv.s : hsv.v;
  const at = (e: ReactPointerEvent<HTMLDivElement>) => {
    const r = e.currentTarget.getBoundingClientRect();
    onChange(Math.max(0, Math.min(1, (e.clientX - r.left) / r.width)));
  };
  return (
    <div
      style={{
        position: 'absolute',
        boxSizing: 'border-box',
        left: x * cw,
        top: y * rh + rh * 0.18,
        width: BAR * cw,
        height: rh * 0.64,
        background: barGradient(ch, hsv),
        border: '1px solid var(--lt-faint)',
        boxShadow: 'inset 0 0 0 1px #07130d',
        cursor: 'pointer',
        zIndex: 9,
        touchAction: 'none',
      }}
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
      onClick={(e) => e.stopPropagation()}
    >
      <div
        style={{
          position: 'absolute',
          left: `calc(${(t * 100).toFixed(2)}% - 2px)`,
          top: -3,
          bottom: -3,
          width: 3,
          background: 'var(--lt-ph)',
          boxShadow: '0 0 0 1px #07130d, 0 0 6px rgba(126,255,191,.8)',
        }}
      />
    </div>
  );
}

export function ColorEntry(props: ColorEntryProps) {
  const { x, y, w, label, value, recent, native, onSet, onPicker } = props;
  const { cols, rows } = useGrid();
  const [open, setOpen] = useState(false);
  const [hsv, setHsv] = useState<HSV>(() =>
    hexToHsv(parseHex(value) || '#000000'),
  );
  const [text, setText] = useState(String(value ?? ''));

  const current = parseHex(value) || '#000000';
  const typed = parseHex(text);

  const show = (hex: string) => {
    setHsv(hexToHsv(hex));
    setText(hex.toUpperCase());
  };
  const openPanel = () => {
    show(current);
    setOpen(true);
  };
  const set = (hex: string | null) => {
    if (!hex) {
      return;
    }
    remember(hex);
    setOpen(false);
    if (hex !== current) {
      onSet(hex);
    }
  };

  useBack(open ? () => setOpen(false) : null);

  const lx = label ? x + label.length + 1 : x;
  const row = (
    <>
      {!!label && (
        <Put x={x} y={y} cls="dim">
          {label}
        </Put>
      )}
      <Swatch x={lx} y={y} hex={current} sel={open} onClick={openPanel} />
      {lx - x + 10 <= w && (
        <Put x={lx + 3} y={y} hoverCls="inv" onClick={openPanel}>
          {current.toUpperCase()}
        </Put>
      )}
    </>
  );
  if (!open) {
    return row;
  }

  // Under the row, kept on the screen.
  const px = Math.max(0, Math.min(x, cols - PANEL_W - 1));
  const py =
    y + 1 + PANEL_H <= rows - 1
      ? y + 1
      : Math.max(TOP, Math.min(y - PANEL_H, rows - 1 - PANEL_H));
  const draft = typed || hsvToHex(hsv);
  const chips = [...recent.map((c) => parseHex(c)), ...readStored()]
    .filter((c, i, all): c is string => !!c && all.indexOf(c) === i)
    .slice(0, Math.floor((PANEL_W - 6) / 2));

  return (
    <>
      {row}
      <Panel
        x={px}
        y={py}
        w={PANEL_W}
        h={PANEL_H}
        title={label ? `${label} COLOUR` : 'COLOUR'}
      >
        <Swatch x={px + 3} y={py + 2} hex={draft} w={5} />
        <Field
          x={px + 10}
          y={py + 2}
          w={8}
          value={text}
          max={7}
          onChange={(v) => {
            setText(v);
            const hex = parseHex(v);
            if (hex) {
              setHsv(hexToHsv(hex));
            }
          }}
          onEnter={() => set(typed)}
        />
        {!typed && (
          <>
            <Put x={px + 10} y={py + 2} cls="red" bg>
              {'['}
            </Put>
            <Put x={px + 19} y={py + 2} cls="red" bg>
              {']'}
            </Put>
          </>
        )}
        {CHANNELS.map(([ch, name, scale], i) => {
          const shown = ch === 'h' ? hsv.h : hsv[ch] * 100;
          return (
            <span key={ch}>
              <Put x={px + 3} y={py + 4 + i} cls="dim">
                {name}
              </Put>
              <Bar
                x={px + 6}
                y={py + 4 + i}
                ch={ch}
                hsv={hsv}
                onChange={(t) => {
                  const next = { ...hsv, [ch]: ch === 'h' ? t * 359.9 : t };
                  setHsv(next);
                  setText(hsvToHex(next).toUpperCase());
                }}
              />
              <Put x={px + 6 + BAR + 2} y={py + 4 + i}>
                {lpad(Math.round(Math.min(shown, scale)), 3)}
              </Put>
            </span>
          );
        })}
        {chips.map((c, i) => (
          <Swatch
            key={c}
            x={px + 3 + i * 2}
            y={py + 7.5}
            hex={c}
            sel={c === draft}
            onClick={() => show(c)}
          />
        ))}
        {!!native && !!onPicker && (
          <Btn
            x={px + 3}
            y={py + 9}
            label="PICKER"
            onClick={() => {
              setOpen(false);
              onPicker();
            }}
          />
        )}
        <Btn
          x={px + PANEL_W - 10}
          y={py + 9}
          label="CANCEL"
          right
          onClick={() => setOpen(false)}
        />
        <Btn
          x={px + PANEL_W - 2}
          y={py + 9}
          label="SET"
          right
          lit
          disabled={!typed}
          onClick={() => set(typed)}
        />
      </Panel>
    </>
  );
}
