import { useBackend, useSharedState } from '../../tgui/backend';
import {
  AnimatedNumber,
  Box,
  Button,
  Input,
  LabeledList,
  ProgressBar,
  RestrictedInput,
  Section,
  Stack,
  Table,
  Tabs,
} from 'tgui-core/components';
import { formatMoney } from 'tgui-core/format';
import { Window } from '../../tgui/layouts';
import { CargoCatalog } from '../../tgui/interfaces/Cargo/CargoCatalog';

// Shuttle state constants (must match DM defines)
const CARGO_SHUTTLE_AWAY = 0;
const CARGO_SHUTTLE_ARRIVING = 1;
const CARGO_SHUTTLE_DOCKED = 2;
const CARGO_SHUTTLE_DEPARTING = 3;

export const VoidcrewCargo = () => {
  return (
    <Window width={800} height={750}>
      <Window.Content scrollable>
        <VoidcrewCargoContent />
      </Window.Content>
    </Window>
  );
};

export const VoidcrewCargoContent = () => {
  const { data } = useBackend();
  const [tab, setTab] = useSharedState('tab', 'catalog');
  const { cart = [], supplies = {} } = data;
  const cart_length = cart.reduce((total, entry) => total + entry.amount, 0);
  const hasSupplies = Object.keys(supplies).length > 0;

  return (
    <Box>
      <VoidcrewCargoStatus />
      <Section fitted>
        <Tabs>
          <Tabs.Tab
            icon="list"
            selected={tab === 'catalog'}
            onClick={() => setTab('catalog')}
          >
            Catalog
          </Tabs.Tab>
          <Tabs.Tab
            icon="shopping-cart"
            textColor={tab !== 'cart' && cart_length > 0 && 'yellow'}
            selected={tab === 'cart'}
            onClick={() => setTab('cart')}
          >
            Checkout ({cart_length})
          </Tabs.Tab>
        </Tabs>
      </Section>
      {tab === 'catalog' &&
        (hasSupplies ? (
          <Section fill height="550px">
            <CargoCatalog />
          </Section>
        ) : (
          <Section>
            <Box color="bad">
              No supplies available. Make sure the cargo system is initialized.
            </Box>
          </Section>
        ))}
      {tab === 'cart' && <VoidcrewCargoCart />}
    </Box>
  );
};

const VoidcrewCargoStatus = () => {
  const { act, data } = useBackend();
  const {
    shuttle_state = CARGO_SHUTTLE_AWAY,
    shuttle_status = 'Away',
    shuttle_timer = 0,
    can_call_shuttle,
    shuttle_error,
    points,
  } = data;

  // Determine button text and state
  const getButtonText = () => {
    switch (shuttle_state) {
      case CARGO_SHUTTLE_AWAY:
        return 'Call Cargo Shuttle';
      case CARGO_SHUTTLE_ARRIVING:
        return `Arriving... (${shuttle_timer}s)`;
      case CARGO_SHUTTLE_DOCKED:
        return 'Send Cargo Shuttle';
      case CARGO_SHUTTLE_DEPARTING:
        return `Departing... (${shuttle_timer}s)`;
      default:
        return 'Cargo Shuttle';
    }
  };

  const getButtonColor = () => {
    switch (shuttle_state) {
      case CARGO_SHUTTLE_DOCKED:
        return 'green';
      case CARGO_SHUTTLE_ARRIVING:
      case CARGO_SHUTTLE_DEPARTING:
        return 'yellow';
      default:
        return 'blue';
    }
  };

  const isButtonDisabled = () => {
    // Disabled during transit or if can't call
    if (
      shuttle_state === CARGO_SHUTTLE_ARRIVING ||
      shuttle_state === CARGO_SHUTTLE_DEPARTING
    ) {
      return true;
    }
    if (shuttle_state === CARGO_SHUTTLE_AWAY && !can_call_shuttle) {
      return true;
    }
    return false;
  };

  return (
    <Section>
      <Box position="absolute" right={1} bold>
        {(points && (
          <>
            <AnimatedNumber
              value={points}
              format={(value) => formatMoney(value)}
            />
            {' credits'}
          </>
        )) || <AnimatedNumber value="No credits" />}
      </Box>
      <LabeledList>
        <LabeledList.Item label="Cargo Shuttle">
          <Button
            color={getButtonColor()}
            disabled={isButtonDisabled()}
            tooltip={
              isButtonDisabled() && shuttle_state === CARGO_SHUTTLE_AWAY
                ? shuttle_error || 'Cannot call shuttle'
                : null
            }
            content={getButtonText()}
            onClick={() => act('send')}
          />
        </LabeledList.Item>
        <LabeledList.Item label="Status">{shuttle_status}</LabeledList.Item>
        {(shuttle_state === CARGO_SHUTTLE_ARRIVING ||
          shuttle_state === CARGO_SHUTTLE_DEPARTING) && (
          <LabeledList.Item label="Timer">
            <ProgressBar
              value={shuttle_timer}
              maxValue={30}
              ranges={{
                good: [20, 30],
                average: [10, 20],
                bad: [0, 10],
              }}
            >
              {shuttle_timer}s remaining
            </ProgressBar>
          </LabeledList.Item>
        )}
        {!!shuttle_error && shuttle_state === CARGO_SHUTTLE_AWAY && (
          <LabeledList.Item label="Note" color="bad">
            {shuttle_error}
          </LabeledList.Item>
        )}
      </LabeledList>
    </Section>
  );
};

const VoidcrewCargoCartButtons = () => {
  const { act, data } = useBackend();
  const { cart = [], shuttle_state = CARGO_SHUTTLE_AWAY } = data;
  const total = cart.reduce((total, entry) => total + entry.cost, 0);
  const shuttleDocked = shuttle_state === CARGO_SHUTTLE_DOCKED;
  return (
    <>
      <Box inline mx={1}>
        {cart.length === 0 && 'Cart is empty'}
        {cart.length === 1 && '1 item'}
        {cart.length >= 2 && cart.length + ' items'}{' '}
        {total > 0 && `(${formatMoney(total)} cr)`}
      </Box>
      {!shuttleDocked && (
        <Button
          icon="times"
          color="transparent"
          content="Clear"
          onClick={() => act('clear')}
        />
      )}
    </>
  );
};

const VoidcrewCargoCart = () => {
  const { act, data } = useBackend();
  const { cart = [], shuttle_state = CARGO_SHUTTLE_AWAY } = data;
  const shuttleDocked = shuttle_state === CARGO_SHUTTLE_DOCKED;
  return (
    <Section fill>
      <Section>
        <Stack>
          <Stack.Item mt="4px">Current Cart</Stack.Item>
          <Stack.Item ml="200px" mt="3px">
            Quantity
          </Stack.Item>
          <Stack.Item ml="72px">
            <VoidcrewCargoCartButtons />
          </Stack.Item>
        </Stack>
      </Section>
      {cart.length === 0 && <Box color="label">Nothing in cart</Box>}
      {cart.length > 0 && (
        <Table>
          {cart.map((entry) => (
            <Table.Row key={entry.id} className="candystripe">
              <Table.Cell collapsing color="label" inline width="210px">
                #{entry.id}&nbsp;{entry.object}
              </Table.Cell>
              <Table.Cell inline ml="65px" width="40px">
                {(!shuttleDocked && entry.can_be_cancelled && (
                  <RestrictedInput
                    width="40px"
                    minValue={0}
                    maxValue={50}
                    value={entry.amount}
                    onEnter={(e, value) =>
                      act('modify', {
                        order_name: entry.object,
                        amount: value,
                      })
                    }
                  />
                )) || <Input width="40px" value={entry.amount} disabled />}
              </Table.Cell>
              <Table.Cell inline ml="5px" width="10px">
                {!shuttleDocked && !!entry.can_be_cancelled && (
                  <Button
                    icon="plus"
                    onClick={() =>
                      act('add_by_name', { order_name: entry.object })
                    }
                  />
                )}
              </Table.Cell>
              <Table.Cell inline ml="15px" width="10px">
                {!shuttleDocked && !!entry.can_be_cancelled && (
                  <Button
                    icon="minus"
                    onClick={() => act('remove', { order_name: entry.object })}
                  />
                )}
              </Table.Cell>
              <Table.Cell collapsing textAlign="right" inline ml="50px">
                {formatMoney(entry.cost)} {entry.cost_type}
              </Table.Cell>
              <Table.Cell inline mt="20px" />
            </Table.Row>
          ))}
        </Table>
      )}
      {cart.length > 0 && shuttle_state === CARGO_SHUTTLE_AWAY && (
        <Box mt={2}>
          <Box opacity={0.5}>
            Add items to cart, then call the cargo shuttle to order.
          </Box>
        </Box>
      )}
      {shuttleDocked && (
        <Box mt={2}>
          <Box color="good">
            Cargo shuttle is docked! Board the shuttle to retrieve your items,
            then send it away to sell exports.
          </Box>
        </Box>
      )}
    </Section>
  );
};
