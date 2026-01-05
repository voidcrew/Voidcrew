/**
 * Add cargo shuttle reference to ships
 * This ensures all cargo consoles on the same ship share one shuttle
 */
/obj/structure/overmap/ship
	/// The cargo shuttle associated with this ship
	var/datum/voidcrew_cargo_shuttle/cargo_shuttle

/obj/structure/overmap/ship/Destroy()
	QDEL_NULL(cargo_shuttle)
	return ..()

/**
 * Gets or creates the cargo shuttle for this ship
 */
/obj/structure/overmap/ship/proc/get_cargo_shuttle()
	if(!cargo_shuttle)
		cargo_shuttle = new()
	return cargo_shuttle
