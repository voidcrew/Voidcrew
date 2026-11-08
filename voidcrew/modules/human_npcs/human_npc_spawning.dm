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
 * An NPC whose own system cleans it up sets npc_corpse_lifetime = 0.
 */

/**
 * Queues a human NPC to be built at `where`. Returns the order; qdel() it to cancel.
 *
 * * npc_type - a /mob/living/carbon/human/npc typepath
 * * where - where it appears (its turf is used)
 * * on_spawned - called with the new mob straight after it is built, the same tick
 * * look - overrides the type's npc_look: a /obj/effect/mob_spawn typepath, a /datum/bounty_look or a
 *   /datum/bounty_record
 * * outfit - overrides the type's npc_outfit
 * * name - overrides the type's npc_name
 * * faction - overrides the type's faction list
 * * context - a /datum/npc_spawn_context (voidcrew/modules/npc_scaling/); the body is built through
 *   spawn_npc_in_zone() and the context finalised after on_spawned
 * * immediate - build it now instead of queueing it (admin tools, tests)
 */
/proc/spawn_human_npc(npc_type, atom/where, datum/callback/on_spawned, look, outfit, name, list/faction, datum/npc_spawn_context/context, immediate = FALSE)
	var/datum/human_npc_order/order = new(npc_type, where, on_spawned, look, outfit, name, faction, context)
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
	/// Weakref to the mob once it is built
	var/datum/weakref/spawned_ref
	/// Set once fulfil() has run, whether or not it made a mob
	var/done = FALSE

/datum/human_npc_order/New(npc_type, atom/where, datum/callback/on_spawned, look, outfit, name, list/faction, datum/npc_spawn_context/context)
	if(!ispath(npc_type, /mob/living/carbon/human/npc))
		CRASH("spawn_human_npc() was given [npc_type], which is not a human NPC type")
	src.npc_type = npc_type
	src.where = get_turf(where)
	src.on_spawned = on_spawned
	src.look = look
	src.outfit = outfit
	src.name = name
	src.faction = faction?.Copy()
	src.context = context

/datum/human_npc_order/Destroy(force)
	SShuman_npcs.queue -= src
	release()
	return ..()

/// Drops what the order held, so a fulfilled order keeps nothing alive.
/datum/human_npc_order/proc/release()
	where = null
	on_spawned = null
	look = null
	outfit = null
	faction = null
	context = null

/// Builds the NPC now. Returns it, or null if it couldn't be built.
/datum/human_npc_order/proc/fulfil()
	if(done)
		return spawned_ref?.resolve()
	done = TRUE
	SShuman_npcs.queue -= src
	var/mob/living/carbon/human/npc/npc
	if(!isnull(where))
		if(context)
			npc = spawn_npc_in_zone(npc_type, where, context, finalize = FALSE, constructor_args = list(src))
		else
			npc = new npc_type(where, src)
	if(QDELETED(npc))
		release()
		return null
	spawned_ref = WEAKREF(npc)
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

/datum/controller/subsystem/human_npcs/stat_entry(msg)
	msg = "Q:[length(queue)]|Made:[spawned_total]|Bodies:[length(corpses)]|Faded:[faded_total]"
	return ..()

/datum/controller/subsystem/human_npcs/fire(resumed = FALSE)
	if(length(queue))
		process_spawns(HUMAN_NPC_SPAWNS_PER_FIRE)
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

/// Builds up to `budget` queued NPCs. Returns how many it built.
/datum/controller/subsystem/human_npcs/proc/process_spawns(budget = HUMAN_NPC_SPAWNS_PER_FIRE)
	. = 0
	while(length(queue) && . < budget)
		var/datum/human_npc_order/order = queue[1]
		queue.Cut(1, 2)
		if(QDELETED(order) || order.done)
			continue
		if(order.fulfil())
			.++

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

/obj/effect/spawner/human_npc/Initialize(mapload)
	. = ..()
	if(!ispath(npc_type, /mob/living/carbon/human/npc))
		stack_trace("[type] at [AREACOORD(src)] has no human NPC type to spawn")
		return
	spawn_human_npc(npc_type, get_turf(src), context = get_npc_spawn_context())
