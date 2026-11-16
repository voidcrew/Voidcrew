// Tutorial checklist hooks: the Repair drones item (voidcrew/modules/shuttle/construction).
// Overrides chain with any others of the same proc.

/datum/techweb/research_node(datum/techweb_node/node, force = FALSE, auto_adjust_cost = TRUE, get_that_dosh = TRUE, atom/research_source)
	. = ..()
	if(!. || !istype(node) || node.id != TECHWEB_NODE_SHIP_REPAIR_SWARM)
		return
	var/obj/structure/overmap/ship/ship = metric_techweb_ship(src)
	if(ship)
		tutorial_credit_crew(ship, TUTORIAL_STEP_REPAIR_DRONES_RESEARCH)

/// The final step spawns the drone and deletes the chassis this component sits on.
/datum/component/construction/ship_repair_drone/check_step(obj/item/item, mob/living/user)
	var/atom/chassis = parent
	. = ..()
	if(. && QDELETED(chassis) && ismob(user))
		tutorial_credit(user, TUTORIAL_STEP_REPAIR_DRONES_ASSEMBLE)

/obj/structure/ship_repair_drone/multitool_act(mob/living/user, obj/item/multitool/tool)
	var/was_linked = !!console
	. = ..()
	if(!was_linked && console && ismob(user))
		tutorial_credit(user, TUTORIAL_STEP_REPAIR_DRONES_LINK)

/// Drones call this when a repair finishes. Credits the crew aboard the console's ship.
/obj/machinery/computer/camera_advanced/base_construction/ship/perform_record_repair(datum/ship_repair_record/record)
	. = ..()
	if(. && current_ship)
		tutorial_credit_crew(current_ship, TUTORIAL_STEP_REPAIR_DRONES_REPAIR, aboard_only = TRUE)

// ---------------------------------------------------------------------------
// Panel helpers for the Repair drones steps (tutorial_catalog.dm). Cheap: they run in ui_data.
// ---------------------------------------------------------------------------

/// How long the ship's construction console lookup is kept.
#define TUTORIAL_REPAIR_CONSOLE_CACHE (10 SECONDS)

/// Ship REF -> list(world.time, weakref to its construction console or null).
GLOBAL_LIST_EMPTY(tutorial_repair_console_cache)

/**
 * The ship's own construction console: the one running its repairs, else one aboard, preferring
 * one with the repair disk. The aboard scan is cached briefly because it walks every ship area.
 */
/proc/tutorial_repair_console(obj/structure/overmap/ship/ship)
	if(QDELETED(ship))
		return null
	var/obj/machinery/computer/camera_advanced/base_construction/ship/console = ship.shuttle?.ship_repair_controller?.resolve()
	if(!QDELETED(console))
		return console
	var/ship_ref = REF(ship)
	var/list/cached = GLOB.tutorial_repair_console_cache[ship_ref]
	if(cached && world.time < cached[1] + TUTORIAL_REPAIR_CONSOLE_CACHE)
		var/datum/weakref/cached_ref = cached[2]
		console = cached_ref?.resolve()
		if(!QDELETED(console))
			return console
	console = null
	for(var/obj/machinery/computer/camera_advanced/base_construction/ship/candidate as anything in ship.get_ship_machines(/obj/machinery/computer/camera_advanced/base_construction/ship))
		if(istype(candidate, /obj/machinery/computer/camera_advanced/base_construction/ship/bay))
			continue
		if(!console || (candidate.console_upgrades & SHIP_CONSTRUCTION_UPGRADE_REPAIR))
			console = candidate
	GLOB.tutorial_repair_console_cache[ship_ref] = list(world.time, console ? WEAKREF(console) : null)
	return console

/// Whether this is a construction console of the viewer's own ship, not an outpost bay's.
/proc/tutorial_repair_is_crew_console(mob/user, atom/candidate)
	var/obj/machinery/computer/camera_advanced/base_construction/ship/console = candidate
	if(!istype(console) || istype(console, /obj/machinery/computer/camera_advanced/base_construction/ship/bay))
		return FALSE
	var/obj/structure/overmap/ship/ship = get_crew_ship(user)
	return ship && get_ship_from_atom(console) == ship

/**
 * What stands between this web and the node: the next node to research on the way, missing
 * reputation, or points. Null once researched or with no web.
 */
/proc/tutorial_repair_research_line(datum/techweb/web, node_id)
	if(!web || web.researched_nodes[node_id])
		return null
	var/datum/techweb_node/next = tutorial_repair_next_node(web, node_id, list())
	if(!next)
		return null
	if(next.id != node_id)
		return "Research [next.display_name] first."
	if(!web.have_zone_permission_for_node(next))
		return "Needs more crew reputation."
	if(!web.can_afford(next.get_price(web)))
		return "Short on research points."
	return null

/// The first unresearched node on the way to node_id whose prerequisites are all researched.
/proc/tutorial_repair_next_node(datum/techweb/web, node_id, list/visited)
	if(visited[node_id] || web.researched_nodes[node_id])
		return null
	visited[node_id] = TRUE
	var/datum/techweb_node/node = SSresearch.techweb_node_by_id(node_id)
	if(!node)
		return null
	for(var/prereq_id in node.prereq_ids)
		var/datum/techweb_node/blocker = tutorial_repair_next_node(web, prereq_id, visited)
		if(blocker)
			return blocker
	return node

/// The next assembly step of the nearest unfinished drone chassis beside the viewer.
/proc/tutorial_repair_chassis_line(mob/user)
	var/turf/center = get_turf(user)
	if(!center)
		return null
	for(var/obj/item/ship_repair_drone_part/chassis/chassis in range(2, center))
		var/datum/component/construction/ship_repair_drone/assembly = chassis.GetComponent(/datum/component/construction/ship_repair_drone)
		if(!assembly || assembly.index > length(assembly.steps))
			continue
		var/list/next_step = assembly.steps[assembly.index]
		var/step_desc = next_step["desc"]
		if(step_desc)
			return STRIP_HTML_FULL(step_desc, 160)
	return null

/// The swarm's state as its console shows it.
/proc/tutorial_repair_swarm_line(obj/machinery/computer/camera_advanced/base_construction/ship/console)
	if(QDELETED(console))
		return null
	if(!(console.console_upgrades & SHIP_CONSTRUCTION_UPGRADE_REPAIR))
		return "No repair disk in the construction console."
	if(!length(console.repair_drones))
		return "No drones linked."
	if(!console.repair_enabled)
		return "Swarm paused."
	if(!console.repair_tracking)
		return "Damage monitoring is off."
	var/waiting = length(console.repair_records)
	if(!waiting)
		return "Swarm out. No hull damage logged."
	return "[waiting] damaged spot\s waiting for repair."

#undef TUTORIAL_REPAIR_CONSOLE_CACHE
