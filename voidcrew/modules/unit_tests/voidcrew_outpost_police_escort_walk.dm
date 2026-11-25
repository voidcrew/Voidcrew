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

/// DIAGNOSTIC (temporary): the Quartermain four_star_crawl crowd by the public lift, O10 walking to cuff S at 18,7
/datum/unit_test/voidcrew_outpost_police_crowd_diag
	var/listed_z
	var/list/moves = list()
	var/turf/corner

/datum/unit_test/voidcrew_outpost_police_crowd_diag/Destroy()
	if(listed_z)
		SSmobs.clients_by_zlevel[listed_z] = list()
	return ..()

/datum/unit_test/voidcrew_outpost_police_crowd_diag/proc/txt(atom/thing)
	var/turf/tile = get_turf(thing)
	return tile ? "[tile.x - corner.x],[tile.y - corner.y]" : "-"

/datum/unit_test/voidcrew_outpost_police_crowd_diag/proc/on_moved(mob/living/source, atom/old_loc, dir, forced, list/old_locs)
	SIGNAL_HANDLER
	var/list/chain = list()
	var/callee/frame = caller
	var/depth = 0
	while(frame && depth < 9)
		chain += "[frame.proc]"
		frame = frame.caller
		depth++
	moves += "[world.time] [txt(old_loc)]>[txt(source)] forced=[forced] diag=[source.moving_diagonally] via [chain.Join("<")]"

/datum/unit_test/voidcrew_outpost_police_crowd_diag/Run()
	var/obj/structure/overmap/trader_outpost/outpost = police_loaded_outpost(/obj/structure/overmap/trader_outpost/outfitter)
	if(!outpost)
		return
	corner = outpost.template_bottom_left
	var/datum/outpost_police/police = outpost.police
	var/datum/ambient_place/outpost/place = SSambient_npcs.outpost_place(outpost)
	var/list/found = list()
	for(var/dx in 13 to 19)
		for(var/dy in 5 to 8)
			var/turf/tile = police_outpost_tile(outpost, dx, dy)
			var/list/stuff = list()
			for(var/atom/movable/thing in tile)
				if(thing.density || ismob(thing) || istype(thing, /obj/structure) || istype(thing, /obj/machinery))
					stuff += "[thing.type][thing.density ? "(dense)" : ""][thing.flags_1 & ON_BORDER_1 ? "(border [thing.dir])" : ""]"
			found += "[dx],[dy]: [tile.type] [stuff.Join(" ")]"
	TEST_FAIL("Tiles: [found.Join(" ; ")]")
	var/turf/spot = police_outpost_tile(outpost, 18, 7)
	var/mob/living/carbon/human/npc/ambient_npc/outpost/police/officer = police_officer(outpost, /mob/living/carbon/human/npc/ambient_npc/outpost/police/beat, police_outpost_tile(outpost, 15, 6))
	var/mob/living/carbon/human/suspect = police_arrest_person(spot)
	listed_z = spot.z
	SSmobs.clients_by_zlevel[listed_z] |= suspect
	suspect.adjustBruteLoss(110)
	suspect.updatehealth()
	var/list/lying = list(list(14, 6), list(14, 6), list(15, 7), list(15, 7), list(16, 6), list(16, 7), list(16, 7), list(19, 7), list(19, 6))
	for(var/list/at in lying)
		var/mob/living/carbon/human/body = allocate(/mob/living/carbon/human/consistent, police_outpost_tile(outpost, at[1], at[2]))
		body.adjustBruteLoss(110)
		body.updatehealth()
	var/mob/living/carbon/human/npc/ambient_npc/outpost/police/standing = police_officer(outpost, /mob/living/carbon/human/npc/ambient_npc/outpost/police/beat, police_outpost_tile(outpost, 15, 7))
	ADD_TRAIT(standing, TRAIT_AI_PAUSED, "diag")
	var/mob/living/carbon/human/npc/ambient_npc/outpost/police/standing2 = police_officer(outpost, /mob/living/carbon/human/npc/ambient_npc/outpost/police/beat, police_outpost_tile(outpost, 14, 6))
	ADD_TRAIT(standing2, TRAIT_AI_PAUSED, "diag")
	var/datum/outpost_warrant/warrant = police_pin_warrant(police, suspect.mind, 12)
	police.note_seen(suspect.mind, spot)
	var/datum/outpost_police_case/case = police.open_case(warrant)
	police.sleep_tick()
	if(case?.arresting() != officer)
		if(case && (officer in case.officers))
			case.officers -= officer
			case.officers.Insert(1, officer)
	TEST_FAIL("Case [case ? case.step : "none"], arresting [case?.arresting() == officer ? "the officer at 15,6" : "someone else"]")
	police_arrest_kit(officer)
	RegisterSignal(officer, COMSIG_MOVABLE_MOVED, PROC_REF(on_moved))
	SSambient_npcs.wake_outpost(place)
	officer.ai_controller.reset_ai_status()
	var/end = world.time + 20 SECONDS
	var/next_tick = world.time
	var/list/rows = list()
	while(world.time < end)
		if(QDELETED(case))
			rows += "[world.time] CASE GONE, officer at [txt(officer)]"
			break
		if(world.time >= next_tick)
			next_tick = world.time + 1 SECONDS
			SSambient_npcs.update_outpost(place, 1)
			officer.ai_controller.reset_ai_status()
			case.process_case()
			if(QDELETED(case))
				continue
			var/datum/move_loop/has_target/jps/loop = GLOB.move_manager.processing_on(officer, SSai_movement)
			var/list/path = list()
			if(istype(loop))
				for(var/turf/tile as anything in loop.movement_path)
					path += txt(tile)
			var/list/behaviors = list()
			for(var/datum/ai_behavior/behavior as anything in officer.ai_controller.current_behaviors)
				behaviors += "[behavior.type]"
			rows += "[world.time] at [txt(officer)] step [case.step] tgt [txt(officer.ai_controller.current_movement_target)] loop [loop ? "[loop.type] path [path.Join(" ")] avoid [istype(loop) ? txt(loop.avoid) : "-"]" : "none"] doing [behaviors.Join(",")]"
		sleep(world.tick_lag)
	TEST_FAIL("Rows: [rows.Join(" | ")]")
	TEST_FAIL("Moves: [moves.Join(" | ")]")
	UnregisterSignal(officer, COMSIG_MOVABLE_MOVED)
