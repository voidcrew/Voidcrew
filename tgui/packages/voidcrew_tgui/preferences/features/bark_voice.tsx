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

// Game preferences for hearing barks

export const voice_sounds_short: FeatureToggle = {
  name: 'Shortened Bark Sounds',
  description: 'Hear shortened versions of bark sounds.',
  component: CheckboxInput,
};

export const voice_sounds_limited_pitch: FeatureToggle = {
  name: 'Limit Bark Pitch',
  description: 'Hear barks without pitch modification.',
  component: CheckboxInput,
};

export const voice_sounds_only_goon: FeatureToggle = {
  name: 'Simple Barks Only',
  description: 'Only hear simple Goonstation-style bark sounds.',
  component: CheckboxInput,
};
