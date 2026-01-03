/**
 * Ship Parts Extraction System
 *
 * Handles extracting ship parts from players when:
 * - Bluespace jump is completed
 * - Round ends
 *
 * Parts must be inside an extraction briefcase on the player's person
 * to be extracted. The player holding the briefcase gets the parts added to their account.
 */

/// Tracks which ckeys have already extracted this round (prevents respawn exploit)
GLOBAL_LIST_EMPTY(extracted_this_round)

/**
 * Extract all ship parts from a player's extraction briefcases and add them to their account
 *
 * @param player - The mob to extract parts from
 * @param extraction_type - Description of how extraction was triggered (for logging)
 * @return List of extracted parts by class, e.g. list("combat" = 2, "science" = 1)
 */
/proc/extract_ship_parts_from_player(mob/living/player, extraction_type = "unknown")
	if(!player)
		return list()

	// Only living players can extract - no extracting from corpses
	if(player.stat == DEAD)
		return list()

	// Must have an active mind - no SSD, logged off, or ghosted players
	if(!player.mind || !player.mind.active)
		return list()

	var/client/player_client = player.client
	if(!player_client)
		return list()

	var/ckey = player_client.ckey
	if(!ckey)
		return list()

	// Check if this player has already extracted this round
	if(ckey in GLOB.extracted_this_round)
		to_chat(player, span_warning("You have already extracted parts this round!"))
		return list()

	// Find all extraction cases on the player
	var/list/cases = find_extraction_cases_on_mob(player)

	if(!length(cases))
		return list()

	// Only extract from the FIRST case - prevents hoarding multiple cases
	var/obj/item/storage/briefcase/secure/extraction/primary_case = cases[1]

	// Warn if they have multiple cases
	if(length(cases) > 1)
		to_chat(player, span_warning("You have multiple extraction cases! Only the first one found will be extracted."))

	// Count parts by class
	var/list/extracted_counts = list()
	for(var/part_class in GLOB.ship_part_classes)
		extracted_counts[part_class] = 0

	// Extract parts from the primary case only
	var/list/parts_to_delete = list()
	for(var/obj/item/ship_parts/part in primary_case.contents)
		var/part_class = part.part_class

		// Try to add to database
		if(GLOB.ship_economy_db?.add_part(ckey, part_class, 1, extraction_type))
			extracted_counts[part_class]++
			parts_to_delete += part

			// Log the extraction
			GLOB.ship_economy_db?.log_extraction(ckey, part_class, extraction_type, "\ref[part]")
		else
			// Failed to add - queue for retry
			GLOB.ship_economy_db?.queue_pending_extraction(ckey, part_class, "\ref[part]")
			parts_to_delete += part // Still delete the item to prevent duplication

	// Delete extracted parts
	for(var/obj/item/ship_parts/part in parts_to_delete)
		qdel(part)

	// Mark this player as having extracted this round (prevent respawn exploit)
	if(length(parts_to_delete))
		GLOB.extracted_this_round += ckey

	// Notify player
	var/total_extracted = 0
	var/list/extraction_summary = list()
	for(var/part_class in extracted_counts)
		var/count = extracted_counts[part_class]
		if(count > 0)
			total_extracted += count
			extraction_summary += "[count] [part_class]"

	if(total_extracted > 0)
		to_chat(player, span_notice("Ship parts extracted from briefcase: [extraction_summary.Join(", ")]. Added to your account!"))

	return extracted_counts

/**
 * Find all extraction cases on a mob (inventory, hands, worn containers)
 *
 * @param target - The mob to search
 * @return List of /obj/item/storage/briefcase/secure/extraction found
 */
/proc/find_extraction_cases_on_mob(mob/living/target)
	var/list/found_cases = list()

	if(!target)
		return found_cases

	// Check all contents recursively (this includes hands, inventory, and contents of containers)
	for(var/obj/item/storage/briefcase/secure/extraction/case in target.get_all_contents())
		found_cases += case

	return found_cases

/**
 * Find all ship parts on a mob that are NOT in an extraction briefcase
 * Used to warn players about unextracted parts
 *
 * @param target - The mob to search
 * @return List of /obj/item/ship_parts found outside of extraction briefcases
 */
/proc/find_loose_ship_parts_on_mob(mob/living/target)
	var/list/loose_parts = list()

	if(!target)
		return loose_parts

	// Get all cases first
	var/list/cases = find_extraction_cases_on_mob(target)
	var/list/case_contents = list()
	for(var/obj/item/storage/briefcase/secure/extraction/case in cases)
		case_contents += case.contents

	// Find all ship parts and check if they're in a case
	for(var/obj/item/ship_parts/part in target.get_all_contents())
		if(!(part in case_contents))
			loose_parts += part

	return loose_parts

/**
 * Extract parts from all players on a ship
 * Called during bluespace jump
 *
 * @param ship - The ship structure (/obj/structure/overmap/ship)
 * @param extraction_type - Description for logging
 * @return Total number of parts extracted
 */
/proc/extract_ship_parts_from_ship(obj/structure/overmap/ship/ship, extraction_type = "bluespace_jump")
	if(!ship)
		return 0

	var/obj/docking_port/mobile/shuttle = ship.shuttle
	if(!shuttle)
		return 0

	var/total_extracted = 0

	// Get all mobs in shuttle areas
	for(var/area/shuttle_area in shuttle.shuttle_areas)
		for(var/mob/living/player in shuttle_area)
			if(!player.client)
				continue

			// Warn about loose parts before extraction
			var/list/loose_parts = find_loose_ship_parts_on_mob(player)
			if(length(loose_parts))
				to_chat(player, span_warning("You have [length(loose_parts)] ship part(s) NOT in an extraction briefcase! These will NOT be extracted!"))

			var/list/extracted = extract_ship_parts_from_player(player, extraction_type)
			for(var/part_class in extracted)
				total_extracted += extracted[part_class]

	if(total_extracted > 0)
		log_game("SHIP_EXTRACTION: Extracted [total_extracted] total parts from ship [ship.name] via [extraction_type]")

	return total_extracted

/**
 * Extract parts from all players at round end
 * Called from the round end hook
 */
/proc/extract_all_player_ship_parts()
	var/total_extracted = 0

	for(var/client/C in GLOB.clients)
		if(!C.mob || !isliving(C.mob))
			continue

		var/mob/living/player = C.mob

		// Warn about loose parts
		var/list/loose_parts = find_loose_ship_parts_on_mob(player)
		if(length(loose_parts))
			to_chat(player, span_warning("You had [length(loose_parts)] ship part(s) NOT in an extraction briefcase! These were NOT extracted!"))

		var/list/extracted = extract_ship_parts_from_player(player, "round_end")

		for(var/part_class in extracted)
			total_extracted += extracted[part_class]

	if(total_extracted > 0)
		log_game("SHIP_EXTRACTION: Extracted [total_extracted] total parts from all players at round end")

	// Clear the extraction tracking for next round
	GLOB.extracted_this_round.Cut()

	return total_extracted
