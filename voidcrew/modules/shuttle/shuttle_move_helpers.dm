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
