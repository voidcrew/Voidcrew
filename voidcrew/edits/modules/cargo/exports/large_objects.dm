// Voidcrew extensions to code/modules/cargo/exports/large_objects.dm.

/datum/export/large/crate/get_cost(obj/exported_obj, apply_elastic = TRUE)
	. = ..()
	// Preserve each crate type's salvage value, but discounted shipping packaging
	// must not refund the shipment. Its removable manifest is not the authority.
	if(istype(exported_obj, /obj/structure/closet/crate))
		var/obj/structure/closet/crate/crate = exported_obj
		if(!isnull(crate.cargo_paid_cost))
			return max(0, min(., FLOOR(crate.cargo_paid_cost * 0.1, 1)))
