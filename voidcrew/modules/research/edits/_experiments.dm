/// Points paid out for completing an experiment. Sized against the node ladder in
/// code/__DEFINES/research.dm: one experiment funds exactly one tier-5 node.
#define RESEARCH_POINTS_PER_EXPERIMENT 200

/datum/experiment/finish_experiment(datum/component/experiment_handler/experiment_handler)
	. = ..()
	experiment_handler.linked_web.add_point_list(list(
		TECHWEB_POINT_TYPE_GENERIC = RESEARCH_POINTS_PER_EXPERIMENT),
	)

/**
 * Ordnance experiments never pass through finish_experiment() - they are finished off from
 * /datum/techweb/add_scientific_paper(), which flips the experiment's completed flag and calls
 * complete_experiment() on us directly, so publishing a paper paid none of the flat experiment bonus above.
 *
 * Pay it here when (and only when) the publication is what actually completed the experiment. Papers that
 * complete nothing pay nothing: publishing a further tier of an already-completed experiment finds it in
 * completed_experiments, so add_experiment() refuses to re-add it and complete_experiment() is never reached.
 */
/datum/techweb/add_scientific_paper(datum/scientific_paper/paper_to_add)
	var/experiment_path = paper_to_add?.experiment_path
	// Nothing to pay for if we can't tell which experiment this is, or it was already completed before this paper.
	var/completed_before = isnull(experiment_path) || !isnull(completed_experiments[experiment_path])
	. = ..()
	if(!. || completed_before)
		return
	if(isnull(completed_experiments[experiment_path])) // paper published, but it didn't complete the experiment
		return
	add_point_list(list(TECHWEB_POINT_TYPE_GENERIC = RESEARCH_POINTS_PER_EXPERIMENT))

#undef RESEARCH_POINTS_PER_EXPERIMENT


/**
 * Limit the server search to links the server explicitly permits. Upstream matches servers
 * purely by z-level, but in this fork docked ships share a z: an encounter berth or an outpost
 * pad puts two crews' R&D servers on the same level. Each server's research_link_available()
 * applies the normal same-site rule and any approved relay grant, so a neighbour's web cannot
 * be selected accidentally while a valid relay remains discoverable.
 */
/datum/controller/subsystem/research/find_valid_servers(turf/location, datum/techweb/checking_web)
	var/list/valid_servers = list()
	for(var/obj/machinery/rnd/server/server as anything in checking_web.techweb_servers)
		if(server.research_link_available(location))
			valid_servers += server
	return valid_servers

/**
 * Non-forced links are the ones the Experiment Configuration UI sends. Validate them here
 * rather than trusting the UI: the web must have a server this handler's location may
 * legitimately reach (find_valid_servers above), so the Connect button works for an approved
 * local or relay-backed web while a crafted href still cannot tap an unavailable neighbour's.
 * Forced links - the multitool route and a server claiming its own unlinked handlers - still use
 * the central site gate.
 */
/datum/component/experiment_handler/link_techweb(datum/techweb/new_web, forced)
	if(new_web && !can_link_site_techweb(parent, new_web))
		return FALSE
	if(!forced)
		if(isnull(new_web) || !length(SSresearch.find_valid_servers(get_turf(parent), new_web)))
			return
	return ..()

/datum/component/experiment_handler/proc/validate_research_site()
	if(!linked_web)
		return FALSE
	if(can_link_site_techweb(parent, linked_web))
		return TRUE
	unlink_techweb()
	return FALSE

/datum/component/experiment_handler/action_experiment(datum/source, ...)
	if(!validate_research_site())
		return FALSE
	return ..()

/datum/component/experiment_handler/ui_data(mob/user)
	validate_research_site()
	return ..()

/datum/component/experiment_handler/ui_act(action, list/params, datum/tgui/ui, datum/ui_state/state)
	if(!validate_research_site() && (action in list("select_experiment", "start_experiment_callback")))
		return TRUE
	return ..()

/datum/component/experiment_handler/can_select_experiment(datum/experiment/experiment)
	if(!validate_research_site())
		return FALSE
	return ..()

/**
 * Experiment handlers are the only research machinery in this fork that links itself: everything
 * else (R&D console, protolathe, operating computer...) is multitooled to the ship's server by hand.
 * Since CONNECT_TO_RND_SERVER_ROUNDSTART no longer falls back to the global SCIENCE web, a handler
 * built before the ship's R&D server exists starts with no link at all, and an unlinked handler is
 * completely silent - it can't select an experiment, so the "not related to your experiment" line
 * never fires either. Say so on examine, and say so when someone tries to use it.
 */
/datum/component/experiment_handler/RegisterWithParent()
	. = ..()
	RegisterSignal(parent, COMSIG_ATOM_EXAMINE, PROC_REF(on_examine_server_link))

/datum/component/experiment_handler/UnregisterFromParent()
	UnregisterSignal(parent, COMSIG_ATOM_EXAMINE)
	return ..()

/datum/component/experiment_handler/proc/on_examine_server_link(datum/source, mob/user, list/examine_text)
	SIGNAL_HANDLER

	if(linked_web)
		examine_text += span_notice("It is linked to the R&D server network of [linked_web.organization].")
		return
	examine_text += span_warning("It has no R&D server link, so it cannot run experiments or bank any points.")
	examine_text += span_notice("Copy a techweb from an R&D server with a [EXAMINE_HINT("multitool")], then use the multitool on this.")

/**
 * Handlers with no server link have no network to announce on. Without this they'd all match each
 * other (linked_web == null == linked_web) and a single published paper would make every unlinked
 * scanner in the galaxy read the announcement out loud.
 */
/datum/component/experiment_handler/announce_message_to_all(message)
	if(isnull(linked_web))
		return
	return ..()

/**
 * Points whatever experiment handler `target` carries at the techweb held in a multitool's buffer.
 * Returns TRUE if the multitool click was consumed.
 *
 * Shared by every experiment-handler machine, because the linking rules are the handler's, not the
 * machine's. The Experiment Configuration UI can only connect to webs with a server on this ship
 * (see link_techweb() above); the multitool is the forced route that can bind a handler to any
 * web, including another crew's, on purpose.
 */
/proc/voidcrew_multitool_link_experiment_handler(atom/movable/target, mob/living/user, obj/item/multitool/tool)
	var/datum/component/experiment_handler/handler = target.GetComponent(/datum/component/experiment_handler)
	if(isnull(handler))
		return FALSE
	if(QDELETED(tool.buffer) || !istype(tool.buffer, /datum/techweb))
		target.balloon_alert(user, "no techweb in buffer!")
		return FALSE
	if(!can_link_site_techweb(target, tool.buffer))
		target.balloon_alert(user, "server belongs to another site")
		return FALSE
	// One click relinks. The old Experi-Scanner flow spent the first click silently unlinking and only
	// linked on a second one, which reads as a multitool that does nothing.
	if(handler.linked_web)
		handler.unlink_techweb()
	handler.link_techweb(tool.buffer, TRUE)
	target.say("Linked to Server!")
	return TRUE

/datum/component/experiment_handler/ignored_handheld_experiment_attempt(datum/source, atom/target, mob/user, list/modifiers)
	SIGNAL_HANDLER

	if(isnull(linked_web) && !(config_flags & EXPERIMENT_CONFIG_SILENT_FAIL))
		playsound(user, 'sound/machines/buzz/buzz-sigh.ogg', 25)
		var/atom/scanner = parent
		to_chat(user, span_warning("[scanner] has no R&D server link. Copy a techweb from an R&D server with a multitool, then use the multitool on [scanner]."))
		return
	return ..()
