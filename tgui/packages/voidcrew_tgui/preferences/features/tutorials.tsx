import {
  CheckboxInput,
  type FeatureToggle,
} from 'tgui/interfaces/PreferencesMenu/preferences/features/base';

export const tutorial_checklist: FeatureToggle = {
  name: 'Open tutorial checklist on spawn',
  category: 'GAMEPLAY',
  description: 'Open the tutorial checklist each time you spawn.',
  component: CheckboxInput,
};
