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
} from 'tgui-core/components';

import { useBackend } from '../backend';
import { Window } from '../layouts';

type NearbyShip = {
  name: string;
  ref: string;
};

type Data = {
  connected: BooleanLike;
  ship_name: string | null;
  nearby_ships: NearbyShip[];
  target_name: string | null;
  target_ref: string | null;
  interdiction_active: BooleanLike;
  interdiction_progress: number;
  cooldown_active: BooleanLike;
  cooldown_remaining: number;
};

export const ShipInterdictor = (props) => {
  const { data } = useBackend<Data>();
  const { connected } = data;

  return (
    <Window width={400} height={450} title="Ship Interdictor">
      <Window.Content>
        <Stack fill vertical>
          {!connected ? (
            <Stack.Item>
              <NoticeBox danger>
                Not connected to ship systems. Ensure the interdictor is
                installed on a valid ship.
              </NoticeBox>
            </Stack.Item>
          ) : (
            <>
              <Stack.Item>
                <StatusSection />
              </Stack.Item>
              <Stack.Item grow>
                <TargetSection />
              </Stack.Item>
              <Stack.Item>
                <ActionSection />
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
  const { ship_name, target_name, interdiction_active, cooldown_active } = data;

  let statusText = 'Ready';
  let statusColor = 'good';

  if (interdiction_active) {
    statusText = 'INTERDICTING';
    statusColor = 'bad';
  } else if (cooldown_active) {
    statusText = 'Recharging';
    statusColor = 'average';
  }

  return (
    <Section title="Status">
      <LabeledList>
        <LabeledList.Item label="Ship">
          {ship_name || 'Unknown'}
        </LabeledList.Item>
        <LabeledList.Item label="Status">
          <Box color={statusColor}>{statusText}</Box>
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
  const { nearby_ships, target_ref, interdiction_active } = data;

  return (
    <Section
      fill
      scrollable
      title="Nearby Ships"
      buttons={
        target_ref &&
        !interdiction_active && (
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
        <NoticeBox>No ships detected on same tile</NoticeBox>
      ) : (
        <Stack vertical>
          {nearby_ships.map((ship) => (
            <Stack.Item key={ship.ref}>
              <Button
                fluid
                icon="crosshairs"
                selected={target_ref === ship.ref}
                disabled={interdiction_active}
                onClick={() => act('select_target', { ref: ship.ref })}
              >
                {ship.name}
              </Button>
            </Stack.Item>
          ))}
        </Stack>
      )}
    </Section>
  );
};

const ActionSection = () => {
  const { act, data } = useBackend<Data>();
  const {
    target_ref,
    interdiction_active,
    interdiction_progress,
    cooldown_active,
    cooldown_remaining,
  } = data;

  // Can't interdict if: no target, already interdicting, or on cooldown
  const canInterdict = target_ref && !interdiction_active && !cooldown_active;

  return (
    <Section title="Interdictor Controls">
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
          <Divider />
          <Button
            fluid
            icon="times"
            color="bad"
            onClick={() => act('cancel_interdict')}
          >
            Cancel Interdiction
          </Button>
        </>
      ) : cooldown_active ? (
        <>
          <Box mb={1} textAlign="center" color="label">
            Interdictor Recharging
          </Box>
          <ProgressBar
            value={1 - cooldown_remaining / 300000}
            ranges={{
              bad: [0, 0.4],
              average: [0.4, 0.8],
              good: [0.8, 1],
            }}
          >
            {Math.ceil(cooldown_remaining / 1000)}s remaining
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
          {target_ref ? 'INTERDICT TARGET' : 'Select a Target'}
        </Button>
      )}
    </Section>
  );
};
