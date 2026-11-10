/**
 * ROLES (CHARACTER-PLAN 2.6): nine category rows, NEVER/LOW/MED/HIGH, char_role.
 * Owner: C4. Stub from the C0 seam; the props are fixed.
 */
import { Put } from './term';
import type { CellBox } from './types';

export function RolesEditor(props: CellBox) {
  const { x, y } = props;
  return (
    <Put x={x + 1} y={y + 1} cls="faint">
      {'ROLES'}
    </Put>
  );
}
