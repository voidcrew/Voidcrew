// Stealth guards (voidcrew/modules/stealth/). Unit tests compile before voidcrew/_DEFINES, so values from
// there are written out: states "unaware", "suspicious", "alert", "searching"; blackboard keys
// "stealth_state", "stealth_wary", "stealth_last_seen_turf"; STEALTH_PATROL_MAX_FAILS 3,
// STEALTH_LOSE_TARGET_TIME 4 s, STEALTH_SEARCH_TIME 40 s, STEALTH_CALM_LOOK_TIME 6 s, STEALTH_WARY_TIME 3 min.

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
	// In front, 2 tiles.
	guard = stealth_guard(block, 6, 2)
	stealth_ai = stealth_ai(guard)
	person.forceMove(stealth_at(block, 8, 2))
	stealth_scans(guard, 2)
	TEST_ASSERT_EQUAL(stealth_ai.stealth_state(), "suspicious", "A guard wasn't suspicious of someone 2 tiles in front after two scans")
	stealth_scans(guard, 2)
	TEST_ASSERT_EQUAL(stealth_ai.stealth_state(), "alert", "A guard wasn't alert on someone 2 tiles in front after four scans")
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
	TEST_ASSERT_EQUAL(stealth_ai.blackboard["stealth_last_seen_turf"], last_seen, "The search isn't at the last place it saw them")
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
	TEST_ASSERT_EQUAL(stealth_ai.blackboard["stealth_last_seen_turf"], get_turf(person), "The search isn't at the attacker's turf")
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
	// Someone behind it hit it during the fight: it turns on them.
	guard = stealth_guard(block, 6, 2)
	stealth_ai = stealth_ai(guard)
	target = stealth_person(block, 8, 2)
	var/mob/living/carbon/human/flanker = stealth_person(block, 3, 2)
	stealth_ai.stealth_go_alert(target)
	SEND_SIGNAL(guard, COMSIG_ATOM_WAS_ATTACKED, flanker, ATTACKER_DAMAGING_ATTACK)
	TEST_ASSERT_EQUAL(stealth_ai.blackboard[BB_BASIC_MOB_CURRENT_TARGET], target, "A hit from someone else pulled the guard off its target")
	target.death()
	stealth_scans(guard, 1)
	TEST_ASSERT_EQUAL(stealth_ai.stealth_state(), "alert", "A guard calmed down while someone else was hurting it")
	TEST_ASSERT_EQUAL(stealth_ai.blackboard[BB_BASIC_MOB_CURRENT_TARGET], flanker, "The guard didn't turn on whoever else hit it")
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
	stealth_ai.stealth_rewind(2 MINUTES)
	stealth_scans(guard, 1)
	TEST_ASSERT(stealth_ai.blackboard["stealth_wary"], "Wary faded too soon")
	// A glimpse of someone far off starts the clock again.
	var/mob/living/carbon/human/person = stealth_person(block, 9, 2)
	stealth_scans(guard, 1)
	TEST_ASSERT_EQUAL(stealth_ai.stealth_state(), "unaware", "A glimpse at the edge of sight made the guard suspicious")
	qdel(person)
	stealth_ai.stealth_rewind(2 MINUTES)
	stealth_scans(guard, 1)
	TEST_ASSERT(stealth_ai.blackboard["stealth_wary"], "A notice gain didn't refresh wary")
	stealth_ai.stealth_rewind(70 SECONDS)
	stealth_scans(guard, 1)
	TEST_ASSERT(!stealth_ai.blackboard["stealth_wary"], "Wary didn't fade with nothing new")
	TEST_ASSERT(stealth_ai.stealth_half_angle() == 60, "A guard no longer wary still has the wary cone")
	// A hit makes it wary again.
	var/mob/living/carbon/human/attacker = stealth_person(block, 11, 4)
	SEND_SIGNAL(guard, COMSIG_ATOM_WAS_ATTACKED, attacker, ATTACKER_DAMAGING_ATTACK)
	TEST_ASSERT(stealth_ai.blackboard["stealth_wary"], "A hit didn't make the guard wary again")
	qdel(block)

#undef STEALTH_TEST_GUARD
