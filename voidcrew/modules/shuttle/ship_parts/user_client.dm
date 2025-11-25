/**
 * Ship Parts Client Procs - Database-backed Rarity System
 *
 * These procs manage ship parts and credits for players.
 * Parts are stored in the database via GLOB.ship_economy_db
 *
 * Economy Model:
 * - CREDITS: Earned at round-end, spent on ships
 * - PARTS: Found in-game (exploration/loot) or from Battlepass rewards
 */

/// Base credits awarded at round end
#define ROUND_END_BASE_CREDITS 100

/**
 * Gives credits at round end
 * Parts are NOT given at round-end - they come from in-game loot and battlepass
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
	for(var/rarity in GLOB.ship_part_rarities)
		var/count = parts[rarity] || 0
		if(count > 0)
			to_chat(src, span_notice("  [count] [rarity]"))
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
	for(var/rarity in GLOB.ship_part_rarities)
		var/count = parts[rarity] || 0
		if(count > 0)
			to_chat(usr, span_boldwarning("[count] [rarity]"))
			total += count

	if(total == 0)
		to_chat(usr, span_notice("You do not have any ship parts."))

/**
 * Returns a list of owned ship parts for use in UI selection
 * Returns list in format: "rarity - X owned" = rarity
 */
/client/proc/get_ships()
	if(!ckey)
		return FALSE

	var/list/parts = GLOB.ship_economy_db?.get_parts(ckey)
	if(!parts)
		to_chat(src, span_notice("Unable to retrieve your parts inventory."))
		return FALSE

	var/list/owned_parts = list()
	for(var/rarity in GLOB.ship_part_rarities)
		var/count = parts[rarity] || 0
		if(count > 0)
			owned_parts["[rarity] - [count] owned"] = rarity

	if(!length(owned_parts))
		to_chat(src, span_notice("You do not have any ship parts."))
		return FALSE

	return owned_parts

/**
 * Withdraw a physical ship part item from account
 * @param rarity - The rarity of part to withdraw
 * @return TRUE if successful
 */
/client/proc/withdraw_ship_part(rarity)
	if(!ckey || !rarity)
		return FALSE

	if(!(rarity in GLOB.ship_part_rarities))
		to_chat(src, span_warning("Invalid part rarity!"))
		return FALSE

	// Check if player has the part
	var/list/parts = GLOB.ship_economy_db?.get_parts(ckey)
	if(!parts || (parts[rarity] || 0) < 1)
		to_chat(src, span_warning("You don't have any [rarity] parts to withdraw!"))
		return FALSE

	// Deduct from database
	var/list/requirements = list()
	requirements[rarity] = 1
	if(!GLOB.ship_economy_db?.spend_parts(ckey, requirements))
		to_chat(src, span_warning("Failed to withdraw part. Please try again."))
		return FALSE

	// Spawn the physical item
	var/obj/item/ship_parts/part_item
	switch(rarity)
		if(RARITY_COMMON)
			part_item = new /obj/item/ship_parts/common(mob.loc)
		if(RARITY_UNCOMMON)
			part_item = new /obj/item/ship_parts/uncommon(mob.loc)
		if(RARITY_RARE)
			part_item = new /obj/item/ship_parts/rare(mob.loc)
		if(RARITY_EPIC)
			part_item = new /obj/item/ship_parts/epic(mob.loc)
		if(RARITY_LEGENDARY)
			part_item = new /obj/item/ship_parts/legendary(mob.loc)

	if(part_item)
		to_chat(src, span_notice("Withdrawn one [rarity] ship part."))
		return TRUE

	return FALSE
