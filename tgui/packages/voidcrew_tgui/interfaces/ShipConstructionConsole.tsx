import { useState } from 'react';

import { useBackend } from '../../tgui/backend';
import {
  Box,
  Button,
  Collapsible,
  Dropdown,
  LabeledList,
  NoticeBox,
  ProgressBar,
  Section,
  Stack,
  Table,
  Tabs,
} from 'tgui-core/components';
import { Window } from '../../tgui/layouts';

interface AirlockData {
  name: string;
  ref: string;
  x: number;
  y: number;
  isCurrent: boolean;
  areaName: string;
}

interface PortData {
  x: number;
  y: number;
  dir: string;
  port_direction: string;
}

interface Data {
  canOperate: boolean;
  shipState: string;
  shipName: string;
  isNotCrew: boolean;
  lastMessage: string;
  lastSuccess: boolean;
  currentPort: PortData | null;
  dockingPortOnEdge: boolean;
  airlocks: AirlockData[];
  rcdMatter: number;
  rcdMaxMatter: number;
  usingSilo: boolean;
  isInConstructionMode: boolean;
  shipWidth: number;
  shipHeight: number;
  maxDimensionLong: number;
  maxDimensionShort: number;
  shipMass: number;
  maxIntegrity: number;
  integrity: number;
  overhealth: number;
  theme?: string;
}

type TabType = 'construction' | 'relocation' | 'settings';

export const ShipConstructionConsole = () => {
  const { act, data } = useBackend<Data>();
  const {
    canOperate,
    isNotCrew,
    lastMessage,
    lastSuccess,
    currentPort,
    airlocks,
    rcdMatter,
    rcdMaxMatter,
    usingSilo,
    isInConstructionMode,
    shipWidth,
    shipHeight,
    maxDimensionLong,
    maxDimensionShort,
    shipMass,
    maxIntegrity,
    integrity,
    overhealth,
    theme,
  } = data;

  const [activeTab, setActiveTab] = useState<TabType>('construction');

  return (
    <Window width={480} height={400} title="Ship Construction Console" theme={theme}>
      <Window.Content scrollable>
        <Stack vertical fill>
          {/* Operation Status Message */}
          {!!lastMessage && (
            <Stack.Item>
              <NoticeBox success={lastSuccess} danger={!lastSuccess}>
                {lastMessage}
                <Button
                  icon="times"
                  ml={1}
                  onClick={() => act('clear_message')}
                />
              </NoticeBox>
            </Stack.Item>
          )}

          {/* Tab Navigation */}
          <Stack.Item>
            <Tabs>
              <Tabs.Tab
                selected={activeTab === 'construction'}
                onClick={() => setActiveTab('construction')}
              >
                Construction
              </Tabs.Tab>
              <Tabs.Tab
                selected={activeTab === 'relocation'}
                onClick={() => setActiveTab('relocation')}
              >
                Port Relocation
              </Tabs.Tab>
              <Tabs.Tab
                selected={activeTab === 'settings'}
                onClick={() => setActiveTab('settings')}
                icon="cog"
              >
                Settings
              </Tabs.Tab>
            </Tabs>
          </Stack.Item>

          {/* Tab Content */}
          <Stack.Item grow>
            {activeTab === 'construction' && (
              <ConstructionTab
                canOperate={canOperate}
                isNotCrew={isNotCrew}
                rcdMatter={rcdMatter}
                rcdMaxMatter={rcdMaxMatter}
                usingSilo={usingSilo}
                isInConstructionMode={isInConstructionMode}
                shipWidth={shipWidth}
                shipHeight={shipHeight}
                maxDimensionLong={maxDimensionLong}
                maxDimensionShort={maxDimensionShort}
                shipMass={shipMass}
                maxIntegrity={maxIntegrity}
                integrity={integrity}
                overhealth={overhealth}
              />
            )}
            {activeTab === 'relocation' && (
              <RelocationTab
                canOperate={canOperate}
                isNotCrew={isNotCrew}
                currentPort={currentPort}
                airlocks={airlocks}
              />
            )}
            {activeTab === 'settings' && <SettingsTab />}
          </Stack.Item>
        </Stack>
      </Window.Content>
    </Window>
  );
};

interface ConstructionTabProps {
  canOperate: boolean;
  isNotCrew: boolean;
  rcdMatter: number;
  rcdMaxMatter: number;
  usingSilo: boolean;
  isInConstructionMode: boolean;
  shipWidth: number;
  shipHeight: number;
  maxDimensionLong: number;
  maxDimensionShort: number;
  shipMass: number;
  maxIntegrity: number;
  integrity: number;
  overhealth: number;
}

const ConstructionTab = (props: ConstructionTabProps) => {
  const { act } = useBackend();
  const {
    canOperate,
    isNotCrew,
    rcdMatter,
    rcdMaxMatter,
    usingSilo,
    isInConstructionMode,
    shipWidth,
    shipHeight,
    maxDimensionLong,
    maxDimensionShort,
    shipMass,
    maxIntegrity,
    integrity,
    overhealth,
  } = props;

  return (
    <Stack vertical fill>
      {/* Ship Status - Consolidated section */}
      <Stack.Item>
        <Section title="Ship Status">
          <Stack vertical>
            {/* Integrity Bar - Full Width */}
            <Stack.Item>
              <Box mb={1}>
                <Box inline color="label" width="80px">
                  Integrity:
                </Box>
                <Box inline width="calc(100% - 85px)">
                  <ProgressBar
                    value={integrity}
                    maxValue={100 + overhealth}
                    ranges={{
                      good: [70, Infinity],
                      average: [40, 70],
                      bad: [-Infinity, 40],
                    }}
                  >
                    {integrity}%
                    {overhealth > 0 && ` (+${overhealth}%)`}
                  </ProgressBar>
                </Box>
              </Box>
            </Stack.Item>

            {/* Two column layout for dimensions and mass */}
            <Stack.Item>
              <Stack>
                <Stack.Item grow basis={0}>
                  <Box color="label" mb={0.5}>
                    Dimensions
                  </Box>
                  <Box fontSize="14px">
                    {shipWidth} x {shipHeight}
                    <Box as="span" color="label" ml={1}>
                      (max {maxDimensionLong})
                    </Box>
                  </Box>
                </Stack.Item>
                <Stack.Item grow basis={0}>
                  <Box color="label" mb={0.5}>
                    Mass
                  </Box>
                  <Box fontSize="14px">
                    {shipMass} / {maxIntegrity} units
                    {shipMass > maxIntegrity && (
                      <Box as="span" color="good" ml={1}>
                        (+{shipMass - maxIntegrity})
                      </Box>
                    )}
                  </Box>
                </Stack.Item>
              </Stack>
            </Stack.Item>
          </Stack>
        </Section>
      </Stack.Item>

      {/* Construction Drone - Main action section */}
      <Stack.Item>
        <Section title="Construction Drone">
          <Stack vertical>
            <Stack.Item>
              <Stack align="center">
                <Stack.Item grow>
                  <Box color="label" inline mr={1}>
                    RCD:
                  </Box>
                  {usingSilo ? (
                    <Box inline color="good">
                      {rcdMatter} units (Silo)
                    </Box>
                  ) : (
                    <Box inline width="200px">
                      <ProgressBar
                        value={rcdMatter}
                        maxValue={rcdMaxMatter}
                        ranges={{
                          good: [rcdMaxMatter * 0.5, Infinity],
                          average: [rcdMaxMatter * 0.25, rcdMaxMatter * 0.5],
                          bad: [-Infinity, rcdMaxMatter * 0.25],
                        }}
                      >
                        {rcdMatter} / {rcdMaxMatter}
                      </ProgressBar>
                    </Box>
                  )}
                </Stack.Item>
                {isInConstructionMode && (
                  <Stack.Item>
                    <Box color="good" bold>
                      ACTIVE
                    </Box>
                  </Stack.Item>
                )}
              </Stack>
            </Stack.Item>
            <Stack.Item mt={1}>
              <Button
                fluid
                icon={isInConstructionMode ? 'check' : 'hammer'}
                content={
                  isInConstructionMode
                    ? 'Construction Mode Active'
                    : 'Enter Construction Mode'
                }
                color={isInConstructionMode ? 'good' : 'default'}
                disabled={!canOperate || isNotCrew || isInConstructionMode}
                onClick={() => act('enter_construction_mode')}
              />
            </Stack.Item>
          </Stack>
        </Section>
      </Stack.Item>

      {/* Collapsible Help Section */}
      <Stack.Item>
        <Collapsible title="Help" color="label">
          <Box color="gray" fontSize="12px">
            <Box mb={0.5}>
              <b>Build:</b> Construct within ship or 1 tile adjacent to expand
            </Box>
            <Box mb={0.5}>
              <b>Deconstruct:</b> Remove structures to shrink ship
            </Box>
            <Box>
              <b>Controls:</b> Arrow keys to move, action buttons to build
            </Box>
          </Box>
        </Collapsible>
      </Stack.Item>

      {!canOperate && (
        <Stack.Item>
          <NoticeBox warning>
            Ship must be docked to use construction features.
          </NoticeBox>
        </Stack.Item>
      )}
    </Stack>
  );
};

interface RelocationTabProps {
  canOperate: boolean;
  isNotCrew: boolean;
  currentPort: PortData | null;
  airlocks: AirlockData[];
}

const RelocationTab = (props: RelocationTabProps) => {
  const { act } = useBackend();
  const { canOperate, isNotCrew, currentPort, airlocks } = props;

  return (
    <Stack vertical fill>
      {/* Current Port Info - Compact */}
      <Stack.Item>
        <Section
          title="Current Docking Port"
          buttons={
            <Button
              icon="fan"
              content="Reset Fans"
              tooltip="Removes all tiny fans and adds new ones to all edge airlocks"
              disabled={!canOperate || isNotCrew}
              onClick={() => act('reset_fans')}
            />
          }
        >
          {currentPort ? (
            <Box>
              Position: ({currentPort.x}, {currentPort.y}) facing{' '}
              {currentPort.dir}
            </Box>
          ) : (
            <Box color="bad">No docking port detected</Box>
          )}
        </Section>
      </Stack.Item>

      {/* Airlocks Table */}
      <Stack.Item grow>
        <Section title="Available Airlocks" fill scrollable>
          <Table>
            <Table.Row header>
              <Table.Cell>Airlock</Table.Cell>
              <Table.Cell>Area</Table.Cell>
              <Table.Cell>Action</Table.Cell>
            </Table.Row>
            {airlocks.map((airlock) => (
              <Table.Row
                key={airlock.ref}
                className={airlock.isCurrent ? 'Table__row--selected' : ''}
              >
                <Table.Cell>
                  {airlock.name}
                  {airlock.isCurrent && (
                    <Box as="span" color="good" ml={1}>
                      (Current)
                    </Box>
                  )}
                </Table.Cell>
                <Table.Cell color="label">{airlock.areaName}</Table.Cell>
                <Table.Cell collapsing>
                  <Button
                    icon="crosshairs"
                    content="Set"
                    disabled={!canOperate || isNotCrew || airlock.isCurrent}
                    onClick={() =>
                      act('relocate_port', {
                        airlock_ref: airlock.ref,
                      })
                    }
                  />
                </Table.Cell>
              </Table.Row>
            ))}
            {airlocks.length === 0 && (
              <Table.Row>
                <Table.Cell colSpan={3}>
                  <NoticeBox>No valid edge airlocks found.</NoticeBox>
                </Table.Cell>
              </Table.Row>
            )}
          </Table>
        </Section>
      </Stack.Item>

      {!canOperate && (
        <Stack.Item>
          <NoticeBox warning>Ship must be docked.</NoticeBox>
        </Stack.Item>
      )}
    </Stack>
  );
};

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
