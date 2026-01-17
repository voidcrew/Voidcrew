// Intent system HUD integration
// Handles swapping between combat toggle and intent selector

/// Intent selector screen reference
/datum/hud
	var/atom/movable/screen/intent_selector/intent_selector

/// Swaps from combat toggle to intent selector HUD
/// Returns the intent selector for further setup
/datum/hud/proc/swap_to_intent_hud()
	if(!mymob)
		return null

	// Already using intent HUD
	if(intent_selector)
		return intent_selector

	// Remove combat toggle from screen and static inventory
	if(action_intent)
		if(mymob.client)
			mymob.client.screen -= action_intent
		static_inventory -= action_intent

	// Create and add intent selector
	intent_selector = new /atom/movable/screen/intent_selector(null, src)
	intent_selector.screen_loc = ui_combat_toggle
	static_inventory += intent_selector

	if(mymob.client)
		mymob.client.screen += intent_selector

	return intent_selector

/// Swaps from intent selector to combat toggle HUD
/datum/hud/proc/swap_to_combat_hud()
	if(!mymob)
		return

	// Already using combat HUD
	if(!intent_selector)
		return

	// Remove intent selector from screen and static inventory
	if(mymob.client)
		mymob.client.screen -= intent_selector
	static_inventory -= intent_selector
	QDEL_NULL(intent_selector)

	// Restore combat toggle
	if(action_intent)
		static_inventory += action_intent
		if(mymob.client)
			mymob.client.screen += action_intent
