/// DIAGNOSTIC (temporary): what tg's pull does to a cuffed prisoner at the Undertow's poker tables
/datum/unit_test/voidcrew_outpost_police_escort_diag

/datum/unit_test/voidcrew_outpost_police_escort_diag/Run()
	var/obj/structure/overmap/trader_outpost/outpost = police_loaded_outpost(/obj/structure/overmap/trader_outpost/black_market)
	if(!outpost)
		return
	var/list/found = list()
	for(var/dx in 29 to 33)
		for(var/dy in 17 to 22)
			var/turf/tile = police_outpost_tile(outpost, dx, dy)
			var/list/stuff = list()
			for(var/atom/movable/thing in tile)
				if(thing.density || ismob(thing) || istype(thing, /obj/structure))
					stuff += "[thing.type][thing.density ? "(dense)" : ""]"
			found += "[dx],[dy]: [tile.type] [stuff.Join(" ")]"
	TEST_FAIL("Tiles: [found.Join(" ; ")]")
	var/mob/living/carbon/human/npc/ambient_npc/outpost/police/officer = police_officer(outpost, where = police_outpost_tile(outpost, 31, 19))
	ADD_TRAIT(officer, TRAIT_AI_PAUSED, "diag")
	var/mob/living/carbon/human/suspect = police_arrest_person(police_outpost_tile(outpost, 32, 20))
	var/obj/item/restraints/handcuffs/cuffs = new(suspect)
	suspect.set_handcuffed(cuffs)
	suspect.update_handcuffed()
	TEST_FAIL("A: [try_step(outpost, officer, suspect, list(31, 19), list(32, 20), list(30, 18))]")
	var/mob/living/carbon/human/bystander = allocate(/mob/living/carbon/human/consistent, police_outpost_tile(outpost, 32, 19))
	TEST_FAIL("B (someone on 32,19): [try_step(outpost, officer, suspect, list(31, 19), list(32, 20), list(30, 18))]")
	bystander.forceMove(police_outpost_tile(outpost, 30, 19))
	TEST_FAIL("B2 (someone on 30,19): [try_step(outpost, officer, suspect, list(31, 19), list(32, 20), list(30, 18))]")
	bystander.forceMove(police_outpost_tile(outpost, 34, 25))
	TEST_FAIL("C: [try_step(outpost, officer, suspect, list(32, 20), list(32, 21), list(31, 19))]")
	TEST_FAIL("D: [try_step(outpost, officer, suspect, list(32, 21), list(31, 22), list(32, 20))]")

/datum/unit_test/voidcrew_outpost_police_escort_diag/proc/try_step(obj/structure/overmap/trader_outpost/outpost, mob/living/officer, mob/living/suspect, list/from, list/held_at, list/to_tile)
	officer.stop_pulling()
	officer.forceMove(police_outpost_tile(outpost, from[1], from[2]))
	suspect.forceMove(police_outpost_tile(outpost, held_at[1], held_at[2]))
	officer.start_pulling(suspect)
	var/held = officer.pulling == suspect
	var/turf/goal = police_outpost_tile(outpost, to_tile[1], to_tile[2])
	var/moved = officer.Move(goal, get_dir(officer, goal))
	var/turf/officer_at = get_turf(officer)
	var/turf/suspect_at = get_turf(suspect)
	var/turf/corner = outpost.template_bottom_left
	return "held=[held] moved=[moved] officer at [officer_at.x - corner.x],[officer_at.y - corner.y] suspect at [suspect_at.x - corner.x],[suspect_at.y - corner.y] still held=[officer.pulling == suspect]"

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
	var/datum/outpost_warrant/warrant = police_pin_warrant(police, suspect.mind, 113)
	police.note_seen(suspect.mind, spot)
	var/datum/outpost_police_case/case = police.open_case(warrant, TRUE)
	police.sleep_tick()
	if(case?.arresting() != officer)
		if(case && (officer in case.officers))
			case.officers -= officer
			case.officers.Insert(1, officer)
	case?.set_step("cuff")
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
