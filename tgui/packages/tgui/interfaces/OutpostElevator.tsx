import {
  Button,
  Dimmer,
  Icon,
  NoticeBox,
  Section,
  Stack,
} from 'tgui-core/components';
import type { BooleanLike } from 'tgui-core/react';

import { useBackend } from '../backend';
import { Window } from '../layouts';

type Floor = {
  id: number;
  name: string;
  occupied: BooleanLike;
  your_ship: BooleanLike;
};

type Data = {
  current_floor: number;
  moving: BooleanLike;
  linked: BooleanLike;
  floors: Floor[];
};

export const OutpostElevator = (props) => {
  const { data, act } = useBackend<Data>();
  const { current_floor, moving, linked, floors } = data;

  return (
    <Window width={300} height={420} theme="retro">
      <Window.Content>
        {!linked && <UnlinkedDimmer />}
        <Stack vertical fill>
          <Stack.Item>
            <NoticeBox info>
              <Icon name="location-dot" mr={1} />
              You are on:{' '}
              {current_floor === 0 ? 'Concourse' : `Berth ${current_floor}`}
            </NoticeBox>
          </Stack.Item>
          <Stack.Item grow>
            <Section fill scrollable title="Floors">
              {!!moving && <MovingDimmer />}
              <Stack vertical>
                {floors.map((floor) => (
                  <Stack.Item key={floor.id}>
                    <Button
                      fluid
                      ellipsis
                      fontSize="14px"
                      bold
                      textAlign="left"
                      icon={floor.your_ship ? 'star' : 'circle'}
                      color={floor.your_ship ? 'good' : 'default'}
                      selected={floor.id === current_floor}
                      disabled={!floor.occupied || floor.id === current_floor}
                      tooltip={
                        floor.id === current_floor
                          ? 'You are here.'
                          : floor.occupied
                            ? undefined
                            : 'Nothing is docked at this berth.'
                      }
                      onClick={() => act('goto', { id: floor.id })}
                    >
                      {`${floor.name}${floor.your_ship ? ' (your ship)' : ''}`}
                    </Button>
                  </Stack.Item>
                ))}
              </Stack>
            </Section>
          </Stack.Item>
        </Stack>
      </Window.Content>
    </Window>
  );
};

const MovingDimmer = () => {
  return (
    <Dimmer>
      <Stack vertical align="center">
        <Stack.Item>
          <Icon size={6} name="spinner" spin />
        </Stack.Item>
        <Stack.Item fontSize="16px">Moving...</Stack.Item>
      </Stack>
    </Dimmer>
  );
};

const UnlinkedDimmer = () => {
  return (
    <Dimmer>
      <Stack vertical align="center">
        <Stack.Item>
          <Icon size={6} name="exclamation" />
        </Stack.Item>
        <Stack.Item fontSize="16px">Out of service.</Stack.Item>
      </Stack>
    </Dimmer>
  );
};
