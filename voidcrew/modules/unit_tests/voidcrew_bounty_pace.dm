/**
 * Bounty hunting: a fighter's pace and its guns' reach (C4), for voidcrew/modules/bounties/bounty_ai.dm
 * (bounty_ai_step(), the AI's walk) and bounty_styles.dm (the side-step, the back-off, the fire range).
 * Criminals and companions are real human bodies that walk and run at a person's pace; the steps the AI
 * takes by hand (out of a friend's line of fire, back from someone too close) come no sooner than a step
 * of the body's own, and hold the AI's walk back as long. A gun fires at anyone it sees within 7 tiles
 * while walking in to 5; the shotgun fires from as close as it walks in.
 *
 * The tests drive the behaviours directly, with the gun tests' helpers (voidcrew_bounty_guns.dm). Fork
 * defines are included after the tests, so a test uses the literal value with a comment naming the define.
 */

/// The pace tests, in the bounty AI tests' room, with the gun tests' helpers
/datum/unit_test/voidcrew_bounty_pace
	parent_type = /datum/unit_test/voidcrew_bounty_guns
	abstract_type = /datum/unit_test/voidcrew_bounty_pace

/// `mover`'s own delay for a step in `direction`: what a player's step costs, longer on a diagonal
/datum/unit_test/voidcrew_bounty_pace/proc/step_delay(mob/living/mover, direction)
	var/delay = max(mover.cached_multiplicative_slowdown, world.tick_lag)
	return ISDIAGONALDIR(direction) ? delay * sqrt(2) : delay

/**
 * A gunman steps out of a friend's line of fire at a person's pace. The shooting runs ten times a second;
 * a second step the same tick, or before the body's own move delay is up, is refused, and once the delay
 * is up it steps again.
 */
/datum/unit_test/voidcrew_bounty_pace/sidestep

/datum/unit_test/voidcrew_bounty_pace/sidestep/Run()
	var/mob/living/carbon/human/npc/bounty_criminal/normal/gunman = make_criminal(/mob/living/carbon/human/npc/bounty_criminal/normal, tile(0, 2), "pistol") // BOUNTY_STYLE_PISTOL
	gunman.ai_controller.set_ai_status(AI_STATUS_OFF)
	var/mob/living/carbon/human/target = make_target(gunman, tile(4, 2))
	draw_gun(gunman)
	var/datum/ai_controller/controller = gunman.ai_controller
	// A friend of theirs in the way
	var/list/gang = gunman.spawn_companions(1, TRUE, list(list("style" = "brawler"))) // BOUNTY_COMPANY_STYLE, BOUNTY_STYLE_BRAWLER
	TEST_ASSERT(length(gang), "Test fixture: no companion")
	allocated += gang
	var/mob/living/carbon/human/npc/bounty_companion/friend = gang[1]
	friend.ai_controller.set_ai_status(AI_STATUS_OFF)
	friend.forceMove(tile(2, 2))
	TEST_ASSERT(bounty_ai_line_blocked(gunman, target), "Test fixture: the friend isn't in the gunman's line of fire")
	TEST_ASSERT(bounty_ai_step_ready(gunman), "Test fixture: the gunman can't step yet")

	// The first step aside comes at once
	var/turf/start = get_turf(gunman)
	shoot_step(gunman)
	var/turf/first_step = get_turf(gunman)
	TEST_ASSERT(first_step != start, "The gunman didn't step out of the friend's line of fire")
	var/delay = step_delay(gunman, get_dir(start, first_step))
	TEST_ASSERT(controller.blackboard["bb_bounty_next_step_at"] >= world.time + delay - 0.01, "The gunman's next step by hand isn't a step's time away") // BB_BOUNTY_NEXT_STEP_AT
	TEST_ASSERT(!bounty_ai_step_ready(gunman), "Right after a step, the gunman may step again")

	// The friend in the way again, the same tick: no second step
	var/list/new_line = get_line(first_step, get_turf(target))
	TEST_ASSERT(length(new_line) >= 3, "Test fixture: the gunman stepped next to the hunter")
	friend.forceMove(new_line[2])
	TEST_ASSERT(bounty_ai_line_blocked(gunman, target), "Test fixture: the friend isn't in the gunman's new line of fire")
	for(var/i in 1 to 3)
		shoot_step(gunman)
		TEST_ASSERT_EQUAL(get_turf(gunman), first_step, "The gunman stepped twice in less than a step's time")
	// The back-off waits for the body too
	var/backstep_at = controller.blackboard["bb_bounty_backstep_at"] // BB_BOUNTY_BACKSTEP_AT
	TEST_ASSERT(!bounty_ai_back_off(controller, gunman, target), "The gunman backed off in less than a step's time")
	TEST_ASSERT_EQUAL(controller.blackboard["bb_bounty_backstep_at"], backstep_at, "A back-off refused for its pace still used up its turn")

	// Once a step's time is up, it steps aside again
	controller.set_blackboard_key("bb_bounty_next_step_at", world.time) // BB_BOUNTY_NEXT_STEP_AT
	shoot_step(gunman)
	TEST_ASSERT(get_turf(gunman) != first_step, "Once a step's time was up, the gunman didn't step aside again")
	shoot_stopped(gunman)
	target.fully_heal(HEAL_ALL)

/**
 * The AI's walk and the steps by hand share the body's pace: a step of the walk holds the next step by
 * hand back by the body's move delay, and a step by hand holds the walk back as long, so the two never
 * add up to two steps in a step's time. A step that isn't paced (the meek's step onto a potted plant's
 * tile) goes as before.
 */
/datum/unit_test/voidcrew_bounty_pace/walk

/datum/unit_test/voidcrew_bounty_pace/walk/Run()
	var/mob/living/carbon/human/npc/bounty_criminal/normal/walker = make_criminal(/mob/living/carbon/human/npc/bounty_criminal/normal, tile(1, 1), "brawler") // BOUNTY_STYLE_BRAWLER
	var/datum/ai_controller/controller = walker.ai_controller
	controller.set_ai_status(AI_STATUS_OFF)
	TEST_ASSERT(istype(controller.ai_movement, /datum/ai_movement/jps/bounty), "Test fixture: the criminal doesn't walk with the bounty movement")

	// A step of the walk: its next step by hand waits
	var/datum/move_loop/fake_step = new /datum/move_loop(null, null, walker, 0, 0, controller)
	walker.Move(tile(2, 1), EAST)
	TEST_ASSERT_EQUAL(get_turf(walker), tile(2, 1), "Test fixture: the walker didn't step")
	controller.ai_movement.post_move(fake_step, 1) // MOVELOOP_SUCCESS
	qdel(fake_step)
	TEST_ASSERT(!bounty_ai_step_ready(walker), "Right after a step of its walk, the criminal may step by hand")
	TEST_ASSERT(controller.blackboard["bb_bounty_next_step_at"] >= world.time + step_delay(walker, EAST) - 0.01, "A step of the walk doesn't hold the next step by hand a step's time") // BB_BOUNTY_NEXT_STEP_AT
	TEST_ASSERT(!bounty_ai_step(walker, tile(3, 1), paced = TRUE), "A paced step went right after a step of the walk")
	TEST_ASSERT_EQUAL(get_turf(walker), tile(2, 1), "The refused step moved the criminal")
	// An unpaced step goes, as it always did
	TEST_ASSERT(bounty_ai_step(walker, tile(3, 1)), "An unpaced step was refused")

	// A step by hand holds the walk back
	controller.set_blackboard_key("bb_bounty_next_step_at", world.time) // BB_BOUNTY_NEXT_STEP_AT
	GLOB.move_manager.move(walker, NORTH, 1, 5 SECONDS, SSai_movement)
	var/datum/move_loop/walk = GLOB.move_manager.processing_on(walker, SSai_movement)
	TEST_ASSERT_NOTNULL(walk, "Test fixture: no walk on the AI's movement")
	TEST_ASSERT(walk.timer < world.time + step_delay(walker, NORTH), "Test fixture: the walk's next step is already a step's time off")
	TEST_ASSERT(bounty_ai_step(walker, tile(3, 2), paced = TRUE), "A paced step with the time up was refused")
	var/held_for = walk.timer - world.time
	GLOB.move_manager.stop_looping(walker, SSai_movement)
	TEST_ASSERT(held_for >= step_delay(walker, NORTH) - 0.01, "After a step by hand, the walk's next step is only [held_for] away")

/**
 * A gun fires at anyone it can see within 7 tiles (BOUNTY_GUN_FIRE_RANGE) while it walks in to 5
 * (BOUNTY_PISTOL_RANGE), and never further; the shotgun fires only from as close as it walks in to
 * (BOUNTY_SHOTGUN_RANGE), and the bottle thrower throws from its own distance.
 */
/datum/unit_test/voidcrew_bounty_pace/gun_range
	var/datum/turf_reservation/range

/datum/unit_test/voidcrew_bounty_pace/gun_range/Destroy()
	QDEL_LIST(allocated)
	QDEL_NULL(range)
	return ..()

/datum/unit_test/voidcrew_bounty_pace/gun_range/Run()
	var/datum/ai_behavior/bounty_shoot/shooting = GET_AI_BEHAVIOR(/datum/ai_behavior/bounty_shoot)
	TEST_ASSERT_EQUAL(shooting.fire_range, 7, "Guns don't fire out to 7 tiles")
	TEST_ASSERT_EQUAL(shooting.required_distance, 5, "Guns don't walk in to 5 tiles")
	var/datum/ai_behavior/bounty_shoot/close/shotgun_range = GET_AI_BEHAVIOR(/datum/ai_behavior/bounty_shoot/close)
	TEST_ASSERT_EQUAL(shotgun_range.fire_range, shotgun_range.required_distance, "The shotgun fires from further off than it walks in to")
	var/datum/ai_behavior/bounty_shoot/throw/bottle_range = GET_AI_BEHAVIOR(/datum/ai_behavior/bounty_shoot/throw)
	TEST_ASSERT_EQUAL(bottle_range.fire_range, bottle_range.required_distance, "Bottles fly from further off than the thrower keeps")

	// A corridor long enough to shoot down
	range = SSmapping.request_turf_block_reservation(12, 3, 1, null, /datum/turf_reservation, /turf/open/floor/iron)
	TEST_ASSERT_NOTNULL(range, "Could not reserve a corridor")
	var/turf/anchor = range.bottom_left_turfs[1]
	var/area/testroom = GLOB.areas_by_type[/area/misc/testroom]
	for(var/dx in 0 to 11)
		for(var/dy in 0 to 2)
			var/turf/tile = locate(anchor.x + dx, anchor.y + dy, anchor.z)
			tile.change_area(tile.loc, testroom)

	// The pistol: a shot at 7 tiles, none at 8
	var/mob/living/carbon/human/npc/bounty_criminal/normal/gunman = make_criminal(/mob/living/carbon/human/npc/bounty_criminal/normal, locate(anchor.x, anchor.y + 1, anchor.z), "pistol") // BOUNTY_STYLE_PISTOL
	gunman.ai_controller.set_ai_status(AI_STATUS_OFF)
	var/mob/living/carbon/human/target = make_target(gunman, locate(anchor.x + 7, anchor.y + 1, anchor.z))
	var/obj/item/gun/ballistic/stechkin = draw_gun(gunman)
	var/datum/ai_controller/controller = gunman.ai_controller
	controller.set_blackboard_key("bb_bounty_windup_until", world.time) // BB_BOUNTY_WINDUP_UNTIL
	controller.set_blackboard_key("bb_bounty_next_shot", world.time) // BB_BOUNTY_NEXT_SHOT
	var/rounds = bounty_gun_live_rounds(stechkin)
	shoot_step(gunman)
	TEST_ASSERT_EQUAL(bounty_gun_live_rounds(stechkin), rounds - 1, "The pistol didn't fire at someone 7 tiles off")
	next_pull(gunman, target)
	target.forceMove(locate(anchor.x + 8, anchor.y + 1, anchor.z))
	shoot_step(gunman)
	TEST_ASSERT_EQUAL(bounty_gun_live_rounds(stechkin), rounds - 1, "The pistol fired at someone 8 tiles off")
	shoot_stopped(gunman)

	// The shotgun: nothing at 3 tiles, a blast at 2
	var/mob/living/carbon/human/npc/bounty_criminal/normal/blaster = make_criminal(/mob/living/carbon/human/npc/bounty_criminal/normal, locate(anchor.x, anchor.y + 2, anchor.z), "shotgun") // BOUNTY_STYLE_SHOTGUN
	blaster.ai_controller.set_ai_status(AI_STATUS_OFF)
	var/mob/living/carbon/human/mark = make_target(blaster, locate(anchor.x + 3, anchor.y + 2, anchor.z))
	var/obj/item/gun/ballistic/shotgun = draw_gun(blaster)
	var/datum/ai_controller/shotgun_ai = blaster.ai_controller
	var/shells = bounty_gun_live_rounds(shotgun)
	for(var/i in 1 to 2)
		shotgun_ai.set_blackboard_key("bb_bounty_next_shot", world.time) // BB_BOUNTY_NEXT_SHOT
		shotgun_ai.set_blackboard_key("bb_bounty_windup_until", world.time) // BB_BOUNTY_WINDUP_UNTIL
		shoot_step(blaster)
	TEST_ASSERT_EQUAL(bounty_gun_live_rounds(shotgun), shells, "The shotgun fired at someone 3 tiles off")
	mark.forceMove(locate(anchor.x + 2, anchor.y + 2, anchor.z))
	bounty_ai_clear_windup(shotgun_ai)
	shotgun_ai.set_blackboard_key("bb_bounty_next_shot", world.time) // BB_BOUNTY_NEXT_SHOT
	shoot_step(blaster)
	shotgun_ai.set_blackboard_key("bb_bounty_windup_until", world.time) // BB_BOUNTY_WINDUP_UNTIL: the pump done
	shoot_step(blaster)
	TEST_ASSERT_EQUAL(bounty_gun_live_rounds(shotgun), shells - 1, "The shotgun didn't fire at someone 2 tiles off")
	shoot_stopped(blaster)
	target.fully_heal(HEAL_ALL)
	mark.fully_heal(HEAL_ALL)
