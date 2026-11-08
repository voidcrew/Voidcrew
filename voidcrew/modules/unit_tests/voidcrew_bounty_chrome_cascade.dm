/**
 * Bounty hunting: the Cascade lattice on a criminal (C1), for
 * voidcrew/modules/bounties/chrome/bounty_chrome_cascade.dm.
 *
 * Fork defines are included after the tests, so a test uses the literal value with a comment naming the
 * define. Criminals are real human NPCs with the player's lattice in them; the tests read tg's state.
 * Their AI is off, and each test drives the chrome by hand.
 *
 * Renders: compile with -DBOUNTY_CHROME_RENDERS and the renders test writes flat icons to
 * data/bounty_chrome_renders/ (the carrier, and the lattice's afterimage at a few hues).
 */
/datum/unit_test/voidcrew_bounty_chrome_cascade
	abstract_type = /datum/unit_test/voidcrew_bounty_chrome_cascade

/// A record of `tier`, `archetype` and `style` or `kit`, carrying `chrome`, for a human
/datum/unit_test/voidcrew_bounty_chrome_cascade/proc/make_record(tier = 2, archetype = "normal", style = "brawler", kit, list/chrome)
	var/datum/bounty_record/record = generate_bounty_record(tier, archetype, "planet", /datum/species/human) // BOUNTY_PLACEMENT_PLANET
	record.tier = tier
	record.archetype = archetype
	record.style = archetype == "boss" ? null : style // BOUNTY_ARCHETYPE_BOSS
	record.kit = kit
	record.chrome = chrome
	return record

/// The criminal for `record` at `where`, its AI off, deleted with the test
/datum/unit_test/voidcrew_bounty_chrome_cascade/proc/make_criminal(datum/bounty_record/record, turf/where)
	var/mob/living/carbon/human/npc/bounty_criminal/criminal = spawn_bounty_criminal(record, where || run_loc_floor_bottom_left, null)
	if(criminal)
		allocated += criminal
		criminal.ai_controller?.set_ai_status(AI_STATUS_OFF)
	return criminal

/// A person with a mind at `where`, deleted with the test
/datum/unit_test/voidcrew_bounty_chrome_cascade/proc/make_person(turf/where)
	var/mob/living/carbon/human/person = allocate(/mob/living/carbon/human/consistent, where || run_loc_floor_top_right)
	person.mind_initialize()
	return person

/// A turf `dx`, `dy` from the bottom left of the test room (a 5x5 floor)
/datum/unit_test/voidcrew_bounty_chrome_cascade/proc/spot(dx, dy)
	return locate(run_loc_floor_bottom_left.x + dx, run_loc_floor_bottom_left.y + dy, run_loc_floor_bottom_left.z)

/// Whether the lattice's window is open on `body`
/datum/unit_test/voidcrew_bounty_chrome_cascade/proc/surging(mob/living/body)
	return !isnull(body.has_status_effect(/datum/status_effect/cyberware_cascade_window))

/// The lattice's own surge button in `body`
/datum/unit_test/voidcrew_bounty_chrome_cascade/proc/surge_action(mob/living/carbon/human/npc/body)
	return bounty_chrome_action(body, /datum/action/cooldown/cyberware/cascade_surge)

// ===== THE SURGE =====

/// The lattice's own surge fires after its tell (a glow and a whine, standing still, at least 0.8 s), early in a fight, and the body and its AI then run at the lattice's pace
/datum/unit_test/voidcrew_bounty_chrome_cascade/surge

/datum/unit_test/voidcrew_bounty_chrome_cascade/surge/Run()
	var/mob/living/carbon/human/hunter = make_person(spot(3, 0))
	var/mob/living/carbon/human/npc/bounty_criminal/criminal = make_criminal(make_record(2, "normal", "brawler", null, list("cascade"))) // BOUNTY_TIER_WANTED, BOUNTY_CHROME_CASCADE
	TEST_ASSERT_NOTNULL(locate(/obj/item/organ/cyberimp/cyberware/cascade) in criminal.organs, "The criminal has no lattice in it")
	var/datum/component/bounty_chrome/chrome = criminal.GetComponent(/datum/component/bounty_chrome)
	TEST_ASSERT_NOTNULL(chrome, "A criminal with a lattice has no chrome AI")
	var/datum/bounty_chrome_move/cascade/move = chrome.move_of(/datum/bounty_chrome_move/cascade)
	TEST_ASSERT_NOTNULL(move, "The lattice has no move")
	TEST_ASSERT(move.tell_time >= 0.8 SECONDS, "The surge's tell is [move.tell_time / 10] s") // BOUNTY_CHROME_TELL_MIN
	TEST_ASSERT(move.boss_usable, "A mini-boss can't use the lattice")

	TEST_ASSERT(criminal.ai_start_fight(hunter), "The criminal wouldn't fight")
	chrome.update_fight()
	TEST_ASSERT(chrome.next_move_at - world.time <= 1.5 SECONDS, "The first surge waits [(chrome.next_move_at - world.time) / 10] s into the fight") // BOUNTY_CHROME_OPENING
	TEST_ASSERT_NULL(chrome.plan(criminal.ai_controller, 1), "It surged the moment the fight started")
	chrome.next_move_at = 0
	TEST_ASSERT(move.can_start(hunter), "It won't surge with a hunter close and in sight")
	var/slowdown_before = criminal.cached_multiplicative_slowdown
	TEST_ASSERT_EQUAL(chrome.plan(criminal.ai_controller, 1), SUBTREE_RETURN_FINISH_PLANNING, "A ready surge didn't start")
	TEST_ASSERT_EQUAL(chrome.telling, move, "The surge's tell isn't running")
	TEST_ASSERT_NOTNULL(criminal.get_filter(move.tell_filter()), "The tell doesn't glow")
	TEST_ASSERT(HAS_TRAIT_FROM(criminal, TRAIT_IMMOBILIZED, "bounty_chrome"), "It doesn't stand still through the tell") // BOUNTY_CHROME_TRAIT
	sleep(0.6 SECONDS)
	TEST_ASSERT(!surging(criminal), "The lattice surged before the tell was over")
	sleep(0.4 SECONDS)
	TEST_ASSERT(surging(criminal), "The tell ended but the lattice's own surge didn't run")
	var/datum/action/cooldown/cyberware/cascade_surge/surge_button = surge_action(criminal)
	TEST_ASSERT(surge_button.next_use_time > world.time + 50 SECONDS, "The surge didn't start the lattice's own minute of cooldown")
	TEST_ASSERT(!HAS_TRAIT_FROM(criminal, TRAIT_IMMOBILIZED, "bounty_chrome"), "It still stands still in the window")
	TEST_ASSERT_NULL(criminal.get_filter(move.tell_filter()), "The tell's glow stayed on")
	// The lattice's speed is on the body, and the AI moves the body at its own pace
	TEST_ASSERT(abs(criminal.cached_multiplicative_slowdown - (slowdown_before - 1)) < 0.01, "The window's pace is [criminal.cached_multiplicative_slowdown], not the lattice's [slowdown_before - 1]")
	TEST_ASSERT(abs(criminal.ai_controller.movement_delay - criminal.cached_multiplicative_slowdown) < 0.01, "Its AI moves it every [criminal.ai_controller.movement_delay], not at its body's pace [criminal.cached_multiplicative_slowdown]")
	TEST_ASSERT(!move.can_start(hunter), "It would surge again with the lattice cycling")
	chrome.next_move_at = 0
	TEST_ASSERT_NULL(chrome.plan(criminal.ai_controller, 1), "It started a second surge in the window")

/// An EMP, a stun or crit during the tell stops it: no surge and no cooldown spent; a stunned or downed criminal starts none
/datum/unit_test/voidcrew_bounty_chrome_cascade/interrupted

/datum/unit_test/voidcrew_bounty_chrome_cascade/interrupted/Run()
	var/mob/living/carbon/human/hunter = make_person(spot(3, 0))
	for(var/way in list("emp", "stunned", "downed"))
		var/mob/living/carbon/human/npc/bounty_criminal/criminal = make_criminal(make_record(2, "normal", "brawler", null, list("cascade")))
		var/datum/component/bounty_chrome/chrome = criminal.GetComponent(/datum/component/bounty_chrome)
		var/datum/bounty_chrome_move/cascade/move = chrome.move_of(/datum/bounty_chrome_move/cascade)
		TEST_ASSERT(criminal.ai_start_fight(hunter), "[way]: the criminal wouldn't fight")
		chrome.update_fight()
		TEST_ASSERT(chrome.start_move(move, hunter), "[way]: the tell didn't start")
		switch(way)
			if("emp")
				criminal.emp_act(EMP_HEAVY)
			if("stunned")
				criminal.Paralyze(3 SECONDS)
			if("downed")
				// Into soft crit, short of hard crit and death
				criminal.setOxyLoss(criminal.health + 20)
		TEST_ASSERT_NULL(chrome.telling, "[way]: the tell kept running")
		sleep(1.1 SECONDS)
		TEST_ASSERT(!surging(criminal), "[way]: the lattice surged anyway")
		var/datum/action/cooldown/cyberware/cascade_surge/surge_button = surge_action(criminal)
		TEST_ASSERT(surge_button.next_use_time <= world.time, "[way]: the lattice's cooldown was spent on a surge that never came")
		chrome.next_move_at = 0
		if(way == "emp")
			TEST_ASSERT(!move.ready(), "The lattice is ready through its EMP reboot")
		else
			TEST_ASSERT(!move.can_start(hunter), "[way]: it would start a surge")
			TEST_ASSERT_NULL(chrome.plan(criminal.ai_controller, 1), "[way]: it planned a surge")
		qdel(criminal)

// ===== IN THE WINDOW =====

/**
 * A gunman in the window strafes across its line to its target, a step at a time, paced by its body:
 * never twice inside the gap or its move delay, never held still, never off its leash, and a companion
 * never off its criminal's. A fighter with no gun ready closes in through its AI instead, and the
 * strafing ends with the window.
 */
/datum/unit_test/voidcrew_bounty_chrome_cascade/strafe

/datum/unit_test/voidcrew_bounty_chrome_cascade/strafe/Run()
	var/mob/living/carbon/human/hunter = make_person(spot(4, 2))
	var/mob/living/carbon/human/npc/bounty_criminal/gunman = make_criminal(make_record(2, "normal", "pistol", null, list("cascade")), spot(0, 2)) // BOUNTY_STYLE_PISTOL
	var/datum/component/bounty_chrome/chrome = gunman.GetComponent(/datum/component/bounty_chrome)
	var/datum/bounty_chrome_move/cascade/move = chrome.move_of(/datum/bounty_chrome_move/cascade)
	TEST_ASSERT(gunman.ai_start_fight(hunter), "The gunman wouldn't fight")
	chrome.update_fight()
	var/datum/bounty_style/style = GLOB.bounty_styles["pistol"]
	var/obj/item/gun/gun = style.carried_ranged(gunman)
	TEST_ASSERT_NOTNULL(gun, "The gunman carries no pistol")
	TEST_ASSERT(human_npc_take_in_hand(gunman, gun), "The gunman couldn't draw its pistol")
	TEST_ASSERT_NOTNULL(style.ready_in_hand(gunman), "The pistol in its hand won't fire")

	TEST_ASSERT(!move.strafe(), "It strafed with no lattice running")
	TEST_ASSERT(move.fire(hunter), "The lattice didn't surge")
	TEST_ASSERT(surging(gunman), "The surge opened no window")
	TEST_ASSERT_NOTNULL(move.strafe_timer, "Nothing strafes in the window")
	move.next_strafe_at = 0
	move.last_step_at = 0
	var/turf/strafed_from = get_turf(gunman)
	TEST_ASSERT(move.strafe(), "A gunman in the window didn't strafe")
	TEST_ASSERT(get_turf(gunman) != strafed_from, "It strafed without moving")
	TEST_ASSERT_EQUAL(gunman.x, strafed_from.x, "Its strafe went toward or away from its target")
	TEST_ASSERT_EQUAL(get_dist(gunman, hunter), get_dist(strafed_from, hunter), "Its strafe changed its distance")
	TEST_ASSERT_NOTNULL(locate(/obj/effect/temp_visual/decoy/fading/cascade) in strafed_from, "Its strafe left no afterimage")
	TEST_ASSERT_EQUAL(move.last_step_at, world.time, "Its step wasn't noted")

	// Paced by its body: never again inside the gap, and never sooner than its move delay
	TEST_ASSERT(!move.strafe(), "It strafed twice at once")
	move.next_strafe_at = 0
	TEST_ASSERT(gunman.cached_multiplicative_slowdown > 0, "The gunman's body moves with no delay at all")
	TEST_ASSERT(!move.strafe(), "It stepped again sooner than its body's move delay")
	move.last_step_at = 0

	// Held still, it doesn't
	ADD_TRAIT(gunman, TRAIT_IMMOBILIZED, TRAIT_GENERIC)
	TEST_ASSERT(!move.strafe(), "Held still, it strafed")
	REMOVE_TRAIT(gunman, TRAIT_IMMOBILIZED, TRAIT_GENERIC)

	// Off its leash it doesn't: its site is the one row it stands on
	var/turf/corner = spot(0, 0)
	gunman.site_bounds = list(corner.x, gunman.y, corner.x + 4, gunman.y, corner.z)
	var/turf/leashed_at = get_turf(gunman)
	TEST_ASSERT(!move.strafe(), "It strafed off its leash")
	TEST_ASSERT_EQUAL(get_turf(gunman), leashed_at, "It moved off its leash")
	gunman.site_bounds = null

	// With no gun ready it closes in through its AI instead
	bounty_ai_apply_style(gunman, "brawler") // BOUNTY_STYLE_BRAWLER
	TEST_ASSERT(!move.strafe(), "A brawler strafed instead of closing in")
	bounty_ai_apply_style(gunman, "pistol")
	TEST_ASSERT(move.strafe(), "Its gun back in play, it didn't strafe")

	// A companion's steps stay on its criminal's leash
	var/list/buddies = gunman.spawn_companions(1, TRUE)
	TEST_ASSERT(length(buddies), "No companion spawned")
	allocated += buddies
	var/mob/living/carbon/human/npc/bounty_companion/buddy = buddies[1]
	buddy.ai_controller?.set_ai_status(AI_STATUS_OFF)
	buddy.forceMove(spot(1, 2))
	TEST_ASSERT("cascade" in bounty_chrome_install_now(buddy, list("cascade")), "The companion's lattice didn't go in")
	var/datum/component/bounty_chrome/buddy_chrome = buddy.GetComponent(/datum/component/bounty_chrome)
	var/datum/bounty_chrome_move/cascade/buddy_move = buddy_chrome?.move_of(/datum/bounty_chrome_move/cascade)
	TEST_ASSERT_NOTNULL(buddy_move, "The companion's lattice has no move")
	buddy.ai_join_fight(hunter)
	buddy.ai_controller.set_blackboard_key(BB_BASIC_MOB_CURRENT_TARGET, hunter)
	bounty_ai_apply_style(buddy, "pistol")
	var/obj/item/gun/buddy_gun = new /obj/item/gun/ballistic/automatic/pistol/aps(get_turf(buddy))
	TEST_ASSERT(buddy.put_in_hands(buddy_gun), "The companion couldn't hold a pistol")
	TEST_ASSERT(buddy_move.fire(hunter), "The companion's lattice didn't surge")
	buddy_move.next_strafe_at = 0
	buddy_move.last_step_at = 0
	gunman.site_bounds = list(corner.x, buddy.y, corner.x + 4, buddy.y, corner.z)
	var/turf/buddy_was = get_turf(buddy)
	TEST_ASSERT(!buddy_move.strafe(), "A companion strafed off its criminal's leash")
	TEST_ASSERT_EQUAL(get_turf(buddy), buddy_was, "A companion moved off its criminal's leash")
	gunman.site_bounds = null
	TEST_ASSERT(buddy_move.strafe(), "A companion on its criminal's ground didn't strafe")

	// The window ends, and the strafing with it
	gunman.remove_status_effect(/datum/status_effect/cyberware_cascade_window)
	move.strafe_pulse()
	TEST_ASSERT_NULL(move.strafe_timer, "It kept strafing after the window")
	TEST_ASSERT(gunman.has_status_effect(/datum/status_effect/cyberware_cascade_crash), "The window ended with no crash")

// ===== MINI-BOSSES =====

/**
 * One lattice, one driver: a Ghost's kit lattice is fired by its dash, so a rolled Cascade never goes
 * in beside it, and a Cascade move handed to a Ghost never drives it. A Juggernaut with a rolled
 * lattice surges through its ability rotation.
 */
/datum/unit_test/voidcrew_bounty_chrome_cascade/bosses

/datum/unit_test/voidcrew_bounty_chrome_cascade/bosses/Run()
	var/mob/living/carbon/human/hunter = make_person(spot(3, 0))
	var/mob/living/carbon/human/npc/bounty_criminal/boss/ghost = make_criminal(make_record(3, "boss", null, "ghost", list("cascade"))) // BOUNTY_TIER_MOST_WANTED, BOUNTY_KIT_GHOST
	TEST_ASSERT(istype(ghost, /mob/living/carbon/human/npc/bounty_criminal/boss/ghost), "No Ghost spawned")
	TEST_ASSERT_NULL(ghost.record.chrome, "A Ghost's record kept a second lattice")
	var/lattices = 0
	for(var/obj/item/organ/cyberimp/cyberware/cascade/lattice in ghost.organs)
		lattices++
	TEST_ASSERT_EQUAL(lattices, 1, "The Ghost carries [lattices] lattices")
	var/datum/component/bounty_chrome/ghost_chrome = ghost.GetComponent(/datum/component/bounty_chrome)
	TEST_ASSERT(!ghost_chrome?.move_of(/datum/bounty_chrome_move/cascade), "The Ghost's kit lattice got a chrome move")
	ghost_chrome = bounty_chrome_equip(ghost, list("cascade"))
	var/datum/bounty_chrome_move/cascade/ghost_move = ghost_chrome?.move_of(/datum/bounty_chrome_move/cascade)
	TEST_ASSERT_NOTNULL(ghost_move, "A Cascade move handed to the Ghost wasn't made")
	TEST_ASSERT(ghost_move.ready(), "The Ghost's lattice isn't ready")
	TEST_ASSERT(!ghost_move.can_start(hunter), "A Cascade move would fire the lattice the Ghost's dash fires")
	TEST_ASSERT(!ghost_move.boss_ability?.worth_using(hunter), "The Ghost's rotation would fire its kit lattice a second way")

	var/mob/living/carbon/human/npc/bounty_criminal/boss/juggernaut = make_criminal(make_record(3, "boss", null, "juggernaut", list("cascade")), spot(1, 1)) // BOUNTY_KIT_JUGGERNAUT
	var/datum/action/cooldown/mob_cooldown/bounty_boss/chrome/ability
	for(var/datum/action/cooldown/mob_cooldown/bounty_boss/chrome/wrapped in juggernaut.boss_abilities)
		if(istype(wrapped.move, /datum/bounty_chrome_move/cascade))
			ability = wrapped
	TEST_ASSERT_NOTNULL(ability, "The Juggernaut's lattice isn't in its ability rotation")
	TEST_ASSERT(ability.windup >= 0.8 SECONDS, "The Juggernaut's surge winds up for [ability.windup / 10] s") // BOUNTY_CHROME_TELL_MIN
	TEST_ASSERT(ability.worth_using(hunter), "The Juggernaut won't surge at a hunter in sight")
	TEST_ASSERT(ability.Trigger(target = hunter), "The Juggernaut's surge wouldn't start")
	TEST_ASSERT(!surging(juggernaut), "The Juggernaut surged before its wind-up")
	sleep(1.2 SECONDS)
	TEST_ASSERT(surging(juggernaut), "The Juggernaut's wind-up ended with no surge")

// ===== RENDERS =====

/**
 * Not a check: with -DBOUNTY_CHROME_RENDERS, writes a Cascade carrier (a brawler and a gunman) and the
 * lattice's afterimage at three hues to data/bounty_chrome_renders/, for a person to look at.
 */
/datum/unit_test/voidcrew_bounty_chrome_cascade/renders

/datum/unit_test/voidcrew_bounty_chrome_cascade/renders/Run()
	var/mob/living/carbon/human/npc/bounty_criminal/brawler = make_criminal(make_record(2, "normal", "brawler", null, list("cascade")), spot(1, 1))
	var/mob/living/carbon/human/npc/bounty_criminal/gunman = make_criminal(make_record(2, "normal", "pistol", null, list("cascade")), spot(3, 1))
	TEST_ASSERT_NOTNULL(locate(/obj/item/organ/cyberimp/cyberware/cascade) in brawler.organs, "The brawler has no lattice")
	TEST_ASSERT_NOTNULL(locate(/obj/item/organ/cyberimp/cyberware/cascade) in gunman.organs, "The gunman has no lattice")
#ifdef BOUNTY_CHROME_RENDERS
	var/datum/bounty_style/style = GLOB.bounty_styles["pistol"]
	var/obj/item/gun/gun = style.carried_ranged(gunman)
	if(gun)
		human_npc_take_in_hand(gunman, gun)
	for(var/facing in list(SOUTH, EAST))
		fcopy(getFlatIcon(brawler, facing), "data/bounty_chrome_renders/cascade_brawler_[dir2text(facing)].png")
		fcopy(getFlatIcon(gunman, facing), "data/bounty_chrome_renders/cascade_gunman_[dir2text(facing)].png")
	// The afterimage a step leaves, tinted as the lattice's trail is (a flat icon drops an atom's colour, so the tint goes on by hand)
	var/obj/effect/temp_visual/decoy/fading/cascade/afterimage = new(spot(2, 3), gunman, 0)
	for(var/hue in list(0, 120, 280))
		var/icon/trail = getFlatIcon(gunman, EAST)
		trail.MapColors(arglist(afterimage.cascade_tint_matrix(hue)))
		fcopy(trail, "data/bounty_chrome_renders/cascade_afterimage_[hue].png")
	qdel(afterimage)
#endif
