/obj/machinery/computer/rdconsole
	///The mobile ship we are connected to.
	var/datum/weakref/connected_ship_ref

/obj/machinery/computer/rdconsole/Destroy()
	if(connected_ship_ref)
		connected_ship_ref = null
	unsync_research_servers()
	return ..()

/obj/machinery/computer/rdconsole/unsync_research_servers()
	if(stored_research)
		// Must be -= : `[src] = FALSE` keeps the console as an assoc KEY, i.e. a
		// permanent hard ref. Upstream's Destroy would have removed it, but this runs
		// first (dme chaining) and nulls stored_research, so upstream's cleanup skips.
		stored_research.consoles_accessing -= src
		stored_research.connected_machines -= src
		stored_research = null

/obj/machinery/computer/rdconsole/connect_to_shuttle(mapload, obj/docking_port/mobile/port, obj/docking_port/stationary/dock)
	. = ..()
	if(!port)
		return FALSE
	connected_ship_ref = WEAKREF(port)

/obj/machinery/computer/rdconsole/multitool_act(mob/living/user, obj/item/multitool/tool)
	if(stored_research && !QDELETED(tool.buffer) && istype(tool.buffer, /datum/techweb)) //disconnect old one
		stored_research.connected_machines -= src
		stored_research.consoles_accessing -= src
	. = ..()
	if(.)
		stored_research.connected_machines += src //connect new one
		stored_research.consoles_accessing += src
		say("Linked to Server!")
		return TRUE

/obj/machinery/computer/rdconsole/attackby(obj/item/attacking_item, mob/user, params)
	if(istype(attacking_item, /obj/item/research_notes) && stored_research)
		var/obj/item/research_notes/research_notes = attacking_item
		stored_research.add_point_list(list(TECHWEB_POINT_TYPE_GENERIC = research_notes.value))
		playsound(src,'sound/machines/synth/synth_yes.ogg', 50, TRUE)
		qdel(research_notes)
		return
	return ..()

/obj/machinery/computer/rdconsole/ui_act(action, list/params)
	if (action == "loadTech")
		var/mob/living/user = usr
		var/obj/docking_port/mobile/voidcrew/port = connected_ship_ref?.resolve()
		if(port)
			if(!(user.mind in port.current_ship.ship_team.members))
				say("ERROR- DOWNLOADING NOT ALLOWED FOR NON-CREW!")
				return
	return ..()

/obj/machinery/computer/rdconsole/ui_data(mob/user)
	var/list/data = list()
	data["stored_research"] = !!stored_research
	data["locked"] = locked
	if(!stored_research) //lack of a research node is all we care about.
		return data
	data += list(
		"nodes" = list(),
		"experiments" = list(),
		"researched_designs" = stored_research.researched_designs,
		"points" = stored_research.research_points,
		"points_last_tick" = stored_research.last_bitcoins,
		"web_org" = stored_research.organization,
		"sec_protocols" = !(obj_flags & EMAGGED),
		"t_disk" = null,
		"d_disk" = null,
	)
	data += list(
		"surveyed_objects" = list(
			"nebulas" = stored_research.survey_data ? length(stored_research.survey_data.survey_objects_by_type["nebulas"]) : 0,
			"asteroids" = stored_research.survey_data ? length(stored_research.survey_data.survey_objects_by_type["asteroids"]): 0,
			"electric_storms" = stored_research.survey_data ? length(stored_research.survey_data.survey_objects_by_type["electric_storms"]): 0,
			"emp_storms" = stored_research.survey_data ? length(stored_research.survey_data.survey_objects_by_type["emp_storms"]): 0,
			"planets" = stored_research.survey_data ? length(stored_research.survey_data.survey_objects_by_type["planets"]): 0,
			"stars" = stored_research.survey_data ? length(stored_research.survey_data.survey_objects_by_type["stars"]): 0,
		)
	)

	if (t_disk)
		data["t_disk"] = list (
			"stored_research" = t_disk.stored_research.researched_nodes,
		)
	if (d_disk)
		data["d_disk"] = list("blueprints" = list())
		for (var/datum/design/D in d_disk.blueprints)
			data["d_disk"]["blueprints"] += D.id


	// Serialize all nodes to display
	for(var/v in stored_research.tiers)
		var/datum/techweb_node/n = SSresearch.techweb_node_by_id(v)

		// Ensure node is supposed to be visible
		if (stored_research.hidden_nodes[v])
			continue

		data["nodes"] += list(list(
			"id" = n.id,
			"can_unlock" = stored_research.can_unlock_node(n),
			"tier" = stored_research.tiers[n.id],
		))

	// Get experiments and serialize them
	var/list/exp_to_process = stored_research.available_experiments.Copy()
	for (var/e in stored_research.completed_experiments)
		exp_to_process += stored_research.completed_experiments[e]
	for (var/e in exp_to_process)
		var/datum/experiment/ex = e
		data["experiments"][ex.type] = list(
			"name" = ex.name,
			"description" = ex.description,
			"tag" = ex.exp_tag,
			"progress" = ex.check_progress(),
			"completed" = ex.completed,
			"performance_hint" = ex.performance_hint,
		)
	return data

/obj/machinery/computer/rdconsole/ui_static_data(mob/user)
	. = list(
		"static_data" = list(),
		"point_types_abbreviations" = SSresearch.point_types,
	)

	// Build node cache...
	// Note this looks a bit ugly but its to reduce the size of the JSON payload
	// by the greatest amount that we can, as larger JSON payloads result in
	// hanging when the user opens the UI
	var/node_cache = list()
	for (var/node_id in SSresearch.techweb_nodes)
		var/datum/techweb_node/node = SSresearch.techweb_nodes[node_id] || SSresearch.error_node
		var/compressed_id = "[compress_id(node.id)]"
		node_cache[compressed_id] = list(
			"name" = node.display_name,
			"description" = node.description
		)
		if (LAZYLEN(node.research_costs))
			node_cache[compressed_id]["costs"] = list()
			for (var/node_cost in node.research_costs)
				node_cache[compressed_id]["costs"]["[compress_id(node_cost)]"] = node.research_costs[node_cost]
		if (LAZYLEN(node.prereq_ids))
			node_cache[compressed_id]["prereq_ids"] = list()
			for (var/prerequisite_node in node.prereq_ids)
				node_cache[compressed_id]["prereq_ids"] += compress_id(prerequisite_node)
		if (LAZYLEN(node.design_ids))
			node_cache[compressed_id]["design_ids"] = list()
			for (var/unlocked_design in node.design_ids)
				node_cache[compressed_id]["design_ids"] += compress_id(unlocked_design)
		if (LAZYLEN(node.unlock_ids))
			node_cache[compressed_id]["unlock_ids"] = list()
			for (var/unlocked_node in node.unlock_ids)
				node_cache[compressed_id]["unlock_ids"] += compress_id(unlocked_node)
		if (LAZYLEN(node.required_experiments))
			node_cache[compressed_id]["required_experiments"] = node.required_experiments
		if (LAZYLEN(node.discount_experiments))
			node_cache[compressed_id]["discount_experiments"] = node.discount_experiments
		// Create our list of required surveys
		if(LAZYLEN(node.required_surveyed_objects))
			node_cache[compressed_id]["required_surveyed_objects"] = list()
			for(var/required_object_type in node.required_surveyed_objects)
				var/list/object = list()
				object[required_object_type] = node.required_surveyed_objects[required_object_type]
				node_cache[compressed_id]["required_surveyed_objects"] += object
	// Build design cache
	var/design_cache = list()
	var/datum/asset/spritesheet_batched/research_designs/spritesheet = get_asset_datum(/datum/asset/spritesheet_batched/research_designs)
	var/size32x32 = "[spritesheet.name]32x32"
	for (var/design_id in SSresearch.techweb_designs)
		var/datum/design/design = SSresearch.techweb_designs[design_id] || SSresearch.error_design
		var/compressed_id = "[compress_id(design.id)]"
		var/size = spritesheet.icon_size_id(design.id)
		design_cache[compressed_id] = list(
			design.name,
			"[size == size32x32 ? "" : "[size] "][design.id]"
		)

	// Ensure id cache is included for decompression
	var/flat_id_cache = list()
	for (var/id in id_cache)
		flat_id_cache += id

	.["static_data"] = list(
		"node_cache" = node_cache,
		"design_cache" = design_cache,
		"id_cache" = flat_id_cache,
	)
