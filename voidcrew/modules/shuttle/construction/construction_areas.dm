/// Survey an existing compartment without crossing the owning ship's boundary.
/proc/survey_ship_room(turf/origin, obj/docking_port/mobile/port, max_tiles = 300)
	var/datum/hull_claim/room = new
	var/list/owned_areas = port ? hull_owned_areas(port) : list()
	if(!origin || origin.z != port?.z || !(get_area(origin) in owned_areas) || !isfloorturf(origin))
		room.refusal = "Select a floor inside your ship."
		return room
	refresh_atmos_adjacency(origin)
	if(hull_barrier_turf(origin))
		room.refusal = "Move inside the room, away from its doors and windows."
		return room

	var/list/pending = list(origin)
	var/list/interior = list()
	interior[origin] = TRUE
	room.turfs[origin] = TRUE
	while(length(pending))
		var/turf/here = pending[1]
		pending.Cut(1, 2)
		refresh_atmos_adjacency(here)
		for(var/check_dir in GLOB.alldirs)
			var/turf/there = get_step(here, check_dir)
			if(!there)
				room.refusal = "The room reaches the edge of the map."
				return room
			refresh_atmos_adjacency(there)
			var/is_owned = (get_area(there) in owned_areas)
			if(!TURFS_CAN_SHARE(here, there))
				// Include our walls and corners, but never the space beyond a thin window.
				if(is_owned && !isspaceturf(there) && hull_barrier_turf(there))
					room.turfs[there] = TRUE
			else if(check_dir in GLOB.cardinals)
				if(!is_owned || isspaceturf(there))
					room.refusal = "Seal the room off from space and other ships first."
					return room
				room.turfs[there] = TRUE
				if(!interior[there])
					interior[there] = TRUE
					pending += there
			if(length(room.turfs) > max_tiles)
				room.refusal = "The room exceeds the [max_tiles] tile limit."
				return room
	return room

/// Only APCs actually being moved compete with the destination's existing APC.
/proc/ship_room_apc_conflict(list/turfs, area/destination)
	var/list/apcs = list()
	if(destination?.apc)
		apcs += destination.apc
	for(var/turf/tile as anything in turfs)
		for(var/obj/machinery/power/apc/apc in tile)
			apcs |= apc
	return length(apcs) > 1

/// The operator edits at their drone; other console users edit at the console.
/obj/machinery/computer/camera_advanced/base_construction/ship/proc/area_edit_turf(mob/user)
	if(eyeobj && current_user == user && user.remote_control == eyeobj)
		return get_turf(eyeobj)
	return get_turf(src)

/obj/machinery/computer/camera_advanced/base_construction/ship/proc/ship_area_controls_data(mob/user)
	var/obj/docking_port/mobile/port = get_docking_port()
	if(!port || !user)
		return null
	var/turf/origin = area_edit_turf(user)
	var/area/current_area = get_area(origin)
	var/is_owned = origin && origin.z == port.z && (current_area in hull_owned_areas(port))
	return list(
		"name" = is_owned ? current_area.name : "Outside ship",
		"atDrone" = eyeobj && current_user == user && user.remote_control == eyeobj,
		"canEdit" = is_owned && is_operational && can_operate() && is_crew_member(user),
	)

/// Recheck after prompts: the operator, drone, ship or area may have changed.
/obj/machinery/computer/camera_advanced/base_construction/ship/proc/can_edit_ship_area(mob/user, turf/origin, obj/docking_port/mobile/port)
	return !QDELETED(port) && port == get_docking_port() && can_use(user) \
		&& origin == area_edit_turf(user) && origin?.z == port.z \
		&& (get_area(origin) in hull_owned_areas(port))

/obj/machinery/computer/camera_advanced/base_construction/ship/proc/ship_area_message(mob/user, message, success = FALSE)
	last_operation_message = message
	last_operation_success = success
	to_chat(user, success ? span_notice(message) : span_warning(message))

/obj/machinery/computer/camera_advanced/base_construction/ship/proc/ship_area_control_act(action, mob/user)
	if(!(action in list("ship_area_rename", "ship_area_reassign")))
		return FALSE
	var/obj/docking_port/mobile/port = get_docking_port()
	var/turf/origin = area_edit_turf(user)
	if(!can_edit_ship_area(user, origin, port))
		ship_area_message(user, "Area editing is unavailable here.")
		return TRUE

	if(action == "ship_area_rename")
		var/area/current_area = get_area(origin)
		var/new_name = trim(tgui_input_text(user, "Area name:", "Rename Area", current_area.name, max_length = MAX_NAME_LEN))
		if(!length(new_name))
			return TRUE
		if(!can_edit_ship_area(user, origin, port) || QDELETED(current_area) || get_area(origin) != current_area)
			return TRUE
		var/old_name = current_area.name
		rename_area(current_area, new_name)
		log_shuttle("[key_name(user)] renamed [old_name] to [new_name] on [port] using [src].")
		ship_area_message(user, "Area renamed to [new_name].", TRUE)
		return TRUE

	var/list/choice = user.choose_hull_area(port)
	if(choice)
		reassign_ship_room(user, origin, port, choice[1], choice[2])
	return TRUE

/// Changes area membership only; the hull's turfs, baseturfs and footprint stay in place.
/obj/machinery/computer/camera_advanced/base_construction/ship/proc/reassign_ship_room(mob/user, turf/origin, obj/docking_port/mobile/port, area/destination, new_name)
	if(!can_edit_ship_area(user, origin, port))
		return FALSE
	var/fresh_area = isnull(destination)
	if(fresh_area)
		new_name = trim(copytext_char(new_name, 1, MAX_NAME_LEN + 1))
		if(!length(new_name))
			return FALSE
	else if(QDELETED(destination) || !(destination in hull_owned_areas(port)))
		ship_area_message(user, "That area no longer belongs to this ship.")
		return FALSE

	var/datum/hull_claim/room = survey_ship_room(origin, port)
	var/refusal = room.refusal
	var/list/turfs = room.turfs
	qdel(room)
	if(refusal)
		ship_area_message(user, refusal)
		return FALSE
	if(ship_room_apc_conflict(turfs, destination))
		ship_area_message(user, "Remove the extra APC before merging these areas.")
		return FALSE
	if(fresh_area)
		destination = create_hull_area(port, new_name)
	assign_hull_area(port, turfs, destination, fresh_area)
	log_shuttle("[key_name(user)] assigned [length(turfs)] ship tiles to [destination.name] on [port] using [src].")
	ship_area_message(user, "Room assigned to [destination.name].", TRUE)
	return TRUE
