import type { FeatureChoiced } from 'tgui/interfaces/PreferencesMenu/preferences/features/base';
import { FeatureDropdownInput } from 'tgui/interfaces/PreferencesMenu/preferences/features/dropdowns';

// Replaces tg's prisoner_crime feature: the voidcrew features load after tg's
export const prisoner_crime: FeatureChoiced = {
  name: 'Crime',
  component: FeatureDropdownInput,
};
