/**
 * Ritual: Unquiet Menagerie: ship-scoped port of TG's Petsplosion
 * (code/modules/events/wizard/petsplosion.dm).
 *
 * The ship's animals start budding copies of themselves. His reanimation magic is not
 * precise; pointed at a living thing it makes more living things, badly.
 *
 * The TG original counts candidates with `is_station_level(dupe_animal.z)`, walks
 * GLOB.alive_mob_list twice per wave, and doubles the population every 30 seconds until it
 * has made 400 mobs. Every part of that is wrong here. The z check would sweep in every
 * animal on a shared transit level, other crews' pets, a trader outpost's livestock, a
 * ruin's fauna, and 400 mobs would be a server incident on a ship with six rooms.
 *
 * Changed from the original:
 * - Candidates come from target_ship.get_all_mobs_aboard(), never from a z-level scan.
 *   Every duplicate is re-validated with is_aboard() at the moment it is made, so an animal
 *   that wandered off the ship between waves stops multiplying.
 * - Hard cap of 20 duplicates total instead of TG's 400, and three waves instead of an
 *   open-ended doubling. Culling the herd between waves still slows it down, exactly as in
 *   the original, that is the counterplay and it is preserved.
 * - The candidate ceiling (TG refuses to run above 100 dupable mobs) is kept as a per-ship
 *   check in is_valid_target(): a ship already crawling with animals is skipped.
 * - Reuses upstream's GLOB.petsplosion_candidates typecache so the eligible-pet list stays
 *   in sync with TG's rather than drifting into a second copy.
 */
/datum/round_event_control/voidcrew/lich/unquiet_menagerie
	name = "Ritual: Unquiet Menagerie"
	typepath = /datum/round_event/voidcrew/lich/unquiet_menagerie
	description = "The animals aboard the target ship multiply in waves."
	max_occurrences = 1
	event_scope = EVENT_SCOPE_SHIP
	min_wizard_trigger_potency = 1
	max_wizard_trigger_potency = 4

/// Needs pets aboard, and not so many that the ship is already a barn.
/datum/round_event_control/voidcrew/lich/unquiet_menagerie/is_valid_target(obj/structure/overmap/ship/ship)
	. = ..()
	if(!.)
		return FALSE
	var/candidates = 0
	for(var/mob/living/aboard_mob as anything in ship.get_all_mobs_aboard())
		if(is_type_in_typecache(aboard_mob, GLOB.petsplosion_candidates))
			candidates++
	return candidates > 0 && candidates <= 20

/datum/round_event/voidcrew/lich/unquiet_menagerie
	announce_when = 1
	end_when = 33
	/// Total duplicates this event may create, ever. TG allows 400; a ship gets 20.
	var/dupe_cap = 20
	/// How many have been made so far.
	var/duped = 0
	/// Waves left to run.
	var/waves_remaining = 3
	/// Event tick the next wave fires on.
	var/next_wave = 0

/datum/round_event/voidcrew/lich/unquiet_menagerie/start()
	if(!target_valid())
		return
	next_wave = activeFor + 2

/datum/round_event/voidcrew/lich/unquiet_menagerie/announce(fake)
	lich_announce_ship(
		"I reached for your dead and found only pets. Fine. A living thing is a pattern, \
		and a pattern can be copied, and copied, and copied. \
		Cull them if it makes you feel better.",
		"Unquiet Menagerie",
	)

/datum/round_event/voidcrew/lich/unquiet_menagerie/tick()
	if(!target_valid())
		return
	if(!waves_remaining || duped >= dupe_cap)
		end_when = activeFor
		return
	if(activeFor < next_wave)
		return
	run_wave()
	waves_remaining--
	next_wave += 10

/// Duplicates every eligible animal currently aboard, up to the remaining cap.
/datum/round_event/voidcrew/lich/unquiet_menagerie/proc/run_wave()
	if(!target_valid())
		return
	for(var/mob/living/parent_animal as anything in target_ship.get_all_mobs_aboard())
		if(duped >= dupe_cap)
			return
		if(QDELETED(parent_animal))
			continue
		if(!is_type_in_typecache(parent_animal, GLOB.petsplosion_candidates))
			continue
		// Re-checked per animal per wave: it may have been carried off the ship since.
		if(!target_ship.is_aboard(parent_animal))
			continue
		var/turf/spawn_turf = get_turf(parent_animal)
		if(!spawn_turf || !target_ship.is_aboard(spawn_turf))
			continue
		new parent_animal.type(spawn_turf)
		duped++
