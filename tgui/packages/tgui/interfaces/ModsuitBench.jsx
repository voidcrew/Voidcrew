import { useState } from 'react';
import {
  Box,
  Button,
  Divider,
  Image,
  LabeledList,
  NoticeBox,
  ProgressBar,
  Section,
  Stack,
  Tabs,
  Tooltip,
} from 'tgui-core/components';

import { useBackend } from '../backend';
import { Window } from '../layouts';

const Wallet = (props) => {
  const { held_vouchers, account_credits } = props;
  return (
    <Box inline color="label">
      Carrying{' '}
      <Box inline bold color="purple">
        {held_vouchers}
      </Box>{' '}
      voucher{held_vouchers === 1 ? '' : 's'}
      {' · '}
      {account_credits === null ? (
        <Box inline color="bad">
          no ID account
        </Box>
      ) : (
        <Box inline bold color="gold">
          {account_credits} cr
        </Box>
      )}
    </Box>
  );
};

const SuitSummary = (props) => {
  const { act } = useBackend();
  const { suit, charging, locked, held_vouchers, account_credits } = props;
  const used = suit.complexity;
  const max = suit.complexity_max;
  return (
    <Section
      title={suit.name}
      buttons={
        <>
          <Wallet
            held_vouchers={held_vouchers}
            account_credits={account_credits}
          />{' '}
          <Tooltip content="Engrave a new designation, free.">
            <Button icon="pen" disabled={locked} onClick={() => act('rename')}>
              Engrave
            </Button>
          </Tooltip>{' '}
          <Button icon="door-open" onClick={() => act('open_frame')}>
            Open frame
          </Button>
        </>
      }
    >
      <LabeledList>
        <LabeledList.Item label="Chassis">
          {suit.theme} ({suit.skin})
        </LabeledList.Item>
        <LabeledList.Item label="Modules">
          <ProgressBar
            value={max > 0 ? used / max : 0}
            ranges={{ good: [0, 0.7], average: [0.7, 0.95], bad: [0.95, 1] }}
          >
            {used} / {max} complexity
          </ProgressBar>
        </LabeledList.Item>
        <LabeledList.Item label="Power draw">
          {suit.charge_drain} per second
        </LabeledList.Item>
        <LabeledList.Item label="Slowdown">
          {suit.slowdown > 0 ? suit.slowdown : 'none'}
          {' · seals in '}
          {suit.seal_time}s per part
        </LabeledList.Item>
        <LabeledList.Item label="Core">
          {suit.core_name ? `${suit.core_name}, ${suit.charge_text}` : 'none'}
          {!!charging && (
            <Box inline color="good" ml={1}>
              ⚡ charging off the frame
            </Box>
          )}
        </LabeledList.Item>
      </LabeledList>
    </Section>
  );
};

const ModuleRow = (props) => {
  const { module, action, buttonIcon, buttonText, disabled, note } = props;
  const { act } = useBackend();

  const button = (
    <Button
      icon={buttonIcon}
      disabled={disabled}
      onClick={() => act(action, { ref: module.ref })}
    >
      {buttonText}
    </Button>
  );

  return (
    <Stack align="center" py={0.5} className="candystripe">
      <Stack.Item grow>
        <Box bold>{module.name}</Box>
        <Box color="label" fontSize="0.85em">
          {module.desc}
        </Box>
      </Stack.Item>
      <Stack.Item color="label" minWidth="80px" textAlign="center">
        {module.complexity} cplx
      </Stack.Item>
      <Stack.Item minWidth="90px" textAlign="right">
        {note ? <Tooltip content={note}>{button}</Tooltip> : button}
      </Stack.Item>
    </Stack>
  );
};

const ModulesTab = (props) => {
  const { data } = useBackend();
  const { installed_modules = [], loose_modules = [] } = data;
  const { locked } = props;
  return (
    <Stack fill vertical>
      <Stack.Item grow basis="50%">
        <Section fill scrollable title="Installed">
          {installed_modules.length === 0 && (
            <Box color="label">Nothing installed.</Box>
          )}
          {installed_modules.map((module) => (
            <ModuleRow
              key={module.ref}
              module={module}
              action="remove_module"
              buttonIcon="minus"
              buttonText="Remove"
              disabled={locked || !module.removable}
              note={!module.removable ? 'Fixed in place, part of the suit.' : null}
            />
          ))}
        </Section>
      </Stack.Item>
      <Stack.Item grow basis="50%">
        <Section fill scrollable title="On you">
          {loose_modules.length === 0 && (
            <Box color="label">
              No loose modules on you. Anything in your hands, pockets or bag
              shows up here.
            </Box>
          )}
          {loose_modules.map((module) => (
            <ModuleRow
              key={module.ref}
              module={module}
              action="install_module"
              buttonIcon="plus"
              buttonText="Install"
              disabled={locked || !!module.denial}
              note={module.denial}
            />
          ))}
        </Section>
      </Stack.Item>
    </Stack>
  );
};

const UpgradeRow = (props) => {
  const { act } = useBackend();
  const { upgrade, locked } = props;
  const blocked = !!upgrade.denial || !upgrade.affordable || locked;

  const button = (
    <Button
      icon={
        upgrade.installed
          ? 'check'
          : upgrade.repeatable
            ? 'arrows-rotate'
            : 'screwdriver-wrench'
      }
      color={upgrade.installed ? 'good' : null}
      disabled={blocked}
      onClick={() => act('buy_upgrade', { id: upgrade.id })}
    >
      {upgrade.installed ? 'Fitted' : upgrade.repeatable ? 'Service' : 'Fit'}
    </Button>
  );

  const note = upgrade.installed
    ? null
    : upgrade.denial ||
      (!upgrade.affordable ? "You can't cover the price." : null);

  return (
    <Stack
      align="center"
      py={0.5}
      className="candystripe"
      opacity={upgrade.installed ? 0.6 : 1}
    >
      <Stack.Item grow>
        <Box bold>{upgrade.name}</Box>
        <Box color="label" fontSize="0.85em">
          {upgrade.desc}
        </Box>
      </Stack.Item>
      <Stack.Item minWidth="110px" textAlign="right">
        {upgrade.price_vouchers > 0 && (
          <Box inline bold color="purple">
            {upgrade.price_vouchers} vch
          </Box>
        )}
        {upgrade.price_vouchers > 0 && upgrade.price_credits > 0 && (
          <Box inline color="label">
            {' + '}
          </Box>
        )}
        {upgrade.price_credits > 0 && (
          <Box inline bold color="gold">
            {upgrade.price_credits} cr
          </Box>
        )}
      </Stack.Item>
      <Stack.Item minWidth="90px" textAlign="right">
        {note ? <Tooltip content={note}>{button}</Tooltip> : button}
      </Stack.Item>
    </Stack>
  );
};

const UpgradesTab = (props) => {
  const { data } = useBackend();
  const { upgrades = [] } = data;
  const { locked } = props;

  const categories = [];
  for (const upgrade of upgrades) {
    if (!categories.includes(upgrade.category)) {
      categories.push(upgrade.category);
    }
  }

  return (
    <Section fill scrollable>
      {categories.map((category) => (
        <Box key={category} mb={1}>
          <Box bold color="label">
            {category}
          </Box>
          <Divider />
          {upgrades
            .filter((upgrade) => upgrade.category === category)
            .map((upgrade) => (
              <UpgradeRow key={upgrade.id} upgrade={upgrade} locked={locked} />
            ))}
        </Box>
      ))}
    </Section>
  );
};

const PaintTab = (props) => {
  const { act, data } = useBackend();
  const { skins = [], paints = [] } = data;
  const { locked } = props;
  return (
    <Stack fill vertical>
      <Stack.Item grow>
        <Section fill scrollable title="Shell">
          {skins.length <= 1 && (
            <Box color="label" mb={1}>
              This chassis only comes in the one shell.
            </Box>
          )}
          {skins.map((entry) => (
            <Button
              key={entry.skin}
              selected={entry.current}
              disabled={locked || entry.current}
              m={0.5}
              onClick={() => act('set_skin', { skin: entry.skin })}
            >
              <Stack align="center">
                {!!entry.icon && (
                  <Stack.Item>
                    <Image
                      src={`data:image/png;base64,${entry.icon}`}
                      width="32px"
                      height="32px"
                      style={{ imageRendering: 'pixelated' }}
                    />
                  </Stack.Item>
                )}
                <Stack.Item>{entry.skin}</Stack.Item>
              </Stack>
            </Button>
          ))}
        </Section>
      </Stack.Item>
      <Stack.Item>
        <Section
          title="Paint"
          buttons={
            <>
              <Button
                icon="palette"
                disabled={locked}
                onClick={() => act('custom_paint')}
              >
                Custom colour
              </Button>{' '}
              <Button
                icon="eraser"
                disabled={locked}
                onClick={() => act('clear_paint')}
              >
                Strip paint
              </Button>
            </>
          }
        >
          {paints.map((paint) => (
            <Button
              key={paint.name}
              disabled={locked}
              m={0.5}
              onClick={() => act('set_paint', { paint: paint.name })}
            >
              <Stack align="center">
                <Stack.Item>
                  <Box
                    width="16px"
                    height="16px"
                    backgroundColor={paint.hex}
                    style={{ border: '1px solid rgba(0, 0, 0, 0.5)' }}
                  />
                </Stack.Item>
                <Stack.Item>{paint.name}</Stack.Item>
              </Stack>
            </Button>
          ))}
        </Section>
      </Stack.Item>
    </Stack>
  );
};

export const ModsuitBench = (props) => {
  const { data } = useBackend();
  const {
    has_occupant,
    has_suit,
    barred,
    suit,
    charging,
    held_vouchers,
    account_credits,
  } = data;

  const [tab, setTab] = useState('modules');

  if (!has_occupant || !has_suit) {
    return (
      <Window title="MOD Fitting Bench" width={660} height={620}>
        <Window.Content>
          <NoticeBox>
            No MOD control unit detected. Step into the frame wearing your suit.
          </NoticeBox>
        </Window.Content>
      </Window>
    );
  }

  // The bench can't work on a suit that's sealed shut around its wearer.
  const locked = !!suit.sealed || !!barred;

  return (
    <Window title="MOD Fitting Bench" width={660} height={620}>
      <Window.Content>
        <Stack fill vertical>
          {!!barred && (
            <Stack.Item>
              <NoticeBox danger>
                Trade embargo in effect. The bench won&apos;t run for you.
              </NoticeBox>
            </Stack.Item>
          )}
          {!!suit.sealed && (
            <Stack.Item>
              <NoticeBox warning>
                The suit is sealed. Power it down before the bench can touch it.
              </NoticeBox>
            </Stack.Item>
          )}
          <Stack.Item>
            <SuitSummary
              suit={suit}
              charging={charging}
              locked={locked}
              held_vouchers={held_vouchers}
              account_credits={account_credits}
            />
          </Stack.Item>
          <Stack.Item>
            <Tabs fluid>
              <Tabs.Tab
                selected={tab === 'modules'}
                onClick={() => setTab('modules')}
              >
                Modules
              </Tabs.Tab>
              <Tabs.Tab
                selected={tab === 'upgrades'}
                onClick={() => setTab('upgrades')}
              >
                Upgrades
              </Tabs.Tab>
              <Tabs.Tab
                selected={tab === 'paint'}
                onClick={() => setTab('paint')}
              >
                Paint
              </Tabs.Tab>
            </Tabs>
          </Stack.Item>
          <Stack.Item grow>
            {tab === 'modules' && <ModulesTab locked={locked} />}
            {tab === 'upgrades' && <UpgradesTab locked={locked} />}
            {tab === 'paint' && <PaintTab locked={locked} />}
          </Stack.Item>
          <Stack.Item>
            <Box color="label" fontSize="0.85em" px={1}>
              Module swaps, paint and engraving are free. Upgrades are
              permanent, charged on the spot, and stay with the suit. Servicing
              is charged per visit. No refunds.
            </Box>
          </Stack.Item>
        </Stack>
      </Window.Content>
    </Window>
  );
};
