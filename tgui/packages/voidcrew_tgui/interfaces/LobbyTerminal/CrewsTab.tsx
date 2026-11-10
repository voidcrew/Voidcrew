/**
 * CREWS tab. STUB from the shell package: package P2 owns and replaces this file.
 * Draw only with the term.tsx primitives; content lives between rows TOP and rows - 2
 * (rows - 1 is the shell's notice line). data.crews: see types.ts.
 */
import { useBackend } from 'tgui/backend';

import { Frame, Put, TOP, useGrid } from './term';
import type { LobbyData } from './types';

export function CrewsTab() {
  const { data } = useBackend<LobbyData>();
  const { cols, rows } = useGrid();
  const crews = data.crews || [];
  return (
    <Frame
      x={0}
      y={TOP}
      w={cols}
      h={rows - 1 - TOP}
      title={`CREWS  ${crews.length}`}
    >
      <Put x={3} y={TOP + 2} cls="dim">
        NO CREWS ARE SIGNING ON.
      </Put>
    </Frame>
  );
}
