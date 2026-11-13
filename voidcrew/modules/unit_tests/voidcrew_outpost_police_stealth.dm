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

/// A trader's report counts at once
/datum/unit_test/voidcrew_stealth_live/police/trader

/datum/unit_test/voidcrew_stealth_live/police/trader/Run()
	TEST_ASSERT(police_room(12, 6), "No room for the test")
	pa_trader(outpost, at(1, 1), at(1, 2), /datum/outpost_shop/vendor/bait_shop)
	var/mob/living/carbon/human/brawler = visitor_at(4, 1)
	var/mob/living/carbon/human/victim = person_at(5, 1, FALSE)
	TEST_ASSERT_NOTNULL(police.report_crime(brawler, "shot", victim), "A trader's report did not count at once")
	TEST_ASSERT_EQUAL(police.get_warrant(brawler.mind)?.heat, 25, "A trader's report put the wrong heat on")

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

	// A plain stop: the radio check-in, not more than once in its gap, and never "all quiet" with a case open
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

#undef POLICE_STEALTH_BEAT
