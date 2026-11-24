/**
 * Outpost police tests: the hatches, and the key the medics and morgue crew carry (voidcrew/modules/trade/
 * outpost_checkpoint.dm and outpost_checkpoint_npcs.dm). A hatch is a checkpoint whose outer door opens onto space:
 * Quartermain's two yard hatches and the Undertow's bar hatch, onto catwalks no officer can walk.
 *
 * The first tests use the small checkpoint of voidcrew_trader_checkpoint.dm (lobby below, a chamber of two tiles,
 * the concourse above), its lobby made space to be a hatch. The last are live, on the real maps, with the police's
 * own tick and the officers' own AI (the harness of voidcrew_outpost_police_search.dm).
 *
 * Fork defines are included after the tests, so values are written out: heat 40 is two stars
 * (OUTPOST_POLICE_STAR_HEAT 10, 25, 50, 90, 140); checkpoint states "idle", "scanning", "passing", "rejecting".
 */

/// Makes the fixture's lobby space, so its checkpoint is a hatch
/datum/unit_test/voidcrew_trader_checkpoint/proc/make_hatch()
	var/turf/origin = host.template_bottom_left
	for(var/dx in 0 to 4)
		for(var/dy in 0 to 1)
			put_in_area(locate(origin.x + dx, origin.y + dy, origin.z), /area/space)
	host.ensure_police()
	TEST_ASSERT(checkpoint.is_hatch(), "Fixture: a checkpoint whose outer door opens onto space is not a hatch")

/**
 * Someone wanted is refused the way out through a hatch, by the door's own deny light, and is never shut in or kept
 * out: the hatch sends them back to the concourse they came from, and lets anyone in from outside. Nobody else
 * gains a way through: a clean crewmate in the chamber with them cannot open it either.
 */
/datum/unit_test/voidcrew_trader_checkpoint/hatch_wanted/Run()
	TEST_ASSERT(fixture(FALSE), "Could not prepare the checkpoint")
	make_hatch()
	var/mob/living/carbon/human/wanted = visitor(secured)
	var/datum/outpost_warrant/warrant = police_pin_warrant(host.police, wanted.mind, 40)
	var/mob/living/carbon/human/mate = visitor(secured)
	// From the concourse: no cycle outward, and the door shows its refusal like any refused door
	TEST_ASSERT(!checkpoint.request_cycle(wanted), "A hatch cycled outward for someone wanted")
	TEST_ASSERT_EQUAL(checkpoint.state, "idle", "A hatch began a cycle outward for someone wanted") // CHECKPOINT_IDLE
	inner.bumpopen(wanted)
	TEST_ASSERT(!COOLDOWN_FINISHED(inner, deny_cooldown), "The hatch's inner door did not show its refusal to someone wanted")
	sleep(1.5 SECONDS)
	TEST_ASSERT(inner.density, "The hatch's inner door opened for someone wanted")
	// A crewmate cycles it for them and they both go in
	TEST_ASSERT(scan_now(mate), "A hatch would not cycle outward for someone not wanted")
	TEST_ASSERT_EQUAL(checkpoint.state, "passing", "The empty chamber did not pass for a crewmate going out") // CHECKPOINT_PASSING
	sleep(1.5 SECONDS)
	TEST_ASSERT(!inner.density, "Fixture: the inner door did not open for the crewmate")
	mate.forceMove(chamber[1])
	wanted.forceMove(chamber[2])
	TEST_ASSERT(wait_shut(inner, 10 SECONDS), "Fixture: the inner door did not shut after the pass")
	// The outer door opens for neither of them, and not for someone outside either while a wanted one is in there
	var/mob/living/carbon/human/outsider = visitor(lobby)
	TEST_ASSERT(!checkpoint.request_outer(mate), "A hatch opened onto space for a crewmate with someone wanted beside them")
	TEST_ASSERT(!checkpoint.request_outer(wanted), "A hatch opened onto space for someone wanted")
	TEST_ASSERT(!checkpoint.request_outer(outsider), "A hatch opened from outside onto someone wanted in its chamber")
	outer.bumpopen(wanted)
	TEST_ASSERT(!COOLDOWN_FINISHED(outer, deny_cooldown), "The hatch's outer door did not show its refusal to someone wanted")
	// In a locker it is the same
	var/obj/structure/closet/locker = allocate(/obj/structure/closet, chamber[2])
	locker.close()
	wanted.forceMove(locker)
	TEST_ASSERT(!checkpoint.request_outer(mate), "A hatch opened onto space on someone wanted shut in a locker")
	wanted.forceMove(chamber[2])
	qdel(locker)
	sleep(1.5 SECONDS)
	TEST_ASSERT(outer.density, "The hatch's outer door opened with someone wanted in its chamber")
	// Never shut in: asking to go back in, they are refused (wanted is barred) and sent back to the concourse
	TEST_ASSERT(scan_now(wanted), "The hatch would not scan someone wanted standing in it")
	TEST_ASSERT_EQUAL(checkpoint.state, "rejecting", "The hatch let someone wanted through inward") // CHECKPOINT_REJECTING
	sleep(1.5 SECONDS)
	TEST_ASSERT(outer.density, "A refusal opened the hatch onto space for someone who came from the concourse")
	TEST_ASSERT(!inner.density, "A refusal left someone who came from the concourse shut in the hatch")
	wanted.forceMove(secured)
	mate.forceMove(secured)
	TEST_ASSERT(wait_shut(inner, 15 SECONDS), "The inner door did not shut once the refused person had gone back in")
	TEST_ASSERT_EQUAL(checkpoint.state, "idle", "The hatch did not settle after sending someone back in") // CHECKPOINT_IDLE
	// Coming in from outside always works, wanted or not
	wanted.forceMove(lobby)
	outsider.forceMove(locate(lobby.x + 1, lobby.y, lobby.z))
	TEST_ASSERT(checkpoint.request_outer(wanted), "A hatch would not let someone wanted in from outside")
	sleep(1.5 SECONDS)
	TEST_ASSERT(!outer.density, "Fixture: the outer door did not open for someone outside")
	TEST_ASSERT(checkpoint.outer_opened, "The hatch did not note its outer door opening")
	// In from outside and refused: back out the way they came, as at any gate
	wanted.forceMove(chamber[1])
	checkpoint.close_door(outer)
	TEST_ASSERT(wait_shut(outer, 10 SECONDS), "Fixture: the outer door did not shut behind someone coming in")
	for(var/i in 1 to 40)
		if(checkpoint.state == "scanning") // CHECKPOINT_SCANNING
			break
		sleep(0.1 SECONDS)
	TEST_ASSERT_EQUAL(checkpoint.state, "scanning", "The hatch did not scan someone who came in from outside") // CHECKPOINT_SCANNING
	checkpoint.finish_scan()
	TEST_ASSERT_EQUAL(checkpoint.state, "rejecting", "The hatch let someone wanted in from outside") // CHECKPOINT_REJECTING
	sleep(1.5 SECONDS)
	TEST_ASSERT(!outer.density, "Someone refused coming in from outside was shut in the hatch")
	TEST_ASSERT(inner.density, "The hatch opened onto the concourse for someone refused from outside")
	wanted.forceMove(lobby)
	TEST_ASSERT(wait_shut(outer, 15 SECONDS), "The outer door did not shut once the refused person had gone")
	// With the stars gone the hatch is a hatch again for them
	host.police.remove_warrant(warrant)
	wanted.forceMove(secured)
	checkpoint.set_state("idle") // CHECKPOINT_IDLE
	TEST_ASSERT(checkpoint.request_cycle(wanted), "A hatch still refused someone whose stars were gone")

/// A lobby checkpoint is not a hatch: someone wanted in its chamber is let back out to the lobby as before
/datum/unit_test/voidcrew_trader_checkpoint/hatch_not_lobby/Run()
	TEST_ASSERT(fixture(FALSE), "Could not prepare the checkpoint")
	host.ensure_police()
	TEST_ASSERT(!checkpoint.is_hatch(), "A lobby checkpoint counts as a hatch")
	var/mob/living/carbon/human/wanted = visitor(chamber[1])
	police_pin_warrant(host.police, wanted.mind, 40)
	TEST_ASSERT(checkpoint.request_outer(wanted), "A lobby checkpoint kept someone wanted from walking back out to the lobby")
	sleep(1.5 SECONDS)
	TEST_ASSERT(!outer.density, "A lobby checkpoint's outer door did not open for someone wanted in it")

/**
 * The police's key on a hatch: the inner door, for an officer with business in the chamber, while nothing unscanned
 * can be in there (the outer door shut and not opened since the last clean pass); never the outer door; and nothing
 * for anyone else.
 */
/datum/unit_test/voidcrew_trader_checkpoint/hatch_key/Run()
	TEST_ASSERT(fixture(FALSE), "Could not prepare the checkpoint")
	make_hatch()
	var/mob/living/carbon/human/npc/ambient_npc/outpost/police/officer/cop = key_officer(secured)
	var/datum/can_pass_info/cop_walk = new(cop, list())
	var/mob/living/carbon/human/suspect = visitor(chamber[2])
	police_pin_warrant(host.police, suspect.mind, 40)
	// Nothing to do in there: walls to it
	TEST_ASSERT(!inner.CanAStarPass(SOUTH, cop_walk), "An officer with no business in the hatch paths through its inner door")
	inner.bumpopen(cop)
	sleep(1.5 SECONDS)
	TEST_ASSERT(inner.density, "An officer with no business in the hatch opened its inner door")
	// Walking to someone in it, who came from the concourse: the inner door is its to open, the outer door is not
	cop.ai_controller.set_movement_target(type, suspect)
	TEST_ASSERT(inner.CanAStarPass(SOUTH, cop_walk), "An officer walking to someone in a hatch cannot path in by its inner door")
	TEST_ASSERT(!outer.CanAStarPass(SOUTH, cop_walk), "An officer's key fits a hatch's outer door")
	inner.bumpopen(cop)
	sleep(1.5 SECONDS)
	TEST_ASSERT(!inner.density, "An officer's key did not open a hatch's inner door on someone wanted in it")
	TEST_ASSERT(outer.density, "The hatch opened onto space with its inner door")
	// The officer in the doorway with them: the police at work, and the hatch opens for nobody
	cop.forceMove(get_turf(inner))
	TEST_ASSERT(checkpoint.police_at_work(), "An officer in the hatch's doorway with someone wanted is not the police at work")
	TEST_ASSERT(!checkpoint.request_outer(suspect), "The hatch opened onto space on an arrest")
	// Done: out of the way, the door shuts in its own time
	cop.forceMove(secured)
	suspect.forceMove(secured)
	TEST_ASSERT(wait_shut(inner, 10 SECONDS), "The hatch's inner door did not shut after the officer's key")
	TEST_ASSERT_EQUAL(checkpoint.state, "idle", "The hatch did not settle after the officer's key") // CHECKPOINT_IDLE
	// Someone in from outside, not scanned yet: no key opens the way in for them
	var/mob/living/carbon/human/outsider = visitor(lobby)
	TEST_ASSERT(checkpoint.request_outer(outsider), "Fixture: the hatch did not open for someone outside")
	sleep(1.5 SECONDS)
	outsider.forceMove(chamber[1])
	suspect.forceMove(chamber[2])
	checkpoint.close_door(outer)
	TEST_ASSERT(wait_shut(outer, 10 SECONDS), "Fixture: the outer door did not shut")
	checkpoint.set_state("idle") // CHECKPOINT_IDLE, as if nobody had asked for the scan yet
	TEST_ASSERT(!inner.CanAStarPass(SOUTH, cop_walk), "An officer paths in by a hatch's inner door with someone unscanned in there")
	inner.bumpopen(cop)
	sleep(1.5 SECONDS)
	TEST_ASSERT(inner.density, "An officer's key opened a hatch's inner door on someone in from outside and unscanned")
	// A clean pass since: the key fits again
	suspect.forceMove(secured)
	TEST_ASSERT(scan_now(outsider), "Fixture: could not scan the person in from outside")
	TEST_ASSERT_EQUAL(checkpoint.state, "passing", "Fixture: a clean person from outside did not pass") // CHECKPOINT_PASSING
	outsider.forceMove(secured)
	TEST_ASSERT(wait_shut(inner, 10 SECONDS), "Fixture: the inner door did not shut after the pass")
	TEST_ASSERT(!checkpoint.outer_opened, "A clean pass did not clear the hatch's note of its outer door")
	suspect.forceMove(chamber[2])
	TEST_ASSERT(inner.CanAStarPass(SOUTH, cop_walk), "After a clean pass an officer cannot path in by a hatch's inner door")
	// Any other NPC still gets nothing
	var/mob/living/carbon/human/npc/ambient_npc/outpost/customer/npc = allocate(/mob/living/carbon/human/npc/ambient_npc/outpost/customer, secured)
	npc.ai_controller?.set_movement_target(type, suspect)
	inner.bumpopen(npc)
	sleep(1.5 SECONDS)
	TEST_ASSERT(inner.density, "A townsperson opened a hatch's inner door by walking into it")
	// Standing in it, the way out is its own
	cop.ai_controller.set_movement_target(type, null)
	suspect.forceMove(secured)
	cop.forceMove(chamber[1])
	TEST_ASSERT(inner.CanAStarPass(NORTH, cop_walk), "An officer in a hatch cannot path out by its inner door")
	inner.bumpopen(cop)
	sleep(1.5 SECONDS)
	TEST_ASSERT(!inner.density, "An officer in a hatch could not let itself back in")
	qdel(cop)

/// A crew member of `type` at `where`, working for the fixture's outpost, its AI off so the job is the test's
/datum/unit_test/voidcrew_trader_checkpoint/proc/crew_member(type, turf/where)
	var/mob/living/carbon/human/npc/ambient_npc/outpost/recovery/worker = allocate(type, where)
	worker.outpost_recovery = host.ensure_recovery()
	worker.ai_controller?.set_ai_status(AI_STATUS_OFF)
	return worker

/**
 * The medics and the morgue crew carry the police's key for their own work in the chamber: a body to collect, a
 * patient to treat. Nothing for a crew member with no such work there, and nothing for anyone else. While they work
 * in there the chamber scans nobody, keeps its outer door open behind them and lets nobody else in.
 */
/datum/unit_test/voidcrew_trader_checkpoint/crew_key/Run()
	TEST_ASSERT(fixture(FALSE), "Could not prepare the checkpoint")
	host.ensure_police()
	var/mob/living/carbon/human/npc/ambient_npc/outpost/recovery/morgue/worker = crew_member(/mob/living/carbon/human/npc/ambient_npc/outpost/recovery/morgue, lobby)
	var/datum/can_pass_info/worker_walk = new(worker, list())
	var/mob/living/carbon/human/body = visitor(chamber[2])
	body.death()
	// No job: walls to it, as to any NPC
	TEST_ASSERT(!outer.CanAStarPass(NORTH, worker_walk), "A morgue worker with no body in the chamber paths through its door")
	outer.bumpopen(worker)
	sleep(1.5 SECONDS)
	TEST_ASSERT(outer.density, "A morgue worker with no body in the chamber opened its door")
	// Its body in there, and its walk going to it: the outer door, never the inner one
	var/datum/ambient_activity/recover_body/job = new(worker)
	job.body_ref = WEAKREF(body)
	worker.activity = job
	worker.ai_controller.set_movement_target(type, body)
	TEST_ASSERT(outer.CanAStarPass(NORTH, worker_walk), "A morgue worker walking to a body in the chamber cannot path through the outer door")
	TEST_ASSERT(!inner.CanAStarPass(SOUTH, worker_walk), "A morgue worker paths through the shut inner door of a working gate")
	outer.bumpopen(worker)
	sleep(1.5 SECONDS)
	TEST_ASSERT(!outer.density, "A morgue worker's key did not open the outer door on a body in the chamber")
	// At work in there: not scanned, not shut in, and nobody else comes in on it
	worker.forceMove(chamber[1])
	TEST_ASSERT(checkpoint.crew_at_work(), "A morgue worker in the chamber with its body is not at work")
	var/mob/living/carbon/human/npc/ambient_npc/outpost/customer/npc = allocate(/mob/living/carbon/human/npc/ambient_npc/outpost/customer, lobby)
	sleep(7 SECONDS) // OUTPOST_CHECKPOINT_OUTER_HOLD is 4 s
	TEST_ASSERT(!outer.density, "The outer door shut on a morgue worker at work in the chamber")
	TEST_ASSERT_EQUAL(checkpoint.state, "idle", "The chamber went on with its cycle with a morgue worker at work in it") // CHECKPOINT_IDLE
	TEST_ASSERT_NULL(checkpoint.chamber_place_for(npc), "A townsperson was given a place in the chamber on a morgue worker at work")
	TEST_ASSERT(!checkpoint.request_cycle(npc), "A cycle was answered with a morgue worker at work in the chamber")
	// Done and gone: the gate goes on
	worker.activity = null
	qdel(job)
	worker.forceMove(lobby)
	body.forceMove(lobby)
	TEST_ASSERT(!checkpoint.crew_at_work(), "A crew member gone from the chamber is still at work in it")
	TEST_ASSERT(wait_shut(outer, 10 SECONDS), "The outer door did not shut after the morgue worker left")
	// A medic and its patient: the same key
	var/mob/living/carbon/human/npc/ambient_npc/outpost/recovery/medic/medic = crew_member(/mob/living/carbon/human/npc/ambient_npc/outpost/recovery/medic, lobby)
	var/datum/can_pass_info/medic_walk = new(medic, list())
	var/mob/living/carbon/human/npc/ambient_npc/outpost/customer/patient = allocate(/mob/living/carbon/human/npc/ambient_npc/outpost/customer, chamber[2])
	patient.ai_controller?.set_ai_status(AI_STATUS_OFF)
	TEST_ASSERT(!outer.CanAStarPass(NORTH, medic_walk), "A medic with no patient in the chamber paths through its door")
	var/datum/ambient_activity/treat_patient/treating = new(medic)
	treating.patient_ref = WEAKREF(patient)
	medic.activity = treating
	medic.ai_controller.set_movement_target(type, chamber[1])
	TEST_ASSERT(outer.CanAStarPass(NORTH, medic_walk), "A medic walking to a patient in the chamber cannot path through the outer door")
	outer.bumpopen(medic)
	sleep(1.5 SECONDS)
	TEST_ASSERT(!outer.density, "A medic's key did not open the outer door on a patient in the chamber")
	medic.forceMove(chamber[1])
	TEST_ASSERT(checkpoint.crew_at_work(), "A medic in the chamber with its patient is not at work")
	// Someone playing the body has no key
	medic.mind_initialize()
	TEST_ASSERT(!checkpoint.crew_key_holder(medic), "A played medic's body has the crews' key")
	medic.activity = null
	qdel(treating)

/// A crew's key on a hatch: the inner door, under the same rule as the officers'
/datum/unit_test/voidcrew_trader_checkpoint/crew_key_hatch/Run()
	TEST_ASSERT(fixture(FALSE), "Could not prepare the checkpoint")
	make_hatch()
	var/mob/living/carbon/human/npc/ambient_npc/outpost/recovery/morgue/worker = crew_member(/mob/living/carbon/human/npc/ambient_npc/outpost/recovery/morgue, secured)
	var/datum/can_pass_info/worker_walk = new(worker, list())
	var/mob/living/carbon/human/body = visitor(chamber[2])
	body.death()
	var/datum/ambient_activity/recover_body/job = new(worker)
	job.body_ref = WEAKREF(body)
	worker.activity = job
	worker.ai_controller.set_movement_target(type, body)
	TEST_ASSERT(inner.CanAStarPass(SOUTH, worker_walk), "A morgue worker walking to a body in a hatch cannot path in by its inner door")
	TEST_ASSERT(!outer.CanAStarPass(SOUTH, worker_walk), "A crew's key fits a hatch's outer door")
	inner.bumpopen(worker)
	sleep(1.5 SECONDS)
	TEST_ASSERT(!inner.density, "A morgue worker's key did not open a hatch's inner door on a body in it")
	worker.activity = null
	qdel(job)

// ===== LIVE: AN ARREST IN A WORKING HATCH =====

/datum/unit_test/voidcrew_outpost_police_search/hatch
	abstract_type = /datum/unit_test/voidcrew_outpost_police_search/hatch
	/// The outpost whose hatch it is
	var/outpost_type
	/// The hatch's checkpoint id on that map
	var/hatch_id

/**
 * Two stars, standing in a working hatch's chamber (come in from the concourse, as a crewmate's cycle lets someone
 * in): an officer opens its inner door, cuffs them there and walks them out; the hatch never opens onto space; and
 * no officer is left in it.
 */
/datum/unit_test/voidcrew_outpost_police_search/hatch/Run()
	var/obj/structure/overmap/trader_outpost/outpost = search_outpost(outpost_type)
	if(!outpost)
		return
	var/datum/outpost_police/police = outpost.police
	var/datum/outpost_checkpoint/post = outpost.checkpoints[hatch_id]
	TEST_ASSERT_NOTNULL(post, "[outpost_type] has no checkpoint [hatch_id]")
	TEST_ASSERT(post.is_hatch(), "[outpost_type]: [hatch_id] is not a hatch")
	TEST_ASSERT_NOTNULL(police.desk_turf, "[outpost_type] has no police desk")
	var/turf/stand = post.chamber_turfs[1]
	duty_officer(outpost, /mob/living/carbon/human/npc/ambient_npc/outpost/police/sergeant, police.desk_turf)
	beat_officers(outpost)
	var/mob/living/carbon/human/suspect = wanted_at(outpost, stand, stand, 40)
	suspect.real_name = "Hatch Suspect"
	suspect.name = suspect.real_name
	post.outer_opened = FALSE
	police.wake()
	var/turf/corner = outpost.template_bottom_left
	var/started = world.time
	var/cuffed_after = -1
	var/outer_opened = FALSE
	while(world.time - started < 90 SECONDS)
		if(!post.outer_door.density)
			outer_opened = TRUE
		if(suspect.handcuffed)
			cuffed_after = world.time - started
			break
		sleep(0.5 SECONDS)
	var/datum/outpost_police_case/case = police.cases[suspect.mind]
	if(cuffed_after < 0)
		police.sleep_tick()
		TEST_FAIL("[outpost_type] [hatch_id]: two stars in the hatch: not in cuffs after 90 s (arrest [case ? "on its \"[case.step]\" step" : "never opened"], [police.get_stars(suspect.mind)] stars, the suspect at [suspect.x - corner.x + 1],[suspect.y - corner.y + 1], hatch [post.state], outer door [post.outer_door.density ? "shut" : "open"], inner door [post.inner_door.density ? "shut" : "open"]). [officers_report(outpost)]")
		dispatch_clear(police)
		return
	started = world.time
	var/out_after = -1
	while(world.time - started < 60 SECONDS)
		if(!post.outer_door.density)
			outer_opened = TRUE
		if(!post.holds_turf(get_turf(suspect)) && (is_outpost_police_npc(suspect.pulledby) || police.cell_holding(suspect.mind)))
			out_after = world.time - started
			break
		sleep(0.5 SECONDS)
	if(out_after < 0)
		case = police.cases[suspect.mind]
		police.sleep_tick()
		TEST_FAIL("[outpost_type] [hatch_id]: cuffed in the hatch and still [post.holds_turf(get_turf(suspect)) ? "in it" : "let go of"] 60 s later (arrest [case ? "on its \"[case.step]\" step" : "closed"], hatch [post.state], inner door [post.inner_door.density ? "shut" : "open"]). [officers_report(outpost)]")
		dispatch_clear(police)
		return
	TEST_ASSERT(!outer_opened, "[outpost_type] [hatch_id]: the hatch opened onto space during the arrest")
	started = world.time
	var/officers_inside = TRUE
	while(world.time - started < 30 SECONDS)
		officers_inside = FALSE
		for(var/mob/living/officer as anything in police.officers)
			if(post.holds_turf(get_turf(officer)))
				officers_inside = TRUE
		if(!officers_inside)
			break
		sleep(0.5 SECONDS)
	TEST_ASSERT(!officers_inside, "[outpost_type] [hatch_id]: an officer still in the hatch 30 s after the prisoner left it. [officers_report(outpost)]")
	log_test("[outpost_type] [hatch_id]: cuffed in the hatch after [cuffed_after / 10] s, out of it [out_after / 10] s later")
	police.sleep_tick()
	dispatch_clear(police)

/datum/unit_test/voidcrew_outpost_police_search/hatch/quartermain_west
	outpost_type = /obj/structure/overmap/trader_outpost/outfitter
	hatch_id = "quartermain_west_yard"

/datum/unit_test/voidcrew_outpost_police_search/hatch/undertow_bar
	outpost_type = /obj/structure/overmap/trader_outpost/black_market
	hatch_id = "undertow_bar"
