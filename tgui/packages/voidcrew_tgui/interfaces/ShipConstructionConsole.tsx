import { useEffect, useState } from 'react';
import {
  Box,
  Button,
  ColorBox,
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
  bay?: {
    silo: string | null;
    requested: BooleanLike;
    available: BooleanLike;
    outpost_materials: BooleanLike;
  };
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
  selectedTool: ToolId;
  rtdInstalled: BooleanLike;
  rpdInstalled: BooleanLike;
  rldInstalled: BooleanLike;
  decalInstalled: BooleanLike;
  scannerInstalled: BooleanLike;
  lightType: LightType;
  lightDir: LightDir;
  lightColor: string;
  scannerMode: 'off' | 't-ray' | 'pipe' | 'thermal';
  isOutpost: BooleanLike;
  elevatorPlanning?: BooleanLike;
}

type ToolId = 'rcd' | 'camera' | 'tile' | 'pipe' | 'light' | 'decal';

type LightType = 'tube' | 'bulb' | 'floor' | 'glow';

type LightDir = 'auto' | 'north' | 'east' | 'south' | 'west';

type TabType = 'construction' | 'tools' | 'repair' | 'relocation' | 'settings';

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
    isOutpost,
  } = data;

  const [activeTab, setActiveTab] = useState<TabType>(
    isOutpost || isInConstructionMode ? 'tools' : 'construction',
  );

  useEffect(() => {
    if (isInConstructionMode) {
      setActiveTab('tools');
    }
  }, [isInConstructionMode]);

  return (
    <Window
      width={600}
      height={650}
      title="Ship Construction Console"
      theme={theme}
    >
      <Window.Content scrollable>
        <Stack vertical>
          {!!data.bay && (
            <Stack.Item>
              <Section title="Bay materials">
                <Box mb={1} style={{ overflowWrap: 'anywhere' }}>
                  {data.bay.silo || 'No silo connected'}
                </Box>
                <Button
                  selected={!!data.bay.silo && !data.bay.outpost_materials}
                  disabled={!canOperate || isNotCrew}
                  onClick={() => act('bay_ship_silo')}
                >
                  Use ship silo
                </Button>
                <Button
                  selected={!!data.bay.outpost_materials}
                  disabled={
                    !canOperate ||
                    isNotCrew ||
                    (!!data.bay.requested && !data.bay.available)
                  }
                  onClick={() =>
                    act(
                      data.bay?.available
                        ? 'bay_outpost_silo'
                        : 'bay_request_silo',
                    )
                  }
                >
                  {data.bay.available
                    ? 'Use outpost silo'
                    : data.bay.requested
                      ? 'Materials requested'
                      : 'Request outpost materials'}
                </Button>
              </Section>
            </Stack.Item>
          )}
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
              {!isOutpost && (
                <Tabs.Tab
                  selected={activeTab === 'construction'}
                  onClick={() => setActiveTab('construction')}
                >
                  Construction
                </Tabs.Tab>
              )}
              <Tabs.Tab
                selected={activeTab === 'tools'}
                onClick={() => setActiveTab('tools')}
                icon="toolbox"
              >
                Tools
              </Tabs.Tab>
              {!isOutpost && (
                <Tabs.Tab
                  selected={activeTab === 'repair'}
                  onClick={() => setActiveTab('repair')}
                >
                  Repair Drones
                </Tabs.Tab>
              )}
              {!isOutpost && (
                <Tabs.Tab
                  selected={activeTab === 'relocation'}
                  onClick={() => setActiveTab('relocation')}
                >
                  Port Relocation
                </Tabs.Tab>
              )}
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
          <Stack.Item>
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
            {activeTab === 'tools' && <ToolsTab />}
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
    <Stack vertical>
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

      <Stack.Item>
        <ShipConstructionControls />
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

const TOOL_LIST: { id: ToolId; label: string; icon: string }[] = [
  { id: 'rcd', label: 'RCD', icon: 'hammer' },
  { id: 'camera', label: 'Cameras', icon: 'video' },
  { id: 'tile', label: 'Floor tiles', icon: 'border-all' },
  { id: 'pipe', label: 'Pipes', icon: 'wrench' },
  { id: 'light', label: 'Lights', icon: 'lightbulb' },
  { id: 'decal', label: 'Decals', icon: 'spray-can' },
];

const SCANNER_MODES: { mode: Data['scannerMode']; label: string }[] = [
  { mode: 'off', label: 'Off' },
  { mode: 't-ray', label: 'T-ray' },
  { mode: 'pipe', label: 'Pipes' },
  { mode: 'thermal', label: 'Thermal' },
];

const LIGHT_TYPES: { type: LightType; label: string }[] = [
  { type: 'tube', label: 'Tube' },
  { type: 'bulb', label: 'Bulb' },
  { type: 'floor', label: 'Floor' },
  { type: 'glow', label: 'Glow stick' },
];

const LIGHT_WALLS: { dir: LightDir; label: string; icon: string }[] = [
  { dir: 'north', label: 'North', icon: 'arrow-up' },
  { dir: 'east', label: 'East', icon: 'arrow-right' },
  { dir: 'south', label: 'South', icon: 'arrow-down' },
  { dir: 'west', label: 'West', icon: 'arrow-left' },
];

const ToolsTab = () => {
  const { act, data } = useBackend<Data>();
  const {
    canOperate,
    isNotCrew,
    isInConstructionMode,
    selectedTool,
    rtdInstalled,
    rpdInstalled,
    rldInstalled,
    decalInstalled,
    scannerInstalled,
    lightType,
    lightDir,
    lightColor,
    scannerMode,
    isOutpost,
    elevatorPlanning,
  } = data;

  const installed: Record<ToolId, boolean> = {
    rcd: true,
    camera: true,
    tile: !!rtdInstalled,
    pipe: !!rpdInstalled,
    light: !!rldInstalled,
    decal: !!decalInstalled,
  };
  const idle = !isInConstructionMode;

  return (
    <Stack vertical>
      {!isInConstructionMode && (
        <Stack.Item>
          <Button
            fluid
            icon="hammer"
            disabled={!canOperate || isNotCrew}
            onClick={() => act('enter_construction_mode')}
          >
            Enter Construction Mode
          </Button>
        </Stack.Item>
      )}
      <Stack.Item>
        <Section title="Tools">
          <Stack vertical>
            {TOOL_LIST.filter((tool) => installed[tool.id]).map((tool) => (
              <Stack.Item key={tool.id}>
                <Stack>
                  <Stack.Item grow>
                    <Button
                      fluid
                      icon={tool.icon}
                      selected={selectedTool === tool.id}
                      disabled={idle}
                      onClick={() => act('select_tool', { tool: tool.id })}
                    >
                      {tool.label}
                    </Button>
                  </Stack.Item>
                  {tool.id !== 'light' && tool.id !== 'camera' && (
                    <Stack.Item>
                      <Button
                        icon="cog"
                        disabled={idle}
                        onClick={() => act('configure_tool', { tool: tool.id })}
                      />
                    </Stack.Item>
                  )}
                </Stack>
              </Stack.Item>
            ))}
          </Stack>
        </Section>
      </Stack.Item>
      {selectedTool === 'light' && !!rldInstalled && (
        <Stack.Item>
          <Section title="Lights">
            <LabeledList>
              <LabeledList.Item label="Type">
                {LIGHT_TYPES.map((entry) => (
                  <Button
                    key={entry.type}
                    selected={lightType === entry.type}
                    disabled={idle}
                    onClick={() => act('light_type', { type: entry.type })}
                  >
                    {entry.label}
                  </Button>
                ))}
              </LabeledList.Item>
              {(lightType === 'tube' || lightType === 'bulb') && (
                <LabeledList.Item label="Wall">
                  <Button
                    selected={lightDir === 'auto'}
                    disabled={idle}
                    onClick={() => act('light_dir', { dir: 'auto' })}
                  >
                    Auto
                  </Button>
                  {LIGHT_WALLS.map((entry) => (
                    <Button
                      key={entry.dir}
                      icon={entry.icon}
                      tooltip={entry.label}
                      selected={lightDir === entry.dir}
                      disabled={idle}
                      onClick={() => act('light_dir', { dir: entry.dir })}
                    />
                  ))}
                </LabeledList.Item>
              )}
              <LabeledList.Item label="Color">
                <Button disabled={idle} onClick={() => act('light_color')}>
                  <ColorBox color={lightColor} />
                </Button>
              </LabeledList.Item>
            </LabeledList>
          </Section>
        </Stack.Item>
      )}
      {!!scannerInstalled && (
        <Stack.Item>
          <Section title="Scanner">
            {SCANNER_MODES.map((entry) => (
              <Button
                key={entry.mode}
                selected={scannerMode === entry.mode}
                disabled={idle}
                onClick={() => act('scanner_mode', { mode: entry.mode })}
              >
                {entry.label}
              </Button>
            ))}
          </Section>
        </Stack.Item>
      )}
      {!!isOutpost && (
        <Stack.Item>
          <Section title="Hangar elevator">
            <Button
              selected={!!elevatorPlanning}
              disabled={idle}
              onClick={() => act('elevator_plan')}
            >
              Blueprint
            </Button>
            <Button
              disabled={idle || !elevatorPlanning}
              onClick={() => act('elevator_rotate')}
            >
              Rotate
            </Button>
            <Button.Confirm
              disabled={idle || !elevatorPlanning}
              onClick={() => act('elevator_confirm')}
            >
              Install
            </Button.Confirm>
          </Section>
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
    <Stack vertical>
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
      <Stack.Item>
        <Section title="Available Hull Doors">
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
