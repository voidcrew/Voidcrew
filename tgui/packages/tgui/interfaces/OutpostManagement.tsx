import { type ReactNode, useState } from 'react';
import {
  Button,
  Dropdown,
  Icon,
  Input,
  NumberInput,
  TextArea,
} from 'tgui-core/components';
import type { BooleanLike } from 'tgui-core/react';
import { resolveAsset } from '../assets';
import { useBackend } from '../backend';
import { Window } from '../layouts';

// Matches the existing 1200 x 760 console plate, including its inset borders.
const FRAME = { width: 1200, height: 760 };
const PANELS = {
  identity: [8, 6, 470, 30],
  owner: [486, 6, 430, 30],
  status: [924, 6, 268, 30],
  directory: [10, 50, 586, 556],
  registry: [606, 50, 586, 556],
  broadcast: [10, 616, 586, 136],
  command: [606, 616, 586, 136],
} as const;

type Vessel = { ref: string; name: string };
type Candidate = Vessel & {
  ckey: string;
  can_receive_outpost: BooleanLike;
  is_resident?: BooleanLike;
};
type Resident = Vessel & {
  active: BooleanLike;
  steward: BooleanLike;
  treasurer: BooleanLike;
};
export type OutpostData = {
  linked: BooleanLike;
  outpost_name: string;
  founder_name: string | null;
  memo: string;
  is_owner: BooleanLike;
  has_owner: BooleanLike;
  can_manage: BooleanLike;
  can_spend: BooleanLike;
  raidable: BooleanLike;
  dock_mode: string;
  rename_cooldown: number;
  advert_cost: number;
  advert_cooldown: number;
  advert_remaining: number;
  dock_requests: Vessel[];
  approved_ships: Vessel[];
  banned_ships: Vessel[];
  builders: string[];
  candidates: Candidate[];
  resident_mode: string;
  resident_limit: number;
  resident_active: number;
  arrival_available: BooleanLike;
  residents: Resident[];
  resident_invites: Record<string, BooleanLike>;
  resident_blocked: string[];
};
type Act = (action: string, params?: Record<string, unknown>) => unknown;
type Props = { data: OutpostData; act: Act };

function Panel({
  slot,
  children,
  className = '',
}: {
  slot: keyof typeof PANELS;
  children: ReactNode;
  className?: string;
}) {
  const [x, y, width, height] = PANELS[slot];
  return (
    <div
      className={`Outpost__panel Outpost__panel--${slot} ${className}`}
      style={{
        left: `${(x / FRAME.width) * 100}%`,
        top: `${(y / FRAME.height) * 100}%`,
        width: `${(width / FRAME.width) * 100}%`,
        height: `${(height / FRAME.height) * 100}%`,
      }}
    >
      {children}
    </div>
  );
}

function Empty({ icon, children }: { icon: string; children: ReactNode }) {
  return (
    <div className="Outpost__empty">
      <Icon name={icon} />
      <span>{children}</span>
    </div>
  );
}

function Residents({ data, act }: Props) {
  const { residents = [], candidates = [], builders = [] } = data;
  return (
    <>
      <div className="Outpost__section-label">
        Residents <span>{residents.length}</span>
      </div>
      {residents.length === 0 && <Empty icon="users">No residents</Empty>}
      {residents.map((person) => (
        <div className="Outpost__row" key={person.ref}>
          <span
            className={`Outpost__dot ${person.active ? 'Outpost__dot--online' : ''}`}
          />
          <div className="Outpost__person">
            <strong>{person.name}</strong>
            <small>{person.active ? 'Active' : 'Away'}</small>
          </div>
          {!!data.is_owner && (
            <>
              <Button
                icon="id-badge"
                selected={!!person.steward}
                tooltip="Management"
                onClick={() =>
                  act('delegate', { ref: person.ref, role: 'steward' })
                }
              />
              <Button
                icon="coins"
                selected={!!person.treasurer}
                tooltip="Treasury"
                onClick={() =>
                  act('delegate', { ref: person.ref, role: 'treasurer' })
                }
              />
            </>
          )}
          <Button
            icon="user-minus"
            tooltip="Remove resident"
            disabled={!data.can_manage}
            onClick={() => act('remove_resident', { ref: person.ref })}
          />
        </div>
      ))}
      <div className="Outpost__section-label">
        On site <span>{candidates.length}</span>
      </div>
      {candidates.length === 0 && (
        <Empty icon="location-dot">Nobody else on site</Empty>
      )}
      {candidates.map((person) => (
        <div className="Outpost__row" key={person.ref}>
          <div className="Outpost__person">
            <strong>{person.name}</strong>
            <small>{person.ckey}</small>
          </div>
          <Button
            icon="user-plus"
            tooltip="Add resident"
            selected={!!person.is_resident}
            disabled={!data.can_manage || !!person.is_resident}
            onClick={() => act('add_resident', { ref: person.ref })}
          />
          {!!data.is_owner && (
            <Button
              icon="hammer"
              tooltip="Construction"
              selected={builders.includes(person.ckey)}
              onClick={() =>
                act(
                  builders.includes(person.ckey)
                    ? 'remove_builder'
                    : 'add_builder',
                  { ref: person.ref, ckey: person.ckey },
                )
              }
            />
          )}
        </div>
      ))}
    </>
  );
}

function Docking({ data, act }: Props) {
  const groups = [
    { title: 'Requests', ships: data.dock_requests || [], kind: 'request' },
    { title: 'Cleared', ships: data.approved_ships || [], kind: 'approved' },
    { title: 'Blocked', ships: data.banned_ships || [], kind: 'banned' },
  ];
  return (
    <>
      {groups.map(({ title, ships, kind }) => (
        <div key={kind}>
          <div className="Outpost__section-label">
            {title}
            <span>{ships.length}</span>
          </div>
          {ships.length === 0 && <div className="Outpost__quiet">None</div>}
          {ships.map((ship) => (
            <div className="Outpost__row" key={ship.ref}>
              <Icon name="shuttle-space" />
              <strong className="Outpost__grow">{ship.name}</strong>
              {kind === 'request' && (
                <Button
                  icon="check"
                  color="good"
                  tooltip="Clear approach"
                  disabled={!data.can_manage}
                  onClick={() => act('approve_request', { ref: ship.ref })}
                />
              )}
              <Button
                icon={kind === 'banned' ? 'unlock' : 'xmark'}
                tooltip={
                  kind === 'banned'
                    ? 'Unblock vessel'
                    : kind === 'request'
                      ? 'Deny approach'
                      : 'Revoke clearance'
                }
                disabled={!data.can_manage}
                onClick={() =>
                  act(
                    kind === 'banned'
                      ? 'unban_ship'
                      : kind === 'request'
                        ? 'deny_request'
                        : 'revoke_approval',
                    { ref: ship.ref },
                  )
                }
              />
              {kind !== 'banned' && (
                <Button
                  icon="ban"
                  tooltip="Block vessel"
                  disabled={!data.can_manage}
                  onClick={() => act('ban_ship', { ref: ship.ref })}
                />
              )}
            </div>
          ))}
        </div>
      ))}
    </>
  );
}

function Access({ data, act }: Props) {
  const [account, setAccount] = useState('');
  const invites = Object.keys(data.resident_invites || {});
  const blocked = data.resident_blocked || [];
  const builders = data.builders || [];
  const submit = (action: string) => {
    act(action, { ckey: account.trim() });
    setAccount('');
  };
  return (
    <>
      <div className="Outpost__section-label">Return access</div>
      <div className="Outpost__inline">
        <Input
          fluid
          placeholder="Player account"
          value={account}
          onChange={setAccount}
          disabled={!data.can_manage}
        />
        <Button
          icon="user-check"
          tooltip="Invite"
          disabled={!data.can_manage || !account.trim()}
          onClick={() => submit('invite_resident')}
        />
        <Button
          icon="user-slash"
          tooltip="Block"
          disabled={!data.can_manage || !account.trim()}
          onClick={() => submit('block_resident')}
        />
      </div>
      <div className="Outpost__section-label">
        Invited<span>{invites.length}</span>
      </div>
      {invites.length === 0 && <div className="Outpost__quiet">None</div>}
      {invites.map((key) => (
        <div className="Outpost__row" key={key}>
          <span className="Outpost__grow">{key}</span>
          <Icon name="user-check" />
        </div>
      ))}
      <div className="Outpost__section-label">
        Blocked<span>{blocked.length}</span>
      </div>
      {blocked.length === 0 && <div className="Outpost__quiet">None</div>}
      {blocked.map((key) => (
        <div className="Outpost__row" key={key}>
          <span className="Outpost__grow">{key}</span>
          <Button
            icon="unlock"
            tooltip="Unblock account"
            disabled={!data.can_manage}
            onClick={() => act('unblock_resident', { ckey: key })}
          />
        </div>
      ))}
      <div className="Outpost__section-label">
        Construction<span>{builders.length}</span>
      </div>
      {builders.length === 0 && (
        <div className="Outpost__quiet">Owner only</div>
      )}
      {builders.map((key) => (
        <div className="Outpost__row" key={key}>
          <span className="Outpost__grow">{key}</span>
          <Button
            icon="xmark"
            tooltip="Revoke construction"
            disabled={!data.is_owner}
            onClick={() => act('remove_builder', { ckey: key })}
          />
        </div>
      ))}
      <Button.Confirm
        className="Outpost__reset"
        icon="rotate-left"
        color="bad"
        disabled={!data.can_manage}
        onClick={() => act('reset_resident_access')}
      >
        Reset return access
      </Button.Confirm>
    </>
  );
}

function Registry({ data, act }: Props) {
  const [name, setName] = useState(data.outpost_name || '');
  const [memo, setMemo] = useState(data.memo || '');
  const [password, setPassword] = useState('');
  const docking = [
    { id: 'open', name: 'Open', icon: 'door-open' },
    { id: 'request', name: 'Request', icon: 'hand' },
    { id: 'lockdown', name: 'Lockdown', icon: 'lock' },
  ];
  const arrivals = [
    { id: 'open', name: 'Open' },
    { id: 'password', name: 'Password' },
    { id: 'approved', name: 'Invite' },
    { id: 'closed', name: 'Closed' },
  ];
  return (
    <>
      <div className="Outpost__heading">
        <Icon name="sliders" />
        Registry & policies
      </div>
      <div className="Outpost__registry-scroll">
        <label className="Outpost__field-label">Designation</label>
        <div className="Outpost__inline">
          <Input
            fluid
            value={name}
            onChange={setName}
            disabled={!data.can_manage}
            maxLength={64}
          />
          <Button
            icon="check"
            tooltip={
              data.rename_cooldown > 0
                ? `Rename available in ${Math.ceil(data.rename_cooldown)}s`
                : 'Rename'
            }
            disabled={
              !data.can_manage ||
              !name.trim() ||
              name.trim() === data.outpost_name ||
              data.rename_cooldown > 0
            }
            onClick={() => act('rename', { name: name.trim() })}
          />
        </div>
        <label className="Outpost__field-label">Public memo</label>
        <div className="Outpost__memo">
          <TextArea
            fluid
            height="62px"
            value={memo}
            onChange={setMemo}
            disabled={!data.can_manage}
            placeholder="Public memo"
          />
          <Button
            icon="floppy-disk"
            tooltip="Save memo"
            disabled={!data.can_manage || memo === data.memo}
            onClick={() => act('set_memo', { memo })}
          />
        </div>
        <label className="Outpost__field-label">Docking</label>
        <div className="Outpost__switches">
          {docking.map((mode) => (
            <Button
              key={mode.id}
              icon={mode.icon}
              selected={data.dock_mode === mode.id}
              disabled={!data.can_manage}
              onClick={() => act('set_dock_mode', { mode: mode.id })}
            >
              {mode.name}
            </Button>
          ))}
        </div>
        <label className="Outpost__field-label">Resident arrivals</label>
        <div className="Outpost__switches">
          {arrivals.map((mode) => (
            <Button
              key={mode.id}
              selected={data.resident_mode === mode.id}
              disabled={!data.can_manage}
              onClick={() => act('resident_mode', { mode: mode.id })}
            >
              {mode.name}
            </Button>
          ))}
        </div>
        {data.resident_mode === 'password' && (
          <div className="Outpost__inline Outpost__password">
            <input
              className="Input Input--fluid"
              type="password"
              placeholder="New password"
              value={password}
              onChange={(event) => setPassword(event.currentTarget.value)}
              autoComplete="new-password"
              maxLength={64}
              disabled={!data.can_manage}
            />
            <Button
              icon="key"
              tooltip="Set password"
              disabled={!data.can_manage || !password.trim()}
              onClick={() => {
                act('resident_password', { password });
                setPassword('');
              }}
            />
          </div>
        )}
        <div className="Outpost__limit">
          <span>Resident limit</span>
          <NumberInput
            value={data.resident_limit || 6}
            minValue={1}
            maxValue={12}
            step={1}
            width="64px"
            disabled={!data.can_manage}
            onChange={(amount) =>
              act('resident_limit', { amount: String(amount) })
            }
          />
          <small>{data.resident_active || 0} active</small>
        </div>
        <div
          className={
            'Outpost__arrival ' +
            (data.arrival_available ? 'Outpost__arrival--ready' : '')
          }
        >
          <Icon name="bed" />
          {data.arrival_available ? 'Cryo ready' : 'No free cryopod'}
        </div>
      </div>
    </>
  );
}

function Broadcast({ data, act }: Props) {
  const live = data.advert_remaining > 0;
  return (
    <>
      <div className="Outpost__heading">
        <Icon name="satellite-dish" />
        Broadcast{!!live && <span className="Outpost__live">LIVE</span>}
      </div>
      <div className="Outpost__footer-row">
        <div className="Outpost__readout">
          <strong>
            {live
              ? `${Math.ceil(data.advert_remaining / 60)} min`
              : `${data.advert_cost} cr`}
          </strong>
          <small>{live ? 'Remaining' : 'Sector listing'}</small>
        </div>
        <Button
          icon="tower-broadcast"
          disabled={
            !data.can_manage ||
            !data.can_spend ||
            live ||
            data.advert_cooldown > 0
          }
          tooltip={
            !data.can_spend
              ? 'Treasury permission required'
              : data.advert_cooldown > 0
                ? `Ready in ${Math.ceil(data.advert_cooldown)}s`
                : undefined
          }
          onClick={() => act('buy_advert')}
        >
          {live ? 'On air' : 'Broadcast'}
        </Button>
      </div>
    </>
  );
}

function Ownership({ data, act }: Props) {
  const [recipient, setRecipient] = useState<string>('');
  const candidates = (data.candidates || []).filter(
    (person) => !!person.can_receive_outpost,
  );
  const selected = candidates.find((person) => person.ref === recipient);
  return (
    <>
      <div className="Outpost__heading">
        <Icon name="flag" />
        Ownership
      </div>
      {data.is_owner ? (
        <div className="Outpost__ownership">
          <Dropdown
            fluid
            placeholder="New owner"
            displayText={selected?.name || 'New owner'}
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
          <Button
            color="bad"
            icon="arrow-right-from-bracket"
            onClick={() => act('abandon')}
          >
            Abandon
          </Button>
        </div>
      ) : (
        <div className="Outpost__quiet">{data.founder_name || 'Unclaimed'}</div>
      )}
    </>
  );
}

export function OutpostManagementPanel({ data, act }: Props) {
  const [tab, setTab] = useState('docking');
  const tabs = [
    { id: 'docking', title: 'Docking', icon: 'anchor' },
    { id: 'residents', title: 'Residents', icon: 'users' },
    { id: 'access', title: 'Access', icon: 'id-card' },
  ];
  return (
    <div className="Outpost">
      <div
        className="Outpost__plate"
        style={{
          backgroundImage: `url("${resolveAsset('outpost_management_plate.png')}")`,
        }}
      />
      <Panel slot="identity" className="Outpost__rail">
        <Icon name="house-flag" />
        <strong title={data.outpost_name}>
          {data.outpost_name || 'Outpost registry'}
        </strong>
      </Panel>
      <Panel slot="owner" className="Outpost__rail">
        <span>OWNER</span>
        <strong>{data.founder_name || 'Unclaimed'}</strong>
      </Panel>
      <Panel slot="status" className="Outpost__rail Outpost__rail--status">
        <Icon name={data.raidable ? 'shield-halved' : 'shield'} />
        <strong>{data.raidable ? 'Unpatrolled' : 'Patrolled'}</strong>
      </Panel>
      {data.linked ? (
        <>
          <Panel slot="directory">
            <nav className="Outpost__tabs">
              {tabs.map((item) => (
                <Button
                  key={item.id}
                  icon={item.icon}
                  selected={tab === item.id}
                  onClick={() => setTab(item.id)}
                >
                  {item.title}
                  {item.id === 'docking' &&
                  (data.dock_requests?.length || 0) > 0 ? (
                    <span className="Outpost__count">
                      {data.dock_requests.length}
                    </span>
                  ) : null}
                </Button>
              ))}
            </nav>
            <div className="Outpost__directory-scroll">
              {tab === 'docking' ? (
                <Docking data={data} act={act} />
              ) : tab === 'residents' ? (
                <Residents data={data} act={act} />
              ) : (
                <Access data={data} act={act} />
              )}
            </div>
          </Panel>
          <Panel slot="registry">
            <Registry data={data} act={act} />
          </Panel>
          <Panel slot="broadcast">
            <Broadcast data={data} act={act} />
          </Panel>
          <Panel slot="command">
            <Ownership data={data} act={act} />
          </Panel>
        </>
      ) : (
        <Panel slot="directory">
          <Empty icon="link-slash">No outpost link</Empty>
        </Panel>
      )}
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
