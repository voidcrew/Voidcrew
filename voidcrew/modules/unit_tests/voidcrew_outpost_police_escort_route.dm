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
 * An officer at map-local `from` holding a cuffed, searched suspect on `held_at`, carrying evidence, walks them in
 * with its own brain. `crowd`: the outpost's own people are about, and a second officer covers the arrest.
 * Returns list(tiles walked, the steps in local coordinates with what the walk was doing, the case's step at the end).
 */
/datum/unit_test/voidcrew_outpost_police_escort_route/proc/walk_in(obj/structure/overmap/trader_outpost/outpost, list/from, list/held_at, crit = FALSE, crowd = FALSE, limit = 60 SECONDS)
	var/datum/outpost_police/police = outpost.police
	var/datum/ambient_place/outpost/place = SSambient_npcs.outpost_place(outpost)
	var/turf/start = local(outpost, from[1], from[2])
	var/turf/behind = local(outpost, held_at[1], held_at[2])
	var/mob/living/carbon/human/npc/ambient_npc/outpost/police/officer = police_officer(outpost, /mob/living/carbon/human/npc/ambient_npc/outpost/police/beat, start)
	police_arrest_kit(officer)
	var/mob/living/carbon/human/suspect = police_arrest_person(behind)
	listed_z = start.z
	SSmobs.clients_by_zlevel[listed_z] |= suspect
	var/datum/outpost_warrant/warrant = police_pin_warrant(police, suspect.mind, 12)
	var/datum/outpost_police_case/case = police.open_case(warrant)
	police.sleep_tick()
	if(!case || case.arresting() != officer)
		TEST_FAIL("Fixture: no arrest by the officer at [local_text(outpost, start)] ([case?.arresting()])")
		return null
	if(crowd)
		var/mob/living/carbon/human/npc/ambient_npc/outpost/police/second = police_officer(outpost, /mob/living/carbon/human/npc/ambient_npc/outpost/police/beat, police_arrest_beside(suspect))
		police_arrest_kit(second)
		case.staff()
	var/obj/item/restraints/handcuffs/cuffs = allocate(/obj/item/restraints/handcuffs/outpost_police/used)
	suspect.equip_to_slot(cuffs, ITEM_SLOT_HANDCUFFED)
	case.cuffs_on(suspect)
	case.searched = TRUE
	var/obj/item/outpost_sealed_case/evidence/box = allocate(/obj/item/outpost_sealed_case/evidence)
	officer.put_in_hands(box)
	case.evidence_ref = WEAKREF(box)
	police_evidence_locker(outpost)
	if(crit)
		suspect.adjustBruteLoss(110)
		suspect.updatehealth()
	officer.start_pulling(suspect)
	case.set_step("escort")
	SSambient_npcs.wake_outpost(place)
	var/datum/ai_controller/brain = officer.ai_controller
	brain.reset_ai_status()

	var/list/steps = list(local_text(outpost, start))
	var/turf/last = start
	var/turf/last_avoid
	var/turf/last_target
	var/was_loose = FALSE
	var/walked = 0
	var/end = world.time + limit
	var/next_tick = world.time
	while(world.time < end && !QDELETED(case) && case.step == "escort")
		if(world.time >= next_tick)
			next_tick = world.time + 1 SECONDS
			if(crowd)
				SSambient_npcs.update_outpost(place, 1)
				for(var/mob/living/carbon/human/npc/ambient_npc/npc as anything in place.npcs)
					npc.ai_controller?.reset_ai_status()
			case.process_case()
		sleep(world.tick_lag)
		var/turf/here = get_turf(officer)
		var/datum/move_loop/has_target/jps/loop = GLOB.move_manager.processing_on(officer, SSai_movement)
		if(istype(loop) && loop.avoid != last_avoid)
			last_avoid = loop.avoid
			steps += "AVOID[local_text(outpost, last_avoid)]"
		if(istype(loop) && get_turf(loop.target) != last_target)
			last_target = get_turf(loop.target)
			steps += "TO[local_text(outpost, last_target)]"
		var/loose = officer.pulling != suspect
		if(loose != was_loose)
			steps += loose ? "LOOSE" : "HELD"
			was_loose = loose
		if(here != last)
			walked++
			steps += local_text(outpost, here)
			last = here
	var/end_step = QDELETED(case) ? "closed" : case.step
	police.close_case(suspect.mind)
	officer.stop_pulling()
	return list(walked, steps, end_step)

/**
 * Quartermain, the owner's arrest (round 2026-11-24 19:40): the officer took a prisoner from beside the crate stacks
 * at (19,15) to the desk at (16,3). The short way is down past the crates and through the exit gate at (15,12), about
 * fifteen tiles; the officer went right, up and round the balcony and down into the jail instead.
 */
/datum/unit_test/voidcrew_outpost_police_escort_route/Run()
	var/obj/structure/overmap/trader_outpost/outpost = police_loaded_outpost(/obj/structure/overmap/trader_outpost/outfitter)
	if(!outpost)
		return
	var/datum/ambient_place/outpost/place = SSambient_npcs.outpost_place(outpost)
	outpost.police.perception.test_plain = FALSE
	for(var/pass in 1 to 30)
		if(!SSambient_npcs.update_outpost(place, 0, null, 40))
			break
	for(var/trial in 1 to 3)
		var/list/result = walk_in(outpost, list(19, 15), list(19, 16), TRUE, TRUE)
		if(!result)
			return
		var/list/steps = result[2]
		TEST_FAIL("Quartermain crowd trial [trial]: [result[1]] tiles, ended on [result[3]]: [steps.Join(" ")]")
