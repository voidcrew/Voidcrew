/**
 * Helm console.
 *
 * A fixed 1200x760 faceplate: top rail, three-column body (instrument stack /
 * navigation chart / contact drawer) and a bottom control console. Every panel
 * is positioned from GEOMETRY below, in percentages, so the whole console scales
 * with the window. GEOMETRY is also the source geometry for the background-plate
 * mask (tools/helm_plate/make_mask.py); keep the two in step.
 *
 * The chart is drawn here rather than piped through a BYOND camera map, which is
 * what lets it zoom, label contacts, take clicks, and interpolate movement. The
 * ship moves one whole overmap tile per `tick_move()` with no sub-tile position
 * in DM at all; we glide the camera and the token over exactly `moveIntervalMs`.
 * The same interval the move timer is scheduled on, so each authoritative
 * jump reads as continuous flight.
 *
 * Flight is fly-by-wire: the rose (or W/A/S/D at the keyboard) commands a
 * course, and the ship sheds contrary drift, burns up to its cruise speed and
 * coasts holding it. See the key handler in Faceplate.
 */
import {
  createContext,
  useContext,
  useEffect,
  useLayoutEffect,
  useRef,
  useState,
} from 'react';
import { Input } from 'tgui-core/components';
import { globalEvents } from 'tgui-core/events';
import { acquireHotKey, releaseHotKey } from 'tgui-core/hotkeys';
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
  HULL: { x: 10, y: 54, w: 212, h: 70 },
  FUEL: { x: 10, y: 132, w: 212, h: 168 },
  DRIVE: { x: 10, y: 308, w: 212, h: 84 },
  SENSOR: { x: 10, y: 400, w: 212, h: 184 },
  CHART: { x: 240, y: 52, w: 652, h: 532 },
  DRAWER: { x: 908, y: 52, w: 284, h: 532 },
  THROT: { x: 10, y: 600, w: 110, h: 152 },
  ROSE: { x: 128, y: 600, w: 172, h: 152 },
  VELOC: { x: 308, y: 600, w: 212, h: 152 },
  OPS: { x: 528, y: 600, w: 664, h: 152 },
} satisfies Record<string, Rect>;

/**
 * The faceplate art, served by /datum/asset/simple/helm_faceplate. Its bezels are
 * composited at the exact GEOMETRY coordinates above, so it is stretched to
 * 100% x 100% rather than covered. The panels are positioned in percentages and
 * the two have to track each other. Set to null to fall back to the CSS plate.
 */
const FACEPLATE_ASSET: string | null = 'helm_faceplate.png';

const panelStyle = (r: Rect) => ({
  left: `${(r.x / FRAME.w) * 100}%`,
  top: `${(r.y / FRAME.h) * 100}%`,
  width: `${(r.w / FRAME.w) * 100}%`,
  height: `${(r.h / FRAME.h) * 100}%`,
});

/**
 * SVG elements take `transform-origin: 50% 50%` of the view-box by default, which
 * silently breaks any translate/scale chain that assumes the user-space origin.
 * Every CSS transform on an SVG node in this file pins the origin to 0,0.
 */
const SVG_ORIGIN = { transformOrigin: '0 0' } as const;

// ---------------------------------------------------------------- data

type ContactKind =
  | 'ship'
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

type Contact = {
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
   * See get_contact_variant() in ship_sensors.dm.
   */
  variant?: string | null;
  /** Storms only, 1-3. Sizes the glyph; 0 elsewhere. */
  severity?: number;
  ref: string | null;
  /** Seen right now, versus merely charted, drawn solid rather than faded. */
  live?: BooleanLike;
  /** Vessels only: FALSE until a scan or the top radar tier names them. */
  identified?: BooleanLike;
  /** REF of the overmap object, for the chart's context menu. */
  target?: string | null;
  hostile?: BooleanLike;
  integrity?: number;
};

/** A hail heard by this ship. See ship_transmissions.dm. */
type Transmission = {
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

type Engine = {
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
type ChartedContact = {
  name: string;
  x: number;
  y: number;
  category: string;
  kind: ContactKind;
  variant?: string | null;
  severity?: number;
  target: string;
};

/**
 * Flight-policy toggles. Keys are exactly what act('autopilot_pref') sends and
 * the server whitelists in set_autopilot_pref(); the checked state shown is
 * whatever the server last confirmed, so a rejected key simply never moves.
 */
type AutopilotPrefs = {
  crossMeteor: BooleanLike;
  crossElectric: BooleanLike;
  crossEmp: BooleanLike;
  avoidHostiles: BooleanLike;
  zoneCaution: BooleanLike;
  hazardLanding: BooleanLike;
};

/** A plotted course. See ship_autopilot.dm. */
type Autopilot = {
  engaged: BooleanLike;
  /** Server-side label for the destination, never echoed back from the client. */
  label: string | null;
  /** Why the last course ended, shown until a new one is plotted. */
  status: string | null;
  /** The plotted course ends in a docking approach, not just an arrival. */
  dockOnArrival?: BooleanLike;
  destX?: number;
  destY?: number;
  remaining?: number;
  /** Remaining course, next step first, in relative overmap coordinates. */
  path: [number, number][];
  /** Present engaged or idle: the policy panel works while nothing is flown. */
  prefs?: AutopilotPrefs;
  /** Shields are up, so asteroid impacts are absorbed (crossMeteor hint). */
  shieldsActive?: BooleanLike;
};

/** One thing the Dock button could do from the tile the ship is on. */
type DockOption = {
  /** "empty space", or a description of the thing we'd dock into. */
  name: string;
  /** REF() of the overmap object to dock with, or null for empty space. */
  ref: string | null;
  isEmpty: BooleanLike;
};

type Data = {
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
  transmissions: Transmission[];
  otherInfo: { name: string; integrity: number; ref: string }[];
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
};

// BYOND direction bits, as change_heading expects them.
const DIR = {
  N: 1,
  S: 2,
  E: 4,
  W: 8,
  NE: 5,
  NW: 9,
  SE: 6,
  SW: 10,
} as const;
const BURN_NONE = 0;
const BURN_STOP = -1;

const DIR_VECTOR: Record<number, [number, number]> = {
  1: [0, 1],
  2: [0, -1],
  4: [1, 0],
  8: [-1, 0],
  5: [1, 1],
  9: [-1, 1],
  6: [1, -1],
  10: [-1, -1],
};

/** Keyboard steering: event.code → the compass bit that key presses. */
const KEY_AXIS: Record<string, number> = {
  KeyW: DIR.N,
  ArrowUp: DIR.N,
  KeyS: DIR.S,
  ArrowDown: DIR.S,
  KeyD: DIR.E,
  ArrowRight: DIR.E,
  KeyA: DIR.W,
  ArrowLeft: DIR.W,
};

/**
 * Keycodes the manual-control toggle takes away from the game while armed.
 *
 * tgui forwards letter keys to the BYOND client as movement/hotkey macros,
 * that is how you walk around with a UI focused, so steering on W/A/S/D
 * without acquiring them flies the ship AND marches the pilot into a wall.
 * X (swap hands in game) rides along for the coast key. Arrows and Space are
 * in tgui's default acquired set and never reach the game from a focused
 * window, which is why they are absent here.
 */
const STEER_KEYCODES = [87, 65, 83, 68, 88]; // W A S D X

/**
 * The chart's contact taxonomy.
 *
 * Two axes, and both come from DM: `kind` is the family and picks the glyph
 * silhouette, `variant` is one step finer and picks the colour. A navigator
 * reading the chart should be able to say what a mark is from its shape alone
 * and what sort of one it is from its colour, without a legend and without
 * hovering, which is why no two families share an outline and no two members
 * of a family share a hue.
 *
 * Family colour, used where the helm knows the family but nothing finer.
 */
const KIND_COLOR: Record<ContactKind, string> = {
  planet: '#8fa7ad',
  ruin: '#9d8fd0',
  outpost: '#59b871',
  ship: '#d6e2e4',
  nebula: '#c479c0',
  hazard: '#cf4a38',
  bounty: '#e2564a',
  mission: '#f2a341',
  rumor: '#ffc94d',
  event: '#74c8dd',
  marker: '#9fb2b7',
};

/**
 * Planet terrain, keyed on chart_variant in planets.dm. Planets all share one
 * glyph and are told apart by colour alone, so these are picked to be separable
 * at a few pixels: an ice world and an ocean world must not both read as "blue".
 */
const PLANET_COLOR: Record<string, string> = {
  lava: '#e0713c',
  ice: '#8fd8ea',
  ocean: '#4d8ed8',
  jungle: '#5fc267',
  wasteland: '#c3a56d',
  asteroid: '#9aa6a9',
  rock: '#8fa7ad',
  signal: '#7f939a',
  wreck: '#d1604f',
};

/**
 * Storm families. Each is flown around differently, rock damages the hull, ion
 * kills the electronics, so none of the three share a colour, and all three
 * stay out of the crit red the console reserves for hostile vessels.
 */
const HAZARD_COLOR: Record<string, string> = {
  rock: '#c86b3c',
  ion: '#a071e0',
  electrical: '#e6c53f',
};

/**
 * Per-family colour tables, consulted before the family colour above.
 *
 * Nebulas deliberately have no entry here: every gas variant reads as the
 * same mark on the chart (KIND_COLOR.nebula) since which gas a cloud carries
 * isn't something the crew can tell without flying into it anyway.
 */
const VARIANT_COLOR: Partial<Record<ContactKind, Record<string, string>>> = {
  planet: PLANET_COLOR,
  hazard: HAZARD_COLOR,
  // A rumour-chart ruin advertises itself as worth the trip even unsurveyed.
  ruin: { encrypted: '#ffc94d' },
};

/**
 * What colour a mark is drawn in. Hostility and anonymity outrank everything
 * else: an unscanned hull must not borrow the friendly white or the hostile red,
 * because which one it deserves is exactly what the crew doesn't know yet.
 */
const contactColour = (contact: Contact) => {
  if (contact.kind === 'ship' && !contact.identified) return '#8c9ea2';
  if (contact.hostile) return '#cf4a38';
  const variants = VARIANT_COLOR[contact.kind];
  const refined = contact.variant ? variants?.[contact.variant] : undefined;
  return refined ?? KIND_COLOR[contact.kind] ?? KIND_COLOR.marker;
};

/** Storm glyphs scale with severity, so a majour field reads as worse. */
const SEVERITY_SCALE: Record<number, number> = { 1: 0.82, 2: 1, 3: 1.2 };

/**
 * Categories an active scan can sweep for; matches sensor_category in DM.
 * Planets and Ruins are charted out to the sensor ring and persist. Ships are
 * identified in place out to the view ring and are never charted. Hazards are
 * absent deliberately: our own sensors can't pin a storm, which is what a bought
 * star chart is for, it records the whole band, storms included.
 */
const SCAN_TYPES = ['Planets', 'Ruins', 'Ships'];

const deciToSeconds = (ds: number) => Math.ceil(ds / 10);

/** m:ss, matching the ETA the ship formats for the readouts. */
const clockOf = (ms: number) => {
  const total = Math.round(ms / 1000);
  return `${Math.floor(total / 60)}:${String(total % 60).padStart(2, '0')}`;
};

/** Deciseconds as m:ss. The hull-failure lockout runs minutes, where a bare second count reads badly. */
const deciToClock = (ds: number) => clockOf(deciToSeconds(ds) * 1000);

/** Contacts are keyed by ref where they have one; live ship tracks don't. */
const contactKey = (contact: Pick<Contact, 'ref' | 'name' | 'x' | 'y'>) =>
  contact.ref ?? `${contact.name}-${contact.x}-${contact.y}`;

/**
 * Whether "Travel & dock" can be offered on a contact: only the kinds a ship
 * can actually berth into, and only from a distance, on top of one, the Dock
 * button already does the job.
 */
const DOCKABLE_KINDS: ContactKind[] = ['planet', 'ruin', 'outpost'];
const canTravelDock = (contact: Contact) =>
  DOCKABLE_KINDS.includes(contact.kind) && contact.dist > 0 && !!contact.target;

/**
 * Port of overmap_delta_to_compass() in ship_waypoints.dm: the 0.4142 is
 * tan(22.5°), which is what splits the compass into eight even sectors.
 *
 * Bearing and distance are derived from two positions the client already has, so
 * they are computed here rather than sent. That is what lets the charted table
 * ride ui_static_data: including them made an otherwise unchanging set of
 * contacts look like it changed every time the ship crossed a tile.
 */
const bearingOf = (dx: number, dy: number) => {
  if (!dx && !dy) return '';
  let compass = '';
  if (Math.abs(dy) > Math.abs(dx) * 0.4142) compass += dy > 0 ? 'N' : 'S';
  if (Math.abs(dx) > Math.abs(dy) * 0.4142) compass += dx > 0 ? 'E' : 'W';
  return compass;
};

/**
 * The live contact set and the permanent charted table as one list.
 *
 * Static data can't know what is in sight this second, so the charted table
 * carries everything the ship has ever seen, including whatever it happens to be
 * looking at right now. Dropping the duplicates is the client's job, keyed on the
 * object each entry came from.
 */
const useContacts = (): Contact[] => {
  const { data } = useBackend<Data>();
  const { waypoints = [], chartedContacts = [], x, y } = data;

  const alreadyLive = new Set(
    waypoints.map((contact) => contact.target).filter(Boolean),
  );

  const remembered: Contact[] = [];
  for (const entry of chartedContacts) {
    if (entry.target && alreadyLive.has(entry.target)) continue;
    const dx = entry.x - x;
    const dy = entry.y - y;
    remembered.push({
      ...entry,
      ref: null,
      live: 0,
      dist: Math.round(Math.hypot(dx, dy)),
      bearing: bearingOf(dx, dy),
    });
  }
  return [...waypoints, ...remembered];
};

/**
 * How long the ship needs to reach a tile at the speed it is already carrying.
 *
 * Nothing on the helm used to answer this. `eta` from the server is the clock on
 * the movement timer (the next TILE, not the destination) and the drift track's
 * own clocks run to a rolling horizon that slides along with the ship, so its
 * label reads the same number forever. Under thrust the speed changes every
 * fifth of a second and all of it moves, which is why this only ever looked
 * broken with the engines cold: coast, and every duration on the console holds
 * still while the ship keeps crossing tiles.
 *
 * tick_move() steps each axis by the SIGN of its velocity, so one interval buys a
 * tile on BOTH axes at once: the hop count to a tile is its Chebyshev distance,
 * not the straight-line one the rows report alongside it. Wraparound counts, for
 * the same reason useDrift() walks it. The map's edges are joined, and the short
 * way to a contact near the far edge is off the near one.
 *
 * It is the honest "at this speed" figure rather than a promise: it assumes the
 * crew steers the short way and holds the magnitude they have. Deliberately NOT
 * gated on the current heading. A ship coasting the wrong way still wants to
 * know what the trip costs before it commits to turning, and absent entirely
 * with the ship stopped, where there is no answer to give.
 */
const useTravelClock = () => {
  const { data } = useBackend<Data>();
  const { x, y, chart, moveIntervalMs, state } = data;

  const size = chart?.size ?? 51;
  // tick_move() flies the band 2..size-1 joined end to end, so the long way
  // round an axis is (size - 2) - |delta|.
  const span = size - 2;
  const axisSteps = (delta: number) => {
    const direct = Math.abs(delta);
    const around = span - direct;
    return around > 0 && around < direct ? around : direct;
  };

  /** m:ss to reach the tile, or null where the console can't say. */
  return (tileX: number, tileY: number): string | null => {
    if (!moveIntervalMs || state !== 'flying') return null;
    const steps = Math.max(axisSteps(tileX - x), axisSteps(tileY - y));
    if (!steps) return null;
    return clockOf(steps * moveIntervalMs);
  };
};

/**
 * The selected contact, shared so the chart and the drawer highlight each other:
 * clicking a mark on the map scrolls it into focus in the list, and vice versa.
 */
const Selection = createContext<{
  selected: string | null;
  select: (key: string) => void;
}>({ selected: null, select: () => {} });

/**
 * A request to bring an overmap tile into view. `nonce` is what makes a second
 * click on the same contact a fresh request. The coordinates alone are
 * identical, so the chart would never see the request change.
 */
type FocusRequest = { x: number; y: number; nonce: number };

/**
 * Picking a contact out of the register aims the chart at it.
 *
 * The camera lives inside Chart, because pan and zoom are the things that own
 * it, so the register can't move it directly: it posts a tile here and the
 * chart decides what to do about it. That indirection is what lets the chart
 * ignore a request for a mark that is already on screen, the common case, and
 * one where moving the camera would detach it from the ship for no gain.
 */
const ChartFocus = createContext<{
  request: FocusRequest | null;
  focusOn: (x: number, y: number) => void;
}>({ request: null, focusOn: () => {} });

/**
 * Where the right-click action menu is pinned and what it was opened on. `key`
 * is the contact under the cursor where there was one; bare chart opens a menu
 * on `tile` alone, since plotting a course is an action on a position.
 */
type MenuState = {
  key: string | null;
  tile: { x: number; y: number };
  left: number;
  top: number;
};

/**
 * Approximate menu box, used only to keep it inside the console. Tracks the
 * max-width and the text sizes of .Helm__menu in the stylesheet.
 */
const MENU_SIZE = { w: 260, h: 210 };

/**
 * The right-click action menu, opened from either the chart or the contact
 * drawer and rendered once at the console root.
 *
 * At the root rather than inside the panel it was opened from, because every
 * panel well is `overflow: hidden`: a menu owned by the chart gets clipped at
 * the chart's edge, and the drawer is under 300px wide, too narrow to read one
 * in at all. Anchored on the console it can open at the cursor wherever the
 * cursor is.
 */
const MenuControl = createContext<
  (
    event: React.MouseEvent,
    key: string | null,
    tile: { x: number; y: number },
  ) => void
>(() => {});

/**
 * Where the Dock button's option picker is pinned. A separate context from
 * MenuControl above because its contents come straight from `dockOptions`
 * rather than from a selected contact, but it needs the same
 * rendered-at-the-root treatment, for the same reason: the OPS panel is
 * `overflow: hidden` and only 152px tall, nowhere near enough to hold a list
 * of options without clipping it.
 */
const DockMenuControl = createContext<(event: React.MouseEvent) => void>(
  () => {},
);

// ---------------------------------------------------------------- root

export const HelmComputer = () => {
  const [selected, setSelected] = useState<string | null>(null);
  const select = (key: string) =>
    setSelected((current) => (current === key ? null : key));

  const [focusRequest, setFocusRequest] = useState<FocusRequest | null>(null);
  const focusOn = (x: number, y: number) =>
    setFocusRequest((current) => ({ x, y, nonce: (current?.nonce ?? 0) + 1 }));

  return (
    <Window width={1216} height={800}>
      <Window.Content fitted>
        <Selection.Provider value={{ selected, select }}>
          <ChartFocus.Provider value={{ request: focusRequest, focusOn }}>
            <Faceplate />
          </ChartFocus.Provider>
        </Selection.Provider>
      </Window.Content>
    </Window>
  );
};

const Faceplate = () => {
  const { act, data } = useBackend<Data>();
  const { shipCrashed, repairCurrent, repairTotal } = data;
  const locked = useLocked();
  const rootRef = useRef<HTMLDivElement>(null);
  const [menu, setMenu] = useState<MenuState | null>(null);
  const [dockMenu, setDockMenu] = useState<{
    left: number;
    top: number;
  } | null>(null);

  const contacts = useContacts();
  const menuContact = menu?.key
    ? contacts.find((contact) => contactKey(contact) === menu.key)
    : undefined;
  // A contact that vanished takes its menu with it rather than leaving a menu
  // pointing at nothing. A tile menu has no contact and is left alone.
  if (menu?.key && !menuContact) setMenu(null);

  const openMenu = (
    event: React.MouseEvent,
    key: string | null,
    tile: { x: number; y: number },
  ) => {
    // Both callers would otherwise hand the BYOND client's own context menu to a
    // player mid-manoeuvre.
    event.preventDefault();
    event.stopPropagation();
    const box = rootRef.current?.getBoundingClientRect();
    const width = box?.width ?? 0;
    const height = box?.height ?? 0;
    const cursorX = event.clientX - (box?.left ?? 0);
    const cursorY = event.clientY - (box?.top ?? 0);
    setMenu({
      key,
      tile,
      // Flipped to the other side of the cursor rather than clamped back to the
      // edge: the drawer sits against the right side of the console, so clamping
      // would pin every menu opened from it to the same spot instead of to the
      // row it came from.
      left:
        cursorX + MENU_SIZE.w <= width
          ? cursorX
          : Math.max(0, cursorX - MENU_SIZE.w),
      top: clamp(cursorY, 0, Math.max(0, height - MENU_SIZE.h)),
    });
  };

  const openDockPicker = (event: React.MouseEvent) => {
    event.stopPropagation();
    const box = rootRef.current?.getBoundingClientRect();
    const width = box?.width ?? 0;
    const height = box?.height ?? 0;
    const cursorX = event.clientX - (box?.left ?? 0);
    const cursorY = event.clientY - (box?.top ?? 0);
    setDockMenu({
      left:
        cursorX + MENU_SIZE.w <= width
          ? cursorX
          : Math.max(0, cursorX - MENU_SIZE.w),
      top: clamp(cursorY, 0, Math.max(0, height - MENU_SIZE.h)),
    });
  };

  /**
   * Whether the keyboard is currently steering the ship. Off, every key does
   * what it always did, including walking your character, which is exactly
   * why steering can't simply be always-on: tgui forwards letters to the game,
   * so unarmed W/A/S/D would fly the ship and march the pilot at once. The
   * switch lives in the Helm panel's caption; closing the console or losing
   * flight state disarms it.
   */
  const [manualControl, setManualControl] = useState(false);

  // The key handler below registers once, so it reads the live gate state
  // through this ref rather than closing over one render's worth of it.
  // Abandoned is its own gate: useLocked() deliberately unlocks an abandoned
  // ship so the claim button works, but every mouse control sits behind the
  // claim overlay, the keyboard must not steer past it unclaimed.
  const keyGuards = useRef({
    manual: false,
    locked: true,
    flying: false,
    crashed: false,
    abandoned: false,
  });
  keyGuards.current = {
    manual: manualControl,
    locked,
    flying: data.state === 'flying',
    crashed: !!shipCrashed,
    abandoned: !!data.isAbandoned,
  };

  // Manual control is an in-flight mode: a docked, crashed or spectating
  // console hands the keyboard back rather than sitting on dead keys.
  const canManualControl = !locked && data.state === 'flying' && !shipCrashed;
  useEffect(() => {
    if (manualControl && !canManualControl) setManualControl(false);
  }, [manualControl, canManualControl]);

  /**
   * Whether this window currently has the keyboard. The manual-control claim
   * only exists inside the window's own input handling, unfocused, keystrokes
   * go straight to the BYOND client and walk the pilot as normal, whatever the
   * switch says, so the switch reads "live" only while this is true, and
   * "armed" while it merely waits for the window to be clicked back into.
   * tgui-core's focus signal is debounced, so focus hopping between elements
   * inside the window doesn't flicker it.
   */
  const [windowFocused, setWindowFocused] = useState(() => document.hasFocus());
  useEffect(() => {
    const onFocusChange = (focused: boolean) => setWindowFocused(focused);
    globalEvents.on('window-focus-change', onFocusChange);
    return () => globalEvents.off('window-focus-change', onFocusChange);
  }, []);

  /**
   * While armed, take the steering letters away from the game so the pilot's
   * character stands fast. Acquire/release is tgui's own claim mechanism.
   * PreventDefault can't do this job, because the passthrough that forwards
   * keys to BYOND has usually already run by the time this handler sees the
   * event. Paired exactly: armed acquires, the cleanup releases on disarm and
   * on unmount, so a closed console never leaves W/A/S/D dead.
   */
  useEffect(() => {
    if (!manualControl) return;
    for (const code of STEER_KEYCODES) acquireHotKey(code);
    return () => {
      for (const code of STEER_KEYCODES) releaseHotKey(code);
    };
  }, [manualControl]);

  /**
   * Keyboard steering, live only while manual control is armed (the switch in
   * the Helm panel's caption (see the acquisition effect above for why it)
   * can't be always-on). W/A/S/D and the arrow keys command a course from the
   * union of the held movement keys (opposite keys cancel on their axis);
   * Space brakes, and pressing it again while braking coasts, the server owns
   * that toggle; X cuts straight to coast. Tap-to-command rather than
   * hold-to-thrust: velocity persists in space, so a held key would add
   * nothing over a press, and the commanded course lives server-side until it
   * is replaced, which is why releasing a key sends nothing.
   *
   * Stands down over any typing surface (the rename field must never steer
   * the ship), over modifier chords, and behind anything that consumed the
   * key first, the throttle's own arrow handling preventDefaults, and this
   * defers to it. preventDefault here is limited to keys actually handled, so
   * Space and the arrows keep their scroll behaviour wherever this declines.
   */
  useEffect(() => {
    // Effect-closure state, same lifetime as a ref since this registers once.
    // Cleared on window blur so a key released while the client is unfocused
    // can't stay "held" forever.
    const held = new Set<string>();
    const courseOfHeld = () => {
      let dir = 0;
      for (const code of held) dir |= KEY_AXIS[code] ?? 0;
      if ((dir & DIR.N) !== 0 && (dir & DIR.S) !== 0) dir &= ~(DIR.N | DIR.S);
      if ((dir & DIR.E) !== 0 && (dir & DIR.W) !== 0) dir &= ~(DIR.E | DIR.W);
      return dir;
    };
    const onKeyDown = (event: KeyboardEvent) => {
      const guards = keyGuards.current;
      if (!guards.manual) return;
      if (guards.locked || !guards.flying || guards.crashed || guards.abandoned)
        return;
      if (event.ctrlKey || event.altKey || event.metaKey) return;
      if (event.defaultPrevented) return;
      const target = event.target as HTMLElement | null;
      if (
        target &&
        (target.tagName === 'INPUT' ||
          target.tagName === 'TEXTAREA' ||
          target.isContentEditable)
      ) {
        return;
      }
      if (event.code === 'Space') {
        event.preventDefault();
        if (!event.repeat) act('stop');
        return;
      }
      if (event.code === 'KeyX') {
        event.preventDefault();
        if (!event.repeat) act('set_course', { dir: 0 });
        return;
      }
      if (!(event.code in KEY_AXIS)) return;
      event.preventDefault();
      if (event.repeat || held.has(event.code)) return;
      held.add(event.code);
      const dir = courseOfHeld();
      // Zero means the new key cancelled a held one out. Command nothing
      // rather than a coast the pilot didn't ask for.
      if (dir) act('set_course', { dir });
    };
    const onKeyUp = (event: KeyboardEvent) => {
      held.delete(event.code);
    };
    const onBlur = () => held.clear();
    window.addEventListener('keydown', onKeyDown);
    window.addEventListener('keyup', onKeyUp);
    window.addEventListener('blur', onBlur);
    return () => {
      window.removeEventListener('keydown', onKeyDown);
      window.removeEventListener('keyup', onKeyUp);
      window.removeEventListener('blur', onBlur);
    };
    // act is the stable module-level sendAct, so this registers exactly once.
  }, [act]);

  return (
    <MenuControl.Provider value={openMenu}>
      <DockMenuControl.Provider value={openDockPicker}>
        <div
          className="Helm"
          ref={rootRef}
          onClick={() => {
            setMenu(null);
            setDockMenu(null);
          }}
        >
          <div
            className={`Helm__plate ${FACEPLATE_ASSET ? 'Helm__plate--art' : ''}`}
            style={
              FACEPLATE_ASSET
                ? { backgroundImage: `url("${resolveAsset(FACEPLATE_ASSET)}")` }
                : undefined
            }
          />
          {!FACEPLATE_ASSET && <div className="Helm__hazard" />}

          <Panel rect={GEOMETRY.IDENT}>
            <Ident />
          </Panel>
          <Panel rect={GEOMETRY.ZONE}>
            <ZoneBadge />
          </Panel>
          <Panel rect={GEOMETRY.ALERT}>
            <AlertStrip />
          </Panel>

          <Panel rect={GEOMETRY.HULL} label="Hull" aux="integrity">
            <HullGauge />
          </Panel>
          <Panel rect={GEOMETRY.FUEL} label="Fuel" aux="drive mass">
            <FuelStack />
          </Panel>
          <Panel rect={GEOMETRY.DRIVE} label="Drive" aux="thrust">
            <DriveGauge />
          </Panel>
          <Panel rect={GEOMETRY.SENSOR} label="Sensors" aux="array">
            <SensorDial />
          </Panel>

          <Panel rect={GEOMETRY.CHART} label="Navigation chart">
            <Chart />
          </Panel>
          <Panel rect={GEOMETRY.DRAWER} label="Contacts">
            <Drawer />
          </Panel>

          <Panel rect={GEOMETRY.THROT} label="Throttle" aux="cruise">
            <Throttle />
          </Panel>
          <Panel
            rect={GEOMETRY.ROSE}
            label="Helm"
            action={
              <button
                type="button"
                className={`Helm__btn Helm__wellAction ${
                  manualControl
                    ? windowFocused
                      ? 'Helm--on'
                      : 'Helm--armed'
                    : ''
                }`}
                disabled={!canManualControl}
                title={
                  !manualControl
                    ? 'Steer from the keyboard: WASD and arrows fly, Space brakes, X coasts. Your character stands fast while it is on.'
                    : windowFocused
                      ? 'Keyboard is steering the ship, click to hand W/A/S/D back to your character'
                      : 'Armed, steering resumes when this console window is focused. Right now your keys move your character as normal.'
                }
                onClick={() => setManualControl(!manualControl)}
              >
                {manualControl
                  ? windowFocused
                    ? 'wasd · live'
                    : 'wasd · armed'
                  : 'wasd'}
              </button>
            }
          >
            <HelmRose />
          </Panel>
          <Panel rect={GEOMETRY.VELOC} label="Velocity">
            <VelocityCluster />
          </Panel>
          <Panel rect={GEOMETRY.OPS} label="Operations">
            <OpsRow />
          </Panel>

          {!!menu && (
            <ContactMenu
              contact={menuContact}
              tile={menu.tile}
              left={menu.left}
              top={menu.top}
              onClose={() => setMenu(null)}
            />
          )}
          {!!dockMenu && (
            <DockPickerMenu
              left={dockMenu.left}
              top={dockMenu.top}
              onClose={() => setDockMenu(null)}
            />
          )}

          {!!shipCrashed && (
            <CrashOverlay current={repairCurrent} total={repairTotal} />
          )}
          {!shipCrashed && <AbandonedOverlay />}
        </div>
      </DockMenuControl.Provider>
    </MenuControl.Provider>
  );
};

const Panel = (props: {
  rect: Rect;
  label?: string;
  aux?: string;
  /** Right-aligned control in the caption bar. The label row is the only
   * chrome a well owns, so a panel-scoped switch lives there or nowhere. */
  action?: React.ReactNode;
  children;
}) => {
  const { rect, label, aux, action, children } = props;
  return (
    <div className="Helm__panel" style={panelStyle(rect)}>
      <div className={`Helm__well ${label ? 'Helm__well--labelled' : ''}`}>
        {!!label && (
          <div className="Helm__wellLabel">
            {label}
            {!!aux && <span className="Helm__wellAux">/ {aux}</span>}
            {action}
          </div>
        )}
        {children}
      </div>
    </div>
  );
};

/** True when this console can't issue orders: a viewscreen, or an outsider. */
const useLocked = () => {
  const { data } = useBackend<Data>();
  return !!data.isViewer || (!!data.isNotCrew && !data.isAbandoned);
};

// ---------------------------------------------------------------- top rail

/**
 * Shrinks the ship name until it fits the ident slot, down to a floor, past which
 * it ellipsises. The plate is fixed art with a fixed-width ident bezel and ship
 * names are player-set and unbounded, so the name is what has to give, letting it
 * run on simply pushed it off the end of the panel.
 *
 * The measurement is taken with the scale forced back to 1, otherwise each pass
 * would measure the previous pass's shrink and creep smaller every render.
 */
const useFitToWidth = (text: string, minScale: number) => {
  const boxRef = useRef<HTMLDivElement>(null);
  const textRef = useRef<HTMLButtonElement>(null);
  const [scale, setScale] = useState(1);

  useLayoutEffect(() => {
    const box = boxRef.current;
    const node = textRef.current;
    if (!box || !node) return;

    const measure = () => {
      const applied = node.style.getPropertyValue('--helm-name-scale');
      node.style.setProperty('--helm-name-scale', '1');
      // BOTH reads have to happen while the scale is forced back to 1. The slot is
      // a flex item sized from its content, so measuring the slot with the shrink
      // already applied would feed each result into the next and creep the name
      // smaller every time the observer fired.
      const natural = node.scrollWidth;
      const available = box.clientWidth;
      // Restored before paint, and React re-applies its own value next render.
      node.style.setProperty('--helm-name-scale', applied);
      if (!available || !natural) return;
      // scrollWidth rounds down to whole pixels while the text is laid out at
      // fractional widths, so a name that "exactly fits" is routinely a fraction
      // too wide and ellipsises anyway. The guard pixel costs nothing visible.
      setScale(Math.max(minScale, Math.min(1, available / (natural + 1))));
    };

    measure();
    // The console is sized in container units, so a window resize changes the
    // base font size as well as the slot. Both have to be re-measured.
    const observer = new ResizeObserver(measure);
    observer.observe(box);
    return () => observer.disconnect();
  }, [text, minScale]);

  /*
   * Verify after paint, and shrink again if the name is still clipped.
   *
   * The measurement above is only as good as the font metrics in force when it
   * ran, and the stencil stack starts at 'Arial Narrow'. A host without it falls
   * back to something markedly wider. Measure with one font, render with another,
   * and the ellipsis comes back with nothing left to re-check it. Container units
   * resolving late do the same thing.
   *
   * No dependency array on purpose: this runs after every render, only ever
   * shrinks, and stops touching state the moment it fits, so it converges in a
   * pass or two instead of trusting a single reading.
   */
  useEffect(() => {
    const node = textRef.current;
    if (!node || node.scrollWidth <= node.clientWidth + 1) return;
    const overflowRatio = node.clientWidth / (node.scrollWidth + 1);
    setScale((current) => Math.max(minScale, current * overflowRatio));
  });

  return { boxRef, textRef, scale };
};

const Ident = () => {
  const { act, data } = useBackend<Data>();
  const { shipInfo, x, y } = data;
  const locked = useLocked();
  const [editing, setEditing] = useState(false);
  const { boxRef, textRef, scale } = useFitToWidth(shipInfo.name, 0.45);

  return (
    <div className="Helm__ident">
      <div className="Helm__identName" ref={boxRef}>
        {editing ? (
          <Input
            autoFocus
            fluid
            value={shipInfo.name}
            onEnter={(value) => {
              act('rename_ship', { newName: value });
              setEditing(false);
            }}
            onBlur={() => setEditing(false)}
          />
        ) : (
          <button
            type="button"
            ref={textRef}
            className="Helm__shipName"
            style={
              { '--helm-name-scale': scale } as React.CSSProperties
            }
            disabled={locked}
            title={locked ? shipInfo.name : `${shipInfo.name}, rename vessel`}
            onClick={() => setEditing(true)}
          >
            {shipInfo.name}
          </button>
        )}
      </div>
      <span className="Helm__shipClass">
        {shipInfo.class}
        {!!shipInfo.mass && ` · ${shipInfo.mass}t`}
      </span>
      <span className="Helm__shipPos">
        {String(x).padStart(2, '0')} / {String(y).padStart(2, '0')}
      </span>
    </div>
  );
};

const ZoneBadge = () => {
  const { data } = useBackend<Data>();
  const {
    zone_name,
    zone_color,
    zone_description,
    weapons_allowed,
    interdiction_allowed,
  } = data;

  return (
    <div className="Helm__zone" title={zone_description}>
      <i
        className="Helm__zoneDot"
        style={{ background: zone_color, color: zone_color }}
      />
      <span className="Helm__zoneName" style={{ color: zone_color }}>
        {zone_name}
      </span>
      <span className="Helm__zoneFlags">
        <span
          className={`Helm__flag ${weapons_allowed ? 'Helm--on' : 'Helm--off'}`}
          title={
            weapons_allowed
              ? 'Ship weapons are live here'
              : 'Ship weapons are disabled here'
          }
        >
          Weap
        </span>
        <span
          className={`Helm__flag ${interdiction_allowed ? 'Helm--on' : 'Helm--off'}`}
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
 * crew can't act on stays out. This rail is for things that change what you do
 * in the next few seconds.
 */
const AlertStrip = () => {
  const { data } = useBackend<Data>();
  const drift = useDrift(useContacts());
  const alerts: [string, string][] = [];

  if (data.isNotCrew && !data.isAbandoned) {
    alerts.push(['crit', 'Crew authorization required']);
  }
  if (data.shipDisabled) {
    alerts.push(['crit', 'Hull critical, systems offline']);
  }
  if (data.isInterdicted) {
    alerts.push([
      'crit',
      `Interdicted, engines at ${Math.round(data.speedMultiplier * 100)}%`,
    ]);
  }
  if (data.state === 'flying' && !data.canThrust) {
    alerts.push(['crit', 'No engine power']);
  }
  // Only a hazard earns the rail. Everything else the drift runs over is on the
  // chart and in the ENDS readout, and none of it changes what you do next.
  if (drift?.intercept && drift.intercept.contact.kind === 'hazard') {
    alerts.push([
      drift.intercept.ms <= 15000 ? 'crit' : 'warn',
      // "Heading into" rather than "drifting into": the track is the velocity,
      // so it is just as true of a ship burning straight at the thing.
      `Heading into ${drift.intercept.contact.name}, ${clockOf(drift.intercept.ms)}`,
    ]);
  }
  // Sits above the transition line: a crew that can't survive where they're
  // going needs to read that before the countdown they're reading it during.
  if (data.zone_advisory) {
    alerts.push([
      data.zone_advisory.critical ? 'crit' : 'warn',
      data.zone_advisory.label,
    ]);
  }
  if (data.zone_transitioning) {
    alerts.push([
      'warn',
      `Entering ${data.zone_transition_target ?? 'new zone'}, ${data.zone_transition_remaining}s`,
    ]);
  }
  if (data.cargoShuttlePresent) {
    alerts.push(['warn', 'Cargo shuttle docked']);
  }
  if (data.calibrating) {
    alerts.push(['warn', 'Bluespace jump calibrating']);
  }
  if (data.autopilot?.engaged) {
    alerts.push([
      'info',
      `Autopilot, ${data.autopilot.label ?? 'plotted course'} in ${data.autopilot.remaining ?? 0}${
        data.autopilot.dockOnArrival ? ' · docking on arrival' : ''
      }`,
    ]);
  }
  if (data.hiddenInNebula) {
    alerts.push(['info', 'Nebula concealment active']);
  } else if (data.nebulaHideWarmup) {
    alerts.push([
      'info',
      `Concealing in ${deciToSeconds(data.nebulaHideRemaining)}s`,
    ]);
  } else if (data.onNebula) {
    alerts.push(['info', 'Nebula, concealment available']);
  }

  return (
    <div className="Helm__alerts">
      {alerts.length ? (
        alerts.map(([severity, text]) => (
          <span key={text} className={`Helm__alert Helm--${severity}`}>
            {text}
          </span>
        ))
      ) : (
        <span className="Helm__quiet">All systems nominal</span>
      )}
    </div>
  );
};

// ---------------------------------------------------------------- left stack

/** 75+ green, 61–74 amber, 51–60 red, 50 and under is the disabled threshold. */
const hullColor = (value: number) => {
  if (value <= 50) return '#4a1410';
  if (value <= 60) return '#cf4a38';
  if (value <= 74) return '#d9a230';
  return '#59b871';
};

const HullGauge = () => {
  const { data } = useBackend<Data>();
  const { integrity, overhealth = 0, shipDisabled } = data;
  const base = Math.min(integrity - overhealth, 100);
  const colour = hullColor(base);

  return (
    <div className="Helm__pad">
      <div className="Helm__hullRow">
        <span className="Helm__hullNum" style={{ color: colour }}>
          {integrity}
        </span>
        <span className="Helm__hullSub">%</span>
        <span
          className="Helm__hullState"
          style={{ color: shipDisabled ? '#cf4a38' : '#7d8f94' }}
        >
          {shipDisabled
            ? 'Disabled'
            : overhealth > 0
              ? `+${overhealth} plate`
              : 'Nominal'}
        </span>
      </div>
      <div className="Helm__bar Helm__hullBar">
        <i style={{ width: `${base}%`, background: colour }} />
        {overhealth > 0 && (
          <i
            style={{
              left: `${base}%`,
              width: `${overhealth}%`,
              background: '#1d6b3a',
            }}
          />
        )}
        <span className="Helm__disabledMark" title="Systems fail below 50%" />
        <span className="Helm__ticks" />
      </div>
    </div>
  );
};

const FuelStack = () => {
  const { act, data } = useBackend<Data>();
  const { engineInfo = [] } = data;
  const locked = useLocked();

  const live = engineInfo.filter((engine) => engine.enabled && engine.maxFuel);
  const average = live.length
    ? Math.round(
        live.reduce((sum, e) => sum + (e.fuel / e.maxFuel) * 100, 0) /
          live.length,
      )
    : 0;
  const colour =
    average < 25 ? '#cf4a38' : average < 50 ? '#d9a230' : '#f2a341';

  return (
    <div className="Helm__pad">
      <div className="Helm__metric">
        <span className="Helm__k">Reserve</span>
        <span className="Helm__v" style={{ color: colour }}>
          {average}%
        </span>
      </div>
      <div className="Helm__bar" style={{ marginTop: '0.4cqw' }}>
        <i style={{ width: `${average}%`, background: colour }} />
        <span className="Helm__ticks" />
      </div>
      <div className="Helm__engines">
        {engineInfo.map((engine) => {
          const percent = engine.maxFuel
            ? Math.round((engine.fuel / engine.maxFuel) * 100)
            : 0;
          return (
            <div key={engine.ref} className="Helm__engine">
              <button
                type="button"
                className={`Helm__engineToggle ${engine.enabled ? 'Helm--on' : ''}`}
                disabled={locked}
                title={`${engine.enabled ? 'Shut down' : 'Start'} ${engine.name}`}
                onClick={() => act('toggle_engine', { engine: engine.ref })}
              >
                {engine.enabled ? 'I' : 'O'}
              </button>
              <span className="Helm__engineName" title={engine.name}>
                {engine.name}
              </span>
              <span
                className="Helm__engineFuel"
                style={{
                  color: !engine.enabled
                    ? '#3a474b'
                    : percent < 40
                      ? '#d9a230'
                      : '#f2a341',
                }}
              >
                {percent}%
              </span>
            </div>
          );
        })}
      </div>
    </div>
  );
};

/**
 * Installed thrust and what the drives are currently doing. Deliberately not a
 * live-output-over-maximum ratio: nothing in DM tracks instantaneous thrust any
 * more, so a ratio here would be a gauge that always reads zero.
 */
const DriveGauge = () => {
  const { data } = useBackend<Data>();
  const {
    est_thrust = 0,
    engineInfo = [],
    canThrust,
    burnDirection,
    speedMultiplier,
  } = data;

  const online = engineInfo.filter((engine) => engine.enabled).length;
  const share = engineInfo.length ? (online / engineInfo.length) * 100 : 0;
  const burning = burnDirection !== BURN_NONE && burnDirection !== BURN_STOP;
  const throttled = speedMultiplier < 1;

  return (
    <div className="Helm__pad">
      <div className="Helm__metric">
        <span className="Helm__k">Thrust</span>
        <span className="Helm__v">{est_thrust.toFixed(1)}</span>
      </div>
      <div className="Helm__bar" style={{ marginTop: '0.4cqw' }}>
        <i
          style={{
            width: `${share}%`,
            background: canThrust ? '#f2a341' : '#4a3413',
          }}
        />
        <span className="Helm__ticks" />
      </div>
      <div
        className="Helm__note"
        style={{ color: canThrust ? '#7d8f94' : '#cf4a38' }}
      >
        {!canThrust
          ? 'No engine power'
          : throttled
            ? `Throttled to ${Math.round(speedMultiplier * 100)}%`
            : burning
              ? `Burning · ${online} of ${engineInfo.length} drives`
              : `${online} of ${engineInfo.length} drives online`}
      </div>
    </div>
  );
};

const SensorDial = () => {
  const { act, data } = useBackend<Data>();
  const { sensorRange, scanCooldown, scanCooldownRemaining, state } = data;
  const locked = useLocked();
  const canScan = !locked && state === 'flying';

  const MAX_RANGE = 10;
  const circumference = 2 * Math.PI * 26;
  // 3/4 sweep so the dial reads as a gauge rather than a full ring.
  const filled = (sensorRange / MAX_RANGE) * circumference * 0.75;
  const cooldownRadius = 19;
  const cooldownFraction = scanCooldown
    ? Math.min(1, scanCooldownRemaining / 600)
    : 0;

  return (
    <div className="Helm__pad">
      <div className="Helm__dial">
        <svg viewBox="0 0 72 62" aria-hidden="true">
          <circle
            cx="36"
            cy="32"
            r="26"
            fill="none"
            stroke="#0f1618"
            strokeWidth="6"
          />
          <circle
            cx="36"
            cy="32"
            r="26"
            fill="none"
            stroke="#74c8dd"
            strokeWidth="6"
            strokeDasharray={`${filled} ${circumference}`}
            transform="rotate(135 36 32)"
            opacity="0.9"
          />
          {cooldownFraction > 0 && (
            <circle
              cx="36"
              cy="32"
              r={cooldownRadius}
              fill="none"
              stroke="#d9a230"
              strokeWidth="2"
              strokeDasharray={`${2 * Math.PI * cooldownRadius * cooldownFraction} ${2 * Math.PI * cooldownRadius}`}
              transform="rotate(-90 36 32)"
            />
          )}
        </svg>
        <div className="Helm__dialReadout">
          <span className="Helm__dialValue">{sensorRange}</span>
          <span className="Helm__dialUnit">Tile range</span>
        </div>
      </div>
      <div
        className="Helm__scanState"
        style={{ color: scanCooldown ? '#d9a230' : '#7d8f94' }}
      >
        {scanCooldown
          ? `Recharging ${deciToSeconds(scanCooldownRemaining)}s`
          : canScan
            ? 'Active scan'
            : 'Scan requires flight'}
      </div>
      <div className="Helm__scanRow">
        {SCAN_TYPES.map((category) => (
          <button
            key={category}
            type="button"
            className="Helm__btn"
            disabled={!canScan || !!scanCooldown}
            title={`Chart every ${category.toLowerCase().replace(/s$/, '')} in sensor range so it stays on the map after you leave`}
            onClick={() => act('active_scan', { category })}
          >
            {category}
          </button>
        ))}
      </div>
    </div>
  );
};

// ---------------------------------------------------------------- chart

/** Design units per overmap tile in the chart's own coordinate space. */
const UNIT = 10;

/**
 * How far inside its tile a projected cell is drawn.
 *
 * The chart is smooth and the overmap is not: the ship moves in whole-tile hops,
 * but a projection drawn as a polyline is a diagonal-free straight edge that
 * lines up with nothing, so the crew can read a heading off it and not the tiles
 * it actually passes through. The fix is to mark the tiles themselves, but at
 * full tile size, consecutive cells on a straight track share their edges and
 * merge back into one unbroken corridor. The inset is the gap that keeps them
 * reading as separate hops.
 *
 * Drift sits inside the plotted course rather than on top of it, so where the
 * autopilot is flying the ship and the two tracks coincide, they nest instead of
 * covering each other.
 */
const PLOT_INSET = 1.2;
const DRIFT_INSET = 2.2;

/**
 * Widest zoom, in tiles across the chart, that still leaves a projected cell big
 * enough to hold its arrival clock, and fine enough for a per-tile grid to be a
 * grid rather than a wash. Past it the marks stay and the text goes.
 */
const TILE_DETAIL_SPAN = 17;

/**
 * Zoom is continuous, measured in overmap tiles visible across the chart, and
 * driven by the wheel or the slider under it. It replaced three preset buttons
 * (tactical / sector / whole chart). The presets were always either too tight to
 * see where you were going or too wide to pick a contact out of.
 *
 * The wheel steps multiplicatively and the slider is logarithmic over the same
 * range, so a notch of wheel and a notch of slider feel like the same amount of
 * zoom wherever you are in the range.
 */
const ZOOM_MIN_SPAN = 7;
const ZOOM_WHEEL_STEP = 1.18;

/**
 * Pixels the pointer must travel before a press counts as a pan rather than a
 * click. Small enough that dragging feels immediate, large enough that the hand
 * wobble in a click on a contact glyph doesn't swallow the selection.
 */
const PAN_THRESHOLD = 4;

/**
 * How far inside the chart's edge a contact has to sit for a click on it to
 * count as "already in view" and leave the camera alone. A mark half-clipped
 * against the bezel is on screen in the strict sense and no use to anybody, so
 * the test insets by a fraction of the well rather than taking its raw bounds.
 */
const FOCUS_INSET = 0.08;

/**
 * The camera's pan onto a selected contact. Long enough to read as travel
 * across the chart, a cut leaves the crew working out what they are looking at.
 * And short enough that it is over before the next click.
 */
const FOCUS_PAN_MS = 260;

const clamp = (value: number, low: number, high: number) =>
  Math.max(low, Math.min(high, value));

/**
 * Ceiling on how far ahead a coasting ship is projected. A minute out, at the
 * speeds a slow hull crosses tiles, the projection is stale long before the ship
 * arrives, something will have moved or been steered around.
 */
const DRIFT_HORIZON_MS = 60000;

/** ZONE_TRANSITION_TIME, for the hold the chart draws at a zone line. */
const ZONE_TRANSITION_MS = 10000;

/**
 * Which concentric band a tile falls in, as calculate_zone_for_turf() decides it:
 * distance from the sun over the map's max radius, against the two ring ratios.
 *
 * Every input is server-supplied, `centre` is SSovermap.overmap_centre, the
 * ratios are ZONE_INNER/MIDDLE_RING_RATIO, so this is the same arithmetic the
 * ship runs rather than a client-side guess at it. Only the band index matters;
 * which colour it is doesn't.
 */
const bandOf = (
  tileX: number,
  tileY: number,
  centre: number,
  maxRadius: number,
  ringInner: number,
  ringMiddle: number,
) => {
  const normalized = Math.hypot(tileX - centre, tileY - centre) / maxRadius;
  if (normalized < ringInner) return 2;
  if (normalized < ringMiddle) return 1;
  return 0;
};

type DriftTile = { x: number; y: number; step: number };

type Drift = {
  vector: [number, number];
  /** Tiles the ship crosses from where it is now, nearest first. */
  tiles: DriftTile[];
  /** Where it ends up if nobody touches the controls, and how long that takes. */
  end: DriftTile;
  endMs: number;
  /** One tile crossing, so a cell can label the clock it is reached at. */
  stepMs: number;
  /** The first thing the ship already knows about that the track runs over. */
  intercept: { contact: Contact; step: number; ms: number } | null;
  /**
   * Set when a zone line cuts the projection short. The ship coasts to the last
   * tile on this side of it and stops there for the crossing rather than
   * carrying on, so `tiles` ends at the hold, and this is the tile beyond it.
   * When it is reached is `endMs`, the same as any other end of the projection.
   */
  hold: { x: number; y: number } | null;
};

/** Which contact a tile holding several is named by. Danger outranks scenery. */
const interceptRank = (contact: Contact) =>
  contact.kind === 'hazard' ? 2 : contact.kind === 'nebula' ? 1 : 0;

/**
 * Where the ship ends up with the engines cold.
 *
 * Nothing out here slows a hull down: cut thrust and the velocity you have is
 * the velocity you keep, so "coasting" is a course rather than a pause. The helm
 * used to say nothing at all about it, the chart drew its heading tick off
 * `burnDirection`, so the moment the crew stopped burning the only thing on
 * screen pointing anywhere vanished, while the ship carried on crossing a tile
 * every few seconds.
 *
 * `driftDirection` is taken from the velocity signs rather than the burn, so the
 * steps here are exactly the ones tick_move() will take, wraparound included.
 *
 * The track runs as far as the sensor ring and no further. The console has no
 * business drawing a course through space this hull has no way of knowing
 * anything about (the same reason hazards are never charted beyond sight) and
 * it keeps the projection inside the chart at the zoom the crew actually flies
 * at, so the ghost at the end of it is on screen rather than somewhere off past
 * the edge. It also means the radar tree buys reach on this too: base sensors
 * project the four tiles the crew can already see, tier 3 projects ten.
 */
const useDrift = (contacts: Contact[]): Drift | null => {
  const { data } = useBackend<Data>();
  const {
    x,
    y,
    chart,
    driftDirection,
    moveIntervalMs,
    state,
    burnDirection,
    sensorRange,
  } = data;

  const vector = DIR_VECTOR[driftDirection];
  if (!vector || !moveIntervalMs || state !== 'flying') return null;
  // Nothing to project while the brake is on: decelerate() sheds the whole
  // velocity in about a second, so a minute of coasting is a course the ship is
  // in the middle of cancelling. The readouts say BRAKING there instead.
  if (burnDirection === BURN_STOP) return null;

  const size = chart?.size ?? 51;
  // tick_move()'s own wraparound, in the chart's relative coordinates: the ship
  // flies the band 2..size-1, and a step off either end lands on the far side.
  const wrap = (value: number) =>
    value <= 1 ? size - 1 : value >= size ? 2 : value;

  const steps = clamp(
    Math.round(DRIFT_HORIZON_MS / moveIntervalMs),
    1,
    Math.max(chart?.viewRange ?? 4, sensorRange ?? 4),
  );

  const onTile = new Map<string, Contact>();
  for (const contact of contacts) {
    const key = `${contact.x},${contact.y}`;
    const held = onTile.get(key);
    if (!held || interceptRank(contact) > interceptRank(held)) {
      onTile.set(key, contact);
    }
  }

  const centre = chart?.centre ?? (size - 1) / 2;
  const maxRadius = (size - 1) / 2;
  const ringInner = chart?.ringInner ?? 0.33;
  const ringMiddle = chart?.ringMiddle ?? 0.66;
  const bandAt = (tileX: number, tileY: number) =>
    bandOf(tileX, tileY, centre, maxRadius, ringInner, ringMiddle);

  const tiles: DriftTile[] = [];
  let intercept: Drift['intercept'] = null;
  let hold: Drift['hold'] = null;
  let tileX = x;
  let tileY = y;
  for (let step = 1; step <= steps; step++) {
    const nextX = wrap(tileX + vector[0]);
    const nextY = wrap(tileY + vector[1]);

    // A zone line is a full stop, not a tile the ship passes over: tick_move()
    // hands the step to start_zone_transition(), which kills the velocity and
    // parks the hull on this side for ZONE_TRANSITION_TIME. Projecting straight
    // through would promise a position the ship has no way of reaching on the
    // velocity it currently has.
    if (bandAt(nextX, nextY) !== bandAt(tileX, tileY)) {
      hold = { x: nextX, y: nextY };
      break;
    }

    tileX = nextX;
    tileY = nextY;
    tiles.push({ x: tileX, y: tileY, step });
    const contact = onTile.get(`${tileX},${tileY}`);
    if (contact && !intercept) {
      intercept = { contact, step, ms: step * moveIntervalMs };
    }
  }

  // Falls back to the ship's own tile for a crossing that is one step away.
  // There the projection is "you stop where you are", which is the truth.
  const end = tiles.length ? tiles[tiles.length - 1] : { x, y, step: 0 };

  return {
    vector,
    tiles,
    end,
    endMs: end.step * moveIntervalMs,
    stepMs: moveIntervalMs,
    intercept,
    hold,
  };
};

/** The policy rows, in the order the panel lists them. */
const AUTOPILOT_POLICY_ROWS: { key: keyof AutopilotPrefs; label: string }[] = [
  { key: 'crossMeteor', label: 'Cross asteroid fields' },
  { key: 'crossElectric', label: 'Cross ion storms' },
  { key: 'crossEmp', label: 'Cross EMP clouds' },
  { key: 'avoidHostiles', label: 'Avoid known hostiles' },
  { key: 'zoneCaution', label: 'Prefer safer zones' },
  { key: 'hazardLanding', label: 'Allow hazardous destination' },
];

/**
 * The autopilot's flight-policy checkboxes, opened from the gear beside the
 * autopilot readout. Editable engaged or idle; a change while a course is
 * being flown re-plans it on the spot under the new rules (server side, see
 * set_autopilot_pref in ship_autopilot.dm).
 */
const AutopilotPolicyPanel = () => {
  const { act, data } = useBackend<Data>();
  const locked = useLocked();
  const prefs = data.autopilot?.prefs;
  if (!prefs) return null;
  return (
    <div className="Helm__policyPanel">
      <div className="Helm__policyTitle">FLIGHT POLICY</div>
      {AUTOPILOT_POLICY_ROWS.map((row) => (
        <label key={row.key} className="Helm__policyRow">
          <input
            type="checkbox"
            checked={!!prefs[row.key]}
            disabled={locked}
            onChange={(event) =>
              act('autopilot_pref', {
                key: row.key,
                value: event.currentTarget.checked ? 1 : 0,
              })
            }
          />
          {row.label}
          {row.key === 'crossMeteor' && !!data.autopilot?.shieldsActive && (
            <span className="Helm__policyHint">
              Shields online — impacts absorbed
            </span>
          )}
        </label>
      ))}
    </div>
  );
};

const Chart = () => {
  const { act, data } = useBackend<Data>();
  const {
    x,
    y,
    chart,
    sensorRange,
    transmissions = [],
    burnDirection,
    driftDirection,
    speed,
    heading,
    eta,
    moveIntervalMs,
    state,
    autopilot,
  } = data;

  const viewRange = chart?.viewRange ?? 4;
  const waypoints = useContacts();
  const drift = useDrift(waypoints);
  const { selected, select } = useContext(Selection);
  const locked = useLocked();

  // Hover fills the readout below the chart; right-click pins the shared action
  // menu at the cursor. The menu carries both the contact under the cursor (if
  // there was one) and the tile it was over, because plotting a course is an
  // action on the position rather than on any mark.
  const [hovered, setHovered] = useState<string | null>(null);
  // The flight-policy panel, opened from the gear beside the autopilot readout.
  const [showPolicy, setShowPolicy] = useState(false);
  const openActionMenu = useContext(MenuControl);
  const viewportRef = useRef<HTMLDivElement>(null);
  const cameraRef = useRef<SVGGElement>(null);

  const byKey = (key: string | null) =>
    key ? waypoints.find((contact) => contactKey(contact) === key) : undefined;
  const hoveredContact = byKey(hovered);

  // Docking, jumping and recovery move the ship a long way at once; sliding the
  // camera across half the sector for those reads as a bug, so they cut.
  const lastPos = useRef<{ x: number; y: number } | null>(null);
  const previous = lastPos.current;
  const teleported =
    !previous || Math.hypot(x - previous.x, y - previous.y) > 2.5;
  useEffect(() => {
    lastPos.current = { x, y };
  });

  const size = chart?.size ?? 51;
  const extent = size * UNIT;
  const toX = (tileX: number) => tileX * UNIT - UNIT / 2;
  const toY = (tileY: number) => (size + 1 - tileY) * UNIT - UNIT / 2;

  const [span, setSpan] = useState(13);
  const maxSpan = size;
  const zoomSpan = clamp(span, ZOOM_MIN_SPAN, maxSpan);
  const scale = extent / (zoomSpan * UNIT);

  // Contact glyphs sit in a group that counter-scales against the camera zoom
  // (see ContactMark/TransmissionPulse/PlottedCourse below), which is what
  // keeps a mark legible at any zoom instead of shrinking to a dot at max
  // zoom-in. Left uncorrected, though, that counter-scale is exact, 1/scale
  // exactly cancels the camera's scale(${scale}), so a glyph is the IDENTICAL
  // screen size zoomed all the way out as zoomed all the way in. At the
  // zoomed-out end that reads as clutter: dozens of full-size glyphs packed
  // into the same screen space that one tile's worth occupies up close.
  // markScale blends the counter-scale toward the raw camera scale as the
  // view widens, so glyphs still shrink somewhat with distance like everything
  // else on the chart, while staying at their fully-compensated, always-legible
  // size once zoomed in past the midpoint.
  const zoomBlend = clamp(
    (zoomSpan - ZOOM_MIN_SPAN) / (maxSpan - ZOOM_MIN_SPAN),
    0,
    1,
  );
  const MARK_ZOOM_OUT_FLOOR = 0.4;
  const markScale = scale / (1 - zoomBlend * (1 - MARK_ZOOM_OUT_FLOOR));

  // React attaches wheel handlers passively at the root, so preventDefault from
  // an onWheel prop is ignored and the BYOND window scrolls instead of zooming.
  // The listener has to be bound natively to be non-passive.
  useEffect(() => {
    const viewport = viewportRef.current;
    if (!viewport) return;
    const onWheel = (event: WheelEvent) => {
      event.preventDefault();
      const step = event.deltaY > 0 ? ZOOM_WHEEL_STEP : 1 / ZOOM_WHEEL_STEP;
      setSpan((current) =>
        clamp(current * step, ZOOM_MIN_SPAN, maxSpan),
      );
    };
    viewport.addEventListener('wheel', onWheel, { passive: false });
    return () => viewport.removeEventListener('wheel', onWheel);
  }, [maxSpan]);

  // Zoomed in, the chart follows the ship. Zoomed most of the way out, following
  // the ship would push the map's own edges into the middle of the viewport, so
  // the focus eases across to the centre of the sector over the last of the range.
  const centreBlend = clamp((zoomSpan - maxSpan * 0.6) / (maxSpan * 0.4), 0, 1);
  const followX = toX(x) + (extent / 2 - toX(x)) * centreBlend;
  const followY = toY(y) + (extent / 2 - toY(y)) * centreBlend;

  // Dragging the chart parks the camera on a map position instead of on the ship,
  // which is the whole point of looking around: the sector holds still and the
  // ship flies across it. Recentre re-attaches.
  const [anchor, setAnchor] = useState<{ x: number; y: number } | null>(null);
  const focusX = anchor ? anchor.x : followX;
  const focusY = anchor ? anchor.y : followY;

  /**
   * Bring a contact picked in the register onto the chart.
   *
   * Anchoring on it is the same thing a drag does, so the Recentre button
   * appears and says how to get back to the ship. A contact that is already on
   * screen is left alone: the mark highlights, the camera keeps following the
   * hull, and nothing lurches under a crew that could see the thing all along.
   *
   * Whether it is on screen is measured through the camera's own on-screen
   * matrix rather than worked back out of the zoom span. The chart is a square
   * viewBox sliced into a well half again as wide as it is tall, so the tiles
   * visible per axis differ and the slice crops the top and bottom, the matrix
   * already accounts for both, and for whatever the window has been resized to.
   */
  const { request: focusRequest } = useContext(ChartFocus);
  const [panEase, setPanEase] = useState(false);
  const servedFocus = useRef(0);
  const easeTimer = useRef<ReturnType<typeof setTimeout> | null>(null);
  const stopPanEase = () => {
    if (easeTimer.current) clearTimeout(easeTimer.current);
    easeTimer.current = null;
    setPanEase(false);
  };

  useEffect(() => {
    if (!focusRequest || focusRequest.nonce === servedFocus.current) return;
    servedFocus.current = focusRequest.nonce;

    const target = { x: toX(focusRequest.x), y: toY(focusRequest.y) };
    const camera = cameraRef.current;
    const viewport = viewportRef.current;
    const svg = camera?.ownerSVGElement;
    const matrix = camera?.getScreenCTM();

    if (camera && svg && viewport && matrix) {
      const box = viewport.getBoundingClientRect();
      const point = svg.createSVGPoint();
      point.x = target.x;
      point.y = target.y;
      const screen = point.matrixTransform(matrix);
      const inset = Math.min(box.width, box.height) * FOCUS_INSET;
      if (
        screen.x >= box.left + inset &&
        screen.x <= box.right - inset &&
        screen.y >= box.top + inset &&
        screen.y <= box.bottom - inset
      ) {
        return;
      }
    }

    setAnchor(target);
    setPanEase(true);
    if (easeTimer.current) clearTimeout(easeTimer.current);
    easeTimer.current = setTimeout(() => {
      easeTimer.current = null;
      setPanEase(false);
    }, FOCUS_PAN_MS);
  }, [focusRequest]);

  // A console closed mid-pan would otherwise set state on a dead component.
  useEffect(() => () => {
    if (easeTimer.current) clearTimeout(easeTimer.current);
  }, []);

  // An anchored camera doesn't move on its own, so there is nothing to glide and
  // a transition would only smear the drag a frame behind the cursor. The
  // exception is the pan onto a selected contact, which is the one time the
  // anchor itself moves and wants to be seen moving.
  const glide = panEase
    ? `transform ${FOCUS_PAN_MS}ms ease-out`
    : anchor || teleported || !moveIntervalMs || state !== 'flying'
      ? 'none'
      : `transform ${moveIntervalMs}ms linear`;

  // Zoom and follow are split across two groups on purpose: the follow pan glides
  // over the move interval, but the zoom must land immediately. Sharing one
  // transform would stretch a wheel notch out over a slow ship's whole tile
  // crossing, which reads as the console lagging.
  const zoomTransform = `translate(${extent / 2}px, ${extent / 2}px) scale(${scale})`;
  const followTransform = `translate(${-focusX}px, ${-focusY}px)`;

  /** The overmap tile under a mouse event, via the chart's own current matrix. */
  const tileFromEvent = (event: React.MouseEvent) => {
    const camera = cameraRef.current;
    const svg = camera?.ownerSVGElement;
    if (!camera || !svg) return null;
    const matrix = camera.getScreenCTM();
    if (!matrix) return null;
    const point = svg.createSVGPoint();
    point.x = event.clientX;
    point.y = event.clientY;
    const local = point.matrixTransform(matrix.inverse());
    return {
      x: clamp(Math.round((local.x + UNIT / 2) / UNIT), 2, size - 1),
      y: clamp(Math.round(size + 1 - (local.y + UNIT / 2) / UNIT), 2, size - 1),
    };
  };

  /**
   * Drag-to-pan, on either the left or the middle button.
   *
   * Nothing happens until the pointer has travelled PAN_THRESHOLD, so a plain
   * left click still selects the contact under it, only a real drag is treated
   * as a pan. The pixel delta is divided by the camera's own on-screen matrix
   * rather than by a scale we recompute, so panning tracks the cursor exactly at
   * any zoom.
   */
  const panState = useRef<{
    pointerId: number;
    /** Where the press landed, for the click-vs-drag threshold. */
    startX: number;
    startY: number;
    /** Where the last move landed. Deltas are incremental from here, not from
     *  the press, so zooming mid-drag can't make the map jump. */
    lastX: number;
    lastY: number;
    moved: boolean;
  } | null>(null);
  // Set for the duration of one click after a drag, so the mouseup that ends a
  // pan doesn't also select whatever the cursor happens to be resting on.
  const didPan = useRef(false);

  const startPan = (event: React.PointerEvent) => {
    if (event.button !== 0 && event.button !== 1) return;
    // The zoom slider and the cancel button live inside the viewport; dragging
    // those is not dragging the chart.
    if ((event.target as Element)?.closest?.('.Helm__zoomRow, button, input')) {
      return;
    }
    if (!cameraRef.current) return;
    // Middle-drag is autoscroll in a browser; the BYOND client is one.
    if (event.button === 1) event.preventDefault();
    // A hand on the chart outranks a pan the console started on its own: left
    // running, the transition would drag the map a quarter-second behind the
    // cursor for the rest of the ease.
    stopPanEase();
    panState.current = {
      pointerId: event.pointerId,
      startX: event.clientX,
      startY: event.clientY,
      lastX: event.clientX,
      lastY: event.clientY,
      moved: false,
    };
  };

  const movePan = (event: React.PointerEvent) => {
    const pan = panState.current;
    if (!pan || pan.pointerId !== event.pointerId) return;
    if (!pan.moved) {
      const travelled = Math.hypot(
        event.clientX - pan.startX,
        event.clientY - pan.startY,
      );
      if (travelled < PAN_THRESHOLD) return;
      pan.moved = true;
      didPan.current = true;
      event.currentTarget.setPointerCapture(pan.pointerId);
    }

    // Read live rather than caching: the group's horizontal scale is pixels per
    // chart unit, and dividing the pixel delta by it is what makes the map track
    // the cursor exactly 1:1 at any zoom.
    const pixelsPerUnit = cameraRef.current?.getScreenCTM()?.a || 1;
    const dx = (event.clientX - pan.lastX) / pixelsPerUnit;
    const dy = (event.clientY - pan.lastY) / pixelsPerUnit;
    pan.lastX = event.clientX;
    pan.lastY = event.clientY;

    // Functional form on purpose: several pointermove events can land before a
    // re-render, and each has to build on the last one's offset rather than on
    // the focus this render closed over.
    setAnchor((current) => ({
      x: (current?.x ?? focusX) - dx,
      y: (current?.y ?? focusY) - dy,
    }));
  };

  const endPan = (event: React.PointerEvent) => {
    const pan = panState.current;
    if (!pan || pan.pointerId !== event.pointerId) return;
    if (pan.moved && event.currentTarget.hasPointerCapture(pan.pointerId)) {
      event.currentTarget.releasePointerCapture(pan.pointerId);
    }
    panState.current = null;
  };

  const openMenu = (event: React.MouseEvent, key: string | null) => {
    const contact = byKey(key);
    // A contact's own coordinates beat the cursor's: clicking the edge of a glyph
    // shouldn't plot a course to the tile next door.
    const tile = contact
      ? { x: contact.x, y: contact.y }
      : tileFromEvent(event);
    if (!tile) return;
    openActionMenu(event, key, tile);
  };

  const centre = chart?.centre ?? Math.round((size + 1) / 2);
  const maxRadius = (size - 1) / 2;
  const rings: [number, string][] = [
    [maxRadius, '#59b871'],
    [(chart?.ringMiddle ?? 0.66) * maxRadius, '#d9a230'],
    [(chart?.ringInner ?? 0.33) * maxRadius, '#cf4a38'],
  ];

  const vector = DIR_VECTOR[burnDirection];
  // The nose follows the burn while the engines are lit and the direction of
  // travel once they are cold. Off `burnDirection` alone, a coasting or braking
  // ship's token swung back to due north and sat there pointing the wrong way
  // for the whole crossing. Read straight off the dir rather than off the drift
  // projection, which is deliberately absent under braking.
  const nose = vector ?? DIR_VECTOR[driftDirection];
  const heeling = nose ? (Math.atan2(nose[0], nose[1]) * 180) / Math.PI : 0;

  // Arrival clock for a plotted course, off the planned path's own length rather
  // than the distance to the destination: the route detours around storms and
  // standoff bands, and the tiles it spends doing that are tiles the ship flies.
  // PlottedCourse deliberately draws no per-step clocks, on the grounds that the
  // destination one lives here. It just never did until now.
  const courseEta =
    moveIntervalMs && autopilot?.remaining
      ? clockOf(autopilot.remaining * moveIntervalMs)
      : null;

  const gridLines: number[] = [];
  for (let i = 0; i <= size; i += 5) gridLines.push(i);

  // The overmap moves in whole tiles, so the projection marks are tile-shaped,
  // and a tile-shaped mark on a five-tile grid reads as an arbitrary rectangle
  // floating in open space. The fine grid is the lattice it sits on. Only drawn
  // once zoomed in far enough for the lines to be distinguishable from each
  // other, since at full zoom-out fifty-one of them per axis is a flat wash.
  const fineGrid: number[] = [];
  if (zoomSpan <= TILE_DETAIL_SPAN) {
    for (let i = 0; i <= size; i++) fineGrid.push(i);
  }

  return (
    <div
      className={`Helm__viewport ${anchor ? 'Helm--panned' : ''}`}
      ref={viewportRef}
      // Right-clicking bare chart opens the position menu rather than handing the
      // client's own context menu to a player mid-manoeuvre.
      onContextMenu={(event) => openMenu(event, null)}
      onPointerDown={startPan}
      onPointerMove={movePan}
      onPointerUp={endPan}
      onPointerCancel={endPan}
      // Swallowed in the capture phase so the click that ends a drag never
      // reaches a contact underneath it.
      onClickCapture={(event) => {
        if (!didPan.current) return;
        didPan.current = false;
        event.stopPropagation();
      }}
      // Closing the menu is the console root's job, the click bubbles to it.
      onDoubleClick={() => setAnchor(null)}
    >
      <svg
        viewBox={`0 0 ${extent} ${extent}`}
        preserveAspectRatio="xMidYMid slice"
        role="img"
        aria-label="Overmap navigation chart"
      >
        <defs>
          <radialGradient id="helm-sunglow">
            <stop offset="0%" stopColor="#f2a341" stopOpacity="0.35" />
            <stop offset="100%" stopColor="#f2a341" stopOpacity="0" />
          </radialGradient>
        </defs>

        <g style={{ ...SVG_ORIGIN, transform: zoomTransform }}>
        <g
          className="Helm__camera"
          ref={cameraRef}
          style={{ ...SVG_ORIGIN, transform: followTransform, transition: glide }}
        >
          {/*
            Everything decorative, behind the marks and deaf to the mouse. The
            zone discs are filled, and a filled SVG shape takes hits across its
            whole area, without this they'd eat right-clicks meant for the chart.
          */}
          <g pointerEvents="none">
          {rings.map(([radius, colour]) => (
            <g key={colour}>
              <circle
                cx={toX(centre)}
                cy={toY(centre)}
                r={radius * UNIT}
                fill={colour}
                fillOpacity={0.06}
              />
              <circle
                cx={toX(centre)}
                cy={toY(centre)}
                r={radius * UNIT}
                fill="none"
                stroke={colour}
                strokeOpacity={0.3}
                strokeDasharray="5 4"
                vectorEffect="non-scaling-stroke"
              />
            </g>
          ))}

          <g stroke="#74c8dd" strokeOpacity={0.028} strokeWidth={0.4}>
            {fineGrid.map((i) => (
              <line
                key={`fv${i}`}
                x1={i * UNIT}
                y1={0}
                x2={i * UNIT}
                y2={extent}
              />
            ))}
            {fineGrid.map((i) => (
              <line
                key={`fh${i}`}
                x1={0}
                y1={i * UNIT}
                x2={extent}
                y2={i * UNIT}
              />
            ))}
          </g>

          <g stroke="#74c8dd" strokeOpacity={0.055} strokeWidth={0.6}>
            {gridLines.map((i) => (
              <line
                key={`v${i}`}
                x1={i * UNIT}
                y1={0}
                x2={i * UNIT}
                y2={extent}
              />
            ))}
            {gridLines.map((i) => (
              <line
                key={`h${i}`}
                x1={0}
                y1={i * UNIT}
                x2={extent}
                y2={i * UNIT}
              />
            ))}
          </g>

          <rect
            x={0}
            y={0}
            width={extent}
            height={extent}
            fill="none"
            stroke="#3a474b"
            vectorEffect="non-scaling-stroke"
          />

          <circle
            cx={toX(centre)}
            cy={toY(centre)}
            r={60}
            fill="url(#helm-sunglow)"
          />
          <circle cx={toX(centre)} cy={toY(centre)} r={7} fill="#f2a341" />
          </g>

          {/*
            Under the plotted course: where a course is flying the ship, the
            drift is only ever a step behind it, and the two lines lie on top of
            each other. Amber, because this is the ship's own state, the green
            line is where it means to go, the amber one is where it is going.
          */}
          {!!drift && (
            <DriftTrack
              drift={drift}
              from={[x, y]}
              toX={toX}
              toY={toY}
              scale={markScale}
              span={zoomSpan}
            />
          )}

          {!!autopilot?.engaged && (
            <PlottedCourse
              from={[x, y]}
              path={autopilot.path ?? []}
              toX={toX}
              toY={toY}
              scale={markScale}
            />
          )}

          {/*
            Hails, under the contact marks so a pulse never swallows a click.
            The ring expands and fades in CSS; a transmission that has aged out
            simply stops arriving in the live set and the mark disappears.
          */}
          {transmissions
            .filter((hail) => hail.live)
            .map((hail, index) => (
              <TransmissionPulse
                key={`${hail.x}-${hail.y}-${hail.age}-${index}`}
                hail={hail}
                cx={toX(hail.x)}
                cy={toY(hail.y)}
                scale={markScale}
              />
            ))}

          {waypoints.map((contact) => {
            const key = contactKey(contact);
            return (
              <ContactMark
                key={key}
                contact={contact}
                cx={toX(contact.x)}
                cy={toY(contact.y)}
                scale={markScale}
                inRange={!!contact.live}
                selected={selected === key}
                onSelect={() => select(key)}
                onHover={(entered) =>
                  setHovered((current) =>
                    entered ? key : current === key ? null : current,
                  )
                }
                onMenu={(event) => openMenu(event, key)}
              />
            );
          })}

          {/*
            Deaf to the mouse. The view ring below is a filled disc four tiles
            across drawn on top of every mark inside it, so while it took hits it
            silently swallowed hover and right-click for every contact the ship
            was closest to, the ones the crew most wants to inspect.
          */}
          <g
            className="Helm__shipToken"
            pointerEvents="none"
            style={{
              ...SVG_ORIGIN,
              transform: `translate(${toX(x)}px, ${toY(y)}px)`,
              transition: glide,
            }}
          >
            {/*
              Two rings, and the gap between them is the radar tree made visible.
              Solid inner: what the crew can see, free and fixed. Dashed outer:
              how far a scan reaches, everything charted came from this band.
              At base radar they sit on top of each other, which is the honest
              picture of a ship that has researched nothing.
            */}
            <circle
              r={viewRange * UNIT}
              fill="#74c8dd"
              fillOpacity={0.05}
              stroke="#74c8dd"
              strokeOpacity={0.34}
              vectorEffect="non-scaling-stroke"
            />
            {sensorRange > viewRange && (
              <circle
                r={sensorRange * UNIT}
                fill="none"
                stroke="#74c8dd"
                strokeOpacity={0.22}
                strokeDasharray="3 4"
                vectorEffect="non-scaling-stroke"
              />
            )}
            <g style={{ ...SVG_ORIGIN, transform: `scale(${1 / scale})` }}>
              <circle r={12} fill="#f2a341" fillOpacity={0.1} />
              {!!vector && !!speed && (
                <line
                  x1={0}
                  y1={0}
                  x2={(vector[0] / Math.hypot(...vector)) * (14 + speed * 9)}
                  y2={(-vector[1] / Math.hypot(...vector)) * (14 + speed * 9)}
                  stroke="#f2a341"
                  strokeWidth={1.6}
                  strokeDasharray="4 3"
                  strokeOpacity={0.85}
                />
              )}
              <path
                d="M0,-7 L5,6 L0,3 L-5,6 Z"
                fill="#f2a341"
                transform={`rotate(${heeling})`}
              />
            </g>
          </g>
        </g>
        </g>
      </svg>

      <div className="Helm__hud Helm--tl">
        <div className="Helm__hudLine">
          <span className="Helm__hudKey">HDG</span>{' '}
          {burnDirection === BURN_STOP
            ? 'BRAKING'
            : burnDirection !== BURN_NONE
              ? heading
              : drift
                ? // Cold engines and a moving ship is a course, not a stop, and
                  // this line called it HOLDING either way.
                  `DRIFT ${bearingOf(drift.vector[0], drift.vector[1])}`
                : 'HOLDING'}
        </div>
        <div className="Helm__hudLine">
          <span className="Helm__hudKey">POS</span> {String(x).padStart(2, '0')}{' '}
          / {String(y).padStart(2, '0')}
        </div>
        {!!drift && (
          // Where the ship ends up on the velocity it already has, engines or
          // no engines. The track on the chart says which way; this says where.
          <div className="Helm__hudLine Helm--drift">
            <span className="Helm__hudKey">ENDS</span>{' '}
            {String(drift.end.x).padStart(2, '0')} /{' '}
            {String(drift.end.y).padStart(2, '0')} · {clockOf(drift.endMs)}
          </div>
        )}
        {!!drift?.intercept && (
          <div
            className={`Helm__hudLine ${
              drift.intercept.contact.kind === 'hazard'
                ? 'Helm--driftHazard'
                : 'Helm--drift'
            }`}
          >
            <span className="Helm__hudKey">PATH</span>{' '}
            {drift.intercept.contact.name.toUpperCase()} ·{' '}
            {clockOf(drift.intercept.ms)}
          </div>
        )}
      </div>
      <div className="Helm__hud Helm--tr">
        <div className="Helm__hudBig">{speed?.toFixed(1) ?? '0.0'}</div>
        {/*
          `eta` is the movement timer's own clock, the next TILE, not the next
          anywhere. Calling it ETA next to a chart full of destinations invited
          exactly one reading, and it is the wrong one: it never counts toward a
          contact, and at a steady coast it cycles the same figure forever. The
          arrival clocks live on the contacts themselves (see useTravelClock).
        */}
        <div className="Helm__hudLine">
          <span className="Helm__hudKey">SPM · TILE</span> {eta || '-'}
        </div>
      </div>
      {!!hoveredContact && <ContactReadout contact={hoveredContact} />}

      <div className="Helm__hud Helm--bl">
        {!!showPolicy && <AutopilotPolicyPanel />}
        <div className="Helm__hudLine" style={{ color: '#3d6a76' }}>
          <span className="Helm__hudKey">SENSOR</span> {sensorRange} TILES
        </div>
        {!!autopilot?.engaged && (
          <div className="Helm__course">
            <span className="Helm__courseLabel">
              AUTO · {autopilot.label ?? 'plotted position'}
            </span>
            <span className="Helm__courseDist">
              {autopilot.remaining ?? 0} tiles
              {!!courseEta && ` · ${courseEta}`}
            </span>
            <button
              type="button"
              className="Helm__btn"
              disabled={locked}
              title="Stand the autopilot down and take manual control"
              onClick={() => act('autopilot_cancel')}
            >
              Cancel
            </button>
            <button
              type="button"
              className={`Helm__btn Helm__policyGear${showPolicy ? ' Helm--selected' : ''}`}
              title="Autopilot flight policy"
              onClick={() => setShowPolicy((open) => !open)}
            >
              ⚙
            </button>
          </div>
        )}
        {!autopilot?.engaged && (
          // The gear stays reachable with no course engaged; the readout line
          // only appears once there is an outcome to report.
          <div className="Helm__course">
            <span className="Helm__courseStatus" style={{ marginTop: 0 }}>
              {autopilot?.status
                ? `AUTOPILOT OFF · ${autopilot.status}`
                : 'AUTOPILOT'}
            </span>
            <button
              type="button"
              className={`Helm__btn Helm__policyGear${showPolicy ? ' Helm--selected' : ''}`}
              title="Autopilot flight policy"
              onClick={() => setShowPolicy((open) => !open)}
            >
              ⚙
            </button>
          </div>
        )}
      </div>

      <div className="Helm__zoomRow">
        {/*
          Only offered once the camera is actually off the ship. A permanent
          re-centre button on a chart that is already centred is a dead control.
        */}
        {!!anchor && (
          <button
            type="button"
            className="Helm__btn Helm__recentre"
            title="Snap the chart back onto the ship (or double-click the chart)"
            onClick={() => setAnchor(null)}
          >
            Recentre
          </button>
        )}
        <span className="Helm__zoomLabel">{Math.round(zoomSpan)} tiles</span>
        <input
          type="range"
          className="Helm__zoomSlider"
          aria-label="Chart zoom"
          min={0}
          max={100}
          step={1}
          value={Math.round(
            (Math.log(zoomSpan / ZOOM_MIN_SPAN) /
              Math.log(maxSpan / ZOOM_MIN_SPAN)) *
              100,
          )}
          onChange={(event) =>
            setSpan(
              ZOOM_MIN_SPAN *
                (maxSpan / ZOOM_MIN_SPAN) **
                  (Number(event.currentTarget.value) / 100),
            )
          }
        />
      </div>
    </div>
  );
};

/**
 * The drift track: the tiles the ship crosses from here on the velocity it
 * already has, and a ghost of it at the end of the horizon.
 *
 * Segments split on wraparound for the same reason PlottedCourse's do, a drift
 * that leaves one edge and re-enters the other would otherwise draw one line
 * straight back across the whole chart.
 */
const DriftTrack = (props: {
  drift: Drift;
  from: [number, number];
  toX: (tile: number) => number;
  toY: (tile: number) => number;
  scale: number;
  span: number;
}) => {
  const { drift, from, toX, toY, scale, span } = props;
  const { tiles, end, intercept, hold } = drift;
  // A crossing one step away leaves no tiles to draw, but the hold still has to
  // be marked, that case is precisely the one the crew most needs to see.
  if (!tiles.length && !hold) return null;

  const segments: string[][] = [];
  let current: string[] = [`${toX(from[0])},${toY(from[1])}`];
  let previous = from;
  for (const tile of tiles) {
    if (
      Math.abs(tile.x - previous[0]) > 1 ||
      Math.abs(tile.y - previous[1]) > 1
    ) {
      if (current.length > 1) segments.push(current);
      current = [];
    }
    current.push(`${toX(tile.x)},${toY(tile.y)}`);
    previous = [tile.x, tile.y];
  }
  if (current.length > 1) segments.push(current);

  const heeling =
    (Math.atan2(drift.vector[0], drift.vector[1]) * 180) / Math.PI;
  const hazard = intercept?.contact.kind === 'hazard';

  const detailed = span <= TILE_DETAIL_SPAN;

  return (
    <g className="Helm__drift" pointerEvents="none">
      {/*
        The thread between the cells. It carries the whole reading when the tiles
        are too small to mark individually, and drops back to a hint once they
        aren't, at that zoom the cells say everything it does, and a dashed line
        run through the middle of each of them only fights their clocks.
      */}
      {segments.map((segment) => (
        <polyline
          key={segment[0]}
          points={segment.join(' ')}
          fill="none"
          stroke="#f2a341"
          strokeWidth={1.2}
          strokeOpacity={detailed ? 0.18 : 0.42}
          strokeDasharray="3 6"
          vectorEffect="non-scaling-stroke"
        />
      ))}

      {/*
        One cell per tile the ship crosses.

        Drawn in map space at tile size rather than counter-scaled like the
        glyphs: a mark that means "this tile" has to be the size of the tile at
        every zoom, or it stops being an answer to which tile. Zoomed in far
        enough for the cell to hold it, each one is labelled with the clock the
        ship reaches it at, the per-tile version of the single endpoint ETA the
        HUD line carries.

        The track fades along its length. The near tiles are the ones a crew
        still has time to steer on, and the middle of a minute-long projection
        is the part most likely to be wrong by the time it arrives. The last
        tile is exempt: it is the answer to where the ship ends up, which is the
        question the whole track exists to answer, and fading it hardest for
        being furthest away buries exactly that.
      */}
      {tiles.map((tile) => {
        const struck = intercept?.step === tile.step;
        const colour = struck && hazard ? '#cf4a38' : '#f2a341';
        const fade =
          tile.step === end.step
            ? 1
            : 1 - (0.5 * (tile.step - 1)) / Math.max(tiles.length - 1, 1);
        return (
          <g key={`cell-${tile.x}-${tile.y}-${tile.step}`}>
            <rect
              x={toX(tile.x) - UNIT / 2 + DRIFT_INSET}
              y={toY(tile.y) - UNIT / 2 + DRIFT_INSET}
              width={UNIT - DRIFT_INSET * 2}
              height={UNIT - DRIFT_INSET * 2}
              rx={0.7}
              fill={colour}
              fillOpacity={(struck ? 0.22 : 0.08) * fade}
              stroke={colour}
              strokeOpacity={(struck ? 0.95 : 0.5) * fade}
              strokeWidth={struck ? 1.4 : 1}
              vectorEffect="non-scaling-stroke"
            />
            {/*
              Along the bottom edge rather than through the middle: a contact
              glyph sits at the centre of its tile, and the tile the crew most
              wants the clock for is the one with something on it.
            */}
            {!!detailed && (
              <text
                x={toX(tile.x)}
                y={toY(tile.y) + UNIT / 2 - DRIFT_INSET - 0.5}
                textAnchor="middle"
                fill={colour}
                fillOpacity={0.8 * fade}
                fontSize={UNIT * 0.28}
                fontFamily="ui-monospace, monospace"
              >
                {clockOf(tile.step * drift.stepMs)}
              </text>
            )}
          </g>
        );
      })}

      {/*
        The zone line the track stops at. Drawn as a barred cell on the far side
        rather than as another step: the ship does not go there on the velocity
        it has, it stops short and spends ZONE_TRANSITION_TIME sitting still
        first. Without this the projection just ended in open space for no
        visible reason.
      */}
      {!!hold && (
        <g>
          <rect
            x={toX(hold.x) - UNIT / 2 + DRIFT_INSET}
            y={toY(hold.y) - UNIT / 2 + DRIFT_INSET}
            width={UNIT - DRIFT_INSET * 2}
            height={UNIT - DRIFT_INSET * 2}
            rx={0.7}
            fill="none"
            stroke="#74c8dd"
            strokeOpacity={0.65}
            strokeWidth={1.1}
            strokeDasharray="2 2"
            vectorEffect="non-scaling-stroke"
          />
          {!!detailed && (
            <text
              x={toX(hold.x)}
              y={toY(hold.y) + UNIT / 2 - DRIFT_INSET - 0.5}
              textAnchor="middle"
              fill="#74c8dd"
              fillOpacity={0.85}
              fontSize={UNIT * 0.26}
              fontFamily="ui-monospace, monospace"
            >
              +{ZONE_TRANSITION_MS / 1000}s
            </text>
          )}
        </g>
      )}

      {!!intercept && (
        <g
          transform={`translate(${toX(intercept.contact.x)},${toY(intercept.contact.y)})`}
        >
          <g style={{ ...SVG_ORIGIN, transform: `scale(${1 / scale})` }}>
            <circle
              r={11}
              fill="none"
              stroke={hazard ? '#cf4a38' : '#f2a341'}
              strokeWidth={1.2}
              strokeOpacity={hazard ? 0.9 : 0.5}
              strokeDasharray="4 3"
            />
          </g>
        </g>
      )}

      {/*
        The ghost: the hull's own silhouette, hollow, where it ends up. Skipped
        when the crossing is the very next step, since "where it ends up" is the
        tile it is already on and the ghost would sit on top of the real token.
      */}
      {!!tiles.length && (
      <g transform={`translate(${toX(end.x)},${toY(end.y)})`}>
        <g style={{ ...SVG_ORIGIN, transform: `scale(${1 / scale})` }}>
          <path
            d="M0,-7 L5,6 L0,3 L-5,6 Z"
            fill="none"
            stroke="#f2a341"
            strokeWidth={1.2}
            strokeOpacity={0.55}
            transform={`rotate(${heeling})`}
          />
          {/*
            Zoomed out past the per-tile clocks, the ghost carries the endpoint
            one on its own. Otherwise the whole projection loses its timing at
            exactly the zoom where the crew is looking furthest ahead.
          */}
          {span > TILE_DETAIL_SPAN && (
            <text
              y={17}
              textAnchor="middle"
              fill="#f2a341"
              fillOpacity={0.6}
              fontSize={9}
              fontFamily="ui-monospace, monospace"
            >
              {clockOf(drift.endMs)}
            </text>
          )}
        </g>
      </g>
      )}
    </g>
  );
};

/**
 * The plotted course, drawn from the ship along the remaining path.
 *
 * Split into segments wherever consecutive steps aren't adjacent: the overmap
 * wraps at its edges and the route planner uses that, so a course that leaves one
 * side and re-enters the other would otherwise draw one line straight back across
 * the whole chart.
 */
const PlottedCourse = (props: {
  from: [number, number];
  path: [number, number][];
  toX: (tile: number) => number;
  toY: (tile: number) => number;
  scale: number;
}) => {
  const { from, path, toX, toY, scale } = props;
  if (!path.length) return null;

  const segments: string[][] = [];
  let current: string[] = [`${toX(from[0])},${toY(from[1])}`];
  let previous = from;
  for (const point of path) {
    if (
      Math.abs(point[0] - previous[0]) > 1 ||
      Math.abs(point[1] - previous[1]) > 1
    ) {
      if (current.length > 1) segments.push(current);
      current = [];
    }
    current.push(`${toX(point[0])},${toY(point[1])}`);
    previous = point;
  }
  if (current.length > 1) segments.push(current);

  const destination = path[path.length - 1];

  return (
    <g className="Helm__plot" pointerEvents="none">
      {segments.map((segment) => (
        <polyline
          key={segment[0]}
          points={segment.join(' ')}
          fill="none"
          stroke="#59b871"
          strokeWidth={1.5}
          strokeOpacity={0.7}
          strokeDasharray="6 5"
          vectorEffect="non-scaling-stroke"
        />
      ))}

      {/*
        The route's own tiles, on the same footing as the drift's: a course is
        a list of tiles the ship will stand on, and the line between them is a
        drawing convenience rather than anything the overmap does.

        No clocks here. A plotted course runs as far as the crew asked for
        rather than to the sensor horizon, so labelling every step of a
        sector-crossing route buries the chart it is drawn on; the remaining
        count and the destination ETA live in the autopilot readout instead.
      */}
      {path.map((point, index) => (
        <rect
          key={`plot-${point[0]}-${point[1]}-${index}`}
          x={toX(point[0]) - UNIT / 2 + PLOT_INSET}
          y={toY(point[1]) - UNIT / 2 + PLOT_INSET}
          width={UNIT - PLOT_INSET * 2}
          height={UNIT - PLOT_INSET * 2}
          rx={0.7}
          fill="#59b871"
          fillOpacity={0.06}
          stroke="#59b871"
          strokeOpacity={0.45}
          strokeWidth={1}
          vectorEffect="non-scaling-stroke"
        />
      ))}

      <g
        transform={`translate(${toX(destination[0])},${toY(destination[1])})`}
      >
        <g style={{ ...SVG_ORIGIN, transform: `scale(${1 / scale})` }}>
          <circle
            className="Helm__plotTarget"
            r={9}
            fill="none"
            stroke="#59b871"
            strokeWidth={1.4}
          />
          <path
            d="M-4,0 H4 M0,-4 V4"
            stroke="#59b871"
            strokeWidth={1.2}
            strokeOpacity={0.9}
          />
        </g>
      </g>
    </g>
  );
};

const ContactMark = (props: {
  contact: Contact;
  cx: number;
  cy: number;
  scale: number;
  inRange: boolean;
  selected: boolean;
  onSelect: () => void;
  onHover: (entered: boolean) => void;
  onMenu: (event: React.MouseEvent) => void;
}) => {
  const { contact, cx, cy, scale, inRange, selected, onSelect, onHover, onMenu } =
    props;
  const unknown = contact.kind === 'ship' && !contact.identified;
  const colour = contactColour(contact);
  // Nebulas and storms spread across whole banks of tiles, so labelling every
  // one buries the chart in repeated names. They read as a field from the
  // glyphs alone; the name comes back on click, and the drawer always has it.
  const labelled =
    selected || (contact.kind !== 'nebula' && contact.kind !== 'hazard');

  return (
    <g
      className={`Helm__contact ${selected ? 'Helm--selected' : ''}`}
      transform={`translate(${cx},${cy})`}
      opacity={inRange ? 1 : 0.5}
      onClick={onSelect}
      onContextMenu={onMenu}
      onMouseEnter={() => onHover(true)}
      onMouseLeave={() => onHover(false)}
    >
      <g style={{ ...SVG_ORIGIN, transform: `scale(${1 / scale})` }}>
        {/*
          Invisible hit area. The glyphs are 5-6 units across at chart scale,
          which is a punishing target with a mouse, this gives every contact a
          consistent grab radius without changing how it looks.
        */}
        <circle r={11} fill="transparent" />
        <circle className="Helm__halo" r={11} fill={colour} fillOpacity={0.5} />
        {unknown ? (
          <UnknownGlyph colour={colour} />
        ) : (
          <ContactGlyph
            kind={contact.kind}
            variant={contact.variant}
            severity={contact.severity}
            colour={colour}
          />
        )}
        {!!labelled && (
          // Sits inside the counter-scale group, so this is a constant size on
          // screen at every zoom. One SVG unit is only ~1.3 screen pixels here,
          // which is why the old 5.2 rendered at about six pixels.
          <text
            y={15}
            textAnchor="middle"
            fill={colour}
            fontSize={10}
            fontFamily="ui-monospace, monospace"
          >
            {contact.name.toUpperCase()}
          </text>
        )}
      </g>
    </g>
  );
};

/**
 * A hail going out or coming in: a ring that expands and fades from the sender's
 * tile, with the message beneath it. Our own transmissions read amber like the
 * rest of the ship's own state; anyone else's read ice, same as every other
 * outside-world contact.
 */
const TransmissionPulse = (props: {
  hail: Transmission;
  cx: number;
  cy: number;
  scale: number;
}) => {
  const { hail, cx, cy, scale } = props;
  const colour = hail.own ? '#f2a341' : '#74c8dd';

  return (
    <g transform={`translate(${cx},${cy})`} style={{ pointerEvents: 'none' }}>
      <g style={{ ...SVG_ORIGIN, transform: `scale(${1 / scale})` }}>
        <circle
          className="Helm__pulse"
          r={9}
          fill="none"
          stroke={colour}
          strokeWidth={1.4}
        />
        <circle
          className="Helm__pulse Helm__pulse--trail"
          r={9}
          fill="none"
          stroke={colour}
          strokeWidth={1}
        />
        <text
          className="Helm__hailText"
          y={-16}
          textAnchor="middle"
          fill={colour}
          fontSize={8.5}
          fontFamily="ui-monospace, monospace"
        >
          {hail.message.length > 46
            ? `${hail.message.slice(0, 45)}…`
            : hail.message}
        </text>
      </g>
    </g>
  );
};

/**
 * Everything the helm knows about the contact under the cursor. Sits bottom-right
 * of the chart rather than following the mouse: a callout chasing the cursor
 * across a chart the crew is trying to read is worse than one they can learn the
 * position of.
 */
const ContactReadout = (props: { contact: Contact }) => {
  const { contact } = props;
  const travelClock = useTravelClock();
  const unknown = contact.kind === 'ship' && !contact.identified;
  const eta = travelClock(contact.x, contact.y);

  return (
    <div className="Helm__readout">
      <div className={`Helm__readoutName ${unknown ? 'Helm--unknown' : ''}`}>
        {contact.name}
      </div>
      <div className="Helm__readoutMeta">
        {contact.category} · {String(contact.x).padStart(2, '0')} /{' '}
        {String(contact.y).padStart(2, '0')}
      </div>
      <div className="Helm__readoutMeta">
        {contact.dist > 0
          ? `${contact.dist} tiles ${contact.bearing}`
          : 'This position'}
        {/*
          The trip at the speed the ship is already making, so a crew reading the
          callout before they commit to a heading knows what it costs. Tiles
          alone can't say: the same four tiles is twenty seconds or two minutes
          depending on what the hull is carrying.
        */}
        {!!eta && ` · ${eta} out`}
        {contact.integrity != null && ` · hull ${contact.integrity}%`}
        {!!contact.hostile && ' · HOSTILE'}
      </div>
      <div className="Helm__readoutHint">
        {unknown ? 'Right-click to identify' : 'Right-click to set course'}
      </div>
    </div>
  );
};

/**
 * Contextual actions for a contact, opened by right-click on its mark on the
 * chart or on its row in the contact drawer. The two are the same list seen two
 * ways, so they answer a right-click identically.
 *
 * The menu is anchored on a tile, not on a mark: plotting a course is an action
 * on a position, so bare chart gets the same menu a contact does, minus the
 * actions that need something to act on.
 */
const ContactMenu = (props: {
  contact?: Contact;
  tile: { x: number; y: number };
  left: number;
  top: number;
  onClose: () => void;
}) => {
  const { contact, tile, left, top, onClose } = props;
  const { act, data } = useBackend<Data>();
  const { scanCooldown, state, autopilot, x, y, shipDisabled, canThrust } = data;
  const locked = useLocked();

  const unknown = contact?.kind === 'ship' && !contact.identified;
  const here = tile.x === x && tile.y === y;
  const items: {
    label: string;
    hint?: string;
    disabled?: boolean;
    onClick: () => void;
  }[] = [];

  if (unknown) {
    items.push({
      // Deliberately the same sweep the sensor panel's Ships button runs, so a
      // targeted identify can't dodge the scan cooldown or become a cheaper
      // route to the same information.
      label: 'Identify vessels',
      hint: scanCooldown
        ? 'Sensors recharging'
        : state !== 'flying'
          ? 'Requires flight'
          : undefined,
      disabled: locked || !!scanCooldown || state !== 'flying',
      onClick: () => act('active_scan', { category: 'Ships' }),
    });
  }

  if (contact?.dist === 0 && contact.target) {
    items.push({
      label: 'Interact',
      hint: 'Shares our position',
      disabled: locked,
      onClick: () => act('act_overmap', { ship_to_act: contact.target }),
    });
  }

  const blocked =
    state !== 'flying'
      ? 'Requires flight'
      : shipDisabled
        ? 'Systems offline'
        : !canThrust
          ? 'No engine power'
          : undefined;

  if (!here) {
    items.push({
      label: contact ? `Set course · ${contact.name}` : 'Set course here',
      hint: blocked ?? 'Routes around known hazards',
      disabled: locked || !!blocked,
      onClick: () => act('autopilot', { x: tile.x, y: tile.y }),
    });
  }

  if (contact && canTravelDock(contact)) {
    items.push({
      label: `Travel & dock · ${contact.name}`,
      hint: blocked ?? 'Flies there, then begins docking',
      disabled: locked || !!blocked,
      onClick: () =>
        act('autopilot', {
          x: tile.x,
          y: tile.y,
          dock: 1,
          target: contact.target,
        }),
    });
  }

  if (autopilot?.engaged) {
    items.push({
      label: 'Cancel autopilot',
      disabled: locked,
      onClick: () => act('autopilot_cancel'),
    });
  }

  if (contact?.ref) {
    items.push({
      label: 'Clear waypoint',
      disabled: locked,
      onClick: () => act('remove_waypoint', { waypoint: contact.ref }),
    });
  }

  return (
    <div
      className="Helm__menu"
      style={{ left: `${left}px`, top: `${top}px` }}
      onClick={(event) => event.stopPropagation()}
      onContextMenu={(event) => {
        event.preventDefault();
        event.stopPropagation();
      }}
    >
      <div className="Helm__menuHead">
        {contact?.name ?? `${String(tile.x).padStart(2, '0')} / ${String(tile.y).padStart(2, '0')}`}
      </div>
      {items.length === 0 ? (
        <div className="Helm__menuEmpty">No actions available</div>
      ) : (
        items.map((item) => (
          <button
            key={item.label}
            type="button"
            className="Helm__menuItem"
            disabled={item.disabled}
            onClick={() => {
              item.onClick();
              onClose();
            }}
          >
            <span className="Helm__menuLabel">{item.label}</span>
            {!!item.hint && <span className="Helm__menuHint">{item.hint}</span>}
          </button>
        ))
      )}
    </div>
  );
};

/**
 * The Dock button's option picker, opened only when `dockOptions` holds more
 * than one entry (OpsRow dispatches straight to `act('dock', ...)` otherwise,
 * see runDock() there). Rendered at the console root for the same clipping
 * reason as ContactMenu above.
 */
const DockPickerMenu = (props: {
  left: number;
  top: number;
  onClose: () => void;
}) => {
  const { left, top, onClose } = props;
  const { act, data } = useBackend<Data>();
  const options = data.dockOptions ?? [];

  return (
    <div
      className="Helm__menu"
      style={{ left: `${left}px`, top: `${top}px` }}
      onClick={(event) => event.stopPropagation()}
      onContextMenu={(event) => {
        event.preventDefault();
        event.stopPropagation();
      }}
    >
      <div className="Helm__menuHead">Dock with…</div>
      {options.length === 0 ? (
        <div className="Helm__menuEmpty">Nothing to dock with</div>
      ) : (
        options.map((option) => (
          <button
            key={option.ref ?? 'empty'}
            type="button"
            className="Helm__menuItem"
            onClick={() => {
              act('dock', option.ref ? { target: option.ref } : {});
              onClose();
            }}
          >
            <span className="Helm__menuLabel">{option.name}</span>
          </button>
        ))
      )}
    </div>
  );
};

/**
 * A contact's chart glyph at list-row size, so the register and the map agree
 * about what a thing looks like. The view box is centred on the origin, which is
 * where every glyph below is drawn from.
 */
const ContactBadge = (props: { contact: Contact }) => {
  const { contact } = props;
  const unknown = contact.kind === 'ship' && !contact.identified;
  const colour = contactColour(contact);

  return (
    <svg viewBox="-8 -8 16 16" aria-hidden="true">
      {unknown ? (
        <UnknownGlyph colour={colour} />
      ) : (
        <ContactGlyph
          kind={contact.kind}
          variant={contact.variant}
          severity={contact.severity}
          colour={colour}
        />
      )}
    </svg>
  );
};

/**
 * An unscanned vessel: a dashed ring with no heading and no shape. Deliberately
 * shares nothing with the solid arrowhead an identified ship gets, at a glance
 * the crew should be able to count how many contacts they have not looked at.
 */
const UnknownGlyph = (props: { colour: string }) => (
  <>
    <circle
      r={5}
      fill="none"
      stroke={props.colour}
      strokeWidth={1.5}
      strokeDasharray="2.6 2.2"
    />
    <circle r={1.3} fill={props.colour} />
  </>
);

/**
 * Everything the chart draws that isn't the ship.
 *
 * One silhouette per family, and within the two families where the difference
 * changes what a crew does, the things orbiting a star, and the things trying
 * to kill you on the way there. One per variant as well. All of it is monoline
 * at a single weight and inside a ~6-unit box, so a chart full of contacts reads
 * as one instrument rather than a sticker sheet.
 */
const ContactGlyph = (props: {
  kind: ContactKind;
  variant?: string | null;
  severity?: number;
  colour: string;
}) => {
  const { kind, variant, severity, colour } = props;
  const line = { fill: 'none', stroke: colour, strokeWidth: 1.6 } as const;

  switch (kind) {
    case 'planet':
      // A rock in orbit is a ring with a core, whatever it's made of, the
      // terrain is carried entirely by PLANET_COLOR. The three variants that
      // aren't really planets get out of the family instead of miscolouring it.
      if (variant === 'asteroid') {
        // Deliberately lopsided, with a bite out of one side. A regular polygon
        // here read as the event hexagon at chart size.
        return (
          <path
            d="M-4.8,-0.6 L-2.4,-4.6 L1,-3.4 L2.2,-5 L4.8,-1.4 L2.6,0.4 L4.2,2.8 L0.4,4.8 L-3.4,3 Z"
            {...line}
          />
        );
      }
      if (variant === 'signal') {
        // Something transmitting and nothing more. A dashed ring would have been
        // the obvious draw and is already spoken for by an unidentified vessel;
        // these are the two contacts a crew is most likely to confuse, so they
        // are the two that have to share the least.
        return (
          <>
            <circle cx={-3.2} r={1.5} fill={colour} />
            <path d="M-1.6,-2.8 A3.2 3.2 0 0 1 -1.6,2.8" {...line} strokeWidth={1.4} />
            <path d="M0,-4.6 A5.6 5.6 0 0 1 0,4.6" {...line} strokeWidth={1.4} />
          </>
        );
      }
      if (variant === 'wreck') {
        // A hull on its side, hollow and broken open. Every other glyph on the
        // chart sits upright, so lying over is by itself enough to say this one
        // isn't flying, which is what keeps it off the hostile arrowhead.
        return (
          <g transform="rotate(125)">
            <path d="M0,-5.2 L3.7,4.2 L0,1.9 L-3.7,4.2 Z" {...line} />
            <path d="M-3.1,-1.4 L3.1,-1.4" {...line} strokeWidth={1.3} />
          </g>
        );
      }
      return (
        <>
          <circle r={4.5} {...line} strokeWidth={1.8} />
          <circle r={1.8} fill={colour} />
        </>
      );

    case 'ruin':
      // Empty until surveyed, an outline with nothing identified inside it. The
      // core arrives with the survey; an encrypted signal is still unsurveyed and
      // stays hollow, and says what it is in gold instead.
      return (
        <>
          <path d="M0,-5 L4.5,2.5 L-4.5,2.5 Z" {...line} strokeWidth={1.7} />
          {!!variant && variant !== 'encrypted' && (
            <circle cy={0.4} r={1.4} fill={colour} />
          )}
        </>
      );

    case 'outpost':
      // A colony flies a pennant; a market is a stall with its lights on.
      if (variant === 'colony') {
        return (
          <>
            <path d="M-2.6,5 V-5" {...line} />
            <path d="M-2.6,-4.6 L4.4,-2.4 L-2.6,-0.2 Z" fill={colour} />
          </>
        );
      }
      return (
        <>
          <rect x={-4} y={-4} width={8} height={8} {...line} strokeWidth={1.7} />
          <rect x={-1.4} y={-1.4} width={2.8} height={2.8} fill={colour} />
        </>
      );

    case 'ship':
      return (
        <path d="M0,-5.5 L4,4.5 L0,2 L-4,4.5 Z" fill={colour} fillOpacity={0.9} />
      );

    case 'nebula':
      return (
        <>
          <ellipse
            rx={6.2}
            ry={4.2}
            fill={colour}
            fillOpacity={0.16}
            stroke={colour}
            strokeWidth={1.2}
            strokeDasharray="3 2"
          />
          <circle cx={-1.8} cy={-0.6} r={1.1} fill={colour} fillOpacity={0.7} />
          <circle cx={1.9} cy={0.9} r={0.9} fill={colour} fillOpacity={0.55} />
        </>
      );

    case 'hazard':
      // Sized by severity: the only glyph on the chart that changes scale, and
      // it earns it: how bad the storm is decides whether you route around it.
      return (
        <g
          style={{
            ...SVG_ORIGIN,
            transform: `scale(${SEVERITY_SCALE[severity ?? 2] ?? 1})`,
          }}
        >
          <HazardGlyph variant={variant} colour={colour} line={line} />
        </g>
      );

    case 'bounty':
      // A reticle: something the crew was sent to put a weapon on.
      return (
        <>
          <path d="M-5.4,-3 V-5.4 H-3 M3,-5.4 H5.4 V-3" {...line} />
          <path d="M5.4,3 V5.4 H3 M-3,5.4 H-5.4 V3" {...line} />
          <circle r={1.5} fill={colour} />
        </>
      );

    case 'mission':
      return <path d="M0,-5.2 L5.2,0 L0,5.2 L-5.2,0 Z" fill={colour} fillOpacity={0.9} />;

    case 'rumor':
      // Same diamond as a mission, hollow: a lead, not an assignment. Hollow
      // rather than dashed, a dash pattern this size disintegrates a polygon
      // into loose marks well before the chart is zoomed out.
      return <path d="M0,-5.2 L5.2,0 L0,5.2 L-5.2,0 Z" {...line} />;

    case 'event':
      return (
        <>
          <path d="M0,-5.4 L4.7,-2.7 L4.7,2.7 L0,5.4 L-4.7,2.7 L-4.7,-2.7 Z" {...line} />
          <circle r={1.4} fill={colour} />
        </>
      );

    default:
      // A plain waypoint: somewhere the crew decided mattered.
      return (
        <path
          d="M0,-6 L2,-2 L6,-2 L3,1 L4,5 L0,3 L-4,5 L-3,1 L-6,-2 L-2,-2 Z"
          {...line}
          strokeWidth={1.5}
        />
      );
  }
};

/**
 * The three storms, which are the contacts a navigator most needs to tell apart
 * at a glance: rock scours the hull, ion kills the electronics, an arc front
 * does both to whatever is unshielded. Nothing they share but the danger.
 */
const HazardGlyph = (props: {
  variant?: string | null;
  colour: string;
  line: { fill: 'none'; stroke: string; strokeWidth: number };
}) => {
  const { variant, colour, line } = props;
  switch (variant) {
    case 'rock':
      // Debris: solid chunks with clear space between them, so a field of these
      // reads as a field.
      return (
        <>
          <path d="M-4.8,-2.4 L-2.2,-4.2 L-0.8,-1.8 L-3.2,-0.4 Z" fill={colour} />
          <path d="M1.4,-4.4 L4.6,-3.2 L4,-0.4 L1,-1.4 Z" fill={colour} />
          <path d="M-2.6,1.4 L0.6,0.8 L1.4,3.8 L-1.6,4.4 Z" fill={colour} />
          <circle cx={3.6} cy={3.2} r={1.2} fill={colour} />
        </>
      );
    case 'ion':
      // A pulse going out: bare spokes, no rim. Deliberately open where the
      // rock field is solid and the arc glyph is one unbroken stroke.
      return (
        <>
          <circle r={1.6} fill={colour} />
          <path
            d="M0,-3 V-6 M0,3 V6 M-3,0 H-6 M3,0 H6 M-2.2,-2.2 L-4.4,-4.4 M2.2,2.2 L4.4,4.4 M2.2,-2.2 L4.4,-4.4 M-2.2,2.2 L-4.4,4.4"
            {...line}
            strokeWidth={1.4}
          />
        </>
      );
    case 'electrical':
      return <path d="M1.6,-6 L-3.4,0.4 L-0.2,0.4 L-1.6,6 L3.4,-0.4 L0.2,-0.4 Z" fill={colour} />;
    default:
      // Something is out there and the sensors won't say what.
      return (
        <path
          d="M0,-6 L1.7,-1.7 L6,0 L1.7,1.7 L0,6 L-1.7,1.7 L-6,0 L-1.7,-1.7 Z"
          {...line}
        />
      );
  }
};

// ---------------------------------------------------------------- drawer

const TABS = ['Contacts', 'At location', 'Comms', 'Intel'] as const;
type Tab = (typeof TABS)[number];

const Drawer = () => {
  const { data } = useBackend<Data>();
  const { otherInfo = [], transmissions = [] } = data;
  const [tab, setTab] = useState<Tab>('Contacts');
  // Only hails still pulsing on the chart count as unread-ish; an old log is not
  // something to keep nagging about.
  const freshHails = transmissions.filter((hail) => hail.live && !hail.own).length;

  return (
    <div className="Helm__drawerWrap">
      <div className="Helm__tabs">
        {TABS.map((name) => (
          <button
            key={name}
            type="button"
            className={`Helm__tab ${tab === name ? 'Helm--on' : ''}`}
            onClick={() => setTab(name)}
          >
            {name}
            {name === 'At location' && !!otherInfo.length && (
              <span className="Helm__badge">{otherInfo.length}</span>
            )}
            {name === 'Comms' && !!freshHails && (
              <span className="Helm__badge">{freshHails}</span>
            )}
          </button>
        ))}
      </div>
      <div className="Helm__drawerBody">
        {tab === 'Contacts' && <ContactList />}
        {tab === 'At location' && <AtLocation />}
        {tab === 'Comms' && <Comms />}
        {tab === 'Intel' && <Intel />}
      </div>
    </div>
  );
};

const ContactList = () => {
  const { act } = useBackend<Data>();
  const waypoints = useContacts();
  const travelClock = useTravelClock();
  const locked = useLocked();
  const { selected, select } = useContext(Selection);
  const { focusOn } = useContext(ChartFocus);
  const openActionMenu = useContext(MenuControl);

  if (!waypoints.length) {
    return <div className="Helm__empty">No contacts in range</div>;
  }

  const groups: Record<string, Contact[]> = {};
  for (const contact of waypoints) {
    const category = contact.category || 'Waypoints';
    (groups[category] ||= []).push(contact);
  }

  // A nebula bank or asteroid storm is dozens of identically-named tiles. The
  // register lists the nearest one and counts the rest, so a single field reads
  // as a single entry. The chart is where its actual shape lives.
  const collapse = (contacts: Contact[]) => {
    const nearest = new Map<string, { contact: Contact; count: number }>();
    for (const contact of contacts) {
      const existing = nearest.get(contact.name);
      if (!existing) {
        nearest.set(contact.name, { contact, count: 1 });
      } else {
        existing.count++;
        if (contact.dist < existing.contact.dist) existing.contact = contact;
      }
    }
    return [...nearest.values()];
  };

  return (
    <>
      {Object.keys(groups)
        .sort()
        .map((category) => (
          <div key={category}>
            <div className="Helm__cat">
              {category} · {groups[category].length}
            </div>
            {collapse(groups[category]).map(({ contact, count }) => {
              const key = contactKey(contact);
              // Time to reach it at the speed the ship already has. Sits on the
              // meta line rather than beside the bearing: the drawer is under
              // 300px wide and the name column is the one that gives up the
              // room, so a second figure on the top line ellipsises the only
              // thing on the row you can't work out from the chart.
              const eta = travelClock(contact.x, contact.y);
              return (
                <div
                  key={key}
                  className={`Helm__row ${contact.hostile ? 'Helm--hostile' : ''} ${
                    contact.kind === 'ship' && !contact.identified
                      ? 'Helm--unknown'
                      : ''
                  } ${selected === key ? 'Helm--selected' : ''}`}
                  title={
                    contact.kind === 'ship' && !contact.identified
                      ? 'Unidentified vessel, right-click for actions, or run a Ships scan to resolve it'
                      : 'Bring it up on the chart · right-click to set course'
                  }
                  /*
                   * Highlight it and take the chart to it. A charted contact can
                   * be anywhere in the sector, the register remembers
                   * everything the ship has ever seen, so on a list of tiles
                   * mostly off the far edge of the view, a highlight alone left
                   * the crew hunting for the mark they had just clicked.
                   */
                  onClick={() => {
                    select(key);
                    focusOn(contact.x, contact.y);
                  }}
                  /*
                   * The same menu the chart mark opens, on the same contact. A
                   * course is plotted to the contact's own tile, so for a
                   * collapsed field (see collapse() above) that is the nearest
                   * tile of it, which is the one the row is reporting anyway.
                   */
                  onContextMenu={(event) =>
                    openActionMenu(event, key, { x: contact.x, y: contact.y })
                  }
                >
                  <span className="Helm__rowGlyph">
                    <ContactBadge contact={contact} />
                  </span>
                  <span className="Helm__rowName">
                    {contact.name}
                    {count > 1 && (
                      <span className="Helm__rowCount"> ×{count}</span>
                    )}
                  </span>
                  <span className="Helm__rowDist">
                    {contact.dist > 0
                      ? `${contact.dist} ${contact.bearing}`
                      : 'Here'}
                  </span>
                  <span className="Helm__rowCoord">
                    {String(contact.x).padStart(2, '0')} /{' '}
                    {String(contact.y).padStart(2, '0')}
                    {!!eta && ` · ${eta} out`}
                    {count > 1 && ' · nearest'}
                    {contact.integrity != null &&
                      ` · hull ${contact.integrity}%`}
                    {!!contact.ref && !locked && (
                      <button
                        type="button"
                        className="Helm__btn Helm__rowClear"
                        title="Clear this waypoint"
                        onClick={(event) => {
                          event.stopPropagation();
                          act('remove_waypoint', { waypoint: contact.ref });
                        }}
                      >
                        Clear
                      </button>
                    )}
                  </span>
                  {/*
                   * The same course actions the right-click menu leads with,
                   * surfaced on the selected row. A context menu is an
                   * invisible affordance, and these are the two things a
                   * navigator actually does from the register. stopPropagation
                   * keeps a button press from re-toggling the selection.
                   */}
                  {selected === key && !locked && (
                    <div className="Helm__rowActions">
                      {contact.dist > 0 && (
                        <button
                          type="button"
                          className="Helm__btn"
                          title="Autopilot flies there, routes around known hazards"
                          onClick={(event) => {
                            event.stopPropagation();
                            act('autopilot', { x: contact.x, y: contact.y });
                          }}
                        >
                          Set course
                        </button>
                      )}
                      {!!canTravelDock(contact) && (
                        <button
                          type="button"
                          className="Helm__btn"
                          title="Flies there, then begins docking"
                          onClick={(event) => {
                            event.stopPropagation();
                            act('autopilot', {
                              x: contact.x,
                              y: contact.y,
                              dock: 1,
                              target: contact.target,
                            });
                          }}
                        >
                          Travel &amp; dock
                        </button>
                      )}
                    </div>
                  )}
                </div>
              );
            })}
          </div>
        ))}
    </>
  );
};

/**
 * Objects sharing the ship's tile: the only contacts that can actually be
 * acted on, which is why they get their own tab and a count badge.
 */
const AtLocation = () => {
  const { act, data } = useBackend<Data>();
  const { otherInfo = [], speed, state } = data;
  const locked = useLocked();
  const canInteract = !locked && !speed && state === 'flying';

  if (!otherInfo.length) {
    return <div className="Helm__empty">Nothing at this position</div>;
  }

  return (
    <>
      {otherInfo.map((object) => (
        <div key={object.ref} className="Helm__card">
          <div className="Helm__cardName">{object.name}</div>
          <div className="Helm__cardMeta">
            {object.integrity ? `Integrity ${object.integrity}%` : 'Sharing tile'}
          </div>
          <button
            type="button"
            className="Helm__btn"
            style={{ width: '100%' }}
            disabled={!canInteract}
            title={
              canInteract
                ? `Interact with ${object.name}`
                : 'Come to a full stop first'
            }
            onClick={() => act('act_overmap', { ship_to_act: object.ref })}
          >
            Interact
          </button>
        </div>
      ))}
    </>
  );
};

const Comms = () => {
  const { act, data } = useBackend<Data>();
  const { transmissions = [] } = data;
  const locked = useLocked();
  const [message, setMessage] = useState('');
  // The keystroke sound is cosmetic, so it doesn't get a round trip per keypress.
  // The console keeps its own floor as well; this just stops us asking.
  const lastKeySound = useRef(0);

  const send = () => {
    if (!message.trim()) return;
    act('broadcast', { message });
    setMessage('');
  };

  // Newest first: the log arrives oldest-first as the ship stores it, but a
  // three-second hail is missed easily and the latest one is what matters.
  const log = [...transmissions].reverse();

  return (
    <div className="Helm__comms">
      <Input
        fluid
        placeholder="Hail vessels in sight…"
        value={message}
        disabled={locked}
        onChange={(value) => {
          setMessage(value);
          const now = Date.now();
          if (now - lastKeySound.current >= 400) {
            lastKeySound.current = now;
            act('typing_sound');
          }
        }}
        onEnter={send}
      />
      <button
        type="button"
        className="Helm__btn"
        disabled={locked || !message.trim()}
        onClick={send}
      >
        Transmit
      </button>

      {log.length === 0 ? (
        <div className="Helm__empty">No traffic heard</div>
      ) : (
        <div className="Helm__hailLog">
          {log.map((hail, index) => (
            <div
              key={`${hail.sender}-${hail.age}-${index}`}
              className={`Helm__hail ${hail.own ? 'Helm--own' : ''} ${
                hail.live ? 'Helm--fresh' : ''
              }`}
            >
              <div className="Helm__hailHead">
                <span className="Helm__hailFrom">
                  {hail.own ? 'Transmitted' : hail.sender}
                </span>
                <span className="Helm__hailAge">
                  {hail.age < 1 ? 'now' : `${hail.age}s ago`}
                </span>
              </div>
              <div className="Helm__hailBody">{hail.message}</div>
              <div className="Helm__hailPos">
                {String(hail.x).padStart(2, '0')} /{' '}
                {String(hail.y).padStart(2, '0')}
              </div>
            </div>
          ))}
        </div>
      )}
    </div>
  );
};

const Intel = () => {
  const { act, data } = useBackend<Data>();
  const { pendingRumors = [] } = data;
  const locked = useLocked();

  if (!pendingRumors.length) {
    return <div className="Helm__empty">No sealed charts aboard</div>;
  }

  return (
    <>
      {pendingRumors.map((rumor) => (
        <div key={rumor.ref} className="Helm__card Helm--rumor">
          <div className="Helm__cardName">{rumor.name}</div>
          {!!rumor.desc && <div className="Helm__cardDesc">{rumor.desc}</div>}
          <button
            type="button"
            className="Helm__btn"
            style={{ width: '100%' }}
            disabled={locked}
            title="Spawns the signal in the deep lanes and charts it. The mark is visible to anyone who scans for it, ready the crew first."
            onClick={() => act('reveal_rumor', { chart: rumor.ref })}
          >
            Reveal coordinates
          </button>
        </div>
      ))}
    </>
  );
};

// ---------------------------------------------------------------- controls

// One act() per pointermove is one BYOND Topic call per mouse pixel: a single
// drag of this slider spends hundreds of them, and the client's per-minute topic
// limit boots the pilot mid-flight. The knob tracks the cursor from local state
// and the server hears at most one value per interval, plus the final one.
const THROTTLE_SEND_MS = 200;

const Throttle = () => {
  const { act, data } = useBackend<Data>();
  const locked = useLocked();
  const trackRef = useRef<HTMLDivElement>(null);
  const dragging = useRef(false);
  // Set while the local value is ahead of the backend's; null once it catches up.
  const [dragValue, setDragValue] = useState<number | null>(null);
  const lastSent = useRef({ value: -1, at: 0 });
  const pending = useRef<ReturnType<typeof setTimeout> | null>(null);

  const burnPercentage = dragValue ?? data.burnPercentage;

  const send = (value: number, force: boolean) => {
    if (pending.current) {
      clearTimeout(pending.current);
      pending.current = null;
    }
    if (value === lastSent.current.value) return;
    const wait = THROTTLE_SEND_MS - (Date.now() - lastSent.current.at);
    if (!force && wait > 0) {
      // Superseded by the next move if one arrives first, so a long drag costs
      // one call per interval rather than one per event.
      pending.current = setTimeout(() => send(value, true), wait);
      return;
    }
    lastSent.current = { value, at: Date.now() };
    act('change_burn_percentage', { percentage: value });
  };

  // Hand the knob back to the backend only once it agrees, so releasing a drag
  // doesn't snap the knob back for the length of a round trip, frames arrive
  // every tile crossed and one of them would land mid-flight. If the backend
  // never agrees the console refused the change, so stop lying about it.
  useEffect(() => {
    if (dragValue === null || dragging.current) return;
    const settled = data.burnPercentage === dragValue;
    const refused = !pending.current && Date.now() - lastSent.current.at > 1500;
    if (settled || refused) setDragValue(null);
  }, [data.burnPercentage, dragValue]);

  useEffect(
    () => () => {
      if (pending.current) clearTimeout(pending.current);
    },
    [],
  );

  const commit = (clientY: number, force = false) => {
    const track = trackRef.current;
    if (!track) return;
    const rect = track.getBoundingClientRect();
    const value = Math.round(
      Math.min(100, Math.max(1, (1 - (clientY - rect.top) / rect.height) * 100)),
    );
    setDragValue(value);
    send(value, force);
  };

  return (
    <div className="Helm__throttle">
      <div
        ref={trackRef}
        className="Helm__throttleTrack"
        role="slider"
        tabIndex={locked ? -1 : 0}
        aria-label="Cruise throttle"
        aria-valuemin={1}
        aria-valuemax={100}
        aria-valuenow={burnPercentage}
        onPointerDown={(event) => {
          if (locked) return;
          dragging.current = true;
          event.currentTarget.setPointerCapture(event.pointerId);
          commit(event.clientY);
        }}
        onPointerMove={(event) => {
          if (dragging.current) commit(event.clientY);
        }}
        onPointerUp={(event) => {
          if (!dragging.current) return;
          dragging.current = false;
          // The value under the cursor at release is the one the pilot meant;
          // it goes out immediately even if a throttled send is still pending.
          commit(event.clientY, true);
        }}
        onPointerCancel={() => {
          dragging.current = false;
        }}
        onKeyDown={(event) => {
          if (locked) return;
          const step =
            event.key === 'ArrowUp' ? 5 : event.key === 'ArrowDown' ? -5 : 0;
          if (!step) return;
          event.preventDefault();
          // Held arrow keys autorepeat, so these go through the same throttle.
          const value = Math.min(100, Math.max(1, burnPercentage + step));
          setDragValue(value);
          send(value, false);
        }}
      >
        <div
          className="Helm__throttleFill"
          style={{ height: `${burnPercentage}%` }}
        />
        <div
          className="Helm__throttleKnob"
          style={{ bottom: `${burnPercentage}%` }}
        />
      </div>
      <div className="Helm__throttleScale">
        <span>100</span>
        <span>75</span>
        <span>50</span>
        <span>25</span>
        <span>1</span>
      </div>
      <div className="Helm__throttleValue">{burnPercentage}</div>
    </div>
  );
};

const Arrow = (props: { rotation: number }) => (
  <svg
    viewBox="0 0 24 24"
    fill="none"
    stroke="currentColor"
    strokeWidth={2.4}
    strokeLinecap="round"
    strokeLinejoin="round"
    style={{ transform: `rotate(${props.rotation}deg)` }}
  >
    <path d="M12 19V5M12 5l-6 6M12 5l6 6" />
  </svg>
);

const ROSE_CELLS: [string, number, number][] = [
  ['Northwest', DIR.NW, -45],
  ['North', DIR.N, 0],
  ['Northeast', DIR.NE, 45],
  ['West', DIR.W, -90],
  ['Brake', BURN_STOP, 0],
  ['East', DIR.E, 90],
  ['Southwest', DIR.SW, -135],
  ['South', DIR.S, 180],
  ['Southeast', DIR.SE, 135],
];

/**
 * The steering rose. Direction cells light from the COMMANDED course, not the
 * burn: fly-by-wire holds the course after the engines cut, so a lit cell over
 * a cold burn means the ship is cruising that way. Clicking the lit cell
 * coasts; the centre cell is always brake.
 */
const HelmRose = () => {
  const { act, data } = useBackend<Data>();
  const {
    burnDirection,
    commandedCourse,
    canThrust,
    shipDisabled,
    state,
    zone_transitioning,
  } = data;
  const locked = useLocked();

  const flyable = state === 'flying' && !shipDisabled && !locked;
  const canMove = flyable && !!canThrust && !zone_transitioning;

  return (
    <div className="Helm__rose">
      <div className="Helm__roseGrid">
        {ROSE_CELLS.map(([name, direction, rotation]) => {
          const isStop = direction === BURN_STOP;
          const lit = isStop
            ? burnDirection === BURN_STOP
            : commandedCourse === direction;
          return (
            <button
              key={name}
              type="button"
              className={`Helm__dirBtn ${isStop ? 'Helm--stop' : ''} ${lit ? 'Helm--lit' : ''}`}
              aria-label={isStop ? 'Brake' : `Fly ${name.toLowerCase()}`}
              title={
                isStop
                  ? zone_transitioning
                    ? 'Cancel zone transition'
                    : burnDirection === BURN_STOP
                      ? 'Braking, click to coast'
                      : 'Brake'
                  : lit
                    ? `Flying ${name.toLowerCase()}, click to coast`
                    : `Fly ${name.toLowerCase()}, drift is shed automatically`
              }
              disabled={isStop ? !flyable && !zone_transitioning : !canMove}
              onClick={() =>
                isStop ? act('stop') : act('change_heading', { dir: direction })
              }
            >
              {isStop ? (
                <svg viewBox="0 0 24 24" fill="currentColor">
                  <rect x={6} y={6} width={12} height={12} rx={1} />
                </svg>
              ) : (
                <Arrow rotation={rotation} />
              )}
            </button>
          );
        })}
      </div>
    </div>
  );
};

const VelocityCluster = () => {
  const { data } = useBackend<Data>();
  const {
    speed = 0,
    heading,
    eta,
    burnPercentage,
    burnDirection,
    commandedCourse,
    cruiseTargetSpeed,
  } = data;
  const drift = useDrift(useContacts());

  // CRUISE is derived, not sent: a commanded course with the burn out and way
  // on the ship is, by definition, the coast phase of fly-by-wire.
  const courseVector =
    commandedCourse !== BURN_NONE && burnDirection === BURN_NONE && speed > 0
      ? DIR_VECTOR[commandedCourse]
      : undefined;
  const showCruiseTarget =
    Number.isFinite(cruiseTargetSpeed) && cruiseTargetSpeed > 0;

  return (
    <div className="Helm__velocity">
      <div className="Helm__velBig">
        <span className="Helm__velValue">{speed.toFixed(1)}</span>
        <span className="Helm__velUnit">Tiles / min</span>
      </div>
      <div className="Helm__velSide">
        <div className="Helm__metric">
          <span className="Helm__k">Heading</span>
          <span className="Helm__v" style={{ fontSize: '1cqw' }}>
            {burnDirection === BURN_STOP
              ? 'Brake'
              : burnDirection !== BURN_NONE
                ? heading
                : courseVector
                  ? `Cruise ${bearingOf(courseVector[0], courseVector[1])}`
                  : drift
                    ? `Coast ${bearingOf(drift.vector[0], drift.vector[1])}`
                    : 'Hold'}
          </span>
        </div>
        {/* The tile clock, not an arrival time, see the HUD copy of it. */}
        <div className="Helm__metric">
          <span className="Helm__k">Next tile</span>
          <span className="Helm__v" style={{ fontSize: '1cqw' }}>
            {eta || '-'}
          </span>
        </div>
        <div
          className="Helm__metric"
          title="Throttle sets both the burn intensity and the cruise speed the ship holds"
        >
          <span className="Helm__k">Throttle</span>
          <span className="Helm__v" style={{ fontSize: '1cqw' }}>
            {burnPercentage}%
            {!!showCruiseTarget && (
              <span style={{ fontSize: '0.8cqw', color: '#7d8f94' }}>
                {' '}
                → {cruiseTargetSpeed.toFixed(1)} t/min
              </span>
            )}
          </span>
        </div>
      </div>
    </div>
  );
};

const OpsButton = (props: {
  label: string;
  sub: string;
  path: string;
  disabled?: boolean;
  state?: 'armed' | 'active';
  title: string;
  onClick: (event: React.MouseEvent<HTMLButtonElement>) => void;
}) => (
  <button
    type="button"
    className={`Helm__opBtn ${props.state ? `Helm--${props.state}` : ''}`}
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
    <span className="Helm__opLabel">{props.label}</span>
    <span className="Helm__opSub">{props.sub}</span>
  </button>
);

const OpsRow = () => {
  const { act, data } = useBackend<Data>();
  const {
    state,
    shipDisabled,
    undockCooldown,
    undockCooldownRemaining,
    undockLocked,
    undockLockoutRemaining,
    integrityLockout,
    integrityLockoutRemaining,
    dockWarmup,
    dockWarmupRemaining,
    undockWarmup,
    undockWarmupRemaining,
    cargoShuttlePresent,
    onNebula,
    hiddenInNebula,
    nebulaHideWarmup,
    nebulaHideRemaining,
    zone_transitioning,
    calibrating,
    dockOptions,
    speed,
    dockAssistMaxSpeed,
  } = data;
  const locked = useLocked();
  const openDockPicker = useContext(DockMenuControl);
  const flyable = state === 'flying' && !shipDisabled && !locked;
  // Dock assist: at or below the limit the ship kills its remaining way itself
  // before the warmup starts, the server enforces the same threshold, this
  // gate just keeps the button honest about it. A server that doesn't send the
  // limit falls back to 0 here, which is the old dead-stop rule.
  const dockSpeedLimit = dockAssistMaxSpeed ?? 0;
  const tooFastToDock = speed > dockSpeedLimit;
  const autoStopping = speed > 0 && !tooFastToDock;

  const options = dockOptions ?? [];
  const multipleDockOptions = options.length > 1;
  const primaryDockOption = options[0];
  const dockName = primaryDockOption?.name ?? 'empty space';
  const runDock = (option?: DockOption) =>
    act('dock', option?.ref ? { target: option.ref } : {});

  const undockDisabled =
    (state !== 'idle' && state !== 'undocking') ||
    !!shipDisabled ||
    locked ||
    !!undockCooldown ||
    !!undockLocked ||
    !!integrityLockout ||
    !!undockWarmup ||
    !!cargoShuttlePresent;

  // 'docking', 'undocking' and 'acting' disable every control on this panel, so the ship
  // looks neither docked nor flying and no button reacts. Name the state instead of
  // shrugging with "Already underway". A crew that can see "docking sequence in progress"
  // knows to wait (or to call it in) rather than assuming the console is dead.
  const manoeuvring =
    state === 'docking' || state === 'undocking' || state === 'acting';
  const manoeuvringLabel =
    state === 'docking'
      ? 'Docking sequence in progress'
      : state === 'undocking'
        ? 'Undocking sequence in progress'
        : 'Plotting approach vector';

  const undockReason = () => {
    if (undockWarmup)
      return `Undocking in ${deciToSeconds(undockWarmupRemaining)}s`;
    if (cargoShuttlePresent) return 'Cargo shuttle aboard. Send it away first';
    if (undockCooldown)
      return `Systems stabilising, ${deciToSeconds(undockCooldownRemaining)}s`;
    if (undockLocked)
      return `Interdiction lockout, ${deciToSeconds(undockLockoutRemaining)}s`;
    // Says "hull failure", not "hull damaged". By the time a crew reads this the breach is
    // usually welded and the integrity gauge is back on 100%, and a reason phrased in the
    // present tense would look like the console arguing with its own readout.
    if (integrityLockout)
      return `Hull failure, recertification ${deciToClock(integrityLockoutRemaining)}`;
    if (manoeuvring) return manoeuvringLabel;
    if (state !== 'idle' && state !== 'undocking') return 'Already underway';
    return 'Clear moorings and get underway';
  };

  const dockReason = () => {
    if (dockWarmup) return `Docking in ${deciToSeconds(dockWarmupRemaining)}s`;
    if (manoeuvring) return manoeuvringLabel;
    if (tooFastToDock) {
      return dockSpeedLimit > 0
        ? `Slow below ${dockSpeedLimit} tiles/min to make a docking approach`
        : multipleDockOptions
          ? 'Come to a full stop to dock'
          : `Come to a full stop to dock with ${dockName}`;
    }
    if (multipleDockOptions) {
      return autoStopping
        ? `Auto-stop, then choose from ${options.length} docking options here`
        : `Choose from ${options.length} docking options here`;
    }
    if (primaryDockOption?.isEmpty) {
      return autoStopping
        ? 'Auto-stop and hold position here in empty space'
        : 'Hold position here in empty space';
    }
    return autoStopping
      ? `Auto-stop and dock with ${dockName}`
      : `Dock with ${dockName}`;
  };

  return (
    <div className="Helm__ops">
      <OpsButton
        label="Undock"
        // The countdown belongs on the face of the button, not only in its
        // tooltip: "moorings" next to a dead button says nothing about why.
        sub={
          undockWarmup
            ? `${deciToSeconds(undockWarmupRemaining)}s`
            : undockCooldown
              ? `hold ${deciToSeconds(undockCooldownRemaining)}s`
              : undockLocked
                ? `locked ${deciToSeconds(undockLockoutRemaining)}s`
                : integrityLockout
                  ? `recert ${deciToClock(integrityLockoutRemaining)}`
                  : cargoShuttlePresent
                    ? 'shuttle aboard'
                    : manoeuvring
                      ? `${state}…`
                      : 'moorings'
        }
        path="M9 4h6v4h5v12H4V8h5V4zm3 5v7m0 0l-3-3m3 3l3-3"
        disabled={undockDisabled}
        state={undockWarmup ? 'armed' : undefined}
        title={undockReason()}
        onClick={() => act('undock')}
      />
      <OpsButton
        label="Dock"
        // Says what is actually under the ship. This button used to only ever dock
        // into empty space and refused outright when anything shared the tile, then
        // only ever offered the first real candidate found, now it lists every
        // dockable thing sharing the tile and only asks the crew to choose when
        // there's more than one.
        sub={
          dockWarmup
            ? `${deciToSeconds(dockWarmupRemaining)}s`
            : manoeuvring
              ? `${state}…`
              : multipleDockOptions
                ? `${options.length} options`
                : dockName
        }
        path="M12 3v10m0 0l-3-3m3 3l3-3M4 17h16v4H4z"
        disabled={
          !flyable ||
          tooFastToDock ||
          !!dockWarmup ||
          !!zone_transitioning ||
          !!hiddenInNebula
        }
        state={dockWarmup ? 'armed' : undefined}
        title={dockReason()}
        onClick={(event) =>
          multipleDockOptions ? openDockPicker(event) : runDock(primaryDockOption)
        }
      />
      <OpsButton
        label={hiddenInNebula ? 'Emerge' : 'Cloak'}
        sub={
          hiddenInNebula
            ? 'concealed'
            : nebulaHideWarmup
              ? `${deciToSeconds(nebulaHideRemaining)}s`
              : onNebula
                ? 'nebula ready'
                : 'needs nebula'
        }
        path="M2 12s4-7 10-7 10 7 10 7-4 7-10 7-10-7-10-7zm10 3a3 3 0 100-6 3 3 0 000 6z"
        disabled={
          hiddenInNebula
            ? locked
            : !flyable ||
              !onNebula ||
              !!nebulaHideWarmup ||
              !!zone_transitioning
        }
        state={hiddenInNebula ? 'active' : nebulaHideWarmup ? 'armed' : undefined}
        title={
          hiddenInNebula
            ? 'Break concealment and become visible again'
            : onNebula
              ? 'Hide the ship inside this nebula'
              : 'Fly onto a nebula tile to conceal the ship'
        }
        onClick={() =>
          act(hiddenInNebula ? 'unhide_from_nebula' : 'hide_in_nebula')
        }
      />
      <OpsButton
        label="Bluespace"
        sub={calibrating ? 'calibrating' : 'leave system'}
        path="M13 2L4 14h6l-1 8 9-12h-6l1-8z"
        disabled={!flyable || !!zone_transitioning || !!hiddenInNebula}
        state={calibrating ? 'armed' : undefined}
        title={
          calibrating
            ? 'Cancel the bluespace jump'
            : 'Calibrate a bluespace jump, this ends the round for your ship'
        }
        onClick={() => act('bluespace_jump')}
      />
    </div>
  );
};

// ---------------------------------------------------------------- overlays

const CrashOverlay = (props: { current: number; total: number }) => {
  const { current, total } = props;
  const percent = total > 0 ? (current / total) * 100 : 0;

  return (
    <div className="Helm__overlay">
      <div className="Helm__overlayBox">
        <div className="Helm__overlayTitle">Hull integrity critical</div>
        <div className="Helm__overlayDesc">
          Ship systems are offline. Rebuild hull mass to restore functionality.
        </div>
        <div className="Helm__bar" style={{ height: '1.6cqw' }}>
          <i style={{ width: `${percent}%`, background: '#cf4a38' }} />
          <span className="Helm__ticks" />
        </div>
        <div className="Helm__overlayValue">
          {current} / {total}
        </div>
        <div className="Helm__overlayNote">
          {Math.max(0, total - current)} mass remaining
        </div>
      </div>
    </div>
  );
};

const AbandonedOverlay = () => {
  const { act, data } = useBackend<Data>();
  if (!data.isAbandoned || data.isViewer) return null;

  return (
    <div className="Helm__overlay Helm--prompt">
      <div className="Helm__overlayBox">
        <div className="Helm__overlayTitle">Vessel abandoned</div>
        <div className="Helm__overlayDesc">
          No command authorization is registered to this ship. Claiming it makes
          you its commanding officer.
        </div>
        <div className="Helm__overlayActions">
          <button
            type="button"
            className="Helm__btn"
            onClick={() => act('claim_abandoned')}
          >
            Claim this ship
          </button>
        </div>
      </div>
    </div>
  );
};
