import { useState } from 'react';
import {
  Box,
  Button,
  Input,
  LabeledList,
  NoticeBox,
  Section,
  Stack,
} from 'tgui-core/components';
import type { BooleanLike } from 'tgui-core/react';
import { useBackend } from '../backend';

export type HomeServiceData = {
  can_manage: BooleanLike;
  can_spend: BooleanLike;
  is_owner: BooleanLike;
  balance: number;
  treasury_name: string;
  personal_account: string | null;
  ledger: { adjusted_money: number; reason: string }[];
  cargo_state: number;
  cargo_status: string;
  cargo_orders: number;
  cargo_history: {
    time: string;
    type: string;
    name: string;
    amount: number;
    value: number;
  }[];
  resident_mode: string;
  resident_limit: number;
  resident_active: number;
  arrival_available: BooleanLike;
  residents: {
    ref: string;
    name: string;
    active: BooleanLike;
    steward: BooleanLike;
    treasurer: BooleanLike;
  }[];
  candidates: { ref: string; name: string }[];
  resident_invites: Record<string, BooleanLike>;
  resident_blocked: string[];
  research_pairs: {
    ref: string;
    name: string;
    status: string;
    last_success: string | null;
  }[];
};

export const OutpostHomeServices = () => {
  const { act, data } = useBackend<HomeServiceData>();
  const [amount, setAmount] = useState('');
  const [account, setAccount] = useState('');
  const [password, setPassword] = useState('');
  const [positions, setPositions] = useState(String(data.resident_limit));
  return (
    <>
      <Section title="Home Services">
        <Box>
          Included: powered habitat, charged SMES, portable generator with 10
          plasma sheets, management and construction consoles, docking elevator,
          freight receiving, empty silo, bank terminal and resident cryopod.
        </Box>
        <Box mt={1}>
          Power and fuel are finite. Deposit reserves, maintain power, and build
          a lab and fabrication equipment using ordinary construction. Rejoining
          or replacing equipment provides no new founding stock.
        </Box>
      </Section>
      <Section title={data.treasury_name}>
        <LabeledList>
          <LabeledList.Item label="Available">
            {data.balance} cr
          </LabeledList.Item>
          <LabeledList.Item label="Your ID account">
            {data.personal_account || 'No account on ID'}
          </LabeledList.Item>
        </LabeledList>
        <Input
          mt={1}
          placeholder="Whole credits"
          value={amount}
          onChange={setAmount}
        />
        <Button
          disabled={!data.personal_account}
          onClick={() => act('deposit', { amount })}
        >
          ID account → Treasury
        </Button>
        <Button
          disabled={!data.can_spend || !data.personal_account}
          onClick={() => act('withdraw', { amount })}
        >
          Treasury → ID account
        </Button>
        <Box color="label">
          Cash and holochips can be deposited at the bank terminal.
        </Box>
        {data.ledger.map((entry, index) => (
          <Box key={index} mt={1}>
            {entry.adjusted_money} cr: {entry.reason}
          </Box>
        ))}
      </Section>
      <Section title="Cargo and Materials">
        <Box>{data.cargo_status}</Box>
        <Box>
          {data.cargo_orders} orders in the shared cart. Freight state:{' '}
          {['Away', 'Arriving', 'Docked', 'Departing'][data.cargo_state] ||
            data.cargo_state}
          .
        </Box>
        <Box mt={1}>
          Order through the cargo console or materials market using treasury
          spending permission. Take the elevator to Freight Receiving to unload.
          Place actual goods on the freight vessel and dispatch it to export.
        </Box>
        <Button onClick={() => act('open_cargo')}>Locate cargo console</Button>
        {data.cargo_history.slice(0, 10).map((entry, index) => (
          <Box key={index}>
            {entry.time}: {entry.type} {entry.amount} × {entry.name} (
            {entry.value} cr)
          </Box>
        ))}
      </Section>
      <Section title="Residents and Return Access">
        <Box>
          {data.resident_active} / {data.resident_limit} active residents.
          Arrival:{' '}
          {data.arrival_available
            ? 'Cryopod available'
            : 'No available cryopod'}
          .
        </Box>
        <Box color="label">
          Join as a resident through the normal lobby, subject to respawn,
          character and cryo cooldown rules. Ship membership and ID accounts
          stay separate. Delegated roles belong to the current character; saved
          return access belongs to the player account for this round.
        </Box>
        {!!data.can_manage && (
          <>
            <Box mt={1}>
              {['open', 'password', 'approved', 'closed'].map((mode) => (
                <Button
                  key={mode}
                  selected={data.resident_mode === mode}
                  onClick={() => act('resident_mode', { mode })}
                >
                  {mode}
                </Button>
              ))}
            </Box>
            <Input
              placeholder="Resident password"
              value={password}
              onChange={setPassword}
            />
            <Button
              onClick={() => {
                act('resident_password', { password });
                setPassword('');
              }}
            >
              Set password / clear saved password access
            </Button>
            <Stack mt={1}>
              <Stack.Item grow>
                <Input
                  placeholder="Player account name"
                  value={account}
                  onChange={setAccount}
                />
              </Stack.Item>
              <Stack.Item>
                <Button
                  onClick={() => act('invite_resident', { ckey: account })}
                >
                  Invite
                </Button>
                <Button
                  color="bad"
                  onClick={() => act('block_resident', { ckey: account })}
                >
                  Revoke return
                </Button>
              </Stack.Item>
            </Stack>
            <Input
              mt={1}
              value={positions}
              onChange={setPositions}
              placeholder="Active positions (1–12)"
            />
            <Button
              onClick={() => act('resident_limit', { amount: positions })}
            >
              Set resident positions
            </Button>
            <Button.Confirm
              color="bad"
              onClick={() => act('reset_resident_access')}
            >
              Reset all saved return access
            </Button.Confirm>
            <Box>
              Invited: {Object.keys(data.resident_invites).join(', ') || 'None'}
            </Box>
            {data.resident_blocked.map((key) => (
              <Box key={key}>
                {key}{' '}
                <Button onClick={() => act('unblock_resident', { ckey: key })}>
                  Unblock
                </Button>
              </Box>
            ))}
            {data.candidates.map((person) => (
              <Box key={person.ref}>
                {person.name}{' '}
                <Button
                  onClick={() => act('add_resident', { ref: person.ref })}
                >
                  Add current character as resident
                </Button>
              </Box>
            ))}
          </>
        )}
        {data.residents.map((person) => (
          <Box key={person.ref} mt={1}>
            {person.name} ({person.active ? 'active' : 'away'})
            {!!data.is_owner && (
              <>
                <Button
                  selected={!!person.steward}
                  onClick={() =>
                    act('delegate', { ref: person.ref, role: 'steward' })
                  }
                >
                  Management
                </Button>
                <Button
                  selected={!!person.treasurer}
                  onClick={() =>
                    act('delegate', { ref: person.ref, role: 'treasurer' })
                  }
                >
                  Treasury
                </Button>
              </>
            )}
            {!!data.can_manage && (
              <Button
                onClick={() => act('remove_resident', { ref: person.ref })}
              >
                Remove character membership
              </Button>
            )}
          </Box>
        ))}
      </Section>
      <Section title="Research Pairing">
        <NoticeBox>
          Build a physical R&D server, insert a server disk, then use a
          multitool to link local consoles, scanners and fabrication machines.
          Link fabrication to the local silo separately. Points, incomplete work
          and materials remain local.
        </NoticeBox>
        <Button
          disabled={!data.can_manage}
          onClick={() => act('pair_research')}
        >
          Pair with a docked ship
        </Button>
        <Box color="label">
          The ship captain approves at its server with a secondary multitool
          click. Completed records synchronize while docked; each disk retains
          its own copy after departure.
        </Box>
        {data.research_pairs.map((pair) => (
          <Box key={pair.ref} mt={1}>
            <Box bold>{pair.name}</Box>
            <Box>{pair.status}</Box>
            <Box>Last successful sync: {pair.last_success || 'Never'}</Box>
            <Button
              disabled={!data.can_manage}
              onClick={() => act('revoke_pair', { ref: pair.ref })}
            >
              Revoke pairing
            </Button>
          </Box>
        ))}
      </Section>
    </>
  );
};
