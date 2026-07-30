/**
 * Ship Economy Round-End Rewards
 *
 * Economy is stored in the database via GLOB.ship_economy_db
 *
 * Round-End Rewards:
 * - CREDITS: Given at round-end (base 100, bonuses for performance)
 * - PARTS: Extracted from player inventories at round-end, plus a small
 *   participation grant for anyone who played a character this round
 */

/**
 * Extract parts and give credits at round end
 */
/datum/controller/subsystem/ticker/display_report(popcount)
	. = ..()
	// First, extract ship parts from all players. This has to run before the
	// participation grant so a player's own message order reads
	// "here is what you carried home", then "here is your floor".
	extract_all_player_ship_parts()
	// Then give round-end credits and the participation part
	for(var/client/all_clients as anything in GLOB.clients)
		all_clients.give_round_end_credits()
		all_clients.give_round_end_participation_parts()
