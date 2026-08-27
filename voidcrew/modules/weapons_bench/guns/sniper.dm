/**
 * Anti-materiel sniper rifle -- red/deep-tier blueprint gun.
 *
 * Part node sits deep (prereq Exotic Ammunition, tier 4). Same pipeline as the
 * L6 SAW; see guns/l6_saw.dm for the annotated walkthrough.
 */

/obj/item/blueprint/gun/sniper_rifle
	name = "weapon schematic (anti-materiel rifle)"
	schematic_name = "anti-materiel sniper rifle"
	recipe_type = /datum/crafting_recipe/blueprint/gun/sniper_rifle
	tier = BLUEPRINT_TIER_RED

/datum/crafting_recipe/blueprint/gun/sniper_rifle
	name = "Anti-Materiel Sniper Rifle"
	result = /obj/item/gun/ballistic/rifle/sniper_rifle
	reqs = list(
		/obj/item/gun_part/sniper_rifle = 1,
		/obj/item/firing_pin = 1,
		/obj/item/stack/sheet/iron = 8,
	)

/obj/item/gun_part/sniper_rifle
	name = "anti-materiel rifle receiver"
	desc = "The machined receiver and bolt assembly for an anti-materiel sniper rifle. You'll need the matching schematic to build it into a working gun."
	icon_state = "sniper"
	// Mirrors /datum/design/gun_part_sniper_rifle below.
	custom_materials = list(
		/datum/material/iron = SHEET_MATERIAL_AMOUNT * 18,
		/datum/material/plastic = SHEET_MATERIAL_AMOUNT * 4,
		/datum/material/silver = SHEET_MATERIAL_AMOUNT * 3,
	)

/datum/design/gun_part_sniper_rifle
	name = "Anti-Materiel Rifle Receiver"
	desc = "A machined receiver and bolt assembly for an anti-materiel sniper rifle. Not a working gun on its own."
	build_type = PROTOLATHE | AWAY_LATHE
	materials = list(
		/datum/material/iron = SHEET_MATERIAL_AMOUNT * 18,
		/datum/material/plastic = SHEET_MATERIAL_AMOUNT * 4,
		/datum/material/silver = SHEET_MATERIAL_AMOUNT * 3,
	)
	build_path = /obj/item/gun_part/sniper_rifle
	category = list(
		RND_CATEGORY_WEAPONS + RND_SUBCATEGORY_WEAPONS_PARTS,
	)
	departmental_flags = DEPARTMENT_BITFLAG_SECURITY

/datum/design/ammo_sniper_rounds
	name = "Sniper Magazine (.50 BMG)"
	desc = "A magazine of .50 BMG cartridges for an anti-materiel rifle."
	build_type = PROTOLATHE | AWAY_LATHE
	materials = list(
		/datum/material/iron = SHEET_MATERIAL_AMOUNT * 8,
		/datum/material/plastic = HALF_SHEET_MATERIAL_AMOUNT * 4,
	)
	build_path = /obj/item/ammo_box/magazine/sniper_rounds
	category = list(
		RND_CATEGORY_WEAPONS + RND_SUBCATEGORY_WEAPONS_AMMO,
	)
	departmental_flags = DEPARTMENT_BITFLAG_SECURITY
	// Upstream magazine, already worth 15 sheets of iron on its own; see
	// /datum/design/ammo_m12g in guns/bulldog.dm for why the design takes the exemption.
	inherit_materials = DESIGN_INHERIT_MATS_SPECIAL

/datum/techweb_node/weapon_part_sniper_rifle
	display_name = "Anti-Materiel Rifle Schematics"
	description = "Reverse-engineered receiver schematics for an anti-materiel sniper rifle. Unlocks protolathe production of its receiver assembly."
	prerequisite_nodes = list(/datum/techweb_node/exotic_ammo)
	unlocked_designs = list(/datum/design/gun_part_sniper_rifle)
	research_costs = list(TECHWEB_POINT_TYPE_GENERIC = TECHWEB_TIER_4_POINTS)

/datum/techweb_node/weapon_ammo_sniper_rifle
	display_name = ".50 BMG Ammunition"
	description = "Bulk .50 BMG production for the anti-materiel rifle. Prints magazines at the lathe."
	prerequisite_nodes = list(/datum/techweb_node/weapon_part_sniper_rifle)
	unlocked_designs = list(/datum/design/ammo_sniper_rounds)
	research_costs = list(TECHWEB_POINT_TYPE_GENERIC = TECHWEB_TIER_2_POINTS)
