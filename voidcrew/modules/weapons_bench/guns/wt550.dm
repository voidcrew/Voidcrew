/**
 * WT-550 autorifle -- yellow/mid-tier blueprint gun.
 *
 * The lawful counterpart to the C-20r. Part node sits mid-depth (prereq Riot
 * Suppression, tier 3); see guns/l6_saw.dm for the annotated walkthrough.
 */

/obj/item/blueprint/gun/wt550
	name = "weapon schematic (WT-550 autorifle)"
	schematic_name = "WT-550 autorifle"
	recipe_type = /datum/crafting_recipe/blueprint/gun/wt550
	tier = BLUEPRINT_TIER_YELLOW

/datum/crafting_recipe/blueprint/gun/wt550
	name = "WT-550 Autorifle"
	result = /obj/item/gun/ballistic/automatic/wt550
	reqs = list(
		/obj/item/gun_part/wt550 = 1,
		/obj/item/firing_pin = 1,
		/obj/item/stack/sheet/iron = 5,
	)

/obj/item/gun_part/wt550
	name = "WT-550 receiver"
	desc = "The machined receiver assembly for a WT-550 autorifle. You'll need the matching schematic to build it into a working gun."
	icon_state = "wt550"

/datum/design/gun_part_wt550
	name = "WT-550 Receiver"
	desc = "A machined receiver assembly for a WT-550 autorifle. Not a working gun on its own."
	id = "vc_gun_part_wt550"
	build_type = PROTOLATHE | AWAY_LATHE
	materials = list(
		/datum/material/iron = SHEET_MATERIAL_AMOUNT * 10,
		/datum/material/plastic = SHEET_MATERIAL_AMOUNT * 4,
	)
	build_path = /obj/item/gun_part/wt550
	category = list(
		RND_CATEGORY_WEAPONS + RND_SUBCATEGORY_WEAPONS_PARTS,
	)
	departmental_flags = DEPARTMENT_BITFLAG_SECURITY

/datum/design/ammo_wt550
	name = "Autorifle Magazine (4.6x30mm)"
	desc = "A 20-round 4.6x30mm magazine for a WT-550 autorifle."
	id = "vc_ammo_wt550"
	build_type = PROTOLATHE | AWAY_LATHE
	materials = list(
		/datum/material/iron = SHEET_MATERIAL_AMOUNT * 4,
		/datum/material/plastic = HALF_SHEET_MATERIAL_AMOUNT * 3,
	)
	build_path = /obj/item/ammo_box/magazine/wt550m9
	category = list(
		RND_CATEGORY_WEAPONS + RND_SUBCATEGORY_WEAPONS_AMMO,
	)
	departmental_flags = DEPARTMENT_BITFLAG_SECURITY

/datum/techweb_node/weapon_part_wt550
	id = TECHWEB_NODE_WEAPON_PART_WT550
	display_name = "WT-550 Schematics"
	description = "Licensed receiver schematics for the WT-550 autorifle. Unlocks protolathe production of its receiver assembly."
	prereq_ids = list(TECHWEB_NODE_RIOT_SUPRESSION)
	design_ids = list("vc_gun_part_wt550")
	research_costs = list(TECHWEB_POINT_TYPE_GENERIC = TECHWEB_TIER_3_POINTS)

/datum/techweb_node/weapon_ammo_wt550
	id = TECHWEB_NODE_WEAPON_AMMO_WT550
	display_name = "4.6x30mm Ammunition"
	description = "Bulk 4.6x30mm production for the WT-550. Prints magazines at the lathe."
	prereq_ids = list(TECHWEB_NODE_WEAPON_PART_WT550)
	design_ids = list("vc_ammo_wt550")
	research_costs = list(TECHWEB_POINT_TYPE_GENERIC = TECHWEB_TIER_2_POINTS)
