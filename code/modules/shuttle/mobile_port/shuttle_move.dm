/// This is the main proc. Despite what the name suggests,
/// it instantly moves our mobile port to stationary port `new_dock`.
/obj/docking_port/mobile/proc/initiate_docking(obj/docking_port/stationary/new_dock, movement_direction, force=FALSE)
	// Crashing this ship with NO SURVIVORS

	// Voidcrew: check() calls this with `destination`, which is legitimately null for a
	// ship in open flight - and a null dock used to runtime on the line below, killing
	// the whole SSshuttle fire mid-loop (round 811: Scarab/Kilo/Delta and the
	// shuttle-purchase flow all hit it). Hand check() the error code it already handles.
	if(isnull(new_dock))
		return DOCKING_NULL_DESTINATION

	if(new_dock.get_docked() == src)
		remove_ripples()
		return DOCKING_SUCCESS

	if(!force)
		if(!check_dock(new_dock))
			remove_ripples()
			return DOCKING_BLOCKED
		if(!canMove())
			remove_ripples()
			return DOCKING_IMMOBILIZED

	var/obj/docking_port/stationary/old_dock = get_docked()

	// The area that gets placed under shuttle turfs that do not have their own area to place down
	var/fallback_area_type = SHUTTLE_DEFAULT_UNDERLYING_AREA

	if(old_dock) //Dock overwrites
		fallback_area_type = old_dock.area_type

	/**************************************************************************************************************
		Both lists are associative with a turf:bitflag structure. (new_turfs bitflag space unused currently)
		The bitflag contains the data for what inhabitants of that coordinate should be moved to the new location
		The bitflags can be found in __DEFINES/shuttles.dm
	*/
	var/list/old_turfs = return_ordered_turfs(x, y, z, dir)
	var/list/new_turfs = return_ordered_turfs(new_dock.x, new_dock.y, new_dock.z, new_dock.dir)
	CHECK_TICK
	/**************************************************************************************************************/

	// The fallback area is the area for shuttle turfs that have no area underneath them
	// If it no longer/has never existed it will be created
	var/area/fallback_area = GLOB.areas_by_type[fallback_area_type]
	if(!fallback_area)
		fallback_area = new fallback_area_type(null)

	var/rotation = 0
	if(new_dock.dir != dir) //Even when the dirs are the same rotation is coming out as not 0 for some reason
		rotation = dir2angle(new_dock.dir)-dir2angle(dir)
		if ((rotation % 90) != 0)
			rotation += (rotation % 90) //diagonal rotations not allowed, round up
		rotation = SIMPLIFY_DEGREES(rotation)

	if(!movement_direction)
		movement_direction = REVERSE_DIR(preferred_direction)

	var/list/moved_atoms = list() //Everything not a turf that gets moved in the shuttle
	var/list/areas_to_move = list() //unique assoc list of areas on turfs being moved
	var/list/underlying_areas = list() //unique assoc list of areas beneath turfs being moved

	. = preflight_check(old_turfs, new_turfs, areas_to_move, underlying_areas, rotation)
	if(.)
		repair_powernets_after_aborted_move(old_turfs)
		remove_ripples()
		return

	/*******************************************Hiding turfs if necessary*******************************************/
	// TODO: Move this somewhere sane
	var/list/new_hidden_turfs
	if(hidden)
		new_hidden_turfs = list()
		for(var/i in 1 to old_turfs.len)
			CHECK_TICK
			var/turf/oldT = old_turfs[i]
			if(old_turfs[oldT] & MOVE_TURF)
				new_hidden_turfs += new_turfs[i]
		SSshuttle.update_hidden_docking_ports(null, new_hidden_turfs)
	/***************************************************************************************************************/

	if(!force)
		if(!check_dock(new_dock))
			repair_powernets_after_aborted_move(old_turfs)
			remove_ripples()
			return DOCKING_BLOCKED
		if(!canMove())
			repair_powernets_after_aborted_move(old_turfs)
			remove_ripples()
			return DOCKING_IMMOBILIZED

	// Moving to the new location will trample the ripples there at the exact
	// same time any mobs there are trampled, to avoid any discrepancy where
	// the ripples go away before it is safe.
	takeoff(old_turfs, new_turfs, moved_atoms, rotation, movement_direction, old_dock, fallback_area)

	// VOIDCREW EDIT ADDITION: the landing-zone crush leaks (see evict_landing_stowaways()).
	// Deliberately before the CHECK_TICK below and outside cleanup_runway(): the hull turfs
	// exist as of takeoff() and moved_atoms is final, so this is the one moment where "came
	// with the ship" and "was already lying here" can still be told apart with certainty.
	evict_landing_stowaways(old_turfs, new_turfs, moved_atoms)

	CHECK_TICK

	cleanup_runway(new_dock, old_turfs, new_turfs, areas_to_move, underlying_areas, moved_atoms, rotation, movement_direction, fallback_area)

	CHECK_TICK

	/*******************************************Unhiding turfs if necessary******************************************/
	if(new_hidden_turfs)
		SSshuttle.update_hidden_docking_ports(hidden_turfs, null)
		hidden_turfs = new_hidden_turfs
	/****************************************************************************************************************/

	check_poddoors()
	new_dock.last_dock_time = world.time
	setDir(new_dock.dir)

	// remove any stragglers just in case, and clear the list
	remove_ripples()
	return DOCKING_SUCCESS

/**
 * Rebuild the hull's powernets after a move aborts between preflight_check() and takeoff().
 *
 * By then beforeShuttleMove() has severed every cable on the hull, and it deliberately
 * skips the deferred neighbour re-propagation (see /obj/structure/cable/beforeShuttleMove)
 * that used to heal exactly this window - so without this pass an aborted dock leaves the
 * whole grid cut, machines disconnected, until the next successful move. Nothing has moved
 * yet, so propagating from any severed cable rebuilds its grid in place; the rest of that
 * grid then short-circuits on the net it built, and untouched cables never had theirs cut.
 */
/obj/docking_port/mobile/proc/repair_powernets_after_aborted_move(list/old_turfs)
	for(var/i in 1 to length(old_turfs))
		CHECK_TICK
		var/turf/oldT = old_turfs[i]
		if(!oldT)
			continue
		for(var/obj/structure/cable/cut_cable in oldT)
			cut_cable.propagate_if_no_network()

/obj/docking_port/mobile/proc/preflight_check(list/old_turfs, list/new_turfs, list/areas_to_move, list/underlying_areas, rotation)
	for(var/i in 1 to length(old_turfs))
		CHECK_TICK
		var/turf/oldT = old_turfs[i]
		var/turf/newT = new_turfs[i]
		if(!newT)
			return DOCKING_NULL_DESTINATION
		if(!oldT)
			return DOCKING_NULL_SOURCE

		var/area/old_area = oldT.loc
		var/move_mode = old_area.beforeShuttleMove(shuttle_areas) //areas

		for(var/atom/movable/moving_atom as anything in oldT.contents)
			CHECK_TICK
			if(moving_atom.loc != oldT) //fix for multi-tile objects
				continue
			move_mode = moving_atom.beforeShuttleMove(newT, rotation, move_mode, src) //atoms

		move_mode = oldT.fromShuttleMove(newT, move_mode) //turfs
		move_mode = newT.toShuttleMove(oldT, move_mode, src) //turfs

		if(move_mode & MOVE_AREA)
			var/area/underlying_area = underlying_areas_by_turf[oldT]
			if(underlying_area)
				underlying_areas[underlying_area] = TRUE
			areas_to_move[old_area] = TRUE

		// Voidcrew: a registered hull tile that will not travel is how ships lose
		// engines and deck sections (rounds 803/804) - say exactly why before it
		// happens. Fires for the moving port's own registered areas, and for ANY
		// tile carrying one of our engines: round 811's Pill lost its thruster off
		// a space turf in an orphaned same-name area, which the registered-area
		// filter and the space-turf filter both silently waved through.
		if(!(move_mode & MOVE_TURF))
			var/obj/machinery/power/shuttle_engine/mounted = locate() in oldT
			if(mounted && !(mounted in engine_list))
				mounted = null
			if(mounted || (!isspaceturf(oldT) && shuttle_areas[old_area]))
				log_shuttle("[name]: preflight will leave hull turf [oldT] ([oldT.type]) at [AREACOORD(oldT)] behind[mounted ? " WITH ENGINE [mounted]" : ""] - move_mode=[move_mode], area=[old_area.type] [REF(old_area)] (registered=[shuttle_areas[old_area] ? "yes" : "NO"]), baseturfs=[islist(oldT.baseturfs) ? jointext(oldT.baseturfs, " > ") : "[oldT.baseturfs]"]")

		old_turfs[oldT] = move_mode

/obj/docking_port/mobile/proc/takeoff(list/old_turfs, list/new_turfs, list/moved_atoms, rotation, movement_direction, old_dock, area/fallback_area)
	for(var/i in 1 to old_turfs.len)
		var/turf/oldT = old_turfs[i]
		var/turf/newT = new_turfs[i]
		var/move_mode = old_turfs[oldT]

		if(move_mode & MOVE_TURF)
			oldT.onShuttleMove(newT, movement_force, movement_direction, move_mode & MOVE_AREA) //turfs

		if(move_mode & MOVE_AREA)
			var/area/shuttle_area = oldT.loc
			shuttle_area.onShuttleMove(oldT, newT, src, fallback_area) //areas

		if(move_mode & MOVE_CONTENTS)
			for(var/k in oldT)
				var/atom/movable/moving_atom = k
				if(moving_atom.loc != oldT) //fix for multi-tile objects
					continue
				moving_atom.onShuttleMove(newT, oldT, movement_force, movement_direction, old_dock, src) //atoms
				moved_atoms[moving_atom] = oldT

		if(move_mode & MOVE_SPECIAL)
			SEND_SIGNAL(oldT, COMSIG_SHUTTLE_TURF_ON_MOVE_SPECIAL, newT, movement_force, movement_direction, old_dock, src)

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

/obj/docking_port/mobile/proc/cleanup_runway(obj/docking_port/stationary/new_dock, list/old_turfs, list/new_turfs, list/areas_to_move, list/underlying_areas, list/moved_atoms, rotation, movement_direction, area/fallback_area)
	fallback_area.afterShuttleMove(0)
	for(var/i in 1 to underlying_areas.len)
		CHECK_TICK
		var/area/underlying_area = underlying_areas[i]
		underlying_area.afterShuttleMove(0)

	// Parallax handling
	// This needs to be done before the atom after move
	var/new_parallax_dir = FALSE
	if(istype(new_dock, /obj/docking_port/stationary/transit))
		new_parallax_dir = preferred_direction
	for(var/i in 1 to areas_to_move.len)
		CHECK_TICK
		var/area/internal_area = areas_to_move[i]
		internal_area.afterShuttleMove(new_parallax_dir) //areas

	for(var/i in 1 to old_turfs.len)
		CHECK_TICK
		var/turf/old_turf = old_turfs[i]
		var/old_move_mode = old_turfs[old_turf]
		var/turf/old_ceiling = get_step_multiz(old_turf, UP)
		if(old_ceiling) // check if a ceiling was generated previously
			// remove old ceiling
			if(istype(old_ceiling, /turf/open/floor/engine/hull/ceiling))
				old_ceiling.ScrapeAway()
			else
				old_ceiling.remove_baseturfs_from_typecache(list(/turf/open/floor/engine/hull/ceiling = TRUE))
		if(!(old_move_mode & MOVE_TURF))
			continue
		var/turf/new_turf = new_turfs[i]
		new_turf.afterShuttleMove(old_turf, rotation) //turfs
		var/turf/new_ceiling = get_step_multiz(new_turf, UP) // check if a ceiling is needed
		if(new_ceiling)
			// generate ceiling
			if(!(istype(new_ceiling, /turf/open/floor/engine/hull/ceiling) || new_ceiling.depth_to_find_baseturf(/turf/open/floor/engine/hull/ceiling)))
				if(istype(new_ceiling, /turf/open/openspace) || istype(new_ceiling, /turf/open/space/openspace))
					new_ceiling.place_on_top(/turf/open/floor/engine/hull/ceiling)
				else
					new_ceiling.stack_ontop_of_baseturf(/turf/open/openspace, /turf/open/floor/engine/hull/ceiling)
					new_ceiling.stack_ontop_of_baseturf(/turf/open/space/openspace, /turf/open/floor/engine/hull/ceiling)
	for(var/i in 1 to moved_atoms.len)
		CHECK_TICK
		var/atom/movable/moved_object = moved_atoms[i]
		if(QDELETED(moved_object))
			continue
		var/turf/oldT = moved_atoms[moved_object]
		moved_object.afterShuttleMove(oldT, movement_force, dir, preferred_direction, movement_direction, rotation)//atoms

	// lateShuttleMove (There had better be a really good reason for additional stages beyond this)

	fallback_area.lateShuttleMove()

	for(var/i in 1 to areas_to_move.len)
		CHECK_TICK
		var/area/internal_area = areas_to_move[i]
		internal_area.lateShuttleMove()

	for(var/i in 1 to underlying_areas.len)
		CHECK_TICK
		var/area/underlying_area = underlying_areas[i]
		underlying_area.lateShuttleMove()

	for(var/i in 1 to old_turfs.len)
		CHECK_TICK
		if(!(old_turfs[old_turfs[i]] & (MOVE_CONTENTS|MOVE_TURF)))
			continue
		var/turf/oldT = old_turfs[i]
		var/turf/newT = new_turfs[i]
		newT.lateShuttleMove(oldT)

	for(var/i in 1 to moved_atoms.len)
		CHECK_TICK
		var/atom/movable/moved_object = moved_atoms[i]
		if(QDELETED(moved_object))
			continue
		var/turf/oldT = moved_atoms[moved_object]
		moved_object.lateShuttleMove(oldT, movement_force, movement_direction)
