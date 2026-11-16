/**
 * The shared level-2 screens of CHARACTER (design 03 section 4.5): the list picker and the
 * colour panel. Both are laid out in a column (x, w) of the main region: (23, 39) from BODY and
 * KIT, (1, 31) from TRAITS. They fill rows 3.0 to M - 1.25. Escape and [ BACK ] belong to the
 * frame (CharFrame), which closes them.
 *
 * A picker press applies at once and the picker stays open. A colour bar applies when it is let
 * go, a hex on Enter, a chip on a press. Nothing is sent while a bar is dragged.
 */
import { useEffect, useRef, useState } from 'react';

import {
  barGradient,
  type HSV,
  hexToHsv,
  hsvToHex,
  parseHex,
  readStored,
  remember,
} from './ColorEntry';
import {
  Bar,
  Big,
  BODY_Y,
  bodyRows,
  cut,
  Field,
  HRule,
  Key,
  Pager,
  Put,
  Slab,
  Swatch,
  safe,
  useGrid,
  wrapMax,
} from './term';

const q = (v: number) => Math.floor(v * 4) / 4;

export type PickerProps = {
  x: number;
  w: number;
  /** The crumb and the head, e.g. 'HAIR'. */
  label: string;
  choices: string[];
  value: string;
  nameOf: (v: string) => string;
  /** Palette lists: the colour a choice shows. */
  hexOf?: (v: string) => string | null;
  onPick: (v: string) => void;
  onClose: () => void;
};

export type ColourPanelProps = {
  x: number;
  w: number;
  /** 'HAIR COLOUR', 'EYES', 'COLOUR 2'. */
  label: string;
  /** '#rrggbb'. */
  value: string;
  /** Colours on this file; the viewer's last ones are added after them. */
  recent: string[];
  /** Show [ PICKER ] (BYOND's colour dialog). */
  native?: boolean;
  onApply: (hex: string) => void;
  onPicker?: () => void;
  onClose: () => void;
};

/** Rows 3.0 to 4.5: the label, big and white. */
function Head(props: { x: number; label: string; w: number }) {
  const { x, label, w } = props;
  const text = safe(label).toUpperCase();
  return text.length * 1.25 <= w ? (
    <Big x={x} y={3.125} scale={1.25} cls="wht lt-name">
      {text}
    </Big>
  ) : (
    <Put x={x} y={3.25} cls="wht lt-name">
      {cut(text, w)}
    </Put>
  );
}

export function ListPicker(props: PickerProps) {
  const { x, w, label, choices, value, nameOf, hexOf, onPick } = props;
  const { rows: M } = useGrid();
  const wide = w >= 39;
  const [find, setFind] = useState('');
  const findOn = choices.length > 24;

  const shown = (v: string) => safe(nameOf(v));
  const needle = find.trim().toLowerCase();
  const list = needle
    ? choices.filter((v) => shown(v).toLowerCase().includes(needle))
    : choices;

  // Two columns when at most one name in ten is longer than 17 (the full list decides, so
  // typing in FIND never reflows the page).
  const long17 = choices.filter((v) => shown(v).length > 17).length;
  const ncol = wide && long17 * 10 <= choices.length ? 2 : 1;
  const colW = ncol === 2 ? 19 : w;
  const palette = !!hexOf;
  const nameW = (ncol === 2 ? 17 : w - 3) - (palette ? 3 : 0);
  const two = !wide && choices.some((v) => shown(v).length > nameW);
  const rowH = two ? 2.25 : 1.25;

  const fitAll = Math.floor((M - 6.5) / rowH);
  const paged = fitAll * ncol < list.length;
  const perCol = Math.max(1, paged ? Math.floor((M - 7.75) / rowH) : fitAll);
  const per = perCol * ncol;
  const pages = Math.max(1, Math.ceil(list.length / per));
  const pageOf = (v: string) => Math.max(0, Math.floor(list.indexOf(v) / per));
  const [page, setPage] = useState(() => pageOf(value));
  // The open value's page follows it (< and >, or a push from tg's window).
  useEffect(() => {
    if (list.includes(value)) {
      setPage(pageOf(value));
    }
  }, [value]);
  const pg = Math.min(page, pages - 1);
  const slice = list.slice(pg * per, (pg + 1) * per);

  const step = (by: number) => {
    const at = choices.indexOf(value);
    const n = choices.length;
    if (n) {
      onPick(choices[(((at < 0 ? 0 : at + by) % n) + n) % n]);
    }
  };

  return (
    <>
      <Head x={x} label={label} w={findOn ? 13 : w - 7} />
      {!!findOn && (
        <Field
          x={x + (wide ? 14 : 13)}
          y={BODY_Y}
          w={wide ? 14 : 10}
          value={find}
          max={24}
          onChange={(v) => {
            setFind(v);
            setPage(0);
          }}
          onEnter={() => {
            if (list.length === 1) {
              onPick(list[0]);
            }
          }}
        />
      )}
      <Key
        x={x + w - 6}
        y={BODY_Y}
        w={3}
        kind="cap"
        label="<"
        onClick={() => step(-1)}
      />
      <Key
        x={x + w - 3}
        y={BODY_Y}
        w={3}
        kind="cap"
        label=">"
        onClick={() => step(1)}
      />
      <HRule x={x} y={4.75} w={w} />
      {slice.map((v, i) => {
        const col = Math.floor(i / perCol);
        const r = i % perCol;
        const cx = x + col * (colW + 1);
        const cy = 5.25 + r * rowH;
        const on = v === value;
        const hex = hexOf?.(v);
        const nx = cx + 2 + (palette ? 3 : 0);
        const lines = two
          ? wrapMax(shown(v), nameW, 2)
          : [cut(shown(v), nameW)];
        return (
          <Slab
            key={v}
            x={cx}
            y={cy}
            w={colW}
            h={rowH}
            variant="row"
            alt={r % 2 === 1}
            on={on}
            auto={on ? 5 : undefined}
            onClick={() => onPick(v)}
          >
            {!!palette && (
              <Swatch
                x={cx + 2}
                y={cy + (rowH - 1) / 2}
                hex={hex || '#000000'}
              />
            )}
            {lines.map((line, j) => (
              <Put
                key={j}
                x={nx}
                y={cy + (two ? 0.125 + j : (rowH - 1) / 2)}
                cls={on ? 'wht' : ''}
              >
                {line}
              </Put>
            ))}
          </Slab>
        );
      })}
      {!slice.length && (
        <Put x={x + 2} y={5.375} cls="dim">
          {'NO MATCH'}
        </Put>
      )}
      <Pager
        x={x + w}
        y={M - 2.25}
        page={pg + 1}
        pages={pages}
        onPage={(p) => setPage(p - 1)}
        right
      />
    </>
  );
}

const PANEL_CSS = `
.lt-tui .lt-hexbad .lt-field { color: var(--lt-faint); text-shadow: none; }
`;

export function ColourPanel(props: ColourPanelProps) {
  const { x, w, label, value, recent, native, onApply, onPicker } = props;
  const { rows: M } = useGrid();
  const B = bodyRows(M);
  const g = B >= 20 ? 2.25 : 1.75;
  const S = Math.min(8, Math.max(3, q(B - 5.25 - 3 * g)));
  const yb = 5.5 + S;

  const current = parseHex(value) || '#000000';
  const [was] = useState(current);
  const [hsv, setHsv] = useState<HSV>(() => hexToHsv(current));
  const [text, setText] = useState(current.toUpperCase());
  const live = useRef(hsv);
  live.current = hsv;
  const dragging = useRef(false);

  // A push (ours or tg's window) moves the panel unless a bar is held.
  useEffect(() => {
    if (!dragging.current) {
      setHsv(hexToHsv(current));
      setText(current.toUpperCase());
    }
  }, [current]);

  const typed = parseHex(text);
  const draft = typed || hsvToHex(hsv);

  const apply = (hex: string | null) => {
    if (!hex) {
      return;
    }
    remember(hex);
    setHsv(hexToHsv(hex));
    setText(hex.toUpperCase());
    if (hex !== current) {
      onApply(hex);
    }
  };

  const chips = [...recent.map((c) => parseHex(c)), ...readStored()]
    .filter((c, i, all): c is string => !!c && all.indexOf(c) === i)
    .slice(0, Math.min(12, Math.floor((w + 1) / 3)));

  const channels: ['h' | 's' | 'v', string][] = [
    ['h', 'H'],
    ['s', 'S'],
    ['v', 'V'],
  ];

  return (
    <>
      <style>{PANEL_CSS}</style>
      <Head x={x} label={label} w={w} />
      <HRule x={x} y={4.75} w={w} />
      <Swatch x={x} y={5.25} w={12} h={S} hex={draft} />
      <div className={typed ? undefined : 'lt-hexbad'}>
        <Field
          x={x + 14}
          y={5.25}
          w={9}
          value={text}
          max={7}
          onChange={(v) => {
            setText(v);
            const hex = parseHex(v);
            if (hex) {
              setHsv(hexToHsv(hex));
            }
          }}
          onEnter={() => apply(typed)}
        />
      </div>
      <Put x={x + 14} y={7} cls="dim">
        {'WAS'}
      </Put>
      <Swatch x={x + 18} y={7} w={4} hex={was} onClick={() => apply(was)} />
      {channels.map(([c, name], i) => {
        const by = yb + i * g;
        const bh = g - 0.75;
        const t = c === 'h' ? hsv.h / 360 : hsv[c];
        const at = (v: number): HSV => ({
          ...live.current,
          [c]: c === 'h' ? v * 359.9 : v,
        });
        return (
          <span key={c}>
            <Put x={x} y={by + (bh - 1) / 2} cls="dim">
              {name}
            </Put>
            <Bar
              x={x + 2}
              y={by}
              w={w - 2}
              h={bh}
              value={t}
              gradient={barGradient(c, hsv)}
              step={c === 'h' ? 1 / 72 : 1 / 40}
              auto={c === 'h' ? 5 : undefined}
              onChange={(v) => {
                dragging.current = true;
                const next = at(v);
                live.current = next;
                setHsv(next);
                setText(hsvToHex(next).toUpperCase());
              }}
              onRelease={() => {
                dragging.current = false;
                apply(hsvToHex(live.current));
              }}
            />
          </span>
        );
      })}
      {chips.map((c, i) => (
        <Swatch
          key={c}
          x={x + i * 3}
          y={yb + 3 * g}
          hex={c}
          sel={c === current}
          onClick={() => apply(c)}
        />
      ))}
      {!!native && !!onPicker && (
        <Key
          x={x}
          y={yb + 3 * g + 1.25}
          w={12}
          kind="cap"
          label="[ PICKER ]"
          onClick={onPicker}
        />
      )}
    </>
  );
}
