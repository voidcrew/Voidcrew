/**
 * Chart glyphs.
 *
 * Contacts are drawn as monoline SVG silhouettes rather than world-DMI sprites:
 * one shape per family, one more per variant where the difference changes what a
 * crew does, all at a single weight inside a ~6-unit box. Colour carries family
 * and terrain (see the palettes below), so glyphs stay legible at any zoom and
 * the chart reads as one instrument rather than a sticker sheet.
 */
import type { Contact, ContactKind } from './data';

/** Family colour, used where the helm knows the family but nothing finer. */
export const KIND_COLOR: Record<ContactKind, string> = {
  planet: '#8fa7ad',
  ruin: '#9d8fd0',
  outpost: '#59b871',
  ship: '#d6e2e4',
  distress: '#ff4d6d',
  nebula: '#c479c0',
  hazard: '#cf4a38',
  bounty: '#e2564a',
  mission: '#f2a341',
  rumor: '#ffc94d',
  event: '#74c8dd',
  marker: '#9fb2b7',
};

/** Planet terrain, keyed on chart_variant in planets.dm. */
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

/** Storm families. Each is flown around differently, so none share a colour. */
const HAZARD_COLOR: Record<string, string> = {
  rock: '#c86b3c',
  ion: '#a071e0',
  electrical: '#e6c53f',
};

/** Gas IDs from events.dm, with distinct tints readable against the dark chart. */
const NEBULA_COLOR: Record<string, string> = {
  plasma: '#e695c4',
  n2: '#e6cc66',
  water_vapor: '#c5dce8',
  miasma: '#a6ad63',
  tritium: '#67df73',
  hypernoblium: '#4bc9c5',
  pluoxium: '#9d8aeb',
  nitrium: '#df8855',
};

/** Per-family colour tables, consulted before the family colour above. */
const VARIANT_COLOR: Partial<Record<ContactKind, Record<string, string>>> = {
  planet: PLANET_COLOR,
  hazard: HAZARD_COLOR,
  nebula: NEBULA_COLOR,
  ruin: { encrypted: '#ffc94d' },
};

/**
 * What colour a mark is drawn in. Hostility and anonymity outrank everything
 * else: an unscanned hull must not borrow the friendly white or the hostile red.
 */
export const contactColour = (contact: Contact) => {
  if (contact.kind === 'ship' && !contact.identified) return '#8c9ea2';
  if (contact.hostile) return '#cf4a38';
  if (contact.sos) return KIND_COLOR.distress;
  const variants = VARIANT_COLOR[contact.kind];
  const refined = contact.variant ? variants?.[contact.variant] : undefined;
  return refined ?? KIND_COLOR[contact.kind] ?? KIND_COLOR.marker;
};

/** Storm glyphs scale with severity, so a majour field reads as worse. */
const SEVERITY_SCALE: Record<number, number> = { 1: 0.82, 2: 1, 3: 1.2 };

const SVG_ORIGIN = { transformOrigin: '0 0' } as const;

/**
 * An unscanned vessel: a dashed ring with no heading and no shape, nothing like
 * the solid arrowhead an identified ship gets.
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
 * One silhouette per family, and within the families where it matters, per
 * variant. Monoline at a single weight, inside a ~6-unit box.
 */
export const ContactGlyph = (props: {
  kind: ContactKind;
  variant?: string | null;
  severity?: number;
  colour: string;
}) => {
  const { kind, variant, severity, colour } = props;
  const line = { fill: 'none', stroke: colour, strokeWidth: 1.6 } as const;

  switch (kind) {
    case 'planet':
      if (variant === 'asteroid') {
        return (
          <path
            d="M-4.8,-0.6 L-2.4,-4.6 L1,-3.4 L2.2,-5 L4.8,-1.4 L2.6,0.4 L4.2,2.8 L0.4,4.8 L-3.4,3 Z"
            {...line}
          />
        );
      }
      if (variant === 'signal') {
        return (
          <>
            <circle cx={-3.2} r={1.5} fill={colour} />
            <path d="M-1.6,-2.8 A3.2 3.2 0 0 1 -1.6,2.8" {...line} strokeWidth={1.4} />
            <path d="M0,-4.6 A5.6 5.6 0 0 1 0,4.6" {...line} strokeWidth={1.4} />
          </>
        );
      }
      if (variant === 'wreck') {
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
      return (
        <>
          <path d="M0,-5 L4.5,2.5 L-4.5,2.5 Z" {...line} strokeWidth={1.7} />
          {!!variant && variant !== 'encrypted' && (
            <circle cy={0.4} r={1.4} fill={colour} />
          )}
        </>
      );

    case 'outpost':
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

    case 'distress':
      return (
        <>
          <circle r={1.7} fill={colour} />
          <path
            d="M-2.5,-2.5 A3.6 3.6 0 0 0 -2.5,2.5 M2.5,-2.5 A3.6 3.6 0 0 1 2.5,2.5"
            {...line}
            strokeWidth={1.4}
          />
          <path
            d="M-4.4,-4.4 A6.3 6.3 0 0 0 -4.4,4.4 M4.4,-4.4 A6.3 6.3 0 0 1 4.4,4.4"
            {...line}
            strokeWidth={1.3}
          />
        </>
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
      return <path d="M0,-5.2 L5.2,0 L0,5.2 L-5.2,0 Z" {...line} />;

    case 'event':
      return (
        <>
          <path d="M0,-5.4 L4.7,-2.7 L4.7,2.7 L0,5.4 L-4.7,2.7 L-4.7,-2.7 Z" {...line} />
          <circle r={1.4} fill={colour} />
        </>
      );

    default:
      return (
        <path
          d="M0,-6 L2,-2 L6,-2 L3,1 L4,5 L0,3 L-4,5 L-3,1 L-6,-2 L-2,-2 Z"
          {...line}
          strokeWidth={1.5}
        />
      );
  }
};

/** The three storms, which a navigator most needs to tell apart at a glance. */
const HazardGlyph = (props: {
  variant?: string | null;
  colour: string;
  line: { fill: 'none'; stroke: string; strokeWidth: number };
}) => {
  const { variant, colour, line } = props;
  switch (variant) {
    case 'rock':
      return (
        <>
          <path d="M-4.8,-2.4 L-2.2,-4.2 L-0.8,-1.8 L-3.2,-0.4 Z" fill={colour} />
          <path d="M1.4,-4.4 L4.6,-3.2 L4,-0.4 L1,-1.4 Z" fill={colour} />
          <path d="M-2.6,1.4 L0.6,0.8 L1.4,3.8 L-1.6,4.4 Z" fill={colour} />
          <circle cx={3.6} cy={3.2} r={1.2} fill={colour} />
        </>
      );
    case 'ion':
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
      return (
        <path
          d="M0,-6 L1.7,-1.7 L6,0 L1.7,1.7 L0,6 L-1.7,1.7 L-6,0 L-1.7,-1.7 Z"
          {...line}
        />
      );
  }
};

const glyphFor = (contact: Contact) => {
  const colour = contactColour(contact);
  const unknown = contact.kind === 'ship' && !contact.identified;
  return unknown ? (
    <UnknownGlyph colour={colour} />
  ) : (
    <ContactGlyph
      kind={contact.kind}
      variant={contact.variant}
      severity={contact.severity}
      colour={colour}
    />
  );
};

/** A contact's chart glyph at row size, so the register and the map agree. */
export const ContactBadge = (props: { contact: Contact }) => (
  <svg viewBox="-8 -8 16 16" width="16px" height="16px" aria-hidden="true">
    {glyphFor(props.contact)}
  </svg>
);

/** A contact's mark on the chart, sized in map-space pixels. */
export const ContactMark = (props: {
  contact: Contact;
  size?: number;
  direction?: number;
}) => {
  const { contact, size = 34, direction = 0 } = props;
  return (
    <svg
      viewBox="-8 -8 16 16"
      width={`${size}px`}
      height={`${size}px`}
      style={{ overflow: 'visible' }}
      aria-hidden="true"
    >
      <g transform={direction ? `rotate(${direction})` : undefined}>
        {glyphFor(contact)}
      </g>
    </svg>
  );
};

/** The crew's own hull: a solid arrowhead, optionally facing its course. */
export const ShipMark = (props: { size?: number; direction?: number }) => {
  const { size = 44, direction = 0 } = props;
  return (
    <svg
      viewBox="-8 -8 16 16"
      width={`${size}px`}
      height={`${size}px`}
      // display:block drops the inline baseline gap that otherwise sat the mark
      // a few pixels high of its tile centre in the chart.
      style={{ display: 'block', overflow: 'visible' }}
      aria-hidden="true"
    >
      <g transform={direction ? `rotate(${direction})` : undefined}>
        <ContactGlyph kind="ship" colour="#e0a72c" />
      </g>
    </svg>
  );
};

/** A hail pulse: the event hexagon in a given colour. */
export const PulseMark = (props: { colour: string; size?: number }) => {
  const { colour, size = 22 } = props;
  return (
    <svg viewBox="-8 -8 16 16" width={`${size}px`} height={`${size}px`} aria-hidden="true">
      <ContactGlyph kind="event" colour={colour} />
    </svg>
  );
};

/**
 * The autopilot's destination pip: a red reticle that spins, so a course that
 * is being flown reads differently at a glance from one that is only projected.
 */
export const TargetReticle = (props: { size?: number }) => {
  const { size = 14 } = props;
  const colour = '#cf4a38';
  return (
    <div
      className="Helm__reticle"
      style={{ width: `${size}px`, height: `${size}px` }}
    >
      <svg viewBox="-8 -8 16 16" width="100%" height="100%" aria-hidden="true">
        <circle
          r={5.6}
          fill="none"
          stroke={colour}
          strokeWidth={1.2}
          strokeDasharray="2.4 1.6"
        />
        <circle r={2.4} fill="none" stroke={colour} strokeWidth={1.1} />
        <path
          d="M0,-7.6 V-4.6 M0,4.6 V7.6 M-7.6,0 H-4.6 M4.6,0 H7.6"
          fill="none"
          stroke={colour}
          strokeWidth={1.5}
        />
        <circle r={0.9} fill={colour} />
      </svg>
    </div>
  );
};
