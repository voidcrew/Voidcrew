/**
 * # One slow-mo for a crew
 *
 * voidcrew/modules/cyberware/ware_sandy_timestop_shared.dm. Crewmates' slow-mos that touch become one: it lasts until
 * the last member's own time is out, a member out of time is slowed with the world, one replay plays at the end and
 * every crash lands after it. Another crew's player ends it for everyone with no replay.
 */
/datum/unit_test/voidcrew_cyberware_timestop/shared
	abstract_type = /datum/unit_test/voidcrew_cyberware_timestop/shared
	var/list/ships = list()
	var/list/teams = list()

/// Ships of earlier shared tests: test datums are only destroyed after the whole run.
GLOBAL_LIST_EMPTY(sandy_shared_test_ships)

/datum/unit_test/voidcrew_cyberware_timestop/shared/Destroy()
	for(var/obj/structure/overmap/ship/ship as anything in ships)
		SSovermap.simulated_ships -= ship
		ship.ship_team = null
	ships.Cut()
	for(var/datum/team/team as anything in teams)
		qdel(team)
	teams.Cut()
	return ..()

/// Puts every body in `bodies` on one ship's crew (cyberware_crew_team()).
/datum/unit_test/voidcrew_cyberware_timestop/shared/proc/make_crew(list/bodies)
	for(var/obj/structure/overmap/ship/old as anything in GLOB.sandy_shared_test_ships)
		SSovermap.simulated_ships -= old
		old.ship_team = null
	GLOB.sandy_shared_test_ships.Cut()
	var/obj/structure/overmap/ship/ship = new
	GLOB.sandy_shared_test_ships += ship
	var/datum/team/voidcrew/team = new
	team.name = "Test crew"
	team.ship = ship
	ship.ship_team = team
	SSovermap.simulated_ships |= ship
	ships += ship
	teams += team
	for(var/mob/living/body as anything in bodies)
		if(!body.mind)
			body.mind_initialize()
		team.add_member(body.mind)
		TEST_ASSERT_EQUAL(cyberware_crew_team(body), team, "Test fixture: [body] isn't on the crew")

/datum/unit_test/voidcrew_cyberware_timestop/shared/proc/session_of(mob/living/body)
	return GLOB.sandy_session_of[body]

/// Two Cascades, the second pressed a second after the first: one slow-mo until the second's time is out, the first
/// slowed with the world (still able to act) for the rest of it, one replay, both crashes after it.
/datum/unit_test/voidcrew_cyberware_timestop/shared/join

/datum/unit_test/voidcrew_cyberware_timestop/shared/join/Run()
	var/mob/living/carbon/human/first = make_user(spot(0, 0), "sandyone[type]")
	var/mob/living/carbon/human/second = make_user(spot(3, 0), "sandytwo[type]")
	make_crew(list(first, second))
	set_window(first, 2 SECONDS)
	set_window(second, 2 SECONDS)
	var/mob/living/carbon/human/npc/raider = allocate(/mob/living/carbon/human/npc, spot(1, 2))
	TEST_ASSERT(!cyberware_time_stop_witnessed(first), "Test fixture: a crewmate counts as a witness")

	var/datum/status_effect/cyberware_cascade_window/one = surge(first)
	sleep(1 SECONDS)
	TEST_ASSERT_NOTNULL(one.time_stop, "Test fixture: the first slow-mo didn't start")
	var/datum/sandy_replay/recording = GLOB.sandy_replays[first]
	TEST_ASSERT_NOTNULL(recording, "Test fixture: the first slow-mo isn't recording")
	var/datum/status_effect/cyberware_cascade_window/two = surge(second)
	sleep(0.1 SECONDS)
	TEST_ASSERT_NOTNULL(two.time_stop, "The crewmate's surge in the slow-mo didn't slow the world")
	var/datum/sandy_session/session = session_of(first)
	TEST_ASSERT_NOTNULL(session, "The two slow-mos didn't join")
	TEST_ASSERT_EQUAL(session_of(second), session, "The second surger is in another session")
	TEST_ASSERT_EQUAL(session.replay, recording, "The shared slow-mo isn't recorded by the first one's recording")
	TEST_ASSERT_NULL(GLOB.sandy_replays[second], "The second surger kept a recording of its own")
	TEST_ASSERT(abs(cyberware_time_scale(first) - 1) < 0.01, "The first Cascade isn't at normal speed beside the second ([cyberware_time_scale(first)])")
	TEST_ASSERT(abs(cyberware_time_scale(second) - 1) < 0.01, "The second Cascade isn't at normal speed beside the first ([cyberware_time_scale(second)])")
	TEST_ASSERT(abs(cyberware_time_scale(raider) - 0.1) < 0.01, "The NPC isn't at the world's 10% ([cyberware_time_scale(raider)])")

	sleep(1.1 SECONDS) // the first one's own time is out
	TEST_ASSERT(!first.has_status_effect(/datum/status_effect/cyberware_cascade_window), "Test fixture: the first window outlived its 2 s")
	TEST_ASSERT(!first.has_status_effect(/datum/status_effect/cyberware_cascade_crash), "The first surger crashed before the replay")
	TEST_ASSERT_EQUAL(recording.state, 1, "The recording stopped while the second surger still had time")
	TEST_ASSERT_NOTNULL(two.time_stop, "The shared slow-mo ended with the first one's time")
	TEST_ASSERT(abs(cyberware_time_scale(first) - 0.1) < 0.01, "The first surger, out of time, isn't slowed with the world ([cyberware_time_scale(first)])")
	TEST_ASSERT(first.has_movespeed_modifier(/datum/movespeed_modifier/cyberware_dilation), "The first surger's walk isn't slowed")
	TEST_ASSERT(!frozen(first), "The first surger was frozen")
	TEST_ASSERT(!first.get_filter("sandy_time_stop_outline"), "The first surger kept the edge glow")
	TEST_ASSERT(second.get_filter("sandy_time_stop_outline"), "The second surger lost the edge glow")
	var/turf/was = get_turf(first)
	first.Move(spot(0, 1), NORTH)
	TEST_ASSERT(get_turf(first) != was, "The slowed first surger couldn't move")

	sleep(1 SECONDS) // the second one's time is out: it all ends
	TEST_ASSERT(!second.has_status_effect(/datum/status_effect/cyberware_cascade_window), "Test fixture: the second window outlived its 2 s")
	TEST_ASSERT(!length(GLOB.cyberware_time_fields), "A field outlived the shared slow-mo")
	TEST_ASSERT(!first.has_status_effect(/datum/status_effect/cyberware_cascade_crash) && !second.has_status_effect(/datum/status_effect/cyberware_cascade_crash), "A crash landed before the replay")
	TEST_ASSERT(!QDELETED(recording) && recording.state >= 2, "The one replay didn't start at the end")
	wait_replay(first)
	TEST_ASSERT(GLOB.sandy_replay_last["played"], "The shared replay didn't play")
	TEST_ASSERT(first.has_status_effect(/datum/status_effect/cyberware_cascade_crash), "The first surger never crashed")
	TEST_ASSERT(second.has_status_effect(/datum/status_effect/cyberware_cascade_crash), "The second surger never crashed")
	TEST_ASSERT_NULL(session_of(first), "The session outlived its replay")
	first.remove_status_effect(/datum/status_effect/cyberware_cascade_crash)
	second.remove_status_effect(/datum/status_effect/cyberware_cascade_crash)

/// A member pressing the surge again drops out (slowed with the world) and the slow-mo goes on for the other.
/datum/unit_test/voidcrew_cyberware_timestop/shared/drop_out

/datum/unit_test/voidcrew_cyberware_timestop/shared/drop_out/Run()
	var/mob/living/carbon/human/first = make_user(spot(0, 0), "sandyone[type]")
	var/mob/living/carbon/human/second = make_user(spot(3, 0), "sandytwo[type]")
	make_crew(list(first, second))
	set_window(first, 3 SECONDS)
	set_window(second, 3 SECONDS)
	var/datum/status_effect/cyberware_cascade_window/one = surge(first)
	sleep(0.2 SECONDS)
	surge(second)
	sleep(0.3 SECONDS)
	var/datum/sandy_session/session = session_of(first)
	TEST_ASSERT_NOTNULL(session, "Test fixture: the two slow-mos didn't join")
	var/datum/action/cooldown/cyberware/cascade_surge/button = surge_button(second)
	TEST_ASSERT(button.Trigger(), "The second press did nothing")
	TEST_ASSERT(!second.has_status_effect(/datum/status_effect/cyberware_cascade_window), "The second press didn't end that member's window")
	TEST_ASSERT_NOTNULL(one.time_stop, "One member dropping out ended the shared slow-mo")
	TEST_ASSERT(abs(cyberware_time_scale(second) - 0.1) < 0.01, "The member who dropped out isn't slowed with the world")
	TEST_ASSERT(!second.has_status_effect(/datum/status_effect/cyberware_cascade_crash), "The member who dropped out crashed before the replay")
	TEST_ASSERT_EQUAL(session.replay?.state, 1, "The recording stopped when one member dropped out")
	qdel(one) // the other ends it
	sleep(0.1 SECONDS)
	wait_replay(first)
	TEST_ASSERT(second.has_status_effect(/datum/status_effect/cyberware_cascade_crash), "The member who dropped out never crashed")
	first.remove_status_effect(/datum/status_effect/cyberware_cascade_crash)
	second.remove_status_effect(/datum/status_effect/cyberware_cascade_crash)

/// A player from another crew coming near ends the shared slow-mo for everyone, with no replay.
/datum/unit_test/voidcrew_cyberware_timestop/shared/other_crew

/datum/unit_test/voidcrew_cyberware_timestop/shared/other_crew/Run()
	var/mob/living/carbon/human/first = make_user(spot(0, 0), "sandyone[type]")
	var/mob/living/carbon/human/second = make_user(spot(3, 0), "sandytwo[type]")
	make_crew(list(first, second))
	set_window(first, 4 SECONDS)
	set_window(second, 4 SECONDS)
	var/datum/status_effect/cyberware_cascade_window/one = surge(first)
	sleep(0.2 SECONDS)
	var/datum/status_effect/cyberware_cascade_window/two = surge(second)
	sleep(0.2 SECONDS)
	TEST_ASSERT_NOTNULL(session_of(first), "Test fixture: the two slow-mos didn't join")
	var/mob/living/carbon/human/stranger = allocate(/mob/living/carbon/human/consistent, spot(5, 0))
	stranger.key = "sandysharedstranger"
	sleep(0.5 SECONDS)
	TEST_ASSERT_NULL(one.time_stop, "Another crew's player didn't end the first member's slow-mo")
	TEST_ASSERT_NULL(two.time_stop, "Another crew's player didn't end the second member's slow-mo")
	TEST_ASSERT(!length(GLOB.cyberware_time_fields), "A field outlived another crew's player coming near")
	TEST_ASSERT_NULL(GLOB.sandy_replays[first], "The shared slow-mo cut short kept its recording")
	TEST_ASSERT_NULL(session_of(first), "The session outlived being cut short")
	stranger.key = null
	qdel(one)
	qdel(two)
	first.remove_status_effect(/datum/status_effect/cyberware_cascade_crash)
	second.remove_status_effect(/datum/status_effect/cyberware_cascade_crash)

/// Crewmates' slow-mos that don't touch stay apart, each with its own recording.
/datum/unit_test/voidcrew_cyberware_timestop/shared/apart

/datum/unit_test/voidcrew_cyberware_timestop/shared/apart/Run()
	var/turf/far = locate(run_loc_floor_bottom_left.x + 24, run_loc_floor_bottom_left.y, run_loc_floor_bottom_left.z)
	if(!far)
		far = locate(run_loc_floor_bottom_left.x - 24, run_loc_floor_bottom_left.y, run_loc_floor_bottom_left.z)
	TEST_ASSERT_NOTNULL(far, "Test fixture: no turf 24 tiles from the test room")
	var/mob/living/carbon/human/first = make_user(spot(0, 0), "sandyone[type]")
	var/mob/living/carbon/human/second = make_user(far, "sandytwo[type]")
	make_crew(list(first, second))
	set_window(first, 1 SECONDS)
	set_window(second, 1 SECONDS)
	var/datum/status_effect/cyberware_cascade_window/one = surge(first)
	var/datum/status_effect/cyberware_cascade_window/two = surge(second)
	sleep(0.3 SECONDS)
	TEST_ASSERT_NOTNULL(one.time_stop, "Test fixture: the first slow-mo didn't start")
	TEST_ASSERT_NOTNULL(two.time_stop, "Test fixture: the second slow-mo didn't start")
	TEST_ASSERT_NULL(session_of(first), "Slow-mos 24 tiles apart joined")
	TEST_ASSERT(GLOB.sandy_replays[first] && GLOB.sandy_replays[second] && GLOB.sandy_replays[first] != GLOB.sandy_replays[second], "Slow-mos apart don't each have their own recording")
	sleep(1 SECONDS)
	wait_replay(first)
	wait_replay(second)
	first.remove_status_effect(/datum/status_effect/cyberware_cascade_crash)
	second.remove_status_effect(/datum/status_effect/cyberware_cascade_crash)

/// A Cascade and a street model: the world runs at the Cascade's 10% (the street surger at its 2.5x over it), then at
/// the street model's 40% once the Cascade is out of time.
/datum/unit_test/voidcrew_cyberware_timestop/shared/mixed

/datum/unit_test/voidcrew_cyberware_timestop/shared/mixed/Run()
	var/mob/living/carbon/human/first = make_user(spot(0, 0), "sandyone[type]")
	var/mob/living/carbon/human/second = make_user(spot(3, 0), "sandytwo[type]", /obj/item/organ/cyberimp/cyberware/cascade/street)
	make_crew(list(first, second))
	set_window(first, 1 SECONDS)
	set_window(second, 3 SECONDS)
	var/mob/living/carbon/human/npc/raider = allocate(/mob/living/carbon/human/npc, spot(1, 2))
	surge(first)
	sleep(0.1 SECONDS)
	var/datum/status_effect/cyberware_cascade_window/two = surge(second)
	sleep(0.2 SECONDS)
	var/datum/sandy_session/session = session_of(first)
	TEST_ASSERT_NOTNULL(session, "Test fixture: the two slow-mos didn't join")
	TEST_ASSERT(abs(cyberware_time_scale(raider) - 0.1) < 0.01, "The world isn't at the Cascade's 10% ([cyberware_time_scale(raider)])")
	TEST_ASSERT(abs(cyberware_time_scale(second) - 0.25) < 0.01, "The street surger doesn't run at 2.5x the Cascade's world ([cyberware_time_scale(second)])")
	var/datum/sandy_replay/recording = session.replay
	var/rate_before = recording.clock_rate
	sleep(1 SECONDS) // the Cascade is out of time
	TEST_ASSERT_NOTNULL(two.time_stop, "The shared slow-mo ended with the Cascade's time")
	TEST_ASSERT(abs(cyberware_time_scale(raider) - 0.4) < 0.01, "The world didn't speed up to the street model's 40% ([cyberware_time_scale(raider)])")
	TEST_ASSERT(abs(cyberware_time_scale(second) - 1) < 0.01, "The street surger isn't at normal speed in its own pace ([cyberware_time_scale(second)])")
	TEST_ASSERT(abs(cyberware_time_scale(first) - 0.4) < 0.01, "The Cascade, out of time, isn't slowed with the world ([cyberware_time_scale(first)])")
	TEST_ASSERT(recording.clock_rate > rate_before * 3, "The recording's frames didn't follow the world's new pace")
	qdel(two)
	sleep(0.1 SECONDS)
	wait_replay(first)
	TEST_ASSERT(first.has_status_effect(/datum/status_effect/cyberware_cascade_crash) && second.has_status_effect(/datum/status_effect/cyberware_cascade_crash), "A crash didn't land after the replay")
	first.remove_status_effect(/datum/status_effect/cyberware_cascade_crash)
	second.remove_status_effect(/datum/status_effect/cyberware_cascade_crash)

/// A shared slow-mo ends at its cap however much time its members have left: the one replay, then every crash. A
/// crewmate pressing after it is over gets a slow-mo of their own.
/datum/unit_test/voidcrew_cyberware_timestop/shared/capped

/datum/unit_test/voidcrew_cyberware_timestop/shared/capped/Run()
	var/mob/living/carbon/human/first = make_user(spot(0, 0), "sandyone[type]")
	var/mob/living/carbon/human/second = make_user(spot(3, 0), "sandytwo[type]")
	var/mob/living/carbon/human/third = make_user(spot(5, 0), "sandythree[type]")
	make_crew(list(first, second, third))
	set_window(first, 10 SECONDS)
	set_window(second, 10 SECONDS)
	set_window(third, 1 SECONDS)
	var/datum/status_effect/cyberware_cascade_window/one = surge(first)
	sleep(0.2 SECONDS)
	var/datum/status_effect/cyberware_cascade_window/two = surge(second)
	sleep(0.1 SECONDS)
	var/datum/sandy_session/session = session_of(first)
	TEST_ASSERT_NOTNULL(session, "Test fixture: the two slow-mos didn't join")
	TEST_ASSERT_EQUAL(session.max_length, 30 SECONDS, "A shared slow-mo isn't capped at 30 seconds")
	var/datum/sandy_replay/recording = session.replay
	session.max_length = world.time - session.started + 0.5 SECONDS // the cap, brought within the test's reach
	sleep(0.8 SECONDS)
	TEST_ASSERT(QDELETED(one) && QDELETED(two), "A member's window outlived the cap")
	TEST_ASSERT(!length(GLOB.cyberware_time_fields), "A field outlived the cap")
	TEST_ASSERT(!QDELETED(recording) && recording.state >= 2, "The replay didn't start at the cap")
	TEST_ASSERT(!first.has_status_effect(/datum/status_effect/cyberware_cascade_crash) && !second.has_status_effect(/datum/status_effect/cyberware_cascade_crash), "A crash landed before the replay")
	wait_replay(first)
	TEST_ASSERT(GLOB.sandy_replay_last["played"], "The capped slow-mo's replay didn't play")
	TEST_ASSERT(first.has_status_effect(/datum/status_effect/cyberware_cascade_crash) && second.has_status_effect(/datum/status_effect/cyberware_cascade_crash), "A crash didn't land after the replay")
	TEST_ASSERT_NULL(session_of(first), "The session outlived its replay")

	var/datum/status_effect/cyberware_cascade_window/three = surge(third)
	sleep(0.1 SECONDS)
	TEST_ASSERT_NOTNULL(three.time_stop, "A crewmate's press after the cap didn't slow the world")
	TEST_ASSERT_NULL(session_of(third), "A press after the cap joined the old session")
	TEST_ASSERT_NOTNULL(GLOB.sandy_replays[third], "A press after the cap isn't recording a replay of its own")
	sleep(1 SECONDS)
	wait_replay(third)
	first.remove_status_effect(/datum/status_effect/cyberware_cascade_crash)
	second.remove_status_effect(/datum/status_effect/cyberware_cascade_crash)
	third.remove_status_effect(/datum/status_effect/cyberware_cascade_crash)
