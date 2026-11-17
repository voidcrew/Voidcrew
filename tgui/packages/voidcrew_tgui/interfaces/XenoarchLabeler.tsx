/**
 * The specimen labeler: the tag it will print, stamped in purple ink on manila
 * card, over the words it knows for each line. Click a line on the tag or a
 * tab to choose which line to set, then click a word.
 */
import { useState } from 'react';
import { Box, Button, Stack } from 'tgui-core/components';

import { useBackend } from '../../tgui/backend';
import { Window } from '../../tgui/layouts';

type Field = 'effect' | 'trigger' | 'second';

type Data = {
  effect: string | null;
  trigger: string | null;
  second: string | null;
  effects: string[];
  triggers: string[];
  none: string;
};

const FIELDS: { key: Field; title: string }[] = [
  { key: 'effect', title: 'Effect' },
  { key: 'trigger', title: 'Trigger' },
  { key: 'second', title: 'Second' },
];

const INK = '#5b2a86';

/** A manila tag on a string, its three lines stamped in purple. */
const Tag = (props: {
  data: Data;
  field: Field;
  onField: (field: Field) => void;
}) => {
  const { data, field, onField } = props;
  return (
    <div
      style={{
        position: 'relative',
        margin: '4px auto 10px',
        width: '310px',
        background: '#d9bf8c',
        backgroundImage:
          'repeating-linear-gradient(90deg, #0000 0 3px, #0000000a 3px 4px)',
        clipPath: 'polygon(0 18%, 9% 0, 100% 0, 100% 100%, 9% 100%, 0 82%)',
        padding: '12px 14px 12px 46px',
        boxShadow: '0 4px 8px #0008',
      }}
    >
      <div
        style={{
          position: 'absolute',
          left: '14px',
          top: '50%',
          width: '14px',
          height: '14px',
          marginTop: '-7px',
          borderRadius: '50%',
          background: '#2a2826',
          boxShadow: '0 0 0 3px #b89a5e',
        }}
      />
      {FIELDS.map((line) => {
        const word = data[line.key];
        return (
          <div
            key={line.key}
            onClick={() => onField(line.key)}
            style={{
              cursor: 'pointer',
              display: 'flex',
              alignItems: 'baseline',
              padding: '2px 4px',
              borderBottom: '1px solid #a88a54',
              background: field === line.key ? '#ffffff38' : undefined,
            }}
          >
            <span
              style={{
                width: '62px',
                flexShrink: 0,
                fontFamily: 'serif',
                fontSize: '11px',
                color: '#4a3a1c',
              }}
            >
              {line.title}:
            </span>
            <span
              style={{
                fontFamily: 'monospace',
                fontWeight: 'bold',
                fontSize: '15px',
                letterSpacing: '1px',
                textTransform: 'uppercase',
                color: word ? INK : '#a88a5480',
                transform: word ? 'rotate(-1.5deg)' : undefined,
                opacity: word ? 0.9 : 1,
                whiteSpace: 'nowrap',
                overflow: 'hidden',
                textOverflow: 'ellipsis',
              }}
            >
              {word ?? '...'}
            </span>
          </div>
        );
      })}
    </div>
  );
};

export const XenoarchLabeler = () => {
  const { act, data } = useBackend<Data>();
  const [field, setField] = useState<Field>('effect');
  let words = data.effects;
  if (field === 'trigger') {
    words = data.triggers;
  } else if (field === 'second') {
    words = [data.none, ...data.effects];
  }
  const chosen = data[field];
  const anySet = !!data.effect || !!data.trigger || !!data.second;
  const pick = (word: string) => {
    act('set', { field, word });
    // Move on to the next blank line, as a hand would.
    const next = FIELDS.find((line) => line.key !== field && !data[line.key]);
    if (next) {
      setField(next.key);
    }
  };
  return (
    <Window width={420} height={520} theme="ntos_darkmode">
      <Window.Content style={{ background: '#3a3631' }}>
        <Stack vertical fill>
          <Stack.Item>
            <Tag data={data} field={field} onField={setField} />
          </Stack.Item>
          <Stack.Item>
            <Stack>
              {FIELDS.map((tab) => (
                <Stack.Item grow basis={0} key={tab.key}>
                  <Button
                    fluid
                    textAlign="center"
                    selected={field === tab.key}
                    onClick={() => setField(tab.key)}
                  >
                    {tab.title}
                  </Button>
                </Stack.Item>
              ))}
            </Stack>
          </Stack.Item>
          <Stack.Item grow>
            <Box
              style={{
                height: '100%',
                overflowY: 'auto',
                background: '#2b2824',
                padding: '6px',
                borderRadius: '4px',
              }}
            >
              {words.map((word) => (
                <span
                  key={word}
                  onClick={() => pick(word)}
                  style={{
                    display: 'inline-block',
                    cursor: 'pointer',
                    margin: '3px',
                    padding: '3px 8px',
                    borderRadius: '2px',
                    fontFamily: 'monospace',
                    fontSize: '12px',
                    background: word === chosen ? INK : '#e9e1cd',
                    color: word === chosen ? '#fff' : '#3a3631',
                    boxShadow: '0 1px 0 #0006',
                  }}
                >
                  {word}
                </span>
              ))}
            </Box>
          </Stack.Item>
          <Stack.Item>
            <Stack justify="flex-end">
              <Stack.Item>
                <Button
                  icon="eraser"
                  disabled={!anySet}
                  onClick={() => act('clear')}
                >
                  Clear
                </Button>
              </Stack.Item>
            </Stack>
          </Stack.Item>
        </Stack>
      </Window.Content>
    </Window>
  );
};
