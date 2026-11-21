// Stealth guards: fixes to what guards hear and where players hide (stealth_cover.dm, stealth_noise.dm,
// stealth_noise_sources.dm, stealth_closet.dm). Unit tests compile before voidcrew/_DEFINES, so values from there are
// written out: STEALTH_COVER_SETTLE 1 s, noise kinds "thrown", "impact", "voice", "door". The helpers are in
// voidcrew_stealth.dm and voidcrew_stealth_hearing.dm.

#define STEALTH_FIX_LOOKOUT /mob/living/carbon/human/npc/ruin/trooper/scav/lookout

/// Cover: a shot shows the shooter lying down too; a lit light they carry shows them; a dead potted plant of any kind
/// hides nobody.
/datum/unit_test/voidcrew_stealth_fix_cover

/datum/unit_test/voidcrew_stealth_fix_cover/Run()
	var/datum/turf_reservation/block = stealth_block(12, 3)
	TEST_ASSERT_NOTNULL(block, "No room for the test")
	var/turf/far = stealth_at(block, 8, 1)
	allocate(/obj/structure/flora/bush/jungle, far)
	var/mob/living/carbon/human/person = stealth_person(block, 8, 1)
	person.stealth_moved_at = world.time - 10 SECONDS
	// A lit flashlight in hand, 6 tiles in front of a guard.
	var/mob/living/carbon/human/npc/guard = stealth_guard(block, 2, 1)
	var/datum/ai_controller/basic_controller/human_npc/stealth/stealth_ai = stealth_ai(guard)
	TEST_ASSERT(stealth_ai.stealth_covered(person, far, 6), "Someone keeping still in cover 6 tiles off isn't covered")
	var/obj/item/flashlight/held = allocate(/obj/item/flashlight, far)
	TEST_ASSERT(person.put_in_hands(held), "Test fixture: the flashlight can't be held")
	held.attack_self(person)
	TEST_ASSERT(held.light_on, "Test fixture: the flashlight didn't switch on")
	TEST_ASSERT(!stealth_ai.stealth_covered(person, far, 6), "Cover hid someone holding a lit flashlight")
	stealth_scans(guard, 10)
	TEST_ASSERT(stealth_ai.stealth_state() != "unaware", "A guard never noticed someone in cover with a lit flashlight 6 tiles in front")
	qdel(guard)
	qdel(held)
	// Lying still in it, then firing from it lying down.
	person.stealth_moved_at = world.time - 10 SECONDS
	person.set_body_position(LYING_DOWN)
	TEST_ASSERT(stealth_in_cover(person, far), "Someone lying still in a jungle bush isn't in cover")
	var/obj/item/gun/ballistic/automatic/pistol/pistol = allocate(/obj/item/gun/ballistic/automatic/pistol, far)
	TEST_ASSERT(person.put_in_active_hand(pistol), "Test fixture: the pistol can't be held")
	pistol.shoot_live_shot(person)
	TEST_ASSERT(!stealth_in_cover(person, far), "Someone lying in cover stayed hidden as they fired")
	person.stealth_shot_at = world.time - 10 SECONDS
	person.stealth_moved_at = world.time - 10 SECONDS
	TEST_ASSERT(stealth_in_cover(person, far), "A shot long ago still shows the shooter")
	person.set_body_position(STANDING_UP)
	// A plain potted plant gone dead on its mapped tile.
	var/turf/plant_tile = stealth_at(block, 10, 2)
	var/obj/item/kirbyplants/plant = allocate(/obj/item/kirbyplants, plant_tile)
	plant.stealth_cover_spot = plant_tile
	TEST_ASSERT_EQUAL(stealth_cover_at(plant_tile), plant, "A potted plant on its mapped tile isn't cover")
	plant.dead = TRUE
	TEST_ASSERT_NULL(stealth_cover_at(plant_tile), "A dead potted plant is cover")
	qdel(block)

/// Thrown things and stray rounds are heard from where tg plays them: the thrower's side of the wall they hit. (A coin,
/// which tg lands in silence, is covered by hear/real_throw no longer using one.)
/datum/unit_test/voidcrew_stealth_live/hear/fix_wall_hits

/datum/unit_test/voidcrew_stealth_live/hear/fix_wall_hits/Run()
	TEST_ASSERT(hear_room(20, 5), "No room for the test")
	for(var/dy in 0 to 4)
		var/turf/wall_spot = at(10, dy)
		wall_spot.ChangeTurf(/turf/closed/wall)
	// A sharp ear two tiles behind the wall, facing it (the player who keeps the level awake is behind it).
	var/mob/living/carbon/human/npc/guard = sentry(12, 2, WEST, STEALTH_FIX_LOOKOUT)
	var/datum/ai_controller/basic_controller/human_npc/stealth/guard_ai = guard.ai_controller
	var/mob/living/carbon/human/thrower = person_at(5, 2, FALSE)
	var/obj/item/restraints/handcuffs/cuffs = allocate(/obj/item/restraints/handcuffs, get_turf(thrower))
	cuffs.throw_at(at(10, 2), 12, 2, thrower)
	var/deadline = world.time + 5 SECONDS
	while(cuffs.throwing && world.time < deadline)
		sleep(1)
	TEST_ASSERT_EQUAL(get_turf(cuffs), at(9, 2), "Test fixture: the handcuffs didn't stop at the wall")
	TEST_ASSERT_EQUAL(guard_ai.stealth_state(), "unaware", "A guard behind a wall heard handcuffs land on the far side of it")
	TEST_ASSERT(guard_ai.last_heard?[1] != "thrown", "A guard behind a wall heard a landing it couldn't")
	// A round striking the wall: tg plays it from the round, on the shooter's side.
	settle(guard)
	guard_ai.group.forget_noises()
	var/obj/projectile/bullet/round = allocate(/obj/projectile/bullet, at(9, 2))
	round.firer = thrower
	round.on_hit(at(10, 2))
	TEST_ASSERT_EQUAL(guard_ai.stealth_state(), "unaware", "A guard behind a wall heard a round strike the far side of it")
	TEST_ASSERT(guard_ai.last_heard?[1] != "impact", "A guard behind a wall heard an impact it couldn't")

/// An emote's sound reaches only those in view of it, as tg plays it: a whistle behind a wall isn't heard.
/datum/unit_test/voidcrew_stealth_live/hear/fix_emote_wall

/datum/unit_test/voidcrew_stealth_live/hear/fix_emote_wall/Run()
	TEST_ASSERT(hear_room(20, 5), "No room for the test")
	for(var/dy in 0 to 4)
		var/turf/wall_spot = at(10, dy)
		wall_spot.ChangeTurf(/turf/closed/wall)
	var/mob/living/carbon/human/npc/guard = sentry(11, 2, WEST, STEALTH_FIX_LOOKOUT)
	var/datum/ai_controller/basic_controller/human_npc/stealth/guard_ai = guard.ai_controller
	var/mob/living/carbon/human/whistler = person_at(9, 2, FALSE)
	whistler.emote("whistle")
	TEST_ASSERT_EQUAL(guard_ai.stealth_state(), "unaware", "A guard heard a whistle through a wall")
	TEST_ASSERT(guard_ai.last_heard?[1] != "voice", "A guard heard a whistle through a wall")

/// A locker opened or shut near a guard is heard as a door: it glances. One of its own working one isn't remarked.
/datum/unit_test/voidcrew_stealth_live/hear/fix_closet_sound

/datum/unit_test/voidcrew_stealth_live/hear/fix_closet_sound/Run()
	TEST_ASSERT(hear_room(20, 5), "No room for the test")
	var/mob/living/carbon/human/npc/guard = sentry(10, 2, EAST)
	var/datum/ai_controller/basic_controller/human_npc/stealth/guard_ai = guard.ai_controller
	var/mob/living/carbon/human/sneak = person_at(8, 3, FALSE)
	var/obj/structure/closet/locker = allocate(/obj/structure/closet, at(8, 2))
	TEST_ASSERT(locker.open(sneak), "Test fixture: the locker didn't open")
	TEST_ASSERT_EQUAL(guard_ai.last_heard?[1], "door", "A guard 2 tiles from a locker opening didn't hear it")
	guard_ai.last_heard = null
	guard_ai.group.forget_noises()
	TEST_ASSERT(locker.close(sneak), "Test fixture: the locker didn't shut")
	TEST_ASSERT_EQUAL(guard_ai.last_heard?[1], "door", "A guard 2 tiles from a locker shutting didn't hear it")
	// One of its own.
	settle(guard)
	guard_ai.last_heard = null
	guard_ai.group.forget_noises()
	var/mob/living/carbon/human/npc/mate = sentry(8, 1, EAST)
	TEST_ASSERT(locker.open(mate), "Test fixture: the locker didn't open for a guard")
	TEST_ASSERT_NULL(guard_ai.last_heard, "A guard heard one of its own open a locker")

/// A door one of the group works is theirs, unless that one is a captive: cuffed or hands up under a gun.
/datum/unit_test/voidcrew_stealth_live/hear/fix_member_beside

/datum/unit_test/voidcrew_stealth_live/hear/fix_member_beside/Run()
	TEST_ASSERT(hear_room(20, 5), "No room for the test")
	var/mob/living/carbon/human/npc/guard = sentry(8, 2, EAST)
	var/datum/ai_controller/basic_controller/human_npc/stealth/guard_ai = guard.ai_controller
	var/datum/stealth_group/group = guard_ai.group
	var/turf/door_spot = at(9, 2)
	TEST_ASSERT(group.member_uses_door(guard, door_spot, group.living_members()), "A free guard at a door doesn't count as using it")
	ADD_TRAIT(guard, TRAIT_RESTRAINED, TRAIT_SOURCE_UNIT_TESTS)
	TEST_ASSERT(!group.member_uses_door(guard, door_spot, group.living_members()), "A cuffed guard at a door makes it theirs")
	REMOVE_TRAIT(guard, TRAIT_RESTRAINED, TRAIT_SOURCE_UNIT_TESTS)
	var/mob/living/carbon/human/aimer = person_at(6, 2, FALSE)
	guard_ai.holdup_aimer = WEAKREF(aimer)
	TEST_ASSERT(!group.member_uses_door(guard, door_spot, group.living_members()), "A guard with its hands up at a door makes it theirs")
	guard_ai.holdup_aimer = null
	TEST_ASSERT(group.member_uses_door(guard, door_spot, group.living_members()), "A guard let go doesn't count as using a door again")

/// Small noises aren't alarms: lures don't thin out the answer to gunfire. And a louder noise of the same kind just
/// after a quiet one is heard, not folded into it.
/datum/unit_test/voidcrew_stealth_live/hear/fix_alarms

/datum/unit_test/voidcrew_stealth_live/hear/fix_alarms/Run()
	TEST_ASSERT(hear_room(20, 5), "No room for the test")
	var/mob/living/carbon/human/npc/guard = sentry(10, 2, EAST)
	var/datum/ai_controller/basic_controller/human_npc/stealth/guard_ai = guard.ai_controller
	var/datum/stealth_group/group = guard_ai.group
	var/mob/living/carbon/human/thrower = person_at(2, 2, FALSE)
	// Two lures at two spots (each one used to count half an alarm).
	group.forget_noises()
	TEST_ASSERT(stealth_noise(at(6, 2), "knock", null, thrower) > 0, "Test fixture: the first lure wasn't heard")
	settle(guard)
	TEST_ASSERT(stealth_noise(at(14, 2), "knock", null, thrower) > 0, "Test fixture: the second lure wasn't heard")
	TEST_ASSERT_EQUAL(group.alarm_count(), 0, "Lures counted as alarms")
	// A quiet landing, then a heavy one there a moment later.
	settle(guard)
	group.forget_noises()
	TEST_ASSERT(stealth_noise(at(8, 2), "thrown", 3, thrower) > 0, "Test fixture: the quiet landing wasn't heard")
	settle(guard)
	TEST_ASSERT(stealth_noise(at(8, 2), "thrown", 6, thrower) > 0, "A heavy landing just after a quiet one there wasn't heard")
	settle(guard)
	TEST_ASSERT_EQUAL(stealth_noise(at(8, 2), "thrown", 3, thrower), 0, "A quiet landing just after a heavy one there was heard again")

#undef STEALTH_FIX_LOOKOUT
