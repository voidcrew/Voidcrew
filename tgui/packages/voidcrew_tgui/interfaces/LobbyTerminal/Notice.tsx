import { useBackend } from 'tgui/backend';

import { useBack } from './nav';
import { Btn, Frame, Put, pad, TOP, useGrid, wrapMax } from './term';
import type { LobbyData } from './types';

/** The CONFIRMED box (kind "ok"), drawn instead of the tab content. */
export function Confirmed() {
  const { data, act } = useBackend<LobbyData>();
  const { cols } = useGrid();
  const notice = data.notice;
  useBack(notice ? () => act('dismiss') : null);
  if (!notice) {
    return null;
  }
  const w = Math.min(44, cols - 2);
  const x = Math.floor(cols / 2) - Math.floor(w / 2);
  const lines = wrapMax(notice.text.toUpperCase(), w - 6, 3);
  const h = 7 + lines.length;
  return (
    <Frame x={x} y={TOP + 3} w={w} h={h} title="CONFIRMED">
      {lines.map((line, i) => (
        <Put key={i} x={x + 3} y={TOP + 5 + i} cls="amb">
          {line}
        </Put>
      ))}
      <Put x={x + 3} y={TOP + 6 + lines.length} cls="dim">
        STAND BY.
      </Put>
      <Btn
        x={x + 3}
        y={TOP + 8 + lines.length}
        label="BACK"
        lit
        auto={1}
        onClick={() => act('dismiss')}
      />
    </Frame>
  );
}

/** One amber or red line on the bottom row. Click to clear it. */
export function NoticeLine() {
  const { data, act } = useBackend<LobbyData>();
  const { cols, rows } = useGrid();
  const notice = data.notice;
  if (!notice || notice.kind === 'ok') {
    return null;
  }
  return (
    <Put
      x={1}
      y={rows - 1}
      cls={notice.kind === 'bad' ? 'red' : 'amb'}
      onClick={() => act('dismiss')}
    >
      {pad(notice.text.toUpperCase(), cols - 2)}
    </Put>
  );
}
