// VOIDCREW EDIT: player_outposts supports claim treasury deposits and withdrawals.
import { useState } from 'react';

import {
  AnimatedNumber,
  // VOIDCREW EDIT: player_outposts supports claim treasury deposits and withdrawals.
  Box,
  Button,
  // VOIDCREW EDIT: player_outposts supports claim treasury deposits and withdrawals.
  Input,
  LabeledList,
  NoticeBox,
  Section,
} from 'tgui-core/components';
import { formatMoney } from 'tgui-core/format';
import type { BooleanLike } from 'tgui-core/react';

import { useBackend } from '../backend';
import { Window } from '../layouts';

type Data = {
  current_balance: number;
  siphoning: BooleanLike;
  station_name: string;
  // VOIDCREW EDIT START: player_outposts supports claim treasury deposits and withdrawals.
  is_outpost?: BooleanLike;
  user_account?: string | null;
  can_withdraw?: BooleanLike;
  history?: { adjusted_money: number; reason: string }[];
  // VOIDCREW EDIT END
};

export const BankMachine = (props) => {
  const { act, data } = useBackend<Data>();
  const { current_balance, siphoning, station_name } = data;
  // VOIDCREW EDIT START: player_outposts supports claim treasury deposits and withdrawals.
  const [amount, setAmount] = useState('');
  const isOutpost = !!data.is_outpost;
  // VOIDCREW EDIT END

  return (
    // VOIDCREW EDIT: player_outposts supports claim treasury deposits and withdrawals.
    <Window width={isOutpost ? 450 : 350} height={isOutpost ? 390 : 155}>
      {/* VOIDCREW EDIT: player_outposts supports claim treasury deposits and withdrawals. */}
      <Window.Content scrollable={isOutpost}>
        {/* VOIDCREW EDIT START: player_outposts supports claim treasury deposits and withdrawals. */}
        <NoticeBox danger>
          {isOutpost ? 'Claim treasury' : 'Authorized personnel only'}
        </NoticeBox>
        {/* VOIDCREW EDIT END */}
        <Section title={`${station_name} Vault`}>
          <LabeledList>
            <LabeledList.Item
              label="Current Balance"
              buttons={
                // VOIDCREW EDIT START: player_outposts supports claim treasury deposits and withdrawals.
                !isOutpost && (
                  <Button
                    icon={siphoning ? 'times' : 'sync'}
                    content={siphoning ? 'Stop Siphoning' : 'Siphon Credits'}
                    selected={siphoning}
                    onClick={() => act(siphoning ? 'halt' : 'siphon')}
                  />
                )
                // VOIDCREW EDIT END
              }
            >
              <AnimatedNumber
                value={current_balance}
                format={(value) => formatMoney(value)}
              />
              {' cr'}
            </LabeledList.Item>
          </LabeledList>
        </Section>
        {/* VOIDCREW EDIT START: player_outposts supports claim treasury deposits and withdrawals. */}
        {!!isOutpost && (
          <Section title="Account transfer">
            <Box>
              Your ID account: {data.user_account || 'No account on ID'}
            </Box>
            <Box color="label">Amount (whole credits)</Box>
            <Input placeholder="Credits" value={amount} onChange={setAmount} />
            <Button
              icon="arrow-down"
              disabled={!data.user_account}
              onClick={() => act('deposit', { amount })}
            >
              Deposit
            </Button>
            <Button
              icon="arrow-up"
              disabled={!data.can_withdraw || !data.user_account}
              onClick={() => act('withdraw', { amount })}
            >
              Withdraw
            </Button>
          </Section>
        )}
        {!!isOutpost && !!data.history?.length && (
          <Section title="Recent transactions" scrollable height="145px">
            {data.history
              .slice(-10)
              .reverse()
              .map((entry, index) => (
                <Box key={index}>
                  {entry.adjusted_money} cr: {entry.reason}
                </Box>
              ))}
          </Section>
        )}
        {/* VOIDCREW EDIT END */}
      </Window.Content>
    </Window>
  );
};
