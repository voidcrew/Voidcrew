/datum/techweb_node
	/// Standing required for direct research only; imported knowledge remains usable.
	var/zone_permission = ZONE_PERMISSION_PUBLIC
	// list(
	// 	nebulas = 0,
	// 	asteroids = 0,
	// 	electric_storms = 0,
	// 	emp_storms = 0,
	// 	planets = 0,
	// 	stars = 0,
	// )
	var/list/required_surveyed_objects

/// Prices are per-web copies: discounts must never make a debit negative or alter global nodes.
/datum/techweb_node/get_price(datum/techweb/host)
	var/list/prices = ..()
	prices = prices.Copy()
	for(var/point_type in prices)
		prices[point_type] = max(0, prices[point_type])
	return prices

/datum/techweb_node/electric_weapons
	zone_permission = ZONE_PERMISSION_YELLOW

/datum/techweb_node/beam_weapons
	zone_permission = ZONE_PERMISSION_ADVANCED

/datum/techweb_node/syndicate_basic
	zone_permission = ZONE_PERMISSION_ELITE

/datum/techweb_node/unregulated_bluespace
	zone_permission = ZONE_PERMISSION_ELITE

// Vex sells these boards at the same step; the printers shouldn't be an open back door
/datum/techweb_node/ship_combat_shields
	zone_permission = ZONE_PERMISSION_ADVANCED

/datum/techweb_node/ship_combat_interdictor
	zone_permission = ZONE_PERMISSION_ADVANCED

/datum/techweb_node/ship_combat_siphon
	zone_permission = ZONE_PERMISSION_ADVANCED

/datum/techweb_node/ship_combat_ew
	zone_permission = ZONE_PERMISSION_ADVANCED

// Combat mechs follow the guns they carry. The plain plates, disabler and repair droid moved to
// Expedition Equipment in techweb_nodes.dm so they stay open.
/datum/techweb_node/mech_combat
	zone_permission = ZONE_PERMISSION_YELLOW

/datum/techweb_node/mech_assault
	zone_permission = ZONE_PERMISSION_ADVANCED

/datum/techweb_node/mech_infiltrator
	zone_permission = ZONE_PERMISSION_ADVANCED

// Its reputation gate comes from Electric Weaponry and Combat Exosuits behind it.
/datum/techweb_node/mech_firearms
	research_costs = list(TECHWEB_POINT_TYPE_GENERIC = TECHWEB_TIER_4_POINTS)

/datum/techweb_node/night_vision
	zone_permission = ZONE_PERMISSION_YELLOW

/datum/techweb_node/riot_supression
	zone_permission = ZONE_PERMISSION_YELLOW

// Upstream hangs Explosives, and so Exotic Ammunition, off Riot Supression. The pyro casing, .38 TRAC,
// True Strike and flechettes are public gear, so the branch starts from Security Equipment instead.
/datum/techweb_node/explosives
	prereq_ids = list(TECHWEB_NODE_SEC_EQUIP)

/datum/techweb_node/exotic_ammo
	description = "Tracking and ricochet rounds for .38s, and flechette shells."

/datum/techweb_node/cyber/combat_implants
	zone_permission = ZONE_PERMISSION_ADVANCED

// Same reason: the toolset, surgery arm and nutriment plus don't belong behind the reviver.
/datum/techweb_node/cyber/integrated_toolsets
	prereq_ids = list(TECHWEB_NODE_CYBER_IMPLANTS, TECHWEB_NODE_EXP_TOOLS)
