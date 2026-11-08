/**
 * # Specimen labeler
 *
 * New code on BeeStation's idea (42b0625, code/modules/xenoarchaeology/tools/xenoarchaeology_labeler.dm).
 * Art: BeeStation icons/obj/xenoarchaeology/xenoartifact_tech.dmi "labeler", CC BY-SA 3.0; the
 * print animation in icons/study.dmi was drawn from it for Voidcrew.
 *
 * A handheld tag printer. The crew dials in three words from its fixed lists (what the find does,
 * what wakes it, its second effect or "None") and presses a printed tag onto a large find. Nothing
 * says whether the tag is right; a buyer's price is the only answer. Right-click peels a tag off.
 */
/obj/item/artifact_labeler
	name = "specimen labeler"
	desc = "A handheld tag printer with a little green screen. Its word list is burned into memory and can't be changed."
	icon = 'voidcrew/modules/xenoarch/icons/study.dmi'
	icon_state = "labeler"
	inhand_icon_state = "electronic"
	lefthand_file = 'icons/mob/inhands/items/devices_lefthand.dmi'
	righthand_file = 'icons/mob/inhands/items/devices_righthand.dmi'
	item_flags = NOBLUDGEON
	w_class = WEIGHT_CLASS_SMALL
	drop_sound = 'sound/items/handling/tape_drop.ogg'
	pickup_sound = 'sound/items/handling/tape_pickup.ogg'
	custom_materials = list(
		/datum/material/iron = SMALL_MATERIAL_AMOUNT * 2,
		/datum/material/glass = SMALL_MATERIAL_AMOUNT * 1.5,
	)
	/// What the find does, as an effect's label word
	var/effect_word
	/// What wakes it, as a trigger word
	var/trigger_word
	/// Its second effect's label word, or ARTIFACT_LABEL_NONE
	var/second_word
	COOLDOWN_DECLARE(print_cooldown)

/obj/item/artifact_labeler/examine(mob/user)
	. = ..()
	if(effect_word || trigger_word || second_word)
		. += "Its screen reads: <i>[effect_word || "..."] / [trigger_word || "..."] / [second_word || "..."]</i>"

/obj/item/artifact_labeler/attack_self(mob/user, modifiers)
	. = ..()
	if(.)
		return
	ui_interact(user)
	return TRUE

/// Whether all three words are set.
/obj/item/artifact_labeler/proc/is_complete()
	return effect_word && trigger_word && second_word

/**
 * Dials one field to a word from its list. Returns TRUE if it changed.
 * `field` is "effect", "trigger" or "second"; a null word clears the field.
 */
/obj/item/artifact_labeler/proc/set_word(field, word)
	if(word && !(word in words_for(field)))
		return FALSE
	switch(field)
		if("effect")
			if(effect_word == word)
				return FALSE
			effect_word = word
		if("trigger")
			if(trigger_word == word)
				return FALSE
			trigger_word = word
		if("second")
			if(second_word == word)
				return FALSE
			second_word = word
		else
			return FALSE
	return TRUE

/// The words a field may take.
/obj/item/artifact_labeler/proc/words_for(field)
	switch(field)
		if("effect")
			return artifact_effect_label_names()
		if("trigger")
			return artifact_trigger_label_names()
		if("second")
			return list(ARTIFACT_LABEL_NONE) + artifact_effect_label_names()
	return list()

/// A label datum for the words now set, or null if any is missing.
/obj/item/artifact_labeler/proc/make_label()
	if(!is_complete())
		return null
	return new /datum/artifact_label(effect_word, trigger_word, second_word)

/obj/item/artifact_labeler/interact_with_atom(atom/interacting_with, mob/living/user, list/modifiers)
	if(!istype(interacting_with, /obj/machinery/artifact))
		return NONE
	var/obj/machinery/artifact/find = interacting_with
	if(!is_complete())
		balloon_alert(user, "the tag is half blank!")
		return ITEM_INTERACT_BLOCKING
	if(!COOLDOWN_FINISHED(src, print_cooldown))
		return ITEM_INTERACT_BLOCKING
	COOLDOWN_START(src, print_cooldown, 2 SECONDS)
	flick("labeler_print", src)
	playsound(src, 'sound/items/taperecorder/taperecorder_print.ogg', 35, TRUE)
	if(!do_after(user, 1 SECONDS, find))
		return ITEM_INTERACT_BLOCKING
	var/datum/artifact_label/new_label = make_label()
	if(!new_label)
		return ITEM_INTERACT_BLOCKING
	var/replaced = !!find.label
	find.apply_label(new_label, user)
	// A tag sets the sale price, and anyone can reach a find, so leave a trail for admins.
	log_game("[key_name(user)] tagged artifact [find.serial] as [effect_word] / [trigger_word] / [second_word] at [AREACOORD(find)].")
	playsound(find, 'sound/items/handling/component_pickup.ogg', 30, TRUE)
	user.visible_message(
		span_notice("[user] presses a printed tag onto [find]."),
		span_notice(replaced ? "You peel off the old tag and press the new one onto [find]." : "You press the tag onto [find]."),
	)
	return ITEM_INTERACT_SUCCESS

/obj/item/artifact_labeler/interact_with_atom_secondary(atom/interacting_with, mob/living/user, list/modifiers)
	if(!istype(interacting_with, /obj/machinery/artifact))
		return NONE
	var/obj/machinery/artifact/find = interacting_with
	if(!find.label)
		balloon_alert(user, "no tag on it!")
		return ITEM_INTERACT_BLOCKING
	if(!do_after(user, 1 SECONDS, find))
		return ITEM_INTERACT_BLOCKING
	if(!find.remove_label(user))
		return ITEM_INTERACT_BLOCKING
	log_game("[key_name(user)] peeled the tag off artifact [find.serial] at [AREACOORD(find)].")
	playsound(find, 'sound/items/poster/poster_ripped.ogg', 20, TRUE)
	user.visible_message(
		span_notice("[user] peels the tag off [find]."),
		span_notice("You peel the tag off [find]."),
	)
	return ITEM_INTERACT_SUCCESS

// ===== tgui =====

/obj/item/artifact_labeler/ui_state(mob/user)
	return GLOB.hands_state

/obj/item/artifact_labeler/ui_interact(mob/user, datum/tgui/ui)
	ui = SStgui.try_update_ui(user, src, ui)
	if(!ui)
		ui = new(user, src, "XenoarchLabeler", name)
		ui.open()

/obj/item/artifact_labeler/ui_static_data(mob/user)
	return list(
		"effects" = artifact_effect_label_names(),
		"triggers" = artifact_trigger_label_names(),
		"none" = ARTIFACT_LABEL_NONE,
	)

/obj/item/artifact_labeler/ui_data(mob/user)
	return list(
		"effect" = effect_word,
		"trigger" = trigger_word,
		"second" = second_word,
	)

/obj/item/artifact_labeler/ui_act(action, list/params, datum/tgui/ui, datum/ui_state/state)
	. = ..()
	if(.)
		return
	switch(action)
		if("set")
			var/field = params["field"]
			var/word = params["word"]
			if(!istext(field) || (!isnull(word) && !istext(word)))
				return FALSE
			if(set_word(field, word))
				playsound(src, 'sound/machines/terminal/terminal_button03.ogg', 15, TRUE)
				return TRUE
		if("clear")
			if(effect_word || trigger_word || second_word)
				effect_word = null
				trigger_word = null
				second_word = null
				playsound(src, 'sound/machines/terminal/terminal_button07.ogg', 15, TRUE)
				return TRUE
	return FALSE
