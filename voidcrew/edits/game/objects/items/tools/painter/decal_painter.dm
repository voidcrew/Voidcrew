// Voidcrew extensions to code/game/objects/items/tools/painter/decal_painter.dm.

/// An immutable description of the current paint selection for remote construction jobs.
/obj/item/airlock_painter/decal/proc/get_decal_data()
	return current_category.get_decal_info(state = selected_decal_icon_state, color = selected_color, dir = selected_dir)
