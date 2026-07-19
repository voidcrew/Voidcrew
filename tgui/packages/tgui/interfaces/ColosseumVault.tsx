import {
  Button,
  Icon,
  NoticeBox,
  Section,
  Stack,
} from 'tgui-core/components';
import type { BooleanLike } from 'tgui-core/react';

import { useBackend } from '../backend';
import { Window } from '../layouts';

type VaultItem = {
  name: string;
  ref: string;
  corpse: BooleanLike;
};

type Data = {
  claim_active: BooleanLike;
  claim_seconds: number;
  is_winner: BooleanLike;
  can_claim: BooleanLike;
  items: VaultItem[];
};

export const ColosseumVault = (props) => {
  const { data, act } = useBackend<Data>();
  const { claim_active, claim_seconds, is_winner, can_claim, items } = data;

  return (
    <Window width={360} height={480} theme="retro">
      <Window.Content>
        <Stack vertical fill>
          <Stack.Item>
            {claim_active ? (
              <NoticeBox color={is_winner ? 'good' : 'bad'}>
                <Icon name={is_winner ? 'trophy' : 'lock'} mr={1} />
                {is_winner
                  ? `Victor's claim window: ${claim_seconds}s remaining.`
                  : `Winners-only claim window: opens to all in ${claim_seconds}s.`}
              </NoticeBox>
            ) : (
              <NoticeBox info>
                <Icon name="unlock" mr={1} />
                The vault is unlocked to the public.
              </NoticeBox>
            )}
          </Stack.Item>
          <Stack.Item grow>
            <Section fill scrollable title={`Spoils (${items.length})`}>
              {items.length === 0 && (
                <NoticeBox>The vault is empty. Fight harder.</NoticeBox>
              )}
              <Stack vertical>
                {items.map((item) => (
                  <Stack.Item key={item.ref}>
                    <Button
                      fluid
                      ellipsis
                      textAlign="left"
                      icon={item.corpse ? 'skull' : 'hand-holding'}
                      color={item.corpse ? 'grey' : 'default'}
                      disabled={!can_claim}
                      tooltip={
                        can_claim
                          ? 'Take this from the vault.'
                          : 'Only the victors may claim right now.'
                      }
                      onClick={() => act('claim', { ref: item.ref })}
                    >
                      {item.name}
                    </Button>
                  </Stack.Item>
                ))}
              </Stack>
            </Section>
          </Stack.Item>
        </Stack>
      </Window.Content>
    </Window>
  );
};
