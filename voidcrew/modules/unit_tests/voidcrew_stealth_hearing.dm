// Stealth guards: hearing (voidcrew/modules/stealth/stealth_noise.dm and friends). Unit tests compile before
// voidcrew/_DEFINES, so values from there are written out: noise kinds "gun_quiet", "gun_pistol", "gun_smg",
// "gun_long", "impact", "blast", "glass", "thrown", "knock", "bash", "door", "thud", "voice", "scream", "shout";
// flags LOS_ONLY 1, LOUD 2; call kinds REPORT 1, MISSING 2, ALARM 3; STEALTH_CHECKIN_TIME 30 s,
// STEALTH_RADIO_CALL_TIME 3 s, the heard mark "q_y0".
//
// Every test runs in the walled, lit room of voidcrew_stealth_live with a person on SSmobs' list of players, so
// the level is awake and guards hear. Those down to hear/cleanup never sleep: the AI is on but never gets a
// turn, so they pin what one noise does. The ones after them use real tg actions, and the last three let the
// real AI run.

#define STEALTH_HEAR_GUARD /mob/living/carbon/human/npc/ruin/trooper/scav
#define STEALTH_HEAR_LOOKOUT /mob/living/carbon/human/npc/ruin/trooper/scav/lookout

/datum/unit_test/voidcrew_stealth_live/hear
	abstract_type = /datum/unit_test/voidcrew_stealth_live/hear
	/// Stops handed out on route "a" so far
	var/stops_made = 0
	/// The group's marker
	var/obj/effect/landmark/stealth_group/marker

/// The room, its group marker in the top left corner, and a player far off in the bottom right one.
/datum/unit_test/voidcrew_stealth_live/hear/proc/hear_room(width, height)
	if(!make_room(width, height))
		return FALSE
	marker = allocate(/obj/effect/landmark/stealth_group, at(0, height - 1))
	person_at(width - 1, 0)
	return TRUE

/// Gives the room's floor gravity, for tests where something is thrown or falls (reserved space has none).
/datum/unit_test/voidcrew_stealth_live/hear/proc/ground()
	var/turf/corner = room.bottom_left_turfs[1]
	var/turf/far_corner = room.top_right_turfs[1]
	for(var/turf/open/spot in block(corner.x, corner.y, corner.z, far_corner.x, far_corner.y, corner.z))
		spot.AddElement(/datum/element/forced_gravity, 1)

/// A sentry at (dx, dy): awake and in the group.
/datum/unit_test/voidcrew_stealth_live/hear/proc/sentry(dx, dy, facing = EAST, guard_type = STEALTH_HEAR_GUARD)
	var/mob/living/carbon/human/npc/guard = allocate(guard_type, at(dx, dy))
	guard.setDir(facing)
	guard.AddElement(/datum/element/forced_gravity, 1)
	var/datum/ai_controller/basic_controller/human_npc/stealth/stealth_ai = wake(guard)
	stealth_ai.stealth_setup()
	return guard

/// A guard with a stop of route "a" under it, so it walks a route (it waits there ten minutes).
/datum/unit_test/voidcrew_stealth_live/hear/proc/walker(dx, dy, facing = EAST, guard_type = STEALTH_HEAR_GUARD)
	stop_at(dx, dy, ++stops_made, 10 MINUTES)
	return sentry(dx, dy, facing, guard_type)

/// Back to nothing on its mind, with every clock run out.
/datum/unit_test/voidcrew_stealth_live/hear/proc/settle(mob/living/guard)
	var/datum/ai_controller/basic_controller/human_npc/stealth/stealth_ai = guard.ai_controller
	stealth_ai.clear_blackboard_key(BB_BASIC_MOB_CURRENT_TARGET)
	stealth_ai.stealth_go_unaware()
	stealth_ai.stealth_clear_wary()
	stealth_ai.stealth_drop_call()
	stealth_ai.stealth_rewind(2 MINUTES)
	stealth_ai.glance_until = 0

/datum/unit_test/voidcrew_stealth_live/hear/proc/state_of(mob/living/guard)
	var/datum/ai_controller/basic_controller/human_npc/stealth/stealth_ai = guard.ai_controller
	return stealth_ai.stealth_state()

/datum/unit_test/voidcrew_stealth_live/hear/proc/no_targets(list/guards)
	for(var/mob/living/guard as anything in guards)
		var/datum/ai_controller/basic_controller/human_npc/stealth/stealth_ai = guard.ai_controller
		TEST_ASSERT(!stealth_ai.blackboard_key_exists(BB_BASIC_MOB_CURRENT_TARGET), "A sound gave [guard] a target")

/// Walls and doors on the line eat reach; glass and the two ends don't.
/datum/unit_test/voidcrew_stealth_live/hear/muffle

/datum/unit_test/voidcrew_stealth_live/hear/muffle/Run()
	TEST_ASSERT(hear_room(20, 3), "No room for the test")
	var/turf/west = at(0, 1)
	var/turf/east = at(8, 1)
	TEST_ASSERT_EQUAL(stealth_muffled_dist(west, east, 0), 8, "An open line isn't its plain distance")
	var/turf/wall_spot = at(4, 1)
	wall_spot.ChangeTurf(/turf/closed/wall)
	TEST_ASSERT_EQUAL(stealth_muffled_dist(west, east, 0), 11, "One wall didn't cost 3 tiles")
	TEST_ASSERT_EQUAL(stealth_muffled_dist(west, east, 2), 9.5, "A loud sound didn't lose half as much to a wall")
	TEST_ASSERT_EQUAL(stealth_muffled_dist(west, east, 1), INFINITY, "A line-of-sight sound went through a wall")
	TEST_ASSERT_EQUAL(stealth_muffled_dist(wall_spot, west, 0), 4, "A sound on a wall is muffled on its west side")
	TEST_ASSERT_EQUAL(stealth_muffled_dist(wall_spot, east, 0), 4, "A sound on a wall is muffled on its east side")
	var/obj/machinery/door/airlock/door = allocate(/obj/machinery/door/airlock, at(6, 1))
	TEST_ASSERT(door.density, "The airlock isn't shut")
	TEST_ASSERT_EQUAL(stealth_muffled_dist(west, east, 0), 13, "A wall and a closed airlock didn't cost 5 tiles")
	qdel(door)
	allocate(/obj/structure/window/fulltile, at(6, 1))
	TEST_ASSERT_EQUAL(stealth_muffled_dist(west, east, 0), 11, "A window muffled a sound")
	for(var/dx in list(2, 3, 5))
		var/turf/more = at(dx, 1)
		more.ChangeTurf(/turf/closed/wall)
	TEST_ASSERT_EQUAL(stealth_muffled_dist(west, east, 2), INFINITY, "A sound was heard through four walls")

/// Every kind has a profile; a gun is never heard further than tg plays its own sound; tiers and suppressors.
/datum/unit_test/voidcrew_stealth_live/hear/guns

/datum/unit_test/voidcrew_stealth_live/hear/guns/Run()
	TEST_ASSERT(hear_room(5, 3), "No room for the test")
	for(var/kind in list("gun_quiet", "gun_pistol", "gun_smg", "gun_long", "impact", "blast", "glass", "thrown", "knock", "bash", "door", "thud", "voice", "scream", "shout"))
		var/list/profile = stealth_noise_profile(kind)
		TEST_ASSERT_EQUAL(length(profile), 3, "Noise kind [kind] has no profile")
		TEST_ASSERT(profile[1] > 0 && profile[2] > 0 && isnum(profile[3]), "Noise kind [kind] has a bad profile")
	var/turf/here = at(1, 1)
	var/list/expected = list(
		/obj/item/gun/ballistic/automatic/pistol = "gun_pistol",
		/obj/item/gun/ballistic/revolver = "gun_pistol",
		/obj/item/gun/energy/laser = "gun_pistol",
		/obj/item/gun/ballistic/automatic/c20r = "gun_smg",
		/obj/item/gun/ballistic/rifle/boltaction = "gun_long",
		/obj/item/gun/ballistic/shotgun = "gun_long",
		/obj/item/gun/ballistic/bow/longbow = "gun_quiet",
		/obj/item/gun/ballistic/automatic/pistol/suppressed = "gun_quiet",
	)
	for(var/gun_type in expected)
		var/obj/item/gun/gun = allocate(gun_type, here)
		var/list/noise = gun.stealth_shot_noise()
		TEST_ASSERT_EQUAL(noise[1], expected[gun_type], "[gun_type] is the wrong loudness")
	var/obj/item/gun/ballistic/automatic/pistol/pistol = allocate(/obj/item/gun/ballistic/automatic/pistol, here)
	TEST_ASSERT_EQUAL(pistol.stealth_shot_noise()[2], 9, "A pistol's reach isn't 9")
	pistol.fire_sound_volume = 10
	TEST_ASSERT(pistol.stealth_shot_noise()[2] < 9, "A quiet custom gun is heard as far as a loud one")
	pistol.install_suppressor(new /obj/item/suppressor(pistol))
	var/list/quiet = pistol.stealth_shot_noise()
	TEST_ASSERT_EQUAL(quiet[1], "gun_quiet", "A pistol with a suppressor fitted isn't quiet")
	TEST_ASSERT_EQUAL(quiet[2], 4, "A suppressed shot's reach isn't 4")

/// tg's footstep rules: running is heard, walking and every silencer are not.
/datum/unit_test/voidcrew_stealth_live/hear/footstep_reach

/datum/unit_test/voidcrew_stealth_live/hear/footstep_reach/Run()
	TEST_ASSERT(hear_room(6, 3), "No room for the test")
	var/mob/living/carbon/human/runner = person_at(1, 1, FALSE)
	TEST_ASSERT_EQUAL(stealth_footstep_reach(runner), 0, "A walking step is heard")
	runner.toggle_move_intent()
	TEST_ASSERT_EQUAL(stealth_footstep_reach(runner), 5, "A running step barefoot on plain floor doesn't carry 5")
	runner.equip_to_slot_or_del(new /obj/item/clothing/shoes/sneakers/black(runner), ITEM_SLOT_FEET)
	TEST_ASSERT_EQUAL(stealth_footstep_reach(runner), 5, "A running step in shoes on plain floor doesn't carry 5")
	var/turf/plating = at(3, 1)
	plating.ChangeTurf(/turf/open/floor/plating)
	runner.forceMove(plating)
	TEST_ASSERT(stealth_footstep_reach(runner) > 5, "Plating is no louder than floor")
	runner.forceMove(at(1, 1))
	ADD_TRAIT(runner, TRAIT_LIGHT_STEP, TRAIT_SOURCE_UNIT_TESTS)
	TEST_ASSERT_EQUAL(stealth_footstep_reach(runner), 3, "A light step doesn't carry 3")
	REMOVE_TRAIT(runner, TRAIT_LIGHT_STEP, TRAIT_SOURCE_UNIT_TESTS)
	ADD_TRAIT(runner, TRAIT_SILENT_FOOTSTEPS, TRAIT_SOURCE_UNIT_TESTS)
	TEST_ASSERT_EQUAL(stealth_footstep_reach(runner), 0, "Silent footsteps are heard")
	REMOVE_TRAIT(runner, TRAIT_SILENT_FOOTSTEPS, TRAIT_SOURCE_UNIT_TESTS)
	runner.set_body_position(LYING_DOWN)
	TEST_ASSERT_EQUAL(stealth_footstep_reach(runner), 2, "Crawling doesn't carry 2")
	runner.set_body_position(STANDING_UP)
	var/obj/structure/closet/locker = allocate(/obj/structure/closet, at(1, 1))
	runner.forceMove(locker)
	TEST_ASSERT_EQUAL(stealth_footstep_reach(runner), 0, "Someone in a locker makes footsteps")
	runner.forceMove(at(1, 1))
	// The real shoes.
	qdel(runner.shoes)
	runner.equip_to_slot_or_del(new /obj/item/clothing/shoes/laceup/winters_loafers(runner), ITEM_SLOT_FEET)
	TEST_ASSERT_NOTNULL(runner.shoes, "The loafers didn't go on")
	TEST_ASSERT_EQUAL(stealth_footstep_reach(runner), 0, "Running in Winter's loafers is heard")

/// One guard goes, then two, then everyone; somewhere else, one again. No sound gives anyone a target.
/datum/unit_test/voidcrew_stealth_live/hear/dispatch

/datum/unit_test/voidcrew_stealth_live/hear/dispatch/Run()
	TEST_ASSERT(hear_room(30, 3), "No room for the test")
	var/mob/living/carbon/human/npc/first = walker(5, 1)
	var/mob/living/carbon/human/npc/second = walker(7, 1)
	var/mob/living/carbon/human/npc/third = walker(9, 1)
	var/datum/ai_controller/basic_controller/human_npc/stealth/first_ai = first.ai_controller
	var/datum/ai_controller/basic_controller/human_npc/stealth/second_ai = second.ai_controller
	var/datum/ai_controller/basic_controller/human_npc/stealth/third_ai = third.ai_controller
	var/datum/stealth_group/group = first_ai.group
	TEST_ASSERT_EQUAL(group, marker.group, "The guards didn't join the marker's group")
	TEST_ASSERT_NOTNULL(third_ai.route_id, "A guard on a stop claimed no route")
	var/turf/spot = at(4, 1)
	TEST_ASSERT_EQUAL(stealth_noise(spot, "knock"), 3, "Three guards within 5 tiles didn't all hear a knock")
	TEST_ASSERT_EQUAL(first_ai.stealth_state(), "suspicious", "The nearest guard didn't go to look")
	TEST_ASSERT(first_ai.suspicion_heard, "A guard that heard something isn't marked as having heard it")
	TEST_ASSERT_EQUAL(first_ai.investigate_turf, spot, "It isn't going to where the noise was")
	TEST_ASSERT(!first_ai.blackboard["stealth_wary"], "A noise alone made a guard wary")
	TEST_ASSERT_EQUAL(second_ai.stealth_state(), "unaware", "A second guard went to the first noise")
	TEST_ASSERT(second_ai.glance_until > world.time && third_ai.glance_until > world.time, "The others didn't glance")
	TEST_ASSERT_EQUAL(second.dir, WEST, "A glancing guard didn't turn to the noise")
	// The same noise at once is the same noise.
	TEST_ASSERT_EQUAL(stealth_noise(spot, "knock"), 0, "The same noise in the same moment was heard twice")
	group.rewind(4 SECONDS)
	stealth_noise(spot, "knock")
	TEST_ASSERT_EQUAL(second_ai.stealth_state(), "suspicious", "Two guards didn't go to the second noise")
	TEST_ASSERT_EQUAL(third_ai.stealth_state(), "unaware", "Three guards went to the second noise")
	group.rewind(4 SECONDS)
	stealth_noise(spot, "knock")
	for(var/mob/living/guard as anything in list(first, second, third))
		TEST_ASSERT_EQUAL(state_of(guard), "searching", "Not every guard searched at the third noise")
	TEST_ASSERT(third_ai.blackboard["stealth_wary"], "A guard searching for a noise isn't wary")
	// Ten tiles off it is a new spot.
	for(var/mob/living/guard as anything in list(first, second, third))
		settle(guard)
	group.rewind(4 SECONDS)
	TEST_ASSERT_EQUAL(stealth_noise(at(15, 1), "glass"), 2, "A smash 6 and 8 tiles off wasn't heard by two")
	TEST_ASSERT_EQUAL(third_ai.stealth_state(), "suspicious", "Nobody went to a noise somewhere new")
	TEST_ASSERT_EQUAL(second_ai.stealth_state(), "unaware", "Two went to the first noise at a new spot")
	no_targets(list(first, second, third))

/// A sentry leaves its post only for a noise close by.
/datum/unit_test/voidcrew_stealth_live/hear/sentry_rule

/datum/unit_test/voidcrew_stealth_live/hear/sentry_rule/Run()
	TEST_ASSERT(hear_room(20, 3), "No room for the test")
	var/mob/living/carbon/human/npc/post_guard = sentry(6, 1)
	var/mob/living/carbon/human/npc/route_guard = walker(7, 1)
	var/datum/ai_controller/basic_controller/human_npc/stealth/post_ai = post_guard.ai_controller
	TEST_ASSERT_NULL(post_ai.route_id, "A guard with no stop near it claimed a route")
	TEST_ASSERT_EQUAL(stealth_noise(at(0, 1), "glass"), 2, "Both guards should hear a smash 6 and 7 tiles off")
	TEST_ASSERT_EQUAL(state_of(post_guard), "unaware", "A sentry left its post for a noise 6 tiles off")
	TEST_ASSERT(post_ai.glance_until > world.time, "The sentry didn't glance")
	TEST_ASSERT_EQUAL(state_of(route_guard), "suspicious", "The route guard didn't go in the sentry's place")
	settle(post_guard)
	settle(route_guard)
	post_ai.group.forget_noises()
	stealth_noise(at(3, 1), "glass")
	TEST_ASSERT_EQUAL(state_of(post_guard), "suspicious", "A sentry didn't look at a noise 3 tiles off")
	no_targets(list(post_guard, route_guard))

/// The guard who never came back is missed by the ones who watched it go, once it is overdue.
/datum/unit_test/voidcrew_stealth_live/hear/missing

/datum/unit_test/voidcrew_stealth_live/hear/missing/Run()
	TEST_ASSERT(hear_room(20, 3), "No room for the test")
	var/mob/living/carbon/human/npc/first = walker(5, 1)
	var/mob/living/carbon/human/npc/second = walker(7, 1)
	var/mob/living/carbon/human/npc/third = walker(9, 1)
	var/datum/ai_controller/basic_controller/human_npc/stealth/first_ai = first.ai_controller
	var/datum/stealth_group/group = first_ai.group
	var/turf/spot = at(4, 1)
	stealth_noise(spot, "knock")
	TEST_ASSERT_EQUAL(length(group.checks), 1, "No check was opened on the guard that went")
	first.death()
	group.check_overdue()
	TEST_ASSERT_EQUAL(state_of(second), "unaware", "A guard knew its friend was down before it was overdue")
	group.rewind(31 SECONDS)
	group.check_overdue()
	TEST_ASSERT_EQUAL(state_of(second), "searching", "Nobody came looking for the guard that never came back")
	TEST_ASSERT_EQUAL(state_of(third), "searching", "Only one guard came looking")
	TEST_ASSERT(group.lure_count(spot) >= 2, "The next noise at that spot won't bring everyone")
	TEST_ASSERT_EQUAL(length(group.checks), 0, "A failed check wasn't closed")
	// One that comes back closes its check.
	settle(second)
	settle(third)
	group.forget_noises()
	stealth_noise(spot, "knock")
	TEST_ASSERT_EQUAL(state_of(second), "suspicious", "The next guard didn't go to look")
	settle(second)
	group.rewind(31 SECONDS)
	group.check_overdue()
	TEST_ASSERT_EQUAL(state_of(third), "unaware", "A guard was missed after it came back")
	no_targets(list(second, third))

/// Gunfire: the nearest four that aren't sentries run to it, the rest hold, everyone is wary. After two alarms, two go.
/datum/unit_test/voidcrew_stealth_live/hear/alarm

/datum/unit_test/voidcrew_stealth_live/hear/alarm/Run()
	TEST_ASSERT(hear_room(30, 5), "No room for the test")
	// The sentries first: a guard made beside a stop would claim its route.
	var/list/sentries = list(sentry(4, 3), sentry(6, 3))
	var/list/route_guards = list()
	for(var/dx in 3 to 8)
		route_guards += walker(dx, 1)
	var/mob/living/any_guard = route_guards[1]
	var/datum/ai_controller/basic_controller/human_npc/stealth/any_ai = any_guard.ai_controller
	var/datum/stealth_group/group = any_ai.group
	var/turf/spot = at(1, 1)
	TEST_ASSERT_EQUAL(stealth_noise(spot, "gun_long"), 8, "Eight guards within 14 tiles didn't all hear a rifle")
	var/searching = 0
	for(var/mob/living/guard as anything in route_guards)
		var/datum/ai_controller/basic_controller/human_npc/stealth/guard_ai = guard.ai_controller
		TEST_ASSERT(guard_ai.blackboard["stealth_wary"], "A guard that heard gunfire isn't wary")
		if(guard_ai.stealth_state() == "searching")
			searching++
	TEST_ASSERT_EQUAL(searching, 4, "Not exactly four guards ran to the gunfire")
	TEST_ASSERT_EQUAL(state_of(route_guards[1]), "searching", "The nearest guard didn't go")
	TEST_ASSERT_EQUAL(state_of(route_guards[6]), "unaware", "The furthest guard didn't hold")
	for(var/mob/living/guard as anything in sentries)
		var/datum/ai_controller/basic_controller/human_npc/stealth/guard_ai = guard.ai_controller
		TEST_ASSERT_EQUAL(guard_ai.stealth_state(), "unaware", "A sentry left its post for gunfire")
		TEST_ASSERT(guard_ai.blackboard["stealth_wary"], "A sentry that heard gunfire isn't wary")
	// A second, then a third: by then they have learned it may be a draw.
	for(var/round_number in 2 to 3)
		for(var/mob/living/guard as anything in route_guards + sentries)
			settle(guard)
		group.rewind(4 SECONDS)
		stealth_noise(spot, "gun_long")
	searching = 0
	for(var/mob/living/guard as anything in route_guards)
		if(state_of(guard) == "searching")
			searching++
	TEST_ASSERT_EQUAL(searching, 2, "After two alarms in memory, not exactly two guards went to the third")
	no_targets(route_guards + sentries)

/// Their own side: a guard doesn't hear itself, a friend's gunfire is a call for help, their own door is nothing, a friend's fall is heard.
/datum/unit_test/voidcrew_stealth_live/hear/allies

/datum/unit_test/voidcrew_stealth_live/hear/allies/Run()
	TEST_ASSERT(hear_room(20, 3), "No room for the test")
	var/mob/living/carbon/human/npc/shooter = walker(3, 1)
	var/mob/living/carbon/human/npc/friend = walker(8, 1)
	var/datum/ai_controller/basic_controller/human_npc/stealth/friend_ai = friend.ai_controller
	TEST_ASSERT_EQUAL(stealth_noise(shooter, "voice", null, shooter), 0, "A guard's whistle was heard by its friend")
	TEST_ASSERT_EQUAL(stealth_noise(shooter, "gun_pistol", null, shooter), 1, "A guard's gunfire wasn't heard by its friend")
	TEST_ASSERT_EQUAL(state_of(shooter), "unaware", "A guard reacted to its own shot")
	TEST_ASSERT_EQUAL(friend_ai.stealth_state(), "searching", "A guard didn't run to a friend's gunfire")
	TEST_ASSERT_EQUAL(friend_ai.search_center, get_turf(shooter), "It isn't looking where its friend fired from")
	settle(friend)
	var/obj/machinery/door/airlock/door = allocate(/obj/machinery/door/airlock, at(9, 1))
	TEST_ASSERT_EQUAL(stealth_noise(door, "door"), 0, "A door with one of their own beside it was heard")
	door.forceMove(at(11, 1))
	TEST_ASSERT_EQUAL(stealth_noise(door, "door"), 1, "A door with nobody beside it wasn't heard")
	TEST_ASSERT(friend_ai.glance_until > world.time, "A guard didn't glance at a door")
	friend_ai.group.forget_noises()
	TEST_ASSERT_EQUAL(stealth_noise(at(6, 1), "thud", null, shooter), 1, "A friend's fall wasn't heard")
	TEST_ASSERT_EQUAL(friend_ai.stealth_state(), "suspicious", "A guard didn't look at a friend's fall")
	no_targets(list(shooter, friend))

/// The deaf hear nothing; with no player on the level nothing is heard at all; ten shots in a tick are one noise.
/datum/unit_test/voidcrew_stealth_live/hear/deaf_dormant

/datum/unit_test/voidcrew_stealth_live/hear/deaf_dormant/Run()
	TEST_ASSERT(hear_room(20, 3), "No room for the test")
	var/mob/living/carbon/human/npc/guard = walker(5, 1)
	var/datum/ai_controller/basic_controller/human_npc/stealth/guard_ai = guard.ai_controller
	var/datum/stealth_group/group = guard_ai.group
	var/turf/spot = at(3, 1)
	ADD_TRAIT(guard, TRAIT_DEAF, TRAIT_SOURCE_UNIT_TESTS)
	TEST_ASSERT_EQUAL(stealth_noise(spot, "gun_long"), 0, "A deaf guard heard a rifle")
	REMOVE_TRAIT(guard, TRAIT_DEAF, TRAIT_SOURCE_UNIT_TESTS)
	// Nobody on the level.
	var/list/were_listed = players.Copy()
	for(var/mob/living/person as anything in were_listed)
		SSmobs.clients_by_zlevel[were_listed[person]] -= person
	TEST_ASSERT_EQUAL(stealth_noise(spot, "gun_long"), 0, "A guard on an empty level heard a rifle")
	TEST_ASSERT_EQUAL(guard_ai.stealth_state(), "unaware", "A noise on an empty level changed a guard")
	for(var/mob/living/person as anything in were_listed)
		SSmobs.clients_by_zlevel[were_listed[person]] += person
	var/heard = 0
	for(var/shot in 1 to 10)
		heard += stealth_noise(at(3 + (shot % 3), 1), "gun_long")
	TEST_ASSERT_EQUAL(heard, 1, "Ten shots in one tick weren't one noise")
	TEST_ASSERT_EQUAL(length(group.alarms), 1, "Ten shots in one tick were more than one alarm")
	TEST_ASSERT_EQUAL(guard_ai.stealth_state(), "searching", "A guard didn't run to gunfire")
	no_targets(list(guard))

/// A guard that sees someone shouts; a friend in earshot runs to the shouter and doesn't shout on. A muted guard calls nobody.
/datum/unit_test/voidcrew_stealth_live/hear/shout

/datum/unit_test/voidcrew_stealth_live/hear/shout/Run()
	TEST_ASSERT(hear_room(24, 3), "No room for the test")
	var/mob/living/carbon/human/npc/spotter = walker(10, 1, EAST)
	var/mob/living/carbon/human/npc/friend = walker(4, 1, WEST)
	var/datum/ai_controller/basic_controller/human_npc/stealth/spotter_ai = spotter.ai_controller
	var/datum/ai_controller/basic_controller/human_npc/stealth/friend_ai = friend.ai_controller
	var/mob/living/carbon/human/intruder = person_at(12, 1, FALSE)
	ADD_TRAIT(spotter, TRAIT_MUTE, TRAIT_SOURCE_UNIT_TESTS)
	stealth_scans(spotter, 4)
	TEST_ASSERT_EQUAL(spotter_ai.stealth_state(), "alert", "A guard isn't alert on someone 2 tiles in front of it")
	TEST_ASSERT_EQUAL(friend_ai.stealth_state(), "unaware", "A muted guard called its friend")
	REMOVE_TRAIT(spotter, TRAIT_MUTE, TRAIT_SOURCE_UNIT_TESTS)
	settle(spotter)
	spotter.setDir(EAST)
	stealth_scans(spotter, 4)
	TEST_ASSERT_EQUAL(spotter_ai.stealth_state(), "alert", "A guard isn't alert on someone 2 tiles in front of it")
	TEST_ASSERT_EQUAL(friend_ai.stealth_state(), "searching", "A guard in earshot of a shout didn't come")
	TEST_ASSERT_EQUAL(friend_ai.search_center, get_turf(spotter), "It ran to the intruder, not to the friend who shouted")
	TEST_ASSERT(!friend_ai.blackboard_key_exists(BB_BASIC_MOB_CURRENT_TARGET), "A shout gave a guard a target")
	TEST_ASSERT(!friend_ai.next_shout, "A guard that came for a shout shouted on")
	TEST_ASSERT_EQUAL(spotter_ai.blackboard[BB_BASIC_MOB_CURRENT_TARGET], intruder, "The guard that saw them has no target")

/// A radio call takes three seconds, reaches the other lookout anywhere, and is stopped by a knockout, a jammer or an EMP.
/datum/unit_test/voidcrew_stealth_live/hear/radio

/datum/unit_test/voidcrew_stealth_live/hear/radio/Run()
	TEST_ASSERT(hear_room(40, 3), "No room for the test")
	var/mob/living/carbon/human/npc/speaker = walker(3, 1, WEST, STEALTH_HEAR_LOOKOUT)
	var/mob/living/carbon/human/npc/listener = walker(34, 1, EAST, STEALTH_HEAR_LOOKOUT)
	var/mob/living/carbon/human/npc/neighbour = walker(31, 1, WEST)
	var/datum/ai_controller/basic_controller/human_npc/stealth/speaker_ai = speaker.ai_controller
	var/datum/ai_controller/basic_controller/human_npc/stealth/listener_ai = listener.ai_controller
	var/datum/stealth_group/group = speaker_ai.group
	TEST_ASSERT_NOTNULL(speaker.stealth_radio_ready(), "A lookout has no working radio")
	TEST_ASSERT_NULL(neighbour.stealth_radio_ready(), "A plain guard has a radio")
	var/turf/spot = at(5, 1)
	// The call goes out after three seconds, not before.
	TEST_ASSERT(speaker_ai.stealth_start_call(3, spot), "A lookout couldn't start a call")
	stealth_scans(speaker, 1)
	TEST_ASSERT_EQUAL(listener_ai.stealth_state(), "unaware", "A radio call arrived at once")
	speaker_ai.stealth_rewind(3.1 SECONDS)
	stealth_scans(speaker, 1)
	TEST_ASSERT_NULL(speaker_ai.pending_call, "A call that was made is still pending")
	TEST_ASSERT_EQUAL(listener_ai.stealth_state(), "searching", "The other lookout didn't answer a radio alarm")
	TEST_ASSERT_EQUAL(state_of(neighbour), "searching", "The guard beside the lookout that answered didn't come")
	// Knocked out inside the three seconds.
	for(var/mob/living/guard as anything in list(speaker, listener, neighbour))
		settle(guard)
	group.forget_noises()
	speaker_ai.stealth_start_call(3, spot)
	speaker.Unconscious(4 SECONDS)
	TEST_ASSERT_NULL(speaker_ai.pending_call, "A knocked-out guard kept its call")
	speaker.SetUnconscious(0)
	speaker.update_stat()
	settle(speaker)
	TEST_ASSERT_EQUAL(listener_ai.stealth_state(), "unaware", "A call from a knocked-out guard arrived")
	// A jammer beside the speaker.
	var/obj/item/jammer/jammer = allocate(/obj/item/jammer, get_turf(speaker))
	GLOB.active_jammers |= jammer
	TEST_ASSERT_NULL(speaker.stealth_radio_ready(), "A jammed lookout's radio works")
	speaker_ai.stealth_start_call(3, spot)
	speaker_ai.stealth_rewind(3.1 SECONDS)
	stealth_scans(speaker, 1)
	GLOB.active_jammers -= jammer
	TEST_ASSERT_EQUAL(listener_ai.stealth_state(), "unaware", "A jammed call arrived")
	TEST_ASSERT(speaker_ai.bark_ready_at["stealth_radio_dead"], "A lookout with a dead radio didn't say so")
	// The receiver's earpiece hit by an EMP.
	settle(speaker)
	var/obj/item/radio/earpiece = listener.ears
	earpiece.emp_act(EMP_HEAVY)
	TEST_ASSERT_NULL(listener.stealth_radio_ready(), "An EMPed earpiece still works")
	speaker_ai.stealth_start_call(3, spot)
	speaker_ai.stealth_rewind(3.1 SECONDS)
	stealth_scans(speaker, 1)
	TEST_ASSERT_EQUAL(listener_ai.stealth_state(), "unaware", "A lookout with a dead earpiece got the call")
	TEST_ASSERT_EQUAL(state_of(neighbour), "unaware", "The call reached a guard with no radio")
	no_targets(list(speaker, listener, neighbour))

/// A lone lookout that reports in is missed by the other lookout; a guard with no radio that goes alone is missed by nobody.
/datum/unit_test/voidcrew_stealth_live/hear/report

/datum/unit_test/voidcrew_stealth_live/hear/report/Run()
	TEST_ASSERT(hear_room(40, 3), "No room for the test")
	var/mob/living/carbon/human/npc/scout = walker(3, 1, WEST, STEALTH_HEAR_LOOKOUT)
	var/mob/living/carbon/human/npc/listener = walker(34, 1, EAST, STEALTH_HEAR_LOOKOUT)
	var/mob/living/carbon/human/npc/loner = walker(18, 1, WEST)
	var/datum/ai_controller/basic_controller/human_npc/stealth/scout_ai = scout.ai_controller
	var/datum/stealth_group/group = scout_ai.group
	TEST_ASSERT_EQUAL(stealth_noise(at(5, 1), "knock"), 1, "Only the lookout should hear this knock")
	TEST_ASSERT_NOTNULL(scout_ai.pending_call, "A lookout sent to look didn't reach for its radio")
	scout_ai.stealth_rewind(3.1 SECONDS)
	stealth_scans(scout, 1)
	TEST_ASSERT_EQUAL(state_of(listener), "unaware", "A report moved someone")
	scout.death()
	group.rewind(31 SECONDS)
	group.check_overdue()
	TEST_ASSERT_EQUAL(state_of(listener), "searching", "A lookout that reported and never came back wasn't missed")
	// No radio, nobody else in earshot: nobody knows it went.
	settle(listener)
	group.forget_noises()
	TEST_ASSERT_EQUAL(stealth_noise(at(20, 1), "knock"), 1, "Only the plain guard should hear this knock")
	TEST_ASSERT_EQUAL(state_of(loner), "suspicious", "The plain guard didn't go to look")
	loner.death()
	group.rewind(31 SECONDS)
	group.check_overdue()
	TEST_ASSERT_EQUAL(state_of(listener), "unaware", "A guard nobody saw leave was missed")

/// The grey "?" of a heard noise: for players near with no fill of their own, never for a glance, gone when it gives up.
/datum/unit_test/voidcrew_stealth_live/hear/mark

/datum/unit_test/voidcrew_stealth_live/hear/mark/Run()
	TEST_ASSERT(hear_room(20, 3), "No room for the test")
	var/mob/living/carbon/human/npc/first = walker(8, 1)
	var/mob/living/carbon/human/npc/second = walker(10, 1)
	var/datum/ai_controller/basic_controller/human_npc/stealth/first_ai = first.ai_controller
	var/datum/ai_controller/basic_controller/human_npc/stealth/second_ai = second.ai_controller
	var/mob/living/carbon/human/watcher = person_at(4, 1)
	stealth_noise(at(7, 1), "knock")
	TEST_ASSERT(first_ai.suspicion_heard, "The guard that went isn't marked as having heard")
	TEST_ASSERT(stealth_meter_heard(first_ai.stealth_state(), first_ai.suspicion_heard), "A heard suspicion shows no mark")
	TEST_ASSERT_NOTNULL(first_ai.meter, "No mark was built for a heard suspicion with nobody noticed")
	TEST_ASSERT(watcher in first_ai.meter.heard_viewers(first_ai.notice_map), "A player near the guard doesn't get the heard mark")
	first_ai.notice_map[REF(watcher)] = list(0.5, get_turf(watcher), world.time)
	TEST_ASSERT(!(watcher in first_ai.meter.heard_viewers(first_ai.notice_map)), "A player with their own fill gets the heard mark too")
	TEST_ASSERT(!second_ai.suspicion_heard, "A glance shows the heard mark")
	first_ai.stealth_go_unaware()
	TEST_ASSERT(!first_ai.suspicion_heard, "The heard mark outlived the suspicion")
	TEST_ASSERT(!stealth_meter_heard(first_ai.stealth_state(), first_ai.suspicion_heard), "An unaware guard shows the heard mark")

/// Deleting a guard with a call pending and a check open, then its group: nothing left behind.
/datum/unit_test/voidcrew_stealth_live/hear/cleanup

/datum/unit_test/voidcrew_stealth_live/hear/cleanup/Run()
	TEST_ASSERT(hear_room(20, 3), "No room for the test")
	stop_at(5, 1, 1, 10 MINUTES)
	stop_at(7, 1, 2, 10 MINUTES)
	var/mob/living/carbon/human/npc/scout = new STEALTH_HEAR_LOOKOUT(at(5, 1))
	var/mob/living/carbon/human/npc/friend = new STEALTH_HEAR_GUARD(at(7, 1))
	var/datum/ai_controller/basic_controller/human_npc/stealth/scout_ai = wake(scout)
	var/datum/ai_controller/basic_controller/human_npc/stealth/friend_ai = wake(friend)
	scout_ai.stealth_setup()
	friend_ai.stealth_setup()
	var/datum/stealth_group/group = scout_ai.group
	stealth_noise(at(4, 1), "knock")
	TEST_ASSERT_NOTNULL(scout_ai.pending_call, "The lookout has no call pending")
	TEST_ASSERT_EQUAL(length(group.checks), 1, "No check is open")
	qdel(scout)
	group.rewind(31 SECONDS)
	group.check_overdue()
	TEST_ASSERT_EQUAL(friend_ai.stealth_state(), "searching", "A deleted investigator wasn't missed")
	qdel(friend)
	QDEL_NULL(marker)
	TEST_ASSERT(!(group in GLOB.stealth_groups), "A group with no marker and no guards is still registered")
	TEST_ASSERT(QDELETED(group), "The group wasn't deleted")
	// The explosion listener went with it.
	SEND_GLOBAL_SIGNAL(COMSIG_GLOB_EXPLOSION, at(4, 1), 0, 0, 1)

// ===== Through the real tg action =====

/// A real pistol shot sends a guard running; suppressed, it is unheard at 6 tiles and a curiosity at 3.
/datum/unit_test/voidcrew_stealth_live/hear/real_gunshot

/datum/unit_test/voidcrew_stealth_live/hear/real_gunshot/Run()
	TEST_ASSERT(hear_room(30, 3), "No room for the test")
	var/mob/living/carbon/human/npc/guard = walker(3, 1, WEST)
	var/datum/ai_controller/basic_controller/human_npc/stealth/guard_ai = guard.ai_controller
	var/mob/living/carbon/human/shooter = person_at(10, 1, FALSE)
	var/obj/item/gun/ballistic/automatic/pistol/pistol = allocate(/obj/item/gun/ballistic/automatic/pistol, get_turf(shooter))
	shooter.put_in_active_hand(pistol)
	var/turf/far_wall = at(25, 1)
	TEST_ASSERT(pistol.process_fire(far_wall, shooter), "The pistol didn't fire")
	TEST_ASSERT_EQUAL(guard_ai.stealth_state(), "searching", "A guard 7 tiles behind a pistol shot didn't run to it")
	TEST_ASSERT(get_dist(guard_ai.search_center, shooter) <= 1, "It isn't searching where the shot came from")
	TEST_ASSERT(!guard_ai.blackboard_key_exists(BB_BASIC_MOB_CURRENT_TARGET), "A gunshot gave a guard a target")
	// Suppressed, 6 tiles: nothing.
	settle(guard)
	guard_ai.group.forget_noises()
	pistol.install_suppressor(new /obj/item/suppressor(pistol))
	shooter.forceMove(at(9, 1))
	// No time passes in this test: the gun's own delay between shots is cleared by hand.
	pistol.reset_fire_cd()
	TEST_ASSERT(pistol.process_fire(far_wall, shooter), "The suppressed pistol didn't fire")
	TEST_ASSERT_EQUAL(guard_ai.stealth_state(), "unaware", "A guard heard a suppressed shot 6 tiles off")
	// 3 tiles, in the open: it turns to look.
	guard_ai.group.forget_noises()
	shooter.forceMove(at(6, 1))
	pistol.reset_fire_cd()
	TEST_ASSERT(pistol.process_fire(far_wall, shooter), "The suppressed pistol didn't fire again")
	TEST_ASSERT_EQUAL(guard_ai.stealth_state(), "suspicious", "A guard 3 tiles from a suppressed shot didn't look")
	TEST_ASSERT(guard_ai.suspicion_heard, "It isn't marked as having heard it")
	TEST_ASSERT(!guard_ai.blackboard["stealth_wary"], "A suppressed shot made a guard wary")

/// A real throw: the guard looks where the thing landed. A bottle smashes and carries further.
/datum/unit_test/voidcrew_stealth_live/hear/real_throw

/datum/unit_test/voidcrew_stealth_live/hear/real_throw/Run()
	TEST_ASSERT(hear_room(30, 7), "No room for the test")
	ground()
	var/mob/living/carbon/human/npc/guard = sentry(9, 5, EAST)
	var/datum/ai_controller/basic_controller/human_npc/stealth/guard_ai = guard.ai_controller
	var/mob/living/carbon/human/thrower = person_at(0, 2, FALSE)
	var/obj/item/coin/iron/coin = allocate(/obj/item/coin/iron, get_turf(thrower))
	var/turf/landing = at(9, 2)
	coin.throw_at(landing, 12, 2, thrower)
	var/deadline = world.time + 10 SECONDS
	while((coin.throwing || guard_ai.stealth_state() == "unaware") && world.time < deadline)
		sleep(1)
	TEST_ASSERT_EQUAL(guard_ai.stealth_state(), "suspicious", "A guard 3 tiles from a thrown coin's landing didn't look (it landed [get_dist(coin, guard)] tiles off)")
	TEST_ASSERT(get_dist(guard_ai.investigate_turf, get_turf(coin)) <= 1, "It isn't looking where the coin landed")
	TEST_ASSERT_EQUAL(guard_ai.last_heard[1], "thrown", "It heard something other than a landing")
	// A bottle, 7 tiles from the guard: only breaking glass carries that far.
	settle(guard)
	guard_ai.group.forget_noises()
	// On a route now: a sentry wouldn't leave its post for something this far off.
	guard.forceMove(at(16, 2))
	stop_at(16, 2, 1, 10 MINUTES)
	stealth_assign_points()
	guard_ai.route_id = "a"
	guard_ai.route_index = 1
	guard_ai.home_turf = at(16, 2)
	guard.setDir(EAST)
	var/obj/item/reagent_containers/cup/glass/bottle/beer/bottle = allocate(/obj/item/reagent_containers/cup/glass/bottle/beer, get_turf(thrower))
	TEST_ASSERT_EQUAL(bottle.stealth_throw_kind(), "glass", "A glass bottle doesn't smash as glass")
	bottle.throw_at(landing, 12, 2, thrower)
	deadline = world.time + 10 SECONDS
	while(guard_ai.stealth_state() == "unaware" && world.time < deadline)
		sleep(1)
	TEST_ASSERT_EQUAL(guard_ai.stealth_state(), "suspicious", "A guard 7 tiles from a smashed bottle didn't look")
	TEST_ASSERT_EQUAL(guard_ai.last_heard[1], "glass", "It heard something other than breaking glass")

/// Knocking on a wall or a window, and a door that refuses: the guard on the far side looks at its own side of it.
/datum/unit_test/voidcrew_stealth_live/hear/real_knock

/datum/unit_test/voidcrew_stealth_live/hear/real_knock/Run()
	TEST_ASSERT(hear_room(20, 5), "No room for the test")
	for(var/dy in 0 to 4)
		var/turf/wall_spot = at(10, dy)
		wall_spot.ChangeTurf(/turf/closed/wall)
	var/mob/living/carbon/human/npc/guard = sentry(13, 2, EAST)
	var/datum/ai_controller/basic_controller/human_npc/stealth/guard_ai = guard.ai_controller
	var/mob/living/carbon/human/knocker = person_at(9, 2, FALSE)
	var/turf/closed/wall/wall = at(10, 2)
	wall.attack_hand(knocker, list())
	TEST_ASSERT_EQUAL(guard_ai.stealth_state(), "suspicious", "A guard 3 tiles behind a wall didn't hear a push on it")
	TEST_ASSERT_EQUAL(guard_ai.investigate_turf, at(11, 2), "It isn't going to its own side of the wall")
	// A window in the wall.
	settle(guard)
	guard_ai.group.forget_noises()
	var/turf/pane_spot = at(10, 3)
	pane_spot.ChangeTurf(/turf/open/floor/iron)
	var/obj/structure/window/reinforced/fulltile/pane = allocate(/obj/structure/window/reinforced/fulltile, pane_spot)
	knocker.forceMove(at(9, 3))
	knocker.set_combat_mode(FALSE)
	pane.attack_hand(knocker, list())
	TEST_ASSERT_EQUAL(guard_ai.stealth_state(), "suspicious", "A guard didn't hear a knock on a window")
	TEST_ASSERT_EQUAL(guard_ai.last_heard[1], "knock", "A knock with combat mode off wasn't a knock")
	TEST_ASSERT_EQUAL(guard_ai.investigate_turf?.x, pane_spot.x + 1, "It isn't going to its own side of the window")
	// A door that refuses.
	settle(guard)
	guard_ai.group.forget_noises()
	var/turf/door_spot = at(10, 1)
	door_spot.ChangeTurf(/turf/open/floor/iron)
	var/obj/machinery/door/airlock/door = allocate(/obj/machinery/door/airlock, door_spot)
	door.animation_effects(DOOR_DENY_ANIMATION)
	TEST_ASSERT_EQUAL(guard_ai.stealth_state(), "suspicious", "A guard didn't hear a door refuse someone")
	TEST_ASSERT_EQUAL(guard_ai.investigate_turf?.x, door_spot.x + 1, "It isn't going to its own side of the door")

/// A body that drops is heard; one held when it drops is lowered without a sound. A whistle is heard; a nod is not.
/datum/unit_test/voidcrew_stealth_live/hear/real_fall_emote

/datum/unit_test/voidcrew_stealth_live/hear/real_fall_emote/Run()
	TEST_ASSERT(hear_room(20, 5), "No room for the test")
	var/mob/living/carbon/human/npc/guard = sentry(10, 2, EAST)
	var/datum/ai_controller/basic_controller/human_npc/stealth/guard_ai = guard.ai_controller
	var/mob/living/carbon/human/holder = person_at(6, 2, FALSE)
	var/mob/living/carbon/human/held = person_at(7, 2, FALSE)
	ground()
	holder.start_pulling(held)
	holder.setGrabState(GRAB_AGGRESSIVE)
	TEST_ASSERT_EQUAL(held.pulledby, holder, "The grab didn't take")
	held.Knockdown(10 SECONDS)
	TEST_ASSERT_EQUAL(held.body_position, LYING_DOWN, "The held one didn't go down")
	TEST_ASSERT_EQUAL(guard_ai.stealth_state(), "unaware", "A body lowered by whoever held it was heard")
	var/mob/living/carbon/human/dropped = person_at(7, 3, FALSE)
	dropped.Knockdown(10 SECONDS)
	TEST_ASSERT_EQUAL(guard_ai.stealth_state(), "suspicious", "A body dropping 3 tiles behind a guard wasn't heard")
	TEST_ASSERT_EQUAL(guard_ai.last_heard[1], "thud", "It heard something other than a thud")
	// Emotes.
	settle(guard)
	guard_ai.group.forget_noises()
	guard.setDir(EAST)
	var/mob/living/carbon/human/whistler = person_at(6, 4, FALSE)
	whistler.emote("nod")
	TEST_ASSERT_EQUAL(guard_ai.stealth_state(), "unaware", "A silent emote was heard")
	whistler.emote("whistle")
	TEST_ASSERT_EQUAL(guard_ai.stealth_state(), "suspicious", "A whistle 4 tiles off wasn't heard")
	TEST_ASSERT_EQUAL(guard_ai.last_heard[1], "voice", "It heard something other than a voice")

/// A real explosion 12 tiles off, the other side of a wall: the guard runs to it.
/datum/unit_test/voidcrew_stealth_live/hear/real_blast

/datum/unit_test/voidcrew_stealth_live/hear/real_blast/Run()
	TEST_ASSERT(hear_room(30, 5), "No room for the test")
	for(var/dy in 0 to 4)
		var/turf/wall_spot = at(10, dy)
		wall_spot.ChangeTurf(/turf/closed/wall)
	var/mob/living/carbon/human/npc/guard = walker(16, 2, EAST)
	var/datum/ai_controller/basic_controller/human_npc/stealth/guard_ai = guard.ai_controller
	explosion(at(4, 2), devastation_range = 0, heavy_impact_range = 0, light_impact_range = 1)
	var/deadline = world.time + 10 SECONDS
	while(guard_ai.stealth_state() != "searching" && world.time < deadline)
		sleep(1)
	TEST_ASSERT_EQUAL(guard_ai.stealth_state(), "searching", "A guard 12 tiles from a blast behind a wall didn't run to it")
	TEST_ASSERT_EQUAL(guard_ai.last_heard[1], "blast", "It heard something other than a blast")
	TEST_ASSERT(!guard_ai.blackboard_key_exists(BB_BASIC_MOB_CURRENT_TARGET), "A blast gave a guard a target")

// ===== With the real AI running =====

/// A bottle thrown off a guard's route: it walks over, finds nothing, and goes back to its round.
/datum/unit_test/voidcrew_stealth_live/hear/live_lure

/datum/unit_test/voidcrew_stealth_live/hear/live_lure/Run()
	TEST_ASSERT(make_room(34, 9), "No room for the test")
	marker = allocate(/obj/effect/landmark/stealth_group, at(0, 8))
	// The player who keeps the level awake, walled off at the far end.
	for(var/dy in 0 to 8)
		var/turf/wall_spot = at(24, dy)
		wall_spot.ChangeTurf(/turf/closed/wall)
	person_at(30, 2)
	// A wall hides the thrower from the route; the top two rows are open to throw along.
	for(var/dy in 0 to 6)
		var/turf/wall_spot = at(11, dy)
		wall_spot.ChangeTurf(/turf/closed/wall)
	ground()
	stop_at(2, 2, 1)
	stop_at(8, 2, 2)
	var/mob/living/carbon/human/npc/guard = guard_at(2, 2)
	var/datum/ai_controller/basic_controller/human_npc/stealth/guard_ai = wake(guard)
	var/mob/living/carbon/human/thrower = person_at(16, 7, FALSE)
	sleep(3 SECONDS)
	TEST_ASSERT_EQUAL(guard_ai.route_id, "a", "The guard never claimed its route")
	TEST_ASSERT_EQUAL(guard_ai.stealth_state(), "unaware", "A patrolling guard with nobody in sight isn't unaware")
	var/turf/landing = at(5, 7)
	var/obj/item/reagent_containers/cup/glass/bottle/beer/bottle = allocate(/obj/item/reagent_containers/cup/glass/bottle/beer, get_turf(thrower))
	bottle.throw_at(landing, 14, 2, thrower)
	var/start_time = world.time
	var/found = FALSE
	var/nearest = INFINITY
	var/deadline = world.time + 25 SECONDS
	while(world.time < deadline)
		nearest = min(nearest, get_dist(guard, landing))
		if(nearest <= 1)
			found = TRUE
			break
		sleep(2)
	TEST_ASSERT(found, "The guard never walked to the smashed bottle: it got within [nearest] tiles, state [guard_ai.stealth_state()], heard [guard_ai.last_heard ? guard_ai.last_heard[1] : "nothing"]")
	var/back = FALSE
	deadline = start_time + 60 SECONDS
	while(world.time < deadline)
		if(guard_ai.stealth_state() == "unaware" && (get_dist(guard, at(2, 2)) <= 1 || get_dist(guard, at(8, 2)) <= 1))
			back = TRUE
			break
		sleep(2)
	TEST_ASSERT(back, "The guard didn't go back to its round: state [guard_ai.stealth_state()], [get_dist(guard, at(2, 2))] and [get_dist(guard, at(8, 2))] tiles from its stops")
	TEST_ASSERT(!guard_ai.blackboard_key_exists(BB_BASIC_MOB_CURRENT_TARGET), "A smashed bottle gave a guard a target")

/// Someone walking up behind a guard is not heard; the same person running makes it turn.
/datum/unit_test/voidcrew_stealth_live/hear/live_footsteps

/datum/unit_test/voidcrew_stealth_live/hear/live_footsteps/Run()
	TEST_ASSERT(make_room(20, 3), "No room for the test")
	// The player first: a guard woken on an empty level stays asleep.
	var/mob/living/carbon/human/runner = person_at(5, 1)
	var/mob/living/carbon/human/npc/guard = guard_at(10, 1, EAST)
	var/datum/ai_controller/basic_controller/human_npc/stealth/guard_ai = wake(guard)
	sleep(2 SECONDS)
	TEST_ASSERT_EQUAL(guard_ai.stealth_state(), "unaware", "A guard noticed someone standing 5 tiles behind it")
	// Walking, to one tile behind it.
	for(var/step_number in 1 to 4)
		runner.Move(get_step(runner, EAST), EAST)
		sleep(3)
	TEST_ASSERT_EQUAL(get_dist(runner, guard), 1, "The walker didn't get behind the guard")
	TEST_ASSERT_EQUAL(guard_ai.stealth_state(), "unaware", "A guard heard someone walk up behind it")
	// Back, and now running.
	runner.forceMove(at(5, 1))
	guard_ai.stealth_go_unaware()
	guard_ai.stealth_clear_wary()
	guard.setDir(EAST)
	sleep(2 SECONDS)
	TEST_ASSERT_EQUAL(guard_ai.stealth_state(), "unaware", "The guard didn't settle")
	runner.toggle_move_intent()
	TEST_ASSERT_EQUAL(runner.move_intent, MOVE_INTENT_RUN, "The runner isn't running")
	var/heard = FALSE
	for(var/step_number in 1 to 3)
		runner.Move(get_step(runner, EAST), EAST)
		for(var/tick in 1 to 6)
			if(guard_ai.stealth_state() != "unaware")
				heard = TRUE
				break
			sleep(1)
		if(heard)
			break
	var/deadline = world.time + 3 SECONDS
	while(!heard && world.time < deadline)
		heard = guard_ai.stealth_state() != "unaware"
		sleep(1)
	TEST_ASSERT(heard, "A guard never heard someone run up behind it (they are [get_dist(runner, guard)] tiles off)")
	TEST_ASSERT(get_dist(runner, guard) >= 2, "The runner was next to the guard before it turned")
	TEST_ASSERT_EQUAL(guard.dir, WEST, "The guard didn't turn to the footsteps")
	TEST_ASSERT(guard_ai.last_heard?[1] == "footsteps", "It turned for something other than footsteps")

/// A lookout that sees someone reaches for its radio; stunned before the call goes out, the other lookout never hears of it.
/datum/unit_test/voidcrew_stealth_live/hear/live_call

/datum/unit_test/voidcrew_stealth_live/hear/live_call/Run()
	TEST_ASSERT(make_room(40, 3), "No room for the test")
	marker = allocate(/obj/effect/landmark/stealth_group, at(0, 2))
	var/mob/living/carbon/human/npc/scout = allocate(STEALTH_HEAR_LOOKOUT, at(4, 1))
	scout.setDir(EAST)
	scout.AddElement(/datum/element/forced_gravity, 1)
	var/mob/living/carbon/human/npc/listener = allocate(STEALTH_HEAR_LOOKOUT, at(36, 1))
	listener.setDir(EAST)
	listener.AddElement(/datum/element/forced_gravity, 1)
	person_at(6, 1)
	var/datum/ai_controller/basic_controller/human_npc/stealth/scout_ai = wake(scout)
	var/datum/ai_controller/basic_controller/human_npc/stealth/listener_ai = wake(listener)
	var/deadline = world.time + 15 SECONDS
	while(isnull(scout_ai.pending_call) && world.time < deadline)
		sleep(1)
	TEST_ASSERT_EQUAL(scout_ai.stealth_state(), "alert", "A lookout isn't alert on someone 2 tiles in front of it")
	TEST_ASSERT_NOTNULL(scout_ai.pending_call, "A lookout that saw someone didn't reach for its radio")
	scout.Stun(8 SECONDS)
	TEST_ASSERT_NULL(scout_ai.pending_call, "A stunned lookout kept its call")
	var/found = FALSE
	deadline = world.time + 6 SECONDS
	while(world.time < deadline)
		if(listener_ai.stealth_state() != "unaware")
			found = TRUE
		sleep(2)
	TEST_ASSERT(!found, "The other lookout heard of a call that was never made")

#undef STEALTH_HEAR_GUARD
#undef STEALTH_HEAR_LOOKOUT
