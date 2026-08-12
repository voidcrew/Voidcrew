import { Box, Button, Icon, Section, Stack } from 'tgui-core/components';
import type { BooleanLike } from 'tgui-core/react';

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
  can_requisition: BooleanLike;
  wiki_url: string | null;
};

export const ShipJoinMenu = () => {
  const { act, data } = useBackend<ShipJoinMenuData>();
  const { player_name, ships, can_requisition, wiki_url } = data;

  return (
    <Window
      title={`Welcome, ${player_name}`}
      width={500}
      height={520}
      buttons={
        <Button
          icon="book"
          disabled={!wiki_url}
          tooltip={wiki_url ? 'Open the wiki in your browser' : undefined}
          onClick={() => act('open_wiki')}
        >
          Wiki
        </Button>
      }
    >
      <Window.Content>
        <Stack vertical fill>
          {/* Purchase Ship Section */}
          <Stack.Item>
            <PurchaseShipSection />
          </Stack.Item>

          {/* Free Hull Section */}
          <Stack.Item>
            <RequisitionSection canRequisition={!!can_requisition} />
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
            Buy a ship and become its captain. You&apos;ll pick its hull, theme
            and upgrade modules in the shipyard, then set your own course.
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
            Open Shipyard
          </Button>
        </Stack.Item>
      </Stack>
    </Section>
  );
};

const RequisitionSection = (props: { canRequisition: boolean }) => {
  const { act } = useBackend<ShipJoinMenuData>();
  const { canRequisition } = props;

  return (
    <Section
      title={
        <Box inline>
          <Icon name="life-ring" mr={1} />
          Requisition a Hull
        </Box>
      }
    >
      <Stack vertical>
        <Stack.Item>
          <Box color="gray" fontSize="13px" mb={1}>
            {canRequisition
              ? 'No ship in the fleet has a position open for you, so the yard will issue you one at no cost. The class, theme and fittings are whatever is on the line. Buy from the shipyard if you want to choose.'
              : 'Available only when the fleet has no room left. There are still open positions below, join one of those.'}
          </Box>
        </Stack.Item>
        <Stack.Item>
          <Button
            fluid
            icon="wrench"
            color={canRequisition ? 'good' : undefined}
            disabled={!canRequisition}
            fontSize="14px"
            textAlign="center"
            tooltip={
              canRequisition
                ? 'Spawns a free ship and makes you its officer'
                : 'The fleet still has open positions'
            }
            onClick={() => act('requisition_hull')}
          >
            {canRequisition ? 'Requisition a Hull (Free)' : 'Fleet Has Room'}
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
          Requisition a free hull above, or buy your own.
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
