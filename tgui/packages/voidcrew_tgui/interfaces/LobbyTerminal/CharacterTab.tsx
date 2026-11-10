/**
 * CHARACTER tab, layout A "personnel file" (CHARACTER-PLAN 2.2): FILES, the preview, the
 * PERSONNEL FILE cells and the crumbs; one editor sub-screen at a time.
 * Owner: C3. Stub from the C0 seam: sends char_open and draws the empty frame.
 */
import { useEffect, useState } from 'react';
import { useBackend } from 'tgui/backend';

import { BodyEditor } from './BodyEditor';
import { KitEditor } from './KitEditor';
import { RolesEditor } from './RolesEditor';
import { TraitsEditor } from './TraitsEditor';
import { Frame, TOP, useGrid } from './term';
import type { CellBox, CharSection, LobbyData } from './types';

/** home: bumped when CHARACTER is pressed while already open; go back to the file view. */
export function CharacterTab(props: { home: number }) {
  const { home } = props;
  const { act } = useBackend<LobbyData>();
  const { cols, rows } = useGrid();
  const [section, setSection] = useState<CharSection | null>(null);

  useEffect(() => {
    act('char_open');
  }, []);
  useEffect(() => {
    setSection(null);
  }, [home]);

  const h = rows - 1 - TOP;
  const box: CellBox = { x: 0, y: TOP + 1, w: cols, h: h - 1 };
  let editor;
  if (section === 'body') {
    editor = <BodyEditor {...box} />;
  } else if (section === 'roles') {
    editor = <RolesEditor {...box} />;
  } else if (section === 'traits') {
    editor = <TraitsEditor {...box} />;
  } else if (section === 'kit') {
    editor = <KitEditor {...box} />;
  }

  return (
    <>
      <Frame x={0} y={TOP} w={cols} h={h} title="PERSONNEL FILE" />
      {editor}
    </>
  );
}
