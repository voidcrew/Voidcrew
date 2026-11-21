// Hostages, the hand over the mouth and hands up (voidcrew/modules/stealth/stealth_hostage.dm, stealth_hostage_pose.dm,
// stealth_grip.dm, stealth_holdup.dm): a held body stays on its holder's tile when others bump or shove it, who a
// standing-off guard turns on, what counts as an order to drop it, and the guard's move after a lapsed hold-up. Unit
// tests compile before voidcrew/_DEFINES, so values are written out: trait source "stealth_grip", state "alert".

/// Counts tg's grab signal and moves, and can refuse a pull, for the tests below.
/datum/hands_test_watch
	var/grabs = 0
	var/moves = 0

/datum/hands_test_watch/proc/on_grab(datum/source, mob/living/target)
	SIGNAL_HANDLER
	grabs++

/datum/hands_test_watch/proc/refuse_pull(datum/source, atom/movable/thing, force)
	SIGNAL_HANDLER
	return COMSIG_LIVING_CANCEL_PULL

/datum/hands_test_watch/proc/on_moved(datum/source)
	SIGNAL_HANDLER
	moves++

/// A standoff scene on row `y` of `block`: a guard at (8, y) facing west, `holder` at (2, y) holding a friend of the
/// guard's at gunpoint (pistol in the active hand), and another friend of theirs at (`fx`, `fy`). Returns
/// list(guard_ai, guard, holder, hostage, friend), or null if the fixture failed.
/datum/unit_test/proc/hands_scene(datum/turf_reservation/block, y, fx, fy)
	var/mob/living/carbon/human/npc/guard = stealth_guard(block, 8, y, WEST)
	var/mob/living/carbon/human/npc/hostage = stealth_guard(block, 3, y, WEST)
	var/mob/living/carbon/human/npc/friend = stealth_guard(block, fx, fy, WEST)
	var/mob/living/carbon/human/holder = stealth_person(block, 2, y)
	for(var/mob/living/body as anything in list(guard, hostage, friend))
		ADD_TRAIT(body, TRAIT_DESIGNATED_TARGET, TRAIT_SOURCE_UNIT_TESTS)
	var/datum/ai_controller/basic_controller/human_npc/stealth/guard_ai = stealth_test_standoff(guard, holder, hostage)
	if(!guard_ai)
		return null
	return list(guard_ai, guard, holder, hostage, friend)

/// Waits up to `limit` for `guard_ai` to stop standing off (a shot or a throw still in the air).
/datum/unit_test/proc/hands_wait_standoff_over(datum/ai_controller/basic_controller/human_npc/stealth/guard_ai, limit = 3 SECONDS)
	var/deadline = world.time + limit
	while(guard_ai.standoff_holder && world.time < deadline)
		sleep(world.tick_lag)

/// Deletes a scene's people so the next scene's attacks reach no standoff of this one.
/datum/unit_test/proc/hands_clear(list/scene, list/extra)
	for(var/i in 2 to length(scene))
		qdel(scene[i])
	for(var/thing in extra)
		qdel(thing)

/// A passer-by running into a holder (tg's mob swap) can't part him from the body he holds in front: he is pushed, the
/// body comes along, and the guard keeps standing off. Let go, the two can be swapped past again.
/datum/unit_test/voidcrew_stealth_hands_no_swap

/datum/unit_test/voidcrew_stealth_hands_no_swap/Run()
	var/datum/turf_reservation/block = stealth_block(12, 5)
	TEST_ASSERT_NOTNULL(block, "No room for the test")
	var/mob/living/carbon/human/npc/guard = stealth_guard(block, 10, 2, WEST)
	var/mob/living/carbon/human/npc/hostage = stealth_guard(block, 5, 2, WEST)
	var/mob/living/carbon/human/holder = stealth_person(block, 4, 2)
	var/datum/ai_controller/basic_controller/human_npc/stealth/guard_ai = stealth_test_standoff(guard, holder, hostage)
	if(!guard_ai)
		return
	TEST_ASSERT(HAS_TRAIT(holder, TRAIT_NOMOBSWAP) && HAS_TRAIT(hostage, TRAIT_NOMOBSWAP), "Held in front, the two can still be swapped past")
	var/mob/living/carbon/human/passer = stealth_person(block, 3, 2)
	if(passer.move_intent == MOVE_INTENT_WALK)
		passer.toggle_move_intent()
	passer.set_combat_mode(FALSE)
	passer.Move(get_step(passer, EAST), EAST)
	TEST_ASSERT(passer.loc != holder.loc, "The passer-by ended up on the holder's tile")
	stealth_test_check_held(holder, hostage, guard_ai, "bumped by a passer-by")
	holder.stop_pulling()
	TEST_ASSERT(!HAS_TRAIT(holder, TRAIT_NOMOBSWAP), "Let go, the holder still can't be swapped past")
	TEST_ASSERT(!HAS_TRAIT(hostage, TRAIT_NOMOBSWAP), "Let go, the body still can't be swapped past")
	qdel(block)

/// Someone else shoving the body held in front (tg's shove, from the next tile): it is straight back on its holder's
/// tile and the guard keeps standing off.
/datum/unit_test/voidcrew_stealth_hands_shoved

/datum/unit_test/voidcrew_stealth_hands_shoved/Run()
	var/datum/turf_reservation/block = stealth_block(12, 5)
	TEST_ASSERT_NOTNULL(block, "No room for the test")
	var/list/scene = hands_scene(block, 2, 6, 4)
	if(!scene)
		return
	var/datum/ai_controller/basic_controller/human_npc/stealth/guard_ai = scene[1]
	var/mob/living/carbon/human/holder = scene[3]
	var/mob/living/carbon/human/npc/hostage = scene[4]
	var/mob/living/carbon/human/shover = stealth_person(block, 2, 3)
	var/datum/hands_test_watch/watch = allocate(/datum/hands_test_watch)
	watch.RegisterSignal(hostage, COMSIG_MOVABLE_MOVED, TYPE_PROC_REF(/datum/hands_test_watch, on_moved))
	var/list/modifiers = list()
	modifiers[RIGHT_CLICK] = "1"
	shover.UnarmedAttack(hostage, TRUE, modifiers)
	watch.UnregisterSignal(hostage, COMSIG_MOVABLE_MOVED)
	TEST_ASSERT(watch.moves >= 2, "Test fixture: the shove didn't move the hostage ([watch.moves] moves)")
	TEST_ASSERT_EQUAL(hostage.loc, holder.loc, "Shoved by someone else, the hostage stayed off the holder's tile")
	TEST_ASSERT_EQUAL(stealth_hostage_of(holder), hostage, "Shoved by someone else, the hostage is no longer one")
	var/datum/ai_planning_subtree/stealth_hostage/subtree = GLOB.ai_subtrees[/datum/ai_planning_subtree/stealth_hostage]
	TEST_ASSERT_EQUAL(subtree.SelectBehaviors(guard_ai, 1), SUBTREE_RETURN_FINISH_PLANNING, "The hostage shoved by someone else, the guard stopped standing off")
	qdel(block)

/// A standoff against the holder ends for good when he shoots or throws at the guard or a friend in view; a blow on a
/// friend the guard can't see, or a shove, leaves it on.
/datum/unit_test/voidcrew_stealth_hands_fight_back

/datum/unit_test/voidcrew_stealth_hands_fight_back/Run()
	var/datum/turf_reservation/block = stealth_block(12, 6)
	TEST_ASSERT_NOTNULL(block, "No room for the test")
	// A shot at the guard.
	var/list/scene = hands_scene(block, 2, 5, 3)
	if(!scene)
		return
	var/datum/ai_controller/basic_controller/human_npc/stealth/guard_ai = scene[1]
	var/mob/living/carbon/human/holder = scene[3]
	var/obj/item/gun/pistol = holder.get_active_held_item()
	pistol.fire_gun(scene[2], holder, FALSE, null)
	hands_wait_standoff_over(guard_ai)
	TEST_ASSERT_NULL(guard_ai.standoff_holder, "The standoff outlived the holder shooting the guard")
	TEST_ASSERT(LAZYFIND(guard_ai.no_deals, REF(holder)), "No grudge after the holder shot the guard")
	hands_clear(scene)
	// A shot at a friend in view.
	scene = hands_scene(block, 2, 5, 3)
	if(!scene)
		return
	guard_ai = scene[1]
	holder = scene[3]
	TEST_ASSERT(guard_ai.stealth_standoff_sees_friend(scene[5]), "Test fixture: the guard can't see his friend")
	pistol = holder.get_active_held_item()
	pistol.fire_gun(scene[5], holder, FALSE, null)
	hands_wait_standoff_over(guard_ai)
	TEST_ASSERT_NULL(guard_ai.standoff_holder, "The standoff outlived the holder shooting a friend in view")
	TEST_ASSERT(LAZYFIND(guard_ai.no_deals, REF(holder)), "No grudge after the holder shot a friend")
	hands_clear(scene)
	// Something thrown at the guard.
	scene = hands_scene(block, 2, 5, 3)
	if(!scene)
		return
	guard_ai = scene[1]
	holder = scene[3]
	var/obj/item/wrench/thrown = allocate(/obj/item/wrench, holder.loc)
	thrown.throw_at(scene[2], 10, 1, holder)
	hands_wait_standoff_over(guard_ai)
	TEST_ASSERT_NULL(guard_ai.standoff_holder, "The standoff outlived the holder throwing something at the guard")
	TEST_ASSERT(LAZYFIND(guard_ai.no_deals, REF(holder)), "No grudge after the holder threw something at the guard")
	hands_clear(scene, list(thrown))
	// Something thrown at a friend in view.
	scene = hands_scene(block, 2, 5, 3)
	if(!scene)
		return
	guard_ai = scene[1]
	holder = scene[3]
	thrown = allocate(/obj/item/wrench, holder.loc)
	thrown.throw_at(scene[5], 10, 1, holder)
	hands_wait_standoff_over(guard_ai)
	TEST_ASSERT_NULL(guard_ai.standoff_holder, "The standoff outlived the holder throwing something at a friend in view")
	hands_clear(scene, list(thrown))
	// A shove on a friend in view: no harm, the standoff stays on.
	scene = hands_scene(block, 2, 2, 3)
	if(!scene)
		return
	guard_ai = scene[1]
	holder = scene[3]
	TEST_ASSERT(guard_ai.stealth_standoff_sees_friend(scene[5]), "Test fixture: the guard can't see his friend")
	var/list/modifiers = list()
	modifiers[RIGHT_CLICK] = "1"
	holder.swap_hand()
	holder.UnarmedAttack(scene[5], TRUE, modifiers)
	holder.swap_hand()
	TEST_ASSERT_EQUAL(guard_ai.standoff_holder?.resolve(), holder, "A shove on a friend ended the standoff")
	hands_clear(scene)
	// A blow on a friend the guard can't see: the standoff stays on.
	var/list/walls = list()
	for(var/x in 3 to 9)
		var/turf/spot = stealth_at(block, x, 3)
		spot.ChangeTurf(/turf/closed/wall)
		walls += spot
	scene = hands_scene(block, 2, 2, 3)
	if(!scene)
		return
	guard_ai = scene[1]
	holder = scene[3]
	TEST_ASSERT(!guard_ai.stealth_standoff_sees_friend(scene[5]), "Test fixture: the guard can see his friend behind the wall")
	stealth_test_punch(holder, scene[5])
	TEST_ASSERT_EQUAL(guard_ai.standoff_holder?.resolve(), holder, "A blow on a friend the guard can't see ended the standoff")
	hands_clear(scene)
	for(var/turf/spot as anything in walls)
		spot.ChangeTurf(/turf/open/floor/iron)
	qdel(block)

/// Someone else attacking a friend the guard can see: the guard leaves the holder be (no grudge) and turns on them. A
/// friend hit out of his sight changes nothing.
/datum/unit_test/voidcrew_stealth_hands_third_party

/datum/unit_test/voidcrew_stealth_hands_third_party/Run()
	var/datum/turf_reservation/block = stealth_block(12, 6)
	TEST_ASSERT_NOTNULL(block, "No room for the test")
	var/list/scene = hands_scene(block, 2, 2, 3)
	if(!scene)
		return
	var/datum/ai_controller/basic_controller/human_npc/stealth/guard_ai = scene[1]
	var/mob/living/carbon/human/holder = scene[3]
	var/mob/living/carbon/human/third = stealth_person(block, 2, 4)
	TEST_ASSERT(guard_ai.stealth_standoff_sees_friend(scene[5]), "Test fixture: the guard can't see his friend")
	stealth_test_punch(third, scene[5])
	TEST_ASSERT_NULL(guard_ai.standoff_holder, "The guard kept standing off while someone else hit his friend")
	TEST_ASSERT(!LAZYFIND(guard_ai.no_deals, REF(holder)), "The holder got the blame for someone else's blow")
	TEST_ASSERT_EQUAL(guard_ai.blackboard[BB_BASIC_MOB_CURRENT_TARGET], third, "The guard didn't turn on whoever hit his friend")
	hands_clear(scene, list(third))
	// Out of his sight.
	var/list/walls = list()
	for(var/x in 3 to 9)
		var/turf/spot = stealth_at(block, x, 3)
		spot.ChangeTurf(/turf/closed/wall)
		walls += spot
	scene = hands_scene(block, 2, 2, 3)
	if(!scene)
		return
	guard_ai = scene[1]
	holder = scene[3]
	third = stealth_person(block, 2, 4)
	TEST_ASSERT(!guard_ai.stealth_standoff_sees_friend(scene[5]), "Test fixture: the guard can see his friend behind the wall")
	stealth_test_punch(third, scene[5])
	TEST_ASSERT_EQUAL(guard_ai.standoff_holder?.resolve(), holder, "A friend hit out of the guard's sight ended the standoff")
	hands_clear(scene, list(third))
	for(var/turf/spot as anything in walls)
		spot.ChangeTurf(/turf/open/floor/iron)
	qdel(block)

/// Harm to the hostage with no hand or item behind it while the holder holds him (slammed on a table) and setting him
/// alight end the standoff for good; his own lungs hurting him don't.
/datum/unit_test/voidcrew_stealth_hands_unarmed_harm

/datum/unit_test/voidcrew_stealth_hands_unarmed_harm/Run()
	var/datum/turf_reservation/block = stealth_block(12, 6)
	TEST_ASSERT_NOTNULL(block, "No room for the test")
	var/list/scene = hands_scene(block, 2, 6, 4)
	if(!scene)
		return
	var/datum/ai_controller/basic_controller/human_npc/stealth/guard_ai = scene[1]
	var/mob/living/carbon/human/holder = scene[3]
	var/mob/living/carbon/human/npc/hostage = scene[4]
	hostage.apply_damage(5, OXY)
	TEST_ASSERT_EQUAL(guard_ai.standoff_holder?.resolve(), holder, "The hostage short of breath ended the standoff")
	hostage.apply_damage(10, BRUTE)
	TEST_ASSERT_NULL(guard_ai.standoff_holder, "The standoff outlived a blow to the hostage in the holder's hands")
	TEST_ASSERT(LAZYFIND(guard_ai.no_deals, REF(holder)), "No grudge after the hostage was hurt in the holder's hands")
	hands_clear(scene)
	scene = hands_scene(block, 2, 6, 4)
	if(!scene)
		return
	guard_ai = scene[1]
	holder = scene[3]
	hostage = scene[4]
	hostage.adjust_fire_stacks(5)
	hostage.ignite_mob()
	TEST_ASSERT(hostage.on_fire, "Test fixture: the hostage didn't catch fire")
	TEST_ASSERT_NULL(guard_ai.standoff_holder, "The standoff outlived the hostage set alight in the holder's hands")
	TEST_ASSERT(LAZYFIND(guard_ai.no_deals, REF(holder)), "No grudge after the hostage was set alight")
	hostage.extinguish_mob()
	qdel(block)

/// Only a real order to drop it makes the guard drop his weapon: a sentence with a gun or a piece in it doesn't.
/datum/unit_test/voidcrew_stealth_hands_drop_words

/datum/unit_test/voidcrew_stealth_hands_drop_words/Run()
	var/datum/turf_reservation/block = stealth_block(12, 6)
	TEST_ASSERT_NOTNULL(block, "No room for the test")
	var/list/scene = hands_scene(block, 2, 6, 4)
	if(!scene)
		return
	var/datum/ai_controller/basic_controller/human_npc/stealth/guard_ai = scene[1]
	var/mob/living/carbon/human/holder = scene[3]
	for(var/line in list("You piece of work.", "I've got a gun.", "Nobody touch your weapons.", "Drop dead."))
		holder.say(line)
		TEST_ASSERT(!guard_ai.standoff_dropped, "\"[line]\" made the guard drop his weapon")
	holder.say("Drop the gun!")
	TEST_ASSERT(guard_ai.standoff_dropped, "Told to drop the gun, the guard didn't")
	hands_clear(scene)
	for(var/line in list("Drop it!", "Put your weapon down!", "Guns down!"))
		scene = hands_scene(block, 2, 6, 4)
		if(!scene)
			return
		guard_ai = scene[1]
		holder = scene[3]
		holder.say(line)
		TEST_ASSERT(guard_ai.standoff_dropped, "Told \"[line]\", the guard didn't drop it")
		hands_clear(scene)
	qdel(block)

/// A guard held with a hand over his mouth mumbles against it, but not once his throat is cut (or anything else has
/// made him mute).
/datum/unit_test/voidcrew_stealth_hands_mute_mumble

/datum/unit_test/voidcrew_stealth_hands_mute_mumble/Run()
	var/datum/turf_reservation/block = stealth_block(8, 5)
	TEST_ASSERT_NOTNULL(block, "No room for the test")
	var/mob/living/carbon/human/npc/guard = d45_bare_guard(block, 4, 2)
	var/mob/living/carbon/human/holder = stealth_person(block, 3, 2)
	holder.setDir(EAST)
	grip_clamp(holder, guard)
	TEST_ASSERT_EQUAL(guard.stealth_hostage_sound(holder), "mumble", "Test fixture: the held guard doesn't mumble")
	ADD_TRAIT(guard, TRAIT_MUTE, TRAIT_SOURCE_UNIT_TESTS)
	TEST_ASSERT_NULL(guard.stealth_hostage_sound(holder), "A guard with no voice mumbled against the hand")
	REMOVE_TRAIT(guard, TRAIT_MUTE, TRAIT_SOURCE_UNIT_TESTS)
	qdel(block)

/// The hand over the mouth refused by tg's pull: one grab (tg's grab signal sent once), no hold, no mute.
/datum/unit_test/voidcrew_stealth_hands_grip_refused

/datum/unit_test/voidcrew_stealth_hands_grip_refused/Run()
	var/datum/turf_reservation/block = stealth_block(8, 5)
	TEST_ASSERT_NOTNULL(block, "No room for the test")
	var/mob/living/carbon/human/npc/guard = d45_bare_guard(block, 4, 2)
	var/mob/living/carbon/human/holder = stealth_person(block, 3, 2)
	holder.setDir(EAST)
	holder.zone_selected = BODY_ZONE_PRECISE_MOUTH
	TEST_ASSERT(stealth_grip_can_clamp(holder, guard), "Test fixture: can't put a hand over the guard's mouth")
	var/datum/hands_test_watch/watch = allocate(/datum/hands_test_watch)
	watch.RegisterSignal(holder, COMSIG_LIVING_GRAB, TYPE_PROC_REF(/datum/hands_test_watch, on_grab))
	watch.RegisterSignal(holder, COMSIG_LIVING_TRY_PULL, TYPE_PROC_REF(/datum/hands_test_watch, refuse_pull))
	TEST_ASSERT(!holder.grab(guard), "A refused pull still counted as a grab")
	watch.UnregisterSignal(holder, list(COMSIG_LIVING_GRAB, COMSIG_LIVING_TRY_PULL))
	TEST_ASSERT_EQUAL(watch.grabs, 1, "tg's grab signal went out [watch.grabs] times for one grab")
	TEST_ASSERT(holder.pulling != guard, "Refused, the holder still pulls the guard")
	TEST_ASSERT(!HAS_TRAIT_FROM(guard, TRAIT_MUTE, "stealth_grip"), "Refused, the guard was left mute")
	qdel(block)

/// A held-up guard who makes his move while his surrender still holds him down fights when he gets up: he doesn't
/// decide again whether to give up.
/datum/unit_test/voidcrew_stealth_hands_holdup_move

/datum/unit_test/voidcrew_stealth_hands_holdup_move/Run()
	var/datum/turf_reservation/block = stealth_block(10, 4)
	TEST_ASSERT_NOTNULL(block, "No room for the test")
	var/mob/living/carbon/human/npc/guard = stealth_guard(block, 4, 1, WEST)
	var/datum/ai_controller/basic_controller/human_npc/stealth/guard_ai = stealth_ai(guard)
	var/mob/living/carbon/human/person = stealth_person(block, 2, 1)
	var/obj/item/gun/ballistic/automatic/pistol/pistol = allocate(/obj/item/gun/ballistic/automatic/pistol)
	pistol.can_misfire = FALSE
	person.put_in_active_hand(pistol, forced = TRUE)
	person.AddComponent(/datum/component/gunpoint, guard, pistol)
	TEST_ASSERT_EQUAL(guard_ai.holdup_aimer?.resolve(), person, "Test fixture: held up, the guard didn't give up")
	// as in voidcrew_stealth_holdup: walk up and grab him (tg drops the aim), let go and walk off
	person.forceMove(stealth_at(block, 3, 1))
	person.start_pulling(guard, supress_message = TRUE)
	person.stop_pulling()
	person.forceMove(stealth_at(block, 0, 1))
	guard_ai.stealth_holdup_check()
	TEST_ASSERT_NULL(guard_ai.holdup_aimer, "Test fixture: nobody covering him, the guard kept his hands up")
	TEST_ASSERT(guard.IsParalyzed(), "Test fixture: the surrender's Paralyze had already run out")
	guard.SetParalyzed(0)
	TEST_ASSERT(!guard.npc_surrendering, "Up again, the guard is still surrendering")
	TEST_ASSERT(!guard.npc_surrender_redecide, "Up again after making his move, the guard decides again whether to give up")
	TEST_ASSERT_EQUAL(guard_ai.blackboard[BB_BASIC_MOB_CURRENT_TARGET], person, "Up again, the guard isn't after the aimer")
	qdel(block)
