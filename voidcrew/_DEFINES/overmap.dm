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
 * How far a ship can SEE, in overmap tiles — the free, unresearchable ring the
 * old camera console rendered with view(SHIP_VIEW_RANGE). Everything physically
 * inside it draws on the helm chart with no research and no scanning.
 *
 * Deliberately distinct from the ship's SENSOR range (ship_sensors.dm), which
 * starts equal to this and grows with the radar research tree. Sensors do not
 * widen what the crew can see — they reach past sight, so a scan can chart
 * things into the waypoint list that were never visible. Keep the two apart:
 * collapsing them makes the whole radar tree a spectator upgrade.
 */
#define SHIP_VIEW_RANGE 4

//Possible ship states
#define OVERMAP_SHIP_IDLE "idle"
#define OVERMAP_SHIP_FLYING "flying"
#define OVERMAP_SHIP_ACTING "acting"
#define OVERMAP_SHIP_DOCKING "docking"
#define OVERMAP_SHIP_UNDOCKING "undocking"

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
/// Open span between the two maximum-size ship berths in a landable meteor storm reservation
#define EVENT_FIELD_WIDTH 48
#define EVENT_FIELD_HEIGHT 48
/// Extra vacuum kept around each maximum-size ship berth, beyond the normal reservation padding
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
