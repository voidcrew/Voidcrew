import { useBackend } from 'tgui/backend';
import { Button, Stack } from 'tgui-core/components';

import {
  CheckboxInput,
  type FeatureChoiced,
  type FeatureChoicedServerData,
  type FeatureNumeric,
  type FeatureToggle,
  FeatureSliderInput,
  type FeatureValueProps,
} from 'tgui/interfaces/PreferencesMenu/preferences/features/base';
import { FeatureDropdownInput } from 'tgui/interfaces/PreferencesMenu/preferences/features/dropdowns';

function FeatureBarkDropdownInput(
  props: FeatureValueProps<string, string, FeatureChoicedServerData>,
) {
  const { act } = useBackend();

  return (
    <Stack>
      <Stack.Item grow>
        <FeatureDropdownInput {...props} />
      </Stack.Item>
      <Stack.Item>
        <Button
          onClick={() => {
            act('play_bark');
          }}
          icon="play"
          width="100%"
          height="100%"
        />
      </Stack.Item>
      <Stack.Item>
        <Button
          onClick={() => {
            act('open_voice_screen');
          }}
          icon="list"
          width="100%"
          height="100%"
        />
      </Stack.Item>
    </Stack>
  );
}

export const voice_pack: FeatureChoiced = {
  name: 'Bark Sound',
  description: 'The sound effect that plays when you speak.',
  component: FeatureBarkDropdownInput,
};

export const bark_speech_speed: FeatureNumeric = {
  name: 'Bark Speed',
  description: 'How fast your bark sounds play.',
  component: FeatureSliderInput,
};

export const bark_speech_pitch: FeatureNumeric = {
  name: 'Bark Pitch',
  description: 'The pitch of your bark sounds.',
  component: FeatureSliderInput,
};

export const bark_pitch_range: FeatureNumeric = {
  name: 'Bark Pitch Variance',
  description: 'How much your bark pitch varies between sounds.',
  component: FeatureSliderInput,
};

// Game preferences for hearing barks.
//
// These need an explicit `category`. GamePreferencesPage falls back to the literal
// string 'ERROR' for any feature without one, so the settings that actually control
// what you hear were filed under a tab named ERROR, while the inert "Enable TTS" and
// "TTS Volume" (which drive the unrelated SStts subsystem) sat under Sound, right where
// a player looking to turn barks off would find them.

export const sound_barks_volume: FeatureNumeric = {
  name: 'Bark Volume',
  category: 'SOUND',
  description:
    "How loud other people's speech barks are for you. Set to 0 to turn barks off.",
  component: FeatureSliderInput,
};

export const voice_sounds_short: FeatureToggle = {
  name: 'Shortened Bark Sounds',
  category: 'SOUND',
  description: 'Hear shortened versions of bark sounds.',
  component: CheckboxInput,
};

export const voice_sounds_limited_pitch: FeatureToggle = {
  name: 'Limit Bark Pitch',
  category: 'SOUND',
  description: 'Hear barks without pitch modification.',
  component: CheckboxInput,
};

export const voice_sounds_only_goon: FeatureToggle = {
  name: 'Simple Barks Only',
  category: 'SOUND',
  description: 'Only hear simple Goonstation-style bark sounds.',
  component: CheckboxInput,
};
