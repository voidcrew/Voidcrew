import { useBackend } from '../../tgui/backend';
import { Button, LabeledList, NoticeBox, ProgressBar, Section, Table } from 'tgui-core/components';
import { Window } from '../../tgui/layouts';

type PirateInfo = {
  ref: string;
  name: string;
  faction: string;
  targeting: boolean;
  distance: number;
};

type NegotiationInfo = {
  pirate_name: string;
  faction: string;
  demanded: number;
  remaining: number;
  progress: number;
  state: string;
};

type ShipCommsData = {
  linked_ship: string | null;
  has_negotiation: boolean;
  negotiation: NegotiationInfo | null;
  hailable_pirates: PirateInfo[];
};

export const ShipComms = (props) => {
  const { act, data } = useBackend<ShipCommsData>();
  const { linked_ship, has_negotiation, negotiation, hailable_pirates } = data;

  return (
    <Window width={450} height={400} title="Ship Communications">
      <Window.Content>
        <Section title="Ship Status">
          <LabeledList>
            <LabeledList.Item label="Linked Ship">
              {linked_ship || 'Not linked'}
            </LabeledList.Item>
            <LabeledList.Item label="Comms Status">
              {has_negotiation ? (
                <span style={{ color: 'orange', fontWeight: 'bold' }}>
                  ACTIVE NEGOTIATION
                </span>
              ) : (
                <span style={{ color: 'green' }}>Ready</span>
              )}
            </LabeledList.Item>
          </LabeledList>
        </Section>

        {has_negotiation && negotiation && (
          <Section title="Active Negotiation">
            <LabeledList>
              <LabeledList.Item label="Hailing">
                {negotiation.pirate_name}
              </LabeledList.Item>
              <LabeledList.Item label="Faction">
                {negotiation.faction}
              </LabeledList.Item>
              <LabeledList.Item label="Demanded">
                {negotiation.demanded} cr
              </LabeledList.Item>
              <LabeledList.Item label="Remaining">
                {negotiation.remaining} cr
              </LabeledList.Item>
            </LabeledList>

            <ProgressBar
              value={negotiation.progress}
              maxValue={100}
              color={negotiation.progress >= 100 ? 'green' : 'yellow'}
              mt={1}
            >
              Payment Progress: {Math.round(negotiation.progress)}%
            </ProgressBar>

            <NoticeBox info mt={1}>
              Click the hologram or use the radial menu to negotiate.
              Place tribute on the mission pad to make payments.
            </NoticeBox>

            <Button
              icon="phone-slash"
              color="red"
              onClick={() => act('end_comms')}
              mt={1}
              fluid
            >
              End Communication
            </Button>
          </Section>
        )}

        {!has_negotiation && (
          <Section title="Hostile Vessels">
            {hailable_pirates.length > 0 ? (
              <Table>
                <Table.Row header>
                  <Table.Cell>Ship</Table.Cell>
                  <Table.Cell>Faction</Table.Cell>
                  <Table.Cell>Distance</Table.Cell>
                  <Table.Cell>Status</Table.Cell>
                  <Table.Cell>Action</Table.Cell>
                </Table.Row>
                {hailable_pirates.map((pirate) => (
                  <Table.Row key={pirate.ref}>
                    <Table.Cell>{pirate.name}</Table.Cell>
                    <Table.Cell>{pirate.faction}</Table.Cell>
                    <Table.Cell>{pirate.distance}</Table.Cell>
                    <Table.Cell>
                      {pirate.targeting ? (
                        <span style={{ color: 'red' }}>TARGETING</span>
                      ) : (
                        <span style={{ color: 'orange' }}>Hostile</span>
                      )}
                    </Table.Cell>
                    <Table.Cell>
                      <Button
                        icon="phone"
                        color="yellow"
                        onClick={() => act('hail', { ref: pirate.ref })}
                      >
                        Hail
                      </Button>
                    </Table.Cell>
                  </Table.Row>
                ))}
              </Table>
            ) : (
              <NoticeBox info>
                No hostile ships in range to hail.
              </NoticeBox>
            )}
          </Section>
        )}
      </Window.Content>
    </Window>
  );
};
