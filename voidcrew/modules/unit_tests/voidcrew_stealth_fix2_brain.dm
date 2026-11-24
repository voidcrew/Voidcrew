// Stealth guards: the second round of guard brain fixes (stealth_ai.dm, stealth_perception.dm, stealth_disguise.dm).
// Unit tests compile before voidcrew/_DEFINES, so values from there are written out: states "unaware", "suspicious",
// "alert", "searching"; STEALTH_CALL_NAME 4; STEALTH_HARM_ALERT_RANGE 9; a wall muffles a sound by 3 tiles; a pass is
// read from 2 tiles, and a guard kept further off than that gives up 8 s after the stop; BB_HUMAN_NPC_STUN_SHOOTER
// "human_npc_stun_shooter".

#define FIX2_BRAIN_LOOKOUT /mob/living/carbon/human/npc/ruin/trooper/scav/lookout

/// Sets up two guards standing in one group's region. Returns the friend's controller.
/datum/unit_test/proc/fix2_brain_pair(mob/living/carbon/human/npc/guard, mob/living/carbon/human/npc/friend)
	var/datum/ai_controller/basic_controller/human_npc/stealth/guard_ai = stealth_ai(guard)
	var/datum/ai_controller/basic_controller/human_npc/stealth/friend_ai = stealth_ai(friend)
	guard_ai.stealth_setup()
	friend_ai.stealth_setup()
	return friend_ai

/// Out cold, a guard raises nothing from its own sleep: a sleep chem that keeps it under doesn't page its friends.
/datum/unit_test/voidcrew_stealth_fix2_brain_out_cold_harm

/datum/unit_test/voidcrew_stealth_fix2_brain_out_cold_harm/Run()
	var/datum/turf_reservation/block = stealth_block(8, 3)
	TEST_ASSERT_NOTNULL(block, "No room for the test")
	allocate(/obj/effect/landmark/stealth_group, stealth_at(block, 4, 2))
	var/mob/living/carbon/human/npc/guard = stealth_guard(block, 1, 1, EAST)
	var/mob/living/carbon/human/npc/friend = stealth_guard(block, 4, 1, WEST)
	var/datum/ai_controller/basic_controller/human_npc/stealth/friend_ai = fix2_brain_pair(guard, friend)
	var/datum/ai_controller/basic_controller/human_npc/stealth/guard_ai = stealth_ai(guard)
	guard.Unconscious(30 SECONDS)
	TEST_ASSERT_EQUAL(guard.stat, UNCONSCIOUS, "Test fixture: the guard isn't out cold")
	// The knockout itself landed while it was awake; what matters is what comes after.
	guard_ai.harm_pending = FALSE
	guard_ai.next_harm_at = 0
	guard.Sleeping(10 SECONDS)
	TEST_ASSERT(!guard_ai.harm_pending, "Sleep reapplied to a guard out cold was taken as fresh harm")
	guard_ai.stealth_note_harm()
	TEST_ASSERT(!guard_ai.harm_pending, "A guard out cold noted harm")
	TEST_ASSERT_EQUAL(friend_ai.stealth_state(), "unaware", "A friend went looking because a guard out cold was kept asleep")
	qdel(block)

/// Harm nobody is named for reaches only the friends that see it or hear it, and only harm the guard felt land.
/datum/unit_test/voidcrew_stealth_fix2_brain_harm_heard

/datum/unit_test/voidcrew_stealth_fix2_brain_harm_heard/Run()
	var/datum/turf_reservation/block = stealth_block(10, 3)
	TEST_ASSERT_NOTNULL(block, "No room for the test")
	allocate(/obj/effect/landmark/stealth_group, stealth_at(block, 4, 2))
	var/mob/living/carbon/human/npc/guard = allocate(FIX2_BRAIN_LOOKOUT, stealth_at(block, 1, 1))
	guard.setDir(EAST)
	var/mob/living/carbon/human/npc/near = stealth_guard(block, 3, 1, WEST)
	// Behind two walls: 7 tiles off, 13 as the sound carries.
	stealth_at(block, 5, 1).ChangeTurf(/turf/closed/wall)
	stealth_at(block, 6, 1).ChangeTurf(/turf/closed/wall)
	var/mob/living/carbon/human/npc/far = stealth_guard(block, 8, 1, EAST)
	var/datum/ai_controller/basic_controller/human_npc/stealth/near_ai = fix2_brain_pair(guard, near)
	var/datum/ai_controller/basic_controller/human_npc/stealth/far_ai = stealth_ai(far)
	far_ai.stealth_setup()
	var/datum/ai_controller/basic_controller/human_npc/stealth/guard_ai = stealth_ai(guard)
	guard_ai.stealth_ready = TRUE
	// Health slipping away: its own business.
	guard_ai.stealth_note_harm(5 SECONDS, FALSE)
	guard_ai.stealth_judge_harm()
	TEST_ASSERT_EQUAL(guard_ai.stealth_state(), "searching", "Health lost with nobody to blame didn't send the guard looking")
	TEST_ASSERT_EQUAL(near_ai.stealth_state(), "unaware", "A friend went looking because a guard was losing health")
	TEST_ASSERT_EQUAL(far_ai.stealth_state(), "unaware", "A friend behind walls went looking because a guard was losing health")
	// A blow it felt land: the friend that sees it goes, the one behind two walls doesn't.
	guard_ai.next_harm_at = 0
	guard_ai.stealth_note_harm()
	guard_ai.stealth_judge_harm()
	TEST_ASSERT_EQUAL(near_ai.stealth_state(), "searching", "A friend that saw a guard hurt didn't go looking")
	TEST_ASSERT_EQUAL(far_ai.stealth_state(), "unaware", "A friend that could neither see nor hear a guard hurt went looking")
	qdel(block)

/// Standing off against a holder, harm a guard can't name (a grenade, fire, gas) ends the standoff as a blow does,
/// for it and for one of its people that sees it.
/datum/unit_test/voidcrew_stealth_fix2_brain_standoff_harm

/datum/unit_test/voidcrew_stealth_fix2_brain_standoff_harm/Run()
	var/datum/turf_reservation/block = stealth_block(10, 5)
	TEST_ASSERT_NOTNULL(block, "No room for the test")
	allocate(/obj/effect/landmark/stealth_group, stealth_at(block, 6, 4))
	var/mob/living/carbon/human/npc/guard = stealth_guard(block, 8, 1, WEST)
	var/mob/living/carbon/human/npc/hostage = stealth_guard(block, 3, 1, WEST)
	var/mob/living/carbon/human/holder = stealth_person(block, 2, 1)
	var/mob/living/carbon/human/npc/guard2 = stealth_guard(block, 8, 3, WEST)
	var/mob/living/carbon/human/npc/hostage2 = stealth_guard(block, 3, 3, WEST)
	var/mob/living/carbon/human/holder2 = stealth_person(block, 2, 3)
	var/datum/ai_controller/basic_controller/human_npc/stealth/guard2_ai = fix2_brain_pair(guard, guard2)
	var/datum/ai_controller/basic_controller/human_npc/stealth/guard_ai = stealth_test_standoff(guard, holder, hostage)
	if(!guard_ai)
		return
	if(!stealth_test_standoff(guard2, holder2, hostage2))
		return
	guard_ai.next_harm_at = 0
	guard_ai.stealth_note_harm()
	guard_ai.stealth_judge_harm()
	TEST_ASSERT_NULL(guard_ai.standoff_holder, "The standoff outlived harm the guard couldn't name")
	TEST_ASSERT(LAZYFIND(guard_ai.no_deals, REF(holder)), "No grudge after harm in a standoff")
	TEST_ASSERT_NULL(guard2_ai.standoff_holder, "A guard that saw one of its people hurt kept standing off")
	qdel(block)

/// A guard that can't see a stun shooter doesn't charge where they are now.
/datum/unit_test/voidcrew_stealth_fix2_brain_close_in_unseen

/datum/unit_test/voidcrew_stealth_fix2_brain_close_in_unseen/Run()
	var/datum/turf_reservation/block = stealth_block(10, 3)
	TEST_ASSERT_NOTNULL(block, "No room for the test")
	var/mob/living/carbon/human/npc/guard = stealth_guard(block, 1, 1, EAST)
	var/datum/ai_controller/basic_controller/human_npc/stealth/stealth_ai = stealth_ai(guard)
	var/datum/component/npc_combat_sense/sense = guard.GetComponent(/datum/component/npc_combat_sense)
	TEST_ASSERT_NOTNULL(sense, "Test fixture: a scav guard has no combat sense")
	var/mob/living/carbon/human/shooter = stealth_person(block, 7, 1)
	var/turf/spot = get_turf(shooter)
	GLOB.stealth_test_dark_turfs[spot] = TRUE
	sense.shooter_ref = WEAKREF(shooter)
	stealth_ai.set_blackboard_key(BB_BASIC_MOB_CURRENT_TARGET, shooter)
	TEST_ASSERT(!stealth_ai.stealth_has_in_view(shooter), "Test fixture: the guard sees the shooter in the dark")
	TEST_ASSERT_NULL(sense.rules.plan_close_in(guard, stealth_ai, sense), "A guard charged a shooter it can't see")
	TEST_ASSERT_NULL(stealth_ai.blackboard["human_npc_stun_shooter"], "A guard set off after a shooter it can't see")
	GLOB.stealth_test_dark_turfs[spot] = FALSE
	TEST_ASSERT_EQUAL(sense.rules.plan_close_in(guard, stealth_ai, sense), SUBTREE_RETURN_FINISH_PLANNING, "A guard didn't charge a shooter it can see")
	qdel(block)

/// Someone's captive (an NPC in cuffs or out cold) is no intruder to a guard, as to the den's cameras.
/datum/unit_test/voidcrew_stealth_fix2_brain_captive

/datum/unit_test/voidcrew_stealth_fix2_brain_captive/Run()
	var/datum/turf_reservation/block = stealth_block(8, 5)
	TEST_ASSERT_NOTNULL(block, "No room for the test")
	var/mob/living/carbon/human/npc/guard = stealth_guard(block, 1, 2, EAST)
	var/datum/ai_controller/basic_controller/human_npc/stealth/stealth_ai = stealth_ai(guard)
	var/mob/living/carbon/human/cuffed = stealth_person(block, 4, 2)
	cuffed.set_handcuffed(new /obj/item/restraints/handcuffs(cuffed))
	cuffed.update_handcuffed()
	TEST_ASSERT(HAS_TRAIT(cuffed, TRAIT_RESTRAINED), "Test fixture: the cuffs didn't go on")
	var/mob/living/carbon/human/out_cold = stealth_person(block, 4, 3)
	out_cold.Unconscious(30 SECONDS)
	var/mob/living/carbon/human/free = stealth_person(block, 4, 1)
	var/list/candidates = stealth_candidates(guard, 6)
	TEST_ASSERT(!(cuffed in candidates), "A guard might notice a cuffed captive")
	TEST_ASSERT(!(out_cold in candidates), "A guard might notice a captive out cold")
	TEST_ASSERT(free in candidates, "A guard can't notice someone free")
	stealth_scans(guard, 3)
	TEST_ASSERT_NULL(stealth_ai.notice_map[REF(cuffed)], "A guard noticed a cuffed captive")
	TEST_ASSERT_NULL(stealth_ai.notice_map[REF(out_cold)], "A guard noticed a captive out cold")
	qdel(block)

/// A fallen friend beside a guard in the dark isn't seen; in the light it is.
/datum/unit_test/voidcrew_stealth_fix2_brain_body_dark

/datum/unit_test/voidcrew_stealth_fix2_brain_body_dark/Run()
	var/datum/turf_reservation/block = stealth_block(10, 3)
	TEST_ASSERT_NOTNULL(block, "No room for the test")
	allocate(/obj/effect/landmark/stealth_group, stealth_at(block, 6, 2))
	var/mob/living/carbon/human/npc/guard = stealth_guard(block, 5, 1, EAST)
	// Two tiles behind it, inside its all-round close radius.
	var/mob/living/carbon/human/npc/friend = stealth_guard(block, 3, 1, EAST)
	fix2_brain_pair(guard, friend)
	var/datum/ai_controller/basic_controller/human_npc/stealth/stealth_ai = stealth_ai(guard)
	var/turf/spot = get_turf(friend)
	friend.set_body_position(LYING_DOWN)
	GLOB.stealth_test_dark_turfs[spot] = TRUE
	stealth_ai.next_body_scan = 0
	stealth_scans(guard, 1)
	TEST_ASSERT_EQUAL(stealth_ai.stealth_state(), "unaware", "A guard found a body behind it in the dark")
	GLOB.stealth_test_dark_turfs[spot] = FALSE
	stealth_ai.next_body_scan = 0
	stealth_scans(guard, 1)
	TEST_ASSERT_EQUAL(stealth_ai.stealth_state(), "suspicious", "A guard didn't find a body behind it in the light")
	qdel(block)

/// Stopped by a guard that can't get within reading range of the pass, the disguise doesn't hold forever.
/datum/unit_test/voidcrew_stealth_fix2_brain_challenge_gives_up

/datum/unit_test/voidcrew_stealth_fix2_brain_challenge_gives_up/Run()
	var/datum/turf_reservation/block = stealth_block(10, 3)
	TEST_ASSERT_NOTNULL(block, "No room for the test")
	var/mob/living/carbon/human/npc/guard = stealth_guard(block, 1, 1, EAST)
	var/datum/ai_controller/basic_controller/human_npc/stealth/stealth_ai = stealth_ai(guard)
	var/mob/living/carbon/human/person = stealth_person(block, 5, 1)
	stealth_dress(person)
	stealth_ai.stealth_challenge(person)
	TEST_ASSERT_EQUAL(stealth_ai.challenge?.resolve(), person, "Test fixture: the guard didn't stop them")
	stealth_scans(guard, 1)
	TEST_ASSERT_EQUAL(stealth_ai.challenge?.resolve(), person, "The guard gave up on the stop at once")
	stealth_ai.stealth_rewind(9 SECONDS)
	stealth_scans(guard, 1)
	TEST_ASSERT_NULL(stealth_ai.challenge?.resolve(), "A stop the guard never got close to read held after 9 s")
	TEST_ASSERT(!stealth_ai.stealth_fooled(person), "Kept out of reach, the disguise still fools the guard")
	qdel(block)

/// A guard whose target goes down fights someone who hit it out of the dark, but can't name them or know their face.
/datum/unit_test/voidcrew_stealth_fix2_brain_downed_unseen

/datum/unit_test/voidcrew_stealth_fix2_brain_downed_unseen/Run()
	var/datum/turf_reservation/block = stealth_block(10, 3)
	TEST_ASSERT_NOTNULL(block, "No room for the test")
	var/mob/living/carbon/human/npc/lookout = allocate(FIX2_BRAIN_LOOKOUT, stealth_at(block, 4, 1))
	lookout.setDir(EAST)
	var/datum/ai_controller/basic_controller/human_npc/stealth/lookout_ai = lookout.ai_controller
	lookout_ai.stealth_ready = TRUE
	var/mob/living/carbon/human/first = stealth_person(block, 6, 1)
	first.real_name = "Ana Kowalski"
	first.name = first.real_name
	lookout_ai.stealth_go_alert(first)
	TEST_ASSERT_EQUAL(lookout_ai.blackboard[BB_BASIC_MOB_CURRENT_TARGET], first, "Test fixture: no fight")
	// Three tiles behind it, in its colours with a bare face.
	var/mob/living/carbon/human/behind = stealth_person(block, 1, 1)
	behind.real_name = "Ivan Petrov"
	behind.name = behind.real_name
	stealth_dress(behind, TRUE, FALSE, FALSE)
	var/datum/component/stealth_disguise/cache = stealth_disguise_cache(behind)
	TEST_ASSERT_EQUAL(cache?.face, "Ivan Petrov", "Test fixture: not the face expected")
	lookout_ai.next_switch_at = world.time + 1 MINUTES
	SEND_SIGNAL(lookout, COMSIG_ATOM_WAS_ATTACKED, behind, ATTACKER_DAMAGING_ATTACK)
	TEST_ASSERT_EQUAL(lookout_ai.blackboard[BB_BASIC_MOB_CURRENT_TARGET], first, "Test fixture: the lookout turned on the one behind it")
	TEST_ASSERT(!LAZYACCESS(lookout_ai.made, cache.face), "A lookout knew the face of someone it never saw")
	first.Unconscious(30 SECONDS)
	lookout_ai.pending_call = null
	lookout_ai.stealth_target_downed(first)
	TEST_ASSERT_EQUAL(lookout_ai.blackboard[BB_BASIC_MOB_CURRENT_TARGET], behind, "With its target down the lookout didn't fight the one that hit it")
	TEST_ASSERT_NOTNULL(lookout_ai.pending_call, "The lookout didn't call in the next fight")
	TEST_ASSERT_NULL(lookout_ai.pending_call[4], "A lookout named someone it never saw ([lookout_ai.pending_call[4]])")
	TEST_ASSERT(!LAZYACCESS(lookout_ai.made, cache.face), "A lookout knew the face of someone it fought without seeing")
	qdel(block)

/// A pass in a dead guard's name gets nobody called by his name.
/datum/unit_test/voidcrew_stealth_fix2_brain_dead_pass

/datum/unit_test/voidcrew_stealth_fix2_brain_dead_pass/Run()
	var/datum/turf_reservation/block = stealth_block(8, 3)
	TEST_ASSERT_NOTNULL(block, "No room for the test")
	allocate(/obj/effect/landmark/stealth_group, stealth_at(block, 4, 2))
	var/mob/living/carbon/human/npc/guard = stealth_guard(block, 1, 1, EAST)
	var/mob/living/carbon/human/npc/friend = stealth_guard(block, 6, 1, WEST)
	fix2_brain_pair(guard, friend)
	var/datum/ai_controller/basic_controller/human_npc/stealth/stealth_ai = stealth_ai(guard)
	friend.real_name = "Vasily Orlov"
	var/mob/living/carbon/human/person = stealth_person(block, 3, 1)
	stealth_dress(person, TRUE, TRUE, FALSE)
	var/obj/item/card/id/advanced/black/scav/card = new(person)
	card.registered_name = friend.real_name
	person.equip_to_slot_or_del(card, ITEM_SLOT_ID)
	TEST_ASSERT_EQUAL(stealth_ai.stealth_card_name(person), "Vasily", "Test fixture: a living friend's pass isn't read as his")
	friend.death()
	TEST_ASSERT_NULL(stealth_ai.stealth_card_name(person), "A dead guard's pass was read as his")
	qdel(block)

#undef FIX2_BRAIN_LOOKOUT
