import { useState } from 'react';

import {
  Box,
  Button,
  Input,
  LabeledList,
  NoticeBox,
  Section,
  Stack,
  TextArea,
} from 'tgui-core/components';
import type { BooleanLike } from 'tgui-core/react';

import { useBackend } from '../backend';
import { Window } from '../layouts';

type ShipEntry = {
  name: string;
  ref: string;
};

type Candidate = {
  name: string;
  ckey: string;
  ref: string;
  can_receive_outpost: BooleanLike;
};

type Data = {
  linked: BooleanLike;
  outpost_name: string;
  founder_name: string | null;
  memo: string;
  is_owner: BooleanLike;
  has_owner: BooleanLike;
  raidable: BooleanLike;
  dock_mode: string;
  rename_cooldown: number;
  advert_cost: number;
  advert_cooldown: number;
  advert_remaining: number;
  dock_requests: ShipEntry[];
  approved_ships: ShipEntry[];
  banned_ships: ShipEntry[];
  builders: string[];
  candidates: Candidate[];
};

const DOCK_MODES = [
  { id: 'open', label: 'Open', icon: 'door-open' },
  { id: 'request', label: 'By Request', icon: 'question' },
  { id: 'lockdown', label: 'Lockdown', icon: 'lock' },
] as const;

const IdentitySection = () => {
  const { act, data } = useBackend<Data>();
  const { outpost_name, memo, is_owner, rename_cooldown } = data;
  const [newName, setNewName] = useState('');
  const [newMemo, setNewMemo] = useState(memo);

  return (
    <Section title="Registry Identity">
      <LabeledList>
        <LabeledList.Item label="Outpost">{outpost_name}</LabeledList.Item>
      </LabeledList>
      {!!is_owner && (
        <>
          <Stack mt={1}>
            <Stack.Item grow>
              <Input
                fluid
                placeholder="New designation..."
                value={newName}
                onChange={setNewName}
              />
            </Stack.Item>
            <Stack.Item>
              <Button
                icon="signature"
                disabled={!newName.trim() || rename_cooldown > 0}
                tooltip={
                  rename_cooldown > 0
                    ? `Registry cooldown: ${Math.ceil(rename_cooldown)}s`
                    : undefined
                }
                onClick={() => {
                  act('rename', { name: newName.trim() });
                  setNewName('');
                }}
              >
                Rename
              </Button>
            </Stack.Item>
          </Stack>
          <Box mt={1}>
            <TextArea
              fluid
              height="3em"
              placeholder="Public memo, shown to anyone surveying the outpost and on broadcasts..."
              value={newMemo}
              onChange={setNewMemo}
            />
            <Button
              mt={0.5}
              icon="pen"
              onClick={() => act('set_memo', { memo: newMemo })}
            >
              Save Memo
            </Button>
          </Box>
        </>
      )}
      {!is_owner && memo && <Box color="label">&quot;{memo}&quot;</Box>}
    </Section>
  );
};

const BroadcastSection = () => {
  const { act, data } = useBackend<Data>();
  const { is_owner, advert_cost, advert_cooldown, advert_remaining } = data;

  return (
    <Section title="Galaxy-Wide Broadcast">
      {advert_remaining > 0 ? (
        <NoticeBox success>
          Broadcast live, {Math.ceil(advert_remaining / 60)} min remaining.
          Your outpost is pinned on every ship&apos;s nav chart.
        </NoticeBox>
      ) : (
        <Box color="label">
          Put your outpost on every helm chart and mission board in the sector.
          One-time notification to all ships; listing lasts 20 minutes.
        </Box>
      )}
      {!!is_owner && (
        <Button
          mt={1}
          fluid
          icon="satellite-dish"
          textAlign="center"
          disabled={advert_remaining > 0 || advert_cooldown > 0}
          tooltip={
            advert_cooldown > 0
              ? `Array recharging: ${Math.ceil(advert_cooldown)}s`
              : undefined
          }
          onClick={() => act('buy_advert')}
        >
          Buy Broadcast ({advert_cost} cr, charged to your ID)
        </Button>
      )}
    </Section>
  );
};

const DockingSection = () => {
  const { act, data } = useBackend<Data>();
  const {
    is_owner,
    dock_mode,
    dock_requests = [],
    approved_ships = [],
    banned_ships = [],
  } = data;

  return (
    <Section title="Docking Control">
      <Stack>
        {DOCK_MODES.map((mode) => (
          <Stack.Item key={mode.id} grow>
            <Button
              fluid
              icon={mode.icon}
              textAlign="center"
              selected={dock_mode === mode.id}
              disabled={!is_owner}
              onClick={() => act('set_dock_mode', { mode: mode.id })}
            >
              {mode.label}
            </Button>
          </Stack.Item>
        ))}
      </Stack>
      {dock_requests.length > 0 && (
        <Section title="Pending Requests">
          {dock_requests.map((ship) => (
            <Stack key={ship.ref} align="center" className="candystripe">
              <Stack.Item grow bold>
                {ship.name}
              </Stack.Item>
              {!!is_owner && (
                <>
                  <Stack.Item>
                    <Button
                      icon="check"
                      color="good"
                      onClick={() => act('approve_request', { ref: ship.ref })}
                    >
                      Approve
                    </Button>
                  </Stack.Item>
                  <Stack.Item>
                    <Button
                      icon="times"
                      color="bad"
                      onClick={() => act('deny_request', { ref: ship.ref })}
                    >
                      Deny
                    </Button>
                  </Stack.Item>
                  <Stack.Item>
                    <Button
                      icon="ban"
                      color="bad"
                      tooltip="Deny and ban this vessel"
                      onClick={() => act('ban_ship', { ref: ship.ref })}
                    />
                  </Stack.Item>
                </>
              )}
            </Stack>
          ))}
        </Section>
      )}
      {approved_ships.length > 0 && (
        <Section title="Cleared Vessels">
          {approved_ships.map((ship) => (
            <Stack key={ship.ref} align="center" className="candystripe">
              <Stack.Item grow>{ship.name}</Stack.Item>
              {!!is_owner && (
                <Stack.Item>
                  <Button
                    icon="times"
                    onClick={() => act('revoke_approval', { ref: ship.ref })}
                  >
                    Revoke
                  </Button>
                </Stack.Item>
              )}
            </Stack>
          ))}
        </Section>
      )}
      {banned_ships.length > 0 && (
        <Section title="Banned Vessels">
          {banned_ships.map((ship) => (
            <Stack key={ship.ref} align="center" className="candystripe">
              <Stack.Item grow>{ship.name}</Stack.Item>
              {!!is_owner && (
                <Stack.Item>
                  <Button
                    icon="undo"
                    onClick={() => act('unban_ship', { ref: ship.ref })}
                  >
                    Unban
                  </Button>
                </Stack.Item>
              )}
            </Stack>
          ))}
        </Section>
      )}
    </Section>
  );
};

const PeopleSection = () => {
  const { act, data } = useBackend<Data>();
  const { is_owner, builders = [], candidates = [] } = data;

  if (!is_owner) {
    return null;
  }

  return (
    <Section title="Builders & Ownership">
      {builders.length > 0 && (
        <>
          <Box color="label">Authorized builders:</Box>
          {builders.map((ckey) => (
            <Stack key={ckey} align="center" className="candystripe">
              <Stack.Item grow>{ckey}</Stack.Item>
              <Stack.Item>
                <Button
                  icon="times"
                  onClick={() => act('remove_builder', { ckey })}
                >
                  Revoke
                </Button>
              </Stack.Item>
            </Stack>
          ))}
        </>
      )}
      {candidates.length > 0 ? (
        <>
          <Box color="label" mt={1}>
            People on the outpost:
          </Box>
          {candidates.map((person) => (
            <Stack key={person.ref} align="center" className="candystripe">
              <Stack.Item grow>{person.name}</Stack.Item>
              <Stack.Item>
                <Button
                  icon="hammer"
                  disabled={builders.includes(person.ckey)}
                  onClick={() => act('add_builder', { ref: person.ref })}
                >
                  Authorize
                </Button>
              </Stack.Item>
              <Stack.Item>
                <Button
                  icon="crown"
                  color="average"
                  disabled={!person.can_receive_outpost}
                  tooltip={
                    person.can_receive_outpost
                      ? 'Transfer ownership permanently'
                      : 'Already holds a claim this shift'
                  }
                  onClick={() => act('transfer', { ref: person.ref })}
                >
                  Transfer
                </Button>
              </Stack.Item>
            </Stack>
          ))}
        </>
      ) : (
        <Box color="label" mt={1}>
          Nobody else is on the outpost right now, builders and ownership
          transfers require the person to be here in person.
        </Box>
      )}
    </Section>
  );
};

export const OutpostManagement = (props) => {
  const { act, data } = useBackend<Data>();
  const { linked, founder_name, is_owner, has_owner, raidable } = data;

  if (!linked) {
    return (
      <Window title="Outpost Management" width={500} height={200}>
        <Window.Content>
          <NoticeBox danger>
            No outpost registry link: this console isn&apos;t on a registered
            claim.
          </NoticeBox>
        </Window.Content>
      </Window>
    );
  }

  return (
    <Window title="Outpost Management" width={500} height={640}>
      <Window.Content scrollable>
        {!has_owner && (
          <NoticeBox warning>
            This outpost has been abandoned. It has no registered owner.
          </NoticeBox>
        )}
        {!!has_owner && !is_owner && (
          <NoticeBox>
            Registered to {founder_name}. Read-only access.
          </NoticeBox>
        )}
        {!!raidable && (
          <NoticeBox danger>
            Unpatrolled space: this outpost can be attacked by other ships.
          </NoticeBox>
        )}
        <IdentitySection />
        <BroadcastSection />
        <DockingSection />
        <PeopleSection />
        {!!is_owner && (
          <Section title="Danger Zone">
            <Button
              fluid
              icon="person-walking-arrow-right"
              color="bad"
              textAlign="center"
              onClick={() => act('abandon')}
            >
              Abandon Outpost
            </Button>
          </Section>
        )}
      </Window.Content>
    </Window>
  );
};
