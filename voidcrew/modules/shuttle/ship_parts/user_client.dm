/**
 * Ship Parts Client Procs - Database-backed Class System
 *
 * These procs manage ship parts and credits for players.
 * Parts are stored in the database via GLOB.ship_economy_db
 *
 * Economy Model:
 * - CREDITS: Earned at round-end, spent on ships
 * - PARTS: Found in-game (exploration/loot), extracted via bluespace jump or round end
 *
 * Part Classes:
 * - Combat: Found in wrecks, combat zones
 * - Science: Found in labs, research sites
 * - Trade: Found at stations, trade posts
 * - Misc: Found in general loot areas
 */

/// Base credits awarded at round end
#define ROUND_END_BASE_CREDITS 100

/**
 * Gives credits at round end
 * Parts are extracted separately via the extraction system
 */
/client/proc/give_round_end_credits()
	if(!ckey)
		return

	var/credits_earned = ROUND_END_BASE_CREDITS

	// TODO: Add bonuses based on round performance, survival, objectives, etc.
	// Example future bonuses:
	// - Survived the round: +25 credits
	// - Completed objectives: +50 credits
	// - Captain/leadership role: +25 credits

	// Add credits to database
	if(GLOB.ship_economy_db?.add_credits(ckey, credits_earned, "round_end_reward"))
		to_chat(src, span_notice("You have earned [credits_earned] ship credits for completing the round!"))
	else
		to_chat(src, span_warning("Failed to receive your credit reward. Please contact an admin."))

/**
 * Returns the player's current credit balance
 */
/client/proc/get_ship_credits()
	if(!ckey)
		return 0
	return GLOB.ship_economy_db?.get_credits(ckey) || 0

/**
 * Gives a readout of credits and all ship parts owned (from database)
 */
/client/proc/list_ship_inventory()
	if(!ckey)
		to_chat(src, span_warning("Unable to identify your account!"))
		return

	// Show credits
	var/credits = GLOB.ship_economy_db?.get_credits(ckey) || 0
	to_chat(src, span_boldnotice("Ship Credits: [credits]"))

	// Show parts
	var/list/parts = GLOB.ship_economy_db?.get_parts(ckey)
	if(!parts)
		to_chat(src, span_warning("Unable to retrieve your parts inventory."))
		return

	to_chat(src, span_boldnotice("Ship Parts:"))
	var/total = 0
	for(var/part_class in GLOB.ship_part_classes)
		var/count = parts[part_class] || 0
		if(count > 0)
			to_chat(src, span_notice("  [count] [part_class]"))
			total += count

	if(total == 0)
		to_chat(src, span_notice("  (none)"))

/**
 * Gives a readout of all ship parts owned (from database)
 */
/client/proc/list_ship_parts()
	if(!ckey)
		to_chat(usr, span_warning("Unable to identify your account!"))
		return

	var/list/parts = GLOB.ship_economy_db?.get_parts(ckey)
	if(!parts)
		to_chat(usr, span_warning("Unable to retrieve your parts inventory."))
		return

	to_chat(usr, span_boldwarning("Currently owned ship parts:"))
	var/total = 0
	for(var/part_class in GLOB.ship_part_classes)
		var/count = parts[part_class] || 0
		if(count > 0)
			to_chat(usr, span_boldwarning("[count] [part_class]"))
			total += count

	if(total == 0)
		to_chat(usr, span_notice("You do not have any ship parts."))

/**
 * Returns a list of owned ship parts for use in UI selection
 * Returns list in format: "class - X owned" = class
 */
/client/proc/get_ships()
	if(!ckey)
		return FALSE

	var/list/parts = GLOB.ship_economy_db?.get_parts(ckey)
	if(!parts)
		to_chat(src, span_notice("Unable to retrieve your parts inventory."))
		return FALSE

	var/list/owned_parts = list()
	for(var/part_class in GLOB.ship_part_classes)
		var/count = parts[part_class] || 0
		if(count > 0)
			owned_parts["[part_class] - [count] owned"] = part_class

	if(!length(owned_parts))
		to_chat(src, span_notice("You do not have any ship parts."))
		return FALSE

	return owned_parts

/**
 * Withdraw a physical ship part item from account
 * @param part_class - The class of part to withdraw (combat/science/trade/misc)
 * @return TRUE if successful
 */
/client/proc/withdraw_ship_part(part_class)
	if(!ckey || !part_class)
		return FALSE

	if(!(part_class in GLOB.ship_part_classes))
		to_chat(src, span_warning("Invalid part class!"))
		return FALSE

	// Check if player has the part
	var/list/parts = GLOB.ship_economy_db?.get_parts(ckey)
	if(!parts || (parts[part_class] || 0) < 1)
		to_chat(src, span_warning("You don't have any [part_class] parts to withdraw!"))
		return FALSE

	// Deduct from database
	var/list/requirements = list()
	requirements[part_class] = 1
	if(!GLOB.ship_economy_db?.spend_parts(ckey, requirements))
		to_chat(src, span_warning("Failed to withdraw part. Please try again."))
		return FALSE

	// Spawn the physical item
	var/obj/item/ship_parts/part_item
	switch(part_class)
		if(PART_CLASS_COMBAT)
			part_item = new /obj/item/ship_parts/combat(mob.loc)
		if(PART_CLASS_SCIENCE)
			part_item = new /obj/item/ship_parts/science(mob.loc)
		if(PART_CLASS_TRADE)
			part_item = new /obj/item/ship_parts/trade(mob.loc)
		if(PART_CLASS_MISC)
			part_item = new /obj/item/ship_parts/misc(mob.loc)

	if(part_item)
		to_chat(src, span_notice("Withdrawn one [part_class] ship part."))
		return TRUE

	return FALSE

/**
 * Verb to withdraw a ship part - presents a selection menu
 */
/client/verb/withdraw_part()
	set name = "Withdraw Ship Part"
	set category = "IC"

	if(!ckey)
		to_chat(src, span_warning("Unable to identify your account!"))
		return

	var/list/parts = GLOB.ship_economy_db?.get_parts(ckey)
	if(!parts)
		to_chat(src, span_warning("Unable to retrieve your parts inventory."))
		return

	// Build selection list
	var/list/available = list()
	for(var/part_class in GLOB.ship_part_classes)
		var/count = parts[part_class] || 0
		if(count > 0)
			available["[part_class] ([count] available)"] = part_class

	if(!length(available))
		to_chat(src, span_notice("You don't have any parts to withdraw."))
		return

	var/choice = tgui_input_list(src, "Select a part class to withdraw:", "Withdraw Ship Part", available)
	if(!choice)
		return

	var/selected_class = available[choice]
	if(withdraw_ship_part(selected_class))
		to_chat(src, span_notice("Part withdrawn successfully!"))

/**
 * Verb to request an extraction case
 * Players can only have one case at a time
 */
/client/verb/request_extraction_case()
	set name = "Request Extraction Case"
	set category = "IC"

	if(!mob || !isliving(mob))
		to_chat(src, span_warning("You need to be alive to request a case!"))
		return

	var/mob/living/player = mob

	// Check if they already have one
	for(var/obj/item/storage/briefcase/secure/extraction/existing in player.get_all_contents())
		to_chat(src, span_warning("You already have an extraction case!"))
		return

	// Spawn the case
	var/obj/item/storage/briefcase/secure/extraction/extraction_case = new(player.loc)
	if(extraction_case)
		to_chat(src, span_notice("An extraction case has been provided. Store ship parts inside to extract them on bluespace jump or round end!"))
		to_chat(src, span_warning("Warning: This case can be stolen, hacked, or broken into with an EMAG!"))
	else
		to_chat(src, span_warning("Failed to create case. Please try again."))
