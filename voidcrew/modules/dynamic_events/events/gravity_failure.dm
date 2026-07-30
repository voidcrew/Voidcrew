/**
 * Gravity Generator Failure — voidcrew's replacement for TG's Gravity Generator
 * Blackout (code/modules/events/gravity_generator_blackout.dm).
 *
 * Not a port. TG's event switches off a specific machine, `/obj/machinery/gravity_generator/main`,
 * and requires a crewmember to walk to it and reset it by hand. No voidcrew hull maps
 * one — ship gravity comes from `default_gravity` on the shuttle areas themselves, so
 * there is no generator to black out and nothing to walk to. Rather than map a machine
 * onto forty-odd hulls to preserve a mechanic, the event acts on the thing that actually
 * provides gravity here: the deck plating cuts out ship-wide and comes back on its own.
 *
 * has_gravity() short-circuits on the area's NO_GRAVITY flag before it ever consults
 * default_gravity or the z-level, so setting that flag is a complete and reversible
 * override. Shuttle areas are per-instance ("Loading the same shuttle map at a different
 * time will produce distinct area instances", /area/shuttle), so this cannot leak onto
 * another crew flying the same hull.
 */
/datum/round_event_control/voidcrew/gravity_failure
	name = "Gravity Generator Failure"
	typepath = /datum/round_event/voidcrew/gravity_failure
	weight = 25
	max_occurrences = 3
	earliest_start = 10 MINUTES
	category = EVENT_CATEGORY_ENGINEERING
	description = "The target ship's deck plating loses gravity for a few minutes."
	/// Zero-g is a navigation problem, and it needs somewhere to navigate. A hull with one
	/// room is a hull where you are already touching the far wall.
	min_ship_mass = SHIP_MASS_SMALL
	min_wizard_trigger_potency = 0
	max_wizard_trigger_potency = 4

/datum/round_event/voidcrew/gravity_failure
	announce_when = 1
	start_when = 3
	/// ~3 minutes at two seconds a tick. Long enough to be a real problem, short enough
	/// that a crew mid-repair is not stuck floating for the rest of the round.
	end_when = 93
	fakeable = TRUE
	/// Areas this event actually flipped, so end() restores exactly what it changed.
	/// Areas that were already weightless when we started are left out and stay that way.
	var/list/area/suppressed_areas = list()

/datum/round_event/voidcrew/gravity_failure/announce(fake)
	if(!target_valid())
		return
	target_ship.ship_event_announce(
		"Fault on the gravity bus. Deck plating is dropping out across the ship. Secure loose equipment and hold onto something.",
		"Gravity Alert",
		ANNOUNCER_GRANOMALIES,
	)

/datum/round_event/voidcrew/gravity_failure/start()
	if(!target_valid())
		return
	for(var/area/ship_area as anything in target_ship.shuttle.shuttle_areas)
		if(QDELETED(ship_area) || (ship_area.area_flags & NO_GRAVITY))
			continue
		ship_area.area_flags |= NO_GRAVITY
		suppressed_areas += ship_area

	if(!length(suppressed_areas)) // Already a weightless hull; nothing to take away.
		kill()
		return

	refresh_crew_gravity()
	target_ship.play_ship_sound('sound/effects/empulse.ogg', 40)

/datum/round_event/voidcrew/gravity_failure/end()
	restore_gravity()
	if(!target_valid())
		return
	target_ship.ship_event_announce("Gravity bus back online. Plating is holding.", "Gravity Alert")

/**
 * Gravity must come back even if the event is killed early or the ship dies mid-fault —
 * the flag lives on the area, not on this datum, so leaking it would leave a hull
 * permanently weightless with nothing left to explain why.
 */
/datum/round_event/voidcrew/gravity_failure/kill()
	restore_gravity()
	return ..()

/// Clears the flag from every area this event set it on, and re-checks everyone aboard.
/datum/round_event/voidcrew/gravity_failure/proc/restore_gravity()
	for(var/area/ship_area as anything in suppressed_areas)
		if(QDELETED(ship_area))
			continue
		ship_area.area_flags &= ~NO_GRAVITY
	suppressed_areas.Cut()
	refresh_crew_gravity()

/**
 * Living mobs cache their gravity state and only recheck it on movement or a z change,
 * so flipping an area flag under a mob standing still does nothing until it steps. Poke
 * everyone aboard directly.
 */
/datum/round_event/voidcrew/gravity_failure/proc/refresh_crew_gravity()
	if(!target_valid())
		return
	for(var/mob/living/aboard as anything in target_ship.get_all_mobs_aboard(include_dead = TRUE))
		aboard.refresh_gravity()
