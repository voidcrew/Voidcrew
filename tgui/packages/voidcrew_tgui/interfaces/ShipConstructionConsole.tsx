import { useState } from 'react';

import { useBackend } from '../../tgui/backend';
import {
  Button,
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
}

type TabType = 'overview' | 'construction' | 'relocation';

export const ShipConstructionConsole = () => {
  const { act, data } = useBackend<Data>();
  const {
    canOperate,
    shipState,
    shipName,
    isNotCrew,
    lastMessage,
    lastSuccess,
    currentPort,
    dockingPortOnEdge,
    airlocks,
    rcdMatter,
    rcdMaxMatter,
    usingSilo,
    isInConstructionMode,
    shipWidth,
    shipHeight,
    maxDimensionLong,
    maxDimensionShort,
  } = data;

  const [activeTab, setActiveTab] = useState<TabType>('overview');

  return (
    <Window width={550} height={550} title="Ship Construction Console">
      <Window.Content scrollable>
        <Stack vertical fill>
          {/* Crew Authorization Warning */}
          {!!isNotCrew && (
            <Stack.Item>
              <NoticeBox danger>CREW AUTHORIZATION REQUIRED</NoticeBox>
            </Stack.Item>
          )}

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
                selected={activeTab === 'overview'}
                onClick={() => setActiveTab('overview')}
              >
                Overview
              </Tabs.Tab>
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
            </Tabs>
          </Stack.Item>

          {/* Tab Content */}
          <Stack.Item grow>
            {activeTab === 'overview' && (
              <OverviewTab
                shipName={shipName}
                shipState={shipState}
                canOperate={canOperate}
                isNotCrew={isNotCrew}
                rcdMatter={rcdMatter}
                rcdMaxMatter={rcdMaxMatter}
                usingSilo={usingSilo}
                currentPort={currentPort}
                dockingPortOnEdge={dockingPortOnEdge}
                shipWidth={shipWidth}
                shipHeight={shipHeight}
                maxDimensionLong={maxDimensionLong}
                maxDimensionShort={maxDimensionShort}
              />
            )}
            {activeTab === 'construction' && (
              <ConstructionTab
                canOperate={canOperate}
                isNotCrew={isNotCrew}
                rcdMatter={rcdMatter}
                rcdMaxMatter={rcdMaxMatter}
                usingSilo={usingSilo}
                isInConstructionMode={isInConstructionMode}
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
          </Stack.Item>
        </Stack>
      </Window.Content>
    </Window>
  );
};

interface OverviewTabProps {
  shipName: string;
  shipState: string;
  canOperate: boolean;
  isNotCrew: boolean;
  rcdMatter: number;
  rcdMaxMatter: number;
  usingSilo: boolean;
  currentPort: PortData | null;
  dockingPortOnEdge: boolean;
  shipWidth: number;
  shipHeight: number;
  maxDimensionLong: number;
  maxDimensionShort: number;
}

const OverviewTab = (props: OverviewTabProps) => {
  const { act } = useBackend();
  const {
    shipName,
    shipState,
    canOperate,
    isNotCrew,
    rcdMatter,
    rcdMaxMatter,
    usingSilo,
    currentPort,
    dockingPortOnEdge,
    shipWidth,
    shipHeight,
    maxDimensionLong,
    maxDimensionShort,
  } = props;

  return (
    <Stack vertical fill>
      <Stack.Item>
        <Section title={shipName || 'Ship Construction Console'}>
          <LabeledList>
            <LabeledList.Item label="Ship Status">
              {shipState === 'idle' ? 'Docked' : 'In Flight'}
            </LabeledList.Item>
            <LabeledList.Item label="Console Status">
              {canOperate ? 'Ready' : 'Operations Unavailable'}
            </LabeledList.Item>
          </LabeledList>
        </Section>
      </Stack.Item>

      <Stack.Item>
        <Section title="Ship Dimensions">
          <LabeledList>
            <LabeledList.Item label="Width">
              <ProgressBar
                value={shipWidth}
                maxValue={maxDimensionLong}
                ranges={{
                  good: [0, maxDimensionShort],
                  average: [maxDimensionShort, maxDimensionLong],
                  bad: [maxDimensionLong, Infinity],
                }}
              >
                {shipWidth} / {maxDimensionLong}
              </ProgressBar>
            </LabeledList.Item>
            <LabeledList.Item label="Height">
              <ProgressBar
                value={shipHeight}
                maxValue={maxDimensionLong}
                ranges={{
                  good: [0, maxDimensionShort],
                  average: [maxDimensionShort, maxDimensionLong],
                  bad: [maxDimensionLong, Infinity],
                }}
              >
                {shipHeight} / {maxDimensionLong}
              </ProgressBar>
            </LabeledList.Item>
            <LabeledList.Item label="Limit Note" color="label">
              Max {maxDimensionLong}. Only one dimension may exceed{' '}
              {maxDimensionShort}.
            </LabeledList.Item>
          </LabeledList>
        </Section>
      </Stack.Item>

      <Stack.Item>
        <Section title="RCD Resources">
          <LabeledList>
            <LabeledList.Item label="Source">
              {usingSilo ? 'Ore Silo (Linked)' : 'Internal Storage'}
            </LabeledList.Item>
            <LabeledList.Item label="Matter">
              {usingSilo ? (
                `${rcdMatter} units available`
              ) : (
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
              )}
            </LabeledList.Item>
          </LabeledList>
        </Section>
      </Stack.Item>

      <Stack.Item>
        <Section title="Current Docking Port">
          {currentPort ? (
            <>
              <LabeledList>
                <LabeledList.Item label="Position">
                  ({currentPort.x}, {currentPort.y})
                </LabeledList.Item>
                <LabeledList.Item label="Direction">
                  {currentPort.dir}
                </LabeledList.Item>
                <LabeledList.Item label="Status">
                  {dockingPortOnEdge ? (
                    <span style={{ color: '#6c6' }}>On edge - OK</span>
                  ) : (
                    <span style={{ color: '#c66' }}>Blocked!</span>
                  )}
                </LabeledList.Item>
              </LabeledList>
              {!dockingPortOnEdge && (
                <NoticeBox danger mt={1}>
                  WARNING: You have built past your docking port! Docking may
                  fail. Use Port Relocation to move the docking port to an edge
                  airlock.
                </NoticeBox>
              )}
            </>
          ) : (
            <NoticeBox>No docking port detected</NoticeBox>
          )}
        </Section>
      </Stack.Item>

      <Stack.Item>
        <Section title="Ship Maintenance">
          <Stack vertical>
            <Stack.Item>
              <Button
                icon="fan"
                content="Reset Fans"
                tooltip="Removes all tiny fans and adds new ones to all external airlocks"
                disabled={!canOperate || isNotCrew}
                onClick={() => act('reset_fans')}
              />
            </Stack.Item>
          </Stack>
        </Section>
      </Stack.Item>

      {!canOperate && (
        <Stack.Item>
          <NoticeBox warning>
            Ship must be docked to perform construction operations.
          </NoticeBox>
        </Stack.Item>
      )}
    </Stack>
  );
};

interface ConstructionTabProps {
  canOperate: boolean;
  isNotCrew: boolean;
  rcdMatter: number;
  rcdMaxMatter: number;
  usingSilo: boolean;
  isInConstructionMode: boolean;
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
  } = props;

  return (
    <Stack vertical fill>
      <Stack.Item>
        <Section title="Construction Drone Control">
          <Stack vertical>
            <Stack.Item>
              <LabeledList>
                <LabeledList.Item label="RCD Matter">
                  {usingSilo ? (
                    `${rcdMatter} units (Silo)`
                  ) : (
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
                  )}
                </LabeledList.Item>
                <LabeledList.Item label="Status">
                  {isInConstructionMode ? (
                    <NoticeBox success mb={0}>
                      Construction mode active
                    </NoticeBox>
                  ) : (
                    'Idle'
                  )}
                </LabeledList.Item>
              </LabeledList>
            </Stack.Item>
            <Stack.Item mt={2}>
              <Button
                fluid
                icon="hammer"
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

      <Stack.Item>
        <Section title="Instructions">
          <Stack vertical>
            <Stack.Item>
              <b>Building:</b> Use the drone to construct within your ship or
              one tile adjacent to expand.
            </Stack.Item>
            <Stack.Item mt={1}>
              <b>Expanding:</b> Build on space or planetoid tiles adjacent to
              your ship to automatically add them to your shuttle.
            </Stack.Item>
            <Stack.Item mt={1}>
              <b>Deconstructing:</b> Remove structures to shrink your ship.
              Empty tiles will be automatically removed.
            </Stack.Item>
            <Stack.Item mt={1}>
              <b>Controls:</b>
              <ul>
                <li>Arrow keys to move the drone</li>
                <li>Build action to construct at drone location</li>
                <li>Configure RCD to change build mode</li>
              </ul>
            </Stack.Item>
          </Stack>
        </Section>
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
      <Stack.Item>
        <Section title="Current Docking Port">
          {currentPort ? (
            <LabeledList>
              <LabeledList.Item label="Position">
                ({currentPort.x}, {currentPort.y})
              </LabeledList.Item>
              <LabeledList.Item label="Direction">
                {currentPort.dir}
              </LabeledList.Item>
            </LabeledList>
          ) : (
            <NoticeBox>No docking port detected</NoticeBox>
          )}
        </Section>
      </Stack.Item>

      <Stack.Item grow>
        <Section title="Available Airlocks" fill scrollable>
          <Table>
            <Table.Row header>
              <Table.Cell>Airlock</Table.Cell>
              <Table.Cell>Area</Table.Cell>
              <Table.Cell>Position</Table.Cell>
              <Table.Cell>Action</Table.Cell>
            </Table.Row>
            {airlocks.map((airlock) => (
              <Table.Row
                key={airlock.ref}
                className={airlock.isCurrent ? 'Table__row--selected' : ''}
              >
                <Table.Cell>
                  {airlock.name}
                  {airlock.isCurrent && ' (Current)'}
                </Table.Cell>
                <Table.Cell>{airlock.areaName}</Table.Cell>
                <Table.Cell>
                  ({airlock.x}, {airlock.y})
                </Table.Cell>
                <Table.Cell>
                  <Button
                    icon="crosshairs"
                    content="Set as Dock"
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
                <Table.Cell colSpan={4}>
                  <NoticeBox>
                    No valid edge airlocks found on this ship.
                  </NoticeBox>
                </Table.Cell>
              </Table.Row>
            )}
          </Table>
        </Section>
      </Stack.Item>

      {!canOperate && (
        <Stack.Item>
          <NoticeBox warning>
            Ship must be docked to relocate docking port.
          </NoticeBox>
        </Stack.Item>
      )}
    </Stack>
  );
};
