// Outpost jobs (voidcrew/modules/outpost_jobs/): fixers at the trader outposts hand out crime jobs.
// Owner: P0 seams, frozen: packages never edit this file. A package that needs a private constant defines it
// at the top of its own file and #undefs it at the bottom.
// Unit tests are compiled before this file, so a test uses the literal value with a comment naming the define.
// Numbers come from data/outpost-jobs/balance/jobs_sim.py (spec 10).

// ===== THE JOBS =====

/// /datum/mission/fixer_job/var/job_kind
#define FIXER_JOB_SABOTAGE "sabotage"
#define FIXER_JOB_SMUGGLE "smuggle"
#define FIXER_JOB_BREAKIN "breakin"
#define FIXER_JOB_HIT "hit"
#define FIXER_JOB_EVIDENCE "evidence"
#define FIXER_JOB_JAILBREAK "jailbreak"

/// Base pay, green (L20). Yellow and red multiply by FIXER_ZONE_PAY.
#define FIXER_PAY_SABOTAGE 800
#define FIXER_PAY_SMUGGLE 600
#define FIXER_PAY_BREAKIN 1200
#define FIXER_PAY_HIT 1500
#define FIXER_PAY_EVIDENCE 1600
#define FIXER_PAY_JAILBREAK 2400
/// Pay by zone: green, yellow, red (index by ZONE_GREEN..ZONE_RED)
#define FIXER_ZONE_PAY list(1, 1.7, 2.6)

/// Deadlines for the deed (the mission's `duration`)
#define FIXER_TIME_SABOTAGE (20 MINUTES)
#define FIXER_TIME_SMUGGLE (40 MINUTES)
#define FIXER_TIME_BREAKIN (25 MINUTES)
#define FIXER_TIME_HIT (20 MINUTES)
#define FIXER_TIME_EVIDENCE (25 MINUTES)
#define FIXER_TIME_JAILBREAK (20 MINUTES)

/// Weight of each job on a fixer's slate
#define FIXER_WEIGHT_SABOTAGE 3
#define FIXER_WEIGHT_SMUGGLE 2
#define FIXER_WEIGHT_BREAKIN 3
#define FIXER_WEIGHT_HIT 3
#define FIXER_WEIGHT_EVIDENCE 2
#define FIXER_WEIGHT_JAILBREAK 2

/// The jailbreak's noise floor: a forced cell door is always three stars (L11)
#define FIXER_JAILBREAK_FLOOR 3

// ===== THE NETWORK =====

/// An offer to a ship stays open
#define FIXER_OFFER_TIME (3 MINUTES)
/// Jobs a fixer holds
#define FIXER_SLATE_SIZE 2
/// A taken entry is replaced after
#define FIXER_SLATE_REFILL (10 MINUTES)
/// An untaken entry is swapped after
#define FIXER_OFFER_EXPIRY (25 MINUTES)
/// Fixer jobs a ship holds
#define FIXER_JOBS_PER_SHIP 1
/// Jobs paid before the middle jobs (the safe, hits) are offered: /datum/mission/fixer_job/var/trust_tier
#define FIXER_TRUST_TIER1 2
/// Jobs paid before the top jobs (evidence, jailbreak) are offered
#define FIXER_TRUST_TIER2 5
/// A fixer's wait for a crew after a clean pay, a noisy pay, a failure
#define FIXER_REST_CLEAN (6 MINUTES)
#define FIXER_REST_NOISY (10 MINUTES)
#define FIXER_REST_FAILED (10 MINUTES)
/// After a counted crime against a fixer (L22)
#define FIXER_BURN_TIME (30 MINUTES)
/// An officer this close stops the talk
#define FIXER_OFFICER_RANGE 4
/// Reach of the talk radial
#define FIXER_TALK_RANGE 2
/// A finished job waits this long to be paid
#define FIXER_COLLECT_TIME (60 MINUTES)
/// Townspeople talk about a job this long
#define FIXER_GOSSIP_TIME (10 MINUTES)
/// A deadline that cannot fairly fall is put off by this (spec 4.6)
#define FIXER_DEADLINE_HOLD (5 MINUTES)

// ===== THE GRADE (spec 5) =====

/// The clean bonus, as a share of base
#define FIXER_BONUS_SHARE 0.6
/// Share of the bonus at noise 0, 1, 2, 3+ (index noise + 1, capped at the last)
#define FIXER_GRADE_SHARE list(1, 0.6, 0.25, 0)
/// The port reading looks back this far from the deed
#define FIXER_PORT_WINDOW (60 SECONDS)
/// A player's hit this recent makes a kill theirs
#define FIXER_HAND_WINDOW (30 SECONDS)

// ===== JOB PEOPLE AND THINGS =====

/// A sabotage target's integrity
#define FIXER_TARGET_INTEGRITY 150
/// Quiet sabotage times (the kiosk takes two steps)
#define FIXER_TAMPER_CRATE (8 SECONDS)
#define FIXER_TAMPER_KIOSK (6 SECONDS)
#define FIXER_TAMPER_RACK (12 SECONDS)
/// Cans a wrecked drinks machine drops
#define FIXER_KIOSK_CANS 4
/// Between a keeper's breaks, and how long a break lasts
#define FIXER_KEEPER_BREAK_LOW (3 MINUTES)
#define FIXER_KEEPER_BREAK_HIGH (5 MINUTES)
#define FIXER_KEEPER_AWAY_LOW (60 SECONDS)
#define FIXER_KEEPER_AWAY_HIGH (90 SECONDS)
/// Between a mark's calls, and how long a call lasts
#define FIXER_MARK_CALL_LOW (3 MINUTES)
#define FIXER_MARK_CALL_HIGH (5 MINUTES)
#define FIXER_MARK_CALL_TIME_LOW (40 SECONDS)
#define FIXER_MARK_CALL_TIME_HIGH (70 SECONDS)
/// Percent of yellow and red marks who carry a pistol
#define FIXER_MARK_ARMED_CHANCE 50
/// Beyond this the prisoner has lost his leader
#define FIXER_WARD_FOLLOW_RANGE 12
/// Lost this long, he gives up
#define FIXER_WARD_LOST_TIME (30 SECONDS)
/// A paid-for passenger leaves after this
#define FIXER_WARD_STAY_TIME (20 MINUTES)

/// fixer_job_spot() kinds: a tile with a wall neighbour, room for three side by side, a tile by the lift
#define FIXER_SPOT_WALL "wall"
#define FIXER_SPOT_OPEN "open"
#define FIXER_SPOT_ARRIVE "arrive"

// ===== FAILING (/datum/mission/fixer_job/var/fail_reason, spec 4.4) =====

/// The deadline passed before the deed
#define FIXER_FAIL_DEADLINE "deadline"
/// "Forget it.", or abandoned at the ship console
#define FIXER_FAIL_DROPPED "dropped"
/// The deed's subject is lost (the prisoner dies or is taken back, the goods are gone)
#define FIXER_FAIL_LOST "lost"
/// An outsider's hand did the deed
#define FIXER_FAIL_SPOILED "spoiled"
/// Staging found no room
#define FIXER_FAIL_STAGING "staging"
/// The outpost or the ship was deleted
#define FIXER_FAIL_GONE "gone"
/// The deed was done and nobody came for the money within FIXER_COLLECT_TIME
#define FIXER_FAIL_UNCOLLECTED "uncollected"

// ===== TALK (spec 2.3; radial option text, at most 16 characters, said aloud by the player) =====

#define FIXER_TALK_WORK "Got any work?"
#define FIXER_TALK_ELSE "What else?"
#define FIXER_TALK_TAKE "I'll take it."
#define FIXER_TALK_DONE "It's done."
#define FIXER_TALK_DROP "Forget it."

// ===== LINES (keys of each speaker's section in FIXER_STRINGS_FIXER, spec 6.1) =====

#define FIXER_LINE_NO_SHIP "no_ship"
#define FIXER_LINE_NO_TRUST "no_trust"
#define FIXER_LINE_WANTED "wanted"
#define FIXER_LINE_OFFICER "officer"
#define FIXER_LINE_NOTHING "nothing"
#define FIXER_LINE_BURNED "burned"
#define FIXER_LINE_TROUBLE "trouble"
#define FIXER_LINE_BUSY "busy"
#define FIXER_LINE_GONE "gone"
#define FIXER_LINE_TAKEN "taken"
#define FIXER_LINE_PAY_CLEAN "pay_clean"
#define FIXER_LINE_PAY_SOME "pay_some"
#define FIXER_LINE_PAY_LOUD "pay_loud"
#define FIXER_LINE_FAILED "failed"
#define FIXER_LINE_SPOILED "spoiled"
#define FIXER_LINE_WAIT "wait"
#define FIXER_LINE_NOT_YOURS "not_yours"
#define FIXER_LINE_WRONG_FIXER "wrong_fixer"
#define FIXER_LINE_OFFER_SABOTAGE "offer_sabotage"
#define FIXER_LINE_OFFER_SMUGGLE "offer_smuggle"
#define FIXER_LINE_OFFER_BREAKIN "offer_breakin"
#define FIXER_LINE_OFFER_HIT "offer_hit"
#define FIXER_LINE_OFFER_EVIDENCE "offer_evidence"
#define FIXER_LINE_OFFER_JAILBREAK "offer_jailbreak"
#define FIXER_LINE_REPEAT "repeat"
#define FIXER_LINE_IDLE "idle"

/// Speakers: the top-level sections of FIXER_STRINGS_FIXER. A missing key falls back to the stand-in's, then "...".
#define FIXER_VOICE_NAN "nan"
#define FIXER_VOICE_LOT "lot"
#define FIXER_VOICE_QUILL "quill"
#define FIXER_VOICE_STAND_IN "stand_in"

/// Offer and note tokens (offer_tokens() keys)
#define FIXER_TOKEN_NAME "{name}"
#define FIXER_TOKEN_LOOK "{look}"
#define FIXER_TOKEN_CLOCK "{clock}"
#define FIXER_TOKEN_PLACE "{place}"
#define FIXER_TOKEN_TO "{to}"

/// Text bounds in characters (spec 11): each token is cut to its bound with an ellipsis before it is used
#define FIXER_BOUND_NAME 28
#define FIXER_BOUND_LOOK 32
#define FIXER_BOUND_PLACE 24
#define FIXER_BOUND_TO 24
/// A spoken line after substitution
#define FIXER_BOUND_LINE 140
/// A note line, and lines on a note
#define FIXER_BOUND_NOTE_LINE 64
#define FIXER_NOTE_LINES 3

// ===== STRINGS =====

/// Where this feature's dialogue lives. ambient_dialogue_lines() reads only AMBIENT_STRINGS_DIR, so a reader loads
/// these into GLOB.string_cache first: load_strings_file(file, FIXER_STRINGS_DIR).
#define FIXER_STRINGS_DIR "voidcrew/modules/outpost_jobs/strings"
#define FIXER_STRINGS_FIXER "fixer.json"
#define FIXER_STRINGS_SABOTAGE "job_sabotage.json"
#define FIXER_STRINGS_SMUGGLE "job_smuggle.json"
#define FIXER_STRINGS_BREAKIN "job_breakin.json"
#define FIXER_STRINGS_HIT "job_hit.json"
#define FIXER_STRINGS_JAILBREAK "job_jailbreak.json"
