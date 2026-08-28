/obj/item/circuitboard/machine/rdserver/ship
	build_path = /obj/machinery/rnd/server/ship

/**
 * Upstream #94114 (be1f2318695) made every printed or tech-storage R&D console board start
 * LOCKED, so that station engineers have to ask the science department to research things for
 * them. There is no station and no science department here: every hull builds its own R&D from
 * the roundstart autolathe kit below, and the only people carrying ACCESS_RESEARCH are a captain
 * and whichever theme rosters happen to include a scientist.
 *
 * Left at upstream's default the console still opens and still draws the tree, but every action
 * answers "Console is locked, cannot perform further actions." and the unlock button answers
 * "Unauthorized Access." - for the kit's console and for all seventeen mapped ones. The board
 * can still be locked deliberately by swiping an ID with research access on it.
 */
/obj/item/circuitboard/computer/rdconsole
	locked = FALSE

/obj/item/storage/box/rndboards/all
	name = "\proper the Research & Development Kit"
	desc = "A box containing everything required to setup Research & Development equipment."
	illustration = "scicircuit"

/obj/item/storage/box/rndboards/all/PopulateContents()
	new /obj/item/circuitboard/machine/rdserver/ship(src)
	new /obj/item/circuitboard/machine/protolathe(src)
	new /obj/item/circuitboard/machine/destructive_analyzer(src)
	new /obj/item/circuitboard/machine/circuit_imprinter(src)
	// Explicitly the unlocked board, matching what #94114 did to the parent box upstream. The
	// fork default above already makes these the same type; this keeps the kit correct if that
	// default is ever reconsidered.
	new /obj/item/circuitboard/computer/rdconsole/unlocked(src)
	new /obj/item/disk/computer/ship_disk(src)

