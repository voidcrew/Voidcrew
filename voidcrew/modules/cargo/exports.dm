/**
 * Voidcrew-specific export datums
 * Defines sell values for items unique to voidcrew
 * Export values are approximately 1/4 of purchase cost to prevent arbitrage
 */

// ========== SHIP COMBAT EQUIPMENT ==========
// Purchase costs based on CARGO_CRATE_VALUE (200cr)

// Missile frames: 4 for 800cr = 200cr each, export ~50cr
/datum/export/ship_missile_frame
	cost = 50
	unit_name = "missile frame"
	export_types = list(/obj/structure/ship_missile)
	exclude_types = list(/obj/structure/ship_missile/armed)

// Tracking circuits: 6 for 600cr = 100cr each, export ~25cr
/datum/export/ship_missile_tracking
	cost = 25
	unit_name = "missile tracking circuit"
	export_types = list(/obj/item/electronics/ship_missile_tracking)

// Standard warheads: 4 for 1600cr = 400cr each, export ~100cr
/datum/export/warhead
	cost = 100
	unit_name = "missile warhead"
	export_types = list(/obj/item/bombcore/missile)
	exclude_types = list(/obj/item/bombcore/missile/light, /obj/item/bombcore/missile/heavy)

// Light warheads: 6 for 1000cr = ~167cr each, export ~40cr
/datum/export/warhead/light
	cost = 40
	unit_name = "light missile warhead"
	export_types = list(/obj/item/bombcore/missile/light)
	exclude_types = list()

// Heavy warheads: 2 for 2400cr = 1200cr each, export ~300cr
/datum/export/warhead/heavy
	cost = 300
	unit_name = "heavy missile warhead"
	export_types = list(/obj/item/bombcore/missile/heavy)
	exclude_types = list()

// Armed standard missile: frame(200) + tracking(100) + warhead(400) = ~700cr, export ~175cr
/datum/export/ship_missile
	cost = 175
	unit_name = "armed missile"
	export_types = list(/obj/structure/ship_missile/armed)
	exclude_types = list(/obj/structure/ship_missile/armed/light, /obj/structure/ship_missile/armed/heavy)

// Armed light missile: frame(200) + tracking(100) + warhead(167) = ~470cr, export ~120cr
/datum/export/ship_missile/light
	cost = 120
	unit_name = "light missile"
	export_types = list(/obj/structure/ship_missile/armed/light)
	exclude_types = list()

// Armed heavy missile: frame(200) + tracking(100) + warhead(1200) = ~1500cr, export ~375cr
/datum/export/ship_missile/heavy
	cost = 375
	unit_name = "heavy missile"
	export_types = list(/obj/structure/ship_missile/armed/heavy)
	exclude_types = list()

// Circuit boards - researched items, low resale value (~50cr each)
/datum/export/ship_combat_board
	cost = 50
	unit_name = "ship combat circuit board"
	export_types = list(
		/obj/item/circuitboard/computer/ship_combat_console,
		/obj/item/circuitboard/machine/ship_combat,
	)

// ========== RESEARCH & DATA ==========

/datum/export/research_notes
	unit_name = "research notes"
	export_types = list(/obj/item/research_notes/loot)
	/// We calculate cost based on the notes' value
	cost = 0

/datum/export/research_notes/get_cost(obj/item/research_notes/notes, apply_elastic)
	if(!istype(notes))
		return 0
	// Convert research points to credits at 50% rate
	return round(notes.value * 0.5)

/datum/export/survey_data
	cost = 50
	unit_name = "survey data disk"
	export_types = list(/obj/item/disk/survey_data_disk)

// ========== NANITE TECHNOLOGY ==========

/datum/export/nanite_disk
	cost = 200
	unit_name = "nanite program disk"
	export_types = list(/obj/item/disk/nanite_program)

// ========== UNIQUE GEAR ==========

/datum/export/survivor_suit
	cost = 1000
	unit_name = "survivor suit"
	export_types = list(/obj/item/clothing/suit/hooded/explorer/survivor)

/datum/export/survivor_hood
	cost = 300
	unit_name = "survivor hood"
	export_types = list(/obj/item/clothing/head/hooded/explorer/survivor)
