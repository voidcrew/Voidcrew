// Voidcrew extensions to code/modules/cargo/exports/materials.dm.

/// Fuel has one resale ceiling, whether shipped loose or through a stock block.
/proc/plasma_export_bid()
	return max(0, min(SSstock_market.materials_prices[/datum/material/plasma], 10))

/datum/export/material/plasma/get_cost(obj/exported_obj, apply_elastic = TRUE)
	return round(plasma_export_bid() * get_amount(exported_obj))

/datum/export/material/market/plasma/get_cost(obj/exported_obj, apply_elastic = TRUE)
	var/amount = get_amount(exported_obj)
	if(amount <= 0)
		return 0
	var/material_value = plasma_export_bid() * amount
	if(istype(exported_obj, /obj/item/stock_block))
		var/obj/item/stock_block/block = exported_obj
		if(block.export_mat != material_id)
			return 0
		if(!block.fluid)
			material_value = min(material_value, block.export_value)
	return (apply_elastic ? cost : init_cost) * max(0, material_value)
// VOIDCREW EDIT END

/datum/export/material/market/plasma
	message = "cm3 of plasma"
	material_id = /datum/material/plasma
