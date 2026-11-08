// Hyperviolence blood part: defines private to this part. Defines shared between the
// hyperviolence parts live in voidcrew/_DEFINES/hyperviolence.dm.

/// Smallest brute hit, after armour, that can throw blood across the floor.
#define HV_BLOOD_MIN_HIT 12
/// Brute damage per tile a sprayed hit reaches.
#define HV_BLOOD_DAMAGE_PER_TILE 12
/// Furthest a single spray line can reach.
#define HV_BLOOD_MAX_RANGE 5
/// A mob throws one spray per window, so a burst of shots into one body paints the same few tiles once.
#define HV_BLOOD_SPRAY_WINDOW (0.4 SECONDS)
/// A limb that comes off within this long of a hit is blown off in the direction of that hit.
#define HV_BLOOD_HIT_MEMORY (0.5 SECONDS)
/// Sprays at or above this many tiles also throw a pair of flanking lines either side of the main one.
#define HV_BLOOD_FAN_STRENGTH 3
/// Tiles a spray reaches when a limb comes off.
#define HV_BLOOD_DISMEMBER_STRENGTH 3

/// Each unit of blood a standing bleeder loses adds this much to the pool under them.
#define HV_BLOOD_POOL_PER_UNIT 1
/// Pool pictures are 64x64 and drawn this many pixels left of and below their tile, which centres them on it.
#define HV_BLOOD_POOL_OFFSET -16
/// Pool sizes up to this one fit inside their own tile. Bigger ones reach over its edges.
#define HV_BLOOD_POOL_CONTAINED_TIER 2
/// The pool size from which a pool runs onto the tiles beside it.
#define HV_BLOOD_POOL_LOBE_TIER 3
/// The biggest pool size.
#define HV_BLOOD_POOL_BIGGEST_TIER 4
/// How many neighbouring tiles a pool of the first big size has run onto, and a pool of the biggest size.
#define HV_BLOOD_POOL_LOBES_BIG 1
#define HV_BLOOD_POOL_LOBES_BIGGEST 3

/// How often, at most, floating blood is checked against gravity when nothing announced a change.
#define HV_BLOOD_FLOAT_SWEEP (15 SECONDS)
/// Floating blood states in blood_weightless.dmi.
#define HV_BLOOD_FLOAT_VARIANTS 12

#define HV_BLOOD_SPRAY_ICON 'voidcrew/modules/hyperviolence/blood/icons/blood_spray.dmi'
#define HV_BLOOD_POOL_ICON 'voidcrew/modules/hyperviolence/blood/icons/blood_pool.dmi'
#define HV_BLOOD_FLOAT_ICON 'voidcrew/modules/hyperviolence/blood/icons/blood_weightless.dmi'
