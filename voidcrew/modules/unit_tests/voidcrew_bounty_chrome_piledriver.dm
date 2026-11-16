/**
 * Bounty hunting: the Meteor Piledriver on a criminal (C1), for
 * voidcrew/modules/bounties/chrome/bounty_chrome_piledriver.dm.
 *
 * Fork defines are included after the tests, so a test uses the literal value with a comment naming the
 * define. Criminals are real human NPCs with the player's leg frame in them; the leap, its shadow, the
 * crush and the shockwave are the implant's. Their AI is off, and each test drives the chrome by hand.
 * The test room is a 5x5 floor; turfs a test changes are put back when it ends.
 *
 * Renders: compile with -DBOUNTY_CHROME_RENDERS and the renders test writes the carrier's flat icons to
 * data/bounty_chrome_renders/; the crouch's dip, glow and reticle are composited from them.
 */
/datum/unit_test/voidcrew_bounty_chrome_piledriver
	abstract_type = /datum/unit_test/voidcrew_bounty_chrome_piledriver
	/// Turfs a test changed, put back to plain floor when it ends
	var/list/turf/changed_turfs = list()

/datum/unit_test/voidcrew_bounty_chrome_piledriver/Destroy()
	for(var/turf/changed as anything in changed_turfs)
		changed.ChangeTurf(/turf/open/floor/iron)
	changed_turfs = null
	return ..()

/// A record of `tier`, `archetype` and `style` or `kit`, carrying `chrome`, for a human
/datum/unit_test/voidcrew_bounty_chrome_piledriver/proc/make_record(tier = 2, archetype = "normal", style = "brawler", kit, list/chrome)
	var/datum/bounty_record/record = generate_bounty_record(tier, archetype, "planet", /datum/species/human) // BOUNTY_PLACEMENT_PLANET
	record.tier = tier
	record.archetype = archetype
	record.style = archetype == "boss" ? null : style // BOUNTY_ARCHETYPE_BOSS
	record.kit = kit
	record.chrome = chrome
	return record

/// The criminal for `record` at `where`, its AI off, deleted with the test
/datum/unit_test/voidcrew_bounty_chrome_piledriver/proc/make_criminal(datum/bounty_record/record, turf/where)
	var/mob/living/carbon/human/npc/bounty_criminal/criminal = spawn_bounty_criminal(record, where || run_loc_floor_bottom_left, null)
	if(criminal)
		allocated += criminal
		criminal.ai_controller?.set_ai_status(AI_STATUS_OFF)
	return criminal

/// A Wanted brawler with the Piledriver at `where`
/datum/unit_test/voidcrew_bounty_chrome_piledriver/proc/make_leaper(turf/where)
	return make_criminal(make_record(2, "normal", "brawler", null, list("piledriver")), where) // BOUNTY_TIER_WANTED, BOUNTY_CHROME_PILEDRIVER

/// A person with a mind at `where`, deleted with the test
/datum/unit_test/voidcrew_bounty_chrome_piledriver/proc/make_person(turf/where)
	var/mob/living/carbon/human/person = allocate(/mob/living/carbon/human/consistent, where || run_loc_floor_top_right)
	person.mind_initialize()
	return person

/// A turf `dx`, `dy` from the bottom left of the test room
/datum/unit_test/voidcrew_bounty_chrome_piledriver/proc/spot(dx, dy)
	return locate(run_loc_floor_bottom_left.x + dx, run_loc_floor_bottom_left.y + dy, run_loc_floor_bottom_left.z)

/// Changes `where` to `new_type`, to be put back when the test ends
/datum/unit_test/voidcrew_bounty_chrome_piledriver/proc/change_turf(turf/where, new_type)
	changed_turfs |= where
	return where.ChangeTurf(new_type)

/// `criminal`'s Piledriver move
/datum/unit_test/voidcrew_bounty_chrome_piledriver/proc/move_of(mob/living/carbon/human/npc/criminal)
	var/datum/component/bounty_chrome/chrome = criminal.GetComponent(/datum/component/bounty_chrome)
	return chrome?.move_of(/datum/bounty_chrome_move/piledriver)

/// `criminal`'s own Meteor Leap button
/datum/unit_test/voidcrew_bounty_chrome_piledriver/proc/leap_action(mob/living/carbon/human/npc/criminal)
	return bounty_chrome_action(criminal, /datum/action/cooldown/cyberware/piledriver_leap)

/// Whether the implant's landing shadow is on `where`
/datum/unit_test/voidcrew_bounty_chrome_piledriver/proc/shadow_on(turf/where)
	return !isnull(locate(/obj/effect/temp_visual/cyberware_piledriver_shadow) in where)

/// Whether the crouch's reticle (a boss floor mark) is on `where`
/datum/unit_test/voidcrew_bounty_chrome_piledriver/proc/reticle_on(turf/where)
	for(var/obj/effect/temp_visual/bounty_boss_mark/mark in where)
		if(mark.icon_state == "target_circle")
			return TRUE
	return FALSE

/// How many crouch reticles are anywhere in the test room
/datum/unit_test/voidcrew_bounty_chrome_piledriver/proc/reticles()
	. = 0
	for(var/turf/room_turf as anything in block(spot(0, 0), spot(4, 4)))
		for(var/obj/effect/temp_visual/bounty_boss_mark/mark in room_turf)
			if(mark.icon_state == "target_circle")
				.++

// ===== THE LEAP =====

/**
 * A whole leap from the fight's planning: the crouch (standing still, sunk, glowing, a reticle on its
 * target that follows them), then the implant's own leap onto where they stand when the crouch ends,
 * its shadow, and its landing: the target crushed, a hunter in the ring knocked down, one outside it
 * untouched. Never a companion's piece.
 */
/datum/unit_test/voidcrew_bounty_chrome_piledriver/leap

/datum/unit_test/voidcrew_bounty_chrome_piledriver/leap/Run()
	var/turf/start = spot(0, 0)
	var/turf/aim = spot(3, 0)
	var/turf/stepped_to = spot(3, 1)
	var/datum/bounty_chrome_piece/piece = GLOB.bounty_chrome_pieces["piledriver"]
	TEST_ASSERT(!piece.companion, "Companions can roll the Piledriver")
	var/mob/living/carbon/human/target = make_person(aim)
	var/mob/living/carbon/human/ring_hunter = make_person(spot(4, 2))
	var/mob/living/carbon/human/outside_hunter = make_person(spot(0, 4))
	var/mob/living/carbon/human/npc/bounty_criminal/criminal = make_leaper(start)
	TEST_ASSERT_NOTNULL(locate(/obj/item/organ/cyberimp/cyberware/piledriver) in criminal.organs, "The criminal has no Piledriver in it")
	var/datum/component/bounty_chrome/chrome = criminal.GetComponent(/datum/component/bounty_chrome)
	var/datum/bounty_chrome_move/piledriver/move = move_of(criminal)
	TEST_ASSERT_NOTNULL(move, "The Piledriver has no move")
	TEST_ASSERT(move.tell_time >= 0.8 SECONDS, "The crouch is [move.tell_time / 10] s") // BOUNTY_CHROME_TELL_MIN
	TEST_ASSERT(move.area_move, "The leap isn't held to the bystander rule")
	TEST_ASSERT(criminal.ai_start_fight(target), "The criminal wouldn't fight")
	// In the fight too (it attacked them, say): the shockwave may catch them
	criminal.body_add_grudge(ring_hunter)
	chrome.update_fight()
	TEST_ASSERT(chrome.next_move_at - world.time <= 1.5 SECONDS, "The first leap waits [(chrome.next_move_at - world.time) / 10] s into the fight") // BOUNTY_CHROME_OPENING
	chrome.next_move_at = 0
	var/datum/action/cooldown/cyberware/piledriver_leap/leap = leap_action(criminal)
	TEST_ASSERT_NOTNULL(leap, "The Piledriver has no Meteor Leap")

	TEST_ASSERT(move.can_start(target), "It won't leap at a hunter three tiles off in the open")
	TEST_ASSERT_EQUAL(chrome.plan(criminal.ai_controller, 1), SUBTREE_RETURN_FINISH_PLANNING, "A ready leap didn't start")
	TEST_ASSERT_EQUAL(chrome.telling, move, "The crouch isn't running")
	TEST_ASSERT(HAS_TRAIT_FROM(criminal, TRAIT_IMMOBILIZED, "bounty_chrome"), "It doesn't stand still in the crouch") // BOUNTY_CHROME_TRAIT
	TEST_ASSERT_NOTNULL(criminal.get_filter(move.tell_filter()), "The crouch doesn't glow")
	TEST_ASSERT(criminal.pixel_z < criminal.base_pixel_z, "It doesn't sink into the crouch")
	TEST_ASSERT(reticle_on(aim), "No reticle on its target in the crouch")
	// Its target steps aside: the reticle follows
	target.forceMove(stepped_to)
	TEST_ASSERT(reticle_on(stepped_to), "The reticle didn't follow its target")
	TEST_ASSERT_EQUAL(reticles(), 1, "The reticle was left behind or doubled")
	sleep(0.6 SECONDS)
	TEST_ASSERT(leap.next_use_time <= world.time, "It leapt before the crouch was over")
	TEST_ASSERT_EQUAL(criminal.loc, start, "It moved in the crouch")

	sleep(0.5 SECONDS)
	TEST_ASSERT(leap.next_use_time > world.time + 50 SECONDS, "The crouch ended with no leap (the implant's minute of cooldown didn't start)")
	TEST_ASSERT(shadow_on(stepped_to), "The implant's shadow isn't where its target went")
	TEST_ASSERT_EQUAL(reticles(), 0, "The reticle stayed on in the air")
	TEST_ASSERT(!HAS_TRAIT_FROM(criminal, TRAIT_IMMOBILIZED, "bounty_chrome"), "The crouch's hold stayed on")
	TEST_ASSERT(HAS_TRAIT(criminal, TRAIT_IMMOBILIZED), "It isn't held by its own leap in the air")
	TEST_ASSERT_EQUAL(criminal.loc, start, "It arrived before its time in the air was over")
	TEST_ASSERT(target.getBruteLoss() == 0, "The target was hurt before the landing")

	sleep(1 SECONDS)
	TEST_ASSERT_EQUAL(criminal.loc, stepped_to, "It didn't land on the shadow")
	TEST_ASSERT(target.getBruteLoss() > 0 && target.IsParalyzed(), "The hunter under it wasn't crushed")
	TEST_ASSERT(ring_hunter.IsKnockdown(), "A hunter in the ring wasn't knocked down")
	TEST_ASSERT(outside_hunter.getBruteLoss() == 0 && !outside_hunter.IsKnockdown(), "A hunter outside the ring was caught")
	TEST_ASSERT(!HAS_TRAIT(criminal, TRAIT_IMMOBILIZED), "It is still held after landing")
	TEST_ASSERT_EQUAL(criminal.pixel_z, criminal.base_pixel_z, "It is still up in the air, or still crouched")
	TEST_ASSERT(!move.can_start(target), "It would leap again with the implant cooling down")

/**
 * Where it lands: never at someone too close; over a table; never through a wall; beside a target on
 * lava, or off its leash; and in the air it comes down as the player's leap does, stunned or not.
 */
/datum/unit_test/voidcrew_bounty_chrome_piledriver/reach

/datum/unit_test/voidcrew_bounty_chrome_piledriver/reach/Run()
	var/turf/aim = spot(3, 0)
	var/mob/living/carbon/human/target = make_person(aim)
	var/mob/living/carbon/human/npc/bounty_criminal/criminal = make_leaper(spot(0, 0))
	var/datum/bounty_chrome_move/piledriver/move = move_of(criminal)
	TEST_ASSERT(criminal.ai_start_fight(target), "The criminal wouldn't fight")
	TEST_ASSERT_EQUAL(move.landing_for(target), aim, "It wouldn't land on a hunter three tiles off in the open")

	target.forceMove(spot(2, 0))
	TEST_ASSERT(!move.can_start(target), "It would leap at a hunter two tiles off") // BOUNTY_PILEDRIVER_MIN_RANGE
	target.forceMove(aim)

	var/obj/structure/table/table = allocate(/obj/structure/table, spot(2, 0))
	TEST_ASSERT_EQUAL(move.landing_for(target), aim, "A table between them stopped the leap")
	qdel(table)

	// A target on a table: it lands beside them
	table = allocate(/obj/structure/table, aim)
	var/turf/off_table_landing = move.landing_for(target)
	TEST_ASSERT(off_table_landing && off_table_landing != aim && get_dist(off_table_landing, aim) == 1, "With its target on a table it would land on the table, or not beside them")
	qdel(table)

	for(var/dy in 0 to 4)
		change_turf(spot(2, dy), /turf/closed/wall)
	TEST_ASSERT_NULL(move.landing_for(target), "It would leap through a wall")
	TEST_ASSERT(!move.can_start(target), "It would start a leap through a wall")
	for(var/dy in 0 to 4)
		change_turf(spot(2, dy), /turf/open/floor/iron)

	// Never onto lava: beside it instead
	ADD_TRAIT(target, TRAIT_LAVA_IMMUNE, TRAIT_GENERIC)
	change_turf(aim, /turf/open/lava/smooth)
	var/turf/landing = move.landing_for(target)
	TEST_ASSERT_NOTNULL(landing, "With its target on lava it found nowhere to land")
	TEST_ASSERT(landing && !islava(landing) && get_dist(landing, aim) == 1, "It would land on lava, or not beside its target")
	change_turf(aim, /turf/open/floor/iron)
	REMOVE_TRAIT(target, TRAIT_LAVA_IMMUNE, TRAIT_GENERIC)

	// Never off its leash: its site ends a column short of its target
	var/turf/corner = spot(0, 0)
	criminal.site_bounds = list(corner.x, corner.y, corner.x + 2, corner.y + 4, corner.z)
	landing = move.landing_for(target)
	TEST_ASSERT(landing && criminal.leash_ok(landing), "It would land off its leash")
	criminal.site_bounds = null

	// Shot or stunned in the air, it still comes down on the shadow, as a player's leap does
	TEST_ASSERT(move.fire(target), "It didn't leap")
	TEST_ASSERT(shadow_on(aim), "No shadow under its target")
	criminal.Paralyze(2 SECONDS)
	sleep(1 SECONDS)
	TEST_ASSERT_EQUAL(criminal.loc, aim, "Stunned in the air, it didn't come down on the shadow")
	TEST_ASSERT(target.getBruteLoss() > 0, "Its landing crushed nobody")

/**
 * Never onto anyone outside its fight, its own companion, or anyone down: it doesn't start, and someone
 * stepping into the landing during the crouch calls it off with the pistons settling and nothing spent.
 */
/datum/unit_test/voidcrew_bounty_chrome_piledriver/bystanders

/datum/unit_test/voidcrew_bounty_chrome_piledriver/bystanders/Run()
	var/mob/living/carbon/human/target = make_person(spot(3, 0))
	var/mob/living/carbon/human/bystander = make_person(spot(4, 2))
	var/mob/living/carbon/human/npc/bounty_criminal/criminal = make_leaper(spot(0, 0))
	var/datum/component/bounty_chrome/chrome = criminal.GetComponent(/datum/component/bounty_chrome)
	var/datum/bounty_chrome_move/piledriver/move = move_of(criminal)
	var/datum/action/cooldown/cyberware/piledriver_leap/leap = leap_action(criminal)
	TEST_ASSERT(criminal.ai_start_fight(target), "The criminal wouldn't fight")
	chrome.update_fight()
	chrome.next_move_at = 0
	TEST_ASSERT(!move.can_start(target), "It would leap with a bystander in the landing")
	TEST_ASSERT_NULL(chrome.plan(criminal.ai_controller, 1), "It planned a leap onto a bystander")
	bystander.forceMove(spot(0, 4))
	TEST_ASSERT(move.can_start(target), "With the bystander clear it won't leap")

	// A bystander walks in during the crouch: it calls the leap off
	TEST_ASSERT(chrome.start_move(move, target), "The crouch didn't start")
	bystander.forceMove(spot(4, 1))
	sleep(1.2 SECONDS)
	TEST_ASSERT_EQUAL(criminal.loc, spot(0, 0), "It leapt onto a bystander who walked in")
	TEST_ASSERT(leap.next_use_time <= world.time, "Calling the leap off spent the implant's cooldown")
	TEST_ASSERT(!shadow_on(spot(3, 0)), "A called-off leap left a shadow")
	TEST_ASSERT_EQUAL(reticles(), 0, "A called-off leap left its reticle")
	TEST_ASSERT_EQUAL(criminal.pixel_z, criminal.base_pixel_z, "It is still crouched")
	bystander.forceMove(spot(0, 4))

	// Its own companion in the landing
	var/list/buddies = criminal.spawn_companions(1, TRUE)
	TEST_ASSERT(length(buddies), "No companion spawned")
	allocated += buddies
	var/mob/living/carbon/human/npc/bounty_companion/buddy = buddies[1]
	buddy.ai_controller?.set_ai_status(AI_STATUS_OFF)
	buddy.forceMove(spot(4, 1))
	TEST_ASSERT(!move.can_start(target), "It would leap onto its own companion")
	buddy.forceMove(spot(1, 4))
	TEST_ASSERT(move.can_start(target), "With its companion clear it won't leap")

	// A hunter in its fight, down in the landing
	var/mob/living/carbon/human/fallen_hunter = make_person(spot(4, 0))
	criminal.body_add_grudge(fallen_hunter)
	TEST_ASSERT(move.can_start(target), "A hunter on its feet in its fight stops the leap")
	fallen_hunter.setOxyLoss(fallen_hunter.health + 20)
	TEST_ASSERT(fallen_hunter.stat != CONSCIOUS && fallen_hunter.stat != DEAD, "The downed hunter isn't down")
	TEST_ASSERT(!move.can_start(target), "It would leap onto someone who is down")

/// An EMP, a stun or crit in the crouch stops it: no leap, nothing spent, the reticle and the crouch gone; a stunned criminal starts none
/datum/unit_test/voidcrew_bounty_chrome_piledriver/interrupted

/datum/unit_test/voidcrew_bounty_chrome_piledriver/interrupted/Run()
	var/turf/start = spot(0, 0)
	var/turf/aim = spot(3, 0)
	var/mob/living/carbon/human/target = make_person(aim)
	for(var/way in list("emp", "stunned", "downed"))
		var/mob/living/carbon/human/npc/bounty_criminal/criminal = make_leaper(start)
		var/datum/component/bounty_chrome/chrome = criminal.GetComponent(/datum/component/bounty_chrome)
		var/datum/bounty_chrome_move/piledriver/move = move_of(criminal)
		var/datum/action/cooldown/cyberware/piledriver_leap/leap = leap_action(criminal)
		TEST_ASSERT(criminal.ai_start_fight(target), "[way]: the criminal wouldn't fight")
		chrome.update_fight()
		TEST_ASSERT(chrome.start_move(move, target), "[way]: the crouch didn't start")
		TEST_ASSERT(reticle_on(aim), "[way]: no reticle in the crouch")
		switch(way)
			if("emp")
				criminal.emp_act(EMP_HEAVY)
			if("stunned")
				criminal.Paralyze(3 SECONDS)
			if("downed")
				criminal.setOxyLoss(criminal.health + 20)
		TEST_ASSERT_NULL(chrome.telling, "[way]: the crouch kept running")
		TEST_ASSERT_EQUAL(reticles(), 0, "[way]: the reticle stayed")
		TEST_ASSERT(!HAS_TRAIT_FROM(criminal, TRAIT_IMMOBILIZED, "bounty_chrome"), "[way]: the crouch's hold stayed on")
		sleep(1.2 SECONDS)
		TEST_ASSERT_EQUAL(criminal.loc, start, "[way]: it leapt anyway")
		TEST_ASSERT(leap.next_use_time <= world.time, "[way]: the implant's cooldown was spent on a leap that never came")
		TEST_ASSERT(!shadow_on(aim), "[way]: a shadow came down anyway")
		TEST_ASSERT(target.getBruteLoss() == 0, "[way]: the target was hurt")
		if(way == "emp")
			TEST_ASSERT(!move.ready(), "The Piledriver is ready through its EMP reboot")
		else
			TEST_ASSERT(!move.can_start(target), "[way]: it would start a leap")
		qdel(criminal)

// ===== MINI-BOSSES =====

/// The Pyromaniac leaps through its ability rotation: the wind-up is the crouch, the effect the implant's own leap
/datum/unit_test/voidcrew_bounty_chrome_piledriver/boss

/datum/unit_test/voidcrew_bounty_chrome_piledriver/boss/Run()
	var/turf/aim = spot(3, 0)
	var/mob/living/carbon/human/target = make_person(aim)
	var/mob/living/carbon/human/npc/bounty_criminal/boss/boss = make_criminal(make_record(3, "boss", null, "pyromaniac", list("piledriver")), spot(0, 0)) // BOUNTY_TIER_MOST_WANTED, BOUNTY_KIT_PYROMANIAC
	TEST_ASSERT(istype(boss, /mob/living/carbon/human/npc/bounty_criminal/boss/pyromaniac), "No Pyromaniac spawned")
	TEST_ASSERT_NOTNULL(locate(/obj/item/organ/cyberimp/cyberware/piledriver) in boss.organs, "The Pyromaniac has no Piledriver in it")
	var/datum/action/cooldown/mob_cooldown/bounty_boss/chrome/ability
	for(var/datum/action/cooldown/mob_cooldown/bounty_boss/chrome/wrapped in boss.boss_abilities)
		if(istype(wrapped.move, /datum/bounty_chrome_move/piledriver))
			ability = wrapped
	TEST_ASSERT_NOTNULL(ability, "The Pyromaniac's Piledriver isn't in its ability rotation")
	TEST_ASSERT(ability.windup >= 0.8 SECONDS, "The Pyromaniac's crouch is [ability.windup / 10] s") // BOUNTY_CHROME_TELL_MIN
	TEST_ASSERT(ability.worth_using(target), "The Pyromaniac won't leap at a hunter three tiles off")
	TEST_ASSERT(ability.Trigger(target = target), "The Pyromaniac's leap wouldn't start")
	TEST_ASSERT_EQUAL(boss.boss_busy, "windup", "The Pyromaniac isn't crouching")
	TEST_ASSERT(reticle_on(aim), "The Pyromaniac's crouch has no reticle")
	sleep(2.2 SECONDS)
	TEST_ASSERT_EQUAL(boss.loc, aim, "The Pyromaniac didn't come down on its target")
	TEST_ASSERT(target.getBruteLoss() > 0, "The Pyromaniac's landing crushed nobody")
	TEST_ASSERT_EQUAL(reticles(), 0, "The Pyromaniac's reticle stayed")

// ===== RENDERS =====

/// Not a check: with -DBOUNTY_CHROME_RENDERS, writes a Piledriver carrier's flat icons to data/bounty_chrome_renders/, for the crouch composite
/datum/unit_test/voidcrew_bounty_chrome_piledriver/renders

/datum/unit_test/voidcrew_bounty_chrome_piledriver/renders/Run()
	var/mob/living/carbon/human/npc/bounty_criminal/criminal = make_leaper(spot(1, 1))
	var/mob/living/carbon/human/target = make_person(spot(4, 1))
	TEST_ASSERT_NOTNULL(locate(/obj/item/organ/cyberimp/cyberware/piledriver) in criminal.organs, "The carrier has no Piledriver")
	TEST_ASSERT_NOTNULL(target, "No one to leap at")
#ifdef BOUNTY_CHROME_RENDERS
	for(var/facing in list(SOUTH, EAST))
		fcopy(getFlatIcon(criminal, facing), "data/bounty_chrome_renders/piledriver_carrier_[dir2text(facing)].png")
	fcopy(getFlatIcon(target, WEST), "data/bounty_chrome_renders/piledriver_target_west.png")
#endif
