// Voidcrew extensions to code/modules/wiremod/core/integrated_circuit.dm.

/**
 * Whether this circuit board refuses to hold the given component at all.
 * Checked before anything else in add_component(), so it also blocks remote printing.
 */
/obj/item/integrated_circuit/proc/is_component_blacklisted(obj/item/circuit_component/to_check)
	return FALSE
