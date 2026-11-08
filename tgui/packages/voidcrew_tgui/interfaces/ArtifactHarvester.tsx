/**
 * Exotic particle harvester: a phosphor scope traces the signal of the find beside the machine,
 * in its energy's colour, and a glass tube fills with the battery's colour as it draws.
 * DM side: voidcrew/modules/xenoarch/use/harvester.dm.
 */
import { Box, Button, Stack } from 'tgui-core/components';

import { useBackend } from '../../tgui/backend';
import { Window } from '../../tgui/layouts';

type Source = {
  serial: string;
  state: string;
  color: string | null;
};

type Cell = {
  fill: number;
  color: string | null;
  kind: string | null;
  serial: string | null;
};

type Data = {
  powered: number;
  drawing: number;
  source: Source | null;
  cell: Cell | null;
};

const WORDS: Record<string, string> = {
  ready: 'SIGNAL',
  drawing: 'DRAWING',
  quiet: 'NO SIGNAL',
  tangled: 'CROSSED',
  unfit: 'WILL NOT HOLD',
  spent: 'SPENT',
  busy: 'ENGAGED',
  mismatch: 'CELL MISMATCH',
};

const SCREEN_W = 240;
const SCREEN_H = 90;
const PHOSPHOR = '#59d48a';
/** One period of the base wave in pixels; animated traces only use whole harmonics of it. */
const PERIOD = 2 * Math.PI * 20;

/** The trace for a state, twice the screen wide so it can scroll seamlessly. */
function tracePath(state: string): string {
  const points: string[] = [];
  for (let x = 0; x <= SCREEN_W * 2; x += 3) {
    const t = x / 20;
    let y: number;
    switch (state) {
      case 'ready':
      case 'drawing':
        y = Math.sin(t) * 22;
        break;
      case 'tangled':
        y = Math.sin(t) * 15 + Math.sin(t * 3 + 1) * 13;
        break;
      case 'unfit':
        y = Math.sin(t * 3) * 26 * Math.exp(-((x % 60) / 16));
        break;
      case 'mismatch':
        y = Math.sin(t) * 12 + Math.sin(t * 5) * 6;
        break;
      case 'busy':
        y = Math.sign(Math.sin(t * 0.8)) * 14;
        break;
      default:
        y = Math.sin(t * 7) * 1.2;
    }
    points.push(`${x},${(SCREEN_H / 2 - y).toFixed(1)}`);
  }
  return `M ${points.join(' L ')}`;
}

const MOVING = ['ready', 'drawing', 'tangled'];

function Scope(props: { state: string; color: string; lit: boolean }) {
  const { state, color, lit } = props;
  return (
    <svg width={SCREEN_W} height={SCREEN_H} style={{ display: 'block' }}>
      <rect
        width={SCREEN_W}
        height={SCREEN_H}
        fill={lit ? '#06120b' : '#050607'}
      />
      {[...Array(9)].map((_, i) => (
        <line
          key={`v${i}`}
          x1={(i + 1) * (SCREEN_W / 10)}
          y1={0}
          x2={(i + 1) * (SCREEN_W / 10)}
          y2={SCREEN_H}
          stroke={lit ? '#16301f' : '#0d1210'}
        />
      ))}
      {[...Array(3)].map((_, i) => (
        <line
          key={`h${i}`}
          x1={0}
          y1={(i + 1) * (SCREEN_H / 4)}
          x2={SCREEN_W}
          y2={(i + 1) * (SCREEN_H / 4)}
          stroke={lit ? '#16301f' : '#0d1210'}
        />
      ))}
      {lit ? (
        <path
          d={tracePath(state)}
          fill="none"
          stroke={color}
          strokeWidth="2"
          opacity={state === 'spent' || state === 'none' ? 0.45 : 1}
          style={{ filter: `drop-shadow(0 0 3px ${color})` }}
        >
          {MOVING.includes(state) ? (
            <animateTransform
              attributeName="transform"
              type="translate"
              from="0 0"
              to={`-${PERIOD.toFixed(2)} 0`}
              dur={state === 'drawing' ? '0.6s' : '1.6s'}
              repeatCount="indefinite"
            />
          ) : null}
        </path>
      ) : null}
    </svg>
  );
}

function Tube(props: { fill: number; color: string | null; live: boolean }) {
  const { fill, color, live } = props;
  const height = 104;
  const level = Math.round(height * Math.max(0, Math.min(1, fill)));
  return (
    <Box
      style={{
        width: '28px',
        height: `${height + 6}px`,
        border: '2px solid #8a929e',
        borderRadius: '14px',
        background: '#0b0d10',
        position: 'relative',
        overflow: 'hidden',
        boxShadow: 'inset 0 0 6px #000',
      }}
    >
      <Box
        style={{
          position: 'absolute',
          bottom: '3px',
          left: '3px',
          right: '3px',
          height: `${level}px`,
          borderRadius: '10px',
          background: color || '#2a2d33',
          boxShadow: color && live ? `0 0 10px ${color}` : 'none',
          opacity: color ? 0.9 : 0.5,
          transition: 'height 0.8s ease-out',
        }}
      />
      <Box
        style={{
          position: 'absolute',
          top: '4px',
          left: '6px',
          width: '4px',
          bottom: '8px',
          background: '#ffffff22',
          borderRadius: '2px',
        }}
      />
    </Box>
  );
}

const etched = {
  fontFamily: 'monospace',
  fontSize: '10px',
  letterSpacing: '2px',
  color: '#8f98a6',
};

export const ArtifactHarvester = (props) => {
  const { act, data } = useBackend<Data>();
  const { powered, drawing, source, cell } = data;
  const state = source ? source.state : 'none';
  const lit = !!powered;
  const traceColor =
    (state === 'drawing' || state === 'ready') && source?.color
      ? source.color
      : PHOSPHOR;
  const canDraw =
    lit && !drawing && !!cell && cell.fill < 1 && state === 'ready';
  return (
    <Window width={340} height={200}>
      <Window.Content
        style={{ background: 'linear-gradient(#34383f, #24272c)' }}
      >
        <Stack>
          <Stack.Item>
            <Box
              style={{
                border: '3px solid #111317',
                borderRadius: '6px',
                padding: '2px',
                background: '#0a0b0d',
                boxShadow: '0 0 0 1px #4a505a',
              }}
            >
              <Scope state={state} color={traceColor} lit={lit} />
            </Box>
            <Stack mt={0.5}>
              <Stack.Item grow style={etched}>
                {source ? source.serial.toUpperCase() : 'NO SOURCE'}
              </Stack.Item>
              <Stack.Item style={{ ...etched, color: lit ? traceColor : '#3a3f47' }}>
                {source ? WORDS[state] || '' : ''}
              </Stack.Item>
            </Stack>
          </Stack.Item>
          <Stack.Item ml={1.5}>
            <Tube
              fill={cell ? cell.fill : 0}
              color={cell ? cell.color : null}
              live={!!drawing}
            />
            <Box mt={0.5} style={etched} textAlign="center">
              CELL
            </Box>
          </Stack.Item>
        </Stack>
        <Stack mt={1}>
          <Stack.Item grow>
            {drawing ? (
              <Button fluid color="bad" onClick={() => act('halt')}>
                HALT
              </Button>
            ) : (
              <Button fluid disabled={!canDraw} onClick={() => act('draw')}>
                DRAW
              </Button>
            )}
          </Stack.Item>
          <Stack.Item>
            <Button
              disabled={!cell?.color || !!drawing}
              onClick={() => act('purge')}
            >
              VENT
            </Button>
          </Stack.Item>
          <Stack.Item>
            <Button disabled={!cell || !!drawing} onClick={() => act('eject')}>
              EJECT
            </Button>
          </Stack.Item>
        </Stack>
      </Window.Content>
    </Window>
  );
};
