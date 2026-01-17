import { useBackend } from 'tgui/backend';
import { Button, Stack } from 'tgui-core/components';

import {
  type FeatureChoiced,
  type FeatureChoicedServerData,
  type FeatureNumeric,
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
