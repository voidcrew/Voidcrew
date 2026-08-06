/*
 * Where the chemistry components are allowed to live.
 *
 * Ported from monkestation's wiremod_chem module (housing/chemical_circuit.dm).
 *
 * Chemistry components conjure, move and inject reagents, so they are kept off the generic
 * circuit board entirely: they only work in a chemical circuit board, which in turn is what
 * the chemical manufacturer is built to hold. That keeps automated chem production a thing
 * you build a machine for rather than something you carry in a pocket.
 */
/obj/item/integrated_circuit/is_component_blacklisted(obj/item/circuit_component/to_check)
	. = ..()
	if(.)
		return .
	//Unremovable components are installed by a shell, not slotted in by a player - the
	//chemical manufacturer's own Manufacturer Output is one. Blocking those would leave a
	//manufacturer holding a circuit with no way out, so they are always allowed through.
	if(!to_check.removable)
		return FALSE
	return istype(to_check, /obj/item/circuit_component/chem)

/obj/item/integrated_circuit/chemical
	name = "chemical circuit board"
	desc = "An integrated circuit board unlocked to accept chemistry components."

/obj/item/integrated_circuit/chemical/is_component_blacklisted(obj/item/circuit_component/to_check)
	//Chemistry components are the whole point of this board, so the base restriction is
	//lifted. Two things stay out:
	// - assoc_literal, which would let you hand-author a chemical list from nothing and
	//   sidestep the synthesizer's power and precursor costs entirely.
	// - the BCI components, which are unbalanced and deliberately unobtainable.
	if(istype(to_check, /obj/item/circuit_component/assoc_literal))
		return TRUE
	if(istype(to_check, /obj/item/circuit_component/chem/bci))
		return TRUE
	return FALSE
