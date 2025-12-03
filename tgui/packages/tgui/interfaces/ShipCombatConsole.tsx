import { type BooleanLike } from 'tgui-core/react';
import {
  Box,
  Button,
  Collapsible,
  Dimmer,
  Icon,
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
  interdiction_active: BooleanLike;
  interdict_cooldown_active: BooleanLike;
  interdict_cooldown_remaining: number;
  interdictor_unlocked: BooleanLike;
  target_in_interdict_range: BooleanLike;
  target_in_force_dock_range: BooleanLike;
  target_in_missile_range: BooleanLike;
  is_admin: BooleanLike;
  debug_mode: BooleanLike;
  debug_interdictor: BooleanLike;
};

export const ShipCombatConsole = () => {
  const { data } = useBackend<Data>();
  const { connected, is_admin } = data;

  return (
    <Window width={420} height={580} title="Ship Combat">
      <Window.Content>
        {!connected ? (
          <NoticeBox danger>
            Not connected to ship systems. Install console on a valid ship.
          </NoticeBox>
        ) : (
          <Stack fill vertical>
            <Stack.Item>
              <TargetingPanel />
            </Stack.Item>
            <Stack.Item>
              <WeaponsPanel />
            </Stack.Item>
            <Stack.Item grow>
              <LaunchersPanel />
            </Stack.Item>
            {!!is_admin && (
              <Stack.Item>
                <DebugPanel />
              </Stack.Item>
            )}
          </Stack>
        )}
      </Window.Content>
    </Window>
  );
};

const TargetingPanel = () => {
  const { act, data } = useBackend<Data>();
  const {
    ship_name,
    target_name,
    target_ref,
    nearby_ships,
    target_in_missile_range,
  } = data;

  return (
    <Section
      title={
        <Box inline>
          <Icon name="crosshairs" mr={1} />
          Targeting
        </Box>
      }
      buttons={
        <Box color="label" fontSize="11px">
          {ship_name}
        </Box>
      }
    >
      <Stack vertical>
        {/* Current Target Display */}
        <Stack.Item>
          <Box
            p={1}
            mb={1}
            textAlign="center"
            backgroundColor={target_name ? 'rgba(219, 40, 40, 0.15)' : 'rgba(255,255,255,0.05)'}
            style={{ borderRadius: '4px' }}
          >
            {target_name ? (
              <Stack align="center" justify="center">
                <Stack.Item>
                  <Icon name="bullseye" color="bad" mr={1} />
                </Stack.Item>
                <Stack.Item>
                  <Box bold color="bad" fontSize="16px">
                    {target_name}
                  </Box>
                </Stack.Item>
                <Stack.Item ml={2}>
                  <Button
                    icon="times"
                    color="transparent"
                    onClick={() => act('clear_target')}
                  />
                </Stack.Item>
              </Stack>
            ) : (
              <Box color="label">No Target Selected</Box>
            )}
          </Box>
        </Stack.Item>

        {/* Ship List */}
        <Stack.Item>
          {nearby_ships.length === 0 ? (
            <Box color="label" textAlign="center" py={1}>
              No ships in sensor range
            </Box>
          ) : (
            <Stack vertical fill>
              {nearby_ships.map((ship) => (
                <Stack.Item key={ship.ref}>
                  <Button
                    fluid
                    icon={target_ref === ship.ref ? 'dot-circle' : 'circle'}
                    selected={target_ref === ship.ref}
                    onClick={() => act('select_target', { ref: ship.ref })}
                  >
                    {ship.name}
                  </Button>
                </Stack.Item>
              ))}
            </Stack>
          )}
        </Stack.Item>

        {/* Engage Button */}
        <Stack.Item mt={1}>
          <Button
            fluid
            bold
            icon="rocket"
            color="red"
            disabled={!target_name || !target_in_missile_range}
            onClick={() => act('activate')}
          >
            {!target_name
              ? 'Select Target'
              : !target_in_missile_range
                ? 'Out of Range'
                : 'ENGAGE'}
          </Button>
        </Stack.Item>
      </Stack>
    </Section>
  );
};

const WeaponsPanel = () => {
  const { act, data } = useBackend<Data>();
  const {
    target_ref,
    interdiction_active,
    interdict_cooldown_active,
    interdict_cooldown_remaining,
    interdictor_unlocked,
    target_in_interdict_range,
    target_in_force_dock_range,
  } = data;

  if (!interdictor_unlocked) {
    return (
      <Section
        title={
          <Box inline>
            <Icon name="satellite-dish" mr={1} />
            Interdictor
          </Box>
        }
      >
        <Box color="label" textAlign="center">
          <Icon name="lock" mr={1} />
          Research Required
        </Box>
      </Section>
    );
  }

  const canInterdict =
    target_ref &&
    target_in_interdict_range &&
    !interdiction_active &&
    !interdict_cooldown_active;

  const canForceDock = interdiction_active && target_in_force_dock_range;

  // Build tooltip for Slow button
  const getSlowTooltip = () => {
    if (interdiction_active) {
      return 'Interdiction field is already active';
    }
    if (!target_ref) {
      return 'Select a target ship first';
    }
    if (!target_in_interdict_range) {
      return 'Target is too far away - get closer to interdict';
    }
    if (interdict_cooldown_active) {
      return 'Interdictor is recharging';
    }
    return 'Activate interdiction field to slow target ship by 50%';
  };

  // Build tooltip for Force Dock button
  const getForceDockTooltip = () => {
    if (!interdiction_active) {
      return 'Must slow the target first before force docking';
    }
    if (!target_in_force_dock_range) {
      return 'Must be on the same tile as target to force dock';
    }
    return 'Force the target ship to dock with yours';
  };

  return (
    <Section
      title={
        <Box inline>
          <Icon name="satellite-dish" mr={1} />
          Interdictor
        </Box>
      }
    >
      {interdict_cooldown_active && !interdiction_active ? (
        <ProgressBar
          value={1 - interdict_cooldown_remaining / 3000}
          ranges={{
            bad: [0, 0.4],
            average: [0.4, 0.8],
            good: [0.8, 1],
          }}
        >
          Recharging - {Math.ceil(interdict_cooldown_remaining / 10)}s
        </ProgressBar>
      ) : (
        <Stack vertical>
          {!!interdiction_active && (
            <Stack.Item>
              <NoticeBox warning>
                <Icon name="bolt" mr={1} />
                INTERDICTION ACTIVE
              </NoticeBox>
            </Stack.Item>
          )}
          <Stack.Item>
            <Stack>
              <Stack.Item grow>
                <Button
                  fluid
                  icon="satellite-dish"
                  disabled={!!interdiction_active || !canInterdict}
                  color={interdiction_active ? 'average' : 'default'}
                  tooltip={getSlowTooltip()}
                  onClick={() => act('start_interdict')}
                >
                  {interdiction_active
                    ? 'Slowing'
                    : !target_ref
                      ? 'No Target'
                      : !target_in_interdict_range
                        ? 'Out of Range'
                        : 'Slow'}
                </Button>
              </Stack.Item>
              <Stack.Item grow>
                <Button
                  fluid
                  icon="link"
                  color="red"
                  disabled={!canForceDock}
                  tooltip={getForceDockTooltip()}
                  onClick={() => act('force_dock')}
                >
                  {!interdiction_active
                    ? 'Slow First'
                    : !target_in_force_dock_range
                      ? 'Get Closer'
                      : 'Force Dock'}
                </Button>
              </Stack.Item>
              {!!interdiction_active && (
                <Stack.Item>
                  <Button
                    icon="times"
                    color="bad"
                    tooltip="Cancel interdiction"
                    onClick={() => act('cancel_interdict')}
                  />
                </Stack.Item>
              )}
            </Stack>
          </Stack.Item>
        </Stack>
      )}
    </Section>
  );
};

const LaunchersPanel = () => {
  const { data } = useBackend<Data>();
  const { launchers, launchers_ready, launchers_total } = data;

  const missilesLoaded = launchers.filter((l) => l.loaded).length;

  return (
    <Section
      fill
      scrollable
      title={
        <Box inline>
          <Icon name="rocket" mr={1} />
          Launchers
        </Box>
      }
      buttons={
        <Box color="label" fontSize="11px">
          {missilesLoaded} loaded | {launchers_ready}/{launchers_total} ready
        </Box>
      }
    >
      {launchers.length === 0 ? (
        <Box color="label" textAlign="center" py={2}>
          <Icon name="unlink" size={2} mb={1} />
          <br />
          No launchers linked
        </Box>
      ) : (
        <Stack vertical>
          {launchers.map((launcher) => (
            <Stack.Item key={launcher.id}>
              <Stack align="center" py={0.5}>
                <Stack.Item basis="60px">
                  <Box color="label" fontSize="11px">
                    {launcher.id}
                  </Box>
                </Stack.Item>
                <Stack.Item grow>
                  {launcher.loaded ? (
                    <Box color="good" fontSize="12px">
                      {launcher.missile_name}
                      <Box as="span" color="label" ml={1}>
                        ({launcher.missile_damage})
                      </Box>
                    </Box>
                  ) : (
                    <Box color="bad" fontSize="12px">
                      Empty
                    </Box>
                  )}
                </Stack.Item>
                <Stack.Item basis="70px">
                  {launcher.ready ? (
                    <Box color="good" textAlign="right">
                      <Icon name="check" /> Ready
                    </Box>
                  ) : launcher.cooldown ? (
                    <ProgressBar
                      value={1 - launcher.cooldown_time / 50}
                      ranges={{
                        good: [0.8, 1],
                        average: [0.4, 0.8],
                        bad: [0, 0.4],
                      }}
                    />
                  ) : (
                    <Box color="bad" textAlign="right">
                      Offline
                    </Box>
                  )}
                </Stack.Item>
              </Stack>
            </Stack.Item>
          ))}
        </Stack>
      )}
    </Section>
  );
};

const DebugPanel = () => {
  const { act, data } = useBackend<Data>();
  const { debug_mode, debug_interdictor } = data;

  return (
    <Collapsible title="Admin Debug" color="purple">
      <Section>
        <LabeledList>
          <LabeledList.Item label="Debug Mode">
            <Button
              icon={debug_mode ? 'toggle-on' : 'toggle-off'}
              color={debug_mode ? 'good' : 'bad'}
              onClick={() => act('toggle_debug')}
            >
              {debug_mode ? 'On' : 'Off'}
            </Button>
          </LabeledList.Item>
          {!!debug_mode && (
            <LabeledList.Item label="Interdictor">
              <Button
                icon={debug_interdictor ? 'check-square' : 'square'}
                color={debug_interdictor ? 'good' : 'default'}
                onClick={() => act('toggle_debug_interdictor')}
              >
                {debug_interdictor ? 'Unlocked' : 'Locked'}
              </Button>
            </LabeledList.Item>
          )}
        </LabeledList>
      </Section>
    </Collapsible>
  );
};
