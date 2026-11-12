/**
 * Owner shop register: the buyer window (outpost_shop.dm, outpost_shop_stock.dm).
 *
 * `price` is what this viewer pays per unit (0 for staff who take stock free);
 * `buy` echoes it so a price change while the window is open is refused.
 *
 * A leased floor's till (trade_floors/floor_fittings.dm) hosts the same window
 * and sends its staff three more keys: `can_toggle`, `shop_open` and `sales`.
 * With them the window gains the open/closed button and the sales list.
 */
import { useState } from 'react';
import {
  Box,
  Button,
  DmIcon,
  Icon,
  Input,
  NoticeBox,
  NumberInput,
  Section,
  Stack,
  Tabs,
} from 'tgui-core/components';
import type { BooleanLike } from 'tgui-core/react';

import { useBackend } from '../backend';
import { Window } from '../layouts';

type Category = { id: string; name: string };

type Listing = {
  id: string;
  name: string;
  category: string;
  icon: string;
  icon_state: string;
  price: number;
  per_unit: BooleanLike;
  available: number;
  max_per_buy: number;
};

type Sale = {
  when: string;
  buyer: string;
  name: string;
  qty: number;
  total: number;
  taken: BooleanLike;
  where?: string | null;
  npc?: BooleanLike;
};

type Data = {
  shop_name: string;
  open: BooleanLike;
  closed_reason: string | null;
  free_take: BooleanLike;
  account_credits: number | null;
  confirm_total: number;
  categories: Category[];
  listings: Listing[];
  can_toggle?: BooleanLike;
  shop_open?: BooleanLike;
  sales?: Sale[] | null;
};

const ALL = '__all__';

/** One line, cut with an ellipsis: every name here is somebody's own text. */
const CLIP = {
  overflow: 'hidden',
  textOverflow: 'ellipsis',
  whiteSpace: 'nowrap',
} as const;

const PLACES = { till: 'Till', shelf: 'Shelf' };

export const OutpostShop = (props) => {
  const { act, data } = useBackend<Data>();
  const {
    shop_name,
    open,
    closed_reason,
    can_toggle,
    shop_open,
    sales,
    categories = [],
    listings = [],
  } = data;
  const [category, setCategory] = useState(ALL);
  const [search, setSearch] = useState('');
  const [tab, setTab] = useState<'shop' | 'sales'>('shop');

  const shownTab = can_toggle ? tab : 'shop';
  const shownCategory =
    category === ALL || categories.some((cat) => cat.id === category)
      ? category
      : ALL;
  const needle = search.trim().toLowerCase();
  const visible = listings.filter(
    (listing) =>
      (shownCategory === ALL || listing.category === shownCategory) &&
      (!needle || listing.name.toLowerCase().includes(needle)),
  );

  return (
    <Window width={560} height={520} title={shop_name}>
      <Window.Content>
        <Stack fill vertical>
          {can_toggle ? (
            <Stack.Item>
              <Stack align="center">
                <Stack.Item grow>
                  <Tabs>
                    <Tabs.Tab
                      icon="cart-shopping"
                      selected={shownTab === 'shop'}
                      onClick={() => setTab('shop')}
                    >
                      Shop
                    </Tabs.Tab>
                    <Tabs.Tab
                      icon="receipt"
                      selected={shownTab === 'sales'}
                      onClick={() => setTab('sales')}
                    >
                      Sales
                    </Tabs.Tab>
                  </Tabs>
                </Stack.Item>
                <Stack.Item>
                  <Button
                    icon={shop_open ? 'door-open' : 'door-closed'}
                    color={shop_open ? 'good' : 'bad'}
                    onClick={() => act('toggle_open')}
                  >
                    {shop_open ? 'Open' : 'Closed'}
                  </Button>
                </Stack.Item>
              </Stack>
            </Stack.Item>
          ) : null}
          <Stack.Item grow>
            {shownTab === 'sales' ? (
              <SalesList sales={sales || []} />
            ) : open ? (
              <Stack fill>
                {categories.length > 1 ? (
                  <Stack.Item width="150px">
                    <Section fill scrollable>
                      <Tabs vertical>
                        <Tabs.Tab
                          selected={shownCategory === ALL}
                          onClick={() => setCategory(ALL)}
                        >
                          All
                        </Tabs.Tab>
                        {categories.map((cat) => (
                          <Tabs.Tab
                            key={cat.id}
                            selected={shownCategory === cat.id}
                            onClick={() => setCategory(cat.id)}
                          >
                            <div
                              style={{ ...CLIP, maxWidth: '108px' }}
                              title={cat.name}
                            >
                              {cat.name}
                            </div>
                          </Tabs.Tab>
                        ))}
                      </Tabs>
                    </Section>
                  </Stack.Item>
                ) : null}
                <Stack.Item grow basis={0} style={{ minWidth: 0 }}>
                  <Section
                    fill
                    scrollable
                    buttons={
                      <Input
                        placeholder="Search"
                        value={search}
                        onChange={setSearch}
                      />
                    }
                  >
                    {visible.length === 0 ? (
                      <Box color="label">Nothing for sale.</Box>
                    ) : null}
                    {visible.map((listing) => (
                      <BuyRow key={listing.id} listing={listing} />
                    ))}
                  </Section>
                </Stack.Item>
              </Stack>
            ) : (
              <NoticeBox>{closed_reason || 'Closed.'}</NoticeBox>
            )}
          </Stack.Item>
        </Stack>
      </Window.Content>
    </Window>
  );
};

const BuyRow = (props: { listing: Listing }) => {
  const { act, data } = useBackend<Data>();
  const { listing } = props;
  const { free_take, account_credits, confirm_total, open } = data;
  const limit = Math.max(1, Math.min(listing.max_per_buy, listing.available));
  const [quantity, setQuantity] = useState(1);
  const [confirming, setConfirming] = useState(false);
  const amount = Math.min(Math.max(1, quantity), limit);
  const total = listing.price * amount;
  const soldOut = listing.available < 1;
  const noAccount = !free_take && account_credits === null;
  const cantAfford =
    !free_take && (account_credits === null || account_credits < total);
  const needsConfirm = total >= confirm_total;

  const buy = () => {
    if (needsConfirm && !confirming) {
      setConfirming(true);
      return;
    }
    setConfirming(false);
    act('buy', { id: listing.id, price: listing.price, quantity: amount });
  };

  return (
    <Box
      mb={0.5}
      p={0.5}
      style={{ background: 'rgba(255, 255, 255, 0.04)', borderRadius: '2px' }}
    >
      <Stack align="center" wrap>
        <Stack.Item>
          <DmIcon
            icon={listing.icon}
            icon_state={listing.icon_state}
            width="32px"
            height="32px"
            fallback={<Icon name="box" size={1.5} />}
          />
        </Stack.Item>
        <Stack.Item grow basis="120px" style={{ minWidth: '100px' }}>
          <Box bold style={CLIP} title={listing.name}>
            {listing.name}
          </Box>
          <Box color="label" style={CLIP}>
            {soldOut
              ? 'Sold out'
              : free_take
                ? null
                : `${listing.price} cr${listing.per_unit ? ' each' : ''}`}
          </Box>
        </Stack.Item>
        {/* In a narrow window the buttons drop to a line of their own */}
        <Stack.Item ml="auto">
          <Stack align="center">
            <Stack.Item>
              <Button
                icon="magnifying-glass"
                tooltip="Inspect"
                onClick={() => act('inspect', { id: listing.id })}
              />
            </Stack.Item>
            <Stack.Item>
              <NumberInput
                value={amount}
                minValue={1}
                maxValue={limit}
                step={1}
                width="45px"
                disabled={soldOut}
                onChange={(value) => {
                  setQuantity(Math.round(value));
                  setConfirming(false);
                }}
              />
            </Stack.Item>
            <Stack.Item width="120px">
              <Button
                fluid
                ellipsis
                icon={free_take ? 'hand-holding' : 'cart-shopping'}
                color={confirming ? 'caution' : undefined}
                disabled={!open || soldOut || cantAfford}
                tooltip={
                  noAccount
                    ? 'No account.'
                    : cantAfford
                      ? 'Not enough credits.'
                      : undefined
                }
                onClick={buy}
              >
                {free_take
                  ? 'Take'
                  : confirming
                    ? `${total} cr?`
                    : `${total} cr`}
              </Button>
            </Stack.Item>
          </Stack>
        </Stack.Item>
      </Stack>
    </Box>
  );
};

const SalesList = (props: { sales: Sale[] }) => {
  const { sales } = props;
  return (
    <Section fill scrollable>
      {sales.length === 0 ? <NoticeBox>No sales yet.</NoticeBox> : null}
      {sales.map((sale, index) => (
        <Stack key={index} mb={0.5} align="center">
          <Stack.Item width="42px" color="label">
            {sale.when}
          </Stack.Item>
          <Stack.Item grow basis={0} style={{ minWidth: 0 }}>
            <div
              style={CLIP}
              title={`${sale.buyer}: ${sale.qty}x ${sale.name}`}
            >
              {sale.buyer}: {sale.qty}x {sale.name}
            </div>
          </Stack.Item>
          <Stack.Item width="96px" color="label" style={CLIP}>
            {PLACES[sale.where || ''] || 'Register'}
            {sale.npc ? ', cash' : ''}
          </Stack.Item>
          <Stack.Item width="90px" textAlign="right" style={CLIP}>
            {sale.taken ? (
              <Box color="average">Taken</Box>
            ) : (
              <Box color="good">{sale.total} cr</Box>
            )}
          </Stack.Item>
        </Stack>
      ))}
    </Section>
  );
};
