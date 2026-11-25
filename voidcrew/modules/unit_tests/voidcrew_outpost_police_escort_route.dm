/**
 * Outpost police tests: the way an officer walks a cuffed prisoner to the desk (police_arrest.dm step_escort(),
 * route_to()). On the real maps, with the officer's own brain doing the walking.
 *
 * Fork defines are included after the tests, so values are written out: step "escort", one star is 12 heat.
 */

/datum/unit_test/voidcrew_outpost_police_escort_route
	/// The level put on SSmobs' list of players so tg's AI runs there
	var/listed_z

/datum/unit_test/voidcrew_outpost_police_escort_route/Destroy()
	if(listed_z)
		SSmobs.clients_by_zlevel[listed_z] = list()
	return ..()

/// The tile at map-local (lx, ly) of `outpost` (1-based, as the .dmm counts them)
/datum/unit_test/voidcrew_outpost_police_escort_route/proc/local(obj/structure/overmap/trader_outpost/outpost, lx, ly)
	var/turf/corner = outpost.template_bottom_left
	return locate(corner.x + lx - 1, corner.y + ly - 1, corner.z)

/// "(x,y)" in map-local coordinates
/datum/unit_test/voidcrew_outpost_police_escort_route/proc/local_text(obj/structure/overmap/trader_outpost/outpost, turf/tile)
	var/turf/corner = outpost.template_bottom_left
	if(!tile)
		return "(nowhere)"
	return "([tile.x - corner.x + 1],[tile.y - corner.y + 1])"

/**
 * An arrest on a suspect down at map-local `at`, an officer of the beat beside them and the outpost's own people about:
 * the order, the cuffs and the search, then the walk in, all by the police's own code and the officer's own brain.
 * Returns list(tiles walked to the evidence locker, the trace, the case's step at the end, the shortest way there).
 */
/datum/unit_test/voidcrew_outpost_police_escort_route/proc/whole_arrest(obj/structure/overmap/trader_outpost/outpost, list/at, limit = 120 SECONDS)
	var/datum/outpost_police/police = outpost.police
	var/datum/ambient_place/outpost/place = SSambient_npcs.outpost_place(outpost)
	var/turf/spot = local(outpost, at[1], at[2])
	// An officer of the beat beside them: the arrest is theirs, and the walk to the desk starts on the concourse
	var/turf/beside = police_arrest_beside(spot)
	if(!beside)
		TEST_FAIL("Fixture: no floor beside [local_text(outpost, spot)]")
		return null
	police_officer(outpost, /mob/living/carbon/human/npc/ambient_npc/outpost/police/beat, beside)
	var/mob/living/carbon/human/suspect = police_arrest_person(spot)
	listed_z = spot.z
	SSmobs.clients_by_zlevel[listed_z] |= suspect
	suspect.adjustBruteLoss(110)
	suspect.updatehealth()
	var/datum/outpost_warrant/warrant = police_pin_warrant(police, suspect.mind, 12)
	police.note_seen(suspect.mind, spot)
	var/datum/outpost_police_case/case = police.open_case(warrant)
	police.sleep_tick()
	var/mob/living/carbon/human/npc/ambient_npc/outpost/police/officer = case?.arresting()
	if(!officer)
		TEST_FAIL("Fixture: no arrest opened")
		return null
	police_arrest_kit(officer)
	police_evidence_locker(outpost)
	SSambient_npcs.wake_outpost(place)
	officer.ai_controller.reset_ai_status()
	var/started = world.time
	var/list/steps = list("[officer.unit_kind] [case.step]@[local_text(outpost, get_turf(officer))]")
	var/turf/last = get_turf(officer)
	var/turf/last_avoid
	var/turf/last_target
	var/last_step = case.step
	var/walked = 0
	var/shortest = 0
	var/end = world.time + limit
	var/next_tick = world.time
	while(world.time < end && !QDELETED(case) && case.step != "book")
		if(world.time >= next_tick)
			next_tick = world.time + 1 SECONDS
			SSambient_npcs.update_outpost(place, 1)
			for(var/mob/living/carbon/human/npc/ambient_npc/npc as anything in place.npcs)
				npc.ai_controller?.reset_ai_status()
			case.process_case()
		sleep(world.tick_lag)
		if(QDELETED(case))
			break
		if(case.arresting() != officer)
			steps += "OFFICER-CHANGED"
			break
		if(case.step != last_step)
			last_step = case.step
			steps += "STEP:[case.step]@[round((world.time - started) / 10)]s"
			if(case.step == "escort" && !case.evidence_ref)
				var/obj/item/outpost_sealed_case/evidence/box = allocate(/obj/item/outpost_sealed_case/evidence)
				officer.put_in_hands(box)
				case.evidence_ref = WEAKREF(box)
				// In straight steps, as an officer walks someone it holds (police_stealth.dm police_straight_steps())
				var/list/short_way = get_path_to(officer, police.get_evidence_locker(), 120, 1, officer.ai_controller.get_access(), diagonal_handling = DIAGONAL_REMOVE_ALL)
				shortest = length(short_way)
				steps += "SHORTEST:[shortest]"
		var/turf/here = get_turf(officer)
		var/datum/move_loop/has_target/jps/loop = GLOB.move_manager.processing_on(officer, SSai_movement)
		if(istype(loop) && loop.avoid != last_avoid)
			last_avoid = loop.avoid
			steps += "AVOID[local_text(outpost, last_avoid)]"
		if(istype(loop) && get_turf(loop.target) != last_target)
			last_target = get_turf(loop.target)
			steps += "TO[local_text(outpost, last_target)]"
		if(here != last)
			if(case.step == "escort")
				walked++
			steps += local_text(outpost, here)
			last = here
	steps += "END@[round((world.time - started) / 10)]s"
	var/end_step = QDELETED(case) ? "closed" : case.step
	police.close_case(suspect.mind)
	officer.stop_pulling()
	// Out of the way of the next arrest (left at the cell door, they stood in the next escort's way)
	qdel(suspect)
	return list(walked, steps, end_step, shortest)

/**
 * The walk in takes the short way to the desk. Quartermain, the owner's arrest (round 2026-11-24 19:44): a suspect
 * cuffed beside the crate stacks at (19,15) was walked right, up round the balcony and down into the jail, where the
 * short way is down past the crates and through the exit gate at (15,12). The same from other spots on each concourse.
 */
/datum/unit_test/voidcrew_outpost_police_escort_route/Run()
	// Map-local spots on each concourse: the owner's at Quartermain, and the far ends of each
	var/list/spots_by_map = list(
		/obj/structure/overmap/trader_outpost/outfitter = list(list(19, 15), list(29, 15), list(33, 21), list(24, 26)),
		/obj/structure/overmap/trader_outpost/general = list(null, null, null),
		/obj/structure/overmap/trader_outpost/black_market = list(null, null, null),
	)
	for(var/outpost_type in spots_by_map)
		var/obj/structure/overmap/trader_outpost/outpost = police_loaded_outpost(outpost_type)
		if(!outpost)
			continue
		var/datum/ambient_place/outpost/place = SSambient_npcs.outpost_place(outpost)
		outpost.police.perception.test_plain = FALSE
		for(var/pass in 1 to 30)
			if(!SSambient_npcs.update_outpost(place, 0, null, 40))
				break
		for(var/list/spot as anything in spots_by_map[outpost_type])
			var/turf/start = spot ? local(outpost, spot[1], spot[2]) : police_floor(outpost)
			if(start?.is_blocked_turf(TRUE))
				start = police_arrest_beside(start)
			if(!start)
				TEST_FAIL("[outpost_type]: no floor for the suspect at [json_encode(spot)]")
				continue
			var/turf/corner = outpost.template_bottom_left
			var/list/result = whole_arrest(outpost, list(start.x - corner.x + 1, start.y - corner.y + 1))
			if(!result)
				continue
			var/list/steps = result[2]
			var/walked = result[1]
			var/shortest = result[4]
			if(result[3] != "book" || !shortest || walked > shortest + 6)
				TEST_FAIL("[outpost_type] from [local_text(outpost, start)]: walked [walked] tiles to the evidence for a shortest way of [shortest], ended on [result[3]]: [steps.Join(" ")]")
