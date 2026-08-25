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

import { useBackend } from '../backend';
import { Window } from '../layouts';

type Shell = {
  id: string;
  name: string;
  description: string;
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
    <Window title="Colonial Registry: Land Claim" width={460} height={520}>
      <Window.Content scrollable>
        {denial ? (
          <NoticeBox danger>{denial}</NoticeBox>
        ) : (
          <NoticeBox success={!!isProtected} warning={!isProtected}>
            Claim site is in the {zone_name} zone, {' '}
            {isProtected
              ? 'patrolled space. Your outpost will be protected from ship weapons.'
              : 'unpatrolled space. Your outpost CAN be attacked by other ships.'}
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
        <Section title="Starting Shell">
          {shells.map((shell) => (
            <Section key={shell.id}>
              <Stack align="center">
                <Stack.Item grow>
                  <Box bold>{shell.name}</Box>
                  <Box color="label" fontSize="0.9em">
                    {shell.description}
                  </Box>
                </Stack.Item>
                <Stack.Item>
                  <Button.Checkbox
                    checked={selectedShell === shell.id}
                    onClick={() => setSelectedShell(shell.id)}
                  >
                    Select
                  </Button.Checkbox>
                </Stack.Item>
              </Stack>
            </Section>
          ))}
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
          <Box color="label" fontSize="0.85em" mt={1}>
            Founding is permanent for the shift: the claim is fixed at your
            ship&apos;s current coordinates and the deed is consumed.
          </Box>
        </Section>
      </Window.Content>
    </Window>
  );
};
