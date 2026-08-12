/**
 * Ritual: Bodysnatch: ship-scoped port of TG's Change Places! (code/modules/events/wizard/shuffle.dm).
 *
 * Everyone aboard is picked up and put down somewhere else aboard, at random, at once.
 *
 * TG's shuffleloc gathers `/mob/living/carbon/human` out of GLOB.alive_mob_list, filters on
 * `is_station_level(H.z)` with the comment "lets not try to strand people in space", and
 * teleports each into another victim's `loc`. In this fork that filter passes for any
 * z-level a ship currently occupies, which means the shared transit level, a galaxy-wide
 * shuffle that would swap crews between hulls, dump people into vacuum, and teleport
 * shoppers out of a trader outpost. That is not a scarier version of the event, it is a
 * different and much worse event.
 *
 * Changed from the original:
 * - The victim pool and the destination pool are both the target ship's own crew, resolved
 *   through shuttle areas. Nobody leaves the hull; the shuffle is genuinely internal.
 * - Destinations are get_turf() of each victim rather than their raw `loc`. TG's version can
 *   deposit somebody inside a closet or a mech another crewmember happened to be in;
 *   turf-level destinations keep the outcome legible and stop the event from stuffing two
 *   people into one container.
 * - Every destination is re-validated with is_aboard() immediately before its teleport. The
 *   list is built and consumed inside one start() call, but do_teleport() can sleep, and a
 *   shuttle that starts moving mid-shuffle would otherwise scatter the rest of the crew onto
 *   whatever now sits at those coordinates.
 * - The two sibling controls in TG's file are NOT ported. Change Faces (shuffle real_names)
 *   is a Face/Off gag with no necromantic reading, and Change Minds is mass mindswap, a
 *   round-warping effect that would collide badly with track C's thrall mechanic, and that
 *   sticks to a player in a way the roster no longer allows (see lich_events.dm).
 *
 * This rite itself is a one-shot shuffle and nothing else: it moves people, they walk back.
 * Nothing about them is changed and there is nothing to undo.
 */
/datum/round_event_control/voidcrew/lich/bodysnatch
	name = "Ritual: Bodysnatch"
	typepath = /datum/round_event/voidcrew/lich/bodysnatch
	description = "Shuffles everyone aboard the target ship between each other's positions."
	max_occurrences = 3
	event_scope = EVENT_SCOPE_SHIP
	min_crew_aboard = 2 // A shuffle of one person is not a shuffle.
	min_wizard_trigger_potency = 2
	max_wizard_trigger_potency = 5

/datum/round_event/voidcrew/lich/bodysnatch
	announce_when = 1

/datum/round_event/voidcrew/lich/bodysnatch/announce(fake)
	lich_announce_ship(
		"You have grown attached to standing where you stand. That is a habit, and habits \
		are for the living. Hold still, or don't. It makes no difference.",
		"Bodysnatch",
		'sound/effects/magic/blink.ogg',
	)

/datum/round_event/voidcrew/lich/bodysnatch/start()
	if(!target_valid())
		return

	var/list/mob/living/carbon/human/victims = list()
	var/list/turf/destinations = list()
	for(var/mob/living/aboard_mob as anything in target_ship.get_all_mobs_aboard())
		if(!ishuman(aboard_mob) || QDELETED(aboard_mob))
			continue
		var/turf/mob_turf = get_turf(aboard_mob)
		if(!mob_turf || !target_ship.is_aboard(mob_turf))
			continue
		victims += aboard_mob
		destinations += mob_turf

	if(length(victims) < 2)
		return

	shuffle_inplace(victims)
	shuffle_inplace(destinations)

	for(var/mob/living/carbon/human/victim as anything in victims)
		if(!length(destinations))
			break // Positions are not always unique, same as the original.
		var/turf/destination = destinations[length(destinations)]
		destinations.len -= 1
		if(QDELETED(victim))
			continue
		// do_teleport() can sleep; the ship may have moved out from under this turf since
		// the list was built, so the claim is re-checked per victim.
		if(!destination || !target_ship.is_aboard(destination))
			continue
		do_teleport(victim, destination, channel = TELEPORT_CHANNEL_MAGIC)

	// The original's parting smoke puff, on the people who actually got moved.
	for(var/mob/living/carbon/human/victim as anything in victims)
		if(QDELETED(victim))
			continue
		do_smoke(0, holder = victim, location = get_turf(victim))
		to_chat(victim, span_hypnophrase("Cold green hands take you by the shoulders and set you down somewhere else."))
