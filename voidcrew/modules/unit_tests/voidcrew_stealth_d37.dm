// Stealth guards, owner decisions 37 (glass and doors) and 38 (skill by zone). voidcrew/modules/stealth/stealth_doors.dm,
// stealth_skill.dm, and the glass step in stealth_noise_sources.dm. Values from voidcrew/_DEFINES are written out:
// STEALTH_NOISE_RANGE_CRUNCH 4, STEALTH_DOOR_CUE_COOLDOWN 30 s, STEALTH_DOOR_CUE_MAX 2, STEALTH_DOOR_GUARD_MEMORY 20 s;
// ZONE_GREEN 1, ZONE_YELLOW 2, ZONE_RED 3. States and noise kinds are written as text.

/// Stepping on a shard, even at a walk: the guard in earshot goes to look. A guard's own step on one is nothing,
/// and a green guard's duller ear misses a crunch a yellow one hears.
/datum/unit_test/voidcrew_stealth_live/hear/glass_crunch

/datum/unit_test/voidcrew_stealth_live/hear/glass_crunch/Run()
	TEST_ASSERT(hear_room(20, 3), "No room for the test")
	var/mob/living/carbon/human/npc/guard = sentry(8, 1, EAST)
	var/datum/ai_controller/basic_controller/human_npc/stealth/guard_ai = guard.ai_controller
	var/obj/item/shard/shard = allocate(/obj/item/shard, at(5, 1))
	var/mob/living/carbon/human/walker = person_at(4, 1, FALSE)
	walker.equip_to_slot_or_del(new /obj/item/clothing/shoes/sneakers/black(walker), ITEM_SLOT_FEET)
	TEST_ASSERT_EQUAL(walker.move_intent, MOVE_INTENT_WALK, "The walker isn't walking")
	walker.forceMove(get_turf(shard))
	TEST_ASSERT_EQUAL(guard_ai.last_heard?[1], "crunch", "A guard 3 tiles off didn't hear a shard stepped on at a walk")
	TEST_ASSERT_EQUAL(guard_ai.stealth_state(), "suspicious", "A crunch didn't send the guard to look")
	no_targets(list(guard))
	// One of their own stepping on it.
	settle(guard)
	guard_ai.group.forget_noises()
	guard_ai.last_heard = null
	walker.forceMove(at(2, 0))
	var/mob/living/carbon/human/npc/friend = sentry(4, 1, EAST)
	friend.forceMove(get_turf(shard))
	TEST_ASSERT_NULL(guard_ai.last_heard, "A guard heard its friend step on glass")
	TEST_ASSERT_EQUAL(guard_ai.stealth_state(), "unaware", "A friend's crunch sent a guard to look")
	friend.forceMove(at(0, 0))
	// A bulb on the floor crunches too.
	var/obj/item/light/bulb/bulb = allocate(/obj/item/light/bulb, at(6, 2))
	walker.forceMove(get_turf(bulb))
	TEST_ASSERT_EQUAL(guard_ai.last_heard?[1], "crunch", "Stepping on a bulb wasn't heard")
	// A green guard 4 tiles off: 4 x 0.75 = 3, out of reach. A yellow one there hears it.
	settle(guard)
	guard_ai.group.forget_noises()
	guard_ai.last_heard = null
	guard_ai.stealth_force_skill(/datum/stealth_skill/green)
	walker.forceMove(at(3, 1))
	shard.forceMove(at(4, 1))
	walker.forceMove(at(4, 1))
	TEST_ASSERT_NULL(guard_ai.last_heard, "A green guard heard a crunch 4 tiles off")
	guard_ai.stealth_force_skill(/datum/stealth_skill/yellow)
	guard_ai.group.forget_noises()
	walker.forceMove(at(3, 1))
	walker.forceMove(at(4, 1))
	TEST_ASSERT_EQUAL(guard_ai.last_heard?[1], "crunch", "A yellow guard didn't hear a crunch 4 tiles off")

/// A door seen opening in a guard's cone makes it suspicious of its own side of the door; behind it, out of its
/// dark sight in the dark, or with one of their own beside the door, nothing; a door that keeps moving is throttled.
/datum/unit_test/voidcrew_stealth_live/hear/door_seen

/datum/unit_test/voidcrew_stealth_live/hear/door_seen/Run()
	TEST_ASSERT(hear_room(20, 5), "No room for the test")
	var/mob/living/carbon/human/npc/guard = sentry(2, 2, EAST)
	var/datum/ai_controller/basic_controller/human_npc/stealth/guard_ai = guard.ai_controller
	var/turf/door_spot = at(9, 2)
	var/obj/machinery/door/poddoor/shutters/shutter = allocate(/obj/machinery/door/poddoor/shutters, door_spot)
	TEST_ASSERT(shutter.density, "The shutter isn't shut")
	// Seven tiles ahead, lit, opened through tg's own open(): it goes to look at its side of it.
	INVOKE_ASYNC(shutter, TYPE_PROC_REF(/obj/machinery/door, open))
	TEST_ASSERT_EQUAL(guard_ai.stealth_state(), "suspicious", "A guard didn't react to a shutter opening in front of it")
	TEST_ASSERT_EQUAL(guard_ai.investigate_turf, at(8, 2), "It isn't going to its own side of the door")
	TEST_ASSERT(!guard_ai.suspicion_heard, "A door it saw counts as one it only heard")
	no_targets(list(guard))
	// The same door again at once: throttled, a glance at most.
	settle(guard)
	TEST_ASSERT_EQUAL(stealth_door_moved(shutter, FALSE), 0, "A door sent someone to look twice within 30 s")
	TEST_ASSERT_EQUAL(guard_ai.stealth_state(), "unaware", "A throttled door made a guard suspicious")
	// After the cooldown it works once more; then that door is ignored for the rest of 3 minutes.
	// (No forget_noises() here: it forgets doors too.)
	guard_ai.group.rewind(31 SECONDS)
	TEST_ASSERT_EQUAL(stealth_door_moved(shutter, TRUE), 1, "A door didn't draw a look after its cooldown")
	settle(guard)
	guard_ai.group.rewind(31 SECONDS)
	TEST_ASSERT_EQUAL(stealth_door_moved(shutter, FALSE), 0, "A door drew a third look within 3 minutes")
	guard_ai.group.rewind(3 MINUTES)
	TEST_ASSERT_EQUAL(stealth_door_moved(shutter, TRUE), 1, "A door was still ignored after 3 minutes")
	settle(guard)
	guard_ai.group.forget_noises()
	guard_ai.group.rewind(31 SECONDS)
	// Behind it: nothing.
	guard.setDir(WEST)
	TEST_ASSERT_EQUAL(stealth_door_moved(shutter, FALSE), 0, "A guard saw a door behind it")
	guard.setDir(EAST)
	// In the dark, 7 tiles off (past its dark sight of 4): nothing. 3 tiles off: it sees it.
	GLOB.stealth_test_dark_turfs[door_spot] = TRUE
	TEST_ASSERT_EQUAL(stealth_door_moved(shutter, TRUE), 0, "A guard saw a dark doorway 7 tiles off")
	guard.forceMove(at(6, 2))
	TEST_ASSERT_EQUAL(stealth_door_moved(shutter, FALSE), 1, "A guard didn't see a dark doorway 3 tiles off")
	GLOB.stealth_test_dark_turfs[door_spot] = FALSE
	no_targets(list(guard))

/// Their own doors: a door that moves with one of them beside it draws nobody, and neither does the close that
/// follows once that guard has walked on. A wooden door a player opens is seen and heard.
/datum/unit_test/voidcrew_stealth_live/hear/door_own

/datum/unit_test/voidcrew_stealth_live/hear/door_own/Run()
	TEST_ASSERT(hear_room(20, 5), "No room for the test")
	var/mob/living/carbon/human/npc/watcher = sentry(2, 2, EAST)
	var/datum/ai_controller/basic_controller/human_npc/stealth/watcher_ai = watcher.ai_controller
	var/obj/machinery/door/poddoor/shutters/shutter = allocate(/obj/machinery/door/poddoor/shutters, at(8, 2))
	var/mob/living/carbon/human/npc/passer = sentry(9, 2, WEST)
	TEST_ASSERT_EQUAL(stealth_door_moved(shutter, TRUE), 0, "A door one of them stood beside drew a look")
	TEST_ASSERT_EQUAL(watcher_ai.stealth_state(), "unaware", "A guard was suspicious of its friend's door")
	TEST_ASSERT_EQUAL(watcher_ai.glance_until, 0, "A guard glanced at its friend's door")
	passer.forceMove(at(15, 2))
	TEST_ASSERT_EQUAL(stealth_door_moved(shutter, FALSE), 0, "The close after a friend's opening drew a look")
	TEST_ASSERT_EQUAL(watcher_ai.stealth_state(), "unaware", "A guard was suspicious of its friend's door shutting itself")
	// Long after that, a close with nobody beside it is someone else's.
	watcher_ai.group.rewind(21 SECONDS)
	TEST_ASSERT_EQUAL(stealth_door_moved(shutter, TRUE), 1, "A door with nobody beside it drew no look")
	settle(watcher)
	watcher_ai.group.forget_noises()
	// A wooden door, opened through tg's own Open().
	var/obj/structure/mineral_door/wood/wood = allocate(/obj/structure/mineral_door/wood, at(6, 3))
	INVOKE_ASYNC(wood, TYPE_PROC_REF(/obj/structure/mineral_door, Open))
	TEST_ASSERT_EQUAL(watcher_ai.stealth_state(), "suspicious", "A guard didn't react to a wooden door opening in front of it")
	TEST_ASSERT_EQUAL(watcher_ai.last_heard?[1], "door", "A wooden door made no noise")
	no_targets(list(watcher, passer))

/// The skill profile: yellow is today's tuning; zone, mapper and admin pick it in that order of strength.
/datum/unit_test/voidcrew_stealth_skill

/datum/unit_test/voidcrew_stealth_skill/Run()
	var/datum/stealth_skill/yellow = stealth_skill_of(/datum/stealth_skill/yellow)
	// The numbers the den was tuned on (STEALTH_SIGHT_RANGE, STEALTH_CONE_HALF_ANGLE, ... in _DEFINES/stealth.dm).
	TEST_ASSERT_EQUAL(yellow.sight_range, 8, "Yellow sight range changed")
	TEST_ASSERT_EQUAL(yellow.alert_max_range, 7, "Yellow alert range changed")
	TEST_ASSERT_EQUAL(yellow.dark_sight_range, 4, "Yellow dark sight changed")
	TEST_ASSERT_EQUAL(yellow.cone_half_angle, 60, "Yellow cone changed")
	TEST_ASSERT_EQUAL(yellow.wary_half_angle, 75, "Yellow wary cone changed")
	TEST_ASSERT_EQUAL(yellow.search_half_angle, 90, "Yellow search cone changed")
	TEST_ASSERT_EQUAL(yellow.notice_rate, 1, "Yellow notice rate changed")
	TEST_ASSERT_EQUAL(yellow.point_blank_range, 2, "Yellow point-blank range changed")
	TEST_ASSERT_EQUAL(yellow.near_range, 4, "Yellow near range changed")
	TEST_ASSERT_EQUAL(yellow.near_mult, 3, "Yellow near multiplier changed")
	TEST_ASSERT_EQUAL(yellow.close_range, 2, "Yellow close range changed")
	TEST_ASSERT_EQUAL(yellow.hearing_mult, 1, "Yellow hearing changed")
	TEST_ASSERT_EQUAL(yellow.reaction_delay, 2 SECONDS, "Yellow reaction delay changed")
	TEST_ASSERT_EQUAL(yellow.search_time, 40 SECONDS, "Yellow search time changed")
	TEST_ASSERT_EQUAL(yellow.wary_time, 60 SECONDS, "Yellow wary time changed")
	// Every profile keeps decision 18 (no alert from off screen) and a cone that never takes in what is behind.
	for(var/skill_type in subtypesof(/datum/stealth_skill))
		var/datum/stealth_skill/profile = stealth_skill_of(skill_type)
		TEST_ASSERT(profile.alert_max_range <= 7, "[skill_type] goes alert from off screen")
		TEST_ASSERT(profile.search_half_angle <= 90, "[skill_type] searches with eyes in the back of its head")
		TEST_ASSERT(profile.sight_range <= 9, "[skill_type] sees past the range it gathers people from")
	// Zones.
	TEST_ASSERT_EQUAL(stealth_skill_type_for_zone(1), /datum/stealth_skill/green, "Green zone isn't green skill")
	TEST_ASSERT_EQUAL(stealth_skill_type_for_zone(2), /datum/stealth_skill/yellow, "Yellow zone isn't yellow skill")
	TEST_ASSERT_EQUAL(stealth_skill_type_for_zone(3), /datum/stealth_skill/red, "Red zone isn't red skill")
	TEST_ASSERT_EQUAL(stealth_skill_type_for_zone(null), /datum/stealth_skill/yellow, "An unknown zone isn't yellow")
	var/datum/turf_reservation/block = stealth_block(3, 3)
	TEST_ASSERT_NOTNULL(block, "No room for the test")
	// Reserved test space belongs to no zone: yellow.
	var/mob/living/carbon/human/npc/guard = allocate(/mob/living/carbon/human/npc/ruin/trooper/scav, stealth_at(block, 1, 1))
	var/datum/ai_controller/basic_controller/human_npc/stealth/stealth_ai = stealth_ai(guard)
	TEST_ASSERT_NULL(stealth_zone_of(get_turf(guard)), "Reserved test space belongs to a zone")
	TEST_ASSERT_EQUAL(stealth_ai.stealth_skill().name, "yellow", "A guard with no zone isn't yellow")
	// A spawner's pick reaches the guard and beats the zone.
	stealth_set_mapped_skill(/datum/stealth_skill/red, guard)
	TEST_ASSERT_EQUAL(guard.stealth_skill, /datum/stealth_skill/red, "A spawner's skill didn't reach its guard")
	TEST_ASSERT_EQUAL(stealth_ai.stealth_skill().name, "red", "A mapped skill didn't beat the zone")
	// An admin's pick beats the mapper's, and lets go again.
	stealth_ai.stealth_force_skill(/datum/stealth_skill/green)
	TEST_ASSERT_EQUAL(stealth_ai.stealth_skill().name, "green", "An admin's skill didn't beat the mapper's")
	stealth_set_mapped_skill(/datum/stealth_skill/red, guard)
	TEST_ASSERT_EQUAL(stealth_ai.stealth_skill().name, "green", "A mapper's skill overrode an admin's")
	stealth_ai.stealth_force_skill(null)
	TEST_ASSERT_EQUAL(stealth_ai.stealth_skill().name, "red", "Clearing an admin's skill didn't go back to the mapper's")
	// A spawner hands its pick over without a reference to itself. (The family root places nothing.)
	var/obj/effect/spawner/human_npc/spawner = new(stealth_at(block, 0, 0))
	spawner.stealth_skill = /datum/stealth_skill/green
	var/datum/callback/handover = spawner.npc_spawned_callback()
	TEST_ASSERT_NOTNULL(handover, "A spawner with a skill hands nothing over")
	TEST_ASSERT(handover.object == GLOBAL_PROC, "The spawner's handover holds the spawner")
	spawner.stealth_skill = null
	TEST_ASSERT_NULL(spawner.npc_spawned_callback(), "A spawner without a skill hands something over")
	if(!QDELETED(spawner))
		qdel(spawner)
	qdel(guard)
	qdel(block)

/// The knobs reach the guard: green is narrower, shorter-sighted, no instant alert at 2 tiles, gives up sooner.
/datum/unit_test/voidcrew_stealth_skill_knobs

/datum/unit_test/voidcrew_stealth_skill_knobs/Run()
	var/datum/turf_reservation/block = stealth_block(14, 7)
	TEST_ASSERT_NOTNULL(block, "No room for the test")
	var/mob/living/carbon/human/person = stealth_person(block, 0, 0)
	var/mob/living/carbon/human/npc/guard = stealth_guard(block, 2, 3)
	var/datum/ai_controller/basic_controller/human_npc/stealth/stealth_ai = stealth_ai(guard)
	// Cone: two ahead and three aside is 56 degrees off its facing.
	var/turf/aside = stealth_at(block, 4, 6)
	TEST_ASSERT(stealth_in_cone(guard, aside, stealth_ai.stealth_half_angle()), "56 degrees is outside a yellow cone")
	stealth_ai.stealth_force_skill(/datum/stealth_skill/green)
	TEST_ASSERT(!stealth_in_cone(guard, aside, stealth_ai.stealth_half_angle()), "56 degrees is inside a green cone")
	TEST_ASSERT_EQUAL(stealth_ai.stealth_range_onto(aside), 7, "A green guard's sight isn't 7")
	// Eight ahead in the light: a yellow guard notices, a green one doesn't see that far.
	person.forceMove(stealth_at(block, 10, 3))
	stealth_scans(guard, 1)
	TEST_ASSERT_NULL(stealth_ai.notice_map[REF(person)], "A green guard noticed someone 8 tiles off")
	stealth_ai.stealth_force_skill(/datum/stealth_skill/yellow)
	stealth_scans(guard, 1)
	TEST_ASSERT_NOTNULL(stealth_ai.notice_map[REF(person)], "A yellow guard didn't notice someone 8 tiles off")
	qdel(guard)
	// Two ahead in the light: yellow is an alert on that look; green is not (its point-blank is 1).
	person.forceMove(stealth_at(block, 4, 3))
	guard = stealth_guard(block, 2, 3)
	stealth_ai = stealth_ai(guard)
	stealth_ai.stealth_force_skill(/datum/stealth_skill/green)
	stealth_scans(guard, 1)
	TEST_ASSERT(stealth_ai.stealth_state() != "alert", "A green guard went alert at once at 2 tiles")
	qdel(guard)
	guard = stealth_guard(block, 2, 3)
	stealth_ai = stealth_ai(guard)
	stealth_scans(guard, 1)
	TEST_ASSERT_EQUAL(stealth_ai.stealth_state(), "alert", "A yellow guard didn't go alert at once at 2 tiles")
	stealth_ai.clear_blackboard_key(BB_BASIC_MOB_CURRENT_TARGET)
	qdel(guard)
	// Search length: 30 s in, a green search is over and a yellow one isn't.
	person.forceMove(stealth_at(block, 0, 0))
	guard = stealth_guard(block, 12, 3, WEST)
	stealth_ai = stealth_ai(guard)
	stealth_scans(guard, 1)
	stealth_ai.stealth_go_searching(stealth_at(block, 10, 3))
	stealth_ai.stealth_rewind(30 SECONDS)
	stealth_scans(guard, 1)
	TEST_ASSERT_EQUAL(stealth_ai.stealth_state(), "searching", "A yellow search ended within 30 s")
	stealth_ai.stealth_force_skill(/datum/stealth_skill/green)
	stealth_scans(guard, 1)
	TEST_ASSERT_EQUAL(stealth_ai.stealth_state(), "unaware", "A green search didn't end by 30 s")
	qdel(guard)
	qdel(block)
