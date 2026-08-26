import {
  Button,
  LabeledList,
  NoticeBox,
  ProgressBar,
  Section,
} from 'tgui-core/components';
import type { BooleanLike } from 'tgui-core/react';

import { useBackend } from '../backend';
import { Window } from '../layouts';

type SiphonData = {
  active: BooleanLike;
  warming_up: BooleanLike;
  warmup_progress: number;
  credits_stored: number;
  has_target: BooleanLike;
  target_name: string;
  target_credits: number;
  siphon_goal: number;
  goal_progress: number;
  goal_fraction: number;
  can_activate: BooleanLike;
  no_lock_reason: string;
  siphon_rate: number;
  rate_mult: number;
  efficiency_mult: number;
  warmup_mult: number;
  warmup_time: number;
  power_draw: number;
};

export const ShipSiphon = (props) => {
  const { act, data } = useBackend<SiphonData>();
  const {
    active,
    warming_up,
    warmup_progress,
    credits_stored,
    has_target,
    target_name,
    target_credits,
    siphon_goal,
    goal_progress,
    goal_fraction,
    can_activate,
    no_lock_reason,
    siphon_rate,
    rate_mult,
    efficiency_mult,
    warmup_mult,
    warmup_time,
    power_draw,
  } = data;

  return (
    <Window width={400} height={450} title="Ship Data Siphon">
      <Window.Content>
        <Section title="Status">
          <LabeledList>
            <LabeledList.Item label="State">
              {active ? (
                <span style={{ color: 'red', fontWeight: 'bold' }}>
                  ACTIVE - SIPHONING
                </span>
              ) : warming_up ? (
                <span style={{ color: 'orange' }}>Calibrating...</span>
              ) : (
                <span style={{ color: 'gray' }}>Inactive</span>
              )}
            </LabeledList.Item>
            <LabeledList.Item label="Credits Stored">
              {credits_stored} cr
            </LabeledList.Item>
          </LabeledList>

          {!!warming_up && (
            <ProgressBar
              value={warmup_progress}
              maxValue={100}
              color="orange"
              mt={1}
            >
              Calibrating: {Math.round(warmup_progress)}%
            </ProgressBar>
          )}

          {!!active && siphon_goal > 0 && (
            <ProgressBar value={goal_progress} maxValue={100} color="red" mt={1}>
              Siphon Progress: {Math.round(goal_progress)}% ({credits_stored} /{' '}
              {siphon_goal} cr)
            </ProgressBar>
          )}
        </Section>

        <Section title="Target">
          {has_target ? (
            <LabeledList>
              <LabeledList.Item label="Target Ship">
                {target_name}
              </LabeledList.Item>
              <LabeledList.Item label="Target Credits">
                {target_credits} cr
              </LabeledList.Item>
              <LabeledList.Item
                label={goal_fraction >= 1 ? 'Full Drain' : '25% Goal'}
              >
                {Math.round(target_credits * (goal_fraction || 0.25))} cr
              </LabeledList.Item>
            </LabeledList>
          ) : (
            <NoticeBox info>
              {no_lock_reason ||
                'No target locked. Use the combat console to acquire a weapons lock.'}
            </NoticeBox>
          )}
        </Section>

        <Section title="System Stats">
          <LabeledList>
            <LabeledList.Item label="Siphon Rate">
              {siphon_rate} cr/tick ({Math.round(rate_mult * 100)}%)
            </LabeledList.Item>
            <LabeledList.Item label="Warmup Time">
              {warmup_time}s ({Math.round((1 - warmup_mult) * 100)}% reduction)
            </LabeledList.Item>
            <LabeledList.Item label="Power Draw">
              {power_draw > 0 ? `${power_draw} W` : 'Idle'}
            </LabeledList.Item>
            <LabeledList.Item label="Efficiency">
              {Math.round((1 - efficiency_mult) * 100)}% power reduction
            </LabeledList.Item>
          </LabeledList>
        </Section>

        <Section title="Controls">
          {credits_stored > 0 && !active && !warming_up && (
            <Button
              icon="coins"
              color="green"
              onClick={() => act('withdraw')}
              mb={1}
              fluid
            >
              Withdraw {credits_stored} credits
            </Button>
          )}

          {active || warming_up ? (
            <Button
              icon="stop"
              color="red"
              onClick={() => act('deactivate')}
              fluid
            >
              Deactivate Siphon
            </Button>
          ) : (
            <Button
              icon="play"
              color={can_activate ? 'green' : 'gray'}
              disabled={!can_activate}
              onClick={() => act('activate')}
              fluid
            >
              {can_activate ? 'Activate Siphon' : 'Requires Weapons Lock'}
            </Button>
          )}
        </Section>
      </Window.Content>
    </Window>
  );
};
