/**
 * The terminal's bezel: frame, top strip, deck with the big keys, grille and the tray of
 * small lobby buttons. Class tree from the art's lobby_terminal.css:
 *
 *   .lt-bezel (--s) > .lt-screen, .lt-frame > .lt-strip, .lt-deck > .lt-deck-row >
 *     .lt-keys > .lt-key..., .lt-grille-slot > .lt-grille, .lt-tray > .lt-sbtn...
 *
 * Without the art (static.bezel null) the same tree is drawn by PLACEHOLDER_CSS.
 */
import { type ReactNode, useState } from 'react';
import { useBackend } from 'tgui/backend';

import type { LobbyData } from './types';

type KeyId = 'join' | 'ready' | 'notready' | 'observe' | 'character' | 'start';

const KEY_LABEL: Record<KeyId, string> = {
  join: 'JOIN',
  ready: 'READY',
  notready: 'READY',
  observe: 'OBSERVE',
  character: 'CHARACTER',
  start: 'START',
};

function Key(props: {
  id: KeyId;
  disabled?: boolean;
  title: string;
  onClick: () => void;
}) {
  const { id, disabled, title, onClick } = props;
  return (
    <button
      type="button"
      className={`lt-key lt-key--${id}${disabled ? ' is-disabled' : ''}`}
      disabled={disabled}
      title={title}
      onClick={disabled ? undefined : onClick}
    >
      <span className="lt-key-legend">{KEY_LABEL[id]}</span>
    </button>
  );
}

type SmallId = 'wiki' | 'poll' | 'crew_manifest' | 'settings' | 'changelog';

function SmallButton(props: {
  id: SmallId;
  title: string;
  disabled?: boolean;
  mark?: boolean;
  onClick: () => void;
}) {
  const { id, title, disabled, mark, onClick } = props;
  const [hover, setHover] = useState(false);
  const state = disabled ? '_disabled' : hover ? '_highlighted' : '';
  return (
    <button
      type="button"
      className={`lt-sbtn${disabled ? ' is-disabled' : ''}`}
      title={title}
      disabled={disabled}
      onClick={disabled ? undefined : onClick}
      onMouseEnter={() => setHover(true)}
      onMouseLeave={() => setHover(false)}
    >
      <span className={`lt-sbtn-icon lobbyterminal24x24 lt-${id}${state}`} />
      {!!mark && (
        <span className="lt-sbtn-mark lobbyterminal24x26 lt-new_poll" />
      )}
    </button>
  );
}

export function Bezel(props: { s: number; children: ReactNode }) {
  const { s, children } = props;
  const { data, act } = useBackend<LobbyData>();
  const art = !!data.bezel;
  const preRound = data.phase === 'loading' || data.phase === 'pregame';
  const ready = !!data.ready;
  const showReady = preRound || data.phase === 'setup';

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
      <div className="lt-deck">
        <div className="lt-deck-row">
          <div className="lt-keys">
            {showReady ? (
              <>
                <Key
                  id={ready ? 'ready' : 'notready'}
                  disabled={!preRound}
                  title={ready ? 'Ready' : 'Not ready'}
                  onClick={() => act('ready')}
                />
                <span
                  className={`lt-lamp lt-lamp--${ready ? 'ready' : 'notready'}`}
                />
              </>
            ) : (
              <Key
                id="join"
                disabled={data.phase !== 'playing'}
                title="Join"
                onClick={() => act('join')}
              />
            )}
            <Key
              id="observe"
              disabled={!data.can_observe}
              title="Observe"
              onClick={() => act('observe')}
            />
            <Key
              id="character"
              disabled={!data.prefs_ready}
              title="Character"
              onClick={() => act('character')}
            />
            {data.localhost_admin && preRound ? (
              <Key
                id="start"
                title="Start now"
                onClick={() => act('start_now')}
              />
            ) : null}
          </div>
          <div className="lt-grille-slot">
            <div className="lt-grille" />
          </div>
          <div className="lt-tray">
            <SmallButton
              id="wiki"
              title="Wiki"
              disabled={!data.wiki}
              onClick={() => act('wiki')}
            />
            <SmallButton
              id="poll"
              title="Polls"
              disabled={!data.polls}
              mark={data.polls === 2}
              onClick={() => act('polls')}
            />
            <SmallButton
              id="crew_manifest"
              title="Crew manifest"
              onClick={() => act('manifest')}
            />
            <SmallButton
              id="settings"
              title="Settings"
              disabled={!data.prefs_ready}
              onClick={() => act('settings')}
            />
            <SmallButton
              id="changelog"
              title="Changelog"
              onClick={() => act('changelog')}
            />
          </div>
        </div>
      </div>
    </div>
  );
}

/**
 * Keycap legends are baked into the art; only the placeholder (and the START key, which has
 * no art) shows the text legend.
 */
const LEGEND_CSS = `
.lt-key-legend { display: none; }
.lt-key--start { width: calc(var(--s) * 52px); height: calc(var(--s) * 34px); position: relative;
  background: #9aa39f; box-shadow: inset 0 0 0 calc(var(--s) * 2px) #20202a; }
.lt-key--start .lt-key-legend, .lt-ph .lt-key-legend { display: block; position: absolute;
  left: calc(var(--s) * 6px); right: calc(var(--s) * 6px); top: calc(var(--s) * 9px); height: calc(var(--s) * 13px);
  background: #36373a; color: #7effbf; font-family: 'VCR', monospace; font-size: calc(var(--s) * 9px);
  line-height: calc(var(--s) * 13px); text-align: center; letter-spacing: calc(var(--s) * 1px); }
.lt-key--start:hover .lt-key-legend { color: #ffc41f; }
.lt-key-legend { pointer-events: none; }
`;

export const BEZEL_EXTRA_CSS = LEGEND_CSS;

/** Stand-in for the art: the same layout in flat lobby colours. */
const PLACEHOLDER_CSS = `
.lt-ph.lt-bezel { --s: 1; position: absolute; inset: 0; overflow: hidden; background: #9aa39f; user-select: none; }
.lt-ph .lt-screen { position: absolute; top: calc(var(--s) * 15px); left: calc(var(--s) * 13px);
  right: calc(var(--s) * 13px); bottom: calc(var(--s) * 52px); overflow: hidden; z-index: 1; }
.lt-ph .lt-frame { position: absolute; top: calc(var(--s) * 12px); left: calc(var(--s) * 10px);
  right: calc(var(--s) * 10px); bottom: calc(var(--s) * 49px); box-sizing: border-box;
  border: calc(var(--s) * 3px) solid #51575e; border-bottom-color: #e0e3dc; border-right-color: #e0e3dc;
  pointer-events: none; z-index: 2; }
.lt-ph .lt-strip { position: absolute; top: calc(var(--s) * -10px); left: calc(50% - var(--s) * 30px);
  width: calc(var(--s) * 61px); height: calc(var(--s) * 6px); background: #36373a; }
.lt-ph .lt-deck { position: absolute; left: 0; right: 0; bottom: 0; height: calc(var(--s) * 49px); z-index: 2;
  border-top: calc(var(--s) * 2px) solid #e0e3dc; box-sizing: border-box; }
.lt-ph .lt-deck-row { position: absolute; top: calc(var(--s) * 6px); left: calc(var(--s) * 30px);
  right: calc(var(--s) * 29px); display: flex; align-items: flex-start; }
.lt-ph .lt-keys { display: flex; align-items: flex-start; flex: none; }
.lt-ph .lt-key { display: block; flex: none; margin: 0; padding: 0; border: 0; outline: 0; position: relative;
  height: calc(var(--s) * 34px); background: #bec4bf; box-shadow: inset 0 0 0 calc(var(--s) * 2px) #20202a; cursor: pointer; }
.lt-ph .lt-key + .lt-key { margin-left: calc(var(--s) * 4px); }
.lt-ph .lt-key--join, .lt-ph .lt-key--ready, .lt-ph .lt-key--notready { width: calc(var(--s) * 68px); }
.lt-ph .lt-key--observe { width: calc(var(--s) * 84px); }
.lt-ph .lt-key--character { width: calc(var(--s) * 100px); }
.lt-ph .lt-key:hover { background: #e0e3dc; }
.lt-ph .lt-key:active { background: #9aa39f; }
.lt-ph .lt-key.is-disabled { cursor: default; background: #9aa39f; }
.lt-ph .lt-key.is-disabled .lt-key-legend { color: #33676a; }
.lt-ph .lt-key--notready .lt-key-legend { color: #ff4f6a; }
.lt-ph .lt-lamp { flex: none; width: calc(var(--s) * 10px); height: calc(var(--s) * 9px);
  margin: calc(var(--s) * 11px) calc(var(--s) * 1px) 0 calc(var(--s) * 2px); background: #20202a; }
.lt-ph .lt-lamp + .lt-key { margin-left: 0; }
.lt-ph .lt-lamp--ready { background: #7effbf; }
.lt-ph .lt-lamp--notready { background: #ff4f6a; }
.lt-ph .lt-grille-slot { flex: 1 1 0; min-width: 0; }
.lt-ph .lt-tray { flex: none; position: relative; display: flex; margin-top: calc(var(--s) * 1px);
  padding: calc(var(--s) * 3px); width: calc(var(--s) * 142px); height: calc(var(--s) * 31px);
  box-sizing: border-box; background: #36373a; }
.lt-ph .lt-sbtn { position: relative; flex: none; margin: 0; padding: 0; border: 0; background: none;
  width: calc(var(--s) * 24px); height: calc(var(--s) * 24px); cursor: pointer; }
.lt-ph .lt-sbtn + .lt-sbtn { margin-left: calc(var(--s) * 4px); }
.lt-ph .lt-sbtn-icon, .lt-ph .lt-sbtn-mark { position: absolute; left: 0; top: 0;
  transform: scale(var(--s)); transform-origin: 0 0; pointer-events: none; image-rendering: pixelated; }
.lt-ph .lt-sbtn-mark { top: calc(var(--s) * -1px); }
`;
