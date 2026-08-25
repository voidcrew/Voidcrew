/**
 * Shared payload types for the drug lab station interfaces
 * (DrugLabMixer, DrugLabCatalyst, DrugLabCrystallizer).
 *
 * Mirrors DRUG_LAB_STAGE_* / DRUG_STATION_* in
 * voidcrew/_DEFINES/drug_smuggling.dm and the payloads built by
 * /datum/drug_lab_session/ui_data_for() in
 * voidcrew/modules/drug_smuggling/lab_session.dm.
 */
import type { BooleanLike } from 'tgui-core/react';

/** DRUG_LAB_STAGE_*: batch progression */
export enum DrugLabStage {
  Loading = 1,
  Mixer = 2,
  Catalyst = 3,
  Crystallizer = 4,
  Done = 5,
}

/** DRUG_STATION_*: per-station score/attempt indices */
export enum DrugStation {
  Mixer = 1,
  Catalyst = 2,
  Crystallizer = 3,
}

export const STAGE_LABELS: Record<number, string> = {
  [DrugLabStage.Loading]: 'Loading precursors',
  [DrugLabStage.Mixer]: 'Mixing',
  [DrugLabStage.Catalyst]: 'Catalysis',
  [DrugLabStage.Crystallizer]: 'Crystallization',
  [DrugLabStage.Done]: 'Batch complete',
};

/** Fields every drug lab machine payload carries once a session is wired. */
export type DrugLabCommonData = {
  /** True while no cook session is wired to this machine, all other fields absent. */
  dormant: BooleanLike;
  /** DrugStation index of this machine. */
  station: number;
  /** DrugLabStage the batch is currently at. */
  stage: number;
  /** Locked/best scores per station, indexed [mixer, catalyst, crystallizer]. */
  scores: number[];
  /** This station's own locked/best score. */
  station_score: number;
  /** Attempts used at this station. */
  attempts_used: number;
  /** DRUG_STATION_ATTEMPTS. */
  max_attempts: number;
  /** Street name of the product being cooked. */
  street_name: string | null;
  /** Whether this station is the batch's current live stage. */
  is_live: BooleanLike;
};

export type MixerIngredient = {
  name: string;
  banked: BooleanLike;
};

/** DrugLabMixer's full payload (common + hopper game state). */
export type DrugLabMixerData = DrugLabCommonData & {
  ingredients: MixerIngredient[];
  hopper_count: number;
  total_rounds: number;
  game_active: BooleanLike;
  /** Current round of the active attempt, 1-based. */
  round: number;
  /** Rounds fully cleared this attempt. */
  rounds_completed: number;
  /** The current round's hopper order; null while no attempt is live. */
  sequence: number[] | null;
  /** Bumps whenever a fresh sequence is issued, replay the flash phase. */
  sequence_id: number;
  /** Presses of the current sequence matched so far (server-side cursor). */
  cursor: number;
  /** A finished attempt awaits the Commit/Retry choice. */
  awaiting_choice: BooleanLike;
  /** Capped score of the most recently finished attempt. */
  last_attempt_score: number;
  /** The last finished attempt scored under the hazard floor. */
  botched: BooleanLike;
  /** Score ceiling of the next attempt, or null when attempts are spent. */
  next_cap: number | null;
};

/**
 * Fields shared by the two client-run real-time games (catalyst rhythm,
 * crystallizer catch). The chart payloads only ride the data while an
 * attempt is live; the nonce ties a finish report to exactly one attempt.
 */
export type DrugLabRealtimeData = DrugLabCommonData & {
  /** A real-time attempt is in play at this station right now. */
  game_active: BooleanLike;
  /** Milliseconds of countdown the client renders before the chart's t=0. */
  lead_in_ms: number;
  /** Single-use token of the live attempt; echo it in the finish act. */
  nonce: string | null;
  /** A finished attempt awaits the Commit/Retry choice. */
  awaiting_choice: BooleanLike;
  /** Capped score of the most recently finished attempt. */
  last_attempt_score: number;
  /** The last finished attempt scored under the hazard floor. */
  botched: BooleanLike;
  /** Score ceiling of the next attempt, or null when attempts are spent. */
  next_cap: number | null;
};

/** One catalyst chart note: lane 1-based, t in ms from the chart's start. */
export type CatalystNote = {
  lane: number;
  t: number;
};

/** DrugLabCatalyst's full payload. */
export type DrugLabCatalystData = DrugLabRealtimeData & {
  /** DRUG_CATALYST_LANE_COUNT. */
  lane_count: number;
  /** The live attempt's note chart; null while no attempt is live. */
  chart: CatalystNote[] | null;
};

/** One crystallizer drop: col 1-based, t = tray-arrival ms, tainted flag. */
export type CrystallizerEntry = {
  col: number;
  t: number;
  tainted: BooleanLike;
};

/** DrugLabCrystallizer's full payload. */
export type DrugLabCrystallizerData = DrugLabRealtimeData & {
  /** DRUG_CRYSTALLIZER_COL_COUNT. */
  col_count: number;
  /** The live attempt's drop table; null while no attempt is live. */
  spawn_table: CrystallizerEntry[] | null;
};
