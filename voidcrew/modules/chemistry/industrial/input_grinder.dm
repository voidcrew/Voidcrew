/**
 * Remote chemical grinder.
 *
 * Ported from monkestation's wiremod_chem module (components/inputs/grinder_input.dm).
 *
 * A chemical input tank that eats anything dropped or thrown onto its tile and grinds or
 * juices it straight into its own buffer, so a circuit can be fed by a conveyor line
 * rather than by hand.
 */
/obj/structure/chemical_input/grinder
	name = "remote chemical grinder"
	desc = "Grinds anything dropped onto it straight into chemicals."
	icon = 'icons/obj/pipes_n_cables/hydrochem/plumbers.dmi'
	icon_state = "grinder_chemical"
	reagent_flags = TRANSPARENT | DRAINABLE
	component_name = "Grinder Input"
	density = FALSE

/obj/structure/chemical_input/grinder/Initialize(mapload)
	. = ..()
	var/static/list/loc_connections = list(
		COMSIG_ATOM_ENTERED = PROC_REF(on_entered),
	)
	AddElement(/datum/element/connect_loc, loc_connections)

/obj/structure/chemical_input/grinder/proc/on_entered(datum/source, atom/movable/arrived)
	SIGNAL_HANDLER
	grind_item(arrived)

/*
 * VOIDCREW ADAPTATION: monkestation called on_juice()/on_grind() and read juice_results
 * directly. On this fork's tg base both of those procs are PROTECTED_PROC (uncallable from
 * outside the item), and juice_results has been replaced by a single juice_typepath. The
 * supported entry points are now grind()/juice(), which handle the reagent transfer, recurse
 * into contents, and call blended() on the grinder to dispose of the item.
 */
/obj/structure/chemical_input/grinder/proc/grind_item(atom/movable/target)
	if(reagents.holder_full())
		return
	if(!isitem(target))
		return
	var/obj/item/item = target

	//Juicing is preferred where the item supports it, matching the old behaviour.
	if(item.juice_typepath && item.juice(reagents, null, src))
		return
	if(length(item.grind_results) || item.reagents?.total_volume)
		item.grind(reagents, null, src)
