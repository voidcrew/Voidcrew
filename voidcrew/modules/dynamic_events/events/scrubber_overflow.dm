/**
 * Ship-scoped port of TG's Scrubber Overflow (code/modules/events/scrubber_overflow.dm).
 *
 * The scrubbers aboard one ship spew foam laced with a random (mostly harmless)
 * reagent. Scrubber collection uses the target ship's machine list instead of the
 * station z-level, and the warning goes out over the ship's own announcement
 * channel. The Threatening and Catastrophic variants use genuinely dangerous
 * reagents far more often and are restricted to the hazardous zone bands.
 */
/datum/round_event_control/voidcrew/scrubber_overflow
	name = "Scrubber Overflow: Normal"
	typepath = /datum/round_event/voidcrew/scrubber_overflow
	weight = 5
	max_occurrences = 3
	category = EVENT_CATEGORY_JANITORIAL
	description = "The scrubbers release a tide of mostly harmless froth."

/datum/round_event_control/voidcrew/scrubber_overflow/is_valid_target(obj/structure/overmap/ship/ship)
	. = ..()
	if(!.)
		return FALSE
	// Pointless aboard a ship with no working scrubbers to overflow
	for(var/obj/machinery/atmospherics/components/unary/vent_scrubber/scrubber as anything in ship.get_ship_machines(/obj/machinery/atmospherics/components/unary/vent_scrubber))
		if(!scrubber.welded)
			return TRUE
	return FALSE

/datum/round_event_control/voidcrew/scrubber_overflow/threatening
	name = "Scrubber Overflow: Threatening"
	typepath = /datum/round_event/voidcrew/scrubber_overflow/threatening
	weight = 2
	max_occurrences = 1
	earliest_start = 35 MINUTES
	/// Rolls the genuinely dangerous reagent table often enough to hurt. Keep out of the safe ring.
	allowed_zones = list(ZONE_YELLOW, ZONE_RED)
	/// A lone crew member has no one to drag them out of a chemical foam flood.
	min_crew_aboard = 2
	/// Being dragged clear only helps if there is a clear tile to be dragged to, on a small
	/// hull the foam covers everything at once.
	min_ship_mass = SHIP_MASS_MEDIUM
	description = "The scrubbers release a tide of moderately harmless froth."

/datum/round_event_control/voidcrew/scrubber_overflow/catastrophic
	name = "Scrubber Overflow: Catastrophic"
	typepath = /datum/round_event/voidcrew/scrubber_overflow/catastrophic
	weight = 1
	max_occurrences = 1
	earliest_start = 45 MINUTES
	allowed_zones = list(ZONE_YELLOW, ZONE_RED)
	min_crew_aboard = 2
	min_ship_mass = SHIP_MASS_MEDIUM
	description = "The scrubbers release a tide of mildly harmless froth."

/datum/round_event/voidcrew/scrubber_overflow
	announce_when = 1
	start_when = 5
	fakeable = FALSE
	/// The probability that the ejected reagents will be dangerous
	var/danger_chance = 1
	/// Amount of reagents ejected from each scrubber
	var/reagents_amount = 50
	/// Probability of an individual scrubber overflowing
	var/overflow_probability = 50
	/// Specific reagent to force all scrubbers to use, null for random reagent choice (admin VV only. The TG admin_setup datum was not ported)
	var/datum/reagent/forced_reagent_type
	/// A list of scrubbers that will have reagents ejected from them
	var/list/scrubbers = list()
	/// The list of chems that scrubbers can produce
	var/list/safer_chems = list(/datum/reagent/water,
		/datum/reagent/carbon,
		/datum/reagent/consumable/flour,
		/datum/reagent/space_cleaner,
		/datum/reagent/carpet/royal/blue,
		/datum/reagent/carpet/orange,
		/datum/reagent/consumable/nutriment,
		/datum/reagent/consumable/condensedcapsaicin,
		/datum/reagent/drug/mushroomhallucinogen,
		/datum/reagent/lube,
		/datum/reagent/cryptobiolin,
		/datum/reagent/blood,
		/datum/reagent/medicine/c2/multiver,
		/datum/reagent/water/holywater,
		/datum/reagent/consumable/ethanol,
		/datum/reagent/consumable/hot_coco,
		/datum/reagent/consumable/yoghurt,
		/datum/reagent/consumable/tinlux,
		/datum/reagent/hydrogen_peroxide,
		/datum/reagent/bluespace,
		/datum/reagent/pax,
		/datum/reagent/consumable/laughter,
		/datum/reagent/concentrated_barbers_aid,
		/datum/reagent/baldium,
		/datum/reagent/colorful_reagent,
		/datum/reagent/consumable/salt,
		/datum/reagent/consumable/ethanol/beer,
		/datum/reagent/hair_dye,
		/datum/reagent/consumable/sugar,
		/datum/reagent/glitter/random,
		/datum/reagent/gravitum,
		/datum/reagent/growthserum,
		/datum/reagent/yuck,
	)

/// Picks the reagent each scrubber spews: a safe chem from the list above, or any random reagent when dangerous.
/datum/round_event/voidcrew/scrubber_overflow/proc/get_overflowing_reagent(dangerous)
	return dangerous ? get_random_reagent_id() : pick(safer_chems)

/// Builds the victim list from the target ship's unwelded scrubbers; fizzles if none roll in.
/datum/round_event/voidcrew/scrubber_overflow/setup()
	if(!target_valid())
		return kill()
	for(var/obj/machinery/atmospherics/components/unary/vent_scrubber/scrubber as anything in target_ship.get_ship_machines(/obj/machinery/atmospherics/components/unary/vent_scrubber))
		if(scrubber.welded)
			continue
		if(!prob(overflow_probability))
			continue
		scrubbers += scrubber
	if(!length(scrubbers))
		return kill()

/datum/round_event/voidcrew/scrubber_overflow/announce(fake)
	if(!target_valid())
		return
	target_ship.ship_event_announce("A backpressure surge is building in the vessel's scrubber network. Some ejection of contents may occur.", "Ventilation Alert")

/datum/round_event/voidcrew/scrubber_overflow/start()
	if(!target_valid())
		return
	for(var/obj/machinery/atmospherics/components/unary/vent_scrubber/scrubber as anything in scrubbers)
		// Scrubbers can be destroyed, deconstructed or left behind between selection and firing
		if(QDELETED(scrubber) || !target_ship.is_aboard(scrubber))
			continue
		var/turf/scrubber_turf = get_turf(scrubber)
		if(!scrubber_turf)
			continue
		var/datum/reagents/dispensed_reagent = new /datum/reagents(reagents_amount)
		dispensed_reagent.my_atom = scrubber
		if(forced_reagent_type)
			dispensed_reagent.add_reagent(forced_reagent_type, reagents_amount)
		else if(prob(danger_chance))
			dispensed_reagent.add_reagent(get_overflowing_reagent(dangerous = TRUE), reagents_amount)
			new /mob/living/basic/cockroach(scrubber_turf)
			new /mob/living/basic/cockroach/bloodroach(scrubber_turf)
		else
			dispensed_reagent.add_reagent(get_overflowing_reagent(dangerous = FALSE), reagents_amount)
		dispensed_reagent.create_foam(/datum/effect_system/fluid_spread/foam/short, reagents_amount)
		CHECK_TICK

/datum/round_event/voidcrew/scrubber_overflow/threatening
	danger_chance = 10
	reagents_amount = 100

/datum/round_event/voidcrew/scrubber_overflow/catastrophic
	danger_chance = 30
	reagents_amount = 150

/**
 * Admin-only variant, as upstream: every unwelded scrubber aboard goes off at once
 * instead of half of them. Weight and occurrence cap are zero so it stays out of the
 * random roster and only fires from the Trigger Event panel.
 */
/datum/round_event_control/voidcrew/scrubber_overflow/every_vent
	name = "Scrubber Overflow: Every Vent"
	typepath = /datum/round_event/voidcrew/scrubber_overflow/every_vent
	weight = 0
	max_occurrences = 0
	min_ship_mass = SHIP_MASS_MEDIUM
	description = "The scrubbers release a tide of mostly harmless froth, but every scrubber aboard is affected."

/datum/round_event/voidcrew/scrubber_overflow/every_vent
	overflow_probability = 100
	reagents_amount = 100
