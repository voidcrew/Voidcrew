// Ship Combat System Defines and Signals

// ========== SIGNALS ==========

/// Sent when a missile is fired from a ship: (obj/effect/ship_missile/missile, obj/structure/overmap/ship/target)
#define COMSIG_SHIP_MISSILE_FIRED "ship_missile_fired"

/// Sent when a missile impacts a ship: (obj/effect/ship_missile/missile, turf/impact_turf)
#define COMSIG_SHIP_MISSILE_IMPACT "ship_missile_impact"

/// Sent when a ship's shields are hit: (obj/effect/ship_missile/missile)
#define COMSIG_SHIP_SHIELD_HIT "ship_shield_hit"

/// Sent when a ship fires any weapon (used for cloaking decloak): ()
#define COMSIG_SHIP_WEAPON_FIRED "ship_weapon_fired"

/// Sent when a ship's cloak status changes: (cloaked)
#define COMSIG_SHIP_CLOAK_CHANGED "ship_cloak_changed"

// ========== MISSILE DEFINES ==========

/// Base damage for standard missiles
#define MISSILE_DAMAGE_STANDARD 50
/// Base damage for heavy missiles
#define MISSILE_DAMAGE_HEAVY 100
/// Base damage for light missiles
#define MISSILE_DAMAGE_LIGHT 25

/// Missile flight speed (tiles per decisecond, similar to meteors)
#define MISSILE_SPEED 2

/// Explosion ranges for missile impact
#define MISSILE_EXPLOSION_DEVASTATION 0
#define MISSILE_EXPLOSION_HEAVY 1
#define MISSILE_EXPLOSION_LIGHT 2
#define MISSILE_EXPLOSION_FLAME 2

// ========== LAUNCHER DEFINES ==========

/// Cooldown between missile fires (in deciseconds)
#define MISSILE_LAUNCHER_COOLDOWN 5 SECONDS

/// Power draw when firing
#define MISSILE_LAUNCHER_POWER_FIRE 500

// ========== SHIELD DEFINES ==========

/// Range at which ship shields can intercept missiles
#define SHIP_SHIELD_RANGE 3

// ========== COMBAT CONSOLE DEFINES ==========

/// Range at which ships can be targeted (in overmap tiles)
#define COMBAT_TARGETING_RANGE 1

/// Camera view size for targeting
#define COMBAT_CAMERA_VIEW_RANGE 7
