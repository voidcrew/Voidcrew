/**
 * Bulldog shotgun -- red-tier blueprint gun.
 *
 * Boarding-party drum shotgun. Part node sits deep (prereq Exotic Ammunition,
 * tier 4); see guns/l6_saw.dm for the annotated pipeline walkthrough.
 */

/obj/item/blueprint/gun/bulldog
	name = "weapon schematic (Bulldog shotgun)"
	schematic_name = "Bulldog shotgun"
	recipe_type = /datum/crafting_recipe/blueprint/gun/bulldog
	tier = BLUEPRINT_TIER_RED

/datum/crafting_recipe/blueprint/gun/bulldog
	name = "Bulldog Shotgun"
	result = /obj/item/gun/ballistic/shotgun/bulldog
	reqs = list(
		/obj/item/gun_part/bulldog = 1,
		/obj/item/firing_pin = 1,
		/obj/item/stack/sheet/iron = 6,
	)

/obj/item/gun_part/bulldog
	name = "Bulldog receiver"
	desc = "The machined receiver and drum-feed assembly for a Bulldog shotgun. You'll need the matching schematic to build it into a working gun."
	icon_state = "bulldog"
	// Mirrors /datum/design/gun_part_bulldog below. The lathe already stamps these on a printed
	// receiver; declaring them here keeps a hand-spawned one worth the same.
	custom_materials = list(
		/datum/material/iron = SHEET_MATERIAL_AMOUNT * 12,
		/datum/material/plastic = SHEET_MATERIAL_AMOUNT * 4,
		/datum/material/silver = SHEET_MATERIAL_AMOUNT * 1,
	)

/datum/design/gun_part_bulldog
	name = "Bulldog Receiver"
	desc = "A machined receiver and drum-feed assembly for a Bulldog shotgun. Not a working gun on its own."
	build_type = PROTOLATHE | AWAY_LATHE
	materials = list(
		/datum/material/iron = SHEET_MATERIAL_AMOUNT * 12,
		/datum/material/plastic = SHEET_MATERIAL_AMOUNT * 4,
		/datum/material/silver = SHEET_MATERIAL_AMOUNT * 1,
	)
	build_path = /obj/item/gun_part/bulldog
	category = list(
		RND_CATEGORY_WEAPONS + RND_SUBCATEGORY_WEAPONS_PARTS,
	)
	departmental_flags = DEPARTMENT_BITFLAG_SECURITY

/datum/design/ammo_m12g
	name = "Shotgun Drum Magazine (12g buckshot)"
	desc = "An 8-round buckshot drum for a Bulldog shotgun."
	build_type = PROTOLATHE | AWAY_LATHE
	materials = list(
		/datum/material/iron = SHEET_MATERIAL_AMOUNT * 6,
		/datum/material/plastic = HALF_SHEET_MATERIAL_AMOUNT * 4,
	)
	build_path = /obj/item/ammo_box/magazine/m12g
	category = list(
		RND_CATEGORY_WEAPONS + RND_SUBCATEGORY_WEAPONS_AMMO,
	)
	departmental_flags = DEPARTMENT_BITFLAG_SECURITY
	// The drum is an upstream type that already ships 15 sheets of iron on itself, which is what a
	// looted one is worth at the ore silo. Rewriting that to match this design would reprice every
	// scavenged Bulldog drum in the world, so the design takes the exemption instead. A printed
	// drum still inherits exactly what it cost, same as before.
	inherit_materials = DESIGN_INHERIT_MATS_SPECIAL

/datum/design/ammo_m12g_slug
	name = "Shotgun Drum Magazine (12g slug)"
	desc = "An 8-round slug drum for a Bulldog shotgun."
	build_type = PROTOLATHE | AWAY_LATHE
	materials = list(
		/datum/material/iron = SHEET_MATERIAL_AMOUNT * 6,
		/datum/material/plastic = HALF_SHEET_MATERIAL_AMOUNT * 4,
	)
	build_path = /obj/item/ammo_box/magazine/m12g/slug
	category = list(
		RND_CATEGORY_WEAPONS + RND_SUBCATEGORY_WEAPONS_AMMO,
	)
	departmental_flags = DEPARTMENT_BITFLAG_SECURITY
	inherit_materials = DESIGN_INHERIT_MATS_SPECIAL // See /datum/design/ammo_m12g above.

/datum/techweb_node/weapon_part_bulldog
	display_name = "Bulldog Schematics"
	description = "Reverse-engineered receiver schematics for the Bulldog shotgun. Unlocks protolathe production of its receiver assembly."
	prerequisite_nodes = list(/datum/techweb_node/exotic_ammo)
	unlocked_designs = list(/datum/design/gun_part_bulldog)
	research_costs = list(TECHWEB_POINT_TYPE_GENERIC = TECHWEB_TIER_4_POINTS)

/datum/techweb_node/weapon_ammo_bulldog
	display_name = "12g Drum Production"
	description = "Bulk 12-gauge drum production for the Bulldog. Prints buckshot and slug drums at the lathe."
	prerequisite_nodes = list(/datum/techweb_node/weapon_part_bulldog)
	unlocked_designs = list(/datum/design/ammo_m12g, /datum/design/ammo_m12g_slug)
	research_costs = list(TECHWEB_POINT_TYPE_GENERIC = TECHWEB_TIER_2_POINTS)
