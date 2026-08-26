/**
 * C-20r SMG -- yellow/mid-tier blueprint gun.
 *
 * Part node sits mid-depth (prereq Riot Suppression, tier 3). Same pipeline as
 * the L6 SAW; see guns/l6_saw.dm for the annotated walkthrough.
 */

/obj/item/blueprint/gun/c20r
	name = "weapon schematic (C-20r SMG)"
	schematic_name = "C-20r SMG"
	recipe_type = /datum/crafting_recipe/blueprint/gun/c20r
	tier = BLUEPRINT_TIER_YELLOW

/datum/crafting_recipe/blueprint/gun/c20r
	name = "C-20r SMG"
	result = /obj/item/gun/ballistic/automatic/c20r
	reqs = list(
		/obj/item/gun_part/c20r = 1,
		/obj/item/firing_pin = 1,
		/obj/item/stack/sheet/iron = 5,
	)

/obj/item/gun_part/c20r
	name = "C-20r receiver"
	desc = "The machined receiver assembly for a C-20r submachine gun. You'll need the matching schematic to build it into a working gun."
	icon_state = "c20r"
	// Mirrors /datum/design/gun_part_c20r below.
	custom_materials = list(
		/datum/material/iron = SHEET_MATERIAL_AMOUNT * 10,
		/datum/material/plastic = SHEET_MATERIAL_AMOUNT * 4,
	)

/datum/design/gun_part_c20r
	name = "C-20r Receiver"
	desc = "A machined receiver assembly for a C-20r SMG. Not a working gun on its own."
	id = "vc_gun_part_c20r"
	build_type = PROTOLATHE | AWAY_LATHE
	materials = list(
		/datum/material/iron = SHEET_MATERIAL_AMOUNT * 10,
		/datum/material/plastic = SHEET_MATERIAL_AMOUNT * 4,
	)
	build_path = /obj/item/gun_part/c20r
	category = list(
		RND_CATEGORY_WEAPONS + RND_SUBCATEGORY_WEAPONS_PARTS,
	)
	departmental_flags = DEPARTMENT_BITFLAG_SECURITY

/datum/design/ammo_smgm45
	name = "SMG Magazine (.45)"
	desc = "A .45 box magazine for a C-20r SMG."
	id = "vc_ammo_smgm45"
	build_type = PROTOLATHE | AWAY_LATHE
	materials = list(
		/datum/material/iron = SHEET_MATERIAL_AMOUNT * 4,
		/datum/material/plastic = HALF_SHEET_MATERIAL_AMOUNT * 3,
	)
	build_path = /obj/item/ammo_box/magazine/smgm45
	category = list(
		RND_CATEGORY_WEAPONS + RND_SUBCATEGORY_WEAPONS_AMMO,
	)
	departmental_flags = DEPARTMENT_BITFLAG_SECURITY
	// Upstream magazine, already worth 15 sheets of iron on its own; see
	// /datum/design/ammo_m12g in guns/bulldog.dm for why the design takes the exemption.
	inherit_materials = DESIGN_INHERIT_MATS_SPECIAL

/datum/techweb_node/weapon_part_c20r
	id = TECHWEB_NODE_WEAPON_PART_C20R
	display_name = "C-20r Schematics"
	description = "Reverse-engineered receiver schematics for the C-20r SMG. Unlocks protolathe production of its receiver assembly."
	prereq_ids = list(TECHWEB_NODE_RIOT_SUPRESSION)
	design_ids = list("vc_gun_part_c20r")
	research_costs = list(TECHWEB_POINT_TYPE_GENERIC = TECHWEB_TIER_3_POINTS)

/datum/techweb_node/weapon_ammo_c20r
	id = TECHWEB_NODE_WEAPON_AMMO_C20R
	display_name = ".45 SMG Ammunition"
	description = "Bulk .45 production for the C-20r. Prints magazines at the lathe."
	prereq_ids = list(TECHWEB_NODE_WEAPON_PART_C20R)
	design_ids = list("vc_ammo_smgm45")
	research_costs = list(TECHWEB_POINT_TYPE_GENERIC = TECHWEB_TIER_2_POINTS)
