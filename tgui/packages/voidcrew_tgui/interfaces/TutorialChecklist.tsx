// Tutorial checklist: category groups on the left, the open lesson on the right.
import { useEffect, useState } from 'react';
import { Box, Button, Icon, Section, Stack, Tabs } from 'tgui-core/components';
import type { BooleanLike } from 'tgui-core/react';

import { useBackend } from '../backend';
import { Window } from '../layouts';

type Step = {
  key: string;
  name: string;
  text: string;
  optional: BooleanLike;
  /** Steps sharing a route form one way to finish the item. */
  route: string | null;
  route_name: string | null;
};

type Item = {
  id: string;
  name: string;
  intro: string;
  steps: Step[];
};

type Category = {
  id: string;
  name: string;
  items: string[];
};

type Data = {
  categories: Category[];
  items: Item[];
  done: string[];
  notes: Record<string, string>;
  /** Live state lines for the open item's undone steps. */
  live: Record<string, string>;
  /** The step the outlines and in-window focus follow, or null. */
  guide: string | null;
  excused: string[];
  suggested: string | null;
  selected: string | null;
  spawn_open: BooleanLike;
  highlights: BooleanLike;
};

type Progress = {
  finished: number;
  total: number;
  complete: boolean;
};

type Lookup = { done: Set<string>; excused: Set<string> };

const routeIds = (steps: Step[]) => {
  const ids: string[] = [];
  for (const step of steps) {
    if (step.route && !ids.includes(step.route)) ids.push(step.route);
  }
  return ids;
};

/** Shared steps plus the route closest to done. Excused and optional steps don't count. */
const itemProgress = (item: Item, look: Lookup): Progress => {
  const live = item.steps.filter(
    (step) => !step.optional && !look.excused.has(step.key),
  );
  const counted = live.filter((step) => !step.route);
  let best: Step[] | undefined;
  let bestShare = -1;
  for (const route of routeIds(live)) {
    const steps = live.filter((step) => step.route === route);
    const share =
      steps.filter((step) => look.done.has(step.key)).length / steps.length;
    if (share > bestShare) {
      best = steps;
      bestShare = share;
    }
  }
  if (best) counted.push(...best);
  const finished = counted.filter((step) => look.done.has(step.key)).length;
  return {
    finished,
    total: counted.length,
    complete: look.done.has(item.id) || finished >= counted.length,
  };
};

const ProgressMark = (props: { progress?: Progress }) => {
  const { progress } = props;
  if (!progress) return null;
  return progress.complete ? (
    <Icon name="check" color="good" />
  ) : (
    <Box as="span" color="label">
      {progress.finished}/{progress.total}
    </Box>
  );
};

export const TutorialChecklist = () => {
  const { act, data } = useBackend<Data>();
  const items = data.items || [];
  const categories = data.categories || [];
  const notes = data.notes || {};
  const live = data.live || {};
  const guide = data.guide || null;
  const suggested = data.suggested || null;
  const look: Lookup = {
    done: new Set(data.done || []),
    excused: new Set(data.excused || []),
  };
  const byId: Record<string, Item> = {};
  const progress: Record<string, Progress> = {};
  for (const item of items) {
    byId[item.id] = item;
    progress[item.id] = itemProgress(item, look);
  }

  const startId =
    (data.selected && byId[data.selected] ? data.selected : null) ||
    suggested ||
    items[0]?.id;
  const [selectedId, setSelectedId] = useState(startId);
  const selected = byId[selectedId || ''] || items[0];
  const homeCategory = categories.find((cat) =>
    cat.items.includes(startId || ''),
  );
  const [open, setOpen] = useState<Record<string, boolean>>(
    homeCategory ? { [homeCategory.id]: true } : {},
  );

  // The server keeps the open item for the in-game highlight.
  useEffect(() => {
    if (startId && data.selected !== startId) act('select', { id: startId });
  }, []);

  const select = (id: string) => {
    setSelectedId(id);
    act('select', { id });
  };

  return (
    <Window title="Tutorials" width={640} height={480}>
      <Window.Content>
        <Stack vertical fill>
          <Stack.Item grow>
            <Stack fill>
              <Stack.Item width="205px">
                <Section fill scrollable>
                  {categories.map((cat) => {
                    const finished = cat.items.filter(
                      (id) => progress[id]?.complete,
                    ).length;
                    const isOpen = !!open[cat.id];
                    const holdsSuggested =
                      !!suggested && cat.items.includes(suggested);
                    return (
                      <Box key={cat.id} mb={0.5}>
                        <Box
                          className="Button Button--color--transparent"
                          px={0.5}
                          py={0.25}
                          style={{ display: 'block', cursor: 'pointer' }}
                          onClick={() =>
                            setOpen({ ...open, [cat.id]: !isOpen })
                          }
                        >
                          <Stack>
                            <Stack.Item>
                              <Icon
                                name={isOpen ? 'chevron-down' : 'chevron-right'}
                                color="label"
                                width="12px"
                              />
                            </Stack.Item>
                            <Stack.Item grow bold>
                              {cat.name}
                              {!isOpen && holdsSuggested ? (
                                <Icon name="star" color="yellow" ml={1} />
                              ) : null}
                            </Stack.Item>
                            <Stack.Item color="label">
                              {finished}/{cat.items.length}
                            </Stack.Item>
                          </Stack>
                        </Box>
                        {isOpen ? (
                          <Tabs vertical>
                            {cat.items.map((id) => {
                              const item = byId[id];
                              if (!item) return null;
                              return (
                                <Tabs.Tab
                                  key={id}
                                  selected={id === selected?.id}
                                  onClick={() => select(id)}
                                  pl={2}
                                >
                                  <Stack>
                                    <Stack.Item grow>
                                      {item.name}
                                      {id === suggested ? (
                                        <Icon
                                          name="star"
                                          color="yellow"
                                          ml={1}
                                        />
                                      ) : null}
                                    </Stack.Item>
                                    <Stack.Item>
                                      <ProgressMark progress={progress[id]} />
                                    </Stack.Item>
                                  </Stack>
                                </Tabs.Tab>
                              );
                            })}
                          </Tabs>
                        ) : null}
                      </Box>
                    );
                  })}
                </Section>
              </Stack.Item>
              <Stack.Item grow basis={0}>
                <Section
                  fill
                  scrollable
                  title={selected?.name}
                  buttons={
                    selected && selected.id === suggested ? (
                      <Box color="yellow">
                        <Icon name="star" mr={0.5} />
                        Next up
                      </Box>
                    ) : (
                      <Box color="label">
                        <ProgressMark progress={progress[selected?.id || '']} />
                      </Box>
                    )
                  }
                >
                  {selected ? (
                    <>
                      {selected.intro ? (
                        <Box mb={1.5} lineHeight={1.4}>
                          {selected.intro}
                        </Box>
                      ) : null}
                      <StepList
                        item={selected}
                        look={look}
                        notes={notes}
                        live={live}
                        guide={guide}
                      />
                    </>
                  ) : null}
                </Section>
              </Stack.Item>
            </Stack>
          </Stack.Item>
          <Stack.Item>
            <Stack>
              <Stack.Item>
                <Button.Checkbox
                  checked={!data.spawn_open}
                  onClick={() => act('toggle_spawn_open')}
                >
                  Don&apos;t open on spawn
                </Button.Checkbox>
              </Stack.Item>
              <Stack.Item>
                <Button.Checkbox
                  checked={!!data.highlights}
                  onClick={() => act('toggle_highlights')}
                >
                  Highlight objects
                </Button.Checkbox>
              </Stack.Item>
            </Stack>
          </Stack.Item>
        </Stack>
      </Window.Content>
    </Window>
  );
};

type Group = { route: string | null; routeName: string; steps: Step[] };

const groupSteps = (steps: Step[]) => {
  const groups: Group[] = [];
  for (const step of steps) {
    const last = groups[groups.length - 1];
    if (last && step.route && last.route === step.route) {
      last.steps.push(step);
    } else {
      groups.push({
        route: step.route,
        routeName: step.route_name || '',
        steps: [step],
      });
    }
  }
  return groups;
};

type StepListProps = {
  item: Item;
  look: Lookup;
  notes: Record<string, string>;
  live: Record<string, string>;
  guide: string | null;
};

/** Steps in order. Routes get a box with "OR" between them and go quiet once another route is done. */
const StepList = (props: StepListProps) => {
  const { item, look, notes, live, guide } = props;
  const groups = groupSteps(item.steps);
  const routeDone = (route: string) =>
    item.steps
      .filter((step) => step.route === route && !step.optional)
      .every((step) => look.done.has(step.key));
  const finishedRoute = routeIds(item.steps).find(routeDone);
  return (
    <Box>
      {groups.map((group, index) => {
        if (!group.route) {
          return group.steps.map((step) => (
            <StepRow
              key={step.key}
              step={step}
              done={look.done.has(step.key)}
              quiet={look.excused.has(step.key) && !notes[step.key]}
              note={notes[step.key]}
              live={live[step.key]}
              guided={step.key === guide}
            />
          ));
        }
        const previous = groups[index - 1];
        const isDone = finishedRoute === group.route;
        const quiet = !!finishedRoute && !isDone;
        return (
          <Box key={`${group.route}-${index}`}>
            {previous?.route ? (
              <Box
                color="label"
                textAlign="center"
                my={0.5}
                style={{ letterSpacing: '1px' }}
              >
                OR
              </Box>
            ) : null}
            <Box
              p={1}
              pb={0}
              mb={1}
              style={{
                border: `1px solid ${isDone ? 'rgba(92, 184, 92, 0.5)' : 'rgba(255, 255, 255, 0.12)'}`,
                borderRadius: '4px',
                opacity: quiet ? 0.45 : 1,
              }}
            >
              <Box bold mb={1} color={isDone ? 'good' : 'label'}>
                <Icon name={isDone ? 'check' : 'route'} mr={1} />
                {group.routeName}
                {quiet ? (
                  <Box as="span" ml={1} bold={false} italic>
                    not needed
                  </Box>
                ) : null}
              </Box>
              {group.steps.map((step) => (
                <StepRow
                  key={step.key}
                  step={step}
                  done={look.done.has(step.key)}
                  quiet={quiet}
                  note={notes[step.key]}
                  live={live[step.key]}
                  guided={step.key === guide}
                />
              ))}
            </Box>
          </Box>
        );
      })}
    </Box>
  );
};

type StepRowProps = {
  step: Step;
  done: boolean;
  quiet?: boolean;
  note?: string;
  /** Live state, shown while the step is undone. */
  live?: string;
  /** The outlines and in-window focus point at this step. */
  guided?: boolean;
};

const StepRow = (props: StepRowProps) => {
  const { step, done, quiet, note, live, guided } = props;
  return (
    <Stack mb={1.5} style={{ opacity: quiet ? 0.6 : 1 }}>
      <Stack.Item>
        <Icon
          name={done ? 'square-check' : quiet ? 'square-minus' : 'square'}
          color={done ? 'good' : 'label'}
          size={1.2}
        />
      </Stack.Item>
      <Stack.Item grow>
        <Box bold color={done ? 'label' : undefined}>
          {step.name}
          {guided && !done ? (
            <Icon name="location-crosshairs" color="green" ml={1} />
          ) : null}
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
        {!done && !!live ? (
          <Box
            color="teal"
            style={{
              overflowWrap: 'anywhere',
              display: '-webkit-box',
              WebkitLineClamp: 2,
              WebkitBoxOrient: 'vertical',
              overflow: 'hidden',
            }}
          >
            {live}
          </Box>
        ) : null}
      </Stack.Item>
    </Stack>
  );
};
