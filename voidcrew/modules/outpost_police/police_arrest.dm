/**
 * # Outpost police: arrests
 *
 * Owner: P5. One /datum/outpost_police_case per suspect at one or two stars: respond, order, subdue, cuff,
 * search, escort, desk, book. Every step on the suspect's body is the tg action a player officer would take.
 * Spec 6 (the step table and 6.4).
 */

/// Owns the officer while it has a case step to do
/datum/ai_planning_subtree/outpost_police_case

/datum/ai_planning_subtree/outpost_police_case/SelectBehaviors(datum/ai_controller/controller, seconds_per_tick)
	return

/// Opens an arrest for `warrant`. Returns the case, or null.
/datum/outpost_police/proc/open_case(datum/outpost_warrant/warrant)
	return null

/// Closes `who`'s arrest, if any
/datum/outpost_police/proc/close_case(datum/mind/who)
	return

/// Once a second (police_core.dm tick()): start, reassign and close cases
/datum/outpost_police/proc/tick_cases()
	return
