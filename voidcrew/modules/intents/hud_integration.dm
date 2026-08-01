// Intent system HUD integration
// Handles swapping between combat toggle and intent selector
//
// Upstream reworked the HUD registry: screen elements are no longer poked into the
// `static_inventory`/`hotkeybuttons` lists and `client.screen` by hand, they are
// registered through add_screen_object()/remove_screen_object() under a hud key and a
// screen group, and show_hud() rebuilds client.screen from those groups. The combat
// toggle lives at the HUD_MOB_INTENTS key (see code/_onclick/hud/human.dm), so the
// intent selector takes that same slot rather than being bolted on beside it.

/// Intent selector screen reference
/datum/hud
	var/atom/movable/screen/intent_selector/intent_selector
	/// How the combat toggle we displaced was registered, so swap_to_combat_hud() can rebuild it verbatim.
	var/stored_combat_toggle_type
	var/stored_combat_toggle_group
	var/stored_combat_toggle_icon
	var/stored_combat_toggle_loc

/// Swaps from combat toggle to intent selector HUD
/// Returns the intent selector for further setup
/datum/hud/proc/swap_to_intent_hud()
	if(!mymob)
		return null

	// Already using intent HUD
	if(intent_selector)
		return intent_selector

	// Displace the combat toggle, remembering how it was registered.
	// remove_screen_object() qdels it, and /atom/movable/screen/Destroy() deregisters it
	// from both screen_objects and its screen group for us.
	var/group_key = HUD_GROUP_INFO
	var/screen_location = ui_acti
	var/atom/movable/screen/combattoggle/combat_toggle = screen_objects[HUD_MOB_INTENTS]
	if(istype(combat_toggle))
		stored_combat_toggle_type = combat_toggle.type
		stored_combat_toggle_group = combat_toggle.hud_group_key || HUD_GROUP_INFO
		stored_combat_toggle_icon = combat_toggle.icon
		// default_screen_location is the un-minimised position; screen_loc may currently be
		// ui_acti_alt if the HUD is in its reduced style.
		stored_combat_toggle_loc = combat_toggle.default_screen_location || combat_toggle.screen_loc
		group_key = stored_combat_toggle_group
		screen_location = stored_combat_toggle_loc
		remove_screen_object(combat_toggle, update = FALSE)

	// Create and add intent selector in its place.
	// ui_icon is deliberately left null: the selector ships its own icon sheet and must not
	// be repainted with the player's ui_style sheet the way the combat toggle is.
	intent_selector = add_screen_object(/atom/movable/screen/intent_selector, HUD_MOB_INTENTS, group_key, ui_loc = screen_location, update_screen = TRUE)

	return intent_selector

/// Swaps from intent selector to combat toggle HUD
/datum/hud/proc/swap_to_combat_hud()
	if(!mymob)
		return

	// Already using combat HUD
	if(!intent_selector)
		return

	// Remove intent selector (qdel deregisters it from screen_objects/screen_groups)
	remove_screen_object(intent_selector, update = FALSE)
	intent_selector = null

	// Restore combat toggle exactly as it was registered
	if(stored_combat_toggle_type)
		add_screen_object(stored_combat_toggle_type, HUD_MOB_INTENTS, stored_combat_toggle_group, stored_combat_toggle_icon, stored_combat_toggle_loc)
		stored_combat_toggle_type = null
		stored_combat_toggle_group = null
		stored_combat_toggle_icon = null
		stored_combat_toggle_loc = null

	show_hud(hud_version)
