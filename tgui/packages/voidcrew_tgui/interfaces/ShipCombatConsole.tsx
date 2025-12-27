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
  Slider,
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

type Turret = {
  id: string;
  name: string;
  power_level: number;
  damage: number;
  cooldown: number;
  power_per_shot: number;
  ready: BooleanLike;
  on_exterior: BooleanLike;
  cooldown_remaining: number;
  cell_charge: number;
  cell_max: number;
};

type Data = {
  connected: BooleanLike;
  ship_name: string | null;
  cloak_active: BooleanLike;
  attack_mode: BooleanLike;
  is_in_attack_mode: BooleanLike;
  target_name: string | null;
  target_ref: string | null;
  // Targeting lock-in-progress data
  is_targeting: BooleanLike;
  targeting_ship_name: string | null;
  targeting_ship_ref: string | null;
  targeting_progress: number;
  targeting_time_remaining: number;
  nearby_ships: NearbyShip[];
  launchers: Launcher[];
  launchers_ready: number;
  launchers_total: number;
  // Laser turret data
  turrets: Turret[];
  turrets_ready: number;
  turrets_total: number;
  turret_power_level: number;
  turret_power_available: number;
  turret_power_max: number;
  // Interdictor data
  interdictor_linked: BooleanLike;
  interdictor_unlocked: BooleanLike;
  interdiction_active: BooleanLike;
  interdiction_warming_up: BooleanLike;
  interdiction_warmup_progress: number;
  interdictor_power_level: number;
  interdictor_power_draw: number;
  interdictor_target_name: string | null;
  interdictor_target_speed_cap: number | null;
  interdict_cooldown_active: BooleanLike;
  interdict_cooldown_remaining: number;
  interdictor_ready: BooleanLike;
  being_interdicted: BooleanLike;
  our_interdiction_strength: number;
  target_in_interdict_range: BooleanLike;
  target_in_force_dock_range: BooleanLike;
  target_in_missile_range: BooleanLike;
  // Shield data
  shield_linked: BooleanLike;
  shield_unlocked: BooleanLike;
  shield_active: BooleanLike;
  shield_broken: BooleanLike;
  shield_health: number;
  shield_max_health: number;
  shield_overhealth: number;
  shield_power_allocation: number;
  shield_regen_rate: number;
  shield_power_draw: number;
  shield_efficiency: number;
  shield_cooldown_active: BooleanLike;
  shield_cooldown_remaining: number;
  // Admin
  is_admin: BooleanLike;
  debug_mode: BooleanLike;
  debug_interdictor: BooleanLike;
  debug_shields: BooleanLike;
};

export const ShipCombatConsole = () => {
  const { data } = useBackend<Data>();
  const { connected, is_admin } = data;

  return (
    <Window width={400} height={600} title="Ship Combat">
      <Window.Content scrollable>
        {!connected ? (
          <NoticeBox danger>
            Not connected to ship systems. Install console on a valid ship.
          </NoticeBox>
        ) : (
          <Stack vertical>
            <Stack.Item>
              <TargetingPanel />
            </Stack.Item>
            <Stack.Item>
              <ShieldsPanel />
            </Stack.Item>
            <Stack.Item>
              <WeaponsPanel />
            </Stack.Item>
            <Stack.Item>
              <TurretsPanel />
            </Stack.Item>
            <Stack.Item>
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
    is_targeting,
    targeting_ship_name,
    targeting_progress,
    targeting_time_remaining,
    is_in_attack_mode,
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
        {/* Targeting Lock In Progress */}
        {!!is_targeting && (
          <Stack.Item>
            <Box
              p={1}
              mb={1}
              backgroundColor="rgba(255, 165, 0, 0.2)"
              style={{ borderRadius: '4px' }}
            >
              <Stack vertical>
                <Stack.Item>
                  <Stack align="center" justify="center">
                    <Stack.Item>
                      <Icon name="spinner" spin color="average" mr={1} />
                    </Stack.Item>
                    <Stack.Item>
                      <Box bold color="average">
                        ACQUIRING LOCK: {targeting_ship_name}
                      </Box>
                    </Stack.Item>
                    <Stack.Item ml={2}>
                      <Button
                        icon="times"
                        color="transparent"
                        tooltip="Cancel targeting"
                        onClick={() => act('cancel_targeting')}
                      />
                    </Stack.Item>
                  </Stack>
                </Stack.Item>
                <Stack.Item>
                  <ProgressBar value={(targeting_progress || 0) / 100} color="blue">
                    {targeting_time_remaining.toFixed(1)}s remaining
                  </ProgressBar>
                </Stack.Item>
              </Stack>
            </Box>
          </Stack.Item>
        )}

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

        {/* Attack Mode Indicator */}
        {!!is_in_attack_mode && (
          <Stack.Item>
            <NoticeBox warning>
              <Icon name="crosshairs" mr={1} />
              TARGETING ACTIVE - Move view to aim, use action buttons to fire
            </NoticeBox>
          </Stack.Item>
        )}

        {/* Engage/Exit Button */}
        <Stack.Item mt={1}>
          {is_in_attack_mode ? (
            <Button
              fluid
              bold
              icon="times"
              color="grey"
              onClick={() => act('deactivate')}
            >
              EXIT TARGETING
            </Button>
          ) : (
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
          )}
        </Stack.Item>
      </Stack>
    </Section>
  );
};

const ShieldsPanel = () => {
  const { act, data } = useBackend<Data>();
  const {
    shield_linked,
    shield_unlocked,
    shield_active,
    shield_broken,
    shield_health,
    shield_max_health,
    shield_overhealth,
    shield_power_allocation,
    shield_regen_rate,
    shield_power_draw,
    shield_efficiency,
    shield_cooldown_active,
    shield_cooldown_remaining,
  } = data;

  // Hide entirely when not unlocked
  if (!shield_unlocked) {
    return null;
  }

  // No generator linked - minimal display
  if (!shield_linked) {
    return (
      <Section
        title={
          <Box inline>
            <Icon name="shield-halved" mr={1} />
            Shields
            <Box inline color="label" ml={1} fontSize="11px">
              NO GENERATOR
            </Box>
          </Box>
        }
      />
    );
  }

  // Calculate health percentage for display
  const healthPercent = shield_max_health
    ? shield_health / shield_max_health
    : 0;
  const powerPercent = Math.round((shield_power_allocation ?? 1) * 100);

  // Cooldown display - compact recharging state
  if (shield_broken && shield_cooldown_active) {
    const cooldownSeconds = Math.ceil((shield_cooldown_remaining || 0) / 10);
    const cooldownProgress = 1 - (shield_cooldown_remaining || 0) / 300;

    return (
      <Section
        title={
          <Box inline>
            <Icon name="shield-halved" mr={1} />
            Shields
            <Box inline color="bad" ml={1} fontSize="11px">
              RECHARGING - {cooldownSeconds}s
            </Box>
          </Box>
        }
      >
        <ProgressBar
          value={cooldownProgress}
          ranges={{
            bad: [0, 0.4],
            average: [0.4, 0.8],
            good: [0.8, 1],
          }}
        />
      </Section>
    );
  }

  // Shields OFF - minimal collapsible display
  if (powerPercent === 0 && !shield_active) {
    return (
      <Section
        title={
          <Box inline>
            <Icon name="shield-halved" mr={1} />
            Shields
            <Box inline color="label" ml={1} fontSize="11px">
              OFF
            </Box>
          </Box>
        }
      >
        <Slider
          value={powerPercent}
          minValue={0}
          maxValue={200}
          step={10}
          stepPixelSize={4}
          format={(v) => `${v}%`}
          onChange={(e, value) => act('set_shield_power', { power: value })}
        />
      </Section>
    );
  }

  // Active/Charging shields - full display
  return (
    <Section
      title={
        <Box inline>
          <Icon name="shield-halved" mr={1} />
          Shields
          <Box
            inline
            color={shield_active ? 'good' : 'average'}
            ml={1}
            fontSize="11px"
          >
            {shield_active ? 'ACTIVE' : 'CHARGING'}
          </Box>
        </Box>
      }
    >
      <Stack vertical>
        {/* Health Bar */}
        <Stack.Item>
          <ProgressBar
            value={healthPercent}
            ranges={{
              bad: [0, 0.25],
              average: [0.25, 0.5],
              good: [0.5, 1],
            }}
          >
            <Box inline>
              {shield_health || 0} / {shield_max_health || 0}
              {shield_overhealth > 0 && (
                <Box inline color="cyan" ml={1}>
                  (+{Math.round(shield_overhealth)})
                </Box>
              )}
            </Box>
          </ProgressBar>
        </Stack.Item>

        {/* Power Allocation Slider */}
        <Stack.Item>
          <Box fontSize="11px" color="label">
            Power: {powerPercent}%
            {powerPercent > 100 && shield_health >= shield_max_health && (
              <Box inline color="cyan" ml={1}>
                +overhealth
              </Box>
            )}
          </Box>
          <Slider
            value={powerPercent}
            minValue={0}
            maxValue={200}
            step={10}
            stepPixelSize={4}
            format={(v) => `${v}%`}
            disabled={!!shield_broken}
            onChange={(e, value) => act('set_shield_power', { power: value })}
          />
        </Stack.Item>

        {/* Stats Row - more compact */}
        <Stack.Item>
          <Box fontSize="11px" color="label">
            <Icon name="bolt" mr={0.5} />
            {shield_power_draw || 0}W
            <Box inline ml={2}>
              <Icon name="arrow-up" mr={0.5} />
              {shield_regen_rate || 0}/s
            </Box>
          </Box>
        </Stack.Item>
      </Stack>
    </Section>
  );
};

const WeaponsPanel = () => {
  const { act, data } = useBackend<Data>();
  const {
    target_ref,
    interdictor_linked,
    interdictor_unlocked,
    interdiction_active,
    interdiction_warming_up,
    interdiction_warmup_progress,
    interdictor_power_level,
    interdictor_power_draw,
    interdictor_target_name,
    interdictor_target_speed_cap,
    interdict_cooldown_active,
    interdict_cooldown_remaining,
    interdictor_ready,
    being_interdicted,
    our_interdiction_strength,
    target_in_interdict_range,
    target_in_force_dock_range,
  } = data;

  // Hide entirely when not unlocked
  if (!interdictor_unlocked) {
    return null;
  }

  const powerPercent = Math.round((interdictor_power_level ?? 1) * 100);

  // Show if WE are being interdicted
  if (being_interdicted) {
    return (
      <Section
        title={
          <Box inline>
            <Icon name="satellite-dish" mr={1} />
            Interdictor
            <Box inline color="bad" ml={1} fontSize="11px">
              BEING INTERDICTED
            </Box>
          </Box>
        }
      >
        <NoticeBox danger>
          <Icon name="exclamation-triangle" mr={1} />
          INTERDICTION FIELD ACTIVE - Engines at {100 - (our_interdiction_strength || 0)}%
        </NoticeBox>
      </Section>
    );
  }

  // No interdictor linked
  if (!interdictor_linked) {
    return (
      <Section
        title={
          <Box inline>
            <Icon name="satellite-dish" mr={1} />
            Interdictor
            <Box inline color="label" ml={1} fontSize="11px">
              NOT LINKED
            </Box>
          </Box>
        }
      >
        <Box color="label" textAlign="center">
          <Icon name="unlink" mr={1} />
          No interdictor linked. Use a multitool to link.
        </Box>
      </Section>
    );
  }

  const canInterdict =
    target_ref &&
    target_in_interdict_range &&
    !interdiction_active &&
    !interdiction_warming_up &&
    !interdict_cooldown_active &&
    interdictor_ready;

  const canForceDock = interdiction_active && target_in_force_dock_range;

  // Cooldown state
  if (interdict_cooldown_active && !interdiction_active && !interdiction_warming_up) {
    return (
      <Section
        title={
          <Box inline>
            <Icon name="satellite-dish" mr={1} />
            Interdictor
            <Box inline color="average" ml={1} fontSize="11px">
              RECHARGING
            </Box>
          </Box>
        }
      >
        <ProgressBar
          value={1 - interdict_cooldown_remaining / 3000}
          ranges={{
            bad: [0, 0.4],
            average: [0.4, 0.8],
            good: [0.8, 1],
          }}
        >
          {Math.ceil(interdict_cooldown_remaining / 10)}s
        </ProgressBar>
      </Section>
    );
  }

  // Warmup state
  if (interdiction_warming_up) {
    return (
      <Section
        title={
          <Box inline>
            <Icon name="satellite-dish" mr={1} />
            Interdictor
            <Box inline color="average" ml={1} fontSize="11px">
              LOCKING
            </Box>
          </Box>
        }
      >
        <Stack vertical>
          <Stack.Item>
            <Box bold textAlign="center" color="average" mb={1}>
              <Icon name="spinner" spin mr={1} />
              Acquiring lock on {interdictor_target_name}...
            </Box>
          </Stack.Item>
          <Stack.Item>
            <ProgressBar value={interdiction_warmup_progress || 0} color="blue">
              {Math.round((interdiction_warmup_progress || 0) * 100)}%
            </ProgressBar>
          </Stack.Item>
          <Stack.Item mt={1}>
            <Button
              fluid
              icon="times"
              color="bad"
              onClick={() => act('cancel_interdict')}
            >
              Cancel
            </Button>
          </Stack.Item>
        </Stack>
      </Section>
    );
  }

  // Active interdiction
  if (interdiction_active) {
    return (
      <Section
        title={
          <Box inline>
            <Icon name="satellite-dish" mr={1} />
            Interdictor
            <Box inline color="orange" ml={1} fontSize="11px">
              ACTIVE
            </Box>
          </Box>
        }
      >
        <Stack vertical>
          {/* Target Info */}
          <Stack.Item>
            <Box bold color="orange" textAlign="center">
              {interdictor_target_name} - Speed capped at {interdictor_target_speed_cap}%
            </Box>
          </Stack.Item>

          {/* Power Slider */}
          <Stack.Item>
            <Box fontSize="11px" color="label" mb={0.5}>
              <Icon name="bolt" mr={0.5} />
              Power: {powerPercent}% ({interdictor_power_draw}W)
            </Box>
            <Slider
              value={powerPercent}
              minValue={25}
              maxValue={200}
              step={25}
              stepPixelSize={8}
              format={(v) => `${v}%`}
              onChange={(e, value) => act('set_interdictor_power', { power: value })}
            />
          </Stack.Item>

          {/* Action Buttons */}
          <Stack.Item>
            <Stack>
              <Stack.Item grow>
                <Button
                  fluid
                  icon="link"
                  color="red"
                  disabled={!canForceDock}
                  tooltip={
                    !target_in_force_dock_range
                      ? 'Must be on the same tile as target'
                      : 'Force the target ship to dock with yours'
                  }
                  onClick={() => act('force_dock')}
                >
                  {!target_in_force_dock_range ? 'Get Closer' : 'Force Dock'}
                </Button>
              </Stack.Item>
              <Stack.Item>
                <Button
                  icon="times"
                  color="bad"
                  tooltip="Cancel interdiction"
                  onClick={() => act('cancel_interdict')}
                />
              </Stack.Item>
            </Stack>
          </Stack.Item>
        </Stack>
      </Section>
    );
  }

  // Ready state - show power slider and buttons
  return (
    <Section
      title={
        <Box inline>
          <Icon name="satellite-dish" mr={1} />
          Interdictor
        </Box>
      }
    >
      <Stack vertical>
        {/* Power Slider */}
        <Stack.Item>
          <Box fontSize="11px" color="label" mb={0.5}>
            <Icon name="bolt" mr={0.5} />
            Power: {powerPercent}%
            {powerPercent > 100 && (
              <Box inline color="orange" ml={1}>
                - High power mode
              </Box>
            )}
          </Box>
          <Slider
            value={powerPercent}
            minValue={25}
            maxValue={200}
            step={25}
            stepPixelSize={8}
            format={(v) => `${v}%`}
            onChange={(e, value) => act('set_interdictor_power', { power: value })}
          />
        </Stack.Item>

        {/* Action Buttons */}
        <Stack.Item>
          <Stack>
            <Stack.Item grow>
              <Button
                fluid
                icon="satellite-dish"
                disabled={!canInterdict}
                tooltip={
                  !target_ref
                    ? 'Select a target ship first'
                    : !target_in_interdict_range
                      ? 'Target is too far away'
                      : 'Slow target ship'
                }
                onClick={() => act('start_interdict')}
              >
                {!target_ref
                  ? 'No Target'
                  : !target_in_interdict_range
                    ? 'Out of Range'
                    : 'Interdict'}
              </Button>
            </Stack.Item>
            <Stack.Item grow>
              <Button fluid icon="link" color="red" disabled tooltip="Interdict first">
                Force Dock
              </Button>
            </Stack.Item>
          </Stack>
        </Stack.Item>
      </Stack>
    </Section>
  );
};

const TurretsPanel = () => {
  const { act, data } = useBackend<Data>();
  const {
    turrets,
    turrets_ready,
    turrets_total,
    turret_power_level,
    turret_power_available,
    turret_power_max,
  } = data;

  const powerPercent = Math.round((turret_power_level ?? 1) * 100);
  const powerRatio = turret_power_max > 0 ? turret_power_available / turret_power_max : 0;

  return (
    <Section
      title={
        <Box inline>
          <Icon name="bolt" mr={1} />
          Laser Turrets
        </Box>
      }
      buttons={
        <Box color="label" fontSize="11px">
          {turrets_ready}/{turrets_total} ready
        </Box>
      }
    >
      {turrets.length === 0 ? (
        <Box color="label" textAlign="center" py={1}>
          <Icon name="unlink" mr={1} />
          No turrets linked
        </Box>
      ) : (
        <Stack vertical>
          {/* Total Power Bar */}
          <Stack.Item>
            <Box mb={0.5} fontSize="11px" color="label">
              <Icon name="battery-half" mr={0.5} />
              Available Power
            </Box>
            <ProgressBar
              value={powerRatio}
              ranges={{
                bad: [0, 0.25],
                average: [0.25, 0.5],
                good: [0.5, 1],
              }}
            >
              {turret_power_available} / {turret_power_max}
            </ProgressBar>
          </Stack.Item>

          {/* Power Level Slider */}
          <Stack.Item>
            <Box mb={0.5} fontSize="11px" color="label">
              Power Level ({powerPercent.toFixed(0)}%)
              {powerPercent > 100 && (
                <Box inline color="orange" ml={1}>
                  - High power mode
                </Box>
              )}
            </Box>
            <Slider
              value={powerPercent}
              minValue={25}
              maxValue={200}
              step={25}
              stepPixelSize={8}
              format={(v) => `${v}%`}
              onChange={(e, value) => act('set_turret_power', { power: value })}
            />
          </Stack.Item>

          {/* Stats Row */}
          <Stack.Item>
            <Stack fontSize="11px" color="label" mt={0.5}>
              <Stack.Item grow>
                <Icon name="crosshairs" mr={0.5} />
                {Math.round(50 * turret_power_level)} dmg
              </Stack.Item>
              <Stack.Item grow>
                <Icon name="bolt" mr={0.5} />
                {Math.round(2000 * turret_power_level)}W/shot
              </Stack.Item>
              <Stack.Item grow>
                <Icon name="shield-halved" mr={0.5} color="cyan" />
                1.5x vs shields
              </Stack.Item>
            </Stack>
          </Stack.Item>

          {/* Turret List */}
          <Stack.Item>
            <Collapsible title={`Turret Status (${turrets.length})`}>
              <Stack vertical>
                {turrets.map((turret) => (
                  <Stack.Item key={turret.id}>
                    <Stack
                      align="center"
                      py={0.5}
                      style={{
                        opacity: turret.on_exterior ? 1 : 0.5,
                      }}
                    >
                      <Stack.Item basis="60px">
                        <Box color="label" fontSize="11px">
                          {turret.id}
                        </Box>
                      </Stack.Item>
                      <Stack.Item grow>
                        {turret.on_exterior ? (
                          <Box color="cyan" fontSize="12px">
                            {turret.damage} dmg
                            <Box as="span" color="label" ml={1}>
                              ({turret.power_per_shot}W)
                            </Box>
                          </Box>
                        ) : (
                          <Box color="bad" fontSize="12px">
                            <Icon name="triangle-exclamation" mr={0.5} />
                            Not on exterior
                          </Box>
                        )}
                      </Stack.Item>
                      <Stack.Item basis="70px">
                        {!turret.on_exterior ? (
                          <Box color="bad" textAlign="right">
                            Disabled
                          </Box>
                        ) : turret.ready ? (
                          <Box color="good" textAlign="right">
                            <Icon name="check" /> Ready
                          </Box>
                        ) : turret.cooldown_remaining > 0 ? (
                          <ProgressBar
                            value={1 - turret.cooldown_remaining / turret.cooldown}
                            ranges={{
                              good: [0.8, 1],
                              average: [0.4, 0.8],
                              bad: [0, 0.4],
                            }}
                          />
                        ) : turret.cell_charge < turret.power_per_shot ? (
                          <ProgressBar
                            value={turret.cell_charge / turret.power_per_shot}
                            color="yellow"
                          >
                            Charging
                          </ProgressBar>
                        ) : (
                          <Box color="bad" textAlign="right">
                            Error
                          </Box>
                        )}
                      </Stack.Item>
                    </Stack>
                  </Stack.Item>
                ))}
              </Stack>
            </Collapsible>
          </Stack.Item>
        </Stack>
      )}
    </Section>
  );
};

const LaunchersPanel = () => {
  const { data } = useBackend<Data>();
  const { launchers, launchers_ready, launchers_total } = data;

  const loadedLaunchers = launchers.filter((l) => l.loaded);
  const missilesLoaded = loadedLaunchers.length;

  // No launchers linked
  if (launchers.length === 0) {
    return (
      <Section
        title={
          <Box inline>
            <Icon name="rocket" mr={1} />
            Launchers
            <Box inline color="label" ml={1} fontSize="11px">
              NONE
            </Box>
          </Box>
        }
      >
        <Box color="label" textAlign="center">
          <Icon name="unlink" mr={1} />
          No launchers linked
        </Box>
      </Section>
    );
  }

  // All launchers empty - show compact dot display
  if (missilesLoaded === 0) {
    return (
      <Section
        title={
          <Box inline>
            <Icon name="rocket" mr={1} />
            Launchers
            <Box inline color="label" ml={1} fontSize="11px">
              {launchers.map((l, i) => (
                <Icon
                  key={l.id}
                  name="circle"
                  size={0.8}
                  color="bad"
                  ml={i > 0 ? 0.5 : 1}
                />
              ))}
              <Box inline ml={1}>0/{launchers.length}</Box>
            </Box>
          </Box>
        }
      />
    );
  }

  // Has loaded missiles - show details
  return (
    <Section
      title={
        <Box inline>
          <Icon name="rocket" mr={1} />
          Launchers
          <Box inline ml={1} fontSize="11px">
            {launchers.map((l, i) => (
              <Icon
                key={l.id}
                name="circle"
                size={0.8}
                color={l.loaded ? (l.ready ? 'good' : 'average') : 'bad'}
                ml={i > 0 ? 0.5 : 1}
              />
            ))}
            <Box inline color="label" ml={1}>
              {launchers_ready}/{launchers_total}
            </Box>
          </Box>
        </Box>
      }
    >
      <Stack vertical>
        {loadedLaunchers.map((launcher) => (
          <Stack.Item key={launcher.id}>
            <Stack align="center">
              <Stack.Item grow>
                <Box color="good" fontSize="12px">
                  {launcher.missile_name}
                  <Box as="span" color="label" ml={1}>
                    ({launcher.missile_damage} dmg)
                  </Box>
                </Box>
              </Stack.Item>
              <Stack.Item basis="60px">
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
                  <Box color="average" textAlign="right">
                    Loading
                  </Box>
                )}
              </Stack.Item>
            </Stack>
          </Stack.Item>
        ))}
      </Stack>
    </Section>
  );
};

const DebugPanel = () => {
  const { act, data } = useBackend<Data>();
  const { debug_mode, debug_interdictor, debug_shields } = data;

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
            <>
              <LabeledList.Item label="Interdictor">
                <Button
                  icon={debug_interdictor ? 'check-square' : 'square'}
                  color={debug_interdictor ? 'good' : 'default'}
                  onClick={() => act('toggle_debug_interdictor')}
                >
                  {debug_interdictor ? 'Unlocked' : 'Locked'}
                </Button>
              </LabeledList.Item>
              <LabeledList.Item label="Shields">
                <Button
                  icon={debug_shields ? 'check-square' : 'square'}
                  color={debug_shields ? 'good' : 'default'}
                  onClick={() => act('toggle_debug_shields')}
                >
                  {debug_shields ? 'Unlocked' : 'Locked'}
                </Button>
              </LabeledList.Item>
            </>
          )}
        </LabeledList>
      </Section>
    </Collapsible>
  );
};
