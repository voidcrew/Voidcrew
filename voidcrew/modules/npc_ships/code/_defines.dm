// NPC Ship AI Blackboard Keys
#define BB_NPC_TARGET "npc_target"                    // Target ship reference
#define BB_NPC_TARGET_LOCKED "npc_target_locked"      // TRUE if weapons locked
#define BB_NPC_LOCK_START_TIME "npc_lock_start_time"  // When lock started
#define BB_NPC_COMBAT_STATE "npc_combat_state"        // idle/engaging/combat

// Movement blackboard keys
#define BB_NPC_MOVEMENT_MODE "npc_movement_mode"      // orbit/patrol/chase
#define BB_NPC_ORBIT_TARGET "npc_orbit_target"        // Celestial object to orbit
#define BB_NPC_ORBIT_DISTANCE "npc_orbit_distance"    // Desired orbit distance
#define BB_NPC_ORBIT_ANGLE "npc_orbit_angle"          // Current angle in orbit
#define BB_NPC_PATROL_WAYPOINTS "npc_patrol_waypoints"// List of patrol turfs
#define BB_NPC_PATROL_INDEX "npc_patrol_index"        // Current waypoint index
#define BB_NPC_CHASE_BOUNDARY "npc_chase_boundary"    // Max chase range from home
#define BB_NPC_HOME_TURF "npc_home_turf"              // Starting position

// Combat states
#define NPC_COMBAT_IDLE "idle"
#define NPC_COMBAT_ENGAGING "engaging"
#define NPC_COMBAT_COMBAT "combat"

// Movement modes
#define NPC_MOVEMENT_IDLE "idle"
#define NPC_MOVEMENT_ORBIT "orbit"
#define NPC_MOVEMENT_PATROL "patrol"
#define NPC_MOVEMENT_CHASE "chase"

// Config
#define NPC_SHIP_TERRITORY_RANGE 10       // Detect and attack within 10 tiles
#define NPC_SHIP_LOCK_TIME (5 SECONDS)    // Match player lock time
#define NPC_SHIP_MAX_SHIPS 5              // Max pirates per round
#define NPC_SHIP_SPAWN_INTERVAL (30 SECONDS)

// Weapon cooldowns (simplified - no ammo tracking)
#define NPC_LASER_COOLDOWN (5 SECONDS)
#define NPC_MISSILE_COOLDOWN (10 SECONDS)

// Movement config
#define NPC_SHIP_ACCELERATION 0.03        // How fast ships accelerate (slow and steady)
#define NPC_SHIP_MAX_SPEED 0.25           // Max speed magnitude (~4 seconds per tile)
#define NPC_SHIP_ORBIT_DISTANCE 5         // Default orbit distance in tiles
#define NPC_SHIP_PATROL_THRESHOLD 3       // How close to waypoint before moving on
#define NPC_SHIP_CHASE_RANGE 50           // Max tiles to chase from home (most of red zone)
#define NPC_SHIP_OBSTACLE_SCAN_RANGE 3    // How far ahead to scan for obstacles

// Pirate crew config
#define NPC_SHIP_CREW_MIN 3
#define NPC_SHIP_CREW_MAX 6
