// Package: P2 guns and flask. The plasma flask: feeding, fill sprite steps and examine line.

/// Feeds a plasma sheet or ore stack into the flask, one unit per do_after. Returns mol added.
/obj/item/plasma_flask/proc/feed(obj/item/stack/fuel, mob/user)
	return 0

/obj/item/plasma_flask/item_interaction(mob/living/user, obj/item/tool, list/modifiers)
	if(istype(tool, /obj/item/stack/sheet/mineral/plasma) || istype(tool, /obj/item/stack/ore/plasma))
		feed(tool, user)
		return ITEM_INTERACT_SUCCESS
	return ..()
