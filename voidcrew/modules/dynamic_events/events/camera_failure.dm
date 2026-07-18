/**
 * Ship-scoped port of TG's Camera Failure (code/modules/events/camerafailure.dm).
 * Exemplar for the dynamic-event porting pattern — see
 * voidcrew/GUIDES/dynamic_events_port_spec.md
 */
/datum/round_event_control/voidcrew/camera_failure
	name = "Ship Camera Failure"
	typepath = /datum/round_event/voidcrew/camera_failure
	weight = 100
	max_occurrences = 20
	alert_observers = FALSE
	category = EVENT_CATEGORY_ENGINEERING
	description = "Turns off a random amount of the target ship's cameras."

/datum/round_event_control/voidcrew/camera_failure/is_valid_target(obj/structure/overmap/ship/ship)
	. = ..()
	if(!.)
		return FALSE
	// Pointless on a ship with no cameras to break
	return length(ship.get_ship_machines(/obj/machinery/camera)) > 0

/datum/round_event/voidcrew/camera_failure
	fakeable = FALSE

/datum/round_event/voidcrew/camera_failure/start()
	if(!target_valid())
		return
	var/list/cameras = target_ship.get_ship_machines(/obj/machinery/camera)
	var/iterations = 1
	while(length(cameras) && prob(round(100 / iterations)))
		var/obj/machinery/camera/failing = pick_n_take(cameras)
		if(failing.camera_enabled)
			failing.toggle_cam(null, 0)
		iterations *= 2.5
