import { useState } from 'react';
import { useBackend } from '../../tgui/backend';
import {
  AnimatedNumber,
  Button,
  ByondUi,
  Input,
  LabeledList,
  ProgressBar,
  Section,
  Stack,
  Table,
} from 'tgui-core/components';
import { Window } from '../../tgui/layouts';

export const HelmComputer = (props, context) => {
  const { act, data, config } = useBackend(context);
  const [mapRefreshKey, setMapRefreshKey] = useState(0);
  const { mapRef, isViewer, shipCrashed, repairProgress } = data || {};

  // Show crash repair screen if ship is crashed
  if (shipCrashed) {
    return (
      <Window width={500} height={400}>
        <Window.Content>
          <CrashRepairScreen repairProgress={repairProgress} />
        </Window.Content>
      </Window>
    );
  }

  return (
    <Window width={900} height={900} resizable>
      <Window.Content>
        <Stack vertical>
          <Stack.Item textAlign={'center'}>
            <SharedContent />
          </Stack.Item>
          <Stack.Item>
            <Stack fill textAlign={'center'}>
              <Section
                title="Map"
                width={'70%'}
                fill
                buttons={
                  <Button
                    icon="sync"
                    tooltip="Refresh Map"
                    onClick={() => setMapRefreshKey((k) => k + 1)}
                  />
                }
              >
                <Stack.Item>
                  <ByondUi
                    key={`helm-map-${mapRefreshKey}`}
                    className="CameraConsole__map"
                    height="610px"
                    params={{
                      id: mapRef,
                      type: 'map',
                      zoom: 0,
                    }}
                  />
                </Stack.Item>
              </Section>
              <Section title="Controls" width={'30%'}>
                <Stack vertical>
                  <Stack.Item>
                    <ShipControlContent />
                  </Stack.Item>

                  <Stack.Item>
                    <BroadcastSection />
                  </Stack.Item>

                  <Stack.Item>
                    <Radar />
                  </Stack.Item>

                  <Stack.Item>
                    <ShipContent />
                  </Stack.Item>
                </Stack>
              </Section>
            </Stack>
          </Stack.Item>
        </Stack>
      </Window.Content>
    </Window>
  );
};

const Radar = (context) => {
  const { act, data } = useBackend(context);
  const { isViewer = [], otherInfo = [] } = data;
  return (
    <Section>
      <Table>
        <Table.Row bold>
          <Table.Cell>Name</Table.Cell>
          <Table.Cell>Integrity</Table.Cell>
          {!isViewer && <Table.Cell>Act</Table.Cell>}
        </Table.Row>
        {otherInfo.map((ship) => (
          <Table.Row key={ship.name}>
            <Table.Cell>{ship.name}</Table.Cell>
            <Table.Cell>
              {!!ship.integrity && (
                <ProgressBar
                  ranges={{
                    good: [51, 100],
                    average: [26, 50],
                    bad: [0, 25],
                  }}
                  maxValue={100}
                  value={ship.integrity}
                />
              )}
            </Table.Cell>
            {!isViewer && (
              <Table.Cell>
                <Button
                  tooltip="Interact"
                  tooltipPosition="left"
                  icon="circle"
                  disabled={
                    isViewer || data.speed > 0 || data.state !== 'flying'
                  }
                  onClick={() =>
                    act('act_overmap', {
                      ship_to_act: ship.ref,
                    })
                  }
                />
              </Table.Cell>
            )}
          </Table.Row>
        ))}
      </Table>
    </Section>
  );
};

const BroadcastSection = (props, context) => {
  const { act, data } = useBackend(context);
  const { isViewer } = data;
  const [broadcastMessage, setBroadcastMessage] = useState('');

  const handleBroadcast = () => {
    if (broadcastMessage && broadcastMessage.trim()) {
      act('broadcast', { message: broadcastMessage });
      setBroadcastMessage('');
    }
  };

  const handleInput = (value) => {
    setBroadcastMessage(value);
    act('typing_sound');
  };

  return (
    <Section title="Broadcast">
      <Stack vertical>
        <Stack.Item>
          <Input
            fluid
            placeholder="Enter message..."
            value={broadcastMessage}
            disabled={isViewer}
            onChange={handleInput}
            onEnter={handleBroadcast}
          />
        </Stack.Item>
        <Stack.Item>
          <Button
            fluid
            icon="broadcast-tower"
            content="Broadcast"
            disabled={isViewer || !broadcastMessage}
            onClick={handleBroadcast}
          />
        </Stack.Item>
      </Stack>
    </Section>
  );
};

const SharedContent = (props, context) => {
  const { act, data } = useBackend(context);
  const {
    isViewer,
    integrity,
    overhealth = 0,
    shipInfo = [],
    otherInfo = [],
  } = data;

  // Calculate the base integrity (capped at 100) and the maxValue for the bar
  const baseIntegrity = Math.min(integrity, 100);
  const totalIntegrity = integrity; // This can be > 100 with overhealth
  const maxBarValue = Math.max(100, totalIntegrity);

  return (
    <Section
      title={
        <Button.Input
          content={shipInfo.name}
          currentValue={shipInfo.name}
          disabled={isViewer}
          onCommit={(e, value) =>
            act('rename_ship', {
              newName: value,
            })
          }
        />
      }
      buttons={
        <Button
          tooltip="Refresh Ship Stats"
          tooltipPosition="left"
          icon="sync"
          disabled={isViewer}
          onClick={() => act('reload_ship')}
        />
      }
    >
      <LabeledList>
        <LabeledList.Item label="Class">{shipInfo.class}</LabeledList.Item>
        <LabeledList.Item label="Integrity">
          <IntegrityBar integrity={integrity} overhealth={overhealth} />
        </LabeledList.Item>
        <LabeledList.Item label="Sensor Range">
          <ProgressBar value={shipInfo.sensor_range} minValue={1} maxValue={8}>
            <AnimatedNumber value={shipInfo.sensor_range} />
          </ProgressBar>
        </LabeledList.Item>
        {shipInfo.mass && (
          <LabeledList.Item label="Mass">
            {shipInfo.mass + 'tonnes'}
          </LabeledList.Item>
        )}
      </LabeledList>
    </Section>
  );
};

// Custom integrity bar that shows overhealth as dark green
// Color thresholds: overhealth=dark green, 75-100%=green, 61-74%=yellow, 51-60%=red, 0-50%=dark red
const IntegrityBar = (props) => {
  const { integrity, overhealth = 0 } = props;

  // Base integrity is capped at 100%
  const baseIntegrity = Math.min(integrity - overhealth, 100);
  const totalIntegrity = integrity;

  // Determine bar color based on base integrity
  // 75-100: green, 61-74: yellow, 51-60: red, 0-50: deep dark red
  const getBarColor = (value) => {
    if (value <= 50) return '#4a0000'; // Deep dark red (disabled)
    if (value <= 60) return '#bd2020'; // Red
    if (value <= 74) return '#d9b804'; // Yellow
    return '#20b142'; // Green
  };

  // If we have overhealth, show a stacked bar
  if (overhealth > 0) {
    const maxValue = totalIntegrity;
    return (
      <div style={{ position: 'relative', width: '100%' }}>
        {/* Background bar for total width */}
        <ProgressBar
          value={totalIntegrity}
          maxValue={maxValue}
          color="transparent"
        >
          {/* Stacked bars inside */}
          <div
            style={{
              position: 'absolute',
              top: 0,
              left: 0,
              height: '100%',
              width: `${(baseIntegrity / maxValue) * 100}%`,
              backgroundColor: getBarColor(baseIntegrity),
              transition: 'width 0.5s ease',
            }}
          />
          <div
            style={{
              position: 'absolute',
              top: 0,
              left: `${(baseIntegrity / maxValue) * 100}%`,
              height: '100%',
              width: `${(overhealth / maxValue) * 100}%`,
              backgroundColor: '#0d5c1a', // Dark green for overhealth
              transition: 'width 0.5s ease',
            }}
          />
          <span style={{ position: 'relative', zIndex: 1 }}>
            {totalIntegrity}%
          </span>
        </ProgressBar>
      </div>
    );
  }

  // No overhealth, use custom colored bar
  return (
    <ProgressBar value={baseIntegrity} maxValue={100} color="transparent">
      <div
        style={{
          position: 'absolute',
          top: 0,
          left: 0,
          height: '100%',
          width: `${baseIntegrity}%`,
          backgroundColor: getBarColor(baseIntegrity),
          transition: 'width 0.5s ease, background-color 0.5s ease',
        }}
      />
      <span style={{ position: 'relative', zIndex: 1 }}>{baseIntegrity}%</span>
    </ProgressBar>
  );
};

// Content included on helms when they're controlling ships
const ShipContent = (props, context) => {
  const { act, data } = useBackend(context);
  const {
    isViewer,
    engineInfo,
    shipInfo,
    speed,
    heading,
    eta,
    x,
    y,
    dock_request,
    dock_req_name,
  } = data;
  return (
    <>
      {!!dock_request && (
        <Section title="Docking Request">
          <LabeledList>
            <LabeledList.Item label={dock_req_name}>
              <Button
                content="Accept"
                color="good"
                disabled={isViewer}
                onClick={() => act('dock_req_success')}
              />
              <Button
                content="Decline"
                color="bad"
                disabled={isViewer}
                onClick={() => act('dock_req_failure')}
              />
            </LabeledList.Item>
          </LabeledList>
        </Section>
      )}
      <Section title="Velocity">
        <LabeledList>
          <LabeledList.Item label="Speed">
            <ProgressBar
              ranges={{
                good: [0, 4],
                average: [5, 6],
                bad: [7, Infinity],
              }}
              maxValue={10}
              value={speed}
            >
              <AnimatedNumber
                value={speed}
                format={(value) => Math.round(value * 10) / 10}
              />
              spM
            </ProgressBar>
          </LabeledList.Item>
          <LabeledList.Item label="Heading">
            <AnimatedNumber value={heading} />
          </LabeledList.Item>
          <LabeledList.Item label="Position">
            X
            <AnimatedNumber value={x} />
            /Y
            <AnimatedNumber value={y} />
          </LabeledList.Item>
          <LabeledList.Item label="ETA">
            <AnimatedNumber value={eta} />
          </LabeledList.Item>
        </LabeledList>
      </Section>
      <Section
        title="Engines"
        buttons={
          <Button
            tooltip="Refresh Engine"
            tooltipPosition="left"
            icon="sync"
            disabled={isViewer}
            onClick={() => act('reload_engines')}
          />
        }
      >
        <Table>
          <Table.Row bold>
            <Table.Cell collapsing>Name</Table.Cell>
            <Table.Cell fluid>Fuel</Table.Cell>
          </Table.Row>
          {engineInfo &&
            engineInfo.map((engine) => (
              <Table.Row key={engine.name} className="candystripe">
                <Table.Cell collapsing>
                  <Button
                    content={
                      engine.name.len < 14
                        ? engine.name
                        : engine.name.slice(0, 10) + '...'
                    }
                    color={engine.enabled && 'good'}
                    icon={engine.enabled ? 'toggle-on' : 'toggle-off'}
                    disabled={isViewer}
                    tooltip="Toggle Engine"
                    tooltipPosition="right"
                    onClick={() =>
                      act('toggle_engine', {
                        engine: engine.ref,
                      })
                    }
                  />
                </Table.Cell>
                <Table.Cell fluid>
                  {!!engine.maxFuel && (
                    <ProgressBar
                      fluid
                      ranges={{
                        good: [50, Infinity],
                        average: [25, 50],
                        bad: [-Infinity, 25],
                      }}
                      maxValue={engine.maxFuel}
                      minValue={0}
                      value={engine.fuel}
                    >
                      <AnimatedNumber
                        value={(engine.fuel / engine.maxFuel) * 100}
                        format={(value) => Math.round(value)}
                      />
                      %
                    </ProgressBar>
                  )}
                </Table.Cell>
              </Table.Row>
            ))}
        </Table>
      </Section>
    </>
  );
};

// Arrow directional controls
const ShipControlContent = (props, context) => {
  const { act, data } = useBackend(context);
  const { calibrating, shipDisabled, canThrust } = data;
  const flyable = data.state === 'flying' && !shipDisabled;
  const canMove = flyable && canThrust;

  //  DIRECTIONS const idea from Lyra as part of their Haven-Urist project
  const DIRECTIONS = {
    north: 1,
    south: 2,
    east: 4,
    west: 8,
    northeast: 1 + 4,
    northwest: 1 + 8,
    southeast: 2 + 4,
    southwest: 2 + 8,
  };
  return (
    <Section title="Navigation">
      {shipDisabled && (
        <div className="NoticeBox danger">HULL CRITICAL - SYSTEMS OFFLINE</div>
      )}
      {data.state === 'idle' && !shipDisabled && (
        <div className="NoticeBox">Ship Docked.</div>
      )}
      {flyable && !canThrust && (
        <div className="NoticeBox danger">No engine power available!</div>
      )}
      <Table collapsing>
        <Table.Row height={2}>
          <Table.Cell width={1}>
            <Button
              tooltip="Undock"
              tooltipPosition="right"
              icon="sign-out-alt"
              disabled={data.state !== 'idle' || shipDisabled}
              onClick={() => act('undock')}
            />
          </Table.Cell>

          <Table.Cell width={1}>
            <Button
              tooltip="Dock in Empty Space"
              tooltipPosition="right"
              icon="sign-in-alt"
              disabled={!flyable}
              onClick={() => act('dock_empty')}
            />
          </Table.Cell>

          <Table.Cell width={1}>
            <Button
              tooltip={calibrating ? 'Cancel Jump' : 'Bluespace Jump'}
              tooltipPosition="right"
              icon={calibrating ? 'times' : 'angle-double-right'}
              color={calibrating ? 'bad' : undefined}
              disabled={!flyable}
              onClick={() => act('bluespace_jump')}
            />
          </Table.Cell>
        </Table.Row>
        <Table.Row height={1}>
          <Table.Cell width={1}>
            <Button
              icon="arrow-left"
              iconRotation={45}
              mb={1}
              disabled={!canMove}
              onClick={() =>
                act('change_heading', {
                  dir: DIRECTIONS.northwest,
                })
              }
            />
          </Table.Cell>
          <Table.Cell width={1}>
            <Button
              icon="arrow-up"
              mb={1}
              disabled={!canMove}
              onClick={() =>
                act('change_heading', {
                  dir: DIRECTIONS.north,
                })
              }
            />
          </Table.Cell>
          <Table.Cell width={1}>
            <Button
              icon="arrow-right"
              iconRotation={-45}
              mb={1}
              disabled={!canMove}
              onClick={() =>
                act('change_heading', {
                  dir: DIRECTIONS.northeast,
                })
              }
            />
          </Table.Cell>
        </Table.Row>
        <Table.Row height={1}>
          <Table.Cell width={1}>
            <Button
              icon="arrow-left"
              mb={1}
              disabled={!canMove}
              onClick={() =>
                act('change_heading', {
                  dir: DIRECTIONS.west,
                })
              }
            />
          </Table.Cell>
          <Table.Cell width={1}>
            <Button
              tooltip="Stop"
              icon="circle"
              mb={1}
              disabled={!data.speed || !flyable}
              onClick={() => act('stop')}
            />
          </Table.Cell>
          <Table.Cell width={1}>
            <Button
              icon="arrow-right"
              mb={1}
              disabled={!canMove}
              onClick={() =>
                act('change_heading', {
                  dir: DIRECTIONS.east,
                })
              }
            />
          </Table.Cell>
        </Table.Row>
        <Table.Row height={1}>
          <Table.Cell width={1}>
            <Button
              icon="arrow-left"
              iconRotation={-45}
              mb={1}
              disabled={!canMove}
              onClick={() =>
                act('change_heading', {
                  dir: DIRECTIONS.southwest,
                })
              }
            />
          </Table.Cell>
          <Table.Cell width={1}>
            <Button
              icon="arrow-down"
              mb={1}
              disabled={!canMove}
              onClick={() =>
                act('change_heading', {
                  dir: DIRECTIONS.south,
                })
              }
            />
          </Table.Cell>
          <Table.Cell width={1}>
            <Button
              icon="arrow-right"
              iconRotation={45}
              mb={1}
              disabled={!canMove}
              onClick={() =>
                act('change_heading', {
                  dir: DIRECTIONS.southeast,
                })
              }
            />
          </Table.Cell>
        </Table.Row>
      </Table>
    </Section>
  );
};

// Crash repair screen - shown when ship is crashed and needs repair
const CrashRepairScreen = (props) => {
  const { repairProgress } = props;

  return (
    <Section
      title="SYSTEM FAILURE"
      style={{
        textAlign: 'center',
        height: '100%',
      }}
    >
      <Stack vertical fill>
        <Stack.Item>
          <div
            style={{
              fontSize: '24px',
              color: '#ff4444',
              marginBottom: '20px',
              fontWeight: 'bold',
            }}
          >
            HULL INTEGRITY CRITICAL
          </div>
        </Stack.Item>
        <Stack.Item>
          <div
            style={{
              fontSize: '16px',
              color: '#aaaaaa',
              marginBottom: '30px',
            }}
          >
            Ship systems offline. Repair hull to restore functionality.
          </div>
        </Stack.Item>
        <Stack.Item>
          <div
            style={{
              fontSize: '14px',
              color: '#888888',
              marginBottom: '10px',
            }}
          >
            REPAIR PROGRESS
          </div>
        </Stack.Item>
        <Stack.Item>
          <ProgressBar
            value={repairProgress}
            maxValue={100}
            ranges={{
              bad: [0, 33],
              average: [34, 66],
              good: [67, 100],
            }}
          >
            <span style={{ fontSize: '20px', fontWeight: 'bold' }}>
              {repairProgress}%
            </span>
          </ProgressBar>
        </Stack.Item>
        <Stack.Item>
          <div
            style={{
              fontSize: '12px',
              color: '#666666',
              marginTop: '20px',
            }}
          >
            Rebuild hull structure to 65% integrity to restore systems
          </div>
        </Stack.Item>
      </Stack>
    </Section>
  );
};
