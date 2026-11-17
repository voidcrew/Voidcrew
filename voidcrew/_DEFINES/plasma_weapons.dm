// Plasma and frontier laser weapons (voidcrew/modules/plasma_weapons/).
// Package: P0 seams. Values are final; packages read them and never redefine them.

// ===== NPCs =====

/// 1 lets pirate gunners roll the Cinder and Furnace and arms red-zone Director Prime and Chief Auditor with a
/// Furnace (plasma_pirates.dm). 0 (on hold for now): no NPC is handed a plasma gun and bosses keep their stock
/// weapon. The Old Furnace stays in red-zone boss loot either way.
#define PLASMA_NPC_GUNS 0

// ===== Cartridge and chamber =====

/// Mol one plasma sheet gives (a sheet grinds to 20 u, 1 u boils to 1 mol)
#define PLASMA_MOL_PER_SHEET 20
/// Plasma sheets printed into one cartridge
#define PLASMA_CARTRIDGE_SHEETS 3
/// Mol of plasma a cartridge (and a gun's sealed chamber) holds
#define PLASMA_CARTRIDGE_CAPACITY (PLASMA_CARTRIDGE_SHEETS * PLASMA_MOL_PER_SHEET)
/// Iron in a cartridge's jacket. A cartridge is made of this and nothing else, whatever made it,
/// so a lathe or recycler never gets plasma back out of one.
#define PLASMA_CARTRIDGE_IRON HALF_SHEET_MATERIAL_AMOUNT
/// do_after to seat a cartridge in a pistol
#define PLASMA_LOAD_DELAY_PISTOL (1 SECONDS)
/// do_after to seat a cartridge in a rifle
#define PLASMA_LOAD_DELAY_RIFLE (1.5 SECONDS)
/// Mol a pistol bolt costs (casing e_cost): 15 shots a cartridge
#define PLASMA_SHOT_MOL_PISTOL 4
/// Mol a rifle bolt costs (casing e_cost): 12 shots a cartridge
#define PLASMA_SHOT_MOL_RIFLE 5

// ===== Bolt: ignition, fire and ash =====

/// Temperature a passing bolt exposes its turf at (hotspot_expose)
#define PLASMA_BOLT_EXPOSE_TEMP 1000
/// Volume a passing bolt exposes its turf with (hotspot_expose)
#define PLASMA_BOLT_EXPOSE_VOLUME 10
/// A pistol bolt melts an arm or leg left within this much of its max damage
#define PLASMA_ASH_MARGIN_PISTOL 10
/// A rifle bolt melts an arm or leg left within this much of its max damage
#define PLASMA_ASH_MARGIN_RIFLE 20
/// The margin only counts on a limb that already had this much damage before the bolt, so no bolt melts
/// an unhurt arm or leg in one hit
#define PLASMA_ASH_PRIOR_DAMAGE 10
/// A bolt only melts a limb when at least this much of its own burn gets through armour
#define PLASMA_ASH_MIN_LANDED 10
/// Structure and door damage multiplier (demolition_mod) for a pistol bolt
#define PLASMA_DEMOLITION_PISTOL 1.5
/// Structure and door damage multiplier (demolition_mod) for a rifle bolt
#define PLASMA_DEMOLITION_RIFLE 2

// ===== Effects =====

/// Wall glows allowed at once on one z-level; new ones over the cap are skipped
#define PLASMA_GLOW_CAP_PER_Z 40
/// Soot decals allowed in the world; the oldest goes when a new one is made over the cap
#define PLASMA_SOOT_GLOBAL_CAP 300
/// Slag decals one tile keeps from separate melts; a new melt over this replaces the oldest slag on that tile
#define PLASMA_SLAG_TURF_CAP 3
/// How long a wall glow (or a soot decal's glow) takes to cool to nothing
#define PLASMA_GLOW_DURATION (8 SECONDS)

/// Light colour of a plasma bolt and of its splash and gutter-out
#define PLASMA_LIGHT_COLOR "#E178FF"

/// Furthest a bolt's sprite slides across its path onto a held shield on its last step, in pixels
#define PLASMA_BOLT_MAX_SLIDE 6

// ===== Sounds =====
// Slots for the plasma weapons' own sounds. Each holds a stock sound for now; drop a new file in here to replace it.

/// A bolt passing close by someone's head
#define PLASMA_SOUND_NEAR_MISS 'sound/items/weapons/plasma_cutter.ogg'
/// A bolt hitting a wall, floor, machine or anything else hard
#define PLASMA_SOUND_IMPACT_WALL 'sound/items/weapons/effects/searwall.ogg'
/// A bolt hitting a window or windoor
#define PLASMA_SOUND_IMPACT_GLASS 'sound/effects/glass/glasshit.ogg'
/// A held shield stopping a bolt. null plays the shield's own block sound.
#define PLASMA_SOUND_SHIELD_BLOCK null
/// A limb with no flesh (robotic, bone, stone) melting off
#define PLASMA_SOUND_METAL_MELT 'sound/items/tools/welder2.ogg'
/// Hot slag in a wound quenched with water, an extinguisher or cryo
#define PLASMA_SOUND_QUENCH 'sound/effects/wounds/sizzle1.ogg'
/// A bead of slag picked out of a wound
#define PLASMA_SOUND_SLAG_PICK 'sound/items/handling/surgery/hemostat1.ogg'
/// A bolt splashing off armour that stops all of it. null plays nothing.
#define PLASMA_SOUND_ARMOUR_BLOCK PLASMA_SOUND_IMPACT_WALL

/// Volume of a bolt hitting a person, by bolt
#define PLASMA_HIT_VOLUME_PISTOL 55
#define PLASMA_HIT_VOLUME_RIFLE 68
/// Volume added to the damage-scaled volume of a bolt hitting a wall or anything else hard
#define PLASMA_SURFACE_HIT_BONUS 10
/// Gap between the old cartridge coming out and the new one going in on a swap
#define PLASMA_SWAP_SOUND_GAP (0.35 SECONDS)
/// Random playback rate for a plasma or frontier laser shot, about 4% either way
#define PLASMA_SHOT_FREQUENCY (rand(96, 104) / 100)
/// Lowest pitch a frontier laser's shot drops to as its cell runs down
#define FRONTIER_LASER_MIN_PITCH 0.85

// ===== Wounds =====

/// Slag in a fresh plasma burn, by severity
#define PLASMA_WOUND_SLAG_MODERATE 3
#define PLASMA_WOUND_SLAG_SEVERE 6
#define PLASMA_WOUND_SLAG_CRITICAL 12
/// Seconds a fresh plasma burn stays hot, by severity
#define PLASMA_WOUND_HEAT_MODERATE 10
#define PLASMA_WOUND_HEAT_SEVERE 20
#define PLASMA_WOUND_HEAT_CRITICAL 30
/// Burn a second a hot plasma burn deals, by severity
#define PLASMA_WOUND_COOK_SEVERE 0.3
#define PLASMA_WOUND_COOK_CRITICAL 0.5
/// Slag a moderate plasma burn sheds a second once cool
#define PLASMA_WOUND_SHED_RATE 0.1
/// Heat decay multipliers for a cold body and for cold air
#define PLASMA_WOUND_COLD_BODY_FACTOR 4
#define PLASMA_WOUND_COLD_AIR_FACTOR 2
/// kPa the cold air needs to count
#define PLASMA_WOUND_COLD_AIR_PRESSURE 20
/// Time for one field pick
#define PLASMA_WOUND_PICK_TIME (2.5 SECONDS)
/// Slag taken out per field pick and per surgery step
#define PLASMA_WOUND_PICK_SLAG 3
#define PLASMA_WOUND_SURGERY_SLAG 6
/// Brute dealt per pick, with a proper tool and with an improvised one
#define PLASMA_WOUND_PICK_BRUTE 3
#define PLASMA_WOUND_PICK_BRUTE_IMPROVISED 6
/// Pick time multiplier for wirecutters or a scalpel
#define PLASMA_WOUND_IMPROVISED_TIME 1.25
/// Units of plasma a fresh critical tops the blood up to
#define PLASMA_WOUND_BLOOD_PLASMA 4
/// Critical with slag: limp slowdown, limp chance, fumble multiplier
#define PLASMA_WOUND_LIMP_SLOWDOWN 3
#define PLASMA_WOUND_LIMP_CHANCE 40
#define PLASMA_WOUND_FUMBLE 1.25
/// Blood flow a bolt takes off each bleeding wound on the limb it hits
#define PLASMA_SEAR_FLOW 1.6
/// Scar text file for plasma burns
#define PLASMA_SCAR_FILE "wounds/plasma_scar_desc.json"

/// Furthest a distant firing sound carries, in tiles
#define PLASMA_FAR_SOUND_RANGE 40
/// Distant sound volume at the near edge of its band
#define PLASMA_FAR_SOUND_VOL_NEAR 38
/// Distant sound volume at PLASMA_FAR_SOUND_RANGE
#define PLASMA_FAR_SOUND_VOL_FAR 5
