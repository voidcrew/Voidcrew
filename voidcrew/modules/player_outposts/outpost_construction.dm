/**
 * # Outpost Construction Console
 *
 * The ship construction console rebound to a player outpost: same internal
 * RCD/RTD/RPD/RLD tools and ore-silo plumbing, same remote drone, but the
 * build envelope is the outpost's fixed rectangular build region instead of
 * shuttle areas — so all the shuttle-expansion machinery is switched off.
 * Nothing here flies, so there is no docked-state gate either.
 *
 * Access is per-ckey: the outpost owner plus anyone they authorize at the
 * management console.
 */

/obj/item/circuitboard/computer/player_outpost_construction
	name = "Outpost Construction (Computer Board)"
	greyscale_colors = CIRCUIT_COLOR_ENGINEERING
	build_path = /obj/machinery/computer/camera_advanced/base_construction/ship/outpost

/obj/machinery/computer/camera_advanced/base_construction/ship/outpost
	name = "outpost construction console"
	desc = "A console for building out the outpost. Control a remote drone to construct and modify anything within the claim's survey bounds."
	circuit = /obj/item/circuitboard/computer/player_outpost_construction
	/// The outpost this console builds for (set by link_interior_machinery, or found on Initialize for rebuilt consoles)
	var/obj/structure/overmap/dynamic/player_outpost/outpost

/obj/machinery/computer/camera_advanced/base_construction/ship/outpost/Destroy()
	if(outpost?.construction_console == src)
		outpost.construction_console = null
	outpost = null
	return ..()

/// Rebuilt consoles relink to the outpost that owns their z-level
/obj/machinery/computer/camera_advanced/base_construction/ship/outpost/attempt_ship_connection()
	if(outpost)
		return TRUE
	for(var/obj/structure/overmap/dynamic/player_outpost/candidate as anything in GLOB.player_outposts)
		if(!candidate.mapzone)
			continue
		for(var/datum/space_level/level as anything in candidate.mapzone.z_levels)
			if(level.z_value == z)
				outpost = candidate
				if(!candidate.construction_console)
					candidate.construction_console = src
				return TRUE
	return FALSE

/obj/machinery/computer/camera_advanced/base_construction/ship/outpost/connect_to_shuttle(mapload, obj/docking_port/mobile/voidcrew/port, obj/docking_port/stationary/dock)
	return // not shuttle machinery

/// Builder authorization instead of ship crew membership
/obj/machinery/computer/camera_advanced/base_construction/ship/outpost/is_crew_member(mob/user)
	if(isAdminGhostAI(user))
		return TRUE
	if(!outpost)
		return FALSE
	return outpost.can_build(user)

/// Outposts don't fly: operable whenever linked
/obj/machinery/computer/camera_advanced/base_construction/ship/outpost/can_operate()
	return !!outpost

/obj/machinery/computer/camera_advanced/base_construction/ship/outpost/get_operate_error()
	return "No outpost registry link established."

/obj/machinery/computer/camera_advanced/base_construction/ship/outpost/get_docking_port()
	return null

/obj/machinery/computer/camera_advanced/base_construction/ship/outpost/find_spawn_spot()
	if(outpost?.arrival_turf)
		return outpost.arrival_turf
	return get_turf(src)

// The whole build region counts as "inside": the expansion branch of the
// build actions (expand_shuttle_to_turf on !was_in_shuttle) can never trigger
/obj/machinery/computer/camera_advanced/base_construction/ship/outpost/is_in_shuttle_area(turf/T)
	return outpost?.is_turf_buildable(T)

/obj/machinery/computer/camera_advanced/base_construction/ship/outpost/is_adjacent_to_shuttle(turf/T)
	return FALSE

/obj/machinery/computer/camera_advanced/base_construction/ship/outpost/can_move_to(turf/T)
	return T && outpost?.is_turf_buildable(T)

/obj/machinery/computer/camera_advanced/base_construction/ship/outpost/can_build_at(turf/T)
	return T && outpost?.is_turf_buildable(T)

// No shuttle to grow, shrink or re-port
/obj/machinery/computer/camera_advanced/base_construction/ship/outpost/expand_shuttle_to_turf(turf/T, mob/user)
	return FALSE

/obj/machinery/computer/camera_advanced/base_construction/ship/outpost/check_expansion_dimensions(turf/new_turf, obj/docking_port/mobile/port)
	return FALSE

/obj/machinery/computer/camera_advanced/base_construction/ship/outpost/cleanup_deconstructed_turfs()
	return

/obj/machinery/computer/camera_advanced/base_construction/ship/outpost/reset_fans()
	last_operation_message = "Outposts have no edge airlocks to fan."
	last_operation_success = FALSE
	return FALSE

/obj/machinery/computer/camera_advanced/base_construction/ship/outpost/relocate_docking_port(obj/machinery/door/airlock/new_airlock)
	last_operation_message = "Outpost docking pads are fixed."
	last_operation_success = FALSE
	return FALSE

/obj/machinery/computer/camera_advanced/base_construction/ship/outpost/ui_data(mob/user)
	var/list/data = ..()
	// Report the build region instead of shuttle bounds
	if(outpost?.build_bounds)
		data["shipWidth"] = outpost.build_bounds[3] - outpost.build_bounds[1] + 1
		data["shipHeight"] = outpost.build_bounds[4] - outpost.build_bounds[2] + 1
		data["maxDimensionLong"] = data["shipWidth"]
		data["maxDimensionShort"] = data["shipHeight"]
	return data

/obj/machinery/computer/camera_advanced/base_construction/ship/outpost/ui_static_data(mob/user)
	var/list/data = ..()
	data["shipName"] = outpost ? outpost.name : null
	return data
