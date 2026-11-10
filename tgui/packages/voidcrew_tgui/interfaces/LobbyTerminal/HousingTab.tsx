/**
 * HOUSING tab. STUB from the shell package: package P5 owns and replaces this file.
 * Draw only with the term.tsx primitives; content lives between rows TOP and rows - 2.
 * data.outposts: see types.ts.
 */
import { useBackend } from 'tgui/backend';

import { Frame, Put, TOP, useGrid } from './term';
import type { LobbyData } from './types';

export function HousingTab() {
  const { data } = useBackend<LobbyData>();
  const { cols, rows } = useGrid();
  const outposts = data.outposts || [];
  return (
    <Frame
      x={0}
      y={TOP}
      w={cols}
      h={rows - 1 - TOP}
      title={`OUTPOSTS  ${outposts.length}`}
    >
      <Put x={3} y={TOP + 2} cls="dim">
        NO ROOMS TO LET.
      </Put>
    </Frame>
  );
}
