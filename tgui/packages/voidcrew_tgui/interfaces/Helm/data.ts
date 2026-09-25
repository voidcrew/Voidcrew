/**
 * Helm console data shapes.
 *
 * These mirror the payload built by /obj/machinery/computer/helm/ui_data() in
 * voidcrew/modules/shuttle/helm/_helm.dm and the contact snapshot in
 * voidcrew/modules/overmap/code/ship/sensors.dm. Keep the two in step: the
 * server is the source of truth, this file only describes it.
 */
import type { BooleanLike } from 'tgui-core/react';

export type ContactKind =
  | 'ship'
  | 'distress'
  | 'planet'
  | 'ruin'
  | 'outpost'
  | 'nebula'
  | 'hazard'
  | 'bounty'
  | 'mission'
  | 'rumor'
  | 'event'
  | 'marker';

export type Contact = {
  name: string;
  x: number;
  y: number;
  dist: number;
  bearing: string;
  category: string;
  kind: ContactKind;
  /**
   * One step finer than `kind`: which terrain a planet is, which storm a hazard
   * is, which gas a nebula carries. Null where the helm has nothing finer to
   * say, an unsurveyed ruin, a mission pin dropped on bare coordinates.
   * See get_contact_variant() in ship/sensors.dm.
   */
  variant?: string | null;
  /** Storms only, 1-3. Sizes the glyph; 0 elsewhere. */
  severity?: number;
  /**
   * One plain sentence about what going there costs - a red-band planet's
   * radiation fronts, say. Null for the great majority of contacts, which have
   * nothing to warn about. See get_hazard_note() in ship/sensors.dm.
   */
  hazard?: string | null;
  ref: string | null;
  /** Stable identity shared by live, charted and distress versions of a contact. */
  contactRef: string;
  /** Seen right now, versus merely charted, drawn solid rather than faded. */
  live?: BooleanLike;
  /** Vessels only: FALSE until a scan or the top radar tier names them. */
  identified?: BooleanLike;
  /** REF of the overmap object, for the chart's context menu. */
  target?: string | null;
  hostile?: BooleanLike;
  integrity?: number;
  /**
   * The hull behind this contact is running a distress beacon. Set on the
   * contact whether it came from the vessel pass (a beacon inside the rings) or
   * from the unlimited-range distress pass (one anywhere else in the galaxy).
   * See ship/distress.dm.
   */
  sos?: BooleanLike;
  /** Whatever the crew over there typed. Nothing verified it. */
  sosMessage?: string | null;
};

/** A hail heard by this ship. See ship/transmissions.dm. */
export type Transmission = {
  message: string;
  sender: string;
  x: number;
  y: number;
  /** Seconds since it fired. */
  age: number;
  /** Still young enough to pulse on the chart. */
  live: BooleanLike;
  /** We sent it. */
  own: BooleanLike;
};

export type Engine = {
  name: string;
  fuel: number;
  maxFuel: number;
  enabled: BooleanLike;
  ref: string;
};

/**
 * An entry in the permanent charted table (ui_static_data). Carries no distance,
 * bearing or live flag. Those are derived per-frame by useContacts().
 */
export type ChartedContact = {
  contactRef: string;
  name: string;
  x: number;
  y: number;
  category: string;
  kind: ContactKind;
  variant?: string | null;
  severity?: number;
  /** See Contact.hazard - remembered contacts keep their warnings. */
  hazard?: string | null;
  target: string;
};

/**
 * Flight-policy toggles. Keys are exactly what act('autopilot_pref') sends and
 * the server whitelists in set_autopilot_pref(); the checked state shown is
 * whatever the server last confirmed, so a rejected key simply never moves.
 */
export type AutopilotPrefs = {
  allowNeutral: BooleanLike;
  allowContested: BooleanLike;
  allowLawless: BooleanLike;
};

/** The planned course is public; navigation's hazard map stays on the server. */
export type Autopilot = {
  engaged: BooleanLike;
  label: string | null;
  status: string | null;
  dockOnArrival?: BooleanLike;
  destX?: number;
  destY?: number;
  path: [number, number][];
  prefs?: AutopilotPrefs;
};

/** One thing the Dock button could do from the tile the ship is on. */
export type DockOption = {
  /** "empty space", or a description of the thing we'd dock into. */
  name: string;
  /** REF() of the overmap object to dock with, or null for empty space. */
  ref: string | null;
  isEmpty: BooleanLike;
};

export type Data = {
  isViewer: BooleanLike;
  isNotCrew: BooleanLike;
  isAbandoned: BooleanLike;
  shipInfo: { name: string; class: string; mass: number };
  chart: {
    size: number;
    centre: number;
    ringInner: number;
    ringMiddle: number;
    /** Free sight radius, fixed. Research moves sensorRange, never this. */
    viewRange: number;
  };

  integrity: number;
  overhealth: number;
  shipDisabled: BooleanLike;
  shipCrashed: BooleanLike;
  repairCurrent: number;
  repairTotal: number;

  est_thrust: number;
  canThrust: BooleanLike;
  engineInfo: Engine[];

  x: number;
  y: number;
  state: string;
  docked: BooleanLike;
  speed: number;
  heading: string;
  /**
   * The dir the velocity itself carries the ship in, set whether or not the
   * engines are lit. `burnDirection` is where the crew is pushing; this is where
   * the ship goes if they stop. See useDrift().
   */
  driftDirection: number;
  eta: number;
  moveIntervalMs: number;
  burnDirection: number;
  burnPercentage: number;
  /**
   * The course the pilot has commanded, as BYOND dir bits, or 0 for none.
   * Outlives the burn: while cruising the engines are cold but this still
   * carries the direction the ship is holding. The rose lights from this.
   */
  commandedCourse: number;
  /** Tiles/min the throttle is currently trimming the cruise toward. */
  cruiseTargetSpeed: number;
  /** Tiles/min at or below which Dock auto-stops the ship. Server enforces the same. */
  dockAssistMaxSpeed: number;

  sensorRange: number;
  scanCooldown: BooleanLike;
  scanCooldownRemaining: number;
  waypoints: Contact[];
  /** Static: everything ever seen. Merged with `waypoints` by useContacts(). */
  chartedContacts: ChartedContact[];
  /** Ship-wide list preferences. Removed contacts still appear on the chart. */
  dismissedContacts: string[];
  transmissions: Transmission[];
  otherInfo: {
    name: string;
    integrity: number;
    hazard?: string | null;
    ref: string;
  }[];
  pendingRumors: { name: string; desc: string; ref: string }[];

  zone_name: string;
  zone_color: string;
  zone_description: string;
  weapons_allowed: BooleanLike;
  interdiction_allowed: BooleanLike;
  zone_transitioning: BooleanLike;
  zone_transition_progress: number;
  zone_transition_remaining: number;
  zone_transition_target: string | null;
  /** Set while the ship is in (or crossing into) a band it has no warfare
   * research to meet. Null the rest of the time. */
  zone_advisory: { label: string; critical: BooleanLike } | null;

  calibrating: BooleanLike;
  undockCooldown: BooleanLike;
  undockCooldownRemaining: number;
  undockLocked: BooleanLike;
  undockLockoutRemaining: number;
  integrityLockout: BooleanLike;
  integrityLockoutRemaining: number;
  dockWarmup: BooleanLike;
  dockWarmupRemaining: number;
  undockWarmup: BooleanLike;
  undockWarmupRemaining: number;
  cargoShuttlePresent: BooleanLike;
  isInterdicted: BooleanLike;
  speedMultiplier: number;
  onNebula: BooleanLike;
  hiddenInNebula: BooleanLike;
  nebulaHideWarmup: BooleanLike;
  nebulaHideRemaining: number;
  canLand: BooleanLike;
  dockOptions: DockOption[];
  autopilot: Autopilot;
  /** This ship's own distress beacon. Everyone else's rides the contact set. */
  distress: {
    active: BooleanLike;
    /** What the beacon is repeating, or null while it is dark. */
    message: string | null;
    cooldown: BooleanLike;
    cooldownRemaining: number;
  };
};

// BYOND direction bits, as change_heading expects them.
export const DIR = {
  N: 1,
  S: 2,
  E: 4,
  W: 8,
  NE: 5,
  NW: 9,
  SE: 6,
  SW: 10,
} as const;

// Keep in sync with voidcrew/_DEFINES/overmap.dm.
export const BURN_NONE = 0;
export const BURN_STOP = -1;

export const DIR_VECTOR: Record<number, [number, number]> = {
  1: [0, 1],
  2: [0, -1],
  4: [1, 0],
  8: [-1, 0],
  5: [1, 1],
  9: [-1, 1],
  6: [1, -1],
  10: [-1, -1],
};

/** WASD + X (coast). Same set the monolith bound. */
export const STEER_KEYCODES = [87, 65, 83, 68, 88];

/** Keyboard movement keys, as the union-of-held course the server expects. */
export const KEY_AXIS: Record<string, number> = {
  KeyW: DIR.N,
  ArrowUp: DIR.N,
  KeyS: DIR.S,
  ArrowDown: DIR.S,
  KeyD: DIR.E,
  ArrowRight: DIR.E,
  KeyA: DIR.W,
  ArrowLeft: DIR.W,
};

/** Active scan sweeps the sensor panel offers. */
export const SCAN_TYPES = ['Planets', 'Ruins', 'Ships'];
