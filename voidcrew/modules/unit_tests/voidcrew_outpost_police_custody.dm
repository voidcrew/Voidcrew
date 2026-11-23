/**
 * Outpost police tests: trouble from inside a cell, and reaching the warden from one (police_cell.dm, police_bribe.dm,
 * police_life.dm, police_stealth.dm). Built on the cell tests' fixture (voidcrew_outpost_police_cell.dm), the warden's
 * (voidcrew_outpost_police_bribe.dm) and the stealth room (voidcrew_outpost_police_stealth.dm). Fork defines are
 * included after the tests: use literal values with a comment naming the define.
 */

/**
 * The playtest of 2026-11-23: a prisoner at three stars, just uncuffed in a Halcyon cell, shoves the warden down
 * against the cell wall. The warden answers with his baton, the charge is counted quietly and starts the term over,
 * and the officer who sees the warden on the cell floor does not take him for a body: nobody searches, nobody calls an
 * alarm, nobody is at large. With the cell empty a colleague dead on its floor is still a body to find.
 */
/datum/unit_test/voidcrew_stealth_live/police/cell_shove

/datum/unit_test/voidcrew_stealth_live/police/cell_shove/Run()
	TEST_ASSERT(police_room(12, 7), "No room for the test")
	allocate(/obj/effect/landmark/stealth_group, at(0, 6))
	// A cell in the south-west corner: floor (0,0) and (0,1), its door east of the bottom tile, the lobby tile beyond
	var/list/marks = list()
	for(var/dy in 0 to 1)
		var/obj/effect/landmark/outpost_police_cell/mark = allocate(/obj/effect/landmark/outpost_police_cell, at(0, dy))
		mark.cell_id = "test"
		marks += mark
	var/obj/machinery/door/airlock/outpost/glass/police_cell/door = allocate(/obj/machinery/door/airlock/outpost/glass/police_cell, at(1, 0))
	door.cell_id = "test"
	police.build_cells(marks, list(door), list())
	TEST_ASSERT_EQUAL(length(police.cells), 1, "Fixture: the cell was not built")
	var/datum/outpost_police_cell/cell = police.cells[1]
	TEST_ASSERT_EQUAL(cell.outside_turf, at(2, 0), "Fixture: the cell's lobby tile is not across its door")

	var/mob/living/carbon/human/npc/ambient_npc/outpost/police/sergeant/warden = officer_at(0, 0, NORTH, /mob/living/carbon/human/npc/ambient_npc/outpost/police/sergeant)
	var/mob/living/carbon/human/npc/ambient_npc/outpost/police/watcher = officer_at(5, 1, WEST)
	var/datum/ai_controller/basic_controller/human_npc/stealth/outpost_police/warden_brain = warden.ai_controller
	var/datum/ai_controller/basic_controller/human_npc/stealth/outpost_police/watcher_brain = watcher.ai_controller
	warden_brain.stealth_setup()
	watcher_brain.stealth_setup()
	TEST_ASSERT_NOTNULL(watcher_brain.group, "Fixture: the officers patrol in no group")
	TEST_ASSERT_EQUAL(watcher_brain.group, warden_brain.group, "Fixture: the two officers are not one squad")

	var/mob/living/carbon/human/prisoner = visitor_at(0, 1)
	prisoner.physiology.stamina_mod = 1
	var/datum/mind/mind = prisoner.mind
	var/datum/outpost_warrant/warrant = police_pin_warrant(police, mind, 75) // three stars, as in the round
	// Booked on a hold with half a minute to run, the cuffs just off
	cell.admit(prisoner, world.time + 30 SECONDS)
	TEST_ASSERT(police.in_custody(prisoner), "Fixture: a prisoner in the cell is not in custody")
	police.stealth_tick_squad()

	// The shove, tg's own: the warden has the cell wall at his back
	prisoner.setDir(SOUTH)
	prisoner.disarm(warden)
	TEST_ASSERT_EQUAL(warden.body_position, LYING_DOWN, "Fixture: the shove against the wall did not knock the warden down")
	TEST_ASSERT(prisoner.getStaminaLoss() > 0, "The warden did not hit back at a prisoner who shoved him in the cell")
	TEST_ASSERT_EQUAL(warden_brain.stealth_state(), "unaware", "The warden went [warden_brain.stealth_state()] over his own prisoner")
	TEST_ASSERT(!warden_brain.blackboard_key_exists(BB_BASIC_MOB_CURRENT_TARGET), "The warden took his own prisoner for a target")

	// The officer with the cell in view: no body found, no search, no alarm
	watcher_brain.stealth_check_bodies()
	TEST_ASSERT_EQUAL(watcher_brain.stealth_state(), "unaware", "An officer went [watcher_brain.stealth_state()] at the warden knocked down in an occupied cell")
	TEST_ASSERT_NULL(watcher_brain.pending_call, "An officer is calling in the warden knocked down in an occupied cell")
	TEST_ASSERT(!watcher_brain.blackboard["stealth_wary"], "An officer is on edge over the warden knocked down in an occupied cell")

	// The charge is passed on quietly, counts, and starts the term over as a jail term at three stars
	TEST_ASSERT_EQUAL(length(police.pending_reports), 1, "The shove was not reported")
	police.tick_warrants()
	var/datum/outpost_pending_report/report = police.pending_reports[1]
	TEST_ASSERT(report.relay_since, "The warden is not passing the report on")
	report.relay_since -= 4 SECONDS // OUTPOST_POLICE_RADIOLESS_TIME, 3 SECONDS
	police.tick_warrants()
	TEST_ASSERT_EQUAL(warrant.heat, 83, "The shove was not counted as resisting") // OUTPOST_CRIME_RESIST: 8 points
	TEST_ASSERT(cell.jailed[mind], "A crime in the cell left the hold a paid one")
	TEST_ASSERT(cell.prisoners[mind] >= world.time + 4 MINUTES - 1 SECONDS, "A crime in the cell did not start the term over at three stars' time") // OUTPOST_POLICE_JAIL[3]
	TEST_ASSERT(police.in_custody(prisoner), "A crime in the cell let the prisoner out of custody")

	// The squad's calm holds
	police.stealth_tick_squad()
	TEST_ASSERT(!police.stealth_anyone_at_large(), "A prisoner in a cell is at large")
	TEST_ASSERT_EQUAL(police.dispatch_active_level(), 0, "The outpost is on alert over a prisoner in a cell")
	for(var/datum/ai_controller/basic_controller/human_npc/stealth/outpost_police/brain as anything in list(warden_brain, watcher_brain))
		TEST_ASSERT_EQUAL(brain.stealth_state(), "unaware", "An officer is [brain.stealth_state()] after a crime in a cell")
		TEST_ASSERT_NULL(brain.pending_call, "An officer has a call going after a crime in a cell")

	// Knocked out cold on the cell floor, he is still nobody's mystery while the cell holds someone
	warden.Unconscious(1 MINUTES)
	watcher_brain.stealth_check_bodies()
	TEST_ASSERT_EQUAL(watcher_brain.stealth_state(), "unaware", "An officer went [watcher_brain.stealth_state()] at the warden out cold in an occupied cell")

	// The cell empty, a colleague dead on its floor is a body like any other
	cell.forget_prisoner(mind)
	police.warrants -= mind
	qdel(warrant)
	prisoner.forceMove(at(11, 5))
	warden.death()
	var/list/seen = watcher_brain.blackboard["stealth_bodies_seen"] // BB_STEALTH_BODIES_SEEN
	seen -= REF(warden)
	watcher_brain.group.reported_bodies -= REF(warden)
	watcher_brain.clear_blackboard_key(BB_BASIC_MOB_CURRENT_TARGET)
	watcher_brain.stealth_go_unaware()
	watcher_brain.stealth_check_bodies()
	TEST_ASSERT(watcher_brain.stealth_state() != "unaware", "An officer walked past a colleague dead in an empty cell")

/// A crime counted against a prisoner starts their term over as a jail term at their stars, never shorter, with no fine to buy it off; an accomplice's charge does not
/datum/unit_test/voidcrew_outpost_police_cell_crime_inside

/datum/unit_test/voidcrew_outpost_police_cell_crime_inside/Run()
	var/datum/outpost_police/cell_test/police = police_cells_fixture()
	var/datum/outpost_police_cell/cell = police_cell_named(police, "a")
	var/mob/living/carbon/human/prisoner = police_cell_person(cell.tiles[1])
	var/mob/living/carbon/human/officer = police_cell_person(cell.outside_turf)
	var/datum/mind/mind = prisoner.mind
	police_pin_warrant(police, mind, 30)
	police.pinned_stars = 2
	// A paid hold with half a minute left
	cell.admit(prisoner, world.time + 30 SECONDS)
	var/hold_until = cell.prisoners[mind]

	// Their crew's doing is not their own
	police.count_crime(prisoner, "accomplice", derived = TRUE) // OUTPOST_CRIME_ACCOMPLICE
	TEST_ASSERT(!cell.jailed[mind] && cell.prisoners[mind] == hold_until, "An accomplice's charge started a prisoner's term over")

	// A blow on an officer, counted at three stars
	police.pinned_stars = 3
	police.count_crime(prisoner, "resist", officer) // OUTPOST_CRIME_RESIST
	TEST_ASSERT(cell.jailed[mind], "A crime in the cell left the hold a paid one")
	TEST_ASSERT(cell.prisoners[mind] >= world.time + 4 MINUTES - 1 SECONDS && cell.prisoners[mind] <= world.time + 4 MINUTES, "A crime in the cell set [(cell.prisoners[mind] - world.time) / 10] s, not three stars' four minutes") // OUTPOST_POLICE_JAIL[3]
	TEST_ASSERT("cell_more_time" in police.lines, "Nobody told the prisoner their time started over") // POLICE_LINE_CELL_MORE_TIME
	TEST_ASSERT(cell.visit_due[mind], "A hold turned jail term is not on the warden's round")
	TEST_ASSERT(police.in_custody(prisoner), "A crime in the cell let the prisoner out of custody")

	// No fine buys it off
	police.fine_result = TRUE
	var/tries = police.fine_tries
	police.tick_cells()
	TEST_ASSERT(mind in cell.prisoners, "A fine bought off a term earned in the cell")
	TEST_ASSERT_EQUAL(police.fine_tries, tries, "A fine was tried for a term earned in the cell")

	// Never shorter than what was left
	cell.prisoners[mind] = world.time + 9 MINUTES
	police.pinned_stars = 1
	cell.crime_inside(mind)
	TEST_ASSERT(cell.prisoners[mind] >= world.time + 9 MINUTES - 1 SECONDS, "A crime in the cell shortened the term")

	// Carried out with the clock stopped: it starts over when they are back in
	cell.return_by[mind] = world.time + 20 SECONDS // OUTPOST_POLICE_CELL_RETURN
	cell.time_left[mind] = 10 SECONDS
	police.pinned_stars = 4
	cell.crime_inside(mind)
	TEST_ASSERT_EQUAL(cell.time_left[mind], 7 MINUTES, "A crime while out of the cell did not set four stars' time for the return") // OUTPOST_POLICE_JAIL[4]
	cell.return_by -= mind
	cell.time_left -= mind

	// Served, they walk as anyone does
	cell.prisoners[mind] = world.time
	police.tick_cells()
	TEST_ASSERT(!(mind in cell.prisoners), "A term earned in the cell was never over")
	TEST_ASSERT(!length(cell.crimes_inside) && !length(cell.visit_due), "A released prisoner left marks on the cell")

/// A crime counted while the booking is still running is given its term when the booking ends
/datum/unit_test/voidcrew_outpost_police_cell_crime_while_booked

/datum/unit_test/voidcrew_outpost_police_cell_crime_while_booked/Run()
	var/datum/outpost_police/cell_test/police = police_cells_fixture()
	police.pinned_stars = 2
	police.fine_result = TRUE
	var/datum/outpost_police_cell/cell = police.cell_best()
	var/mob/living/carbon/human/suspect = police_cell_person(cell.outside_turf)
	var/mob/living/carbon/human/officer = police_cell_person(get_step(cell.outside_turf, NORTH))
	var/datum/mind/mind = suspect.mind
	police_pin_warrant(police, mind, 30)
	TEST_ASSERT_NOTNULL(police_cell_cuff(suspect, officer), "Setup: the suspect did not get cuffed")
	INVOKE_ASYNC(police, TYPE_PROC_REF(/datum/outpost_police, book), suspect, officer)
	// The cuffs take two seconds to come off (CELL_UNCUFF_TIME): the booking is running
	var/deadline = world.time + 10 SECONDS
	UNTIL(!isnull(cell.booking[mind]) || world.time > deadline)
	TEST_ASSERT(!isnull(cell.booking[mind]), "Setup: the booking never started")
	police.pinned_stars = 3
	cell.crime_inside(mind)
	TEST_ASSERT(!cell.jailed[mind], "A crime during the booking set the term before the booking was over")
	deadline = world.time + 20 SECONDS
	UNTIL(isnull(cell.booking[mind]) || world.time > deadline)
	TEST_ASSERT(isnull(cell.booking[mind]), "Setup: the booking never ended")
	TEST_ASSERT(mind in cell.prisoners, "Setup: the booking did not hold the suspect")
	TEST_ASSERT(cell.jailed[mind], "A fined prisoner who committed a crime while being booked is on a paid hold")
	TEST_ASSERT(cell.prisoners[mind] >= world.time + 4 MINUTES - 5 SECONDS, "A crime during the booking did not set three stars' time") // OUTPOST_POLICE_JAIL[3]
	TEST_ASSERT_EQUAL(cell.bail_due[mind], INFINITY, "A fine can buy off a term earned during the booking")

/// A prisoner who steps out past the officer while being booked is charged once the booking is over, as any walk out of a cell is
/datum/unit_test/voidcrew_outpost_police_cell_walks_past_officer

/datum/unit_test/voidcrew_outpost_police_cell_walks_past_officer/Run()
	var/datum/outpost_police/cell_test/police = police_cells_fixture()
	var/datum/outpost_police_cell/cell = police_cell_named(police, "a")
	var/mob/living/carbon/human/prisoner = police_cell_person(cell.tiles[1])
	var/datum/mind/mind = prisoner.mind
	police_pin_warrant(police, mind, 55)
	cell.admit(prisoner, world.time + 4 MINUTES)
	cell.booking[mind] = world.time
	// Their own step out of the open door, the officer still inside
	SEND_SIGNAL(prisoner, COMSIG_MOB_CLIENT_PRE_MOVE, list())
	prisoner.forceMove(cell.outside_turf)
	police.tick_cells()
	TEST_ASSERT_EQUAL(length(police.crimes), 0, "A prisoner was charged while the booking still ran")
	TEST_ASSERT(police.in_custody(prisoner), "A prisoner being booked is not in custody")
	// The booking ends (book_in()): the next tick finds them gone
	cell.booking -= mind
	police.tick_cells()
	var/list/crime = police_last_crime(police)
	TEST_ASSERT_NOTNULL(crime, "A prisoner who walked out during the booking was never charged")
	TEST_ASSERT_EQUAL(crime[1], prisoner, "The jailbreak was pinned on another")
	TEST_ASSERT_EQUAL(crime[2], "jailbreak", "Walking out during the booking was not a jailbreak") // OUTPOST_CRIME_JAILBREAK
	TEST_ASSERT(!police.in_custody(prisoner), "A prisoner who walked out during the booking is still in custody: nobody would go after them")

/// A prisoner's hand on the cell door, or a word from the cell, brings the warden; he comes once of his own accord a little into a jail term
/datum/unit_test/voidcrew_outpost_police_cell_call

/datum/unit_test/voidcrew_outpost_police_cell_call/Run()
	var/list/fixture = police_bribe_fixture(3)
	var/datum/outpost_police/cell_test/police = fixture[1]
	var/datum/outpost_police_cell/cell = fixture[2]
	var/mob/living/carbon/human/prisoner = fixture[3]
	var/mob/living/carbon/human/npc/ambient_npc/outpost/police/sergeant/warden = fixture[4]
	var/datum/mind/mind = prisoner.mind
	police.officers += warden

	// Someone in the cell who is no prisoner rattles the door: nothing
	var/mob/living/carbon/human/visitor = police_cell_person(cell.tiles[2])
	cell.door.try_to_activate_door(visitor)
	TEST_ASSERT(!(LAZYACCESS(warden.reaction_cooldowns, "cell reply") > world.time), "The warden answered the door for someone who is no prisoner")
	visitor.forceMove(get_step(cell.outside_turf, NORTH))

	// The prisoner tries the door: it stays shut, and the warden answers
	cell.door.try_to_activate_door(prisoner)
	TEST_ASSERT(cell.door.density, "A prisoner's hand opened the cell door")
	TEST_ASSERT(LAZYACCESS(warden.reaction_cooldowns, "cell reply") > world.time, "The warden did not hear a prisoner try the cell door")
	warden.life_answer_cell(WEAKREF(prisoner))
	var/datum/ambient_activity/warden_bribe/visit = warden.activity
	TEST_ASSERT(istype(visit), "The warden did not come to a prisoner who tried the door")
	TEST_ASSERT_EQUAL(visit.spot, cell.outside_turf, "The warden is not coming to the cell door")
	warden.end_activity()
	TEST_ASSERT_EQUAL(length(police.crimes), 0, "Trying the cell door from inside was a crime")

	// A word from the cell does the same, by way of the cell
	LAZYREMOVE(warden.reaction_cooldowns, "cell reply")
	cell.called_out(prisoner)
	TEST_ASSERT(LAZYACCESS(warden.reaction_cooldowns, "cell reply") > world.time, "The warden did not hear a prisoner call out")
	LAZYREMOVE(warden.reaction_cooldowns, "cell reply")
	prisoner.say("Warden!")
	TEST_ASSERT(LAZYACCESS(warden.reaction_cooldowns, "cell reply") > world.time, "The warden did not hear a prisoner speak")
	// Walking into the door is the same as a hand on it
	LAZYREMOVE(warden.reaction_cooldowns, "cell reply")
	cell.door.bumpopen(prisoner)
	TEST_ASSERT(LAZYACCESS(warden.reaction_cooldowns, "cell reply") > world.time, "The warden did not hear a prisoner walk into the cell door")

	// Of his own accord: not before the time, not while anyone wanted is at large, then once
	cell.visit_due[mind] = world.time + 20 SECONDS // OUTPOST_POLICE_BRIBE_FIRST
	police.tick_bribes()
	TEST_ASSERT(!istype(warden.activity, /datum/ambient_activity/warden_bribe), "The warden came by before the prisoner had sat a while")
	cell.visit_due[mind] = world.time
	police.pinned_at_large = TRUE
	police.tick_bribes()
	TEST_ASSERT(!istype(warden.activity, /datum/ambient_activity/warden_bribe), "The warden came by while someone wanted was at large")
	TEST_ASSERT(mind in cell.visit_due, "A visit that could not be made was dropped")
	police.pinned_at_large = FALSE
	police.tick_bribes()
	visit = warden.activity
	TEST_ASSERT(istype(visit), "The warden never came by of his own accord")
	TEST_ASSERT(!(mind in cell.visit_due), "The warden would come by again and again")
	visit.arrived = TRUE
	visit.arrive()
	TEST_ASSERT_EQUAL(police.bribe_offers[mind], 1500, "The warden came by and named no price") // OUTPOST_POLICE_BRIBE_MIN
	warden.end_activity()
	police.tick_bribes()
	TEST_ASSERT(!istype(warden.activity, /datum/ambient_activity/warden_bribe), "The warden came by a second time uncalled")

/**
 * Each of the three outposts as mapped: from his desk the warden answers a prisoner in either cell who tries the door
 * or speaks, sets off for that cell's door within his walk, has a way there, and comes by of his own accord.
 */
/datum/unit_test/voidcrew_outpost_police_warden_reach

/datum/unit_test/voidcrew_outpost_police_warden_reach/Run()
	for(var/outpost_type in list(
		/obj/structure/overmap/trader_outpost/general,
		/obj/structure/overmap/trader_outpost/outfitter,
		/obj/structure/overmap/trader_outpost/black_market,
	))
		var/obj/structure/overmap/trader_outpost/outpost = police_loaded_outpost(outpost_type)
		if(!outpost)
			continue
		var/datum/outpost_police/police = outpost.police
		TEST_ASSERT_NOTNULL(police.desk_turf, "[outpost_type] has no police desk")
		var/mob/living/carbon/human/npc/ambient_npc/outpost/police/sergeant/warden = police_officer(outpost, /mob/living/carbon/human/npc/ambient_npc/outpost/police/sergeant, police.desk_turf)
		var/list/way_access = warden.wear_id?.GetAccess()
		for(var/datum/outpost_police_cell/cell as anything in police.cells)
			var/mob/living/carbon/human/prisoner = police_cell_person(cell.tiles[1])
			var/datum/mind/mind = prisoner.mind
			police_pin_warrant(police, mind, 55)
			cell.admit(prisoner, world.time + 4 MINUTES, TRUE)
			TEST_ASSERT_EQUAL(police.bribe_cell_for(prisoner), cell, "[outpost_type]: a jailed prisoner in [cell.cell_id] cannot be made an offer")
			TEST_ASSERT(get_dist(police.desk_turf, cell.outside_turf) <= 12, "[outpost_type]: [cell.cell_id]'s door is [get_dist(police.desk_turf, cell.outside_turf)] tiles from the desk, past the warden's walk") // OUTPOST_POLICE_BRIBE_WALK_REACH
			for(var/way in list("door", "word"))
				LAZYREMOVE(warden.reaction_cooldowns, "cell reply")
				police.bribe_wait -= mind
				if(way == "door")
					cell.door.try_to_activate_door(prisoner)
				else
					prisoner.say("Warden!")
				TEST_ASSERT(LAZYACCESS(warden.reaction_cooldowns, "cell reply") > world.time, "[outpost_type]: the warden at his desk did not hear [cell.cell_id]'s prisoner ([way])")
				warden.life_answer_cell(WEAKREF(prisoner))
				var/datum/ambient_activity/warden_bribe/visit = warden.activity
				TEST_ASSERT(istype(visit), "[outpost_type]: the warden did not set off for [cell.cell_id] ([way]); he is [warden.activity?.type || "doing nothing"]")
				if(istype(visit))
					TEST_ASSERT_EQUAL(visit.spot, cell.outside_turf, "[outpost_type]: the warden set off for somewhere other than [cell.cell_id]'s door")
				warden.end_activity()
			// Of his own accord
			police.bribe_wait -= mind
			cell.visit_due[mind] = world.time
			police.tick_bribes()
			TEST_ASSERT(istype(warden.activity, /datum/ambient_activity/warden_bribe), "[outpost_type]: the warden never came by [cell.cell_id] of his own accord")
			warden.end_activity()
			cell.forget_prisoner(mind)
			qdel(police.warrants[mind])
			police.warrants -= mind
			qdel(prisoner)
		// A way from the desk to stand by each door (last: the search sleeps, and a warden with nobody about stands down)
		for(var/datum/outpost_police_cell/cell as anything in police.cells)
			var/list/way_there = get_path_to(warden, cell.outside_turf, 40, 1, way_access)
			TEST_ASSERT(length(way_there) || get_dist(warden, cell.outside_turf) <= 1, "[outpost_type]: no way from the desk to [cell.cell_id]'s door")
		qdel(warden)
