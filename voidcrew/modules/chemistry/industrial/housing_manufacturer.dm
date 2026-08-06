/**
 * Chemical manufacturer.
 *
 * Ported from monkestation's wiremod_chem module (housing/_chem_housing.dm).
 *
 * The shell the whole system is built around. It holds a chemical circuit board, keeps its
 * cell topped up off the area's power grid, accepts a precursor tank as feedstock, and
 * catches everything the circuit produces in its own reagent buffer.
 */
/obj/structure/chemical_manufacturer
	name = "chemical manufacturer"
	desc = "A state of the art machine that utilizes chemical precursors as well as circuitry to mix chemicals."

	icon = 'voidcrew/icons/obj/industrial_chem_structures.dmi'
	icon_state = "manufacturer"

	max_integrity = 2500
	density = TRUE

	/// The feedstock tank the synthesizer draws precursor from.
	var/obj/item/precursor_tank/connected_tank
	var/reagent_flags = TRANSPARENT | DRAINABLE
	var/buffer = 500
	/// Seconds accumulated toward the next cell top-up.
	var/recharge_counter = 0

/// How often the manufacturer refills its circuit's cell, in seconds.
#define MANUFACTURER_RECHARGE_INTERVAL 2

/obj/structure/chemical_manufacturer/Initialize(mapload)
	. = ..()
	create_reagents(buffer, reagent_flags)
	START_PROCESSING(SSmachines, src)
	AddComponent( \
		/datum/component/shell, \
		unremovable_circuit_components = list(new /obj/item/circuit_component/chem/output_manufacturer), \
		capacity = SHELL_CAPACITY_VERY_LARGE, \
		shell_flags = SHELL_FLAG_USB_PORT, \
	)

/obj/structure/chemical_manufacturer/Destroy()
	//VOIDCREW FIX: monkestation never stopped processing, leaving destroyed manufacturers
	//on SSmachines forever.
	STOP_PROCESSING(SSmachines, src)
	connected_tank = null
	return ..()

/obj/structure/chemical_manufacturer/process(seconds_per_tick)
	var/obj/item/integrated_circuit/attached_circuit = locate(/obj/item/integrated_circuit) in contents
	if(!attached_circuit?.cell)
		return

	recharge_counter += seconds_per_tick
	if(recharge_counter < MANUFACTURER_RECHARGE_INTERVAL)
		return
	recharge_counter = 0

	var/obj/item/stock_parts/power_store/cell = attached_circuit.cell
	var/usedpower = cell.give(cell.maxcharge - cell.charge)
	if(!usedpower)
		return
	var/area/our_area = get_area(src)
	our_area?.use_energy(max(usedpower, 0), AREA_USAGE_EQUIP)

/obj/structure/chemical_manufacturer/attackby(obj/item/attacking_item, mob/user, list/modifiers, list/attack_modifiers)
	//NOTE: monkestation declared two separate attackby overrides on this type, which DM
	//silently chains. Merged into one here so the ordering is explicit.
	if(istype(attacking_item, /obj/item/precursor_tank))
		replace_tank(attacking_item, user)
		return
	if(attacking_item.tool_behaviour == TOOL_WRENCH)
		if(attacking_item.use_tool(src, user, 4 SECONDS, volume = 75))
			to_chat(user, span_notice("You [anchored ? "un" : ""]secure [src]."))
			set_anchored(!anchored)
			return
	return ..()

/obj/structure/chemical_manufacturer/examine(mob/user)
	. = ..()
	if(connected_tank)
		. += span_notice("[connected_tank] is loaded, holding <b>[connected_tank.stored_precursor]</b> units of precursor. Alt-click to eject it.")
	else
		. += span_warning("No precursor tank is loaded. Synthesis will run, but at a steep power premium.")

/// Whether the loaded tank can cover the requested number of units.
/obj/structure/chemical_manufacturer/proc/has_precursor(amount)
	if(!connected_tank)
		return FALSE
	return connected_tank.stored_precursor >= amount

/// Spends up to `amount` units of precursor, taking whatever is available.
/obj/structure/chemical_manufacturer/proc/process_precursor(amount)
	if(!connected_tank)
		return FALSE
	connected_tank.stored_precursor -= min(connected_tank.stored_precursor, amount)
	return TRUE

/obj/structure/chemical_manufacturer/proc/remove_tank()
	if(!connected_tank)
		return
	connected_tank.forceMove(drop_location())
	connected_tank = null

/obj/structure/chemical_manufacturer/proc/replace_tank(obj/item/precursor_tank/incoming_tank, mob/user)
	remove_tank()
	if(!user.transferItemToLoc(incoming_tank, src))
		return
	connected_tank = incoming_tank

/obj/structure/chemical_manufacturer/click_alt(mob/living/user)
	remove_tank()
	return CLICK_ACTION_SUCCESS

/obj/structure/chemical_manufacturer/plunger_act(obj/item/plunger/attacking_plunger, mob/living/user, reinforced)
	to_chat(user, span_notice("You start furiously plunging [src]."))
	if(!do_after(user, 3 SECONDS, target = src))
		return
	to_chat(user, span_notice("You finish plunging [src]."))
	reagents.expose(get_turf(src), TOUCH) //splash on the floor
	reagents.clear_reagents()

/**
 * The manufacturer's built-in, unremovable output component. Same job as the remote tank
 * output, except it writes into the manufacturer's own buffer rather than a linked structure.
 */
/obj/item/circuit_component/chem/output_manufacturer
	display_name = "Manufacturer Output"
	desc = "Sends chemicals into the manufacturer this circuit is installed in."

	circuit_flags = CIRCUIT_FLAG_INPUT_SIGNAL
	ui_buttons = list(
		"plus" = "add",
		"minus" = "remove",
	)

	var/list/chemical_inputs
	var/datum/port/input/heat_input

/obj/item/circuit_component/chem/output_manufacturer/populate_ports()
	chemical_inputs = list()
	AddComponent(/datum/component/circuit_component_add_port, \
		port_list = chemical_inputs, \
		add_action = "add", \
		remove_action = "remove", \
		port_type = PORT_TYPE_CHEMICAL_LIST, \
		prefix = "Chemical Input", \
		minimum_amount = 2, \
	)
	heat_input = add_input_port("Desired Heat", PORT_TYPE_NUMBER, default = 275)

/obj/item/circuit_component/chem/output_manufacturer/input_received(datum/port/input/port, list/return_values)
	//Resolved every pulse rather than cached: the circuit can be pulled out of one
	//manufacturer and dropped into another without ever being re-initialised.
	var/obj/structure/chemical_manufacturer/host = parent?.shell
	if(!istype(host) || !host.reagents)
		return

	var/list/chemical_list = collect_chemical_inputs(chemical_inputs)
	if(!length(chemical_list))
		return

	var/sane_heat = sanitize_heat(heat_input)
	host.reagents.add_reagent_list(chemical_list, temperature = sane_heat)

/obj/item/circuit_component/chem/output_manufacturer/after_work_call()
	clear_all_temp_ports()

/obj/item/circuit_component/chem/output_manufacturer/clear_all_temp_ports()
	for(var/datum/port/input/input as anything in chemical_inputs)
		input.value = null

#undef MANUFACTURER_RECHARGE_INTERVAL
