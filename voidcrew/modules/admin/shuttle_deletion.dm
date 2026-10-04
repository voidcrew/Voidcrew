/// Called after the Shuttle Manipulator's deletion confirmation.
/obj/docking_port/mobile/proc/admin_delete_shuttle(escape = FALSE)
	if(QDELETED(src))
		return FALSE
	if(escape)
		intoTheSunset()
	else
		jumpToNullSpace()
	return TRUE

/// A Voidcrew hull and its overmap ship are one administrative deletion.
/obj/docking_port/mobile/voidcrew/admin_delete_shuttle(escape = FALSE)
	if(QDELETED(src))
		return FALSE
	var/obj/structure/overmap/ship/owner = current_ship
	if(!QDELETED(owner) && owner.shuttle == src)
		owner.detach_shuttle()
	else
		// A stale back-reference must not delete a different, still-owned hull.
		owner = null
		current_ship = null
	. = ..()
	if(!QDELETED(owner))
		qdel(owner)
