// A pocket holding something that can't be stripped (a human NPC's locked gear carries TRAIT_NO_STRIP) reads as
// empty, as every other slot already does in tg's strip menu, instead of showing a bulge nobody can take.

/datum/strippable_item/mob_item_slot/pocket/get_obscuring(atom/source)
	var/obj/item/item = get_item(source)
	if(item && (HAS_TRAIT(item, TRAIT_NO_STRIP) || HAS_TRAIT(item, TRAIT_EXAMINE_SKIP)))
		return STRIPPABLE_OBSCURING_NONE
	return ..()

/datum/strippable_item/mob_item_slot/pocket/start_unequip(atom/source, mob/user)
	var/obj/item/item = get_item(source)
	if(item && (HAS_TRAIT(item, TRAIT_NO_STRIP) || HAS_TRAIT(item, TRAIT_EXAMINE_SKIP)))
		return FALSE
	return ..()
