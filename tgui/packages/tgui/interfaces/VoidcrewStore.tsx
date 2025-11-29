import { useBackend, useSharedState } from '../backend';
import {
  Box,
  Button,
  DmIcon,
  Icon,
  Section,
  Stack,
  Table,
  Tabs,
} from 'tgui-core/components';
import { Window } from '../layouts';

type StoreItem = {
  name: string;
  path: string;
  cost: number;
  desc: string;
  icon?: string;
  icon_state?: string;
};

type StoreTab = {
  name: string;
  title: string;
  contents: StoreItem[];
};

type VoidcrewStoreData = {
  loadout_tabs: StoreTab[];
  owned_items: string[];
  total_coins: number;
};

export const VoidcrewStore = (props) => {
  const { act, data } = useBackend<VoidcrewStoreData>();
  const { loadout_tabs, total_coins, owned_items } = data;

  const [selectedTabName, setSelectedTab] = useSharedState(
    'tabs',
    loadout_tabs[0]?.name,
  );
  const selectedTab = loadout_tabs.find(
    (curTab) => curTab.name === selectedTabName,
  );

  return (
    <Window title="Voidcrew Store" width={900} height={500}>
      <Window.Content>
        <Stack fill vertical>
          <Stack.Item>
            <Section
              title="Store Categories"
              align="center"
              buttons={
                <Box color="gold">
                  <Button
                    icon="fa-solid fa-coins"
                    content={total_coins}
                    tooltip="Your total credits"
                    backgroundColor="transparent"
                    color="gold"
                  />
                </Box>
              }
            >
              <Tabs>
                {loadout_tabs.map((curTab) => (
                  <Tabs.Tab
                    key={curTab.name}
                    selected={selectedTabName === curTab.name}
                    onClick={() => setSelectedTab(curTab.name)}
                  >
                    {curTab.name}
                  </Tabs.Tab>
                ))}
              </Tabs>
            </Section>
          </Stack.Item>
          <Stack.Item grow>
            <Section
              title={selectedTab?.title || 'Store Items'}
              fill
              scrollable
            >
              <Table>
                <Table.Row header>
                  <Table.Cell style={{ width: '5%' }}>Icon</Table.Cell>
                  <Table.Cell style={{ width: '65%' }}>Name</Table.Cell>
                  <Table.Cell style={{ width: '15%', textAlign: 'right' }}>
                    Cost
                  </Table.Cell>
                  <Table.Cell style={{ width: '15%', textAlign: 'right' }}>
                    Purchase
                  </Table.Cell>
                </Table.Row>
                {selectedTab && selectedTab.contents ? (
                  selectedTab.contents.map((item, index) => (
                    <Table.Row
                      key={item.path}
                      backgroundColor={index % 2 === 0 ? '#19181e' : '#16151b'}
                    >
                      <Table.Cell>
                        {item.icon && item.icon_state ? (
                          <DmIcon
                            icon={item.icon}
                            icon_state={item.icon_state}
                            verticalAlign="middle"
                            height="32px"
                            width="32px"
                            fallback={<Icon name="spinner" size={2} spin />}
                          />
                        ) : (
                          <Box
                            inline
                            verticalAlign="middle"
                            width="32px"
                            height="32px"
                          >
                            <Icon name="question" size={2} />
                          </Box>
                        )}
                      </Table.Cell>
                      <Table.Cell>
                        <Box tooltip={item.desc}>{item.name}</Box>
                      </Table.Cell>
                      <Table.Cell style={{ textAlign: 'right' }}>
                        <Box display="flex" justifyContent="flex-end">
                          <Button
                            icon="fa-solid fa-coins"
                            backgroundColor="transparent"
                            color="gold"
                            content={item.cost}
                          />
                        </Box>
                      </Table.Cell>
                      <Table.Cell style={{ textAlign: 'right' }}>
                        <Box display="flex" justifyContent="flex-end">
                          <Button.Confirm
                            content={
                              owned_items.includes(item.path)
                                ? 'Owned'
                                : 'Purchase'
                            }
                            disabled={
                              owned_items.includes(item.path) ||
                              total_coins < item.cost
                            }
                            onClick={() =>
                              act('select_item', {
                                path: item.path,
                              })
                            }
                          />
                        </Box>
                      </Table.Cell>
                    </Table.Row>
                  ))
                ) : (
                  <Table.Row>
                    <Table.Cell colSpan={4} align="center">
                      <Box>No items available in this category.</Box>
                    </Table.Cell>
                  </Table.Row>
                )}
              </Table>
            </Section>
          </Stack.Item>
        </Stack>
      </Window.Content>
    </Window>
  );
};
