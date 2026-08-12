/**
 * Chrome Cradle console. Keep GEOMETRY aligned with the faceplate artwork.
 */
import { Tooltip } from 'tgui-core/components';
import { type BooleanLike, classes } from 'tgui-core/react';

import { resolveAsset } from '../../tgui/assets';
import { useBackend } from '../backend';
import { Window } from '../layouts';

// ---------------------------------------------------------------- geometry

const FRAME = { w: 1200, h: 760 };

type Rect = { x: number; y: number; w: number; h: number };

const GEOMETRY = {
  IDENT: { x: 8, y: 6, w: 470, h: 30 },
  LOAD: { x: 486, y: 6, w: 430, h: 30 },
  BANK: { x: 924, y: 6, w: 268, h: 30 },
  RACK: { x: 10, y: 50, w: 586, h: 556 },
  DETAIL: { x: 606, y: 50, w: 586, h: 556 },
  STATUS: { x: 10, y: 616, w: 586, h: 136 },
  CTRL: { x: 606, y: 616, w: 586, h: 136 },
} satisfies Record<string, Rect>;

/**
 * The backplate, served by /datum/asset/simple/chrome_cradle_plate. Stretched
 * to 100% x 100% rather than covered, because its brackets are drawn at the
 * same GEOMETRY coordinates the panels are positioned from. Set to null to
 * fall back to the CSS gradient.
 */
const PLATE_ASSET: string | null = 'chrome_cradle_plate.png';

const panelStyle = (r: Rect) => ({
  left: `${(r.x / FRAME.w) * 100}%`,
  top: `${(r.y / FRAME.h) * 100}%`,
  width: `${(r.w / FRAME.w) * 100}%`,
  height: `${(r.h / FRAME.h) * 100}%`,
});

// ---------------------------------------------------------------- data

/** Where a piece of chrome currently sits, as far as the rig is concerned. */
type WareState = 'installed' | 'carried' | 'tray';

type Ware = {
  ref: string;
  name: string;
  desc: string;
  /** Spritesheet key for the card art, see /datum/asset/spritesheet_batched/chrome. */
  icon: string;
  tier: number;
  load: number;
  capacity_bonus: number;
  state: WareState;
  /**
   * How many identical copies this one card stands for. The backend folds
   * duplicates into a single tile rather than tiling the same sprite across a
   * row; acting on the card acts on one of them.
   */
  count: number;
  installed: BooleanLike;
  /** Whether the occupant has the headroom for it. Always true once installed. */
  fits: BooleanLike;
  failing: BooleanLike;
  emp_down: BooleanLike;
  browned_out: BooleanLike;
  damage: number;
  configurable: BooleanLike;
  price_credits: number;
  price_vouchers: number;
  /** Sold two-to-a-case: the price quoted is the whole case's. */
  price_paired: BooleanLike;
};

type Group = {
  id: string;
  name: string;
  region: string;
  ware: Ware[];
};

/** Where the budget lands if the highlighted piece goes in, or comes out. */
type Projection = {
  load: number;
  capacity: number;
  evicts: string[];
};

/**
 * The ink picker, sent only when the highlighted piece is a Chromatic Dermis
 * already seated in the occupant. `color` is a hex. What the skin is keyed to
 * now, while the palette entries are addressed by name, which is what the
 * backend takes.
 */
type Ink = {
  color: string;
  pattern: string;
  palette: { name: string; hex: string }[];
  patterns: { name: string; blurb: string }[];
};

type Data = {
  has_occupant: BooleanLike;
  occupant_name: string | null;
  occupant_is_user: BooleanLike;
  can_operate: BooleanLike;
  busy: BooleanLike;
  busy_action: string | null;
  busy_ware: string | null;
  busy_timeleft: number;
  busy_duration: number;
  loaded_credits: number;
  tuneup_fee: number;
  barred: BooleanLike;
  account_credits: number | null;
  load: number;
  capacity: number;
  brownout: BooleanLike;
  tuneup_denial: string | null;
  selected: string | null;
  projection: Projection | null;
  ink: Ink | null;
  groups: Group[];
  tray_count: number;
};

// Mirrors the CYBERWARE_COLOR_TIER_* defines.
const TIER_COLORS: Record<number, string> = {
  1: '#ffb347',
  2: '#4dd8e6',
  3: '#ff2079',
  4: '#aaff3c',
};

const TIER_NAMES: Record<number, string> = {
  1: 'STREET',
  2: 'PRO',
  3: 'MILITARY',
  4: 'LEGEND',
};

const tierColor = (tier: number) => TIER_COLORS[tier] || TIER_COLORS[1];

/** The parlor's price tag, or null when Splice doesn't stock the piece. */
function priceLabel(ware: Ware): string | null {
  const parts: string[] = [];
  if (ware.price_vouchers > 0) {
    parts.push(
      `${ware.price_vouchers} voucher${ware.price_vouchers > 1 ? 's' : ''}`,
    );
  }
  if (ware.price_credits > 0) {
    parts.push(`${ware.price_credits} cr`);
  }
  if (parts.length === 0) {
    return null;
  }
  return parts.join(' + ') + (ware.price_paired ? ' / pair' : '');
}

/** The one-word condition a piece is in, or null when it is simply fine. */
function faultLabel(ware: Ware): string | null {
  if (ware.emp_down) {
    return 'EMP SCRAMBLED';
  }
  if (ware.browned_out) {
    return 'BROWNED OUT';
  }
  if (ware.failing) {
    return 'OFFLINE';
  }
  if (ware.damage > 0) {
    return 'DAMAGED';
  }
  return null;
}

// ---------------------------------------------------------------- root

export const ChromeCradle = () => {
  return (
    <Window title="Chrome Cradle" width={1216} height={800}>
      <Window.Content fitted>
        <Faceplate />
      </Window.Content>
    </Window>
  );
};

const Faceplate = () => {
  return (
    <div className="Cradle">
      <div
        className={`Cradle__plate ${PLATE_ASSET ? 'Cradle__plate--art' : ''}`}
        style={
          PLATE_ASSET
            ? { backgroundImage: `url("${resolveAsset(PLATE_ASSET)}")` }
            : undefined
        }
      />

      <Panel rect={GEOMETRY.IDENT}>
        <Ident />
      </Panel>
      <Panel rect={GEOMETRY.LOAD}>
        <LoadRail />
      </Panel>
      <Panel rect={GEOMETRY.BANK}>
        <Bank />
      </Panel>

      <Panel rect={GEOMETRY.RACK} label="Hardware" aux="by body system">
        <Rack />
      </Panel>
      <Panel rect={GEOMETRY.DETAIL} label="Inspection">
        <Detail />
      </Panel>

      <Panel rect={GEOMETRY.STATUS} label="Rig">
        <StatusDeck />
      </Panel>
      <Panel rect={GEOMETRY.CTRL} label="Slab">
        <Controls />
      </Panel>
    </div>
  );
};

const Panel = (props: {
  rect: Rect;
  label?: string;
  aux?: string;
  children;
}) => {
  const { rect, label, aux, children } = props;
  return (
    <div className="Cradle__panel" style={panelStyle(rect)}>
      <div className={`Cradle__well ${label ? 'Cradle__well--labelled' : ''}`}>
        {!!label && (
          <div className="Cradle__wellLabel">
            {label}
            {!!aux && <span className="Cradle__wellAux">/ {aux}</span>}
          </div>
        )}
        {children}
      </div>
    </div>
  );
};

// ---------------------------------------------------------------- top rail

const Ident = () => {
  const { data } = useBackend<Data>();
  const { has_occupant, occupant_name, can_operate, busy, barred } = data;

  let state = 'NO SUBJECT';
  let tone = 'idle';
  if (barred) {
    state = 'TRADE EMBARGO';
    tone = 'bad';
  } else if (busy) {
    state = 'RIG WORKING';
    tone = 'warn';
  } else if (has_occupant && can_operate) {
    state = 'CONSENT LIVE';
    tone = 'good';
  } else if (has_occupant) {
    state = 'CANNOT CONSENT';
    tone = 'bad';
  }

  return (
    <div className="Cradle__ident">
      <span className="Cradle__identTag">SUBJECT</span>
      <span className="Cradle__identName">
        {has_occupant ? occupant_name : 'slab empty'}
      </span>
      <span className={`Cradle__identState Cradle__identState--${tone}`}>
        {state}
      </span>
    </div>
  );
};

/**
 * The neural budget, segmented by the piece that spends it. When something is
 * highlighted the bar also carries a projection tick: where the load lands if
 * that swap happens, so an over-capacity install is visible before it is
 * refused rather than after.
 */
const LoadRail = () => {
  const { data } = useBackend<Data>();
  const { load, capacity, brownout, groups, projection } = data;

  // One segment per seated piece, so a stacked card still spends its budget
  // once per copy rather than drawing a single fat cell.
  const installed = groups
    .flatMap((group) => group.ware)
    .filter((ware) => !!ware.installed && ware.load > 0)
    .flatMap((ware) =>
      Array.from({ length: ware.count }, (_unused, copy) => ({ ware, copy })),
    );
  const projected = projection ? projection.load : null;
  const scale = Math.max(capacity, load, projected ?? 0, 1);

  return (
    <div className="Cradle__loadRail">
      <span className="Cradle__loadTag">NEURAL LOAD</span>
      <div className="Cradle__loadTrack">
        {installed.map(({ ware, copy }) => (
          <div
            key={`${ware.ref}-${copy}`}
            className="Cradle__loadCell"
            style={{
              width: `${(ware.load / scale) * 100}%`,
              backgroundColor: brownout ? '#8c2030' : tierColor(ware.tier),
            }}
          />
        ))}
        <div
          className="Cradle__loadCap"
          style={{ left: `${(capacity / scale) * 100}%` }}
        />
        {projected !== null && projected !== load && (
          <div
            className={classes([
              'Cradle__loadGhost',
              projected > (projection?.capacity ?? capacity) &&
                'Cradle__loadGhost--over',
            ])}
            style={{
              left: `${(Math.min(projected, load) / scale) * 100}%`,
              width: `${(Math.abs(projected - load) / scale) * 100}%`,
            }}
          />
        )}
      </div>
      <span
        className={classes([
          'Cradle__loadValue',
          !!brownout && 'Cradle__loadValue--bad',
        ])}
      >
        {load}
        <span className="Cradle__loadSlash">/</span>
        {capacity}
      </span>
      {!!brownout && <span className="Cradle__brownout">BROWNOUT</span>}
    </div>
  );
};

const Bank = () => {
  const { data } = useBackend<Data>();
  const { loaded_credits, account_credits } = data;
  return (
    <div className="Cradle__bank">
      <span className="Cradle__bankTag">SLOT</span>
      <span className="Cradle__bankValue">{loaded_credits} cr</span>
      <span className="Cradle__bankTag">ID</span>
      <span className="Cradle__bankValue">
        {account_credits === null ? '-' : `${account_credits} cr`}
      </span>
    </div>
  );
};

// ---------------------------------------------------------------- rack

const Rack = () => {
  const { data } = useBackend<Data>();
  const { groups, has_occupant } = data;

  if (!has_occupant) {
    return (
      <div className="Cradle__empty">
        The rack is dark. Drag yourself onto the slab to lie back and it wakes
        up.
      </div>
    );
  }

  return (
    <div className="Cradle__rack">
      {groups.map((group) => (
        <GroupRow key={group.id} group={group} />
      ))}
    </div>
  );
};

const GroupRow = (props: { group: Group }) => {
  const { group } = props;
  // Counts are of pieces, not of cards. A stack of three spares is three.
  const total = group.ware.reduce((sum, ware) => sum + ware.count, 0);
  const installed = group.ware.reduce(
    (sum, ware) => sum + (ware.installed ? ware.count : 0),
    0,
  );
  const spare = total - installed;

  return (
    <div className="Cradle__group">
      <div className="Cradle__groupHead">
        <div
          className={classes([
            'Cradle__groupName',
            installed > 0 && 'Cradle__groupName--live',
          ])}
        >
          {group.name}
        </div>
        <div className="Cradle__groupSub">
          {group.ware.length === 0
            ? 'nothing to install'
            : `${spare} available`}
        </div>
      </div>
      <div className="Cradle__tiles">
        {group.ware.length === 0 && <div className="Cradle__tileEmpty" />}
        {group.ware.map((ware) => (
          <Tile key={ware.ref} ware={ware} />
        ))}
      </div>
    </div>
  );
};

const Tile = (props: { ware: Ware }) => {
  const { ware } = props;
  const { act, data } = useBackend<Data>();
  const picked = data.selected === ware.ref;
  const fault = faultLabel(ware);

  return (
    <Tooltip content={<TileCard ware={ware} />} position="right">
      <button
        type="button"
        className={classes([
          'Cradle__tile',
          !!ware.installed && 'Cradle__tile--installed',
          picked && 'Cradle__tile--picked',
          !ware.installed && !ware.fits && 'Cradle__tile--nofit',
        ])}
        style={{ borderColor: tierColor(ware.tier) }}
        onClick={() => act('select', { ref: ware.ref })}
      >
        <span className={classes(['chrome32x32', ware.icon])} />
        {!!ware.installed && (
          <span
            className="Cradle__tileFlag"
            style={{ backgroundColor: tierColor(ware.tier) }}
          />
        )}
        {ware.count > 1 && (
          <span className="Cradle__tileCount">×{ware.count}</span>
        )}
        {!!fault && <span className="Cradle__tileFault" />}
      </button>
    </Tooltip>
  );
};

/**
 * What a tile says on hover: the whole card without having to commit a click.
 * Clicking is what puts the piece on the body, so hovering has to be enough to
 * shop with, name, grade, what it costs the nervous system, what Splice
 * charges, and the pitch.
 */
const TileCard = (props: { ware: Ware }) => {
  const { ware } = props;
  const accent = tierColor(ware.tier);
  const fault = faultLabel(ware);
  const price = priceLabel(ware);

  return (
    <div className="Cradle__hover">
      <div className="Cradle__hoverName" style={{ color: accent }}>
        {ware.name}
      </div>
      <div className="Cradle__hoverMeta">
        <span style={{ color: accent }}>
          T{ware.tier} {TIER_NAMES[ware.tier] || 'CHROME'}
        </span>
        <span>load {ware.load}</span>
        {ware.capacity_bonus > 0 && <span>+{ware.capacity_bonus} cap</span>}
        {ware.count > 1 && <span>×{ware.count} on hand</span>}
        <span className="Cradle__hoverWhere">
          {ware.state === 'installed'
            ? 'installed'
            : ware.state === 'tray'
              ? 'in tray'
              : 'carried'}
        </span>
      </div>
      {!!price && <div className="Cradle__hoverPrice">{price}</div>}
      {!!fault && <div className="Cradle__hoverFault">{fault}</div>}
      {!ware.installed && !ware.fits && (
        <div className="Cradle__hoverFault">No neural headroom</div>
      )}
      <div className="Cradle__hoverDesc">{ware.desc}</div>
    </div>
  );
};

// ---------------------------------------------------------------- inspector

const Detail = () => {
  const { act, data } = useBackend<Data>();
  const {
    groups,
    selected,
    projection,
    occupant_is_user,
    can_operate,
    busy,
    barred,
  } = data;

  const ware = groups
    .flatMap((group) => group.ware)
    .find((entry) => entry.ref === selected);

  if (!ware) {
    return (
      <div className="Cradle__empty">
        Pick a piece from the rack. Anything you own shows up on the body before
        the rig touches you.
      </div>
    );
  }

  // Only the occupant, conscious and unrestrained, may order work on their own
  // body. Everyone else reads the same screen and can pop the tray.
  const mayOperate = !!occupant_is_user && !!can_operate && !busy && !barred;
  const accent = tierColor(ware.tier);
  const fault = faultLabel(ware);
  const price = priceLabel(ware);
  const overCapacity =
    !!projection && projection.load > projection.capacity && !ware.installed;

  return (
    <div className="Cradle__detail">
      <div className="Cradle__detailHead">
        <span
          className={classes(['chrome32x32', ware.icon, 'Cradle__detailIcon'])}
        />
        <div className="Cradle__detailTitle">
          <div className="Cradle__detailName" style={{ color: accent }}>
            {ware.name}
          </div>
          <div className="Cradle__detailTier">
            <span style={{ color: accent }}>
              TIER {ware.tier} · {TIER_NAMES[ware.tier] || 'CHROME'}
            </span>
            <span className="Cradle__detailWhere">
              {ware.state === 'installed'
                ? 'INSTALLED'
                : ware.state === 'tray'
                  ? 'IN TRAY'
                  : 'CARRIED'}
              {ware.count > 1 ? ` · ×${ware.count}` : ''}
            </span>
          </div>
        </div>
      </div>

      {!!fault && <div className="Cradle__fault">{fault}</div>}

      <div className="Cradle__stats">
        <Stat label="Neural load" value={ware.load} accent={accent} />
        {ware.capacity_bonus > 0 && (
          <Stat
            label="Capacity granted"
            value={`+${ware.capacity_bonus}`}
            accent="#59b871"
          />
        )}
        {!!price && (
          <Stat label="Parlor price" value={price} accent="#f2c24a" />
        )}
        {ware.damage > 0 && (
          <Stat label="Damage" value={ware.damage} accent="#cf4a38" />
        )}
      </div>

      <div className="Cradle__desc">{ware.desc}</div>

      {!!projection && (
        <div className="Cradle__projection">
          <div className="Cradle__projectionRow">
            <span>{ware.installed ? 'After removal' : 'After install'}</span>
            <span
              className={classes([
                'Cradle__projectionValue',
                overCapacity && 'Cradle__projectionValue--bad',
              ])}
            >
              {projection.load} / {projection.capacity} load
            </span>
          </div>
          {projection.evicts.length > 0 && (
            <div className="Cradle__evicts">
              Evicts to the tray: {projection.evicts.join(', ')}
            </div>
          )}
          {!!overCapacity && (
            <div className="Cradle__evicts Cradle__evicts--bad">
              No neural headroom. Shed load or find a Governor.
            </div>
          )}
        </div>
      )}

      <div className="Cradle__detailActions">
        {ware.installed ? (
          <ActionButton
            tone="bad"
            disabled={!mayOperate}
            hint="Three-second extraction. The ware comes back out intact."
            onClick={() => act('remove', { ref: ware.ref })}
          >
            EXTRACT
          </ActionButton>
        ) : (
          <ActionButton
            tone="good"
            disabled={!mayOperate || !ware.fits}
            hint={
              ware.fits
                ? 'Four-second install. You will be briefly sedated.'
                : 'Will not fit the current load budget.'
            }
            onClick={() => act('install', { ref: ware.ref })}
          >
            INSTALL
          </ActionButton>
        )}
      </div>

      {!!ware.configurable && !!ware.installed && (
        <InkPanel ware={ware} mayOperate={mayOperate} />
      )}
    </div>
  );
};

/**
 * The ink picker: eight pigments and five patterns, each applied to the skin
 * the moment it is clicked. Splice stocks what Splice stocks, there is no
 * free-text colour here on purpose.
 */
const InkPanel = (props: { ware: Ware; mayOperate: boolean }) => {
  const { ware, mayOperate } = props;
  const { act, data } = useBackend<Data>();
  const { ink } = data;

  if (!ink) {
    return null;
  }

  return (
    <div className="Cradle__ink">
      <div className="Cradle__inkHead">INK</div>
      <div className="Cradle__swatches">
        {ink.palette.map((swatch) => (
          <button
            key={swatch.name}
            type="button"
            title={swatch.name}
            disabled={!mayOperate}
            className={classes([
              'Cradle__swatch',
              swatch.hex === ink.color && 'Cradle__swatch--on',
            ])}
            style={{ backgroundColor: swatch.hex }}
            onClick={() =>
              mayOperate &&
              act('set_ink', { ref: ware.ref, color: swatch.name })
            }
          />
        ))}
      </div>
      <div className="Cradle__patterns">
        {ink.patterns.map((pattern) => (
          <button
            key={pattern.name}
            type="button"
            title={pattern.blurb}
            disabled={!mayOperate}
            className={classes([
              'Cradle__pattern',
              pattern.name === ink.pattern && 'Cradle__pattern--on',
            ])}
            onClick={() =>
              mayOperate &&
              act('set_ink', { ref: ware.ref, pattern: pattern.name })
            }
          >
            {pattern.name}
          </button>
        ))}
      </div>
    </div>
  );
};

const Stat = (props: { label: string; value: string | number; accent }) => {
  const { label, value, accent } = props;
  return (
    <div className="Cradle__stat">
      <div className="Cradle__statValue" style={{ color: accent }}>
        {value}
      </div>
      <div className="Cradle__statLabel">{label}</div>
    </div>
  );
};

const ActionButton = (props: {
  tone: string;
  disabled?: boolean;
  hint?: string;
  onClick: () => void;
  children;
}) => {
  const { tone, disabled, hint, onClick, children } = props;
  return (
    <button
      type="button"
      title={hint}
      disabled={disabled}
      className={classes([
        'Cradle__action',
        `Cradle__action--${tone}`,
        disabled && 'Cradle__action--off',
      ])}
      onClick={() => !disabled && onClick()}
    >
      {children}
    </button>
  );
};

// ---------------------------------------------------------------- deck

const StatusDeck = () => {
  const { data } = useBackend<Data>();
  const {
    busy,
    busy_action,
    busy_ware,
    busy_timeleft,
    busy_duration,
    barred,
    has_occupant,
    occupant_is_user,
    occupant_name,
    can_operate,
    tray_count,
  } = data;

  const progress =
    busy_duration > 0 ? (busy_duration - busy_timeleft) / busy_duration : 0;

  if (busy) {
    return (
      <div className="Cradle__deck">
        <div className="Cradle__progressLabel">
          {busy_action === 'install' ? 'INSTALLING' : 'EXTRACTING'}
          {!!busy_ware && <span> · {busy_ware}</span>}
          <span className="Cradle__progressTime">
            {busy_timeleft.toFixed(1)}s
          </span>
        </div>
        <div className="Cradle__progressTrack">
          <div
            className="Cradle__progressFill"
            style={{ width: `${progress * 100}%` }}
          />
        </div>
        <div className="Cradle__note">
          Hold still. Leaving the slab cancels the cycle. Nothing is lost, the
          ware goes to the tray.
        </div>
      </div>
    );
  }

  const notes: string[] = [];
  if (barred) {
    notes.push('Trade embargo. The rig will not work on you.');
  }
  if (!has_occupant) {
    notes.push('The slab is empty. Drag yourself onto it to lie back.');
  } else if (!occupant_is_user) {
    notes.push(
      `${occupant_name} is on the slab. The rig takes orders from its occupant only. You can still pop the parts tray.`,
    );
  } else if (!can_operate) {
    notes.push(
      'The rig refuses: you have to be conscious and unrestrained to consent to chrome work.',
    );
  } else {
    notes.push(
      'Rig idle. Highlight a piece in the rack, check it on the body, then commit.',
    );
  }
  if (tray_count > 0) {
    notes.push(
      `Parts tray holds ${tray_count} piece${tray_count > 1 ? 's' : ''}.`,
    );
  }

  return (
    <div className="Cradle__deck">
      {notes.map((note) => (
        <div key={note} className="Cradle__note">
          {note}
        </div>
      ))}
    </div>
  );
};

const Controls = () => {
  const { act, data } = useBackend<Data>();
  const {
    tuneup_fee,
    tuneup_denial,
    occupant_is_user,
    can_operate,
    busy,
    barred,
    loaded_credits,
    tray_count,
    has_occupant,
  } = data;

  const mayOperate = !!occupant_is_user && !!can_operate && !busy && !barred;

  return (
    <div className="Cradle__controls">
      <ActionButton
        tone="cool"
        disabled={!mayOperate || !!tuneup_denial}
        hint={
          tuneup_denial ||
          `Clears EMP scramble and repairs all installed chrome. ${tuneup_fee} cr.`
        }
        onClick={() => act('tuneup')}
      >
        {`TUNE-UP · ${tuneup_fee} CR`}
      </ActionButton>
      <ActionButton
        tone="plain"
        disabled={tray_count === 0}
        hint="Anyone adjacent can pop the tray. Evicted chrome is never held hostage."
        onClick={() => act('eject_tray')}
      >
        {`EJECT TRAY${tray_count > 0 ? ` · ${tray_count}` : ''}`}
      </ActionButton>
      <ActionButton
        tone="plain"
        disabled={loaded_credits <= 0 || !!busy}
        hint="Returns the slab's loaded cash as a holochip."
        onClick={() => act('eject_cash')}
      >
        EJECT CASH
      </ActionButton>
      <ActionButton
        tone="plain"
        disabled={!has_occupant}
        hint="Gets the patient off the slab. Cancels any running cycle, the ware goes to the tray."
        onClick={() => act('get_up')}
      >
        {occupant_is_user ? 'GET UP' : 'UNBUCKLE'}
      </ActionButton>
    </div>
  );
};
