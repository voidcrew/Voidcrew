import type { CSSProperties } from 'react';
import { Box, Section, Stack } from 'tgui-core/components';
import type { BooleanLike } from 'tgui-core/react';

import { useBackend } from '../../tgui/backend';
import { Window } from '../../tgui/layouts';

// The directory board on a trader outpost's concourse (voidcrew/modules/trade_floors/floor_directory.dm).
// One row a floor, in floor order: who has it and, for an Open floor, what it offers. Nothing to press.

export type DirectoryRow = {
  number: number;
  kind: 'open' | 'invited' | 'private' | 'tenant' | 'vacant';
  name: string | null;
  crew: string | null;
  accent: string | null;
  line: string | null;
  offers: string[];
  busy: BooleanLike;
};

export type DirectoryData = {
  building: string | null;
  rows: DirectoryRow[];
};

// What the server sends is already cut to these; the window cuts again so a row never grows past its box
const NAME_MAX = 24;
const CREW_MAX = 40;
const LINE_MAX = 60;
const BUILDING_MAX = 40;
const OFFERS = [
  'Shop',
  'Clinic',
  'Cloning',
  'Lockers',
  'Teleporter',
  'Canteen',
];

const MUTED = '#8b94a3';
const NEUTRAL_ACCENT = '#4b5361';

// One line, cut where the box ends
const ONE_LINE: CSSProperties = {
  overflow: 'hidden',
  textOverflow: 'ellipsis',
  whiteSpace: 'nowrap',
};

// Two lines at most, broken anywhere
const TWO_LINES: CSSProperties = {
  display: '-webkit-box',
  WebkitBoxOrient: 'vertical',
  WebkitLineClamp: 2,
  overflow: 'hidden',
  overflowWrap: 'anywhere',
};

const cut = (text: string | null | undefined, max: number) => {
  const letters = Array.from(text ?? '');
  if (letters.length <= max) {
    return letters.join('');
  }
  return `${letters
    .slice(0, max - 1)
    .join('')
    .trimEnd()}…`;
};

// The accent is one of the game's eight colours. Anything else is drawn neutral.
const accentOf = (row: DirectoryRow) =>
  row.accent && /^#[0-9a-f]{6}$/i.test(row.accent)
    ? row.accent
    : NEUTRAL_ACCENT;

const titleOf = (row: DirectoryRow) => {
  switch (row.kind) {
    case 'open':
    case 'invited':
      return cut(row.name || `Floor ${row.number}`, NAME_MAX);
    case 'tenant':
      return cut(row.name || 'Offices', CREW_MAX);
    case 'vacant':
      return 'Vacant';
    default:
      return 'Private';
  }
};

const Tag = (props: { color: string; children: string }) => (
  <Box
    inline
    px={0.75}
    style={{
      border: `1px solid ${props.color}`,
      borderRadius: '3px',
      color: props.color,
      fontSize: '11px',
      lineHeight: '16px',
      whiteSpace: 'nowrap',
    }}
  >
    {props.children}
  </Box>
);

const FloorRow = (props: { row: DirectoryRow }) => {
  const { row } = props;
  const listed = row.kind === 'open' || row.kind === 'invited';
  const offers = (row.offers || []).filter((offer) => OFFERS.includes(offer));
  return (
    <Box
      mb={0.75}
      py={0.75}
      pr={1}
      style={{
        background: 'rgba(255, 255, 255, 0.04)',
        borderLeft: `5px solid ${listed ? accentOf(row) : NEUTRAL_ACCENT}`,
        borderRadius: '2px',
      }}
    >
      <Stack align="start">
        <Stack.Item
          shrink={0}
          width="2.4em"
          textAlign="center"
          bold
          fontSize="20px"
          color={listed ? 'label' : MUTED}
        >
          {row.number}
        </Stack.Item>
        <Stack.Item grow basis={0} style={{ minWidth: 0 }}>
          <Stack align="center">
            <Stack.Item
              grow
              basis={0}
              bold={listed || row.kind === 'tenant'}
              fontSize="14px"
              color={listed ? undefined : MUTED}
              style={{ ...ONE_LINE, minWidth: 0 }}
            >
              {titleOf(row)}
            </Stack.Item>
            {!!row.busy && (
              <Stack.Item shrink={0}>
                <Tag color="#e0a030">Busy</Tag>
              </Stack.Item>
            )}
            {row.kind === 'open' ? (
              <Stack.Item shrink={0}>
                <Tag color="#5fbf5f">Open</Tag>
              </Stack.Item>
            ) : null}
            {row.kind === 'invited' ? (
              <Stack.Item shrink={0}>
                <Tag color={MUTED}>By invitation</Tag>
              </Stack.Item>
            ) : null}
          </Stack>
          {listed && !!row.crew ? (
            <Box color="label" style={ONE_LINE}>
              {cut(row.crew, CREW_MAX)}
            </Box>
          ) : null}
          {row.kind === 'open' && !!row.line ? (
            <Box mt={0.5} italic style={TWO_LINES}>
              {cut(row.line, LINE_MAX)}
            </Box>
          ) : null}
          {row.kind === 'open' && offers.length > 0 ? (
            <Box
              mt={0.5}
              style={{ display: 'flex', flexWrap: 'wrap', gap: '4px' }}
            >
              {offers.map((offer) => (
                <Tag key={offer} color="#9fc3e6">
                  {offer}
                </Tag>
              ))}
            </Box>
          ) : null}
        </Stack.Item>
      </Stack>
    </Box>
  );
};

export const OutpostDirectory = (props) => {
  const { data } = useBackend<DirectoryData>();
  const rows = data.rows || [];
  return (
    <Window width={400} height={560} title="Directory">
      <Window.Content>
        <Section
          fill
          scrollable
          title={
            <Box style={ONE_LINE}>
              {cut(data.building || 'Upstairs', BUILDING_MAX)}
            </Box>
          }
        >
          {rows.length === 0 ? (
            <Box color={MUTED}>Nothing upstairs.</Box>
          ) : (
            rows.map((row) => <FloorRow key={row.number} row={row} />)
          )}
        </Section>
      </Window.Content>
    </Window>
  );
};
