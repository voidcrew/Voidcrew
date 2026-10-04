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

type Destination = {
  id: string;
  name: string;
  zone: number | null;
  zoneName: string;
  fee: number;
  available: BooleanLike;
  reason: string | null;
};

type Charging = {
  destination: string;
  secondsLeft: number;
  total: number;
  mine: BooleanLike;
};

type Data = {
  padName: string;
  online: BooleanLike;
  blocked: string | null;
  charging: Charging | null;
  destinations: Destination[];
};

const ZONE_COLORS: Record<number, string> = {
  1: 'good',
  2: 'average',
  3: 'bad',
};

const zoneColor = (zone: number | null) =>
  zone ? ZONE_COLORS[zone] || 'label' : 'label';

export const OutpostTeleporter = () => {
  const { act, data } = useBackend<Data>();
  const { padName, online, blocked, charging, destinations = [] } = data;

  return (
    <Window width={400} height={440} title={padName}>
      <Window.Content scrollable>
        {!online ? (
          <NoticeBox danger>Not linked to the network.</NoticeBox>
        ) : charging ? (
          <Section
            title={`To ${charging.destination}`}
            buttons={
              charging.mine ? (
                <Button icon="xmark" color="bad" onClick={() => act('cancel')}>
                  Cancel
                </Button>
              ) : null
            }
          >
            <ProgressBar
              value={Math.max(0, charging.total - charging.secondsLeft)}
              maxValue={Math.max(charging.total, 0.1)}
            />
          </Section>
        ) : (
          <DestinationList destinations={destinations} blocked={blocked} />
        )}
      </Window.Content>
    </Window>
  );
};

type ListProps = {
  destinations: Destination[];
  blocked: string | null;
};

const DestinationList = (props: ListProps) => {
  const { act } = useBackend<Data>();
  const { destinations, blocked } = props;
  return (
    <Section
      buttons={
        blocked === 'Stand on the pad.' ? (
          <Button
            icon="person-walking-arrow-right"
            onClick={() => act('clear_pad')}
          >
            Clear pad
          </Button>
        ) : null
      }
    >
      {blocked ? (
        <Box color="average" mb={1}>
          {blocked}
        </Box>
      ) : null}
      {destinations.length === 0 ? (
        <Box color="label">No destinations.</Box>
      ) : (
        <Stack vertical>
          {destinations.map((dest) => (
            <Stack.Item key={dest.id}>
              <Stack align="center">
                <Stack.Item grow>
                  <Box bold>{dest.name}</Box>
                  <Box color={zoneColor(dest.zone)} fontSize={0.9}>
                    {dest.zoneName}
                  </Box>
                </Stack.Item>
                <Stack.Item>
                  <Box color={dest.fee > 0 ? 'average' : 'good'}>
                    {dest.fee > 0 ? `${dest.fee} cr` : 'Free'}
                  </Box>
                </Stack.Item>
                <Stack.Item>
                  <Button
                    icon="bolt"
                    disabled={!dest.available || !!blocked}
                    onClick={() =>
                      act('depart', { id: dest.id, fee: dest.fee })
                    }
                  >
                    {dest.available ? 'Travel' : dest.reason}
                  </Button>
                </Stack.Item>
              </Stack>
            </Stack.Item>
          ))}
        </Stack>
      )}
    </Section>
  );
};
