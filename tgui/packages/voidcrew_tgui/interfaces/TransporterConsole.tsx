import { type BooleanLike } from 'tgui-core/react';
import {
  Box,
  Button,
  LabeledList,
  NoticeBox,
  Section,
  Stack,
  Table,
} from 'tgui-core/components';

import { useBackend } from '../backend';
import { Window } from '../layouts';

type Transponder = {
  ref: string;
  name: string;
  carrier: string | null;
  area: string;
  status: string;
  ready: BooleanLike;
};

type PadItem = {
  name: string;
  living: BooleanLike;
};

type Data = {
  padLinked: BooleanLike;
  researchLinked: BooleanLike;
  targetingUnlocked: BooleanLike;
  diagnosticsUnlocked: BooleanLike;
  padStatus: string;
  padReady: BooleanLike;
  cooldownLeft: number;
  beamSeconds: number;
  bufferSize: number;
  patternIntegrity: 'nominal' | 'corrupted' | 'unknown';
  padContents: PadItem[];
  targetName: string | null;
  lockedSite: string | null;
  lockedSiteClear: BooleanLike;
  transponders: Transponder[];
};

const IntegrityBox = (props: { integrity: Data['patternIntegrity'] }) => {
  const { integrity } = props;
  if (integrity === 'corrupted') {
    return (
      <NoticeBox danger>
        Pattern buffer integrity check FAILED. The pad&apos;s safety interlocks
        have been cut. Do not use it.
      </NoticeBox>
    );
  }
  if (integrity === 'nominal') {
    return <NoticeBox success>Pattern buffer integrity nominal.</NoticeBox>;
  }
  return (
    <NoticeBox>
      No biofilter matrix installed. Pattern buffer integrity cannot be
      verified.
    </NoticeBox>
  );
};

export const TransporterConsole = (props) => {
  const { act, data } = useBackend<Data>();
  const {
    padLinked,
    researchLinked,
    targetingUnlocked,
    diagnosticsUnlocked,
    padStatus,
    padReady,
    cooldownLeft,
    beamSeconds,
    bufferSize,
    patternIntegrity,
    padContents = [],
    targetName,
    lockedSite,
    lockedSiteClear,
    transponders = [],
  } = data;

  const inOrbit = !!targetName;
  const canBeam = !!padLinked && !!padReady && inOrbit;

  return (
    <Window width={520} height={620} title="Transporter Control">
      <Window.Content scrollable>
        {!padLinked && (
          <NoticeBox danger>
            No transporter pad linked. Save a pad to a multitool buffer and
            apply it to this console.
          </NoticeBox>
        )}
        {!researchLinked && (
          <NoticeBox>
            No research uplink. Copy a techweb from an R&amp;D server with a
            multitool to unlock targeting and diagnostics.
          </NoticeBox>
        )}
        {/* Both are BooleanLike (DM sends 0/1), so these need coercing - a bare
            `a && b && <x/>` renders the literal 0 when b is 0. */}
        {!!padLinked && !!diagnosticsUnlocked && (
          <IntegrityBox integrity={patternIntegrity} />
        )}

        <Section
          title="Pad"
          buttons={
            <Box color={padReady ? 'good' : 'average'}>
              {padReady ? 'READY' : padStatus.toUpperCase()}
            </Box>
          }
        >
          <LabeledList>
            <LabeledList.Item label="Orbital lock">
              {targetName ? (
                targetName
              ) : (
                <Box color="bad">nothing in transporter range</Box>
              )}
            </LabeledList.Item>
            <LabeledList.Item label="Cycle time">
              {beamSeconds} seconds
            </LabeledList.Item>
            <LabeledList.Item label="Pattern buffer">
              {bufferSize} object{bufferSize === 1 ? '' : 's'} per cycle
            </LabeledList.Item>
            {cooldownLeft > 0 && (
              <LabeledList.Item label="Recharging">
                <Box color="average">{cooldownLeft} seconds remaining</Box>
              </LabeledList.Item>
            )}
          </LabeledList>
        </Section>

        <Section title="Pattern lock">
          <LabeledList>
            <LabeledList.Item label="Coordinates">
              {lockedSite ? (
                <Box color={lockedSiteClear ? 'good' : 'bad'}>{lockedSite}</Box>
              ) : (
                <Box color="label">
                  none, the computer will pick open ground
                </Box>
              )}
            </LabeledList.Item>
          </LabeledList>
          <Stack mt={1}>
            <Stack.Item>
              <Button
                icon="crosshairs"
                disabled={!targetingUnlocked || !inOrbit}
                tooltip={
                  !targetingUnlocked
                    ? 'Pattern targeting not researched'
                    : !inOrbit
                      ? 'Nothing in transporter range'
                      : undefined
                }
                onClick={() => act('openScanner')}
              >
                Open targeting scanner
              </Button>
            </Stack.Item>
            <Stack.Item>
              <Button
                icon="xmark"
                disabled={!lockedSite}
                onClick={() => act('clearLock')}
              >
                Clear lock
              </Button>
            </Stack.Item>
          </Stack>
        </Section>

        <Section title="Beam down">
          {padContents.length === 0 ? (
            <Box color="label">The pad is empty.</Box>
          ) : (
            <Table>
              {padContents.map((item, index) => (
                <Table.Row key={index}>
                  <Table.Cell color={item.living ? 'good' : 'label'}>
                    {item.name}
                  </Table.Cell>
                </Table.Row>
              ))}
            </Table>
          )}
          <Stack mt={1}>
            <Stack.Item>
              <Button
                icon="arrow-down"
                disabled={!canBeam || !lockedSite}
                tooltip={!lockedSite ? 'No coordinates locked' : undefined}
                onClick={() => act('beamDown')}
              >
                Beam to lock
              </Button>
            </Stack.Item>
            <Stack.Item>
              <Button
                icon="dice"
                disabled={!canBeam}
                onClick={() => act('beamDownRandom')}
              >
                Beam to open ground
              </Button>
            </Stack.Item>
          </Stack>
        </Section>

        <Section
          title="Beam up"
          buttons={
            <Button
              icon="arrow-up"
              disabled={!canBeam || !targetingUnlocked || !lockedSite}
              tooltip={
                !targetingUnlocked
                  ? 'Pattern targeting not researched'
                  : !lockedSite
                    ? 'No coordinates locked'
                    : undefined
              }
              onClick={() => act('beamUpSite')}
            >
              Lift from lock
            </Button>
          }
        >
          {transponders.length === 0 ? (
            <Box color="label">
              No transponder signals below. Crew going down need to take one
              with them.
            </Box>
          ) : (
            <Table>
              {transponders.map((signal) => (
                <Table.Row key={signal.ref} className="candystripe">
                  <Table.Cell p={0.5}>
                    <Box>{signal.name}</Box>
                    <Box color="label" fontSize="0.85rem">
                      {signal.carrier ? `carried by ${signal.carrier}, ` : ''}
                      {signal.area}
                    </Box>
                  </Table.Cell>
                  <Table.Cell collapsing textAlign="right" p={0.5}>
                    <Button
                      icon="arrow-up"
                      disabled={!canBeam || !signal.ready}
                      tooltip={signal.ready ? undefined : signal.status}
                      onClick={() =>
                        act('beamUpTransponder', { ref: signal.ref })
                      }
                    >
                      Lift
                    </Button>
                  </Table.Cell>
                </Table.Row>
              ))}
            </Table>
          )}
        </Section>
      </Window.Content>
    </Window>
  );
};
