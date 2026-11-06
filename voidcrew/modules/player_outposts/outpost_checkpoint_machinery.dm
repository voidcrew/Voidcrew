/// Construct the ordinary machine, not a stocked/map/event subtype. Infrastructure
/// without a circuit retains its existing, explicitly supported hull representation.
/// What this machine is rebuilt as: its board's product when it has one, else itself.
/obj/machinery/proc/checkpoint_type()
	if(is_type_in_typecache(src, GLOB.outpost_checkpoint_excluded))
		return null
	// Its stock comes from its type, and a board's product is the plain, empty version.
	if(is_type_in_typecache(src, GLOB.ship_save_stocked_fixtures))
		return type
	if(anchored && istype(circuit) && ispath(circuit.build_path, /obj/machinery))
		return circuit.build_path
	return type

/obj/machinery/computer/helm/viewscreen/checkpoint_type()
	return type

/// The bare unary type only exists as a machine's own pipe connector (see
/// /datum/gas_machine_connector). Its machine makes a new one, so it is never a fitting itself.
/obj/machinery/atmospherics/components/unary/checkpoint_type()
	if(type == /obj/machinery/atmospherics/components/unary)
		return null
	return ..()

/// Pipe connectors this machine made for itself. They move with it rather than as pieces.
/obj/machinery/proc/checkpoint_atmos_parts()
	return list()

/obj/machinery/cryo_cell/checkpoint_atmos_parts()
	var/obj/machinery/atmospherics/connector = internal_connector?.gas_connector
	return connector ? list(connector) : list()

/// Empties a construction part of whatever it came with and fills its battery.
/proc/checkpoint_scrub_part(obj/item/part)
	part.reagents?.clear_reagents()
	if(istype(part, /obj/item/tank))
		var/obj/item/tank/tank = part
		tank.air_contents.gases.Cut()
	if(istype(part, /obj/item/stock_parts/power_store))
		var/obj/item/stock_parts/power_store/battery = part
		battery.charge = battery.maxcharge
	if(istype(part, /obj/item/vending_refill))
		var/obj/item/vending_refill/refill = part
		refill.products = list()
		refill.product_categories = list()
		refill.contraband = list()
		refill.premium = list()

/**
 * Puts a loaded machine's parts and supplies right. A capture keeps nothing per machine, so it stays
 * at the default tier it initialized with.
 */
/proc/checkpoint_restore_machine(obj/machinery/machine)
	// Scrubbing its refill and rereading its parts would empty a vendor that comes back stocked.
	var/stocked_vendor = istype(machine, /obj/machinery/vending) && is_type_in_typecache(machine, GLOB.ship_save_stocked_fixtures)
	if(machine.circuit)
		// Retain the newly initialized circuit and its machine-specific configuration.
		var/obj/item/circuitboard/board = machine.circuit
		ship_save_strip_board_salvage(board)
		if(!stocked_vendor)
			for(var/obj/item/part in machine.component_parts)
				if(part != board)
					checkpoint_scrub_part(part)
			machine.RefreshParts()
	if(istype(machine, /obj/machinery/vending) && !stocked_vendor)
		var/obj/machinery/vending/vendor = machine
		for(var/datum/data/vending_product/product as anything in vendor.product_records + vendor.hidden_records + vendor.coin_records)
			product.amount = 0
	if(istype(machine, /obj/machinery/power/apc))
		var/obj/machinery/power/apc/controller = machine
		QDEL_NULL(controller.cell)
		var/cell_type = controller.cell_type || /obj/item/stock_parts/power_store/battery/upgraded
		controller.cell = new cell_type(controller)
		controller.cell.charge = controller.cell.maxcharge
		controller.update()
	if(istype(machine, /obj/machinery/computer/camera_advanced/base_construction/ship))
		var/obj/machinery/computer/camera_advanced/base_construction/ship/builder = machine
		if(builder.internal_painter)
			QDEL_NULL(builder.internal_painter.ink)
		builder.internal_rcd.matter = 0
		if(builder.internal_rtd)
			builder.internal_rtd.matter = 0
		if(builder.internal_rld)
			builder.internal_rld.matter = 0
	machine.update_appearance()

/// Construction components and built-in radios are fittings, not cargo. Their
/// contents are still visited separately, so a component cannot smuggle stock.
/proc/checkpoint_is_machine_fitting(obj/item/item)
	if(ismachinery(item.loc))
		var/obj/machinery/machine = item.loc
		if(istype(machine, /obj/machinery/computer/camera_advanced/base_construction/ship))
			var/obj/machinery/computer/camera_advanced/base_construction/ship/builder = machine
			if(item in list(builder.internal_rcd, builder.internal_rtd, builder.internal_rpd, builder.internal_rld, builder.internal_painter))
				return TRUE
		return (item in machine.component_parts) || item == machine.circuit || istype(item, /obj/item/radio)
	return istype(item, /obj/item/encryptionkey) && istype(item.loc, /obj/item/radio) && ismachinery(item.loc.loc)

/// Top off as each machine is placed; the hidden copy may have drawn power while it waited.
/datum/checkpoint_construction/proc/provision_machine(obj/machinery/machine)
	checkpoint_provision_machine(machine)

/// Charged batteries and engine fuel, whatever the machine started with.
/proc/checkpoint_provision_machine(obj/machinery/machine)
	for(var/obj/item/stock_parts/power_store/battery in machine.component_parts)
		battery.charge = battery.maxcharge
	if(istype(machine, /obj/machinery/power/apc))
		var/obj/machinery/power/apc/controller = machine
		if(controller.cell)
			controller.cell.charge = controller.cell.maxcharge
		controller.update()
	if(istype(machine, /obj/machinery/atmospherics/components/unary/shuttle/heater))
		var/obj/machinery/atmospherics/components/unary/shuttle/heater/heater = machine
		QDEL_NULL(heater.fuel_tank)
		heater.fuel_tank = new /obj/item/tank/internals/plasma/empty(heater)
		// A dedicated reserve works even if the old pipe network was drained or cut.
		if(!heater.use_tank)
			heater.toggle_fuel_source()
		heater.update_gas_stats()
		heater.fuel_tank.air_contents.assert_gas(/datum/gas/plasma)
		heater.fuel_tank.air_contents.gases[/datum/gas/plasma][MOLES] = heater.gas_capacity
	if(istype(machine, /obj/machinery/power/shuttle_engine/ship/liquid))
		var/obj/machinery/power/shuttle_engine/ship/liquid/engine = machine
		engine.reagents.clear_reagents()
		for(var/reagent in engine.fuel_reagents)
			engine.reagents.add_reagent(reagent, engine.max_reagents * engine.fuel_reagents[reagent] / engine.reagent_amount_holder)
	machine.update_appearance()
