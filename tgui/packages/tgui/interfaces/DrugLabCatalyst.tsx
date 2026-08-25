/**
 * Catalyst column of the hidden drug lab: a four-lane rhythm game. Reagent
 * glyphs scroll down toward the strike line; hit 1-4 (or the arrow keys) as
 * each one crosses it.
 *
 * The game is CLIENT-RUN, SERVER-VALIDATED: act() latency makes per-note
 * server checks impossible, so this window plays the server-issued chart
 * locally with requestAnimationFrame and reports totals once. The server
 * rebuilds the same deterministic chart and rejects implausible reports
 * (count mismatches, finishes faster than the chart span, stale nonces).
 * Nothing here is trusted beyond plausibility.
 */
import { useEffect, useRef, useState } from 'react';
import {
  Box,
  Button,
  Icon,
  KeyListener,
  LabeledList,
  NoticeBox,
  Section,
  Stack,
} from 'tgui-core/components';
import type { KeyEvent } from 'tgui-core/events';
import {
  KEY_1,
  KEY_2,
  KEY_3,
  KEY_4,
  KEY_DOWN,
  KEY_LEFT,
  KEY_RIGHT,
  KEY_UP,
} from 'tgui-core/keycodes';

import { useBackend } from '../backend';
import { Window } from '../layouts';
import {
  type DrugLabCatalystData,
  DrugLabStage,
  STAGE_LABELS,
} from './common/drugLab';

/** Presses within this of a note's t are PERFECT. */
const PERFECT_WINDOW_MS = 140;
/** Presses within this of a note's t are GOOD; past it the note is missed. */
const GOOD_WINDOW_MS = 280;
/** Scroll speed: how many px a note travels per ms. */
const SCROLL_PX_PER_MS = 0.18;
/** Playfield height in px. */
const FIELD_HEIGHT = 340;
/** Strike line's y within the playfield. */
const STRIKE_Y = 300;
/** How long after the last note the run auto-reports. */
const END_TAIL_MS = 500;
/** How long a lane's key baseplate stays lit after a press. */
const PRESS_FLASH_MS = 120;

/** keycode -> lane. Number row 1-4 and left/down/up/right both play. */
const LANE_KEYS: Record<number, number> = {
  [KEY_1]: 1,
  [KEY_2]: 2,
  [KEY_3]: 3,
  [KEY_4]: 4,
  [KEY_LEFT]: 1,
  [KEY_DOWN]: 2,
  [KEY_UP]: 3,
  [KEY_RIGHT]: 4,
};
/** Reagent glyph per lane. */
const LANE_ICONS = ['flask', 'vial', 'droplet', 'atom'];
const LANE_COLORS = ['#4fa8d8', '#7bc96f', '#e8b13a', '#c76fc9'];
const LANE_HINTS = ['1 / ←', '2 / ↓', '3 / ↑', '4 / →'];

type Verdict = 'perfect' | 'good' | 'miss';

type NoteState = {
  lane: number;
  t: number;
  judged: Verdict | null;
};

type GamePhase = 'idle' | 'countdown' | 'playing' | 'reported';

type JudgementFlash = {
  kind: Verdict;
  seq: number;
} | null;

const VERDICT_COLORS: Record<Verdict, string> = {
  perfect: '#68d448',
  good: '#4fa8d8',
  miss: '#d84f4f',
};

export const DrugLabCatalyst = (props) => {
  const { act, data } = useBackend<DrugLabCatalystData>();

  const [phase, setPhase] = useState<GamePhase>('idle');
  const [now, setNow] = useState(0);
  const [combo, setCombo] = useState(0);
  const [judgement, setJudgement] = useState<JudgementFlash>(null);

  // The whole game loop and key handler touch ONLY refs and stable setters:
  // KeyListener registers its handler once, with the first render's closure.
  const phaseRef = useRef<GamePhase>('idle');
  const notesRef = useRef<NoteState[]>([]);
  const goTimeRef = useRef(0);
  const nonceRef = useRef<string | null>(null);
  const countsRef = useRef({ perfects: 0, goods: 0, misses: 0 });
  const judgeSeqRef = useRef(0);
  const rafRef = useRef<number | null>(null);
  const lastPressRef = useRef({ lane: 0, at: -9999 });
  const actRef = useRef(act);
  actRef.current = act;

  const setPhaseBoth = (next: GamePhase) => {
    phaseRef.current = next;
    setPhase(next);
  };

  const stopLoop = () => {
    if (rafRef.current !== null) {
      cancelAnimationFrame(rafRef.current);
      rafRef.current = null;
    }
  };

  const startLoop = () => {
    stopLoop();
    const tick = () => {
      const nowMs = performance.now();
      const elapsed = nowMs - goTimeRef.current;
      const notes = notesRef.current;
      if (phaseRef.current === 'countdown' && elapsed >= 0) {
        setPhaseBoth('playing');
      }
      if (phaseRef.current === 'playing') {
        // Sweep notes whose window closed unpressed into misses
        for (const note of notes) {
          if (!note.judged && elapsed > note.t + GOOD_WINDOW_MS) {
            note.judged = 'miss';
            countsRef.current.misses++;
            setCombo(0);
            setJudgement({ kind: 'miss', seq: ++judgeSeqRef.current });
          }
        }
        const lastT = notes.length ? notes[notes.length - 1].t : 0;
        if (elapsed >= lastT + END_TAIL_MS) {
          setPhaseBoth('reported');
          const counts = countsRef.current;
          actRef.current('catalyst_finish', {
            nonce: nonceRef.current,
            perfects: counts.perfects,
            goods: counts.goods,
            misses: counts.misses,
          });
          rafRef.current = null;
          setNow(nowMs);
          return;
        }
      }
      setNow(nowMs);
      rafRef.current = requestAnimationFrame(tick);
    };
    rafRef.current = requestAnimationFrame(tick);
  };

  // A fresh nonce means a fresh attempt: rebuild local state and count down.
  // game_active dropping means the server resolved the attempt, stand down.
  useEffect(() => {
    if (
      data.game_active &&
      data.nonce &&
      data.chart &&
      data.nonce !== nonceRef.current
    ) {
      nonceRef.current = data.nonce;
      notesRef.current = data.chart.map((note) => ({
        lane: note.lane,
        t: note.t,
        judged: null,
      }));
      countsRef.current = { perfects: 0, goods: 0, misses: 0 };
      setCombo(0);
      setJudgement(null);
      goTimeRef.current = performance.now() + (data.lead_in_ms || 3000);
      setPhaseBoth('countdown');
      startLoop();
    } else if (!data.game_active && phaseRef.current !== 'idle') {
      stopLoop();
      setPhaseBoth('idle');
    }
  }, [data.game_active, data.nonce]);

  // Cancel the loop on unmount
  useEffect(() => () => stopLoop(), []);

  const handleKey = (keyEvent: KeyEvent) => {
    const lane = LANE_KEYS[keyEvent.code];
    if (!lane || keyEvent.repeat) {
      return;
    }
    keyEvent.event?.preventDefault?.();
    if (phaseRef.current !== 'playing') {
      return;
    }
    const elapsed = performance.now() - goTimeRef.current;
    lastPressRef.current = { lane, at: elapsed };
    // Nearest unjudged note in this lane gets the judgement
    let best: NoteState | null = null;
    let bestDelta = Infinity;
    for (const note of notesRef.current) {
      if (note.lane !== lane || note.judged) {
        continue;
      }
      const delta = Math.abs(note.t - elapsed);
      if (delta < bestDelta) {
        bestDelta = delta;
        best = note;
      }
    }
    if (!best || bestDelta > GOOD_WINDOW_MS) {
      return; // stray press: no note consumed, no penalty
    }
    const kind: Verdict = bestDelta <= PERFECT_WINDOW_MS ? 'perfect' : 'good';
    best.judged = kind;
    if (kind === 'perfect') {
      countsRef.current.perfects++;
    } else {
      countsRef.current.goods++;
    }
    setCombo((current) => current + 1);
    setJudgement({ kind, seq: ++judgeSeqRef.current });
  };

  if (data.dormant) {
    return (
      <Window width={430} height={300}>
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

  const laneCount = data.lane_count || 4;
  const lanes = Array.from({ length: laneCount }, (_, i) => i + 1);
  const laneWidthPct = 100 / laneCount;
  const elapsed = now - goTimeRef.current;
  const counts = countsRef.current;
  const inGame = phase !== 'idle';
  const pressGlowLane =
    elapsed - lastPressRef.current.at < PRESS_FLASH_MS
      ? lastPressRef.current.lane
      : 0;

  return (
    <Window width={430} height={700}>
      <Window.Content>
        {inGame && <KeyListener onKeyDown={handleKey} />}
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
                <LabeledList.Item label="Column score">
                  {data.station_score}/100 ({data.attempts_used}/
                  {data.max_attempts} attempts used)
                </LabeledList.Item>
              </LabeledList>
            </Section>
          </Stack.Item>
          <Stack.Item grow>
            {data.stage < DrugLabStage.Catalyst && (
              <Section fill title="Reaction Feed">
                <NoticeBox info>
                  <Icon name="hourglass-half" mr={1} />
                  Waiting on the mixer: the column has nothing to catalyze
                  yet.
                </NoticeBox>
              </Section>
            )}
            {data.stage === DrugLabStage.Catalyst && (
              <Section
                fill
                title="Reaction Feed"
                buttons={
                  inGame && (
                    <>
                      <Box inline color="good" bold mr={1}>
                        P {counts.perfects}
                      </Box>
                      <Box inline color="blue" bold mr={1}>
                        G {counts.goods}
                      </Box>
                      <Box inline color="bad" bold>
                        M {counts.misses}
                      </Box>
                    </>
                  )
                }
              >
                <Stack vertical>
                  {inGame && (
                    <>
                      <Stack.Item>
                        <Box
                          position="relative"
                          width="100%"
                          height={`${FIELD_HEIGHT}px`}
                          style={{
                            overflow: 'hidden',
                            background: 'rgba(0, 0, 0, 0.55)',
                            borderRadius: '4px',
                          }}
                        >
                          {lanes.map((lane) => (
                            <Box
                              key={lane}
                              style={{
                                position: 'absolute',
                                top: '0',
                                bottom: '0',
                                left: `${(lane - 1) * laneWidthPct}%`,
                                width: `${laneWidthPct}%`,
                                borderRight:
                                  lane < laneCount
                                    ? '1px solid rgba(255, 255, 255, 0.12)'
                                    : 'none',
                                background:
                                  pressGlowLane === lane
                                    ? 'rgba(255, 255, 255, 0.08)'
                                    : 'transparent',
                              }}
                            />
                          ))}
                          <Box
                            style={{
                              position: 'absolute',
                              left: '0',
                              right: '0',
                              top: `${STRIKE_Y}px`,
                              height: '3px',
                              background: 'rgba(255, 255, 255, 0.75)',
                              boxShadow: '0 0 6px rgba(255, 255, 255, 0.6)',
                            }}
                          />
                          {notesRef.current.map((note, i) => {
                            if (note.judged) {
                              return null;
                            }
                            const y =
                              STRIKE_Y - (note.t - elapsed) * SCROLL_PX_PER_MS;
                            if (y < -24 || y > FIELD_HEIGHT + 8) {
                              return null;
                            }
                            return (
                              <Icon
                                key={i}
                                name={LANE_ICONS[note.lane - 1]}
                                size={1.6}
                                style={{
                                  position: 'absolute',
                                  left: `calc(${
                                    (note.lane - 0.5) * laneWidthPct
                                  }% - 10px)`,
                                  top: `${y - 10}px`,
                                  color: LANE_COLORS[note.lane - 1],
                                }}
                              />
                            );
                          })}
                          {judgement && phase === 'playing' && (
                            <Box
                              key={judgement.seq}
                              bold
                              style={{
                                position: 'absolute',
                                left: '0',
                                right: '0',
                                top: `${STRIKE_Y - 44}px`,
                                textAlign: 'center',
                                fontSize: '1.3em',
                                color: VERDICT_COLORS[judgement.kind],
                                textShadow: '0 0 4px rgba(0, 0, 0, 0.9)',
                              }}
                            >
                              {judgement.kind.toUpperCase()}
                              {combo > 1 && judgement.kind !== 'miss'
                                ? ` x${combo}`
                                : ''}
                            </Box>
                          )}
                          {phase === 'countdown' && (
                            <Box
                              bold
                              style={{
                                position: 'absolute',
                                left: '0',
                                right: '0',
                                top: '120px',
                                textAlign: 'center',
                                fontSize: '3em',
                                color: '#ffffff',
                                textShadow: '0 0 8px rgba(0, 0, 0, 0.9)',
                              }}
                            >
                              {Math.max(Math.ceil(-elapsed / 1000), 1)}
                            </Box>
                          )}
                          {phase === 'playing' && elapsed < 400 && (
                            <Box
                              bold
                              style={{
                                position: 'absolute',
                                left: '0',
                                right: '0',
                                top: '120px',
                                textAlign: 'center',
                                fontSize: '3em',
                                color: '#68d448',
                                textShadow: '0 0 8px rgba(0, 0, 0, 0.9)',
                              }}
                            >
                              GO!
                            </Box>
                          )}
                          {phase === 'reported' && (
                            <Box
                              bold
                              style={{
                                position: 'absolute',
                                left: '0',
                                right: '0',
                                top: '140px',
                                textAlign: 'center',
                                fontSize: '1.4em',
                                color: '#ffffff',
                              }}
                            >
                              <Icon name="circle-notch" spin mr={1} />
                              Validating run...
                            </Box>
                          )}
                        </Box>
                      </Stack.Item>
                      <Stack.Item>
                        <Stack>
                          {lanes.map((lane) => (
                            <Stack.Item key={lane} grow>
                              <Box
                                textAlign="center"
                                bold
                                style={{
                                  color: LANE_COLORS[lane - 1],
                                  opacity:
                                    pressGlowLane === lane ? '1' : '0.6',
                                }}
                              >
                                <Icon name={LANE_ICONS[lane - 1]} mr={1} />
                                {LANE_HINTS[lane - 1]}
                              </Box>
                            </Stack.Item>
                          ))}
                        </Stack>
                      </Stack.Item>
                    </>
                  )}
                  {!inGame && !!data.awaiting_choice && (
                    <Stack.Item>
                      <NoticeBox color={data.botched ? 'bad' : 'good'}>
                        <Icon
                          name={data.botched ? 'triangle-exclamation' : 'vial'}
                          mr={1}
                        />
                        Attempt scored {data.last_attempt_score}/100
                        {data.botched ? ', the column reacted violently!' : ''}
                      </NoticeBox>
                    </Stack.Item>
                  )}
                  {!inGame && !data.awaiting_choice && (
                    <Stack.Item>
                      <NoticeBox info>
                        Reagent glyphs scroll toward the strike line. Hit keys
                        1-4 (or ← ↓ ↑ →) as each glyph crosses it. Timing is
                        everything: PERFECT beats GOOD beats a miss.
                      </NoticeBox>
                    </Stack.Item>
                  )}
                  {!inGame && !data.awaiting_choice && (
                    <Stack.Item>
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
                    </Stack.Item>
                  )}
                  {!inGame && !!data.awaiting_choice && (
                    <Stack.Item>
                      <Stack>
                        <Stack.Item grow>
                          <Button
                            fluid
                            icon="check"
                            color="good"
                            tooltip="Lock the column in at its best score and move to the crystallization chamber."
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
                            tooltip="Retries can only raise your score, but each one caps lower, and retrying a botch is how columns catch fire."
                            onClick={() => act('start_attempt')}
                          >
                            {data.next_cap === null
                              ? 'No retries left'
                              : `Retry (max ${data.next_cap})`}
                          </Button>
                        </Stack.Item>
                      </Stack>
                    </Stack.Item>
                  )}
                </Stack>
              </Section>
            )}
            {data.stage > DrugLabStage.Catalyst && (
              <Section fill title="Reaction Feed">
                <NoticeBox color="good">
                  <Icon name="check" mr={1} />
                  Column locked in at {data.station_score}/100.
                </NoticeBox>
                {data.stage < DrugLabStage.Done ? (
                  <NoticeBox info>
                    The batch has moved on. Work the crystallization chamber.
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
