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

// NOTE: this stays on attackby rather than item_interaction, and only reaches the click because
// upstream's /obj/machinery/computer/rdconsole/item_interaction (code/modules/research/
// rdconsole.dm:74-75) returns NONE for anything that is not an /obj/item/disk, letting
// code/_onclick/item_attack.dm:32-36 fall through to the attackby leg. If upstream ever makes
// that item_interaction claim non-disk items, feeding research notes silently stops working -
// port this to an item_interaction override that returns ..() for non-notes.
// (Third arg is named `params` for history; /atom/proc/attackby now passes list/modifiers, and
// nothing here reads it.)
/obj/machinery/computer/rdconsole/attackby(obj/item/attacking_item, mob/user, params)
	if(istype(attacking_item, /obj/item/research_notes) && stored_research)
		var/obj/item/research_notes/research_notes = attacking_item
		stored_research.adjust_multiple_points(list(TECHWEB_POINT_TYPE_GENERIC = research_notes.value))
		playsound(src,'sound/machines/synth/synth_yes.ogg', 50, TRUE)
		qdel(research_notes)
		return
	return ..()

// Must re-state upstream's full signature (code/modules/research/rdconsole.dm:360 /
// code/modules/tgui/external.dm:99). This override is the outermost one, so declaring fewer
// params than the parent drops `ui` and `state` on the way through ..() for every caller.
/obj/machinery/computer/rdconsole/ui_act(action, list/params, datum/tgui/ui, datum/ui_state/state)
	if (action == "loadTech")
		var/mob/living/user = usr
		var/obj/docking_port/mobile/voidcrew/port = connected_ship_ref?.resolve()
		if(port)
			if(!(user.mind in port.current_ship.ship_team.members))
				say("ERROR- DOWNLOADING NOT ALLOWED FOR NON-CREW!")
				return
	return ..()

/**
 * VOIDCREW EDIT: survey gating. Upstream's R&D payload has no notion of surveyed celestial
 * objects, so this override adds the ship's survey tally and nothing else.
 *
 * This used to be a full copy of upstream's ui_data with the survey block spliced into it, and
 * the copy rotted: it was still reporting the console's own `locked` var after upstream moved
 * the lock onto the circuit board, still serialising nodes by string id, and never grew
 * `queue_nodes`. Keep it a delta on ..() so upstream changes land for free.
 */
/obj/machinery/computer/rdconsole/ui_data(mob/user)
	. = ..()
	if(!stored_research) // upstream returns early with only the "no techweb" keys
		return
	var/datum/survey_research/survey_data = stored_research.survey_data
	.["surveyed_objects"] = list(
		"nebulas" = survey_data ? length(survey_data.survey_objects_by_type["nebulas"]) : 0,
		"asteroids" = survey_data ? length(survey_data.survey_objects_by_type["asteroids"]) : 0,
		"electric_storms" = survey_data ? length(survey_data.survey_objects_by_type["electric_storms"]) : 0,
		"emp_storms" = survey_data ? length(survey_data.survey_objects_by_type["emp_storms"]) : 0,
		"planets" = survey_data ? length(survey_data.survey_objects_by_type["planets"]) : 0,
		"stars" = survey_data ? length(survey_data.survey_objects_by_type["stars"]) : 0,
	)

/**
 * VOIDCREW EDIT: publish each node's survey requirement alongside upstream's node cache, so the
 * UI can tell a crew what still needs charting.
 *
 * Additive on purpose. Upstream builds the whole node/design cache in ..() and has already run
 * compress_id() over every node path by the time we get here, so the calls below are pure cache
 * lookups and the flat id_cache ..() returned stays complete. Do not add ids that ..() has not
 * already seen or they will be missing from the decompression table on the UI side.
 */
/obj/machinery/computer/rdconsole/ui_static_data(mob/user)
	. = ..()
	var/list/static_data = .["static_data"]
	var/list/node_cache = static_data["node_cache"]
	for (var/node_path, _node in SSresearch.techweb_nodes)
		var/datum/techweb_node/node = _node
		if(!LAZYLEN(node.required_surveyed_objects))
			continue
		var/list/node_data = node_cache["[compress_id(node_path)]"]
		if(isnull(node_data))
			continue
		// Create our list of required surveys
		node_data["required_surveyed_objects"] = list()
		for(var/required_object_type in node.required_surveyed_objects)
			var/list/object = list()
			object[required_object_type] = node.required_surveyed_objects[required_object_type]
			node_data["required_surveyed_objects"] += object
