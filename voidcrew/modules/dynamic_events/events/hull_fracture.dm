/**
 * Hull Fracture — voidcrew's take on TG's Chasmic Earthquake
 * (code/modules/events/earthquake.dm).
 *
 * The shape of the original survives intact: an epicentre, a rough fault line drawn
 * through it, a long telegraph of shaking tiles, then the fault lets go. What changes is
 * what "letting go" means. TG's fault drops into the z-level below, which a ship does
 * not have — one deck, vacuum underneath — so here the fault line blows out into space
 * instead of down. Same warning, same "get off the marked tiles", different hole.
 *
 * Read as metal fatigue rather than seismology: a stress fracture running through the
 * spaceframe that finally opens. The crew get roughly fifty seconds of groaning plating
 * and shaking deck to clear the line and seal the compartment off before it goes.
 */
/datum/round_event_control/voidcrew/hull_fracture
	name = "Hull Fracture"
	typepath = /datum/round_event/voidcrew/hull_fracture
	weight = 7
	max_occurrences = 2
	earliest_start = 30 MINUTES
	min_crew_aboard = 2
	category = EVENT_CATEGORY_ENGINEERING
	description = "A stress fracture opens along a line of the target ship's hull."
	allowed_zones = list(ZONE_YELLOW, ZONE_RED)
	/// The fault is a fixed-size line, not a fraction of the hull. On anything smaller
	/// than a Delta-class it is not a fracture running through the ship, it is the ship.
	min_ship_mass = SHIP_MASS_LARGE
	min_wizard_trigger_potency = 3
	max_wizard_trigger_potency = 7

/datum/round_event/voidcrew/hull_fracture
	start_when = 1
	announce_when = 3
	end_when = 25
	announce_chance = 100 // Unlike the station original this is never a surprise: the fault is visible and the crew need the warning.
	fakeable = FALSE
	/// Centre of the fault.
	var/turf/epicenter
	/// Turfs the fracture runs through, which blow out at the end.
	var/list/turfs_to_shred = list()
	/// Turfs bordering the fault, which take lighter damage.
	var/list/edges = list()

/**
 * Draws the fault line. Follows the original's method — a block around the epicentre,
 * culled down to the turfs near a chain of midpoints so the result reads as a crack
 * rather than a rectangle — but every candidate is filtered through is_aboard(), so the
 * fault can never run off the hull into a ruin the ship happens to be parked on.
 */
/datum/round_event/voidcrew/hull_fracture/setup()
	if(!target_valid())
		kill()
		return

	epicenter = pick_epicenter()
	if(!epicenter)
		kill()
		return

	// Shorter arms than the station version — a ship is not 255 tiles across.
	var/turf/fracture_point_high = locate(epicenter.x + rand(3, 6), epicenter.y + rand(3, 5), epicenter.z)
	var/turf/fracture_point_low = locate(epicenter.x - rand(3, 6), epicenter.y - rand(3, 5), epicenter.z)
	if(!fracture_point_high || !fracture_point_low)
		kill()
		return

	var/turf/high_midpoint = TURF_MIDPOINT(fracture_point_high, epicenter)
	var/turf/low_midpoint = TURF_MIDPOINT(fracture_point_low, epicenter)
	var/list/turfs_to_compare = list(
		fracture_point_high,
		fracture_point_low,
		high_midpoint,
		low_midpoint,
		TURF_MIDPOINT(fracture_point_high, high_midpoint),
		TURF_MIDPOINT(fracture_point_low, low_midpoint),
		TURF_MIDPOINT(high_midpoint, epicenter),
		TURF_MIDPOINT(low_midpoint, epicenter),
	)

	for(var/turf/candidate as anything in block(fracture_point_high, fracture_point_low))
		// Anything not ours is somebody else's deck, or the vacuum between us and it.
		if(!target_ship.is_aboard(candidate))
			continue
		var/nearest_distance = get_dist(candidate, epicenter)
		for(var/turf/comparison as anything in turfs_to_compare)
			nearest_distance = min(get_dist(candidate, comparison), nearest_distance)
		if(nearest_distance > 2)
			if(nearest_distance == 3)
				edges += candidate
			continue
		turfs_to_shred += candidate

	if(!length(turfs_to_shred))
		kill()
		return
	message_admins("A hull fracture is about to open aboard [target_ship.display_name || target_ship.name] in [get_area_name(epicenter)][ADMIN_JMP(epicenter)].")

/**
 * Where the fault starts. Prefers a mapper-placed event_spawn marker aboard so a hull's
 * author can keep the crack out of the cockpit, and falls back to any open turf so the
 * event still works on the hulls that have no markers.
 */
/datum/round_event/voidcrew/hull_fracture/proc/pick_epicenter()
	var/list/markers = target_ship.get_ship_event_spawns()
	if(length(markers))
		var/obj/effect/landmark/event_spawn/marker = pick(markers)
		return get_turf(marker)
	return target_ship.get_random_open_ship_turf()

/datum/round_event/voidcrew/hull_fracture/announce(fake)
	if(!target_valid())
		return
	target_ship.ship_event_announce(
		"Structural monitoring reports a propagating stress fracture in the spaceframe. Clear the affected compartment and seal it off.",
		"Structural Alert",
	)

/datum/round_event/voidcrew/hull_fracture/start()
	if(!target_valid())
		return
	notify_ghosts(
		"A hull fracture is opening aboard [target_ship.display_name || target_ship.name]: [get_area_name(epicenter)]!",
		source = epicenter,
		header = "Groan, Groan, Groan",
	)

/datum/round_event/voidcrew/hull_fracture/tick()
	if(!target_valid())
		return

	if(ISMULTIPLE(activeFor, 5))
		for(var/turf/faulted as anything in turfs_to_shred)
			faulted.Shake(pixelshiftx = 0.1, pixelshifty = 0.1, duration = 1 SECONDS)

		if(ISMULTIPLE(activeFor, 10))
			// Only the crew standing on this hull hear their ship coming apart.
			for(var/mob/living/witness as anything in target_ship.get_all_mobs_aboard())
				shake_camera(witness, 1 SECONDS, 1 + (activeFor % 10))
				witness.playsound_local(witness, 'sound/misc/metal_creak.ogg', 60)

	// The last few seconds: the deck goes from groaning to throwing people over.
	if(activeFor == end_when - 2)
		for(var/turf/faulted as anything in turfs_to_shred)
			faulted.Shake(pixelshiftx = 0.5, pixelshifty = 0.5, duration = 1 SECONDS)
			for(var/mob/living/victim in faulted)
				victim.Knockdown(7 SECONDS)
				victim.Paralyze(5 SECONDS)
				to_chat(victim, span_warning("The deck buckles violently beneath you, throwing you off your feet!"))

	if(activeFor == end_when - 1)
		for(var/turf/faulted as anything in turfs_to_shred)
			if(prob(90))
				SSexplosions.lowturf += faulted
		for(var/turf/edge as anything in edges)
			edge.Shake(pixelshiftx = 0.5, pixelshifty = 0.5, duration = 1 SECONDS)
		playsound(epicenter, 'sound/misc/metal_creak.ogg', 125, TRUE)

/**
 * The fault lets go. As in the original there is no real explosion — the blast is applied
 * to the fault turfs and their contents only, so a compartment two rooms away is fine and
 * anyone still standing on the line is not.
 */
/datum/round_event/voidcrew/hull_fracture/end()
	if(!target_valid())
		return

	for(var/mob/living/witness as anything in target_ship.get_all_mobs_aboard())
		shake_camera(witness, 2 SECONDS, 4)
		witness.playsound_local(witness, 'sound/effects/explosion/explosionfar.ogg', 75)

	for(var/turf/faulted as anything in turfs_to_shred)
		if(prob(10))
			SSexplosions.medturf += faulted
		else
			SSexplosions.highturf += faulted

	for(var/turf/edge as anything in edges)
		if(prob(25))
			SSexplosions.medturf += edge
		else
			SSexplosions.lowturf += edge

	target_ship.ship_event_announce("The fracture has opened. Hull breach along the fault line — vac suits and sealant, now.", "Structural Alert")
