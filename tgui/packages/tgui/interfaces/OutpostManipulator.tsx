import { useState } from 'react';
import {
  Box,
  Button,
  Dropdown,
  Icon,
  LabeledList,
  NoticeBox,
  NumberInput,
  ProgressBar,
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
  pricer?: BooleanLike;
};

/** One service room's admin rows (admin_ui_data()); a row with an action gets a button. */
type ServiceAdminRoom = {
  id: string;
  name: string;
  rows?: { label: string; action: string | null; ref: string | null }[] | null;
};

type ShipBayData = {
  installed: BooleanLike;
  capacity: number;
  install_denial: string | null;
  remove_denial: string | null;
  saved_checkpoints: number;
  silo: string | null;
  silos: { ref: string; name: string }[];
  slots: {
    number: number;
    ref: string | null;
    status: string;
    ship?: string;
    can_jump?: BooleanLike;
    silo?: string | null;
    requested?: BooleanLike;
    approved?: BooleanLike;
    owner_crew?: BooleanLike;
    grant_denial?: string | null;
    can_remove_ship?: BooleanLike;
  }[];
};

type CheckpointAdminData = {
  enabled: BooleanLike;
  docked: string | null;
  checkpoints: {
    ref: string;
    name: string;
    owner: string;
    size: string;
    original: string;
    rebuild_denial: string | null;
  }[];
  rebuilds: {
    ref: string;
    name: string;
    owner: string;
    status: string;
    progress: number;
    can_rush: BooleanLike;
  }[];
};

type PrisonAdminPrisoner = {
  ref: string;
  name: string;
  cell: number;
  personality: string;
  crime: string;
  activity: string;
  /** 0-100 each; hunger is how fed they are, 100 = full */
  hunger: number;
  grime: number;
  health: number;
  care: number;
  /** 0-1: care between no pay and full pay */
  grade?: number;
  /** 0-1: the share of full pay they earn now */
  pay_factor?: number;
  /** 0-100 */
  mood: number;
  state: PrisonerState;
  /** seconds until an escaped prisoner is gone for good, null when not loose */
  loose_left: number | null;
  /** seconds */
  sentence_left: number;
  dead: BooleanLike;
  /** seconds on the confinement clock */
  confined_seconds?: number;
  /** shut in their cell right now */
  confined?: BooleanLike;
  /** handcuffed */
  cuffed?: BooleanLike;
  /** seconds of lockdown still owed after a riot, 0 when none */
  lockdown_left?: number;
};

type PrisonerState =
  | 'normal'
  | 'fighting'
  | 'beaten'
  | 'rioting'
  | 'loose'
  | 'wreck';

type PrisonStage = 'calm' | 'grumbling' | 'restless' | 'riot';

type CrewMode = 'auto' | 'home' | 'away';

/** The warden console's experiment block, the same for admins */
type PrisonExperiment = {
  /** unknown (a blind serum not yet shown), hulk, fly, nightmare or changeling */
  form: string;
  /** offered, dosed, twitching, incubating, live, vents, horror, contained or failed */
  stage: string;
  subject: string | null;
  /** seconds */
  time_left: number | null;
  researcher_present: BooleanLike;
  fee_paid: number;
  bonus_paid: number;
  /** up or regenerating while the changeling's horror is out, else null */
  horror?: string | null;
  /** subdued or down while a creature that was put down waits for Kessler, else null */
  pickup?: string | null;
};

type PrisonAdminData = {
  intake_open: BooleanLike;
  /** open, closed, suspended, debt, experiment or no_power */
  intake_state?: string;
  /** seconds, null when nothing is scheduled */
  next_arrival: number | null;
  /** cr/min */
  pay_rate: number;
  paid_total: number;
  powered: BooleanLike;
  /** 0-100 each */
  conditions: { clean: number; lit: number; powered: number; score: number };
  cells: { number: number; occupant_ref: string | null }[];
  prisoners: PrisonAdminPrisoner[];
  /** 0-100 */
  tension: number;
  stage: PrisonStage;
  /** seconds until an unresolved riot becomes a breakout, null when none */
  breakout_in: number | null;
  // Everything below may be missing from an older payload; its row is then hidden.
  crew_home?: BooleanLike;
  crew_mode?: CrewMode;
  riot_active?: BooleanLike;
  /** seconds of riot with the crew home */
  riot_elapsed?: number;
  /** seconds of riot with nobody home, null before it is tracked */
  riot_absent?: number | null;
  /** seconds, null when not subdued */
  subdued_left?: number | null;
  /** credits fined in the current incident */
  incident_fined?: number | null;
  /** prisoners lost in the last 30 minutes */
  lost_recent?: number | null;
  /** treasury debt */
  debt?: number;
  hatch?: {
    meals: number;
    clean_suits: number;
    dirty_suits: number;
    capacity: number;
    lasts_minutes: number | null;
  };
  /** weighted mess load */
  mess_units?: number | null;
  /** floor tiles the mess score divides by */
  floor_size?: number | null;
  /** tiles the light score sampled */
  lit_samples?: number | null;
  /** seconds of outage counted against power */
  outage_debt?: number;
  extras?: PrisonAdminExtras | null;
  /** null with no experiment */
  experiment?: PrisonExperiment | null;
  incidents?: PrisonIncidents | null;
};

/** Wildcard incidents and wing events (outpost_prison_incidents.dm, outpost_prison_wing_events.dm) */
type PrisonIncidents = {
  /** percent per minute at the wing's tension now */
  chance: number;
  /** seconds of crew-home time before the next roll can come */
  gap_left: number;
  /** why the clock is not rolling, null when it is */
  paused: string | null;
  /** stab or snap while one is under way */
  running: string | null;
  actor: string | null;
  target: string | null;
  /** seconds of tell left, null past the tell */
  tell_left: number | null;
  /** seconds of crew-home time before the next wing event, null before the first tick */
  wing_event_in: number | null;
  /** why the wing event clock is not running, null when it is */
  wing_event_paused: string | null;
  /** scrubber or toilet while one gurgles */
  wing_event_pending: string | null;
};

type AdminGuard = {
  ref: string;
  name: string;
  health: number;
  status: string;
  activity: string;
  response: string;
};

type AdminRep = { key: string; name: string; score: number; label: string };

type AdminLife = {
  pairs: {
    a_ref: string;
    b_ref: string;
    a_name: string;
    b_name: string;
    affinity: number;
  }[];
  birthdays: string[];
  scene: string | null;
};

type AdminContraband = {
  cells: { number: number; shiv: BooleanLike; pruno: string }[];
  drunk: string[];
  carrying: string[];
};

type AdminMail = {
  letters: {
    ref: string;
    to_ref: string;
    to_name: string;
    kind: string;
    opened: BooleanLike;
    contraband: BooleanLike;
    /** seconds */
    age: number;
  }[];
  /** seconds until the next mail pod, null when the clock is stopped */
  next_in: number | null;
};

type AdminLeads = {
  /** seconds until the wing can give a lead, null when ready */
  ready_in: number | null;
  carriers: string[];
  open: {
    teller: string;
    ship: string;
    name: string;
    lie: BooleanLike;
    exposed: BooleanLike;
    /** seconds */
    age: number;
  }[];
};

/** One record waiting in the bounty prisoner pool (outpost_prison_bounty.dm) */
type AdminBountyRecord = {
  id: string;
  name: string;
  /** "Petty", "Wanted" or "Most Wanted" */
  tier: string;
  level: number;
  archetype: string | null;
  /** seconds in the pool, and until it leaves it */
  age: number;
  left: number;
  /** the outpost whose wing it is still reserved for, if any */
  reserved_for: string | null;
  /** reserved for this wing */
  ours: BooleanLike;
  /** the outpost whose wing it is named to as the next bounty arrival, if any */
  named_to: string | null;
  /** this wing would take it now */
  accepts: BooleanLike;
};

type AdminBounty = {
  /** the warden's bounty transfer setting */
  setting: string;
  count: number;
  max: number;
  most_wanted: number;
  lanes: number;
  next: { id: string; name: string; tier: string } | null;
  pool: AdminBountyRecord[];
};

/**
 * The extras packages' blocks (outpost_prison_extras.dm). Each is an empty list until its
 * package lands; the object-shaped ones render nothing until then.
 */
type PrisonAdminExtras = {
  guards?: AdminGuard[];
  social?: AdminRep[];
  life?: AdminLife | [];
  contraband?: AdminContraband | [];
  mail?: AdminMail | [];
  leads?: AdminLeads | [];
  bounty?: AdminBounty | [];
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
  research_connection: string;
  residents: Resident[];
  ship_bays: ShipBayData;
  checkpoints: CheckpointAdminData;
  /** Ckey billed as a visitor here, or null. */
  playtest_visitor?: string | null;
  services?: ServiceAdminRoom[] | null;
  /** null when the outpost has no prison */
  prison?: PrisonAdminData | null;
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

/** "release_locker" -> "Release locker". */
const actionLabel = (action: string) => modeLabel(action.replace(/_/g, ' '));

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
    <Stack vertical>
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
              icon="user-secret"
              selected={!!selected.playtest_visitor}
              disabled={busy}
              tooltip="Bill yourself as a visitor here: services charge you and staff doors stay shut. Management rights are unchanged."
              onClick={() => mutate('playtest_visitor')}
            >
              {selected.playtest_visitor
                ? 'Stop Visitor Billing'
                : 'Bill Me as a Visitor'}
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
          {selected.playtest_visitor ? (
            <NoticeBox mt={1}>
              Billing {selected.playtest_visitor} as a visitor.
            </NoticeBox>
          ) : null}
        </Section>
      </Stack.Item>

      <Stack.Item>
        <ShipBays data={selected.ship_bays} busy={busy} act={mutate} />
      </Stack.Item>

      <Stack.Item>
        <ServiceRooms rooms={selected.services} busy={busy} act={mutate} />
      </Stack.Item>

      {!!selected.checkpoints?.enabled && (
        <Stack.Item>
          <CheckpointTools
            data={selected.checkpoints}
            busy={busy}
            act={mutate}
          />
        </Stack.Item>
      )}

      <Stack.Item>
        {selected.prison ? (
          <PrisonTools data={selected.prison} busy={busy} act={mutate} />
        ) : (
          <Section title="Prison">
            <Box color="label">No prison</Box>
          </Section>
        )}
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
                Research connections: {selected.research_connection}
              </Box>
            </Stack.Item>
          </Stack>
        </Section>
      </Stack.Item>

      <Stack.Item>
        <Section title="Residents">
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
                    {!!resident.pricer && (
                      <Box inline color="teal" ml={1}>
                        Pricer
                      </Box>
                    )}
                    {!resident.steward &&
                    !resident.treasurer &&
                    !resident.pricer ? (
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
                      icon="tags"
                      disabled={busy}
                      tooltip="Pricing: sets service prices and takes shop stock free"
                      onClick={() =>
                        mutate('delegate', {
                          ref: resident.ref,
                          role: 'pricer',
                        })
                      }
                    >
                      {resident.pricer ? 'Unmake Pricer' : 'Pricer'}
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

const ServiceRooms = ({
  rooms,
  busy,
  act,
}: {
  rooms?: ServiceAdminRoom[] | null;
  busy: boolean;
  act: DetailsProps['act'];
}) => (
  <Section title="Service Rooms">
    {!rooms?.length ? (
      <Box color="label">No service rooms installed.</Box>
    ) : (
      rooms.map((room) => (
        <Box key={room.id} mb={1}>
          <Box bold mb={0.5}>
            {room.name || room.id}
          </Box>
          {!room.rows?.length ? (
            <Box color="label">Nothing to manage.</Box>
          ) : (
            <Table>
              {room.rows.map((row, index) => (
                <Table.Row key={`${row.ref ?? ''}:${row.label}:${index}`}>
                  <Table.Cell style={{ overflowWrap: 'anywhere' }}>
                    {row.label}
                  </Table.Cell>
                  <Table.Cell collapsing>
                    {row.action ? (
                      <Button
                        compact
                        disabled={busy}
                        onClick={() =>
                          act('service_admin', {
                            id: room.id,
                            service_action: row.action,
                            ref: row.ref,
                          })
                        }
                      >
                        {actionLabel(row.action)}
                      </Button>
                    ) : null}
                  </Table.Cell>
                </Table.Row>
              ))}
            </Table>
          )}
        </Box>
      ))
    )}
  </Section>
);

const ShipBays = ({
  data,
  busy,
  act,
}: {
  data: ShipBayData;
  busy: boolean;
  act: DetailsProps['act'];
}) => (
  <Section
    title="Ship Bay"
    buttons={
      data.installed ? (
        <Button
          icon="trash"
          color="bad"
          disabled={busy || !!data.remove_denial}
          tooltip={data.remove_denial}
          onClick={() => act('remove_bays')}
        >
          Remove Upgrade
        </Button>
      ) : (
        <Button
          icon="plus"
          color="good"
          disabled={busy || !!data.install_denial}
          tooltip={data.install_denial}
          onClick={() => act('install_bays')}
        >
          Install Bay (Free)
        </Button>
      )
    }
  >
    <Box mb={1}>
      {data.installed ? 'One permanent bay installed' : 'Not installed'}
      {' / '}
      {data.saved_checkpoints} saved checkpoints
    </Box>
    <Box color="label" mb={1}>
      The bay stays loaded between visits.
    </Box>
    {!!(data.installed ? data.remove_denial : data.install_denial) && (
      <Box color="label" mb={1}>
        {data.installed ? data.remove_denial : data.install_denial}
      </Box>
    )}
    <LabeledList>
      <LabeledList.Item label="Outpost silo">
        <Dropdown
          width="100%"
          disabled={busy || data.silos.length === 0}
          selected={data.silo || ''}
          placeholder="No outpost silo selected"
          options={data.silos.map((silo) => ({
            value: silo.ref,
            displayText: silo.name,
          }))}
          onSelected={(ref) => act('bay_select_silo', { ref })}
        />
      </LabeledList.Item>
    </LabeledList>
    {data.slots.map((bay) => (
      <Box key={bay.number} mt={2}>
        <Box bold mb={0.5} style={{ overflowWrap: 'anywhere' }}>
          Bay {bay.number}: {bay.ship || bay.status}
        </Box>
        {!!bay.ref && (
          <>
            <Box color="label" mb={1}>
              {bay.status} / {bay.silo || 'No linked materials'}
              {bay.owner_crew
                ? ' / Owner crew access'
                : bay.approved
                  ? ' / Outpost materials approved'
                  : bay.requested
                    ? ' / Materials requested'
                    : ''}
            </Box>
            <Stack wrap>
              <Button
                icon="location-crosshairs"
                disabled={busy || !bay.can_jump}
                onClick={() => act('bay_jump', { ref: bay.ref })}
              >
                Jump
              </Button>
              <Button
                icon="code"
                disabled={busy}
                onClick={() => act('bay_vv', { ref: bay.ref })}
              >
                Inspect Bay
              </Button>
              <Button
                icon="boxes-stacked"
                disabled={busy || !!bay.grant_denial || !!bay.approved}
                tooltip={bay.grant_denial}
                onClick={() => act('bay_grant_materials', { ref: bay.ref })}
              >
                Grant Materials
              </Button>
              <Button
                icon="ban"
                disabled={busy || (!bay.approved && !bay.requested)}
                onClick={() => act('bay_revoke_materials', { ref: bay.ref })}
              >
                Revoke Materials
              </Button>
              <Button
                icon="trash"
                color="bad"
                disabled={busy || !bay.can_remove_ship}
                tooltip="Delete the docked ship. Living people aboard move to the bay elevator."
                onClick={() => act('bay_remove_ship', { ref: bay.ref })}
              >
                Remove Ship
              </Button>
            </Stack>
          </>
        )}
      </Box>
    ))}
  </Section>
);

const CheckpointTools = ({
  data,
  busy,
  act,
}: {
  data: CheckpointAdminData;
  busy: boolean;
  act: DetailsProps['act'];
}) => (
  <Section title="Checkpoints (Admin)">
    <Box color="label" mb={1}>
      Free. No fees, captain rules or materials.
    </Box>
    <Stack wrap mb={1}>
      <Button
        icon="floppy-disk"
        disabled={busy}
        onClick={() => act('checkpoint_save')}
      >
        Save Checkpoint
      </Button>
      <Button
        icon="rotate"
        disabled={busy || !data.docked}
        tooltip={
          data.docked
            ? `Save ${data.docked}, delete it and rebuild it`
            : 'No ship is docked in the bay'
        }
        onClick={() => act('checkpoint_rebuild_docked')}
      >
        Rebuild Docked Ship
      </Button>
      <Button
        icon="ship"
        disabled={busy}
        tooltip="Build a new ship from the shipyard catalog for you"
        onClick={() => act('checkpoint_order_free')}
      >
        Build Ship (Free)
      </Button>
    </Stack>
    {data.rebuilds.map((rebuild) => (
      <Box key={rebuild.ref} mb={1}>
        <Box bold style={{ overflowWrap: 'anywhere' }}>
          {rebuild.name}
        </Box>
        <Box color="label">
          {rebuild.status} / {rebuild.owner}
        </Box>
        <ProgressBar value={rebuild.progress / 100} my={0.5}>
          {rebuild.progress}%
        </ProgressBar>
        <Stack wrap>
          <Button
            icon="forward-fast"
            disabled={busy || !rebuild.can_rush}
            onClick={() => act('rebuild_rush', { ref: rebuild.ref })}
          >
            Finish Now
          </Button>
          <Button
            icon="stop"
            color="bad"
            disabled={busy}
            onClick={() => act('rebuild_stop', { ref: rebuild.ref })}
          >
            Stop
          </Button>
        </Stack>
      </Box>
    ))}
    {data.checkpoints.length === 0 ? (
      <Box color="label">No saved checkpoints.</Box>
    ) : (
      <Table>
        <Table.Row header>
          <Table.Cell>Ship</Table.Cell>
          <Table.Cell>Owner</Table.Cell>
          <Table.Cell>Original</Table.Cell>
          <Table.Cell collapsing>Actions</Table.Cell>
        </Table.Row>
        {data.checkpoints.map((checkpoint) => (
          <Table.Row key={checkpoint.ref}>
            <Table.Cell style={{ overflowWrap: 'anywhere' }}>
              {checkpoint.name}
              <Box color="label" fontSize="11px">
                {checkpoint.size}
              </Box>
            </Table.Cell>
            <Table.Cell>{checkpoint.owner}</Table.Cell>
            <Table.Cell>{checkpoint.original}</Table.Cell>
            <Table.Cell collapsing>
              <Button
                compact
                icon="ship"
                disabled={busy || !!checkpoint.rebuild_denial}
                tooltip={
                  checkpoint.rebuild_denial ||
                  (checkpoint.original === 'In service'
                    ? 'Builds an extra copy; the original is left alone'
                    : undefined)
                }
                onClick={() =>
                  act('checkpoint_rebuild', { ref: checkpoint.ref })
                }
              >
                Rebuild
              </Button>
              <Button
                compact
                icon="trash"
                color="bad"
                disabled={busy}
                onClick={() =>
                  act('checkpoint_delete', { ref: checkpoint.ref })
                }
              >
                Delete
              </Button>
            </Table.Cell>
          </Table.Row>
        ))}
      </Table>
    )}
  </Section>
);

/** m:ss */
const clock = (seconds: number) => {
  const total = Math.max(0, Math.ceil(seconds || 0));
  return `${Math.floor(total / 60)}:${String(total % 60).padStart(2, '0')}`;
};

const conditionColor = (value: number) =>
  value >= 80 ? 'good' : value >= 50 ? 'average' : 'bad';

type PrisonStat = {
  field: 'hunger' | 'grime' | 'health' | 'mood';
  label: string;
  presets: number[];
  color: (value: number) => string;
};

// Colours follow the PRISONER_* thresholds in voidcrew/_DEFINES/outpost_prison_*.dm.
const PRISON_STATS: PrisonStat[] = [
  {
    field: 'hunger',
    label: 'Fed',
    presets: [0, 30, 100],
    // Hungry below 40, starving below 15.
    color: (value) => (value < 15 ? 'bad' : value < 40 ? 'average' : 'good'),
  },
  {
    field: 'grime',
    label: 'Grime',
    presets: [0, 60, 100],
    // Dirty at 50, filthy at 80.
    color: (value) => (value >= 80 ? 'bad' : value >= 50 ? 'average' : 'good'),
  },
  {
    field: 'health',
    label: 'Health',
    presets: [20, 60, 100],
    // Injured below 90.
    color: (value) => (value < 50 ? 'bad' : value < 90 ? 'average' : 'good'),
  },
  {
    field: 'mood',
    label: 'Mood',
    // 10 attacks staff and fights, 40 only climbs out of an open hatch, 70 is the start value.
    presets: [10, 40, 70],
    // Attacks staff below 35, escapes below 50.
    color: (value) => (value < 35 ? 'bad' : value < 50 ? 'average' : 'good'),
  },
];

/** Seconds. 30 s starts the walk back to the cell. */
const SENTENCE_PRESETS = [30, 300, 900];

const PRISON_ALL = [
  ['starve', 'Starve'],
  ['feed', 'Feed'],
  ['dirty', 'Dirty'],
  ['clean', 'Clean'],
  ['hurt', 'Hurt'],
  ['heal', 'Heal'],
  ['enrage', 'Enrage'],
  ['calm', 'Calm'],
] as const;

const PRISON_STAGES: Record<PrisonStage, { label: string; color: string }> = {
  calm: { label: 'Calm', color: 'good' },
  grumbling: { label: 'Grumbling', color: 'average' },
  restless: { label: 'Restless', color: 'orange' },
  riot: { label: 'Riot', color: 'bad' },
};

/** Normal prisoners get no badge. */
const PRISONER_STATES: Partial<
  Record<PrisonerState, { label: string; icon: string; color: string }>
> = {
  fighting: { label: 'Fighting', icon: 'hand-back-fist', color: 'orange' },
  beaten: { label: 'Beaten', icon: 'user-injured', color: 'average' },
  rioting: { label: 'Rioting', icon: 'hand-fist', color: 'bad' },
  loose: { label: 'Loose', icon: 'person-running', color: 'bad' },
  wreck: { label: 'Wrecking', icon: 'hammer', color: 'bad' },
};

/** Stage thresholds: calm below 40, riot at 75 (PRISON_TENSION_RIOT). */
const tensionColor = (value: number) =>
  value >= 75 ? 'bad' : value >= 40 ? 'average' : 'good';

/** Minutes */
const PRISON_ADVANCE = [1, 5, 10];

const CREW_MODES: [CrewMode, string][] = [
  ['auto', 'Auto'],
  ['home', 'Home'],
  ['away', 'Away'],
];

/** Credits */
const DEBT_PRESETS = [0, 1000, 5000];

/** Seconds: none, past the 30 s grace, the whole ramp */
const OUTAGE_PRESETS = [0, 60, 120];

/** Seconds: none, pay stops at 2 min, wrecking at 6 min */
const CONFINED_PRESETS = [0, 120, 360];

/** PRISON_SUBDUED_TIME */
const SUBDUE_SECONDS = 360;

/** prison_experiment forms */
const EXPERIMENT_FORMS = [
  ['hulk', 'Hulk'],
  ['fly', 'Fly'],
  ['nightmare', 'Nightmare'],
  ['changeling', 'Changeling'],
] as const;

type ExperimentForm = (typeof EXPERIMENT_FORMS)[number][0];

/** prison_changeling_stage stages */
const CHANGELING_STAGES = [
  ['burst', 'Burst', 'burst'],
  ['horror', 'Horror', 'skull-crossbones'],
] as const;

/** prison_incident kinds */
const INCIDENT_KINDS = [
  ['stab', 'Stabbing', 'skull-crossbones'],
  ['snap', 'Snap', 'hand-fist'],
  ['fight', 'Fight', 'hand-back-fist'],
] as const;

/** prison_wing_event kinds */
const WING_EVENTS = [
  ['lights', 'Blow Lights', 'lightbulb'],
  ['scrubber', 'Scrubber Overflow', 'wind'],
  ['toilet', 'Toilet Flood', 'toilet'],
] as const;

const isNum = (value: unknown): value is number =>
  typeof value === 'number' && Number.isFinite(value);

const cr = (value: number) => `${Math.floor(value || 0).toLocaleString()} cr`;

type PrisonProps = {
  data: PrisonAdminData;
  busy: boolean;
  act: DetailsProps['act'];
};

/** The wildcard incidents and wing events rows: buttons that skip the clocks, and the clocks */
const PrisonIncidentTools = ({ data, busy, act }: PrisonProps) => {
  // Whether the Stabbing and Snap buttons play their tell first
  const [withTell, setWithTell] = useState(false);
  const incidents = data.incidents || null;
  if (!incidents) {
    return null;
  }
  const clockParts = [
    `${incidents.chance}%/min`,
    incidents.paused ? `paused: ${incidents.paused}` : 'rolling',
    incidents.gap_left > 0 ? `gap ${clock(incidents.gap_left)}` : '',
  ].filter(Boolean);
  const running = incidents.running
    ? [
        incidents.running === 'stab'
          ? `${incidents.actor || '?'} is after ${incidents.target || '?'}`
          : `${incidents.actor || '?'} is about to snap`,
        isNum(incidents.tell_left)
          ? `tell ${clock(incidents.tell_left)}`
          : 'attacking',
      ].join(', ')
    : '';
  const wingParts = [
    incidents.wing_event_pending
      ? `${incidents.wing_event_pending} gurgling`
      : isNum(incidents.wing_event_in)
        ? `next in ${clock(incidents.wing_event_in)}`
        : '',
    incidents.wing_event_paused ? `paused: ${incidents.wing_event_paused}` : '',
  ].filter(Boolean);

  return (
    <>
      <Stack
        className="OutpostPrisonAdmin__incidents"
        align="center"
        wrap
        mb={1}
      >
        <Stack.Item width="90px" bold>
          Incidents
        </Stack.Item>
        {INCIDENT_KINDS.map(([kind, label, icon]) => (
          <Button
            key={kind}
            icon={icon}
            disabled={busy || !!incidents.running}
            tooltip={
              kind === 'fight'
                ? 'Starts with the argument'
                : withTell
                  ? 'After its tell'
                  : 'Skips the tell'
            }
            onClick={() =>
              act('prison_incident', { kind, tell: withTell ? 1 : 0 })
            }
          >
            {label}
          </Button>
        ))}
        <Button.Checkbox
          checked={withTell}
          disabled={busy}
          onClick={() => setWithTell(!withTell)}
        >
          Tell first
        </Button.Checkbox>
        <Stack.Item ml={1} color="label">
          {clockParts.join(', ')}
        </Stack.Item>
        {running ? (
          <Stack.Item ml={1} bold color="bad">
            {running}
          </Stack.Item>
        ) : null}
      </Stack>
      <Stack
        className="OutpostPrisonAdmin__wing-events"
        align="center"
        wrap
        mb={1}
      >
        <Stack.Item width="90px" bold>
          Wing events
        </Stack.Item>
        {WING_EVENTS.map(([kind, label, icon]) => (
          <Button
            key={kind}
            icon={icon}
            disabled={busy || !!incidents.wing_event_pending}
            onClick={() => act('prison_wing_event', { kind })}
          >
            {label}
          </Button>
        ))}
        {wingParts.length > 0 ? (
          <Stack.Item ml={1} color="label">
            {wingParts.join(', ')}
          </Stack.Item>
        ) : null}
      </Stack>
    </>
  );
};

const PrisonTools = ({ data, busy, act }: PrisonProps) => {
  // The form each prisoner's Experiment button starts
  const [form, setForm] = useState<ExperimentForm>('hulk');
  const experiment = data.experiment || null;
  const changeling = !!experiment && experiment.form === 'changeling';
  const horror = experiment?.horror || null;
  const open = !!data.intake_open;
  const powered = !!data.powered;
  const conditions = data.conditions || {
    clean: 0,
    lit: 0,
    powered: 0,
    score: 0,
  };
  const prisoners = [...(data.prisoners || [])].sort((a, b) => a.cell - b.cell);
  const names: Record<string, string> = {};
  for (const prisoner of prisoners) {
    names[prisoner.ref] = prisoner.name;
  }
  const conditionParts: [string, number][] = [
    ['Clean', conditions.clean],
    ['Lit', conditions.lit],
    ['Power', conditions.powered],
    ['Score', conditions.score],
  ];
  const tension = Math.round(data.tension || 0);
  const stage = PRISON_STAGES[data.stage] || {
    label: data.stage || '?',
    color: 'label',
  };
  const riotOn =
    data.riot_active === undefined || data.riot_active === null
      ? data.stage === 'riot'
      : !!data.riot_active;
  const subdued = isNum(data.subdued_left) && data.subdued_left > 0;
  const intakeParts = [
    data.intake_state || '',
    isNum(data.lost_recent) ? `${data.lost_recent} lost in 30 min` : '',
  ].filter(Boolean);
  const clocks = [
    riotOn && isNum(data.riot_elapsed)
      ? `riot ${clock(data.riot_elapsed)} home`
      : '',
    riotOn && isNum(data.riot_absent) ? `${clock(data.riot_absent)} away` : '',
    isNum(data.subdued_left) ? `subdued ${clock(data.subdued_left)}` : '',
  ].filter(Boolean);
  const hatch = data.hatch;
  const scanParts = [
    isNum(data.mess_units)
      ? `mess ${data.mess_units}${
          isNum(data.floor_size) ? ` / ${data.floor_size} tiles` : ''
        }`
      : isNum(data.floor_size)
        ? `${data.floor_size} floor tiles`
        : '',
    isNum(data.lit_samples) ? `${data.lit_samples} light samples` : '',
  ].filter(Boolean);
  const extras = extrasBlock<PrisonAdminExtras>(data.extras);

  return (
    <Section title="Prison">
      <Stack wrap align="center" mb={1}>
        <Button
          icon={open ? 'door-open' : 'door-closed'}
          selected={open}
          disabled={busy}
          onClick={() => act('prison_intake', { open: open ? 0 : 1 })}
        >
          {open ? 'Intake: Open' : 'Intake: Closed'}
        </Button>
        <Button
          icon="user-plus"
          disabled={busy}
          onClick={() => act('prison_spawn', {})}
        >
          Spawn One
        </Button>
        <Button
          icon="users"
          disabled={busy}
          onClick={() => act('prison_fill', {})}
        >
          Fill Cells
        </Button>
        <Button
          icon="coins"
          disabled={busy}
          onClick={() => act('prison_pay_now', {})}
        >
          Pay Now
        </Button>
        <Button
          icon="trash"
          disabled={busy}
          onClick={() => act('prison_mess', {})}
        >
          Mess
        </Button>
        <Button
          icon="lightbulb"
          disabled={busy}
          onClick={() => act('prison_break_lights', {})}
        >
          Break Lights
        </Button>
        <Button
          icon="utensils"
          disabled={busy}
          onClick={() => act('prison_fill_hatch', {})}
        >
          Fill Hatches
        </Button>
        <Button
          icon="bug"
          disabled={busy}
          onClick={() => act('prison_spawn_rat', {})}
        >
          Spawn Rat
        </Button>
        <Button
          icon={powered ? 'plug-circle-xmark' : 'plug'}
          color={powered ? undefined : 'good'}
          disabled={busy}
          onClick={() => act('prison_power', { on: powered ? 0 : 1 })}
        >
          {powered ? 'Cut Power' : 'Restore Power'}
        </Button>
        {PRISON_ADVANCE.map((minutes) => (
          <Button
            key={minutes}
            icon="forward"
            disabled={busy}
            tooltip={`Skip ${minutes} min`}
            onClick={() => act('prison_advance', { minutes })}
          >
            {`+${minutes} min`}
          </Button>
        ))}
      </Stack>
      <Stack className="OutpostPrisonAdmin__trouble" align="center" wrap mb={1}>
        <Stack.Item width="90px" bold>
          Trouble
        </Stack.Item>
        <Button
          icon="hand-fist"
          color="bad"
          disabled={busy || prisoners.length === 0}
          onClick={() => act('prison_riot', {})}
        >
          Riot
        </Button>
        <Button
          icon="dove"
          color="good"
          disabled={busy}
          onClick={() => act('prison_calm', {})}
        >
          Calm all
        </Button>
        <Button
          icon="truck-arrow-right"
          disabled={busy || !riotOn}
          tooltip="Transfer the rioters out now"
          onClick={() => act('prison_transfer', {})}
        >
          Transfer
        </Button>
        <Button
          icon="hourglass-half"
          disabled={busy}
          tooltip="The quiet after a riot"
          onClick={() => act('prison_subdue', { seconds: SUBDUE_SECONDS })}
        >
          Subdue
        </Button>
        <Button
          icon="hourglass-end"
          disabled={busy || !subdued}
          onClick={() => act('prison_subdue', { seconds: 0 })}
        >
          End Subdue
        </Button>
        <Stack.Item className="OutpostPrisonAdmin__tension" ml={1}>
          {'Tension '}
          <Box
            inline
            bold
            className="OutpostPrisonAdmin__tension-value"
            color={tensionColor(tension)}
          >
            {`${tension}`}
          </Box>
          <Box inline bold ml={1} color={stage.color}>
            {stage.label}
          </Box>
          {typeof data.breakout_in === 'number' ? (
            <Box inline bold ml={1} color="bad">
              {`breakout in ${clock(data.breakout_in)}`}
            </Box>
          ) : null}
        </Stack.Item>
      </Stack>
      <PrisonIncidentTools data={data} busy={busy} act={act} />
      <Stack
        className="OutpostPrisonAdmin__experiment"
        align="center"
        wrap
        mb={1}
      >
        <Stack.Item width="90px" bold>
          Experiment
        </Stack.Item>
        <Button
          icon="user-doctor"
          disabled={busy}
          tooltip="Beam in the researcher with an offer"
          onClick={() => act('prison_researcher', {})}
        >
          Researcher
        </Button>
        {EXPERIMENT_FORMS.map(([value, label]) => (
          <Button
            key={value}
            selected={form === value}
            disabled={busy}
            tooltip="What a prisoner's Experiment button starts"
            onClick={() => setForm(value)}
          >
            {label}
          </Button>
        ))}
        {CHANGELING_STAGES.map(([stage, label, icon]) => (
          <Button
            key={stage}
            icon={icon}
            disabled={busy || !changeling}
            tooltip="Skip the changeling ahead"
            onClick={() => act('prison_changeling_stage', { stage })}
          >
            {label}
          </Button>
        ))}
        <Button
          icon="heart-pulse"
          disabled={busy || !horror}
          tooltip={
            horror === 'regenerating'
              ? 'Get the horror up now'
              : 'Drop the horror to regenerate'
          }
          onClick={() => act('prison_horror', { what: 'regen' })}
        >
          Regen
        </Button>
        <Button.Confirm
          icon="skull"
          color="bad"
          confirmContent="Kill?"
          disabled={busy || !horror}
          tooltip="Kill the horror for good"
          onClick={() => act('prison_horror', { what: 'kill' })}
        >
          Kill Horror
        </Button.Confirm>
        <Button.Confirm
          icon="stop"
          color="bad"
          confirmContent="End?"
          disabled={busy || !experiment}
          tooltip="No fee is paid"
          onClick={() => act('prison_experiment_end', {})}
        >
          End Experiment
        </Button.Confirm>
      </Stack>

      <LabeledList>
        <LabeledList.Item label="Pay">
          {`${Math.round((data.pay_rate || 0) * 10) / 10} cr/min, ${Math.floor(
            data.paid_total || 0,
          ).toLocaleString()} cr paid`}
        </LabeledList.Item>
        <LabeledList.Item label="Arrivals">
          {!open
            ? 'Intake closed'
            : typeof data.next_arrival === 'number'
              ? `Next in ${clock(data.next_arrival)}`
              : 'None scheduled'}
          {powered ? null : (
            <Box inline color="bad" ml={1}>
              No power
            </Box>
          )}
        </LabeledList.Item>
        <LabeledList.Item label="Conditions">
          {conditionParts.map(([label, value]) => (
            <Box inline key={label} mr={1.5}>
              {`${label} `}
              <Box inline bold color={conditionColor(value || 0)}>
                {Math.round(value || 0)}
              </Box>
            </Box>
          ))}
        </LabeledList.Item>
        <LabeledList.Item label="Cells">
          {(data.cells || []).map((cell) => (
            <Box
              inline
              key={cell.number}
              mr={1.5}
              color={cell.occupant_ref ? undefined : 'label'}
            >
              {`${cell.number}: ${
                cell.occupant_ref
                  ? names[cell.occupant_ref] || `? ${cell.occupant_ref}`
                  : 'Empty'
              }`}
            </Box>
          ))}
        </LabeledList.Item>
        {intakeParts.length > 0 ? (
          <LabeledList.Item label="Intake">
            {intakeParts.join(', ')}
          </LabeledList.Item>
        ) : null}
        {data.crew_mode ? (
          <LabeledList.Item label="Crew">
            <Box
              inline
              bold
              className="OutpostPrisonAdmin__crew"
              color={data.crew_home ? 'good' : 'average'}
              mr={1}
            >
              {data.crew_home ? 'Home' : 'Away'}
            </Box>
            {CREW_MODES.map(([mode, label]) => (
              <Button
                key={mode}
                compact
                selected={data.crew_mode === mode}
                disabled={busy}
                onClick={() => act('prison_crew_home', { mode })}
              >
                {label}
              </Button>
            ))}
          </LabeledList.Item>
        ) : null}
        {clocks.length > 0 ? (
          <LabeledList.Item label="Clocks">
            {clocks.join(', ')}
          </LabeledList.Item>
        ) : null}
        {experiment ? (
          <LabeledList.Item label="Experiment">
            {[
              experiment.form || 'unknown',
              experiment.stage || '?',
              experiment.horror === 'regenerating' ? 'regenerating' : '',
              experiment.pickup ? `${experiment.pickup}, awaiting pickup` : '',
              experiment.subject || '',
              isNum(experiment.time_left)
                ? `${clock(experiment.time_left)} left`
                : '',
              experiment.researcher_present ? 'researcher here' : '',
              `fee ${cr(experiment.fee_paid)}`,
              `bonus ${cr(experiment.bonus_paid)}`,
            ]
              .filter(Boolean)
              .join(', ')}
          </LabeledList.Item>
        ) : null}
        {isNum(data.debt) ? (
          <LabeledList.Item label="Debt">
            <Box inline bold color={data.debt > 0 ? 'bad' : undefined} mr={1}>
              {cr(data.debt)}
            </Box>
            <NumberInput
              value={Math.max(0, Math.round(data.debt))}
              minValue={0}
              maxValue={100000}
              step={50}
              stepPixelSize={2}
              width="60px"
              disabled={busy}
              onChange={(next) =>
                act('prison_debt', { amount: Math.max(0, Math.round(next)) })
              }
            />
            {DEBT_PRESETS.map((amount) => (
              <Button
                key={amount}
                compact
                disabled={busy}
                onClick={() => act('prison_debt', { amount })}
              >
                {amount.toLocaleString()}
              </Button>
            ))}
            {isNum(data.incident_fined) ? (
              <Box inline color="label" ml={1}>
                {`incident fined ${cr(data.incident_fined)}`}
              </Box>
            ) : null}
          </LabeledList.Item>
        ) : null}
        {hatch ? (
          <LabeledList.Item label="Hatches">
            {`meals ${hatch.meals || 0}, clean ${hatch.clean_suits || 0}, dirty ${
              hatch.dirty_suits || 0
            }, ${
              (hatch.meals || 0) +
              (hatch.clean_suits || 0) +
              (hatch.dirty_suits || 0)
            }/${hatch.capacity || 0}${
              isNum(hatch.lasts_minutes)
                ? `, lasts ${Math.round(hatch.lasts_minutes)} min`
                : ''
            }`}
          </LabeledList.Item>
        ) : null}
        {scanParts.length > 0 ? (
          <LabeledList.Item label="Scan">
            {scanParts.join(', ')}
          </LabeledList.Item>
        ) : null}
        {isNum(data.outage_debt) ? (
          <LabeledList.Item label="Outage">
            <Box inline mr={1}>
              {`${Math.round(data.outage_debt)} s`}
            </Box>
            {OUTAGE_PRESETS.map((seconds) => (
              <Button
                key={seconds}
                compact
                disabled={busy}
                tooltip="Seconds of outage counted while the power is off"
                onClick={() => act('prison_outage', { seconds })}
              >
                {`${seconds} s`}
              </Button>
            ))}
          </LabeledList.Item>
        ) : null}
      </LabeledList>

      {extras ? (
        <PrisonExtrasTools
          extras={extras}
          prisoners={prisoners}
          names={names}
          busy={busy}
          act={act}
        />
      ) : null}

      <Stack align="center" wrap mt={1}>
        <Stack.Item width="90px" bold>
          All prisoners
        </Stack.Item>
        {PRISON_ALL.map(([what, label]) => (
          <Button
            key={what}
            disabled={busy || prisoners.length === 0}
            onClick={() => act('prison_all', { what })}
          >
            {label}
          </Button>
        ))}
      </Stack>

      {prisoners.length === 0 ? (
        <Box color="label" mt={1}>
          No prisoners
        </Box>
      ) : (
        prisoners.map((prisoner) => (
          <PrisonerRow
            key={prisoner.ref}
            prisoner={prisoner}
            extras={extras}
            busy={busy}
            act={act}
            form={form}
          />
        ))
      )}
    </Section>
  );
};

type PrisonerRowProps = {
  prisoner: PrisonAdminPrisoner;
  extras?: PrisonAdminExtras | null;
  busy: boolean;
  act: DetailsProps['act'];
  /** What the Experiment button starts */
  form: ExperimentForm;
};

const PrisonerRow = ({
  prisoner,
  extras,
  busy,
  act,
  form,
}: PrisonerRowProps) => {
  const dead = !!prisoner.dead;
  const locked = busy || dead;
  const ref = prisoner.ref;
  const set = (field: string, value: number) =>
    act('prison_set', { ref, field, value });
  const loose = !dead && typeof prisoner.loose_left === 'number';
  // No badge for normal or dead prisoners, and none for Loose while the
  // loose timer shows, since it says the same thing.
  const badged =
    !dead &&
    !!prisoner.state &&
    prisoner.state !== 'normal' &&
    !(loose && prisoner.state === 'loose');
  const state = badged
    ? PRISONER_STATES[prisoner.state] || {
        label: prisoner.state,
        icon: 'circle-question',
        color: 'label',
      }
    : null;

  return (
    <Box
      className="OutpostPrisonAdmin__prisoner"
      mt={1}
      pt={1}
      style={{
        borderTop: '1px solid rgba(255, 255, 255, 0.1)',
        opacity: dead ? 0.6 : undefined,
      }}
    >
      <Stack align="center">
        <Stack.Item grow>
          <Box bold style={{ overflowWrap: 'anywhere' }}>
            {`Cell ${prisoner.cell}: ${prisoner.name}`}
            {dead ? (
              <Box inline color="bad" ml={1}>
                Dead
              </Box>
            ) : null}
            {state ? (
              <Box
                inline
                className="OutpostPrisonAdmin__state"
                color={state.color}
                ml={1}
              >
                <Icon name={state.icon} mr={0.5} />
                {state.label}
              </Box>
            ) : null}
            {loose ? (
              <Box
                inline
                className="OutpostPrisonAdmin__loose"
                color="bad"
                ml={1}
              >
                <Icon name="person-running" mr={0.5} />
                {`loose ${clock(prisoner.loose_left as number)}`}
              </Box>
            ) : null}
          </Box>
          <Box color="label" fontSize="11px">
            {[prisoner.personality, prisoner.crime, prisoner.activity]
              .filter(Boolean)
              .join(' / ')}
          </Box>
        </Stack.Item>
        <Stack.Item>
          <Button
            compact
            icon="hand-back-fist"
            disabled={locked}
            onClick={() => act('prison_fight', { ref })}
          >
            Fight
          </Button>
          <Button
            compact
            icon="burst"
            disabled={locked}
            onClick={() => act('prison_breakout', { ref })}
          >
            Breakout
          </Button>
          <Button
            compact
            icon="hammer"
            disabled={locked}
            onClick={() => act('prison_wreck', { ref })}
          >
            Wreck
          </Button>
          <Button
            compact
            icon="flask"
            disabled={locked}
            tooltip={`Start a ${form} experiment`}
            onClick={() => act('prison_experiment', { ref, form })}
          >
            Experiment
          </Button>
          <Button
            compact
            icon="person-walking-arrow-right"
            disabled={locked}
            onClick={() => act('prison_release', { ref })}
          >
            Release
          </Button>
          <Button.Confirm
            compact
            icon="skull"
            color="bad"
            confirmContent="Kill?"
            disabled={locked}
            onClick={() => act('prison_kill', { ref })}
          >
            Kill
          </Button.Confirm>
          <Button.Confirm
            compact
            icon="trash"
            color="bad"
            confirmContent="Remove?"
            disabled={busy}
            onClick={() => act('prison_remove', { ref })}
          >
            Remove
          </Button.Confirm>
        </Stack.Item>
      </Stack>
      <Stack align="center" wrap mt={0.5}>
        {PRISON_STATS.map((stat) => {
          const value = Math.round(prisoner[stat.field] || 0);
          return (
            <Stack.Item
              key={stat.field}
              className={`OutpostPrisonAdmin__stat OutpostPrisonAdmin__stat--${stat.field}`}
              mr={1}
            >
              <Box inline bold color={stat.color(value)} mr={0.5}>
                {stat.label}
              </Box>
              <NumberInput
                value={value}
                minValue={0}
                maxValue={100}
                step={1}
                stepPixelSize={2}
                width="38px"
                disabled={locked}
                onChange={(next) => set(stat.field, Math.round(next))}
              />
              {stat.presets.map((preset) => (
                <Button
                  key={preset}
                  compact
                  disabled={locked}
                  onClick={() => set(stat.field, preset)}
                >
                  {preset}
                </Button>
              ))}
            </Stack.Item>
          );
        })}
        <Stack.Item
          className="OutpostPrisonAdmin__stat OutpostPrisonAdmin__stat--care"
          mr={1}
          color="label"
        >
          {`Care ${Math.round(prisoner.care || 0)}`}
        </Stack.Item>
        {isNum(prisoner.grade) ? (
          <Stack.Item
            className="OutpostPrisonAdmin__stat OutpostPrisonAdmin__stat--grade"
            mr={1}
            color="label"
          >
            {`Grade ${prisoner.grade.toFixed(2)}`}
          </Stack.Item>
        ) : null}
        {isNum(prisoner.pay_factor) ? (
          <Stack.Item
            className="OutpostPrisonAdmin__stat OutpostPrisonAdmin__stat--pay"
            mr={1}
            color="label"
          >
            {`Pay ${prisoner.pay_factor.toFixed(2)}`}
          </Stack.Item>
        ) : null}
        {isNum(prisoner.confined_seconds) ? (
          <Stack.Item
            className="OutpostPrisonAdmin__stat OutpostPrisonAdmin__stat--locked_in"
            mr={1}
          >
            <Box
              inline
              bold
              color={prisoner.confined ? 'bad' : undefined}
              mr={0.5}
            >
              {prisoner.confined ? <Icon name="lock" mr={0.5} /> : null}
              Confined
            </Box>
            <NumberInput
              value={Math.max(0, Math.round(prisoner.confined_seconds))}
              minValue={0}
              maxValue={3600}
              step={10}
              stepPixelSize={4}
              width="48px"
              format={clock}
              disabled={locked}
              onChange={(next) => set('locked_in', Math.round(next))}
            />
            {CONFINED_PRESETS.map((preset) => (
              <Button
                key={preset}
                compact
                disabled={locked}
                onClick={() => set('locked_in', preset)}
              >
                {clock(preset)}
              </Button>
            ))}
          </Stack.Item>
        ) : null}
        {isNum(prisoner.lockdown_left) && prisoner.lockdown_left > 0 ? (
          <Stack.Item
            className="OutpostPrisonAdmin__stat OutpostPrisonAdmin__stat--lockdown"
            mr={1}
          >
            <Box inline bold color="average" mr={0.5}>
              <Icon name="lock" mr={0.5} />
              {`Lockdown ${clock(prisoner.lockdown_left)}`}
            </Box>
            <Button
              compact
              disabled={locked}
              onClick={() => set('lockdown', 0)}
            >
              Clear
            </Button>
          </Stack.Item>
        ) : null}
        <Stack.Item className="OutpostPrisonAdmin__stat OutpostPrisonAdmin__stat--sentence">
          <Box inline bold mr={0.5}>
            Left
          </Box>
          <NumberInput
            value={Math.max(0, Math.round(prisoner.sentence_left || 0))}
            minValue={0}
            maxValue={3600}
            step={30}
            stepPixelSize={4}
            width="48px"
            format={clock}
            disabled={locked}
            onChange={(next) => set('sentence', Math.round(next))}
          />
          {SENTENCE_PRESETS.map((preset) => (
            <Button
              key={preset}
              compact
              disabled={locked}
              onClick={() => set('sentence', preset)}
            >
              {clock(preset)}
            </Button>
          ))}
        </Stack.Item>
      </Stack>
      {extras ? (
        <PrisonerExtras
          prisoner={prisoner}
          extras={extras}
          locked={locked}
          act={act}
        />
      ) : null}
    </Box>
  );
};

// ===== Prison extras (outpost_prison_extras.dm): guards, reputation, life, contraband, mail, leads =====

/** An extras block sent as an object; an empty list means its package has not landed yet. */
function extrasBlock<T>(value: T | unknown[] | null | undefined): T | null {
  return value && typeof value === 'object' && !Array.isArray(value)
    ? (value as T)
    : null;
}

/** An extras block sent as a list, without holes; anything else is empty. */
function extrasRows<T>(value: T[] | null | undefined): T[] {
  return Array.isArray(value) ? value.filter(Boolean) : [];
}

/** prison_rep: -10 to 10; brute at -5 or less, fair at 5 or more */
const REP_PRESETS = [-10, -5, 0, 5, 10];

/** prison_affinity: -100 to 100; friends at 25 or more, rivals at -25 or less */
const AFFINITY_PRESETS: [number, string][] = [
  [50, 'Friends'],
  [0, 'Neutral'],
  [-50, 'Rivals'],
];

/** prison_mail kinds */
const LETTER_KINDS = [
  { value: 'good', displayText: 'Good news' },
  { value: 'kid', displayText: "Kid's drawing" },
  { value: 'news', displayText: 'News' },
  { value: 'bad', displayText: 'Bad news' },
  { value: 'contraband', displayText: 'Contraband' },
];

type ExtrasToolsProps = {
  extras: PrisonAdminExtras;
  prisoners: PrisonAdminPrisoner[];
  names: Record<string, string>;
  busy: boolean;
  act: DetailsProps['act'];
};

/** The wing-wide extras controls, under the prison's own list */
const PrisonExtrasTools = ({
  extras,
  prisoners,
  names,
  busy,
  act,
}: ExtrasToolsProps) => {
  const guards = extrasRows(extras.guards);
  const reps = extrasRows(extras.social);
  const life = extrasBlock<AdminLife>(extras.life);
  const contraband = extrasBlock<AdminContraband>(extras.contraband);
  const mail = extrasBlock<AdminMail>(extras.mail);
  const leads = extrasBlock<AdminLeads>(extras.leads);
  const pairs = extrasRows(life?.pairs);
  const cells = extrasRows(contraband?.cells);
  const letters = extrasRows(mail?.letters);
  const openLeads = extrasRows(leads?.open);
  const bounty = extrasBlock<AdminBounty>(extras.bounty);
  return (
    <Box
      className="OutpostPrisonAdmin__extras"
      mt={1}
      pt={1}
      style={{ borderTop: '1px solid rgba(255, 255, 255, 0.1)' }}
    >
      <LabeledList>
        {Array.isArray(extras.guards) ? (
          <LabeledList.Item label="Guards">
            <Button
              compact
              icon="user-plus"
              disabled={busy}
              tooltip="Free, ignores the cap"
              onClick={() => act('prison_guard_spawn', {})}
            >
              Spawn
            </Button>
            {guards.map((guard) => (
              <Box
                key={guard.ref}
                className="OutpostPrisonAdmin__guard"
                mt={0.5}
              >
                <Box inline bold mr={1}>
                  {guard.name}
                </Box>
                <Box inline color="label" mr={1}>
                  {[
                    `${Math.round(guard.health || 0)} HP`,
                    guard.status,
                    guard.activity,
                    guard.response,
                  ]
                    .filter(Boolean)
                    .join(' / ')}
                </Box>
                <Button
                  compact
                  icon="user-injured"
                  disabled={busy}
                  onClick={() => act('prison_guard_down', { ref: guard.ref })}
                >
                  Down
                </Button>
                <Button.Confirm
                  compact
                  icon="trash"
                  color="bad"
                  confirmContent="Remove?"
                  disabled={busy}
                  onClick={() => act('prison_guard_remove', { ref: guard.ref })}
                >
                  Remove
                </Button.Confirm>
              </Box>
            ))}
          </LabeledList.Item>
        ) : null}
        {reps.length > 0 ? (
          <LabeledList.Item label="Reputation">
            {reps.map((rep) => (
              <Box key={rep.key} className="OutpostPrisonAdmin__rep" mb={0.5}>
                <Box inline bold mr={1}>
                  {rep.name || rep.key}
                </Box>
                <Box inline color="label" mr={1}>
                  {rep.label}
                </Box>
                <NumberInput
                  value={Math.round((rep.score || 0) * 10) / 10}
                  minValue={-10}
                  maxValue={10}
                  step={0.5}
                  stepPixelSize={4}
                  width="44px"
                  disabled={busy}
                  onChange={(next) =>
                    act('prison_rep', {
                      key: rep.key,
                      score: Math.max(-10, Math.min(10, next)),
                    })
                  }
                />
                {REP_PRESETS.map((score) => (
                  <Button
                    key={score}
                    compact
                    disabled={busy}
                    onClick={() => act('prison_rep', { key: rep.key, score })}
                  >
                    {`${score}`}
                  </Button>
                ))}
              </Box>
            ))}
          </LabeledList.Item>
        ) : null}
        {life ? (
          <LabeledList.Item label="Affinity">
            {pairs.map((pair) => (
              <Box
                key={`${pair.a_ref}|${pair.b_ref}`}
                className="OutpostPrisonAdmin__pair"
                mb={0.5}
              >
                <Box inline mr={1}>
                  {`${pair.a_name || names[pair.a_ref] || '?'} / ${
                    pair.b_name || names[pair.b_ref] || '?'
                  }`}
                </Box>
                <NumberInput
                  value={Math.round(pair.affinity || 0)}
                  minValue={-100}
                  maxValue={100}
                  step={5}
                  stepPixelSize={2}
                  width="44px"
                  disabled={busy}
                  onChange={(next) =>
                    act('prison_affinity', {
                      a_ref: pair.a_ref,
                      b_ref: pair.b_ref,
                      value: Math.max(-100, Math.min(100, Math.round(next))),
                    })
                  }
                />
                {AFFINITY_PRESETS.map(([value, label]) => (
                  <Button
                    key={label}
                    compact
                    disabled={busy}
                    onClick={() =>
                      act('prison_affinity', {
                        a_ref: pair.a_ref,
                        b_ref: pair.b_ref,
                        value,
                      })
                    }
                  >
                    {label}
                  </Button>
                ))}
              </Box>
            ))}
            <AffinityPicker prisoners={prisoners} busy={busy} act={act} />
          </LabeledList.Item>
        ) : null}
        {life ? (
          <LabeledList.Item label="Scenes">
            <Button
              compact
              icon="clone"
              disabled={busy}
              tooltip="A card game at the table with the deck"
              onClick={() => act('prison_cards', {})}
            >
              Cards
            </Button>
            {life.scene ? (
              <Box inline color="average" ml={1}>
                {life.scene}
              </Box>
            ) : null}
          </LabeledList.Item>
        ) : null}
        {contraband ? (
          <LabeledList.Item label="Stashes">
            {cells.map((cell) => {
              const pruno = cell.pruno || 'none';
              const stocked = !!cell.shiv || pruno !== 'none';
              const stash = (kind: string) =>
                act('prison_stash', { cell: cell.number, kind });
              return (
                <Box
                  key={cell.number}
                  className="OutpostPrisonAdmin__stash"
                  mb={0.5}
                >
                  <Box inline bold mr={1}>
                    {`Cell ${cell.number}`}
                  </Box>
                  <Button
                    compact
                    selected={!!cell.shiv}
                    disabled={busy}
                    onClick={() => stash('shiv')}
                  >
                    Shiv
                  </Button>
                  <Button
                    compact
                    selected={pruno !== 'none'}
                    disabled={busy}
                    onClick={() => stash('pruno')}
                  >
                    {pruno === 'none' ? 'Pruno' : `Pruno (${pruno})`}
                  </Button>
                  <Button
                    compact
                    disabled={busy || !stocked}
                    onClick={() => stash('clear')}
                  >
                    Clear
                  </Button>
                </Box>
              );
            })}
          </LabeledList.Item>
        ) : null}
        {mail ? (
          <LabeledList.Item label="Mail">
            <Button
              compact
              icon="envelope"
              disabled={busy}
              tooltip="A mail pod now, with letters for a share of the prisoners"
              onClick={() => act('prison_mail_wave', {})}
            >
              Mail pod
            </Button>
            <Box inline color="label" ml={1}>
              {isNum(mail.next_in)
                ? `Next mail pod in ${clock(mail.next_in)}`
                : 'Mail clock stopped'}
            </Box>
            {letters.map((letter) => (
              <Box key={letter.ref} className="OutpostPrisonAdmin__letter">
                {`${letter.to_name || names[letter.to_ref] || '?'}: ${
                  letter.kind
                }, ${clock(letter.age)}`}
                {letter.opened ? (
                  <Box inline color="average" ml={1}>
                    opened
                  </Box>
                ) : null}
                {letter.contraband ? (
                  <Box inline color="bad" ml={1}>
                    contraband
                  </Box>
                ) : null}
              </Box>
            ))}
          </LabeledList.Item>
        ) : null}
        {leads ? (
          <LabeledList.Item label="Leads">
            <Box color="label">
              {isNum(leads.ready_in) && leads.ready_in > 0
                ? `Next lead in ${clock(leads.ready_in)}`
                : 'Ready'}
            </Box>
            {openLeads.map((lead, index) => (
              <Box key={index} className="OutpostPrisonAdmin__lead">
                {`${lead.teller} to ${lead.ship}: ${lead.name}, ${clock(
                  lead.age,
                )}`}
                {lead.lie ? (
                  <Box inline bold color="bad" ml={1}>
                    lie
                  </Box>
                ) : null}
                {lead.exposed ? (
                  <Box inline color="label" ml={1}>
                    exposed
                  </Box>
                ) : null}
              </Box>
            ))}
          </LabeledList.Item>
        ) : null}
        {bounty ? (
          <PrisonBountyTools bounty={bounty} busy={busy} act={act} />
        ) : null}
      </LabeledList>
    </Box>
  );
};

/** prison_bounty_intake settings */
const BOUNTY_INTAKE_SETTINGS: [string, string][] = [
  ['all', 'All'],
  ['no_most_wanted', 'No Most Wanted'],
  ['none', 'None'],
];

/** prison_bounty_make tiers */
const BOUNTY_TIERS: [number, string][] = [
  [1, 'Petty'],
  [2, 'Wanted'],
  [3, 'Most Wanted'],
];

type BountyToolsProps = {
  bounty: AdminBounty;
  busy: boolean;
  act: DetailsProps['act'];
};

/** Bounty prisoners (outpost_prison_bounty.dm): the wing's transfers, test records, and the pool with a forced admission per record */
const PrisonBountyTools = ({ bounty, busy, act }: BountyToolsProps) => {
  const pool = extrasRows(bounty.pool);
  return (
    <>
      <LabeledList.Item label="Bounty intake">
        {BOUNTY_INTAKE_SETTINGS.map(([setting, label]) => (
          <Button
            key={setting}
            compact
            selected={bounty.setting === setting}
            disabled={busy}
            onClick={() => act('prison_bounty_intake', { setting })}
          >
            {label}
          </Button>
        ))}
        <Box inline color="label" ml={1}>
          {`${bounty.count || 0}/${bounty.max || 0} held, ${
            bounty.most_wanted || 0
          }/${bounty.lanes || 1} Most Wanted`}
        </Box>
        {bounty.next ? (
          <Box color="average" mt={0.5}>
            {`Next: ${bounty.next.name || '?'} (${bounty.next.tier || '?'})`}
          </Box>
        ) : null}
      </LabeledList.Item>
      <LabeledList.Item label="Bounty pool">
        {BOUNTY_TIERS.map(([tier, label]) => (
          <Button
            key={tier}
            compact
            icon="plus"
            disabled={busy}
            tooltip="A test record, reserved for this wing"
            onClick={() => act('prison_bounty_make', { tier })}
          >
            {label}
          </Button>
        ))}
        <Button.Confirm
          compact
          icon="trash"
          color="bad"
          confirmContent="Clear?"
          disabled={busy || pool.length === 0}
          onClick={() => act('prison_bounty_clear', {})}
        >
          Clear
        </Button.Confirm>
        {pool.length === 0 ? (
          <Box color="label" mt={0.5}>
            Empty
          </Box>
        ) : null}
        {pool.map((record) => (
          <Box
            key={record.id}
            className="OutpostPrisonAdmin__bounty-record"
            mt={0.5}
          >
            <Box inline bold mr={1}>
              {record.name || '?'}
            </Box>
            <Box inline color="label" mr={1}>
              {[
                record.tier,
                record.archetype,
                `${clock(record.age || 0)} in pool`,
                `leaves in ${clock(record.left || 0)}`,
                record.ours
                  ? 'reserved here'
                  : record.reserved_for
                    ? `reserved for ${record.reserved_for}`
                    : 'open',
                record.named_to ? `named to ${record.named_to}` : null,
                record.accepts ? null : 'refused here',
              ]
                .filter(Boolean)
                .join(' / ')}
            </Box>
            <Button
              compact
              icon="right-to-bracket"
              disabled={busy}
              tooltip="Beam them in now, into the first free cell"
              onClick={() => act('prison_bounty_admit', { id: record.id })}
            >
              Admit
            </Button>
          </Box>
        ))}
      </LabeledList.Item>
    </>
  );
};

type AffinityPickerProps = {
  prisoners: PrisonAdminPrisoner[];
  busy: boolean;
  act: DetailsProps['act'];
};

/** Two prisoners and a preset: makes a pair that has no affinity yet */
const AffinityPicker = ({ prisoners, busy, act }: AffinityPickerProps) => {
  const [first, setFirst] = useState('');
  const [second, setSecond] = useState('');
  const living = prisoners.filter((prisoner) => !prisoner.dead);
  const names: Record<string, string> = {};
  for (const prisoner of living) {
    names[prisoner.ref] = prisoner.name;
  }
  const options = living.map((prisoner) => ({
    value: prisoner.ref,
    displayText: prisoner.name,
  }));
  const ready = !!names[first] && !!names[second] && first !== second;
  return (
    <Stack
      className="OutpostPrisonAdmin__pick-pair"
      align="center"
      wrap
      mt={0.5}
    >
      <Dropdown
        width="130px"
        disabled={busy || living.length < 2}
        selected={first}
        displayText={names[first] || undefined}
        placeholder="Prisoner"
        options={options}
        onSelected={(ref) => setFirst(ref)}
      />
      <Dropdown
        width="130px"
        disabled={busy || living.length < 2}
        selected={second}
        displayText={names[second] || undefined}
        placeholder="Prisoner"
        options={options}
        onSelected={(ref) => setSecond(ref)}
      />
      {AFFINITY_PRESETS.map(([value, label]) => (
        <Button
          key={label}
          compact
          disabled={busy || !ready}
          onClick={() =>
            act('prison_affinity', { a_ref: first, b_ref: second, value })
          }
        >
          {label}
        </Button>
      ))}
    </Stack>
  );
};

type PrisonerExtrasProps = {
  prisoner: PrisonAdminPrisoner;
  extras: PrisonAdminExtras;
  locked: boolean;
  act: DetailsProps['act'];
};

/** One prisoner's extras: badges, then birthday, party, a letter and a lead */
const PrisonerExtras = ({
  prisoner,
  extras,
  locked,
  act,
}: PrisonerExtrasProps) => {
  const life = extrasBlock<AdminLife>(extras.life);
  const contraband = extrasBlock<AdminContraband>(extras.contraband);
  const mail = extrasBlock<AdminMail>(extras.mail);
  const leads = extrasBlock<AdminLeads>(extras.leads);
  if (!life && !contraband && !mail && !leads) {
    return null;
  }
  const ref = prisoner.ref;
  const birthday = extrasRows(life?.birthdays).includes(ref);
  // [label, icon, colour]
  const badges: [string, string, string][] = [];
  if (birthday) {
    badges.push(['Birthday', 'cake-candles', 'good']);
  }
  if (extrasRows(contraband?.drunk).includes(ref)) {
    badges.push(['Drunk', 'wine-bottle', 'average']);
  }
  if (extrasRows(contraband?.carrying).includes(ref)) {
    badges.push(['Carrying', 'hand', 'average']);
  }
  if (extrasRows(leads?.carriers).includes(ref)) {
    badges.push(['Has a lead', 'map-location-dot', 'good']);
  }
  return (
    <Stack
      className="OutpostPrisonAdmin__prisoner-extras"
      align="center"
      wrap
      mt={0.5}
    >
      {badges.map(([label, icon, color]) => (
        <Box
          inline
          key={label}
          className="OutpostPrisonAdmin__badge"
          color={color}
          mr={1}
        >
          <Icon name={icon} mr={0.5} />
          {label}
        </Box>
      ))}
      {life ? (
        <>
          <Button
            compact
            icon="cake-candles"
            disabled={locked || birthday}
            onClick={() => act('prison_birthday', { ref })}
          >
            Birthday
          </Button>
          <Button
            compact
            icon="champagne-glasses"
            disabled={locked || !birthday}
            tooltip={birthday ? undefined : 'Birthday first'}
            onClick={() => act('prison_party', { ref })}
          >
            Party
          </Button>
        </>
      ) : null}
      {mail ? (
        <Dropdown
          width="110px"
          disabled={locked}
          selected={null}
          displayText="Send letter"
          icon="envelope"
          options={LETTER_KINDS}
          onSelected={(kind) => act('prison_mail', { ref, kind })}
        />
      ) : null}
      {leads ? (
        <Button
          compact
          icon="map-location-dot"
          disabled={locked}
          tooltip="Carries a lead, and the wing is ready"
          onClick={() => act('prison_lead', { ref })}
        >
          Lead
        </Button>
      ) : null}
    </Stack>
  );
};
