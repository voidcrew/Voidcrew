// Voidcrew extensions to code/modules/research/designs/machine_designs.dm.

/datum/design/board/quantum_server
	name = "Quantum Server Board"
	desc = "The circuit board for a quantum server."
	id = "quantum_server"
	build_path = /obj/item/circuitboard/machine/quantum_server
	category = list(
		RND_CATEGORY_MACHINE + RND_SUBCATEGORY_MACHINE_CARGO
	)
	departmental_flags = DEPARTMENT_BITFLAG_ENGINEERING
