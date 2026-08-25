import { useState } from 'react';
import {
  Box,
  Button,
  Dropdown,
  Icon,
  NoticeBox,
  Section,
  Stack,
  Table,
} from 'tgui-core/components';
import { type BooleanLike } from 'tgui-core/react';

import { useBackend } from '../backend';
import { Window } from '../layouts';

type ShipEntry = {
  name: string;
  ref: string;
  crew_count: number;
};

type CrewMember = {
  name: string;
  job: string;
  ref: string;
  is_captain: BooleanLike;
  is_online: BooleanLike;
};

type AddablePlayer = {
  name: string;
  ckey: string;
  ref: string;
};

type Data = {
  ships: ShipEntry[];
  selected_ref: string | null;
  ship_name: string | null;
  memo: string | null;
  joining_allowed: BooleanLike;
  crew: CrewMember[];
  addable_players: AddablePlayer[];
};

export const AdminCrewManagement = () => {
  const { act, data } = useBackend<Data>();
  const { ships, selected_ref } = data;

  return (
    <Window width={720} height={500} title="Ship Crew Management">
      <Window.Content>
        <Stack fill>
          <Stack.Item basis="40%">
            <Section title="Ships" fill scrollable>
              {ships.length === 0 ? (
                <NoticeBox info>No simulated ships exist right now.</NoticeBox>
              ) : (
                <Table>
                  {ships.map((ship) => (
                    <Table.Row
                      key={ship.ref}
                      className="candystripe"
                      bold={ship.ref === selected_ref}
                      onClick={() => act('select_ship', { ref: ship.ref })}
                      style={{ cursor: 'pointer' }}
                    >
                      <Table.Cell>{ship.name}</Table.Cell>
                      <Table.Cell collapsing color="label">
                        {ship.crew_count} crew
                      </Table.Cell>
                    </Table.Row>
                  ))}
                </Table>
              )}
            </Section>
          </Stack.Item>
          <Stack.Item grow>
            {selected_ref ? (
              <CrewPanel />
            ) : (
              <Section title="Crew" fill>
                <NoticeBox info>Select a ship on the left.</NoticeBox>
              </Section>
            )}
          </Stack.Item>
        </Stack>
      </Window.Content>
    </Window>
  );
};

const CrewPanel = () => {
  const { act, data } = useBackend<Data>();
  const { ship_name, memo, joining_allowed, crew, addable_players } = data;
  const [addTarget, setAddTarget] = useState('');

  return (
    <Stack vertical fill>
      <Stack.Item>
        <Section
          title={`Crew of ${ship_name}`}
          buttons={
            <Box color={joining_allowed ? 'good' : 'bad'} fontSize="11px">
              <Icon name={joining_allowed ? 'door-open' : 'door-closed'} mr={1} />
              {joining_allowed ? 'Joining enabled' : 'Joining disabled'}
            </Box>
          }
        >
          {!!memo && (
            <Box color="label" fontSize="11px" italic>
              Memo: {memo}
            </Box>
          )}
          {crew.length === 0 ? (
            <NoticeBox info mt={!!memo ? 1 : 0}>
              No crew members on this ship.
            </NoticeBox>
          ) : (
            <Table mt={!!memo ? 1 : 0}>
              <Table.Row header>
                <Table.Cell>Name</Table.Cell>
                <Table.Cell>Role</Table.Cell>
                <Table.Cell>Status</Table.Cell>
                <Table.Cell>Actions</Table.Cell>
              </Table.Row>
              {crew.map((member) => (
                <Table.Row key={member.ref} className="candystripe">
                  <Table.Cell bold={!!member.is_captain}>
                    {member.name}
                    {!!member.is_captain && (
                      <Box inline color="gold" ml={1}>
                        <Icon name="crown" />
                      </Box>
                    )}
                  </Table.Cell>
                  <Table.Cell>{member.job}</Table.Cell>
                  <Table.Cell color={member.is_online ? 'good' : 'grey'}>
                    <Icon name={member.is_online ? 'circle' : 'circle-xmark'} />
                    {member.is_online ? ' Online' : ' Offline'}
                  </Table.Cell>
                  <Table.Cell>
                    {member.is_captain ? (
                      <Button.Confirm
                        icon="arrow-down"
                        color="average"
                        compact
                        onClick={() => act('demote', { ref: member.ref })}
                        tooltip="Remove captaincy"
                      >
                        Demote
                      </Button.Confirm>
                    ) : (
                      <Button.Confirm
                        icon="crown"
                        color="good"
                        compact
                        onClick={() => act('promote', { ref: member.ref })}
                        tooltip="Transfer captaincy to this member"
                      >
                        Make Captain
                      </Button.Confirm>
                    )}
                    <Button.Confirm
                      icon="user-minus"
                      color="bad"
                      compact
                      ml={1}
                      onClick={() => act('kick', { ref: member.ref })}
                      tooltip="Remove from crew"
                    >
                      Kick
                    </Button.Confirm>
                  </Table.Cell>
                </Table.Row>
              ))}
            </Table>
          )}
        </Section>
      </Stack.Item>
      <Stack.Item>
        <Section title="Add Player to Crew">
          {addable_players.length === 0 ? (
            <NoticeBox info>No eligible players (everyone is already aboard).</NoticeBox>
          ) : (
            <Stack align="center">
              <Stack.Item grow>
                <Dropdown
                  width="100%"
                  selected={addTarget}
                  options={addable_players.map((player) => `${player.name} (${player.ckey})`)}
                  onSelected={(value) => setAddTarget(value)}
                />
              </Stack.Item>
              <Stack.Item>
                <Button
                  icon="user-plus"
                  color="good"
                  disabled={!addTarget}
                  onClick={() =>
                    act('add_crew', {
                      ref: addable_players.find(
                        (player) =>
                          `${player.name} (${player.ckey})` === addTarget,
                      )?.ref,
                    })
                  }
                >
                  Add
                </Button>
              </Stack.Item>
            </Stack>
          )}
        </Section>
      </Stack.Item>
    </Stack>
  );
};
