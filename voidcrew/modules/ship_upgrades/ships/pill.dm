/**
 * Pill-class modules.
 *
 * The Pill has one slot: the middle tile of the corridor, between the bunks and
 * the cockpit. Everyone walks through it to reach the helm, so modules here are
 * gear laid out on the floor - nothing dense enough to block the walk. The hull
 * owns the tile's floor, light, entry door and fans - modules only add what
 * sits in it.
 *
 * No themes on this hull, so none of these set for_theme.
 */

/datum/ship_upgrade_module/pill
	for_ship = /datum/map_template/shuttle/voidcrew/pill

/datum/ship_upgrade_module/pill/empty
	id = "pill_extra_empty"
	name = "Empty Bay"
	desc = "The bay ships bare. Spare floor in the middle of the ship, somewhere \
		to drop ore bags on the way in."
	slot = "pill_extra"
	map_file = "pill/pill_extra_empty.dmm"
	is_default = TRUE

/datum/ship_upgrade_module/pill/medical
	id = "pill_extra_medical"
	name = "Medical Bay"
	desc = "A defibrillator, brute and burn kits, a health analyzer, a roller bed \
		and a body bag. The Pill's medical provision is otherwise the medkits \
		under the pilot's bed."
	slot = "pill_extra"
	map_file = "pill/pill_extra_medical.dmm"
	part_cost = list(PART_CLASS_MISC = 4)

/datum/ship_upgrade_module/pill/weapons
	id = "pill_extra_weapons"
	name = "Weapons Bay"
	desc = "Three surplus retro laser guns and a charging dock on the floor. The \
		crew can shoot back now."
	slot = "pill_extra"
	map_file = "pill/pill_extra_weapons.dmm"
	part_cost = list(PART_CLASS_COMBAT = 4)

/datum/ship_upgrade_module/pill/engineering
	id = "pill_extra_engineering"
	name = "Engineering Bay"
	desc = "A stocked toolbelt, insulated gloves, a rapid pipe dispenser, cable \
		and fifty sheets each of iron and glass. Enough to patch the hull, or to \
		start improving it."
	slot = "pill_extra"
	map_file = "pill/pill_extra_engineering.dmm"
	part_cost = list(PART_CLASS_TRADE = 4)

/datum/ship_upgrade_module/pill/builder
	id = "pill_extra_builder"
	name = "Builder Bay"
	desc = "Ship construction console and ore silo boards, a loaded RCD with two \
		large matter cartridges, a rapid pipe dispenser, a stocked toolbelt and insulated gloves. \
		Two hundred iron sheets, one hundred glass sheets and three cable coils \
		give the crew a head start on turning the Pill into a proper ship."
	slot = "pill_extra"
	map_file = "pill/pill_extra_builder.dmm"
	part_cost = list(PART_CLASS_TRADE = 8)
