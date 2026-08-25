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
import { VoidcrewCargoCatalog } from './VoidcrewCargoCatalog';

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
  const { cart = [], supplies = {}, history = [] } = data;
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
          <Tabs.Tab
            icon="history"
            selected={tab === 'history'}
            onClick={() => setTab('history')}
          >
            History ({history.length})
          </Tabs.Tab>
        </Tabs>
      </Section>
      {tab === 'catalog' &&
        (hasSupplies ? (
          <Section fill height="550px">
            <VoidcrewCargoCatalog express />
          </Section>
        ) : (
          <Section>
            <Box color="bad">
              No supplies available. Make sure the cargo system is initialized.
            </Box>
          </Section>
        ))}
      {tab === 'cart' && <VoidcrewCargoCart />}
      {tab === 'history' && <VoidcrewCargoHistory />}
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
    loan,
  } = data;

  // Determine button text and state
  const getButtonText = () => {
    switch (shuttle_state) {
      case CARGO_SHUTTLE_AWAY:
        return 'Call shuttle';
      case CARGO_SHUTTLE_ARRIVING:
        return `Arriving...`;
      case CARGO_SHUTTLE_DOCKED:
        return 'Depart';
      case CARGO_SHUTTLE_DEPARTING:
        return `Departing...`;
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
        {(!!points && (
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
        {shuttle_state === CARGO_SHUTTLE_ARRIVING && (
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
        {shuttle_state === CARGO_SHUTTLE_DEPARTING && (
          <LabeledList.Item label="Timer">
            <ProgressBar
              value={shuttle_timer}
              maxValue={5}
              ranges={{
                good: [3, 5],
                average: [2, 3],
                bad: [0, 2],
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
      {!!loan && (
        <Box
          mt={2}
          p={1}
          backgroundColor={
            loan.accepted
              ? 'rgba(100, 200, 100, 0.1)'
              : 'rgba(255, 200, 0, 0.1)'
          }
        >
          <Box bold color={loan.accepted ? 'good' : 'yellow'} mb={1}>
            {loan.accepted
              ? `Loan Accepted from ${loan.sender}`
              : `Shuttle Loan Offer from ${loan.sender}`}
          </Box>
          <Box mb={1}>{loan.announcement}</Box>
          {loan.bonus_credits > 0 && (
            <Box color="good" mb={1}>
              Bonus: {formatMoney(loan.bonus_credits)} credits
              {loan.accepted && ' (credited)'}
            </Box>
          )}
          {loan.accepted ? (
            <Box color="good" italic>
              Call the cargo shuttle to receive your loan items.
            </Box>
          ) : (
            <Stack>
              <Stack.Item>
                <Button
                  color="green"
                  icon="check"
                  content="Accept Loan"
                  onClick={() => act('accept_loan')}
                />
              </Stack.Item>
              <Stack.Item>
                <Button
                  color="red"
                  icon="times"
                  content="Decline"
                  onClick={() => act('decline_loan')}
                />
              </Stack.Item>
            </Stack>
          )}
        </Box>
      )}
    </Section>
  );
};

const VoidcrewCargoCartButtons = () => {
  const { act, data } = useBackend();
  const { cart = [], shuttle_state = CARGO_SHUTTLE_AWAY } = data;
  const total = cart.reduce((total, entry) => total + entry.cost, 0);
  // The cart is the dispatched shipment's manifest once the shuttle is called
  const cartLocked = shuttle_state !== CARGO_SHUTTLE_AWAY;
  return (
    <>
      <Box inline mx={1}>
        {cart.length === 0 && 'Cart is empty'}
        {cart.length === 1 && '1 item'}
        {cart.length >= 2 && cart.length + ' items'}{' '}
        {total > 0 && `(${formatMoney(total)} cr)`}
      </Box>
      {!cartLocked && (
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
  const cartLocked = shuttle_state !== CARGO_SHUTTLE_AWAY;
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
                {(!cartLocked && !!entry.can_be_cancelled && (
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
                {!cartLocked && !!entry.can_be_cancelled && (
                  <Button
                    icon="plus"
                    onClick={() =>
                      act('add_by_name', { order_name: entry.object })
                    }
                  />
                )}
              </Table.Cell>
              <Table.Cell inline ml="15px" width="10px">
                {!cartLocked && !!entry.can_be_cancelled && (
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
      {cart.length > 0 && shuttle_state === CARGO_SHUTTLE_ARRIVING && (
        <Box mt={2}>
          <Box color="yellow">
            Order dispatched - the cart is locked until the shuttle arrives.
          </Box>
        </Box>
      )}
      {!!shuttleDocked && (
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

const VoidcrewCargoHistory = () => {
  const { data } = useBackend();
  const { history = [] } = data;

  return (
    <Section fill title="Transaction History">
      {history.length === 0 && (
        <Box color="label">No transactions recorded yet.</Box>
      )}
      {history.length > 0 && (
        <Table>
          <Table.Row header>
            <Table.Cell>Time</Table.Cell>
            <Table.Cell>Type</Table.Cell>
            <Table.Cell>Item</Table.Cell>
            <Table.Cell>Qty</Table.Cell>
            <Table.Cell textAlign="right">Value</Table.Cell>
          </Table.Row>
          {history.map((entry, index) => (
            <Table.Row key={index} className="candystripe">
              <Table.Cell color="label">{entry.time}</Table.Cell>
              <Table.Cell color={entry.type === 'buy' ? 'bad' : 'good'}>
                {entry.type === 'buy' ? 'Purchase' : 'Sale'}
              </Table.Cell>
              <Table.Cell>{entry.name}</Table.Cell>
              <Table.Cell>{entry.amount}</Table.Cell>
              <Table.Cell textAlign="right">
                <Box color={entry.type === 'buy' ? 'bad' : 'good'}>
                  {entry.type === 'buy' ? '-' : '+'}
                  {formatMoney(entry.value)} cr
                </Box>
              </Table.Cell>
            </Table.Row>
          ))}
        </Table>
      )}
    </Section>
  );
};
