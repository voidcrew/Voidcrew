// Intent system component
// Handles intent state and click interception for classic SS13 intents

/datum/component/intents
	/// The current intent
	var/current_intent = INTENT_HELP
	/// Reference to the HUD intent selector, if any
	var/atom/movable/screen/intent_selector/intent_hud

/datum/component/intents/Initialize()
	if(!isliving(parent))
		return COMPONENT_INCOMPATIBLE
	var/mob/living/owner = parent
	// Start with help intent, combat mode off
	set_intent(INTENT_HELP)
	RegisterSignal(owner, COMSIG_LIVING_UNARMED_ATTACK, PROC_REF(on_unarmed_attack))
	RegisterSignal(owner, COMSIG_LIVING_GRAB, PROC_REF(on_grab_attempt))
	// Intercept combat mode keybinds to prevent them from bypassing intents
	RegisterSignal(owner, COMSIG_KB_LIVING_TOGGLE_COMBAT_DOWN, PROC_REF(on_toggle_combat))
	RegisterSignal(owner, COMSIG_KB_LIVING_ENABLE_COMBAT_DOWN, PROC_REF(on_enable_combat))
	RegisterSignal(owner, COMSIG_KB_LIVING_DISABLE_COMBAT_DOWN, PROC_REF(on_disable_combat))

/datum/component/intents/Destroy()
	if(intent_hud)
		intent_hud = null
	return ..()

/datum/component/intents/UnregisterFromParent()
	var/mob/living/owner = parent
	if(owner)
		UnregisterSignal(owner, list(
			COMSIG_LIVING_UNARMED_ATTACK,
			COMSIG_LIVING_GRAB,
			COMSIG_KB_LIVING_TOGGLE_COMBAT_DOWN,
			COMSIG_KB_LIVING_ENABLE_COMBAT_DOWN,
			COMSIG_KB_LIVING_DISABLE_COMBAT_DOWN,
		))

/// Sets the current intent and syncs combat mode
/datum/component/intents/proc/set_intent(new_intent)
	current_intent = new_intent
	var/mob/living/owner = parent
	if(!owner)
		return

	// Sync combat mode based on intent
	// Help = combat mode off, all others = combat mode on
	var/should_be_combat = (new_intent != INTENT_HELP)
	if(owner.combat_mode != should_be_combat)
		owner.set_combat_mode(should_be_combat, silent = TRUE)

	// Update HUD if we have one
	if(intent_hud)
		intent_hud.update_appearance()

/// Cycles to the next intent in order
/datum/component/intents/proc/cycle_intent()
	var/list/cycle_order = INTENT_CYCLE_ORDER
	var/current_index = cycle_order.Find(current_intent)
	if(!current_index)
		current_index = 1
	var/next_index = (current_index % length(cycle_order)) + 1
	set_intent(cycle_order[next_index])

/// Signal handler for COMSIG_LIVING_UNARMED_ATTACK
/// Intercepts unarmed attacks and translates based on current intent
/datum/component/intents/proc/on_unarmed_attack(mob/living/source, atom/target, proximity, modifiers)
	SIGNAL_HANDLER

	// Only intercept if in proximity and target is a living mob
	if(!proximity || !isliving(target))
		return NONE

	// Don't intercept right-clicks - let normal disarm flow handle it
	if(LAZYACCESS(modifiers, RIGHT_CLICK))
		return NONE

	switch(current_intent)
		if(INTENT_DISARM)
			// Disarm intent: left-click triggers disarm
			INVOKE_ASYNC(src, PROC_REF(do_disarm), source, target)
			return COMPONENT_CANCEL_ATTACK_CHAIN
		if(INTENT_GRAB)
			// Grab intent: left-click triggers grab
			INVOKE_ASYNC(src, PROC_REF(do_grab), source, target)
			return COMPONENT_CANCEL_ATTACK_CHAIN
		// Help and Harm intents: let normal attack chain proceed
		// Combat mode is already synced appropriately

	return NONE

/// Signal handler for COMSIG_LIVING_GRAB
/// We don't need to intercept this normally, but we could use it for grab intent special behavior
/datum/component/intents/proc/on_grab_attempt(mob/living/source, mob/living/target)
	SIGNAL_HANDLER
	return NONE

/// Performs a disarm action
/datum/component/intents/proc/do_disarm(mob/living/source, mob/living/target)
	if(!source || !target)
		return
	if(!source.Adjacent(target))
		return
	source.disarm(target)

/// Performs a grab action
/datum/component/intents/proc/do_grab(mob/living/source, mob/living/target)
	if(!source || !target)
		return
	if(!source.Adjacent(target))
		return
	source.grab(target)

/// Intercept F key (toggle combat) - cycle intents instead
/datum/component/intents/proc/on_toggle_combat(mob/living/source)
	SIGNAL_HANDLER
	cycle_intent()
	return COMSIG_KB_ACTIVATED

/// Intercept 4 key (enable combat) - set harm intent
/datum/component/intents/proc/on_enable_combat(mob/living/source)
	SIGNAL_HANDLER
	set_intent(INTENT_HARM)
	return COMSIG_KB_ACTIVATED

/// Intercept 1 key (disable combat) - set help intent
/datum/component/intents/proc/on_disable_combat(mob/living/source)
	SIGNAL_HANDLER
	set_intent(INTENT_HELP)
	return COMSIG_KB_ACTIVATED
