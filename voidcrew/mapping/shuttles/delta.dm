/**
 * Delta-class Frigate
 *
 * * Derelict NT frigate salvage; unlock 2 combat + 1 misc
 * * Converted to the phase-4 modular standard: 4 upgrade slots, 4 themes
 * * Slots: cargo (open, 7x5), cafe (open, 7x5), med (open, 6x3),
 *   dorms (enclosed-lite, 6x3 with the (14,16) cryo reserve tile)
 * * Themes: Salvage Claim (the re-lit derelict, default), Gorlex Prize
 *   (syndicate warship refit), The Congregation (blood cult refit),
 *   The Lightship (volunteer rescue station)
 * * The bare hull flies and is joinable with every slot empty: helm, engine
 *   block, both airlock arms, autolathe (engineering), and the reserve-tile
 *   cryopod + console all live outside the slots; the hull owns APC/atmos
 *   coverage for every slot pocket
 */
/datum/map_template/shuttle/voidcrew/delta
	name = "Delta-class Frigate"
	suffix = "delta_a" // Default suffix, overridden by selected theme
	short_name = "Delta-class"
	catalog_desc = "A derelict Nanotrasen frigate brought back into service - long and narrow, \
		with the engine block aft and an airlock arm on each side. Helm, engines, autolathe \
		and cryo are permanent; the four slots are cargo, cafe, medical and dorms, so the \
		same hull can fly as a trader, a clinic or a bunkhouse for a larger crew."
	part_requirements = list(PART_CLASS_COMBAT = 8, PART_CLASS_MISC = 8, PART_CLASS_TRADE = 6)
	has_upgrade_slots = TRUE
	upgrade_slot_ids = list(
		"delta_cargo",
		"delta_cafe",
		"delta_med",
		"delta_dorms",
	)
	available_themes = list("salvage", "syndicate", "cult", "lightship")
	// job_slots come from the selected theme, not defined here

/// DOCKING PORT ///

/obj/docking_port/mobile/voidcrew/delta
	name = "Delta-class Frigate"
	area_type = /area/shuttle/voidcrew/delta
	port_direction = 8
	preferred_direction = 4

/obj/docking_port/mobile/voidcrew/delta/a
	name = "Delta-class Frigate A"

/obj/docking_port/mobile/voidcrew/delta/b
	name = "Delta-class Frigate B"

/obj/docking_port/mobile/voidcrew/delta/c
	name = "Delta-class Frigate C"

/obj/docking_port/mobile/voidcrew/delta/d
	name = "Delta-class Frigate D"

/// AREAS ///

/// Command ///

/area/shuttle/voidcrew/delta/bridge
	name = "Bridge"
	icon_state = "bridge"

/area/shuttle/voidcrew/delta/bridge/a

/area/shuttle/voidcrew/delta/bridge/b
	name = "Operations"

/area/shuttle/voidcrew/delta/bridge/c
	name = "Wheelhouse"

/area/shuttle/voidcrew/delta/bridge/d
	name = "Watch Room"

/// Engineering ///

/area/shuttle/voidcrew/delta/engineering
	name = "Engineering"
	icon_state = "engine"

/area/shuttle/voidcrew/delta/engineering/a

/area/shuttle/voidcrew/delta/engineering/b
	name = "Powerplant"

/area/shuttle/voidcrew/delta/engineering/c
	name = "Engine Room"

/area/shuttle/voidcrew/delta/engineering/d
	name = "Boiler Room"

// The medbay pocket is the delta_med upgrade slot; the hull keeps the
// medvendor, APC and atmos for it on permanent tiles
/area/shuttle/voidcrew/delta/medbay
	name = "Medbay"
	icon_state = "medbay"

/area/shuttle/voidcrew/delta/medbay/a

/area/shuttle/voidcrew/delta/medbay/b
	name = "Trauma Bay"

/area/shuttle/voidcrew/delta/medbay/c
	name = "Infirmary"

/area/shuttle/voidcrew/delta/medbay/d
	name = "Casualty Bay"

// The hold interior is the delta_cargo upgrade slot
/area/shuttle/voidcrew/delta/cargo
	name = "Starboard Hold"
	icon_state = "cargo_bay"

/area/shuttle/voidcrew/delta/cargo/a

/area/shuttle/voidcrew/delta/cargo/b
	name = "Munitions Hold"

/area/shuttle/voidcrew/delta/cargo/c
	name = "Hold"

/area/shuttle/voidcrew/delta/cargo/d
	name = "Boathouse"

/// Service ///

// The crew deck interior is the delta_dorms upgrade slot; the hull keeps a
// cryopod + console + APC on the (14,16) reserve tile
/area/shuttle/voidcrew/delta/dorms
	name = "Crew Deck"
	icon_state = "dorms"

/area/shuttle/voidcrew/delta/dorms/a

/area/shuttle/voidcrew/delta/dorms/b
	name = "Berthing"

/area/shuttle/voidcrew/delta/dorms/c
	name = "Quarters"

/area/shuttle/voidcrew/delta/dorms/d
	name = "Watch Quarters"

// The wing interior is the delta_cafe upgrade slot
/area/shuttle/voidcrew/delta/cafe
	name = "Port Wing"
	icon_state = "cafeteria"

/area/shuttle/voidcrew/delta/cafe/a

/area/shuttle/voidcrew/delta/cafe/b
	name = "Mess Deck"

/area/shuttle/voidcrew/delta/cafe/c
	name = "Refectory"

/area/shuttle/voidcrew/delta/cafe/d
	name = "Station Mess"

/// Hallways ///

/area/shuttle/voidcrew/delta/hallway/central
	name = "Central Primary Hallway"
	icon_state = "centralhall"

/area/shuttle/voidcrew/delta/hallway/central/a

/area/shuttle/voidcrew/delta/hallway/central/b
	name = "Spinal Corridor"

/area/shuttle/voidcrew/delta/hallway/central/c
	name = "Nave"

/area/shuttle/voidcrew/delta/hallway/central/d
	name = "Main Passage"

/area/shuttle/voidcrew/delta/airlock/port
	name = "Port Airlock"
	icon_state = "porthall"

/area/shuttle/voidcrew/delta/airlock/port/a

/area/shuttle/voidcrew/delta/airlock/port/b
	name = "Boarding Lock"

/area/shuttle/voidcrew/delta/airlock/port/c

/area/shuttle/voidcrew/delta/airlock/port/d
	name = "Rescue Dock"

/area/shuttle/voidcrew/delta/airlock/starboard
	name = "Starboard Airlock"
	icon_state = "starboardmaint"

/area/shuttle/voidcrew/delta/airlock/starboard/a

/area/shuttle/voidcrew/delta/airlock/starboard/b

/area/shuttle/voidcrew/delta/airlock/starboard/c

/area/shuttle/voidcrew/delta/airlock/starboard/d
