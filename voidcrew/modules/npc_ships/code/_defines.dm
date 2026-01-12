// Cached blocked turfs for O(1) pathfinding lookups (populated at round start)
GLOBAL_LIST_EMPTY(overmap_blocked_turfs)

// NPC Ship AI Blackboard Keys
#define BB_NPC_TARGET "npc_target"                    // Target ship reference
#define BB_NPC_TARGET_LOCKED "npc_target_locked"      // TRUE if weapons locked
#define BB_NPC_LOCK_START_TIME "npc_lock_start_time"  // When lock started
#define BB_NPC_COMBAT_STATE "npc_combat_state"        // idle/engaging/combat
#define BB_NPC_RETREAT_REASON "npc_retreat_reason"    // Why we're retreating (siphon_goal, no_weapons)
#define BB_NPC_LAST_TARGET "npc_last_target"          // Who we were fighting before retreating

// Movement blackboard keys
#define BB_NPC_MOVEMENT_MODE "npc_movement_mode"      // patrol/chase/return_to_route/roaming
#define BB_NPC_PATROL_CIRCUIT "npc_patrol_circuit"    // List of circuit waypoints (circular patrol)
#define BB_NPC_CIRCUIT_INDEX "npc_circuit_index"      // Current waypoint index on circuit
#define BB_NPC_CURRENT_PATH "npc_current_path"        // Current A* path (list of turfs)
#define BB_NPC_PATH_INDEX "npc_path_index"            // Current index in path (1-based)
#define BB_NPC_SPAWN_ZONE "npc_spawn_zone"            // Zone ship spawned in (can't leave)
#define BB_NPC_HAD_TARGET "npc_had_target"            // TRUE if we were just chasing (for return_to_route)

// Combat states
#define NPC_COMBAT_IDLE "idle"
#define NPC_COMBAT_SCANNING "scanning"  // Scanning target for wealth before engaging
#define NPC_COMBAT_ENGAGING "engaging"
#define NPC_COMBAT_COMBAT "combat"
#define NPC_COMBAT_RETREATING "retreating"

// Scanning blackboard keys
#define BB_NPC_SCAN_START_TIME "npc_scan_start_time"  // When scan started
#define BB_NPC_SCAN_COMPLETE "npc_scan_complete"      // Whether scan finished
#define BB_NPC_SCANNED_SHIPS "npc_scanned_ships"      // Assoc list of ship ref -> time scanned
#define BB_NPC_SCAN_ANNOUNCED "npc_scan_announced"    // Whether we announced scan start

// How long to remember a scanned ship before re-scanning (5 minutes)
#define NPC_SCAN_MEMORY_TIME (5 MINUTES)

// Movement modes
#define NPC_MOVEMENT_IDLE "idle"
#define NPC_MOVEMENT_PATROL "patrol"
#define NPC_MOVEMENT_CHASE "chase"
#define NPC_MOVEMENT_RETURN_TO_ROUTE "return_to_route"
#define NPC_MOVEMENT_ROAMING "roaming"
#define NPC_MOVEMENT_RETREAT "retreat"

// Spawner config (subsystem-level settings)
#define NPC_SHIP_MAX_SHIPS 5              // Max NPC ships per round
#define NPC_SHIP_SPAWN_INTERVAL (30 SECONDS)

// Movement behavior config (shared by all ship types)
#define NPC_SHIP_PATROL_THRESHOLD 3       // How close to waypoint before moving on
#define NPC_SHIP_OBSTACLE_SCAN_RANGE 1    // How far ahead to scan for obstacles
#define NPC_SHIP_CIRCUIT_WAYPOINTS 12     // Number of waypoints in patrol circuit
#define NPC_SHIP_ORBIT_VARIANCE 0.15      // Radius variance for patrol circuits (15%)

// NOTE: Per-ship vars (territory_range, lock_time, cooldowns, speed, acceleration, crew)
// are now defined on /obj/structure/overmap/ship/npc and its subtypes.
// See npc_ship.dm for pirate ship configuration.

// Faction colors for ship identification
#define NPC_COLOR_PIRATE COLOR_RED            // Pirates - red
#define NPC_COLOR_NANOTRASEN "#4444FF"        // Nanotrasen - blue
#define NPC_COLOR_SYNDICATE "#8B0000"         // Syndicate - dark red
