/// Voidcrew: powernet -> TRUE/FALSE verdicts from powernet_leaves_hull(), valid for one
/// preflight_check() pass only. Null outside a move.
/obj/docking_port/mobile/var/list/move_powernet_verdicts

/**
 * VOIDCREW ADDITION. Does this powernet have a member that will NOT travel with the hull?
 *
 * A net whose every cable and machine sits on a moving hull tile is carried across the
 * move intact: nothing in a powernet is positional, so there is nothing to rebuild, and
 * the machines on it never see the netless window that cutting opens (an emitter that
 * sees no powernet switches itself off and stays off). Only a net that reaches past the
 * hull - a cable run onto the berth, a docked neighbour wired across the airlock - has to
 * be severed, and then every hull cable of that net is cut so the two halves rebuild
 * separately as before. The walk is over the net's own members, once per net per move.
 *
 * "Moving hull tile" is the same test fromShuttleMove() applies: an area registered on
 * this port AND the shuttle skipover in the baseturfs. A breached tile adopted into a ship
 * area (see /area/onShuttleMove) has the area but no skipover, so a cable lying on it
 * counts as staying behind - which it does.
 */
/obj/docking_port/mobile/proc/powernet_leaves_hull(datum/powernet/net)
	if(isnull(net))
		return FALSE
	if(isnull(move_powernet_verdicts))
		return TRUE // not inside a preflight pass: keep upstream's cut-everything behaviour
	var/verdict = move_powernet_verdicts[net]
	if(!isnull(verdict))
		return verdict
	verdict = FALSE
	for(var/obj/structure/cable/member as anything in net.cables)
		if(isnull(member)) // a hard-deleted member is nulled in place, not removed
			continue
		if(!hull_tile_moves(member.loc))
			verdict = TRUE
			break
	if(!verdict)
		for(var/obj/machinery/power/member as anything in net.nodes)
			if(isnull(member))
				continue
			if(!hull_tile_moves(member.loc))
				verdict = TRUE
				break
	move_powernet_verdicts[net] = verdict
	return verdict

/// Voidcrew: will this turf's contents be carried by the move? Mirrors fromShuttleMove().
/obj/docking_port/mobile/proc/hull_tile_moves(turf/tile)
	if(!isturf(tile))
		return FALSE
	if(!shuttle_areas[tile.loc])
		return FALSE
	return isshuttleturf(tile)

/**
 * Rebuild the hull's powernets and plumbing after a move aborts between preflight_check()
 * and takeoff().
 *
 * By then beforeShuttleMove() has severed every hull cable of any net that reached past the
 * hull (see powernet_leaves_hull(); self-contained nets are left alone), and it deliberately
 * skips the deferred neighbour re-propagation (see /obj/structure/cable/beforeShuttleMove)
 * that used to heal exactly this window - so without this pass an aborted dock leaves the
 * whole grid cut, machines disconnected, until the next successful move. Nothing has moved
 * yet, so propagating from any severed cable rebuilds its grid in place; the rest of that
 * grid then short-circuits on the net it built, and untouched cables never had theirs cut.
 *
 * Plumbing components disconnect in beforeShuttleMove() the same way and are re-enabled
 * in place by restore_plumbing_after_aborted_move() (voidcrew/edits/machinery/plumbing_shuttle_move.dm).
 */
/obj/docking_port/mobile/proc/repair_networks_after_aborted_move(list/old_turfs)
	for(var/i in 1 to length(old_turfs))
		CHECK_TICK
		var/turf/oldT = old_turfs[i]
		if(!oldT)
			continue
		for(var/obj/structure/cable/cut_cable in oldT)
			cut_cable.propagate_if_no_network()
	restore_plumbing_after_aborted_move(old_turfs)

/// How far past the hull's edge evict_landing_stowaways() will look for somewhere to put a stowaway.
#define STOWAWAY_EXIT_DEPTH 5

/**
 * VOIDCREW ADDITION. Evict anything that was standing on the landing site and survived
 * into the hull's interior.
 *
 * /turf/toShuttleMove() is supposed to clear the destination before the deck is laid over
 * it - living things are gibbed, anchored objects deleted, loose objects shoved aside -
 * but "shoved aside" is a single step(thing, shuttle.dir), and that has never been enough
 * for this fork:
 *
 * - One tile does not clear a footprint. Ships land in a 56x40 planet berth
 *   (RESERVE_DOCK_MAX_SIZE_*) with the hull centred in it, so a tank in the middle of the
 *   deck is still under the deck after its step.
 * - The step direction is the port's OLD facing (setDir() to the berth's dir happens at
 *   the very end of initiate_docking()), while preflight_check() walks the destination in
 *   return_ordered_turfs() order - x ascending, y ascending within each column. Whenever
 *   those disagree (ship facing SOUTH or WEST relative to that scan) everything loose is
 *   pushed into tiles the crush has already finished with, and stays there.
 * - step() also simply fails when the next tile is blocked, which on a planet surface it
 *   frequently is.
 * - preflight_check() is full of CHECK_TICKs, so the crush is spread over several ticks
 *   and planet fauna walks onto cleared tiles in the gap. Anything riding inside a shoved
 *   object (a mob in a closet) is never looked at in the first place.
 *
 * Upstream gets away with all of that because a station shuttle's destination is empty
 * space. Ours is a planet surface covered in loot and wildlife, so the leftovers end up on
 * the deck: the reported fuel tanks, shards and RTGs, and the mobs that came with them.
 *
 * moved_atoms is the exact set of movables this move carried, so anything else standing on
 * a turf we just laid down was already there. Crew, cargo, and anything the crew left
 * lying on their own floor are all in moved_atoms and are never touched by this.
 */
/obj/docking_port/mobile/proc/evict_landing_stowaways(list/old_turfs, list/new_turfs, list/moved_atoms)
	var/min_x = INFINITY
	var/min_y = INFINITY
	var/max_x = 0
	var/max_y = 0
	var/footprint_z = 0
	var/list/stowaways = list()
	for(var/i in 1 to length(old_turfs))
		var/turf/landed = new_turfs[i]
		if(!landed)
			continue
		// The rectangle is taken from the WHOLE footprint, not just the tiles that moved,
		// so a stowaway is pushed clear of the ship rather than into the ground squares a
		// non-rectangular hull leaves inside its own bounding box.
		min_x = min(min_x, landed.x)
		max_x = max(max_x, landed.x)
		min_y = min(min_y, landed.y)
		max_y = max(max_y, landed.y)
		footprint_z = landed.z
		var/turf/old_turf = old_turfs[i]
		if(!old_turf)
			continue
		// Both flags, not either: MOVE_CONTENTS is what put this tile's legitimate
		// occupants into moved_atoms, and without it the exemption below cannot be
		// trusted. MOVE_AREA alone is a breached tile - the site's own ground adopted into
		// one of our areas - and what is lying on that is still the site's business.
		var/move_mode = old_turfs[old_turf]
		if((move_mode & (MOVE_TURF|MOVE_CONTENTS)) != (MOVE_TURF|MOVE_CONTENTS))
			continue
		for(var/atom/movable/stowaway as anything in landed.contents)
			if(moved_atoms[stowaway]) // came with the ship
				continue
			if(stowaway.loc != landed) // multi-tile objects
				continue
			if(stowaway.resistance_flags & SHUTTLE_CRUSH_PROOF)
				continue
			// The berth's own stationary port sits inside the rectangle by definition, and
			// non-living mobs are left alone by every other crush branch in this module.
			if(istype(stowaway, /obj/docking_port))
				continue
			if(ismob(stowaway) && !isliving(stowaway))
				continue
			stowaways += stowaway

	if(!length(stowaways))
		return

	var/evicted = 0
	var/destroyed = 0
	for(var/atom/movable/stowaway as anything in stowaways)
		if(QDELETED(stowaway))
			continue
		var/turf/exit_turf = find_stowaway_exit(stowaway, min_x, min_y, max_x, max_y, footprint_z)
		stowaway.pulledby?.stop_pulling()
		stowaway.stop_pulling()
		if(isliving(stowaway))
			var/mob/living/living_stowaway = stowaway
			living_stowaway.buckled?.unbuckle_mob(living_stowaway, force = TRUE)
			if(!exit_turf)
				// Nowhere on the map to put it, and the hull is already on top of it, so
				// this is the crush arriving late rather than a new outcome.
				log_shuttle("[name]: [key_name(living_stowaway)] survived the landing crush at [AREACOORD(living_stowaway)] with nowhere outside the footprint to go - gibbed.")
				living_stowaway.investigate_log("has been gibbed by [src].", INVESTIGATE_DEATHS)
				living_stowaway.gib(DROP_ALL_REMAINS)
				destroyed++
				continue
			log_shuttle("[name]: [key_name(living_stowaway)] survived the landing crush at [AREACOORD(living_stowaway)] - moved clear to [AREACOORD(exit_turf)].")
			living_stowaway.forceMove(exit_turf)
			evicted++
			continue
		if(!exit_turf)
			qdel(stowaway) // what the crush already does to anything it cannot shove
			destroyed++
			continue
		stowaway.forceMove(exit_turf)
		evicted++

	log_shuttle("[name]: landing footprint ([min_x],[min_y],[footprint_z])-([max_x],[max_y],[footprint_z]) held [length(stowaways)] site movable(s) the crush missed - [evicted] moved clear, [destroyed] destroyed.")

/**
 * Nearest turf outside the rectangle the hull just occupied, for a stowaway standing in it.
 *
 * Walks straight out along whichever of the four axes is closest and takes the first tile
 * past the edge that will actually hold the thing, going up to STOWAWAY_EXIT_DEPTH further
 * out if the tiles at the edge are walls or rubble. Falls back to the first tile outside
 * the rectangle it found at all, blocked or not - overlapping something on the surface is
 * a far smaller problem than riding around inside somebody's hull - and the caller only
 * destroys the thing when even that does not exist.
 */
/obj/docking_port/mobile/proc/find_stowaway_exit(atom/movable/stowaway, min_x, min_y, max_x, max_y, footprint_z)
	var/stow_x = stowaway.x
	var/stow_y = stowaway.y
	if(!stow_x || !stow_y)
		return null
	// start_x, start_y, step_x, step_y, tiles from the stowaway to that starting tile
	var/list/exit_lanes = list(
		list(min_x - 1, stow_y, -1, 0, stow_x - (min_x - 1)),
		list(max_x + 1, stow_y, 1, 0, (max_x + 1) - stow_x),
		list(stow_x, min_y - 1, 0, -1, stow_y - (min_y - 1)),
		list(stow_x, max_y + 1, 0, 1, (max_y + 1) - stow_y),
	)
	var/turf/fallback
	var/best_cost = INFINITY
	var/turf/best
	for(var/list/lane as anything in exit_lanes)
		var/lane_cost = lane[5]
		for(var/depth in 0 to STOWAWAY_EXIT_DEPTH - 1)
			if((lane_cost + depth) >= best_cost)
				break
			var/turf/candidate = locate(lane[1] + (lane[3] * depth), lane[2] + (lane[4] * depth), footprint_z)
			if(!candidate)
				break // ran off the edge of the map on this axis
			if(!fallback)
				fallback = candidate
			if(candidate.is_blocked_turf(exclude_mobs = TRUE, source_atom = stowaway))
				continue
			best_cost = lane_cost + depth
			best = candidate
			break
	return best || fallback

#undef STOWAWAY_EXIT_DEPTH

/// The bounding box + z test alone. Subtypes layer extra membership checks onto
/// is_in_shuttle_bounds() (the mobile port also tests shuttle_areas); callers that
/// need to know whether something is PHYSICALLY within the footprint regardless of
/// area bookkeeping (voidcrew refresh_engines()) must use this directly.
/obj/docking_port/proc/is_in_shuttle_bounds_geometric(atom/A)
	var/turf/T = get_turf(A)
	if(!T || T.z != z) // Voidcrew: shuttle separates geometric hull bounds from area membership.
		return FALSE
	var/list/bounds = return_coords()
	var/x0 = bounds[1]
	var/y0 = bounds[2]
	var/x1 = bounds[3]
	var/y1 = bounds[4]
	if(!ISINRANGE(T.x, min(x0, x1), max(x0, x1)))
		return FALSE
	if(!ISINRANGE(T.y, min(y0, y1), max(y0, y1)))
		return FALSE
	return TRUE

/obj/structure/cable/shuttleRotate(rotation, params)
	. = ..()
	// linked_dirs is direction data like any dir, so a rotated landing must rotate it
	// too. afterShuttleMove()'s powernet rebuild walks the grid through EVERY cable's
	// linked_dirs (get_cable_connections()), not just the cable being reconnected, so
	// one cable still carrying pre-rotation bits stalls the walk there and strands
	// everything beyond it on a separate, sourceless powernet - wired but dead.
	if(!linked_dirs)
		return
	var/rotated_dirs = 0
	for(var/check_dir in GLOB.cardinals)
		if(linked_dirs & check_dir)
			rotated_dirs |= angle2dir(rotation + dir2angle(check_dir))
	linked_dirs = rotated_dirs

/obj/structure/cable/lateShuttleMove(turf/oldT, list/movement_force, move_dir)
	. = ..()
	// Deliberately NOT in afterShuttleMove(): the powernet walk trusts every walked
	// cable's linked_dirs, and those are only per-cable correct as each cable's
	// afterShuttleMove() runs. Propagating from the first landed cable while later
	// cables still carry stale bits splits one physical grid into several nets, and
	// propagate_if_no_network() never revisits a cable that has one. By the late
	// pass every cable has relinked, so the first propagate covers the whole grid.
	propagate_if_no_network()
