/**
 * OBSERVE, asked in the terminal: a small box over the current screen with STAY focused, so a
 * slipped key never takes a player out of the round. Escape is STAY.
 */
import { useBackend } from 'tgui/backend';

import { quietDialogClose } from './motion';
import { useBack } from './nav';
import { BODY_Y, Btn, Dialog, Put, useGrid } from './term';
import type { LobbyData } from './types';

const W = 43;

const COME_BACK: Record<string, [string, string]> = {
  same: ['YOU CAN SIGN ON AGAIN LATER.', 'dim'],
  new: ['YOU CAN SIGN ON LATER AS SOMEONE ELSE.', 'dim'],
  none: ['YOU WILL SIT THIS ROUND OUT.', 'amb'],
};

export function ObserveConfirm(props: { onClose: () => void }) {
  const { onClose } = props;
  const { data, act } = useBackend<LobbyData>();
  const { cols } = useGrid();
  useBack(onClose);
  const x = Math.floor((cols - W) / 2);
  const y = BODY_Y + 2;
  const [line, cls] = COME_BACK[data.respawn || 'same'] || COME_BACK.same;
  return (
    <>
      <div
        className="lt-dimsheet"
        onClick={(e) => {
          e.stopPropagation();
          onClose();
        }}
      />
      <Dialog w={W} h={7} caption="OBSERVE">
        <Put x={x + 2} y={y + 1} cls="wht">
          LEAVE THE OFFICE AND WATCH THE ROUND?
        </Put>
        <Put x={x + 2} y={y + 2} cls={cls}>
          {line}
        </Put>
        <Btn x={x + 2} y={y + 4} label="STAY" lit auto={9} onClick={onClose} />
        <Btn
          x={x + 41}
          y={y + 4}
          label="OBSERVE"
          right
          onClick={() => {
            // Answered, not backed out of: the box goes without the back sound.
            quietDialogClose();
            onClose();
            act('observe_confirm');
          }}
        />
      </Dialog>
    </>
  );
}
