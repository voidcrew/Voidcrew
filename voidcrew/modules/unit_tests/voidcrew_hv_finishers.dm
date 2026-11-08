/**
 * Hyperviolence finishers (voidcrew/modules/hyperviolence/finishers/).
 *
 * Fork defines are included after the tests, so these use the literal values, each with a comment
 * naming the define. The finishers are driven by calling advance() and tick() directly; nothing
 * here waits on a timer or an AI walk.
 */

/// Shared helpers; not a test itself
/datum/unit_test/voidcrew_hv_finisher
	abstract_type = /datum/unit_test/voidcrew_hv_finisher

/// The floor `dx`, `dy` tiles from the test room's bottom-left corner
/datum/unit_test/voidcrew_hv_finisher/proc/spot(dx, dy)
	return locate(run_loc_floor_bottom_left.x + dx, run_loc_floor_bottom_left.y + dy, run_loc_floor_bottom_left.z)

/// A human knocked flat at `where`
/datum/unit_test/voidcrew_hv_finisher/proc/downed_human(turf/where)
	var/mob/living/carbon/human/consistent/victim = allocate(/mob/living/carbon/human/consistent, where)
	victim.Paralyze(100 SECONDS)
	return victim

/// Runs `finisher` to its end through advance(), as its timer would. Gives up after a sane number of steps.
/datum/unit_test/voidcrew_hv_finisher/proc/run_to_end(datum/hv_finisher/finisher)
	for(var/i in 1 to 20)
		if(!finisher.running)
			return
		finisher.advance()

/// Every boss that should have a finisher has one, wired into its AI once, after its targeting
/datum/unit_test/voidcrew_hv_finisher/users

/datum/unit_test/voidcrew_hv_finisher/users/Run()
	var/list/users = list(
		/mob/living/basic/hoarfrost_matriarch,
		/mob/living/basic/trooper/pirate/faction/boss/medieval,
		/mob/living/basic/alien/queen/large/derelict,
		/mob/living/basic/trooper/pirate/faction/boss/grey,
	)
	for(var/user_type in users)
		var/mob/living/basic/boss = allocate(user_type, spot(1, 1))
		var/datum/component/hv_finisher_user/finishing = boss.GetComponent(/datum/component/hv_finisher_user)
		TEST_ASSERT_NOTNULL(finishing, "[user_type] has no finisher")
		TEST_ASSERT_NOTNULL(boss.ai_controller, "[user_type] has no AI")
		var/count = 0
		for(var/datum/ai_planning_subtree/subtree in boss.ai_controller.planning_subtrees)
			if(istype(subtree, /datum/ai_planning_subtree/hv_finisher))
				count++
		TEST_ASSERT_EQUAL(count, 1, "[user_type] should plan its finisher exactly once")
		// BB_HV_FINISHER_ACTION
		TEST_ASSERT_EQUAL(boss.ai_controller.blackboard["BB_hv_finisher_action"], finishing.finisher_action, "[user_type]'s AI can't see its finisher")
		TEST_ASSERT_EQUAL(finishing.finisher_action.owner, boss, "[user_type] wasn't granted its finisher")
		TEST_ASSERT(!(finishing.finisher_action in boss.actions), "[user_type]'s finisher has a button a player could press")
		qdel(boss)

/// The subtree goes after the subtrees that pick a target and before the attacks, once
/datum/unit_test/voidcrew_hv_finisher/subtree_order

/datum/unit_test/voidcrew_hv_finisher/subtree_order/Run()
	var/mob/living/basic/hoarfrost_matriarch/matriarch = allocate(/mob/living/basic/hoarfrost_matriarch, spot(1, 1))
	var/list/plan = matriarch.ai_controller.planning_subtrees
	var/finisher_at = 0
	var/find_target_at = 0
	var/rotation_at = 0
	for(var/i in 1 to length(plan))
		var/datum/ai_planning_subtree/subtree = plan[i]
		if(istype(subtree, /datum/ai_planning_subtree/hv_finisher))
			finisher_at = i
		else if(istype(subtree, /datum/ai_planning_subtree/simple_find_target))
			find_target_at = i
		else if(istype(subtree, /datum/ai_planning_subtree/hoarfrost_rotation))
			rotation_at = i
	TEST_ASSERT(finisher_at > find_target_at, "the finisher is planned before the matriarch picks a target")
	TEST_ASSERT(finisher_at < rotation_at, "the finisher is planned after the matriarch's abilities")
	TEST_ASSERT(!hv_finisher_add_subtree(matriarch.ai_controller), "the finisher subtree was added twice")

/// A boarding pod swaps a boss's AI controller after it spawns; the finisher follows it
/datum/unit_test/voidcrew_hv_finisher/controller_swap

/datum/unit_test/voidcrew_hv_finisher/controller_swap/Run()
	var/mob/living/basic/trooper/pirate/faction/boss/medieval/knight = allocate(/mob/living/basic/trooper/pirate/faction/boss/medieval, spot(1, 1))
	var/datum/component/hv_finisher_user/finishing = knight.GetComponent(/datum/component/hv_finisher_user)
	var/datum/ai_controller/old_controller = knight.ai_controller
	TEST_ASSERT_EQUAL(finishing.watched_controller, old_controller, "the finisher isn't watching the knight's AI")
	// What /obj/structure/closet/supplypod/boarding/boss/setup_boarder_patrol() does
	qdel(old_controller)
	knight.ai_controller = new /datum/ai_controller/basic_controller/trooper/patrolling/boss(knight)
	TEST_ASSERT_NULL(finishing.watched_controller, "the finisher still watches a deleted AI")
	// The component does this on a one-tick timer
	finishing.adopt_controller()
	TEST_ASSERT_EQUAL(finishing.watched_controller, knight.ai_controller, "the finisher didn't follow the knight onto its new AI")
	TEST_ASSERT(locate(/datum/ai_planning_subtree/hv_finisher) in knight.ai_controller.planning_subtrees, "the new AI doesn't plan the finisher")

/// Who can and can't be finished
/datum/unit_test/voidcrew_hv_finisher/victims

/datum/unit_test/voidcrew_hv_finisher/victims/Run()
	var/mob/living/basic/hoarfrost_matriarch/matriarch = allocate(/mob/living/basic/hoarfrost_matriarch, spot(1, 1))
	var/mob/living/carbon/human/consistent/standing = allocate(/mob/living/carbon/human/consistent, spot(2, 1))
	TEST_ASSERT(!hv_finisher_valid_victim(matriarch, standing), "someone on their feet can be finished")
	var/mob/living/carbon/human/consistent/down = downed_human(spot(2, 2))
	TEST_ASSERT(hv_finisher_valid_victim(matriarch, down), "someone knocked down can't be finished")
	down.faction |= matriarch.faction
	TEST_ASSERT(!hv_finisher_valid_victim(matriarch, down), "an ally can be finished")
	down.faction -= matriarch.faction
	var/mob/living/carbon/human/consistent/dead = downed_human(spot(1, 2))
	dead.death()
	TEST_ASSERT(!hv_finisher_valid_victim(matriarch, dead), "a corpse can be finished")
	var/datum/hv_finisher/finisher = allocate(/datum/hv_finisher/hoarfrost, matriarch, down)
	TEST_ASSERT(finisher.start(), "the finisher didn't start on someone down next to it")
	TEST_ASSERT(!hv_finisher_valid_victim(matriarch, down), "someone already being finished can be finished again")
	finisher.stop(1) // HV_FINISHER_DONE

/// The matriarch's finisher, start to end: the hold, the arm, and both mobs freed after
/datum/unit_test/voidcrew_hv_finisher/full_run

/datum/unit_test/voidcrew_hv_finisher/full_run/Run()
	var/mob/living/basic/hoarfrost_matriarch/matriarch = allocate(/mob/living/basic/hoarfrost_matriarch, spot(1, 1))
	var/mob/living/carbon/human/consistent/victim = downed_human(spot(2, 1))
	var/datum/hv_finisher/finisher = allocate(/datum/hv_finisher/hoarfrost, matriarch, victim)
	TEST_ASSERT(finisher.start(), "the finisher didn't start")
	TEST_ASSERT(!finisher.gripped, "the wind-up already holds the victim")
	TEST_ASSERT_NOTNULL(finisher.mark, "the wind-up didn't mark the victim")
	TEST_ASSERT(HAS_TRAIT(matriarch, TRAIT_AI_PAUSED), "the matriarch's AI runs during the finisher")
	TEST_ASSERT(matriarch.has_status_effect(/datum/status_effect/hv_finishing), "the matriarch isn't marked as finishing")
	var/zone = finisher.target_zone
	TEST_ASSERT(zone in list(BODY_ZONE_R_ARM, BODY_ZONE_L_ARM), "the matriarch went for [zone], not an arm")
	finisher.advance()
	TEST_ASSERT(finisher.gripped, "the pin doesn't hold the victim")
	TEST_ASSERT(HAS_TRAIT_FROM(victim, TRAIT_FLOORED, TRAIT_STATUS_EFFECT("hv_finisher_hold")), "the victim isn't held down")
	TEST_ASSERT_NOTNULL(victim.get_bodypart(zone), "the arm came off before the kill")
	run_to_end(finisher)
	TEST_ASSERT(!finisher.running, "the finisher never ended")
	TEST_ASSERT_EQUAL(finisher.result, 1, "the finisher ended early") // HV_FINISHER_DONE
	TEST_ASSERT(finisher.completed, "the killing blow never landed")
	TEST_ASSERT_NULL(victim.get_bodypart(zone), "the arm is still on")
	TEST_ASSERT(!victim.has_status_effect(/datum/status_effect/hv_finisher_hold), "the victim is still held")
	TEST_ASSERT(!HAS_TRAIT_FROM(victim, TRAIT_FLOORED, TRAIT_STATUS_EFFECT("hv_finisher_hold")), "the hold's traits outlived it")
	TEST_ASSERT(!matriarch.has_status_effect(/datum/status_effect/hv_finishing), "the matriarch is still finishing")
	TEST_ASSERT(!HAS_TRAIT(matriarch, TRAIT_AI_PAUSED), "the matriarch's AI is still paused")
	// HV_FINISHER_OFFSET
	TEST_ASSERT(!LAZYACCESS(matriarch.offsets?[PIXEL_Y_OFFSET], "hv_finisher"), "the matriarch kept her pose")

/// A torn-off head lands where the body lies, with the brain still in it
/datum/unit_test/voidcrew_hv_finisher/head_keeps_brain

/datum/unit_test/voidcrew_hv_finisher/head_keeps_brain/Run()
	var/mob/living/basic/alien/queen/large/derelict/empress = allocate(/mob/living/basic/alien/queen/large/derelict, spot(1, 1))
	var/mob/living/carbon/human/consistent/victim = downed_human(spot(2, 1))
	var/obj/item/organ/brain/brain = victim.get_organ_slot(ORGAN_SLOT_BRAIN)
	var/obj/item/bodypart/head/head = victim.get_bodypart(BODY_ZONE_HEAD)
	var/datum/hv_finisher/finisher = allocate(/datum/hv_finisher/alien_empress, empress, victim)
	TEST_ASSERT(finisher.start(), "the finisher didn't start")
	run_to_end(finisher)
	TEST_ASSERT_EQUAL(finisher.result, 1, "the finisher ended early") // HV_FINISHER_DONE
	TEST_ASSERT_NULL(victim.get_bodypart(BODY_ZONE_HEAD), "the head is still on")
	TEST_ASSERT(!QDELETED(head), "the head was destroyed")
	TEST_ASSERT_EQUAL(get_turf(head), spot(2, 1), "the head didn't land where the body lies")
	TEST_ASSERT(!QDELETED(brain), "the brain was destroyed")
	TEST_ASSERT_EQUAL(brain.loc, head, "the brain isn't in the head")

/// A burst head still leaves the brain
/datum/unit_test/voidcrew_hv_finisher/burst_keeps_brain

/datum/unit_test/voidcrew_hv_finisher/burst_keeps_brain/Run()
	var/mob/living/basic/trooper/pirate/faction/boss/grey/robust = allocate(/mob/living/basic/trooper/pirate/faction/boss/grey, spot(1, 1))
	var/mob/living/carbon/human/consistent/victim = downed_human(spot(2, 1))
	var/obj/item/organ/brain/brain = victim.get_organ_slot(ORGAN_SLOT_BRAIN)
	var/datum/hv_finisher/finisher = allocate(/datum/hv_finisher/robust_one, robust, victim)
	TEST_ASSERT(finisher.start(), "the finisher didn't start")
	run_to_end(finisher)
	TEST_ASSERT_EQUAL(finisher.result, 1, "the finisher ended early") // HV_FINISHER_DONE
	TEST_ASSERT_NULL(victim.get_bodypart(BODY_ZONE_HEAD), "the head is still on")
	TEST_ASSERT(!QDELETED(brain), "the brain was destroyed")

/// The Black Knight takes both legs
/datum/unit_test/voidcrew_hv_finisher/bisect

/datum/unit_test/voidcrew_hv_finisher/bisect/Run()
	var/mob/living/basic/trooper/pirate/faction/boss/medieval/knight = allocate(/mob/living/basic/trooper/pirate/faction/boss/medieval, spot(1, 1))
	var/mob/living/carbon/human/consistent/victim = downed_human(spot(2, 1))
	var/datum/hv_finisher/finisher = allocate(/datum/hv_finisher/black_knight, knight, victim)
	TEST_ASSERT(finisher.start(), "the finisher didn't start")
	run_to_end(finisher)
	TEST_ASSERT_EQUAL(finisher.result, 1, "the finisher ended early") // HV_FINISHER_DONE
	TEST_ASSERT_NULL(victim.get_bodypart(BODY_ZONE_L_LEG), "the left leg is still on")
	TEST_ASSERT_NULL(victim.get_bodypart(BODY_ZONE_R_LEG), "the right leg is still on")
	TEST_ASSERT_NOTNULL(victim.get_bodypart(BODY_ZONE_HEAD), "the knight took the head too")

/// Hurting the attacker makes it let go, before the kill; it takes extra damage meanwhile
/datum/unit_test/voidcrew_hv_finisher/damage_interrupt

/datum/unit_test/voidcrew_hv_finisher/damage_interrupt/Run()
	var/mob/living/basic/hoarfrost_matriarch/matriarch = allocate(/mob/living/basic/hoarfrost_matriarch, spot(1, 1))
	var/mob/living/carbon/human/consistent/victim = downed_human(spot(2, 1))
	var/datum/hv_finisher/hoarfrost/finisher = allocate(/datum/hv_finisher/hoarfrost, matriarch, victim)
	TEST_ASSERT(finisher.start(), "the finisher didn't start")
	finisher.advance()
	var/zone = finisher.target_zone
	var/health_before = matriarch.health
	matriarch.apply_damage(30, BRUTE)
	TEST_ASSERT_EQUAL(health_before - matriarch.health, 30 * finisher.vulnerability, "the matriarch didn't take extra damage while finishing")
	TEST_ASSERT(finisher.running, "the finisher broke before it took enough damage")
	matriarch.apply_damage(30, BRUTE)
	TEST_ASSERT(!finisher.running, "the finisher kept going through [finisher.interrupt_damage] damage")
	TEST_ASSERT_EQUAL(finisher.result, 3, "the finisher ended for the wrong reason") // HV_FINISHER_DAMAGED
	TEST_ASSERT(!finisher.completed, "the kill landed anyway")
	TEST_ASSERT_NOTNULL(victim.get_bodypart(zone), "the victim lost the arm anyway")
	TEST_ASSERT(!victim.has_status_effect(/datum/status_effect/hv_finisher_hold), "the victim is still held")
	TEST_ASSERT(matriarch.has_status_effect(/datum/status_effect/hv_finisher_reeling), "the matriarch didn't reel")
	health_before = matriarch.health
	matriarch.apply_damage(10, BRUTE)
	TEST_ASSERT_EQUAL(health_before - matriarch.health, 10, "the matriarch still takes extra damage after letting go")

/// Pulling the victim clear frees them; in the wind-up it costs only a short cooldown
/datum/unit_test/voidcrew_hv_finisher/pulled_clear

/datum/unit_test/voidcrew_hv_finisher/pulled_clear/Run()
	var/mob/living/basic/trooper/pirate/faction/boss/medieval/knight = allocate(/mob/living/basic/trooper/pirate/faction/boss/medieval, spot(1, 1))
	var/mob/living/carbon/human/consistent/victim = downed_human(spot(2, 1))
	var/datum/component/hv_finisher_user/finishing = knight.GetComponent(/datum/component/hv_finisher_user)
	var/datum/action/cooldown/mob_cooldown/hv_finisher/action = finishing.finisher_action
	TEST_ASSERT(action.Trigger(target = victim), "the knight couldn't start his finisher")
	var/datum/hv_finisher/finisher = action.active
	TEST_ASSERT_NOTNULL(finisher, "the ability started no finisher")
	TEST_ASSERT(!action.IsAvailable(), "the ability is ready again mid-finisher")
	victim.forceMove(spot(4, 1))
	TEST_ASSERT(!finisher.running, "the finisher went on with the victim out of reach")
	TEST_ASSERT_EQUAL(finisher.result, 2, "the finisher ended for the wrong reason") // HV_FINISHER_LOST_GRIP
	TEST_ASSERT_NULL(action.active, "the ability still thinks it's finishing")
	TEST_ASSERT_EQUAL(action.next_use_time - world.time, action.missed_cooldown, "a miss in the wind-up didn't cost the short cooldown")
	TEST_ASSERT(!victim.has_status_effect(/datum/status_effect/hv_finisher_hold), "the victim is still held")
	TEST_ASSERT(!knight.has_status_effect(/datum/status_effect/hv_finisher_reeling), "the knight reels from a miss")

/// However it breaks, the hold runs out: the finisher stops itself past its longest length
/datum/unit_test/voidcrew_hv_finisher/times_out

/datum/unit_test/voidcrew_hv_finisher/times_out/Run()
	var/mob/living/basic/hoarfrost_matriarch/matriarch = allocate(/mob/living/basic/hoarfrost_matriarch, spot(1, 1))
	var/mob/living/carbon/human/consistent/victim = downed_human(spot(2, 1))
	var/datum/hv_finisher/finisher = allocate(/datum/hv_finisher/hoarfrost, matriarch, victim)
	TEST_ASSERT(finisher.start(), "the finisher didn't start")
	finisher.advance()
	var/datum/status_effect/hv_finisher_hold/hold = victim.has_status_effect(/datum/status_effect/hv_finisher_hold)
	TEST_ASSERT_NOTNULL(hold, "the victim isn't held")
	TEST_ASSERT(hold.duration <= world.time + finisher.longest_duration(), "the hold outlasts the finisher's longest length")
	finisher.started_at = world.time - finisher.longest_duration() - 1
	finisher.tick()
	TEST_ASSERT(!finisher.running, "the finisher ran past its longest length")
	TEST_ASSERT_EQUAL(finisher.result, 6, "the finisher ended for the wrong reason") // HV_FINISHER_TIMED_OUT
	TEST_ASSERT(!victim.has_status_effect(/datum/status_effect/hv_finisher_hold), "the victim is still held")
	TEST_ASSERT(!HAS_TRAIT(matriarch, TRAIT_AI_PAUSED), "the matriarch's AI is still paused")

/// No finisher stage plays a hallucination, ghost or zombie sound, which sit wrong on a beast, a knight or a pirate,
/// and the matriarch's growl is a fixed, slowed animal growl rather than one the random pitch can squeak up.
/datum/unit_test/voidcrew_hv_finisher/sounds

/datum/unit_test/voidcrew_hv_finisher/sounds/Run()
	var/list/wrong_for_a_mob = list("hallucinations", "zombie", "ghost", "faithless")
	for(var/datum/hv_finisher_stage/stage_type as anything in typesof(/datum/hv_finisher_stage))
		for(var/sound_file in list(initial(stage_type.enter_sound), initial(stage_type.effect_sound)))
			if(!sound_file)
				continue
			for(var/word in wrong_for_a_mob)
				TEST_ASSERT(!findtext("[sound_file]", word), "[stage_type] plays [sound_file], which is a [word] sound")
	var/datum/hv_finisher_stage/windup/hoarfrost/growl = /datum/hv_finisher_stage/windup/hoarfrost
	TEST_ASSERT(findtext("[initial(growl.enter_sound)]", "non-humanoids"), "The matriarch's wind-up is not a beast sound")
	var/slowed = initial(growl.enter_frequency)
	TEST_ASSERT(slowed > 0 && slowed < 1, "The matriarch's growl is not slowed")
