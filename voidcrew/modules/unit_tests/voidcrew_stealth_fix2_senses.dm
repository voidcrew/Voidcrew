// Stealth guards: second round of fixes to what guards hear and where players hide (stealth_noise.dm,
// stealth_noise_sources.dm, stealth_hearing.dm, stealth_cover.dm, stealth_doors.dm). Unit tests compile before
// voidcrew/_DEFINES, so values from there are written out: noise kinds "gun_pistol", "bash", "door", "thud",
// "blast", "glass", "thrown"; STEALTH_NOISE_RANGE_BLAST 14; a running step barefoot on plain floor carries 3. The
// helpers are in voidcrew_stealth.dm, voidcrew_stealth_hearing.dm and voidcrew_stealth_hostage.dm.

#define STEALTH_FIX2_GUARD /mob/living/carbon/human/npc/ruin/trooper/scav

/// Hearing a noise on a planet only reads the planet's shared air: the turf keeps it, it gets no air of its own.
/datum/unit_test/voidcrew_stealth_fix2_planet_air

/datum/unit_test/voidcrew_stealth_fix2_planet_air/Run()
	if(!planetary_atmos_shared_mix_enabled())
		return
	var/datum/turf_reservation/block = stealth_block(3, 1)
	TEST_ASSERT_NOTNULL(block, "No room for the test")
	var/turf/open/spot = stealth_at(block, 1, 0)
	spot.ChangeTurf(/turf/open/misc/dirt/dry, flags = CHANGETURF_IGNORE_AIR)
	spot = stealth_at(block, 1, 0)
	var/datum/gas_mixture/shared = GLOB.planetary_shared_turf_air[OPENTURF_DEFAULT_ATMOS]
	TEST_ASSERT_NOTNULL(shared, "Test fixture: no shared planet air")
	TEST_ASSERT(spot.air == shared, "Test fixture: the dirt isn't on the shared planet air")
	TEST_ASSERT(stealth_noise_carries(spot), "Planet air doesn't carry a noise")
	TEST_ASSERT(stealth_air_carry(spot, spot) > 0.95, "Planet air at one atmosphere thins a noise")
	TEST_ASSERT(spot.air == shared, "Hearing a noise gave a planet turf air of its own")

/// Thin air carries a gunshot and a running step less far, as tg plays them to players; at one atmosphere nothing
/// changes, and in a vacuum nothing carries.
/datum/unit_test/voidcrew_stealth_live/hear/fix2_thin_air

/datum/unit_test/voidcrew_stealth_live/hear/fix2_thin_air/Run()
	TEST_ASSERT(hear_room(12, 3), "No room for the test")
	var/mob/living/carbon/human/npc/guard = sentry(6, 1, WEST)
	var/datum/ai_controller/basic_controller/human_npc/stealth/guard_ai = guard.ai_controller
	var/mob/living/carbon/human/shooter = person_at(1, 1, FALSE)
	var/mob/living/carbon/human/runner = person_at(9, 1, FALSE)
	TEST_ASSERT(stealth_air_carry(at(1, 1), at(6, 1)) > 0.95, "Full air thins a noise")
	// Full air: a running step 2 tiles behind and a pistol 5 tiles off are heard.
	stealth_scans(guard, 1)
	runner.toggle_move_intent()
	runner.forceMove(at(8, 1))
	stealth_scans(guard, 1)
	TEST_ASSERT_EQUAL(guard_ai.last_heard?[1], "footsteps", "A running step 2 tiles behind wasn't heard in full air")
	settle(guard)
	guard_ai.group.forget_noises()
	TEST_ASSERT_EQUAL(stealth_noise(at(1, 1), "gun_pistol", null, shooter), 1, "A pistol 5 tiles off wasn't heard in full air")
	settle(guard)
	guard_ai.group.forget_noises()
	// A quarter of an atmosphere in the whole room: neither carries that far.
	var/turf/corner = room.bottom_left_turfs[1]
	var/turf/far_corner = room.top_right_turfs[1]
	for(var/turf/open/spot in block(corner.x, corner.y, corner.z, far_corner.x, far_corner.y, corner.z))
		spot.air.remove_ratio(0.75)
	var/thin = stealth_air_carry(at(1, 1), at(6, 1))
	TEST_ASSERT(thin > 0 && thin < 0.3, "A quarter of an atmosphere carries [thin] of a noise's reach")
	TEST_ASSERT_EQUAL(stealth_noise(at(1, 1), "gun_pistol", null, shooter), 0, "A pistol 5 tiles off was heard in thin air")
	guard_ai.last_heard = null
	runner.forceMove(at(9, 1))
	stealth_scans(guard, 1)
	guard_ai.last_heard = null
	runner.forceMove(at(8, 1))
	stealth_scans(guard, 1)
	TEST_ASSERT_NULL(guard_ai.last_heard, "A running step 2 tiles behind was heard in thin air")
	// No air at all on the far side.
	var/turf/open/far_spot = at(9, 1)
	far_spot.air.remove_ratio(1)
	TEST_ASSERT_EQUAL(stealth_air_carry(at(6, 1), far_spot), 0, "A vacuum carries a noise")
	no_targets(list(guard))

/// Foliage hides someone only where it grew: dug up it is no cover, planted back in its hole it is, planted anywhere
/// else it isn't.
/datum/unit_test/voidcrew_stealth_fix2_dug_bush

/datum/unit_test/voidcrew_stealth_fix2_dug_bush/Run()
	var/datum/turf_reservation/block = stealth_block(3, 1)
	TEST_ASSERT_NOTNULL(block, "No room for the test")
	var/turf/hole = stealth_at(block, 0, 0)
	var/turf/elsewhere = stealth_at(block, 2, 0)
	var/obj/structure/flora/bush/jungle/bush = allocate(/obj/structure/flora/bush/jungle, hole)
	TEST_ASSERT_EQUAL(stealth_cover_at(hole), bush, "A jungle bush isn't cover")
	bush.uproot()
	TEST_ASSERT_NULL(stealth_cover_at(hole), "A dug up bush is cover")
	bush.replant()
	TEST_ASSERT_EQUAL(stealth_cover_at(hole), bush, "A bush planted back in its own hole isn't cover")
	bush.uproot()
	bush.forceMove(elsewhere)
	TEST_ASSERT_NULL(stealth_cover_at(elsewhere), "A dug up bush dragged off is cover")
	bush.replant()
	TEST_ASSERT(bush.anchored, "Test fixture: the bush wasn't planted back")
	TEST_ASSERT_NULL(stealth_cover_at(elsewhere), "A bush planted somewhere new is cover")

/// Someone holding a guard up in front of them in a bush is not hidden by it; let go, they are.
/datum/unit_test/voidcrew_stealth_fix2_cover_hostage

/datum/unit_test/voidcrew_stealth_fix2_cover_hostage/Run()
	var/datum/turf_reservation/block = stealth_block(4, 1)
	TEST_ASSERT_NOTNULL(block, "No room for the test")
	var/turf/bush_tile = stealth_at(block, 1, 0)
	allocate(/obj/structure/flora/bush/jungle, bush_tile)
	stealth_ground(bush_tile)
	stealth_ground(stealth_at(block, 2, 0))
	var/mob/living/carbon/human/holder = stealth_person(block, 1, 0)
	var/obj/item/gun/ballistic/automatic/pistol/pistol = allocate(/obj/item/gun/ballistic/automatic/pistol, bush_tile)
	holder.put_in_hands(pistol)
	var/mob/living/carbon/human/npc/hostage = allocate(STEALTH_FIX2_GUARD, stealth_at(block, 2, 0))
	holder.stealth_moved_at = world.time - 10 SECONDS
	TEST_ASSERT(stealth_in_cover(holder, bush_tile), "Test fixture: someone keeping still in a bush isn't in cover")
	stealth_test_grab(holder, hostage, GRAB_NECK)
	if(hostage.loc != holder.loc)
		hostage.forceMove(holder.loc)
	TEST_ASSERT_EQUAL(stealth_held_in_front(holder), hostage, "Test fixture: the hostage isn't held up in front")
	holder.stealth_moved_at = world.time - 10 SECONDS
	TEST_ASSERT(!stealth_in_cover(holder, bush_tile), "Someone holding a guard up in front of them is hidden in a bush")
	holder.stop_pulling()
	TEST_ASSERT(stealth_in_cover(holder, bush_tile), "Someone in a bush who let go of their hostage isn't hidden again")

/**
 * A door is theirs only when one of them works it: a guard who merely stands beside it hears and sees it like anyone,
 * a forced door beside him is heard, and a stunned or floored one opens nothing for the rest. A wooden door left
 * open by a guard and shut by someone else is someone else's; an airlock shutting by itself is still theirs.
 */
/datum/unit_test/voidcrew_stealth_live/hear/fix2_door_user

/datum/unit_test/voidcrew_stealth_live/hear/fix2_door_user/Run()
	TEST_ASSERT(hear_room(20, 5), "No room for the test")
	var/mob/living/carbon/human/npc/watcher = sentry(2, 2, EAST)
	var/datum/ai_controller/basic_controller/human_npc/stealth/watcher_ai = watcher.ai_controller
	var/datum/stealth_group/group = watcher_ai.group
	var/obj/machinery/door/poddoor/shutters/shutter = allocate(/obj/machinery/door/poddoor/shutters, at(8, 2))
	// A sentry beside the door with its back to it.
	var/mob/living/carbon/human/npc/bystander = sentry(9, 2, EAST)
	var/datum/ai_controller/basic_controller/human_npc/stealth/bystander_ai = bystander.ai_controller
	// tg's own door procs name who works it.
	shutter.try_to_activate_door(bystander)
	TEST_ASSERT_EQUAL(stealth_door_user(shutter), bystander, "Working a door doesn't name who worked it")
	shutter.stealth_user_at = -1
	TEST_ASSERT_NULL(stealth_door_user(shutter), "A door worked earlier still names who worked it")
	// Nobody of theirs works it: the watcher goes to look, the one beside it hears it.
	TEST_ASSERT_EQUAL(stealth_door_moved(shutter, TRUE), 1, "A door opened beside a guard who didn't touch it drew no look")
	TEST_ASSERT_EQUAL(bystander_ai.last_heard?[1], "door", "A guard beside a door someone else opened didn't hear it")
	settle(watcher)
	settle(bystander)
	group.forget_noises()
	bystander_ai.last_heard = null
	TEST_ASSERT(stealth_noise(shutter, "bash") > 0, "A door forced open beside a guard who didn't touch it wasn't heard")
	settle(watcher)
	settle(bystander)
	group.forget_noises()
	// The guard beside it works it: theirs.
	shutter.stealth_user_ref = WEAKREF(bystander)
	shutter.stealth_user_at = world.time
	TEST_ASSERT_EQUAL(stealth_door_moved(shutter, TRUE), 0, "A door one of them worked drew a look")
	TEST_ASSERT_EQUAL(watcher_ai.stealth_state(), "unaware", "A guard was suspicious of its friend's door")
	TEST_ASSERT_EQUAL(stealth_noise(shutter, "bash"), 0, "A door one of them worked was heard as forced")
	// The airlock shutting by itself after a friend opened it: still theirs.
	bystander.forceMove(at(15, 2))
	shutter.stealth_user_at = -1
	TEST_ASSERT_EQUAL(stealth_door_moved(shutter, FALSE), 0, "A door shutting by itself after a friend opened it drew a look")
	group.forget_noises()
	// A guard that can't stand works no door for the rest: floored, or paralysed.
	bystander.forceMove(at(9, 2))
	ADD_TRAIT(bystander, TRAIT_INCAPACITATED, TRAIT_SOURCE_UNIT_TESTS)
	TEST_ASSERT(!group.member_uses_door(bystander, at(8, 2), group.living_members()), "A paralysed guard works a door for the rest")
	REMOVE_TRAIT(bystander, TRAIT_INCAPACITATED, TRAIT_SOURCE_UNIT_TESTS)
	TEST_ASSERT(group.member_uses_door(bystander, at(8, 2), group.living_members()), "A guard no longer paralysed can't work a door")
	// Floored last: it lies there a moment after the trait goes.
	ADD_TRAIT(bystander, TRAIT_FLOORED, TRAIT_SOURCE_UNIT_TESTS)
	TEST_ASSERT(!group.member_uses_door(bystander, at(8, 2), group.living_members()), "A floored guard works a door for the rest")
	REMOVE_TRAIT(bystander, TRAIT_FLOORED, TRAIT_SOURCE_UNIT_TESTS)
	// A wooden door a guard opened and walked away from, shut by someone else: theirs no longer.
	var/obj/structure/mineral_door/wood/wood = allocate(/obj/structure/mineral_door/wood, at(5, 3))
	wood.stealth_user_ref = WEAKREF(bystander)
	wood.stealth_user_at = world.time
	bystander.forceMove(at(5, 4))
	TEST_ASSERT_EQUAL(stealth_door_moved(wood, TRUE), 0, "A wooden door one of them opened drew a look")
	bystander.forceMove(at(15, 4))
	wood.stealth_user_at = -1
	TEST_ASSERT_EQUAL(stealth_door_moved(wood, FALSE), 1, "A wooden door shut by someone after a guard left it open drew no look")
	no_targets(list(watcher, bystander))

/// A guard going down on its own slip makes no thud for its friends; knocked down by something else, it does.
/datum/unit_test/voidcrew_stealth_live/hear/fix2_slip_thud

/datum/unit_test/voidcrew_stealth_live/hear/fix2_slip_thud/Run()
	TEST_ASSERT(hear_room(12, 3), "No room for the test")
	ground()
	var/mob/living/carbon/human/npc/faller = sentry(4, 1, EAST)
	var/datum/ai_controller/basic_controller/human_npc/stealth/faller_ai = faller.ai_controller
	var/mob/living/carbon/human/npc/friend = sentry(6, 1, WEST)
	var/datum/ai_controller/basic_controller/human_npc/stealth/friend_ai = friend.ai_controller
	var/turf/floor = get_turf(faller)
	faller_ai.slipped_at = world.time
	floor.handle_fall(faller)
	TEST_ASSERT_NULL(friend_ai.last_heard, "A guard's own slip thudded for its friends")
	TEST_ASSERT_EQUAL(length(friend_ai.group.lures), 0, "A guard's own slip counted as a lure")
	faller_ai.slipped_at = -1
	floor.handle_fall(faller)
	TEST_ASSERT_EQUAL(friend_ai.last_heard?[1], "thud", "A guard knocked down by something else made no thud")
	no_targets(list(faller, friend))

/// A blast carries as far as tg plays it to players: a small pop only to its range plus the view, a big one to 14.
/datum/unit_test/voidcrew_stealth_live/hear/fix2_blast_reach

/datum/unit_test/voidcrew_stealth_live/hear/fix2_blast_reach/Run()
	TEST_ASSERT(hear_room(16, 3), "No room for the test")
	var/mob/living/carbon/human/npc/guard = sentry(14, 1, WEST)
	var/datum/ai_controller/basic_controller/human_npc/stealth/guard_ai = guard.ai_controller
	TEST_ASSERT_EQUAL(stealth_blast_reach(0, 0, 0, 0, 1), round(1 + world.view - 2, 1), "A small blast's reach isn't tg's near sound range")
	TEST_ASSERT_EQUAL(stealth_blast_reach(1, 2, 1, 2, 3), 14, "A heavy blast doesn't carry 14")
	// 13 tiles off: a light pop isn't heard, a heavy blast is.
	guard_ai.group.on_explosion(null, at(1, 1), 0, 0, 1, 0, 0, 0, 1)
	TEST_ASSERT_NULL(guard_ai.last_heard, "A small blast 13 tiles off was heard")
	guard_ai.group.on_explosion(null, at(1, 1), 1, 2, 3, 0, 1, 2, 3)
	TEST_ASSERT_EQUAL(guard_ai.last_heard?[1], "blast", "A heavy blast 13 tiles off wasn't heard")
	no_targets(list(guard))

/// Foliage costs nothing where no guards are: no rustle there. Where they are, a step onto it rustles as before.
/datum/unit_test/voidcrew_stealth_live/hear/fix2_guards_about

/datum/unit_test/voidcrew_stealth_live/hear/fix2_guards_about/Run()
	TEST_ASSERT(hear_room(6, 3), "No room for the test")
	sentry(0, 0, EAST)
	var/datum/turf_reservation/block = stealth_block(3, 1)
	TEST_ASSERT_NOTNULL(block, "No room for the test")
	var/turf/away = stealth_at(block, 1, 0)
	TEST_ASSERT(stealth_guards_about(at(4, 1)), "No guards about in their own room")
	TEST_ASSERT(!stealth_guards_about(away), "Guards about somewhere with none")
	allocate(/obj/structure/flora/bush/jungle, away)
	allocate(/obj/structure/flora/bush/jungle, at(4, 1))
	var/mob/living/carbon/human/stranger = person_at(4, 2, FALSE)
	stranger.forceMove(away)
	stranger.stealth_cover_step()
	TEST_ASSERT_EQUAL(stranger.stealth_rustle_at, 0, "A step onto foliage with no guards about rustled")
	stranger.forceMove(at(4, 1))
	stranger.stealth_cover_step()
	TEST_ASSERT(stranger.stealth_rustle_at > world.time, "A step onto foliage in the guards' room didn't rustle")

/// A mob tg plays no footsteps for makes none for guards; one it does, does.
/datum/unit_test/voidcrew_stealth_fix2_beast_steps

/datum/unit_test/voidcrew_stealth_fix2_beast_steps/Run()
	var/datum/turf_reservation/block = stealth_block(3, 1)
	TEST_ASSERT_NOTNULL(block, "No room for the test")
	stealth_ground(stealth_at(block, 0, 0))
	stealth_ground(stealth_at(block, 2, 0))
	var/mob/living/basic/pig/pig = allocate(/mob/living/basic/pig, stealth_at(block, 0, 0))
	var/mob/living/basic/deer/deer = allocate(/mob/living/basic/deer, stealth_at(block, 2, 0))
	TEST_ASSERT(!stealth_has_footsteps(pig), "Test fixture: tg plays footsteps for a pig")
	TEST_ASSERT_EQUAL(stealth_footstep_reach(pig), 0, "A pig with no footsteps in tg makes some for guards")
	TEST_ASSERT(stealth_has_footsteps(deer), "Test fixture: tg plays no footsteps for a deer")
	TEST_ASSERT_EQUAL(stealth_footstep_reach(deer), 3, "A deer's steps don't carry 3")

/// A glass slid down the bar by a bartender doesn't smash in tg, so it only lands.
/datum/unit_test/voidcrew_stealth_fix2_glass_slide

/datum/unit_test/voidcrew_stealth_fix2_glass_slide/Run()
	var/datum/turf_reservation/block = stealth_block(3, 1)
	TEST_ASSERT_NOTNULL(block, "No room for the test")
	var/turf/landing = stealth_at(block, 2, 0)
	var/mob/living/carbon/human/thrower = stealth_person(block, 0, 0)
	var/obj/item/reagent_containers/cup/glass/bottle/beer/bottle = allocate(/obj/item/reagent_containers/cup/glass/bottle/beer, stealth_at(block, 1, 0))
	var/datum/thrownthing/throwing = new(bottle, landing, EAST, 5, 1, thrower)
	TEST_ASSERT_EQUAL(bottle.stealth_throw_kind(landing, throwing), "glass", "A thrown glass bottle doesn't smash as glass")
	ADD_TRAIT(thrower, TRAIT_BOOZE_SLIDER, TRAIT_SOURCE_UNIT_TESTS)
	TEST_ASSERT_EQUAL(bottle.stealth_throw_kind(landing, throwing), "thrown", "A bottle a bartender slid smashes as glass")
	REMOVE_TRAIT(thrower, TRAIT_BOOZE_SLIDER, TRAIT_SOURCE_UNIT_TESTS)
	qdel(throwing)

#undef STEALTH_FIX2_GUARD
