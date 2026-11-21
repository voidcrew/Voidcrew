// Stealth guards, decision 40: disguises (voidcrew/modules/stealth/stealth_disguise.dm). Values from voidcrew/_DEFINES are
// written out: pieces mask 1, clothing 2, pass 4; fill x0.5 clothing, x0.25 with a mask, x0.05 the whole set inside near
// range (4) and 0 beyond; challenge range 5 / 3 / 2; the pass is read for 2 s, asked for again at 3 s, blown at 6 s;
// more than 2 tiles from where they were stopped is walking off. States and bark kinds are written as text.
// The tests down to voidcrew_stealth_disguise_loot call the scan directly; the voidcrew_stealth_live ones run the real AI.

/// Puts the scavs' own things on `person`: the fatigues, a balaclava, a pass.
/datum/unit_test/proc/stealth_dress(mob/living/carbon/human/person, uniform = TRUE, mask = TRUE, card = TRUE)
	if(uniform)
		person.equip_to_slot_or_del(new /obj/item/clothing/under/syndicate/scav(person), ITEM_SLOT_ICLOTHING)
	if(mask)
		person.equip_to_slot_or_del(new /obj/item/clothing/mask/balaclava/scav(person), ITEM_SLOT_MASK)
	if(card)
		person.equip_to_slot_or_del(new /obj/item/card/id/advanced/black/scav(person), ITEM_SLOT_ID)

/// The guard's notice of `person`, 0 if it has none.
/datum/unit_test/proc/stealth_notice_of(mob/living/guard, mob/living/person)
	var/datum/ai_controller/basic_controller/human_npc/stealth/stealth_ai = guard.ai_controller
	var/list/entry = stealth_ai.notice_map?[REF(person)]
	return entry ? entry[1] : 0

/// What counts as each piece, and that changing clothes is seen at once.
/datum/unit_test/voidcrew_stealth_disguise_pieces

/datum/unit_test/voidcrew_stealth_disguise_pieces/Run()
	var/datum/turf_reservation/block = stealth_block(3, 3)
	TEST_ASSERT_NOTNULL(block, "No room for the test")
	var/mob/living/carbon/human/person = stealth_person(block, 1, 1)
	TEST_ASSERT_EQUAL(stealth_disguise_of(person), 0, "Someone in nothing of theirs wears a piece")
	stealth_dress(person, TRUE, FALSE, FALSE)
	TEST_ASSERT_EQUAL(stealth_disguise_of(person), 2, "The fatigues aren't the clothing piece")
	stealth_dress(person, FALSE, TRUE, FALSE)
	TEST_ASSERT_EQUAL(stealth_disguise_of(person), 3, "A balaclava over the fatigues isn't clothing and mask")
	stealth_dress(person, FALSE, FALSE, TRUE)
	TEST_ASSERT_EQUAL(stealth_disguise_of(person), 7, "The pass in the ID slot isn't the ID piece")
	TEST_ASSERT_EQUAL(stealth_disguise_stage(7), 4, "The whole set isn't stage 4")
	TEST_ASSERT_EQUAL(stealth_disguise_stage(3), 3, "Clothing and mask isn't stage 3")
	TEST_ASSERT_EQUAL(stealth_disguise_stage(6), 2, "Clothing and pass with a bare face isn't stage 2")
	TEST_ASSERT_EQUAL(stealth_disguise_stage(1), 1, "A mask alone isn't stage 1")
	// The vest the guards wear over theirs keeps the clothing; a coat they don't wear loses it.
	TEST_ASSERT(stealth_guard_suits()[/obj/item/clothing/suit/armor/vest], "The guards' own vest isn't read from their outfits")
	var/obj/item/clothing/suit/vest = new /obj/item/clothing/suit/armor/vest(person)
	TEST_ASSERT(person.equip_to_slot_if_possible(vest, ITEM_SLOT_OCLOTHING), "The vest wouldn't go on")
	TEST_ASSERT_EQUAL(stealth_disguise_of(person), 7, "The guards' own vest over the fatigues lost the clothing piece")
	TEST_ASSERT(person.dropItemToGround(vest), "The vest wouldn't come off")
	var/obj/item/clothing/suit/coat = new /obj/item/clothing/suit/toggle/labcoat(person)
	TEST_ASSERT(person.equip_to_slot_if_possible(coat, ITEM_SLOT_OCLOTHING), "The coat wouldn't go on")
	TEST_ASSERT_EQUAL(stealth_disguise_of(person), 5, "A lab coat over the fatigues still passes for the guards' dress")
	TEST_ASSERT(person.dropItemToGround(coat), "The coat wouldn't come off")
	TEST_ASSERT_EQUAL(stealth_disguise_of(person), 7, "Taking the coat off didn't bring the clothing piece back")
	// Any mask that hides the face is the mask; a bare face is none.
	TEST_ASSERT(person.dropItemToGround(person.wear_mask), "The balaclava wouldn't come off")
	TEST_ASSERT_EQUAL(stealth_disguise_of(person), 6, "A bare face still counts as masked")
	person.equip_to_slot_or_del(new /obj/item/clothing/mask/gas(person), ITEM_SLOT_MASK)
	TEST_ASSERT_EQUAL(stealth_disguise_of(person), 7, "A gas mask doesn't hide the face")
	// The fatigues off: the pass drops with them, and only the mask is left.
	TEST_ASSERT(person.dropItemToGround(person.w_uniform), "The fatigues wouldn't come off")
	TEST_ASSERT_EQUAL(stealth_disguise_of(person), 1, "With the fatigues off something but the mask still counts")
	person.equip_to_slot_or_del(new /obj/item/clothing/under/color/grey(person), ITEM_SLOT_ICLOTHING)
	TEST_ASSERT_EQUAL(stealth_disguise_of(person), 1, "A grey jumpsuit passes for the guards' dress")
	qdel(block)

/// Each stage's notice fill at 6 tiles in the light, and the same through the green and red skills.
/datum/unit_test/voidcrew_stealth_disguise_fill

/datum/unit_test/voidcrew_stealth_disguise_fill/Run()
	var/datum/turf_reservation/block = stealth_block(20, 5)
	TEST_ASSERT_NOTNULL(block, "No room for the test")
	// uniform, mask, card, share of the plain fill (0.375 a scan for a yellow guard at 6 tiles)
	var/list/cases = list(
		list(FALSE, FALSE, FALSE, 1),
		list(FALSE, TRUE, FALSE, 1),
		list(TRUE, FALSE, FALSE, 0.5),
		list(TRUE, TRUE, FALSE, 0.25),
		list(TRUE, FALSE, TRUE, 0.5),
		list(TRUE, TRUE, TRUE, 0),
	)
	for(var/list/test_case as anything in cases)
		var/mob/living/carbon/human/npc/guard = stealth_guard(block, 6, 2)
		var/mob/living/carbon/human/person = stealth_person(block, 12, 2)
		stealth_dress(person, test_case[1], test_case[2], test_case[3])
		stealth_scans(guard, 1)
		var/expected = 0.375 * test_case[4]
		var/found = stealth_notice_of(guard, person)
		TEST_ASSERT(abs(found - expected) < 0.001, "Fatigues [test_case[1]], mask [test_case[2]], pass [test_case[3]]: one look at 6 tiles gave [found] notice, not [expected]")
		qdel(guard)
		qdel(person)
	// Skill: clothing and mask fills at a quarter of the guard's plain rate, times 0.6 green, 1 yellow, 1.6 red.
	var/list/scales = list(/datum/stealth_skill/green = 0.6, /datum/stealth_skill/yellow = 1, /datum/stealth_skill/red = 1.6)
	var/last = 0
	for(var/skill_type in scales)
		var/mob/living/carbon/human/npc/guard = stealth_guard(block, 6, 2)
		guard.stealth_skill = skill_type
		var/mob/living/carbon/human/person = stealth_person(block, 12, 2)
		stealth_scans(guard, 1)
		var/plain = stealth_notice_of(guard, person)
		qdel(guard)
		guard = stealth_guard(block, 6, 2)
		guard.stealth_skill = skill_type
		stealth_dress(person, TRUE, TRUE, FALSE)
		stealth_scans(guard, 1)
		var/found = stealth_notice_of(guard, person)
		TEST_ASSERT(plain > 0, "[skill_type]: a plain person 6 tiles in front wasn't noticed at all")
		TEST_ASSERT(abs(found - plain * 0.25 * scales[skill_type]) < 0.001, "[skill_type]: clothing and mask gave [found] notice against [plain] plain")
		TEST_ASSERT(found > last, "[skill_type] is fooled no less than the skill below it")
		last = found
		qdel(guard)
		qdel(person)
	qdel(block)

/// The whole set: one of their own at range, a greeting nearer, and a challenge only for lingering close.
/datum/unit_test/voidcrew_stealth_disguise_friend

/datum/unit_test/voidcrew_stealth_disguise_friend/Run()
	var/datum/turf_reservation/block = stealth_block(20, 5)
	TEST_ASSERT_NOTNULL(block, "No room for the test")
	var/mob/living/carbon/human/npc/guard = stealth_guard(block, 6, 2)
	var/datum/ai_controller/basic_controller/human_npc/stealth/stealth_ai = stealth_ai(guard)
	var/mob/living/carbon/human/person = stealth_person(block, 12, 2)
	stealth_dress(person)
	stealth_scans(guard, 30)
	TEST_ASSERT_EQUAL(stealth_ai.stealth_state(), "unaware", "A guard grew suspicious of someone in the whole set 6 tiles off")
	TEST_ASSERT_EQUAL(stealth_notice_of(guard, person), 0, "Someone in the whole set 6 tiles off gained notice")
	TEST_ASSERT(guard.npc_last_bark != "stealth_greet" && guard.npc_last_bark != "stealth_smoke", "A guard greeted someone 6 tiles off")
	// Three tiles off: inside its near range, outside its challenge range. A word, and a slow fill.
	person.forceMove(stealth_at(block, 9, 2))
	stealth_scans(guard, 1)
	TEST_ASSERT_EQUAL(stealth_ai.stealth_state(), "unaware", "A guard did more than greet someone in the whole set 3 tiles off")
	TEST_ASSERT(guard.npc_last_bark == "stealth_greet" || guard.npc_last_bark == "stealth_smoke", "A guard had no word for one of its own 3 tiles off")
	var/found = stealth_notice_of(guard, person)
	TEST_ASSERT(abs(found - 0.1125) < 0.001, "One look at the whole set 3 tiles off gave [found] notice, not 0.1125")
	TEST_ASSERT_NULL(stealth_ai.challenge, "A guard stopped someone in the whole set 3 tiles off on its first look")
	// They stay: in the end it stops them.
	stealth_scans(guard, 30)
	TEST_ASSERT_EQUAL(stealth_ai.stealth_state(), "suspicious", "A guard never stopped someone in the whole set who stood 3 tiles in front of it")
	TEST_ASSERT_EQUAL(stealth_ai.challenge?.resolve(), person, "The suspicious guard hasn't stopped the one who lingered")
	TEST_ASSERT_NULL(stealth_ai.blackboard[BB_BASIC_MOB_CURRENT_TARGET], "A guard took a target in a disguise that held")
	qdel(block)

/// Up close with the pass: stopped, checked for 2 s, waved on, and then left alone by that guard.
/datum/unit_test/voidcrew_stealth_disguise_pass

/datum/unit_test/voidcrew_stealth_disguise_pass/Run()
	var/datum/turf_reservation/block = stealth_block(20, 5)
	TEST_ASSERT_NOTNULL(block, "No room for the test")
	var/mob/living/carbon/human/npc/guard = stealth_guard(block, 6, 2)
	var/datum/ai_controller/basic_controller/human_npc/stealth/stealth_ai = stealth_ai(guard)
	var/mob/living/carbon/human/person = stealth_person(block, 8, 2)
	stealth_dress(person)
	stealth_scans(guard, 1)
	TEST_ASSERT_EQUAL(stealth_ai.stealth_state(), "suspicious", "A guard didn't stop someone in the whole set 2 tiles in front of it")
	TEST_ASSERT_EQUAL(stealth_ai.challenge?.resolve(), person, "The guard hasn't stopped the person in front of it")
	TEST_ASSERT_EQUAL(guard.npc_last_bark, "stealth_challenge", "The guard stopped them without a word")
	TEST_ASSERT_NULL(stealth_ai.blackboard[BB_BASIC_MOB_CURRENT_TARGET], "Stopping someone gave the guard a target")
	stealth_scans(guard, 1)
	TEST_ASSERT(stealth_ai.checked_at, "The guard isn't reading the pass of someone 2 tiles off")
	TEST_ASSERT_EQUAL(stealth_ai.stealth_state(), "suspicious", "The guard was done with the pass in no time")
	stealth_ai.stealth_rewind(2 SECONDS)
	stealth_scans(guard, 1)
	TEST_ASSERT_EQUAL(stealth_ai.stealth_state(), "unaware", "A guard that read a good pass for 2 s didn't let them go")
	TEST_ASSERT_EQUAL(guard.npc_last_bark, "stealth_id_pass", "The guard let them go without a word")
	TEST_ASSERT(stealth_ai.passes[REF(person)] > world.time, "The guard doesn't remember the pass it read")
	stealth_scans(guard, 10)
	TEST_ASSERT_EQUAL(stealth_ai.stealth_state(), "unaware", "A guard stopped someone again right after reading their pass")
	TEST_ASSERT_EQUAL(stealth_notice_of(guard, person), 0, "Someone it has passed gained notice")
	// The pass comes off a while later: the guard's leave goes with it.
	stealth_ai.stealth_rewind(61 SECONDS)
	TEST_ASSERT(person.dropItemToGround(person.wear_id), "The pass wouldn't come off")
	stealth_scans(guard, 1)
	TEST_ASSERT_EQUAL(stealth_ai.challenge?.resolve(), person, "With the pass gone the guard didn't stop them again")
	qdel(block)

/// Taking the pass off and on to pull a guard over: a second stop within 60 s of a wave, or a third within 5 min, sees
/// through them. Waves older than 5 min are forgotten.
/datum/unit_test/voidcrew_stealth_disguise_recheck

/datum/unit_test/voidcrew_stealth_disguise_recheck/Run()
	var/datum/turf_reservation/block = stealth_block(20, 5)
	TEST_ASSERT_NOTNULL(block, "No room for the test")
	for(var/how in list("at once", "third time"))
		var/mob/living/carbon/human/npc/guard = stealth_guard(block, 6, 2)
		var/datum/ai_controller/basic_controller/human_npc/stealth/stealth_ai = stealth_ai(guard)
		var/mob/living/carbon/human/person = stealth_person(block, 8, 2)
		stealth_dress(person)
		var/waves = how == "at once" ? 1 : 2
		for(var/wave in 1 to waves)
			if(wave > 1)
				stealth_ai.stealth_rewind(61 SECONDS)
				TEST_ASSERT(person.dropItemToGround(person.wear_id), "[how]: the pass wouldn't come off")
				stealth_scans(guard, 1)
				TEST_ASSERT_EQUAL(stealth_ai.challenge?.resolve(), person, "[how]: a minute after a wave the guard didn't stop them")
				stealth_dress(person, FALSE, FALSE, TRUE)
			else
				stealth_scans(guard, 1)
				TEST_ASSERT_EQUAL(stealth_ai.challenge?.resolve(), person, "[how]: the guard didn't stop someone in the whole set")
			stealth_scans(guard, 1)
			stealth_ai.stealth_rewind(2 SECONDS)
			stealth_scans(guard, 1)
			TEST_ASSERT_EQUAL(guard.npc_last_bark, "stealth_id_pass", "[how]: wave [wave] didn't pass")
			TEST_ASSERT_EQUAL(length(stealth_ai.waved?[REF(person)]), wave, "[how]: the guard didn't count wave [wave]")
		if(how == "third time")
			stealth_ai.stealth_rewind(61 SECONDS)
		TEST_ASSERT(person.dropItemToGround(person.wear_id), "[how]: the pass wouldn't come off")
		stealth_scans(guard, 1)
		TEST_ASSERT_NULL(stealth_ai.challenge?.resolve(), "[how]: the guard stopped them once more instead of seeing through it")
		TEST_ASSERT(stealth_ai.made?[REF(person)] > world.time, "[how]: the guard doesn't remember who it saw through")
		// The spot line follows the blown one at once, so the last bark is "spot": the blown line's cooldown shows it was said.
		TEST_ASSERT(stealth_ai.bark_ready_at["stealth_blown"] > world.time, "[how]: the guard saw through them without a word")
		TEST_ASSERT(!stealth_ai.stealth_fooled(person), "[how]: the disguise still holds for that guard")
		qdel(guard)
		qdel(person)
	// Old waves are forgotten.
	var/mob/living/carbon/human/npc/guard = stealth_guard(block, 6, 2)
	var/datum/ai_controller/basic_controller/human_npc/stealth/stealth_ai = stealth_ai(guard)
	LAZYADDASSOCLIST(stealth_ai.waved, "someone", world.time)
	LAZYADDASSOCLIST(stealth_ai.waved, "someone", world.time)
	TEST_ASSERT(stealth_ai.stealth_rechecked("someone"), "Two fresh waves didn't count")
	stealth_ai.stealth_rewind(5 MINUTES + 1 SECONDS)
	TEST_ASSERT(!stealth_ai.stealth_rechecked("someone"), "Waves over 5 minutes old still counted")
	TEST_ASSERT_NULL(stealth_ai.waved?["someone"], "Old waves weren't cleared")
	qdel(block)

/// No pass: asked again at 3 s, blown at 6 s. Walking off or running is blown at once. A pass put on in time passes.
/datum/unit_test/voidcrew_stealth_disguise_fail

/datum/unit_test/voidcrew_stealth_disguise_fail/Run()
	var/datum/turf_reservation/block = stealth_block(20, 5)
	TEST_ASSERT_NOTNULL(block, "No room for the test")
	for(var/how in list("waits", "walks off", "runs", "shows a pass"))
		var/mob/living/carbon/human/npc/guard = stealth_guard(block, 6, 2)
		var/datum/ai_controller/basic_controller/human_npc/stealth/stealth_ai = stealth_ai(guard)
		var/mob/living/carbon/human/person = stealth_person(block, 8, 2)
		stealth_dress(person, TRUE, TRUE, FALSE)
		stealth_scans(guard, 2)
		TEST_ASSERT_EQUAL(stealth_ai.challenge?.resolve(), person, "[how]: a guard didn't stop someone in clothing and mask 2 tiles in front of it")
		TEST_ASSERT(stealth_ai.checked_at, "[how]: the guard isn't waiting for a pass")
		switch(how)
			if("waits")
				stealth_ai.stealth_rewind(3 SECONDS)
				stealth_scans(guard, 1)
				TEST_ASSERT_EQUAL(stealth_ai.stealth_state(), "suspicious", "The guard was past asking after 3 s")
				TEST_ASSERT(stealth_ai.warned, "The guard didn't ask a second time after 3 s")
				TEST_ASSERT_EQUAL(guard.npc_last_bark, "stealth_id_fail", "The guard asked a second time without a word")
				stealth_ai.stealth_rewind(3 SECONDS)
				stealth_scans(guard, 1)
			if("walks off")
				person.forceMove(stealth_at(block, 11, 2))
				stealth_scans(guard, 1)
			if("runs")
				person.toggle_move_intent()
				person.forceMove(stealth_at(block, 9, 2))
				stealth_scans(guard, 1)
			if("shows a pass")
				stealth_dress(person, FALSE, FALSE, TRUE)
				stealth_ai.stealth_rewind(2 SECONDS)
				stealth_scans(guard, 1)
				TEST_ASSERT_EQUAL(stealth_ai.stealth_state(), "unaware", "A pass put on while the guard waited didn't pass")
				qdel(guard)
				qdel(person)
				continue
		TEST_ASSERT_EQUAL(stealth_ai.stealth_state(), "alert", "[how]: the guard didn't go for someone with no pass")
		TEST_ASSERT_EQUAL(stealth_ai.blackboard[BB_BASIC_MOB_CURRENT_TARGET], person, "[how]: the alert guard has no target")
		TEST_ASSERT(stealth_ai.made[REF(person)] > world.time, "[how]: the guard doesn't remember who it saw through")
		TEST_ASSERT(!stealth_ai.stealth_fooled(person), "[how]: the disguise still holds for the guard that blew it")
		qdel(guard)
		qdel(person)
	qdel(block)

/// What a guard sees that no guard of the den would do: a weapon in hand, a fallen guard pulled along, an off-limits room.
/datum/unit_test/voidcrew_stealth_disguise_breakers

/datum/unit_test/voidcrew_stealth_disguise_breakers/Run()
	var/datum/turf_reservation/block = stealth_block(20, 5)
	TEST_ASSERT_NOTNULL(block, "No room for the test")
	// what they hold => whether it blows the whole set at 6 tiles
	var/list/cases = list(
		/obj/item/gun/ballistic/automatic/pistol = TRUE,
		/obj/item/knife/combat = TRUE,
		/obj/item/melee/baton/security = TRUE,
		/obj/item/storage/toolbox/mechanical = FALSE,
		/obj/item/flashlight/seclite = FALSE,
	)
	for(var/item_type in cases)
		var/mob/living/carbon/human/npc/guard = stealth_guard(block, 6, 2)
		var/datum/ai_controller/basic_controller/human_npc/stealth/stealth_ai = stealth_ai(guard)
		var/mob/living/carbon/human/person = stealth_person(block, 12, 2)
		stealth_dress(person)
		stealth_scans(guard, 2)
		TEST_ASSERT_EQUAL(stealth_ai.stealth_state(), "unaware", "[item_type]: empty-handed in the whole set wasn't one of their own")
		person.put_in_hands(new item_type(person))
		stealth_scans(guard, 1)
		TEST_ASSERT_EQUAL(stealth_ai.stealth_state(), cases[item_type] ? "alert" : "unaware", "[item_type] in hand at 6 tiles left the guard [stealth_ai.stealth_state()]")
		qdel(guard)
		qdel(person)
	// Off limits: the pass excuses it, unless the mark says nobody.
	for(var/how in list("no pass", "pass", "pass, nobody allowed"))
		var/obj/effect/landmark/stealth_restricted/mark = new(stealth_at(block, 12, 2))
		mark.reach = 1
		mark.allowed = how != "pass, nobody allowed"
		var/mob/living/carbon/human/npc/guard = stealth_guard(block, 6, 2)
		var/datum/ai_controller/basic_controller/human_npc/stealth/stealth_ai = stealth_ai(guard)
		var/mob/living/carbon/human/person = stealth_person(block, 12, 2)
		stealth_dress(person, TRUE, TRUE, how != "no pass")
		stealth_scans(guard, 2)
		TEST_ASSERT_EQUAL(stealth_ai.stealth_state(), how == "pass" ? "unaware" : "alert", "Off limits, [how]: the guard is [stealth_ai.stealth_state()]")
		// Outside the room the same disguise is nothing to look at.
		if(how == "no pass")
			TEST_ASSERT_NULL(stealth_ai.group.off_limits()[stealth_at(block, 15, 2)], "A mark with a reach of 1 took in a tile 3 off")
		qdel(guard)
		qdel(person)
		qdel(mark)
	// At its back, a gun in hand: it senses someone there but hasn't seen the gun, so the disguise holds until it looks.
	var/mob/living/carbon/human/npc/back_guard = stealth_guard(block, 6, 2, WEST)
	var/datum/ai_controller/basic_controller/human_npc/stealth/back_ai = stealth_ai(back_guard)
	var/mob/living/carbon/human/armed = stealth_person(block, 8, 2)
	stealth_dress(armed)
	armed.put_in_hands(new /obj/item/gun/ballistic/automatic/pistol(armed))
	stealth_scans(back_guard, 1)
	TEST_ASSERT(back_ai.stealth_state() != "alert", "A guard saw the gun in the hand of someone at its back")
	TEST_ASSERT(!back_ai.stealth_knows(armed), "A guard saw through a disguise at its back")
	back_guard.setDir(EAST)
	stealth_scans(back_guard, 1)
	TEST_ASSERT_EQUAL(back_ai.stealth_state(), "alert", "A guard that turned to face someone with a gun in hand let it go")
	qdel(back_guard)
	qdel(armed)
	// Pulling a fallen guard (its look for bodies is held off, so this is the pulling alone).
	var/mob/living/carbon/human/npc/guard = stealth_guard(block, 6, 2)
	var/datum/ai_controller/basic_controller/human_npc/stealth/stealth_ai = stealth_ai(guard)
	stealth_ai.stealth_setup()
	var/mob/living/carbon/human/npc/victim = stealth_guard(block, 12, 3)
	var/datum/ai_controller/basic_controller/human_npc/stealth/guard_ai = stealth_ai(victim)
	guard_ai.stealth_setup()
	victim.death()
	var/mob/living/carbon/human/person = stealth_person(block, 12, 2)
	stealth_dress(person)
	person.start_pulling(victim)
	TEST_ASSERT_EQUAL(person.pulling, victim, "The body wouldn't be pulled")
	stealth_ai.next_body_scan = world.time + 1 MINUTES
	stealth_scans(guard, 1)
	TEST_ASSERT_EQUAL(stealth_ai.stealth_state(), "alert", "A guard watched one of its own being dragged off by someone in the whole set")
	TEST_ASSERT_EQUAL(stealth_ai.blackboard[BB_BASIC_MOB_CURRENT_TARGET], person, "The guard isn't after whoever drags the body")
	qdel(guard)
	qdel(victim)
	qdel(person)
	qdel(block)

/// Standing over a body as it is found, and laying hands on a guard in another's sight.
/datum/unit_test/voidcrew_stealth_disguise_seen

/datum/unit_test/voidcrew_stealth_disguise_seen/Run()
	var/datum/turf_reservation/block = stealth_block(20, 5)
	TEST_ASSERT_NOTNULL(block, "No room for the test")
	// A fresh body with them beside it.
	var/mob/living/carbon/human/npc/guard = stealth_guard(block, 6, 2)
	var/datum/ai_controller/basic_controller/human_npc/stealth/stealth_ai = stealth_ai(guard)
	stealth_ai.stealth_setup()
	var/mob/living/carbon/human/npc/victim = stealth_guard(block, 12, 3)
	var/datum/ai_controller/basic_controller/human_npc/stealth/guard_ai = stealth_ai(victim)
	guard_ai.stealth_setup()
	TEST_ASSERT_EQUAL(guard_ai.group, stealth_ai.group, "The two guards aren't one group")
	var/mob/living/carbon/human/person = stealth_person(block, 12, 2)
	stealth_dress(person)
	stealth_scans(guard, 2)
	TEST_ASSERT_EQUAL(stealth_ai.stealth_state(), "unaware", "Standing by a living guard in the whole set drew a look")
	victim.death()
	// Its look for fallen friends comes round again.
	stealth_ai.next_body_scan = 0
	stealth_scans(guard, 1)
	TEST_ASSERT_EQUAL(stealth_ai.stealth_state(), "alert", "A guard found a body with someone in the whole set standing over it and let them be")
	TEST_ASSERT_EQUAL(stealth_ai.blackboard[BB_BASIC_MOB_CURRENT_TARGET], person, "The guard isn't after whoever stood over the body")
	qdel(guard)
	qdel(victim)
	// Hands on a guard: the one touched turns on them, and so does the one that sees it; one that doesn't see it is still fooled.
	guard = stealth_guard(block, 6, 2)
	stealth_ai = stealth_ai(guard)
	stealth_ai.stealth_setup()
	victim = stealth_guard(block, 11, 2)
	guard_ai = stealth_ai(victim)
	guard_ai.stealth_setup()
	var/mob/living/carbon/human/npc/other = stealth_guard(block, 2, 2, WEST)
	var/datum/ai_controller/basic_controller/human_npc/stealth/friend_ai = stealth_ai(other)
	friend_ai.stealth_setup()
	person.forceMove(stealth_at(block, 10, 2))
	TEST_ASSERT(stealth_ai.stealth_fooled(person), "The watching guard already sees through them")
	guard_ai.stealth_touched(person)
	TEST_ASSERT_EQUAL(guard_ai.stealth_state(), "alert", "A guard touched from behind by someone in the whole set didn't turn on them")
	TEST_ASSERT_EQUAL(stealth_ai.stealth_state(), "alert", "A guard watched one of its own being grabbed and did nothing")
	TEST_ASSERT_EQUAL(stealth_ai.blackboard[BB_BASIC_MOB_CURRENT_TARGET], person, "The watching guard isn't after the one it saw")
	TEST_ASSERT_EQUAL(friend_ai.stealth_state(), "unaware", "A guard with its back to it all reacted")
	// Word reaches the third guard only through a shout or a call that reaches it (decision 44, voidcrew_stealth_d44.dm):
	// being wary is not word.
	TEST_ASSERT(friend_ai.stealth_fooled(person), "A guard nobody has told sees through them")
	friend_ai.stealth_set_wary()
	TEST_ASSERT(friend_ai.stealth_fooled(person), "A wary guard nobody told knows what another guard saw")
	stealth_ai.stealth_tell(friend_ai)
	TEST_ASSERT(!friend_ai.stealth_fooled(person), "A guard that was told is still fooled")
	qdel(block)

/// Running in a guard's earshot is only footsteps (decision 44); a face it went alert on is known unless a mask hides it.
/datum/unit_test/voidcrew_stealth_disguise_known

/datum/unit_test/voidcrew_stealth_disguise_known/Run()
	var/datum/turf_reservation/block = stealth_block(20, 5)
	TEST_ASSERT_NOTNULL(block, "No room for the test")
	// Running three tiles behind it.
	var/mob/living/carbon/human/npc/guard = stealth_guard(block, 6, 2, WEST)
	var/datum/ai_controller/basic_controller/human_npc/stealth/stealth_ai = stealth_ai(guard)
	var/mob/living/carbon/human/person = stealth_person(block, 10, 2)
	stealth_dress(person)
	stealth_scans(guard, 1)
	person.forceMove(stealth_at(block, 9, 2))
	stealth_scans(guard, 1)
	TEST_ASSERT(stealth_ai.stealth_fooled(person), "Walking behind a guard in the whole set gave them away")
	person.toggle_move_intent()
	person.forceMove(stealth_at(block, 8, 2))
	stealth_scans(guard, 1)
	TEST_ASSERT(stealth_ai.stealth_fooled(person), "Running three tiles behind a guard gave a disguise away by ear")
	TEST_ASSERT(!length(stealth_ai.made), "A guard marked someone it only heard running")
	qdel(guard)
	qdel(person)
	// A face it has gone alert on.
	guard = stealth_guard(block, 6, 2)
	stealth_ai = stealth_ai(guard)
	person = stealth_person(block, 12, 2)
	stealth_ai.stealth_go_alert(person)
	stealth_ai.clear_blackboard_key(BB_BASIC_MOB_CURRENT_TARGET)
	stealth_ai.stealth_go_unaware()
	stealth_ai.stealth_clear_wary()
	stealth_dress(person, TRUE, FALSE, TRUE)
	TEST_ASSERT(!stealth_ai.stealth_fooled(person), "A guard didn't know the bare face it had fought")
	stealth_scans(guard, 1)
	TEST_ASSERT(abs(stealth_notice_of(guard, person) - 0.375) < 0.001, "A known face in the fatigues was still noticed slowly")
	stealth_dress(person, FALSE, TRUE, FALSE)
	TEST_ASSERT(stealth_ai.stealth_fooled(person), "A mask didn't hide a face the guard knew")
	// A disguise it saw through stays seen through, mask or no mask.
	stealth_ai.stealth_blow(person)
	TEST_ASSERT(!stealth_ai.stealth_fooled(person), "A guard that saw through a masked disguise is fooled by it again")
	qdel(guard)
	qdel(person)
	// Someone it fought masked left no face behind: the disguise holds.
	guard = stealth_guard(block, 6, 2)
	stealth_ai = stealth_ai(guard)
	person = stealth_person(block, 12, 2)
	stealth_dress(person, FALSE, TRUE, FALSE)
	stealth_ai.stealth_go_alert(person)
	stealth_ai.clear_blackboard_key(BB_BASIC_MOB_CURRENT_TARGET)
	stealth_ai.stealth_go_unaware()
	stealth_ai.stealth_clear_wary()
	stealth_dress(person, TRUE, FALSE, TRUE)
	TEST_ASSERT(stealth_ai.stealth_fooled(person), "A guard knew someone it had only ever seen masked")
	qdel(block)

/// The pass, the fatigues and the balaclava come off a guard like anyone's; the rest of its kit stays locked. The pass opens scav doors.
/datum/unit_test/voidcrew_stealth_disguise_loot

/datum/unit_test/voidcrew_stealth_disguise_loot/Run()
	var/datum/turf_reservation/block = stealth_block(5, 3)
	TEST_ASSERT_NOTNULL(block, "No room for the test")
	var/mob/living/carbon/human/npc/guard = stealth_guard(block, 1, 1)
	var/mob/living/carbon/human/person = stealth_person(block, 3, 1)
	var/obj/item/card/id/card = guard.wear_id
	TEST_ASSERT(istype(card, /obj/item/card/id/advanced/black/scav), "A scav guard wears no scav pass")
	TEST_ASSERT(("scav" in card.GetAccess()), "The scav pass carries no scav access")
	TEST_ASSERT_EQUAL(card.registered_name, guard.real_name, "The pass isn't in the guard's name")
	var/obj/item/uniform = guard.w_uniform
	TEST_ASSERT(istype(uniform, /obj/item/clothing/under/syndicate/scav), "A scav guard doesn't wear the scav fatigues")
	for(var/obj/item/loot as anything in list(card, uniform))
		TEST_ASSERT(!human_npc_gear_locked(loot), "[loot] is locked gear")
		TEST_ASSERT(!HAS_TRAIT(loot, TRAIT_NO_STRIP), "[loot] can't be stripped")
	TEST_ASSERT(human_npc_gear_locked(guard.shoes), "The guard's boots are loot too")
	var/obj/item/mask = new /obj/item/clothing/mask/balaclava/scav(guard)
	TEST_ASSERT(!guard.npc_lock_item(mask), "A scav balaclava was locked to the guard")
	qdel(mask)
	// A door that takes scav access.
	var/obj/machinery/door/airlock/door = allocate(/obj/machinery/door/airlock, stealth_at(block, 4, 0))
	door.req_one_access = list("armory", "scav")
	TEST_ASSERT(door.check_access(card), "A door set to scav access refuses the scav pass")
	// Taken off the guard and worn.
	TEST_ASSERT(guard.dropItemToGround(card), "The pass can't be taken off the guard")
	TEST_ASSERT(guard.dropItemToGround(uniform), "The fatigues can't be taken off the guard")
	TEST_ASSERT(person.equip_to_slot_if_possible(uniform, ITEM_SLOT_ICLOTHING), "The looted fatigues can't be worn")
	TEST_ASSERT(person.equip_to_slot_if_possible(card, ITEM_SLOT_ID), "The looted pass can't be worn")
	sleep(2)
	TEST_ASSERT(!QDELETED(card) && !QDELETED(uniform), "The looted pass or fatigues were deleted")
	TEST_ASSERT_EQUAL(stealth_disguise_of(person), 6, "The guard's own fatigues and pass aren't clothing and ID on someone else")
	qdel(block)

/// The real AI: stopped at a distance in the fatigues and a pass, the guard walks up, reads it and goes back to its post.
/datum/unit_test/voidcrew_stealth_live/disguise_pass

/datum/unit_test/voidcrew_stealth_live/disguise_pass/Run()
	TEST_ASSERT(make_room(14, 5), "No room for the test")
	var/mob/living/carbon/human/npc/guard = guard_at(1, 2)
	var/mob/living/carbon/human/person = person_at(6, 2)
	stealth_dress(person, TRUE, FALSE, TRUE)
	var/datum/ai_controller/basic_controller/human_npc/stealth/stealth_ai = wake(guard)
	var/turf/post = at(1, 2)
	var/stopped = FALSE
	var/deadline = world.time + 30 SECONDS
	while(world.time < deadline && !(stealth_ai.passes?[REF(person)]))
		if(stealth_ai.challenge?.resolve() == person)
			stopped = TRUE
		sleep(2)
	TEST_ASSERT(stopped, "A guard never stopped someone in the fatigues 5 tiles in front of it")
	TEST_ASSERT(stealth_ai.passes?[REF(person)], "The guard never let someone with a pass go (state [stealth_ai.stealth_state()], [get_dist(guard, person)] tiles off)")
	TEST_ASSERT_NULL(stealth_ai.blackboard[BB_BASIC_MOB_CURRENT_TARGET], "The guard took a target during the check")
	TEST_ASSERT(get_dist(guard, person) <= 2, "The guard read a pass from [get_dist(guard, person)] tiles off")
	deadline = world.time + 30 SECONDS
	while(world.time < deadline && get_turf(guard) != post)
		sleep(2)
	TEST_ASSERT_EQUAL(get_turf(guard), post, "The guard didn't go back to its post after the check")
	TEST_ASSERT_EQUAL(stealth_ai.stealth_state(), "unaware", "The guard isn't calm after a good pass")

/// The real AI: stopped with no pass, they stand there; the guard asks again and then goes for them.
/datum/unit_test/voidcrew_stealth_live/disguise_fail

/datum/unit_test/voidcrew_stealth_live/disguise_fail/Run()
	TEST_ASSERT(make_room(14, 5), "No room for the test")
	var/mob/living/carbon/human/npc/guard = guard_at(1, 2)
	var/mob/living/carbon/human/person = person_at(4, 2)
	stealth_dress(person, TRUE, TRUE, FALSE)
	var/datum/ai_controller/basic_controller/human_npc/stealth/stealth_ai = wake(guard)
	var/stopped = FALSE
	var/start_time = world.time
	var/deadline = world.time + 30 SECONDS
	while(world.time < deadline && stealth_ai.stealth_state() != "alert")
		if(stealth_ai.challenge?.resolve() == person)
			stopped = TRUE
		sleep(2)
	TEST_ASSERT(stopped, "A guard never stopped someone in clothing and mask 3 tiles in front of it")
	TEST_ASSERT_EQUAL(stealth_ai.stealth_state(), "alert", "A guard never went for someone who showed no pass")
	TEST_ASSERT(world.time - start_time >= 5 SECONDS, "The guard gave someone with no pass only [(world.time - start_time) / 10] s")
	TEST_ASSERT_EQUAL(stealth_ai.blackboard[BB_BASIC_MOB_CURRENT_TARGET], person, "The alert guard isn't after them")

/// Someone holding one of its own up in front of them, seen in its cone: an alert on that look, no notice to fill, at
/// any range it sees and in a disguise or not.
/datum/unit_test/voidcrew_stealth_hostage_seen

/datum/unit_test/voidcrew_stealth_hostage_seen/Run()
	var/datum/turf_reservation/block = stealth_block(12, 5)
	TEST_ASSERT_NOTNULL(block, "No room for the test")
	for(var/disguised in list(FALSE, TRUE))
		var/mob/living/carbon/human/npc/guard = stealth_guard(block, 2, 2, EAST)
		var/datum/ai_controller/basic_controller/human_npc/stealth/stealth_ai = stealth_ai(guard)
		var/mob/living/carbon/human/holder = stealth_person(block, 8, 2)
		if(disguised)
			stealth_dress(holder)
		var/mob/living/carbon/human/npc/friend = stealth_guard(block, 8, 2, WEST)
		TEST_ASSERT(holder.put_in_hands(new /obj/item/gun/ballistic/automatic/pistol(holder)), "Test fixture: no gun in hand")
		stealth_test_grab(holder, friend, GRAB_NECK)
		if(friend.loc != holder.loc)
			friend.forceMove(holder.loc)
		TEST_ASSERT_EQUAL(stealth_hostage_of(holder), friend, "Test fixture: the friend isn't held at gunpoint")
		stealth_scans(guard, 1)
		TEST_ASSERT_EQUAL(stealth_ai.stealth_state(), "alert", "A guard took its time over someone holding one of its own six tiles off ([disguised ? "disguised" : "plain"])")
		qdel(guard)
		qdel(friend)
		qdel(holder)
