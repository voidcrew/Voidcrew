// Package: P2 guns and cartridges. The plasma cartridge: made full, used up, never refilled.
//
// A cartridge's plasma only ever falls. It comes full from the hand press, the lathe or the shop
// (plasma_press.dm, plasma_shop.dm), goes into a gun's chamber when seated and comes back out with
// whatever the chamber still holds (plasma_guns.dm). Nothing puts plasma into a cartridge.

/obj/item/plasma_cartridge
	w_class = WEIGHT_CLASS_SMALL
	slot_flags = ITEM_SLOT_BELT

/// Whatever made it, a cartridge is its iron jacket and nothing else. A lathe stamps the design's
/// plasma onto what it prints and crafting stamps the ingredients'; either would let a spent
/// cartridge recycle back into plasma sheets, and make it burn like a plasma item.
/obj/item/plasma_cartridge/apply_material_effects(list/materials)
	return ..(list(/datum/material/iron = PLASMA_CARTRIDGE_IRON))

/obj/item/plasma_cartridge/on_craft_completion(list/components, datum/crafting_recipe/current_recipe, atom/crafter)
	. = ..()
	playsound(src, PLASMA_SOUND_PRESS, 20, TRUE)

/// Fill step 0 (spent) to 3 (full), for the sprite and the examine line
/obj/item/plasma_cartridge/proc/fill_step()
	if(stored <= 0)
		return 0
	if(stored >= PLASMA_CARTRIDGE_CAPACITY)
		return 3
	return stored < PLASMA_CARTRIDGE_CAPACITY / 2 ? 1 : 2

/obj/item/plasma_cartridge/update_icon_state()
	icon_state = "cartridge_[fill_step()]"
	inhand_icon_state = icon_state
	update_inhand_icon()
	return ..()

/obj/item/plasma_cartridge/examine(mob/user)
	. = ..()
	switch(fill_step())
		if(0)
			. += "It is spent."
		if(1)
			. += "It is about a third full."
		if(2)
			. += "It is about two thirds full."
		if(3)
			. += "It is full."
