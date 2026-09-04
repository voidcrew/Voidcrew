import { useBackend } from '../../tgui/backend';
import {
  Button,
  Divider,
  LabeledList,
  Section,
  Table,
} from 'tgui-core/components';
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
    is_crew,
    has_captain,
    election_running,
    election_cooldown = 0,
    can_call_election,
  } = data;

  return (
    <Section title={'Cryo Management'}>
      <LabeledList>
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
      {!!is_crew && (
        <Section title="Ship Command">
          <Button
            content={election_running ? 'Election Running' : 'Call an Election'}
            icon="crown"
            color={can_call_election ? 'good' : undefined}
            disabled={!can_call_election}
            onClick={() => act('callElection')}
          />
          <div style={{ marginTop: '4px', opacity: 0.7 }}>
            {election_running
              ? 'A vote is under way. Answer the prompt to cast your vote.'
              : has_captain
                ? 'This ship has a captain. An election can only be called when there is nobody left able to run it.'
                : election_cooldown > 0
                  ? 'The last election failed. Another can be called in ' +
                    election_cooldown +
                    's.'
                  : 'No captain is able to run this ship. Calling an election nominates you; the rest of the crew get 45 seconds to vote.'}
          </div>
        </Section>
      )}
      <Divider />
      {cooldown > 0 && (
        <div className="NoticeBox">{'On Cooldown: ' + cooldown / 10 + 's'}</div>
      )}
      <Table>
        <Table.Row header>
          <Table.Cell>Job Name</Table.Cell>
          <Table.Cell>Slots</Table.Cell>
        </Table.Row>
        {jobs.map((job) => (
          <Table.Row key={job.name}>
            <Table.Cell>{job.name}</Table.Cell>
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
        ))}
      </Table>
    </Section>
  );
};
