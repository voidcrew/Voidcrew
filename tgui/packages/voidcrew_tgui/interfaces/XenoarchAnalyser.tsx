/**
 * The artifact analyser's bench: a phosphor scope that follows the find on the
 * scan pad, two engraved plates for the last reading, and the paper tape the
 * pad prints while the crew tests the find.
 *
 * Before a scan the scope shows one green trace for the find as a whole. Once a
 * find has been read, each emission gets its own trace in its own colour, and
 * the trace's shape follows how it releases. Nothing here explains a rule; it
 * only shows what the instrument picks up.
 */
import { type ReactNode, useEffect, useRef } from 'react';
import { Box, Button, Stack } from 'tgui-core/components';
import type { BooleanLike } from 'tgui-core/react';

import { useBackend } from '../../tgui/backend';
import { Window } from '../../tgui/layouts';

type Channel = {
  channel: string;
  kind: string;
  kind_key: string;
  release: string;
  release_key: string;
  family: string;
  awake: BooleanLike;
  resting: BooleanLike;
};

type Reading = {
  serial: string;
  name: string;
  damaged: BooleanLike;
  current: BooleanLike;
  channels: Channel[];
};

type Specimen = {
  serial: string;
  name: string;
  awake: BooleanLike;
  resting: BooleanLike;
  label: string | null;
};

type TapeLine = {
  time: string;
  text: string;
  tone: 'note' | 'response' | 'quiet' | 'fault';
  count: number;
};

type Data = {
  powered: BooleanLike;
  pad: 'none' | 'offline' | 'ready';
  scanning: BooleanLike;
  progress: number;
  specimen: Specimen | null;
  reading: Reading | null;
  tape: TapeLine[];
  kind_colors: Record<string, string>;
};

const SCOPE_W = 360;
const SCOPE_H = 190;
const PHOSPHOR = '#7dffa0';
const SCAN_VIOLET = '#c48cff';

/** 0 dormant, 1 resting between runs, 2 awake. */
const activity = (awake: BooleanLike, resting: BooleanLike) =>
  awake ? (resting ? 1 : 2) : 0;

/**
 * A trace two screens wide, so scrolling it left by one screen loops cleanly.
 * Fields roll, bursts spike, contact emissions blip now and then, and anything
 * dormant is just grain.
 */
const wavePath = (shape: string, amp: number, mid: number, seed: number) => {
  const period = shape === 'pulse' ? 90 : shape === 'touch' ? 120 : 60;
  const points: string[] = [];
  for (let x = 0; x <= SCOPE_W * 2; x += 3) {
    const t = (x % period) / period;
    let y = 0;
    if (shape === 'aura') {
      y = Math.sin(t * Math.PI * 2);
    } else if (shape === 'pulse') {
      if (t < 0.08) {
        y = Math.sin((t / 0.08) * Math.PI) * 1.4;
      } else if (t < 0.16) {
        y = -Math.sin(((t - 0.08) / 0.08) * Math.PI) * 0.4;
      }
    } else if (shape === 'touch' && t > 0.45 && t < 0.55) {
      y = Math.sin(((t - 0.45) / 0.1) * Math.PI);
    }
    const grain = Math.sin(x * 12.9898 + seed) * 43758.5453;
    y += (grain - Math.floor(grain) - 0.5) * 0.18;
    points.push(`${x},${(mid - y * amp).toFixed(1)}`);
  }
  return `M${points.join(' L')}`;
};

const Trace = (props: {
  shape: string;
  level: number;
  mid: number;
  color: string;
  seed: number;
}) => {
  const { shape, level, mid, color, seed } = props;
  const amp = level === 2 ? 34 : level === 1 ? 14 : 3;
  return (
    <g>
      <animateTransform
        attributeName="transform"
        type="translate"
        from="0 0"
        to={`-${SCOPE_W} 0`}
        dur={level === 2 ? '2.2s' : '4.5s'}
        repeatCount="indefinite"
      />
      <path
        d={wavePath(level ? shape : 'noise', amp, mid, seed)}
        fill="none"
        stroke={color}
        strokeWidth={1.6}
        opacity={level ? 1 : 0.7}
        style={{ filter: `drop-shadow(0 0 3px ${color})` }}
      />
    </g>
  );
};

const scopeMessage = (data: Data) => {
  if (data.pad === 'none') {
    return 'NO PAD';
  }
  if (data.pad === 'offline') {
    return 'PAD OFFLINE';
  }
  if (!data.specimen) {
    return 'PAD CLEAR';
  }
  return '';
};

const Scope = (props: { data: Data }) => {
  const { data } = props;
  const { powered, scanning, progress, specimen, reading, kind_colors } = data;
  const channels = reading?.current ? reading.channels : null;
  const lines: ReactNode[] = [];
  if (powered) {
    for (let x = 0; x <= SCOPE_W; x += 36) {
      lines.push(
        <line
          key={`x${x}`}
          x1={x}
          y1={0}
          x2={x}
          y2={SCOPE_H}
          stroke="#1d4a2c"
        />,
      );
    }
    for (let y = 0; y <= SCOPE_H; y += 38) {
      lines.push(
        <line
          key={`y${y}`}
          x1={0}
          y1={y}
          x2={SCOPE_W}
          y2={y}
          stroke="#1d4a2c"
        />,
      );
    }
  }
  const midFor = (index: number, count: number) =>
    count > 1 ? (index ? 140 : 58) : SCOPE_H / 2;
  const message = powered ? scopeMessage(data) : '';
  const sweepX = (SCOPE_W * progress) / 100;
  return (
    <Box
      style={{
        background: '#2b2d2f',
        borderRadius: '14px',
        padding: '10px',
        boxShadow: 'inset 0 0 0 2px #45484c, 0 2px 0 #111',
      }}
    >
      <svg
        width={SCOPE_W}
        height={SCOPE_H}
        style={{
          display: 'block',
          borderRadius: '10px',
          background: powered
            ? 'radial-gradient(circle at 50% 45%, #0f2a18 0%, #06120a 75%)'
            : '#0b0c0c',
        }}
      >
        {lines}
        {!!powered &&
          !!specimen &&
          (channels ? (
            channels.map((ch, i) => (
              <Trace
                key={ch.channel}
                shape={ch.release_key}
                level={activity(ch.awake, ch.resting)}
                mid={midFor(i, channels.length)}
                color={kind_colors[ch.kind_key] || PHOSPHOR}
                seed={i * 7}
              />
            ))
          ) : (
            <Trace
              shape="aura"
              level={activity(specimen.awake, specimen.resting)}
              mid={SCOPE_H / 2}
              color={PHOSPHOR}
              seed={3}
            />
          ))}
        {!!powered && !!scanning && (
          <>
            <rect
              x={0}
              y={0}
              width={sweepX}
              height={SCOPE_H}
              fill={SCAN_VIOLET}
              opacity={0.08}
            />
            <line
              x1={sweepX}
              x2={sweepX}
              y1={0}
              y2={SCOPE_H}
              stroke={SCAN_VIOLET}
              strokeWidth={2}
              style={{ filter: `drop-shadow(0 0 4px ${SCAN_VIOLET})` }}
            />
            <text
              x={SCOPE_W - 10}
              y={18}
              fill={SCAN_VIOLET}
              fontFamily="monospace"
              fontSize={12}
              textAnchor="end"
            >
              SCAN {progress}%
            </text>
          </>
        )}
        {!!powered && !!specimen && (
          <text
            x={10}
            y={18}
            fill={PHOSPHOR}
            fontFamily="monospace"
            fontSize={12}
          >
            {specimen.serial.toUpperCase()}
          </text>
        )}
        {!!powered &&
          !!specimen &&
          !!channels &&
          channels.map((ch, i) => (
            <text
              key={ch.channel}
              x={10}
              y={channels.length > 1 ? (i ? 182 : 100) : SCOPE_H - 8}
              fill={kind_colors[ch.kind_key] || PHOSPHOR}
              fontFamily="monospace"
              fontSize={10}
              opacity={0.8}
            >
              CH{i + 1}
            </text>
          ))}
        {!!message && (
          <text
            x={SCOPE_W / 2}
            y={SCOPE_H / 2 + 5}
            fill={PHOSPHOR}
            opacity={0.6}
            fontFamily="monospace"
            fontSize={16}
            textAnchor="middle"
          >
            {message}
          </text>
        )}
      </svg>
    </Box>
  );
};

/** The specimen's paper card on the bench. */
const Nameplate = (props: { data: Data }) => {
  const { powered, specimen, reading } = props.data;
  const shown = powered ? specimen : null;
  return (
    <Box
      style={{
        background: '#d9d4c3',
        color: '#2a2a28',
        padding: '6px 8px',
        borderRadius: '3px',
        fontFamily: 'monospace',
        minHeight: '58px',
        boxShadow: '0 2px 0 #0008',
      }}
    >
      <Box style={{ fontSize: '15px', fontWeight: 'bold' }}>
        {shown ? shown.serial : '- - - -'}
      </Box>
      <Box>{shown ? shown.name : ''}</Box>
      {!!shown && !!reading?.current && !!reading.damaged && (
        <Box style={{ color: '#8a3b1c' }}>fractured</Box>
      )}
      {!!shown?.label && (
        <Box style={{ marginTop: '4px', fontSize: '11px', color: '#6b2d8a' }}>
          Tag: {shown.label}
        </Box>
      )}
    </Box>
  );
};

/** An engraved plate holding one emission's reading. */
const Plate = (props: {
  label: string;
  channel?: Channel;
  color?: string;
  empty: string;
}) => {
  const { label, channel, color, empty } = props;
  return (
    <Box
      style={{
        height: '100%',
        background: 'linear-gradient(#5b5f63, #474a4e)',
        border: '1px solid #2a2c2e',
        borderRadius: '4px',
        padding: '6px 8px',
        minHeight: '66px',
        color: '#e8e6dc',
        boxShadow: 'inset 0 1px 0 #6d7175',
      }}
    >
      <Box
        style={{
          fontSize: '10px',
          letterSpacing: '2px',
          color: '#b9b6aa',
          marginBottom: '3px',
          textShadow: '0 1px 0 #2a2c2e',
        }}
      >
        {label}
      </Box>
      {channel ? (
        <>
          <Box style={{ fontWeight: 'bold', color }}>{channel.kind}</Box>
          <Box>{channel.release}</Box>
          <Box style={{ color: '#cfccc0' }}>{channel.family}</Box>
        </>
      ) : (
        <Box style={{ color: '#9a978c' }}>{empty}</Box>
      )}
    </Box>
  );
};

const INK: Record<string, string> = {
  note: '#3b3a36',
  response: '#9b1d1d',
  quiet: '#8d8a80',
  fault: '#a8561b',
};

/** The tape the pad prints on, newest line at the bottom. */
const Tape = (props: { tape: TapeLine[] }) => {
  const { tape } = props;
  const roll = useRef<HTMLDivElement>(null);
  const last = tape[tape.length - 1];
  useEffect(() => {
    if (roll.current) {
      roll.current.scrollTop = roll.current.scrollHeight;
    }
  }, [tape.length, last?.text, last?.count]);
  return (
    <div
      ref={roll}
      style={{
        height: '100%',
        overflowY: 'auto',
        background:
          'repeating-linear-gradient(#f1ecdc 0 17px, #e9e3d0 17px 18px)',
        color: INK.note,
        fontFamily: 'monospace',
        fontSize: '12px',
        lineHeight: '18px',
        padding: '4px 10px',
        borderLeft: '6px dotted #cfc8b2',
        borderRight: '6px dotted #cfc8b2',
        boxShadow: '0 3px 8px #0009',
      }}
    >
      {tape.map((line, i) => (
        <div key={i} style={{ color: INK[line.tone] || INK.note }}>
          <span style={{ opacity: 0.6 }}>{line.time}</span>
          {'  '}
          {line.text}
          {line.count > 1 ? ` x${line.count}` : ''}
        </div>
      ))}
    </div>
  );
};

/** A chunky bench key. */
const Key = (props: {
  label: string;
  icon?: string;
  color: string;
  disabled: boolean;
  height?: string;
  onClick: () => void;
}) => {
  const { label, icon, color, disabled, onClick } = props;
  const height = props.height ?? '44px';
  return (
    <Button
      fluid
      icon={icon}
      disabled={disabled}
      onClick={onClick}
      style={{
        height,
        lineHeight: height,
        textAlign: 'center',
        fontWeight: 'bold',
        letterSpacing: '3px',
        borderRadius: '6px',
        background: disabled ? '#3a3c3f' : color,
        color: disabled ? '#6a6c6f' : '#111',
        boxShadow: '0 3px 0 #111',
      }}
    >
      {label}
    </Button>
  );
};

export const XenoarchAnalyser = () => {
  const { act, data } = useBackend<Data>();
  const { powered, pad, scanning, specimen, reading, tape, kind_colors } = data;
  const channels = reading?.current ? reading.channels : [];
  const read = !!powered && !!reading?.current;
  const canScan = !!powered && pad === 'ready' && !!specimen && !scanning;
  return (
    <Window width={600} height={560} theme="ntos_darkmode">
      <Window.Content style={{ background: '#1d1f21' }}>
        <Stack vertical fill>
          <Stack.Item>
            <Stack>
              <Stack.Item>
                <Scope data={data} />
              </Stack.Item>
              <Stack.Item grow>
                <Stack vertical fill>
                  <Stack.Item>
                    <Nameplate data={data} />
                  </Stack.Item>
                  <Stack.Item grow />
                  <Stack.Item>
                    <Key
                      label="SCAN"
                      color="#8fd19e"
                      disabled={!canScan}
                      onClick={() => act('scan')}
                    />
                  </Stack.Item>
                  <Stack.Item>
                    <Key
                      label="HALT"
                      color="#e39a7a"
                      disabled={!powered || !scanning}
                      onClick={() => act('halt')}
                    />
                  </Stack.Item>
                </Stack>
              </Stack.Item>
            </Stack>
          </Stack.Item>
          <Stack.Item>
            <Stack>
              <Stack.Item grow basis={0}>
                <Plate
                  label="PRIMARY"
                  channel={read ? channels[0] : undefined}
                  color={channels[0] && kind_colors[channels[0].kind_key]}
                  empty={read ? 'None detected.' : '-'}
                />
              </Stack.Item>
              <Stack.Item grow basis={0}>
                <Plate
                  label="SECONDARY"
                  channel={read ? channels[1] : undefined}
                  color={channels[1] && kind_colors[channels[1].kind_key]}
                  empty={read ? 'None detected.' : '-'}
                />
              </Stack.Item>
            </Stack>
          </Stack.Item>
          <Stack.Item grow>
            <Stack fill>
              <Stack.Item grow>
                <Tape tape={tape} />
              </Stack.Item>
              <Stack.Item width="64px">
                <Stack vertical fill>
                  <Stack.Item grow />
                  <Stack.Item>
                    <Key
                      label=""
                      icon="scissors"
                      color="#d9d4c3"
                      height="36px"
                      disabled={!tape.length}
                      onClick={() => act('tear')}
                    />
                  </Stack.Item>
                </Stack>
              </Stack.Item>
            </Stack>
          </Stack.Item>
        </Stack>
      </Window.Content>
    </Window>
  );
};
