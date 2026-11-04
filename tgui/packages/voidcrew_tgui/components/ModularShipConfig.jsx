import { Box, Button, Collapsible, Icon, Section, Stack } from 'tgui-core/components';

import { useBackend } from 'tgui/backend';

/**
 * Modular Ship Configuration component
 * Allows admins to select themes and upgrade modules for modular voidcrew ships
 */
export const ModularShipConfig = ({ modularData }) => {
  const { act } = useBackend();
  const { themes, has_themes, slots, selected_theme, selected_upgrades } =
    modularData;

  return (
    <Section
      level={2}
      title="Ship Configuration"
      buttons={
        <Button
          icon="undo"
          content="Reset"
          onClick={() => act('clear_ship_selections')}
        />
      }
    >
      {/* Theme Selection */}
      {has_themes && themes && themes.length > 0 && (
        <Section
          level={3}
          title="Ship Theme"
          buttons={
            <Box fontSize="11px" color="label">
              Choose ship variant
            </Box>
          }
        >
          <Stack vertical>
            {themes.map((theme) => {
              const isSelected = selected_theme === theme.id;

              return (
                <Stack.Item key={theme.id}>
                  <Box
                    style={{
                      padding: '8px',
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
                              {theme.name}
                              {theme.is_default && (
                                <Box as="span" color="label" ml={1}>
                                  (Default)
                                </Box>
                              )}
                            </Box>
                          </Stack.Item>
                          <Stack.Item>
                            <Box color="gray" fontSize="12px">
                              {theme.desc}
                            </Box>
                          </Stack.Item>
                          {theme.jobs && theme.jobs.length > 0 && (
                            <Stack.Item>
                              <Collapsible title="Crew Roster" color="label">
                                <Box fontSize="11px" color="label" mt={1}>
                                  {theme.jobs.map((job, idx) => (
                                    <Box key={idx}>
                                      {job.officer && (
                                        <Icon
                                          name="star"
                                          color="gold"
                                          mr={1}
                                        />
                                      )}
                                      {job.slots}x {job.name}
                                    </Box>
                                  ))}
                                </Box>
                              </Collapsible>
                            </Stack.Item>
                          )}
                        </Stack>
                      </Stack.Item>

                      <Stack.Item ml={2}>
                        <Button
                          icon={isSelected ? 'check-circle' : 'circle'}
                          color={isSelected ? 'good' : 'default'}
                          onClick={() =>
                            act('select_ship_theme', { theme_id: theme.id })
                          }
                        >
                          {isSelected ? 'Selected' : 'Select'}
                        </Button>
                      </Stack.Item>
                    </Stack>
                  </Box>
                </Stack.Item>
              );
            })}
          </Stack>
        </Section>
      )}

      {/* Upgrade Slots */}
      {slots && slots.length > 0 && (
        <Section
          level={3}
          title="Upgrade Modules"
          buttons={
            <Box fontSize="11px" color="label">
              Select modules for each slot
            </Box>
          }
        >
          <Stack vertical>
            {slots.map((slot) => (
              <Stack.Item key={slot.key}>
                <UpgradeSlotSection
                  slot={slot}
                  selectedModuleId={selected_upgrades?.[slot.key]}
                />
              </Stack.Item>
            ))}
          </Stack>
        </Section>
      )}

      {(!slots || slots.length === 0) && (!has_themes || themes.length === 0) && (
        <Box color="label" textAlign="center" py={2}>
          No configuration options available for this ship.
        </Box>
      )}
    </Section>
  );
};

/**
 * Upgrade Slot Section component
 * Shows available modules for a single upgrade slot
 */
const UpgradeSlotSection = ({ slot, selectedModuleId }) => {
  const { act } = useBackend();

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

          return (
            <Stack.Item key={module.id}>
              <Box
                style={{
                  padding: '6px',
                  marginBottom: '2px',
                  backgroundColor: isSelected
                    ? 'rgba(0, 200, 0, 0.15)'
                    : 'rgba(255, 255, 255, 0.05)',
                  border: isSelected
                    ? '1px solid rgba(0, 200, 0, 0.5)'
                    : '1px solid rgba(255, 255, 255, 0.1)',
                  borderRadius: '4px',
                }}
              >
                <Stack align="center">
                  <Stack.Item grow>
                    <Stack vertical>
                      <Stack.Item>
                        <Box bold color="white">
                          {module.name}
                          {module.is_default && (
                            <Box as="span" color="label" ml={1}>
                              (Default)
                            </Box>
                          )}
                        </Box>
                      </Stack.Item>
                      <Stack.Item>
                        <Box color="gray" fontSize="11px">
                          {module.desc}
                        </Box>
                      </Stack.Item>
                    </Stack>
                  </Stack.Item>

                  <Stack.Item ml={2}>
                    <Button
                      icon={isSelected ? 'check-circle' : 'circle'}
                      color={isSelected ? 'good' : 'default'}
                      onClick={() =>
                        act('select_ship_upgrade', {
                          slot: slot.key,
                          module_id: module.id,
                        })
                      }
                    >
                      {isSelected ? 'Selected' : 'Select'}
                    </Button>
                  </Stack.Item>
                </Stack>
              </Box>
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
