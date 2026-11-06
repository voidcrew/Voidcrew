/// Backgrounds: owned by M4. See data/backgrounds/spec.md.

// Fixed NPC freighter: no slots, themes or cryopods. SSnpc_ships loads it for P5's haulers, and
// unit tests load it as a crewless player hull. The crew spawns on /obj/effect/landmark/hauler/crew.
/datum/map_template/shuttle/voidcrew/hauler
	name = "Mule-class Freighter"
	short_name = "Mule-class"
	suffix = "hauler"
	catalog_desc = "A slow freighter with a big hold and a small crew."
	part_requirements = list()

	job_slots = list(
		list(
			name = "Skipper",
			officer = TRUE,
			outfit = /datum/outfit/job/captain,
			category = JOB_CAT_COMMAND,
			slots = 1,
		),
	)

/// DOCKING PORT ///

/obj/docking_port/mobile/voidcrew/hauler
	name = "Mule-class Freighter"
	area_type = /area/shuttle/voidcrew/hauler
	// Bow east, port mapped dir NORTH on the south face (like the Kilo turned around): the hull is
	// longer fore-to-aft than abeam, so adjust_reserve_dock_to_shuttle() guesses EAST.
	port_direction = 8
	preferred_direction = 4 // must match the aspect-ratio guess in adjust_reserve_dock_to_shuttle or the ship spins every dock

/// AREAS ///

/area/shuttle/voidcrew/hauler
	name = "Mule-class Freighter"
	icon_state = "station"

/area/shuttle/voidcrew/hauler/bridge
	name = "Bridge"
	icon_state = "bridge"

/area/shuttle/voidcrew/hauler/hold
	name = "Hold"
	icon_state = "cargo_bay"

/area/shuttle/voidcrew/hauler/engineering
	name = "Engineering"
	icon_state = "engine"
