import { useEffect } from 'react';
import { useBackend } from 'tgui/backend';

import { useBack } from './nav';
import {
  Band,
  BODY_Y,
  Box,
  BOX_Y,
  Btn,
  Dialog,
  Put,
  safe,
  useGrid,
  wrapMax,
} from './term';
import type { LobbyData } from './types';

/** How long a notice stays before it clears itself, in ms. */
const NOTICE_LIFE = { warn: 8000, bad: 10000 } as const;

/** Notice text: column 2 to column 60. */
const NOTICE_W = 59;

/** The empty main box, for what draws a dialog instead of a screen. */
export function EmptyBox() {
  const { rows } = useGrid();
  return <Box x={0} y={BOX_Y} w={63} h={rows - 1 - BOX_Y} />;
}

/** The CONFIRMED box (kind "ok"), drawn over the empty main box instead of the screen. */
export function Confirmed() {
  const { data, act } = useBackend<LobbyData>();
  const { cols } = useGrid();
  const notice = data.notice;
  const dismiss = () => act('dismiss', notice ? { at: notice.at } : {});
  useBack(notice ? dismiss : null);
  if (!notice) {
    return null;
  }
  const lines = wrapMax(safe(notice.text).toUpperCase(), 41, 3);
  const n = lines.length;
  const x = Math.floor((cols - 45) / 2) + 2;
  // The Dialog's top row.
  const y = BODY_Y + 2;
  return (
    <>
      <EmptyBox />
      <Dialog w={45} h={6 + n} caption="CONFIRMED">
        {lines.map((line, i) => (
          <Put key={i} x={x} y={y + 1 + i} cls="wht">
            {line}
          </Put>
        ))}
        <Put x={x} y={y + 1.5 + n} cls="dim">
          STAND BY.
        </Put>
        <Btn x={x} y={y + 3.5 + n} label="BACK" lit auto={9} onClick={dismiss} />
      </Dialog>
    </>
  );
}

/**
 * The notice row under the main box (kinds warn and bad): amber on a faint band, or ink on a
 * red band. Two lines at most; a second line grows the band upward over the box's bottom edge.
 * A click clears it, and it clears itself after a few seconds.
 */
export function NoticeLine() {
  const { data, act } = useBackend<LobbyData>();
  const { rows } = useGrid();
  const notice = data.notice;
  const kind = notice?.kind;
  const at = notice?.at;
  useEffect(() => {
    if (kind !== 'warn' && kind !== 'bad') {
      return;
    }
    const id = setTimeout(() => act('dismiss', { at }), NOTICE_LIFE[kind]);
    return () => clearTimeout(id);
  }, [kind, at]);
  if (!notice || notice.kind === 'ok') {
    return null;
  }
  const bad = notice.kind === 'bad';
  const lines = wrapMax(safe(notice.text).toUpperCase(), NOTICE_W, 2);
  const top = rows - lines.length;
  const clear = () => act('dismiss', { at: notice.at });
  return (
    <>
      {lines.length > 1 && (
        <Band x={0} y={top} w={63} h={lines.length} tone="bg" />
      )}
      <Band
        x={0}
        y={top}
        w={63}
        h={lines.length}
        tone={bad ? 'bad' : 'warn'}
      />
      {lines.map((line, i) => (
        <Put
          key={i}
          x={2}
          y={top + i}
          cls={bad ? 'ink' : 'amb'}
          onClick={clear}
          mouseOnly
        >
          {line}
        </Put>
      ))}
    </>
  );
}
