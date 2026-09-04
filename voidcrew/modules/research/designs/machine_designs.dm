/datum/design/board/rdserver
	build_path = /obj/item/circuitboard/machine/rdserver/ship

// Upstream ships the TEG, its circulators and the RTG as circuit boards and hull
// fittings, but never gave any of them a design datum - so nothing in the web could
// print them and a crew that wanted to add or replace a generator had no route to
// one. Unlocked by the Radioisotope Generators / Thermoelectric Generation nodes
// in voidcrew/modules/research/techweb_nodes.dm.
/datum/design/board/rtg
	name = "Machine Design (RTG Board)"
	desc = "The circuit board for a radioisotope thermoelectric generator."
	id = "rtg"
	build_path = /obj/item/circuitboard/machine/rtg
	category = list(
		RND_CATEGORY_MACHINE + RND_SUBCATEGORY_MACHINE_ENGINEERING
	)
	departmental_flags = DEPARTMENT_BITFLAG_ENGINEERING

// Upstream's radioactive nebula shielder has a board and a sprite but no design and no node
// - its only source is a cargo pack that a dead station trait was supposed to unlock, so
// nothing in this fork could ever build one. Hung off Radioisotope Generators, the node
// already dealing in sealed radioactive blocks. See voidcrew/edits/machinery/nebula_shielding.dm
/datum/design/board/nebula_shielding
	name = "Machine Design (Radioactive Nebula Shielder Board)"
	desc = "The circuit board for a radioactive nebula shielder, which keeps a tritium nebula's radiation off the crew."
	id = "radioactive_nebula_shielding"
	build_path = /obj/item/circuitboard/machine/radioactive_nebula_shielding
	category = list(
		RND_CATEGORY_MACHINE + RND_SUBCATEGORY_MACHINE_ENGINEERING
	)
	departmental_flags = DEPARTMENT_BITFLAG_ENGINEERING

/datum/design/board/teg
	name = "Machine Design (Thermoelectric Generator Board)"
	desc = "The circuit board for a thermoelectric generator."
	id = "teg"
	build_path = /obj/item/circuitboard/machine/thermoelectric_generator
	category = list(
		RND_CATEGORY_MACHINE + RND_SUBCATEGORY_MACHINE_ENGINEERING
	)
	departmental_flags = DEPARTMENT_BITFLAG_ENGINEERING

/datum/design/board/teg_circulator
	name = "Machine Design (Circulator/Heat Exchanger Board)"
	desc = "The circuit board for a thermoelectric generator's gas circulator."
	id = "teg_circulator"
	build_path = /obj/item/circuitboard/machine/circulator
	category = list(
		RND_CATEGORY_MACHINE + RND_SUBCATEGORY_MACHINE_ENGINEERING
	)
	departmental_flags = DEPARTMENT_BITFLAG_ENGINEERING
