/**
 * # Player Outpost Shells
 *
 * The pre-built starting structures a founder picks from when using their
 * deed. Each shell is a small .dmm loaded onto the outpost's fresh z-level;
 * the owner expands outward from it via the construction console or by hand.
 *
 * Shell requirements (enforced by convention, checked by link_interior_machinery):
 * - exactly one /obj/machinery/computer/player_outpost_management
 * - exactly one /obj/machinery/computer/camera_advanced/base_construction/ship/outpost
 * - one /obj/machinery/ore_silo (feeds the construction console's internal tools)
 * - one /obj/effect/landmark/player_outpost_arrival
 * - airlocks on each cardinal side (visitors walk in from the docks via EVA)
 * - pressurized core, lights
 */

/area/voidcrew/player_outpost
	name = "\improper Player Outpost"
	icon_state = "away"
	static_lighting = TRUE
	requires_power = FALSE
	default_gravity = STANDARD_GRAVITY
	// No UNIQUE_AREA: every shell load must instantiate its own area so
	// multiple player outposts don't share one area datum
	area_flags = NOTELEPORT
	flags_1 = NONE
	ambience_index = AMBIENCE_AWAY

/// Marks where visitors and the construction drone arrive; consumed at load
/obj/effect/landmark/player_outpost_arrival
	name = "player outpost arrival"

// Base type is abstract: no mappath
/datum/map_template/player_outpost
	name = "Outpost Shell"
	/// Short blurb shown on the founding catalog
	var/catalog_desc = ""

/datum/map_template/player_outpost/small
	name = "Compact Habitat"
	catalog_desc = "A snug pressurized module: one room, the essential consoles, and not much else. Cheap on materials, quick to expand."
	mappath = "voidcrew/_maps/map_files/outposts/player_outpost_shell_small.dmm"

/datum/map_template/player_outpost/medium
	name = "Waystation Frame"
	catalog_desc = "A proper station core with separated work and living space. More floor to hold down, more room to grow into."
	mappath = "voidcrew/_maps/map_files/outposts/player_outpost_shell_medium.dmm"
