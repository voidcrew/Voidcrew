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

	/// List of all active bounties
	var/list/datum/pirate_bounty/active_bounties = list()

	/// Whether initial bounties have been generated
	var/bounties_initialized = FALSE

/datum/controller/subsystem/bounty/Initialize()
	// Generate bounties after a delay to let pirates spawn
	addtimer(CALLBACK(src, PROC_REF(generate_initial_bounties)), 6 SECONDS)
	return SS_INIT_SUCCESS

/**
 * Generates bounties for all currently active pirates.
 * Called after pirate spawning is complete.
 */
/datum/controller/subsystem/bounty/proc/generate_initial_bounties()
	if(bounties_initialized)
		return

	for(var/obj/structure/overmap/ship/npc/ship in SSnpc_ships.active_ships)
		create_bounty_for_ship(ship)

	bounties_initialized = TRUE
	log_world("SSbounty: Generated [length(active_bounties)] initial bounties")

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
 * Removes a bounty from tracking (called by bounty on complete/fail).
 */
/datum/controller/subsystem/bounty/proc/remove_bounty(datum/bounty/bounty)
	active_bounties -= bounty

/**
 * Called by SSnpc_ships when a new pirate spawns.
 * Creates a bounty for the new ship.
 */
/datum/controller/subsystem/bounty/proc/on_pirate_spawned(obj/structure/overmap/ship/npc/ship)
	if(!bounties_initialized)
		return  // Will be handled by generate_initial_bounties

	// Small delay to let the ship fully initialize (key spawns with captain)
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
		)

		// Add ship-specific data
		if(for_ship)
			bounty_data["is_hunting"] = bounty.is_claimant(for_ship)

		// Add target location hint (zone)
		var/obj/structure/overmap/ship/npc/target = bounty.get_target_ship()
		if(target)
			var/zone_type = SSovermap_zones?.get_zone_for_atom(target)
			bounty_data["zone"] = zone_type || "Unknown"

		data += list(bounty_data)

	return data
