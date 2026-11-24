/**
 * Outpost police tests: the walk in after a gunfight (police_arrest.dm step_escort(), police_stealth.dm). Quartermain,
 * round 2026-11-24 19:44: the owner shot four officers on the concourse and went down beside the crates at (19,15).
 * The desk sergeant came out through the checkpoint, cuffed them and took 40 seconds over a walk of 15 tiles: right,
 * up round the balcony past the fallen, and back down to the jail. Here the same, on the real map, with the police's
 * own tick and the sergeant's own brain.
 *
 * Fork defines are included after the tests, so values are written out: 104 heat is five stars and more.
 */

/datum/unit_test/voidcrew_outpost_police_escort_detour
	/// The level put on SSmobs' list of players so tg's AI runs there
	var/listed_z

/datum/unit_test/voidcrew_outpost_police_escort_detour/Destroy()
	if(listed_z)
		SSmobs.clients_by_zlevel[listed_z] = list()
	return ..()

/// The tile at map-local (lx, ly) of `outpost` (1-based, as the .dmm counts them)
/datum/unit_test/voidcrew_outpost_police_escort_detour/proc/local(obj/structure/overmap/trader_outpost/outpost, lx, ly)
	var/turf/corner = outpost.template_bottom_left
	return locate(corner.x + lx - 1, corner.y + ly - 1, corner.z)

/// "(x,y)" in map-local coordinates
/datum/unit_test/voidcrew_outpost_police_escort_detour/proc/local_text(obj/structure/overmap/trader_outpost/outpost, turf/tile)
	var/turf/corner = outpost.template_bottom_left
	if(!tile)
		return "(nowhere)"
	return "([tile.x - corner.x + 1],[tile.y - corner.y + 1])"

/// A beat officer at map-local (lx, ly), or on the nearest free floor there, put down: dead or in crit
/datum/unit_test/voidcrew_outpost_police_escort_detour/proc/fallen_officer(obj/structure/overmap/trader_outpost/outpost, lx, ly, dead)
	var/turf/spot = local(outpost, lx, ly)
	if(spot?.is_blocked_turf(TRUE))
		spot = police_arrest_beside(spot)
	if(!spot)
		TEST_FAIL("Fixture: no floor for a fallen officer at ([lx],[ly])")
		return null
	var/mob/living/carbon/human/npc/ambient_npc/outpost/police/officer = police_officer(outpost, /mob/living/carbon/human/npc/ambient_npc/outpost/police/beat, spot)
	if(dead)
		officer.death()
	else
		officer.adjustBruteLoss(160)
		officer.updatehealth()
	return officer

/**
 * The owner's arrest: the fallen where they lay, a suspect at five stars down in soft crit at (19,15) with the gun
 * they used, and the desk sergeant sent. Returns list(tiles walked from the cuffs to the evidence locker, the trace,
 * the case's step at the end, the shortest way there).
 */
/datum/unit_test/voidcrew_outpost_police_escort_detour/proc/after_the_fight(obj/structure/overmap/trader_outpost/outpost, limit = 150 SECONDS)
	var/datum/outpost_police/police = outpost.police
	var/datum/ambient_place/outpost/place = SSambient_npcs.outpost_place(outpost)
	// The fallen: three gasping and dead at the top of the right stairs, the rest on the left of the concourse
	fallen_officer(outpost, 31, 29, TRUE)
	fallen_officer(outpost, 31, 30, FALSE)
	fallen_officer(outpost, 31, 31, FALSE)
	fallen_officer(outpost, 17, 21, FALSE)
	fallen_officer(outpost, 15, 19, TRUE)
	fallen_officer(outpost, 16, 19, TRUE)
	// The beat officers still up are out on the concourse fighting: the desk sergeant is the one who comes
	var/mob/living/carbon/human/npc/ambient_npc/outpost/police/sergeant
	for(var/mob/living/carbon/human/npc/ambient_npc/outpost/police/someone in police.officers.Copy())
		if(someone.stat != CONSCIOUS)
			continue
		if(someone.unit_kind == "sergeant" && !sergeant)
			sergeant = someone
			continue
		qdel(someone)
	if(!sergeant)
		sergeant = police_officer(outpost, /mob/living/carbon/human/npc/ambient_npc/outpost/police/sergeant, police.desk_turf)
	var/turf/spot = local(outpost, 19, 15)
	var/mob/living/carbon/human/suspect = police_arrest_person(spot)
	listed_z = spot.z
	SSmobs.clients_by_zlevel[listed_z] |= suspect
	var/obj/item/gun/ballistic/automatic/pistol/gun = allocate(/obj/item/gun/ballistic/automatic/pistol)
	suspect.put_in_hands(gun)
	suspect.adjustBruteLoss(110)
	suspect.updatehealth()
	var/datum/outpost_warrant/warrant = police_pin_warrant(police, suspect.mind, 104)
	LAZYADD(warrant.evidence, WEAKREF(gun))
	police.note_seen(suspect.mind, spot)
	var/datum/outpost_police_case/case = police.open_case(warrant, TRUE)
	var/mob/living/carbon/human/npc/ambient_npc/outpost/police/officer = case?.arresting()
	if(!officer)
		TEST_FAIL("Fixture: no arrest opened")
		return null
	if(officer != sergeant)
		TEST_FAIL("Fixture: the arrest went to [officer] ([officer.unit_kind]), not the desk sergeant")
		return null
	police_arrest_kit(officer)
	police_evidence_locker(outpost)
	SSambient_npcs.wake_outpost(place)
	officer.ai_controller.reset_ai_status()
	// The police's own tick runs the case once a second, as it does in a round
	police.wake()
	// The owner had emagged the lobby scanner: the gate was down through the walk in
	for(var/checkpoint_id in outpost.checkpoints)
		var/datum/outpost_checkpoint/post = outpost.checkpoints[checkpoint_id]
		post.disable(null, null)
	var/started = world.time
	var/list/steps = list("[officer.unit_kind] [case.step]@[local_text(outpost, get_turf(officer))]")
	var/turf/last = get_turf(officer)
	var/turf/last_target
	var/last_step = case.step
	var/last_state
	var/walked = 0
	var/shortest = 0
	var/counting = FALSE
	var/end = world.time + limit
	var/next_tick = world.time
	while(world.time < end && !QDELETED(case) && case.step != "book")
		if(world.time >= next_tick)
			next_tick = world.time + 1 SECONDS
			SSambient_npcs.update_outpost(place, 1)
			for(var/mob/living/carbon/human/npc/ambient_npc/npc as anything in place.npcs)
				npc.ai_controller?.reset_ai_status()
		sleep(world.tick_lag)
		if(QDELETED(case))
			steps += "CLOSED: suspect stat [suspect.stat] crit [HAS_TRAIT(suspect, TRAIT_CRITICAL_CONDITION)] cuffed [!!suspect.handcuffed] stars [police.get_stars(suspect.mind)] warrant [!!police.get_warrant(suspect.mind)] force [police.force_level(suspect, officer)] at [local_text(outpost, get_turf(suspect))]"
			break
		if(case.arresting() != officer)
			steps += "OFFICER-CHANGED"
			break
		var/datum/ai_controller/basic_controller/human_npc/stealth/brain = officer.ai_controller
		var/state = istype(brain) ? brain.stealth_state() : null
		if(state != last_state)
			last_state = state
			steps += "STATE:[state]"
		if(case.step != last_step)
			last_step = case.step
			steps += "STEP:[case.step]@[round((world.time - started) / 10)]s"
			if(case.step == "escort" && !counting)
				counting = TRUE
				var/list/short_way = get_path_to(officer, police.get_evidence_locker(), 120, 1, officer.ai_controller.get_access())
				shortest = length(short_way)
				steps += "SHORTEST:[shortest]"
		var/turf/here = get_turf(officer)
		var/datum/move_loop/has_target/loop = GLOB.move_manager.processing_on(officer, SSai_movement)
		if(istype(loop) && get_turf(loop.target) != last_target)
			last_target = get_turf(loop.target)
			steps += "TO[local_text(outpost, last_target)]"
		if(here != last)
			if(counting && (case.step == "escort" || case.step == "desk"))
				walked++
			steps += local_text(outpost, here)
			last = here
	steps += "END@[round((world.time - started) / 10)]s"
	var/end_step = QDELETED(case) ? "closed" : case.step
	police.close_case(suspect.mind)
	officer.stop_pulling()
	return list(walked, steps, end_step, shortest)

/**
 * Walked in after a gunfight with colleagues down in sight, the escort still takes the short way to the desk: it does
 * not go round past the fallen with the prisoner in tow.
 */
/datum/unit_test/voidcrew_outpost_police_escort_detour/Run()
	var/obj/structure/overmap/trader_outpost/outpost = police_loaded_outpost(/obj/structure/overmap/trader_outpost/outfitter)
	if(!outpost)
		return
	var/datum/ambient_place/outpost/place = SSambient_npcs.outpost_place(outpost)
	outpost.police.perception.test_plain = FALSE
	for(var/pass in 1 to 30)
		if(!SSambient_npcs.update_outpost(place, 0, null, 40))
			break
	var/list/result = after_the_fight(outpost)
	if(!result)
		return
	var/list/steps = result[2]
	var/walked = result[1]
	var/shortest = result[4]
	if(result[3] != "book" || !shortest || walked > shortest + 6)
		TEST_FAIL("Quartermain after the fight: walked [walked] tiles to the evidence for a shortest way of [shortest], ended on [result[3]]: [steps.Join(" ")]")
