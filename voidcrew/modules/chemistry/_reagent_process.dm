/*
 * Lets a reagent react to its own container's contents changing, rather than
 * only to a mob metabolising it. Ported from monkestation, which uses it for
 * Australium.
 */

/datum/reagent
	/// If set, reagent_fire() is called whenever the container holding this
	/// reagent has its contents changed.
	var/requires_process = FALSE

/**
 * Called when a reagent container holding this reagent has its contents changed.
 *
 * Runs inside the container's reagent-change signal handler, so it must not
 * sleep. It is safe to add or remove reagents from host - reagent_processing()
 * guards against the re-entry that causes.
 */
/datum/reagent/proc/reagent_fire(obj/item/reagent_containers/host)
	return

/obj/item/reagent_containers
	/// Re-entry guard: reagent_fire() edits the very holder whose change signal
	/// called us, which would otherwise recurse.
	var/processing_reagents = FALSE

/obj/item/reagent_containers/proc/reagent_processing()
	// A holder can be tearing down while its atom still points at it: Destroy()
	// nulls reagent_list before clearing my_atom.reagents, and update_total()
	// signals during that window.
	if(processing_reagents || isnull(reagents) || isnull(reagents.reagent_list))
		return
	processing_reagents = TRUE
	// Copy first - reagent_fire() is allowed to add and remove reagents, which
	// mutates the list we would otherwise be iterating.
	for(var/datum/reagent/listed_reagent as anything in reagents.reagent_list.Copy())
		// A previous reagent_fire() may have deleted this one, which nulls the
		// entry in our copy in place.
		if(isnull(listed_reagent))
			continue
		if(listed_reagent.requires_process)
			listed_reagent.reagent_fire(src)
	processing_reagents = FALSE
