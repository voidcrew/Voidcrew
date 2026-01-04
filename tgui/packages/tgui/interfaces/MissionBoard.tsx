import { useState } from 'react';

import {
  Box,
  Button,
  Divider,
  Flex,
  LabeledList,
  NoticeBox,
  ProgressBar,
  Section,
  Stack,
  Tabs,
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

type Data = {
  has_ship: BooleanLike;
  max_missions: number;
  active_count: number;
  has_pad: BooleanLike;
  available_missions: Mission[];
  active_missions: Mission[];
  pad_contents: PadItem[];
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
  } = data;

  const [currentTab, setCurrentTab] = useState<'available' | 'active'>(
    'available',
  );

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
