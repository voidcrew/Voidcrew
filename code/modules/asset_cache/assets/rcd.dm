/datum/asset/spritesheet_batched/rcd
	name = "rcd-tgui"

/datum/asset/spritesheet_batched/rcd/create_spritesheets()
	//the ship construction console's hull windows are not in GLOB.rcd_designs (they are not
	//offered by the handheld RCD) but they share this spritesheet, so draw both trees
	// VOIDCREW EDIT START: shuttle draws hull-window construction icons.
	for(var/list/design_tree as anything in list(GLOB.rcd_designs, GLOB.ship_rcd_hull_designs))
		draw_design_tree(design_tree)
	// VOIDCREW EDIT END

// VOIDCREW EDIT: shuttle draws icons for construction design trees; implementation in voidcrew/edits/modules/asset_cache/assets/rcd.dm.
// VOIDCREW EDIT REMOVAL: shuttle draws the original design loop in voidcrew/edits/modules/asset_cache/assets/rcd.dm.
