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
	zone_permission = ZONE_PERMISSION_ADVANCED
	display_name = "12g Drum Production"
	description = "Bulk buckshot and slug drums for the Bulldog."
	prereq_ids = list(TECHWEB_NODE_EXOTIC_AMMO)
	design_ids = list("vc_ammo_m12g", "vc_ammo_m12g_slug")
	research_costs = list(TECHWEB_POINT_TYPE_GENERIC = TECHWEB_TIER_2_POINTS)

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
	zone_permission = ZONE_PERMISSION_YELLOW
	display_name = ".45 SMG Ammunition"
	description = "Bulk .45 production for the C-20r."
	prereq_ids = list(TECHWEB_NODE_RIOT_SUPRESSION)
	design_ids = list("vc_ammo_smgm45")
	research_costs = list(TECHWEB_POINT_TYPE_GENERIC = TECHWEB_TIER_2_POINTS)

/datum/design/ammo_m7mm
	name = "Machine Gun Magazine (7mm)"
	desc = "A box magazine of 7mm ammunition for an L6 SAW."
	id = "vc_ammo_m7mm"
	build_type = PROTOLATHE | AWAY_LATHE
	// Sustained SAW fire consumes mining resources on every reload. At full
	// efficiency this still costs 20 iron, 4 titanium, 4 plasma and 2 plastic.
	materials = list(
		/datum/material/iron = SHEET_MATERIAL_AMOUNT * 50,
		/datum/material/titanium = SHEET_MATERIAL_AMOUNT * 10,
		/datum/material/plasma = SHEET_MATERIAL_AMOUNT * 10,
		/datum/material/plastic = SHEET_MATERIAL_AMOUNT * 5,
	)
	build_path = /obj/item/ammo_box/magazine/m7mm
	category = list(
		RND_CATEGORY_WEAPONS + RND_SUBCATEGORY_WEAPONS_AMMO,
	)
	departmental_flags = DEPARTMENT_BITFLAG_SECURITY

// --- Techweb nodes -----------------------------------------------------------

/datum/techweb_node/weapon_ammo_l6_saw
	id = TECHWEB_NODE_WEAPON_AMMO_L6_SAW
	zone_permission = ZONE_PERMISSION_ADVANCED
	display_name = "7mm Machine Gun Ammunition"
	description = "Belt-fed 7mm production for the L6 SAW."
	prereq_ids = list(TECHWEB_NODE_EXOTIC_AMMO, TECHWEB_NODE_AUTOMATIC_AMMO)
	design_ids = list("vc_ammo_m7mm")
	research_costs = list(TECHWEB_POINT_TYPE_GENERIC = TECHWEB_TIER_2_POINTS)

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
	zone_permission = ZONE_PERMISSION_ADVANCED
	display_name = ".50 BMG Ammunition"
	description = "Bulk .50 BMG production for the anti-materiel rifle."
	prereq_ids = list(TECHWEB_NODE_EXOTIC_AMMO)
	design_ids = list("vc_ammo_sniper_rounds")
	research_costs = list(TECHWEB_POINT_TYPE_GENERIC = TECHWEB_TIER_2_POINTS)

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
	zone_permission = ZONE_PERMISSION_YELLOW
	display_name = "4.6x30mm Ammunition"
	description = "Bulk 4.6x30mm production for the WT-550."
	prereq_ids = list(TECHWEB_NODE_RIOT_SUPRESSION)
	design_ids = list("vc_ammo_wt550")
	research_costs = list(TECHWEB_POINT_TYPE_GENERIC = TECHWEB_TIER_2_POINTS)
