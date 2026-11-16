/**
 * SETTINGS, KEYS group: tg's keybindings page (PreferencesMenu KeybindingsPage) in the terminal.
 *
 * Categories, names and descriptions come from tg's keybindings.json asset (settings_keys_open
 * sends it); the player's bindings from the server's settings_keys block
 * (lobby_settings_keys.dm). Every write goes through tg's keybindings middleware.
 *
 * A row shows the keybinding's keys in the value zone, cut with the mark when they don't fit.
 * Enter or a click opens the keybinding at level 2: its three slots as blocks (each key whole up
 * to the block's width), CLEAR for the selected slot, RESET (tg's "Reset to Defaults") and
 * RESET ALL behind a confirm.
 *
 * Rebinding: pressing a slot listens. The next key, with its modifiers, is the binding, in tg's
 * own format (formatKeyboardEvent below, copied from tg; it is not exported). A modifier alone
 * binds on its key-up, as in tg. Escape cancels (tg clears the slot instead). While listening
 * the page takes every key and mouse press first: the terminal's navigation is locked (lockNav),
 * and capture listeners on window stop the keys before tgui-core passes them on to BYOND.
 */
import { useEffect, useRef, useState } from 'react';
import { resolveAsset } from 'tgui/assets';
import { useBackend } from 'tgui/backend';
import { fetchRetry } from 'tgui-core/http';
import { isEscape, KEY } from 'tgui-core/keys';

import { quietDialogClose, sfx, useBlink } from './motion';
import { lockNav, useBack } from './nav';
import {
  byName,
  DESC_W,
  NAME_X,
  type SettingsCat,
  SettingsColumns,
  type SettingsRowSpec,
  useSettings,
  VALUE_W,
  VALUE_X,
  WORK_W,
  WORK_X,
} from './SettingsFrame';
import {
  BODY_Y,
  Big,
  Btn,
  Dialog,
  HRule,
  Put,
  Slab,
  cut,
  safe,
  useGrid,
  wrapMax,
} from './term';
import type { LobbyKeysData, SettingsKeysBlock } from './types';

// ---------------------------------------------------------------------------
// tg's keybindings.json catalog

type KeybindInfo = { name: string; description?: string };
/** category -> keybind_name -> its name and description. */
type KeysCatalog = Record<string, Record<string, KeybindInfo>>;

let cached: KeysCatalog | null = null;
let pending: Promise<void> | null = null;
const listeners = new Set<() => void>();

/** The asset can arrive after the first fetch (settings_keys_open sends it): retry until it does. */
function attempt(tries: number): Promise<void> {
  return fetchRetry(resolveAsset('keybindings.json'))
    .then((response) => {
      if (!response.ok) {
        throw new Error(`keybindings.json: ${response.status}`);
      }
      return response.json();
    })
    .then((data: KeysCatalog) => {
      cached = data && typeof data === 'object' ? data : {};
      for (const fn of listeners) {
        fn();
      }
    })
    .catch(
      () =>
        new Promise<void>((resolve) =>
          setTimeout(
            () => resolve(attempt(tries + 1)),
            tries < 20 ? 1500 : 5000,
          ),
        ),
    );
}

/** The catalog, or null until it has arrived. Fetched once per window. */
function useKeysCatalog(): KeysCatalog | null {
  const [, setTick] = useState(0);
  useEffect(() => {
    const fn = () => setTick((t) => t + 1);
    listeners.add(fn);
    if (!cached && !pending) {
      pending = attempt(0);
    }
    return () => {
      listeners.delete(fn);
    };
  }, []);
  return cached;
}

/** tg's order: categories by name, EMOTE and then ADMIN moved to the bottom; empty ones dropped. */
function keyCats(catalog: KeysCatalog): SettingsCat[] {
  const ids = Object.keys(catalog)
    .filter((id) => Object.keys(catalog[id] || {}).length > 0)
    .sort(byName);
  for (const last of ['EMOTE', 'ADMIN']) {
    const at = ids.indexOf(last);
    if (at >= 0) {
      ids.push(ids.splice(at, 1)[0]);
    }
  }
  return ids.map((id) => ({ id, label: cut(upper(id), 13) }));
}

function infoOf(catalog: KeysCatalog | null, id: string): KeybindInfo | null {
  if (!catalog) {
    return null;
  }
  for (const cat of Object.keys(catalog)) {
    const info = catalog[cat]?.[id];
    if (info) {
      return info;
    }
  }
  return null;
}

function bindsOf(block: SettingsKeysBlock | undefined, id: string): string[] {
  const keys = block?.binds && !Array.isArray(block.binds) && block.binds[id];
  return Array.isArray(keys) ? keys.filter((k) => k && k !== 'Unbound') : [];
}

const upper = (s: string) => safe(s).toUpperCase();

/** An empty slot. */
const EMPTY = '---';
/** tg's MAX_HOTKEY_SLOTS. */
const SLOTS = 3;

// ---------------------------------------------------------------------------
// Key capture, as tg's KeybindingsPage formats it

function isStandardKey(event: KeyboardEvent): boolean {
  return (
    event.key !== KEY.Alt &&
    event.key !== KEY.Control &&
    event.key !== KEY.Shift &&
    !isEscape(event.key)
  );
}

const KEY_CODE_TO_BYOND: Record<string, string> = {
  // The names today's browser control reports. tg's table has only the old ones, so an arrow
  // or Delete would be stored under a name the game never matches a key press to.
  ARROWDOWN: 'South',
  ARROWLEFT: 'West',
  ARROWRIGHT: 'East',
  ARROWUP: 'North',
  DELETE: 'Delete',
  DEL: 'Delete',
  DOWN: 'South',
  END: 'Southwest',
  HOME: 'Northwest',
  INSERT: 'Insert',
  LEFT: 'West',
  PAGEDOWN: 'Southeast',
  PAGEUP: 'Northeast',
  RIGHT: 'East',
  ' ': 'Space',
  UP: 'North',
};

/** KeyboardEvent.DOM_KEY_LOCATION_NUMPAD (tg spells it out for IE 11). */
const DOM_KEY_LOCATION_NUMPAD = 3;

function formatKeyboardEvent(event: KeyboardEvent): string {
  let text = '';
  if (event.altKey) {
    text += 'Alt';
  }
  if (event.ctrlKey) {
    text += 'Ctrl';
  }
  if (event.shiftKey) {
    text += 'Shift';
  }
  if (event.location === DOM_KEY_LOCATION_NUMPAD) {
    text += 'Numpad';
  }
  if (isStandardKey(event)) {
    const key = event.key.toUpperCase();
    text += KEY_CODE_TO_BYOND[key] || key;
  }
  return text;
}

/** Takes the one event and stops it everywhere: the terminal, tgui-core's pass-through, the browser. */
function swallow(e: Event) {
  e.preventDefault();
  e.stopPropagation();
  e.stopImmediatePropagation();
}

/** Swallows the next event of that type (and key code) on window, once, within 3 s (tg's cancelNextKeyUp). */
function swallowNext(type: 'keyup' | 'click', code?: number) {
  const fn = (e: Event) => {
    if (code !== undefined && (e as KeyboardEvent).keyCode !== code) {
      return;
    }
    swallow(e);
    stop();
  };
  const stop = () => window.removeEventListener(type, fn, true);
  window.addEventListener(type, fn, true);
  setTimeout(stop, 3000);
}

/**
 * While `on`: every key and mouse press goes here first. onHeld(text) shows modifiers held so far;
 * onDone(text) ends it with the binding, or null when cancelled (Escape, or a mouse press anywhere).
 */
function useKeyCapture(
  on: boolean,
  onHeld: (text: string) => void,
  onDone: (text: string | null) => void,
) {
  const cb = useRef({ onHeld, onDone });
  cb.current = { onHeld, onDone };
  useEffect(() => {
    if (!on) {
      return;
    }
    let last: KeyboardEvent | null = null;
    let over = false;
    lockNav(true);
    const done = (text: string | null) => {
      if (over) {
        return;
      }
      over = true;
      lockNav(false);
      cb.current.onDone(text);
    };
    const down = (e: KeyboardEvent) => {
      swallow(e);
      if (over || e.repeat) {
        return;
      }
      swallowNext('keyup', e.keyCode);
      if (isEscape(e.key)) {
        done(null);
      } else if (isStandardKey(e)) {
        done(formatKeyboardEvent(e));
      } else {
        last = e;
        cb.current.onHeld(formatKeyboardEvent(e));
      }
    };
    const up = (e: KeyboardEvent) => {
      swallow(e);
      if (last) {
        done(formatKeyboardEvent(last));
      }
    };
    const press = (e: MouseEvent) => {
      swallow(e);
      // The click that follows this press must not start listening again.
      swallowNext('click');
      done(null);
    };
    const keyTypes = ['keydown', 'keyup', 'keypress'] as const;
    const mouseTypes = ['mousedown', 'mouseup', 'click', 'mouseover'] as const;
    const onKeyEvent = (e: Event) => {
      if (e.type === 'keydown') {
        down(e as KeyboardEvent);
      } else if (e.type === 'keyup') {
        up(e as KeyboardEvent);
      } else {
        swallow(e);
      }
    };
    const onMouseEvent = (e: Event) => {
      if (e.type === 'mousedown') {
        press(e as MouseEvent);
      } else {
        swallow(e);
      }
    };
    for (const t of keyTypes) {
      window.addEventListener(t, onKeyEvent, true);
    }
    for (const t of mouseTypes) {
      window.addEventListener(t, onMouseEvent, true);
    }
    return () => {
      for (const t of keyTypes) {
        window.removeEventListener(t, onKeyEvent, true);
      }
      for (const t of mouseTypes) {
        window.removeEventListener(t, onMouseEvent, true);
      }
      lockNav(false);
    };
  }, [on]);
}

// ---------------------------------------------------------------------------
// Level 2: one keybinding

const SLOT_Y = 5.5;
const SLOT_H = 1.5;
const SLOT_PITCH = 1.75;
/** The key's text in a slot: from WORK_X + 4, this wide. */
const SLOT_TEXT_X = WORK_X + 4;
const SLOT_TEXT_W = WORK_W - 5;
const BTN_Y = SLOT_Y + SLOTS * SLOT_PITCH + 0.5;

/** The keybinding's name over the slots: 1.25x when it fits, else normal size, cut. */
function Head(props: { text: string }) {
  const { text } = props;
  return text.length * 1.25 <= WORK_W ? (
    <Big x={WORK_X} y={3.125} scale={1.25} cls="wht lt-name">
      {text}
    </Big>
  ) : (
    <Put x={WORK_X} y={3.25} cls="wht lt-name">
      {cut(text, WORK_W)}
    </Put>
  );
}

/** RESET ALL, asked in the terminal's dialog with KEEP focused. */
function ResetAllConfirm(props: { onClose: () => void; onReset: () => void }) {
  const { onClose, onReset } = props;
  const { cols } = useGrid();
  useBack(onClose);
  const w = 39;
  const x = Math.floor((cols - w) / 2);
  const y = BODY_Y + 2;
  return (
    <>
      <div
        className="lt-dimsheet"
        onClick={(e) => {
          e.stopPropagation();
          onClose();
        }}
      />
      <Dialog w={w} h={6} caption="RESET ALL">
        <Put x={x + 2} y={y + 1} cls="wht">
          PUT EVERY KEY BACK TO ITS DEFAULT?
        </Put>
        <Btn x={x + 2} y={y + 3} label="KEEP" lit auto={9} onClick={onClose} />
        <Btn
          x={x + w - 2}
          y={y + 3}
          label="RESET ALL"
          right
          onClick={() => {
            quietDialogClose();
            onClose();
            onReset();
          }}
        />
      </Dialog>
    </>
  );
}

function KeyEdit(props: { id: string }) {
  const { id } = props;
  const { act, data } = useBackend<LobbyKeysData>();
  const catalog = useKeysCatalog();
  const { closeSub } = useSettings();
  const { rows: M } = useGrid();
  const info = infoOf(catalog, id);
  const block = data.settings_keys;
  const rev = block?.rev ?? 0;
  // The keys just sent, shown until the server's next push (which snaps a refused one back).
  const [sent, setSent] = useState<{ rev: number; keys: string[] } | null>(
    null,
  );
  const keys = sent && sent.rev === rev ? sent.keys : bindsOf(block, id);
  const [sel, setSel] = useState(0);
  const [listen, setListen] = useState<number | null>(null);
  const [held, setHeld] = useState('');
  const [asking, setAsking] = useState(false);
  const lit = useBlink(listen !== null && !held, 450);

  const gone = !!catalog && !info;
  useEffect(() => {
    if (gone) {
      closeSub();
    }
  }, [gone]);

  const send = (next: string[]) => {
    setSent({ rev, keys: next });
    act('settings_keys_set', { keybind_name: id, hotkeys: next });
  };

  useKeyCapture(listen !== null, setHeld, (text) => {
    const slot = listen;
    setListen(null);
    setHeld('');
    if (text === null || slot === null) {
      return;
    }
    // A key this keybinding already has (in this slot or another) changes nothing.
    if (keys.includes(text)) {
      return;
    }
    // tg's rule: a slot past the last bound key fills the next free one.
    const next = [...keys];
    next[Math.min(next.length, slot)] = text;
    sfx('slot');
    send(next.slice(0, SLOTS));
  });

  if (!info) {
    return null;
  }
  const desc = upper(info.description || '');
  const descLines = desc ? wrapMax(desc, DESC_W, 2) : [];
  const selKey = keys[sel];

  return (
    <>
      <Head text={upper(info.name)} />
      <HRule x={WORK_X} y={4.75} w={WORK_W} />
      {Array.from({ length: SLOTS }, (_, i) => {
        const y = SLOT_Y + i * SLOT_PITCH;
        const ty = y + 0.25;
        const key = keys[i];
        const listening = listen === i;
        let text: string;
        let cls: string;
        if (listening) {
          text = held ? upper(held) : 'PRESS A KEY';
          cls = held || lit ? 'wht' : 'faint';
        } else if (key) {
          text = cut(upper(key), SLOT_TEXT_W);
          cls = sel === i ? 'wht' : '';
        } else {
          text = EMPTY;
          cls = 'faint';
        }
        return (
          <Slab
            key={i}
            x={WORK_X}
            y={y}
            w={WORK_W}
            h={SLOT_H}
            variant="block"
            on={sel === i || listening}
            auto={i === 0 ? 5 : undefined}
            onFocus={(on) => {
              if (on) {
                setSel(i);
              }
            }}
            onClick={() => {
              setSel(i);
              setHeld('');
              setListen(i);
            }}
          >
            <Put x={WORK_X + 1} y={ty} cls="dim">
              {String(i + 1)}
            </Put>
            <Put x={SLOT_TEXT_X} y={ty} cls={cls} pulse={key}>
              {cut(text, SLOT_TEXT_W)}
            </Put>
          </Slab>
        );
      })}
      <Btn
        x={WORK_X}
        y={BTN_Y}
        label="CLEAR"
        disabled={!selKey || listen !== null}
        onClick={() => {
          if (selKey) {
            const next = [...keys];
            next.splice(sel, 1);
            send(next);
          }
        }}
      />
      <Btn
        x={WORK_X + 11}
        y={BTN_Y}
        label="RESET"
        disabled={listen !== null}
        onClick={() => {
          setSent(null);
          act('settings_keys_reset', { keybind_name: id });
        }}
      />
      <Btn
        x={WORK_X + WORK_W}
        y={BTN_Y}
        label="RESET ALL"
        right
        disabled={listen !== null}
        onClick={() => setAsking(true)}
      />
      {descLines.map((line, i) => (
        <Put key={i} x={NAME_X} y={M - 3.25 + i} cls="dim">
          {line}
        </Put>
      ))}
      {!!asking && (
        <ResetAllConfirm
          onClose={() => setAsking(false)}
          onReset={() => {
            setSent(null);
            act('settings_keys_reset_all');
          }}
        />
      )}
    </>
  );
}

// ---------------------------------------------------------------------------
// The KEYS group

export function SettingsKeys() {
  const { act, data } = useBackend<LobbyKeysData>();
  const catalog = useKeysCatalog();
  const { sub, from, setCrumb } = useSettings();
  const [open, setOpen] = useState<string | null>(null);
  const block = data.settings_keys;

  useEffect(() => {
    act('settings_keys_open');
    return () => act('settings_keys_close');
  }, []);

  const cats = catalog ? keyCats(catalog) : [];
  const cat = cats.some((c) => c.id === open) ? open : cats[0]?.id || null;
  useEffect(() => {
    setCrumb(cat ? cut(upper(cat), 13) : '');
  }, [cat]);

  const rows: SettingsRowSpec[] =
    catalog && cat && block
      ? Object.entries(catalog[cat] || {})
          .sort((a, b) => byName(a[1].name, b[1].name))
          .map(([id, info]) => {
            const NAME = upper(info.name || id);
            const keys = bindsOf(block, id);
            const all = keys.map(upper).join(' ');
            return {
              key: id,
              name: NAME,
              // Keys too long for the row are cut there; the strip then shows them whole.
              desc: all.length > VALUE_W ? all : info.description || '',
              onPress: () => sub(<KeyEdit id={id} />, NAME, id),
              value: (ty: number, focused: boolean) => (
                <Put
                  x={VALUE_X}
                  y={ty}
                  cls={keys.length ? (focused ? 'wht' : '') : 'faint'}
                  pulse={keys.join(' ')}
                >
                  {keys.length ? cut(all, VALUE_W) : EMPTY}
                </Put>
              ),
            };
          })
      : [];

  return (
    <SettingsColumns
      cats={cats}
      cat={cat}
      onCat={setOpen}
      rows={rows}
      focusKey={from}
      empty={catalog && block ? undefined : 'FETCHING KEYS.'}
    />
  );
}
