// Mission signals (sent by mission datum)
#define COMSIG_MISSION_STARTED "mission_started"
#define COMSIG_MISSION_COMPLETED "mission_completed"
#define COMSIG_MISSION_FAILED "mission_failed"

// Mission difficulty levels
#define MISSION_DIFFICULTY_EASY 1
#define MISSION_DIFFICULTY_MEDIUM 2
#define MISSION_DIFFICULTY_HARD 3

/// target_zone_name before a target has resolved a zone band. Missions with no
/// overmap target keep this forever, so the board hides the zone tag on it.
#define MISSION_ZONE_UNKNOWN "Unknown Zone"

// Default config
#define DEFAULT_AVAILABLE_MISSIONS 5
#define DEFAULT_MAX_ACTIVE_MISSIONS 3
#define DEFAULT_MISSION_DURATION (30 MINUTES)
/// Board reroll wipes all five offers, so a short cooldown made it free to fish
/// for the top-paying contract type. Five minutes makes the posted board a hand
/// you play rather than one you redraw.
#define MISSION_REFRESH_COOLDOWN (5 MINUTES)
/// Unaccepted board offers older than this are rotated out by SSmissions
#define MISSION_BOARD_EXPIRY (20 MINUTES)

/**
 * Chance (percent) that any one offer generated for a ship WITHOUT Shuttle
 * Warfare Systems research is steered into the Neutral band.
 *
 * A crew with no shields and no guns cannot survive a contract that sends them
 * into Contested or Lawless space, and the board is the main thing telling a new
 * crew where to fly - so an unarmed ship's board should mostly point at work it
 * can actually do. Not 100: the deep-band offers that still show through are
 * what advertises the pay (and the vouchers) waiting once they research combat
 * gear, and a board that never mentions the rest of the map teaches nothing.
 * The preference is a bias, never a guarantee - a target list with nothing in
 * the Neutral band falls back to the normal roll (see
 * /datum/mission_target/proc/filter_by_preferred_zone).
 */
#define MISSION_UNARMED_GREEN_BIAS_PROB 70

/**
 * Research-point pay bands for the contracts that settle in points instead of
 * credits (voidcrew/modules/missions/missions/research.dm). A contract picks the
 * band that matches how much science its ask is worth; if it has an overmap
 * target, apply_zone_scaling() then multiplies it by the zone's research_mult.
 * Nothing else in the mission system should hand-write a point number.
 *
 * Priced against what a point actually buys and against the rest of the research
 * economy, so the board stays one faucet among several rather than the whole tap:
 *
 * - a techweb node costs 40 (tier 1) to 200 (tier 5), and the entire tg +
 *   voidcrew tree is roughly 16,000 points (code/__DEFINES/research.dm)
 * - one experiment pays 200 (research/edits/_experiments.dm)
 * - a dissection pays 100 base, 200/400/600 by tier
 * - the orbital survey console pays 250 (nebula) to 1000 (star) per object, and
 *   a telemetry contract is scored on scans the console already paid for
 *
 * So the top of this ladder - a HIGH band contract flown into Lawless space -
 * settles near one star survey, and the bottom sits under one experiment.
 */
#define MISSION_RESEARCH_PAY_LOW 150
#define MISSION_RESEARCH_PAY_MEDIUM 300
#define MISSION_RESEARCH_PAY_HIGH 500

// Overmap bounds for exploration missions (relative coords, 1 to OVERMAP_SIZE)
// Avoid edges (1 tile border) and some buffer
#define MISSION_OVERMAP_MIN_COORD 3
#define MISSION_OVERMAP_MAX_COORD (OVERMAP_SIZE - 2)

// What a mission does when its quest atom or target is lost mid-run
#define MISSION_QUEST_LOST_FAIL 0
#define MISSION_QUEST_LOST_RETARGET 1

/// How many times a retargeting mission may re-pick its target while active
#define MAX_MISSION_RETARGETS 2

/// How many times a field objective asks its site for a spawn turf before giving up
#define MISSION_FIELD_SPAWN_TRIES 6
/// Gap between those attempts
#define MISSION_FIELD_SPAWN_RETRY_DELAY (15 SECONDS)

/// Mobs a contract depends on. SSplanet_mobs sweeps every unclaimed living mob
/// off an empty planet after its grace period; without this it takes the marked
/// specimen, the poacher squad and the stranded survivor with it.
#define TRAIT_MISSION_FIELD_MOB "mission_field_mob"

// Results of offering an item to a mission's current objective
#define MISSION_ITEM_REFUSED 0
#define MISSION_ITEM_PROGRESS 1
#define MISSION_ITEM_COMPLETE 2

/// Weighted zone_mobs wave themes rolled per mission, who answers the noise
#define MISSION_WAVE_THEMES list(\
	/obj/effect/zone_mobs/pirate = 5,\
	/obj/effect/zone_mobs/syndicate = 4,\
	/obj/effect/zone_mobs/robot = 4,\
	/obj/effect/zone_mobs/undead = 3,\
	/obj/effect/zone_mobs/bug = 3,\
)
