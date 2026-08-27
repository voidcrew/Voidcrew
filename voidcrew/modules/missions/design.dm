/**
 * RND Designs for Mission Equipment
 */

/datum/design/board/mission_board
	name = "Computer Design (Mission Board)"
	desc = "The circuit board for a mission board console."
	build_path = /obj/item/circuitboard/computer/mission_board
	category = list(
		RND_CATEGORY_COMPUTER + RND_SUBCATEGORY_COMPUTER_CARGO
	)
	departmental_flags = DEPARTMENT_BITFLAG_CARGO | DEPARTMENT_BITFLAG_SCIENCE

/datum/design/board/mission_pad
	name = "Machine Design (Mission Pad)"
	desc = "The circuit board for a mission pad."
	build_path = /obj/item/circuitboard/machine/mission_pad
	category = list(
		RND_CATEGORY_MACHINE + RND_SUBCATEGORY_MACHINE_CARGO
	)
	departmental_flags = DEPARTMENT_BITFLAG_CARGO | DEPARTMENT_BITFLAG_SCIENCE
