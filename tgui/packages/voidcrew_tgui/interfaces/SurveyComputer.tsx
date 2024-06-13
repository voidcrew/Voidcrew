import { useBackend } from '../../tgui/backend';
import { Button, Section, Stack } from '../../tgui/components';
import { Window } from '../../tgui/layouts';

export const SurveyComputer = (props, context) => {
  const { act, data } = useBackend();
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
    <Window width={390} height={587}>
      <Window.Content />
      <Window.Content scrollable>
        <SurveyButton />
      </Window.Content>
    </Window>
  );
};

export const SurveyButton = (props, context) => {
  const { act, data, config } = useBackend();
  const { surveyStatus } = data;
  return (
    <Section title="Survey status" textAlign="center">
      <Stack vertical>
        <Stack.Item fontSize={1.5}>Status: {surveyStatus}</Stack.Item>
        <Stack.Item>
          <Button
            tooltip="Begin survey"
            // tooltipPosition="right"
            // icon="sign-out-alt"
            fluid
            color="blue"
            lineHeight={5}
            align="center"
            // selected
            icon="globe"
            content="Begin Survey"
          />
        </Stack.Item>
      </Stack>
    </Section>
  );
};

export const SurveyResults = (props, context) => {
  const { act, data } = useBackend();
};
