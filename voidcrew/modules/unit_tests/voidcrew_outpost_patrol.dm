/**
 * Outpost patrols (voidcrew/modules/npc_ships/code/outpost_patrol.dm): the boarding patrol pointed at
 * a player outpost, the breakout controller escaped prisoners run, and the ship patrol it came from.
 *
 * Voidcrew defines are not visible from test files, so blackboard keys appear as their literal
 * strings. The prison fixtures (prison_test_claim(), prison_spot()) are in
 * voidcrew_outpost_prison_helpers.dm.
 */

// ===== PATH =====

/datum/unit_test/voidcrew_outpost_patrol_path
	parent_type = /datum/unit_test/voidcrew_outpost_management

/datum/unit_test/voidcrew_outpost_patrol_path/Run()
	var/obj/structure/overmap/dynamic/player_outpost/home = prison_test_claim("patrolpathowner")
	TEST_ASSERT_NOTNULL(home, "The patrol test prison did not load")
	var/key = REF(home)
	var/list/path = get_outpost_patrol_path(home, TRUE)
	TEST_ASSERT(length(path) >= 5, "The patrol path has [length(path)] doors; the wing alone has its office door and four cell doors")

	// The wing's own doors, from the upgrade's area
	var/obj/machinery/door/staff_door = locate(/obj/machinery/door/airlock) in prison_spot(home, 9, 6)
	TEST_ASSERT_NOTNULL(staff_door, "The warden's office door is not where the map puts it")
	TEST_ASSERT(staff_door in path, "The warden's office door is not on the patrol path")
	for(var/cell_x in list(3, 7, 11, 15))
		var/obj/machinery/door/cell_door = locate(/obj/machinery/door/airlock) in prison_spot(home, cell_x, 12)
		TEST_ASSERT_NOTNULL(cell_door, "No cell door at [cell_x],12")
		TEST_ASSERT(cell_door in path, "The cell door at [cell_x],12 is not on the patrol path")

	// Left out: a door onto space (the wing's entrance, placed away from the shell here), the shell's
	// external airlock, and the hatch windoors on their table
	var/obj/machinery/door/entrance = locate(/obj/machinery/door/airlock) in prison_spot(home, 9, 1)
	TEST_ASSERT_NOTNULL(entrance, "The wing's entrance is not where the map puts it")
	TEST_ASSERT(!(entrance in path), "A door that opens onto space is on the patrol path")
	var/external_count = 0
	for(var/turf/shell_turf as anything in home.outpost_area.get_turfs_by_zlevel(home.upgrade_level_z()))
		for(var/obj/machinery/door/airlock/external/outer in shell_turf)
			external_count++
			TEST_ASSERT(!(outer in path), "The shell's external airlock is on the patrol path")
	TEST_ASSERT(external_count, "The compact shell has no external airlock to leave out")
	for(var/hatch_x in list(5, 13))
		var/hatch_count = 0
		for(var/obj/machinery/door/window/hatch_door in prison_spot(home, hatch_x, 6))
			hatch_count++
			TEST_ASSERT(!(hatch_door in path), "A serving hatch windoor is a patrol stop")
			TEST_ASSERT_EQUAL(length(GLOB.door_to_rooms[key][REF(hatch_door)]), 2, "A serving hatch does not part the yard from the office")
		TEST_ASSERT(hatch_count, "No serving hatch windoors at [hatch_x],6")
	var/level_z = home.upgrade_level_z()
	for(var/obj/machinery/door/door as anything in path)
		TEST_ASSERT_EQUAL(door.z, level_z, "A patrol door is off the outpost's main level")

	// Rooms, filed under the outpost for the patrol and room search subtrees
	var/yard_room = get_room_for_turf(prison_spot(home, 9, 8), key)
	var/office_room = get_room_for_turf(prison_spot(home, 9, 3), key)
	TEST_ASSERT(yard_room && office_room && yard_room != office_room, "The yard and the office are not separate rooms ([yard_room], [office_room])")
	var/list/staff_rooms = GLOB.door_to_rooms[key][REF(staff_door)]
	TEST_ASSERT(length(staff_rooms) == 2 && (yard_room in staff_rooms) && (office_room in staff_rooms), "The office door does not join the yard and the office")
	TEST_ASSERT(length(GLOB.ship_rooms[key]) >= 6, "Only [length(GLOB.ship_rooms[key])] rooms; the wing has four cells, a yard and an office")
	var/obj/structure/closet/office_closet = locate() in prison_spot(home, 2, 2)
	TEST_ASSERT_NOTNULL(office_closet, "The office closet is not where the map puts it")
	TEST_ASSERT(office_closet in GLOB.ship_rooms[key][office_room]["closets"], "The office closet is not in the office's room data")

	// Cached, and changed only in place
	TEST_ASSERT(get_outpost_patrol_path(home) == path, "The cached patrol path was not reused")
	var/turf/open/floor/door_spot
	for(var/turf/open/floor/candidate in home.outpost_area.get_turfs_by_zlevel(level_z))
		if(clear_floor(candidate, home) && clear_floor(get_step(candidate, NORTH), home) && clear_floor(get_step(candidate, SOUTH), home) \
			&& clear_floor(get_step(candidate, EAST), home) && clear_floor(get_step(candidate, WEST), home))
			door_spot = candidate
			break
	TEST_ASSERT_NOTNULL(door_spot, "No open floor in the shell to build a door on")
	var/obj/machinery/door/airlock/built_door = new(door_spot)
	TEST_ASSERT(get_outpost_patrol_path(home, TRUE) == path, "Rebuilding replaced the shared path list")
	TEST_ASSERT(built_door in path, "A door built in the outpost was not added to the patrol")
	qdel(built_door)
	TEST_ASSERT(!(built_door in path), "A deleted door stayed on the patrol path")
	for(var/room_id in GLOB.ship_rooms[key])
		TEST_ASSERT(!(built_door in GLOB.ship_rooms[key][room_id]["doors"]), "A deleted door stayed in [room_id]'s doors")
	TEST_ASSERT(get_outpost_patrol_path(home) == path, "Rebuilding after a deletion replaced the shared path list")
	TEST_ASSERT(!(null in path), "The rebuild after a door was deleted left a gap in the path")
	TEST_ASSERT(staff_door in path, "The rebuild after a door was deleted lost the office door")

	// Assigning, and clearing every key again
	var/mob/living/basic/outpost_prisoner/runner = allocate(/mob/living/basic/outpost_prisoner, prison_spot(home, 9, 3))
	var/datum/ai_controller/controller = swap_basic_ai_controller(runner, /datum/ai_controller/basic_controller/outpost_breakout)
	TEST_ASSERT_NOTNULL(controller, "The breakout controller could not take a prisoner")
	TEST_ASSERT(assign_mob_to_outpost_patrol(runner, home), "A prisoner in the office was not given the patrol")
	TEST_ASSERT(controller.blackboard["mob_patrol_path"] == path, "The patroller does not share the outpost's path")
	TEST_ASSERT_EQUAL(controller.blackboard["mob_patrol_ship_ref"], key, "The patrol is not keyed to the outpost")
	var/start_index = controller.blackboard["mob_patrol_index"]
	TEST_ASSERT(start_index >= 1 && start_index <= length(path), "The patrol starts at index [start_index] of [length(path)]")
	TEST_ASSERT_EQUAL(controller.blackboard["_last_known_room"], office_room, "The patrol did not start in the office")
	TEST_ASSERT_EQUAL(controller.blackboard["_exploring_room"], office_room, "The office was not searched first")
	TEST_ASSERT(office_closet in controller.blackboard["_exploration_targets"], "The office search skipped its closet")
	TEST_ASSERT_EQUAL(outpost_patrol_of(runner), home, "outpost_patrol_of() did not find the outpost")
	// Mid-patrol state from the door handling
	controller.set_blackboard_key("_blocking_door_to_attack", staff_door)
	controller.blackboard["_patrol_door_start_time"] = world.time
	controller.blackboard["_skipped_blocking_doors"] = list(REF(staff_door) = TRUE)
	controller.blackboard["_blocking_door_attack_times"] = list(REF(staff_door) = world.time)
	TEST_ASSERT(clear_outpost_patrol(runner), "clear_outpost_patrol() refused a patroller")
	for(var/bb_key in outpost_patrol_blackboard_keys())
		TEST_ASSERT_NULL(controller.blackboard[bb_key], "clear_outpost_patrol() left [bb_key] set")
	for(var/bb_key in list("mob_patrol_path", "mob_patrol_index", "mob_patrol_target", "mob_patrol_ship_ref", "_last_known_room", \
		"_exploring_room", "_exploration_targets", "_exploration_index", "_blocking_door_to_attack", "_patrol_door_start_time", \
		"_skipped_blocking_doors", "_blocking_door_attack_times", "_failed_blocking_doors"))
		TEST_ASSERT_NULL(controller.blackboard[bb_key], "clear_outpost_patrol() left [bb_key] set")
	TEST_ASSERT_NULL(outpost_patrol_of(runner), "A cleared prisoner still reports a patrol")
	TEST_ASSERT(length(path), "Clearing one patroller emptied the shared path")

	// Deleting the cache (as the outpost's deletion does) empties the shared tables
	var/datum/outpost_patrol_cache/cache = GLOB.outpost_patrol_caches[key]
	TEST_ASSERT_NOTNULL(cache, "The outpost has no patrol cache")
	qdel(cache)
	TEST_ASSERT_NULL(GLOB.outpost_patrol_caches[key], "A deleted cache stayed registered")
	TEST_ASSERT_NULL(GLOB.ship_rooms[key], "A deleted cache left its rooms behind")
	TEST_ASSERT_NULL(GLOB.turf_to_room[key], "A deleted cache left its turf table behind")
	TEST_ASSERT(!length(path), "A deleted cache left doors in the shared path")
	settle_prison_air(home)

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

/datum/unit_test/voidcrew_outpost_patrol_breakout/proc/reached_door(mob/living/walker, start_index)
	var/datum/ai_controller/controller = walker.ai_controller
	if(controller.blackboard["mob_patrol_index"] != start_index)
		return TRUE
	var/obj/machinery/door/target_door = controller.blackboard["mob_patrol_target"]
	return !QDELETED(target_door) && get_dist(walker, target_door) <= 1

/datum/unit_test/voidcrew_outpost_patrol_breakout/proc/has_swung_at(atom/target)
	return target in swung_at

/// Where the walker is on the wing's own map coordinates, and what its AI is doing, for failure messages
/datum/unit_test/voidcrew_outpost_patrol_breakout/proc/describe_walker(obj/structure/overmap/dynamic/player_outpost/home, mob/living/walker)
	var/datum/outpost_upgrade/prison/blueprint = home.outpost_upgrades["prison"]
	var/list/bounds = blueprint.footprint_bounds
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
	var/obj/structure/overmap/dynamic/player_outpost/home = prison_test_claim("breakoutowner")
	TEST_ASSERT_NOTNULL(home, "The breakout test prison did not load")
	var/key = REF(home)
	var/turf/start = prison_spot(home, 9, 8)
	var/mob/living/basic/outpost_prisoner/walker = allocate(/mob/living/basic/outpost_prisoner, start)
	var/mob/living/basic/outpost_prisoner/inmate = allocate(/mob/living/basic/outpost_prisoner, prison_spot(home, 8, 8))
	var/mob/living/basic/trooper/other_escapee = allocate(/mob/living/basic/trooper, prison_spot(home, 10, 8))
	TEST_ASSERT_NOTNULL(swap_basic_ai_controller(other_escapee, /datum/ai_controller/basic_controller/outpost_breakout), "The breakout controller could not take a trooper")

	// Swapping a live prisoner's controller
	var/datum/ai_controller/routine = walker.ai_controller
	var/datum/ai_controller/controller = swap_basic_ai_controller(walker, /datum/ai_controller/basic_controller/outpost_breakout)
	TEST_ASSERT(istype(controller, /datum/ai_controller/basic_controller/outpost_breakout), "The prisoner did not take the breakout controller")
	TEST_ASSERT_EQUAL(walker.ai_controller, controller, "The prisoner is not run by the new controller")
	TEST_ASSERT(QDELETED(routine), "The prisoner's routine controller outlived the swap")
	TEST_ASSERT_EQUAL(swap_basic_ai_controller(walker, /datum/ai_controller/basic_controller/outpost_breakout), controller, "Swapping to the same controller type replaced it")
	RegisterSignal(walker, COMSIG_HOSTILE_PRE_ATTACKINGTARGET, PROC_REF(on_swing))

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

	// Walking the path with someone on the level
	TEST_ASSERT(assign_mob_to_outpost_patrol(walker, home), "The escaped prisoner was not given the patrol")
	var/start_index = controller.blackboard["mob_patrol_index"]
	watcher = allocate(/mob/living/carbon/human/consistent)
	watched_z = walker.z
	SSmobs.clients_by_zlevel[watched_z] |= watcher
	controller.reset_ai_status()
	TEST_ASSERT_EQUAL(controller.ai_status, AI_STATUS_ON, "The breakout AI did not wake with someone on the level")
	var/list/trace = list()
	var/walked = FALSE
	var/deadline = world.time + 45 SECONDS
	while(world.time < deadline)
		if(reached_door(walker, start_index))
			walked = TRUE
			break
		trace += describe_walker(home, walker)
		sleep(1 SECONDS)
	TEST_ASSERT(walked, "The escaped prisoner never reached a patrol door. Trace: [jointext(trace, " | ")]")
	TEST_ASSERT(walker.loc != start, "The escaped prisoner never moved")

	// Someone in reach gets attacked
	var/walker_room = get_room_for_turf(get_turf(walker), key)
	var/turf/guard_spot
	for(var/reach in 1 to 4)
		for(var/turf/open/floor/candidate in range(reach, walker))
			if(candidate == get_turf(walker) || get_dist(candidate, walker) != reach || get_room_for_turf(candidate, key) != walker_room || candidate.is_blocked_turf())
				continue
			guard_spot = candidate
			break
		if(guard_spot)
			break
	TEST_ASSERT_NOTNULL(guard_spot, "No open floor near the escaped prisoner for the guard")
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

/**
 * A rebuild over two hundred doors yields instead of holding the tick, and the path keeps only
 * the 40 stops nearest the prison wing (OUTPOST_PATROL_MAX_STOPS).
 */
/datum/unit_test/voidcrew_outpost_patrol_many_doors
	parent_type = /datum/unit_test/voidcrew_outpost_management

/datum/unit_test/voidcrew_outpost_patrol_many_doors/Run()
	var/obj/structure/overmap/dynamic/player_outpost/home = prison_test_claim("manydoorsowner")
	TEST_ASSERT_NOTNULL(home, "The door-heavy test prison did not load")
	var/datum/outpost_prison/prison = test_prison(home)
	var/list/bounds = prison.upgrade.footprint_bounds
	var/z = bounds[5]
	// A 41 x 21 stretch of the claim beside the wing, with a door on every other tile: 200 doors.
	var/low_x = bounds[3] + 4
	if(low_x + 40 > home.build_bounds[3])
		low_x = bounds[1] - 45
	var/low_y = min(bounds[2], home.build_bounds[4] - 21)
	var/turf/low_corner = locate(low_x, low_y, z)
	var/turf/high_corner = locate(low_x + 40, low_y + 20, z)
	TEST_ASSERT(low_corner && high_corner, "No room on the claim for the door grid")
	var/list/owned = list()
	for(var/turf/ground as anything in block(low_corner, high_corner))
		owned[ground] = TRUE
	var/list/interior = list()
	for(var/column in 0 to 19)
		for(var/row in 0 to 9)
			var/obj/machinery/door/airlock/door = allocate(/obj/machinery/door/airlock, locate(low_x + 1 + column * 2, low_y + 1 + row * 2, z))
			interior[door] = TRUE
	TEST_ASSERT_EQUAL(length(interior), 200, "The grid has [length(interior)] doors")

	var/datum/outpost_patrol_cache/cache = new(home)
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

	// The stops kept are the ones nearest the wing.
	var/turf/origin = cache.patrol_origin()
	TEST_ASSERT_NOTNULL(origin, "The patrol has no starting point")
	var/farthest_kept = 0
	for(var/obj/machinery/door/door as anything in path)
		farthest_kept = max(farthest_kept, get_dist(origin, door))
	for(var/obj/machinery/door/door as anything in interior)
		if(door in path)
			continue
		TEST_ASSERT(get_dist(origin, door) >= farthest_kept, "A door [get_dist(origin, door)] tiles from the wing was dropped while one [farthest_kept] tiles away was kept")
	qdel(cache)
	settle_prison_air(home)

// ===== THE LOOKUP NEVER HOLDS UP THE PRISON =====

/**
 * Looking for an outpost's doors yields whenever the tick is full, and a prisoner goes loose from
 * the prison's tick on SSprocessing, where a sleep stalls everything else the subsystem runs. So
 * going loose hands the lookup off and returns at once; the patrol is assigned when it finishes,
 * and not at all if the prisoner was caught meanwhile.
 */
/datum/unit_test/voidcrew_outpost_patrol_async
	parent_type = /datum/unit_test/voidcrew_outpost_management

/datum/unit_test/voidcrew_outpost_patrol_async/Run()
	var/obj/structure/overmap/dynamic/player_outpost/home = trouble_test_claim("patrolasyncowner")
	TEST_ASSERT_NOTNULL(home, "The patrol lookup test prison did not load")
	var/datum/outpost_prison/prison = test_prison(home)
	var/mob/living/basic/outpost_prisoner/runner = trouble_prisoner(prison, prison_spot(home, 9, 8))
	var/mob/living/basic/outpost_prisoner/caught = trouble_prisoner(prison, prison_spot(home, 10, 8))

	// With no tick left, the lookup's first CHECK_TICK has to give the tick back.
	var/started = world.time
	Master.current_ticklimit = 0
	runner.go_loose()
	var/returned_at = world.time
	if(!Master.current_ticklimit)
		Master.current_ticklimit = TICK_LIMIT_RUNNING
	TEST_ASSERT_EQUAL(returned_at, started, "Going loose waited [returned_at - started] ds for the door lookup")
	TEST_ASSERT(wait_until(CALLBACK(src, PROC_REF(has_patrol), runner), 10 SECONDS), "The loose prisoner was never put on the patrol")
	TEST_ASSERT(length(runner.ai_controller.blackboard["mob_patrol_path"]) <= 40, "The patrol path is longer than 40 stops") // OUTPOST_PATROL_MAX_STOPS

	// Caught while the doors are still being looked for: no patrol for the prisoner back in custody.
	var/datum/outpost_patrol_cache/cache = GLOB.outpost_patrol_caches[REF(home)]
	TEST_ASSERT_NOTNULL(cache, "The outpost has no patrol cache")
	cache.dirty = TRUE
	Master.current_ticklimit = 0
	caught.go_loose()
	caught.back_in_custody()
	if(!Master.current_ticklimit)
		Master.current_ticklimit = TICK_LIMIT_RUNNING
	UNTIL(!cache.rebuilding || world.time > started + 20 SECONDS)
	sleep(1)
	TEST_ASSERT(!has_patrol(caught), "A prisoner caught during the door lookup was put on the patrol")
	settle_prison_air(home)

/datum/unit_test/voidcrew_outpost_patrol_async/proc/has_patrol(mob/living/walker)
	return length(walker.ai_controller?.blackboard["mob_patrol_path"]) > 0
