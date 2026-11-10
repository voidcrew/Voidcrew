import { useState } from 'react';
import { Box, Button, Icon, Section, Stack, Tabs } from 'tgui-core/components';
import type { BooleanLike } from 'tgui-core/react';

import { useBackend } from '../backend';
import { Window } from '../layouts';

type Step = {
  key: string;
  name: string;
  text: string;
  optional: BooleanLike;
};

type Item = {
  id: string;
  name: string;
  steps: Step[];
};

type Data = {
  items: Item[];
  done: string[];
  notes: Record<string, string>;
  excused: string[];
  spawn_open: BooleanLike;
};

const itemProgress = (item: Item, done: Set<string>, excused: Set<string>) => {
  const counted = item.steps.filter(
    (step) => !step.optional && !excused.has(step.key),
  );
  const finished = counted.filter((step) => done.has(step.key)).length;
  const complete = done.has(item.id) || finished >= counted.length;
  return { finished, total: counted.length, complete };
};

export const TutorialChecklist = () => {
  const { act, data } = useBackend<Data>();
  const { items = [], notes = {}, spawn_open } = data;
  const done = new Set(data.done || []);
  const excused = new Set(data.excused || []);

  const firstOpen =
    items.find((item) => !itemProgress(item, done, excused).complete) ||
    items[0];
  const [selectedId, setSelectedId] = useState<string | undefined>(
    firstOpen?.id,
  );
  const selected = items.find((item) => item.id === selectedId) || firstOpen;

  return (
    <Window title="Tutorials" width={560} height={440}>
      <Window.Content>
        <Stack vertical fill>
          <Stack.Item grow>
            <Stack fill>
              <Stack.Item width="185px">
                <Section fill scrollable>
                  <Tabs vertical>
                    {items.map((item) => {
                      const progress = itemProgress(item, done, excused);
                      return (
                        <Tabs.Tab
                          key={item.id}
                          selected={item.id === selected?.id}
                          onClick={() => setSelectedId(item.id)}
                        >
                          <Stack>
                            <Stack.Item grow>{item.name}</Stack.Item>
                            <Stack.Item>
                              {progress.complete ? (
                                <Icon name="check" color="good" />
                              ) : (
                                <Box color="label">
                                  {progress.finished}/{progress.total}
                                </Box>
                              )}
                            </Stack.Item>
                          </Stack>
                        </Tabs.Tab>
                      );
                    })}
                  </Tabs>
                </Section>
              </Stack.Item>
              <Stack.Item grow>
                <Section fill scrollable title={selected?.name}>
                  {selected ? (
                    selected.steps.map((step) => (
                      <StepRow
                        key={step.key}
                        step={step}
                        done={done.has(step.key)}
                        note={notes[step.key]}
                      />
                    ))
                  ) : null}
                </Section>
              </Stack.Item>
            </Stack>
          </Stack.Item>
          <Stack.Item>
            <Button.Checkbox
              checked={!spawn_open}
              onClick={() => act('toggle_spawn_open')}
            >
              Don&apos;t open on spawn
            </Button.Checkbox>
          </Stack.Item>
        </Stack>
      </Window.Content>
    </Window>
  );
};

type StepRowProps = {
  step: Step;
  done: boolean;
  note?: string;
};

const StepRow = (props: StepRowProps) => {
  const { step, done, note } = props;
  return (
    <Stack mb={1.5}>
      <Stack.Item>
        <Icon
          name={done ? 'square-check' : 'square'}
          color={done ? 'good' : 'label'}
          size={1.2}
        />
      </Stack.Item>
      <Stack.Item grow>
        <Box bold color={done ? 'label' : undefined}>
          {step.name}
          {step.optional ? (
            <Box as="span" color="label" ml={1} bold={false}>
              (optional)
            </Box>
          ) : null}
        </Box>
        <Box color="label">{step.text}</Box>
        {!done && !!note ? (
          <Box color="average" italic>
            {note}
          </Box>
        ) : null}
      </Stack.Item>
    </Stack>
  );
};
