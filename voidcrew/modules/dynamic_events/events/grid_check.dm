/**
 * Ship-scoped port of TG's Grid Check (code/modules/events/grid_check.dm).
 * Knocks out every APC aboard one ship for a short while (or until the crew
 * manually reboots them), announced by the ship computer as a grid fluctuation.
 * See voidcrew/GUIDES/dynamic_events_port_spec.md
 */
/datum/round_event_control/voidcrew/grid_check
	name = "Ship Grid Check"
	typepath = /datum/round_event/voidcrew/grid_check
	weight = 5
	max_occurrences = 3
	category = EVENT_CATEGORY_ENGINEERING
	description = "Turns off all APCs aboard the target ship for a while, or until they are manually rebooted."
	min_players = 0
	min_crew_aboard = 2
	allowed_zones = list(ZONE_YELLOW, ZONE_RED)

/datum/round_event_control/voidcrew/grid_check/is_valid_target(obj/structure/overmap/ship/ship)
	. = ..()
	if(!.)
		return FALSE
	// Pointless on a ship with no APCs to knock out
	return length(ship.get_ship_machines(/obj/machinery/power/apc)) > 0

/datum/round_event/voidcrew/grid_check
	announce_when = 1
	start_when = 1

/datum/round_event/voidcrew/grid_check/announce(fake)
	if(!target_valid())
		return
	target_ship.ship_event_announce("Abnormal power fluctuations detected in the ship's grid. As a precautionary measure, the ship's power will be shut off for an indeterminate duration.", "Critical Power Failure", ANNOUNCER_POWEROFF)

/// Fails each APC aboard the ship for a random 30-120 seconds, matching TG's
/// power_fail(30, 120). The crew can still reboot each APC early by hand.
/datum/round_event/voidcrew/grid_check/start()
	if(!target_valid())
		return
	for(var/obj/machinery/power/apc/current_apc as anything in target_ship.get_ship_machines(/obj/machinery/power/apc))
		if(QDELETED(current_apc) || !current_apc.cell)
			continue
		current_apc.energy_fail(rand(30, 120))
