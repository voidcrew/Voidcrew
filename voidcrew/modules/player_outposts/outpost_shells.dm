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
 * - one ordinary cargo console, bank terminal and resident cryopod on accessible
 *   interior floors (install_home_bundle binds them without spawning stock)
 * - one /obj/effect/landmark/player_outpost_arrival
 * - a hangar elevator kit on the north side: 3x3 /obj/effect/landmark/outpost_elevator_alcove
 *   with one /obj/machinery/outpost_elevator/directional panel, so visiting ships
 *   get hangar berths from the moment of founding (see outpost_hangar.dm)
 * - external airlocks on the remaining cardinal sides (EVA walk-in stays possible)
 * - pressurized core, lights
 * - a starter power bay: APC + cable, charged SMES with input terminal, and an
 *   unanchored portable generator with fuel, the area requires power, so when
 *   the SMES buffer drains the owner keeps the generator fed or goes dark
 *
 * The bare-claim shell deliberately breaks all of these: it ships nothing but a
 * pad, the arrival landmark and a crate of console boards. Everything the
 * linker doesn't find is simply absent until the owner builds it (rebuilt
 * consoles relink themselves; see outpost_management.dm / outpost_construction.dm).
 */

/area/voidcrew/player_outpost
	name = "\improper Player Outpost"
	icon_state = "away"
	static_lighting = TRUE
	default_gravity = STANDARD_GRAVITY
	// No UNIQUE_AREA: every shell load must instantiate its own area so
	// multiple player outposts don't share one area datum
	area_flags = NOTELEPORT
	flags_1 = NONE
	ambience_index = AMBIENCE_AWAY
	repels_megafauna = TRUE // voidcrew/area/megafauna_ban.dm

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
	catalog_desc = "A compact, single-room habitat."
	mappath = "voidcrew/_maps/map_files/outposts/player_outpost_shell_small.dmm"

/datum/map_template/player_outpost/medium
	name = "Waystation Frame"
	catalog_desc = "Separate living quarters and workshop around a central hall."
	mappath = "voidcrew/_maps/map_files/outposts/player_outpost_shell_medium.dmm"

/datum/map_template/player_outpost/nothing
	name = "Bare Claim"
	catalog_desc = "No prefab at all: an empty sector, a survey pad, and a crate holding the registry console boards. Bring your own everything."
	mappath = "voidcrew/_maps/map_files/outposts/player_outpost_shell_nothing.dmm"

/// The bare claim's entire inheritance: the two registry console boards.
/// Everything else (frames, materials, the silo, air) is the owner's problem.
/obj/structure/closet/crate/player_outpost_start
	name = "colonial registry claim crate"
	desc = "The colonial registry's idea of a starter kit: the circuit boards for an outpost's management and construction consoles, and a packing slip wishing you luck."

/obj/structure/closet/crate/player_outpost_start/PopulateContents()
	. = ..()
	new /obj/item/circuitboard/computer/player_outpost_management(src)
	new /obj/item/circuitboard/computer/player_outpost_construction(src)
	new /obj/item/paper/fluff/player_outpost_claim(src)

/obj/item/paper/fluff/player_outpost_claim
	name = "packing slip"
	default_raw_text = "CONTENTS: outpost management console board (1), outpost construction console board (1). The Colonial Registry congratulates you on your new claim and reminds you that unimproved sectors carry no warranty, atmosphere, or floor. Good luck."
