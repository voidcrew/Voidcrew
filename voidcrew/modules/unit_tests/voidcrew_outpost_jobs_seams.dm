/**
 * Outpost jobs tests: the seams P0 cut into the police, the checkpoint and the mission shell for
 * voidcrew/modules/outpost_jobs/ (build plan 3.4). Owner: P0. Helpers are in voidcrew_outpost_jobs_helpers.dm.
 * Fork defines are included after the tests: literal values carry a comment naming the define.
 */

/// count_crime() tells its listeners of every counted crime: one under a star and one that adds stars
/datum/unit_test/voidcrew_outpost_jobs_seam_crime_signal

/datum/unit_test/voidcrew_outpost_jobs_seam_crime_signal/Run()
	var/obj/structure/overmap/trader_outpost/outpost = jobs_outpost()
	var/datum/outpost_police/police = outpost.police
	var/datum/jobs_test_listener/listener = allocate(/datum/jobs_test_listener)
	listener.listen(police, "outpost_police_crime") // COMSIG_OUTPOST_POLICE_CRIME
	var/mob/living/carbon/human/victim = jobs_person(jobs_spot(1, 0))
	var/mob/living/carbon/human/offender = jobs_person(jobs_spot(0, 0))

	TEST_ASSERT_EQUAL(police.count_crime(offender, "unarmed", victim), 0, "Setup: one punch is not still under a star") // OUTPOST_CRIME_ASSAULT_UNARMED
	TEST_ASSERT_EQUAL(length(listener.heard), 1, "A counted crime under one star sent no crime signal")
	var/list/first = listener.last()
	TEST_ASSERT_EQUAL(first[1], offender.mind, "The crime signal named the wrong mind")
	TEST_ASSERT_EQUAL(first[2], "unarmed", "The crime signal named the wrong crime")
	TEST_ASSERT_EQUAL(first[3], victim, "The crime signal named the wrong victim")
	TEST_ASSERT_EQUAL(first[4], 0, "The crime signal gave the wrong stars after")
	TEST_ASSERT(!first[5], "A first-hand crime was sent as derived")

	TEST_ASSERT_EQUAL(police.count_crime(offender, "shot", victim), 2, "Setup: a shot on top of a punch is not two stars") // OUTPOST_CRIME_ASSAULT_SHOT
	TEST_ASSERT_EQUAL(length(listener.heard), 2, "A crime that added stars sent no crime signal")
	var/list/second = listener.last()
	TEST_ASSERT_EQUAL(second[2], "shot", "The second crime signal named the wrong crime")
	TEST_ASSERT_EQUAL(second[4], 2, "The second crime signal gave the wrong stars after")

	police.count_crime(offender, "civilian_kill", victim, derived = TRUE) // OUTPOST_CRIME_KILL_CIVILIAN
	TEST_ASSERT_EQUAL(length(listener.heard), 3, "A derived crime sent no crime signal")
	var/list/third = listener.last()
	TEST_ASSERT(third[5], "A derived crime was not sent as derived")

	// The new crime is on the table: 12 points, ceiling two stars, floor one
	TEST_ASSERT_EQUAL(police.heat_after(0, "sabotage"), 12, "Sabotage from nothing is not 12 heat") // OUTPOST_CRIME_SABOTAGE, OUTPOST_POLICE_STAR_HEAT[1] = 10
	TEST_ASSERT_EQUAL(police.heat_after(40, "sabotage"), 49, "Sabotage went past its two-star ceiling") // OUTPOST_POLICE_STAR_HEAT[3] - 1

/// pending_noise() is above 0 while a report waits on its witness, for the offender or against the victim, and 0 once it lands or lapses
/datum/unit_test/voidcrew_outpost_jobs_seam_pending_noise

/datum/unit_test/voidcrew_outpost_jobs_seam_pending_noise/Run()
	var/obj/structure/overmap/trader_outpost/outpost = jobs_outpost()
	var/datum/outpost_police/police = outpost.police
	var/datum/outpost_police_perception/jobs_test/witness_switch = jobs_witness(outpost)
	witness_switch.delay = 3 SECONDS
	var/mob/living/carbon/human/victim = jobs_person(jobs_spot(1, 0))
	var/mob/living/carbon/human/puncher = jobs_person(jobs_spot(0, 0))
	var/mob/living/carbon/human/shooter = jobs_person(jobs_spot(0, 1))
	var/mob/living/carbon/human/bystander = jobs_person(jobs_spot(3, 3))

	TEST_ASSERT_EQUAL(police.pending_noise(list(puncher.mind), list(victim)), 0, "Nothing waiting, and pending_noise() is not 0")
	TEST_ASSERT_NULL(police.report_crime(puncher, "unarmed", victim), "Setup: a report with a delay counted at once") // OUTPOST_CRIME_ASSAULT_UNARMED
	TEST_ASSERT_EQUAL(length(police.pending_reports), 1, "Setup: the report is not waiting")
	TEST_ASSERT_EQUAL(police.pending_noise(list(puncher.mind), null), 1, "A waiting punch is not noise for its offender")
	TEST_ASSERT_EQUAL(police.pending_noise(null, list(victim)), 1, "A waiting punch is not noise against its victim")
	TEST_ASSERT_EQUAL(police.pending_noise(list(bystander.mind), list(bystander)), 0, "A report about others is noise for a bystander")

	// It lands: nothing waits any more
	var/datum/outpost_pending_report/landed = police.pending_reports[1]
	landed.due = world.time
	police.process_pending_reports()
	TEST_ASSERT_EQUAL(length(police.pending_reports), 0, "Setup: the due report did not land")
	TEST_ASSERT_EQUAL(police.pending_noise(list(puncher.mind), list(victim)), 0, "A report that landed is still waiting noise")

	// A shot waits on a witness who is out cold: two stars' worth, until it lapses
	witness_switch.can_report_now = FALSE
	TEST_ASSERT_NULL(police.report_crime(shooter, "shot", victim), "Setup: a delayed shot counted at once") // OUTPOST_CRIME_ASSAULT_SHOT
	var/datum/outpost_pending_report/waiting = police.pending_reports[1]
	waiting.due = world.time
	police.process_pending_reports()
	TEST_ASSERT_EQUAL(length(police.pending_reports), 1, "Setup: a report was dropped while its witness might still come round")
	TEST_ASSERT_EQUAL(police.pending_noise(list(shooter.mind), null), 2, "A waiting shot is not two stars' noise") // 25 heat
	TEST_ASSERT_EQUAL(police.pending_noise(null, list(victim)), 2, "A waiting shot is not two stars' noise against its victim")
	waiting.expires = world.time
	police.process_pending_reports()
	TEST_ASSERT_EQUAL(length(police.pending_reports), 0, "Setup: the report never lapsed")
	TEST_ASSERT_EQUAL(police.pending_noise(list(shooter.mind), list(victim)), 0, "A report that lapsed is still waiting noise")

/// A cell holding a ward: the door can be forced, forcing it is a jailbreak and says so, a ward is no stray, and a player can still be booked in
/datum/unit_test/voidcrew_outpost_jobs_seam_cell_ward

/datum/unit_test/voidcrew_outpost_jobs_seam_cell_ward/Run()
	var/obj/structure/overmap/trader_outpost/outpost = jobs_outpost()
	var/datum/outpost_police/police = outpost.police
	var/datum/outpost_police_cell/cell = jobs_cells(police)
	TEST_ASSERT_NOTNULL(cell, "No test cell")
	var/datum/jobs_test_listener/crimes = allocate(/datum/jobs_test_listener)
	crimes.listen(police, "outpost_police_crime") // COMSIG_OUTPOST_POLICE_CRIME
	var/datum/jobs_test_listener/forced = allocate(/datum/jobs_test_listener)
	forced.listen(police, "outpost_police_cell_forced") // COMSIG_OUTPOST_POLICE_CELL_FORCED

	TEST_ASSERT(cell.door.density, "Setup: the empty cell's door is open")
	TEST_ASSERT(!cell.still_forceable(), "A crowbar works on an empty cell")
	TEST_ASSERT_EQUAL(police.cell_for_ward(), cell, "The emptiest cell is not the first cell")

	var/mob/living/carbon/human/ward = allocate(/mob/living/carbon/human/consistent, cell.tiles[1])
	TEST_ASSERT(cell.hold_ward(ward), "A cell would not hold a ward")
	TEST_ASSERT_EQUAL(cell.ward_count(), 1, "A held ward is not counted")
	TEST_ASSERT_EQUAL(police.cell_of_ward(ward), cell, "The police cannot find the ward's cell")
	TEST_ASSERT(police.cell_for_ward() != cell, "The next ward goes to the cell that already holds one")
	TEST_ASSERT(!cell.stray_inside(), "A ward is taken for a stray")
	TEST_ASSERT(cell.still_forceable(), "A crowbar does not work on a cell holding a ward")
	police.tick_cells()
	TEST_ASSERT(cell.door.density, "The cell opened for its ward as if for a stray")

	// A player can still be booked into the same cell
	var/mob/living/carbon/human/prisoner = jobs_person(cell.tiles[2])
	cell.admit(prisoner, world.time + 1800, TRUE)
	TEST_ASSERT(prisoner.mind in cell.prisoners, "A player could not be admitted to a cell holding a ward")
	cell.forget_prisoner(prisoner.mind)
	prisoner.forceMove(jobs_spot(4, 2))

	// Forcing the door: 12 s, then a jailbreak on the forcer and the forced signal
	var/mob/living/carbon/human/breaker = jobs_person(cell.outside_turf)
	var/obj/item/crowbar/crowbar = allocate(/obj/item/crowbar)
	TEST_ASSERT_EQUAL(cell.door.crowbar_act(breaker, crowbar), ITEM_INTERACT_SUCCESS, "A crowbar on the door of a cell holding a ward did not start")
	TEST_ASSERT(cell.forcing, "The cell is not being forced")
	sleep(14 SECONDS) // OUTPOST_POLICE_CELL_FORCE_TIME is 12 s
	TEST_ASSERT(!cell.door.density, "The forced door did not open")
	var/list/crime = crimes.last()
	TEST_ASSERT_NOTNULL(crime, "Forcing a ward's cell counted no crime")
	TEST_ASSERT_EQUAL(crime[1], breaker.mind, "The jailbreak was pinned on another")
	TEST_ASSERT_EQUAL(crime[2], "jailbreak", "Forcing a ward's cell was not a jailbreak") // OUTPOST_CRIME_JAILBREAK
	var/list/forcing = forced.last()
	TEST_ASSERT_NOTNULL(forcing, "Forcing the door sent no forced signal")
	TEST_ASSERT_EQUAL(forcing[1], cell, "The forced signal named the wrong cell")
	TEST_ASSERT_EQUAL(forcing[2], breaker, "The forced signal named the wrong forcer")

	// Dropped and deleted wards leave the list
	cell.drop_ward(ward)
	TEST_ASSERT_EQUAL(cell.ward_count(), 0, "A dropped ward is still counted")
	var/mob/living/carbon/human/second_ward = allocate(/mob/living/carbon/human/consistent, cell.tiles[1])
	cell.hold_ward(second_ward)
	qdel(second_ward)
	TEST_ASSERT_EQUAL(cell.ward_count(), 0, "A deleted ward is still counted")

/// The checkpoint refuses a live job case like a weapon, says so, and still misses it in a smuggler's bag
/datum/unit_test/voidcrew_trader_checkpoint/outpost_jobs_cargo

/datum/unit_test/voidcrew_trader_checkpoint/outpost_jobs_cargo/Destroy()
	GLOB.fixer_test_contraband.Cut()
	return ..()

/datum/unit_test/voidcrew_trader_checkpoint/outpost_jobs_cargo/Run()
	TEST_ASSERT(fixture(), "Could not prepare the checkpoint")
	var/mob/living/carbon/human/person = visitor(chamber[1])
	var/obj/item/folder/case = allocate(/obj/item/folder, person)
	TEST_ASSERT(!length(checkpoint.inspect_chamber()), "Setup: an ordinary folder is refused")
	GLOB.fixer_test_contraband += case
	var/list/refused = checkpoint.inspect_chamber()
	TEST_ASSERT_EQUAL(refused[person], "checkpoint_cargo", "A live job case was not refused as cargo") // CHECKPOINT_LINE_CARGO
	TEST_ASSERT(sensor.machine_line("checkpoint_cargo"), "The wall scanner has nothing to say about cargo")
	TEST_ASSERT(guard.shop.get_line("checkpoint_cargo"), "The guard has nothing to say about cargo")

	// A weapon outranks the case, either way round
	var/obj/item/gun/ballistic/automatic/pistol/pistol = allocate(/obj/item/gun/ballistic/automatic/pistol, person)
	refused = checkpoint.inspect_chamber()
	TEST_ASSERT_EQUAL(refused[person], "checkpoint_armed", "A case hid the gun beside it") // CHECKPOINT_LINE_ARMED
	qdel(pistol)

	TEST_ASSERT(scan_now(person), "Could not start a scan")
	TEST_ASSERT_EQUAL(checkpoint.state, "rejecting", "A live job case passed the scan") // CHECKPOINT_REJECTING
	settle()

	// In a smuggler's bag it is not seen
	var/obj/item/storage/backpack/bag = allocate(/obj/item/storage/backpack, person)
	ADD_TRAIT(bag, TRAIT_CONTRABAND_BLOCKER, TRAIT_GENERIC)
	case.forceMove(bag)
	TEST_ASSERT(!length(checkpoint.inspect_chamber()), "Contraband-shielded storage lost its shielding for a job case")

// ===== THE MISSION NOTICE =====

/// A plain mission for the notice test: no generation, a ship notice written down
/datum/mission/outpost_jobs_seam_test
	name = "Seam test haul"

/datum/mission/outpost_jobs_seam_test/generate_mission_details()
	return

/// It writes down that finish_mission() asked it for the notice
/datum/mission/outpost_jobs_seam_test/hooked
	var/notified_with = -1

/datum/mission/outpost_jobs_seam_test/hooked/notify_completed(reputation_gain)
	notified_with = reputation_gain
	return ..()

/obj/structure/overmap/ship/outpost_jobs_seam_test
	/// list(message, category) for each notice
	var/list/notices = list()

/obj/structure/overmap/ship/outpost_jobs_seam_test/ship_notify(message, category = "ALERT", alert_level = 1, sound_file = null, volume = 100, anywhere = FALSE) // SHIP_NOTIFY_NOTICE
	notices += list(list(message, category))

/// notify_completed() says what finish_mission() always said, and finish_mission() asks it
/datum/unit_test/voidcrew_outpost_jobs_seam_notice
	var/old_accepting

/datum/unit_test/voidcrew_outpost_jobs_seam_notice/New()
	. = ..()
	old_accepting = SSmetrics.accepting
	SSmetrics.accepting = FALSE

/datum/unit_test/voidcrew_outpost_jobs_seam_notice/Destroy()
	SSmetrics.accepting = old_accepting
	return ..()

/datum/unit_test/voidcrew_outpost_jobs_seam_notice/Run()
	var/obj/structure/overmap/ship/outpost_jobs_seam_test/ship = allocate(/obj/structure/overmap/ship/outpost_jobs_seam_test)
	ship.ship_account = allocate(/datum/bank_account, "Jobs notice test", null, 1, FALSE)
	var/datum/mission/outpost_jobs_seam_test/mission = allocate(/datum/mission/outpost_jobs_seam_test)
	mission.servant = ship
	mission.value = 500
	mission.notify_completed(2)
	TEST_ASSERT_EQUAL(length(ship.notices), 1, "notify_completed() sent [length(ship.notices)] notices, not one")
	var/list/notice = ship.notices[1]
	TEST_ASSERT_EQUAL(notice[1], "Seam test haul completed! Reward: 500 credits. Reputation +2.", "The completion notice changed")
	TEST_ASSERT_EQUAL(notice[2], "MISSION COMPLETE", "The completion notice's category changed")
	mission.value = 0
	mission.notify_completed(0)
	notice = ship.notices[2]
	TEST_ASSERT_EQUAL(notice[1], "Seam test haul completed! Reward: settled.", "The notice for a mission that paid nothing changed")
	mission.servant = null

	var/datum/mission/outpost_jobs_seam_test/hooked/finished = new
	finished.servant = ship
	finished.value = 300
	ship.active_missions += finished
	finished.finish_mission(run_loc_floor_bottom_left)
	TEST_ASSERT_EQUAL(finished.notified_with, 0, "finish_mission() did not ask notify_completed() for the notice")
	TEST_ASSERT_EQUAL(length(ship.notices), 3, "finish_mission() sent [length(ship.notices) - 2] notices, not one")
	notice = ship.notices[3]
	TEST_ASSERT_EQUAL(notice[1], "Seam test haul completed! Reward: 300 credits.", "finish_mission()'s notice changed")
	TEST_ASSERT(!(finished in ship.active_missions), "A finished mission is still on the ship")
