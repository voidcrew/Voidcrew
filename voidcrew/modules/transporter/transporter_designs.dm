/**
 * RND designs for the transporter.
 *
 * Every piece is priced in bluespace one way or another - the boards need it at the
 * imprinter, and the pad needs six raw crystals on top of that when it's assembled.
 * A crew that hasn't solved mining or trade for bluespace isn't getting a transporter
 * just because they finished the research.
 */

/datum/design/board/transporter_pad
	name = "Machine Design (Transporter Pad)"
	desc = "The circuit board for a transporter pad."
	build_path = /obj/item/circuitboard/machine/transporter_pad
	materials = list(
		/datum/material/glass = SHEET_MATERIAL_AMOUNT,
		/datum/material/gold = HALF_SHEET_MATERIAL_AMOUNT,
		/datum/material/diamond = HALF_SHEET_MATERIAL_AMOUNT,
		/datum/material/bluespace = SHEET_MATERIAL_AMOUNT * 2,
	)
	category = list(
		RND_CATEGORY_MACHINE + RND_SUBCATEGORY_MACHINE_TELEPORT,
	)
	departmental_flags = DEPARTMENT_BITFLAG_SCIENCE | DEPARTMENT_BITFLAG_ENGINEERING

/datum/design/board/transporter_console
	name = "Computer Design (Transporter Control Console)"
	desc = "The circuit board for a transporter control console."
	build_path = /obj/item/circuitboard/computer/transporter
	materials = list(
		/datum/material/glass = SHEET_MATERIAL_AMOUNT,
		/datum/material/gold = HALF_SHEET_MATERIAL_AMOUNT,
		/datum/material/bluespace = SHEET_MATERIAL_AMOUNT,
	)
	category = list(
		RND_CATEGORY_COMPUTER + RND_SUBCATEGORY_COMPUTER_RESEARCH,
	)
	departmental_flags = DEPARTMENT_BITFLAG_SCIENCE | DEPARTMENT_BITFLAG_ENGINEERING

/datum/design/transporter_transponder
	name = "Site-to-ship transponder"
	desc = "A personal beacon that a transporter pad can find and recover."
	build_type = PROTOLATHE | AWAY_LATHE
	materials = list(
		/datum/material/iron = SHEET_MATERIAL_AMOUNT,
		/datum/material/glass = HALF_SHEET_MATERIAL_AMOUNT,
		/datum/material/silver = HALF_SHEET_MATERIAL_AMOUNT,
		/datum/material/bluespace = HALF_SHEET_MATERIAL_AMOUNT,
	)
	build_path = /obj/item/transporter_transponder
	category = list(
		RND_CATEGORY_TOOLS + RND_SUBCATEGORY_TOOLS_ENGINEERING_ADVANCED,
	)
	departmental_flags = DEPARTMENT_BITFLAG_SCIENCE | DEPARTMENT_BITFLAG_ENGINEERING

/// Research-only unlocks, with no printable object behind them.
/datum/design/transporter_targeting
	name = "Transporter pattern targeting"
	desc = "Lets the control console aim a beam at an exact turf instead of dropping people wherever the computer finds room, and hold a lock through a roof."
	research_icon = 'voidcrew/icons/effects/overmap.dmi'
	research_icon_state = "globe"

/datum/design/transporter_biofilter
	name = "Transporter biofilter matrix"
	desc = "Cleans up what a transport does to the people it moves, shortens the recharge, and reports when a pad's safety interlocks have been cut."
	research_icon = 'icons/obj/medical/chemical.dmi'
	research_icon_state = "pill22"
