/**
 * Allow RND machines to be connected via multitool
 * But only if we're connected to science's node by default
 * Check is for stuff like Autolathes.
 */
/obj/machinery/rnd/Destroy()
	unsync_research_servers()
	return ..()

/obj/machinery/rnd/unsync_research_servers()
	if(stored_research)
		stored_research.connected_machines -= src
		stored_research = null

/// Register every actual connection, including direct links, exactly once.
/obj/machinery/rnd/connect_techweb(datum/techweb/new_techweb)
	unsync_research_servers()
	. = ..()
	if(stored_research)
		stored_research.connected_machines |= src

/obj/machinery/rnd/multitool_act(mob/living/user, obj/item/multitool/tool)
	// The upstream handler also returns success after opening the maintenance wires.
	// That action must not change a link or dereference an unlinked machine's web.
	if(panel_open)
		return ..()
	if(istype(tool.buffer, /datum/techweb) && !can_link_site_techweb(src, tool.buffer))
		balloon_alert(user, "server belongs to another site")
		return FALSE
	. = ..()
	if(. && stored_research && stored_research == tool.buffer)
		say("Linked to Server!")

/**
 * The destructive scanner is the only experiment-handler machine with no way to pick a server: it
 * isn't an /obj/machinery/rnd, so the multitool handler above doesn't reach it, and upstream simply
 * assumed it would auto-connect to the station techweb forever. It links itself to a server on its
 * own z-level at build time and is adopted by a ship R&D server that comes online after it, but
 * without this a scanner that misses both has no route back.
 */
/obj/machinery/destructive_scanner/multitool_act(mob/living/user, obj/item/multitool/tool)
	if(voidcrew_multitool_link_experiment_handler(src, user, tool))
		return TRUE
	return ..()

/**
 * Tied to Production
 */
/obj/machinery/rnd/production/update_designs()
	if(!stored_research)
		techweb_updating = FALSE
		cached_designs?.Cut()
		return
	return ..()

// Production's upstream connect handler unregisters design signals before calling
// the base R&D handler. Reject an invalid target before it touches the current link.
/obj/machinery/rnd/production/connect_techweb(datum/techweb/new_techweb)
	if(new_techweb && !can_link_site_techweb(src, new_techweb))
		return FALSE
	return ..()

/obj/machinery/rnd/production/unsync_research_servers()
	if(stored_research)
		UnregisterSignal(stored_research, list(COMSIG_TECHWEB_ADD_DESIGN, COMSIG_TECHWEB_REMOVE_DESIGN))
	cached_designs?.Cut()
	. = ..()
	if(!QDELETED(src))
		update_static_data_for_all_viewers()

/obj/machinery/rnd/production/ui_act(action, list/params, datum/tgui/ui)
	if(action == "build" && !validate_research_site(stored_research))
		say("No research server linked.")
		return TRUE
	return ..()

/obj/machinery/rnd/production/ui_data(mob/user)
	validate_research_site(stored_research)
	return ..()

/obj/machinery/rnd/production/ui_static_data(mob/user)
	validate_research_site(stored_research)
	return ..()

/// Lathes pay per item, so a queued batch must recheck before each payment.
/obj/machinery/rnd/production/do_make_item(datum/design/design, items_remaining, build_time_per_item, material_cost_coefficient, charge_per_item, turf/target, alist/user_data)
	if(!design || !validate_research_site(stored_research) || !stored_research.researched_designs[design.id])
		say("Unable to continue production: research link or design unavailable.")
		finalize_build()
		return
	return ..()
