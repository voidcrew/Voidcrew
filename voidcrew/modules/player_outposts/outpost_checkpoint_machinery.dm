/// Used only while loading an isolated registry preview; cleared before delivery.
/obj/machinery
	var/checkpoint_load_id = 0

/// Construct the ordinary machine, not a stocked/map/event subtype. Infrastructure
/// without a circuit retains its existing, explicitly supported hull representation.
/// What this machine is rebuilt as: its board's product when it has one, else itself.
/obj/machinery/proc/checkpoint_type()
	if(is_type_in_typecache(src, GLOB.outpost_checkpoint_excluded))
		return null
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

/// Keep parts as construction types, never mutable datums belonging to the source.
/datum/ship_checkpoint/proc/capture_machine(obj/machinery/machine)
	var/list/parts = list()
	var/has_battery = FALSE
	for(var/datum/part as anything in machine.component_parts)
		if(istype(part, /datum/stock_part))
			var/datum/stock_part/stock = part
			parts += stock.type
		else if(isitem(part) && part != machine.circuit)
			var/datum/stock_part/stock = GLOB.stock_part_datums_per_object[part.type]
			parts += stock ? stock.type : part.type
			if(istype(part, /obj/item/stock_parts/power_store))
				has_battery = TRUE
	if(istype(machine, /obj/machinery/power/smes) && !istype(machine, /obj/machinery/power/smes/connector) && !has_battery)
		for(var/i in 1 to 5)
			parts += /obj/item/stock_parts/power_store/battery/high
	var/list/data = list("parts" = parts)
	if(istype(machine, /obj/machinery/power/apc))
		var/obj/machinery/power/apc/controller = machine
		var/cell_type = controller.cell?.type || /obj/item/stock_parts/power_store/battery/upgraded
		data["cell"] = cell_type
	if(istype(machine, /obj/machinery/computer/camera_advanced/base_construction/ship))
		var/obj/machinery/computer/camera_advanced/base_construction/ship/builder = machine
		data["construction_upgrades"] = builder.installed_upgrade_types.Copy()
	return data

/// Restore parts before RefreshParts calculates capacity, speed and efficiency.
/datum/checkpoint_construction/proc/restore_machine(obj/machinery/machine, mob/living/operator)
	if(!machine.checkpoint_load_id || machine.checkpoint_load_id > length(snapshot.machines))
		return
	var/list/data = snapshot.machines[machine.checkpoint_load_id]
	machine.checkpoint_load_id = 0
	if(machine.circuit)
		// Retain the newly initialized circuit and its machine-specific configuration.
		var/obj/item/circuitboard/board = machine.circuit
		var/list/old_parts = machine.component_parts?.Copy() || list()
		machine.component_parts = list(board)
		for(var/obj/item/part in old_parts)
			if(part != board)
				qdel(part)
		for(var/part_type in data["parts"])
			if(ispath(part_type, /datum/stock_part))
				machine.component_parts += GLOB.stock_part_datums[part_type]
			else
				var/obj/item/part = new part_type(machine)
				machine.component_parts += part
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
		machine.RefreshParts()
	if(istype(machine, /obj/machinery/vending))
		var/obj/machinery/vending/vendor = machine
		for(var/datum/data/vending_product/product as anything in vendor.product_records + vendor.hidden_records + vendor.coin_records)
			product.amount = 0
	if(istype(machine, /obj/machinery/power/apc))
		var/obj/machinery/power/apc/controller = machine
		QDEL_NULL(controller.cell)
		var/cell_type = data["cell"]
		controller.cell = new cell_type(controller)
		controller.cell.charge = controller.cell.maxcharge
		controller.update()
	if(istype(machine, /obj/machinery/computer/camera_advanced/base_construction/ship))
		var/obj/machinery/computer/camera_advanced/base_construction/ship/builder = machine
		for(var/upgrade_type in data["construction_upgrades"])
			if(!ispath(upgrade_type, /obj/item/ship_construction_upgrade) && !ispath(upgrade_type, /obj/item/rcd_upgrade) && !ispath(upgrade_type, /obj/item/rpd_upgrade))
				continue
			var/obj/item/disk = new upgrade_type(builder)
			builder.item_interaction(operator, disk)
			if(!QDELETED(disk))
				qdel(disk)
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
/datum/checkpoint_construction/proc/is_machine_fitting(obj/item/item)
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
