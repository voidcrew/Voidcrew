/**
 * KIT (CHARACTER-PLAN 2.8): loadout categories and items, char_kit, GAGS colours through ColorEntry (char_kit_color), char_kit_skin, char_kit_name.
 * Owner: C4. Stub from the C0 seam; the props are fixed.
 */
import { Put } from './term';
import type { CellBox } from './types';

export function KitEditor(props: CellBox) {
  const { x, y } = props;
  return (
    <Put x={x + 1} y={y + 1} cls="faint">
      {'KIT'}
    </Put>
  );
}
