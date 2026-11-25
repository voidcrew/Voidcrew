/**
 * Outpost police tests: walking a prisoner in down a hall one tile wide with someone standing in it (police_arrest.dm
 * make_way(), police_movement.dm). Quartermain's stock-room hall, the tiles (18..21, 16) from the outpost's corner, has
 * crates below and the railing above: the soak's escorts stood behind the case's own cover officer there, and behind a
 * townsperson, for 15 s and more on the walk to the evidence locker (pass 12, shove_officers, jailed_shove_walk_out).
 * Here the same, on the real map, with the officers' own brains and the case run once a second as the police's tick runs it.
 *
 * Fork defines are included after the tests, so values are written out: 12 heat is one star; steps "desk".
 */

/datum/unit_test/voidcrew_outpost_police_escort_hall
	/// The level put on SSmobs' list of players so tg's AI runs there
	var/listed_z

/datum/unit_test/voidcrew_outpost_police_escort_hall/Destroy()
	if(listed_z)
		SSmobs.clients_by_zlevel[listed_z] = list()
	return ..()

/// The tile (x, y) from `outpost`'s corner, as the soak counts them
/datum/unit_test/voidcrew_outpost_police_escort_hall/proc/box(obj/structure/overmap/trader_outpost/outpost, x, y)
	var/turf/corner = outpost.template_bottom_left
	return locate(corner.x + x, corner.y + y, corner.z)

/// "x,y" from `outpost`'s corner
/datum/unit_test/voidcrew_outpost_police_escort_hall/proc/box_text(obj/structure/overmap/trader_outpost/outpost, atom/thing)
	var/turf/corner = outpost.template_bottom_left
	var/turf/tile = get_turf(thing)
	if(!tile)
		return "-"
	return "[tile.x - corner.x],[tile.y - corner.y]"

/**
 * The walk: the arresting officer and its prisoner in cuffs at `officer_at` and `suspect_at`, `blocker` (made by the
 * caller) standing where it stands. Returns null when the escort got clear of the hall toward the locker within
 * `limit`, else what it saw each second.
 */
/datum/unit_test/voidcrew_outpost_police_escort_hall/proc/walk_past(obj/structure/overmap/trader_outpost/outpost, mob/living/carbon/human/npc/ambient_npc/outpost/police/officer, mob/living/carbon/human/suspect, mob/living/blocker, limit = 20 SECONDS)
	var/datum/outpost_police/police = outpost.police
	var/datum/outpost_warrant/warrant = police_pin_warrant(police, suspect.mind, 12) // one star
	var/datum/outpost_police_case/case = police.open_case(warrant)
	police.sleep_tick()
	if(!case)
		TEST_FAIL("Fixture: no arrest opened")
		return null
	if(case.arresting() != officer)
		TEST_FAIL("Fixture: the arrest went to [case.arresting()], not the officer beside the suspect")
		return null
	police_arrest_kit(officer)
	var/obj/item/restraints/handcuffs/cuffs = allocate(/obj/item/restraints/handcuffs/outpost_police/used)
	suspect.equip_to_slot(cuffs, ITEM_SLOT_HANDCUFFED)
	case.cuffs_on(suspect)
	case.searched = TRUE
	// Something taken off them on the search: the walk goes to the evidence locker first
	var/obj/item/outpost_sealed_case/evidence/sealed = allocate(/obj/item/outpost_sealed_case/evidence)
	sealed.forceMove(officer)
	var/atom/locker = police_evidence_locker(outpost)
	officer.start_pulling(suspect)
	if(officer.pulling != suspect)
		TEST_FAIL("Fixture: the officer did not take hold of the prisoner")
		return null
	case.set_step("desk")
	listed_z = officer.z
	SSmobs.clients_by_zlevel[listed_z] |= suspect
	for(var/mob/living/someone in list(officer, blocker, case.cover()))
		someone.ai_controller?.reset_ai_status()
	var/list/seen = list()
	var/turf/start = get_turf(officer)
	var/start_dist = get_dist(start, locker)
	var/end = world.time + limit
	var/next_tick = world.time
	while(world.time < end)
		if(world.time >= next_tick)
			next_tick = world.time + 1 SECONDS
			if(QDELETED(case))
				seen += "case closed"
				break
			case.process_case()
			for(var/mob/living/someone in list(officer, blocker, case.cover()))
				someone.ai_controller?.reset_ai_status()
			var/datum/move_loop/has_target/jps/loop = GLOB.move_manager.processing_on(officer, SSai_movement)
			var/next_step = (istype(loop) && length(loop.movement_path)) ? box_text(outpost, loop.movement_path[1]) : "none"
			seen += "[round((world.time - (end - limit)) / 10)]s officer [box_text(outpost, officer)] dir [dir2text(officer.dir)] step [case.step] next [next_step] bumped [officer.bump_blocker?.resolve() == blocker ? "it" : "[officer.bump_blocker?.resolve()]"]; prisoner [box_text(outpost, suspect)]; in the way [box_text(outpost, blocker)] can move [outpost_npc_can_make_room(blocker)]"
		sleep(world.tick_lag)
		// Out of the hall and on toward the locker
		if(get_dist(officer, locker) <= start_dist - 3)
			police.close_case(suspect.mind)
			officer.stop_pulling()
			return null
	police.close_case(suspect.mind)
	officer.stop_pulling()
	return seen

/// Everyone else on the police roster and among the townspeople is taken off, so only the test's people are about
/datum/unit_test/voidcrew_outpost_police_escort_hall/proc/clear_outpost(obj/structure/overmap/trader_outpost/outpost)
	for(var/mob/living/carbon/human/npc/ambient_npc/outpost/police/someone in outpost.police.officers.Copy())
		qdel(someone)
	var/datum/ambient_place/outpost/place = SSambient_npcs.outpost_place(outpost)
	for(var/mob/living/carbon/human/npc/ambient_npc/npc as anything in (place ? place.npcs.Copy() : list()))
		qdel(npc)

/**
 * The case's own cover officer standing idle in the hall, one step ahead of the escort, the prisoner on the escort's
 * own tile (they were cuffed lying under it): the escort gets past and on to the locker.
 */
/datum/unit_test/voidcrew_outpost_police_escort_hall/Run()
	var/obj/structure/overmap/trader_outpost/outpost = police_loaded_outpost(/obj/structure/overmap/trader_outpost/outfitter)
	if(!outpost)
		return
	outpost.police.perception.test_plain = FALSE
	clear_outpost(outpost)

	// shove_officers: the cover in the hall at 19,16, the escort and its prisoner both on 20,16
	var/mob/living/carbon/human/npc/ambient_npc/outpost/police/escort = police_officer(outpost, /mob/living/carbon/human/npc/ambient_npc/outpost/police/beat, box(outpost, 20, 16))
	var/mob/living/carbon/human/npc/ambient_npc/outpost/police/cover = police_officer(outpost, /mob/living/carbon/human/npc/ambient_npc/outpost/police/beat, box(outpost, 19, 16))
	var/mob/living/carbon/human/prisoner = police_arrest_person(box(outpost, 20, 16))
	escort.setDir(NORTH)
	var/list/seen = walk_past(outpost, escort, prisoner, cover)
	if(seen)
		TEST_FAIL("Quartermain hall: the escort stood behind its cover officer: [seen.Join(" | ")]")
	qdel(prisoner)
	qdel(escort)
	qdel(cover)

	// jailed_shove_walk_out: a townsperson in the hall at 20,16, the escort at 21,16, its prisoner on the diagonal at 22,15
	escort = police_officer(outpost, /mob/living/carbon/human/npc/ambient_npc/outpost/police/beat, box(outpost, 21, 16))
	cover = police_officer(outpost, /mob/living/carbon/human/npc/ambient_npc/outpost/police/beat, box(outpost, 22, 14))
	prisoner = police_arrest_person(box(outpost, 22, 15))
	var/mob/living/carbon/human/npc/ambient_npc/outpost/local = allocate(/mob/living/carbon/human/npc/ambient_npc/outpost, box(outpost, 20, 16))
	local.set_place(SSambient_npcs.outpost_place(outpost))
	escort.setDir(EAST)
	seen = walk_past(outpost, escort, prisoner, local)
	if(seen)
		TEST_FAIL("Quartermain hall: the escort stood behind a townsperson: [seen.Join(" | ")]")
