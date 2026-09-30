import {
  Box,
  Button,
  NoticeBox,
  ProgressBar,
  Section,
  Stack,
} from 'tgui-core/components';
import type { BooleanLike } from 'tgui-core/react';

import { useBackend } from '../backend';
import { Window } from '../layouts';

type Clone = {
  ref: string;
  site: string;
  ready: BooleanLike;
  offline: BooleanLike;
  percent: number;
  unsafe_air: BooleanLike;
  denial: string | null;
  warning: string | null;
};

type Data = {
  alive: BooleanLike;
  clones: Clone[];
};

const CloneRow = (props: { clone: Clone; alive: BooleanLike }) => {
  const { act } = useBackend<Data>();
  const { clone, alive } = props;
  const blocked = alive ? 'You are still alive.' : clone.denial;

  return (
    <Section
      title={clone.site}
      buttons={
        <>
          <Button icon="eye" onClick={() => act('view', { ref: clone.ref })}>
            View
          </Button>
          <Button
            icon="user"
            color="good"
            disabled={!!blocked}
            tooltip={blocked || undefined}
            onClick={() => act('wake', { ref: clone.ref })}
          >
            Wake
          </Button>
        </>
      }
    >
      {clone.ready ? (
        <Box color="good">Ready</Box>
      ) : (
        <ProgressBar value={clone.percent / 100} />
      )}
      {clone.offline ? (
        <Box color="bad" mt={0.5}>
          No power.
        </Box>
      ) : null}
      {clone.unsafe_air ? (
        <Box color="average" mt={0.5}>
          Bad air.
        </Box>
      ) : null}
      {clone.warning ? (
        <Box color="average" mt={0.5}>
          {clone.warning}
        </Box>
      ) : null}
    </Section>
  );
};

export const CloneWake = (props) => {
  const { data } = useBackend<Data>();
  const { alive, clones = [] } = data;

  return (
    <Window title="Clones" width={380} height={420}>
      <Window.Content scrollable>
        <Stack vertical>
          {clones.length === 0 ? (
            <Stack.Item>
              <NoticeBox info>No clones.</NoticeBox>
            </Stack.Item>
          ) : (
            clones.map((clone) => (
              <Stack.Item key={clone.ref}>
                <CloneRow clone={clone} alive={alive} />
              </Stack.Item>
            ))
          )}
        </Stack>
      </Window.Content>
    </Window>
  );
};
