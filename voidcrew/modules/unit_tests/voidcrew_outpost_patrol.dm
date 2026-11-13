/**
 * Outpost patrols (voidcrew/modules/npc_ships/code/outpost_patrol.dm): the boarding patrol pointed at
 * a player outpost, the breakout controller escaped prisoners run, and the ship patrol it came from.
 *
 * Voidcrew defines are not visible from test files, so blackboard keys appear as their literal
 * strings. The patrol runs on a player outpost (upgrade_test_claim(), voidcrew_outpost_upgrades.dm);
 * the breakout controller's own test uses the prison fixtures (prison_test_claim(), prison_spot()) in
 * voidcrew_outpost_prison_helpers.dm.
 */

// ===== PATH =====

/datum/unit_test/voidcrew_outpost_patrol_path
	parent_type = /datum/unit_test/voidcrew_outpost_management

/datum/unit_test/voidcrew_outpost_patrol_path/Run()
	var/obj/structure/overmap/dynamic/player_outpost/home = upgrade_test_claim("patrolpathowner")
	TEST_ASSERT_NOTNULL(home, "The patrol test outpost did not load")
	var/key = REF(home)
	var/level_z = home.upgrade_level_z()

	// Doors built in the shell, for the patrol to visit
	var/list/door_spots = list()
	for(var/turf/open/floor/candidate in home.outpost_area.get_turfs_by_zlevel(level_z))
		if(clear_floor(candidate, home) && clear_floor(get_step(candidate, NORTH), home) && clear_floor(get_step(candidate, SOUTH), home) \
			&& clear_floor(get_step(candidate, EAST), home) && clear_floor(get_step(candidate, WEST), home))
			door_spots += candidate
	TEST_ASSERT(length(door_spots) >= 2, "Not enough open floor in the shell to build two doors on")
	var/turf/open/floor/kept_spot = door_spots[1]
	var/turf/open/floor/door_spot
	for(var/turf/open/floor/candidate as anything in door_spots)
		if(get_dist(candidate, kept_spot) > 2)
			door_spot = candidate
			break
	TEST_ASSERT_NOTNULL(door_spot, "No second spot in the shell for a door, clear of the first")
	var/obj/machinery/door/airlock/kept_door = allocate(/obj/machinery/door/airlock, kept_spot)
	var/list/path = get_outpost_patrol_path(home, TRUE)
	TEST_ASSERT(kept_door in path, "A door built in the outpost is not on the patrol path")

	// Left out: the shell's external airlock
	var/external_count = 0
	for(var/turf/shell_turf as anything in home.outpost_area.get_turfs_by_zlevel(level_z))
		for(var/obj/machinery/door/airlock/external/outer in shell_turf)
			external_count++
			TEST_ASSERT(!(outer in path), "The shell's external airlock is on the patrol path")
	TEST_ASSERT(external_count, "The compact shell has no external airlock to leave out")
	for(var/obj/machinery/door/door as anything in path)
		TEST_ASSERT_EQUAL(door.z, level_z, "A patrol door is off the outpost's main level")

	// Cached, and changed only in place
	TEST_ASSERT(get_outpost_patrol_path(home) == path, "The cached patrol path was not reused")
	var/obj/machinery/door/airlock/built_door = new(door_spot)
	TEST_ASSERT(get_outpost_patrol_path(home, TRUE) == path, "Rebuilding replaced the shared path list")
	TEST_ASSERT(built_door in path, "A door built in the outpost was not added to the patrol")
	qdel(built_door)
	TEST_ASSERT(!(built_door in path), "A deleted door stayed on the patrol path")
	for(var/room_id in GLOB.ship_rooms[key])
		TEST_ASSERT(!(built_door in GLOB.ship_rooms[key][room_id]["doors"]), "A deleted door stayed in [room_id]'s doors")
	TEST_ASSERT(get_outpost_patrol_path(home) == path, "Rebuilding after a deletion replaced the shared path list")
	TEST_ASSERT(!(null in path), "The rebuild after a door was deleted left a gap in the path")
	TEST_ASSERT(kept_door in path, "The rebuild after a door was deleted lost the other door")

	// Assigning a pawn by hand, and clearing every key again
	var/turf/pawn_spot = get_step(kept_spot, EAST)
	var/mob/living/basic/trooper/runner = allocate(/mob/living/basic/trooper, pawn_spot)
	var/datum/ai_controller/controller = swap_basic_ai_controller(runner, /datum/ai_controller/basic_controller/outpost_breakout)
	TEST_ASSERT_NOTNULL(controller, "The breakout controller could not take a trooper")
	TEST_ASSERT(assign_mob_to_outpost_patrol(runner, home), "A pawn in the outpost was not given the patrol")
	TEST_ASSERT(controller.blackboard["mob_patrol_path"] == path, "The patroller does not share the outpost's path")
	TEST_ASSERT_EQUAL(controller.blackboard["mob_patrol_ship_ref"], key, "The patrol is not keyed to the outpost")
	var/start_index = controller.blackboard["mob_patrol_index"]
	TEST_ASSERT(start_index >= 1 && start_index <= length(path), "The patrol starts at index [start_index] of [length(path)]")
	var/pawn_room = get_room_for_turf(pawn_spot, key)
	TEST_ASSERT_NOTNULL(pawn_room, "The pawn's tile is in no room of the outpost")
	TEST_ASSERT_EQUAL(controller.blackboard["_last_known_room"], pawn_room, "The patrol did not start in the pawn's room")
	TEST_ASSERT_EQUAL(outpost_patrol_of(runner), home, "outpost_patrol_of() did not find the outpost")
	// Mid-patrol state from the door handling
	controller.set_blackboard_key("_blocking_door_to_attack", kept_door)
	controller.blackboard["_patrol_door_start_time"] = world.time
	controller.blackboard["_skipped_blocking_doors"] = list(REF(kept_door) = TRUE)
	controller.blackboard["_blocking_door_attack_times"] = list(REF(kept_door) = world.time)
	TEST_ASSERT(clear_outpost_patrol(runner), "clear_outpost_patrol() refused a patroller")
	for(var/bb_key in outpost_patrol_blackboard_keys())
		TEST_ASSERT_NULL(controller.blackboard[bb_key], "clear_outpost_patrol() left [bb_key] set")
	for(var/bb_key in list("mob_patrol_path", "mob_patrol_index", "mob_patrol_target", "mob_patrol_ship_ref", "_last_known_room", \
		"_exploring_room", "_exploration_targets", "_exploration_index", "_blocking_door_to_attack", "_patrol_door_start_time", \
		"_skipped_blocking_doors", "_blocking_door_attack_times", "_failed_blocking_doors"))
		TEST_ASSERT_NULL(controller.blackboard[bb_key], "clear_outpost_patrol() left [bb_key] set")
	TEST_ASSERT_NULL(outpost_patrol_of(runner), "A cleared pawn still reports a patrol")
	TEST_ASSERT(length(path), "Clearing one patroller emptied the shared path")

	// Deleting the cache (as the outpost's deletion does) empties the shared tables
	var/datum/outpost_patrol_cache/cache = GLOB.outpost_patrol_caches[key]
	TEST_ASSERT_NOTNULL(cache, "The outpost has no patrol cache")
	qdel(cache)
	TEST_ASSERT_NULL(GLOB.outpost_patrol_caches[key], "A deleted cache stayed registered")
	TEST_ASSERT_NULL(GLOB.ship_rooms[key], "A deleted cache left its rooms behind")
	TEST_ASSERT_NULL(GLOB.turf_to_room[key], "A deleted cache left its turf table behind")
	TEST_ASSERT(!length(path), "A deleted cache left doors in the shared path")

/// Open floor of the outpost with nothing standing on it
/datum/unit_test/voidcrew_outpost_patrol_path/proc/clear_floor(turf/tile, obj/structure/overmap/dynamic/player_outpost/home)
	if(!isfloorturf(tile) || tile.loc != home.outpost_area || tile == home.arrival_turf)
		return FALSE
	for(var/atom/movable/thing as anything in tile)
		if(thing.density || istype(thing, /obj/machinery) || istype(thing, /obj/structure))
			return FALSE
	return TRUE

// ===== BREAKOUT AI =====

/datum/unit_test/voidcrew_outpost_patrol_breakout
	parent_type = /datum/unit_test/voidcrew_outpost_management
	/// Everything the escaped prisoner swung at
	var/list/swung_at = list()
	/// Stands in for a player on the level, so the AI runs
	var/mob/living/carbon/human/watcher
	var/watched_z

/datum/unit_test/voidcrew_outpost_patrol_breakout/Destroy()
	if(watcher && watched_z)
		SSmobs.clients_by_zlevel[watched_z] -= watcher
	watcher = null
	swung_at = null
	return ..()

/datum/unit_test/voidcrew_outpost_patrol_breakout/proc/on_swing(datum/source, atom/target)
	SIGNAL_HANDLER
	swung_at += target

/datum/unit_test/voidcrew_outpost_patrol_breakout/proc/has_swung_at(atom/target)
	return target in swung_at

/// Where the walker is on the wing's own map coordinates, and what its AI is doing, for failure messages
/datum/unit_test/voidcrew_outpost_patrol_breakout/proc/describe_walker(obj/structure/overmap/trader_outpost/prison_test_host/home, mob/living/walker)
	var/list/bounds = list(home.wing_corner.x, home.wing_corner.y)
	var/datum/ai_controller/controller = walker.ai_controller
	var/list/doing = list()
	for(var/datum/ai_behavior/behavior as anything in controller.current_behaviors)
		doing += "[behavior.type]"
	var/atom/moving_to = controller.current_movement_target
	var/obj/machinery/door/target_door = controller.blackboard["mob_patrol_target"]
	var/list/parts = list()
	parts += "([walker.x - bounds[1] + 1],[walker.y - bounds[2] + 1]) status [controller.ai_status] index [controller.blackboard["mob_patrol_index"]]"
	parts += "door [target_door ? "[target_door.x - bounds[1] + 1],[target_door.y - bounds[2] + 1]" : "none"]"
	parts += "exploring [controller.blackboard["_exploring_room"]] #[controller.blackboard["_exploration_index"]]/[length(controller.blackboard["_exploration_targets"])]"
	parts += "moving to [moving_to ? "[moving_to.x - bounds[1] + 1],[moving_to.y - bounds[2] + 1]" : "nothing"]"
	parts += "doing [jointext(doing, ",")] target [controller.blackboard[BB_BASIC_MOB_CURRENT_TARGET]]"
	return jointext(parts, " ")

/datum/unit_test/voidcrew_outpost_patrol_breakout/Run()
	var/obj/structure/overmap/trader_outpost/prison_test_host/home = prison_test_claim("breakoutowner")
	TEST_ASSERT_NOTNULL(home, "The breakout test prison did not load")
	var/turf/start = prison_spot(home, 9, 8)
	var/mob/living/carbon/human/npc/outpost_prisoner/walker = allocate(/mob/living/carbon/human/npc/outpost_prisoner, start)
	var/mob/living/carbon/human/npc/outpost_prisoner/inmate = allocate(/mob/living/carbon/human/npc/outpost_prisoner, prison_spot(home, 8, 8))
	var/mob/living/basic/trooper/other_escapee = allocate(/mob/living/basic/trooper, prison_spot(home, 10, 8))
	TEST_ASSERT_NOTNULL(swap_basic_ai_controller(other_escapee, /datum/ai_controller/basic_controller/outpost_breakout), "The breakout controller could not take a trooper")

	// Swapping a live prisoner's controller
	var/datum/ai_controller/routine = walker.ai_controller
	var/datum/ai_controller/controller = swap_basic_ai_controller(walker, /datum/ai_controller/basic_controller/outpost_breakout)
	TEST_ASSERT(istype(controller, /datum/ai_controller/basic_controller/outpost_breakout), "The prisoner did not take the breakout controller")
	TEST_ASSERT_EQUAL(walker.ai_controller, controller, "The prisoner is not run by the new controller")
	TEST_ASSERT(QDELETED(routine), "The prisoner's routine controller outlived the swap")
	TEST_ASSERT_EQUAL(swap_basic_ai_controller(walker, /datum/ai_controller/basic_controller/outpost_breakout), controller, "Swapping to the same controller type replaced it")
	// Running, as anyone loose does (go_loose()): on walk intent tg lets nobody push or swap past a person in the way
	walker.set_prison_pace(hurry = TRUE)
	// A real human body swings through its own hands: tg's unarmed attack
	RegisterSignal(walker, COMSIG_LIVING_UNARMED_ATTACK, PROC_REF(on_swing))

	// Targeting: people and pets, never prisoners or anyone else breaking out
	var/datum/targeting_strategy/strategy = GET_TARGETING_STRATEGY(controller.blackboard[BB_TARGETING_STRATEGY])
	TEST_ASSERT_NOTNULL(strategy, "The breakout controller has no targeting strategy")
	var/mob/living/carbon/human/consistent/guard = allocate(/mob/living/carbon/human/consistent, prison_spot(home, 9, 10))
	var/mob/living/basic/pet/dog/corgi/pet = allocate(/mob/living/basic/pet/dog/corgi, prison_spot(home, 11, 10))
	TEST_ASSERT(strategy.can_attack(walker, guard), "An escaped prisoner would not attack a person")
	TEST_ASSERT(strategy.can_attack(walker, pet), "An escaped prisoner would not attack a pet")
	TEST_ASSERT(!strategy.can_attack(walker, inmate), "An escaped prisoner would attack a prisoner")
	TEST_ASSERT(!strategy.can_attack(walker, other_escapee), "An escaped prisoner would attack someone else breaking out")
	guard.forceMove(run_loc_floor_bottom_left)
	pet.forceMove(run_loc_floor_bottom_left)
	var/datum/ai_planning_subtree/aggressive_find_target/finder = GLOB.ai_subtrees[/datum/ai_planning_subtree/aggressive_find_target]
	finder.SelectBehaviors(controller, 1)
	TEST_ASSERT_NULL(controller.blackboard[BB_BASIC_MOB_CURRENT_TARGET], "With only prisoners about, an escaped prisoner picked a target")
	other_escapee.forceMove(run_loc_floor_bottom_left)

	// Someone in reach, with someone on the level, gets attacked. The lockup sits on no player
	// outpost, so there is no door patrol to walk first.
	watcher = allocate(/mob/living/carbon/human/consistent)
	watched_z = walker.z
	SSmobs.clients_by_zlevel[watched_z] |= watcher
	controller.reset_ai_status()
	TEST_ASSERT_EQUAL(controller.ai_status, AI_STATUS_ON, "The breakout AI did not wake with someone on the level")
	var/turf/guard_spot = prison_spot(home, 10, 8)
	TEST_ASSERT(!guard_spot.is_blocked_turf(), "The guard's spot beside the escaped prisoner is blocked")
	guard.forceMove(guard_spot)
	var/hit = wait_until(CALLBACK(src, PROC_REF(has_swung_at), guard), 20 SECONDS)
	TEST_ASSERT(hit, "The escaped prisoner never attacked a guard [get_dist(walker, guard)] tiles away: [describe_walker(home, walker)]")
	for(var/atom/target as anything in swung_at)
		TEST_ASSERT(!ismob(target) || !is_outpost_breakout_ally(target), "The escaped prisoner swung at [target], a prisoner or another escapee")
	TEST_ASSERT(!(inmate in swung_at), "The escaped prisoner swung at a prisoner")

	// Recaptured: back to the routine controller, with nothing of the breakout left
	SSmobs.clients_by_zlevel[watched_z] -= watcher
	watched_z = null
	var/datum/ai_controller/back = swap_basic_ai_controller(walker, /datum/ai_controller/basic_controller/outpost_prisoner)
	TEST_ASSERT(istype(back, /datum/ai_controller/basic_controller/outpost_prisoner), "The prisoner did not go back to the routine controller")
	TEST_ASSERT_EQUAL(walker.ai_controller, back, "The prisoner is not run by the routine controller again")
	TEST_ASSERT(QDELETED(controller), "The breakout controller outlived the swap back")
	TEST_ASSERT_NULL(back.blackboard["mob_patrol_path"], "The routine controller came back with a patrol path")
	TEST_ASSERT_NULL(back.blackboard[BB_BASIC_MOB_CURRENT_TARGET], "The routine controller came back with a target")
	TEST_ASSERT_NULL(outpost_patrol_of(walker), "A recaptured prisoner still reports a patrol")
	settle_prison_air(home)

// ===== SHIPS =====

/// The boarding patrol on a ship, built by hand: three rooms in a row joined by two airlocks
/datum/unit_test/voidcrew_ship_boarding_patrol
	var/datum/turf_reservation/fixture_block
	var/area/shuttle/voidcrew/ship_area
	/// turf = its area before the test
	var/list/original_areas = list()
	var/obj/docking_port/mobile/voidcrew/port
	var/obj/structure/overmap/ship/ship
	var/mob/living/basic/pirate
	var/list/built_doors = list()

/datum/unit_test/voidcrew_ship_boarding_patrol/Destroy()
	if(pirate?.ai_controller)
		clear_all_patrol_state(pirate.ai_controller)
	if(ship)
		clear_ship_patrol_path(ship)
		ship.shuttle = null
	if(!QDELETED(port))
		port.current_ship = null
		qdel(port, force = TRUE)
	QDEL_LIST(built_doors)
	for(var/turf/fixture_turf as anything in original_areas)
		fixture_turf.change_area(fixture_turf.loc, original_areas[fixture_turf])
	original_areas.Cut()
	if(!QDELETED(ship_area))
		ship_area.shuttle_port = null
		qdel(ship_area)
	QDEL_NULL(fixture_block)
	port = null
	ship = null
	pirate = null
	ship_area = null
	return ..()

/datum/unit_test/voidcrew_ship_boarding_patrol/Run()
	fixture_block = SSmapping.request_turf_block_reservation(9, 3, 1)
	TEST_ASSERT_NOTNULL(fixture_block, "No room for the ship fixture")
	var/turf/corner = fixture_block.bottom_left_turfs[1]
	ship_area = new
	for(var/dx in 0 to 8)
		for(var/dy in 0 to 2)
			var/turf/spot = locate(corner.x + dx, corner.y + dy, corner.z)
			original_areas[spot] = spot.loc
			spot.change_area(spot.loc, ship_area)
			if(dy == 1 && dx >= 1 && dx <= 7)
				spot.ChangeTurf(/turf/open/floor/iron)
			else
				spot.ChangeTurf(/turf/closed/wall)
	var/obj/machinery/door/airlock/first_door = new(locate(corner.x + 3, corner.y + 1, corner.z))
	var/obj/machinery/door/airlock/second_door = new(locate(corner.x + 5, corner.y + 1, corner.z))
	built_doors += first_door
	built_doors += second_door
	port = new(locate(corner.x + 1, corner.y + 1, corner.z), list(ship_area))
	TEST_ASSERT(port.shuttle_areas[ship_area], "The fixture port does not hold the ship's area")
	port.register() // so deleting it unregisters it once
	ship = allocate(/obj/structure/overmap/ship)
	ship.shuttle = port

	pirate = allocate(/mob/living/basic/trooper, locate(corner.x + 1, corner.y + 1, corner.z))
	TEST_ASSERT_NOTNULL(swap_basic_ai_controller(pirate, /datum/ai_controller/basic_controller/trooper/patrolling), "The patrolling controller could not take a trooper")
	TEST_ASSERT(assign_mob_to_patrol(pirate, ship), "The boarding patrol no longer assigns on a ship")
	var/datum/ai_controller/controller = pirate.ai_controller
	var/list/path = controller.blackboard["mob_patrol_path"]
	TEST_ASSERT_EQUAL(length(path), 2, "The ship's patrol path does not have its two airlocks")
	TEST_ASSERT((first_door in path) && (second_door in path), "The ship's patrol path is missing an airlock")
	TEST_ASSERT_EQUAL(controller.blackboard["mob_patrol_ship_ref"], REF(ship), "The patrol is not keyed to the ship")
	TEST_ASSERT(GLOB.boarding_patrol_paths[REF(ship)] == path, "The ship's patrol path was not cached")
	TEST_ASSERT_EQUAL(length(GLOB.ship_rooms[REF(ship)]), 3, "The ship fixture is not three rooms")
	var/start_index = controller.blackboard["mob_patrol_index"]
	TEST_ASSERT(start_index >= 1 && start_index <= 2, "The ship patrol starts at index [start_index]")
	TEST_ASSERT_NOTNULL(controller.blackboard["_last_known_room"], "The ship patrol did not find the starting room")
	TEST_ASSERT_NULL(GLOB.outpost_patrol_caches[REF(ship)], "A ship patrol made an outpost patrol cache")
	TEST_ASSERT_NULL(outpost_patrol_of(pirate), "A ship patroller reports an outpost patrol")

// ===== DOOR-HEAVY OUTPOSTS =====

/// A patrol cache whose starting point is set by the test
/datum/outpost_patrol_cache/unit_test
	var/turf/test_origin

/datum/outpost_patrol_cache/unit_test/patrol_origin()
	return test_origin

/**
 * A rebuild over two hundred doors yields instead of holding the tick, and the path keeps only
 * the 40 stops nearest where the patrol starts (OUTPOST_PATROL_MAX_STOPS).
 */
/datum/unit_test/voidcrew_outpost_patrol_many_doors
	parent_type = /datum/unit_test/voidcrew_outpost_management
	var/datum/turf_reservation/grid_block

/datum/unit_test/voidcrew_outpost_patrol_many_doors/Destroy()
	QDEL_NULL(grid_block)
	return ..()

/datum/unit_test/voidcrew_outpost_patrol_many_doors/Run()
	var/obj/structure/overmap/dynamic/player_outpost/home = allocate(/obj/structure/overmap/dynamic/player_outpost)
	// A 41 x 21 block with a door on every other tile: 200 doors.
	grid_block = SSmapping.request_turf_block_reservation(41, 21, 1)
	TEST_ASSERT_NOTNULL(grid_block, "No room for the door grid")
	var/turf/low_corner = grid_block.bottom_left_turfs[1]
	var/low_x = low_corner.x
	var/low_y = low_corner.y
	var/z = low_corner.z
	var/turf/high_corner = locate(low_x + 40, low_y + 20, z)
	TEST_ASSERT(low_corner && high_corner, "No room for the door grid")
	var/list/owned = list()
	for(var/turf/ground as anything in block(low_corner, high_corner))
		ground.ChangeTurf(/turf/open/floor/iron)
		owned[ground] = TRUE
	var/list/interior = list()
	for(var/column in 0 to 19)
		for(var/row in 0 to 9)
			var/obj/machinery/door/airlock/door = allocate(/obj/machinery/door/airlock, locate(low_x + 1 + column * 2, low_y + 1 + row * 2, z))
			interior[door] = TRUE
	TEST_ASSERT_EQUAL(length(interior), 200, "The grid has [length(interior)] doors")

	var/datum/outpost_patrol_cache/unit_test/cache = new(home)
	cache.test_origin = low_corner
	// With no tick left, the first CHECK_TICK has to give the tick back.
	var/started = world.time
	Master.current_ticklimit = 0
	cache.rebuild(owned, interior)
	if(!Master.current_ticklimit)
		Master.current_ticklimit = TICK_LIMIT_RUNNING
	TEST_ASSERT(world.time > started, "Rebuilding the patrol over 200 doors never yielded")
	TEST_ASSERT(!QDELETED(cache), "The patrol cache was deleted during the rebuild")
	var/list/path = cache.path
	TEST_ASSERT_EQUAL(length(path), 40, "The patrol path has [length(path)] stops, not the 40 nearest") // OUTPOST_PATROL_MAX_STOPS

	// The stops kept are the ones nearest the start.
	var/turf/origin = cache.patrol_origin()
	TEST_ASSERT_NOTNULL(origin, "The patrol has no starting point")
	var/farthest_kept = 0
	for(var/obj/machinery/door/door as anything in path)
		farthest_kept = max(farthest_kept, get_dist(origin, door))
	for(var/obj/machinery/door/door as anything in interior)
		if(door in path)
			continue
		TEST_ASSERT(get_dist(origin, door) >= farthest_kept, "A door [get_dist(origin, door)] tiles from the start was dropped while one [farthest_kept] tiles away was kept")
	qdel(cache)

