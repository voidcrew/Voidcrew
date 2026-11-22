/**
 * Colour helpers shared by CHARACTER's colour panel (CharPickers ColourPanel) and SETTINGS:
 * hex parsing, H/S/V conversion, the bar gradients and the viewer's last colours.
 */
// ---------------------------------------------------------------------------
// Colour maths

export type HSV = { h: number; s: number; v: number };

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

export function hexToHsv(hex: string): HSV {
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

export function hsvToHex({ h, s, v }: HSV): string {
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

export function readStored(): string[] {
  try {
    const raw = JSON.parse(window.localStorage.getItem(STORE) || '[]');
    return Array.isArray(raw)
      ? raw.map((c) => parseHex(String(c))).filter((c): c is string => !!c)
      : [];
  } catch {
    return [];
  }
}

export function remember(hex: string) {
  try {
    const next = [hex, ...readStored().filter((c) => c !== hex)].slice(0, KEEP);
    window.localStorage.setItem(STORE, JSON.stringify(next));
  } catch {
    // Storage blocked: the row just shows the file's colours.
  }
}


/** The CSS gradient a bar shows: its channel swept with the other two held. */
export function barGradient(ch: 'h' | 's' | 'v', hsv: HSV): string {
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
