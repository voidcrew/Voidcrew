import { type BooleanLike } from 'tgui-core/react';
import {
  Box,
  Button,
  Divider,
  LabeledList,
  NoticeBox,
  ProgressBar,
  Section,
  Stack,
  Table,
} from 'tgui-core/components';

import { useBackend } from '../backend';
import { Window } from '../layouts';

type NearbyShip = {
  name: string;
  ref: string;
};

type Launcher = {
  id: string;
  name: string;
  loaded: BooleanLike;
  missile_name: string | null;
  missile_damage: number | null;
  ready: BooleanLike;
  cooldown: BooleanLike;
  cooldown_time: number;
};

type Data = {
  connected: BooleanLike;
  ship_name: string | null;
  cloak_active: BooleanLike;
  target_name: string | null;
  target_ref: string | null;
  nearby_ships: NearbyShip[];
  launchers: Launcher[];
  launchers_ready: number;
  launchers_total: number;
  // Interdictor data
  interdiction_active: BooleanLike;
  interdiction_progress: number;
  interdict_cooldown_active: BooleanLike;
  interdict_cooldown_remaining: number;
  target_same_tile: BooleanLike;
};

export const ShipCombatConsole = (props) => {
  const { data } = useBackend<Data>();
  const { connected } = data;

  return (
    <Window width={500} height={650} title="Ship Combat Console">
      <Window.Content>
        <Stack fill vertical>
          {!connected ? (
            <Stack.Item>
              <NoticeBox danger>
                Not connected to ship systems. Ensure the console is installed
                on a valid ship.
              </NoticeBox>
            </Stack.Item>
          ) : (
            <>
              <Stack.Item>
                <StatusSection />
              </Stack.Item>
              <Stack.Item>
                <TargetSection />
              </Stack.Item>
              <Stack.Item>
                <InterdictorSection />
              </Stack.Item>
              <Stack.Item grow>
                <LauncherSection />
              </Stack.Item>
            </>
          )}
        </Stack>
      </Window.Content>
    </Window>
  );
};

const StatusSection = () => {
  const { data } = useBackend<Data>();
  const { ship_name, cloak_active, target_name } = data;

  return (
    <Section title="Status">
      <LabeledList>
        <LabeledList.Item label="Ship">
          {ship_name || 'Unknown'}
        </LabeledList.Item>
        <LabeledList.Item label="Cloak">
          {cloak_active ? (
            <Box color="good">Active</Box>
          ) : (
            <Box color="label">Inactive</Box>
          )}
        </LabeledList.Item>
        <LabeledList.Item label="Target">
          {target_name ? (
            <Box color="bad">{target_name}</Box>
          ) : (
            <Box color="label">None</Box>
          )}
        </LabeledList.Item>
      </LabeledList>
    </Section>
  );
};

const TargetSection = () => {
  const { act, data } = useBackend<Data>();
  const { nearby_ships, target_name, target_ref } = data;

  return (
    <Section
      scrollable
      title="Nearby Ships"
      buttons={
        target_name && (
          <Button
            icon="times"
            color="bad"
            onClick={() => act('clear_target')}
          >
            Clear
          </Button>
        )
      }
    >
      {nearby_ships.length === 0 ? (
        <NoticeBox>No ships detected in range</NoticeBox>
      ) : (
        <Stack vertical>
          {nearby_ships.map((ship) => (
            <Stack.Item key={ship.ref}>
              <Button
                fluid
                icon="crosshairs"
                selected={target_ref === ship.ref}
                onClick={() => act('select_target', { ref: ship.ref })}
              >
                {ship.name}
              </Button>
            </Stack.Item>
          ))}
        </Stack>
      )}
      <Divider />
      <Button
        fluid
        icon="crosshairs"
        color="red"
        disabled={!target_name}
        onClick={() => act('activate')}
      >
        Activate Targeting
      </Button>
    </Section>
  );
};

const InterdictorSection = () => {
  const { act, data } = useBackend<Data>();
  const {
    target_ref,
    target_same_tile,
    interdiction_active,
    interdiction_progress,
    interdict_cooldown_active,
    interdict_cooldown_remaining,
  } = data;

  // Can interdict if: target selected, on same tile, not already interdicting, not on cooldown
  const canInterdict =
    target_ref && target_same_tile && !interdiction_active && !interdict_cooldown_active;

  return (
    <Section title="Interdictor">
      {interdiction_active ? (
        <>
          <Box mb={1} fontSize="14px" textAlign="center" color="bad">
            INTERDICTION IN PROGRESS
          </Box>
          <ProgressBar
            value={interdiction_progress / 100}
            ranges={{
              bad: [0, 0.4],
              average: [0.4, 0.8],
              good: [0.8, 1],
            }}
          >
            Locking... {interdiction_progress}%
          </ProgressBar>
          <Box mt={1}>
            <Button
              fluid
              icon="times"
              color="bad"
              onClick={() => act('cancel_interdict')}
            >
              Cancel Interdiction
            </Button>
          </Box>
        </>
      ) : interdict_cooldown_active ? (
        <>
          <Box mb={1} textAlign="center" color="label">
            Interdictor Recharging
          </Box>
          <ProgressBar
            value={1 - interdict_cooldown_remaining / 3000}
            ranges={{
              bad: [0, 0.4],
              average: [0.4, 0.8],
              good: [0.8, 1],
            }}
          >
            {Math.ceil(interdict_cooldown_remaining / 10)}s remaining
          </ProgressBar>
        </>
      ) : (
        <Button
          fluid
          icon="satellite-dish"
          color="red"
          disabled={!canInterdict}
          onClick={() => act('start_interdict')}
        >
          {!target_ref
            ? 'Select a Target'
            : !target_same_tile
              ? 'Target Not In Range (Same Tile)'
              : 'INTERDICT TARGET'}
        </Button>
      )}
    </Section>
  );
};

const LauncherSection = () => {
  const { data } = useBackend<Data>();
  const { launchers, launchers_ready, launchers_total } = data;

  // Count total loaded missiles
  const missilesLoaded = launchers.filter((l) => l.loaded).length;

  return (
    <Section
      fill
      scrollable
      title="Missile Launchers"
      buttons={
        <Box>
          {missilesLoaded} missiles | {launchers_ready}/{launchers_total} ready
        </Box>
      }
    >
      {launchers.length === 0 ? (
        <NoticeBox>
          No launchers linked. Use a multitool to link missile launchers.
        </NoticeBox>
      ) : (
        <Table>
          <Table.Row header>
            <Table.Cell>Launcher</Table.Cell>
            <Table.Cell>Missile</Table.Cell>
            <Table.Cell>Status</Table.Cell>
          </Table.Row>
          {launchers.map((launcher) => (
            <Table.Row key={launcher.id}>
              <Table.Cell>{launcher.id}</Table.Cell>
              <Table.Cell>
                {launcher.loaded ? (
                  <Box color="good">
                    {launcher.missile_name} ({launcher.missile_damage} dmg)
                  </Box>
                ) : (
                  <Box color="bad">Empty</Box>
                )}
              </Table.Cell>
              <Table.Cell>
                {launcher.ready ? (
                  <Box color="good">Ready</Box>
                ) : launcher.cooldown ? (
                  <ProgressBar
                    value={1 - launcher.cooldown_time / 50}
                    ranges={{
                      good: [0.8, 1],
                      average: [0.4, 0.8],
                      bad: [0, 0.4],
                    }}
                  >
                    Cooling
                  </ProgressBar>
                ) : (
                  <Box color="bad">Not Ready</Box>
                )}
              </Table.Cell>
            </Table.Row>
          ))}
        </Table>
      )}
    </Section>
  );
};
