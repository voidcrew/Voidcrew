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

/// Lit candles needed around an offering rune
#define VESTIGE_OFFERING_CANDLES 3
