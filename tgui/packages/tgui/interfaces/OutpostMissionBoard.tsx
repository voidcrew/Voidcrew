import {
  Box,
  Button,
  NoticeBox,
  Section,
  Stack,
} from 'tgui-core/components';
import type { BooleanLike } from 'tgui-core/react';

import { useBackend } from '../backend';
import { Window } from '../layouts';

type Offer = {
  ref: string;
  name: string;
  desc: string;
  wanted_text: string;
  reward_item: string | null;
  difficulty_name: string;
  difficulty_color: string;
  progress: string;
};

type Data = {
  shop_name: string;
  trader_name: string;
  barred: BooleanLike;
  ship_name: string | null;
  ship_mission_slots_free: number;
  offers: Offer[];
  accepted: Offer[];
};

export const OutpostMissionBoard = (props) => {
  const { act, data } = useBackend<Data>();
  const {
    shop_name,
    trader_name,
    barred,
    ship_name,
    ship_mission_slots_free,
    offers = [],
    accepted = [],
  } = data;

  const canAccept = !barred && !!ship_name && ship_mission_slots_free > 0;

  return (
    <Window title={`${shop_name} — Supply Requests`} width={480} height={500}>
      <Window.Content scrollable>
        {!!barred && (
          <NoticeBox danger>
            TRADE EMBARGO IN EFFECT — {trader_name} is not posting work for
            you.
          </NoticeBox>
        )}
        {!ship_name && (
          <NoticeBox>
            No crew registration found — you need a ship to take a contract.
          </NoticeBox>
        )}
        <Section
          title={`${trader_name} wants hauled in:`}
          buttons={
            ship_name ? (
              <Box inline color="label">
                {ship_name} · {ship_mission_slots_free} mission slot
                {ship_mission_slots_free === 1 ? '' : 's'} free
              </Box>
            ) : null
          }
        >
          {offers.length === 0 && (
            <Box color="label">Nothing posted right now.</Box>
          )}
          {offers.map((offer) => (
            <Section key={offer.ref}>
              <Stack align="center">
                <Stack.Item grow>
                  <Stack vertical>
                    <Stack.Item bold>
                      {offer.wanted_text}
                      {'  '}
                      <Box inline color={offer.difficulty_color}>
                        [{offer.difficulty_name}]
                      </Box>
                    </Stack.Item>
                    <Stack.Item color="label" fontSize="0.9em">
                      {offer.desc}
                    </Stack.Item>
                    <Stack.Item color="gold">
                      Pay: one free {offer.reward_item ?? 'item'}
                    </Stack.Item>
                  </Stack>
                </Stack.Item>
                <Stack.Item>
                  <Button
                    icon="file-signature"
                    disabled={!canAccept}
                    tooltip={
                      canAccept
                        ? 'Turn in at your own ship&apos;s mission board and pad.'
                        : undefined
                    }
                    onClick={() => act('accept', { ref: offer.ref })}
                  >
                    Accept
                  </Button>
                </Stack.Item>
              </Stack>
            </Section>
          ))}
        </Section>
        {accepted.length > 0 && (
          <Section title="Already on your ship's books">
            {accepted.map((offer) => (
              <Box key={offer.ref} color="label">
                {offer.wanted_text} — free {offer.reward_item ?? 'item'} on
                delivery
              </Box>
            ))}
          </Section>
        )}
        <Section>
          <Box color="label" fontSize="0.9em">
            Deliver the goods to your own ship&apos;s mission pad; the reward
            item beams onto the pad on turn-in.
          </Box>
        </Section>
      </Window.Content>
    </Window>
  );
};
