/**
 * Dock terminal lobby. Rendered into the `lobby_browser` control over the map pane, not
 * a popup window.
 *
 * Never wrap this in <Window>: Window winsets size and position on Byond.windowId, which
 * here is the skin control, and would wreck the map pane. The root is a bare full-viewport
 * div that follows the control's size.
 *
 * UI-local state (tab, selections, pages, fits) lives in React; only actions round-trip.
 */
import { Fragment, useEffect, useMemo, useRef, useState } from 'react';
import { resolveAsset } from 'tgui/assets';
import { useBackend } from 'tgui/backend';

import { Bezel } from './Bezel';
import { Boot } from './Boot';
import { CharacterTab } from './CharacterTab';
import { CrewsTab } from './CrewsTab';
import { HeaderBand, TABS, TabRow } from './Header';
import { HousingTab } from './HousingTab';
import { computeLayout, regions } from './layout';
import { KeyBar, MenuPopup, SideMenu } from './Menu';
import { Confirmed, NoticeLine } from './Notice';
import { NAV_CSS, NavProvider, useBack } from './nav';
import { ObserveConfirm } from './ObserveConfirm';
import { type Grid, GridContext, Region, STARS, TERM_CSS } from './term';
import type { LobbyData, TabId } from './types';
import { YardTab } from './YardTab';

const FONT = 'VCR';
/** Advance of one character at 1px, for when the font hasn't loaded yet. */
const FALLBACK_ADVANCE = 0.6;

function usePaneSize() {
  const read = () => ({
    w: document.documentElement.clientWidth || window.innerWidth,
    h: document.documentElement.clientHeight || window.innerHeight,
    dpr: window.devicePixelRatio || 1,
  });
  const [size, setSize] = useState(read);
  useEffect(() => {
    const update = () => {
      const next = read();
      setSize((prev) =>
        prev.w === next.w && prev.h === next.h && prev.dpr === next.dpr
          ? prev
          : next,
      );
    };
    window.addEventListener('resize', update);
    let observer: ResizeObserver | undefined;
    if (typeof ResizeObserver !== 'undefined') {
      observer = new ResizeObserver(update);
      observer.observe(document.documentElement);
    }
    return () => {
      window.removeEventListener('resize', update);
      observer?.disconnect();
    };
  }, []);
  return size;
}

function measureAdvance(family: string): number {
  const canvas = document.createElement('canvas');
  const ctx = canvas.getContext('2d');
  if (!ctx) {
    return FALLBACK_ADVANCE;
  }
  ctx.font = `100px ${family}`;
  const w = ctx.measureText('M'.repeat(50)).width / 50 / 100;
  return w > 0.3 && w < 1 ? w : FALLBACK_ADVANCE;
}

/** Loads VCR OSD Mono from the lobby asset and returns the measured advance. */
function useTerminalFont() {
  const [advance, setAdvance] = useState(FALLBACK_ADVANCE);
  useEffect(() => {
    let cancelled = false;
    let tries = 0;
    const load = () => {
      const url = resolveAsset('VCR_OSD_Mono.ttf');
      const face = new FontFace(FONT, `url(${url})`);
      face
        .load()
        .then((loaded) => {
          if (cancelled) {
            return;
          }
          document.fonts.add(loaded);
          setAdvance(measureAdvance(`'${FONT}'`));
        })
        .catch(() => {
          // The asset mapping can arrive a moment after the first render.
          if (!cancelled && tries++ < 5) {
            setTimeout(load, 1000);
          }
        });
    };
    load();
    return () => {
      cancelled = true;
    };
  }, []);
  return advance;
}

export function LobbyTerminal() {
  const { data, act } = useBackend<LobbyData>();
  const pane = usePaneSize();
  const advance = useTerminalFont();
  const layout = useMemo(
    () => computeLayout(pane.w, pane.h, pane.dpr, advance),
    [pane.w, pane.h, pane.dpr, advance],
  );
  const grid: Grid = useMemo(
    () => ({
      cols: layout.cols,
      rows: layout.rows,
      cw: layout.cw,
      ch: layout.ch,
      s: layout.s,
      lw: layout.lw,
      mode: layout.mode,
    }),
    [layout],
  );
  const reg = regions(layout.mode, layout.rows);

  const [tab, setTab] = useState<TabId>('crews');
  /** The tab that was open before CHARACTER, for Escape at its file view. */
  const [prevTab, setPrevTab] = useState<TabId>('crews');
  /** Bumped when SHIPYARD is pressed while already on it. */
  const [yardHome, setYardHome] = useState(0);
  /** Bumped when CHARACTER is pressed while already on it: back to the file view. */
  const [charHome, setCharHome] = useState(0);
  const [observeOpen, setObserveOpen] = useState(false);
  const [menuOpen, setMenuOpen] = useState(false);
  /** CHARACTER was opened by the shell before the round, not by the player. */
  const [autoChar, setAutoChar] = useState(false);
  const autoTried = useRef(false);

  const openScreen = (next: TabId) => {
    if (next === 'character' && tab !== 'character') {
      setPrevTab(tab);
    }
    setTab(next);
  };

  const request = data.tab_request;
  /** Counts screens the server picked; the tab row mounts again on each so its claim runs. */
  const [served, setServed] = useState(0);
  useEffect(() => {
    if (request) {
      // The server picked the screen: the CHARACTER file no longer opens by itself.
      autoTried.current = true;
      openScreen(request.tab);
      setServed((n) => n + 1);
    }
  }, [request?.serial]);

  // The player's first key press or click after LOGIN.
  const bootRef = useRef(data.boot);
  bootRef.current = data.boot;
  const [acted, setActed] = useState(false);
  useEffect(() => {
    if (acted) {
      return;
    }
    const onAct = () => {
      if (!bootRef.current) {
        setActed(true);
      }
    };
    window.addEventListener('keydown', onAct, true);
    window.addEventListener('click', onAct, true);
    return () => {
      window.removeEventListener('keydown', onAct, true);
      window.removeEventListener('click', onAct, true);
    };
  }, [acted]);

  // Before the round the main area opens on the CHARACTER file, once per page load, until the
  // player does something. When the round starts and they still have not, CREWS.
  const before = data.phase === 'loading' || data.phase === 'pregame';
  useEffect(() => {
    if (autoTried.current || acted || !before || !data.prefs_ready) {
      return;
    }
    autoTried.current = true;
    if (tab !== 'character') {
      openScreen('character');
      setAutoChar(true);
    }
  }, [acted, before, data.prefs_ready]);
  useEffect(() => {
    if (data.phase === 'playing' && autoChar && !acted && tab === 'character') {
      setTab('crews');
    }
    if (data.phase === 'playing' || acted) {
      setAutoChar(false);
    }
  }, [data.phase, acted]);

  // Report display metrics once the font settles (Windows scaling, pane size), for tuning.
  useEffect(() => {
    const id = setTimeout(
      () =>
        act('metrics', {
          dpr: layout.dpr,
          w: pane.w,
          h: pane.h,
          s: layout.s,
          cols: layout.cols,
          rows: layout.rows,
          mode: layout.mode,
        }),
      3000,
    );
    return () => clearTimeout(id);
  }, [advance]);

  const notice = data.notice;
  const confirmed = !!notice && notice.kind === 'ok';

  const switchTab = (next: TabId) => {
    if (next === tab && next === 'shipyard') {
      setYardHome(yardHome + 1);
    }
    if (next === tab && next === 'character') {
      setCharHome(charHome + 1);
    }
    openScreen(next);
    setObserveOpen(false);
    setMenuOpen(false);
    if (confirmed && notice) {
      act('dismiss', { at: notice.at });
    }
  };
  const { s } = layout;

  let body;
  if (confirmed) {
    body = <Confirmed />;
  } else if (tab === 'crews') {
    body = <CrewsTab setTab={switchTab} />;
  } else if (tab === 'shipyard') {
    body = <YardTab home={yardHome} />;
  } else if (tab === 'character') {
    body = <CharacterTab home={charHome} auto={autoChar} />;
  } else {
    body = <HousingTab />;
  }
  // When the start-up screen ends, the first-focus owners mount again so their claim runs.
  // The CHARACTER screen is left alone: mounting it again would ask for its file again.
  const bootKey = data.boot ? 'boot' : 'live';
  // The open tab's first-focus claim: in setup and ended it wins (design 01 section 9); on
  // HOUSING it is the stand-in when no key is live (design 02 section 4.4), so a live key's
  // claim (1) and READY's (9) beat it.
  const tabClaim =
    data.phase === 'setup' || data.phase === 'ended'
      ? 9
      : tab === 'housing'
        ? 0
        : undefined;
  const menu = {
    charOpen: tab === 'character' && !confirmed,
    onCharacter: () => switchTab('character'),
    onObserve: () => {
      setMenuOpen(false);
      setObserveOpen(true);
    },
  };

  return (
    <div
      style={{
        position: 'fixed',
        inset: 0,
        overflow: 'hidden',
        background: '#0b0a0e',
      }}
    >
      <style>{TERM_CSS + NAV_CSS}</style>
      <NavProvider
        onTabNumber={(n) => {
          const next = TABS[n - 1];
          if (next) {
            switchTab(next[0]);
          }
        }}
        onTabStep={(step) => {
          const at = TABS.findIndex(([id]) => id === tab);
          const next = TABS[(at + step + TABS.length) % TABS.length];
          switchTab(next[0]);
        }}
      >
        <Bezel s={s}>
          <div className="lt-crt">
            <div className="lt-nebula" />
            <div className="lt-stars">
              {STARS.map(([left, top, opacity], i) => (
                <i
                  key={i}
                  style={{
                    left: `${left}%`,
                    top: `${top}%`,
                    opacity,
                    width: s,
                    height: s,
                  }}
                />
              ))}
            </div>
            <div
              className="lt-tui"
              style={{
                left: layout.ox,
                top: layout.oy,
                width: layout.cols * layout.cw,
                height: layout.rows * layout.ch,
                fontSize: layout.fs,
                lineHeight: `${layout.ch}px`,
              }}
            >
              <GridContext.Provider value={grid}>
                <Region {...reg.header}>
                  <HeaderBand />
                </Region>
                {!!reg.menu && (
                  <Region {...reg.menu}>
                    <SideMenu key={bootKey} {...menu} />
                  </Region>
                )}
                <Region {...reg.main}>
                  <TabRow
                    key={`${bootKey}-${served}`}
                    tab={tab}
                    setTab={switchTab}
                    claim={tabClaim}
                  />
                  {tab === 'character' && !confirmed && (
                    <BackTo onBack={() => switchTab(prevTab)} />
                  )}
                  <Fragment key={tab === 'character' ? 'char' : bootKey}>
                    {body}
                  </Fragment>
                  <NoticeLine />
                  {!!observeOpen && !confirmed && (
                    <ObserveConfirm onClose={() => setObserveOpen(false)} />
                  )}
                  {!!reg.bar && !!menuOpen && (
                    <MenuPopup onClose={() => setMenuOpen(false)} />
                  )}
                </Region>
                {!!reg.bar && (
                  <Region {...reg.bar}>
                    <KeyBar
                      key={bootKey}
                      {...menu}
                      menuOpen={menuOpen}
                      onMenu={() => {
                        setObserveOpen(false);
                        setMenuOpen(!menuOpen);
                      }}
                    />
                  </Region>
                )}
              </GridContext.Provider>
            </div>
            {/* Glass layers, bottom to top: the canvas, the start-up screen, scanlines, vignette. */}
            <Boot
              glassW={layout.screen.w}
              glassH={layout.screen.h}
              dpr={layout.dpr}
            />
            <div className="lt-scan" />
            <div className="lt-vign" />
          </div>
        </Bezel>
      </NavProvider>
    </div>
  );
}

/** Escape at the CHARACTER file view: back to the tab that was open before it. */
function BackTo(props: { onBack: () => void }) {
  useBack(props.onBack);
  return null;
}
