import { useEffect, useState } from 'react';
import {
  Box,
  Button,
  Collapsible,
  Dropdown,
  Input,
  LabeledList,
  NoticeBox,
  NumberInput,
  Section,
  Stack,
} from 'tgui-core/components';
import type { BooleanLike } from 'tgui-core/react';

import { useBackend } from '../backend';
import { Window } from '../layouts';

type Contact = {
  ref: string;
  name: string;
  kind: string;
  coords: number[] | null;
  status: string;
  active: BooleanLike;
};

type Port = {
  ref: string;
  label: string;
  name: string;
  id: string | null;
  coords: number[];
  direction: string;
  width: number;
  height: number;
  status: string;
  location: string | null;
};

type Player = {
  ref: string;
  name: string;
  ckey: string | null;
  location: string;
  connected: BooleanLike;
  dead: BooleanLike;
};

type Details = Contact & {
  type: string;
  interior: string;
  footprint: string | null;
  is_ship: BooleanLike;
  has_interior: BooleanLike;
  supports_interior: BooleanLike;
  supports_unload: BooleanLike;
  load_blocker: string | null;
  unload_blocker: string | null;
  delete_blocker: string | null;
  busy: BooleanLike;
  can_jump: BooleanLike;
  ports: Port[];
  ships: { ref: string; name: string; status: string }[];
  players: Player[] | null;
  cleanup: {
    title: string;
    reason: string | null;
    timer_label: string | null;
    seconds: number | null;
  };
  unload_effect: string;
};

type SpawnOption = {
  id: string;
  name: string;
  category: string;
  description: string | null;
};

type BanEntry = {
  id: string;
  outpost_ref: string;
  outpost: string;
  kind: string;
  target_ref: string;
  name: string;
  label: string;
  seconds: number | null;
};

type Bans = {
  entries: BanEntry[];
  outposts: { ref: string; name: string; trader: BooleanLike }[];
  ships: { ref: string; name: string }[];
  people: { ref: string; name: string }[];
  max_minutes: number;
};

type Data = {
  bans: Bans | null;
  objects: Contact[];
  selected: Details | null;
  return_name: string | null;
  error: string | null;
  notice: string | null;
  spawning: BooleanLike;
  spawn_serial: number;
  spawn_options: SpawnOption[];
  worldgen: string | null;
  worldgen_seconds: number;
  queued_jobs: number;
};

const coordinates = (coords: number[] | null) =>
  coords ? coords.join(', ') : 'No location';

const duration = (seconds: number) =>
  seconds < 60
    ? `${seconds}s`
    : `${Math.floor(seconds / 60)}m ${seconds % 60}s`;

const wrapping = { whiteSpace: 'normal', overflowWrap: 'anywhere' } as const;

export const OvermapManagement = () => {
  const { act, data } = useBackend<Data>();
  const [search, setSearch] = useState('');
  const [kind, setKind] = useState('All types');
  const [activity, setActivity] = useState('All');
  const [showSpawn, setShowSpawn] = useState(false);
  const { objects, selected } = data;
  const showBans = !!data.bans;
  const closeBans = () => {
    if (showBans) {
      act('ban_view', { open: 0 });
    }
  };
  useEffect(() => {
    if (data.spawn_serial > 0) {
      setShowSpawn(false);
    }
  }, [data.spawn_serial]);
  const query = search.trim().toLowerCase();
  const contacts = objects
    .filter(
      (contact) =>
        (kind === 'All types' || kind === contact.kind) &&
        (activity === 'All' || !!contact.active === (activity === 'Active')) &&
        `${contact.name} ${contact.kind} ${coordinates(contact.coords)}`
          .toLowerCase()
          .includes(query),
    )
    .sort((a, b) => a.name.localeCompare(b.name) || a.ref.localeCompare(b.ref));
  const kinds = [
    'All types',
    ...new Set(objects.map((item) => item.kind).sort()),
  ];

  return (
    <Window width={1120} height={760} title="Overmap Management">
      <Window.Content>
        <Stack vertical fill>
          <Stack.Item>
            <Stack align="center">
              <Stack.Item grow>
                <Box bold fontSize="18px">
                  Overmap
                </Box>
                <Box color="label">{objects.length} locations and ships</Box>
              </Stack.Item>
              <Stack.Item>
                <Button
                  icon="ban"
                  selected={showBans}
                  onClick={() => {
                    setShowSpawn(false);
                    act('ban_view', { open: showBans ? 0 : 1 });
                  }}
                >
                  Outpost bans
                </Button>
              </Stack.Item>
              <Stack.Item>
                <Button
                  icon="plus"
                  color="good"
                  selected={showSpawn}
                  onClick={() => {
                    closeBans();
                    setShowSpawn(!showSpawn);
                  }}
                >
                  Spawn new
                </Button>
              </Stack.Item>
            </Stack>
          </Stack.Item>
          {!!data.worldgen && (
            <Stack.Item>
              <Box color="label">
                Interior work in progress ({duration(data.worldgen_seconds)})
                {data.queued_jobs > 0 ? ` · ${data.queued_jobs} waiting` : ''}
              </Box>
            </Stack.Item>
          )}
          {!!(data.error || data.notice) && (
            <Stack.Item>
              <NoticeBox
                {...(data.error ? { danger: true } : { success: true })}
              >
                <Button
                  icon="xmark"
                  compact
                  color="transparent"
                  tooltip="Dismiss message"
                  onClick={() => act('dismiss')}
                />
                {data.error || data.notice}
              </NoticeBox>
            </Stack.Item>
          )}
          <Stack.Item grow style={{ minHeight: 0 }}>
            <Stack fill>
              <Stack.Item basis="33%" style={{ minWidth: 0 }}>
                <Section fill>
                  <Stack vertical fill>
                    <Stack.Item>
                      <Input
                        fluid
                        placeholder="Search names or sectors"
                        value={search}
                        onChange={setSearch}
                      />
                    </Stack.Item>
                    <Stack.Item>
                      <Dropdown
                        width="100%"
                        options={kinds}
                        selected={kind}
                        onSelected={setKind}
                      />
                    </Stack.Item>
                    <Stack.Item>
                      <Dropdown
                        width="100%"
                        options={['All', 'Active', 'Inactive']}
                        selected={activity}
                        onSelected={setActivity}
                      />
                    </Stack.Item>
                    <Stack.Item>
                      <Box color="label">
                        {contacts.length} shown
                        {(!!query ||
                          kind !== 'All types' ||
                          activity !== 'All') && (
                          <Button
                            compact
                            color="transparent"
                            ml={1}
                            onClick={() => {
                              setSearch('');
                              setKind('All types');
                              setActivity('All');
                            }}
                          >
                            Clear filters
                          </Button>
                        )}
                      </Box>
                    </Stack.Item>
                    <Stack.Item
                      grow
                      style={{ overflowY: 'auto', minHeight: 0 }}
                    >
                      {contacts.length === 0 && (
                        <NoticeBox info>No matching results.</NoticeBox>
                      )}
                      {contacts.map((contact) => (
                        <Button
                          key={contact.ref}
                          fluid
                          mb={0.5}
                          py={0.75}
                          selected={
                            !showSpawn &&
                            !showBans &&
                            selected?.ref === contact.ref
                          }
                          onClick={() => {
                            setShowSpawn(false);
                            closeBans();
                            act('select', { ref: contact.ref });
                          }}
                        >
                          <Box bold style={wrapping}>
                            {contact.name}
                          </Box>
                          <Box fontSize="11px" style={wrapping}>
                            {contact.kind} · Sector{' '}
                            {coordinates(contact.coords)}
                          </Box>
                          <Box fontSize="11px">{contact.status}</Box>
                        </Button>
                      ))}
                    </Stack.Item>
                  </Stack>
                </Section>
              </Stack.Item>
              <Stack.Item grow style={{ minWidth: 0 }}>
                {data.bans ? (
                  <OutpostBans bans={data.bans} />
                ) : showSpawn ? (
                  <SpawnContact onCancel={() => setShowSpawn(false)} />
                ) : selected ? (
                  <ContactDetails key={selected.ref} contact={selected} />
                ) : (
                  <Section fill>
                    <Box mt={5} textAlign="center" color="label">
                      <Box bold fontSize="16px" mb={1}>
                        Choose a location or ship
                      </Box>
                      Inspect its interior, docking pads and cleanup status.
                    </Box>
                  </Section>
                )}
              </Stack.Item>
            </Stack>
          </Stack.Item>
        </Stack>
      </Window.Content>
    </Window>
  );
};

const SpawnContact = ({ onCancel }: { onCancel: () => void }) => {
  const { act, data } = useBackend<Data>();
  const [category, setCategory] = useState('Planets');
  const [query, setQuery] = useState('');
  const [optionId, setOptionId] = useState<string | null>(null);
  const [location, setLocation] = useState('Random empty sector');
  const options = data.spawn_options || [];
  const selected = options.find((option) => option.id === optionId);
  const matches = options
    .filter(
      (option) =>
        option.category === category &&
        option.name.toLowerCase().includes(query.trim().toLowerCase()),
    )
    .sort((a, b) => a.name.localeCompare(b.name));
  const atSelection = location === 'Selected sector';
  return (
    <Section title="Spawn new" fill>
      <Stack vertical fill>
        <Stack.Item>
          <Dropdown
            width="100%"
            selected={category}
            options={[...new Set(options.map((option) => option.category))]}
            onSelected={(value) => {
              setCategory(value);
              setOptionId(null);
              setQuery('');
            }}
          />
        </Stack.Item>
        <Stack.Item>
          <Input
            fluid
            placeholder={`Search ${category.toLowerCase()}`}
            value={query}
            onChange={setQuery}
          />
        </Stack.Item>
        <Stack.Item grow style={{ overflowY: 'auto', minHeight: 0 }}>
          {matches.length === 0 && (
            <NoticeBox info>No matching templates.</NoticeBox>
          )}
          {matches.map((option) => (
            <Button
              key={option.id}
              fluid
              mb={0.5}
              py={0.5}
              selected={option.id === optionId}
              onClick={() => setOptionId(option.id)}
            >
              <Box style={wrapping}>{option.name}</Box>
            </Button>
          ))}
        </Stack.Item>
        <Stack.Item>
          <Box bold mb={0.5}>
            {selected?.name || 'Choose a template above'}
          </Box>
          {!!selected?.description && (
            <Box color="label" mb={1}>
              {selected.description}
            </Box>
          )}
          <LabeledList>
            <LabeledList.Item label="Spawn at">
              <Dropdown
                selected={location}
                options={['Random empty sector', 'Selected sector']}
                onSelected={setLocation}
              />
            </LabeledList.Item>
          </LabeledList>
          {!!atSelection && (
            <Box color="label" mt={0.5}>
              {data.selected
                ? `${data.selected.name} · Sector ${coordinates(data.selected.coords)}`
                : 'Select a location or ship first.'}
            </Box>
          )}
          <Box mt={1}>
            <Button
              icon="plus"
              color="good"
              disabled={
                !selected ||
                !!data.spawning ||
                (atSelection && !data.selected?.coords)
              }
              onClick={() =>
                act('spawn', {
                  id: optionId,
                  location: atSelection ? 'selected' : 'random',
                  ref: data.selected?.ref,
                })
              }
            >
              {data.spawning ? 'Spawning…' : 'Spawn selected'}
            </Button>
            <Button onClick={onCancel}>Back to overview</Button>
          </Box>
        </Stack.Item>
      </Stack>
    </Section>
  );
};

const ContactDetails = ({ contact }: { contact: Details }) => {
  const { act, data } = useBackend<Data>();
  const target = { ref: contact.ref };
  const cleanup = contact.cleanup;
  // Each distinct reason appears once, with the actions it prevents.
  const blockers = new Map<string, string[]>();
  if (
    !contact.busy &&
    contact.has_interior &&
    contact.supports_interior &&
    contact.supports_unload &&
    contact.unload_blocker
  ) {
    blockers.set(contact.unload_blocker, ['unload']);
  }
  if (!contact.busy && contact.delete_blocker) {
    blockers.set(contact.delete_blocker, [
      ...(blockers.get(contact.delete_blocker) || []),
      'delete',
    ]);
  }
  return (
    <Section fill scrollable>
      {!!data.return_name && (
        <Button icon="arrow-left" mb={1} onClick={() => act('back')}>
          Back to {data.return_name}
        </Button>
      )}
      <Box bold fontSize="20px" mb={0.5} style={wrapping}>
        {contact.name}
      </Box>
      <Box color="label" mb={1}>
        {contact.kind} · Sector {coordinates(contact.coords)} · Interior:{' '}
        {contact.interior}
      </Box>
      <Button
        icon="person-walking-arrow-right"
        disabled={!contact.can_jump}
        onClick={() => act('jump', target)}
      >
        Visit interior
      </Button>
      <Button
        icon="location-dot"
        disabled={!contact.coords}
        onClick={() => act('overmap', target)}
      >
        Visit overmap
      </Button>

      <Section
        title={contact.is_ship ? 'Ship status' : 'Interior cleanup'}
        mt={1}
      >
        <Box
          bold
          color={cleanup.title === 'Cleanup blocked' ? 'average' : undefined}
        >
          {cleanup.title}
        </Box>
        {!!cleanup.reason && !blockers.has(cleanup.reason) && (
          <Box color="label" mt={0.5}>
            {cleanup.reason}
          </Box>
        )}
        {[...blockers].map(([reason, actions]) => (
          <Box key={reason} mt={0.75}>
            <Box color="average" bold>
              Cannot {actions.join(' or ')}
            </Box>
            <Box mt={0.25}>{reason}</Box>
          </Box>
        ))}
        {!!cleanup.timer_label && cleanup.seconds !== null && (
          <Box mt={0.75} color="label">
            {cleanup.timer_label}: {duration(cleanup.seconds)}
          </Box>
        )}
        <Stack wrap mt={1}>
          {!!contact.supports_interior &&
            (!contact.has_interior || !!contact.supports_unload) && (
              <Stack.Item>
                {contact.has_interior ? (
                  <Button
                    icon="eject"
                    disabled={!!contact.busy || !!contact.unload_blocker}
                    tooltip={contact.unload_blocker || contact.unload_effect}
                    onClick={() => act('unload', target)}
                  >
                    Unload interior
                  </Button>
                ) : (
                  <Button
                    icon="download"
                    disabled={!!contact.busy || !!contact.load_blocker}
                    tooltip={contact.load_blocker || undefined}
                    onClick={() => act('load', target)}
                  >
                    Load interior
                  </Button>
                )}
              </Stack.Item>
            )}
          <Stack.Item>
            <Button
              icon="trash"
              color="bad"
              disabled={!!contact.busy || !!contact.delete_blocker}
              tooltip={
                contact.delete_blocker ||
                'Permanently remove this object and its interior'
              }
              onClick={() => act('delete', target)}
            >
              {contact.is_ship ? 'Delete ship' : 'Delete location'}
            </Button>
          </Stack.Item>
        </Stack>
      </Section>

      {contact.players !== null && (
        <Section title={`Players at outpost (${contact.players.length})`}>
          <Box color="label" mb={0.5}>
            Concourse:{' '}
            {
              contact.players.filter(
                (player) => player.location === 'Concourse',
              ).length
            }
            {' · Hangars: '}
            {
              contact.players.filter(
                (player) => player.location !== 'Concourse',
              ).length
            }
          </Box>
          {contact.players.length === 0 ? (
            <Box>No player bodies in the concourse or hangars.</Box>
          ) : (
            contact.players.map((player) => (
              <Box key={player.ref} mb={0.5} style={wrapping}>
                <Box bold>
                  {player.name}
                  {player.ckey ? ` (${player.ckey})` : ''}
                </Box>
                <Box color="label">
                  {player.location} · {player.connected ? 'Online' : 'Offline'}
                  {player.dead ? ' · Dead' : ''}
                </Box>
              </Box>
            ))
          )}
        </Section>
      )}

      {contact.ships.length > 0 && (
        <Section title={`Ships here (${contact.ships.length})`}>
          {contact.ships.map((ship) => (
            <Button
              key={ship.ref}
              fluid
              mb={0.5}
              py={0.5}
              onClick={() =>
                act('inspect_ship', { ...target, ship_ref: ship.ref })
              }
            >
              <Box bold style={wrapping}>
                {ship.name}
              </Box>
              <Box fontSize="11px">{ship.status} · Inspect ship</Box>
            </Button>
          ))}
        </Section>
      )}
      <Section title="Docking ports">
        {contact.ports.length === 0 && (
          <Box color="label">
            {contact.has_interior || !contact.supports_interior
              ? 'No docking ports assigned.'
              : 'Ports appear when the interior is loaded.'}
          </Box>
        )}
        {contact.ports.map((port) => (
          <Box key={port.ref} mb={1}>
            <Stack align="center">
              <Stack.Item grow style={{ minWidth: 0 }}>
                <Box bold>{port.label}</Box>
                <Box color="label" style={wrapping}>
                  {port.status}
                </Box>
                {contact.players !== null && !!port.location && (
                  <Box>
                    Players:{' '}
                    {
                      contact.players.filter(
                        (player) => player.location === port.location,
                      ).length
                    }
                  </Box>
                )}
              </Stack.Item>
              <Stack.Item>
                <Button
                  icon="location-dot"
                  disabled={!!contact.busy}
                  onClick={() =>
                    act('port_jump', { ...target, port_ref: port.ref })
                  }
                >
                  Visit
                </Button>
              </Stack.Item>
            </Stack>
          </Box>
        ))}
      </Section>
      <Collapsible title="Technical details">
        <LabeledList>
          <LabeledList.Item label="Object type">
            <Box style={wrapping}>{contact.type}</Box>
          </LabeledList.Item>
          <LabeledList.Item label="Reference">{contact.ref}</LabeledList.Item>
          {!!contact.footprint && (
            <LabeledList.Item label="Map allocation">
              {contact.footprint}
            </LabeledList.Item>
          )}
        </LabeledList>
        <Button icon="code" mt={1} onClick={() => act('variables', target)}>
          View variables
        </Button>
        {contact.ports.map((port) => (
          <Box key={port.ref} mt={1}>
            <Box bold>
              {port.label}: {port.name}
            </Box>
            <Box color="label" style={wrapping}>
              ID: {port.id || 'None'} · {coordinates(port.coords)} ·{' '}
              {port.direction} · {port.width} × {port.height}
            </Box>
            <Button
              icon="code"
              onClick={() =>
                act('port_variables', { ...target, port_ref: port.ref })
              }
            >
              Port variables
            </Button>
          </Box>
        ))}
      </Collapsible>
    </Section>
  );
};

const BAN_KINDS = {
  trader: [
    { value: 'embargo', displayText: 'Trade embargo (ship)' },
    { value: 'aggressor', displayText: 'Marked for violence (person)' },
    { value: 'trespass', displayText: 'Refused service (person)' },
  ],
  player: [{ value: 'ship_ban', displayText: 'Denied docking (ship)' }],
};

const SHIP_KINDS = ['embargo', 'ship_ban'];

const OutpostBans = ({ bans }: { bans: Bans }) => {
  const { act } = useBackend<Data>();
  const [search, setSearch] = useState('');
  const [outpostFilter, setOutpostFilter] = useState('');
  const [outpostRef, setOutpostRef] = useState<string | null>(null);
  const [kind, setKind] = useState<string | null>(null);
  const [targetRef, setTargetRef] = useState<string | null>(null);
  const [minutes, setMinutes] = useState(15);

  const query = search.trim().toLowerCase();
  const entries = bans.entries
    .filter(
      (entry) =>
        (!outpostFilter || entry.outpost_ref === outpostFilter) &&
        `${entry.name} ${entry.outpost} ${entry.label}`
          .toLowerCase()
          .includes(query),
    )
    .sort(
      (a, b) =>
        a.outpost.localeCompare(b.outpost) || a.name.localeCompare(b.name),
    );
  const outposts = [...bans.outposts].sort((a, b) =>
    a.name.localeCompare(b.name),
  );
  const outpost = outposts.find((option) => option.ref === outpostRef);
  const kinds = outpost
    ? outpost.trader
      ? BAN_KINDS.trader
      : BAN_KINDS.player
    : [];
  const kindOption = kinds.find((option) => option.value === kind);
  const shipTarget = !!kind && SHIP_KINDS.includes(kind);
  const targets = (shipTarget ? bans.ships : bans.people)
    .map((option) => ({ value: option.ref, displayText: option.name }))
    .sort((a, b) => a.displayText.localeCompare(b.displayText));
  const target = targets.find((option) => option.value === targetRef);
  const outpostName = (ref: string) =>
    outposts.find((option) => option.ref === ref)?.name || 'All outposts';

  return (
    <Section fill>
      <Stack vertical fill>
        <Stack.Item>
          <Box bold fontSize="18px">
            Outpost bans
          </Box>
          <Box color="label">
            {bans.entries.length} active across {outposts.length} outposts
          </Box>
        </Stack.Item>
        <Stack.Item>
          <Stack>
            <Stack.Item grow>
              <Input
                fluid
                placeholder="Search names or outposts"
                value={search}
                onChange={setSearch}
              />
            </Stack.Item>
            <Stack.Item basis="40%">
              <Dropdown
                width="100%"
                selected={outpostFilter}
                displayText={outpostName(outpostFilter)}
                options={[
                  { value: '', displayText: 'All outposts' },
                  ...outposts.map((option) => ({
                    value: option.ref,
                    displayText: option.name,
                  })),
                ]}
                onSelected={setOutpostFilter}
              />
            </Stack.Item>
          </Stack>
        </Stack.Item>
        <Stack.Item grow style={{ overflowY: 'auto', minHeight: 0 }}>
          {entries.length === 0 && (
            <NoticeBox info>
              {bans.entries.length > 0 ? 'No matching bans.' : 'Nobody is banned.'}
            </NoticeBox>
          )}
          {entries.map((entry) => (
            <Box key={entry.id} mb={1}>
              <Stack align="center">
                <Stack.Item grow style={{ minWidth: 0 }}>
                  <Box bold style={wrapping}>
                    {entry.name}
                  </Box>
                  <Box color="label" style={wrapping}>
                    {entry.label} · {entry.outpost}
                    {entry.seconds !== null
                      ? ` · ${duration(entry.seconds)} left`
                      : ' · Until lifted'}
                  </Box>
                </Stack.Item>
                <Stack.Item>
                  <Button
                    icon="unlock"
                    onClick={() =>
                      act('ban_lift', {
                        outpost: entry.outpost_ref,
                        kind: entry.kind,
                        target: entry.target_ref,
                      })
                    }
                  >
                    Lift
                  </Button>
                </Stack.Item>
              </Stack>
            </Box>
          ))}
        </Stack.Item>
        <Stack.Item>
          <Section title="Add a ban">
            <LabeledList>
              <LabeledList.Item label="Outpost">
                <Dropdown
                  width="100%"
                  selected={outpostRef}
                  displayText={outpost?.name}
                  placeholder="Choose an outpost"
                  options={outposts.map((option) => ({
                    value: option.ref,
                    displayText: option.name,
                  }))}
                  onSelected={(value) => {
                    setOutpostRef(value);
                    setKind(null);
                    setTargetRef(null);
                  }}
                />
              </LabeledList.Item>
              <LabeledList.Item label="Ban">
                <Dropdown
                  width="100%"
                  disabled={!outpost}
                  selected={kind}
                  displayText={kindOption?.displayText}
                  placeholder="Choose a ban"
                  options={kinds}
                  onSelected={(value) => {
                    setKind(value);
                    setTargetRef(null);
                    setMinutes(value === 'trespass' ? 30 : 15);
                  }}
                />
              </LabeledList.Item>
              <LabeledList.Item label={shipTarget ? 'Ship' : 'Person'}>
                <Dropdown
                  width="100%"
                  disabled={!kind}
                  selected={targetRef}
                  displayText={target?.displayText}
                  placeholder={shipTarget ? 'Choose a ship' : 'Choose a person'}
                  options={targets}
                  onSelected={setTargetRef}
                />
              </LabeledList.Item>
              {!!kind && kind !== 'ship_ban' && (
                <LabeledList.Item label="Minutes">
                  <NumberInput
                    width="60px"
                    minValue={1}
                    maxValue={bans.max_minutes}
                    step={1}
                    value={minutes}
                    onChange={setMinutes}
                  />
                </LabeledList.Item>
              )}
            </LabeledList>
            <Button
              mt={1}
              icon="ban"
              color="bad"
              disabled={!outpost || !kind || !target}
              onClick={() =>
                act('ban_add', {
                  outpost: outpostRef,
                  kind,
                  target: targetRef,
                  minutes,
                })
              }
            >
              Add ban
            </Button>
          </Section>
        </Stack.Item>
      </Stack>
    </Section>
  );
};
