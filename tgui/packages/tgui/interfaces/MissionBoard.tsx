import { useState } from 'react';

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

type Mission = {
  ref: string;
  name: string;
  desc: string;
  author: string;
  value: number;
  reward_item: string | null;
  reward_item_icon: string | null;
  duration: number;
  time_remaining: number;
  time_remaining_text: string;
  progress: string;
  can_complete: BooleanLike;
  active: BooleanLike;
  requires_item?: BooleanLike;
  target_x?: number;
  target_y?: number;
  visited?: BooleanLike;
  difficulty: number;
  difficulty_name: string;
  difficulty_color: string;
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
};

type Claimant = {
  ref: string;
  name: string;
};

type PlayerBounty = {
  ref: string;
  name: string;
  desc: string;
  reward: number;
  is_custom: boolean;
  status: 'available' | 'completed' | 'cancelled';
  target_item_name?: string;
  target_amount?: number;
  creator_name?: string;
  is_creator: boolean;
  is_claimer: boolean;
  was_abandoned?: boolean;
  can_claim: boolean;
  hunter_count: number;
  claimants?: Claimant[];
};

type Data = {
  has_ship: BooleanLike;
  max_missions: number;
  active_count: number;
  has_pad: BooleanLike;
  available_missions: Mission[];
  active_missions: Mission[];
  pad_contents: PadItem[];
  bounties: Bounty[];
  has_active_bounty: BooleanLike;
  player_bounties: PlayerBounty[];
  has_created_bounty: BooleanLike;
  has_claimed_player_bounty: BooleanLike;
  ship_balance: number;
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
    available_missions,
    active_missions,
    pad_contents,
    bounties,
    has_active_bounty,
    player_bounties,
    has_created_bounty,
    has_claimed_player_bounty,
    ship_balance,
  } = data;

  const [currentTab, setCurrentTab] = useState<
    'available' | 'active' | 'bounties'
  >('available');

  const huntingCount = bounties.filter((b) => b.is_hunting).length;

  return (
    <Stack fill vertical>
      {/* Header */}
      <Stack.Item>
        <Section
          title="Mission Control"
          buttons={
            <Button icon="sync" onClick={() => act('refresh')}>
              Refresh
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
          </LabeledList>
        </Section>
      </Stack.Item>

      {/* Pad contents if any - only show on active tab */}
      {currentTab === 'active' && has_pad && pad_contents.length > 0 && (
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
      </Stack.Item>
    </Stack>
  );
};

type MissionCardProps = {
  mission: Mission;
  isActive: boolean;
  padContents?: PadItem[];
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
      title={mission.name}
      buttons={
        <Box inline>
          <Box inline color={mission.difficulty_color} mr={1}>
            [{mission.difficulty_name}]
          </Box>
          <Box inline color="good" mr={1}>
            {mission.value} cr
          </Box>
          {mission.reward_item && (
            <Box inline color="average">
              +{' '}
              {mission.reward_item_icon && (
                <img
                  src={`data:image/png;base64,${mission.reward_item_icon}`}
                  style={{
                    verticalAlign: 'middle',
                    marginRight: '4px',
                  }}
                />
              )}
              {mission.reward_item}
            </Box>
          )}
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
        <Box as="span" color="good" bold>
          {mission.value} credits
        </Box>
        {mission.reward_item && (
          <Box as="span" color="average" bold>
            {' '}
            +{' '}
            {mission.reward_item_icon && (
              <img
                src={`data:image/png;base64,${mission.reward_item_icon}`}
                style={{
                  verticalAlign: 'middle',
                  marginRight: '4px',
                }}
              />
            )}
            {mission.reward_item}
          </Box>
        )}
      </Box>

      {isActive && (
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
            {mission.progress && (
              <LabeledList.Item label="Progress">
                {mission.progress}
              </LabeledList.Item>
            )}
          </LabeledList>
          <Divider />
          <Flex justify="space-between">
            <Flex.Item>
              {mission.requires_item ? (
                <Button
                  icon="check"
                  color="good"
                  disabled={!mission.can_complete && padContents.length === 0}
                  onClick={() => {
                    // If there's an item on the pad, use the first one
                    const itemRef =
                      padContents.length > 0 ? padContents[0].ref : null;
                    act('turn_in', { ref: mission.ref, item_ref: itemRef });
                  }}
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
            </Flex.Item>
            <Flex.Item>
              <Button
                icon="times"
                color="bad"
                onClick={() => act('abandon', { ref: mission.ref })}
              >
                Abandon
              </Button>
            </Flex.Item>
          </Flex>
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

type BountyMode = 'select' | 'preset' | 'custom';

const PlayerBountyCreator = (props: PlayerBountyCreatorProps) => {
  const { act } = useBackend<Data>();
  const { hasCreatedBounty, shipBalance, hasPad } = props;

  const [mode, setMode] = useState<BountyMode>('select');
  const [reward, setReward] = useState(500);
  const [itemAmount, setItemAmount] = useState(5);
  const [customName, setCustomName] = useState('');
  const [customDesc, setCustomDesc] = useState('');

  if (hasCreatedBounty) {
    return null; // Don't show creator if already has a bounty
  }

  // Initial selection - choose bounty type
  if (mode === 'select') {
    return (
      <Section title="Create Bounty">
        <Box mb={1} color="label">
          Post a bounty for other ships to complete. Your reward will be held in
          escrow until the bounty is completed or cancelled.
        </Box>
        <LabeledList>
          <LabeledList.Item label="Ship Balance">
            <Box color={shipBalance >= 100 ? 'good' : 'bad'}>
              {shipBalance} cr
            </Box>
          </LabeledList.Item>
        </LabeledList>
        <Divider />
        <Stack>
          <Stack.Item grow>
            <Button
              fluid
              icon="box"
              color="good"
              disabled={shipBalance < 100 || !hasPad}
              tooltip={
                !hasPad
                  ? 'Requires mission pad for item delivery'
                  : shipBalance < 100
                    ? 'Insufficient funds (need 100 cr minimum)'
                    : 'Request a specific item to be delivered'
              }
              onClick={() => setMode('preset')}
            >
              Request Item
            </Button>
          </Stack.Item>
          <Stack.Item grow>
            <Button
              fluid
              icon="pen"
              color="caution"
              disabled={shipBalance < 100}
              tooltip={
                shipBalance < 100
                  ? 'Insufficient funds (need 100 cr minimum)'
                  : 'Create a custom objective'
              }
              onClick={() => setMode('custom')}
            >
              Custom Objective
            </Button>
          </Stack.Item>
        </Stack>
      </Section>
    );
  }

  // Preset item bounty flow
  if (mode === 'preset') {
    return (
      <Section
        title="Request Item"
        buttons={
          <Button icon="arrow-left" onClick={() => setMode('select')}>
            Back
          </Button>
        }
      >
        <LabeledList>
          <LabeledList.Item label="Item Amount">
            <NumberInput
              value={itemAmount}
              minValue={1}
              maxValue={100}
              step={1}
              width="80px"
              onChange={(value) => setItemAmount(value)}
            />
            <Box as="span" color="label" ml={1}>
              (for stackable items)
            </Box>
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
          icon="hand-pointer"
          color="good"
          disabled={shipBalance < reward}
          tooltip={
            shipBalance < reward ? 'Insufficient funds' : 'Choose item type'
          }
          onClick={() =>
            act('create_preset_bounty', { reward, amount: itemAmount })
          }
        >
          Select Item Type...
        </Button>
      </Section>
    );
  }

  // Custom objective bounty flow
  return (
    <Section
      title="Custom Objective"
      buttons={
        <Button
          icon="arrow-left"
          onClick={() => {
            setMode('select');
            setCustomName('');
            setCustomDesc('');
          }}
        >
          Back
        </Button>
      }
    >
      <LabeledList>
        <LabeledList.Item label="Title">
          <Input
            placeholder="Bounty name..."
            width="100%"
            maxLength={64}
            value={customName}
            onChange={(value) => setCustomName(value)}
          />
        </LabeledList.Item>
        <LabeledList.Item label="Objective">
          <TextArea
            placeholder="Describe what needs to be done..."
            width="100%"
            height="60px"
            maxLength={256}
            value={customDesc}
            onChange={(value) => setCustomDesc(value)}
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
        icon="check"
        color="good"
        disabled={
          shipBalance < reward ||
          customName.length < 3 ||
          customDesc.length < 5
        }
        tooltip={
          shipBalance < reward
            ? 'Insufficient funds'
            : customName.length < 3
              ? 'Title must be at least 3 characters'
              : customDesc.length < 5
                ? 'Objective must be at least 5 characters'
                : undefined
        }
        onClick={() => {
          act('create_custom_bounty', {
            reward,
            name: customName,
            desc: customDesc,
          });
          setMode('select');
          setCustomName('');
          setCustomDesc('');
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
      {createdBounty && (
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
            <LabeledList.Item label="Name">{createdBounty.name}</LabeledList.Item>
            <LabeledList.Item label="Type">
              {createdBounty.is_custom ? 'Custom Objective' : 'Item Request'}
            </LabeledList.Item>
            <LabeledList.Item label="Reward">
              <Box color="gold">{createdBounty.reward} cr</Box>
            </LabeledList.Item>
            <LabeledList.Item label="Hunters">
              <Box
                color={createdBounty.hunter_count > 0 ? 'good' : 'average'}
              >
                {createdBounty.hunter_count > 0
                  ? `${createdBounty.hunter_count} ship${createdBounty.hunter_count !== 1 ? 's' : ''} hunting`
                  : 'Waiting for hunters'}
              </Box>
            </LabeledList.Item>
          </LabeledList>

          {/* For custom bounties with hunters, show list of claimants to pay */}
          {!!createdBounty.is_custom &&
            createdBounty.claimants &&
            createdBounty.claimants.length > 0 && (
              <Box mt={1}>
                <Divider />
                <Box color="label" mb={1}>
                  Select a hunter to pay the reward:
                </Box>
                <Stack vertical>
                  {createdBounty.claimants.map((claimant) => (
                    <Stack.Item key={claimant.ref}>
                      <Button
                        fluid
                        icon="check"
                        color="good"
                        onClick={() =>
                          act('complete_custom_bounty', {
                            claimant_ref: claimant.ref,
                          })
                        }
                      >
                        Pay {claimant.name}
                      </Button>
                    </Stack.Item>
                  ))}
                </Stack>
              </Box>
            )}
        </Section>
      )}

      {/* Show claimed bounty */}
      {claimedBounty && (
        <Section
          title="Hunting Bounty"
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
            <LabeledList.Item label="Name">{claimedBounty.name}</LabeledList.Item>
            <LabeledList.Item label="From">
              {claimedBounty.creator_name || 'Unknown'}
            </LabeledList.Item>
            <LabeledList.Item label="Reward">
              <Box color="gold">{claimedBounty.reward} cr</Box>
            </LabeledList.Item>
            <LabeledList.Item label="Competition">
              <Box color={claimedBounty.hunter_count > 1 ? 'orange' : 'good'}>
                {claimedBounty.hunter_count > 1
                  ? `${claimedBounty.hunter_count - 1} other ship${claimedBounty.hunter_count > 2 ? 's' : ''} hunting`
                  : 'No competition'}
              </Box>
            </LabeledList.Item>
            <LabeledList.Item label="Objective">
              {claimedBounty.desc}
            </LabeledList.Item>
          </LabeledList>
          {!claimedBounty.is_custom ? (
            <Box mt={1}>
              <Button
                fluid
                icon="truck"
                color="good"
                disabled={!hasPad}
                tooltip={
                  !hasPad
                    ? 'Requires mission pad'
                    : `Place ${claimedBounty.target_item_name} on pad`
                }
                onClick={() => act('turn_in_player_bounty')}
              >
                Turn In ({claimedBounty.target_item_name})
              </Button>
            </Box>
          ) : (
            <Box mt={1}>
              <NoticeBox info mb={1}>
                Custom bounties must be marked complete by the creator. Use
                &quot;Send Item&quot; to deliver proof.
              </NoticeBox>
              <Button
                fluid
                icon="paper-plane"
                color="good"
                disabled={!hasPad}
                tooltip={
                  !hasPad
                    ? 'Requires mission pad'
                    : 'Send item on pad to bounty creator'
                }
                onClick={() => act('send_custom_bounty_item')}
              >
                Send Item to Creator
              </Button>
            </Box>
          )}
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
    if (bounty.was_abandoned) return 'You abandoned this bounty';
    if (hasClaimedBounty) return 'Already hunting a bounty';
    if (!bounty.can_claim) return 'Cannot claim this bounty';
    return undefined;
  };

  return (
    <Section
      title={
        <Box inline color={bounty.was_abandoned ? 'gray' : undefined}>
          <Box as="span" color={bounty.was_abandoned ? 'gray' : 'teal'} mr={1}>
            {bounty.is_custom ? '[Custom]' : '[Item]'}
          </Box>
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

      {!bounty.is_custom && bounty.target_item_name && (
        <Box mb={1} p={1} backgroundColor="rgba(0, 100, 200, 0.1)">
          <Box color="label">
            Required:{' '}
            <Box as="span" color="white" bold>
              {bounty.target_item_name}
            </Box>
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
          {!!bounty.was_abandoned && (
            <Box color="bad" bold>
              [ABANDONED]
            </Box>
          )}
        </Flex.Item>
      </Flex>

      <Button
        fluid
        icon="skull"
        color={canClaim ? 'good' : 'gray'}
        disabled={!canClaim}
        tooltip={getDisabledReason()}
        onClick={() => act('claim_player_bounty', { ref: bounty.ref })}
      >
        {bounty.was_abandoned ? 'Abandoned' : 'Accept Bounty'}
      </Button>
    </Section>
  );
};
