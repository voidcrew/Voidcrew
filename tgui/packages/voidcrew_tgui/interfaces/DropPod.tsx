import { useBackend } from '../../tgui/backend';
import { Button } from '../../tgui/components';
import { Window } from '../../tgui/layouts';

interface Data {
  mappingEnabled: number;
  used: number;
  teleporterLinked: number;
}

export const DropPod = (props, context) => {
  const { act, data } = useBackend<Data>();
  const { used, teleporterLinked, mappingEnabled } = data;
  let canTeleport = used === 1 && teleporterLinked === 1 ? true : false;

  return (
    <Window width={300} height={450}>
      <Window.Content>
        <Button
          tooltip={
            !used
              ? "can't teleport while on ship"
              : !teleporterLinked
                ? 'no linked quantum pad'
                : undefined
          }
          disabled={canTeleport ? false : true}
          onClick={() => act('teleport')}
        >
          Teleport
        </Button>
        <Button onClick={() => act('open')}>Open</Button>
        <Button onClick={() => act('close')}>Close</Button>
        <Button
          disabled={used ? true : false}
          onClick={() => act('randomDrop')}
        >
          Random launch
        </Button>
        <Button disabled={used ? true : false} onClick={() => act('map')}>
          Map
        </Button>
      </Window.Content>
    </Window>
  );
};
