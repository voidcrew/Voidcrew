import { toTitleCase } from 'tgui-core/string'
import { useBackend } from '../../tgui/backend';
import { Button, Section, Table } from 'tgui-core/components';
import { Window } from '../../tgui/layouts';

type Data = {
  crates: Crates[];
};

type Crates = {
  name: string;
  ref: string;
};

export const ShippingContainer = (props) => {
  const { act, data } = useBackend<Data>();
  const { crates } = data;

  return (
    <Window width={335} height={415}>
      <Window.Content scrollable>
        <Section title="Crates">
          <Table>
            {crates.map((crate) => (
              <Table.Row key={crate.ref}>
                <Button
                  content={toTitleCase(crate.name)}
                  onClick={() =>
                    act('remove', {
                      ref: crate.ref,
                    })
                  }
                />
              </Table.Row>
            ))}
          </Table>
        </Section>
      </Window.Content>
    </Window>
  );
};
