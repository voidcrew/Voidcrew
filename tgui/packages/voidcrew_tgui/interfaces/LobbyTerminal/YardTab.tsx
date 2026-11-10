/**
 * SHIPYARD tab. STUB from the shell package: package P4 owns and replaces this file.
 * Draw only with the term.tsx primitives; content lives between rows TOP and rows - 2.
 * The catalog arrives in static data only after `yard_open`. data/static keys: see types.ts.
 */
import { useEffect } from 'react';
import { useBackend } from 'tgui/backend';

import { Frame, Put, TOP, useGrid } from './term';
import type { LobbyData } from './types';

export function YardTab() {
  const { act } = useBackend<LobbyData>();
  const { cols, rows } = useGrid();
  useEffect(() => {
    act('yard_open');
  }, []);
  return (
    <Frame x={0} y={TOP} w={cols} h={rows - 1 - TOP} title="SHIPYARD">
      <Put x={3} y={TOP + 2} cls="dim">
        THE YARD IS CLOSED.
      </Put>
    </Frame>
  );
}
