// Voidcrew extensions to code/game/area/areas.dm.

/**
 * Drops the trailing all-empty z entries off turfs_to_uncontain_by_zlevel.
 *
 * `length(turfs_to_uncontain_by_zlevel)` is the cheap "is there anything pending" test that
 * get_zlevel_turf_lists(), get_turfs_by_zlevel() and has_contained_turfs() all branch on, so
 * an area whose cut lists have all been applied has to shrink back to zero or those hot
 * readers keep paying to rediscover that there is nothing to do.
 *
 * Only trailing empties are dropped - a populated z anywhere in the list stops the walk - so
 * this can never discard a pending cut. Callers that are mid-iteration over the list must
 * call it AFTER the loop: it shortens the list, and DM snapshots a `1 to length()` bound.
 */
/area/proc/trim_trailing_empty_uncontain_lists()
	var/current_length = length(turfs_to_uncontain_by_zlevel)
	var/new_length = current_length
	// Walk backwards thru the list
	for (var/i in current_length to 0 step -1)
		if (i && length(turfs_to_uncontain_by_zlevel[i]))
			break // Stop the moment we find a useful list
		new_length = i

	if (new_length < current_length)
		turfs_to_uncontain_by_zlevel.len = new_length

/**
 * VOIDCREW ADDITION: TRUE when a turf really does still stand in this area.
 *
 * has_contained_turfs() above answers from list LENGTHS - `turfs_by_zlevel` minus the
 * pending `turfs_to_uncontain_by_zlevel` - and that arithmetic only balances if every entry
 * added to one list eventually gets its counterpart applied against the other.
 *
 * It did not. SSarea_contents used to empty an area's whole cut list in a single assignment
 * once its drain loop finished, and change_area() appends to that same list during every
 * MC_TICK_CHECK yield the drain takes. Anything that landed mid-drain was discarded without
 * ever being applied, leaving one PHANTOM entry in `turfs_by_zlevel` per lost cut - and
 * nothing that could ever remove it. An area in that state answers "still occupied" forever
 * even once every real turf has been handed back, which is exactly the state a torn-down
 * site's area is in, and why reap_emptied_areas() could not collect them.
 *
 * That discard is fixed (area_contents.dm drains one z at a time and clears only what it
 * just applied), so this should now find residue only from paths that hand-roll the
 * bookkeeping. It stays as the load-bearing safety for reap_emptied_areas(): reparenting
 * live ground out from under a co-tenant is unrecoverable, and a length comparison is not
 * worth that risk.
 *
 * Cheap in the case it exists for: get_zlevel_turf_lists() cannonizes first, which drops
 * every properly-returned turf, so what is walked here is just the residue.
 */
/area/proc/has_resident_turfs()
	for (var/list/zlevel_turfs as anything in get_zlevel_turf_lists())
		for (var/turf/resident as anything in zlevel_turfs)
			if (resident?.loc == src)
				return TRUE
	return FALSE
