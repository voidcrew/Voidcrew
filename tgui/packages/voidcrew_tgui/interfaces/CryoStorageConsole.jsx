import { useBackend } from '../../tgui/backend';
import {
  Button,
  Divider,
  Dropdown,
  LabeledList,
  Section,
  Stack,
  Table,
} from 'tgui-core/components';
import { TableCell } from 'tgui-core/components/Table';
import { Window } from '../../tgui/layouts';

export const CryoStorageConsole = (props, context) => {
  return (
    <Window width={450} height={620} resizable>
      <Window.Content scrollable>
        <CryoStorageConsoleContent />
      </Window.Content>
    </Window>
  );
};

export const CryoStorageConsoleContent = (props, context) => {
  const { act, data } = useBackend(context);
  const {
    jobs = [],
    memo,
    awakening,
    cooldown = 1,
    customSlots = [],
    playerCredits = 0,
  } = data;

  // Helper function to get current slot display name
  const getCurrentSlotName = (job) => {
    if (!job.currentSwap || job.currentSwap === -1) {
      return `Default (${job.name})`;
    }
    const customSlot = customSlots.find((s) => s.index === job.currentSwap);
    return customSlot ? customSlot.name : `Default (${job.name})`;
  };

  // Helper function to get equipment cost for a custom slot
  const getEquipmentCost = (slotIndex) => {
    if (slotIndex === -1 || slotIndex === null || slotIndex === undefined) {
      return 0;
    }
    const customSlot = customSlots.find((s) => s.index === slotIndex);
    return customSlot?.equipmentCost || 0;
  };

  // Helper function to build dropdown options for a job
  const getSlotOptions = (job) => {
    const options = [`Default (${job.name})`];

    if (job.swapOptions && job.swapOptions.length > 0) {
      job.swapOptions.forEach((option) => {
        const customSlot = customSlots.find((s) => s.index === option.index);
        if (customSlot && customSlot.unlocked) {
          options.push(option.name);
        }
      });
    }

    return options;
  };

  // Helper function to get selected slot info
  const getSelectedSlotInfo = (job) => {
    if (!job.currentSwap || job.currentSwap === -1) {
      return null;
    }

    const customSlot = customSlots.find((s) => s.index === job.currentSwap);
    if (!customSlot) {
      return null;
    }

    return {
      accessPreset: customSlot.accessPreset,
      equipmentCost: customSlot.equipmentCost || 0,
    };
  };

  return (
    <Section title={'Cryo Management'}>
      <LabeledList>
        <LabeledList.Item label="Player Credits">
          <span style={{ color: '#90EE90', fontWeight: 'bold' }}>
            {playerCredits} CR
          </span>
        </LabeledList.Item>
        <LabeledList.Item label="Awakening Settings">
          <Button
            content={awakening ? 'Disable' : 'Enable'}
            icon="bed"
            color={awakening ? 'bad' : 'good'}
            onClick={() => act('toggleAwakening')}
          />
          <Button.Input
            content="Set Memo"
            currentValue={memo}
            onCommit={(e, value) =>
              act('setMemo', {
                newName: value,
              })
            }
          />
        </LabeledList.Item>
      </LabeledList>
      <Divider />
      {cooldown > 0 && (
        <div className="NoticeBox">{'On Cooldown: ' + cooldown / 10 + 's'}</div>
      )}
      <Table>
        <Table.Row header>
          <Table.Cell>Job Name</Table.Cell>
          <Table.Cell>Custom Slot</Table.Cell>
          <Table.Cell>Slots</Table.Cell>
        </Table.Row>
        {jobs.map((job) => {
          const slotInfo = getSelectedSlotInfo(job);
          const options = getSlotOptions(job);

          return (
            <Table.Row key={job.name}>
              <Table.Cell>{job.name}</Table.Cell>
              <Table.Cell>
                <Stack vertical>
                  <Stack.Item>
                    <Dropdown
                      width="180px"
                      options={options}
                      selected={getCurrentSlotName(job)}
                      onSelected={(value) => {
                        // Determine the slot index based on selection
                        let slotIndex = -1;

                        if (value !== `Default (${job.name})`) {
                          // Find the custom slot by name
                          const selectedOption = job.swapOptions?.find(
                            (opt) => opt.name === value
                          );
                          if (selectedOption) {
                            slotIndex = selectedOption.index;
                          }
                        }

                        act('swapCustomSlot', {
                          jobRef: job.ref,
                          slotIndex: slotIndex,
                        });
                      }}
                    />
                  </Stack.Item>
                  {slotInfo && (
                    <Stack.Item>
                      <span
                        style={{ fontSize: '0.85em', color: '#aaa', marginTop: '2px' }}
                      >
                        Access: {slotInfo.accessPreset || 'None'}
                        {slotInfo.equipmentCost > 0 && (
                          <span style={{ color: '#FFD700' }}>
                            {' '}
                            | Cost: {slotInfo.equipmentCost} CR
                          </span>
                        )}
                      </span>
                    </Stack.Item>
                  )}
                </Stack>
              </Table.Cell>
              <Table.Cell>
                <Button
                  content="+"
                  disabled={cooldown > 0 || job.slots >= job.max}
                  onClick={() =>
                    act('adjustJobSlot', {
                      toAdjust: job.ref,
                      delta: 1,
                    })
                  }
                />
                {job.slots}
                <Button
                  content="-"
                  disabled={cooldown > 0 || job.slots <= 0}
                  onClick={() =>
                    act('adjustJobSlot', {
                      toAdjust: job.ref,
                      delta: -1,
                    })
                  }
                />
              </Table.Cell>
            </Table.Row>
          );
        })}
      </Table>
    </Section>
  );
};
