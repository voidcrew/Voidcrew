/datum/techweb_node
	/// Standing required for direct research only; imported knowledge remains usable.
	var/zone_permission = ZONE_PERMISSION_PUBLIC
	// list(
	// 	nebulas = 0,
	// 	asteroids = 0,
	// 	electric_storms = 0,
	// 	emp_storms = 0,
	// 	planets = 0,
	// 	stars = 0,
	// )
	var/list/required_surveyed_objects

/// Prices are per-web copies: discounts must never make a debit negative or alter global nodes.
/datum/techweb_node/get_price(datum/techweb/host)
	var/list/prices = ..()
	prices = prices.Copy()
	for(var/point_type in prices)
		prices[point_type] = max(0, prices[point_type])
	return prices
