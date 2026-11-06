import { useState } from 'react';
import {
  Box,
  Button,
  Dropdown,
  LabeledList,
  NoticeBox,
  ProgressBar,
  Section,
  Stack,
  Tabs,
} from 'tgui-core/components';
import type { BooleanLike } from 'tgui-core/react';
import { useBackend } from '../backend';
import { Window } from '../layouts';
import {
  type PreviewData,
  ShipPreview,
  type UpgradeSlot,
} from './ShipUpgradeSelector';
import {
  type BillClass,
  HullPlan,
  PART_CLASSES,
  type PartClass,
  type SavedShip,
  type ShipSurvey,
  SlotCard,
} from './SavedShipCards';

type ShopTheme = {
  id: string;
  name: string;
  desc: string;
  is_default: BooleanLike;
  price: number;
  crew: number;
};

type ShopModule = {
  id: string;
  name: string;
  desc: string;
  slot: string;
  is_default: BooleanLike;
  price: number;
  themes: string[];
};

type ShopHull = {
  id: string;
  name: string;
  description: string;
  price: number;
  crew: number;
  themes: ShopTheme[];
  slots_by_theme: Record<string, string[]>;
  modules: ShopModule[];
  preview: PreviewData | null;
};

type Shop = {
  hull: string;
  theme: string | null;
  selections: Record<string, string>;
  lines: { label: string; amount: number }[];
  price: number;
  payers: {
    id: string;
    name: string;
    balance: number;
    available: BooleanLike;
  }[];
  payer: string;
  denial: string | null;
};

type Data = {
  outpost: string;
  working: BooleanLike;
  error: string | null;
  notice: string | null;
  rebuilds: {
    ref: string;
    name: string;
    status: string;
    progress: number;
  }[];
  catalog: ShopHull[];
  shop: Shop | null;
  saved_ships: {
    online: BooleanLike;
    parts: Record<PartClass, number> | null;
    slots: number;
    saves: SavedShip[];
    ships: DockedShip[];
  };
};

type DockedShip = ShipSurvey & {
  ref: string;
  name: string;
  class: string | null;
  denial: string | null;
};

const credits = (amount: number) => `${amount.toLocaleString()} cr`;

export const ShipCheckpoint = () => {
  const { data } = useBackend<Data>();
  const [tab, setTab] = useState('saved');
  const rebuilds = data.rebuilds || [];
  return (
    <Window width={720} height={860} title={`${data.outpost} Shipyard`}>
      <Window.Content scrollable>
        {!!data.error && <NoticeBox danger>{data.error}</NoticeBox>}
        {!!data.notice && <NoticeBox success>{data.notice}</NoticeBox>}
        {!!data.working && <NoticeBox>Processing...</NoticeBox>}
        {rebuilds.length > 0 && (
          <Section title="Construction">
            {rebuilds.map((rebuild) => (
              <Box key={rebuild.ref} mb={1}>
                <Box bold style={{ overflowWrap: 'anywhere' }}>
                  {rebuild.name}
                </Box>
                <Box color="label" mb={1}>
                  {rebuild.status}
                </Box>
                <ProgressBar value={rebuild.progress / 100}>
                  {rebuild.progress}%
                </ProgressBar>
              </Box>
            ))}
          </Section>
        )}
        <Tabs>
          <Tabs.Tab
            icon="anchor"
            selected={tab === 'saved'}
            onClick={() => setTab('saved')}
          >
            Saved ships
          </Tabs.Tab>
          <Tabs.Tab
            icon="ship"
            selected={tab === 'shop'}
            onClick={() => setTab('shop')}
          >
            New ship
          </Tabs.Tab>
        </Tabs>
        {tab === 'shop' && <ShopTab />}
        {tab === 'saved' && <SavedShipsTab />}
      </Window.Content>
    </Window>
  );
};

/** Why a save costs what it costs: one column per part class, with the machines behind it. */
const PriceBill = (props: {
  bill: BillClass[];
  parts: Record<PartClass, number> | null;
}) => (
  <div
    style={{
      display: 'grid',
      gridTemplateColumns: 'repeat(4, minmax(0, 1fr))',
      gap: '8px',
    }}
  >
    {PART_CLASSES.map(({ id, label, color }) => {
      const entry = props.bill.find((line) => line.class === id);
      const need = entry?.parts || 0;
      const held = props.parts ? props.parts[id] : null;
      const short = held !== null && need > held;
      return (
        <div
          key={id}
          style={{
            borderTop: `2px solid ${color}`,
            background: 'rgba(255,255,255,0.03)',
            padding: '6px 8px 8px',
            opacity: need ? 1 : 0.45,
          }}
        >
          <div style={{ display: 'flex', alignItems: 'baseline', gap: '5px' }}>
            <span
              style={{
                fontSize: '22px',
                fontWeight: 'bold',
                lineHeight: '1',
                color,
              }}
            >
              {need}
            </span>
            <span style={{ color: '#b9c6d0' }}>{label}</span>
          </div>
          {held !== null && !!need && (
            <div
              style={{
                fontSize: '11px',
                marginTop: '2px',
                color: short ? '#ff7b72' : '#7f8e9a',
                fontWeight: short ? 'bold' : 'normal',
              }}
            >
              you have {held}
            </div>
          )}
          <div style={{ marginTop: '6px' }}>
            {(entry?.items || []).map((item) => (
              <div
                key={item.name}
                style={{
                  display: 'flex',
                  gap: '6px',
                  lineHeight: '1.3',
                  marginTop: '3px',
                }}
              >
                <span style={{ flex: 1, minWidth: 0, color: '#d7e0e7' }}>
                  {item.name}
                  {!!item.count && item.count > 1 && (
                    <span style={{ color: '#7f8e9a' }}> ×{item.count}</span>
                  )}
                </span>
                <span style={{ color, fontWeight: 'bold' }}>{item.parts}</span>
              </div>
            ))}
          </div>
        </div>
      );
    })}
  </div>
);

/** The ship in the bay and what it would cost to save. */
const DockedPanel = (props: {
  ship: DockedShip;
  parts: Record<PartClass, number> | null;
}) => {
  const { ship, parts } = props;
  return (
    <div
      style={{
        border: '1px solid rgba(134,197,228,0.28)',
        borderRadius: '3px',
        overflow: 'hidden',
        background: 'linear-gradient(180deg, #16222d 0%, #111a23 100%)',
      }}
    >
      <div style={{ display: 'flex' }}>
        <div style={{ flex: '0 0 200px' }}>
          <HullPlan plan={ship.plan} height={92} />
        </div>
        <div style={{ flex: 1, minWidth: 0, padding: '8px 12px' }}>
          <div
            style={{
              fontSize: '16px',
              fontWeight: 'bold',
              color: '#eef4f8',
              overflowWrap: 'anywhere',
            }}
          >
            {ship.name}
          </div>
          {!!ship.class && <Box color="label">{ship.class}</Box>}
          <Box color="label" mt={0.5}>
            {(ship.mass || 0).toLocaleString()} t · crew {ship.crew || 0}
          </Box>
        </div>
        <div style={{ padding: '8px 14px', textAlign: 'right' }}>
          <div
            style={{
              fontSize: '30px',
              fontWeight: 'bold',
              lineHeight: '1',
              color: '#eef4f8',
            }}
          >
            {ship.total || 0}
          </div>
          <Box color="label">parts to save</Box>
        </div>
      </div>
      <div style={{ padding: '8px' }}>
        <PriceBill bill={ship.bill || []} parts={parts} />
      </div>
    </div>
  );
};

/** Why this captain can't afford the save, or null. */
const shortOfParts = (
  bill: BillClass[],
  parts: Record<PartClass, number> | null,
) => {
  if (!parts) {
    return null;
  }
  const missing = bill
    .filter((entry) => entry.parts > parts[entry.class])
    .map((entry) => `${entry.parts - parts[entry.class]} ${entry.class}`);
  return missing.length ? `Short ${missing.join(', ')}.` : null;
};

const SavedShipsTab = () => {
  const { data, act } = useBackend<Data>();
  const { online, parts, slots, saves, ships } = data.saved_ships;
  const [shipRef, setShipRef] = useState<string | null>(null);
  if (!online) {
    return (
      <Section title="Saved ships">
        <Box color="label">Shipyard records are offline.</Box>
      </Section>
    );
  }
  const ship = ships.find((entry) => entry.ref === shipRef) || ships[0];
  const saveDenial = !ship
    ? 'Dock a ship you command.'
    : ship.denial || shortOfParts(ship.bill || [], parts);
  return (
    <>
      <Section
        title="In the bay"
        buttons={
          ships.length > 1 ? (
            <Stack>
              {ships.map((entry) => (
                <Stack.Item key={entry.ref}>
                  <Button
                    selected={entry === ship}
                    onClick={() => setShipRef(entry.ref)}
                  >
                    {entry.name}
                  </Button>
                </Stack.Item>
              ))}
            </Stack>
          ) : undefined
        }
      >
        {ship ? (
          <DockedPanel ship={ship} parts={parts} />
        ) : (
          <Box color="label">Dock a ship you command.</Box>
        )}
      </Section>
      <Section title="Saved ships">
        <div
          style={{
            display: 'grid',
            gridTemplateColumns: 'repeat(3, minmax(0, 1fr))',
            gap: '10px',
          }}
        >
          {Array.from({ length: slots }, (_, index) => {
            const slot = index + 1;
            const save = saves.find((entry) => entry.slot === slot);
            return (
              <SlotCard
                key={slot}
                slot={slot}
                save={save}
                ghostPlan={ship?.plan}
                footer={
                  <div
                    style={{
                      display: 'grid',
                      gridTemplateColumns: save ? '1fr 1fr' : '1fr',
                      gap: '4px',
                    }}
                  >
                    {!!save && (
                      <Button
                        fluid
                        color="good"
                        textAlign="center"
                        style={{ margin: 0 }}
                        disabled={!!data.working || !!save.denial}
                        tooltip={save.denial}
                        onClick={() =>
                          act('ship_save_retrieve', { slot: save.slot })
                        }
                      >
                        Build here
                      </Button>
                    )}
                    <Button
                      fluid
                      color={save ? 'orange' : undefined}
                      textAlign="center"
                      style={{ margin: 0 }}
                      disabled={
                        !!data.working || !!saveDenial || !!save?.locked
                      }
                      tooltip={
                        saveDenial ||
                        (save?.locked ? 'Already under way.' : undefined)
                      }
                      onClick={() =>
                        act('ship_save_store', { ref: ship?.ref, slot })
                      }
                    >
                      {save ? 'Overwrite' : 'Save'}
                    </Button>
                  </div>
                }
              />
            );
          })}
        </div>
      </Section>
    </>
  );
};

/** Matches is_module_available_for_theme(): themeless hulls take only themeless modules. */
const fitsTheme = (module: ShopModule, theme: string) =>
  theme ? module.themes.includes(theme) : module.themes.length === 0;

const slotName = (key: string) => {
  const spaced = key.replace(/_/g, ' ');
  return spaced.charAt(0).toUpperCase() + spaced.slice(1);
};

const ShopTab = () => {
  const { data, act } = useBackend<Data>();
  const shop = data.shop;
  const catalog = data.catalog || [];
  const hull = catalog.find((entry) => entry.id === shop?.hull);
  if (!shop || !hull) {
    return (
      <Section title="New ship">
        <Box color="label">No ships for sale.</Box>
      </Section>
    );
  }
  const themeKey = shop.theme || '';
  const theme = hull.themes.find((entry) => entry.id === shop.theme);
  const slotKeys = hull.slots_by_theme[themeKey] || [];
  const slots: UpgradeSlot[] = slotKeys.map((key) => ({
    key,
    display_name: slotName(key),
    modules: hull.modules
      .filter((module) => module.slot === key && fitsTheme(module, themeKey))
      .map((module) => ({
        id: module.id,
        name: module.name,
        desc: module.desc,
        part_cost: {},
        is_default: !!module.is_default,
      })),
  }));
  const payer = shop.payers.find((entry) => entry.id === shop.payer);
  return (
    <>
      <Section title="Hull">
        <Dropdown
          width="100%"
          selected={hull.id}
          displayText={`${hull.name} (${credits(hull.price)})`}
          options={catalog.map((entry) => ({
            value: entry.id,
            displayText: `${entry.name} (${credits(entry.price)})`,
          }))}
          onSelected={(value) => act('shop_hull', { id: value })}
        />
        <Box color="label" mt={1}>
          {hull.description}
        </Box>
        <Box color="label" mt={1}>
          Crew: {theme ? theme.crew : hull.crew}
        </Box>
      </Section>
      {hull.themes.length > 0 && (
        <Section title="Theme">
          <Stack wrap>
            {hull.themes.map((entry) => (
              <Stack.Item key={entry.id} mb={0.5}>
                <Button
                  selected={entry.id === shop.theme}
                  tooltip={entry.desc}
                  onClick={() => act('shop_theme', { id: entry.id })}
                >
                  {entry.name}
                  {entry.price > 0 ? ` (+${credits(entry.price)})` : ''}
                </Button>
              </Stack.Item>
            ))}
          </Stack>
          {!!theme && (
            <Box color="label" mt={1}>
              {theme.desc}
            </Box>
          )}
        </Section>
      )}
      {!!hull.preview && (
        <Section title="Layout">
          <Box height="240px">
            <ShipPreview
              preview={hull.preview}
              themeKey={themeKey}
              slots={slots}
              selectedUpgrades={shop.selections}
              hoverModule={null}
            />
          </Box>
        </Section>
      )}
      {slots.length > 0 && (
        <Section title="Modules">
          <LabeledList>
            {slots.map((slot) => {
              const chosen = hull.modules.find(
                (module) => module.id === shop.selections[slot.key],
              );
              const options = hull.modules.filter(
                (module) =>
                  module.slot === slot.key && fitsTheme(module, themeKey),
              );
              return (
                <LabeledList.Item key={slot.key} label={slot.display_name}>
                  <Dropdown
                    width="100%"
                    selected={chosen?.id || ''}
                    displayText={
                      chosen
                        ? `${chosen.name}${chosen.price > 0 ? ` (+${credits(chosen.price)})` : ''}`
                        : 'Default'
                    }
                    options={options.map((module) => ({
                      value: module.id,
                      displayText: `${module.name}${module.price > 0 ? ` (+${credits(module.price)})` : ''}`,
                    }))}
                    onSelected={(value) =>
                      act('shop_module', { slot: slot.key, id: value })
                    }
                  />
                  {!!chosen && (
                    <Box color="label" mt={0.5}>
                      {chosen.desc}
                    </Box>
                  )}
                </LabeledList.Item>
              );
            })}
          </LabeledList>
        </Section>
      )}
      <Section title="Price">
        <LabeledList>
          {shop.lines.map((line) => (
            <LabeledList.Item key={line.label} label={line.label}>
              {credits(line.amount)}
            </LabeledList.Item>
          ))}
          <LabeledList.Item label="Total">
            <Box bold>{credits(shop.price)}</Box>
          </LabeledList.Item>
          <LabeledList.Item label="Pay from">
            <Dropdown
              width="100%"
              selected={shop.payer}
              displayText={
                payer
                  ? `${payer.name} (${payer.available ? credits(payer.balance) : 'no ID'})`
                  : 'Choose'
              }
              options={shop.payers.map((entry) => ({
                value: entry.id,
                displayText: `${entry.name} (${entry.available ? credits(entry.balance) : 'no ID'})`,
              }))}
              onSelected={(value) => act('shop_payer', { id: value })}
            />
          </LabeledList.Item>
        </LabeledList>
        <Box color="label" mt={1}>
          Spent when construction begins. You take command at handover.
        </Box>
        {!!shop.denial && (
          <Box color="bad" mt={1}>
            {shop.denial}
          </Box>
        )}
        <Button
          mt={1}
          icon="ship"
          color="good"
          disabled={!!data.working || !!shop.denial}
          onClick={() => act('shop_buy')}
        >
          Order ship ({credits(shop.price)})
        </Button>
      </Section>
    </>
  );
};
