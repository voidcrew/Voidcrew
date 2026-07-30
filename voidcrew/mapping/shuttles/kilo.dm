/**
 * Kilo-class Mining Ship
 *
 * * Asteroid-mining barge with a side of freight; NTMS-037, frontier crew
 * * First ship converted to the phase-4 modular standard
 * * 3 upgrade slots: service (cafe box), dock (mining prep strip), hold (cargo east)
 * * 4 themes: Dust Hauler (tramp grime, default), Saloon (full frontier-wood
 *   refit), Dollhouse (pastel pink), Factory Fresh (clean corporate refit)
 * * The bare hull satisfies anatomy M1-M9 with every slot empty: helm, docking
 *   spine, engine column, SMES bay, PACMAN, west airlock, 3 cryopods and every
 *   permanent room's APC/atmos coverage all live outside the slots
 */
/datum/map_template/shuttle/voidcrew/kilo
	name = "Kilo-class Mining Ship"
	short_name = "Kilo-Class"
	suffix = "kilo_a" // Default suffix, overridden by selected theme
	catalog_desc = "A frontier mining barge built around an east-side cargo hold and an external \
		dock prep strip. Helm, engine column, SMES bay and cryopods are all permanent, so \
		the bare hull flies as bought. Its slots cover the service room, the dock strip and \
		the hold, which lets it run as a pure ore hauler or a small freighter."
	part_requirements = list(PART_CLASS_TRADE = 6, PART_CLASS_MISC = 4, PART_CLASS_SCIENCE = 2)
	has_upgrade_slots = TRUE
	upgrade_slot_ids = list(
		"kilo_service",
		"kilo_dock",
		"kilo_hold",
	)
	available_themes = list("tramp", "saloon", "pink", "clean")
	// job_slots come from the selected theme, not defined here

/// DOCKING PORT ///

/obj/docking_port/mobile/voidcrew/kilo
	name = "Kilo-class Mining Ship"
	area_type = /area/shuttle/voidcrew/kilo
	port_direction = 8
	preferred_direction = 4

/obj/docking_port/mobile/voidcrew/kilo/a
	name = "Kilo-class Mining Ship A"

/obj/docking_port/mobile/voidcrew/kilo/b
	name = "Kilo-class Mining Ship B"

/obj/docking_port/mobile/voidcrew/kilo/c
	name = "Kilo-class Mining Ship C"

/obj/docking_port/mobile/voidcrew/kilo/d
	name = "Kilo-class Mining Ship D"

/// AREAS ///

/// Command ///

/area/shuttle/voidcrew/kilo/bridge
	name = "Bridge"
	icon_state = "bridge"

/area/shuttle/voidcrew/kilo/bridge/a

/area/shuttle/voidcrew/kilo/bridge/b

/area/shuttle/voidcrew/kilo/bridge/c

/area/shuttle/voidcrew/kilo/bridge/d

/// Cargo ///

/area/shuttle/voidcrew/kilo/cargo
	name = "Cargo Bay"
	icon_state = "cargo_bay"

/area/shuttle/voidcrew/kilo/cargo/a

/area/shuttle/voidcrew/kilo/cargo/b

/area/shuttle/voidcrew/kilo/cargo/c

/area/shuttle/voidcrew/kilo/cargo/d

/area/shuttle/voidcrew/kilo/cargo/mining_dock
	name = "Mining Dock"
	icon_state = "mining"

/area/shuttle/voidcrew/kilo/cargo/mining_dock/a

/area/shuttle/voidcrew/kilo/cargo/mining_dock/b

/area/shuttle/voidcrew/kilo/cargo/mining_dock/c

/area/shuttle/voidcrew/kilo/cargo/mining_dock/d

/// Engineering ///

/area/shuttle/voidcrew/kilo/engineering
	name = "Engineering"
	icon_state = "engine"

/area/shuttle/voidcrew/kilo/engineering/a

/area/shuttle/voidcrew/kilo/engineering/b

/area/shuttle/voidcrew/kilo/engineering/c

/area/shuttle/voidcrew/kilo/engineering/d

/// Service ///

// The cafe box is the kilo_service upgrade slot; the module loaded into it
// brings this area's APC, air alarm, vent and scrubber with it
/area/shuttle/voidcrew/kilo/cafe
	name = "Service Bay"
	icon_state = "cafeteria"

/area/shuttle/voidcrew/kilo/cafe/a

/area/shuttle/voidcrew/kilo/cafe/b

/area/shuttle/voidcrew/kilo/cafe/c

/area/shuttle/voidcrew/kilo/cafe/d

/area/shuttle/voidcrew/kilo/dorms
	name = "Dormitories"
	icon_state = "dorms"

/area/shuttle/voidcrew/kilo/dorms/a

/area/shuttle/voidcrew/kilo/dorms/b

/area/shuttle/voidcrew/kilo/dorms/c

/area/shuttle/voidcrew/kilo/dorms/d
