// Package: P2 guns and flask. The plasma flask: feeding, fill sprite steps and examine line.

/obj/item/plasma_flask
	w_class = WEIGHT_CLASS_SMALL
	slot_flags = ITEM_SLOT_BELT

/// Mol one unit of `fuel` gives, or 0 if it isn't plasma a flask takes (sheets and ore only)
/proc/plasma_fuel_mol_per_unit(obj/item/stack/fuel)
	if(istype(fuel, /obj/item/stack/sheet/mineral/plasma))
		return PLASMA_MOL_PER_SHEET
	if(istype(fuel, /obj/item/stack/ore/plasma))
		return PLASMA_MOL_PER_ORE
	return 0

/// Feeds a plasma sheet or ore stack into the flask, one unit per do_after. Returns mol added.
/// A unit goes in only when there is room for all of it. With no user there is no delay.
/obj/item/plasma_flask/proc/feed(obj/item/stack/fuel, mob/user)
	var/per_unit = plasma_fuel_mol_per_unit(fuel)
	if(!per_unit)
		return 0
	var/added = 0
	while(!QDELETED(fuel) && fuel.get_amount() > 0)
		if(stored + per_unit > PLASMA_FLASK_CAPACITY)
			if(!added && user)
				balloon_alert(user, "it's full")
			break
		if(user && !do_after(user, PLASMA_FEED_DELAY, target = src))
			break
		if(QDELETED(fuel) || stored + per_unit > PLASMA_FLASK_CAPACITY || !fuel.use(1))
			break
		stored += per_unit
		added += per_unit
		playsound(src, PLASMA_SOUND_FEED_SHEET, 20, TRUE)
		update_appearance()
	if(added)
		playsound(src, PLASMA_SOUND_FEED_CLICK, 30, TRUE)
	return added

/obj/item/plasma_flask/item_interaction(mob/living/user, obj/item/tool, list/modifiers)
	if(istype(tool, /obj/item/stack/sheet/mineral/plasma) || istype(tool, /obj/item/stack/ore/plasma))
		feed(tool, user)
		return ITEM_INTERACT_SUCCESS
	return ..()

/// Fill step 0 (empty) to 3 (full), for the sprite and the examine line
/obj/item/plasma_flask/proc/fill_step()
	if(stored <= 0)
		return 0
	if(stored >= PLASMA_FLASK_CAPACITY)
		return 3
	return stored < PLASMA_FLASK_CAPACITY / 2 ? 1 : 2

/obj/item/plasma_flask/update_icon_state()
	icon_state = "flask_[fill_step()]"
	return ..()

/obj/item/plasma_flask/examine(mob/user)
	. = ..()
	switch(fill_step())
		if(0)
			. += "It is empty."
		if(1)
			. += "It is about a third full."
		if(2)
			. += "It is about two thirds full."
		if(3)
			. += "It is full."
