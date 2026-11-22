/**
 * tg's preferences.json catalog (choices, display names, quirk_info, loadout_tabs, species)
 * for the CHARACTER tab. The server sends the asset on char_open; it is fetched once per
 * window and shared by every editor. Owner: C3.
 */
import { useEffect, useState } from 'react';
import { resolveAsset } from 'tgui/assets';
import type { ServerData } from 'tgui/interfaces/PreferencesMenu/types';
import { fetchRetry } from 'tgui-core/http';

let cached: ServerData | null = null;
let pending: Promise<ServerData | null> | null = null;

/** Tries this many times, a second and a half apart: the asset can arrive after the first fetch (char_open sends it). */
const TRIES = 20;
const RETRY_MS = 1500;

function attempt(left: number): Promise<ServerData | null> {
  return fetchRetry(resolveAsset('preferences.json'))
    .then((response) => {
      if (!response.ok) {
        throw new Error(`preferences.json: ${response.status}`);
      }
      return response.json();
    })
    .then((data: ServerData) => {
      cached = data;
      return data;
    })
    .catch(() =>
      left > 1
        ? new Promise<ServerData | null>((resolve) =>
            setTimeout(() => resolve(attempt(left - 1)), RETRY_MS),
          )
        : null,
    );
}

/** TRUE after a whole round of tries came back empty (20 tries, 30 s). */
let failed = false;
const listeners = new Set<() => void>();
const tell = () => {
  for (const fn of listeners) {
    fn();
  }
};

function load(): Promise<ServerData | null> {
  if (!pending) {
    failed = false;
    pending = attempt(TRIES).then((data) => {
      if (!data) {
        pending = null; // the next mount or retry tries again
        failed = true;
      }
      tell();
      return data;
    });
  }
  return pending;
}

/** The catalog, or null until it has arrived. */
export function usePrefsCatalog(): ServerData | null {
  return usePrefsCatalogState().cat;
}

/** The catalog with its failure state: failed after 20 tries; retry() starts a new round. */
export function usePrefsCatalogState(): {
  cat: ServerData | null;
  failed: boolean;
  retry: () => void;
} {
  const [, setTick] = useState(0);
  useEffect(() => {
    const fn = () => setTick((t) => t + 1);
    listeners.add(fn);
    if (!cached) {
      load();
    }
    return () => {
      listeners.delete(fn);
    };
  }, []);
  return {
    cat: cached,
    failed: !cached && failed,
    retry: () => {
      if (!cached && !pending) {
        load();
        tell();
      }
    },
  };
}

// ---------------------------------------------------------------------------
// Reading the catalog. Shared by the file view and the BODY editor.

type Choiced = {
  choices?: string[];
  display_names?: Record<string, string>;
  to_hex?: Record<string, { value: string }>;
};

/** A preference's constant data (choices, display names), or null. */
function entry(cat: ServerData | null, key: string): Choiced | null {
  const e = cat?.[key];
  return e && typeof e === 'object' ? (e as Choiced) : null;
}

/** The values a choiced preference takes, in the server's order; null when unknown. */
export function choicesOf(
  cat: ServerData | null,
  key: string,
): string[] | null {
  if (key === 'species' && cat?.species) {
    const listed = entry(cat, key)?.choices;
    return listed?.length ? listed : Object.keys(cat.species);
  }
  const list = entry(cat, key)?.choices;
  return Array.isArray(list) && list.length ? list : null;
}

/** What the player reads for a value. */
export function nameOf(cat: ServerData | null, key: string, value: unknown) {
  const v = String(value ?? '');
  if (key === 'species') {
    return cat?.species?.[v]?.name || v;
  }
  if (key === 'gender') {
    return PRONOUNS[v] || v;
  }
  return entry(cat, key)?.display_names?.[v] || v;
}

/** The next or previous choice, wrapping. */
export function stepChoice(list: string[], value: unknown, by: number) {
  const i = list.indexOf(String(value));
  const n = list.length;
  return list[(((i < 0 ? 0 : i + by) % n) + n) % n];
}

/** gender values (MALE, FEMALE, PLURAL, NEUTER) as pronouns. */
export const PRONOUNS: Record<string, string> = {
  male: 'He/Him',
  female: 'She/Her',
  plural: 'They/Them',
  neuter: 'It/Its',
};

/** GLOB.color_list_ethereal (code/_globalvars/lists/flavor_misc.dm); the catalog sends icons only. */
export const ETHEREAL_HEX: Record<string, string> = {
  Blue: '#3399ff',
  'Bright Yellow': '#ffff99',
  'Burnt Orange': '#cc4400',
  'Cyan Blue': '#00ffff',
  'Dark Blue': '#6666ff',
  'Dark Fuschia': '#cc0066',
  'Dark Green': '#37835b',
  'Dark Red': '#9c3030',
  'Dull Yellow': '#fbdf56',
  'Faint Blue': '#b3d9ff',
  'Faint Green': '#ddff99',
  'Faint Red': '#ffb3b3',
  Green: '#97ee63',
  Orange: '#ffa64d',
  Pink: '#ff99cc',
  Purple: '#ee82ee',
  Red: '#ff4d4d',
  'Seafoam Green': '#00fa9a',
  White: '#f2f2f2',
};

/** The colour a named-colour preference shows (skin_tone, feature_ethcolor), or null. */
export function namedHex(cat: ServerData | null, key: string, value: unknown) {
  const v = String(value ?? '');
  if (key === 'feature_ethcolor') {
    return ETHEREAL_HEX[v] || null;
  }
  return entry(cat, key)?.to_hex?.[v]?.value || null;
}

/** A stored kit name (html_encoded by the server) as plain text, for React text only. */
export function decodeName(text: string): string {
  return text
    .replace(/&#(\d+);/g, (_, n) => String.fromCharCode(Number(n)))
    .replace(/&#x([0-9a-f]+);/gi, (_, n) =>
      String.fromCharCode(parseInt(n, 16)),
    )
    .replace(/&quot;/g, '"')
    .replace(/&lt;/g, '<')
    .replace(/&gt;/g, '>')
    .replace(/&amp;/g, '&');
}

/** A voice pack's name without its group ("Goonstation: Bottalk 1" -> "Bottalk 1"). */
export function voiceShort(name: string): string {
  return name.split(': ').pop() || name;
}

/** Loadout item name by typepath. */
export function kitName(cat: ServerData | null, path: string) {
  for (const tab of cat?.loadout?.loadout_tabs || []) {
    const item = tab.contents.find((it) => it.path === path);
    if (item) {
      return item.name;
    }
  }
  return path.split('/').pop() || path;
}

/** quirk_info entry for a taken quirk key. */
export function quirkOf(cat: ServerData | null, key: string) {
  return cat?.quirks?.quirk_info?.[key] || null;
}
