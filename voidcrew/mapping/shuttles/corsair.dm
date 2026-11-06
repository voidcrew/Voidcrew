/**
 * Corsair-class Raider
 *
 * * The pirate background's hull: never on the shelf, never in the Spacefarer roll
 * * Nose east, engines aft (west), boarding hatch and docking port on the north face
 * * One upgrade slot: corsair_hold (5x4 enclosed room, see ships/corsair.dm)
 * * 2 themes: Rogue (dark plastitanium, default) and Privateer (rust and plating)
 * * The bare hull flies as spawned: helm, power, cryopods and the combat kit are all
 *   on the hull; the gun deck's APC powers the turrets, launcher, interdictor and siphon
 */
/datum/map_template/shuttle/voidcrew/corsair
	name = "Corsair-class Raider"
	short_name = "Corsair-class"
	suffix = "corsair_a" // Default suffix, overridden by selected theme
	catalog_desc = "A fast raider with teeth: lasers, a missile tube, an interdictor and a siphon rig."
	part_requirements = list()
	has_upgrade_slots = TRUE
	upgrade_slot_ids = list("corsair_hold")
	available_themes = list("rogue", "privateer")
	background_start = BACKGROUND_PIRATE
	// job_slots come from the selected theme, not defined here

/// DOCKING PORT ///

/obj/docking_port/mobile/voidcrew/corsair
	name = "Corsair-class Raider"
	area_type = /area/shuttle/voidcrew/corsair
	port_direction = 8
	preferred_direction = 4 // must match the aspect-ratio guess in adjust_reserve_dock_to_shuttle or the ship spins every dock

/obj/docking_port/mobile/voidcrew/corsair/a
	name = "Corsair-class Raider A"

/obj/docking_port/mobile/voidcrew/corsair/b
	name = "Corsair-class Raider B"

/// AREAS ///

/area/shuttle/voidcrew/corsair
	name = "Corsair-class Raider"
	icon_state = "station"

/area/shuttle/voidcrew/corsair/bridge
	name = "Bridge"
	icon_state = "bridge"

/area/shuttle/voidcrew/corsair/bridge/a

/area/shuttle/voidcrew/corsair/bridge/b

/area/shuttle/voidcrew/corsair/gunnery
	name = "Gunnery"
	icon_state = "bridge"

/area/shuttle/voidcrew/corsair/gunnery/a

/area/shuttle/voidcrew/corsair/gunnery/b

/area/shuttle/voidcrew/corsair/crew
	name = "Crew Quarters"
	icon_state = "dorms"

/area/shuttle/voidcrew/corsair/crew/a

/area/shuttle/voidcrew/corsair/crew/b

/area/shuttle/voidcrew/corsair/engineering
	name = "Engineering"
	icon_state = "engine"

/area/shuttle/voidcrew/corsair/engineering/a

/area/shuttle/voidcrew/corsair/engineering/b

/area/shuttle/voidcrew/corsair/hold
	name = "Hold"
	icon_state = "cargo_bay"

/area/shuttle/voidcrew/corsair/hold/a

/area/shuttle/voidcrew/corsair/hold/b

/area/shuttle/voidcrew/corsair/hallway
	name = "Hallway"
	icon_state = "hallC"

/area/shuttle/voidcrew/corsair/hallway/a

/area/shuttle/voidcrew/corsair/hallway/b
