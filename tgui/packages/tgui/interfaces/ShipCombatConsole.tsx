import { useState } from 'react';
import { useBackend } from '../backend';
import {
  AnimatedNumber,
  Button,
  ByondUi,
  LabeledList,
  ProgressBar,
  Section,
  Stack,
  Table,
} from 'tgui-core/components';
import { Window } from '../layouts';

type Launcher = {
  id: string;
  name: string;
  loaded: boolean;
  missile_name: string | null;
  missile_damage: number | null;
  ready: boolean;
  cooldown: boolean;
  cooldown_time: number;
};

type Target = {
  name: string;
  integrity: number;
  ref: string;
};

type Data = {
  shipName: string;
  shipIntegrity: number;
  hasTarget: boolean;
  targetName: string | null;
  targetIntegrity: number | null;
  hasTargetTurf: boolean;
  targetMapRef: string;
  availableTargets: Target[];
  launchers: Launcher[];
  cloakActive: boolean;
  mapRef: string;
};

export const ShipCombatConsole = () => {
  const { act, data } = useBackend<Data>();
  const [mapRefreshKey, setMapRefreshKey] = useState(0);

  const {
    shipName,
    shipIntegrity,
    hasTarget,
    targetName,
    targetIntegrity,
    hasTargetTurf,
    targetMapRef,
    availableTargets = [],
    launchers = [],
    cloakActive,
  } = data;

  return (
    <Window width={1000} height={700} resizable>
      <Window.Content>
        <Stack fill>
          {/* Left Panel - Target Camera and Targeting */}
          <Stack.Item grow={2}>
            <Stack vertical fill>
              {/* Target Camera View */}
              <Stack.Item grow>
                <Section
                  title="Target View"
                  fill
                  buttons={
                    <>
                      <Button
                        icon="sync"
                        tooltip="Refresh Camera"
                        onClick={() => {
                          act('refresh_camera');
                          setMapRefreshKey((k) => k + 1);
                        }}
                      />
                      {hasTarget && (
                        <Button
                          icon="times"
                          color="bad"
                          tooltip="Clear Target"
                          onClick={() => act('clear_target')}
                        />
                      )}
                    </>
                  }
                >
                  {hasTarget ? (
                    <ByondUi
                      key={`combat-map-${mapRefreshKey}`}
                      className="CameraConsole__map"
                      height="400px"
                      params={{
                        id: targetMapRef,
                        type: 'map',
                        zoom: 0,
                      }}
                    />
                  ) : (
                    <Stack fill vertical justify="center" align="center">
                      <Stack.Item fontSize="1.5em" color="label">
                        No Target Selected
                      </Stack.Item>
                      <Stack.Item color="gray">
                        Select a target from the radar to view
                      </Stack.Item>
                    </Stack>
                  )}
                </Section>
              </Stack.Item>

              {/* Target Info */}
              {hasTarget && (
                <Stack.Item>
                  <Section title={`Target: ${targetName}`}>
                    <LabeledList>
                      <LabeledList.Item label="Integrity">
                        <ProgressBar
                          value={targetIntegrity! / 100}
                          ranges={{
                            good: [0.6, Infinity],
                            average: [0.3, 0.6],
                            bad: [-Infinity, 0.3],
                          }}
                        >
                          <AnimatedNumber value={targetIntegrity} />%
                        </ProgressBar>
                      </LabeledList.Item>
                      <LabeledList.Item label="Impact Point">
                        {hasTargetTurf ? (
                          <span style={{ color: '#4caf50' }}>Selected</span>
                        ) : (
                          <span style={{ color: '#f44336' }}>
                            Click on camera to select
                          </span>
                        )}
                      </LabeledList.Item>
                    </LabeledList>
                  </Section>
                </Stack.Item>
              )}
            </Stack>
          </Stack.Item>

          {/* Right Panel - Ship Status, Radar, Launchers */}
          <Stack.Item grow={1}>
            <Stack vertical fill>
              {/* Ship Status */}
              <Stack.Item>
                <Section title={`Ship: ${shipName}`}>
                  <LabeledList>
                    <LabeledList.Item label="Hull Integrity">
                      <ProgressBar
                        value={shipIntegrity / 100}
                        ranges={{
                          good: [0.6, Infinity],
                          average: [0.3, 0.6],
                          bad: [-Infinity, 0.3],
                        }}
                      >
                        <AnimatedNumber value={shipIntegrity} />%
                      </ProgressBar>
                    </LabeledList.Item>
                    <LabeledList.Item label="Cloak Status">
                      {cloakActive ? (
                        <span style={{ color: '#4caf50' }}>ACTIVE</span>
                      ) : (
                        <span style={{ color: '#9e9e9e' }}>Inactive</span>
                      )}
                    </LabeledList.Item>
                  </LabeledList>
                </Section>
              </Stack.Item>

              {/* Radar - Available Targets */}
              <Stack.Item>
                <Section title="Radar">
                  {availableTargets.length > 0 ? (
                    <Table>
                      <Table.Row header>
                        <Table.Cell>Ship</Table.Cell>
                        <Table.Cell>Integrity</Table.Cell>
                        <Table.Cell>Action</Table.Cell>
                      </Table.Row>
                      {availableTargets.map((target) => (
                        <Table.Row key={target.ref}>
                          <Table.Cell>{target.name}</Table.Cell>
                          <Table.Cell>
                            <ProgressBar
                              value={target.integrity / 100}
                              ranges={{
                                good: [0.6, Infinity],
                                average: [0.3, 0.6],
                                bad: [-Infinity, 0.3],
                              }}
                            >
                              {target.integrity}%
                            </ProgressBar>
                          </Table.Cell>
                          <Table.Cell>
                            <Button
                              icon="crosshairs"
                              tooltip="Target"
                              onClick={() =>
                                act('select_target', { ref: target.ref })
                              }
                            />
                          </Table.Cell>
                        </Table.Row>
                      ))}
                    </Table>
                  ) : (
                    <span style={{ color: 'gray' }}>No ships in range</span>
                  )}
                </Section>
              </Stack.Item>

              {/* Missile Launchers */}
              <Stack.Item grow>
                <Section title="Missile Launchers" fill scrollable>
                  {launchers.length > 0 ? (
                    <Stack vertical>
                      {launchers.map((launcher) => (
                        <Stack.Item key={launcher.id}>
                          <Section
                            title={launcher.name}
                            buttons={
                              <Button
                                icon="rocket"
                                content="Fire"
                                disabled={
                                  !launcher.ready ||
                                  !hasTarget ||
                                  !hasTargetTurf
                                }
                                color={
                                  launcher.ready && hasTarget && hasTargetTurf
                                    ? 'red'
                                    : undefined
                                }
                                onClick={() =>
                                  act('fire_launcher', { id: launcher.id })
                                }
                              />
                            }
                          >
                            <LabeledList>
                              <LabeledList.Item label="Status">
                                {launcher.loaded ? (
                                  <span style={{ color: '#4caf50' }}>
                                    Loaded: {launcher.missile_name}
                                  </span>
                                ) : (
                                  <span style={{ color: '#f44336' }}>Empty</span>
                                )}
                              </LabeledList.Item>
                              {launcher.loaded && (
                                <LabeledList.Item label="Damage">
                                  {launcher.missile_damage}
                                </LabeledList.Item>
                              )}
                              {launcher.cooldown && (
                                <LabeledList.Item label="Cooldown">
                                  <span style={{ color: '#ff9800' }}>
                                    Reloading...
                                  </span>
                                </LabeledList.Item>
                              )}
                            </LabeledList>
                          </Section>
                        </Stack.Item>
                      ))}
                    </Stack>
                  ) : (
                    <span style={{ color: 'gray' }}>
                      No launchers linked. Use a multitool to link launchers.
                    </span>
                  )}
                </Section>
              </Stack.Item>

              {/* Fire All Button */}
              <Stack.Item>
                <Button
                  fluid
                  icon="bomb"
                  content="Fire All Launchers"
                  disabled={!hasTarget || !hasTargetTurf}
                  color={hasTarget && hasTargetTurf ? 'red' : undefined}
                  onClick={() => act('fire_all')}
                />
              </Stack.Item>
            </Stack>
          </Stack.Item>
        </Stack>
      </Window.Content>
    </Window>
  );
};
