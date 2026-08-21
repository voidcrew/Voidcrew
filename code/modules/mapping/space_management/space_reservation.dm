//Yes, they can only be rectangular.
//Yes, I'm sorry.

/// Above this many turfs, reservation teardown in Release() spreads itself over
/// multiple ticks instead of running atomically. Small reservations keep the
/// historical no-sleep behavior, so qdel() from tick-sensitive contexts stays safe.
#define RESERVATION_RELEASE_YIELD_THRESHOLD 2500

/datum/turf_reservation
	/// All turfs that we've reserved
	var/list/reserved_turfs = list()

	/// Turfs around the reservation for cordoning
	var/list/cordon_turfs = list()

	/// Area of turfs next to the cordon to fill with pre_cordon_area's
	var/list/pre_cordon_turfs = list()

	/// The width of the reservation
	var/width = 0

	/// The height of the reservation
	var/height = 0

	/// The z stack size of the reservation. Note that reservations are ALWAYS reserved from the bottom up
	var/z_size = 0

	/// List of the bottom left turfs. Indexed by what their z index for this reservation is
	var/list/bottom_left_turfs = list()

	/// List of the top right turfs. Indexed by what their z index for this reservation is
	var/list/top_right_turfs = list()

	/// The turf type the reservation is initially made with
	var/turf_type = /turf/open/space

	/// Do we override baseturfs with turf_type?
	var/turf_type_is_baseturf = TRUE

	///Distance away from the cordon where we can put a "sort-cordon" and run some extra code (see make_repel). 0 makes nothing happen
	var/pre_cordon_distance = 0

/datum/turf_reservation/transit
	turf_type = /turf/open/space/transit
	pre_cordon_distance = 7

/// Returns TRUE if the given turf falls inside this reservation's bounds.
/// Cheap bounds check against the per-z corners rather than a search of
/// reserved_turfs, which can run to thousands of entries.
/datum/turf_reservation/proc/contains_turf(turf/checked)
	if(isnull(checked))
		return FALSE

	for(var/z_idx in 1 to length(bottom_left_turfs))
		var/turf/bottom_left = bottom_left_turfs[z_idx]
		var/turf/top_right = top_right_turfs[z_idx]
		if(checked.z != bottom_left.z)
			continue

		return (checked.x >= bottom_left.x && checked.x <= top_right.x) \
			&& (checked.y >= bottom_left.y && checked.y <= top_right.y)

	return FALSE

/datum/turf_reservation/proc/Release()
	// VOIDCREW EDIT: the release set is rebuilt from the corners we recorded at claim time
	// instead of trusting `reserved_turfs` to still list everything _reserve_area() took.
	//
	// `reserved_turfs` is handed out BY REFERENCE: SSshuttle used to alias it straight into
	// the transit area's turfs_by_zlevel (see generate_transit_dock), and the area
	// bookkeeping mutates that list in place - SSarea_contents removes one entry per turf
	// that left the area, and cannonize_contained_turfs_by_zlevel() Cut()s and refills it.
	// So the list drifted into meaning "turfs currently sitting in that area", not "turfs we
	// claimed". A shuttle in transit subtracts its footprint; if the reservation was
	// released before that shuttle handed its turfs back (transit dock force-destroyed while
	// something was docked, ship deleted in transit, jumpToNullSpace) those turfs were never
	// taken out of SSmapping.used_turfs and never returned to unused_turfs. They stayed
	// claimed and flagged for the rest of the round, and once enough of them piled up
	// request_turf_block_reservation() could no longer fit a block and minted a fresh
	// permanent 255x255 reservation z-level (~65k turfs, ~48 MB) instead.
	//
	// Measured on the 52-cycle churn soak as +152 used_turfs a cycle, monotonic, in steps
	// that are hull footprints rather than any rectangle perimeter (101, 172, 262, 322, 323,
	// 383, 399 - odd sizes, and never below SSarea_contents' 100 loose-turf cut threshold).
	//
	// The aliasing itself is fixed at its source in SSshuttle, but the corners are ours
	// alone and cannot be reached by anyone else, so block() over them stays the
	// authoritative answer to "what did we take" no matter who mutates our lists.
	var/list/released = list()
	for(var/z_idx in 1 to min(length(bottom_left_turfs), length(top_right_turfs)))
		var/turf/bottom_left = bottom_left_turfs[z_idx]
		var/turf/top_right = top_right_turfs[z_idx]
		if(isnull(bottom_left) || isnull(top_right))
			continue
		for(var/turf/claimed as anything in block(bottom_left, top_right))
			released[claimed] = TRUE
	// `as anything` on both, so a hard delete that nulled an entry in place does not throw
	// the loop - the nulls are dropped explicitly instead.
	for(var/turf/claimed as anything in reserved_turfs)
		if(!isnull(claimed))
			released[claimed] = TRUE
	for(var/turf/cordon_turf as anything in cordon_turfs)
		if(!isnull(cordon_turf))
			released[cordon_turf] = TRUE

	bottom_left_turfs.Cut()
	top_right_turfs.Cut()
	reserved_turfs = list()
	cordon_turfs = list()

	if(!length(released))
		return

	// Keyed above rather than appended, so a turf listed twice (the aliased transit list
	// appends a returning shuttle turf a second time) is only handed to the drain once -
	// releasing it twice would double-add it to the space area's contents.
	var/list/used = SSmapping.used_turfs
	var/list/release_turfs = list()
	for(var/turf/claimed as anything in released)
		var/datum/turf_reservation/holder = used[claimed]
		if(!isnull(holder) && holder != src && !QDELETED(holder))
			continue // somebody live owns this ground now; it is theirs to hand back
		used -= claimed
		release_turfs += claimed

	// Landable overmap encounters reserve >20k turfs - tearing those down atomically
	// hard-freezes the server for seconds, so large releases yield. This is safe even
	// from qdel(): our turf lists were already emptied above, so a reentrant Release()
	// during a yield has nothing left to double-process.
	var/can_yield = length(release_turfs) > RESERVATION_RELEASE_YIELD_THRESHOLD

	for(var/turf/reserved_turf as anything in release_turfs)
		SEND_SIGNAL(reserved_turf, COMSIG_TURF_RESERVATION_RELEASED, src)

		// immediately disconnect from atmos
		reserved_turf.blocks_air = TRUE
		CALCULATE_ADJACENT_TURFS(reserved_turf, KILL_EXCITED)
		if(can_yield)
			CHECK_TICK

	// Makes the linter happy, even tho we don't await this
	INVOKE_ASYNC(SSmapping, TYPE_PROC_REF(/datum/controller/subsystem/mapping, reserve_turfs), release_turfs)

/// Attempts to calaculate and store a list of turfs around the reservation for cordoning. Returns whether a valid cordon was calculated
/datum/turf_reservation/proc/calculate_cordon_turfs(turf/bottom_left, turf/top_right)
	if(bottom_left.x < 2 || bottom_left.y < 2 || top_right.x > (world.maxx - 2) || top_right.y > (world.maxy - 2))
		return FALSE // no space for a cordon here

	var/list/possible_turfs = CORNER_OUTLINE(bottom_left, width, height)
	// if they're our cordon turfs, accept them
	possible_turfs -= cordon_turfs
	for(var/turf/cordon_turf as anything in possible_turfs)
		if(!(cordon_turf.turf_flags & UNUSED_RESERVATION_TURF))
			return FALSE
	cordon_turfs |= possible_turfs

	if(pre_cordon_distance)
		var/turf/offset_turf = locate(bottom_left.x + pre_cordon_distance, bottom_left.y + pre_cordon_distance, bottom_left.z)
		var/list/to_add = CORNER_OUTLINE(offset_turf, width - pre_cordon_distance * 2, height - pre_cordon_distance * 2) //we step-by-stop move inwards from the outer cordon
		for(var/turf/turf_being_added as anything in to_add)
			pre_cordon_turfs |= turf_being_added //add one by one so we can filter out duplicates

	return TRUE

/// Actually generates the cordon around the reservation, and marking the cordon turfs as reserved
/datum/turf_reservation/proc/generate_cordon()
	for(var/turf/cordon_turf as anything in cordon_turfs)
		var/area/misc/cordon/cordon_area = GLOB.areas_by_type[/area/misc/cordon] || new
		var/area/old_area = cordon_turf.loc

		LISTASSERTLEN(old_area.turfs_to_uncontain_by_zlevel, cordon_turf.z, list())
		LISTASSERTLEN(cordon_area.turfs_by_zlevel, cordon_turf.z, list())
		old_area.turfs_to_uncontain_by_zlevel[cordon_turf.z] += cordon_turf
		cordon_area.turfs_by_zlevel[cordon_turf.z] += cordon_turf
		cordon_area.contents += cordon_turf

		// Its no longer unused, but its also not "used"
		// (not removed from SSmapping.unused_turfs - stale entries there are cheap,
		// per-turf removal is not; see _reserve_area())
		cordon_turf.turf_flags &= ~UNUSED_RESERVATION_TURF
		cordon_turf.empty(/turf/cordon, /turf/cordon)
		// still gets linked to us though
		SSmapping.used_turfs[cordon_turf] = src
		CHECK_TICK

	//swap the area with the pre-cordoning area
	for(var/turf/pre_cordon_turf as anything in pre_cordon_turfs)
		make_repel(pre_cordon_turf)

///Register signals in the cordon "danger zone" to do something with whoever trespasses
/datum/turf_reservation/proc/make_repel(turf/pre_cordon_turf)
	SHOULD_CALL_PARENT(TRUE)
	//Okay so hear me out. If we place a special turf IN the reserved area, it will be overwritten, so we can't do that
	//But signals are preserved even between turf changes, so even if we register a signal now it will stay even if that turf is overriden by the template
	RegisterSignals(pre_cordon_turf, list(COMSIG_QDELETING, COMSIG_TURF_RESERVATION_RELEASED), PROC_REF(on_stop_repel))

/datum/turf_reservation/proc/on_stop_repel(turf/pre_cordon_turf)
	SHOULD_CALL_PARENT(TRUE)
	SIGNAL_HANDLER

	stop_repel(pre_cordon_turf)

///Unregister all the signals we added in RegisterRepelSignals
/datum/turf_reservation/proc/stop_repel(turf/pre_cordon_turf)
	UnregisterSignal(pre_cordon_turf, list(COMSIG_QDELETING, COMSIG_TURF_RESERVATION_RELEASED))

/datum/turf_reservation/transit/make_repel(turf/pre_cordon_turf)
	..()

	RegisterSignal(pre_cordon_turf, COMSIG_ATOM_ENTERED, PROC_REF(space_dump_soft))

/datum/turf_reservation/transit/stop_repel(turf/pre_cordon_turf)
	..()

	UnregisterSignal(pre_cordon_turf, COMSIG_ATOM_ENTERED)

/datum/turf_reservation/transit/proc/space_dump(atom/source, atom/movable/enterer)
	SIGNAL_HANDLER

	dump_in_space(enterer)

///Only dump if we don't have the hyperspace cordon movement exemption trait
/datum/turf_reservation/transit/proc/space_dump_soft(atom/source, atom/movable/enterer)
	SIGNAL_HANDLER

	if(!HAS_TRAIT(enterer, TRAIT_FREE_HYPERSPACE_SOFTCORDON_MOVEMENT))
		space_dump(source, enterer)

/datum/turf_reservation/turf_not_baseturf
	turf_type_is_baseturf = FALSE

/// Internal proc which handles reserving the area for the reservation.
/datum/turf_reservation/proc/_reserve_area(width, height, zlevel)
	src.width = width
	src.height = height
	if(width > world.maxx || height > world.maxy || width < 1 || height < 1)
		return FALSE
	var/list/avail = SSmapping.unused_turfs["[zlevel]"]
	var/turf/BL
	var/turf/TR
	var/list/turf/final = list()
	var/passing = FALSE
	for(var/i in avail)
		CHECK_TICK
		BL = i
		if(!(BL.turf_flags & UNUSED_RESERVATION_TURF))
			continue
		if(BL.x + width > world.maxx || BL.y + height > world.maxy)
			continue
		TR = locate(BL.x + width - 1, BL.y + height - 1, BL.z)
		if(!(TR.turf_flags & UNUSED_RESERVATION_TURF))
			continue
		final = block(BL, TR)
		if(!final)
			continue
		passing = TRUE
		for(var/I in final)
			var/turf/checking = I
			if(!(checking.turf_flags & UNUSED_RESERVATION_TURF))
				passing = FALSE
				break
		if(passing) // found a potentially valid area, now try to calculate its cordon
			passing = calculate_cordon_turfs(BL, TR)
		if(!passing)
			continue
		break
	if(!passing || !istype(BL) || !istype(TR))
		return FALSE

	// Claim every validated turf (ours AND the cordon ring) BEFORE doing any expensive
	// work: the empty() pass below yields via CHECK_TICK, and a turf left
	// validated-but-unclaimed across a yield could be grabbed by a concurrent reserve().
	// Claiming is pure flag/bookkeeping work, so this pass never sleeps.
	// Claimed turfs are deliberately NOT removed from SSmapping.unused_turfs: per-turf
	// removal from a list that size is a linear scan each (quadratic overall - seconds
	// of hard freeze for big reservations). The reserve scan above already skips
	// anything without UNUSED_RESERVATION_TURF, and the unused_turfs lists are assoc
	// keyed by turf, so handing a turf back later just updates its existing key.
	reserved_turfs += final
	for(var/turf/T as anything in final)
		SSmapping.used_turfs[T] = src
		T.turf_flags = (T.turf_flags | RESERVATION_TURF) & ~UNUSED_RESERVATION_TURF
	for(var/turf/cordon_turf as anything in cordon_turfs)
		cordon_turf.turf_flags &= ~UNUSED_RESERVATION_TURF
		SSmapping.used_turfs[cordon_turf] = src

	// Record the corners as part of claiming, not after the conversion below. The
	// turfs are already flagged RESERVATION_TURF and pointed at us in used_turfs, so
	// GET_TURF_ABOVE/BELOW route through this reservation from here on - and those
	// read the corner lists. Publishing them after a pass that yields left a window
	// where a turf claimed by us had no bounds to look up.
	bottom_left_turfs += BL
	top_right_turfs += TR

	// The actual turf conversion is by far the expensive part (a full ChangeTurf per
	// turf) - now that everything is claimed it can safely spread over multiple ticks
	for(var/turf/T as anything in final)
		T.empty(turf_type, turf_type_is_baseturf ? turf_type : null)
		CHECK_TICK

	return TRUE

/datum/turf_reservation/proc/reserve(width, height, z_size, z_reservation)
	src.z_size = z_size
	var/failed_reservation = FALSE
	for(var/_ in 1 to z_size)
		if(!_reserve_area(width, height, z_reservation))
			failed_reservation = TRUE
			break

	if(failed_reservation)
		Release()
		return FALSE

	generate_cordon()
	return TRUE

/// Calculates the effective bounds information for the given turf. Returns a list of the information, or null if not applicable.
/datum/turf_reservation/proc/calculate_turf_bounds_information(turf/target)
	// Bounded by the corner lists rather than z_size, same as contains_turf(): a
	// half-built or already-released reservation still has its z_size set.
	for(var/z_idx in 1 to length(bottom_left_turfs))
		var/turf/bottom_left = bottom_left_turfs[z_idx]
		var/turf/top_right = top_right_turfs[z_idx]
		var/bl_x = bottom_left.x
		var/bl_y = bottom_left.y
		var/tr_x = top_right.x
		var/tr_y = top_right.y

		if(target.x < bl_x)
			continue

		if(target.y < bl_y)
			continue

		if(target.x > tr_x)
			continue

		if(target.y > tr_y)
			continue

		var/list/return_information = list()
		return_information["z_idx"] = z_idx
		return_information["offset_x"] = target.x - bl_x
		return_information["offset_y"] = target.y - bl_y
		return return_information
	return null

/// Gets the turf below the given target. Returns null if there is no turf below the target
/datum/turf_reservation/proc/get_turf_below(turf/target)
	var/list/bounds_info = calculate_turf_bounds_information(target)
	if(isnull(bounds_info))
		return null

	var/z_idx = bounds_info["z_idx"]
	// check what z level, if its the max, then there is no turf below
	if(z_idx >= length(bottom_left_turfs))
		return null

	var/offset_x = bounds_info["offset_x"]
	var/offset_y = bounds_info["offset_y"]
	var/turf/bottom_left = bottom_left_turfs[z_idx + 1]
	return locate(bottom_left.x + offset_x, bottom_left.y + offset_y, bottom_left.z)

/// Gets the turf above the given target. Returns null if there is no turf above the target
/datum/turf_reservation/proc/get_turf_above(turf/target)
	var/list/bounds_info = calculate_turf_bounds_information(target)
	if(isnull(bounds_info))
		return null

	var/z_idx = bounds_info["z_idx"]
	// check what z level, if its the min, then there is no turf above
	if(z_idx == 1)
		return null

	var/offset_x = bounds_info["offset_x"]
	var/offset_y = bounds_info["offset_y"]
	var/turf/bottom_left = bottom_left_turfs[z_idx - 1]
	return locate(bottom_left.x + offset_x, bottom_left.y + offset_y, bottom_left.z)

#undef RESERVATION_RELEASE_YIELD_THRESHOLD

/datum/turf_reservation/New()
	LAZYADD(SSmapping.turf_reservations, src)

/datum/turf_reservation/Destroy()
	Release()
	LAZYREMOVE(SSmapping.turf_reservations, src)
	return ..()
