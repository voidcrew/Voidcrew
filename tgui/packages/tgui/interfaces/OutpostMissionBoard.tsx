import type { ReactNode } from 'react';

import {
  Box,
  Button,
  Icon,
  NoticeBox,
  Section,
  Stack,
  Tooltip,
} from 'tgui-core/components';
import type { BooleanLike } from 'tgui-core/react';

import { useBackend } from '../backend';
import { Window } from '../layouts';

type RewardItem = {
  name: string;
  icon: string | null;
  rare: BooleanLike;
};

type Offer = {
  ref: string;
  name: string;
  desc: string;
  author: string;
  value: number;
  reward_items?: RewardItem[];
  voucher_count: number;
  difficulty_name: string;
  difficulty_color: string;
  zone_name: string | null;
  zone_color: string;
  progress: string;
  wanted_text: string;
  archetype: string;
  time_remaining_text: string;
  favor_reward: number;
  favor_trader: string | null;
};

type FavorStanding = {
  points: number;
  tier: number;
  tier_name: string;
  discount_pct: number;
  next_at: number;
  trader: string;
};

type ShipMission = Offer & {
  from_this_shop: BooleanLike;
  location_ok: BooleanLike;
  holding_valid_item: BooleanLike;
  turn_in_hint: string | null;
  requires_item: BooleanLike;
};

type Data = {
  shop_name: string;
  trader_name: string;
  barred: BooleanLike;
  ship_name: string | null;
  ship_mission_slots_free: number;
  offers: Offer[];
  ship_missions: ShipMission[];
  favor?: FavorStanding;
};

const ARCHETYPE_ICONS = {
  procurement: 'boxes-stacked',
  salvage: 'magnet',
  bounty: 'crosshairs',
  courier: 'truck-fast',
  recovery: 'box-open',
  contract: 'file-signature',
} as const;

const archetypeIcon = (archetype: string) =>
  ARCHETYPE_ICONS[archetype as keyof typeof ARCHETYPE_ICONS] ??
  ARCHETYPE_ICONS.contract;

const RewardLine = (props: { offer: Offer }) => {
  const { offer } = props;
  const items = offer.reward_items ?? [];
  const segments: ReactNode[] = [];

  if (offer.value > 0) {
    segments.push(
      <Box as="span" bold color="gold">
        {offer.value} cr
      </Box>,
    );
  }
  for (const item of items) {
    segments.push(
      <Box as="span" bold color={item.rare ? 'orange' : 'teal'}>
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
  if (offer.voucher_count > 0) {
    segments.push(
      <Box as="span" bold color="purple">
        {offer.voucher_count} voucher{offer.voucher_count === 1 ? '' : 's'}
      </Box>,
    );
  }
  if (offer.favor_reward > 0) {
    segments.push(
      <Box as="span" bold color="orange">
        +{offer.favor_reward} standing
      </Box>,
    );
  }

  return (
    <Box>
      <Box inline color="label">
        Pays:{' '}
      </Box>
      {segments.length === 0 ? (
        <Box inline color="label">
          goods
        </Box>
      ) : (
        segments.map((segment, index) => (
          // biome-ignore lint/suspicious/noArrayIndexKey: static, order-stable list
          <Box as="span" key={index}>
            {index > 0 && <Box as="span" color="label">{' + '}</Box>}
            {segment}
          </Box>
        ))
      )}
    </Box>
  );
};

const OfferCard = (props: { offer: Offer; canAccept: boolean }) => {
  const { act } = useBackend<Data>();
  const { offer, canAccept } = props;
  return (
    <Section>
      <Stack align="center">
        <Stack.Item>
          <Icon name={archetypeIcon(offer.archetype)} size={1.6} color="label" />
        </Stack.Item>
        <Stack.Item grow>
          <Stack vertical>
            <Stack.Item bold>
              {offer.name}{' '}
              {!!offer.zone_name && (
                <Box inline color={offer.zone_color}>
                  [{offer.zone_name}]{' '}
                </Box>
              )}
              <Box inline color={offer.difficulty_color}>
                [{offer.difficulty_name}]
              </Box>
            </Stack.Item>
            <Stack.Item color="label" fontSize="0.9em">
              {offer.desc}
            </Stack.Item>
            <Stack.Item>
              <RewardLine offer={offer} />
            </Stack.Item>
          </Stack>
        </Stack.Item>
        <Stack.Item>
          <Button
            icon="file-signature"
            disabled={!canAccept}
            onClick={() => act('accept', { ref: offer.ref })}
          >
            Accept
          </Button>
        </Stack.Item>
      </Stack>
    </Section>
  );
};

const ShipMissionRow = (props: { mission: ShipMission }) => {
  const { act } = useBackend<Data>();
  const { mission } = props;
  const canTurnIn =
    !!mission.requires_item &&
    !!mission.location_ok &&
    !!mission.holding_valid_item;

  const turnInButton = (
    <Button
      icon="hand-holding-hand"
      disabled={!canTurnIn}
      onClick={() => act('turn_in', { ref: mission.ref })}
    >
      Turn In
    </Button>
  );

  return (
    <Stack align="center" py={0.5} className="candystripe">
      <Stack.Item>
        <Icon name={archetypeIcon(mission.archetype)} color="label" />
      </Stack.Item>
      <Stack.Item grow>
        <Box bold>{mission.name}</Box>
        <Box color="label" fontSize="0.85em">
          {mission.progress} · {mission.time_remaining_text} left
        </Box>
      </Stack.Item>
      <Stack.Item>
        <RewardLine offer={mission} />
      </Stack.Item>
      <Stack.Item>
        {!canTurnIn && mission.turn_in_hint ? (
          <Tooltip content={mission.turn_in_hint}>{turnInButton}</Tooltip>
        ) : (
          turnInButton
        )}
      </Stack.Item>
    </Stack>
  );
};

export const OutpostMissionBoard = (props) => {
  const { data } = useBackend<Data>();
  const {
    shop_name,
    trader_name,
    barred,
    ship_name,
    ship_mission_slots_free,
    offers = [],
    ship_missions = [],
    favor,
  } = data;

  const canAccept = !barred && !!ship_name && ship_mission_slots_free > 0;

  return (
    <Window title={`${shop_name}, Contract Board`} width={560} height={620}>
      <Window.Content scrollable>
        {!!barred && (
          <NoticeBox danger>
            TRADE EMBARGO IN EFFECT: {trader_name} is not posting work for
            you.
          </NoticeBox>
        )}
        {!ship_name && (
          <NoticeBox>
            No crew registration found: you need a ship to take a contract.
          </NoticeBox>
        )}
        <Section
          title={`${trader_name}'s postings`}
          buttons={
            ship_name ? (
              <Box inline color="label">
                {!!favor && (
                  <Tooltip
                    content={`Completing ${favor.trader}'s contracts earns standing: discounts at each tier, back-room stock at Trusted.`}
                  >
                    <Box inline>
                      <Box
                        inline
                        bold
                        color={favor.tier >= 3 ? 'orange' : 'good'}
                      >
                        {favor.tier_name}
                      </Box>
                      {favor.next_at > 0 && (
                        <Box inline>
                          {' '}
                          ({favor.points}/{favor.next_at})
                        </Box>
                      )}
                      {' · '}
                    </Box>
                  </Tooltip>
                )}
                {ship_name} · {ship_mission_slots_free} slot
                {ship_mission_slots_free === 1 ? '' : 's'} free
              </Box>
            ) : null
          }
        >
          {offers.length === 0 && (
            <Box color="label">Nothing posted right now.</Box>
          )}
          {offers.map((offer) => (
            <OfferCard key={offer.ref} offer={offer} canAccept={canAccept} />
          ))}
        </Section>
        {ship_missions.length > 0 && (
          <Section title="Your ship's active contracts">
            {ship_missions.map((mission) => (
              <ShipMissionRow key={mission.ref} mission={mission} />
            ))}
            <Box color="label" fontSize="0.85em" mt={1}>
              Item contracts can be turned in right here. Hold the goods in
              hand. Courier pods only unseal at their destination outpost.
            </Box>
          </Section>
        )}
      </Window.Content>
    </Window>
  );
};
