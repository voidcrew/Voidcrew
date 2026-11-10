/**
 * The character preview (CHARACTER-PLAN 2.5 / 3): a viewscreen over cells (x, y, w, h)
 * showing the server's render of the dressed mannequin facing dir. Keeps a client cache of
 * char_preview pushes (key -> dir -> png) and sends char_turn only for a facing it doesn't
 * have for the current look. The turn keys and dress label around it belong to CharacterTab.
 * Owner: C2. Stub from the C0 seam; the props are fixed.
 */
import { useGrid } from './term';
import type { CellBox, CharDir } from './types';

export function CharPreview(props: CellBox & { dir: CharDir }) {
  const { x, y, w, h } = props;
  const { cw, ch } = useGrid();
  return (
    <div
      className="lt-vscreen"
      style={{
        left: Math.round(x * cw),
        top: Math.round(y * ch),
        width: Math.round(w * cw),
        height: Math.round(h * ch),
      }}
    >
      <div className="lt-vscan" />
    </div>
  );
}
