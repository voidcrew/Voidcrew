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

/// Sent when a ship starts being targeted: (obj/structure/overmap/ship/attacker)
#define COMSIG_SHIP_BEING_TARGETED "ship_being_targeted"

/// Sent when a ship is no longer being targeted (lock broken or completed): (obj/structure/overmap/ship/attacker)
#define COMSIG_SHIP_TARGETING_STOPPED "ship_targeting_stopped"

/// Sent when a ship enters an overmap hazard event: (obj/structure/overmap/event/hazard)
#define COMSIG_SHIP_HAZARD_TRIGGERED "ship_hazard_triggered"

// ========== MISSILE DEFINES ==========
/// Missile construction states
#define MISSILE_STATE_UNWIRED 0
#define MISSILE_STATE_WIRED 1
#define MISSILE_STATE_TRACKING 2
#define MISSILE_STATE_PAYLOAD 3
#define MISSILE_STATE_ARMED 4

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

/// Power draw when firing
#define MISSILE_LAUNCHER_POWER_FIRE 500

// ========== COMBAT CONSOLE DEFINES ==========

/// Range at which ships can be detected on sensors (in overmap tiles)
#define COMBAT_TARGETING_RANGE 3

/// Range at which missile lock can be activated (in overmap tiles)
#define COMBAT_MISSILE_LOCK_RANGE 2

/// Time it takes to acquire a target lock (in deciseconds)
#define COMBAT_TARGETING_TIME 5 SECONDS

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

// ========== SHIELD DEFINES ==========

/// Base shield health per generator (before stock part modifiers)
/// Tier 1: 500, Tier 2: 750, Tier 3: 1000
#define SHIP_SHIELD_BASE_HEALTH 500
/// Base shield regeneration per second
#define SHIP_SHIELD_BASE_REGEN 2
/// Cooldown after shields break before reactivation (30 seconds)
#define SHIP_SHIELD_BROKEN_COOLDOWN 30 SECONDS
/// Minimum power allocation (0% = shields off)
#define SHIP_SHIELD_MIN_POWER_MULT 0
/// Maximum power allocation (200%)
#define SHIP_SHIELD_MAX_POWER_MULT 2
/// Power draw per unit of ship mass
#define SHIP_SHIELD_POWER_PER_MASS 0.5

// Stock part multipliers (per tier above 1)
/// Capacitor: +50% max shield health per tier
#define SHIELD_CAPACITOR_HEALTH_MULT 0.5
/// Micro-laser: +30% base regen rate per tier
#define SHIELD_LASER_REGEN_MULT 0.3
/// Servo: -15% power consumption per tier
#define SHIELD_SERVO_EFFICIENCY_MULT 0.15

// ========== SHIELD SIGNALS ==========

/// Sent when shields absorb damage: (damage_absorbed, turf/impact_location)
#define COMSIG_SHIP_SHIELD_HIT "ship_shield_hit"
/// Sent when shields break (health reaches 0)
#define COMSIG_SHIP_SHIELD_BROKEN "ship_shield_broken"
/// Sent when shields shut down due to power loss
#define COMSIG_SHIP_SHIELD_POWERDOWN "ship_shield_powerdown"
/// Sent when shields are reactivated after cooldown
#define COMSIG_SHIP_SHIELD_RESTORED "ship_shield_restored"

/// Return value to cancel missile impact (missile was blocked by shields)
#define COMSIG_CANCEL_MISSILE_IMPACT (1<<0)

// ========== LASER TURRET DEFINES ==========

/// Base laser damage at 100% power
#define LASER_DAMAGE_BASE 50
/// Base power draw per shot at 100% power
#define LASER_POWER_BASE 2000
/// Minimum power level (25%)
#define LASER_POWER_MIN 0.25
/// Maximum power level (200%)
#define LASER_POWER_MAX 2
/// Cooldown between shots in deciseconds at 100% power
#define LASER_COOLDOWN_BASE 2 SECONDS
/// Power draw when idle (just to stay linked)
#define LASER_IDLE_POWER 50
/// Base charge rate from powernet to cell (power per second)
#define LASER_CHARGE_RATE_BASE 100
/// Maximum number of laser turrets that can be linked to a ship
#define LASER_MAX_TURRETS 10

// Laser stock part multipliers (per tier above 1)
/// Micro-laser: +25% damage per tier
#define LASER_MICROLASER_DAMAGE_MULT 0.25
/// Capacitor: +25% charge rate per tier
#define LASER_CAPACITOR_CHARGE_MULT 0.25
/// Servo: -10% cooldown per tier
#define LASER_SERVO_COOLDOWN_MULT 0.10

// ========== SHIELD DAMAGE MULTIPLIERS ==========

/// Missiles deal reduced damage to shields (50%)
#define SHIELD_DAMAGE_MULT_MISSILE 0.5
/// Lasers deal increased damage to shields (150%)
#define SHIELD_DAMAGE_MULT_LASER 1.5
/// Meteors deal normal damage to shields (100%)
#define SHIELD_DAMAGE_MULT_METEOR 1.0

// ========== LASER SIGNALS ==========

/// Sent when a laser turret fires: (obj/machinery/ship_combat/laser_turret/turret, turf/target)
#define COMSIG_SHIP_LASER_FIRED "ship_laser_fired"
