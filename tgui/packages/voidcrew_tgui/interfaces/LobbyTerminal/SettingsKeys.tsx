/**
 * SETTINGS, KEYS group: the keybindings. A placeholder until the KEYS package fills it in; the
 * contract it builds against is at the top of Settings.tsx.
 */
import { SettingsColumns } from './Settings';

export function SettingsKeys() {
  return (
    <SettingsColumns cats={[]} cat={null} onCat={() => undefined} rows={[]} />
  );
}
