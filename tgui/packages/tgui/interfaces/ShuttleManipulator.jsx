import { map } from 'es-toolkit/compat';
import { useState } from 'react';
import {
  // VOIDCREW EDIT: ship_upgrades configures modular hull themes and rooms in the admin panel.
  Box,
  Button,
  // VOIDCREW EDIT REMOVAL: ship_upgrades imports Collapsible in the modular hull configuration component.
  Flex,
  // VOIDCREW EDIT: ship_upgrades configures modular hull themes and rooms in the admin panel.
  Icon,
  LabeledList,
  Section,
  // VOIDCREW EDIT REMOVAL: ship_upgrades imports Stack in the modular hull configuration component.
  Table,
  Tabs,
} from 'tgui-core/components';

// VOIDCREW EDIT: ship_upgrades keeps admin ship configuration in the modular frontend.
import { ModularShipConfig } from 'voidcrew_tgui/components/ModularShipConfig';

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
                  // VOIDCREW EDIT START: ship_upgrades configures modular hull themes and rooms in the admin panel.
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
                  // VOIDCREW EDIT END
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
  // VOIDCREW EDIT: ship_upgrades configures modular hull themes and rooms in the admin panel.
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
          {/* VOIDCREW EDIT START: ship_upgrades configures modular hull themes and rooms in the admin panel. */}
          {selected.is_modular && modularData && (
            <ModularShipConfig modularData={modularData} />
          )}
          {/* VOIDCREW EDIT END */}

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
          {/* VOIDCREW EDIT: ship_upgrades configures modular hull themes and rooms in the admin panel. */}
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

// VOIDCREW EDIT: ship_upgrades renders configuration from voidcrew_tgui/components/ModularShipConfig.
