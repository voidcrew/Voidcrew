// Ship ore redemption uses local storage and does not require an ore silo.
/obj/machinery/mineral/ore_redemption
	requires_silo = FALSE

/obj/item/stack/ore/titanium
	points = 40

// Boulder machinery applies MINING_POINT_MACHINE_MULTIPLIER to this material rate.
/datum/material/titanium
	points_per_unit = 50 / SHEET_MATERIAL_AMOUNT

/// Quote the raw ore payout, including this ORM's point upgrade.
/obj/machinery/mineral/ore_redemption/proc/get_ore_points(datum/material/material)
	var/obj/item/stack/ore/ore_type = material.ore_type
	if(!ispath(ore_type, /obj/item/stack/ore))
		return 0
	return initial(ore_type.points) * point_upgrade
