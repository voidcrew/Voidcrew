/**
 * Weighted chemical splitter.
 *
 * Ported from monkestation's wiremod_chem module.
 *
 * Peels a chosen share off an incoming chemical list and passes the remainder on.
 * "Percent" takes that percentage of every reagent present; "Flat" divides a fixed unit
 * budget evenly across however many reagents are present.
 */
/obj/item/circuit_component/chem/weighted_splitter
	display_name = "Weighted Chemical Splitter"
	desc = "General chemical splitter, allows more fine grain control."
	energy_usage_per_input = 0.002 * STANDARD_CELL_CHARGE

	circuit_flags = CIRCUIT_FLAG_INPUT_SIGNAL|CIRCUIT_FLAG_OUTPUT_SIGNAL

	var/datum/port/input/chemical_input

	/// The share that was weighted out.
	var/datum/port/output/chemical_output
	/// Everything left over.
	var/datum/port/output/non_weighted_output

	/// Percent of each reagent, or a flat unit budget.
	var/datum/port/input/option/weight_type
	/// The percentage, or the unit budget.
	var/datum/port/input/number

/obj/item/circuit_component/chem/weighted_splitter/populate_options()
	//VOIDCREW EDIT: monkestation spelled this option "Precent". Corrected here; this is a
	//fresh port so there are no saved circuits carrying the old spelling.
	weight_type = add_option_port("Weight Type", list("Percent", "Flat"))

/obj/item/circuit_component/chem/weighted_splitter/populate_ports()
	chemical_input = add_input_port("Chemicals", PORT_TYPE_CHEMICAL_LIST)
	number = add_input_port("Number", PORT_TYPE_NUMBER)

	chemical_output = add_output_port("Weighted Output", PORT_TYPE_CHEMICAL_LIST, port_type = /datum/port/output/singular)
	non_weighted_output = add_output_port("Secondary Output", PORT_TYPE_CHEMICAL_LIST, port_type = /datum/port/output/singular)

/obj/item/circuit_component/chem/weighted_splitter/input_received(datum/port/input/port, list/return_values)
	//VOIDCREW FIX: work on a copy. Monkestation decremented the input port's own list in
	//place, which is the same list object the upstream component is still holding as its
	//output value.
	var/list/chemicals = chemical_input.value?.Copy()
	if(!length(chemicals))
		return

	var/filter_amount = number.value
	if(filter_amount <= 0)
		return

	var/list/weighted_output = list()
	var/list/rest = list()

	switch(weight_type.value)
		if("Percent")
			filter_amount = clamp(filter_amount, 0, 100)
			//VOIDCREW FIX: monkestation divided by the percentage, so asking for 50% handed
			//over 2% and asking for 1% handed over the whole batch. Multiply by the fraction.
			var/fraction = filter_amount / 100
			for(var/reagent_type in chemicals)
				var/taken = chemicals[reagent_type] * fraction
				weighted_output[reagent_type] += taken
				rest[reagent_type] += chemicals[reagent_type] - taken

		if("Flat")
			var/per_chemical_amount = filter_amount / length(chemicals)
			for(var/reagent_type in chemicals)
				var/taken = min(per_chemical_amount, chemicals[reagent_type])
				weighted_output[reagent_type] += taken
				rest[reagent_type] += chemicals[reagent_type] - taken

		else
			return

	non_weighted_output.set_output(rest)
	chemical_output.set_output(weighted_output)

/obj/item/circuit_component/chem/weighted_splitter/after_work_call()
	clear_all_temp_ports()

/obj/item/circuit_component/chem/weighted_splitter/clear_all_temp_ports()
	chemical_output.value = null
	non_weighted_output.value = null
	chemical_input.value = null
