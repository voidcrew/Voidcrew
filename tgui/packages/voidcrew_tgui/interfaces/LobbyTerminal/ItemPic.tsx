/**
 * ItemPic (design 03b section 3.2): a loadout item's own sprite in a cell block, as tg's
 * loadout page draws it (DmIcon from the catalog's icon and icon_state), at a whole scale,
 * pixelated and centred. Draws nothing when the icon does not resolve (no Byond.iconRefMap
 * entry, as in the render harness).
 */
import { DmIcon } from 'tgui-core/components';

import { useGrid } from './term';

export function ItemPic(props: {
  x: number;
  y: number;
  w: number;
  h: number;
  icon: string;
  icon_state: string;
  /** Whole multiple of 32 px. */
  scale: number;
}) {
  const { x, y, w, h, icon, icon_state, scale } = props;
  const { cw, ch } = useGrid();
  const size = 32 * Math.max(1, Math.floor(scale));
  const left = Math.round(x * cw + (w * cw - size) / 2);
  const top = Math.round(y * ch + (h * ch - size) / 2);
  return (
    <div
      style={{
        position: 'absolute',
        left,
        top,
        width: size,
        height: size,
        pointerEvents: 'none',
        zIndex: 3,
      }}
    >
      <DmIcon
        icon={icon}
        icon_state={icon_state}
        fallback={null}
        width={`${size}px`}
        height={`${size}px`}
        style={{ imageRendering: 'pixelated' }}
      />
    </div>
  );
}
