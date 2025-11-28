/**
 * Custom Slot Spawn Integration
 *
 * Handles applying custom slot configurations when players spawn.
 * - If player has an active slot, uses that slot's saved loadout
 * - If no active slot, uses whatever is in current preferences
 */

/**
 * Get the active custom slot's loadout for a player
 * Returns the loadout list if active slot has one, null otherwise
 *
 * @param ckey - The player's ckey
 * @return List of loadout items or null
 */
/proc/get_active_custom_slot_loadout(ckey)
	if(!ckey || !GLOB.custom_slot_manager)
		return null

	var/list/slot_data = GLOB.custom_slot_manager.get_active_slot(ckey)
	if(!slot_data)
		return null

	var/slot_index = slot_data["slot_index"]

	// Get the loadout for this slot
	var/list/loadout = GLOB.custom_slot_manager.get_slot_loadout(ckey, slot_index)
	if(!loadout || !length(loadout))
		return null

	return loadout
