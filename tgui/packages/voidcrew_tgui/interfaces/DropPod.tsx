import { useBackend } from '../../tgui/backend';
import { Button, NoticeBox, Section, Stack } from '../../tgui/components';
import { Window } from '../../tgui/layouts';

interface Data {
  mappingEnabled: number;
  used: number;
  teleporterLinked: number;
  overPlanet: number;
}

export const DropPod = (props, context) => {
  const { act, data } = useBackend<Data>();
  const { used, overPlanet, teleporterLinked, mappingEnabled } = data;
  let canTeleport = used === 1 && teleporterLinked === 1 ? true : false;

  let canDrop = false;
  if (!used && overPlanet === 1) {
    canDrop = true;
  }

  let canMap = false;
  if (canDrop && mappingEnabled === 1) {
    canMap = true;
  }

  return (
    <Window width={300} height={450} title="Drop pod">
      <Window.Content>
        <Section
          title="Pod settings"
          fontSize={1.2}
          textAlign="center"
          buttons={
            <Button icon="arrows-rotate" onClick={() => act('refresh')} />
          }
        >
          <NoticeBox
            ml={'10%'}
            mr={'10%'}
            backgroundColor={teleporterLinked === 1 ? 'green' : 'red'}
            textColor="white"
          >
            teleporter status: {teleporterLinked === 1 ? 'LINKED' : 'UNLINKED'}
          </NoticeBox>
          <Button align="right" onClick={() => act('open')}>
            Open
          </Button>
          <Button onClick={() => act('close')}>Close</Button>

          <Button
            tooltip={
              !teleporterLinked
                ? 'no linked quantum pad'
                : !used
                  ? "can't teleport while on ship"
                  : undefined
            }
            disabled={canTeleport ? false : true}
            onClick={() => act('teleport')}
          >
            Teleport
          </Button>
        </Section>
        <Stack />
        <Section title="Drop options" textAlign="center" fontSize={1.2}>
          <Button
            disabled={canDrop ? false : true}
            onClick={() => act('randomDrop')}
          >
            Random launch
          </Button>
          <Button disabled={canMap ? false : true} onClick={() => act('map')}>
            Directed launch
          </Button>
        </Section>
      </Window.Content>
    </Window>
  );
};
