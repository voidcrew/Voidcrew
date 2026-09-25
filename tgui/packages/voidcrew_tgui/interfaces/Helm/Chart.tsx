/**
 * Helm navigation chart, drawn on HelmPlane.
 *
 * The world is a `chart.size`-tile square that wraps on both axes. Coordinates
 * come from the server; this file only maps them to map-space pixels (tile * TILE,
 * y inverted so north is up) and drops nodes onto the plane. The camera and all
 * pan/zoom live in HelmPlane; the contact register aims it through the `focus`
 * prop.
 */
import { type CSSProperties, Fragment, useRef, useState } from 'react';
import { KeepScale } from 'react-zoom-pan-pinch';
import { Blink, Box, Button, Icon } from 'tgui-core/components';

import { HelmPlane } from './HelmPlane';
import { useBackend } from '../../backend';
import {
  type AutopilotPrefs,
  BURN_NONE,
  BURN_STOP,
  type Contact,
  type ContactKind,
  type Data,
  DIR_VECTOR,
} from './data';
import { ContactMark, PulseMark, ShipMark, TargetReticle } from './Glyphs';
import {
  bearingOf,
  clockOf,
  contactKey,
  isChartTile,
  useChartFocus,
  useContacts,
  useDrift,
  useLocked,
  useMenuControl,
  useSelection,
  useTravelClock,
  visibleCourseSegments,
} from './hooks';

/** Map-space pixels per overmap tile. */
const TILE = 26;
const MAP_PADDING = TILE * 10;
/** How far around the ship wrapped contact copies are drawn, in tiles. */
const WRAP_MARGIN = 8;

const SHIP_TINT = '#e0a72c';

/**
 * Contact families the label toggle keeps pinned open. Settlements and planets
 * join ruins: all three are places a crew plots a course toward, and reading
 * their names off the chart beats hovering each mark.
 */
const LABEL_KINDS: ContactKind[] = ['ruin', 'planet', 'outpost'];

/** 0 = up (north), clockwise. */
const courseAngle = (dir: number) => {
  const vector = DIR_VECTOR[dir];
  if (!vector) return 0;
  return (Math.atan2(vector[0], vector[1]) * 180) / Math.PI;
};

/**
 * Chevron marks evenly spaced along a polyline, each pointing the way the line
 * runs. Drawn as bare SVG paths in map space so they scale with the chart.
 */
const chevronMarks = (
  points: { x: number; y: number }[],
  spacing: number,
  size: number,
) => {
  const marks: string[] = [];
  let travelled = 0;
  let nextAt = spacing / 2;
  for (let i = 1; i < points.length; i++) {
    const from = points[i - 1];
    const to = points[i];
    const dx = to.x - from.x;
    const dy = to.y - from.y;
    const length = Math.hypot(dx, dy);
    if (!length) continue;
    const ux = (dx / length) * size;
    const uy = (dy / length) * size;
    while (nextAt <= travelled + length) {
      const t = (nextAt - travelled) / length;
      const cx = from.x + dx * t;
      const cy = from.y + dy * t;
      marks.push(
        `M${cx - ux + uy * 0.7},${cy - uy - ux * 0.7} L${cx + ux},${cy + uy} L${cx - ux - uy * 0.7},${cy - uy + ux * 0.7}`,
      );
      nextAt += spacing;
    }
    travelled += length;
  }
  return marks.join(' ');
};

const AUTOPILOT_ZONES: {
  key: keyof AutopilotPrefs;
  label: string;
  colour: string;
}[] = [
  { key: 'allowNeutral', label: 'Neutral Zone', colour: '#59b871' },
  { key: 'allowContested', label: 'Contested Zone', colour: '#d9a230' },
  { key: 'allowLawless', label: 'Lawless Zone', colour: '#cf4a38' },
];

/** Flight-policy toggles shown over the chart, straight from the server prefs. */
const AutopilotZones = () => {
  const { act, data } = useBackend<Data>();
  const locked = useLocked();
  const prefs = data.autopilot?.prefs;
  if (!prefs) return null;
  return (
    <div className="Helm__zoneControls">
      <div className="Helm__zoneTitle">A/P: ALLOWED ZONES</div>
      <div className="Helm__zoneButtons">
        {AUTOPILOT_ZONES.map(({ key, label, colour }) => (
          <button
            key={key}
            type="button"
            className="Helm__zoneButton"
            style={{ borderTopColor: colour }}
            aria-pressed={!!prefs[key]}
            disabled={locked}
            title={`${prefs[key] ? 'Block' : 'Allow'} autopilot entry into the ${label}`}
            onClick={() =>
              act('autopilot_pref', { key, value: prefs[key] ? 0 : 1 })
            }
          >
            <span>{label}</span>
            <span className="Helm__zoneState">
              <span
                className={`Helm__zoneLight ${prefs[key] ? 'Helm--allowed' : 'Helm--blocked'}`}
              />
              {prefs[key] ? 'Allowed' : 'Blocked'}
            </span>
          </button>
        ))}
      </div>
    </div>
  );
};

export const Chart = () => {
  const { act, data } = useBackend<Data>();
  const {
    x,
    y,
    chart,
    sensorRange,
    transmissions = [],
    autopilot,
    burnDirection,
    driftDirection,
    speed,
    heading,
    eta,
  } = data;

  const size = chart?.size ?? 51;
  const centre = chart?.centre ?? (size - 1) / 2;
  const maxRadius = (size - 1) / 2;
  const viewRange = chart?.viewRange ?? 4;
  const mapPx = size * TILE;

  const contacts = useContacts();
  const drift = useDrift(contacts);
  const { selected, select } = useSelection();
  const openMenu = useMenuControl();
  const { request: focusRequest, focusOn } = useChartFocus();
  const locked = useLocked();
  const travelClock = useTravelClock();
  // Uncontrolled drift extrapolation is misleading while autopilot owns steering.
  const showDrift = !!drift && !autopilot?.engaged;
  // Time to run the plotted course, on the same clock the register shows.
  const destinationEta =
    autopilot?.engaged && autopilot.destX != null && autopilot.destY != null
      ? travelClock(autopilot.destX, autopilot.destY)
      : null;

  const [hovered, setHovered] = useState<string | null>(null);
  // Live camera zoom, only so the grid can fade out as the chart widens. Stored
  // quantised and only on scale change, so panning never re-renders the SVG.
  const [cameraScale, setCameraScale] = useState(1);
  const gridOpacity = Math.max(0, Math.min(1, (cameraScale - 0.5) / 0.5));
  // Opt-in always-on labels for the places a crew flies to (ruins, planets and
  // trader outposts), so they can be read without hovering each mark. Off by
  // default; labels can crowd a busy map.
  const [showLabels, setShowLabels] = useState(false);

  // Nodes anchor at the CENTRE of their tile, not its top-left corner.
  const toX = (tileX: number) => (tileX + 0.5) * TILE;
  const toY = (tileY: number) => (size - tileY - 0.5) * TILE;
  const toTile = (px: number, py: number) => ({
    x: Math.floor(px / TILE),
    y: Math.floor(size - py / TILE),
  });

  const shipPx = { x: toX(x), y: toY(y) };
  // Face where the hull is actually going; fall back to the commanded course,
  // and to the last heading held so braking or stopping does not snap the token
  // back to due north.
  const rawCourse = data.driftDirection || data.commandedCourse || 0;
  const lastFacing = useRef(0);
  if (rawCourse) lastFacing.current = rawCourse;
  const shipCourse = rawCourse || lastFacing.current;
  // One request stream for the register and the recentre button, so whichever
  // was pressed last is the one the camera follows.
  const focus = focusRequest
    ? {
        x: toX(focusRequest.x),
        y: toY(focusRequest.y),
        nonce: focusRequest.nonce,
      }
    : null;

  // The base copy is always drawn; wrapped copies are added only while the
  // contact sits near the seam, so a charted contact on the far side isn't lost.
  const copiesOf = (tileX: number, tileY: number) => {
    const out: { x: number; y: number }[] = [{ x: tileX, y: tileY }];
    for (const ox of [-size, size]) {
      for (const oy of [-size, size]) {
        const cx = tileX + ox;
        const cy = tileY + oy;
        if (
          Math.abs(cx - x) <= WRAP_MARGIN + viewRange &&
          Math.abs(cy - y) <= WRAP_MARGIN + viewRange
        ) {
          out.push({ x: cx, y: cy });
        }
      }
    }
    return out;
  };

  const ringStyle = (radiusTiles: number, colour: string): CSSProperties => {
    const d = radiusTiles * 2 * TILE;
    return {
      width: `${d}px`,
      height: `${d}px`,
      borderRadius: '50%',
      border: `1px dashed ${colour}`,
      pointerEvents: 'none',
    };
  };

  const contactNode = (
    contact: Contact,
    px: number,
    py: number,
    key: string,
  ) => {
    const keyRef = contactKey(contact);
    const isSelected = selected === keyRef;
    return (
      <HelmPlane.Button
        key={key}
        x={px}
        y={py}
        selected={isSelected}
        tooltip={contact.name}
        tooltipAlways={
          contact.kind === 'ship' ||
          (showLabels && LABEL_KINDS.includes(contact.kind))
        }
        onClick={() => select(keyRef)}
        onContextMenu={(event) => {
          event.preventDefault();
          openMenu(event, keyRef, { x: contact.x, y: contact.y });
        }}
      >
        <div
          onMouseEnter={() => setHovered(keyRef)}
          onMouseLeave={() =>
            setHovered((cur) => (cur === keyRef ? null : cur))
          }
          style={{ display: 'flex' }}
        >
          <ContactMark contact={contact} size={TILE * 0.6} />
        </div>
      </HelmPlane.Button>
    );
  };

  const hoveredContact = hovered
    ? contacts.find((entry) => contactKey(entry) === hovered)
    : undefined;

  // Trajectory geometry, shared by the lines and the chevrons that ride them.
  const driftPoints =
    drift && drift.tiles.length > 0
      ? [
          shipPx,
          ...drift.tiles.map((tile) => ({ x: toX(tile.x), y: toY(tile.y) })),
        ]
      : [];
  const routeSegments =
    (autopilot?.path?.length ?? 0) > 0
      ? visibleCourseSegments([x, y], autopilot?.path ?? [], [x, y], size)
      : [];
  // A barrier crossing leaves a gap between segments. Each unbroken stretch gets
  // its own chevrons, so none are drawn across the map along the gap.
  const routeRuns: { x: number; y: number }[][] = [];
  let runEnd: readonly [number, number] | null = null;
  for (const segment of routeSegments) {
    if (
      !runEnd ||
      runEnd[0] !== segment.from[0] ||
      runEnd[1] !== segment.from[1]
    ) {
      routeRuns.push([{ x: toX(segment.from[0]), y: toY(segment.from[1]) }]);
    }
    routeRuns[routeRuns.length - 1].push({
      x: toX(segment.to[0]),
      y: toY(segment.to[1]),
    });
    runEnd = segment.to;
  }
  const driftArrows = chevronMarks(driftPoints, TILE, TILE * 0.16);
  const routeArrows = routeRuns
    .map((run) => chevronMarks(run, TILE, TILE * 0.16))
    .filter(Boolean)
    .join(' ');

  // Autopilot readout and the ship-recentre button share the plane's control
  // strip along the bottom of the chart, next to the map's own zoom controls.
  const autopilotReadout = (
    <>
      {!!autopilot?.engaged && (
        <div className="Helm__course">
          <span className="Helm__courseLabel">
            A/P · {autopilot.label ?? 'plotted position'}
          </span>
          {(autopilot.path?.length ?? 0) > 0 && (
            <span
              className="Helm__courseDist"
              title="The green line and arrows show the remaining autopilot route"
            >
              {autopilot.path.length} tiles
            </span>
          )}
          {!!autopilot.dockOnArrival && (
            <span className="Helm__courseDist">Dock on arrival</span>
          )}
          <button
            type="button"
            className="Helm__btn"
            disabled={locked}
            title="Stand the autopilot down and take manual control"
            onClick={() => act('autopilot_cancel')}
          >
            Cancel
          </button>
        </div>
      )}
      {!autopilot?.engaged && (
        <div className="Helm__course">
          <span className="Helm__courseStatus">
            {autopilot?.status ? `MANUAL · ${autopilot.status}` : 'MANUAL'}
          </span>
        </div>
      )}
    </>
  );

  // Autopilot on the left of the strip; the map's own controls and the ship
  // recentre all sit to the right.
  const controlsExtra = autopilotReadout;

  // Takes the built-in centre-the-view button's slot: a chart-scoped toggle for
  // always-on labels on ruins, planets and trader outposts instead.
  const controlsCenter = (
    <Button
      icon="tags"
      selected={showLabels}
      tooltip={
        showLabels
          ? 'Hide labels on ruins, planets and outposts'
          : 'Label every ruin, planet and outpost on the chart'
      }
      onClick={() => setShowLabels((value) => !value)}
    />
  );

  const controlsActions = (
    <Button
      icon="crosshairs"
      tooltip="Recentre on the ship"
      onClick={() => focusOn(x, y)}
    />
  );

  return (
    <div className="Helm__chart">
      <HelmPlane
        mapWidth={mapPx}
        mapHeight={mapPx}
        padding={MAP_PADDING}
        maxScale={3}
        focus={focus}
        controlsClassName="Helm__chartControls"
        centerAction={controlsCenter}
        controlsExtra={controlsExtra}
        controlsActions={controlsActions}
        initialFocus={{ x: shipPx.x, y: shipPx.y }}
        onTransform={(camera) => {
          const next = Math.round(camera.scale * 100) / 100;
          setCameraScale((prev) => (prev === next ? prev : next));
        }}
        stageBackground={
          <div
            style={{ position: 'absolute', inset: 0, background: '#0d1018' }}
          />
        }
        background={
          <div
            style={{ position: 'absolute', inset: 0, pointerEvents: 'auto' }}
            onContextMenu={(event) => {
              event.preventDefault();
              const native = event.nativeEvent;
              openMenu(event, null, toTile(native.offsetX, native.offsetY));
            }}
          >
            <svg
              width={mapPx}
              height={mapPx}
              style={{
                position: 'absolute',
                inset: 0,
                pointerEvents: 'none',
              }}
            >
              {/* Zone bands, drawn as nested discs largest first so each reads
                  as an annulus. Matches get_zone_band_for_turf(): the ring
                  against the sun is the safe green zone, the outer ring at the
                  map edge is red. Nothing is painted past the outer circle. */}
              <circle
                cx={toX(centre)}
                cy={toY(centre)}
                r={maxRadius * TILE}
                fill="rgba(207, 74, 56, 0.06)"
              />
              <circle
                cx={toX(centre)}
                cy={toY(centre)}
                r={maxRadius * (chart?.ringMiddle ?? 0.66) * TILE}
                fill="rgba(217, 162, 48, 0.05)"
              />
              <circle
                cx={toX(centre)}
                cy={toY(centre)}
                r={maxRadius * (chart?.ringInner ?? 0.33) * TILE}
                fill="rgba(89, 184, 113, 0.06)"
              />
              {[1, 0.66, 0.33].map((ratio) => (
                <circle
                  key={ratio}
                  cx={toX(centre)}
                  cy={toY(centre)}
                  r={maxRadius * ratio * TILE}
                  fill="none"
                  stroke="rgba(255, 255, 255, 0.18)"
                  strokeDasharray="4 6"
                />
              ))}
              {Array.from({ length: size + 1 }, (_, i) => (
                <Fragment key={i}>
                  <line
                    x1={i * TILE}
                    y1={0}
                    x2={i * TILE}
                    y2={mapPx}
                    stroke={`rgba(255, 255, 255, ${0.05 * gridOpacity})`}
                  />
                  <line
                    x1={0}
                    y1={i * TILE}
                    x2={mapPx}
                    y2={i * TILE}
                    stroke={`rgba(255, 255, 255, ${0.05 * gridOpacity})`}
                  />
                </Fragment>
              ))}
              <defs>
                <radialGradient id="helm-sun-bloom">
                  <stop offset="0%" stopColor={SHIP_TINT} stopOpacity={0.5} />
                  <stop offset="45%" stopColor={SHIP_TINT} stopOpacity={0.16} />
                  <stop offset="100%" stopColor={SHIP_TINT} stopOpacity={0} />
                </radialGradient>
              </defs>
              {/* A soft halo around the sun so its disc reads as glowing rather
                  than as a flat pip. */}
              <circle
                cx={toX(centre)}
                cy={toY(centre)}
                r={TILE * 5}
                fill="url(#helm-sun-bloom)"
              />
              <circle
                cx={toX(centre)}
                cy={toY(centre)}
                r={TILE * 1.4}
                fill={SHIP_TINT}
                opacity={0.9}
              />
            </svg>
          </div>
        }
      >
        <HelmPlane.Button
          x={shipPx.x}
          y={shipPx.y}
          zIndex={1}
          style={{ pointerEvents: 'none' }}
        >
          <div style={ringStyle(viewRange, 'rgba(255,255,255,0.25)')} />
        </HelmPlane.Button>
        <HelmPlane.Button
          x={shipPx.x}
          y={shipPx.y}
          zIndex={1}
          style={{ pointerEvents: 'none' }}
        >
          <div
            style={ringStyle(sensorRange ?? viewRange, 'rgba(89,184,113,0.35)')}
          />
        </HelmPlane.Button>

        {contacts.flatMap((contact) =>
          copiesOf(contact.x, contact.y)
            .filter(({ x: cx, y: cy }) => isChartTile(cx, cy, size))
            .map((copy, index) =>
              contactNode(
                contact,
                toX(copy.x),
                toY(copy.y),
                `${contactKey(contact)}#${index}`,
              ),
            ),
        )}

        {((showDrift && !!drift && drift.tiles.length > 0) ||
          (autopilot?.path?.length ?? 0) > 0) && (
          <HelmPlane.Button x={0} y={0} anchor="top-left" zIndex={0}>
            <svg
              width={mapPx}
              height={mapPx}
              style={{
                position: 'absolute',
                left: 0,
                top: 0,
                pointerEvents: 'none',
                overflow: 'visible',
              }}
            >
              {showDrift && driftPoints.length > 1 && (
                <>
                  <polyline
                    points={driftPoints
                      .map((point) => `${point.x},${point.y}`)
                      .join(' ')}
                    fill="none"
                    stroke={SHIP_TINT}
                    strokeOpacity={0.6}
                    strokeWidth={1}
                    strokeDasharray="5 4"
                  />
                  <path
                    d={driftArrows}
                    fill="none"
                    stroke={SHIP_TINT}
                    strokeOpacity={0.9}
                    strokeWidth={1}
                  />
                </>
              )}
              {routeSegments.map((segment, index) => (
                <line
                  key={`route-${index}`}
                  x1={toX(segment.from[0])}
                  y1={toY(segment.from[1])}
                  x2={toX(segment.to[0])}
                  y2={toY(segment.to[1])}
                  stroke="#59b871"
                  strokeWidth={1}
                />
              ))}
              {!!routeArrows && (
                <path
                  d={routeArrows}
                  fill="none"
                  stroke="#59b871"
                  strokeWidth={1}
                />
              )}
            </svg>
          </HelmPlane.Button>
        )}
        {!!drift?.hold && (
          <HelmPlane.Button
            x={toX(drift.hold.x)}
            y={toY(drift.hold.y)}
            zIndex={2}
          >
            <Icon name="ban" color="bad" size={1.5} />
          </HelmPlane.Button>
        )}

        {autopilot?.destX != null && autopilot?.destY != null && (
          <HelmPlane.Button
            x={toX(autopilot.destX)}
            y={toY(autopilot.destY)}
            zIndex={2}
          >
            <div className="Helm__target">
              {!!destinationEta && (
                <span className="Helm__etaAnchor">
                  <KeepScale style={{ transformOrigin: '50% 100%' }}>
                    <span className="Helm__eta">{destinationEta}</span>
                  </KeepScale>
                </span>
              )}
              <TargetReticle />
            </div>
          </HelmPlane.Button>
        )}

        {/* Manual flight: a clock above every projected cell, and a pip at the
            end of the run. */}
        {!!showDrift &&
          !!drift &&
          drift.tiles.map((tile) => (
            <HelmPlane.Button
              key={`eta-${tile.x}-${tile.y}-${tile.step}`}
              x={toX(tile.x)}
              y={toY(tile.y)}
              zIndex={1}
            >
              <span className="Helm__etaAnchor">
                <KeepScale style={{ transformOrigin: '50% 100%' }}>
                  <span className="Helm__eta">
                    {clockOf(tile.step * drift.stepMs)}
                  </span>
                </KeepScale>
              </span>
            </HelmPlane.Button>
          ))}
        {showDrift && !!drift && drift.tiles.length > 0 && (
          <HelmPlane.Button
            x={toX(drift.end.x)}
            y={toY(drift.end.y)}
            zIndex={2}
          >
            <TargetReticle />
          </HelmPlane.Button>
        )}

        {transmissions.map((signal, index) => (
          <HelmPlane.Button
            key={`tx-${index}`}
            x={toX(signal.x)}
            y={toY(signal.y)}
            zIndex={3}
          >
            {signal.live ? (
              <Blink>
                <PulseMark
                  colour={signal.own ? SHIP_TINT : '#8c9ea2'}
                  size={14}
                />
              </Blink>
            ) : null}
          </HelmPlane.Button>
        ))}

        <HelmPlane.Button id="helm-ship" x={shipPx.x} y={shipPx.y} zIndex={5}>
          <ShipMark size={28} direction={courseAngle(shipCourse)} />
        </HelmPlane.Button>
      </HelmPlane>
      {/* Readouts ride over the plane. The plane keeps its own zoom/pan
          controls in the bottom-right corner, so the HUD hugs the other
          edges and the recentre sits just above them. */}
      <div
        className="Helm__hud"
        style={{ top: 8, right: 8, textAlign: 'right', zIndex: 10 }}
      >
        <div className="Helm__hudBig">{speed?.toFixed(1) ?? '0.0'}</div>
        <div className="Helm__hudLine">
          <span className="Helm__hudKey">SPM · TILE</span> {eta || '-'}
        </div>
      </div>
      {/* Flight readouts sit in the chart's top-left corner, away from the
          zoom/pan controls along the bottom and the speed slab on the right. */}
      <div className="Helm__hud Helm--tl" style={{ zIndex: 10 }}>
        <div className="Helm__readouts">
          <div className="Helm__hudLine">
            <span className="Helm__hudKey">HDG</span>{' '}
            {burnDirection === BURN_STOP
              ? 'BRAKING'
              : burnDirection !== BURN_NONE
                ? heading
                : drift
                  ? `DRIFT ${bearingOf(drift.vector[0], drift.vector[1])}`
                  : 'HOLDING'}
          </div>
          <div className="Helm__hudLine">
            <span className="Helm__hudKey">POS</span>{' '}
            {String(x).padStart(2, '0')} / {String(y).padStart(2, '0')}
          </div>
          {showDrift && !!drift && (
            <div className="Helm__hudLine Helm--drift">
              <span className="Helm__hudKey">ENDS</span>{' '}
              {String(drift.end.x).padStart(2, '0')} /{' '}
              {String(drift.end.y).padStart(2, '0')} · {clockOf(drift.endMs)}
            </div>
          )}
          {showDrift && !!drift?.intercept && (
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
      </div>
      <div
        className="Helm__hud Helm__hud--row"
        style={{ bottom: '3cqw', left: 8, zIndex: 10 }}
      >
        <AutopilotZones />
      </div>
      {!!hoveredContact && (
        <Box
          position="absolute"
          top="0.5em"
          left="50%"
          backgroundColor="black"
          style={{ pointerEvents: 'none', transform: 'translateX(-50%)' }}
          px={0.5}
        >
          <b>{hoveredContact.name}</b> · {hoveredContact.dist}{' '}
          {hoveredContact.bearing}
        </Box>
      )}
    </div>
  );
};
