/**
 * Bounty Subsystem
 *
 * Manages global bounties for pirate ships. Bounties are created when
 * pirates spawn and tracked until completed or failed.
 */
SUBSYSTEM_DEF(bounty)
	name = "Bounty"
	init_order = INIT_ORDER_OVERMAP + 3  // After NPC ships spawn
	flags = SS_NO_FIRE  // No periodic firing - event-driven
	runlevels = RUNLEVEL_GAME
	dependencies = list(
		/datum/controller/subsystem/npc_ships,  // Pirates must exist before we create bounties
	)

	/// List of all active bounties
	var/list/datum/pirate_bounty/active_bounties = list()

	/// List of all player-created bounties
	var/list/datum/player_bounty/player_bounties = list()

	/// Whether initial bounties have been generated
	var/bounties_initialized = FALSE

/datum/controller/subsystem/bounty/Initialize()
	// SSnpc_ships is a dependency, so pirates are already spawned
	// Generate bounties for all existing pirates
	generate_initial_bounties()
	bounties_initialized = TRUE
	return SS_INIT_SUCCESS

/**
 * Generates bounties for all currently active pirates.
 * Called to create bounties for any pirates that already exist.
 */
/datum/controller/subsystem/bounty/proc/generate_initial_bounties()
	var/count = 0
	for(var/obj/structure/overmap/ship/npc/ship in SSnpc_ships.active_ships)
		if(create_bounty_for_ship(ship))
			count++

	log_world("SSbounty: Generated [count] bounties for existing pirates")

/**
 * Creates a bounty for a specific pirate ship.
 * @param ship The NPC ship to create a bounty for
 * @return The created bounty or null on failure
 */
/datum/controller/subsystem/bounty/proc/create_bounty_for_ship(obj/structure/overmap/ship/npc/ship)
	if(!ship || QDELETED(ship))
		return null

	// Find the captain's key on this ship
	var/obj/item/ship_key/key = find_ship_key(ship)
	if(!key)
		log_world("SSbounty: No key found for [ship.name], skipping bounty creation")
		return null

	// Check if bounty already exists for this ship
	var/datum/pirate_bounty/existing = get_bounty_for_ship(ship)
	if(existing)
		return existing

	// Create the bounty
	var/datum/pirate_bounty/new_bounty = new(ship, key)
	if(QDELETED(new_bounty))
		return null

	active_bounties += new_bounty
	log_world("SSbounty: Created bounty for [ship.name] worth [new_bounty.reward] credits")

	return new_bounty

/**
 * Finds the captain's key aboard an NPC ship.
 */
/datum/controller/subsystem/bounty/proc/find_ship_key(obj/structure/overmap/ship/npc/ship)
	if(!ship?.shuttle?.shuttle_areas)
		return null

	// Search all areas of the ship
	for(var/area/shuttle_area as anything in ship.shuttle.shuttle_areas)
		// Check for keys on the ground
		for(var/obj/item/ship_key/key in shuttle_area)
			if(key.get_ship() == ship)
				return key

		// Check for keys held by mobs
		for(var/mob/living/L in shuttle_area)
			for(var/obj/item/ship_key/key in L.contents)
				if(key.get_ship() == ship)
					return key

	return null

/**
 * Gets the bounty for a specific ship.
 * @param ship The ship to look up
 * @return The bounty or null if none exists
 */
/datum/controller/subsystem/bounty/proc/get_bounty_for_ship(obj/structure/overmap/ship/npc/ship)
	for(var/datum/pirate_bounty/bounty in active_bounties)
		if(bounty.get_target_ship() == ship)
			return bounty
	return null

/**
 * Gets the bounty that matches a specific key.
 * @param key The ship key to match
 * @return The bounty or null if none matches
 */
/datum/controller/subsystem/bounty/proc/get_bounty_for_key(obj/item/ship_key/key)
	for(var/datum/pirate_bounty/bounty in active_bounties)
		if(bounty.get_target_key() == key)
			return bounty
	return null

/**
 * Gets all active (valid) bounties.
 * Cleans up invalid bounties while iterating.
 */
/datum/controller/subsystem/bounty/proc/get_all_bounties()
	var/list/valid = list()
	for(var/datum/pirate_bounty/bounty in active_bounties)
		if(bounty.is_valid())
			valid += bounty
		else if(!bounty.completed && !bounty.failed)
			// Invalid but not explicitly resolved - clean up
			bounty.fail("Target no longer available.")
	return valid

/**
 * Gets bounties that a specific ship has accepted.
 * @param ship The player ship to check
 */
/datum/controller/subsystem/bounty/proc/get_bounties_for_claimant(obj/structure/overmap/ship/ship)
	var/list/claimed = list()
	for(var/datum/pirate_bounty/bounty in active_bounties)
		if(bounty.is_valid() && bounty.is_claimant(ship))
			claimed += bounty
	return claimed

/**
 * Checks if a ship already has an active bounty.
 * Ships can only hunt one bounty at a time.
 */
/datum/controller/subsystem/bounty/proc/ship_has_active_bounty(obj/structure/overmap/ship/ship)
	for(var/datum/pirate_bounty/bounty in active_bounties)
		if(bounty.is_valid() && bounty.is_claimant(ship))
			return TRUE
	return FALSE

/**
 * Removes a bounty from tracking (called by bounty on complete/fail).
 */
/datum/controller/subsystem/bounty/proc/remove_bounty(datum/bounty/bounty)
	active_bounties -= bounty

/**
 * Called by SSnpc_ships when a new pirate spawns.
 * Creates a bounty for the new ship after a short delay.
 */
/datum/controller/subsystem/bounty/proc/on_pirate_spawned(obj/structure/overmap/ship/npc/ship)
	// During SSbounty initialization, bounties are created via generate_initial_bounties()
	if(!bounties_initialized)
		return

	// For replacement pirates spawned after init, create bounty with delay for ship to fully load
	addtimer(CALLBACK(src, PROC_REF(create_bounty_for_ship), ship), 2 SECONDS)

// ========== UI DATA HELPERS ==========

/**
 * Gets bounty data formatted for TGUI.
 * @param for_ship Optional - if provided, includes whether this ship is hunting each bounty
 */
/datum/controller/subsystem/bounty/proc/get_bounty_ui_data(obj/structure/overmap/ship/for_ship = null)
	var/list/data = list()

	for(var/datum/pirate_bounty/bounty in get_all_bounties())
		var/list/bounty_data = list(
			"name" = bounty.name,
			"desc" = bounty.desc,
			"reward" = bounty.reward,
			"hunter_count" = bounty.get_hunter_count(),
			"ref" = REF(bounty),
			"tracking_cost" = bounty.get_tracking_cost(),
			"loot_description" = bounty.get_loot_description(),
		)

		// Add ship-specific data
		if(for_ship)
			bounty_data["is_hunting"] = bounty.is_claimant(for_ship)
			bounty_data["was_abandoned"] = bounty.has_abandoned(for_ship)
			bounty_data["has_tracking"] = bounty.has_tracking(for_ship)
			// Calculate reward this ship would get (accounting for tracking)
			bounty_data["effective_reward"] = bounty.get_reward_for_ship(for_ship)

		// Add target location hint (zone)
		var/obj/structure/overmap/ship/npc/target = bounty.get_target_ship()
		if(target)
			var/zone_type = SSovermap_zones?.get_zone_for_atom(target)
			bounty_data["zone"] = zone_type || "Unknown"

			// If ship has tracking enabled, include real-time coordinates
			if(for_ship && bounty.has_tracking(for_ship))
				var/turf/target_turf = get_turf(target)
				if(target_turf)
					bounty_data["target_x"] = target_turf.x
					// Convert absolute Y to relative overmap coordinate (1-based)
					bounty_data["target_y"] = target_turf.y - OVERMAP_SOUTH_SIDE_COORD + 1

		data += list(bounty_data)

	return data

// ========== PLAYER BOUNTY MANAGEMENT ==========

/**
 * Creates a new player bounty.
 * @param creator_ship The ship creating the bounty
 * @param creator_pad The mission pad linked to the creator's console
 * @param reward_amount The credit reward offered
 * @return The created bounty or null on failure
 */
/datum/controller/subsystem/bounty/proc/create_player_bounty(obj/structure/overmap/ship/creator_ship, obj/machinery/mission_pad/creator_pad, reward_amount)
	if(!creator_ship || QDELETED(creator_ship))
		return null

	// Check if ship already has an active bounty
	if(ship_has_active_player_bounty(creator_ship))
		return null

	// Check if ship has sufficient funds
	if(!creator_ship.ship_account || creator_ship.ship_account.account_balance < reward_amount)
		return null

	// Deduct reward from creator (escrow)
	creator_ship.ship_account.adjust_money(-reward_amount)

	var/datum/player_bounty/new_bounty = new(creator_ship, creator_pad, reward_amount)
	if(QDELETED(new_bounty))
		// Refund on failure
		creator_ship.ship_account.adjust_money(reward_amount)
		return null

	player_bounties += new_bounty
	return new_bounty

/**
 * Removes a player bounty from tracking.
 */
/datum/controller/subsystem/bounty/proc/remove_player_bounty(datum/player_bounty/bounty)
	player_bounties -= bounty

/**
 * Gets all valid player bounties.
 */
/datum/controller/subsystem/bounty/proc/get_all_player_bounties()
	var/list/valid = list()
	for(var/datum/player_bounty/bounty in player_bounties)
		if(bounty.is_valid())
			valid += bounty
		else if(bounty.status == "available")
			// Invalid but not resolved - cancel it
			bounty.cancel()
	return valid

/**
 * Checks if a ship has created an active player bounty.
 */
/datum/controller/subsystem/bounty/proc/ship_has_active_player_bounty(obj/structure/overmap/ship/ship)
	for(var/datum/player_bounty/bounty in player_bounties)
		if(bounty.get_creator_ship() == ship && bounty.status == "available")
			return TRUE
	return FALSE

/**
 * Checks if a ship is hunting (has claimed) a player bounty.
 */
/datum/controller/subsystem/bounty/proc/ship_has_claimed_player_bounty(obj/structure/overmap/ship/ship)
	for(var/datum/player_bounty/bounty in player_bounties)
		if(bounty.status == "available" && bounty.is_claimant(ship))
			return TRUE
	return FALSE

/**
 * Gets the player bounty a ship has created.
 */
/datum/controller/subsystem/bounty/proc/get_ship_created_bounty(obj/structure/overmap/ship/ship)
	for(var/datum/player_bounty/bounty in player_bounties)
		if(bounty.get_creator_ship() == ship && bounty.status == "available")
			return bounty
	return null

/**
 * Gets the player bounty a ship is hunting.
 */
/datum/controller/subsystem/bounty/proc/get_ship_claimed_bounty(obj/structure/overmap/ship/ship)
	for(var/datum/player_bounty/bounty in player_bounties)
		if(bounty.status == "available" && bounty.is_claimant(ship))
			return bounty
	return null

/**
 * Gets player bounty data formatted for TGUI.
 * @param for_ship The ship to include relationship data for
 */
/datum/controller/subsystem/bounty/proc/get_player_bounty_ui_data(obj/structure/overmap/ship/for_ship)
	var/list/data = list()

	for(var/datum/player_bounty/bounty in get_all_player_bounties())
		data += list(bounty.get_ui_data(for_ship))

	return data
