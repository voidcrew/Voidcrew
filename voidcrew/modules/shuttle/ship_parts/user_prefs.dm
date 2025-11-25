/**
 * Ship Parts Preferences - Database-backed Rarity System
 *
 * Parts are now stored in the database via GLOB.ship_economy_db
 * The old savefile-based system has been deprecated.
 *
 * At round end, players receive a random rarity part as a reward.
 */

/**
 * Give a random ship part at round end
 * Weighted by rarity: common is most likely, legendary is rare
 */
/datum/controller/subsystem/ticker/display_report(popcount)
	. = ..()
	for(var/client/all_clients as anything in GLOB.clients)
		all_clients.give_random_ship_part()
