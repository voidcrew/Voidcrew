import { useBackend } from '../../tgui/backend';
import { Button, NoticeBox, Section, Stack } from 'tgui-core/components';
import { Window } from '../../tgui/layouts';

interface Data {
  mappingEnabled: number;
  used: number;
  teleporterLinked: number;
  teleporterUsed: number;
  overPlanet: number;
}

export const DropPod = (props, context) => {
  const { act, data } = useBackend<Data>();
  const { used, overPlanet, teleporterLinked, teleporterUsed, mappingEnabled } =
    data;

  let canTeleport = false;
  let teleportTooltip;
  let teleportStatus = 'NOT LINKED';

  if (teleporterLinked) {
    if (teleporterUsed) {
      teleportTooltip = 'already used';
      teleportStatus = 'USED';
    } else {
      teleportStatus = 'LINKED';
      if (used) {
        canTeleport = true;
      } else {
        teleportTooltip = "can't launch from ship";
      }
    }
  } else {
    teleportTooltip = 'not linked to a quantum pad';
  }

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
            backgroundColor={
              teleportStatus === 'USED'
                ? 'yellow'
                : teleportStatus === 'LINKED'
                  ? 'green'
                  : teleportStatus === 'NOT LINKED'
                    ? 'red'
                    : 'red'
            }
            textColor="white"
          >
            teleporter status: {teleportStatus}
          </NoticeBox>
          <Button align="right" onClick={() => act('open')}>
            Open
          </Button>
          <Button onClick={() => act('close')}>Close</Button>

          <Button
            tooltip={teleportTooltip}
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
