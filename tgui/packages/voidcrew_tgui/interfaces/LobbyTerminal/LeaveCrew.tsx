/**
 * LEAVE CREW: asked before commission, requisition or load founds a new crew while the player
 * belongs to one (spec 02, 2.4). The focus starts on [ STAY ]; Escape is STAY. The right-hand
 * key is the only thing on the page that sends leave_crew 1.
 */
import { useBack, usePager } from './nav';
import { BODY_Y, Btn, Dialog, Put, safe, useGrid, wrapMax } from './term';

const W = 45;
const TEXT_W = 41;

export function LeaveCrew(props: {
  /** The crew's name (the ship's name, 46 at most). */
  crew: string;
  /** The key that opened it: COMMISSION, REQUISITION or LOAD. */
  label: string;
  onStay: () => void;
  onGo: () => void;
}) {
  const { crew, label, onStay, onGo } = props;
  const { cols, rows, cw, ch } = useGrid();
  useBack(onStay);
  // PageUp / PageDown do nothing while this is open (the fit underneath would change step).
  usePager(() => undefined);
  const lines = wrapMax(`THIS LEAVES ${safe(crew).toUpperCase()}.`, TEXT_W, 3);
  const n = lines.length;
  const x = Math.floor((cols - W) / 2);
  const y = BODY_Y + 2;
  const keyY = y + n + 2;
  return (
    <>
      {/* The screen under the dialog at 35 %. Clicks stop here. */}
      <div
        style={{
          position: 'absolute',
          left: 0,
          top: 0,
          width: Math.round(cols * cw),
          height: Math.round(rows * ch),
          background: 'rgba(15,6,32,.65)',
          zIndex: 7,
        }}
        onClick={(e) => e.stopPropagation()}
      />
      <Dialog w={W} h={5 + n} caption="LEAVE CREW">
        {lines.map((line, i) => (
          <Put key={i} x={x + 2} y={y + 1 + i} cls="wht">
            {line}
          </Put>
        ))}
        <Btn x={x + 2} y={keyY} label="STAY" lit auto={9} onClick={onStay} />
        <Btn x={x + 43} y={keyY} right label={label} onClick={onGo} />
      </Dialog>
    </>
  );
}
