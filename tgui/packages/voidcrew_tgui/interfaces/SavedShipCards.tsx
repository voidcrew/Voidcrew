import type { CSSProperties, ReactNode } from 'react';
import { useMemo } from 'react';
import { Box } from 'tgui-core/components';
import type { BooleanLike } from 'tgui-core/react';

export type PartClass = 'combat' | 'science' | 'trade' | 'misc';

export type BillLine = {
  name: string;
  count: number | null;
  parts: number;
};

export type BillClass = {
  class: PartClass;
  parts: number;
  items: BillLine[];
};

/** What a hull holds. A save written before this existed has none of it. */
export type ShipSurvey = {
  mass?: number;
  crew?: number;
  plan?: string | null;
  bill?: BillClass[];
  total?: number;
};

export type SavedShip = ShipSurvey & {
  slot: number;
  name: string;
  class: string | null;
  denial: string | null;
  locked?: BooleanLike;
};

/** The colours of the physical parts. */
export const PART_CLASSES: {
  id: PartClass;
  label: string;
  color: string;
}[] = [
  { id: 'combat', label: 'combat', color: '#e0605a' },
  { id: 'science', label: 'science', color: '#5aa7e8' },
  { id: 'trade', label: 'trade', color: '#e0b64a' },
  { id: 'misc', label: 'misc', color: '#a9b4bd' },
];

const partColor = (id: PartClass) =>
  PART_CLASSES.find((entry) => entry.id === id)?.color;

const PLAN_LAYERS: { char: string; color: string }[] = [
  { char: 'o', color: '#274a60' },
  { char: 'g', color: '#4f8fb0' },
  { char: '#', color: '#86c5e4' },
  { char: 'e', color: '#d98f4e' },
  { char: 't', color: partColor('trade')! },
  { char: 's', color: partColor('science')! },
  { char: 'w', color: partColor('combat')! },
];

/** Rows of runs from ship_save_survey(): "5.3#2o/..." is five empty, three wall, two floor. */
const readPlan = (plan: string) => {
  const paths: Record<string, string> = {};
  const rows = plan.split('/');
  let width = 0;
  rows.forEach((row, y) => {
    let x = 0;
    for (const [, count, char] of row.matchAll(/(\d*)(\D)/g)) {
      const run = count ? Number(count) : 1;
      if (char !== '.') {
        paths[char] = `${paths[char] || ''}M${x} ${y}h${run}v1h-${run}z`;
      }
      x += run;
    }
    width = Math.max(width, x);
  });
  return { paths, width, height: rows.length };
};

const GRID: CSSProperties = {
  backgroundColor: '#0a1520',
  backgroundImage:
    'linear-gradient(rgba(134,197,228,0.07) 1px, transparent 1px), linear-gradient(90deg, rgba(134,197,228,0.07) 1px, transparent 1px)',
  backgroundSize: '12px 12px',
  backgroundPosition: 'center',
};

/** The hull from above, as the yard's drawing of it. */
export const HullPlan = (props: { plan?: string | null; height: number }) => {
  const { plan, height } = props;
  const drawing = useMemo(() => (plan ? readPlan(plan) : null), [plan]);
  return (
    <div
      style={{
        ...GRID,
        height: `${height}px`,
        padding: '8px',
        display: 'flex',
        alignItems: 'center',
        justifyContent: 'center',
      }}
    >
      {!!drawing && (
        <svg
          viewBox={`0 0 ${drawing.width} ${drawing.height}`}
          preserveAspectRatio="xMidYMid meet"
          shapeRendering="crispEdges"
          style={{
            width: '100%',
            height: '100%',
            filter: 'drop-shadow(0 0 4px rgba(134,197,228,0.35))',
          }}
        >
          {PLAN_LAYERS.map(
            (layer) =>
              !!drawing.paths[layer.char] && (
                <path
                  key={layer.char}
                  d={drawing.paths[layer.char]}
                  fill={layer.color}
                />
              ),
          )}
        </svg>
      )}
    </div>
  );
};

const SMALL_CAPS: CSSProperties = {
  fontSize: '10px',
  letterSpacing: '0.12em',
  textTransform: 'uppercase',
};

const Stat = (props: { label: string; value: string }) => (
  <div style={{ flex: '1 1 0', minWidth: 0 }}>
    <div style={{ ...SMALL_CAPS, color: '#7f8e9a' }}>{props.label}</div>
    <div style={{ fontSize: '14px', fontWeight: 'bold', color: '#dbe6ee' }}>
      {props.value}
    </div>
  </div>
);

const FitLine = (props: {
  color?: string;
  name: string;
  count?: number | null;
}) => (
  <div
    style={{
      display: 'flex',
      alignItems: 'baseline',
      gap: '6px',
      lineHeight: '1.45',
    }}
  >
    <span
      style={{
        flex: '0 0 auto',
        width: '6px',
        height: '6px',
        background: props.color,
        transform: 'translateY(-1px)',
      }}
    />
    <span style={{ flex: 1, minWidth: 0 }}>{props.name}</span>
    {!!props.count && props.count > 1 && (
      <span style={{ color: '#7f8e9a' }}>×{props.count}</span>
    )}
  </div>
);

const machineCount = (bill: BillClass[], id: PartClass) =>
  (bill.find((line) => line.class === id)?.items || []).reduce(
    (total, item) => total + (item.count || 1),
    0,
  );

/** Weapons by name, then how much lab and cargo gear it carries. */
const Fit = (props: { bill: BillClass[] }) => {
  const { bill } = props;
  const weapons = bill.find((line) => line.class === 'combat')?.items || [];
  const lab = machineCount(bill, 'science');
  const cargo = machineCount(bill, 'trade');
  return (
    <>
      {weapons.length === 0 && <Box color="label">Unarmed</Box>}
      {weapons.map((item) => (
        <FitLine
          key={item.name}
          color={partColor('combat')}
          name={item.name}
          count={item.count}
        />
      ))}
      {lab > 0 && (
        <FitLine color={partColor('science')} name="Lab machines" count={lab} />
      )}
      {cargo > 0 && (
        <FitLine color={partColor('trade')} name="Cargo machines" count={cargo} />
      )}
    </>
  );
};

const FRAME: CSSProperties = {
  border: '1px solid rgba(134,197,228,0.28)',
  borderRadius: '3px',
  overflow: 'hidden',
  flex: 1,
  display: 'flex',
  flexDirection: 'column',
  background: 'linear-gradient(180deg, #16222d 0%, #111a23 100%)',
};

const SLOT_LABEL: CSSProperties = {
  ...SMALL_CAPS,
  padding: '5px 8px',
  color: '#86c5e4',
  borderBottom: '1px solid rgba(134,197,228,0.18)',
};

/**
 * One tall ship card. Buttons go in `footer`, under the card. An empty slot can show
 * `ghostPlan`, the ship that would go in it.
 */
export const SlotCard = (props: {
  slot: number;
  save?: SavedShip;
  ghostPlan?: string | null;
  planHeight?: number;
  footer?: ReactNode;
}) => {
  const { slot, save, ghostPlan, planHeight = 96, footer } = props;
  return (
    <div style={{ display: 'flex', flexDirection: 'column', minWidth: 0 }}>
      {save ? (
        <div style={FRAME}>
          <div style={SLOT_LABEL}>Slot {slot}</div>
          <HullPlan plan={save.plan} height={planHeight} />
          <div style={{ padding: '8px', flex: 1 }}>
            <div
              style={{
                fontSize: '13px',
                fontWeight: 'bold',
                color: '#eef4f8',
                overflowWrap: 'anywhere',
                lineHeight: '1.25',
              }}
            >
              {save.name}
            </div>
            {!!save.class && (
              <div style={{ color: '#8fa0ad', marginTop: '2px' }}>
                {save.class}
              </div>
            )}
            {save.mass !== undefined && (
              <div style={{ display: 'flex', gap: '8px', margin: '8px 0' }}>
                <Stat label="Mass" value={`${save.mass.toLocaleString()} t`} />
                <Stat label="Crew" value={`${save.crew ?? 0}`} />
              </div>
            )}
            {!!save.bill && <Fit bill={save.bill} />}
          </div>
        </div>
      ) : (
        <div
          style={{ ...FRAME, border: '1px dashed rgba(134,197,228,0.3)' }}
        >
          <div style={SLOT_LABEL}>Slot {slot}</div>
          <div style={{ opacity: 0.22 }}>
            <HullPlan plan={ghostPlan} height={planHeight} />
          </div>
          <div
            style={{
              flex: 1,
              display: 'flex',
              alignItems: 'center',
              justifyContent: 'center',
              minHeight: '70px',
              color: '#7f8e9a',
            }}
          >
            Empty
          </div>
        </div>
      )}
      {!!footer && <div style={{ marginTop: '6px' }}>{footer}</div>}
    </div>
  );
};
