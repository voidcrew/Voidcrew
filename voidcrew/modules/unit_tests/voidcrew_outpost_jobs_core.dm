/**
 * Outpost jobs tests: the job shell, the ledger, placement and goods (voidcrew/modules/outpost_jobs/). Owner: P2.
 * Helpers are in voidcrew_outpost_jobs_helpers.dm. Fork defines are included after the tests: use literal values
 * with a comment naming the define.
 *
 * Inputs are pinned: crimes are sent by calling count_crime() directly, the port level by the ledger's
 * test_port_level. Tests are compiled before outpost_jobs, so none overrides a proc of it: they use the base job
 * type with `test_stage_result` set, and call begin_job() with the ship and crew set by hand.
 */

/// Every P2 test: the mission metrics stay out of the database
/datum/unit_test/voidcrew_outpost_jobs_core
	abstract_type = /datum/unit_test/voidcrew_outpost_jobs_core
	var/old_accepting

/datum/unit_test/voidcrew_outpost_jobs_core/New()
	. = ..()
	old_accepting = SSmetrics.accepting
	SSmetrics.accepting = FALSE

/datum/unit_test/voidcrew_outpost_jobs_core/Destroy()
	SSmetrics.accepting = old_accepting
	return ..()

/// A started base fixer job at `outpost` for `ship`'s crew, its roster fixed and its ledger listening
/datum/unit_test/voidcrew_outpost_jobs_core/proc/core_job(obj/structure/overmap/trader_outpost/outpost, obj/structure/overmap/ship/ship, base_pay = 1000)
	var/datum/mission/fixer_job/job = allocate(/datum/mission/fixer_job)
	job.base_pay = base_pay
	job.job_outpost = outpost
	TEST_ASSERT(job.bind_target(), "A fixer job did not bind its outpost")
	job.servant = ship
	job.accepting_crew = ship.get_crew_record()
	job.active = TRUE
	job.time_started = world.time
	job.test_stage_result = TRUE
	TEST_ASSERT(job.begin_job(), "A fixer job with room did not start")
	TEST_ASSERT_NOTNULL(job.ledger, "A started fixer job has no ledger")
	return job

/// Each reading on its own: the crew's stars, an outsider's stars against a job atom, the port at the deed
/datum/unit_test/voidcrew_outpost_jobs_core/readings

/datum/unit_test/voidcrew_outpost_jobs_core/readings/Run()
	var/obj/structure/overmap/trader_outpost/outpost = jobs_outpost()
	var/datum/outpost_police/police = outpost.police
	var/mob/living/carbon/human/crewman = jobs_person(jobs_spot(0, 0))
	var/mob/living/carbon/human/outsider = jobs_person(jobs_spot(1, 0))
	var/mob/living/carbon/human/bystander = jobs_person(jobs_spot(2, 0))
	var/mob/living/carbon/human/mark = jobs_person(jobs_spot(3, 0))
	var/obj/structure/overmap/ship/ship = jobs_ship(list(crewman))

	// Crew alone
	var/datum/mission/fixer_job/crew_job = core_job(outpost, ship)
	TEST_ASSERT_EQUAL(crew_job.noise(), 0, "A job with nothing counted is not silent")
	police.count_crime(crewman, "unarmed", bystander) // OUTPOST_CRIME_ASSAULT_UNARMED
	TEST_ASSERT_EQUAL(crew_job.ledger.crew_reading, 0, "Setup: a punch was over a star")
	TEST_ASSERT_EQUAL(crew_job.noise(), 1, "A counted crime under a star by the crew is not noise 1")
	police.count_crime(crewman, "shot", bystander) // OUTPOST_CRIME_ASSAULT_SHOT
	TEST_ASSERT_EQUAL(crew_job.ledger.crew_reading, 2, "The crew reading did not take the crew's two stars")
	TEST_ASSERT_EQUAL(crew_job.ledger.scene_reading, 0, "A crime against a bystander was read as the scene")
	TEST_ASSERT_EQUAL(crew_job.noise(), 2, "Two stars on the crew is not noise 2")
	qdel(crew_job)

	// Scene alone: an outsider's crime against a job atom counts, against anything else it does not
	var/datum/mission/fixer_job/scene_job = core_job(outpost, ship)
	scene_job.track(mark)
	police.count_crime(outsider, "unarmed", bystander) // OUTPOST_CRIME_ASSAULT_UNARMED
	TEST_ASSERT_EQUAL(scene_job.noise(), 0, "An outsider's crime against a bystander counted for the job")
	police.count_crime(outsider, "shot", mark) // OUTPOST_CRIME_ASSAULT_SHOT
	TEST_ASSERT_EQUAL(scene_job.ledger.crew_reading, 0, "An outsider's crime was read as the crew's")
	TEST_ASSERT_EQUAL(scene_job.ledger.scene_reading, 2, "An outsider's two stars against the job's mark were not the scene reading")
	TEST_ASSERT_EQUAL(scene_job.noise(), 2, "The scene reading did not set the noise")
	qdel(scene_job)

	// A crime of the job's own kind counts by anyone, against anything
	var/datum/mission/fixer_job/kind_job = core_job(outpost, ship)
	kind_job.scene_crimes = list("gate_tamper") // OUTPOST_CRIME_GATE_TAMPER
	var/mob/living/carbon/human/tamperer = jobs_person(jobs_spot(4, 0))
	police.count_crime(tamperer, "gate_tamper") // OUTPOST_CRIME_GATE_TAMPER
	TEST_ASSERT(kind_job.ledger.counted, "A crime of the job's own kind was not counted")
	qdel(kind_job)

	// Port alone: read at the deed
	var/datum/mission/fixer_job/port_job = core_job(outpost, ship)
	port_job.ledger.test_port_level = 3
	TEST_ASSERT_EQUAL(port_job.noise(), 0, "The port was read before the deed")
	TEST_ASSERT(port_job.mark_deed(crewman), "The crew's deed did not count")
	port_job.ledger.test_port_level = 0
	TEST_ASSERT_EQUAL(port_job.ledger.port_reading, 3, "The port reading was not taken at the deed")
	TEST_ASSERT_EQUAL(port_job.noise(), 3, "A loud port at the deed is not noise 3")
	qdel(port_job)

	jobs_cleanup(list(ship))

/// A noise floor (the jailbreak's three stars) takes its stars off the top; nothing over it is silent
/datum/unit_test/voidcrew_outpost_jobs_core/floor

/datum/unit_test/voidcrew_outpost_jobs_core/floor/Run()
	var/obj/structure/overmap/trader_outpost/outpost = jobs_outpost()
	var/mob/living/carbon/human/crewman = jobs_person(jobs_spot(0, 0))
	var/obj/structure/overmap/ship/ship = jobs_ship(list(crewman))

	var/datum/mission/fixer_job/at_floor = core_job(outpost, ship)
	at_floor.noise_floor = 3 // FIXER_JAILBREAK_FLOOR
	at_floor.ledger.test_port_level = 3
	at_floor.mark_deed(crewman)
	TEST_ASSERT_EQUAL(at_floor.noise(), 0, "Three stars on a job with a floor of three is not silent")
	qdel(at_floor)

	var/datum/mission/fixer_job/over_floor = core_job(outpost, ship)
	over_floor.noise_floor = 3 // FIXER_JAILBREAK_FLOOR
	over_floor.ledger.test_port_level = 5
	over_floor.mark_deed(crewman)
	TEST_ASSERT_EQUAL(over_floor.noise(), 2, "Five stars over a floor of three is not noise 2")
	qdel(over_floor)

	jobs_cleanup(list(ship))

/// The roster is fixed at accept: a crewmate who left the crew still counts, and an outsider's deed spoils the job
/datum/unit_test/voidcrew_outpost_jobs_core/roster

/datum/unit_test/voidcrew_outpost_jobs_core/roster/Run()
	var/obj/structure/overmap/trader_outpost/outpost = jobs_outpost()
	var/datum/outpost_police/police = outpost.police
	var/mob/living/carbon/human/crewman = jobs_person(jobs_spot(0, 0))
	var/mob/living/carbon/human/leaver = jobs_person(jobs_spot(1, 0))
	var/mob/living/carbon/human/outsider = jobs_person(jobs_spot(2, 0))
	var/mob/living/carbon/human/bystander = jobs_person(jobs_spot(3, 0))
	var/obj/structure/overmap/ship/ship = jobs_ship(list(crewman, leaver))

	var/datum/mission/fixer_job/job = core_job(outpost, ship)
	leaver.mind.leave_reputation_crew()
	TEST_ASSERT_NULL(leaver.mind.get_reputation_crew(), "Setup: the leaver is still on the crew")
	TEST_ASSERT(job.on_roster(leaver.mind), "A crewmate who left after the accept is off the roster")
	TEST_ASSERT(!job.on_roster(outsider.mind), "An outsider is on the roster")
	police.count_crime(leaver, "shot", bystander) // OUTPOST_CRIME_ASSAULT_SHOT
	TEST_ASSERT_EQUAL(job.ledger.crew_reading, 2, "A crewmate who left still carries the job's stars, and they were not counted")

	// The hands rule: an outsider's deed spoils, no player's deed counts for the crew
	TEST_ASSERT(!job.mark_deed(outsider), "An outsider's deed counted for the crew")
	TEST_ASSERT(job.failed, "An outsider's deed did not spoil the job")
	TEST_ASSERT_EQUAL(job.fail_reason, "spoiled", "An outsider's deed failed the job for the wrong reason") // FIXER_FAIL_SPOILED

	var/datum/mission/fixer_job/unseen = core_job(outpost, ship)
	TEST_ASSERT(unseen.mark_deed(null), "A deed with no player behind it did not count for the crew")
	TEST_ASSERT(unseen.deed_done && !unseen.failed, "A deed with no player behind it did not finish the job's deed")
	qdel(unseen)

	jobs_cleanup(list(ship))

/// A report still on its way blocks the pay; once it lands the crew is paid into the ship's account, with no reputation
/datum/unit_test/voidcrew_outpost_jobs_core/pay

/datum/unit_test/voidcrew_outpost_jobs_core/pay/Run()
	var/obj/structure/overmap/trader_outpost/outpost = jobs_outpost()
	var/datum/outpost_police/police = outpost.police
	var/datum/outpost_police_perception/jobs_test/witness_switch = jobs_witness(outpost)
	var/mob/living/carbon/human/crewman = jobs_person(jobs_spot(0, 0))
	var/mob/living/carbon/human/outsider = jobs_person(jobs_spot(1, 0))
	var/mob/living/carbon/human/bystander = jobs_person(jobs_spot(2, 0))
	var/mob/living/carbon/human/npc/ambient_npc/outpost/fixer/fixer = allocate(/mob/living/carbon/human/npc/ambient_npc/outpost/fixer, jobs_spot(1, 1))
	var/obj/structure/overmap/ship/ship = jobs_ship(list(crewman), 0)
	var/datum/voidcrew_crew_record/record = ship.get_crew_record()
	var/reputation_before = record.reputation

	var/datum/mission/fixer_job/job = core_job(outpost, ship)
	TEST_ASSERT_NULL(job.work_receipt, "A fixer job made a work receipt, so it pays trade reputation")
	TEST_ASSERT_EQUAL(job.can_pay(crewman, fixer), "nothing", "A job whose deed is not done can be paid") // FIXER_LINE_NOTHING
	job.mark_deed(crewman)
	TEST_ASSERT_EQUAL(job.can_pay(outsider, fixer), "not_yours", "An outsider can collect the crew's pay") // FIXER_LINE_NOT_YOURS

	witness_switch.delay = 3 SECONDS
	TEST_ASSERT_NULL(police.report_crime(crewman, "unarmed", bystander), "Setup: a report with a delay counted at once") // OUTPOST_CRIME_ASSAULT_UNARMED
	TEST_ASSERT_EQUAL(job.can_pay(crewman, fixer), "wait", "A report still on its way did not hold the pay") // FIXER_LINE_WAIT
	TEST_ASSERT_EQUAL(job.pay_out(crewman, fixer), 0, "A report still on its way did not stop the pay")
	var/datum/outpost_pending_report/landed = police.pending_reports[1]
	landed.due = world.time
	police.process_pending_reports()
	TEST_ASSERT_NULL(job.can_pay(crewman, fixer), "The crew still cannot be paid once the report landed")

	var/expected = fixer_job_pay(1000, job.pay_zone(), 1)
	// The real pay path writes the fixer_job_paid row (job_admin.dm), with what was paid and the noise
	var/list/old_pending = SSmetrics.pending
	SSmetrics.pending = list()
	SSmetrics.accepting = TRUE
	var/paid = job.pay_out(crewman, fixer)
	SSmetrics.accepting = FALSE
	var/list/paid_rows = list()
	for(var/list/row as anything in SSmetrics.pending)
		if(row["event"] == "fixer_job_paid")
			paid_rows += list(row)
	SSmetrics.pending = old_pending
	TEST_ASSERT_EQUAL(length(paid_rows), 1, "Paying a job wrote [length(paid_rows)] fixer_job_paid rows, not one")
	var/list/paid_row = paid_rows[1]
	TEST_ASSERT_EQUAL(paid_row["credits"], expected, "The fixer_job_paid row does not carry what was paid")
	TEST_ASSERT_EQUAL(paid_row["points"], 1, "The fixer_job_paid row does not carry the noise the job was paid at")
	TEST_ASSERT_EQUAL(paid, expected, "The pay for a punch under a star is not the noise-1 rate")
	TEST_ASSERT(job.completed, "A paid job is not completed")
	TEST_ASSERT_EQUAL(job.noise(), 1, "A paid job forgot the noise it was paid at")
	TEST_ASSERT_EQUAL(ship.ship_account.account_balance, expected, "The pay did not reach the ship's account")
	TEST_ASSERT_EQUAL(record.reputation, reputation_before, "A fixer job changed the crew's trade reputation")

	jobs_cleanup(list(ship))

/// The pay table: every job at noise 0 and 3+ in each zone, against the spec's figures (base x zone x 1.6 clean, rounded to 10)
/datum/unit_test/voidcrew_outpost_jobs_core/pay_table

/datum/unit_test/voidcrew_outpost_jobs_core/pay_table/Run()
	// type = list(green loud, green clean, yellow loud, yellow clean, red loud, red clean)
	var/list/table = list(
		/datum/mission/fixer_job/sabotage = list(800, 1280, 1360, 2180, 2080, 3330),
		/datum/mission/fixer_job/smuggle = list(600, 960, 1020, 1630, 1560, 2500),
		/datum/mission/fixer_job/breakin = list(1200, 1920, 2040, 3260, 3120, 4990),
		/datum/mission/fixer_job/hit = list(1500, 2400, 2550, 4080, 3900, 6240),
		/datum/mission/fixer_job/breakin/evidence = list(1600, 2560, 2720, 4350, 4160, 6660),
		/datum/mission/fixer_job/jailbreak = list(2400, 3840, 4080, 6530, 6240, 9980),
	)
	for(var/datum/mission/fixer_job/kind as anything in table)
		var/list/row = table[kind]
		var/base = initial(kind.base_pay)
		for(var/zone in 1 to 3) // ZONE_GREEN to ZONE_RED
			TEST_ASSERT_EQUAL(fixer_job_pay(base, zone, 3), row[zone * 2 - 1], "[kind] in zone [zone], loud, does not pay the table's figure")
			TEST_ASSERT_EQUAL(fixer_job_pay(base, zone, 0), row[zone * 2], "[kind] in zone [zone], quiet, does not pay the table's figure")
	TEST_ASSERT_EQUAL(fixer_job_pay(1500, 1, 1), 2040, "A green hit with some noise does not pay 60% of the bonus")
	TEST_ASSERT_EQUAL(fixer_job_pay(800, 1, 2), 920, "Green sabotage at noise 2 does not pay 25% of the bonus")
	TEST_ASSERT_EQUAL(fixer_job_pay(800, 1, 7), 800, "Noise past 3 paid more than the base")
	TEST_ASSERT_EQUAL(fixer_credits_text(9980), "9,980", "The receipt's figure has no thousands separator")

/// The deadline stops at the deed and the collect backstop takes over; a shut port holds the deadline off
/datum/unit_test/voidcrew_outpost_jobs_core/deadline

/datum/unit_test/voidcrew_outpost_jobs_core/deadline/Run()
	var/obj/structure/overmap/trader_outpost/outpost = jobs_outpost()
	var/mob/living/carbon/human/crewman = jobs_person(jobs_spot(0, 0))
	var/obj/structure/overmap/ship/ship = jobs_ship(list(crewman))

	var/datum/mission/fixer_job/done = core_job(outpost, ship)
	done.timeout_timer = addtimer(CALLBACK(done, TYPE_PROC_REF(/datum/mission, on_timeout)), 20 MINUTES, TIMER_STOPPABLE)
	done.mark_deed(crewman)
	TEST_ASSERT(timeleft(done.timeout_timer) > 50 MINUTES, "The deadline did not give way to the hour's backstop at the deed") // FIXER_COLLECT_TIME
	qdel(done)

	var/datum/mission/fixer_job/held = core_job(outpost, ship)
	var/datum/outpost_recovery/recovery = outpost.ensure_recovery()
	recovery.port_shut_until = world.time + 10 MINUTES
	held.on_timeout()
	TEST_ASSERT(!held.failed, "A deadline fell while the port was shut")
	TEST_ASSERT(held.timeout_timer && abs(timeleft(held.timeout_timer) - 5 MINUTES) <= 10, "A held deadline was not put off five minutes") // FIXER_DEADLINE_HOLD
	recovery.port_shut_until = 0
	held.on_timeout()
	TEST_ASSERT(held.failed, "A deadline did not fall once the port opened")
	TEST_ASSERT_EQUAL(held.fail_reason, "deadline", "A missed deadline failed for the wrong reason") // FIXER_FAIL_DEADLINE

	var/datum/mission/fixer_job/unstaged = allocate(/datum/mission/fixer_job)
	unstaged.job_outpost = outpost
	unstaged.bind_target()
	unstaged.servant = ship
	unstaged.accepting_crew = ship.get_crew_record()
	unstaged.active = TRUE
	TEST_ASSERT(!unstaged.begin_job(), "A job with no room started")
	TEST_ASSERT_EQUAL(unstaged.fail_reason, "staging", "A job with no room failed for the wrong reason") // FIXER_FAIL_STAGING

	jobs_cleanup(list(ship))

/// unstage() leaves nothing of the job; a job person is the outpost's and refuses closets; an outsider's hand on the goods spoils
/datum/unit_test/voidcrew_outpost_jobs_core/atoms

/datum/unit_test/voidcrew_outpost_jobs_core/atoms/Run()
	var/obj/structure/overmap/trader_outpost/outpost = jobs_outpost()
	var/mob/living/carbon/human/crewman = jobs_person(jobs_spot(0, 0))
	var/mob/living/carbon/human/outsider = jobs_person(jobs_spot(1, 0))
	var/obj/structure/overmap/ship/ship = jobs_ship(list(crewman))

	var/datum/mission/fixer_job/job = core_job(outpost, ship)
	var/mob/living/carbon/human/npc/ambient_npc/core_test/person = allocate(/mob/living/carbon/human/npc/ambient_npc/core_test, jobs_spot(2, 2))
	fixer_job_npc_setup(person, job)
	TEST_ASSERT_EQUAL(person.place, SSambient_npcs.outpost_place(outpost), "A job person is not one of the outpost's people")
	TEST_ASSERT(HAS_TRAIT(person, "no_containment"), "A job person can be shut in a closet") // TRAIT_NO_CONTAINMENT
	TEST_ASSERT(HAS_TRAIT(person, TRAIT_NO_STORAGE_INSERT), "A job person can be put in a bag")
	TEST_ASSERT(job.is_scene_victim(person), "A crime against a job person is not a crime against the job")
	TEST_ASSERT(fixer_crowd_exempt(person), "A job person counts against the outpost's crowd")
	var/obj/structure/table/thing = allocate(/obj/structure/table, jobs_spot(3, 3))
	job.track(thing)
	var/obj/item/mission_recovery/fixer_goods/goods = allocate(/obj/item/mission_recovery/fixer_goods, jobs_spot(0, 1))
	goods.bind_job(job)
	TEST_ASSERT_EQUAL(job.goods_ref?.resolve(), goods, "Bound goods are not the job's goods")
	TEST_ASSERT(crewman.put_in_hands(goods), "Setup: the crewman could not take the goods")
	TEST_ASSERT(!job.failed, "The crew's own hand on the goods spoiled the job")
	job.unstage()
	TEST_ASSERT(QDELETED(person), "A job person is still here after unstage()")
	TEST_ASSERT(QDELETED(thing), "A job's thing is still here after unstage()")
	TEST_ASSERT(QDELETED(goods), "The job's goods are still here after unstage()")
	qdel(job)

	var/datum/mission/fixer_job/spoiled = core_job(outpost, ship)
	var/obj/item/mission_recovery/fixer_goods/taken = allocate(/obj/item/mission_recovery/fixer_goods, jobs_spot(0, 1))
	taken.bind_job(spoiled)
	outsider.put_in_hands(taken)
	TEST_ASSERT(spoiled.failed, "An outsider taking the goods did not spoil the job")
	TEST_ASSERT_EQUAL(spoiled.fail_reason, "spoiled", "An outsider taking the goods failed the job for the wrong reason") // FIXER_FAIL_SPOILED

	jobs_cleanup(list(ship))

/// No spot is ever a doorway or beside one, or the lift
/datum/unit_test/voidcrew_outpost_jobs_core/spots

/datum/unit_test/voidcrew_outpost_jobs_core/spots/Run()
	var/obj/structure/overmap/trader_outpost/outpost = jobs_outpost()
	outpost.lobby_alcove_turfs = list(run_loc_floor_top_right)
	var/turf/door_turf = jobs_spot(0, 2)
	allocate(/obj/machinery/door/airlock/public, door_turf)
	var/list/near_door = list(door_turf)
	for(var/direction in GLOB.cardinals)
		near_door += get_step(door_turf, direction)
	var/found = 0
	for(var/kind in list("wall", "open", "arrive")) // FIXER_SPOT_WALL, FIXER_SPOT_OPEN, FIXER_SPOT_ARRIVE
		var/list/candidates = fixer_job_spot_candidates(outpost, kind)
		found += length(candidates)
		for(var/turf/tile as anything in candidates)
			TEST_ASSERT(!(tile in near_door), "A [kind] spot was in or beside a doorway at [AREACOORD(tile)]")
			TEST_ASSERT(!(tile in outpost.lobby_alcove_turfs), "A [kind] spot was on the lift at [AREACOORD(tile)]")
	TEST_ASSERT(found > 0, "The test room gave no spot of any kind")
	var/list/run = fixer_job_spot(outpost, "open", null, 2) // FIXER_SPOT_OPEN
	if(length(run) == 2)
		TEST_ASSERT_EQUAL(get_dist(run[1], run[2]), 1, "Two open spots asked for together are not side by side")

/// A fixer job's goods are never taken in a search, nor is a bag holding them (L15)
/datum/unit_test/voidcrew_outpost_jobs_core/goods_not_evidence

/datum/unit_test/voidcrew_outpost_jobs_core/goods_not_evidence/Run()
	var/obj/structure/overmap/trader_outpost/outpost = jobs_outpost()
	var/mob/living/carbon/human/suspect = jobs_person(jobs_spot(0, 0))
	var/obj/item/mission_recovery/fixer_goods/goods = allocate(/obj/item/mission_recovery/fixer_goods, jobs_spot(0, 0))
	var/obj/item/storage/box/box = allocate(/obj/item/storage/box, jobs_spot(0, 0))
	var/obj/item/storage/box/empty_box = allocate(/obj/item/storage/box, jobs_spot(0, 0))
	goods.forceMove(box)
	TEST_ASSERT(suspect.put_in_hands(box), "Setup: the suspect could not hold the box")
	TEST_ASSERT(suspect.put_in_hands(empty_box), "Setup: the suspect could not hold the empty box")
	TEST_ASSERT(outpost.police.evidence_can_take(empty_box, suspect), "Setup: a search could not take an ordinary box")
	TEST_ASSERT(!outpost.police.evidence_can_take(box, suspect), "A search could take a box holding a fixer job's goods")
	goods.forceMove(get_turf(suspect))
	TEST_ASSERT(!outpost.police.evidence_can_take(goods, suspect), "A search could take a fixer job's goods at the suspect's feet")
