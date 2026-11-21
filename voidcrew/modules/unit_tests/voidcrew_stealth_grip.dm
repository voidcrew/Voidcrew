// The hand over the mouth and the squeeze (voidcrew/modules/stealth/stealth_grip.dm), hands up (stealth_holdup.dm) and
// the cut throat's knockdown (hyperviolence/overlays_exec/knife_executions.dm). Unit tests compile before
// voidcrew/_DEFINES, so values are written out: trait source "stealth_grip", the squeeze lets go at 75 oxygen loss,
// HUMAN_NPC_RANK_BOSS 2, state "alert".

/// `holder` behind `guard`, hands empty, the mouth aimed at: the hand over his mouth, through tg's grab.
/datum/unit_test/proc/grip_clamp(mob/living/carbon/human/holder, mob/living/carbon/human/npc/guard)
	holder.zone_selected = BODY_ZONE_PRECISE_MOUTH
	TEST_ASSERT(stealth_grip_can_clamp(holder, guard), "Test fixture: can't put a hand over the guard's mouth")
	TEST_ASSERT(holder.grab(guard), "Test fixture: the grab didn't go through")
	var/datum/stealth_grip/grip = holder.stealth_grip_holding
	TEST_ASSERT_NOTNULL(grip, "Test fixture: no hand over the mouth")
	return grip

/// Who can be held: an unaware guard from behind with the mouth aimed at; not from the front, not with something in
/// hand, not an alert guard, not a person (tg's grab for them). Held: tg's neck grab on the holder's tile, mute, on his
/// feet in front, no struggling. Let go: free, alert on the holder, can speak.
/datum/unit_test/voidcrew_stealth_grip_clamp

/datum/unit_test/voidcrew_stealth_grip_clamp/Run()
	var/datum/turf_reservation/block = stealth_block(9, 9)
	TEST_ASSERT_NOTNULL(block, "No room for the test")
	var/mob/living/carbon/human/npc/guard = d45_bare_guard(block, 4, 1)
	var/datum/ai_controller/basic_controller/human_npc/stealth/guard_ai = stealth_ai(guard)
	var/mob/living/carbon/human/person = stealth_person(block, 3, 1)
	person.zone_selected = BODY_ZONE_CHEST
	TEST_ASSERT(!stealth_grip_can_clamp(person, guard), "A hand over the mouth with the chest aimed at")
	person.zone_selected = BODY_ZONE_PRECISE_MOUTH
	person.forceMove(stealth_at(block, 5, 1))
	TEST_ASSERT(!stealth_grip_can_clamp(person, guard), "A hand over the mouth from the front")
	person.forceMove(stealth_at(block, 3, 1))
	var/obj/item/pen/pen = allocate(/obj/item/pen)
	person.put_in_active_hand(pen, forced = TRUE)
	TEST_ASSERT(!stealth_grip_can_clamp(person, guard), "A hand over the mouth with something in that hand")
	qdel(pen)
	var/datum/stealth_grip/grip = grip_clamp(person, guard)
	TEST_ASSERT_EQUAL(person.pulling, guard, "The holder isn't holding the guard")
	TEST_ASSERT_EQUAL(person.grab_state, GRAB_NECK, "The hand over the mouth isn't tg's neck grab")
	TEST_ASSERT_EQUAL(guard.loc, person.loc, "The held guard isn't on the holder's tile")
	TEST_ASSERT(HAS_TRAIT_FROM(guard, TRAIT_MUTE, "stealth_grip") && !guard.can_speak(), "A guard with a hand over his mouth can speak")
	TEST_ASSERT(HAS_TRAIT(guard, TRAIT_IMMOBILIZED) && HAS_TRAIT(guard, TRAIT_HANDS_BLOCKED), "The held guard can move or use his hands")
	TEST_ASSERT_EQUAL(guard.body_position, STANDING_UP, "The held guard isn't held on his feet")
	TEST_ASSERT(guard.hostage_pose_dir, "The held guard isn't drawn held in front")
	TEST_ASSERT(guard.incapacitated & INCAPABLE_GRAB, "The held guard isn't incapacitated by the grab, as tg's grab leaves him")
	TEST_ASSERT_EQUAL(stealth_held_in_front(person), guard, "The held guard isn't held in front")
	var/datum/ai_planning_subtree/escape = GLOB.ai_subtrees[/datum/ai_planning_subtree/escape_captivity/stealth]
	TEST_ASSERT(guard_ai.planning_subtrees.Find(escape), "The guard doesn't plan with the stealth escape subtree")
	TEST_ASSERT(isnull(escape.SelectBehaviors(guard_ai, 1)), "The guard struggles against a hand over his mouth")
	// Let go: free, knows who it was, can talk.
	person.stop_pulling()
	TEST_ASSERT(QDELETED(grip), "Letting go didn't end the hold")
	TEST_ASSERT_NULL(person.stealth_grip_holding, "The holder is still marked holding")
	TEST_ASSERT(!HAS_TRAIT_FROM(guard, TRAIT_MUTE, "stealth_grip"), "The mute stayed after letting go")
	TEST_ASSERT_EQUAL(guard_ai.stealth_state(), "alert", "Let go, the guard isn't alert")
	TEST_ASSERT_EQUAL(guard_ai.blackboard[BB_BASIC_MOB_CURRENT_TARGET], person, "Let go, the guard isn't after the holder")
	// An alert guard: tg's grab.
	var/mob/living/carbon/human/npc/alert = d45_bare_guard(block, 4, 3)
	var/mob/living/carbon/human/other = stealth_person(block, 3, 3)
	var/datum/ai_controller/basic_controller/human_npc/stealth/alert_ai = stealth_ai(alert)
	alert_ai.stealth_go_alert(other)
	alert_ai.stealth_rewind(1)
	other.zone_selected = BODY_ZONE_PRECISE_MOUTH
	TEST_ASSERT(!stealth_grip_can_clamp(other, alert), "A hand over an alert guard's mouth")
	other.grab(alert)
	TEST_ASSERT_NULL(other.stealth_grip_holding, "A grab on an alert guard put a hand over his mouth")
	TEST_ASSERT_EQUAL(other.grab_state, GRAB_PASSIVE, "A grab on an alert guard wasn't tg's grab")
	// A person: tg's grab.
	var/mob/living/carbon/human/victim = stealth_person(block, 4, 5)
	victim.setDir(EAST)
	var/mob/living/carbon/human/grabber = stealth_person(block, 3, 5)
	grabber.zone_selected = BODY_ZONE_PRECISE_MOUTH
	TEST_ASSERT(!stealth_grip_can_clamp(grabber, victim), "A hand over a person's mouth")
	grabber.grab(victim)
	TEST_ASSERT_NULL(grabber.stealth_grip_holding, "A grab on a person put a hand over his mouth")
	TEST_ASSERT_EQUAL(grabber.grab_state, GRAB_PASSIVE, "A grab on a person wasn't tg's grab")
	// A sealed helmet keeps the hand off.
	var/mob/living/carbon/human/npc/sealed = d45_bare_guard(block, 4, 7)
	d45_helmet(sealed, /obj/item/clothing/head/helmet/space)
	var/mob/living/carbon/human/reacher = stealth_person(block, 3, 7)
	reacher.zone_selected = BODY_ZONE_PRECISE_MOUTH
	TEST_ASSERT(!stealth_grip_can_clamp(reacher, sealed), "A hand over the mouth through a sealed helmet")
	qdel(block)

/// From the hold: a gun makes him a hostage; a knife cuts on the click, and a cut throat goes down.
/datum/unit_test/voidcrew_stealth_grip_hostage_and_knife

/datum/unit_test/voidcrew_stealth_grip_hostage_and_knife/Run()
	var/datum/turf_reservation/block = stealth_block(8, 5)
	TEST_ASSERT_NOTNULL(block, "No room for the test")
	var/mob/living/carbon/human/npc/guard = d45_bare_guard(block, 4, 1)
	var/mob/living/carbon/human/person = stealth_person(block, 3, 1)
	grip_clamp(person, guard)
	TEST_ASSERT_NULL(stealth_hostage_of(person), "A hand over the mouth with no gun is a hostage")
	var/obj/item/gun/ballistic/automatic/pistol/pistol = allocate(/obj/item/gun/ballistic/automatic/pistol)
	person.put_in_inactive_hand(pistol, forced = TRUE)
	TEST_ASSERT_EQUAL(stealth_hostage_of(person), guard, "A hand over the mouth and a gun in the other hand isn't a hostage")
	TEST_ASSERT(guard.hostage_pose_dir, "The hostage isn't posed")
	person.stop_pulling()
	// The knife.
	var/mob/living/carbon/human/npc/second = d45_bare_guard(block, 4, 3)
	var/mob/living/carbon/human/cutter = stealth_person(block, 3, 3)
	grip_clamp(cutter, second)
	var/obj/item/knife/combat/knife = allocate(/obj/item/knife/combat)
	cutter.put_in_active_hand(knife, forced = TRUE)
	cutter.set_combat_mode(TRUE)
	cutter.zone_selected = BODY_ZONE_CHEST
	TEST_ASSERT(knife.hv_knife_execution_possible(cutter, second), "A knife can't cut a guard held with a hand over his mouth")
	TEST_ASSERT(knife.hv_knife_execution_instant(cutter, second), "A guard held with a hand over his mouth waits for the hold")
	knife.melee_attack_chain(cutter, second, list())
	TEST_ASSERT(second.has_status_effect(/datum/status_effect/neck_slice), "The cut didn't land on a held guard")
	TEST_ASSERT(second.IsKnockdown(), "A cut throat didn't go down")
	TEST_ASSERT(!second.can_speak(), "A cut throat can speak")
	qdel(block)

/// The squeeze from the hold: tg's strangle, out and let go alive; a helmet slows it.
/datum/unit_test/voidcrew_stealth_grip_squeeze

/datum/unit_test/voidcrew_stealth_grip_squeeze/Run()
	var/datum/turf_reservation/block = stealth_block(8, 5)
	TEST_ASSERT_NOTNULL(block, "No room for the test")
	var/mob/living/carbon/human/npc/guard = d45_bare_guard(block, 4, 1)
	var/mob/living/carbon/human/person = stealth_person(block, 3, 1)
	var/datum/stealth_grip/grip = grip_clamp(person, guard)
	TEST_ASSERT(person.grab(guard), "The second grab click didn't go through")
	TEST_ASSERT(grip.squeezing, "The second grab click didn't squeeze")
	TEST_ASSERT_EQUAL(person.grab_state, GRAB_KILL, "The squeeze isn't tg's strangle")
	TEST_ASSERT_EQUAL(grip.oxy_rate, 4, "A bare neck doesn't take the squeeze's full rate")
	for(var/i in 1 to 30)
		if(QDELETED(grip))
			break
		grip.squeeze_tick(1)
	TEST_ASSERT(QDELETED(grip), "The squeeze never let go")
	TEST_ASSERT_NULL(person.pulling, "The squeeze let go but still holds him")
	TEST_ASSERT(guard.stat != DEAD, "The squeeze killed")
	TEST_ASSERT(HAS_TRAIT(guard, TRAIT_KNOCKEDOUT), "The squeeze let go before he was out")
	TEST_ASSERT(guard.getOxyLoss() >= 75, "The squeeze let go at [guard.getOxyLoss()] oxygen loss")
	TEST_ASSERT(!HAS_TRAIT_FROM(guard, TRAIT_MUTE, "stealth_grip"), "The mute outlived the hold")
	// A sec helmet slows it.
	var/mob/living/carbon/human/npc/helmeted = d45_bare_guard(block, 4, 3)
	d45_helmet(helmeted, /obj/item/clothing/head/helmet/sec)
	var/mob/living/carbon/human/strangler = stealth_person(block, 3, 3)
	var/datum/stealth_grip/slow = grip_clamp(strangler, helmeted)
	strangler.grab(helmeted)
	TEST_ASSERT(slow.squeezing, "The squeeze didn't close on a sec helmet")
	TEST_ASSERT(slow.oxy_rate < 4 && slow.oxy_rate > 0, "A sec helmet left the squeeze at [slow.oxy_rate] a second")
	strangler.stop_pulling()
	// A badly hurt guard is let go before tg's full crit would go on choking him.
	var/mob/living/carbon/human/npc/hurt = d45_bare_guard(block, 6, 3)
	hurt.apply_damage(60, BRUTE, BODY_ZONE_CHEST)
	var/mob/living/carbon/human/choker = stealth_person(block, 5, 3)
	var/datum/stealth_grip/deep = grip_clamp(choker, hurt)
	choker.grab(hurt)
	TEST_ASSERT(deep.squeezing, "The squeeze didn't close on a hurt guard")
	for(var/i in 1 to 30)
		if(QDELETED(deep))
			break
		deep.squeeze_tick(1)
	TEST_ASSERT(QDELETED(deep), "The squeeze never let a hurt guard go")
	TEST_ASSERT(hurt.health > HEALTH_THRESHOLD_FULLCRIT, "The squeeze let a hurt guard go in full crit ([hurt.health] health)")
	qdel(block)

/// A gun on a guard (tg's hold-up): hands up, holds still for a grab, makes his move once nobody covers him. A boss and
/// an armed alert guard refuse.
/datum/unit_test/voidcrew_stealth_holdup

/datum/unit_test/voidcrew_stealth_holdup/Run()
	var/datum/turf_reservation/block = stealth_block(10, 7)
	TEST_ASSERT_NOTNULL(block, "No room for the test")
	var/mob/living/carbon/human/npc/guard = stealth_guard(block, 4, 1, WEST)
	var/datum/ai_controller/basic_controller/human_npc/stealth/guard_ai = stealth_ai(guard)
	var/datum/ai_planning_subtree/holdup = GLOB.ai_subtrees[/datum/ai_planning_subtree/stealth_holdup]
	var/at = guard_ai.planning_subtrees.Find(holdup)
	TEST_ASSERT(at, "The hands-up subtree isn't in the guard's planning")
	TEST_ASSERT(at < guard_ai.planning_subtrees.Find(GLOB.ai_subtrees[/datum/ai_planning_subtree/human_npc_arm]), "The hands-up subtree comes after arming")
	var/mob/living/carbon/human/person = stealth_person(block, 2, 1)
	var/obj/item/gun/ballistic/automatic/pistol/pistol = allocate(/obj/item/gun/ballistic/automatic/pistol)
	pistol.can_misfire = FALSE
	person.put_in_active_hand(pistol, forced = TRUE)
	person.AddComponent(/datum/component/gunpoint, guard, pistol)
	TEST_ASSERT_EQUAL(guard_ai.holdup_aimer?.resolve(), person, "Held up, the guard didn't give up")
	TEST_ASSERT(guard.npc_surrendering && guard.IsParalyzed(), "Held up, the guard didn't surrender")
	TEST_ASSERT(!guard_ai.stealth_scanning(), "A guard with his hands up still scans")
	TEST_ASSERT_EQUAL(holdup.SelectBehaviors(guard_ai, 1), SUBTREE_RETURN_FINISH_PLANNING, "A guard with his hands up plans on")
	// Walk up and take him: tg drops the aim, he stays put while held.
	person.forceMove(stealth_at(block, 3, 1))
	person.start_pulling(guard, supress_message = TRUE)
	TEST_ASSERT_NULL(person.GetComponent(/datum/component/gunpoint), "Test fixture: tg kept the aim through a grab")
	TEST_ASSERT(guard_ai.stealth_holdup_covered(), "A guard held by the one he gave up to isn't covered")
	var/datum/ai_planning_subtree/escape = GLOB.ai_subtrees[/datum/ai_planning_subtree/escape_captivity/stealth]
	TEST_ASSERT(isnull(escape.SelectBehaviors(guard_ai, 1)), "A guard with his hands up struggles against a grab")
	guard_ai.stealth_holdup_check()
	TEST_ASSERT(guard_ai.holdup_aimer, "A held guard made his move")
	// Let go and walk off: his move.
	person.stop_pulling()
	person.forceMove(stealth_at(block, 0, 1))
	guard_ai.stealth_holdup_check()
	TEST_ASSERT_NULL(guard_ai.holdup_aimer, "Nobody covering him, the guard kept his hands up")
	TEST_ASSERT(guard.IsParalyzed(), "Nobody covering him, the guard's surrender was cut short (tg's Paralyze runs its time)")
	TEST_ASSERT_EQUAL(guard_ai.stealth_state(), "alert", "Nobody covering him, the guard isn't alert")
	TEST_ASSERT_EQUAL(guard_ai.blackboard[BB_BASIC_MOB_CURRENT_TARGET], person, "Nobody covering him, the guard isn't after the aimer")
	// A boss doesn't give up.
	var/mob/living/carbon/human/npc/boss = stealth_guard(block, 4, 3, WEST)
	boss.npc_rank = 2
	var/mob/living/carbon/human/boss_aimer = stealth_person(block, 2, 3)
	var/obj/item/gun/ballistic/automatic/pistol/boss_pistol = allocate(/obj/item/gun/ballistic/automatic/pistol)
	boss_aimer.put_in_active_hand(boss_pistol, forced = TRUE)
	boss_aimer.AddComponent(/datum/component/gunpoint, boss, boss_pistol)
	var/datum/ai_controller/basic_controller/human_npc/stealth/boss_ai = stealth_ai(boss)
	TEST_ASSERT_NULL(boss_ai.holdup_aimer, "A boss gave up")
	TEST_ASSERT(!boss.npc_surrendering, "A boss surrendered")
	TEST_ASSERT_EQUAL(boss_ai.stealth_state(), "alert", "A boss held up didn't go alert")
	// An alert guard with a weapon drawn doesn't give up.
	var/mob/living/carbon/human/npc/armed = stealth_guard(block, 8, 5, WEST)
	var/mob/living/carbon/human/armed_aimer = stealth_person(block, 6, 5)
	var/datum/ai_controller/basic_controller/human_npc/stealth/armed_ai = stealth_ai(armed)
	var/obj/item/gun/ballistic/automatic/pistol/drawn = allocate(/obj/item/gun/ballistic/automatic/pistol)
	armed.drop_all_held_items()
	armed.put_in_active_hand(drawn, forced = TRUE)
	armed_ai.stealth_go_alert(armed_aimer)
	var/obj/item/gun/ballistic/automatic/pistol/aimed = allocate(/obj/item/gun/ballistic/automatic/pistol)
	armed_aimer.put_in_active_hand(aimed, forced = TRUE)
	armed_aimer.AddComponent(/datum/component/gunpoint, armed, aimed)
	TEST_ASSERT_NULL(armed_ai.holdup_aimer, "An alert guard with a gun drawn gave up")
	qdel(block)

/// A cut throat goes down for a moment: anyone, a player as much as a guard.
/datum/unit_test/voidcrew_hv_knife_throat_knockdown

/datum/unit_test/voidcrew_hv_knife_throat_knockdown/Run()
	var/datum/turf_reservation/block = stealth_block(6, 3)
	TEST_ASSERT_NOTNULL(block, "No room for the test")
	var/mob/living/carbon/human/victim = stealth_person(block, 3, 1)
	victim.setDir(EAST)
	var/mob/living/carbon/human/attacker = stealth_person(block, 2, 1)
	attacker.setDir(EAST)
	var/obj/item/knife/combat/knife = allocate(/obj/item/knife/combat)
	attacker.put_in_active_hand(knife, forced = TRUE)
	attacker.set_combat_mode(TRUE)
	attacker.zone_selected = BODY_ZONE_HEAD
	TEST_ASSERT(knife.hv_finish_knife_execution(attacker, victim), "The cut didn't land")
	TEST_ASSERT(victim.has_status_effect(/datum/status_effect/neck_slice), "The cut didn't cut the throat")
	TEST_ASSERT(victim.IsKnockdown(), "A person with a cut throat didn't go down")
	qdel(block)
