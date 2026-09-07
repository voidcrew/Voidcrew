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
import type { BooleanLike } from 'tgui-core/react';

import { useBackend } from '../backend';
import { Window } from '../layouts';

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
  outpost_adverts: OutpostAdvert[];
};

type OutpostAdvert = {
  name: string;
  blurb: string;
  x: number;
  y: number;
  remaining_minutes: number;
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

const MissionBoardContent = () => {
  const { act, data } = useBackend<Data>();
  const {
    max_missions,
    active_count,
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
    outpost_adverts = [],
  } = data;

  const [currentTab, setCurrentTab] = useState<
    'available' | 'active' | 'bounties' | 'broadcasts'
  >('available');

  const huntingCount = bounties.filter((b) => b.is_hunting).length;

  return (
    <Stack fill vertical>
      {/* Header */}
      <Stack.Item>
        <Section
          title="Mission Control"
          buttons={
            <Button
              icon="sync"
              disabled={refresh_cooldown_remaining > 0}
              onClick={() => act('refresh')}
            >
              {refresh_cooldown_remaining > 0
                ? `Refresh (${refresh_cooldown_remaining}s)`
                : 'Refresh'}
            </Button>
          }
        >
          <LabeledList>
            <LabeledList.Item label="Active Missions">
              {active_count} / {max_missions}
            </LabeledList.Item>
            <LabeledList.Item label="Mission Pad">
              <Box color={has_pad ? 'good' : 'bad'}>
                {has_pad ? 'Connected' : 'Not Found'}
              </Box>
            </LabeledList.Item>
            <LabeledList.Item label="MOD GPS">
              <Button
                icon="location-dot"
                disabled={!has_mod_gps}
                tooltip={
                  has_mod_gps
                    ? 'Upload active mission beacons to your worn MODsuit GPS.'
                    : 'Wear a MODsuit with an installed GPS module to link it here.'
                }
                onClick={() => act('link_mod_gps')}
              >
                Link Mission Beacons
              </Button>
            </LabeledList.Item>
          </LabeledList>
        </Section>
      </Stack.Item>

      {/* Pad contents if any - only show on active tab */}
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

      {/* Mission Tabs */}
      <Stack.Item>
        <Tabs fluid>
          <Tabs.Tab
            selected={currentTab === 'available'}
            onClick={() => setCurrentTab('available')}
          >
            Available ({available_missions.length})
          </Tabs.Tab>
          <Tabs.Tab
            selected={currentTab === 'active'}
            onClick={() => setCurrentTab('active')}
          >
            Active ({active_count}/{max_missions})
          </Tabs.Tab>
          <Tabs.Tab
            selected={currentTab === 'bounties'}
            onClick={() => setCurrentTab('bounties')}
            icon="skull"
          >
            Bounties ({huntingCount}/{bounties.length})
          </Tabs.Tab>
          <Tabs.Tab
            selected={currentTab === 'broadcasts'}
            onClick={() => setCurrentTab('broadcasts')}
            icon="satellite-dish"
          >
            Broadcasts ({outpost_adverts.length})
          </Tabs.Tab>
        </Tabs>
      </Stack.Item>

      {/* Tab Content */}
      <Stack.Item grow>
        {currentTab === 'available' && (
          <Section fill scrollable>
            {available_missions.length === 0 ? (
              <NoticeBox>No available missions</NoticeBox>
            ) : (
              <Stack vertical>
                {available_missions.map((mission) => (
                  <Stack.Item key={mission.ref}>
                    <MissionCard mission={mission} isActive={false} />
                  </Stack.Item>
                ))}
              </Stack>
            )}
          </Section>
        )}

        {currentTab === 'active' && (
          <Section fill scrollable>
            {active_missions.length === 0 ? (
              <NoticeBox>No active missions</NoticeBox>
            ) : (
              <Stack vertical>
                {active_missions.map((mission) => (
                  <Stack.Item key={mission.ref}>
                    <MissionCard
                      mission={mission}
                      isActive
                      padContents={pad_contents}
                    />
                  </Stack.Item>
                ))}
              </Stack>
            )}
          </Section>
        )}

        {currentTab === 'bounties' && (
          <Section fill scrollable>
            {/* Player Bounty Creation */}
            <PlayerBountyCreator
              hasCreatedBounty={!!has_created_bounty}
              shipBalance={ship_balance}
              hasPad={!!has_pad}
            />

            {/* Player's Active Bounty Status */}
            {(!!has_created_bounty || !!has_claimed_player_bounty) && (
              <PlayerBountyStatus
                playerBounties={player_bounties}
                hasPad={!!has_pad}
              />
            )}

            {/* Available Player Bounties */}
            {player_bounties.filter(
              (b) => !b.is_creator && b.status === 'available',
            ).length > 0 && (
              <Section title="Player Bounties" mt={1}>
                <Stack vertical>
                  {player_bounties
                    .filter((b) => !b.is_creator && b.status === 'available')
                    .map((bounty) => (
                      <Stack.Item key={bounty.ref}>
                        <PlayerBountyCard
                          bounty={bounty}
                          hasPad={!!has_pad}
                          hasClaimedBounty={!!has_claimed_player_bounty}
                        />
                      </Stack.Item>
                    ))}
                </Stack>
              </Section>
            )}

            <Divider />

            {/* Pirate Bounties */}
            <Section title="Pirate Bounties">
              <NoticeBox info mb={1}>
                Bounties are competitive - multiple crews can hunt the same
                target. Turn in the captain&apos;s key at the mission pad to
                claim the reward.
              </NoticeBox>
              {bounties.length === 0 ? (
                <NoticeBox>No active pirate bounties</NoticeBox>
              ) : (
                <Stack vertical>
                  {bounties.map((bounty) => (
                    <Stack.Item key={bounty.ref}>
                      <BountyCard
                        bounty={bounty}
                        hasPad={!!has_pad}
                        hasActiveBounty={!!has_active_bounty}
                      />
                    </Stack.Item>
                  ))}
                </Stack>
              )}
            </Section>
          </Section>
        )}

        {currentTab === 'broadcasts' && (
          <Section fill scrollable title="Outpost Broadcasts">
            {outpost_adverts.length === 0 ? (
              <NoticeBox>
                No outposts are broadcasting right now. Player-founded outposts
                can buy galaxy-wide listings from their management console.
              </NoticeBox>
            ) : (
              <Stack vertical>
                {outpost_adverts.map((advert) => (
                  <Stack.Item key={`${advert.name}-${advert.x}-${advert.y}`}>
                    <Section>
                      <Stack align="center">
                        <Stack.Item grow>
                          <Box bold>{advert.name}</Box>
                          <Box color="label" fontSize="0.9em">
                            &quot;{advert.blurb}&quot;
                          </Box>
                        </Stack.Item>
                        <Stack.Item textAlign="right">
                          <Box bold>
                            ({advert.x}, {advert.y})
                          </Box>
                          <Box color="label" fontSize="0.85em">
                            {advert.remaining_minutes} min left
                          </Box>
                        </Stack.Item>
                      </Stack>
                    </Section>
                  </Stack.Item>
                ))}
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
        <Flex.Item>
          {!!bounty.is_hunting && !!bounty.has_tracking && (
            <Box color="teal" bold mr={1}>
              [TRACKING]
            </Box>
          )}
          {!!bounty.is_hunting && (
            <Box color="green" bold>
              [HUNTING]
            </Box>
          )}
          {!!bounty.was_abandoned && (
            <Box color="bad" bold>
              [ABANDONED]
            </Box>
          )}
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
                  tooltip={
                    !hasPad ? 'Requires mission pad to turn in' : undefined
                  }
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
                    tooltip={`Enable tracking to see target coordinates. Reduces reward by ${bounty.tracking_cost} cr`}
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

// ========== PLAYER BOUNTY COMPONENTS ==========

type PlayerBountyCreatorProps = {
  hasCreatedBounty: boolean;
  shipBalance: number;
  hasPad: boolean;
};

const PlayerBountyCreator = (props: PlayerBountyCreatorProps) => {
  const { act } = useBackend<Data>();
  const { hasCreatedBounty, shipBalance, hasPad } = props;

  const [reward, setReward] = useState(500);
  const [bountyName, setBountyName] = useState('');
  const [bountyDesc, setBountyDesc] = useState('');

  if (hasCreatedBounty) {
    return null; // Don't show creator if already has a bounty
  }

  return (
    <Section title="Create Bounty">
      <Box mb={1} color="label">
        Post a bounty for other ships to complete. Contractors will submit
        offers with proof, which you can approve to complete the exchange.
      </Box>
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
              ? 'Title must be at least 3 characters'
              : bountyDesc.length < 5
                ? 'Objective must be at least 5 characters'
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

          {/* Contractors working but no offers yet */}
          {createdBounty.contractor_count > 0 &&
            (!createdBounty.pending_offers ||
              createdBounty.pending_offers.length === 0) && (
              <Box mt={1}>
                <NoticeBox info>
                  Contractors are working on your bounty. Offers will appear
                  here for your approval.
                </NoticeBox>
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
              <>
                <NoticeBox info mb={1}>
                  Your offer has been submitted. Keep the items on your pad
                  until the creator approves!
                </NoticeBox>
                <Button
                  fluid
                  icon="undo"
                  color="caution"
                  onClick={() => act('withdraw_bounty_offer')}
                >
                  Withdraw Offer
                </Button>
              </>
            ) : (
              <>
                <NoticeBox info mb={1}>
                  Place items on your pad as proof, then submit an offer. The
                  creator will review and approve to complete the exchange.
                </NoticeBox>
                <Button
                  fluid
                  icon="paper-plane"
                  color="good"
                  disabled={!hasPad}
                  tooltip={
                    !hasPad
                      ? 'Requires mission pad'
                      : 'Submit items on pad as an offer'
                  }
                  onClick={() => act('make_bounty_offer')}
                >
                  Submit Offer
                </Button>
              </>
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
