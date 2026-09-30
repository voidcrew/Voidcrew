/**
 * HelmPlane - a zoomable, pannable plane for top-down tactical maps.
 *
 * Adapted from BandaStation's NanoMap (https://github.com/ss220club/BandaStation)
 * for react-zoom-pan-pinch v4, stripped of the station-specific floors, stairs
 * and lavaland handling. The background is a slot, so consumers draw their own
 * map (an SVG star chart, a composited ship hull, ...) and drop nodes onto it.
 *
 * All node and background coordinates are in map-space pixels, independent of
 * the current zoom. Nodes scale with the map by default; wrap a label in
 * `keepScale` to keep it legible at any zoom.
 */
import { useLocalStorage } from '@uidotdev/usehooks';
import {
  type CSSProperties,
  type MouseEvent,
  type ReactNode,
  useEffect,
  useId,
  useMemo,
  useRef,
  useState,
} from 'react';
import {
  KeepScale,
  MiniMap,
  TransformComponent,
  TransformWrapper,
  useControls,
} from 'react-zoom-pan-pinch';
import { Button } from 'tgui-core/components';
import { clamp01 } from 'tgui-core/math';
import { classes } from 'tgui-core/react';
import { throttle } from 'tgui-core/timer';

/** Camera transform, mirroring react-zoom-pan-pinch's transform state. */
export type HelmPlaneCamera = {
  scale: number;
  positionX: number;
  positionY: number;
};

/** A camera with scale 0 means "never saved", so the plane fits on mount. */
const UNSET_CAMERA: HelmPlaneCamera = {
  scale: 0,
  positionX: 0,
  positionY: 0,
};

/** Camera is written at most once a second, to keep localStorage quiet. */
const CAMERA_WRITE_MS = 1000;

/**
 * One axis of a camera position kept on the content, the way `limitToBounds`
 * clamps a drag: content wider than the viewport stays against its edges, and
 * narrower content is centred. Programmatic moves skip that clamp, so without
 * this the first drag after one snaps the view.
 */
const boundAxis = (position: number, viewport: number, content: number) =>
  content <= viewport
    ? (viewport - content) / 2
    : Math.min(0, Math.max(viewport - content, position));

type MinimapConfig = {
  width?: number;
  height?: number;
  /** Separate minimap art; falls back to `background` when omitted. */
  content?: ReactNode;
};

type HelmPlaneProps = {
  /** Map-space size in pixels. */
  mapWidth: number;
  mapHeight: number;
  padding?: number;
  /** Fills the map-space, behind every node. */
  background?: ReactNode;
  /** Drawn in the stage, behind the map plane itself (e.g. a vignette). */
  stageBackground?: ReactNode;
  /** Nodes positioned in map-space, see `HelmPlane.Button`. */
  children?: ReactNode;
  /** Lower zoom bound. Defaults to half the scale that fits the whole map. */
  minScale?: number;
  /** Upper zoom bound. Default 4. */
  maxScale?: number;
  /** Zoom used when there is no saved camera. */
  initialScale?: number;
  /** Fit the map on first mount when no camera was saved. Default true. */
  fitOnInit?: boolean;
  /** Centre the map on init. Default true. */
  centerOnInit?: boolean;
  /**
   * Open centred on this map-space point at `initialScale` (default 1) instead
   * of fitting or centring the map. Ignored when a saved camera is restored.
   */
  initialFocus?: { x: number; y: number } | null;
  /** Render the zoom controls. Default true. */
  controls?: boolean;
  /** Extra class on the controls row, so a consumer can theme the buttons. */
  controlsClassName?: string;
  /**
   * Replaces the built-in centre-the-view button. Consumers that need a
   * chart-scoped toggle in its slot (rather than a centre action) pass their
   * own node; omitting it keeps the default control.
   */
  centerAction?: ReactNode;
  /** Rendered before the built-in controls, inside the same row (left slot). */
  controlsExtra?: ReactNode;
  /** Rendered after the built-in controls, inside the same row (right slot). */
  controlsActions?: ReactNode;
  minimap?: boolean | MinimapConfig;
  /** Persist the camera under this key; omit for a transient camera. */
  storageKey?: string;
  /**
   * Ask the plane to centre this map-space point. `nonce` makes a repeat request
   * for the same point a fresh one. Consumers that don't own the camera (a
   * contact register, say) drive it through this rather than by reaching in.
   */
  focus?: { x: number; y: number; nonce: number } | null;
  /** Pan animation when `focus` changes, ms. Default 260. */
  focusDuration?: number;
  onTransform?: (camera: HelmPlaneCamera) => void;
  className?: string;
};

type HelmPlaneButtonProps = {
  /** Map-space position in pixels. */
  x: number;
  y: number;
  /** Anchor point of the node at (x, y). Default 'center'. */
  anchor?: 'center' | 'top-left';
  id?: string;
  selected?: boolean;
  /** Follow this node as it moves. */
  tracking?: boolean;
  trackingDuration?: number;
  hidden?: boolean;
  /** Facing in degrees, 0 = up; renders a pointer behind the children. */
  direction?: number | null;
  /** Counter-scale the node so it stays legible at any zoom. */
  keepScale?: boolean;
  tooltip?: string;
  /** Keep the tooltip visible without hover (e.g. always-on ship labels). */
  tooltipAlways?: boolean;
  onClick?: (event: MouseEvent) => void;
  onContextMenu?: (event: MouseEvent) => void;
  className?: string;
  style?: CSSProperties;
  zIndex?: number;
  children?: ReactNode;
};

const TRANSIENT_KEY = '__helm_plane_transient__';

export const HelmPlane = Object.assign(HelmPlaneInner, {
  Button: HelmPlaneButton,
});

function HelmPlaneInner(props: HelmPlaneProps) {
  const {
    mapWidth,
    mapHeight,
    padding = 0,
    background,
    stageBackground,
    children,
    minScale,
    maxScale = 4,
    initialScale,
    fitOnInit = true,
    centerOnInit = true,
    initialFocus,
    controls = true,
    controlsClassName,
    centerAction,
    controlsExtra,
    controlsActions,
    minimap,
    storageKey,
    focus,
    focusDuration,
    onTransform,
    className,
  } = props;

  // `useLocalStorage` needs a key at all times, so transient planes get a
  // per-instance one that is wiped on unmount. Only an explicit `storageKey`
  // is treated as a camera worth restoring.
  const instanceId = useId();
  const storeKey = storageKey ?? `${TRANSIENT_KEY}_${instanceId}`;
  const persistent = !!storageKey;
  const [camera, setCamera] = useLocalStorage<HelmPlaneCamera>(
    storeKey,
    UNSET_CAMERA,
  );
  const hasSaved = persistent && !!camera && camera.scale > 0;

  useEffect(() => {
    if (persistent) {
      return;
    }
    return () => {
      try {
        window.localStorage.removeItem(storeKey);
      } catch {
        // Ignore private-mode/storage failures - the plane still works.
      }
    };
  }, [persistent, storeKey]);

  // Live transform, kept for the controls readout and tracking. Persisting is
  // throttled separately so dragging does not hammer localStorage.
  const [transform, setTransform] = useState<HelmPlaneCamera>(
    hasSaved ? camera : { ...UNSET_CAMERA, scale: initialScale ?? 0 },
  );
  const [fitFloor, setFitFloor] = useState<number | null>(null);

  const persistCamera = useMemo(
    () => throttle((next: HelmPlaneCamera) => setCamera(next), CAMERA_WRITE_MS),
    [setCamera],
  );

  const minimapConfig: MinimapConfig | null =
    minimap === true ? {} : minimap || null;
  const [minimapVisible, setMinimapVisible] = useState(!!minimapConfig);

  const handleTransform = (
    _ref: unknown,
    state: { scale: number; positionX: number; positionY: number },
  ) => {
    const next: HelmPlaneCamera = {
      scale: state.scale,
      positionX: state.positionX,
      positionY: state.positionY,
    };
    setTransform(next);
    persistCamera(next);
    onTransform?.(next);
  };

  const contentWidth = mapWidth + padding * 2;
  const contentHeight = mapHeight + padding * 2;

  // The lower zoom bound is half the scale that fits the whole map in the stage.
  // It comes from the stage and map sizes, not from the first camera, so a plane
  // that opens zoomed in (a restored camera, an initial focus) can still be
  // zoomed out to the whole map. Re-measured when the window is resized.
  const stageRef = useRef<HTMLDivElement>(null);
  useEffect(() => {
    const stage = stageRef.current;
    if (!stage) {
      return;
    }
    const measure = () => {
      const { clientWidth, clientHeight } = stage;
      if (!clientWidth || !clientHeight) {
        return;
      }
      const fit = Math.min(
        clientWidth / contentWidth,
        clientHeight / contentHeight,
      );
      setFitFloor(fit / 2);
    };
    measure();
    if (typeof ResizeObserver === 'undefined') {
      return;
    }
    const observer = new ResizeObserver(measure);
    observer.observe(stage);
    return () => observer.disconnect();
  }, [contentWidth, contentHeight]);

  const resolvedMinScale = minScale ?? fitFloor ?? 0.01;
  // Decided once at mount: the first transform saves a camera, which would
  // otherwise flip `hasSaved` before the opening camera has been placed.
  const [openedFromSave] = useState(hasSaved);
  // An initial focus owns the opening camera. The library's own fit/centre
  // layout is re-applied on its first resize notification, which can land after
  // the focus and throw the view back to the middle of the map.
  const libraryLayout = !openedFromSave && !initialFocus;

  return (
    <TransformWrapper
      initialScale={hasSaved ? camera.scale : initialScale}
      initialPositionX={hasSaved ? camera.positionX : undefined}
      initialPositionY={hasSaved ? camera.positionY : undefined}
      minScale={resolvedMinScale}
      maxScale={maxScale}
      fitOnInit={fitOnInit && libraryLayout}
      centerOnInit={centerOnInit && libraryLayout}
      // Keep the camera on the map: drag and wheel stop at the content edges,
      // and a zoomed-out map is centred instead of drifting off. Without this
      // the plane is infinite and a flick can leave the map far off screen.
      limitToBounds
      centerZoomedOut
      disablePadding
      doubleClick={{ disabled: true }}
      panning={{ velocityDisabled: true }}
      // `smooth` (default on) multiplies the wheel step by |deltaY|, which turns
      // one mouse-wheel notch (deltaY ~100) into a ~1x leap. Off, the wheel moves
      // by `step` per notch, matching the +/- buttons.
      smooth={false}
      wheel={{ step: 0.15 }}
      // Keep the camera put when the map content changes size (e.g. swapping a
      // hull preview); consumers may redraw without the view jumping.
      autoAlignment={{ disabled: true }}
      onTransform={handleTransform}
    >
      <HelmPlaneFocus
        focus={focus}
        duration={focusDuration}
        initial={openedFromSave ? null : initialFocus}
        initialScale={initialScale}
        padding={padding}
      />
      <div className={classes(['HelmPlane', className])}>
        <div className="HelmPlane__Stage" ref={stageRef}>
          {stageBackground}
          <TransformComponent
            wrapperStyle={{ width: '100%', height: '100%' }}
            contentStyle={{
              width: `${contentWidth}px`,
              height: `${contentHeight}px`,
            }}
          >
            <div
              className="HelmPlane__Map"
              style={{
                width: `${contentWidth}px`,
                height: `${contentHeight}px`,
              }}
            >
              <div
                className="HelmPlane__Inner"
                style={{
                  left: `${padding}px`,
                  top: `${padding}px`,
                  width: `${mapWidth}px`,
                  height: `${mapHeight}px`,
                }}
              >
                {!!background && (
                  <div className="HelmPlane__Background">{background}</div>
                )}
                {children}
              </div>
            </div>
          </TransformComponent>
        </div>

        {!!(minimapConfig && minimapVisible) && (
          <div className="HelmPlane__Minimap">
            <MiniMap
              width={minimapConfig.width ?? 150}
              height={minimapConfig.height}
            >
              <div
                className="HelmPlane__Map HelmPlane__Map--minimap"
                style={{ width: `${mapWidth}px`, height: `${mapHeight}px` }}
              >
                {minimapConfig.content ?? background}
              </div>
            </MiniMap>
          </div>
        )}

        {!!controls && (
          <HelmPlaneControls
            scale={transform.scale}
            minScale={resolvedMinScale}
            maxScale={maxScale}
            minimapAvailable={!!minimapConfig}
            minimapVisible={minimapVisible}
            className={controlsClassName}
            center={centerAction}
            extra={controlsExtra}
            actions={controlsActions}
            onToggleMinimap={() => setMinimapVisible((value) => !value)}
          />
        )}
      </div>
    </TransformWrapper>
  );
}

function HelmPlaneFocus(props: {
  focus?: { x: number; y: number; nonce: number } | null;
  duration?: number;
  initial?: { x: number; y: number } | null;
  initialScale?: number;
  padding?: number;
}) {
  const { setTransform, instance } = useControls();
  const served = useRef(0);
  const initialServed = useRef(false);
  // The map's origin sits `padding` into the bounded content box, so map-space
  // points have to be offset by it before they are centred.
  const pad = props.padding ?? 0;
  // The consumer passes a fresh object every render (the ship moves), and
  // useControls() hands out new functions every render, so both are read
  // through refs. The size watcher below is set up once, not per render.
  const initialRef = useRef(props.initial);
  initialRef.current = props.initial;
  const initialScaleRef = useRef(props.initialScale);
  initialScaleRef.current = props.initialScale;
  const setTransformRef = useRef(setTransform);
  setTransformRef.current = setTransform;
  const hasInitial = !!props.initial;

  useEffect(() => {
    const wrapper = instance.wrapperComponent;
    if (!hasInitial || !wrapper) {
      return;
    }
    let lastWidth = 0;
    let lastHeight = 0;
    const onSize = () => {
      const width = wrapper.clientWidth;
      const height = wrapper.clientHeight;
      if (!width || !height) {
        return;
      }
      if (!initialServed.current) {
        // The window can mount the plane before it has a size; wait for one.
        const point = initialRef.current;
        if (!point) {
          return;
        }
        initialServed.current = true;
        centreOn(
          instance,
          setTransformRef.current,
          pad + point.x,
          pad + point.y,
          initialScaleRef.current ?? 1,
          0,
        );
      } else if (
        lastWidth &&
        lastHeight &&
        (width !== lastWidth || height !== lastHeight)
      ) {
        // A resized viewport (the window laying itself out, or the player
        // resizing it) keeps the same point in the middle rather than
        // sliding the view off towards a corner.
        const { positionX, positionY, scale } = instance.state;
        centreOn(
          instance,
          setTransformRef.current,
          (lastWidth / 2 - positionX) / scale,
          (lastHeight / 2 - positionY) / scale,
          scale,
          0,
        );
      }
      lastWidth = width;
      lastHeight = height;
    };
    onSize();
    if (typeof ResizeObserver === 'undefined') {
      return;
    }
    const observer = new ResizeObserver(onSize);
    observer.observe(wrapper);
    return () => observer.disconnect();
  }, [hasInitial, pad, instance]);

  useEffect(() => {
    const request = props.focus;
    if (!request || request.nonce === served.current) {
      return;
    }
    served.current = request.nonce;
    // Center the map-space point in the viewport at the current zoom.
    centreOn(
      instance,
      setTransform,
      pad + request.x,
      pad + request.y,
      instance.state.scale,
      props.duration ?? 260,
    );
  }, [props.focus, props.duration, pad, instance, setTransform]);

  return null;
}

type PlaneControls = ReturnType<typeof useControls>;

/**
 * Moves the camera so a content-space point sits in the middle of the viewport
 * at `scale`, as far as the content's edges allow.
 */
function centreOn(
  instance: PlaneControls['instance'],
  setTransform: PlaneControls['setTransform'],
  contentX: number,
  contentY: number,
  scale: number,
  duration: number,
) {
  const wrapper = instance.wrapperComponent;
  const content = instance.contentComponent;
  if (!wrapper || !content) {
    return;
  }
  const width = wrapper.clientWidth;
  const height = wrapper.clientHeight;
  setTransform(
    boundAxis(width / 2 - contentX * scale, width, content.offsetWidth * scale),
    boundAxis(
      height / 2 - contentY * scale,
      height,
      content.offsetHeight * scale,
    ),
    scale,
    duration,
    'easeOut',
  );
}

function HelmPlaneControls(props: {
  scale: number;
  minScale: number;
  maxScale: number;
  minimapAvailable: boolean;
  minimapVisible: boolean;
  className?: string;
  center?: ReactNode;
  extra?: ReactNode;
  actions?: ReactNode;
  onToggleMinimap: () => void;
}) {
  const {
    zoomIn,
    zoomOut,
    centerView,
    setTransform,
    clientToContent,
    instance,
  } = useControls();
  const {
    scale,
    minScale,
    maxScale,
    minimapAvailable,
    minimapVisible,
    className,
    center,
    extra,
    actions,
    onToggleMinimap,
  } = props;

  const span = Math.max(maxScale - minScale, 0.0001);
  const zoomFraction = clamp01((scale - minScale) / span);

  return (
    <div className={classes(['HelmPlane__Controls', className])}>
      {!!extra && <div className="HelmPlane__Controls--extra">{extra}</div>}

      <div className="HelmPlane__Controls--main">
        <Button icon="minus" onClick={() => zoomOut(0.15)} />
        <Button
          icon="refresh"
          tooltip="Reset zoom to 1x"
          onClick={() => {
            const wrapper = instance.wrapperComponent;
            if (!wrapper) {
              return;
            }
            // Zoom about whatever is in the middle of the view now.
            const rect = wrapper.getBoundingClientRect();
            const centre = clientToContent(
              rect.left + rect.width / 2,
              rect.top + rect.height / 2,
            );
            centreOn(instance, setTransform, centre.x, centre.y, 1, 200);
          }}
        />
        <Button icon="plus" onClick={() => zoomIn(0.15)} />
        {center !== undefined ? (
          center
        ) : (
          <Button
            className="HelmPlane__Controls--center"
            icon="bullseye"
            tooltip="Centre the view"
            onClick={() => centerView()}
          >
            <div
              className="HelmPlane__Controls--fill"
              style={{ width: `${zoomFraction * 100}%` }}
            />
          </Button>
        )}

        {actions}

        {!!minimapAvailable && (
          <Button
            icon={minimapVisible ? 'map' : 'map-o'}
            selected={minimapVisible}
            tooltip={minimapVisible ? 'Hide minimap' : 'Show minimap'}
            onClick={onToggleMinimap}
          />
        )}
      </div>
    </div>
  );
}

function HelmPlaneButton(props: HelmPlaneButtonProps) {
  const {
    x,
    y,
    anchor = 'center',
    id,
    selected = false,
    tracking = false,
    trackingDuration = 1000,
    hidden = false,
    direction,
    keepScale = false,
    tooltip,
    tooltipAlways = false,
    onClick,
    onContextMenu,
    className,
    style,
    zIndex,
    children,
  } = props;

  const generatedId = useId();
  const nodeId = id ?? generatedId;
  const { zoomToElement, instance } = useControls();

  // Follow the node's map-space position as it updates. The duration is
  // caller-controlled so a fast-moving contact can be watched smoothly.
  useEffect(() => {
    if (!tracking || !selected || hidden) {
      return;
    }
    const currentScale = instance.state.scale;
    zoomToElement(nodeId, currentScale, trackingDuration, 'linear');
  }, [
    x,
    y,
    tracking,
    selected,
    hidden,
    nodeId,
    trackingDuration,
    zoomToElement,
    instance,
  ]);

  if (hidden) {
    return null;
  }

  const transform =
    anchor === 'center'
      ? `translate(${x}px, ${y}px) translate(-50%, -50%)`
      : `translate(${x}px, ${y}px)`;

  const inner = keepScale ? (
    <KeepScale style={{ transformOrigin: '0 0' }}>{children}</KeepScale>
  ) : (
    children
  );

  return (
    <div
      id={nodeId}
      className={classes([
        'HelmPlane__Node',
        selected && 'HelmPlane__Node--selected',
        tracking && 'HelmPlane__Node--tracking',
        className,
      ])}
      style={{ transform, zIndex, ...style }}
      onClick={onClick}
      onContextMenu={onContextMenu}
    >
      {!!tooltip && (
        <div className="HelmPlane__Node--tooltipAnchor">
          <KeepScale style={{ transformOrigin: '50% 100%' }}>
            <div
              className={classes([
                'HelmPlane__Node--tooltip',
                tooltipAlways && 'HelmPlane__Node--tooltipAlways',
              ])}
            >
              {tooltip}
            </div>
          </KeepScale>
        </div>
      )}
      {direction != null && (
        <div
          className="HelmPlane__Node--direction"
          style={{ transform: `rotate(${direction}deg)` }}
        >
          <svg viewBox="0 0 66 66">
            <polygon points="100,75 200,250 0,250" />
          </svg>
        </div>
      )}
      {inner}
    </div>
  );
}
