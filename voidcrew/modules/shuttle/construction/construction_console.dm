/**
 * Ship Construction Console
 *
 * A console for managing ship construction and modifications.
 * Currently supports docking port relocation - additional features planned.
 */

/obj/machinery/computer/ship_construction
	name = "ship construction console"
	desc = "A console for managing ship construction and modifications. Currently supports docking port relocation."
	icon = 'voidcrew/modules/shuttle/icons/computer.dmi'
	icon_screen = "navigation"
	icon_keyboard = "tech_key"
	circuit = /obj/item/circuitboard/computer/ship_construction
	light_color = LIGHT_COLOR_CYAN

	/// The ship we are connected to
	var/obj/structure/overmap/ship/current_ship
	/// Status message for last operation
	var/last_operation_message = ""
	/// Whether the last operation succeeded
	var/last_operation_success = TRUE

/obj/machinery/computer/ship_construction/LateInitialize()
	. = ..()
	attempt_ship_connection()

/obj/machinery/computer/ship_construction/connect_to_shuttle(mapload, obj/docking_port/mobile/voidcrew/port, obj/docking_port/stationary/dock)
	if(!istype(port))
		return
	current_ship = port.current_ship

/**
 * Attempts to connect this console to its containing ship
 */
/obj/machinery/computer/ship_construction/proc/attempt_ship_connection()
	if(current_ship)
		return TRUE

	var/obj/docking_port/mobile/voidcrew/port = SSshuttle.get_containing_shuttle(src)
	if(!istype(port))
		return FALSE

	current_ship = port.current_ship
	return !!current_ship

/**
 * Checks if the given user is a member of this ship's crew
 */
/obj/machinery/computer/ship_construction/proc/is_crew_member(mob/user)
	if(!ismob(user))
		return FALSE
	// Allow admin ghosts with AI interaction enabled
	if(isAdminGhostAI(user))
		return TRUE
	var/mob/living/living_user = user
	if(!istype(living_user) || !living_user.mind)
		return FALSE
	if(!current_ship || !current_ship.ship_team)
		return TRUE // No ship team set up, allow access
	return (living_user.mind in current_ship.ship_team.members)

/**
 * Checks if the console can perform operations (ship must be docked)
 */
/obj/machinery/computer/ship_construction/proc/can_operate()
	if(!current_ship)
		return FALSE
	return current_ship.state == OVERMAP_SHIP_IDLE

/**
 * Gets the docking port for the current ship
 */
/obj/machinery/computer/ship_construction/proc/get_docking_port()
	if(!current_ship)
		return null
	return current_ship.shuttle

/**
 * Checks if an airlock is on the edge of the shuttle (has adjacent non-shuttle turf)
 */
/obj/machinery/computer/ship_construction/proc/is_edge_airlock(obj/machinery/door/airlock/airlock, obj/docking_port/mobile/port)
	var/turf/airlock_turf = get_turf(airlock)
	if(!airlock_turf)
		return FALSE

	// Check cardinal directions for non-shuttle areas
	for(var/check_dir in GLOB.cardinals)
		var/turf/adjacent = get_step(airlock_turf, check_dir)
		if(!adjacent)
			continue
		var/area/adj_area = get_area(adjacent)
		if(!(adj_area in port.shuttle_areas))
			return TRUE // This airlock is on the edge

	return FALSE

/**
 * Gets a list of all valid edge airlocks on this ship
 */
/obj/machinery/computer/ship_construction/proc/get_valid_airlocks()
	var/list/valid_airlocks = list()

	var/obj/docking_port/mobile/port = get_docking_port()
	if(!port)
		return valid_airlocks

	// Iterate through shuttle areas to find airlocks
	for(var/area/shuttle_area as anything in port.shuttle_areas)
		for(var/obj/machinery/door/airlock/airlock in shuttle_area)
			// Check if airlock is on the edge (has adjacent non-shuttle turf)
			if(is_edge_airlock(airlock, port))
				valid_airlocks += airlock

	return valid_airlocks

/**
 * Gets information about the current docking port location
 */
/obj/machinery/computer/ship_construction/proc/get_current_docking_port_info()
	var/obj/docking_port/mobile/port = get_docking_port()
	if(!port)
		return null

	var/turf/port_turf = get_turf(port)

	return list(
		"x" = port_turf ? port_turf.x : 0,
		"y" = port_turf ? port_turf.y : 0,
		"dir" = dir2text(port.dir),
		"port_direction" = dir2text(port.port_direction)
	)

/**
 * Relocates the docking port to a new airlock
 */
/obj/machinery/computer/ship_construction/proc/relocate_docking_port(obj/machinery/door/airlock/new_airlock)
	if(!can_operate())
		last_operation_message = "Cannot modify ship while in flight."
		last_operation_success = FALSE
		return FALSE

	var/obj/docking_port/mobile/port = get_docking_port()
	if(!port)
		last_operation_message = "No ship connection."
		last_operation_success = FALSE
		return FALSE

	// Validate the airlock is in our shuttle
	var/area/airlock_area = get_area(new_airlock)
	if(!(airlock_area in port.shuttle_areas))
		last_operation_message = "Airlock is not part of this ship."
		last_operation_success = FALSE
		return FALSE

	// Validate it's an edge airlock
	if(!is_edge_airlock(new_airlock, port))
		last_operation_message = "Airlock must be on the edge of the ship."
		last_operation_success = FALSE
		return FALSE

	// Calculate new direction based on adjacent tiles
	var/turf/airlock_turf = get_turf(new_airlock)
	var/outside_dir

	for(var/check_dir in GLOB.cardinals)
		var/turf/adjacent = get_step(airlock_turf, check_dir)
		var/area/adj_area = get_area(adjacent)
		if(!(adj_area in port.shuttle_areas))
			outside_dir = check_dir
			break

	if(!outside_dir)
		last_operation_message = "Could not determine docking direction."
		last_operation_success = FALSE
		return FALSE

	// Calculate new dir (points INTO the ship, away from docking entrance)
	var/new_dir = REVERSE_DIR(outside_dir)

	// Calculate new port_direction (ship-relative direction)
	var/world_port_facing = REVERSE_DIR(new_dir)
	var/angle_diff = SIMPLIFY_DEGREES(dir2angle(world_port_facing) - dir2angle(port.preferred_direction))
	var/new_port_direction = angle2dir(angle_diff)

	// Move the port and update variables
	port.forceMove(airlock_turf)
	port.dir = new_dir
	port.port_direction = new_port_direction

	// Recalculate dimensions
	port.calculate_docking_port_information()

	last_operation_message = "Docking port relocated successfully. Changes will take effect on next dock."
	last_operation_success = TRUE
	return TRUE

// ============================================
// TGUI Integration
// ============================================

/obj/machinery/computer/ship_construction/ui_interact(mob/user, datum/tgui/ui)
	. = ..()
	if(!current_ship && !attempt_ship_connection())
		return FALSE

	ui = SStgui.try_update_ui(user, src, ui)
	if(!ui)
		ui = new(user, src, "ShipConstructionConsole", name)
		ui.open()
		ui.set_autoupdate(TRUE)

/obj/machinery/computer/ship_construction/ui_data(mob/user)
	var/list/data = list()

	data["canOperate"] = can_operate()
	data["shipState"] = current_ship ? current_ship.state : null
	data["isNotCrew"] = !is_crew_member(user)
	data["lastMessage"] = last_operation_message
	data["lastSuccess"] = last_operation_success

	// Current docking port info
	data["currentPort"] = get_current_docking_port_info()

	// Get the current port turf for comparison
	var/turf/current_port_turf = get_turf(get_docking_port())

	// Available airlocks
	var/list/airlock_data = list()
	for(var/obj/machinery/door/airlock/airlock in get_valid_airlocks())
		var/turf/T = get_turf(airlock)
		var/is_current = (T == current_port_turf)
		var/area/airlock_area = get_area(airlock)
		airlock_data += list(list(
			"name" = airlock.name,
			"ref" = REF(airlock),
			"x" = T ? T.x : 0,
			"y" = T ? T.y : 0,
			"isCurrent" = is_current,
			"areaName" = airlock_area ? airlock_area.name : "Unknown"
		))
	data["airlocks"] = airlock_data

	return data

/obj/machinery/computer/ship_construction/ui_static_data(mob/user)
	var/list/data = list()

	data["shipName"] = current_ship ? current_ship.display_name : null

	return data

/obj/machinery/computer/ship_construction/ui_act(action, list/params, datum/tgui/ui, datum/ui_state/state)
	. = ..()
	if(.)
		return

	// Server-side crew check
	if(!is_crew_member(usr))
		say("ERROR: Access denied. Crew authorization required.")
		return

	switch(action)
		if("relocate_port")
			var/obj/machinery/door/airlock/target = locate(params["airlock_ref"])
			if(!target)
				last_operation_message = "Invalid airlock selected."
				last_operation_success = FALSE
				return TRUE
			relocate_docking_port(target)
			return TRUE
		if("clear_message")
			last_operation_message = ""
			return TRUE

	return FALSE
