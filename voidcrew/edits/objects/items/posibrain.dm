/**
 * Positronic brain (posibrain) repair + examine.
 *
 * Posibrains take integrity damage while piloting an open-cage mech
 * (see voidcrew/edits/vehicles/mecha.dm). Give roboticists a way to patch
 * that damage back up with a cable coil or a welding tool, mirroring the
 * repair loops used on other vehicles so the numbers stay familiar, and
 * surface the integrity state on examine like other damaged objects.
 */

/// Integrity restored per repair tick.
#define VOIDCREW_POSIBRAIN_REPAIR_AMOUNT 10

/obj/item/mmi/posibrain/examine(mob/user)
	. = ..()
	var/healthpercent = round((get_integrity()/max_integrity) * 100, 1)
	switch(healthpercent)
		if(60 to 95)
			. += span_info("It looks slightly damaged.")
		if(25 to 60)
			. += span_warning("It appears heavily damaged.")
		if(0 to 25)
			. += span_boldwarning("It's falling apart!")

/obj/item/mmi/posibrain/welder_act(mob/living/user, obj/item/W)
	if(user.combat_mode)
		return
	. = TRUE
	if(DOING_INTERACTION(user, src))
		balloon_alert(user, "you're already repairing it!")
		return
	if(get_integrity() >= max_integrity)
		balloon_alert(user, "it's not damaged!")
		return
	if(!W.tool_start_check(user, amount=1, heat_required = HIGH_TEMPERATURE_REQUIRED))
		return
	user.balloon_alert_to_viewers("started welding [src]", "started repairing [src]")
	audible_message(span_hear("You hear welding."))
	var/did_the_thing
	while(get_integrity() < max_integrity)
		if(W.use_tool(src, user, 2.5 SECONDS, volume=50))
			did_the_thing = TRUE
			repair_damage(VOIDCREW_POSIBRAIN_REPAIR_AMOUNT)
			audible_message(span_hear("You hear welding."))
		else
			break
	if(did_the_thing)
		user.balloon_alert_to_viewers("[(get_integrity() >= max_integrity) ? "fully" : "partially"] repaired [src]")
	else
		user.balloon_alert_to_viewers("stopped welding [src]", "interrupted the repair!")

/obj/item/mmi/posibrain/item_interaction(mob/living/user, obj/item/tool, list/modifiers)
	if(istype(tool, /obj/item/stack/cable_coil))
		if(user.combat_mode)
			return NONE
		if(DOING_INTERACTION(user, src))
			balloon_alert(user, "you're already repairing it!")
			return ITEM_INTERACT_SUCCESS
		if(get_integrity() >= max_integrity)
			balloon_alert(user, "it's not damaged!")
			return ITEM_INTERACT_SUCCESS
		user.visible_message(span_notice("[user] starts fixing some of the wires in [src]."), span_notice("You start fixing some of the wires in [src]."))
		var/did_the_thing
		while(get_integrity() < max_integrity)
			if(!do_after(user, 1 SECONDS, src))
				break
			if(!tool.use(1))
				balloon_alert(user, "not enough cable!")
				break
			did_the_thing = TRUE
			repair_damage(VOIDCREW_POSIBRAIN_REPAIR_AMOUNT)
		if(did_the_thing)
			user.balloon_alert_to_viewers("[(get_integrity() >= max_integrity) ? "fully" : "partially"] rewired [src]")
		else
			user.balloon_alert_to_viewers("stopped rewiring [src]", "interrupted the repair!")
		return ITEM_INTERACT_SUCCESS
	return ..()