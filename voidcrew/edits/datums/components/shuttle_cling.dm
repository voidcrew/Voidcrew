// Voidcrew extensions to code/datums/components/shuttle_cling.dm.

/datum/component/shuttle_cling/RegisterWithParent()
	. = ..()
	// Drift may immediately move the parent off transit and delete this component.
	// Start it only after _JoinParent(), so removal can safely unregister us.
	ADD_TRAIT(parent, TRAIT_HYPERSPACED, REF(src))

	RegisterSignals(parent, list(COMSIG_MOVABLE_MOVED, COMSIG_MOVABLE_UNBUCKLE, COMSIG_ATOM_NO_LONGER_PULLED), PROC_REF(update_state))
	RegisterSignal(parent, SIGNAL_REMOVETRAIT(TRAIT_FREE_HYPERSPACE_MOVEMENT), PROC_REF(initialize_loop))
	RegisterSignal(parent, SIGNAL_ADDTRAIT(TRAIT_FREE_HYPERSPACE_MOVEMENT), PROC_REF(clear_loop))

	//Items have this cool thing where they're first put on the floor if you grab them from storage, and then into your hand, which isn't caught by movement signals that well
	if(isitem(parent))
		RegisterSignal(parent, COMSIG_ITEM_PICKUP, PROC_REF(do_remove))

	if(!HAS_TRAIT(parent, TRAIT_FREE_HYPERSPACE_MOVEMENT))
		initialize_loop()
	if(QDELETED(src))
		return

	update_state(parent) //otherwise we'll get moved 1 tile before we can correct ourselves, which isnt super bad but just looks jank
