import {
  Box,
  Button,
  Icon,
  LabeledList,
  NoticeBox,
  Section,
  Stack,
  Table,
} from 'tgui-core/components';
import type { BooleanLike } from 'tgui-core/react';

import { useBackend } from '../backend';
import { Window } from '../layouts';

type OutpostSummary = {
  ref: string;
  name: string;
  owner: string;
  coords: string;
  loaded: BooleanLike;
};

type Resident = {
  ref: string;
  name: string;
  is_self: BooleanLike;
  steward: BooleanLike;
  treasurer: BooleanLike;
};

type SelectedOutpost = {
  ref: string;
  name: string;
  owner: string;
  coords: string;
  shell: string;
  balance: number;
  dock_mode: 'open' | 'request' | 'lockdown';
  resident_mode: 'open' | 'password' | 'approved' | 'closed';
  resident_active: number;
  freight_state: string;
  freight_error: string;
  research_pairs: number;
  residents: Resident[];
};

export type Data = {
  outposts: OutpostSummary[];
  selected: SelectedOutpost | null;
  busy: BooleanLike;
  error: string | null;
};

const dockModes: SelectedOutpost['dock_mode'][] = [
  'open',
  'request',
  'lockdown',
];

const residentModes: SelectedOutpost['resident_mode'][] = [
  'open',
  'password',
  'approved',
  'closed',
];

const modeLabel = (mode: string) =>
  mode.charAt(0).toUpperCase() + mode.slice(1);

export const OutpostManipulator = () => {
  const { act, data } = useBackend<Data>();

  return (
    <Window title="Outpost Manipulator" theme="admin" width={920} height={640}>
      <Window.Content fitted>
        <OutpostManipulatorPanel data={data} act={act} />
      </Window.Content>
    </Window>
  );
};

type OutpostManipulatorPanelProps = {
  data: Data;
  act: (action: string, params?: unknown) => void;
};

export const OutpostManipulatorPanel = ({
  data,
  act,
}: OutpostManipulatorPanelProps) => {
  const { outposts, selected, busy, error } = data;
  const isBusy = !!busy;

  return (
    <Stack fill>
      <Stack.Item width="31%">
        <Section title="Player Outposts" fill scrollable>
          <Button
            fluid
            icon="plus"
            color="good"
            disabled={isBusy}
            onClick={() => act('create')}
          >
            Create Outpost
          </Button>
          <Box mt={1}>
            {outposts.length ? (
              <Stack vertical>
                {outposts.map((outpost) => (
                  <Stack.Item key={outpost.ref}>
                    <Button
                      fluid
                      selected={outpost.ref === selected?.ref}
                      disabled={isBusy}
                      onClick={() => act('select', { ref: outpost.ref })}
                    >
                      <Stack align="center">
                        <Stack.Item grow>
                          <Box bold>{outpost.name}</Box>
                          <Box color="label" fontSize="11px">
                            {outpost.owner || 'Unclaimed'}
                          </Box>
                        </Stack.Item>
                        <Stack.Item>
                          <Icon
                            name={outpost.loaded ? 'circle-check' : 'circle'}
                            color={outpost.loaded ? 'good' : 'label'}
                          />
                        </Stack.Item>
                      </Stack>
                    </Button>
                  </Stack.Item>
                ))}
              </Stack>
            ) : (
              <NoticeBox info>No player outposts found.</NoticeBox>
            )}
          </Box>
        </Section>
      </Stack.Item>

      <Stack.Item grow overflowY="auto">
        {error ? <NoticeBox danger>{error}</NoticeBox> : null}
        {selected ? (
          <OutpostDetails selected={selected} busy={isBusy} act={act} />
        ) : (
          <Section title="Registry" fill>
            <NoticeBox info>
              Select an outpost to inspect or manipulate it.
            </NoticeBox>
          </Section>
        )}
      </Stack.Item>
    </Stack>
  );
};

type DetailsProps = {
  selected: SelectedOutpost;
  busy: boolean;
  act: (action: string, params?: unknown) => void;
};

const OutpostDetails = ({ selected, busy, act }: DetailsProps) => {
  const mutate = (action: string, params?: unknown) => {
    if (!busy) {
      act(action, params);
    }
  };

  return (
    <Stack vertical fill>
      <Stack.Item>
        <Section title={selected.name}>
          <LabeledList>
            <LabeledList.Item label="Owner">
              {selected.owner || 'Unclaimed'}
            </LabeledList.Item>
            <LabeledList.Item label="Coordinates">
              {selected.coords}
            </LabeledList.Item>
            <LabeledList.Item label="Shell">{selected.shell}</LabeledList.Item>
            <LabeledList.Item label="Balance">
              {selected.balance.toLocaleString()} cr
            </LabeledList.Item>
          </LabeledList>
        </Section>
      </Stack.Item>

      <Stack.Item>
        <Section title="Navigation and Identity">
          <Stack wrap>
            <Button
              icon="location-crosshairs"
              disabled={busy}
              onClick={() => act('jump')}
            >
              Jump to Outpost
            </Button>
            <Button
              icon="globe"
              disabled={busy}
              onClick={() => act('jump_overmap')}
            >
              Jump Overmap
            </Button>
            <Button icon="code" disabled={busy} onClick={() => act('vv')}>
              View Variables
            </Button>
            <Button icon="pen" disabled={busy} onClick={() => mutate('rename')}>
              Rename
            </Button>
            <Button
              icon="user-gear"
              disabled={busy}
              onClick={() => mutate('owner')}
            >
              Set Owner
            </Button>
            <Button
              icon="coins"
              disabled={busy}
              onClick={() => mutate('balance')}
            >
              Adjust Balance
            </Button>
            <Button
              icon="person-circle-minus"
              color="caution"
              disabled={busy}
              onClick={() => mutate('abandon')}
            >
              Abandon
            </Button>
            <Button
              icon="trash"
              color="bad"
              disabled={busy}
              onClick={() => mutate('delete')}
            >
              Delete
            </Button>
          </Stack>
        </Section>
      </Stack.Item>

      <Stack.Item>
        <Section title="Services">
          <Stack vertical>
            <Stack.Item>
              <Stack align="center" wrap>
                <Stack.Item width="90px" bold>
                  Docking
                </Stack.Item>
                {dockModes.map((mode) => (
                  <Button
                    key={mode}
                    selected={selected.dock_mode === mode}
                    disabled={busy}
                    onClick={() => mutate('dock_mode', { mode })}
                  >
                    {modeLabel(mode)}
                  </Button>
                ))}
              </Stack>
            </Stack.Item>
            <Stack.Item>
              <Stack align="center" wrap>
                <Stack.Item width="90px" bold>
                  Residents
                </Stack.Item>
                {residentModes.map((mode) => (
                  <Button
                    key={mode}
                    selected={selected.resident_mode === mode}
                    disabled={busy}
                    onClick={() => mutate('resident_mode', { mode })}
                  >
                    {modeLabel(mode)}
                  </Button>
                ))}
                <Box color="label">
                  {selected.resident_active} active residents
                </Box>
              </Stack>
            </Stack.Item>
            <Stack.Item>
              <Stack wrap>
                <Button
                  icon="key"
                  disabled={busy}
                  onClick={() => mutate('resident_password')}
                >
                  Set Resident Password
                </Button>
                <Button
                  icon="user-slash"
                  disabled={busy}
                  onClick={() => mutate('reset_resident_access')}
                >
                  Reset Resident Access
                </Button>
                <Button
                  icon="link"
                  disabled={busy}
                  onClick={() => mutate('relink')}
                >
                  Relink Services
                </Button>
                <Button
                  icon="flask"
                  color="caution"
                  disabled={busy}
                  onClick={() => mutate('revoke_research')}
                >
                  Revoke Research
                </Button>
              </Stack>
            </Stack.Item>
            <Stack.Item>
              <Box color={selected.freight_error ? 'bad' : 'good'}>
                Freight: {selected.freight_state}
                {selected.freight_error ? ` - ${selected.freight_error}` : null}
              </Box>
              <Box color="label">
                Research pairings: {selected.research_pairs}
              </Box>
            </Stack.Item>
          </Stack>
        </Section>
      </Stack.Item>

      <Stack.Item grow>
        <Section title="Residents" fill scrollable>
          <Stack align="center" mb={1}>
            <Stack.Item grow>
              <Box color="label">
                {selected.resident_active} active residents
              </Box>
            </Stack.Item>
            <Stack.Item>
              <Button
                icon="user-plus"
                disabled={busy}
                onClick={() => mutate('add_resident')}
              >
                Add Resident
              </Button>
            </Stack.Item>
          </Stack>
          {selected.residents.length ? (
            <Table>
              <Table.Row header>
                <Table.Cell>Name</Table.Cell>
                <Table.Cell>Roles</Table.Cell>
                <Table.Cell collapsing>Actions</Table.Cell>
              </Table.Row>
              {selected.residents.map((resident) => (
                <Table.Row key={resident.ref}>
                  <Table.Cell>{resident.name}</Table.Cell>
                  <Table.Cell>
                    {!!resident.steward && (
                      <Box inline color="good">
                        Steward
                      </Box>
                    )}
                    {!!resident.treasurer && (
                      <Box inline color="yellow" ml={1}>
                        Treasurer
                      </Box>
                    )}
                    {!resident.steward && !resident.treasurer ? (
                      <Box color="label">Resident</Box>
                    ) : null}
                  </Table.Cell>
                  <Table.Cell collapsing>
                    <Button
                      compact
                      icon="user-shield"
                      disabled={busy}
                      onClick={() =>
                        mutate('delegate', {
                          ref: resident.ref,
                          role: 'steward',
                        })
                      }
                    >
                      {resident.steward ? 'Unmake Steward' : 'Steward'}
                    </Button>
                    <Button
                      compact
                      icon="coins"
                      disabled={busy}
                      onClick={() =>
                        mutate('delegate', {
                          ref: resident.ref,
                          role: 'treasurer',
                        })
                      }
                    >
                      {resident.treasurer ? 'Unmake Treasurer' : 'Treasurer'}
                    </Button>
                    <Button
                      compact
                      color="bad"
                      icon="user-minus"
                      disabled={busy || !!resident.is_self}
                      tooltip={
                        resident.is_self
                          ? 'You cannot remove yourself'
                          : undefined
                      }
                      onClick={() =>
                        mutate('remove_resident', { ref: resident.ref })
                      }
                    >
                      Remove
                    </Button>
                  </Table.Cell>
                </Table.Row>
              ))}
            </Table>
          ) : (
            <NoticeBox info>No residents are registered.</NoticeBox>
          )}
        </Section>
      </Stack.Item>
    </Stack>
  );
};
