/**
 * # Outpost police: dispatch
 *
 * Owner: P4. Sectors, the police lifts, ordering units and topping the scene up in waves. Spec 5.2-5.4.
 *
 * - Sectors: the concourse (past the checkpoint), the lobby (the checkpoint area inside the outpost's box),
 *   each hangar berth (the berth datum itself) and outside.
 * - Lift points: the police lift tiles behind the police doors (concourse), the public lift alcove (lobby) and
 *   each berth's alcove. Officers ride between them (ride()) the way the outpost lift moves people, taking
 *   whoever they pull. They never use a checkpoint.
 * - Once a second (tick_dispatch()): officers carried off the outpost leave the roster (abuse M12); waves leave
 *   their door together (M13); a point whose unit could not get out is skipped (M2); the scene is topped up to
 *   the alert level's count, beat officers first, then by lift in waves; surplus response units stand down by
 *   lift; arrests are opened at one and two stars; officer bodies past the cap are collected; nobody at the
 *   outpost for a minute sends the response units away unseen.
 *
 * Every "does this point or officer see that person" test here goes through police.perception.sees() (spec 3
 * and 18); this file never calls can_see.
 */

/// Trait source that holds a wave behind its door until it leaves together
#define POLICE_WAVE_TRAIT "outpost_police_wave"
/// Trait source that holds a rider still in the hangar elevator alcove while the car travels
#define POLICE_RIDE_TRAIT "outpost_police_ride"
/// A wave forms up behind its door this long before it may leave
#define POLICE_WAVE_FORM_UP (3 SECONDS)
/// A wave leaves without members still waiting to be built after this long
#define POLICE_WAVE_WAIT_MAX (15 SECONDS)
/// Response units are sent away unseen after nobody has been at the outpost this long (spec 5.4)
#define POLICE_EMPTY_RECALL (60 SECONDS)
/// A stood-down response unit with no lift to leave by goes, unseen, after waiting this long (players may never all leave)
#define POLICE_NO_LIFT_LEAVE (2 MINUTES)
/// Tiles looked at when picking one out of sight (M2)
#define POLICE_UNSEEN_TRIES 60

// =========================================================================
// P4'S OWN STATE (vars on shared types, declared here; every name starts with dispatch_)
// =========================================================================

/datum/outpost_police
	/// Spawn orders not built yet: order -> POLICE_UNIT_*
	var/list/datum/human_npc_order/dispatch_orders = list()
	/// Waves not yet done with (/datum/outpost_police_wave)
	var/list/datum/outpost_police_wave/dispatch_waves = list()
	/// world.time the next wave may be sent
	var/dispatch_next_wave = 0
	/// Lift points skipped (M2): turf -> world.time they come back
	var/list/turf/dispatch_skipped = list()
	/// Officers carried off the outpost (M12): off the roster, deleted once nobody is near
	var/list/mob/living/carbon/human/npc/ambient_npc/outpost/police/dispatch_strays = list()
	/// world.time since when no player has been at the outpost, or 0
	var/dispatch_empty_since = 0
	/// Where officers hold a docked ship's airlock at three stars and up: mind -> list(last seen turf, post turf)
	var/list/dispatch_holds = list()
	/// Build units at once rather than through the human NPC queue (unit tests)
	var/dispatch_build_now = FALSE

// Chains with police_core.dm's Destroy(): orders not built yet are called off, so nobody is built for a police that is gone
/datum/outpost_police/Destroy()
	for(var/datum/human_npc_order/order as anything in dispatch_orders.Copy())
		qdel(order)
	dispatch_orders.Cut()
	QDEL_LIST(dispatch_waves)
	for(var/mob/living/carbon/human/npc/ambient_npc/outpost/police/stray in dispatch_strays)
		if(stray.police == src)
			stray.police = null
	dispatch_strays.Cut()
	dispatch_skipped.Cut()
	dispatch_holds.Cut()
	return ..()

/mob/living/carbon/human/npc/ambient_npc/outpost/police
	/// The wave they came in, while it is forming up
	var/datum/outpost_police_wave/dispatch_wave
	/// Weakref to the mind of the suspect they are responding to, or null
	var/datum/weakref/dispatch_mind
	/// Mid-ride on a lift
	var/dispatch_riding = FALSE
	/// world.time since when they have stood down with no lift to leave by, or 0
	var/dispatch_no_lift_since = 0
	/// world.time since when a person has been pulling them, or 0 (M11)
	var/dispatch_pull_since = 0
	/// Weakref to who stands in their line of fire (M11)
	var/datum/weakref/dispatch_block_ref
	/// world.time since when they have stood there, or since they were last charged for it
	var/dispatch_block_since = 0
	/// world.time a watched departing officer reached their lift exit tile, or 0
	var/dispatch_exit_arrived_at = 0
	/// world.time they may next ask a lobby checkpoint door to cycle
	var/dispatch_checkpoint_ask_at = 0

/mob/living/carbon/human/npc/ambient_npc/outpost/police/Destroy()
	REMOVE_TRAIT(src, TRAIT_AI_PAUSED, POLICE_WAVE_TRAIT)
	REMOVE_TRAIT(src, TRAIT_AI_PAUSED, POLICE_RIDE_TRAIT)
	if(dispatch_wave)
		dispatch_wave.members -= WEAKREF(src)
		dispatch_wave = null
	police?.clear_checkpoint_crossing(src)
	police?.dispatch_strays -= src
	dispatch_mind = null
	dispatch_block_ref = null
	return ..()

/// Whether they are responding to a suspect
/mob/living/carbon/human/npc/ambient_npc/outpost/police/proc/dispatch_responding()
	return !isnull(dispatch_mind?.resolve())

/// Officers sent together, who leave their lift door together (M13)
/datum/outpost_police_wave
	/// The sector they are for
	var/sector
	/// The lift point they form up on, or null when built out of sight (M2)
	var/turf/point
	/// world.time they may leave
	var/release_at = 0
	/// world.time they left, or 0
	var/released_at = 0
	/// Whether the stuck check (M2) has been made
	var/checked = FALSE
	/// Their spawn orders
	var/list/datum/human_npc_order/orders = list()
	/// Weakrefs to the members built so far
	var/list/datum/weakref/members = list()

/datum/outpost_police_wave/Destroy()
	orders.Cut()
	// Built members still pointing here would keep it from going, or stay frozen behind the door if the wave was dropped early
	for(var/mob/living/carbon/human/npc/ambient_npc/outpost/police/member as anything in living_members())
		REMOVE_TRAIT(member, TRAIT_AI_PAUSED, POLICE_WAVE_TRAIT)
		if(member.dispatch_wave == src)
			member.dispatch_wave = null
	members.Cut()
	point = null
	sector = null
	return ..()

/// The members still about
/datum/outpost_police_wave/proc/living_members()
	. = list()
	for(var/datum/weakref/ref as anything in members)
		var/mob/living/carbon/human/npc/ambient_npc/outpost/police/officer = ref.resolve()
		if(!QDELETED(officer))
			. += officer

/// Whether any of its orders is still waiting to be built
/datum/outpost_police_wave/proc/pending()
	for(var/datum/human_npc_order/order as anything in orders)
		if(!QDELETED(order) && !order.done)
			return TRUE
	return FALSE

// =========================================================================
// THE API (build plan section 2)
// =========================================================================

/// The highest stars among the suspects at the outpost
/datum/outpost_police/proc/alert_level()
	var/best = 0
	for(var/datum/outpost_warrant/warrant as anything in suspects_at_outpost())
		best = max(best, get_stars(warrant.mind))
	return clamp(best, 0, 5)

/// Which sector `where` is in: POLICE_SECTOR_*, or the /datum/outpost_berth of a hangar
/datum/outpost_police/proc/sector_of(turf/where)
	where = get_turf(where)
	if(!where || !outpost)
		return POLICE_SECTOR_OUTSIDE
	if(outpost.is_secured_turf(where))
		return POLICE_SECTOR_CONCOURSE
	if(dispatch_in_box(where))
		if(istype(where.loc, /area/voidcrew/trader_outpost/checkpoint))
			return POLICE_SECTOR_LOBBY
		// The police lift closets open onto the concourse, whatever area the map gives them
		if(where in lift_turfs)
			return POLICE_SECTOR_CONCOURSE
		return POLICE_SECTOR_OUTSIDE
	for(var/datum/outpost_berth/berth as anything in outpost.berths)
		if(berth?.contains_turf(where))
			return berth
	return POLICE_SECTOR_OUTSIDE

/// Whether `from_sector` and `to_sector` share the outpost's main floor (concourse <-> lobby: walked on foot, never a lift)
/datum/outpost_police/proc/dispatch_same_floor(from_sector, to_sector)
	return (from_sector == POLICE_SECTOR_CONCOURSE && to_sector == POLICE_SECTOR_LOBBY) || (from_sector == POLICE_SECTOR_LOBBY && to_sector == POLICE_SECTOR_CONCOURSE)

/**
 * A lift point serving `sector`: one no suspect at the outpost (nor `avoid_sight_of`) sees, the farthest from
 * them first; if every point is watched, the farthest (abuse M13). Points skipped for being blocked (M2) are
 * left out. When `rider` is pulling someone onto a multi-tile elevator alcove, interior alcove tiles come first
 * so the pulled person steps inside the alcove too. Null if the sector has none left.
 */
/datum/outpost_police/proc/lift_point(sector, atom/avoid_sight_of, mob/living/rider)
	var/list/watchers = dispatch_suspect_mobs()
	if(isliving(avoid_sight_of))
		watchers |= avoid_sight_of
	var/list/turf/tiles = dispatch_lift_tiles(sector)
	var/prefer_inner = !!(rider?.pulling && length(tiles) > 2)
	var/turf/best
	var/best_watched = TRUE
	var/best_neighbors = -1
	var/best_distance = -1
	for(var/turf/point as anything in tiles)
		if(!point || dispatch_skipped[point] > world.time)
			continue
		// Someone standing on it: the officer could never step on (review-1 S4)
		if(lift_point_blocked(point, rider))
			continue
		var/neighbors = 0
		if(prefer_inner)
			for(var/dir in GLOB.cardinals)
				if(get_step(point, dir) in tiles)
					neighbors++
		var/watched = FALSE
		var/distance = INFINITY
		for(var/mob/living/watcher as anything in watchers)
			if(perception.sees(point, watcher))
				watched = TRUE
			var/turf/watcher_turf = get_turf(watcher)
			if(watcher_turf?.z == point.z)
				distance = min(distance, get_dist(watcher_turf, point))
		var/better = FALSE
		if(!best)
			better = TRUE
		else if(best_watched && !watched)
			better = TRUE
		else if(best_watched == watched)
			if(prefer_inner && neighbors != best_neighbors)
				better = neighbors > best_neighbors
			else if(distance > best_distance)
				better = TRUE
		if(better)
			best = point
			best_watched = watched
			best_neighbors = neighbors
			best_distance = distance
	return best

/// Whether someone on their feet other than `rider`, or whoever `rider` pulls, stands on `point`
/datum/outpost_police/proc/lift_point_blocked(turf/point, mob/living/rider)
	for(var/mob/living/standing in point)
		if(standing == rider || (rider && rider.pulling == standing) || standing.stat == DEAD || standing.body_position == LYING_DOWN)
			continue
		return TRUE
	return FALSE

/// The hangar elevator panel serving the alcove `start` belongs to, or null
/datum/outpost_police/proc/dispatch_elevator_for(turf/start)
	if(!start || !outpost)
		return null
	if(start in outpost.lobby_alcove_turfs)
		for(var/obj/machinery/outpost_elevator/panel as anything in outpost.lobby_panels)
			if(!QDELETED(panel))
				return panel
		return null
	for(var/datum/outpost_berth/berth as anything in outpost.berths)
		if(berth && (start in berth.alcove_turfs) && !QDELETED(berth.panel))
			return berth.panel
	return null

/// The hangar elevator floor id for `sector` (0 for the lobby, berth_number for a berth), or null
/datum/outpost_police/proc/dispatch_elevator_floor(sector)
	if(sector == POLICE_SECTOR_LOBBY)
		return 0
	var/datum/outpost_berth/berth = sector
	if(istype(berth))
		return berth.berth_number
	return null

/**
 * `officer` rides the hangar elevator from the alcove they stand in to `sector`, with whoever they pull, the same
 * way players use the elevator panel. Concourse <-> lobby and concourse <-> berth never teleport across the map:
 * officers walk between the concourse and the lobby on foot. Sleeps the ride. TRUE on arrival.
 */
/datum/outpost_police/proc/ride(mob/living/officer, sector)
	var/mob/living/carbon/human/npc/ambient_npc/outpost/police/rider = officer
	if(QDELETED(officer) || officer.stat != CONSCIOUS || HAS_TRAIT_FROM(officer, TRAIT_AI_PAUSED, POLICE_RIDE_TRAIT) || (istype(rider) && rider.dispatch_riding))
		return FALSE
	var/turf/start = get_turf(officer)
	if(!start)
		return FALSE
	var/from_sector = sector_of(start)
	if(dispatch_same_floor(from_sector, sector))
		return FALSE
	if((from_sector == POLICE_SECTOR_CONCOURSE && sector != POLICE_SECTOR_CONCOURSE) || (sector == POLICE_SECTOR_CONCOURSE && from_sector != POLICE_SECTOR_CONCOURSE))
		return FALSE
	var/obj/machinery/outpost_elevator/panel = dispatch_elevator_for(start)
	var/floor_id = dispatch_elevator_floor(sector)
	if(!panel || isnull(floor_id))
		// No elevator panel here (a mapping gap): no ride, they walk instead
		return FALSE
	ADD_TRAIT(officer, TRAIT_AI_PAUSED, POLICE_RIDE_TRAIT)
	if(istype(rider))
		rider.dispatch_riding = TRUE
	. = ride_elevator(officer, panel, floor_id)
	if(!QDELETED(officer))
		REMOVE_TRAIT(officer, TRAIT_AI_PAUSED, POLICE_RIDE_TRAIT)
	if(istype(rider) && !QDELETED(rider))
		rider.dispatch_riding = FALSE

/// Runs the alcove step-in and elevator wait for `ride()` while the rider's AI is paused
/datum/outpost_police/proc/ride_elevator(mob/living/officer, obj/machinery/outpost_elevator/panel, floor_id)
	var/list/turf/own_alcove = panel.get_own_alcove()
	if(!length(own_alcove))
		return FALSE
	// Pulling someone still a step outside the alcove: step deeper until tg's pull brings them onto the car floor
	var/atom/movable/pulled_in = officer.pulling
	if(pulled_in && !(get_turf(pulled_in) in own_alcove) && get_dist(officer, pulled_in) <= 1)
		for(var/step_num in 1 to 2)
			if(officer.pulling != pulled_in || (get_turf(pulled_in) in own_alcove))
				break
			var/moved = FALSE
			for(var/pull_now in list(TRUE, FALSE))
				for(var/dir in GLOB.cardinals)
					var/turf/deeper = get_step(officer, dir)
					if(!(deeper in own_alcove))
						continue
					var/triggers_pull = ISDIAGONALDIR(get_dir(pulled_in, deeper)) || get_dist(deeper, pulled_in) > 1
					if(pull_now && !triggers_pull)
						continue
					// An outpost NPC standing there steps out of the car for them
					for(var/mob/living/someone in deeper)
						if(someone != pulled_in && someone.density)
							outpost_npc_step_aside(someone, officer, own_alcove)
					if(!deeper.is_blocked_turf(exclude_mobs = FALSE, source_atom = officer) && officer.Move(deeper, dir))
						moved = TRUE
						break
				if(moved)
					break
			if(!moved)
				break
		if(officer.pulling == pulled_in && !(get_turf(pulled_in) in own_alcove))
			return FALSE
	var/wait_until = world.time + OUTPOST_ELEVATOR_TRAVEL_TIME + 1 SECONDS
	while(!QDELETED(panel) && panel.moving && world.time < wait_until)
		sleep(0.5 SECONDS)
	if(QDELETED(src) || QDELETED(panel) || QDELETED(officer) || officer.stat != CONSCIOUS)
		return FALSE
	if(!panel.start_ride(floor_id, officer))
		return FALSE
	var/ride_until = world.time + OUTPOST_ELEVATOR_TRAVEL_TIME + 2 SECONDS
	while(!QDELETED(panel) && panel.moving && world.time < ride_until)
		sleep(0.5 SECONDS)
	if(QDELETED(src) || QDELETED(officer) || officer.stat != CONSCIOUS)
		return FALSE
	var/list/turf/arrived_alcove = outpost?.get_floor_alcove(floor_id)
	return !!(arrived_alcove && (get_turf(officer) in arrived_alcove))

/// Stubs filled in `outpost_checkpoint_npcs.dm` (`trade/` compiles after `outpost_police/`): checkpoint crossing and the elevator car's state
/datum/outpost_police/proc/checkpoint_step_to_concourse(mob/living/walker)
	return null

/datum/outpost_police/proc/clear_checkpoint_crossing(mob/living/walker)
	return

/datum/outpost_police/proc/elevator_busy(sector)
	return FALSE


/// The sector `ride()` travels to next when going from `from_sector` to `to_sector`, or null when walking on foot
/datum/outpost_police/proc/next_elevator_sector(from_sector, to_sector)
	if(from_sector == to_sector || from_sector == POLICE_SECTOR_OUTSIDE || to_sector == POLICE_SECTOR_OUTSIDE)
		return null
	if((from_sector == POLICE_SECTOR_CONCOURSE && to_sector == POLICE_SECTOR_LOBBY) || (from_sector == POLICE_SECTOR_LOBBY && to_sector == POLICE_SECTOR_CONCOURSE))
		return null
	if(istype(from_sector, /datum/outpost_berth) && to_sector == POLICE_SECTOR_CONCOURSE)
		return POLICE_SECTOR_LOBBY
	return to_sector

/// Which sector's elevator alcove a walker in `from_sector` walks into to board `next_elevator_sector()`
/datum/outpost_police/proc/elevator_board_sector(from_sector)
	return from_sector == POLICE_SECTOR_CONCOURSE ? POLICE_SECTOR_LOBBY : from_sector

/// Queues one unit of `unit_kind` (POLICE_UNIT_*) for `sector`. Returns the spawn order, or null.
/datum/outpost_police/proc/order_unit(unit_kind, sector)
	var/datum/outpost_police_wave/wave = dispatch_new_wave(sector, lift_point(sector))
	var/datum/human_npc_order/order = dispatch_queue_unit(unit_kind, wave)
	if(!order && !length(wave.members))
		dispatch_waves -= wave
		qdel(wave)
	return order

// =========================================================================
// THE TICK
// =========================================================================

/// Once a second (police_core.dm tick()): responders, waves, caps, stand-downs, bodies, cases to open
/datum/outpost_police/proc/tick_dispatch()
	if(!outpost)
		return
	// Before the round starts no NPC's AI or Life() runs (SSai_controllers, SSmobs): units sent now would stand frozen
	// on their lift point, so nothing is sent or opened until it starts
	if(!SSticker.HasRoundStarted())
		return
	dispatch_prune_orders()
	dispatch_check_strays()
	dispatch_check_waves()
	dispatch_collect_bodies()
	if(dispatch_recall_when_empty())
		return
	dispatch_update_holds()
	dispatch_respond(alert_level())
	dispatch_open_cases()
	for(var/mob/living/carbon/human/npc/ambient_npc/outpost/police/officer in officers)
		if(officer.stat == DEAD)
			continue
		officer.dispatch_check_pull()
		officer.check_body_block()
		// Stars drive the stealth states: stand down, look again, take a free route (police_stealth.dm)
		stealth_tick_officer(officer)

/// Drops orders that were built or dropped
/datum/outpost_police/proc/dispatch_prune_orders()
	for(var/datum/human_npc_order/order as anything in dispatch_orders.Copy())
		if(QDELETED(order) || order.done)
			dispatch_orders -= order

/**
 * Whether a player is or was in `npc` (a brain transplant puts one in a human NPC's body): such a body is never
 * deleted out of hand by the police or the recovery (review S4). Logged when `why` is given (one-off checks only).
 */
/proc/outpost_npc_played(mob/living/npc, why)
	if(QDELETED(npc))
		return FALSE
	var/mob/living/carbon/carbon_npc = npc
	if(!npc.mind && !npc.ckey && !npc.client && !(iscarbon(npc) && carbon_npc.last_mind))
		return FALSE
	if(why)
		log_game("OUTPOST POLICE: [key_name(npc)] was not deleted ([why]): a player is or was in that body.")
	return TRUE

/**
 * Abuse M12: an officer carried off the outpost (aboard a ship that undocked, dragged out of the box) leaves
 * the roster and the caps but keeps their AI. Once no player is near enough to see them they are deleted;
 * back at the outpost, they rejoin.
 */
/datum/outpost_police/proc/dispatch_check_strays()
	for(var/mob/living/carbon/human/npc/ambient_npc/outpost/police/officer in officers.Copy())
		if(officer.dispatch_riding || dispatch_at_outpost(officer))
			continue
		remove_officer(officer)
		officer.dispatch_mind = null
		dispatch_strays |= officer
	for(var/mob/living/carbon/human/npc/ambient_npc/outpost/police/stray as anything in dispatch_strays.Copy())
		if(QDELETED(stray))
			dispatch_strays -= stray
			continue
		if(dispatch_at_outpost(stray))
			dispatch_strays -= stray
			add_officer(stray)
			continue
		if(!human_npc_watched(stray))
			dispatch_strays -= stray
			if(outpost_npc_played(stray, "off-outpost stray"))
				continue
			stray.npc_drop_not_gear()
			qdel(stray)

/// Waves leave together once formed up (M13); a point whose unit never got out is skipped (M2)
/datum/outpost_police/proc/dispatch_check_waves()
	for(var/datum/outpost_police_wave/wave as anything in dispatch_waves.Copy())
		var/pending = wave.pending()
		if(!wave.released_at)
			if(world.time >= wave.release_at && (!pending || world.time >= wave.release_at + POLICE_WAVE_WAIT_MAX))
				dispatch_release_wave(wave)
			continue
		if(!wave.checked && world.time >= wave.released_at + OUTPOST_POLICE_LIFT_BLOCKED)
			wave.checked = TRUE
			dispatch_check_stuck(wave)
		if(wave.checked && !pending)
			dispatch_waves -= wave
			for(var/mob/living/carbon/human/npc/ambient_npc/outpost/police/member as anything in wave.living_members())
				if(member.dispatch_wave == wave)
					member.dispatch_wave = null
			qdel(wave)

/// The wave leaves its door: everyone built so far goes at once
/datum/outpost_police/proc/dispatch_release_wave(datum/outpost_police_wave/wave)
	wave.released_at = world.time
	for(var/mob/living/carbon/human/npc/ambient_npc/outpost/police/member as anything in wave.living_members())
		REMOVE_TRAIT(member, TRAIT_AI_PAUSED, POLICE_WAVE_TRAIT)
		// They come out of the lift doors already hunting (spec-stealth 1.4)
		member.police_search_for(member.dispatch_mind?.resolve())

/**
 * Abuse M2. Members still on their lift point a while after leaving, with a suspect to go to, could not get
 * out (a crate or a wall against the door). The point is skipped for OUTPOST_POLICE_LIFT_SKIP, and each stuck
 * member rides to another point of the sector, or, with none left, is put on a tile out of every player's
 * sight, as a unit built there would be.
 */
/datum/outpost_police/proc/dispatch_check_stuck(datum/outpost_police_wave/wave)
	if(!wave.point)
		return
	var/list/stuck = list()
	for(var/mob/living/carbon/human/npc/ambient_npc/outpost/police/member as anything in wave.living_members())
		if(member.stat != CONSCIOUS || member.case || HAS_TRAIT(member, TRAIT_RESTRAINED) || member.pulledby)
			continue
		if(get_dist(member, wave.point) > 1)
			continue
		var/datum/mind/mind = member.dispatch_mind?.resolve()
		var/mob/living/suspect = mind?.current
		if(!isliving(suspect) || get_dist(suspect, wave.point) <= 2)
			continue
		stuck += member
	if(!length(stuck))
		return
	dispatch_skipped[wave.point] = world.time + OUTPOST_POLICE_LIFT_SKIP
	log_game("OUTPOST POLICE: [outpost] lift point [AREACOORD(wave.point)] is blocked; skipped for a while.")
	for(var/mob/living/carbon/human/npc/ambient_npc/outpost/police/member as anything in stuck)
		if(human_npc_watched(member))
			continue
		var/turf/other = lift_point(wave.sector)
		if(other && other != get_turf(member) && !dispatch_tile_watched(other))
			member.forceMove(other)
			continue
		var/turf/hidden = dispatch_unseen_tile(wave.sector)
		if(hidden)
			member.forceMove(hidden)

/**
 * Officer bodies past OUTPOST_POLICE_CORPSE_CAP at this outpost: the oldest is collected (deleted) even if
 * someone is watching. A documented performance exception, like the prison guards' body collection (spec
 * 5.4); the rest go by the base corpse sweep.
 */
/datum/outpost_police/proc/dispatch_collect_bodies()
	var/list/bodies = list()
	for(var/mob/living/carbon/human/npc/ambient_npc/outpost/police/officer in officers)
		// A body a player died in is theirs, and goes by the player rules (review S4)
		if(officer.stat == DEAD && !outpost_npc_played(officer))
			bodies += officer
	while(length(bodies) > OUTPOST_POLICE_CORPSE_CAP)
		var/mob/living/carbon/human/npc/ambient_npc/outpost/police/oldest = bodies[1]
		for(var/mob/living/carbon/human/npc/ambient_npc/outpost/police/body as anything in bodies)
			if(body.timeofdeath < oldest.timeofdeath)
				oldest = body
		bodies -= oldest
		oldest.npc_drop_not_gear()
		var/obj/structure/closet/body_bag/bag = oldest.loc
		var/turf/bag_turf = get_turf(bag)
		qdel(oldest)
		if(istype(bag, /obj/structure/closet/body_bag/outpost_morgue) && !QDELETED(bag) && !(locate(/mob/living) in bag))
			for(var/atom/movable/leftover as anything in bag.contents.Copy())
				if(bag_turf)
					leftover.forceMove(bag_turf)
			qdel(bag)

/// Nobody at the outpost for POLICE_EMPTY_RECALL: response units go, unseen (spec 5.4). TRUE while nobody is there.
/datum/outpost_police/proc/dispatch_recall_when_empty()
	// A wanted person here (connected or not) keeps the response going
	if(length(dispatch_players_at_outpost()) || length(suspects_at_outpost()))
		dispatch_empty_since = 0
		return FALSE
	// Nobody here is wanted at three stars or more: the squad's stun and lethal roles go (owner decision 37)
	clear_roles()
	if(!dispatch_empty_since)
		dispatch_empty_since = world.time
		return TRUE
	if(world.time - dispatch_empty_since < POLICE_EMPTY_RECALL)
		return TRUE
	for(var/mob/living/carbon/human/npc/ambient_npc/outpost/police/officer in officers.Copy())
		if(officer.stat == DEAD || !dispatch_is_response_unit(officer))
			continue
		if(!human_npc_watched(officer) && !outpost_npc_played(officer))
			officer.npc_drop_not_gear()
			qdel(officer)
	for(var/datum/human_npc_order/order as anything in dispatch_orders.Copy())
		qdel(order)
	dispatch_orders.Cut()
	return TRUE

/**
 * Tops the scene up to the alert level's count (spec 5.2): beat officers nearest the suspects first, then
 * response units already about, then new units by lift in waves at the level's cadence. Surplus response
 * units stand down; beat officers go back to their beat.
 */
/datum/outpost_police/proc/dispatch_respond(level)
	// Someone in cuffs or a cell is no reason to keep a response here: the extra units go home (owner decision 37)
	var/list/datum/outpost_warrant/suspects = dispatch_active_suspects()
	level = min(level, dispatch_active_level())
	if(level < 3)
		clear_roles()
	if(level <= 0 || !length(suspects))
		dispatch_stand_down(0)
		dispatch_check_idle()
		return
	var/wanted = OUTPOST_POLICE_UNITS[level]
	var/list/on_scene = list()
	for(var/mob/living/carbon/human/npc/ambient_npc/outpost/police/officer in officers)
		if(!dispatch_can_respond(officer))
			continue
		if(officer.case)
			on_scene += officer
			continue
		var/datum/mind/mind = officer.dispatch_mind?.resolve()
		if(!mind)
			continue
		// Responding still: to whichever suspect is nearest now
		var/datum/outpost_warrant/nearest = dispatch_nearest_suspect(officer, suspects)
		if(!nearest)
			officer.dispatch_mind = null
			continue
		if(nearest.mind != mind)
			officer.dispatch_mind = WEAKREF(nearest.mind)
		on_scene += officer
	// Beat officers first, nearest first; then idle response units; then stood-down response units walking to the lift
	if(length(on_scene) < wanted)
		for(var/pass in 1 to 3)
			if(length(on_scene) >= wanted)
				break
			var/list/pool = list()
			for(var/mob/living/carbon/human/npc/ambient_npc/outpost/police/officer in officers)
				if((officer in on_scene) || officer.unit_kind == POLICE_UNIT_SERGEANT)
					continue
				if(pass == 1 && (!dispatch_can_respond(officer) || dispatch_is_response_unit(officer)))
					continue
				if(pass == 2 && (!dispatch_can_respond(officer) || !dispatch_is_response_unit(officer)))
					continue
				if(pass == 3 && !dispatch_can_recall(officer))
					continue
				pool += officer
			while(length(on_scene) < wanted && length(pool))
				var/mob/living/carbon/human/npc/ambient_npc/outpost/police/pick = dispatch_closest_to_suspects(pool, suspects)
				pool -= pick
				var/datum/outpost_warrant/nearest = dispatch_nearest_suspect(pick, suspects)
				if(!nearest)
					continue
				if(pick.npc_exit)
					pick.npc_stop_leaving()
				pick.dispatch_mind = WEAKREF(nearest.mind)
				pick.dispatch_no_lift_since = 0
				on_scene += pick
	// New units by lift
	var/short = wanted - length(on_scene) - length(dispatch_orders)
	if(short > 0 && world.time >= dispatch_next_wave)
		var/datum/outpost_warrant/top = dispatch_top_suspect(suspects)
		var/mob/living/suspect = top?.mind?.current
		var/sector = sector_of(top?.last_seen_turf || get_turf(suspect))
		if(sector == POLICE_SECTOR_OUTSIDE && suspect)
			sector = sector_of(suspect)
		if(sector != POLICE_SECTOR_OUTSIDE)
			dispatch_send_wave(level, min(short, OUTPOST_POLICE_WAVE[level]), sector, top)
			dispatch_next_wave = world.time + OUTPOST_POLICE_CADENCE[level]
	if(length(on_scene) > wanted)
		dispatch_stand_down(wanted, on_scene)
	dispatch_check_idle(on_scene)

/**
 * Sends a wave of `size` units for `sector`, all from one lift point (no suspect watching it if possible).
 * The kinds fill the level's make-up: a marshal at five stars, tactical at four and five, officers otherwise.
 */
/datum/outpost_police/proc/dispatch_send_wave(level, size, sector, datum/outpost_warrant/top)
	var/datum/outpost_police_wave/wave = dispatch_new_wave(sector, lift_point(sector, top?.mind?.current))
	for(var/i in 1 to size)
		if(!dispatch_queue_unit(dispatch_next_kind(level), wave, top))
			break
	if(!length(wave.orders) && !length(wave.members))
		dispatch_waves -= wave
		qdel(wave)
		return null
	INVOKE_ASYNC(src, PROC_REF(say_dispatch), level >= 5 ? POLICE_LINE_MARSHAL : POLICE_LINE_ALL_UNITS, null)
	return wave

/// The kind the level's make-up is shortest of (spec 5.2: 4 stars two tactical, 5 stars four tactical and a marshal)
/datum/outpost_police/proc/dispatch_next_kind(level)
	var/tactical = 0
	var/marshals = 0
	for(var/mob/living/carbon/human/npc/ambient_npc/outpost/police/officer in officers)
		if(officer.stat == DEAD)
			continue
		if(officer.unit_kind == POLICE_UNIT_TACTICAL)
			tactical++
		else if(officer.unit_kind == POLICE_UNIT_MARSHAL)
			marshals++
	for(var/datum/human_npc_order/order as anything in dispatch_orders)
		if(dispatch_orders[order] == POLICE_UNIT_TACTICAL)
			tactical++
		else if(dispatch_orders[order] == POLICE_UNIT_MARSHAL)
			marshals++
	if(level >= 5 && !marshals)
		return POLICE_UNIT_MARSHAL
	if(tactical < (level >= 5 ? 4 : (level >= 4 ? 2 : 0)))
		return POLICE_UNIT_TACTICAL
	return POLICE_UNIT_OFFICER

/**
 * Brings the scene down to `keep` officers: surplus response units (farthest first) call it in and leave by
 * the nearest lift point; then surplus beat officers go back to their beat. `on_scene` is who is there now
 * (null: everyone responding). Officers on an arrest are never stood down here.
 */
/datum/outpost_police/proc/dispatch_stand_down(keep, list/on_scene)
	if(keep <= 0)
		for(var/datum/human_npc_order/order as anything in dispatch_orders.Copy())
			qdel(order)
		dispatch_orders.Cut()
	if(isnull(on_scene))
		on_scene = list()
		for(var/mob/living/carbon/human/npc/ambient_npc/outpost/police/officer in officers)
			if(officer.stat != DEAD && (officer.case || officer.dispatch_responding() || (dispatch_is_response_unit(officer) && !officer.npc_exit)))
				on_scene += officer
	var/list/candidates = list()
	for(var/mob/living/carbon/human/npc/ambient_npc/outpost/police/officer as anything in on_scene)
		if(!officer.case && !officer.dispatch_riding)
			candidates += officer
	var/list/datum/outpost_warrant/suspects = dispatch_active_suspects()
	var/surplus = length(on_scene) - keep
	var/called_in = FALSE
	// Response units go first, then beat officers
	for(var/pass in 1 to 2)
		while(surplus > 0)
			var/mob/living/carbon/human/npc/ambient_npc/outpost/police/farthest
			var/farthest_distance = -1
			for(var/mob/living/carbon/human/npc/ambient_npc/outpost/police/officer as anything in candidates)
				if(dispatch_is_response_unit(officer) != (pass == 1))
					continue
				var/datum/outpost_warrant/nearest = dispatch_nearest_suspect(officer, suspects)
				var/turf/known = nearest ? dispatch_suspect_turf(nearest) : null
				var/distance = (known && known.z == officer.z) ? get_dist(officer, known) : 1000
				if(distance > farthest_distance)
					farthest = officer
					farthest_distance = distance
			if(!farthest)
				break
			candidates -= farthest
			surplus--
			farthest.dispatch_mind = null
			if(!dispatch_is_response_unit(farthest))
				continue
			if(!dispatch_send_home(farthest))
				continue
			if(!called_in && keep <= 0 && !length(cases))
				called_in = TRUE
				INVOKE_ASYNC(farthest, TYPE_PROC_REF(/mob/living/carbon/human/npc/ambient_npc/outpost/police, police_say), POLICE_LINE_CLEAR, null, TRUE)

/**
 * A response unit goes home: they walk to the nearest lift tile nobody stands on or is already headed for, and leave
 * by it. TRUE once they are on their way. No lift anywhere: they stay about until the outpost empties
 * (dispatch_recall_when_empty()), or, as players may never all leave, until they have waited POLICE_NO_LIFT_LEAVE and
 * nobody can see them.
 */
/datum/outpost_police/proc/dispatch_send_home(mob/living/carbon/human/npc/ambient_npc/outpost/police/officer)
	officer.dispatch_mind = null
	if(officer.dispatch_wave)
		officer.dispatch_wave.members -= WEAKREF(officer)
		officer.dispatch_wave = null
		REMOVE_TRAIT(officer, TRAIT_AI_PAUSED, POLICE_WAVE_TRAIT)
	var/turf/exit = dispatch_free_exit(officer)
	if(!exit)
		if(!officer.dispatch_no_lift_since)
			officer.dispatch_no_lift_since = world.time
		else if(world.time - officer.dispatch_no_lift_since >= POLICE_NO_LIFT_LEAVE && !human_npc_watched(officer) && !outpost_npc_played(officer))
			officer.npc_drop_not_gear()
			qdel(officer)
		return FALSE
	officer.dispatch_no_lift_since = 0
	return officer.npc_walk_out(exit)

/// Sectors whose lift tiles `from_sector` can walk to directly (without cycling a checkpoint or riding an elevator)
/datum/outpost_police/proc/dispatch_walkable_exit_sectors(from_sector)
	if(from_sector == POLICE_SECTOR_CONCOURSE)
		return list(POLICE_SECTOR_CONCOURSE, POLICE_SECTOR_LOBBY)
	if(from_sector == POLICE_SECTOR_LOBBY)
		return list(POLICE_SECTOR_LOBBY)
	if(istype(from_sector, /datum/outpost_berth) && (from_sector in outpost?.berths))
		return list(from_sector)
	return list()

/**
 * The lift tile `officer` leaves by: one in a sector they can walk to on foot (own sector first) that no one else
 * stands on or is headed for, nearest first; failing that, the nearest unskipped one there. Their own tile when they
 * already stand in a lift.
 */
/datum/outpost_police/proc/dispatch_free_exit(mob/living/carbon/human/npc/ambient_npc/outpost/police/officer)
	var/turf/here = get_turf(officer)
	if(!here)
		return null
	if(dispatch_is_lift_tile(here))
		return here
	var/list/sectors = dispatch_walkable_exit_sectors(sector_of(here))
	if(!length(sectors))
		return null
	var/list/turf/taken = list()
	for(var/mob/living/carbon/human/npc/ambient_npc/outpost/police/other in officers)
		if(other != officer && other.npc_exit)
			taken |= other.npc_exit
	// Free and nobody else headed there, then free, in their own sector before any walkable fallback sector
	for(var/share in list(FALSE, TRUE))
		for(var/sector in sectors)
			var/turf/best
			var/best_distance = INFINITY
			for(var/turf/point as anything in dispatch_lift_tiles(sector))
				if(!point || point.z != here.z || dispatch_skipped[point] > world.time || (!share && (point in taken)) || lift_point_blocked(point, officer))
					continue
				var/distance = get_dist(here, point)
				if(distance < best_distance)
					best = point
					best_distance = distance
			if(best)
				return best
	for(var/sector in sectors)
		var/turf/fallback = dispatch_nearest_lift_point(sector, officer)
		if(fallback)
			return fallback
	return null

/**
 * Nobody waits in a lift for good: a response unit with no suspect to go after and no case (theirs is in custody, or
 * gone) goes home; one walking home whose exit someone else now stands on picks another; one standing in any lift is
 * home (npc_may_vanish()).
 */
/datum/outpost_police/proc/dispatch_check_idle(list/on_scene)
	for(var/mob/living/carbon/human/npc/ambient_npc/outpost/police/officer in officers)
		if(officer.stat != CONSCIOUS || !dispatch_is_response_unit(officer) || officer.case || officer.dispatch_riding)
			continue
		if(officer.npc_exit)
			var/turf/exit = officer.npc_exit
			if(get_turf(officer) != exit && lift_point_blocked(exit, officer))
				var/turf/other = dispatch_free_exit(officer)
				if(other && other != exit)
					officer.npc_walk_out(other)
			continue
		if(!dispatch_can_respond(officer) || officer.dispatch_responding() || (on_scene && (officer in on_scene)))
			continue
		// Still forming up behind the lift door with their wave
		if(officer.dispatch_wave && !officer.dispatch_wave.released_at)
			continue
		dispatch_send_home(officer)

/// Suspects at the outpost who are not in custody (cuffed by us or in a cell)
/datum/outpost_police/proc/dispatch_active_suspects()
	. = list()
	for(var/datum/outpost_warrant/warrant as anything in suspects_at_outpost())
		var/mob/living/body = warrant.mind?.current
		if(isliving(body) && in_custody(body))
			continue
		. += warrant

/// The highest stars among the suspects at the outpost who are not in custody
/datum/outpost_police/proc/dispatch_active_level()
	. = 0
	for(var/datum/outpost_warrant/warrant as anything in dispatch_active_suspects())
		. = max(., get_stars(warrant.mind))
	. = clamp(., 0, 5)

/**
 * Opens an arrest for each suspect of one or two stars who has none, one case per two officers, rounded up: a
 * lone officer still makes the arrest (with nobody to cover them), rather than fighting someone it never cuffs.
 * A suspect who is down (any stars, alive) is cuffed where they lie (owner decision 37).
 */
/datum/outpost_police/proc/dispatch_open_cases()
	var/list/datum/outpost_warrant/needing_case = list()
	for(var/datum/outpost_warrant/warrant as anything in suspects_at_outpost())
		var/stars = get_stars(warrant.mind)
		if(stars < 1 || cases[warrant.mind])
			continue
		var/mob/living/suspect = warrant.mind?.current
		if(!isliving(suspect) || suspect.stat == DEAD || in_custody(suspect))
			continue
		var/down = police_suspect_down(suspect)
		if(stars > 2 && !down)
			continue
		needing_case += warrant
	if(!length(needing_case))
		return
	var/available = 0
	for(var/mob/living/carbon/human/npc/ambient_npc/outpost/police/officer in officers)
		if(dispatch_can_respond(officer) && officer.unit_kind != POLICE_UNIT_SERGEANT)
			available++
	// Recall a departing response unit if every non-leaving officer is unavailable while a suspect needs cuffing
	if(!available)
		for(var/mob/living/carbon/human/npc/ambient_npc/outpost/police/officer in officers)
			if(dispatch_can_recall(officer) && officer.unit_kind != POLICE_UNIT_SERGEANT)
				officer.npc_stop_leaving()
				available++
				break
	var/allowed = round((available + 1) / 2)
	if(length(cases) >= allowed)
		return
	for(var/datum/outpost_warrant/warrant as anything in needing_case)
		if(length(cases) >= allowed)
			return
		var/mob/living/suspect = warrant.mind?.current
		if(!isliving(suspect) || suspect.stat == DEAD || in_custody(suspect) || cases[warrant.mind])
			continue
		open_case(warrant, police_suspect_down(suspect))

/**
 * Where officers hold a docked ship at three stars and up (spec 8: they follow through open doors and never
 * breach): beside the ship's outer airlock nearest where the suspect was last seen aboard.
 */
/datum/outpost_police/proc/dispatch_update_holds()
	for(var/datum/mind/mind as anything in dispatch_holds.Copy())
		if(!get_warrant(mind) || get_stars(mind) < 3)
			dispatch_holds -= mind
	for(var/datum/outpost_warrant/warrant as anything in suspects_at_outpost())
		if(get_stars(warrant.mind) < 3 || !warrant.last_seen_turf)
			continue
		var/list/held = dispatch_holds[warrant.mind]
		if(held && held[1] == warrant.last_seen_turf)
			continue
		var/turf/post = dispatch_hold_post(warrant.last_seen_turf)
		if(post)
			dispatch_holds[warrant.mind] = list(warrant.last_seen_turf, post)
		else
			dispatch_holds -= warrant.mind

/// A hangar tile outside the outer airlock of the docked ship `aboard` is on, nearest `aboard`; null if `aboard` is not on a docked ship
/datum/outpost_police/proc/dispatch_hold_post(turf/aboard)
	var/datum/outpost_berth/berth = sector_of(aboard)
	if(!istype(berth) || !berth.ship?.shuttle)
		return null
	var/list/turf/hull = berth.ship.shuttle.return_turfs()
	if(!(aboard in hull))
		return null
	var/turf/best
	var/best_distance = INFINITY
	for(var/turf/hull_turf as anything in hull)
		if(!(locate(/obj/machinery/door/airlock) in hull_turf))
			continue
		var/distance = get_dist(hull_turf, aboard)
		if(distance >= best_distance)
			continue
		for(var/direction in GLOB.cardinals)
			var/turf/outside = get_step(hull_turf, direction)
			if(!outside || (outside in hull) || !isopenturf(outside) || outside.is_blocked_turf(exclude_mobs = TRUE))
				continue
			best = outside
			best_distance = distance
			break
	return best

// =========================================================================
// HELPERS
// =========================================================================

/// Inside the outpost's own box (concourse, lobby, closets), not a hangar
/datum/outpost_police/proc/dispatch_in_box(turf/where)
	var/turf/bottom_left = outpost?.template_bottom_left
	if(!bottom_left || !outpost.outpost_template || where.z != bottom_left.z)
		return FALSE
	return where.x >= bottom_left.x && where.y >= bottom_left.y && where.x < bottom_left.x + outpost.outpost_template.width && where.y < bottom_left.y + outpost.outpost_template.height

/// Whether `thing` is at this outpost: its box, any of its berths and the ships docked there
/datum/outpost_police/proc/dispatch_at_outpost(atom/thing)
	var/turf/where = get_turf(thing)
	return where && get_trader_outpost_for_turf(where) == outpost

/// The lift tiles of `sector`
/datum/outpost_police/proc/dispatch_lift_tiles(sector)
	if(sector == POLICE_SECTOR_CONCOURSE)
		return lift_turfs
	if(sector == POLICE_SECTOR_LOBBY)
		return outpost?.lobby_alcove_turfs || list()
	var/datum/outpost_berth/berth = sector
	if(istype(berth) && (berth in outpost?.berths))
		return berth.alcove_turfs
	return list()

/// Whether `where` is any lift tile of this outpost
/datum/outpost_police/proc/dispatch_is_lift_tile(turf/where)
	if((where in lift_turfs) || (where in outpost?.lobby_alcove_turfs))
		return TRUE
	for(var/datum/outpost_berth/berth as anything in outpost?.berths)
		if(berth && (where in berth.alcove_turfs))
			return TRUE
	return FALSE

/// The lift point of `sector` nearest `from` (of any sector for null); skipped points left out
/datum/outpost_police/proc/dispatch_nearest_lift_point(sector, atom/from)
	var/turf/from_turf = get_turf(from)
	if(!from_turf)
		return null
	var/list/turf/points
	if(isnull(sector))
		points = lift_turfs.Copy()
		points |= outpost?.lobby_alcove_turfs
		for(var/datum/outpost_berth/berth as anything in outpost?.berths)
			if(berth)
				points |= berth.alcove_turfs
	else
		points = dispatch_lift_tiles(sector)
	var/turf/best
	var/best_distance = INFINITY
	for(var/turf/point as anything in points)
		if(!point || point.z != from_turf.z || dispatch_skipped[point] > world.time)
			continue
		var/distance = get_dist(from_turf, point)
		if(distance < best_distance)
			best = point
			best_distance = distance
	return best

/// The hangar elevator alcove tiles of `sector` (`lobby` or a hangar berth; never concourse closets)
/datum/outpost_police/proc/dispatch_elevator_tiles(sector)
	if(sector == POLICE_SECTOR_LOBBY)
		return outpost?.lobby_alcove_turfs || list()
	var/datum/outpost_berth/berth = sector
	if(istype(berth) && (berth in outpost?.berths))
		return berth.alcove_turfs || list()
	return list()

/// An unblocked, unskipped tile in `sector`'s hangar elevator alcove nearest `from`, or null
/datum/outpost_police/proc/dispatch_nearest_elevator_point(sector, atom/from, mob/living/rider)
	var/turf/from_turf = get_turf(from)
	if(!from_turf)
		return null
	var/turf/best
	var/best_distance = INFINITY
	for(var/turf/point as anything in dispatch_elevator_tiles(sector))
		if(!point || point.z != from_turf.z || dispatch_skipped[point] > world.time)
			continue
		if(rider && lift_point_blocked(point, rider))
			continue
		var/distance = get_dist(from_turf, point)
		if(distance < best_distance)
			best = point
			best_distance = distance
	return best

/// Living suspects at the outpost
/datum/outpost_police/proc/dispatch_suspect_mobs()
	. = list()
	for(var/datum/outpost_warrant/warrant as anything in suspects_at_outpost())
		var/mob/living/suspect = warrant.mind?.current
		if(isliving(suspect) && suspect.stat != DEAD)
			. += suspect

/// Living players with a client at the outpost (its box, its berths and the ships docked there)
/datum/outpost_police/proc/dispatch_players_at_outpost()
	. = list()
	for(var/mob/living/player as anything in GLOB.alive_player_list)
		if(player.client && dispatch_at_outpost(player))
			. += player

/// Whether `officer` can be sent somewhere: alive, up, free and not walking out
/datum/outpost_police/proc/dispatch_can_respond(mob/living/carbon/human/npc/ambient_npc/outpost/police/officer)
	if(QDELETED(officer) || officer.stat != CONSCIOUS || officer.npc_exit || officer.fading)
		return FALSE
	// Held still by the ambient pause (nobody on the concourse): they would never come
	if(officer.paused_at)
		return FALSE
	return !human_npc_out_of_fight(officer)

/// Whether a stood-down `officer` walking to the lift can be called back to respond
/datum/outpost_police/proc/dispatch_can_recall(mob/living/carbon/human/npc/ambient_npc/outpost/police/officer)
	if(QDELETED(officer) || officer.stat != CONSCIOUS || !officer.npc_exit || officer.fading || officer.paused_at)
		return FALSE
	return !human_npc_out_of_fight(officer)

/// A unit sent by dispatch (not a beat officer or the sergeant)
/datum/outpost_police/proc/dispatch_is_response_unit(mob/living/carbon/human/npc/ambient_npc/outpost/police/officer)
	return officer.unit_kind != POLICE_UNIT_BEAT && officer.unit_kind != POLICE_UNIT_SERGEANT

/// Where the police think `warrant`'s holder is: where they were last seen, else where they are
/datum/outpost_police/proc/dispatch_suspect_turf(datum/outpost_warrant/warrant)
	return warrant.last_seen_turf || get_turf(warrant.mind?.current)

/// Of `suspects`, the one nearest `officer` by where they are thought to be (another level counts as far away)
/datum/outpost_police/proc/dispatch_nearest_suspect(atom/officer, list/datum/outpost_warrant/suspects)
	var/turf/from = get_turf(officer)
	var/datum/outpost_warrant/best
	var/best_distance = INFINITY
	for(var/datum/outpost_warrant/warrant as anything in suspects)
		var/turf/known = dispatch_suspect_turf(warrant)
		if(!known)
			continue
		var/distance = (from && known.z == from.z) ? get_dist(from, known) : 1000
		if(!best || distance < best_distance)
			best = warrant
			best_distance = distance
	return best

/// Of `candidates`, the officer nearest any of `suspects`
/datum/outpost_police/proc/dispatch_closest_to_suspects(list/candidates, list/datum/outpost_warrant/suspects)
	var/best
	var/best_distance = INFINITY
	for(var/atom/candidate as anything in candidates)
		var/datum/outpost_warrant/nearest = dispatch_nearest_suspect(candidate, suspects)
		var/turf/known = nearest ? dispatch_suspect_turf(nearest) : null
		var/turf/from = get_turf(candidate)
		var/distance = (known && from && known.z == from.z) ? get_dist(from, known) : 1000
		if(!best || distance < best_distance)
			best = candidate
			best_distance = distance
	return best

/// The suspect with the most stars (ties: the first)
/datum/outpost_police/proc/dispatch_top_suspect(list/datum/outpost_warrant/suspects)
	var/datum/outpost_warrant/best
	var/best_stars = 0
	for(var/datum/outpost_warrant/warrant as anything in suspects)
		var/stars = get_stars(warrant.mind)
		if(stars > best_stars)
			best = warrant
			best_stars = stars
	return best

/// Living officers on the roster plus units ordered and not built yet
/datum/outpost_police/proc/dispatch_live_count()
	. = length(dispatch_orders)
	for(var/mob/living/carbon/human/npc/ambient_npc/outpost/police/officer in officers)
		if(officer.stat != DEAD)
			.++

/// The same over every trader outpost
/proc/outpost_police_world_count()
	. = 0
	for(var/obj/structure/overmap/trader_outpost/outpost as anything in GLOB.trader_outposts)
		if(outpost?.police)
			. += outpost.police.dispatch_live_count()

/// A new wave for `sector` from `point` (null: built out of sight)
/datum/outpost_police/proc/dispatch_new_wave(sector, turf/point)
	var/datum/outpost_police_wave/wave = new
	wave.sector = sector
	wave.point = point
	wave.release_at = world.time + (point ? POLICE_WAVE_FORM_UP : 0)
	dispatch_waves += wave
	return wave

/**
 * Queues one unit of `unit_kind` into `wave`, on its lift point, or (none left, M2) on a tile out of every
 * player's sight. Stops at OUTPOST_POLICE_CAP_OUTPOST here and OUTPOST_POLICE_CAP_WORLD everywhere, units
 * waiting to be built included. Returns the order, or null.
 */
/datum/outpost_police/proc/dispatch_queue_unit(unit_kind, datum/outpost_police_wave/wave, datum/outpost_warrant/for_warrant)
	var/unit_type = dispatch_unit_type(unit_kind)
	if(!unit_type || !wave)
		return null
	if(dispatch_live_count() >= OUTPOST_POLICE_CAP_OUTPOST || outpost_police_world_count() >= OUTPOST_POLICE_CAP_WORLD)
		return null
	var/turf/where = wave.point
	if(!where)
		where = dispatch_unseen_tile(wave.sector)
		if(!where)
			return null
		wave.release_at = world.time
	var/outfit = profile?.outfits?[unit_kind]
	var/datum/weakref/mind_ref = for_warrant?.mind ? WEAKREF(for_warrant.mind) : null
	var/datum/human_npc_order/order = spawn_human_npc(unit_type, where, CALLBACK(src, PROC_REF(dispatch_unit_built), wave, mind_ref), outfit = ispath(outfit, /datum/outfit) ? outfit : null, immediate = dispatch_build_now)
	if(!order)
		return null
	wave.orders += order
	if(!order.done)
		dispatch_orders[order] = unit_kind
	wake()
	return order

/// The officer type of POLICE_UNIT_*
/datum/outpost_police/proc/dispatch_unit_type(unit_kind)
	switch(unit_kind)
		if(POLICE_UNIT_BEAT)
			return /mob/living/carbon/human/npc/ambient_npc/outpost/police/beat
		if(POLICE_UNIT_SERGEANT)
			return /mob/living/carbon/human/npc/ambient_npc/outpost/police/sergeant
		if(POLICE_UNIT_OFFICER)
			return /mob/living/carbon/human/npc/ambient_npc/outpost/police/officer
		if(POLICE_UNIT_TACTICAL)
			return /mob/living/carbon/human/npc/ambient_npc/outpost/police/tactical
		if(POLICE_UNIT_MARSHAL)
			return /mob/living/carbon/human/npc/ambient_npc/outpost/police/marshal
	return null

/// A dispatched unit was built: on the roster, in its wave, held behind the door until the wave leaves
/datum/outpost_police/proc/dispatch_unit_built(datum/outpost_police_wave/wave, datum/weakref/mind_ref, mob/living/carbon/human/npc/ambient_npc/outpost/police/officer)
	if(QDELETED(src) || !istype(officer))
		return
	add_officer(officer)
	// Outpost staff, as the ambient people they work beside are while they belong to it
	officer.faction |= FACTION_TURRET
	officer.dispatch_mind = mind_ref
	if(QDELETED(wave))
		return
	officer.dispatch_wave = wave
	// The lift arrives: one chime for the wave (spec 5.3), as the ride's own arrival has
	if(wave.point && !length(wave.members) && get_turf(officer) == wave.point)
		playsound(wave.point, 'sound/machines/ding.ogg', 50, TRUE)
	wave.members += WEAKREF(officer)
	if(!wave.released_at)
		ADD_TRAIT(officer, TRAIT_AI_PAUSED, POLICE_WAVE_TRAIT)
	else
		officer.police_search_for(officer.dispatch_mind?.resolve())

/**
 * A free tile of `sector` at least OUTPOST_POLICE_UNSEEN_SPAWN_DIST from, and out of sight of, every player on
 * its level (abuse M2), or null. Tries up to POLICE_UNSEEN_TRIES tiles.
 */
/datum/outpost_police/proc/dispatch_unseen_tile(sector)
	var/list/turf/pool = list()
	var/datum/outpost_berth/berth = sector
	if(istype(berth))
		pool = shuffle(berth.get_block())
	else if(sector == POLICE_SECTOR_LOBBY && length(outpost?.lobby_alcove_turfs))
		pool = shuffle(RANGE_TURFS(12, pick(outpost.lobby_alcove_turfs)))
	else if(sector == POLICE_SECTOR_CONCOURSE && outpost?.template_bottom_left && outpost.outpost_template)
		var/turf/bottom_left = outpost.template_bottom_left
		for(var/i in 1 to POLICE_UNSEEN_TRIES)
			var/turf/tile = locate(bottom_left.x + rand(0, outpost.outpost_template.width - 1), bottom_left.y + rand(0, outpost.outpost_template.height - 1), bottom_left.z)
			if(tile)
				pool += tile
	if(length(pool) > POLICE_UNSEEN_TRIES)
		pool.Cut(POLICE_UNSEEN_TRIES + 1)
	for(var/turf/tile as anything in pool)
		if(!isopenturf(tile) || isspaceturf(tile) || tile.is_blocked_turf(exclude_mobs = FALSE) || sector_of(tile) != sector)
			continue
		if(locate(/obj/effect/landmark/outpost_checkpoint_chamber) in tile)
			continue
		if(!dispatch_tile_watched(tile))
			return tile
	return null

/// Whether a living player on `tile`'s level is within OUTPOST_POLICE_UNSEEN_SPAWN_DIST of it or sees it
/datum/outpost_police/proc/dispatch_tile_watched(turf/tile)
	if(!islist(SSmobs.clients_by_zlevel) || tile.z > length(SSmobs.clients_by_zlevel))
		return FALSE
	for(var/mob/living/player in SSmobs.clients_by_zlevel[tile.z])
		if(player.stat == DEAD)
			continue
		if(get_dist(player, tile) < OUTPOST_POLICE_UNSEEN_SPAWN_DIST || perception.sees(tile, player))
			return TRUE
	return FALSE

// ===== on the officer =====

/// Abuse M11: a person pulling an officer resists, once every OUTPOST_POLICE_BLOCK_TIME
/mob/living/carbon/human/npc/ambient_npc/outpost/police/proc/dispatch_check_pull()
	var/mob/living/puller = pulledby
	if(mind || client || !isliving(puller) || !puller.mind || police?.perception?.is_officer(puller))
		dispatch_pull_since = 0
		return
	if(!dispatch_pull_since)
		dispatch_pull_since = world.time
		return
	if(world.time - dispatch_pull_since >= OUTPOST_POLICE_BLOCK_TIME)
		dispatch_pull_since = world.time
		police?.report_crime(puller, OUTPOST_CRIME_RESIST, src)

/mob/living/carbon/human/npc/ambient_npc/outpost/police/npc_stop_leaving()
	dispatch_exit_arrived_at = 0
	dispatch_no_lift_since = 0
	return ..()

/// Unwatched departing officers vanish along their walk; watched ones at an open lift alcove call the car and wait its travel delay
/mob/living/carbon/human/npc/ambient_npc/outpost/police/npc_may_vanish()
	// The base's own checks (human_npc_states.dm), less its exit-tile rule, which follows here
	if(isnull(npc_exit) || stat != CONSCIOUS || human_npc_out_of_fight(src) || INCAPACITATED_IGNORING(src, NONE) || pulledby || buckled || !isturf(loc))
		dispatch_exit_arrived_at = 0
		return FALSE
	if(!human_npc_watched(src))
		return TRUE
	// Standing in any lift is as good as their own exit: nobody waits in one for a tile someone else holds
	var/turf/here = get_turf(src)
	if(here != npc_exit && !police?.dispatch_is_lift_tile(here))
		dispatch_exit_arrived_at = 0
		return FALSE
	if(!dispatch_exit_arrived_at)
		dispatch_exit_arrived_at = world.time
		playsound(here, 'sound/machines/chime.ogg', 50, TRUE)
		return FALSE
	return world.time - dispatch_exit_arrived_at >= OUTPOST_ELEVATOR_TRAVEL_TIME

/mob/living/carbon/human/npc/ambient_npc/outpost/police/npc_vanish()
	var/turf/exit_turf = get_turf(src)
	var/arrived_watched = dispatch_exit_arrived_at > 0 && (exit_turf == npc_exit || police?.dispatch_is_lift_tile(exit_turf))
	dispatch_exit_arrived_at = 0
	if(arrived_watched && exit_turf)
		playsound(exit_turf, 'sound/machines/ding.ogg', 50, TRUE)
	return ..()

#undef POLICE_WAVE_TRAIT
#undef POLICE_RIDE_TRAIT
#undef POLICE_WAVE_FORM_UP
#undef POLICE_WAVE_WAIT_MAX
#undef POLICE_EMPTY_RECALL
#undef POLICE_NO_LIFT_LEAVE
#undef POLICE_UNSEEN_TRIES
