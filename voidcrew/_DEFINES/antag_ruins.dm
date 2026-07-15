// Vestige ruin (antag boon) tuning knobs — see voidcrew/modules/antag_ruins/

/// When the first vestige ruin surfaces on the overmap
#define VESTIGE_FIRST_SPAWN_TIME (1 MINUTES)
/// Delay between subsequent vestige ruin arrivals
#define VESTIGE_SPAWN_INTERVAL (1 MINUTES)
/// Hard cap on vestige ruins per round (also capped by how many themes exist)
#define VESTIGE_MAX_PER_ROUND 4

/// Most boon candidates a fulfilled pact offers at once (fewer if the patron has less left to give)
#define VESTIGE_REWARD_CHOICES 3

/// Unique DNA samples the Trial of Faces demands
#define VESTIGE_FACES_SAMPLES_NEEDED 5
/// How many of those samples must come from living targets
#define VESTIGE_FACES_LIVING_NEEDED 2
/// Incubation time before a sown vestige egg hatches
#define VESTIGE_EGG_INCUBATION (3 MINUTES)
/// Lit candles needed around an offering rune
#define VESTIGE_OFFERING_CANDLES 3
/// Blood units the Vigil of Blood demands in total
#define VESTIGE_VIGIL_BLOOD_TOTAL 400
/// Blood units drawn per altar donation
#define VESTIGE_VIGIL_BLOOD_PER_DONATION 100
/// Devour points the Trial of the Snuffed Flame demands (lights in someone else's grip count double)
#define VESTIGE_FLAME_LIGHTS_NEEDED 25
