import { useState } from 'react';

import {
  Box,
  Button,
  Input,
  NoticeBox,
  Section,
  Stack,
} from 'tgui-core/components';
import type { BooleanLike } from 'tgui-core/react';

import { resolveAsset } from '../../tgui/assets';
import { useBackend } from '../../tgui/backend';
import { Window } from '../../tgui/layouts';

type Shell = {
  id: string;
  name: string;
  description: string;
  preview: string | null;
};

type Data = {
  shells: Shell[];
  max_name_length: number;
  denial: string | null;
  zone_name: string | null;
  protected: BooleanLike;
};

export const OutpostShellCatalog = (props) => {
  const { act, data } = useBackend<Data>();
  const {
    shells = [],
    max_name_length,
    denial,
    zone_name,
    protected: isProtected,
  } = data;

  const [outpostName, setOutpostName] = useState('');
  const [selectedShell, setSelectedShell] = useState<string | null>(null);

  const canFound = !denial && outpostName.trim().length > 0 && !!selectedShell;

  return (
    <Window title="Colonial Registry: Land Claim" width={560} height={560}>
      <Window.Content scrollable>
        {denial ? (
          <NoticeBox danger>{denial}</NoticeBox>
        ) : (
          <NoticeBox success={!!isProtected}>
            {zone_name} · {isProtected ? 'Patrolled' : 'Unpatrolled'}
          </NoticeBox>
        )}
        <Section title="Outpost Name">
          <Input
            fluid
            placeholder="Name your outpost..."
            maxLength={max_name_length}
            value={outpostName}
            onChange={setOutpostName}
          />
        </Section>
        <Section title="Habitat">
          <Stack>
            {shells.map((shell) => (
              <Stack.Item key={shell.id} grow basis={0}>
                <Button
                  fluid
                  selected={selectedShell === shell.id}
                  onClick={() => setSelectedShell(shell.id)}
                  style={{ whiteSpace: 'normal', padding: '6px' }}
                >
                  {!!shell.preview && (
                    <img
                      src={resolveAsset(shell.preview)}
                      alt={shell.name}
                      style={{ width: '100%' }}
                    />
                  )}
                  <Box bold mt={0.5}>
                    {shell.name}
                  </Box>
                  <Box fontSize="0.9em" opacity={0.8}>
                    {shell.description}
                  </Box>
                </Button>
              </Stack.Item>
            ))}
          </Stack>
        </Section>
        <Section>
          <Button
            fluid
            icon="flag"
            color="good"
            disabled={!canFound}
            textAlign="center"
            onClick={() =>
              act('found', {
                shell_id: selectedShell,
                name: outpostName.trim(),
              })
            }
          >
            Register Claim &amp; Found Outpost
          </Button>
        </Section>
      </Window.Content>
    </Window>
  );
};
