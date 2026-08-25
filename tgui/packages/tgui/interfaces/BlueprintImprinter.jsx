import {
  Box,
  Button,
  Flex,
  Icon,
  LabeledList,
  NoticeBox,
  Section,
  Stack,
} from 'tgui-core/components';
import { toFixed } from 'tgui-core/math';

import { useBackend } from '../backend';
import { Window } from '../layouts';

const TIERS = {
  1: { name: 'Green', color: 'good' },
  2: { name: 'Yellow', color: 'yellow' },
  3: { name: 'Red', color: 'bad' },
};

const TimeFormat = (props) => {
  const { value } = props;
  const seconds = toFixed(Math.floor((value / 10) % 60)).padStart(2, '0');
  const minutes = toFixed(Math.floor((value / (10 * 60)) % 60)).padStart(
    2,
    '0',
  );
  return `${minutes}:${seconds}`;
};

const LoadedCash = (props) => {
  const { act, data } = useBackend();
  const { loaded_credits, account_credits, working } = data;

  return (
    <Section
      title="Payment"
      buttons={
        <Button
          icon="eject"
          disabled={!loaded_credits || !!working}
          onClick={() => act('eject_cash')}
          content="Eject Cash"
        />
      }
    >
      <LabeledList>
        <LabeledList.Item label="Loaded Cash">
          <Box bold color={loaded_credits ? 'good' : 'grey'}>
            <Icon name="coins" mr={1} />
            {loaded_credits} cr
          </Box>
        </LabeledList.Item>
        <LabeledList.Item label="ID Account">
          {account_credits === null ? (
            <Box color="grey" italic>
              No bank account on ID
            </Box>
          ) : (
            <Box>
              <Icon name="id-card" mr={1} />
              {account_credits} cr
            </Box>
          )}
        </LabeledList.Item>
      </LabeledList>
      <Box mt={1} color="label" fontSize="0.9em">
        Fees draw from loaded cash first, then your ID account. Feed bills, coins
        or holochips into the cradle to load cash.
      </Box>
    </Section>
  );
};

const InsertedSchematic = (props) => {
  const { act, data } = useBackend();
  const {
    blueprint_ready,
    schematic_name,
    tier,
    fee,
    already_known,
    can_afford,
    working,
    barred,
  } = data;

  if (!blueprint_ready) {
    return (
      !working && (
        <NoticeBox info>
          Slot a schematic scroll into the cradle to begin.
        </NoticeBox>
      )
    );
  }

  const tierInfo = TIERS[tier] || TIERS[2];
  const blocked = already_known || !can_afford || barred;

  return (
    <Section
      title="Loaded Schematic"
      buttons={
        <>
          <Button
            icon="brain"
            disabled={blocked || !!working}
            color={blocked ? 'default' : 'good'}
            onClick={() => act('imprint')}
            content="Imprint"
            tooltip={
              (barred && 'Trade embargo in effect.') ||
              (already_known && 'You already know this schematic.') ||
              (!can_afford && 'Insufficient funds.') ||
              null
            }
          />
          <Button
            icon="eject"
            disabled={!!working}
            onClick={() => act('eject_blueprint')}
            content="Eject"
          />
        </>
      }
    >
      <LabeledList>
        <LabeledList.Item label="Schematic">
          <Box bold>{schematic_name}</Box>
        </LabeledList.Item>
        <LabeledList.Item label="Tier">
          <Box bold color={tierInfo.color}>
            {tierInfo.name}
          </Box>
        </LabeledList.Item>
        <LabeledList.Item label="Fee">
          <Box bold color={can_afford ? 'good' : 'bad'}>
            {fee} cr
          </Box>
        </LabeledList.Item>
        {!!already_known && (
          <LabeledList.Item label="Status" color="good">
            Already imprinted this round.
          </LabeledList.Item>
        )}
        {!already_known && !can_afford && (
          <LabeledList.Item label="Status" color="bad">
            Insufficient funds: load cash or top up your ID.
          </LabeledList.Item>
        )}
      </LabeledList>
    </Section>
  );
};

export const BlueprintImprinter = (props) => {
  const { act, data } = useBackend();
  const { working, timeleft, has_occupant, barred } = data;

  return (
    <Window title="Neural Schematic Imprinter" width={420} height={400}>
      <Window.Content>
        {!has_occupant && (
          <NoticeBox>No occupant detected. Climb into the cradle.</NoticeBox>
        )}
        {!!barred && <NoticeBox danger>Trade embargo in effect.</NoticeBox>}
        {!!working && (
          <NoticeBox danger>
            <Flex direction="column">
              <Flex.Item mb={0.5}>
                Imprinting in progress. Do not leave the cradle.
              </Flex.Item>
              <Flex.Item>
                Time Left: <TimeFormat value={timeleft} />
              </Flex.Item>
            </Flex>
          </NoticeBox>
        )}
        <InsertedSchematic />
        <LoadedCash />
        <Button
          fluid
          icon="door-open"
          mt={1}
          disabled={!has_occupant}
          onClick={() => act('open_door')}
          content="Open Cradle"
          tooltip="Pop the cradle door from the inside and step out."
        />
      </Window.Content>
    </Window>
  );
};
