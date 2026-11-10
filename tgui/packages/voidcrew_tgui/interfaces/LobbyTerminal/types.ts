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

export type TabId = 'crews' | 'shipyard' | 'housing';

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
  code_wait?: number;
};

export type HousingData = {
  outposts?: Outpost[];
};

// ---------------------------------------------------------------------------

export type LobbyData = ShellData &
  ShellStatic &
  CrewsData &
  YardData &
  YardStatic &
  HousingData;

/**
 * Every action and its params. Shell actions are handled in lobby_bezel.dm; prefixed ones
 * go to their section (crew_* P2, yard_* P3, home_* P5).
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
};
