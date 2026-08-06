/**
 * Internal chemical tank.
 *
 * Ported from monkestation's wiremod_chem module.
 *
 * A buffer inside the circuit. Pulsing "Handle Input" pushes whatever is on the chemical
 * inputs into storage; pulsing the component's normal trigger draws a requested number of
 * units back out. Storage does not react - it is a tank, not a mixer.
 */
/obj/item/circuit_component/chem/internal_tank
	display_name = "Internal Chemical Tank"
	desc = "Holds chemicals inside your circuit."
	energy_usage_per_input = 0.0001 * STANDARD_CELL_CHARGE

	ui_buttons = list(
		"plus" = "add",
		"minus" = "remove",
	)

	circuit_flags = CIRCUIT_FLAG_INPUT_SIGNAL|CIRCUIT_FLAG_OUTPUT_SIGNAL

	var/datum/port/output/chemical_output
	var/list/chemical_inputs
	var/datum/port/input/heat_input
	/// How many units to draw back out on a read pulse.
	var/datum/port/input/reagent_amount
	/// Separate trigger for storing rather than drawing.
	var/datum/port/input/handle_input

	/// Long-term storage.
	var/datum/reagents/reagent_holder
	/// Scratch holder used to measure a draw before it leaves the component.
	var/datum/reagents/transferrance

/obj/item/circuit_component/chem/internal_tank/Initialize(mapload)
	. = ..()
	reagent_holder = new /datum/reagents(10000)
	reagent_holder.my_atom = src
	transferrance = new /datum/reagents(10000)
	transferrance.my_atom = src

/obj/item/circuit_component/chem/internal_tank/Destroy()
	//VOIDCREW FIX: monkestation ran . = ..() before QDEL_NULLing these, freeing the holders
	//after the component had already been destroyed. Free first, then chain.
	QDEL_NULL(reagent_holder)
	QDEL_NULL(transferrance)
	return ..()

/obj/item/circuit_component/chem/internal_tank/populate_ports()
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
	reagent_amount = add_input_port("Reagent Output Amount", PORT_TYPE_NUMBER)
	chemical_output = add_output_port("Reagent Output", PORT_TYPE_CHEMICAL_LIST, port_type = /datum/port/output/singular)
	handle_input = add_input_port("Handle Input", PORT_TYPE_SIGNAL, trigger = PROC_REF(handle_input))

/obj/item/circuit_component/chem/internal_tank/input_received(datum/port/input/port, list/return_values)
	var/sane_number = clamp(reagent_amount.value, 0, 1000)
	if(!sane_number)
		return

	reagent_holder.trans_to(transferrance, sane_number)

	chemical_output.set_output(holder_to_chemical_list(transferrance))
	transferrance.clear_reagents()

/// Stores whatever is currently on the chemical inputs.
/obj/item/circuit_component/chem/internal_tank/proc/handle_input(datum/port/input/port, list/return_values)
	var/list/chemical_list = collect_chemical_inputs(chemical_inputs)
	if(!length(chemical_list))
		return

	var/sane_heat = sanitize_heat(heat_input)
	reagent_holder.add_reagent_list(chemical_list, temperature = sane_heat)

	after_work_call()

/obj/item/circuit_component/chem/internal_tank/after_work_call()
	clear_all_temp_ports()

/obj/item/circuit_component/chem/internal_tank/clear_all_temp_ports()
	chemical_output.value = null
	for(var/datum/port/input/input as anything in chemical_inputs)
		input.value = null
