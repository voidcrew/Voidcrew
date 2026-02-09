// Cached blocked turfs for O(1) pathfinding lookups (populated at round start)
GLOBAL_LIST_EMPTY(overmap_blocked_turfs)

// Patrol stagger counter - prevents mobs from all targeting the same door
GLOBAL_LIST_EMPTY(patrol_stagger_counter)

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
#define NPC_COMBAT_HAILING "hailing"    // Hailing target - waiting for them to answer
#define NPC_COMBAT_ENGAGING "engaging"
#define NPC_COMBAT_COMBAT "combat"
#define NPC_COMBAT_SIPHONING "siphoning"  // Yellow zone: interdict + siphon (no weapons/boarding)
#define NPC_COMBAT_RETREATING "retreating"
#define NPC_COMBAT_NEGOTIATING "negotiating"
// Boarding phase states (phased combat system)
#define NPC_COMBAT_BOARDING "boarding"                    // Active wave in progress
#define NPC_COMBAT_BOARDING_COOLDOWN "boarding_cooldown"  // 60-second break between waves
#define NPC_COMBAT_BOSS_PHASE "boss_phase"                // Boss spawned, awaiting outcome
#define NPC_COMBAT_DISABLED "disabled"                    // Ship disabled, player can board
#define NPC_COMBAT_DISENGAGING "disengaging"              // Pirates won, leaving

// Hailing phase blackboard keys
#define BB_NPC_HAILING_START "npc_hailing_start"          // When hailing started
#define BB_NPC_HAILING_ANNOUNCED "npc_hailing_announced"  // Whether initial hail was sent
#define BB_NPC_TARGET_LAST_POS "npc_target_last_pos"      // Target position when negotiation started (to detect movement)

// Hailing/negotiation timing
#define NPC_HAILING_GRACE_PERIOD (20 SECONDS)     // Time to answer the hail before combat
#define NPC_HAILING_REMINDER_INTERVAL (10 SECONDS)  // Reminder halfway through

// Signals for player aggression detection
#define COMSIG_SHIP_WEAPONS_LOCKED "ship_weapons_locked"  // Fired when player locks weapons on a ship
#define COMSIG_SHIP_WEAPONS_LOCK_LOST "ship_weapons_lock_lost"  // Fired when weapon lock on a ship is lost
#define COMSIG_SHIP_MOVED_DURING_NEGOTIATION "ship_moved_during_negotiation"

// Negotiation blackboard keys
#define BB_NPC_NEGOTIATION "npc_negotiation"
#define BB_NPC_NEGOTIATION_START "npc_negotiation_start"
#define BB_NPC_PAID_TRIBUTE_SHIPS "npc_paid_tribute_ships"
#define BB_NPC_FAILED_NEGOTIATION_SHIPS "npc_failed_negotiation_ships"  // Ships that refused/failed negotiation - no second chances

// Negotiation states
#define NEGOTIATION_PENDING "pending"
#define NEGOTIATION_ACTIVE "active"
#define NEGOTIATION_PAYING "paying"
#define NEGOTIATION_ACCEPTED "accepted"
#define NEGOTIATION_REJECTED "rejected"
#define NEGOTIATION_TIMEOUT "timeout"

// Negotiation signals
#define COMSIG_SHIP_HAILED "ship_hailed"
#define COMSIG_NEGOTIATION_STARTED "negotiation_started"
#define COMSIG_NEGOTIATION_ENDED "negotiation_ended"

// Negotiation timing
#define NEGOTIATION_DEFAULT_TIMEOUT (2 MINUTES)
#define NEGOTIATION_IMMUNITY_TIME (5 MINUTES)
#define NEGOTIATION_IMMUNITY_DURATION (5 MINUTES)
#define NEGOTIATION_WARNING_TIMES list(60, 30, 10)  // Seconds before timeout to warn

// Negotiation payment signal
#define COMSIG_NEGOTIATION_PAYMENT "negotiation_payment"

// ========== BOARDING PHASE SYSTEM ==========

// Boarding blackboard keys
#define BB_NPC_BOARDING_WAVE "npc_boarding_wave"                    // Current wave number (1, 2, 3)
#define BB_NPC_BOARDING_WAVE_BOARDERS "npc_boarding_wave_boarders"  // List of mobs in current wave
#define BB_NPC_BOARDING_COOLDOWN_END "npc_boarding_cooldown_end"    // World.time when cooldown ends
#define BB_NPC_BOARDING_BOSS "npc_boarding_boss"                    // Reference to spawned boss mob
#define BB_NPC_BOARDING_PLAYER_CREW "npc_boarding_player_crew"      // List of tracked player crew
#define BB_NPC_BOARDING_INITIAL_CREW_COUNT "npc_boarding_crew_count" // Crew count at boarding start (for wave scaling)
#define BB_NPC_BOARDING_WAVE_START_TIME "npc_boarding_wave_start"   // World.time when current wave started
#define BB_NPC_BOARDING_TARGET_POS "npc_boarding_target_pos"        // Target position at boarding start (for movement detection)

// Boarding signals
#define COMSIG_BOARDING_WAVE_COMPLETE "boarding_wave_complete"      // Fired when all boarders in wave die
#define COMSIG_BOARDING_BOSS_KILLED "boarding_boss_killed"          // Fired when boss is killed
#define COMSIG_BOARDING_PLAYER_CREW_DIED "boarding_player_crew_died" // Fired when tracked player crew dies
#define COMSIG_BOARDING_ESCALATED "boarding_escalated"              // Fired when player aggression escalates to full combat

// Boarding timing constants
#define NPC_BOARDING_WAVE_COUNT 3                  // Number of waves before boss
#define NPC_BOARDING_WAVE_COOLDOWN (30 SECONDS)    // Time between waves
#define NPC_BOARDING_DISENGAGE_DELAY (10 SECONDS)  // Time before pirates leave after victory
#define NPC_BOARDING_WAVE_TIME_LIMIT (3 MINUTES)   // Max time per wave before escalation
#define NPC_BOARDING_SPACE_CHECK_INTERVAL (10 SECONDS)  // How often to check if boarders fell into space

// Ship combat boarding pod constants
#define NPC_SHIP_COMBAT_MAX_BOARDERS 10            // Max hostile mobs during ship combat phase
#define NPC_SHIP_COMBAT_POD_COOLDOWN (15 SECONDS)  // Cooldown between boarding pod volleys

// Additional boarding blackboard keys
#define BB_NPC_BOARDING_LAST_SPACE_CHECK "npc_boarding_space_check"  // Last time we checked for boarders in space

// Bounty ship part rewards
#define BOUNTY_LIGHT_SHIP_PARTS 1
#define BOUNTY_HEAVY_SHIP_PARTS 3

// Scanning blackboard keys
#define BB_NPC_SCAN_START_TIME "npc_scan_start_time"  // When scan started
#define BB_NPC_SCAN_COMPLETE "npc_scan_complete"      // Whether scan finished
#define BB_NPC_SCANNED_SHIPS "npc_scanned_ships"      // Assoc list of ship ref -> time scanned
#define BB_NPC_SCAN_ANNOUNCED "npc_scan_announced"    // Whether we announced scan start

// Combat action commitment blackboard keys (for action priority system)
#define BB_NPC_LAST_COMBAT_ACTION "npc_last_combat_action"      // Last offensive action taken
#define BB_NPC_INTERDICTOR_START_TIME "npc_interdictor_start"   // When interdiction was activated
#define BB_NPC_SIPHON_START_TIME "npc_siphon_start"             // When siphon was activated

// Combat action types (for action priority)
#define NPC_ACTION_FIRE_WEAPONS "fire_weapons"
#define NPC_ACTION_FIRE_BOARDING_PODS "fire_boarding_pods"
#define NPC_ACTION_USE_INTERDICTOR "use_interdictor"
#define NPC_ACTION_ACTIVATE_SIPHON "activate_siphon"

// Commitment delays (time after starting an action before other actions can be taken)
#define NPC_INTERDICTOR_COMMITMENT_DELAY (3 SECONDS)  // Delay after starting interdiction
#define NPC_SIPHON_COMMITMENT_DELAY (2 SECONDS)       // Delay after activating siphon

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

// ========== MOB PATROL SYSTEM (JPS-based) ==========
// Cached patrol paths for boarding parties (keyed by ship ref)
GLOBAL_LIST_EMPTY(boarding_patrol_paths)
// Cached list of doors that require access (keyed by ship ref -> list of door refs)
// Pirates have no access, so these doors need to be attacked, not bumped
GLOBAL_LIST_EMPTY(boarding_locked_doors)
// Tracks which ships have had their patrol path visualized (debug mode only)
GLOBAL_VAR(patrol_paths_visualized)
// Stores visualization markers for patrol paths (keyed by ship ref)
GLOBAL_LIST_EMPTY(patrol_path_markers)

// Mob patrol blackboard keys
#define BB_MOB_PATROL_PATH "mob_patrol_path"          // Reference to the cached patrol path list
#define BB_MOB_PATROL_INDEX "mob_patrol_index"        // Current index in the patrol path (1-based)
#define BB_MOB_PATROL_TARGET "mob_patrol_target"      // Current patrol waypoint (target door)
#define BB_MOB_PATROL_SHIP_REF "mob_patrol_ship_ref"  // REF() of the ship being patrolled
#define BB_MOB_PATROL_TARGET_TURF "mob_patrol_target_turf"  // Turf of current patrol target (for assembly check when door destroyed)
#define BB_MOB_PATROL_ORIGIN_ROOM "mob_patrol_origin_room"  // Room we were in when we started approaching current target door
#define BB_DOOR_TO_OPEN "door_to_open"                // Door we're trying to open

// Door attack timeout (for reinforced doors)
#define PATROL_DOOR_ATTACK_TIMEOUT (45 SECONDS)

// ========== ROOM EXPLORATION SYSTEM ==========
// Cached room data for ship exploration (populated during patrol path generation)
GLOBAL_LIST_EMPTY(ship_rooms)      // ship_ref -> list(room_id -> room_data)
GLOBAL_LIST_EMPTY(turf_to_room)    // ship_ref -> list(turf_ref -> room_id) - O(1) lookup
GLOBAL_LIST_EMPTY(door_to_rooms)   // ship_ref -> list(door_ref -> list(room_id_1, room_id_2))

// Room exploration blackboard keys
#define BB_LAST_KNOWN_ROOM "_last_known_room"                     // Last room mob was in (for transition detection)
#define BB_EXPLORED_ROOMS "_explored_rooms"                       // Rooms explored this cycle (use LAZYSET)
#define BB_EXPLORING_ROOM "_exploring_room"                       // Current room being explored
#define BB_EXPLORATION_TARGETS "_exploration_targets"             // List of targets (closets + turfs)
#define BB_EXPLORATION_INDEX "_exploration_index"                 // Current target index
#define BB_EXPLORATION_TARGET "_exploration_target"               // Current exploration target

// Room exploration constants
#define EXPLORATION_MAX_LOCKERS 3                                 // Cap locker targets per room
#define EXPLORATION_MIN_ROOM_SIZE 4                               // Skip exploration for rooms smaller than this

