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
	display_name = "7mm Machine Gun Ammunition"
	description = "Belt-fed 7mm production for the L6 SAW."
	prereq_ids = list(TECHWEB_NODE_EXOTIC_AMMO, TECHWEB_NODE_AUTOMATIC_AMMO)
	design_ids = list("vc_ammo_m7mm")
	research_costs = list(TECHWEB_POINT_TYPE_GENERIC = TECHWEB_TIER_2_POINTS)
