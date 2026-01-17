import {
  CheckboxInput,
  type FeatureToggle,
} from 'tgui/interfaces/PreferencesMenu/preferences/features/base';

export const use_intent_system: FeatureToggle = {
  name: 'Use Intent System',
  category: 'GAMEPLAY',
  description:
    'Use classic SS13 intents (Help, Disarm, Grab, Harm) instead of combat mode toggle. Requires rejoin to apply.',
  component: CheckboxInput,
};
