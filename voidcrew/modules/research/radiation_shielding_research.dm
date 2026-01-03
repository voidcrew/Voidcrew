// Radiation Shielding Research
// Techweb nodes for ship radiation protection upgrades

// ========== TECHWEB NODES ==========

/// Standard radiation shielding - protects crew from Contested zone radiation
/datum/techweb_node/radiation_shielding_standard
	id = TECHWEB_NODE_RADIATION_SHIELDING_STANDARD
	display_name = "Standard Radiation Shielding"
	description = "Hull plating upgrades that protect crew from moderate solar radiation in Contested zones. Automatically applied to all ships linked to this research network."
	prereq_ids = list(TECHWEB_NODE_BASIC_SHUTTLE)
	design_ids = list(
		"radiation_shielding_standard_upgrade",
	)
	research_costs = list(TECHWEB_POINT_TYPE_GENERIC = TECHWEB_TIER_2_POINTS)

/// Heavy radiation shielding - protects crew from Lawless zone radiation
/datum/techweb_node/radiation_shielding_heavy
	id = TECHWEB_NODE_RADIATION_SHIELDING_HEAVY
	display_name = "Heavy Radiation Shielding"
	description = "Reinforced hull plating that protects crew from intense solar radiation in Lawless zones. Automatically applied to all ships linked to this research network."
	prereq_ids = list(TECHWEB_NODE_RADIATION_SHIELDING_STANDARD)
	design_ids = list(
		"radiation_shielding_heavy_upgrade",
	)
	research_costs = list(TECHWEB_POINT_TYPE_GENERIC = TECHWEB_TIER_4_POINTS)

// ========== DESIGN DATUMS ==========
// These are "virtual" designs - researching them triggers the auto-upgrade to linked ships
// They don't produce physical items, they unlock ship capabilities

/datum/design/radiation_shielding_upgrade
	name = "Standard Radiation Shielding Upgrade"
	desc = "A hull and software upgrade that provides protection against moderate solar radiation. Applied automatically to all linked ships when researched."
	id = "radiation_shielding_standard_upgrade"
	build_type = NONE  // Not buildable - this is a passive upgrade
	category = list(RND_CATEGORY_EQUIPMENT)
	departmental_flags = DEPARTMENT_BITFLAG_ENGINEERING | DEPARTMENT_BITFLAG_SCIENCE

/datum/design/radiation_shielding_upgrade/heavy
	name = "Heavy Radiation Shielding Upgrade"
	desc = "A reinforced hull upgrade that provides protection against intense solar radiation. Applied automatically to all linked ships when researched."
	id = "radiation_shielding_heavy_upgrade"
