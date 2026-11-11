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
	var/datum/ai_controller/basic_controller/human_npc/stealth/outpost_police/brain = wake(officer)
	brain.stealth_setup()
	TEST_ASSERT_EQUAL(brain.route_id, "a", "The officer did not take its beat")
	for(var/dy in 0 to 6)
		var/turf/wall_spot = at(8, dy)
		wall_spot.ChangeTurf(/turf/closed/wall)
	// Seven tiles and a wall: a pistol carries 9, the wall costs half its 3 for a loud noise
	var/mob/living/carbon/human/shooter = visitor_at(11, 3)
	var/heard_by = stealth_noise(get_turf(shooter), "gun_pistol", null, shooter)
	TEST_ASSERT_EQUAL(brain.stealth_state(), "searching", "A pistol shot through a wall seven tiles off did not send the officer to look (heard by [heard_by], officer's group [brain.group ? "yes" : "none"], muffled distance [stealth_muffled_dist(get_turf(shooter), get_turf(officer), 2)], players on the level [length(SSmobs.clients_by_zlevel[officer.z])], groups [length(GLOB.stealth_groups)])")
	TEST_ASSERT(!length(police.warrants) && !length(police.pending_reports), "A shot heard gave someone a record")

	brain.clear_blackboard_key(BB_BASIC_MOB_CURRENT_TARGET)
	brain.stealth_go_unaware()
	brain.stealth_clear_wary()
	brain.stealth_rewind(2 MINUTES)
	brain.glance_until = 0
	shooter.forceMove(at(12, 4))
	stealth_noise(get_turf(shooter), "gun_quiet", null, shooter)
	TEST_ASSERT_EQUAL(brain.stealth_state(), "unaware", "A suppressed shot eight tiles off moved the officer")

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

#undef POLICE_STEALTH_BEAT
