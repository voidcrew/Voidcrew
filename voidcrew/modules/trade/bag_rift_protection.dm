/// The receiving bag can be on the other side of an area boundary from its user.
/datum/storage/bag_of_holding/proc/can_create_rift(mob/user)
	var/area/bag_area = get_area(parent)
	if(!bag_area || (bag_area.area_flags & NO_BOH) || is_trader_outpost_protected(parent))
		if(user)
			to_chat(user, span_warning("Bluespace interference prevents the bags from nesting here."))
		return FALSE
	return TRUE
