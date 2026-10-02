/**
 * Helm console hooks, geometry and shared contexts.
 *
 * Everything here reads from ui_data(); none of it calls act(). The chart owns
 * the camera, so cross-panel requests (focus, selection, context menu) travel
 * through the contexts below rather than by reaching into the chart.
 */
import { createContext, useContext } from 'react';
import type { MouseEvent } from 'react';

import { useBackend } from '../../backend';
import {
  type Contact,
  type ContactKind,
  type Data,
  DIR_VECTOR,
} from './data';

// ---------------------------------------------------------------- formatting

/** m:ss, matching the ETA the ship formats for the readouts. */
export const clockOf = (ms: number) => {
  const total = Math.round(ms / 1000);
  return `${Math.floor(total / 60)}:${String(total % 60).padStart(2, '0')}`;
};

/** Deciseconds to whole seconds. */
export const deciToSeconds = (ds: number) => Math.ceil(ds / 10);

/** Deciseconds as m:ss. The hull-failure lockout runs minutes, where a bare second count reads badly. */
export const deciToClock = (ds: number) => clockOf(deciToSeconds(ds) * 1000);

/** Keep contact selection stable when a vessel moves or reveals its name. */
export const contactKey = (contact: Pick<Contact, 'ref' | 'contactRef'>) =>
  contact.ref ?? contact.contactRef;

// ---------------------------------------------------------------- geometry

import {
  bandOf,
  clamp,
  type CourseSegment,
  isChartTile,
  visibleCourseSegments,
  wrappedDelta,
} from './geometry';

export {
  bandOf,
  clamp,
  type CourseSegment,
  isChartTile,
  visibleCourseSegments,
  wrappedDelta,
};

/** Port of overmap_delta_to_compass() in ship/waypoints.dm: the 0.4142 is
 * tan(22.5°), which is what splits the compass into eight even sectors. */
export const bearingOf = (dx: number, dy: number) => {
  if (!dx && !dy) return '';
  let compass = '';
  if (Math.abs(dy) > Math.abs(dx) * 0.4142) compass += dy > 0 ? 'N' : 'S';
  if (Math.abs(dx) > Math.abs(dy) * 0.4142) compass += dx > 0 ? 'E' : 'W';
  return compass;
};

// ---------------------------------------------------------------- contacts

/**
 * The live contact set and the permanent charted table as one list.
 *
 * Static data can't know what is in sight this second, so the charted table
 * carries everything the ship has ever seen, including whatever it happens to be
 * looking at right now. Dropping the duplicates is the client's job, keyed on the
 * object each entry came from.
 */
export const useContacts = (): Contact[] => {
  const { data } = useBackend<Data>();
  const { waypoints = [], chartedContacts = [], x, y } = data;

  const alreadyLive = new Set(
    waypoints.map((contact) => contact.target).filter(Boolean),
  );

  const remembered: Contact[] = [];
  for (const entry of chartedContacts) {
    if (entry.target && alreadyLive.has(entry.target)) continue;
    const dx = wrappedDelta(entry.x - x, (data.chart?.size ?? 51) - 2);
    const dy = wrappedDelta(entry.y - y, (data.chart?.size ?? 51) - 2);
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
 * tick_move() steps each axis by the SIGN of its velocity, so one interval buys
 * a tile on BOTH axes at once: the hop count to a tile is its Chebyshev distance,
 * not the straight-line one the rows report alongside it. Wraparound counts.
 */
export const useTravelClock = () => {
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

/** Whether the viewer may not fly this hull. Abandoned ships deliberately unlock. */
export const useLocked = () => {
  const { data } = useBackend<Data>();
  return !!data.isViewer || (!!data.isNotCrew && !data.isAbandoned);
};

/** Whether "Travel & dock" can be offered on a contact. */
export const DOCKABLE_KINDS: ContactKind[] = ['planet', 'ruin', 'outpost'];
export const canTravelDock = (contact: Contact) =>
  DOCKABLE_KINDS.includes(contact.kind) && contact.dist > 0 && !!contact.target;

// ---------------------------------------------------------------- drift

export type DriftTile = { x: number; y: number; step: number };

export type Drift = {
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
  /** Set when a zone line cuts the projection short. */
  hold: { x: number; y: number } | null;
};

/** Which contact a tile holding several is named by. Danger outranks scenery. */
const interceptRank = (contact: Contact) =>
  contact.kind === 'hazard' ? 2 : contact.kind === 'nebula' ? 1 : 0;

/**
 * Ceiling on how far ahead a coasting ship is projected. A minute out, at the
 * speeds a slow hull crosses tiles, the projection is stale long before the ship
 * arrives, something will have moved or been steered around.
 */
export const DRIFT_HORIZON_MS = 60000;

/** ZONE_TRANSITION_TIME, for the hold the chart draws at a zone line. */
export const ZONE_TRANSITION_MS = 10000;

/**
 * Where the ship ends up with the engines cold. Nothing out here slows a hull
 * down, so "coasting" is a course rather than a pause; `driftDirection` is taken
 * from the velocity signs, so the steps follow tick_move() up to the barriers.
 * Only autopilot projects a route beyond them. The track stops at the sensor
 * ring: the console has no business drawing a course through space this hull
 * knows nothing about.
 */
export const useDrift = (contacts: Contact[]): Drift | null => {
  const { data } = useBackend<Data>();
  const {
    x,
    y,
    chart,
    driftDirection,
    moveIntervalMs,
    state,
    sensorRange,
  } = data;

  const vector = DIR_VECTOR[driftDirection];
  if (!vector || !moveIntervalMs || state !== 'flying') return null;
  // The brake still projects: the track's length is driven by moveIntervalMs,
  // which grows as decelerate() bleeds speed away, so the projection collapses
  // onto the hull as the ship slows instead of vanishing outright.

  const size = chart?.size ?? 51;
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
    const nextX = tileX + vector[0];
    const nextY = tileY + vector[1];
    if (!isChartTile(nextX, nextY, size)) break;

    // A zone line is a full stop, not a tile the ship passes over.
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

// ---------------------------------------------------------------- contexts

/**
 * The selected contact, shared so the chart and the drawer highlight each other:
 * clicking a mark on the map scrolls it into focus in the list, and vice versa.
 */
export const Selection = createContext<{
  selected: string | null;
  select: (key: string) => void;
}>({ selected: null, select: () => {} });

export const useSelection = () => useContext(Selection);

/**
 * A request to bring an overmap tile into view. `nonce` is what makes a second
 * click on the same contact a fresh request.
 */
export type FocusRequest = { x: number; y: number; nonce: number };

/**
 * Picking a contact out of the register aims the chart at it. The camera lives
 * inside Chart, so the register posts a tile here and the chart decides what to
 * do about it (and can ignore a request for a mark already on screen).
 */
export const ChartFocus = createContext<{
  request: FocusRequest | null;
  focusOn: (x: number, y: number) => void;
}>({ request: null, focusOn: () => {} });

export const useChartFocus = () => useContext(ChartFocus);

/**
 * Where the right-click action menu is pinned and what it was opened on. `key`
 * is the contact under the cursor where there was one; bare chart opens a menu
 * on `tile` alone, since plotting a course is an action on a position.
 */
export type MenuState = {
  key: string | null;
  tile: { x: number; y: number };
  left: number;
  top: number;
};

/**
 * The right-click action menu, opened from either the chart or the contact
 * drawer and rendered once at the console root (panel wells are overflow:hidden).
 */
export const MenuControl = createContext<
  (event: MouseEvent, key: string | null, tile: { x: number; y: number }) => void
>(() => {});

export const useMenuControl = () => useContext(MenuControl);

/** Where the Dock button's option picker is pinned (own context, same root treatment). */
export const DockMenuControl = createContext<(event: MouseEvent) => void>(
  () => {},
);

export const useDockMenuControl = () => useContext(DockMenuControl);

/** Approximate menu box, used only to keep it inside the console. */
export const MENU_SIZE = { w: 260, h: 210 };

// Provider aliases, so the entry file reads cleanly.
export const SelectionProvider = Selection.Provider;
export const ChartFocusProvider = ChartFocus.Provider;
export const MenuControlProvider = MenuControl.Provider;
export const DockMenuControlProvider = DockMenuControl.Provider;
