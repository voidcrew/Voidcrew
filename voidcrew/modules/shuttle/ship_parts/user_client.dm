/**
 * Ship Parts Client Procs - Database-backed Rarity System
 *
 * These procs manage ship parts for players.
 * Parts are stored in the database via GLOB.ship_economy_db
 */

/// Rarity weights for random part distribution (higher = more common)
#define RARITY_WEIGHT_COMMON 50
#define RARITY_WEIGHT_UNCOMMON 30
#define RARITY_WEIGHT_RARE 15
#define RARITY_WEIGHT_EPIC 4
#define RARITY_WEIGHT_LEGENDARY 1

/**
 * Gives a random ship part based on weighted rarity distribution
 * Called at round end to reward players
 */
/client/proc/give_random_ship_part()
	if(!ckey)
		return

	// Weighted random selection
	var/list/rarity_weights = list(
		RARITY_COMMON = RARITY_WEIGHT_COMMON,
		RARITY_UNCOMMON = RARITY_WEIGHT_UNCOMMON,
		RARITY_RARE = RARITY_WEIGHT_RARE,
		RARITY_EPIC = RARITY_WEIGHT_EPIC,
		RARITY_LEGENDARY = RARITY_WEIGHT_LEGENDARY
	)

	var/selected_rarity = pick_weight(rarity_weights)

	// Add to database
	if(GLOB.ship_economy_db?.add_part(ckey, selected_rarity, 1, "round_end_reward"))
		to_chat(usr, span_notice("You have received a [selected_rarity] ship part as a round reward!"))
	else
		to_chat(usr, span_warning("Failed to receive your ship part reward. It will be queued for later."))
		GLOB.ship_economy_db?.queue_pending_extraction(ckey, selected_rarity, "round_end_[world.realtime]")

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
