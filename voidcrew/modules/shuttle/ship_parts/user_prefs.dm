/**
 * Ship Economy Round-End Rewards
 *
 * Economy is stored in the database via GLOB.ship_economy_db
 *
 * Round-End Rewards:
 * - CREDITS: Given at round-end (base 100, bonuses for performance)
 * - PARTS: Extracted from player inventories at round-end
 */

/**
 * Extract parts and give credits at round end
 */
/datum/controller/subsystem/ticker/display_report(popcount)
	. = ..()
	// First, extract ship parts from all players
	extract_all_player_ship_parts()
	// Then give round-end credits
	for(var/client/all_clients as anything in GLOB.clients)
		all_clients.give_round_end_credits()
