import {
  Box,
  Button,
  NoticeBox,
  Section,
  Stack,
  Table,
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

type Data = {
  shop_name: string;
  trader_name: string;
  barred: BooleanLike;
  held_vouchers: number;
  account_credits: number | null;
  skus: Sku[];
};

export const TraderShop = (props) => {
  const { act, data } = useBackend<Data>();
  const {
    shop_name,
    trader_name,
    barred,
    held_vouchers,
    account_credits,
    skus = [],
  } = data;

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
          title={`${trader_name}'s Stock`}
          buttons={
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
          }
        >
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
        </Section>
        <Section>
          <Box color="label" fontSize="0.9em">
            Fixed prices. Vouchers and credits charged on the spot — hold
            vouchers or barter goods in hand, credits come off your ID. No
            refunds.
          </Box>
        </Section>
      </Window.Content>
    </Window>
  );
};
