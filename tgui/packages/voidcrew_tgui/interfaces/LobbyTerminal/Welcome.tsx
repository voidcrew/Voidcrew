/**
 * WELCOME, asked once of a first-timer (first_time_notice.dm): combat mode or intents, with
 * COMBAT MODE focused. LATER, Escape or a click outside closes it for this connection.
 */
import { useBackend } from 'tgui/backend';

import { quietDialogClose } from './motion';
import { useBack } from './nav';
import { BODY_Y, Big, Btn, Dialog, Put, RPut, Slab, useGrid } from './term';
import type { LobbyData } from './types';

const W = 45;
const H = 11;

const CHOICES: [mode: string, name: string, key: string, line: string][] = [
  ['combat', 'COMBAT MODE', 'F', 'ONE SWITCH: GUARD UP OR DOWN.'],
  ['intents', 'INTENTS', '1-4', 'HELP, DISARM, GRAB, HARM.'],
];

export function Welcome(props: { onLater: () => void; onClose: () => void }) {
  const { onLater, onClose } = props;
  const { act } = useBackend<LobbyData>();
  const { cols } = useGrid();
  useBack(onLater);
  const x = Math.floor((cols - W) / 2);
  const y = BODY_Y + 2;
  const pick = (mode: string) => {
    // Answered, not backed out of: the box goes without the back sound.
    quietDialogClose();
    onClose();
    act('welcome_pick', { mode });
  };
  return (
    <>
      <div
        className="lt-dimsheet"
        onClick={(e) => {
          e.stopPropagation();
          onLater();
        }}
      />
      <Dialog w={W} h={H} caption="WELCOME">
        <Put x={x + 2} y={y + 1} cls="wht">
          FIRST TIME IN PORT. HOW DO YOU FIGHT?
        </Put>
        {CHOICES.map(([mode, name, key, line], i) => {
          const sy = y + 2.5 + i * 3.25;
          return (
            <Slab
              key={mode}
              x={x + 2}
              y={sy}
              w={W - 4}
              h={2.75}
              variant="block"
              auto={i === 0 ? 20 : undefined}
              onClick={() => pick(mode)}
            >
              <Big x={x + 4} y={sy + 0.25} scale={1.25} cls="wht">
                {name}
              </Big>
              <RPut x={x + W - 4} y={sy + 0.375} cls="amb">
                {key}
              </RPut>
              <Put x={x + 4} y={sy + 1.5} cls="dim">
                {line}
              </Put>
            </Slab>
          );
        })}
        <Put x={x + 2} y={y + 9.5} cls="dim">
          IT CAN BE CHANGED IN SETTINGS.
        </Put>
        <Btn x={x + W - 2} y={y + 9.5} label="LATER" right onClick={onLater} />
      </Dialog>
    </>
  );
}
