/**
 * Exotic utilizer: one power button ringed by the battery's charge, glowing in the colour of the
 * energy it holds. DM side: voidcrew/modules/xenoarch/use/utilizer.dm.
 */
import { Box, Button, Stack } from 'tgui-core/components';

import { useBackend } from '../../tgui/backend';
import { Window } from '../../tgui/layouts';

type Cell = {
  fill: number;
  color: string | null;
  serial: string | null;
  mode: string | null;
};

type Data = {
  emitting: number;
  cell: Cell | null;
};

const RING_R = 52;
const RING_C = 2 * Math.PI * RING_R;

export const AnomalyUtilizer = (props) => {
  const { act, data } = useBackend<Data>();
  const { emitting, cell } = data;
  const on = !!emitting;
  const color = cell?.color || '#4b5563';
  const fill = cell ? Math.max(0, Math.min(1, cell.fill)) : 0;
  return (
    <Window width={240} height={226}>
      <Window.Content style={{ background: '#1f2126' }}>
        <Box textAlign="center">
          <svg width="140" height="140" viewBox="0 0 140 140">
            <circle
              cx="70"
              cy="70"
              r={RING_R}
              fill="none"
              stroke="#2b2f36"
              strokeWidth="10"
            />
            <circle
              cx="70"
              cy="70"
              r={RING_R}
              fill="none"
              stroke={color}
              strokeWidth="10"
              strokeDasharray={`${(RING_C * fill).toFixed(1)} ${RING_C.toFixed(1)}`}
              transform="rotate(-90 70 70)"
              style={{ filter: on ? `drop-shadow(0 0 4px ${color})` : 'none' }}
            >
              {on ? (
                <animate
                  attributeName="opacity"
                  values="1;0.55;1"
                  dur="1.6s"
                  repeatCount="indefinite"
                />
              ) : null}
            </circle>
            <circle
              cx="70"
              cy="70"
              r="34"
              fill={on ? color : '#2b2f36'}
              stroke="#111317"
              strokeWidth="3"
              style={{
                cursor: cell ? 'pointer' : 'default',
                filter: on ? `drop-shadow(0 0 8px ${color})` : 'none',
              }}
              onClick={() => act('power')}
            />
            <text
              x="70"
              y="75"
              textAnchor="middle"
              fontFamily="monospace"
              fontSize="13"
              fill={on ? '#0b0d10' : '#8f98a6'}
              style={{ pointerEvents: 'none' }}
            >
              {on ? 'EMIT' : 'OFF'}
            </text>
          </svg>
        </Box>
        <Stack align="center">
          <Stack.Item
            grow
            style={{
              fontFamily: 'monospace',
              fontSize: '11px',
              letterSpacing: '1px',
              color: '#c9b98f',
            }}
          >
            {cell?.serial ? cell.serial.toUpperCase() : 'NO CELL'}
            {cell?.mode ? ` · ${cell.mode.toUpperCase()}` : ''}
          </Stack.Item>
          <Stack.Item>
            <Button disabled={!cell} onClick={() => act('eject')}>
              EJECT
            </Button>
          </Stack.Item>
        </Stack>
      </Window.Content>
    </Window>
  );
};
