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
  locked: BooleanLike;
  password_cleared: BooleanLike;
  /** One of 'pending' | 'denied' | 'expired' | 'withdrawn', or null if never applied. */
  application_status: string | null;
  application_note: string | null;
  can_apply: BooleanLike;
};

type ShipJoinMenuData = {
  player_name: string;
  ships: ActiveShip[];
  can_requisition: BooleanLike;
  wiki_url: string | null;
  hardcore_enabled: BooleanLike;
  hardcore_available: BooleanLike;
  hardcore_reason: string | null;
};

export const ShipJoinMenu = () => {
  const { act, data } = useBackend<ShipJoinMenuData>();
  const {
    player_name,
    ships,
    can_requisition,
    wiki_url,
    hardcore_enabled,
    hardcore_available,
    hardcore_reason,
  } = data;

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

          {/* Hardcore Drop Section - hidden entirely when the server has it off */}
          {!!hardcore_enabled && (
            <Stack.Item>
              <HardcoreDropSection
                available={!!hardcore_available}
                reason={hardcore_reason}
              />
            </Stack.Item>
          )}

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

const HardcoreDropSection = (props: {
  available: boolean;
  reason: string | null;
}) => {
  const { act } = useBackend<ShipJoinMenuData>();
  const { available, reason } = props;

  return (
    <Section
      title={
        <Box inline>
          <Icon name="parachute-box" mr={1} />
          Hardcore Drop
        </Box>
      }
    >
      <Stack vertical>
        <Stack.Item>
          <Box color="gray" fontSize="13px" mb={1}>
            No ship, no crew, no pickup. You land alone on a random world in a
            pod with one crate of supplies and build from nothing. The only
            channel that reaches anyone is Wideband, and the only way off is
            somebody choosing to come and get you.
          </Box>
        </Stack.Item>
        <Stack.Item>
          <Button
            fluid
            icon="mountain-sun"
            color={available ? 'bad' : undefined}
            disabled={!available}
            fontSize="14px"
            textAlign="center"
            tooltip={
              available
                ? 'Drops you alone on a planet surface. There is no going back.'
                : (reason ?? 'Unavailable')
            }
            onClick={() => act('hardcore_drop')}
          >
            {available ? 'Drop Me Somewhere' : 'Unavailable'}
          </Button>
        </Stack.Item>
        {!available && !!reason && (
          <Stack.Item>
            <Box color="gray" fontSize="12px" mt={0.5}>
              {reason}
            </Box>
          </Stack.Item>
        )}
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
                {!!ship.locked && (
                  <Stack.Item ml={1.5}>
                    <Box
                      fontSize="12px"
                      color={ship.password_cleared ? 'lightgreen' : 'yellow'}
                    >
                      <Icon
                        name={ship.password_cleared ? 'unlock' : 'lock'}
                        mr={0.5}
                      />
                      {ship.password_cleared ? 'Cleared' : 'Password'}
                    </Box>
                  </Stack.Item>
                )}
              </Stack>
            </Stack.Item>

            {/* Where an application to this ship currently stands, if there is one. */}
            {!!ship.application_note && (
              <Stack.Item mt={0.5}>
                <Box
                  fontSize="11px"
                  color={
                    ship.application_status === 'pending' ? 'lightblue' : 'gray'
                  }
                >
                  <Icon
                    name={
                      ship.application_status === 'pending'
                        ? 'hourglass-half'
                        : 'circle-info'
                    }
                    mr={0.5}
                  />
                  {ship.application_note}
                </Box>
              </Stack.Item>
            )}

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

        {/* Join Button, plus the way past a lock for someone without the password */}
        <Stack.Item>
          <Stack vertical>
            <Stack.Item>
              <Button
                fluid
                icon="sign-in-alt"
                color="blue"
                disabled={totalSlots === 0}
                tooltip={
                  totalSlots === 0
                    ? 'No positions available'
                    : ship.locked && !ship.password_cleared
                      ? "Requires the crew's join password"
                      : 'Join crew'
                }
                onClick={() => act('select_ship', { ship_ref: ship.ref })}
              >
                Join
              </Button>
            </Stack.Item>
            {ship.application_status === 'pending' ? (
              <Stack.Item>
                <Button
                  fluid
                  icon="times"
                  color="bad"
                  tooltip="Take back your application"
                  onClick={() =>
                    act('withdraw_application', { ship_ref: ship.ref })
                  }
                >
                  Withdraw
                </Button>
              </Stack.Item>
            ) : (
              !!ship.can_apply && (
                <Stack.Item>
                  <Button
                    fluid
                    icon="envelope"
                    color="good"
                    tooltip="Ask the captain to let you aboard without the password"
                    onClick={() => act('apply_to_ship', { ship_ref: ship.ref })}
                  >
                    Apply
                  </Button>
                </Stack.Item>
              )
            )}
          </Stack>
        </Stack.Item>
      </Stack>
    </Box>
  );
};
