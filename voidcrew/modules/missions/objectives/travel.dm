/**
 * # Travel Objectives
 *
 * Ship-level verbs: fly the ship somewhere, or scan things with the survey
 * console. Both listen on the servant ship and complete off signals.
 */

// =========================================================================
// GO TO COORDINATES, fly within range of the mission target
// =========================================================================

/datum/mission_objective/goto_coords
	/// Range (overmap tiles) within which the target counts as reached
	var/completion_range = 1
	/// What the crew is told when they arrive
	var/arrival_message = "Survey coordinates reached! Return to the mission board to collect your reward."

/datum/mission_objective/goto_coords/activate()
	. = ..()
	var/obj/structure/overmap/ship/ship = get_servant()
	if(!ship)
		return
	RegisterSignal(ship, COMSIG_VOIDCREW_SHIP_MOVED, PROC_REF(on_ship_moved))
	check_position()

/datum/mission_objective/goto_coords/deactivate()
	var/obj/structure/overmap/ship/ship = get_servant()
	if(ship)
		UnregisterSignal(ship, COMSIG_VOIDCREW_SHIP_MOVED)
	return ..()

/datum/mission_objective/goto_coords/proc/on_ship_moved(datum/source)
	SIGNAL_HANDLER
	check_position()

/// Ship position in relative overmap coordinates, or null
/datum/mission_objective/goto_coords/proc/get_ship_coords()
	var/obj/structure/overmap/ship/ship = get_servant()
	if(!ship)
		return null
	return list(ship.x, ship.y - OVERMAP_SOUTH_SIDE_COORD + 1)

/datum/mission_objective/goto_coords/proc/get_distance_to_target()
	var/list/ship_coords = get_ship_coords()
	var/datum/mission_target/target = mission?.target
	if(!ship_coords || !target)
		return null
	return sqrt((ship_coords[1] - target.target_x) ** 2 + (ship_coords[2] - target.target_y) ** 2)

/datum/mission_objective/goto_coords/proc/check_position()
	if(completed)
		return
	var/dist = get_distance_to_target()
	if(isnull(dist) || dist > completion_range)
		return
	if(arrival_message)
		notify_crew(arrival_message)
	complete()

/datum/mission_objective/goto_coords/get_progress_string()
	if(completed)
		return "Coordinates reached"
	var/dist = get_distance_to_target()
	if(isnull(dist))
		return "Head for the marked coordinates"
	return "[round(dist)] tiles away"

// =========================================================================
// SCAN CELESTIALS: survey console counter
// =========================================================================

/datum/mission_objective/scan_celestial
	/// Type key of celestial objects to survey ("planets", "nebulas", ... or "any");
	/// keys match survey_research.survey_objects_by_type
	var/target_type = "any"
	/// Display names for the target type
	var/target_name = "celestial objects"
	var/target_name_singular = "celestial object"
	/// Scans required / done
	var/required_amount = 3
	var/current_amount = 0

/datum/mission_objective/scan_celestial/reset()
	. = ..()
	current_amount = 0

/datum/mission_objective/scan_celestial/proc/display_name()
	return required_amount == 1 ? target_name_singular : target_name

/datum/mission_objective/scan_celestial/activate()
	. = ..()
	var/obj/structure/overmap/ship/ship = get_servant()
	if(ship)
		RegisterSignal(ship, COMSIG_VOIDCREW_SURVEY_COMPLETED, PROC_REF(on_survey_completed))

/datum/mission_objective/scan_celestial/deactivate()
	var/obj/structure/overmap/ship/ship = get_servant()
	if(ship)
		UnregisterSignal(ship, COMSIG_VOIDCREW_SURVEY_COMPLETED)
	return ..()

/datum/mission_objective/scan_celestial/proc/on_survey_completed(datum/source, celestial_type)
	SIGNAL_HANDLER
	if(completed)
		return
	if(target_type != "any" && celestial_type != target_type)
		return
	current_amount++
	if(current_amount >= required_amount)
		notify_crew("Survey quota met. Return to the mission board to collect your reward.")
		complete()
		return
	notify_crew("Surveyed [current_amount]/[required_amount] [display_name()].", sound = 'voidcrew/sound/notify2.ogg')

/datum/mission_objective/scan_celestial/get_progress_string()
	return "[current_amount]/[required_amount] [display_name()]"
