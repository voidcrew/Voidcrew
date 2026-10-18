/**
 * # NPCs at the weapons checkpoint
 *
 * The outpost's people keep to their own side of the checkpoint (outpost_checkpoint.dm): an NPC
 * never works a checkpoint door by walking into it, pathing never plans an NPC's route through a
 * chamber, and an ambient NPC only uses an exit gate when it is leaving for good. Their activity spots
 * already keep off the checkpoint area (ambient_outpost_tile_avoided(), get_loiter_floor()).
 *
 * The one who has to cross is someone stepping off the lift in the lobby while players are about
 * (/datum/ambient_outpost_role/proc/arrive()). They go through like a player: up to the outer door,
 * in when it is open, a wait through the scan, out through the inner door. They ask each door at
 * most once every OUTPOST_CHECKPOINT_NPC_ASK_GAP and never walk into a shut one.
 */

/// The checkpoint that leads in from the lift lobby nearest `near`: one whose outer door opens onto the outpost, not space. Null if there is none.
/obj/structure/overmap/trader_outpost/proc/lobby_checkpoint(atom/near)
	var/datum/outpost_checkpoint/best
	var/best_distance = INFINITY
	for(var/checkpoint_id in checkpoints)
		var/datum/outpost_checkpoint/post = checkpoints[checkpoint_id]
		if(QDELETED(post) || !post.lobby_turf || !istype(post.lobby_turf.loc, /area/voidcrew/trader_outpost))
			continue
		var/distance = near ? get_dist(near, post.lobby_turf) : 0
		if(distance < best_distance)
			best = post
			best_distance = distance
	return best

/// Sends `npc`, just off the lift on the lobby side of `outpost`'s checkpoint, through it first
/proc/ambient_cross_checkpoint_on_arrival(mob/living/basic/ambient_npc/npc, obj/structure/overmap/trader_outpost/outpost)
	if(QDELETED(npc) || !outpost || !length(outpost.checkpoints))
		return
	var/turf/here = get_turf(npc)
	if(!here || !istype(here.loc, /area/voidcrew/trader_outpost/checkpoint))
		return
	npc.start_activity(new /datum/ambient_activity/cross_checkpoint(npc))

/**
 * Going through the checkpoint from the lift lobby. Ends on the concourse. Anyone still outside after
 * OUTPOST_CHECKPOINT_NPC_PATIENCE goes back down the lift (or, stuck in the chamber, slips away).
 */
/datum/ambient_activity/cross_checkpoint
	name = "going through the checkpoint"
	priority = AMBIENT_PRIORITY_REACTION
	/// The checkpoint they are going through
	var/datum/weakref/checkpoint_ref
	/// world.time they give up
	var/give_up_at = 0
	/// world.time they may ask a door again
	var/next_ask_at = 0

/datum/ambient_activity/cross_checkpoint/setup()
	var/datum/ambient_place/outpost/outpost_place = doer.place
	var/obj/structure/overmap/trader_outpost/outpost = istype(outpost_place) ? outpost_place.outpost() : null
	var/datum/outpost_checkpoint/post = outpost?.lobby_checkpoint(doer)
	if(!post)
		return FALSE
	checkpoint_ref = WEAKREF(post)
	give_up_at = world.time + OUTPOST_CHECKPOINT_NPC_PATIENCE
	ADD_TRAIT(doer, TRAIT_CHECKPOINT_CROSSING, REF(src))
	go_to(post.lobby_turf, 1)
	return TRUE

/datum/ambient_activity/cross_checkpoint/Destroy()
	checkpoint_ref = null
	return ..()

/datum/ambient_activity/cross_checkpoint/finish()
	if(!QDELETED(doer))
		REMOVE_TRAIT(doer, TRAIT_CHECKPOINT_CROSSING, REF(src))
	return ..()

/datum/ambient_activity/cross_checkpoint/act(seconds)
	var/datum/outpost_checkpoint/post = checkpoint_ref?.resolve()
	if(QDELETED(post) || QDELETED(post.outer_door) || QDELETED(post.inner_door) || world.time >= give_up_at)
		give_up(post)
		// Their next activity (if any) has replaced this one
		return AMBIENT_STEP_CONTINUE
	var/turf/here = get_turf(doer)
	if(post.outpost?.is_secured_turf(here))
		return AMBIENT_STEP_DONE
	var/turf/inner_turf = get_turf(post.inner_door)
	var/turf/outer_turf = get_turf(post.outer_door)
	// In the chamber: through the inner door once it opens, asking for a scan if nobody has
	if(here == inner_turf || (here in post.chamber_turfs))
		if(here == inner_turf || (!post.inner_door.density && !post.inner_door.operating))
			go_to(concourse_step(post))
			return AMBIENT_STEP_MOVE
		if(post.state == CHECKPOINT_IDLE && post.outer_door.density && !post.outer_door.operating && world.time >= next_ask_at)
			next_ask_at = world.time + OUTPOST_CHECKPOINT_NPC_ASK_GAP
			post.request_cycle(doer)
		return AMBIENT_STEP_CONTINUE
	// Outside: by the outer door until it is open for them, then in
	if(here != outer_turf && get_dist(here, post.lobby_turf) > 1)
		go_to(post.lobby_turf, 1)
		return AMBIENT_STEP_MOVE
	var/outer_open = !post.outer_door.density && !post.outer_door.operating
	if(here == outer_turf || (outer_open && post.state == CHECKPOINT_IDLE))
		var/turf/entry = chamber_entry(post)
		if(entry)
			go_to(entry)
			return AMBIENT_STEP_MOVE
		return AMBIENT_STEP_CONTINUE
	if(post.state == CHECKPOINT_IDLE && !outer_open && post.inner_door.density && !post.outer_door.operating && !post.inner_door.operating && world.time >= next_ask_at)
		next_ask_at = world.time + OUTPOST_CHECKPOINT_NPC_ASK_GAP
		post.request_outer(doer)
	return AMBIENT_STEP_CONTINUE

/// A free chamber tile to step into, the one nearest the inner door first; null if the chamber is full
/datum/ambient_activity/cross_checkpoint/proc/chamber_entry(datum/outpost_checkpoint/post)
	var/turf/inner_turf = get_turf(post.inner_door)
	var/turf/best
	var/best_distance = INFINITY
	for(var/turf/tile as anything in post.chamber_turfs)
		if(tile != doer.loc && tile.is_blocked_turf(exclude_mobs = FALSE, source_atom = doer))
			continue
		var/distance = get_dist(tile, inner_turf)
		if(distance < best_distance)
			best = tile
			best_distance = distance
	return best

/// The free concourse tile just past the inner door (the one straight ahead if it is free)
/datum/ambient_activity/cross_checkpoint/proc/concourse_step(datum/outpost_checkpoint/post)
	var/turf/ahead = post.secured_turf
	if(!ahead.is_blocked_turf(exclude_mobs = FALSE, source_atom = doer))
		return ahead
	for(var/turf/beside as anything in RANGE_TURFS(1, ahead))
		if(beside != ahead && post.outpost?.is_secured_turf(beside) && !beside.is_blocked_turf(exclude_mobs = FALSE, source_atom = doer))
			return beside
	return ahead

/// They could not get through: back down the lift from the lobby, or gone from inside the chamber
/datum/ambient_activity/cross_checkpoint/proc/give_up(datum/outpost_checkpoint/post)
	// Starting the next activity ends this one, so hold on to them
	var/mob/living/basic/ambient_npc/walker = doer
	var/turf/here = get_turf(walker)
	if(!QDELETED(post) && ((here in post.chamber_turfs) || here == get_turf(post.inner_door) || here == get_turf(post.outer_door)))
		walker.fade_out()
		return
	if(!walker.start_activity(new /datum/ambient_activity/leave(walker)) && !QDELETED(walker))
		walker.fade_out()

// A walk that ended stuck (a door shut in their face) is simply tried again from where they stand
/datum/ambient_activity/cross_checkpoint/spot_unreachable()
	spot = null
	arrived = FALSE

/datum/ambient_activity/cross_checkpoint/shift_times(delay)
	. = ..()
	give_up_at = ambient_shifted(give_up_at, delay)
	next_ask_at = ambient_shifted(next_ask_at, delay)
