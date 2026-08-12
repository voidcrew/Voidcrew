import {
  type CSSProperties,
  type ReactNode,
  useEffect,
  useRef,
  useState,
} from 'react';
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

type HullEntry = {
  id: string;
  name: string;
  short_name: string;
  description: string;
  part_cost: Partial<PartsInventory>;
  crew_capacity: number;
  theme_count: number;
  slot_count: number;
  /** Costs nothing to unlock, so it's already yours */
  is_free: boolean;
};

/** Anything the confirmation modal can be pointed at. */
type PurchaseTarget = {
  id: string;
  name: string;
  desc?: string;
  part_cost?: Partial<PartsInventory>;
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
  hulls: HullEntry[];
  selected_hull: string | null;
  unlocked_ships: string[];
  hull_unlocked: boolean;
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

/** Share of the window height handed to the map before the user drags it. */
const SPLIT_DEFAULT = 0.6;
const SPLIT_MIN = 0.15;
const SPLIT_MAX = 0.85;

export const ShipUpgradeSelector = () => {
  const { act, data } = useBackend<ShipUpgradeSelectorData>();
  const {
    ship_name,
    hulls,
    selected_hull,
    unlocked_ships,
    hull_unlocked,
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

  // State for active tab - the hull is step one, you buy it before anything else
  const [activeTab, setActiveTab] = useState<'hull' | 'theme' | 'upgrades'>(
    'hull',
  );

  // Preview hover state: temporarily show a hovered theme/module on the map
  const [hoverTheme, setHoverTheme] = useState<string | null>(null);
  const [hoverModule, setHoverModule] = useState<HoverModule | null>(null);

  // Draggable split between the map on top and the selection lists below
  const splitContainerRef = useRef<HTMLDivElement>(null);
  const [split, setSplit] = useState(SPLIT_DEFAULT);
  const [dragging, setDragging] = useState(false);
  const [mapCollapsed, setMapCollapsed] = useState(false);

  useEffect(() => {
    if (!dragging) {
      return;
    }
    const stop = () => setDragging(false);
    const onMove = (event: MouseEvent) => {
      // The button was released somewhere we couldn't see - don't keep dragging
      if (event.buttons === 0) {
        stop();
        return;
      }
      const container = splitContainerRef.current;
      if (!container) {
        return;
      }
      const rect = container.getBoundingClientRect();
      if (rect.height <= 0) {
        return;
      }
      const fraction = (event.clientY - rect.top) / rect.height;
      setSplit(Math.min(SPLIT_MAX, Math.max(SPLIT_MIN, fraction)));
    };
    window.addEventListener('mousemove', onMove);
    window.addEventListener('mouseup', stop);
    return () => {
      window.removeEventListener('mousemove', onMove);
      window.removeEventListener('mouseup', stop);
    };
  }, [dragging]);

  // Effective tab - if no themes, the theme tab collapses into upgrades
  const effectiveTab =
    activeTab === 'hull'
      ? 'hull'
      : activeTab === 'theme' && has_themes && themes?.length > 0
        ? 'theme'
        : 'upgrades';

  // State for purchase confirmation modal
  const [confirmingPurchase, setConfirmingPurchase] = useState<{
    type: 'ship' | 'theme' | 'upgrade';
    item: PurchaseTarget;
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
    type: 'ship' | 'theme' | 'upgrade',
    item: PurchaseTarget,
  ) => {
    setConfirmingPurchase({ type, item });
  };

  const PURCHASE_ACTIONS = {
    ship: { action: 'unlock_hull', idKey: 'hull_id', label: 'Ship' },
    theme: { action: 'unlock_theme', idKey: 'theme_id', label: 'Theme' },
    upgrade: { action: 'unlock_upgrade', idKey: 'module_id', label: 'Upgrade' },
  } as const;

  // Confirm purchase
  const confirmPurchase = () => {
    if (confirmingPurchase) {
      const { action, idKey } = PURCHASE_ACTIONS[confirmingPurchase.type];
      act(action, { [idKey]: confirmingPurchase.item.id });
      setConfirmingPurchase(null);
    }
  };

  const selectedThemeData = themes?.find((t) => t.id === selected_theme);
  const selectedHullData = hulls?.find((h) => h.id === selected_hull);
  const canAffordHull = canAfford(selectedHullData?.part_cost);

  const hasPreview = !!(
    preview?.hulls && Object.keys(preview.hulls).length > 0
  );
  const showMap = hasPreview && !mapCollapsed;
  const previewThemeKey = hoverTheme ?? selected_theme ?? '';
  const previewLabel = hoverTheme
    ? (themes?.find((t) => t.id === hoverTheme)?.name ?? '')
    : (selectedThemeData?.name ?? '');

  const actionButtons = (
    <Stack vertical>
      {/* You have to own the hull before it'll fly */}
      {!hull_unlocked && !!selectedHullData && (
        <Stack.Item>
          <Box fontSize="11px" color="label" mb={0.5}>
            <Icon name="lock" mr={1} />
            You don&apos;t own the {selectedHullData.short_name} yet.
          </Box>
          <PartCostStrip cost={selectedHullData.part_cost} parts={parts} />
        </Stack.Item>
      )}
      <Stack.Item>
        <Stack justify="flex-end">
          <Stack.Item>
            <Button icon="times" color="bad" onClick={() => act('cancel')}>
              Cancel
            </Button>
          </Stack.Item>
          <Stack.Item ml={1}>
            {hull_unlocked ? (
              <Button icon="rocket" color="good" onClick={() => act('confirm')}>
                LAUNCH SHIP
              </Button>
            ) : (
              <Button
                icon="shopping-cart"
                color={canAffordHull ? 'caution' : 'gray'}
                disabled={!selectedHullData || !canAffordHull}
                tooltip={
                  canAffordHull
                    ? 'Spend parts to own this hull permanently'
                    : 'You cannot afford this hull'
                }
                onClick={() =>
                  selectedHullData &&
                  handleUnlockClick('ship', {
                    id: selectedHullData.id,
                    name: selectedHullData.name,
                    desc: describeHull(selectedHullData),
                    part_cost: selectedHullData.part_cost,
                  })
                }
              >
                {canAffordHull ? 'PURCHASE SHIP' : 'INSUFFICIENT PARTS'}
              </Button>
            )}
          </Stack.Item>
        </Stack>
      </Stack.Item>
    </Stack>
  );

  return (
    <Window
      title={ship_name ? `Shipyard: ${ship_name}` : 'Shipyard'}
      width={hasPreview ? 1200 : 650}
      height={hasPreview ? 900 : 650}
    >
      <Window.Content>
        {/* Purchase Confirmation Modal */}
        {!!confirmingPurchase && (
          <Modal>
            <Box fontSize="16px" bold mb={2}>
              {confirmingPurchase.type === 'ship' ? 'Purchase' : 'Unlock'}{' '}
              {PURCHASE_ACTIONS[confirmingPurchase.type].label}?
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
              {confirmingPurchase.type === 'ship'
                ? 'This is a one-time purchase. Once bought, this hull is yours to fly in every future round.'
                : `This is a one-time purchase. Once unlocked, you can use this ${confirmingPurchase.type} forever.`}
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
                  icon={
                    confirmingPurchase.type === 'ship'
                      ? 'shopping-cart'
                      : 'unlock'
                  }
                  onClick={confirmPurchase}
                  disabled={!canAfford(confirmingPurchase.item.part_cost)}
                >
                  Confirm Purchase
                </Button>
              </Stack.Item>
            </Stack>
          </Modal>
        )}

        <div
          ref={splitContainerRef}
          style={{
            display: 'flex',
            flexDirection: 'column',
            height: '100%',
            gap: '0.5em',
            // Keep the resize cursor while the pointer strays off the handle
            cursor: dragging ? 'ns-resize' : undefined,
            userSelect: dragging ? 'none' : undefined,
          }}
        >
          {/* Top row: the big ship preview, spanning the whole window */}
          {hasPreview && !!preview && (
            <div
              style={{
                flex: showMap ? `${split} 1 0` : '0 0 auto',
                minHeight: 0,
                // Never let the preview paint over the lists below it
                overflow: 'hidden',
              }}
            >
              <Section
                title="Ship Preview"
                fill={showMap}
                fitted
                buttons={
                  <Stack align="center">
                    <Stack.Item>
                      <PartsStrip parts={parts} />
                    </Stack.Item>
                    <Stack.Item ml={2}>
                      <Button
                        icon={showMap ? 'chevron-up' : 'chevron-down'}
                        tooltip={showMap ? 'Hide the map' : 'Show the map'}
                        onClick={() => setMapCollapsed(showMap)}
                      />
                    </Stack.Item>
                  </Stack>
                }
              >
                {!!showMap && (
                  <Stack vertical fill>
                    {/* minHeight lets this shrink past the map's own height */}
                    <Stack.Item grow style={{ minHeight: 0 }}>
                      <ShipPreview
                        preview={preview}
                        themeKey={previewThemeKey}
                        slots={slots}
                        selectedUpgrades={selected_upgrades}
                        hoverModule={hoverModule}
                      />
                    </Stack.Item>
                    <Stack.Item>
                      <Box
                        fontSize="11px"
                        color="label"
                        textAlign="center"
                        py={0.5}
                      >
                        {!!previewLabel && (
                          <Box as="span" color="white" bold mr={1}>
                            {previewLabel}
                          </Box>
                        )}
                        Hover a theme or module to preview it on the map.
                      </Box>
                    </Stack.Item>
                  </Stack>
                )}
              </Section>
            </div>
          )}

          {/* Drag this to trade map height against list height */}
          {!!showMap && (
            <SplitHandle
              active={dragging}
              onGrab={() => setDragging(true)}
              onReset={() => setSplit(SPLIT_DEFAULT)}
            />
          )}

          {/* Bottom row: selection lists, plus loadout when previewing */}
          <div
            style={{
              flex: showMap ? `${1 - split} 1 0` : '1 1 0',
              minHeight: 0,
            }}
          >
            <Stack fill>
              <Stack.Item grow>
                <Stack vertical fill>
                  {/* Header with Parts Inventory (in the preview header otherwise) */}
                  {!hasPreview && (
                    <Stack.Item>
                      <Section title="Your Parts">
                        <PartsStrip parts={parts} />
                      </Section>
                    </Stack.Item>
                  )}

                  {/* Tabs */}
                  <Stack.Item>
                    <Tabs>
                      <Tabs.Tab
                        selected={effectiveTab === 'hull'}
                        onClick={() => setActiveTab('hull')}
                      >
                        Hull
                      </Tabs.Tab>
                      {/* !! matters: DM sends has_themes as 0/1, and a bare 0
                          renders as the text "0" in the tab strip */}
                      {!!has_themes && !!themes?.length && (
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

                  {/* Hull Selection */}
                  {effectiveTab === 'hull' && (
                    <Stack.Item grow>
                      <Section
                        title="Ship Hull"
                        fill
                        scrollable
                        buttons={
                          <Box fontSize="12px" color="label">
                            Pick a hull to see it on the map
                          </Box>
                        }
                      >
                        <Stack vertical>
                          {hulls?.map((hull) => (
                            <Stack.Item key={hull.id}>
                              <HullRow
                                hull={hull}
                                parts={parts}
                                isSelected={selected_hull === hull.id}
                                isOwned={!!unlocked_ships?.includes(hull.id)}
                                onPurchaseClick={() =>
                                  handleUnlockClick('ship', {
                                    id: hull.id,
                                    name: hull.name,
                                    desc: describeHull(hull),
                                    part_cost: hull.part_cost,
                                  })
                                }
                              />
                            </Stack.Item>
                          ))}
                          {(!hulls || hulls.length === 0) && (
                            <Stack.Item>
                              <Box color="label" textAlign="center" py={2}>
                                No ships are available for purchase.
                              </Box>
                            </Stack.Item>
                          )}
                        </Stack>
                      </Section>
                    </Stack.Item>
                  )}

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
                                            color={
                                              isUnlocked ? 'white' : 'gray'
                                            }
                                          >
                                            {theme.name}
                                            {!!theme.is_default && (
                                              <Box
                                                as="span"
                                                color="label"
                                                ml={1}
                                              >
                                                (Default)
                                              </Box>
                                            )}
                                            {!!isUnlocked &&
                                              !theme.is_default && (
                                                <Box
                                                  as="span"
                                                  color="good"
                                                  ml={1}
                                                >
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
                                        {!!(
                                          theme.jobs && theme.jobs.length > 0
                                        ) && (
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
                                    {!isUnlocked && !!hasCost && (
                                      <Stack.Item>
                                        <Stack>
                                          {Object.entries(theme.part_cost)
                                            .filter(
                                              ([_, cost]) => cost && cost > 0,
                                            )
                                            .map(([partClass, cost]) => (
                                              <Stack.Item
                                                key={partClass}
                                                ml={1}
                                              >
                                                <Tooltip
                                                  content={`${cost} ${capitalize(partClass)} parts`}
                                                >
                                                  <Box
                                                    color={
                                                      (parts?.[
                                                        partClass as keyof PartsInventory
                                                      ] || 0) >= (cost || 0)
                                                        ? CLASS_COLORS[
                                                            partClass
                                                          ]
                                                        : 'bad'
                                                    }
                                                  >
                                                    <Icon
                                                      name={
                                                        CLASS_ICONS[partClass]
                                                      }
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
                                            isSelected
                                              ? 'check-circle'
                                              : 'circle'
                                          }
                                          color={
                                            isSelected ? 'good' : 'default'
                                          }
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
                                          color={
                                            affordable ? 'caution' : 'gray'
                                          }
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
                                No upgrade slots available for this
                                configuration.
                              </Box>
                            </Stack.Item>
                          )}
                        </Stack>
                      </Section>
                    </Stack.Item>
                  )}

                  {/* Actions (they live under the loadout when previewing) */}
                  {!hasPreview && (
                    <Stack.Item>
                      <Section>{actionButtons}</Section>
                    </Stack.Item>
                  )}
                </Stack>
              </Stack.Item>

              {/* Bottom right column: loadout summary and launch controls */}
              {!!hasPreview && (
                <Stack.Item width="19rem">
                  <Stack vertical fill>
                    <Stack.Item grow>
                      <Section title="Current Loadout" fill scrollable>
                        <Box mb={1}>
                          <Box color="label" fontSize="11px">
                            Hull
                          </Box>
                          <Box color="white" bold>
                            {selectedHullData?.short_name ?? ship_name}
                            {!hull_unlocked && (
                              <Box as="span" color="average" ml={1}>
                                (not owned)
                              </Box>
                            )}
                          </Box>
                        </Box>
                        {!!selectedThemeData && (
                          <Box mb={1}>
                            <Box color="label" fontSize="11px">
                              Theme
                            </Box>
                            <Box color="white" bold>
                              {selectedThemeData.name}
                            </Box>
                          </Box>
                        )}
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
                    <Stack.Item>
                      <Section>{actionButtons}</Section>
                    </Stack.Item>
                  </Stack>
                </Stack.Item>
              )}
            </Stack>
          </div>
        </div>
      </Window.Content>
    </Window>
  );
};

/**
 * Grab bar between the map and the lists below it. Drag to resize,
 * double click to snap back to the default split.
 */
const SplitHandle = (props: {
  active: boolean;
  onGrab: () => void;
  onReset: () => void;
}) => {
  const { active, onGrab, onReset } = props;
  const [hovered, setHovered] = useState(false);
  const lit = active || hovered;

  return (
    <div
      onMouseDown={(event) => {
        event.preventDefault();
        onGrab();
      }}
      onDoubleClick={onReset}
      onMouseEnter={() => setHovered(true)}
      onMouseLeave={() => setHovered(false)}
      title="Drag to resize, double click to reset"
      style={{
        flex: '0 0 auto',
        height: '10px',
        cursor: 'ns-resize',
        display: 'flex',
        alignItems: 'center',
        justifyContent: 'center',
      }}
    >
      <div
        style={{
          width: '90px',
          height: lit ? '4px' : '3px',
          borderRadius: '2px',
          backgroundColor: lit
            ? 'rgba(255, 200, 0, 0.9)'
            : 'rgba(255, 255, 255, 0.25)',
        }}
      />
    </div>
  );
};

/** One-line summary of what a hull gets you before any customization. */
function describeHull(hull: HullEntry): string {
  const bits = [`${hull.crew_capacity} crew`];
  if (hull.theme_count > 0) {
    bits.push(`${hull.theme_count} themes`);
  }
  if (hull.slot_count > 0) {
    bits.push(`${hull.slot_count} upgrade slots`);
  }
  return bits.join(' · ');
}

/** Part cost, each class red when the player is short of it. */
const PartCostStrip = (props: {
  cost: Partial<PartsInventory> | undefined;
  parts: PartsInventory;
}) => {
  const entries = Object.entries(props.cost || {}).filter(
    ([_, cost]) => cost && cost > 0,
  );

  if (entries.length === 0) {
    return <Box color="good">Free</Box>;
  }

  return (
    <Stack>
      {entries.map(([partClass, cost]) => (
        <Stack.Item key={partClass} mr={2}>
          <Tooltip content={`${cost} ${capitalize(partClass)} parts`}>
            <Box
              color={
                (props.parts?.[partClass as keyof PartsInventory] || 0) >=
                (cost || 0)
                  ? CLASS_COLORS[partClass]
                  : 'bad'
              }
            >
              <Icon name={CLASS_ICONS[partClass]} mr={0.5} />
              {cost} {capitalize(partClass)}
            </Box>
          </Tooltip>
        </Stack.Item>
      ))}
    </Stack>
  );
};

/**
 * One hull on the shelf. Selecting is free and swaps the map preview; the
 * purchase button only appears on hulls you don't own yet.
 */
const HullRow = (props: {
  hull: HullEntry;
  parts: PartsInventory;
  isSelected: boolean;
  isOwned: boolean;
  onPurchaseClick: () => void;
}) => {
  const { act } = useBackend<ShipUpgradeSelectorData>();
  const { hull, parts, isSelected, isOwned, onPurchaseClick } = props;

  const affordable = Object.entries(hull.part_cost || {}).every(
    ([partClass, cost]) =>
      (parts?.[partClass as keyof PartsInventory] || 0) >= (cost || 0),
  );

  return (
    <div
      style={{
        padding: '10px',
        marginBottom: '4px',
        backgroundColor: isSelected
          ? 'rgba(0, 200, 0, 0.15)'
          : 'rgba(255, 255, 255, 0.05)',
        border: isSelected
          ? '2px solid rgba(0, 200, 0, 0.5)'
          : '1px solid rgba(255, 255, 255, 0.1)',
        borderRadius: '4px',
      }}
    >
      <Stack align="center">
        <Stack.Item grow>
          <Stack vertical>
            <Stack.Item>
              <Box bold color="white">
                {hull.name}
                {!!isOwned && (
                  <Box as="span" color="good" ml={1}>
                    <Icon name={hull.is_free ? 'gift' : 'check'} />{' '}
                    {hull.is_free ? 'Free' : 'Owned'}
                  </Box>
                )}
              </Box>
            </Stack.Item>
            <Stack.Item>
              <Box color="label" fontSize="12px">
                {describeHull(hull)}
              </Box>
            </Stack.Item>
            {!!hull.description && (
              <Stack.Item mt={0.5}>
                <Box color="label" fontSize="12px" italic mr={2}>
                  {hull.description}
                </Box>
              </Stack.Item>
            )}
          </Stack>
        </Stack.Item>

        {/* Cost, until you own it */}
        {!isOwned && (
          <Stack.Item>
            <PartCostStrip cost={hull.part_cost} parts={parts} />
          </Stack.Item>
        )}

        <Stack.Item ml={2}>
          <Button
            icon={isSelected ? 'check-circle' : 'circle'}
            color={isSelected ? 'good' : 'default'}
            onClick={() => act('select_hull', { hull_id: hull.id })}
          >
            {isSelected ? 'Viewing' : 'View'}
          </Button>
        </Stack.Item>
        {!isOwned && (
          <Stack.Item ml={1}>
            <Button
              icon="shopping-cart"
              color={affordable ? 'caution' : 'gray'}
              disabled={!affordable}
              onClick={onPurchaseClick}
              tooltip={
                affordable
                  ? 'Spend parts to own this hull permanently'
                  : 'You cannot afford this hull'
              }
            >
              Purchase
            </Button>
          </Stack.Item>
        )}
      </Stack>
    </div>
  );
};

/** Compact one-line readout of the player's spendable parts. */
const PartsStrip = (props: { parts: PartsInventory }) => (
  <Stack>
    {Object.entries(props.parts || {}).map(([partClass, count]) => (
      <Stack.Item key={partClass} ml={2}>
        <Box color={CLASS_COLORS[partClass]}>
          <Icon name={CLASS_ICONS[partClass]} mr={1} />
          {count} {capitalize(partClass)}
        </Box>
      </Stack.Item>
    ))}
  </Stack>
);

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

  // Measure the space we've been given so the map can be scaled to fit it in
  // both axes - the window is much wider than a typical hull is tall.
  const containerRef = useRef<HTMLDivElement>(null);
  const [avail, setAvail] = useState({ width: 0, height: 0 });

  useEffect(() => {
    const element = containerRef.current;
    if (!element) {
      return;
    }
    const measure = () =>
      setAvail({ width: element.clientWidth, height: element.clientHeight });
    measure();
    const observer = new ResizeObserver(measure);
    observer.observe(element);
    return () => observer.disconnect();
  }, []);

  const scale = hull
    ? Math.min(avail.width / hull.width, avail.height / hull.height)
    : 0;
  const mapWidth = hull ? hull.width * scale : 0;
  const mapHeight = hull ? hull.height * scale : 0;

  const overlays: ReactNode[] = [];
  Object.entries(hull?.slots ?? {}).forEach(([slotKey, marker]) => {
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
    const topPct =
      ((hull.height - (py0 - 1) - geom.height) / hull.height) * 100;
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
            padding: '0 4px',
            fontSize: '11px',
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
    <div
      ref={containerRef}
      style={{
        position: 'relative',
        width: '100%',
        height: '100%',
        overflow: 'hidden',
      }}
    >
      {/*
       * The map is laid out in its own absolutely positioned layer so its
       * pixel size never counts towards the height of the box we measure.
       * If it did, shrinking the split would deadlock: the row can't get
       * smaller than the map, so the observer never sees less space, so the
       * map never scales down.
       */}
      <div
        style={{
          position: 'absolute',
          inset: 0,
          display: 'flex',
          alignItems: 'center',
          justifyContent: 'center',
        }}
      >
        {!hull && (
          <Box color="label" textAlign="center">
            No preview available for this configuration.
          </Box>
        )}
        {!!hull && scale > 0 && (
          <div
            style={{
              position: 'relative',
              width: `${mapWidth}px`,
              height: `${mapHeight}px`,
              // Not pure black: the darkest wall sprites (plastitanium,
              // cult) are near-black and vanish against it. A dim space
              // backdrop keeps dark hulls readable.
              background:
                'radial-gradient(ellipse at 35% 30%, #232a3d 0%, #161a26 65%, #10131c 100%)',
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
          </div>
        )}
      </div>
    </div>
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
                  {!isUnlocked && !!hasCost && (
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
