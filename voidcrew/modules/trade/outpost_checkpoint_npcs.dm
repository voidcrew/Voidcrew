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

/// The checkpoint that leads in from the lift lobby nearest `near` (preferring one not jammed on a refusal): one whose outer door opens onto the outpost, not space. Null if there is none.
/obj/structure/overmap/trader_outpost/proc/lobby_checkpoint(atom/near)
	var/turf/here = get_turf(near)
	var/datum/outpost_checkpoint/best
	var/best_jammed = TRUE
	var/best_distance = INFINITY
	for(var/checkpoint_id in checkpoints)
		var/datum/outpost_checkpoint/post = checkpoints[checkpoint_id]
		if(QDELETED(post) || !post.lobby_turf || !istype(post.lobby_turf.loc, /area/voidcrew/trader_outpost))
			continue
		if(here && ((here in post.chamber_turfs) || here == get_turf(post.inner_door) || here == get_turf(post.outer_door)))
			return post
		var/jammed = post.state == CHECKPOINT_REJECTING && length(post.inspect_chamber()) > 0
		if(jammed && !best_jammed)
			continue
		var/distance = near ? get_dist(near, post.lobby_turf) : 0
		if((!jammed && best_jammed) || distance < best_distance)
			best = post
			best_jammed = jammed
			best_distance = distance
	return best

/// Sends `npc`, just off the lift on the lobby side of `outpost`'s checkpoint, through it first
/proc/ambient_cross_checkpoint_on_arrival(mob/living/carbon/human/npc/ambient_npc/npc, obj/structure/overmap/trader_outpost/outpost)
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
	var/free_pass = post.is_disabled() || post.state == CHECKPOINT_FORCED
	if(here == inner_turf || (here in post.chamber_turfs))
		if(here == inner_turf || (!post.inner_door.density && !post.inner_door.operating))
			go_to(concourse_step(post))
			return AMBIENT_STEP_MOVE
		if((post.is_disabled() || (post.state == CHECKPOINT_IDLE && post.outer_door.density && !post.outer_door.operating)) && !post.inner_door.operating && world.time >= next_ask_at)
			next_ask_at = world.time + OUTPOST_CHECKPOINT_NPC_ASK_GAP
			post.request_cycle(doer)
		return AMBIENT_STEP_CONTINUE
	// Outside: by the outer door until it is open for them, then in
	if(here != outer_turf && get_dist(here, post.lobby_turf) > 1)
		go_to(post.lobby_turf, 1)
		return AMBIENT_STEP_MOVE
	var/outer_open = !post.outer_door.density && !post.outer_door.operating
	if(here == outer_turf || (outer_open && (post.state == CHECKPOINT_IDLE || free_pass)))
		var/turf/entry = chamber_entry(post)
		if(entry)
			go_to(entry)
			return AMBIENT_STEP_MOVE
		return AMBIENT_STEP_CONTINUE
	if(!outer_open && !post.outer_door.operating && (free_pass || (post.state == CHECKPOINT_IDLE && post.inner_door.density && !post.inner_door.operating)) && world.time >= next_ask_at)
		next_ask_at = world.time + OUTPOST_CHECKPOINT_NPC_ASK_GAP
		post.request_outer(doer)
	return AMBIENT_STEP_CONTINUE

/// A free chamber tile to step into, the one nearest the inner door first; null if the chamber is full
/proc/outpost_checkpoint_chamber_entry(datum/outpost_checkpoint/post, mob/living/walker)
	var/turf/inner_turf = get_turf(post.inner_door)
	var/turf/best
	var/best_distance = INFINITY
	for(var/turf/tile as anything in post.chamber_turfs)
		if(tile != walker.loc && tile.is_blocked_turf(exclude_mobs = FALSE, source_atom = walker))
			continue
		var/distance = get_dist(tile, inner_turf)
		if(distance < best_distance)
			best = tile
			best_distance = distance
	return best

/// The free concourse tile just past the inner door (the one straight ahead if it is free)
/proc/outpost_checkpoint_concourse_step(datum/outpost_checkpoint/post, mob/living/walker)
	var/turf/ahead = post.secured_turf
	if(!ahead.is_blocked_turf(exclude_mobs = FALSE, source_atom = walker))
		return ahead
	for(var/turf/beside as anything in RANGE_TURFS(1, ahead))
		if(beside != ahead && post.outpost?.is_secured_turf(beside) && !beside.is_blocked_turf(exclude_mobs = FALSE, source_atom = walker))
			return beside
	return ahead

/datum/ambient_activity/cross_checkpoint/proc/chamber_entry(datum/outpost_checkpoint/post)
	return outpost_checkpoint_chamber_entry(post, doer)

/datum/ambient_activity/cross_checkpoint/proc/concourse_step(datum/outpost_checkpoint/post)
	return outpost_checkpoint_concourse_step(post, doer)

/// They could not get through: back down the lift from the lobby, or gone from inside the chamber
/datum/ambient_activity/cross_checkpoint/proc/give_up(datum/outpost_checkpoint/post)
	// Starting the next activity ends this one, so hold on to them
	var/mob/living/carbon/human/npc/ambient_npc/walker = doer
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

// =========================================================================
// OUTPOST POLICE CHECKPOINT & ELEVATOR SEAMS (declared in police_dispatch.dm)
// =========================================================================

/datum/outpost_police/clear_checkpoint_crossing(mob/living/walker)
	if(!QDELETED(walker))
		REMOVE_TRAIT(walker, TRAIT_CHECKPOINT_CROSSING, "outpost_police_checkpoint")

/**
 * Next turf for `walker` in `POLICE_SECTOR_LOBBY` walking through the lobby checkpoint onto `POLICE_SECTOR_CONCOURSE`
 * (`here` while waiting for the door/scan, null when no checkpoint applies so the caller walks directly).
 */
/datum/outpost_police/checkpoint_step_to_concourse(mob/living/walker)
	if(QDELETED(walker))
		return null
	var/datum/outpost_checkpoint/post = outpost?.lobby_checkpoint(walker)
	if(!post || QDELETED(post.outer_door) || QDELETED(post.inner_door))
		clear_checkpoint_crossing(walker)
		return null
	var/turf/here = get_turf(walker)
	if(!here || outpost.is_secured_turf(here))
		clear_checkpoint_crossing(walker)
		return null
	ADD_TRAIT(walker, TRAIT_CHECKPOINT_CROSSING, "outpost_police_checkpoint")
	var/mob/living/carbon/human/npc/ambient_npc/outpost/police/officer = walker
	var/turf/inner_turf = get_turf(post.inner_door)
	var/turf/outer_turf = get_turf(post.outer_door)
	if(here == inner_turf || (here in post.chamber_turfs))
		if(here == inner_turf || (!post.inner_door.density && !post.inner_door.operating))
			return outpost_checkpoint_concourse_step(post, walker)
		if((post.is_disabled() || post.state == CHECKPOINT_IDLE || (post.state == CHECKPOINT_REJECTING && !length(post.inspect_chamber()))) && !post.outer_door.operating && !post.inner_door.operating && !post.doorway_blocked(post.outer_door))
			if(!istype(officer) || world.time >= officer.dispatch_checkpoint_ask_at)
				if(istype(officer))
					officer.dispatch_checkpoint_ask_at = world.time + OUTPOST_CHECKPOINT_NPC_ASK_GAP
				post.request_cycle(walker)
		return here
	if(here != outer_turf && get_dist(here, post.lobby_turf) > 1)
		return post.lobby_turf
	var/outer_open = !post.outer_door.density && !post.outer_door.operating
	if(here == outer_turf || (outer_open && (post.is_disabled() || post.state == CHECKPOINT_IDLE || post.state == CHECKPOINT_FORCED || (post.state == CHECKPOINT_REJECTING && !length(post.inspect_chamber())))))
		return outpost_checkpoint_chamber_entry(post, walker) || here
	if(!outer_open && !post.outer_door.operating && !post.inner_door.operating && (post.is_disabled() || post.state == CHECKPOINT_FORCED || (post.state == CHECKPOINT_IDLE && post.inner_door.density)))
		if(!istype(officer) || world.time >= officer.dispatch_checkpoint_ask_at)
			if(istype(officer))
				officer.dispatch_checkpoint_ask_at = world.time + OUTPOST_CHECKPOINT_NPC_ASK_GAP
			post.request_outer(walker)
	return get_dist(here, post.lobby_turf) <= 1 ? here : post.lobby_turf

/proc/outpost_police_elevator_panel(obj/structure/overmap/trader_outpost/outpost, sector)
	if(!outpost)
		return null
	if(sector == POLICE_SECTOR_LOBBY)
		return length(outpost.lobby_panels) ? outpost.lobby_panels[1] : null
	var/datum/outpost_berth/berth = sector
	if(istype(berth))
		return berth.panel
	return null

/datum/outpost_police/elevator_busy(sector)
	var/obj/machinery/outpost_elevator/panel = outpost_police_elevator_panel(outpost, sector)
	return !!(panel && !QDELETED(panel) && panel.moving)
