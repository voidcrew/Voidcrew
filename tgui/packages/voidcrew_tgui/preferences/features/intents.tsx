import {
  CheckboxInput,
  type FeatureToggle,
} from 'tgui/interfaces/PreferencesMenu/preferences/features/base';

export const use_intent_system: FeatureToggle = {
  name: 'Use Intent System',
  category: 'GAMEPLAY',
  description:
    'Use classic SS13 intents (Help, Disarm, Grab, Harm) instead of combat mode toggle. Use 1-2-3-4 keys to switch intents.',
  component: CheckboxInput,
};
