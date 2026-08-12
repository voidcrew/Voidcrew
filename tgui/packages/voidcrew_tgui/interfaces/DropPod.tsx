import { Button, NoticeBox, Section, Stack } from 'tgui-core/components';
import { useBackend } from '../../tgui/backend';
import { Window } from '../../tgui/layouts';

interface Data {
  used: number;
  teleporterLinked: number;
  teleporterUsed: number;
  overPlanet: number;
  /** Racked in an assault pod tube, the weapons system owns the launch. */
  inTube: number;
}

export const DropPod = (props, context) => {
  const { act, data } = useBackend<Data>();
  const { used, overPlanet, teleporterLinked, teleporterUsed, inTube } = data;

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

  const canDrop = !used && overPlanet === 1 && inTube !== 1;
  const dropTooltip = inTube
    ? 'loaded in a launch tube. The weapons officer fires this pod'
    : used
      ? 'this pod has already been launched'
      : overPlanet !== 1
        ? 'no surveyed celestial body below'
        : undefined;

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
            disabled={!canTeleport}
            onClick={() => act('teleport')}
          >
            Teleport
          </Button>
        </Section>
        <Stack />
        <Section title="Drop options" textAlign="center" fontSize={1.2}>
          {!!inTube && (
            <NoticeBox ml={'10%'} mr={'10%'} backgroundColor="red">
              LOADED IN LAUNCH TUBE
            </NoticeBox>
          )}
          <Button
            tooltip={dropTooltip}
            disabled={!canDrop}
            onClick={() => act('randomDrop')}
          >
            Random launch
          </Button>
          <Button
            tooltip={dropTooltip}
            disabled={!canDrop}
            onClick={() => act('map')}
          >
            Directed launch
          </Button>
        </Section>
      </Window.Content>
    </Window>
  );
};
