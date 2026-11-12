/**
 * Bounty chrome: Mantis Blades (C2), for voidcrew/modules/bounties/chrome/bounty_chrome_mantis.dm.
 *
 * Criminals carry the real housings; the tests read tg's own state (held items, wounds, knockdown, the
 * lunge action's cooldown). The AI is switched off and the chrome driven through its own procs, so nothing
 * else happens in between. Fork defines are included after the tests, so literals stand in for them with
 * a comment naming the define. The test room is a 5x5 floor.
 */

/// A Petty knife criminal with the blades in at `where`, its AI off
/datum/unit_test/voidcrew_bounty_chrome/proc/make_mantis(turf/where, style = "knife")
	var/mob/living/carbon/human/npc/bounty_criminal/criminal = make_criminal(make_record(1, "normal", style, null, list("mantis")), where) // BOUNTY_CHROME_MANTIS
	criminal?.ai_controller?.set_ai_status(AI_STATUS_OFF)
	return criminal

/// Starts `criminal`'s fight with `hunter` and returns its chrome
/datum/unit_test/voidcrew_bounty_chrome/proc/chrome_fight(mob/living/carbon/human/npc/bounty_criminal/criminal, mob/living/hunter)
	criminal.ai_start_fight(hunter)
	var/datum/component/bounty_chrome/chrome = criminal.GetComponent(/datum/component/bounty_chrome)
	chrome?.update_fight()
	return chrome

/// The mantis blades `body` holds
/datum/unit_test/voidcrew_bounty_chrome/proc/held_blades(mob/living/carbon/body)
	. = list()
	for(var/obj/item/melee/energy/blade/hardlight/cyberware_mantis/blade in body.held_items)
		. += blade

/// Blades out in a fight, one a click, into free hands; its knife stays in its pocket; the blade is its weapon and cuts real wounds; it can't be made to drop them; they go back in when it goes down
/datum/unit_test/voidcrew_bounty_chrome/mantis_blades

/datum/unit_test/voidcrew_bounty_chrome/mantis_blades/Run()
	var/mob/living/carbon/human/hunter = make_person(spot(3, 2))
	var/mob/living/carbon/human/npc/bounty_criminal/criminal = make_mantis(spot(1, 2))
	TEST_ASSERT_NOTNULL(criminal, "No Mantis criminal spawned")
	var/list/housings = bounty_mantis_housings(criminal)
	TEST_ASSERT_EQUAL(length(housings), 2, "The criminal carries [length(housings)] Mantis housings, not the pair")
	for(var/obj/item/organ/cyberimp/arm/toolkit/cyberware/mantis/housing as anything in housings)
		TEST_ASSERT(!housing.blade_extended(), "A blade is out before any fight")
		for(var/obj/item/blade as anything in bounty_mantis_blades(housing))
			TEST_ASSERT(human_npc_gear_locked(blade), "The [housing]'s blade isn't locked to the body like its other gear")
	var/datum/component/bounty_chrome/chrome = criminal.GetComponent(/datum/component/bounty_chrome)
	TEST_ASSERT_NOTNULL(chrome, "The Mantis criminal has no chrome AI")
	var/datum/bounty_chrome_move/mantis_blades/blades = chrome.move_of(/datum/bounty_chrome_move/mantis_blades)
	TEST_ASSERT_NOTNULL(blades, "The blades' move wasn't made")
	TEST_ASSERT(!blades.plan(criminal.ai_controller, hunter), "A blade came out with no fight on")

	chrome_fight(criminal, hunter)
	TEST_ASSERT(blades.plan(criminal.ai_controller, hunter), "No blade came out when the fight started")
	TEST_ASSERT_EQUAL(length(held_blades(criminal)), 1, "Both blades came out in one click")
	TEST_ASSERT(blades.plan(criminal.ai_controller, hunter), "The second blade didn't come out")
	TEST_ASSERT(!blades.plan(criminal.ai_controller, hunter), "A third click put something out")
	var/list/out = held_blades(criminal)
	TEST_ASSERT_EQUAL(length(out), 2, "The criminal holds [length(out)] blades, not one in each hand")
	for(var/obj/item/organ/cyberimp/arm/toolkit/cyberware/mantis/housing as anything in housings)
		TEST_ASSERT(housing.blade_extended(), "The [housing]'s blade isn't out")
	TEST_ASSERT_NULL(locate(/obj/item/knife) in criminal.held_items, "The criminal drew its knife as well")
	TEST_ASSERT_NOTNULL(locate(/obj/item/knife) in criminal.get_all_contents(), "The criminal lost its knife")
	var/obj/item/weapon = human_npc_held_melee_weapon(criminal)
	TEST_ASSERT(istype(weapon, /obj/item/melee/energy/blade/hardlight/cyberware_mantis), "The criminal fights with [weapon], not its blades")

	// They never leave its hands
	var/obj/item/blade = out[1]
	TEST_ASSERT(HAS_TRAIT(blade, TRAIT_NODROP), "A blade that is out can be dropped")
	TEST_ASSERT(HAS_TRAIT(blade, TRAIT_NO_STRIP), "A blade that is out can be stripped")
	criminal.dropItemToGround(blade)
	criminal.drop_all_held_items()
	TEST_ASSERT_EQUAL(length(held_blades(criminal)), 2, "Dropping things made the criminal let go of a blade")
	TEST_ASSERT_NULL(locate(/obj/item/melee/energy/blade/hardlight/cyberware_mantis) in spot(1, 2), "A blade lies on the floor")

	// Its cuts are the blade's own: brute, and in time tg's slash wound
	hunter.forceMove(spot(2, 2))
	var/datum/wound/slash/cut
	for(var/i in 1 to 8)
		criminal.next_move = 0
		criminal.next_click = 0
		criminal.zone_selected = BODY_ZONE_CHEST
		human_npc_ready_item(criminal, blade)
		criminal.ai_controller.ai_interact(target = hunter, combat_mode = TRUE)
		cut = locate() in hunter.all_wounds
		if(cut || hunter.stat == DEAD)
			break
	TEST_ASSERT(hunter.getBruteLoss() > 0, "The blades did nothing")
	TEST_ASSERT_NOTNULL(cut, "Eight blade hits opened no slash wound")

	// Down in crit: they go back in, into the housings
	criminal.setOxyLoss(criminal.health + 20)
	TEST_ASSERT(HAS_TRAIT(criminal, TRAIT_CRITICAL_CONDITION), "The criminal isn't in crit for the downed check")
	TEST_ASSERT_EQUAL(length(held_blades(criminal)), 0, "Downed, the criminal still holds its blades")
	for(var/obj/item/organ/cyberimp/arm/toolkit/cyberware/mantis/housing as anything in housings)
		TEST_ASSERT(!housing.blade_extended(), "Downed, the [housing]'s blade is still out")
		for(var/obj/item/housed as anything in bounty_mantis_blades(housing))
			TEST_ASSERT_EQUAL(housed.loc, housing, "Downed, a blade is somewhere other than its housing")

/// The blades go away when the fight is over, when it is cuffed, during an EMP's reboot, and with the chrome when it dies; a bat stays in hand and the other blade does the work
/datum/unit_test/voidcrew_bounty_chrome/mantis_blades_away

/datum/unit_test/voidcrew_bounty_chrome/mantis_blades_away/Run()
	var/mob/living/carbon/human/hunter = make_person(spot(3, 2))
	var/list/ways = list("calm", "cuffed", "emp", "death")
	for(var/way in ways)
		var/mob/living/carbon/human/npc/bounty_criminal/criminal = make_mantis(spot(1, 2))
		var/datum/component/bounty_chrome/chrome = chrome_fight(criminal, hunter)
		var/datum/bounty_chrome_move/mantis_blades/blades = chrome.move_of(/datum/bounty_chrome_move/mantis_blades)
		blades.plan(criminal.ai_controller, hunter)
		blades.plan(criminal.ai_controller, hunter)
		var/list/out = held_blades(criminal)
		TEST_ASSERT_EQUAL(length(out), 2, "[way]: the blades didn't come out")
		switch(way)
			if("calm")
				criminal.ai_calm_down()
				chrome.update_fight()
			if("cuffed")
				var/obj/item/restraints/handcuffs/cuffs = new(criminal)
				criminal.set_handcuffed(cuffs)
				criminal.update_handcuffed()
			if("emp")
				criminal.emp_act(EMP_HEAVY)
			if("death")
				criminal.death()
		TEST_ASSERT_EQUAL(length(held_blades(criminal)), 0, "[way]: a blade is still in hand")
		if(way == "emp")
			// Through the reboot nothing comes out, however often it plans
			TEST_ASSERT(!blades.plan(criminal.ai_controller, hunter), "A blade came out during the EMP's reboot")
			TEST_ASSERT_EQUAL(length(held_blades(criminal)), 0, "A blade is out during the EMP's reboot")
		if(way == "death")
			sleep(1)
			for(var/obj/item/blade as anything in out)
				TEST_ASSERT(QDELETED(blade), "A dead criminal's blade outlived its burnt-out housing")
			TEST_ASSERT_NULL(locate(/obj/item/melee/energy/blade/hardlight/cyberware_mantis) in spot(1, 2), "A dead criminal left a blade on the floor")
		qdel(criminal)

	// A club fighter's bat has nowhere to go: that arm keeps it, and the other blade comes out
	var/mob/living/carbon/human/npc/bounty_criminal/clubber = make_mantis(spot(1, 2), "club")
	var/datum/component/bounty_chrome/club_chrome = chrome_fight(clubber, hunter)
	var/datum/bounty_chrome_move/mantis_blades/club_blades = club_chrome.move_of(/datum/bounty_chrome_move/mantis_blades)
	var/obj/item/bat = locate(/obj/item/melee/baseball_bat) in clubber.held_items
	TEST_ASSERT_NOTNULL(bat, "The club fighter holds no bat")
	club_blades.plan(clubber.ai_controller, hunter)
	club_blades.plan(clubber.ai_controller, hunter)
	TEST_ASSERT_EQUAL(length(held_blades(clubber)), 1, "The club fighter has [length(held_blades(clubber))] blades out, not the one its free hand takes")
	TEST_ASSERT(clubber.is_holding(bat), "The club fighter dropped its bat for a blade")
	TEST_ASSERT_NULL(locate(/obj/item/melee/baseball_bat) in spot(1, 2), "The bat ended up on the floor")
	TEST_ASSERT(istype(human_npc_held_melee_weapon(clubber), /obj/item/melee/energy/blade/hardlight/cyberware_mantis), "The club fighter swings its bat, not its blade")

/// The lunge: never before its opener; a blue line and outline for its tell, standing still; then the housing's own Mantis Lunge: the dash, the cut and the knockdown, and its cooldown
/datum/unit_test/voidcrew_bounty_chrome/mantis_lunge

/datum/unit_test/voidcrew_bounty_chrome/mantis_lunge/Run()
	var/mob/living/carbon/human/hunter = make_person(spot(4, 2))
	var/mob/living/carbon/human/npc/bounty_criminal/criminal = make_mantis(spot(1, 2))
	var/datum/component/bounty_chrome/chrome = chrome_fight(criminal, hunter)
	var/datum/bounty_chrome_move/mantis_blades/blades = chrome.move_of(/datum/bounty_chrome_move/mantis_blades)
	var/datum/bounty_chrome_move/mantis_lunge/lunge = chrome.move_of(/datum/bounty_chrome_move/mantis_lunge)
	TEST_ASSERT_NOTNULL(lunge, "The lunge's move wasn't made")
	TEST_ASSERT(!lunge.can_start(hunter), "The lunge would start with the blades in")
	blades.plan(criminal.ai_controller, hunter)
	blades.plan(criminal.ai_controller, hunter)
	TEST_ASSERT(lunge.opens_at > world.time, "The first lunge may come the moment the fight starts")
	TEST_ASSERT(lunge.opens_at <= world.time + 1 SECONDS, "The first lunge waits more than a second") // BOUNTY_MANTIS_OPENING
	TEST_ASSERT(!lunge.plan(criminal.ai_controller, hunter), "A lunge started inside its opener")
	lunge.opens_at = 0
	TEST_ASSERT(lunge.can_start(hunter), "The lunge won't start at a hunter three tiles off in a clear line")
	TEST_ASSERT(lunge.plan(criminal.ai_controller, hunter), "A ready lunge didn't start")
	TEST_ASSERT_EQUAL(chrome.telling, lunge, "The lunge's tell isn't running")
	TEST_ASSERT(HAS_TRAIT_FROM(criminal, TRAIT_IMMOBILIZED, "bounty_chrome"), "The criminal doesn't stand still through the tell") // BOUNTY_CHROME_TRAIT
	TEST_ASSERT_NOTNULL(criminal.get_filter(lunge.tell_filter()), "The tell has no outline")
	for(var/dx in 2 to 4)
		var/obj/effect/temp_visual/bounty_boss_mark/mark = locate() in spot(dx, 2)
		TEST_ASSERT_NOTNULL(mark, "The line isn't marked [dx - 1] tiles out")
		TEST_ASSERT_EQUAL(mark?.icon_state, dx == 4 ? "target_circle" : "target_box", "The line's mark [dx - 1] tiles out is the wrong one")
	TEST_ASSERT_NULL(locate(/obj/effect/temp_visual/bounty_boss_mark) in spot(0, 2), "The line is marked behind the criminal")
	sleep(0.6 SECONDS)
	TEST_ASSERT_EQUAL(hunter.getBruteLoss(), 0, "The hunter was cut before the tell was over")
	// Standing still through the tell greys the button out (the lunge checks immobility), so read its cooldown
	for(var/obj/item/organ/cyberimp/arm/toolkit/cyberware/mantis/housing as anything in bounty_mantis_housings(criminal))
		var/datum/action/cooldown/cyberware/mantis_lunge/housing_lunge = locate() in housing.actions
		TEST_ASSERT(!housing_lunge || housing_lunge.next_use_time <= world.time, "The lunge was used before the tell was over")
	// The tell ends at 0.9 s, the implant's own telegraph runs 0.3 s, then the dash
	sleep(1 SECONDS)
	TEST_ASSERT_NULL(lunge.lunge_action(), "The housing's own Mantis Lunge wasn't used: it isn't cooling down")
	TEST_ASSERT_EQUAL(get_dist(criminal, hunter), 1, "The dash didn't carry the criminal to the hunter")
	TEST_ASSERT(hunter.getBruteLoss() > 0, "The lunge didn't cut the hunter")
	TEST_ASSERT(hunter.IsKnockdown() || hunter.body_position == LYING_DOWN, "The lunge didn't put the hunter down")
	TEST_ASSERT(!HAS_TRAIT_FROM(criminal, TRAIT_IMMOBILIZED, "bounty_chrome"), "The criminal still stands still after the tell")
	TEST_ASSERT_NULL(locate(/obj/effect/temp_visual/bounty_boss_mark) in spot(3, 2), "The line stayed lit after the tell")
	TEST_ASSERT(!lunge.can_start(hunter), "The lunge would start again at once")

/// No lunge at someone right beside it, on the floor, through a table, past a drop beside the line, or with a stun or an EMP in its tell
/datum/unit_test/voidcrew_bounty_chrome/mantis_lunge_refusals
	/// Turfs it changed, put back when it ends
	var/list/turf/changed_turfs = list()

/datum/unit_test/voidcrew_bounty_chrome/mantis_lunge_refusals/Destroy()
	for(var/turf/changed as anything in changed_turfs)
		changed.ChangeTurf(/turf/open/floor/iron)
	changed_turfs = null
	return ..()

/datum/unit_test/voidcrew_bounty_chrome/mantis_lunge_refusals/Run()
	var/mob/living/carbon/human/hunter = make_person(spot(4, 2))
	var/mob/living/carbon/human/npc/bounty_criminal/criminal = make_mantis(spot(1, 2))
	var/datum/component/bounty_chrome/chrome = chrome_fight(criminal, hunter)
	var/datum/bounty_chrome_move/mantis_blades/blades = chrome.move_of(/datum/bounty_chrome_move/mantis_blades)
	var/datum/bounty_chrome_move/mantis_lunge/lunge = chrome.move_of(/datum/bounty_chrome_move/mantis_lunge)
	blades.plan(criminal.ai_controller, hunter)
	blades.plan(criminal.ai_controller, hunter)
	lunge.opens_at = 0
	TEST_ASSERT(lunge.can_start(hunter), "The lunge won't start in the clear")

	hunter.forceMove(spot(2, 2))
	TEST_ASSERT(!lunge.can_start(hunter), "A lunge would start at someone right beside it")
	hunter.forceMove(spot(4, 2))

	hunter.Knockdown(2 SECONDS)
	TEST_ASSERT(!lunge.can_start(hunter), "A lunge would start at someone on the floor")
	hunter.SetKnockdown(0)
	hunter.get_up(instant = TRUE)
	TEST_ASSERT(lunge.can_start(hunter), "The lunge won't start once the hunter is up")

	var/obj/structure/table/table = allocate(/obj/structure/table, spot(3, 2))
	TEST_ASSERT(!lunge.can_start(hunter), "A lunge would start through a table it falls short at")
	qdel(table)

	var/turf/beside_line = spot(2, 3)
	changed_turfs += beside_line
	beside_line.ChangeTurf(/turf/open/space)
	TEST_ASSERT(!lunge.can_start(hunter), "A lunge would start beside open space")
	beside_line = spot(2, 3)
	beside_line.ChangeTurf(/turf/open/floor/iron)
	TEST_ASSERT(lunge.can_start(hunter), "The lunge won't start once the space is floor again")

	// Cut short: nothing fires, and the housing's lunge isn't spent
	for(var/way in list("stunned", "emp"))
		chrome.next_move_at = 0
		TEST_ASSERT(chrome.start_move(lunge, hunter), "[way]: the lunge's tell didn't start")
		if(way == "stunned")
			criminal.Paralyze(2 SECONDS)
		else
			criminal.emp_act(EMP_HEAVY)
		TEST_ASSERT_NULL(chrome.telling, "[way]: the tell kept running")
		sleep(1.4 SECONDS)
		TEST_ASSERT_EQUAL(hunter.getBruteLoss(), 0, "[way]: the hunter was cut anyway")
		TEST_ASSERT(get_dist(criminal, hunter) > 1, "[way]: the criminal dashed anyway")
		criminal.SetParalyzed(0)
		criminal.get_up(instant = TRUE)
	// The EMP put the blades away for its reboot: no lunge with them in
	TEST_ASSERT_EQUAL(length(held_blades(criminal)), 0, "The blades stayed out through the EMP")
	TEST_ASSERT(!lunge.can_start(hunter), "A lunge would start with the blades in after the EMP")

/// The dash runs down the line the tell lit: a hunter who steps off it is missed, and it stops on the tile before the line's end
/datum/unit_test/voidcrew_bounty_chrome/mantis_lunge_follows_line

/datum/unit_test/voidcrew_bounty_chrome/mantis_lunge_follows_line/Run()
	var/mob/living/carbon/human/hunter = make_person(spot(4, 2))
	var/mob/living/carbon/human/npc/bounty_criminal/criminal = make_mantis(spot(1, 2))
	var/datum/component/bounty_chrome/chrome = chrome_fight(criminal, hunter)
	var/datum/bounty_chrome_move/mantis_blades/blades = chrome.move_of(/datum/bounty_chrome_move/mantis_blades)
	var/datum/bounty_chrome_move/mantis_lunge/lunge = chrome.move_of(/datum/bounty_chrome_move/mantis_lunge)
	blades.plan(criminal.ai_controller, hunter)
	blades.plan(criminal.ai_controller, hunter)
	lunge.opens_at = 0
	chrome.next_move_at = 0
	TEST_ASSERT(chrome.start_move(lunge, hunter), "The lunge's tell didn't start")
	// One step off the lit line during the tell: still next to where the dash stops, but off the marked tile
	hunter.forceMove(spot(4, 3))
	sleep(1.6 SECONDS)
	TEST_ASSERT_NULL(lunge.lunge_action(), "The housing's own Mantis Lunge wasn't used")
	TEST_ASSERT_EQUAL(get_turf(criminal), spot(3, 2), "The dash didn't run down the lit line to its last tile")
	TEST_ASSERT_EQUAL(hunter.getBruteLoss(), 0, "The dash cut a hunter who had stepped off its line")

/// The player's lunge is the implant's ordinary one: it follows its target through the wind-up, passes over someone standing in the way, and stops at a window
/datum/unit_test/voidcrew_bounty_chrome/mantis_lunge_player

/datum/unit_test/voidcrew_bounty_chrome/mantis_lunge_player/Run()
	var/mob/living/carbon/human/lunger = make_person(spot(0, 2))
	var/mob/living/carbon/human/victim = make_person(spot(4, 2))
	var/obj/item/organ/cyberimp/arm/toolkit/cyberware/mantis/housing = allocate(/obj/item/organ/cyberimp/arm/toolkit/cyberware/mantis)
	TEST_ASSERT(housing.Insert(lunger, special = TRUE), "The housing wouldn't go in")
	housing.Extend(housing.contents[1])
	TEST_ASSERT(housing.blade_extended(), "The blade didn't come out")
	var/datum/action/cooldown/cyberware/mantis_lunge/press = locate() in housing.actions
	TEST_ASSERT_NOTNULL(press, "The housing has no lunge")

	var/mob/living/carbon/human/bystander = make_person(spot(2, 2))
	TEST_ASSERT(press.Trigger(target = victim), "The lunge wouldn't start past someone standing in the way")
	sleep(0.8 SECONDS)
	TEST_ASSERT_EQUAL(get_turf(lunger), spot(3, 2), "The player's lunge didn't pass over someone standing in the way")
	TEST_ASSERT(victim.getBruteLoss() > 0, "The player's lunge didn't cut its target")
	TEST_ASSERT_EQUAL(bystander.getBruteLoss(), 0, "The player's lunge cut whoever stood in the way")
	bystander.forceMove(spot(2, 4))

	// It follows its target through the wind-up
	lunger.forceMove(spot(0, 2))
	victim.get_up(instant = TRUE)
	var/brute_before = victim.getBruteLoss()
	press.ResetCooldown()
	TEST_ASSERT(press.Trigger(target = victim), "The lunge wouldn't start in the clear")
	victim.forceMove(spot(4, 3))
	sleep(0.8 SECONDS)
	TEST_ASSERT(lunger.Adjacent(victim), "The player's lunge didn't follow its target through the wind-up")
	TEST_ASSERT(victim.getBruteLoss() > brute_before, "The player's lunge didn't cut a target who moved in the wind-up")
	victim.forceMove(spot(4, 2))

	lunger.forceMove(spot(0, 2))
	brute_before = victim.getBruteLoss()
	var/obj/structure/window/fulltile/pane = allocate(/obj/structure/window/fulltile, spot(2, 2))
	press.ResetCooldown()
	TEST_ASSERT(press.Trigger(target = victim), "The lunge wouldn't start at someone behind a window")
	sleep(0.8 SECONDS)
	TEST_ASSERT_EQUAL(get_turf(lunger), spot(1, 2), "The player's lunge went through a window")
	// <=, not ==: the earlier cut may heal a little meanwhile
	TEST_ASSERT(victim.getBruteLoss() <= brute_before, "A lunge stopped by a window still cut its target")
	qdel(pane)

/// The bounty NPC's shown-line dash is a real run: someone who steps onto its line during the tell stops it short, and nobody is cut
/datum/unit_test/voidcrew_bounty_chrome/mantis_lunge_npc_blocked

/datum/unit_test/voidcrew_bounty_chrome/mantis_lunge_npc_blocked/Run()
	var/mob/living/carbon/human/hunter = make_person(spot(4, 2))
	var/mob/living/carbon/human/npc/bounty_criminal/criminal = make_mantis(spot(0, 2))
	var/datum/component/bounty_chrome/chrome = chrome_fight(criminal, hunter)
	var/datum/bounty_chrome_move/mantis_blades/blades = chrome.move_of(/datum/bounty_chrome_move/mantis_blades)
	var/datum/bounty_chrome_move/mantis_lunge/lunge = chrome.move_of(/datum/bounty_chrome_move/mantis_lunge)
	blades.plan(criminal.ai_controller, hunter)
	blades.plan(criminal.ai_controller, hunter)
	lunge.opens_at = 0
	chrome.next_move_at = 0
	TEST_ASSERT(chrome.start_move(lunge, hunter), "The lunge's tell didn't start")
	var/mob/living/carbon/human/bystander = make_person(spot(2, 2))
	sleep(1.6 SECONDS)
	TEST_ASSERT_NULL(lunge.lunge_action(), "The housing's own Mantis Lunge wasn't used")
	TEST_ASSERT_EQUAL(get_turf(criminal), spot(1, 2), "The NPC's dash went through someone standing on its line")
	TEST_ASSERT_EQUAL(hunter.getBruteLoss(), 0, "A dash stopped short still cut its target")
	TEST_ASSERT_EQUAL(bystander.getBruteLoss(), 0, "A dash stopped short cut whoever stopped it")

#ifdef BOUNTY_CHROME_RENDERS
/// Writes a Mantis criminal with its blades out, a Gorilla brawler and the tells' floor marks to data/bounty_chrome_renders/
/datum/unit_test/voidcrew_bounty_chrome/melee_chrome_renders

/datum/unit_test/voidcrew_bounty_chrome/melee_chrome_renders/Run()
	var/mob/living/carbon/human/hunter = make_person(spot(4, 2))
	var/mob/living/carbon/human/npc/bounty_criminal/criminal = make_mantis(spot(1, 2))
	var/datum/component/bounty_chrome/chrome = chrome_fight(criminal, hunter)
	var/datum/bounty_chrome_move/mantis_blades/blades = chrome.move_of(/datum/bounty_chrome_move/mantis_blades)
	blades.plan(criminal.ai_controller, hunter)
	blades.plan(criminal.ai_controller, hunter)
	for(var/facing in list(SOUTH, NORTH, EAST, WEST))
		fcopy(getFlatIcon(criminal, facing), "data/bounty_chrome_renders/mantis_blades_out_[dir2text(facing)].png")
	var/mob/living/carbon/human/npc/bounty_criminal/gorilla = make_criminal(make_record(1, "normal", "brawler", null, list("gorilla")), spot(0, 0)) // BOUNTY_CHROME_GORILLA
	gorilla.ai_controller?.set_ai_status(AI_STATUS_OFF)
	for(var/facing in list(SOUTH, NORTH, EAST))
		fcopy(getFlatIcon(gorilla, facing), "data/bounty_chrome_renders/gorilla_brawler_[dir2text(facing)].png")
	var/list/marks = list(
		"mark_mantis_line" = new /obj/effect/temp_visual/bounty_boss_mark(spot(0, 4), 10 SECONDS, list(0.42, 0.72, 1, 0, 0, 0, 0, 0, 0)), // BOUNTY_MANTIS_MARK_MATRIX
		"mark_mantis_end" = new /obj/effect/temp_visual/bounty_boss_mark(spot(1, 4), 10 SECONDS, list(0.42, 0.72, 1, 0, 0, 0, 0, 0, 0), "target_circle"),
		"mark_gorilla_punch" = new /obj/effect/temp_visual/bounty_boss_mark(spot(2, 4), 10 SECONDS),
		"mark_gorilla_grab" = new /obj/effect/temp_visual/bounty_boss_mark(spot(3, 4), 10 SECONDS, list(1, 0.54, 0.12, 0, 0, 0, 0, 0, 0), "target_circle"), // BOUNTY_GORILLA_MARK_MATRIX
	)
	for(var/name in marks)
		var/obj/effect/mark = marks[name]
		fcopy(getFlatIcon(mark, SOUTH), "data/bounty_chrome_renders/[name].png")
		qdel(mark)
	qdel(gorilla)
#endif
