import { useBackend } from '../../tgui/backend';
import { Button } from '../../tgui/components';
import { Window } from '../../tgui/layouts';

interface Data {
  mappingEnabled: number;
}

export const DropPod = (props, context) => {
  const { act, data } = useBackend<Data>();
  const { used } = data;
  return (
    <Window width={300} height={450}>
      <Window.Content>
        {used}
        <Button onClick={() => act('randomDrop')}>Random launch</Button>
        <Button onClick={() => act('map')}>Map</Button>
      </Window.Content>
    </Window>
  );
};
