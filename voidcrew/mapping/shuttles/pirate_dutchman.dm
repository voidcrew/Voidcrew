/**
 * TG Pirate Ship (Flying Dutchman) - Dutchman-class
 * Undead skeleton crew seeking booty. Heavy threat.
 */
/datum/map_template/shuttle/voidcrew/pirate_dutchman
	name = "Dutchman-class Ghostship"
	suffix = "pirate_dutchman"
	short_name = "Dutchman-class"
	part_requirements = list(PART_CLASS_COMBAT = 2)

	job_slots = list(
		list(
			name = "Captain",
			officer = TRUE,
			outfit = /datum/outfit/job/captain/pirate,
			category = JOB_CAT_COMMAND,
			slots = 1,
		),
		list(
			name = "First Mate",
			outfit = /datum/outfit/job/hop/pirate,
			category = JOB_CAT_COMMAND,
			slots = 1,
		),
		list(
			name = "Buccaneer",
			outfit = /datum/outfit/job/security/pirate,
			category = JOB_CAT_SECURITY,
			slots = 3,
		),
		list(
			name = "Deckhand",
			outfit = /datum/outfit/job/assistant/pirate,
			category = JOB_CAT_ASSISTANT,
			slots = 3,
		),
	)

/// DOCKING PORT ///

/obj/docking_port/mobile/voidcrew/pirate_dutchman
	name = "Dutchman-class Ghostship"
	area_type = /area/shuttle/voidcrew/pirate_dutchman
	// The galleon has no airlock - the whole deck is open to space - so the port sits on
	// the bowsprit tip at (11,25), aimed inboard. That is the bow, hence NORTH.
	port_direction = 1
	// 21 abeam against 25 fore to aft, so adjust_reserve_dock_to_shuttle's aspect-ratio
	// guess comes out EAST. This must match it or the ship spins 270 degrees on every
	// dock. It was SOUTH on the map instance and WEST here, and did exactly that.
	preferred_direction = 4

/// AREAS ///

/area/shuttle/voidcrew/pirate_dutchman
	name = "Dutchman-class Ghostship"

/area/shuttle/voidcrew/pirate_dutchman/bridge
	name = "Bridge"
	icon_state = "bridge"

/area/shuttle/voidcrew/pirate_dutchman/cargo
	name = "Cargo Hold"
	icon_state = "cargo_warehouse"

/area/shuttle/voidcrew/pirate_dutchman/commons
	name = "Commons"
	icon_state = "station"

/area/shuttle/voidcrew/pirate_dutchman/engineering
	name = "Engineering"
	icon_state = "engine"
