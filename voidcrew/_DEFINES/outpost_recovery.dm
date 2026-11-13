// Outpost massacre and rehydration (voidcrew/modules/outpost_police/recovery_*.dm), wave 2 of the outpost police.
// Owner: R0 seams, frozen: packages never edit this file (one exception: R1's path rename changes OUTPOST_TRADER_MOB).
// Unit tests are compiled before this file, so a test uses the literal value with a comment naming the define.
// Crimes added for wave 2 (KILL_STAFF, GATE_TAMPER, ARMED_ROBBERY) are in outpost_police.dm with the others.

/// Guard for code on other branches that wants to know the recovery API is here
#define OUTPOST_RECOVERY_API

/**
 * The type of an outpost trader; a checkpoint guard is a subtype (`OUTPOST_TRADER_MOB/checkpoint_guard`).
 * For istype() and other expressions only: DM does not expand a define at the start of a type or proc
 * declaration, so declarations write the path out (recovery_robbery.dm's three forwarders). R1's path rename
 * (basic mob to /mob/living/carbon/human/npc/ambient_npc/outpost/trader) changes this line with the rest.
 */
#define OUTPOST_TRADER_MOB /mob/living/carbon/human/npc/ambient_npc/outpost/trader

// ===== STATE (recovery_core.dm, R2; spec-rehydrate 2) =====

/// /datum/outpost_recovery/var/state
#define OUTPOST_RECOVERY_NORMAL 0
#define OUTPOST_RECOVERY_TROUBLE 1
#define OUTPOST_RECOVERY_CLEANUP 2
#define OUTPOST_RECOVERY_RESTAFF 3
#define OUTPOST_RECOVERY_REFILL 4

/// No stars here and no NPC death for this long: the outpost is quiet
#define OUTPOST_RECOVERY_QUIET_TIME (2 MINUTES)
/// The first crew wave comes this long after the recovery call
#define OUTPOST_RECOVERY_FIRST_WAVE (1 MINUTES)
/// CLEANUP ends this long after quiet at the latest
#define OUTPOST_RECOVERY_CLEANUP_MAX (15 MINUTES)
/// CLEANUP ends early when no NPC body is left and this share of patrol stops is clean (percent)
#define OUTPOST_RECOVERY_CLEAN_SHARE 80
/// NPC bodies kept per outpost, officers included; past it the oldest NPC body is collected
#define OUTPOST_RECOVERY_BODY_CAP 24
/// A body still there this long after the outpost went quiet goes back to the base corpse sweep
#define OUTPOST_RECOVERY_SWEEP_FALLBACK (20 MINUTES)
/// REFILL brings one ambient arrival every this long...
#define OUTPOST_RECOVERY_REFILL_GAP_MIN (60 SECONDS)
/// ...to this long
#define OUTPOST_RECOVERY_REFILL_GAP_MAX (90 SECONDS)
/// Loose casings kept per outpost (should; only if a cheap hook exists)
#define OUTPOST_RECOVERY_CASING_CAP 200

// ===== CREWS (recovery_crews.dm; R3 morgue, R4 janitors; spec-rehydrate 3 and 4) =====

/// Morgue workers, and janitors, in a normal wave
#define OUTPOST_RECOVERY_CREW_SMALL 2
/// ...and in a big one
#define OUTPOST_RECOVERY_CREW_BIG 4
/// More NPC bodies than this calls the big wave
#define OUTPOST_RECOVERY_BIG_WAVE_BODIES 12
/// Officers escorting a wave when no officer is alive
#define OUTPOST_RECOVERY_ESCORT 2
/// Crew waves lost in a row -> delay of the next wave (4.2). Index 1 = one wave lost.
#define OUTPOST_RECOVERY_LOST_DELAYS list(2 MINUTES, 4 MINUTES, 8 MINUTES)
/// ...and its escort size
#define OUTPOST_RECOVERY_LOST_ESCORTS list(2, 4, 4)
/// This many waves lost in a row shuts the port...
#define OUTPOST_RECOVERY_LOST_SHUT 4
/// ...for this long, then the ladder starts again
#define OUTPOST_RECOVERY_PORT_SHUT_TIME (15 MINUTES)

/// A body with a conscious player this close is not free
#define OUTPOST_RECOVERY_FREE_RANGE 2
/// A body that was not free is tried again after this long
#define OUTPOST_RECOVERY_BODY_RETRY (60 SECONDS)
/// Loose limbs and organs this close to a body go in its bag
#define OUTPOST_RECOVERY_LIMB_RANGE 2
/// A patrol stop is clean when a worker on it finds no body and no mess this close
#define OUTPOST_RECOVERY_STOP_RANGE 6
/// Trays in the morgue room are found this close to its landmark (link_rooms())
#define OUTPOST_RECOVERY_MORGUE_REACH 3

// ===== LOSSES: the trader drop and the stick-up share one cap (1.3, 10) =====

/// The most one trader drop is worth, in credits
#define OUTPOST_TRADER_DROP_CAP 750
/// Drops and stick-up takings per outpost per round, all counters together
#define OUTPOST_RECOVERY_LOSS_CAP 1500

// ===== THE STICK-UP (recovery_robbery.dm, R7; spec-rehydrate 10) =====

/// The till pays this times the zone multiplier (1, 1.5, 2)
#define OUTPOST_HOLDUP_TILL 200
/// An emptied till is full again this long later
#define OUTPOST_HOLDUP_TILL_REFILL (30 MINUTES)
/// With the till empty, one shelf item worth at most this much
#define OUTPOST_HOLDUP_ITEM_CAP 100
/// The trader raises the alarm this long after the hand-over whatever happens...
#define OUTPOST_HOLDUP_ALARM_DELAY (30 SECONDS)
/// ...or when the robber is out of its sight or this many tiles off
#define OUTPOST_HOLDUP_ALARM_RANGE 8

// ===== THE GATE EMAG (trade/outpost_checkpoint.dm, R7; spec-rehydrate 9) =====

/// An emagged scanner keeps its gate down this long
#define OUTPOST_CHECKPOINT_EMAG_TIME (3 MINUTES)
/// ...and cannot be emagged again until this long after it came back
#define OUTPOST_CHECKPOINT_EMAG_COOLDOWN (5 MINUTES)

// ===== DIALOGUE =====
// Two files, so the crew lines (R4) and the stick-up lines (R7) never meet in a merge. Sections are the
// police profile's zone names (halcyon, quartermain, undertow), as in AMBIENT_STRINGS_POLICE.

/// The crews' lines (R4 writes every line, R3's included). Owner: R4.
#define AMBIENT_STRINGS_RECOVERY "outpost_recovery.json"
/// The recovery call on the police radio (R2)
#define RECOVERY_LINE_CALL "call"
/// A crew member finds the first body (R3)
#define RECOVERY_LINE_FIRST_BODY "first_body"
/// ...an officer's body (R3)
#define RECOVERY_LINE_OFFICER_BODY "officer_body"
/// Over the radio, one per body bagged (R3)
#define RECOVERY_LINE_BAGGED "bagged"
/// Over the radio, a body in a tray (R3)
#define RECOVERY_LINE_TRAY "tray"
/// Calling for the lift (R3, R4)
#define RECOVERY_LINE_LIFT "lift"
/// A mess they resent (R4)
#define RECOVERY_LINE_MESS "mess"
/// To a player walking on a wet or dirty floor (R4)
#define RECOVERY_LINE_MIND_FLOOR "mind_floor"

/// The stick-up and the gate guard's lines. Owner: R7.
#define AMBIENT_STRINGS_ROBBERY "outpost_robbery.json"
/// Held up (R7)
#define ROBBERY_LINE_HANDS_UP "hands_up"
/// Handing over the till (R7)
#define ROBBERY_LINE_HAND_OVER "hand_over"
/// The till is empty (R7)
#define ROBBERY_LINE_EMPTY "empty"
/// The alarm over the radio: %PLACE% and %LOOK% as in AMBIENT_STRINGS_POLICE (R7)
#define ROBBERY_LINE_ALARM "alarm"
/// The gate guard sees the scanner emagged (R7)
#define ROBBERY_LINE_GATE_DOWN "gate_down"
