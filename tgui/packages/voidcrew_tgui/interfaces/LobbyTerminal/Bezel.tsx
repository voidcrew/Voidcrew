/**
 * The terminal's bezel: the frame and its top strip around the glass. It covers the whole
 * pane. Class tree from the art's lobby_terminal.css:
 *
 *   .lt-bezel (--s) > .lt-screen, .lt-frame > .lt-strip
 *
 * No keys, no focusables, no game data. Without the art (static.bezel null) the same tree is
 * drawn flat by PLACEHOLDER_CSS.
 */
import type { ReactNode } from 'react';
import { useBackend } from 'tgui/backend';

import type { LobbyData } from './types';

export function Bezel(props: { s: number; children: ReactNode }) {
  const { s, children } = props;
  const { data } = useBackend<LobbyData>();
  const art = !!data.bezel;
  return (
    <div
      className={art ? 'lt-bezel' : 'lt-bezel lt-ph'}
      style={{ ['--s' as string]: s }}
    >
      {!art && <style>{PLACEHOLDER_CSS}</style>}
      <div className="lt-screen">{children}</div>
      <div className="lt-frame">
        <div className="lt-strip" />
      </div>
    </div>
  );
}

/** Stand-in for the art: a flat frame in the bezel's body colour. */
const PLACEHOLDER_CSS = `
.lt-ph.lt-bezel { --s: 1; position: absolute; inset: 0; overflow: hidden; background: #43365a; user-select: none; }
.lt-ph .lt-screen { position: absolute; top: calc(var(--s) * 15px); left: calc(var(--s) * 13px);
  right: calc(var(--s) * 13px); bottom: calc(var(--s) * 3px); overflow: hidden; z-index: 1; }
.lt-ph .lt-frame { position: absolute; top: calc(var(--s) * 12px); left: calc(var(--s) * 10px);
  right: calc(var(--s) * 10px); bottom: 0; box-sizing: border-box;
  border: calc(var(--s) * 3px) solid #33284a; border-bottom: 0; pointer-events: none; z-index: 2; }
.lt-ph .lt-strip { position: absolute; top: calc(var(--s) * -10px); left: calc(50% - var(--s) * 30px);
  width: calc(var(--s) * 61px); height: calc(var(--s) * 6px); background: #241b36; }
`;
