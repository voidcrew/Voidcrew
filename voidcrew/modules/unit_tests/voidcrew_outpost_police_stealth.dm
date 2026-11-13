/**
 * Outpost police tests: the police on the stealth layer (spec-stealth.md section 4;
 * voidcrew/modules/stealth_police/police_stealth.dm and the stealth rules of outpost_police/police_perception.dm).
 * Owner: P13.
 *
 * Every test runs in the walled, lit room of voidcrew_stealth_live (voidcrew_stealth.dm), under a fake trader
 * outpost, with the police's perception on its real rules (test_plain off). None of them sleeps: the AI is stepped
 * by hand. Fork defines are included after the tests, so values are written out: states "unaware", "alert",
 * "searching"; crimes "unarmed", "shot" (25 heat, two stars); OUTPOST_POLICE_RADIOLESS_TIME 3 s;
 * STEALTH_RADIO_CALL_TIME 3 s.
 */

#define POLICE_STEALTH_BEAT /mob/living/carbon/human/npc/ambient_npc/outpost/police/beat

/datum/unit_test/voidcrew_stealth_live/police
	abstract_type = /datum/unit_test/voidcrew_stealth_live/police
	/// The fake outpost over the room
	var/obj/structure/overmap/trader_outpost/outpost
	/// Its police
	var/datum/outpost_police/police

/datum/unit_test/voidcrew_stealth_live/police/Destroy()
	outpost = null
	police = null
	return ..()

/// The room, a fake trader outpost over it and its police seeing by the stealth rules. FALSE if there is no room.
/datum/unit_test/voidcrew_stealth_live/police/proc/police_room(width, height)
	if(!make_room(width, height))
		return FALSE
	outpost = allocate(/obj/structure/overmap/trader_outpost)
	outpost.outpost_template = allocate(/datum/map_template/trader_outpost)
	outpost.outpost_template.width = width + 2
	outpost.outpost_template.height = height + 2
	outpost.template_bottom_left = room.bottom_left_turfs[1]
	police = outpost.ensure_police()
	police.perception.test_plain = FALSE
	return TRUE

/// An officer of `officer_type` at (dx, dy) facing `facing`, on the roster
/datum/unit_test/voidcrew_stealth_live/police/proc/officer_at(dx, dy, facing = EAST, officer_type = POLICE_STEALTH_BEAT)
	var/mob/living/carbon/human/npc/ambient_npc/outpost/police/officer = police_officer(outpost, officer_type, at(dx, dy))
	officer.setDir(facing)
	officer.AddElement(/datum/element/forced_gravity, 1)
	return officer

/// Someone with a mind at (dx, dy), not on the list of players
/datum/unit_test/voidcrew_stealth_live/police/proc/visitor_at(dx, dy)
	var/mob/living/carbon/human/person = person_at(dx, dy, FALSE)
	person.mind_initialize()
	allocated += person.mind
	return person

/// A police patrol stop on `route` at (dx, dy)
/datum/unit_test/voidcrew_stealth_live/police/proc/police_stop(dx, dy, route, order, wait, activity)
	var/obj/effect/landmark/stealth_patrol/police/stop = allocate(/obj/effect/landmark/stealth_patrol/police, at(dx, dy))
	stop.route = route
	stop.order = order
	stop.wait = wait
	stop.police_activity = activity
	return stop

// ===== THE BRAIN =====

/// Officers think as stealth guards with the police's subtrees in spec order, carry a working radio and no light
/datum/unit_test/voidcrew_stealth_live/police/brain

/datum/unit_test/voidcrew_stealth_live/police/brain/Run()
	TEST_ASSERT(police_room(6, 6), "No room for the test")
	var/mob/living/carbon/human/npc/ambient_npc/outpost/police/officer = officer_at(2, 2)
	var/datum/ai_controller/basic_controller/human_npc/stealth/outpost_police/brain = officer.ai_controller
	TEST_ASSERT(istype(brain), "An officer has [officer.ai_controller?.type], not the stealth police brain")
	var/list/subtrees = list()
	for(var/datum/ai_planning_subtree/subtree as anything in brain.planning_subtrees)
		subtrees += subtree.type
	TEST_ASSERT_EQUAL(subtrees[1], /datum/ai_planning_subtree/stealth_perception, "The scan is not the officer's first thought")
	TEST_ASSERT_EQUAL(subtrees[length(subtrees)], /datum/ai_planning_subtree/stealth_patrol, "The patrol is not the officer's last thought")
	TEST_ASSERT(subtrees.Find(/datum/ai_planning_subtree/outpost_police_case) < subtrees.Find(/datum/ai_planning_subtree/stealth_react), "Searching comes before the arrest")
	TEST_ASSERT_EQUAL(subtrees.Find(/datum/ai_planning_subtree/outpost_police_stop), length(subtrees) - 1, "The stop's activity is not just before the patrol")
	TEST_ASSERT(!(/datum/ai_planning_subtree/simple_find_target in subtrees) && !(/datum/ai_planning_subtree/ambient_routine in subtrees), "tg's target finder or the ambient routine still runs an officer")
	TEST_ASSERT(officer.stealth_radio, "An officer is not on the radio net")
	TEST_ASSERT_NOTNULL(officer.stealth_radio_ready(), "An officer's headset does not work")
	// No light that can come off them (abuse M8, ST6). The one light allowed is tg's mini energy gun's own gunlight,
	// built into the gun (not removable) on an officer whose kit is locked to them
	for(var/obj/item/flashlight/light in officer.get_all_contents())
		var/obj/item/gun/holder = light.loc
		var/datum/component/seclite_attachable/mount = istype(holder) ? holder.GetComponent(/datum/component/seclite_attachable) : null
		TEST_ASSERT(mount && mount.light == light && !mount.is_light_removable, "An officer carries a light that can come off (abuse M8): [light] in [light.loc]")

// ===== SIGHT CONVICTS =====

/// Behind an officer's back it sees nothing; in its cone it does; the dark and a cloak cut it short; a camera sees the cloak; a clean visitor is never noticed
/datum/unit_test/voidcrew_stealth_live/police/sight

/datum/unit_test/voidcrew_stealth_live/police/sight/Run()
	TEST_ASSERT(police_room(20, 9), "No room for the test")
	var/datum/outpost_police_perception/perception = police.perception
	var/mob/living/carbon/human/npc/ambient_npc/outpost/police/officer = officer_at(8, 4, EAST)
	var/mob/living/carbon/human/person = visitor_at(3, 4)
	TEST_ASSERT(!perception.sees(officer, person), "An unaware officer saw someone five tiles behind it")
	person.forceMove(at(13, 4))
	TEST_ASSERT(perception.sees(officer, person), "An officer did not see someone five tiles in front of it")

	var/turf/far_dark = at(14, 4)
	var/turf/near_dark = at(11, 4)
	GLOB.stealth_test_dark_turfs[far_dark] = TRUE
	GLOB.stealth_test_dark_turfs[near_dark] = TRUE
	person.forceMove(far_dark)
	TEST_ASSERT(!perception.sees(officer, person), "An officer saw someone six tiles off in the dark")
	person.forceMove(near_dark)
	TEST_ASSERT(perception.sees(officer, person), "An officer did not see someone three tiles off in the dark")
	GLOB.stealth_test_dark_turfs[far_dark] = FALSE
	GLOB.stealth_test_dark_turfs[near_dark] = FALSE

	person.forceMove(at(12, 4))
	ADD_TRAIT(person, "cyber_camo", TRAIT_SOURCE_UNIT_TESTS) // TRAIT_CYBER_CAMO
	TEST_ASSERT(!perception.sees(officer, person), "An officer saw a cloaked person four tiles off")
	var/obj/machinery/outpost_checkpoint_sensor/camera = allocate(/obj/machinery/outpost_checkpoint_sensor, at(16, 4))
	TEST_ASSERT(perception.sees(camera, person), "A camera did not see through a cloak")
	REMOVE_TRAIT(person, "cyber_camo", TRAIT_SOURCE_UNIT_TESTS)

	// A clean visitor in plain sight raises no notice
	person.forceMove(at(10, 4))
	var/datum/ai_controller/basic_controller/human_npc/stealth/outpost_police/brain = officer.ai_controller
	stealth_scans(officer, 3)
	TEST_ASSERT_EQUAL(brain.stealth_state(), "unaware", "An officer took notice of a clean visitor")
	TEST_ASSERT(!length(brain.notice_map), "An officer kept notice on a clean visitor")

// ===== THE RADIO DECIDES WHEN IT COUNTS =====

/// An officer's report waits for its call and counts when it goes out; the officer acts on it meanwhile; killed first, nobody is wanted
/datum/unit_test/voidcrew_stealth_live/police/radio

/datum/unit_test/voidcrew_stealth_live/police/radio/Run()
	TEST_ASSERT(police_room(20, 9), "No room for the test")
	var/mob/living/carbon/human/npc/ambient_npc/outpost/police/officer = officer_at(8, 4, EAST)
	var/datum/ai_controller/basic_controller/human_npc/stealth/outpost_police/brain = officer.ai_controller
	var/mob/living/carbon/human/shooter = visitor_at(11, 4)
	// No mind: a victim who is a player would be a witness of their own, reporting at once
	var/mob/living/carbon/human/victim = person_at(12, 5, FALSE)

	TEST_ASSERT_NULL(police.report_crime(shooter, "shot", victim), "An officer's report counted before its call")
	TEST_ASSERT_EQUAL(length(police.pending_reports), 1, "An officer's report is not waiting on its call")
	TEST_ASSERT_NULL(police.get_warrant(shooter.mind), "A warrant exists before the call went out")
	TEST_ASSERT_EQUAL(police.force_level(shooter), 0, "The police at large know before the call") // POLICE_FORCE_NONE
	TEST_ASSERT_EQUAL(police.force_level(shooter, officer), 2, "The witness does not act on the shooting it saw") // POLICE_FORCE_STUN
	TEST_ASSERT_EQUAL(brain.stealth_state(), "alert", "The witness is not alert on the shooter")
	TEST_ASSERT_EQUAL(brain.blackboard[BB_BASIC_MOB_CURRENT_TARGET], shooter, "The witness is alert on someone else")
	TEST_ASSERT_NOTNULL(brain.pending_call, "The witness has no call going")
	brain.stealth_rewind(4 SECONDS)
	brain.stealth_deliver_call()
	TEST_ASSERT_EQUAL(police.get_warrant(shooter.mind)?.heat, 25, "The report did not count when the call went out")
	TEST_ASSERT_EQUAL(length(police.pending_reports), 0, "A made report stayed queued")

	// The only witness dies before its call: nobody is wanted
	var/mob/living/carbon/human/second = visitor_at(10, 3)
	police.recent_reports.Cut()
	TEST_ASSERT_NULL(police.report_crime(second, "unarmed", victim), "A second report counted before its call")
	TEST_ASSERT_EQUAL(length(police.pending_reports), 1, "The second report is not waiting")
	officer.death()
	police.tick_warrants()
	TEST_ASSERT_NULL(police.get_warrant(second.mind), "A report counted after its only witness died")
	TEST_ASSERT_EQUAL(length(police.pending_reports), 0, "A report with a dead witness stayed queued")

/// Owner decision 19: an officer with a dead radio can't call it in, but still acts; it reports in person beside an officer whose radio works
/datum/unit_test/voidcrew_stealth_live/police/radio_dead

/datum/unit_test/voidcrew_stealth_live/police/radio_dead/Run()
	TEST_ASSERT(police_room(20, 9), "No room for the test")
	var/mob/living/carbon/human/npc/ambient_npc/outpost/police/officer = officer_at(2, 4, EAST)
	var/datum/ai_controller/basic_controller/human_npc/stealth/outpost_police/brain = officer.ai_controller
	var/obj/item/radio/headset = officer.ears
	TEST_ASSERT(istype(headset), "An officer has no headset")
	headset.set_on(FALSE)
	TEST_ASSERT_NULL(officer.stealth_radio_ready(), "A switched-off headset still works")
	var/mob/living/carbon/human/brawler = visitor_at(4, 4)
	var/mob/living/carbon/human/victim = person_at(5, 4, FALSE)
	police.report_crime(brawler, "shot", victim)
	TEST_ASSERT_EQUAL(brain.stealth_state(), "alert", "An officer with a dead radio did not act on what it saw")
	police.tick_warrants()
	TEST_ASSERT_NULL(police.get_warrant(brawler.mind), "An officer with a dead radio got the report out alone")
	TEST_ASSERT_EQUAL(length(police.pending_reports), 1, "The report was dropped while the witness lives")

	// Another officer with a working radio within reach: the words in person make it, after a few seconds
	officer_at(8, 1, WEST)
	police.tick_warrants()
	var/datum/outpost_pending_report/report = police.pending_reports[1]
	TEST_ASSERT(report.relay_since, "The witness is not telling the officer beside it")
	TEST_ASSERT_NULL(police.get_warrant(brawler.mind), "Telling someone in person was instant")
	report.relay_since -= 4 SECONDS
	police.tick_warrants()
	TEST_ASSERT_EQUAL(police.get_warrant(brawler.mind)?.heat, 25, "Telling an officer with a radio in person did not make the report")

/// Owner decision 42: a radio knocked out before the call (an EMP, a jammer) loses that call, and the witness calls it in once the radio is back
/datum/unit_test/voidcrew_stealth_live/police/radio_back

/datum/unit_test/voidcrew_stealth_live/police/radio_back/Run()
	TEST_ASSERT(police_room(20, 9), "No room for the test")
	var/mob/living/carbon/human/npc/ambient_npc/outpost/police/officer = officer_at(2, 4, EAST)
	var/datum/ai_controller/basic_controller/human_npc/stealth/outpost_police/brain = officer.ai_controller
	var/obj/item/radio/headset = officer.ears
	TEST_ASSERT(istype(headset), "An officer has no headset")
	var/mob/living/carbon/human/brawler = visitor_at(4, 4)
	var/mob/living/carbon/human/victim = person_at(5, 4, FALSE)
	TEST_ASSERT_NULL(police.report_crime(brawler, "shot", victim), "An officer's report counted before its call")
	TEST_ASSERT_NOTNULL(brain.pending_call, "The witness has no call going")
	// The radio dies before the call (an EMP switches it off for a while): that call is lost
	headset.set_on(FALSE)
	police.tick_warrants()
	brain.stealth_rewind(4 SECONDS)
	brain.stealth_deliver_call()
	TEST_ASSERT_NULL(police.get_warrant(brawler.mind), "A report went out on a radio that was down")
	TEST_ASSERT_EQUAL(length(police.pending_reports), 1, "The report was dropped while the witness lives")
	TEST_ASSERT_EQUAL(brain.stealth_state(), "alert", "The witness stopped acting on what it saw")
	// The radio comes back inside the report's keep: the witness calls it in
	headset.set_on(TRUE)
	police.tick_warrants()
	TEST_ASSERT_NOTNULL(brain.pending_call, "The witness did not call it in again once its radio was back")
	brain.stealth_rewind(4 SECONDS)
	brain.stealth_deliver_call()
	police.tick_warrants()
	TEST_ASSERT_EQUAL(police.get_warrant(brawler.mind)?.heat, 25, "A witness whose radio came back never called the report in")

/// A trader at their counter reports at once; dragged away from their counter, they report after the civilian delay and can be silenced before it lands
/datum/unit_test/voidcrew_stealth_live/police/trader

/datum/unit_test/voidcrew_stealth_live/police/trader/Run()
	TEST_ASSERT(police_room(12, 6), "No room for the test")
	var/mob/living/carbon/human/npc/ambient_npc/outpost/trader/keeper = pa_trader(outpost, at(1, 1), at(1, 2), /datum/outpost_shop/vendor/bait_shop)
	var/mob/living/carbon/human/brawler = visitor_at(4, 1)
	var/mob/living/carbon/human/victim = person_at(5, 1, FALSE)
	TEST_ASSERT_NOTNULL(police.report_crime(brawler, "shot", victim), "A trader's report at their counter did not count at once")
	TEST_ASSERT_EQUAL(police.get_warrant(brawler.mind)?.heat, 25, "A trader's report put the wrong heat on")

	police.close_warrant(brawler.mind, TRUE)
	keeper.forceMove(at(3, 4)) // off the counter (home is 1,1): no desk alarm within reach
	TEST_ASSERT_EQUAL(police.report_crime(brawler, "shot", victim), 0, "A trader away from their counter reported instantaneously instead of queueing a civilian report")
	TEST_ASSERT_EQUAL(length(police.pending_reports), 1, "An off-counter trader queued [length(police.pending_reports)] pending reports, not 1")
	TEST_ASSERT_NULL(police.get_warrant(brawler.mind), "An off-counter trader's delayed report put heat on immediately")

	var/datum/outpost_pending_report/pending = police.pending_reports[1]
	pending.due = world.time - 1
	keeper.set_stat(UNCONSCIOUS)
	police.tick_warrants()
	TEST_ASSERT_NULL(police.get_warrant(brawler.mind), "An unconscious off-counter trader still delivered their delayed report")
	keeper.set_stat(CONSCIOUS)
	police.tick_warrants()
	TEST_ASSERT_EQUAL(police.get_warrant(brawler.mind)?.heat, 25, "An awake off-counter trader's delayed report never landed once due")

// ===== SOUND SUMMONS =====

/// A pistol shot through a wall sends a beat officer to look and gives nobody stars; a suppressed one at that range does not move it
/datum/unit_test/voidcrew_stealth_live/police/gunfire

/datum/unit_test/voidcrew_stealth_live/police/gunfire/Run()
	TEST_ASSERT(police_room(20, 7), "No room for the test")
	allocate(/obj/effect/landmark/stealth_group, at(0, 6))
	person_at(19, 6)
	police_stop(4, 3, "a", 1, 10 MINUTES, null)
	var/mob/living/carbon/human/npc/ambient_npc/outpost/police/officer = officer_at(4, 3, WEST)
	// Nobody on the test concourse holds them still (ambient pause); a player there would wake them
	officer.resume_routine()
	var/datum/ai_controller/basic_controller/human_npc/stealth/outpost_police/brain = wake(officer)
	brain.stealth_setup()
	TEST_ASSERT_EQUAL(brain.route_id, "a", "The officer did not take its beat")
	for(var/dy in 0 to 6)
		var/turf/wall_spot = at(8, dy)
		wall_spot.ChangeTurf(/turf/closed/wall)
	// Seven tiles and a wall: a pistol carries 9, the wall costs half its 3 for a loud noise
	var/mob/living/carbon/human/shooter = visitor_at(11, 3)
	var/heard_by = stealth_noise(get_turf(shooter), "gun_pistol", null, shooter)
	TEST_ASSERT_EQUAL(brain.stealth_state(), "searching", "A pistol shot through a wall seven tiles off did not send the officer to look (heard by [heard_by], officer's AI [brain.ai_status], held still [officer.paused_at], officer's group [brain.group ? "yes" : "none"], muffled distance [stealth_muffled_dist(get_turf(shooter), get_turf(officer), 2)], players on the level [length(SSmobs.clients_by_zlevel[officer.z])], groups [length(GLOB.stealth_groups)])")
	TEST_ASSERT(!length(police.warrants) && !length(police.pending_reports), "A shot heard gave someone a record")

	brain.clear_blackboard_key(BB_BASIC_MOB_CURRENT_TARGET)
	brain.stealth_go_unaware()
	brain.stealth_clear_wary()
	brain.stealth_rewind(2 MINUTES)
	brain.glance_until = 0
	shooter.forceMove(at(12, 4))
	stealth_noise(get_turf(shooter), "gun_quiet", null, shooter)
	TEST_ASSERT_EQUAL(brain.stealth_state(), "unaware", "A suppressed shot eight tiles off moved the officer")

// ===== THE PUBLIC (owner decision 35) =====

/**
 * A visitor with a clean record who runs about behind an officer, bumps into it, talks and opens a door in front of it
 * gets no question mark; once they are wanted, the same steps are heard.
 */
/datum/unit_test/voidcrew_stealth_live/police/innocent_walker

/datum/unit_test/voidcrew_stealth_live/police/innocent_walker/Run()
	TEST_ASSERT(police_room(16, 7), "No room for the test")
	allocate(/obj/effect/landmark/stealth_group, at(0, 6))
	police_stop(8, 3, "a", 1, 10 MINUTES, null)
	var/mob/living/carbon/human/npc/ambient_npc/outpost/police/officer = officer_at(8, 3, EAST)
	officer.resume_routine()
	var/datum/ai_controller/basic_controller/human_npc/stealth/outpost_police/brain = wake(officer)
	brain.stealth_setup()
	TEST_ASSERT_EQUAL(brain.group?.outpost_police(), police, "The officer's patrol group does not know it is the police's")

	// A visitor on the list of players, running (tg's default), barefoot on plain floor: heard 5 tiles off
	var/mob/living/carbon/human/visitor = person_at(5, 3)
	visitor.mind_initialize()
	allocated += visitor.mind
	if(visitor.move_intent != MOVE_INTENT_RUN)
		visitor.toggle_move_intent()
	TEST_ASSERT(stealth_footstep_reach(visitor) > 0, "A running visitor makes no footsteps")

	// Running about behind it, right at its back
	stealth_scans(officer, 1)
	for(var/list/spot in list(list(6, 3), list(7, 3), list(7, 4), list(6, 4), list(7, 2)))
		visitor.forceMove(at(spot[1], spot[2]))
		stealth_scans(officer, 1)
	TEST_ASSERT_EQUAL(brain.stealth_state(), "unaware", "An officer went [brain.stealth_state()] at a clean visitor running behind it")

	// Bumping into it, a friendly hand, talking, a door in front of it
	brain.on_bumped(officer, visitor)
	brain.on_handled(officer, visitor)
	TEST_ASSERT_EQUAL(brain.stealth_state(), "unaware", "An officer went [brain.stealth_state()] at a clean visitor bumping into it")
	TEST_ASSERT_EQUAL(stealth_noise(get_turf(visitor), "voice", null, visitor), 0, "An officer heard a clean visitor talk")
	var/obj/machinery/door/airlock/door = allocate(/obj/machinery/door/airlock, at(11, 3))
	TEST_ASSERT_EQUAL(stealth_door_moved(door, TRUE), 0, "A door opening in front of an officer sent it to look")
	TEST_ASSERT_EQUAL(brain.stealth_state(), "unaware", "An officer went [brain.stealth_state()] at a door or a voice")
	TEST_ASSERT(!length(brain.notice_map), "An officer keeps notice on a clean visitor")

	// Wanted, the same steps behind it are heard
	police_pin_warrant(police, visitor.mind, 12) // one star
	visitor.forceMove(at(5, 3))
	stealth_scans(officer, 1)
	visitor.forceMove(at(7, 3))
	stealth_scans(officer, 1)
	TEST_ASSERT(brain.stealth_state() != "unaware", "An officer did not hear a wanted person run up behind it")
	police_pin_warrant(police, visitor.mind, 0)

// ===== THE BEAT =====

/// A beat officer made on stop 1 claims the route and walks to stop 2; a coffee stop runs the coffee while it waits; carried off and back it walks its route again; a spare beat officer takes a free route; stars at 0 send it back to its beat
/datum/unit_test/voidcrew_stealth_live/police/beat

/datum/unit_test/voidcrew_stealth_live/police/beat/Run()
	TEST_ASSERT(police_room(20, 7), "No room for the test")
	allocate(/obj/effect/landmark/stealth_group, at(0, 6))
	var/obj/effect/landmark/stealth_patrol/police/first = police_stop(2, 2, "a", 1, 5 SECONDS, "shopfront")
	first.route_mode = "loop"
	police_stop(6, 2, "a", 2, 30 SECONDS, "coffee")
	police_stop(16, 2, "b", 1, 5 SECONDS, null)
	var/obj/machinery/vending/coffee/machine = allocate(/obj/machinery/vending/coffee, at(7, 3))
	// The test room is the outpost's public floor, as a mapped concourse is (a stop's activity stands only on public floor)
	var/datum/ambient_place/outpost/place = SSambient_npcs.outpost_place(outpost)
	place.public_floor = list()
	for(var/turf/open/tile in block(room.bottom_left_turfs[1], room.top_right_turfs[1]))
		place.public_floor[tile] = TRUE
	place.floor_built_at = world.time

	var/mob/living/carbon/human/npc/ambient_npc/outpost/police/officer = officer_at(2, 2, NORTH)
	var/datum/ai_controller/basic_controller/human_npc/stealth/outpost_police/brain = officer.ai_controller
	brain.stealth_setup()
	TEST_ASSERT_EQUAL(brain.route_id, "a", "A beat officer made on stop 1 did not claim its route")
	TEST_ASSERT_EQUAL(brain.route_index, 1, "A beat officer made on stop 1 does not start there")
	brain.stealth_plan_route()
	TEST_ASSERT(brain.at_stop, "A beat officer on its first stop is not stopped there")
	brain.wait_until = world.time - 1
	brain.stealth_plan_route()
	TEST_ASSERT_EQUAL(brain.goto_dest, at(6, 2), "A beat officer does not walk on to stop 2")

	// The coffee stop
	brain.stealth_drop_walk()
	officer.forceMove(at(6, 2))
	brain.stealth_plan_route()
	TEST_ASSERT(brain.at_stop && brain.route_index == 2, "A beat officer at stop 2 is not stopped there")
	var/datum/ai_planning_subtree/outpost_police_stop/stop_subtree = locate() in brain.planning_subtrees
	stop_subtree.SelectBehaviors(brain, 1)
	TEST_ASSERT(istype(officer.activity, /datum/ambient_activity/police_coffee), "At a coffee stop the officer did not go for a coffee (stop tag [brain.police_stop_tag_now() || "none"], visit [brain.police_stop_visit] of [brain.wait_until], doing [officer.activity?.type || "nothing"], held still [officer.paused_at], beside the machine: [police_spot_report(officer, machine)])")
	TEST_ASSERT_EQUAL(officer.activity.anchor(), machine, "The officer went for a coffee somewhere else")
	brain.wait_until = world.time - 1
	stop_subtree.SelectBehaviors(brain, 1)
	TEST_ASSERT_NULL(officer.activity, "The coffee went on after the stop's wait")

	// Carried off its region and back: its route again (abuse M29)
	brain.stealth_become_sentry(get_turf(officer))
	TEST_ASSERT_NULL(brain.route_id, "Carried off, it kept walking its route")
	brain.police_take_route_back()
	TEST_ASSERT_EQUAL(brain.route_id, "a", "Back home, it did not take its route again")

	// A beat officer with no stop under it (a replacement off the lift) takes the free route
	var/mob/living/carbon/human/npc/ambient_npc/outpost/police/spare = officer_at(11, 5, SOUTH)
	var/datum/ai_controller/basic_controller/human_npc/stealth/outpost_police/spare_brain = spare.ai_controller
	spare_brain.stealth_setup()
	TEST_ASSERT_NULL(spare_brain.route_id, "A beat officer off its routes claimed one where it stood")
	police.stealth_tick_officer(spare)
	TEST_ASSERT_EQUAL(spare_brain.route_id, "b", "A spare beat officer did not take the free route")
	TEST_ASSERT_EQUAL(spare_brain.home_turf, at(16, 2), "A spare beat officer does not head for its route's first stop")

	// Stars at 0: back to unaware and its beat
	var/mob/living/carbon/human/suspect = visitor_at(9, 2)
	var/datum/outpost_warrant/warrant = police_pin_warrant(police, suspect.mind, 15)
	officer.setDir(EAST)
	brain.stealth_go_alert(suspect)
	TEST_ASSERT_EQUAL(brain.stealth_state(), "alert", "Fixture: the officer is not alert on a one-star suspect")
	police.stealth_tick_officer(officer)
	TEST_ASSERT_EQUAL(brain.stealth_state(), "alert", "An officer stood down while its suspect still had a star")
	warrant.heat = 0
	police.stealth_tick_officer(officer)
	TEST_ASSERT_EQUAL(brain.stealth_state(), "unaware", "An officer stayed on a suspect with no stars")
	TEST_ASSERT_EQUAL(brain.route_id, "a", "An officer stood down lost its beat")

/// A coffee stop with no coffee machine at hand but a counter (Halcyon's diner) has a cup at the counter; with neither it stands. A plain stop checks in over the radio.
/datum/unit_test/voidcrew_stealth_live/police/coffee_counter

/datum/unit_test/voidcrew_stealth_live/police/coffee_counter/Run()
	TEST_ASSERT(police_room(9, 5), "No room for the test")
	var/mob/living/carbon/human/npc/ambient_npc/outpost/police/officer = officer_at(2, 2, NORTH)
	var/datum/ambient_activity/bare = police.stop_activity_for(officer, "coffee")
	TEST_ASSERT_NULL(bare, "A coffee stop with no machine and no counter gave [bare?.type]")
	var/obj/structure/table/counter = allocate(/obj/structure/table, at(3, 3))
	var/datum/ambient_activity/cup = police.stop_activity_for(officer, "coffee")
	TEST_ASSERT(istype(cup, /datum/ambient_activity/drink/police), "A coffee stop by a counter with no machine gave [cup?.type || "nothing"]")
	TEST_ASSERT_EQUAL(cup.anchor(), counter, "The coffee was taken somewhere other than the counter")
	qdel(cup)
	var/obj/machinery/vending/coffee/machine = allocate(/obj/machinery/vending/coffee, at(1, 3))
	var/datum/ambient_activity/vended = police.stop_activity_for(officer, "coffee")
	TEST_ASSERT(istype(vended, /datum/ambient_activity/police_coffee), "A coffee stop with a machine at hand did not use it ([vended?.type || "nothing"])")
	TEST_ASSERT_EQUAL(vended.anchor(), machine, "The coffee was taken from somewhere other than the machine")
	qdel(vended)

	// A plain stop: the radio check-in, not more than once in its gap, and never "all quiet" with a case open.
	// Stops only run for an officer who is up and about, not one held still with nobody around.
	officer.resume_routine()
	var/datum/outpost_police_voice/voice = police.life_voice()
	voice.next_check_in_at = 0
	police.cases["test case"] = TRUE
	police.stop_activity_for(officer, "watch")
	police.cases -= "test case"
	TEST_ASSERT_EQUAL(voice.next_check_in_at, 0, "A beat officer checked in all quiet with a case open")
	TEST_ASSERT_NULL(police.stop_activity_for(officer, "watch"), "A plain stop with nobody asleep near gave an activity")
	var/next_at = voice.next_check_in_at
	TEST_ASSERT(next_at > world.time, "A beat officer at a plain stop never checked in")
	police.stop_activity_for(officer, "watch")
	TEST_ASSERT_EQUAL(voice.next_check_in_at, next_at, "A beat officer checked in twice inside the gap")

/// A body on the floor near a stop is called in to the desk once, by whoever sees it first; a bagged one is not
/datum/unit_test/voidcrew_stealth_live/police/body_on_floor

/datum/unit_test/voidcrew_stealth_live/police/body_on_floor/Run()
	TEST_ASSERT(police_room(9, 5), "No room for the test")
	var/mob/living/carbon/human/npc/ambient_npc/outpost/police/officer = officer_at(2, 2, EAST)
	var/mob/living/carbon/human/npc/ambient_npc/outpost/police/partner = officer_at(2, 3, EAST)
	officer.resume_routine()
	partner.resume_routine()
	var/mob/living/carbon/human/body = person_at(5, 2, FALSE)
	body.death()
	TEST_ASSERT_EQUAL(body.stat, DEAD, "The body is not dead")
	var/datum/outpost_police_voice/voice = police.life_voice()
	var/datum/ambient_activity/police_body/call_in = officer.start_activity(police.stop_activity_for(officer, "watch"))
	TEST_ASSERT(istype(call_in), "An officer at a stop paid no mind to a body on the floor ([officer.activity?.type || "nothing"])")
	officer.activity_step(1)
	TEST_ASSERT(voice.context_free_at["body"] > world.time, "An officer looking at a body did not call it in") // POLICE_LINE_BODY
	TEST_ASSERT_NULL(partner.life_body_near(), "A second officer would call in a body already called in")
	officer.end_activity()

	// A body already bagged is in hand
	var/mob/living/carbon/human/bagged = person_at(5, 3, FALSE)
	bagged.death()
	var/obj/structure/closet/body_bag/bag = allocate(/obj/structure/closet/body_bag, at(6, 3))
	bagged.forceMove(bag)
	TEST_ASSERT_NULL(officer.life_body_near(), "An officer would call in a body in a bag")

/// A sergeant who comes in away from the desk heads for it and leaves the beat routes alone; from the desk, now and then a coffee from the machine beside it, drunk back at the desk
/datum/unit_test/voidcrew_stealth_live/police/sergeant_post

/datum/unit_test/voidcrew_stealth_live/police/sergeant_post/Run()
	TEST_ASSERT(police_room(20, 7), "No room for the test")
	allocate(/obj/effect/landmark/stealth_group, at(0, 6))
	police_stop(2, 2, "a", 1, 5 SECONDS, null)
	police_stop(8, 2, "a", 2, 5 SECONDS, null)
	police.desk_turf = at(14, 4)
	var/datum/ambient_place/outpost/place = SSambient_npcs.outpost_place(outpost)
	place.public_floor = list()
	for(var/turf/open/tile in block(room.bottom_left_turfs[1], room.top_right_turfs[1]))
		place.public_floor[tile] = TRUE
	place.floor_built_at = world.time

	// Off a lift that stands on a beat stop
	var/mob/living/carbon/human/npc/ambient_npc/outpost/police/sergeant/sergeant = officer_at(2, 2, NORTH, /mob/living/carbon/human/npc/ambient_npc/outpost/police/sergeant)
	sergeant.resume_routine()
	var/datum/ai_controller/basic_controller/human_npc/stealth/outpost_police/brain = sergeant.ai_controller
	brain.stealth_setup()
	TEST_ASSERT_NULL(brain.route_id, "A sergeant took beat route [brain.route_id]")
	TEST_ASSERT_EQUAL(brain.home_turf, police.desk_turf, "A sergeant who came in away from the desk does not head for it")
	TEST_ASSERT_EQUAL(police.free_route(brain.group), "a", "A sergeant kept the beat off its route")

	// At the desk, with the coffee machine two tiles off
	var/obj/machinery/vending/coffee/machine = allocate(/obj/machinery/vending/coffee, at(16, 4))
	sergeant.forceMove(police.desk_turf)
	sergeant.next_desk_coffee = 0
	TEST_ASSERT_EQUAL(brain.police_stop_tag_now(), "desk", "The sergeant at the desk is not at the desk")
	var/datum/ambient_activity/police_coffee/coffee = sergeant.start_activity(police.stop_activity_for(sergeant, "desk"))
	TEST_ASSERT(istype(coffee), "The sergeant never went for a coffee from the desk ([sergeant.activity?.type || "nothing"])")
	TEST_ASSERT_EQUAL(coffee.anchor(), machine, "The sergeant went to some other machine")
	TEST_ASSERT(coffee.carry_on, "The sergeant would drink it at the machine, not back at the desk")
	TEST_ASSERT(sergeant.next_desk_coffee > world.time, "Nothing keeps the sergeant from going straight back for another")
	sergeant.forceMove(coffee.spot)
	TEST_ASSERT_EQUAL(brain.police_stop_tag_now(), "desk", "At the machine beside the desk, the sergeant's coffee was cut short")
	sergeant.activity_step(1)
	var/obj/item/reagent_containers/cup/glass/drinkingglass/mug = sergeant.held_item
	TEST_ASSERT(istype(mug) && mug.reagents.has_reagent(/datum/reagent/consumable/coffee), "The sergeant at the machine holds no coffee")
	sergeant.end_activity()
	TEST_ASSERT(!QDELETED(mug) && sergeant.held_item == mug, "The sergeant left the coffee at the machine")
	TEST_ASSERT_NULL(brain.police_stop_tag_now(), "Off the desk with nothing to do, the sergeant is not sent back to it")

	// Back at the desk: the desk, and the coffee is drunk there
	sergeant.forceMove(police.desk_turf)
	var/datum/ambient_activity/police_desk/at_desk = sergeant.start_activity(police.stop_activity_for(sergeant, "desk"))
	TEST_ASSERT(istype(at_desk), "Back at the desk the sergeant did not take it ([sergeant.activity?.type || "nothing"])")
	var/before = mug.reagents.total_volume
	at_desk.next_sip = 0
	sergeant.activity_step(1)
	TEST_ASSERT(mug.reagents.total_volume < before, "The sergeant never drank the coffee at the desk")
	sergeant.end_activity()

/// Armed alert officers open lockers they saw a suspect climb into, and hold fire on lockers entered unseen
/datum/unit_test/voidcrew_stealth_live/police/closet_pursuit

/datum/unit_test/voidcrew_stealth_live/police/closet_pursuit/Run()
	TEST_ASSERT(police_room(14, 7), "No room for the test")
	var/mob/living/carbon/human/npc/ambient_npc/outpost/police/officer = officer_at(4, 3, EAST)
	var/datum/ai_controller/basic_controller/human_npc/stealth/outpost_police/brain = officer.ai_controller
	brain.stealth_setup()
	var/mob/living/carbon/human/suspect = visitor_at(6, 3)
	police_pin_warrant(police, suspect.mind, 30) // two stars (POLICE_FORCE_STUN)
	var/obj/structure/closet/locker = allocate(/obj/structure/closet, at(6, 3))
	locker.open()

	// Seen on open ground, then shut inside the locker in front of the officer
	brain.stealth_go_alert(suspect)
	locker.close()
	TEST_ASSERT_EQUAL(suspect.loc, locker, "Fixture: the suspect was not shut inside the locker")
	TEST_ASSERT(brain.stealth_closet_track(suspect), "The officer did not track the suspect into the locker")
	TEST_ASSERT_EQUAL(brain.shut_in, locker, "The officer did not claim the locker it saw shut")

	var/datum/ai_planning_subtree/outpost_police_force/force_tree = locate() in brain.planning_subtrees
	var/datum/ai_planning_subtree/stealth_closet/closet_tree = locate() in brain.planning_subtrees
	brain.planned_behaviors.Cut()
	var/force_res = force_tree.SelectBehaviors(brain, 1)
	TEST_ASSERT_NULL(force_res, "The force subtree ended planning instead of yielding to stealth_closet")
	TEST_ASSERT(!(locate(/datum/ai_behavior/human_npc_shoot) in brain.planned_behaviors), "The force subtree planned a shot at a closed locker")
	closet_tree.SelectBehaviors(brain, 1)
	TEST_ASSERT(length(brain.planned_behaviors) > 0, "stealth_closet planned nothing for the claimed locker")
	officer.forceMove(at(5, 3))
	brain.stealth_try_closet()
	TEST_ASSERT(locker.opened, "The officer beside the locker did not open it")

	// Entered unseen: holds fire and stands watch, never shoots the container
	locker.close()
	brain.stealth_drop_closet()
	brain.target_free_seen_at = -10 MINUTES
	brain.planned_behaviors.Cut()
	TEST_ASSERT_NULL(force_tree.SelectBehaviors(brain, 1), "The force subtree did not yield on an unseen locker")
	closet_tree.SelectBehaviors(brain, 1)
	TEST_ASSERT(!!(locate(/datum/ai_behavior/stealth_stand) in brain.planned_behaviors), "An officer did not hold fire on a locker entered unseen")
	brain.planned_behaviors.Cut()
	police_pin_warrant(police, suspect.mind, 0)

/// Response units never claim beat routes, and a second beat officer made beside a taken route claims the free one
/datum/unit_test/voidcrew_stealth_live/police/route_guards

/datum/unit_test/voidcrew_stealth_live/police/route_guards/Run()
	TEST_ASSERT(police_room(20, 7), "No room for the test")
	allocate(/obj/effect/landmark/stealth_group, at(0, 6))
	police_stop(2, 2, "a", 1, 5 SECONDS, null)
	police_stop(8, 2, "a", 2, 5 SECONDS, null)
	police_stop(16, 2, "b", 1, 5 SECONDS, null)

	// A response officer stepping off a lift beside stop 1 of route "a" leaves the beat route free
	var/mob/living/carbon/human/npc/ambient_npc/outpost/police/responder = officer_at(2, 2, EAST, /mob/living/carbon/human/npc/ambient_npc/outpost/police/officer)
	var/datum/ai_controller/basic_controller/human_npc/stealth/outpost_police/resp_brain = responder.ai_controller
	resp_brain.stealth_setup()
	TEST_ASSERT_NULL(resp_brain.route_id, "A response officer claimed beat route [resp_brain.route_id]")
	TEST_ASSERT_EQUAL(police.free_route(resp_brain.group), "a", "A response officer blocked beat route a")

	// Beat #1 takes route "a"; Beat #2 spawning within claim range of route "a" takes free route "b" instead of doubling up
	var/mob/living/carbon/human/npc/ambient_npc/outpost/police/beat_one = officer_at(2, 2, EAST)
	var/datum/ai_controller/basic_controller/human_npc/stealth/outpost_police/brain_one = beat_one.ai_controller
	brain_one.stealth_setup()
	TEST_ASSERT_EQUAL(brain_one.route_id, "a", "The first beat officer did not claim route a")

	var/mob/living/carbon/human/npc/ambient_npc/outpost/police/beat_two = officer_at(3, 2, EAST)
	var/datum/ai_controller/basic_controller/human_npc/stealth/outpost_police/brain_two = beat_two.ai_controller
	brain_two.stealth_setup()
	TEST_ASSERT_EQUAL(brain_two.route_id, "b", "A replacement beat officer beside a taken route got [brain_two.route_id || "none"] instead of free route b")

/// Container bumps, passive crowd pulls and peaceful non-player NPCs do not make concourse officers suspicious
/datum/unit_test/voidcrew_stealth_live/police/public_crowd

/datum/unit_test/voidcrew_stealth_live/police/public_crowd/Run()
	TEST_ASSERT(police_room(14, 7), "No room for the test")
	allocate(/obj/effect/landmark/stealth_group, at(0, 6))
	police_stop(6, 3, "a", 1, 10 MINUTES, null)
	var/mob/living/carbon/human/npc/ambient_npc/outpost/police/officer = officer_at(6, 3, EAST)
	officer.resume_routine()
	var/datum/ai_controller/basic_controller/human_npc/stealth/outpost_police/brain = wake(officer)
	brain.stealth_setup()

	var/mob/living/carbon/human/visitor = visitor_at(4, 3)
	var/obj/structure/closet/crate/crate = allocate(/obj/structure/closet/crate, at(5, 3))
	crate.open()
	visitor.forceMove(crate)
	crate.close()
	brain.on_bumped(officer, crate)
	TEST_ASSERT_EQUAL(brain.stealth_state(), "unaware", "A crate holding a clean visitor bumping an officer put it in [brain.stealth_state()]")
	crate.open()
	visitor.forceMove(at(5, 3))

	visitor.start_pulling(officer, supress_message = TRUE)
	TEST_ASSERT_EQUAL(brain.stealth_state(), "unaware", "A clean visitor passively pulling an officer put it in [brain.stealth_state()]")
	visitor.stop_pulling()

	// Peaceful NPC with no mind (e.g. a blending-in fugitive or neutral bystander) makes no footstep or voice suspicion
	var/mob/living/carbon/human/bystander_npc = person_at(4, 4, FALSE)
	TEST_ASSERT(!officer.police_has_business(bystander_npc), "An officer had business with a peaceful non-player human")
	TEST_ASSERT_EQUAL(stealth_noise(get_turf(bystander_npc), "voice", null, bystander_npc), 0, "An officer heard a peaceful NPC's everyday voice")
	bystander_npc.forceMove(at(5, 4))
	stealth_scans(officer, 1)
	TEST_ASSERT_EQUAL(brain.stealth_state(), "unaware", "A peaceful NPC's footsteps put an officer in [brain.stealth_state()]")

/// A pilot in a mech is seen all round while a closed locker hides; a blind viewer never convicts; multiple witnesses must all be silenced
/datum/unit_test/voidcrew_stealth_live/police/mech_blind_and_witnesses

/datum/unit_test/voidcrew_stealth_live/police/mech_blind_and_witnesses/Run()
	TEST_ASSERT(police_room(20, 9), "No room for the test")
	var/datum/outpost_police_perception/stealth/perception = police.perception
	var/mob/living/carbon/human/npc/ambient_npc/outpost/police/officer = officer_at(8, 4, EAST)
	var/mob/living/carbon/human/pilot = visitor_at(4, 4)

	// Behind the officer's back on foot: unseen. Inside a mech on the same tile: seen all round, and suspect_seen() holds.
	TEST_ASSERT(!perception.sees(officer, pilot), "Setup: an unaware officer saw someone on foot behind its back")
	var/obj/vehicle/sealed/mecha/ripley/mech = allocate(/obj/vehicle/sealed/mecha/ripley, at(4, 4))
	pilot.forceMove(mech)
	TEST_ASSERT(perception.sees(officer, pilot), "An officer did not see an offender piloting a mech")
	TEST_ASSERT(police.suspect_seen(pilot), "suspect_seen() missed a suspect inside a mech")
	pilot.forceMove(at(11, 4))

	// Inside a closed locker in front of the officer: hidden
	var/obj/structure/closet/locker = allocate(/obj/structure/closet, at(11, 4))
	locker.opened = FALSE
	pilot.forceMove(locker)
	TEST_ASSERT(!perception.sees(officer, pilot), "An officer saw someone shut inside a closed locker")
	pilot.forceMove(at(11, 4))

	// A blinded officer sees nobody, even in front or when struck
	officer.become_blind(TRAIT_SOURCE_UNIT_TESTS)
	TEST_ASSERT(!perception.sees(officer, pilot), "A blind officer saw someone in front of it")
	TEST_ASSERT(!perception.struck_sees(officer, pilot), "A blind officer saw whoever struck it")
	officer.cure_blind(TRAIT_SOURCE_UNIT_TESTS)

	// A restrained trader cannot trigger an instant shop report
	var/mob/living/carbon/human/npc/ambient_npc/outpost/trader/trader = pa_trader(outpost, at(2, 2), at(2, 3), /datum/outpost_shop/vendor/bait_shop)
	ADD_TRAIT(trader, TRAIT_RESTRAINED, TRAIT_SOURCE_UNIT_TESTS)
	var/mob/living/carbon/human/brawler = visitor_at(3, 2)
	var/mob/living/carbon/human/dummy = person_at(4, 2, FALSE)
	officer.forceMove(at(18, 8))
	officer.setDir(EAST)
	TEST_ASSERT_NULL(police.report_crime(brawler, "unarmed", dummy), "A restrained trader reported a crime")
	TEST_ASSERT_EQUAL(length(police.pending_reports), 0, "A restrained trader with nobody else watching queued a report")
	REMOVE_TRAIT(trader, TRAIT_RESTRAINED, TRAIT_SOURCE_UNIT_TESTS)
	qdel(trader)

	// Two ambient townspeople witness a crime: restraining only the first does not silence the second
	var/datum/ambient_place/outpost/place = SSambient_npcs.outpost_place(outpost)
	var/mob/living/carbon/human/npc/ambient_npc/outpost/first_local = allocate(/mob/living/carbon/human/npc/ambient_npc/outpost, at(3, 1))
	var/mob/living/carbon/human/npc/ambient_npc/outpost/second_local = allocate(/mob/living/carbon/human/npc/ambient_npc/outpost, at(4, 1))
	first_local.set_place(place)
	second_local.set_place(place)
	police.recent_reports.Cut()
	TEST_ASSERT_NULL(police.report_crime(brawler, "shot", dummy), "A townsperson's report counted without waiting")
	TEST_ASSERT_EQUAL(length(police.pending_reports), 1, "The townspeople's report was not queued")
	ADD_TRAIT(first_local, TRAIT_RESTRAINED, TRAIT_SOURCE_UNIT_TESTS)
	var/datum/outpost_pending_report/local_report = police.pending_reports[1]
	local_report.due = world.time
	police.tick_warrants()
	TEST_ASSERT_EQUAL(police.get_warrant(brawler.mind)?.heat, 25, "Restraining one of two witnessing townspeople silenced the other")
	REMOVE_TRAIT(first_local, TRAIT_RESTRAINED, TRAIT_SOURCE_UNIT_TESTS)

/// Fading-out NPCs neither witness crimes, hold a suspect's hide clock, nor finish delayed reports, and a player in an officer's body reports immediately on stealth rules
/datum/unit_test/voidcrew_stealth_live/police/fading_and_played_witness

/datum/unit_test/voidcrew_stealth_live/police/fading_and_played_witness/Run()
	TEST_ASSERT(police_room(20, 9), "No room for the test")
	var/datum/outpost_police_perception/stealth/perception = police.perception
	var/datum/ambient_place/outpost/place = SSambient_npcs.outpost_place(outpost)

	// A departing officer fading out down the lift neither sees a crime nor holds suspect_seen()
	var/mob/living/carbon/human/npc/ambient_npc/outpost/police/departing = officer_at(4, 4, EAST)
	var/mob/living/carbon/human/suspect = visitor_at(6, 4)
	var/mob/living/carbon/human/dummy = person_at(7, 4, FALSE)
	TEST_ASSERT(police.suspect_seen(suspect), "Setup: an awake officer facing the suspect did not see them")
	departing.fading = TRUE
	TEST_ASSERT(!police.suspect_seen(suspect), "A fading-out officer still held suspect_seen()")
	TEST_ASSERT_NULL(police.report_crime(suspect, "unarmed", dummy), "A fading-out officer witnessed a crime")
	TEST_ASSERT_EQUAL(length(police.pending_reports), 0, "A fading-out officer queued a crime report")
	departing.fading = FALSE
	qdel(departing)

	// A townsperson who starts fading out before their 3s report finishes cannot complete the report, nor witness a new one
	var/mob/living/carbon/human/npc/ambient_npc/outpost/local = allocate(/mob/living/carbon/human/npc/ambient_npc/outpost, at(5, 4))
	local.set_place(place)
	police.recent_reports.Cut()
	TEST_ASSERT_NULL(police.report_crime(suspect, "shot", dummy), "A townsperson's report counted without waiting")
	TEST_ASSERT_EQUAL(length(police.pending_reports), 1, "Setup: the townsperson's report was not queued")
	var/datum/outpost_pending_report/pending = police.pending_reports[1]
	local.fading = TRUE
	pending.due = world.time
	police.tick_warrants()
	TEST_ASSERT_NULL(police.get_warrant(suspect.mind), "A fading-out townsperson completed their delayed report")
	pending.expires = world.time
	police.tick_warrants()
	police.recent_reports.Cut()
	TEST_ASSERT_NULL(police.report_crime(suspect, "shot", dummy), "A fading-out townsperson witnessed a new crime")
	TEST_ASSERT_EQUAL(length(police.pending_reports), 0, "A fading-out townsperson queued a new report")
	local.fading = FALSE
	qdel(local)

	// Under stealth rules, a player in an officer's body sees all-round like a player and reports immediately (no 3s delay or radio-call gate)
	var/mob/living/carbon/human/npc/ambient_npc/outpost/police/played = officer_at(8, 4, EAST) // facing away from suspect at (6, 4)
	var/mob/living/carbon/human/donor = visitor_at(1, 1)
	donor.mind.transfer_to(played)
	TEST_ASSERT(perception.sees(played, suspect), "A player in an officer's body was cone-gated like an AI officer")
	TEST_ASSERT_EQUAL(perception.report_delay(played, "shot"), 0, "A player in an officer's body was given a civilian report delay")
	TEST_ASSERT(!perception.reports_by_call(played), "A player in an officer's body was gated on an AI radio call")
	police.recent_reports.Cut()
	TEST_ASSERT_EQUAL(police.report_crime(suspect, "shot", played), 2, "A player victim in an officer's body did not report immediately at two stars")

/// Seated officers unbuckle and put coffee down on duty; non-case watchers stand down when a standing suspect is cuffed; multi-occupant mechs track the wanted rider; departing officers disarm and keep stealth JPS
/datum/unit_test/voidcrew_stealth_live/police/duty_unbuckle_and_stand_down

/datum/unit_test/voidcrew_stealth_live/police/duty_unbuckle_and_stand_down/Run()
	TEST_ASSERT(police_room(20, 9), "No room for the test")

	// 1. Seated officer with coffee unbuckles and sets the drink down when given a case while unaware, or when put into searching
	var/mob/living/carbon/human/npc/ambient_npc/outpost/police/officer = officer_at(4, 3, EAST)
	officer.resume_routine()
	var/datum/ai_controller/basic_controller/human_npc/stealth/outpost_police/brain = officer.ai_controller
	var/obj/structure/chair/chair = allocate(/obj/structure/chair, at(4, 3))
	TEST_ASSERT(officer.sit_on(chair), "Setup: the officer could not sit on the chair")
	officer.take_drink(/datum/reagent/consumable/coffee)
	TEST_ASSERT(officer.buckled == chair && !isnull(officer.held_item), "Setup: the officer is not seated with a coffee")

	var/mob/living/carbon/human/suspect = visitor_at(8, 3)
	var/datum/outpost_warrant/warrant = police_pin_warrant(police, suspect.mind, 25) // two stars
	var/datum/outpost_police_case/case = police.open_case(warrant)
	police.sleep_tick()
	TEST_ASSERT_NOTNULL(case, "Setup: no arrest case opened at two stars")
	TEST_ASSERT_EQUAL(officer.case, case, "Setup: the seated officer was not assigned the case")
	brain.SelectBehaviors(1)
	brain.planned_behaviors.Cut()
	TEST_ASSERT(!officer.buckled, "A seated officer assigned a case stayed buckled when case planning ran before outpost_police_stop")
	TEST_ASSERT_NULL(officer.held_item, "A seated officer assigned a case kept holding their coffee")
	police.close_case(suspect.mind)
	brain.stealth_go_unaware()

	TEST_ASSERT(officer.sit_on(chair), "Setup: the officer could not sit on the chair a second time")
	officer.take_drink(/datum/reagent/consumable/coffee)
	brain.stealth_go_searching(at(8, 3))
	TEST_ASSERT(!officer.buckled, "A seated officer put into searching stayed buckled to their chair")
	TEST_ASSERT_NULL(officer.held_item, "A seated officer put into searching kept holding their coffee")
	brain.stealth_go_unaware()
	qdel(officer)

	// 2. A non-case watching officer stands down to unaware (not searching) when a standing suspect is cuffed into an open arrest
	var/mob/living/carbon/human/npc/ambient_npc/outpost/police/arresting = officer_at(7, 3, EAST)
	var/mob/living/carbon/human/npc/ambient_npc/outpost/police/watcher = officer_at(5, 3, EAST)
	var/datum/ai_controller/basic_controller/human_npc/stealth/outpost_police/watcher_brain = watcher.ai_controller
	case = police.open_case(warrant)
	police.sleep_tick()
	TEST_ASSERT_NOTNULL(case, "Setup: could not reopen the two-star case")
	if(watcher.case)
		case.drop_officer(watcher)
	watcher_brain.stealth_go_alert(suspect)
	TEST_ASSERT_EQUAL(watcher_brain.stealth_state(), "alert", "Setup: the watching officer is not alert on the suspect")
	var/obj/item/restraints/handcuffs/outpost_police/used/cuffs = allocate(/obj/item/restraints/handcuffs/outpost_police/used)
	TEST_ASSERT(suspect.equip_to_slot_if_possible(cuffs, ITEM_SLOT_HANDCUFFED, disable_warning = TRUE), "Setup: could not cuff the standing suspect")
	case.cuffs_on(suspect)
	TEST_ASSERT(!watcher_brain.stealth_keep_target(), "A non-case watching officer kept a cuffed arrestee as a fight target")
	TEST_ASSERT_EQUAL(watcher_brain.stealth_state(), "unaware", "A non-case watching officer went [watcher_brain.stealth_state()] instead of unaware when a standing suspect was cuffed")
	TEST_ASSERT_NULL(watcher_brain.police_hunt, "A stood-down watching officer kept police_hunt set")
	watcher.dispatch_mind = WEAKREF(suspect.mind)
	watcher_brain.police_research_at = 0
	police.stealth_tick_officer(watcher)
	TEST_ASSERT_EQUAL(watcher_brain.stealth_state(), "unaware", "stealth_tick_officer sent an officer searching for a restrained suspect already under arrest")
	watcher.dispatch_mind = null
	suspect.dropItemToGround(cuffs, TRUE)
	qdel(cuffs)
	police.close_case(suspect.mind)
	police_pin_warrant(police, suspect.mind, 0)
	qdel(arresting)
	qdel(watcher)

	// 3. Multi-occupant mech with clean pilot and three-star passenger keeps police_hunt on the wanted passenger without flapping
	var/mob/living/carbon/human/npc/ambient_npc/outpost/police/hunter = officer_at(6, 5, EAST, /mob/living/carbon/human/npc/ambient_npc/outpost/police/officer)
	var/datum/ai_controller/basic_controller/human_npc/stealth/outpost_police/hunter_brain = hunter.ai_controller
	var/mob/living/carbon/human/pilot = visitor_at(10, 5)
	var/mob/living/carbon/human/passenger = visitor_at(10, 5)
	var/datum/outpost_warrant/passenger_warrant = police_pin_warrant(police, passenger.mind, 55) // three stars
	var/obj/vehicle/sealed/mecha/ripley/mech = allocate(/obj/vehicle/sealed/mecha/ripley, at(10, 5))
	mech.max_occupants = 2
	mech.mob_enter(pilot, silent = TRUE)
	mech.mob_enter(passenger, silent = TRUE)
	TEST_ASSERT_EQUAL(mech.occupants[1], pilot, "Setup: clean pilot is not the first mech occupant")
	hunter_brain.stealth_go_alert(mech)
	TEST_ASSERT_EQUAL(hunter_brain.police_hunt?.resolve(), passenger.mind, "stealth_go_alert tracked the clean pilot instead of the wanted mech passenger")
	police.stealth_tick_officer(hunter)
	TEST_ASSERT_EQUAL(hunter_brain.stealth_state(), "alert", "stealth_tick_officer dropped alert on a mech with a clean pilot and wanted passenger")
	passenger_warrant.heat = 0
	police.stealth_tick_officer(hunter)
	TEST_ASSERT_EQUAL(hunter_brain.stealth_state(), "unaware", "stealth_tick_officer kept alert on a mech after its wanted passenger's warrant cleared")
	mech.mob_exit(passenger, silent = TRUE)
	mech.mob_exit(pilot, silent = TRUE)
	qdel(mech)

	// 4. Departing response officer stands easy, holsters weapons, clears its overhead stealth mark and keeps the 60-step stealth JPS pathfinder
	hunter.set_force(3) // POLICE_FORCE_LETHAL
	hunter_brain.stealth_go_searching(at(12, 5))
	hunter_brain.meter = new(hunter_brain, hunter)
	hunter_brain.meter.update()
	TEST_ASSERT(hunter.npc_walk_out(at(16, 5)), "npc_walk_out failed on a conscious officer")
	TEST_ASSERT_EQUAL(hunter_brain.stealth_state(), "unaware", "A departing officer walking out stayed in [hunter_brain.stealth_state()]")
	TEST_ASSERT_EQUAL(hunter.force, 0, "A departing officer walking out kept force [hunter.force] drawn")
	TEST_ASSERT_NULL(hunter_brain.meter, "A departing officer walking out kept its overhead stealth mark")
	TEST_ASSERT(istype(hunter_brain.ai_movement, /datum/ai_movement/jps/stealth), "A departing officer lost the stealth JPS pathfinder ([hunter_brain.ai_movement?.type])")
	hunter.npc_stop_leaving()

/// Stop activities check line of sight, reachability and partner eligibility, and preserve desk coffee cooldowns when blocked
/datum/unit_test/voidcrew_stealth_live/police/stop_filters

/datum/unit_test/voidcrew_stealth_live/police/stop_filters/Run()
	TEST_ASSERT(police_room(18, 9), "No room for the test")
	var/mob/living/carbon/human/npc/ambient_npc/outpost/police/officer = officer_at(4, 4, EAST)
	officer.resume_routine()

	// 1. Chat partner skips traders, recovery crews and walled-off NPCs, and reaches a free customer two tiles off
	var/mob/living/carbon/human/npc/ambient_npc/outpost/trader/keeper = allocate(/mob/living/carbon/human/npc/ambient_npc/outpost/trader, at(5, 4))
	keeper.outpost = outpost
	outpost.traders += keeper
	keeper.home = at(5, 4)
	keeper.resume_routine()
	var/mob/living/carbon/human/npc/ambient_npc/outpost/recovery/morgue/coroner = allocate(/mob/living/carbon/human/npc/ambient_npc/outpost/recovery/morgue, at(4, 5))
	coroner.resume_routine()
	for(var/dy in 0 to 8)
		var/turf/wall_spot = at(2, dy)
		wall_spot.ChangeTurf(/turf/closed/wall)
	var/mob/living/carbon/human/npc/ambient_npc/outpost/customer/walled_npc = allocate(/mob/living/carbon/human/npc/ambient_npc/outpost/customer, at(1, 4))
	walled_npc.resume_routine()
	TEST_ASSERT_NULL(officer.police_chat_partner(), "An officer chose a trader, recovery worker or walled-off NPC to chat with")
	var/mob/living/carbon/human/npc/ambient_npc/outpost/customer/townsperson = allocate(/mob/living/carbon/human/npc/ambient_npc/outpost/customer, at(6, 4))
	townsperson.set_place(SSambient_npcs.outpost_place(outpost))
	townsperson.resume_routine()
	qdel(keeper)
	TEST_ASSERT_EQUAL(officer.police_chat_partner(), townsperson, "An officer did not pick the free visible townsperson to chat with")
	var/datum/ambient_activity/chat/talk = officer.start_activity(police.stop_activity_for(officer, "chat"))
	TEST_ASSERT(istype(talk) && get_dist(talk.spot, officer) <= 3, "A two-tile chat stop failed setup or picked a spot outside stop reach")
	officer.end_activity()
	townsperson.end_activity()
	qdel(townsperson)
	qdel(coroner)
	qdel(walled_npc)

	// 2. Walled-off coffee machine is skipped in favour of a visible counter, and drink/police stays within stop reach
	var/obj/machinery/vending/coffee/walled_machine = allocate(/obj/machinery/vending/coffee, at(1, 3))
	var/obj/structure/table/bar_counter = allocate(/obj/structure/table, at(5, 4))
	var/obj/structure/table/far_table = allocate(/obj/structure/table, at(10, 4))
	var/obj/structure/chair/far_stool = allocate(/obj/structure/chair, at(10, 5))
	var/datum/ambient_activity/drink/police/bar_cup = officer.start_activity(police.stop_activity_for(officer, "coffee"))
	TEST_ASSERT(istype(bar_cup) && bar_cup.anchor() == bar_counter, "Coffee stop used a walled-off machine instead of the visible counter")
	TEST_ASSERT(get_dist(bar_cup.spot, officer) <= 3 && bar_cup.spot != get_turf(far_stool), "Counter coffee wandered to a distant booth outside stop reach")
	officer.end_activity()
	qdel(walled_machine)
	qdel(bar_counter)
	qdel(far_table)
	qdel(far_stool)

	// 3. A boxed-in sleeper with no reachable adjacent tile falls through to calling in a visible corpse
	var/mob/living/carbon/human/boxed_sleeper = visitor_at(6, 4)
	boxed_sleeper.Sleeping(5 MINUTES)
	var/list/box_tables = list()
	for(var/turf/around as anything in RANGE_TURFS(1, at(6, 4)))
		if(around != at(6, 4))
			box_tables += allocate(/obj/structure/table, around)
	var/mob/living/carbon/human/corpse = person_at(8, 4, FALSE)
	corpse.death()
	var/datum/ambient_activity/police_body/body_call = officer.start_activity(police.stop_activity_for(officer, "watch"))
	TEST_ASSERT(istype(body_call), "A boxed-in sleeper blocked the stop from calling in a visible corpse ([officer.activity?.type || "nothing"])")
	officer.end_activity()
	for(var/obj/structure/table/blocker as anything in box_tables)
		qdel(blocker)
	qdel(boxed_sleeper)
	qdel(corpse)

	// 4. Blocking every tile beside the sergeant's coffee machine falls back to the desk without burning next_desk_coffee
	police.desk_turf = at(13, 4)
	var/mob/living/carbon/human/npc/ambient_npc/outpost/police/sergeant/sergeant = officer_at(13, 4, SOUTH, /mob/living/carbon/human/npc/ambient_npc/outpost/police/sergeant)
	sergeant.resume_routine()
	sergeant.next_desk_coffee = 0
	var/obj/machinery/vending/coffee/desk_machine = allocate(/obj/machinery/vending/coffee, at(15, 4))
	var/list/machine_blockers = list()
	for(var/turf/around as anything in RANGE_TURFS(1, at(15, 4)))
		if(around != at(15, 4))
			machine_blockers += allocate(/obj/structure/table, around)
	var/datum/ambient_activity/fallback = sergeant.start_activity(police.stop_activity_for(sergeant, "desk"))
	TEST_ASSERT(istype(fallback, /datum/ambient_activity/police_desk), "A blocked desk coffee machine did not fall back to police_desk ([fallback?.type || "nothing"])")
	TEST_ASSERT_EQUAL(sergeant.next_desk_coffee, 0, "A blocked desk coffee machine burned next_desk_coffee")
	sergeant.end_activity()
	for(var/obj/structure/table/blocker as anything in machine_blockers)
		qdel(blocker)
	qdel(desk_machine)

#undef POLICE_STEALTH_BEAT

/// Cross-sector concourse <-> lobby walks are foot walks (not unfinished lift rides), while lobby -> hangar berth walks redirect cleanly toward the hangar elevator alcove
/datum/unit_test/voidcrew_outpost_police_stealth_sector_walks

/datum/unit_test/voidcrew_outpost_police_stealth_sector_walks/Run()
	var/obj/structure/overmap/trader_outpost/outpost = police_loaded_outpost()
	if(!outpost)
		return
	var/datum/outpost_police/police = outpost.police
	police.sleep_tick()
	TEST_ASSERT(length(outpost.lobby_alcove_turfs), "The outpost has no lobby elevator alcove")
	var/turf/concourse_tile = police_floor(outpost)
	TEST_ASSERT_NOTNULL(concourse_tile, "No free concourse tile found")
	var/turf/lobby_tile
	for(var/turf/candidate as anything in RANGE_TURFS(8, outpost.lobby_alcove_turfs[1]))
		if(isopenturf(candidate) && !candidate.is_blocked_turf(TRUE) && police.sector_of(candidate) == "lobby" && !(candidate in outpost.lobby_alcove_turfs))
			lobby_tile = candidate
			break
	TEST_ASSERT_NOTNULL(lobby_tile, "No open lobby floor tile outside the elevator alcove found")

	var/mob/living/carbon/human/npc/ambient_npc/outpost/police/officer = police_officer(outpost, /mob/living/carbon/human/npc/ambient_npc/outpost/police/officer, concourse_tile)
	var/datum/ai_controller/basic_controller/human_npc/stealth/outpost_police/brain = officer.ai_controller
	TEST_ASSERT(!brain.police_cross_sector_lift_walk(lobby_tile), "Concourse-to-lobby walk was treated as needing a lift ride")
	officer.forceMove(lobby_tile)
	TEST_ASSERT(!brain.police_cross_sector_lift_walk(concourse_tile), "Lobby-to-concourse walk was treated as needing a lift ride")

	var/datum/turf_reservation/claimed = SSmapping.request_turf_block_reservation(3, 3, 1, requester = "police stealth sector walk test")
	TEST_ASSERT_NOTNULL(claimed, "Could not reserve a 3x3 hangar alcove")
	var/datum/outpost_berth/berth = new(outpost, 1, null)
	berth.reservation = claimed
	for(var/turf/tile as anything in berth.get_block())
		tile.ChangeTurf(/turf/open/floor/iron)
	var/list/old_berths = outpost.berths
	outpost.berths = list(berth)
	var/turf/berth_tile = berth.get_block()[5]

	// With no elevator alcove tiles on the berth, a cross-sector walk there fails cleanly instead of looping to the lobby alcove
	berth.alcove_turfs = list()
	TEST_ASSERT(!brain.police_cross_sector_lift_walk(berth_tile), "A berth with no elevator alcove still counted as a rideable lift walk")
	brain.stealth_walk(berth_tile, "search")
	TEST_ASSERT_EQUAL(brain.goto_result, "failed", "A walk to an unrideable berth did not fail cleanly")
	brain.stealth_drop_walk()

	// With real alcove tiles on the berth, redirecting from an earlier walk updates goto_dest and aims goto_turf toward the lobby elevator alcove
	berth.alcove_turfs = berth.get_block()
	TEST_ASSERT(brain.police_cross_sector_lift_walk(berth_tile), "Lobby-to-berth walk did not register as needing the hangar elevator")
	brain.goto_dest = concourse_tile
	brain.goto_turf = concourse_tile
	brain.stealth_walk(berth_tile, "search")
	brain.planned_behaviors.Cut()
	TEST_ASSERT_EQUAL(brain.goto_dest, berth_tile, "Redirecting a stealth walk to a hangar berth did not update goto_dest")
	TEST_ASSERT(!isnull(brain.goto_turf) && brain.goto_turf != concourse_tile && brain.goto_turf != berth_tile, "Redirecting a stealth walk to a hangar berth kept stale goto_turf [brain.goto_turf]")

	brain.stealth_drop_walk()
	qdel(berth)
	outpost.berths = old_berths
	dispatch_clear(police)
