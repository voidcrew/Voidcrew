/**
 * # Ruin, planet and mission human NPCs (phase C of the human NPC migration)
 *
 * The people found in ruins, on planets and at mission sites: tg's troopers (space pirates, Syndicate
 * operatives, Nanotrasen security, Russian mobsters), the beach and boat pirates, and the wasteland hermits
 * and poacher squads. The faction pirate crews squatting in ruins or named in kill contracts are the same
 * faction pirates that crew NPC ships (/mob/living/carbon/human/npc/faction_pirate,
 * voidcrew/modules/npc_ships/code/faction_pirates/faction_pirate_humans.dm), which do the same things for
 * themselves (planet alliance, spot line, contract cash). They were
 * basic and simple mobs that swapped to a corpse on death; now they are real
 * /mob/living/carbon/human/npc bodies (voidcrew/modules/human_npcs/), so wounds, crit, bleeding,
 * medicine, cuffs and revival work on them as on players. Developer notes: kit vault modules/human_npcs.md.
 *
 * What the families share (this root):
 * - They belong where they spawn. On a planet they join its fauna's alliance (map_footprint.dm), as the
 *   mobs they replace did, so hermits and beach pirates don't fight the local wildlife. Anywhere else they
 *   keep their own factions.
 * - A "spot" line when they pick someone new to fight (RUIN_NPC_BARK_SPOT).
 * - Zone outfit tables (/datum/human_npc_outfit_table/ruin): more armour, better guns and a medipen in
 *   the yellow and red zones, never more health, and outfits of their own on cold sites.
 * - spawn_npc_in_zone_or_queue(): planet, biome and marker spawners queue human types through
 *   spawn_human_npc() instead of building a dozen bodies in one tick.
 * - A kill contract's cash entitlement (npc_payout_mission): a named target pays its cash once per
 *   contract, as the faction pirates did.
 */

/// Bark kind: it picked someone new to fight.
#define RUIN_NPC_BARK_SPOT "spot"

/mob/living/carbon/human/npc/ruin
	npc_target_stat = HUMAN_NPC_FINISHES_DOWNED
	/// Weakref to the /datum/mission whose named target this is; its death cash pays only if that
	/// contract can still claim it (/datum/mission/proc/claim_boss_cash()).
	var/datum/weakref/npc_payout_mission
	/// Weakref to the last mob it called out, so one fight gives one "spot" line
	var/datum/weakref/npc_spotted
	/// The ZONE_* its spawn order dressed it for, or null if it was made without one
	var/npc_dressed_zone

/mob/living/carbon/human/npc/ruin/Initialize(mapload, datum/human_npc_order/order)
	. = ..()
	npc_dressed_zone = order?.resolve_zone()
	// tg's Initialize gave it the planet's alliance before it was dressed; a mapped or ordered faction
	// list has replaced its factions since, so it rejoins here.
	inherit_planetary_faction(src)
	AddElement(/datum/element/human_npc_spot_bark)

/mob/living/carbon/human/npc/ruin/Destroy()
	npc_payout_mission = null
	npc_spotted = null
	return ..()

/**
 * The zone it belongs to, for zone-laddered loot: its spawn context's, which may have resolved after it
 * was made (a ruin loading before its planet registered), else the zone it was dressed for, else where
 * it stands.
 */
/mob/living/carbon/human/npc/ruin/proc/npc_home_zone()
	return npc_spawn_context?.zone_type || npc_dressed_zone || npc_spawn_zone()

// Natives of the planet they spawn on, like the fauna they share it with.
/mob/living/carbon/human/npc/ruin/should_inherit_planetary_faction()
	return TRUE

// A named contract target's cash goes to the contract once (the faction pirates' rule): if the
// contract is gone or has already paid, the body carries none.
/mob/living/carbon/human/npc/ruin/npc_drop_death_loot()
	if(!npc_loot_dropped && npc_death_cash > 0 && npc_payout_mission)
		var/datum/mission/mission = npc_payout_mission.resolve()
		if(!mission?.claim_boss_cash())
			npc_death_cash = 0
	return ..()

/**
 * Says the family's spot line when the NPC picks someone new to fight. An element, so the NPC's own
 * types can listen to the same blackboard signal.
 */
/datum/element/human_npc_spot_bark
	element_flags = ELEMENT_DETACH_ON_HOST_DESTROY

/datum/element/human_npc_spot_bark/Attach(datum/target)
	. = ..()
	if(!istype(target, /mob/living/carbon/human/npc/ruin))
		return ELEMENT_INCOMPATIBLE
	RegisterSignal(target, COMSIG_AI_BLACKBOARD_KEY_SET(BB_BASIC_MOB_CURRENT_TARGET), PROC_REF(on_target_set))

/datum/element/human_npc_spot_bark/Detach(datum/source)
	UnregisterSignal(source, COMSIG_AI_BLACKBOARD_KEY_SET(BB_BASIC_MOB_CURRENT_TARGET))
	return ..()

/datum/element/human_npc_spot_bark/proc/on_target_set(mob/living/carbon/human/npc/ruin/source)
	SIGNAL_HANDLER
	var/mob/living/target = source.ai_controller?.blackboard[BB_BASIC_MOB_CURRENT_TARGET]
	if(!isliving(target) || source.stat != CONSCIOUS)
		return
	if(source.npc_spotted?.resolve() == target)
		return
	source.npc_spotted = WEAKREF(target)
	source.npc_bark(RUIN_NPC_BARK_SPOT)

/**
 * Outfit tables for the ruin families. Green regulars wear what they always did; yellow adds armour; red
 * adds a helmet or better gun and a medipen (used in soft crit, human_npc_soft_crit.dm). Families that
 * are found on cold sites set a cold_layer that swaps their suit for a cold-weather one (the base cold
 * layer only fills empty slots, which leaves an armour vest's wearer to freeze).
 */
/datum/human_npc_outfit_table/ruin

/// Cold-weather wear that also replaces the suit: for outfits whose suit is armour with no warmth in it.
/datum/human_npc_layer/cold/coat
	replace_slots = ITEM_SLOT_FEET | ITEM_SLOT_OCLOTHING

/**
 * spawn_npc_in_zone() for spawners that roll many mobs at once (planet population, biome terrain, zone
 * markers): a human NPC type is queued through spawn_human_npc() with the same context, so it is built
 * over the next ticks instead of now. Returns the mob, or the human NPC order.
 */
/proc/spawn_npc_in_zone_or_queue(spawn_type, atom/location, datum/npc_spawn_context/context)
	if(ispath(spawn_type, /mob/living/carbon/human/npc))
		return spawn_human_npc(spawn_type, location, context = context)
	return spawn_npc_in_zone(spawn_type, location, context)

/// Map spawners for the ruin families (ruin_npc_spawners.dm). Each subtype names the NPC it places;
/// npc_name and npc_faction set one mapped NPC's own name and side.
/obj/effect/spawner/human_npc/ruin
	name = "ruin NPC spawner"
	// The family's own type places nothing (it is never mapped; tests create every type once).
	abstract_spawner_type = /obj/effect/spawner/human_npc/ruin

// ===== Derelict shuttles inside space ruins =====
// The caravan ambush ruin docks four upstream derelict shuttles (code/datums/shuttles/ruin.dm) that
// carried trooper mobs. Following the space ruins' copy-and-redirect scheme (voidcrew/datums/ruins/space.dm),
// voidcrew copies of those maps with human NPC spawners live in _maps/voidcrew/shuttles/, and these
// prefixes point the upstream templates at them. The upstream maps stay as merge reference.
/datum/map_template/shuttle/ruin/caravan_victim
	prefix = "_maps/voidcrew/shuttles/"

/datum/map_template/shuttle/ruin/pirate_cutter
	prefix = "_maps/voidcrew/shuttles/"

/datum/map_template/shuttle/ruin/syndicate_dropship
	prefix = "_maps/voidcrew/shuttles/"

/datum/map_template/shuttle/ruin/syndicate_fighter_shiv
	prefix = "_maps/voidcrew/shuttles/"
