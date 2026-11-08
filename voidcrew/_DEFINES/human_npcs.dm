// Human NPCs: real /mob/living/carbon/human bodies driven by an AI (voidcrew/modules/human_npcs/).
// Unit tests are included before voidcrew/_DEFINES, so nothing here is visible to them.

/// Returns TRUE if `thing` is a human NPC body.
#define ishumannpc(thing) istype(thing, /mob/living/carbon/human/npc)

// npc_rank: who may land hyperviolence aimed crits and gun executions (owner decision D4).
/// An ordinary NPC. Its hits never become aimed crits or executions.
#define HUMAN_NPC_RANK_REGULAR 0
/// An elite NPC. Lands aimed crits and executions the way a player does.
#define HUMAN_NPC_RANK_ELITE 1
/// A boss NPC. Lands aimed crits and executions the way a player does.
#define HUMAN_NPC_RANK_BOSS 2

/// On every item locked to a human NPC's body (human_npc_gear.dm).
#define TRAIT_HUMAN_NPC_GEAR "human_npc_gear"
/// On a consumable issued to a human NPC: it may leave the body, but never becomes loot (human_npc_gear.dm).
#define TRAIT_HUMAN_NPC_CONSUMABLE "human_npc_consumable"
/// On locked gear that went somewhere it may not be, and is deleted on the next tick unless it comes back.
#define TRAIT_HUMAN_NPC_GEAR_LOST "human_npc_gear_lost"

/// Default for how far a human NPC spots hostiles, in tiles (BB_AGGRO_RANGE).
#define HUMAN_NPC_SIGHT_RANGE 9

/// Human NPCs the spawn queue makes per fire of SShuman_npcs. One human costs about 11 ms to make.
#define HUMAN_NPC_SPAWNS_PER_FIRE 1
/// How often SShuman_npcs looks over the corpses it tracks.
#define HUMAN_NPC_CORPSE_SWEEP_INTERVAL (30 SECONDS)
/// Default time a human NPC corpse lies before it may be cleaned up (npc_corpse_lifetime).
#define HUMAN_NPC_CORPSE_LIFETIME (10 MINUTES)
/// A corpse or loose body part with a player this close is never cleaned up.
#define HUMAN_NPC_CORPSE_WATCH_RANGE 10
/// Corpses deleted per fire at most, so a big sweep doesn't stall a tick.
#define HUMAN_NPC_CORPSE_DELETES_PER_FIRE 2

// Blackboard keys (human_npc_ai.dm).
/// Deciseconds between two pulls of the trigger.
#define BB_HUMAN_NPC_SHOT_DELAY "human_npc_shot_delay"
/// world.time the NPC may next pull the trigger.
#define BB_HUMAN_NPC_NEXT_SHOT "human_npc_next_shot"
/// Furthest a gunner shoots from, in tiles. Further than this it closes in.
#define BB_HUMAN_NPC_FIRE_RANGE "human_npc_fire_range"
/// A gunner steps back from a target closer than this, in tiles. 0 never steps back.
#define BB_HUMAN_NPC_KEEP_AWAY "human_npc_keep_away"
/// world.time the NPC may next try to reload or change weapons, after a try that got nowhere.
#define BB_HUMAN_NPC_ARMING_RETRY_AT "human_npc_arming_retry_at"
/// world.time a reload in progress gives up.
#define BB_HUMAN_NPC_RELOAD_UNTIL "human_npc_reload_until"
/// The item the NPC is drawing (human_npc_draw).
#define BB_HUMAN_NPC_DRAW_ITEM "human_npc_draw_item"
