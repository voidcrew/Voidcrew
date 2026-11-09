/**
 * Bounty chrome: Gorilla Arms (C2), for voidcrew/modules/bounties/chrome/bounty_chrome_gorilla.dm.
 *
 * Criminals carry the real lattices; the tests read tg's own state (the arms' cooldowns, tg's pull and
 * grab state, damage, throws, doors). The AI is switched off and the chrome driven through its own procs;
 * the grab's own clock is left to run where the test is about its timing. Fork defines are included after
 * the tests, so literals stand in for them with a comment naming the define. The test room is a 5x5 floor.
 */

/// A Petty brawler with Gorilla Arms at `where`, its AI off
/datum/unit_test/voidcrew_bounty_chrome/proc/make_gorilla(turf/where)
	var/mob/living/carbon/human/npc/bounty_criminal/criminal = make_criminal(make_record(1, "normal", "brawler", null, list("gorilla")), where) // BOUNTY_CHROME_GORILLA
	criminal?.ai_controller?.set_ai_status(AI_STATUS_OFF)
	return criminal

/// Sets `arm`'s punch to be loaded again in `left` (0: loaded now)
/datum/unit_test/voidcrew_bounty_chrome/proc/arm_reload(obj/item/organ/cyberimp/cyberware/gorilla_arms/arm, left)
	arm.slam_cooldown = left ? world.time + left : 0

/// Whether `hunter` is held fast by `criminal`: tg's aggressive grab
/datum/unit_test/voidcrew_bounty_chrome/proc/held_by(mob/living/hunter, mob/living/criminal)
	return hunter.pulledby == criminal && criminal.grab_state >= GRAB_AGGRESSIVE

/// Plain fists only for its ordinary blows: with both fists loaded it throws nothing; with one used, every blow is that fist's, and the loaded one stays loaded
/datum/unit_test/voidcrew_bounty_chrome/gorilla_fists

/datum/unit_test/voidcrew_bounty_chrome/gorilla_fists/Run()
	var/mob/living/carbon/human/hunter = make_person(spot(2, 2))
	var/mob/living/carbon/human/npc/bounty_criminal/criminal = make_gorilla(spot(1, 2))
	var/list/arms = bounty_gorilla_arms(criminal)
	TEST_ASSERT_EQUAL(length(arms), 2, "The criminal carries [length(arms)] Gorilla lattices, not the pair")
	var/datum/status_effect/organ_set_bonus/cyberware_gorilla/bonus = criminal.has_status_effect(/datum/status_effect/organ_set_bonus/cyberware_gorilla)
	TEST_ASSERT(bonus?.bonus_active, "The pair's set bonus (prying doors) isn't working")
	var/datum/component/bounty_chrome/chrome = chrome_fight(criminal, hunter)
	var/datum/ai_controller/controller = criminal.ai_controller
	var/datum/ai_behavior/basic_melee_attack/human_npc/bounty/gorilla/brawl = GET_AI_BEHAVIOR(/datum/ai_behavior/basic_melee_attack/human_npc/bounty/gorilla)

	// Planning in its fight queues its own blows, not the bounty melee's
	var/datum/bounty_chrome_move/gorilla_punch/punch = chrome.move_of(/datum/bounty_chrome_move/gorilla_punch)
	TEST_ASSERT_NOTNULL(punch, "The piston punch's move wasn't made")
	TEST_ASSERT(punch.plan(controller, hunter), "The gorilla planned nothing in its fight")
	TEST_ASSERT(controller.current_behaviors[brawl], "The gorilla's plain-fist blows weren't queued")
	TEST_ASSERT_NULL(chrome.telling, "A piston punch started inside its opener")

	// Both fists loaded: nothing thrown
	for(var/i in 1 to 3)
		criminal.next_move = 0
		criminal.next_click = 0
		controller.set_blackboard_key(BB_BASIC_MOB_MELEE_COOLDOWN_TIMER, world.time - 1)
		brawl.perform(1, controller, BB_BASIC_MOB_CURRENT_TARGET, BB_TARGETING_STRATEGY, BB_BASIC_MOB_CURRENT_TARGET_HIDING_LOCATION)
	TEST_ASSERT_EQUAL(hunter.getBruteLoss(), 0, "The gorilla threw a blow with both fists loaded")
	for(var/obj/item/organ/cyberimp/cyberware/gorilla_arms/arm as anything in arms)
		TEST_ASSERT(bounty_gorilla_loaded(arm), "An ordinary blow spent the [arm]'s punch")

	// One fist used: its blows are that fist's plain punches
	var/obj/item/organ/cyberimp/cyberware/gorilla_arms/used = arms[1]
	var/obj/item/organ/cyberimp/cyberware/gorilla_arms/loaded = arms[2]
	arm_reload(used, 30 SECONDS)
	for(var/i in 1 to 5)
		criminal.next_move = 0
		criminal.next_click = 0
		controller.set_blackboard_key(BB_BASIC_MOB_MELEE_COOLDOWN_TIMER, world.time - 1)
		var/before = hunter.getBruteLoss()
		brawl.perform(1, controller, BB_BASIC_MOB_CURRENT_TARGET, BB_TARGETING_STRATEGY, BB_BASIC_MOB_CURRENT_TARGET_HIDING_LOCATION)
		TEST_ASSERT_EQUAL(bounty_gorilla_arm_of_hand(criminal, criminal.active_hand_index), used, "A blow was thrown with the loaded fist")
		// A plain punch is 5 to 10 (a human arm's unarmed damage); the implant's is 20
		TEST_ASSERT(hunter.getBruteLoss() - before <= 10, "An ordinary blow did [hunter.getBruteLoss() - before] brute: it was the implant's punch")
		hunter.forceMove(spot(2, 2))
		hunter.SetKnockdown(0)
		hunter.get_up(instant = TRUE)
	TEST_ASSERT(bounty_gorilla_loaded(loaded), "An ordinary blow spent the loaded fist's punch")

/// The piston punch: an orange outline and the lit tile for its tell, then a loaded fist's punch, the implant's (its brute, its knock-back, that arm's cooldown); stepping off the lit tile, it hits air; never toward a drop
/datum/unit_test/voidcrew_bounty_chrome/gorilla_punch
	/// Turfs it changed, put back when it ends
	var/list/turf/changed_turfs = list()

/datum/unit_test/voidcrew_bounty_chrome/gorilla_punch/Destroy()
	for(var/turf/changed as anything in changed_turfs)
		changed.ChangeTurf(/turf/open/floor/iron)
	changed_turfs = null
	return ..()

/datum/unit_test/voidcrew_bounty_chrome/gorilla_punch/Run()
	var/mob/living/carbon/human/hunter = make_person(spot(2, 2))
	var/mob/living/carbon/human/npc/bounty_criminal/criminal = make_gorilla(spot(1, 2))
	var/list/arms = bounty_gorilla_arms(criminal)
	var/datum/component/bounty_chrome/chrome = chrome_fight(criminal, hunter)
	var/datum/bounty_chrome_move/gorilla_punch/punch = chrome.move_of(/datum/bounty_chrome_move/gorilla_punch)
	TEST_ASSERT(punch.opens_at > world.time, "The first piston punch may come the moment the fight starts")
	TEST_ASSERT(punch.opens_at <= world.time + 1.5 SECONDS, "The first piston punch waits more than 1.5 s") // BOUNTY_GORILLA_PUNCH_OPENING
	TEST_ASSERT(punch.can_start(hunter), "The piston punch won't start at a hunter beside it")

	TEST_ASSERT(chrome.start_move(punch, hunter), "The piston punch's tell didn't start")
	TEST_ASSERT(HAS_TRAIT_FROM(criminal, TRAIT_IMMOBILIZED, "bounty_chrome"), "The gorilla doesn't stand still through the tell") // BOUNTY_CHROME_TRAIT
	TEST_ASSERT_NOTNULL(criminal.get_filter(punch.tell_filter()), "The tell has no outline")
	var/obj/effect/temp_visual/bounty_boss_mark/mark = locate() in spot(2, 2)
	TEST_ASSERT_NOTNULL(mark, "The tile it aims at isn't lit")
	sleep(0.4 SECONDS)
	TEST_ASSERT_EQUAL(hunter.getBruteLoss(), 0, "The punch landed before the tell was over")
	sleep(0.6 SECONDS)
	TEST_ASSERT(hunter.getBruteLoss() >= 15, "The piston punch did [hunter.getBruteLoss()] brute, not the implant's 20") // CYBERWARE_GORILLA_PUNCH_DAMAGE
	var/spent = 0
	for(var/obj/item/organ/cyberimp/cyberware/gorilla_arms/arm as anything in arms)
		if(!bounty_gorilla_loaded(arm))
			spent++
	TEST_ASSERT_EQUAL(spent, 1, "[spent] arms went on cooldown, not the one that punched")
	sleep(0.5 SECONDS)
	TEST_ASSERT(get_dist(criminal, hunter) >= 2, "The punch didn't knock the hunter back")

	// Off the lit tile: it hits air, and spends nothing
	for(var/obj/item/organ/cyberimp/cyberware/gorilla_arms/arm as anything in arms)
		arm_reload(arm, 0)
	hunter.forceMove(spot(2, 2))
	hunter.SetKnockdown(0)
	hunter.get_up(instant = TRUE)
	hunter.fully_heal()
	chrome.next_move_at = 0
	criminal.next_move = 0
	criminal.next_click = 0
	TEST_ASSERT(chrome.start_move(punch, hunter), "The second piston punch's tell didn't start")
	hunter.forceMove(spot(2, 3))
	sleep(1 SECONDS)
	TEST_ASSERT_EQUAL(hunter.getBruteLoss(), 0, "The punch followed the hunter off the lit tile")
	for(var/obj/item/organ/cyberimp/cyberware/gorilla_arms/arm as anything in arms)
		TEST_ASSERT(bounty_gorilla_loaded(arm), "A punch at air spent the [arm]'s punch")

	// Never toward a drop: the tile behind the hunter is space
	hunter.forceMove(spot(2, 2))
	var/turf/behind = spot(3, 2)
	changed_turfs += behind
	behind.ChangeTurf(/turf/open/space)
	TEST_ASSERT(!punch.can_start(hunter), "A piston punch would knock the hunter out into space")

/// The grab: a fist just used and one loaded; its hand on the hunter (tg's pull) and a ring for the tell; then tg's aggressive grab, two face punches with the used fist, and the loaded fist's punch, the implant's hurl; the guard after
/datum/unit_test/voidcrew_bounty_chrome/gorilla_grab

/datum/unit_test/voidcrew_bounty_chrome/gorilla_grab/Run()
	var/mob/living/carbon/human/hunter = make_person(spot(2, 2))
	var/mob/living/carbon/human/npc/bounty_criminal/criminal = make_gorilla(spot(1, 2))
	var/list/arms = bounty_gorilla_arms(criminal)
	var/obj/item/organ/cyberimp/cyberware/gorilla_arms/used = arms[1]
	var/obj/item/organ/cyberimp/cyberware/gorilla_arms/loaded = arms[2]
	var/datum/component/bounty_chrome/chrome = chrome_fight(criminal, hunter)
	var/datum/bounty_chrome_move/gorilla_grab/grab = chrome.move_of(/datum/bounty_chrome_move/gorilla_grab)
	TEST_ASSERT_NOTNULL(grab, "The grab's move wasn't made")
	TEST_ASSERT(grab.grab_ready_at > world.time + 2 SECONDS, "The first grab may come inside the fight's first moments") // BOUNTY_GORILLA_GRAB_OPENING
	TEST_ASSERT(!grab.can_start(hunter), "A grab could start inside its opener")
	grab.grab_ready_at = 0
	TEST_ASSERT(!grab.can_start(hunter), "A grab could start with both fists loaded, so its face punches would be the implant's")
	arm_reload(used, 3.9 SECONDS)
	TEST_ASSERT(grab.can_start(hunter), "No grab with one fist just used and the other loaded")

	// The tell: its hand on them, a ring under them, nothing harmful yet
	chrome.next_move_at = 0
	TEST_ASSERT(chrome.start_move(grab, hunter), "The grab's tell didn't start")
	TEST_ASSERT_EQUAL(criminal.pulling, hunter, "The gorilla's hand isn't on the hunter through the tell")
	TEST_ASSERT_EQUAL(criminal.grab_state, GRAB_PASSIVE, "The grip tightened before the tell was over")
	var/obj/effect/temp_visual/bounty_boss_mark/ring = locate() in spot(2, 2)
	TEST_ASSERT_EQUAL(ring?.icon_state, "target_circle", "No ring under the hunter it reaches for")
	TEST_ASSERT_NOTNULL(criminal.get_filter(grab.tell_filter()), "The tell has no outline")

	// The grip tightens: tg's aggressive grab
	sleep(1 SECONDS)
	TEST_ASSERT(held_by(hunter, criminal), "The grip didn't tighten into an aggressive grab")
	TEST_ASSERT(HAS_TRAIT_FROM(hunter, TRAIT_IMMOBILIZED, CHOKEHOLD_TRAIT), "The grabbed hunter can walk off, as in no aggressive grab of tg's")
	TEST_ASSERT(HAS_TRAIT_FROM(hunter, TRAIT_HANDS_BLOCKED, CHOKEHOLD_TRAIT), "The grabbed hunter's hands are free, as in no aggressive grab of tg's")
	TEST_ASSERT(HAS_TRAIT_FROM(criminal, TRAIT_IMMOBILIZED, "bounty_chrome_gorilla"), "Holding on, the gorilla can walk off") // BOUNTY_GORILLA_TRAIT
	TEST_ASSERT(grab.plan(criminal.ai_controller, hunter), "Holding on, the gorilla would plan something else")

	// Two punches to the face, a click apart, still held
	sleep(1 SECONDS)
	TEST_ASSERT(held_by(hunter, criminal), "Let go after the first face punch")
	sleep(0.8 SECONDS)
	TEST_ASSERT(held_by(hunter, criminal), "Let go after the second face punch")
	TEST_ASSERT_EQUAL(grab.punches, 2, "[grab.punches] face punches before the finisher")
	TEST_ASSERT(bounty_gorilla_loaded(loaded), "A face punch spent the loaded fist")
	var/before_finisher = hunter.getBruteLoss()

	// The finisher: the loaded fist's punch on someone held fast is the implant's hurl
	sleep(0.8 SECONDS)
	TEST_ASSERT(!held_by(hunter, criminal), "The finisher didn't let go")
	TEST_ASSERT_NULL(criminal.pulling, "The finisher left the gorilla pulling the hunter")
	TEST_ASSERT(!bounty_gorilla_loaded(loaded), "The finisher wasn't the loaded fist's punch")
	TEST_ASSERT(hunter.getBruteLoss() >= before_finisher + 15, "The finisher did [hunter.getBruteLoss() - before_finisher] brute, not the implant's 20") // CYBERWARE_GORILLA_PUNCH_DAMAGE
	TEST_ASSERT(!HAS_TRAIT_FROM(criminal, TRAIT_IMMOBILIZED, "bounty_chrome_gorilla"), "Still rooted after the finisher")
	TEST_ASSERT_NULL(grab.held_ref, "The grab still holds someone after the finisher")
	sleep(1 SECONDS)
	TEST_ASSERT(get_dist(criminal, hunter) >= 3, "The finisher didn't hurl the hunter across the room")

	// The guard: not grabbed again straight away
	hunter.forceMove(spot(2, 2))
	hunter.SetKnockdown(0)
	hunter.SetParalyzed(0)
	hunter.get_up(instant = TRUE)
	arm_reload(used, 3.9 SECONDS)
	arm_reload(loaded, 0)
	grab.grab_ready_at = 0
	criminal.next_move = 0
	criminal.next_click = 0
	TEST_ASSERT(!grab.can_start(hunter), "The hunter was grabbed again the moment they were let go")
	grab.guard = null
	TEST_ASSERT(grab.can_start(hunter), "With the guard gone, no second grab")

/// Ways out, tg's: a step or Resist during the tell; Resist, a friend's pull, a stun or an EMP while held fast; anyone who goes down is let go and never grabbed from the floor; someone tg's grab can't hold, or held by another, isn't grabbed
/datum/unit_test/voidcrew_bounty_chrome/gorilla_grab_ways_out

/datum/unit_test/voidcrew_bounty_chrome/gorilla_grab_ways_out/Run()
	var/mob/living/carbon/human/hunter = make_person(spot(2, 2))
	var/mob/living/carbon/human/friend = make_person(spot(2, 3))
	var/list/ways = list("step", "resist_reach", "resist", "friend", "stunned", "emp", "knocked_down")
	for(var/way in ways)
		hunter.forceMove(spot(2, 2))
		hunter.fully_heal()
		hunter.SetKnockdown(0)
		hunter.SetParalyzed(0)
		hunter.get_up(instant = TRUE)
		var/mob/living/carbon/human/npc/bounty_criminal/criminal = make_gorilla(spot(1, 2))
		var/list/arms = bounty_gorilla_arms(criminal)
		arm_reload(arms[1], 3.9 SECONDS)
		var/datum/component/bounty_chrome/chrome = chrome_fight(criminal, hunter)
		var/datum/bounty_chrome_move/gorilla_grab/grab = chrome.move_of(/datum/bounty_chrome_move/gorilla_grab)
		grab.grab_ready_at = 0
		chrome.next_move_at = 0
		TEST_ASSERT(grab.can_start(hunter), "[way]: no grab could start")
		TEST_ASSERT(chrome.start_move(grab, hunter), "[way]: the grab's tell didn't start")
		switch(way)
			if("step")
				hunter.forceMove(spot(3, 2))
			if("resist_reach")
				hunter.next_move = 0
				hunter.execute_resist()
		if(way == "step" || way == "resist_reach")
			TEST_ASSERT_NULL(hunter.pulledby, "[way]: the hunter is still in the gorilla's hand")
			sleep(1 SECONDS)
			TEST_ASSERT(!held_by(hunter, criminal), "[way]: the hunter was grabbed anyway")
			TEST_ASSERT_NULL(grab.held_ref, "[way]: the gorilla holds someone it never got")
			sleep(2.4 SECONDS)
			TEST_ASSERT_EQUAL(hunter.getBruteLoss(), 0, "[way]: the hunter was punched anyway")
			qdel(criminal)
			continue
		sleep(1 SECONDS)
		TEST_ASSERT(held_by(hunter, criminal), "[way]: the grip didn't tighten")
		switch(way)
			if("resist")
				// tg's own resist at tg's odds: a few tries; a failed one costs stamina, put back between tries
				for(var/attempt in 1 to 20)
					if(!held_by(hunter, criminal))
						break
					hunter.next_move = 0
					hunter.last_special = 0
					hunter.setStaminaLoss(0)
					hunter.execute_resist()
			if("friend")
				TEST_ASSERT(friend.start_pulling(hunter), "The friend couldn't take hold of the held hunter")
			if("stunned")
				criminal.Paralyze(2 SECONDS)
			if("emp")
				criminal.emp_act(EMP_HEAVY)
			if("knocked_down")
				hunter.Knockdown(2 SECONDS)
				TEST_ASSERT(!grab.may_grab(hunter), "Someone on the floor could be grabbed")
		if(way == "knocked_down")
			// Its next click finds them on the floor and lets go
			sleep(1 SECONDS)
		TEST_ASSERT(!held_by(hunter, criminal), "[way]: the gorilla kept hold")
		TEST_ASSERT(criminal.pulling != hunter, "[way]: the gorilla still pulls the hunter")
		TEST_ASSERT_NULL(grab.held_ref, "[way]: the grab still holds the hunter")
		TEST_ASSERT(!HAS_TRAIT_FROM(criminal, TRAIT_IMMOBILIZED, "bounty_chrome_gorilla"), "[way]: the gorilla is still rooted") // BOUNTY_GORILLA_TRAIT
		var/hurt = hunter.getBruteLoss()
		sleep(2.4 SECONDS)
		TEST_ASSERT_EQUAL(hunter.getBruteLoss(), hurt, "[way]: a punch landed after the hold ended")
		if(way == "friend")
			friend.stop_pulling()
			friend.forceMove(spot(2, 3))
		qdel(criminal)

	// Never: someone tg's grab can't tighten on, or someone another holds fast
	var/mob/living/carbon/human/npc/bounty_criminal/criminal = make_gorilla(spot(1, 2))
	arm_reload(bounty_gorilla_arms(criminal)[1], 3.9 SECONDS)
	var/datum/component/bounty_chrome/chrome = chrome_fight(criminal, hunter)
	var/datum/bounty_chrome_move/gorilla_grab/grab = chrome.move_of(/datum/bounty_chrome_move/gorilla_grab)
	grab.grab_ready_at = 0
	hunter.forceMove(spot(2, 2))
	hunter.SetKnockdown(0)
	hunter.get_up(instant = TRUE)
	TEST_ASSERT(grab.can_start(hunter), "No grab could start for the last checks")
	ADD_TRAIT(hunter, TRAIT_PUSHIMMUNE, "unit_test")
	TEST_ASSERT(!grab.can_start(hunter), "A grab would start on someone tg's grab can't tighten on")
	REMOVE_TRAIT(hunter, TRAIT_PUSHIMMUNE, "unit_test")
	friend.forceMove(spot(2, 3))
	friend.start_pulling(hunter)
	hunter.grabbedby(friend)
	TEST_ASSERT(held_by(hunter, friend), "The friend didn't hold the hunter fast for the check")
	TEST_ASSERT(!grab.can_start(hunter), "A grab would start on someone another holds fast")

/// Doors: forced when the hunter is behind one, with the set bonus's own pry; never a bolted one, one onto space, or one on a ship
/datum/unit_test/voidcrew_bounty_chrome/gorilla_doors
	/// Turfs it changed, put back when it ends
	var/list/turf/changed_turfs = list()
	/// Turf -> the area it had before it was made part of a ship
	var/list/original_areas = list()
	/// Areas it made
	var/list/test_areas = list()

/datum/unit_test/voidcrew_bounty_chrome/gorilla_doors/Destroy()
	for(var/turf/changed as anything in changed_turfs)
		changed.ChangeTurf(/turf/open/floor/iron)
	changed_turfs = null
	for(var/turf/moved as anything in original_areas)
		moved.change_area(get_area(moved), original_areas[moved])
	original_areas = null
	QDEL_LIST(test_areas)
	return ..()

/// A shut airlock at `where`, unpowered, so a pry opens it at once
/datum/unit_test/voidcrew_bounty_chrome/gorilla_doors/proc/make_door(turf/where)
	var/obj/machinery/door/airlock/door = allocate(/obj/machinery/door/airlock, where)
	door.set_machine_stat(door.machine_stat | NOPOWER)
	return door

/datum/unit_test/voidcrew_bounty_chrome/gorilla_doors/Run()
	var/mob/living/carbon/human/hunter = make_person(spot(3, 2))
	var/mob/living/carbon/human/npc/bounty_criminal/criminal = make_gorilla(spot(1, 2))
	var/datum/component/bounty_chrome/chrome = chrome_fight(criminal, hunter)
	var/datum/bounty_chrome_move/gorilla_doors/doors = chrome.move_of(/datum/bounty_chrome_move/gorilla_doors)
	TEST_ASSERT_NOTNULL(doors, "The door move wasn't made")

	// Bolted: left alone
	var/obj/machinery/door/airlock/door = make_door(spot(2, 2))
	door.bolt()
	TEST_ASSERT(!doors.try_door(), "The gorilla went for a bolted door")
	door.unbolt()

	// Space behind it: left shut
	var/turf/outside = spot(2, 3)
	changed_turfs += outside
	outside.ChangeTurf(/turf/open/space)
	TEST_ASSERT(!doors.try_door(), "The gorilla went for a door with space behind it")
	outside = spot(2, 3)
	outside.ChangeTurf(/turf/open/floor/iron)

	// On a ship: left shut
	var/area/shuttle/ship_area = new()
	test_areas += ship_area
	original_areas[spot(2, 2)] = get_area(spot(2, 2))
	var/turf/door_turf = spot(2, 2)
	door_turf.change_area(get_area(door_turf), ship_area)
	TEST_ASSERT(!doors.try_door(), "The gorilla went for a door on a ship")
	door_turf.change_area(ship_area, original_areas[door_turf])
	original_areas -= door_turf

	// The hunter behind a plain shut door: a hand on it, and the set bonus forces it
	TEST_ASSERT(doors.try_door(), "The gorilla didn't go for the door the hunter is behind")
	sleep(2 SECONDS)
	TEST_ASSERT(!door.density, "The set bonus didn't force the door open")
	TEST_ASSERT_EQUAL(get_turf(criminal), spot(1, 2), "The gorilla walked through instead of forcing the door")

/// A Juggernaut with the arms gets the grab in its own rotation: not while its shield fills a hand, then held busy while it holds on, and free again after
/datum/unit_test/voidcrew_bounty_chrome/gorilla_juggernaut

/datum/unit_test/voidcrew_bounty_chrome/gorilla_juggernaut/Run()
	var/mob/living/carbon/human/hunter = make_person(spot(2, 2))
	var/mob/living/carbon/human/npc/bounty_criminal/boss/boss = make_criminal(make_record(3, "boss", null, "juggernaut", list("gorilla")), spot(1, 2)) // BOUNTY_KIT_JUGGERNAUT
	boss.ai_controller?.set_ai_status(AI_STATUS_OFF)
	var/list/arms = bounty_gorilla_arms(boss)
	TEST_ASSERT_EQUAL(length(arms), 2, "The Juggernaut's Gorilla Arms didn't go in")
	var/datum/action/cooldown/mob_cooldown/bounty_boss/chrome/ability
	for(var/datum/action/cooldown/mob_cooldown/bounty_boss/chrome/wrapped in boss.boss_abilities)
		if(istype(wrapped.move, /datum/bounty_chrome_move/gorilla_grab))
			ability = wrapped
	TEST_ASSERT_NOTNULL(ability, "The Juggernaut's grab isn't in its ability rotation")
	TEST_ASSERT(ability.windup >= 0.8 SECONDS, "The grab winds up for [ability.windup / 10] s") // BOUNTY_CHROME_TELL_MIN
	arm_reload(arms[1], 3.9 SECONDS)
	// Its tower shield fills its off hand (C8): one fist free, and the grab takes two
	var/obj/item/shield/riot/phalanx_buckler/shield = locate() in boss.held_items
	TEST_ASSERT_NOTNULL(shield, "The Juggernaut isn't holding its shield")
	TEST_ASSERT_EQUAL(length(boss.get_empty_held_indexes()), 1, "With its shield in hand, the Juggernaut doesn't have one fist free")
	TEST_ASSERT(!bounty_gorilla_fists_for_grab(boss), "With its shield in hand, the Juggernaut has two fists for the grab")
	TEST_ASSERT(!ability.worth_using(hunter), "The Juggernaut wanted the grab with its shield in hand")
	// Its shield broken (the gear lock keeps it from being dropped), both fists are free and the grab comes back
	qdel(shield)
	TEST_ASSERT(bounty_gorilla_fists_for_grab(boss), "Its shield gone, the Juggernaut doesn't have two fists for the grab")
	TEST_ASSERT(ability.worth_using(hunter), "The grab isn't worth using on a hunter beside it")
	TEST_ASSERT(ability.Trigger(target = hunter), "The grab ability wouldn't start")
	TEST_ASSERT_EQUAL(boss.pulling, hunter, "The Juggernaut's hand isn't on the hunter through its wind-up")
	sleep(1 SECONDS)
	TEST_ASSERT(held_by(hunter, boss), "The Juggernaut's grip didn't tighten")
	TEST_ASSERT_EQUAL(boss.boss_busy, "gorilla_hold", "Holding on, the Juggernaut isn't busy") // BOUNTY_GORILLA_BOSS_BUSY
	// The finisher or the hold's own clock (BOUNTY_GORILLA_HOLD_MAX, 4 s from the grip) lets go, whichever comes first
	var/waited = 0
	while((held_by(hunter, boss) || boss.boss_busy) && waited < 5 SECONDS)
		sleep(0.2 SECONDS)
		waited += 0.2 SECONDS
	TEST_ASSERT(!held_by(hunter, boss), "The Juggernaut never let go")
	TEST_ASSERT_NULL(boss.boss_busy, "The Juggernaut is still busy after the hold")
