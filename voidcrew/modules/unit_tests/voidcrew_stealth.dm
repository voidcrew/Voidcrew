// Stealth guards (voidcrew/modules/stealth/). Unit tests compile before voidcrew/_DEFINES, so values from
// there are written out: states "unaware", "suspicious", "alert", "searching"; blackboard keys
// "stealth_state", "stealth_wary"; STEALTH_PATROL_MAX_FAILS 3, STEALTH_LOSE_TARGET_TIME 4 s,
// STEALTH_SEARCH_TIME 40 s, STEALTH_CALM_LOOK_TIME 6 s, STEALTH_WARY_TIME 60 s, STEALTH_SWITCH_COOLDOWN 4 s.
//
// The tests down to voidcrew_stealth_body_again call the scan and the state procs directly, with the AI off. The
// voidcrew_stealth_live tests at the bottom run the real AI: planning, the scan and real walking.

#define STEALTH_TEST_GUARD /mob/living/carbon/human/npc/ruin/trooper/scav

/// A floored block of `width` x `height` tiles for one test. Released by the caller.
/datum/unit_test/proc/stealth_block(width, height)
	var/datum/turf_reservation/block = SSmapping.request_turf_block_reservation(width, height, 1)
	if(isnull(block))
		return null
	var/turf/corner = block.bottom_left_turfs[1]
	for(var/turf/spot as anything in block(corner.x, corner.y, corner.z, corner.x + width - 1, corner.y + height - 1, corner.z))
		spot.ChangeTurf(/turf/open/floor/iron)
		GLOB.stealth_test_dark_turfs[spot] = FALSE
	return block

/datum/unit_test/proc/stealth_at(datum/turf_reservation/block, dx, dy)
	var/turf/corner = block.bottom_left_turfs[1]
	return locate(corner.x + dx, corner.y + dy, corner.z)

/// A guard at (dx, dy) of `block`, facing `facing`.
/datum/unit_test/proc/stealth_guard(datum/turf_reservation/block, dx, dy, facing = EAST)
	var/mob/living/carbon/human/npc/guard = allocate(STEALTH_TEST_GUARD, stealth_at(block, dx, dy))
	guard.setDir(facing)
	return guard

/// A walking, ordinary person at (dx, dy) of `block`.
/datum/unit_test/proc/stealth_person(datum/turf_reservation/block, dx, dy)
	var/mob/living/carbon/human/consistent/person = allocate(/mob/living/carbon/human/consistent, stealth_at(block, dx, dy))
	if(person.move_intent == MOVE_INTENT_RUN)
		person.toggle_move_intent()
	return person

/datum/unit_test/proc/stealth_ai(mob/living/guard)
	return guard.ai_controller

/datum/unit_test/proc/stealth_scans(mob/living/guard, count)
	var/datum/ai_controller/basic_controller/human_npc/stealth/stealth_ai = guard.ai_controller
	for(var/i in 1 to count)
		stealth_ai.stealth_scan_once()

/// Cone math against a guard facing east.
/datum/unit_test/voidcrew_stealth_cone

/datum/unit_test/voidcrew_stealth_cone/Run()
	var/datum/turf_reservation/block = stealth_block(9, 9)
	TEST_ASSERT_NOTNULL(block, "No room for the test")
	var/obj/item/viewer = allocate(/obj/item/pen, stealth_at(block, 4, 4))
	viewer.setDir(EAST)
	// offset => expected at 60, 75, 90
	var/list/cases = list(
		list(3, 0, TRUE, TRUE, TRUE),
		list(3, 2, TRUE, TRUE, TRUE),
		list(2, 3, TRUE, TRUE, TRUE),
		list(1, 3, FALSE, TRUE, TRUE),
		list(0, 3, FALSE, FALSE, FALSE),
		list(-2, 0, FALSE, FALSE, FALSE),
		list(0, 0, TRUE, TRUE, TRUE),
	)
	var/list/angles = list(60, 75, 90)
	for(var/list/test_case as anything in cases)
		var/turf/spot = stealth_at(block, 4 + test_case[1], 4 + test_case[2])
		for(var/i in 1 to 3)
			TEST_ASSERT_EQUAL(!!stealth_in_cone(viewer, spot, angles[i]), test_case[2 + i], "Offset ([test_case[1]], [test_case[2]]) at half-angle [angles[i]]")
	qdel(block)

/// The dark helper reads the test lists: a dark-listed turf is dark, a lit-listed one is not.
/datum/unit_test/voidcrew_stealth_dark

/datum/unit_test/voidcrew_stealth_dark/Run()
	var/datum/turf_reservation/block = stealth_block(3, 3)
	TEST_ASSERT_NOTNULL(block, "No room for the test")
	var/turf/lit = stealth_at(block, 0, 0)
	var/turf/dark = stealth_at(block, 1, 0)
	GLOB.stealth_test_dark_turfs[dark] = TRUE
	TEST_ASSERT(!stealth_tile_is_dark(lit), "A lit test turf reads as dark")
	TEST_ASSERT(stealth_tile_is_dark(dark), "A turf in the test dark list reads as lit")
	GLOB.stealth_test_dark_turfs[dark] = FALSE
	qdel(block)

/// Sight: behind stays unaware, in front goes suspicious then alert, dark at range and off-screen never alert.
/datum/unit_test/voidcrew_stealth_sight

/datum/unit_test/voidcrew_stealth_sight/Run()
	var/datum/turf_reservation/block = stealth_block(20, 5)
	TEST_ASSERT_NOTNULL(block, "No room for the test")
	// Behind, 3 tiles, lit, still.
	var/mob/living/carbon/human/npc/guard = stealth_guard(block, 6, 2)
	var/datum/ai_controller/basic_controller/human_npc/stealth/stealth_ai = stealth_ai(guard)
	var/mob/living/carbon/human/person = stealth_person(block, 3, 2)
	stealth_scans(guard, 10)
	TEST_ASSERT_EQUAL(stealth_ai.stealth_state(), "unaware", "A guard noticed someone standing 3 tiles behind it")
	qdel(guard)
	// In front, 2 tiles, lit: an alert on the first look (decision 32).
	guard = stealth_guard(block, 6, 2)
	stealth_ai = stealth_ai(guard)
	person.forceMove(stealth_at(block, 8, 2))
	stealth_scans(guard, 1)
	TEST_ASSERT_EQUAL(stealth_ai.stealth_state(), "alert", "A guard wasn't alert on someone 2 tiles in front after one scan")
	TEST_ASSERT_EQUAL(stealth_ai.blackboard[BB_BASIC_MOB_CURRENT_TARGET], person, "The alert guard has no target")
	qdel(guard)
	// In front, 6 tiles, dark.
	guard = stealth_guard(block, 6, 2)
	stealth_ai = stealth_ai(guard)
	var/turf/dark = stealth_at(block, 12, 2)
	GLOB.stealth_test_dark_turfs[dark] = TRUE
	person.forceMove(dark)
	stealth_scans(guard, 10)
	GLOB.stealth_test_dark_turfs[dark] = FALSE
	TEST_ASSERT_EQUAL(stealth_ai.stealth_state(), "unaware", "A guard saw someone 6 tiles off in the dark")
	qdel(guard)
	// In front, 8 tiles, lit: never alert from off-screen.
	guard = stealth_guard(block, 6, 2)
	stealth_ai = stealth_ai(guard)
	person.forceMove(stealth_at(block, 14, 2))
	for(var/i in 1 to 30)
		stealth_ai.stealth_scan_once()
		TEST_ASSERT(stealth_ai.stealth_state() != "alert", "A guard went alert on someone 8 tiles off")
	TEST_ASSERT_EQUAL(stealth_ai.stealth_state(), "suspicious", "A guard never grew suspicious of someone 8 tiles in front in the light")
	qdel(guard)
	qdel(block)

/// Alert: keeps its target all round; loses it behind a wall and searches where it last saw it.
/datum/unit_test/voidcrew_stealth_alert

/datum/unit_test/voidcrew_stealth_alert/Run()
	var/datum/turf_reservation/block = stealth_block(16, 5)
	TEST_ASSERT_NOTNULL(block, "No room for the test")
	var/mob/living/carbon/human/npc/guard = stealth_guard(block, 6, 2)
	var/datum/ai_controller/basic_controller/human_npc/stealth/stealth_ai = stealth_ai(guard)
	var/mob/living/carbon/human/person = stealth_person(block, 9, 2)
	stealth_ai.stealth_go_alert(person)
	person.forceMove(stealth_at(block, 3, 2))
	stealth_scans(guard, 5)
	TEST_ASSERT_EQUAL(stealth_ai.blackboard[BB_BASIC_MOB_CURRENT_TARGET], person, "An alert guard dropped a target that stepped behind it")
	// Behind a wall now.
	var/turf/last_seen = stealth_at(block, 9, 2)
	person.forceMove(last_seen)
	stealth_scans(guard, 1)
	for(var/dy in 0 to 4)
		var/turf/wall_spot = stealth_at(block, 11, dy)
		wall_spot.ChangeTurf(/turf/closed/wall)
	person.forceMove(stealth_at(block, 13, 2))
	stealth_scans(guard, 1)
	TEST_ASSERT_EQUAL(stealth_ai.stealth_state(), "alert", "A guard gave up on a target the moment it went out of sight")
	stealth_ai.stealth_rewind(5 SECONDS)
	stealth_scans(guard, 1)
	TEST_ASSERT_EQUAL(stealth_ai.stealth_state(), "searching", "A guard that lost its target isn't searching")
	TEST_ASSERT_EQUAL(stealth_ai.last_seen_turf, last_seen, "The search isn't at the last place it saw them")
	TEST_ASSERT_NULL(stealth_ai.blackboard[BB_BASIC_MOB_CURRENT_TARGET], "A searching guard still has a target")
	qdel(block)

/// Hit from out of sight: searches the attacker's turf, wary. Pulled: alert on the puller. The step 3 hook.
/datum/unit_test/voidcrew_stealth_touched

/datum/unit_test/voidcrew_stealth_touched/Run()
	var/datum/turf_reservation/block = stealth_block(20, 5)
	TEST_ASSERT_NOTNULL(block, "No room for the test")
	var/mob/living/carbon/human/npc/guard = stealth_guard(block, 15, 2)
	var/datum/ai_controller/basic_controller/human_npc/stealth/stealth_ai = stealth_ai(guard)
	var/mob/living/carbon/human/person = stealth_person(block, 1, 2)
	SEND_SIGNAL(guard, COMSIG_ATOM_WAS_ATTACKED, person, ATTACKER_DAMAGING_ATTACK)
	TEST_ASSERT_EQUAL(stealth_ai.stealth_state(), "searching", "A guard hit from out of sight isn't searching")
	TEST_ASSERT_EQUAL(stealth_ai.last_seen_turf, get_turf(person), "The search isn't at the attacker's turf")
	TEST_ASSERT(stealth_ai.blackboard["stealth_wary"], "A guard that was hit isn't wary")
	qdel(guard)
	// Pulled.
	guard = stealth_guard(block, 15, 2)
	stealth_ai = stealth_ai(guard)
	person.forceMove(stealth_at(block, 14, 2))
	person.start_pulling(guard)
	TEST_ASSERT_EQUAL(stealth_ai.stealth_state(), "alert", "A pulled guard isn't alert")
	TEST_ASSERT_EQUAL(stealth_ai.blackboard[BB_BASIC_MOB_CURRENT_TARGET], person, "A pulled guard isn't after the puller")
	person.stop_pulling()
	qdel(guard)
	// The hook: unaware when the blow began, even though the blow made it alert.
	guard = stealth_guard(block, 15, 2)
	stealth_ai = stealth_ai(guard)
	TEST_ASSERT(guard.stealth_was_unaware(), "An unaware guard doesn't read as unaware")
	SEND_SIGNAL(guard, COMSIG_ATOM_WAS_ATTACKED, person, ATTACKER_DAMAGING_ATTACK)
	TEST_ASSERT_EQUAL(stealth_ai.stealth_state(), "alert", "A guard hit by someone beside it isn't alert")
	TEST_ASSERT(guard.stealth_was_unaware(), "The hook forgot the guard was unaware in the same tick")
	stealth_ai.stealth_rewind(1)
	TEST_ASSERT(!guard.stealth_was_unaware(), "The hook still reads unaware after time passed")
	var/mob/living/carbon/human/npc/plain = allocate(/mob/living/carbon/human/npc/ruin/trooper/syndicate, stealth_at(block, 3, 2))
	TEST_ASSERT(!plain.stealth_was_unaware(), "An NPC without stealth reads as unaware")
	qdel(block)

/// A fallen friend in view: suspicious once; the same body never sets it off again.
/datum/unit_test/voidcrew_stealth_bodies

/datum/unit_test/voidcrew_stealth_bodies/Run()
	var/datum/turf_reservation/block = stealth_block(12, 5)
	TEST_ASSERT_NOTNULL(block, "No room for the test")
	allocate(/obj/effect/landmark/stealth_group, stealth_at(block, 6, 4))
	var/mob/living/carbon/human/npc/guard = stealth_guard(block, 2, 2)
	var/mob/living/carbon/human/npc/friend = stealth_guard(block, 5, 2)
	var/datum/ai_controller/basic_controller/human_npc/stealth/stealth_ai = stealth_ai(guard)
	var/datum/ai_controller/basic_controller/human_npc/stealth/friend_ai = stealth_ai(friend)
	stealth_ai.stealth_setup()
	friend_ai.stealth_setup()
	TEST_ASSERT_EQUAL(stealth_ai.group, friend_ai.group, "Two guards by one marker aren't in one group")
	friend.death()
	stealth_scans(guard, 1)
	TEST_ASSERT_EQUAL(stealth_ai.stealth_state(), "suspicious", "A guard didn't react to a dead friend in view")
	stealth_ai.stealth_go_unaware()
	stealth_ai.next_body_scan = 0
	stealth_scans(guard, 3)
	TEST_ASSERT_EQUAL(stealth_ai.stealth_state(), "unaware", "The same body set a guard off twice")
	qdel(block)

/// Routes: each guard claims only its own group's stops, in order; a guard far from any stop is a sentry.
/// A stop it can't reach is skipped after STEALTH_PATROL_MAX_FAILS failures.
/datum/unit_test/voidcrew_stealth_routes

/datum/unit_test/voidcrew_stealth_routes/Run()
	var/datum/turf_reservation/first = stealth_block(10, 5)
	var/datum/turf_reservation/second = stealth_block(10, 5)
	TEST_ASSERT(first && second, "No room for the test")
	var/list/guards = list()
	for(var/datum/turf_reservation/block in list(first, second))
		allocate(/obj/effect/landmark/stealth_group, stealth_at(block, 9, 4))
		// Made out of order, so the group has to sort them.
		var/obj/effect/landmark/stealth_patrol/third = allocate(/obj/effect/landmark/stealth_patrol, stealth_at(block, 7, 0))
		third.order = 3
		var/obj/effect/landmark/stealth_patrol/second_stop = allocate(/obj/effect/landmark/stealth_patrol, stealth_at(block, 4, 0))
		second_stop.order = 2
		var/obj/effect/landmark/stealth_patrol/first_stop = allocate(/obj/effect/landmark/stealth_patrol, stealth_at(block, 1, 0))
		first_stop.order = 1
		guards += stealth_guard(block, 1, 0)
	var/list/stop_columns = list(1, 4, 7)
	for(var/i in 1 to 2)
		var/datum/turf_reservation/block = i == 1 ? first : second
		var/datum/ai_controller/basic_controller/human_npc/stealth/stealth_ai = stealth_ai(guards[i])
		stealth_ai.stealth_setup()
		TEST_ASSERT_EQUAL(stealth_ai.route_id, "a", "Guard [i] didn't claim the route it spawned on")
		var/list/stops = stealth_ai.stealth_stops()
		TEST_ASSERT_EQUAL(length(stops), 3, "Guard [i]'s route has [length(stops)] stops, not its own group's 3")
		for(var/index in 1 to length(stops))
			var/datum/stealth_stop/stop = stops[index]
			TEST_ASSERT_EQUAL(stop.order, index, "Guard [i]'s stop [index] is out of order")
			TEST_ASSERT_EQUAL(stop.spot, stealth_at(block, stop_columns[index], 0), "Guard [i]'s stop [index] isn't in its own block")
	var/mob/living/carbon/human/npc/sentry = stealth_guard(first, 1, 4, SOUTH)
	var/datum/ai_controller/basic_controller/human_npc/stealth/sentry_ai = stealth_ai(sentry)
	// Four tiles from the nearest stop, beyond STEALTH_ROUTE_CLAIM_RANGE (2).
	sentry_ai.stealth_setup()
	TEST_ASSERT_NULL(sentry_ai.route_id, "A guard away from every stop claimed a route")
	TEST_ASSERT_EQUAL(sentry_ai.sentry_dir, SOUTH, "The sentry doesn't face the way it spawned")
	// Unreachable stop.
	var/datum/ai_controller/basic_controller/human_npc/stealth/walker = stealth_ai(guards[1])
	walker.route_index = 2
	walker.goto_purpose = "patrol"
	for(var/i in 1 to 3)
		walker.stealth_walk_failed()
	TEST_ASSERT(walker.stop_skip_until["2"] > world.time, "A stop that failed 3 times isn't skipped")
	TEST_ASSERT(walker.route_index != 2, "The guard still heads for a skipped stop")
	qdel(first)
	qdel(second)

/// A search that ran out while the guard slept ends on waking: unaware, still wary.
/datum/unit_test/voidcrew_stealth_wake

/datum/unit_test/voidcrew_stealth_wake/Run()
	var/datum/turf_reservation/block = stealth_block(5, 5)
	TEST_ASSERT_NOTNULL(block, "No room for the test")
	var/mob/living/carbon/human/npc/guard = stealth_guard(block, 2, 2)
	var/datum/ai_controller/basic_controller/human_npc/stealth/stealth_ai = stealth_ai(guard)
	stealth_ai.stealth_go_searching(stealth_at(block, 3, 3))
	stealth_ai.stealth_rewind(41 SECONDS)
	stealth_scans(guard, 1)
	TEST_ASSERT_EQUAL(stealth_ai.stealth_state(), "unaware", "A search past its time didn't end on waking")
	TEST_ASSERT(stealth_ai.blackboard["stealth_wary"], "A guard that searched isn't wary")
	qdel(block)

/// Someone in a locker in front of a guard is unseen; a mech in range is alert at once.
/datum/unit_test/voidcrew_stealth_containers

/datum/unit_test/voidcrew_stealth_containers/Run()
	var/datum/turf_reservation/block = stealth_block(10, 5)
	TEST_ASSERT_NOTNULL(block, "No room for the test")
	var/mob/living/carbon/human/npc/guard = stealth_guard(block, 2, 2)
	var/datum/ai_controller/basic_controller/human_npc/stealth/stealth_ai = stealth_ai(guard)
	var/mob/living/carbon/human/person = stealth_person(block, 4, 2)
	var/obj/structure/closet/locker = allocate(/obj/structure/closet, stealth_at(block, 4, 2))
	locker.close()
	person.forceMove(locker)
	stealth_scans(guard, 10)
	TEST_ASSERT_EQUAL(stealth_ai.stealth_state(), "unaware", "A guard saw someone shut in a locker")
	person.forceMove(stealth_at(block, 6, 2))
	var/obj/vehicle/sealed/mecha/ripley/mech = allocate(/obj/vehicle/sealed/mecha/ripley, stealth_at(block, 6, 2))
	person.forceMove(mech)
	mech.add_occupant(person)
	stealth_scans(guard, 1)
	TEST_ASSERT_EQUAL(stealth_ai.stealth_state(), "alert", "A guard wasn't alert on a mech in front of it")
	TEST_ASSERT_EQUAL(stealth_ai.blackboard[BB_BASIC_MOB_CURRENT_TARGET], mech, "The guard isn't after the mech")
	mech.remove_occupant(person)
	person.forceMove(stealth_at(block, 8, 2))
	qdel(block)

/// Deleting a guard takes it out of its group; with the marker and every guard gone the group goes too.
/datum/unit_test/voidcrew_stealth_cleanup

/datum/unit_test/voidcrew_stealth_cleanup/Run()
	var/datum/turf_reservation/block = stealth_block(6, 4)
	TEST_ASSERT_NOTNULL(block, "No room for the test")
	var/obj/effect/landmark/stealth_group/marker = new(stealth_at(block, 5, 3))
	var/datum/stealth_group/group = marker.group
	var/mob/living/carbon/human/npc/guard = new STEALTH_TEST_GUARD(stealth_at(block, 1, 1))
	var/datum/ai_controller/basic_controller/human_npc/stealth/stealth_ai = guard.ai_controller
	stealth_ai.stealth_setup()
	TEST_ASSERT_EQUAL(stealth_ai.group, group, "The guard didn't join the marker's group")
	qdel(guard)
	TEST_ASSERT_EQUAL(length(group.living_members()), 0, "A deleted guard is still in its group")
	TEST_ASSERT(group in GLOB.stealth_groups, "A group with its marker standing was removed")
	qdel(marker)
	TEST_ASSERT(!(group in GLOB.stealth_groups), "A group with no marker and no guards is still registered")
	qdel(block)

/// Its target dead with nobody else about: a short look round, then unaware. Anyone else in view or hurting it
/// keeps the alarm going.
/datum/unit_test/voidcrew_stealth_calm

/datum/unit_test/voidcrew_stealth_calm/Run()
	var/datum/turf_reservation/block = stealth_block(12, 5)
	TEST_ASSERT_NOTNULL(block, "No room for the test")
	var/mob/living/carbon/human/npc/guard = stealth_guard(block, 2, 2)
	var/datum/ai_controller/basic_controller/human_npc/stealth/stealth_ai = stealth_ai(guard)
	var/mob/living/carbon/human/target = stealth_person(block, 4, 2)
	stealth_ai.stealth_go_alert(target)
	stealth_scans(guard, 1)
	target.death()
	stealth_scans(guard, 1)
	TEST_ASSERT_EQUAL(stealth_ai.stealth_state(), "searching", "A guard that killed its target isn't looking round")
	TEST_ASSERT(stealth_ai.calm_until, "A guard that killed its target with nobody about isn't calming down")
	TEST_ASSERT_NULL(stealth_ai.blackboard[BB_BASIC_MOB_CURRENT_TARGET], "A guard still has a dead target")
	stealth_ai.stealth_rewind(7 SECONDS)
	stealth_scans(guard, 1)
	TEST_ASSERT_EQUAL(stealth_ai.stealth_state(), "unaware", "A guard didn't calm down after its target died")
	TEST_ASSERT(stealth_ai.blackboard["stealth_wary"], "A guard that just fought isn't wary")
	qdel(guard)
	qdel(target)
	// Someone else in plain view: no calming down.
	guard = stealth_guard(block, 2, 2)
	stealth_ai = stealth_ai(guard)
	target = stealth_person(block, 4, 2)
	var/mob/living/carbon/human/bystander = stealth_person(block, 5, 3)
	stealth_ai.stealth_go_alert(target)
	target.death()
	stealth_scans(guard, 1)
	TEST_ASSERT(stealth_ai.stealth_state() == "suspicious" || stealth_ai.stealth_state() == "alert", "A guard calmed down with someone else in front of it")
	TEST_ASSERT(!stealth_ai.calm_until, "A guard is calming down with someone else in front of it")
	qdel(guard)
	qdel(target)
	qdel(bystander)
	// Someone behind it hits it during the fight: it turns on them, and not straight back when the first one hits it.
	guard = stealth_guard(block, 6, 2)
	stealth_ai = stealth_ai(guard)
	target = stealth_person(block, 8, 2)
	var/mob/living/carbon/human/flanker = stealth_person(block, 3, 2)
	stealth_ai.stealth_go_alert(target)
	SEND_SIGNAL(guard, COMSIG_ATOM_WAS_ATTACKED, flanker, ATTACKER_DAMAGING_ATTACK)
	TEST_ASSERT_EQUAL(stealth_ai.blackboard[BB_BASIC_MOB_CURRENT_TARGET], flanker, "A guard didn't turn on someone else who hit it")
	SEND_SIGNAL(guard, COMSIG_ATOM_WAS_ATTACKED, target, ATTACKER_DAMAGING_ATTACK)
	TEST_ASSERT_EQUAL(stealth_ai.blackboard[BB_BASIC_MOB_CURRENT_TARGET], flanker, "A guard hit by two people flapped straight back to the first")
	// The one it turned on dies: the other is still there, and remembered.
	flanker.death()
	stealth_scans(guard, 1)
	TEST_ASSERT_EQUAL(stealth_ai.stealth_state(), "alert", "A guard calmed down while someone else was hurting it")
	TEST_ASSERT_EQUAL(stealth_ai.blackboard[BB_BASIC_MOB_CURRENT_TARGET], target, "The guard didn't go back to whoever else hit it")
	qdel(block)

/// Wary fades after STEALTH_WARY_TIME with nothing new; a notice gain starts the clock again.
/datum/unit_test/voidcrew_stealth_wary_fade

/datum/unit_test/voidcrew_stealth_wary_fade/Run()
	var/datum/turf_reservation/block = stealth_block(12, 5)
	TEST_ASSERT_NOTNULL(block, "No room for the test")
	var/mob/living/carbon/human/npc/guard = stealth_guard(block, 2, 2)
	var/datum/ai_controller/basic_controller/human_npc/stealth/stealth_ai = stealth_ai(guard)
	stealth_ai.stealth_go_searching(stealth_at(block, 3, 3))
	stealth_ai.stealth_rewind(41 SECONDS)
	stealth_scans(guard, 1)
	TEST_ASSERT_EQUAL(stealth_ai.stealth_state(), "unaware", "The search didn't end")
	TEST_ASSERT(stealth_ai.blackboard["stealth_wary"], "A guard that searched isn't wary")
	stealth_ai.stealth_rewind(40 SECONDS)
	stealth_scans(guard, 1)
	TEST_ASSERT(stealth_ai.blackboard["stealth_wary"], "Wary faded too soon")
	// A glimpse of someone far off starts the clock again.
	var/mob/living/carbon/human/person = stealth_person(block, 9, 2)
	stealth_scans(guard, 1)
	TEST_ASSERT_EQUAL(stealth_ai.stealth_state(), "unaware", "A glimpse at the edge of sight made the guard suspicious")
	qdel(person)
	stealth_ai.stealth_rewind(40 SECONDS)
	stealth_scans(guard, 1)
	TEST_ASSERT(stealth_ai.blackboard["stealth_wary"], "A notice gain didn't refresh wary")
	stealth_ai.stealth_rewind(30 SECONDS)
	stealth_scans(guard, 1)
	TEST_ASSERT(!stealth_ai.blackboard["stealth_wary"], "Wary didn't fade with nothing new")
	TEST_ASSERT(stealth_ai.stealth_half_angle() == 60, "A guard no longer wary still has the wary cone")
	// A hit makes it wary again.
	var/mob/living/carbon/human/attacker = stealth_person(block, 11, 4)
	SEND_SIGNAL(guard, COMSIG_ATOM_WAS_ATTACKED, attacker, ATTACKER_DAMAGING_ATTACK)
	TEST_ASSERT(stealth_ai.blackboard["stealth_wary"], "A hit didn't make the guard wary again")
	qdel(block)

/// The mark over a guard's head: notice and state to icon_state (draft D: fills round to nearest, drains round up).
/datum/unit_test/voidcrew_stealth_meter_states

/datum/unit_test/voidcrew_stealth_meter_states/Run()
	// Private "?": yellow to 1.0, then red to 2.5.
	TEST_ASSERT_NULL(stealth_meter_notice_state(0), "No notice still shows a mark")
	TEST_ASSERT_EQUAL(stealth_meter_notice_state(0.05), "q_y0", "A little notice isn't an empty grey ?")
	TEST_ASSERT_EQUAL(stealth_meter_notice_state(0.3), "q_y2", "0.3 notice")
	TEST_ASSERT_EQUAL(stealth_meter_notice_state(0.5), "q_y4", "Half notice doesn't round to the nearest row")
	TEST_ASSERT_EQUAL(stealth_meter_notice_state(1), "q_y7", "Suspicious isn't a full yellow ?")
	TEST_ASSERT_EQUAL(stealth_meter_notice_state(1.75), "q_r4", "Halfway to alert isn't half red")
	TEST_ASSERT_EQUAL(stealth_meter_notice_state(2.5), "q_r7", "Alert notice isn't a full red ?")
	TEST_ASSERT_EQUAL(stealth_meter_notice_state(4), "q_r7", "Notice past alert overflows the glyph")
	// Public marks. Times in deciseconds; now = 10000.
	TEST_ASSERT_NULL(stealth_meter_public_state("unaware", 10000, 0, 9000, 0), "An unaware guard has a public mark")
	TEST_ASSERT_NULL(stealth_meter_public_state("suspicious", 10000, 0, 9000, 0), "A suspicious guard has a public mark")
	TEST_ASSERT_EQUAL(stealth_meter_public_state("alert", 10000, 0, 9000, 0), "ex_r7", "Alert with the target in sight isn't a full red !")
	TEST_ASSERT_EQUAL(stealth_meter_public_state("alert", 10000, 9980, 9000, 0), "ex_r4", "Target lost 2 of 4 s: the ! doesn't drain rounding up")
	TEST_ASSERT_EQUAL(stealth_meter_public_state("alert", 10000, 9961, 9000, 0), "ex_r1", "The last row of the ! went out early")
	TEST_ASSERT_EQUAL(stealth_meter_public_state("alert", 10000, 9960, 9000, 0), "q_y7", "A drained ! doesn't become the yellow ?")
	TEST_ASSERT_EQUAL(stealth_meter_public_state("searching", 10000, 0, 10000, 0), "q_y7", "A fresh search isn't a full yellow ?")
	TEST_ASSERT_EQUAL(stealth_meter_public_state("searching", 10000, 0, 9800, 0), "q_y4", "Halfway through the 40 s search")
	TEST_ASSERT_NULL(stealth_meter_public_state("searching", 10000, 0, 9600, 0), "A finished search still shows")
	TEST_ASSERT_EQUAL(stealth_meter_public_state("searching", 10000, 0, 9970, 10030), "q_y4", "Calming down doesn't drain to calm_until")
	// The drain steps at each row: the full ! loses its top row after 1/7 of 4 s.
	var/step = stealth_meter_next_step("alert", 10000, 10000, 9000, 0)
	TEST_ASSERT(step > 40 / 7 && step < 40 / 7 + 1, "The first drain step isn't at 1/7 of the lose time (got [step])")
	TEST_ASSERT_EQUAL(stealth_meter_next_step("alert", 10000, 0, 9000, 0), 0, "A steady ! schedules a drain")

/// The mark goes with its guard: death, deletion, and the public mark hides the private one.
/datum/unit_test/voidcrew_stealth_meter_cleanup

/datum/unit_test/voidcrew_stealth_meter_cleanup/Run()
	var/datum/turf_reservation/block = stealth_block(8, 5)
	TEST_ASSERT_NOTNULL(block, "No room for the test")
	var/mob/living/carbon/human/npc/guard = stealth_guard(block, 2, 2)
	var/datum/ai_controller/basic_controller/human_npc/stealth/stealth_ai = stealth_ai(guard)
	var/mob/living/carbon/human/person = stealth_person(block, 4, 2)
	stealth_ai.stealth_go_alert(person)
	// No client is near in a test, so build it by hand.
	stealth_ai.meter = new /datum/stealth_meter(stealth_ai, guard)
	var/datum/stealth_meter/meter = stealth_ai.meter
	meter.update()
	var/obj/effect/abstract/stealth_mark/mark = meter.mark
	TEST_ASSERT_NOTNULL(mark, "An alert guard has no mark")
	TEST_ASSERT_EQUAL(mark.icon_state, "ex_r7", "An alert guard's mark isn't a full red !")
	TEST_ASSERT(mark in guard.vis_contents, "The mark isn't drawn on the guard")
	TEST_ASSERT_EQUAL(mark.pixel_z, stealth_meter_offset(guard), "The mark isn't just over a standing guard's head")
	TEST_ASSERT(mark.pixel_z > 29, "The mark sits in a standing guard's face")
	guard.set_body_position(LYING_DOWN)
	TEST_ASSERT_EQUAL(mark.pixel_z, 29, "The mark didn't drop when the guard lay down")
	guard.set_body_position(STANDING_UP)
	guard.death()
	TEST_ASSERT(QDELETED(meter), "A dead guard kept its mark")
	TEST_ASSERT(!(mark in guard.vis_contents), "A dead guard still draws its mark")
	TEST_ASSERT(QDELETED(mark), "A dead guard's mark wasn't deleted")
	// Deletion.
	var/mob/living/carbon/human/npc/second = stealth_guard(block, 6, 2)
	var/datum/ai_controller/basic_controller/human_npc/stealth/second_ai = stealth_ai(second)
	second_ai.stealth_go_searching(stealth_at(block, 6, 3))
	second_ai.meter = new /datum/stealth_meter(second_ai, second)
	meter = second_ai.meter
	meter.update()
	mark = meter.mark
	TEST_ASSERT_EQUAL(mark?.icon_state, "q_y7", "A searching guard's mark isn't a full yellow ?")
	qdel(second)
	TEST_ASSERT(QDELETED(meter), "A deleted guard's meter lived on")
	TEST_ASSERT(QDELETED(mark), "A deleted guard's mark lived on")
	qdel(block)

/// A stealth guard hit by an ally's stray shot doesn't turn on them or raise the alarm.
/datum/unit_test/voidcrew_stealth_ally_hit

/datum/unit_test/voidcrew_stealth_ally_hit/Run()
	var/datum/turf_reservation/block = stealth_block(6, 5)
	TEST_ASSERT_NOTNULL(block, "No room for the test")
	var/mob/living/carbon/human/npc/guard = stealth_guard(block, 2, 2)
	var/mob/living/carbon/human/npc/ally = stealth_guard(block, 4, 2, WEST)
	var/datum/ai_controller/basic_controller/human_npc/stealth/stealth_ai = stealth_ai(guard)
	SEND_SIGNAL(guard, COMSIG_ATOM_WAS_ATTACKED, ally, ATTACKER_DAMAGING_ATTACK)
	TEST_ASSERT_EQUAL(stealth_ai.stealth_state(), "unaware", "An ally's stray shot raised the alarm")
	TEST_ASSERT_NULL(stealth_ai.blackboard[BB_BASIC_MOB_CURRENT_TARGET], "An ally's stray shot made the guard target them")
	TEST_ASSERT(!stealth_ai.blackboard["stealth_wary"], "An ally's stray shot made the guard wary")
	qdel(block)

/// The candidate cap counts only those it could perceive: a crowd of its own side at its feet doesn't hide someone further off.
/datum/unit_test/voidcrew_stealth_cap

/datum/unit_test/voidcrew_stealth_cap/Run()
	var/datum/turf_reservation/block = stealth_block(10, 5)
	TEST_ASSERT_NOTNULL(block, "No room for the test")
	var/mob/living/carbon/human/npc/guard = stealth_guard(block, 2, 2)
	var/datum/ai_controller/basic_controller/human_npc/stealth/stealth_ai = stealth_ai(guard)
	// More than STEALTH_MAX_CANDIDATES (8) of its own side, all nearer than the person.
	for(var/i in 1 to 10)
		var/mob/living/basic/mouse/mouse = allocate(/mob/living/basic/mouse, stealth_at(block, 3, 2))
		mouse.faction = list("scav") // FACTION_SCAV
	stealth_person(block, 5, 2)
	stealth_scans(guard, 1)
	TEST_ASSERT_EQUAL(stealth_ai.stealth_state(), "suspicious", "A crowd of its own side hid someone 3 tiles in front of a guard")
	qdel(block)

/// Notice stops at STEALTH_ALERT_AT (2.5), so someone out of reach can't bank a lead that hides a second person.
/datum/unit_test/voidcrew_stealth_notice_cap

/datum/unit_test/voidcrew_stealth_notice_cap/Run()
	var/datum/turf_reservation/block = stealth_block(20, 7)
	TEST_ASSERT_NOTNULL(block, "No room for the test")
	var/mob/living/carbon/human/npc/guard = stealth_guard(block, 6, 3)
	var/datum/ai_controller/basic_controller/human_npc/stealth/stealth_ai = stealth_ai(guard)
	// Eight tiles off: noticed, never alert (STEALTH_ALERT_MAX_RANGE 7).
	var/mob/living/carbon/human/far = stealth_person(block, 14, 3)
	stealth_scans(guard, 30)
	var/list/entry = stealth_ai.notice_map[REF(far)]
	TEST_ASSERT_NOTNULL(entry, "A guard never noticed someone 8 tiles in front of it")
	TEST_ASSERT(entry[1] <= 2.5, "Notice climbed past the alert level ([entry[1]])")
	// They step out of sight behind it; someone else walks up in front.
	far.forceMove(stealth_at(block, 0, 3))
	var/mob/living/carbon/human/near = stealth_person(block, 8, 3)
	stealth_scans(guard, 5)
	TEST_ASSERT_EQUAL(stealth_ai.stealth_state(), "alert", "Someone it could no longer see kept a guard from alerting on the person in front of it")
	TEST_ASSERT_EQUAL(stealth_ai.blackboard[BB_BASIC_MOB_CURRENT_TARGET], near, "The guard isn't after the person in front of it")
	qdel(block)

/// A friend who went down, got up and went down again is news again.
/datum/unit_test/voidcrew_stealth_body_again

/datum/unit_test/voidcrew_stealth_body_again/Run()
	var/datum/turf_reservation/block = stealth_block(12, 5)
	TEST_ASSERT_NOTNULL(block, "No room for the test")
	allocate(/obj/effect/landmark/stealth_group, stealth_at(block, 6, 4))
	var/mob/living/carbon/human/npc/guard = stealth_guard(block, 2, 2)
	var/mob/living/carbon/human/npc/friend = stealth_guard(block, 5, 2)
	var/datum/ai_controller/basic_controller/human_npc/stealth/stealth_ai = stealth_ai(guard)
	var/datum/ai_controller/basic_controller/human_npc/stealth/friend_ai = stealth_ai(friend)
	stealth_ai.stealth_setup()
	friend_ai.stealth_setup()
	friend.set_body_position(LYING_DOWN)
	stealth_scans(guard, 1)
	TEST_ASSERT_EQUAL(stealth_ai.stealth_state(), "suspicious", "A guard didn't react to a friend on the floor")
	stealth_ai.stealth_go_unaware()
	friend.set_body_position(STANDING_UP)
	stealth_ai.next_body_scan = 0
	stealth_scans(guard, 1)
	TEST_ASSERT_EQUAL(stealth_ai.stealth_state(), "unaware", "A friend back on its feet set a guard off")
	friend.death()
	stealth_ai.next_body_scan = 0
	stealth_scans(guard, 1)
	TEST_ASSERT_EQUAL(stealth_ai.stealth_state(), "suspicious", "A guard ignored a friend killed after getting back up")
	qdel(block)

// ===== The real AI =====

/**
 * Tests that run the guard's real AI: planning, the scan and real walking, over a few seconds of game time. A
 * person on SSmobs' list of players keeps the level awake, as a player there does. Every wait is on game time
 * with a long deadline and ends as soon as the thing happens, so a slow machine only makes them slower.
 */
/datum/unit_test/voidcrew_stealth_live
	abstract_type = /datum/unit_test/voidcrew_stealth_live
	/// The walled room this test runs in
	var/datum/turf_reservation/room
	/// person => the z-level they were listed on
	var/list/players = list()

/datum/unit_test/voidcrew_stealth_live/Destroy()
	for(var/mob/living/person as anything in players)
		SSmobs.clients_by_zlevel[players[person]] -= person
	players = null
	. = ..()
	QDEL_NULL(room)

/// Builds a lit, walled, floored room `width` x `height` inside (walls keep its air in). FALSE if there is no room.
/datum/unit_test/voidcrew_stealth_live/proc/make_room(width, height)
	room = SSmapping.request_turf_block_reservation(width + 2, height + 2, 1)
	if(isnull(room))
		return FALSE
	var/turf/corner = room.bottom_left_turfs[1]
	for(var/turf/spot as anything in block(corner.x, corner.y, corner.z, corner.x + width + 1, corner.y + height + 1, corner.z))
		var/edge = spot.x == corner.x || spot.y == corner.y || spot.x == corner.x + width + 1 || spot.y == corner.y + height + 1
		spot.ChangeTurf(edge ? /turf/closed/wall : /turf/open/floor/iron)
		GLOB.stealth_test_dark_turfs[spot] = FALSE
	return TRUE

/// The floor (dx, dy) from the room's inside corner.
/datum/unit_test/voidcrew_stealth_live/proc/at(dx, dy)
	var/turf/corner = room.bottom_left_turfs[1]
	return locate(corner.x + 1 + dx, corner.y + 1 + dy, corner.z)

/datum/unit_test/voidcrew_stealth_live/proc/guard_at(dx, dy, facing = EAST)
	var/mob/living/carbon/human/npc/guard = allocate(STEALTH_TEST_GUARD, at(dx, dy))
	guard.setDir(facing)
	guard.AddElement(/datum/element/forced_gravity, 1)
	return guard

/// A walking person the guards can't hurt (the tests are about what the guards do, not how the fight goes).
/// `listed` puts them on SSmobs' list of players.
/datum/unit_test/voidcrew_stealth_live/proc/person_at(dx, dy, listed = TRUE)
	var/mob/living/carbon/human/consistent/person = allocate(/mob/living/carbon/human/consistent, at(dx, dy))
	if(person.move_intent == MOVE_INTENT_RUN)
		person.toggle_move_intent()
	person.AddElement(/datum/element/forced_gravity, 1)
	person.physiology.brute_mod = 0
	person.physiology.burn_mod = 0
	person.physiology.stamina_mod = 0
	if(listed)
		var/turf/where = get_turf(person)
		SSmobs.clients_by_zlevel[where.z] += person
		players[person] = where.z
	return person

/// Switches a guard's AI on, as someone arriving on its level does.
/datum/unit_test/voidcrew_stealth_live/proc/wake(mob/living/guard)
	var/datum/ai_controller/basic_controller/human_npc/stealth/stealth_ai = guard.ai_controller
	stealth_ai.reset_ai_status()
	return stealth_ai

/// A stop on route "a".
/datum/unit_test/voidcrew_stealth_live/proc/stop_at(dx, dy, order, wait = 5)
	var/obj/effect/landmark/stealth_patrol/stop = allocate(/obj/effect/landmark/stealth_patrol, at(dx, dy))
	stop.order = order
	stop.wait = wait
	return stop

/// A route leg longer than tg's 14-tile walk limit, with the only player far off behind a wall: it gets there.
/datum/unit_test/voidcrew_stealth_live/patrol

/datum/unit_test/voidcrew_stealth_live/patrol/Run()
	TEST_ASSERT(make_room(40, 5), "No room for the test")
	allocate(/obj/effect/landmark/stealth_group, at(0, 4))
	stop_at(1, 2, 1)
	stop_at(26, 2, 2)
	// A wall between the far stop and the player, who is 37 tiles from the guard: past tg's idle radius.
	for(var/dy in 0 to 4)
		var/turf/wall_spot = at(32, dy)
		wall_spot.ChangeTurf(/turf/closed/wall)
	person_at(38, 2)
	var/mob/living/carbon/human/npc/guard = guard_at(1, 2)
	var/datum/ai_controller/basic_controller/human_npc/stealth/stealth_ai = wake(guard)
	TEST_ASSERT_EQUAL(stealth_ai.ai_status, AI_STATUS_ON, "A guard with a player far off on its level isn't fully awake")
	var/turf/far_stop = at(26, 2)
	var/deadline = world.time + 90 SECONDS
	while(get_turf(guard) != far_stop && world.time < deadline)
		sleep(2)
	TEST_ASSERT_EQUAL(stealth_ai.route_id, "a", "The guard never claimed its route")
	TEST_ASSERT_EQUAL(get_turf(guard), far_stop, "A guard didn't finish a 25-tile route leg (it is [get_dist(guard, far_stop)] tiles short)")
	TEST_ASSERT_EQUAL(stealth_ai.stealth_state(), "unaware", "A patrolling guard with nobody in sight isn't unaware")
	// And back: the route goes on.
	var/turf/near_stop = at(1, 2)
	deadline = world.time + 90 SECONDS
	while(get_turf(guard) != near_stop && world.time < deadline)
		sleep(2)
	TEST_ASSERT_EQUAL(get_turf(guard), near_stop, "A guard didn't walk back along its route")
	TEST_ASSERT_NOTNULL(stealth_ai.route_id, "A guard gave up its route")

/// Left far from its route by a chase, a guard walks back to it; a sentry walks back to its post.
/datum/unit_test/voidcrew_stealth_live/walk_home

/datum/unit_test/voidcrew_stealth_live/walk_home/Run()
	TEST_ASSERT(make_room(52, 5), "No room for the test")
	allocate(/obj/effect/landmark/stealth_group, at(0, 2))
	stop_at(1, 0, 1, 50)
	stop_at(4, 0, 2, 50)
	for(var/dy in 0 to 4)
		var/turf/wall_spot = at(49, dy)
		wall_spot.ChangeTurf(/turf/closed/wall)
	person_at(50, 2)
	var/mob/living/carbon/human/npc/walker = guard_at(1, 0)
	// Four tiles from the nearest stop: past STEALTH_ROUTE_CLAIM_RANGE (2), so a sentry.
	var/mob/living/carbon/human/npc/sentry = guard_at(1, 4, SOUTH)
	var/datum/ai_controller/basic_controller/human_npc/stealth/walker_ai = wake(walker)
	var/datum/ai_controller/basic_controller/human_npc/stealth/sentry_ai = wake(sentry)
	walker_ai.stealth_setup()
	sentry_ai.stealth_setup()
	TEST_ASSERT_EQUAL(walker_ai.route_id, "a", "The guard on the route didn't claim it")
	TEST_ASSERT_NULL(sentry_ai.route_id, "The guard off the route claimed it")
	var/turf/post = at(1, 4)
	// Where a long chase ends: 43 tiles from the route. Further than STEALTH_LEASH_RANGE (24), and than one walk
	// (STEALTH_WALK_LEG 40), so the way back is in two legs.
	walker.forceMove(at(47, 0))
	sentry.forceMove(at(47, 4))
	walker_ai.stealth_go_searching(at(47, 0))
	sentry_ai.stealth_go_searching(at(47, 4))
	walker_ai.stealth_rewind(41 SECONDS)
	sentry_ai.stealth_rewind(41 SECONDS)
	var/deadline = world.time + 120 SECONDS
	while(world.time < deadline && !(get_turf(sentry) == post && walker_ai.at_stop))
		sleep(2)
	TEST_ASSERT_EQUAL(walker_ai.route_id, "a", "A guard left far from its route became a sentry")
	TEST_ASSERT(walker_ai.at_stop, "A guard left far from its route never got back to a stop (it is at [walker.x - at(0, 0).x], [walker.y - at(0, 0).y])")
	TEST_ASSERT(get_dist(walker, at(4, 0)) <= 3, "The guard is at a stop that isn't on its route")
	TEST_ASSERT_EQUAL(get_turf(sentry), post, "A sentry left far from its post didn't walk back (it is [get_dist(sentry, post)] tiles off)")
	TEST_ASSERT_EQUAL(sentry_ai.home_turf, post, "A sentry's post moved")

/// Searching, it goes straight to alert on someone it glimpses, never down to suspicious.
/datum/unit_test/voidcrew_stealth_live/search_to_alert

/datum/unit_test/voidcrew_stealth_live/search_to_alert/Run()
	TEST_ASSERT(make_room(14, 5), "No room for the test")
	var/mob/living/carbon/human/npc/guard = guard_at(3, 2)
	var/mob/living/carbon/human/person = person_at(12, 0)
	var/datum/ai_controller/basic_controller/human_npc/stealth/stealth_ai = wake(guard)
	stealth_ai.stealth_go_searching(at(3, 2))
	// Three tiles in front of it: one scan's worth of notice is past suspicious but short of alert.
	person.forceMove(at(6, 2))
	var/went_suspicious = FALSE
	var/deadline = world.time + 20 SECONDS
	while(stealth_ai.stealth_state() != "alert" && world.time < deadline)
		if(stealth_ai.stealth_state() == "suspicious")
			went_suspicious = TRUE
		sleep(1)
	TEST_ASSERT(!went_suspicious, "A searching guard that glimpsed someone dropped to suspicious")
	TEST_ASSERT_EQUAL(stealth_ai.stealth_state(), "alert", "A searching guard didn't go alert on someone three tiles in front of it")
	TEST_ASSERT_EQUAL(stealth_ai.blackboard[BB_BASIC_MOB_CURRENT_TARGET], person, "The guard isn't after the person it glimpsed")

/// Alert on a decoy it can't reach, it still notices someone nearer and turns on them; it doesn't flap back.
/datum/unit_test/voidcrew_stealth_live/switch_target

/datum/unit_test/voidcrew_stealth_live/switch_target/Run()
	TEST_ASSERT(make_room(14, 5), "No room for the test")
	// A glass wall: the decoy beyond it is in plain sight and out of reach.
	for(var/dy in 0 to 4)
		allocate(/obj/structure/window/reinforced/fulltile, at(8, dy))
	var/mob/living/carbon/human/npc/guard = guard_at(3, 2)
	var/mob/living/carbon/human/decoy = person_at(11, 2)
	var/datum/ai_controller/basic_controller/human_npc/stealth/stealth_ai = wake(guard)
	stealth_ai.stealth_go_alert(decoy)
	sleep(3 SECONDS)
	TEST_ASSERT_EQUAL(stealth_ai.stealth_state(), "alert", "A guard gave up on someone standing in plain sight behind glass")
	// tg drops the target key each time the walk at the glass fails; the next scan takes it back. Its focus stays.
	TEST_ASSERT_EQUAL(stealth_ai.blackboard["stealth_focus"], decoy, "A guard forgot the person behind the glass")
	// Someone else beside it, on its side of the glass.
	var/mob/living/carbon/human/intruder = person_at(1, 2, FALSE)
	intruder.forceMove(get_step(guard, WEST) || at(1, 2))
	var/deadline = world.time + 30 SECONDS
	while(stealth_ai.blackboard[BB_BASIC_MOB_CURRENT_TARGET] != intruder && world.time < deadline)
		// Kept at its shoulder, wherever it has got to.
		if(get_dist(intruder, guard) > 1)
			var/turf/beside = get_step(guard, WEST)
			if(beside && !beside.is_blocked_turf())
				intruder.forceMove(beside)
		sleep(2)
	TEST_ASSERT_EQUAL(stealth_ai.blackboard[BB_BASIC_MOB_CURRENT_TARGET], intruder, "A guard busy with a decoy never turned on someone at its shoulder")
	TEST_ASSERT_EQUAL(stealth_ai.stealth_state(), "alert", "A guard that changed target isn't alert")
	// The decoy hits it at once: too soon to turn back (STEALTH_SWITCH_COOLDOWN 4 s), and the decoy is no nearer.
	SEND_SIGNAL(guard, COMSIG_ATOM_WAS_ATTACKED, decoy, ATTACKER_DAMAGING_ATTACK)
	TEST_ASSERT_EQUAL(stealth_ai.blackboard[BB_BASIC_MOB_CURRENT_TARGET], intruder, "A guard flapped back to its old target the moment it was hit")
	var/flapped = FALSE
	deadline = world.time + 3 SECONDS
	while(world.time < deadline)
		if(stealth_ai.blackboard[BB_BASIC_MOB_CURRENT_TARGET] == decoy)
			flapped = TRUE
		sleep(2)
	TEST_ASSERT(!flapped, "A guard flapped back to the decoy while someone stood nearer")
	// Later, a hit from the decoy does turn it.
	stealth_ai.stealth_rewind(5 SECONDS)
	SEND_SIGNAL(guard, COMSIG_ATOM_WAS_ATTACKED, decoy, ATTACKER_DAMAGING_ATTACK)
	TEST_ASSERT_EQUAL(stealth_ai.blackboard[BB_BASIC_MOB_CURRENT_TARGET], decoy, "A guard didn't turn on someone who hit it once the cooldown had passed")

/// Someone in a cardboard box: unseen while it sits still, noticed when it moves at the guard's shoulder, found when it bumps it.
/datum/unit_test/voidcrew_stealth_live/box

/datum/unit_test/voidcrew_stealth_live/box/Run()
	TEST_ASSERT(make_room(16, 7), "No room for the test")
	person_at(15, 6)
	var/mob/living/carbon/human/npc/guard = guard_at(3, 3, WEST)
	var/datum/ai_controller/basic_controller/human_npc/stealth/stealth_ai = wake(guard)
	var/mob/living/carbon/human/stowaway = person_at(6, 3, FALSE)
	var/obj/structure/closet/cardboard/box = allocate(/obj/structure/closet/cardboard, at(6, 3))
	stowaway.forceMove(box)
	// Still, three tiles behind it, then still at two.
	sleep(3 SECONDS)
	TEST_ASSERT_EQUAL(stealth_ai.stealth_state(), "unaware", "A guard noticed a box that never moved")
	TEST_ASSERT(LAZYACCESS(stealth_ai.hidden_spots, REF(stowaway)), "The guard's scan never found the person in the box (the test can't tell hidden from missing)")
	// It shuffles about within two tiles.
	var/list/spots = list(at(5, 3), at(5, 4), at(5, 3), at(5, 2))
	var/spot_index = 0
	var/deadline = world.time + 30 SECONDS
	while(stealth_ai.stealth_state() == "unaware" && world.time < deadline)
		spot_index = (spot_index % length(spots)) + 1
		box.forceMove(spots[spot_index])
		sleep(1.2 SECONDS)
	TEST_ASSERT(stealth_ai.stealth_state() != "unaware", "A guard ignored a box shuffling about at its shoulder")
	// A second guard, and a box that walks into it.
	var/mob/living/carbon/human/npc/second = guard_at(12, 1, WEST)
	var/datum/ai_controller/basic_controller/human_npc/stealth/second_ai = wake(second)
	second_ai.stealth_setup()
	var/mob/living/carbon/human/second_person = person_at(14, 1, FALSE)
	var/obj/structure/closet/cardboard/second_box = allocate(/obj/structure/closet/cardboard, at(13, 1))
	second_person.forceMove(second_box)
	step(second_box, WEST)
	TEST_ASSERT_EQUAL(second_ai.stealth_state(), "alert", "A box that walked into a guard wasn't found out")
	TEST_ASSERT_EQUAL(second_ai.blackboard[BB_BASIC_MOB_CURRENT_TARGET], second_person, "The guard isn't after whoever is in the box")

/// A blast with nobody to blame: the guard it hits and the friend near it both go looking there. A hit with a name doesn't rouse the friend.
/datum/unit_test/voidcrew_stealth_live/blast

/datum/unit_test/voidcrew_stealth_live/blast/Run()
	TEST_ASSERT(make_room(30, 5), "No room for the test")
	allocate(/obj/effect/landmark/stealth_group, at(0, 4))
	for(var/dy in 0 to 4)
		var/turf/wall_spot = at(20, dy)
		wall_spot.ChangeTurf(/turf/closed/wall)
	var/mob/living/carbon/human/person = person_at(25, 2)
	var/mob/living/carbon/human/npc/struck = guard_at(3, 2, WEST)
	var/mob/living/carbon/human/npc/friend = guard_at(8, 2, EAST)
	var/datum/ai_controller/basic_controller/human_npc/stealth/struck_ai = wake(struck)
	var/datum/ai_controller/basic_controller/human_npc/stealth/friend_ai = wake(friend)
	sleep(2 SECONDS)
	TEST_ASSERT_EQUAL(struck_ai.group, friend_ai.group, "Two guards by one marker aren't in one group")
	TEST_ASSERT_EQUAL(friend_ai.stealth_state(), "unaware", "A guard with nothing going on isn't unaware")
	// A named hit first: the friend, facing away, hears nothing of it.
	SEND_SIGNAL(struck, COMSIG_ATOM_WAS_ATTACKED, person, ATTACKER_DAMAGING_ATTACK)
	struck.Stun(0.5 SECONDS)
	sleep(1 SECONDS)
	TEST_ASSERT_EQUAL(struck_ai.stealth_state(), "searching", "A guard hit from out of sight isn't searching")
	TEST_ASSERT_EQUAL(friend_ai.stealth_state(), "unaware", "A hit with a name on it roused the guard's friend")
	// Now a blast.
	struck_ai.stealth_go_unaware()
	struck_ai.stealth_clear_wary()
	struck_ai.stealth_rewind(30 SECONDS)
	var/turf/where_hit = get_turf(struck)
	EX_ACT(struck, EXPLODE_LIGHT)
	var/deadline = world.time + 5 SECONDS
	while(friend_ai.stealth_state() != "searching" && world.time < deadline)
		sleep(1)
	TEST_ASSERT_EQUAL(friend_ai.stealth_state(), "searching", "A blast on a guard didn't send its friend looking")
	TEST_ASSERT_EQUAL(friend_ai.last_seen_turf, where_hit, "The friend isn't looking where the blast was")
	TEST_ASSERT(friend_ai.blackboard["stealth_wary"], "The friend isn't wary after the blast")
	TEST_ASSERT(struck_ai.blackboard["stealth_wary"], "A guard caught in a blast isn't wary")
	TEST_ASSERT(struck.stat != CONSCIOUS || struck_ai.stealth_state() == "searching", "A guard caught in a blast went back to its post")

/// The mark over an alert guard's head goes when it is cuffed, and stays gone while it is.
/datum/unit_test/voidcrew_stealth_live/cuffed_mark

/datum/unit_test/voidcrew_stealth_live/cuffed_mark/Run()
	TEST_ASSERT(make_room(10, 5), "No room for the test")
	var/mob/living/carbon/human/npc/guard = guard_at(3, 2)
	var/mob/living/carbon/human/person = person_at(5, 2)
	var/datum/ai_controller/basic_controller/human_npc/stealth/stealth_ai = wake(guard)
	stealth_ai.stealth_go_alert(person)
	var/deadline = world.time + 10 SECONDS
	while(isnull(stealth_ai.meter?.mark) && world.time < deadline)
		sleep(1)
	TEST_ASSERT_NOTNULL(stealth_ai.meter?.mark, "An alert guard with someone beside it has no mark")
	var/obj/effect/abstract/stealth_mark/mark = stealth_ai.meter.mark
	TEST_ASSERT(mark in guard.vis_contents, "The mark isn't drawn on the guard")
	guard.set_handcuffed(new /obj/item/restraints/handcuffs(guard))
	guard.update_handcuffed()
	TEST_ASSERT(HAS_TRAIT(guard, TRAIT_RESTRAINED), "The cuffs didn't go on")
	deadline = world.time + 5 SECONDS
	while(!isnull(stealth_ai.meter) && world.time < deadline)
		sleep(1)
	TEST_ASSERT_NULL(stealth_ai.meter, "A cuffed guard kept its mark")
	TEST_ASSERT(!(mark in guard.vis_contents), "A cuffed guard still draws its mark")
	// Hitting it while it is cuffed doesn't bring the mark back.
	SEND_SIGNAL(guard, COMSIG_ATOM_WAS_ATTACKED, person, ATTACKER_DAMAGING_ATTACK)
	var/came_back = FALSE
	deadline = world.time + 3 SECONDS
	while(world.time < deadline)
		if(stealth_ai.meter)
			came_back = TRUE
		sleep(1)
	TEST_ASSERT(!came_back, "A mark came back over a cuffed guard")

#undef STEALTH_TEST_GUARD
