/**
 * The wanted board on a trader outpost's concourse (bounty_outpost.dm, P6).
 * Read-only wanted posters: the mugshot, name, what they're wanted for,
 * where they were seen and the reward. Mugshots come in the static data.
 */
import { Box, Section, Stack } from 'tgui-core/components';
import { formatMoney } from 'tgui-core/format';

import { useBackend } from '../backend';
import { Window } from '../layouts';

type Entry = {
  id: string;
  name: string;
  alias: string | null;
  tier_level: number;
  // "Wanted alive", "Wanted dead or alive" or "Wanted dead"
  terms: string;
  crime: string | null;
  reward: number;
  vouchers?: number;
  place: string;
};

type Data = {
  entries: Entry[];
  mugshots: Record<string, string>;
};

const tierColor = (level: number) =>
  level >= 3 ? 'bad' : level === 2 ? 'average' : 'label';

/** The poster's heading: MOST WANTED for tier 3, WANTED for the rest */
const heading = (level: number) => (level >= 3 ? 'MOST WANTED' : 'WANTED');

const WantedCard = (props: { entry: Entry; mugshot?: string }) => {
  const { entry, mugshot } = props;
  const vouchers = entry.vouchers ?? 0;
  const color = tierColor(entry.tier_level);
  return (
    <Section
      title={
        <Stack>
          <Stack.Item grow minWidth={0} color={color}>
            {entry.name}
            {entry.alias ? ` "${entry.alias}"` : ''}
          </Stack.Item>
          <Stack.Item shrink={0} nowrap bold color="gold">
            {formatMoney(entry.reward)} cr
            {vouchers > 0
              ? ` + ${vouchers} voucher${vouchers > 1 ? 's' : ''}`
              : ''}
          </Stack.Item>
        </Stack>
      }
    >
      <Stack>
        <Stack.Item>
          {mugshot ? (
            <img
              src={mugshot}
              width={64}
              height={64}
              style={{ imageRendering: 'pixelated' }}
            />
          ) : (
            <Box
              width="64px"
              height="64px"
              backgroundColor="rgba(0, 0, 0, 0.3)"
              textAlign="center"
              lineHeight="64px"
              color="label"
            >
              ?
            </Box>
          )}
        </Stack.Item>
        <Stack.Item grow>
          <Box bold color={color}>
            {heading(entry.tier_level)}
          </Box>
          <Box>
            {entry.terms}
            {entry.crime ? ` for ${entry.crime}` : ''}.
          </Box>
          <Box color="label">{entry.place}.</Box>
        </Stack.Item>
      </Stack>
    </Section>
  );
};

export const WantedBoard = (props) => {
  const { data } = useBackend<Data>();
  const { entries = [], mugshots = {} } = data;

  return (
    <Window width={420} height={520}>
      <Window.Content scrollable>
        {entries.length === 0 ? (
          <Box color="label">No one is wanted right now.</Box>
        ) : (
          entries.map((entry) => (
            <WantedCard
              key={entry.id}
              entry={entry}
              mugshot={mugshots[entry.id]}
            />
          ))
        )}
      </Window.Content>
    </Window>
  );
};
