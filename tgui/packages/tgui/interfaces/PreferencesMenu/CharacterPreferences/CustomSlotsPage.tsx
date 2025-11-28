import { useRef, useState } from 'react';
import { useBackend } from 'tgui/backend';
import {
  Box,
  Button,
  Icon,
  Input,
  Section,
  Stack,
  Tooltip,
} from 'tgui-core/components';

type CustomSlot = {
  index: number;
  name: string;
  unlocked: boolean;
  cost: number;
  isActive: boolean;
};

type CustomSlotsData = {
  slots: CustomSlot[];
  playerCredits: number;
};

export function CustomSlotsPage() {
  const { act, data } = useBackend<CustomSlotsData>();
  const { slots = [], playerCredits = 0 } = data;

  // Show loading if we have no slots at all
  if (!slots || slots.length === 0) {
    return (
      <Section fill>
        <Box>
          Loading custom slots...
          <br />
          <Box color="label" fontSize="0.9em" mt={1}>
            Debug - Data keys: {Object.keys(data || {}).join(', ') || 'none'}
          </Box>
        </Box>
      </Section>
    );
  }

  return (
    <Stack vertical fill>
      <Stack.Item>
        <Section
          title="Custom Slots"
          buttons={
            <Tooltip content="Credits available for purchasing custom slots">
              <Box color="gold" bold fontSize="1.2em">
                <Icon name="coins" mr={1} />
                {playerCredits.toLocaleString()} Credits
              </Box>
            </Tooltip>
          }
        >
          <Box italic color="label" mb={1}>
            Configure your custom character slots. Slot 1 is free, additional
            slots must be purchased with credits.
          </Box>
        </Section>
      </Stack.Item>

      <Stack.Item grow>
        <Stack vertical fill>
          {slots.map((slot) => (
            <Stack.Item key={slot.index}>
              <CustomSlotCard slot={slot} playerCredits={playerCredits} />
            </Stack.Item>
          ))}
        </Stack>
      </Stack.Item>
    </Stack>
  );
}

type CustomSlotCardProps = {
  slot: CustomSlot;
  playerCredits: number;
};

function CustomSlotCard(props: CustomSlotCardProps) {
  const { slot, playerCredits } = props;
  const { act } = useBackend();
  // Use ref to always have current value (avoid stale closure issues)
  const nameRef = useRef(slot?.name || '');
  const [localName, setLocalName] = useState(slot?.name || '');

  // Keep ref in sync with state
  const handleNameChange = (value: string) => {
    nameRef.current = value;
    setLocalName(value);
  };

  const canAfford = playerCredits >= slot.cost;
  const isSlotOne = slot.index === 1;

  // Save slot name and loadout
  const handleSaveAll = () => {
    const nameToSave =
      (nameRef.current || '').trim() || `Custom Slot ${slot.index}`;
    // Configure the slot name
    act('configure_slot', {
      slotIndex: slot.index,
      name: nameToSave,
    });
    // Save the loadout
    act('save_loadout', { slotIndex: slot.index });
  };

  const handlePurchase = () => {
    if (canAfford) {
      act('purchase_slot', {
        slotIndex: slot.index,
      });
    }
  };

  return (
    <Section
      title={
        <Stack align="center">
          <Stack.Item>
            <Box bold>SLOT {slot.index}</Box>
          </Stack.Item>
          <Stack.Item>
            {isSlotOne ? (
              <Box color="good" ml={1}>
                (Free)
              </Box>
            ) : slot.unlocked ? (
              <Box color="good" ml={1}>
                <Icon name="check" mr={0.5} />
                Unlocked
              </Box>
            ) : (
              <Box color="label" ml={1}>
                ({slot.cost.toLocaleString()} credits)
              </Box>
            )}
          </Stack.Item>
        </Stack>
      }
      buttons={
        !slot.unlocked &&
        !isSlotOne && (
          <Tooltip
            content={
              !canAfford
                ? `Insufficient credits. Need ${slot.cost.toLocaleString()}, have ${playerCredits.toLocaleString()}`
                : `Purchase this slot for ${slot.cost.toLocaleString()} credits`
            }
          >
            <Button
              icon={canAfford ? 'shopping-cart' : 'lock'}
              color={canAfford ? 'good' : 'bad'}
              disabled={!canAfford}
              onClick={handlePurchase}
            >
              {canAfford ? 'BUY' : 'LOCKED'}
            </Button>
          </Tooltip>
        )
      }
    >
      {slot.unlocked || isSlotOne ? (
        <Stack vertical>
          <Stack.Item>
            <Stack align="center">
              <Stack.Item basis="20%">
                <Box bold>Name:</Box>
              </Stack.Item>
              <Stack.Item grow>
                <Input
                  fluid
                  placeholder="Enter slot name..."
                  value={localName}
                  onChange={handleNameChange}
                  maxLength={50}
                />
              </Stack.Item>
            </Stack>
          </Stack.Item>

          <Stack.Item mt={2}>
            <Stack>
              <Stack.Item grow>
                <Button fluid icon="save" color="good" onClick={handleSaveAll}>
                  Save Slot
                </Button>
              </Stack.Item>
              <Stack.Item grow ml={1}>
                <Tooltip content="Set this slot as active and load its saved loadout">
                  <Button
                    fluid
                    icon={slot.isActive ? 'check-circle' : 'circle'}
                    color={slot.isActive ? 'blue' : 'default'}
                    onClick={() =>
                      act('set_active_slot', {
                        slotIndex: slot.index,
                      })
                    }
                  >
                    {slot.isActive ? 'ACTIVE' : 'Set Active'}
                  </Button>
                </Tooltip>
              </Stack.Item>
            </Stack>
          </Stack.Item>
        </Stack>
      ) : (
        <Box color="label" italic textAlign="center" py={2}>
          Purchase this slot to unlock customization
        </Box>
      )}
    </Section>
  );
}
