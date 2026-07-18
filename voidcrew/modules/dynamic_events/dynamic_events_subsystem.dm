/**
 * Voidcrew's scheduler for ship-scoped dynamic events.
 *
 * SSevents stays alive but inert (allow_random_events is FALSE), and still
 * processes the running list — event instances register themselves with
 * SSevents in /datum/round_event/New(), so ticking is inherited for free.
 * This subsystem only handles selection: roll a ported event from the roster,
 * let the control pick a target ship, fire.
 */
SUBSYSTEM_DEF(dynamic_events)
	name = "Dynamic Events"
	wait = 10 SECONDS
	runlevels = RUNLEVEL_GAME
	dependencies = list(
		/datum/controller/subsystem/events,
	)

	/// Master switch. Flip via VV to pause natural dynamic events; admin-forced ones still work.
	var/enabled = TRUE
	/// Next world.time a natural dynamic event may fire.
	var/scheduled = 0
	/// Scheduling bounds. Global cadence — each firing hits one ship, so with N
	/// crewed ships a given crew sees roughly one event per N * this interval.
	var/frequency_lower = 3 MINUTES
	var/frequency_upper = 8 MINUTES
	/// Roster of ported event controls. Shares instances with SSevents.control so
	/// occurrence counts and the admin "Trigger Event" panel stay coherent.
	var/list/datum/round_event_control/voidcrew/control = list()

/datum/controller/subsystem/dynamic_events/Initialize()
	for(var/datum/round_event_control/voidcrew/event in SSevents.control)
		control += event
	log_game("SSdynamic_events: [length(control)] ported event controls in the roster.")
	reschedule()
	return SS_INIT_SUCCESS

/datum/controller/subsystem/dynamic_events/fire(resumed)
	if(!enabled || !length(control))
		return
	if(scheduled > world.time)
		return
	spawn_dynamic_event()
	reschedule()

/datum/controller/subsystem/dynamic_events/proc/reschedule()
	scheduled = world.time + rand(frequency_lower, max(frequency_lower, frequency_upper))

/**
 * Rolls a weighted event from the roster and fires it.
 * Mirrors SSevents.spawnEvent(), minus the config gate that keeps TG events dead.
 *
 * Arguments:
 * * excluded_event - control to skip, used when an admin rerolls an event.
 */
/datum/controller/subsystem/dynamic_events/proc/spawn_dynamic_event(datum/round_event_control/voidcrew/excluded_event)
	set waitfor = FALSE // preRunEvent() sleeps through the admin cancel window

	var/players_amt = get_active_player_count(alive_check = TRUE, afk_check = TRUE, human_check = TRUE)
	var/list/roster = list()
	for(var/datum/round_event_control/voidcrew/event as anything in control)
		if(excluded_event && event.typepath == excluded_event.typepath)
			continue
		if(!event.can_spawn_event(players_amt))
			continue
		roster[event] = event.weight

	var/datum/round_event_control/voidcrew/chosen = pick_weight(roster)
	if(!chosen)
		return

	var/result = chosen.preRunEvent()
	if(result == EVENT_CANT_RUN)
		chosen.max_occurrences = 0
	else if(result == EVENT_READY)
		chosen.run_event(random = TRUE)
