// Cached blocked turfs for O(1) pathfinding lookups (populated at round start)
GLOBAL_LIST_EMPTY(overmap_blocked_turfs)

// NPC Ship AI Blackboard Keys
#define BB_NPC_TARGET "npc_target"                    // Target ship reference
#define BB_NPC_TARGET_LOCKED "npc_target_locked"      // TRUE if weapons locked
#define BB_NPC_LOCK_START_TIME "npc_lock_start_time"  // When lock started
#define BB_NPC_COMBAT_STATE "npc_combat_state"        // idle/engaging/combat

// Movement blackboard keys
#define BB_NPC_MOVEMENT_MODE "npc_movement_mode"      // patrol/chase/return_to_route/roaming
#define BB_NPC_PATROL_CIRCUIT "npc_patrol_circuit"    // List of circuit waypoints (circular patrol)
#define BB_NPC_CIRCUIT_INDEX "npc_circuit_index"      // Current waypoint index on circuit
#define BB_NPC_CURRENT_PATH "npc_current_path"        // Current A* path (list of turfs)
#define BB_NPC_PATH_INDEX "npc_path_index"            // Current index in path (1-based)
#define BB_NPC_PATH_TIMESTAMP "npc_path_timestamp"    // world.time when path was calculated
#define BB_NPC_SPAWN_ZONE "npc_spawn_zone"            // Zone ship spawned in (can't leave)
#define BB_NPC_HAD_TARGET "npc_had_target"            // TRUE if we were just chasing (for return_to_route)
#define BB_NPC_TARGET_TILE "npc_target_tile"          // The specific tile we're moving toward

// Combat states
#define NPC_COMBAT_IDLE "idle"
#define NPC_COMBAT_ENGAGING "engaging"
#define NPC_COMBAT_COMBAT "combat"

// Movement modes
#define NPC_MOVEMENT_IDLE "idle"
#define NPC_MOVEMENT_PATROL "patrol"
#define NPC_MOVEMENT_CHASE "chase"
#define NPC_MOVEMENT_RETURN_TO_ROUTE "return_to_route"
#define NPC_MOVEMENT_ROAMING "roaming"

// Config
#define NPC_SHIP_TERRITORY_RANGE 2        // Detect and attack within 2 tiles (escape at 3+ tiles)
#define NPC_SHIP_LOCK_TIME (5 SECONDS)    // Match player lock time
#define NPC_SHIP_MAX_SHIPS 5              // Max pirates per round
#define NPC_SHIP_SPAWN_INTERVAL (30 SECONDS)

// Weapon cooldowns (simplified - no ammo tracking)
#define NPC_LASER_COOLDOWN (5 SECONDS)
#define NPC_MISSILE_COOLDOWN (10 SECONDS)

// Movement config
#define NPC_SHIP_ACCELERATION 0.3         // Fixed acceleration per burn (ignores mass/engine power)
#define NPC_SHIP_MAX_SPEED 0.5            // Max speed cap (tiles per tick)
#define NPC_SHIP_PATROL_THRESHOLD 3       // How close to waypoint before moving on
#define NPC_SHIP_OBSTACLE_SCAN_RANGE 1    // How far ahead to scan for obstacles
#define NPC_SHIP_REPATH_INTERVAL (2 SECONDS) // How often to recalculate A* paths
#define NPC_SHIP_CIRCUIT_WAYPOINTS 12     // Number of waypoints in patrol circuit
#define NPC_SHIP_ORBIT_VARIANCE 0.15      // Radius variance for patrol circuits (15%)

// Pirate crew config
#define NPC_SHIP_CREW_MIN 3
#define NPC_SHIP_CREW_MAX 6
