// Z level of the overmap
#define OVERMAP_Z_LEVEL 1 // aka centcom z

// size of the overmap (OVERMAP_SIZE x OVERMAP_SIZE)
#define OVERMAP_SIZE 51 // keep this odd to provide a centre tile

// These overmap coords are configured to place it in the top left of the z level
#define OVERMAP_LEFT_SIDE_COORD 1
#define OVERMAP_RIGHT_SIDE_COORD (OVERMAP_LEFT_SIDE_COORD + (OVERMAP_SIZE - 1))

#define OVERMAP_NORTH_SIDE_COORD (world.maxy)
#define OVERMAP_SOUTH_SIDE_COORD (OVERMAP_NORTH_SIDE_COORD - (OVERMAP_SIZE - 1))

/**
 * How far a ship can SEE, in overmap tiles, the free, unresearchable ring the
 * old camera console rendered with view(SHIP_VIEW_RANGE). Everything physically
 * inside it draws on the helm chart with no research and no scanning.
 *
 * Deliberately distinct from the ship's SENSOR range (ship_sensors.dm), which
 * starts equal to this and grows with the radar research tree. Sensors do not
 * widen what the crew can see. They reach past sight, so a scan can chart
 * things into the waypoint list that were never visible. Keep the two apart:
 * collapsing them makes the whole radar tree a spectator upgrade.
 */
#define SHIP_VIEW_RANGE 4

/// Longest join password a captain may set on a player-created hull
#define SHIP_JOIN_PASSWORD_MAX_LEN 24

/**
 * Crew applications (voidcrew/modules/captain_management/join_applications.dm).
 *
 * The way onto a locked hull for someone who does not have the password: the lobby
 * player asks, the captain reads their ckey and answers. A password stops being a wall
 * once there is a door beside it, which is the whole point - crews lock up because the
 * alternative is no control at all, not because they want an empty ship.
 */
/// Longest note a lobby player may attach to a crew application
#define SHIP_JOIN_APPLICATION_MSG_MAX_LEN 200
/// A pending application nobody answers gives up after this. Sized for "the captain is
/// mid-fight" rather than "the captain logged off"; there is no way to tell the two apart
/// from the lobby, so the applicant gets told either way instead of waiting forever.
#define SHIP_JOIN_APPLICATION_TIMEOUT (5 MINUTES)
/// How long a ckey must wait to apply to the same hull again after giving up or timing out
#define SHIP_JOIN_APPLICATION_COOLDOWN (2 MINUTES)
/// Same, after an outright refusal. Longer, because "no" should not have to be typed twice.
#define SHIP_JOIN_APPLICATION_DENY_COOLDOWN (5 MINUTES)
/// Most pending applications one hull holds at once, so a crowd cannot bury the review list
#define SHIP_JOIN_APPLICATION_MAX_PENDING 10

//Crew application states
#define SHIP_APPLICATION_PENDING "pending"
#define SHIP_APPLICATION_DENIED "denied"
#define SHIP_APPLICATION_EXPIRED "expired"
#define SHIP_APPLICATION_WITHDRAWN "withdrawn"

//Possible ship states
#define OVERMAP_SHIP_IDLE "idle"
#define OVERMAP_SHIP_FLYING "flying"
#define OVERMAP_SHIP_ACTING "acting"
#define OVERMAP_SHIP_DOCKING "docking"
#define OVERMAP_SHIP_UNDOCKING "undocking"

/**
 * Derelict lifecycle (see SSovermap.sweep_derelicts()).
 *
 * Crew death was never the only way a ship empties: crews log off, cryo out, or walk
 * away, and none of those paths ever flagged the hull. Occupancy is the one honest
 * signal, so the sweep runs on it - deliberately with no carve-outs for crews that
 * are planetside, dead or logged off. A crew that is not aboard for this long IS the
 * abandoned ship. Getting it back afterwards is one claim at the helm.
 */
/// No living, connected player physically aboard for this long -> the hull is abandoned
/// (claimable derelict). Hulls that never had a crew at all skip the derelict window
/// and despawn outright.
#define SHIP_CREWLESS_ABANDON_TIME (30 MINUTES)
/// An abandoned hull older than this despawns for good, releasing its berth, its map
/// zone pin and its transit reservation. Claiming stops the clock; merely being aboard
/// only postpones the teardown.
#define SHIP_DERELICT_DESPAWN_TIME (1 HOURS)
/// Cadence of the occupancy sweep. A minute of slack on half-hour clocks is nothing.
#define DERELICT_SWEEP_INTERVAL (1 MINUTES)
/**
 * A hull docked at a dynamic encounter - a planet, a space ruin, an asteroid field, the
 * crash site its own hull failure minted - with nothing alive at the site for this long
 * is force-undocked back into open space.
 *
 * A docked hull holds one of the site's berth flags and parks its overmap token in the
 * site's contents, and can_release_interior() refuses on either. Nothing else undocks a
 * hull whose crew is dead, so the site's map zone (or turf reservation, and often a whole
 * z-level under it) stayed pinned until the hull itself despawned - the crewless clock
 * plus the claim window, an hour and a half later. Five minutes instead. The derelict
 * clocks above are untouched and keep running; they just run in open space, where they
 * cost a hull rather than a hull and an encounter.
 */
#define SHIP_SITE_DEAD_UNDOCK_TIME (5 MINUTES)

/// Fraction of max_speed at or below which the helm's Dock button finishes the stop itself; any faster and the approach is refused.
#define DOCK_ASSIST_SPEED_FRACTION 0.5

/**
 * Hull integrity states.
 *
 * A latch, not a recomputed comparison. Integrity is derived from turf mass, and mass
 * moves a tile at a time - so a bare "is the percentage under X" test flips back and
 * forth across the boundary all through a repair, and anything hung off that test fires
 * once per flip. Each of these is entered exactly once per transition, and leaving one
 * needs a different threshold than entering it did (see the ..._FRACTION defines).
 */
/// Hull is sound, or damaged but not yet alarming.
#define SHIP_INTEGRITY_NOMINAL 0
/// Hull is failing. Klaxon loop is running; the ship still flies.
#define SHIP_INTEGRITY_CRITICAL 1
/// Hull has failed. Ship is dead in the water until repaired past the recovery threshold.
#define SHIP_INTEGRITY_DISABLED 2

/**
 * Hull damage bands, as fractions of the damage allowance (see integrity_damage_allowance()).
 *
 * The allowance is how much mass a hull may lose before it is disabled. Expressing the
 * other two bands as fractions *of the allowance* rather than of max_integrity is what
 * gives the state machine its hysteresis: a hull drops out of NOMINAL at 0.8 of its
 * allowance and only climbs back at 0.7, so the tile that trips the alarm is never also
 * the tile that clears it.
 */
/// Share of the allowance that must be lost before the critical klaxon starts.
#define SHIP_INTEGRITY_CRITICAL_FRACTION 0.8
/// Share of the allowance the hull must be repaired back inside to clear an alarm.
#define SHIP_INTEGRITY_RECOVERY_FRACTION 0.7
/// Share of a hull's baseline mass it may lose before being disabled.
#define SHIP_INTEGRITY_ALLOWANCE_FRACTION 0.5
/**
 * Floor on the damage allowance, in mass.
 *
 * Percentage bands alone are hostile to very small hulls: a scratch-built survey hull can
 * mass under 30, which puts half of it inside a single explosion and makes one welded wall
 * a double-digit swing. Below ~120 mass this floor takes over from the fraction, so a shack
 * has to lose essentially all of itself rather than half. It does not bind on any shipped
 * hull - the smallest, the medieval pirate sloop, masses 127.
 */
#define SHIP_INTEGRITY_MIN_ALLOWANCE 60

/**
 * How long a hull is held at its berth after an integrity failure.
 *
 * Armed the moment the hull latches into SHIP_INTEGRITY_DISABLED, not when it is patched up.
 * This is a floor on how quickly a wreck can be back in the void, not an extra wait tacked
 * onto the end of repairs: a crew that welds fast sits out whatever is left of it, and a crew
 * that spends longer than this rebuilding leaves the moment the alarm clears. Repairing to
 * 100% does not clear it - the ship is whole, the clamps are still on.
 *
 * Deliberately not the interdiction lockout, which also freezes hull construction (see
 * can_operate() in construction_console.dm and survey_expand() in hull_survey.dm). Sharing
 * that cooldown would lock the crew out of the repairs this timer exists to make them do.
 */
#define SHIP_INTEGRITY_UNDOCK_LOCKOUT (3 MINUTES)

// Space ruin spawning configuration
/// Maximum number of space ruins to spawn on the overmap
#define MAX_OVERMAP_SPACE_RUINS 24
/// Minimum number of space ruins to spawn
#define MIN_OVERMAP_SPACE_RUINS 12

// Asteroid mining now lives entirely on landable meteor storm / asteroid field hazard
// events (see events.dm) - a proper /datum/map_generator, same architecture as planets,
// carves one or more rock blobs into a lazily-loaded turf reservation, with real vacuum
// between and around them, instead of loading a static space-ruin template. The old
// asteroid-category space ruin signals (upstream asteroid1-6 etc.) were retired as the
// mining vehicle; they still spawn as ordinary ("unknown"-category) explorable ruins.
/// Minimum number of landable asteroid field events guaranteed on the overmap at roundstart,
/// so crews always have somewhere to mine in space (was MIN_OVERMAP_ASTEROID_SIGNALS, pointed
/// at ruin signals, before mining moved to field events)
#define MIN_OVERMAP_ASTEROID_FIELDS 3
/// Ore stack size bounds for seeded asteroid deposits (planet rock yields rand(1,5) off mining z-levels)
#define ASTEROID_ORE_AMOUNT_MIN 2
#define ASTEROID_ORE_AMOUNT_MAX 5
/// DEPRECATED, kept for reference only. A landable meteor storm used to size its own turf
/// reservation as this plus a maximum-size berth on all four sides (166x134), which no
/// reservation z-level could ever share - so every field minted a permanent 255x255 level.
/// Fields are now lattice tenants and take the whole of their slot's build region
/// (MAP_SLOT_RUIN_REGION_* in planet_defines.dm), four to a z-level.
#define EVENT_FIELD_WIDTH 48
#define EVENT_FIELD_HEIGHT 48
/// Extra vacuum kept around each maximum-size ship berth, beyond the normal berth padding.
/// The slot build region applies this through PLANET_DOCK_RUIN_CLEARANCE, which matches it.
#define EVENT_FIELD_DOCK_CLEARANCE 3
/// Moderate-field rock blob count bounds (see /datum/map_generator/cave_generator/asteroid_field
/// in AsteroidCaves.dm). Minor/majour subtypes override these along with the radius bounds.
#define EVENT_FIELD_MIN_BLOBS 34
#define EVENT_FIELD_MAX_BLOBS 42
/// Moderate-field blob radius bounds (tiles). Each blob is a jittered circle of rock - the
/// same technique /datum/map_generator/cave_generator/asteroid uses for its single field.
#define EVENT_FIELD_BLOB_RADIUS_MIN 5
#define EVENT_FIELD_BLOB_RADIUS_MAX 9
/// Target fraction of a hazard field's rock turfs that should bear ore after seeding - denser
/// than the old lone asteroid signal's ratio (~20%) since reaching this rock means flying
/// through live meteor traffic first (see ship_damage.dm apply_meteor_damage)
#define EVENT_FIELD_ORE_TARGET_RATIO 0.3

// Overmap parallax themes - what a crew sees out the windows while their ship sits
// over (or inside) an overmap object. Themes are applied by the context-parallax
// system (see "Context-aware overmap parallax" in
// voidcrew/modules/overmap/code/modules/overmap/_overmap.dm): add a define here plus
// a case in get_overmap_parallax_layer_types(), then tag any overmap object type (or
// /datum/overmap/planet) with one `parallax_theme = ...` line.
#define PARALLAX_THEME_ASTEROIDS "parallax_theme_asteroids"
#define PARALLAX_THEME_SPACE_GAS "parallax_theme_space_gas"
#define PARALLAX_THEME_ICEMOON "parallax_theme_icemoon"
#define PARALLAX_THEME_PLANET "parallax_theme_planet"

// Electrical storm SMES charging
/// Base energy fed into each SMES on a ship per electrical storm effect tick, before severity scaling.
/// Effect ticks are gated by the 3 second hazard cooldown, so this is roughly what a default
/// 50 kW SMES input terminal would deliver over the same window - a small passive freebie.
#define ELECTRICAL_STORM_SMES_CHARGE (150 KILO JOULES)
/// Charge multiplier for minor electrical storms (moderate uses intensity 1, majour intensity 2)
#define ELECTRICAL_STORM_SMES_CHARGE_MULT_MINOR 0.5

// Worldgen queue (voidcrew/modules/overmap/code/controllers/subsystem/worldgen_queue.dm)
/// Pass as a load_level() queue timeout to mean "build it only if the queue is free
/// right now, otherwise give up". For UI paths that must answer immediately rather
/// than hold a player's interface open while somebody else's planet finishes.
#define WORLDGEN_QUEUE_NO_WAIT 0

// Lighting settle wait (see /datum/controller/subsystem/overmap/proc/wait_for_lighting_settle)
/// How often the settle wait samples the lighting backlog.
#define LIGHTING_SETTLE_POLL (1 SECONDS)
/// Consecutive zero-backlog samples that count as "settled". Two, not one, because a
/// source feeds a corner feeds an object across separate fires - a single empty sample
/// can land in the gap between those stages.
#define LIGHTING_SETTLE_EMPTY_SAMPLES 2
/// Samples the backlog may fail to reach a new low before the wait gives up on it and
/// returns anyway. A backlog that stops SHRINKING is not a build still rendering, it is
/// ordinary live churn - a portal's light, a mob walking with a lantern, a storm - and
/// no amount of waiting will ever see the bottom of it.
#define LIGHTING_SETTLE_PLATEAU_SAMPLES 5
