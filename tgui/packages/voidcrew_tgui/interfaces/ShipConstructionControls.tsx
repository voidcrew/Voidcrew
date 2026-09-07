import { Box, Button, LabeledList, Section, Stack } from 'tgui-core/components';
import type { BooleanLike } from 'tgui-core/react';

import { useBackend } from '../../tgui/backend';

export interface ConstructionControlsData {
  queueUnlocked: BooleanLike;
  areaUnlocked: BooleanLike;
  queueEnabled: BooleanLike;
  queuePaused: BooleanLike;
  queueStatus: string;
  buildSize: number;
  turfBuildMode: 'auto' | 'floor' | 'wall';
  buildTimePercent: number;
  jobs: { ref: string; name: string; x: number; y: number }[];
}

export const ShipConstructionControls = () => {
  const { act, data } = useBackend<ConstructionControlsData>();
  const {
    queueUnlocked,
    areaUnlocked,
    queueEnabled,
    queuePaused,
    queueStatus,
    buildSize,
    turfBuildMode,
    buildTimePercent,
    jobs = [],
  } = data;
  return (
    <Section title="Construction settings">
      <LabeledList>
        <LabeledList.Item label="Fabrication time">
          {buildTimePercent === 0
            ? 'Instant'
            : `${buildTimePercent}% of base time`}
        </LabeledList.Item>
        <LabeledList.Item label="Floor / wall blueprint">
          {(['auto', 'floor', 'wall'] as const).map((mode) => (
            <Button
              key={mode}
              selected={turfBuildMode === mode}
              disabled={mode === 'auto' && buildSize > 1}
              onClick={() => act('turf_build_mode', { mode })}
            >
              {mode === 'auto'
                ? 'Auto'
                : mode === 'floor'
                  ? 'Floors only'
                  : 'Walls only'}
            </Button>
          ))}
        </LabeledList.Item>
        <LabeledList.Item label="Brush">
          {[1, 2, 3].map((size) => (
            <Button
              key={size}
              selected={buildSize === size}
              disabled={size > 1 && !areaUnlocked}
              onClick={() => act('build_size', { size: String(size) })}
            >
              {size}×{size}
            </Button>
          ))}
        </LabeledList.Item>
      </LabeledList>
      <Box color="label" mt={1}>
        Area brushes skip existing tiles. 3×3 is centered on the drone; 2×2
        extends north and east. Applies to RCD builds, tiles and decals.
      </Box>
      {!!queueUnlocked && (
        <Stack vertical mt={1}>
          <Stack.Item>
            <Button.Checkbox
              checked={queueEnabled}
              disabled={buildSize > 1}
              onClick={() => act('queue_toggle')}
            >
              Queue builds
            </Button.Checkbox>
            <Button
              icon={queuePaused ? 'play' : 'pause'}
              onClick={() => act('queue_pause')}
            >
              {queuePaused ? 'Resume' : 'Pause'}
            </Button>
            <Button
              disabled={jobs.length === 0}
              color="bad"
              onClick={() => act('queue_clear')}
            >
              Clear queue
            </Button>
          </Stack.Item>
          <Stack.Item>
            {jobs.length}/128 jobs · {queueStatus}
          </Stack.Item>
          {jobs.length > 0 && (
            <Stack.Item maxHeight="110px" overflowY="auto">
              {jobs.map((job) => (
                <Box key={job.ref}>
                  <Button
                    icon="times"
                    tooltip="Cancel this job"
                    onClick={() => act('queue_remove', { ref: job.ref })}
                  />
                  {job.name} ({job.x}, {job.y})
                </Box>
              ))}
            </Stack.Item>
          )}
        </Stack>
      )}
      {!queueUnlocked && (
        <Box color="label" mt={1}>
          Install a job queue disk to queue construction.
        </Box>
      )}
    </Section>
  );
};
