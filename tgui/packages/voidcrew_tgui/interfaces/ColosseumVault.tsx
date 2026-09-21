import { useState } from 'react';
import {
  Button,
  Icon,
  ImageButton,
  Input,
  NoticeBox,
  NumberInput,
  Section,
  Stack,
} from 'tgui-core/components';
import type { BooleanLike } from 'tgui-core/react';
import { createSearch } from 'tgui-core/string';

import { useBackend } from '../../tgui/backend';
import { Window } from '../../tgui/layouts';
import { getLayoutState, LAYOUT, LayoutToggle } from '../../tgui/interfaces/common/LayoutToggle';

type VaultItem = {
  name: string;
  ref: string;
  corpse: BooleanLike;
  icon: string;
  icon_state: string;
  amount: number;
};

type Data = {
  claim_active: BooleanLike;
  claim_seconds: number;
  is_winner: BooleanLike;
  can_claim: BooleanLike;
  items: VaultItem[];
};

export const ColosseumVault = () => {
  const { data } = useBackend<Data>();
  const { claim_active, claim_seconds, is_winner, can_claim, items } = data;
  const [searchText, setSearchText] = useState('');
  const [displayMode, setDisplayMode] = useState(getLayoutState());
  const search = createSearch(searchText, (item: VaultItem) => item.name);
  const contents = items
    .filter(search)
    .sort((a, b) => a.name.localeCompare(b.name));
  const itemCount = items.reduce((total, item) => total + item.amount, 0);

  return (
    <Window width={480} height={575} theme="retro">
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
            <Section
              fill
              scrollable
              title={`Spoils (${itemCount})`}
              buttons={
                <Stack>
                  <Stack.Item>
                    <Input
                      autoFocus
                      placeholder="Search..."
                      value={searchText}
                      onChange={setSearchText}
                      expensive
                    />
                  </Stack.Item>
                  <LayoutToggle state={displayMode} setState={setDisplayMode} />
                  <Stack.Item>
                    <Button
                      icon="question"
                      tooltip={
                        <>
                          LMB - Claim one
                          <br />
                          RMB - Claim all of this item
                          <br />
                          Enter a quantity to claim that many
                        </>
                      }
                      tooltipPosition="bottom-end"
                    />
                  </Stack.Item>
                </Stack>
              }
            >
              {items.length === 0 ? (
                <NoticeBox>The vault is empty. Fight harder.</NoticeBox>
              ) : contents.length === 0 ? (
                <NoticeBox>Nothing found.</NoticeBox>
              ) : (
                contents.map((item) => (
                  <VaultItemButton
                    key={item.ref}
                    item={item}
                    canClaim={!!can_claim}
                    grid={displayMode === LAYOUT.Grid}
                  />
                ))
              )}
            </Section>
          </Stack.Item>
        </Stack>
      </Window.Content>
    </Window>
  );
};

const VaultItemButton = (props: {
  item: VaultItem;
  canClaim: boolean;
  grid: boolean;
}) => {
  const { item, canClaim, grid } = props;
  const { act } = useBackend<Data>();
  const claim = (amount: number) => act('claim', { ref: item.ref, amount });

  return (
    <ImageButton
      fluid={!grid}
      imageSize={grid ? 64 : 32}
      dmIcon={item.corpse ? null : item.icon}
      dmIconState={item.icon_state}
      fallbackIcon={item.corpse ? 'skull' : 'hand-holding'}
      color={item.corpse ? 'grey' : 'default'}
      disabled={!canClaim}
      tooltip={canClaim ? item.name : 'Only the victors may claim right now.'}
      tooltipPosition="bottom"
      buttons={
        item.amount > 1 && (
          <NumberInput
            width="40px"
            minValue={1}
            maxValue={item.amount}
            step={1}
            value={1}
            disabled={!canClaim}
            onChange={claim}
          />
        )
      }
      buttonsAlt={
        grid && (
          <Stack bold color="label" fontSize={0.8}>
            <Stack.Item grow />
            <Stack.Item style={{ textShadow: '0 1px 1px black' }}>
              x{item.amount}
            </Stack.Item>
          </Stack>
        )
      }
      onClick={() => claim(1)}
      onRightClick={() => claim(item.amount)}
    >
      {grid ? (
        item.name
      ) : (
        <Stack textAlign="left">
          <Stack.Item grow>{item.name}</Stack.Item>
          <Stack.Item color="label" fontSize={0.8}>
            x{item.amount}
          </Stack.Item>
        </Stack>
      )}
    </ImageButton>
  );
};
