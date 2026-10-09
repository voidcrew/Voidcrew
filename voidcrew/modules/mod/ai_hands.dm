/**
 * MOD AIs (and pAIs) working the wearer's body once the wearer can't.
 *
 * While the wearer's out cold, in hard crit or dead, and the suit's running with its gauntlets
 * sealed, the AI's clicks are the wearer's hands: whatever's in the active hand used on what it
 * clicks, or a bare hand (a punch, in the AI's combat mode). It's slower at it than the wearer
 * (AI_HANDS_COOLDOWN), and picking things up or dropping them takes it a while (AI_HANDS_GRAB_TIME).
 * The AI's own keys for hands work on the wearer's: drop, swap hands, use in hand. It sees the
 * wearer's hands on its screen, with what's in them, while it has them.
 *
 * Whatever state the wearer's in, the AI's middle or alt clicks use the suit's selected module at
 * what it clicks, as the wearer's do: tethers, kinesis and the like, which an AI couldn't aim before.
 */

#define AI_HANDS_COOLDOWN (2 SECONDS)
#define AI_HANDS_GRAB_TIME (1.5 SECONDS)
#define AI_HANDS_CHARGE (DEFAULT_CHARGE_DRAIN * 2.5)

/obj/item/mod/control
	/// Whether the suit's holding the wearer's hands up for its AI (see ai_take_hands()).
	var/ai_holding_hands = FALSE
	/// Whether the AI's in the middle of something with them.
	var/ai_hands_busy = FALSE
	/// The wearer's hands on the AI's screen, while it can use them.
	var/list/atom/movable/screen/mod_ai_hand/ai_hand_slots = list()
	COOLDOWN_DECLARE(cooldown_ai_hands)

/// One of the wearer's hands on the AI's screen, showing what's in it. Clicking it uses the item in
/// it if it's the hand in use, or switches to it.
/atom/movable/screen/mod_ai_hand
	icon = 'icons/hud/screen_midnight.dmi'
	mouse_over_pointer = MOUSE_HAND_POINTER
	var/obj/item/mod/control/mod
	var/held_index

/atom/movable/screen/mod_ai_hand/Click(location, control, params)
	if(usr != mod?.ai_assistant || !mod.ai_can_use_hands())
		return
	if(mod.wearer.active_hand_index == held_index)
		INVOKE_ASYNC(mod, TYPE_PROC_REF(/obj/item/mod/control, ai_use_inhand))
	else
		mod.wearer.swap_hand(held_index)

/atom/movable/screen/mod_ai_hand/Destroy()
	vis_contents.Cut()
	mod = null
	return ..()

/obj/item/mod/control/on_gained_assistant(mob/living/silicon/new_helper)
	. = ..()
	RegisterSignal(new_helper, COMSIG_MOB_CLICKON, PROC_REF(on_assistant_click))
	RegisterSignal(new_helper, COMSIG_KB_MOB_DROPITEM_DOWN, PROC_REF(on_assistant_drop))
	RegisterSignal(new_helper, COMSIG_KB_MOB_SWAPHANDS_DOWN, PROC_REF(on_assistant_swap))
	RegisterSignal(new_helper, COMSIG_KB_MOB_ACTIVATEINHAND_DOWN, PROC_REF(on_assistant_use_inhand))
	RegisterSignal(new_helper, COMSIG_MOB_LOGIN, PROC_REF(on_suit_changed))
	RegisterSignals(src, list(COMSIG_MOD_TOGGLED, COMSIG_MOD_PART_SEALED), PROC_REF(on_suit_changed))
	RegisterSignal(src, COMSIG_MOD_WEARER_SET, PROC_REF(on_wearer_set))
	RegisterSignal(src, COMSIG_MOD_WEARER_UNSET, PROC_REF(on_wearer_unset))
	if(wearer)
		on_wearer_set()

/obj/item/mod/control/on_removed_assistant()
	UnregisterSignal(ai_assistant, list(COMSIG_MOB_CLICKON, COMSIG_KB_MOB_DROPITEM_DOWN, COMSIG_KB_MOB_SWAPHANDS_DOWN, COMSIG_KB_MOB_ACTIVATEINHAND_DOWN, COMSIG_MOB_LOGIN))
	UnregisterSignal(src, list(COMSIG_MOD_TOGGLED, COMSIG_MOD_PART_SEALED, COMSIG_MOD_WEARER_SET, COMSIG_MOD_WEARER_UNSET))
	if(wearer)
		on_wearer_unset()
	ai_assistant.client?.screen -= ai_hand_slots
	QDEL_LIST(ai_hand_slots)
	return ..()

/obj/item/mod/control/Destroy()
	ai_assistant?.client?.screen -= ai_hand_slots
	QDEL_LIST(ai_hand_slots)
	return ..()

/obj/item/mod/control/proc/on_wearer_set(datum/source)
	SIGNAL_HANDLER
	RegisterSignals(wearer, list(COMSIG_MOB_STATCHANGE, COMSIG_MOB_UPDATE_HELD_ITEMS, COMSIG_MOB_SWAP_HANDS), PROC_REF(on_suit_changed))
	ai_update_hands_hud()

/obj/item/mod/control/proc/on_wearer_unset(datum/source)
	SIGNAL_HANDLER
	UnregisterSignal(wearer, list(COMSIG_MOB_STATCHANGE, COMSIG_MOB_UPDATE_HELD_ITEMS, COMSIG_MOB_SWAP_HANDS))
	ai_let_go_of_hands()
	ai_assistant?.client?.screen -= ai_hand_slots
	QDEL_LIST(ai_hand_slots)

/// Whether the AI can work the wearer's hands: they're out, and the suit's running on them with its gauntlets sealed.
/obj/item/mod/control/proc/ai_can_use_hands()
	if(!ai_assistant || !wearer || wearer.stat < UNCONSCIOUS || !active || activating)
		return FALSE
	var/datum/mod_part/gauntlets = get_part_datum_from_slot(ITEM_SLOT_GLOVES)
	return gauntlets?.sealed

/// Holds the wearer's hands up for the AI: being out doesn't block them while it does, until it lets go (see ai_let_go_of_hands()).
/obj/item/mod/control/proc/ai_take_hands()
	ai_holding_hands = TRUE
	REMOVE_TRAIT(wearer, TRAIT_HANDS_BLOCKED, STAT_TRAIT)

/// Lets go of the wearer's hands. Out as they are, they go limp again, dropping whatever they hold.
/obj/item/mod/control/proc/ai_let_go_of_hands(datum/source)
	SIGNAL_HANDLER
	if(!ai_holding_hands)
		return
	ai_holding_hands = FALSE
	if(wearer?.stat >= UNCONSCIOUS)
		ADD_TRAIT(wearer, TRAIT_HANDS_BLOCKED, STAT_TRAIT)

/// Something about the suit, its wearer or what they hold changed: lets go of their hands if the AI can't use them now, and shows it them as they are.
/obj/item/mod/control/proc/on_suit_changed(datum/source)
	SIGNAL_HANDLER
	if(!ai_can_use_hands())
		ai_let_go_of_hands()
	ai_update_hands_hud()

/// Shows the AI the wearer's hands and what's in them, while it can use them.
/obj/item/mod/control/proc/ai_update_hands_hud()
	var/client/viewer = ai_assistant?.client
	if(!ai_can_use_hands())
		viewer?.screen -= ai_hand_slots
		QDEL_LIST(ai_hand_slots)
		return
	if(length(ai_hand_slots) != length(wearer.held_items))
		viewer?.screen -= ai_hand_slots
		QDEL_LIST(ai_hand_slots)
		for(var/index in 1 to length(wearer.held_items))
			var/atom/movable/screen/mod_ai_hand/slot = new(null, null)
			slot.mod = src
			slot.held_index = index
			slot.name = wearer.get_held_index_name(index)
			slot.icon_state = "hand_[wearer.held_index_to_dir(index)]"
			// Where the wearer's own would be, a row up, over the AI's buttons.
			slot.screen_loc = "CENTER+[IS_LEFT_INDEX(index) ? 0 : -1]:16,SOUTH+[1 + round((index - 1) / 2)]:5"
			ai_hand_slots += slot
	for(var/atom/movable/screen/mod_ai_hand/slot as anything in ai_hand_slots)
		slot.vis_contents.Cut()
		var/obj/item/held = wearer.held_items[slot.held_index]
		if(held)
			slot.vis_contents += held
		slot.cut_overlays()
		if(slot.held_index == wearer.active_hand_index)
			slot.add_overlay(IS_LEFT_INDEX(slot.held_index) ? "lhandactive" : "rhandactive")
	viewer?.screen |= ai_hand_slots

/// Starts something the AI does with the wearer's hands, if it can now: takes them, the time and the charge.
/obj/item/mod/control/proc/ai_ready_hands()
	if(!ai_can_use_hands() || ai_hands_busy || !COOLDOWN_FINISHED(src, cooldown_ai_hands))
		return FALSE
	if(get_charge() < AI_HANDS_CHARGE)
		balloon_alert(ai_assistant, "not enough charge!")
		return FALSE
	COOLDOWN_START(src, cooldown_ai_hands, AI_HANDS_COOLDOWN)
	subtract_charge(AI_HANDS_CHARGE)
	ai_take_hands()
	return TRUE

/// Does something as the wearer, with what being out puts on them lifted for it.
/obj/item/mod/control/proc/as_wearer(datum/callback/what)
	var/mob/living/carbon/human/body = wearer
	ai_hands_busy = TRUE
	REMOVE_TRAIT(body, TRAIT_INCAPACITATED, STAT_TRAIT)
	what.Invoke()
	if(!QDELETED(body) && body.stat != CONSCIOUS)
		ADD_TRAIT(body, TRAIT_INCAPACITATED, STAT_TRAIT)
	ai_hands_busy = FALSE

/// Picking something up or putting it down takes the AI a while.
/obj/item/mod/control/proc/ai_grab_wait(atom/target)
	ai_hands_busy = TRUE
	. = do_after(ai_assistant, AI_HANDS_GRAB_TIME, target, extra_checks = CALLBACK(src, PROC_REF(ai_can_use_hands)))
	ai_hands_busy = FALSE

/obj/item/mod/control/proc/on_assistant_click(mob/living/silicon/source, atom/target, list/modifiers)
	SIGNAL_HANDLER
	if(istype(target, /atom/movable/screen) || LAZYACCESS(modifiers, SHIFT_CLICK) || LAZYACCESS(modifiers, CTRL_CLICK))
		return
	if(LAZYACCESS(modifiers, MIDDLE_CLICK) || LAZYACCESS(modifiers, ALT_CLICK))
		if(!wearer || !selected_module?.used_signal)
			return
		INVOKE_ASYNC(src, PROC_REF(ai_use_module), target)
		return COMSIG_MOB_CANCEL_CLICKON
	// Out of reach of an empty hand, it's the AI's own click.
	if(!ai_can_use_hands() || (!wearer.get_active_held_item() && !wearer.CanReach(target)))
		return
	INVOKE_ASYNC(src, PROC_REF(ai_hand_click), target, modifiers)
	return COMSIG_MOB_CANCEL_CLICKON

/// The AI's click, as the wearer's.
/obj/item/mod/control/proc/ai_hand_click(atom/target, list/modifiers)
	if(!ai_ready_hands())
		return
	var/mob/living/silicon/assistant = ai_assistant
	var/obj/item/held = wearer.get_active_held_item()
	if(!held && isitem(target) && target.loc != wearer && !ai_grab_wait(target))
		return
	if(!ai_can_use_hands())
		return
	if(isliving(target))
		log_combat(assistant, target, "used [key_name(wearer)]'s hands on", held)
	wearer.set_combat_mode(assistant.combat_mode)
	as_wearer(CALLBACK(wearer, TYPE_PROC_REF(/mob, ClickOn), target, list2params(modifiers)))

/obj/item/mod/control/proc/on_assistant_drop(mob/living/silicon/source)
	SIGNAL_HANDLER
	if(!ai_can_use_hands())
		return
	INVOKE_ASYNC(src, PROC_REF(ai_drop))
	return COMSIG_KB_ACTIVATED

/obj/item/mod/control/proc/ai_drop()
	var/obj/item/held = wearer.get_active_held_item()
	if(!held)
		balloon_alert(ai_assistant, "nothing in hand!")
		return
	if(!ai_ready_hands() || !ai_grab_wait(wearer))
		return
	if(held == wearer?.get_active_held_item())
		wearer.dropItemToGround(held)

/obj/item/mod/control/proc/on_assistant_swap(mob/living/silicon/source)
	SIGNAL_HANDLER
	if(!ai_can_use_hands())
		return
	wearer.swap_hand()
	return COMSIG_KB_ACTIVATED

/obj/item/mod/control/proc/on_assistant_use_inhand(mob/living/silicon/source)
	SIGNAL_HANDLER
	if(!ai_can_use_hands())
		return
	INVOKE_ASYNC(src, PROC_REF(ai_use_inhand))
	return COMSIG_KB_ACTIVATED

/obj/item/mod/control/proc/ai_use_inhand()
	if(!wearer.get_active_held_item() || !ai_ready_hands())
		return
	as_wearer(CALLBACK(wearer, TYPE_PROC_REF(/mob, execute_mode)))

/// The suit's selected module used at what the AI clicked, as the wearer's click would.
/obj/item/mod/control/proc/ai_use_module(atom/target)
	var/obj/item/mod/module/module = selected_module
	if(ai_hands_busy || !wearer || !module?.used_signal)
		return
	if(wearer.stat < UNCONSCIOUS)
		module.on_select_use(target)
		return
	as_wearer(CALLBACK(module, TYPE_PROC_REF(/obj/item/mod/module, on_select_use), target))

#undef AI_HANDS_COOLDOWN
#undef AI_HANDS_GRAB_TIME
#undef AI_HANDS_CHARGE
