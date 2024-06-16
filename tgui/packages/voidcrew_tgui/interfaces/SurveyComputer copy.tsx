import { useState } from 'react';

import { useBackend } from '../../tgui/backend';
import {
  Button,
  LabeledList,
  Section,
  Stack,
  Tabs,
} from '../../tgui/components';
import { Window } from '../../tgui/layouts';

interface Data {
  type: string;
  loaded: number;
  hostilityLevel: string;
  infoLevel: string;
  weather: string;
  mobTypes: string;
  atmosType: string;
  gatheredLoot: number;
  visited: string;
  megafauna: string;
  playerList: string;
  surveyStatus: string;
  notOverPlanet: number;
  surveyedPlanetsCount: number;
}

export const SurveyComputer = (props, context) => {
  const { act, data } = useBackend<Data>();
  const { surveyStatus } = data;
  const [tab, setTab] = useState(1);

  return (
    <Window width={500} height={587} title="Orbital Survey Computer">
      <Window.Content scrollable>
        <Stack vertical fill>
          <Stack.Item>
            <Tabs fill fluid textAlign="center">
              <Tabs.Tab
                icon="wrench"
                selected={tab === 1}
                maxWidth="33.3%"
                key={1}
                onClick={() => {
                  act('refresh');
                  setTab(1);
                }}
              >
                Survey Technology
              </Tabs.Tab>
              {surveyStatus === 'complete' ? (
                <Tabs.Tab
                  icon="globe"
                  maxWidth="33.4%"
                  selected={tab === 2}
                  key={2}
                  onClick={() => {
                    act('refresh');
                    setTab(2);
                  }}
                >
                  Planet Information
                </Tabs.Tab>
              ) : (
                <Tabs.Tab
                  icon="globe"
                  maxWidth="33.4%"
                  selected={tab === 2}
                  key={2}
                >
                  Planet Information
                </Tabs.Tab>
              )}

              <Tabs.Tab
                icon="arrows-rotate"
                maxWidth="33.3%"
                textColor="blue"
                onClick={() => act('refresh')}
              >
                Refresh Information
              </Tabs.Tab>
            </Tabs>
          </Stack.Item>
          <Stack.Item textAlign={'center'}>
            {tab === 1 ? <SurveyButton /> : <SurveyResults />}
          </Stack.Item>
        </Stack>
      </Window.Content>
    </Window>
  );
};

const SurveyButton = (props, context) => {
  const { act, data } = useBackend<Data>();
  const {
    surveyStatus,
    gatheredLoot,
    notOverPlanet,
    infoLevel,
    surveyedPlanetsCount,
  } = data;

  return (
    <Stack fill vertical>
      <Stack.Item height="30%">
        {/* <Section fill> */}

        <Stack fill>
          <Stack.Item width="50%">
            {notOverPlanet === 1 ? (
              <Button
                fluid
                color="blue"
                lineHeight={2.5}
                icon="globe"
                disabled
                tooltip="no orbit detected"
                onClick={() => act('error')}
                content="Begin Survey"
              />
            ) : surveyStatus === 'complete' ? (
              <Button
                color="green"
                icon="globe"
                verticalAlignContent="middle"
                fluid
                height="100%"
                onClick={() => {
                  act('refresh');
                  act('map');
                }}
                content="Open map"
              />
            ) : surveyStatus === 'in-progress' ? (
              <Button
                color="blue"
                lineHeight={2.5}
                icon="globe"
                content="Surveying..."
              />
            ) : (
              <Button
                color="blue"
                lineHeight={2.5}
                icon="globe"
                onClick={() => {
                  act('refresh');
                  act('survey');
                }}
                content="Begin Survey"
              />
            )}
          </Stack.Item>
          <Stack.Item width="50%">
            <Button
              color="green"
              icon="sack-dollar"
              fluid
              height="100%"
              verticalAlignContent="middle"
            >
              Cash out
            </Button>
          </Stack.Item>
        </Stack>
        {/* </Section> */}
      </Stack.Item>
      <Stack.Item height="70%">
        <Stack>
          <Stack vertical fill width="47%" ml="1.5%" mr="1.5%">
            <Section title="Ship information" fontSize={1.2}>
              <LabeledList>
                <LabeledList.Item textAlign="center" label="Testing">
                  Value
                </LabeledList.Item>
              </LabeledList>
            </Section>
          </Stack>
          <Stack vertical fill width="47%" ml="1.5%" mr="1.5%">
            <Section title="Planet information" fontSize={1.2}>
              <LabeledList>
                <LabeledList.Item label="Ship Name">
                  {' '}
                  Destroyer
                </LabeledList.Item>
                <LabeledList.Item label="Current Tech Level">
                  {infoLevel}
                </LabeledList.Item>
                <LabeledList.Item label="Surveyed Planets">
                  {surveyedPlanetsCount}
                </LabeledList.Item>
                <LabeledList.Item label="Estimated earnings">
                  500
                </LabeledList.Item>
                <LabeledList.Item label="Savings">5000</LabeledList.Item>
              </LabeledList>
            </Section>
          </Stack>
        </Stack>
      </Stack.Item>
    </Stack>
  );
};

const SurveyResults = (props, context) => {
  const { act, data } = useBackend<Data>();
  const {
    type,
    loaded,
    hostilityLevel,
    infoLevel,
    weather,
    mobTypes,
    atmosType,
    visited,
    megafauna,
    playerList,
    surveyStatus,
  } = data;
  return (
    <Section textAlign="center" fontSize={1.5}>
      <LabeledList>
        {type ? (
          <LabeledList.Item label="Type">{type}</LabeledList.Item>
        ) : undefined}

        {hostilityLevel ? (
          <LabeledList.Item label="Hostility">
            {hostilityLevel}
          </LabeledList.Item>
        ) : undefined}

        {infoLevel ? (
          <LabeledList.Item label="infoLevel"> {infoLevel} </LabeledList.Item>
        ) : undefined}

        {weather ? (
          <LabeledList.Item label="weather">{weather}</LabeledList.Item>
        ) : undefined}

        {mobTypes ? (
          <LabeledList.Item label="mobTypes">{mobTypes}</LabeledList.Item>
        ) : undefined}

        {atmosType ? (
          <LabeledList.Item label="atmosType">{atmosType}</LabeledList.Item>
        ) : undefined}

        {visited ? (
          <LabeledList.Item label="visited">{visited}</LabeledList.Item>
        ) : undefined}

        {megafauna ? (
          <LabeledList.Item label="megafauna">{megafauna}</LabeledList.Item>
        ) : undefined}

        {playerList ? (
          <LabeledList.Item label="playerList">{playerList}</LabeledList.Item>
        ) : undefined}
      </LabeledList>
    </Section>
  );
};
