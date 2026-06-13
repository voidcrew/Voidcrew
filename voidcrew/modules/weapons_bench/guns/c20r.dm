/**
 * C-20r SMG -- yellow/mid-tier blueprint gun.
 *
 * Part node sits mid-depth (prereq Riot Suppression, tier 3). Same pipeline as
 * the L6 SAW; see guns/l6_saw.dm for the annotated walkthrough.
 */

/obj/item/gun_blueprint/c20r
	name = "weapon blueprint (C-20r SMG)"
	blueprint_name = "C-20r SMG"
	result_path = /obj/item/gun/ballistic/automatic/c20r
	required_part = /obj/item/gun_part/c20r

/obj/item/gun_part/c20r
	name = "C-20r receiver"
	desc = "The machined receiver assembly for a C-20r submachine gun. Assemble it at a weapons bench with the C-20r blueprint and a firing pin."
	icon_state = "c20r"

/datum/design/gun_part_c20r
	name = "C-20r Receiver"
	desc = "A machined receiver assembly for a C-20r SMG. Inert until assembled at a weapons bench."
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
