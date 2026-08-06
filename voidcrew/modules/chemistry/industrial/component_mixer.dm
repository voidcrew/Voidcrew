/**
 * Chemical mixer.
 *
 * Ported from monkestation's wiremod_chem module.
 *
 * Takes any number of chemical lists, drops them into a scratch reagent holder at a
 * chosen temperature, lets them react, and emits whatever came out. This is the only
 * component where reactions actually run, which is why it is the expensive one.
 */
/obj/item/circuit_component/chem/mixer
	display_name = "Chemical Mixer"
	desc = "Mixes chemicals."
	energy_usage_per_input = 0.004 * STANDARD_CELL_CHARGE

	circuit_flags = CIRCUIT_FLAG_INPUT_SIGNAL|CIRCUIT_FLAG_OUTPUT_SIGNAL

	/// The player-added chemical list inputs.
	var/list/chemical_inputs
	/// Temperature the mix is brought to before reacting.
	var/datum/port/input/heat_input
	var/datum/port/output/output
	/// Scratch holder. Filled, reacted and emptied inside a single pulse.
	var/datum/reagents/reagent_holder

	ui_buttons = list(
		"plus" = "add",
		"minus" = "remove",
	)

/obj/item/circuit_component/chem/mixer/Initialize(mapload)
	. = ..()
	reagent_holder = new /datum/reagents(10000)
	reagent_holder.my_atom = src

/obj/item/circuit_component/chem/mixer/Destroy()
	//VOIDCREW FIX: monkestation called . = ..() first and then qdel'd the holder, so the
	//holder was freed after the component had already been torn down. Free first.
	QDEL_NULL(reagent_holder)
	return ..()

/obj/item/circuit_component/chem/mixer/populate_ports()
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
	output = add_output_port("Output", PORT_TYPE_CHEMICAL_LIST, order = 1.1, port_type = /datum/port/output/singular)

/obj/item/circuit_component/chem/mixer/input_received(datum/port/input/port, list/return_values)
	var/list/chemical_list = collect_chemical_inputs(chemical_inputs)
	if(!length(chemical_list))
		return

	var/sane_heat = sanitize_heat(heat_input)

	reagent_holder.add_reagent_list(chemical_list, temperature = sane_heat)
	reagent_holder.handle_reactions()

	output.set_output(holder_to_chemical_list(reagent_holder))
	reagent_holder.clear_reagents()

/obj/item/circuit_component/chem/mixer/after_work_call()
	clear_all_temp_ports()

/obj/item/circuit_component/chem/mixer/clear_all_temp_ports()
	for(var/datum/port/input/input as anything in chemical_inputs)
		input.value = null
	output.value = null
