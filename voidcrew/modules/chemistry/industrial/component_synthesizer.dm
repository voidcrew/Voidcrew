/**
 * Chemical synthesizer.
 *
 * Ported from monkestation's wiremod_chem module (components/generator.dm).
 *
 * The faucet of the whole system: turns power, and optionally precursor feedstock, into
 * raw dispensable reagents. The precursor economy lives in check_power_modifictions():
 * a synthesizer running inside a chemical manufacturer with a stocked precursor tank pays
 * the flat component rate, one that has run dry pays five times the requested units, and
 * one running loose in a hand-held circuit pays twenty-five times. That gradient is what
 * makes the manufacturer worth building instead of pocketing a circuit.
 */
/obj/item/circuit_component/chem/synthesizer
	display_name = "Chemical Synthesizer"
	desc = "General chemical synthesizer component."
	energy_usage_per_input = 0.0001 * STANDARD_CELL_CHARGE

	circuit_flags = CIRCUIT_FLAG_INPUT_SIGNAL|CIRCUIT_FLAG_OUTPUT_SIGNAL

	/// Which reagent to make.
	var/datum/port/input/option/chemical_to_generate
	/// How many units of it.
	var/datum/port/input/per_chemical_amount

	var/datum/port/output/output

	/// The raw reagents a synthesizer is allowed to conjure. Deliberately the base
	/// chem-dispenser set: anything more interesting has to be reacted for in a mixer.
	var/list/dispensable_reagents = list(
		/datum/reagent/aluminium,
		/datum/reagent/silver,
		/datum/reagent/bromine,
		/datum/reagent/carbon,
		/datum/reagent/chlorine,
		/datum/reagent/copper,
		/datum/reagent/consumable/ethanol,
		/datum/reagent/fluorine,
		/datum/reagent/hydrogen,
		/datum/reagent/iodine,
		/datum/reagent/iron,
		/datum/reagent/lithium,
		/datum/reagent/mercury,
		/datum/reagent/nitrogen,
		/datum/reagent/oxygen,
		/datum/reagent/phosphorus,
		/datum/reagent/potassium,
		/datum/reagent/uranium/radium,
		/datum/reagent/silicon,
		/datum/reagent/sodium,
		/datum/reagent/stable_plasma,
		/datum/reagent/consumable/sugar,
		/datum/reagent/sulfur,
		/datum/reagent/toxin/acid,
		/datum/reagent/water,
		/datum/reagent/fuel,
	)
	/// Built display name -> type map, because the option port shows names to the player.
	var/list/reagent_list = list()

/// The most units one pulse can conjure, and the ceiling used when billing for power.
#define SYNTHESIZER_MAX_UNITS 100

/obj/item/circuit_component/chem/synthesizer/populate_options()
	for(var/datum/reagent/reagent as anything in dispensable_reagents)
		reagent_list[initial(reagent.name)] = reagent

	chemical_to_generate = add_option_port("Chemical", reagent_list)

/obj/item/circuit_component/chem/synthesizer/populate_ports()
	output = add_output_port("Output", PORT_TYPE_CHEMICAL_LIST, order = 1.1, port_type = /datum/port/output/singular)
	per_chemical_amount = add_input_port("Units", PORT_TYPE_NUMBER, default = 1)

/// Returns the units this pulse will actually produce. Kept in one place so the power
/// bill and the output can never disagree.
/obj/item/circuit_component/chem/synthesizer/proc/requested_units()
	return clamp(per_chemical_amount?.value || 0, 0, SYNTHESIZER_MAX_UNITS)

/*
 * NOTE: this has a side effect - it spends precursor. That is intentional and is why the
 * hook is called exactly once per trigger, from should_receive_input(). Do not call it to
 * "check" anything.
 */
/obj/item/circuit_component/chem/synthesizer/check_power_modifictions()
	//VOIDCREW FIX: monkestation read the raw port value here, so a null or negative Units
	//input billed zero power while input_received() still clamped and produced reagent.
	var/units = requested_units()
	if(!units)
		return energy_usage_per_input

	var/obj/structure/chemical_manufacturer/host = parent?.shell
	if(!istype(host))
		return energy_usage_per_input * 25 * units //no housing at all: brute-force matter fabrication

	if(!host.has_precursor(units))
		//Burn whatever precursor is left and pay the premium on the shortfall.
		var/precursor = host.connected_tank?.stored_precursor || 0
		var/shortfall = units - precursor
		host.process_precursor(units)
		return energy_usage_per_input * 5 * shortfall

	host.process_precursor(units)
	return energy_usage_per_input

/obj/item/circuit_component/chem/synthesizer/input_received(datum/port/input/port, list/return_values)
	if(!chemical_to_generate?.value)
		return
	var/datum/reagent/chosen = reagent_list[chemical_to_generate.value]
	if(!chosen)
		return

	var/units = requested_units()
	if(!units)
		return

	//Built by hand rather than list(chosen = units): DM reads a bare identifier on the left
	//of = inside list() as a literal string key, which would produce list("chosen" = units).
	var/list/built_output = list()
	built_output[chosen] = units
	output.set_output(built_output)

/obj/item/circuit_component/chem/synthesizer/after_work_call()
	clear_all_temp_ports()

/obj/item/circuit_component/chem/synthesizer/clear_all_temp_ports()
	output.value = null

#undef SYNTHESIZER_MAX_UNITS
