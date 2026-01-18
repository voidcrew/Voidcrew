// Intent system integration
// Login hooks to apply intent preference and set up the system

/mob/living/carbon/human/Login()
	. = ..()
	if(!.)
		return

	// Check if player prefers intent system
	if(!client?.prefs)
		return

	var/use_intents = client.prefs.read_preference(/datum/preference/toggle/use_intents)
	if(use_intents)
		enable_intent_system()
	else
		disable_intent_system()

/// Enables the intent system for this mob
/mob/living/carbon/human/proc/enable_intent_system()
	// Add the intent component if not already present
	var/datum/component/intents/intent_comp = GetComponent(/datum/component/intents)
	if(!intent_comp)
		intent_comp = AddComponent(/datum/component/intents)

	// Swap HUD to intent selector
	if(hud_used)
		var/atom/movable/screen/intent_selector/selector = hud_used.swap_to_intent_hud()
		if(selector && intent_comp)
			selector.intent_component = intent_comp
			intent_comp.intent_hud = selector
			selector.update_appearance()

/// Disables the intent system for this mob
/mob/living/carbon/human/proc/disable_intent_system()
	// Remove the intent component
	var/datum/component/intents/intent_comp = GetComponent(/datum/component/intents)
	if(intent_comp)
		if(intent_comp.intent_hud)
			intent_comp.intent_hud.intent_component = null
			intent_comp.intent_hud = null
		qdel(intent_comp)

	// Swap HUD back to combat toggle
	if(hud_used)
		hud_used.swap_to_combat_hud()
