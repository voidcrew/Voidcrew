import { map } from 'es-toolkit/compat';
import { useBackend, useSharedState } from '../../tgui/backend';
import {
  Box,
  Button,
  Collapsible,
  Dropdown,
  Flex,
  Input,
  LabeledList,
  NoticeBox,
  NumberInput,
  Section,
  Stack,
  Tabs,
} from 'tgui-core/components';
import { Window } from '../../tgui/layouts';

export const NaniteCodes = (props, context) => {
  const { program, program_id } = props;
  const { act } = useBackend(context);
  return (
    <Section title="Codes" level={3} mr={1}>
      <LabeledList>
        <LabeledList.Item label="Activation">
          <NumberInput
            value={program.activation_code}
            width="47px"
            minValue={0}
            maxValue={9999}
            step={1}
            onChange={(value) =>
              act('set_code', {
                target_code: 'activation',
                code: value,
                program_id,
              })
            }
          />
        </LabeledList.Item>
        <LabeledList.Item label="Deactivation">
          <NumberInput
            value={program.deactivation_code}
            width="47px"
            minValue={0}
            maxValue={9999}
            step={1}
            onChange={(value) =>
              act('set_code', {
                target_code: 'deactivation',
                code: value,
                program_id,
              })
            }
          />
        </LabeledList.Item>
        <LabeledList.Item label="Kill">
          <NumberInput
            value={program.kill_code}
            width="47px"
            minValue={0}
            maxValue={9999}
            step={1}
            onChange={(value) =>
              act('set_code', {
                target_code: 'kill',
                code: value,
                program_id,
              })
            }
          />
        </LabeledList.Item>
        {!!program.can_trigger && (
          <LabeledList.Item label="Trigger">
            <NumberInput
              value={program.trigger_code}
              width="47px"
              minValue={0}
              maxValue={9999}
              step={1}
              onChange={(value) =>
                act('set_code', {
                  target_code: 'trigger',
                  code: value,
                  program_id,
                })
              }
            />
          </LabeledList.Item>
        )}
      </LabeledList>
    </Section>
  );
};

export const NaniteDelays = (props, context) => {
  const { program, program_id } = props;
  const { act } = useBackend(context);

  return (
    <Section title="Delays" level={3} ml={1}>
      <LabeledList>
        <LabeledList.Item label="Restart Timer">
          <NumberInput
            value={program.timer_restart}
            unit="s"
            width="57px"
            minValue={0}
            maxValue={3600}
            step={1}
            onChange={(value) =>
              act('set_restart_timer', {
                delay: value,
                program_id,
              })
            }
          />
        </LabeledList.Item>
        <LabeledList.Item label="Shutdown Timer">
          <NumberInput
            value={program.timer_shutdown}
            unit="s"
            width="57px"
            minValue={0}
            maxValue={3600}
            step={1}
            onChange={(value) =>
              act('set_shutdown_timer', {
                delay: value,
                program_id,
              })
            }
          />
        </LabeledList.Item>
        {!!program.can_trigger && (
          <>
            <LabeledList.Item label="Trigger Repeat Timer">
              <NumberInput
                value={program.timer_trigger}
                unit="s"
                width="57px"
                minValue={0}
                maxValue={3600}
                step={1}
                onChange={(value) =>
                  act('set_trigger_timer', {
                    delay: value,
                    program_id,
                  })
                }
              />
            </LabeledList.Item>
            <LabeledList.Item label="Trigger Delay">
              <NumberInput
                value={program.timer_trigger_delay}
                unit="s"
                width="57px"
                minValue={0}
                maxValue={3600}
                step={1}
                onChange={(value) =>
                  act('set_timer_trigger_delay', {
                    delay: value,
                    program_id,
                  })
                }
              />
            </LabeledList.Item>
          </>
        )}
      </LabeledList>
    </Section>
  );
};

export const NaniteExtraEntry = (props, context) => {
  const { extra_setting, program_id } = props;
  const { name, type } = extra_setting;
  const typeComponentMap = {
    number: (
      <NaniteExtraNumber extra_setting={extra_setting} program_id={program_id} />
    ),
    text: (
      <NaniteExtraText extra_setting={extra_setting} program_id={program_id} />
    ),
    type: (
      <NaniteExtraType extra_setting={extra_setting} program_id={program_id} />
    ),
    boolean: (
      <NaniteExtraBoolean
        extra_setting={extra_setting}
        program_id={program_id}
      />
    ),
  };
  return (
    <LabeledList.Item label={name}>{typeComponentMap[type]}</LabeledList.Item>
  );
};

export const NaniteExtraNumber = (props, context) => {
  const { extra_setting, program_id } = props;
  const { act } = useBackend(context);
  const { name, value, min, max, unit } = extra_setting;
  return (
    <NumberInput
      value={value}
      width="64px"
      minValue={min}
      maxValue={max}
      step={1}
      unit={unit}
      onChange={(val) =>
        act('set_extra_setting', {
          target_setting: name,
          value: val,
          program_id,
        })
      }
    />
  );
};

export const NaniteExtraText = (props, context) => {
  const { extra_setting, program_id } = props;
  const { act } = useBackend(context);
  const { name, value } = extra_setting;
  const setText = (val) =>
    act('set_extra_setting', {
      target_setting: name,
      value: val,
      program_id,
    });
  // Cloud programs sync to their hosts, so only commit the finished text
  if (program_id) {
    return (
      <Input
        value={value}
        width="200px"
        onBlur={(val) => val !== value && setText(val)}
      />
    );
  }
  return <Input value={value} width="200px" onChange={setText} />;
};

export const NaniteExtraType = (props, context) => {
  const { extra_setting, program_id } = props;
  const { act } = useBackend(context);
  const { name, value, types } = extra_setting;
  return (
    <Dropdown
      over
      selected={value}
      width="150px"
      options={types}
      onSelected={(val) =>
        act('set_extra_setting', {
          target_setting: name,
          value: val,
          program_id,
        })
      }
    />
  );
};

export const NaniteExtraBoolean = (props, context) => {
  const { extra_setting, program_id } = props;
  const { act } = useBackend(context);
  const { name, value, true_text, false_text } = extra_setting;
  return (
    <Button.Checkbox
      content={value ? true_text : false_text}
      checked={value}
      onClick={() =>
        act('set_extra_setting', {
          target_setting: name,
          program_id,
        })
      }
    />
  );
};

export const NaniteProgrammerContent = (props, context) => {
  const { act, data } = useBackend(context);
  const {
    has_program,
    name,
    desc,
    use_rate,
    can_trigger,
    trigger_cost,
    trigger_cooldown,
    activated,
    has_extra_settings,
    extra_settings = {},
  } = data;
  if (!has_program) {
    return (
      <Section title="Program" fill>
        <NoticeBox textAlign="center">Download a nanite program</NoticeBox>
      </Section>
    );
  }
  return (
    <Section title={name} fill scrollable>
      <Section title="Info" level={2}>
        <Flex>
          <Flex.Item>{desc}</Flex.Item>
          <Flex.Item size={0.7}>
            <LabeledList>
              <LabeledList.Item label="Use Rate">{use_rate}</LabeledList.Item>
              {!!can_trigger && (
                <>
                  <LabeledList.Item label="Trigger Cost">
                    {trigger_cost}
                  </LabeledList.Item>
                  <LabeledList.Item label="Trigger Cooldown">
                    {trigger_cooldown}
                  </LabeledList.Item>
                </>
              )}
            </LabeledList>
          </Flex.Item>
        </Flex>
      </Section>
      <Section
        title="Settings"
        level={2}
        buttons={
          <Button
            icon={activated ? 'power-off' : 'times'}
            content={activated ? 'Active' : 'Inactive'}
            selected={activated}
            color="bad"
            bold
            onClick={() => act('toggle_active')}
          />
        }>
        <Flex>
          <Flex.Item>
            <NaniteCodes program={data} />
          </Flex.Item>
          <Flex.Item>
            <NaniteDelays program={data} />
          </Flex.Item>
        </Flex>
        {!!has_extra_settings && (
          <Section title="Special" level={3}>
            <LabeledList>
              {extra_settings.map((setting) => (
                <NaniteExtraEntry key={setting.name} extra_setting={setting} />
              ))}
            </LabeledList>
          </Section>
        )}
      </Section>
    </Section>
  );
};

export const NaniteInfoBox = (props, context) => {
  const { program } = props;
  const { act } = useBackend(context);
  const {
    id,
    name,
    desc,
    activated,
    use_rate,
    can_trigger,
    trigger_cost,
    trigger_cooldown,
    has_extra_settings,
  } = program;
  const extra_settings = program.extra_settings || [];
  return (
    <Section
      title={name}
      level={2}
      buttons={
        <Button
          icon={activated ? 'power-off' : 'times'}
          content={activated ? 'Active' : 'Inactive'}
          selected={activated}
          color="bad"
          bold
          onClick={() =>
            act('toggle_active', {
              program_id: id,
            })
          }
        />
      }>
      <Flex>
        <Flex.Item mr={1}>{desc}</Flex.Item>
        <Flex.Item size={0.5}>
          <LabeledList>
            <LabeledList.Item label="Use Rate">{use_rate}</LabeledList.Item>
            {!!can_trigger && (
              <>
                <LabeledList.Item label="Trigger Cost">
                  {trigger_cost}
                </LabeledList.Item>
                <LabeledList.Item label="Trigger Cooldown">
                  {trigger_cooldown}
                </LabeledList.Item>
              </>
            )}
          </LabeledList>
        </Flex.Item>
      </Flex>
      <Flex wrap="wrap">
        <Flex.Item>
          <NaniteCodes program={program} program_id={id} />
        </Flex.Item>
        <Flex.Item>
          <NaniteDelays program={program} program_id={id} />
        </Flex.Item>
      </Flex>
      {!!has_extra_settings && (
        <Section title="Extra Settings" level={3}>
          <LabeledList>
            {extra_settings.map((setting) => (
              <NaniteExtraEntry
                key={setting.name}
                extra_setting={setting}
                program_id={id}
              />
            ))}
          </LabeledList>
        </Section>
      )}
    </Section>
  );
};

export const NaniteCloudBackupList = (props, context) => {
  const { act, data } = useBackend(context);
  const cloud_backups = data.cloud_backups || [];
  return cloud_backups.map((backup) => (
    <Button
      fluid
      key={backup.cloud_id}
      content={'Backup #' + backup.cloud_id}
      textAlign="center"
      onClick={() =>
        act('set_view', {
          view: backup.cloud_id,
        })
      }
    />
  ));
};

export const NaniteCloudBackupDetails = (props, context) => {
  const { act, data } = useBackend(context);
  const { current_view, can_rule, has_program, cloud_backup } = data;
  if (!cloud_backup) {
    return <NoticeBox>ERROR: Backup not found</NoticeBox>;
  }
  const cloud_programs = data.cloud_programs || [];
  return (
    <Section
      title={'Backup #' + current_view}
      level={2}
      buttons={
        !!has_program && (
          <Button
            icon="upload"
            content="Upload Program from Programmer"
            color="good"
            onClick={() => act('upload_program')}
          />
        )
      }>
      {cloud_programs.map((program) => {
        const rules = program.rules || [];
        return (
          <Collapsible
            key={program.name}
            title={program.name}
            buttons={
              <Button
                icon="minus-circle"
                color="bad"
                onClick={() =>
                  act('remove_program', {
                    program_id: program.id,
                  })
                }
              />
            }>
            <Section>
              <NaniteInfoBox program={program} />
              {(!!can_rule || !!program.has_rules) && (
                <Section
                  mt={-2}
                  title="Rules"
                  level={2}
                  buttons={
                    <>
                      {!!can_rule && (
                        <Button
                          icon="plus"
                          content="Add Rule from Programmer"
                          color="good"
                          onClick={() =>
                            act('add_rule', {
                              program_id: program.id,
                            })
                          }
                        />
                      )}
                      <Button
                        icon={
                          program.all_rules_required ? 'check-double' : 'check'
                        }
                        content={
                          program.all_rules_required ? 'Meet all' : 'Meet any'
                        }
                        onClick={() =>
                          act('toggle_rule_logic', {
                            program_id: program.id,
                          })
                        }
                      />
                    </>
                  }>
                  {program.has_rules ? (
                    rules.map((rule) => (
                      <Box key={rule.display}>
                        <Button
                          icon="minus-circle"
                          color="bad"
                          onClick={() =>
                            act('remove_rule', {
                              program_id: program.id,
                              rule_id: rule.id,
                            })
                          }
                        />
                        {` ${rule.display}`}
                      </Box>
                    ))
                  ) : (
                    <Box color="bad">No Active Rules</Box>
                  )}
                </Section>
              )}
            </Section>
          </Collapsible>
        );
      })}
    </Section>
  );
};

export const NaniteProgramHub = (props, context) => {
  const { act, data } = useBackend(context);
  const { detail_view, has_techweb, programs = {} } = data;
  const [selectedCategory, setSelectedCategory] = useSharedState('category');
  const programsInCategory = (programs && programs[selectedCategory]) || [];
  return (
    <Section
      title="Programs"
      fill
      scrollable
      buttons={
        <>
          <Button
            icon={detail_view ? 'info' : 'list'}
            content={detail_view ? 'Detailed' : 'Compact'}
            onClick={() => act('toggle_details')}
          />
          <Button
            icon="sync"
            content="Sync Research"
            onClick={() => act('refresh')}
          />
        </>
      }
    >
      {!has_techweb ? (
        <NoticeBox>
          No research server linked. Link one with a multitool to download
          programs.
        </NoticeBox>
      ) : programs !== null ? (
        <Flex>
          <Flex.Item minWidth="110px">
            <Tabs vertical>
              {map(programs, (cat_contents, category) => {
                // Categories arrive as RND paths ("/Nanites/Utility Nanites");
                // show just the subcategory word
                const tabLabel = category
                  .split('/')
                  .pop()
                  .replace(/ Nanites$/, '');
                return (
                  <Tabs.Tab
                    key={category}
                    selected={category === selectedCategory}
                    onClick={() => setSelectedCategory(category)}
                  >
                    {tabLabel}
                  </Tabs.Tab>
                );
              })}
            </Tabs>
          </Flex.Item>
          <Flex.Item grow={1} basis={0}>
            {detail_view ? (
              programsInCategory.map((program) => (
                <Section
                  key={program.id}
                  title={program.name}
                  level={2}
                  buttons={
                    <Button
                      icon="download"
                      content="Download"
                      onClick={() =>
                        act('download', {
                          program_id: program.id,
                        })
                      }
                    />
                  }
                >
                  {program.desc}
                </Section>
              ))
            ) : (
              <LabeledList>
                {programsInCategory.map((program) => (
                  <LabeledList.Item
                    key={program.id}
                    label={program.name}
                    buttons={
                      <Button
                        icon="download"
                        content="Download"
                        onClick={() =>
                          act('download', {
                            program_id: program.id,
                          })
                        }
                      />
                    }
                  />
                ))}
              </LabeledList>
            )}
          </Flex.Item>
        </Flex>
      ) : (
        <NoticeBox>No nanite programs are currently researched.</NoticeBox>
      )}
    </Section>
  );
};

export const NaniteCloudControl = (props, context) => {
  const { act, data } = useBackend(context);
  const { has_disk, current_view, new_backup_id, ship_name } = data;
  return (
    <Window width={1295} height={700} resizable>
      <Window.Content>
        <Stack fill>
          <Stack.Item grow basis={0}>
            <NaniteProgramHub />
          </Stack.Item>
          <Stack.Item grow basis={0}>
            <NaniteProgrammerContent />
          </Stack.Item>
          <Stack.Item grow basis={0}>
            <Stack vertical fill>
              <Stack.Item>
                <Section
                  title="Backup Disk"
                  buttons={
                    <Button
                      icon="eject"
                      content="Eject"
                      disabled={!has_disk}
                      onClick={() => act('eject')}
                    />
                  }>
                  {!has_disk ? (
                    <NoticeBox>No disk inserted</NoticeBox>
                  ) : (
                    <>
                      <Button
                        content="Save from Cloud"
                        color="good"
                        disabled={!current_view}
                        tooltip="Saves the open cloud backup to the disk."
                        onClick={() => act('store_backup')}
                      />
                      <Button
                        content="Load to Cloud"
                        color="bad"
                        disabled={!current_view}
                        tooltip="Replaces the open cloud backup with the disk's."
                        onClick={() => act('load_backup')}
                      />
                    </>
                  )}
                </Section>
              </Stack.Item>
              <Stack.Item grow>
                <Section
                  title="Cloud Storage"
                  fill
                  scrollable
                  buttons={
                    current_view ? (
                      <Button
                        icon="arrow-left"
                        content="Return"
                        onClick={() =>
                          act('set_view', {
                            view: 0,
                          })
                        }
                      />
                    ) : (
                      <>
                        {'New Backup: '}
                        <NumberInput
                          value={new_backup_id}
                          minValue={1}
                          maxValue={100}
                          step={1}
                          stepPixelSize={4}
                          width="39px"
                          onChange={(value) =>
                            act('update_new_backup_value', {
                              value: value,
                            })
                          }
                        />
                        <Button
                          icon="plus"
                          onClick={() => act('create_backup')}
                        />
                      </>
                    )
                  }>
                  <NoticeBox info>
                    Cloud networks are local to {ship_name || 'this ship'}.
                    Nanites join a backup by having their cloud ID set in a
                    nanite chamber aboard this ship. Matching ID numbers on
                    other ships are separate, unrelated clouds.
                  </NoticeBox>
                  {!data.current_view ? (
                    <NaniteCloudBackupList />
                  ) : (
                    <NaniteCloudBackupDetails />
                  )}
                </Section>
              </Stack.Item>
            </Stack>
          </Stack.Item>
        </Stack>
      </Window.Content>
    </Window>
  );
};
