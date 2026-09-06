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

/obj/machinery/rnd/multitool_act(mob/living/user, obj/item/multitool/tool)
	if(istype(tool.buffer, /datum/techweb) && !can_link_site_techweb(src, tool.buffer))
		balloon_alert(user, "server belongs to another site")
		return FALSE
	if(stored_research && !QDELETED(tool.buffer) && istype(tool.buffer, /datum/techweb)) //disconnect old one
		stored_research.connected_machines -= src
	. = ..()
	if(.)
		stored_research.connected_machines += src //connect new one
		say("Linked to Server!")
		var/obj/machinery/rnd/production/production = src
		if(istype(production))
			production.update_designs()
		return TRUE

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
		cached_designs?.Cut()
		return
	return ..()

/obj/machinery/rnd/production/unsync_research_servers()
	if(stored_research)
		UnregisterSignal(stored_research, list(COMSIG_TECHWEB_ADD_DESIGN, COMSIG_TECHWEB_REMOVE_DESIGN))
	cached_designs?.Cut()
	return ..()
