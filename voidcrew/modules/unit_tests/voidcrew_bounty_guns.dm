/**
 * Bounty hunting: the guns, for voidcrew/modules/bounties/bounty_styles.dm and the pistols of the kingpin's
 * goons and Club Volga. Every bounty gun is a real one fired through the body's own hands: an SMG burst is
 * four separate trigger pulls of a WT-550, and stops the moment the shooter can't shoot or the target is
 * gone; a holstered gun comes out with a line and holds the first shot; the Stechkin is set to single shots
 * with its own fire selector and fired in strings by criminals, goons, mobsters and the don; a dry revolver
 * is reloaded from a speedloader; a blended fugitive's holster is worn by its decoys too.
 *
 * The tests drive the behaviours and procs directly (a test world has no clients, so the AI is off) and
 * skip the waits between pulls by moving the clock, not by sleeping through them. They sleep a tick
 * between real shots only because a gun's fire delay is a timer. Fork defines are included after the
 * tests, so a test uses the literal value with a comment naming the define.
 */

/**
 * Waits for the guns `fighter` holds to be ready for the next pull: a tick at least, and until each one's
 * fire delay is over (it is a timer, and a busy test world runs timers late). Gives up after 2 seconds.
 */
/proc/bounty_guns_test_wait(mob/living/carbon/fighter)
	sleep(1)
	for(var/wait in 1 to 20)
		var/busy = FALSE
		for(var/obj/item/gun/gun in fighter?.held_items)
			if(gun.fire_cd || gun.firing_burst)
				busy = TRUE
		if(!busy)
			return
		sleep(1)

/// The criminals' guns, in the bounty AI tests' room with their helpers (make_criminal(), carried())
/datum/unit_test/voidcrew_bounty_guns
	parent_type = /datum/unit_test/voidcrew_bounty_ai
	abstract_type = /datum/unit_test/voidcrew_bounty_guns

/// A person at `where` whom `criminal` is out to get: on its grudge list and its target
/datum/unit_test/voidcrew_bounty_guns/proc/make_target(mob/living/carbon/human/npc/bounty_criminal/criminal, turf/where)
	var/mob/living/carbon/human/consistent/hunter = allocate(/mob/living/carbon/human/consistent, where)
	criminal.ai_add_grudge(hunter)
	criminal.ai_controller.set_blackboard_key(BB_BASIC_MOB_CURRENT_TARGET, hunter)
	return hunter

/// One step of `fighter`'s shooting behaviour, with the click delays a test can't wait out cleared
/datum/unit_test/voidcrew_bounty_guns/proc/shoot_step(mob/living/carbon/human/npc/fighter)
	var/datum/bounty_style/style = bounty_ai_style(fighter)
	var/datum/ai_behavior/shoot = GET_AI_BEHAVIOR(style.ranged_behavior)
	fighter.next_move = 0
	fighter.next_click = 0
	return shoot.perform(0.1, fighter.ai_controller, BB_BASIC_MOB_CURRENT_TARGET, BB_TARGETING_STRATEGY)

/// What the controller does when the shooting behaviour stops: its finish_action()
/datum/unit_test/voidcrew_bounty_guns/proc/shoot_stopped(mob/living/carbon/human/npc/fighter)
	var/datum/bounty_style/style = bounty_ai_style(fighter)
	var/datum/ai_behavior/shoot = GET_AI_BEHAVIOR(style.ranged_behavior)
	shoot.finish_action(fighter.ai_controller, FALSE, BB_BASIC_MOB_CURRENT_TARGET, BB_TARGETING_STRATEGY)

/// The next pull is due now: a tick for the gun's fire delay, the target patched up, the wait skipped
/datum/unit_test/voidcrew_bounty_guns/proc/next_pull(mob/living/carbon/human/npc/fighter, mob/living/carbon/human/target)
	bounty_guns_test_wait(fighter)
	target?.fully_heal(HEAL_ALL)
	fighter.ai_controller.set_blackboard_key("bb_bounty_next_shot", world.time) // BB_BOUNTY_NEXT_SHOT

/// `fighter` draws its style's gun through the draw behaviour the arm subtree queues. Returns the gun, in hand.
/datum/unit_test/voidcrew_bounty_guns/proc/draw_gun(mob/living/carbon/human/npc/fighter)
	var/datum/bounty_style/style = bounty_ai_style(fighter)
	var/obj/item/gun/gun = style?.carried_ranged(fighter)
	TEST_ASSERT_NOTNULL(gun, "Test fixture: [fighter] has no gun to draw")
	var/datum/ai_controller/controller = fighter.ai_controller
	controller.set_blackboard_key("human_npc_draw_item", gun) // BB_HUMAN_NPC_DRAW_ITEM
	var/datum/ai_behavior/draw = GET_AI_BEHAVIOR(/datum/ai_behavior/human_npc_draw/bounty)
	TEST_ASSERT(draw.perform(0.1, controller, "human_npc_draw_item") & AI_BEHAVIOR_SUCCEEDED, "[fighter] didn't draw [gun]")
	draw.finish_action(controller, TRUE, "human_npc_draw_item")
	TEST_ASSERT(fighter.is_holding(gun), "[gun] didn't come into [fighter]'s hand")
	return gun

/// Runs `behavior_type` (a reload) on `npc` step by step, the waits between steps skipped. TRUE if it finished.
/datum/unit_test/voidcrew_bounty_guns/proc/run_reload(mob/living/carbon/human/npc/npc, behavior_type, steps = 40)
	var/datum/ai_controller/controller = npc.ai_controller
	var/datum/ai_behavior/reload = GET_AI_BEHAVIOR(behavior_type)
	if(!reload.setup(controller))
		return FALSE
	for(var/step in 1 to steps)
		npc.next_click = 0
		npc.next_move = 0
		var/result = reload.perform(1, controller)
		if(result & AI_BEHAVIOR_FAILED)
			reload.finish_action(controller, FALSE)
			return FALSE
		if(result & AI_BEHAVIOR_SUCCEEDED)
			reload.finish_action(controller, TRUE)
			return TRUE
	return FALSE

/**
 * A burst of `fighter`'s under way at `target`: the spin-up skipped and the first pull made. Returns the
 * rounds left in `gun`.
 */
/datum/unit_test/voidcrew_bounty_guns/proc/start_burst(mob/living/carbon/human/npc/fighter, mob/living/carbon/human/target, obj/item/gun/ballistic/gun)
	var/datum/ai_controller/controller = fighter.ai_controller
	shoot_step(fighter)
	controller.set_blackboard_key("bb_bounty_windup_until", world.time) // BB_BOUNTY_WINDUP_UNTIL
	shoot_step(fighter)
	TEST_ASSERT(controller.blackboard["bb_bounty_burst_left"], "Test fixture: [fighter]'s burst didn't start") // BB_BOUNTY_BURST_LEFT
	next_pull(fighter, target)
	return bounty_gun_live_rounds(gun)

// ===== THE KIT AND THE ROLLS =====

/**
 * The WT-550 at every tier, worn on the belt with a spare magazine in a pocket; the .38 in a shoulder
 * holster with a speedloader; both carried, not held, until a fight. Both are rolled for criminals and
 * companions, and offered in the Bounty Panel.
 */
/datum/unit_test/voidcrew_bounty_guns/kit

/datum/unit_test/voidcrew_bounty_guns/kit/Run()
	for(var/tier in list(1, 2)) // BOUNTY_TIER_PETTY, BOUNTY_TIER_WANTED
		var/mob/living/carbon/human/npc/bounty_criminal/normal/gunner = make_criminal(/mob/living/carbon/human/npc/bounty_criminal/normal, tile(tier, 0), "smg", tier) // BOUNTY_STYLE_SMG
		var/obj/item/gun/ballistic/automatic/wt550/smg = gunner.belt
		TEST_ASSERT(istype(smg), "A tier [tier] SMG criminal has no WT-550 on the belt")
		TEST_ASSERT(!gunner.is_holding(smg), "The WT-550 is in hand before the fight")
		TEST_ASSERT(istype(gunner.r_store, /obj/item/ammo_box/magazine/wt550m9) || istype(gunner.l_store, /obj/item/ammo_box/magazine/wt550m9), "The SMG criminal has no spare magazine in a pocket")
		TEST_ASSERT_NOTNULL(carried(gunner, /obj/item/stack/medical/bruise_pack), "The SMG criminal carries nothing to treat themselves with")
		TEST_ASSERT_EQUAL(smg.burst_size, 1, "The WT-550 fires more than a round a pull")
		TEST_ASSERT_EQUAL(bounty_ai_style(gunner)?.carried_ranged(gunner), smg, "The SMG style would not draw the WT-550 off the belt")

	var/mob/living/carbon/human/npc/bounty_criminal/normal/shooter = make_criminal(/mob/living/carbon/human/npc/bounty_criminal/normal, tile(3, 0), "revolver") // BOUNTY_STYLE_REVOLVER
	var/obj/item/gun/ballistic/revolver/c38/revolver = carried(shooter, /obj/item/gun/ballistic/revolver/c38)
	TEST_ASSERT_NOTNULL(revolver, "The revolver criminal carries no .38")
	TEST_ASSERT(istype(revolver.loc, /obj/item/storage/belt/holster), "The .38 isn't in a holster")
	TEST_ASSERT(istype(shooter.r_store, /obj/item/ammo_box/c38) || istype(shooter.l_store, /obj/item/ammo_box/c38), "The revolver criminal has no speedloader in a pocket")
	TEST_ASSERT_NOTNULL(carried(shooter, /obj/item/stack/medical/bruise_pack), "The revolver criminal carries nothing to treat themselves with")
	TEST_ASSERT_EQUAL(bounty_gun_live_rounds(revolver), 6, "The .38 isn't loaded with six")

	// Rolled for criminals and companions, offered to admins
	var/list/rolled = list()
	for(var/i in 1 to 400)
		rolled[bounty_roll_style()] = TRUE
	TEST_ASSERT(rolled["smg"] && rolled["revolver"], "A criminal never rolls the SMG or the revolver") // BOUNTY_STYLE_SMG, BOUNTY_STYLE_REVOLVER
	var/mob/living/carbon/human/npc/bounty_companion/buddy = allocate(/mob/living/carbon/human/npc/bounty_companion, tile(4, 0))
	var/list/companion_styles = list()
	for(var/i in 1 to 300)
		buddy.ai_style = null
		qdel(buddy.bounty_build_outfit(1)) // ZONE_GREEN
		companion_styles[buddy.ai_style] = TRUE
	TEST_ASSERT(companion_styles["smg"] && companion_styles["revolver"], "A companion never rolls the SMG or the revolver")
	var/datum/bounty_admin_panel/panel = allocate(/datum/bounty_admin_panel)
	var/list/choices = panel.style_choices()
	TEST_ASSERT_EQUAL(choices["SMG"], "smg", "The Bounty Panel doesn't offer the SMG")
	TEST_ASSERT_EQUAL(choices["Revolver"], "revolver", "The Bounty Panel doesn't offer the revolver")

	// Which styles fight with a gun
	for(var/key in list("pistol", "shotgun", "smg", "revolver", "holdout"))
		TEST_ASSERT(bounty_style_is_gun(key), "The [key] style doesn't count as a gun")
	for(var/key in list("brawler", "knife", "club", "bottle", "nonsense"))
		TEST_ASSERT(!bounty_style_is_gun(key), "The [key] style counts as a gun")

// ===== THE SMG'S BURST =====

/**
 * A burst is four trigger pulls of the real WT-550 at its own full-auto rate, after the gun is brought up
 * level, and each pull is asked for again: it stops the moment the shooter is stamina-crit, cuffed,
 * knocked down or dead, or the target goes down, and what is left of a burst the AI was stopped in the
 * middle of never fires.
 */
/datum/unit_test/voidcrew_bounty_guns/smg_burst

/datum/unit_test/voidcrew_bounty_guns/smg_burst/Run()
	var/mob/living/carbon/human/npc/bounty_criminal/normal/gunner = make_criminal(/mob/living/carbon/human/npc/bounty_criminal/normal, tile(0, 2), "smg") // BOUNTY_STYLE_SMG
	var/mob/living/carbon/human/target = make_target(gunner, tile(4, 2))
	var/obj/item/gun/ballistic/automatic/wt550/gun = gunner.belt
	TEST_ASSERT(human_npc_take_in_hand(gunner, gun), "The WT-550 can't be drawn off the belt")
	var/datum/ai_controller/controller = gunner.ai_controller
	var/rounds = bounty_gun_live_rounds(gun)

	// Brought up level first: no round yet
	shoot_step(gunner)
	TEST_ASSERT(controller.blackboard["bb_bounty_windup_until"] > world.time, "The SMG didn't come up level before the burst") // BB_BOUNTY_WINDUP_UNTIL
	TEST_ASSERT_EQUAL(bounty_gun_live_rounds(gun), rounds, "A round went before the SMG was up")
	controller.set_blackboard_key("bb_bounty_windup_until", world.time) // BB_BOUNTY_WINDUP_UNTIL

	// Four pulls, a single round each, the gun's own rate apart
	for(var/pull in 1 to 4)
		shoot_step(gunner)
		TEST_ASSERT_EQUAL(bounty_gun_live_rounds(gun), rounds - pull, "After pull [pull] of the burst [rounds - bounty_gun_live_rounds(gun)] rounds had gone")
		if(pull == 4)
			break
		TEST_ASSERT_EQUAL(controller.blackboard["bb_bounty_burst_left"], 4 - pull, "The burst lost count after pull [pull]") // BB_BOUNTY_BURST_LEFT, BOUNTY_SMG_BURST
		TEST_ASSERT_EQUAL(controller.blackboard["bb_bounty_next_shot"], world.time + 3, "The burst's next pull isn't 0.3 seconds on") // BB_BOUNTY_NEXT_SHOT, BOUNTY_SMG_BURST_GAP
		next_pull(gunner, target)
	TEST_ASSERT_NULL(controller.blackboard["bb_bounty_burst_left"], "The burst didn't end after four pulls") // BB_BOUNTY_BURST_LEFT
	TEST_ASSERT_EQUAL(controller.blackboard["bb_bounty_next_shot"], world.time + 5, "After a burst, the next one isn't half a second off") // BOUNTY_SMG_INTERVAL
	// The next burst is brought up level again
	next_pull(gunner, target)
	shoot_step(gunner)
	TEST_ASSERT_EQUAL(bounty_gun_live_rounds(gun), rounds - 4, "A fifth round went without the SMG brought up again")
	TEST_ASSERT(controller.blackboard["bb_bounty_windup_until"] > world.time, "The next burst didn't start with the SMG brought up")
	shoot_stopped(gunner)

	// Cut off by anything that stops the shooter, or the target going down
	var/list/stoppers = list("stamina crit", "cuffs", "knockdown", "death", "target down", "AI stopped")
	for(var/i in 1 to length(stoppers))
		var/stopper = stoppers[i]
		var/mob/living/carbon/human/npc/bounty_criminal/normal/shooter = make_criminal(/mob/living/carbon/human/npc/bounty_criminal/normal, tile(0, i % 5), "smg") // BOUNTY_STYLE_SMG
		var/mob/living/carbon/human/mark = make_target(shooter, tile(4, i % 5))
		var/obj/item/gun/ballistic/automatic/wt550/smg = shooter.belt
		TEST_ASSERT(human_npc_take_in_hand(shooter, smg), "Test fixture: the WT-550 can't be drawn")
		var/left = start_burst(shooter, mark, smg)
		switch(stopper)
			if("stamina crit")
				shooter.adjustStaminaLoss(200)
				TEST_ASSERT(shooter.has_status_effect(/datum/status_effect/incapacitating/stamcrit), "Test fixture: no stamina crit")
			if("cuffs")
				var/obj/item/restraints/handcuffs/cuffs = allocate(/obj/item/restraints/handcuffs, get_turf(shooter))
				TEST_ASSERT(shooter.equip_to_slot_if_possible(cuffs, ITEM_SLOT_HANDCUFFED) && HAS_TRAIT(shooter, TRAIT_RESTRAINED), "Test fixture: the cuffs didn't go on")
			if("knockdown")
				shooter.Knockdown(3 SECONDS)
				TEST_ASSERT(HAS_TRAIT(shooter, TRAIT_FLOORED), "Test fixture: not knocked down")
			if("death")
				shooter.death()
			if("target down")
				bounty_test_hurt_to(mark, -10)
				TEST_ASSERT(mark.stat >= SOFT_CRIT, "Test fixture: the target didn't go down")
			if("AI stopped")
				// The next pull came due long ago: the AI was off in between (asleep, say), and the burst was cut off
				shooter.ai_controller.set_blackboard_key("bb_bounty_next_shot", world.time - 6) // BB_BOUNTY_NEXT_SHOT, past BOUNTY_BURST_STALE
		for(var/try_pull in 1 to 3)
			shoot_step(shooter)
		TEST_ASSERT_EQUAL(bounty_gun_live_rounds(smg), left, "The burst went on after [stopper]")
		if(stopper == "AI stopped")
			TEST_ASSERT(shooter.ai_controller.blackboard["bb_bounty_windup_until"], "A burst cut off by the AI stopping didn't start over with the SMG brought up")
		shoot_stopped(shooter)
		TEST_ASSERT_NULL(shooter.ai_controller.blackboard["bb_bounty_burst_left"], "After [stopper], the rest of the burst is still to come") // BB_BOUNTY_BURST_LEFT

// ===== THE DRAW =====

/**
 * Every gun style that keeps its gun put away comes out with a line. The draw is the first shot's
 * telegraph: at least 0.6 seconds, even if the telegraph itself is dropped, and the pistol isn't raised
 * a second time on top of it. The Stechkin comes out switched to single shots by its own selector. A hit
 * during the draw fumbles the first shot.
 */
/datum/unit_test/voidcrew_bounty_guns/draw

/datum/unit_test/voidcrew_bounty_guns/draw/Run()
	for(var/key in list("pistol", "shotgun", "smg", "revolver")) // BOUNTY_STYLE_*
		var/datum/bounty_style/style = GLOB.bounty_styles[key]
		TEST_ASSERT(length(style?.draw_message), "The [key] style draws its gun without a word")

	var/mob/living/carbon/human/npc/bounty_criminal/normal/gunner = make_criminal(/mob/living/carbon/human/npc/bounty_criminal/normal, tile(0, 2), "pistol") // BOUNTY_STYLE_PISTOL
	var/mob/living/carbon/human/target = make_target(gunner, tile(4, 2))
	var/obj/item/gun/ballistic/automatic/pistol/aps/stechkin = carried(gunner, /obj/item/gun/ballistic/automatic/pistol/aps)
	TEST_ASSERT_EQUAL(stechkin?.burst_size, 3, "Test fixture: the Stechkin isn't on its three-round burst before the draw")
	var/datum/ai_controller/controller = gunner.ai_controller
	var/drawn_at = world.time
	TEST_ASSERT_EQUAL(draw_gun(gunner), stechkin, "The pistol criminal drew something else")
	TEST_ASSERT_EQUAL(controller.blackboard["bb_bounty_drawn_at"], drawn_at, "The draw wasn't the pistol's") // BB_BOUNTY_DRAWN_AT

	// Its own selector, set to single shots
	TEST_ASSERT_EQUAL(stechkin.burst_size, 1, "The drawn Stechkin still fires bursts")
	TEST_ASSERT(!stechkin.burst_fire_selection, "The Stechkin's selector isn't on single shots")

	// The first shot waits out the draw
	TEST_ASSERT(controller.blackboard["bb_bounty_windup_until"] >= drawn_at + 6, "The first shot can come less than 0.6 seconds after the draw") // BB_BOUNTY_WINDUP_UNTIL, BOUNTY_DRAW_TIME
	TEST_ASSERT(controller.blackboard["bb_bounty_next_shot"] >= drawn_at + 6, "Nothing holds the first shot once the draw's telegraph is gone") // BB_BOUNTY_NEXT_SHOT, BOUNTY_DRAW_TIME
	var/rounds = bounty_gun_live_rounds(stechkin)
	shoot_step(gunner)
	TEST_ASSERT_EQUAL(bounty_gun_live_rounds(stechkin), rounds, "A shot went during the draw")
	// Its telegraph dropped (the shooting cut short and planned again): the clock still holds the shot
	bounty_ai_clear_windup(controller)
	shoot_step(gunner)
	TEST_ASSERT_EQUAL(bounty_gun_live_rounds(stechkin), rounds, "A shot went during the draw once its telegraph was dropped")
	// The draw done: one round at once, the pistol not raised again
	controller.set_blackboard_key("bb_bounty_next_shot", world.time) // BB_BOUNTY_NEXT_SHOT
	shoot_step(gunner)
	TEST_ASSERT_EQUAL(bounty_gun_live_rounds(stechkin), rounds - 1, "The first shot after the draw wasn't a single round, or didn't go")
	TEST_ASSERT_NULL(controller.blackboard["bb_bounty_windup_until"], "The pistol was raised again after the draw")
	shoot_stopped(gunner)

	// A hit during the draw fumbles the first shot
	var/mob/living/carbon/human/npc/bounty_criminal/normal/slinger = make_criminal(/mob/living/carbon/human/npc/bounty_criminal/normal, tile(0, 4), "revolver") // BOUNTY_STYLE_REVOLVER
	make_target(slinger, tile(4, 4))
	var/obj/item/gun/ballistic/revolver/c38/revolver = draw_gun(slinger)
	var/datum/ai_controller/slinger_ai = slinger.ai_controller
	var/cylinder = bounty_gun_live_rounds(revolver)
	slinger_ai.set_blackboard_key("bb_bounty_hit_at", world.time) // BB_BOUNTY_HIT_AT
	slinger_ai.set_blackboard_key("bb_bounty_windup_until", world.time) // BB_BOUNTY_WINDUP_UNTIL
	shoot_step(slinger)
	TEST_ASSERT_EQUAL(bounty_gun_live_rounds(revolver), cylinder, "A hit during the draw didn't spoil the first shot")
	TEST_ASSERT(slinger_ai.blackboard["bb_bounty_next_shot"] >= world.time + 10, "A fumbled draw didn't hold the next shot back") // BOUNTY_FUMBLE_PAUSE
	shoot_stopped(slinger)
	target.fully_heal(HEAL_ALL)

// ===== PISTOL STRINGS =====

/**
 * The criminal's pistol: single shots half a second apart, six to a string, then a second and a half on
 * top before the next string, which needs no new raise. An empty magazine is reloaded the player's way
 * and the strings start over with the fresh one.
 */
/datum/unit_test/voidcrew_bounty_guns/pistol_strings

/datum/unit_test/voidcrew_bounty_guns/pistol_strings/Run()
	var/mob/living/carbon/human/npc/bounty_criminal/normal/gunner = make_criminal(/mob/living/carbon/human/npc/bounty_criminal/normal, tile(0, 2), "pistol") // BOUNTY_STYLE_PISTOL
	var/mob/living/carbon/human/target = make_target(gunner, tile(4, 2))
	var/obj/item/gun/ballistic/automatic/pistol/aps/stechkin = draw_gun(gunner)
	var/datum/ai_controller/controller = gunner.ai_controller
	controller.set_blackboard_key("bb_bounty_windup_until", world.time) // BB_BOUNTY_WINDUP_UNTIL
	controller.set_blackboard_key("bb_bounty_next_shot", world.time) // BB_BOUNTY_NEXT_SHOT
	// Fifteen in the magazine and one in the chamber
	var/full = bounty_gun_live_rounds(stechkin)
	TEST_ASSERT(full >= 13, "Test fixture: the Stechkin holds only [full]")

	// The whole magazine: a pause after every 6th shot, none after the last (that is the reload)
	for(var/shot in 1 to full)
		shoot_step(gunner)
		TEST_ASSERT_EQUAL(bounty_gun_live_rounds(stechkin), full - shot, "Shot [shot] wasn't a single round")
		var/wait = controller.blackboard["bb_bounty_next_shot"] - world.time // BB_BOUNTY_NEXT_SHOT
		if(!(shot % 6) && shot < full) // BOUNTY_PISTOL_STRING_SHOTS
			TEST_ASSERT_EQUAL(wait, 20, "After the [shot]th shot, the next string isn't 2 seconds off") // BOUNTY_PISTOL_INTERVAL + BOUNTY_PISTOL_STRING_PAUSE
		else
			TEST_ASSERT_EQUAL(wait, 5, "Shot [shot + 1] isn't half a second after shot [shot]") // BOUNTY_PISTOL_INTERVAL
		if(shot == 7)
			TEST_ASSERT_NULL(controller.blackboard["bb_bounty_windup_until"], "The pistol was raised again for its second string")
		next_pull(gunner, target)
		if(shot == 6)
			// The pause is waited out, not skipped: the last shot and the draw two seconds back
			controller.set_blackboard_key("bb_bounty_last_shot", world.time - 20) // BB_BOUNTY_LAST_SHOT
			controller.set_blackboard_key("bb_bounty_drawn_at", world.time - 30) // BB_BOUNTY_DRAWN_AT
	TEST_ASSERT(!stechkin.can_shoot(), "Test fixture: the Stechkin still fires after [full]")
	var/datum/bounty_style/style = bounty_ai_style(gunner)
	TEST_ASSERT_NULL(style.ready_in_hand(gunner), "A dry Stechkin counts as ready")

	// The player's reload from the spare in a pocket; the strings start over with it
	TEST_ASSERT(human_npc_can_reload(gunner, stechkin), "The dry Stechkin can't be reloaded from the spare magazine")
	TEST_ASSERT(run_reload(gunner, /datum/ai_behavior/human_npc_reload), "The dry Stechkin wasn't reloaded")
	TEST_ASSERT(stechkin.can_shoot(), "The reloaded Stechkin doesn't fire")
	TEST_ASSERT_EQUAL(stechkin.burst_size, 1, "The reload put the Stechkin back on bursts")
	var/fresh = bounty_gun_live_rounds(stechkin)
	controller.set_blackboard_key("bb_bounty_next_shot", world.time) // BB_BOUNTY_NEXT_SHOT
	controller.set_blackboard_key("bb_bounty_windup_until", world.time) // BB_BOUNTY_WINDUP_UNTIL
	for(var/shot in 1 to 6)
		shoot_step(gunner)
		TEST_ASSERT_EQUAL(bounty_gun_live_rounds(stechkin), fresh - shot, "Shot [shot] of the new magazine wasn't a single round")
		var/wait = controller.blackboard["bb_bounty_next_shot"] - world.time // BB_BOUNTY_NEXT_SHOT
		TEST_ASSERT_EQUAL(wait, shot == 6 ? 20 : 5, "The new magazine's first string isn't six shots and a pause")
		next_pull(gunner, target)
	shoot_stopped(gunner)

// ===== THE REVOLVER'S RELOAD =====

/**
 * Six shots leave six spent casings in the .38's cylinder. The reload the arm subtree picks for it clicks
 * the speedloader from the pocket into the cylinder, the player's way: the spent casings fall out, six
 * live rounds go in, and the empty speedloader is let go of.
 */
/datum/unit_test/voidcrew_bounty_guns/revolver_reload

/datum/unit_test/voidcrew_bounty_guns/revolver_reload/Run()
	var/mob/living/carbon/human/npc/bounty_criminal/normal/slinger = make_criminal(/mob/living/carbon/human/npc/bounty_criminal/normal, tile(0, 2), "revolver") // BOUNTY_STYLE_REVOLVER
	var/mob/living/carbon/human/target = make_target(slinger, tile(4, 2))
	var/obj/item/gun/ballistic/revolver/c38/revolver = carried(slinger, /obj/item/gun/ballistic/revolver/c38)
	TEST_ASSERT(human_npc_take_in_hand(slinger, revolver), "The .38 can't be drawn")
	var/datum/bounty_style/style = bounty_ai_style(slinger)
	var/datum/ai_controller/controller = slinger.ai_controller
	for(var/shot in 1 to 6)
		slinger.next_move = 0
		slinger.next_click = 0
		TEST_ASSERT(style.attack(slinger, controller, target, revolver), "Shot [shot] of the cylinder didn't go")
		bounty_guns_test_wait(slinger)
		target.fully_heal(HEAL_ALL)
	TEST_ASSERT(!revolver.can_shoot(), "Test fixture: the .38 still fires after six")
	TEST_ASSERT_EQUAL(length(revolver.magazine.ammo_list()), 6, "The spent casings didn't stay in the cylinder")
	TEST_ASSERT_NULL(style.ready_in_hand(slinger), "A dry revolver counts as ready")
	TEST_ASSERT(human_npc_can_reload(slinger, revolver), "A dry revolver with a speedloader in a pocket can't be reloaded")
	TEST_ASSERT(revolver.internal_magazine, "Test fixture: the arm subtree wouldn't pick the cylinder reload for the .38")

	TEST_ASSERT(run_reload(slinger, /datum/ai_behavior/human_npc_reload/bounty_tube), "The dry revolver wasn't reloaded")
	TEST_ASSERT(revolver.can_shoot(), "The reloaded revolver doesn't fire")
	TEST_ASSERT_EQUAL(bounty_gun_live_rounds(revolver), 6, "The cylinder isn't six live rounds")
	var/spent = 0
	for(var/obj/item/ammo_casing/casing in get_turf(slinger))
		if(!casing.loaded_projectile)
			spent++
	TEST_ASSERT_EQUAL(spent, 6, "[spent] spent casings fell out of the cylinder, not six")
	for(var/obj/item/ammo_box/c38/loader in slinger.held_items)
		TEST_FAIL("The empty speedloader is still in [slinger]'s hand")
	TEST_ASSERT(style.ready_in_hand(slinger) == revolver, "The reloaded revolver isn't ready to fire")

// ===== THE KINGPIN'S GOONS =====

/// A goon's Stechkin: switched to single shots with its own selector, half a second apart, six to a string, then the pause
/datum/unit_test/voidcrew_bounty_guns_goon
	parent_type = /datum/unit_test/voidcrew_bounty_kingpin

/datum/unit_test/voidcrew_bounty_guns_goon/Run()
	var/datum/criminal_bounty/kingpin/posting = kingpin_test_posting()
	var/mob/living/carbon/human/npc/bounty_criminal/kingpin/kingpin = kingpin_test_lounge(posting, 1)
	var/datum/bounty_kingpin_crew/crew = kingpin.kingpin_crew
	// Its clock is moved by hand here: no fight ticks of its own while the shots are counted
	STOP_PROCESSING(SSfastprocess, crew)
	var/list/goons = crew.goons()
	var/mob/living/carbon/human/npc/bounty_kingpin_goon/goon = goons[1]
	TEST_ASSERT_EQUAL(goon?.goon_weapon, "pistol", "Test fixture: the lounge's first goon isn't the pistol goon") // BOUNTY_GOON_WEAPON_PISTOL
	var/mob/living/carbon/human/hunter = kingpin_test_person(kingpin_test_spot(2, 2), null)
	TEST_ASSERT(crew.start_shootout(hunter, TRUE), "The shootout didn't start")
	var/obj/item/gun/ballistic/automatic/pistol/aps/stechkin = human_npc_held_gun(goon)
	TEST_ASSERT(istype(stechkin), "The pistol goon didn't draw a Stechkin")
	crew.crew_draw_ends_at = world.time
	crew.process(0.2)
	TEST_ASSERT_EQUAL(crew.crew_state, "fighting", "The fight didn't start after the draw") // BOUNTY_KINGPIN_FIGHTING
	// The kingpin's own aims are another test's: keep him out of this one
	kingpin.kingpin_next_aim_at = world.time + 1 HOURS
	kingpin.kingpin_cancel_aim()

	var/full = bounty_gun_live_rounds(stechkin)
	for(var/shot in 1 to 7)
		goon.goon_next_fire_at = 0
		goon.goon_fumbled_until = 0
		goon.next_move = 0
		goon.next_click = 0
		TEST_ASSERT(crew.goon_try_attack(goon, hunter), "The goon didn't take shot [shot]")
		TEST_ASSERT_EQUAL(stechkin.burst_size, 1, "The goon's Stechkin fires bursts")
		TEST_ASSERT_EQUAL(bounty_gun_live_rounds(stechkin), full - shot, "The goon's shot [shot] wasn't a single round")
		var/wait = goon.goon_next_fire_at - world.time
		TEST_ASSERT_EQUAL(wait, shot == 6 ? 20 : 5, "After the goon's shot [shot], the next is [wait / 10] seconds off") // BOUNTY_GOON_PISTOL_COOLDOWN, + BOUNTY_PISTOL_STRING_PAUSE
		bounty_guns_test_wait(goon)
		hunter.fully_heal(HEAL_ALL)

// ===== CLUB VOLGA =====

/**
 * A mobster gunman's volley is a string: his Stechkin switched to single shots with its own selector, six
 * pulls half a second apart, then two seconds to the next. The don fires his gold Desert Eagle the same
 * way, after he raises it once a magazine.
 */
/datum/unit_test/voidcrew_bounty_guns_club
	parent_type = /datum/unit_test/voidcrew_bounty_lair_mafia

/datum/unit_test/voidcrew_bounty_guns_club/Run()
	var/datum/ai_behavior/bounty_mafia_fire/fire = GET_AI_BEHAVIOR(/datum/ai_behavior/bounty_mafia_fire)
	var/row = 0
	for(var/member_type in list(/mob/living/carbon/human/npc/bounty_mafia/pistol, /mob/living/carbon/human/npc/bounty_mafia/don))
		var/mob/living/carbon/human/consistent/hunter = hunter_at(spot(4, row))
		var/mob/living/carbon/human/npc/bounty_mafia/shooter = member_at(member_type, spot(0, row))
		row += 4
		var/datum/ai_controller/controller = shooter.ai_controller
		var/obj/item/gun/ballistic/gun = human_npc_loaded_gun(shooter)
		TEST_ASSERT(istype(gun), "Test fixture: [shooter] holds no loaded gun")
		gun.can_misfire = FALSE
		controller.set_blackboard_key(BB_BASIC_MOB_CURRENT_TARGET, hunter)
		TEST_ASSERT(fire.setup(controller, BB_BASIC_MOB_CURRENT_TARGET), "[shooter]'s volley didn't start")
		if(shooter.mafia_aim_until)
			// The don raises his pistol once a magazine first
			TEST_ASSERT(istype(shooter, /mob/living/carbon/human/npc/bounty_mafia/don), "[shooter] aims before a pistol string")
			shooter.mafia_aim_until = world.time
		var/full = bounty_gun_live_rounds(gun)
		for(var/shot in 1 to 6)
			shooter.mafia_next_pull_at = 0
			shooter.next_move = 0
			shooter.next_click = 0
			var/flags = fire.perform(0.1, controller, BB_BASIC_MOB_CURRENT_TARGET)
			TEST_ASSERT_EQUAL(gun.burst_size, 1, "[shooter]'s pistol fires bursts")
			TEST_ASSERT_EQUAL(bounty_gun_live_rounds(gun), full - shot, "[shooter]'s shot [shot] wasn't a single round")
			if(shot < 6)
				TEST_ASSERT(!(flags & AI_BEHAVIOR_SUCCEEDED), "[shooter]'s string ended after [shot] shots")
				TEST_ASSERT_EQUAL(shooter.mafia_next_pull_at - world.time, 5, "[shooter]'s shots aren't half a second apart") // BOUNTY_PISTOL_INTERVAL
				bounty_guns_test_wait(shooter)
				hunter.fully_heal(HEAL_ALL)
				continue
			TEST_ASSERT(flags & AI_BEHAVIOR_SUCCEEDED, "[shooter]'s string didn't end after six shots") // BOUNTY_PISTOL_STRING_SHOTS
			fire.finish_action(controller, TRUE, BB_BASIC_MOB_CURRENT_TARGET)
			TEST_ASSERT_EQUAL(shooter.mafia_next_volley_at - world.time, 20, "[shooter]'s next string isn't 2 seconds off") // BOUNTY_PISTOL_INTERVAL + BOUNTY_PISTOL_STRING_PAUSE
			TEST_ASSERT(!fire.setup(controller, BB_BASIC_MOB_CURRENT_TARGET), "[shooter] started a string before his pause was over")
		sleep(2)
		clear_room()

// ===== BLENDING IN =====

/**
 * A fugitive blending in at a trader outpost keeps its holster or fanny pack on under the patron's coat;
 * its decoys wear an empty one of the same kind, so what a pistol, revolver or meek fugitive carries in
 * plain sight examines like its decoys. The decoys still carry no gun. (The rest of the look-alike
 * examine is voidcrew_bounty_outpost/look_alikes.)
 */
/datum/unit_test/voidcrew_bounty_guns_blend
	parent_type = /datum/unit_test/voidcrew_bounty_outpost

/// The lines of `patron`'s examine that tell what it carries where people can see: its belt, its back and its hands
/datum/unit_test/voidcrew_bounty_guns_blend/proc/carry_lines(mob/living/carbon/human/patron, mob/viewer)
	var/list/lines = list()
	for(var/line in patron.examine(viewer))
		var/plain = trim(STRIP_HTML_FULL("[line]", MAX_MESSAGE_LEN))
		if(findtext(plain, "waist") || findtext(plain, " back.") || findtext(plain, "holding"))
			lines += plain
	return lines.Join(" | ")

/datum/unit_test/voidcrew_bounty_guns_blend/Run()
	outpost = make_outpost(/obj/structure/overmap/trader_outpost/outfitter)
	outpost.lobby_alcove_turfs = list(run_loc_floor_top_right)
	var/mob/living/carbon/human/viewer = make_hunter()
	var/list/cases = list(
		list("normal", "pistol", /mob/living/carbon/human/npc/bounty_criminal/normal), // BOUNTY_ARCHETYPE_NORMAL, BOUNTY_STYLE_PISTOL
		list("normal", "revolver", /mob/living/carbon/human/npc/bounty_criminal/normal), // BOUNTY_STYLE_REVOLVER
		list("meek", "holdout", /mob/living/carbon/human/npc/bounty_criminal/meek), // BOUNTY_ARCHETYPE_MEEK, BOUNTY_STYLE_HOLDOUT
	)
	for(var/list/spec as anything in cases)
		var/datum/bounty_record/record = generate_bounty_record(1, spec[1], "trader_outpost", /datum/species/human) // BOUNTY_TIER_PETTY, BOUNTY_PLACEMENT_TRADER_OUTPOST
		record.style = spec[2]
		// Dressed as production dresses it: the bounty outfit table, its style's gun and its holster
		var/datum/human_npc_order/order = spawn_human_npc(spec[3], run_loc_floor_bottom_left, look = record, name = record.name, immediate = TRUE)
		var/mob/living/carbon/human/npc/bounty_criminal/fugitive = order?.spawned_ref?.resolve()
		qdel(order)
		TEST_ASSERT_NOTNULL(fugitive, "Test fixture: no [spec[2]] fugitive was made")
		allocated += fugitive
		fugitive.record = record
		TEST_ASSERT(istype(fugitive.belt, /obj/item/storage), "Test fixture: the [spec[2]] fugitive wears no holster or pouch")
		var/datum/criminal_bounty/outpost_test/posting = allocate(/datum/criminal_bounty/outpost_test)
		posting.record = record
		posting.placement_kind = "trader_outpost" // BOUNTY_PLACEMENT_TRADER_OUTPOST
		posting.site_ref = WEAKREF(outpost)
		posting.value = 1234
		fugitive.posting_ref = WEAKREF(posting)
		posting.criminal_ref = WEAKREF(fugitive)
		GLOB.criminal_bounties += posting
		TEST_ASSERT(posting.setup_outpost_blend(TRUE), "The [spec[2]] fugitive's posting could not be set up to blend in")
		var/list/decoys = decoys_of(posting)
		TEST_ASSERT(length(decoys), "The [spec[2]] fugitive has no decoys")
		var/fugitive_carry = carry_lines(fugitive, viewer)
		TEST_ASSERT(findtext(fugitive_carry, "waist"), "Test fixture: the [spec[2]] fugitive's belt doesn't show")
		for(var/mob/living/carbon/human/npc/bounty_criminal/decoy/decoy as anything in decoys)
			TEST_ASSERT_EQUAL(decoy.belt?.type, fugitive.belt?.type, "A decoy of the [spec[2]] fugitive wears no [fugitive.belt]")
			TEST_ASSERT(human_npc_gear_locked(decoy.belt), "A decoy's [decoy.belt] isn't locked to it")
			TEST_ASSERT(!length(decoy.belt.contents), "A decoy's [decoy.belt] has something in it")
			TEST_ASSERT_NULL(locate(/obj/item/gun) in decoy.get_all_contents(), "A decoy carries a gun")
			TEST_ASSERT_EQUAL(carry_lines(decoy, viewer), fugitive_carry, "A decoy carries something else in plain sight than the [spec[2]] fugitive")
#ifdef BOUNTY_GUN_RENDERS
		var/mob/living/carbon/human/npc/bounty_criminal/decoy/first_decoy = decoys[1]
		for(var/facing in list(SOUTH, EAST))
			fugitive.setDir(facing)
			first_decoy.setDir(facing)
			fcopy(getFlatIcon(fugitive, facing, no_anim = TRUE), "data/bounty_gun_renders/blend_[spec[2]]_fugitive_[dir2text(facing)].png")
			fcopy(getFlatIcon(first_decoy, facing, no_anim = TRUE), "data/bounty_gun_renders/blend_[spec[2]]_decoy_[dir2text(facing)].png")
#endif
		for(var/datum/weakref/decoy_ref as anything in posting.decoys)
			qdel(decoy_ref?.resolve())
		posting.decoys = list()
		GLOB.criminal_bounties -= posting
		qdel(fugitive)

#ifdef BOUNTY_GUN_RENDERS
/**
 * Not a check: renders the gun styles on real criminals, holstered and drawn, facing south and east, to
 * data/bounty_gun_renders/. Compile with -DBOUNTY_GUN_RENDERS to run it.
 */
/datum/unit_test/voidcrew_bounty_guns/renders

/datum/unit_test/voidcrew_bounty_guns/renders/Run()
	var/list/specs = list(
		list("pistol", /obj/item/gun/ballistic/automatic/pistol/aps),
		list("smg", /obj/item/gun/ballistic/automatic/wt550),
		list("revolver", /obj/item/gun/ballistic/revolver/c38),
	)
	var/column = 0
	for(var/list/spec as anything in specs)
		var/mob/living/carbon/human/npc/bounty_criminal/normal/gunner = make_criminal(/mob/living/carbon/human/npc/bounty_criminal/normal, tile(column, 2), spec[1])
		column++
		var/obj/item/gun/gun = carried(gunner, spec[2])
		for(var/facing in list(SOUTH, EAST))
			gunner.setDir(facing)
			fcopy(getFlatIcon(gunner, facing, no_anim = TRUE), "data/bounty_gun_renders/[spec[1]]_holstered_[dir2text(facing)].png")
		TEST_ASSERT(human_npc_take_in_hand(gunner, gun), "[spec[1]]: the gun can't be drawn")
		for(var/facing in list(SOUTH, EAST))
			gunner.setDir(facing)
			fcopy(getFlatIcon(gunner, facing, no_anim = TRUE), "data/bounty_gun_renders/[spec[1]]_drawn_[dir2text(facing)].png")
#endif
