// Voidcrew extensions to code/modules/projectiles/boxes_magazines/_box_magazine.dm.

/**
 * Report what this box is intrinsically worth rather than whatever was last stamped onto
 * custom_materials.
 *
 * Lathes overwrite a printed item's custom_materials with the whole print cost, via
 * split_materials_uniformly(), which is meant to spread that cost across the item *and its
 * contents*. An ammo box has no contents at that moment: top_off(starting = TRUE) fills
 * stored_ammo with type paths and the rounds are only instantiated later, by get_round() /
 * ammo_list(). So the box takes that proc's "I am just one thing" fast path and banks the
 * entire cost of a full box of ammunition all by itself.
 *
 * Left alone, you could print a box, empty it into a magazine, feed the empty box back to
 * the lathe for a full refund and repeat - free ammunition forever, plus the scrap value of
 * every round on top. A printed box could also be sold on the cargo export pad for its whole
 * print cost. Note that both halves of the print cost cancel out, so upgrading the lathe's
 * servos neither opened nor closed the loop.
 *
 * Rounds still listed in stored_ammo are deliberately not counted here. Once instantiated
 * they live in contents, and the material container's user_insert() already walks contents
 * and credits them separately - counting them here too would pay out twice.
 */
/obj/item/ammo_box/get_material_composition(flags)
	if(isnull(intrinsic_materials))
		return list()

	. = list()
	for(var/mat in intrinsic_materials)
		var/datum/material/material = GET_MATERIAL_REF(mat)
		var/list/material_comp = material.return_composition(intrinsic_materials[mat], flags)
		for(var/comp_mat in material_comp)
			.[comp_mat] += material_comp[comp_mat]

/obj/item/ammo_box
	var/list/intrinsic_materials
