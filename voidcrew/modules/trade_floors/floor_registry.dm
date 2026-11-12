/**
 * # Outpost floors: letting, buying and the one-a-crew rule
 *
 * Owner: P1. Stubs below are P0's and answer as if there were no floors.
 */

/// Makes this outpost's `floor_count` floor datums, none with ground yet. Stub: nothing.
/// P1: call it when the interior links, and give each a tenant name through P8.
/obj/structure/overmap/trader_outpost/proc/make_floors()
	return

/// The lowest-numbered floor that can be sold now, or null. Stub: null.
/obj/structure/overmap/trader_outpost/proc/floor_to_let()
	return null

/// Why `buyer` cannot hold another floor, as text for the counter, or null when they can (A24).
/// The same test runs on buying, claiming, being given a floor and taking over a lease. Stub: null.
/proc/floor_holder_denial(mob/buyer)
	return null

/**
 * The lease on the trader's Colonial Registry shelf. It has no item: dispense() runs the purchase.
 * P1: get_denial_reason() ("No vacancies." / "You already hold a floor."), live stock, and the order of spec 2
 * (mark, charge, reserve, load, link; refund exactly on failure). P9 lists it in the three catalogues.
 */
/datum/shop_sku/outpost_floor
	name = "floor lease"
	desc = "A floor of your own, upstairs."
	category = "Colonial Registry"
	price_credits = OUTPOST_FLOOR_COST_CREDITS
	price_vouchers = OUTPOST_FLOOR_COST_VOUCHERS
	fixed_price = TRUE
	contract_reward = FALSE
	stock_min = 1
	stock_max = 1
