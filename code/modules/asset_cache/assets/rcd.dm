/datum/asset/spritesheet_batched/rcd
	name = "rcd-tgui"

// VOIDCREW EDIT START - PR #123: ship systems and overmap integration.
/datum/asset/spritesheet_batched/rcd/create_spritesheets()
	//the ship construction console's hull windows are not in GLOB.rcd_designs (they are not
	//offered by the handheld RCD) but they share this spritesheet, so draw both trees
	for(var/list/design_tree as anything in list(GLOB.rcd_designs, GLOB.ship_rcd_hull_designs))
		draw_design_tree(design_tree)
// VOIDCREW EDIT END
