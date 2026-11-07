// Tunables for voidcrew/modules/gun_feel: recoil kick, muzzle flash, flying casings and shouldering.

// ---- Recoil kick ----
// Kick strengths are in tiles of camera travel (1 = 32 px). Keep them well under 1.

/// Random spread, in degrees, around "straight back" for each kick.
#define GUN_FEEL_RECOIL_DEVIATION 22.5
/// Hard cap on any single kick, in tiles.
#define GUN_FEEL_MAX_KICK 1.5
/// Tiles of kick added per point of a gun's upstream `recoil` var (nagant, sawn-offs, the sniper rifle...).
#define GUN_FEEL_LEGACY_RECOIL_KICK 0.15
/// Animation tag for the kick, so a new shot supersedes the last kick instead of stacking on it.
#define GUN_FEEL_RECOIL_ANIM_TAG "gun_feel_recoil"

// Gun classes, picked once per gun from its type and size. A subtype can preset `gun_feel_class`.
#define GUN_FEEL_CLASS_NONE "none"
#define GUN_FEEL_CLASS_PISTOL "pistol"
#define GUN_FEEL_CLASS_REVOLVER "revolver"
#define GUN_FEEL_CLASS_SMG "smg"
#define GUN_FEEL_CLASS_RIFLE "rifle"
#define GUN_FEEL_CLASS_SHOTGUN "shotgun"
#define GUN_FEEL_CLASS_MARKSMAN "marksman"
#define GUN_FEEL_CLASS_HEAVY "heavy"
#define GUN_FEEL_CLASS_LAUNCHER "launcher"
#define GUN_FEEL_CLASS_ENERGY "energy"
#define GUN_FEEL_CLASS_ENERGY_LONG "energy_long"

// Kick when shouldered (KICK) and from the hip (KICK_HIP), in tiles.
// HIP_SPREAD is extra spread in degrees from the hip, fed into tg's bonus spread (rand(0, x), then +-0.7x).
#define GUN_FEEL_KICK_PISTOL 0.12
#define GUN_FEEL_KICK_REVOLVER 0.18
#define GUN_FEEL_KICK_SMG 0.08
#define GUN_FEEL_KICK_HIP_SMG 0.2
#define GUN_FEEL_HIP_SPREAD_SMG 10
#define GUN_FEEL_KICK_RIFLE 0.12
#define GUN_FEEL_KICK_HIP_RIFLE 0.3
#define GUN_FEEL_HIP_SPREAD_RIFLE 20
#define GUN_FEEL_KICK_SHOTGUN 0.3
#define GUN_FEEL_KICK_HIP_SHOTGUN 0.55
#define GUN_FEEL_HIP_SPREAD_SHOTGUN 12
#define GUN_FEEL_KICK_MARKSMAN 0.35
#define GUN_FEEL_KICK_HIP_MARKSMAN 0.7
#define GUN_FEEL_HIP_SPREAD_MARKSMAN 30
#define GUN_FEEL_KICK_HEAVY 0.18
#define GUN_FEEL_KICK_HIP_HEAVY 0.45
#define GUN_FEEL_HIP_SPREAD_HEAVY 30
#define GUN_FEEL_KICK_LAUNCHER 0.4
#define GUN_FEEL_KICK_HIP_LAUNCHER 0.7
#define GUN_FEEL_HIP_SPREAD_LAUNCHER 15
#define GUN_FEEL_HIP_SPREAD_ENERGY_LONG 10

// ---- Shouldering ----

/// How long a long gun must be held in both hands before it is shouldered.
#define GUN_FEEL_SHOULDER_TIME (0.4 SECONDS)

// ---- Muzzle flash ----

#define GUN_FEEL_FLASH_ICON 'icons/obj/weapons/guns/projectiles_muzzle.dmi'
#define GUN_FEEL_FLASH_ICON_STATE "muzzle_bullet"
/// How long the flash sprite shows. muzzle_bullet is two frames of 0.1s.
#define GUN_FEEL_FLASH_TIME (0.2 SECONDS)
/// How long the flash light stays on after the last shot.
#define GUN_FEEL_FLASH_LIGHT_TIME (0.3 SECONDS)
#define GUN_FEEL_FLASH_LIGHT_RANGE 3
#define GUN_FEEL_FLASH_LIGHT_POWER 1.2
#define GUN_FEEL_FLASH_LIGHT_COLOR COLOR_VERY_SOFT_YELLOW
// Where the barrel sits relative to the shooter's centre, in pixels, by aim direction.
#define GUN_FEEL_FLASH_REACH_SIDE 12
#define GUN_FEEL_FLASH_REACH_UP 8
#define GUN_FEEL_FLASH_REACH_DOWN 6
#define GUN_FEEL_FLASH_HAND_HEIGHT -2
/// The bright core of muzzle_bullet sits this many pixels behind the icon centre.
#define GUN_FEEL_FLASH_HOTSPOT 4

// ---- Flying casings ----

/// Most casings allowed in flight at once. Past this, casings drop the old way.
#define GUN_FEEL_CASING_CAP 60
/// Degrees clockwise from the shooter's facing that casings leave at: out to the right and a little back.
#define GUN_FEEL_CASING_EJECT_ANGLE 110
#define GUN_FEEL_CASING_EJECT_SCATTER 25
/// Height, in pixels, a casing leaves the gun at.
#define GUN_FEEL_CASING_START_HEIGHT 8
// Launch speeds in pixels per physics step (0.05 s).
#define GUN_FEEL_CASING_SPEED_MIN 2.5
#define GUN_FEEL_CASING_SPEED_MAX 4
#define GUN_FEEL_CASING_LIFT_MIN 2
#define GUN_FEEL_CASING_LIFT_MAX 3.5

// ---- Movable physics (shared by anything using /datum/component/movable_physics) ----
// Per physics step (0.05 s), in pixels.

#define MOVABLE_PHYSICS_GRAVITY 0.75
#define MOVABLE_PHYSICS_AIR_DRAG 0.03
#define MOVABLE_PHYSICS_GROUND_FRICTION 0.45
/// Share of vertical speed kept on a floor bounce.
#define MOVABLE_PHYSICS_RESTITUTION 0.4
/// Share of horizontal speed kept on a floor bounce.
#define MOVABLE_PHYSICS_BOUNCE_KEEP 0.65
/// Share of horizontal speed kept when glancing off a wall.
#define MOVABLE_PHYSICS_WALL_KEEP 0.5
/// A bounce slower than this just settles.
#define MOVABLE_PHYSICS_MIN_BOUNCE 1.2
/// Anything still moving after this long settles where it is.
#define MOVABLE_PHYSICS_TIMEOUT (3 SECONDS)
