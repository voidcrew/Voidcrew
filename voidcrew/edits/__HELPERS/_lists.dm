// Voidcrew extensions to code/__HELPERS/_lists.dm.

/**
 * VOIDCREW ADDITION: complains once per cooldown about a typecache filter called with
 * something that isn't a list.
 *
 * The filters below run per-turf inside /turf/proc/empty(), so a reservation the size of a
 * ruin interior calls them seventeen thousand times in a row. An unguarded throw there is
 * not one runtime, it is a runtime per turf - which is how round-7 (2026-08-16) put a
 * quarter of a million reservation runtimes into dd.log. Rate-limited so the diagnosis
 * itself can never become the flood.
 */
/proc/warn_bad_typecache_filter(filter_name, list/atoms, list/typecache)
	var/static/next_complaint = 0
	if(world.time < next_complaint)
		return
	next_complaint = world.time + 10 SECONDS
	stack_trace("[filter_name]() called with [islist(atoms) ? "a list" : "a non-list"] of atoms and [islist(typecache) ? "a list" : "a non-list"] typecache - filtering nothing and returning empty")
