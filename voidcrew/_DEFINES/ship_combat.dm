// Ship Combat System Defines and Signals

// ========== SIGNALS ==========

/// Sent when a missile is fired from a ship: (obj/effect/ship_missile/missile, obj/structure/overmap/ship/target)
#define COMSIG_SHIP_MISSILE_FIRED "ship_missile_fired"

/// Sent when a missile impacts a ship: (obj/effect/ship_missile/missile, turf/impact_turf)
#define COMSIG_SHIP_MISSILE_IMPACT "ship_missile_impact"

/// Sent when a ship fires any weapon (used for cloaking decloak): ()
#define COMSIG_SHIP_WEAPON_FIRED "ship_weapon_fired"

/// Sent when a ship is boarded by a boarding pod: (obj/effect/boarding_pod/pod, obj/structure/overmap/ship/npc/source_ship)
#define COMSIG_SHIP_BOARDED "ship_boarded"

/// Sent when a ship's cloak status changes: (cloaked)
#define COMSIG_SHIP_CLOAK_CHANGED "ship_cloak_changed"

/// Sent when a ship starts being targeted: (obj/structure/overmap/ship/attacker)
#define COMSIG_SHIP_BEING_TARGETED "ship_being_targeted"

/// Sent when a ship is no longer being targeted (lock broken or completed): (obj/structure/overmap/ship/attacker)
#define COMSIG_SHIP_TARGETING_STOPPED "ship_targeting_stopped"

/// Sent when a ship has a weapons lock acquired on it (breaks cloak): (obj/structure/overmap/ship/attacker)
#define COMSIG_SHIP_WEAPONS_LOCKED "ship_weapons_locked"

/// Sent when a ship loses a weapons lock that was on it: (obj/structure/overmap/ship/attacker)
#define COMSIG_SHIP_WEAPONS_LOCK_LOST "ship_weapons_lock_lost"

/// Sent when a ship enters an overmap hazard event: (obj/structure/overmap/event/hazard)
#define COMSIG_SHIP_HAZARD_TRIGGERED "ship_hazard_triggered"

/// Sent when a ship hides in a nebula (drops all combat connections)
#define COMSIG_SHIP_GOING_DARK "ship_going_dark"

/// Sent when a ship unhides from a nebula
#define COMSIG_SHIP_EMERGING_FROM_NEBULA "ship_emerging_from_nebula"

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

// ========== ASSAULT POD DEFINES ==========
// Assault pods are drop pods fired out of a launch tube at another vessel. They
// are a boarding tool, not ordnance: the shield toll is small, the breach is
// hand-cut rather than blasted, and the whole point is depositing the occupants
// on the far side of somebody else's hull.

/// Shield damage a pod deals when a shield stops it. Deliberately low - pods are
/// for hulls that are already open or already unshielded, not for cracking shields.
#define ASSAULT_POD_SHIELD_DAMAGE 100
/// Power draw when launching a pod
#define ASSAULT_POD_LAUNCH_POWER 1500
/// Time to load a pod into a launch tube
#define ASSAULT_POD_LOAD_TIME 6 SECONDS
/// How many consecutive blocked tiles a pod chews through before it gives up and
/// stops on the outside face. Two gets you through a double-thickness hull.
#define ASSAULT_POD_BREACH_DEPTH 2
/// Light-impact radius of the shock at the breach point (no devastation, no heavy -
/// the hole is cut explicitly so it stays the size we asked for)
#define ASSAULT_POD_IMPACT_LIGHT 2
/// Brute damage the pod deals to dense objects standing in the breach path
#define ASSAULT_POD_BREACH_DAMAGE 500
/// Flight speed of an assault pod (delay in deciseconds per tile - heavier than a missile)
#define ASSAULT_POD_SPEED 1

// ========== COMBAT CONSOLE DEFINES ==========

/// Range at which ships can be detected on sensors (in overmap tiles)
#define COMBAT_TARGETING_RANGE 3

/// Range at which missile lock can be activated (in overmap tiles)
#define COMBAT_MISSILE_LOCK_RANGE 2

/// Time it takes to acquire a target lock (in deciseconds)
#define COMBAT_TARGETING_TIME 5 SECONDS

/// Camera view size for targeting
#define COMBAT_CAMERA_VIEW_RANGE 7

/// How many tiles from space should be visible in targeting camera (0 = only directly adjacent to space)
#define COMBAT_CAMERA_VISIBILITY_RANGE 1

// ========== INTERDICTOR DEFINES ==========

/// Time to lock on to a target ship (5 seconds warmup)
#define INTERDICTOR_LOCK_TIME 5 SECONDS

/// Cooldown between interdiction attempts (5 minutes)
#define INTERDICTOR_COOLDOWN 5 MINUTES

/// Rearm time after the target shield-bursts out of a completed lock. Deliberately far
/// shorter than INTERDICTOR_COOLDOWN: the burst drains the target's entire shield pool,
/// which takes ~47s (30s broken + regen back to the burst cost) before it can burst
/// again - re-locking inside that window is the counterplay. Charging the full 5-minute
/// cooldown here made the target's recovery 2-6x faster than the attacker's, so bursting
/// out was strictly dominant and yellow-zone pirates (boardable only via interdiction)
/// could never be caught.
#define INTERDICTOR_BURST_BREAK_COOLDOWN 30 SECONDS

/// Base speed reduction at 100% power (50% speed)
#define INTERDICTOR_BASE_REDUCTION 0.5

/// Cooldown before interdicted ship can undock (30 seconds)
#define INTERDICTOR_UNDOCK_LOCKOUT 30 SECONDS

/// Cooldown before force-docked ship can undock (2 minutes)
#define INTERDICTOR_FORCE_DOCK_LOCKOUT 2 MINUTES

/// Range at which interdiction can be started (in overmap tiles)
#define INTERDICTOR_RANGE 2

/// Range at which force dock can be used (in overmap tiles, must be same tile)
#define INTERDICTOR_FORCE_DOCK_RANGE 0

// ========== INTERDICTOR MACHINE DEFINES ==========

/// Base power draw for interdictor (3 kW)
#define INTERDICTOR_BASE_POWER_COST 3 KILO WATTS
/// Power draw per unit of ship mass (W per mass)
#define INTERDICTOR_POWER_PER_MASS 40
/// Minimum power allocation (25%)
#define INTERDICTOR_POWER_MIN 0.25
/// Maximum power allocation (200%)
#define INTERDICTOR_POWER_MAX 2.0

// Interdictor stock part multipliers (per tier above 1)
/// Capacitor: +25% max effect strength per tier
#define INTERDICTOR_CAPACITOR_EFFECT_MULT 0.25
/// Micro-laser: +20% power efficiency per tier
#define INTERDICTOR_LASER_EFFICIENCY_MULT 0.20
/// Servo: -15% cooldown per tier
#define INTERDICTOR_SERVO_COOLDOWN_MULT 0.15

// ========== INTERDICTOR SIGNALS ==========

/// Sent when a ship is interdicted: (obj/machinery/ship_combat/interdictor/source, power_level)
#define COMSIG_SHIP_INTERDICTED "ship_interdicted"
/// Sent when interdiction ends on a ship
#define COMSIG_SHIP_INTERDICTION_ENDED "ship_interdiction_ended"

// ========== SHIELD DEFINES ==========

/// Base shield health per generator (before stock part modifiers)
/// Tier 1: 500, Tier 2: 750, Tier 3: 1000
#define SHIP_SHIELD_BASE_HEALTH 500
/// Base shield regeneration per second
#define SHIP_SHIELD_BASE_REGEN 10
/// Cooldown after shields break before reactivation (30 seconds)
#define SHIP_SHIELD_BROKEN_COOLDOWN 30 SECONDS
/// Minimum power allocation (0% = shields off)
#define SHIP_SHIELD_MIN_POWER_MULT 0
/// Maximum power allocation (200%)
#define SHIP_SHIELD_MAX_POWER_MULT 2
/// Base power draw for shield generator (1.5 kW) - ensures small ships still pay meaningful cost
#define SHIP_SHIELD_BASE_POWER_COST 1.5 KILO WATTS
/// Power draw per unit of ship mass (W per mass)
#define SHIP_SHIELD_POWER_PER_MASS 15
/// Ceiling on banked overhealth, as a fraction of max shield health. Overhealth is
/// consumed before the main pool, so without a ceiling a ship idling at 200% power
/// banks shield_regen_rate HP/sec forever and becomes unbreakable.
/// Balance number chosen without playtest data - tune freely.
#define SHIP_SHIELD_MAX_OVERHEALTH_MULT 0.5
/// Maximum shield generators that can join one hull's pool. Max health and regen are
/// plain sums over the pool, so the generator count is otherwise the one shield stat
/// with no limit (turrets have LASER_MAX_TURRETS).
/// Balance number chosen without playtest data - tune freely.
#define SHIP_MAX_SHIELD_GENERATORS 4
/// Fraction of max shield health the pool starts with the moment shields come online,
/// on a fresh raise and on post-break reactivation alike. Shields used to establish at
/// 0 HP, so under sustained fire (round 4 meteor shower) the first hit re-broke the
/// pool and re-armed the full SHIP_SHIELD_BROKEN_COOLDOWN - shields could never come
/// online at all once anything was shooting. 0.5 lets a single tier-1 generator's pool
/// (500) survive one small meteor (200) on the way up.
/// Balance number chosen without playtest data - tune freely.
#define SHIP_SHIELD_RAISE_CHARGE_MULT 0.5

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

/// Sent when a ship's hull takes damage (turfs destroyed, walls damaged, etc)
#define COMSIG_SHIP_HULL_HIT "ship_hull_hit"

/// Sent when a ship takes explosive damage that destroys turfs (missiles, bombs)
/// Used by NPC ships to trigger mass recalculation
#define COMSIG_SHIP_EXPLOSIVE_DAMAGE "ship_explosive_damage"

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

// ========== METEOR SHIELD DAMAGE VALUES ==========

/// Shield damage from big meteors
#define METEOR_SHIELD_DAMAGE_BIG 600
/// Shield damage from medium meteors
#define METEOR_SHIELD_DAMAGE_MEDIUM 400
/// Shield damage from small/default meteors
#define METEOR_SHIELD_DAMAGE_SMALL 200

// ========== LASER SIGNALS ==========

/// Sent when a laser turret fires: (obj/machinery/ship_combat/laser_turret/turret, turf/target)
#define COMSIG_SHIP_LASER_FIRED "ship_laser_fired"

// ========== TIMING CONSTANTS ==========

/// Missile flight lifetime before self-destruct
#define MISSILE_FLIGHT_LIFETIME 30 SECONDS
/// Time to load a missile into launcher
#define MISSILE_LAUNCHER_LOAD_TIME 4 SECONDS
/// Base cloak duration before upgrades
#define SHIP_CLOAK_BASE_DURATION 30 SECONDS
/// Additional cloak duration per capacitor tier
#define SHIP_CLOAK_DURATION_PER_TIER 15 SECONDS
/// Cooldown before recloaking
#define SHIP_CLOAK_RECLOAK_DELAY 1 MINUTES
/// Minimum recloak cooldown after upgrades
#define SHIP_CLOAK_MIN_RECLOAK_DELAY 30 SECONDS
/// Shield reactivation cooldown after breaking
#define SHIP_SHIELD_REACTIVATION_COOLDOWN 1 MINUTES

// ========== CLOAK DEFINES ==========

/// Base power draw for cloaking device (5 kW) - ensures small ships still pay meaningful cost
#define SHIP_CLOAK_BASE_POWER_COST 5 KILO WATTS
/// Power draw per unit of ship mass (W per mass) - cloaking larger ships is harder
#define SHIP_CLOAK_POWER_PER_MASS 50

// ========== SHIP NOTIFICATION DEFINES ==========

/// Notification alert levels for ship_notify()
#define SHIP_NOTIFY_NOTICE 1
#define SHIP_NOTIFY_WARNING 2
#define SHIP_NOTIFY_DANGER 3

// ========== SIPHON MACHINE DEFINES ==========

/// Base power draw for data siphon (2 kW)
#define SIPHON_BASE_POWER_COST 2 KILO WATTS
/// Base siphon rate (credits per tick)
#define SIPHON_BASE_RATE 25
/// Base warmup time before siphon activates
#define SIPHON_BASE_WARMUP_TIME 5 SECONDS
/// Balance below which a target isn't worth the lock - the siphon refuses to spin up
#define SIPHON_MINIMUM_TARGET_BALANCE 50
/// How long a siphoned account stays frozen after the last credit is pulled off it.
/// The freeze lapses on its own instead of being released, so a siphon that dies
/// without cleaning up can never leave a crew locked out of their money for the round.
#define SIPHON_ACCOUNT_LOCK_GRACE (10 SECONDS)

// Siphon stock part multipliers (per tier above 1)
/// Capacitor: +25% siphon rate per tier
#define SIPHON_CAPACITOR_RATE_MULT 0.25
/// Micro-laser: +20% power efficiency per tier
#define SIPHON_LASER_EFFICIENCY_MULT 0.20
/// Servo: -15% warmup time per tier
#define SIPHON_SERVO_WARMUP_MULT 0.15

// ========== SOUND CHANNELS ==========

/// Sound channel for economic scan looping sound
#define CHANNEL_ECON_SCAN 1010

// ========== ELECTRONIC WARFARE DEFINES ==========
/// Sent to the TARGET ship when a payload lands: (datum/ew_payload/instance, obj/structure/overmap/ship/attacker)
#define COMSIG_SHIP_EW_PAYLOAD_STARTED "ship_ew_payload_started"
/// Sent to the TARGET ship when a payload expires or is purged: (datum/ew_payload/instance)
#define COMSIG_SHIP_EW_PAYLOAD_ENDED "ship_ew_payload_ended"
/// Sent to the TARGET ship when its crew purges the intrusion: ()
#define COMSIG_SHIP_EW_PURGED "ship_ew_purged"
/// Sent to the ATTACKER ship when its suite is traced: (obj/structure/overmap/ship/target)
#define COMSIG_SHIP_EW_TRACED "ship_ew_traced"

/// Base power draw while warming up or running a payload (2 kW)
#define EW_BASE_POWER_COST 2 KILO WATTS
/// Signature ceiling: reaching it triggers a trace
#define EW_SIGNATURE_MAX 100
/// Signature decay per second while idle
#define EW_SIGNATURE_DECAY 1.5
/// Suite lockout after being traced
#define EW_TRACE_LOCKOUT 3 MINUTES
/// Target immunity window after purging an intrusion
#define EW_PURGE_HARDENED_TIME 2 MINUTES
/// NPC crews purge an intrusion on their own after this long
#define EW_NPC_AUTOPURGE_TIME 45 SECONDS

// EW suite stock part multipliers (per tier above 1)
/// Capacitor: -15% signature cost per tier
#define EW_CAPACITOR_SIGNATURE_MULT 0.15
/// Micro-laser: +20% power efficiency per tier
#define EW_LASER_EFFICIENCY_MULT 0.20
/// Servo: -15% warmup time per tier
#define EW_SERVO_WARMUP_MULT 0.15

// ========== HARMONIC DAMPENING ARRAY DEFINES ==========
// Counter to ion and electrical overmap storms. Deliberately conservative: even a
// fully upgraded array leaves some surges through, and every catch costs real power.

/// Standby draw of a dampening array (250 W)
#define STORM_DAMPENER_IDLE_POWER (250 WATTS)
/// Chance for an all tier 1 array to catch an incoming surge
#define STORM_DAMPENER_BASE_CHANCE 50
/// Added catch chance per capacitor tier above 1 (two capacitors, so +39 at tier 4)
#define STORM_DAMPENER_CAPACITOR_CHANCE 6.5
/// Hard ceiling on catch chance - the array is never a guarantee
#define STORM_DAMPENER_MAX_CHANCE 90
/// Energy drawn from the local APC per caught surge, before servo efficiency (5 kJ)
#define STORM_DAMPENER_BASE_SURGE (5 KILO JOULES)
/// Servo: -15% surge cost per tier above 1
#define STORM_DAMPENER_SERVO_EFFICIENCY 0.15
/// Floor on the surge cost multiplier, so upgrades never make catching a surge cheap
#define STORM_DAMPENER_MIN_EFFICIENCY 0.4
/// How many surges an all tier 1 array can sink inside one saturation window
#define STORM_DAMPENER_BASE_CAPACITY 3
/// Added saturation capacity per scanning module tier above 1 (9 at tier 4)
#define STORM_DAMPENER_SCANNER_CAPACITY 2
/// Length of a saturation window - matches the ship's hazard damage cooldown
#define STORM_DAMPENER_WINDOW (3 SECONDS)
/// Throttle on the array's discharge sound so a heavy storm isn't an audio wall
#define STORM_DAMPENER_FEEDBACK_COOLDOWN (1 SECONDS)
