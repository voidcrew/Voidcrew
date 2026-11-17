// Tutorial checklist hooks. Part C: R&D setup (kit, ship server, disk, console, protolathe, multitool
// links) and surveys (research node, survey console, notes).
// Overrides chain with any others of the same proc; each returns the parent's value unchanged.

// ---------------------------------------------------------------------------
// R&D setup
// ---------------------------------------------------------------------------

/// The autolathe builds on a timer with no user, so the kit counts once a player picks it up or opens it.
/obj/item/storage/box/rndboards/all/pickup(mob/user)
	. = ..()
	tutorial_credit(user, TUTORIAL_STEP_RESEARCH_KIT)

/datum/storage/box/rndkit/open_storage(mob/living/to_show)
	. = ..()
	if(.)
		tutorial_credit(to_show, TUTORIAL_STEP_RESEARCH_KIT)

/// on_construction() runs for flatpack deploys and frame builds, never for mapped machines.
/obj/machinery/rnd/server/ship/on_construction(mob/user)
	. = ..()
	tutorial_credit(user, TUTORIAL_STEP_RESEARCH_SERVER)

/obj/machinery/computer/rdconsole/on_construction(mob/user)
	. = ..()
	tutorial_credit(user, TUTORIAL_STEP_RESEARCH_CONSOLE)

/obj/machinery/rnd/production/protolathe/on_construction(mob/user)
	. = ..()
	tutorial_credit(user, TUTORIAL_STEP_RESEARCH_PROTOLATHE)

/// The ship server takes its source disk in attacked_by (voidcrew/modules/research/server.dm).
/obj/machinery/rnd/server/ship/attacked_by(obj/item/attacking_item, mob/living/user, list/modifiers, list/attack_modifiers)
	var/had_disk = !!source_code_hdd
	. = ..()
	if(!had_disk && source_code_hdd && source_code_hdd == attacking_item)
		tutorial_credit(user, TUTORIAL_STEP_RESEARCH_DISK)

/// The ship server's multitool_act stores its disk's techweb in the multitool buffer.
/obj/machinery/rnd/server/ship/multitool_act(mob/living/user, obj/item/multitool/tool)
	. = ..()
	if(. && source_code_hdd?.stored_research && tool.buffer == source_code_hdd.stored_research)
		tutorial_credit(user, TUTORIAL_STEP_RESEARCH_MULTITOOL)

/obj/machinery/computer/rdconsole/multitool_act(mob/living/user, obj/item/multitool/tool)
	. = ..()
	if(. && stored_research && stored_research == tool.buffer && tutorial_ship_rnd_linked(get_ship_from_atom(src), stored_research))
		tutorial_credit(user, TUTORIAL_STEP_RESEARCH_LINK)

/obj/machinery/rnd/production/protolathe/multitool_act(mob/living/user, obj/item/multitool/tool)
	. = ..()
	if(. && stored_research && stored_research == tool.buffer && tutorial_ship_rnd_linked(get_ship_from_atom(src), stored_research))
		tutorial_credit(user, TUTORIAL_STEP_RESEARCH_LINK)

/**
 * TRUE when the ship has an R&D console and a protolathe both on a techweb served by a ship
 * R&D server. With no web given, the ship's own research web is used.
 * Walks the hull's machines, so only call it on a player action or a panel open.
 */
/proc/tutorial_ship_rnd_linked(obj/structure/overmap/ship/ship, datum/techweb/web)
	if(QDELETED(ship))
		return FALSE
	if(!web)
		web = ship.get_research_web()
	if(!web || !(locate(/obj/machinery/rnd/server/ship) in web.techweb_servers))
		return FALSE
	var/console_linked = FALSE
	for(var/obj/machinery/computer/rdconsole/console as anything in ship.get_ship_machines(/obj/machinery/computer/rdconsole))
		if(console.stored_research == web)
			console_linked = TRUE
			break
	if(!console_linked)
		return FALSE
	for(var/obj/machinery/rnd/production/protolathe/lathe as anything in ship.get_ship_machines(/obj/machinery/rnd/production/protolathe))
		if(lathe.stored_research == web)
			return TRUE
	return FALSE

// ---------------------------------------------------------------------------
// Surveys
// ---------------------------------------------------------------------------

/// Research notes are redeemed (and deleted) by the Voidcrew override in research/edits/_rd_consoles.dm.
/// Notes of any origin count, because merged notes change origin.
/obj/machinery/computer/rdconsole/attackby(obj/item/attacking_item, mob/user, list/modifiers, list/attack_modifiers)
	var/is_notes = istype(attacking_item, /obj/item/research_notes)
	. = ..()
	if(is_notes && QDELETED(attacking_item))
		tutorial_credit(user, TUTORIAL_STEP_SURVEYS_NOTES)

/datum/techweb/research_node(datum/techweb_node/node, force = FALSE, auto_adjust_cost = TRUE, get_that_dosh = TRUE, atom/research_source)
	. = ..()
	if(!. || !istype(node) || node.id != TECHWEB_NODE_SURVEY_CONSOLE)
		return
	var/obj/structure/overmap/ship/ship = metric_techweb_ship(src)
	if(ship)
		tutorial_credit_crew(ship, TUTORIAL_STEP_SURVEYS_NODE)

/// Only the crew's own ship console counts. Outpost archive consoles open the same window.
/obj/machinery/computer/camera_advanced/shuttle_docker/survey/ui_interact(mob/user, datum/tgui/ui)
	. = ..()
	var/obj/structure/overmap/ship/ship = bound_ship?.resolve()
	if(attached_to_ship && ship && get_crew_ship(user, ship))
		tutorial_credit(user, TUTORIAL_STEP_SURVEYS_BUILD)

/// When the ship's movement last stopped a running survey, for the Surveys checklist line.
/obj/machinery/computer/camera_advanced/shuttle_docker/survey/var/tutorial_moved_at = 0

/obj/machinery/computer/camera_advanced/shuttle_docker/survey/cancel_survey(datum/source)
	SIGNAL_HANDLER
	var/was_running = survey_in_progress
	. = ..()
	if(was_running && source && !survey_in_progress)
		tutorial_moved_at = world.time

// ---------------------------------------------------------------------------
// In-window focus (TutorialFocus in the tsx). Window ids: "rdconsole", "imprinter", "survey", "autolathe".
// ---------------------------------------------------------------------------

/obj/machinery/computer/rdconsole/ui_data(mob/user)
	. = ..()
	if(islist(.))
		.["tutorial_focus"] = tutorial_ui_focus(user, "rdconsole")

/obj/machinery/rnd/production/circuit_imprinter/ui_data(mob/user)
	. = ..()
	if(islist(.))
		.["tutorial_focus"] = tutorial_ui_focus(user, "imprinter")

/obj/machinery/autolathe/ui_data(mob/user)
	. = ..()
	if(islist(.))
		.["tutorial_focus"] = tutorial_ui_focus(user, "autolathe")

/obj/machinery/computer/camera_advanced/shuttle_docker/survey/ui_data(mob/user)
	. = ..()
	if(islist(.))
		.["tutorial_focus"] = tutorial_ui_focus(user, "survey")

// ---------------------------------------------------------------------------
// Step helpers (tutorial_catalog.dm R&D setup and Surveys)
// ---------------------------------------------------------------------------

/// TRUE when the candidate is a flatpack that deploys into one of these machine types.
/proc/tutorial_flatpack_builds(atom/candidate, list/machine_types)
	var/obj/item/flatpack/pack = candidate
	if(!istype(pack) || !pack.board)
		return FALSE
	for(var/machine_type in machine_types)
		if(ispath(pack.board.build_path, machine_type))
			return TRUE
	return FALSE

/// TRUE when the mob carries an item that works as this tool (TOOL_* define).
/proc/tutorial_has_tool(mob/user, tool_behaviour)
	if(!user)
		return FALSE
	for(var/obj/item/thing in user.get_all_contents())
		if(thing.tool_behaviour == tool_behaviour)
			return TRUE
	return FALSE

/// "No multitool on you." while the mob carries no such tool, else null.
/proc/tutorial_tool_line(mob/user, tool_behaviour)
	if(!user || tutorial_has_tool(user, tool_behaviour))
		return null
	return "No [tool_behaviour] on you."

/// TRUE for a computer frame that is empty or holds this board type.
/proc/tutorial_frame_for(atom/candidate, board_type)
	var/obj/structure/frame/computer/frame = candidate
	if(!istype(frame))
		return FALSE
	return !frame.circuit || istype(frame.circuit, board_type)

/// The step's nearest highlight candidate that is a computer frame for this board, or null.
/// With board_required, empty frames don't count.
/proc/tutorial_nearest_frame(mob/user, datum/vc_tutorial_step/step, board_type, board_required = FALSE)
	var/turf/center = get_turf(user)
	if(!center)
		return null
	var/obj/structure/frame/computer/nearest
	var/nearest_dist = INFINITY
	for(var/obj/structure/frame/computer/frame in tutorial_step_candidates(user, step))
		if(frame.circuit ? !istype(frame.circuit, board_type) : board_required)
			continue
		var/dist = get_dist(center, frame)
		if(dist < nearest_dist)
			nearest = frame
			nearest_dist = dist
	return nearest

/// What a computer frame needs next, and whether the mob lacks the tool for it.
/proc/tutorial_frame_line(mob/user, obj/structure/frame/computer/frame)
	if(QDELETED(frame))
		return null
	var/line
	var/tool
	if(!frame.anchored)
		line = "The frame needs a wrench."
		tool = TOOL_WRENCH
	else
		switch(frame.state)
			if(FRAME_COMPUTER_STATE_EMPTY)
				line = "The frame needs its board."
			if(FRAME_COMPUTER_STATE_BOARD_INSTALLED)
				line = "The board needs a screwdriver."
				tool = TOOL_SCREWDRIVER
			if(FRAME_COMPUTER_STATE_BOARD_SECURED)
				line = "The frame needs 5 cable."
			if(FRAME_COMPUTER_STATE_WIRED)
				line = "The frame needs 2 glass."
			if(FRAME_COMPUTER_STATE_GLASSED)
				line = "The frame needs a screwdriver."
				tool = TOOL_SCREWDRIVER
	if(tool && !tutorial_has_tool(user, tool))
		line += " You have none."
	return line

/// TRUE when an R&D console or lathe runs off this techweb.
/proc/tutorial_rnd_device_linked(atom/candidate, datum/techweb/web)
	if(!web)
		return FALSE
	if(istype(candidate, /obj/machinery/computer/rdconsole))
		var/obj/machinery/computer/rdconsole/console = candidate
		return console.stored_research == web
	if(istype(candidate, /obj/machinery/rnd))
		var/obj/machinery/rnd/machine = candidate
		return machine.stored_research == web
	return FALSE

/// The plain name the R&D setup steps use for a linkable device, or null.
/proc/tutorial_rnd_device_label(atom/machine)
	if(istype(machine, /obj/machinery/computer/rdconsole))
		return "R&D console"
	if(istype(machine, /obj/machinery/rnd/production/protolathe))
		return "protolathe"
	if(istype(machine, /obj/machinery/rnd/production/circuit_imprinter))
		return "circuit imprinter"
	return null

/// "Research points: 12 of 40." for a node not yet researched, or null.
/proc/tutorial_node_points_line(datum/techweb/web, node_id)
	if(!web || web.researched_nodes[node_id])
		return null
	var/datum/techweb_node/node = SSresearch.techweb_node_by_id(node_id)
	if(!node)
		return null
	var/list/price = node.get_price(web)
	var/cost = price?[TECHWEB_POINT_TYPE_GENERIC]
	if(!cost)
		return null
	var/have = round(web.research_points[TECHWEB_POINT_TYPE_GENERIC] || 0)
	return "Research points: [have] of [cost]."
