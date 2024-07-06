import { useBackend } from '../../tgui/backend';
import { Button } from '../../tgui/components';
import { Window } from '../../tgui/layouts';

interface Data {
  mappingEnabled: number;
  used: number;
}

export const DropPod = (props, context) => {
  const { act, data } = useBackend<Data>();
  const { used } = data;
  return (
    <Window width={300} height={450}>
      <Window.Content>
        <Button onClick={() => act('open')}>Open</Button>
        <Button onClick={() => act('closed')}>Close</Button>
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
