/**
 * Chemical filter.
 *
 * Ported from monkestation's wiremod_chem module.
 *
 * Partitions an incoming chemical list into "named in the filter" and "everything else".
 */
/obj/item/circuit_component/chem/filter
	display_name = "Chemical Filter"
	desc = "General chemical filter."
	energy_usage_per_input = 0.0025 * STANDARD_CELL_CHARGE

	circuit_flags = CIRCUIT_FLAG_INPUT_SIGNAL|CIRCUIT_FLAG_OUTPUT_SIGNAL

	/// The chemicals to sort.
	var/datum/port/input/chemical_input
	/// A list of reagent names to pull out.
	var/datum/port/input/filter_list

	/// Everything the filter list named.
	var/datum/port/output/filtered_output
	/// Everything it did not.
	var/datum/port/output/junk_output

/*
 * ckey'd-name -> reagent type, built once on first use.
 *
 * Filter lists are typed by players, so "Space Cleaner", "space cleaner" and "spacecleaner"
 * all have to resolve. Doing that by scanning GLOB.name2reagent per name per pulse would be
 * hundreds of string compares every time a circuit fires, hence the cached map.
 */
/proc/fuzzy_name2reagent()
	var/static/list/cached
	if(cached)
		return cached
	cached = list()
	for(var/reagent_name in GLOB.name2reagent)
		cached[ckey(LOWER_TEXT(reagent_name))] = GLOB.name2reagent[reagent_name]
	return cached

/obj/item/circuit_component/chem/filter/populate_ports()
	. = ..()
	chemical_input = add_input_port("Chemicals", PORT_TYPE_CHEMICAL_LIST)
	filtered_output = add_output_port("Filtered Chemicals", PORT_TYPE_CHEMICAL_LIST, port_type = /datum/port/output/singular)
	junk_output = add_output_port("Unfiltered Chemicals", PORT_TYPE_CHEMICAL_LIST, port_type = /datum/port/output/singular)
	filter_list = add_input_port("Filter List", PORT_TYPE_LIST(PORT_TYPE_STRING))

/obj/item/circuit_component/chem/filter/input_received(datum/port/input/port, list/return_values)
	var/list/inputted_chemicals = chemical_input.value
	if(!length(inputted_chemicals))
		filtered_output.set_output(list())
		junk_output.set_output(list())
		return

	//Resolve the filter names to reagent types once, as a set we can test against.
	var/list/wanted_types = list()
	for(var/name in filter_list.value)
		//GLOB.name2reagent is keyed by exact display name; players type by hand, so fall
		//back to a case- and space-insensitive lookup rather than silently matching nothing.
		var/datum/reagent/resolved = GLOB.name2reagent[name] || fuzzy_name2reagent()[ckey(LOWER_TEXT(name))]
		if(resolved)
			wanted_types[resolved] = TRUE

	/*
	 * VOIDCREW FIX: monkestation iterated the *filter list* rather than the input, which
	 * meant (a) any input chemical the filter did not name was dropped on the floor
	 * instead of reaching junk_output, and (b) filter entries that were absent from the
	 * input were emitted on junk_output with a null volume. Partitioning the input
	 * conserves total volume, which is the whole point of a filter.
	 */
	var/list/output_reagents = list()
	var/list/rest_reagents = list()
	for(var/reagent_type in inputted_chemicals)
		var/volume = inputted_chemicals[reagent_type]
		if(!volume)
			continue
		if(wanted_types[reagent_type])
			output_reagents[reagent_type] += volume
		else
			rest_reagents[reagent_type] += volume

	junk_output.set_output(rest_reagents)
	filtered_output.set_output(output_reagents)

/obj/item/circuit_component/chem/filter/after_work_call()
	clear_all_temp_ports()

/obj/item/circuit_component/chem/filter/clear_all_temp_ports()
	chemical_input.value = null
	filtered_output.value = null
	junk_output.value = null
