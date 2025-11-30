import { useBackend } from 'tgui/backend';
import { Box, Button, Section, Stack } from 'tgui-core/components';

import { JobPriority, type PreferencesMenuData } from '../types';
import { useServerPrefs } from '../useServerPrefs';

const PRIORITY_BUTTON_SIZE = '18px';

type PriorityButtonProps = {
  name: string;
  color: string;
  modifier?: string;
  enabled: boolean;
  onClick: () => void;
};

function PriorityButton(props: PriorityButtonProps) {
  const className = `PreferencesMenu__Jobs__departments__priority`;

  return (
    <Stack.Item height={PRIORITY_BUTTON_SIZE}>
      <Button
        className={className + (props.modifier ? ` ${className}--${props.modifier}` : '')}
        color={props.enabled ? props.color : 'white'}
        circular
        onClick={props.onClick}
        tooltip={props.name}
        tooltipPosition="bottom"
        height={PRIORITY_BUTTON_SIZE}
        width={PRIORITY_BUTTON_SIZE}
      />
    </Stack.Item>
  );
}

function PriorityHeaders() {
  const className = 'PreferencesMenu__Jobs__PriorityHeader';

  return (
    <Stack>
      <Stack.Item grow />
      <Stack.Item className={className}>Off</Stack.Item>
      <Stack.Item className={className}>Low</Stack.Item>
      <Stack.Item className={className}>Med</Stack.Item>
      <Stack.Item className={className}>High</Stack.Item>
    </Stack>
  );
}

type CategoryRowProps = {
  category: string;
  priority: JobPriority | null;
  onSetPriority: (priority: JobPriority | null) => void;
};

function CategoryRow(props: CategoryRowProps) {
  const { category, priority, onSetPriority } = props;

  return (
    <Stack.Item height="28px" mt={0}>
      <Stack fill align="center">
        <Stack.Item
          width="50%"
          style={{
            paddingLeft: '0.3em',
            fontWeight: 'bold',
          }}
        >
          {category}
        </Stack.Item>

        <Stack.Item grow>
          <Stack
            style={{
              alignItems: 'center',
              height: '100%',
              justifyContent: 'flex-end',
              paddingLeft: '0.3em',
            }}
          >
            <PriorityButton
              name="Off"
              modifier="off"
              color="light-grey"
              enabled={!priority}
              onClick={() => onSetPriority(null)}
            />
            <PriorityButton
              name="Low"
              color="red"
              enabled={priority === JobPriority.Low}
              onClick={() => onSetPriority(JobPriority.Low)}
            />
            <PriorityButton
              name="Medium"
              color="yellow"
              enabled={priority === JobPriority.Medium}
              onClick={() => onSetPriority(JobPriority.Medium)}
            />
            <PriorityButton
              name="High"
              color="green"
              enabled={priority === JobPriority.High}
              onClick={() => onSetPriority(JobPriority.High)}
            />
          </Stack>
        </Stack.Item>
      </Stack>
    </Stack.Item>
  );
}

export function ShipCategoriesPage() {
  const { act, data } = useBackend<PreferencesMenuData>();
  const serverData = useServerPrefs();

  // Get categories from server constant data (provided by middleware)
  const categories: string[] =
    serverData?.ship_categories?.ship_categories || [];
  // Get current preferences from UI data
  const categoryPreferences: Record<string, JobPriority> =
    data.ship_category_preferences || {};

  const handleSetPriority = (category: string, priority: JobPriority | null) => {
    act('set_ship_category_preference', {
      category: category,
      level: priority,
    });
  };

  return (
    <Stack vertical fill>
      <Stack.Item>
        <Section
          title="Ship Role Preferences"
          buttons={
            <Box italic fontSize="12px" color="label">
              Set your preferred role categories for roundstart ships
            </Box>
          }
        >
          <Box mb={1} color="label" fontSize="12px">
            When you ready up, you&apos;ll be assigned a job matching your
            preferences on the roundstart ship. Higher priority categories are
            checked first. If no match is found, you&apos;ll get a random
            available role.
          </Box>

          <PriorityHeaders />

          <Stack vertical g={0}>
            {categories.map((category) => (
              <CategoryRow
                key={category}
                category={category}
                priority={categoryPreferences[category] || null}
                onSetPriority={(priority) =>
                  handleSetPriority(category, priority)
                }
              />
            ))}
          </Stack>

          {categories.length === 0 && (
            <Box color="bad" textAlign="center" mt={2}>
              No ship categories available. This may be a server configuration
              issue.
            </Box>
          )}
        </Section>
      </Stack.Item>
    </Stack>
  );
}
