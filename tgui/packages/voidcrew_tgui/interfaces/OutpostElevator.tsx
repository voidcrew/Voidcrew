import type { CSSProperties } from 'react';
import {
  Box,
  Button,
  Dimmer,
  Icon,
  NoticeBox,
  Section,
  Stack,
} from 'tgui-core/components';
import type { BooleanLike } from 'tgui-core/react';

import { useBackend } from '../../tgui/backend';
import { Window } from '../../tgui/layouts';

type Floor = {
  id: number;
  // Leased floors say 'floor'. Rows without a kind are the concourse, berths and bays.
  kind?: 'concourse' | 'berth' | 'bay' | 'floor';
  name: string;
  occupied: BooleanLike;
  your_ship: BooleanLike;
  locked?: BooleanLike;
  // Leased floors only
  crew?: string;
  mark?: 'yours' | 'private' | 'open';
  accent?: string;
};

type Data = {
  current_floor: number;
  moving: BooleanLike;
  linked: BooleanLike;
  floors: Floor[];
};

// A floor's name and its crew's are each one line of this many characters at most
const LINE_MAX = 24;
// The window as it is with no leased floor to show, and what each floor's row adds: six floors
// fit without scrolling. The list scrolls past the cap, and tgui keeps a window inside the screen.
const HEIGHT_BASE = 420;
const HEIGHT_WITH_FLOORS = 388;
const HEIGHT_PER_FLOOR = 48;
const HEIGHT_MAX = 680;

const MARKS = {
  yours: 'Yours',
  private: 'Private',
  open: 'Open',
};

// One line, cut where the row ends: a row never grows past the window or into its mark
const ONE_LINE: CSSProperties = {
  overflow: 'hidden',
  textOverflow: 'ellipsis',
  whiteSpace: 'nowrap',
};

// Two lines at most, broken anywhere: a long name never pushes the list down or runs off the box
const TWO_LINES: CSSProperties = {
  display: '-webkit-box',
  WebkitBoxOrient: 'vertical',
  WebkitLineClamp: 2,
  overflow: 'hidden',
  overflowWrap: 'anywhere',
};

const cutLine = (text?: string) => {
  const letters = Array.from(text ?? '');
  if (letters.length <= LINE_MAX) {
    return letters.join('');
  }
  return `${letters
    .slice(0, LINE_MAX - 1)
    .join('')
    .trimEnd()}…`;
};

// The accent is one of the game's eight colours. Anything else is drawn neutral.
const accentOf = (floor: Floor) =>
  floor.accent && /^#[0-9a-f]{6}$/i.test(floor.accent)
    ? floor.accent
    : '#888888';

export const OutpostElevator = (props) => {
  const { data, act } = useBackend<Data>();
  const { current_floor, moving, linked, floors } = data;
  const levels = floors.filter((floor) => floor.kind !== 'floor');
  const leased = floors.filter((floor) => floor.kind === 'floor');
  const here = floors.find((floor) => floor.id === current_floor);
  const hereName = !here
    ? 'Unknown floor'
    : here.kind === 'floor'
      ? cutLine(here.name)
      : here.name;

  const height = Math.min(
    HEIGHT_MAX,
    Math.max(
      HEIGHT_BASE,
      leased.length > 0
        ? HEIGHT_WITH_FLOORS + leased.length * HEIGHT_PER_FLOOR
        : 0,
    ),
  );

  return (
    <Window width={300} height={height} theme="retro">
      <Window.Content>
        {!linked && <UnlinkedDimmer />}
        <Stack vertical fill>
          <Stack.Item>
            <NoticeBox info>
              <Box style={TWO_LINES}>
                <Icon name="location-dot" mr={1} />
                You are on: {hereName}
              </Box>
            </NoticeBox>
          </Stack.Item>
          <Stack.Item grow>
            <Section fill scrollable title="Floors">
              {!!moving && <MovingDimmer />}
              <Stack vertical>
                {levels.map((floor) => (
                  <Stack.Item key={floor.id}>
                    <Button
                      fluid
                      ellipsis
                      fontSize="14px"
                      bold
                      textAlign="left"
                      icon={
                        floor.your_ship
                          ? 'star'
                          : floor.locked
                            ? 'lock'
                            : 'circle'
                      }
                      color={floor.your_ship ? 'good' : 'default'}
                      selected={floor.id === current_floor}
                      disabled={
                        !floor.occupied ||
                        !!floor.locked ||
                        floor.id === current_floor
                      }
                      tooltip={
                        floor.id === current_floor
                          ? 'You are here.'
                          : !floor.occupied
                            ? 'Nothing is docked at this berth.'
                            : floor.locked
                              ? 'Crew only.'
                              : undefined
                      }
                      onClick={() => act('goto', { id: floor.id })}
                    >
                      {`${floor.name}${floor.your_ship ? ' (your ship)' : ''}`}
                    </Button>
                  </Stack.Item>
                ))}
                {leased.length > 0 && <Stack.Divider />}
                {leased.map((floor) => (
                  <Stack.Item key={floor.id}>
                    <FloorRow
                      floor={floor}
                      here={floor.id === current_floor}
                      onGo={() => act('goto', { id: floor.id })}
                    />
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

type FloorRowProps = {
  floor: Floor;
  here: boolean;
  onGo: () => void;
};

// A leased floor: its colour, its name over its crew's, and whose it is
const FloorRow = (props: FloorRowProps) => {
  const { floor, here, onGo } = props;
  const mark = floor.mark ? MARKS[floor.mark] : undefined;
  return (
    <Button
      fluid
      py={0.5}
      color={floor.your_ship ? 'good' : 'default'}
      selected={here}
      disabled={here || !floor.occupied}
      tooltip={here ? 'You are here.' : undefined}
      onClick={onGo}
    >
      <Stack align="center" style={{ overflow: 'hidden' }}>
        <Stack.Item>
          <Box
            width="6px"
            height="32px"
            style={{
              backgroundColor: accentOf(floor),
              borderRadius: '2px',
              border: '1px solid rgba(0, 0, 0, 0.5)',
            }}
          />
        </Stack.Item>
        <Stack.Item grow basis={0} style={{ minWidth: 0 }}>
          <Box bold fontSize="14px" lineHeight="18px" style={ONE_LINE}>
            {cutLine(floor.name)}
          </Box>
          <Box
            fontSize="11px"
            lineHeight="14px"
            style={{ ...ONE_LINE, opacity: 0.8 }}
          >
            {cutLine(floor.crew) || ' '}
          </Box>
        </Stack.Item>
        {!!mark && (
          <Stack.Item bold fontSize="11px">
            {mark}
          </Stack.Item>
        )}
      </Stack>
    </Button>
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
