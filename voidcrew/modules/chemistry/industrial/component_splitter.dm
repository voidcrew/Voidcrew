/**
 * Chemical splitter.
 *
 * Ported from monkestation's wiremod_chem module.
 *
 * Divides an incoming chemical list evenly across every output. Add and remove outputs
 * with the component's buttons; each output is singular so the split cannot be re-fanned
 * into two inputs and duplicated.
 */
/obj/item/circuit_component/chem/splitter
	display_name = "Chemical Splitter"
	desc = "General chemical splitter."

	ui_buttons = list(
		"plus" = "add",
		"minus" = "remove",
	)

	circuit_flags = CIRCUIT_FLAG_INPUT_SIGNAL|CIRCUIT_FLAG_OUTPUT_SIGNAL

	var/list/splitter_outputs
	var/datum/port/input/chemical_input

/obj/item/circuit_component/chem/splitter/populate_ports()
	splitter_outputs = list()
	AddComponent(/datum/component/circuit_component_add_port, \
		port_list = splitter_outputs, \
		add_action = "add", \
		remove_action = "remove", \
		port_type = PORT_TYPE_CHEMICAL_LIST, \
		prefix = "Split Output", \
		minimum_amount = 2, \
		is_output = TRUE, \
		is_singular = TRUE, \
	)
	chemical_input = add_input_port("Chemical Input", PORT_TYPE_CHEMICAL_LIST, order = 1.1)

/obj/item/circuit_component/chem/splitter/input_received(datum/port/input/port, list/return_values)
	var/list/outputs = splitter_outputs.Copy()
	var/split_count = length(outputs)
	if(!split_count)
		return

	var/list/inputs = chemical_input.value
	if(!length(inputs))
		return

	var/list/single_output_list = list()
	for(var/reagent_type in inputs)
		single_output_list[reagent_type] += inputs[reagent_type] / split_count

	for(var/datum/port/output/output as anything in outputs)
		//VOIDCREW FIX: hand every output its own copy. Monkestation set the same list
		//object on all of them, so a downstream component mutating its share silently
		//mutated every other branch's share too.
		output.set_output(single_output_list.Copy())

/obj/item/circuit_component/chem/splitter/after_work_call()
	clear_all_temp_ports()

/obj/item/circuit_component/chem/splitter/clear_all_temp_ports()
	for(var/datum/port/output/output as anything in splitter_outputs)
		output.value = null
	chemical_input.value = null
