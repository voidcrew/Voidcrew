/datum/asset/spritesheet_batched/rcd
	name = "rcd-tgui"

/datum/asset/spritesheet_batched/rcd/create_spritesheets()
	//the ship construction console's hull windows are not in GLOB.rcd_designs (they are not
	//offered by the handheld RCD) but they share this spritesheet, so draw both trees
	for(var/list/design_tree as anything in list(GLOB.rcd_designs, GLOB.ship_rcd_hull_designs))
		draw_design_tree(design_tree)

/// Inserts an icon for every design in one GLOB.rcd_designs-shaped tree.
/datum/asset/spritesheet_batched/rcd/proc/draw_design_tree(list/design_tree)
	for(var/root_category in design_tree)

		var/list/category_designs = design_tree[root_category]
		if(!length(category_designs))
			continue

		for(var/category in category_designs)
			var/list/designs = category_designs[category]

			var/sprite_name

			for(var/list/design as anything in designs)
				var/atom/movable/path = design[RCD_DESIGN_PATH]
				if(!ispath(path))
					continue
				sprite_name = initial(path.name)
				var/datum/universal_icon/sprite_icon

				//icon for windows are blended with grills if required and loaded from radial menu
				if(ispath(path, /obj/structure/window))
					var/obj/structure/window/window_path = path
					if(path == /obj/structure/window)
						sprite_icon = uni_icon('icons/hud/radial.dmi', "windowsize")
					else if(path == /obj/structure/window/reinforced)
						sprite_icon = uni_icon('icons/hud/radial.dmi', "windowtype")
					else
						sprite_icon = uni_icon(initial(window_path.icon), initial(window_path.icon_state))
						//every other full tile window sits on a grille the same way the two
						//stock ones do, including the hull windows added above
						if(initial(window_path.fulltile))
							sprite_icon.blend_icon(uni_icon('icons/obj/structures.dmi', "grille"), ICON_UNDERLAY)

				//icons for solid airlocks have an added solid overlay on top of their glass icons
				else if(ispath(path, /obj/machinery/door/airlock))
					var/obj/machinery/door/airlock/airlock_path = path
					var/airlock_icon = initial(airlock_path.icon)

					sprite_icon = uni_icon(airlock_icon, "closed")
					if(!initial(airlock_path.glass) && initial(airlock_path.can_be_glass))
						sprite_icon.blend_icon(uni_icon(airlock_icon, "fill_closed"), ICON_OVERLAY)

				//for all other icons we load the paths default icon & icon state
				else
					sprite_icon = uni_icon(initial(path.icon), initial(path.icon_state))

				insert_icon(sanitize_css_class_name(sprite_name), sprite_icon)
