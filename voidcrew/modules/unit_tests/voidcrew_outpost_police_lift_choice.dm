/**
 * Outpost police tests: off the staff lift nearest where they are going (police_life.dm life_free_lift_turf() and
 * life_step_off_nearest(), police_dispatch.dm lift_point()). Quartermain, owner playtest 2026-11-24: a cell medic and an
 * officer came up the upper-left lift and walked the long way round the north side to the jail, where the right-hand
 * lift is a short walk across the concourse. On the real map, with tg's own pathing for the shortest walks.
 *
 * Fork defines are included after the tests, so values are written out: 25 heat is two stars.
 */

/datum/unit_test/voidcrew_outpost_police_lift_choice
	abstract_type = /datum/unit_test/voidcrew_outpost_police_lift_choice
	var/datum/outpost_police/test_police
	/// The level put on SSmobs' list of players so tg's AI runs there
	var/listed_z

/datum/unit_test/voidcrew_outpost_police_lift_choice/Destroy()
	crit_medic_cleanup(test_police)
	test_police = null
	if(listed_z)
		SSmobs.clients_by_zlevel[listed_z] = list()
	return ..()

/// The tile at map-local (lx, ly) of `outpost` (1-based, as the .dmm counts them)
/datum/unit_test/voidcrew_outpost_police_lift_choice/proc/local(obj/structure/overmap/trader_outpost/outpost, lx, ly)
	var/turf/corner = outpost.template_bottom_left
	return locate(corner.x + lx - 1, corner.y + ly - 1, corner.z)

/// "(x,y)" in map-local coordinates
/datum/unit_test/voidcrew_outpost_police_lift_choice/proc/local_text(obj/structure/overmap/trader_outpost/outpost, turf/tile)
	var/turf/corner = outpost.template_bottom_left
	if(!tile)
		return "(nowhere)"
	return "([tile.x - corner.x + 1],[tile.y - corner.y + 1])"

/**
 * Police lift tile -> the steps of tg's shortest walk (get_path_to()) from it to beside `goal` for `walker`, with its own
 * access; 0 for no walk. `walker` is put on each tile in turn with its AI paused, and put back.
 */
/datum/unit_test/voidcrew_outpost_police_lift_choice/proc/lift_walks(datum/outpost_police/police, mob/living/walker, atom/goal)
	. = list()
	var/turf/home = get_turf(walker)
	ADD_TRAIT(walker, TRAIT_AI_PAUSED, "lift_choice_test")
	for(var/turf/lift as anything in police.lift_turfs)
		walker.forceMove(lift)
		.[lift] = length(get_path_to(walker, goal, 150, 1, walker.get_access()))
	walker.forceMove(home)
	REMOVE_TRAIT(walker, TRAIT_AI_PAUSED, "lift_choice_test")

/// The shortest walk of `walks` (lift_walks()), 0 if none
/datum/unit_test/voidcrew_outpost_police_lift_choice/proc/shortest(list/walks)
	. = 0
	for(var/turf/lift as anything in walks)
		if(walks[lift] && (!. || walks[lift] < .))
			. = walks[lift]

/// `walks` as text, in map-local coordinates
/datum/unit_test/voidcrew_outpost_police_lift_choice/proc/walks_text(obj/structure/overmap/trader_outpost/outpost, list/walks)
	var/list/parts = list()
	for(var/turf/lift as anything in walks)
		parts += "[local_text(outpost, lift)]=[walks[lift]]"
	return parts.Join(" ")

/// Whether `tile` is Quartermain's right-hand police lift, at (37,14) and (38,14)
/datum/unit_test/voidcrew_outpost_police_lift_choice/proc/right_lift(obj/structure/overmap/trader_outpost/outpost, turf/tile)
	return tile == local(outpost, 37, 14) || tile == local(outpost, 38, 14)

/**
 * A cell medic called for a prisoner in crit at Quartermain comes up the right-hand lift every time, the lift with the
 * shortest walk to the cell, and walks to the cell door by the short way.
 */
/datum/unit_test/voidcrew_outpost_police_lift_choice/medic

/datum/unit_test/voidcrew_outpost_police_lift_choice/medic/Run()
	var/obj/structure/overmap/trader_outpost/outpost = police_loaded_outpost(/obj/structure/overmap/trader_outpost/outfitter)
	if(!outpost)
		return
	var/datum/outpost_police/police = outpost.police
	test_police = police
	TEST_ASSERT(length(police.lift_turfs) >= 2, "Fixture: Quartermain has [length(police.lift_turfs)] police lift tiles")
	TEST_ASSERT(length(police.cells), "Fixture: Quartermain has no cells")
	var/datum/outpost_police_cell/cell = police.cells[1]
	TEST_ASSERT_NOTNULL(cell.outside_turf, "Fixture: the cell has no tile outside its door")
	var/turf/floor
	for(var/turf/tile as anything in cell.tiles)
		if(!tile.is_blocked_turf(exclude_mobs = FALSE))
			floor = tile
			break
	TEST_ASSERT_NOTNULL(floor, "Fixture: no free cell floor")
	var/mob/living/carbon/human/prisoner = police_arrest_person(floor)
	crit_medic_beat(prisoner)
	TEST_ASSERT(recovery_in_crit(prisoner), "Fixture: the prisoner is not in crit (stat [prisoner.stat], health [prisoner.health])")
	cell.prisoners[prisoner.mind] = world.time + 30 MINUTES
	TEST_ASSERT(police.cell_patient_ok(prisoner), "Fixture: the prisoner is not a cell medic's patient")

	var/list/walks
	var/best = 0
	for(var/call_number in 1 to 8)
		TEST_ASSERT(police.call_cell_medic(prisoner), "Call [call_number]: no medic came for a prisoner in crit")
		var/mob/living/carbon/human/npc/ambient_npc/outpost/recovery/medic/cell/medic = police.cell_medic_for(prisoner)
		TEST_ASSERT_NOTNULL(medic, "Call [call_number]: the medic called is not on the job")
		var/turf/arrived = get_turf(medic)
		TEST_ASSERT(arrived in police.lift_turfs, "Call [call_number]: the medic came up at [local_text(outpost, arrived)], not on a police lift")
		if(!walks)
			walks = lift_walks(police, medic, cell.outside_turf)
			best = shortest(walks)
			TEST_ASSERT(best, "Fixture: no walk to the cell from any police lift ([walks_text(outpost, walks)])")
		TEST_ASSERT(right_lift(outpost, arrived), "Call [call_number]: the medic came up at [local_text(outpost, arrived)], not the right-hand lift (walks to the cell: [walks_text(outpost, walks)])")
		TEST_ASSERT(walks[arrived] && walks[arrived] <= best + 1, "Call [call_number]: the medic came up at [local_text(outpost, arrived)], a walk of [walks[arrived]] to the cell for a shortest of [best] ([walks_text(outpost, walks)])")
		if(call_number < 8)
			crit_medic_cleanup(police)
			continue
		// The last one walks it, on their own brain
		var/datum/ambient_place/outpost/place = SSambient_npcs.outpost_place(outpost)
		listed_z = arrived.z
		SSmobs.clients_by_zlevel[listed_z] |= prisoner
		SSambient_npcs.wake_outpost(place)
		var/list/steps = list(local_text(outpost, arrived))
		var/turf/last = arrived
		var/walked = 0
		var/end = world.time + 90 SECONDS
		var/next_tick = world.time
		while(world.time < end && !QDELETED(medic) && get_dist(medic, cell.outside_turf) > 1)
			if(world.time >= next_tick)
				next_tick = world.time + 1 SECONDS
				SSambient_npcs.update_outpost(place, 1)
				medic.ai_controller?.reset_ai_status()
			sleep(world.tick_lag)
			var/turf/here = get_turf(medic)
			if(here != last)
				walked++
				steps += local_text(outpost, here)
				last = here
		TEST_ASSERT(!QDELETED(medic) && get_dist(medic, cell.outside_turf) <= 1, "The medic did not reach the cell door in 90 s: [steps.Join(" ")]")
		TEST_ASSERT(walked <= walks[arrived] + 6, "The medic walked [walked] tiles to the cell for a shortest way of [walks[arrived]]: [steps.Join(" ")]")

/**
 * Officers sent to an arrest on Quartermain's concourse come up the lift with the shortest walk there (not the one
 * farthest from the suspect), and the desk sergeant's replacement the one with the shortest walk to the desk.
 */
/datum/unit_test/voidcrew_outpost_police_lift_choice/officer

/datum/unit_test/voidcrew_outpost_police_lift_choice/officer/Run()
	var/obj/structure/overmap/trader_outpost/outpost = police_loaded_outpost(/obj/structure/overmap/trader_outpost/outfitter)
	if(!outpost)
		return
	var/datum/outpost_police/police = outpost.police
	TEST_ASSERT(length(police.lift_turfs) >= 2, "Fixture: Quartermain has [length(police.lift_turfs)] police lift tiles")
	dispatch_clear(police)
	// Down beside the right-hand stairs, on the concourse: the upper-left lift is the farther one from them
	var/turf/spot = local(outpost, 29, 15)
	if(spot.is_blocked_turf(exclude_mobs = FALSE))
		spot = police_arrest_beside(spot)
	TEST_ASSERT(spot && outpost.is_secured_turf(spot), "Fixture: no concourse floor at (29,15)")
	var/mob/living/carbon/human/suspect = dispatch_suspect(outpost, 25, spot)
	police.note_seen(suspect.mind, spot)
	var/datum/outpost_warrant/warrant = police.get_warrant(suspect.mind)
	var/mob/living/carbon/human/npc/ambient_npc/outpost/police/probe = police_officer(outpost, /mob/living/carbon/human/npc/ambient_npc/outpost/police/officer, local(outpost, 19, 15))
	var/list/walks = lift_walks(police, probe, spot)
	var/best = shortest(walks)
	qdel(probe)
	TEST_ASSERT(best, "Fixture: no walk to the arrest from any police lift ([walks_text(outpost, walks)])")
	for(var/send in 1 to 6)
		police.dispatch_skipped.Cut()
		var/datum/outpost_police_wave/wave = police.dispatch_send_wave(2, 1, "concourse", warrant) // POLICE_SECTOR_CONCOURSE
		TEST_ASSERT_NOTNULL(wave, "Send [send]: no wave was sent")
		TEST_ASSERT(right_lift(outpost, wave.point), "Send [send]: the wave for an arrest at [local_text(outpost, spot)] came up at [local_text(outpost, wave.point)], not the right-hand lift (walks: [walks_text(outpost, walks)])")
		TEST_ASSERT(walks[wave.point] && walks[wave.point] <= best + 1, "Send [send]: the wave came up at [local_text(outpost, wave.point)], a walk of [walks[wave.point]] for a shortest of [best] ([walks_text(outpost, walks)])")
		dispatch_clear(police)
	police.close_case(suspect.mind)
	police.warrants -= suspect.mind

	// The desk sergeant's replacement, off a police lift the ambient way
	var/datum/ambient_place/outpost/place = SSambient_npcs.outpost_place(outpost)
	var/datum/ambient_outpost_role/role = SSambient_npcs.get_outpost_role(/datum/ambient_outpost_role/police_sergeant)
	TEST_ASSERT_NOTNULL(role, "Fixture: no sergeant role")
	var/list/desk_walks
	var/desk_best = 0
	for(var/arrival in 1 to 6)
		dispatch_clear(police)
		var/mob/living/carbon/human/npc/ambient_npc/outpost/police/sergeant = outpost_police_arrive(role, place, null)
		TEST_ASSERT_NOTNULL(sergeant, "Arrival [arrival]: no sergeant came up")
		var/turf/arrived = get_turf(sergeant)
		TEST_ASSERT(arrived in police.lift_turfs, "Arrival [arrival]: the sergeant came up at [local_text(outpost, arrived)], not on a police lift")
		if(!desk_walks)
			desk_walks = lift_walks(police, sergeant, police.desk_turf)
			desk_best = shortest(desk_walks)
			TEST_ASSERT(desk_best, "Fixture: no walk to the desk from any police lift ([walks_text(outpost, desk_walks)])")
		TEST_ASSERT(desk_walks[arrived] && desk_walks[arrived] <= desk_best + 1, "Arrival [arrival]: the sergeant came up at [local_text(outpost, arrived)], a walk of [desk_walks[arrived]] to the desk for a shortest of [desk_best] ([walks_text(outpost, desk_walks)])")
	dispatch_clear(police)

/**
 * Halcyon and the Undertow: a cell medic comes up the police lift with the shortest walk to the cell, and the desk
 * sergeant's replacement the one with the shortest walk to the desk. The walks from every lift are noted in the log.
 */
/datum/unit_test/voidcrew_outpost_police_lift_choice/other_outposts

/datum/unit_test/voidcrew_outpost_police_lift_choice/other_outposts/Run()
	for(var/outpost_type in list(/obj/structure/overmap/trader_outpost/general, /obj/structure/overmap/trader_outpost/black_market))
		var/obj/structure/overmap/trader_outpost/outpost = police_loaded_outpost(outpost_type)
		if(!outpost)
			return
		var/datum/outpost_police/police = outpost.police
		test_police = police
		TEST_ASSERT(length(police.lift_turfs) >= 2, "Fixture: [outpost_type] has [length(police.lift_turfs)] police lift tiles")
		TEST_ASSERT(length(police.cells), "Fixture: [outpost_type] has no cells")
		dispatch_clear(police)
		var/datum/outpost_police_cell/cell = police.cells[1]
		var/turf/floor
		for(var/turf/tile as anything in cell.tiles)
			if(!tile.is_blocked_turf(exclude_mobs = FALSE))
				floor = tile
				break
		TEST_ASSERT(floor && cell.outside_turf, "Fixture: [outpost_type]'s first cell has no free floor or no outside tile")
		var/mob/living/carbon/human/prisoner = police_arrest_person(floor)
		crit_medic_beat(prisoner)
		cell.prisoners[prisoner.mind] = world.time + 30 MINUTES
		TEST_ASSERT(police.cell_patient_ok(prisoner), "Fixture: [outpost_type]'s prisoner is not a cell medic's patient")
		var/list/walks
		var/best = 0
		for(var/call_number in 1 to 6)
			TEST_ASSERT(police.call_cell_medic(prisoner), "[outpost_type] call [call_number]: no medic came")
			var/mob/living/medic = police.cell_medic_for(prisoner)
			var/turf/arrived = get_turf(medic)
			TEST_ASSERT(arrived in police.lift_turfs, "[outpost_type] call [call_number]: the medic came up at [local_text(outpost, arrived)], not on a police lift")
			if(!walks)
				walks = lift_walks(police, medic, cell.outside_turf)
				best = shortest(walks)
				TEST_NOTICE(src, "[outpost_type]: walks to cell [local_text(outpost, cell.outside_turf)]: [walks_text(outpost, walks)]")
				TEST_ASSERT(best, "Fixture: [outpost_type] has no walk to the cell from any police lift ([walks_text(outpost, walks)])")
			TEST_ASSERT(walks[arrived] && walks[arrived] <= best + 1, "[outpost_type] call [call_number]: the medic came up at [local_text(outpost, arrived)], a walk of [walks[arrived]] to the cell for a shortest of [best] ([walks_text(outpost, walks)])")
			crit_medic_cleanup(police)
		qdel(prisoner)

		var/datum/ambient_place/outpost/place = SSambient_npcs.outpost_place(outpost)
		var/datum/ambient_outpost_role/role = SSambient_npcs.get_outpost_role(/datum/ambient_outpost_role/police_sergeant)
		var/list/desk_walks
		var/desk_best = 0
		for(var/arrival in 1 to 6)
			dispatch_clear(police)
			var/mob/living/sergeant = outpost_police_arrive(role, place, null)
			TEST_ASSERT_NOTNULL(sergeant, "[outpost_type] arrival [arrival]: no sergeant came up")
			var/turf/arrived = get_turf(sergeant)
			if(!desk_walks)
				desk_walks = lift_walks(police, sergeant, police.desk_turf)
				desk_best = shortest(desk_walks)
				TEST_NOTICE(src, "[outpost_type]: walks to the desk [local_text(outpost, police.desk_turf)]: [walks_text(outpost, desk_walks)]")
				TEST_ASSERT(desk_best, "Fixture: [outpost_type] has no walk to the desk from any police lift ([walks_text(outpost, desk_walks)])")
			TEST_ASSERT(desk_walks[arrived] && desk_walks[arrived] <= desk_best + 1, "[outpost_type] arrival [arrival]: the sergeant came up at [local_text(outpost, arrived)], a walk of [desk_walks[arrived]] to the desk for a shortest of [desk_best] ([walks_text(outpost, desk_walks)])")
		dispatch_clear(police)
		test_police = null
