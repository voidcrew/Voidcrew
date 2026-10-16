/datum/design/ammo_sniper_rounds
	name = "Sniper Magazine (.50 BMG)"
	desc = "A magazine of .50 BMG cartridges for an anti-materiel rifle."
	id = "vc_ammo_sniper_rounds"
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

/datum/techweb_node/weapon_ammo_sniper_rifle
	id = TECHWEB_NODE_WEAPON_AMMO_SNIPER
	display_name = ".50 BMG Ammunition"
	description = "Bulk .50 BMG production for the anti-materiel rifle."
	prereq_ids = list(TECHWEB_NODE_EXOTIC_AMMO)
	design_ids = list("vc_ammo_sniper_rounds")
	research_costs = list(TECHWEB_POINT_TYPE_GENERIC = TECHWEB_TIER_2_POINTS)
