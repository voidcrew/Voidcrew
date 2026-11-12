// Plasma and frontier laser weapons (voidcrew/modules/plasma_weapons/).
// Package: P0 seams. Values are final; packages read them and never redefine them.

// ===== Cartridge and chamber =====

/// Mol one plasma sheet gives (a sheet grinds to 20 u, 1 u boils to 1 mol)
#define PLASMA_MOL_PER_SHEET 20
/// Plasma sheets pressed or printed into one cartridge
#define PLASMA_CARTRIDGE_SHEETS 3
/// Mol of plasma a cartridge (and a gun's sealed chamber) holds
#define PLASMA_CARTRIDGE_CAPACITY (PLASMA_CARTRIDGE_SHEETS * PLASMA_MOL_PER_SHEET)
/// Iron in a cartridge's jacket. A cartridge is made of this and nothing else, whatever made it,
/// so a lathe or recycler never gets plasma back out of one.
#define PLASMA_CARTRIDGE_IRON HALF_SHEET_MATERIAL_AMOUNT
/// Time to press a cartridge by hand from the crafting menu
#define PLASMA_PRESS_TIME (3 SECONDS)
/// do_after to seat a cartridge in a pistol
#define PLASMA_LOAD_DELAY_PISTOL (1 SECONDS)
/// do_after to seat a cartridge in a rifle
#define PLASMA_LOAD_DELAY_RIFLE (1.5 SECONDS)
/// Mol a pistol bolt costs (casing e_cost)
#define PLASMA_SHOT_MOL_PISTOL 4
/// Mol a rifle bolt costs (casing e_cost)
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
/// Structure and door damage multiplier (demolition_mod) for a pistol bolt
#define PLASMA_DEMOLITION_PISTOL 1.5
/// Structure and door damage multiplier (demolition_mod) for a rifle bolt
#define PLASMA_DEMOLITION_RIFLE 2

// ===== Heat and venting (Furnace and Old Furnace) =====

/// Heat a Furnace shot adds
#define PLASMA_HEAT_PER_SHOT 13.5
/// Heat an Old Furnace shot adds
#define PLASMA_HEAT_PER_SHOT_UNIQUE 10
/// After a shot at this heat or more, the gun boils
#define PLASMA_HEAT_BOIL 100
/// Heat at which the coil overlay reaches step 1, 2 and 3
#define PLASMA_HEAT_STEP_1 34
#define PLASMA_HEAT_STEP_2 67
#define PLASMA_HEAT_STEP_3 100
/// Hot surroundings: heat gained per second is min(GAIN_MAX, (K - PLASMA_COOL_HOT_TEMP) / GAIN_SPAN)
#define PLASMA_HEAT_GAIN_MAX 10
#define PLASMA_HEAT_GAIN_SPAN 50

/// Mol a boil takes from the chamber and releases on the holder's turf
#define PLASMA_BOIL_MOL 5
/// Heat a boil removes
#define PLASMA_BOIL_COOL 15
/// Integrity a boil costs the gun
#define PLASMA_BOIL_INTEGRITY 10

/// Mol a manual vent releases
#define PLASMA_VENT_MOL 5
/// Heat a manual vent removes
#define PLASMA_VENT_COOL 50
/// Time between manual vents
#define PLASMA_VENT_COOLDOWN (4 SECONDS)
/// A vent blocks firing for this long
#define PLASMA_VENT_LOCK (1 SECONDS)
/// Vented gas leaves at T20C + heat * this, in kelvin
#define PLASMA_VENT_TEMP_PER_HEAT 4

/// Heat lost per second, always
#define PLASMA_COOL_BASE 2.5
/// Heat lost per second to the turf air, times the pressure and temperature factors below
#define PLASMA_COOL_CONVECT 8.5
/// Pressure factor: min(kPa / PLASMA_COOL_PRESSURE_REF, PLASMA_COOL_PRESSURE_CAP)
#define PLASMA_COOL_PRESSURE_REF 101.3
#define PLASMA_COOL_PRESSURE_CAP 1.5
/// Temperature factor: clamp((PLASMA_COOL_HOT_TEMP - K) / PLASMA_COOL_TEMP_SPAN, 0, PLASMA_COOL_TEMP_CAP)
#define PLASMA_COOL_HOT_TEMP 573
#define PLASMA_COOL_TEMP_SPAN 280
#define PLASMA_COOL_TEMP_CAP 1.6

// ===== Effects =====

/// Wall glows allowed at once on one z-level; new ones over the cap are skipped
#define PLASMA_GLOW_CAP_PER_Z 40
/// Soot decals allowed in the world; the oldest goes when a new one is made over the cap
#define PLASMA_SOOT_GLOBAL_CAP 300
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
/// The Furnace venting its heat
#define PLASMA_SOUND_FURNACE_VENT 'sound/machines/hiss.ogg'
/// The Furnace boiling its chamber over
#define PLASMA_SOUND_FURNACE_BOIL 'sound/effects/gas_hissing.ogg'
/// A cartridge pressed by hand
#define PLASMA_SOUND_PRESS 'sound/items/tools/welder.ogg'

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
