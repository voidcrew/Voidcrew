/**
 * SETTINGS: the terminal's own screen for the game preferences (OPTIONS) and the keybindings
 * (KEYS). Opened from the menu like CHARACTER, in the same box; the tab row stays.
 *
 * Columns of the main region: the list column is 1 to 15 (LIST_X, LIST_W) with the group switch
 * OPTIONS | KEYS on top and the categories of the open group under it; column 16 is a gap; the
 * work column is 17 to 61 (WORK_X, WORK_W): the open category's rows, the page mark and, at the
 * foot, the description strip (two dim lines about the focused or hovered row).
 *
 * A row: the name in 19 to 42 (NAME_X, NAME_W), wrapped to two lines in a taller row when
 * longer (rowHeight(); never more than two, the second then ends in the cut mark); the value in
 * 44 to 61 (VALUE_X, VALUE_W).
 *
 * ## The contract for KEYS (SettingsKeys.tsx, lobby_settings_keys.dm)
 *
 * Everything below is exported from SettingsFrame.tsx (re-exported here). Import it from
 * './SettingsFrame', not './Settings': Settings.tsx imports the two panes, so a pane importing it
 * back would read its constants before they exist.
 *
 * SettingsKeys is drawn instead of the OPTIONS pane while the group is KEYS. It owns its data
 * (its own settings_keys_* actions; settings_act() routes them to settings_keys_act()) and
 * draws the same two columns with <SettingsColumns>:
 *   cats      its categories for the left list ({id, label}; labels at most 13 characters)
 *   cat       the open one (keep it in your own state); onCat(id) opens another
 *   rows      SettingsRowSpec[]: key, name (upper case), desc, value(ty, focused) drawing in the
 *             value zone, onPress (Enter or a click), onStep (Left/Right and the mouse arrows),
 *             muted; typing rows can render a <Field> from value() (see OPTIONS' number rows)
 *   focusKey  the row that takes the focus when the rows mount (back from a level-2 screen);
 *             a row's own `claim` does the same when it turns on
 * SettingsColumns does the list, its paging, the rows' paging (PageUp/PageDown and the page
 * mark), the description strip and the page wipes, so both groups look and move the same.
 * useSettings() gives sub(node, crumb, from) for a level-2 screen in the work column (the frame
 * then draws `node` there and the crumbs SETTINGS / <category> / <crumb>, and Escape or [ BACK ]
 * closes it; `node` must read live data itself), closeSub(), subOpen, from (the row that opened
 * the last one, to give the focus back), setCrumb(label) (the open category's name for the
 * crumbs) and home (bumped when SETTINGS is pressed while open: go back to your top state).
 */
import { type ReactNode, useEffect, useState } from 'react';
import { useBackend } from 'tgui/backend';

import { type Crumb, Crumbs } from './CharFrame';
import { useChanged, useScreen } from './motion';
import { useBack } from './nav';
import {
  GroupSwitch,
  SettingsContext,
  type SettingsGroup,
  type SettingsNav,
  WORK_W,
  WORK_X,
} from './SettingsFrame';
import { SettingsKeys } from './SettingsKeys';
import { SettingsOptions } from './SettingsOptions';
import { BODY_Y, Box, Put, useGrid, WipeAt } from './term';
import type { LobbyData } from './types';

export * from './SettingsFrame';

/** The box, with SAVED on the border for two seconds after a save. */
function SettingsBox() {
  const { rows } = useGrid();
  const { data } = useBackend<LobbyData>();
  const [saved, setSaved] = useState(false);
  useChanged(data.settings_saved ?? 0, () => setSaved(true));
  useEffect(() => {
    if (!saved) {
      return;
    }
    const t = window.setTimeout(() => setSaved(false), 2000);
    return () => window.clearTimeout(t);
  }, [saved, data.settings_saved]);
  return (
    <>
      <Box x={0} y={2.5} w={63} h={rows - 3.5} caption="SETTINGS" />
      {!!saved && (
        <Put x={53} y={2} cls="dim" bg>
          {' SAVED '}
        </Put>
      )}
    </>
  );
}

type Sub = { node: ReactNode; crumb: string; from: string | null };

/**
 * The screen. home: bumped when SETTINGS is pressed while open (back to the top state);
 * onLeave: Escape at the top state (back to the tab that was open before).
 */
export function Settings(props: { home: number; onLeave?: () => void }) {
  const { home, onLeave } = props;
  const { act } = useBackend<LobbyData>();
  const { rows: M } = useGrid();
  const [group, setGroup] = useState<SettingsGroup>('options');
  const [sub, setSub] = useState<Sub | null>(null);
  const [from, setFrom] = useState<string | null>(null);
  const [crumb, setCrumb] = useState('');

  useEffect(() => {
    act('settings_open');
    return () => act('settings_close');
  }, []);

  const closeSub = () => {
    setFrom(sub?.from ?? null);
    setSub(null);
  };
  useEffect(() => {
    setSub(null);
    setFrom(null);
  }, [home]);

  useBack(sub ? closeSub : onLeave || null);
  useScreen(`settings/${group}`, 0);

  const nav: SettingsNav = {
    sub: (node, label, at) => {
      setFrom(null);
      setSub({ node, crumb: label, from: at ?? null });
    },
    closeSub,
    subOpen: !!sub,
    from,
    setCrumb,
    home,
  };
  const crumbs: Crumb[] = [
    ['SETTINGS', closeSub],
    [crumb, closeSub],
  ];
  if (sub) {
    crumbs.push([sub.crumb, null]);
  }

  return (
    <SettingsContext.Provider value={nav}>
      <SettingsBox />
      {!!sub && <Crumbs crumbs={crumbs} onBack={closeSub} />}
      <GroupSwitch
        group={group}
        onGroup={(g) => {
          setSub(null);
          setFrom(null);
          setGroup(g);
        }}
      />
      {group === 'options' ? <SettingsOptions /> : <SettingsKeys />}
      {!!sub && sub.node}
      {/* A picker or a colour panel wipes the work column only. */}
      <WipeAt
        kind="screen"
        x={WORK_X}
        y={BODY_Y}
        w={WORK_W}
        h={M - 1.25 - BODY_Y}
        k={sub ? sub.crumb : ''}
        n={sub ? 1 : 0}
      />
    </SettingsContext.Provider>
  );
}
