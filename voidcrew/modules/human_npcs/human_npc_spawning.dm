/**
 * # Making human NPCs, and clearing their bodies away
 *
 * A human costs about 11 ms to build (spike measurement), so a boarding wave of eight built in one
 * tick stalls the server for two. Every human NPC goes through spawn_human_npc(), which queues an
 * order; SShuman_npcs builds HUMAN_NPC_SPAWNS_PER_FIRE of them per fire.
 *
 * The same subsystem cleans up corpses so they don't pile up over a 6 hour round: a body dead for
 * its npc_corpse_lifetime is deleted the first time a sweep finds no player near it, with the limbs
 * and organs it lost that lie unwatched on the floor. Bodies being dragged, carried or watched stay.
 * An NPC whose own system cleans it up sets npc_corpse_lifetime = 0. It also deletes living NPCs that
 * are walking out (npc_walk_out(), human_npc_states.dm) once they may go.
 *
 * An order dressed by an outfit table (human_npc_outfits.dm) needs its zone. While its spawn context
 * is still resolving the zone (a planet level registering late), the order waits in the queue, up to
 * HUMAN_NPC_ZONE_WAIT, and is then dressed for green.
 */

/**
 * Queues a human NPC to be built at `where`. Returns the order; qdel() it to cancel.
 *
 * * npc_type - a /mob/living/carbon/human/npc typepath
 * * where - where it appears (its turf is used)
 * * on_spawned - called with the new mob straight after it is built, the same tick
 * * look - overrides the type's npc_look: a /obj/effect/mob_spawn typepath, a /datum/bounty_look or a
 *   /datum/bounty_record
 * * outfit - overrides the type's npc_outfit: an outfit typepath, or a /datum/human_npc_outfit_table
 *   typepath to pick one by zone and rank
 * * name - overrides the type's npc_name
 * * faction - overrides the type's faction list
 * * context - a /datum/npc_spawn_context (voidcrew/modules/npc_scaling/); the body is built through
 *   spawn_npc_in_zone() and the context finalised after on_spawned
 * * immediate - build it now instead of queueing it (admin tools, tests)
 * * dir - the way it faces when it appears (a mapped spawner's dir), or NONE for its own
 */
/proc/spawn_human_npc(npc_type, atom/where, datum/callback/on_spawned, look, outfit, name, list/faction, datum/npc_spawn_context/context, immediate = FALSE, dir = NONE)
	var/datum/human_npc_order/order = new(npc_type, where, on_spawned, look, outfit, name, faction, context)
	order.dir = dir
	if(immediate)
		order.fulfil()
	else
		SShuman_npcs.queue += order
	return order

/// One queued human NPC. Holds what spawn_human_npc() was given until the body is built.
/datum/human_npc_order
	var/npc_type
	var/turf/where
	var/datum/callback/on_spawned
	var/look
	var/datum/outfit/outfit
	var/name
	var/list/faction
	var/datum/npc_spawn_context/context
	/// The way it faces when built, or NONE
	var/dir = NONE
	/// The area its spot was in when queued: the order is dropped if the spot has been reused since
	var/area/where_area
	/// Weakref to the map region its spot was in when queued (a packed encounter's footprint or a
	/// reservation), for the same check; null on a level that isn't packed
	var/datum/weakref/where_region
	/// The ZONE_* it is dressed for, once known (resolve_zone())
	var/zone
	/// world.time it was queued
	var/queued_at = 0
	/// world.time it may next look up a zone it is waiting for
	var/next_zone_check = 0
	/// Weakref to the mob once it is built
	var/datum/weakref/spawned_ref
	/// Set once fulfil() has run, whether or not it made a mob
	var/done = FALSE

/datum/human_npc_order/New(npc_type, atom/where, datum/callback/on_spawned, look, outfit, name, list/faction, datum/npc_spawn_context/context)
	if(!ispath(npc_type, /mob/living/carbon/human/npc))
		CRASH("spawn_human_npc() was given [npc_type], which is not a human NPC type")
	src.npc_type = npc_type
	src.where = get_turf(where)
	src.where_area = src.where?.loc
	var/datum/region = map_region_for_turf(src.where)
	src.where_region = region ? WEAKREF(region) : null
	src.on_spawned = on_spawned
	src.look = look
	src.outfit = outfit
	src.name = name
	src.faction = faction?.Copy()
	src.context = context
	queued_at = world.time

/datum/human_npc_order/Destroy(force)
	SShuman_npcs.queue -= src
	release()
	return ..()

/// Drops what the order held, so a fulfilled order keeps nothing alive.
/datum/human_npc_order/proc/release()
	where = null
	where_area = null
	where_region = null
	on_spawned = null
	look = null
	outfit = null
	faction = null
	context = null

/// Whether its body is dressed from an outfit table, and so needs to know its zone first.
/datum/human_npc_order/proc/needs_zone()
	if(ispath(outfit, /datum/human_npc_outfit_table))
		return TRUE
	if(outfit)
		return FALSE
	var/mob/living/carbon/human/npc/npc_path = npc_type
	return !initial(npc_path.npc_outfit) && ispath(initial(npc_path.npc_outfit_table), /datum/human_npc_outfit_table)

/**
 * The zone to dress it for, or null while it is still unknown and worth waiting for: its context's
 * zone, else the zone of its spawn turf (a ship's overmap tile when aboard one). `now` settles for
 * green instead of waiting, as does an order that has waited HUMAN_NPC_ZONE_WAIT.
 */
/datum/human_npc_order/proc/resolve_zone(now = TRUE)
	if(!isnull(zone))
		return zone
	zone = context?.zone_type || get_zone_type_for_player_turf(where)
	if(isnull(zone) && (now || isnull(context) || world.time >= queued_at + HUMAN_NPC_ZONE_WAIT))
		zone = ZONE_GREEN
	return zone

/// Whether it can be built now: it doesn't need a zone, or its zone is known. A waiting order looks
/// its zone up at most once a second.
/datum/human_npc_order/proc/ready()
	if(!isnull(zone) || !needs_zone())
		return TRUE
	if(world.time < next_zone_check)
		return FALSE
	next_zone_check = world.time + 1 SECONDS
	return !isnull(resolve_zone(now = FALSE))

/**
 * Whether the spot it was queued for is still the same place. An order can wait in the queue (up to
 * HUMAN_NPC_ZONE_WAIT for its zone); by then the ruin or planet it was for may have unloaded and its
 * turfs been reused by something else. The spot must still exist, be in the same area and the same
 * packed map region, and not have become a wall.
 */
/datum/human_npc_order/proc/spot_still_valid()
	if(isnull(where) || QDELETED(where))
		return FALSE
	if(where.loc != where_area)
		return FALSE
	// A region that registers after the spot was queued (a planet level coming up late) is fine; one
	// that has gone, or been replaced by another, means the ground was recycled.
	if(where_region && map_region_for_turf(where) != where_region.resolve())
		return FALSE
	return !isclosedturf(where)

/// Builds the NPC now. Returns it, or null if it couldn't be built.
/datum/human_npc_order/proc/fulfil()
	if(done)
		return spawned_ref?.resolve()
	done = TRUE
	SShuman_npcs.queue -= src
	var/mob/living/carbon/human/npc/npc
	if(spot_still_valid())
		if(context)
			npc = spawn_npc_in_zone(npc_type, where, context, finalize = FALSE, constructor_args = list(src))
		else
			npc = new npc_type(where, src)
	if(QDELETED(npc))
		release()
		return null
	spawned_ref = WEAKREF(npc)
	if(dir)
		npc.setDir(dir)
	SShuman_npcs.spawned_total++
	on_spawned?.Invoke(npc)
	context?.finalize()
	release()
	return npc

/// Marks a human NPC as admin-spawned (spawn_human_npcs verb).
/proc/human_npc_mark_admin_spawned(mob/living/carbon/human/npc/npc)
	npc.flags_1 |= ADMIN_SPAWNED_1

SUBSYSTEM_DEF(human_npcs)
	name = "Human NPCs"
	flags = SS_NO_INIT
	wait = 1
	runlevels = RUNLEVEL_LOBBY | RUNLEVELS_DEFAULT
	/// Orders waiting to be built, oldest first
	var/list/datum/human_npc_order/queue = list()
	/// Dead human NPCs whose corpses may be cleaned up
	var/list/mob/living/carbon/human/npc/corpses = list()
	/// The corpses this sweep still has to look at
	var/list/mob/living/carbon/human/npc/corpse_run = list()
	/// world.time of the next corpse sweep
	var/next_sweep = 0
	/// Human NPCs built this round
	var/spawned_total = 0
	/// Corpses cleaned up this round
	var/faded_total = 0
	/// Living NPCs walking out (npc_walk_out())
	var/list/mob/living/carbon/human/npc/leavers = list()
	/// world.time of the next check of the leavers
	var/next_leaver_sweep = 0
	/// NPCs that walked out this round
	var/left_total = 0

/datum/controller/subsystem/human_npcs/stat_entry(msg)
	msg = "Q:[length(queue)]|Made:[spawned_total]|Bodies:[length(corpses)]|Faded:[faded_total]|Leaving:[length(leavers)]|Left:[left_total]"
	return ..()

/datum/controller/subsystem/human_npcs/fire(resumed = FALSE)
	if(length(queue))
		process_spawns(HUMAN_NPC_SPAWNS_PER_FIRE)
		if(MC_TICK_CHECK)
			return
	if(length(leavers) && world.time >= next_leaver_sweep)
		next_leaver_sweep = world.time + HUMAN_NPC_LEAVER_SWEEP_INTERVAL
		sweep_leavers()
		if(MC_TICK_CHECK)
			return
	if(!length(corpse_run))
		if(world.time < next_sweep || !length(corpses))
			return
		next_sweep = world.time + HUMAN_NPC_CORPSE_SWEEP_INTERVAL
		corpse_run = corpses.Copy()
	var/deleted = 0
	while(length(corpse_run))
		var/mob/living/carbon/human/npc/body = corpse_run[length(corpse_run)]
		corpse_run.len--
		if(QDELETED(body))
			corpses -= body
			continue
		if(body.npc_corpse_expired())
			body.npc_fade()
			faded_total++
			deleted++
		if(deleted >= HUMAN_NPC_CORPSE_DELETES_PER_FIRE || MC_TICK_CHECK)
			return

/// Builds up to `budget` queued NPCs, oldest first, passing over orders still waiting for their zone.
/// Returns how many it built.
/datum/controller/subsystem/human_npcs/proc/process_spawns(budget = HUMAN_NPC_SPAWNS_PER_FIRE)
	. = 0
	var/index = 1
	while(index <= length(queue) && . < budget)
		var/datum/human_npc_order/order = queue[index]
		if(QDELETED(order) || order.done)
			queue.Cut(index, index + 1)
			continue
		if(!order.ready())
			index++
			continue
		queue.Cut(index, index + 1)
		if(order.fulfil())
			.++

/// Deletes the NPCs walking out that may go now (npc_may_vanish()).
/datum/controller/subsystem/human_npcs/proc/sweep_leavers()
	for(var/mob/living/carbon/human/npc/leaver as anything in leavers.Copy())
		if(QDELETED(leaver) || leaver.stat == DEAD)
			leavers -= leaver
			continue
		if(leaver.npc_may_vanish())
			leaver.npc_vanish()
			left_total++

/datum/controller/subsystem/human_npcs/proc/track_corpse(mob/living/carbon/human/npc/body)
	corpses |= body

/datum/controller/subsystem/human_npcs/proc/forget_corpse(mob/living/carbon/human/npc/body)
	corpses -= body
	corpse_run -= body

/**
 * Map placement for a human NPC: queues `npc_type` here when the map loads, so a ruin full of them
 * builds over several ticks.
 */
/obj/effect/spawner/human_npc
	name = "human NPC spawner"
	icon = 'icons/effects/mapping_helpers.dmi'
	icon_state = "mobspawner"
	/// The /mob/living/carbon/human/npc typepath to spawn
	var/npc_type
	/// A name for this one NPC (a mapped character), or null for its type's
	var/npc_name
	/// Factions for this one NPC (a mapped camp's own side), or null for its type's
	var/list/npc_faction
	/// The family root this type is: never mapped and places nothing, so it may have no npc_type. A
	/// family's own root subtype sets this to itself (tests make one of every type).
	var/abstract_spawner_type = /obj/effect/spawner/human_npc

/obj/effect/spawner/human_npc/Initialize(mapload)
	. = ..()
	if(!ispath(npc_type, /mob/living/carbon/human/npc))
		if(type != abstract_spawner_type)
			stack_trace("[type] at [AREACOORD(src)] has no human NPC type to spawn")
		return
#ifdef UNIT_TESTS
	// The create-and-destroy test makes one of every type on one tile; it isn't a map, so place nothing.
	if(GLOB.running_create_and_destroy)
		return
#endif
	// The mapped spawner's dir is the way the NPC faces.
	spawn_human_npc(npc_type, get_turf(src), name = npc_name, faction = npc_faction, context = get_npc_spawn_context(), dir = dir)
