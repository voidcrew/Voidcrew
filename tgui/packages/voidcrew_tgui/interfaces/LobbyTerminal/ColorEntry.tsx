/**
 * Free colour entry for BODY and KIT (CHARACTER-PLAN 2.9). The row reads
 * `LABEL  [##] #RRGGBB`; clicking the chip or the hex opens the H/S/V panel. Only SET sends.
 * Owner: C3. The props are the contract C4's KitEditor builds against; keep them.
 */
import { Put, Swatch } from './term';

export type ColorEntryProps = {
  /** Column and row of the label. */
  x: number;
  y: number;
  /** Cells the row may use. */
  w: number;
  label: string;
  /** Current colour, "#rrggbb". */
  value: string;
  /** Colours offered in the recent row (already on this file, plus the viewer's last ones). */
  recent: string[];
  /** Show [ PICKER ] (BYOND's native dialog). BODY colours only. */
  native?: boolean;
  /** SET pressed with a valid colour. */
  onSet: (hex: string) => void;
  /** [ PICKER ] pressed. */
  onPicker?: () => void;
};

export function ColorEntry(props: ColorEntryProps) {
  const { x, y, label, value } = props;
  return (
    <>
      <Put x={x} y={y} cls="dim">
        {label}
      </Put>
      <Swatch x={x + label.length + 1} y={y} hex={value} />
      <Put x={x + label.length + 4} y={y}>
        {value.toUpperCase()}
      </Put>
    </>
  );
}
