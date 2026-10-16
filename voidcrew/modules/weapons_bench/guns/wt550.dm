/datum/design/ammo_wt550
	name = "Autorifle Magazine (4.6x30mm)"
	desc = "A 4.6x30mm magazine for a WT-550 autorifle."
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

/datum/techweb_node/weapon_ammo_wt550
	id = TECHWEB_NODE_WEAPON_AMMO_WT550
	display_name = "4.6x30mm Ammunition"
	description = "Bulk 4.6x30mm production for the WT-550."
	prereq_ids = list(TECHWEB_NODE_RIOT_SUPRESSION)
	design_ids = list("vc_ammo_wt550")
	research_costs = list(TECHWEB_POINT_TYPE_GENERIC = TECHWEB_TIER_2_POINTS)
