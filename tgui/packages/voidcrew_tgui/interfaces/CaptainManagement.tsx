import { useState } from 'react';
import { type BooleanLike } from 'tgui-core/react';
import {
  Box,
  Button,
  Icon,
  Input,
  NoticeBox,
  Section,
  Stack,
  Table,
  Tabs,
  TextArea,
} from 'tgui-core/components';

import { useBackend } from '../backend';
import { Window } from '../layouts';

type CrewMember = {
  name: string;
  job: string;
  ref: string;
  is_captain: BooleanLike;
  is_online: BooleanLike;
};

type AvailablePlayer = {
  name: string;
  ckey: string;
  job: string;
};

type PendingInvite = {
  ckey: string;
  time: number;
};

type CrewApplication = {
  ref: string;
  name: string;
  ckey: string;
  message: string;
  /// Seconds this application has been waiting
  waiting: number;
};

type Data = {
  ship_destroyed: BooleanLike;
  ship_name: string;
  memo: string;
  joining_allowed: BooleanLike;
  join_password: string;
  can_set_password: BooleanLike;
  crew_only_airlocks: BooleanLike;
  is_captain: BooleanLike;
  crew: CrewMember[];
  available_players: AvailablePlayer[];
  pending_invites: PendingInvite[];
  applications: CrewApplication[];
  can_invite: BooleanLike;
  can_rename: BooleanLike;
};

export const CaptainManagement = () => {
  const { data } = useBackend<Data>();
  const { ship_destroyed, ship_name, is_captain } = data;
  const [currentTab, setCurrentTab] = useState<
    'crew' | 'invites' | 'applications' | 'settings'
  >('crew');

  if (ship_destroyed) {
    return (
      <Window width={500} height={500} title="Ship Management">
        <Window.Content>
          <NoticeBox danger>Ship no longer exists!</NoticeBox>
        </Window.Content>
      </Window>
    );
  }

  if (!is_captain) {
    return (
      <Window width={500} height={500} title="Ship Management">
        <Window.Content>
          <NoticeBox danger>You are no longer the captain!</NoticeBox>
        </Window.Content>
      </Window>
    );
  }

  return (
    <Window width={500} height={550} title={`Ship Management - ${ship_name}`}>
      <Window.Content scrollable>
        <Stack vertical fill>
          <Stack.Item>
            <Tabs fluid>
              <Tabs.Tab
                selected={currentTab === 'crew'}
                onClick={() => setCurrentTab('crew')}
                icon="users"
              >
                Crew ({data.crew.length})
              </Tabs.Tab>
              <Tabs.Tab
                selected={currentTab === 'invites'}
                onClick={() => setCurrentTab('invites')}
                icon="envelope"
              >
                Invites ({data.pending_invites.length})
              </Tabs.Tab>
              <Tabs.Tab
                selected={currentTab === 'applications'}
                onClick={() => setCurrentTab('applications')}
                icon="clipboard-list"
              >
                Applications ({data.applications.length})
              </Tabs.Tab>
              <Tabs.Tab
                selected={currentTab === 'settings'}
                onClick={() => setCurrentTab('settings')}
                icon="cog"
              >
                Settings
              </Tabs.Tab>
            </Tabs>
          </Stack.Item>

          <Stack.Item grow>
            {currentTab === 'crew' && <CrewTab />}
            {currentTab === 'invites' && <InvitesTab />}
            {currentTab === 'applications' && <ApplicationsTab />}
            {currentTab === 'settings' && <SettingsTab />}
          </Stack.Item>
        </Stack>
      </Window.Content>
    </Window>
  );
};

const CrewTab = () => {
  const { act, data } = useBackend<Data>();
  const { crew } = data;

  return (
    <Section title="Crew Roster">
      {crew.length === 0 ? (
        <NoticeBox info>No crew members found.</NoticeBox>
      ) : (
        <Table>
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
                {!member.is_captain && (
                  <Button
                    icon="user-minus"
                    color="bad"
                    compact
                    onClick={() => act('kick_crew', { ref: member.ref })}
                    tooltip="Remove from crew"
                  >
                    Kick
                  </Button>
                )}
              </Table.Cell>
            </Table.Row>
          ))}
        </Table>
      )}
    </Section>
  );
};

const InvitesTab = () => {
  const { act, data } = useBackend<Data>();
  const { available_players, pending_invites, can_invite } = data;

  return (
    <Stack vertical fill>
      <Stack.Item>
        <Section title="Pending Invitations">
          {pending_invites.length === 0 ? (
            <NoticeBox info>No pending invitations.</NoticeBox>
          ) : (
            <Table>
              <Table.Row header>
                <Table.Cell>Player</Table.Cell>
                <Table.Cell>Actions</Table.Cell>
              </Table.Row>
              {pending_invites.map((invite) => (
                <Table.Row key={invite.ckey} className="candystripe">
                  <Table.Cell>{invite.ckey}</Table.Cell>
                  <Table.Cell>
                    <Button
                      icon="times"
                      color="bad"
                      compact
                      onClick={() => act('cancel_invite', { ckey: invite.ckey })}
                    >
                      Cancel
                    </Button>
                  </Table.Cell>
                </Table.Row>
              ))}
            </Table>
          )}
        </Section>
      </Stack.Item>
      <Stack.Item grow>
        <Section title="Available Players" fill scrollable>
          {available_players.length === 0 ? (
            <NoticeBox info>No players available to invite.</NoticeBox>
          ) : (
            <Table>
              <Table.Row header>
                <Table.Cell>Name</Table.Cell>
                <Table.Cell>Role</Table.Cell>
                <Table.Cell>Actions</Table.Cell>
              </Table.Row>
              {available_players.map((player) => (
                <Table.Row key={player.ckey} className="candystripe">
                  <Table.Cell>{player.name}</Table.Cell>
                  <Table.Cell color="label">{player.job}</Table.Cell>
                  <Table.Cell>
                    <Button
                      icon="envelope"
                      color="good"
                      compact
                      disabled={!can_invite}
                      onClick={() => act('invite_player', { ckey: player.ckey })}
                      tooltip={
                        can_invite
                          ? 'Send crew invitation'
                          : 'Please wait before sending another invite'
                      }
                    >
                      Invite
                    </Button>
                  </Table.Cell>
                </Table.Row>
              ))}
            </Table>
          )}
        </Section>
      </Stack.Item>
    </Stack>
  );
};

const ApplicationsTab = () => {
  const { act, data } = useBackend<Data>();
  const { applications } = data;

  return (
    <Section
      title="Applications to Join"
      fill
      scrollable
      buttons={
        <Box color="label" fontSize="11px">
          Sent from the lobby by players your join password is keeping out
        </Box>
      }
    >
      {applications.length === 0 ? (
        <NoticeBox info>
          Nobody has applied. Players see an Apply button on your ship in the
          lobby whenever it is password-locked; approving one lets that player
          in without the password. Applications lapse after ten minutes.
        </NoticeBox>
      ) : (
        <Stack vertical>
          {applications.map((application) => (
            <Stack.Item key={application.ref}>
              <Section>
                <Stack align="center">
                  <Stack.Item grow>
                    <Box bold>{application.name}</Box>
                    <Box color="label" fontSize="11px">
                      ckey: {application.ckey} - waiting {application.waiting}s
                    </Box>
                  </Stack.Item>
                  <Stack.Item>
                    <Button
                      icon="check"
                      color="good"
                      onClick={() =>
                        act('approve_application', { ref: application.ref })
                      }
                    >
                      Approve
                    </Button>
                  </Stack.Item>
                  <Stack.Item>
                    <Button
                      icon="times"
                      color="bad"
                      tooltip="Asks you for an optional reason to send back"
                      onClick={() =>
                        act('deny_application', { ref: application.ref })
                      }
                    >
                      Deny
                    </Button>
                  </Stack.Item>
                </Stack>
                <Box mt={1} italic>
                  &quot;{application.message}&quot;
                </Box>
              </Section>
            </Stack.Item>
          ))}
        </Stack>
      )}
    </Section>
  );
};

const SettingsTab = () => {
  const { act, data } = useBackend<Data>();
  const {
    ship_name,
    memo,
    joining_allowed,
    join_password,
    can_set_password,
    crew_only_airlocks,
    can_rename,
  } = data;
  const [newName, setNewName] = useState(ship_name ?? '');
  const [newMemo, setNewMemo] = useState(memo ?? '');
  const [newPassword, setNewPassword] = useState(join_password ?? '');

  return (
    <Stack vertical fill>
      <Stack.Item>
        <Section title="Ship Name">
          <Stack>
            <Stack.Item grow>
              <Input
                fluid
                value={newName}
                maxLength={42}
                onChange={(value) => setNewName(value ?? '')}
                placeholder="Enter ship name..."
              />
            </Stack.Item>
            <Stack.Item>
              <Button
                icon="save"
                color="good"
                disabled={!newName || newName.length < 2 || !can_rename}
                tooltip={!can_rename ? 'Rename is on cooldown' : ''}
                onClick={() => act('rename_ship', { name: newName })}
              >
                Save
              </Button>
            </Stack.Item>
          </Stack>
          <Box mt={1} fontSize="11px" color="label">
            Ship names must be 2-42 characters. Renaming has a 5-minute cooldown.
          </Box>
        </Section>
      </Stack.Item>

      <Stack.Item>
        <Section title="Cryopod Joining">
          <Stack align="center">
            <Stack.Item grow>
              <Box>
                Allow players to join your ship via cryopods in the lobby menu.
              </Box>
            </Stack.Item>
            <Stack.Item>
              <Button
                icon={joining_allowed ? 'door-open' : 'door-closed'}
                color={joining_allowed ? 'good' : 'bad'}
                onClick={() => act('toggle_joining')}
              >
                {joining_allowed ? 'Enabled' : 'Disabled'}
              </Button>
            </Stack.Item>
          </Stack>
        </Section>
      </Stack.Item>

      <Stack.Item>
        <Section title="Join Password">
          {can_set_password ? (
            <>
              <Box mb={1} color="label" fontSize="11px">
                Players joining from the lobby must enter this password. Crew
                you invite, and anyone who has already served aboard, never
                need it. Leave blank and save to remove the lock.
              </Box>
              <Stack>
                <Stack.Item grow>
                  <Input
                    fluid
                    value={newPassword}
                    maxLength={24}
                    onChange={(value) => setNewPassword(value ?? '')}
                    placeholder="No password - anyone may join"
                  />
                </Stack.Item>
                <Stack.Item>
                  <Button
                    icon={newPassword ? 'lock' : 'lock-open'}
                    color="good"
                    onClick={() =>
                      act('set_password', { password: newPassword })
                    }
                  >
                    {newPassword ? 'Set Password' : 'Clear'}
                  </Button>
                </Stack.Item>
              </Stack>
            </>
          ) : (
            <Box color="label">
              Fleet-issued vessels stay open to everyone and cannot be
              password-locked.
            </Box>
          )}
        </Section>
      </Stack.Item>

      <Stack.Item>
        <Section title="Crew-Only Airlocks">
          {can_set_password ? (
            <Stack align="center">
              <Stack.Item grow>
                <Box color="label" fontSize="11px">
                  While this is on, the airlocks and windoors aboard this ship
                  only open for your crew. Anyone else is refused at the door.
                  Crowbars, emags and cut wires still work as they always did.
                </Box>
              </Stack.Item>
              <Stack.Item>
                <Button
                  icon={crew_only_airlocks ? 'lock' : 'lock-open'}
                  color={crew_only_airlocks ? 'good' : 'bad'}
                  onClick={() => act('toggle_crew_lock')}
                >
                  {crew_only_airlocks ? 'Crew Only' : 'Open To All'}
                </Button>
              </Stack.Item>
            </Stack>
          ) : (
            <Box color="label">
              Fleet-issued vessels stay open to everyone and cannot key their
              airlocks to the crew.
            </Box>
          )}
        </Section>
      </Stack.Item>

      <Stack.Item grow>
        <Section title="Ship Memo" fill>
          <Box mb={1} color="label" fontSize="11px">
            This memo is shown to players when they select your ship in the lobby
            and after they spawn.
          </Box>
          <TextArea
            fluid
            height="100px"
            value={newMemo}
            maxLength={500}
            onChange={(value) => setNewMemo(value ?? '')}
            placeholder="Enter a message for new crew members..."
          />
          <Box mt={1}>
            <Stack align="center">
              <Stack.Item grow>
                <Box color="label" fontSize="11px">
                  {(newMemo ?? '').length}/500 characters
                </Box>
              </Stack.Item>
              <Stack.Item>
                <Button
                  icon="save"
                  color="good"
                  onClick={() => act('set_memo', { memo: newMemo })}
                >
                  Save Memo
                </Button>
              </Stack.Item>
            </Stack>
          </Box>
        </Section>
      </Stack.Item>
    </Stack>
  );
};
