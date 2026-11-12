/**
 * # Outpost jobs: the fixers
 *
 * Owner: P1. One fixer at each trader outpost, an ambient outpost NPC on a role of its own (spec 2): Nan Tolliver at
 * Halcyon, Lot Brannigan at the Quartermain, Mister Quill at the Undertow. P0 declared the types; every role's
 * `npc_type` is unset, so no fixer comes until P1 sets it (a role with no npc_type never comes).
 */

/// A fixer: talks work through the kingpin's radial (spec 2.3). P1.
/mob/living/carbon/human/npc/ambient_npc/outpost/fixer

/// Nan Tolliver, Waystation Halcyon
/mob/living/carbon/human/npc/ambient_npc/outpost/fixer/nan

/// Lot Brannigan, Quartermain Depot
/mob/living/carbon/human/npc/ambient_npc/outpost/fixer/lot

/// Mister Quill, the Undertow
/mob/living/carbon/human/npc/ambient_npc/outpost/fixer/quill

/// The fixer roles: one each, at its own outpost. The base comes nowhere (no npc_type).
/datum/ambient_outpost_role/fixer
	name = "fixer"
	max_count = 1

/datum/ambient_outpost_role/fixer/nan
	name = "fixer (Halcyon)"
	outpost_types = list(/obj/structure/overmap/trader_outpost/general)

/datum/ambient_outpost_role/fixer/lot
	name = "fixer (Quartermain)"
	outpost_types = list(/obj/structure/overmap/trader_outpost/outfitter)

/datum/ambient_outpost_role/fixer/quill
	name = "fixer (Undertow)"
	outpost_types = list(/obj/structure/overmap/trader_outpost/black_market)
