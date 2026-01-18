// Intent system keybindings
// Classic SS13 1-2-3-4 intent switching

/datum/keybinding/living/intent
	category = CATEGORY_HUMAN
	weight = WEIGHT_MOB

/datum/keybinding/living/intent/can_use(client/user)
	if(!isliving(user.mob))
		return FALSE
	var/mob/living/L = user.mob
	// Only usable if intent system is enabled
	return !!L.GetComponent(/datum/component/intents)

/datum/keybinding/living/intent/help
	hotkey_keys = list("1")
	name = "intent_help"
	full_name = "Intent: Help"
	description = "Switch to Help intent."
	keybind_signal = COMSIG_KB_LIVING_INTENT_HELP

/datum/keybinding/living/intent/help/down(client/user)
	. = ..()
	if(.)
		return
	var/mob/living/L = user.mob
	var/datum/component/intents/intent_comp = L.GetComponent(/datum/component/intents)
	if(intent_comp)
		intent_comp.set_intent(INTENT_HELP)
	return TRUE

/datum/keybinding/living/intent/disarm
	hotkey_keys = list("2")
	name = "intent_disarm"
	full_name = "Intent: Disarm"
	description = "Switch to Disarm intent."
	keybind_signal = COMSIG_KB_LIVING_INTENT_DISARM

/datum/keybinding/living/intent/disarm/down(client/user)
	. = ..()
	if(.)
		return
	var/mob/living/L = user.mob
	var/datum/component/intents/intent_comp = L.GetComponent(/datum/component/intents)
	if(intent_comp)
		intent_comp.set_intent(INTENT_DISARM)
	return TRUE

/datum/keybinding/living/intent/grab
	hotkey_keys = list("3")
	name = "intent_grab"
	full_name = "Intent: Grab"
	description = "Switch to Grab intent."
	keybind_signal = COMSIG_KB_LIVING_INTENT_GRAB

/datum/keybinding/living/intent/grab/down(client/user)
	. = ..()
	if(.)
		return
	var/mob/living/L = user.mob
	var/datum/component/intents/intent_comp = L.GetComponent(/datum/component/intents)
	if(intent_comp)
		intent_comp.set_intent(INTENT_GRAB)
	return TRUE

/datum/keybinding/living/intent/harm
	hotkey_keys = list("4")
	name = "intent_harm"
	full_name = "Intent: Harm"
	description = "Switch to Harm intent."
	keybind_signal = COMSIG_KB_LIVING_INTENT_HARM

/datum/keybinding/living/intent/harm/down(client/user)
	. = ..()
	if(.)
		return
	var/mob/living/L = user.mob
	var/datum/component/intents/intent_comp = L.GetComponent(/datum/component/intents)
	if(intent_comp)
		intent_comp.set_intent(INTENT_HARM)
	return TRUE
