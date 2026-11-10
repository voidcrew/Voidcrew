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
import { useEffect, useMemo, useState } from 'react';
import { resolveAsset } from 'tgui/assets';
import { useBackend } from 'tgui/backend';

import { BEZEL_EXTRA_CSS, Bezel } from './Bezel';
import { CrewsTab } from './CrewsTab';
import { Header } from './Header';
import { HousingTab } from './HousingTab';
import { computeLayout } from './layout';
import { Confirmed, NoticeLine } from './Notice';
import { type Grid, GridContext, TERM_CSS } from './term';
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
      narrow: layout.narrow,
    }),
    [layout],
  );

  const [tab, setTab] = useState<TabId>('crews');
  const request = data.tab_request;
  useEffect(() => {
    if (request) {
      setTab(request.tab);
    }
  }, [request?.serial]);

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
        }),
      3000,
    );
    return () => clearTimeout(id);
  }, [advance]);

  const notice = data.notice;
  const confirmed = !!notice && notice.kind === 'ok';
  const { s } = layout;
  const scan = Math.max(2, Math.round(s));

  let body;
  if (confirmed) {
    body = <Confirmed />;
  } else if (tab === 'crews') {
    body = <CrewsTab />;
  } else if (tab === 'shipyard') {
    body = <YardTab />;
  } else {
    body = <HousingTab />;
  }

  return (
    <div
      style={{
        position: 'fixed',
        inset: 0,
        overflow: 'hidden',
        background: '#0b0b0e',
        ['--lt-bg' as string]: '#07130d',
      }}
    >
      <style>{TERM_CSS + BEZEL_EXTRA_CSS}</style>
      <Bezel s={s}>
        <div className="lt-crt">
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
              <Header
                tab={tab}
                setTab={(next) => {
                  setTab(next);
                  if (confirmed) {
                    act('dismiss');
                  }
                }}
              />
              {body}
              <NoticeLine />
            </GridContext.Provider>
          </div>
          <div
            className="lt-scan"
            style={{
              background: `repeating-linear-gradient(to bottom, rgba(0,0,0,0) 0, rgba(0,0,0,0) ${scan - 1}px, rgba(0,0,0,.32) ${scan - 1}px, rgba(0,0,0,.32) ${scan}px)`,
            }}
          />
          <div className="lt-glass" />
        </div>
      </Bezel>
    </div>
  );
}
