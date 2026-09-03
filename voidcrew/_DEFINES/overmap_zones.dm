// Overmap Zone System Defines and Signals

// ========== ZONE TYPES ==========

/// Safe zone - no PvP allowed, ship weapons disabled
#define ZONE_GREEN 1
/// Caution zone - weapons disabled, but interdiction/boarding allowed
#define ZONE_YELLOW 2
/// Dangerous zone - full PvP, kill on sight
#define ZONE_RED 3

// Zone type names for display
#define ZONE_NAME_GREEN "Neutral Zone"
#define ZONE_NAME_YELLOW "Contested Zone"
#define ZONE_NAME_RED "Lawless Zone"

// Zone type descriptions
#define ZONE_DESC_GREEN "Safe space - ship weapons are disabled and PvP is prohibited."
#define ZONE_DESC_YELLOW "Caution - ship weapons are disabled, but interdiction and boarding are permitted."
#define ZONE_DESC_RED "Dangerous space - all combat is permitted. Enter at your own risk."

/// What the chart says about a red-band planet, on top of its terrain description.
/// Every planet in the red ring carries /datum/weather/rad_storm/planetary alongside its
/// own climate - see apply_planet_level_traits() - and this is the only thing that says so
/// before a crew is standing in one.
#define PLANET_HAZARD_NOTE_RADSTORM "Radiation fronts sweep this world."

// Zone colors for UI/display
#define ZONE_COLOR_GREEN "#00ff00"
#define ZONE_COLOR_YELLOW "#ffff00"
#define ZONE_COLOR_RED "#ff0000"

// ========== ZONE CONFIGURATION ==========

// Zones are dealt once at roundstart and never move, so there are no rotation
// or shift-warning knobs here - the defines that used to sit above this line
// were left over from a rotating-zone design and nothing read them.

/// Time required to cross between zones (in deciseconds) - 10 seconds
#define ZONE_TRANSITION_TIME (10 SECONDS)

/// Zone distribution ratios (distance from center, as percentage of max radius)
/// Inner ring: 0% to 33% = closest to sun (most dangerous due to sun + lawless zone)
/// Middle ring: 33% to 66%
/// Outer ring: 66% to 100%
#define ZONE_INNER_RING_RATIO 0.33
#define ZONE_MIDDLE_RING_RATIO 0.66
// Outer is implicitly 1.0

// ========== ZONE SIGNALS ==========

/// Sent when an overmap turf's zone changes: (old_zone_type, new_zone_type)
#define COMSIG_TURF_ZONE_CHANGED "turf_zone_changed"

/// Sent globally when any zone shift occurs: (list/affected_turfs)
#define COMSIG_GLOB_ZONE_SHIFT "!zone_shift"

/// Sent globally before a zone shift: (seconds_remaining)
#define COMSIG_GLOB_ZONE_SHIFT_WARNING "!zone_shift_warning"

/// Sent when a ship enters a new zone type: (old_zone_type, new_zone_type)
#define COMSIG_SHIP_ZONE_CHANGED "ship_zone_changed"

// ========== ZONE WEAPON RESTRICTIONS ==========

/// Check if weapons are allowed in a zone type
#define ZONE_WEAPONS_ALLOWED(zone_type) (zone_type == ZONE_RED)

/// Check if interdiction is allowed in a zone type
#define ZONE_INTERDICTION_ALLOWED(zone_type) (zone_type != ZONE_GREEN)

/// Check if forced docking is allowed in a zone type
#define ZONE_FORCED_DOCKING_ALLOWED(zone_type) (zone_type != ZONE_GREEN)

// ========== ZONE PLANET EFFECTS ==========
// Planet surfaces feel their overmap zone: storms come more often, hit with
// less warning and last longer in dangerous space, and biome fauna spawns
// denser and meaner. Zones scale AMOUNTS, never kinds, deeper bands mine
// more of the same ores, but no zone-gated ore types or loot tables.

/// Multiplier on the downtime between scheduled storms (SSweather's 5-10 minute gap) per zone
#define ZONE_WEATHER_DOWNTIME_MULT_YELLOW 0.75
#define ZONE_WEATHER_DOWNTIME_MULT_RED 0.5

/// Multiplier on the storm warning time (telegraph) per zone
#define ZONE_WEATHER_TELEGRAPH_MULT_YELLOW 0.75
#define ZONE_WEATHER_TELEGRAPH_MULT_RED 0.5

/// Multiplier on how long a storm lasts once it hits, per zone
#define ZONE_WEATHER_DURATION_MULT_YELLOW 1.25
#define ZONE_WEATHER_DURATION_MULT_RED 1.5

/// Multiplier on biome mob spawn chance during planet terrain population, per zone
#define ZONE_PLANET_MOB_CHANCE_MULT_YELLOW 1.3
#define ZONE_PLANET_MOB_CHANCE_MULT_RED 1.6

/// Chance (percent) that a biome mob roll upgrades to the biome's dangerous_mob_spawn_list, per zone
#define ZONE_PLANET_MOB_UPGRADE_PROB_YELLOW 20
#define ZONE_PLANET_MOB_UPGRADE_PROB_RED 40

/**
 * How many structure spawners (tendrils, monster nests, demonic portals) a planet may
 * seed, per zone. These are NOT managed by SSplanet_mobs: they are permanent terrain and
 * each holds a standing group of mobs for the whole round, so the per-planet fauna cap
 * does not bound them. Without a budget the raw biome roll seeds ~20 of them on a lava
 * planet - roughly 60 permanent hostiles on top of the 15 SSplanet_mobs allows.
 */
#define ZONE_PLANET_SPAWNER_BUDGET_GREEN 3
#define ZONE_PLANET_SPAWNER_BUDGET_YELLOW 5
#define ZONE_PLANET_SPAWNER_BUDGET_RED 8

/// Minimum tiles between two structure spawners on a planet. Keeps the budget spread out
/// instead of letting the whole allowance land in one corner of the map.
#define ZONE_PLANET_SPAWNER_SPACING 24

/**
 * How many anomalies a planet may seed, per zone.
 *
 * Anomalies used to be a ship-scoped dynamic event, which made them something that
 * happened TO a crew in their own corridors with nowhere to stand back to. On a planet
 * the same object reads the opposite way: it is stationary, it is visible from across
 * open ground, and the crew chose to walk over there. Approaching one is a decision, and
 * a crew carrying a neutralizer (Anomaly Research, tier 3) gets a core out of it.
 *
 * Green stays empty for the same reason it seeds no megafauna: it is where a crew takes
 * its first landing.
 */
#define ZONE_PLANET_ANOMALY_BUDGET_GREEN 0
#define ZONE_PLANET_ANOMALY_BUDGET_YELLOW 2
#define ZONE_PLANET_ANOMALY_BUDGET_RED 3

/// Minimum tiles between two planet anomalies, so a budget of 3 is three separate finds
/// rather than one lethal clearing.
#define ZONE_PLANET_ANOMALY_SPACING 20

/// Cap on random turf draws while placing the anomaly budget. A planet whose open ground
/// is nearly all taken simply seeds fewer than its budget rather than spinning.
#define PLANET_ANOMALY_PLACEMENT_ATTEMPTS 400

/// Multiplier on ore mined per planet rock wall (mineralAmt), per zone, green stays baseline (x1). Applied in /turf/closed/mineral/proc/zone_scaled_ore_amount()
#define ZONE_PLANET_ORE_MULT_YELLOW 1.5
#define ZONE_PLANET_ORE_MULT_RED 2

