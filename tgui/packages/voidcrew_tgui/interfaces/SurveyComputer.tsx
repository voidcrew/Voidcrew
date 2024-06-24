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
} from '../../tgui/components';
import { Window } from '../../tgui/layouts';

interface SurveyedPlanet {
  loaded: number;
  visited: number;
  testAdvData: string;
  testEliteData: string;
}

type SurveyedPlanets = {
  [key: string]: SurveyedPlanet;
};

interface Data {
  bankedCash: number;
  bankedPoints: number;
  currentPlanet?: string;
  mappingEnabled?: number;
  shipMoving: number;
  surveyedPlanets: SurveyedPlanets;
  surveyStatus: 'unsurveyed' | 'complete' | 'in-progress' | 'no-orbit';
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
  const { theme } = data;
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
                <Tabs vertical>
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
                    icon="globe"
                    mt={1}
                    mb={1}
                    selected={tab === 2}
                    key={2}
                    onClick={() => {
                      setTab(2);
                    }}
                  >
                    Planets
                  </Tabs.Tab>
                  <Tabs.Tab
                    icon="dollar-sign"
                    mt={1}
                    mb={1}
                    selected={tab === 3}
                    key={3}
                    onClick={() => {
                      setTab(3);
                    }}
                  >
                    Banking
                  </Tabs.Tab>
                  <Tabs.Tab
                    icon="flask"
                    mt={1}
                    mb={1}
                    selected={tab === 4}
                    key={4}
                    onClick={() => {
                      setTab(4);
                    }}
                  >
                    Research
                  </Tabs.Tab>
                  <Tabs.Tab
                    icon="wrench"
                    mt={1}
                    mb={1}
                    selected={tab === 5}
                    key={5}
                    onClick={() => {
                      setTab(5);
                    }}
                  >
                    Settings
                  </Tabs.Tab>
                </Tabs>
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
                <Banking />
              ) : tab === 4 ? (
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
    mappingEnabled,
    surveyValue,
    surveyStatus,
    shipMoving,
  } = data;

  interface Option {
    state: 'unsurveyed' | 'complete' | 'in-progress' | 'no-orbit';
    content: string;
    action?: string;
    disabled?: boolean;
    tooltip?: string;
  }

  const options: Option[] = [
    {
      content: 'Start survey',
      state: 'unsurveyed',
      action: 'survey',
      tooltip:
        surveyValue && surveyValue.points && surveyValue.cash
          ? `Value: ${surveyValue.points} points | ${surveyValue.cash} credits`
          : undefined,
    },
    {
      content: 'In progress',
      state: 'in-progress',
      disabled: true,
    },
    {
      content: 'Open map',
      state: 'complete',
      action: 'map',
      disabled: mappingEnabled ? false : true,
      tooltip: mappingEnabled ? undefined : 'Mapping is not yet unlocked',
    },
    {
      content: 'Start survey',
      // state: 'planetless',
      state: 'no-orbit',
      disabled: true,
      tooltip: 'not orbiting any planets',
    },
  ];

  const currentOption = options.find(
    (opt) => opt.state === surveyStatus,
  ) as Option;

  const notices: string[] = [];

  if (shipMoving === 0) {
    notices.push('Ship is currently moving, surveying disabled');
  }

  if (bankedPoints && bankedPoints !== 0) {
    notices.push(`You have ${bankedPoints} research points to print`);
  }

  if (bankedCash && bankedCash !== 0) {
    notices.push(`You have ${bankedCash} credits to cash out`);
  }

  let currentThemeColors = theme ? getThemeColors(theme) : undefined;
  let selectedTheme;
  return (
    <Stack vertical fill textAlign="center">
      <Stack.Item height="20%" pb={0} mb={0}>
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
      <Stack.Item height="60%" grow>
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
            currentOption.action ? act(currentOption.action) : undefined;
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
  const { surveyStatus, theme, surveyedPlanets, currentPlanet } = data;

  const [planetTab, setPlanetTab] = useState(0);
  const selectedPlanet =
    planetTab === 0
      ? undefined
      : Object.entries(surveyedPlanets)[planetTab - 1];
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
    // Test advanced data
    ...(selectedPlanetData?.testAdvData
      ? { TestAdv: selectedPlanetData?.testAdvData }
      : undefined),
    // Test elite data
    ...(selectedPlanetData?.testEliteData
      ? { TestElite: selectedPlanetData?.testEliteData }
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
                  {Object.entries(surveyedPlanets).map((entry, index) => {
                    return entry[0] === currentPlanet ? (
                      <Tabs.Tab
                        key={entry[0]}
                        selected={planetTab === index + 1}
                        onClick={() => {
                          entry[0] !== currentPlanet
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
              <Stack.Item>
                <Tabs vertical>
                  {Object.entries(surveyedPlanets).map((entry, index) => {
                    return entry[0] !== currentPlanet ? (
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
              </Stack.Item>
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
                title="help"
                open
              >
                <NoticeBox
                  backgroundColor={currentThemeColors?.notice}
                  textColor={currentThemeColors?.noticeText}
                >
                  Information about a planet only updates while in orbit.
                </NoticeBox>
                <NoticeBox
                  backgroundColor={currentThemeColors?.notice}
                  textColor={currentThemeColors?.noticeText}
                >
                  Certain details are only available after researching the
                  proper survey tech.
                </NoticeBox>
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

const Banking = (props, context) => {
  const { act, data } = useBackend<Data>();
  const { bankedCash, surveyStatus, surveyedPlanets, theme } = data;
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
              act('loadData');
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
