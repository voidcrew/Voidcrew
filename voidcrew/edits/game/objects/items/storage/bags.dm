// Voidcrew extensions to code/game/objects/items/storage/bags.dm.

/obj/item/storage/bag/ore/examine(mob/user)
	. = ..()
	if(!atom_storage)
		return
	var/free_slots = atom_storage.max_slots - length(contents)
	var/free_weight = atom_storage.max_total_storage - atom_storage.get_total_weight()
	if(free_slots <= 0 || free_weight <= 0)
		. += span_warning("It is full. Ore you walk over will be left on the ground until you empty it.")
	else if(free_slots >= INFINITY) // the satchel of holding
		. += span_notice("It has room for as much ore as you can carry.")
	else
		. += span_notice("It has room for [free_slots] more stack\s of ore.")
	. += span_notice("Click an ore redemption machine or an ore box with it to empty it out.")
	// VOIDCREW EDIT ADDITION END
