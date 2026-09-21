// Voidcrew extensions to code/modules/mapping/space_management/space_reservation.dm.

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
