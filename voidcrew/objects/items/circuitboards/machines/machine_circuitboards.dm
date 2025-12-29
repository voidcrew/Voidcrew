/obj/item/circuitboard/machine/pacman
	req_components = list(
		/obj/item/stock_parts/matter_bin = 1,
		/obj/item/stock_parts/micro_laser = 1,
		/obj/item/stack/cable_coil = 2,
		/obj/item/stock_parts/capacitor = 1)

/obj/item/circuitboard/machine/shuttle/engine/plasma
	name = "Plasma Thruster (Machine Board)"
	build_path = /obj/machinery/power/shuttle_engine/ship/fueled/plasma
	req_components = list(/obj/item/stock_parts/capacitor = 2,
		/obj/item/stack/cable_coil = 5,
		/obj/item/stock_parts/micro_laser = 1)

/obj/item/circuitboard/machine/shuttle/engine/electric
	name = "Ion Thruster (Machine Board)"
	build_path = /obj/machinery/power/shuttle_engine/ship/electric
	req_components = list(/obj/item/stock_parts/capacitor = 3,
		/obj/item/stock_parts/micro_laser = 3)

/obj/item/circuitboard/machine/shuttle/engine/expulsion
	name = "Expulsion Thruster (Machine Board)"
	build_path = /obj/machinery/power/shuttle_engine/ship/fueled/expulsion
	req_components = list(/obj/item/stock_parts/servo = 2,
		/obj/item/stock_parts/matter_bin = 2)

/obj/item/circuitboard/machine/shuttle/engine/oil
	name = "Oil Thruster (Machine Board)"
	build_path = /obj/machinery/power/shuttle_engine/ship/liquid/oil
	req_components = list(/obj/item/reagent_containers/cup/beaker = 4,
		/obj/item/stock_parts/micro_laser = 2)

/obj/item/circuitboard/machine/shuttle/engine/void
	name = "Void Thruster (Machine Board)"
	build_path = /obj/machinery/power/shuttle_engine/ship/void
	req_components = list(/obj/item/stock_parts/capacitor/quadratic = 2,
		/obj/item/stack/cable_coil = 5,
		/obj/item/stock_parts/micro_laser/quadultra = 1)

/obj/item/circuitboard/machine/shuttle/heater
	name = "Fueled Engine Heater (Machine Board)"
	build_path = /obj/machinery/atmospherics/components/unary/shuttle/heater
	req_components = list(/obj/item/stock_parts/micro_laser = 2,
		/obj/item/stock_parts/matter_bin = 1)
