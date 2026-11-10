/**
 * BODY (CHARACTER-PLAN 2.3/2.4): data-driven rows from CharData.prefs in BODY_KEYS order, char_set, the species confirm line, ColorEntry for free colours.
 * Owner: C3. Stub from the C0 seam; the props are fixed.
 */
import { Put } from './term';
import type { CellBox } from './types';

export function BodyEditor(props: CellBox) {
  const { x, y } = props;
  return (
    <Put x={x + 1} y={y + 1} cls="faint">
      {'BODY'}
    </Put>
  );
}
