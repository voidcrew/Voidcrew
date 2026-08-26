/**
 * Laser carbine -- yellow/mid-tier blueprint gun, the first energy schematic.
 *
 * Energy weapons skip the ammo node entirely: the cell recharges at any
 * recharger, which is the point of the carbine. Sustained cheap fire, low
 * per-shot punch. Part node sits mid-depth (prereq Riot Suppression, tier 3).
 */

/obj/item/blueprint/gun/laser_carbine
	name = "weapon schematic (laser carbine)"
	schematic_name = "laser carbine"
	recipe_type = /datum/crafting_recipe/blueprint/gun/laser_carbine
	tier = BLUEPRINT_TIER_YELLOW

/datum/crafting_recipe/blueprint/gun/laser_carbine
	name = "Laser Carbine"
	result = /obj/item/gun/energy/laser/carbine
	reqs = list(
		/obj/item/gun_part/laser_carbine = 1,
		/obj/item/firing_pin = 1,
		/obj/item/stack/sheet/glass = 5,
	)

/obj/item/gun_part/laser_carbine
	name = "laser carbine emitter assembly"
	desc = "The machined emitter and focusing assembly for a laser carbine. You'll need the matching schematic to build it into a working gun."
	icon_state = "laser_carbine"
	// Mirrors /datum/design/gun_part_laser_carbine below.
	custom_materials = list(
		/datum/material/iron = SHEET_MATERIAL_AMOUNT * 8,
		/datum/material/glass = SHEET_MATERIAL_AMOUNT * 4,
		/datum/material/gold = SHEET_MATERIAL_AMOUNT * 1,
	)

/datum/design/gun_part_laser_carbine
	name = "Laser Carbine Emitter Assembly"
	desc = "A machined emitter and focusing assembly for a laser carbine. Not a working gun on its own."
	id = "vc_gun_part_laser_carbine"
	build_type = PROTOLATHE | AWAY_LATHE
	materials = list(
		/datum/material/iron = SHEET_MATERIAL_AMOUNT * 8,
		/datum/material/glass = SHEET_MATERIAL_AMOUNT * 4,
		/datum/material/gold = SHEET_MATERIAL_AMOUNT * 1,
	)
	build_path = /obj/item/gun_part/laser_carbine
	category = list(
		RND_CATEGORY_WEAPONS + RND_SUBCATEGORY_WEAPONS_PARTS,
	)
	departmental_flags = DEPARTMENT_BITFLAG_SECURITY

/datum/techweb_node/weapon_part_laser_carbine
	id = TECHWEB_NODE_WEAPON_PART_CARBINE
	display_name = "Laser Carbine Schematics"
	description = "Emitter schematics for a rapid-cycling laser carbine. Unlocks protolathe production of its emitter assembly. There's no ammunition to research; the cell tops up at any recharger."
	prereq_ids = list(TECHWEB_NODE_RIOT_SUPRESSION)
	design_ids = list("vc_gun_part_laser_carbine")
	research_costs = list(TECHWEB_POINT_TYPE_GENERIC = TECHWEB_TIER_3_POINTS)
