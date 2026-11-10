/**
 * TRAITS (CHARACTER-PLAN 2.7): filtered quirk list, description, TAKEN box with POINTS, char_quirk and quirk options through char_set.
 * Owner: C4. Stub from the C0 seam; the props are fixed.
 */
import { Put } from './term';
import type { CellBox } from './types';

export function TraitsEditor(props: CellBox) {
  const { x, y } = props;
  return (
    <Put x={x + 1} y={y + 1} cls="faint">
      {'TRAITS'}
    </Put>
  );
}
