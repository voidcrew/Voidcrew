// Vestige ruin (antag boon) tuning knobs (see voidcrew/modules/antag_ruins/)

/// When the first vestige ruin surfaces on the overmap
#define VESTIGE_FIRST_SPAWN_TIME (20 MINUTES)
/// Delay between subsequent vestige ruin arrivals
#define VESTIGE_SPAWN_INTERVAL (15 MINUTES)
/// Hard cap on vestige ruins per round (also capped by how many themes exist)
#define VESTIGE_MAX_PER_ROUND 14

/// Most boon candidates a fulfilled pact offers at once (fewer if the patron has less left to give)
#define VESTIGE_REWARD_CHOICES 3

// ===== ASCENSION (endgame capstone boons, see modules/antag_ruins/ascension.dm) =====

/// Round time before a patron will discuss ascension at all.
#define VESTIGE_ASCENSION_UNLOCK_TIME (90 MINUTES)
/// Hard ceiling on one ascension run. Expiry returns a living supplicant home, failed.
#define VESTIGE_ASCENSION_TIME_LIMIT (30 MINUTES)
/// Grace period after the boss dies before the arena pulls the victor out on its own.
#define VESTIGE_ASCENSION_VICTORY_GRACE (6 MINUTES)
/// Blank turfs left around the arena template inside its reservation.
#define VESTIGE_ASCENSION_ARENA_PADDING 3

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
/// Burn damage the mana geode must drink from its holder (Trial of the Singed Hand)
#define VESTIGE_SINGED_BURN_NEEDED 100
/// Surfaces the corroding chrism must rust (Rite of Rust)
#define VESTIGE_RUST_TURFS_NEEDED 20
/// Distinct corpses the pale lantern must drain (Vigil of the Last Breath)
#define VESTIGE_LANTERN_CORPSES_NEEDED 5
/// Thrown training-star hits the Trial of the Thrown Star demands
#define VESTIGE_STAR_HITS_NEEDED 10
/// Most hits any single victim can credit toward the Trial of the Thrown Star
#define VESTIGE_STAR_HITS_PER_VICTIM 3
/// Cumulative seconds in hard vacuum the Trial of the Long Dark demands
#define VESTIGE_VOID_SECONDS_NEEDED 300
