// Ship Combat System Defines and Signals

// ========== SIGNALS ==========

/// Sent when a missile is fired from a ship: (obj/effect/ship_missile/missile, obj/structure/overmap/ship/target)
#define COMSIG_SHIP_MISSILE_FIRED "ship_missile_fired"

/// Sent when a missile impacts a ship: (obj/effect/ship_missile/missile, turf/impact_turf)
#define COMSIG_SHIP_MISSILE_IMPACT "ship_missile_impact"

/// Sent when a ship fires any weapon (used for cloaking decloak): ()
#define COMSIG_SHIP_WEAPON_FIRED "ship_weapon_fired"

/// Sent when a ship's cloak status changes: (cloaked)
#define COMSIG_SHIP_CLOAK_CHANGED "ship_cloak_changed"

/// Sent when a ship enters an overmap hazard event: (obj/structure/overmap/event/hazard)
#define COMSIG_SHIP_HAZARD_TRIGGERED "ship_hazard_triggered"

// ========== MISSILE DEFINES ==========
/// Base damage for light missiles
#define MISSILE_DAMAGE_LIGHT 200
/// Base damage for standard missiles
#define MISSILE_DAMAGE_STANDARD 400
/// Base damage for heavy missiles
#define MISSILE_DAMAGE_HEAVY 600

/// Missile flight speed (delay in deciseconds per tile - lower = faster)
#define MISSILE_SPEED 0.5

/// Default explosion ranges for missile impact (standard missile)
#define MISSILE_EXPLOSION_DEVASTATION 1
#define MISSILE_EXPLOSION_HEAVY 3
#define MISSILE_EXPLOSION_LIGHT 5
#define MISSILE_EXPLOSION_FLAME 3

// ========== LAUNCHER DEFINES ==========

/// Cooldown between missile fires (in deciseconds)
#define MISSILE_LAUNCHER_COOLDOWN 5 SECONDS

/// Power draw when firing
#define MISSILE_LAUNCHER_POWER_FIRE 500

// ========== COMBAT CONSOLE DEFINES ==========

/// Range at which ships can be detected on sensors (in overmap tiles)
#define COMBAT_TARGETING_RANGE 3

/// Range at which missile lock can be activated (in overmap tiles)
#define COMBAT_MISSILE_LOCK_RANGE 2

/// Camera view size for targeting
#define COMBAT_CAMERA_VIEW_RANGE 7

// ========== INTERDICTOR DEFINES ==========

/// Time to lock on to a target ship (5 seconds)
#define INTERDICTOR_LOCK_TIME 5 SECONDS

/// Cooldown between interdiction attempts (5 minutes)
#define INTERDICTOR_COOLDOWN 5 MINUTES

/// Speed multiplier applied to interdicted ships (50% speed)
#define INTERDICTOR_SPEED_REDUCTION 0.5

/// Power draw when interdicting
#define INTERDICTOR_POWER_ACTIVE 300

/// Cooldown before interdicted ship can undock (30 seconds)
#define INTERDICTOR_UNDOCK_LOCKOUT 30 SECONDS

/// Range at which interdiction can be started (in overmap tiles)
#define INTERDICTOR_RANGE 2

/// Range at which force dock can be used (in overmap tiles, must be same tile)
#define INTERDICTOR_FORCE_DOCK_RANGE 0
