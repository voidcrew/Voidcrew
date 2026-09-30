import type { ReactNode } from 'react';
import { Button, Icon } from 'tgui-core/components';
import { formatMoney } from 'tgui-core/format';
import type { BooleanLike } from 'tgui-core/react';
import { useBackend } from '../backend';
import { Window } from '../layouts';

type PrisonerStatus =
  | 'present'
  | 'arriving'
  | 'leaving'
  | 'dead'
  | 'confined'
  | 'rioting'
  | 'loose'
  | 'subject';

/** Priority, highest first: breakout, escape, riot, riot_imminent, hatch_empty */
type PrisonAlarm =
  | 'riot'
  | 'escape'
  | 'breakout'
  | 'riot_imminent'
  | 'hatch_empty';

type IntakeState = 'open' | 'closed' | 'suspended' | 'debt' | 'no_power';

type PrisonStage = 'calm' | 'grumbling' | 'restless' | 'riot';

type Prisoner = {
  ref: string;
  name: string;
  /** 1 to capacity */
  cell: number;
  crime: string;
  /** seconds */
  sentence_left: number;
  status: PrisonerStatus;
  /** brought in on a bounty (outpost_prison_bounty.dm); null for an ordinary prisoner */
  bounty?: BountyBadge | null;
};

/** A bounty prisoner's roster line */
type BountyBadge = {
  /** "wanted for smuggling" */
  wanted_for?: string | null;
  most_wanted?: BooleanLike;
};

type BountyIntakeSetting = 'all' | 'no_most_wanted' | 'none';

/** Bounty transfers into the wing (outpost_prison_bounty.dm); null on an older payload */
type BountyIntake = {
  setting?: BountyIntakeSetting;
  can_manage?: BooleanLike;
  /** the next arrival, once it is a bounty prisoner */
  next?: {
    name?: string;
    most_wanted?: BooleanLike;
    /** seconds until they beam in */
    in?: number | null;
  } | null;
};

type GuardStatus =
  | 'arriving'
  | 'post'
  | 'rounds'
  | 'routine'
  | 'responding'
  | 'riot'
  | 'down'
  | 'away';

type Guard = {
  ref: string;
  name: string;
  rank: string;
  status: GuardStatus;
};

type Guards = {
  max: number;
  hire_cost: number;
  /** cr/min per guard */
  wage: number;
  can_manage: BooleanLike;
  /** a manager, a free post, and the fee in the treasury */
  can_hire: BooleanLike;
  list: Guard[];
};

/** Guards (outpost_prison_extras.dm); null on an unlinked console */
type Extras = {
  guards?: Guards | null;
};

type ExperimentForm = 'unknown' | 'hulk' | 'fly' | 'nightmare' | 'changeling';

type ExperimentStage =
  | 'offered'
  | 'dosed'
  | 'twitching'
  | 'incubating'
  | 'live'
  | 'vents'
  | 'horror'
  | 'contained'
  | 'failed';

type Experiment = {
  /** "unknown" for a blind serum until the creature shows */
  form: ExperimentForm;
  stage: ExperimentStage;
  subject: string | null;
  /** a creature that was put down lies waiting for Kessler to collect it */
  pickup?: BooleanLike;
};

export type OutpostPrisonData = {
  linked: BooleanLike;
  powered: BooleanLike;
  /** the wing's APC is running down its cell */
  on_battery?: BooleanLike;
  intake_open: BooleanLike;
  /** seconds, null when nothing is scheduled */
  next_arrival: number | null;
  capacity: number;
  can_manage: BooleanLike;
  prisoners: Prisoner[];
  log: { time: string; text: string }[];
  /** null when nothing is wrong */
  alarm?: PrisonAlarm | null;
  alarm_text?: string;
  // Everything below may be missing from an older payload; its part of the console is then hidden.
  intake_state?: IntakeState;
  /** treasury debt, 0 when none */
  debt?: number;
  /** missing means the console leaves it to the server */
  can_pay_debt?: BooleanLike;
  visitors_allowed?: BooleanLike;
  /** the yard's mood in a word */
  trouble?: { stage: PrisonStage } | null;
  extras?: Extras | null;
  /** null with no experiment */
  experiment?: Experiment | null;
  /** bounty transfers: the warden's setting and the next bounty arrival */
  bounty?: BountyIntake | null;
};

type Act = (action: string, params?: Record<string, unknown>) => unknown;
type Props = { data: OutpostPrisonData; act: Act };
type Tone = 'good' | 'average' | 'bad';

/** Present prisoners get no badge. */
const STATUSES: Partial<
  Record<PrisonerStatus, { label: string; icon: string; tone: Tone }>
> = {
  arriving: { label: 'Arriving', icon: 'right-to-bracket', tone: 'good' },
  leaving: { label: 'Leaving', icon: 'right-from-bracket', tone: 'average' },
  dead: { label: 'Dead', icon: 'skull', tone: 'bad' },
  confined: { label: 'Locked in', icon: 'lock', tone: 'average' },
  rioting: { label: 'Rioting', icon: 'hand-fist', tone: 'bad' },
  loose: { label: 'Loose', icon: 'person-running', tone: 'bad' },
  subject: { label: 'Subject', icon: 'flask', tone: 'average' },
};

/** Red alarms pulse. */
const ALARMS: Record<
  PrisonAlarm,
  { label: string; icon: string; tone: 'red' | 'amber' }
> = {
  riot: { label: 'Riot', icon: 'hand-fist', tone: 'red' },
  escape: { label: 'Escape', icon: 'person-running', tone: 'amber' },
  breakout: { label: 'Breakout', icon: 'burst', tone: 'red' },
  riot_imminent: { label: 'Riot brewing', icon: 'people-group', tone: 'red' },
  hatch_empty: { label: 'Hatch empty', icon: 'utensils', tone: 'amber' },
};

/** What the line beside the intake switch says when nobody is coming; open and closed have their own. */
const INTAKE_LINES: Partial<Record<IntakeState, { text: string; tone: Tone }>> =
  {
    suspended: { text: 'Suspended', tone: 'bad' },
    debt: { text: 'On hold: debt', tone: 'bad' },
    no_power: { text: 'On hold: no power', tone: 'bad' },
  };

const YARD: Record<PrisonStage, { label: string; color: string }> = {
  calm: { label: 'Calm', color: 'good' },
  grumbling: { label: 'Grumbling', color: 'average' },
  restless: { label: 'Restless', color: 'orange' },
  riot: { label: 'Riot', color: 'bad' },
};

/** What each guard is doing. */
const GUARD_STATUSES: Record<
  GuardStatus,
  { label: string; icon: string; tone?: Tone }
> = {
  arriving: { label: 'Arriving', icon: 'right-to-bracket', tone: 'good' },
  post: { label: 'On post', icon: 'user-shield' },
  rounds: { label: 'On rounds', icon: 'person-walking' },
  routine: { label: 'On duty', icon: 'user-shield' },
  responding: {
    label: 'Responding',
    icon: 'person-running',
    tone: 'average',
  },
  riot: { label: 'Holding the door', icon: 'shield-halved', tone: 'bad' },
  down: { label: 'Injured', icon: 'user-injured', tone: 'bad' },
  away: { label: 'Off duty', icon: 'right-from-bracket', tone: 'average' },
};

/** A blind serum reads Serum until its creature shows. */
const EXPERIMENT_FORMS: Record<ExperimentForm, string> = {
  unknown: 'Serum',
  hulk: 'Hulk',
  fly: 'Fly person',
  nightmare: 'Nightmare',
  changeling: 'Specimen',
};

const EXPERIMENT_STAGES: Record<
  ExperimentStage,
  { label: string; tone: string }
> = {
  offered: { label: 'Offered', tone: 'average' },
  dosed: { label: 'Dosed', tone: 'average' },
  twitching: { label: 'Twitching', tone: 'average' },
  incubating: { label: 'Incubating', tone: 'average' },
  live: { label: 'Loose', tone: 'bad' },
  vents: { label: 'In vents', tone: 'bad' },
  horror: { label: 'Horror', tone: 'bad' },
  contained: { label: 'Contained', tone: 'good' },
  failed: { label: 'Failed', tone: 'label' },
};

/** The warden's bounty transfer settings, in button order */
const BOUNTY_SETTINGS: [BountyIntakeSetting, string][] = [
  ['all', 'All'],
  ['no_most_wanted', 'No Most Wanted'],
  ['none', 'None'],
];

/** m:ss */
function clock(seconds: number) {
  const total = Math.max(0, Math.ceil(seconds || 0));
  return `${Math.floor(total / 60)}:${String(total % 60).padStart(2, '0')}`;
}

/** Credits per minute, to one decimal place when it has one. */
function rate(value: number) {
  return `${Math.round((value || 0) * 10) / 10}`;
}

function credits(value: number | null | undefined) {
  return formatMoney(Math.floor(value || 0));
}

function isNumber(value: unknown): value is number {
  return typeof value === 'number' && Number.isFinite(value);
}

/** A block the server sent as an object; anything else hides its part. */
function block<T>(value: T | null | undefined): T | null {
  return value && typeof value === 'object' && !Array.isArray(value)
    ? value
    : null;
}

function Empty({ icon, children }: { icon: string; children: ReactNode }) {
  return (
    <div className="Outpost__empty">
      <Icon name={icon} />
      <span>{children}</span>
    </div>
  );
}

/** The head: the yard's mood in a word, and the wing's power as a panel would show it */
function Head({ data }: { data: OutpostPrisonData }) {
  const linked = !!data.linked;
  const trouble = block(data.trouble);
  const yard = trouble ? YARD[trouble.stage] : null;
  return (
    <div className="OutpostPrison__head">
      <Icon name="handcuffs" />
      <strong>Prison</strong>
      <span className="OutpostPrison__head-status">
        {linked && yard ? (
          <span className={`OutpostPrison__stage--${yard.color}`}>
            {`Yard: ${yard.label}`}
          </span>
        ) : null}
        {linked && !data.powered ? (
          <span className="OutpostPrison__alert" role="alert">
            <Icon name="plug-circle-xmark" />
            No power
          </span>
        ) : linked && data.on_battery ? (
          <span className="OutpostPrison__tone--average">
            <Icon name="car-battery" />
            On battery
          </span>
        ) : null}
      </span>
    </div>
  );
}

function Alarm({ data }: { data: OutpostPrisonData }) {
  if (!data.alarm) {
    return null;
  }
  const known = ALARMS[data.alarm] || {
    label: data.alarm,
    icon: 'triangle-exclamation',
    tone: 'red',
  };
  return (
    <div
      className={`OutpostPrison__alarm OutpostPrison__alarm--${known.tone}`}
      role="alert"
    >
      <Icon name={known.icon} />
      <strong>{data.alarm_text || known.label}</strong>
    </div>
  );
}

/** Beside the intake switch: the next transfer when open (naming a bounty prisoner), or why nobody is coming. */
function intakeLine(
  data: OutpostPrisonData,
): { text: string; tone?: Tone } | null {
  const state = data.intake_state;
  if (state && state !== 'open' && state !== 'closed') {
    return INTAKE_LINES[state] || { text: state, tone: 'average' };
  }
  if (!data.intake_open) {
    return null;
  }
  if (isNumber(data.next_arrival)) {
    const next = block(block(data.bounty)?.next);
    const mostWanted = !!next?.most_wanted;
    const who = next?.name
      ? `: ${next.name}${mostWanted ? ', Most Wanted' : ''}`
      : '';
    return {
      text: `Next transfer ${clock(data.next_arrival)}${who}`,
      tone: mostWanted ? 'bad' : undefined,
    };
  }
  return (data.prisoners || []).length >= data.capacity
    ? { text: 'Full' }
    : null;
}

/** Intake, visitors and the debt: the warden's switches */
function Controls({ data, act }: Props) {
  const open = !!data.intake_open;
  // Intake can be closed while the treasury owes, but not opened.
  const held = data.intake_state === 'debt' && !open;
  const line = intakeLine(data);
  const hasVisitors =
    data.visitors_allowed !== undefined && data.visitors_allowed !== null;
  const visitors = !!data.visitors_allowed;
  const debt = isNumber(data.debt) && data.debt > 0 ? data.debt : 0;
  // Debt is paid by managers and treasurers; without a hint the server decides.
  const canPay =
    data.can_pay_debt === undefined ||
    data.can_pay_debt === null ||
    !!data.can_pay_debt;
  return (
    <>
      <div className="OutpostPrison__control-row">
        <Button
          icon={open ? 'door-open' : 'door-closed'}
          selected={open}
          disabled={!data.can_manage || held}
          tooltip={
            !data.can_manage
              ? 'Managers only'
              : held
                ? 'Debt unpaid'
                : undefined
          }
          onClick={() => act('toggle_intake')}
        >
          {open ? 'Intake: Open' : 'Intake: Closed'}
        </Button>
        {line ? (
          <span
            className={`OutpostPrison__intake-line${
              line.tone ? ` OutpostPrison__tone--${line.tone}` : ''
            }`}
          >
            {line.text}
          </span>
        ) : null}
      </div>
      {hasVisitors || debt > 0 ? (
        <div className="OutpostPrison__control-row">
          {hasVisitors ? (
            <Button
              icon={visitors ? 'people-arrows' : 'user-lock'}
              selected={visitors}
              disabled={!data.can_manage}
              tooltip={data.can_manage ? undefined : 'Managers only'}
              onClick={() => act('toggle_visitors')}
            >
              {visitors ? 'Visitors: Yes' : 'Visitors: No'}
            </Button>
          ) : null}
          {debt > 0 ? (
            <span className="OutpostPrison__debt">
              Debt <b>{`${credits(debt)} cr`}</b>
              <Button
                icon="hand-holding-dollar"
                disabled={!canPay}
                tooltip={canPay ? undefined : 'Managers and treasurers only'}
                onClick={() => act('pay_debt')}
              >
                Pay debt
              </Button>
            </span>
          ) : null}
        </div>
      ) : null}
    </>
  );
}

/** Which bounty prisoners the wing takes */
function BountyTransfers({ data, act }: Props) {
  const bounty = block(data.bounty);
  if (!bounty) {
    return null;
  }
  const setting = bounty.setting || 'all';
  const canManage = !!bounty.can_manage;
  return (
    <div className="OutpostPrison__control-row">
      <span className="OutpostPrison__control-label">Bounty prisoners</span>
      {BOUNTY_SETTINGS.map(([value, label]) => (
        <Button
          key={value}
          compact
          selected={setting === value}
          disabled={!canManage}
          tooltip={canManage ? undefined : 'Managers only'}
          onClick={() => act('set_bounty_intake', { setting: value })}
        >
          {label}
        </Button>
      ))}
    </div>
  );
}

/** The researcher's experiment in one line: who, what, and how it stands */
function ExperimentLine({ data }: { data: OutpostPrisonData }) {
  const experiment = block(data.experiment);
  if (!experiment) {
    return null;
  }
  const form = EXPERIMENT_FORMS[experiment.form] || 'Serum';
  const stage = experiment.pickup
    ? { label: 'Awaiting pickup', tone: 'good' }
    : EXPERIMENT_STAGES[experiment.stage] || {
        label: experiment.stage || '?',
        tone: 'label',
      };
  return (
    <div className="OutpostPrison__control-row">
      <span className="OutpostPrison__control-label">Experiment</span>
      <span className="OutpostPrison__experiment-what">
        {experiment.subject ? `${experiment.subject} · ${form}` : form}
      </span>
      <span
        className={`OutpostPrison__experiment-stage OutpostPrison__tone--${stage.tone}`}
      >
        {stage.label}
      </span>
    </div>
  );
}

function GuardRow({
  guard,
  canDismiss,
  act,
}: {
  guard: Guard;
  canDismiss: boolean;
  act: Act;
}) {
  const known = GUARD_STATUSES[guard.status] || {
    label: guard.status || '?',
    icon: 'circle-question',
    tone: 'average' as Tone,
  };
  // The rank is shown unless the name already starts with it ("Officer Hale").
  const rank = guard.rank || '';
  const showRank =
    rank !== '' &&
    !(guard.name || '').toLowerCase().startsWith(rank.toLowerCase());
  return (
    <div className="OutpostPrison__staff-row">
      <div className="Outpost__person">
        <strong>{guard.name}</strong>
        {showRank ? <small>{rank}</small> : null}
      </div>
      <span
        className={`OutpostPrison__status${
          known.tone ? ` OutpostPrison__tone--${known.tone}` : ''
        }`}
      >
        <Icon name={known.icon} />
        {known.label}
      </span>
      {canDismiss ? (
        <Button.Confirm
          icon="user-minus"
          confirmContent="Dismiss?"
          onClick={() => act('guard_dismiss', { ref: guard.ref })}
        >
          Dismiss
        </Button.Confirm>
      ) : (
        <span />
      )}
    </div>
  );
}

function GuardsSection({ data, act }: Props) {
  const guards = block(block(data.extras)?.guards);
  if (!guards) {
    return null;
  }
  const list = (guards.list || []).filter(Boolean);
  const max = guards.max || 0;
  const manager = !!guards.can_manage;
  const hireBlocked = !manager
    ? 'Managers only'
    : max > 0 && list.length >= max
      ? 'No free post'
      : 'Treasury short';
  return (
    <>
      <div className="Outpost__section-label">
        Guards
        {max > 0 ? <span>{`${list.length}/${max}`}</span> : null}
      </div>
      {list.length === 0 ? (
        <div className="Outpost__quiet">None</div>
      ) : (
        list.map((guard) => (
          <GuardRow
            key={guard.ref}
            guard={guard}
            canDismiss={manager}
            act={act}
          />
        ))
      )}
      <div className="OutpostPrison__staff-foot">
        <small>{`Wage ${rate(guards.wage)} cr/min each`}</small>
        <Button
          icon="user-plus"
          disabled={!guards.can_hire}
          tooltip={guards.can_hire ? undefined : hireBlocked}
          onClick={() => act('guard_hire')}
        >
          {`Hire (${credits(guards.hire_cost)} cr)`}
        </Button>
      </div>
    </>
  );
}

function Status({ status }: { status: PrisonerStatus }) {
  if (status === 'present') {
    return <span />;
  }
  const known = STATUSES[status] || {
    label: status,
    icon: 'circle-question',
    tone: 'average',
  };
  return (
    <span
      className={`OutpostPrison__status OutpostPrison__tone--${known.tone}`}
    >
      <Icon name={known.icon} />
      {known.label}
    </span>
  );
}

function RosterRow({ prisoner, cell }: { prisoner: Prisoner; cell: string }) {
  const dead = prisoner.status === 'dead';
  const bounty = block(prisoner.bounty);
  return (
    <div
      className={`OutpostPrison__roster-row${
        dead ? ' OutpostPrison__roster-row--dead' : ''
      }`}
    >
      <span className="OutpostPrison__cell">{cell}</span>
      <div className="Outpost__person">
        <strong>{prisoner.name}</strong>
        <small>
          {bounty?.wanted_for || prisoner.crime}
          {bounty?.most_wanted ? (
            <span className="OutpostPrison__tone--bad">
              {' · '}
              <Icon name="star" /> Most Wanted
            </span>
          ) : null}
        </small>
      </div>
      <span className="OutpostPrison__number">
        {dead ? '-' : clock(prisoner.sentence_left)}
      </span>
      <Status status={prisoner.status} />
    </div>
  );
}

function Roster({ data }: { data: OutpostPrisonData }) {
  const prisoners = data.prisoners || [];
  // One row per cell. A prisoner past the last cell still gets a row; one
  // with no cell is listed after the cells.
  const cellCount = Math.max(
    data.capacity > 0 ? data.capacity : 4,
    ...prisoners.map((prisoner) => prisoner.cell || 0),
  );
  const cells = Array.from({ length: cellCount }, (_, index) => index + 1);
  const unassigned = prisoners.filter((prisoner) => !(prisoner.cell > 0));
  return (
    <>
      <div className="Outpost__section-label">Cells</div>
      {cells.map((cell) => {
        const occupants = prisoners.filter(
          (prisoner) => prisoner.cell === cell,
        );
        if (occupants.length === 0) {
          return (
            <div
              className="OutpostPrison__roster-row OutpostPrison__roster-row--empty"
              key={`empty-${cell}`}
            >
              <span className="OutpostPrison__cell">{cell}</span>
              <span className="OutpostPrison__vacant">Empty</span>
              <span />
              <span />
            </div>
          );
        }
        return occupants.map((prisoner) => (
          <RosterRow key={prisoner.ref} prisoner={prisoner} cell={`${cell}`} />
        ));
      })}
      {unassigned.map((prisoner) => (
        <RosterRow key={prisoner.ref} prisoner={prisoner} cell="-" />
      ))}
    </>
  );
}

function Log({ data }: { data: OutpostPrisonData }) {
  const log = data.log || [];
  return (
    <>
      <div className="Outpost__section-label">Log</div>
      {log.length === 0 ? (
        <div className="Outpost__quiet">None</div>
      ) : (
        <div className="OutpostPrison__log">
          {log.map((entry, index) => (
            <div key={index}>
              <span>{entry.time}</span>
              {entry.text}
            </div>
          ))}
        </div>
      )}
    </>
  );
}

export function OutpostPrisonPanel({ data, act }: Props) {
  return (
    <div className="Outpost OutpostPrison">
      <Head data={data} />
      {data.linked ? <Alarm data={data} /> : null}
      {data.linked ? (
        <div className="OutpostPrison__body">
          <div className="OutpostPrison__controls">
            <Controls data={data} act={act} />
            <BountyTransfers data={data} act={act} />
            <ExperimentLine data={data} />
          </div>
          <Roster data={data} />
          <GuardsSection data={data} act={act} />
          <Log data={data} />
        </div>
      ) : (
        <Empty icon="link-slash">No prison link</Empty>
      )}
    </div>
  );
}

export const OutpostPrison = () => {
  const { data, act } = useBackend<OutpostPrisonData>();
  return (
    <Window title="Prison Warden" width={480} height={540}>
      <Window.Content fitted>
        <OutpostPrisonPanel data={data} act={act} />
      </Window.Content>
    </Window>
  );
};
