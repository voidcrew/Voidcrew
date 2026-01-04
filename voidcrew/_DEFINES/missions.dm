// Mission signals (sent by mission datum)
#define COMSIG_MISSION_STARTED "mission_started"
#define COMSIG_MISSION_COMPLETED "mission_completed"
#define COMSIG_MISSION_FAILED "mission_failed"

// Default config
#define DEFAULT_AVAILABLE_MISSIONS 5
#define DEFAULT_CREW_SHARE 0.5
#define DEFAULT_MAX_ACTIVE_MISSIONS 3
#define DEFAULT_MISSION_DURATION (30 MINUTES)

// Value variance range (±10%)
#define MISSION_VALUE_VARIANCE 0.1

// Overmap bounds for exploration missions (relative coords, 1 to OVERMAP_SIZE)
// Avoid edges (1 tile border) and some buffer
#define MISSION_OVERMAP_MIN_COORD 3
#define MISSION_OVERMAP_MAX_COORD (OVERMAP_SIZE - 2)
