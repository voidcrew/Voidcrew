/**
 * # Specimen crate
 *
 * A heavy crate built to hold one large find. Effects stop while it is shut inside (an
 * artifact off a turf never stirs), so a crew can haul a dangerous find without it going off.
 */
/obj/structure/closet/crate/specimen
	name = "specimen crate"
	desc = "A padded, lead-lined crate big enough for one large find."
	allow_dense = TRUE
	allow_objects = TRUE
	storage_capacity = 10

/obj/structure/closet/crate/specimen/insertion_allowed(atom/movable/thing)
	// The only dense thing it takes is one artifact. No people, no other machines.
	if(istype(thing, /obj/machinery/artifact))
		var/obj/machinery/artifact/find = thing
		if(find.anchored || (locate(/obj/machinery/artifact) in contents))
			return FALSE
		return TRUE
	if(ismob(thing) || (isobj(thing) && thing.density))
		return FALSE
	return ..()
