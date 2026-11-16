/**
 * CHARACTER (design 03): the router. Level 0 is the personnel file, level 1 an editor (BODY,
 * ROLES, TRAITS, KIT), level 2 a picker or colour panel in the work column. The frame pieces
 * (box, ID column, crumbs, species dialog) are in CharFrame.tsx.
 *
 * Props the shell wires: home (bumped when CHARACTER is pressed while open: back to the file),
 * auto (the shell opened it before the round: char_open {auto: 1}, no focus claim), onLeave
 * (Escape at the file view: back to the tab that was open before).
 */
import { type ReactNode, useEffect, useRef, useState } from 'react';
import { useBackend } from 'tgui/backend';

import { BodyEditor, type BodyGroup } from './BodyEditor';
import { CharFile } from './CharFile';
import {
  CharBox,
  CharContext,
  type CharNav,
  type Crumb,
  Crumbs,
  IdColumn,
  nextDir,
  type Section,
  SpeciesConfirm,
  WORK_W,
  WORK_X,
} from './CharFrame';
import { KitEditor } from './KitEditor';
import { useBack } from './nav';
import { RolesEditor } from './RolesEditor';
import { TraitsEditor } from './TraitsEditor';
import { BODY_Y, bodyRows, Key, NameLine, Slab, safe, useGrid } from './term';
import type { CharDir, LobbyData } from './types';
import { usePrefsCatalogState } from './usePrefsCatalog';

const TITLES: Record<Section, string> = {
  body: 'BODY',
  roles: 'ROLES',
  traits: 'TRAITS',
  kit: 'KIT',
};

/** A file switch is taken as done (or lost) after this long. */
const SWITCH_MS = 3000;
/** A push this far behind char_rev is asked for again. */
const STALE_MS = 2000;
const STALE_EVERY = 5000;

type Sub = { node: ReactNode; crumb: string; from: string | null };

/** The ghost block in the work column while the file is fetched or the records don't answer. */
function Ghost(props: { text: string; onRetry?: () => void }) {
  const { text, onRetry } = props;
  return (
    <>
      <Slab x={WORK_X} y={BODY_Y} w={WORK_W} h={4.75} variant="block" dead />
      <NameLine
        x={WORK_X + 2}
        y={BODY_Y + 0.625}
        w={35}
        text={text}
        cls="dim"
      />
      {!!onRetry && (
        <Key
          x={WORK_X + 2}
          y={5.75}
          w={13}
          kind="box"
          label="TRY AGAIN"
          onClick={onRetry}
        />
      )}
    </>
  );
}

export function CharacterTab(props: {
  home: number;
  auto?: boolean;
  onLeave?: () => void;
}) {
  const { home, auto, onLeave } = props;
  const { act, data } = useBackend<LobbyData>();
  const { rows: M } = useGrid();
  const { cat, failed, retry } = usePrefsCatalogState();
  const char = data.char;

  const [section, setSection] = useState<Section | null>(null);
  const [sub, setSub] = useState<Sub | null>(null);
  const [from, setFrom] = useState<string | null>(null);
  /** The section the file view gives the focus to: BODY on a player's open, else the one left. */
  const [focusSec, setFocusSec] = useState<Section | null>(
    auto ? null : 'body',
  );
  const [group, setGroup] = useState<BodyGroup>('identity');
  const [dir, setDir] = useState<CharDir>(2);
  const [switchAt, setSwitchAt] = useState(0);
  const quiet = !!auto && !section && focusSec === null;

  useEffect(() => {
    act('char_open', auto ? { auto: 1 } : {});
  }, []);

  const toFile = () => {
    setSub(null);
    setFrom(null);
    if (section) {
      setFocusSec(section);
    }
    setSection(null);
  };
  const openSection = (s: Section) => {
    setSub(null);
    setFrom(null);
    setSection(s);
  };
  const closeSub = () => {
    setFrom(sub?.from ?? null);
    setSub(null);
  };

  useEffect(() => {
    setSub(null);
    setFrom(null);
    setSection(null);
  }, [home]);

  // The open file changed (here or in tg's window): back to the file view.
  const slot = char?.slot;
  const lastSlot = useRef(slot);
  useEffect(() => {
    if (lastSlot.current !== undefined && slot !== lastSlot.current) {
      setSub(null);
      setFrom(null);
      setSection(null);
      setFocusSec('body');
      setSwitchAt(0);
    }
    lastSlot.current = slot;
  }, [slot]);
  useEffect(() => {
    if (!switchAt) {
      return;
    }
    const t = window.setTimeout(() => setSwitchAt(0), SWITCH_MS);
    return () => window.clearTimeout(t);
  }, [switchAt]);

  // Stale: char_rev (every tick) ahead of the last push for 2 s asks again, once per 5 s.
  const behind = !!char && (data.char_rev ?? 0) > char.rev;
  const lastAsk = useRef(0);
  useEffect(() => {
    if (!behind) {
      return;
    }
    const t = window.setTimeout(() => {
      if (Date.now() - lastAsk.current >= STALE_EVERY) {
        lastAsk.current = Date.now();
        act('char_open');
      }
    }, STALE_MS);
    return () => window.clearTimeout(t);
  }, [behind, data.char_rev]);

  // Escape: up one level; at the file view, back to the tab before.
  useBack(sub ? closeSub : section ? toFile : onLeave || null);

  const nav: CharNav = {
    dir,
    turn: (by) => setDir((d) => nextDir(d, by)),
    sub: (node, crumb, at) => {
      setFrom(null);
      setSub({ node, crumb, from: at ?? null });
    },
    closeSub,
    subOpen: !!sub,
    from,
    quiet,
  };

  const NAME = safe(String(char?.prefs.real_name ?? '')).toUpperCase();
  const caption = section ? NAME || 'PERSONNEL FILE' : 'PERSONNEL FILE';
  const crumbs: Crumb[] = [['CHARACTER', toFile]];
  if (section) {
    crumbs.push([TITLES[section], sub ? closeSub : null]);
    if (sub) {
      crumbs.push([sub.crumb, null]);
    }
  }

  let screen: ReactNode;
  if (!char) {
    screen = (
      <>
        <IdColumn
          pv={Math.min(14, Math.max(6, bodyRows(M) - 2.25))}
          uniform="blank"
        />
        <Ghost text="FETCHING YOUR FILE." />
      </>
    );
  } else if (!section) {
    screen = (
      <CharFile
        cat={cat}
        open={openSection}
        focus={focusSec}
        switching={!!switchAt}
        onSlot={(n) => {
          setSwitchAt(Date.now());
          act('char_slot', { slot: n });
        }}
        ghost={
          failed ? (
            <Ghost
              text="NO ANSWER FROM RECORDS."
              onRetry={() => {
                act('char_open');
                retry();
              }}
            />
          ) : undefined
        }
      />
    );
  } else if (section === 'body') {
    screen = <BodyEditor group={group} setGroup={setGroup} />;
  } else {
    // ROLES, TRAITS and KIT: the old editors inside the new frame until they are rebuilt.
    const full = section === 'traits';
    const box = full
      ? { x: 0, y: BODY_Y, w: 63, h: M - 4 }
      : { x: WORK_X - 1, y: BODY_Y, w: WORK_W + 2, h: M - 4 };
    const Editor =
      section === 'roles'
        ? RolesEditor
        : section === 'traits'
          ? TraitsEditor
          : KitEditor;
    screen = (
      <>
        {!full && <IdColumn pv={Math.min(14, bodyRows(M) - 2.25)} />}
        <Editor {...box} />
      </>
    );
  }

  return (
    <CharContext.Provider value={nav}>
      <CharBox caption={caption} />
      {!!section && <Crumbs crumbs={crumbs} onBack={sub ? closeSub : toFile} />}
      {screen}
      {!!sub && sub.node}
      <SpeciesConfirm />
    </CharContext.Provider>
  );
}
