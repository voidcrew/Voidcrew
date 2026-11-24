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
 * most once every OUTPOST_CHECKPOINT_NPC_ASK_GAP and never walk into a shut one. Through, they walk on a
 * few tiles before their visit starts: the one tile in front of the inner door is the only way out of it,
 * and the gate stays open, and shut to the queue, while anyone stands in its doorway.
 *
 * Nobody waits in a doorway. A place in the chamber is kept for each of them before they set off for it
 * (chamber_place_for()): the tile furthest in first, so the one inside the outer door fills last and never shuts
 * the rest of the chamber off. With no place to be had they wait in the lobby in front of the outer door; one
 * caught in the doorway (the place they were walking to was taken) steps back out to the lobby.
 *
 * "By the outer door" is a tile they can step to the door's front tile from (outpost_checkpoint_by_outer_door()).
 * Quartermain's and the Undertow's lobbies lead up to the door between queue rails: a tile across a rail from the
 * door's front is one tile away and nowhere near it.
 *
 * The outpost's officers are the exception to "no NPC walks into a chamber": see "the police's key" at the end.
 */

/// How long a place in the chamber is kept for someone who has stopped asking for it
#define OUTPOST_CHECKPOINT_NPC_PLACE_TIME (4 SECONDS)

/datum/outpost_checkpoint
	/// Chamber tile -> weakref of the NPC on their way to stand on it, so no two head for one tile (chamber_place_for())
	var/list/chamber_places
	/// Chamber tile -> world.time its place was last asked for
	var/list/chamber_places_at

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
		var/distance = !here ? 0 : (here.z == post.lobby_turf.z ? get_dist(here, post.lobby_turf) : 10000)
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
	/// Where they are walking on to, clear of the inner door
	var/turf/onward
	/// How many such spots they have tried
	var/onward_tries = 0

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
	onward = null
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
	var/turf/inner_turf = get_turf(post.inner_door)
	if(post.outpost?.is_secured_turf(here))
		// Through, but not done on the doorstep: whoever stood there (their routine starts with a stand as often as
		// not) held everyone behind them in the gate
		if(get_dist(here, inner_turf) >= OUTPOST_CHECKPOINT_NPC_CLEAR || onward_tries > OUTPOST_CHECKPOINT_NPC_CLEAR_TRIES)
			return AMBIENT_STEP_DONE
		if(!onward || onward == here || onward.is_blocked_turf(exclude_mobs = FALSE, source_atom = doer))
			onward_tries++
			onward = onward_tries > OUTPOST_CHECKPOINT_NPC_CLEAR_TRIES ? null : outpost_checkpoint_clear_spot(post, doer)
		if(!onward)
			return AMBIENT_STEP_DONE
		go_to(onward)
		return AMBIENT_STEP_MOVE
	var/turf/outer_turf = get_turf(post.outer_door)
	// In the chamber: through the inner door once it opens, asking for a scan if nobody has
	var/free_pass = post.is_disabled() || post.state == CHECKPOINT_FORCED
	if(here == inner_turf || (here in post.chamber_turfs))
		if(here == inner_turf || (!post.inner_door.density && !post.inner_door.operating))
			go_to(concourse_step(post))
			return AMBIENT_STEP_MOVE
		// Further in while they wait, so the tile inside the outer door is free for the next one
		var/turf/place = chamber_entry(post)
		if(place && place != here)
			go_to(place)
			return AMBIENT_STEP_MOVE
		if((post.is_disabled() || (post.state == CHECKPOINT_IDLE && post.outer_door.density && !post.outer_door.operating)) && !post.inner_door.operating && world.time >= next_ask_at)
			next_ask_at = world.time + OUTPOST_CHECKPOINT_NPC_ASK_GAP
			post.request_cycle(doer)
		return AMBIENT_STEP_CONTINUE
	// In the outer doorway: on in if there is a place for them, else back out. Nobody waits in a doorway.
	if(here == outer_turf)
		go_to(chamber_entry(post) || outpost_checkpoint_lobby_spot(post, doer))
		return AMBIENT_STEP_MOVE
	// Outside: by the outer door until it is open for them and there is room inside, then in. One tile from its
	// front tile across a queue rail is not by it: round into the lane
	if(!outpost_checkpoint_by_outer_door(post, here))
		go_to(post.lobby_turf, get_dist(here, post.lobby_turf) > 1 ? 1 : 0)
		return AMBIENT_STEP_MOVE
	var/outer_open = !post.outer_door.density && !post.outer_door.operating
	if(outer_open && (post.state == CHECKPOINT_IDLE || free_pass))
		var/turf/entry = chamber_entry(post)
		if(entry)
			go_to(entry)
			return AMBIENT_STEP_MOVE
		return AMBIENT_STEP_CONTINUE
	if(!outer_open && !post.outer_door.operating && (free_pass || (post.state == CHECKPOINT_IDLE && post.inner_door.density && !post.inner_door.operating)) && world.time >= next_ask_at)
		next_ask_at = world.time + OUTPOST_CHECKPOINT_NPC_ASK_GAP
		post.request_outer(doer)
	return AMBIENT_STEP_CONTINUE

/// The chamber tile kept for `walker` to walk in to (chamber_place_for()); null while there is no room for them
/proc/outpost_checkpoint_chamber_entry(datum/outpost_checkpoint/post, mob/living/walker)
	return post.chamber_place_for(walker)

/// Whether `walker` could stand on chamber tile `tile` now: nobody and nothing in the way on it
/datum/outpost_checkpoint/proc/chamber_tile_free(turf/tile, mob/living/walker)
	return tile == walker.loc || !tile.is_blocked_turf(exclude_mobs = FALSE, source_atom = walker)

/**
 * The chamber tiles `walker` could walk to now from the outer door, each with how many steps in it is (the tile
 * inside the door is 0). A tile someone or something stands on is no way through: with the tile inside the door
 * taken, nothing is.
 */
/datum/outpost_checkpoint/proc/chamber_depths(mob/living/walker)
	. = list()
	var/turf/door_turf = get_turf(outer_door)
	if(!door_turf)
		return
	var/list/turf/frontier = list()
	for(var/direction in GLOB.cardinals)
		var/turf/tile = get_step(door_turf, direction)
		if((tile in chamber_turfs) && chamber_tile_free(tile, walker))
			.[tile] = 0
			frontier += tile
	while(length(frontier))
		var/turf/from = frontier[1]
		frontier.Cut(1, 2)
		for(var/direction in GLOB.cardinals)
			var/turf/tile = get_step(from, direction)
			if(!(tile in chamber_turfs) || !isnull(.[tile]) || !chamber_tile_free(tile, walker))
				continue
			.[tile] = .[from] + 1
			frontier += tile

/// Gives up places whose NPC is gone, down, or has not asked for theirs in OUTPOST_CHECKPOINT_NPC_PLACE_TIME
/datum/outpost_checkpoint/proc/prune_chamber_places()
	for(var/turf/tile as anything in chamber_places)
		var/datum/weakref/holder_ref = chamber_places[tile]
		var/mob/living/holder = holder_ref?.resolve()
		if(QDELETED(holder) || holder.stat != CONSCIOUS || world.time - chamber_places_at[tile] > OUTPOST_CHECKPOINT_NPC_PLACE_TIME)
			chamber_places -= tile
			chamber_places_at -= tile

/**
 * The chamber tile `walker` is to walk in to, kept for them from now until they stop asking: the free tile furthest
 * in from the outer door that nobody else is on their way to (nearest the inner door among equals), which is the one
 * they already have unless a better one has opened up. Null when there is none they can walk to: the chamber is
 * full, or someone stands in the way just inside the door.
 */
/datum/outpost_checkpoint/proc/chamber_place_for(mob/living/walker)
	if(QDELETED(walker))
		return null
	// The police are at work in there: nobody walks in on an arrest, and whoever is inside already stays where they are
	if(police_at_work())
		return null
	LAZYINITLIST(chamber_places)
	LAZYINITLIST(chamber_places_at)
	prune_chamber_places()
	var/list/depths = chamber_depths(walker)
	var/datum/weakref/walker_ref = WEAKREF(walker)
	var/turf/best
	var/best_depth = -1
	var/best_distance = INFINITY
	var/turf/inner_turf = get_turf(inner_door)
	for(var/turf/tile as anything in depths)
		var/datum/weakref/holder_ref = chamber_places[tile]
		if(holder_ref && holder_ref != walker_ref)
			continue
		var/depth = depths[tile]
		var/distance = get_dist(tile, inner_turf)
		if(depth > best_depth || (depth == best_depth && distance < best_distance))
			best = tile
			best_depth = depth
			best_distance = distance
	// One place each: the one they had goes when a better one opens up, or when theirs was taken
	for(var/turf/tile as anything in chamber_places)
		if(chamber_places[tile] == walker_ref && tile != best)
			chamber_places -= tile
			chamber_places_at -= tile
	if(best)
		chamber_places[best] = walker_ref
		chamber_places_at[best] = world.time
	return best

/**
 * Where `walker` steps back to out of the outer doorway: the tile in front of the door, the only way out of it.
 * Whoever of the outpost's people stands there makes room for the one coming back out.
 */
/proc/outpost_checkpoint_lobby_spot(datum/outpost_checkpoint/post, mob/living/walker)
	var/turf/front = post.lobby_turf
	if(!front)
		return null
	for(var/mob/living/waiting in front)
		if(waiting != walker && waiting.density)
			outpost_npc_step_aside(waiting, walker, list())
	return front

/// Whether `here` is by `post`'s outer door: its front tile, or a tile beside that with a clear step onto it (no queue rail, wall or counter between)
/proc/outpost_checkpoint_by_outer_door(datum/outpost_checkpoint/post, turf/here)
	var/turf/front = post.lobby_turf
	if(!here || !front || here.z != front.z)
		return FALSE
	return here == front || (get_dist(here, front) <= 1 && outpost_police_way_step_ok(here, front))

/// The free concourse tile just past the inner door (the one straight ahead if it is free)
/proc/outpost_checkpoint_concourse_step(datum/outpost_checkpoint/post, mob/living/walker)
	var/turf/ahead = post.secured_turf
	if(!ahead.is_blocked_turf(exclude_mobs = FALSE, source_atom = walker))
		return ahead
	for(var/turf/beside as anything in RANGE_TURFS(1, ahead))
		if(beside != ahead && post.outpost?.is_secured_turf(beside) && !beside.is_blocked_turf(exclude_mobs = FALSE, source_atom = walker))
			return beside
	return ahead

/**
 * A free concourse tile a few steps in from the inner door, in a clear line from the tile in front of it, the
 * nearest to `walker` first: where someone who came through gets out of the way. Null if there is none.
 */
/proc/outpost_checkpoint_clear_spot(datum/outpost_checkpoint/post, mob/living/walker)
	var/turf/door_turf = get_turf(post.inner_door)
	var/turf/ahead = post.secured_turf
	var/turf/here = get_turf(walker)
	if(!door_turf || !ahead || !here)
		return null
	var/turf/best
	var/best_distance = INFINITY
	for(var/turf/open/tile in RANGE_TURFS(OUTPOST_CHECKPOINT_NPC_CLEAR + 2, door_turf))
		if(get_dist(tile, door_turf) < OUTPOST_CHECKPOINT_NPC_CLEAR || !post.outpost?.is_secured_turf(tile))
			continue
		if(!ambient_ground_ok(tile) || ambient_by_a_door(tile) || tile.is_blocked_turf(exclude_mobs = FALSE, source_atom = walker))
			continue
		var/distance = get_dist(tile, here)
		if(distance >= best_distance)
			continue
		// Somewhere they can walk straight to from the door, not a shop's back room through a wall
		var/blocked = FALSE
		for(var/turf/between as anything in get_line(ahead, tile))
			if(between != tile && (isclosedturf(between) || between.is_blocked_turf(exclude_mobs = TRUE)))
				blocked = TRUE
				break
		if(blocked)
			continue
		best = tile
		best_distance = distance
	return best

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

/**
 * On their way in to the chamber they keep asking for their place, so it stays theirs. If it is gone (someone stepped
 * onto it, or into the way just inside the door) they take another, or with none to be had stop where they are in the
 * lobby, or step back out of the doorway.
 */
/datum/ambient_activity/cross_checkpoint/at_spot()
	var/datum/outpost_checkpoint/post = checkpoint_ref?.resolve()
	var/turf/here = get_turf(doer)
	if(!QDELETED(post) && isturf(spot) && here != spot && (spot in post.chamber_turfs) && !(here in post.chamber_turfs))
		var/turf/place = chamber_entry(post)
		if(place != spot)
			if(place)
				go_to(place)
			else if(here == get_turf(post.outer_door))
				go_to(outpost_checkpoint_lobby_spot(post, doer))
			else
				go_to(null)
	return ..()

// A walk that ended stuck (a door shut in their face) is simply tried again from where they stand
/datum/ambient_activity/cross_checkpoint/spot_unreachable()
	spot = null
	arrived = FALSE
	onward = null

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
		// Further in while they wait, so the tile inside the outer door is free for the next one
		var/turf/place = outpost_checkpoint_chamber_entry(post, walker)
		if(place && place != here)
			return place
		if((post.is_disabled() || post.state == CHECKPOINT_IDLE || (post.state == CHECKPOINT_REJECTING && !length(post.inspect_chamber()))) && !post.outer_door.operating && !post.inner_door.operating && !post.doorway_blocked(post.outer_door))
			if(!istype(officer) || world.time >= officer.dispatch_checkpoint_ask_at)
				if(istype(officer))
					officer.dispatch_checkpoint_ask_at = world.time + OUTPOST_CHECKPOINT_NPC_ASK_GAP
				post.request_cycle(walker)
		return here
	// In the outer doorway: on in if there is a place for them, else back out. Nobody waits in a doorway.
	if(here == outer_turf)
		return outpost_checkpoint_chamber_entry(post, walker) || outpost_checkpoint_lobby_spot(post, walker) || here
	// One tile from the door's front tile across a queue rail is not by the door: round into the lane first
	var/by_door = outpost_checkpoint_by_outer_door(post, here)
	if(!by_door)
		return post.lobby_turf
	var/outer_open = !post.outer_door.density && !post.outer_door.operating
	if(outer_open && (post.is_disabled() || post.state == CHECKPOINT_IDLE || post.state == CHECKPOINT_FORCED || (post.state == CHECKPOINT_REJECTING && !length(post.inspect_chamber()))))
		return outpost_checkpoint_chamber_entry(post, walker) || here
	if(!outer_open && !post.outer_door.operating && !post.inner_door.operating && (post.is_disabled() || post.state == CHECKPOINT_FORCED || (post.state == CHECKPOINT_IDLE && post.inner_door.density)))
		if(!istype(officer) || world.time >= officer.dispatch_checkpoint_ask_at)
			if(istype(officer))
				officer.dispatch_checkpoint_ask_at = world.time + OUTPOST_CHECKPOINT_NPC_ASK_GAP
			post.request_outer(walker)
	return here

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

// =========================================================================
// THE POLICE'S KEY
// =========================================================================
// An officer never walks through a scan chamber on its way somewhere: lobby to concourse it is scanned like anyone
// (checkpoint_step_to_concourse() above), and back it takes the exit gate. But the chamber is no refuge from it.
// With business in there (someone to look for, arrest or walk out: its walk ends in the chamber or a doorway, or it
// stands in one and wants out) pathing lets it through the doors its key opens, and walking into one opens it:
// - the outer door, the lobby's side, where the desk and the cells are. A scan under way stops for it. Never while
//   the inner door is open: the lock holds for the key too, and the inner door shuts in its own time;
// - the inner door only while the gate is down (an emag), when both doors are plain airlocks to everyone. With the
//   gate working no key opens the way onto the concourse for whoever stands in the chamber unscanned: an officer on
//   the concourse walks in if that door stands open, and round by the exit gate if it does not.
// While officers are at work in there (police_at_work()) the chamber scans nobody, its outer door stays open behind
// them, and none of the outpost's people walks in or asks a door. Nothing here moves, stuns or holds anyone: the
// arrest in the chamber is the same arrest as anywhere (outpost_police/police_arrest.dm).

/// Whether `tile` is this checkpoint's: a tile of its chamber or one of its two doorways
/datum/outpost_checkpoint/proc/holds_turf(turf/tile)
	return !!tile && ((tile in chamber_turfs) || tile == get_turf(outer_door) || tile == get_turf(inner_door))

/// `person` as one of this outpost's own officers, on duty and up, nobody playing them; null for anyone else
/datum/outpost_checkpoint/proc/duty_officer(mob/living/person)
	var/mob/living/carbon/human/npc/ambient_npc/outpost/police/cop = person
	if(!istype(cop) || cop.mind || cop.client || cop.stat != CONSCIOUS || !outpost || cop.police?.outpost != outpost)
		return null
	return cop

/**
 * Whether `walker` is an officer with business in here now, so its key is for these doors: it stands in the chamber
 * or a doorway (the way out is its own), or what its own walk goes to is in here (a suspect, the tile they were last
 * seen on, a colleague it covers, evidence on the floor). Where it walks is the officer's own business; nothing here
 * reads where anyone wanted is.
 */
/datum/outpost_checkpoint/proc/police_key_holder(mob/living/walker)
	var/mob/living/carbon/human/npc/ambient_npc/outpost/police/cop = duty_officer(walker)
	if(!cop)
		return FALSE
	if(holds_turf(get_turf(cop)))
		return TRUE
	var/atom/walking_to = cop.ai_controller?.current_movement_target
	return !QDELETED(walking_to) && holds_turf(get_turf(walking_to))

/// Whether pathing takes `walker` through `door`: an officer with business in here, and a door that is open or that its key opens
/datum/outpost_checkpoint/proc/police_key_fits(obj/machinery/door/airlock/outpost/checkpoint/door, mob/living/walker)
	if(QDELETED(outer_door) || QDELETED(inner_door) || !police_key_holder(walker))
		return FALSE
	if(!door.density || is_disabled())
		return TRUE
	return door == outer_door

/**
 * `user` walks into `door`, shut: if it is an officer with business in here, the door its key opens does. The outer
 * door, whatever the chamber is doing, short of having its inner door open; the inner door only while the gate is
 * down. TRUE if it opens.
 */
/datum/outpost_checkpoint/proc/police_key(obj/machinery/door/airlock/outpost/checkpoint/door, mob/living/user)
	if(QDELETED(outer_door) || QDELETED(inner_door) || QDELETED(door) || door.operating || !door.density || !police_key_holder(user))
		return FALSE
	if(is_disabled())
		return open_freely(door)
	if(door != outer_door)
		return FALSE
	// Whoever is being scanned waits: nothing is decided about a chamber the police have opened
	if(state == CHECKPOINT_SCANNING)
		set_state(CHECKPOINT_IDLE)
	return request_outer(user)

/// Whether `person` is someone the police are after or hold: wanted here, under arrest, or in custody
/datum/outpost_checkpoint/proc/police_wants(mob/living/person)
	var/datum/outpost_police/police = outpost?.police
	if(!police || !isliving(person) || !person.mind || person.stat == DEAD)
		return FALSE
	return police.get_stars(person.mind) >= 1 || police.arrest_on(person) || police.in_custody(person)

/**
 * Whether the police are at work in here: one of the outpost's officers, on duty and not just going through to the
 * concourse, stands in the chamber or a doorway, and so does someone they are after or hold (in a locker or a mech
 * counts). An officer by itself is no work: one dragged in here holds nothing up. Meanwhile the chamber scans nobody,
 * its outer door stays open, and the outpost's people keep out.
 */
/datum/outpost_checkpoint/proc/police_at_work()
	if(!outpost?.police || QDELETED(outer_door) || QDELETED(inner_door))
		return FALSE
	var/list/turf/tiles = chamber_turfs + get_turf(outer_door) + get_turf(inner_door)
	var/officer_here = FALSE
	for(var/turf/tile as anything in tiles)
		for(var/mob/living/carbon/human/npc/ambient_npc/outpost/police/cop in tile)
			// "outpost_police_checkpoint": the source checkpoint_step_to_concourse() gives an officer going through
			if(duty_officer(cop) && !HAS_TRAIT_FROM(cop, TRAIT_CHECKPOINT_CROSSING, "outpost_police_checkpoint"))
				officer_here = TRUE
				break
		if(officer_here)
			break
	if(!officer_here)
		return FALSE
	for(var/turf/tile as anything in tiles)
		for(var/atom/movable/thing as anything in tile)
			if(!scannable(thing))
				continue
			for(var/mob/living/person in thing.get_all_contents())
				if(police_wants(person))
					return TRUE
	return FALSE

/// The police were at work in here when a scan was due (start_scan()): once they are done, whoever is shut in is scanned
/datum/outpost_checkpoint/proc/scan_after_police()
	if(QDELETED(src) || QDELETED(outer_door) || QDELETED(inner_door) || is_disabled() || state != CHECKPOINT_IDLE)
		return
	// A door is open: its closing starts the scan (on_door_closed())
	if(!outer_door.density || !inner_door.density || outer_door.operating || inner_door.operating)
		return
	if(length(chamber_people()))
		start_scan()

#undef OUTPOST_CHECKPOINT_NPC_PLACE_TIME
