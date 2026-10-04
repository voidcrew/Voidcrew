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
		// VOIDCREW EDIT CHANGE START - original: candidate = mergers[id]
		// A new group gives way to an existing group it meets, trusting that group's refresh to
		// take us in. It does not when the member it met was itself cut off from that group
		// (that refresh drops the member too), which left us in no group and mergers null.
		candidate = mergers?[id]
		if(!candidate)
			new /datum/merger(id, allowed_types, src)
			candidate = mergers?[id]
		// VOIDCREW EDIT END
	return candidate
