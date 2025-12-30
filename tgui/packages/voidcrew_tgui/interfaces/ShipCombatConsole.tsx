import { useMemo, useState } from 'react';
import { type BooleanLike } from 'tgui-core/react';
import {
  Box,
  Button,
  Collapsible,
  Dropdown,
  Icon,
  LabeledList,
  NoticeBox,
  ProgressBar,
  Section,
  Slider,
  Stack,
  Tabs,
} from 'tgui-core/components';

import { useBackend } from '../backend';
import { Window } from '../layouts';

// Stock part tier names
const CAPACITOR_NAMES = ['Basic', 'Advanced', 'Super', 'Quadratic'];
const LASER_NAMES = ['Basic', 'High-Power', 'Ultra', 'Quad-Ultra'];
const SCANNER_NAMES = ['Basic', 'Advanced', 'Phasic', 'Triphasic'];

// Get part name from tier (tier is usually sum of all parts, so divide by count)
const getPartName = (tier: number, names: string[]): string => {
  const index = Math.min(Math.max(Math.round(tier) - 1, 0), names.length - 1);
  return names[index] || names[0];
};

// Render tier dots component
const TierDots = ({ tier, maxTier = 4 }: { tier: number; maxTier?: number }) => {
  const filled = Math.min(Math.round(tier), maxTier);
  return (
    <Box inline ml={0.5}>
      {Array.from({ length: maxTier }, (_, i) => (
        <Box
          key={i}
          inline
          color={i < filled ? 'good' : 'label'}
          style={{ fontSize: '8px', marginRight: '1px' }}
        >
          {i < filled ? '●' : '○'}
        </Box>
      ))}
    </Box>
  );
};

// Compact upgrade display: "Name: PartName ●●●○"
const UpgradeDisplay = ({
  label,
  tier,
  names,
}: {
  label: string;
  tier: number;
  names: string[];
}) => (
  <Box inline fontSize="9px" mr={1}>
    <Box inline color="label">{label}:</Box>
    <Box inline color="white" ml={0.5}>{getPartName(tier, names)}</Box>
    <TierDots tier={tier} />
  </Box>
);

// Simple upgrade display with just dots: "Cap: ●●●○"
const SimpleUpgradeDisplay = ({
  label,
  tier,
}: {
  label: string;
  tier: number;
}) => (
  <Box inline fontSize="9px" mr={1}>
    <Box inline color="label">{label}:</Box>
    <TierDots tier={tier} />
  </Box>
);

type NearbyShip = {
  name: string;
  ref: string;
  shields: number;
  shields_max: number;
  integrity: number;
  integrity_max: number;
  distance: number;
  speed: number;
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
  on_exterior: BooleanLike;
  enabled: BooleanLike;
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
  upgrades: {
    capacitor_tier: number;
    laser_tier: number;
    servo_tier: number;
  };
};

type ShieldGenerator = {
  id: string;
  name: string;
  active: BooleanLike;
  health: number;
  max_health: number;
  upgrades: {
    capacitor_tier: number;
    laser_tier: number;
    servo_tier: number;
  };
};

type CloakDevice = {
  active: BooleanLike;
  can_activate: BooleanLike;
  duration_remaining: number;
  duration_max: number;
  cooldown_remaining: number;
  cooldown_max: number;
  upgrades: {
    capacitor_tier: number;
    laser_tier: number;
    scanning_tier: number;
  };
};

type Data = {
  connected: BooleanLike;
  ship_name: string | null;
  ship_docked: BooleanLike;
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
  // Shield generators list
  shield_generators: ShieldGenerator[];
  // Cloak device
  cloak_device: CloakDevice | null;
  cloak_unlocked: BooleanLike;
  // Theme
  theme?: string;
};

export const ShipCombatConsole = () => {
  const { data } = useBackend<Data>();
  const { connected, theme } = data;
  const [activeTab, setActiveTab] = useState(0);

  return (
    <Window width={380} height={520} title="Weapons System" theme={theme}>
      <Window.Content scrollable>
        {!connected ? (
          <NoticeBox danger>
            Not connected to ship systems. Install console on a valid ship.
          </NoticeBox>
        ) : (
          <Stack vertical fill>
            <Stack.Item>
              <Tabs fluid>
                <Tabs.Tab
                  selected={activeTab === 0}
                  onClick={() => setActiveTab(0)}
                  icon="crosshairs"
                >
                  Targeting
                </Tabs.Tab>
                <Tabs.Tab
                  selected={activeTab === 1}
                  onClick={() => setActiveTab(1)}
                  icon="shield-halved"
                >
                  Equipment
                </Tabs.Tab>
                <Tabs.Tab
                  selected={activeTab === 2}
                  onClick={() => setActiveTab(2)}
                  icon="rocket"
                >
                  Weapons
                </Tabs.Tab>
                <Tabs.Tab
                  selected={activeTab === 3}
                  onClick={() => setActiveTab(3)}
                  icon="cog"
                >
                  Settings
                </Tabs.Tab>
              </Tabs>
            </Stack.Item>
            <Stack.Item grow>
              {activeTab === 0 && <TargetingTab />}
              {activeTab === 1 && <EquipmentTab />}
              {activeTab === 2 && <WeaponsTab />}
              {activeTab === 3 && <SettingsTab />}
            </Stack.Item>
          </Stack>
        )}
      </Window.Content>
    </Window>
  );
};

// ============================================================================
// TARGETING TAB
// ============================================================================

const TargetingTab = () => {
  return (
    <Stack vertical>
      <Stack.Item>
        <TargetingPanel />
      </Stack.Item>
    </Stack>
  );
};

const TargetingPanel = () => {
  const { act, data } = useBackend<Data>();
  const {
    ship_docked,
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

  // Find the currently targeted ship for status display
  const targetShip = target_ref && nearby_ships ? nearby_ships.find((s) => s.ref === target_ref) : null;

  // Memoize the filtered list of other ships to avoid filtering on every render
  const otherShips = useMemo(
    () => (nearby_ships ? nearby_ships.filter((s) => s.ref !== target_ref) : []),
    [nearby_ships, target_ref]
  );

  // Show docked notice
  if (ship_docked) {
    return (
      <Stack vertical>
        <Stack.Item>
          <NoticeBox info>
            <Icon name="anchor" mr={1} />
            Targeting unavailable while docked
          </NoticeBox>
        </Stack.Item>
      </Stack>
    );
  }

  return (
    <Stack vertical>
      {/* Targeting Lock In Progress */}
      {!!is_targeting && (
        <Stack.Item>
          <Box
            p={0.5}
            mb={0.5}
            backgroundColor="rgba(255, 165, 0, 0.2)"
            style={{ borderRadius: '3px' }}
          >
            <Stack vertical>
              <Stack.Item>
                <Stack align="center" justify="center">
                  <Stack.Item>
                    <Icon name="spinner" spin color="average" mr={1} />
                  </Stack.Item>
                  <Stack.Item>
                    <Box bold color="average" fontSize="11px">
                      ACQUIRING: {targeting_ship_name}
                    </Box>
                  </Stack.Item>
                  <Stack.Item ml={1}>
                    <Button
                      icon="times"
                      color="transparent"
                      compact
                      aria-label="Cancel targeting"
                      onClick={() => act('cancel_targeting')}
                    />
                  </Stack.Item>
                </Stack>
              </Stack.Item>
              <Stack.Item>
                <ProgressBar value={(targeting_progress || 0) / 100} color="blue">
                  {targeting_time_remaining.toFixed(1)}s
                </ProgressBar>
              </Stack.Item>
            </Stack>
          </Box>
        </Stack.Item>
      )}

      {/* Current Target Display */}
      {target_name && targetShip ? (
        <Stack.Item>
          <Box
            p={0.5}
            backgroundColor="rgba(219, 40, 40, 0.15)"
            style={{ borderRadius: '3px' }}
          >
            <Stack vertical>
              {/* Target Name Header */}
              <Stack.Item>
                <Stack align="center">
                  <Stack.Item>
                    <Icon name="bullseye" color="bad" mr={1} />
                  </Stack.Item>
                  <Stack.Item grow>
                    <Box bold color="bad" fontSize="13px">
                      {target_name}
                    </Box>
                  </Stack.Item>
                  <Stack.Item>
                    <Button
                      icon="times"
                      color="transparent"
                      compact
                      aria-label="Clear target"
                      onClick={() => act('clear_target')}
                    />
                  </Stack.Item>
                </Stack>
              </Stack.Item>
              {/* Enemy Status Bars */}
              <Stack.Item>
                <Stack fontSize="10px">
                  <Stack.Item grow basis="50%">
                    <Box color="label" mb={0.25}>Shields</Box>
                    <ProgressBar
                      value={targetShip.shields_max > 0 ? targetShip.shields / targetShip.shields_max : 0}
                      color="#4488aa"
                    >
                      {Math.round(targetShip.shields)}/{targetShip.shields_max}
                    </ProgressBar>
                  </Stack.Item>
                  <Stack.Item grow basis="50%">
                    <Box color="label" mb={0.25}>Integrity</Box>
                    <ProgressBar
                      value={targetShip.integrity_max > 0 ? targetShip.integrity / targetShip.integrity_max : 0}
                      ranges={{
                        bad: [0, 0.25],
                        average: [0.25, 0.5],
                        good: [0.5, 1],
                      }}
                    >
                      {Math.round(targetShip.integrity)}%
                    </ProgressBar>
                  </Stack.Item>
                </Stack>
              </Stack.Item>
              {/* Distance and Speed */}
              <Stack.Item>
                <Stack fontSize="10px" color="label">
                  <Stack.Item grow>
                    <Icon name="ruler" mr={0.5} />
                    {targetShip.distance} tiles
                  </Stack.Item>
                  <Stack.Item grow>
                    <Icon name="tachometer-alt" mr={0.5} />
                    {targetShip.speed} spM
                  </Stack.Item>
                </Stack>
              </Stack.Item>
            </Stack>
          </Box>
        </Stack.Item>
      ) : (
        <Stack.Item>
          <Box
            p={0.5}
            textAlign="center"
            backgroundColor="rgba(255,255,255,0.05)"
            style={{ borderRadius: '3px' }}
          >
            <Box color="label" fontSize="11px">No Target</Box>
          </Box>
        </Stack.Item>
      )}

      {/* Ship List - excludes currently targeted ship */}
      <Stack.Item>
        {otherShips.length === 0 ? (
          <Box color="label" textAlign="center" py={0.5} fontSize="11px">
            {!nearby_ships || nearby_ships.length === 0 ? 'No ships in sensor range' : 'No other ships in range'}
          </Box>
        ) : (
          <Stack vertical>
            {otherShips.map((ship) => (
              <Stack.Item key={ship.ref}>
                <Button
                  fluid
                  compact
                  icon="circle"
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
            TARGETING ACTIVE
          </NoticeBox>
        </Stack.Item>
      )}

      {/* Engage/Exit Button */}
      <Stack.Item>
        {is_in_attack_mode ? (
          <Button
            fluid
            compact
            icon="times"
            color="grey"
            onClick={() => act('deactivate')}
          >
            EXIT TARGETING
          </Button>
        ) : (
          <Button
            fluid
            compact
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
  );
};

const InterdictorPanel = () => {
  const { act, data } = useBackend<Data>();
  const {
    target_ref,
    interdictor_linked,
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

  const powerPercent = Math.round((interdictor_power_level ?? 1) * 100);

  // Show if WE are being interdicted
  if (being_interdicted) {
    return (
      <Section
        title={
          <Box inline>
            <Icon name="satellite-dish" mr={1} />
            Interdictor
            <Box inline color="bad" ml={1} fontSize="10px">
              INTERDICTED
            </Box>
          </Box>
        }
      >
        <NoticeBox danger>
          <Icon name="exclamation-triangle" mr={1} />
          Engines at {100 - (our_interdiction_strength || 0)}%
        </NoticeBox>
      </Section>
    );
  }

  if (!interdictor_linked) {
    return (
      <Section
        title={
          <Box inline>
            <Icon name="satellite-dish" mr={1} />
            Interdictor
            <Box inline color="label" ml={1} fontSize="10px">
              NOT LINKED
            </Box>
          </Box>
        }
      />
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
            <Box inline color="average" ml={1} fontSize="10px">
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
            <Box inline color="average" ml={1} fontSize="10px">
              LOCKING
            </Box>
          </Box>
        }
      >
        <Stack vertical>
          <Stack.Item>
            <Box bold textAlign="center" color="average" fontSize="11px">
              <Icon name="spinner" spin mr={1} />
              {interdictor_target_name}
            </Box>
          </Stack.Item>
          <Stack.Item>
            <ProgressBar value={interdiction_warmup_progress || 0} color="blue">
              {Math.round((interdiction_warmup_progress || 0) * 100)}%
            </ProgressBar>
          </Stack.Item>
          <Stack.Item>
            <Button
              fluid
              compact
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
            <Box inline color="orange" ml={1} fontSize="10px">
              ACTIVE
            </Box>
          </Box>
        }
      >
        <Stack vertical>
          <Stack.Item>
            <Box bold color="orange" textAlign="center" fontSize="11px">
              {interdictor_target_name} @ {interdictor_target_speed_cap}%
            </Box>
          </Stack.Item>
          <Stack.Item>
            <Box fontSize="10px" color="label">
              Power: {powerPercent}% ({interdictor_power_draw}W)
            </Box>
            <Slider
              value={powerPercent}
              minValue={25}
              maxValue={200}
              step={25}
              stepPixelSize={6}
              format={(v) => `${v}%`}
              onChange={(e, value) => act('set_interdictor_power', { power: value })}
            />
          </Stack.Item>
          <Stack.Item>
            <Stack>
              <Stack.Item grow>
                <Button
                  fluid
                  compact
                  icon="link"
                  color="red"
                  disabled={!canForceDock}
                  onClick={() => act('force_dock')}
                >
                  {!target_in_force_dock_range ? 'Get Closer' : 'Force Dock'}
                </Button>
              </Stack.Item>
              <Stack.Item>
                <Button
                  compact
                  icon="times"
                  color="bad"
                  aria-label="Cancel interdiction"
                  onClick={() => act('cancel_interdict')}
                />
              </Stack.Item>
            </Stack>
          </Stack.Item>
        </Stack>
      </Section>
    );
  }

  // Ready state
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
        <Stack.Item>
          <Box fontSize="10px" color="label">
            Power: {powerPercent}%
            {powerPercent > 100 && (
              <Box inline color="orange" ml={1}>HIGH</Box>
            )}
          </Box>
          <Slider
            value={powerPercent}
            minValue={25}
            maxValue={200}
            step={25}
            stepPixelSize={6}
            format={(v) => `${v}%`}
            onChange={(e, value) => act('set_interdictor_power', { power: value })}
          />
        </Stack.Item>
        <Stack.Item>
          <Stack>
            <Stack.Item grow>
              <Button
                fluid
                compact
                icon="satellite-dish"
                disabled={!canInterdict}
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
              <Button
                fluid
                compact
                icon="link"
                color="red"
                disabled
              >
                Force Dock
              </Button>
            </Stack.Item>
          </Stack>
        </Stack.Item>
      </Stack>
    </Section>
  );
};

// ============================================================================
// EQUIPMENT TAB
// ============================================================================

const EquipmentTab = () => {
  return (
    <Stack vertical>
      <Stack.Item>
        <ShieldGeneratorsPanel />
      </Stack.Item>
      <Stack.Item>
        <InterdictorPanel />
      </Stack.Item>
      <Stack.Item>
        <CloakingPanel />
      </Stack.Item>
    </Stack>
  );
};

const ShieldGeneratorsPanel = () => {
  const { act, data } = useBackend<Data>();
  const {
    ship_docked,
    shield_linked,
    shield_active,
    shield_broken,
    shield_health,
    shield_max_health,
    shield_overhealth,
    shield_power_allocation,
    shield_regen_rate,
    shield_power_draw,
    shield_cooldown_active,
    shield_cooldown_remaining,
    shield_generators,
  } = data;

  if (!shield_linked) {
    return (
      <Section
        title={
          <Box inline>
            <Icon name="shield-halved" mr={1} />
            Shield Generators
            <Box inline color="label" ml={1} fontSize="10px">
              NO GENERATOR
            </Box>
          </Box>
        }
      />
    );
  }

  if (ship_docked) {
    return (
      <Section
        title={
          <Box inline>
            <Icon name="shield-halved" mr={1} />
            Shield Generators
            <Box inline color="label" ml={1} fontSize="10px">
              DOCKED
            </Box>
          </Box>
        }
      >
        <Box color="label" textAlign="center" fontSize="11px">
          <Icon name="anchor" mr={1} />
          Unavailable while docked
        </Box>
      </Section>
    );
  }

  const healthPercent = shield_max_health ? shield_health / shield_max_health : 0;
  const powerPercent = Math.round((shield_power_allocation ?? 1) * 100);

  // Cooldown display
  if (shield_broken && shield_cooldown_active) {
    const cooldownSeconds = Math.ceil((shield_cooldown_remaining || 0) / 10);
    const cooldownProgress = 1 - (shield_cooldown_remaining || 0) / 300;

    return (
      <Section
        title={
          <Box inline>
            <Icon name="shield-halved" mr={1} />
            Shield Generators
            <Box inline color="bad" ml={1} fontSize="10px">
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

  return (
    <Section
      title={
        <Box inline>
          <Icon name="shield-halved" mr={1} />
          Shield Generators
          <Box
            inline
            color={shield_active ? 'good' : powerPercent === 0 ? 'label' : 'average'}
            ml={1}
            fontSize="10px"
          >
            {shield_active ? 'ACTIVE' : powerPercent === 0 ? 'OFF' : 'CHARGING'}
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
          <Box fontSize="10px" color="label">
            Power: {powerPercent}%
            {powerPercent > 100 && shield_health >= shield_max_health && (
              <Box inline color="cyan" ml={1}>+overhealth</Box>
            )}
          </Box>
          <Slider
            value={powerPercent}
            minValue={0}
            maxValue={200}
            step={10}
            stepPixelSize={3}
            format={(v) => `${v}%`}
            disabled={!!shield_broken}
            onChange={(e, value) => act('set_shield_power', { power: value })}
          />
        </Stack.Item>

        {/* Stats Row */}
        <Stack.Item>
          <Box fontSize="10px" color="label">
            <Icon name="bolt" mr={0.5} />
            {shield_power_draw || 0}W
            <Box inline ml={2}>
              <Icon name="arrow-up" mr={0.5} />
              {shield_regen_rate || 0}/s
            </Box>
          </Box>
        </Stack.Item>

        {/* Generator List with Upgrades */}
        {shield_generators && shield_generators.length > 0 && (
          <Stack.Item>
            <Collapsible title={`Generators (${shield_generators.length})`}>
              <Stack vertical>
                {shield_generators.map((gen) => (
                  <Stack.Item key={gen.id}>
                    <Box
                      p={0.5}
                      mb={0.5}
                      backgroundColor="rgba(255,255,255,0.03)"
                      style={{ borderRadius: '3px' }}
                    >
                      <Box>
                        <SimpleUpgradeDisplay
                          label="Cap"
                          tier={gen.upgrades?.capacitor_tier || 0}
                        />
                        <SimpleUpgradeDisplay
                          label="Laser"
                          tier={gen.upgrades?.laser_tier || 0}
                        />
                        <SimpleUpgradeDisplay
                          label="Servo"
                          tier={gen.upgrades?.servo_tier || 0}
                        />
                      </Box>
                    </Box>
                  </Stack.Item>
                ))}
              </Stack>
            </Collapsible>
          </Stack.Item>
        )}
      </Stack>
    </Section>
  );
};

const CloakingPanel = () => {
  const { act, data } = useBackend<Data>();
  const { cloak_device, cloak_unlocked } = data;

  if (!cloak_unlocked || !cloak_device) {
    return (
      <Section
        title={
          <Box inline>
            <Icon name="eye-slash" mr={1} />
            Cloaking Device
            <Box inline color="label" ml={1} fontSize="10px">
              NOT LINKED
            </Box>
          </Box>
        }
      />
    );
  }

  const {
    active,
    can_activate,
    duration_remaining,
    duration_max,
    cooldown_remaining,
    cooldown_max,
    upgrades,
  } = cloak_device;

  const durationPercent = duration_max > 0 ? duration_remaining / duration_max : 0;
  const cooldownPercent = cooldown_max > 0 ? 1 - cooldown_remaining / cooldown_max : 1;

  // On cooldown
  if (cooldown_remaining > 0 && !active) {
    return (
      <Section
        title={
          <Box inline>
            <Icon name="eye-slash" mr={1} />
            Cloaking Device
            <Box inline color="average" ml={1} fontSize="10px">
              RECHARGING
            </Box>
          </Box>
        }
      >
        <ProgressBar
          value={cooldownPercent}
          ranges={{
            bad: [0, 0.4],
            average: [0.4, 0.8],
            good: [0.8, 1],
          }}
        >
          {Math.ceil(cooldown_remaining / 10)}s
        </ProgressBar>
      </Section>
    );
  }

  // Active
  if (active) {
    return (
      <Section
        title={
          <Box inline>
            <Icon name="eye-slash" mr={1} />
            Cloaking Device
            <Box inline color="cyan" ml={1} fontSize="10px">
              ACTIVE
            </Box>
          </Box>
        }
      >
        <Stack vertical>
          <Stack.Item>
            <ProgressBar value={durationPercent} color="cyan">
              {Math.ceil(duration_remaining / 10)}s remaining
            </ProgressBar>
          </Stack.Item>
          <Stack.Item>
            <Button
              fluid
              compact
              icon="eye"
              color="bad"
              onClick={() => act('cloak_deactivate')}
            >
              Decloak
            </Button>
          </Stack.Item>
        </Stack>
      </Section>
    );
  }

  // Ready
  return (
    <Section
      title={
        <Box inline>
          <Icon name="eye-slash" mr={1} />
          Cloaking Device
        </Box>
      }
    >
      <Stack vertical>
        <Stack.Item>
          <Box fontSize="10px" color="label">
            Duration: {Math.ceil(duration_max)}s
          </Box>
        </Stack.Item>
        <Stack.Item>
          <Box>
            <UpgradeDisplay
              label="Cap"
              tier={upgrades?.capacitor_tier || 0}
              names={CAPACITOR_NAMES}
            />
            <UpgradeDisplay
              label="Laser"
              tier={upgrades?.laser_tier || 0}
              names={LASER_NAMES}
            />
            <UpgradeDisplay
              label="Scan"
              tier={upgrades?.scanning_tier || 0}
              names={SCANNER_NAMES}
            />
          </Box>
        </Stack.Item>
        <Stack.Item>
          <Button
            fluid
            compact
            icon="eye-slash"
            color="blue"
            disabled={!can_activate}
            onClick={() => act('cloak_activate')}
          >
            {can_activate ? 'Activate Cloak' : 'Cannot Cloak'}
          </Button>
        </Stack.Item>
      </Stack>
    </Section>
  );
};

// ============================================================================
// WEAPONS TAB
// ============================================================================

const WeaponsTab = () => {
  return (
    <Stack vertical>
      <Stack.Item>
        <MissileLaunchersPanel />
      </Stack.Item>
      <Stack.Item>
        <LaserTurretsPanel />
      </Stack.Item>
    </Stack>
  );
};

const MissileLaunchersPanel = () => {
  const { data } = useBackend<Data>();
  const { launchers, launchers_ready, launchers_total } = data;

  if (launchers.length === 0) {
    return (
      <Section
        title={
          <Box inline>
            <Icon name="rocket" mr={1} />
            Missile Launchers
            <Box inline color="label" ml={1} fontSize="10px">
              NONE
            </Box>
          </Box>
        }
      >
        <Box color="label" textAlign="center" fontSize="11px">
          <Icon name="unlink" mr={1} />
          No launchers linked
        </Box>
      </Section>
    );
  }

  return (
    <Section
      title={
        <Box inline>
          <Icon name="rocket" mr={1} />
          Missile Launchers
        </Box>
      }
      buttons={
        <Box color="label" fontSize="10px">
          {launchers_ready}/{launchers_total} ready
        </Box>
      }
    >
      <Stack vertical>
        {launchers.map((launcher) => {
          const isDisabled = !launcher.on_exterior || !launcher.enabled;
          return (
            <Stack.Item key={launcher.id}>
              <Stack
                align="center"
                py={0.25}
                style={{ opacity: isDisabled ? 0.5 : 1 }}
              >
                <Stack.Item basis="50px">
                  <Box color="label" fontSize="10px">
                    {launcher.id}
                  </Box>
                </Stack.Item>
                <Stack.Item grow>
                  {isDisabled ? (
                    <Box color="bad" fontSize="11px">
                      <Icon name="triangle-exclamation" mr={0.5} />
                      {!launcher.on_exterior ? 'Not on exterior' : 'Disabled'}
                    </Box>
                  ) : launcher.loaded ? (
                    <Box color="good" fontSize="11px">
                      {launcher.missile_name}
                      <Box as="span" color="label" ml={1}>
                        ({launcher.missile_damage} dmg)
                      </Box>
                    </Box>
                  ) : (
                    <Box color="label" fontSize="11px">Empty</Box>
                  )}
                </Stack.Item>
                <Stack.Item basis="55px">
                  {isDisabled ? (
                    <Box color="bad" textAlign="right" fontSize="10px">
                      Disabled
                    </Box>
                  ) : !launcher.loaded ? (
                    <Box color="label" textAlign="right" fontSize="10px">
                      --
                    </Box>
                  ) : launcher.ready ? (
                    <Box color="good" textAlign="right" fontSize="10px">
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
                    <Box color="average" textAlign="right" fontSize="10px">
                      Loading
                    </Box>
                  )}
                </Stack.Item>
              </Stack>
            </Stack.Item>
          );
        })}
      </Stack>
    </Section>
  );
};

const LaserTurretsPanel = () => {
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

  if (turrets.length === 0) {
    return (
      <Section
        title={
          <Box inline>
            <Icon name="bolt" mr={1} />
            Laser Turrets
            <Box inline color="label" ml={1} fontSize="10px">
              NONE
            </Box>
          </Box>
        }
      >
        <Box color="label" textAlign="center" fontSize="11px">
          <Icon name="unlink" mr={1} />
          No turrets linked
        </Box>
      </Section>
    );
  }

  return (
    <Section
      title={
        <Box inline>
          <Icon name="bolt" mr={1} />
          Laser Turrets
        </Box>
      }
      buttons={
        <Box color="label" fontSize="10px">
          {turrets_ready}/{turrets_total} ready
        </Box>
      }
    >
      <Stack vertical>
        {/* Total Power Bar */}
        <Stack.Item>
          <Box mb={0.25} fontSize="10px" color="label">
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
          <Box mb={0.25} fontSize="10px" color="label">
            Power Level ({powerPercent}%)
            {powerPercent > 100 && (
              <Box inline color="orange" ml={1}>HIGH</Box>
            )}
          </Box>
          <Slider
            value={powerPercent}
            minValue={25}
            maxValue={200}
            step={25}
            stepPixelSize={6}
            format={(v) => `${v}%`}
            onChange={(e, value) => act('set_turret_power', { power: value })}
          />
        </Stack.Item>

        {/* Stats Row */}
        <Stack.Item>
          <Stack fontSize="10px" color="label">
            <Stack.Item grow>
              <Icon name="crosshairs" mr={0.5} />
              {Math.round(50 * turret_power_level)} dmg
            </Stack.Item>
            <Stack.Item grow>
              <Icon name="bolt" mr={0.5} />
              {Math.round(2000 * turret_power_level)}W
            </Stack.Item>
            <Stack.Item grow>
              <Icon name="shield-halved" mr={0.5} color="cyan" />
              1.5x shields
            </Stack.Item>
          </Stack>
        </Stack.Item>

        {/* Turret List with Upgrades */}
        <Stack.Item>
          <Collapsible title={`Turret Status (${turrets.length})`}>
            <Stack vertical>
              {turrets.map((turret) => (
                <Stack.Item key={turret.id}>
                  <Box
                    p={0.5}
                    mb={0.5}
                    backgroundColor="rgba(255,255,255,0.03)"
                    style={{
                      borderRadius: '3px',
                      opacity: turret.on_exterior ? 1 : 0.5,
                    }}
                  >
                    {/* Main row: ID, Damage, Status */}
                    <Stack align="center">
                      <Stack.Item basis="50px">
                        <Box color="label" fontSize="10px">
                          {turret.id}
                        </Box>
                      </Stack.Item>
                      <Stack.Item grow>
                        {turret.on_exterior ? (
                          <Box color="cyan" fontSize="11px">
                            {turret.damage} dmg
                            <Box as="span" color="label" ml={1}>
                              ({turret.power_per_shot}W)
                            </Box>
                          </Box>
                        ) : (
                          <Box color="bad" fontSize="11px">
                            <Icon name="triangle-exclamation" mr={0.5} />
                            Not on exterior
                          </Box>
                        )}
                      </Stack.Item>
                      <Stack.Item basis="55px">
                        {!turret.on_exterior ? (
                          <Box color="bad" textAlign="right" fontSize="10px">
                            Disabled
                          </Box>
                        ) : turret.ready ? (
                          <Box color="good" textAlign="right" fontSize="10px">
                            <Icon name="check" /> Ready
                          </Box>
                        ) : turret.cooldown_remaining > 0 ? (
                          <ProgressBar
                            value={turret.cooldown > 0 ? 1 - turret.cooldown_remaining / turret.cooldown : 0}
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
                            Chrg
                          </ProgressBar>
                        ) : (
                          <Box color="bad" textAlign="right" fontSize="10px">
                            Error
                          </Box>
                        )}
                      </Stack.Item>
                    </Stack>
                    {/* Upgrades row */}
                    <Box mt={0.5}>
                      <SimpleUpgradeDisplay
                        label="Cap"
                        tier={turret.upgrades?.capacitor_tier || 0}
                      />
                      <SimpleUpgradeDisplay
                        label="Laser"
                        tier={turret.upgrades?.laser_tier || 0}
                      />
                      <SimpleUpgradeDisplay
                        label="Servo"
                        tier={turret.upgrades?.servo_tier || 0}
                      />
                    </Box>
                  </Box>
                </Stack.Item>
              ))}
            </Stack>
          </Collapsible>
        </Stack.Item>
      </Stack>
    </Section>
  );
};

// ============================================================================
// SETTINGS TAB
// ============================================================================

const SettingsTab = () => {
  const { act, data } = useBackend<Data>();
  const { theme } = data;

  return (
    <Stack vertical>
      <Stack.Item>
        <Section title="Display Settings">
          <LabeledList>
            <LabeledList.Item label="Theme">
              <Dropdown
                width="150px"
                selected={theme || 'default'}
                options={[
                  'default',
                  'cardtable',
                  'malfunction',
                  'ntOS95',
                  'ntos_synth',
                  'ntos_terminal',
                  'syndicate',
                  'wizard',
                ]}
                onSelected={(value) => act('setTheme', { theme: value })}
              />
            </LabeledList.Item>
          </LabeledList>
        </Section>
      </Stack.Item>
    </Stack>
  );
};

