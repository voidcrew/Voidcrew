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

// ===== Phase A2: shared pieces for pirates, ruin NPCs, hermits and criminals =====

// npc_target_stat: the worst state a target can be in and still get attacked (BB_TARGET_MINIMUM_STAT).
/// Pirates, troopers, hermits, raiders, NT customs: keep shooting someone in crit, as tg troopers do.
#define HUMAN_NPC_FINISHES_DOWNED HARD_CRIT
/// Criminals, companions, bosses, prisoners, guards: stop once a target is in crit.
#define HUMAN_NPC_SPARES_DOWNED CONSCIOUS

// Bark kinds (human_npc_barks.dm). Families supply the lines through a /datum/human_npc_voice.
/// Entered crit. Whispered in soft crit; hard crit gets the emote only.
#define HUMAN_NPC_BARK_DOWNED "downed"
/// Left crit, or got up from stamcrit.
#define HUMAN_NPC_BARK_RECOVER "recover"
/// Now and then while it crawls in soft crit. Falls back to the downed lines.
#define HUMAN_NPC_BARK_PLEAD "plead"
/// Handcuffs went on.
#define HUMAN_NPC_BARK_CUFFED "cuffed"
/// Started working at its cuffs (tg's cuff_resist).
#define HUMAN_NPC_BARK_SLIPPING "slipping_cuffs"
/// Its cuffs came off, by its own work or someone else's.
#define HUMAN_NPC_BARK_UNCUFFED "uncuffed"
/// Broke out of a grab or off someone's shoulders by resisting.
#define HUMAN_NPC_BARK_PULLED_FREE "pulled_free"
/// Gave up (human_npc_surrender.dm). Always said.
#define HUMAN_NPC_BARK_SURRENDER "surrender"
/// Died. Emote only: the dead don't talk.
#define HUMAN_NPC_BARK_DEATH "death"
/// Default seconds between two barks from one NPC.
#define HUMAN_NPC_BARK_COOLDOWN (4 SECONDS)
/// How often an NPC crawling in soft crit pleads, at most.
#define HUMAN_NPC_PLEAD_INTERVAL (12 SECONDS)

// Sites (human_npc_outfits.dm): what the air where an NPC is dressed asks of its kit.
/// Too little pressure to live in: a sealed suit and helmet and its own air.
#define HUMAN_NPC_SITE_VACUUM (1<<0)
/// Pressure is fine but the air isn't: a mask and a tank.
#define HUMAN_NPC_SITE_BAD_AIR (1<<1)
/// Cold enough to freeze an unprotected person: cold-weather wear.
#define HUMAN_NPC_SITE_COLD (1<<2)
/// Air colder than this, in kelvin, is a cold site.
#define HUMAN_NPC_SITE_COLD_TEMP (T0C - 10)
/// Oxygen partial pressure below this, in kPa, is not breathable (tg's safe minimum).
#define HUMAN_NPC_SITE_MIN_OXYGEN 16
/// How much better than its lungs' limits (kPa) the air must be before an NPC on internals closes its valve.
#define HUMAN_NPC_AIR_MARGIN 2
/// A queued NPC dressed by an outfit table waits this long for its spawn zone to resolve, then takes green.
#define HUMAN_NPC_ZONE_WAIT (60 SECONDS)

// Leaving (human_npc_states.dm).
/// How often SShuman_npcs checks whether an NPC walking out may be deleted.
#define HUMAN_NPC_LEAVER_SWEEP_INTERVAL (1 SECONDS)

// Signals sent on a human NPC.
/// It gave up: tg's *surrender is running. ()
#define COMSIG_HUMAN_NPC_SURRENDERED "human_npc_surrendered"
/// Its surrender's paralysis ended and nobody had cuffed it. ()
#define COMSIG_HUMAN_NPC_SURRENDER_ENDED "human_npc_surrender_ended"
/// It entered crit. ()
#define COMSIG_HUMAN_NPC_DOWNED "human_npc_downed"
/// It left crit, or got up from stamcrit. ()
#define COMSIG_HUMAN_NPC_RECOVERED "human_npc_recovered"
/// It walked out and is about to be deleted (human_npc_states.dm). ()
#define COMSIG_HUMAN_NPC_LEFT "human_npc_left"

// More blackboard keys.
/// A mob it is running from (surrender flight, soft-crit crawl).
#define BB_HUMAN_NPC_FLEE_FROM "human_npc_flee_from"
/// world.time it stops fleeing after deciding not to give up again.
#define BB_HUMAN_NPC_FLEE_UNTIL "human_npc_flee_until"
/// The item it is using on itself (human_npc_treat_self).
#define BB_HUMAN_NPC_TREAT_ITEM "human_npc_treat_item"
/// world.time it may next treat itself.
#define BB_HUMAN_NPC_NEXT_TREAT "human_npc_next_treat"
/// The turf it is walking out to (npc_walk_out()).
#define BB_HUMAN_NPC_EXIT "human_npc_exit"
