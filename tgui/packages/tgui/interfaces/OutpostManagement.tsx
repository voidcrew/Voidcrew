/**
 * Outpost management console.
 *
 * A slim header (name, owner, treasury), a tab bar, and each tab owns the
 * whole window below it, split into framed columns. Styles live in
 * styles/interfaces/OutpostManagement.scss.
 */
import {
  type ReactNode,
  type PointerEvent as ReactPointerEvent,
  useEffect,
  useLayoutEffect,
  useMemo,
  useRef,
  useState,
} from 'react';
import {
  Button,
  Dropdown,
  Icon,
  Input,
  KeyListener,
  NumberInput,
  TextArea,
} from 'tgui-core/components';
import type { KeyEvent } from 'tgui-core/events';
import { formatMoney } from 'tgui-core/format';
import { acquireHotKey, releaseHotKey } from 'tgui-core/hotkeys';
import { KEY_DOWN, KEY_LEFT, KEY_RIGHT, KEY_UP } from 'tgui-core/keycodes';
import type { BooleanLike } from 'tgui-core/react';
import { HelmPlane } from '../../voidcrew_tgui/interfaces/Helm/HelmPlane';
import { resolveAsset } from '../assets';
import { useBackend } from '../backend';
import { Window } from '../layouts';

// ===== Data =====

type Vessel = { ref: string; name: string };
type Candidate = Vessel & {
  ckey: string;
  is_resident?: BooleanLike;
};
type Resident = Vessel & {
  is_self: BooleanLike;
  active: BooleanLike;
  steward: BooleanLike;
  treasurer: BooleanLike;
  pricer?: BooleanLike;
};
type ResearchState = 'connected' | 'pending' | 'none';
/** One ship settled at the outpost (ships_ui_data()). */
type ShipHere = Vessel & {
  /** "Bay 1", "Berth 2", "Pad 1" */
  berth: string;
  /** People on its crew */
  crew: number;
  /** Always "none" for someone who does not manage the outpost */
  research: ResearchState | string;
  research_ref: string | null;
  /** Ship bay rows only: materials and eviction exist for the bay alone. */
  bay_ref?: string | null;
  materials?: 'allowed' | 'requested' | 'none' | string | null;
  evict_denial?: string | null;
  evicting?: BooleanLike;
  /** Seconds until the ship is sent off. */
  evict_eta?: number;
};
/** A research link whose ship is not listed in ships_here (it left, or is still docking). */
type ResearchAway = {
  ref: string;
  ship: string | null;
  research: ResearchState | string;
};
type PriceRow = {
  key: string;
  label: string;
  value: number;
  max: number;
  /** Whether the room this price belongs to is built */
  available: BooleanLike;
};
type LedgerEntry = {
  time: string;
  label: string;
  /** Who paid, or whose account was refunded */
  who: string | null;
  amount: number;
};
type ServiceTotal = { service: string; label: string; total: number };
type Pricing = {
  prices?: PriceRow[];
  ledger?: LedgerEntry[] | null;
  totals?: ServiceTotal[] | null;
  /** Credits taken in the last hour, refunds off; null without income access */
  last_hour?: number | null;
};
type ShopDetail = {
  kind: 'shop';
  open?: BooleanLike;
  can_toggle?: BooleanLike;
};
type NetworkPad = { id: string; name: string };
type TeleporterDetail = {
  kind: 'teleporter';
  padName?: string;
  arrivals?: string;
  allowlist?: NetworkPad[];
  candidates?: NetworkPad[];
  can_edit?: BooleanLike;
};
type ServiceRoom = {
  id: string;
  name: string;
  detail?: { kind?: string; [key: string]: unknown } | null;
};
type UpgradeEntry = {
  id: string;
  name: string;
  desc: string;
  price: number;
  width: number;
  height: number;
  preview: string | null;
  /** Joins another room's wall at a joint instead of being placed freely */
  snap?: BooleanLike;
};
/** A joint a snap upgrade may join, as the server judged it */
type UpgradeSnap = {
  /** The footprint's bottom-left, in world tiles */
  x: number;
  y: number;
  rotation: number;
  side: string;
  /** Why it can't be built there now, or null */
  reason: string | null;
  blocked: [number, number][];
  openings: [number, number][];
};
type UpgradeStatus = {
  id: string;
  state: 'available' | 'ready' | 'installed';
  denial: string | null;
  manage_denial: string | null;
};
/** One character per tile, rows from the bottom-left corner (see build_upgrade_survey()). */
type UpgradeSurvey = {
  x: number;
  y: number;
  z: number;
  width: number;
  height: number;
  cells: string;
  near: string;
};
export type OutpostData = {
  linked: BooleanLike;
  outpost_name: string;
  founder_name: string | null;
  memo: string;
  is_owner: BooleanLike;
  has_owner: BooleanLike;
  can_claim: BooleanLike;
  can_manage: BooleanLike;
  can_spend: BooleanLike;
  can_set_prices: BooleanLike;
  /** Treasury user: picks the service silo. */
  can_select_silo?: BooleanLike;
  can_view_income?: BooleanLike;
  /** This user is billed as a visitor (admin testing aid). */
  playtest_visitor?: BooleanLike;
  pricing?: Pricing | null;
  services?: ServiceRoom[] | null;
  /** Ship names whose crews count as members. */
  owner_crews?: (string | Vessel)[] | null;
  treasury_balance: number;
  service_silo: string | null;
  service_silos: Vessel[];
  dock_mode: string;
  rename_cooldown: number;
  advert_cost: number;
  advert_cooldown: number;
  advert_remaining: number;
  advert_denial: string | null;
  dock_requests: Vessel[];
  approved_ships: Vessel[];
  banned_ships: Vessel[];
  ships_here?: ShipHere[] | null;
  research_away?: ResearchAway[] | null;
  builders: string[];
  candidates: Candidate[];
  resident_mode: string;
  arrival_available: BooleanLike;
  residents: Resident[];
  resident_invites: Record<string, BooleanLike>;
  resident_blocked: string[];
  research_servers: Vessel[];
  ship_bay_installed: BooleanLike;
  ship_bay_cost: number;
  ship_bay_denial: string | null;
  ship_bay_preview?: string | null;
  ship_bay_width?: number;
  ship_bay_height?: number;
  upgrade_catalog: UpgradeEntry[];
  upgrades: UpgradeStatus[];
  upgrade_surveying: BooleanLike;
  upgrade_survey?: UpgradeSurvey | null;
  /** Joints the placing snap upgrade may join, while its placement map is open */
  upgrade_snaps?: UpgradeSnap[] | null;
};
type Act = (action: string, params?: Record<string, unknown>) => unknown;
type Props = { data: OutpostData; act: Act };

// ===== Small parts =====

function Frame({
  title,
  icon,
  extra,
  foot,
  fill,
  flush,
  bodyClassName = '',
  children,
}: {
  title: ReactNode;
  icon: string;
  extra?: ReactNode;
  foot?: ReactNode;
  fill?: boolean;
  flush?: boolean;
  bodyClassName?: string;
  children?: ReactNode;
}) {
  return (
    <section className={`Outpost__frame ${fill ? 'Outpost__frame--fill' : ''}`}>
      <div className="Outpost__frame-head">
        <Icon name={icon} />
        <span>{title}</span>
        {extra !== undefined && extra !== null ? (
          <span className="Outpost__frame-extra">{extra}</span>
        ) : null}
      </div>
      <div
        className={`Outpost__frame-body ${flush ? 'Outpost__frame-body--flush' : ''} ${bodyClassName}`}
      >
        {children}
      </div>
      {foot ? <div className="Outpost__frame-foot">{foot}</div> : null}
    </section>
  );
}

function Section({ title, count }: { title: string; count?: number }) {
  return (
    <div className="Outpost__section">
      {title}
      {count !== undefined ? (
        <span className="Outpost__section-count">{count}</span>
      ) : null}
    </div>
  );
}

function None({ children }: { children: ReactNode }) {
  return <div className="Outpost__none">{children}</div>;
}

type Choice = { id: string; name: string; icon?: string };

/** A row of mutually exclusive buttons. Picking the current choice does nothing. */
function Segmented({
  choices,
  value,
  disabled,
  inline,
  onPick,
}: {
  choices: Choice[];
  value: string;
  disabled?: boolean;
  inline?: boolean;
  onPick: (id: string) => void;
}) {
  return (
    <div
      className={`Outpost__segment ${inline ? 'Outpost__segment--inline' : ''}`}
    >
      {choices.map((choice) => (
        <Button
          key={choice.id}
          icon={choice.icon}
          selected={value === choice.id}
          disabled={disabled}
          onClick={() => {
            if (value !== choice.id) {
              onPick(choice.id);
            }
          }}
        >
          {choice.name}
        </Button>
      ))}
    </div>
  );
}

function credits(amount: number) {
  return `${formatMoney(Number(amount) || 0)} cr`;
}

/** Whole seconds as m:ss. */
function clock(seconds?: number | null) {
  const total = Math.max(0, Math.ceil(Number(seconds) || 0));
  return `${Math.floor(total / 60)}:${String(total % 60).padStart(2, '0')}`;
}

/** Silo choice belongs to treasury users; older servers only sent can_set_prices. */
function canSelectSilo(data: OutpostData) {
  return data.can_select_silo === undefined
    ? !!data.can_set_prices
    : !!data.can_select_silo;
}

// ===== Ships =====

const DOCK_MODES: Choice[] = [
  { id: 'open', name: 'Open', icon: 'door-open' },
  { id: 'request', name: 'Request', icon: 'hand' },
  { id: 'lockdown', name: 'Lockdown', icon: 'lock' },
];

function DockingFrame({ data, act }: Props) {
  const requests = data.dock_requests || [];
  const cleared = data.approved_ships || [];
  const blocked = data.banned_ships || [];
  const manage = !!data.can_manage;
  const block = (ship: Vessel) => (
    <Button
      icon="ban"
      tooltip="Block"
      disabled={!manage}
      onClick={() => act('ban_ship', { ref: ship.ref })}
    />
  );
  return (
    <Frame title="Docking" icon="tower-observation" fill>
      <Segmented
        choices={DOCK_MODES}
        value={data.dock_mode}
        disabled={!manage}
        onPick={(mode) => act('set_dock_mode', { mode })}
      />
      <Section title="Requests" count={requests.length} />
      {requests.length === 0 ? <None>No requests</None> : null}
      {requests.map((ship) => (
        <div className="Outpost__row" key={ship.ref}>
          <Icon name="shuttle-space" />
          <span className="Outpost__name">{ship.name}</span>
          <Button
            icon="check"
            color="good"
            disabled={!manage}
            onClick={() => act('approve_request', { ref: ship.ref })}
          >
            Clear
          </Button>
          <Button
            disabled={!manage}
            onClick={() => act('deny_request', { ref: ship.ref })}
          >
            Deny
          </Button>
          {block(ship)}
        </div>
      ))}
      <Section title="Cleared" count={cleared.length} />
      {cleared.length === 0 ? <None>None</None> : null}
      {cleared.map((ship) => (
        <div className="Outpost__row" key={ship.ref}>
          <Icon name="shuttle-space" />
          <span className="Outpost__name">{ship.name}</span>
          <Button
            disabled={!manage}
            onClick={() => act('revoke_approval', { ref: ship.ref })}
          >
            Revoke
          </Button>
          {block(ship)}
        </div>
      ))}
      <Section title="Blocked" count={blocked.length} />
      {blocked.length === 0 ? <None>None</None> : null}
      {blocked.map((ship) => (
        <div className="Outpost__row" key={ship.ref}>
          <Icon name="ban" />
          <span className="Outpost__name">{ship.name}</span>
          <Button
            icon="unlock"
            disabled={!manage}
            onClick={() => act('unban_ship', { ref: ship.ref })}
          >
            Unblock
          </Button>
        </div>
      ))}
    </Frame>
  );
}

/** R&D cell of a ship row: connect, pending with cancel, or disconnect. */
function ShipResearch({
  ship,
  server,
  data,
  act,
}: Props & { ship: ShipHere; server: Vessel | undefined }) {
  const manage = !!data.can_manage;
  if (!manage) {
    return <span className="Outpost__dash">-</span>;
  }
  const link = ship.research_ref;
  if (ship.research === 'connected') {
    return (
      <Button
        icon="link-slash"
        disabled={!link}
        onClick={() => link && act('revoke_research', { ref: link })}
      >
        Disconnect
      </Button>
    );
  }
  if (ship.research === 'pending') {
    return (
      <>
        <span className="Outpost__state">Pending</span>
        <Button
          icon="xmark"
          tooltip="Cancel"
          disabled={!link}
          onClick={() => link && act('revoke_research', { ref: link })}
        />
      </>
    );
  }
  return (
    <Button
      icon="link"
      disabled={!server}
      tooltip={server ? undefined : 'No R&D server'}
      onClick={() =>
        server && act('invite_research', { ship: ship.ref, server: server.ref })
      }
    >
      Connect
    </Button>
  );
}

function ShipRow({
  ship,
  server,
  data,
  act,
}: Props & { ship: ShipHere; server: Vessel | undefined }) {
  const manage = !!data.can_manage;
  const materials = !!data.can_spend && manage;
  const bay = ship.bay_ref;
  const evicting = !!bay && !!ship.evicting;
  return (
    <div
      className={`Outpost__ship ${evicting ? 'Outpost__ship--leaving' : ''}`}
    >
      <div>
        <div className="Outpost__ship-name">{ship.name}</div>
        <div className="Outpost__ship-sub">
          {ship.berth} · {ship.crew} crew
        </div>
      </div>
      <div className="Outpost__slot">
        <ShipResearch ship={ship} server={server} data={data} act={act} />
      </div>
      <div className="Outpost__slot">
        {bay && ship.materials === 'requested' ? (
          <>
            <Button
              color="good"
              disabled={!materials}
              onClick={() => act('approve_bay_silo', { ref: bay })}
            >
              Allow
            </Button>
            <Button
              disabled={!materials}
              onClick={() => act('revoke_bay_silo', { ref: bay })}
            >
              Deny
            </Button>
          </>
        ) : bay && ship.materials === 'allowed' ? (
          <Button
            disabled={!materials}
            onClick={() => act('revoke_bay_silo', { ref: bay })}
          >
            Revoke
          </Button>
        ) : (
          <span className="Outpost__dash">-</span>
        )}
      </div>
      <div className="Outpost__slot Outpost__slot--end">
        {!bay ? null : evicting ? (
          <>
            <span className="Outpost__countdown">
              <Icon name="stopwatch" /> {clock(ship.evict_eta)}
            </span>
            <Button
              icon="xmark"
              tooltip="Cancel"
              disabled={!manage}
              onClick={() => act('cancel_bay_eviction', { ref: bay })}
            />
          </>
        ) : (
          <Button.Confirm
            color="bad"
            disabled={!manage || !!ship.evict_denial}
            tooltip={ship.evict_denial || undefined}
            onClick={() => act('evict_bay_ship', { ref: bay })}
          >
            Evict
          </Button.Confirm>
        )}
      </div>
    </div>
  );
}

/** Research links whose ship is not at the outpost: they stay live until cut. */
function ResearchAwayRows({
  links,
  data,
  act,
}: Props & { links: ResearchAway[] }) {
  if (links.length === 0) {
    return null;
  }
  return (
    <>
      <Section title="R&D away" count={links.length} />
      {links.map((link) => (
        <div className="Outpost__row" key={link.ref}>
          <Icon name="shuttle-space" />
          <span className="Outpost__name">{link.ship || 'Unknown ship'}</span>
          {link.research === 'connected' ? (
            <Button
              icon="link-slash"
              disabled={!data.can_manage}
              onClick={() => act('revoke_research', { ref: link.ref })}
            >
              Disconnect
            </Button>
          ) : (
            <>
              <span className="Outpost__state">Pending</span>
              <Button
                icon="xmark"
                tooltip="Cancel"
                disabled={!data.can_manage}
                onClick={() => act('revoke_research', { ref: link.ref })}
              />
            </>
          )}
        </div>
      ))}
    </>
  );
}

function HarbourFrame({ data, act }: Props) {
  const ships = data.ships_here || [];
  const away = data.research_away || [];
  const silos = data.service_silos || [];
  const servers = data.research_servers || [];
  const [serverRef, setServerRef] = useState('');
  const server =
    servers.find((candidate) => candidate.ref === serverRef) || servers[0];
  const foot = (
    <>
      {silos.length > 1 ? (
        <div className="Outpost__field-row">
          <span className="Outpost__label">Silo</span>
          <Dropdown
            width="100%"
            disabled={!canSelectSilo(data)}
            selected={data.service_silo || ''}
            displayText={
              silos.find((silo) => silo.ref === data.service_silo)?.name ||
              'No silo'
            }
            options={silos.map((silo) => ({
              value: silo.ref,
              displayText: silo.name,
            }))}
            placeholder="No silo"
            onSelected={(ref) => act('select_service_silo', { ref })}
          />
        </div>
      ) : null}
      {servers.length > 1 ? (
        <div className="Outpost__field-row">
          <span className="Outpost__label">R&amp;D</span>
          <Dropdown
            width="100%"
            disabled={!data.can_manage}
            selected={server?.ref || ''}
            displayText={server?.name || 'No server'}
            options={servers.map((candidate) => ({
              value: candidate.ref,
              displayText: candidate.name,
            }))}
            onSelected={setServerRef}
          />
        </div>
      ) : null}
    </>
  );
  const hasFoot = silos.length > 1 || servers.length > 1;
  return (
    <Frame
      title="At the outpost"
      icon="anchor"
      extra={ships.length}
      fill
      foot={hasFoot ? foot : undefined}
    >
      {ships.length === 0 ? (
        <None>No ships docked</None>
      ) : (
        <>
          <div className="Outpost__ships-head">
            <span>Ship</span>
            <span>R&amp;D</span>
            <span>Materials</span>
            <span />
          </div>
          {ships.map((ship) => (
            <ShipRow
              key={ship.ref}
              ship={ship}
              server={server}
              data={data}
              act={act}
            />
          ))}
        </>
      )}
      <ResearchAwayRows links={away} data={data} act={act} />
    </Frame>
  );
}

function ShipsTab({ data, act }: Props) {
  return (
    <div className="Outpost__page Outpost__page--ships">
      <div className="Outpost__col">
        <DockingFrame data={data} act={act} />
      </div>
      <div className="Outpost__col">
        <HarbourFrame data={data} act={act} />
      </div>
    </div>
  );
}

// ===== People =====

const ROLES = [
  { id: 'steward', name: 'Steward' },
  { id: 'treasurer', name: 'Treasurer' },
  { id: 'pricer', name: 'Pricer' },
] as const;

function ResidentsFrame({ data, act }: Props) {
  const residents = data.residents || [];
  const candidates = data.candidates || [];
  const builders = data.builders || [];
  const crews = (data.owner_crews || [])
    .map((crew) => (typeof crew === 'string' ? crew : crew?.name))
    .filter(Boolean);
  return (
    <Frame title="Residents" icon="users" extra={residents.length} fill>
      {residents.length === 0 ? <None>No residents</None> : null}
      {residents.map((person) => (
        <div className="Outpost__row" key={person.ref}>
          <span
            className={`Outpost__dot ${person.active ? 'Outpost__dot--online' : ''}`}
          />
          <span className="Outpost__name">{person.name}</span>
          {data.is_owner && person.is_self ? (
            <span className="Outpost__tag">Owner</span>
          ) : null}
          {!!data.is_owner && !person.is_self ? (
            <div className="Outpost__chips">
              {ROLES.map((role) => (
                <Button
                  key={role.id}
                  selected={!!person[role.id]}
                  onClick={() =>
                    act('delegate', { ref: person.ref, role: role.id })
                  }
                >
                  {role.name}
                </Button>
              ))}
            </div>
          ) : null}
          {person.is_self ? null : (
            <Button
              icon="user-minus"
              tooltip="Remove"
              disabled={!data.can_manage}
              onClick={() => act('remove_resident', { ref: person.ref })}
            />
          )}
        </div>
      ))}
      <Section title="On site" count={candidates.length} />
      {candidates.length === 0 ? <None>Nobody nearby</None> : null}
      {candidates.map((person) => {
        const builder = builders.includes(person.ckey);
        return (
          <div className="Outpost__row" key={person.ref}>
            <Icon name="user" />
            <span className="Outpost__name">{person.name}</span>
            {person.is_resident ? (
              <span className="Outpost__tag">Resident</span>
            ) : (
              <Button
                icon="user-plus"
                disabled={!data.can_manage}
                onClick={() => act('add_resident', { ref: person.ref })}
              >
                Add
              </Button>
            )}
            {data.is_owner ? (
              <Button
                icon="hammer"
                selected={builder}
                onClick={() =>
                  act(builder ? 'remove_builder' : 'add_builder', {
                    ref: person.ref,
                    ckey: person.ckey,
                  })
                }
              >
                Builder
              </Button>
            ) : null}
          </div>
        );
      })}
      <Section title="Builders" count={builders.length} />
      {builders.length === 0 ? <None>None</None> : null}
      {builders.map((key) => (
        <div className="Outpost__row" key={key}>
          <Icon name="hammer" />
          <span className="Outpost__plain Outpost__mono">{key}</span>
          <Button
            icon="xmark"
            tooltip="Remove"
            disabled={!data.is_owner}
            onClick={() => act('remove_builder', { ckey: key })}
          />
        </div>
      ))}
      {crews.length > 0 ? (
        <>
          <Section title="Owner's crews" count={crews.length} />
          {crews.map((crew) => (
            <div className="Outpost__row" key={crew}>
              <Icon name="shuttle-space" />
              <span className="Outpost__plain">{crew}</span>
            </div>
          ))}
        </>
      ) : null}
    </Frame>
  );
}

const ARRIVAL_MODES: Choice[] = [
  { id: 'open', name: 'Open' },
  { id: 'password', name: 'Password' },
  { id: 'approved', name: 'Invite' },
  { id: 'closed', name: 'Closed' },
];

function ArrivalsFrame({ data, act }: Props) {
  const [account, setAccount] = useState('');
  const [password, setPassword] = useState('');
  const manage = !!data.can_manage;
  const invites = Object.keys(data.resident_invites || {});
  const blocked = data.resident_blocked || [];
  const submit = (action: string) => {
    act(action, { ckey: account.trim() });
    setAccount('');
  };
  return (
    <Frame
      title="Arrivals"
      icon="id-card"
      fill
      foot={
        <div className="Outpost__field-row">
          <span className="Outpost__grow" />
          <Button.Confirm
            icon="rotate-left"
            color="bad"
            disabled={!manage}
            onClick={() => act('reset_resident_access')}
          >
            Reset access
          </Button.Confirm>
        </div>
      }
    >
      <Segmented
        choices={ARRIVAL_MODES}
        value={data.resident_mode}
        disabled={!manage}
        onPick={(mode) => act('resident_mode', { mode })}
      />
      {data.resident_mode === 'password' ? (
        <div className="Outpost__field-row Outpost__field-row--password">
          <input
            className="Input Input--fluid"
            type="password"
            placeholder="New password"
            value={password}
            onChange={(event) => setPassword(event.currentTarget.value)}
            autoComplete="new-password"
            maxLength={64}
            disabled={!manage}
          />
          <Button
            icon="key"
            disabled={!manage || !password.trim()}
            onClick={() => {
              act('resident_password', { password });
              setPassword('');
            }}
          >
            Set
          </Button>
        </div>
      ) : null}
      {data.arrival_available ? null : (
        <div className="Outpost__alert">
          <Icon name="bed" />
          No free cryopod
        </div>
      )}
      <label className="Outpost__field-label">Account</label>
      <div className="Outpost__field-row">
        <Input
          fluid
          placeholder="Account name"
          value={account}
          onChange={setAccount}
          disabled={!manage}
        />
        <Button
          icon="user-check"
          disabled={!manage || !account.trim()}
          onClick={() => submit('invite_resident')}
        >
          Invite
        </Button>
        <Button
          icon="user-slash"
          disabled={!manage || !account.trim()}
          onClick={() => submit('block_resident')}
        >
          Block
        </Button>
      </div>
      <Section title="Invited" count={invites.length} />
      {invites.length === 0 ? <None>None</None> : null}
      {invites.map((key) => (
        <div className="Outpost__row" key={key}>
          <Icon name="envelope" />
          <span className="Outpost__plain Outpost__mono">{key}</span>
        </div>
      ))}
      <Section title="Blocked" count={blocked.length} />
      {blocked.length === 0 ? <None>None</None> : null}
      {blocked.map((key) => (
        <div className="Outpost__row" key={key}>
          <Icon name="user-slash" />
          <span className="Outpost__plain Outpost__mono">{key}</span>
          <Button
            icon="unlock"
            disabled={!manage}
            onClick={() => act('unblock_resident', { ckey: key })}
          >
            Unblock
          </Button>
        </div>
      ))}
    </Frame>
  );
}

function PeopleTab({ data, act }: Props) {
  return (
    <div className="Outpost__page Outpost__page--wide-left">
      <div className="Outpost__col">
        <ResidentsFrame data={data} act={act} />
      </div>
      <div className="Outpost__col">
        <ArrivalsFrame data={data} act={act} />
      </div>
    </div>
  );
}

// ===== Rooms =====

/** Built rooms that carry settings (the server's `services` rows). */
function serviceRooms(data: OutpostData): ServiceRoom[] {
  return (data.services || []).filter((room) => !!room?.id);
}

/** The ship bay is sold in the rooms list, though the server keeps it apart from the rooms. */
const SHIP_BAY_ID = '_ship_bay';

function shipBayEntry(data: OutpostData): UpgradeEntry {
  return {
    id: SHIP_BAY_ID,
    name: 'Ship Bay',
    desc: 'A private hangar for one ship, with a bar and workshops along the back wall.',
    price: data.ship_bay_cost,
    width: data.ship_bay_width || 0,
    height: data.ship_bay_height || 0,
    preview: data.ship_bay_preview || null,
  };
}

function shipBayStatus(data: OutpostData): UpgradeStatus {
  return {
    id: SHIP_BAY_ID,
    state: data.ship_bay_installed ? 'installed' : 'available',
    denial: data.ship_bay_denial,
    manage_denial: null,
  };
}

const SHOP_STATES: Choice[] = [
  { id: 'open', name: 'Open' },
  { id: 'closed', name: 'Closed' },
];
const TELEPORTER_ARRIVALS: Choice[] = [
  { id: 'open', name: 'Open' },
  { id: 'members', name: 'Members' },
  { id: 'allowlist', name: 'Allow list' },
  { id: 'closed', name: 'Closed' },
];

function TeleporterSettings({
  detail,
  canManage,
  serviceAct,
}: {
  detail: TeleporterDetail;
  canManage: boolean;
  serviceAct: (action: string, params?: Record<string, unknown>) => void;
}) {
  const [pick, setPick] = useState('');
  const canEdit = detail.can_edit === undefined ? canManage : !!detail.can_edit;
  const arrivals = detail.arrivals || 'open';
  const allowlist = detail.allowlist || [];
  const listed = new Set(allowlist.map((pad) => pad.id));
  const candidates = (detail.candidates || []).filter(
    (pad) => !listed.has(pad.id),
  );
  const chosen = candidates.find((pad) => pad.id === pick);
  return (
    <div className="Outpost__room-sub">
      <div className="Outpost__field-row">
        <span className="Outpost__label">Arrivals</span>
        <Segmented
          inline
          choices={TELEPORTER_ARRIVALS}
          value={arrivals}
          disabled={!canEdit}
          onPick={(mode) => serviceAct('set_teleporter_arrivals', { mode })}
        />
      </div>
      {arrivals === 'allowlist' ? (
        <>
          {allowlist.map((pad) => (
            <div className="Outpost__row" key={pad.id}>
              <Icon name="circle-nodes" />
              <span className="Outpost__plain">{pad.name}</span>
              <Button
                icon="xmark"
                tooltip="Remove"
                disabled={!canEdit}
                onClick={() =>
                  serviceAct('teleporter_disallow', { target: pad.id })
                }
              />
            </div>
          ))}
          <div className="Outpost__field-row Outpost__field-row--follow">
            <Dropdown
              width="100%"
              placeholder="Outpost pad"
              selected={chosen?.id || ''}
              displayText={chosen?.name || 'Outpost pad'}
              options={candidates.map((pad) => ({
                displayText: pad.name,
                value: pad.id,
              }))}
              onSelected={setPick}
              disabled={!canEdit || candidates.length === 0}
            />
            <Button
              icon="plus"
              disabled={!canEdit || !chosen}
              onClick={() => {
                if (!chosen) {
                  return;
                }
                serviceAct('teleporter_allow', { target: chosen.id });
                setPick('');
              }}
            >
              Allow
            </Button>
          </div>
        </>
      ) : null}
    </div>
  );
}

function RoomRow({
  entry,
  status,
  room,
  selected,
  onSelect,
  data,
  act,
}: Props & {
  entry: UpgradeEntry;
  status: UpgradeStatus | undefined;
  room: ServiceRoom | undefined;
  selected: boolean;
  onSelect: (id: string) => void;
}) {
  const state = status?.state || 'available';
  const serviceAct = (
    service_action: string,
    params: Record<string, unknown> = {},
  ) => act('service_act', { ...params, id: room?.id, service_action });
  const kind = room?.detail?.kind;
  const shop = kind === 'shop' ? (room?.detail as ShopDetail) : null;
  return (
    <>
      <div
        className={`Outpost__room ${selected ? 'Outpost__room--selected' : ''}`}
        onClick={() => onSelect(entry.id)}
      >
        <span className="Outpost__name">{entry.name}</span>
        <div className="Outpost__slot Outpost__slot--end">
          {state === 'available' ? (
            <span className="Outpost__price">
              {entry.price > 0 ? credits(entry.price) : 'Free'}
            </span>
          ) : null}
          {shop ? (
            <Segmented
              inline
              choices={SHOP_STATES}
              value={shop.open ? 'open' : 'closed'}
              disabled={!shop.can_toggle}
              onPick={() => serviceAct('toggle_open')}
            />
          ) : null}
        </div>
      </div>
      {state === 'installed' && kind === 'teleporter' && room?.detail ? (
        <TeleporterSettings
          detail={room.detail as TeleporterDetail}
          canManage={!!data.can_manage}
          serviceAct={serviceAct}
        />
      ) : null}
    </>
  );
}

function RoomDetail({
  entry,
  status,
  act,
  onPlace,
}: {
  entry: UpgradeEntry;
  status: UpgradeStatus | undefined;
  act: Act;
  onPlace: (id: string) => void;
}) {
  const state = status?.state || 'available';
  const bay = entry.id === SHIP_BAY_ID;
  const foot = (
    <div className="Outpost__buy">
      {state === 'available' ? (
        <>
          <span className="Outpost__price">
            {entry.price > 0 ? credits(entry.price) : 'Free'}
            {bay ? ' · 100 iron · 50 glass' : null}
          </span>
          <Button.Confirm
            icon="cart-shopping"
            disabled={!status || !!status.denial}
            tooltip={status?.denial || undefined}
            onClick={() =>
              bay
                ? act('install_ship_bay')
                : act('buy_upgrade', { id: entry.id })
            }
          >
            Buy
          </Button.Confirm>
        </>
      ) : state === 'ready' ? (
        <>
          <span className="Outpost__price Outpost__muted">Paid</span>
          <Button
            icon="map-location-dot"
            disabled={!!status?.manage_denial}
            tooltip={status?.manage_denial || undefined}
            onClick={() => onPlace(entry.id)}
          >
            Place
          </Button>
          <Button.Confirm
            icon="rotate-left"
            color="bad"
            disabled={!!status?.manage_denial}
            tooltip={status?.manage_denial || undefined}
            onClick={() => act('cancel_upgrade', { id: entry.id })}
          >
            Cancel purchase
          </Button.Confirm>
        </>
      ) : (
        <span className="Outpost__price Outpost__muted">Built</span>
      )}
    </div>
  );
  return (
    <Frame
      title={entry.name}
      icon="cube"
      extra={`${entry.width} x ${entry.height}`}
      fill
      flush
      foot={foot}
    >
      <div className="Outpost__preview">
        <UpgradePreview name={entry.preview} />
      </div>
      <div className="Outpost__desc">{entry.desc}</div>
    </Frame>
  );
}

function RoomsTab({
  data,
  act,
  onPlace,
}: Props & { onPlace: (id: string) => void }) {
  const catalog = [...(data.upgrade_catalog || []), shipBayEntry(data)];
  const rooms = serviceRooms(data);
  const [chosen, setChosen] = useState<string | null>(null);
  const statusOf = (id: string) =>
    id === SHIP_BAY_ID
      ? shipBayStatus(data)
      : (data.upgrades || []).find((entry) => entry.id === id);
  const stateOf = (id: string) => statusOf(id)?.state || 'available';
  const groups = [
    { title: 'Built', state: 'installed' },
    { title: 'Ready to place', state: 'ready' },
    { title: 'For sale', state: 'available' },
  ].map((group) => ({
    ...group,
    entries: catalog.filter((entry) => stateOf(entry.id) === group.state),
  }));
  const fallback =
    catalog.find((entry) => stateOf(entry.id) === 'ready') ||
    catalog.find((entry) => stateOf(entry.id) === 'available') ||
    catalog[0];
  const current = catalog.find((entry) => entry.id === chosen) || fallback;
  return (
    <div className="Outpost__page Outpost__page--wide-left">
      <div className="Outpost__col">
        <Frame title="Rooms" icon="cubes" fill>
          {groups.map((group) =>
            group.entries.length === 0 ? null : (
              <div key={group.state}>
                <Section title={group.title} count={group.entries.length} />
                {group.entries.map((entry) => (
                  <RoomRow
                    key={entry.id}
                    entry={entry}
                    status={statusOf(entry.id)}
                    room={rooms.find((room) => room.id === entry.id)}
                    selected={entry.id === current.id}
                    onSelect={setChosen}
                    data={data}
                    act={act}
                  />
                ))}
              </div>
            ),
          )}
        </Frame>
      </div>
      <div className="Outpost__col">
        <RoomDetail
          entry={current}
          status={statusOf(current.id)}
          act={act}
          onPlace={onPlace}
        />
      </div>
    </div>
  );
}

// ===== Room preview =====

function usePreviewImage(name: string | null) {
  const [image, setImage] = useState<HTMLImageElement | null>(null);
  useEffect(() => {
    setImage(null);
    if (!name) {
      return;
    }
    let live = true;
    const loading = new Image();
    loading.onload = () => {
      if (live) {
        setImage(loading);
      }
    };
    loading.src = resolveAsset(name);
    return () => {
      live = false;
    };
  }, [name]);
  return image;
}

/** A room's preview picture that zooms and pans, sized from the picture itself. */
function UpgradePreview({ name }: { name: string | null }) {
  const image = usePreviewImage(name);
  if (!name) {
    return <None>No preview</None>;
  }
  if (!image) {
    return null;
  }
  return (
    <HelmPlane
      key={name}
      mapWidth={image.naturalWidth}
      mapHeight={image.naturalHeight}
      maxScale={3}
      background={
        <img
          src={resolveAsset(name)}
          style={{
            position: 'absolute',
            left: 0,
            top: 0,
            width: '100%',
            height: '100%',
            imageRendering: 'pixelated',
          }}
        />
      }
    />
  );
}

// ===== Placement map =====

/** Opening pixels per tile. The canvas shows 36 x 28 tiles at this zoom. */
const MAP_TILE = 16;
const MAP_WIDTH = 36 * MAP_TILE;
const MAP_HEIGHT = 28 * MAP_TILE;
/** Pixels per tile the wheel steps through. */
const ZOOM_STEPS = [4, 6, 8, 12, 16, 24];
/** Wheel travel per zoom step. A mouse notch is about 100; touchpads send many small deltas. */
const WHEEL_STEP = 60;
/** Survey cells an upgrade may cover: space, lattice, floor. */
const OPEN_CELLS = 'slf';
const CELL_COLORS: Record<string, string> = {
  s: '#07090b',
  l: '#27313b',
  f: '#474d54',
  w: '#9ca0a5',
  g: '#4f9fc4',
  d: '#d3a24c',
  m: '#8b5c34',
  x: '#5e2323',
};
const PAN_KEYS: Record<number, [number, number]> = {
  [KEY_LEFT]: [-1, 0],
  [KEY_RIGHT]: [1, 0],
  [KEY_UP]: [0, 1],
  [KEY_DOWN]: [0, -1],
};

type Tile = { x: number; y: number };
type Footprint = {
  origin: Tile;
  width: number;
  height: number;
  blocked: Tile[];
  reason: string | null;
};

/** Index of a world tile in the survey strings, or -1 outside the surveyed region. */
function surveyIndex(survey: UpgradeSurvey, x: number, y: number) {
  const column = x - survey.x;
  const row = y - survey.y;
  if (column < 0 || row < 0 || column >= survey.width || row >= survey.height) {
    return -1;
  }
  return row * survey.width + column;
}

/** The same rule the server applies: every tile open, one tile near outpost ground. */
function checkFootprint(
  survey: UpgradeSurvey,
  origin: Tile,
  width: number,
  height: number,
): Footprint {
  const blocked: Tile[] = [];
  let outside = false;
  let near = false;
  for (let dx = 0; dx < width; dx++) {
    for (let dy = 0; dy < height; dy++) {
      const tile = { x: origin.x + dx, y: origin.y + dy };
      const index = surveyIndex(survey, tile.x, tile.y);
      if (index < 0) {
        outside = true;
        blocked.push(tile);
        continue;
      }
      if (!OPEN_CELLS.includes(survey.cells[index])) {
        blocked.push(tile);
      }
      if (survey.near[index] === '1') {
        near = true;
      }
    }
  }
  const reason = outside
    ? 'Too far from the outpost'
    : blocked.length > 0
      ? 'Blocked'
      : !near
        ? 'Too far from the outpost'
        : null;
  return { origin, width, height, blocked, reason };
}

/** Tiles from the server's [x, y] pairs. */
function pairTiles(pairs: [number, number][] | undefined): Tile[] {
  return (pairs || []).map(([x, y]) => ({ x, y }));
}

/** A joint's offer as a footprint. The server has already judged it. */
function snapFootprint(snap: UpgradeSnap, upgrade: UpgradeEntry): Footprint {
  const turned = snap.rotation === 90 || snap.rotation === 270;
  return {
    origin: { x: snap.x, y: snap.y },
    width: turned ? upgrade.height : upgrade.width,
    height: turned ? upgrade.width : upgrade.height,
    blocked: pairTiles(snap.blocked),
    reason: snap.reason,
  };
}

/** Tiles from a tile to a footprint's rectangle, 0 inside it. */
function footprintDistance(footprint: Footprint, tile: Tile) {
  const right = footprint.origin.x + footprint.width - 1;
  const top = footprint.origin.y + footprint.height - 1;
  const dx = Math.max(footprint.origin.x - tile.x, 0, tile.x - right);
  const dy = Math.max(footprint.origin.y - tile.y, 0, tile.y - top);
  return Math.max(dx, dy);
}

/** Hovering this many tiles from a joint's room still picks it. */
const SNAP_REACH = 12;

/** The joint whose room is under the tile, else the nearest within SNAP_REACH. */
function pickSnap(
  snaps: UpgradeSnap[],
  upgrade: UpgradeEntry,
  tile: Tile | null,
): UpgradeSnap | null {
  if (!tile) {
    return null;
  }
  let best: UpgradeSnap | null = null;
  let bestDistance = SNAP_REACH + 1;
  for (const snap of snaps) {
    const distance = footprintDistance(snapFootprint(snap, upgrade), tile);
    if (distance < bestDistance) {
      best = snap;
      bestDistance = distance;
    }
  }
  return best;
}

/** The footprint of the room centred on a tile, at the given rotation. */
function ghostFootprint(
  survey: UpgradeSurvey | null,
  anchor: Tile | null,
  upgrade: UpgradeEntry,
  rotation: number,
): Footprint | null {
  if (!survey || !anchor) {
    return null;
  }
  const turned = rotation === 90 || rotation === 270;
  const width = turned ? upgrade.height : upgrade.width;
  const height = turned ? upgrade.width : upgrade.height;
  return checkFootprint(
    survey,
    {
      x: anchor.x - Math.floor(width / 2),
      y: anchor.y - Math.floor(height / 2),
    },
    width,
    height,
  );
}

type Point = { x: number; y: number };
/** x and y: the world tile position of the canvas's bottom-left corner, fractional while dragging. */
type Camera = { x: number; y: number; zoom: number };

/** World pixels left of and below the canvas, rounded so tile edges land on whole pixels. */
function cameraOffset(camera: Camera): Point {
  return {
    x: Math.round(camera.x * camera.zoom),
    y: Math.round(camera.y * camera.zoom),
  };
}

/** Canvas pixel of a world position in tiles, y up. */
function toCanvas(camera: Camera, world: Point): Point {
  const offset = cameraOffset(camera);
  return {
    x: world.x * camera.zoom - offset.x,
    y: MAP_HEIGHT - (world.y * camera.zoom - offset.y),
  };
}

function toWorld(camera: Camera, point: Point): Point {
  const offset = cameraOffset(camera);
  return {
    x: (point.x + offset.x) / camera.zoom,
    y: (MAP_HEIGHT - point.y + offset.y) / camera.zoom,
  };
}

/** The tile under a canvas pixel, or null off the canvas. */
function tileAt(camera: Camera, point: Point | null): Tile | null {
  if (
    !point ||
    point.x < 0 ||
    point.y < 0 ||
    point.x >= MAP_WIDTH ||
    point.y >= MAP_HEIGHT
  ) {
    return null;
  }
  const world = toWorld(camera, point);
  return { x: Math.floor(world.x), y: Math.ceil(world.y) - 1 };
}

/** Canvas pixel under a client position, whatever the canvas's CSS size. */
function canvasPoint(
  canvas: HTMLCanvasElement,
  clientX: number,
  clientY: number,
): Point | null {
  const rect = canvas.getBoundingClientRect();
  if (!rect.width || !rect.height) {
    return null;
  }
  return {
    x: ((clientX - rect.left) * MAP_WIDTH) / rect.width,
    y: ((clientY - rect.top) * MAP_HEIGHT) / rect.height,
  };
}

/** Keeps the view over the surveyed region, centring it when the region is smaller. */
function clampAxis(value: number, start: number, size: number, span: number) {
  if (size <= span) {
    return start - (span - size) / 2;
  }
  return Math.min(Math.max(value, start), start + size - span);
}

function clampCamera(camera: Camera, survey: UpgradeSurvey): Camera {
  return {
    x: clampAxis(camera.x, survey.x, survey.width, MAP_WIDTH / camera.zoom),
    y: clampAxis(camera.y, survey.y, survey.height, MAP_HEIGHT / camera.zoom),
    zoom: camera.zoom,
  };
}

/** Zooming out stops at the first step that shows the whole survey. */
function minZoom(survey: UpgradeSurvey) {
  let zoom = ZOOM_STEPS[0];
  for (const step of ZOOM_STEPS) {
    if (
      step <= MAP_TILE &&
      survey.width * step <= MAP_WIDTH &&
      survey.height * step <= MAP_HEIGHT
    ) {
      zoom = step;
    }
  }
  return zoom;
}

/** One zoom step in or out, keeping the world point under `point` where it is. */
function zoomCamera(
  camera: Camera,
  survey: UpgradeSurvey,
  point: Point,
  direction: number,
): Camera {
  const zoom = ZOOM_STEPS[ZOOM_STEPS.indexOf(camera.zoom) + direction];
  if (zoom === undefined || zoom < minZoom(survey)) {
    return camera;
  }
  const world = toWorld(camera, point);
  return clampCamera(
    {
      x: world.x - point.x / zoom,
      y: world.y - (MAP_HEIGHT - point.y) / zoom,
      zoom,
    },
    survey,
  );
}

function hexColor(hex: string) {
  return [1, 3, 5].map((start) => parseInt(hex.slice(start, start + 2), 16));
}

/** Pixel colour per cell class. */
const CELL_PIXELS: Record<string, number[]> = {};
for (const [cell, hex] of Object.entries(CELL_COLORS)) {
  CELL_PIXELS[cell] = hexColor(hex);
}

/** The build range border. */
const RANGE_COLOR = '#e03c3c';
/** Canvas pixels, at every zoom. */
const RANGE_LINE = 2;

/** x1, y1, x2, y2 in world tiles: one straight run of tile edges. */
export type Segment = [number, number, number, number];

/**
 * Every tile edge between an in-range tile and an out-of-range tile or the survey
 * edge, with runs along one line merged. Built once per survey.
 */
export function rangeOutline(survey: UpgradeSurvey): Segment[] {
  const { x, y, width, height, near } = survey;
  const inside = (column: number, row: number) =>
    column >= 0 &&
    row >= 0 &&
    column < width &&
    row < height &&
    near[row * width + column] === '1';
  const segments: Segment[] = [];
  // The line along the bottom of each row, plus the top of the last one.
  for (let row = 0; row <= height; row++) {
    let start = -1;
    for (let column = 0; column <= width; column++) {
      const edge =
        column < width && inside(column, row) !== inside(column, row - 1);
      if (edge && start < 0) {
        start = column;
      } else if (!edge && start >= 0) {
        segments.push([x + start, y + row, x + column, y + row]);
        start = -1;
      }
    }
  }
  // The line along the left of each column, plus the right of the last one.
  for (let column = 0; column <= width; column++) {
    let start = -1;
    for (let row = 0; row <= height; row++) {
      const edge =
        row < height && inside(column, row) !== inside(column - 1, row);
      if (edge && start < 0) {
        start = row;
      } else if (!edge && start >= 0) {
        segments.push([x + column, y + start, x + column, y + row]);
        start = -1;
      }
    }
  }
  return segments;
}

/** Strokes the build range border with the current camera. Off-canvas runs are skipped. */
function drawOutline(
  context: CanvasRenderingContext2D,
  camera: Camera,
  outline: Segment[],
) {
  if (outline.length === 0) {
    return;
  }
  const { zoom } = camera;
  const offset = cameraOffset(camera);
  const margin = RANGE_LINE;
  context.save();
  context.beginPath();
  for (const [x1, y1, x2, y2] of outline) {
    const left = x1 * zoom - offset.x;
    const right = x2 * zoom - offset.x;
    const bottom = MAP_HEIGHT - (y1 * zoom - offset.y);
    const top = MAP_HEIGHT - (y2 * zoom - offset.y);
    if (
      right < -margin ||
      left > MAP_WIDTH + margin ||
      bottom < -margin ||
      top > MAP_HEIGHT + margin
    ) {
      continue;
    }
    context.moveTo(left, bottom);
    context.lineTo(right, top);
  }
  context.strokeStyle = RANGE_COLOR;
  context.lineWidth = RANGE_LINE;
  // Square caps fill the outer pixel where two runs meet at a corner.
  context.lineCap = 'square';
  context.stroke();
  context.restore();
}

/** The survey at one pixel per tile, drawn once per survey and scaled up every frame. */
function renderSurvey(survey: UpgradeSurvey): HTMLCanvasElement | null {
  const { width, height, cells } = survey;
  const bitmap = document.createElement('canvas');
  bitmap.width = width;
  bitmap.height = height;
  const context = bitmap.getContext('2d');
  if (!context || width < 1 || height < 1) {
    return null;
  }
  const pixels = context.createImageData(width, height);
  for (let row = 0; row < height; row++) {
    // Survey rows run up from the bottom, bitmap rows down from the top.
    let offset = (height - 1 - row) * width * 4;
    for (let column = 0; column < width; column++) {
      const color = CELL_PIXELS[cells[row * width + column]] || [0, 0, 0];
      pixels.data[offset] = color[0];
      pixels.data[offset + 1] = color[1];
      pixels.data[offset + 2] = color[2];
      pixels.data[offset + 3] = 255;
      offset += 4;
    }
  }
  context.putImageData(pixels, 0, 0);
  return bitmap;
}

type MapMenu = {
  tile: Tile;
  /** The clicked spot in world tiles; the menu follows it when the view moves. */
  point: Point;
};
type MapScene = {
  survey: UpgradeSurvey | null;
  bitmap: HTMLCanvasElement | null;
  outline: Segment[];
  image: HTMLImageElement | null;
  upgrade: UpgradeEntry;
  rotation: number;
  menu: MapMenu | null;
  /** A snap upgrade's joints; null for a room placed freely */
  snaps: UpgradeSnap[] | null;
};

/** Where a wall opens once a snap room joins it. */
const OPENING_COLOR = '#e8c15a';

/**
 * One room's footprint: green or red, blocked tiles tinted. The ghost under the cursor also shows
 * the preview, turned (and for a left-hand joint mirrored) as it would be built.
 */
function drawFootprint(
  context: CanvasRenderingContext2D,
  camera: Camera,
  footprint: Footprint,
  upgrade: UpgradeEntry,
  ghost: {
    image: HTMLImageElement | null;
    rotation: number;
    mirrored: boolean;
  } | null,
) {
  const { zoom } = camera;
  const { x: left, y: top } = toCanvas(camera, {
    x: footprint.origin.x,
    y: footprint.origin.y + footprint.height,
  });
  const pixelWidth = footprint.width * zoom;
  const pixelHeight = footprint.height * zoom;
  if (ghost?.image) {
    context.save();
    // The preview is much finer than the map, so smooth it as it shrinks.
    context.imageSmoothingEnabled = true;
    context.globalAlpha = 0.75;
    context.translate(left + pixelWidth / 2, top + pixelHeight / 2);
    // Canvas y points down, so a positive angle turns clockwise like the game's rotation.
    context.rotate((ghost.rotation * Math.PI) / 180);
    if (ghost.mirrored) {
      context.scale(-1, 1);
    }
    context.drawImage(
      ghost.image,
      (-upgrade.width * zoom) / 2,
      (-upgrade.height * zoom) / 2,
      upgrade.width * zoom,
      upgrade.height * zoom,
    );
    context.restore();
  }
  const valid = !footprint.reason;
  const strong = !!ghost;
  context.fillStyle = valid
    ? `rgba(90, 200, 110, ${strong ? 0.22 : 0.1})`
    : `rgba(220, 60, 60, ${strong ? 0.22 : 0.1})`;
  context.fillRect(left, top, pixelWidth, pixelHeight);
  context.fillStyle = 'rgba(230, 50, 50, 0.55)';
  for (const tile of footprint.blocked) {
    const spot = toCanvas(camera, { x: tile.x, y: tile.y + 1 });
    context.fillRect(spot.x, spot.y, zoom, zoom);
  }
  const line = zoom < 8 || !strong ? 1 : 2;
  context.strokeStyle = valid ? '#6fd08a' : '#e05555';
  context.lineWidth = line;
  context.strokeRect(
    left + line / 2,
    top + line / 2,
    pixelWidth - line,
    pixelHeight - line,
  );
}

function drawMap(
  canvas: HTMLCanvasElement,
  scene: MapScene,
  camera: Camera | null,
  hover: Tile | null,
) {
  const context = canvas.getContext('2d');
  if (!context) {
    return;
  }
  context.fillStyle = '#000';
  context.fillRect(0, 0, MAP_WIDTH, MAP_HEIGHT);
  const { survey, bitmap, outline, image, upgrade, rotation, menu, snaps } =
    scene;
  if (!survey || !bitmap || !camera) {
    return;
  }
  const { zoom } = camera;
  const corner = toCanvas(camera, {
    x: survey.x,
    y: survey.y + survey.height,
  });
  context.imageSmoothingEnabled = false;
  context.drawImage(
    bitmap,
    corner.x,
    corner.y,
    survey.width * zoom,
    survey.height * zoom,
  );
  const target = menu ? menu.tile : hover;
  if (snaps) {
    // Every joint's room is outlined; the one picked shows the preview.
    const active = pickSnap(snaps, upgrade, target);
    for (const snap of snaps) {
      drawFootprint(
        context,
        camera,
        snapFootprint(snap, upgrade),
        upgrade,
        snap === active
          ? { image, rotation: snap.rotation, mirrored: snap.side === 'left' }
          : null,
      );
      context.fillStyle = OPENING_COLOR;
      for (const tile of pairTiles(snap.openings)) {
        const spot = toCanvas(camera, { x: tile.x, y: tile.y + 1 });
        context.fillRect(
          spot.x + zoom / 4,
          spot.y + zoom / 4,
          zoom / 2,
          zoom / 2,
        );
      }
    }
    return;
  }
  drawOutline(context, camera, outline);
  const footprint = ghostFootprint(survey, target, upgrade, rotation);
  if (!footprint) {
    return;
  }
  drawFootprint(context, camera, footprint, upgrade, {
    image,
    rotation,
    mirrored: false,
  });
}

type PlacementProps = Props & {
  upgrade: UpgradeEntry;
  onBack: () => void;
};

function UpgradePlacement({ data, act, upgrade, onBack }: PlacementProps) {
  const survey = data.upgrade_survey || null;
  // No survey and none coming: the map was refused (the reason went to chat), so Rescan stays on
  const scanning = !!data.upgrade_surveying;
  const surveying = scanning || !survey;
  // A snap upgrade goes only on the joints the server offers, each at its own rotation.
  const snaps = upgrade.snap ? data.upgrade_snaps || [] : null;
  const [rotation, setRotation] = useState(0);
  const [camera, setCamera] = useState<Camera | null>(null);
  const [hover, setHover] = useState<Tile | null>(null);
  const [menu, setMenu] = useState<MapMenu | null>(null);
  const [panning, setPanning] = useState(false);
  const canvasRef = useRef<HTMLCanvasElement>(null);
  const wrapRef = useRef<HTMLDivElement>(null);
  // Input lands between renders, so the live camera and hover sit in refs. Each
  // animation frame draws from them, then copies them to state for the Build menu.
  const cameraRef = useRef<Camera | null>(null);
  const hoverRef = useRef<Tile | null>(null);
  const pointerRef = useRef<Point | null>(null);
  const dragRef = useRef<{
    pointerId: number;
    x: number;
    y: number;
    /** Canvas pixels per CSS pixel. */
    scale: Point;
  } | null>(null);
  const wheelRef = useRef(0);
  const frameRef = useRef<number | null>(null);
  const sceneRef = useRef<MapScene | null>(null);
  const handlersRef = useRef<{
    wheel: (event: WheelEvent) => void;
    key: (key: KeyEvent) => void;
  } | null>(null);
  const image = usePreviewImage(upgrade.preview);
  // Keyed on content: a static data update can resend the same survey.
  const bitmap = useMemo(
    () => (survey ? renderSurvey(survey) : null),
    [survey?.width, survey?.height, survey?.cells],
  );
  const outline = useMemo(
    () => (survey ? rangeOutline(survey) : []),
    [survey?.x, survey?.y, survey?.width, survey?.height, survey?.near],
  );

  const target = menu ? menu.tile : hover;
  const activeSnap = snaps ? pickSnap(snaps, upgrade, target) : null;
  const footprint = snaps
    ? activeSnap
      ? snapFootprint(activeSnap, upgrade)
      : null
    : ghostFootprint(survey, target, upgrade, rotation);
  const buildRotation = activeSnap ? activeSnap.rotation : rotation;
  const menuSpot = menu && camera ? toCanvas(camera, menu.point) : null;

  /** At most one draw per animation frame, however many inputs asked for one. */
  const requestFrame = () => {
    if (frameRef.current !== null) {
      return;
    }
    frameRef.current = requestAnimationFrame(() => {
      frameRef.current = null;
      const canvas = canvasRef.current;
      if (canvas && sceneRef.current) {
        drawMap(canvas, sceneRef.current, cameraRef.current, hoverRef.current);
      }
      setCamera(cameraRef.current);
      setHover(hoverRef.current);
    });
  };

  /** Re-reads the tile under the cursor. The clicked tile holds while the menu is open. */
  const trackHover = () => {
    if (menu) {
      return;
    }
    const current = cameraRef.current;
    const tile = current ? tileAt(current, pointerRef.current) : null;
    const old = hoverRef.current;
    if (tile?.x === old?.x && tile?.y === old?.y) {
      return;
    }
    hoverRef.current = tile;
    requestFrame();
  };

  const moveCamera = (next: Camera) => {
    if (!survey) {
      return;
    }
    cameraRef.current = clampCamera(next, survey);
    trackHover();
    requestFrame();
  };

  const onWheel = (event: WheelEvent) => {
    const canvas = canvasRef.current;
    const current = cameraRef.current;
    if (!canvas || !current || !survey) {
      return;
    }
    const unit =
      event.deltaMode === 1 ? 33 : event.deltaMode === 2 ? MAP_HEIGHT : 1;
    const delta = event.deltaY * unit;
    // Small deltas add up to a step; turning the wheel back starts over.
    if (delta * wheelRef.current < 0) {
      wheelRef.current = 0;
    }
    wheelRef.current += delta;
    if (Math.abs(wheelRef.current) < WHEEL_STEP) {
      return;
    }
    const direction = wheelRef.current > 0 ? -1 : 1;
    wheelRef.current = 0;
    const point = canvasPoint(canvas, event.clientX, event.clientY);
    if (point) {
      moveCamera(zoomCamera(current, survey, point, direction));
    }
  };

  const onKey = (key: KeyEvent) => {
    const delta = PAN_KEYS[key.code];
    if (!delta) {
      return;
    }
    key.event.preventDefault();
    const current = cameraRef.current;
    if (!current) {
      return;
    }
    // About 16 screen pixels a press at any zoom, eight times that with shift.
    const stride =
      Math.max(1, Math.round(MAP_TILE / current.zoom)) * (key.shift ? 8 : 1);
    moveCamera({
      ...current,
      x: current.x + delta[0] * stride,
      y: current.y + delta[1] * stride,
    });
  };

  const endDrag = (event: ReactPointerEvent<HTMLCanvasElement>) => {
    const drag = dragRef.current;
    if (!drag || drag.pointerId !== event.pointerId) {
      return;
    }
    dragRef.current = null;
    if (event.currentTarget.hasPointerCapture(drag.pointerId)) {
      event.currentTarget.releasePointerCapture(drag.pointerId);
    }
    setPanning(false);
  };

  // Handlers bound outside React (the wheel, KeyListener) read these, so they always see this render.
  useLayoutEffect(() => {
    sceneRef.current = {
      survey,
      bitmap,
      outline,
      image,
      upgrade,
      rotation,
      menu,
      snaps,
    };
    handlersRef.current = { wheel: onWheel, key: onKey };
  });

  useLayoutEffect(() => {
    requestFrame();
  }, [
    bitmap,
    outline,
    image,
    rotation,
    menu,
    snaps,
    upgrade.width,
    upgrade.height,
  ]);

  // A new survey keeps the current view where it can, else opens on the outpost.
  useLayoutEffect(() => {
    if (!survey) {
      return;
    }
    const old = cameraRef.current;
    const zoom = Math.max(old?.zoom ?? MAP_TILE, minZoom(survey));
    moveCamera(
      old
        ? { ...old, zoom }
        : {
            x: survey.x + Math.floor((survey.width - MAP_WIDTH / zoom) / 2),
            y: survey.y + Math.floor((survey.height - MAP_HEIGHT / zoom) / 2),
            zoom,
          },
    );
  }, [survey?.x, survey?.y, survey?.z, survey?.width, survey?.height]);

  // React's onWheel is passive and cannot stop the window scrolling.
  useEffect(() => {
    const wrap = wrapRef.current;
    if (!wrap) {
      return;
    }
    const listener = (event: WheelEvent) => {
      event.preventDefault();
      handlersRef.current?.wheel(event);
    };
    wrap.addEventListener('wheel', listener, { passive: false });
    return () => wrap.removeEventListener('wheel', listener);
  }, []);

  useEffect(
    () => () => {
      if (frameRef.current !== null) {
        cancelAnimationFrame(frameRef.current);
        frameRef.current = null;
      }
    },
    [],
  );

  // The arrows already stay out of the game by default; hold them anyway while the map is up.
  useEffect(() => {
    for (const code of Object.keys(PAN_KEYS)) acquireHotKey(Number(code));
    return () => {
      for (const code of Object.keys(PAN_KEYS)) releaseHotKey(Number(code));
    };
  }, []);

  return (
    <>
      <KeyListener onKeyDown={(key) => handlersRef.current?.key(key)} />
      <div
        className={`Outpost__map ${panning ? 'Outpost__map--panning' : ''}`}
        ref={wrapRef}
      >
        <canvas
          ref={canvasRef}
          width={MAP_WIDTH}
          height={MAP_HEIGHT}
          onPointerDown={(event) => {
            if (event.button !== 1) {
              return;
            }
            // Middle-drag pans; the browser would start autoscroll instead.
            event.preventDefault();
            const rect = event.currentTarget.getBoundingClientRect();
            if (!cameraRef.current || !rect.width || !rect.height) {
              return;
            }
            event.currentTarget.setPointerCapture(event.pointerId);
            dragRef.current = {
              pointerId: event.pointerId,
              x: event.clientX,
              y: event.clientY,
              scale: { x: MAP_WIDTH / rect.width, y: MAP_HEIGHT / rect.height },
            };
            setPanning(true);
          }}
          onPointerMove={(event) => {
            pointerRef.current = canvasPoint(
              event.currentTarget,
              event.clientX,
              event.clientY,
            );
            const drag = dragRef.current;
            const current = cameraRef.current;
            if (!drag || drag.pointerId !== event.pointerId || !current) {
              trackHover();
              return;
            }
            // Middle button let go while another is still held.
            if (!(event.buttons & 4)) {
              endDrag(event);
              trackHover();
              return;
            }
            // Deltas from the last move, so a zoom mid-drag doesn't jump the map.
            const dx = ((event.clientX - drag.x) * drag.scale.x) / current.zoom;
            const dy = ((event.clientY - drag.y) * drag.scale.y) / current.zoom;
            drag.x = event.clientX;
            drag.y = event.clientY;
            moveCamera({ ...current, x: current.x - dx, y: current.y + dy });
          }}
          onPointerUp={endDrag}
          onPointerCancel={endDrag}
          onLostPointerCapture={endDrag}
          onPointerLeave={() => {
            pointerRef.current = null;
            trackHover();
          }}
          onMouseDown={(event) => {
            if (event.button === 1) {
              event.preventDefault();
            }
          }}
          onAuxClick={(event) => event.preventDefault()}
          onClick={(event) => {
            // A left press during a middle-drag belongs to the drag.
            if (dragRef.current) {
              return;
            }
            const current = cameraRef.current;
            const point = canvasPoint(
              event.currentTarget,
              event.clientX,
              event.clientY,
            );
            pointerRef.current = point;
            const tile = current ? tileAt(current, point) : null;
            if (menu) {
              setMenu(null);
              hoverRef.current = tile;
              requestFrame();
              return;
            }
            if (!tile || !point || !current || surveying) {
              return;
            }
            hoverRef.current = tile;
            setHover(tile);
            setMenu({ tile, point: toWorld(current, point) });
          }}
        />
        {surveying ? (
          <div className="Outpost__map-status">
            {scanning ? 'Surveying' : 'No survey'}
          </div>
        ) : snaps && snaps.length === 0 ? (
          <div className="Outpost__map-status">No free wall</div>
        ) : null}
        {menu && footprint && menuSpot ? (
          <div
            className="Outpost__map-menu"
            style={{
              left: `clamp(0px, ${(menuSpot.x / MAP_WIDTH) * 100}%, calc(100% - 170px))`,
              top: `clamp(0px, ${(menuSpot.y / MAP_HEIGHT) * 100}%, calc(100% - 70px))`,
            }}
          >
            <Button.Confirm
              icon="hammer"
              disabled={!!footprint.reason}
              tooltip={footprint.reason || undefined}
              confirmContent="Permanent. Build here?"
              onClick={() => {
                act('place_upgrade', {
                  id: upgrade.id,
                  x: footprint.origin.x,
                  y: footprint.origin.y,
                  rotation: buildRotation,
                });
                setMenu(null);
              }}
            >
              Build
            </Button.Confirm>
            {snaps ? null : (
              <Button
                icon="rotate-right"
                onClick={() => {
                  setRotation((rotation + 90) % 360);
                  setMenu(null);
                }}
              >
                Rotate
              </Button>
            )}
          </div>
        ) : null}
      </div>
      <div className="Outpost__map-side">
        <div className="Outpost__heading">
          <Icon name="map-location-dot" />
          {upgrade.name}
        </div>
        <div className="Outpost__map-actions">
          {snaps ? null : (
            <Button
              icon="rotate-right"
              onClick={() => {
                setRotation((rotation + 90) % 360);
                setMenu(null);
              }}
            >
              Rotate
            </Button>
          )}
          <Button
            icon="arrows-rotate"
            disabled={scanning}
            onClick={() => act('refresh_upgrade_map', { id: upgrade.id })}
          >
            Rescan
          </Button>
        </div>
        <div className="Outpost__map-actions">
          <Button icon="arrow-left" onClick={onBack}>
            Back
          </Button>
        </div>
      </div>
    </>
  );
}

function PriceEditor({
  row,
  canSet,
  act,
}: {
  row: PriceRow;
  canSet: boolean;
  act: Act;
}) {
  const value = Number(row.value) || 0;
  const max = Math.max(0, Number(row.max) || 0);
  const [draft, setDraft] = useState<number | null>(null);
  // A new server value (ours accepted, or someone else's) replaces the draft.
  useEffect(() => {
    setDraft(null);
  }, [value]);
  const shown = draft ?? value;
  return (
    <div className="Outpost__row">
      <span
        className={`Outpost__plain ${row.available ? '' : 'Outpost__muted'}`}
      >
        {row.label || row.key}
      </span>
      <NumberInput
        value={shown}
        minValue={0}
        maxValue={max}
        step={1}
        stepPixelSize={2}
        width="92px"
        unit="cr"
        disabled={!canSet}
        onChange={(next) =>
          setDraft(Math.min(max, Math.max(0, Math.round(next))))
        }
      />
      <Button
        icon="check"
        disabled={!canSet || shown === value}
        onClick={() => act('set_price', { key: row.key, value: shown })}
      >
        Set
      </Button>
    </div>
  );
}

function PricingTab({ data, act }: Props) {
  const pricing = data.pricing || {};
  const prices = pricing.prices || [];
  const ledger = pricing.ledger || [];
  const totals = pricing.totals || [];
  const sum = totals.reduce(
    (total, entry) => total + (Number(entry.total) || 0),
    0,
  );
  const takings = totals.length > 0 || ledger.length > 0;
  return (
    <div
      className={`Outpost__page ${takings ? 'Outpost__page--halves' : 'Outpost__page--single'}`}
    >
      <div className="Outpost__col">
        <Frame title="Prices" icon="tags" fill>
          {prices.length === 0 ? <None>Nothing to price</None> : null}
          {prices.map((row) => (
            <PriceEditor
              key={row.key}
              row={row}
              canSet={!!data.can_set_prices}
              act={act}
            />
          ))}
        </Frame>
      </div>
      {takings ? (
        <div className="Outpost__col">
          <Frame title="Takings" icon="coins" fill>
            {typeof pricing.last_hour === 'number' ? (
              <div className="Outpost__total">
                <span>Last hour</span>
                <span className="Outpost__mono">
                  {credits(pricing.last_hour)}
                </span>
              </div>
            ) : null}
            {totals.length > 0 ? (
              <>
                <Section title="By source" />
                {totals.map((entry) => (
                  <div className="Outpost__row" key={entry.service}>
                    <span className="Outpost__plain">
                      {entry.label || entry.service}
                    </span>
                    <strong className="Outpost__amount">
                      {credits(entry.total)}
                    </strong>
                  </div>
                ))}
                <div className="Outpost__total">
                  <span>Total</span>
                  <span className="Outpost__mono">{credits(sum)}</span>
                </div>
              </>
            ) : null}
            {ledger.length > 0 ? (
              <>
                <Section title="Ledger" />
                {/* The server sends the ledger newest first. */}
                {ledger.map((entry, index) => (
                  <div
                    className="Outpost__row"
                    key={`${entry.time}-${ledger.length - index}`}
                  >
                    <span className="Outpost__time">{entry.time}</span>
                    <div className="Outpost__person">
                      <strong>{entry.label}</strong>
                      {entry.who ? <small>{entry.who}</small> : null}
                    </div>
                    {Number(entry.amount) > 0 ? (
                      <strong className="Outpost__amount">
                        +{credits(entry.amount)}
                      </strong>
                    ) : Number(entry.amount) < 0 ? (
                      <strong className="Outpost__amount Outpost__amount--refund">
                        -{credits(Math.abs(Number(entry.amount)))}
                      </strong>
                    ) : null}
                  </div>
                ))}
              </>
            ) : null}
          </Frame>
        </div>
      ) : null}
    </div>
  );
}

// ===== Outpost =====

function RegistryFrame({ data, act }: Props) {
  const [name, setName] = useState(data.outpost_name || '');
  const [memo, setMemo] = useState(data.memo || '');
  const manage = !!data.can_manage;
  return (
    <Frame title="Registry" icon="house-flag" fill>
      <label className="Outpost__field-label">Name</label>
      <div className="Outpost__field-row">
        <Input
          fluid
          value={name}
          onChange={setName}
          disabled={!manage}
          maxLength={64}
        />
        <Button
          icon="check"
          tooltip={data.rename_cooldown > 0 ? 'Renamed recently' : undefined}
          disabled={
            !manage ||
            !name.trim() ||
            name.trim() === data.outpost_name ||
            data.rename_cooldown > 0
          }
          onClick={() => act('rename', { name: name.trim() })}
        >
          Rename
        </Button>
      </div>
      <label className="Outpost__field-label">Public memo</label>
      <TextArea
        fluid
        height="150px"
        value={memo}
        onChange={setMemo}
        disabled={!manage}
      />
      <div className="Outpost__field-row Outpost__field-row--follow">
        <span className="Outpost__grow" />
        <Button
          icon="floppy-disk"
          disabled={!manage || memo === data.memo}
          onClick={() => act('set_memo', { memo })}
        >
          Save memo
        </Button>
      </div>
    </Frame>
  );
}

function BroadcastFrame({ data, act }: Props) {
  const live = data.advert_remaining > 0;
  return (
    <Frame title="Broadcast" icon="satellite-dish">
      <div className="Outpost__field-row Outpost__field-row--lead">
        <span className="Outpost__grow Outpost__readout">
          {live
            ? `On air, ${Math.ceil(data.advert_remaining / 60)} min`
            : credits(data.advert_cost)}
        </span>
        <Button
          icon="tower-broadcast"
          disabled={
            !data.can_manage ||
            !!data.advert_denial ||
            !data.can_spend ||
            live ||
            data.advert_cooldown > 0
          }
          tooltip={(!live && data.advert_denial) || undefined}
          onClick={() => act('buy_advert')}
        >
          {live ? 'On air' : 'Broadcast'}
        </Button>
      </div>
    </Frame>
  );
}

function OwnershipFrame({ data, act }: Props) {
  const [recipient, setRecipient] = useState('');
  const candidates = data.candidates || [];
  const selected = candidates.find((person) => person.ref === recipient);
  if (data.is_owner) {
    return (
      <Frame title="Ownership" icon="key">
        <label className="Outpost__field-label">Transfer to</label>
        <div className="Outpost__field-row">
          <Dropdown
            width="100%"
            placeholder="Someone on site"
            displayText={selected?.name || 'Someone on site'}
            selected={recipient}
            options={candidates.map((person) => ({
              displayText: person.name,
              value: person.ref,
            }))}
            onSelected={setRecipient}
          />
          <Button
            icon="right-left"
            disabled={!selected}
            onClick={() => act('transfer', { ref: recipient })}
          >
            Transfer
          </Button>
        </div>
        <div className="Outpost__field-row Outpost__field-row--apart">
          <span className="Outpost__grow" />
          <Button
            color="bad"
            icon="arrow-right-from-bracket"
            onClick={() => act('abandon')}
          >
            Abandon outpost
          </Button>
        </div>
      </Frame>
    );
  }
  if (!data.has_owner) {
    return (
      <Frame title="Ownership" icon="key">
        <div className="Outpost__field-row Outpost__field-row--lead">
          <span className="Outpost__grow" />
          <Button
            icon="flag"
            disabled={!data.can_claim}
            onClick={() => act('claim')}
          >
            Claim outpost
          </Button>
        </div>
      </Frame>
    );
  }
  return null;
}

function OutpostTab({ data, act }: Props) {
  return (
    <div className="Outpost__page Outpost__page--halves">
      <div className="Outpost__col">
        {data.can_manage ? (
          <RegistryFrame data={data} act={act} />
        ) : (
          <Frame title="Registry" icon="house-flag" fill>
            <label className="Outpost__field-label">Public memo</label>
            <div className="Outpost__plain">{data.memo}</div>
          </Frame>
        )}
      </div>
      <div className="Outpost__col">
        {data.can_manage ? <BroadcastFrame data={data} act={act} /> : null}
        <OwnershipFrame data={data} act={act} />
      </div>
    </div>
  );
}

// ===== Shell =====

type TabId = 'ships' | 'people' | 'rooms' | 'pricing' | 'outpost';
type Tab = { id: TabId; title: string; icon: string };
const TABS: Record<TabId, Tab> = {
  ships: { id: 'ships', title: 'Ships', icon: 'shuttle-space' },
  people: { id: 'people', title: 'People', icon: 'users' },
  rooms: { id: 'rooms', title: 'Rooms', icon: 'cubes' },
  pricing: { id: 'pricing', title: 'Pricing', icon: 'tags' },
  outpost: { id: 'outpost', title: 'Outpost', icon: 'house-flag' },
};

/**
 * Managers see every tab. Treasurers get Ships (materials) and Pricing; pricers
 * Pricing; anyone else Ships. Rooms shows for staff when a room lets them change
 * a setting; Outpost shows while the outpost is unclaimed, for the claim button.
 */
function visibleTabs(data: OutpostData): Tab[] {
  if (data.is_owner || data.can_manage) {
    return [TABS.ships, TABS.people, TABS.rooms, TABS.pricing, TABS.outpost];
  }
  const pricing = !!data.can_set_prices || !!data.can_view_income;
  const treasurer = canSelectSilo(data) || !!data.can_spend;
  const tabs: Tab[] = [];
  if (treasurer || !pricing) {
    tabs.push(TABS.ships);
  }
  if (
    serviceRooms(data).some(
      (room) => !!room.detail?.can_toggle || !!room.detail?.can_edit,
    )
  ) {
    tabs.push(TABS.rooms);
  }
  if (pricing) {
    tabs.push(TABS.pricing);
  }
  if (!data.has_owner) {
    tabs.push(TABS.outpost);
  }
  return tabs;
}

function Header({ data }: { data: OutpostData }) {
  return (
    <header className="Outpost__header">
      <div className="Outpost__cell Outpost__cell--name">
        <Icon name="house-flag" />
        <strong title={data.outpost_name}>
          {data.outpost_name || 'Outpost registry'}
        </strong>
      </div>
      <div className="Outpost__cell Outpost__cell--owner">
        <span className="Outpost__cell-label">OWNER</span>
        <strong>{data.founder_name || 'Unclaimed'}</strong>
      </div>
      {data.can_manage || data.can_spend ? (
        <div className="Outpost__cell Outpost__cell--treasury">
          <span className="Outpost__cell-label">TREASURY</span>
          <strong>{credits(data.treasury_balance)}</strong>
        </div>
      ) : null}
    </header>
  );
}

export function OutpostManagementPanel({ data, act }: Props) {
  const [chosenTab, setTab] = useState<TabId>('ships');
  const [placingId, setPlacingId] = useState<string | null>(null);
  const placingUpgrade = (data.upgrade_catalog || []).find(
    (entry) => entry.id === placingId,
  );
  const placingStatus = (data.upgrades || []).find(
    (entry) => entry.id === placingId,
  );
  // Placed, cancelled or refused: back to the room list.
  useEffect(() => {
    if (placingId && placingStatus?.state !== 'ready') {
      setPlacingId(null);
    }
  }, [placingId, placingStatus?.state]);
  const tabs = visibleTabs(data);
  const tab = tabs.some((item) => item.id === chosenTab)
    ? chosenTab
    : tabs[0]?.id;
  const requests = data.dock_requests?.length || 0;
  const placing = !!data.linked && !!placingUpgrade && tab === 'rooms';

  let page: ReactNode = null;
  if (!data.linked) {
    page = (
      <div className="Outpost__page Outpost__page--single">
        <Frame title="Outpost" icon="link-slash" fill>
          <None>No outpost link</None>
        </Frame>
      </div>
    );
  } else if (placing && placingUpgrade) {
    page = (
      <div className="Outpost__page Outpost__page--single">
        <Frame
          title={`Place ${placingUpgrade.name}`}
          icon="map-location-dot"
          fill
          flush
          bodyClassName="Outpost__placement"
        >
          <UpgradePlacement
            data={data}
            act={act}
            upgrade={placingUpgrade}
            onBack={() => {
              act('close_upgrade_map');
              setPlacingId(null);
            }}
          />
        </Frame>
      </div>
    );
  } else if (tab === 'ships') {
    page = <ShipsTab data={data} act={act} />;
  } else if (tab === 'people') {
    page = <PeopleTab data={data} act={act} />;
  } else if (tab === 'rooms') {
    page = (
      <RoomsTab
        data={data}
        act={act}
        onPlace={(id) => {
          act('open_upgrade_map', { id });
          setPlacingId(id);
        }}
      />
    );
  } else if (tab === 'pricing') {
    page = <PricingTab data={data} act={act} />;
  } else if (tab === 'outpost') {
    page = <OutpostTab data={data} act={act} />;
  }

  return (
    <div className="Outpost">
      <Header data={data} />
      {data.linked && tabs.length > 0 ? (
        <nav className="Outpost__tabs">
          {tabs.map((item) => (
            <button
              type="button"
              key={item.id}
              className={`Outpost__tab ${tab === item.id ? 'Outpost__tab--active' : ''}`}
              onClick={() => setTab(item.id)}
            >
              <Icon name={item.icon} />
              {item.title}
              {item.id === 'ships' && requests > 0 ? (
                <span className="Outpost__badge">{requests}</span>
              ) : null}
            </button>
          ))}
        </nav>
      ) : null}
      {data.playtest_visitor ? (
        <div className="Outpost__banner" role="status">
          <Icon name="user-secret" />
          Billed as a visitor.
        </div>
      ) : null}
      {page}
    </div>
  );
}

export const OutpostManagement = () => {
  const { data, act } = useBackend<OutpostData>();
  return (
    <Window title="Outpost Management" width={1000} height={680}>
      <Window.Content fitted>
        <OutpostManagementPanel data={data} act={act} />
      </Window.Content>
    </Window>
  );
};
