// Step 3b: the garrotte and the chokehold (voidcrew/modules/stealth/stealth_takedown.dm, stealth_garrotte.dm). Unit tests
// compile before voidcrew/_DEFINES, so values are written out: the garrotte 8 oxygen a second, the chokehold 4, the
// chokehold lets go at 75, no hold through cover 60.

/// A garrotte in both of `person`'s hands, combat mode on.
/datum/unit_test/proc/takedown_garrotte(mob/living/carbon/human/person)
	var/obj/item/garrotte/wire = allocate(/obj/item/garrotte)
	person.put_in_active_hand(wire, forced = TRUE)
	person.set_combat_mode(TRUE)
	return wire

/// Who can be taken: from behind an unaware guard, not from the front, not an alert guard, a person from behind, not
/// through a sealed helmet; the chokehold wants an empty hand and the garrotte both.
/datum/unit_test/voidcrew_stealth_takedown_who

/datum/unit_test/voidcrew_stealth_takedown_who/Run()
	var/datum/turf_reservation/block = stealth_block(9, 9)
	TEST_ASSERT_NOTNULL(block, "No room for the test")
	var/mob/living/carbon/human/npc/guard = d45_bare_guard(block, 4, 1)
	var/mob/living/carbon/human/person = stealth_person(block, 3, 1)
	var/obj/item/garrotte/wire = takedown_garrotte(person)
	TEST_ASSERT(HAS_TRAIT(wire, TRAIT_WIELDED), "The garrotte isn't held in both hands")
	TEST_ASSERT_NULL(stealth_takedown_refusal(person, guard, "garrotte", wire), "The garrotte can't take an unaware guard from behind")
	person.forceMove(stealth_at(block, 5, 1))
	TEST_ASSERT_EQUAL(stealth_takedown_refusal(person, guard, "garrotte", wire), "front", "The garrotte takes a guard from the front")
	person.forceMove(stealth_at(block, 3, 1))
	TEST_ASSERT_EQUAL(stealth_takedown_refusal(person, guard, "choke"), "no", "A chokehold with a garrotte in hand")
	// An alert guard is on guard, even from behind.
	var/mob/living/carbon/human/npc/alert = d45_bare_guard(block, 4, 3)
	var/mob/living/carbon/human/other = stealth_person(block, 3, 3)
	other.set_combat_mode(TRUE)
	var/datum/ai_controller/basic_controller/human_npc/stealth/alert_ai = stealth_ai(alert)
	alert_ai.stealth_go_alert(other)
	TEST_ASSERT_EQUAL(stealth_takedown_refusal(other, alert, "choke"), "front", "An alert guard can be choked from behind")
	// A person (no awareness) from behind can (decision 22), from the front can't.
	var/mob/living/carbon/human/victim = stealth_person(block, 4, 5)
	victim.setDir(EAST)
	var/mob/living/carbon/human/choker = stealth_person(block, 3, 5)
	choker.set_combat_mode(TRUE)
	TEST_ASSERT_NULL(stealth_takedown_refusal(choker, victim, "choke"), "A person can't be choked from behind")
	victim.setDir(WEST)
	TEST_ASSERT_EQUAL(stealth_takedown_refusal(choker, victim, "choke"), "front", "A person facing you can be choked")
	// ...unless he is helpless.
	victim.Paralyze(10 SECONDS)
	TEST_ASSERT_NULL(stealth_takedown_refusal(choker, victim, "choke"), "A paralysed person can't be choked")
	victim.SetParalyzed(0)
	victim.setDir(EAST)
	// A sealed helmet stops both.
	var/obj/item/clothing/head/helmet/space/sealed = new(victim)
	TEST_ASSERT(victim.equip_to_slot_if_possible(sealed, ITEM_SLOT_HEAD, disable_warning = TRUE), "Couldn't put on the space helmet")
	TEST_ASSERT_EQUAL(stealth_takedown_refusal(choker, victim, "choke"), "cover", "A chokehold through a sealed helmet")
	// No combat mode, no takedown: a grab is tg's grab.
	var/mob/living/carbon/human/npc/calm = d45_bare_guard(block, 4, 7)
	var/mob/living/carbon/human/puller = stealth_person(block, 3, 7)
	puller.set_combat_mode(FALSE)
	puller.grab(calm)
	TEST_ASSERT_NULL(puller.stealth_takedown_doing, "A grab out of combat mode started a takedown")
	TEST_ASSERT_EQUAL(puller.grab_state, GRAB_PASSIVE, "A grab out of combat mode wasn't tg's pull")

/// The garrotte closes tg's strangle at once: floored, mute, oxygen loss each second, out at 50,
/// dead if never let go, then let go. Letting go early ends it.
/datum/unit_test/voidcrew_stealth_takedown_garrotte

/datum/unit_test/voidcrew_stealth_takedown_garrotte/Run()
	var/datum/turf_reservation/block = stealth_block(8, 5)
	TEST_ASSERT_NOTNULL(block, "No room for the test")
	var/mob/living/carbon/human/npc/guard = d45_bare_guard(block, 4, 1)
	var/mob/living/carbon/human/person = stealth_person(block, 3, 1)
	var/obj/item/garrotte/wire = takedown_garrotte(person)
	var/datum/stealth_takedown/hold = new(person, guard, "garrotte", wire)
	TEST_ASSERT(hold.close(), "The garrotte didn't close")
	TEST_ASSERT_EQUAL(person.grab_state, GRAB_KILL, "The garrotte isn't tg's strangle")
	TEST_ASSERT_EQUAL(person.pulling, guard, "The garroter isn't holding the guard")
	TEST_ASSERT(!HAS_TRAIT(guard, TRAIT_FLOORED) && guard.body_position == STANDING_UP, "The garrotted guard isn't held on his feet")
	TEST_ASSERT(HAS_TRAIT(guard, TRAIT_IMMOBILIZED) && HAS_TRAIT(guard, TRAIT_HANDS_BLOCKED), "The garrotted guard can move or use his hands")
	TEST_ASSERT(HAS_TRAIT(guard, TRAIT_MUTE) && !guard.can_speak(), "A garrotted guard can speak")
	TEST_ASSERT_EQUAL(hold.oxy_rate, 8, "A bare neck doesn't take the garrotte's full rate")
	for(var/i in 1 to 7)
		hold.hold_tick(1)
	TEST_ASSERT(guard.getOxyLoss() >= 50, "Seven seconds of the garrotte left the guard at [guard.getOxyLoss()] oxygen loss")
	TEST_ASSERT(guard.stat >= UNCONSCIOUS, "The garrotte didn't put the guard out")
	TEST_ASSERT(guard.body_position == LYING_DOWN, "The guard didn't go down when he passed out")
	for(var/i in 1 to 25)
		if(QDELETED(hold))
			break
		hold.hold_tick(1)
	TEST_ASSERT_EQUAL(guard.stat, DEAD, "A garrotte never let go didn't kill")
	TEST_ASSERT(QDELETED(hold), "The garrotte held on past death")
	TEST_ASSERT_NULL(person.pulling, "The garroter still holds the body")
	TEST_ASSERT(!HAS_TRAIT_FROM(guard, TRAIT_MUTE, "stealth_takedown"), "The mute outlived the hold")
	// Letting go early: tg's stop_pulling() ends it, and the mute with it.
	var/mob/living/carbon/human/npc/second = d45_bare_guard(block, 4, 3)
	var/mob/living/carbon/human/strangler = stealth_person(block, 3, 3)
	var/obj/item/garrotte/other_wire = takedown_garrotte(strangler)
	var/datum/stealth_takedown/other_hold = new(strangler, second, "garrotte", other_wire)
	TEST_ASSERT(other_hold.close(), "The second garrotte didn't close")
	strangler.stop_pulling()
	TEST_ASSERT(QDELETED(other_hold), "Letting go didn't end the garrotte")
	TEST_ASSERT(!HAS_TRAIT_FROM(second, TRAIT_MUTE, "stealth_takedown"), "The mute stayed after letting go")
	TEST_ASSERT_NULL(strangler.stealth_takedown_doing, "The garroter is still marked busy")
	// A wire that's destroyed lets go too.
	var/mob/living/carbon/human/npc/third = d45_bare_guard(block, 7, 3)
	var/mob/living/carbon/human/cutter = stealth_person(block, 6, 3)
	var/obj/item/garrotte/third_wire = takedown_garrotte(cutter)
	var/datum/stealth_takedown/third_hold = new(cutter, third, "garrotte", third_wire)
	TEST_ASSERT(third_hold.close(), "The third garrotte didn't close")
	qdel(third_wire)
	TEST_ASSERT(QDELETED(third_hold), "A destroyed garrotte didn't end the hold")
	TEST_ASSERT_NULL(cutter.pulling, "A destroyed garrotte still holds him")
	TEST_ASSERT(!HAS_TRAIT_FROM(third, TRAIT_MUTE, "stealth_takedown"), "The mute stayed after the wire was destroyed")

/// The chokehold puts him out and lets go by itself, alive; a helmet slows the garrotte.
/datum/unit_test/voidcrew_stealth_takedown_choke

/datum/unit_test/voidcrew_stealth_takedown_choke/Run()
	var/datum/turf_reservation/block = stealth_block(8, 5)
	TEST_ASSERT_NOTNULL(block, "No room for the test")
	var/mob/living/carbon/human/npc/guard = d45_bare_guard(block, 4, 1)
	var/mob/living/carbon/human/person = stealth_person(block, 3, 1)
	person.set_combat_mode(TRUE)
	var/datum/stealth_takedown/hold = new(person, guard, "choke")
	TEST_ASSERT(hold.close(), "The chokehold didn't close")
	TEST_ASSERT_EQUAL(person.grab_state, GRAB_KILL, "The chokehold isn't tg's strangle")
	for(var/i in 1 to 30)
		if(QDELETED(hold))
			break
		hold.hold_tick(1)
	TEST_ASSERT(QDELETED(hold), "The chokehold never let go")
	TEST_ASSERT_NULL(person.pulling, "The chokehold let go but still holds him")
	TEST_ASSERT(guard.stat != DEAD, "The chokehold killed")
	TEST_ASSERT(HAS_TRAIT(guard, TRAIT_KNOCKEDOUT), "The chokehold let go before he was out")
	TEST_ASSERT(guard.getOxyLoss() >= 75, "The chokehold let go at [guard.getOxyLoss()] oxygen loss")
	// A sec helmet (melee 35) slows the wire to 65%.
	var/mob/living/carbon/human/npc/helmeted = d45_bare_guard(block, 4, 3)
	d45_helmet(helmeted, /obj/item/clothing/head/helmet/sec)
	var/mob/living/carbon/human/strangler = stealth_person(block, 3, 3)
	var/obj/item/garrotte/wire = takedown_garrotte(strangler)
	var/datum/stealth_takedown/slow = new(strangler, helmeted, "garrotte", wire)
	TEST_ASSERT(slow.close(), "The garrotte didn't close on a sec helmet")
	TEST_ASSERT(slow.oxy_rate < 8 && slow.oxy_rate > 4, "A sec helmet left the garrotte at [slow.oxy_rate] a second")
	strangler.stop_pulling()
