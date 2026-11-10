/**
 * Data contract for the dock terminal lobby (DM: voidcrew/modules/lobby_terminal/).
 *
 * Shared keys are fixed. Section owners may ADD optional keys in their own section; never
 * rename a shared key (a drifted key reads as undefined, i.e. "off", forever).
 *
 * DM has no booleans: every flag arrives as 0/1 (BooleanLike). Never write `flag && <Jsx/>`.
 */
import type { BooleanLike } from 'tgui-core/react';

// ---------------------------------------------------------------------------
// Shell (2.1): header, bezel, notice. Owner: P1.
// ---------------------------------------------------------------------------

export type Phase = 'loading' | 'pregame' | 'setup' | 'playing' | 'ended';

export type NoticeKind = 'ok' | 'warn' | 'bad';

export type Notice = {
  text: string;
  /** ok: the CONFIRMED box. warn: one amber line. bad: one red line. */
  kind: NoticeKind;
  /** world.time when it was set. */
  at: number;
};

export type TabId = 'crews' | 'shipyard' | 'housing' | 'character';

/** bezel.json from the art package (all numbers are 1x pixels). Null: placeholder bezel. */
export type BezelSpec = {
  scale?: { min_width?: number; base_height?: number };
  [key: string]: unknown;
};

export type ShellData = {
  phase: Phase;
  /** playing: deciseconds since round start. loading/pregame: countdown seconds, -1 = delayed. Else 0. */
  clock: number;
  online: number;
  ready: BooleanLike;
  prefs_ready: BooleanLike;
  can_observe: BooleanLike;
  /** 0 none or disabled, 1 open polls, 2 new polls. */
  polls: 0 | 1 | 2;
  /** Position in the popcap queue, 0 when not queued. */
  queue: number;
  /** Admins before the round: [players ready, admins ready, admins]. Null otherwise. */
  admin_ready: [number, number, number] | null;
  notice: Notice | null;
  /** The server asks the client to switch tab; act on each new serial. */
  tab_request: { tab: TabId; serial: number } | null;
};

export type ShellStatic = {
  wiki: BooleanLike;
  localhost_admin: BooleanLike;
  /** Port name for the header, or null (header reads "BERTH OFFICE"). */
  port: string | null;
  bezel: BezelSpec | null;
};

// ---------------------------------------------------------------------------
// CREWS (2.2). Owner: P2.
// ---------------------------------------------------------------------------

export type CrewJob = {
  /** REF(job), a key of ship.job_slots. */
  ref: string;
  title: string;
  /** Open slots. */
  open: number;
  /** FALSE when banned or short on playtime: SIGN ON greys out. */
  ok: BooleanLike;
};

export type Crew = {
  ref: string;
  name: string;
  /** Hull class (source_template.short_name). */
  cls: string;
  /** Crew aboard (length(manifest)). */
  crew: number;
  memo: string;
  locked: BooleanLike;
  cleared: BooleanLike;
  applied: BooleanLike;
  /** Crew-only airlocks. */
  doors: BooleanLike;
  /** Seconds until PING CREW is allowed again. */
  ping_wait: number;
  /** Seconds until a cryo rejoin is allowed. */
  rejoin_wait: number;
  /** Seconds left on a wrong-code lockout. */
  code_wait: number;
  jobs: CrewJob[];
};

export type CrewsData = {
  crews?: Crew[];
};

// ---------------------------------------------------------------------------
// SHIPYARD (2.3). Owners: P3 (DM), P4 (UI).
// ---------------------------------------------------------------------------

export type PartClass = 'combat' | 'science' | 'trade' | 'misc';
export type Parts = Partial<Record<PartClass, number>>;
/** [job title, slots] */
export type CrewLine = [string, number];

export type Finish = {
  id: string;
  name: string;
  desc: string;
  cost: Parts;
  def: BooleanLike;
  /** Slot keys this finish offers. */
  slots: string[];
  jobs: CrewLine[];
};

export type HullSlot = {
  key: string;
  label: string;
};

export type Module = {
  id: string;
  name: string;
  desc: string;
  slot: string;
  cost: Parts;
  def: BooleanLike;
  /** Finish ids this module is offered with, or null for every finish. */
  themes: string[] | null;
  /** Crew per finish id ("" = any finish). */
  jobs: Record<string, CrewLine[]>;
};

export type Hull = {
  /** "[type]" */
  id: string;
  name: string;
  short: string;
  desc: string;
  cost: Parts;
  free: BooleanLike;
  finishes: Finish[];
  slots: HullSlot[];
  modules: Module[];
  /** Crew of a hull with no finishes (template job_slots). Hulls with finishes use Finish.jobs. */
  jobs?: CrewLine[];
  /** build_ship_preview_data(hull), unchanged. */
  preview: unknown;
};

export type Owned = {
  hulls: string[];
  finishes: Record<string, string[]>;
  modules: Record<string, string[]>;
};

/** Saved ship card (2.5). Field names follow the mockup; the ship-saving PR maps to them. */
export type SaveCard = {
  slot: number;
  name: string;
  /** Class line, e.g. "Goon-class Scout". */
  class: string;
  mass?: number;
  crew?: number;
  /** Why it can't load now, or null. */
  denial: string | null;
  /** UNDER WAY: the original hull is still in service. */
  locked: BooleanLike;
  funds?: number;
  research?: number;
  /** Encoded floor plan for the line drawing. */
  plan?: string;
  /** [label, count, colour class] */
  fit?: [string, number, string][];
  lab?: number;
  cargo?: number;
};

export type YardData = {
  account?: Parts | null;
  owned?: Owned | null;
  free_ships?: BooleanLike;
  can_requisition?: BooleanLike;
  /** Name of the crew the player would leave by founding a new one, or null. */
  crew_change?: string | null;
  /** Bumped when a commission put the player aboard: drop the fit. */
  fit_serial?: number;
  /** Saved ships, null entries for empty slots. Null hides the SAVED SHIPS box. Always sent by the shell. */
  saves: (SaveCard | null)[] | null;
};

export type YardStatic = {
  /** Only after yard_open. */
  catalog?: Hull[] | null;
};

// ---------------------------------------------------------------------------
// HOUSING (2.4). Owner: P5.
// ---------------------------------------------------------------------------

export type OutpostMode = 'open' | 'password' | 'approved' | 'closed';

export type Outpost = {
  ref: string;
  name: string;
  mode: OutpostMode;
  residents: number;
  cleared: BooleanLike;
  /** Short in-character reason MOVE IN is refused, or null. */
  denial: string | null;
  /** Seconds left on a wrong-code lockout. */
  code_wait?: number;
  /** INVITE outposts: the player may ask to move in. */
  can_ask?: BooleanLike;
  /** A move-in request from this player is still fresh. */
  asked?: BooleanLike;
};

export type HousingData = {
  outposts?: Outpost[];
};

// ---------------------------------------------------------------------------
// CHARACTER (CHARACTER-PLAN 2.1). Owners: C1 (DM), C2 (preview), C3 (file + BODY),
// C4 (ROLES / TRAITS / KIT).
//
// The big catalog (choices, display names, quirk_info, loadout_tabs, species) is tg's own
// preferences.json, read through usePrefsCatalog() as ServerData. The keys below are only
// the per-player state.
// ---------------------------------------------------------------------------

/** Ship role level: 1 LOW, 2 MED, 3 HIGH (JP_*). Absent from CharData.roles = NEVER. */
export type RoleLevel = 1 | 2 | 3;

/** BYOND dirs the preview renders: NORTH 1, SOUTH 2, EAST 4, WEST 8. */
export type CharDir = 1 | 2 | 4 | 8;

/** One packed loadout item (tg's loadout_list entry, INFO_* keys). */
export type CharKitItem = {
  /** GAGS colours, "#rrggbb" joined, one per colour slot. */
  greyscale?: string;
  /** Custom name; the server escapes it and caps it at KIT_NAME_MAX. */
  name?: string;
  /** Reskin option key. */
  reskin?: string;
};

/** A species change waiting on CHANGE / CANCEL because taken quirks don't fit it. */
export type CharConfirm = {
  kind: 'species';
  /** The species id asked for. */
  value: string;
  /** Names of the quirks it would drop. */
  quirks: string[];
};

/** The char block. Pushed as a one-off update on char_open, after each edit and on slot change. */
export type CharData = {
  /** char_rev at the time of the push. */
  rev: number;
  /** 1-based. */
  slot: number;
  /** Saved names, null for an empty slot. Length = max_save_slots (3, or 8 for BYOND members). */
  slots: (string | null)[];
  /**
   * savefile_key -> compile_ui_data() for every accessible PREFERENCE_CHARACTER preference.
   * A key that is absent is not shown (the server's accessibility rules pick the rows).
   */
  prefs: Record<string, any>;
  /** Taken quirks, sanitize_css_class_name keys as tg sends. */
  quirks: string[];
  /** Quirks the current species can't take. */
  quirks_blocked: string[];
  /**
   * ship_category_preferences: category -> level. Absent = NEVER. At most one category is
   * HIGH: the server demotes the old HIGH to MED when another is set HIGH (Q3).
   */
  roles: Record<string, RoleLevel>;
  /** Packed loadout: item typepath -> details. */
  kit: Record<string, CharKitItem>;
  /** Job category the preview wears. */
  dress: string;
  confirm: CharConfirm | null;
};

export type CharStatic = {
  /** [category, examples] in GLOB.job_categories order; examples from the roundstart job pool. */
  roles: [category: string, examples: string][];
  /** Recolourable loadout item path -> number of GAGS colour slots. */
  kit_colors: Record<string, number>;
};

/** One rendered facing of the preview. png is base64 PNG data, no data: prefix. */
export type CharPreview = { key: string; dir: CharDir; png: string } | null;

export type CharacterData = {
  /** Sent every tick; tells the client whether its last push is stale. */
  char_rev?: number;
  /** One-off pushes: these keep their last pushed value between pushes. */
  char?: CharData;
  char_static?: CharStatic;
  char_preview?: CharPreview;
};

/**
 * BODY rows, top to bottom. A row shows only when its savefile key is in CharData.prefs.
 * Species feature keys not listed here still show, as generic rows after the species ones.
 * underwear, undershirt, socks and hair_gradient(+_color) are the owner's extra rows (Q1).
 */
export const BODY_KEYS = [
  'real_name',
  'age',
  'species',
  'body_type',
  'gender',
  'background',
  'skin_tone',
  'hairstyle_name',
  'hair_color',
  'hair_gradient',
  'hair_gradient_color',
  'facial_style_name',
  'facial_hair_color',
  'feature_mcolor',
  'feature_ethcolor',
  'eye_color',
  'voice_pack',
  'backpack',
  'jumpsuit_style',
  'underwear',
  'undershirt',
  'socks',
] as const;

/** Colour keys that get the native picker ([ PICKER ], char_color_pick). Kit colours never do (Q4). */
export const NATIVE_COLOR_KEYS = [
  'hair_color',
  'hair_gradient_color',
  'facial_hair_color',
  'feature_mcolor',
  'eye_color',
] as const;

/** MAX_NAME_LEN (code/__DEFINES/say.dm): character names and kit item names. */
export const NAME_MAX = 42;
export const KIT_NAME_MAX = NAME_MAX;
/** AGE_MIN / AGE_MAX (code/__DEFINES/mobs.dm). */
export const AGE_MIN = 18;
export const AGE_MAX = 85;

/** The PERSONNEL FILE sections, each an editor sub-screen. Null in CharacterTab = the file view. */
export type CharSection = 'body' | 'roles' | 'traits' | 'kit';

/** A block of cells (x, y = top-left column and row; w, h = columns and rows) handed to an editor. */
export type CellBox = { x: number; y: number; w: number; h: number };

// ---------------------------------------------------------------------------

export type LobbyData = ShellData &
  ShellStatic &
  CrewsData &
  YardData &
  YardStatic &
  HousingData &
  CharacterData;

/**
 * Every action and its params. Shell actions are handled in lobby_bezel.dm; prefixed ones
 * go to their section (crew_* P2, yard_* P3, home_* P5, char_* C1/C2).
 */
export type LobbyActions = {
  join: Record<string, never>;
  ready: Record<string, never>;
  observe: Record<string, never>;
  character: Record<string, never>;
  settings: Record<string, never>;
  wiki: Record<string, never>;
  polls: Record<string, never>;
  manifest: Record<string, never>;
  changelog: Record<string, never>;
  start_now: Record<string, never>;
  dismiss: Record<string, never>;
  /** Client display metrics, logged once per load. */
  metrics: {
    dpr: number;
    w: number;
    h: number;
    s: number;
    cols: number;
    rows: number;
  };
  crew_sign_on: { ship: string; job: string };
  crew_code: { ship: string; code: string };
  crew_apply: { ship: string; note: string };
  crew_ping: { ship: string };
  yard_open: Record<string, never>;
  yard_preview: { hull: string };
  yard_commission: {
    hull: string;
    finish: string;
    modules: Record<string, string>;
    leave_crew: 0 | 1;
  };
  yard_requisition: { leave_crew: 0 | 1 };
  yard_load: { slot: number; leave_crew: 0 | 1 };
  home_move_in: { outpost: string; code?: string };
  home_request: { outpost: string };
  /** Sends char, char_static and preferences.json; queues the preview. */
  char_open: Record<string, never>;
  /** Saves, then switches to that slot (1-based). There is no delete (Q5). */
  char_slot: { slot: number };
  /** One PREFERENCE_CHARACTER preference. confirm is only set by the server's own re-run. */
  char_set: { key: string; value: unknown; confirm?: 0 | 1 };
  char_random_name: Record<string, never>;
  /** BYOND's native colour dialog for a BODY colour key (NATIVE_COLOR_KEYS). */
  char_color_pick: { key: string };
  char_voice_play: Record<string, never>;
  /** level 0 = NEVER. Setting 3 (HIGH) demotes any other HIGH to MED (Q3). */
  char_role: { category: string; level: 0 | RoleLevel };
  char_quirk: { quirk: string; on: 0 | 1 };
  /** path: loadout item typepath. */
  char_kit: { path: string; on: 0 | 1 };
  /** slot: 0-based GAGS colour slot; color "#rrggbb". */
  char_kit_color: { path: string; slot: number; color: string };
  /** Renaming is on (Q2). An empty name clears it. */
  char_kit_name: { path: string; name: string };
  char_kit_skin: { path: string; skin: string };
  /** Preview only: which category's uniform the mannequin wears. */
  char_dress: { category: string };
  /** Asks for that facing when it isn't cached for the current look. */
  char_turn: { dir: CharDir };
  /** Answers CharData.confirm. */
  char_confirm: { ok: 0 | 1 };
};
