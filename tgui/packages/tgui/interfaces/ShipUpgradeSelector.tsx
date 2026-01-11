import { useState } from 'react';
import {
  Box,
  Button,
  Icon,
  Modal,
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
  ship_template: string;
  slots: UpgradeSlot[];
  parts: PartsInventory;
  unlocked_upgrades: string[];
  selected_upgrades: Record<string, string>;
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
  const { ship_name, slots, parts, unlocked_upgrades, selected_upgrades } =
    data;

  // State for purchase confirmation modal
  const [confirmingPurchase, setConfirmingPurchase] =
    useState<UpgradeModule | null>(null);

  // Check if a module is unlocked
  const isModuleUnlocked = (module: UpgradeModule) => {
    if (module.is_default) return true;
    return unlocked_upgrades?.includes(module.id);
  };

  // Check if player can afford a module
  const canAffordModule = (module: UpgradeModule) => {
    if (module.is_default || !module.part_cost) return true;
    return Object.entries(module.part_cost).every(
      ([partClass, cost]) =>
        (parts?.[partClass as keyof PartsInventory] || 0) >= (cost || 0),
    );
  };

  // Handle unlock button click - show confirmation
  const handleUnlockClick = (module: UpgradeModule) => {
    setConfirmingPurchase(module);
  };

  // Confirm purchase
  const confirmPurchase = () => {
    if (confirmingPurchase) {
      act('unlock_upgrade', { module_id: confirmingPurchase.id });
      setConfirmingPurchase(null);
    }
  };

  return (
    <Window title={`Customize: ${ship_name}`} width={600} height={550}>
      <Window.Content scrollable>
        {/* Purchase Confirmation Modal */}
        {confirmingPurchase && (
          <Modal>
            <Box fontSize="16px" bold mb={2}>
              Unlock Upgrade?
            </Box>
            <Box mb={2}>
              <Box bold color="white">
                {confirmingPurchase.name}
              </Box>
              <Box color="white" mt={1}>
                {confirmingPurchase.desc}
              </Box>
            </Box>
            <Box mb={2}>
              <Box bold>Cost:</Box>
              <Stack mt={1}>
                {Object.entries(confirmingPurchase.part_cost || {})
                  .filter(([_, cost]) => cost && cost > 0)
                  .map(([partClass, cost]) => (
                    <Stack.Item key={partClass} mr={2}>
                      <Box color={CLASS_COLORS[partClass]}>
                        <Icon name={CLASS_ICONS[partClass]} mr={1} />
                        {cost} {capitalize(partClass)}
                      </Box>
                    </Stack.Item>
                  ))}
                {Object.keys(confirmingPurchase.part_cost || {}).length ===
                  0 && <Box color="good">Free</Box>}
              </Stack>
            </Box>
            <Box italic color="label" mb={2}>
              This is a one-time purchase. Once unlocked, you can use this
              upgrade forever.
            </Box>
            <Stack justify="flex-end">
              <Stack.Item>
                <Button onClick={() => setConfirmingPurchase(null)}>
                  Cancel
                </Button>
              </Stack.Item>
              <Stack.Item ml={1}>
                <Button
                  color="good"
                  icon="unlock"
                  onClick={confirmPurchase}
                  disabled={!canAffordModule(confirmingPurchase)}
                >
                  Confirm Purchase
                </Button>
              </Stack.Item>
            </Stack>
          </Modal>
        )}

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
                  Unlock upgrades permanently, then select for your ship
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
                      unlockedUpgrades={unlocked_upgrades || []}
                      onUnlockClick={handleUnlockClick}
                    />
                  </Stack.Item>
                ))}
              </Stack>
            </Section>
          </Stack.Item>

          {/* Actions */}
          <Stack.Item>
            <Section>
              <Stack justify="flex-end">
                <Stack.Item>
                  <Button
                    icon="times"
                    color="bad"
                    onClick={() => act('cancel')}
                  >
                    Cancel
                  </Button>
                </Stack.Item>
                <Stack.Item ml={1}>
                  <Button
                    icon="rocket"
                    color="good"
                    onClick={() => act('confirm')}
                  >
                    LAUNCH SHIP
                  </Button>
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
  unlockedUpgrades: string[];
  onUnlockClick: (module: UpgradeModule) => void;
}) => {
  const { act } = useBackend<ShipUpgradeSelectorData>();
  const { slot, selectedModuleId, playerParts, unlockedUpgrades, onUnlockClick } =
    props;

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
          const isUnlocked =
            module.is_default || unlockedUpgrades.includes(module.id);
          const isSelected = selectedModuleId === module.id;
          const hasCost =
            module.part_cost &&
            Object.values(module.part_cost).some((v) => v && v > 0);

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
              <Box
                style={{
                  padding: '8px',
                  marginBottom: '4px',
                  backgroundColor: isSelected
                    ? 'rgba(0, 200, 0, 0.15)'
                    : isUnlocked
                      ? 'rgba(255, 255, 255, 0.05)'
                      : 'rgba(0, 0, 0, 0.2)',
                  border: isSelected
                    ? '1px solid rgba(0, 200, 0, 0.5)'
                    : '1px solid rgba(255, 255, 255, 0.1)',
                  borderRadius: '4px',
                  opacity: isUnlocked ? 1 : 0.6,
                }}
              >
                <Stack align="center">
                  <Stack.Item grow>
                    <Stack vertical>
                      <Stack.Item>
                        <Box bold color={isUnlocked ? 'white' : 'gray'}>
                          {module.name}
                          {module.is_default && (
                            <Box as="span" color="label" ml={1}>
                              (Default)
                            </Box>
                          )}
                          {isUnlocked && !module.is_default && (
                            <Box as="span" color="good" ml={1}>
                              <Icon name="check" /> Owned
                            </Box>
                          )}
                        </Box>
                      </Stack.Item>
                      <Stack.Item>
                        <Box color="white" fontSize="12px">
                          {module.desc}
                        </Box>
                      </Stack.Item>
                    </Stack>
                  </Stack.Item>

                  {/* Cost display for locked modules */}
                  {!isUnlocked && hasCost && (
                    <Stack.Item>
                      <Stack>
                        {Object.entries(module.part_cost)
                          .filter(([_, cost]) => cost && cost > 0)
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
                    </Stack.Item>
                  )}

                  {/* Action buttons */}
                  <Stack.Item ml={2}>
                    {isUnlocked ? (
                      // Unlocked - can select
                      <Button
                        icon={isSelected ? 'check-circle' : 'circle'}
                        color={isSelected ? 'good' : 'default'}
                        onClick={() =>
                          act('select_upgrade', {
                            slot: slot.key,
                            module_id: module.id,
                          })
                        }
                      >
                        {isSelected ? 'Selected' : 'Select'}
                      </Button>
                    ) : (
                      // Locked - can unlock
                      <Button
                        icon="lock"
                        color={canAfford ? 'caution' : 'gray'}
                        disabled={!canAfford}
                        onClick={() => onUnlockClick(module)}
                        tooltip={
                          !canAfford
                            ? 'You cannot afford this upgrade'
                            : 'Click to unlock this upgrade permanently'
                        }
                      >
                        Unlock
                      </Button>
                    )}
                  </Stack.Item>
                </Stack>
              </Box>
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
