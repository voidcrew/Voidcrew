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

// ---- Sounds ----

/// A random playback speed of 1 +- spread, as a multiplier of the recording's own rate.
/// BYOND reads a sound frequency between -100 and 100 as a multiplier, so this works whatever the file's sample rate.
#define GUN_FEEL_PITCH(spread) (1 + (rand() * 2 - 1) * (spread))
/// Pitch spread for energy weapon shots. Powder guns play at their recorded pitch every time.
#define GUN_FEEL_ENERGY_PITCH_SPREAD 0.06
/// Pitch spread for bullet impacts and near misses.
#define GUN_FEEL_IMPACT_PITCH_SPREAD 0.08

// Sound effect keys for /datum/sound_effect.
#define SFX_GUN_FEEL_BULLET_FLESH "gun_feel_bullet_flesh"
#define SFX_GUN_FEEL_BULLET_MISS "gun_feel_bullet_miss"
#define SFX_GUN_FEEL_HIT_METAL "gun_feel_hit_metal"
#define SFX_GUN_FEEL_HIT_GLASS "gun_feel_hit_glass"
#define SFX_GUN_FEEL_HIT_STONE "gun_feel_hit_stone"
#define SFX_GUN_FEEL_HIT_WOOD "gun_feel_hit_wood"
#define SFX_GUN_FEEL_HIT_SNOW "gun_feel_hit_snow"

// What a bullet hit is made of, for its impact sound.
#define GUN_FEEL_SURFACE_FLESH "flesh"
#define GUN_FEEL_SURFACE_METAL "metal"
#define GUN_FEEL_SURFACE_GLASS "glass"
#define GUN_FEEL_SURFACE_STONE "stone"
#define GUN_FEEL_SURFACE_WOOD "wood"
#define GUN_FEEL_SURFACE_SNOW "snow"

/// Volume of a bullet hitting flesh. Fixed, like Shiptest, instead of scaling with damage.
#define GUN_FEEL_FLESH_HIT_VOLUME 100
/// Volume of a suppressed bullet hitting anything. Matches upstream vol_by_damage().
#define GUN_FEEL_SUPPRESSED_HIT_VOLUME 5
/// One thing hit by several pellets or bullets within this many deciseconds makes one impact sound.
#define GUN_FEEL_IMPACT_SOUND_WINDOW 1

// ---- Near misses ----

/// A bullet must be at least this many tiles from where it was fired before it whizzes past anyone.
#define GUN_FEEL_NEAR_MISS_MIN_TRAVEL 3
#define GUN_FEEL_NEAR_MISS_VOLUME 70
/// Flinch strength, in pixels, for a bullet passing close by.
#define GUN_FEEL_NEAR_MISS_FLINCH 1
/// One mob hears at most one whizz in this window (a shotgun blast is one whizz, not six).
#define GUN_FEEL_NEAR_MISS_COOLDOWN (0.1 SECONDS)

// ---- Hit flinch ----

/// Flinch strength, in pixels, is BASE + damage * PER_DAMAGE, rounded and capped at MAX.
#define GUN_FEEL_FLINCH_BASE 1
#define GUN_FEEL_FLINCH_PER_DAMAGE 0.08
#define GUN_FEEL_FLINCH_MAX 3
/// Vertical flinch is this share of the horizontal one; a sprite reads sideways jolts better.
#define GUN_FEEL_FLINCH_VERTICAL 0.5
#define GUN_FEEL_FLINCH_OUT_TIME (0.1 SECONDS)
#define GUN_FEEL_FLINCH_BACK_TIME (0.25 SECONDS)
/// No new flinch starts until the last one has played out, so automatic fire never stacks them.
#define GUN_FEEL_FLINCH_COOLDOWN (0.35 SECONDS)

// ---- Resting casings ----

/// Casings on the floor lie at a random multiple of this angle.
#define GUN_FEEL_CASING_ROTATION_STEP 22.5
/// Pixel scatter for a casing that lands on a floor without flying there.
#define GUN_FEEL_CASING_DROP_SCATTER 8

// Bullet speeds, in tiles per decisecond (tiles a second / 10). Shiptest's speeds, converted from its
// deciseconds-per-tile values (code/__DEFINES/projectiles.dm there). tg's default bullet does 1.25.
/// Pistols and revolvers: 25 tiles a second.
#define GUN_FEEL_SPEED_PISTOL 2.5
/// SMGs, rifles and machine guns: 33 tiles a second.
#define GUN_FEEL_SPEED_RIFLE 3.33
/// Buckshot, slugs and other shotgun rounds: 28.6 tiles a second.
#define GUN_FEEL_SPEED_SHOTGUN 2.86
/// Rubber shot, a little slower like Shiptest's rubber modifier: 22 tiles a second.
#define GUN_FEEL_SPEED_SHOTGUN_RUBBER 2.22
/// .50 sniper rounds: 50 tiles a second.
#define GUN_FEEL_SPEED_SNIPER 5
