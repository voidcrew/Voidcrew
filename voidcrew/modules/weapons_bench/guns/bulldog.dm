/datum/design/ammo_m12g
	name = "Shotgun Drum Magazine (12g buckshot)"
	desc = "A buckshot drum for a Bulldog shotgun."
	id = "vc_ammo_m12g"
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

/datum/design/ammo_m12g_slug
	name = "Shotgun Drum Magazine (12g slug)"
	desc = "A slug drum for a Bulldog shotgun."
	id = "vc_ammo_m12g_slug"
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

/datum/techweb_node/weapon_ammo_bulldog
	id = TECHWEB_NODE_WEAPON_AMMO_BULLDOG
	display_name = "12g Drum Production"
	description = "Bulk buckshot and slug drums for the Bulldog."
	prereq_ids = list(TECHWEB_NODE_EXOTIC_AMMO)
	design_ids = list("vc_ammo_m12g", "vc_ammo_m12g_slug")
	research_costs = list(TECHWEB_POINT_TYPE_GENERIC = TECHWEB_TIER_2_POINTS)
