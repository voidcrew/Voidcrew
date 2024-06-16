import { useState } from 'react';

import { useBackend } from '../../tgui/backend';
import {
  Button,
  Collapsible,
  LabeledList,
  NoticeBox,
  ProgressBar,
  Section,
  Stack,
  Tabs,
} from '../../tgui/components';
import { Window } from '../../tgui/layouts';

interface SurveyedPlanet {
  loaded: number;
  visited: number;
}

type SurveyedPlanets = {
  [key: string]: SurveyedPlanet;
};

interface Data {
  currentPlanet?: string;
  shipMoving: number;
  surveyStatus: 'unsurveyed' | 'complete' | 'in-progress' | 'planetless';
  surveyedPlanets: SurveyedPlanets;
}

export const SurveyComputer = (props, context) => {
  const { act, data } = useBackend<Data>();
  const { surveyStatus } = data;
  const [tab, setTab] = useState(1);

  return (
    <Window width={540} height={587} title="Orbital Survey Computer">
      <Window.Content scrollable fitted fillPositionedParent>
        <Stack fill scrollable fillPositionedParent>
          <Stack.Item>
            <Section fill>
              <Collapsible>
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
              ) : (
                <Research />
              )}
            </Section>
          </Stack.Item>
        </Stack>
      </Window.Content>
    </Window>
  );
};

const Research = (props, context) => {
  const { act, data } = useBackend<Data>();
  const { surveyStatus } = data;

  return <Section title="Research" />;
};

const Banking = (props, context) => {
  const { act, data } = useBackend<Data>();
  const { surveyStatus, surveyedPlanets } = data;

  return <Section title="Banking">BREAK DA BANK</Section>;
};

const Surveying = (props, context) => {
  const { act, data } = useBackend<Data>();
  const { surveyStatus, shipMoving } = data;

  interface Option {
    state: 'unsurveyed' | 'complete' | 'in-progress' | 'planetless';
    content: string;
    color?: string;
    action?: string;
    disabled?: boolean;
    tooltip?: string;
  }

  const options: Option[] = [
    {
      content: 'Start survey',
      state: 'unsurveyed',
      color: 'blue',
      action: 'survey',
    },
    {
      content: 'In progress',
      state: 'in-progress',
      color: 'yellow',
    },
    { content: 'Open map', state: 'complete', color: 'green', action: 'map' },
    {
      content: 'Start survey',
      state: 'planetless',
      disabled: true,
      tooltip: 'not orbiting any planets',
    },
  ];

  const currentOption = options.find(
    (opt) => opt.state === surveyStatus,
  ) as Option;

  return (
    <Stack vertical fill textAlign="center">
      <Stack.Item>
        <Button
          lineHeight={3}
          ml="10%"
          color={
            currentOption && currentOption.color
              ? currentOption.color
              : undefined
          }
          mr="10%"
          mt="30%"
          width="80%"
          icon="globe"
          verticalAlignContent="middle"
          fontSize={3}
          tooltip={
            currentOption && currentOption.tooltip
              ? currentOption.tooltip
              : undefined
          }
          disabled={currentOption && currentOption.disabled ? true : false}
          onClick={() => {
            currentOption && currentOption.action
              ? act(currentOption.action)
              : undefined;
          }}
          content={currentOption && currentOption.content}
        />
      </Stack.Item>
      {surveyStatus === 'in-progress' ? (
        <Stack.Item>
          <ProgressBar
            mt={1.3}
            maxWidth="40%"
            value={0.7}
            ranges={{
              good: [0.7, 1],
              average: [0.4, 0.7],
              bad: [0, 0.4],
            }}
          />
        </Stack.Item>
      ) : undefined}
    </Stack>
  );
};

const Planets = (props, context) => {
  const { act, data } = useBackend<Data>();
  const { surveyStatus, surveyedPlanets, currentPlanet } = data;

  const [planetTab, setPlanetTab] = useState(0);
  const selectedPlanet =
    planetTab === 0
      ? undefined
      : Object.entries(surveyedPlanets)[planetTab - 1];
  return (
    <Stack fill textAlign="center">
      <Stack.Item>
        <Collapsible open>
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
        <Section title="Planet Info" textAlign="center" fill>
          {selectedPlanet ? (
            <LabeledList key={selectedPlanet[0]}>
              {Object.entries(selectedPlanet[1]).map((prop) => {
                return (
                  <LabeledList.Item
                    textAlign="center"
                    key={prop[0]}
                    label={prop[0]}
                  >
                    {prop[1]}
                  </LabeledList.Item>
                );
              })}
            </LabeledList>
          ) : (
            <NoticeBox info>Select a planet from the dropdown menu</NoticeBox>
          )}
        </Section>
      </Stack.Item>
    </Stack>
  );
};
