/*
 * Base type for every industrial chemistry circuit component.
 *
 * Ported from monkestation's wiremod_chem module.
 *
 * Chemical payloads are transient: a component is handed a chemical list on a pulse,
 * consumes it, and must forget it. If the port kept its value the next unrelated pulse
 * would process the same chemicals again and conjure matter out of nothing, so every
 * component that carries chemicals wipes its chemical ports in after_work_call(), which
 * core wiremod fires at the very end of trigger_component().
 */
/obj/item/circuit_component/chem
	category = "Chemistry"
	energy_usage_per_input = 0.001 * STANDARD_CELL_CHARGE //the stock component rate; subtypes scale off this

/// Blanks every port on the component. Subtypes override this to wipe only the ports
/// that actually carry a payload, so configuration inputs (heat, unit counts) survive.
/obj/item/circuit_component/chem/proc/clear_all_temp_ports()
	for(var/datum/port/output/output as anything in output_ports)
		output.value = null
	for(var/datum/port/input/input as anything in input_ports)
		input.value = null

/**
 * Folds a list of chemical-list input ports down into one summed chemical list.
 *
 * VOIDCREW FIX: monkestation did `chemical_list += input_port.value` for each port.
 * DM list addition concatenates rather than merges, so two inputs both carrying
 * /datum/reagent/water produced a list with the key "water" present twice; iterating it
 * then read the *first* associated value both times, so 10u + 40u came out as 20u.
 * Summing explicitly is both correct and cheaper.
 */
/obj/item/circuit_component/chem/proc/collect_chemical_inputs(list/datum/port/input/ports)
	var/list/collected = list()
	for(var/datum/port/input/input_port as anything in ports)
		var/list/incoming = input_port.value
		if(!length(incoming))
			continue
		for(var/reagent_type in incoming)
			var/volume = incoming[reagent_type]
			if(!volume)
				continue
			collected[reagent_type] += volume
	return collected

/**
 * Reads a "Desired Heat" port into a temperature that is safe to hand a reagent holder.
 *
 * The heat ports default to 275K, but a player can wire a number component into one, and an
 * unset number port reads as 0. Clamping a bare 0 would set the holder to 4K and flash-freeze
 * the batch, so an absent or zero value falls back to the port's own default instead.
 */
/obj/item/circuit_component/chem/proc/sanitize_heat(datum/port/input/heat_port, fallback = 275)
	var/requested = heat_port?.value
	if(!requested)
		requested = fallback
	return clamp(requested, 4, 1000)

/// Snapshots a reagent holder's contents as a chemical list.
/obj/item/circuit_component/chem/proc/holder_to_chemical_list(datum/reagents/holder)
	var/list/built = list()
	if(!holder)
		return built
	for(var/datum/reagent/reagent as anything in holder.reagent_list)
		built[reagent.type] += reagent.volume
	return built
