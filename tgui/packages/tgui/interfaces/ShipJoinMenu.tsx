import { Box, Button, Icon, Section, Stack } from 'tgui-core/components';

import { useBackend } from '../backend';
import { Window } from '../layouts';

type ActiveShip = {
  ref: string;
  name: string;
  class_name: string;
  crew_count: number;
  jobs: Array<{
    name: string;
    slots: number;
  }>;
  memo: string | null;
};

type ShipJoinMenuData = {
  player_name: string;
  ships: ActiveShip[];
};

export const ShipJoinMenu = () => {
  const { data } = useBackend<ShipJoinMenuData>();
  const { player_name, ships } = data;

  return (
    <Window title={`Welcome, ${player_name}`} width={500} height={450}>
      <Window.Content>
        <Stack vertical fill>
          {/* Purchase Ship Section */}
          <Stack.Item>
            <PurchaseShipSection />
          </Stack.Item>

          {/* Join Existing Ship Section */}
          <Stack.Item grow>
            <JoinShipSection ships={ships} />
          </Stack.Item>
        </Stack>
      </Window.Content>
    </Window>
  );
};

const PurchaseShipSection = () => {
  const { act } = useBackend<ShipJoinMenuData>();

  return (
    <Section
      title={
        <Box inline>
          <Icon name="rocket" mr={1} />
          Start Your Own Ship
        </Box>
      }
    >
      <Stack vertical>
        <Stack.Item>
          <Box color="gray" fontSize="13px" mb={1}>
            Purchase a ship from the catalog and become its captain. You&apos;ll
            be able to customize your crew and set your own course.
          </Box>
        </Stack.Item>
        <Stack.Item>
          <Button
            fluid
            icon="shopping-cart"
            color="green"
            fontSize="14px"
            textAlign="center"
            onClick={() => act('purchase_ship')}
          >
            Browse Ship Catalog
          </Button>
        </Stack.Item>
      </Stack>
    </Section>
  );
};

const JoinShipSection = (props: { ships: ActiveShip[] }) => {
  const { ships } = props;

  return (
    <Section
      fill
      scrollable
      title={
        <Box inline>
          <Icon name="users" mr={1} />
          Join Existing Crew
          <Box inline color="gray" ml={1} fontSize="12px">
            ({ships.length} {ships.length === 1 ? 'ship' : 'ships'} available)
          </Box>
        </Box>
      }
    >
      {ships.length === 0 ? (
        <Box textAlign="center" color="gray" fontSize="14px" mt={2}>
          <Icon name="ghost" size={2} mb={1} />
          <br />
          No ships are currently accepting crew.
          <br />
          Purchase your own ship above!
        </Box>
      ) : (
        <Stack vertical>
          {ships.map((ship) => (
            <Stack.Item key={ship.ref}>
              <ShipCard ship={ship} />
            </Stack.Item>
          ))}
        </Stack>
      )}
    </Section>
  );
};

const ShipCard = (props: { ship: ActiveShip }) => {
  const { act } = useBackend<ShipJoinMenuData>();
  const { ship } = props;

  // Calculate total available positions
  const totalSlots = ship.jobs.reduce((sum, job) => sum + job.slots, 0);

  // Format job slots for display (show top 3 jobs with slots)
  const jobsWithSlots = ship.jobs.filter((job) => job.slots > 0);
  const displayJobs = jobsWithSlots.slice(0, 3);
  const moreJobsCount = jobsWithSlots.length - 3;

  return (
    <Box
      style={{
        background: 'rgba(255, 255, 255, 0.05)',
        borderRadius: '4px',
        padding: '8px',
        marginBottom: '6px',
        borderLeft: '3px solid rgba(100, 200, 100, 0.7)',
      }}
    >
      <Stack>
        {/* Ship Info */}
        <Stack.Item grow>
          <Stack vertical>
            {/* Ship Name and Class */}
            <Stack.Item>
              <Box fontSize="15px" bold color="white">
                {ship.name}
              </Box>
              <Box fontSize="12px" color="gray" mt={0.5}>
                <Icon name="tag" mr={0.5} />
                {ship.class_name}
              </Box>
            </Stack.Item>

            {/* Crew Count and Open Slots */}
            <Stack.Item mt={0.5}>
              <Stack>
                <Stack.Item>
                  <Box fontSize="12px" color="lightblue">
                    <Icon name="users" mr={0.5} />
                    {ship.crew_count} aboard
                  </Box>
                </Stack.Item>
                <Stack.Item ml={1.5}>
                  <Box
                    fontSize="12px"
                    color={totalSlots > 0 ? 'lightgreen' : 'gray'}
                  >
                    <Icon name="door-open" mr={0.5} />
                    {totalSlots} {totalSlots === 1 ? 'position' : 'positions'}{' '}
                    open
                  </Box>
                </Stack.Item>
              </Stack>
            </Stack.Item>

            {/* Available Jobs */}
            {displayJobs.length > 0 && (
              <Stack.Item mt={0.5}>
                <Box fontSize="11px" color="gray">
                  <Icon name="briefcase" mr={0.5} />
                  {displayJobs.map((job, idx) => (
                    <span key={job.name}>
                      {job.name}
                      {job.slots > 1 && ` (${job.slots})`}
                      {idx < displayJobs.length - 1 && ', '}
                    </span>
                  ))}
                  {moreJobsCount > 0 && (
                    <span style={{ color: '#888' }}>
                      {' '}
                      +{moreJobsCount} more
                    </span>
                  )}
                </Box>
              </Stack.Item>
            )}
          </Stack>
        </Stack.Item>

        {/* Join Button */}
        <Stack.Item>
          <Button
            icon="sign-in-alt"
            color="blue"
            disabled={totalSlots === 0}
            tooltip={totalSlots === 0 ? 'No positions available' : 'Join crew'}
            onClick={() => act('select_ship', { ship_ref: ship.ref })}
          >
            Join
          </Button>
        </Stack.Item>
      </Stack>
    </Box>
  );
};
