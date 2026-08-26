/atom
	///Holds merger groups currently active on the atom. Do not access directly, use GetMergeGroup() instead.
	var/list/datum/merger/mergers

/// Gets a merger datum representing the connected blob of objects in the allowed_types argument
/atom/proc/GetMergeGroup(id, list/allowed_types)
	RETURN_TYPE(/datum/merger)
	var/datum/merger/candidate
	if(mergers)
		candidate = mergers[id]
	if(!candidate)
		new /datum/merger(id, allowed_types, src)
		// VOIDCREW EDIT CHANGE - was an unguarded mergers[id], which is a "bad index" runtime
		// whenever the merger we just built deleted itself again on the way out. It does that
		// in Refresh() ("if(!length(members)) qdel(src)") when it cannot find even its own
		// origin, and an origin with no turf is exactly that case: an atom part-way through
		// qdel has already been moved to nullspace, so check_turf() has nothing to walk. That
		// is reachable from atmospherics, which asks for the merge group from
		// return_pipenets_for_reconcilation() while a pipeline is still holding a machine the
		// shuttle teardown has started deleting. A merge group with no members legitimately
		// does not exist, so return null and let the caller deal with it.
		if(mergers)
			candidate = mergers[id]
	return candidate
