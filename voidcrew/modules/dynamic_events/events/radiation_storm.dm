/**
 * Ship-scoped port of TG's Radiation Storm (code/modules/events/radiation_storm.dm).
 *
 * A ship has no maintenance shelter, so hull-edge compartments are exposed while
 * interior compartments provide protection from the passing radiation front.
 *
 * ADMIN-ONLY. Radiation storms are red-band planet weather now, see
 * /datum/weather/rad_storm/planetary in voidcrew/datums/weather.dm.
 *
 * The reason is the shelter rule above. It reads well and it is the best part of the
 * event, but on the hulls this actually targeted it frequently had no answer: a
 * small ship is mostly hull edge, so all_areas_exposed was the common case and the
 * fallback is a flat 65% chance per pulse with nowhere to stand. On a planet the same
 * idea has three real answers instead. Go underground, return to the ship, or wear
 * rad-protective clothing, and it arrives on the planet's own weather schedule, so it
 * belongs to a place the crew chose to visit rather than following them around.
 */
/datum/round_event_control/voidcrew/radiation_storm
	name = "Radiation Storm"
	typepath = /datum/round_event/voidcrew/radiation_storm
	weight = 0
	max_occurrences = 0
	category = EVENT_CATEGORY_SPACE
	description = "A radiation front irradiates crew in the target ship's hull-edge compartments."
	min_wizard_trigger_potency = 3
	max_wizard_trigger_potency = 7
	event_scope = EVENT_SCOPE_SHIP
	allowed_zones = list(ZONE_YELLOW, ZONE_RED)
	requires_flying = TRUE
	/// The event's whole shape is "shelter in an interior compartment". A hull too small to
	/// have an interior is all exposed, so there is nothing to do but stand there and take it.
	min_ship_mass = SHIP_MASS_SMALL

/// Washes a target ship's exposed compartments with several moderate radiation pulses.
/datum/round_event/voidcrew/radiation_storm
	announce_when = 1
	start_when = 16
	end_when = 46
	/// Ship areas with at least one turf directly adjacent to space, cached when the storm starts.
	var/list/exposed_areas = list()
	/// Whether the ship has no interior area that can act as reliable shelter.
	var/all_areas_exposed = FALSE

/datum/round_event/voidcrew/radiation_storm/announce(fake)
	if(!target_valid())
		return
	target_ship.ship_event_announce(
		"A radiation front has been detected on an intercept course. Move to interior compartments immediately.",
		"Anomaly Alert",
		ANNOUNCER_RADIATION,
	)

/datum/round_event/voidcrew/radiation_storm/start()
	if(!target_valid())
		return

	exposed_areas = list()
	var/list/ship_areas = target_ship.shuttle.shuttle_areas
	if(!length(ship_areas))
		return

	// A compartment is exposed if any of its OPEN turfs borders space, solid hull
	// walls shield the room behind them, but windows/airlocks onto space do not.
	for(var/area/ship_area as anything in ship_areas)
		for(var/turf/ship_turf in ship_area)
			if(!isopenturf(ship_turf))
				continue
			for(var/turf/adjacent_turf as anything in get_adjacent_turfs(ship_turf))
				if(!isspaceturf(adjacent_turf))
					continue
				exposed_areas += ship_area
				break
			if(ship_area in exposed_areas)
				break

	all_areas_exposed = length(exposed_areas) == length(ship_areas)
	irradiate_exposed_crew()

/datum/round_event/voidcrew/radiation_storm/tick()
	if(!target_valid())
		return
	if((activeFor - start_when) % 5)
		return
	irradiate_exposed_crew()

/datum/round_event/voidcrew/radiation_storm/end()
	if(!target_valid())
		return
	target_ship.ship_event_announce(
		"The radiation front has passed. Hull exposure has returned to safe levels.",
		"Anomaly Alert",
	)

/// Applies one pulse to currently exposed living mobs aboard the target ship.
/datum/round_event/voidcrew/radiation_storm/proc/irradiate_exposed_crew()
	if(!target_valid())
		return
	if(target_ship.state != OVERMAP_SHIP_FLYING || target_ship.docked)
		return

	for(var/mob/living/crew_member as anything in target_ship.get_all_mobs_aboard())
		var/area/crew_area = get_area(crew_member)
		if(!crew_area)
			continue
		if(all_areas_exposed)
			if(!prob(65))
				continue
		else if(!(crew_area in exposed_areas))
			continue
		if(!SSradiation.can_irradiate_basic(crew_member))
			continue

		radiation_pulse(
			source = crew_member,
			max_range = 0,
			threshold = RAD_LIGHT_INSULATION,
			chance = 100,
		)
