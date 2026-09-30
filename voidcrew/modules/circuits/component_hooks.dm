//Voidcrew: hook for components that need to clear transient port values
//once a trigger has finished, so a chemical payload isn't re-sent on the next pulse.
/obj/item/circuit_component/proc/after_work_call()
	return

//Voidcrew: lets a component vary its own power draw per trigger instead of
//always paying the flat energy_usage_per_input. The chemistry synthesiser uses this to
//charge more when it has to fabricate matter without precursor feedstock.
//(Name keeps the upstream monkestation typo so ported components match.)
/obj/item/circuit_component/proc/check_power_modifictions()
	return energy_usage_per_input

//Voidcrew: hard per-board component restrictions.
//Overridden rather than driven by a list var so a module can express "no subtype of X"
//without core having to know the module's type paths. Default is "everything allowed",
//which is the historic behaviour for every stock board.
/**
 * Whether this circuit board refuses to hold the given component at all.
 * Checked before anything else in add_component(), so it also blocks remote printing.
 */
/obj/item/integrated_circuit/proc/is_component_blacklisted(obj/item/circuit_component/to_check)
	return FALSE
