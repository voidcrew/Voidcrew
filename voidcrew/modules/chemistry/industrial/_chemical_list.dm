/*
 * The chemical list circuit datatype.
 *
 * Ported from monkestation's wiremod_chem module.
 *
 * Every industrial chemistry component passes chemicals around as a plain associative
 * list of `reagent typepath -> volume in units`. It is deliberately *not* a reagent
 * holder: holders react, have a temperature, and are expensive to spin up per pulse.
 * A flat list is cheap to split, filter and weight, and only becomes a real holder at
 * the points where chemistry actually has to happen (the mixer, the internal tank, and
 * the output structures).
 *
 * Because it is composite it gets its own port colour and will only connect to other
 * chemical-list ports, so you cannot accidentally wire a number into a mixer.
 */
/datum/circuit_composite_template/chemical_list
	datatype = PORT_COMPOSITE_TYPE_CHEMICAL
	composite_datatype_path = /datum/circuit_datatype/composite_instance/chemical_list
	expected_types = 2

/*
 * We only ever generate one combination from this template (reagent path -> number), so a
 * constant name is both unique and readable. The default implementation would produce
 * "chemical list<entity, number>" in the circuit UI.
 *
 * NOTE: upstream monkestation put this override on /datum/circuit_composite_template/assoc_list
 * instead, which silently reskinned the stock associative-list datatype. Not ported.
 */
/datum/circuit_composite_template/chemical_list/generate_name(list/composite_datatypes)
	SHOULD_BE_PURE(TRUE)
	return "chemical list"

/datum/circuit_datatype/composite_instance/chemical_list
	color = "red"
	datatype_flags = DATATYPE_FLAG_COMPOSITE

/datum/circuit_datatype/composite_instance/chemical_list/convert_value_extensive(datum/port/port, value_to_convert, force)
	var/datum/circuit_datatype/key_handler = GLOB.circuit_datatypes[composite_datatypes[1]]
	var/datum/circuit_datatype/value_handler = GLOB.circuit_datatypes[composite_datatypes[2]]

	var/list/converted_list = list()
	for(var/data in value_to_convert)
		converted_list[key_handler.convert_value(port, data)] = value_handler.convert_value(port, value_to_convert[data])
	return converted_list
