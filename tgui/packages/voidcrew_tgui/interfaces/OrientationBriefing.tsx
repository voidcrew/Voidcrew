import { useState } from 'react';
import {
  Box,
  Button,
  Icon,
  NoticeBox,
  Section,
  Stack,
  Tabs,
} from 'tgui-core/components';
import type { BooleanLike } from 'tgui-core/react';

import { useBackend } from '../backend';
import { Window } from '../layouts';

type Zone = {
  name: string;
  color: string;
  summary: string;
  rules: string[];
};

type ResearchNode = {
  name: string;
  desc: string;
};

type Data = {
  ship_name: string | null;
  combat_researched: BooleanLike;
  zones: Zone[];
  research_path: ResearchNode[];
};

type TabName = 'welcome' | 'zones' | 'combat';

const TABS: { id: TabName; label: string; icon: string }[] = [
  { id: 'welcome', label: 'Welcome', icon: 'hand-spock' },
  { id: 'zones', label: 'Zones', icon: 'circle-half-stroke' },
  { id: 'combat', label: 'Ship Combat', icon: 'crosshairs' },
];

export const OrientationBriefing = () => {
  const [tab, setTab] = useState<TabName>('welcome');

  return (
    <Window title="Welcome to Voidcrew" width={600} height={560}>
      <Window.Content scrollable>
        <Stack vertical fill>
          <Stack.Item>
            <Tabs fluid>
              {TABS.map((entry) => (
                <Tabs.Tab
                  key={entry.id}
                  selected={tab === entry.id}
                  onClick={() => setTab(entry.id)}
                  icon={entry.icon}
                >
                  {entry.label}
                </Tabs.Tab>
              ))}
            </Tabs>
          </Stack.Item>
          <Stack.Item grow>
            {tab === 'welcome' && <WelcomeTab />}
            {tab === 'zones' && <ZonesTab />}
            {tab === 'combat' && <CombatTab />}
          </Stack.Item>
        </Stack>
      </Window.Content>
    </Window>
  );
};

/** The reason this window exists at all: the server is being tested on you. */
const WelcomeTab = () => {
  const { act } = useBackend<Data>();

  return (
    <Section title="This server is in early testing">
      <NoticeBox>
        Things will break. Expect bugs, half-finished features and rounds that
        end badly through no fault of your own.
      </NoticeBox>
      <Box mb={1}>
        Report anything broken to <b>jackrip</b> on the Discord, what you were
        doing and roughly when is usually enough to find it in the logs. The
        wiki covers ships, the overmap, missions and everything else Voidcrew
        adds, in far more detail than this window.
      </Box>
      <Stack mb={2}>
        <Stack.Item>
          <Button icon="comments" onClick={() => act('open_discord')}>
            Open the Discord
          </Button>
        </Stack.Item>
        <Stack.Item>
          <Button icon="book" onClick={() => act('open_wiki')}>
            Open the Wiki
          </Button>
        </Stack.Item>
      </Stack>
      <Box color="label">
        You crew a ship on an overmap. Take contracts, mine, trade and explore;
        fly further in for better pay and worse odds. The other two tabs cover
        where you are allowed to go and how to arm the ship.
      </Box>
    </Section>
  );
};

/** What the three overmap bands permit, straight off the defines that enforce it. */
const ZonesTab = () => {
  const { data } = useBackend<Data>();
  const { zones } = data;

  return (
    <Section title="The three rings">
      <Box mb={2} color="label">
        Your helm console always shows which ring you are in. Crossing a border
        takes ten seconds and can be cancelled until it completes.
      </Box>
      {zones.map((zone) => (
        <Box key={zone.name} mb={2}>
          <Box bold style={{ color: zone.color }}>
            <Icon name="circle" mr={1} />
            {zone.name}
          </Box>
          <Box mb={1}>{zone.summary}</Box>
          <Box ml={2}>
            {zone.rules.map((rule) => (
              <Box key={rule} color="label">
                • {rule}
              </Box>
            ))}
          </Box>
        </Box>
      ))}
      <NoticeBox mt={2}>
        The Deeper in you need to be ready for anything: meteors, radiation storms on
        planets, hostile crews and worse.
      </NoticeBox>
    </Section>
  );
};

/** Why a new crew should not simply fly inward, and what fixes that. */
const CombatTab = () => {
  const { data } = useBackend<Data>();
  const { research_path, combat_researched, ship_name } = data;

  return (
    <Section title="Ship combat gear">
      <Box mb={2}>
        Shields, turrets, missiles and interdictors are researched on your own
        ship, not bought. Use an R&amp;D console wired to your ship&apos;s
        research server; each node unlocks a board you print and build in.
      </Box>
      {research_path.map((node) => (
        <Box key={node.name} mb={1}>
          <Box bold>{node.name}</Box>
          <Box color="label">{node.desc}</Box>
        </Box>
      ))}
      {combat_researched ? (
        <NoticeBox success mt={2}>
          {ship_name ?? 'Your ship'} has Shuttle Warfare Systems researched. You
          can build shields and weapons whenever you are ready.
        </NoticeBox>
      ) : (
        <NoticeBox danger mt={2}>
          {ship_name ?? 'Your ship'} has no Shuttle Warfare Systems research yet:
          no shields, nothing to shoot back with. Take contracts in the middle
          ring, earn research points, and stay out of the inner ring until you
          are equipped.
        </NoticeBox>
      )}
    </Section>
  );
};
