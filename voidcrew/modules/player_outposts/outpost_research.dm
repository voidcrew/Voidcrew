/// An immutable completion certificate, including the actual (possibly random)
/// requirements/progress presented when the experiment completed. No specimens,
/// handlers, random re-rolls, or completion/reward callbacks are copied.
/datum/experiment/completion_record
	completed = TRUE
	var/evidence_json
	var/original_type

/datum/experiment/proc/research_record_type()
	return type

/datum/experiment/completion_record/research_record_type()
	return original_type

/datum/experiment/completion_record/is_complete()
	return TRUE

/datum/experiment/completion_record/check_progress()
	return json_decode(evidence_json)

/datum/techweb/proc/merge_completed_records(datum/techweb/source, datum/outpost_research_pair/pair)
	if(!source || source == src)
		return
	// Match manual disk copying, but revalidate consent after each yielding tick.
	// Imported nodes must not create refunds for research we never paid for.
	var/list/previous_skips = skipped_experiment_types.Copy()
	for(var/node_id in hidden_nodes.Copy())
		CHECK_TICK
		if(QDELETED(source) || (pair && (QDELETED(pair) || pair.unavailable_reason())))
			return
		if(source.get_available_nodes()[node_id] || source.get_researched_nodes()[node_id] || source.get_visible_nodes()[node_id])
			hidden_nodes -= node_id
	for(var/node_id in source.researched_nodes.Copy())
		CHECK_TICK
		if(QDELETED(source) || (pair && (QDELETED(pair) || pair.unavailable_reason())))
			return
		previous_skips = skipped_experiment_types.Copy()
		if(!researched_nodes[node_id])
			research_node_id(node_id, TRUE, FALSE, FALSE)
			// Only remove refunds introduced by this imported node. Local work may
			// have completed while CHECK_TICK yielded, so don't restore an old snapshot.
			for(var/experiment_type in skipped_experiment_types.Copy())
				if(!(experiment_type in previous_skips) && !completed_experiments[experiment_type])
					skipped_experiment_types -= experiment_type
		previous_skips = skipped_experiment_types.Copy()
	for(var/design_id in source.researched_designs.Copy())
		CHECK_TICK
		if(QDELETED(source) || (pair && (QDELETED(pair) || pair.unavailable_reason())))
			return
		if(!researched_designs[design_id])
			add_design_by_id(design_id)
	recalculate_nodes()
	for(var/experiment_type in source.completed_experiments)
		if(completed_experiments[experiment_type])
			continue
		var/datum/experiment/original = source.completed_experiments[experiment_type]
		if(!original.completed)
			continue
		var/datum/experiment/completion_record/record = new
		record.original_type = experiment_type
		record.name = original.name
		record.description = original.description
		record.exp_tag = original.exp_tag
		record.performance_hint = original.performance_hint
		record.evidence_json = json_encode(original.check_progress())
		completed_experiments[experiment_type] = record
		// A synchronized result fulfills this requirement, without refunding the
		// receiving site's earlier spend or paying it a second completion reward.
		skipped_experiment_types[experiment_type] = -1
		for(var/datum/experiment/pending as anything in available_experiments.Copy())
			if(pending.type != experiment_type)
				continue
			for(var/datum/component/experiment_handler/handler as anything in GLOB.experiment_handlers)
				if(handler.selected_experiment == pending)
					pending.on_unselected(handler)
					handler.selected_experiment = null
			available_experiments -= pending
			qdel(pending)
	// Publication identity is experiment type and tier. Clone published evidence
	// without calling publish_paper(), which pays points/credits.
	for(var/experiment_type in source.published_papers)
		var/list/source_tiers = source.published_papers[experiment_type]
		var/list/our_tiers = published_papers[experiment_type]
		if(!our_tiers)
			our_tiers = new /list(length(source_tiers))
			published_papers[experiment_type] = our_tiers
		our_tiers.len = max(length(our_tiers), length(source_tiers))
		for(var/index in 1 to length(source_tiers))
			var/datum/scientific_paper/paper = source_tiers[index]
			if(paper && !our_tiers[index])
				our_tiers[index] = paper.clone_into(paper.type)
	if(source.survey_data)
		if(!survey_data)
			survey_data = new
		survey_data.merge_completed_surveys(source.survey_data)

/datum/survey_research/proc/merge_completed_surveys(datum/survey_research/source)
	if(!source || source == src)
		return
	for(var/category in source.survey_objects_by_type)
		var/list/destination = survey_objects_by_type[category]
		if(!destination)
			continue
		for(var/datum/surveyed_celestial_object/record as anything in source.survey_objects_by_type[category])
			if(!record.ref_id)
				continue
			var/datum/surveyed_celestial_object/existing
			for(var/datum/surveyed_celestial_object/candidate as anything in destination)
				if(candidate.ref_id == record.ref_id)
					existing = candidate
					break
			if(!existing)
				existing = new record.type
				record.copy(existing)
				destination += existing
			else if(record.recorded_at > existing.recorded_at)
				record.copy(existing)

/obj/structure/overmap/dynamic/player_outpost
	var/list/datum/outpost_research_pair/research_pairs = list()
	var/home_service_timer

/obj/structure/overmap/dynamic/player_outpost/proc/process_home_services()
	freight?.check_stalled()
	for(var/datum/outpost_research_pair/pair as anything in research_pairs)
		pair.synchronize()

/obj/structure/overmap/dynamic/player_outpost/proc/propose_research_pair(mob/user, obj/machinery/rnd/server/ship/local_server, obj/machinery/rnd/server/ship/remote_server, obj/item/computer_disk/ship_disk/expected_home_disk, obj/item/computer_disk/ship_disk/expected_ship_disk)
	var/obj/structure/overmap/ship/ship = astype(get_service_site(remote_server))
	if(!can_manage(user) || get_outpost_from_atom(local_server) != src || !ship || ship.docked != src)
		return FALSE
	if(!local_server.source_code_hdd || !remote_server.source_code_hdd)
		return FALSE
	if(local_server.source_code_hdd != expected_home_disk || remote_server.source_code_hdd != expected_ship_disk)
		return FALSE
	for(var/datum/outpost_research_pair/existing as anything in research_pairs)
		if(existing.home_server?.resolve() == local_server && existing.ship_server?.resolve() == remote_server)
			return FALSE
	var/datum/outpost_research_pair/pair = new(src, local_server, remote_server, ship)
	research_pairs += pair
	ship.ship_notify("[name] requests a research pairing. The captain can approve with a secondary multitool click on [remote_server]. Only these installed disks will be trusted.", "RESEARCH")
	return TRUE

/datum/outpost_research_pair
	var/datum/weakref/home_ref
	var/datum/weakref/ship_ref
	var/datum/weakref/home_server
	var/datum/weakref/ship_server
	var/datum/weakref/home_disk
	var/datum/weakref/ship_disk
	var/ship_approved = FALSE
	var/last_success
	var/status = "Awaiting ship captain's approval at the ship server"
	var/syncing = FALSE
	var/label

/datum/outpost_research_pair/New(obj/structure/overmap/dynamic/player_outpost/home, obj/machinery/rnd/server/ship/local_server, obj/machinery/rnd/server/ship/remote_server, obj/structure/overmap/ship/ship)
	home_ref = WEAKREF(home)
	ship_ref = WEAKREF(ship)
	home_server = WEAKREF(local_server)
	ship_server = WEAKREF(remote_server)
	home_disk = WEAKREF(local_server.source_code_hdd)
	ship_disk = WEAKREF(remote_server.source_code_hdd)
	label = "[ship.name]: [remote_server.source_code_hdd.name] ([REF(remote_server.source_code_hdd)]) / [local_server.source_code_hdd.name] ([REF(local_server.source_code_hdd)])"

/datum/outpost_research_pair/proc/unavailable_reason()
	if(!ship_approved)
		return "Awaiting ship captain's approval at the ship server"
	var/obj/structure/overmap/dynamic/player_outpost/home = home_ref?.resolve()
	var/obj/structure/overmap/ship/ship = ship_ref?.resolve()
	if(!home || !ship)
		return "A paired site no longer exists"
	if(ship.docked != home || ship.state != OVERMAP_SHIP_IDLE)
		return "Ship is not docked; retained copies are independent"
	var/obj/machinery/rnd/server/ship/local_server = home_server?.resolve()
	var/obj/machinery/rnd/server/ship/remote_server = ship_server?.resolve()
	if(!local_server || !remote_server)
		return "A paired server is missing; install and pair a new server explicitly"
	if(get_outpost_from_atom(local_server) != home || get_service_site(remote_server) != ship)
		return "A paired server has moved to another site"
	if(!home_disk?.resolve() || !ship_disk?.resolve() || local_server.source_code_hdd != home_disk.resolve() || remote_server.source_code_hdd != ship_disk.resolve())
		return "A trusted disk is missing or replaced; pair the new disk explicitly"
	if(local_server.source_code_hdd.loc != local_server || remote_server.source_code_hdd.loc != remote_server)
		return "A trusted disk is no longer installed"
	if(!local_server.is_operational || !remote_server.is_operational)
		return "A paired server is unpowered or broken"
	return null

/datum/outpost_research_pair/proc/synchronize()
	if(syncing)
		return
	status = unavailable_reason()
	if(status)
		return
	syncing = TRUE
	var/obj/machinery/rnd/server/ship/local_server = home_server.resolve()
	var/obj/machinery/rnd/server/ship/remote_server = ship_server.resolve()
	try
		local_server.stored_research.merge_completed_records(remote_server.stored_research, src)
		if(!unavailable_reason())
			remote_server.stored_research.merge_completed_records(local_server.stored_research, src)
	catch(var/exception/sync_error)
		status = "Synchronization interrupted; retrying with retained records"
		stack_trace("Outpost research synchronization interrupted: [sync_error]")
		syncing = FALSE
		return
	status = unavailable_reason()
	if(!status)
		last_success = station_time_timestamp()
		status = "Synchronized completed technologies, designs, experiments, papers and surveys"
	syncing = FALSE

/// Requesting is a physical local-server operation. The ship captain's approval
/// remains a separate secondary multitool action at the docked ship server.
/obj/structure/overmap/dynamic/player_outpost/proc/prompt_research_pair_from_server(mob/living/user, obj/machinery/rnd/server/ship/local_server)
	if(QDELETED(src) || QDELETED(user) || QDELETED(local_server) || !user.can_perform_action(local_server) || !can_manage(user) || get_outpost_from_atom(local_server) != src || !local_server.source_code_hdd || local_server.source_code_hdd.loc != local_server)
		return
	var/obj/item/computer_disk/ship_disk/expected_local_disk = local_server.source_code_hdd
	var/list/existing_pairs = list()
	for(var/datum/outpost_research_pair/pair as anything in research_pairs)
		if(pair.home_server?.resolve() == local_server)
			existing_pairs["[length(existing_pairs) + 1]. Revoke [pair.label]"] = pair
	var/list/choices = list("Request a new pairing")
	for(var/pair_choice in existing_pairs)
		choices += pair_choice
	var/selected_action = tgui_input_list(user, "Request a docked ship pairing, or revoke an existing local request.", "Research Pairing", choices)
	if(!selected_action)
		return
	if(QDELETED(src) || QDELETED(user) || QDELETED(local_server) || !user.can_perform_action(local_server) || !can_manage(user) || get_outpost_from_atom(local_server) != src || local_server.source_code_hdd != expected_local_disk || local_server.source_code_hdd?.loc != local_server)
		return
	var/datum/outpost_research_pair/selected_pair = existing_pairs[selected_action]
	if(selected_pair)
		if(!QDELETED(src) && !QDELETED(user) && !QDELETED(local_server) && !QDELETED(selected_pair) && (selected_pair in research_pairs) && user.can_perform_action(local_server) && can_manage(user) && get_outpost_from_atom(local_server) == src && local_server.source_code_hdd == expected_local_disk && local_server.source_code_hdd?.loc == local_server)
			research_pairs -= selected_pair
			qdel(selected_pair)
		return
	var/list/remote_servers = research_pair_server_options(remote = TRUE)
	if(!length(remote_servers))
		balloon_alert(user, "no docked ship server with a disk")
		return
	var/list/expected_disks = list()
	for(var/choice in remote_servers)
		var/obj/machinery/rnd/server/ship/server = remote_servers[choice]
		expected_disks[server] = server.source_code_hdd
	var/obj/machinery/rnd/server/ship/remote_server = remote_servers[tgui_input_list(user, "Select the docked ship's physical server disk. Its captain must approve at that server.", "Research Pairing", remote_servers)]
	if(QDELETED(src) || QDELETED(user) || QDELETED(local_server) || QDELETED(remote_server) || !user.can_perform_action(local_server) || !can_manage(user) || get_outpost_from_atom(local_server) != src || !local_server.source_code_hdd || local_server.source_code_hdd != expected_local_disk || local_server.source_code_hdd.loc != local_server)
		return
	if(!propose_research_pair(user, local_server, remote_server, local_server.source_code_hdd, expected_disks[remote_server]))
		balloon_alert(user, "pairing refused: recheck docking and installed disks")

/obj/machinery/rnd/server/ship/multitool_act_secondary(mob/living/user, obj/item/multitool/tool)
	var/obj/structure/overmap/dynamic/player_outpost/local_home = get_outpost_from_atom(src)
	if(local_home)
		if(!local_home.can_manage(user) || !user.can_perform_action(src))
			balloon_alert(user, "outpost management permission required")
			return ITEM_INTERACT_BLOCKING
		INVOKE_ASYNC(local_home, PROC_REF(prompt_research_pair_from_server), user, src)
		return ITEM_INTERACT_SUCCESS
	var/obj/structure/overmap/ship/ship = astype(get_service_site(src))
	if(!ship?.is_ship_captain(user) || !user.can_perform_action(src))
		balloon_alert(user, "ship captain approval required")
		return ITEM_INTERACT_BLOCKING
	var/list/options = list()
	for(var/obj/structure/overmap/dynamic/player_outpost/home as anything in GLOB.player_outposts)
		for(var/datum/outpost_research_pair/pair as anything in home.research_pairs)
			if(pair.ship_server?.resolve() == src)
				options["[length(options) + 1]. [pair.ship_approved ? "Revoke" : "Approve"] [home.name]: [pair.label]"] = pair
	var/datum/outpost_research_pair/selected = options[tgui_input_list(user, "Approve exchange of completed records, or revoke an existing pairing. Points and active work stay local.", "Research Pairing", options)]
	if(QDELETED(selected) || QDELETED(src) || QDELETED(user) || !user.can_perform_action(src) || QDELETED(ship) || get_service_site(src) != ship || !ship.is_ship_captain(user))
		return ITEM_INTERACT_BLOCKING
	var/obj/structure/overmap/dynamic/player_outpost/home = selected.home_ref.resolve()
	if(!home || !(selected in home.research_pairs) || selected.ship_server?.resolve() != src)
		return ITEM_INTERACT_BLOCKING
	if(selected.ship_approved)
		home.research_pairs -= selected
		qdel(selected)
	else if(ship.docked == home && source_code_hdd && source_code_hdd.loc == src && source_code_hdd == selected.ship_disk.resolve())
		selected.ship_approved = TRUE
		selected.synchronize()
	return ITEM_INTERACT_SUCCESS

/obj/machinery/rnd/server/ship/examine(mob/user)
	. = ..()
	var/obj/structure/overmap/dynamic/player_outpost/home = get_outpost_from_atom(src)
	if(home)
		. += span_notice("An outpost owner or management delegate can request a pairing with a secondary multitool click. The docked ship captain approves at the ship server.")
	else
		. += span_notice("To authorize or revoke an outpost's pairing request, the ship captain uses a secondary multitool click on this server. Pairing trusts only the installed disk.")
	for(var/obj/structure/overmap/dynamic/player_outpost/pair_home as anything in GLOB.player_outposts)
		for(var/datum/outpost_research_pair/pair as anything in pair_home.research_pairs)
			if(pair.home_server?.resolve() != src && pair.ship_server?.resolve() != src)
				continue
			. += span_notice("[pair.label]: [pair.unavailable_reason() || pair.status]. Last exchange: [pair.last_success || "never"].")

/// Physical links stay local even when another ship shares the same z level.
/datum/component/remote_materials/check_z_level(obj/silo_to_check = silo)
	return silo_to_check && same_service_site(parent, silo_to_check)

/proc/can_link_site_techweb(atom/machine, datum/techweb/web)
	if(!web)
		return FALSE
	if(!get_service_site(machine) && !length(web.techweb_servers))
		return TRUE
	for(var/obj/machinery/rnd/server/server as anything in web.techweb_servers)
		if(same_service_site(machine, server))
			return TRUE
	return FALSE

/obj/machinery/rnd/connect_techweb(datum/techweb/new_techweb)
	if(new_techweb && !can_link_site_techweb(src, new_techweb))
		return FALSE
	return ..()

/obj/machinery/mecha_part_fabricator/connect_techweb(datum/techweb/new_techweb)
	if(new_techweb && !can_link_site_techweb(src, new_techweb))
		return FALSE
	return ..()

/obj/machinery/component_printer/connect_techweb(datum/techweb/new_techweb)
	if(new_techweb && !can_link_site_techweb(src, new_techweb))
		return FALSE
	return ..()
