import { useState } from 'react';

import { useBackend } from '../../tgui/backend';
import {
  Box,
  Button,
  Collapsible,
  Dropdown,
  LabeledList,
  NoticeBox,
  Section,
  Stack,
  Tabs,
} from 'tgui-core/components';
import { Window } from '../../tgui/layouts';

interface BaseSurveyData {
  ref_id: string;
  object_name: string;
}

interface Nebula extends BaseSurveyData {
  gas_type: string;
}

interface Asteroid extends BaseSurveyData {
  minerals: string[];
}

interface ElectricStorm extends BaseSurveyData {
  intensity: number;
}

interface EmpStorm extends BaseSurveyData {
  intensity: number;
}

interface Planet extends BaseSurveyData {
  visited: number;
  weather_type: string;
  living_player_count: number;
}

interface Star extends BaseSurveyData {
  star_type: string;
}

interface SurveyData {
  nebulas: Nebula[];
  asteroids: Asteroid[];
  electric_storms: ElectricStorm[];
  emp_storms: EmpStorm[];
  planets: Planet[];
  stars: Star[];
}

interface SurveyTarget {
  ref: string;
  name: string;
  status: 'unsurveyed' | 'complete' | 'in-progress' | 'no-orbit';
  atRange: number;
  dist: number;
  points: number;
  cash: number;
  mappable: number;
}

interface Data {
  bankedCash: number;
  bankedPoints: number;
  currentCelestialRef: string;
  currentCelestialType: string;
  surveyData: SurveyData;
  mappingEnabled?: number;
  shipMoving: number;
  surveyAtRange?: number;
  surveyStatus?: 'unsurveyed' | 'complete' | 'in-progress' | 'no-orbit';
  surveyTargets?: SurveyTarget[];
  surveyValue: { cash: number; points: number };
  surveyDataDisk: number;
  theme?: string;
}

interface ColorScheme {
  buttonText?: string;
  button?: string;
  collapsible?: string;
  collapsibleText?: string;
  notice?: string;
  noticeText?: string;
  // tab?: string
  // tabText?: string
}

interface Theme {
  default: ColorScheme;
  syndicate: ColorScheme;
  cardgame: ColorScheme;
  outrun: ColorScheme;
  dark: ColorScheme;
  terminal: ColorScheme;
}

const getThemeColors = (theme: string): ColorScheme | undefined => {
  let colorScheme: ColorScheme | undefined;
  switch (theme) {
    case 'syndicate': {
      colorScheme = {
        collapsible: 'Darkred',
        notice: 'Firebrick',
        button: 'red',
      };
      break;
    }
    case 'cardtable': {
      colorScheme = {
        notice: '#381608',
        noticeText: 'white',
      };
      break;
    }
    case 'ntos_synth': {
      colorScheme = {
        notice: 'Blueviolet',
        noticeText: '#5edba5',
      };
      break;
    }
    case 'ntos_terminal': {
      colorScheme = {
        notice: '#0a4d13',
        noticeText: '#6ae27a',
        button: '#0a4d13',
      };
      break;
    }
    case 'ntOS95': {
      colorScheme = {
        notice: 'grey',
        noticeText: 'white',
      };
      break;
    }
    default: {
      break;
    }
  }
  return colorScheme;
};

export const SurveyComputer = (props, context) => {
  const { act, data } = useBackend<Data>();
  const { theme, currentCelestialRef, currentCelestialType } = data;
  const [tab, setTab] = useState(1);

  const currentThemeColors = theme ? getThemeColors(theme) : undefined;

  return (
    <Window
      width={540}
      height={587}
      theme={theme}
      title="Orbital Survey Computer"
    >
      <Window.Content scrollable fitted fillPositionedParent>
        <Stack fill scrollable fillPositionedParent>
          <Stack.Item>
            <Section fill>
              <Collapsible
                backgroundColor={currentThemeColors?.collapsible}
                textColor={currentThemeColors?.collapsibleText}
              >
                <Stack vertical>
                  <Section
                    title="Software"
                    textAlign="center"
                    mt={1}
                    mb={0}
                    pb={0}
                  />
                  <Stack.Item mt={0} pt={0}>
                    {' '}
                    <Tabs vertical verticalAlign="middle">
                      <Tabs.Tab
                        icon="rocket"
                        mt={1}
                        mb={1}
                        selected={tab === 1}
                        key={1}
                        onClick={() => {
                          setTab(1);
                        }}
                      >
                        Surveying
                      </Tabs.Tab>
                      <Tabs.Tab
                        icon="dollar-sign"
                        mt={1}
                        mb={1}
                        selected={tab === 8}
                        key={8}
                        onClick={() => {
                          setTab(8);
                        }}
                      >
                        Banking
                      </Tabs.Tab>
                      <Tabs.Tab
                        icon="flask"
                        mt={1}
                        mb={1}
                        selected={tab === 9}
                        key={9}
                        onClick={() => {
                          setTab(9);
                        }}
                      >
                        Research
                      </Tabs.Tab>
                      <Tabs.Tab
                        icon="wrench"
                        mt={1}
                        mb={1}
                        selected={tab === 10}
                        key={10}
                        onClick={() => {
                          setTab(10);
                        }}
                      >
                        Settings
                      </Tabs.Tab>
                    </Tabs>
                  </Stack.Item>
                  <Section
                    title="Celestials"
                    textAlign="center"
                    mb={0}
                    pb={0}
                  />
                  <Stack.Item pt={0} mt={0}>
                    <Tabs vertical verticalAlign="middle">
                      <Tabs.Tab
                        icon="globe"
                        mt={1}
                        mb={1}
                        textColor={
                          currentCelestialType &&
                          currentCelestialType === 'planets'
                            ? 'green'
                            : undefined
                        }
                        selected={tab === 2}
                        key={2}
                        onClick={() => {
                          setTab(2);
                        }}
                      >
                        Planets
                      </Tabs.Tab>
                      <Tabs.Tab
                        icon="atom"
                        mt={1}
                        mb={1}
                        textColor={
                          currentCelestialType &&
                          currentCelestialType === 'nebulas'
                            ? 'green'
                            : undefined
                        }
                        selected={tab === 3}
                        key={3}
                        onClick={() => {
                          setTab(3);
                        }}
                      >
                        Nebulas
                      </Tabs.Tab>
                      <Tabs.Tab
                        icon="bolt"
                        mt={1}
                        mb={1}
                        textColor={
                          currentCelestialType &&
                          currentCelestialType === 'electric_storms'
                            ? 'green'
                            : undefined
                        }
                        selected={tab === 4}
                        key={4}
                        onClick={() => {
                          setTab(4);
                        }}
                      >
                        Electric Storms
                      </Tabs.Tab>
                      <Tabs.Tab
                        icon="power-off"
                        mt={1}
                        mb={1}
                        textColor={
                          currentCelestialType &&
                          currentCelestialType === 'emp_storms'
                            ? 'green'
                            : undefined
                        }
                        selected={tab === 5}
                        key={5}
                        onClick={() => {
                          setTab(5);
                        }}
                      >
                        EMP Storms
                      </Tabs.Tab>
                      <Tabs.Tab
                        icon="meteor"
                        mt={1}
                        mb={1}
                        textColor={
                          currentCelestialType &&
                          currentCelestialType === 'asteroids'
                            ? 'green'
                            : undefined
                        }
                        selected={tab === 6}
                        key={6}
                        onClick={() => {
                          setTab(6);
                        }}
                      >
                        Asteroids
                      </Tabs.Tab>
                      <Tabs.Tab
                        icon="sun"
                        mt={1}
                        mb={1}
                        textColor={
                          currentCelestialType &&
                          currentCelestialType === 'stars'
                            ? 'green'
                            : undefined
                        }
                        selected={tab === 7}
                        key={7}
                        onClick={() => {
                          setTab(7);
                        }}
                      >
                        Stars
                      </Tabs.Tab>
                    </Tabs>
                  </Stack.Item>
                </Stack>
              </Collapsible>
            </Section>
          </Stack.Item>
          <Stack.Item width="100%">
            <Section height="100%" fill width="100%">
              {tab === 1 ? (
                <Surveying />
              ) : tab === 2 ? (
                <Planets />
              ) : tab === 3 ? (
                <Nebulas />
              ) : tab === 4 ? (
                <ElectricStorms />
              ) : tab === 5 ? (
                <ElectroMagneticStorms />
              ) : tab === 6 ? (
                <Asteroids />
              ) : tab === 7 ? (
                <Stars />
              ) : tab === 8 ? (
                <Banking />
              ) : tab === 9 ? (
                <Research />
              ) : (
                <Settings />
              )}
            </Section>
          </Stack.Item>
        </Stack>
      </Window.Content>
    </Window>
  );
};

const Surveying = (props, context) => {
  const { act, data } = useBackend<Data>();
  const {
    bankedCash,
    theme,
    bankedPoints,
    shipMoving,
    surveyTargets = [],
  } = data;

  interface Option {
    content: string;
    action?: string;
    disabled?: boolean;
    tooltip?: string;
  }

  const [selectedRef, setSelectedRef] = useState<string | null>(null);
  const selectedTarget =
    surveyTargets.find((target) => target.ref === selectedRef) ??
    surveyTargets[0];

  const currentOption: Option = !selectedTarget
    ? {
        content: 'Start survey',
        disabled: true,
        tooltip: 'no celestials in orbit or within scan range',
      }
    : selectedTarget.status === 'in-progress'
      ? {
          content: 'In progress',
          disabled: true,
        }
      : selectedTarget.status === 'complete'
        ? {
            content: 'Open map',
            action: 'map',
            disabled: selectedTarget.mappable ? false : true,
            tooltip: selectedTarget.mappable
              ? undefined
              : 'Mapping is not yet unlocked',
          }
        : {
            content: 'Start survey',
            action: 'survey',
            tooltip:
              selectedTarget.points && selectedTarget.cash
                ? `Value: ${selectedTarget.points} points | ${selectedTarget.cash} credits`
                : undefined,
          };

  const notices: string[] = [];

  if (shipMoving === 0) {
    notices.push('Ship is currently moving, surveying disabled');
  }

  if (
    selectedTarget &&
    selectedTarget.atRange === 1 &&
    selectedTarget.status === 'unsurveyed'
  ) {
    notices.push('Storm targeted at range: reduced survey yield');
  }

  if (bankedPoints && bankedPoints !== 0) {
    notices.push(`You have ${bankedPoints} research points to print`);
  }

  if (bankedCash && bankedCash !== 0) {
    notices.push(`You have ${bankedCash} credits to cash out`);
  }

  let currentThemeColors = theme ? getThemeColors(theme) : undefined;
  return (
    <Stack vertical fill textAlign="center">
      <Stack.Item pb={0} mb={0}>
        <Stack>
          <Stack.Item grow>
            <Collapsible
              open
              title="Notices"
              backgroundColor={currentThemeColors?.collapsible}
              textColor={currentThemeColors?.collapsibleText}
              lineHeight={2}
              icon={notices.length > 0 ? 'triangle-exclamation' : 'check'}
            >
              {notices.length > 0
                ? notices.map((notice, index) => {
                    return (
                      <NoticeBox
                        backgroundColor={currentThemeColors?.notice}
                        textColor={currentThemeColors?.noticeText}
                        key={index}
                      >
                        {notice}
                      </NoticeBox>
                    );
                  })
                : undefined}
            </Collapsible>
          </Stack.Item>
        </Stack>
      </Stack.Item>
      <Stack.Item grow>
        <Section title="Targets" fill scrollable>
          {surveyTargets.length > 0 ? (
            <Tabs vertical>
              {surveyTargets.map((target) => {
                return (
                  <Tabs.Tab
                    key={target.ref}
                    selected={
                      selectedTarget ? target.ref === selectedTarget.ref : false
                    }
                    onClick={() => setSelectedRef(target.ref)}
                  >
                    {target.name}
                    {target.atRange ? ` (${target.dist} tiles out)` : ''}
                    {target.status === 'complete' ? ' — surveyed' : ''}
                  </Tabs.Tab>
                );
              })}
            </Tabs>
          ) : (
            <NoticeBox
              backgroundColor={currentThemeColors?.notice}
              textColor={currentThemeColors?.noticeText}
            >
              No celestials in orbit or within scan range
            </NoticeBox>
          )}
        </Section>
      </Stack.Item>
      <Stack.Item>
        <Button
          lineHeight={3}
          backgroundColor={currentThemeColors?.button}
          textColor={currentThemeColors?.buttonText}
          minWidth={30}
          textAlign="center"
          icon="globe"
          fontSize={3}
          tooltip={currentOption.tooltip ? currentOption.tooltip : undefined}
          disabled={
            shipMoving === 0 ? true : currentOption.disabled ? true : false
          }
          onClick={() => {
            if (!currentOption.action) {
              return;
            }
            if (currentOption.action === 'survey') {
              act('survey', { target_ref: selectedTarget?.ref });
            } else {
              act(currentOption.action);
            }
          }}
        >
          {currentOption.content}
        </Button>
      </Stack.Item>
    </Stack>
  );
};

const Planets = (props, context) => {
  const { act, data } = useBackend<Data>();
  const { surveyStatus, theme, surveyData, currentCelestialRef } = data;

  const [planetTab, setPlanetTab] = useState(0);
  const selectedPlanet =
    planetTab === 0
      ? undefined
      : Object.entries(surveyData.planets)[planetTab - 1];
  const selectedPlanetName = selectedPlanet?.[0];
  const selectedPlanetData = selectedPlanet?.[1];

  const planetData = {
    // name
    ...(selectedPlanetName ? { Name: selectedPlanetName } : undefined),
    // visited
    ...(selectedPlanetData?.visited
      ? {
          Activity: selectedPlanetData.visited
            ? 'Previous shuttle activity detected'
            : 'No previous shuttle activity detected',
        }
      : undefined),
  };

  let currentThemeColors = theme ? getThemeColors(theme) : undefined;

  return (
    <Stack fill textAlign="center">
      <Stack.Item>
        <Collapsible
          backgroundColor={currentThemeColors?.collapsible}
          textColor={currentThemeColors?.collapsibleText}
        >
          <Stack fill vertical verticalAlign="middle" textAlign="center">
            <Section title="Current" mt={0.1} pb={0} mb={0}>
              <Stack.Item>
                <Tabs vertical pb={0} mb={0}>
                  {Object.entries(surveyData.planets).map((entry, index) => {
                    return entry[1].ref_id === currentCelestialRef ? (
                      <Tabs.Tab
                        key={entry[0]}
                        selected={planetTab === index + 1}
                        onClick={() => {
                          entry[1].ref_id !== currentCelestialRef
                            ? setPlanetTab(index + 1)
                            : surveyStatus === 'complete'
                              ? setPlanetTab(index + 1)
                              : act('error');
                        }}
                      >
                        {entry[0]}
                      </Tabs.Tab>
                    ) : undefined;
                  })}
                </Tabs>
              </Stack.Item>
            </Section>
            <Section title="Other">
              <Tabs vertical>
                {Object.entries(surveyData.planets).map((entry, index) => {
                  return entry[1].ref_id !== currentCelestialRef ? (
                    <Tabs.Tab
                      key={entry[0]}
                      selected={planetTab === index + 1}
                      onClick={() => {
                        setPlanetTab(index + 1);
                      }}
                    >
                      {entry[0]}
                    </Tabs.Tab>
                  ) : undefined;
                })}
              </Tabs>
            </Section>
          </Stack>
        </Collapsible>
      </Stack.Item>

      <Stack.Divider />

      <Stack.Item grow>
        {selectedPlanet ? (
          <Stack vertical scrollable>
            <Stack.Item>
              <Collapsible
                backgroundColor={currentThemeColors?.collapsible}
                textColor={currentThemeColors?.collapsibleText}
                title="extra"
                open
              >
                <NoticeBox
                  backgroundColor={currentThemeColors?.notice}
                  textColor={currentThemeColors?.noticeText}
                >
                  Certain details are only available after researching the
                  proper survey tech.
                </NoticeBox>
                <Button
                  width="70%"
                  icon="arrows-rotate"
                  onClick={() => act('refresh')}
                >
                  Refresh
                </Button>
              </Collapsible>
            </Stack.Item>
            <Stack.Divider />
            <Stack.Item grow>
              <LabeledList>
                {Object.entries(planetData).map((planetData, index) => {
                  return planetData ? (
                    <LabeledList.Item
                      labelWrap
                      label={planetData[0]}
                      key={planetData[0]}
                    >
                      {planetData[1]}
                    </LabeledList.Item>
                  ) : undefined;
                })}
              </LabeledList>
            </Stack.Item>
          </Stack>
        ) : (
          <NoticeBox
            backgroundColor={currentThemeColors?.notice}
            textColor={currentThemeColors?.noticeText}
          >
            Select a planet from the dropdown menu
          </NoticeBox>
        )}
      </Stack.Item>
    </Stack>
  );
};

const Nebulas = (props, context) => {
  const { act, data } = useBackend<Data>();
  const { surveyStatus, theme, surveyData, currentCelestialRef } = data;

  const [tab, setTab] = useState(0);
  const selected =
    tab === 0 ? undefined : Object.entries(surveyData.nebulas)[tab - 1];
  const selectedName = selected?.[0];
  const selectedData = selected?.[1];

  const celestialData = {
    // name
    ...(selectedName ? { Name: selectedName } : undefined),
    // visited
    ...(selectedData?.gas_type
      ? {
          'Gas type': selectedData.gas_type,
        }
      : undefined),
  };

  let currentThemeColors = theme ? getThemeColors(theme) : undefined;

  return (
    <Stack fill textAlign="center">
      <Stack.Item>
        <Collapsible
          backgroundColor={currentThemeColors?.collapsible}
          textColor={currentThemeColors?.collapsibleText}
        >
          <Stack fill vertical verticalAlign="middle" textAlign="center">
            <Section title="Current" mt={0.1} pb={0} mb={0}>
              <Stack.Item>
                <Tabs vertical pb={0} mb={0}>
                  {Object.entries(surveyData.nebulas).map((entry, index) => {
                    return entry[1].ref_id === currentCelestialRef ? (
                      <Tabs.Tab
                        key={entry[0]}
                        selected={tab === index + 1}
                        onClick={() => {
                          entry[1].ref_id !== currentCelestialRef
                            ? setTab(index + 1)
                            : surveyStatus === 'complete'
                              ? setTab(index + 1)
                              : act('error');
                        }}
                      >
                        {entry[0]}
                      </Tabs.Tab>
                    ) : undefined;
                  })}
                </Tabs>
              </Stack.Item>
            </Section>
            <Section title="Other">
              <Tabs vertical>
                {Object.entries(surveyData.nebulas).map((entry, index) => {
                  return entry[1].ref_id !== currentCelestialRef ? (
                    <Tabs.Tab
                      key={entry[0]}
                      selected={tab === index + 1}
                      onClick={() => {
                        setTab(index + 1);
                      }}
                    >
                      {entry[0]}
                    </Tabs.Tab>
                  ) : undefined;
                })}
              </Tabs>
            </Section>
          </Stack>
        </Collapsible>
      </Stack.Item>

      <Stack.Divider />

      <Stack.Item grow>
        {selected ? (
          <Stack vertical scrollable>
            <Stack.Item>
              <Button fluid icon="arrows-rotate" onClick={() => act('refresh')}>
                Refresh
              </Button>
            </Stack.Item>
            <Stack.Divider />
            <Stack.Item grow>
              <LabeledList>
                {Object.entries(celestialData).map((celestialData, index) => {
                  return celestialData ? (
                    <LabeledList.Item
                      labelWrap
                      label={celestialData[0]}
                      key={celestialData[0]}
                    >
                      {celestialData[1]}
                    </LabeledList.Item>
                  ) : undefined;
                })}
              </LabeledList>
            </Stack.Item>
          </Stack>
        ) : (
          <NoticeBox
            backgroundColor={currentThemeColors?.notice}
            textColor={currentThemeColors?.noticeText}
          >
            Select a nebula from the dropdown menu
          </NoticeBox>
        )}
      </Stack.Item>
    </Stack>
  );
};

const ElectricStorms = (props, context) => {
  const { act, data } = useBackend<Data>();
  const { surveyStatus, theme, surveyData, currentCelestialRef } = data;

  const [tab, setTab] = useState(0);
  const selected =
    tab === 0 ? undefined : Object.entries(surveyData.electric_storms)[tab - 1];
  const selectedName = selected?.[0];
  const selectedData = selected?.[1];

  const celestialData = {
    // name
    ...(selectedName ? { Name: selectedName } : undefined),
    // visited
    ...(selectedData?.intensity
      ? {
          Intensity:
            selectedData.intensity === 1
              ? 'Weak electric storm detected'
              : 'Powerful electric storm detected',
        }
      : undefined),
  };

  let currentThemeColors = theme ? getThemeColors(theme) : undefined;

  return (
    <Stack fill textAlign="center">
      <Stack.Item>
        <Collapsible
          backgroundColor={currentThemeColors?.collapsible}
          textColor={currentThemeColors?.collapsibleText}
        >
          <Stack fill vertical verticalAlign="middle" textAlign="center">
            <Section title="Current" mt={0.1} pb={0} mb={0}>
              <Stack.Item>
                <Tabs vertical pb={0} mb={0}>
                  {Object.entries(surveyData.electric_storms).map(
                    (entry, index) => {
                      return entry[1].ref_id === currentCelestialRef ? (
                        <Tabs.Tab
                          key={entry[0]}
                          selected={tab === index + 1}
                          onClick={() => {
                            entry[1].ref_id !== currentCelestialRef
                              ? setTab(index + 1)
                              : surveyStatus === 'complete'
                                ? setTab(index + 1)
                                : act('error');
                          }}
                        >
                          {entry[0]}
                        </Tabs.Tab>
                      ) : undefined;
                    },
                  )}
                </Tabs>
              </Stack.Item>
            </Section>
            <Section title="Other">
              <Tabs vertical>
                {Object.entries(surveyData.electric_storms).map(
                  (entry, index) => {
                    return entry[1].ref_id !== currentCelestialRef ? (
                      <Tabs.Tab
                        key={entry[0]}
                        selected={tab === index + 1}
                        onClick={() => {
                          setTab(index + 1);
                        }}
                      >
                        {entry[0]}
                      </Tabs.Tab>
                    ) : undefined;
                  },
                )}
              </Tabs>
            </Section>
          </Stack>
        </Collapsible>
      </Stack.Item>

      <Stack.Divider />

      <Stack.Item grow>
        {selected ? (
          <Stack vertical scrollable>
            <Stack.Item>
              <Button fluid icon="arrows-rotate" onClick={() => act('refresh')}>
                Refresh
              </Button>
            </Stack.Item>
            <Stack.Divider />
            <Stack.Item grow>
              <LabeledList>
                {Object.entries(celestialData).map((celestialData, index) => {
                  return celestialData ? (
                    <LabeledList.Item
                      labelWrap
                      label={celestialData[0]}
                      key={celestialData[0]}
                    >
                      {celestialData[1]}
                    </LabeledList.Item>
                  ) : undefined;
                })}
              </LabeledList>
            </Stack.Item>
          </Stack>
        ) : (
          <NoticeBox
            backgroundColor={currentThemeColors?.notice}
            textColor={currentThemeColors?.noticeText}
          >
            Select an electric storm from the dropdown menu
          </NoticeBox>
        )}
      </Stack.Item>
    </Stack>
  );
};

const ElectroMagneticStorms = (props, context) => {
  const { act, data } = useBackend<Data>();
  const { surveyStatus, theme, surveyData, currentCelestialRef } = data;

  const [tab, setTab] = useState(0);
  const selected =
    tab === 0 ? undefined : Object.entries(surveyData.emp_storms)[tab - 1];
  const selectedName = selected?.[0];
  const selectedData = selected?.[1];

  const celestialData = {
    // name
    ...(selectedName ? { Name: selectedName } : undefined),
    // visited
    ...(selectedData?.intensity
      ? {
          Intensity:
            selectedData.intensity === 1
              ? 'Weak emp storm detected'
              : 'Powerful emp storm detected',
        }
      : undefined),
  };

  let currentThemeColors = theme ? getThemeColors(theme) : undefined;

  return (
    <Stack fill textAlign="center">
      <Stack.Item>
        <Collapsible
          backgroundColor={currentThemeColors?.collapsible}
          textColor={currentThemeColors?.collapsibleText}
        >
          <Stack fill vertical verticalAlign="middle" textAlign="center">
            <Section title="Current" mt={0.1} pb={0} mb={0}>
              <Stack.Item>
                <Tabs vertical pb={0} mb={0}>
                  {Object.entries(surveyData.emp_storms).map((entry, index) => {
                    return entry[1].ref_id === currentCelestialRef ? (
                      <Tabs.Tab
                        key={entry[0]}
                        selected={tab === index + 1}
                        onClick={() => {
                          entry[1].ref_id !== currentCelestialRef
                            ? setTab(index + 1)
                            : surveyStatus === 'complete'
                              ? setTab(index + 1)
                              : act('error');
                        }}
                      >
                        {entry[0]}
                      </Tabs.Tab>
                    ) : undefined;
                  })}
                </Tabs>
              </Stack.Item>
            </Section>
            <Section title="Other">
              <Tabs vertical>
                {Object.entries(surveyData.emp_storms).map((entry, index) => {
                  return entry[1].ref_id !== currentCelestialRef ? (
                    <Tabs.Tab
                      key={entry[0]}
                      selected={tab === index + 1}
                      onClick={() => {
                        setTab(index + 1);
                      }}
                    >
                      {entry[0]}
                    </Tabs.Tab>
                  ) : undefined;
                })}
              </Tabs>
            </Section>
          </Stack>
        </Collapsible>
      </Stack.Item>

      <Stack.Divider />

      <Stack.Item grow>
        {selected ? (
          <Stack vertical scrollable>
            <Stack.Item>
              <Button fluid icon="arrows-rotate" onClick={() => act('refresh')}>
                Refresh
              </Button>
            </Stack.Item>
            <Stack.Divider />
            <Stack.Item grow>
              <LabeledList>
                {Object.entries(celestialData).map((celestialData, index) => {
                  return celestialData ? (
                    <LabeledList.Item
                      labelWrap
                      label={celestialData[0]}
                      key={celestialData[0]}
                    >
                      {celestialData[1]}
                    </LabeledList.Item>
                  ) : undefined;
                })}
              </LabeledList>
            </Stack.Item>
          </Stack>
        ) : (
          <NoticeBox
            backgroundColor={currentThemeColors?.notice}
            textColor={currentThemeColors?.noticeText}
          >
            Select an electromagnetic storm from the dropdown menu
          </NoticeBox>
        )}
      </Stack.Item>
    </Stack>
  );
};

const Asteroids = (props, context) => {
  const { act, data } = useBackend<Data>();
  const { surveyStatus, theme, surveyData, currentCelestialRef } = data;

  const [tab, setTab] = useState(0);
  const selected =
    tab === 0 ? undefined : Object.entries(surveyData.asteroids)[tab - 1];
  const selectedName = selected?.[0];
  const selectedData = selected?.[1];

  const celestialData = {
    // name
    ...(selectedName ? { Name: selectedName } : undefined),
    // visited
    ...(selectedData?.minerals
      ? {
          'Resource types': selectedData.minerals,
        }
      : undefined),
  };

  let currentThemeColors = theme ? getThemeColors(theme) : undefined;

  return (
    <Stack fill textAlign="center">
      <Stack.Item>
        <Collapsible
          backgroundColor={currentThemeColors?.collapsible}
          textColor={currentThemeColors?.collapsibleText}
        >
          <Stack fill vertical verticalAlign="middle" textAlign="center">
            <Section title="Current" mt={0.1} pb={0} mb={0}>
              <Stack.Item>
                <Tabs vertical pb={0} mb={0}>
                  {Object.entries(surveyData.asteroids).map((entry, index) => {
                    return entry[1].ref_id === currentCelestialRef ? (
                      <Tabs.Tab
                        key={entry[0]}
                        selected={tab === index + 1}
                        onClick={() => {
                          entry[1].ref_id !== currentCelestialRef
                            ? setTab(index + 1)
                            : surveyStatus === 'complete'
                              ? setTab(index + 1)
                              : act('error');
                        }}
                      >
                        {entry[0]}
                      </Tabs.Tab>
                    ) : undefined;
                  })}
                </Tabs>
              </Stack.Item>
            </Section>
            <Section title="Other">
              <Tabs vertical>
                {Object.entries(surveyData.asteroids).map((entry, index) => {
                  return entry[1].ref_id !== currentCelestialRef ? (
                    <Tabs.Tab
                      key={entry[0]}
                      selected={tab === index + 1}
                      onClick={() => {
                        setTab(index + 1);
                      }}
                    >
                      {entry[0]}
                    </Tabs.Tab>
                  ) : undefined;
                })}
              </Tabs>
            </Section>
          </Stack>
        </Collapsible>
      </Stack.Item>

      <Stack.Divider />

      <Stack.Item grow>
        {selected ? (
          <Stack vertical scrollable>
            <Stack.Item>
              <Button fluid icon="arrows-rotate" onClick={() => act('refresh')}>
                Refresh
              </Button>
            </Stack.Item>
            <Stack.Divider />
            <Stack.Item grow>
              <LabeledList>
                {Object.entries(celestialData).map((celestialData, index) => {
                  return celestialData ? (
                    <LabeledList.Item
                      labelWrap
                      label={celestialData[0]}
                      key={celestialData[0]}
                    >
                      {celestialData[1]}
                    </LabeledList.Item>
                  ) : undefined;
                })}
              </LabeledList>
            </Stack.Item>
          </Stack>
        ) : (
          <NoticeBox
            backgroundColor={currentThemeColors?.notice}
            textColor={currentThemeColors?.noticeText}
          >
            Select an asteroid from the dropdown menu
          </NoticeBox>
        )}
      </Stack.Item>
    </Stack>
  );
};

const Stars = (props, context) => {
  const { act, data } = useBackend<Data>();
  const { surveyStatus, theme, surveyData, currentCelestialRef } = data;

  const [tab, setTab] = useState(0);
  const selected =
    tab === 0 ? undefined : Object.entries(surveyData.stars)[tab - 1];
  const selectedName = selected?.[0];
  const selectedData = selected?.[1];

  const celestialData = {
    // name
    ...(selectedName ? { Name: selectedName } : undefined),
    // visited
    ...(selectedData?.star_type
      ? {
          Type: selectedData.star_type,
        }
      : undefined),
  };

  let currentThemeColors = theme ? getThemeColors(theme) : undefined;

  return (
    <Stack fill textAlign="center">
      <Stack.Item>
        <Collapsible
          backgroundColor={currentThemeColors?.collapsible}
          textColor={currentThemeColors?.collapsibleText}
        >
          <Stack fill vertical verticalAlign="middle" textAlign="center">
            <Section title="Current" mt={0.1} pb={0} mb={0}>
              <Stack.Item>
                <Tabs vertical pb={0} mb={0}>
                  {Object.entries(surveyData.stars).map((entry, index) => {
                    return entry[1].ref_id === currentCelestialRef ? (
                      <Tabs.Tab
                        key={entry[0]}
                        selected={tab === index + 1}
                        onClick={() => {
                          entry[1].ref_id !== currentCelestialRef
                            ? setTab(index + 1)
                            : surveyStatus === 'complete'
                              ? setTab(index + 1)
                              : act('error');
                        }}
                      >
                        {entry[0]}
                      </Tabs.Tab>
                    ) : undefined;
                  })}
                </Tabs>
              </Stack.Item>
            </Section>
            <Section title="Other">
              <Tabs vertical>
                {Object.entries(surveyData.stars).map((entry, index) => {
                  return entry[1].ref_id !== currentCelestialRef ? (
                    <Tabs.Tab
                      key={entry[0]}
                      selected={tab === index + 1}
                      onClick={() => {
                        setTab(index + 1);
                      }}
                    >
                      {entry[0]}
                    </Tabs.Tab>
                  ) : undefined;
                })}
              </Tabs>
            </Section>
          </Stack>
        </Collapsible>
      </Stack.Item>

      <Stack.Divider />

      <Stack.Item grow>
        {selected ? (
          <Stack vertical scrollable>
            <Stack.Item>
              <Button fluid icon="arrows-rotate" onClick={() => act('refresh')}>
                Refresh
              </Button>
            </Stack.Item>
            <Stack.Divider />
            <Stack.Item grow>
              <LabeledList>
                {Object.entries(celestialData).map((celestialData, index) => {
                  return celestialData ? (
                    <LabeledList.Item
                      labelWrap
                      label={celestialData[0]}
                      key={celestialData[0]}
                    >
                      {celestialData[1]}
                    </LabeledList.Item>
                  ) : undefined;
                })}
              </LabeledList>
            </Stack.Item>
          </Stack>
        ) : (
          <NoticeBox
            backgroundColor={currentThemeColors?.notice}
            textColor={currentThemeColors?.noticeText}
          >
            Select a star from the dropdown menu
          </NoticeBox>
        )}
      </Stack.Item>
    </Stack>
  );
};

const Banking = (props, context) => {
  const { act, data } = useBackend<Data>();
  const { bankedCash, theme } = data;
  let currentThemeColors = theme ? getThemeColors(theme) : undefined;

  return (
    <Stack vertical>
      <Stack.Item>
        <Button
          lineHeight={3}
          backgroundColor={currentThemeColors?.button}
          textColor={currentThemeColors?.buttonText}
          ml="10%"
          textAlign="center"
          mr="10%"
          fluid
          mt="10%"
          mb="10%"
          icon="dollar-sign"
          fontSize={3}
          disabled={!bankedCash || bankedCash === 0 ? true : false}
          onClick={() => {
            act('cashOut');
          }}
        >
          Withdrawal
        </Button>
      </Stack.Item>
      <Stack.Item>
        <NoticeBox
          textAlign="center"
          backgroundColor={currentThemeColors?.notice}
          textColor={currentThemeColors?.noticeText}
        >
          You currently have ${bankedCash} to withdrawal
        </NoticeBox>
      </Stack.Item>
    </Stack>
  );
};

const Research = (props, context) => {
  const { act, data } = useBackend<Data>();
  const { bankedPoints, surveyStatus, theme } = data;
  let currentThemeColors = theme ? getThemeColors(theme) : undefined;

  return (
    <Stack vertical>
      <Stack.Item>
        <Button
          lineHeight={3}
          ml="10%"
          mr="10%"
          fluid
          mt="10%"
          mb="10%"
          textAlign="center"
          backgroundColor={currentThemeColors?.button}
          textColor={currentThemeColors?.buttonText}
          icon="print"
          fontSize={3}
          disabled={!bankedPoints || bankedPoints === 0 ? true : false}
          onClick={() => {
            act('printResearch');
          }}
        >
          {' '}
          Print
        </Button>
      </Stack.Item>
      <Stack.Item>
        <NoticeBox
          backgroundColor={currentThemeColors?.notice}
          textColor={currentThemeColors?.noticeText}
          textAlign="center"
        >
          You currently have {bankedPoints} research points to print
        </NoticeBox>
      </Stack.Item>
    </Stack>
  );
};

const Settings = (props, context) => {
  const { act, data } = useBackend<Data>();
  const { surveyDataDisk, bankedPoints, surveyStatus, theme } = data;
  let currentThemeColors = theme ? getThemeColors(theme) : undefined;
  let selectedTheme;
  return (
    <Box align="center" pl={2} pr={2}>
      <Section title="Data disk settings" fontSize={2}>
        <Box>
          <Button
            lineHeight={2}
            backgroundColor={currentThemeColors?.button}
            textColor={currentThemeColors?.buttonText}
            textAlign="center"
            icon="download"
            fontSize={2}
            onClick={() => {
              act('downloadData');
            }}
            tooltip={surveyDataDisk ? undefined : 'no disk loaded'}
            disabled={surveyDataDisk ? false : true}
          >
            Load
          </Button>
          <Button
            lineHeight={2}
            backgroundColor={currentThemeColors?.button}
            textColor={currentThemeColors?.buttonText}
            textAlign="center"
            icon="arrow-up-from-bracket"
            fontSize={2}
            onClick={() => {
              act('saveData');
            }}
            tooltip={surveyDataDisk ? undefined : 'no disk loaded'}
            disabled={surveyDataDisk ? false : true}
          >
            Save
          </Button>
          <Button
            lineHeight={2}
            backgroundColor={currentThemeColors?.button}
            textColor={currentThemeColors?.buttonText}
            textAlign="center"
            icon="eject"
            fontSize={2}
            tooltip={surveyDataDisk ? undefined : 'no disk loaded'}
            onClick={() => {
              act('eject');
            }}
            disabled={surveyDataDisk ? false : true}
          >
            Eject
          </Button>
        </Box>
      </Section>
      <Section title="Other settings" fontSize={2}>
        <Stack fontSize={1.5}>
          <Stack.Item grow />
          <Stack.Item minWidth="40%" maxWidth="50%" grow>
            {' '}
            <Dropdown
              onSelected={(value) => {
                selectedTheme = value;
                act('setTheme', { theme: value });
              }}
              backgroundColor={currentThemeColors?.collapsible}
              color={currentThemeColors?.button}
              width="100%"
              fontSize={1}
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
              selected={selectedTheme}
              displayText={'Theme'}
            />
          </Stack.Item>
          <Stack.Item grow />
        </Stack>
      </Section>
    </Box>
  );
};
