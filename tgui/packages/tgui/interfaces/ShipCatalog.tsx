import { useState } from 'react';
import {
  Box,
  Button,
  Icon,
  Section,
  Stack,
  Tooltip,
} from 'tgui-core/components';
import { classes } from 'tgui-core/react';

import { useBackend } from '../backend';
import { Window } from '../layouts';

type PartsInventory = {
  combat: number;
  science: number;
  trade: number;
  misc: number;
};

type ShipCatalogData = {
  credits: number;
  parts: PartsInventory;
  ships: ShipEntry[];
  unlocked_ships: string[];
  selected_faction: string | null;
  search_query: string;
  latejoin_mode?: boolean;
};

type ShipEntry = {
  id: string;
  name: string;
  short_name: string;
  suffix: string;
  preview_image: string;
  crew_capacity: number;
  primary_class: string;
  total_parts: number;
  description: string;
  parts_required: Partial<PartsInventory>;
  faction: string;
  jobs: Array<{
    name: string;
    slots: number;
    officer: boolean;
  }>;
};

const CLASS_COLORS: Record<string, string> = {
  free: '#00ff88',
  combat: '#ff4444',
  science: '#4488ff',
  trade: '#ffcc00',
  misc: '#9d9d9d',
};

const CLASS_ICONS: Record<string, string> = {
  free: 'gift',
  combat: 'crosshairs',
  science: 'flask',
  trade: 'coins',
  misc: 'puzzle-piece',
};

const CLASS_ORDER = ['free', 'combat', 'science', 'trade', 'misc'];

export const ShipCatalog = (props) => {
  const { act, data } = useBackend<ShipCatalogData>();
  const { credits, parts, ships, unlocked_ships, latejoin_mode } = data;
  const [selectedClass, setSelectedClass] = useState<string | null>(null);

  // Filter ships by primary class
  const filteredShips = selectedClass
    ? ships.filter((ship) => ship.primary_class === selectedClass)
    : ships;

  // Helper to check if ship is unlocked
  const isShipUnlocked = (shipId: string) => unlocked_ships?.includes(shipId);

  return (
    <Window title="Ship Catalog" width={700} height={600}>
      <Window.Content scrollable>
        <Stack vertical fill>
          {/* Header with Credits and Parts */}
          <Stack.Item>
            <Section>
              <Stack>
                <Stack.Item grow>
                  <Stack vertical>
                    <Stack.Item>
                      <Box fontSize="18px" bold color="gold">
                        <Icon name="coins" mr={1} />
                        Credits: {credits.toLocaleString()}
                      </Box>
                    </Stack.Item>
                    <Stack.Item>
                      <Box fontSize="14px" color="lightgray">
                        <Icon name="puzzle-piece" mr={1} />
                        Parts:{' '}
                        <Box as="span" color={CLASS_COLORS.combat}>
                          <Icon name={CLASS_ICONS.combat} mr={0.5} />
                          {parts.combat || 0} Combat
                        </Box>
                        {', '}
                        <Box as="span" color={CLASS_COLORS.science}>
                          <Icon name={CLASS_ICONS.science} mr={0.5} />
                          {parts.science || 0} Science
                        </Box>
                        {', '}
                        <Box as="span" color={CLASS_COLORS.trade}>
                          <Icon name={CLASS_ICONS.trade} mr={0.5} />
                          {parts.trade || 0} Trade
                        </Box>
                        {', '}
                        <Box as="span" color={CLASS_COLORS.misc}>
                          <Icon name={CLASS_ICONS.misc} mr={0.5} />
                          {parts.misc || 0} Misc
                        </Box>
                      </Box>
                    </Stack.Item>
                  </Stack>
                </Stack.Item>
              </Stack>
            </Section>
          </Stack.Item>

          {/* Class Filter */}
          <Stack.Item>
            <Section>
              <Stack>
                <Stack.Item>
                  <Button
                    selected={selectedClass === null}
                    onClick={() => setSelectedClass(null)}
                    icon="asterisk"
                  >
                    All Ships
                  </Button>
                </Stack.Item>
                {CLASS_ORDER.map((partClass) => (
                  <Stack.Item key={partClass}>
                    <Button
                      selected={selectedClass === partClass}
                      onClick={() => setSelectedClass(partClass)}
                      icon={CLASS_ICONS[partClass]}
                      color={
                        selectedClass === partClass ? 'transparent' : 'default'
                      }
                      style={{
                        color: CLASS_COLORS[partClass],
                        borderColor:
                          selectedClass === partClass
                            ? CLASS_COLORS[partClass]
                            : undefined,
                      }}
                    >
                      {partClass.charAt(0).toUpperCase() + partClass.slice(1)}
                    </Button>
                  </Stack.Item>
                ))}
              </Stack>
            </Section>
          </Stack.Item>

          {/* Ship List */}
          <Stack.Item grow>
            <Section fill scrollable>
              {filteredShips.length === 0 ? (
                <Box textAlign="center" color="gray" fontSize="16px" mt={4}>
                  No ships found in this category.
                </Box>
              ) : (
                <Stack vertical>
                  {filteredShips.map((ship) => (
                    <Stack.Item key={ship.id}>
                      <ShipCard
                        ship={ship}
                        parts={parts}
                        isUnlocked={isShipUnlocked(ship.id)}
                        latejoinMode={latejoin_mode}
                      />
                    </Stack.Item>
                  ))}
                </Stack>
              )}
            </Section>
          </Stack.Item>
        </Stack>
      </Window.Content>
    </Window>
  );
};

const ShipCard = (props: {
  ship: ShipEntry;
  parts: PartsInventory;
  isUnlocked: boolean;
  latejoinMode?: boolean;
}) => {
  const { act } = useBackend<ShipCatalogData>();
  const { ship, parts, isUnlocked, latejoinMode } = props;

  // Calculate if player can afford to unlock
  const canAfford =
    !isUnlocked &&
    Object.entries(ship.parts_required).every(([partClass, cost]) => {
      return (parts[partClass as keyof PartsInventory] || 0) >= (cost || 0);
    });

  // Format unlock cost for display
  const formatUnlockCost = () => {
    const costs = Object.entries(ship.parts_required)
      .filter(([_, cost]) => cost && cost > 0)
      .map(([partClass, cost]) => (
        <Box
          key={partClass}
          as="span"
          color={CLASS_COLORS[partClass]}
          style={{ marginRight: '8px' }}
        >
          <Icon name={CLASS_ICONS[partClass]} mr={0.5} />
          {cost} {partClass.charAt(0).toUpperCase() + partClass.slice(1)}
        </Box>
      ));

    return costs.length > 0 ? costs : 'Free';
  };

  return (
    <Section
      style={{
        borderLeft: `4px solid ${CLASS_COLORS[ship.primary_class]}`,
        marginBottom: '8px',
      }}
    >
      <Stack>
        {/* Ship Image */}
        <Stack.Item>
          <Box
            width="96px"
            height="96px"
            style={{
              border: `2px solid ${CLASS_COLORS[ship.primary_class]}`,
              borderRadius: '4px',
              display: 'flex',
              alignItems: 'center',
              justifyContent: 'center',
              backgroundColor: 'rgba(0, 0, 0, 0.3)',
            }}
          >
            {ship.preview_image ? (
              <Box
                className={classes(['ship96x96', ship.preview_image])}
                style={{ width: '100%', height: '100%' }}
              />
            ) : (
              <Icon
                name="rocket"
                size={4}
                color={CLASS_COLORS[ship.primary_class]}
              />
            )}
          </Box>
        </Stack.Item>

        {/* Ship Details */}
        <Stack.Item grow>
          <Stack vertical>
            <Stack.Item>
              <Box fontSize="20px" bold>
                {ship.name}
              </Box>
            </Stack.Item>
            <Stack.Item>
              <Box fontSize="14px" color="lightgray" italic>
                {ship.description}
              </Box>
            </Stack.Item>
            <Stack.Item mt={1}>
              <Stack>
                <Stack.Item>
                  <Tooltip content="Maximum crew capacity">
                    <Box>
                      <Icon name="users" mr={1} />
                      Crew: {ship.crew_capacity}
                    </Box>
                  </Tooltip>
                </Stack.Item>
                <Stack.Item ml={2}>
                  <Box color={CLASS_COLORS[ship.primary_class]}>
                    <Icon name={CLASS_ICONS[ship.primary_class]} mr={1} />
                    Type:{' '}
                    {ship.primary_class.charAt(0).toUpperCase() +
                      ship.primary_class.slice(1)}
                  </Box>
                </Stack.Item>
              </Stack>
            </Stack.Item>

            {/* Unlock Requirements */}
            {!isUnlocked && (
              <Stack.Item mt={1}>
                <Box fontSize="13px" color="yellow">
                  <Icon name="lock" mr={1} />
                  Requires: {formatUnlockCost()}
                </Box>
              </Stack.Item>
            )}

            {/* Status and Actions */}
            <Stack.Item mt={1}>
              <Stack>
                {isUnlocked ? (
                  <>
                    <Stack.Item>
                      <Box color="good" fontSize="14px">
                        <Icon name="check-circle" mr={1} />
                        Unlocked
                      </Box>
                    </Stack.Item>
                    <Stack.Item ml={2}>
                      <Button
                        icon="rocket"
                        color="good"
                        onClick={() =>
                          act(
                            latejoinMode ? 'select_for_latejoin' : 'spawn_ship',
                            {
                              ship_id: ship.id,
                            },
                          )
                        }
                      >
                        {latejoinMode ? 'SELECT SHIP' : 'SPAWN SHIP'}
                      </Button>
                    </Stack.Item>
                  </>
                ) : (
                  <Stack.Item>
                    <Button
                      icon="unlock"
                      color={canAfford ? 'blue' : 'gray'}
                      disabled={!canAfford}
                      tooltip={
                        !canAfford
                          ? 'You do not have enough parts to unlock this ship'
                          : 'Spend parts to unlock this ship'
                      }
                      onClick={() =>
                        act('unlock_ship', {
                          ship_id: ship.id,
                        })
                      }
                    >
                      {canAfford ? 'UNLOCK SHIP' : 'INSUFFICIENT PARTS'}
                    </Button>
                  </Stack.Item>
                )}
              </Stack>
            </Stack.Item>
          </Stack>
        </Stack.Item>
      </Stack>
    </Section>
  );
};
