/**
 * Outpost police tests: police_dispatch.dm and police_force.dm (voidcrew/modules/outpost_police/). Owner: P4.
 * Helpers are in voidcrew_outpost_police_helpers.dm. Fork defines are included after the tests: use
 * literal values with a comment naming the define.
 *
 * Heat for each star (OUTPOST_POLICE_STAR_HEAT): 10, 25, 50, 90, 140. Sectors: "concourse" (POLICE_SECTOR_CONCOURSE),
 * "lobby" (POLICE_SECTOR_LOBBY). Units: "officer", "tactical", "marshal" (POLICE_UNIT_*).
 */

/// A person with a mind standing on `where` (a free concourse tile of `outpost` if null), with `heat` pinned at its police
/datum/unit_test/proc/dispatch_suspect(obj/structure/overmap/trader_outpost/outpost, heat = 0, turf/where)
	var/mob/living/carbon/human/consistent/suspect = allocate(/mob/living/carbon/human/consistent, where || police_floor(outpost))
	suspect.mind_initialize()
	if(heat)
		police_pin_warrant(outpost.police, suspect.mind, heat)
	return suspect

/// Deletes every officer and order the police have, for a clean count
/datum/unit_test/proc/dispatch_clear(datum/outpost_police/police)
	for(var/mob/living/officer as anything in police.officers.Copy() + police.dispatch_strays.Copy())
		qdel(officer)
	for(var/datum/human_npc_order/order as anything in police.dispatch_orders.Copy())
		qdel(order)
	police.dispatch_orders.Cut()
	police.dispatch_waves.Cut()
	police.dispatch_skipped.Cut()
	police.dispatch_next_wave = 0

/// Two free concourse tiles, set as the police's only lift points
/datum/unit_test/proc/dispatch_two_lifts(obj/structure/overmap/trader_outpost/outpost)
	var/turf/first = police_floor(outpost)
	var/turf/second = police_floor(outpost)
	for(var/i in 1 to 10)
		if(second != first)
			break
		second = police_floor(outpost)
	outpost.police.lift_turfs = list(first, second)
	return outpost.police.lift_turfs

/// Living officers of `unit_kind` (any kind for null) on the roster
/datum/unit_test/proc/dispatch_count(datum/outpost_police/police, unit_kind)
	. = 0
	for(var/mob/living/carbon/human/npc/ambient_npc/outpost/police/officer as anything in police.officers)
		if(officer.stat != DEAD && (isnull(unit_kind) || officer.unit_kind == unit_kind))
			.++

/// Three free concourse tiles in a straight line, or null
/datum/unit_test/proc/dispatch_row(obj/structure/overmap/trader_outpost/outpost)
	for(var/i in 1 to 40)
		var/turf/start = police_floor(outpost)
		if(!start)
			continue
		for(var/direction in GLOB.cardinals)
			var/turf/middle = get_step(start, direction)
			var/turf/far = get_step(middle, direction)
			if(dispatch_free(outpost, middle) && dispatch_free(outpost, far))
				return list(start, middle, far)
	return null

/// A free concourse tile
/datum/unit_test/proc/dispatch_free(obj/structure/overmap/trader_outpost/outpost, turf/tile)
	return tile && isopenturf(tile) && !tile.is_blocked_turf(exclude_mobs = FALSE) && outpost.is_secured_turf(tile)

/// The scene is topped up to each level's officer count by lift, with the level's make-up at four and five stars
/datum/unit_test/voidcrew_outpost_police_dispatch_levels

/datum/unit_test/voidcrew_outpost_police_dispatch_levels/Run()
	var/obj/structure/overmap/trader_outpost/outpost = police_loaded_outpost()
	if(!outpost)
		return
	var/datum/outpost_police/police = outpost.police
	police.dispatch_build_now = TRUE
	dispatch_two_lifts(outpost)
	var/mob/living/suspect = dispatch_suspect(outpost)
	var/list/heats = list(10, 25, 50, 90, 140) // OUTPOST_POLICE_STAR_HEAT
	var/list/units = list(2, 3, 4, 7, 10) // OUTPOST_POLICE_UNITS
	for(var/level in 1 to 5)
		dispatch_clear(police)
		police_pin_warrant(police, suspect.mind, heats[level])
		TEST_ASSERT_EQUAL(police.alert_level(), level, "A suspect pinned at [heats[level]] heat does not make the alert level [level]")
		for(var/i in 1 to 12)
			police.dispatch_next_wave = 0
			police.tick_dispatch()
		TEST_ASSERT_EQUAL(dispatch_count(police), units[level], "At [level] stars the scene was topped up to the wrong number of officers")
		if(level == 4)
			TEST_ASSERT_EQUAL(dispatch_count(police, "tactical"), 2, "Four stars did not bring two tactical officers")
		if(level == 5)
			TEST_ASSERT_EQUAL(dispatch_count(police, "tactical"), 4, "Five stars did not bring four tactical officers")
			TEST_ASSERT_EQUAL(dispatch_count(police, "marshal"), 1, "Five stars did not bring the marshal")
	dispatch_clear(police)

/// No more than 12 living officers at one outpost, or 24 in the world, units waiting to be built included
/datum/unit_test/voidcrew_outpost_police_dispatch_caps

/datum/unit_test/voidcrew_outpost_police_dispatch_caps/Run()
	var/obj/structure/overmap/trader_outpost/outpost = police_loaded_outpost()
	var/obj/structure/overmap/trader_outpost/other = police_loaded_outpost(/obj/structure/overmap/trader_outpost/outfitter)
	if(!outpost || !other)
		return
	var/datum/outpost_police/police = outpost.police
	police.dispatch_build_now = TRUE
	dispatch_two_lifts(outpost)
	var/turf/floor = police_floor(outpost)
	var/list/fillers = list()
	// 12 waiting here: the outpost is full (OUTPOST_POLICE_CAP_OUTPOST)
	for(var/i in 1 to 12)
		var/datum/human_npc_order/filler = new /datum/human_npc_order(/mob/living/carbon/human/npc/ambient_npc/outpost/police/officer, floor)
		police.dispatch_orders[filler] = "officer"
		fillers += filler
	TEST_ASSERT_NULL(police.order_unit("officer", "concourse"), "An outpost with 12 officers on the way ordered a 13th")
	// 11 here and the rest of the world full (OUTPOST_POLICE_CAP_WORLD)
	police.dispatch_orders -= fillers[1]
	var/needed = 24 - outpost_police_world_count()
	for(var/i in 1 to needed)
		var/datum/human_npc_order/filler = new /datum/human_npc_order(/mob/living/carbon/human/npc/ambient_npc/outpost/police/officer, floor)
		other.police.dispatch_orders[filler] = "officer"
		fillers += filler
	TEST_ASSERT_NULL(police.order_unit("officer", "concourse"), "An officer was ordered with 24 already in the world")
	other.police.dispatch_orders.Cut()
	TEST_ASSERT_NOTNULL(police.order_unit("officer", "concourse"), "An officer could not be ordered with room under both caps")
	for(var/datum/human_npc_order/filler as anything in fillers)
		qdel(filler)
	dispatch_clear(police)

/// A wave forms up on one lift point, held, and its members leave at one and the same time
/datum/unit_test/voidcrew_outpost_police_dispatch_wave

/datum/unit_test/voidcrew_outpost_police_dispatch_wave/Run()
	var/obj/structure/overmap/trader_outpost/outpost = police_loaded_outpost()
	if(!outpost)
		return
	var/datum/outpost_police/police = outpost.police
	police.dispatch_build_now = TRUE
	dispatch_two_lifts(outpost)
	var/mob/living/suspect = dispatch_suspect(outpost, 50)
	var/datum/outpost_police_wave/wave = police.dispatch_send_wave(3, 2, "concourse", police.get_warrant(suspect.mind))
	TEST_ASSERT_NOTNULL(wave, "No wave was sent")
	var/list/members = wave.living_members()
	TEST_ASSERT_EQUAL(length(members), 2, "A wave of two built [length(members)]")
	var/mob/living/first = members[1]
	var/mob/living/second = members[2]
	TEST_ASSERT_EQUAL(get_turf(first), get_turf(second), "A wave's members formed up on different lift points")
	TEST_ASSERT(HAS_TRAIT(first, TRAIT_AI_PAUSED) && HAS_TRAIT(second, TRAIT_AI_PAUSED), "A wave's members are not held behind the door while it forms up")
	wave.release_at = world.time
	police.dispatch_check_waves()
	TEST_ASSERT(wave.released_at, "A formed-up wave did not leave")
	TEST_ASSERT(!HAS_TRAIT_FROM(first, TRAIT_AI_PAUSED, "outpost_police_wave") && !HAS_TRAIT_FROM(second, TRAIT_AI_PAUSED, "outpost_police_wave"), "A wave's members did not leave together")
	dispatch_clear(police)

/// Of two lift points, the one the suspect cannot see is used even when it is the nearer one; with one, either
/datum/unit_test/voidcrew_outpost_police_dispatch_lift_choice

/datum/unit_test/voidcrew_outpost_police_dispatch_lift_choice/Run()
	var/obj/structure/overmap/trader_outpost/outpost = police_loaded_outpost()
	if(!outpost)
		return
	var/datum/outpost_police/police = outpost.police
	var/turf/start = run_loc_floor_bottom_left
	if(run_loc_floor_top_right.x - start.x < 2 || run_loc_floor_top_right.y - start.y < 3)
		TEST_NOTICE(src, "The test room is too small for the lift choice test")
		return
	var/mob/living/suspect = allocate(/mob/living/carbon/human/consistent, start)
	var/turf/watched = locate(start.x, start.y + 3, start.z)
	var/turf/hidden = locate(start.x + 2, start.y, start.z)
	var/turf/between = locate(start.x + 1, start.y, start.z)
	var/old_type = between.type
	between.ChangeTurf(/turf/closed/wall)
	police.lift_turfs = list(watched, hidden)
	police.dispatch_skipped.Cut()
	TEST_ASSERT_EQUAL(police.lift_point("concourse", suspect), hidden, "Dispatch used the lift point the suspect watches over the hidden one")
	between.ChangeTurf(old_type)
	TEST_ASSERT_EQUAL(police.lift_point("concourse", suspect), watched, "With both points in sight, dispatch did not use the farther one")

/// A lift point nobody could get out of is skipped; with every point skipped, units are built out of sight
/datum/unit_test/voidcrew_outpost_police_dispatch_blocked

/datum/unit_test/voidcrew_outpost_police_dispatch_blocked/Run()
	var/obj/structure/overmap/trader_outpost/outpost = police_loaded_outpost()
	if(!outpost)
		return
	var/datum/outpost_police/police = outpost.police
	police.dispatch_build_now = TRUE
	var/list/turf/lifts = dispatch_two_lifts(outpost)
	var/turf/first = lifts[1]
	var/mob/living/suspect = dispatch_suspect(outpost, 50)
	// A unit stuck on its point well after leaving, with a suspect to go to
	var/datum/outpost_police_wave/wave = police.dispatch_new_wave("concourse", first)
	var/mob/living/carbon/human/npc/ambient_npc/outpost/police/stuck = police_officer(outpost, /mob/living/carbon/human/npc/ambient_npc/outpost/police/officer, first)
	stuck.dispatch_mind = WEAKREF(suspect.mind)
	wave.members += WEAKREF(stuck)
	if(get_dist(suspect, first) <= 2)
		suspect.forceMove(police_floor(outpost))
	wave.released_at = world.time - 11 SECONDS // OUTPOST_POLICE_LIFT_BLOCKED
	police.dispatch_check_waves()
	TEST_ASSERT(police.dispatch_skipped[first] > world.time, "A lift point whose unit could not get out was not skipped")
	TEST_ASSERT(police.lift_point("concourse") != first, "A skipped lift point is still used")
	// Every point skipped
	for(var/turf/point as anything in lifts)
		police.dispatch_skipped[point] = world.time + 2 MINUTES // OUTPOST_POLICE_LIFT_SKIP
	TEST_ASSERT_NULL(police.lift_point("concourse"), "A lift point was offered with all of them skipped")
	var/datum/human_npc_order/order = police.order_unit("officer", "concourse")
	TEST_ASSERT_NOTNULL(order, "With every lift point skipped no unit could be built at all")
	var/mob/living/built = order.spawned_ref?.resolve()
	TEST_ASSERT_NOTNULL(built, "The out-of-sight unit was not built")
	TEST_ASSERT(!(get_turf(built) in lifts), "The out-of-sight unit was built on a skipped lift point")
	TEST_ASSERT_EQUAL(police.sector_of(built), "concourse", "The out-of-sight unit was built outside the sector")
	dispatch_clear(police)

/// A ride takes the officer and whoever they pull from a concourse lift to the lobby's, still pulling them
/datum/unit_test/voidcrew_outpost_police_dispatch_ride

/datum/unit_test/voidcrew_outpost_police_dispatch_ride/Run()
	var/obj/structure/overmap/trader_outpost/outpost = police_loaded_outpost()
	if(!outpost)
		return
	var/datum/outpost_police/police = outpost.police
	TEST_ASSERT(length(outpost.lobby_alcove_turfs), "The outpost has no lobby lift alcove")
	var/list/turf/lifts = dispatch_two_lifts(outpost)
	var/turf/start = lifts[1]
	var/mob/living/carbon/human/npc/ambient_npc/outpost/police/officer = police_officer(outpost, /mob/living/carbon/human/npc/ambient_npc/outpost/police/officer, start)
	var/turf/beside
	for(var/direction in GLOB.cardinals)
		var/turf/candidate = get_step(start, direction)
		if(isopenturf(candidate) && !candidate.is_blocked_turf())
			beside = candidate
			break
	TEST_ASSERT_NOTNULL(beside, "No free tile beside the lift point")
	var/mob/living/carbon/human/consistent/prisoner = allocate(/mob/living/carbon/human/consistent, beside)
	officer.start_pulling(prisoner)
	TEST_ASSERT_EQUAL(officer.pulling, prisoner, "The officer could not pull the prisoner")
	TEST_ASSERT(police.ride(officer, "lobby"), "The ride did not arrive")
	TEST_ASSERT(get_turf(officer) in outpost.lobby_alcove_turfs, "The officer did not arrive at the lobby lift")
	TEST_ASSERT_EQUAL(get_turf(prisoner), get_turf(officer), "The pulled prisoner was left behind")
	TEST_ASSERT_EQUAL(officer.pulling, prisoner, "The officer is not pulling the prisoner after the ride")
	officer.stop_pulling()
	dispatch_clear(police)

/// Whom officers fight: a three-star suspect and carp, never a clean player, an outpost resident or a fugitive at the outpost
/datum/unit_test/voidcrew_outpost_police_dispatch_targets

/datum/unit_test/voidcrew_outpost_police_dispatch_targets/Run()
	var/obj/structure/overmap/trader_outpost/outpost = police_loaded_outpost()
	if(!outpost)
		return
	var/datum/outpost_police/police = outpost.police
	var/mob/living/carbon/human/npc/ambient_npc/outpost/police/officer = police_officer(outpost)
	var/turf/here = get_turf(officer)
	var/datum/targeting_strategy/strategy = GET_TARGETING_STRATEGY(/datum/targeting_strategy/basic/human_npc/outpost_police)
	var/mob/living/wanted = dispatch_suspect(outpost, 50, here)
	TEST_ASSERT(strategy.can_attack(officer, wanted), "Officers do not fight a three-star suspect")
	var/mob/living/stunned = dispatch_suspect(outpost, 25, here)
	TEST_ASSERT(strategy.can_attack(officer, stunned), "Officers do not fight a two-star suspect who is up")
	stunned.Paralyze(10 SECONDS)
	TEST_ASSERT(!strategy.can_attack(officer, stunned), "Officers keep firing at a two-star suspect already down")
	var/mob/living/clean = dispatch_suspect(outpost, 0, here)
	TEST_ASSERT(!strategy.can_attack(officer, clean), "Officers fight a player with no warrant")
	var/mob/living/arrest = dispatch_suspect(outpost, 10, here)
	TEST_ASSERT(!strategy.can_attack(officer, arrest), "Officers open fire on a one-star suspect")
	var/mob/living/carp = allocate(/mob/living/basic/carp, here)
	TEST_ASSERT(strategy.can_attack(officer, carp), "Officers do not shoot carp")
	var/mob/living/resident = allocate(/mob/living/basic/carp, here)
	ADD_TRAIT(resident, "outpost_resident", TRAIT_GENERIC) // TRAIT_OUTPOST_RESIDENT
	TEST_ASSERT(!strategy.can_attack(officer, resident), "Officers shoot an outpost resident")
	var/mob/living/fugitive = allocate(/mob/living/carbon/human/npc/bounty_criminal/meek, here)
	TEST_ASSERT(!strategy.can_attack(officer, fugitive), "Officers shoot a bounty fugitive blending in at the outpost")
	var/mob/living/colleague = police_officer(outpost, /mob/living/carbon/human/npc/ambient_npc/outpost/police/officer, here)
	TEST_ASSERT(!strategy.can_attack(officer, colleague), "Officers fight each other")
	dispatch_clear(police)

/// An officer holds fire while a bystander stands in the line, and fires once it is clear
/datum/unit_test/voidcrew_outpost_police_dispatch_hold_fire

/datum/unit_test/voidcrew_outpost_police_dispatch_hold_fire/Run()
	var/obj/structure/overmap/trader_outpost/outpost = police_loaded_outpost()
	if(!outpost)
		return
	var/datum/outpost_police/police = outpost.police
	var/list/turf/row = dispatch_row(outpost)
	TEST_ASSERT_NOTNULL(row, "No three free tiles in a row on the concourse")
	var/turf/start = row[1]
	var/turf/middle = row[2]
	var/turf/far = row[3]
	var/mob/living/carbon/human/npc/ambient_npc/outpost/police/officer = police_officer(outpost, /mob/living/carbon/human/npc/ambient_npc/outpost/police/officer, start)
	var/mob/living/target = dispatch_suspect(outpost, 50, far)
	var/mob/living/bystander = dispatch_suspect(outpost, 0, middle)
	TEST_ASSERT_EQUAL(officer.bystander_in_line(target), bystander, "A bystander between officer and target is not seen as in the line")
	var/obj/item/gun/energy/e_gun/gun = allocate(/obj/item/gun/energy/e_gun)
	for(var/obj/item/held in officer.held_items)
		officer.temporarilyRemoveItemFromInventory(held, force = TRUE)
		qdel(held)
	TEST_ASSERT(officer.put_in_hands(gun), "The officer could not take the test gun")
	outpost_police_set_gun_mode(gun, lethal = TRUE)
	TEST_ASSERT(outpost_police_mode_lethal(gun), "The energy gun did not go to its killing mode")
	var/datum/ai_controller/controller = officer.ai_controller
	controller.set_blackboard_key(BB_BASIC_MOB_CURRENT_TARGET, target)
	controller.set_blackboard_key("human_npc_next_shot", 0) // BB_HUMAN_NPC_NEXT_SHOT
	var/datum/ai_behavior/shoot = GET_AI_BEHAVIOR(/datum/ai_behavior/human_npc_shoot/outpost_police)
	shoot.perform(1, controller, BB_BASIC_MOB_CURRENT_TARGET, BB_TARGETING_STRATEGY, BB_BASIC_MOB_CURRENT_TARGET_HIDING_LOCATION)
	TEST_ASSERT(!controller.blackboard["human_npc_next_shot"], "An officer fired with a bystander in the line")
	officer.forceMove(start)
	bystander.forceMove(police_floor(outpost))
	TEST_ASSERT_NULL(officer.bystander_in_line(target), "A clear line still reads as blocked")
	shoot.perform(1, controller, BB_BASIC_MOB_CURRENT_TARGET, BB_TARGETING_STRATEGY, BB_BASIC_MOB_CURRENT_TARGET_HIDING_LOCATION)
	TEST_ASSERT(controller.blackboard["human_npc_next_shot"], "An officer with a clear line at a three-star suspect did not fire")
	controller.clear_blackboard_key(BB_BASIC_MOB_CURRENT_TARGET)
	dispatch_clear(police)

/// Standing in an officer's line of fire within 2 tiles is resisting once it lasts 5 seconds; so is pulling an officer
/datum/unit_test/voidcrew_outpost_police_dispatch_body_block

/datum/unit_test/voidcrew_outpost_police_dispatch_body_block/Run()
	var/obj/structure/overmap/trader_outpost/outpost = police_loaded_outpost()
	if(!outpost)
		return
	var/datum/outpost_police/police = outpost.police
	var/list/turf/row = dispatch_row(outpost)
	TEST_ASSERT_NOTNULL(row, "No three free tiles in a row on the concourse")
	var/turf/start = row[1]
	var/mob/living/carbon/human/npc/ambient_npc/outpost/police/officer = police_officer(outpost, /mob/living/carbon/human/npc/ambient_npc/outpost/police/officer, start)
	var/mob/living/target = dispatch_suspect(outpost, 50, row[3])
	var/mob/living/blocker = dispatch_suspect(outpost, 0, row[2])
	officer.force = 3 // POLICE_FORCE_LETHAL
	officer.ai_controller.set_blackboard_key(BB_BASIC_MOB_CURRENT_TARGET, target)
	officer.check_body_block()
	TEST_ASSERT_NULL(police.get_warrant(blocker.mind), "Stepping into the line was resisting at once")
	officer.dispatch_block_since = world.time - 5 SECONDS // OUTPOST_POLICE_BLOCK_TIME
	officer.check_body_block()
	var/datum/outpost_warrant/warrant = police.get_warrant(blocker.mind)
	TEST_ASSERT(warrant?.heat > 0, "Standing in the line of fire for 5 seconds was not resisting")
	// Pulling an officer
	officer.ai_controller.clear_blackboard_key(BB_BASIC_MOB_CURRENT_TARGET)
	officer.force = 0 // POLICE_FORCE_NONE
	var/mob/living/puller = dispatch_suspect(outpost, 0, start)
	puller.start_pulling(officer)
	officer.dispatch_check_pull()
	officer.dispatch_pull_since = world.time - 5 SECONDS // OUTPOST_POLICE_BLOCK_TIME
	officer.dispatch_check_pull()
	TEST_ASSERT(police.get_warrant(puller.mind)?.heat > 0, "Pulling an officer for 5 seconds was not resisting")
	puller.stop_pulling()
	dispatch_clear(police)

/// When the alert level falls, surplus response units walk out to a lift; at none, every one of them does
/datum/unit_test/voidcrew_outpost_police_dispatch_stand_down

/datum/unit_test/voidcrew_outpost_police_dispatch_stand_down/Run()
	var/obj/structure/overmap/trader_outpost/outpost = police_loaded_outpost()
	if(!outpost)
		return
	var/datum/outpost_police/police = outpost.police
	dispatch_two_lifts(outpost)
	var/mob/living/suspect = dispatch_suspect(outpost, 50)
	var/list/responders = list()
	for(var/i in 1 to 4)
		var/mob/living/carbon/human/npc/ambient_npc/outpost/police/officer = police_officer(outpost, /mob/living/carbon/human/npc/ambient_npc/outpost/police/officer)
		officer.resume_routine() // as if someone were on the concourse
		officer.dispatch_mind = WEAKREF(suspect.mind)
		responders += officer
	police.dispatch_next_wave = world.time + 1 MINUTES
	police_pin_warrant(police, suspect.mind, 25)
	police.dispatch_respond(police.alert_level())
	var/leaving = 0
	for(var/mob/living/carbon/human/npc/ambient_npc/outpost/police/officer as anything in responders)
		if(officer.npc_exit)
			leaving++
	TEST_ASSERT_EQUAL(leaving, 1, "Going from three stars to two, [leaving] of four response officers stood down instead of one")
	police_pin_warrant(police, suspect.mind, 0)
	police.dispatch_respond(police.alert_level())
	for(var/mob/living/carbon/human/npc/ambient_npc/outpost/police/officer as anything in responders)
		TEST_ASSERT(officer.npc_exit, "A response officer stayed on with nobody wanted")
		TEST_ASSERT(!officer.dispatch_responding(), "A stood-down officer is still responding")
	dispatch_clear(police)

/// Past eight officer bodies at an outpost, the oldest is collected
/datum/unit_test/voidcrew_outpost_police_dispatch_bodies

/datum/unit_test/voidcrew_outpost_police_dispatch_bodies/Run()
	var/obj/structure/overmap/trader_outpost/outpost = police_loaded_outpost()
	if(!outpost)
		return
	var/datum/outpost_police/police = outpost.police
	var/list/bodies = list()
	for(var/i in 1 to 9) // OUTPOST_POLICE_CORPSE_CAP + 1
		var/mob/living/carbon/human/npc/ambient_npc/outpost/police/officer = police_officer(outpost)
		officer.death()
		officer.timeofdeath = world.time - (100 - i) SECONDS
		bodies += officer
	police.dispatch_collect_bodies()
	TEST_ASSERT(QDELETED(bodies[1]), "The oldest officer body was not collected past the cap")
	for(var/i in 2 to 9)
		TEST_ASSERT(!QDELETED(bodies[i]), "An officer body under the cap was collected")
	dispatch_clear(police)

/// An officer carried off the outpost leaves the roster, and with nobody about to see them, goes
/datum/unit_test/voidcrew_outpost_police_dispatch_carried_off

/datum/unit_test/voidcrew_outpost_police_dispatch_carried_off/Run()
	var/obj/structure/overmap/trader_outpost/outpost = police_loaded_outpost()
	if(!outpost)
		return
	var/datum/outpost_police/police = outpost.police
	var/mob/living/carbon/human/npc/ambient_npc/outpost/police/officer = police_officer(outpost, /mob/living/carbon/human/npc/ambient_npc/outpost/police/officer)
	officer.forceMove(run_loc_floor_bottom_left)
	TEST_ASSERT_EQUAL(police.sector_of(officer), "outside", "The test room reads as part of the outpost") // POLICE_SECTOR_OUTSIDE
	police.dispatch_check_strays()
	TEST_ASSERT(QDELETED(officer) || !(officer in police.officers), "An officer carried off the outpost is still on the roster")
	TEST_ASSERT(QDELETED(officer), "An officer carried off with nobody about was not deleted")
	dispatch_clear(police)
