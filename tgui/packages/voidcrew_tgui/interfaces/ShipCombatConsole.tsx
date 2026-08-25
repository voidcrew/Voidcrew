/**
 * Ship combat console.
 *
 * A fixed 1200x760 faceplate, same instrument family as the helm: top rail,
 * left-hand systems stack, a central tactical scope with a contact drawer
 * beside it, and a bottom weapons console. Every panel is positioned from
 * GEOMETRY below, in percentages, so the whole console scales with the window.
 * GEOMETRY is also the source geometry for the faceplate art, the plate PNG
 * is composited from this table; keep the two in step.
 *
 * The scope is drawn here rather than piped through a BYOND camera map, which
 * is what lets it label contacts, take clicks, show lock progress and glide
 * marks between server ticks. Unlike the helm chart it is polar and fixed:
 * sensor range is three tiles, so the whole battlespace fits in one ring set
 * and there is nothing to pan or zoom.
 */
import { useEffect, useMemo, useRef, useState } from 'react';
import { Input } from 'tgui-core/components';
import { type BooleanLike } from 'tgui-core/react';

import { resolveAsset } from '../../tgui/assets';
import { useBackend } from '../backend';
import { Window } from '../layouts';

// ---------------------------------------------------------------- geometry

const FRAME = { w: 1200, h: 760 };

type Rect = { x: number; y: number; w: number; h: number };

const GEOMETRY = {
  IDENT: { x: 8, y: 6, w: 392, h: 32 },
  ZONE: { x: 408, y: 6, w: 284, h: 32 },
  ALERT: { x: 700, y: 6, w: 492, h: 32 },
  SHIELD: { x: 10, y: 54, w: 212, h: 118 },
  HULL: { x: 10, y: 180, w: 212, h: 64 },
  SIG: { x: 10, y: 252, w: 212, h: 108 },
  CLOAK: { x: 10, y: 368, w: 212, h: 104 },
  SIPHON: { x: 10, y: 480, w: 212, h: 104 },
  SCOPE: { x: 240, y: 52, w: 652, h: 532 },
  DRAWER: { x: 908, y: 52, w: 284, h: 532 },
  TUBES: { x: 10, y: 600, w: 270, h: 152 },
  LASERS: { x: 288, y: 600, w: 270, h: 152 },
  INTERDICT: { x: 566, y: 600, w: 308, h: 152 },
  OPS: { x: 882, y: 600, w: 310, h: 152 },
} satisfies Record<string, Rect>;

/**
 * The faceplate art, served by /datum/asset/simple/combat_faceplate. Its bezels
 * are composited at the exact GEOMETRY coordinates above, so it is stretched to
 * 100% x 100% rather than covered. The panels are positioned in percentages
 * and the two have to track each other. Set to null to fall back to the CSS
 * plate.
 */
const FACEPLATE_ASSET: string | null = 'combat_faceplate.png';

const panelStyle = (r: Rect) => ({
  left: `${(r.x / FRAME.w) * 100}%`,
  top: `${(r.y / FRAME.h) * 100}%`,
  width: `${(r.w / FRAME.w) * 100}%`,
  height: `${(r.h / FRAME.h) * 100}%`,
});

/**
 * SVG elements take `transform-origin: 50% 50%` of the view-box by default,
 * which silently breaks any translate/scale chain that assumes the user-space
 * origin. Every CSS transform on an SVG node in this file pins the origin to
 * 0,0.
 */
const SVG_ORIGIN = { transformOrigin: '0 0' } as const;

// ---------------------------------------------------------------- data

type NearbyShip = {
  name: string;
  ref: string;
  /**
   * Whether we know what this hull IS, on the same gate the helm chart uses: an
   * active scan, a received hail, a lock we are holding, or top-tier radar. When
   * it is off the server sends no name and no readout, `shields`, `integrity`
   * and `speed` are all zero and must not be drawn.
   */
  identified: BooleanLike;
  shields: number;
  shields_max: number;
  /** A real hull percent now, for ships and outposts both. */
  integrity: number;
  integrity_max: number;
  distance: number;
  speed: number;
  zone_type: number | null;
  zone_name: string;
  same_zone: BooleanLike;
  /** Overmap tiles, target minus us. East positive. */
  dx: number;
  /** Overmap tiles, target minus us. North positive. */
  dy: number;
  /** A raidable player outpost rather than a vessel. */
  is_outpost: BooleanLike;
};

type Launcher = {
  id: string;
  name: string;
  loaded: BooleanLike;
  missile_name: string | null;
  missile_damage: number | null;
  ready: BooleanLike;
  on_exterior: BooleanLike;
  enabled: BooleanLike;
};

type PodTube = {
  id: string;
  name: string;
  loaded: BooleanLike;
  pod_name: string | null;
  /** How many people are strapped into the loaded pod. */
  occupants: number;
  /** Hatch state: an open pod can be boarded but never fired. */
  sealed: BooleanLike;
  ready: BooleanLike;
  on_exterior: BooleanLike;
  enabled: BooleanLike;
};

type Turret = {
  id: string;
  name: string;
  power_level: number;
  damage: number;
  cooldown: number;
  power_per_shot: number;
  ready: BooleanLike;
  on_exterior: BooleanLike;
  cooldown_remaining: number;
  cell_charge: number;
  cell_max: number;
  upgrades: {
    capacitor_tier: number;
    laser_tier: number;
    servo_tier: number;
  };
};

type ShieldGenerator = {
  id: string;
  name: string;
  active: BooleanLike;
  /** What this generator adds to the ship's shared pool. The pool itself has
   * no per-generator health; see get_aggregated_shield_status(). */
  max_health_contribution: number;
  regen_contribution: number;
  upgrades: {
    capacitor_tier: number;
    laser_tier: number;
    servo_tier: number;
  };
};

type CloakDevice = {
  active: BooleanLike;
  can_activate: BooleanLike;
  duration_remaining: number;
  duration_max: number;
  cooldown_remaining: number;
  cooldown_max: number;
  upgrades: {
    capacitor_tier: number;
    laser_tier: number;
    scanning_tier: number;
  };
};

type EwChip = {
  ref: string;
  name: string;
  desc: string;
  tier: number;
  subsystem: string;
  charges: number;
  max_charges: number;
  ready: BooleanLike;
  cooldown_remaining: number;
  duration: number;
  modes: string[] | null;
};

type EwSuite = {
  signature: number;
  traced: BooleanLike;
  trace_remaining: number;
  executing: BooleanLike;
  executing_name: string | null;
  warmup_progress: number;
  power_draw: number;
  chips: EwChip[];
  upgrades: {
    capacitor_tier: number;
    laser_tier: number;
    servo_tier: number;
  };
};

type EwIntrusionPayload = {
  name: string;
  subsystem: string;
  remaining: number;
};

type EwIntrusion = {
  payloads: EwIntrusionPayload[];
  hardened: BooleanLike;
  hardened_remaining: number;
};

type Data = {
  connected: BooleanLike;
  ship_name: string | null;
  ship_class: string | null;
  ship_mass: number;
  /** OUR hull integrity percent, 0-100. */
  integrity: number;
  /** Hull below the 50% latch: weapons and drives dark. */
  ship_disabled: BooleanLike;
  /** Names of ships holding a completed weapons lock ON US. */
  locked_by: string[];
  /** Which side of the target our fire comes in from; null = auto. */
  approach_direction: string | null;
  ship_docked: BooleanLike;
  hidden_in_nebula: BooleanLike;
  cloak_active: BooleanLike;
  attack_mode: BooleanLike;
  is_in_attack_mode: BooleanLike;
  target_name: string | null;
  target_ref: string | null;
  // Targeting lock-in-progress data
  is_targeting: BooleanLike;
  targeting_ship_name: string | null;
  targeting_ship_ref: string | null;
  targeting_progress: number;
  targeting_time_remaining: number;
  nearby_ships: NearbyShip[];
  launchers: Launcher[];
  launchers_ready: number;
  launchers_total: number;
  // Assault pod tube data
  pod_tubes: PodTube[];
  pod_tubes_ready: number;
  pod_tubes_total: number;
  /** Target is holding a shield up. A pod launched into it kills its crew. */
  target_shields_up: BooleanLike;
  // Laser turret data
  turrets: Turret[];
  turrets_ready: number;
  turrets_total: number;
  turret_power_level: number;
  turret_power_available: number;
  turret_power_max: number;
  // Interdictor data
  interdictor_linked: BooleanLike;
  interdiction_active: BooleanLike;
  interdiction_warming_up: BooleanLike;
  interdiction_warmup_progress: number;
  interdictor_power_level: number;
  interdictor_power_draw: number;
  interdictor_target_name: string | null;
  interdictor_target_speed_cap: number | null;
  interdict_cooldown_active: BooleanLike;
  interdict_cooldown_remaining: number;
  interdictor_ready: BooleanLike;
  being_interdicted: BooleanLike;
  our_interdiction_strength: number;
  can_burst_shields: BooleanLike;
  burst_shield_cost: number;
  target_in_interdict_range: BooleanLike;
  target_in_missile_range: BooleanLike;
  // Shield data
  shield_linked: BooleanLike;
  shield_active: BooleanLike;
  shield_broken: BooleanLike;
  shield_health: number;
  shield_max_health: number;
  shield_overhealth: number;
  shield_power_allocation: number;
  shield_regen_rate: number;
  shield_power_draw: number;
  shield_efficiency: number;
  shield_cooldown_active: BooleanLike;
  shield_cooldown_remaining: number;
  shield_generators: ShieldGenerator[];
  // Cloak device
  cloak_device: CloakDevice | null;
  cloak_unlocked: BooleanLike;
  // Siphon data
  siphon_linked: BooleanLike;
  siphon_active: BooleanLike;
  siphon_warming_up: BooleanLike;
  siphon_warmup_progress: number;
  siphon_credits_stored: number;
  siphon_goal: number;
  siphon_goal_progress: number;
  siphon_target_name: string | null;
  siphon_target_credits: number;
  // Electronic warfare suite (attacker side)
  ew_linked: BooleanLike;
  ew: EwSuite | null;
  // Hostile intrusion on our own ship (target side), null when clean
  ew_intrusion: EwIntrusion | null;
  // Zone information
  zone_type: number | null;
  zone_name: string;
  zone_color: string;
  weapons_allowed: BooleanLike;
  interdiction_allowed: BooleanLike;
  // Zone transition
  zone_transitioning: BooleanLike;
  zone_transition_progress: number;
  zone_transition_remaining: number;
  zone_transition_target: string | null;
};

// ---------------------------------------------------------------- constants

// Palette twins of the SCSS values, for the SVG work and the inline colour
// bands. Colour carries meaning on this console: amber is the ship's own
// state, red is the target and the weapons pointed at it, ice is the world
// outside, non-target contacts, the scope grid, ranges and bearings.
const C_AMBER = '#f2a341';
const C_RED = '#e04836';
const C_ICE = '#74c8dd';
const C_ICE_DIM = '#3d6a76';
const C_STEEL = '#3a474b';
const C_LABEL = '#7d8f94';
const C_GOOD = '#59b871';
const C_WARN = '#d9a230';
const C_CRIT = '#cf4a38';
/** The cyan-green the helm uses for overhealth plate; shields borrow it. */
const C_OVER = '#3ecfa0';

/** Mirrors SIPHON_MINIMUM_TARGET_BALANCE - below this the siphon refuses to spin up. */
const SIPHON_MIN_TARGET_CREDITS = 50;

// Server-truth totals, for the progress bars that only receive a remainder.
// All from ship_combat defines; a snapshot plus a total is what makes a
// countdown drawable without the client running its own clock.
const INTERDICT_COOLDOWN_DS = 3000;
const SHIELD_REFORM_DS = 300;
const TRACE_LOCKOUT_S = 180;
/** Missile lock and interdiction both reach two tiles; sensors reach three. */
const LOCK_RANGE_TILES = 2;

const deciToSeconds = (ds: number) => Math.ceil(ds / 10);

const clamp = (value: number, low: number, high: number) =>
  Math.max(low, Math.min(high, value));

/**
 * Port of overmap_delta_to_compass(): the 0.4142 is tan(22.5°), which is what
 * splits the compass into eight even sectors. Same arithmetic as the helm's,
 * fed from dx/dy the server already sends.
 */
const bearingOf = (dx: number, dy: number) => {
  if (!dx && !dy) return '';
  let compass = '';
  if (Math.abs(dy) > Math.abs(dx) * 0.4142) compass += dy > 0 ? 'N' : 'S';
  if (Math.abs(dx) > Math.abs(dy) * 0.4142) compass += dx > 0 ? 'E' : 'W';
  return compass;
};

/** 75+ green, 61-74 amber, 51-60 red, 50 and under is the disabled latch. */
const hullColor = (value: number) => {
  if (value <= 50) return '#4a1410';
  if (value <= 60) return C_CRIT;
  if (value <= 74) return C_WARN;
  return C_GOOD;
};

/**
 * Why a contact can't be targeted, phrased for its tooltip. Reuses the old
 * console's wording: the rule is about zones, and the message says whose zone
 * is the problem.
 */
const zoneBlockReason = (
  ship: NearbyShip,
  ourZoneType: number | null,
  ourZoneName: string,
) => {
  if (ourZoneType === 0) return `You are in ${ourZoneName} - targeting disabled`;
  if (ship.zone_type === 0) {
    return `${ship.name} is in ${ship.zone_name} - cannot target`;
  }
  return `${ship.name} is in ${ship.zone_name}, different warfare zone`;
};

// ---------------------------------------------------------------- shared atoms

/**
 * A styled native range that commits on release rather than per pixel. React
 * refires `change` for every pixel of a drag, and one act() per pixel is one
 * BYOND Topic call per pixel. A single adjustment would spend hundreds of
 * them. The knob tracks local state; the server hears the stepped value once,
 * on pointer-up / key-up.
 */
const CommitRange = (props: {
  min: number;
  max: number;
  step: number;
  value: number;
  disabled?: boolean;
  label: string;
  title?: string;
  format?: (value: number) => string;
  onCommit: (value: number) => void;
}) => {
  const { min, max, step, value, disabled, label, title, format, onCommit } =
    props;
  const [drag, setDrag] = useState<number | null>(null);
  // Mirrors `drag` for the commit handlers. A pointer-up can land before the
  // re-render that would refresh their closure.
  const dragRef = useRef<number | null>(null);
  const shown = drag ?? value;

  // Hold the knob at the released value until the backend echoes something
  // back, clearing on commit snaps it to the stale value for the length of a
  // round trip, which reads as the console refusing the input. If the backend
  // never answers, it DID refuse, so stop lying about it.
  useEffect(() => {
    if (drag === null || dragRef.current !== null) return;
    if (value === drag) {
      setDrag(null);
      return;
    }
    const timer = setTimeout(() => setDrag(null), 1500);
    return () => clearTimeout(timer);
  }, [value, drag]);

  const commit = () => {
    const held = dragRef.current;
    if (held === null) return;
    dragRef.current = null;
    const stepped = clamp(Math.round(held / step) * step, min, max);
    setDrag(stepped);
    if (stepped !== value) onCommit(stepped);
  };

  return (
    <div className="Tac__sliderRow" title={title}>
      <input
        type="range"
        className="Tac__range"
        aria-label={label}
        min={min}
        max={max}
        step={step}
        value={shown}
        disabled={disabled}
        onChange={(event) => {
          const next = Number(event.currentTarget.value);
          dragRef.current = next;
          setDrag(next);
        }}
        onPointerUp={commit}
        onKeyUp={commit}
        onBlur={commit}
      />
      {format ? <span className="Tac__sliderVal">{format(shown)}</span> : null}
    </div>
  );
};

/**
 * Upgrade tier pips: filled squares up to the tier, hollow past it. The old
 * console drew these as ●○ text; squares in amber sit on the plate instead of
 * on a web page.
 */
const TierSquares = (props: { label: string; tier: number; max?: number }) => {
  const { label, tier, max = 4 } = props;
  const filled = clamp(Math.round(tier), 0, max);
  return (
    <span className="Tac__tiers" title={`${label} tier ${filled} of ${max}`}>
      <span className="Tac__tiersLabel">{label}</span>
      {Array.from({ length: max }, (_, i) => (
        <i key={i} className={`Tac__tier ${i < filled ? 'Tac--on' : ''}`} />
      ))}
    </span>
  );
};

// ---------------------------------------------------------------- root

export const ShipCombatConsole = () => {
  return (
    <Window width={1216} height={800}>
      <Window.Content fitted>
        <Faceplate />
      </Window.Content>
    </Window>
  );
};

const Faceplate = () => {
  const { data } = useBackend<Data>();
  const { connected } = data;

  return (
    <div className="Tac">
      <div
        className={`Tac__plate ${FACEPLATE_ASSET ? 'Tac__plate--art' : ''}`}
        style={
          FACEPLATE_ASSET
            ? { backgroundImage: `url("${resolveAsset(FACEPLATE_ASSET)}")` }
            : undefined
        }
      />
      {!FACEPLATE_ASSET && <div className="Tac__hazard" />}

      <Panel rect={GEOMETRY.IDENT}>
        <Ident />
      </Panel>
      <Panel rect={GEOMETRY.ZONE}>
        <ZoneBadge />
      </Panel>
      <Panel rect={GEOMETRY.ALERT}>
        <AlertStrip />
      </Panel>

      <Panel rect={GEOMETRY.SHIELD} label="Shields" aux="pool">
        <ShieldPanel />
      </Panel>
      <Panel rect={GEOMETRY.HULL} label="Hull" aux="integrity">
        <HullPanel />
      </Panel>
      <Panel rect={GEOMETRY.SIG} label="EW suite" aux="signature">
        <SigPanel />
      </Panel>
      <Panel rect={GEOMETRY.CLOAK} label="Cloak" aux="device">
        <CloakPanel />
      </Panel>
      <Panel rect={GEOMETRY.SIPHON} label="Siphon" aux="data tap">
        <SiphonPanel />
      </Panel>

      <Panel rect={GEOMETRY.SCOPE} label="Tactical scope">
        <Scope />
      </Panel>
      <Panel rect={GEOMETRY.DRAWER} label="Registry">
        <Drawer />
      </Panel>

      <Panel rect={GEOMETRY.TUBES} label="Ordnance tubes">
        <TubesPanel />
      </Panel>
      <Panel rect={GEOMETRY.LASERS} label="Laser battery">
        <LasersPanel />
      </Panel>
      <Panel rect={GEOMETRY.INTERDICT} label="Interdiction field">
        <InterdictPanel />
      </Panel>
      <Panel rect={GEOMETRY.OPS} label="Operations">
        <OpsPanel />
      </Panel>

      {!connected && <NotConnectedOverlay />}
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
    <div className="Tac__panel" style={panelStyle(rect)}>
      <div className={`Tac__well ${label ? 'Tac__well--labelled' : ''}`}>
        {!!label && (
          <div className="Tac__wellLabel">
            {label}
            {!!aux && <span className="Tac__wellAux">/ {aux}</span>}
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
  const { ship_name, ship_class, ship_mass } = data;

  return (
    <div className="Tac__ident">
      {/*
        A plain ellipsis rather than the helm's fit-to-width machinery: the
        name isn't editable from this console, so a long one truncating is an
        acceptable cost for not carrying sixty lines of measurement code.
      */}
      <span className="Tac__shipName" title={ship_name ?? undefined}>
        {ship_name}
      </span>
      <span className="Tac__shipClass">
        {ship_class ?? 'Unclassified'}
        {!!ship_mass && ` · ${ship_mass}t`}
      </span>
      <span className="Tac__tag">Tactical</span>
    </div>
  );
};

const ZoneBadge = () => {
  const { data } = useBackend<Data>();
  const { zone_name, zone_color, weapons_allowed, interdiction_allowed } = data;

  return (
    <div className="Tac__zone">
      <i
        className="Tac__zoneDot"
        style={{ background: zone_color, color: zone_color }}
      />
      <span className="Tac__zoneName" style={{ color: zone_color }}>
        {zone_name || 'Unknown zone'}
      </span>
      <span className="Tac__zoneFlags">
        <span
          className={`Tac__flag ${weapons_allowed ? 'Tac--on' : 'Tac--off'}`}
          title={
            weapons_allowed
              ? 'Ship weapons are live here'
              : 'Ship weapons are disabled here'
          }
        >
          Weap
        </span>
        <span
          className={`Tac__flag ${interdiction_allowed ? 'Tac--on' : 'Tac--off'}`}
          title={
            interdiction_allowed
              ? 'Interdiction and boarding are permitted here'
              : 'Interdiction is prohibited here'
          }
        >
          Intd
        </span>
      </span>
    </div>
  );
};

/**
 * Only conditions that are true right now, ranked critical first. Anything the
 * crew can't act on stays out. This rail is for things that change what you
 * do in the next few seconds.
 */
const AlertStrip = () => {
  const { data } = useBackend<Data>();
  const alerts: [string, string][] = [];

  const payloads = data.ew_intrusion?.payloads?.length ?? 0;
  const locks = data.locked_by?.length ?? 0;

  if (!data.weapons_allowed) {
    alerts.push(['crit', `Weapons disabled in ${data.zone_name}`]);
  }
  if (data.being_interdicted) {
    alerts.push([
      'crit',
      `Interdicted, engines at ${100 - (data.our_interdiction_strength || 0)}%`,
    ]);
  }
  if (payloads > 0) {
    alerts.push([
      'crit',
      `Hostile intrusion, ${payloads} payload${payloads === 1 ? '' : 's'}`,
    ]);
  }
  if (data.ew?.traced) {
    alerts.push(['crit', `Suite traced, ${Math.ceil(data.ew.trace_remaining)}s`]);
  }
  if (locks > 0) {
    alerts.push([
      'crit',
      `${locks} hostile weapons lock${locks === 1 ? '' : 's'}`,
    ]);
  }
  if (data.zone_transitioning) {
    alerts.push([
      'warn',
      `Entering ${data.zone_transition_target ?? 'new zone'}, ${data.zone_transition_remaining}s`,
    ]);
  }
  if (data.is_targeting) {
    alerts.push(['warn', `Acquiring ${data.targeting_ship_name ?? 'contact'}`]);
  }
  if (data.cloak_active) {
    alerts.push([
      'info',
      `Cloak active, ${Math.ceil(data.cloak_device?.duration_remaining ?? 0)}s`,
    ]);
  }
  if (data.siphon_active) {
    alerts.push(['info', `Siphoning ${data.siphon_target_name ?? 'target'}`]);
  }
  if (data.hidden_in_nebula) {
    alerts.push(['info', 'Concealed in nebula']);
  }
  if (data.is_in_attack_mode) {
    alerts.push(['info', 'Targeting camera live']);
  }

  return (
    <div className="Tac__alerts">
      {alerts.length ? (
        alerts.map(([severity, text]) => (
          <span key={text} className={`Tac__alert Tac--${severity}`}>
            {text}
          </span>
        ))
      ) : (
        <span className="Tac__quiet">Weapons safe · no contacts engaged</span>
      )}
    </div>
  );
};

// ---------------------------------------------------------------- left stack

const ShieldPanel = () => {
  const { act, data } = useBackend<Data>();
  const {
    ship_docked,
    shield_linked,
    shield_broken,
    shield_health,
    shield_max_health,
    shield_overhealth,
    shield_power_allocation,
    shield_regen_rate,
    shield_power_draw,
    shield_cooldown_active,
    shield_cooldown_remaining,
    shield_generators = [],
  } = data;

  if (!shield_linked) {
    return (
      <div className="Tac__pad">
        <div className="Tac__quiet">No generators fitted</div>
      </div>
    );
  }

  if (ship_docked) {
    return (
      <div className="Tac__pad">
        <div className="Tac__quiet">Safed while docked</div>
      </div>
    );
  }

  if (shield_broken && shield_cooldown_active) {
    const remaining = shield_cooldown_remaining || 0;
    return (
      <div className="Tac__pad">
        <div className="Tac__stateLine" style={{ color: C_CRIT }}>
          REFORMING {deciToSeconds(remaining)}s
        </div>
        <div className="Tac__bar" style={{ marginTop: '0.4cqw' }}>
          <i
            style={{
              width: `${clamp((1 - remaining / SHIELD_REFORM_DS) * 100, 0, 100)}%`,
              background: C_CRIT,
            }}
          />
          <span className="Tac__ticks" />
        </div>
      </div>
    );
  }

  const pct = shield_max_health
    ? Math.round((shield_health / shield_max_health) * 100)
    : 0;
  const overWidth = shield_max_health
    ? clamp((shield_overhealth / shield_max_health) * 100, 0, 100)
    : 0;
  const powerPercent = Math.round((shield_power_allocation ?? 1) * 100);

  return (
    <div className="Tac__pad">
      <div className="Tac__bigRow">
        <span className="Tac__bigNum" style={{ color: C_AMBER }}>
          {pct}
        </span>
        <span className="Tac__bigUnit">%</span>
        {shield_overhealth > 0 && (
          <span className="Tac__bigState" style={{ color: C_OVER }}>
            +{Math.round(shield_overhealth)} over
          </span>
        )}
        {/* One lamp per generator. Which one is dark matters more than how
            many there are, so they are lamps rather than a count. */}
        <span className="Tac__leds">
          {shield_generators.map((gen) => (
            <i
              key={gen.id}
              className={`Tac__led ${gen.active ? 'Tac--on' : ''}`}
              title={`${gen.name}, ${gen.active ? 'active' : 'offline'}`}
            />
          ))}
        </span>
      </div>
      <div className="Tac__bar">
        <i style={{ width: `${clamp(pct, 0, 100)}%`, background: C_AMBER }} />
        {shield_overhealth > 0 && (
          <i
            style={{
              left: `${clamp(pct, 0, 100)}%`,
              width: `${overWidth}%`,
              background: '#1d6b3a',
            }}
          />
        )}
        <span className="Tac__ticks" />
      </div>
      <div className="Tac__metric" style={{ marginTop: '0.35cqw' }}>
        <span className="Tac__k">Regen</span>
        <span className="Tac__v">+{shield_regen_rate || 0}/s</span>
        <span className="Tac__k">Draw</span>
        <span className="Tac__v">{shield_power_draw || 0}W</span>
      </div>
      <CommitRange
        min={0}
        max={200}
        step={10}
        value={powerPercent}
        label="Shield power allocation"
        title="Regeneration allocation. Past 100% the pool banks overhealth."
        format={(v) => `${v}%`}
        onCommit={(v) => act('set_shield_power', { power: v })}
      />
    </div>
  );
};

const HullPanel = () => {
  const { data } = useBackend<Data>();
  const { integrity, ship_disabled } = data;
  const colour = hullColor(integrity);

  return (
    <div className="Tac__pad">
      <div className="Tac__bigRow">
        <span className="Tac__bigNum" style={{ color: colour }}>
          {integrity}
        </span>
        <span className="Tac__bigUnit">%</span>
        <span
          className="Tac__bigState"
          style={{ color: ship_disabled ? C_CRIT : C_LABEL }}
        >
          {ship_disabled ? 'Disabled' : 'Nominal'}
        </span>
      </div>
      <div className="Tac__bar Tac__hullBar">
        <i
          style={{ width: `${clamp(integrity, 0, 100)}%`, background: colour }}
        />
        <span className="Tac__disabledMark" title="Systems fail below 50%" />
        <span className="Tac__ticks" />
      </div>
    </div>
  );
};

const SigPanel = () => {
  const { act, data } = useBackend<Data>();
  const { ew_linked, ew } = data;

  if (!ew_linked || !ew) {
    return (
      <div className="Tac__pad">
        <div className="Tac__quiet">No EW suite</div>
      </div>
    );
  }

  const {
    signature,
    traced,
    trace_remaining,
    executing,
    executing_name,
    warmup_progress,
    power_draw,
  } = ew;
  const ratio = clamp((signature || 0) / 100, 0, 1);
  const sigColour = ratio >= 0.75 ? C_CRIT : ratio >= 0.5 ? C_WARN : C_GOOD;

  return (
    <div className="Tac__pad">
      <div className="Tac__metric">
        <span className="Tac__k">Signature</span>
        {!traced && ratio >= 0.75 && (
          <span className="Tac__flash">TRACE IMMINENT</span>
        )}
        <span className="Tac__v" style={{ color: sigColour }}>
          {Math.round(signature || 0)}/100
        </span>
      </div>
      <div className="Tac__bar" style={{ marginTop: '0.3cqw' }}>
        <i style={{ width: `${ratio * 100}%`, background: sigColour }} />
        <span className="Tac__ticks" />
      </div>

      {!!traced && (
        <>
          <div
            className="Tac__stateLine"
            style={{ color: C_CRIT, marginTop: '0.45cqw' }}
          >
            TRACED {Math.ceil(trace_remaining || 0)}s
          </div>
          <div className="Tac__bar Tac__bar--thin">
            <i
              style={{
                width: `${clamp((1 - (trace_remaining || 0) / TRACE_LOCKOUT_S) * 100, 0, 100)}%`,
                background: C_CRIT,
              }}
            />
          </div>
        </>
      )}

      {!traced && !!executing && (
        <div className="Tac__execRow">
          <div className="Tac__execLine">
            <span className="Tac__execName" title={executing_name ?? undefined}>
              Running: {executing_name}
            </span>
            <button
              type="button"
              className="Tac__btn Tac--danger"
              title="Abort the running exploit"
              onClick={() => act('ew_cancel')}
            >
              Abort
            </button>
          </div>
          <div className="Tac__bar Tac__bar--thin">
            <i
              style={{
                width: `${clamp(warmup_progress || 0, 0, 100)}%`,
                background: C_WARN,
              }}
            />
          </div>
        </div>
      )}

      <div className="Tac__metric" style={{ marginTop: 'auto' }}>
        <span className="Tac__k">Draw</span>
        <span className="Tac__v">{power_draw || 0}W</span>
      </div>
    </div>
  );
};

const CloakPanel = () => {
  const { act, data } = useBackend<Data>();
  const { cloak_device } = data;

  if (!cloak_device) {
    return (
      <div className="Tac__pad">
        <div className="Tac__quiet">No cloak fitted</div>
      </div>
    );
  }

  const {
    active,
    can_activate,
    duration_remaining,
    duration_max,
    cooldown_remaining,
    cooldown_max,
    upgrades,
  } = cloak_device;

  return (
    <div className="Tac__pad">
      {active ? (
        <>
          <div className="Tac__stateLine" style={{ color: C_ICE }}>
            ACTIVE {Math.ceil(duration_remaining)}s
          </div>
          <div className="Tac__bar" style={{ marginTop: '0.35cqw' }}>
            <i
              style={{
                width: `${duration_max > 0 ? clamp((duration_remaining / duration_max) * 100, 0, 100) : 0}%`,
                background: C_ICE,
              }}
            />
            <span className="Tac__ticks" />
          </div>
          <button
            type="button"
            className="Tac__btn Tac__wideBtn"
            title="Drop the cloak and become visible again"
            onClick={() => act('cloak_deactivate')}
          >
            Decloak
          </button>
        </>
      ) : cooldown_remaining > 0 ? (
        <>
          <div className="Tac__stateLine" style={{ color: C_WARN }}>
            RECHARGE {Math.ceil(cooldown_remaining)}s
          </div>
          <div className="Tac__bar" style={{ marginTop: '0.35cqw' }}>
            <i
              style={{
                width: `${cooldown_max > 0 ? clamp((1 - cooldown_remaining / cooldown_max) * 100, 0, 100) : 0}%`,
                background: C_WARN,
              }}
            />
            <span className="Tac__ticks" />
          </div>
        </>
      ) : (
        <>
          <div className="Tac__metric">
            <span className="Tac__k">Field time</span>
            <span className="Tac__v">{Math.ceil(duration_max)}s</span>
          </div>
          <button
            type="button"
            className="Tac__btn Tac__wideBtn"
            disabled={!can_activate}
            title={
              can_activate
                ? 'Hide the ship from hostile sensors'
                : 'The cloak cannot engage right now'
            }
            onClick={() => act('cloak_activate')}
          >
            Cloak
          </button>
        </>
      )}
      <div className="Tac__tierRow">
        <TierSquares label="Cap" tier={upgrades?.capacitor_tier || 0} />
        <TierSquares label="Las" tier={upgrades?.laser_tier || 0} />
        <TierSquares label="Scan" tier={upgrades?.scanning_tier || 0} />
      </div>
    </div>
  );
};

const SiphonPanel = () => {
  const { act, data } = useBackend<Data>();
  const {
    target_ref,
    siphon_linked,
    siphon_active,
    siphon_warming_up,
    siphon_warmup_progress,
    siphon_credits_stored,
    siphon_goal,
    siphon_goal_progress,
    siphon_target_name,
    siphon_target_credits,
  } = data;

  if (!siphon_linked) {
    return (
      <div className="Tac__pad">
        <div className="Tac__quiet">No siphon</div>
      </div>
    );
  }

  if (siphon_warming_up) {
    return (
      <div className="Tac__pad">
        <div className="Tac__stateLine" style={{ color: C_WARN }}>
          CALIBRATING
        </div>
        <div className="Tac__bar" style={{ marginTop: '0.35cqw' }}>
          <i
            style={{
              width: `${clamp(siphon_warmup_progress || 0, 0, 100)}%`,
              background: C_WARN,
            }}
          />
          <span className="Tac__ticks" />
        </div>
        <button
          type="button"
          className="Tac__btn Tac__wideBtn"
          title="Abort the siphon calibration"
          onClick={() => act('siphon_deactivate')}
        >
          Cancel
        </button>
      </div>
    );
  }

  if (siphon_active) {
    return (
      <div className="Tac__pad">
        <div
          className="Tac__stateLine"
          style={{ color: C_RED }}
          title={siphon_target_name ?? undefined}
        >
          SIPHONING {(siphon_target_name ?? '').toUpperCase()}
        </div>
        <div className="Tac__bar" style={{ marginTop: '0.35cqw' }}>
          <i
            style={{
              width: `${clamp(siphon_goal_progress || 0, 0, 100)}%`,
              background: C_RED,
            }}
          />
          <span className="Tac__ticks" />
        </div>
        {siphon_goal > 0 && (
          <div className="Tac__metric" style={{ marginTop: '0.3cqw' }}>
            <span className="Tac__k">Haul</span>
            <span className="Tac__v">
              {siphon_credits_stored}/{siphon_goal} cr
            </span>
          </div>
        )}
        <button
          type="button"
          className="Tac__btn Tac__wideBtn Tac--danger"
          title="Cut the tap. Anything already stored stays aboard the device."
          onClick={() => act('siphon_deactivate')}
        >
          Stop
        </button>
      </div>
    );
  }

  const targetHasFunds = siphon_target_credits >= SIPHON_MIN_TARGET_CREDITS;

  return (
    <div className="Tac__pad">
      {siphon_credits_stored > 0 && (
        <div className="Tac__note" style={{ color: C_GOOD }}>
          {siphon_credits_stored} cr aboard, collect at device
        </div>
      )}
      {!!target_ref && (
        <div
          className="Tac__note"
          style={{ color: targetHasFunds ? C_GOOD : C_LABEL }}
        >
          {targetHasFunds
            ? `Target holds ${siphon_target_credits} cr`
            : 'Target accounts empty'}
        </div>
      )}
      <button
        type="button"
        className="Tac__btn Tac__wideBtn"
        style={{ marginTop: 'auto' }}
        disabled={!target_ref || !targetHasFunds}
        title={
          !target_ref
            ? 'Requires a target lock'
            : targetHasFunds
              ? 'Tap the locked target and drain its accounts'
              : 'Nothing left in the target to take'
        }
        onClick={() => act('siphon_activate')}
      >
        Siphon
      </button>
    </div>
  );
};

// ---------------------------------------------------------------- scope

/** Scope design units. The viewBox matches the well 1:1. */
const SCOPE = { w: 652, h: 532, cx: 326, cy: 266 } as const;

/** Design units per overmap tile. Three tiles of sensor range fill the rings. */
const TILE = 72;

/**
 * The fan-out for stacked contacts: golden-angle by index, so any number of
 * ships parked on one tile spread into a ring that never repeats an angle,
 * and the same list always fans the same way.
 */
const GOLDEN_ANGLE = 137.508;
const FAN_RADIUS = 18;

type ScopeMark = { ship: NearbyShip; x: number; y: number };

/**
 * Where each contact is drawn. dx/dy are whole overmap tiles, so contacts
 * sharing a tile land on the same point, and anything on OUR tile lands on
 * our own token. Both get fanned onto a small deterministic orbit so every
 * mark stays clickable.
 */
const layoutMarks = (ships: NearbyShip[]): ScopeMark[] => {
  const groups = new Map<string, NearbyShip[]>();
  for (const ship of ships) {
    const key = `${ship.dx},${ship.dy}`;
    const held = groups.get(key);
    if (held) held.push(ship);
    else groups.set(key, [ship]);
  }

  const marks: ScopeMark[] = [];
  for (const members of [...groups.values()]) {
    members.forEach((ship, index) => {
      let x = SCOPE.cx + ship.dx * TILE;
      let y = SCOPE.cy - ship.dy * TILE;
      // A lone contact on our own tile still needs the orbit, dead centre it
      // sits under the ship token and can't be told apart or clicked.
      if (members.length > 1 || (!ship.dx && !ship.dy)) {
        const angle = (index * GOLDEN_ANGLE * Math.PI) / 180;
        x += FAN_RADIUS * Math.cos(angle);
        y += FAN_RADIUS * Math.sin(angle);
      }
      marks.push({ ship, x, y });
    });
  }
  return marks;
};

const Scope = () => {
  const { data } = useBackend<Data>();
  const {
    ship_docked,
    hidden_in_nebula,
    weapons_allowed,
    zone_name,
    nearby_ships = [],
    is_targeting,
  } = data;

  const marks = useMemo(() => layoutMarks(nearby_ships), [nearby_ships]);
  // Docked or concealed, the scope goes dark: grid stays as dressing, marks
  // and controls go. A disabled-weapons zone is different, you can still
  // watch, you just can't shoot, so everything stays and a banner says why.
  const dormant = !!ship_docked || !!hidden_in_nebula;

  return (
    <div className={`Tac__scope ${is_targeting ? 'Tac--acquiring' : ''}`}>
      <svg
        viewBox={`0 0 ${SCOPE.w} ${SCOPE.h}`}
        preserveAspectRatio="xMidYMid meet"
        role="img"
        aria-label="Tactical scope"
      >
        <ScopeBackdrop dimmed={dormant} />
        {!dormant && <ScopeSweep />}
        {!dormant && <OwnShipToken />}
        {!dormant &&
          marks.map((mark) => <ScopeContact key={mark.ship.ref} mark={mark} />)}
      </svg>

      {!dormant && !weapons_allowed && (
        <div className="Tac__scopeBanner">
          WEAPONS DISABLED IN {zone_name.toUpperCase()}
        </div>
      )}

      {!!ship_docked && (
        <div className="Tac__scopeMsg">DOCKED, TACTICAL SYSTEMS SAFED</div>
      )}
      {!ship_docked && !!hidden_in_nebula && (
        <div className="Tac__scopeMsg Tac--ice">CONCEALED, EMISSIONS COLD</div>
      )}
      {!dormant && marks.length === 0 && (
        <div className="Tac__scopeMsg Tac--quiet">
          NO CONTACTS IN SENSOR RANGE
        </div>
      )}

      {!dormant && <ApproachCluster />}
    </div>
  );
};

const RING_LABEL_ANGLE = Math.PI / 4;

const ScopeBackdrop = (props: { dimmed: boolean }) => {
  const { dimmed } = props;
  const { cx, cy, w, h } = SCOPE;

  return (
    <g opacity={dimmed ? 0.3 : 1} pointerEvents="none">
      {/* The grid cross. Faint on purpose: it is orientation, not data. */}
      <g stroke={C_ICE} strokeOpacity={0.07} strokeWidth={1}>
        <line x1={0} y1={cy} x2={w} y2={cy} />
        <line x1={cx} y1={0} x2={cx} y2={h} />
      </g>

      {[1, 2, 3].map((tiles) => {
        const r = tiles * TILE;
        const labelX = cx + r * Math.cos(RING_LABEL_ANGLE) + 4;
        const labelY = cy - r * Math.sin(RING_LABEL_ANGLE) - 4;
        const matters = tiles === LOCK_RANGE_TILES;
        return (
          <g key={tiles}>
            <circle
              cx={cx}
              cy={cy}
              r={r}
              fill="none"
              stroke={C_ICE_DIM}
              strokeOpacity={0.45}
              strokeWidth={1}
            />
            {/*
              Ring 2 is the one that matters, missile lock and interdiction
              both reach exactly this far, so it alone gets a second, brighter
              dashed stroke and a caption. The others are just distance.
            */}
            {!!matters && (
              <circle
                cx={cx}
                cy={cy}
                r={r}
                fill="none"
                stroke={C_ICE}
                strokeOpacity={0.35}
                strokeWidth={1.2}
                strokeDasharray="6 5"
              />
            )}
            <text
              x={labelX}
              y={labelY}
              fill={matters ? C_ICE : C_ICE_DIM}
              fillOpacity={matters ? 0.7 : 0.6}
              fontSize={9}
              fontFamily="ui-monospace, monospace"
            >
              {tiles}
            </text>
            {!!matters && (
              <text
                x={labelX + 10}
                y={labelY}
                fill={C_ICE}
                fillOpacity={0.55}
                fontSize={8}
                fontFamily="ui-monospace, monospace"
                letterSpacing={1}
              >
                LOCK/INTD
              </text>
            )}
          </g>
        );
      })}
    </g>
  );
};

/**
 * The radar sweep: a wedge turning once every six seconds. Pure dressing, it
 * reports nothing, so it sits behind everything, takes no clicks, and
 * reduced-motion removes it entirely (see the SCSS).
 */
const ScopeSweep = () => {
  const r = 3 * TILE;
  const rad = Math.PI / 6; // a 30° wedge
  return (
    <g
      transform={`translate(${SCOPE.cx}, ${SCOPE.cy})`}
      pointerEvents="none"
      aria-hidden="true"
    >
      <g className="Tac__sweep" style={SVG_ORIGIN}>
        <path
          d={`M0,0 L${r},0 A${r},${r} 0 0,1 ${(r * Math.cos(rad)).toFixed(1)},${(r * Math.sin(rad)).toFixed(1)} Z`}
          fill={C_ICE}
          fillOpacity={0.045}
        />
        <line
          x1={0}
          y1={0}
          x2={r}
          y2={0}
          stroke={C_ICE}
          strokeOpacity={0.14}
          strokeWidth={1}
        />
      </g>
    </g>
  );
};

/**
 * Our own hull, dead centre. Glyph only, the ident rail carries the name,
 * and a label here would sit on top of whatever is fanned around the origin.
 */
const OwnShipToken = () => (
  <g
    transform={`translate(${SCOPE.cx}, ${SCOPE.cy})`}
    pointerEvents="none"
    aria-hidden="true"
  >
    <circle r={12} fill={C_AMBER} fillOpacity={0.08} />
    <path d="M0,-8 L6,7 L0,3.5 L-6,7 Z" fill={C_AMBER} />
  </g>
);

/** Corner brackets for the locked target, drawn around the glyph. */
const TARGET_BRACKETS =
  'M-14,-8 V-14 H-8 M8,-14 H14 V-8 M14,8 V14 H8 M-8,14 H-14 V8';

const ScopeContact = (props: { mark: ScopeMark }) => {
  const { act, data } = useBackend<Data>();
  const {
    target_ref,
    is_targeting,
    targeting_ship_ref,
    targeting_progress,
    targeting_time_remaining,
    zone_type,
    zone_name,
  } = data;
  const { ship, x, y } = props.mark;

  const isTarget = !!target_ref && ship.ref === target_ref;
  const acquiring = !!is_targeting && ship.ref === targeting_ship_ref;
  const targetable = !!ship.same_zone;
  const colour = isTarget ? C_RED : targetable ? C_ICE : C_STEEL;

  // Positions arrive once per server tick as whole-tile jumps; the CSS
  // transition on .Tac__mark glides each jump over ~half a second instead of
  // teleporting. New contacts must NOT glide, a mark transitioning from the
  // default identity transform flies in from the scope's corner, so the
  // transition switches on one frame after mount, when the transform is
  // already correct.
  const [settled, setSettled] = useState(false);
  useEffect(() => {
    setSettled(true);
  }, []);

  // "unknown contact" is the chart's wording and too long for a glyph label, so
  // an anonymous return gets the short form rather than a truncation.
  const name = !ship.identified
    ? 'UNKNOWN'
    : ship.name.length > 14
      ? `${ship.name.slice(0, 13)}…`
      : ship.name;
  const shieldFrac =
    ship.shields_max > 0 ? clamp(ship.shields / ship.shields_max, 0, 1) : 0;
  const hullFrac = clamp((ship.integrity || 0) / 100, 0, 1);

  const tooltip = !targetable
    ? zoneBlockReason(ship, zone_type, zone_name)
    : isTarget
      ? `${ship.name}, locked. Click to release.`
      : `${ship.name}, click to acquire a lock`;

  return (
    <g
      className={`Tac__mark ${targetable ? '' : 'Tac--dead'}`}
      style={{
        ...SVG_ORIGIN,
        transform: `translate(${x}px, ${y}px)`,
        transition: settled ? undefined : 'none',
      }}
      onClick={() => {
        if (!targetable) return;
        if (isTarget) act('clear_target');
        else act('select_target', { ref: ship.ref });
      }}
    >
      <title>{tooltip}</title>
      {/* Invisible hit area, the glyphs are a punishing click target bare. */}
      <circle r={15} fill="transparent" />

      {ship.is_outpost ? (
        // An outpost holds still and holds ground: a hollow diamond, nothing
        // like the pointer a vessel gets.
        <path
          d="M0,-7 L7,0 L0,7 L-7,0 Z"
          fill="none"
          stroke={colour}
          strokeWidth={1.6}
        />
      ) : (
        <path
          d="M0,-7 L6,6 L0,2.5 L-6,6 Z"
          fill="none"
          stroke={colour}
          strokeWidth={1.6}
        />
      )}

      <text
        y={17}
        textAnchor="middle"
        fill={colour}
        fontSize={9.5}
        fontFamily="ui-monospace, monospace"
      >
        {name.toUpperCase()}
      </text>
      <text
        y={26}
        textAnchor="middle"
        fill={colour}
        fillOpacity={0.65}
        fontSize={8}
        fontFamily="ui-monospace, monospace"
      >
        {ship.distance}
        {!!ship.identified && ` · ${ship.speed} spM`}
      </text>

      {!!isTarget && (
        <g className="Tac__brackets" pointerEvents="none">
          <path
            d={TARGET_BRACKETS}
            fill="none"
            stroke={C_RED}
            strokeWidth={1.6}
          />
          {/* The dossier in miniature: shields over hull, 24px wide, under the
              label. Enough to watch a volley land without leaving the scope. */}
          <g transform="translate(-12, 30)">
            <rect width={24} height={2.4} fill="#0b1112" stroke="#000" strokeWidth={0.5} />
            <rect width={24 * shieldFrac} height={2.4} fill={C_ICE} />
            <g transform="translate(0, 4)">
              <rect width={24} height={2.4} fill="#0b1112" stroke="#000" strokeWidth={0.5} />
              <rect
                width={24 * hullFrac}
                height={2.4}
                fill={hullColor(ship.integrity || 0)}
              />
            </g>
          </g>
        </g>
      )}

      {!!acquiring && (
        <g pointerEvents="none">
          {/*
            The closing ring: a dashed circle whose gap shrinks with
            targeting_progress. Driven by dashoffset rather than a CSS
            animation so it tracks the server's own clock. The server is the
            one deciding when the lock lands.
          */}
          <circle
            r={20}
            fill="none"
            stroke={C_AMBER}
            strokeWidth={1.6}
            strokeDasharray={2 * Math.PI * 20}
            strokeDashoffset={
              2 * Math.PI * 20 * (1 - clamp(targeting_progress || 0, 0, 100) / 100)
            }
            transform="rotate(-90)"
          />
          <circle
            r={20}
            fill="none"
            stroke={C_AMBER}
            strokeOpacity={0.25}
            strokeWidth={1}
            strokeDasharray="2 3"
          />
          <text
            y={-25}
            textAnchor="middle"
            fill={C_AMBER}
            fontSize={9}
            fontFamily="ui-monospace, monospace"
          >
            {(targeting_time_remaining || 0).toFixed(1)}s
          </text>
        </g>
      )}
    </g>
  );
};

const APPROACH_DIRS = [
  ['auto', 'AUTO'],
  ['north', 'N'],
  ['east', 'E'],
  ['south', 'S'],
  ['west', 'W'],
] as const;

const ApproachCluster = () => {
  const { act, data } = useBackend<Data>();
  const { approach_direction } = data;
  const current = approach_direction ?? 'auto';

  return (
    <div
      className="Tac__approach"
      title="Which side of the target your missiles and laser fire come in from."
    >
      <span className="Tac__approachLabel">approach vector</span>
      {APPROACH_DIRS.map(([dir, label]) => (
        <button
          key={dir}
          type="button"
          className={`Tac__approachBtn ${current === dir ? 'Tac--on' : ''}`}
          onClick={() => act('set_approach_direction', { dir })}
        >
          {label}
        </button>
      ))}
    </div>
  );
};

// ---------------------------------------------------------------- drawer

const TABS = ['Contacts', 'Exploits', 'Defense', 'Systems'] as const;
type Tab = (typeof TABS)[number];

const Drawer = () => {
  const { data } = useBackend<Data>();
  const { nearby_ships = [], ew, ew_intrusion, locked_by = [] } = data;
  const [tab, setTab] = useState<Tab>('Contacts');

  const contacts = nearby_ships.length;
  const readyChips = (ew?.chips ?? []).filter((chip) => !!chip.ready).length;
  // Everything currently aimed at us: live payloads plus completed locks.
  // Red, because it is the one badge that means someone else is winning.
  const threats = (ew_intrusion?.payloads?.length ?? 0) + locked_by.length;

  return (
    <div className="Tac__drawerWrap">
      <div className="Tac__tabs">
        {TABS.map((name) => (
          <button
            key={name}
            type="button"
            className={`Tac__tab ${tab === name ? 'Tac--on' : ''}`}
            onClick={() => setTab(name)}
          >
            {name}
            {name === 'Contacts' && contacts > 0 && (
              <span className="Tac__badge">{contacts}</span>
            )}
            {name === 'Exploits' && readyChips > 0 && (
              <span className="Tac__badge">{readyChips}</span>
            )}
            {name === 'Defense' && threats > 0 && (
              <span className="Tac__badge Tac__badge--red">{threats}</span>
            )}
          </button>
        ))}
      </div>
      <div className="Tac__drawerBody">
        {tab === 'Contacts' && <ContactsTab />}
        {tab === 'Exploits' && <ExploitsTab />}
        {tab === 'Defense' && <DefenseTab />}
        {tab === 'Systems' && <SystemsTab />}
      </div>
    </div>
  );
};

// ---------------------------------------------------------------- drawer · contacts

const ContactsTab = () => {
  const { act, data } = useBackend<Data>();
  const {
    nearby_ships = [],
    target_name,
    target_ref,
    target_in_missile_range,
    target_in_interdict_range,
    is_targeting,
    targeting_ship_name,
    targeting_progress,
    zone_type,
    zone_name,
  } = data;

  const target = target_ref
    ? nearby_ships.find((ship) => ship.ref === target_ref)
    : undefined;
  const others = nearby_ships.filter((ship) => ship.ref !== target_ref);

  return (
    <>
      {!!is_targeting && (
        <div className="Tac__acqBanner">
          <div className="Tac__acqLine">
            <span>Acquiring {targeting_ship_name}</span>
            <button
              type="button"
              className="Tac__btn"
              title="Break off the lock attempt"
              onClick={() => act('cancel_targeting')}
            >
              Cancel
            </button>
          </div>
          <div className="Tac__bar Tac__bar--thin">
            <i
              style={{
                width: `${clamp(targeting_progress || 0, 0, 100)}%`,
                background: C_AMBER,
              }}
            />
          </div>
        </div>
      )}

      {!!target_name && !!target && (
        <div className="Tac__dossier">
          <div className="Tac__dossierHead">
            <span className="Tac__dossierName" title={target.name}>
              {target.name}
            </span>
            <button
              type="button"
              className="Tac__btn"
              title="Release the weapons lock"
              onClick={() => act('clear_target')}
            >
              Release lock
            </button>
          </div>

          <div className="Tac__dossierRow">
            <span className="Tac__k">Shields</span>
            <span className="Tac__v" style={{ color: C_ICE }}>
              {Math.round(target.shields)}/{target.shields_max}
            </span>
          </div>
          <div className="Tac__bar Tac__bar--thin">
            <i
              style={{
                width: `${target.shields_max > 0 ? clamp((target.shields / target.shields_max) * 100, 0, 100) : 0}%`,
                background: C_ICE,
              }}
            />
          </div>

          <div className="Tac__dossierRow">
            <span className="Tac__k">Hull</span>
            <span
              className="Tac__v"
              style={{ color: hullColor(target.integrity || 0) }}
            >
              {Math.round(target.integrity)}%
            </span>
          </div>
          <div className="Tac__bar Tac__bar--thin">
            <i
              style={{
                width: `${clamp(target.integrity || 0, 0, 100)}%`,
                background: hullColor(target.integrity || 0),
              }}
            />
          </div>

          <div className="Tac__dossierMeta">
            {target.distance} tiles · {target.speed} spM · {target.zone_name}
          </div>
          <div className="Tac__rangeChips">
            <span
              className={`Tac__chip ${target_in_missile_range ? 'Tac--on' : ''}`}
              title={
                target_in_missile_range
                  ? 'Inside missile lock range'
                  : 'Outside missile lock range (2 tiles)'
              }
            >
              MSL
            </span>
            <span
              className={`Tac__chip ${target_in_interdict_range ? 'Tac--on' : ''}`}
              title={
                target_in_interdict_range
                  ? 'Inside interdiction range'
                  : 'Outside interdiction range (2 tiles)'
              }
            >
              INTD
            </span>
          </div>
        </div>
      )}

      {others.length === 0 && !target ? (
        <div className="Tac__empty">No contacts in sensor range</div>
      ) : (
        others.map((ship) => {
          const targetable = !!ship.same_zone;
          return (
            <div
              key={ship.ref}
              className={`Tac__row ${targetable ? '' : 'Tac--dead'}`}
              title={
                targetable
                  ? `Acquire a lock on ${ship.name}`
                  : zoneBlockReason(ship, zone_type, zone_name)
              }
              onClick={() => {
                if (targetable) act('select_target', { ref: ship.ref });
              }}
            >
              <span className="Tac__rowGlyph">
                <svg viewBox="-8 -8 16 16" aria-hidden="true">
                  {ship.is_outpost ? (
                    <path
                      d="M0,-6 L6,0 L0,6 L-6,0 Z"
                      fill="none"
                      stroke="currentColor"
                      strokeWidth={1.5}
                    />
                  ) : (
                    <path
                      d="M0,-6 L5,5 L0,2 L-5,5 Z"
                      fill="none"
                      stroke="currentColor"
                      strokeWidth={1.5}
                    />
                  )}
                </svg>
              </span>
              <span className="Tac__rowName">{ship.name}</span>
              <span className="Tac__rowDist">
                {ship.distance} {bearingOf(ship.dx, ship.dy)}
              </span>
              <span className="Tac__rowMeta">
                {ship.identified ? (
                  <>
                    shd {Math.round(ship.shields)}/{ship.shields_max} · hull{' '}
                    {Math.round(ship.integrity)}%
                  </>
                ) : (
                  'no signature'
                )}
                {!targetable && (
                  <span className="Tac__rowZone"> [{ship.zone_name}]</span>
                )}
              </span>
            </div>
          );
        })
      )}
    </>
  );
};

// ---------------------------------------------------------------- drawer · exploits

const EW_TIER_COLORS = ['#7d8f94', '#4fb8a8', '#d9832f', '#a86fe0'];

const EW_TIER_NAMES = [
  'Tier 1 · Harassment',
  'Tier 2 · Disruption',
  'Tier 3 · Assault',
  'Tier 4 · Exotic',
];

// Within-list orderings. All fall back to name so ties are stable.
const EW_SORTERS: Record<string, (a: EwChip, b: EwChip) => number> = {
  'Tier & Name': (a, b) =>
    (a.tier || 0) - (b.tier || 0) || a.name.localeCompare(b.name),
  'Name (A–Z)': (a, b) => a.name.localeCompare(b.name),
  'Ready first': (a, b) =>
    (a.ready ? 0 : 1) - (b.ready ? 0 : 1) || a.name.localeCompare(b.name),
  'Most charges': (a, b) =>
    (b.charges || 0) - (a.charges || 0) || a.name.localeCompare(b.name),
};

const EW_SORT_LABELS = Object.keys(EW_SORTERS);

const formatModeLabel = (mode: string): string =>
  mode.length > 0 ? mode.charAt(0).toUpperCase() + mode.slice(1) : mode;

const ExploitsTab = () => {
  const { data } = useBackend<Data>();
  const { ew_linked, ew } = data;
  const [search, setSearch] = useState('');
  const [tierFilter, setTierFilter] = useState(0);
  // A cycle key instead of a dropdown: the drawer is 284px wide, and a
  // dropdown open over the plate reads as a web form. Click steps the sort.
  const [sortIndex, setSortIndex] = useState(0);

  const chips = ew?.chips ?? [];
  const query = search.trim().toLowerCase();
  const sortLabel = EW_SORT_LABELS[sortIndex];

  const visible = useMemo(() => {
    const sorter = EW_SORTERS[sortLabel] || EW_SORTERS[EW_SORT_LABELS[0]];
    return chips
      .filter((chip) => {
        if (tierFilter && chip.tier !== tierFilter) return false;
        if (
          query &&
          !`${chip.name} ${chip.subsystem}`.toLowerCase().includes(query)
        ) {
          return false;
        }
        return true;
      })
      .sort(sorter);
  }, [chips, tierFilter, query, sortLabel]);

  if (!ew_linked || !ew) {
    return (
      <div className="Tac__ewHowTo">
        <div className="Tac__empty">No electronic warfare suite linked.</div>
        <div className="Tac__ewHint">
          Build or buy an electronic warfare suite, anchor it, and link it to
          this console with a multitool. Load exploit cartridges into the suite
          to make their exploits available here.
        </div>
      </div>
    );
  }

  const grouped = sortIndex === 0 && tierFilter === 0;
  const tierGroups = [1, 2, 3, 4]
    .map((tier) => ({
      tier,
      items: visible.filter((chip) => chip.tier === tier),
    }))
    .filter((group) => group.items.length > 0);

  return (
    <>
      <div className="Tac__ewControls">
        <Input
          fluid
          value={search}
          placeholder="Search exploits…"
          onChange={(value) => setSearch(value ?? '')}
        />
        <button
          type="button"
          className="Tac__btn Tac__sortBtn"
          title="Cycle the sort order"
          onClick={() => setSortIndex((sortIndex + 1) % EW_SORT_LABELS.length)}
        >
          {sortLabel}
        </button>
      </div>
      <div className="Tac__tierFilter">
        <button
          type="button"
          className={`Tac__filterBtn ${tierFilter === 0 ? 'Tac--on' : ''}`}
          onClick={() => setTierFilter(0)}
        >
          All
        </button>
        {[1, 2, 3, 4].map((tier) => (
          <button
            key={tier}
            type="button"
            className={`Tac__filterBtn ${tierFilter === tier ? 'Tac--on' : ''}`}
            style={{ color: EW_TIER_COLORS[tier - 1] }}
            title={EW_TIER_NAMES[tier - 1]}
            onClick={() => setTierFilter(tierFilter === tier ? 0 : tier)}
          >
            T{tier}
          </button>
        ))}
      </div>

      {chips.length === 0 ? (
        <div className="Tac__empty">
          No exploit cartridges loaded: insert cartridges into the suite.
        </div>
      ) : visible.length === 0 ? (
        <div className="Tac__empty">No exploits match your search or filter.</div>
      ) : grouped ? (
        tierGroups.map((group) => (
          <div key={group.tier}>
            <div
              className="Tac__cat"
              style={{ color: EW_TIER_COLORS[group.tier - 1] }}
            >
              {EW_TIER_NAMES[group.tier - 1]} · {group.items.length}
            </div>
            {group.items.map((chip) => (
              <EwChipRow key={chip.ref} chip={chip} />
            ))}
          </div>
        ))
      ) : (
        visible.map((chip) => <EwChipRow key={chip.ref} chip={chip} />)
      )}
    </>
  );
};

const EwChipRow = (props: { chip: EwChip }) => {
  const { chip } = props;
  const { act, data } = useBackend<Data>();
  const { target_ref, ew } = data;
  const executing = !!ew?.executing;
  const traced = !!ew?.traced;
  const spent = chip.charges <= 0;
  const onCooldown = chip.cooldown_remaining > 0;
  const canExecute = !!chip.ready && !executing && !!target_ref;

  // The same ladder the old console climbed; the first true reason wins, and
  // it is surfaced twice, tooltip for the full sentence, status word on the
  // row so a blocked chip reads as blocked without hovering anything.
  let blockReason: string | undefined;
  let statusWord: string | undefined;
  if (spent) {
    blockReason = 'Cartridge spent';
    statusWord = 'SPENT';
  } else if (traced) {
    blockReason = 'Suite locked out';
    statusWord = 'LOCKED';
  } else if (onCooldown) {
    blockReason = `Ready in ${Math.ceil(chip.cooldown_remaining)}s`;
    statusWord = `${Math.ceil(chip.cooldown_remaining)}s`;
  } else if (executing) {
    blockReason = 'Execution already in progress';
    statusWord = 'BUSY';
  } else if (!target_ref) {
    blockReason = 'Requires a target lock';
    statusWord = 'NO LOCK';
  } else if (!chip.ready) {
    blockReason = 'Not ready';
    statusWord = 'NOT READY';
  }

  const tierColor = EW_TIER_COLORS[clamp(chip.tier || 1, 1, 4) - 1];

  return (
    <div className={`Tac__ewChip ${spent ? 'Tac--spent' : ''}`}>
      <div className="Tac__ewHead">
        <span className="Tac__tierChip" style={{ color: tierColor }}>
          T{chip.tier}
        </span>
        <span className="Tac__ewName" title={chip.desc}>
          {chip.name}
        </span>
        <span
          className="Tac__ewCharges"
          style={{ color: spent ? C_CRIT : C_LABEL }}
        >
          {chip.charges}/{chip.max_charges}
        </span>
        <button
          type="button"
          className="Tac__glyphBtn"
          title="Eject cartridge"
          onClick={() => act('ew_eject_chip', { chip_ref: chip.ref })}
        >
          <svg viewBox="0 0 16 16" aria-hidden="true">
            <path d="M8 3l5 6H3l5-6zM3 11h10v2H3z" fill="currentColor" />
          </svg>
        </button>
      </div>
      <div className="Tac__ewMeta">
        {chip.subsystem} · {chip.duration}s
        {!!statusWord && <span className="Tac__ewStatus">{statusWord}</span>}
      </div>
      <div className="Tac__ewExec">
        {chip.modes && chip.modes.length > 0 ? (
          chip.modes.map((mode) => (
            <button
              key={mode}
              type="button"
              className="Tac__btn Tac__execBtn"
              disabled={!canExecute}
              title={blockReason || chip.desc}
              onClick={() => act('ew_execute', { chip_ref: chip.ref, mode })}
            >
              {formatModeLabel(mode)}
            </button>
          ))
        ) : (
          <button
            type="button"
            className="Tac__btn Tac__execBtn"
            disabled={!canExecute}
            title={blockReason || chip.desc}
            onClick={() => act('ew_execute', { chip_ref: chip.ref })}
          >
            {spent ? 'Spent' : 'Execute'}
          </button>
        )}
      </div>
    </div>
  );
};

// ---------------------------------------------------------------- drawer · defense

/**
 * Everything aimed AT us, in one place: completed locks, the field pinning
 * our engines, and any payloads running loose in our systems. The attacking
 * half of the console never has to share a panel with this.
 */
const DefenseTab = () => {
  const { act, data } = useBackend<Data>();
  const {
    locked_by = [],
    being_interdicted,
    our_interdiction_strength,
    can_burst_shields,
    burst_shield_cost,
    ew_intrusion,
  } = data;

  const payloads = ew_intrusion?.payloads ?? [];

  return (
    <>
      <div className="Tac__cat">Weapons locks</div>
      {locked_by.length === 0 ? (
        <div className="Tac__empty">No hostile locks</div>
      ) : (
        <div className="Tac__lockList">
          {locked_by.map((name) => (
            <span key={name} className="Tac__lockChip" title={`${name} holds a completed weapons lock on this ship`}>
              {name}
            </span>
          ))}
        </div>
      )}

      {!!being_interdicted && (
        <>
          <div className="Tac__cat">Interdiction</div>
          <div className="Tac__defLine" style={{ color: C_CRIT }}>
            Engines at {100 - (our_interdiction_strength || 0)}%
          </div>
          <button
            type="button"
            className="Tac__btn Tac__wideBtn Tac--danger"
            disabled={!can_burst_shields}
            title={
              can_burst_shields
                ? `Dump the whole shield pool to snap the field (costs ${burst_shield_cost} shield HP)`
                : `Requires ${burst_shield_cost} shield health with shields active`
            }
            onClick={() => act('burst_shields')}
          >
            Emergency shield burst ({burst_shield_cost} HP)
          </button>
        </>
      )}

      <div className="Tac__cat">Intrusion</div>
      {payloads.length === 0 ? (
        <div className="Tac__empty">No intrusion detected</div>
      ) : (
        <>
          {payloads.map((payload, index) => (
            <div key={index} className="Tac__payload">
              <span className="Tac__payloadName">{payload.name}</span>
              <span className="Tac__payloadSub">{payload.subsystem}</span>
              <span className="Tac__payloadTime">
                {Math.ceil(payload.remaining)}s
              </span>
            </div>
          ))}
          <button
            type="button"
            className="Tac__btn Tac__wideBtn Tac--danger"
            title="End every active payload and harden the firewalls"
            onClick={() => act('ew_purge_intrusion')}
          >
            PURGE INTRUSION
          </button>
        </>
      )}
      {!!ew_intrusion?.hardened && (
        <div className="Tac__defLine" style={{ color: C_GOOD }}>
          Firewalls hardened: {Math.ceil(ew_intrusion.hardened_remaining || 0)}s
        </div>
      )}
    </>
  );
};

// ---------------------------------------------------------------- drawer · systems

/**
 * The maintenance detail the old console buried in Collapsibles: per-mount
 * status and stock-part tiers. Nothing here is a control, it answers "which
 * tube is the slow one" and "did the upgrade take", then gets out of the way.
 */
const SystemsTab = () => {
  const { data } = useBackend<Data>();
  const {
    launchers = [],
    pod_tubes = [],
    turrets = [],
    shield_generators = [],
    cloak_device,
    ew,
    ew_linked,
  } = data;

  return (
    <>
      <div className="Tac__cat">Missile tubes</div>
      {launchers.length === 0 ? (
        <div className="Tac__empty">No tubes linked</div>
      ) : (
        launchers.map((launcher) => {
          const dead = !launcher.on_exterior || !launcher.enabled;
          return (
            <div
              key={launcher.id}
              className={`Tac__sysRow ${dead ? 'Tac--dead' : ''}`}
            >
              <span className="Tac__sysId">{launcher.id}</span>
              <span className="Tac__sysBody">
                {dead ? (
                  <span style={{ color: C_CRIT }}>
                    {!launcher.on_exterior ? 'Not on exterior' : 'Disabled'}
                  </span>
                ) : launcher.loaded ? (
                  <>
                    {launcher.missile_name}
                    <span className="Tac__sysDim">
                      {' '}
                      · {launcher.missile_damage} dmg
                    </span>
                  </>
                ) : (
                  <span className="Tac__sysDim">Empty</span>
                )}
              </span>
              <span className="Tac__sysState">
                {dead ? (
                  '-'
                ) : !launcher.loaded ? (
                  '-'
                ) : launcher.ready ? (
                  <span style={{ color: C_GOOD }}>Ready</span>
                ) : (
                  // No cooldown exists on tubes: loaded-but-not-ready means
                  // the zone's weapons rules are refusing the shot.
                  <span style={{ color: C_WARN }}>Safed</span>
                )}
              </span>
            </div>
          );
        })
      )}

      <div className="Tac__cat">Assault pod tubes</div>
      {pod_tubes.length === 0 ? (
        <div className="Tac__empty">No pod tubes linked</div>
      ) : (
        pod_tubes.map((tube) => {
          const dead = !tube.on_exterior || !tube.enabled;
          return (
            <div
              key={tube.id}
              className={`Tac__sysRow ${dead ? 'Tac--dead' : ''}`}
            >
              <span className="Tac__sysId">{tube.id}</span>
              <span className="Tac__sysBody">
                {dead ? (
                  <span style={{ color: C_CRIT }}>
                    {!tube.on_exterior ? 'Not on exterior' : 'Disabled'}
                  </span>
                ) : tube.loaded ? (
                  <>
                    {tube.pod_name}
                    <span className="Tac__sysDim">
                      {' '}
                      ·{' '}
                      {tube.occupants > 0
                        ? `${tube.occupants} aboard`
                        : 'unmanned'}
                    </span>
                  </>
                ) : (
                  <span className="Tac__sysDim">Empty</span>
                )}
              </span>
              <span className="Tac__sysState">
                {dead || !tube.loaded ? (
                  '-'
                ) : tube.ready ? (
                  <span style={{ color: C_GOOD }}>Ready</span>
                ) : !tube.sealed ? (
                  <span style={{ color: C_WARN }}>Hatch open</span>
                ) : (
                  <span style={{ color: C_WARN }}>Safed</span>
                )}
              </span>
            </div>
          );
        })
      )}

      <div className="Tac__cat">Laser turrets</div>
      {turrets.length === 0 ? (
        <div className="Tac__empty">No turrets linked</div>
      ) : (
        turrets.map((turret) => (
          <div
            key={turret.id}
            className={`Tac__sysRow Tac__sysRow--tall ${turret.on_exterior ? '' : 'Tac--dead'}`}
          >
            <span className="Tac__sysId">{turret.id}</span>
            <span className="Tac__sysBody">
              {turret.on_exterior ? (
                <>
                  {turret.damage} dmg
                  <span className="Tac__sysDim">
                    {' '}
                    · {turret.power_per_shot}W/shot
                  </span>
                </>
              ) : (
                <span style={{ color: C_CRIT }}>Not on exterior</span>
              )}
            </span>
            <span className="Tac__sysState">
              {!turret.on_exterior ? (
                '-'
              ) : turret.ready ? (
                <span style={{ color: C_GOOD }}>Ready</span>
              ) : turret.cooldown_remaining > 0 ? (
                <span className="Tac__microBar">
                  <i
                    style={{
                      width: `${turret.cooldown > 0 ? clamp((1 - turret.cooldown_remaining / turret.cooldown) * 100, 0, 100) : 0}%`,
                      background: C_WARN,
                    }}
                  />
                </span>
              ) : (
                <span className="Tac__microBar">
                  <i
                    style={{
                      width: `${turret.power_per_shot > 0 ? clamp((turret.cell_charge / turret.power_per_shot) * 100, 0, 100) : 0}%`,
                      background: C_AMBER,
                    }}
                  />
                </span>
              )}
            </span>
            <span className="Tac__sysTiers">
              <TierSquares label="Cap" tier={turret.upgrades?.capacitor_tier || 0} />
              <TierSquares label="Las" tier={turret.upgrades?.laser_tier || 0} />
              <TierSquares label="Srv" tier={turret.upgrades?.servo_tier || 0} />
            </span>
          </div>
        ))
      )}

      <div className="Tac__cat">Shield generators</div>
      {shield_generators.length === 0 ? (
        <div className="Tac__empty">No generators linked</div>
      ) : (
        shield_generators.map((gen) => (
          <div key={gen.id} className="Tac__sysRow Tac__sysRow--tall">
            <span className="Tac__sysId">
              <i className={`Tac__led ${gen.active ? 'Tac--on' : ''}`} />
            </span>
            <span className="Tac__sysBody">
              +{gen.max_health_contribution} hp
              <span className="Tac__sysDim"> · +{gen.regen_contribution}/s</span>
            </span>
            <span className="Tac__sysTiers">
              <TierSquares label="Cap" tier={gen.upgrades?.capacitor_tier || 0} />
              <TierSquares label="Las" tier={gen.upgrades?.laser_tier || 0} />
              <TierSquares label="Srv" tier={gen.upgrades?.servo_tier || 0} />
            </span>
          </div>
        ))
      )}

      {!!cloak_device && (
        <>
          <div className="Tac__cat">Cloak</div>
          <div className="Tac__sysRow Tac__sysRow--tall">
            <span className="Tac__sysTiers">
              <TierSquares
                label="Cap"
                tier={cloak_device.upgrades?.capacitor_tier || 0}
              />
              <TierSquares
                label="Las"
                tier={cloak_device.upgrades?.laser_tier || 0}
              />
              <TierSquares
                label="Scan"
                tier={cloak_device.upgrades?.scanning_tier || 0}
              />
            </span>
          </div>
        </>
      )}

      {!!ew_linked && !!ew && (
        <>
          <div className="Tac__cat">EW suite</div>
          <div className="Tac__sysRow Tac__sysRow--tall">
            <span className="Tac__sysTiers">
              <TierSquares label="Cap" tier={ew.upgrades?.capacitor_tier || 0} />
              <TierSquares label="Las" tier={ew.upgrades?.laser_tier || 0} />
              <TierSquares label="Srv" tier={ew.upgrades?.servo_tier || 0} />
            </span>
          </div>
        </>
      )}
    </>
  );
};

// ---------------------------------------------------------------- bottom console

/**
 * One slot glyph per launcher: filled = loaded and ready, barred = loaded but
 * safed, hollow = empty, struck = disabled or not on the exterior. The pip
 * strip is the count made legible, 3/4 says how many, the pips say which.
 *
 * There is no cycling state: tubes have no fire cooldown in DM (can_fire is
 * power + anchor + loaded + exterior + zone), so a loaded tube that isn't
 * ready is being refused by the zone's weapons rules, not reloading.
 */
const TubePip = (props: { launcher: Launcher }) => {
  const { launcher } = props;
  const dead = !launcher.on_exterior || !launcher.enabled;
  const state = dead
    ? 'struck'
    : !launcher.loaded
      ? 'empty'
      : launcher.ready
        ? 'ready'
        : 'safed';
  const title = dead
    ? `${launcher.id}, ${!launcher.on_exterior ? 'not on exterior' : 'disabled'}`
    : !launcher.loaded
      ? `${launcher.id}, empty`
      : launcher.ready
        ? `${launcher.id}, ${launcher.missile_name} ready`
        : `${launcher.id}, loaded, safed by zone weapons rules`;

  return (
    <svg className="Tac__pip" viewBox="0 0 12 16" aria-hidden="false">
      <title>{title}</title>
      {state === 'ready' && (
        <path d="M6 1l4 5v9H2V6l4-5z" fill={C_AMBER} />
      )}
      {state === 'safed' && (
        // Loaded but held: the missile outline with a safety bar across it.
        <>
          <path
            d="M6 1l4 5v9H2V6l4-5z"
            fill="none"
            stroke={C_WARN}
            strokeWidth={1.2}
          />
          <path d="M2 8h8" stroke={C_WARN} strokeWidth={1.4} />
        </>
      )}
      {state === 'empty' && (
        <path
          d="M6 1l4 5v9H2V6l4-5z"
          fill="none"
          stroke={C_STEEL}
          strokeWidth={1.2}
        />
      )}
      {state === 'struck' && (
        <>
          <path
            d="M6 1l4 5v9H2V6l4-5z"
            fill="none"
            stroke={C_STEEL}
            strokeWidth={1.2}
          />
          <path d="M1 15L11 1" stroke={C_CRIT} strokeWidth={1.2} />
        </>
      )}
    </svg>
  );
};

const TubesPanel = () => {
  const { act, data } = useBackend<Data>();
  const {
    launchers = [],
    launchers_ready,
    launchers_total,
    pod_tubes = [],
    pod_tubes_ready,
    pod_tubes_total,
    target_shields_up,
    is_in_attack_mode,
    target_in_missile_range,
  } = data;

  if (launchers.length === 0 && pod_tubes.length === 0) {
    return (
      <div className="Tac__pad">
        <div className="Tac__quiet">
          No tubes linked: multitool a launcher to this console
        </div>
      </div>
    );
  }

  // The server only accepts fire orders from inside camera mode, so the keys
  // are dead until then rather than lying about what a click would do.
  const armed = !!is_in_attack_mode && !!target_in_missile_range;
  const blockReason = !is_in_attack_mode
    ? 'Enter targeting (OPS) to arm the fire keys'
    : !target_in_missile_range
      ? 'Out of missile range'
      : undefined;
  const podsArmed = armed && (pod_tubes_ready ?? 0) > 0;
  const podReason = !armed
    ? blockReason
    : (pod_tubes_ready ?? 0) === 0
      ? 'No pod loaded and ready'
      : target_shields_up
        ? 'Target shields are UP, the pod and its crew die on contact'
        : 'Put a boarding pod through the target hull';

  return (
    <div className="Tac__pad">
      <div className="Tac__weaponHead">
        <span className="Tac__bigNum" style={{ color: C_AMBER }}>
          {launchers_ready}
          <span className="Tac__bigDen">/{launchers_total}</span>
        </span>
        <span className="Tac__pips">
          {launchers.map((launcher) => (
            <TubePip key={launcher.id} launcher={launcher} />
          ))}
        </span>
      </div>
      <div className="Tac__fireRow">
        <button
          type="button"
          className="Tac__fireKey"
          disabled={!armed || launchers.length === 0}
          title={blockReason ?? 'Fire one tube at the locked target'}
          onClick={() => act('fire_missile')}
        >
          Fire
        </button>
        <button
          type="button"
          className="Tac__fireKey"
          disabled={!armed || launchers.length === 0}
          title={blockReason ?? 'Empty every ready tube at once'}
          onClick={() => act('fire_all')}
        >
          Salvo
        </button>
        {pod_tubes.length > 0 && (
          <button
            type="button"
            className="Tac__fireKey"
            disabled={!podsArmed}
            title={podReason}
            onClick={() => act('launch_pod')}
          >
            Board {pod_tubes_ready}/{pod_tubes_total}
          </button>
        )}
      </div>
    </div>
  );
};

const LasersPanel = () => {
  const { act, data } = useBackend<Data>();
  const {
    turrets = [],
    turret_power_level,
    turret_power_available,
    turret_power_max,
    is_in_attack_mode,
    target_ref,
  } = data;

  if (turrets.length === 0) {
    return (
      <div className="Tac__pad">
        <div className="Tac__quiet">
          No turrets linked: multitool a turret to this console
        </div>
      </div>
    );
  }

  const powerPercent = Math.round((turret_power_level ?? 1) * 100);
  const poolRatio =
    turret_power_max > 0
      ? clamp(turret_power_available / turret_power_max, 0, 1)
      : 0;
  // Lasers don't care about missile range. Camera mode and a lock are the
  // whole gate.
  const armed = !!is_in_attack_mode && !!target_ref;
  const blockReason = !is_in_attack_mode
    ? 'Enter targeting (OPS) to arm the fire keys'
    : !target_ref
      ? 'No target locked'
      : undefined;

  return (
    <div className="Tac__pad">
      <div className="Tac__bar" title={`${turret_power_available} of ${turret_power_max} charge banked`}>
        <i style={{ width: `${poolRatio * 100}%`, background: C_AMBER }} />
        <span className="Tac__ticks" />
      </div>
      <CommitRange
        min={25}
        max={200}
        step={25}
        value={powerPercent}
        label="Laser power level"
        title="Beam power. More damage, more watts per shot."
        format={(v) => `${v}%`}
        onCommit={(v) => act('set_turret_power', { power: v })}
      />
      <div className="Tac__note">
        {Math.round(50 * turret_power_level)} dmg ·{' '}
        {Math.round(2000 * turret_power_level)} W/shot · 1.5x vs shields
      </div>
      <div className="Tac__fireRow">
        <button
          type="button"
          className="Tac__fireKey"
          disabled={!armed}
          title={blockReason ?? 'Fire one turret at the locked target'}
          onClick={() => act('fire_laser')}
        >
          Fire
        </button>
        <button
          type="button"
          className="Tac__fireKey"
          disabled={!armed}
          title={blockReason ?? 'Discharge every ready turret at once'}
          onClick={() => act('fire_all_lasers')}
        >
          Volley
        </button>
      </div>
    </div>
  );
};

const InterdictPanel = () => {
  const { act, data } = useBackend<Data>();
  const {
    target_ref,
    interdictor_linked,
    interdiction_active,
    interdiction_warming_up,
    interdiction_warmup_progress,
    interdictor_power_level,
    interdictor_power_draw,
    interdictor_target_name,
    interdictor_target_speed_cap,
    interdict_cooldown_active,
    interdict_cooldown_remaining,
    interdictor_ready,
    target_in_interdict_range,
    interdiction_allowed,
  } = data;

  if (!interdictor_linked) {
    return (
      <div className="Tac__pad">
        <div className="Tac__quiet">No interdictor linked</div>
      </div>
    );
  }

  const powerPercent = Math.round((interdictor_power_level ?? 1) * 100);
  const powerSlider = (
    <CommitRange
      min={25}
      max={200}
      step={25}
      value={powerPercent}
      label="Interdictor power level"
      title="Field strength. A stronger field caps the target's engines lower and draws more power."
      format={(v) => `${v}%`}
      onCommit={(v) => act('set_interdictor_power', { power: v })}
    />
  );

  // Locking: the warmup is the window the target gets to run.
  if (interdiction_warming_up) {
    return (
      <div className="Tac__pad">
        <div
          className="Tac__stateLine"
          style={{ color: C_WARN }}
          title={interdictor_target_name ?? undefined}
        >
          LOCKING {(interdictor_target_name ?? '').toUpperCase()}
        </div>
        <div className="Tac__bar" style={{ marginTop: '0.4cqw' }}>
          <i
            style={{
              // Warmup progress rides 0-1, unlike the sibling 0-100 fields,
              // see the old InterdictorPanel, which displayed it *100.
              width: `${clamp((interdiction_warmup_progress || 0) * 100, 0, 100)}%`,
              background: C_WARN,
            }}
          />
          <span className="Tac__ticks" />
        </div>
        <button
          type="button"
          className="Tac__btn Tac__wideBtn"
          style={{ marginTop: 'auto' }}
          title="Break off the field lock"
          onClick={() => act('cancel_interdict')}
        >
          Cancel
        </button>
      </div>
    );
  }

  if (interdiction_active) {
    return (
      <div className="Tac__pad">
        <div
          className="Tac__stateLine"
          style={{ color: C_RED }}
          title={interdictor_target_name ?? undefined}
        >
          FIELD ACTIVE: {(interdictor_target_name ?? '').toUpperCase()} @{' '}
          {interdictor_target_speed_cap ?? 0}%
        </div>
        {powerSlider}
        <button
          type="button"
          className="Tac__btn Tac__wideBtn Tac--danger"
          style={{ marginTop: 'auto' }}
          title="Drop the field and free the target"
          onClick={() => act('cancel_interdict')}
        >
          Collapse field
        </button>
      </div>
    );
  }

  if (interdict_cooldown_active) {
    const remaining = interdict_cooldown_remaining || 0;
    return (
      <div className="Tac__pad">
        <div className="Tac__stateLine" style={{ color: C_WARN }}>
          RECHARGING {deciToSeconds(remaining)}s
        </div>
        <div className="Tac__bar" style={{ marginTop: '0.4cqw' }}>
          <i
            style={{
              width: `${clamp((1 - remaining / INTERDICT_COOLDOWN_DS) * 100, 0, 100)}%`,
              background: C_WARN,
            }}
          />
          <span className="Tac__ticks" />
        </div>
      </div>
    );
  }

  // Ready. The reason line under the key names the first blocker, in the
  // order a crew can actually fix them: get a lock, close the range, and
  // "prohibited" last because no flying fixes that one.
  const reason = !target_ref
    ? 'No target'
    : !interdiction_allowed
      ? 'Interdiction prohibited here'
      : !target_in_interdict_range
        ? 'Out of range'
        : !interdictor_ready
          ? 'Field charging'
          : null;

  return (
    <div className="Tac__pad">
      {powerSlider}
      <div className="Tac__metric">
        <span className="Tac__k">Draw</span>
        <span className="Tac__v">{interdictor_power_draw || 0}W</span>
      </div>
      <button
        type="button"
        className="Tac__fireKey"
        style={{ marginTop: 'auto' }}
        disabled={!!reason}
        title={
          reason ??
          'Project a field that pins the target’s engines while it holds'
        }
        onClick={() => act('start_interdict')}
      >
        Engage field
      </button>
      {!!reason && <div className="Tac__reason">{reason}</div>}
    </div>
  );
};

// ---------------------------------------------------------------- ops

const OpsButton = (props: {
  label: string;
  sub: string;
  path: string;
  disabled?: boolean;
  state?: 'armed' | 'active';
  title: string;
  onClick: () => void;
}) => (
  <button
    type="button"
    className={`Tac__opBtn ${props.state ? `Tac--${props.state}` : ''}`}
    disabled={props.disabled}
    title={props.title}
    onClick={props.onClick}
  >
    <svg
      viewBox="0 0 24 24"
      fill="none"
      stroke="currentColor"
      strokeWidth={1.7}
      strokeLinecap="round"
      strokeLinejoin="round"
    >
      <path d={props.path} />
    </svg>
    <span className="Tac__opLabel">{props.label}</span>
    <span className="Tac__opSub">{props.sub}</span>
  </button>
);

const OpsPanel = () => {
  const { act, data } = useBackend<Data>();
  const {
    is_in_attack_mode,
    is_targeting,
    target_ref,
    target_name,
    target_in_missile_range,
    ew_intrusion,
    can_burst_shields,
    burst_shield_cost,
  } = data;

  const payloads = ew_intrusion?.payloads?.length ?? 0;

  return (
    <div className="Tac__ops">
      <OpsButton
        label={is_in_attack_mode ? 'Exit' : 'Engage'}
        sub={
          is_in_attack_mode
            ? 'targeting live'
            : target_ref && !target_in_missile_range
              ? 'out of range'
              : 'camera'
        }
        path="M12 3v4M12 17v4M3 12h4M17 12h4M16 12a4 4 0 11-8 0 4 4 0 018 0z"
        // The server refuses the camera beyond missile-lock range, so a live
        // key out there would only ever bounce off a chat warning.
        disabled={
          !is_in_attack_mode && (!target_ref || !target_in_missile_range)
        }
        state={is_in_attack_mode ? 'active' : undefined}
        title={
          is_in_attack_mode
            ? 'Drop out of the targeting camera'
            : !target_ref
              ? 'Select a target on the scope first'
              : !target_in_missile_range
                ? `Close to within ${LOCK_RANGE_TILES} tiles for a missile lock`
                : 'Enter the targeting camera and arm the fire keys'
        }
        onClick={() => act(is_in_attack_mode ? 'deactivate' : 'activate')}
      />
      <OpsButton
        label="Release"
        sub={target_name ?? 'no lock'}
        path="M4 4h4M16 4h4M4 20h4M16 20h4M8 8l8 8M16 8l-8 8"
        disabled={!target_ref && !is_targeting}
        title={
          is_targeting
            ? 'Break off the lock attempt'
            : target_ref
              ? `Release the lock on ${target_name}`
              : 'Nothing is locked'
        }
        onClick={() => {
          // Both, deliberately: mid-acquisition there is a pending lock to
          // cancel AND possibly a held one to release, and the server treats
          // the spare call as a no-op.
          if (is_targeting) act('cancel_targeting');
          act('clear_target');
        }}
      />
      <OpsButton
        label="Purge"
        sub={
          payloads > 0
            ? `${payloads} payload${payloads === 1 ? '' : 's'}`
            : 'no intrusion'
        }
        path="M12 3l7 3v5c0 5-3.5 8-7 10-3.5-2-7-5-7-10V6l7-3zM5 20L20 5"
        disabled={payloads === 0}
        state={payloads > 0 ? 'active' : undefined}
        title={
          payloads > 0
            ? 'End every hostile payload and harden the firewalls'
            : 'No hostile payloads are running'
        }
        onClick={() => act('ew_purge_intrusion')}
      />
      <OpsButton
        label="Burst"
        sub={`${burst_shield_cost} HP`}
        path="M12 2v5M12 17v5M2 12h5M17 12h5M4.9 4.9l3.5 3.5M15.6 15.6l3.5 3.5M19.1 4.9l-3.5 3.5M8.4 15.6l-3.5 3.5"
        disabled={!can_burst_shields}
        title={
          can_burst_shields
            ? `Dump the whole shield pool at once to snap a hostile interdiction field (costs ${burst_shield_cost} shield HP)`
            : `Requires ${burst_shield_cost} shield health with shields active`
        }
        onClick={() => act('burst_shields')}
      />
    </div>
  );
};

// ---------------------------------------------------------------- overlays

const NotConnectedOverlay = () => (
  <div className="Tac__overlay">
    <div className="Tac__overlayBox">
      <div className="Tac__overlayTitle">No ship registered</div>
      <div className="Tac__overlayDesc">
        Install this console aboard a vessel. It links on its own.
      </div>
    </div>
  </div>
);

