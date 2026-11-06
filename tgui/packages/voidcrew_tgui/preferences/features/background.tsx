import type { FeatureChoiced } from 'tgui/interfaces/PreferencesMenu/preferences/features/base';
import { FeatureDropdownInput } from 'tgui/interfaces/PreferencesMenu/preferences/features/dropdowns';

export const background: FeatureChoiced = {
  name: 'Background',
  component: FeatureDropdownInput,
};
