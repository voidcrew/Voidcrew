import { Box, Tooltip } from 'tgui-core/components';

/** One thing spending neural load: chrome, a nanite program, an implant. */
export type LoadSegment = {
  name: string;
  load: number;
  kind: string;
  tier: number;
};

// Mirrors the CYBERWARE_COLOR_TIER_* defines.
export const TIER_COLORS: Record<number, string> = {
  1: '#ffb347',
  2: '#4dd8e6',
  3: '#ff2079',
  4: '#aaff3c',
};

export const tierColor = (tier: number) => TIER_COLORS[tier] || TIER_COLORS[1];

// Bar colours for load that isn't chrome. Chrome uses its tier colour.
const LOAD_KIND_COLORS: Record<string, string> = {
  nanite: '#9b8cff',
  implant: '#8a8fa8',
  bioware: '#6fcf97',
  organ: '#8a8fa8',
};

export const BROWNOUT_COLOR = '#8c2030';

export const segmentColor = (segment: LoadSegment) =>
  segment.kind === 'chrome'
    ? tierColor(segment.tier)
    : LOAD_KIND_COLORS[segment.kind] || '#8a8fa8';

/**
 * A plain neural load bar for consoles outside the chrome cradle: one segment
 * per source, a mark at capacity, and the name of each segment on hover.
 */
export const NeuralLoadBar = (props: {
  load: number;
  capacity: number;
  segments: LoadSegment[];
}) => {
  const { load, capacity, segments } = props;
  const over = load > capacity;
  const scale = Math.max(capacity, load, 1);

  return (
    <Box style={{ display: 'flex', alignItems: 'center', gap: '8px' }}>
      <Box
        style={{
          position: 'relative',
          display: 'flex',
          flex: '1',
          height: '14px',
          border: '1px solid rgba(255, 255, 255, 0.15)',
          background: 'rgba(0, 0, 0, 0.5)',
        }}
      >
        {segments.map((segment, index) => (
          <Tooltip
            key={`${segment.name}-${index}`}
            content={`${segment.name}: ${segment.load}`}
            position="bottom"
          >
            <div
              style={{
                height: '100%',
                width: `${(segment.load / scale) * 100}%`,
                borderRight: '1px solid rgba(0, 0, 0, 0.85)',
                backgroundColor: over ? BROWNOUT_COLOR : segmentColor(segment),
              }}
            />
          </Tooltip>
        ))}
        <div
          style={{
            position: 'absolute',
            top: '0',
            bottom: '0',
            left: `${(capacity / scale) * 100}%`,
            width: '2px',
            background: 'rgba(255, 255, 255, 0.7)',
          }}
        />
      </Box>
      <Box bold color={over ? 'bad' : undefined} style={{ whiteSpace: 'nowrap' }}>
        {load} / {capacity}
      </Box>
    </Box>
  );
};
