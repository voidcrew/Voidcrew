/**
 * Ship Parts Keybinding - Rarity-Based System
 *
 * Allows players to withdraw physical ship parts from their database account.
 */
/datum/keybinding/carbon/remove_ship_part
	hotkey_keys = list("N")
	name = "takeshippart"
	full_name = "Take ship part"
	description = "Withdraw ship parts from your account."
	keybind_signal = COMSIG_KB_CARBON_TAKESHIPPART_DOWN

/datum/keybinding/carbon/remove_ship_part/down(client/user)
	. = ..()
	if(.)
		return

	if(!isliving(user.mob))
		return FALSE

	// Get list of owned parts from database
	var/list/owned_parts = user.get_ships()
	if(!owned_parts)
		return FALSE

	// Show current inventory
	user.list_ship_parts()

	// Let player select which rarity to withdraw
	var/part_response = tgui_input_list(user, "Select a ship part rarity to withdraw.", "Ship Parts", owned_parts)
	if(!part_response || !owned_parts[part_response])
		return FALSE

	var/selected_rarity = owned_parts[part_response]

	// Withdraw the part
	return user.withdraw_ship_part(selected_rarity)
