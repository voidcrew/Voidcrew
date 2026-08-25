/**
 * Crystallization chamber of the hidden drug lab: a five-column catch game.
 * Crystals precipitate from the top of the chamber; slide the tray with
 * A/D (or the arrow keys) to catch the pure ones and dodge the tainted.
 *
 * Same trust model as the catalyst: CLIENT-RUN, SERVER-VALIDATED. The
 * window plays the server-issued drop table locally and reports catch
 * totals once; the server rebuilds the deterministic table and rejects
 * implausible reports. Tainted crystals only hurt when CAUGHT, dodged
 * ones fall past harmlessly.
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
import { KEY_A, KEY_D, KEY_LEFT, KEY_RIGHT } from 'tgui-core/keycodes';

import { useBackend } from '../backend';
import { Window } from '../layouts';
import {
  type DrugLabCrystallizerData,
  DrugLabStage,
  STAGE_LABELS,
} from './common/drugLab';

/** ms a crystal takes to fall from the chamber top to the tray line. */
const FALL_TIME_MS = 1800;
/** The tray catches a crystal within this of its tray-arrival t. */
const CATCH_WINDOW_MS = 120;
/** Playfield height in px. */
const FIELD_HEIGHT = 340;
/** Tray line's y within the playfield. */
const TRAY_Y = 300;
/** How long after the last drop's window the run auto-reports. */
const END_TAIL_MS = 500;

const PURE_COLOR = '#53d8e8';
const TAINTED_COLOR = '#a4d838';

type Resolution =
  | 'caught_pure' // pure, tray was under it: scores
  | 'caught_tainted' // tainted, tray was under it: penalty
  | 'missed_pure' // pure, fell past the tray: lost yield
  | 'passed_tainted'; // tainted, dodged: harmless

type EntryState = {
  col: number;
  t: number;
  tainted: boolean;
  resolved: Resolution | null;
};

type GamePhase = 'idle' | 'countdown' | 'playing' | 'reported';

type CatchFlash = {
  kind: 'caught' | 'tainted' | 'missed';
  seq: number;
} | null;

const FLASH_TEXT = {
  caught: { text: 'CAUGHT', color: '#68d448' },
  tainted: { text: 'TAINTED!', color: '#d84f4f' },
  missed: { text: 'MISSED', color: '#e8b13a' },
};

export const DrugLabCrystallizer = (props) => {
  const { act, data } = useBackend<DrugLabCrystallizerData>();

  const [phase, setPhase] = useState<GamePhase>('idle');
  const [now, setNow] = useState(0);
  const [trayCol, setTrayCol] = useState(3);
  const [flash, setFlash] = useState<CatchFlash>(null);

  // The game loop and key handler touch ONLY refs and stable setters:
  // KeyListener registers its handler once, with the first render's closure.
  const phaseRef = useRef<GamePhase>('idle');
  const entriesRef = useRef<EntryState[]>([]);
  const goTimeRef = useRef(0);
  const nonceRef = useRef<string | null>(null);
  const countsRef = useRef({ caught_pure: 0, caught_tainted: 0, missed_pure: 0 });
  const trayColRef = useRef(3);
  const colCountRef = useRef(5);
  const flashSeqRef = useRef(0);
  const rafRef = useRef<number | null>(null);
  const actRef = useRef(act);
  actRef.current = act;
  colCountRef.current = data.col_count || 5;

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
      const entries = entriesRef.current;
      if (phaseRef.current === 'countdown' && elapsed >= 0) {
        setPhaseBoth('playing');
      }
      if (phaseRef.current === 'playing') {
        for (const entry of entries) {
          if (entry.resolved) {
            continue;
          }
          const delta = elapsed - entry.t;
          if (delta >= -CATCH_WINDOW_MS && delta <= CATCH_WINDOW_MS) {
            // Inside the grace window: catch the moment the tray lines up
            if (trayColRef.current === entry.col) {
              if (entry.tainted) {
                entry.resolved = 'caught_tainted';
                countsRef.current.caught_tainted++;
                setFlash({ kind: 'tainted', seq: ++flashSeqRef.current });
              } else {
                entry.resolved = 'caught_pure';
                countsRef.current.caught_pure++;
                setFlash({ kind: 'caught', seq: ++flashSeqRef.current });
              }
            }
          } else if (delta > CATCH_WINDOW_MS) {
            // Window closed untouched: pure is lost yield, tainted is a dodge
            if (entry.tainted) {
              entry.resolved = 'passed_tainted';
            } else {
              entry.resolved = 'missed_pure';
              countsRef.current.missed_pure++;
              setFlash({ kind: 'missed', seq: ++flashSeqRef.current });
            }
          }
        }
        const lastT = entries.length ? entries[entries.length - 1].t : 0;
        if (elapsed >= lastT + CATCH_WINDOW_MS + END_TAIL_MS) {
          setPhaseBoth('reported');
          const counts = countsRef.current;
          actRef.current('crystallizer_finish', {
            nonce: nonceRef.current,
            caught_pure: counts.caught_pure,
            caught_tainted: counts.caught_tainted,
            missed_pure: counts.missed_pure,
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

  // A fresh nonce means a fresh attempt; game_active dropping means the
  // server resolved it, stand down.
  useEffect(() => {
    if (
      data.game_active &&
      data.nonce &&
      data.spawn_table &&
      data.nonce !== nonceRef.current
    ) {
      nonceRef.current = data.nonce;
      entriesRef.current = data.spawn_table.map((entry) => ({
        col: entry.col,
        t: entry.t,
        tainted: !!entry.tainted,
        resolved: null,
      }));
      countsRef.current = { caught_pure: 0, caught_tainted: 0, missed_pure: 0 };
      const startCol = Math.ceil((data.col_count || 5) / 2);
      trayColRef.current = startCol;
      setTrayCol(startCol);
      setFlash(null);
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
    let delta = 0;
    if (keyEvent.code === KEY_A || keyEvent.code === KEY_LEFT) {
      delta = -1;
    } else if (keyEvent.code === KEY_D || keyEvent.code === KEY_RIGHT) {
      delta = 1;
    } else {
      return;
    }
    keyEvent.event?.preventDefault?.();
    // Key repeats are welcome here: holding a key slides the tray
    if (phaseRef.current !== 'countdown' && phaseRef.current !== 'playing') {
      return;
    }
    const next = Math.min(
      Math.max(trayColRef.current + delta, 1),
      colCountRef.current,
    );
    trayColRef.current = next;
    setTrayCol(next);
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

  const colCount = data.col_count || 5;
  const cols = Array.from({ length: colCount }, (_, i) => i + 1);
  const colWidthPct = 100 / colCount;
  const elapsed = now - goTimeRef.current;
  const counts = countsRef.current;
  const inGame = phase !== 'idle';

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
                <LabeledList.Item label="Chamber score">
                  {data.station_score}/100 ({data.attempts_used}/
                  {data.max_attempts} attempts used)
                </LabeledList.Item>
              </LabeledList>
            </Section>
          </Stack.Item>
          <Stack.Item grow>
            {data.stage < DrugLabStage.Crystallizer && (
              <Section fill title="Growth Chamber">
                <NoticeBox info>
                  <Icon name="hourglass-half" mr={1} />
                  Waiting on the catalyst column: nothing to crystallize yet.
                </NoticeBox>
              </Section>
            )}
            {data.stage === DrugLabStage.Crystallizer && (
              <Section
                fill
                title="Growth Chamber"
                buttons={
                  inGame && (
                    <>
                      <Box inline color="good" bold mr={1}>
                        <Icon name="gem" mr={0.5} />
                        {counts.caught_pure}
                      </Box>
                      <Box inline color="bad" bold mr={1}>
                        <Icon name="biohazard" mr={0.5} />
                        {counts.caught_tainted}
                      </Box>
                      <Box inline color="average" bold>
                        <Icon name="xmark" mr={0.5} />
                        {counts.missed_pure}
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
                          {cols.map((col) => (
                            <Box
                              key={col}
                              style={{
                                position: 'absolute',
                                top: '0',
                                bottom: '0',
                                left: `${(col - 1) * colWidthPct}%`,
                                width: `${colWidthPct}%`,
                                borderRight:
                                  col < colCount
                                    ? '1px solid rgba(255, 255, 255, 0.12)'
                                    : 'none',
                              }}
                            />
                          ))}
                          <Box
                            style={{
                              position: 'absolute',
                              left: '0',
                              right: '0',
                              top: `${TRAY_Y}px`,
                              height: '1px',
                              background: 'rgba(255, 255, 255, 0.25)',
                            }}
                          />
                          {entriesRef.current.map((entry, i) => {
                            if (
                              entry.resolved === 'caught_pure' ||
                              entry.resolved === 'caught_tainted'
                            ) {
                              return null;
                            }
                            const progress =
                              (elapsed - (entry.t - FALL_TIME_MS)) /
                              FALL_TIME_MS;
                            if (progress < 0) {
                              return null;
                            }
                            const y = progress * TRAY_Y;
                            if (y > FIELD_HEIGHT + 8) {
                              return null;
                            }
                            return (
                              <Icon
                                key={i}
                                name={entry.tainted ? 'biohazard' : 'gem'}
                                size={1.5}
                                style={{
                                  position: 'absolute',
                                  left: `calc(${
                                    (entry.col - 0.5) * colWidthPct
                                  }% - 9px)`,
                                  top: `${y - 9}px`,
                                  color: entry.tainted
                                    ? TAINTED_COLOR
                                    : PURE_COLOR,
                                  opacity:
                                    entry.resolved === null ? '1' : '0.4',
                                }}
                              />
                            );
                          })}
                          <Box
                            style={{
                              position: 'absolute',
                              left: `calc(${
                                (trayCol - 1) * colWidthPct
                              }% + 3px)`,
                              width: `calc(${colWidthPct}% - 6px)`,
                              top: `${TRAY_Y + 4}px`,
                              height: '9px',
                              background: '#d4a017',
                              borderRadius: '3px',
                              boxShadow: '0 0 6px rgba(212, 160, 23, 0.7)',
                            }}
                          />
                          {flash && phase === 'playing' && (
                            <Box
                              key={flash.seq}
                              bold
                              style={{
                                position: 'absolute',
                                left: '0',
                                right: '0',
                                top: `${TRAY_Y - 44}px`,
                                textAlign: 'center',
                                fontSize: '1.3em',
                                color: FLASH_TEXT[flash.kind].color,
                                textShadow: '0 0 4px rgba(0, 0, 0, 0.9)',
                              }}
                            >
                              {FLASH_TEXT[flash.kind].text}
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
                              Validating yield...
                            </Box>
                          )}
                        </Box>
                      </Stack.Item>
                      <Stack.Item>
                        <Box textAlign="center" color="label" bold>
                          <Icon name="left-long" mr={1} />
                          A / ← and D / → slide the tray
                          <Icon name="right-long" ml={1} />
                        </Box>
                      </Stack.Item>
                    </>
                  )}
                  {!inGame && !!data.awaiting_choice && (
                    <Stack.Item>
                      <NoticeBox color={data.botched ? 'bad' : 'good'}>
                        <Icon
                          name={data.botched ? 'triangle-exclamation' : 'gem'}
                          mr={1}
                        />
                        Attempt scored {data.last_attempt_score}/100
                        {data.botched
                          ? ', the chamber is running dangerously hot!'
                          : ''}
                      </NoticeBox>
                    </Stack.Item>
                  )}
                  {!inGame && !data.awaiting_choice && (
                    <Stack.Item>
                      <NoticeBox info>
                        Crystals drop from the chamber ceiling. Slide the tray
                        with A/D or the arrow keys:{' '}
                        <Box inline bold style={{ color: PURE_COLOR }}>
                          catch the pure gems
                        </Box>{' '}
                        and{' '}
                        <Box inline bold style={{ color: TAINTED_COLOR }}>
                          dodge the tainted growths
                        </Box>
                        . Tainted only spoil the batch if they land in the
                        tray.
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
                            tooltip="Lock the chamber in at its best score and finish the cook, the product prints right here."
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
                            tooltip="Retries can only raise your score, but each one caps lower, and re-pressurizing a botched batch widens the blast band."
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
            {data.stage > DrugLabStage.Crystallizer && (
              <Section fill title="Growth Chamber">
                <NoticeBox color="good">
                  <Icon name="check" mr={1} />
                  Chamber locked in at {data.station_score}/100, the cook is
                  complete.
                </NoticeBox>
                <NoticeBox info>
                  The packaged batch printed beside the chamber. Do not leave
                  it behind.
                </NoticeBox>
              </Section>
            )}
          </Stack.Item>
        </Stack>
      </Window.Content>
    </Window>
  );
};
