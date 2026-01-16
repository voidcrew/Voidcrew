import { useBackend } from '../../tgui/backend';
import { Button, LabeledList, NoticeBox, ProgressBar, Section, Table } from 'tgui-core/components';
import { Window } from '../../tgui/layouts';

type HailingPirateInfo = {
  ref: string;
  name: string;
  faction: string;
  distance: number;
};

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
  demanded_credits: number;
  demanded_item: string;
  demanded_quantity: number;
  items_received: number;
  state: string;
};

type ShipCommsData = {
  linked_ship: string | null;
  has_negotiation: boolean;
  negotiation: NegotiationInfo | null;
  hailing_pirates: HailingPirateInfo[];
  hailable_pirates: PirateInfo[];
};

export const ShipComms = (props) => {
  const { act, data } = useBackend<ShipCommsData>();
  const {
    linked_ship,
    has_negotiation,
    negotiation,
    hailing_pirates = [],
    hailable_pirates = [],
  } = data;

  return (
    <Window width={450} height={500} title="Ship Communications">
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
              ) : hailing_pirates.length > 0 ? (
                <span style={{ color: 'red', fontWeight: 'bold' }}>
                  INCOMING HAIL
                </span>
              ) : (
                <span style={{ color: 'green' }}>Ready</span>
              )}
            </LabeledList.Item>
          </LabeledList>
        </Section>

        {/* Incoming Hails - TOP PRIORITY */}
        {!has_negotiation && hailing_pirates.length > 0 && (
          <Section
            title="INCOMING TRANSMISSION"
            buttons={
              <span style={{ color: 'red', fontWeight: 'bold' }}>
                ANSWER NOW
              </span>
            }
          >
            <NoticeBox danger>
              A hostile vessel is hailing you! Answer before they open fire!
            </NoticeBox>
            <Table mt={1}>
              <Table.Row header>
                <Table.Cell>Ship</Table.Cell>
                <Table.Cell>Faction</Table.Cell>
                <Table.Cell>Distance</Table.Cell>
                <Table.Cell>Action</Table.Cell>
              </Table.Row>
              {hailing_pirates.map((pirate) => (
                <Table.Row key={pirate.ref}>
                  <Table.Cell>{pirate.name}</Table.Cell>
                  <Table.Cell>{pirate.faction}</Table.Cell>
                  <Table.Cell>{pirate.distance}</Table.Cell>
                  <Table.Cell>
                    <Button
                      icon="phone"
                      color="green"
                      onClick={() => act('answer', { ref: pirate.ref })}
                    >
                      Answer
                    </Button>
                  </Table.Cell>
                </Table.Row>
              ))}
            </Table>
          </Section>
        )}

        {/* Active Negotiation */}
        {has_negotiation && negotiation && (
          <Section title="Active Negotiation">
            <LabeledList>
              <LabeledList.Item label="Speaking With">
                {negotiation.pirate_name}
              </LabeledList.Item>
              <LabeledList.Item label="Faction">
                {negotiation.faction}
              </LabeledList.Item>
              <LabeledList.Item label="Credit Demand">
                {negotiation.demanded_credits} cr
              </LabeledList.Item>
              {negotiation.demanded_item && (
                <LabeledList.Item label="Item Demand">
                  {negotiation.demanded_quantity} {negotiation.demanded_item}
                </LabeledList.Item>
              )}
              {negotiation.demanded_item && negotiation.items_received > 0 && (
                <LabeledList.Item label="Items Delivered">
                  {negotiation.items_received} / {negotiation.demanded_quantity}
                </LabeledList.Item>
              )}
            </LabeledList>

            {negotiation.demanded_item && (
              <ProgressBar
                value={negotiation.items_received}
                maxValue={negotiation.demanded_quantity}
                color={negotiation.items_received >= negotiation.demanded_quantity ? 'green' : 'yellow'}
                mt={1}
              >
                Item Progress: {negotiation.items_received} / {negotiation.demanded_quantity}
              </ProgressBar>
            )}

            <NoticeBox info mt={1}>
              Click the hologram to pay credits or deliver items.
              Place items on the mission pad if paying with goods.
            </NoticeBox>

            <NoticeBox warning mt={1}>
              WARNING: Moving your ship will end negotiations and provoke an attack!
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

        {/* Other Hostile Vessels */}
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
            ) : hailing_pirates.length === 0 ? (
              <NoticeBox info>No hostile ships in range to hail.</NoticeBox>
            ) : null}
          </Section>
        )}
      </Window.Content>
    </Window>
  );
};
