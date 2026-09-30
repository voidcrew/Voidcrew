// Voidcrew extensions to code/modules/wiremod/core/component.dm.

//VOIDCREW EDIT ADDITION: hook for components that need to clear transient port values
//once a trigger has finished, so a chemical payload isn't re-sent on the next pulse.
/obj/item/circuit_component/proc/after_work_call()
	return

//VOIDCREW EDIT ADDITION: lets a component vary its own power draw per trigger instead of
//always paying the flat energy_usage_per_input. The chemistry synthesiser uses this to
//charge more when it has to fabricate matter without precursor feedstock.
//(Name keeps the upstream monkestation typo so ported components match.)
/obj/item/circuit_component/proc/check_power_modifictions()
	return energy_usage_per_input
