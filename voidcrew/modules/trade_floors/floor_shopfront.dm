/**
 * # Outpost floors: the shopfront
 *
 * Owner: P12 (spec 3b.4, L32-L34, L36). The shop is the player outposts' own (outpost_shop.dm, outpost_shop_stock.dm).
 * Its seams call three base procs on /obj/structure/overmap/dynamic/player_outpost (player_outpost.dm), which answer
 * as before floors: owns_till() (a register that is not the room's own), is_shop_hand() (may stock, serve and open or
 * shut; nothing else) and shop_state_changed() (the shop opened or shut). P12 overrides them on the host here, and
 * owns what an NPC can buy.
 *
 * Stubs below are P0's.
 */

/// Whether this floor has a Shop room, installed and open. Stub: FALSE.
/datum/outpost_floor/proc/shop_open()
	return FALSE

/// The places an NPC could buy at now: the register, tills and shelves a customer can reach. Stub: an empty list.
/datum/outpost_floor/proc/npc_sale_points()
	return list()

/// What an NPC would buy at `point`: list("name" = , "price" = , "consumable" = TRUE/FALSE), or null for nothing.
/// Only a listing priced at or under OUTPOST_FLOOR_NPC_ITEM_MAX. Stub: null.
/datum/outpost_floor/proc/npc_offer(atom/point)
	return null

/// `npc` buys one thing at `point`: the budget pays (npc_budget_spend(), P11), the treasury is credited, the stock
/// really goes and the item is handed over. Returns the item, or null when nothing was sold. Stub: null.
/datum/outpost_floor/proc/npc_buy(mob/living/npc, atom/point)
	return null
