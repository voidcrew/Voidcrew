// NPC Ship AI Blackboard Keys
#define BB_NPC_TARGET "npc_target"                    // weakref to target ship
#define BB_NPC_TARGET_LOCKED "npc_target_locked"      // TRUE if weapons locked
#define BB_NPC_LOCK_START_TIME "npc_lock_start_time"  // When lock started
#define BB_NPC_COMBAT_STATE "npc_combat_state"        // idle/engaging/combat

// Combat states
#define NPC_COMBAT_IDLE "idle"
#define NPC_COMBAT_ENGAGING "engaging"
#define NPC_COMBAT_COMBAT "combat"

// Config
#define NPC_SHIP_TERRITORY_RANGE 1        // Attack within 1 tile
#define NPC_SHIP_LOCK_TIME (5 SECONDS)    // Match player lock time
#define NPC_SHIP_MAX_SHIPS 5              // Max pirates per round
#define NPC_SHIP_SPAWN_INTERVAL (30 SECONDS)

// Weapon cooldowns (simplified - no ammo tracking)
#define NPC_LASER_COOLDOWN (5 SECONDS)
#define NPC_MISSILE_COOLDOWN (15 SECONDS)

// Pirate crew config
#define NPC_SHIP_CREW_MIN 3
#define NPC_SHIP_CREW_MAX 6
