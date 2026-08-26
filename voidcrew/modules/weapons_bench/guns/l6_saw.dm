/**
 * L6 SAW -- red-tier blueprint gun (the design doc's running example).
 *
 * Pipeline, all in one place:
 *   1. Schematic (below)            -- ruin loot / black-market SKU; carrying it (or a neural imprint) puts the recipe in your crafting menu
 *   2. Part node -> part design     -- deep node (prereq Exotic Ammunition, tier 4); part prints at the protolathe
 *   3. Ammo node -> ammo design     -- shallow node after the part node; mag prints at the lathe
 *   4. Crafting menu, anywhere -- part + firing pin + sheets => the gun
 */

// --- Schematic + recipe + part -----------------------------------------------

/obj/item/blueprint/gun/l6_saw
	name = "weapon schematic (L6 SAW)"
	schematic_name = "L6 SAW"
	recipe_type = /datum/crafting_recipe/blueprint/gun/l6_saw
	tier = BLUEPRINT_TIER_RED

/datum/crafting_recipe/blueprint/gun/l6_saw
	name = "L6 SAW"
	result = /obj/item/gun/ballistic/automatic/l6_saw
	reqs = list(
		/obj/item/gun_part/l6_saw = 1,
		/obj/item/firing_pin = 1,
		/obj/item/stack/sheet/iron = 8,
	)

/obj/item/gun_part/l6_saw
	name = "L6 SAW receiver"
	desc = "The machined receiver assembly for an L6 SAW light machine gun. You'll need the matching schematic to build it into a working gun."
	icon_state = "l6"
	// Mirrors /datum/design/gun_part_l6_saw below.
	custom_materials = list(
		/datum/material/iron = SHEET_MATERIAL_AMOUNT * 15,
		/datum/material/plastic = SHEET_MATERIAL_AMOUNT * 5,
		/datum/material/silver = SHEET_MATERIAL_AMOUNT * 2,
	)

// --- Protolathe part design --------------------------------------------------

/datum/design/gun_part_l6_saw
	name = "L6 SAW Receiver"
	desc = "A machined receiver assembly for an L6 SAW. Not a working gun on its own."
	id = "vc_gun_part_l6_saw"
	build_type = PROTOLATHE | AWAY_LATHE
	materials = list(
		/datum/material/iron = SHEET_MATERIAL_AMOUNT * 15,
		/datum/material/plastic = SHEET_MATERIAL_AMOUNT * 5,
		/datum/material/silver = SHEET_MATERIAL_AMOUNT * 2,
	)
	build_path = /obj/item/gun_part/l6_saw
	category = list(
		RND_CATEGORY_WEAPONS + RND_SUBCATEGORY_WEAPONS_PARTS,
	)
	departmental_flags = DEPARTMENT_BITFLAG_SECURITY

// --- Lathe ammo design -------------------------------------------------------

/datum/design/ammo_m7mm
	name = "Machine Gun Magazine (7mm)"
	desc = "A box magazine of 7mm rounds for an L6 SAW."
	id = "vc_ammo_m7mm"
	build_type = PROTOLATHE | AWAY_LATHE
	materials = list(
		/datum/material/iron = SHEET_MATERIAL_AMOUNT * 6,
		/datum/material/plastic = HALF_SHEET_MATERIAL_AMOUNT * 4,
	)
	build_path = /obj/item/ammo_box/magazine/m7mm
	category = list(
		RND_CATEGORY_WEAPONS + RND_SUBCATEGORY_WEAPONS_AMMO,
	)
	departmental_flags = DEPARTMENT_BITFLAG_SECURITY
	// Upstream magazine, already worth 15 sheets of iron on its own; see
	// /datum/design/ammo_m12g in guns/bulldog.dm for why the design takes the exemption.
	inherit_materials = DESIGN_INHERIT_MATS_SPECIAL

// --- Techweb nodes -----------------------------------------------------------

/datum/techweb_node/weapon_part_l6_saw
	id = TECHWEB_NODE_WEAPON_PART_L6_SAW
	display_name = "L6 SAW Schematics"
	description = "Reverse-engineered receiver schematics for the L6 SAW. Unlocks protolathe production of its receiver assembly, the hard half of the gun."
	prereq_ids = list(TECHWEB_NODE_EXOTIC_AMMO)
	design_ids = list("vc_gun_part_l6_saw")
	research_costs = list(TECHWEB_POINT_TYPE_GENERIC = TECHWEB_TIER_4_POINTS)

/datum/techweb_node/weapon_ammo_l6_saw
	id = TECHWEB_NODE_WEAPON_AMMO_L6_SAW
	display_name = "7mm Machine Gun Ammunition"
	description = "Belt-fed 7mm production for the L6 SAW. Prints magazines at the lathe."
	prereq_ids = list(TECHWEB_NODE_WEAPON_PART_L6_SAW)
	design_ids = list("vc_ammo_m7mm")
	research_costs = list(TECHWEB_POINT_TYPE_GENERIC = TECHWEB_TIER_2_POINTS)
