import { type CSSProperties, type ReactNode, useState } from 'react';
import {
  Box,
  Button,
  Collapsible,
  Icon,
  Modal,
  Section,
  Stack,
  Tabs,
  Tooltip,
} from 'tgui-core/components';

import { resolveAsset } from '../assets';
import { useBackend } from '../backend';
import { Window } from '../layouts';

type PartsInventory = {
  combat: number;
  science: number;
  trade: number;
  misc: number;
};

type JobPreview = {
  name: string;
  slots: number;
  officer: boolean;
};

type ShipTheme = {
  id: string;
  name: string;
  desc: string;
  part_cost: Partial<PartsInventory>;
  is_default: boolean;
  jobs: JobPreview[];
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

type PreviewGeom = {
  png: string;
  width: number;
  height: number;
  connector?: [number, number];
};

type ModulePreview = PreviewGeom & {
  themes?: Record<string, PreviewGeom>;
};

type HullPreview = {
  png: string;
  width: number;
  height: number;
  slots: Record<string, [number, number]>;
};

type PreviewData = {
  tile_px: number;
  hulls: Record<string, HullPreview>;
  modules: Record<string, ModulePreview>;
};

type HoverModule = {
  slot: string;
  moduleId: string;
};

type ShipUpgradeSelectorData = {
  ship_name: string;
  ship_short_name: string;
  ship_template: string;
  themes: ShipTheme[];
  has_themes: boolean;
  slots: UpgradeSlot[];
  parts: PartsInventory;
  unlocked_upgrades: string[];
  unlocked_themes: string[];
  selected_upgrades: Record<string, string>;
  selected_theme: string | null;
  preview: PreviewData | null;
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
    themes,
    has_themes,
    slots,
    parts,
    unlocked_upgrades,
    unlocked_themes,
    selected_upgrades,
    selected_theme,
    preview,
  } = data;

  // State for active tab
  const [activeTab, setActiveTab] = useState<'theme' | 'upgrades'>('theme');

  // Preview hover state: temporarily show a hovered theme/module on the map
  const [hoverTheme, setHoverTheme] = useState<string | null>(null);
  const [hoverModule, setHoverModule] = useState<HoverModule | null>(null);

  // Effective tab - if no themes, always show upgrades
  const effectiveTab =
    activeTab === 'theme' && has_themes && themes?.length > 0
      ? 'theme'
      : 'upgrades';

  // State for purchase confirmation modal
  const [confirmingPurchase, setConfirmingPurchase] = useState<{
    type: 'theme' | 'upgrade';
    item: ShipTheme | UpgradeModule;
  } | null>(null);

  // Check if a theme is unlocked
  const isThemeUnlocked = (theme: ShipTheme) => {
    if (theme.is_default) return true;
    return unlocked_themes?.includes(theme.id);
  };

  // Check if player can afford an item
  const canAfford = (partCost: Partial<PartsInventory> | undefined) => {
    if (!partCost) return true;
    return Object.entries(partCost).every(
      ([partClass, cost]) =>
        (parts?.[partClass as keyof PartsInventory] || 0) >= (cost || 0),
    );
  };

  // Handle unlock button click - show confirmation
  const handleUnlockClick = (
    type: 'theme' | 'upgrade',
    item: ShipTheme | UpgradeModule,
  ) => {
    setConfirmingPurchase({ type, item });
  };

  // Confirm purchase
  const confirmPurchase = () => {
    if (confirmingPurchase) {
      const action =
        confirmingPurchase.type === 'theme' ? 'unlock_theme' : 'unlock_upgrade';
      const idKey =
        confirmingPurchase.type === 'theme' ? 'theme_id' : 'module_id';
      act(action, { [idKey]: confirmingPurchase.item.id });
      setConfirmingPurchase(null);
    }
  };

  const selectedThemeData = themes?.find((t) => t.id === selected_theme);

  const hasPreview = !!(
    preview?.hulls && Object.keys(preview.hulls).length > 0
  );
  const previewThemeKey = hoverTheme ?? selected_theme ?? '';

  return (
    <Window
      title={`Customize: ${ship_name}`}
      width={hasPreview ? 1100 : 650}
      height={650}
    >
      <Window.Content>
        {/* Purchase Confirmation Modal */}
        {confirmingPurchase && (
          <Modal>
            <Box fontSize="16px" bold mb={2}>
              Unlock{' '}
              {confirmingPurchase.type === 'theme' ? 'Theme' : 'Upgrade'}?
            </Box>
            <Box mb={2}>
              <Box bold color="white">
                {confirmingPurchase.item.name}
              </Box>
              <Box color="white" mt={1}>
                {confirmingPurchase.item.desc}
              </Box>
            </Box>
            <Box mb={2}>
              <Box bold>Cost:</Box>
              <Stack mt={1}>
                {Object.entries(confirmingPurchase.item.part_cost || {})
                  .filter(([_, cost]) => cost && cost > 0)
                  .map(([partClass, cost]) => (
                    <Stack.Item key={partClass} mr={2}>
                      <Box color={CLASS_COLORS[partClass]}>
                        <Icon name={CLASS_ICONS[partClass]} mr={1} />
                        {cost} {capitalize(partClass)}
                      </Box>
                    </Stack.Item>
                  ))}
                {Object.keys(confirmingPurchase.item.part_cost || {}).length ===
                  0 && <Box color="good">Free</Box>}
              </Stack>
            </Box>
            <Box italic color="label" mb={2}>
              This is a one-time purchase. Once unlocked, you can use this{' '}
              {confirmingPurchase.type} forever.
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
                  disabled={!canAfford(confirmingPurchase.item.part_cost)}
                >
                  Confirm Purchase
                </Button>
              </Stack.Item>
            </Stack>
          </Modal>
        )}

        <Stack fill>
          {/* Left column: selection lists */}
          <Stack.Item width={hasPreview ? '58%' : '100%'}>
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

              {/* Tabs */}
              <Stack.Item>
                <Tabs>
                  {has_themes && themes && themes.length > 0 && (
                    <Tabs.Tab
                      selected={effectiveTab === 'theme'}
                      onClick={() => setActiveTab('theme')}
                    >
                      Theme
                    </Tabs.Tab>
                  )}
                  <Tabs.Tab
                    selected={effectiveTab === 'upgrades'}
                    onClick={() => setActiveTab('upgrades')}
                  >
                    Upgrades
                  </Tabs.Tab>
                </Tabs>
              </Stack.Item>

              {/* Theme Selection */}
              {effectiveTab === 'theme' && (
                <Stack.Item grow>
                  <Section
                    title="Ship Theme"
                    fill
                    scrollable
                    buttons={
                      <Box fontSize="12px" color="label">
                        Choose your ship&apos;s configuration
                      </Box>
                    }
                  >
                    <Stack vertical>
                      {themes.map((theme) => {
                        const isUnlocked = isThemeUnlocked(theme);
                        const isSelected = selected_theme === theme.id;
                        const hasCost =
                          theme.part_cost &&
                          Object.values(theme.part_cost).some(
                            (v) => v && v > 0,
                          );
                        const affordable = canAfford(theme.part_cost);

                        return (
                          <Stack.Item key={theme.id}>
                            <div
                              onMouseEnter={() => setHoverTheme(theme.id)}
                              onMouseLeave={() => setHoverTheme(null)}
                              style={{
                                padding: '10px',
                                marginBottom: '4px',
                                backgroundColor: isSelected
                                  ? 'rgba(0, 200, 0, 0.15)'
                                  : isUnlocked
                                    ? 'rgba(255, 255, 255, 0.05)'
                                    : 'rgba(0, 0, 0, 0.2)',
                                border: isSelected
                                  ? '2px solid rgba(0, 200, 0, 0.5)'
                                  : '1px solid rgba(255, 255, 255, 0.1)',
                                borderRadius: '4px',
                                opacity: isUnlocked ? 1 : 0.7,
                              }}
                            >
                              <Stack align="center">
                                <Stack.Item grow>
                                  <Stack vertical>
                                    <Stack.Item>
                                      <Box
                                        bold
                                        color={isUnlocked ? 'white' : 'gray'}
                                      >
                                        {theme.name}
                                        {!!theme.is_default && (
                                          <Box as="span" color="label" ml={1}>
                                            (Default)
                                          </Box>
                                        )}
                                        {isUnlocked && !theme.is_default && (
                                          <Box as="span" color="good" ml={1}>
                                            <Icon name="check" /> Owned
                                          </Box>
                                        )}
                                      </Box>
                                    </Stack.Item>
                                    <Stack.Item>
                                      <Box color="white" fontSize="12px">
                                        {theme.desc}
                                      </Box>
                                    </Stack.Item>
                                    {!!(theme.jobs && theme.jobs.length > 0) && (
                                      <Stack.Item>
                                        <Collapsible
                                          title="Crew Roster"
                                          color="label"
                                        >
                                          <Box
                                            fontSize="11px"
                                            color="label"
                                            mt={1}
                                          >
                                            {theme.jobs.map((job, idx) => (
                                              <Box key={idx}>
                                                {job.slots}x {job.name}
                                              </Box>
                                            ))}
                                          </Box>
                                        </Collapsible>
                                      </Stack.Item>
                                    )}
                                  </Stack>
                                </Stack.Item>

                                {/* Cost display for locked themes */}
                                {!isUnlocked && hasCost && (
                                  <Stack.Item>
                                    <Stack>
                                      {Object.entries(theme.part_cost)
                                        .filter(([_, cost]) => cost && cost > 0)
                                        .map(([partClass, cost]) => (
                                          <Stack.Item key={partClass} ml={1}>
                                            <Tooltip
                                              content={`${cost} ${capitalize(partClass)} parts`}
                                            >
                                              <Box
                                                color={
                                                  (parts?.[
                                                    partClass as keyof PartsInventory
                                                  ] || 0) >= (cost || 0)
                                                    ? CLASS_COLORS[partClass]
                                                    : 'bad'
                                                }
                                              >
                                                <Icon
                                                  name={CLASS_ICONS[partClass]}
                                                  mr={0.5}
                                                />
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
                                    <Button
                                      icon={
                                        isSelected ? 'check-circle' : 'circle'
                                      }
                                      color={isSelected ? 'good' : 'default'}
                                      onClick={() =>
                                        act('select_theme', {
                                          theme_id: theme.id,
                                        })
                                      }
                                    >
                                      {isSelected ? 'Selected' : 'Select'}
                                    </Button>
                                  ) : (
                                    <Button
                                      icon="lock"
                                      color={affordable ? 'caution' : 'gray'}
                                      disabled={!affordable}
                                      onClick={() =>
                                        handleUnlockClick('theme', theme)
                                      }
                                      tooltip={
                                        !affordable
                                          ? 'You cannot afford this theme'
                                          : 'Click to unlock this theme permanently'
                                      }
                                    >
                                      Unlock
                                    </Button>
                                  )}
                                </Stack.Item>
                              </Stack>
                            </div>
                          </Stack.Item>
                        );
                      })}
                    </Stack>
                  </Section>
                </Stack.Item>
              )}

              {/* Upgrade Slots */}
              {effectiveTab === 'upgrades' && (
                <Stack.Item grow>
                  <Section
                    title="Upgrade Slots"
                    fill
                    scrollable
                    buttons={
                      <Box fontSize="12px" color="label">
                        {selectedThemeData
                          ? `Upgrades for ${selectedThemeData.name}`
                          : 'Unlock upgrades permanently, then select for your ship'}
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
                            onUnlockClick={(module) =>
                              handleUnlockClick('upgrade', module)
                            }
                            onHoverModule={(moduleId) =>
                              setHoverModule(
                                moduleId
                                  ? { slot: slot.key, moduleId }
                                  : null,
                              )
                            }
                          />
                        </Stack.Item>
                      ))}
                      {(!slots || slots.length === 0) && (
                        <Stack.Item>
                          <Box color="label" textAlign="center" py={2}>
                            No upgrade slots available for this configuration.
                          </Box>
                        </Stack.Item>
                      )}
                    </Stack>
                  </Section>
                </Stack.Item>
              )}

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
          </Stack.Item>

          {/* Right column: live ship preview */}
          {hasPreview && preview && (
            <Stack.Item grow>
              <Stack vertical fill>
                <Stack.Item>
                  <Section
                    title="Ship Preview"
                    buttons={
                      <Box fontSize="12px" color="label">
                        {hoverTheme
                          ? (themes?.find((t) => t.id === hoverTheme)?.name ??
                            '')
                          : (selectedThemeData?.name ?? '')}
                      </Box>
                    }
                  >
                    <ShipPreview
                      preview={preview}
                      themeKey={previewThemeKey}
                      slots={slots}
                      selectedUpgrades={selected_upgrades}
                      hoverModule={hoverModule}
                    />
                    <Box fontSize="11px" color="label" mt={1} textAlign="center">
                      Hover a theme or module to preview it on the map.
                    </Box>
                  </Section>
                </Stack.Item>
                <Stack.Item grow>
                  <Section title="Current Loadout" fill scrollable>
                    {slots?.map((slot) => {
                      const moduleId =
                        hoverModule?.slot === slot.key
                          ? hoverModule.moduleId
                          : selected_upgrades?.[slot.key];
                      const module =
                        slot.modules.find((m) => m.id === moduleId) ??
                        slot.modules.find((m) => m.is_default);
                      return (
                        <Box key={slot.key} mb={1}>
                          <Box color="label" fontSize="11px">
                            {slot.display_name}
                          </Box>
                          <Box color="white" bold>
                            {module?.name ?? 'Empty'}
                            {hoverModule?.slot === slot.key && (
                              <Box as="span" color="average" ml={1}>
                                (previewing)
                              </Box>
                            )}
                          </Box>
                        </Box>
                      );
                    })}
                  </Section>
                </Stack.Item>
              </Stack>
            </Stack.Item>
          )}
        </Stack>
      </Window.Content>
    </Window>
  );
};

/**
 * Composited top-down map preview: hull image with the effective module for
 * each upgrade slot overlaid at its slot marker position, exactly as the
 * modular map loader will place it in-game.
 */
const ShipPreview = (props: {
  preview: PreviewData;
  themeKey: string;
  slots: UpgradeSlot[];
  selectedUpgrades: Record<string, string>;
  hoverModule: HoverModule | null;
}) => {
  const { preview, themeKey, slots, selectedUpgrades, hoverModule } = props;
  const hull = preview.hulls[themeKey] ?? preview.hulls[''];

  if (!hull) {
    return (
      <Box color="label" textAlign="center" py={4}>
        No preview available for this configuration.
      </Box>
    );
  }

  const overlays: ReactNode[] = [];
  Object.entries(hull.slots).forEach(([slotKey, marker]) => {
    const [sx, sy] = marker;
    const slotInfo = slots?.find((s) => s.key === slotKey);
    const isHovered = !!hoverModule && hoverModule.slot === slotKey;
    const moduleId =
      hoverModule && hoverModule.slot === slotKey
        ? hoverModule.moduleId
        : (selectedUpgrades?.[slotKey] ??
          slotInfo?.modules.find((m) => m.is_default)?.id);
    const mod = moduleId ? preview.modules[moduleId] : undefined;
    if (!mod) {
      return;
    }
    // Themed reskin geometry if one exists, else the base module art
    const geom = (themeKey && mod.themes?.[themeKey]) || mod;
    const [cx, cy] = geom.connector ?? [1, 1];
    // The loader aligns the module's connector tile onto the slot marker tile
    const px0 = sx - (cx - 1);
    const py0 = sy - (cy - 1);
    const leftPct = ((px0 - 1) / hull.width) * 100;
    const topPct = ((hull.height - (py0 - 1) - geom.height) / hull.height) * 100;
    const widthPct = (geom.width / hull.width) * 100;
    const heightPct = (geom.height / hull.height) * 100;
    const boxStyle: CSSProperties = {
      position: 'absolute',
      left: `${leftPct}%`,
      top: `${topPct}%`,
      width: `${widthPct}%`,
      height: `${heightPct}%`,
    };
    overlays.push(
      <img
        key={`img-${slotKey}`}
        src={resolveAsset(geom.png)}
        style={{
          ...boxStyle,
          imageRendering: 'pixelated',
        }}
      />,
      <div
        key={`outline-${slotKey}`}
        style={{
          ...boxStyle,
          border: isHovered
            ? '2px dashed rgba(255, 200, 0, 0.9)'
            : '1px dashed rgba(255, 255, 255, 0.35)',
          pointerEvents: 'none',
        }}
      >
        <div
          style={{
            position: 'absolute',
            top: '-1px',
            left: '-1px',
            padding: '0 3px',
            fontSize: '9px',
            whiteSpace: 'nowrap',
            color: isHovered ? '#ffc800' : 'rgba(255, 255, 255, 0.75)',
            backgroundColor: 'rgba(0, 0, 0, 0.6)',
          }}
        >
          {slotInfo?.display_name ?? slotKey}
        </div>
      </div>,
    );
  });

  return (
    <Box
      style={{
        position: 'relative',
        width: '100%',
        paddingBottom: `${(hull.height / hull.width) * 100}%`,
        backgroundColor: 'black',
      }}
    >
      <img
        src={resolveAsset(hull.png)}
        style={{
          position: 'absolute',
          left: 0,
          top: 0,
          width: '100%',
          height: '100%',
          imageRendering: 'pixelated',
        }}
      />
      {overlays}
    </Box>
  );
};

const UpgradeSlotSection = (props: {
  slot: UpgradeSlot;
  selectedModuleId?: string;
  playerParts: PartsInventory;
  unlockedUpgrades: string[];
  onUnlockClick: (module: UpgradeModule) => void;
  onHoverModule: (moduleId: string | null) => void;
}) => {
  const { act } = useBackend<ShipUpgradeSelectorData>();
  const {
    slot,
    selectedModuleId,
    playerParts,
    unlockedUpgrades,
    onUnlockClick,
    onHoverModule,
  } = props;

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
              <div
                onMouseEnter={() => onHoverModule(module.id)}
                onMouseLeave={() => onHoverModule(null)}
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
                          {!!module.is_default && (
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
              </div>
            </Stack.Item>
          );
        })}
        {slot.modules.length === 0 && (
          <Stack.Item>
            <Box color="label" textAlign="center" py={1}>
              No modules available for this slot.
            </Box>
          </Stack.Item>
        )}
      </Stack>
    </Section>
  );
};

// Helper function to capitalize first letter
function capitalize(str: string): string {
  return str.charAt(0).toUpperCase() + str.slice(1);
}
