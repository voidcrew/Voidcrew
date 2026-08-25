/**
 * Voidcrew's scheduler for ship-scoped dynamic events.
 *
 * SSevents stays alive but inert (allow_random_events is FALSE), and still
 * processes the running list, event instances register themselves with
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
	/// Scheduling bounds, expressed PER CREW rather than fleet-wide: this is how long
	/// one ship should go between ambient events. The global cadence is this divided by
	/// the number of crewed ships (see reschedule()), because each firing only hits one
	/// of them, so a solo player and a six-ship fleet each get hit at about the same
	/// rate, instead of the solo player absorbing the entire fleet's event budget.
	var/frequency_lower = 25 MINUTES
	var/frequency_upper = 45 MINUTES
	/// Floor on the global cadence however large the fleet grows, so a busy server
	/// doesn't turn into a continuous stream of events.
	var/minimum_interval = 5 MINUTES
	/// Live per-ship immunity window (see is_valid_target). A var rather than the bare
	/// define so it can be tuned mid-round without a recompile.
	var/ship_cooldown = DYNAMIC_EVENT_SHIP_COOLDOWN
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
	var/interval = rand(frequency_lower, max(frequency_lower, frequency_upper))
	scheduled = world.time + max(round(interval / crewed_ship_count()), minimum_interval)

/**
 * Ships with at least one living, connected player aboard, the divisor that turns the
 * per-crew interval into a global cadence. Never returns less than 1: with nobody aboard
 * anything there is no event to schedule, and dividing by zero is worse than waiting.
 */
/datum/controller/subsystem/dynamic_events/proc/crewed_ship_count()
	var/count = 0
	for(var/obj/structure/overmap/ship/ship as anything in SSovermap.simulated_ships)
		if(QDELETED(ship) || ship.abandoned || !ship.shuttle)
			continue
		if(!length(ship.get_event_crew()))
			continue
		count++
	return max(count, 1)

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
