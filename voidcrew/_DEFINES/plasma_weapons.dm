// Plasma and frontier laser weapons (voidcrew/modules/plasma_weapons/).
// Package: P0 seams. Values are final; packages read them and never redefine them.

// ===== Flask, chamber and feeding =====

/// Mol of plasma a flask (and a gun's sealed chamber) holds: three sheets
#define PLASMA_FLASK_CAPACITY 60
/// Mol one plasma sheet gives (a sheet grinds to 20 u, 1 u boils to 1 mol)
#define PLASMA_MOL_PER_SHEET 20
/// Mol one plasma ore gives (half a sheet)
#define PLASMA_MOL_PER_ORE 10
/// do_after per sheet or ore fed into a flask or gun
#define PLASMA_FEED_DELAY (0.5 SECONDS)
/// do_after to seat a flask in a pistol
#define PLASMA_LOAD_DELAY_PISTOL (1 SECONDS)
/// do_after to seat a flask in a rifle
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
#define PLASMA_LIGHT_COLOR "#74FFA0"

/// Furthest a bolt's sprite slides across its path onto a held shield on its last step, in pixels
#define PLASMA_BOLT_MAX_SLIDE 6
