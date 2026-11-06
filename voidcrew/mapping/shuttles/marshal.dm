/datum/map_template/shuttle/voidcrew/marshal
	name = "Marshal-class Prisoner Transport"
	short_name = "Marshal-class"
	suffix = "marshal_a" // Default suffix, overridden by selected theme
	catalog_desc = "A licensed bounty hunter's cutter: a two-cell brig, a warrant console and room for six."
	part_requirements = list()
	has_upgrade_slots = TRUE
	upgrade_slot_ids = list("marshal_bay")
	available_themes = list("lawman", "bondsman")
	background_start = BACKGROUND_BOUNTY_HUNTER
	// job_slots come from the selected theme (voidcrew/modules/ship_upgrades/ships/marshal.dm)

/// DOCKING PORT ///

/obj/docking_port/mobile/voidcrew/marshal
	name = "Marshal-class Prisoner Transport"
	area_type = /area/shuttle/voidcrew/marshal
	// The port is mapped on the Boarding Hatch at (12,14), on the port beam of an east-facing hull,
	// aimed inboard (dir 2), so a hard dock mates the hatch between the two cells. WEST, like goon
	// and kilo.
	port_direction = 8
	// The hull is 22x14 and the port faces south, so the shuttle measures 22 fore to aft against 14
	// abeam and the aspect-ratio guess in adjust_reserve_dock_to_shuttle comes out EAST. This must
	// match it or the ship spins 90 degrees on every dock.
	preferred_direction = 4

/obj/docking_port/mobile/voidcrew/marshal/a
	name = "Marshal-class Prisoner Transport A"

/obj/docking_port/mobile/voidcrew/marshal/b
	name = "Marshal-class Prisoner Transport B"

/// AREAS ///

/area/shuttle/voidcrew/marshal
	name = "Marshal-class Prisoner Transport"
	icon_state = "station"

/area/shuttle/voidcrew/marshal/bridge
	name = "Bridge"
	icon_state = "bridge"

/area/shuttle/voidcrew/marshal/bridge/a

/area/shuttle/voidcrew/marshal/bridge/b

/area/shuttle/voidcrew/marshal/brig
	name = "Brig"
	icon_state = "brig"

/area/shuttle/voidcrew/marshal/brig/a

/area/shuttle/voidcrew/marshal/brig/b

/area/shuttle/voidcrew/marshal/crew
	name = "Crew Quarters"
	icon_state = "dorms"

/area/shuttle/voidcrew/marshal/crew/a

/area/shuttle/voidcrew/marshal/crew/b

/area/shuttle/voidcrew/marshal/engineering
	name = "Engineering"
	icon_state = "engine"

/area/shuttle/voidcrew/marshal/engineering/a

/area/shuttle/voidcrew/marshal/engineering/b

/area/shuttle/voidcrew/marshal/bay
	name = "Ready Room"
	icon_state = "cargo_bay"

/area/shuttle/voidcrew/marshal/bay/a

/area/shuttle/voidcrew/marshal/bay/b

/area/shuttle/voidcrew/marshal/hallway
	name = "Hallway"
	icon_state = "hallC"

/area/shuttle/voidcrew/marshal/hallway/a

/area/shuttle/voidcrew/marshal/hallway/b
