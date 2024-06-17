import { useState } from 'react';

import { useBackend } from '../../tgui/backend';
import {
  Button,
  Collapsible,
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
}

type SurveyedPlanets = {
  [key: string]: SurveyedPlanet;
};

interface Data {
  bankedCash: number;
  bankedPoints: number;
  currentPlanet?: string;
  shipMoving: number;
  surveyedPlanets: SurveyedPlanets;
  surveyStatus: 'unsurveyed' | 'complete' | 'in-progress' | 'planetless';
  surveyValue: { cash: number; points: number };
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
  const { bankedPoints, surveyStatus } = data;

  return (
    <Stack vertical>
      <Stack.Item>
        <Section title="Research" textAlign="center" />
      </Stack.Item>

      <Stack.Item>
        <Button
          lineHeight={3}
          // color={currentOption.color ? currentOption.color : undefined}
          ml="10%"
          mr="10%"
          fluid
          mt="10%"
          mb="10%"
          textAlign="center"
          icon="print"
          fontSize={3}
          // tooltip={currentOption.tooltip ? currentOption.tooltip : undefined}
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
        <NoticeBox textAlign="center" success>
          You currently have {bankedPoints} research points to print
        </NoticeBox>
      </Stack.Item>
    </Stack>
  );
};

const Banking = (props, context) => {
  const { act, data } = useBackend<Data>();
  const { bankedCash, surveyStatus, surveyedPlanets } = data;

  return (
    <Stack vertical>
      <Stack.Item>
        <Section title="Banking" textAlign="center" />
      </Stack.Item>

      <Stack.Item>
        <Button
          lineHeight={3}
          // color={currentOption.color ? currentOption.color : undefined}
          ml="10%"
          textAlign="center"
          mr="10%"
          fluid
          mt="10%"
          mb="10%"
          icon="dollar-sign"
          fontSize={3}
          // tooltip={currentOption.tooltip ? currentOption.tooltip : undefined}
          disabled={!bankedCash || bankedCash === 0 ? true : false}
          onClick={() => {
            act('cashOut');
          }}
        >
          {' '}
          Withdrawal
        </Button>
      </Stack.Item>
      <Stack.Item>
        <NoticeBox textAlign="center" success>
          You currently have ${bankedCash} to withdrawal
        </NoticeBox>
      </Stack.Item>
    </Stack>
  );
};

const Surveying = (props, context) => {
  const { act, data } = useBackend<Data>();
  const { bankedCash, bankedPoints, surveyValue, surveyStatus, shipMoving } =
    data;

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
      tooltip:
        surveyValue && surveyValue.points && surveyValue.cash
          ? `Value: ${surveyValue.points} points | ${surveyValue.cash} credits`
          : undefined,
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

  return (
    <Stack vertical fill textAlign="center">
      <Stack.Item height="20%" pb={0} mb={0}>
        <Collapsible
          title="Notices"
          lineHeight={2}
          icon={notices.length > 0 ? 'triangle-exclamation' : 'check'}
        >
          {notices.length > 0
            ? notices.map((notice, index) => {
                return <NoticeBox key={index}>{notice}</NoticeBox>;
              })
            : undefined}
        </Collapsible>
      </Stack.Item>
      <Stack.Item height="80%" grow>
        <Button
          lineHeight={3}
          color={currentOption.color ? currentOption.color : undefined}
          ml="10%"
          mr="10%"
          fluid
          mt="10%"
          mb="10%"
          icon="globe"
          fontSize={3}
          tooltip={currentOption.tooltip ? currentOption.tooltip : undefined}
          disabled={
            shipMoving === 0 ? true : currentOption.disabled ? true : false
          }
          onClick={() => {
            currentOption.action ? act(currentOption.action) : undefined;
          }}
          content={currentOption.content}
        />
      </Stack.Item>
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
        <Collapsible>
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
