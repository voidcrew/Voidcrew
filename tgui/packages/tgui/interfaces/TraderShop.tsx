import { useState } from 'react';
import {
  Box,
  Button,
  NoticeBox,
  Section,
  Stack,
  Table,
  Tabs,
  Tooltip,
} from 'tgui-core/components';
import type { BooleanLike } from 'tgui-core/react';

import { useBackend } from '../backend';
import { Window } from '../layouts';

type Sku = {
  ref: string;
  name: string;
  desc: string;
  price_text: string;
  stock: number;
  can_buy: BooleanLike;
  denial: string | null;
};

type Buyback = {
  ref: string;
  name: string;
  desc: string;
  wanted_text: string;
  payment_text: string;
  demand: number;
  can_sell: BooleanLike;
  denial: string | null;
};

type Data = {
  shop_name: string;
  trader_name: string;
  barred: BooleanLike;
  held_vouchers: number;
  account_credits: number | null;
  skus: Sku[];
  buybacks: Buyback[];
};

const WalletHeader = (props: {
  held_vouchers: number;
  account_credits: number | null;
}) => {
  const { held_vouchers, account_credits } = props;
  return (
    <Box inline color="label">
      Holding{' '}
      <Box inline bold color="good">
        {held_vouchers}
      </Box>{' '}
      voucher{held_vouchers === 1 ? '' : 's'}
      {' · '}
      {account_credits === null ? (
        <Box inline color="bad">
          no ID account
        </Box>
      ) : (
        <Box inline bold>
          {account_credits} cr
        </Box>
      )}
    </Box>
  );
};

const BuyTab = (props: { skus: Sku[]; barred: BooleanLike }) => {
  const { act } = useBackend<Data>();
  const { skus, barred } = props;
  return (
    <Table>
      {skus.map((sku) => (
        <Table.Row key={sku.ref} className="candystripe">
          <Table.Cell>
            <Stack vertical>
              <Stack.Item bold>{sku.name}</Stack.Item>
              <Stack.Item color="label" fontSize="0.9em">
                {sku.desc}
              </Stack.Item>
            </Stack>
          </Table.Cell>
          <Table.Cell collapsing textAlign="right" color="gold">
            {sku.price_text}
          </Table.Cell>
          <Table.Cell collapsing textAlign="center" color="label">
            x{sku.stock}
          </Table.Cell>
          <Table.Cell collapsing>
            {sku.denial && !barred && sku.stock > 0 ? (
              <Tooltip content={sku.denial}>
                <Button disabled icon="cart-shopping">
                  Buy
                </Button>
              </Tooltip>
            ) : (
              <Button
                disabled={!sku.can_buy}
                icon="cart-shopping"
                onClick={() => act('buy', { ref: sku.ref })}
              >
                {sku.stock > 0 ? 'Buy' : 'Sold out'}
              </Button>
            )}
          </Table.Cell>
        </Table.Row>
      ))}
    </Table>
  );
};

const SellTab = (props: { buybacks: Buyback[]; barred: BooleanLike }) => {
  const { act } = useBackend<Data>();
  const { buybacks, barred } = props;
  return (
    <Table>
      {buybacks.map((buyback) => (
        <Table.Row key={buyback.ref} className="candystripe">
          <Table.Cell>
            <Stack vertical>
              <Stack.Item bold>{buyback.wanted_text}</Stack.Item>
              <Stack.Item color="label" fontSize="0.9em">
                {buyback.desc}
              </Stack.Item>
            </Stack>
          </Table.Cell>
          <Table.Cell collapsing textAlign="right" color="gold">
            {buyback.payment_text}
          </Table.Cell>
          <Table.Cell collapsing textAlign="center" color="label">
            wants {buyback.demand}
          </Table.Cell>
          <Table.Cell collapsing>
            {buyback.denial && !barred && buyback.demand > 0 ? (
              <Tooltip content={buyback.denial}>
                <Button disabled icon="hand-holding-dollar">
                  Sell
                </Button>
              </Tooltip>
            ) : (
              <Button
                disabled={!buyback.can_sell}
                icon="hand-holding-dollar"
                onClick={() => act('sell', { ref: buyback.ref })}
              >
                {buyback.demand > 0 ? 'Sell' : 'Not buying'}
              </Button>
            )}
          </Table.Cell>
        </Table.Row>
      ))}
    </Table>
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
    skus = [],
    buybacks = [],
  } = data;

  const [tab, setTab] = useState<'buy' | 'sell'>('buy');
  const hasBuybacks = buybacks.length > 0;

  return (
    <Window title={shop_name} width={560} height={620}>
      <Window.Content scrollable>
        {!!barred && (
          <NoticeBox danger>
            TRADE EMBARGO IN EFFECT — service refused. Embargoes expire;
            grudges do not.
          </NoticeBox>
        )}
        <Section
          title={
            hasBuybacks ? (
              <Tabs>
                <Tabs.Tab selected={tab === 'buy'} onClick={() => setTab('buy')}>
                  {trader_name}&apos;s Stock
                </Tabs.Tab>
                <Tabs.Tab
                  selected={tab === 'sell'}
                  onClick={() => setTab('sell')}
                >
                  {trader_name} Buys
                </Tabs.Tab>
              </Tabs>
            ) : (
              `${trader_name}'s Stock`
            )
          }
          buttons={
            <WalletHeader
              held_vouchers={held_vouchers}
              account_credits={account_credits}
            />
          }
        >
          {tab === 'sell' && hasBuybacks ? (
            <SellTab buybacks={buybacks} barred={barred} />
          ) : (
            <BuyTab skus={skus} barred={barred} />
          )}
        </Section>
        <Section>
          <Box color="label" fontSize="0.9em">
            Fixed prices. Vouchers and credits charged on the spot — hold
            vouchers or barter goods in hand, credits come off your ID. No
            refunds.
            {hasBuybacks &&
              ' Selling works the same way: hold the goods in hand; payouts hit your ID or your palm.'}
          </Box>
        </Section>
      </Window.Content>
    </Window>
  );
};
