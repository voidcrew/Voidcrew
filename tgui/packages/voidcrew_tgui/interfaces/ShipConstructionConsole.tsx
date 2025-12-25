import { useBackend } from '../../tgui/backend';
import {
  Button,
  LabeledList,
  NoticeBox,
  Section,
  Stack,
  Table,
} from 'tgui-core/components';
import { Window } from '../../tgui/layouts';

interface AirlockData {
  name: string;
  ref: string;
  x: number;
  y: number;
  isCurrent: boolean;
  areaName: string;
}

interface PortData {
  x: number;
  y: number;
  dir: string;
  port_direction: string;
}

interface Data {
  canOperate: boolean;
  shipState: string;
  shipName: string;
  isNotCrew: boolean;
  lastMessage: string;
  lastSuccess: boolean;
  currentPort: PortData | null;
  airlocks: AirlockData[];
}

export const ShipConstructionConsole = () => {
  const { act, data } = useBackend<Data>();
  const {
    canOperate,
    shipState,
    shipName,
    isNotCrew,
    lastMessage,
    lastSuccess,
    currentPort,
    airlocks,
  } = data;

  return (
    <Window width={550} height={500} title="Ship Construction Console">
      <Window.Content scrollable>
        <Stack vertical fill>
          {/* Status Section */}
          <Stack.Item>
            <Section title={shipName || 'Ship Construction Console'}>
              <LabeledList>
                <LabeledList.Item label="Ship Status">
                  {shipState === 'idle' ? 'Docked' : 'In Flight'}
                </LabeledList.Item>
                <LabeledList.Item label="Console Status">
                  {canOperate ? 'Ready' : 'Operations Unavailable'}
                </LabeledList.Item>
              </LabeledList>
            </Section>
          </Stack.Item>

          {/* Crew Authorization Warning */}
          {!!isNotCrew && (
            <Stack.Item>
              <NoticeBox danger>CREW AUTHORIZATION REQUIRED</NoticeBox>
            </Stack.Item>
          )}

          {/* Cannot Operate Warning */}
          {!canOperate && !isNotCrew && (
            <Stack.Item>
              <NoticeBox warning>
                Ship must be docked to perform construction operations.
              </NoticeBox>
            </Stack.Item>
          )}

          {/* Operation Status Message */}
          {!!lastMessage && (
            <Stack.Item>
              <NoticeBox success={lastSuccess} danger={!lastSuccess}>
                {lastMessage}
                <Button
                  icon="times"
                  ml={1}
                  onClick={() => act('clear_message')}
                />
              </NoticeBox>
            </Stack.Item>
          )}

          {/* Current Docking Port Info */}
          <Stack.Item>
            <Section title="Current Docking Port">
              {currentPort ? (
                <LabeledList>
                  <LabeledList.Item label="Position">
                    ({currentPort.x}, {currentPort.y})
                  </LabeledList.Item>
                  <LabeledList.Item label="Direction">
                    {currentPort.dir}
                  </LabeledList.Item>
                </LabeledList>
              ) : (
                <NoticeBox>No docking port detected</NoticeBox>
              )}
            </Section>
          </Stack.Item>

          {/* Docking Port Relocation */}
          <Stack.Item grow>
            <Section title="Docking Port Relocation" fill scrollable>
              <Table>
                <Table.Row header>
                  <Table.Cell>Airlock</Table.Cell>
                  <Table.Cell>Area</Table.Cell>
                  <Table.Cell>Position</Table.Cell>
                  <Table.Cell>Action</Table.Cell>
                </Table.Row>
                {airlocks.map((airlock) => (
                  <Table.Row
                    key={airlock.ref}
                    className={airlock.isCurrent ? 'Table__row--selected' : ''}
                  >
                    <Table.Cell>
                      {airlock.name}
                      {airlock.isCurrent && ' (Current)'}
                    </Table.Cell>
                    <Table.Cell>{airlock.areaName}</Table.Cell>
                    <Table.Cell>
                      ({airlock.x}, {airlock.y})
                    </Table.Cell>
                    <Table.Cell>
                      <Button
                        icon="crosshairs"
                        content="Set as Dock"
                        disabled={!canOperate || isNotCrew || airlock.isCurrent}
                        onClick={() =>
                          act('relocate_port', {
                            airlock_ref: airlock.ref,
                          })
                        }
                      />
                    </Table.Cell>
                  </Table.Row>
                ))}
                {airlocks.length === 0 && (
                  <Table.Row>
                    <Table.Cell colSpan={4}>
                      <NoticeBox>
                        No valid edge airlocks found on this ship.
                      </NoticeBox>
                    </Table.Cell>
                  </Table.Row>
                )}
              </Table>
            </Section>
          </Stack.Item>

          {/* Future Features Placeholder */}
          <Stack.Item>
            <Section title="Additional Features">
              <NoticeBox info>
                Additional construction features coming soon.
              </NoticeBox>
            </Section>
          </Stack.Item>
        </Stack>
      </Window.Content>
    </Window>
  );
};
