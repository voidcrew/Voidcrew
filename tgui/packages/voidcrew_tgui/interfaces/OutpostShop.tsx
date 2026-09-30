/**
 * Owner shop register: the buyer window (outpost_shop.dm, outpost_shop_stock.dm).
 *
 * `price` is what this viewer pays per unit (0 for staff who take stock free);
 * `buy` echoes it so a price change while the window is open is refused.
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

type Data = {
  shop_name: string;
  open: BooleanLike;
  closed_reason: string | null;
  free_take: BooleanLike;
  account_credits: number | null;
  confirm_total: number;
  categories: Category[];
  listings: Listing[];
};

const ALL = '__all__';

export const OutpostShop = (props) => {
  const { data } = useBackend<Data>();
  const {
    shop_name,
    open,
    closed_reason,
    categories = [],
    listings = [],
  } = data;
  const [category, setCategory] = useState(ALL);
  const [search, setSearch] = useState('');

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
        {open ? (
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
                        {cat.name}
                      </Tabs.Tab>
                    ))}
                  </Tabs>
                </Section>
              </Stack.Item>
            ) : null}
            <Stack.Item grow>
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
      <Stack align="center">
        <Stack.Item>
          <DmIcon
            icon={listing.icon}
            icon_state={listing.icon_state}
            width="32px"
            height="32px"
            fallback={<Icon name="box" size={1.5} />}
          />
        </Stack.Item>
        <Stack.Item grow>
          <Box bold>{listing.name}</Box>
          <Box color="label">
            {soldOut
              ? 'Sold out'
              : free_take
                ? null
                : `${listing.price} cr${listing.per_unit ? ' each' : ''}`}
          </Box>
        </Stack.Item>
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
                ? `Confirm ${total} cr`
                : `${total} cr`}
          </Button>
        </Stack.Item>
      </Stack>
    </Box>
  );
};
