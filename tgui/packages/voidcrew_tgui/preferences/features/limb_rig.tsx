import {
  CheckboxInput,
  type FeatureToggle,
} from 'tgui/interfaces/PreferencesMenu/preferences/features/base';

export const limb_rig: FeatureToggle = {
  name: 'Animated body',
  category: 'GAMEPLAY',
  description:
    'Draws your character on the bigger, animated body that acts out walking, working and emotes. Off, you keep the plain sprite. Experiments and Milkies, and anyone with the Overanimated quirk, are animated either way.',
  component: CheckboxInput,
};
