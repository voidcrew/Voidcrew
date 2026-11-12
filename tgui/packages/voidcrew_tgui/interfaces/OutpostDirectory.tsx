import type { BooleanLike } from 'tgui-core/react';

import { Window } from '../../tgui/layouts';

// The directory board on a trader outpost's concourse (voidcrew/modules/trade_floors/floor_directory.dm).
// A stub: it draws an empty window. The package that owns the board fills it in from the contract below.

export type DirectoryRow = {
  number: number;
  kind: 'open' | 'invited' | 'private' | 'tenant' | 'vacant';
  name: string | null;
  crew: string | null;
  accent: string | null;
  line: string | null;
  offers: string[];
  busy: BooleanLike;
};

export type DirectoryData = {
  rows: DirectoryRow[];
};

export const OutpostDirectory = (props) => {
  return (
    <Window width={420} height={360} title="Directory">
      <Window.Content />
    </Window>
  );
};
