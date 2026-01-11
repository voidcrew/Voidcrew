import {
  Box,
  Button,
  Dimmer,
  Icon,
  Section,
  Stack,
  Tooltip,
} from 'tgui-core/components';

import { useBackend } from '../backend';
import { Window } from '../layouts';

type PartsInventory = {
  combat: number;
  science: number;
  trade: number;
  misc: number;
};

type UpgradeModule = {
  id: string;
  name: string;
  desc: string;
  part_cost: Partial<PartsInventory>;
  is_default: boolean;
};

type UpgradeSlot = {
  key: string;
  display_name: string;
  modules: UpgradeModule[];
};

type ShipUpgradeSelectorData = {
  ship_name: string;
  ship_short_name: string;
  slots: UpgradeSlot[];
  parts: PartsInventory;
  selected_upgrades: Record<string, string>;
  total_cost: PartsInventory;
  can_afford: boolean;
};

const CLASS_COLORS: Record<string, string> = {
  combat: '#ff4444',
  science: '#4488ff',
  trade: '#ffcc00',
  misc: '#9d9d9d',
};

const CLASS_ICONS: Record<string, string> = {
  combat: 'crosshairs',
  science: 'flask',
  trade: 'coins',
  misc: 'puzzle-piece',
};

export const ShipUpgradeSelector = () => {
  const { act, data } = useBackend<ShipUpgradeSelectorData>();
  const {
    ship_name,
    slots,
    parts,
    selected_upgrades,
    total_cost,
    can_afford,
  } = data;

  // Check if any non-default upgrades are selected
  const hasUpgradeCost = Object.values(total_cost || {}).some(
    (cost) => cost > 0,
  );

  return (
    <Window title={`Customize: ${ship_name}`} width={600} height={500}>
      <Window.Content scrollable>
        <Stack vertical fill>
          {/* Header with Parts Inventory */}
          <Stack.Item>
            <Section title="Your Parts">
              <Stack>
                {Object.entries(parts || {}).map(([partClass, count]) => (
                  <Stack.Item key={partClass} mr={2}>
                    <Box color={CLASS_COLORS[partClass]}>
                      <Icon name={CLASS_ICONS[partClass]} mr={1} />
                      {count} {capitalize(partClass)}
                    </Box>
                  </Stack.Item>
                ))}
              </Stack>
            </Section>
          </Stack.Item>

          {/* Upgrade Slots */}
          <Stack.Item grow>
            <Section
              title="Upgrade Slots"
              fill
              scrollable
              buttons={
                <Box fontSize="12px" color="label">
                  Select modules for each slot
                </Box>
              }
            >
              <Stack vertical>
                {slots?.map((slot) => (
                  <Stack.Item key={slot.key}>
                    <UpgradeSlotSection
                      slot={slot}
                      selectedModuleId={selected_upgrades?.[slot.key]}
                      playerParts={parts}
                    />
                  </Stack.Item>
                ))}
              </Stack>
            </Section>
          </Stack.Item>

          {/* Cost Summary and Actions */}
          <Stack.Item>
            <Section>
              <Stack align="center">
                <Stack.Item grow>
                  {hasUpgradeCost ? (
                    <Box>
                      <Box bold mb={1}>
                        Upgrade Cost:
                      </Box>
                      <Stack>
                        {Object.entries(total_cost || {})
                          .filter(([_, cost]) => cost > 0)
                          .map(([partClass, cost]) => (
                            <Stack.Item key={partClass} mr={2}>
                              <Box
                                color={
                                  (parts?.[
                                    partClass as keyof PartsInventory
                                  ] || 0) >= cost
                                    ? CLASS_COLORS[partClass]
                                    : 'bad'
                                }
                              >
                                <Icon name={CLASS_ICONS[partClass]} mr={1} />
                                {cost} {capitalize(partClass)}
                              </Box>
                            </Stack.Item>
                          ))}
                      </Stack>
                    </Box>
                  ) : (
                    <Box color="good">
                      <Icon name="check" mr={1} />
                      Default loadout (no additional cost)
                    </Box>
                  )}
                </Stack.Item>

                <Stack.Item>
                  <Stack>
                    <Stack.Item>
                      <Button icon="times" color="bad" onClick={() => act('cancel')}>
                        Cancel
                      </Button>
                    </Stack.Item>
                    <Stack.Item ml={1}>
                      <Button
                        icon="rocket"
                        color={can_afford ? 'good' : 'gray'}
                        disabled={!can_afford}
                        onClick={() => act('confirm')}
                        tooltip={
                          !can_afford
                            ? 'You cannot afford these upgrades'
                            : 'Spawn ship with selected upgrades'
                        }
                      >
                        {can_afford ? 'LAUNCH SHIP' : 'CANNOT AFFORD'}
                      </Button>
                    </Stack.Item>
                  </Stack>
                </Stack.Item>
              </Stack>
            </Section>
          </Stack.Item>
        </Stack>
      </Window.Content>
    </Window>
  );
};

const UpgradeSlotSection = (props: {
  slot: UpgradeSlot;
  selectedModuleId?: string;
  playerParts: PartsInventory;
}) => {
  const { act } = useBackend<ShipUpgradeSelectorData>();
  const { slot, selectedModuleId, playerParts } = props;

  return (
    <Section
      title={slot.display_name}
      style={{
        borderLeft: '3px solid #666',
        marginBottom: '8px',
      }}
    >
      <Stack vertical>
        {slot.modules.map((module) => {
          const isSelected = selectedModuleId === module.id;
          const hasCost =
            module.part_cost &&
            Object.values(module.part_cost).some((v) => v > 0);

          // Check if player can afford this module
          const canAfford =
            !hasCost ||
            Object.entries(module.part_cost).every(
              ([partClass, cost]) =>
                (playerParts?.[partClass as keyof PartsInventory] || 0) >=
                (cost || 0),
            );

          return (
            <Stack.Item key={module.id}>
              <Button
                fluid
                selected={isSelected}
                color={isSelected ? 'good' : canAfford ? 'default' : 'gray'}
                onClick={() =>
                  act('select_upgrade', {
                    slot: slot.key,
                    module_id: module.id,
                  })
                }
              >
                <Stack align="center">
                  <Stack.Item grow>
                    <Stack vertical>
                      <Stack.Item>
                        <Box bold>
                          {module.name}
                          {module.is_default && (
                            <Box as="span" color="label" ml={1}>
                              (Default)
                            </Box>
                          )}
                        </Box>
                      </Stack.Item>
                      <Stack.Item>
                        <Box color="label" fontSize="12px">
                          {module.desc}
                        </Box>
                      </Stack.Item>
                    </Stack>
                  </Stack.Item>

                  <Stack.Item>
                    {hasCost ? (
                      <Stack>
                        {Object.entries(module.part_cost)
                          .filter(([_, cost]) => cost > 0)
                          .map(([partClass, cost]) => (
                            <Stack.Item key={partClass} ml={1}>
                              <Tooltip
                                content={`${cost} ${capitalize(partClass)} parts`}
                              >
                                <Box
                                  color={
                                    (playerParts?.[
                                      partClass as keyof PartsInventory
                                    ] || 0) >= (cost || 0)
                                      ? CLASS_COLORS[partClass]
                                      : 'bad'
                                  }
                                >
                                  <Icon name={CLASS_ICONS[partClass]} mr={0.5} />
                                  {cost}
                                </Box>
                              </Tooltip>
                            </Stack.Item>
                          ))}
                      </Stack>
                    ) : (
                      <Box color="good">
                        <Icon name="check" />
                      </Box>
                    )}
                  </Stack.Item>

                  <Stack.Item ml={1}>
                    {isSelected ? (
                      <Icon name="check-circle" color="good" />
                    ) : (
                      <Icon name="circle" color="label" />
                    )}
                  </Stack.Item>
                </Stack>
              </Button>
            </Stack.Item>
          );
        })}
      </Stack>
    </Section>
  );
};

// Helper function to capitalize first letter
function capitalize(str: string): string {
  return str.charAt(0).toUpperCase() + str.slice(1);
}
