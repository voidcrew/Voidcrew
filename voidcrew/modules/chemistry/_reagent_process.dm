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
	// isnull(reagents.reagent_list) is the teardown case, and it is reachable on every container
	// that is still mid-reaction when it dies. /datum/reagents/Destroy() nulls reagent_list, and
	// THEN calls force_stop_reacting() -> finish_reacting() -> update_total(), which ends with
	// SEND_SIGNAL(src, COMSIG_REAGENTS_HOLDER_UPDATED) - the signal on_reagent_change() (and so
	// this proc) is hooked to. my_atom.reagents is only cleared further down Destroy(), so the
	// isnull(reagents) test still passes and the Copy() below ran on a null list. Signal handlers are dispatched
	// through call()(), which is why it logged as a bare "Cannot execute null.Copy()" with no
	// call stack at all.
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
