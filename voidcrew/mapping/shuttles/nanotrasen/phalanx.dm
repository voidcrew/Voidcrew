/**
 * Phalanx-Class Super Battlecruiser
 *
 * * Decommissioned marine carrier; the fleet's capstone combat unlock (3 combat)
 * * Converted to the phase-4 modular standard: 5 upgrade slots, 4 themes
 * * Slots: bay_north (open, 11x3), bay_south (open, 11x3), lab (enclosed, 10x3),
 *   medical (enclosed, 10x3), armory (enclosed, 6x4)
 * * Themes: Fleet Surplus (veteran grey, default), Hearthship (family timber
 *   refit), Verdant (terraformers' garden ship), The Springs (travelling
 *   bathhouse)
 * * The bare hull satisfies anatomy M1-M9 with every slot empty: helm, west
 *   cycling airlocks, engine column + SMES + PACMAN bank, 4 cryopods, and
 *   APC/atmos coverage for every permanent room live outside the slots
 * * Generator bay (x6-12, y21-23), off engineering through the firedoor at
 *   (6,21): a thermoelectric generator with both loops plumbed and charged -
 *   cold loop west (cyan) on a 73K freezer, hot loop east (orange) on a 573K
 *   heater, one plasma charge tank per loop. It ships switched OFF; the four
 *   machines (two circulation pumps, two thermomachines) are the crew's
 *   startup job, and the PACMAN bank is what carries the ship until then
 * * It fights by boarding, not guns: the armory is a slot and the heavy gear
 *   (marine vendor, bomb/L3 kit) only returns via paid modules
 */
/datum/map_template/shuttle/voidcrew/phalanx
	name = "Phalanx-Class Super Battlecruiser"
	suffix = "nano_phalanx_a" // Default suffix, overridden by selected theme
	short_name = "Phalanx-Class"
	catalog_desc = "A decommissioned marine carrier, and the largest hull on the shelf. It \
		fights by boarding rather than by guns: two long internal bays, cycling airlocks and \
		room for a big crew, with no heavy weapons on the bare hull. The lab, medbay and \
		armory are all slots, so the marine gear only comes back if you pay for it. \
		Engineering carries a thermoelectric generator, plumbed and charged but shut down: \
		start it and the ship stops living off plasma sheets. \
		The fleet's capstone unlock - expensive, and a lot of ship to keep running."
	part_requirements = list(PART_CLASS_COMBAT = 24, PART_CLASS_SCIENCE = 12, PART_CLASS_TRADE = 12, PART_CLASS_MISC = 12)
	has_upgrade_slots = TRUE
	upgrade_slot_ids = list(
		"phalanx_bay_north",
		"phalanx_bay_south",
		"phalanx_lab",
		"phalanx_medical",
		"phalanx_armory",
	)
	available_themes = list("surplus", "hearth", "verdant", "springs")
	// job_slots come from the selected theme, not defined here

/// DOCKING PORT ///

/obj/docking_port/mobile/voidcrew/phalanx
	name = "Phalanx-Class Super Battlecruiser"
	area_type = /area/shuttle/voidcrew/phalanx
	port_direction = 8
	preferred_direction = 4

/obj/docking_port/mobile/voidcrew/phalanx/a
	name = "Phalanx-Class Super Battlecruiser A"

/obj/docking_port/mobile/voidcrew/phalanx/b
	name = "Phalanx-Class Super Battlecruiser B"

/obj/docking_port/mobile/voidcrew/phalanx/c
	name = "Phalanx-Class Super Battlecruiser C"

/obj/docking_port/mobile/voidcrew/phalanx/d
	name = "Phalanx-Class Super Battlecruiser D"

/// AREAS ///

/// Command ///

/area/shuttle/voidcrew/phalanx/bridge
	name = "Bridge"
	icon_state = "bridge"

/area/shuttle/voidcrew/phalanx/bridge/a

/area/shuttle/voidcrew/phalanx/bridge/b
	name = "Wheelhouse"

/area/shuttle/voidcrew/phalanx/bridge/c

/area/shuttle/voidcrew/phalanx/bridge/d

/area/shuttle/voidcrew/phalanx/bridge/captain
	name = "Captain's Office"
	icon_state = "captain"

/area/shuttle/voidcrew/phalanx/bridge/captain/a

/area/shuttle/voidcrew/phalanx/bridge/captain/b
	name = "Family Head's Study"

/area/shuttle/voidcrew/phalanx/bridge/captain/c
	name = "Caretaker's Study"

/area/shuttle/voidcrew/phalanx/bridge/captain/d
	name = "Proprietor's Office"

/// Security ///

/area/shuttle/voidcrew/phalanx/security
	name = "Security Equipment"
	icon_state = "security"

/area/shuttle/voidcrew/phalanx/security/a

/area/shuttle/voidcrew/phalanx/security/b
	name = "Door Warden's Post"

/area/shuttle/voidcrew/phalanx/security/c
	name = "Ranger Station"

/area/shuttle/voidcrew/phalanx/security/d
	name = "Doorman's Post"

// The armory box is the phalanx_armory upgrade slot; the module loaded into it
// brings this area's APC, air alarm, vent and scrubber with it
/area/shuttle/voidcrew/phalanx/security/armory
	name = "Security Annex"
	icon_state = "armory"

/area/shuttle/voidcrew/phalanx/security/armory/a

/area/shuttle/voidcrew/phalanx/security/armory/b

/area/shuttle/voidcrew/phalanx/security/armory/c

/area/shuttle/voidcrew/phalanx/security/armory/d

/// Cargo ///

/area/shuttle/voidcrew/phalanx/cargo
	name = "South Hangar"
	icon_state = "cargo_bay"

/area/shuttle/voidcrew/phalanx/cargo/a

/area/shuttle/voidcrew/phalanx/cargo/b

/area/shuttle/voidcrew/phalanx/cargo/c

/area/shuttle/voidcrew/phalanx/cargo/d

/area/shuttle/voidcrew/phalanx/cargo/mining
	name = "North Hangar"
	icon_state = "mining"

/area/shuttle/voidcrew/phalanx/cargo/mining/a

/area/shuttle/voidcrew/phalanx/cargo/mining/b

/area/shuttle/voidcrew/phalanx/cargo/mining/c

/area/shuttle/voidcrew/phalanx/cargo/mining/d

/// Engineering ///

/area/shuttle/voidcrew/phalanx/engineering
	name = "Engineering"
	icon_state = "engine"

/area/shuttle/voidcrew/phalanx/engineering/a

/area/shuttle/voidcrew/phalanx/engineering/b

/area/shuttle/voidcrew/phalanx/engineering/c

/area/shuttle/voidcrew/phalanx/engineering/d

/area/shuttle/voidcrew/phalanx/engineering/storage
	name = "Engineering Storage"
	icon_state = "engine_storage"

/area/shuttle/voidcrew/phalanx/engineering/storage/a

/area/shuttle/voidcrew/phalanx/engineering/storage/b

/area/shuttle/voidcrew/phalanx/engineering/storage/c

/area/shuttle/voidcrew/phalanx/engineering/storage/d

/area/shuttle/voidcrew/phalanx/engineering/atmospherics
	name = "Atmospherics"
	icon_state = "atmos"

/area/shuttle/voidcrew/phalanx/engineering/atmospherics/a

/area/shuttle/voidcrew/phalanx/engineering/atmospherics/b
	name = "The Boiler Room"

/area/shuttle/voidcrew/phalanx/engineering/atmospherics/c

/area/shuttle/voidcrew/phalanx/engineering/atmospherics/d
	name = "Boiler House"

/// Science ///

// The lab interior is the phalanx_lab upgrade slot; modules bring the area's
// APC, air alarm, vent and scrubber
/area/shuttle/voidcrew/phalanx/nanites
	name = "Laboratory"
	icon_state = "station"

/area/shuttle/voidcrew/phalanx/nanites/a

/area/shuttle/voidcrew/phalanx/nanites/b

/area/shuttle/voidcrew/phalanx/nanites/c

/area/shuttle/voidcrew/phalanx/nanites/d

/// Medbay ///

// The theatre block interior is the phalanx_medical upgrade slot; modules bring
// the area's APC, air alarm, vent and scrubber
/area/shuttle/voidcrew/phalanx/medbay
	name = "Medbay"
	icon_state = "medbay"

/area/shuttle/voidcrew/phalanx/medbay/a

/area/shuttle/voidcrew/phalanx/medbay/b

/area/shuttle/voidcrew/phalanx/medbay/c

/area/shuttle/voidcrew/phalanx/medbay/d

/area/shuttle/voidcrew/phalanx/medbay/morgue
	name = "Morgue"
	icon_state = "morgue"

/area/shuttle/voidcrew/phalanx/medbay/morgue/a

/area/shuttle/voidcrew/phalanx/medbay/morgue/b

/area/shuttle/voidcrew/phalanx/medbay/morgue/c

/area/shuttle/voidcrew/phalanx/medbay/morgue/d

/area/shuttle/voidcrew/phalanx/medbay/storage
	name = "Medical Equipment"
	icon_state = "med_storage"

/area/shuttle/voidcrew/phalanx/medbay/storage/a

/area/shuttle/voidcrew/phalanx/medbay/storage/b

/area/shuttle/voidcrew/phalanx/medbay/storage/c

/area/shuttle/voidcrew/phalanx/medbay/storage/d
	name = "Towel Service"

/// Service ///

/area/shuttle/voidcrew/phalanx/dorms
	name = "Dormitories"
	icon_state = "dorms"

/area/shuttle/voidcrew/phalanx/dorms/a

/area/shuttle/voidcrew/phalanx/dorms/b
	name = "Family Bunks"

/area/shuttle/voidcrew/phalanx/dorms/c
	name = "Crew Cabins"

/area/shuttle/voidcrew/phalanx/dorms/d
	name = "Guest Rooms"

/area/shuttle/voidcrew/phalanx/cafeteria
	name = "Cafeteria"
	icon_state = "cafeteria"

/area/shuttle/voidcrew/phalanx/cafeteria/a

/area/shuttle/voidcrew/phalanx/cafeteria/b
	name = "The Long Table"

/area/shuttle/voidcrew/phalanx/cafeteria/c
	name = "Garden Commons"

/area/shuttle/voidcrew/phalanx/cafeteria/d
	name = "Tea Hall"

/area/shuttle/voidcrew/phalanx/kitchen
	name = "Kitchen"
	icon_state = "kitchen"

/area/shuttle/voidcrew/phalanx/kitchen/a

/area/shuttle/voidcrew/phalanx/kitchen/b
	name = "Family Kitchen"

/area/shuttle/voidcrew/phalanx/kitchen/c
	name = "Harvest Kitchen"

/area/shuttle/voidcrew/phalanx/kitchen/d
	name = "Tea Kitchen"

/area/shuttle/voidcrew/phalanx/chapel
	name = "Chapel"
	icon_state = "chapel"

/area/shuttle/voidcrew/phalanx/chapel/a

/area/shuttle/voidcrew/phalanx/chapel/b
	name = "The Hearthroom"

/area/shuttle/voidcrew/phalanx/chapel/c
	name = "The Bower"

/area/shuttle/voidcrew/phalanx/chapel/d
	name = "Spring Shrine"

/area/shuttle/voidcrew/phalanx/chapel/office
	name = "Chapel Office"
	icon_state = "chapeloffice"

/area/shuttle/voidcrew/phalanx/chapel/office/a

/area/shuttle/voidcrew/phalanx/chapel/office/b
	name = "Hearthkeeper's Nook"

/area/shuttle/voidcrew/phalanx/chapel/office/c
	name = "Potting Room"

/area/shuttle/voidcrew/phalanx/chapel/office/d
	name = "Shrinekeeper's Room"

/// Hallways ///

/area/shuttle/voidcrew/phalanx/hallway/central
	name = "Central Hall"
	icon_state = "centralhall"

/area/shuttle/voidcrew/phalanx/hallway/central/a

/area/shuttle/voidcrew/phalanx/hallway/central/b
	name = "Main Hall"

/area/shuttle/voidcrew/phalanx/hallway/central/c
	name = "The Greenway"

/area/shuttle/voidcrew/phalanx/hallway/central/d
	name = "Promenade"

/area/shuttle/voidcrew/phalanx/hallway/aft
	name = "Aft Hall"
	icon_state = "afthall"

/area/shuttle/voidcrew/phalanx/hallway/aft/a

/area/shuttle/voidcrew/phalanx/hallway/aft/b

/area/shuttle/voidcrew/phalanx/hallway/aft/c

/area/shuttle/voidcrew/phalanx/hallway/aft/d
