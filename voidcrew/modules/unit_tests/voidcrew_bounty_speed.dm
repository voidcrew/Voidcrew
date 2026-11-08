/**
 * Bounty fighters' pace against a player's: every move delay here is the one the mob really moves
 * at (cached_multiplicative_slowdown, which the AI's move loop uses), compared with a real human's
 * running and walking delays. The live tests let the AI chase a hunter who runs at a player's pace.
 * (voidcrew/modules/bounties/bounty_ai.dm: ai_set_pace(), /datum/ai_movement/jps/bounty_paced;
 * the paces are in voidcrew/_DEFINES/bounty_ai.dm and bounty_bosses.dm.)
 */
/datum/unit_test/voidcrew_bounty_speed
	abstract_type = /datum/unit_test/voidcrew_bounty_speed
	/// A player human's move delay running, and walking
	var/run_delay
	var/walk_delay

/// A human standing in for the player, whose run and walk delays every pace is held against
/datum/unit_test/voidcrew_bounty_speed/proc/player_at(turf/where)
	var/mob/living/carbon/human/consistent/person = allocate(/mob/living/carbon/human/consistent, where)
	run_delay = person.cached_multiplicative_slowdown
	person.toggle_move_intent()
	walk_delay = person.cached_multiplicative_slowdown
	person.toggle_move_intent()
	return person

/// A criminal made the way the game makes one, from a record
/datum/unit_test/voidcrew_bounty_speed/proc/criminal(turf/where, archetype = "normal", style = null, kit = null, species = null)
	var/datum/bounty_record/record = new
	record.archetype = archetype
	record.tier = 2 // BOUNTY_TIER_WANTED
	record.style = style
	record.kit = kit
	record.species = species
	var/mob/living/basic/bounty_criminal/made = spawn_bounty_criminal(record, where, null)
	allocated += made
	return made

/datum/unit_test/voidcrew_bounty_speed/proc/delay_of(mob/living/mover)
	return mover.cached_multiplicative_slowdown

/datum/unit_test/voidcrew_bounty_speed/proc/same(first, second)
	return abs(first - second) < 0.01

/// Paces, read off the mobs: fighting is a running player's, calm a walking one's
/datum/unit_test/voidcrew_bounty_speed/paces

/datum/unit_test/voidcrew_bounty_speed/paces/Run()
	var/mob/living/carbon/human/consistent/hunter = player_at(locate(run_loc_floor_bottom_left.x + 4, run_loc_floor_bottom_left.y, run_loc_floor_bottom_left.z))
	TEST_ASSERT(run_delay > 0 && walk_delay > run_delay, "A player runs [run_delay] apart and walks [walk_delay] apart")

	// Every style: a walk while calm, a run in a fight and while retreating, the AI walking them at it
	for(var/style in list("brawler", "knife", "club", "pistol", "smg", "revolver", "shotgun", "bottle")) // BOUNTY_STYLE_*
		var/mob/living/basic/bounty_criminal/normal/crook = criminal(run_loc_floor_bottom_left, style = style)
		TEST_ASSERT(same(delay_of(crook), walk_delay), "A calm [style] criminal moves [delay_of(crook)] apart; a walking player [walk_delay]")
		crook.ai_start_fight(hunter)
		TEST_ASSERT(same(delay_of(crook), run_delay), "A [style] criminal fighting moves [delay_of(crook)] apart; a running player [run_delay]")
		TEST_ASSERT(same(crook.ai_controller.movement_delay, delay_of(crook)), "The AI walks a [style] criminal [crook.ai_controller.movement_delay] apart, not at its pace")
		crook.ai_start_retreat(hunter)
		TEST_ASSERT(same(delay_of(crook), run_delay), "A [style] criminal retreating moves [delay_of(crook)] apart; a running player [run_delay]")
		crook.ai_calm_down()
		TEST_ASSERT(same(delay_of(crook), walk_delay), "A [style] criminal calmed down moves [delay_of(crook)] apart; a walking player [walk_delay]")
		allocated -= crook
		qdel(crook)

	// A companion of any style: a walk at the bar, a run in the fight and when it runs off
	var/mob/living/basic/bounty_criminal/normal/leader = criminal(run_loc_floor_bottom_left, style = "brawler")
	var/list/gang = leader.spawn_companions(1)
	TEST_ASSERT(length(gang), "No companion could be spawned")
	var/mob/living/basic/bounty_companion/buddy = gang[1]
	allocated += buddy
	for(var/style in list("brawler", "club", "pistol", "shotgun"))
		buddy.ai_take_style(style)
		buddy.ai_leave_fight()
		TEST_ASSERT(same(delay_of(buddy), walk_delay), "A calm [style] companion moves [delay_of(buddy)] apart; a walking player [walk_delay]")
		buddy.ai_join_fight(hunter)
		TEST_ASSERT(same(delay_of(buddy), run_delay), "A [style] companion fighting moves [delay_of(buddy)] apart; a running player [run_delay]")
		TEST_ASSERT(same(buddy.ai_controller.movement_delay, delay_of(buddy)), "The AI walks a [style] companion [buddy.ai_controller.movement_delay] apart, not at its pace")
	buddy.ai_run_off(hunter)
	TEST_ASSERT(same(delay_of(buddy), run_delay), "A companion running off moves [delay_of(buddy)] apart; a running player [run_delay]")

	// The meek: a sprint a little faster than a runner (a lizard's faster still), winded slower than one
	var/mob/living/basic/bounty_criminal/meek/runner = criminal(run_loc_floor_bottom_left, archetype = "meek", style = "holdout")
	TEST_ASSERT(same(delay_of(runner), walk_delay), "A calm meek criminal moves [delay_of(runner)] apart; a walking player [walk_delay]")
	runner.ai_flee_event(hunter)
	TEST_ASSERT(HAS_TRAIT(runner, "bounty_sprinting"), "A fleeing meek criminal isn't sprinting") // TRAIT_BOUNTY_SPRINTING
	var/sprint = delay_of(runner)
	TEST_ASSERT(sprint < run_delay - 0.1, "A meek criminal sprints [sprint] apart, no faster than a running player ([run_delay])")
	TEST_ASSERT(sprint > run_delay * 0.7, "A meek criminal sprints [sprint] apart: out of reach of anyone running ([run_delay])")
	runner.ai_sprint_left = 0
	runner.ai_update_sprint()
	TEST_ASSERT(runner.ai_winded, "A meek criminal with no sprint left isn't winded")
	TEST_ASSERT(delay_of(runner) > run_delay + 0.5 && delay_of(runner) < walk_delay, "A winded meek criminal moves [delay_of(runner)] apart: not between a run ([run_delay]) and a walk ([walk_delay])")
	var/mob/living/basic/bounty_criminal/meek/lizard = criminal(run_loc_floor_bottom_left, archetype = "meek", style = "holdout", species = /datum/species/lizard)
	lizard.ai_flee_event(hunter)
	TEST_ASSERT(delay_of(lizard) < sprint, "A lizard sprints [delay_of(lizard)] apart, no faster than anyone else ([sprint])")

	// Mini-bosses keep their own paces: the Ghost a runner's, the rest slower, the Heavy slowest, none down to a walk
	var/list/boss_paces = list()
	for(var/kit in list("juggernaut", "pyromaniac", "demolitionist", "ghost", "heavy")) // BOUNTY_KIT_*
		var/mob/living/basic/bounty_criminal/boss/boss = criminal(run_loc_floor_bottom_left, archetype = "boss", kit = kit)
		TEST_ASSERT(istype(boss), "No [kit] could be spawned")
		boss_paces[kit] = delay_of(boss)
		TEST_ASSERT(same(boss.ai_controller.movement_delay, delay_of(boss)), "The AI walks a [kit] [boss.ai_controller.movement_delay] apart, not at its pace")
		TEST_ASSERT(delay_of(boss) < walk_delay - 1, "A [kit] moves [delay_of(boss)] apart, about a walk ([walk_delay])")
		allocated -= boss
		qdel(boss)
	TEST_ASSERT(same(boss_paces["ghost"], run_delay), "The Ghost moves [boss_paces["ghost"]] apart; a running player [run_delay]")
	for(var/kit in list("juggernaut", "pyromaniac", "demolitionist", "heavy"))
		TEST_ASSERT(boss_paces[kit] > run_delay + 0.3, "A [kit] moves [boss_paces[kit]] apart, keeping up with a running player ([run_delay])")
		if(kit != "heavy")
			TEST_ASSERT(boss_paces["heavy"] > boss_paces[kit], "The Heavy ([boss_paces["heavy"]]) isn't slower than the [kit] ([boss_paces[kit]])")

	// The Cascade lattice: twice a runner's pace in the window, a walk in the crash, a run again after
	var/mob/living/basic/bounty_criminal/normal/surger = criminal(run_loc_floor_bottom_left, style = "knife")
	bounty_chrome_install(surger, list("cascade")) // BOUNTY_CHROME_CASCADE
	surger.ai_start_fight(hunter)
	var/datum/bounty_chrome/cascade/lattice = bounty_chrome_piece(surger, "cascade")
	lattice.spin_up()
	lattice.open_window()
	TEST_ASSERT_EQUAL(lattice.phase, 2, "The window didn't open") // BOUNTY_CASCADE_WINDOW
	TEST_ASSERT(delay_of(surger) <= run_delay * 0.55, "In the window they move [delay_of(surger)] apart, not twice as fast as a running player ([run_delay])")
	TEST_ASSERT(same(surger.ai_controller.movement_delay, delay_of(surger)), "The AI doesn't walk them at the window's pace")
	lattice.start_crash()
	TEST_ASSERT(delay_of(surger) >= walk_delay - 0.01, "In the crash they move [delay_of(surger)] apart, quicker than a walking player ([walk_delay])")
	lattice.end_crash()
	TEST_ASSERT(same(delay_of(surger), run_delay), "After a surge they move [delay_of(surger)] apart, not a runner's [run_delay]")
	// A companion's window is as quick
	var/mob/living/basic/bounty_companion/surging_buddy = allocate(/mob/living/basic/bounty_companion, run_loc_floor_bottom_left)
	surging_buddy.ai_take_style("club")
	bounty_chrome_install(surging_buddy, list("cascade"))
	surging_buddy.ai_join_fight(hunter)
	var/datum/bounty_chrome/cascade/buddy_lattice = bounty_chrome_piece(surging_buddy, "cascade")
	buddy_lattice.spin_up()
	buddy_lattice.open_window()
	TEST_ASSERT(delay_of(surging_buddy) <= run_delay * 0.55, "A companion in the window moves [delay_of(surging_buddy)] apart, not twice a runner's pace")
	buddy_lattice.end_surge()

/**
 * A ranged fighter steps out of a friend's line of fire at its own pace: the behavior runs ten
 * times a second, and the step used to come with it every time (gunmen darting across the room).
 */
/datum/unit_test/voidcrew_bounty_speed/sidestep

/datum/unit_test/voidcrew_bounty_speed/sidestep/Run()
	var/turf/corner = run_loc_floor_bottom_left
	var/mob/living/carbon/human/consistent/hunter = player_at(locate(corner.x + 4, corner.y + 2, corner.z))
	var/mob/living/basic/bounty_criminal/normal/gunman = criminal(locate(corner.x, corner.y + 2, corner.z), style = "pistol")
	gunman.ai_start_fight(hunter)
	var/datum/ai_controller/controller = gunman.ai_controller
	controller.clear_blackboard_key("bb_bounty_windup_until") // BB_BOUNTY_WINDUP_UNTIL: the draw
	var/list/gang = gunman.spawn_companions(1)
	TEST_ASSERT(length(gang), "No companion could be spawned")
	var/mob/living/basic/bounty_companion/friend = gang[1]
	allocated += friend
	friend.ai_controller.set_ai_status(AI_STATUS_OFF)
	friend.forceMove(locate(corner.x + 2, corner.y + 2, corner.z))
	var/datum/ai_behavior/basic_ranged_attack/bounty/shooting = GET_AI_BEHAVIOR(/datum/ai_behavior/basic_ranged_attack/bounty)
	TEST_ASSERT(shooting.check_friendly_in_path(gunman, hunter, GET_TARGETING_STRATEGY(controller.blackboard[BB_TARGETING_STRATEGY])), "The companion isn't in the gunman's line of fire")
	var/turf/start = get_turf(gunman)
	shooting.perform(0.1, controller, BB_BASIC_MOB_CURRENT_TARGET, BB_TARGETING_STRATEGY, BB_BASIC_MOB_CURRENT_TARGET_HIDING_LOCATION)
	var/turf/first_step = get_turf(gunman)
	TEST_ASSERT(first_step != start, "The gunman didn't step out of the companion's line of fire")
	// The same tick, and the next few: no second step until a step's worth of time has gone by
	friend.forceMove(get_step_towards(first_step, hunter))
	if(shooting.check_friendly_in_path(gunman, hunter, GET_TARGETING_STRATEGY(controller.blackboard[BB_TARGETING_STRATEGY])))
		shooting.perform(0.1, controller, BB_BASIC_MOB_CURRENT_TARGET, BB_TARGETING_STRATEGY, BB_BASIC_MOB_CURRENT_TARGET_HIDING_LOCATION)
		TEST_ASSERT_EQUAL(get_turf(gunman), first_step, "The gunman stepped twice in one tick")
		TEST_ASSERT(controller.blackboard["bb_bounty_sidestep_at"] >= world.time + run_delay - 0.01, "The next step aside isn't a step's time away") // BB_BOUNTY_SIDESTEP_AT
		controller.set_blackboard_key("bb_bounty_sidestep_at", world.time)
		shooting.perform(0.1, controller, BB_BASIC_MOB_CURRENT_TARGET, BB_TARGETING_STRATEGY, BB_BASIC_MOB_CURRENT_TARGET_HIDING_LOCATION)
		TEST_ASSERT(get_turf(gunman) != first_step, "Once the time was up, the gunman didn't step aside again")

/**
 * The live chase: the AI on, a hunter running down a long corridor at a player's pace. A fighter
 * keeps up, a Cascade window runs them down, its crash falls behind, a gunman keeps its range, and a
 * pace between ticks is walked as it is.
 */
/datum/unit_test/voidcrew_bounty_speed/chase
	priority = TEST_LONGER
	var/datum/turf_reservation/corridor
	var/turf/anchor
	/// Stands in for a player on the level, so the AI runs
	var/mob/living/carbon/human/watcher
	var/watched_z
	/// Steps counted by count_step()
	var/steps = 0

/datum/unit_test/voidcrew_bounty_speed/chase/Destroy()
	if(watcher && watched_z)
		SSmobs.clients_by_zlevel[watched_z] -= watcher
	watcher = null
	QDEL_LIST(allocated)
	QDEL_NULL(corridor)
	return ..()

/datum/unit_test/voidcrew_bounty_speed/chase/proc/spot(dx, dy)
	return locate(anchor.x + dx, anchor.y + dy, anchor.z)

/datum/unit_test/voidcrew_bounty_speed/chase/proc/count_step(datum/source)
	SIGNAL_HANDLER
	steps++

/datum/unit_test/voidcrew_bounty_speed/chase/proc/wake(mob/living/basic/mover)
	mover.ai_controller.can_idle = FALSE
	mover.ai_controller.set_ai_status(AI_STATUS_ON)

/**
 * Sets `chaser` on `runner` and waits, up to 5 seconds, for its first step, then puts the runner
 * `gap` tiles ahead: the race times its pace, not how soon the AI first got to it. The AI plans, acts
 * and walks on background subsystems, which a busy world can hold back, while the runner's move loop
 * runs on SSmovement and never waits. TRUE once it is moving.
 */
/datum/unit_test/voidcrew_bounty_speed/chase/proc/start_chase(mob/living/basic/bounty_criminal/chaser, mob/living/runner, gap)
	runner.forceMove(spot(chaser.x - anchor.x + 7, chaser.y - anchor.y))
	wake(chaser)
	chaser.ai_start_fight(runner)
	var/from_x = chaser.x
	var/until = world.time + 5 SECONDS
	while(world.time < until && chaser.x == from_x)
		sleep(world.tick_lag)
	runner.forceMove(spot(chaser.x - anchor.x + gap, chaser.y - anchor.y))
	return chaser.x != from_x

/// What a chaser is doing, for a failure message: its AI, its walk and anything holding it still
/datum/unit_test/voidcrew_bounty_speed/chase/proc/describe(mob/living/basic/bounty_criminal/chaser)
	var/datum/ai_controller/controller = chaser.ai_controller
	var/list/behaviors = list()
	for(var/datum/ai_behavior/behavior as anything in controller.current_behaviors)
		behaviors += "[behavior.type]"
	var/datum/movement_packet/packet = chaser.move_packet
	var/datum/move_loop/has_target/jps/loop = packet ? packet.existing_loops[SSai_movement] : null
	var/list/held = list()
	for(var/trait in list(TRAIT_IMMOBILIZED, TRAIT_INCAPACITATED, TRAIT_FLOORED, TRAIT_AI_PAUSED, TRAIT_HANDS_BLOCKED, TRAIT_NO_TRANSFORM))
		if(HAS_TRAIT(chaser, trait))
			held += trait
	var/list/parts = list(
		"mode [chaser.ai_mode], acts [chaser.ai_can_act()], ai [controller.ai_status], runs [controller.able_to_run], plans [controller.able_to_plan]",
		"target [controller.blackboard[BB_BASIC_MOB_CURRENT_TARGET]], behaviors [jointext(behaviors, " ")], walking to [controller.current_movement_target]",
		"loop [loop ? "[loop.type] delay [loop.delay] path [length(loop.movement_path)] pathing [loop.is_pathing]" : "none"], path fails [controller.consecutive_pathing_attempts]",
		"moves [!!(chaser.mobility_flags & MOBILITY_MOVE)], delay [delay_of(chaser)], traits [jointext(held, " ")]",
	)
	return jointext(parts, "; ")

/// Runs `runner` east at a player's pace for `time`, healing them as they go; returns how far `chaser` got, as list(chaser, runner)
/datum/unit_test/voidcrew_bounty_speed/chase/proc/race(mob/living/runner, mob/living/basic/chaser, time)
	var/chaser_from = chaser.x
	var/runner_from = runner.x
	GLOB.move_manager.move(runner, EAST, run_delay, timeout = time)
	var/until = world.time + time
	while(world.time < until)
		sleep(0.5 SECONDS)
		runner.fully_heal()
	GLOB.move_manager.stop_looping(runner)
	return list(chaser.x - chaser_from, runner.x - runner_from)

/datum/unit_test/voidcrew_bounty_speed/chase/Run()
	corridor = SSmapping.request_turf_block_reservation(44, 9, 1, null, /datum/turf_reservation, /turf/open/floor/iron)
	TEST_ASSERT_NOTNULL(corridor, "Could not reserve a corridor")
	anchor = corridor.bottom_left_turfs[1]
	var/area/testroom = GLOB.areas_by_type[/area/misc/testroom]
	for(var/dx in 0 to 43)
		for(var/dy in 0 to 8)
			var/turf/tile = spot(dx, dy)
			tile.change_area(tile.loc, testroom)
	watcher = allocate(/mob/living/carbon/human/consistent, spot(0, 8))
	watched_z = anchor.z
	SSmobs.clients_by_zlevel[watched_z] |= watcher
	var/mob/living/carbon/human/consistent/runner = player_at(spot(10, 4))

	// A knife fighter keeps up with a runner: the gap may not open up
	var/mob/living/basic/bounty_criminal/normal/knifer = criminal(spot(3, 4), style = "knife")
	TEST_ASSERT(start_chase(knifer, runner, 2), "A knife criminal's AI never took up the chase: [describe(knifer)]")
	var/list/ran = race(runner, knifer, 4 SECONDS)
	var/gap = runner.x - knifer.x
	TEST_NOTICE(src, "Knife chase: the criminal covered [ran[1]] tiles to the runner's [ran[2]], [gap] behind at the end")
	TEST_ASSERT(gap <= 4, "Chasing a runner, a knife criminal covered [ran[1]] tiles to their [ran[2]] and fell [gap] behind")
	allocated -= knifer
	qdel(knifer)

	// A pace between two ticks (1.25) is walked as it is, where tg's own move loop rounds it up to the next tick
	var/mob/living/basic/bounty_criminal/normal/walker = criminal(spot(1, 2), style = "brawler")
	// Nothing but the walk: no plans, no idle wander (the move loop runs with the AI off)
	walker.ai_controller.replace_planning_subtrees(list())
	walker.ai_controller.set_ai_status(AI_STATUS_OFF)
	walker.set_varspeed(walker.speed - delay_of(walker) + 1.25)
	TEST_ASSERT(same(delay_of(walker), 1.25), "The walker moves [delay_of(walker)] apart, not 1.25")
	var/mob/living/carbon/human/consistent/reference = allocate(/mob/living/carbon/human/consistent, spot(1, 6))
	walker.ai_controller.max_target_distance = 0
	walker.ai_controller.ai_movement.start_moving_towards(walker.ai_controller, spot(30, 2), 0)
	GLOB.move_manager.move(reference, EAST, 1.25, timeout = 3 SECONDS)
	steps = 0
	RegisterSignal(walker, COMSIG_MOVABLE_MOVED, PROC_REF(count_step))
	var/reference_from = reference.x
	sleep(3 SECONDS)
	UnregisterSignal(walker, COMSIG_MOVABLE_MOVED)
	var/reference_steps = reference.x - reference_from
	TEST_NOTICE(src, "At 1.25 apart for 3 seconds: bounty walker [steps] steps, tg move loop [reference_steps]")
	TEST_ASSERT(steps >= 21 && steps >= reference_steps + 2, "At 1.25 apart, in 3 seconds the bounty walker took [steps] steps and tg's move loop [reference_steps] (24 is the pace)")
	walker.ai_controller.ai_movement.stop_moving_towards(walker.ai_controller)
	GLOB.move_manager.stop_looping(reference)
	allocated -= walker
	qdel(walker)

	// In a Cascade window, a fighter runs a runner down from well back
	var/mob/living/basic/bounty_criminal/normal/surger = criminal(spot(3, 4), style = "knife")
	bounty_chrome_install(surger, list("cascade")) // BOUNTY_CHROME_CASCADE
	TEST_ASSERT(start_chase(surger, runner, 7), "A Cascade criminal's AI never took up the chase: [describe(surger)]")
	var/datum/bounty_chrome/cascade/lattice = bounty_chrome_piece(surger, "cascade")
	lattice.next_surge_at = world.time + 1 MINUTES
	lattice.spin_up()
	lattice.open_window()
	var/surger_before = describe(surger)
	ran = race(runner, surger, 2.5 SECONDS)
	gap = runner.x - surger.x
	TEST_NOTICE(src, "Cascade window chase from 7 back: the criminal covered [ran[1]] tiles to the runner's [ran[2]], [gap] behind at the end")
	TEST_ASSERT(gap <= 2, "In a Cascade window, a criminal 7 tiles back covered [ran[1]] tiles to a runner's [ran[2]] and was still [gap] behind. Before: [surger_before]. After: [describe(surger)]")
	allocated -= surger
	qdel(surger)

	// Its crash falls behind
	var/mob/living/basic/bounty_criminal/normal/crashed = criminal(spot(3, 4), style = "knife")
	bounty_chrome_install(crashed, list("cascade"))
	TEST_ASSERT(start_chase(crashed, runner, 2), "A Cascade criminal's AI never took up the chase: [describe(crashed)]")
	var/datum/bounty_chrome/cascade/spent = bounty_chrome_piece(crashed, "cascade")
	spent.next_surge_at = world.time + 1 MINUTES
	spent.spin_up()
	spent.open_window()
	spent.start_crash()
	ran = race(runner, crashed, 2.5 SECONDS)
	TEST_NOTICE(src, "Cascade crash chase: the criminal covered [ran[1]] tiles to the runner's [ran[2]]")
	TEST_ASSERT(ran[2] - ran[1] >= 5, "In the crash, a criminal covered [ran[1]] tiles to a runner's [ran[2]]: it kept up")
	allocated -= crashed
	qdel(crashed)

	// A gunman keeps a runner in range: never left behind past its sight
	var/mob/living/basic/bounty_criminal/normal/gunman = criminal(spot(3, 4), style = "pistol")
	TEST_ASSERT(start_chase(gunman, runner, 5), "A gunman's AI never took up the chase: [describe(gunman)]")
	gunman.ai_controller.set_blackboard_key("bb_bounty_reload_until", world.time + 1 MINUTES) // BB_BOUNTY_RELOAD_UNTIL: no shots, only the chase
	ran = race(runner, gunman, 3 SECONDS)
	gap = runner.x - gunman.x
	TEST_NOTICE(src, "Gunman chase: the criminal covered [ran[1]] tiles to the runner's [ran[2]], [gap] behind at the end")
	TEST_ASSERT(gap <= 8, "Chasing a runner, a gunman covered [ran[1]] tiles to their [ran[2]] and fell [gap] behind")
