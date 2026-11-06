/// Two of these are mapped on every Corsair (never in an outfit): a face and a forged card for the counters
/obj/item/storage/box/disguise_kit
	name = "disguise kit"
	desc = "A plain box with a mask and a blank card in it."

/obj/item/storage/box/disguise_kit/PopulateContents()
	new /obj/item/clothing/mask/chameleon(src)
	new /obj/item/card/id/advanced/chameleon(src)

// Hull-bound rigs: the Corsair starts with an interdictor and a siphon, and taking
// either apart gives scrap, never a board or parts to sell or rebuild elsewhere.

/obj/machinery/ship_combat/interdictor/corsair

/obj/machinery/ship_combat/interdictor/corsair/on_deconstruction(disassembled)
	. = ..()
	pirate_strip_to_scrap(src)

/obj/machinery/shuttle_scrambler/ship_siphon/corsair

/obj/machinery/shuttle_scrambler/ship_siphon/corsair/on_deconstruction(disassembled)
	. = ..()
	// The takings are the crew's money, not a part: they come out as a chip
	if(credits_stored > 0)
		new /obj/item/holochip(drop_location(), credits_stored)
		credits_stored = 0
	pirate_strip_to_scrap(src)

/**
 * Called from on_deconstruction(), before handle_deconstruct() spawns a frame and drops the parts:
 * with the board and parts gone it spawns neither, and the machine leaves two iron sheets.
 */
/proc/pirate_strip_to_scrap(obj/machinery/machine)
	var/atom/drop = machine.drop_location()
	machine.clear_components()
	if(drop)
		new /obj/item/stack/sheet/iron(drop, 2)
