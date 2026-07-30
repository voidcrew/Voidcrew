/**
 * Pill-class modules.
 *
 * The Pill has one slot: the bay bolted onto the nose, east of the cabin. It is a
 * single tile with no room to walk into, so every module here is one machine you
 * reach in and operate from the cabin. The hull owns the tile's floor, light and
 * outer windows - modules only add what sits in it.
 *
 * No themes on this hull, so none of these set for_theme.
 */

/datum/ship_upgrade_module/pill
	for_ship = /datum/map_template/shuttle/voidcrew/pill

/datum/ship_upgrade_module/pill/empty
	id = "pill_extra_empty"
	name = "Empty Bay"
	desc = "The bay ships bare. Somewhere to stack ore bags, or to stand out of the way \
		of whoever is flying."
	slot = "pill_extra"
	map_file = "pill/pill_extra_empty.dmm"
	is_default = TRUE

/datum/ship_upgrade_module/pill/workshop
	id = "pill_extra_workshop"
	name = "Workshop Bay"
	desc = "An autolathe, installed and running. The Pill already carries the circuit \
		board for one and nowhere to put it; this is the nowhere."
	slot = "pill_extra"
	map_file = "pill/pill_extra_workshop.dmm"
	part_cost = list(PART_CLASS_SCIENCE = 4)

/datum/ship_upgrade_module/pill/ore
	id = "pill_extra_ore"
	name = "Ore Processing Bay"
	desc = "An ore redemption machine that works without a silo. Turns what the drills \
		bring back into sheets on board, instead of hauling ore bags to a station."
	slot = "pill_extra"
	map_file = "pill/pill_extra_ore.dmm"
	part_cost = list(PART_CLASS_TRADE = 7)

/datum/ship_upgrade_module/pill/infirmary
	id = "pill_extra_infirmary"
	name = "Infirmary Bay"
	desc = "A sleeper, operated from the cabin. The Pill's entire medical provision is \
		otherwise the two medkits under the bed."
	slot = "pill_extra"
	map_file = "pill/pill_extra_infirmary.dmm"
	part_cost = list(PART_CLASS_MISC = 4)
