import { map } from 'es-toolkit/compat';
import { useState } from 'react';
import {
  Box,
  Button,
  Collapsible,
  Flex,
  Icon,
  LabeledList,
  Section,
  Stack,
  Table,
  Tabs,
} from 'tgui-core/components';

import { useBackend } from '../backend';
import { Window } from '../layouts';

export const ShuttleManipulator = (props) => {
  const [tab, setTab] = useState(1);

  return (
    <Window title="Shuttle Manipulator" width={800} height={600} theme="admin">
      <Window.Content scrollable>
        <Tabs>
          <Tabs.Tab selected={tab === 1} onClick={() => setTab(1)}>
            Status
          </Tabs.Tab>
          <Tabs.Tab selected={tab === 2} onClick={() => setTab(2)}>
            Templates
          </Tabs.Tab>
          <Tabs.Tab selected={tab === 3} onClick={() => setTab(3)}>
            Modification
          </Tabs.Tab>
        </Tabs>
        {tab === 1 && <ShuttleManipulatorStatus />}
        {tab === 2 && <ShuttleManipulatorTemplates />}
        {tab === 3 && <ShuttleManipulatorModification />}
      </Window.Content>
    </Window>
  );
};

export const ShuttleManipulatorStatus = (props) => {
  const { act, data } = useBackend();
  const shuttles = data.shuttles || [];
  return (
    <Section>
      <Table>
        {shuttles.map((shuttle) => (
          <Table.Row key={shuttle.id}>
            <Table.Cell>
              <Button
                content="JMP"
                key={shuttle.id}
                onClick={() =>
                  act('jump_to', {
                    type: 'mobile',
                    id: shuttle.id,
                  })
                }
              />
            </Table.Cell>
            <Table.Cell>
              <Button
                content="Fly"
                key={shuttle.id}
                disabled={!shuttle.can_fly}
                onClick={() =>
                  act('fly', {
                    id: shuttle.id,
                  })
                }
              />
            </Table.Cell>
            <Table.Cell>{shuttle.name}</Table.Cell>
            <Table.Cell>{shuttle.id}</Table.Cell>
            <Table.Cell>{shuttle.status}</Table.Cell>
            <Table.Cell>
              {shuttle.mode}
              {!!shuttle.timer && (
                <>
                  ({shuttle.timeleft})
                  <Button
                    content="Fast Travel"
                    key={shuttle.id}
                    disabled={!shuttle.can_fast_travel}
                    onClick={() =>
                      act('fast_travel', {
                        id: shuttle.id,
                      })
                    }
                  />
                </>
              )}
            </Table.Cell>
          </Table.Row>
        ))}
      </Table>
    </Section>
  );
};

export const ShuttleManipulatorTemplates = (props) => {
  const { act, data } = useBackend();
  const templateObject = data.templates || {};
  const selected = data.selected || {};
  const [selectedTemplateId, setSelectedTemplateId] = useState(
    Object.keys(templateObject)[0],
  );
  const actualTemplates = templateObject[selectedTemplateId]?.templates || [];

  return (
    <Section>
      <Flex>
        <Flex.Item>
          <Tabs vertical>
            {map(templateObject, (template, templateId) => (
              <Tabs.Tab
                key={templateId}
                selected={selectedTemplateId === templateId}
                onClick={() => setSelectedTemplateId(templateId)}
              >
                {template.port_id}
              </Tabs.Tab>
            ))}
          </Tabs>
        </Flex.Item>
        <Flex.Item grow={1} basis={0}>
          {actualTemplates.map((actualTemplate) => {
            const isSelected =
              actualTemplate.shuttle_id === selected.shuttle_id;
            // Whoever made the structure being sent is an asshole
            return (
              <Section
                title={actualTemplate.name}
                level={2}
                key={actualTemplate.shuttle_id}
                buttons={
                  <>
                    {actualTemplate.is_modular && (
                      <Box
                        as="span"
                        color="good"
                        mr={1}
                        style={{ fontSize: '11px' }}
                      >
                        <Icon name="puzzle-piece" mr={0.5} />
                        Modular
                      </Box>
                    )}
                    <Button
                      content={isSelected ? 'Selected' : 'Select'}
                      selected={isSelected}
                      onClick={() =>
                        act('select_template', {
                          shuttle_id: actualTemplate.shuttle_id,
                        })
                      }
                    />
                  </>
                }
              >
                {(!!actualTemplate.description ||
                  !!actualTemplate.admin_notes) && (
                  <LabeledList>
                    {!!actualTemplate.description && (
                      <LabeledList.Item label="Description">
                        {actualTemplate.description}
                      </LabeledList.Item>
                    )}
                    {!!actualTemplate.admin_notes && (
                      <LabeledList.Item label="Admin Notes">
                        {actualTemplate.admin_notes}
                      </LabeledList.Item>
                    )}
                  </LabeledList>
                )}
              </Section>
            );
          })}
        </Flex.Item>
      </Flex>
    </Section>
  );
};

export const ShuttleManipulatorModification = (props) => {
  const { act, data } = useBackend();
  const selected = data.selected || {};
  const existingShuttle = data.existing_shuttle || {};
  const modularData = data.modular_data;

  return (
    <Section>
      {selected ? (
        <>
          <Section level={2} title={selected.name}>
            {(!!selected.description || !!selected.admin_notes) && (
              <LabeledList>
                {!!selected.description && (
                  <LabeledList.Item label="Description">
                    {selected.description}
                  </LabeledList.Item>
                )}
                {!!selected.admin_notes && (
                  <LabeledList.Item label="Admin Notes">
                    {selected.admin_notes}
                  </LabeledList.Item>
                )}
              </LabeledList>
            )}
          </Section>

          {/* Modular Ship Configuration */}
          {selected.is_modular && modularData && (
            <ModularShipConfig modularData={modularData} />
          )}

          {existingShuttle ? (
            <Section
              level={2}
              title={`Existing Shuttle: ${existingShuttle.name}`}
            >
              <LabeledList>
                <LabeledList.Item
                  label="Status"
                  buttons={
                    <Button
                      content="Jump To"
                      onClick={() =>
                        act('jump_to', {
                          type: 'mobile',
                          id: existingShuttle.id,
                        })
                      }
                    />
                  }
                >
                  {existingShuttle.status}
                  {!!existingShuttle.timer && <>({existingShuttle.timeleft})</>}
                </LabeledList.Item>
              </LabeledList>
            </Section>
          ) : (
            <Section level={2} title="Existing Shuttle: None" />
          )}
          <Section level={2} title="Actions">
            <Button
              content="Load"
              color="good"
              onClick={() =>
                act('load', {
                  shuttle_id: selected.shuttle_id,
                })
              }
            />
            <Button
              content="Preview"
              onClick={() =>
                act('preview', {
                  shuttle_id: selected.shuttle_id,
                })
              }
            />
            <Button
              content="Replace"
              color="bad"
              onClick={() =>
                act('replace', {
                  shuttle_id: selected.shuttle_id,
                })
              }
            />
          </Section>
        </>
      ) : (
        'No shuttle selected'
      )}
    </Section>
  );
};

/**
 * Modular Ship Configuration component
 * Allows admins to select themes and upgrade modules for modular voidcrew ships
 */
const ModularShipConfig = ({ modularData }) => {
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
