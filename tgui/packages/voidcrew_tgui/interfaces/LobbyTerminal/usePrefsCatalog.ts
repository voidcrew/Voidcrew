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

function load(): Promise<ServerData | null> {
  if (!pending) {
    pending = fetchRetry(resolveAsset('preferences.json'))
      .then((response) => response.json())
      .then((data: ServerData) => {
        cached = data;
        return data;
      })
      .catch(() => {
        pending = null;
        return null;
      });
  }
  return pending;
}

/** The catalog, or null until it has arrived. */
export function usePrefsCatalog(): ServerData | null {
  const [catalog, setCatalog] = useState<ServerData | null>(cached);
  useEffect(() => {
    if (catalog) {
      return;
    }
    let live = true;
    load().then((data) => {
      if (live && data) {
        setCatalog(data);
      }
    });
    return () => {
      live = false;
    };
  }, []);
  return catalog;
}
