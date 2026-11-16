/// Two tape slots: songs on the first tape can be copied onto the second.
/obj/item/cassette_deck
	name = "dual cassette deck"
	desc = "A handheld tape deck with two slots. Good for making mixtapes."
	icon = 'icons/obj/devices/voice.dmi'
	icon_state = "taperecorder_empty"
	inhand_icon_state = "analyzer"
	lefthand_file = 'icons/mob/inhands/equipment/tools_lefthand.dmi'
	righthand_file = 'icons/mob/inhands/equipment/tools_righthand.dmi'
	w_class = WEIGHT_CLASS_SMALL
	force = 2
	throwforce = 2
	drop_sound = 'sound/items/handling/taperecorder_drop.ogg'
	pickup_sound = 'sound/items/handling/taperecorder_pickup.ogg'
	/// The tape songs are copied from. Filled first.
	var/obj/item/cassette_tape/tape_from
	/// The tape songs are copied onto.
	var/obj/item/cassette_tape/tape_to

/obj/item/cassette_deck/Initialize(mapload)
	. = ..()
	register_context()

/obj/item/cassette_deck/Destroy()
	QDEL_NULL(tape_from)
	QDEL_NULL(tape_to)
	return ..()

/obj/item/cassette_deck/Exited(atom/movable/gone, direction)
	. = ..()
	if(gone == tape_from)
		tape_from = null
	if(gone == tape_to)
		tape_to = null
	update_appearance()

/obj/item/cassette_deck/update_icon_state()
	icon_state = (tape_from || tape_to) ? "taperecorder_idle" : "taperecorder_empty"
	return ..()

/obj/item/cassette_deck/examine(mob/user)
	. = ..()
	if(tape_from)
		. += span_notice("The left slot holds [tape_from].")
	if(tape_to)
		. += span_notice("The right slot holds [tape_to].")

/obj/item/cassette_deck/add_context(atom/source, list/context, obj/item/held_item, mob/user)
	. = ..()
	if(istype(held_item, /obj/item/cassette_tape))
		if(!tape_from || !tape_to)
			context[SCREENTIP_CONTEXT_LMB] = "Insert tape"
		return CONTEXTUAL_SCREENTIP_SET
	if(held_item == src && tape_to)
		if(tape_from)
			context[SCREENTIP_CONTEXT_LMB] = "Copy a song"
		context[SCREENTIP_CONTEXT_RMB] = "Erase a song"
	if(tape_from || tape_to)
		context[SCREENTIP_CONTEXT_ALT_LMB] = "Eject tape"
	return CONTEXTUAL_SCREENTIP_SET

/obj/item/cassette_deck/item_interaction(mob/living/user, obj/item/tool, list/modifiers)
	if(!istype(tool, /obj/item/cassette_tape))
		return NONE
	if(tape_from && tape_to)
		balloon_alert(user, "both slots full!")
		return ITEM_INTERACT_BLOCKING
	if(!user.transferItemToLoc(tool, src))
		return ITEM_INTERACT_BLOCKING
	if(!tape_from)
		tape_from = tool
	else
		tape_to = tool
	playsound(src, 'sound/items/taperecorder/taperecorder_close.ogg', 40, FALSE)
	update_appearance()
	return ITEM_INTERACT_SUCCESS

/obj/item/cassette_deck/click_alt(mob/user)
	// The tape being recorded onto comes out first.
	var/obj/item/cassette_tape/ejected = tape_to || tape_from
	if(!ejected)
		return NONE
	playsound(src, 'sound/items/taperecorder/taperecorder_open.ogg', 40, FALSE)
	ejected.forceMove(drop_location()) // Exited() clears the slot
	user.put_in_hands(ejected)
	return CLICK_ACTION_SUCCESS

/obj/item/cassette_deck/attack_self(mob/user, modifiers)
	. = ..()
	if(.)
		return
	if(!tape_to)
		balloon_alert(user, "no tape to record on")
		return TRUE
	if(!tape_from)
		balloon_alert(user, "nothing to copy from")
		return TRUE
	INVOKE_ASYNC(src, PROC_REF(choose_copy), user)
	return TRUE

/obj/item/cassette_deck/attack_self_secondary(mob/user, modifiers)
	. = ..()
	if(.)
		return
	if(!tape_to)
		balloon_alert(user, "no tape to erase")
		return TRUE
	INVOKE_ASYNC(src, PROC_REF(choose_erase), user)
	return TRUE

/// Labels for a side's songs, numbered so two copies of one song stay apart in a list.
/obj/item/cassette_deck/proc/side_choices(obj/item/cassette_tape/tape)
	var/list/choices = list()
	var/list/side = tape.current_side()
	for(var/position in 1 to length(side))
		choices["[position]. [cassette_track_label(side[position])]"] = position
	return choices

/obj/item/cassette_deck/proc/choose_copy(mob/user)
	var/list/side = tape_from.current_side()
	if(!length(side))
		balloon_alert(user, "[tape_from] is blank")
		return
	if(length(tape_to.current_side()) >= tape_to.max_side_tracks)
		balloon_alert(user, "[tape_to] is full")
		return
	var/obj/item/cassette_tape/from = tape_from
	var/obj/item/cassette_tape/onto = tape_to
	var/list/choices = side_choices(from)
	var/choice = tgui_input_list(user, "Copy which song?", name, choices)
	if(isnull(choice) || QDELETED(src) || !user.can_perform_action(src, FORBID_TELEKINESIS_REACH))
		return
	// The tapes may have been swapped while the list was open.
	if(tape_from != from || tape_to != onto)
		return
	var/position = choices[choice]
	var/list/from_side = from.current_side()
	if(position > length(from_side) || !onto.record_track(from_side[position]))
		balloon_alert(user, "[onto] is full")
		return
	playsound(src, 'sound/machines/click.ogg', 30, TRUE)
	balloon_alert(user, "copied")

/obj/item/cassette_deck/proc/choose_erase(mob/user)
	if(!length(tape_to.current_side()))
		balloon_alert(user, "[tape_to] is blank")
		return
	var/obj/item/cassette_tape/onto = tape_to
	var/list/choices = side_choices(onto)
	var/choice = tgui_input_list(user, "Erase which song?", name, choices)
	if(isnull(choice) || QDELETED(src) || !user.can_perform_action(src, FORBID_TELEKINESIS_REACH))
		return
	if(tape_to != onto || !onto.erase_track(choices[choice]))
		return
	playsound(src, 'sound/machines/click.ogg', 30, TRUE)
	balloon_alert(user, "erased")
