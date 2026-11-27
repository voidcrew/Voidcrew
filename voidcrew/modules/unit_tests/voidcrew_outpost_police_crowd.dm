/**
 * Outpost police tests for a squad in its own way (voidcrew/modules/outpost_police/police_movement.dm): officers
 * closing on one suspect, searching one spot, and walking their beats past each other do not trade places back and
 * forth. Owner playtest 4: "the cops keep just like swapping places i assume trying to walk by each other".
 *
 * The crowd tests run the real AI and real walking in the walled room of voidcrew_stealth_live, the police ticking as
 * they do in a round. A trade of places is seen from outside: two officers on each other's tile from one tick to the
 * next. The rule tests below them call one officer's step into another by hand.
 * Written out: POLICE_SWAP_PAIR_GAP is 10 seconds; heat 25 is two stars, 50 is three.
 */

/datum/unit_test/voidcrew_stealth_live/police/crowd
	abstract_type = /datum/unit_test/voidcrew_stealth_live/police/crowd
	/// The officers watched
	var/list/mob/living/carbon/human/npc/ambient_npc/outpost/police/squad = list()
	/// Who they are after
	var/mob/living/carbon/human/suspect
	/// "1-2" (two of the squad) -> world.time they last traded places
	var/list/last_trade = list()
	/// Trades of places in all, and those by two officers who had traded within the ten seconds before
	var/trades = 0
	var/repeat_trades = 0
	/// The first repeat trade, for the failure message
	var/first_repeat
	/// Steps the squad took in all
	var/steps = 0

/// The room is the outpost's public floor with someone on it, as a concourse with a player there is
/datum/unit_test/voidcrew_stealth_live/police/crowd/proc/open_place()
	var/datum/ambient_place/outpost/place = SSambient_npcs.outpost_place(outpost)
	place.occupied = TRUE
	place.public_floor = list()
	for(var/turf/open/tile in block(room.bottom_left_turfs[1], room.top_right_turfs[1]))
		place.public_floor[tile] = TRUE
	place.floor_built_at = world.time

/// An officer of the squad at (dx, dy)
/datum/unit_test/voidcrew_stealth_live/police/crowd/proc/squad_officer(dx, dy, facing = EAST, officer_type = /mob/living/carbon/human/npc/ambient_npc/outpost/police/beat)
	var/mob/living/carbon/human/npc/ambient_npc/outpost/police/officer = officer_at(dx, dy, facing, officer_type)
	squad += officer
	return officer

/**
 * Someone wanted at (dx, dy), on SSmobs' list of players so the level is awake. `fights`: they never go down and
 * never give up (combat mode, no stun takes), so the squad is on them for as long as the test watches.
 */
/datum/unit_test/voidcrew_stealth_live/police/crowd/proc/wanted_at(dx, dy, heat = 25, fights = TRUE)
	suspect = person_at(dx, dy, TRUE)
	suspect.mind_initialize()
	allocated += suspect.mind
	if(fights)
		ADD_TRAIT(suspect, TRAIT_STUNIMMUNE, TRAIT_SOURCE_UNIT_TESTS)
		ADD_TRAIT(suspect, TRAIT_BATON_RESISTANCE, TRAIT_SOURCE_UNIT_TESTS)
		suspect.set_combat_mode(TRUE)
	police_pin_warrant(police, suspect.mind, heat)
	police.note_seen(suspect.mind, get_turf(suspect))
	return suspect

/// Watches the squad for `seconds`, counting steps and trades of places. `until`: a callback that ends it early when TRUE.
/datum/unit_test/voidcrew_stealth_live/police/crowd/proc/watch(seconds, datum/callback/until)
	var/list/turf/last = list()
	for(var/mob/living/officer as anything in squad)
		wake(officer)
		last[officer] = get_turf(officer)
	var/end = world.time + seconds SECONDS
	while(world.time < end)
		sleep(world.tick_lag)
		var/list/turf/now = list()
		for(var/mob/living/officer as anything in squad)
			now[officer] = get_turf(officer)
			if(now[officer] != last[officer])
				steps++
		for(var/i in 1 to length(squad))
			for(var/j in i + 1 to length(squad))
				var/mob/living/first = squad[i]
				var/mob/living/second = squad[j]
				if(now[first] == last[first] || now[first] != last[second] || now[second] != last[first])
					continue
				trades++
				var/pair = "[i]-[j]"
				if(last_trade[pair] && world.time - last_trade[pair] < 10 SECONDS) // POLICE_SWAP_PAIR_GAP
					repeat_trades++
					if(!first_repeat)
						first_repeat = "officers [i] and [j] traded places twice in [(world.time - last_trade[pair]) / 10] seconds"
				last_trade[pair] = world.time
		last = now
		if(until?.Invoke())
			break

/// Fails the test if two officers traded places back and forth, or nobody moved at all
/datum/unit_test/voidcrew_stealth_live/police/crowd/proc/check_no_repeats(scene)
	TEST_ASSERT(steps >= 8, "[scene]: the squad never set off ([steps] steps): the scene did not run")
	TEST_ASSERT(!repeat_trades, "[scene]: [first_repeat] ([repeat_trades] such trades, [trades] trades in all)")

/// The nearest any of the squad is to the suspect
/datum/unit_test/voidcrew_stealth_live/police/crowd/proc/nearest_to_suspect()
	. = INFINITY
	for(var/mob/living/officer as anything in squad)
		. = min(., get_dist(officer, suspect))

/datum/unit_test/voidcrew_stealth_live/police/crowd/proc/suspect_cuffed()
	return !!suspect.handcuffed

// ===== CLOSING ON ONE SUSPECT =====

/// A hall one tile wide, four officers in file, a suspect who fights on at its far end: nobody trades places twice
/datum/unit_test/voidcrew_stealth_live/police/crowd/corridor

/datum/unit_test/voidcrew_stealth_live/police/crowd/corridor/Run()
	TEST_ASSERT(police_room(20, 1), "No room for the test")
	open_place()
	wanted_at(14, 0)
	for(var/dx in 0 to 3)
		squad_officer(dx, 0)
	police.wake()
	watch(35)
	check_no_repeats("a hall one tile wide")
	TEST_ASSERT(nearest_to_suspect() <= 1, "In a hall one tile wide nobody got up to the suspect ([nearest_to_suspect()] tiles off)")

/// The same hall, a suspect who does as told: the arrest is still made
/datum/unit_test/voidcrew_stealth_live/police/crowd/corridor_arrest

/datum/unit_test/voidcrew_stealth_live/police/crowd/corridor_arrest/Run()
	TEST_ASSERT(police_room(20, 1), "No room for the test")
	open_place()
	wanted_at(14, 0, 25, FALSE)
	for(var/dx in 0 to 3)
		squad_officer(dx, 0)
	police.wake()
	watch(45, CALLBACK(src, PROC_REF(suspect_cuffed)))
	check_no_repeats("an arrest in a hall one tile wide")
	TEST_ASSERT(suspect.handcuffed, "In a hall one tile wide, four officers in file, the suspect who stood still was not cuffed in 45 seconds")

/// An open room, four officers setting off in file for a suspect who fights on: with all that room nobody trades places twice
/datum/unit_test/voidcrew_stealth_live/police/crowd/room

/datum/unit_test/voidcrew_stealth_live/police/crowd/room/Run()
	TEST_ASSERT(police_room(20, 7), "No room for the test")
	open_place()
	wanted_at(14, 3)
	for(var/dx in 0 to 3)
		squad_officer(dx, 3)
	police.wake()
	watch(35)
	check_no_repeats("an open room")
	TEST_ASSERT(nearest_to_suspect() <= 1, "In an open room nobody got up to the suspect ([nearest_to_suspect()] tiles off)")

/// An open room, the squad setting off in a pack at three stars (everyone running, guns out): nobody trades places twice
/datum/unit_test/voidcrew_stealth_live/police/crowd/room_pack

/datum/unit_test/voidcrew_stealth_live/police/crowd/room_pack/Run()
	TEST_ASSERT(police_room(20, 7), "No room for the test")
	open_place()
	wanted_at(16, 3, 50)
	squad_officer(1, 3)
	squad_officer(2, 2)
	squad_officer(2, 4)
	squad_officer(3, 3)
	police.wake()
	watch(30)
	check_no_repeats("a pack in an open room")
	TEST_ASSERT(nearest_to_suspect() <= 7, "In an open room nobody got within range of the suspect ([nearest_to_suspect()] tiles off)")

/// An open room, the squad coming at a two-star suspect from both sides, and the arrest of one who stands still
/datum/unit_test/voidcrew_stealth_live/police/crowd/room_arrest

/datum/unit_test/voidcrew_stealth_live/police/crowd/room_arrest/Run()
	TEST_ASSERT(police_room(17, 11), "No room for the test")
	open_place()
	wanted_at(8, 5, 25, FALSE)
	squad_officer(1, 5)
	squad_officer(2, 3)
	squad_officer(15, 5, WEST)
	squad_officer(14, 7, WEST)
	police.wake()
	watch(40, CALLBACK(src, PROC_REF(suspect_cuffed)))
	check_no_repeats("an arrest in an open room")
	TEST_ASSERT(suspect.handcuffed, "In an open room the suspect who stood still was not cuffed in 40 seconds")

// ===== LOOKING FOR ONE =====

/// The suspect is out of sight behind a wall: the squad looks for them at the one spot they were last seen, and nobody trades places twice
/datum/unit_test/voidcrew_stealth_live/police/crowd/search

/datum/unit_test/voidcrew_stealth_live/police/crowd/search/Run()
	TEST_ASSERT(police_room(20, 7), "No room for the test")
	open_place()
	for(var/dy in 0 to 6)
		var/turf/wall_spot = at(15, dy)
		wall_spot.ChangeTurf(/turf/closed/wall)
	wanted_at(18, 3)
	police.note_seen(suspect.mind, at(10, 3))
	squad_officer(1, 1)
	squad_officer(1, 3)
	squad_officer(1, 5)
	squad_officer(3, 3)
	police.wake()
	watch(50)
	check_no_repeats("a search of one spot")

// ===== ON THE BEAT =====

/// Two officers walking the length of a hall two tiles wide, past two who stand and step about in the middle of it: nobody trades places twice
/datum/unit_test/voidcrew_stealth_live/police/crowd/beat

/datum/unit_test/voidcrew_stealth_live/police/crowd/beat/Run()
	TEST_ASSERT(police_room(20, 2), "No room for the test")
	open_place()
	allocate(/obj/effect/landmark/stealth_group, at(10, 1))
	police_stop(1, 0, "a", 1, 2 SECONDS, null)
	police_stop(18, 0, "a", 2, 2 SECONDS, null)
	police_stop(18, 1, "b", 1, 2 SECONDS, null)
	police_stop(1, 1, "b", 2, 2 SECONDS, null)
	police_stop(9, 0, "c", 1, 2 SECONDS, null)
	police_stop(10, 0, "c", 2, 2 SECONDS, null)
	police_stop(10, 1, "d", 1, 2 SECONDS, null)
	police_stop(9, 1, "d", 2, 2 SECONDS, null)
	// Someone on the list of players, at the far end, keeps the level awake
	suspect = person_at(19, 0, TRUE)
	squad_officer(1, 0)
	squad_officer(18, 1, WEST)
	squad_officer(9, 0)
	squad_officer(10, 1, WEST)
	watch(50)
	check_no_repeats("beats that cross")

// ===== THE RULES, ONE STEP AT A TIME =====

/// A police officer at `where` with its brain off, running (the pace at which tg trades places with anyone not played)
/datum/unit_test/proc/police_crowd_runner(turf/where)
	var/mob/living/carbon/human/npc/ambient_npc/outpost/police/officer = allocate(/mob/living/carbon/human/npc/ambient_npc/outpost/police/beat, where)
	officer.ai_controller?.set_ai_status(AI_STATUS_OFF)
	officer.set_pace(TRUE)
	return officer

/**
 * Running, as officers do on an alert: one never takes the tile its walk ends on from the colleague standing there; two
 * who have traded places do not trade back; one walking the same way is not passed; with room, an officer walks round
 * a colleague and nobody is moved; nobody trades places with the officer making an arrest, who trades with them.
 */
/datum/unit_test/voidcrew_outpost_police_crowd_rules

/datum/unit_test/voidcrew_outpost_police_crowd_rules/Run()
	var/x0 = run_loc_floor_bottom_left.x
	var/y0 = run_loc_floor_bottom_left.y
	var/z0 = run_loc_floor_bottom_left.z
	// A hall one tile wide along y0 + 1: tables above and below it
	for(var/dx in 0 to 4)
		allocate(/obj/structure/table, locate(x0 + dx, y0, z0))
		allocate(/obj/structure/table, locate(x0 + dx, y0 + 2, z0))
	var/turf/hall_start = locate(x0, y0 + 1, z0)
	var/turf/first_tile = locate(x0 + 1, y0 + 1, z0)
	var/turf/second_tile = locate(x0 + 2, y0 + 1, z0)
	var/turf/third_tile = locate(x0 + 3, y0 + 1, z0)
	var/turf/hall_end = locate(x0 + 4, y0 + 1, z0)
	var/mob/living/carbon/human/npc/ambient_npc/outpost/police/walker = police_crowd_runner(first_tile)
	var/mob/living/carbon/human/npc/ambient_npc/outpost/police/other = police_crowd_runner(second_tile)
	TEST_ASSERT_EQUAL(walker.move_intent, MOVE_INTENT_RUN, "Setup: the officer is not running")

	// The tile its walk ends on is the colleague's: no trade, however often it walks into them
	walker.ai_controller.set_movement_target(type, second_tile)
	for(var/i in 1 to 3)
		walker.Move(second_tile, EAST)
	TEST_ASSERT_EQUAL(get_turf(walker), first_tile, "A running officer took the tile its walk ends on from the colleague standing there")
	TEST_ASSERT_EQUAL(get_turf(other), second_tile, "The colleague standing where a running officer's walk ends was moved off it")

	// Going on past them, in a hall too narrow to walk round: one trade
	walker.ai_controller.set_movement_target(type, hall_end)
	walker.Move(second_tile, EAST)
	TEST_ASSERT_EQUAL(get_turf(walker), second_tile, "A running officer did not get past a colleague standing in a narrow hall")
	TEST_ASSERT_EQUAL(get_turf(other), first_tile, "The colleague in the narrow hall did not trade places")
	// The one put off its tile walks back into them: no trade back, and none the other way either for a while
	other.ai_controller.set_movement_target(type, hall_end)
	for(var/i in 1 to 3)
		other.Move(second_tile, EAST)
	TEST_ASSERT_EQUAL(get_turf(other), first_tile, "Two officers who had just traded places traded straight back")
	walker.ai_controller.set_movement_target(type, hall_start)
	COOLDOWN_RESET(walker, police_swap_cooldown)
	walker.Move(first_tile, WEST)
	TEST_ASSERT_EQUAL(get_turf(walker), second_tile, "Two officers who had just traded places traded again the other way")

	// One walking the same way is not passed: it is out of the way in a step. (A third officer, whom the walker has
	// never traded places with: nothing but this rule keeps them apart.)
	other.forceMove(hall_start)
	var/mob/living/carbon/human/npc/ambient_npc/outpost/police/third = police_crowd_runner(third_tile)
	var/datum/move_loop/has_target/jps/third_loop = GLOB.move_manager.jps_move(third, hall_end, 10, repath_delay = 5 SECONDS, subsystem = SSai_movement, extra_info = third.ai_controller)
	TEST_ASSERT_NOTNULL(third_loop, "Setup: no path loop started")
	third_loop.movement_path = list(hall_end)
	third.last_step_at = world.time
	TEST_ASSERT_EQUAL(outpost_npc_next_step(third), hall_end, "Setup: the third officer is not walking on east")
	walker.ai_controller.set_movement_target(type, hall_end)
	COOLDOWN_RESET(walker, police_swap_cooldown)
	walker.Move(third_tile, EAST)
	TEST_ASSERT_EQUAL(get_turf(walker), second_tile, "An officer traded places with a colleague walking the same way")
	TEST_ASSERT_EQUAL(get_turf(third), third_tile, "The colleague walking the same way was moved")
	// Held up for a second and more, it is no longer on the move: the walker gets past (POLICE_WALKING_ON is 1 second)
	third.last_step_at = world.time - 2 SECONDS
	TEST_ASSERT_NULL(outpost_npc_next_step(third), "A colleague who has not moved in two seconds still counts as walking on")
	third.last_step_at = world.time
	// Walking straight into each other, they trade
	third_loop.movement_path = list(second_tile)
	walker.Move(third_tile, EAST)
	TEST_ASSERT_EQUAL(get_turf(walker), third_tile, "Two officers walking into each other in a narrow hall did not trade places")
	TEST_ASSERT_EQUAL(get_turf(third), second_tile, "Walking into each other, only one of the two officers moved")
	GLOB.move_manager.stop_looping(third, SSai_movement)
	qdel(third)

	// With room to, it walks round them, and they stay where they are (the row above the hall's tables, open on its far side)
	var/turf/open_west = locate(x0 + 1, y0 + 3, z0)
	var/turf/open_mid = locate(x0 + 2, y0 + 3, z0)
	walker.forceMove(open_west)
	other.forceMove(open_mid)
	COOLDOWN_RESET(walker, police_swap_cooldown)
	walker.ai_controller.set_movement_target(type, locate(x0 + 4, y0 + 3, z0))
	walker.Move(open_mid, EAST)
	TEST_ASSERT_EQUAL(get_turf(other), open_mid, "With room to walk round them, the colleague in the way was moved")
	TEST_ASSERT(get_turf(walker) != open_west, "With room to walk round a colleague, the officer stood still")
	TEST_ASSERT_EQUAL(walker.x, open_mid.x, "The officer walking round a colleague did not get level with them (at [AREACOORD(walker)])")
	TEST_ASSERT_EQUAL(get_dist(walker, other), 1, "The officer did not walk round the colleague beside them (at [AREACOORD(walker)])")

	// Nobody trades places with the officer making an arrest; it trades with them
	var/mob/living/carbon/human/npc/ambient_npc/outpost/police/lead = police_crowd_runner(second_tile)
	var/mob/living/carbon/human/npc/ambient_npc/outpost/police/passer = police_crowd_runner(first_tile)
	var/obj/structure/overmap/trader_outpost/outpost = wanted_outpost()
	var/datum/outpost_police/police = outpost.police
	police.add_officer(lead)
	police.add_officer(passer)
	var/mob/living/carbon/human/person = wanted_person(hall_end)
	var/datum/outpost_warrant/warrant = police_pin_warrant(police, person.mind, 15)
	var/datum/outpost_police_case/case = new(police, warrant)
	police.cases[person.mind] = case
	lead.case = case
	case.officers = list(WEAKREF(lead))
	TEST_ASSERT_EQUAL(case.arresting(), lead, "Setup: the colleague is not the arresting officer")
	passer.ai_controller.set_movement_target(type, third_tile)
	passer.Move(second_tile, EAST)
	TEST_ASSERT_EQUAL(get_turf(lead), second_tile, "A colleague traded places with the officer making an arrest")
	lead.ai_controller.set_movement_target(type, hall_start)
	lead.Move(first_tile, WEST)
	TEST_ASSERT_EQUAL(get_turf(lead), first_tile, "The officer making an arrest could not get past a colleague in a narrow hall")
	TEST_ASSERT_EQUAL(get_turf(passer), second_tile, "The colleague in the arresting officer's way did not trade places")
	for(var/mob/living/carbon/human/npc/ambient_npc/outpost/police/officer as anything in list(walker, other, lead, passer))
		officer.ai_controller.set_movement_target(type, null)
	lead.case = null
	police.close_case(person.mind)

/// Too close to its target an officer steps back onto a free tile, never into a colleague; boxed in, it stays
/datum/unit_test/voidcrew_outpost_police_crowd_step_back

/datum/unit_test/voidcrew_outpost_police_crowd_step_back/Run()
	var/x0 = run_loc_floor_bottom_left.x
	var/y0 = run_loc_floor_bottom_left.y
	var/z0 = run_loc_floor_bottom_left.z
	var/turf/target_tile = locate(x0 + 1, y0 + 2, z0)
	var/turf/officer_tile = locate(x0 + 2, y0 + 2, z0)
	var/turf/behind = locate(x0 + 3, y0 + 2, z0)
	var/mob/living/carbon/human/target = allocate(/mob/living/carbon/human/consistent, target_tile)
	var/mob/living/carbon/human/npc/ambient_npc/outpost/police/officer = police_crowd_runner(officer_tile)
	TEST_ASSERT_EQUAL(outpost_police_step_back_spot(officer, target), behind, "With nobody behind it, an officer does not step straight back from its target")
	var/mob/living/carbon/human/npc/ambient_npc/outpost/police/colleague = police_crowd_runner(behind)
	var/turf/spot = outpost_police_step_back_spot(officer, target)
	TEST_ASSERT_NOTNULL(spot, "With a colleague behind it and room either side of them, an officer finds nowhere to step back to")
	TEST_ASSERT(spot != behind, "An officer steps back onto the colleague behind it")
	TEST_ASSERT(spot.x > officer_tile.x, "An officer steps back no further from its target")
	// Furniture either side of the colleague: nowhere to go, and it stays
	allocate(/obj/structure/table, locate(x0 + 3, y0 + 1, z0))
	allocate(/obj/structure/table, locate(x0 + 3, y0 + 3, z0))
	TEST_ASSERT_NULL(outpost_police_step_back_spot(officer, target), "Boxed in by a colleague and furniture, an officer still found somewhere to step back to")
	// The behaviour is not taken up at all then, so the officer never stands walking into the colleague
	var/datum/ai_controller/brain = officer.ai_controller
	brain.set_blackboard_key(BB_BASIC_MOB_CURRENT_TARGET, target)
	brain.queue_behavior(/datum/ai_behavior/outpost_police_step_back, BB_BASIC_MOB_CURRENT_TARGET)
	TEST_ASSERT(!brain.current_behaviors[GET_AI_BEHAVIOR(/datum/ai_behavior/outpost_police_step_back)], "Boxed in, an officer still set off stepping back")
	TEST_ASSERT(istype(brain.ai_movement, /datum/ai_movement/jps), "Boxed in, an officer was left on its backing-off movement ([brain.ai_movement?.type])")
	// With the colleague gone, it steps back, and has its pathfinder again after
	qdel(colleague)
	brain.queue_behavior(/datum/ai_behavior/outpost_police_step_back, BB_BASIC_MOB_CURRENT_TARGET)
	TEST_ASSERT(brain.current_behaviors[GET_AI_BEHAVIOR(/datum/ai_behavior/outpost_police_step_back)], "With room behind it, an officer too close to its target did not step back")
	TEST_ASSERT_EQUAL(brain.current_movement_target, behind, "The officer is not stepping straight back")
	brain.CancelActions()
	TEST_ASSERT(istype(brain.ai_movement, /datum/ai_movement/jps), "After stepping back an officer did not have its pathfinder again ([brain.ai_movement?.type])")
	brain.clear_blackboard_key(BB_BASIC_MOB_CURRENT_TARGET)

/// An officer on an alert keeps its pathfinder when a walk of its own ends: it is not put back on the straight chase
/datum/unit_test/voidcrew_outpost_police_crowd_pathfinder

/datum/unit_test/voidcrew_outpost_police_crowd_pathfinder/Run()
	var/obj/structure/overmap/trader_outpost/outpost = wanted_outpost()
	var/datum/outpost_police/police = outpost.police
	var/mob/living/carbon/human/npc/ambient_npc/outpost/police/officer = wanted_officer(outpost, wanted_spot(1, 2))
	officer.setDir(EAST)
	var/mob/living/carbon/human/person = wanted_person(wanted_spot(3, 2))
	police_pin_warrant(police, person.mind, 25)
	var/datum/ai_controller/basic_controller/human_npc/stealth/outpost_police/brain = officer.ai_controller
	brain.stealth_setup()
	brain.stealth_go_alert(person)
	TEST_ASSERT_EQUAL(brain.stealth_state(), "alert", "Setup: the officer is not alert on a two-star suspect")
	TEST_ASSERT(istype(brain.ai_movement, /datum/ai_movement/jps), "An officer gone alert is not on its pathfinder ([brain.ai_movement?.type])")
	// A walk of its own (to where it last saw them) that ends, as any walk does
	var/turf/far = wanted_spot(4, 4)
	brain.goto_dest = far
	brain.goto_turf = far
	brain.queue_behavior(/datum/ai_behavior/stealth_goto)
	TEST_ASSERT(brain.current_behaviors[GET_AI_BEHAVIOR(/datum/ai_behavior/stealth_goto)], "Setup: the officer did not set off on its walk")
	brain.CancelActions()
	TEST_ASSERT_EQUAL(brain.stealth_state(), "alert", "Setup: the officer stopped being alert")
	TEST_ASSERT(istype(brain.ai_movement, /datum/ai_movement/jps), "An alert officer whose walk ended was put back on the straight chase ([brain.ai_movement?.type])")
	brain.clear_blackboard_key(BB_BASIC_MOB_CURRENT_TARGET)
	brain.stealth_go_unaware()
