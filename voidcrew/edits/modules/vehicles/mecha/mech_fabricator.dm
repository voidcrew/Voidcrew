// Voidcrew extensions to code/modules/vehicles/mecha/mech_fabricator.dm.

/**
 * Allocate only the paid material to the printed item and its contents.
 * Unlike split_materials_uniformly(), omit shares below one unit: material
 * initialization rounds every present entry up to at least one, which can
 * multiply a small ingredient across a package with many nested objects.
 */
/obj/machinery/mecha_part_fabricator/proc/apply_fabrication_materials(obj/item/product, list/paid_materials)
	PRIVATE_PROC(TRUE)

	// Ammunition is otherwise created lazily, after the material allocation.
	for(var/obj/item/ammo_box/box as anything in product.get_all_contents_type(/obj/item/ammo_box))
		box.ammo_list()
	var/list/items = product.get_all_contents_type(/obj/item)
	var/list/weights = list()
	for(var/material in paid_materials)
		for(var/obj/item/item as anything in items)
			weights[material] += item.custom_materials?[material] || 1
	for(var/obj/item/item as anything in items)
		var/list/item_materials = list()
		for(var/material in paid_materials)
			var/weight = item.custom_materials?[material] || 1
			var/share = round(paid_materials[material] * weight / weights[material])
			// Stack splits and merges must also preserve the per-unit budget.
			if(isstack(item))
				var/obj/item/stack/stack = item
				share = round(share / stack.amount) * stack.amount
			if(share > 0)
				item_materials[material] = share
		item.set_custom_materials(item_materials)
		if(isstack(item) && !length(item_materials))
			var/obj/item/stack/stack = item
			stack.mats_per_unit = null
		// Ammo boxes read their intrinsic material map when recycled.
		if(istype(item, /obj/item/ammo_box))
			var/obj/item/ammo_box/box = item
			box.intrinsic_materials = item.custom_materials

/obj/machinery/mecha_part_fabricator
	/// Materials paid for the current job, retained even if parts change mid-print.
	var/list/being_built_materials
