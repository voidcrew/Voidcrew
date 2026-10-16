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

/datum/techweb_node/weapon_ammo_c20r
	id = TECHWEB_NODE_WEAPON_AMMO_C20R
	display_name = ".45 SMG Ammunition"
	description = "Bulk .45 production for the C-20r."
	prereq_ids = list(TECHWEB_NODE_RIOT_SUPRESSION)
	design_ids = list("vc_ammo_smgm45")
	research_costs = list(TECHWEB_POINT_TYPE_GENERIC = TECHWEB_TIER_2_POINTS)
