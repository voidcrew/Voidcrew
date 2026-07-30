/**
 * Ship-scoped port of TG's False Alarm (code/modules/events/false_alarm.dm).
 *
 * Picks another dynamic event, announces it to the target ship, and then does absolutely
 * nothing. The crew seal the compartment, get in the suits, and wait for a meteor shower
 * that is not coming.
 *
 * Two restrictions on the pool that the original does not need:
 *
 * - Only EVENT_SCOPE_SHIP controls. A faked Market Crash would announce sector-wide from
 *   one crew's false alarm, which is not a prank, it is a lie to everybody else.
 * - Only events flagged `fakeable`. That is TG's rule too, and it matters more here: the
 *   ports that build their announcement out of state from setup() (which vent, which
 *   machine, which rock) all set it FALSE, so this never produces a half-empty warning.
 *
 * TG also fakes midround dynamic rulesets. Voidcrew does not run dynamic, so that half
 * of the original is dropped rather than ported.
 */
/datum/round_event_control/voidcrew/false_alarm
	name = "False Alarm"
	typepath = /datum/round_event/voidcrew/false_alarm
	weight = 20
	max_occurrences = 5
	earliest_start = 15 MINUTES
	category = EVENT_CATEGORY_BUREAUCRATIC
	description = "Announces an event to the target ship that is not actually happening."

/datum/round_event_control/voidcrew/false_alarm/can_spawn_event(players_amt, allow_magic = FALSE)
	. = ..()
	if(!.)
		return FALSE
	return length(get_fakeable_controls()) > 0

/// Every ship-scoped dynamic event whose announcement can stand on its own.
/datum/round_event_control/voidcrew/false_alarm/proc/get_fakeable_controls()
	var/list/candidates = list()
	for(var/datum/round_event_control/voidcrew/candidate as anything in SSdynamic_events.control)
		if(candidate == src)
			continue
		if(candidate.event_scope != EVENT_SCOPE_SHIP)
			continue
		var/datum/round_event/voidcrew/event = candidate.typepath
		if(!initial(event.fakeable))
			continue
		candidates += candidate
	return candidates

/datum/round_event/voidcrew/false_alarm
	announce_when = 0
	end_when = 1
	fakeable = FALSE // Faking a false alarm is just a false alarm.

/datum/round_event/voidcrew/false_alarm/announce(fake)
	if(fake || !target_valid())
		return

	var/datum/round_event_control/voidcrew/false_alarm/alarm_control = control
	if(!istype(alarm_control))
		return
	var/list/candidates = alarm_control.get_fakeable_controls()
	if(!length(candidates))
		return

	var/datum/round_event_control/voidcrew/picked = pick(candidates)

	// The borrowed event has to believe it is happening to our ship, or its announcement
	// bails on target_valid(). Hand it our target through the same channel the scheduler
	// uses, and take it back straight away so a real firing of that event is unaffected.
	var/obj/structure/overmap/ship/previous_target = picked.pending_target
	picked.pending_target = target_ship
	var/datum/round_event/voidcrew/fake_event = new picked.typepath(FALSE, picked)
	picked.pending_target = previous_target

	message_admins("False Alarm aboard [target_ship.display_name || target_ship.name]: [picked.name]")
	fake_event.kill() // No start, no ticks, no end. It only ever speaks.
	fake_event.announce(TRUE)
