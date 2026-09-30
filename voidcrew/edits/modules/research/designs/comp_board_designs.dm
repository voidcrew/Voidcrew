// Voidcrew extensions to code/modules/research/designs/comp_board_designs.dm.

/datum/design/board/bitrunning_order_console
	name = "Bitrunning Supplies Console Board"
	desc = "Allows for the construction of circuit boards used to build a bitrunning supplies order console, which spends bitrunning points."
	id = "bitrunning_order_console"
	build_path = /obj/item/circuitboard/computer/order_console/bitrunning
	category = list(
		RND_CATEGORY_COMPUTER + RND_SUBCATEGORY_COMPUTER_CARGO
	)
	departmental_flags = DEPARTMENT_BITFLAG_ENGINEERING
