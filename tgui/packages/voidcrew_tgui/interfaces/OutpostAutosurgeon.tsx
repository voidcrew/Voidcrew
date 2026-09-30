import {
  Box,
  Button,
  NoticeBox,
  ProgressBar,
  Section,
  Stack,
} from 'tgui-core/components';
import type { BooleanLike } from 'tgui-core/react';

import { useBackend } from '../../tgui/backend';
import { Window } from '../../tgui/layouts';

type Occupant = {
  name: string;
  health: number;
  maxHealth: number;
};

type Offer = {
  id: string;
  name: string;
  available: BooleanLike;
  reason: string | null;
};

type Run = {
  id: string;
  name: string;
  elapsed: number;
  total: number;
  stage: string;
};

type Data = {
  occupant: Occupant | null;
  occupant_is_user: BooleanLike;
  can_unbuckle: BooleanLike;
  consent_denial: string | null;
  offers: Offer[];
  run: Run | null;
  powered: BooleanLike;
};

export const OutpostAutosurgeon = () => {
  const { act, data } = useBackend<Data>();
  const {
    occupant,
    occupant_is_user,
    can_unbuckle,
    consent_denial,
    offers = [],
    run,
    powered,
  } = data;
  const blocked = !occupant_is_user
    ? 'Patient only.'
    : run
      ? null
      : consent_denial;
  return (
    <Window width={400} height={440} title="Auto-surgeon">
      <Window.Content scrollable>
        {!powered ? <NoticeBox danger>No power.</NoticeBox> : null}
        <Section
          title="Patient"
          buttons={
            occupant ? (
              <Button
                icon="person-walking"
                disabled={!occupant_is_user && !can_unbuckle}
                onClick={() => act('get_up')}
              >
                {occupant_is_user ? 'Get up' : 'Help off'}
              </Button>
            ) : null
          }
        >
          {occupant ? (
            <Stack align="center">
              <Stack.Item grow>{occupant.name}</Stack.Item>
              <Stack.Item width="50%">
                <ProgressBar
                  value={occupant.health}
                  minValue={-100}
                  maxValue={occupant.maxHealth}
                  ranges={{
                    good: [occupant.maxHealth * 0.7, Infinity],
                    average: [0, occupant.maxHealth * 0.7],
                    bad: [-Infinity, 0],
                  }}
                />
              </Stack.Item>
            </Stack>
          ) : (
            <Box color="label">Empty.</Box>
          )}
        </Section>
        {run ? (
          <Section
            title={run.name}
            buttons={
              occupant_is_user ? (
                <Button icon="stop" color="bad" onClick={() => act('cancel')}>
                  Stop
                </Button>
              ) : null
            }
          >
            <Box mb={1}>{run.stage}</Box>
            <ProgressBar
              value={run.elapsed}
              maxValue={Math.max(1, run.total)}
            />
          </Section>
        ) : null}
        {occupant ? (
          <Section title="Procedures">
            {offers.length === 0 ? (
              <Box color="label">Nothing on offer.</Box>
            ) : (
              <Stack vertical>
                {offers.map((offer) => (
                  <Stack.Item key={offer.id}>
                    <Stack align="center">
                      <Stack.Item grow>
                        <Box bold>{offer.name}</Box>
                        {offer.available ? null : (
                          <Box color="label" fontSize="0.9em">
                            {offer.reason}
                          </Box>
                        )}
                      </Stack.Item>
                      <Stack.Item>
                        <Button
                          icon="play"
                          disabled={!!run || !!blocked || !offer.available}
                          tooltip={blocked || undefined}
                          onClick={() => act('start', { id: offer.id })}
                        >
                          Start
                        </Button>
                      </Stack.Item>
                    </Stack>
                  </Stack.Item>
                ))}
              </Stack>
            )}
          </Section>
        ) : null}
      </Window.Content>
    </Window>
  );
};
