/datum/design/board/bitrunning_order_console
	name = "Bitrunning Supplies Console Board"
	desc = "Allows for the construction of circuit boards used to build a bitrunning supplies order console, which spends bitrunning points."
	id = "bitrunning_order_console"
	build_path = /obj/item/circuitboard/computer/order_console/bitrunning
	category = list(
		RND_CATEGORY_COMPUTER + RND_SUBCATEGORY_COMPUTER_CARGO
	)
	departmental_flags = DEPARTMENT_BITFLAG_ENGINEERING

/datum/design/board/quantum_server
	name = "Quantum Server Board"
	desc = "The circuit board for a quantum server."
	id = "quantum_server"
	build_path = /obj/item/circuitboard/machine/quantum_server
	category = list(
		RND_CATEGORY_MACHINE + RND_SUBCATEGORY_MACHINE_CARGO
	)
	departmental_flags = DEPARTMENT_BITFLAG_ENGINEERING
