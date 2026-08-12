// Purity tiers for finished product, judged on the combined 0-300 lab score
#define DRUG_PURITY_STREET 1
#define DRUG_PURITY_PURE 2
#define DRUG_PURITY_PRIMO 3

/// Combined score at or above this is primo grade
#define DRUG_SCORE_PRIMO_THRESHOLD 240
/// Combined score at or above this (but below primo) is pure grade
#define DRUG_SCORE_PURE_THRESHOLD 150

// Payout multipliers applied to the mission's base value per tier
#define DRUG_PAYOUT_MULT_STREET 0.7
#define DRUG_PAYOUT_MULT_PURE 1
#define DRUG_PAYOUT_MULT_PRIMO 1.4

// Lab machine state progression
#define DRUG_LAB_STAGE_LOADING 1
#define DRUG_LAB_STAGE_MIXER 2
#define DRUG_LAB_STAGE_CATALYST 3
#define DRUG_LAB_STAGE_CRYSTALLIZER 4
#define DRUG_LAB_STAGE_DONE 5

// Station indices, used to key per-station scores and attempt counts
#define DRUG_STATION_MIXER 1
#define DRUG_STATION_CATALYST 2
#define DRUG_STATION_CRYSTALLIZER 3

// Minigame geometry, shared by the recipe charts, the machines and their TGUIs
#define DRUG_MIXER_HOPPER_COUNT 4
#define DRUG_CATALYST_LANE_COUNT 4
#define DRUG_CRYSTALLIZER_COL_COUNT 5

/// How many attempts a crew gets at each station before its score locks in
#define DRUG_STATION_ATTEMPTS 3
/// Score ceiling per attempt number: retries cap lower, so first tries matter
#define DRUG_ATTEMPT_MAX_SCORES list(100, 75, 50)

// Customs patrol tuning
/// Percent chance a patrol spawns to shake the ship down during the run
#define DRUG_COP_CHANCE 50
/// Fraction of the mission payout demanded as a fine when caught
#define DRUG_COP_FINE_FRACTION 0.4
#define DRUG_COP_FINE_MIN 1000
#define DRUG_COP_FINE_MAX 20000
/// How long the patrol tails the ship before losing interest
#define DRUG_COP_GIVEUP_TIME (4 MINUTES)
/// Debug: when defined, the patrol always spawns regardless of DRUG_COP_CHANCE
//#define DRUG_COP_FORCE_ROLL

// Lab hazard tuning: botched attempts have consequences
/// An attempt scoring below this counts as a botch and rolls for a hazard
#define DRUG_HAZARD_BOTCH_SCORE 40
/// Percent chance a botched attempt vents toxic fumes over the machine
#define DRUG_HAZARD_FUME_CHANCE 35
/// Percent chance a botched attempt sparks a fire instead of fumes
#define DRUG_HAZARD_FIRE_CHANCE 15
/// Reagent volume of the fume cloud released on a fume hazard
#define DRUG_HAZARD_FUME_VOLUME 30
/// Shock damage the catalyst's electrical hazard deals its operator, a
/// nasty jolt plus the standard stun, never anything close to lethal
#define DRUG_HAZARD_SHOCK_DAMAGE 15
