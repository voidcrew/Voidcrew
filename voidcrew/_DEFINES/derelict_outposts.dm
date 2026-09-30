// Derelict outposts (voidcrew/modules/derelict_outposts/). One per round, unloaded until a ship docks.

/// Theme ids, one picked per round
#define DERELICT_THEME_XENO "xeno"
#define DERELICT_THEME_CULT "cult"
#define DERELICT_THEME_HAUNTED "haunted"
#define DERELICT_THEME_MONSTERS "monsters"
#define DERELICT_THEMES list(DERELICT_THEME_XENO, DERELICT_THEME_CULT, DERELICT_THEME_HAUNTED, DERELICT_THEME_MONSTERS)

/// derelict_state: on the chart with nothing loaded
#define DERELICT_STATE_DORMANT "dormant"
/// derelict_state: level, prison, power and theme going down
#define DERELICT_STATE_BUILDING "building"
/// derelict_state: built and never claimed
#define DERELICT_STATE_READY "ready"
/// derelict_state: claimed at least once; an ordinary player outpost from here on
#define DERELICT_STATE_CLAIMED "claimed"

/// How long a build may run before the watchdog gives up on it
#define DERELICT_BUILD_WATCHDOG (3 MINUTES)
/// Tries per zone band for an empty overmap tile at round start
#define DERELICT_PLACEMENT_TRIES 80

/// No hostile starts within this many tiles of the elevator alcove or the arrival point
#define DERELICT_SAFE_RADIUS 8
/// No hostile starts within this many tiles of the generator
#define DERELICT_GENERATOR_CLEAR_RADIUS 4
/// Hostiles start at least this many tiles apart
#define DERELICT_HOSTILE_SPACING 3
/// Most hostiles one derelict may spawn
#define DERELICT_MAX_HOSTILES 14
/// Most dressing atoms one derelict may place
#define DERELICT_MAX_DRESSING 160

/// Spawn-site health multipliers, by band
#define DERELICT_HEALTH_MULT_YELLOW 1.5
#define DERELICT_HEALTH_MULT_RED 1.8
#define DERELICT_BOSS_HEALTH_MULT_YELLOW 1.5
#define DERELICT_BOSS_HEALTH_MULT_RED 2

/// The mapped plasma leaves the power bay and is left in this many stacks of this many sheets
#define DERELICT_FUEL_STACKS 2
#define DERELICT_FUEL_SHEETS 5
/// The habitat's stack lies at least this far from the generator
#define DERELICT_FUEL_MIN_DISTANCE 8

/// The prison wing's entrance door, zero-based column and row of its map as authored (both styles: (9,1) one-based)
#define DERELICT_PRISON_DOOR_COLUMN 8
#define DERELICT_PRISON_DOOR_ROW 0
