/**
 * # A lathe-printed ammo box must not be worth more scrap than an ordinary one
 *
 * When a lathe finishes a print it overwrites the item's custom_materials with the
 * whole print cost, via split_materials_uniformly(), which is meant to spread that
 * cost over the item *and its contents*. An ammo box has no contents at that moment:
 * top_off(starting = TRUE) fills stored_ammo with type paths and the rounds are only
 * instantiated later, by get_round() / ammo_list(). So the box takes that proc's
 * "I am just one thing" fast path and banks the cost of a full box of ammunition all
 * by itself.
 *
 * That was live: a .45 box cost 4800 iron to print and the *emptied* box fed straight
 * back into the same autolathe refunded all 4800, so you could dump the rounds into a
 * magazine and print the next box for free, forever, and pocket the scrap value of
 * every round on top. Both halves scale with the lathe's creation_efficiency, so
 * upgrading its servos neither opened nor closed the loop. voidcrew unlocks c9mm,
 * c10mm, c45 and strilka310_surplus on every autolathe from roundstart
 * (voidcrew/modules/research/designs/autolathe_designs.dm), so it needed no hacking,
 * no research and no tools. The cargo export pad reads the same value, so a printed
 * box also sold for its full print cost.
 *
 * /obj/item/ammo_box/get_material_composition() fixes it by reporting what the box is
 * intrinsically worth instead of whatever was last stamped onto it. This test guards
 * that invariant against an upstream merge quietly reverting it, since the fix lives
 * in an upstream file.
 */

/datum/unit_test/voidcrew_ammo_box_materials/Run()
	// The same figure the autolathe multiplies a design's cost by and then stamps onto
	// what it just printed. Any value works; this keeps the test honest to the real one.
	var/coefficient = /obj/machinery/autolathe::creation_efficiency

	var/designs_checked = 0
	for(var/design_id in SSresearch.techweb_designs)
		var/datum/design/design = SSresearch.techweb_designs[design_id]
		if(!ispath(design.build_path, /obj/item/ammo_box) || !length(design.materials))
			continue
		// Designs may ask for a material *category* by name and let the printer pick;
		// those never reach split_materials_uniformly() as a plain amount.
		var/skip = FALSE
		for(var/material in design.materials)
			if(istext(material))
				skip = TRUE
				break
		if(skip)
			continue
		designs_checked++

		var/obj/item/ammo_box/pristine = allocate(design.build_path)
		var/obj/item/ammo_box/printed = allocate(design.build_path)
		// Exactly what /obj/machinery/autolathe/proc/do_make_item() does to a fresh print.
		// (split_materials_uniformly() was folded into /datum/design/transfer_materials().)
		design.transfer_materials(design.materials, coefficient, printed)

		var/pristine_worth = scrap_value(pristine)
		var/printed_worth = scrap_value(printed)
		if(printed_worth > pristine_worth)
			TEST_FAIL("Design '[design_id]' prints [design.build_path], and the printed box is worth \
				[printed_worth] material to a recycler against [pristine_worth] for an identical box that \
				never went near a lathe. Emptying it and feeding the box back refunds the print, so the \
				ammunition is free and the loop repeats forever.")

	// A rename or a category shuffle upstream would empty the loop and pass silently.
	if(!designs_checked)
		TEST_FAIL("No printable ammo box designs found at all - this test is checking nothing.")

/// Total material a recycler would credit for this item, the way material_container does it.
/datum/unit_test/voidcrew_ammo_box_materials/proc/scrap_value(obj/item/box)
	. = 0
	var/list/composition = box.get_material_composition(MATCONTAINER_ACCEPT_ALLOYS)
	for(var/material in composition)
		. += composition[material]
