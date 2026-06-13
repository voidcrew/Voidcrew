/**
 * L6 SAW -- red-tier blueprint gun (the design doc's running example).
 *
 * Pipeline, all in one place:
 *   1. Blueprint (below)            -- ruin loot / black-market SKU (wired in the channels pass)
 *   2. Part node -> part design     -- deep node (prereq Exotic Ammunition, tier 4); part prints at the protolathe
 *   3. Ammo node -> ammo design     -- shallow node after the part node; mag prints at the lathe
 *   4. Weapons bench                -- blueprint + part + firing pin => the gun
 */

// --- Blueprint + part item ---------------------------------------------------

/obj/item/gun_blueprint/l6_saw
	name = "weapon blueprint (L6 SAW)"
	blueprint_name = "L6 SAW"
	result_path = /obj/item/gun/ballistic/automatic/l6_saw
	required_part = /obj/item/gun_part/l6_saw

/obj/item/gun_part/l6_saw
	name = "L6 SAW receiver"
	desc = "The machined receiver assembly for an L6 SAW light machine gun. Plug it into a weapons assembly bench with the L6 SAW blueprint and a firing pin to build the weapon."
	icon_state = "l6"

// --- Protolathe part design --------------------------------------------------

/datum/design/gun_part_l6_saw
	name = "L6 SAW Receiver"
	desc = "A machined receiver assembly for an L6 SAW. Inert until assembled at a weapons bench."
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

// --- Techweb nodes -----------------------------------------------------------

/datum/techweb_node/weapon_part_l6_saw
	id = TECHWEB_NODE_WEAPON_PART_L6_SAW
	display_name = "L6 SAW Schematics"
	description = "Reverse-engineered receiver schematics for the L6 SAW. Unlocks protolathe production of its receiver assembly -- the gated half of the gun."
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
