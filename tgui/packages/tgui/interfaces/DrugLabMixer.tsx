/**
 * Industrial mixer station of the hidden drug lab: bank the three recipe
 * precursors, then run the hopper-sequence memory game.
 *
 * All correctness is SERVER-SIDE. Every hopper press is an act round-trip
 * checked against the session's cursor. The only client-local behavior is the
 * cosmetic flash phase: when a fresh sequence arrives (sequence_id bump), the
 * client replays it on the hopper grid before accepting input.
 */
import { useEffect, useRef, useState } from 'react';
import {
  Button,
  Icon,
  LabeledList,
  NoticeBox,
  Section,
  Stack,
} from 'tgui-core/components';

import { useBackend } from '../backend';
import { Window } from '../layouts';
import {
  type DrugLabMixerData,
  DrugLabStage,
  STAGE_LABELS,
} from './common/drugLab';

/** Milliseconds per step of the flash phase. */
const FLASH_STEP_MS = 600;
/** How long each hopper stays lit within a step. */
const FLASH_LIT_MS = 400;
/** How long the green/red grid feedback lingers. */
const GRID_FLASH_MS = 600;

type Phase = 'idle' | 'showing' | 'input';
type GridFlash = 'good' | 'bad' | null;

export const DrugLabMixer = (props) => {
  const { act, data } = useBackend<DrugLabMixerData>();

  const [phase, setPhase] = useState<Phase>('idle');
  const [litHopper, setLitHopper] = useState<number | null>(null);
  const [gridFlash, setGridFlash] = useState<GridFlash>(null);
  const timersRef = useRef<number[]>([]);
  const seenSequenceRef = useRef(-1);
  const prevActiveRef = useRef(false);
  const prevRoundsRef = useRef(0);

  const clearTimers = () => {
    for (const id of timersRef.current) {
      clearTimeout(id);
    }
    timersRef.current = [];
  };
  const after = (ms: number, fn: () => void) => {
    timersRef.current.push(window.setTimeout(fn, ms));
  };

  // Flash-phase driver: replay every fresh sequence, cosmetic only.
  useEffect(() => {
    const active = !!data.game_active;
    const wasActive = prevActiveRef.current;
    prevActiveRef.current = active;

    if (!active) {
      clearTimers();
      setLitHopper(null);
      setPhase('idle');
      if (wasActive) {
        // The attempt just ended: green for a full clear, red otherwise
        setGridFlash(
          data.rounds_completed >= data.total_rounds ? 'good' : 'bad',
        );
        timersRef.current.push(
          window.setTimeout(() => setGridFlash(null), GRID_FLASH_MS),
        );
      }
      prevRoundsRef.current = 0;
      return;
    }
    if (data.sequence_id === seenSequenceRef.current || !data.sequence) {
      return;
    }
    seenSequenceRef.current = data.sequence_id;
    clearTimers();
    setLitHopper(null);
    const clearedRound = data.rounds_completed > prevRoundsRef.current;
    prevRoundsRef.current = data.rounds_completed;
    if (data.cursor > 0) {
      // Rejoined mid-round: the flash already played for whoever is driving
      setPhase('input');
      return;
    }
    let delay = 250;
    if (clearedRound) {
      setGridFlash('good');
      after(GRID_FLASH_MS, () => setGridFlash(null));
      delay += GRID_FLASH_MS;
    }
    setPhase('showing');
    data.sequence.forEach((hopper, i) => {
      after(delay + FLASH_STEP_MS * i, () => setLitHopper(hopper));
      after(delay + FLASH_STEP_MS * i + FLASH_LIT_MS, () => setLitHopper(null));
    });
    after(delay + FLASH_STEP_MS * data.sequence.length + 100, () =>
      setPhase('input'),
    );
  }, [data.sequence_id, data.game_active]);

  // Clean every pending timer up on unmount
  useEffect(() => () => clearTimers(), []);

  if (data.dormant) {
    return (
      <Window width={380} height={300}>
        <Window.Content>
          <NoticeBox>
            <Icon name="lock" mr={1} />
            The console idles on a lock screen. Without an authenticated
            formula, this is just very suspicious furniture.
          </NoticeBox>
        </Window.Content>
      </Window>
    );
  }

  const pressHopper = (index: number) => {
    if (phase !== 'input' || !data.game_active) {
      return;
    }
    setLitHopper(index);
    after(150, () => setLitHopper(null));
    act('press', { index });
  };

  const hopperColor = (n: number) => {
    if (gridFlash) {
      return gridFlash;
    }
    if (litHopper === n) {
      return 'yellow';
    }
    return 'default';
  };

  const hoppers = Array.from(
    { length: data.hopper_count || 4 },
    (_, i) => i + 1,
  );
  const rows: number[][] = [];
  for (let i = 0; i < hoppers.length; i += 2) {
    rows.push(hoppers.slice(i, i + 2));
  }

  const sequenceLength = data.sequence ? data.sequence.length : 0;

  return (
    <Window width={380} height={560}>
      <Window.Content>
        <Stack vertical fill>
          <Stack.Item>
            <Section title="Batch">
              <LabeledList>
                <LabeledList.Item label="Formula">
                  {data.street_name || 'unknown'}
                </LabeledList.Item>
                <LabeledList.Item label="Stage">
                  {STAGE_LABELS[data.stage] || 'unknown'}
                </LabeledList.Item>
                <LabeledList.Item label="Mixer score">
                  {data.station_score}/100 ({data.attempts_used}/
                  {data.max_attempts} attempts used)
                </LabeledList.Item>
              </LabeledList>
            </Section>
          </Stack.Item>
          <Stack.Item>
            <Section title="Hoppers">
              <LabeledList>
                {data.ingredients.map((ingredient, i) => (
                  <LabeledList.Item
                    key={i}
                    label={`Precursor ${i + 1}`}
                    color={ingredient.banked ? 'good' : 'bad'}
                  >
                    <Icon
                      name={ingredient.banked ? 'check' : 'xmark'}
                      mr={1}
                    />
                    {ingredient.name}
                  </LabeledList.Item>
                ))}
              </LabeledList>
            </Section>
          </Stack.Item>
          <Stack.Item grow>
            {data.stage === DrugLabStage.Loading && (
              <Section fill title="Mixing Sequence">
                <NoticeBox info>
                  Feed all three precursors into the hoppers to unseal the
                  mixer.
                </NoticeBox>
              </Section>
            )}
            {data.stage === DrugLabStage.Mixer && (
              <Section
                fill
                title="Mixing Sequence"
                buttons={
                  !!data.game_active && (
                    <>
                      Round {data.round}/{data.total_rounds}
                    </>
                  )
                }
              >
                <Stack vertical>
                  <Stack.Item>
                    {!!data.game_active && phase === 'showing' && (
                      <NoticeBox info>
                        <Icon name="eye" mr={1} />
                        Memorize the hopper sequence...
                      </NoticeBox>
                    )}
                    {!!data.game_active && phase === 'input' && (
                      <NoticeBox color="blue">
                        <Icon name="hand-pointer" mr={1} />
                        Repeat it! {data.cursor}/{sequenceLength}
                      </NoticeBox>
                    )}
                    {!data.game_active && !!data.awaiting_choice && (
                      <NoticeBox color={data.botched ? 'bad' : 'good'}>
                        <Icon
                          name={data.botched ? 'triangle-exclamation' : 'vial'}
                          mr={1}
                        />
                        Attempt scored {data.last_attempt_score}/100
                        {data.botched ? ', the batch reacted violently!' : ''}
                      </NoticeBox>
                    )}
                    {!data.game_active && !data.awaiting_choice && (
                      <NoticeBox info>
                        Run the hoppers in the order the console shows. Five
                        rounds, one mistake ends the attempt.
                      </NoticeBox>
                    )}
                  </Stack.Item>
                  {rows.map((row, rowIndex) => (
                    <Stack.Item key={rowIndex}>
                      <Stack>
                        {row.map((hopper) => (
                          <Stack.Item key={hopper} grow>
                            <Button
                              fluid
                              bold
                              height="48px"
                              fontSize="1.4em"
                              textAlign="center"
                              lineHeight="40px"
                              color={hopperColor(hopper)}
                              disabled={!data.game_active}
                              onClick={() => pressHopper(hopper)}
                            >
                              {hopper}
                            </Button>
                          </Stack.Item>
                        ))}
                      </Stack>
                    </Stack.Item>
                  ))}
                  <Stack.Item>
                    {!data.game_active && !data.awaiting_choice && (
                      <Button
                        fluid
                        icon="play"
                        color="good"
                        disabled={data.next_cap === null}
                        onClick={() => act('start_attempt')}
                      >
                        {data.next_cap === null
                          ? 'No attempts left'
                          : `Start attempt ${data.attempts_used + 1}/${data.max_attempts} (max score ${data.next_cap})`}
                      </Button>
                    )}
                    {!data.game_active && !!data.awaiting_choice && (
                      <Stack>
                        <Stack.Item grow>
                          <Button
                            fluid
                            icon="check"
                            color="good"
                            tooltip="Lock the mixer in at its best score and move to the catalyst column."
                            onClick={() => act('commit')}
                          >
                            Commit {data.station_score}/100
                          </Button>
                        </Stack.Item>
                        <Stack.Item grow>
                          <Button
                            fluid
                            icon="rotate-left"
                            color="average"
                            disabled={data.next_cap === null}
                            tooltip="Retries can only raise your score, but each one caps lower."
                            onClick={() => act('start_attempt')}
                          >
                            {data.next_cap === null
                              ? 'No retries left'
                              : `Retry (max ${data.next_cap})`}
                          </Button>
                        </Stack.Item>
                      </Stack>
                    )}
                  </Stack.Item>
                </Stack>
              </Section>
            )}
            {data.stage > DrugLabStage.Mixer && (
              <Section fill title="Mixing Sequence">
                <NoticeBox color="good">
                  <Icon name="check" mr={1} />
                  Mixer locked in at {data.station_score}/100.
                </NoticeBox>
                {data.stage < DrugLabStage.Done ? (
                  <NoticeBox info>
                    The batch has moved on, work the{' '}
                    {data.stage === DrugLabStage.Catalyst
                      ? 'catalyst column'
                      : 'crystallization chamber'}
                    .
                  </NoticeBox>
                ) : (
                  <NoticeBox color="good">
                    The cook is complete. Get the product moving.
                  </NoticeBox>
                )}
              </Section>
            )}
          </Stack.Item>
        </Stack>
      </Window.Content>
    </Window>
  );
};
