/*
 * NPC pirate boarding AI - regression tests for the 2026-08 behavior-tree port.
 *
 * INCIDENT
 * The fork's boarding-party AI was re-authored from planning_subtrees into behavior trees in
 * 07ea8d7510b. The first live round on the ported AI had every boarding pirate stand still
 * for the whole round, with zero runtimes and a compile-clean tree. Two defects, both of
 * which only a runtime assertion or a static contract check could ever have caught:
 *
 *   FATAL #1 "exploration_hold INSTANT latch"
 *     /datum/bt_node/ai_behavior/exploration_hold/perform() returned a bare
 *     AI_BEHAVIOR_INSTANT. INSTANT is NONE (0) - a modifier, not a result - so
 *     /datum/bt_node/ai_behavior/tick() saw neither the SUCCEEDED nor the FAILED bit and
 *     fell through to BT_RUNNING. A stateless leaf that never completes then returns
 *     BT_RUNNING forever, and the latch is self-sealing twice over: selectors resume at
 *     running_child_index (so every sibling is skipped) and decorators skip
 *     check_condition() while child_active (so the gate that would release the branch is
 *     never re-evaluated). Fix: AI_BEHAVIOR_INSTANT | AI_BEHAVIOR_SUCCEEDED.
 *
 *   FATAL #2 "parallel failure_policy omission"
 *     All three mob_patrol_shared parallels set success_policy BT_PARALLEL_SUCCESS_ALL but
 *     left failure_policy at its BT_PARALLEL_FAILURE_CHILD_ONE default. When child 1 (the
 *     resolve leaf) SUCCEEDS and child 2 (the action branch) FAILS, neither the failure test
 *     nor the success test matches, so the parallel returns BT_RUNNING with nothing actually
 *     running and the enclosing selector pins on it permanently. Fix:
 *     "failure_policy": "BT_PARALLEL_FAILURE_ANY" on all three.
 *
 * Two degraded-but-not-fatal defects are covered here as well: the upstream #97208
 * acquire_target signature drift (fork overrides bound priority_strategy positionally as
 * current_target) and the boss controller swap in boarding_pod.dm forcing
 * set_ai_status(AI_STATUS_ON) past get_expected_ai_status().
 *
 * DRIVER
 * These tests call datum/ai_controller/SelectBehaviors() directly - the exact proc
 * SSai_controllers calls - rather than waiting on the subsystem. SelectBehaviors() consults
 * neither ai_status nor able_to_run, which matters because the unit test room is
 * /area/misc/testroom with no clients, so every controller here parks in AI_STATUS_OFF and
 * the subsystem would never tick it. See pirate_test_tick().
 *
 * The static counterpart to fatal #1 lives in tools/ci/check_bt_returns.py.
 */

// Blackboard keys and step constants owned by voidcrew/modules/npc_ships/.
// tgstation.dme includes code/modules/unit_tests/_unit_tests.dm well before
// voidcrew/modules/npc_ships/code/_defines.dm and mob_patrol.dm, so those #defines are not
// in scope in this file and the literal strings have to be repeated. Every one of them is
// validated against live game state before it is relied on (see the "key is live" assertions
// in each test), so a rename in _defines.dm fails these tests loudly instead of silently
// turning them into no-ops.
#define PIRATE_TEST_BB_EXPLORING_ROOM "_exploring_room"
#define PIRATE_TEST_BB_EXPLORATION_TARGETS "_exploration_targets"
#define PIRATE_TEST_BB_EXPLORATION_INDEX "_exploration_index"
#define PIRATE_TEST_BB_MOB_PATROL_PATH "mob_patrol_path"
#define PIRATE_TEST_BB_MOB_PATROL_INDEX "mob_patrol_index"
#define PIRATE_TEST_BB_MOB_PATROL_TARGET "mob_patrol_target"
#define PIRATE_TEST_BB_PATROL_STEP "_patrol_step"
#define PIRATE_TEST_BB_PATROL_OBSTRUCTION "_patrol_obstruction"
#define PIRATE_TEST_PATROL_STEP_TRAVEL "travel"

/// Concrete pirate used wherever a single representative melee boarder is needed.
#define PIRATE_TEST_MELEE_TYPE /mob/living/basic/trooper/pirate/faction/silverscale/melee

// ==================== SHARED HELPERS ====================

/**
 * Depth-first search of a BUILT behavior tree for the first node of the given type.
 *
 * BT nodes are per-controller instances built from the compiled JSON when the controller
 * possesses its pawn, so there is no typepath -> instance lookup; the tree has to be walked.
 * This walks via the engine's own /datum/bt_node/get_children() contract rather than
 * type-switching on composite/decorator/subtree, so it follows subtree roots and override
 * nodes for free.
 */
/proc/pirate_test_find_bt_node(datum/ai_controller/controller, node_type)
	if(isnull(controller) || isnull(node_type))
		return null
	var/list/to_visit = controller.behavior_nodes?.Copy()
	var/index = 1
	while(index <= length(to_visit))
		var/datum/bt_node/node = to_visit[index++]
		if(isnull(node))
			continue
		if(istype(node, node_type))
			return node
		var/list/children = node.get_children()
		if(length(children))
			to_visit += children
	return null

/**
 * Zeroes every per-node cooldown in a built tree.
 *
 * Behavior cooldowns key off world.time, which does not advance between two direct
 * SelectBehaviors() calls in the same proc. Without this, any leaf that returns
 * AI_BEHAVIOR_DELAY on the first tick is frozen out for the rest of the test, and the
 * repeat_secondary_delay on the trooper tree's target-acquisition parallel would let
 * acquire_target run exactly once.
 */
/proc/pirate_test_zero_cooldowns(datum/ai_controller/controller)
	var/list/to_visit = controller.behavior_nodes?.Copy()
	var/index = 1
	while(index <= length(to_visit))
		var/datum/bt_node/node = to_visit[index++]
		if(isnull(node))
			continue
		if(istype(node, /datum/bt_node/ai_behavior))
			var/datum/bt_node/ai_behavior/leaf = node
			leaf.next_perform_time = 0
		else if(istype(node, /datum/bt_node/composite/parallel))
			var/datum/bt_node/composite/parallel/parallel_node = node
			parallel_node.secondary_ready_at = null
		var/list/children = node.get_children()
		if(length(children))
			to_visit += children

/// One deterministic planning tick. Deliberately does NOT reset active_execution_index:
/// only a BT_RUNNING return writes it, so "did node X run and hold the tick?" stays readable
/// as active_execution_index == X.execution_index without perturbing the observer aborts,
/// which read the same field.
/proc/pirate_test_tick(datum/ai_controller/controller)
	pirate_test_zero_cooldowns(controller)
	controller.SelectBehaviors(1)

/// Stops any movement the tested behaviors started and drops the tree back to a clean plan.
/// Called at the end of every test that lets a move_to_target leaf run, so no JPS moveloop
/// outlives the test.
/proc/pirate_test_halt(datum/ai_controller/controller)
	if(isnull(controller))
		return
	controller.cancel_current_plan()
	controller.ai_movement?.stop_moving_towards(controller)

// ==================== TEST 2 - controller plans ====================

/**
 * Every concrete pirate builds a behavior tree, is alive, and is allowed to run.
 *
 * 2026-08 BT port. Assertion 2 is the important one: initialize_behavior_tree() bails out
 * silently (stack_trace only) when load_tree_from_json() cannot produce a root, leaving a
 * mob with an ai_controller, no behavior_nodes, and no runtime - a totally inert pirate that
 * looks completely healthy from the outside. That is what a missing or stale compiled tree
 * under build/behavior_trees produces, and a .bt.json edit is INERT until tools/build_bt.py
 * regenerates its compiled counterpart.
 *
 * The boss half covers the fourth defect: boarding_pod.dm's boss swap used to call
 * set_ai_status(AI_STATUS_ON) directly, bypassing get_expected_ai_status(). That can park a
 * controller in the ON bucket with able_to_run FALSE, and /datum/ai_movement qdels every
 * moveloop started in that state, so the boss holds position forever.
 */
/datum/unit_test/npc_pirate_ai_controller_plans

/datum/unit_test/npc_pirate_ai_controller_plans/Run()
	for(var/mob/living/basic/trooper/pirate/faction/pirate_type as anything in typesof(/mob/living/basic/trooper/pirate/faction))
		var/mob/living/basic/trooper/pirate/faction/pirate = allocate(pirate_type)

		var/datum/ai_controller/controller = pirate.ai_controller
		TEST_ASSERT_NOTNULL(controller, "[pirate_type] spawned with no ai_controller")
		TEST_ASSERT(LAZYLEN(controller.behavior_nodes), \
			"[pirate_type] ([controller.type]) built no behavior_nodes - initialize_behavior_tree() bailed. \
			Its compiled tree ([BT_COMPILED_PATH(controller.behavior_tree_json)]) is missing or unloadable; \
			run tools/build_bt.py and commit the compiled JSON alongside the .bt.json.")
		TEST_ASSERT_NOTEQUAL(pirate.stat, DEAD, "[pirate_type] was dead on arrival")

		controller.reset_ai_status()
		TEST_ASSERT(controller.able_to_run, \
			"[pirate_type]'s controller is not able_to_run straight out of Initialize()")
		TEST_ASSERT(!controller.forced_off, \
			"[pirate_type] ships with its AI deliberately forced off - it will never plan")
		// NOTE - deviation from the test spec, which asked for ai_status == AI_STATUS_ON here.
		// That is wrong for this environment, and asserting it would be asserting a bug.
		// get_expected_ai_status() -> get_active_ai_status() answers AI_STATUS_ON only for a
		// pawn standing in /area/station or /area/shuttle, or with a nearby client, or with
		// RUN_WHILE_UNWATCHED in ai_traits. The unit test room is /area/misc/testroom, has no
		// clients, and DEFAULT_AI_FLAGS carries no RUN_WHILE_UNWATCHED, so AI_STATUS_OFF is
		// the CORRECT answer here - it is the off-station performance gate doing its job, not
		// a broken pirate. On a real hull it resolves to AI_STATUS_ON because every voidcrew
		// ship area is an /area/shuttle subtype. able_to_run and forced_off are the parts of
		// that decision the mob type actually controls, so they are what is asserted.
		// What else needs guarding is that nothing FORCES a status past that decision, which
		// is the boss-swap defect checked below - and that check has to run on a controller
		// that has NOT just had reset_ai_status() called on it, or it proves nothing.

	// Boss path: run the real boarding-pod swap, with a null ship so assign_mob_to_patrol()
	// returns early instead of needing an overmap hull.
	var/mob/living/basic/trooper/pirate/faction/boss/silverscale/boss = allocate(/mob/living/basic/trooper/pirate/faction/boss/silverscale)
	var/obj/structure/closet/supplypod/boarding/boss/pod = allocate(/obj/structure/closet/supplypod/boarding/boss)
	pod.setup_boarder_patrol(boss, null, 0)

	var/datum/ai_controller/boss_controller = boss.ai_controller
	TEST_ASSERT_NOTNULL(boss_controller, "the boss lost its ai_controller during the boarding-pod swap")
	TEST_ASSERT(istype(boss_controller, /datum/ai_controller/basic_controller/trooper/patrolling/boss), \
		"the boarding-pod boss swap produced [boss_controller.type] instead of a patrolling/boss controller")
	TEST_ASSERT(LAZYLEN(boss_controller.behavior_nodes), \
		"the swapped-in boss controller built no behavior_nodes")
	TEST_ASSERT(boss_controller.able_to_run, "the swapped-in boss controller is not able_to_run")
	TEST_ASSERT_EQUAL(boss_controller.ai_status, boss_controller.get_expected_ai_status(), \
		"the boarding-pod boss swap forced an ai_status past get_expected_ai_status(). \
		A controller parked ON with able_to_run FALSE has every moveloop it starts qdel'd by \
		/datum/ai_movement, which is the boss standing still for the round. Use reset_ai_status().")

// ==================== TEST 3 - the fatal #1 regression ====================

/**
 * The room-exploration branch must not latch the tree as BT_RUNNING forever.
 *
 * 2026-08 BT port, fatal #1 "exploration_hold INSTANT latch". This is the direct regression
 * test: it drives the controller into exploration exactly the way assign_mob_to_patrol() does
 * on landing, then counts the ticks on which exploration_hold is the node holding the tree.
 *
 * The geometry matters. Every exploration target is the pawn's own turf, so
 * explore_resolve_step takes its "reached this waypoint" path every tick: it advances the
 * index, clears BB_EXPLORATION_TARGET and returns SUCCEEDED with no action selected. Both
 * action decorators below it (at_closet, travelling) then decline, which is precisely the
 * fall-through the hold exists to absorb - and precisely the state the port shipped broken.
 */
/datum/unit_test/npc_pirate_patrol_does_not_latch

/datum/unit_test/npc_pirate_patrol_does_not_latch/Run()
	var/mob/living/basic/trooper/pirate/faction/silverscale/melee/pirate = allocate(PIRATE_TEST_MELEE_TYPE)
	var/turf/pirate_turf = get_turf(pirate)
	TEST_ASSERT_NOTNULL(pirate_turf, "the test pirate was allocated without a turf")

	// Exactly boarding_pod.dm's swap. PossessPawn() qdels the old controller, assigns itself
	// to the pawn and recalculates status, so constructing it is the whole swap.
	var/datum/ai_controller/controller = new /datum/ai_controller/basic_controller/trooper/patrolling(pirate)
	TEST_ASSERT_EQUAL(pirate.ai_controller, controller, "the patrolling controller did not take over the pawn")
	TEST_ASSERT(LAZYLEN(controller.behavior_nodes), "the patrolling controller built no behavior_nodes")

	var/datum/bt_node/ai_behavior/hold = pirate_test_find_bt_node(controller, /datum/bt_node/ai_behavior/exploration_hold)
	TEST_ASSERT_NOTNULL(hold, "exploration_hold is not in the built melee patrol tree")
	var/datum/bt_node/decorator/gate = pirate_test_find_bt_node(controller, /datum/bt_node/decorator/exploring_room)
	TEST_ASSERT_NOTNULL(gate, "the exploring_room gate is not in the built melee patrol tree")

	// A synthetic patrol path, so the branch below exploration has something to do once
	// exploration releases the tick. One closed airlock two tiles east: far enough that
	// patrol_resolve_step picks TRAVEL, and not adjacent, so the obstruction branch above
	// exploration stays quiet.
	var/turf/door_turf = get_step(get_step(pirate_turf, EAST), EAST)
	TEST_ASSERT_NOTNULL(door_turf, "the test room is too small to place a patrol door two tiles east")
	var/obj/machinery/door/airlock/patrol_door = allocate(/obj/machinery/door/airlock, door_turf)
	controller.blackboard[PIRATE_TEST_BB_MOB_PATROL_PATH] = list(patrol_door)
	controller.blackboard[PIRATE_TEST_BB_MOB_PATROL_INDEX] = 1

	// Enter exploration the way maybe_start_room_exploration() does. 20 copies of the pawn's
	// own turf keeps explore_resolve_step on its SUCCEEDED-with-no-action path for 20 ticks.
	var/list/exploration_targets = list()
	for(var/i in 1 to 20)
		exploration_targets += pirate_turf
	controller.set_blackboard_key(PIRATE_TEST_BB_EXPLORING_ROOM, "unit_test_room")
	controller.set_blackboard_key(PIRATE_TEST_BB_EXPLORATION_TARGETS, exploration_targets)
	controller.set_blackboard_key(PIRATE_TEST_BB_EXPLORATION_INDEX, 1)

	// The blackboard key strings above are duplicated from _defines.dm (see the header), so
	// prove the gate actually sees the state we just wrote before trusting anything else.
	TEST_ASSERT(gate.check_condition(controller), \
		"the exploring_room gate does not pass on the state this test wrote - \
		the BB_EXPLORING_ROOM key string in this file has drifted from voidcrew/modules/npc_ships/code/_defines.dm")

	var/stuck_on_hold = 0
	for(var/i in 1 to 20)
		pirate_test_tick(controller)
		if(controller.active_execution_index == hold.execution_index)
			stuck_on_hold++

	TEST_ASSERT(stuck_on_hold < 20, \
		"exploration_hold held the tree on all 20 ticks. A perform() that returns \
		AI_BEHAVIOR_INSTANT with no SUCCEEDED/FAILED bit is BT_RUNNING forever: the parallel \
		never finishes, the exploring_room decorator's child_active makes it skip its own \
		check_condition(), and the pirate never reaches the patrol step again.")
	TEST_ASSERT_NULL(controller.blackboard[PIRATE_TEST_BB_MOB_PATROL_TARGET], \
		"patrol claimed the tick while the exploration branch was still active - \
		exploration is meant to consume the tick, not fail out of it")

	// Release exploration and confirm the patrol step below it actually gets the tick.
	// Under the pre-fix latch the enclosing selector is pinned inside the exploration branch,
	// so clearing this key changes nothing and the patrol target is never published.
	controller.clear_blackboard_key(PIRATE_TEST_BB_EXPLORING_ROOM)
	for(var/i in 1 to 5)
		pirate_test_tick(controller)

	TEST_ASSERT_EQUAL(controller.blackboard[PIRATE_TEST_BB_MOB_PATROL_TARGET], patrol_door, \
		"the patrol step never ran after exploration ended - the tree is still pinned in the exploration branch")

	// MOVEMENT PROOF - deliberately skipped.
	// The strongest form of this test is assign_mob_to_patrol() against a real hull, record
	// the pawn's turf, tick ~100, and assert the turf changed. It is not run here: the unit
	// test environment is a bare 5x5 /area/misc/testroom on a fresh z-level with no
	// /obj/structure/overmap/ship, no SSovermap-loaded shuttle_areas and no door graph, so
	// generate_ship_patrol_path() returns null and assign_mob_to_patrol() refuses. Faking a
	// path would only re-test the synthetic path already exercised above while pretending to
	// prove locomotion, so the sub-assertion is left out rather than faked. Restore it if a
	// mapped NPC hull fixture is ever added to the test world.

	pirate_test_halt(controller)

// ==================== TEST 4 - the fatal #2 regression ====================

/**
 * A parallel that declares a success policy must declare a failure policy, and a failing
 * action branch must release the enclosing selector instead of pinning it.
 *
 * 2026-08 BT port, fatal #2 "parallel failure_policy omission". Structural half (a) reads
 * the COMPILED tree - the build/behavior_trees mirror of a .bt.json is what
 * /datum/ai_controller/load_tree_from_json() actually loads, so a .bt.json edit that was
 * never run through tools/build_bt.py would not show up in a source-only check.
 *
 * Behavioural half (b) reproduces the no-escape geometry the incident report identified:
 * the pawn exactly TWO tiles from its patrol door. At dist 2 the stuck timeout in
 * patrol_resolve_step declines (it needs current_dist > 2) and both door branches decline
 * (they need dist <= 1), so nothing rescues the mob except the tree replanning from the top
 * every tick. With failure_policy left at BT_PARALLEL_FAILURE_CHILD_ONE the resolve leaf
 * SUCCEEDS, the travel leaf FAILS, neither policy test matches, and the parallel reports
 * BT_RUNNING with nothing running - which pins the shared selector on child 3 and starves
 * the obstruction branch above it, the one branch that could open the door in front of them.
 */
/datum/unit_test/npc_pirate_patrol_falls_through_blocked_door

/datum/unit_test/npc_pirate_patrol_falls_through_blocked_door/Run()
	// (a) Structural: every parallel in the compiled shared tree that picks a success policy
	// must also pick a failure policy.
	var/shared_source = "voidcrew/modules/npc_ships/code/mob_patrol_shared.bt.json"
	var/shared_compiled = BT_COMPILED_PATH(shared_source)
	TEST_ASSERT(fexists(shared_compiled), \
		"[shared_compiled] does not exist - the shared patrol tree was never compiled. \
		Run tools/build_bt.py; the game loads the compiled JSON, not the .bt.json.")

	var/list/policy_problems = list()
	pirate_test_check_policies(json_decode(file2text(file(shared_compiled))), shared_compiled, policy_problems)
	TEST_ASSERT(!length(policy_problems), \
		"mob_patrol_shared declares success_policy without failure_policy: [policy_problems.Join("; ")]. \
		BT_PARALLEL_SUCCESS_ALL with the default BT_PARALLEL_FAILURE_CHILD_ONE returns BT_RUNNING \
		with nothing running whenever child 1 succeeds and a later child fails.")

	// (b) Behavioural, at exactly dist 2.
	var/mob/living/basic/trooper/pirate/faction/silverscale/melee/pirate = allocate(PIRATE_TEST_MELEE_TYPE)
	var/turf/pirate_turf = get_turf(pirate)
	TEST_ASSERT_NOTNULL(pirate_turf, "the test pirate was allocated without a turf")

	var/datum/ai_controller/controller = new /datum/ai_controller/basic_controller/trooper/patrolling(pirate)
	TEST_ASSERT(LAZYLEN(controller.behavior_nodes), "the patrolling controller built no behavior_nodes")

	var/datum/bt_node/subtree/shared = pirate_test_find_bt_node(controller, /datum/bt_node/subtree/mob_patrol_shared)
	TEST_ASSERT_NOTNULL(shared, "mob_patrol_shared is not in the built melee patrol tree")
	var/datum/bt_node/composite/selector/shared_root = shared.root
	TEST_ASSERT(istype(shared_root), "the mob_patrol_shared root is [shared.root?.type || "null"], expected a selector")

	var/datum/bt_node/ai_behavior/move_to_target/travel = pirate_test_find_bt_node(controller, /datum/bt_node/ai_behavior/move_to_target/patrol_travel)
	TEST_ASSERT_NOTNULL(travel, "patrol_travel is not in the built melee patrol tree")

	var/turf/blocked_turf = get_step(get_step(pirate_turf, EAST), EAST)
	TEST_ASSERT_NOTNULL(blocked_turf, "the test room is too small to place a patrol door two tiles east")
	var/obj/machinery/door/airlock/blocked_door = allocate(/obj/machinery/door/airlock, blocked_turf)
	TEST_ASSERT(blocked_door.density, "the test patrol door spawned already open")
	TEST_ASSERT_EQUAL(get_dist(pirate, blocked_door), 2, "the no-escape geometry needs the pawn exactly 2 tiles from the door")

	controller.blackboard[PIRATE_TEST_BB_MOB_PATROL_PATH] = list(blocked_door)
	controller.blackboard[PIRATE_TEST_BB_MOB_PATROL_INDEX] = 1

	pirate_test_tick(controller)
	TEST_ASSERT_EQUAL(controller.blackboard[PIRATE_TEST_BB_PATROL_STEP], PIRATE_TEST_PATROL_STEP_TRAVEL, \
		"patrol_resolve_step did not pick TRAVEL at dist 2 - the rest of this test is not \
		exercising the resolve-SUCCEEDS/action-FAILS combination it is meant to")

	// Simulate JPS giving up (max_pathing_attempts exhausted against a shut door) on every
	// tick. move_to_target/finish_action clears movement_failed, so it has to be re-armed.
	var/pinned_ticks = 0
	for(var/i in 1 to 10)
		travel.movement_failed = TRUE
		pirate_test_tick(controller)
		if(shared_root.running_child_index)
			pinned_ticks++

	TEST_ASSERT(pinned_ticks < 10, \
		"the shared patrol selector stayed pinned on the patrol parallel for all 10 ticks \
		while the travel leaf was failing. That is the failure_policy omission: with \
		BT_PARALLEL_FAILURE_CHILD_ONE the parallel answers BT_RUNNING for a resolve-SUCCEEDS / \
		action-FAILS tick, and a selector that resumes at running_child_index never revisits \
		any sibling - including the obstruction branch above it.")

	// The starved branch, made concrete: put a shut door directly in front of the pawn, in
	// the direction of travel, and it must be seen. patrol_obstruction_nearby is child 1 of
	// the shared selector, so it is only reachable if the selector was released. Its
	// BT_ABORT_LOWER_PRIORITY observer cannot mask the result here: it polls at 1 SECONDS and
	// world.time does not advance across these synchronous ticks.
	// Re-pin the geometry first. Nothing should have moved the pawn - a JPS moveloop needs
	// world.time to advance and it does not across these synchronous ticks - but the
	// assertion below depends on the door being between the pawn and its patrol target, so
	// make that explicit rather than assume it.
	pirate.forceMove(pirate_turf)
	var/turf/adjacent_turf = get_step(pirate_turf, EAST)
	TEST_ASSERT_NOTNULL(adjacent_turf, "no turf east of the pawn to put a blocking door on")
	allocate(/obj/machinery/door/airlock, adjacent_turf)

	travel.movement_failed = TRUE
	pirate_test_tick(controller)
	TEST_ASSERT_NOTNULL(controller.blackboard[PIRATE_TEST_BB_PATROL_OBSTRUCTION], \
		"the obstruction branch never ran with a shut door directly in the pawn's path - \
		the higher-priority branch is starved by the pinned patrol parallel")

	pirate_test_halt(controller)

/**
 * Walks a decoded BT descriptor and records every PARALLEL that declares success_policy
 * without declaring failure_policy. Shared by TEST 4(a) and TEST 6.
 *
 * Scoped to parallels on purpose. A subplan's defaults pair up safely (LOOP_ON_SUCCESS with
 * FAIL_ON_FAILURE still terminates), whereas a parallel's do not: SUCCESS_ALL with the
 * default FAILURE_CHILD_ONE leaves the child-1-succeeds / child-2-fails combination matching
 * neither test, which is BT_RUNNING with nothing running. Matches both the compiled type
 * string ("/datum/bt_node/composite/parallel") and the source shorthand ("parallel").
 */
/proc/pirate_test_check_policies(list/node, node_path, list/problems)
	if(!islist(node))
		return
	var/node_type_text = node["type"]
	if(istext(node_type_text) && findtext(node_type_text, "parallel") \
			&& !isnull(node["success_policy"]) && isnull(node["failure_policy"]))
		problems += "[node_path] ([node_type_text])"
	var/list/children = node["children"]
	if(islist(children))
		for(var/i in 1 to length(children))
			pirate_test_check_policies(children[i], "[node_path]/children\[[i]\]", problems)
	var/list/single_child = node["child"]
	if(islist(single_child))
		pirate_test_check_policies(single_child, "[node_path]/child", problems)

// ==================== TEST 5 - target acquisition and engagement ====================

/**
 * A pirate acquires a hostile beyond arm's reach and actually swings at it, both from a clean
 * plan and from inside an active exploration branch.
 *
 * 2026-08 BT port. Upstream #97208 inserted priority_strategy into should_keep_target()
 * mid-list and appended resolved_vision_range; the fork's two overrides kept the old
 * three-argument list, so DM bound priority_strategy positionally into current_target. Today
 * that misbinds to null and makes should_keep_target() always answer FALSE (a wasted rescan
 * every tick, fork keep/drop rules dead), but the moment anything sets
 * BB_TARGET_PRIORITY_STRATEGY it answers TRUE unconditionally and the target key is never
 * written at all.
 *
 * The dist-2 acquisition is also the guard for the incident report's 7e caveat: the old
 * finder called can_attack(pawn, target) with no vision_range, so can_see(..., null) made
 * dist > 0 fail and it effectively only ever acquired same-turf targets.
 *
 * PREEMPTION - the open question from the report's section 9, answered here.
 * Combat DOES preempt an exploration hold, and it does so by construction rather than by
 * luck. Two independent mechanisms, both exercised by the second half of this test:
 *   1. acquire_target is child 2 of the tree's outer parallel with finish_on_primary, and a
 *      parallel ticks ALL of its children before it evaluates any policy, so the target scan
 *      runs even on a tick the patrol/exploration half is holding.
 *   2. The combat branch is gated by /datum/bt_node/decorator/bb_key_set on BB_CURRENT_TARGET
 *      with observer_abort BT_ABORT_BOTH, and bb_key_set registers real signals
 *      (COMSIG_AI_BLACKBOARD_KEY_SET / _CLEARED) rather than polling. Writing the target key
 *      fires on_observed_change() -> the BT_ABORT_LOWER_PRIORITY arm -> cancel_current_plan(),
 *      which resets every running_child_index in the tree. The next tick therefore restarts
 *      at child 1 and the combat branch wins.
 * Mechanism 2 is what made "doesn't attack" survivable even under the pre-fix latch, and it
 * is why fatal #1 presented as "pirates stand still" rather than "pirates ignore you".
 */
/datum/unit_test/npc_pirate_engages_target

/datum/unit_test/npc_pirate_engages_target/Run()
	pirate_test_engagement_run(src, FALSE)

/**
 * Second run of TEST 5: identical, except the pirate is already inside an active exploration
 * branch when the victim appears. See the preemption note on
 * /datum/unit_test/npc_pirate_engages_target for what this answers.
 *
 * A separate unit test rather than a second pass inside one Run(), so it gets its own
 * allocated list and a cleared test room. Sharing a room would leave the first run's human
 * standing next to the second run's pirate, and the fork's finder always takes the CLOSEST
 * candidate - the second run would "acquire" the first run's leftovers.
 */
/datum/unit_test/npc_pirate_engages_target_while_exploring

/datum/unit_test/npc_pirate_engages_target_while_exploring/Run()
	pirate_test_engagement_run(src, TRUE)

/// Body of TEST 5, run once clean and once with exploration already owning the tick.
/proc/pirate_test_engagement_run(datum/unit_test/test, pre_explore)
	var/label = pre_explore ? "pre-latched in exploration" : "clean plan"

	var/mob/living/basic/trooper/pirate/faction/silverscale/melee/pirate = test.allocate(PIRATE_TEST_MELEE_TYPE)
	var/turf/pirate_turf = get_turf(pirate)
	if(isnull(pirate_turf))
		return test.Fail("[label]: the test pirate was allocated without a turf", __FILE__, __LINE__)

	var/datum/ai_controller/controller = new /datum/ai_controller/basic_controller/trooper/patrolling(pirate)
	if(!LAZYLEN(controller.behavior_nodes))
		return test.Fail("[label]: the patrolling controller built no behavior_nodes", __FILE__, __LINE__)

	if(pre_explore)
		var/list/exploration_targets = list()
		for(var/i in 1 to 40)
			exploration_targets += pirate_turf
		controller.set_blackboard_key(PIRATE_TEST_BB_EXPLORING_ROOM, "unit_test_room")
		controller.set_blackboard_key(PIRATE_TEST_BB_EXPLORATION_TARGETS, exploration_targets)
		controller.set_blackboard_key(PIRATE_TEST_BB_EXPLORATION_INDEX, 1)
		// Let exploration take the tick before anyone hostile turns up.
		for(var/i in 1 to 5)
			pirate_test_tick(controller)
		if(!controller.blackboard[PIRATE_TEST_BB_EXPLORING_ROOM])
			pirate_test_halt(controller)
			return test.Fail("[label]: exploration ended before the victim was introduced", __FILE__, __LINE__)

	// Two tiles east: inside the fork finder's range() of 9, well outside melee reach.
	var/turf/victim_turf = get_step(get_step(pirate_turf, EAST), EAST)
	if(isnull(victim_turf))
		pirate_test_halt(controller)
		return test.Fail("[label]: the test room is too small to place a victim two tiles east", __FILE__, __LINE__)
	var/mob/living/carbon/human/consistent/victim = test.allocate(/mob/living/carbon/human/consistent, victim_turf)

	var/datum/targeting_strategy/strategy = GET_TARGETING_STRATEGY(controller.blackboard[BB_TARGETING_STRATEGY])
	if(isnull(strategy))
		pirate_test_halt(controller)
		return test.Fail("[label]: the trooper controller has no resolvable BB_TARGETING_STRATEGY", __FILE__, __LINE__)
	if(!strategy.is_valid_target(pirate, victim, 9, controller))
		pirate_test_halt(controller)
		return test.Fail("[label]: [strategy.type] does not consider a human a valid target for a pirate - \
			the factions are not hostile and the rest of this test proves nothing", __FILE__, __LINE__)

	var/acquired = FALSE
	for(var/i in 1 to 30)
		pirate_test_tick(controller)
		if(controller.blackboard[BB_CURRENT_TARGET] == victim)
			acquired = TRUE
			break

	if(!acquired)
		var/found = controller.blackboard[BB_CURRENT_TARGET]
		pirate_test_halt(controller)
		return test.Fail("[label]: the pirate never took the human two tiles away as its target \
			(BB_CURRENT_TARGET = [found || "null"]). Check the acquire_target overrides in \
			mob_patrol.dm against the current parent signatures - a positional misbind of \
			priority_strategy into current_target makes should_keep_target() short-circuit.", __FILE__, __LINE__)

	// The signature-drift landmine, made observable. With BB_TARGET_PRIORITY_STRATEGY unset
	// (the shipped configuration) a mis-ordered should_keep_target() override binds null into
	// current_target, answers FALSE, and merely wastes a rescan - the target still gets
	// written, so the loop above cannot see the defect. Put a strategy in the key and the same
	// misbinding lands a DATUM in current_target: not QDELETED, not living, so the fork
	// override falls through to its "non-mob target, keep it" branch and returns TRUE.
	// acquire_target then reports SUCCEEDED without ever calling find_and_set_target() and the
	// target key is never written at all. That is the fatal form of upstream #97208, and this
	// is the only assertion here that can see it.
	controller.clear_blackboard_key(BB_CURRENT_TARGET)
	controller.set_blackboard_key(BB_TARGET_PRIORITY_STRATEGY, /datum/target_priority_strategy/nearest)
	var/reacquired = FALSE
	for(var/i in 1 to 10)
		pirate_test_tick(controller)
		if(controller.blackboard[BB_CURRENT_TARGET] == victim)
			reacquired = TRUE
			break
	controller.clear_blackboard_key(BB_TARGET_PRIORITY_STRATEGY)
	if(!reacquired)
		pirate_test_halt(controller)
		return test.Fail("[label]: with BB_TARGET_PRIORITY_STRATEGY set the pirate stopped \
			acquiring targets entirely. The acquire_target overrides in mob_patrol.dm are \
			binding positionally against the wrong parent signature - should_keep_target() is \
			receiving the priority strategy where it expects current_target and short-circuiting \
			to TRUE, so find_and_set_target() never runs.", __FILE__, __LINE__)

	// Engagement. Step the victim into reach and clear the melee cooldown gate, which keys off
	// world.time and therefore never expires across synchronous ticks. Read the pawn's turf
	// again rather than reusing the pre-acquisition one - a move_to_target leaf has been
	// running since the target was set.
	var/turf/pirate_now = get_turf(pirate)
	var/turf/reach_turf = get_step(pirate_now, EAST)
	if(isnull(reach_turf) || reach_turf.density)
		reach_turf = pirate_now
	victim.forceMove(reach_turf)
	controller.set_blackboard_key(BB_BASIC_MOB_MELEE_COOLDOWN_TIMER, world.time - 1)
	var/health_before = victim.health
	for(var/i in 1 to 10)
		controller.set_blackboard_key(BB_BASIC_MOB_MELEE_COOLDOWN_TIMER, world.time - 1)
		pirate_test_tick(controller)
	// basic_melee_attack dispatches the swing with INVOKE_ASYNC, so it lands after this proc
	// yields rather than inside the tick loop.
	sleep(1)

	var/engaged = victim.health < health_before || pirate.next_move > world.time
	pirate_test_halt(controller)
	if(!engaged)
		return test.Fail("[label]: the pirate held its target adjacent for 10 ticks without \
			swinging - it acquires but does not engage", __FILE__, __LINE__)

// ==================== TEST 6 - behavior tree JSON integrity ====================

/**
 * Every fork behavior tree resolves, configures and compiles cleanly.
 *
 * 2026-08 BT port. Four contracts, all of which the port broke or nearly broke:
 *   1. every dm_type / behavior / decorator / subtype string resolves to a real typepath;
 *   2. every var key written into a node exists on that node's type - build_node_from_descriptor()
 *      assigns them blind via node.vars[key], and an unknown key is a runtime that aborts
 *      tree construction and leaves the mob inert;
 *   3. every enum and define compiled to a NUMBER, not the literal string - tools/build_bt.py
 *      emits unresolvable defines as literal text silently, and "BT_PARALLEL_FAILURE_ANY" as
 *      a string is not 1;
 *   4. any parallel that declares success_policy also declares failure_policy - fatal #2
 *      exactly.
 *
 * Scope is derived from the code rather than hardcoded: every behavior_tree_json declared by
 * an /datum/ai_controller or /datum/bt_node/subtree under voidcrew/. That automatically
 * includes npc_ship_combat.bt.json and npc_ship_movement.bt.json, which the incident report
 * called out as carrying the identical policy set and never having been checked.
 */
/datum/unit_test/npc_pirate_behavior_tree_json_integrity

/datum/unit_test/npc_pirate_behavior_tree_json_integrity/Run()
	var/list/tree_paths = list()
	for(var/datum/ai_controller/controller_type as anything in subtypesof(/datum/ai_controller))
		var/json_path = initial(controller_type.behavior_tree_json)
		if(json_path && json_path != ABSTRACT_AI_CLASS && findtext(json_path, "voidcrew/") == 1)
			tree_paths |= json_path
	for(var/datum/bt_node/subtree/subtree_type as anything in subtypesof(/datum/bt_node/subtree))
		var/json_path = initial(subtree_type.behavior_tree_json)
		if(json_path && findtext(json_path, "voidcrew/") == 1)
			tree_paths |= json_path

	TEST_ASSERT(length(tree_paths) >= 6, "found only [length(tree_paths)] fork behavior trees - the scope query is broken")
	TEST_ASSERT(("voidcrew/modules/npc_ships/code/subtrees/npc_ship_combat.bt.json" in tree_paths), \
		"npc_ship_combat.bt.json is not reachable from any subtree declaration")
	TEST_ASSERT(("voidcrew/modules/npc_ships/code/subtrees/npc_ship_movement.bt.json" in tree_paths), \
		"npc_ship_movement.bt.json is not reachable from any subtree declaration")

	var/list/problems = list()
	var/list/policy_problems = list()

	for(var/json_path in tree_paths)
		TEST_ASSERT(fexists(json_path), "[json_path] is declared by a live type but does not exist on disk")
		var/compiled_path = BT_COMPILED_PATH(json_path)
		TEST_ASSERT(fexists(compiled_path), \
			"[compiled_path] does not exist. The game loads the compiled tree, so [json_path] is \
			currently inert - run tools/build_bt.py and commit the compiled JSON with the source.")

		// Contract 1 on the source, which is where the human-authored typepath strings live.
		pirate_test_check_source_types(json_decode(file2text(file(json_path))), json_path, problems)
		// Contracts 1-3 on the compiled tree, which is what the engine actually consumes.
		pirate_test_check_compiled(json_decode(file2text(file(compiled_path))), compiled_path, problems)
		// Contract 4, kept separate so the ship trees can be reported without failing the run.
		pirate_test_check_policies(json_decode(file2text(file(compiled_path))), compiled_path, policy_problems)

	TEST_ASSERT(!length(problems), "fork behavior tree defects:\n[problems.Join("\n")]")

	// Contract 4. The patrol trees are the regression under test and are asserted hard.
	var/list/patrol_policy_problems = list()
	var/list/ship_policy_problems = list()
	for(var/problem in policy_problems)
		if(findtext(problem, "mob_patrol"))
			patrol_policy_problems += problem
		else
			ship_policy_problems += problem

	TEST_ASSERT(!length(patrol_policy_problems), \
		"a patrol-tree parallel declares success_policy without failure_policy - this is the \
		2026-08 fatal #2 shape returning:\n[patrol_policy_problems.Join("\n")]")

	// Promoted from TEST_NOTICE to TEST_ASSERT 2026-08-27: the 4 npc_ship_movement parallels
	// and the npc_ship_controller root now declare failure_policy = BT_PARALLEL_FAILURE_ANY
	// (same fix as the mob patrol trees; a FAILED child now falls through instead of pinning
	// the enclosing selector - the latent frozen-ship shape when a dispatch mode had no
	// matching branch, e.g. NPC_MOVEMENT_RETREAT reaching the dispatch selector).
	TEST_ASSERT(!length(ship_policy_problems), \
		"an NPC ship-tree parallel declares success_policy without failure_policy - the \
		2026-08 fatal #2 shape (frozen ship when any child fails):\n[ship_policy_problems.Join("\n")]")

/// Contract 1 against a source .bt.json: the human-authored typepath strings must resolve.
/proc/pirate_test_check_source_types(list/node, node_path, list/problems)
	if(!islist(node))
		return
	for(var/key in list("dm_type", "behavior", "decorator", "subtype"))
		var/raw = node[key]
		if(isnull(raw) || !istext(raw))
			continue
		if(isnull(text2path(raw)))
			problems += "[node_path]: \"[key]\": \"[raw]\" does not resolve to a typepath"
	var/list/children = node["children"]
	if(islist(children))
		for(var/i in 1 to length(children))
			pirate_test_check_source_types(children[i], "[node_path]/children\[[i]\]", problems)
	var/list/single_child = node["child"]
	if(islist(single_child))
		pirate_test_check_source_types(single_child, "[node_path]/child", problems)

/// Contracts 1-3 against a compiled .bt.compiled.json - the descriptor the engine consumes.
/proc/pirate_test_check_compiled(list/node, node_path, list/problems)
	if(!islist(node))
		return
	var/raw_type = node[BT_DESC_TYPE]
	if(!istext(raw_type))
		problems += "[node_path]: compiled node has no \"[BT_DESC_TYPE]\" string"
		return
	var/node_type = text2path(raw_type)
	if(isnull(node_type) || !ispath(node_type, /datum/bt_node))
		problems += "[node_path]: \"[raw_type]\" does not resolve to a /datum/bt_node typepath"
		return

	// build_node_from_descriptor() writes every remaining key straight into node.vars, so an
	// unknown key is a runtime that aborts tree construction.
	var/datum/bt_node/probe = new node_type
	for(var/key in node)
		if(key == BT_DESC_TYPE || key == BT_DESC_CHILDREN || key == BT_DESC_BINDINGS)
			continue
		if(!(key in probe.vars))
			problems += "[node_path]: \"[key]\" is not a var on [raw_type]"
			continue
		if(key in GLOB.pirate_test_numeric_bt_keys)
			var/value = node[key]
			if(!isnum(value))
				problems += "[node_path]: \"[key]\" compiled to [istext(value) ? "the literal string \"[value]\"" : "[value]"] \
					instead of a number - tools/build_bt.py could not resolve that define and emitted it verbatim"
	qdel(probe)

	var/list/children = node[BT_DESC_CHILDREN]
	if(islist(children))
		for(var/i in 1 to length(children))
			pirate_test_check_compiled(children[i], "[node_path]/children\[[i]\]", problems)

/// Compiled-JSON keys that must hold a resolved number rather than an unresolved define name.
GLOBAL_LIST_INIT(pirate_test_numeric_bt_keys, list(
	"success_policy",
	"failure_policy",
	"observer_abort",
	"repeat_secondary_delay",
	"time_between_perform",
	"max_range",
	"required_dist",
	"vision_range",
	"loop_delay",
	"polling_rate",
	"target_loss_distance",
))

#undef PIRATE_TEST_BB_EXPLORING_ROOM
#undef PIRATE_TEST_BB_EXPLORATION_TARGETS
#undef PIRATE_TEST_BB_EXPLORATION_INDEX
#undef PIRATE_TEST_BB_MOB_PATROL_PATH
#undef PIRATE_TEST_BB_MOB_PATROL_INDEX
#undef PIRATE_TEST_BB_MOB_PATROL_TARGET
#undef PIRATE_TEST_BB_PATROL_STEP
#undef PIRATE_TEST_BB_PATROL_OBSTRUCTION
#undef PIRATE_TEST_PATROL_STEP_TRAVEL
#undef PIRATE_TEST_MELEE_TYPE
