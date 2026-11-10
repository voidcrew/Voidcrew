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
#define BB_NPC_RETREAT_START "npc_retreat_start"      // world.time the current retreat began (stamped by set_combat_state)

/// Hard cap on how long a ship stays in RETREATING before writing the encounter off and
/// returning to patrol. The distance-based escape (15+ tiles from the last target) is
/// unreachable for a zone-confined ship whose chaser simply stays nearby - round 4 left
/// two pirates wedged in RETREATING for 21 hours (156,929 retreat_escape calls against a
/// single return_to_patrol all round), which emptied the yellow band of working pirates.
#define NPC_RETREAT_TIME_LIMIT (2 MINUTES)

/// Time to board and claim a disarmed pirate before its unclaimed hull is cleaned up.
#define NPC_DISARMED_DESPAWN_TIME (10 MINUTES)

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
/// TRUE while hailing a target whose accounts came back empty. The resulting
/// negotiation demands cargo instead of credits - see /datum/pirate_negotiation/barter_only.
#define BB_NPC_BROKE_BARTER "npc_broke_barter"

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
/// Which impatience warning escalates a barter demand. 1 = the first warning, so 2
/// means "you stalled past the first warning and still haven't put anything on the pad".
#define NEGOTIATION_BARTER_ESCALATE_WARNING 2
/// How many extra units get added to a barter demand when it escalates.
#define NEGOTIATION_BARTER_ESCALATE_AMOUNT 1

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

// Crew-wipe tracking (applies to every engaged state, not just phased boarding)
#define BB_NPC_TARGET_CREW_SEEN "npc_target_crew_seen"  // TRUE once we've read at least one living crewmember aboard the current target
#define BB_NPC_CREW_WIPE_SINCE "npc_crew_wipe_since"    // World.time we first read zero living crew aboard the target

// Boarding signals
#define COMSIG_BOARDING_WAVE_COMPLETE "boarding_wave_complete"      // Fired when all boarders in wave die
#define COMSIG_BOARDING_BOSS_KILLED "boarding_boss_killed"          // Fired when boss is killed
#define COMSIG_BOARDING_PLAYER_CREW_DIED "boarding_player_crew_died" // Fired when tracked player crew dies
#define COMSIG_BOARDING_ESCALATED "boarding_escalated"              // Fired when player aggression escalates to full combat

// Boarding timing constants
#define NPC_BOARDING_WAVE_COUNT 1                  // One crew-sized wave, then a boss in red
#define NPC_BOARDING_WAVE_COOLDOWN (30 SECONDS)    // Time between waves
#define NPC_BOARDING_DISENGAGE_DELAY (10 SECONDS)  // Time before pirates leave after victory
#define NPC_BOARDING_WAVE_TIME_LIMIT (3 MINUTES)   // Max time per wave before escalation
#define NPC_BOARDING_SPACE_CHECK_INTERVAL (10 SECONDS)  // How often to check if boarders fell into space
/// How long a target has to read as "nobody alive aboard" before we call it a wipe and
/// break off. A grace window, not a formality: a defib or a crit-recovery inside it puts
/// the raid straight back on, and it also rides out the momentary zero a ship reads while
/// it's mid-dock or mid-z-transit.
#define NPC_CREW_WIPE_CONFIRM_TIME (15 SECONDS)

// Ship combat boarding pod constants
#define NPC_SHIP_COMBAT_MAX_BOARDERS 10            // Max hostile mobs during ship combat phase
#define NPC_SHIP_COMBAT_POD_COOLDOWN (15 SECONDS)  // Cooldown between boarding pod volleys

// ========== NPC HULL WEALTH ==========
// What a pirate is carrying in its own accounts, and therefore what a crew can
// take back off it with a data siphon. Rolled per hull from the faction's
// hold_credits_min/max at spawn and scaled by the zone it spawned in - a red
// zone raider is running with a fuller hold than a yellow zone shakedown crew.
#define NPC_HOLD_ZONE_MULT_GREEN 0.75
#define NPC_HOLD_ZONE_MULT_YELLOW 1
#define NPC_HOLD_ZONE_MULT_RED 1.5

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

// How long an abandoned scan holds the pirate off the same ship. Long enough to break
// the acquire/abort/re-announce loop, short enough that a ship which only briefly
// slipped out of range is fair game again soon.
#define NPC_SCAN_ABORT_MEMORY_TIME (1 MINUTES)

// Extra tiles beyond territory_range a target may drift during a financial scan before
// the scan is abandoned. Acquisition happens right at territory_range, so without slack
// one tile of drift by either hull aborts a 6-second scan a second or two in.
#define NPC_SCAN_RANGE_SLACK 2

// ========== PARKED-SHIP RECOVERY ==========
// Both AI subtrees stand down whenever the ship isn't OVERMAP_SHIP_FLYING, and nothing
// else in the game ever undocks an NPC hull - so before the recovery behavior existed,
// a single player force-dock (or a crash-land) was a permanent kill switch for that
// ship's AI. Round 4's Ghostship docked at 04:34 and sat AI-silent for the rest of a
// 22-hour round with its crew alive aboard.

/// world.time the AI first noticed its ship parked (state != FLYING). Cleared, with a
/// log line, the first planning pass after the ship is flying again.
#define BB_NPC_PARKED_SINCE "npc_parked_since"
/// How long a ship must have been parked before the AI tries to undock and resume
/// patrol. Longer than the 2 minute interdictor force-dock lockout on purpose, so a
/// force-docked pirate doesn't launch back out into the face of whoever boarded it the
/// second its clamps release. INVENTED value, not playtested.
#define NPC_PARKED_RECOVERY_DELAY (3 MINUTES)

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
/// How often a hull re-reads its thruster bank for the step budget (see
/// /obj/structure/overmap/ship/npc/refresh_thrust_state). Movement behaviors tick every
/// 2-8 seconds, so this costs at most one engine sweep per hull per interval.
#define NPC_THRUST_RECALC_INTERVAL (2 SECONDS)

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

// ========== PIRATE BOUNTIES ==========
// Only some pirate ships carry a bounty at a time; the rest are just a threat. Bounties come and go.

/// The share of crewed pirate ships with a bounty on them (always at least one)
#define PIRATE_BOUNTY_SHARE 0.5
/// How long a bounty stays up while nobody hunts it
#define PIRATE_BOUNTY_LIFETIME_MIN (30 MINUTES)
#define PIRATE_BOUNTY_LIFETIME_MAX (50 MINUTES)
/// A ship whose bounty ran out carries no new one for this long, so the bounties move around
#define PIRATE_BOUNTY_REST (20 MINUTES)
/// Between two new bounties once the round is running
#define PIRATE_BOUNTY_POST_GAP (3 MINUTES)

// ========== PIRATE CREW AI (pirate_crew.dm, pirate_crew_ai.dm) ==========
// The crew an NPC hull spawns with, and the boarders a pirate puts on a player ship, share one
// /datum/pirate_crew per side of the fight. Unit tests can't see these; they use the literals.

/// The /datum/pirate_crew this mob fights for
#define BB_PIRATE_CREW "pirate_crew"
/// PIRATE_ROLE_* for this mob
#define BB_PIRATE_ROLE "pirate_role"
/// Where this mob spawned or landed; it wanders near it and walks back to it when the crew calms down
#define BB_PIRATE_HOME_TURF "pirate_home_turf"
/// The hostile the crew sent this mob after
#define BB_PIRATE_HUNT_TARGET "pirate_hunt_target"
/// The turf this mob is walking to on the hunt
#define BB_PIRATE_HUNT_TURF "pirate_hunt_turf"
/// A stop part way along a route too long for one path
#define BB_PIRATE_WAYPOINT "pirate_waypoint"
/// Where a post holder is walking back to
#define BB_PIRATE_POST_TURF "pirate_post_turf"
/// Where a mob that strayed is walking back to
#define BB_PIRATE_RETURN_TURF "pirate_return_turf"
/// The door (or wrecked door frame) this mob is breaking through
#define BB_PIRATE_BREACH_TARGET "pirate_breach_target"
/// The turf it breaks the door from
#define BB_PIRATE_BREACH_STAND "pirate_breach_stand"
/// The turf the door stands on, so a frame left behind by the door is broken too
#define BB_PIRATE_BREACH_TURF "pirate_breach_turf"
/// world.time the current breach started
#define BB_PIRATE_BREACH_STARTED "pirate_breach_started"
/// world.time the pathfinder last found no way to the movement target
#define BB_PIRATE_NO_PATH_AT "pirate_no_path_at"
/// The turf it found no way to
#define BB_PIRATE_NO_PATH_DEST "pirate_no_path_dest"

#define PIRATE_ROLE_CAPTAIN "captain"
#define PIRATE_ROLE_GUARD "guard"
#define PIRATE_ROLE_HUNTER "hunter"

/// How far a pirate may take a fight (see target_reach() in pirate_crew_ai.dm)
#define PIRATE_TARGET_OUT 0
#define PIRATE_TARGET_CHASE 1
#define PIRATE_TARGET_HOLD 2

#define PIRATE_BARK_ALERT "alert"
#define PIRATE_BARK_SPOT "spot"
#define PIRATE_BARK_CROSS "cross"
#define PIRATE_BARK_CAPTAIN "captain"

/// How often an alerted crew re-reads where every hostile on its battlefield is
#define PIRATE_CREW_INTEL_INTERVAL (5 SECONDS)
/// How often a crew re-reads which ships make up its battlefield
#define PIRATE_CREW_BATTLEFIELD_INTERVAL (5 SECONDS)
/// A defending crew stands down after this long with no hostile on its battlefield
#define PIRATE_CREW_CALM_DELAY (90 SECONDS)
/// Members still walking home this long after standing down are let idle where they are
#define PIRATE_CREW_SETTLE_TIMEOUT (60 SECONDS)
/// How far a pirate looks for someone to fight
#define PIRATE_CREW_SIGHT_RANGE 9
/// How far from their post the captain and the guard will chase someone
#define PIRATE_CREW_POST_LEASH 7
/// How far past the edge of its battlefield a pirate keeps chasing someone it can see
#define PIRATE_CREW_CHASE_MARGIN 3
/// How far a calm pirate wanders from home
#define PIRATE_CREW_IDLE_LEASH 5
/// A hunt is re-routed only when its quarry has moved this far from where it was headed
#define PIRATE_CREW_HUNT_REQUEUE_DIST 2
/// Longest path the pirate movement datum asks for; two docked hulls run past tg's default 30
#define PIRATE_CREW_MAX_PATH 64
/// How far along a long route a waypoint is put
#define PIRATE_CREW_WAYPOINT_STEPS 40
/// How long a waypoint is followed before it's dropped
#define PIRATE_CREW_WAYPOINT_TIMEOUT (20 SECONDS)
/// Time between blows on a door
#define PIRATE_CREW_BREACH_COOLDOWN (1.2 SECONDS)
/// A door that still stands after this long is given up on
#define PIRATE_CREW_BREACH_GIVE_UP (30 SECONDS)
/// And left alone for this long
#define PIRATE_CREW_BREACH_SKIP_TIME (60 SECONDS)
/// Per mob, between searches for the door in the way
#define PIRATE_CREW_BREACH_SEARCH_COOLDOWN (5 SECONDS)
/// A search looks at no more turfs than this. Two of the largest hulls docked together are about 4500.
#define PIRATE_CREW_BREACH_SEARCH_LIMIT 6000
/// How often one pirate may log that it found no way to its quarry
#define PIRATE_CREW_NO_WAY_LOG_COOLDOWN (30 SECONDS)
/// A "no path" older than this no longer starts a search
#define PIRATE_CREW_NO_PATH_WINDOW (3 SECONDS)
/// After a search finds no way at all, the hunt waits this long before trying the same place again
#define PIRATE_CREW_UNREACHABLE_BACKOFF (5 SECONDS)
/// A door that should open for a pirate but stays shut this long while it keeps walking into it is treated as refusing
#define PIRATE_CREW_STUCK_DOOR_TIME (3 SECONDS)
/// Bumps further apart than this start the stuck-door clock again
#define PIRATE_CREW_STUCK_DOOR_RESET (10 SECONDS)
/// Per mob, between swapping places with an ally
#define PIRATE_CREW_SWAP_COOLDOWN (1 SECONDS)
/// Per mob, between "there he is" lines
#define PIRATE_CREW_SPOT_BARK_MOB (20 SECONDS)
/// Percent chance a pirate shouts as it reloads (pirate_guns.dm)
#define PIRATE_CREW_RELOAD_BARK_CHANCE 35
/// Per crew, between "there he is" lines
#define PIRATE_CREW_SPOT_BARK_CREW (6 SECONDS)
/// Per crew, between "into their ship" lines
#define PIRATE_CREW_CROSS_BARK_CREW (30 SECONDS)
/// How often a pirate with no target looks around for one
#define PIRATE_CREW_SCAN_COOLDOWN (1 SECONDS)
