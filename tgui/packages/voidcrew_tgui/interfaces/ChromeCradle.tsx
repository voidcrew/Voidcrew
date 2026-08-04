import {
  Box,
  Button,
  NoticeBox,
  ProgressBar,
  Section,
  Stack,
  Tooltip,
} from 'tgui-core/components';
import type { BooleanLike } from 'tgui-core/react';

import { useBackend } from '../backend';
import { Window } from '../layouts';

type InstalledWare = {
  ref: string;
  name: string;
  tier: number;
  load: number;
  capacity_bonus: number;
  failing: BooleanLike;
  emp_down: BooleanLike;
};

type CarriedWare = {
  ref: string;
  name: string;
  tier: number;
  load: number;
  capacity_bonus: number;
  fits: BooleanLike;
};

type TrayWare = {
  ref: string;
  name: string;
  tier: number;
  load: number;
  fits: BooleanLike;
};

type Data = {
  has_occupant: BooleanLike;
  occupant_name: string | null;
  occupant_is_user: BooleanLike;
  can_operate: BooleanLike;
  busy: BooleanLike;
  busy_action: string | null;
  busy_timeleft: number;
  busy_duration: number;
  loaded_credits: number;
  tuneup_fee: number;
  barred: BooleanLike;
  account_credits: number | null;
  load: number;
  capacity: number;
  brownout: BooleanLike;
  installed: InstalledWare[];
  tuneup_denial: string | null;
  carried: CarriedWare[];
  tray: TrayWare[];
};

// Mirrors the CYBERWARE_COLOR_TIER_* defines.
const TIER_COLORS: Record<number, string> = {
  1: '#ffb347',
  2: '#4dd8e6',
  3: '#ff2079',
  4: '#aaff3c',
};

const tierColor = (tier: number) => TIER_COLORS[tier] || TIER_COLORS[1];

const TierChip = (props: { tier: number }) => {
  const { tier } = props;
  return (
    <Box
      inline
      bold
      fontSize={0.75}
      px={0.5}
      style={{
        color: '#0a0a0f',
        backgroundColor: tierColor(tier),
        borderRadius: '2px',
        letterSpacing: '0.08em',
      }}
    >
      {`T${tier}`}
    </Box>
  );
};

const LoadBar = (props: {
  installed: InstalledWare[];
  load: number;
  capacity: number;
  brownout: BooleanLike;
}) => {
  const { installed, load, capacity, brownout } = props;
  const denominator = Math.max(capacity, load, 1);
  return (
    <Box>
      <Box
        style={{
          display: 'flex',
          height: '14px',
          border: '1px solid #3a3a4a',
          borderRadius: '2px',
          overflow: 'hidden',
          backgroundColor: '#12121a',
        }}
      >
        {installed
          .filter((ware) => ware.load > 0)
          .map((ware) => (
            <Tooltip
              key={ware.ref}
              content={`${ware.name} — load ${ware.load}`}
            >
              <Box
                style={{
                  width: `${(ware.load / denominator) * 100}%`,
                  backgroundColor: brownout ? '#802020' : tierColor(ware.tier),
                  borderRight: '1px solid #0a0a0f',
                  height: '100%',
                }}
              />
            </Tooltip>
          ))}
      </Box>
      <Stack mt={0.5} align="center">
        <Stack.Item grow>
          <Box color={brownout ? 'bad' : 'label'} fontSize={0.9}>
            Neural load{' '}
            <Box inline bold color={brownout ? 'bad' : 'good'}>
              {load}
            </Box>
            {' / '}
            <Box inline bold>
              {capacity}
            </Box>
          </Box>
        </Stack.Item>
        {!!brownout && (
          <Stack.Item>
            <Box inline bold color="bad">
              CHROME BROWNOUT
            </Box>
          </Stack.Item>
        )}
      </Stack>
    </Box>
  );
};

const WareStats = (props: { load: number; capacity_bonus: number }) => {
  const { load, capacity_bonus } = props;
  return (
    <Box inline color="label" fontSize={0.85}>
      {`load ${load}`}
      {capacity_bonus > 0 && (
        <Box inline color="good">
          {` · +${capacity_bonus} cap`}
        </Box>
      )}
    </Box>
  );
};

export const ChromeCradle = (props) => {
  const { act, data } = useBackend<Data>();
  const {
    has_occupant,
    occupant_name,
    occupant_is_user,
    can_operate,
    busy,
    busy_action,
    busy_timeleft,
    busy_duration,
    loaded_credits,
    tuneup_fee,
    barred,
    account_credits,
    load,
    capacity,
    brownout,
    installed,
    tuneup_denial,
    carried,
    tray,
  } = data;

  // Only the occupant, conscious and unrestrained, may order work on their
  // own body. Everyone else watches and can pop the tray.
  const may_operate = !!occupant_is_user && !!can_operate && !busy && !barred;
  const progress =
    busy_duration > 0 ? (busy_duration - busy_timeleft) / busy_duration : 0;

  return (
    <Window title="Chrome Cradle" width={460} height={640}>
      <Window.Content scrollable>
        {!!barred && (
          <NoticeBox danger>
            Trade embargo. The rig will not work on you.
          </NoticeBox>
        )}
        {!has_occupant && (
          <NoticeBox info>
            The slab is empty. Drag yourself onto it to lie back.
          </NoticeBox>
        )}
        {!!has_occupant && !occupant_is_user && (
          <NoticeBox>
            {occupant_name} is on the slab. The rig takes orders from its
            occupant only — you can eject the parts tray.
          </NoticeBox>
        )}
        {!!has_occupant && !!occupant_is_user && !can_operate && !busy && (
          <NoticeBox danger>
            The rig refuses: you have to be conscious and unrestrained to
            consent to chrome work.
          </NoticeBox>
        )}
        {!!has_occupant && (
          <Section title={`Patient — ${occupant_name}`}>
            <LoadBar
              installed={installed}
              load={load}
              capacity={capacity}
              brownout={brownout}
            />
          </Section>
        )}
        {!!busy && (
          <Section title="Rig Working">
            <ProgressBar
              value={progress}
              minValue={0}
              maxValue={1}
              color="average"
            >
              {busy_action === 'install' ? 'Installing…' : 'Removing…'}
            </ProgressBar>
            <Box mt={0.5} color="label" fontSize={0.85}>
              Hold still. Leaving the slab cancels the cycle — nothing is
              lost, the ware goes to the tray.
            </Box>
          </Section>
        )}
        {!!has_occupant && (
          <Section
            title="Installed Chrome"
            buttons={
              <Button
                icon="wrench"
                disabled={!may_operate || !!tuneup_denial}
                tooltip={
                  tuneup_denial ||
                  `Clears EMP scramble and repairs all installed chrome. ${tuneup_fee} cr.`
                }
                onClick={() => act('tuneup')}
              >
                {`Tune-up (${tuneup_fee} cr)`}
              </Button>
            }
          >
            {installed.length === 0 && (
              <Box color="label">Nothing but meat in there.</Box>
            )}
            {installed.map((ware) => (
              <Stack key={ware.ref} align="center" mb={0.5}>
                <Stack.Item>
                  <TierChip tier={ware.tier} />
                </Stack.Item>
                <Stack.Item grow>
                  <Box inline bold>
                    {ware.name}
                  </Box>{' '}
                  <WareStats
                    load={ware.load}
                    capacity_bonus={ware.capacity_bonus}
                  />
                  {!!ware.failing && (
                    <Box inline bold color="bad" ml={0.5}>
                      {ware.emp_down ? 'EMP SCRAMBLED' : 'FAILING'}
                    </Box>
                  )}
                </Stack.Item>
                <Stack.Item>
                  <Button
                    icon="hand-holding-medical"
                    color="bad"
                    disabled={!may_operate}
                    tooltip="3-second extraction. The ware comes back out intact."
                    onClick={() => act('remove', { ref: ware.ref })}
                  >
                    Remove
                  </Button>
                </Stack.Item>
              </Stack>
            ))}
          </Section>
        )}
        {!!has_occupant && (
          <Section title="Carried Chrome">
            {carried.length === 0 && (
              <Box color="label">
                Nothing installable on you. Chrome in your hands, pockets or
                bag shows up here.
              </Box>
            )}
            {carried.map((ware) => (
              <Stack key={ware.ref} align="center" mb={0.5}>
                <Stack.Item>
                  <TierChip tier={ware.tier} />
                </Stack.Item>
                <Stack.Item grow>
                  <Box inline bold>
                    {ware.name}
                  </Box>{' '}
                  <WareStats
                    load={ware.load}
                    capacity_bonus={ware.capacity_bonus}
                  />
                </Stack.Item>
                <Stack.Item>
                  <Button
                    icon="syringe"
                    color="good"
                    disabled={!may_operate || !ware.fits}
                    tooltip={
                      ware.fits
                        ? '4-second install. You will be briefly sedated.'
                        : 'No neural headroom — shed load or find a Governor.'
                    }
                    onClick={() => act('install', { ref: ware.ref })}
                  >
                    Install
                  </Button>
                </Stack.Item>
              </Stack>
            ))}
          </Section>
        )}
        {tray.length > 0 && (
          <Section
            title="Parts Tray"
            buttons={
              <Button
                icon="inbox"
                tooltip="Anyone can pop the tray — evicted chrome is never held hostage."
                onClick={() => act('eject_tray')}
              >
                Eject Tray
              </Button>
            }
          >
            {tray.map((ware) => (
              <Stack key={ware.ref} align="center" mb={0.5}>
                <Stack.Item>
                  <TierChip tier={ware.tier} />
                </Stack.Item>
                <Stack.Item grow>
                  <Box inline bold>
                    {ware.name}
                  </Box>{' '}
                  <Box inline color="label" fontSize={0.85}>
                    {`load ${ware.load}`}
                  </Box>
                </Stack.Item>
                <Stack.Item>
                  <Button
                    icon="syringe"
                    disabled={!may_operate || !ware.fits}
                    tooltip={
                      ware.fits
                        ? 'Install straight from the tray.'
                        : 'Will not fit the current occupant.'
                    }
                    onClick={() => act('install', { ref: ware.ref })}
                  >
                    Install
                  </Button>
                </Stack.Item>
              </Stack>
            ))}
          </Section>
        )}
        <Section title="Slab">
          <Stack align="center">
            <Stack.Item grow>
              <Box color="label" fontSize={0.9}>
                Loaded cash:{' '}
                <Box inline bold color="gold">
                  {loaded_credits} cr
                </Box>
                {account_credits !== null && (
                  <Box inline>
                    {' · ID account: '}
                    <Box inline bold color="gold">
                      {account_credits} cr
                    </Box>
                  </Box>
                )}
              </Box>
            </Stack.Item>
            {loaded_credits > 0 && (
              <Stack.Item>
                <Button
                  icon="money-bill-wave"
                  disabled={!!busy}
                  onClick={() => act('eject_cash')}
                >
                  Eject Cash
                </Button>
              </Stack.Item>
            )}
            {!!has_occupant && (
              <Stack.Item>
                <Button
                  icon="person-walking-arrow-right"
                  tooltip="Gets the patient off the slab. Cancels any running cycle — the ware goes to the tray."
                  onClick={() => act('get_up')}
                >
                  {occupant_is_user ? 'Get Up' : 'Unbuckle Patient'}
                </Button>
              </Stack.Item>
            )}
          </Stack>
        </Section>
      </Window.Content>
    </Window>
  );
};
