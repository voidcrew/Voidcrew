/// Backgrounds: owned by P0 (frozen). See data/backgrounds/spec.md.

// Keys (savefile values: never rename)
#define BACKGROUND_SPACEFARER "spacefarer"
#define BACKGROUND_CONVICT "convict"
#define BACKGROUND_HOMESTEADER "homesteader"
#define BACKGROUND_BOUNTY_HUNTER "bounty_hunter"
#define BACKGROUND_PIRATE "pirate"
#define BACKGROUND_ALL_KEYS list(BACKGROUND_SPACEFARER, BACKGROUND_CONVICT, BACKGROUND_HOMESTEADER, BACKGROUND_BOUNTY_HUNTER, BACKGROUND_PIRATE)

// State outcomes
#define BACKGROUND_OUTCOME_ONGOING "ongoing"
#define BACKGROUND_OUTCOME_DONE "done"
#define BACKGROUND_OUTCOME_FAILED "failed"
#define BACKGROUND_OUTCOME_ENDED "ended"      // respawned or replaced

// Convict scenarios and goals
#define BACKGROUND_CONVICT_SCENARIO_CELL 1
#define BACKGROUND_CONVICT_SCENARIO_MASSACRE 2
#define BACKGROUND_CONVICT_SCENARIO_ADRIFT 3
#define BACKGROUND_CONVICT_WEIGHT_CELL 50
#define BACKGROUND_CONVICT_WEIGHT_MASSACRE 30
#define BACKGROUND_CONVICT_WEIGHT_ADRIFT 20
#define CONVICT_GOAL_HAUL "haul"
#define CONVICT_GOAL_CAPTAIN "captain"
#define CONVICT_GOAL_CLEAN_SLATE "clean_slate"
#define CONVICT_GOAL_STASH "stash"
#define CONVICT_GOAL_WITNESS "witness"

// Roundstart shares (ruling Q13) and hull caps (ECO-6)
#define BACKGROUND_SHARE_PIRATE 0.25
#define BACKGROUND_SHARE_HUNTER 0.2
#define BACKGROUND_MAX_HOMESTEADERS 4
#define BACKGROUND_MAX_HULLS_PER_KIND 3

// Penitentiary
#define BACKGROUND_PEN_INMATES 8
#define BACKGROUND_PEN_GUARDS 6
#define BACKGROUND_PEN_ESCAPE_CELLS 8          // also the roundstart convict cap
#define BACKGROUND_PEN_CAPTURE_CELLS 6
#define BACKGROUND_PEN_CAPTURE_PER_CELL 2
#define BACKGROUND_CAPTURE_BODY_GRACE (10 MINUTES)  // OWN-1
#define BACKGROUND_POD_SEATS 2
#define BACKGROUND_ADRIFT_MAX_PODS 2           // roundstart
#define BACKGROUND_PODS_PER_CKEY 2             // per round
#define BACKGROUND_POD_SCUTTLE_TIME (5 MINUTES)
#define BACKGROUND_POD_DISTANCE_MIN 10
#define BACKGROUND_POD_DISTANCE_MAX 20
#define BACKGROUND_POD_LAUNCH_TIME (5 SECONDS)
#define ACCESS_PENITENTIARY "penitentiary"
#define ACCESS_PENITENTIARY_PODBAY "penitentiary_podbay"
#define ACCESS_PENITENTIARY_ARMORY "penitentiary_armory"
#define TRAIT_BACKGROUND_CONVICT "background_convict"
#define BACKGROUND_TRAIT "background"            // trait source

// Warrants (ECO-1)
#define BACKGROUND_WARRANT_BASE 1000            // green value at full time, before the zone multiplier
#define BACKGROUND_WARRANT_FRESH_SHARE 0.25
#define BACKGROUND_WARRANT_FULL_TIME (45 MINUTES)
#define BACKGROUND_WARRANT_TIER_SWING 0.1       // petty -10%, most wanted +10%
#define BACKGROUND_LAST_SEEN_INTERVAL (30 SECONDS)
#define BACKGROUND_RECORD_REASSERT (60 SECONDS)

// Goals
#define BACKGROUND_HUNTER_GOAL 3
#define BACKGROUND_PIRATE_GOAL 25000
#define BACKGROUND_CLEAN_SLATE_COST 20000

// Pirates
#define BACKGROUND_PIRATE_FLAG_INTERVAL (30 SECONDS)
#define BACKGROUND_ZONE_REFUSAL_COOLDOWN (20 SECONDS)
#define BACKGROUND_CRIMINAL_OFFERS 3
#define BACKGROUND_SHAKEDOWN_TARGET_MIN 1500
#define BACKGROUND_SHAKEDOWN_TARGET_MAX 3000

// Haulers (ECO-7, ECO-8)
#define BACKGROUND_HAULER_COUNT 2
#define BACKGROUND_HAULER_RESPAWN (20 MINUTES)
#define BACKGROUND_HAULER_HOLD_MIN 800
#define BACKGROUND_HAULER_HOLD_MAX 1200
#define BACKGROUND_HAULER_CASES 3
#define BACKGROUND_HAULER_CASE_PAY 200
#define BACKGROUND_HAULER_FENCE_DEMAND 6
#define BACKGROUND_HAULER_SURRENDER_TIME (3 MINUTES)

// Homestead
#define BACKGROUND_RAID_INTERVAL (40 MINUTES)
#define BACKGROUND_RAID_TELEGRAPH (60 SECONDS)
#define BACKGROUND_RAID_SIZE 3
#define BACKGROUND_RAID_SPAWN_DIST 70
#define BACKGROUND_HOMESTEAD_DAY_LENGTH (30 MINUTES)
#define BACKGROUND_HOMESTEAD_NIGHT_LENGTH (10 MINUTES)   // the last 10 of each 30
#define BACKGROUND_HOMESTEAD_NEEDS_INTERVAL (10 SECONDS)
#define BACKGROUND_HOMESTEAD_SAFE_RANGE 15
#define BACKGROUND_HOMESTEAD_FOOD_MIN 3
#define BACKGROUND_HOMESTEAD_RING 20
#define BACKGROUND_HOMESTEAD_LEASH 12
#define BACKGROUND_HOMESTEAD_LEAVE_CHECK (30 SECONDS)
#define BACKGROUND_CAVE_LADDERS_WANT 3
#define BACKGROUND_CAVE_LADDERS_MIN 2
#define BACKGROUND_CAVE_LADDERS_MAX 4
#define BACKGROUND_CAVE_LADDER_DIST_MIN 25
#define BACKGROUND_CAVE_LADDER_DIST_MAX 60
#define BACKGROUND_CAVE_LADDER_SPACING 20
#define TRAIT_HOMESTEAD_RESIDENT "homestead_resident"

// Metrics (category string must never equal a record_metric() argument name, voidcrew/_DEFINES/metrics.dm:1-9)
#define METRIC_BACKGROUND "background"

// Signals
/// On the ship that took the money: (obj/structure/overmap/ship/target, amount, source) ; source "siphon" or "surrender"
#define COMSIG_BACKGROUND_CREDITS_TAKEN "background_credits_taken"
/// On the ship the money was taken from: (obj/structure/overmap/ship/taker, amount, source)
#define COMSIG_BACKGROUND_CREDITS_LOST "background_credits_lost"
/// On the ship that was paid at its pad: (kind) ; kind "criminal", "pirate_ship" or "warrant"
#define COMSIG_BACKGROUND_BOUNTY_PAID "background_bounty_paid"
