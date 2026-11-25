/**
 * Outpost police tests: an officer walking someone it holds, on the real maps (police_stealth.dm police_straight_steps(),
 * police_arrest.dm outpost_police_draw_corner_clear()).
 *
 * Fork defines are included after the tests, so values are written out: 12 heat is one star; step "desk".
 * Tiles are counted from the loaded outpost's bottom-left corner, as the soak's trace writes them.
 */

/datum/unit_test/voidcrew_outpost_police_escort_straight
	/// The level put on SSmobs' list of players so tg's AI runs there
	var/listed_z
	/// The officer's diagonal steps while it held its prisoner, as "x,y>x,y"
	var/list/diagonals = list()
	var/mob/living/watched_prisoner
	var/turf/corner

/datum/unit_test/voidcrew_outpost_police_escort_straight/Destroy()
	if(listed_z)
		SSmobs.clients_by_zlevel[listed_z] = list()
	watched_prisoner = null
	return ..()

/datum/unit_test/voidcrew_outpost_police_escort_straight/proc/tile_text(atom/thing)
	var/turf/tile = get_turf(thing)
	return tile ? "[tile.x - corner.x],[tile.y - corner.y]" : "-"

/// Each leg of a diagonal step is a Move of its own; tg marks them as one
/datum/unit_test/voidcrew_outpost_police_escort_straight/proc/on_officer_moved(mob/living/source, atom/old_loc, dir, forced, list/old_locs)
	SIGNAL_HANDLER
	if(source.moving_diagonally && source.pulling == watched_prisoner)
		diagonals += "[tile_text(old_loc)]>[tile_text(source)]"

/**
 * The Undertow's poker tables: the officer at 32,21 with its prisoner in cuffs on the diagonal at 31,22, walking them in
 * to the desk. Its pathfinder went 32,20 to 31,19 on a diagonal, which left the prisoner a diagonal behind at 32,20 with a
 * table on one corner; a townsperson on the other, 32,19, and the next step pulled the officer's hand off them, five
 * times in a row (pass 14 soak, jailbreak_shootout). Holding someone, it walks only straight steps, and keeps hold.
 * And taking hold from a diagonal with someone on the open corner, it first goes round to a straight side.
 */
/datum/unit_test/voidcrew_outpost_police_escort_straight/Run()
	var/obj/structure/overmap/trader_outpost/outpost = police_loaded_outpost(/obj/structure/overmap/trader_outpost/black_market)
	if(!outpost)
		return
	corner = outpost.template_bottom_left
	var/datum/outpost_police/police = outpost.police
	for(var/mob/living/carbon/human/npc/ambient_npc/outpost/police/someone in police.officers.Copy())
		qdel(someone)
	var/datum/ambient_place/outpost/place = SSambient_npcs.outpost_place(outpost)
	for(var/mob/living/carbon/human/npc/ambient_npc/npc as anything in (place ? place.npcs.Copy() : list()))
		qdel(npc)
	TEST_ASSERT(police_outpost_tile(outpost, 31, 20).density || (locate(/obj/structure/table) in police_outpost_tile(outpost, 31, 20)), "Fixture: no poker table at 31,20")

	// Taking hold on the diagonal, 31,19 to 32,20, someone standing on the open corner 32,19 (the table on 31,20)
	var/mob/living/carbon/human/npc/ambient_npc/outpost/police/officer = police_officer(outpost, /mob/living/carbon/human/npc/ambient_npc/outpost/police/beat, police_outpost_tile(outpost, 31, 19))
	var/mob/living/carbon/human/prisoner = police_arrest_person(police_outpost_tile(outpost, 32, 20))
	var/mob/living/carbon/human/bystander = allocate(/mob/living/carbon/human/consistent, police_outpost_tile(outpost, 32, 19))
	var/datum/outpost_police_case/case = police.open_case(police_pin_warrant(police, prisoner.mind, 12)) // one star
	police.sleep_tick()
	TEST_ASSERT_NOTNULL(case, "Fixture: no arrest opened")
	TEST_ASSERT_EQUAL(case.arresting(), officer, "Fixture: the arrest went to someone else")
	police_arrest_kit(officer)
	var/obj/item/restraints/handcuffs/cuffs = allocate(/obj/item/restraints/handcuffs/outpost_police/used)
	prisoner.equip_to_slot(cuffs, ITEM_SLOT_HANDCUFFED)
	case.cuffs_on(prisoner)
	case.searched = TRUE
	officer.start_pulling(prisoner)
	TEST_ASSERT_EQUAL(officer.pulling, prisoner, "Fixture: the officer did not take hold of the prisoner")
	if(case.lead_ready(officer, prisoner))
		TEST_FAIL("The officer would lead its prisoner off the diagonal at 32,20 with someone on the open corner 32,19")
	var/turf/side = case.lead_turf_for(officer, prisoner)
	if(isnull(side))
		TEST_FAIL("No tile to lead the prisoner off from")
	else if(side.x != prisoner.x && side.y != prisoner.y)
		TEST_FAIL("The officer would lead its prisoner off another diagonal, from [tile_text(side)]")
	qdel(bystander)

	// One of the outpost's own people on that corner is asked to step off it, and the officer leads from where it stands
	var/turf/open_corner = police_outpost_tile(outpost, 32, 19)
	var/mob/living/carbon/human/npc/ambient_npc/outpost/local = allocate(/mob/living/carbon/human/npc/ambient_npc/outpost, open_corner)
	local.set_place(place)
	ADD_TRAIT(local, TRAIT_AI_PAUSED, "ambient_paused") // AMBIENT_PAUSED_TRAIT: still moves out of the way
	case.keep_pulling(officer, prisoner, TRUE)
	if(get_turf(local) == open_corner || officer.pulling != prisoner || case.lead_goal)
		TEST_FAIL("A townsperson on the open corner was not asked off it (they are at [tile_text(local)], the officer [officer.pulling == prisoner ? "holds" : "let go of"] the prisoner[case.lead_goal ? ", going round to [tile_text(case.lead_goal)]" : ""])")
	qdel(local)

	// A colleague holding its prisoner for it (while it goes round): it does not step aside for them
	var/mob/living/carbon/human/npc/ambient_npc/outpost/police/holder = police_officer(outpost, /mob/living/carbon/human/npc/ambient_npc/outpost/police/beat, open_corner)
	officer.stop_pulling()
	holder.start_pulling(prisoner)
	TEST_ASSERT_EQUAL(holder.pulling, prisoner, "Fixture: the colleague did not take hold of the prisoner")
	var/turf/officer_was = get_turf(officer)
	officer.police_make_room(holder)
	if(get_turf(officer) != officer_was)
		TEST_FAIL("The officer stepped aside for its colleague holding its own prisoner, to [tile_text(officer)]")
	holder.stop_pulling()
	qdel(holder)
	police.close_case(prisoner.mind)
	officer.stop_pulling()
	qdel(prisoner)

	// The walk in from the tables, as in the soak
	officer.forceMove(police_outpost_tile(outpost, 32, 21))
	prisoner = police_arrest_person(police_outpost_tile(outpost, 31, 22))
	case = police.open_case(police_pin_warrant(police, prisoner.mind, 12))
	police.sleep_tick()
	TEST_ASSERT_NOTNULL(case, "Fixture: no second arrest opened")
	TEST_ASSERT_EQUAL(case.arresting(), officer, "Fixture: the second arrest went to someone else")
	cuffs = allocate(/obj/item/restraints/handcuffs/outpost_police/used)
	prisoner.equip_to_slot(cuffs, ITEM_SLOT_HANDCUFFED)
	case.cuffs_on(prisoner)
	case.searched = TRUE
	officer.start_pulling(prisoner)
	TEST_ASSERT_EQUAL(officer.pulling, prisoner, "Fixture: the officer did not take hold of the prisoner at the tables")
	case.set_step("desk")
	watched_prisoner = prisoner
	RegisterSignal(officer, COMSIG_MOVABLE_MOVED, PROC_REF(on_officer_moved))
	listed_z = officer.z
	SSmobs.clients_by_zlevel[listed_z] |= prisoner
	officer.ai_controller?.reset_ai_status()
	var/turf/desk = police_outpost_tile(outpost, 18, 3)
	var/start_dist = get_dist(officer, desk)
	var/list/seen = list()
	var/lost = 0
	var/end = world.time + 25 SECONDS
	var/next_tick = world.time
	while(world.time < end && get_dist(prisoner, desk) > start_dist - 8)
		if(world.time >= next_tick)
			next_tick = world.time + 1 SECONDS
			if(QDELETED(case))
				seen += "case closed"
				break
			case.process_case()
			officer.ai_controller?.reset_ai_status()
			seen += "officer [tile_text(officer)] prisoner [tile_text(prisoner)] step [case.step]"
		sleep(world.tick_lag)
		if(prisoner.pulledby != officer && get_dist(officer, prisoner) > 1)
			lost++
	UnregisterSignal(officer, COMSIG_MOVABLE_MOVED)
	var/walked = start_dist - get_dist(prisoner, desk)
	police.close_case(prisoner.mind)
	officer.stop_pulling()
	TEST_ASSERT(!length(diagonals), "Holding its prisoner, the officer stepped diagonally: [diagonals.Join(" ")] ([seen.Join(" | ")])")
	TEST_ASSERT(walked >= 8, "The prisoner was walked [walked] tiles toward the desk in 25 s ([seen.Join(" | ")])")
	TEST_ASSERT(!lost, "The officer was off its prisoner for [lost] ticks of the walk ([seen.Join(" | ")])")

/**
 * An officer whose diagonal step had someone on its first leg, who could not make way (a colleague at a body), took the
 * other leg and got past them. A tick later its straight try at them ran anyway (police_bump_straight()), found them
 * beside it, and walked it round them: back onto the tile it had just left. Its pathfinder planned the same diagonal
 * again, and it went to and fro by a crowd of fallen officers for 20 s on its way to cuff (pass 14 soak, Quartermain
 * four_star_crawl, O10 at 15,6 with O9 standing at 15,7). Past them, it walks on. (Here the walk is slow enough that
 * POLICE_STRAIGHT_BUMP_GAP spares the second pass; the step back is what is checked.)
 */
/datum/unit_test/voidcrew_stealth_live/police/crowd/diagonal_passed
	/// The officer's tiles in the order it stood on them
	var/list/walked = list()

/datum/unit_test/voidcrew_stealth_live/police/crowd/diagonal_passed/proc/on_officer_moved(mob/living/source, atom/old_loc, dir, forced)
	SIGNAL_HANDLER
	var/turf/tile = get_turf(source)
	walked += "[tile.x - at(0, 0).x],[tile.y - at(0, 0).y]"

/datum/unit_test/voidcrew_stealth_live/police/crowd/diagonal_passed/Run()
	TEST_ASSERT(police_room(9, 6), "No room for the test")
	open_place()
	allocate(/obj/effect/landmark/stealth_group, at(8, 5))
	police_stop(1, 1, "a", 1, 1 SECONDS, null)
	// The only two-step way on is (2, 2) then (3, 3), and so on to the stop: a diagonal every step
	police_stop(5, 5, "a", 2, 30 SECONDS, null)
	// Someone on the list of players keeps the level awake
	suspect = person_at(8, 5, TRUE)
	// At work and not making way, on the first leg of the officer's first diagonal step
	var/mob/living/carbon/human/npc/ambient_npc/outpost/busy = local_at(1, 2)
	ADD_TRAIT(busy, TRAIT_AI_PAUSED, "test_busy")
	TEST_ASSERT(!outpost_npc_can_make_room(busy), "Fixture: the one at work could make way")
	var/mob/living/carbon/human/npc/ambient_npc/outpost/police/officer = squad_officer(1, 1, NORTH)
	var/turf/stop = at(5, 5)
	RegisterSignal(officer, COMSIG_MOVABLE_MOVED, PROC_REF(on_officer_moved))
	watch(20, CALLBACK(src, PROC_REF(walked_to), officer, stop))
	UnregisterSignal(officer, COMSIG_MOVABLE_MOVED)
	var/past = walked.Find("2,2")
	TEST_ASSERT(past, "Fixture: the officer never got to 2,2 (it went [walked.Join(" ")])")
	TEST_ASSERT(!walked.Find("1,1", past), "Past the one at work, the officer walked back to where it started (it went [walked.Join(" ")])")
	TEST_ASSERT(get_dist(officer, stop) <= 1, "The officer never got on past someone it had stepped by on a diagonal (it is at [officer.x - at(0, 0).x],[officer.y - at(0, 0).y], [steps] steps taken)")
	REMOVE_TRAIT(busy, TRAIT_AI_PAUSED, "test_busy")
