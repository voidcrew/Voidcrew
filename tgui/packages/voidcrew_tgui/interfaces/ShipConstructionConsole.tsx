import { useState } from 'react';
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
import type { BooleanLike } from 'tgui-core/react';
import { useBackend } from '../../tgui/backend';
import { Window } from '../../tgui/layouts';
import { ShipConstructionControls } from './ShipConstructionControls';

interface PortDoorData {
  name: string;
  ref: string;
  x: number;
  y: number;
  isCurrent: BooleanLike;
  clearsOverhang: BooleanLike;
  areaName: string;
}

interface PortData {
  x: number;
  y: number;
  dir: string;
  port_direction: string;
}

interface Data {
  repairUnlocked: BooleanLike;
  repairEnabled: BooleanLike;
  repairStatus: string;
  repairTracking: BooleanLike;
  repairRecords: number;
  repairRecordLimit: number;
  repairOverflow: number;
  repairDroneLimit: number;
  repairDrones: {
    ref: string;
    name: string;
    status: string;
    enabled: BooleanLike;
    repaired: number;
  }[];
  canOperate: boolean;
  shipState: string;
  shipName: string;
  isNotCrew: boolean;
  lastMessage: string;
  lastSuccess: boolean;
  currentPort: PortData | null;
  dockingPortOnEdge: BooleanLike;
  portOverhang: number;
  portDoors: PortDoorData[];
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

type TabType = 'construction' | 'repair' | 'relocation' | 'settings';

export const ShipConstructionConsole = () => {
  const { act, data } = useBackend<Data>();
  const {
    canOperate,
    isNotCrew,
    lastMessage,
    lastSuccess,
    currentPort,
    portDoors,
    portOverhang,
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
    <Window
      width={600}
      height={650}
      title="Ship Construction Console"
      theme={theme}
    >
      <Window.Content scrollable>
        <Stack vertical fill>
          {/* Operation Status Message */}
          {!!lastMessage && (
            <Stack.Item>
              <NoticeBox
                {...(lastSuccess ? { success: true } : { danger: true })}
              >
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
                selected={activeTab === 'repair'}
                onClick={() => setActiveTab('repair')}
              >
                Repair Drones
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
                portDoors={portDoors}
                portOverhang={portOverhang}
              />
            )}
            {activeTab === 'settings' && <SettingsTab />}
            {activeTab === 'repair' && <RepairTab />}
          </Stack.Item>
        </Stack>
      </Window.Content>
    </Window>
  );
};

interface ConstructionTabProps {
  canOperate: boolean;
  isNotCrew: boolean;
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
                    {integrity}%{overhealth > 0 && ` (+${overhealth}%)`}
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
        <ShipConstructionControls />
      </Stack.Item>
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
          <NoticeBox>
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
  portDoors: PortDoorData[];
  portOverhang: number;
}

const RelocationTab = (props: RelocationTabProps) => {
  const { act } = useBackend();
  const { canOperate, isNotCrew, currentPort, portDoors, portOverhang } = props;

  const overhanging = portOverhang > 0;
  const canFixOverhang = portDoors.some((door) => !!door.clearsOverhang);

  return (
    <Stack vertical fill>
      {/* Hull built out past the port lands inside whatever the ship berths against */}
      {portOverhang > 0 && (
        <Stack.Item>
          <NoticeBox danger>
            {portOverhang} {portOverhang === 1 ? 'metre' : 'metres'} of hull
            stands out past the docking port, and that section would be driven
            through whatever the ship berths against.
            {canFixOverhang
              ? ' The port will be moved out to the outermost hull door automatically on the next undock; relocate it here if you would rather choose the door yourself.'
              : ' No door on the outermost plating yet, fit an airlock or firelock there. The ship cannot undock until one exists.'}
          </NoticeBox>
        </Stack.Item>
      )}

      {/* Current Port Info - Compact */}
      <Stack.Item>
        <Section
          title="Current Docking Port"
          buttons={
            <Button
              icon="fan"
              content="Reset Fans"
              tooltip="Keeps fans on hull doors and blast doors, removes misplaced fans, and adds missing fans for 2 iron sheets each from the linked silo"
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

      {/* Hull doors the port can be moved to */}
      <Stack.Item grow>
        <Section title="Available Hull Doors" fill scrollable>
          <Table>
            <Table.Row header>
              <Table.Cell>Door</Table.Cell>
              <Table.Cell>Area</Table.Cell>
              <Table.Cell>Action</Table.Cell>
            </Table.Row>
            {portDoors.map((door) => (
              <Table.Row
                key={door.ref}
                className={door.isCurrent ? 'Table__row--selected' : ''}
              >
                <Table.Cell>
                  {door.name}
                  {!!door.isCurrent && (
                    <Box as="span" color="good" ml={1}>
                      (Current)
                    </Box>
                  )}
                  {overhanging && !door.isCurrent && !!door.clearsOverhang && (
                    <Box as="span" color="good" ml={1}>
                      (clears the overhang)
                    </Box>
                  )}
                </Table.Cell>
                <Table.Cell color="label">{door.areaName}</Table.Cell>
                <Table.Cell collapsing>
                  <Button
                    icon="crosshairs"
                    content="Set"
                    disabled={!canOperate || isNotCrew || !!door.isCurrent}
                    onClick={() =>
                      act('relocate_port', {
                        door_ref: door.ref,
                      })
                    }
                  />
                </Table.Cell>
              </Table.Row>
            ))}
            {portDoors.length === 0 && (
              <Table.Row>
                <Table.Cell colSpan={3}>
                  <NoticeBox>
                    No airlocks or firelocks on the outer hull.
                  </NoticeBox>
                </Table.Cell>
              </Table.Row>
            )}
          </Table>
        </Section>
      </Stack.Item>

      {!canOperate && (
        <Stack.Item>
          <NoticeBox>Ship must be docked.</NoticeBox>
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

const RepairTab = () => {
  const { act, data } = useBackend<Data>();
  const {
    repairUnlocked,
    repairEnabled,
    repairStatus,
    repairTracking,
    repairRecords,
    repairRecordLimit,
    repairOverflow,
    repairDroneLimit,
    repairDrones = [],
    isNotCrew,
  } = data;
  if (!repairUnlocked) {
    return (
      <NoticeBox>
        Install a repair swarm upgrade disk to control repair drones.
      </NoticeBox>
    );
  }
  return (
    <Stack vertical>
      <Stack.Item>
        <Section title="Damage monitoring">
          <Box mb={1}>
            {repairRecords} / {repairRecordLimit} locations awaiting repair
          </Box>
          {repairOverflow > 0 && (
            <NoticeBox danger>
              Repair backlog full. Additional damage requires manual repair.
            </NoticeBox>
          )}
          <Button
            icon={repairTracking ? 'stop' : 'record-vinyl'}
            disabled={isNotCrew}
            selected={!!repairTracking}
            onClick={() => act('repair_tracking')}
          >
            {repairTracking ? 'Disable monitoring' : 'Enable monitoring'}
          </Button>
          <Button.Confirm
            disabled={isNotCrew || repairRecords === 0}
            color="bad"
            onClick={() => act('repair_clear')}
          >
            Clear repair backlog
          </Button.Confirm>
          <Box mt={1} color="label">
            {repairStatus}
          </Box>
        </Section>
      </Stack.Item>
      <Stack.Item>
        <Section
          title={`Repair swarm (${repairDrones.length}/${repairDroneLimit})`}
        >
          <Button
            icon={repairEnabled ? 'pause' : 'play'}
            disabled={isNotCrew}
            onClick={() => act('repair_toggle')}
          >
            {repairEnabled ? 'Pause swarm' : 'Deploy swarm'}
          </Button>
          <Button
            icon="house"
            disabled={isNotCrew || repairDrones.length === 0}
            onClick={() => act('repair_recall_all')}
          >
            Recall all
          </Button>
          <Box mt={1} color="label">
            Link drones with a multitool. Repairs use the linked silo.
          </Box>
          {repairDrones.map((drone) => (
            <Section key={drone.ref} title={drone.name} mt={1}>
              <Box mb={1}>
                {drone.status} | {drone.repaired} repairs completed
              </Box>
              <Button
                disabled={isNotCrew}
                onClick={() => act('repair_drone_toggle', { ref: drone.ref })}
              >
                {drone.enabled ? 'Pause' : 'Enable'}
              </Button>
              <Button
                disabled={isNotCrew}
                onClick={() => act('repair_drone_recall', { ref: drone.ref })}
              >
                Recall
              </Button>
            </Section>
          ))}
        </Section>
      </Stack.Item>
    </Stack>
  );
};
