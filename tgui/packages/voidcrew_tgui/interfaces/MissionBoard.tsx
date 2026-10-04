import { type ReactNode, useState } from 'react';

import {
  Box,
  Button,
  Divider,
  Flex,
  Input,
  LabeledList,
  NoticeBox,
  NumberInput,
  ProgressBar,
  Section,
  Stack,
  Tabs,
  TextArea,
} from 'tgui-core/components';
import { formatMoney } from 'tgui-core/format';
import type { BooleanLike } from 'tgui-core/react';

import { useBackend } from '../../tgui/backend';
import { Window } from '../../tgui/layouts';

type RewardItem = {
  name: string;
  icon: string | null;
  rare: BooleanLike;
};

type Mission = {
  ref: string;
  name: string;
  desc: string;
  author: string;
  value: number;
  reward_items?: RewardItem[];
  reward_item: string | null;
  reward_item_icon: string | null;
  duration: number;
  time_remaining: number;
  time_remaining_text: string;
  progress: string;
  can_complete: BooleanLike;
  active: BooleanLike;
  requires_item?: BooleanLike;
  voucher_count?: number;
  research_reward?: number;
  target_x?: number;
  target_y?: number;
  visited?: BooleanLike;
  difficulty: number;
  difficulty_name: string;
  difficulty_color: string;
  zone_name: string | null;
  zone_color: string;
};

type PadItem = {
  name: string;
  ref: string;
};

type Bounty = {
  ref: string;
  name: string;
  desc: string;
  reward: number;
  hunter_count: number;
  is_hunting: boolean;
  was_abandoned: boolean;
  zone: string;
  tracking_cost: number;
  has_tracking?: boolean;
  effective_reward?: number;
  target_x?: number;
  target_y?: number;
  loot_description: string;
};

type PendingOffer = {
  ship_ref: string;
  ship_name: string;
  items: string[];
};

type PlayerBounty = {
  ref: string;
  name: string;
  desc: string;
  reward: number;
  status: 'available' | 'completed' | 'cancelled';
  creator_name?: string;
  is_creator: boolean;
  is_claimer: boolean;
  was_abandoned?: boolean;
  has_pending_offer?: boolean;
  can_claim: boolean;
  contractor_count: number;
  pending_offers?: PendingOffer[];
};

type Data = {
  has_ship: BooleanLike;
  max_missions: number;
  active_count: number;
  has_pad: BooleanLike;
  has_mod_gps: BooleanLike;
  available_missions: Mission[];
  active_missions: Mission[];
  pad_contents: PadItem[];
  bounties: Bounty[];
  has_active_bounty: BooleanLike;
  player_bounties: PlayerBounty[];
  has_created_bounty: BooleanLike;
  has_claimed_player_bounty: BooleanLike;
  ship_balance: number;
  refresh_cooldown_remaining: number;
  // Wanted criminals (voidcrew/modules/bounties/bounty_board.dm)
  wanted?: WantedEntry[];
  // Static data: record id -> base64 mugshot, never sent in the live data
  wanted_mugshots?: Record<string, string>;
};

/** One wanted criminal on the board: a public bounty or this ship's private offer. */
type WantedEntry = {
  ref: string;
  name?: string;
  alias?: string | null;
  species?: string;
  sex?: string;
  tier?: number;
  // "Wanted alive", "Wanted dead or alive" or "Wanted dead"
  terms?: string;
  crime?: string | null;
  place?: string;
  zone?: string;
  zone_color?: string;
  mugshot_id?: string | null;
  value?: number;
  vouchers?: number;
  time_left?: number;
  private?: BooleanLike;
  hunting_by_us?: BooleanLike;
  hunt_refusal?: string | null;
  // The mugshot is how they looked before (a trader-outpost fugitive)
  photo_old?: BooleanLike;
  can_turn_in?: BooleanLike;
  turn_in_refusal?: string | null;
};

export const MissionBoard = () => {
  const { data } = useBackend<Data>();
  const { has_ship } = data;

  return (
    <Window width={550} height={600}>
      <Window.Content scrollable>
        {!has_ship ? (
          <NoticeBox danger>Console not connected to a ship!</NoticeBox>
        ) : (
          <MissionBoardContent />
        )}
      </Window.Content>
    </Window>
  );
};

/** One card in a list */
type ListItem = {
  key: string;
  node: ReactNode;
};

/** A fixed hash of a card's key (FNV-1a, then mixed: refs that differ in one digit land far apart) */
const shuffleHash = (key: string) => {
  let hash = 2166136261;
  for (let i = 0; i < key.length; i++) {
    hash ^= key.charCodeAt(i);
    hash = Math.imul(hash, 16777619);
  }
  hash ^= hash >>> 16;
  hash = Math.imul(hash, 0x85ebca6b);
  hash ^= hash >>> 13;
  hash = Math.imul(hash, 0xc2b2ae35);
  hash ^= hash >>> 16;
  return hash >>> 0;
};

/** Spreads every kind of card evenly down the list, each at its own fixed point in its share, so no kind bunches up */
const shuffleKinds = (items: ListItem[]) => {
  const kinds: Record<string, ListItem[]> = {};
  for (const item of items) {
    const kind = item.key.slice(0, item.key.indexOf('-'));
    if (!kinds[kind]) {
      kinds[kind] = [];
    }
    kinds[kind].push(item);
  }
  const placed: { item: ListItem; place: number }[] = [];
  for (const group of Object.values(kinds)) {
    group.sort((a, b) => shuffleHash(a.key) - shuffleHash(b.key));
    group.forEach((item, i) => {
      const jitter = shuffleHash(`${item.key}~`) / 2 ** 32;
      placed.push({ item, place: (i + jitter) / group.length });
    });
  }
  return placed.sort((a, b) => a.place - b.place).map((entry) => entry.item);
};

const MissionBoardContent = () => {
  const { act, data } = useBackend<Data>();
  const {
    has_pad,
    has_mod_gps,
    available_missions,
    active_missions,
    pad_contents,
    bounties,
    has_active_bounty,
    player_bounties,
    has_created_bounty,
    has_claimed_player_bounty,
    ship_balance,
    refresh_cooldown_remaining,
    wanted = [],
    wanted_mugshots = {},
  } = data;

  const [currentTab, setCurrentTab] = useState<'available' | 'active'>(
    'available',
  );
  const [posting, setPosting] = useState(false);

  const mugshotOf = (entry: WantedEntry) =>
    entry.mugshot_id ? wanted_mugshots[entry.mugshot_id] : undefined;

  // Everything on offer in one list, every kind mixed together
  const offered: ListItem[] = shuffleKinds([
    ...available_missions.map((mission) => ({
      key: `mission-${mission.ref}`,
      node: <MissionCard mission={mission} isActive={false} />,
    })),
    ...wanted
      .filter((entry) => !entry.hunting_by_us)
      .map((entry) => ({
        key: `wanted-${entry.ref}`,
        node: (
          <WantedCard
            entry={entry}
            mugshot={mugshotOf(entry)}
            hasPad={!!has_pad}
          />
        ),
      })),
    ...bounties
      .filter((bounty) => !bounty.is_hunting)
      .map((bounty) => ({
        key: `bounty-${bounty.ref}`,
        node: (
          <BountyCard
            bounty={bounty}
            hasPad={!!has_pad}
            hasActiveBounty={!!has_active_bounty}
          />
        ),
      })),
    ...player_bounties
      .filter(
        (bounty) =>
          !bounty.is_creator &&
          !bounty.is_claimer &&
          bounty.status === 'available',
      )
      .map((bounty) => ({
        key: `contract-${bounty.ref}`,
        node: (
          <PlayerBountyCard
            bounty={bounty}
            hasPad={!!has_pad}
            hasClaimedBounty={!!has_claimed_player_bounty}
          />
        ),
      })),
  ]);

  // Everything taken on
  const taken: ListItem[] = [
    ...active_missions.map((mission) => ({
      key: `mission-${mission.ref}`,
      node: (
        <MissionCard mission={mission} isActive padContents={pad_contents} />
      ),
    })),
    ...wanted
      .filter((entry) => !!entry.hunting_by_us)
      .map((entry) => ({
        key: `wanted-${entry.ref}`,
        node: (
          <WantedCard
            entry={entry}
            mugshot={mugshotOf(entry)}
            hasPad={!!has_pad}
          />
        ),
      })),
    ...bounties
      .filter((bounty) => !!bounty.is_hunting)
      .map((bounty) => ({
        key: `bounty-${bounty.ref}`,
        node: (
          <BountyCard
            bounty={bounty}
            hasPad={!!has_pad}
            hasActiveBounty={!!has_active_bounty}
          />
        ),
      })),
  ];
  const contracts =
    (has_created_bounty ? 1 : 0) + (has_claimed_player_bounty ? 1 : 0);
  const activeCount = taken.length + contracts;

  return (
    <Stack fill vertical>
      <Stack.Item>
        <Section
          title="Mission Control"
          buttons={
            <>
              {!has_created_bounty && (
                <Button
                  icon="bullhorn"
                  selected={posting}
                  onClick={() => setPosting(!posting)}
                >
                  Post Bounty
                </Button>
              )}
              <Button
                icon="sync"
                disabled={refresh_cooldown_remaining > 0}
                onClick={() => act('refresh')}
              >
                {refresh_cooldown_remaining > 0
                  ? `Refresh (${refresh_cooldown_remaining}s)`
                  : 'Refresh'}
              </Button>
            </>
          }
        >
          <LabeledList>
            <LabeledList.Item label="Mission Pad">
              <Box color={has_pad ? 'good' : 'bad'}>
                {has_pad ? 'Connected' : 'Not Found'}
              </Box>
            </LabeledList.Item>
            <LabeledList.Item label="MOD GPS">
              <Button
                icon="location-dot"
                disabled={!has_mod_gps}
                tooltip={has_mod_gps ? undefined : 'No MODsuit GPS'}
                onClick={() => act('link_mod_gps')}
              >
                Link Mission Beacons
              </Button>
            </LabeledList.Item>
          </LabeledList>
        </Section>
      </Stack.Item>

      {posting && !has_created_bounty && (
        <Stack.Item>
          <PlayerBountyCreator
            shipBalance={ship_balance}
            onPosted={() => setPosting(false)}
          />
        </Stack.Item>
      )}

      {currentTab === 'active' && !!has_pad && pad_contents.length > 0 && (
        <Stack.Item>
          <Section title="Items on Pad">
            {pad_contents.map((item) => (
              <Box key={item.ref} className="candystripe" p={0.5}>
                {item.name}
              </Box>
            ))}
          </Section>
        </Stack.Item>
      )}

      <Stack.Item>
        <Tabs fluid>
          <Tabs.Tab
            selected={currentTab === 'available'}
            onClick={() => setCurrentTab('available')}
          >
            Available ({offered.length})
          </Tabs.Tab>
          <Tabs.Tab
            selected={currentTab === 'active'}
            onClick={() => setCurrentTab('active')}
          >
            Active ({activeCount})
          </Tabs.Tab>
        </Tabs>
      </Stack.Item>

      <Stack.Item grow>
        {currentTab === 'available' && (
          <Section fill scrollable>
            {offered.length === 0 ? (
              <NoticeBox>Nothing posted right now.</NoticeBox>
            ) : (
              <Stack vertical>
                {offered.map((item) => (
                  <Stack.Item key={item.key}>{item.node}</Stack.Item>
                ))}
              </Stack>
            )}
          </Section>
        )}

        {currentTab === 'active' && (
          <Section fill scrollable>
            {activeCount === 0 ? (
              <NoticeBox>Nothing taken on.</NoticeBox>
            ) : (
              <Stack vertical>
                {taken.map((item) => (
                  <Stack.Item key={item.key}>{item.node}</Stack.Item>
                ))}
                {contracts > 0 && (
                  <Stack.Item>
                    <PlayerBountyStatus
                      playerBounties={player_bounties}
                      hasPad={!!has_pad}
                    />
                  </Stack.Item>
                )}
              </Stack>
            )}
          </Section>
        )}
      </Stack.Item>
    </Stack>
  );
};

type MissionCardProps = {
  mission: Mission;
  isActive: boolean;
  padContents?: PadItem[];
};

/**
 * Renders a mission's full payout: credits, each item in the reward bundle
 * (rare picks accented), research points and vouchers, as " + "-joined
 * segments. `full` spells out "credits" for the detail view; the compact form
 * says "cr".
 */
const RewardSummary = (props: { mission: Mission; full?: boolean }) => {
  const { mission, full } = props;
  const items = mission.reward_items ?? [];
  const segments: ReactNode[] = [];

  if (mission.value > 0) {
    segments.push(
      <Box as="span" bold color="good">
        {mission.value}
        {full ? ' credits' : ' cr'}
      </Box>,
    );
  }
  for (const item of items) {
    segments.push(
      <Box as="span" bold color={item.rare ? 'orange' : 'average'}>
        {!!item.icon && (
          <img
            src={`data:image/png;base64,${item.icon}`}
            style={{
              verticalAlign: 'middle',
              marginRight: '4px',
              maxHeight: '1.6em',
              maxWidth: '1.6em',
            }}
          />
        )}
        {item.name}
      </Box>,
    );
  }
  if (mission.research_reward) {
    segments.push(
      <Box as="span" bold color="teal">
        {mission.research_reward}
        {full ? ' research points' : ' RP'}
      </Box>,
    );
  }
  if (mission.voucher_count) {
    segments.push(
      <Box as="span" bold color="gold">
        {mission.voucher_count} trade voucher
        {mission.voucher_count > 1 ? 's' : ''}
      </Box>,
    );
  }

  return (
    <>
      {segments.map((segment, index) => (
        <Box as="span" key={index}>
          {index > 0 && (
            <Box as="span" color="label">
              {' + '}
            </Box>
          )}
          {segment}
        </Box>
      ))}
    </>
  );
};

const MissionCard = (props: MissionCardProps) => {
  const { act, data } = useBackend<Data>();
  const { mission, isActive, padContents = [] } = props;
  const { active_count, max_missions } = data;

  const canAccept = !isActive && active_count < max_missions;

  // Format time remaining
  const formatTime = (ms: number) => {
    const totalSeconds = Math.floor(ms / 10);
    const minutes = Math.floor(totalSeconds / 60);
    const seconds = totalSeconds % 60;
    return `${minutes}:${seconds.toString().padStart(2, '0')}`;
  };

  return (
    <Section
      className="MissionBoard__card"
      title={mission.name}
      buttons={
        <Box inline>
          {!!mission.zone_name && (
            <Box inline color={mission.zone_color} mr={1}>
              [{mission.zone_name}]
            </Box>
          )}
          <Box inline color={mission.difficulty_color} mr={1}>
            [{mission.difficulty_name}]
          </Box>
          <RewardSummary mission={mission} />
        </Box>
      }
    >
      <Box italic color="label" mb={1}>
        From: {mission.author}
      </Box>
      <Box mb={1}>{mission.desc}</Box>

      {/* Rewards summary */}
      <Box mb={1}>
        <Box as="span" color="label">
          Rewards:{' '}
        </Box>
        <RewardSummary mission={mission} full />
      </Box>

      {!!isActive && (
        <>
          <LabeledList>
            <LabeledList.Item label="Time Remaining">
              <ProgressBar
                value={mission.time_remaining}
                maxValue={mission.duration}
                ranges={{
                  good: [mission.duration * 0.5, Infinity],
                  average: [mission.duration * 0.25, mission.duration * 0.5],
                  bad: [0, mission.duration * 0.25],
                }}
              >
                {mission.time_remaining_text}
              </ProgressBar>
            </LabeledList.Item>
            {!!mission.progress && (
              <LabeledList.Item label="Progress">
                {mission.progress}
              </LabeledList.Item>
            )}
          </LabeledList>
          <Divider />
          {mission.requires_item ? (
            <Button
              icon="check"
              color="good"
              disabled={!mission.can_complete && padContents.length === 0}
              onClick={() => act('turn_in', { ref: mission.ref })}
            >
              Turn In
            </Button>
          ) : (
            <Button
              icon="check"
              color="good"
              disabled={!mission.can_complete}
              onClick={() => act('turn_in', { ref: mission.ref })}
            >
              Complete
            </Button>
          )}
        </>
      )}

      {!isActive && (
        <Button
          fluid
          icon="plus"
          color="good"
          disabled={!canAccept}
          tooltip={canAccept ? undefined : 'Mission slots full'}
          onClick={() => act('accept', { ref: mission.ref })}
        >
          Accept Mission
        </Button>
      )}
    </Section>
  );
};

type BountyCardProps = {
  bounty: Bounty;
  hasPad: boolean;
  hasActiveBounty: boolean;
};

const BountyCard = (props: BountyCardProps) => {
  const { act } = useBackend<Data>();
  const { bounty, hasPad, hasActiveBounty } = props;

  // Can't accept if: already hunting one, abandoned this one, or already hunting this one
  const canAccept =
    !hasActiveBounty && !bounty.was_abandoned && !bounty.is_hunting;

  // Determine why we can't accept
  const getDisabledReason = () => {
    if (bounty.was_abandoned) return 'You abandoned this bounty';
    if (hasActiveBounty) return 'Already hunting a bounty';
    return undefined;
  };

  // Display effective reward if hunting (may be reduced by tracking)
  const displayReward = bounty.is_hunting
    ? (bounty.effective_reward ?? bounty.reward)
    : bounty.reward;

  return (
    <Section
      className="MissionBoard__card"
      title={
        <Box inline color={bounty.was_abandoned ? 'gray' : undefined}>
          <Box as="span" color={bounty.was_abandoned ? 'gray' : 'red'} mr={1}>
            ☠
          </Box>
          {bounty.name}
        </Box>
      }
      buttons={
        <Box inline>
          <Box
            inline
            color={bounty.was_abandoned ? 'gray' : 'gold'}
            bold
            mr={1}
          >
            {displayReward} cr
            {!!bounty.has_tracking && (
              <Box as="span" color="label" ml={1}>
                (-{bounty.tracking_cost})
              </Box>
            )}
          </Box>
          <Box inline color="label">
            [{bounty.zone}]
          </Box>
        </Box>
      }
    >
      <Box mb={1} color={bounty.was_abandoned ? 'gray' : undefined}>
        {bounty.desc}
      </Box>

      <Box mb={1}>
        <Box as="span" color="label">
          Rewards:{' '}
        </Box>
        <Box as="span" color="good" bold>
          {displayReward} cr
        </Box>
        <Box as="span" color="average" bold>
          {' '}
          + {bounty.loot_description}
        </Box>
      </Box>

      {/* Show coordinates if tracking is enabled */}
      {!!bounty.has_tracking &&
        bounty.target_x !== undefined &&
        bounty.target_y !== undefined && (
          <Box mb={1} p={1} backgroundColor="rgba(0, 255, 0, 0.1)">
            <Box color="good" bold>
              Target Coordinates: ({bounty.target_x}, {bounty.target_y})
            </Box>
          </Box>
        )}

      <Flex justify="space-between" align="center" mb={1}>
        <Flex.Item>
          <Box color="label">
            <Box as="span" color={bounty.hunter_count > 0 ? 'orange' : 'gray'}>
              ⚔ {bounty.hunter_count} crew{bounty.hunter_count !== 1 ? 's' : ''}{' '}
              hunting
            </Box>
          </Box>
        </Flex.Item>
      </Flex>

      <Divider />

      <Flex justify="space-between">
        <Flex.Item grow>
          {bounty.is_hunting ? (
            <Stack>
              <Stack.Item grow>
                <Button
                  fluid
                  icon="crosshairs"
                  color="green"
                  disabled={!hasPad}
                  tooltip={hasPad ? undefined : 'No mission pad'}
                  onClick={() => act('turn_in_bounty', { ref: bounty.ref })}
                >
                  Turn In Key
                </Button>
              </Stack.Item>
              {!bounty.has_tracking && (
                <Stack.Item>
                  <Button
                    icon="satellite-dish"
                    color="teal"
                    onClick={() => act('enable_tracking', { ref: bounty.ref })}
                  >
                    Track (-{bounty.tracking_cost})
                  </Button>
                </Stack.Item>
              )}
              <Stack.Item>
                <Button
                  icon="times"
                  color="bad"
                  onClick={() => act('cancel_bounty', { ref: bounty.ref })}
                >
                  Cancel
                </Button>
              </Stack.Item>
            </Stack>
          ) : (
            <Button
              fluid
              icon="skull"
              color={canAccept ? 'caution' : 'gray'}
              disabled={!canAccept}
              tooltip={getDisabledReason()}
              onClick={() => act('accept_bounty', { ref: bounty.ref })}
            >
              {bounty.was_abandoned ? 'Abandoned' : 'Accept Bounty'}
            </Button>
          )}
        </Flex.Item>
      </Flex>
    </Section>
  );
};

// ========== WANTED COMPONENTS ==========

/** Name colour for each tier: Petty, Wanted, Most Wanted */
const WANTED_TIER_COLORS: Record<number, string> = {
  1: 'average',
  2: 'orange',
  3: 'bad',
};

/** The poster's heading: MOST WANTED for tier 3, WANTED for the rest */
const wantedHeading = (tier?: number) =>
  tier === 3 ? 'MOST WANTED' : 'WANTED';

/** A server phrase as the start of a sentence */
const toSentence = (text?: string | null) =>
  text ? text.charAt(0).toUpperCase() + text.slice(1) : undefined;

const formatWantedTime = (seconds: number) => {
  const total = Math.max(0, Math.floor(seconds));
  const minutes = Math.floor(total / 60);
  const rest = total % 60;
  return `${minutes}:${rest.toString().padStart(2, '0')}`;
};

type WantedCardProps = {
  entry: WantedEntry;
  mugshot?: string;
  hasPad: boolean;
};

/** A wanted poster: picture, name, what they're wanted for, where they were seen, the reward. */
const WantedCard = (props: WantedCardProps) => {
  const { act } = useBackend<Data>();
  const { entry, mugshot, hasPad } = props;

  const tierColor = WANTED_TIER_COLORS[entry.tier ?? 1] ?? 'label';
  const vouchers = entry.vouchers ?? 0;
  const hunting = !!entry.hunting_by_us;
  const isOffer = !!entry.private;
  const huntRefusal = toSentence(entry.hunt_refusal);
  const description = [
    entry.species,
    entry.sex && entry.sex !== 'Unknown' ? entry.sex.toLowerCase() : null,
  ]
    .filter(Boolean)
    .join(', ');

  return (
    <Section
      className="MissionBoard__card"
      title={
        <Box inline color={tierColor}>
          {entry.name || 'Unknown'}
        </Box>
      }
      buttons={
        <Box inline bold color="gold">
          {formatMoney(entry.value ?? 0)} cr
          {vouchers > 0
            ? ` + ${vouchers} voucher${vouchers > 1 ? 's' : ''}`
            : ''}
        </Box>
      }
    >
      <Flex mb={1}>
        <Flex.Item mr={1} textAlign="center">
          {mugshot ? (
            <img
              src={`data:image/png;base64,${mugshot}`}
              width={64}
              height={64}
              style={{
                imageRendering: 'pixelated',
                border: '1px solid rgba(255, 255, 255, 0.2)',
                backgroundColor: 'rgba(0, 0, 0, 0.3)',
              }}
            />
          ) : (
            <Box
              width="64px"
              height="64px"
              lineHeight="64px"
              textAlign="center"
              color="label"
              backgroundColor="rgba(0, 0, 0, 0.3)"
            >
              ?
            </Box>
          )}
          {entry.photo_old ? (
            <Box fontSize="0.8em" italic color="label">
              Old photo
            </Box>
          ) : null}
        </Flex.Item>
        <Flex.Item grow>
          <Box bold color={tierColor}>
            {wantedHeading(entry.tier)}
            {isOffer ? (
              <Box as="span" color="teal" ml={1}>
                Private offer
              </Box>
            ) : null}
          </Box>
          <Box>
            {entry.terms || 'Wanted alive'}
            {entry.crime ? ` for ${entry.crime}` : ''}.
          </Box>
          {description ? (
            <Box color="label">
              {description}
              {entry.alias && entry.alias !== entry.name
                ? `. Goes by ${entry.alias}`
                : ''}
              .
            </Box>
          ) : null}
          <Box color="label">
            {entry.place || 'Last seen: unknown'}{' '}
            <Box as="span" color={entry.zone_color || 'label'}>
              [{entry.zone || 'Unknown Zone'}]
            </Box>
          </Box>
          <Box color="label">{formatWantedTime(entry.time_left ?? 0)} left</Box>
        </Flex.Item>
      </Flex>

      <Stack>
        <Stack.Item grow>
          {hunting ? (
            <Button
              fluid
              icon="times"
              color="bad"
              onClick={() => act('abandon_wanted', { ref: entry.ref })}
            >
              {isOffer ? 'Drop Offer' : 'Abandon'}
            </Button>
          ) : (
            <Button
              fluid
              icon="crosshairs"
              color="caution"
              disabled={!!huntRefusal}
              tooltip={huntRefusal}
              onClick={() => act('hunt_wanted', { ref: entry.ref })}
            >
              {isOffer ? 'Accept Offer' : 'Hunt'}
            </Button>
          )}
        </Stack.Item>
        <Stack.Item>
          <Button
            icon="check"
            color="good"
            disabled={!hasPad || !entry.can_turn_in}
            tooltip={
              !hasPad
                ? 'No mission pad'
                : entry.can_turn_in
                  ? undefined
                  : toSentence(entry.turn_in_refusal)
            }
            onClick={() => act('turn_in_wanted', { ref: entry.ref })}
          >
            Turn In
          </Button>
        </Stack.Item>
        <Stack.Item>
          <Button
            icon="print"
            disabled={!hasPad}
            tooltip={hasPad ? undefined : 'No mission pad'}
            onClick={() => act('print_warrant', { ref: entry.ref })}
          >
            Warrant
          </Button>
        </Stack.Item>
      </Stack>
    </Section>
  );
};

// ========== PLAYER BOUNTY COMPONENTS ==========

type PlayerBountyCreatorProps = {
  shipBalance: number;
  onPosted: () => void;
};

const PlayerBountyCreator = (props: PlayerBountyCreatorProps) => {
  const { act } = useBackend<Data>();
  const { shipBalance, onPosted } = props;

  const [reward, setReward] = useState(500);
  const [bountyName, setBountyName] = useState('');
  const [bountyDesc, setBountyDesc] = useState('');

  return (
    <Section title="Post Bounty">
      <LabeledList>
        <LabeledList.Item label="Ship Balance">
          <Box color={shipBalance >= 100 ? 'good' : 'bad'}>
            {shipBalance} cr
          </Box>
        </LabeledList.Item>
        <LabeledList.Item label="Title">
          <Input
            placeholder="Bounty name..."
            width="100%"
            maxLength={64}
            value={bountyName}
            onChange={(value) => setBountyName(value)}
          />
        </LabeledList.Item>
        <LabeledList.Item label="Objective">
          <TextArea
            placeholder="Describe what needs to be done..."
            width="100%"
            height="60px"
            maxLength={256}
            value={bountyDesc}
            onChange={(value) => setBountyDesc(value)}
          />
        </LabeledList.Item>
        <LabeledList.Item label="Reward">
          <NumberInput
            value={reward}
            minValue={100}
            maxValue={Math.min(50000, shipBalance)}
            step={100}
            width="100px"
            onChange={(value) => setReward(value)}
          />
          <Box as="span" color="label" ml={1}>
            cr
          </Box>
        </LabeledList.Item>
      </LabeledList>
      <Divider />
      <Button
        fluid
        icon="plus"
        color="good"
        disabled={
          shipBalance < reward || bountyName.length < 3 || bountyDesc.length < 5
        }
        tooltip={
          shipBalance < reward
            ? 'Insufficient funds'
            : bountyName.length < 3
              ? 'Title too short'
              : bountyDesc.length < 5
                ? 'Objective too short'
                : undefined
        }
        onClick={() => {
          act('create_bounty', {
            reward,
            name: bountyName,
            desc: bountyDesc,
          });
          setBountyName('');
          setBountyDesc('');
          onPosted();
        }}
      >
        Post Bounty
      </Button>
    </Section>
  );
};

type PlayerBountyStatusProps = {
  playerBounties: PlayerBounty[];
  hasPad: boolean;
};

const PlayerBountyStatus = (props: PlayerBountyStatusProps) => {
  const { act } = useBackend<Data>();
  const { playerBounties, hasPad } = props;

  const createdBounty = playerBounties.find((b) => b.is_creator);
  const claimedBounty = playerBounties.find((b) => b.is_claimer);

  return (
    <>
      {/* Show created bounty */}
      {!!createdBounty && (
        <Section
          title="Your Bounty"
          buttons={
            <Button
              icon="times"
              color="bad"
              onClick={() => act('cancel_player_bounty')}
            >
              Cancel
            </Button>
          }
        >
          <LabeledList>
            <LabeledList.Item label="Name">
              {createdBounty.name}
            </LabeledList.Item>
            <LabeledList.Item label="Reward">
              <Box color="gold">{createdBounty.reward} cr</Box>
            </LabeledList.Item>
            <LabeledList.Item label="Contractors">
              <Box
                color={createdBounty.contractor_count > 0 ? 'good' : 'average'}
              >
                {createdBounty.contractor_count > 0
                  ? `${createdBounty.contractor_count} ship${createdBounty.contractor_count !== 1 ? 's' : ''} accepted`
                  : 'Waiting for contractors'}
              </Box>
            </LabeledList.Item>
          </LabeledList>

          {/* Show pending offers to approve/reject */}
          {!!createdBounty.pending_offers &&
            createdBounty.pending_offers.length > 0 && (
              <Box mt={1}>
                <Divider />
                <Box color="good" bold mb={1}>
                  Pending Offers:
                </Box>
                <Stack vertical>
                  {createdBounty.pending_offers.map((offer) => (
                    <Stack.Item key={offer.ship_ref}>
                      <Section
                        className="MissionBoard__card"
                        title={offer.ship_name}
                        buttons={
                          <Stack>
                            <Stack.Item>
                              <Button
                                icon="check"
                                color="good"
                                onClick={() =>
                                  act('approve_bounty_offer', {
                                    ship_ref: offer.ship_ref,
                                  })
                                }
                              >
                                Approve
                              </Button>
                            </Stack.Item>
                            <Stack.Item>
                              <Button
                                icon="times"
                                color="bad"
                                onClick={() =>
                                  act('reject_bounty_offer', {
                                    ship_ref: offer.ship_ref,
                                  })
                                }
                              >
                                Reject
                              </Button>
                            </Stack.Item>
                          </Stack>
                        }
                      >
                        <Box color="label">Offering:</Box>
                        {offer.items.map((item, idx) => (
                          <Box key={idx} ml={1}>
                            • {item}
                          </Box>
                        ))}
                      </Section>
                    </Stack.Item>
                  ))}
                </Stack>
              </Box>
            )}
        </Section>
      )}

      {/* Show claimed bounty */}
      {!!claimedBounty && (
        <Section
          title="Accepted Contract"
          buttons={
            <Button
              icon="times"
              color="bad"
              onClick={() =>
                act('abandon_player_bounty', { ref: claimedBounty.ref })
              }
            >
              Abandon
            </Button>
          }
        >
          <LabeledList>
            <LabeledList.Item label="Name">
              {claimedBounty.name}
            </LabeledList.Item>
            <LabeledList.Item label="From">
              {claimedBounty.creator_name || 'Unknown'}
            </LabeledList.Item>
            <LabeledList.Item label="Reward">
              <Box color="gold">{claimedBounty.reward} cr</Box>
            </LabeledList.Item>
            <LabeledList.Item label="Competition">
              <Box
                color={claimedBounty.contractor_count > 1 ? 'orange' : 'good'}
              >
                {claimedBounty.contractor_count > 1
                  ? `${claimedBounty.contractor_count - 1} other ship${claimedBounty.contractor_count > 2 ? 's' : ''} competing`
                  : 'No competition'}
              </Box>
            </LabeledList.Item>
            <LabeledList.Item label="Objective">
              {claimedBounty.desc}
            </LabeledList.Item>
          </LabeledList>

          <Box mt={1}>
            {claimedBounty.has_pending_offer ? (
              <Button
                fluid
                icon="undo"
                color="caution"
                onClick={() => act('withdraw_bounty_offer')}
              >
                Withdraw Offer
              </Button>
            ) : (
              <Button
                fluid
                icon="paper-plane"
                color="good"
                disabled={!hasPad}
                tooltip={hasPad ? undefined : 'No mission pad'}
                onClick={() => act('make_bounty_offer')}
              >
                Submit Offer
              </Button>
            )}
          </Box>
        </Section>
      )}
    </>
  );
};

type PlayerBountyCardProps = {
  bounty: PlayerBounty;
  hasPad: boolean;
  hasClaimedBounty: boolean;
};

const PlayerBountyCard = (props: PlayerBountyCardProps) => {
  const { act } = useBackend<Data>();
  const { bounty, hasPad, hasClaimedBounty } = props;

  const canClaim = bounty.can_claim && !hasClaimedBounty;

  // Determine why we can't claim
  const getDisabledReason = () => {
    if (bounty.was_abandoned) return 'You abandoned this contract';
    if (hasClaimedBounty) return 'Already accepted a contract';
    if (!bounty.can_claim) return 'Cannot accept this contract';
    return undefined;
  };

  return (
    <Section
      className="MissionBoard__card"
      title={
        <Box inline color={bounty.was_abandoned ? 'gray' : undefined}>
          {bounty.name}
        </Box>
      }
      buttons={
        <Box inline color={bounty.was_abandoned ? 'gray' : 'gold'} bold>
          {bounty.reward} cr
        </Box>
      }
    >
      <Box mb={1} italic color="label">
        From: {bounty.creator_name || 'Unknown'}
      </Box>
      <Box mb={1} color={bounty.was_abandoned ? 'gray' : undefined}>
        {bounty.desc}
      </Box>

      <Flex justify="space-between" align="center" mb={1}>
        <Flex.Item>
          <Box color="label">
            <Box
              as="span"
              color={bounty.contractor_count > 0 ? 'orange' : 'gray'}
            >
              {bounty.contractor_count} contractor
              {bounty.contractor_count !== 1 ? 's' : ''}
            </Box>
          </Box>
        </Flex.Item>
        <Flex.Item>
          {!!bounty.was_abandoned && (
            <Box color="bad" bold>
              [ABANDONED]
            </Box>
          )}
        </Flex.Item>
      </Flex>

      <Button
        fluid
        icon="handshake"
        color={canClaim ? 'good' : 'gray'}
        disabled={!canClaim}
        tooltip={getDisabledReason()}
        onClick={() => act('claim_player_bounty', { ref: bounty.ref })}
      >
        {bounty.was_abandoned ? 'Abandoned' : 'Accept Contract'}
      </Button>
    </Section>
  );
};
