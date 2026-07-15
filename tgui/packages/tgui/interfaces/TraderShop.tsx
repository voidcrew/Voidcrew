import { useState } from 'react';
import {
  Box,
  Button,
  Image,
  NoticeBox,
  Section,
  Stack,
  Tabs,
  Tooltip,
} from 'tgui-core/components';
import type { BooleanLike } from 'tgui-core/react';

import { useBackend } from '../backend';
import { Window } from '../layouts';

type CatalogSku = {
  ref: string;
  name: string;
  desc: string;
  category: string;
  shelf: 'core' | 'rotating' | 'rare';
  icon: string | null;
  price_credits: number;
  final_credits: number;
  price_vouchers: number;
  discount_pct: number;
  price_text: string;
  barter: BooleanLike;
};

type StockState = {
  ref: string;
  stock: number;
  can_buy: BooleanLike;
  denial: string | null;
};

type LedgerEntry = {
  ref: string;
  name: string;
  desc: string;
  category: string;
  icon: string | null;
  wanted_text: string;
  payment_text: string;
  pays_vouchers: BooleanLike;
};

type LedgerState = {
  ref: string;
  demand: number;
  carrying: number;
  can_sell: BooleanLike;
  denial: string | null;
};

type Data = {
  // static
  shop_name: string;
  trader_name: string;
  categories: string[];
  catalog: CatalogSku[];
  ledger: LedgerEntry[];
  // dynamic
  barred: BooleanLike;
  held_vouchers: number;
  account_credits: number | null;
  stock_states: StockState[];
  ledger_states: LedgerState[];
};

const SHELF_TAGS = {
  rotating: { label: 'LIMITED', color: 'average' },
  rare: { label: 'RARE FIND', color: 'purple' },
} as const;

const WalletHeader = (props: {
  held_vouchers: number;
  account_credits: number | null;
}) => {
  const { held_vouchers, account_credits } = props;
  return (
    <Box inline color="label">
      Carrying{' '}
      <Box inline bold color="purple">
        {held_vouchers}
      </Box>{' '}
      voucher{held_vouchers === 1 ? '' : 's'}
      {' · '}
      {account_credits === null ? (
        <Box inline color="bad">
          no ID account
        </Box>
      ) : (
        <Box inline bold color="gold">
          {account_credits} cr
        </Box>
      )}
    </Box>
  );
};

const ProductImage = (props: { icon: string | null }) => {
  const { icon } = props;
  if (!icon) {
    return <Box width="32px" height="32px" />;
  }
  return (
    <Image
      src={`data:image/png;base64,${icon}`}
      width="32px"
      height="32px"
      style={{ imageRendering: 'pixelated', verticalAlign: 'middle' }}
    />
  );
};

const PriceTag = (props: { sku: CatalogSku }) => {
  const { sku } = props;
  if (sku.barter) {
    return (
      <Box inline bold color="teal">
        {sku.price_text}
      </Box>
    );
  }
  const discounted = sku.discount_pct > 0 && sku.price_credits > 0;
  return (
    <Box inline textAlign="right">
      {sku.price_vouchers > 0 && (
        <Box inline bold color="purple">
          {sku.price_vouchers} vch
        </Box>
      )}
      {sku.price_vouchers > 0 && sku.price_credits > 0 && (
        <Box inline color="label">
          {' + '}
        </Box>
      )}
      {sku.price_credits > 0 && (
        <>
          {discounted && (
            <Box
              inline
              color="label"
              style={{ textDecoration: 'line-through' }}
            >
              {sku.price_credits}
            </Box>
          )}{' '}
          <Box inline bold color="gold">
            {sku.final_credits} cr
          </Box>
        </>
      )}
      {sku.price_vouchers <= 0 && sku.price_credits <= 0 && (
        <Box inline color="good">
          free
        </Box>
      )}
    </Box>
  );
};

const SkuRow = (props: {
  sku: CatalogSku;
  live: StockState | undefined;
  barred: BooleanLike;
}) => {
  const { act } = useBackend<Data>();
  const { sku, live, barred } = props;
  const stock = live?.stock ?? 0;
  const soldOut = stock <= 0;
  const shelfTag = SHELF_TAGS[sku.shelf as keyof typeof SHELF_TAGS];

  const buyButton = (
    <Button
      disabled={!live?.can_buy}
      icon="cart-shopping"
      onClick={() => act('buy', { ref: sku.ref })}
    >
      {soldOut ? 'Sold out' : 'Buy'}
    </Button>
  );

  return (
    <Stack
      align="center"
      py={0.5}
      className="candystripe"
      opacity={soldOut ? 0.5 : 1}
    >
      <Stack.Item>
        <ProductImage icon={sku.icon} />
      </Stack.Item>
      <Stack.Item grow>
        <Box bold>
          {sku.name}{' '}
          {sku.discount_pct > 0 && (
            <Box inline color="good" bold>
              −{sku.discount_pct}%
            </Box>
          )}{' '}
          {shelfTag && (
            <Box inline color={shelfTag.color} fontSize="0.8em" bold>
              {shelfTag.label}
            </Box>
          )}
        </Box>
        <Box color="label" fontSize="0.85em">
          {sku.desc}
        </Box>
      </Stack.Item>
      <Stack.Item textAlign="right" minWidth="90px">
        <PriceTag sku={sku} />
      </Stack.Item>
      <Stack.Item color="label" minWidth="30px" textAlign="center">
        x{stock}
      </Stack.Item>
      <Stack.Item>
        {live?.denial && !barred && !soldOut ? (
          <Tooltip content={live.denial}>{buyButton}</Tooltip>
        ) : (
          buyButton
        )}
      </Stack.Item>
    </Stack>
  );
};

const BuyView = (props: { barred: BooleanLike }) => {
  const { data } = useBackend<Data>();
  const { barred } = props;
  const { categories = [], catalog = [], stock_states = [] } = data;
  const [category, setCategory] = useState('All');

  const liveByRef = new Map(stock_states.map((s) => [s.ref, s]));

  // Shop-declared category order first, then anything unlisted in first-seen order
  const orderedCategories: string[] = [...categories];
  for (const sku of catalog) {
    if (!orderedCategories.includes(sku.category)) {
      orderedCategories.push(sku.category);
    }
  }
  const withItems = orderedCategories.filter((cat) =>
    catalog.some((sku) => sku.category === cat),
  );

  const shown =
    category === 'All'
      ? catalog
      : catalog.filter((sku) => sku.category === category);

  return (
    <Stack fill>
      <Stack.Item minWidth="130px">
        <Tabs vertical>
          <Tabs.Tab selected={category === 'All'} onClick={() => setCategory('All')}>
            All ({catalog.length})
          </Tabs.Tab>
          {withItems.map((cat) => (
            <Tabs.Tab
              key={cat}
              selected={category === cat}
              onClick={() => setCategory(cat)}
            >
              {cat} ({catalog.filter((sku) => sku.category === cat).length})
            </Tabs.Tab>
          ))}
        </Tabs>
      </Stack.Item>
      <Stack.Item grow>
        <Section fill scrollable>
          {shown.map((sku) => (
            <SkuRow
              key={sku.ref}
              sku={sku}
              live={liveByRef.get(sku.ref)}
              barred={barred}
            />
          ))}
        </Section>
      </Stack.Item>
    </Stack>
  );
};

const LedgerRow = (props: {
  entry: LedgerEntry;
  live: LedgerState | undefined;
  barred: BooleanLike;
}) => {
  const { act } = useBackend<Data>();
  const { entry, live, barred } = props;
  const demand = live?.demand ?? 0;
  const carrying = live?.carrying ?? 0;
  const done = demand <= 0;

  const sellButtons = (
    <>
      <Button
        disabled={!live?.can_sell}
        icon="hand-holding-dollar"
        onClick={() => act('sell', { ref: entry.ref })}
      >
        {done ? 'Not buying' : 'Sell'}
      </Button>
      {!done && carrying > 1 && (
        <Button
          disabled={!live?.can_sell}
          icon="boxes-stacked"
          tooltip="Sell everything you're carrying, up to demand"
          onClick={() => act('sell_all', { ref: entry.ref })}
        >
          All
        </Button>
      )}
    </>
  );

  return (
    <Stack align="center" py={0.5} className="candystripe" opacity={done ? 0.5 : 1}>
      <Stack.Item>
        <ProductImage icon={entry.icon} />
      </Stack.Item>
      <Stack.Item grow>
        <Box bold>
          {entry.wanted_text}{' '}
          {!!entry.pays_vouchers && (
            <Box inline color="purple" fontSize="0.8em" bold>
              VOUCHERS
            </Box>
          )}
        </Box>
        <Box color="label" fontSize="0.85em">
          {entry.desc}
        </Box>
      </Stack.Item>
      <Stack.Item
        textAlign="right"
        minWidth="90px"
        color={entry.pays_vouchers ? 'purple' : 'gold'}
      >
        {entry.payment_text}
      </Stack.Item>
      <Stack.Item color="label" minWidth="70px" textAlign="center">
        wants {demand}
        <Box color={carrying > 0 ? 'good' : 'label'} fontSize="0.85em">
          you: {carrying}
        </Box>
      </Stack.Item>
      <Stack.Item>
        {live?.denial && !barred && !done ? (
          <Tooltip content={live.denial}>{sellButtons}</Tooltip>
        ) : (
          sellButtons
        )}
      </Stack.Item>
    </Stack>
  );
};

const SellView = (props: { barred: BooleanLike }) => {
  const { data } = useBackend<Data>();
  const { barred } = props;
  const { ledger = [], ledger_states = [] } = data;
  const liveByRef = new Map(ledger_states.map((s) => [s.ref, s]));
  return (
    <Section fill scrollable>
      {ledger.length === 0 && (
        <Box color="label">Not buying anything this shift.</Box>
      )}
      {ledger.map((entry) => (
        <LedgerRow
          key={entry.ref}
          entry={entry}
          live={liveByRef.get(entry.ref)}
          barred={barred}
        />
      ))}
    </Section>
  );
};

export const TraderShop = (props) => {
  const { data } = useBackend<Data>();
  const {
    shop_name,
    trader_name,
    barred,
    held_vouchers,
    account_credits,
    catalog = [],
    ledger = [],
  } = data;

  const [tab, setTab] = useState<'buy' | 'sell'>('buy');
  const hasBuybacks = ledger.length > 0;
  const specials = catalog.filter((sku) => sku.discount_pct > 0);

  return (
    <Window title={shop_name} width={720} height={640}>
      <Window.Content>
        <Stack fill vertical>
          {!!barred && (
            <Stack.Item>
              <NoticeBox danger>
                TRADE EMBARGO IN EFFECT — service refused. Embargoes expire;
                grudges do not.
              </NoticeBox>
            </Stack.Item>
          )}
          {specials.length > 0 && tab === 'buy' && (
            <Stack.Item>
              <NoticeBox info>
                {trader_name}&apos;s special today:{' '}
                {specials
                  .map((sku) => `${sku.name} (−${sku.discount_pct}%)`)
                  .join(', ')}
              </NoticeBox>
            </Stack.Item>
          )}
          <Stack.Item grow>
            <Section
              fill
              title={
                <Tabs>
                  <Tabs.Tab
                    selected={tab === 'buy'}
                    onClick={() => setTab('buy')}
                  >
                    {trader_name}&apos;s Stock
                  </Tabs.Tab>
                  {hasBuybacks && (
                    <Tabs.Tab
                      selected={tab === 'sell'}
                      onClick={() => setTab('sell')}
                    >
                      {trader_name} Buys
                    </Tabs.Tab>
                  )}
                </Tabs>
              }
              buttons={
                <WalletHeader
                  held_vouchers={held_vouchers}
                  account_credits={account_credits}
                />
              }
            >
              {tab === 'sell' && hasBuybacks ? (
                <SellView barred={barred} />
              ) : (
                <BuyView barred={barred} />
              )}
            </Section>
          </Stack.Item>
          <Stack.Item>
            <Box color="label" fontSize="0.85em" px={1}>
              Fixed prices, charged on the spot — vouchers from anywhere on
              you, credits off your ID, barter goods held in hand. No refunds.
            </Box>
          </Stack.Item>
        </Stack>
      </Window.Content>
    </Window>
  );
};
