// Mission signals (sent by mission datum)
#define COMSIG_MISSION_STARTED "mission_started"
#define COMSIG_MISSION_COMPLETED "mission_completed"
#define COMSIG_MISSION_FAILED "mission_failed"

// Mission difficulty levels
#define MISSION_DIFFICULTY_EASY 1
#define MISSION_DIFFICULTY_MEDIUM 2
#define MISSION_DIFFICULTY_HARD 3

// Default config
#define DEFAULT_AVAILABLE_MISSIONS 5
#define DEFAULT_MAX_ACTIVE_MISSIONS 3
#define DEFAULT_MISSION_DURATION (30 MINUTES)
#define MISSION_REFRESH_COOLDOWN (60 SECONDS)
/// Unaccepted board offers older than this are rotated out by SSmissions
#define MISSION_BOARD_EXPIRY (20 MINUTES)

// Overmap bounds for exploration missions (relative coords, 1 to OVERMAP_SIZE)
// Avoid edges (1 tile border) and some buffer
#define MISSION_OVERMAP_MIN_COORD 3
#define MISSION_OVERMAP_MAX_COORD (OVERMAP_SIZE - 2)

// What a mission does when its quest atom or target is lost mid-run
#define MISSION_QUEST_LOST_FAIL 0
#define MISSION_QUEST_LOST_RETARGET 1

/// How many times a retargeting mission may re-pick its target while active
#define MAX_MISSION_RETARGETS 2

// Results of offering an item to a mission's current objective
#define MISSION_ITEM_REFUSED 0
#define MISSION_ITEM_PROGRESS 1
#define MISSION_ITEM_COMPLETE 2

/// Weighted zone_mobs wave themes rolled per mission — who answers the noise
#define MISSION_WAVE_THEMES list(\
	/obj/effect/zone_mobs/pirate = 5,\
	/obj/effect/zone_mobs/syndicate = 4,\
	/obj/effect/zone_mobs/robot = 4,\
	/obj/effect/zone_mobs/undead = 3,\
	/obj/effect/zone_mobs/bug = 3,\
)
