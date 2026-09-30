/datum/export/large/crate/get_cost(obj/exported_obj, apply_elastic = TRUE)
	. = ..()
	// Preserve each crate type's salvage value, but discounted shipping packaging
	// must not refund the shipment. Its removable manifest is not the authority.
	if(istype(exported_obj, /obj/structure/closet/crate))
		var/obj/structure/closet/crate/crate = exported_obj
		if(!isnull(crate.cargo_paid_cost))
			return max(0, min(., FLOOR(crate.cargo_paid_cost * 0.1, 1)))

/datum/export/manifest_correct/get_cost(obj/O, apply_elastic = TRUE)
	var/obj/item/paper/fluff/jobs/cargo/manifest/manifest = O
	return max(0, min(..(), FLOOR(manifest.order_cost * 0.1, 1)))

/// Fuel has one resale ceiling, whether shipped loose or through a stock block.
/proc/plasma_export_bid()
	return max(0, min(SSstock_market.materials_prices[/datum/material/plasma], 10))

/datum/export/material/plasma/get_cost(obj/exported_obj, apply_elastic = TRUE)
	return round(plasma_export_bid() * get_amount(exported_obj))
