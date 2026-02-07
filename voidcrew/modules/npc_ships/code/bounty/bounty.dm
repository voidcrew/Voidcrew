/**
 * Bounty - Global competitive bounty for pirate ships
 *
 * Bounties are created for each active pirate ship and can be claimed
 * by multiple player ships simultaneously. First ship to turn in the
 * captain's key wins the bounty reward.
 *
 * Bounties fail when:
 * - The captain's key is destroyed (gibbed, spaced, etc.)
 * - The pirate ship is claimed via helm (not bounty turn-in)
 * - The pirate ship is abandoned (crew all dead, no one claimed)
 */
/datum/pirate_bounty
	/// Display name for the bounty
	var/name = "Unknown Target"

	/// Flavor text description
	var/desc = "Eliminate this target and return their command key."

	/// Credit reward for completing the bounty
	var/reward = 1000

	/// Weak reference to the target pirate ship
	var/datum/weakref/target_ship_ref

	/// Weak reference to the captain's key (proof of kill)
	var/datum/weakref/target_key_ref

	/// List of ships (weakrefs) that have accepted this bounty
	var/list/datum/weakref/claiming_ships = list()

	/// List of ships (weakrefs) that have abandoned this bounty (can't re-accept)
	var/list/datum/weakref/abandoned_by = list()

	/// List of ships (weakrefs) that have purchased tracking for this bounty
	var/list/datum/weakref/tracking_ships = list()

	/// Percentage of reward lost when purchasing tracking (0-100)
	var/tracking_cost_percent = 25

	/// Whether this bounty has been completed
	var/completed = FALSE

	/// Whether this bounty has failed
	var/failed = FALSE

	/// Reason for failure (if failed)
	var/failure_reason = ""

	/// The ship type path (for UI categorization)
	var/ship_type_path

	/// Whether this is a heavy-threat bounty (determines loot quality)
	var/is_heavy_bounty = FALSE

/datum/pirate_bounty/New(obj/structure/overmap/ship/npc/target_ship, obj/item/ship_key/captain_key)
	. = ..()
	if(!target_ship || !captain_key)
		qdel(src)
		return

	// Store references
	target_ship_ref = WEAKREF(target_ship)
	target_key_ref = WEAKREF(captain_key)
	ship_type_path = target_ship.type

	// Generate bounty details from ship
	name = target_ship.name
	desc = "Eliminate the crew of [target_ship.name] and return their command authorization key."
	reward = calculate_reward(target_ship)

	// Register for key destruction signal
	RegisterSignal(captain_key, COMSIG_SHIP_KEY_DESTROYED, PROC_REF(on_key_destroyed))
	RegisterSignal(captain_key, COMSIG_SHIP_KEY_USED, PROC_REF(on_key_used))

	// Register for ship destruction signal
	RegisterSignal(target_ship, COMSIG_SHIP_DESTROYED, PROC_REF(on_ship_destroyed))

/datum/pirate_bounty/Destroy()
	// Remove from global tracking first (prevents memory leak)
	SSbounty?.remove_bounty(src)

	// Unregister signals from key
	var/obj/item/ship_key/key = target_key_ref?.resolve()
	if(key)
		UnregisterSignal(key, list(COMSIG_SHIP_KEY_DESTROYED, COMSIG_SHIP_KEY_USED))

	// Unregister signals from ship
	var/obj/structure/overmap/ship/npc/ship = target_ship_ref?.resolve()
	if(ship)
		UnregisterSignal(ship, COMSIG_SHIP_DESTROYED)

	// Clear references
	target_ship_ref = null
	target_key_ref = null
	claiming_ships.Cut()
	abandoned_by.Cut()
	tracking_ships.Cut()

	return ..()

/**
 * Calculates the reward for a bounty based on the zone the ship is in.
 * Red zone pirates are worth more than yellow zone pirates.
 * Note: Ships are confined to their spawn zone (BB_NPC_SPAWN_ZONE),
 * so the zone at spawn time is the zone for the ship's lifetime.
 */
/datum/pirate_bounty/proc/calculate_reward(obj/structure/overmap/ship/npc/ship)
	// Base reward - yellow zone pirates
	var/base_reward = 5000

	// Red zone pirates are worth significantly more
	var/turf/ship_turf = get_turf(ship)
	var/datum/overmap_zone/zone = SSovermap_zones.get_zone(ship_turf)
	if(zone?.zone_type == ZONE_RED)
		base_reward = 15000
		is_heavy_bounty = TRUE

	// Add some variance (80-120%)
	return round(base_reward * rand(80, 120) / 100)

/**
 * Checks if the bounty is still valid (target exists and not resolved).
 */
/datum/pirate_bounty/proc/is_valid()
	if(completed || failed)
		return FALSE

	var/obj/structure/overmap/ship/npc/ship = target_ship_ref?.resolve()
	if(!ship || QDELETED(ship))
		return FALSE

	var/obj/item/ship_key/key = target_key_ref?.resolve()
	if(!key || QDELETED(key))
		return FALSE

	return TRUE

/**
 * Returns the target ship if it still exists.
 */
/datum/pirate_bounty/proc/get_target_ship()
	return target_ship_ref?.resolve()

/**
 * Returns the target key if it still exists.
 */
/datum/pirate_bounty/proc/get_target_key()
	return target_key_ref?.resolve()

/**
 * Adds a ship to the list of claimants hunting this bounty.
 * @param ship The player ship accepting the bounty
 * @return TRUE if successfully added, FALSE otherwise
 */
/datum/pirate_bounty/proc/add_claimant(obj/structure/overmap/ship/ship)
	if(!is_valid())
		return FALSE
	if(!ship || QDELETED(ship))
		return FALSE

	// Check if already claiming this bounty
	if(is_claimant(ship))
		return FALSE

	// Check if ship abandoned this bounty before
	if(has_abandoned(ship))
		return FALSE

	// Check if ship already has an active bounty (limit: 1 at a time)
	if(SSbounty?.ship_has_active_bounty(ship))
		return FALSE

	claiming_ships += WEAKREF(ship)
	return TRUE

/**
 * Removes a ship from the claimant list (cancelled/abandoned bounty).
 * Ship cannot re-accept this bounty after abandoning.
 * Also cleans up dead weakrefs while iterating.
 * @param ship The player ship cancelling the bounty
 */
/datum/pirate_bounty/proc/remove_claimant(obj/structure/overmap/ship/ship)
	for(var/datum/weakref/ref in claiming_ships)
		var/obj/structure/overmap/ship/resolved = ref.resolve()
		if(!resolved)
			claiming_ships -= ref
			continue
		if(resolved == ship)
			claiming_ships -= ref
			// Mark as abandoned - can't re-accept
			abandoned_by += WEAKREF(ship)
			return TRUE
	return FALSE

/**
 * Checks if a ship has previously abandoned this bounty.
 * Also cleans up dead weakrefs while iterating.
 */
/datum/pirate_bounty/proc/has_abandoned(obj/structure/overmap/ship/ship)
	for(var/datum/weakref/ref in abandoned_by)
		var/obj/structure/overmap/ship/resolved = ref.resolve()
		if(!resolved)
			abandoned_by -= ref
			continue
		if(resolved == ship)
			return TRUE
	return FALSE

/**
 * Checks if a ship is currently hunting this bounty.
 * Also cleans up dead weakrefs while iterating.
 */
/datum/pirate_bounty/proc/is_claimant(obj/structure/overmap/ship/ship)
	for(var/datum/weakref/ref in claiming_ships)
		var/obj/structure/overmap/ship/resolved = ref.resolve()
		if(!resolved)
			claiming_ships -= ref
			continue
		if(resolved == ship)
			return TRUE
	return FALSE

/**
 * Gets the number of ships currently hunting this bounty.
 */
/datum/pirate_bounty/proc/get_hunter_count()
	// Clean up dead refs while counting
	var/count = 0
	for(var/datum/weakref/ref in claiming_ships)
		if(ref.resolve())
			count++
		else
			claiming_ships -= ref
	return count

/**
 * Checks if a ship has tracking enabled for this bounty.
 * Also cleans up dead weakrefs while iterating.
 */
/datum/pirate_bounty/proc/has_tracking(obj/structure/overmap/ship/ship)
	for(var/datum/weakref/ref in tracking_ships)
		var/obj/structure/overmap/ship/resolved = ref.resolve()
		if(!resolved)
			tracking_ships -= ref
			continue
		if(resolved == ship)
			return TRUE
	return FALSE

/**
 * Enables tracking for a ship. Must be hunting this bounty.
 * @param ship The ship purchasing tracking
 * @return TRUE if tracking was enabled, FALSE otherwise
 */
/datum/pirate_bounty/proc/enable_tracking(obj/structure/overmap/ship/ship)
	if(!is_valid())
		return FALSE
	if(!ship || QDELETED(ship))
		return FALSE
	// Must be hunting this bounty
	if(!is_claimant(ship))
		return FALSE
	// Already has tracking
	if(has_tracking(ship))
		return FALSE

	tracking_ships += WEAKREF(ship)
	return TRUE

/**
 * Gets the credit cost for enabling tracking.
 * This is the amount that will be deducted from the reward.
 */
/datum/pirate_bounty/proc/get_tracking_cost()
	return round(reward * tracking_cost_percent / 100)

/**
 * Gets the reward for a specific ship, accounting for tracking penalty.
 * @param ship The ship to calculate reward for
 * @return The adjusted reward amount
 */
/datum/pirate_bounty/proc/get_reward_for_ship(obj/structure/overmap/ship/ship)
	if(has_tracking(ship))
		return reward - get_tracking_cost()
	return reward

/**
 * Checks if a key can be turned in for this bounty.
 * @param key The ship key being turned in
 * @param turner The ship attempting to turn in
 * @return TRUE if valid turn-in, FALSE otherwise
 */
/datum/pirate_bounty/proc/can_turn_in(obj/item/ship_key/key, obj/structure/overmap/ship/turner)
	if(!is_valid())
		return FALSE

	// Key must match our target
	if(key != target_key_ref?.resolve())
		return FALSE

	// Turner must have accepted this bounty
	if(!is_claimant(turner))
		return FALSE

	return TRUE

/**
 * Completes the bounty, awarding the winner.
 * @param winner The ship that turned in the key
 * @param pad Optional mission pad to spawn item rewards on
 * @return The reward amount awarded
 */
/datum/pirate_bounty/proc/complete(obj/structure/overmap/ship/winner, obj/machinery/mission_pad/pad)
	if(completed || failed)
		return 0

	completed = TRUE

	// Award credits to winning ship (reduced if they used tracking)
	var/actual_reward = get_reward_for_ship(winner)
	if(winner)
		winner.ship_account.adjust_money(actual_reward)

	// Spawn item rewards on mission pad
	var/list/item_rewards = list()
	if(pad)
		var/turf/spawn_turf = get_turf(pad)
		if(spawn_turf)
			item_rewards = spawn_bounty_loot(spawn_turf)
			pad.do_teleport_effect()

	// Build reward announcement
	var/reward_text = "[actual_reward] credits"
	if(length(item_rewards))
		reward_text += " + [english_list(item_rewards)]"

	if(winner)
		winner.ship_notify("BOUNTY COMPLETE: [name] - [reward_text] awarded!", "MISSION CONTROL", SHIP_NOTIFY_NOTICE, 'voidcrew/sound/notify.ogg', 50)

	// Notify other claimants of failure
	for(var/datum/weakref/ref in claiming_ships)
		var/obj/structure/overmap/ship/loser = ref.resolve()
		if(loser && loser != winner)
			loser.ship_notify("BOUNTY FAILED: [name] - Another crew claimed the bounty.", "MISSION CONTROL", SHIP_NOTIFY_WARNING, 'voidcrew/sound/warn4.ogg', 25)

	// Remove from global tracker
	SSbounty?.remove_bounty(src)

	return actual_reward

/**
 * Returns a human-readable description of the loot this bounty will award.
 * Used by the bounty console UI to show expected rewards.
 */
/datum/pirate_bounty/proc/get_loot_description()
	if(is_heavy_bounty)
		return "2 heavy missiles, weapon cache, [BOUNTY_HEAVY_SHIP_PARTS] ship parts"
	return "2 missiles, weapon cache, [BOUNTY_LIGHT_SHIP_PARTS] ship part[BOUNTY_LIGHT_SHIP_PARTS > 1 ? "s" : ""]"

/**
 * Spawns bounty loot at the given location.
 * Light bounties: 2 standard missiles + basic weapon crate + 1 ship part
 * Heavy bounties: 2 heavy missiles + premium weapon crate + 3 ship parts
 * Ship parts are 70% combat, 30% misc.
 * @param spawn_loc The turf to spawn items on
 * @return List of item names spawned (for announcement)
 */
/datum/pirate_bounty/proc/spawn_bounty_loot(turf/spawn_loc)
	var/list/spawned_items = list()

	if(!spawn_loc)
		return spawned_items

	// Spawn missiles based on bounty type
	if(is_heavy_bounty)
		// Heavy bounty: 2 armed heavy missiles
		new /obj/structure/ship_missile/armed/heavy(spawn_loc)
		new /obj/structure/ship_missile/armed/heavy(spawn_loc)
		spawned_items += "2 heavy missiles"
	else
		// Light bounty: 2 armed standard missiles
		new /obj/structure/ship_missile/armed/standard(spawn_loc)
		new /obj/structure/ship_missile/armed/standard(spawn_loc)
		spawned_items += "2 missiles"

	// Spawn loot crate based on bounty type
	var/crate_type
	if(is_heavy_bounty)
		// Heavy bounty: premium weapon crate
		var/static/list/heavy_loot_crates = list(
			/obj/structure/closet/crate/secure/weapon/pirate_loot/heavy/energy_guns,
			/obj/structure/closet/crate/secure/weapon/pirate_loot/heavy/combat_shotguns,
			/obj/structure/closet/crate/secure/weapon/pirate_loot/heavy/laser_carbines,
			/obj/structure/closet/crate/secure/weapon/pirate_loot/heavy/swat,
			/obj/structure/closet/crate/secure/weapon/pirate_loot/heavy/riot,
			/obj/structure/closet/crate/secure/weapon/pirate_loot/heavy/incendiary,
		)
		crate_type = pick(heavy_loot_crates)
	else
		// Light bounty: basic weapon crate
		var/static/list/light_loot_crates = list(
			/obj/structure/closet/crate/secure/weapon/pirate_loot/lasers,
			/obj/structure/closet/crate/secure/weapon/pirate_loot/disablers,
			/obj/structure/closet/crate/secure/weapon/pirate_loot/armor,
			/obj/structure/closet/crate/secure/weapon/pirate_loot/batons,
			/obj/structure/closet/crate/secure/weapon/pirate_loot/supplies,
		)
		crate_type = pick(light_loot_crates)

	var/obj/structure/closet/crate/spawned_crate = new crate_type(spawn_loc)
	spawned_items += spawned_crate.name

	// Spawn ship parts loose on pad (players must collect and store in extraction briefcase)
	var/part_count = is_heavy_bounty ? BOUNTY_HEAVY_SHIP_PARTS : BOUNTY_LIGHT_SHIP_PARTS
	var/static/list/bounty_part_types = list(
		/obj/item/ship_parts/combat = 70,
		/obj/item/ship_parts/misc = 30,
	)
	for(var/i in 1 to part_count)
		var/part_type = pick_weight(bounty_part_types)
		new part_type(spawn_loc)
	spawned_items += "[part_count] ship part[part_count > 1 ? "s" : ""]"

	return spawned_items

/**
 * Fails the bounty for all claimants.
 * @param reason The reason for failure
 */
/datum/pirate_bounty/proc/fail(reason)
	if(completed || failed)
		return

	failed = TRUE
	failure_reason = reason

	// Notify all claimants
	for(var/datum/weakref/ref in claiming_ships)
		var/obj/structure/overmap/ship/ship = ref.resolve()
		if(ship)
			ship.ship_notify("BOUNTY FAILED: [name] - [reason]", "MISSION CONTROL", SHIP_NOTIFY_WARNING, 'voidcrew/sound/warn4.ogg', 25)

	// Remove from global tracker
	SSbounty?.remove_bounty(src)

// ========== SIGNAL HANDLERS ==========

/**
 * Signal handler for when the target key is destroyed.
 * Fails the bounty for all claimants.
 */
/datum/pirate_bounty/proc/on_key_destroyed(obj/item/ship_key/source, obj/structure/overmap/ship/npc/ship, reason)
	SIGNAL_HANDLER

	// Different failure messages based on reason
	var/fail_message
	switch(reason)
		if(KEY_DESTROYED_CLAIMED)
			// Don't fail here - on_key_used handles this
			return
		if(KEY_DESTROYED_BOUNTY)
			// This shouldn't happen (key turned in = completed, not destroyed)
			return
		else
			fail_message = "Target's command key was destroyed."

	fail(fail_message)

/**
 * Signal handler for when the key is used to claim the ship (not bounty turn-in).
 * This means someone claimed the ship directly without completing the bounty.
 */
/datum/pirate_bounty/proc/on_key_used(obj/item/ship_key/source, obj/structure/overmap/ship/npc/ship, mob/claimer)
	SIGNAL_HANDLER

	// If someone claimed the ship via helm, the bounty fails
	// (They took the ship as loot instead of turning in the key)
	fail("Target ship was claimed by another crew.")

/**
 * Signal handler for when the target ship is destroyed.
 * The bounty fails since the ship (and likely the key) is gone.
 */
/datum/pirate_bounty/proc/on_ship_destroyed(datum/source)
	SIGNAL_HANDLER

	fail("Target vessel was destroyed.")
