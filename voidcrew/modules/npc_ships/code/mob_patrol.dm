/**
 * Mob Patrol System - JPS-based navigation for boarding parties
 *
 * Mobs navigate from door to door using proper JPS pathfinding.
 * This is much simpler and more reliable than the old door-hopping system.
 */

// Debug logging toggle - set to TRUE to enable patrol debug messages
#define PATROL_DEBUG FALSE

#if PATROL_DEBUG
#define PATROL_LOG(msg) log_shuttle("PATROL: [msg]")
#else
#define PATROL_LOG(msg)
#endif

// How long to wait before considering a path failed (JPS should repath automatically, but this is a fallback)
#define PATROL_JPS_TIMEOUT (8 SECONDS)
// How long to wait at a door before giving up and moving to next
#define PATROL_DOOR_TIMEOUT (20 SECONDS)

/**
 * Generate a door-to-door patrol path for a ship.
 * Returns a list of doors to visit in order, creating a route through all accessible rooms.
 *
 * @param ship The overmap ship to generate a path for
 * @return List of door objects in visit order, or null if generation fails
 */
/proc/generate_ship_patrol_path(obj/structure/overmap/ship/target_ship)
	PATROL_LOG("generate_ship_patrol_path called for [target_ship]")

	if(!target_ship?.shuttle?.shuttle_areas?.len)
		PATROL_LOG("FAILED: No shuttle or shuttle_areas on target ship")
		return null

	// Collect all interior doors on the ship (exclude external airlocks, blast doors, etc.)
	// First pass: collect all valid doors
	var/list/obj/machinery/door/all_doors = list()
	for(var/area/ship_area as anything in target_ship.shuttle.shuttle_areas)
		for(var/obj/machinery/door/D in ship_area)
			// Skip firedoors
			if(istype(D, /obj/machinery/door/firedoor))
				continue
			// Skip blast doors / poddoors - these are critical ship infrastructure
			if(istype(D, /obj/machinery/door/poddoor))
				continue
			// Skip external airlocks by type
			if(istype(D, /obj/machinery/door/airlock/external))
				continue
			// Skip doors with "external" in the name
			if(findtext(D.name, "external"))
				continue
			// Check if door leads to space or non-ship area
			var/leads_to_space = FALSE
			var/turf/door_turf = get_turf(D)
			if(door_turf)
				for(var/dir in GLOB.cardinals)
					var/turf/adj = get_step(door_turf, dir)
					if(!adj)
						continue
					// Skip if leads to space
					if(isspaceturf(adj))
						leads_to_space = TRUE
						break
					// Skip if leads outside ship areas
					var/area/adj_area = get_area(adj)
					if(adj_area && !(adj_area in target_ship.shuttle.shuttle_areas))
						leads_to_space = TRUE
						break
			if(leads_to_space)
				continue
			all_doors += D

	// Filter to a single z-level to avoid duplicate rooms from multi-z shuttles
	// Pick the z-level with the most doors
	var/list/doors_by_z = list()
	for(var/obj/machinery/door/D in all_doors)
		var/turf/T = get_turf(D)
		if(!T)
			continue
		var/z_key = "[T.z]"
		if(!doors_by_z[z_key])
			doors_by_z[z_key] = list()
		doors_by_z[z_key] += D

	// Find z-level with most doors
	var/best_z = null
	var/best_count = 0
	for(var/z_key in doors_by_z)
		if(length(doors_by_z[z_key]) > best_count)
			best_count = length(doors_by_z[z_key])
			best_z = z_key

	if(best_z)
		all_doors = doors_by_z[best_z]
		PATROL_LOG("Filtered to z-level [best_z] with [length(all_doors)] doors")

	PATROL_LOG("Found [length(all_doors)] interior doors on ship")

	if(!length(all_doors))
		PATROL_LOG("FAILED: No doors found on ship")
		return null

	// Build door adjacency - which doors can reach which other doors
	// Two doors are adjacent if you can walk between them without going through another door
	var/list/door_neighbors = list() // door ref -> list of neighboring door refs

	for(var/obj/machinery/door/door in all_doors)
		door_neighbors[REF(door)] = list()

	// Cache GLOB.cardinals locally for performance (avoid repeated GLOB lookups)
	var/list/cardinal_dirs = GLOB.cardinals

	// For each door, flood fill to find reachable doors (without crossing other doors)
	for(var/obj/machinery/door/start_door in all_doors)
		var/turf/start_turf = get_turf(start_door)
		if(!start_turf)
			continue

		var/list/visited = list()
		var/list/queue = list()
		visited[start_turf] = TRUE

		// Start from both sides of the door
		for(var/dir in cardinal_dirs)
			var/turf/adj = get_step(start_turf, dir)
			if(adj && !adj.density)
				queue += adj
				visited[adj] = TRUE

		// BFS to find reachable doors - use index-based traversal (O(1) vs O(n) for Cut)
		var/queue_idx = 1
		while(queue_idx <= length(queue))
			var/turf/current = queue[queue_idx]
			queue_idx++

			// Check if this turf has a door (that isn't our start door)
			for(var/obj/machinery/door/found_door in current)
				if(found_door != start_door && (found_door in all_doors))
					// Found a neighboring door
					door_neighbors[REF(start_door)] |= REF(found_door)
					continue // Don't flood past this door

			// Check if current turf IS a door turf (block further expansion)
			var/has_other_door = FALSE
			for(var/obj/machinery/door/D in current)
				if(D != start_door && (D in all_doors))
					has_other_door = TRUE
					break
			if(has_other_door)
				continue

			// Expand to neighbors
			for(var/dir in cardinal_dirs)
				var/turf/neighbor = get_step(current, dir)
				if(!neighbor || visited[neighbor])
					continue
				if(neighbor.density)
					continue
				// Only block on things that truly separate rooms (windows, grilles)
				// Allow all other structures and machinery - they're walkable furniture
				var/blocked = FALSE
				for(var/obj/O in neighbor)
					if(!O.density)
						continue
					if(istype(O, /obj/structure/window) || istype(O, /obj/structure/grille))
						blocked = TRUE
						break
				if(blocked)
					continue
				visited[neighbor] = TRUE
				queue += neighbor

	// Generate patrol path using BFS traversal through connected doors
	// This ensures every step in the path is through a valid door connection (no walls)
	var/list/path = list()
	var/list/unvisited = all_doors.Copy()

	// Start from a random door
	var/obj/machinery/door/current_door = pick(unvisited)
	path += current_door
	unvisited -= current_door

	// BFS through the door graph - only follow valid connections
	while(length(unvisited))
		var/list/neighbors = door_neighbors[REF(current_door)]
		var/obj/machinery/door/next_door = null
		var/best_dist = INFINITY

		// Find the closest unvisited neighbor (directly connected door)
		for(var/neighbor_ref in neighbors)
			var/obj/machinery/door/neighbor = locate(neighbor_ref)
			if(!neighbor)
				continue // Door was deleted
			if(neighbor in unvisited)
				var/dist = get_dist(current_door, neighbor)
				if(dist < best_dist)
					best_dist = dist
					next_door = neighbor

		// If no unvisited neighbors, BFS through door graph to find nearest unvisited
		if(!next_door)
			var/list/bfs_queue = list(REF(current_door))
			var/list/bfs_visited = list(REF(current_door) = TRUE)
			var/list/bfs_parent = list() // To reconstruct path

			// Use index-based traversal (O(1) vs O(n) for Cut)
			var/bfs_idx = 1
			while(bfs_idx <= length(bfs_queue) && !next_door)
				var/check_ref = bfs_queue[bfs_idx]
				bfs_idx++

				var/list/check_neighbors = door_neighbors[check_ref]
				for(var/n_ref in check_neighbors)
					if(bfs_visited[n_ref])
						continue
					bfs_visited[n_ref] = TRUE
					bfs_parent[n_ref] = check_ref

					var/obj/machinery/door/n_door = locate(n_ref)
					if(!n_door)
						continue // Door was deleted
					if(n_door in unvisited)
						// Found an unvisited door - trace back to find first step
						var/trace_ref = n_ref
						while(bfs_parent[trace_ref] != REF(current_door))
							if(!bfs_parent[trace_ref])
								break // Can't trace further
							trace_ref = bfs_parent[trace_ref]
						next_door = locate(trace_ref)
						if(!next_door)
							continue // Traced door was deleted
						break
					bfs_queue += n_ref

		if(!next_door)
			break // No more reachable doors through valid connections

		path += next_door
		unvisited -= next_door
		current_door = next_door

	PATROL_LOG("Generated door patrol path with [length(path)] doors (valid connections only)")

	if(length(path) < 2)
		PATROL_LOG("FAILED: Path too short ([length(path)] doors)")
		return null

	// Also build a list of doors that require access (pirates have none, so these need attacking)
	var/list/locked_doors = list()
	for(var/obj/machinery/door/D in path)
		if(door_requires_access(D))
			locked_doors[REF(D)] = TRUE

	// Cache the locked doors list
	var/ship_ref = REF(target_ship)
	GLOB.boarding_locked_doors[ship_ref] = locked_doors
	PATROL_LOG("Identified [length(locked_doors)] doors requiring access (will attack directly)")

	// Compute room data for exploration system
	compute_ship_rooms(target_ship, all_doors)

	// Post-process: remove doors that would just revisit the same rooms
	// This prevents bouncing between the same 2 rooms via multiple doors
	var/list/filtered_path = list()
	var/list/visited_room_pairs = list()

	for(var/obj/machinery/door/D in path)
		var/list/door_rooms = GLOB.door_to_rooms[ship_ref]?[REF(D)]
		if(!door_rooms || length(door_rooms) < 2)
			// Door doesn't connect two rooms - keep it anyway
			PATROL_LOG("Door [D.name] connects [length(door_rooms)] rooms - keeping (no pair)")
			filtered_path += D
			continue

		// Create a canonical key for this room pair (sorted to be order-independent)
		var/room_a = door_rooms[1]
		var/room_b = door_rooms[2]
		var/pair_key = room_a < room_b ? "[room_a]-[room_b]" : "[room_b]-[room_a]"

		if(visited_room_pairs[pair_key])
			// Already have a door for this room pair - skip this one
			PATROL_LOG("Skipping door [D.name] - already have door for [pair_key]")
			continue

		PATROL_LOG("Door [D.name] connects [pair_key] - keeping")
		visited_room_pairs[pair_key] = TRUE
		filtered_path += D

	if(length(filtered_path) < length(path))
		PATROL_LOG("Filtered path from [length(path)] to [length(filtered_path)] doors (removed duplicates)")
		path = filtered_path

	return path

/**
 * Compute discrete rooms on a ship using flood-fill.
 * Each room is a connected region of turfs separated by doors.
 * Builds GLOB.ship_rooms, GLOB.turf_to_room, and GLOB.door_to_rooms.
 *
 * @param target_ship The ship to compute rooms for
 * @param all_doors List of doors on the ship (from generate_ship_patrol_path)
 */
/proc/compute_ship_rooms(obj/structure/overmap/ship/target_ship, list/obj/machinery/door/all_doors, colorize = FALSE, filter_z = 0)
	if(!target_ship?.shuttle?.shuttle_areas?.len)
		return

	var/ship_ref = REF(target_ship)
	var/color_count = length(GLOB.room_colors)

	// If no z-filter specified, use the z-level of the first door
	if(!filter_z && length(all_doors))
		var/obj/machinery/door/first_door = all_doors[1]
		var/turf/T = get_turf(first_door)
		if(T)
			filter_z = T.z
	var/list/cardinal_dirs = GLOB.cardinals

	// Initialize GLOB structures for this ship
	GLOB.ship_rooms[ship_ref] = list()
	GLOB.turf_to_room[ship_ref] = list()
	GLOB.door_to_rooms[ship_ref] = list()

	// Build a set of all door turfs for quick lookup
	var/list/door_turfs = list()
	for(var/obj/machinery/door/D in all_doors)
		var/turf/door_turf = get_turf(D)
		if(door_turf)
			door_turfs[door_turf] = D

	// Collect all valid turfs on the ship (filtered to single z-level if specified)
	var/list/all_ship_turfs = list()
	for(var/area/ship_area as anything in target_ship.shuttle.shuttle_areas)
		for(var/turf/T in ship_area)
			if(isspaceturf(T))
				continue
			if(filter_z && T.z != filter_z)
				continue  // Skip turfs on other z-levels
			all_ship_turfs[T] = TRUE

	// Track visited turfs across all flood-fills
	var/list/global_visited = list()
	var/room_counter = 0

	// Flood-fill from each unvisited non-door turf
	for(var/turf/start_turf as anything in all_ship_turfs)
		if(global_visited[start_turf])
			continue
		if(door_turfs[start_turf])
			continue // Don't start from a door turf
		if(start_turf.density)
			continue // Don't start from a wall

		// Start a new room
		room_counter++
		var/room_id = "room_[room_counter]"

		var/list/room_turfs = list()
		var/list/room_closets = list()
		var/list/room_doors = list()

		var/list/queue = list(start_turf)
		var/list/visited = list(start_turf = TRUE)
		var/queue_idx = 1

		while(queue_idx <= length(queue))
			var/turf/current = queue[queue_idx]
			queue_idx++

			// Check if this is a door turf - record door but don't expand past it
			var/obj/machinery/door/door_here = door_turfs[current]
			if(door_here)
				room_doors |= door_here
				continue // Don't expand past doors

			// This is a valid room turf
			room_turfs += current
			global_visited[current] = TRUE

			// Record turf -> room mapping for O(1) lookup
			GLOB.turf_to_room[ship_ref][REF(current)] = room_id

			// Check for closets/crates on this turf
			for(var/obj/structure/closet/C in current)
				room_closets |= C
				PATROL_LOG("Found closet [C.type] '[C.name]' in room [room_id] at ([current.x],[current.y])")

			// Expand to neighbors
			for(var/dir in cardinal_dirs)
				var/turf/neighbor = get_step(current, dir)
				if(!neighbor || visited[neighbor])
					continue
				if(!all_ship_turfs[neighbor])
					continue // Outside ship
				if(neighbor.density && !door_turfs[neighbor])
					continue // Wall (but allow doors)

				// Only block on things that truly separate rooms (windows, grilles)
				// Allow doors, structures, machinery - they don't divide rooms
				var/blocked = FALSE
				for(var/obj/O in neighbor)
					if(!O.density)
						continue
					if(istype(O, /obj/structure/window) || istype(O, /obj/structure/grille))
						blocked = TRUE
						break
				if(blocked && !door_turfs[neighbor])
					continue

				visited[neighbor] = TRUE
				queue += neighbor

		// Store room data
		GLOB.ship_rooms[ship_ref][room_id] = list(
			"turfs" = room_turfs,
			"closets" = room_closets,
			"doors" = room_doors
		)

		PATROL_LOG("Room [room_id]: [length(room_turfs)] turfs, [length(room_closets)] closets, [length(room_doors)] doors")

		// Optionally colorize turfs for debugging
		if(colorize && color_count)
			var/room_color = GLOB.room_colors[((room_counter - 1) % color_count) + 1]
			for(var/turf/T as anything in room_turfs)
				T.color = room_color

	// Build door_to_rooms mapping
	// Each door connects two rooms (the rooms on each side of it)
	for(var/obj/machinery/door/D in all_doors)
		var/turf/door_turf = get_turf(D)
		if(!door_turf)
			continue

		var/list/connected_rooms = list()
		for(var/dir in cardinal_dirs)
			var/turf/adj = get_step(door_turf, dir)
			if(!adj)
				continue
			var/adj_room = GLOB.turf_to_room[ship_ref][REF(adj)]
			if(adj_room && !(adj_room in connected_rooms))
				connected_rooms += adj_room

		if(length(connected_rooms))
			GLOB.door_to_rooms[ship_ref][REF(D)] = connected_rooms

	PATROL_LOG("Computed [room_counter] rooms for ship [target_ship]")

/**
 * Get the room ID for a given turf on a ship.
 * Uses pre-computed turf_to_room for O(1) lookup.
 * If the turf is a door turf (not in any room), checks adjacent turfs.
 *
 * @param T The turf to look up
 * @param ship_ref REF() of the ship
 * @return Room ID string, or null if turf isn't in a known room
 */
/proc/get_room_for_turf(turf/T, ship_ref)
	if(!T || !ship_ref)
		return null
	var/list/ship_turf_map = GLOB.turf_to_room[ship_ref]
	if(!ship_turf_map)
		return null

	var/room = ship_turf_map[REF(T)]
	if(room)
		return room

	// Turf not in a room - might be a door turf
	// Check adjacent turfs to find what room we're effectively in
	for(var/dir in GLOB.cardinals)
		var/turf/adj = get_step(T, dir)
		if(!adj)
			continue
		var/adj_room = ship_turf_map[REF(adj)]
		if(adj_room)
			return adj_room

	return null

/**
 * Start room exploration if the room hasn't been explored yet.
 * Called when mob enters a new room.
 *
 * @param controller The AI controller
 * @param room_id The room to explore
 * @param ship_ref REF() of the ship
 */
/proc/maybe_start_room_exploration(datum/ai_controller/controller, room_id, ship_ref)
	if(!controller || !room_id || !ship_ref)
		return

	// Check if room already explored this cycle
	var/list/explored_rooms = controller.blackboard[BB_EXPLORED_ROOMS]
	if(explored_rooms && explored_rooms[room_id])
		PATROL_LOG("[controller.pawn] already explored [room_id], skipping")
		return

	// Mark room as explored NOW (before building targets)
	// This prevents re-exploration if combat interrupts
	LAZYSET(controller.blackboard[BB_EXPLORED_ROOMS], room_id, TRUE)

	// Get room data
	var/list/ship_rooms = GLOB.ship_rooms[ship_ref]
	if(!ship_rooms)
		return
	var/list/room_data = ship_rooms[room_id]
	if(!room_data)
		return

	// Skip exploration for tiny rooms (likely just hallway segments or door gaps)
	var/list/room_turfs = room_data["turfs"]
	var/list/room_closets = room_data["closets"]
	if(length(room_turfs) < EXPLORATION_MIN_ROOM_SIZE && !length(room_closets))
		PATROL_LOG("[controller.pawn] skipping tiny room [room_id] ([length(room_turfs)] turfs, no closets)")
		return

	// Build target list
	var/list/targets = list()

	// Add closets that are closed (locked ones will be broken open)
	var/list/valid_closets = list()
	var/list/all_room_closets = room_data["closets"]
	PATROL_LOG("[controller.pawn] room [room_id] has [length(all_room_closets)] closets in room data")
	for(var/obj/structure/closet/C in all_room_closets)
		if(QDELETED(C))
			PATROL_LOG("  - [C.type] QDELETED, skipping")
			continue
		if(C.opened)
			PATROL_LOG("  - [C.type] '[C.name]' already open, skipping")
			continue
		PATROL_LOG("  - [C.type] '[C.name]' added (locked=[C.locked], welded=[C.welded])")
		valid_closets += C

	// Cap closets and shuffle
	if(length(valid_closets) > EXPLORATION_MAX_LOCKERS)
		valid_closets = shuffle(valid_closets)
		valid_closets.len = EXPLORATION_MAX_LOCKERS

	// If room has closets, ONLY do closets (purpose-driven)
	// If no closets, do 2 waypoints instead
	if(length(valid_closets))
		targets = valid_closets
	else
		// No closets - pick 2 random walkable turfs as waypoints
		var/list/walkable_turfs = list()
		for(var/turf/T in room_turfs)
			if(T.density)
				continue
			var/blocked = FALSE
			for(var/obj/O in T)
				if(O.density)
					blocked = TRUE
					break
			if(blocked)
				continue
			walkable_turfs += T

		if(length(walkable_turfs))
			walkable_turfs = shuffle(walkable_turfs)
			for(var/i in 1 to min(2, length(walkable_turfs)))
				targets += walkable_turfs[i]

	// If no targets, exploration completes immediately
	if(!length(targets))
		PATROL_LOG("[controller.pawn] room [room_id] has no exploration targets")
		return

	// Set exploration state
	controller.set_blackboard_key(BB_EXPLORING_ROOM, room_id)
	controller.set_blackboard_key(BB_EXPLORATION_TARGETS, targets)
	controller.set_blackboard_key(BB_EXPLORATION_INDEX, 1)

	PATROL_LOG("[controller.pawn] starting exploration of [room_id]: [length(targets)] targets ([length(valid_closets)] closets)")

/**
 * Clear patrol tracking keys from a controller's blackboard.
 * Called when advancing to a new door target.
 */
/proc/clear_patrol_tracking_keys(datum/ai_controller/controller)
	controller.clear_blackboard_key("_patrol_door_start_time")
	controller.clear_blackboard_key("_patrol_last_dist")
	controller.clear_blackboard_key(BB_MOB_PATROL_TARGET_TURF)
	controller.clear_blackboard_key("_patrol_assembly_to_attack")
	controller.clear_blackboard_key(BB_MOB_PATROL_ORIGIN_ROOM)

/**
 * Clear ALL patrol-related state from a controller's blackboard.
 * Call this when reassigning a mob to a new patrol to ensure a clean slate.
 */
/proc/clear_all_patrol_state(datum/ai_controller/controller)
	clear_patrol_tracking_keys(controller)
	controller.clear_blackboard_key(BB_MOB_PATROL_PATH)
	controller.clear_blackboard_key(BB_MOB_PATROL_INDEX)
	controller.clear_blackboard_key(BB_MOB_PATROL_TARGET)
	controller.clear_blackboard_key(BB_MOB_PATROL_SHIP_REF)
	controller.clear_blackboard_key("_last_crossed_door")
	controller.clear_blackboard_key("_failed_blocking_doors")
	controller.clear_blackboard_key("_patrol_started_logged")
	// Clear exploration state
	controller.clear_blackboard_key(BB_LAST_KNOWN_ROOM)
	controller.clear_blackboard_key(BB_EXPLORED_ROOMS)
	controller.clear_blackboard_key(BB_EXPLORING_ROOM)
	controller.clear_blackboard_key(BB_EXPLORATION_TARGETS)
	controller.clear_blackboard_key(BB_EXPLORATION_INDEX)
	controller.clear_blackboard_key(BB_EXPLORATION_TARGET)

/**
 * Check if a door requires access to open.
 * Pirates have no access, so any door with req_access or req_one_access will need to be attacked.
 */
/proc/door_requires_access(obj/machinery/door/D)
	if(!D)
		return FALSE

	// Check for airlock-specific access requirements
	if(istype(D, /obj/machinery/door/airlock))
		var/obj/machinery/door/airlock/A = D
		if(LAZYLEN(A.req_access) || LAZYLEN(A.req_one_access))
			return TRUE

	// Check for windoor access requirements
	if(istype(D, /obj/machinery/door/window))
		var/obj/machinery/door/window/W = D
		if(LAZYLEN(W.req_access) || LAZYLEN(W.req_one_access))
			return TRUE

	return FALSE

/**
 * Get or generate the cached patrol path for a ship.
 * Paths are cached in GLOB.boarding_patrol_paths keyed by ship ref.
 */
/proc/get_ship_patrol_path(obj/structure/overmap/ship/target_ship)
	PATROL_LOG("get_ship_patrol_path called for [target_ship]")

	if(!target_ship)
		PATROL_LOG("FAILED: target_ship is null")
		return null

	var/ship_ref = REF(target_ship)

	// Return cached path if it exists
	if(GLOB.boarding_patrol_paths[ship_ref])
		PATROL_LOG("Returning cached path with [length(GLOB.boarding_patrol_paths[ship_ref])] doors")
		return GLOB.boarding_patrol_paths[ship_ref]

	// Generate and cache new path
	PATROL_LOG("No cached path, generating new one...")
	var/list/path = generate_ship_patrol_path(target_ship)
	if(path)
		GLOB.boarding_patrol_paths[ship_ref] = path
		PATROL_LOG("Cached new path with [length(path)] doors")
	else
		PATROL_LOG("Path generation returned null")

	return path

/**
 * Clear the cached patrol path for a ship (call when ship is destroyed or structure changes significantly)
 */
/proc/clear_ship_patrol_path(obj/structure/overmap/ship/target_ship)
	if(!target_ship)
		return
	var/ship_ref = REF(target_ship)
	GLOB.boarding_patrol_paths -= ship_ref
	GLOB.boarding_locked_doors -= ship_ref
	GLOB.patrol_stagger_counter -= ship_ref
	// Clear room data
	GLOB.ship_rooms -= ship_ref
	GLOB.turf_to_room -= ship_ref
	GLOB.door_to_rooms -= ship_ref

/**
 * Debug visualization - draws the door patrol path on the ship with colored markers.
 * Green at start, transitions to red at end. Numbers show visit order.
 * Markers persist until manually cleared with clear_patrol_visualization().
 *
 * @param target_ship The ship to visualize patrol path for
 */
/proc/visualize_patrol_path(obj/structure/overmap/ship/target_ship)
	var/list/path = get_ship_patrol_path(target_ship)
	if(!path || !length(path))
		to_chat(world, span_warning("No patrol path for [target_ship]"))
		return

	// Clear any existing markers for this ship first
	var/ship_ref = REF(target_ship)
	clear_patrol_visualization(ship_ref)

	var/path_length = length(path)
	var/list/markers = list()

	for(var/i in 1 to path_length)
		var/obj/machinery/door/D = path[i]
		if(QDELETED(D))
			continue

		var/turf/T = get_turf(D)
		if(!T)
			continue

		// Create a visual marker at the door
		var/obj/effect/patrol_marker/marker = new(T)
		markers += marker

		// Color gradient: green (start) -> yellow (middle) -> red (end)
		var/progress = (i - 1) / max(path_length - 1, 1)
		var/r = min(255, round(510 * progress))
		var/g = min(255, round(510 * (1 - progress)))
		marker.color = rgb(r, g, 0)

		// Show door name and index
		marker.maptext = MAPTEXT("[i]")
		marker.name = "patrol door #[i]: [D.name]"

	// Store markers for later cleanup
	if(!GLOB.patrol_path_markers)
		GLOB.patrol_path_markers = list()
	GLOB.patrol_path_markers[ship_ref] = markers

	to_chat(world, span_notice("Visualizing door patrol path for [target_ship]: [path_length] doors (green=start, red=end). Use clear_patrol_visualization() to remove."))

/**
 * Clear patrol visualization markers for a specific ship or all ships.
 * @param ship_ref Optional - REF() of a specific ship. If null, clears all markers.
 */
/proc/clear_patrol_visualization(ship_ref)
	if(!GLOB.patrol_path_markers)
		return

	if(ship_ref)
		// Clear markers for specific ship
		var/list/markers = GLOB.patrol_path_markers[ship_ref]
		if(markers)
			for(var/obj/effect/patrol_marker/marker in markers)
				qdel(marker)
			GLOB.patrol_path_markers -= ship_ref
	else
		// Clear all markers
		for(var/ref in GLOB.patrol_path_markers)
			var/list/markers = GLOB.patrol_path_markers[ref]
			for(var/obj/effect/patrol_marker/marker in markers)
				qdel(marker)
		GLOB.patrol_path_markers.Cut()

/**
 * Visual marker for patrol path debugging
 */
/obj/effect/patrol_marker
	name = "patrol waypoint"
	icon = 'icons/effects/effects.dmi'
	icon_state = "yourturftarget"  // Green target reticle
	layer = ABOVE_MOB_LAYER
	mouse_opacity = MOUSE_OPACITY_TRANSPARENT
	alpha = 180

/// Admin verb to visualize patrol path for the ship you're standing on
/client/proc/visualize_ship_patrol()
	set name = "Visualize Patrol Path"
	set category = "Debug"

	if(!check_rights(R_DEBUG))
		return

	var/mob/M = mob
	var/turf/T = get_turf(M)
	if(!T)
		to_chat(M, span_warning("You're not on a turf!"))
		return

	// Find what ship we're on by checking the area
	var/area/A = get_area(T)
	if(!A)
		to_chat(M, span_warning("No area found!"))
		return

	// Look for a ship that has this area in its shuttle_areas
	for(var/obj/structure/overmap/ship/S in SSovermap.simulated_ships)
		if(!S.shuttle?.shuttle_areas)
			continue
		if(A in S.shuttle.shuttle_areas)
			visualize_patrol_path(S)
			return

	to_chat(M, span_warning("Couldn't find a ship for this location. Try standing on a ship."))

/// Admin verb to clear patrol path visualization for the ship you're standing on, or all ships
/client/proc/clear_ship_patrol_visualization()
	set name = "Clear Patrol Visualization"
	set category = "Debug"

	if(!check_rights(R_DEBUG))
		return

	var/mob/M = mob
	var/choice = tgui_alert(M, "Clear patrol visualization for which ships?", "Clear Patrol Viz", list("This Ship", "All Ships", "Cancel"))

	if(choice == "Cancel" || !choice)
		return

	if(choice == "All Ships")
		clear_patrol_visualization()
		to_chat(M, span_notice("Cleared all patrol visualizations."))
		return

	// Find what ship we're on
	var/turf/T = get_turf(M)
	if(!T)
		to_chat(M, span_warning("You're not on a turf!"))
		return

	var/area/A = get_area(T)
	if(!A)
		to_chat(M, span_warning("No area found!"))
		return

	for(var/obj/structure/overmap/ship/S in SSovermap.simulated_ships)
		if(!S.shuttle?.shuttle_areas)
			continue
		if(A in S.shuttle.shuttle_areas)
			clear_patrol_visualization(REF(S))
			to_chat(M, span_notice("Cleared patrol visualization for [S]."))
			return

	to_chat(M, span_warning("Couldn't find a ship for this location."))

/**
 * Assign a mob to patrol a ship's cached path.
 * Starts the mob at the nearest door to their current position.
 */
/proc/assign_mob_to_patrol(mob/living/mob_to_assign, obj/structure/overmap/ship/target_ship, spawn_index = 0, total_spawns = 1)
	PATROL_LOG("assign_mob_to_patrol called: mob=[mob_to_assign], ship=[target_ship]")

	if(!mob_to_assign || !target_ship)
		PATROL_LOG("FAILED: mob_to_assign=[mob_to_assign], target_ship=[target_ship]")
		return FALSE

	var/list/path = get_ship_patrol_path(target_ship)
	if(!path || !length(path))
		PATROL_LOG("FAILED: No path returned from get_ship_patrol_path")
		return FALSE

	var/datum/ai_controller/controller = mob_to_assign.ai_controller
	if(!controller)
		PATROL_LOG("FAILED: Mob has no ai_controller")
		return FALSE

	PATROL_LOG("Mob AI controller type: [controller.type]")

	// Clear all existing patrol state
	clear_all_patrol_state(controller)

	// Assign patrol path reference
	controller.blackboard[BB_MOB_PATROL_PATH] = path
	controller.blackboard[BB_MOB_PATROL_SHIP_REF] = REF(target_ship)

	// Find the nearest door to the mob's current position
	var/start_index = 1
	var/best_dist = INFINITY
	var/turf/mob_turf = get_turf(mob_to_assign)
	if(mob_turf)
		for(var/i in 1 to length(path))
			var/obj/machinery/door/D = path[i]
			if(QDELETED(D))
				continue
			var/dist = get_dist(mob_turf, D)
			if(dist < best_dist)
				best_dist = dist
				start_index = i

	// Stagger start indices to prevent mobs from blocking each other
	var/ship_ref = REF(target_ship)
	if(!GLOB.patrol_stagger_counter[ship_ref])
		GLOB.patrol_stagger_counter[ship_ref] = 0
	var/current_counter = GLOB.patrol_stagger_counter[ship_ref]++
	var/stagger_offset = current_counter * 3

	start_index = ((start_index - 1 + stagger_offset) % length(path)) + 1
	controller.blackboard[BB_MOB_PATROL_INDEX] = start_index

	// Pre-populate the failed doors list with doors that require access
	var/list/locked_doors = GLOB.boarding_locked_doors[ship_ref]
	if(length(locked_doors))
		controller.blackboard["_failed_blocking_doors"] = locked_doors.Copy()
		PATROL_LOG("Pre-marked [length(locked_doors)] doors as needing attack (no access)")

	PATROL_LOG("SUCCESS: Assigned [mob_to_assign] to patrol, start_index=[start_index], path_length=[length(path)]")

	// Determine starting room and trigger initial exploration
	var/starting_room = get_room_for_turf(mob_turf, ship_ref)
	if(starting_room)
		controller.set_blackboard_key(BB_LAST_KNOWN_ROOM, starting_room)
		maybe_start_room_exploration(controller, starting_room, ship_ref)
		PATROL_LOG("[mob_to_assign] starting in [starting_room]")

	// Auto-visualize path in debug mode (only once per ship)
	#if PATROL_DEBUG
	if(!GLOB.patrol_paths_visualized)
		GLOB.patrol_paths_visualized = list()
	if(!GLOB.patrol_paths_visualized[ship_ref])
		GLOB.patrol_paths_visualized[ship_ref] = TRUE
		visualize_patrol_path(target_ship)
	#endif

	return TRUE

/**
 * Planning subtree for door-to-door patrol behavior using JPS pathfinding.
 * Much simpler than the old door-hopping system - just set the movement target
 * and let the JPS movement system handle pathfinding.
 */
/datum/ai_planning_subtree/patrol_path

/datum/ai_planning_subtree/patrol_path/SelectBehaviors(datum/ai_controller/controller, seconds_per_tick)
	var/mob/living/pawn = controller.pawn
	if(!pawn)
		return

	// Don't patrol if we have a combat target
	if(controller.blackboard_key_exists(BB_BASIC_MOB_CURRENT_TARGET))
		return

	// Get patrol data
	var/list/patrol_path = controller.blackboard[BB_MOB_PATROL_PATH]
	if(!length(patrol_path))
		return

	var/patrol_index = controller.blackboard[BB_MOB_PATROL_INDEX] || 1
	var/ship_ref = controller.blackboard[BB_MOB_PATROL_SHIP_REF]

	// Clamp index to valid range
	if(patrol_index < 1 || patrol_index > length(patrol_path))
		patrol_index = 1
		controller.blackboard[BB_MOB_PATROL_INDEX] = patrol_index
		// Clear explored rooms when patrol wraps around
		controller.clear_blackboard_key(BB_EXPLORED_ROOMS)
		PATROL_LOG("[pawn] patrol wrapped, clearing explored rooms")

	// Get current target door
	var/obj/machinery/door/target_door = patrol_path[patrol_index]

	// Store the target door's turf for assembly checking (before it might be destroyed)
	var/turf/target_turf = controller.blackboard[BB_MOB_PATROL_TARGET_TURF]
	if(!QDELETED(target_door) && !target_turf)
		target_turf = get_turf(target_door)
		controller.blackboard[BB_MOB_PATROL_TARGET_TURF] = target_turf

	// If door is destroyed, check for assembly before advancing
	if(QDELETED(target_door))
		// Check if there's an assembly on the door's former location
		if(target_turf)
			for(var/obj/structure/door_assembly/assembly in target_turf)
				if(assembly.density)
					// Assembly still blocking - need to attack it
					PATROL_LOG("[pawn] door destroyed but assembly [assembly.name] remains - attacking")
					controller.set_blackboard_key("_patrol_assembly_to_attack", assembly)
					controller.queue_behavior(/datum/ai_behavior/move_to_and_attack_assembly, "_patrol_assembly_to_attack")
					return SUBTREE_RETURN_FINISH_PLANNING

		// No blocking assembly - safe to advance
		patrol_index = (patrol_index % length(patrol_path)) + 1
		controller.blackboard[BB_MOB_PATROL_INDEX] = patrol_index
		controller.clear_blackboard_key(BB_MOB_PATROL_TARGET_TURF)
		clear_patrol_tracking_keys(controller)
		// Check for wrap
		if(patrol_index == 1)
			controller.clear_blackboard_key(BB_EXPLORED_ROOMS)
			PATROL_LOG("[pawn] patrol wrapped after destroyed door, clearing explored rooms")
		PATROL_LOG("[pawn] door destroyed (no assembly), advancing to [patrol_index]")
		return

	var/turf/pawn_turf = get_turf(pawn)
	var/current_dist = get_dist(pawn, target_door)

	// Log first patrol start
	if(!controller.blackboard["_patrol_started_logged"])
		controller.blackboard["_patrol_started_logged"] = TRUE
		PATROL_LOG("[pawn] STARTING PATROL - target: [target_door.name], dist=[current_dist]")

	// Room-based door transition detection
	// Check if we've moved into a new room (meaning we walked through a door)
	var/current_room = get_room_for_turf(pawn_turf, ship_ref)
	var/last_room = controller.blackboard[BB_LAST_KNOWN_ROOM]

	// Track origin room - the room we were in when we first started approaching this door
	// This is used to verify we actually crossed THROUGH the target door
	var/origin_room = controller.blackboard[BB_MOB_PATROL_ORIGIN_ROOM]
	if(!origin_room && current_room)
		origin_room = current_room
		controller.set_blackboard_key(BB_MOB_PATROL_ORIGIN_ROOM, origin_room)

	// If we don't have room data at all, use simpler fallback logic
	var/has_room_data = GLOB.turf_to_room[ship_ref] != null

	if(current_room && current_room != last_room)
		// We've entered a new room!
		controller.set_blackboard_key(BB_LAST_KNOWN_ROOM, current_room)
		PATROL_LOG("[pawn] entered new room: [current_room] (was: [last_room || "none"])")

		// Check if this room transition means we passed through the target door
		// The door connects two rooms - we must have crossed FROM one TO the other
		var/list/door_rooms = GLOB.door_to_rooms[ship_ref]?[REF(target_door)]
		if(door_rooms && length(door_rooms) >= 2)
			var/room_a = door_rooms[1]
			var/room_b = door_rooms[2]

			// Check if origin room is one of the door's rooms
			var/origin_is_door_room = (origin_room == room_a || origin_room == room_b)

			if(origin_is_door_room)
				// Origin is one of the door's rooms - check for valid crossing
				var/valid_crossing = FALSE
				if(origin_room == room_a && current_room == room_b)
					valid_crossing = TRUE
				else if(origin_room == room_b && current_room == room_a)
					valid_crossing = TRUE

				if(valid_crossing)
					// We actually crossed through the target door - advance patrol
					PATROL_LOG("[pawn] crossed door [patrol_index] ([origin_room] -> [current_room])")
					patrol_index = (patrol_index % length(patrol_path)) + 1
					controller.blackboard[BB_MOB_PATROL_INDEX] = patrol_index

					// Track the door we just crossed so we don't open it again from the other side
					controller.set_blackboard_key("_last_crossed_door", target_door)

					clear_patrol_tracking_keys(controller)

					// Check for wrap
					if(patrol_index == 1)
						controller.clear_blackboard_key(BB_EXPLORED_ROOMS)
						PATROL_LOG("[pawn] patrol wrapped, clearing explored rooms")

					PATROL_LOG("[pawn] advancing to patrol index [patrol_index]")

					// Trigger room exploration for the new room
					maybe_start_room_exploration(controller, current_room, ship_ref)
					return
			else
				// Origin is NOT one of the door's rooms - check if we just entered one
				// This happens when the NPC approaches from a distant room
				if(current_room == room_a || current_room == room_b)
					// We've reached one of the door's rooms - update origin
					controller.set_blackboard_key(BB_MOB_PATROL_ORIGIN_ROOM, current_room)
					PATROL_LOG("[pawn] reached door's room [current_room], setting as origin")

		// Trigger exploration for new room even if we didn't cross target door
		maybe_start_room_exploration(controller, current_room, ship_ref)

		// Entered a different room (not via target door) - still explore it
		maybe_start_room_exploration(controller, current_room, ship_ref)

	// Fallback: ONLY if room data is completely unavailable for this ship
	// This prevents premature patrol advancement when room detection should work
	if(!has_room_data && !target_door.density && current_dist <= 1)
		PATROL_LOG("[pawn] passed open door [patrol_index] (no room data fallback)")
		patrol_index = (patrol_index % length(patrol_path)) + 1
		controller.blackboard[BB_MOB_PATROL_INDEX] = patrol_index
		clear_patrol_tracking_keys(controller)
		if(patrol_index == 1)
			controller.clear_blackboard_key(BB_EXPLORED_ROOMS)
		PATROL_LOG("[pawn] advancing to [patrol_index]")
		return

	// Simple timeout-based stuck detection
	// If we've been trying to reach this door for too long, skip it
	var/door_start_time = controller.blackboard["_patrol_door_start_time"]
	if(!door_start_time)
		controller.blackboard["_patrol_door_start_time"] = world.time
		controller.blackboard["_patrol_last_dist"] = current_dist
	else
		var/last_dist = controller.blackboard["_patrol_last_dist"]

		// If we're making progress, reset the timer
		if(current_dist < last_dist)
			controller.blackboard["_patrol_door_start_time"] = world.time
			controller.blackboard["_patrol_last_dist"] = current_dist
		// If we've been stuck for too long, skip to next door
		else if(world.time > door_start_time + PATROL_DOOR_TIMEOUT && current_dist > 2)
			PATROL_LOG("[pawn] TIMEOUT reaching door [patrol_index] (dist=[current_dist])")
			patrol_index = (patrol_index % length(patrol_path)) + 1
			controller.blackboard[BB_MOB_PATROL_INDEX] = patrol_index
			clear_patrol_tracking_keys(controller)
			if(patrol_index == 1)
				controller.clear_blackboard_key(BB_EXPLORED_ROOMS)
			PATROL_LOG("[pawn] advancing to [patrol_index]")
			return

	// Set the door as our patrol target
	controller.blackboard[BB_MOB_PATROL_TARGET] = target_door

	// If adjacent to door
	if(current_dist <= 1)
		// If door is OPEN (not dense), we need to walk THROUGH it
		if(!target_door.density)
			var/turf/door_turf = get_turf(target_door)
			if(door_turf)
				// Find a walkable turf on the opposite side of the door from the pawn
				var/turf/through_turf = get_turf_through_door(pawn_turf, door_turf)
				if(through_turf)
					// Store through turf and queue walk-through behavior
					controller.set_blackboard_key(BB_MOB_PATROL_TARGET_TURF, through_turf)
					controller.queue_behavior(/datum/ai_behavior/patrol_walk_through, BB_MOB_PATROL_TARGET_TURF)
					PATROL_LOG("[pawn] door [target_door.name] is open, walking through to ([through_turf.x],[through_turf.y])")
					return SUBTREE_RETURN_FINISH_PLANNING
		// If door is closed, let door interaction subtrees handle opening it
		return

	// Queue travel behavior - this triggers the JPS movement system
	// Only queue if we're not already moving to this target
	var/turf/door_turf = get_turf(target_door)
	if(door_turf && controller.current_movement_target != door_turf)
		controller.queue_behavior(/datum/ai_behavior/patrol_travel, BB_MOB_PATROL_TARGET)
		PATROL_LOG("[pawn] queued travel to [target_door.name] (dist=[current_dist])")

/**
 * Travel behavior for patrol movement.
 * Uses AI_BEHAVIOR_REQUIRE_MOVEMENT to trigger the JPS pathfinding system.
 */
/datum/ai_behavior/patrol_travel
	required_distance = 1  // Stop when adjacent to door
	behavior_flags = AI_BEHAVIOR_REQUIRE_MOVEMENT | AI_BEHAVIOR_CAN_PLAN_DURING_EXECUTION

/datum/ai_behavior/patrol_travel/setup(datum/ai_controller/controller, target_key)
	var/obj/machinery/door/target = controller.blackboard[target_key]
	if(QDELETED(target))
		return FALSE
	var/turf/target_turf = get_turf(target)
	if(!target_turf)
		return FALSE
	controller.set_movement_target(type, target_turf)
	return TRUE

/datum/ai_behavior/patrol_travel/perform(seconds_per_tick, datum/ai_controller/controller, target_key)
	var/obj/machinery/door/target = controller.blackboard[target_key]
	if(QDELETED(target))
		return AI_BEHAVIOR_DELAY | AI_BEHAVIOR_SUCCEEDED
	// Only succeed when adjacent - we need to actually reach the door
	if(get_dist(controller.pawn, target) <= 1)
		return AI_BEHAVIOR_DELAY | AI_BEHAVIOR_SUCCEEDED
	return AI_BEHAVIOR_DELAY

/datum/ai_behavior/patrol_travel/finish_action(datum/ai_controller/controller, succeeded, target_key)
	. = ..()

/**
 * Behavior for walking through an open door to a turf on the other side.
 */
/datum/ai_behavior/patrol_walk_through
	required_distance = 0  // Must actually reach the turf
	behavior_flags = AI_BEHAVIOR_REQUIRE_MOVEMENT | AI_BEHAVIOR_CAN_PLAN_DURING_EXECUTION

/datum/ai_behavior/patrol_walk_through/setup(datum/ai_controller/controller, target_key)
	var/turf/target = controller.blackboard[target_key]
	if(!target)
		return FALSE
	controller.set_movement_target(type, target)
	return TRUE

/datum/ai_behavior/patrol_walk_through/perform(seconds_per_tick, datum/ai_controller/controller, target_key)
	var/turf/target = controller.blackboard[target_key]
	if(!target)
		return AI_BEHAVIOR_DELAY | AI_BEHAVIOR_SUCCEEDED
	// Succeed when we're on or adjacent to the target turf
	var/dist = get_dist(controller.pawn, target)
	if(dist <= 0)
		return AI_BEHAVIOR_DELAY | AI_BEHAVIOR_SUCCEEDED
	return AI_BEHAVIOR_DELAY

/datum/ai_behavior/patrol_walk_through/finish_action(datum/ai_controller/controller, succeeded, target_key)
	. = ..()
	controller.clear_blackboard_key(target_key)

/**
 * Helper proc to find a walkable turf on the opposite side of a door from the pawn.
 * Used to make NPCs walk THROUGH open doors instead of just standing next to them.
 */
/proc/get_turf_through_door(turf/pawn_turf, turf/door_turf)
	if(!pawn_turf || !door_turf)
		return null

	// Calculate direction from pawn to door
	var/dir_to_door = get_dir(pawn_turf, door_turf)
	if(!dir_to_door)
		return null

	// Get the turf on the opposite side of the door (same direction, one more step)
	var/turf/through_turf = get_step(door_turf, dir_to_door)
	if(through_turf && !through_turf.density)
		// Check for dense objects on that turf
		var/blocked = FALSE
		for(var/obj/O in through_turf)
			if(O.density)
				blocked = TRUE
				break
		if(!blocked)
			return through_turf

	// If direct path blocked, check cardinal directions from the door
	for(var/dir in GLOB.cardinals)
		if(dir == get_dir(door_turf, pawn_turf))
			continue  // Skip the direction back to the pawn
		var/turf/candidate = get_step(door_turf, dir)
		if(candidate && !candidate.density)
			var/blocked = FALSE
			for(var/obj/O in candidate)
				if(O.density)
					blocked = TRUE
					break
			if(!blocked)
				return candidate

	return null

/**
 * Behavior for walking through an open door to the other side.
 */
/datum/ai_behavior/patrol_walk_through
	required_distance = 0  // Actually reach the target turf
	behavior_flags = AI_BEHAVIOR_REQUIRE_MOVEMENT | AI_BEHAVIOR_CAN_PLAN_DURING_EXECUTION

/datum/ai_behavior/patrol_walk_through/setup(datum/ai_controller/controller, target_key)
	var/turf/target = controller.blackboard[target_key]
	if(!target)
		PATROL_LOG("[controller.pawn] walk_through setup failed: no target turf")
		return FALSE
	controller.set_movement_target(type, target)
	return TRUE

/datum/ai_behavior/patrol_walk_through/perform(seconds_per_tick, datum/ai_controller/controller, target_key)
	var/turf/target = controller.blackboard[target_key]
	if(!target)
		PATROL_LOG("[controller.pawn] walk_through perform failed: no target turf")
		return AI_BEHAVIOR_DELAY | AI_BEHAVIOR_FAILED
	// Succeed when we reach the target turf
	var/turf/pawn_turf = get_turf(controller.pawn)
	if(pawn_turf == target)
		PATROL_LOG("[controller.pawn] walk_through succeeded: reached target turf")
		return AI_BEHAVIOR_DELAY | AI_BEHAVIOR_SUCCEEDED
	PATROL_LOG("[controller.pawn] walk_through: dist=[get_dist(controller.pawn, target)] from target")
	return AI_BEHAVIOR_DELAY

/datum/ai_behavior/patrol_walk_through/finish_action(datum/ai_controller/controller, succeeded, target_key)
	. = ..()
	PATROL_LOG("[controller.pawn] walk_through finish_action: succeeded=[succeeded]")
	controller.clear_blackboard_key(target_key)

/**
 * Subtree that handles ANY blocking door in our path - not just the patrol target.
 * This ensures mobs don't get stuck behind intermediate doors (like windoors)
 * that aren't their current patrol target.
 */
/datum/ai_planning_subtree/handle_blocking_door

/datum/ai_planning_subtree/handle_blocking_door/SelectBehaviors(datum/ai_controller/controller, seconds_per_tick)
	var/mob/living/pawn = controller.pawn
	if(!pawn)
		return

	// Don't handle patrol doors if we have a combat target - attack_obstacle_in_path handles combat obstacles
	if(controller.blackboard_key_exists(BB_BASIC_MOB_CURRENT_TARGET))
		return

	// Check all adjacent turfs for closed doors blocking our movement
	var/turf/pawn_turf = get_turf(pawn)
	if(!pawn_turf)
		return

	// Get our current patrol target from the path list (not from BB_MOB_PATROL_TARGET which may be cleared)
	// This prevents us from treating our target door as a "blocking" door
	var/obj/machinery/door/patrol_target = null
	var/list/patrol_path = controller.blackboard[BB_MOB_PATROL_PATH]
	var/patrol_index = controller.blackboard[BB_MOB_PATROL_INDEX] || 1
	if(length(patrol_path) && patrol_index >= 1 && patrol_index <= length(patrol_path))
		patrol_target = patrol_path[patrol_index]

	// Get the door we just crossed through (if any) - don't re-open it from the other side
	var/obj/machinery/door/last_crossed = controller.blackboard["_last_crossed_door"]

	// Get our current movement target (patrol door or exploration target)
	var/atom/movement_target = controller.current_movement_target
	if(!movement_target)
		// Also check exploration target
		movement_target = controller.blackboard[BB_EXPLORATION_TARGET]
	if(!movement_target)
		movement_target = patrol_target

	// Determine which direction we're trying to go
	var/target_dir = movement_target ? get_dir(pawn_turf, get_turf(movement_target)) : 0

	for(var/dir in GLOB.cardinals)
		var/turf/adj = get_step(pawn_turf, dir)
		if(!adj)
			continue

		// Only handle doors that are in the direction we're trying to go
		// This prevents repeatedly opening doors we've already passed through
		if(target_dir && !(dir & target_dir))
			continue

		// Check for any closed door on this adjacent turf
		for(var/obj/machinery/door/blocking_door in adj)
			// Skip if this IS our patrol target (normal handling will deal with it)
			if(blocking_door == patrol_target)
				continue

			// Skip the door we just crossed through - don't re-open it from the other side
			if(blocking_door == last_crossed)
				continue

			// Skip open doors
			if(!blocking_door.density)
				continue

			// Skip blast doors / poddoors - critical ship infrastructure
			if(istype(blocking_door, /obj/machinery/door/poddoor))
				continue

			// Skip external airlocks - don't want mobs going into space
			if(istype(blocking_door, /obj/machinery/door/airlock/external))
				continue
			if(findtext(blocking_door.name, "external"))
				continue

			// Found a blocking door that isn't our target - handle it
			var/door_ref = REF(blocking_door)

			// Check if we've given up on this door (attacked for too long)
			var/list/skipped_doors = controller.blackboard["_skipped_blocking_doors"]
			if(skipped_doors && skipped_doors[door_ref])
				continue  // Skip this door, we gave up on it

			PATROL_LOG("[pawn] found blocking door [blocking_door.name] at ([adj.x],[adj.y]) - not our target, handling it")

			// Check if we already tried and failed to open this door (persistent tracking)
			var/list/failed_doors = controller.blackboard["_failed_blocking_doors"]
			if(!failed_doors)
				failed_doors = list()
				controller.blackboard["_failed_blocking_doors"] = failed_doors

			if(failed_doors[door_ref])
				// Check if we've been attacking this door for too long (30 seconds)
				var/list/attack_times = controller.blackboard["_blocking_door_attack_times"]
				if(!attack_times)
					attack_times = list()
					controller.blackboard["_blocking_door_attack_times"] = attack_times

				var/attack_start = attack_times[door_ref]
				if(!attack_start)
					attack_times[door_ref] = world.time
				else if(world.time > attack_start + PATROL_DOOR_ATTACK_TIMEOUT)
					// We've been attacking this door for too long - give up
					if(!skipped_doors)
						skipped_doors = list()
						controller.blackboard["_skipped_blocking_doors"] = skipped_doors
					skipped_doors[door_ref] = TRUE
					PATROL_LOG("[pawn] giving up on blocking door [blocking_door.name] after [PATROL_DOOR_ATTACK_TIMEOUT / 10] seconds of attacking")
					continue  // Check for other blocking doors

				// Already failed to open this door before - attack it directly
				controller.set_blackboard_key("_blocking_door_to_attack", blocking_door)
				controller.queue_behavior(/datum/ai_behavior/attack_blocking_door, "_blocking_door_to_attack")
				return SUBTREE_RETURN_FINISH_PLANNING

			// Try to open it first
			controller.set_blackboard_key("_blocking_door_to_open", blocking_door)
			controller.queue_behavior(/datum/ai_behavior/try_open_blocking_door, "_blocking_door_to_open")
			return SUBTREE_RETURN_FINISH_PLANNING

	// Also check for door assemblies (left behind when doors are destroyed)
	for(var/dir in GLOB.cardinals)
		var/turf/adj = get_step(pawn_turf, dir)
		if(!adj)
			continue

		for(var/obj/structure/door_assembly/assembly in adj)
			if(!assembly.density)
				continue  // Not blocking

			PATROL_LOG("[pawn] found blocking door assembly [assembly.name] at ([adj.x],[adj.y]) - attacking it")
			controller.set_blackboard_key("_blocking_assembly_to_attack", assembly)
			controller.queue_behavior(/datum/ai_behavior/attack_blocking_assembly, "_blocking_assembly_to_attack")
			return SUBTREE_RETURN_FINISH_PLANNING

/**
 * Behavior that attacks a blocking door assembly (left behind when doors are destroyed)
 */
/datum/ai_behavior/attack_blocking_assembly
	action_cooldown = 1.2 SECONDS
	behavior_flags = NONE

/datum/ai_behavior/attack_blocking_assembly/setup(datum/ai_controller/controller, assembly_key)
	var/obj/structure/door_assembly/assembly = controller.blackboard[assembly_key]
	if(QDELETED(assembly) || !assembly.density)
		return FALSE
	return TRUE

/datum/ai_behavior/attack_blocking_assembly/perform(seconds_per_tick, datum/ai_controller/controller, assembly_key)
	var/obj/structure/door_assembly/assembly = controller.blackboard[assembly_key]
	var/mob/living/basic/pawn = controller.pawn

	if(QDELETED(assembly) || !assembly.density)
		return AI_BEHAVIOR_DELAY | AI_BEHAVIOR_SUCCEEDED

	// Must be adjacent to attack
	var/assembly_dist = get_dist(pawn, assembly)
	if(assembly_dist > 1)
		PATROL_LOG("[pawn] not adjacent to assembly [assembly.name] (dist=[assembly_dist]), cannot attack")
		return AI_BEHAVIOR_DELAY | AI_BEHAVIOR_FAILED

	pawn.melee_attack(assembly)
	PATROL_LOG("[pawn] smashing door assembly [assembly.name]")
	return AI_BEHAVIOR_DELAY | AI_BEHAVIOR_SUCCEEDED

/datum/ai_behavior/attack_blocking_assembly/finish_action(datum/ai_controller/controller, succeeded, assembly_key)
	. = ..()
	controller.clear_blackboard_key(assembly_key)

/**
 * Behavior that moves to and attacks a door assembly (used when patrol target door is destroyed)
 * This combines pathfinding to the assembly with attacking it.
 */
/datum/ai_behavior/move_to_and_attack_assembly
	action_cooldown = 1.2 SECONDS
	behavior_flags = NONE

/datum/ai_behavior/move_to_and_attack_assembly/setup(datum/ai_controller/controller, assembly_key)
	var/obj/structure/door_assembly/assembly = controller.blackboard[assembly_key]
	if(QDELETED(assembly) || !assembly.density)
		return FALSE
	return TRUE

/datum/ai_behavior/move_to_and_attack_assembly/perform(seconds_per_tick, datum/ai_controller/controller, assembly_key)
	var/obj/structure/door_assembly/assembly = controller.blackboard[assembly_key]
	var/mob/living/basic/pawn = controller.pawn

	if(QDELETED(assembly) || !assembly.density)
		PATROL_LOG("[pawn] assembly destroyed/cleared, can advance")
		return AI_BEHAVIOR_DELAY | AI_BEHAVIOR_SUCCEEDED

	var/assembly_dist = get_dist(pawn, assembly)

	// If not adjacent, move toward it
	if(assembly_dist > 1)
		// Queue movement to the assembly
		controller.current_movement_target = assembly
		PATROL_LOG("[pawn] moving to assembly [assembly.name] (dist=[assembly_dist])")
		return AI_BEHAVIOR_DELAY | AI_BEHAVIOR_SUCCEEDED  // Keep running until adjacent

	// Adjacent - attack it
	pawn.melee_attack(assembly)
	PATROL_LOG("[pawn] smashing patrol target assembly [assembly.name]")
	return AI_BEHAVIOR_DELAY | AI_BEHAVIOR_SUCCEEDED

/datum/ai_behavior/move_to_and_attack_assembly/finish_action(datum/ai_controller/controller, succeeded, assembly_key)
	. = ..()
	var/obj/structure/door_assembly/assembly = controller.blackboard[assembly_key]
	// Only clear if assembly is actually gone
	if(QDELETED(assembly) || !assembly.density)
		controller.clear_blackboard_key(assembly_key)
		controller.clear_blackboard_key(BB_MOB_PATROL_TARGET_TURF)

/**
 * Behavior that attempts to open a blocking door (not our patrol target)
 */
/datum/ai_behavior/try_open_blocking_door
	action_cooldown = 1 SECONDS
	behavior_flags = NONE

/datum/ai_behavior/try_open_blocking_door/setup(datum/ai_controller/controller, door_key)
	var/obj/machinery/door/door = controller.blackboard[door_key]
	if(QDELETED(door) || !door.density)
		return FALSE
	return TRUE

/datum/ai_behavior/try_open_blocking_door/perform(seconds_per_tick, datum/ai_controller/controller, door_key)
	var/obj/machinery/door/door = controller.blackboard[door_key]
	var/mob/living/pawn = controller.pawn

	if(QDELETED(door) || !door.density)
		// Door opened or destroyed - remove from failed list if present
		var/list/failed_doors = controller.blackboard["_failed_blocking_doors"]
		if(failed_doors)
			failed_doors -= REF(door)
		return AI_BEHAVIOR_DELAY | AI_BEHAVIOR_SUCCEEDED

	// Try to open via bumpopen
	door.bumpopen(pawn)

	if(!door.density)
		// Door opened - remove from failed list so we try bumpopen again if it closes
		var/list/failed_doors = controller.blackboard["_failed_blocking_doors"]
		if(failed_doors)
			failed_doors -= REF(door)
		// Also clear attack timeout tracking for this door
		var/list/attack_times = controller.blackboard["_blocking_door_attack_times"]
		if(attack_times)
			attack_times -= REF(door)
		var/list/skipped_doors = controller.blackboard["_skipped_blocking_doors"]
		if(skipped_doors)
			skipped_doors -= REF(door)
		PATROL_LOG("[pawn] successfully opened blocking door [door.name]")
		return AI_BEHAVIOR_DELAY | AI_BEHAVIOR_SUCCEEDED

	// Failed to open - add to failed list so we always attack it from now on
	var/list/failed_doors = controller.blackboard["_failed_blocking_doors"]
	if(!failed_doors)
		failed_doors = list()
		controller.blackboard["_failed_blocking_doors"] = failed_doors
	failed_doors[REF(door)] = TRUE
	PATROL_LOG("[pawn] failed to open blocking door [door.name] - will attack")
	return AI_BEHAVIOR_DELAY | AI_BEHAVIOR_SUCCEEDED

/datum/ai_behavior/try_open_blocking_door/finish_action(datum/ai_controller/controller, succeeded, door_key)
	. = ..()
	controller.clear_blackboard_key(door_key)

/**
 * Behavior that attacks a blocking door (not our patrol target)
 */
/datum/ai_behavior/attack_blocking_door
	action_cooldown = 1.2 SECONDS
	behavior_flags = NONE

/datum/ai_behavior/attack_blocking_door/setup(datum/ai_controller/controller, door_key)
	var/obj/machinery/door/door = controller.blackboard[door_key]
	if(QDELETED(door) || !door.density)
		return FALSE
	return TRUE

/datum/ai_behavior/attack_blocking_door/perform(seconds_per_tick, datum/ai_controller/controller, door_key)
	var/obj/machinery/door/door = controller.blackboard[door_key]
	var/mob/living/basic/pawn = controller.pawn

	if(QDELETED(door) || !door.density)
		// Door opened or destroyed - remove from all tracking lists
		var/door_ref = REF(door)
		var/list/failed_doors = controller.blackboard["_failed_blocking_doors"]
		if(failed_doors)
			failed_doors -= door_ref
		var/list/attack_times = controller.blackboard["_blocking_door_attack_times"]
		if(attack_times)
			attack_times -= door_ref
		var/list/skipped_doors = controller.blackboard["_skipped_blocking_doors"]
		if(skipped_doors)
			skipped_doors -= door_ref
		return AI_BEHAVIOR_DELAY | AI_BEHAVIOR_SUCCEEDED

	// Must be adjacent to attack - if not, fail so we can move closer
	var/door_dist = get_dist(pawn, door)
	if(door_dist > 1)
		PATROL_LOG("[pawn] not adjacent to blocking door [door.name] (dist=[door_dist]), cannot attack")
		return AI_BEHAVIOR_DELAY | AI_BEHAVIOR_FAILED

	// Always use melee attack for door breaking (like blobbernauts/standard troopers)
	// This is more reliable than ranged attacks and saves ammo for combat
	pawn.melee_attack(door)
	PATROL_LOG("[pawn] smashing blocking door [door.name]")
	return AI_BEHAVIOR_DELAY | AI_BEHAVIOR_SUCCEEDED

/datum/ai_behavior/attack_blocking_door/finish_action(datum/ai_controller/controller, succeeded, door_key)
	. = ..()
	controller.clear_blackboard_key(door_key)

/**
 * Door-opening subtree for patrol behavior.
 * When adjacent to target door, tries to open it before attacking.
 */
/datum/ai_planning_subtree/try_open_door_in_path
	var/target_key = BB_MOB_PATROL_TARGET

/datum/ai_planning_subtree/try_open_door_in_path/SelectBehaviors(datum/ai_controller/controller, seconds_per_tick)
	// Don't do patrol door stuff if we have a combat target
	if(controller.blackboard_key_exists(BB_BASIC_MOB_CURRENT_TARGET))
		return

	var/obj/machinery/door/target_door = controller.blackboard[target_key]
	if(QDELETED(target_door))
		return

	// Only try to open if door is closed
	if(!target_door.density)
		return

	var/mob/living/pawn = controller.pawn

	// Only interact when adjacent to the door
	if(get_dist(pawn, target_door) > 1)
		return

	// Check if we already tried and failed to open this door (persistent tracking)
	var/list/failed_doors = controller.blackboard["_failed_blocking_doors"]
	if(failed_doors && failed_doors[REF(target_door)])
		return  // Let attack subtree handle it - we already know this door won't open

	// Try to open the door
	controller.set_blackboard_key(BB_DOOR_TO_OPEN, target_door)
	controller.queue_behavior(/datum/ai_behavior/try_open_door, BB_DOOR_TO_OPEN)
	return SUBTREE_RETURN_FINISH_PLANNING

/**
 * Behavior that attempts to open a door by bumping it.
 * If the door doesn't open (locked, no access, etc.), it stays closed
 * and attack_obstacle_in_path will handle breaking it down.
 */
/datum/ai_behavior/try_open_door
	action_cooldown = 1 SECONDS
	behavior_flags = NONE  // No movement required, we're adjacent

/datum/ai_behavior/try_open_door/setup(datum/ai_controller/controller, door_key)
	var/obj/machinery/door/door = controller.blackboard[door_key]
	if(QDELETED(door) || !door.density)
		return FALSE  // Door gone or already open
	return TRUE

/datum/ai_behavior/try_open_door/perform(seconds_per_tick, datum/ai_controller/controller, door_key)
	var/obj/machinery/door/door = controller.blackboard[door_key]
	var/mob/living/pawn = controller.pawn

	if(QDELETED(door) || !door.density)
		// Door opened or destroyed - remove from failed list if present
		var/list/failed_doors = controller.blackboard["_failed_blocking_doors"]
		if(failed_doors)
			failed_doors -= REF(door)
		return AI_BEHAVIOR_DELAY | AI_BEHAVIOR_SUCCEEDED

	// Try to open the door via bumpopen (handles access checks, power, etc.)
	door.bumpopen(pawn)

	// Check if it opened
	if(!door.density)
		// Door opened - remove from failed list so we try bumpopen again if it closes
		var/list/failed_doors = controller.blackboard["_failed_blocking_doors"]
		if(failed_doors)
			failed_doors -= REF(door)
		// Also clear attack timeout tracking for this door
		var/list/attack_times = controller.blackboard["_blocking_door_attack_times"]
		if(attack_times)
			attack_times -= REF(door)
		var/list/skipped_doors = controller.blackboard["_skipped_blocking_doors"]
		if(skipped_doors)
			skipped_doors -= REF(door)
		PATROL_LOG("[pawn] successfully opened door [door]")
		return AI_BEHAVIOR_DELAY | AI_BEHAVIOR_SUCCEEDED

	// Door didn't open - it's probably locked or we don't have access
	// Add to failed list so we always attack it from now on
	var/list/failed_doors = controller.blackboard["_failed_blocking_doors"]
	if(!failed_doors)
		failed_doors = list()
		controller.blackboard["_failed_blocking_doors"] = failed_doors
	failed_doors[REF(door)] = TRUE
	PATROL_LOG("[pawn] failed to open door [door] - will attack it")
	return AI_BEHAVIOR_DELAY | AI_BEHAVIOR_SUCCEEDED

/datum/ai_behavior/try_open_door/finish_action(datum/ai_controller/controller, succeeded, door_key)
	. = ..()
	controller.clear_blackboard_key(door_key)

/**
 * Attack door subtree for patrol behavior.
 * When adjacent to a locked door (that failed to open), attack it.
 */
/datum/ai_planning_subtree/attack_patrol_door
	var/target_key = BB_MOB_PATROL_TARGET

/datum/ai_planning_subtree/attack_patrol_door/SelectBehaviors(datum/ai_controller/controller, seconds_per_tick)
	// Don't do patrol door stuff if we have a combat target
	if(controller.blackboard_key_exists(BB_BASIC_MOB_CURRENT_TARGET))
		return

	var/obj/machinery/door/target_door = controller.blackboard[target_key]
	if(QDELETED(target_door))
		return

	// Only attack if door is closed (locked)
	if(!target_door.density)
		return

	var/mob/living/pawn = controller.pawn

	// Only attack when adjacent
	if(get_dist(pawn, target_door) > 1)
		return

	// Only attack if we know this door won't open (from failed list)
	var/list/failed_doors = controller.blackboard["_failed_blocking_doors"]
	if(!failed_doors || !failed_doors[REF(target_door)])
		return  // Haven't tried to open it yet

	// Attack the door
	PATROL_LOG("[pawn] ATTACKING locked door [target_door.name]")
	controller.set_blackboard_key(BB_DOOR_TO_OPEN, target_door)
	controller.queue_behavior(/datum/ai_behavior/attack_door, BB_DOOR_TO_OPEN)
	return SUBTREE_RETURN_FINISH_PLANNING

/**
 * Behavior that attacks a door - uses ranged attack if available, otherwise melee
 */
/datum/ai_behavior/attack_door
	action_cooldown = 1.2 SECONDS
	behavior_flags = NONE

/datum/ai_behavior/attack_door/setup(datum/ai_controller/controller, door_key)
	var/obj/machinery/door/door = controller.blackboard[door_key]
	if(QDELETED(door) || !door.density)
		return FALSE
	return TRUE

/datum/ai_behavior/attack_door/perform(seconds_per_tick, datum/ai_controller/controller, door_key)
	var/obj/machinery/door/door = controller.blackboard[door_key]
	var/mob/living/basic/pawn = controller.pawn

	if(QDELETED(door) || !door.density)
		// Door opened/destroyed - remove from all tracking lists
		var/door_ref = REF(door)
		var/list/failed_doors = controller.blackboard["_failed_blocking_doors"]
		if(failed_doors)
			failed_doors -= door_ref
		var/list/attack_times = controller.blackboard["_blocking_door_attack_times"]
		if(attack_times)
			attack_times -= door_ref
		var/list/skipped_doors = controller.blackboard["_skipped_blocking_doors"]
		if(skipped_doors)
			skipped_doors -= door_ref
		return AI_BEHAVIOR_DELAY | AI_BEHAVIOR_SUCCEEDED

	// Must be adjacent to attack - if not, fail so we can move closer
	var/door_dist = get_dist(pawn, door)
	if(door_dist > 1)
		PATROL_LOG("[pawn] not adjacent to door [door.name] (dist=[door_dist]), cannot attack")
		return AI_BEHAVIOR_DELAY | AI_BEHAVIOR_FAILED

	// Always use melee attack for door breaking (like blobbernauts/standard troopers)
	// This is more reliable than ranged attacks and saves ammo for combat
	pawn.melee_attack(door)
	PATROL_LOG("[pawn] smashing door [door.name]")
	return AI_BEHAVIOR_DELAY | AI_BEHAVIOR_SUCCEEDED

/datum/ai_behavior/attack_door/finish_action(datum/ai_controller/controller, succeeded, door_key)
	. = ..()
	controller.clear_blackboard_key(door_key)

// ========== ROOM EXPLORATION SUBTREE ==========

/**
 * Planning subtree for room exploration behavior.
 * When BB_EXPLORING_ROOM is set, visits targets (closets and waypoint turfs)
 * to simulate searching/exploring the room.
 */
/datum/ai_planning_subtree/explore_room

/datum/ai_planning_subtree/explore_room/SelectBehaviors(datum/ai_controller/controller, seconds_per_tick)
	// Not exploring? Skip
	var/exploring_room = controller.blackboard[BB_EXPLORING_ROOM]
	if(!exploring_room)
		return

	// Don't explore if we have a combat target
	if(controller.blackboard_key_exists(BB_BASIC_MOB_CURRENT_TARGET))
		return

	var/mob/living/pawn = controller.pawn
	if(!pawn)
		return

	// Get targets and current index
	var/list/targets = controller.blackboard[BB_EXPLORATION_TARGETS]
	var/target_index = controller.blackboard[BB_EXPLORATION_INDEX] || 1

	// Exploration complete?
	if(!length(targets) || target_index > length(targets))
		PATROL_LOG("[pawn] exploration of [exploring_room] complete")
		clear_exploration_state(controller)
		return

	// Get current target
	var/atom/current_target = targets[target_index]

	// Validate target - if invalid, advance and block patrol from taking over
	if(QDELETED(current_target))
		controller.set_blackboard_key(BB_EXPLORATION_INDEX, target_index + 1)
		return SUBTREE_RETURN_FINISH_PLANNING

	// Skip already-opened closets
	if(istype(current_target, /obj/structure/closet))
		var/obj/structure/closet/closet = current_target
		if(closet.opened)
			controller.set_blackboard_key(BB_EXPLORATION_INDEX, target_index + 1)
			return SUBTREE_RETURN_FINISH_PLANNING

	// Set as current target for behaviors
	controller.set_blackboard_key(BB_EXPLORATION_TARGET, current_target)

	var/target_dist = get_dist(pawn, current_target)

	// If adjacent to target, perform appropriate action
	if(target_dist <= 1)
		if(istype(current_target, /obj/structure/closet))
			// Open the closet
			controller.queue_behavior(/datum/ai_behavior/explore_open_closet, BB_EXPLORATION_TARGET)
			return SUBTREE_RETURN_FINISH_PLANNING
		else
			// It's a turf waypoint - we reached it, advance
			PATROL_LOG("[pawn] reached waypoint in [exploring_room]")
			controller.set_blackboard_key(BB_EXPLORATION_INDEX, target_index + 1)
			// IMPORTANT: Return FINISH_PLANNING to prevent patrol from taking over
			return SUBTREE_RETURN_FINISH_PLANNING

	// Not adjacent - travel to target
	controller.queue_behavior(/datum/ai_behavior/explore_travel, BB_EXPLORATION_TARGET)
	return SUBTREE_RETURN_FINISH_PLANNING

/**
 * Clear exploration state from controller.
 */
/proc/clear_exploration_state(datum/ai_controller/controller)
	controller.clear_blackboard_key(BB_EXPLORING_ROOM)
	controller.clear_blackboard_key(BB_EXPLORATION_TARGETS)
	controller.clear_blackboard_key(BB_EXPLORATION_INDEX)
	controller.clear_blackboard_key(BB_EXPLORATION_TARGET)

/**
 * Travel behavior for exploration targets.
 * Uses JPS pathfinding to reach closets/waypoints.
 */
/datum/ai_behavior/explore_travel
	required_distance = 1
	behavior_flags = AI_BEHAVIOR_REQUIRE_MOVEMENT | AI_BEHAVIOR_CAN_PLAN_DURING_EXECUTION

/datum/ai_behavior/explore_travel/setup(datum/ai_controller/controller, target_key)
	var/atom/target = controller.blackboard[target_key]
	if(QDELETED(target))
		return FALSE
	var/turf/target_turf = get_turf(target)
	if(!target_turf)
		return FALSE
	controller.set_movement_target(type, target_turf)
	return TRUE

/datum/ai_behavior/explore_travel/perform(seconds_per_tick, datum/ai_controller/controller, target_key)
	var/atom/target = controller.blackboard[target_key]
	// Succeed if we're adjacent or target is gone
	if(QDELETED(target) || get_dist(controller.pawn, target) <= 1)
		return AI_BEHAVIOR_DELAY | AI_BEHAVIOR_SUCCEEDED
	return AI_BEHAVIOR_DELAY

/datum/ai_behavior/explore_travel/finish_action(datum/ai_controller/controller, succeeded, target_key)
	. = ..()

/**
 * Behavior that opens a closet during exploration.
 */
/datum/ai_behavior/explore_open_closet
	action_cooldown = 1.2 SECONDS
	behavior_flags = NONE

/datum/ai_behavior/explore_open_closet/setup(datum/ai_controller/controller, target_key)
	var/obj/structure/closet/closet = controller.blackboard[target_key]
	if(QDELETED(closet))
		return FALSE
	if(closet.opened)
		return FALSE
	return TRUE

/datum/ai_behavior/explore_open_closet/perform(seconds_per_tick, datum/ai_controller/controller, target_key)
	var/obj/structure/closet/closet = controller.blackboard[target_key]
	var/mob/living/basic/pawn = controller.pawn

	if(QDELETED(closet) || closet.opened)
		// Already open or gone - advance index
		var/target_index = controller.blackboard[BB_EXPLORATION_INDEX] || 1
		controller.set_blackboard_key(BB_EXPLORATION_INDEX, target_index + 1)
		return AI_BEHAVIOR_DELAY | AI_BEHAVIOR_SUCCEEDED

	// If locked or welded, attack it to break it open
	if(closet.locked || closet.welded)
		pawn.melee_attack(closet)
		PATROL_LOG("[pawn] attacking locked/welded closet [closet.name]")
		return AI_BEHAVIOR_DELAY | AI_BEHAVIOR_SUCCEEDED  // Keep attacking until it opens

	// Unlocked - just open it
	var/old_combat_mode = pawn.combat_mode
	pawn.combat_mode = FALSE
	closet.open(pawn)
	pawn.combat_mode = old_combat_mode

	PATROL_LOG("[pawn] opened closet [closet.name] during exploration")

	// Scan for crew hiding inside - they'll be on/near the closet's turf now
	var/turf/closet_turf = get_turf(closet)
	if(closet_turf)
		for(var/mob/living/carbon/hiding_crew in range(1, closet_turf))
			if(hiding_crew.stat != DEAD)
				// Found a live crew member! Target them immediately
				controller.set_blackboard_key(BB_BASIC_MOB_CURRENT_TARGET, hiding_crew)
				PATROL_LOG("[pawn] found [hiding_crew] hiding in closet! Targeting!")
				break

	// Advance to next target
	var/target_index = controller.blackboard[BB_EXPLORATION_INDEX] || 1
	controller.set_blackboard_key(BB_EXPLORATION_INDEX, target_index + 1)

	return AI_BEHAVIOR_DELAY | AI_BEHAVIOR_SUCCEEDED

/datum/ai_behavior/explore_open_closet/finish_action(datum/ai_controller/controller, succeeded, target_key)
	. = ..()

/**
 * Aggressive target finding subtree that uses range() instead of hearers().
 * This bypasses TG's broken proximity field system.
 */
/datum/ai_planning_subtree/aggressive_find_target
	/// Range to scan for targets
	var/scan_range = 9

/datum/ai_planning_subtree/aggressive_find_target/SelectBehaviors(datum/ai_controller/controller, seconds_per_tick)
	var/mob/living/pawn = controller.pawn
	if(!pawn || !isturf(pawn.loc))
		return

	// Already have a valid target? Validate it
	var/atom/current_target = controller.blackboard[BB_BASIC_MOB_CURRENT_TARGET]
	if(!QDELETED(current_target))
		// Check if target is a dead mob - if so, clear it and find a new one
		if(isliving(current_target))
			var/mob/living/living_target = current_target
			if(living_target.stat == DEAD)
				controller.clear_blackboard_key(BB_BASIC_MOB_CURRENT_TARGET)
				// Fall through to find new target
			else if(get_dist(pawn, living_target) <= 1 && !pawn.CanReach(living_target))
				// Adjacent but unreachable (behind windoor, etc) - clear and find new one
				controller.clear_blackboard_key(BB_BASIC_MOB_CURRENT_TARGET)
				// Fall through to find new target
			else
				return  // Target is alive (and reachable if adjacent), keep it
		else
			return  // Non-mob target, keep it

	var/datum/targeting_strategy/targeting_strategy = GET_TARGETING_STRATEGY(controller.blackboard[BB_TARGETING_STRATEGY])
	if(!targeting_strategy)
		PATROL_LOG("[pawn] aggressive_find_target: No targeting strategy!")
		return

	// Use range() instead of hearers() - more reliable on shuttles
	var/list/potential_targets = list()
	for(var/mob/living/potential_target in range(scan_range, pawn))
		if(potential_target == pawn)
			continue
		// Skip dead mobs - don't waste time attacking corpses
		if(potential_target.stat == DEAD)
			continue
		if(targeting_strategy.can_attack(pawn, potential_target))
			potential_targets += potential_target

	if(!length(potential_targets))
		return

	// Pick closest target
	var/mob/living/best_target
	var/best_dist = INFINITY
	for(var/mob/living/target as anything in potential_targets)
		var/dist = get_dist(pawn, target)
		if(dist < best_dist)
			best_dist = dist
			best_target = target

	if(best_target)
		controller.set_blackboard_key(BB_BASIC_MOB_CURRENT_TARGET, best_target)
		PATROL_LOG("[pawn] aggressive_find_target: Found target [best_target] at dist=[best_dist]")

/**
 * Override of attack_obstacle_in_path that includes mobs in blocking checks.
 * Base TG uses exclude_mobs = TRUE which prevents attacking mobs blocking the path during chase.
 */
/datum/ai_planning_subtree/attack_obstacle_in_path/trooper/include_mobs
	attack_behaviour = /datum/ai_behavior/attack_obstructions/trooper/include_mobs

/datum/ai_planning_subtree/attack_obstacle_in_path/trooper/include_mobs/SelectBehaviors(datum/ai_controller/controller, seconds_per_tick)
	var/atom/target = controller.blackboard[target_key]
	if(QDELETED(target))
		return

	var/turf/next_step = get_step_towards(controller.pawn, target)
	// Use exclude_mobs = FALSE to detect mobs blocking the path
	if (!next_step.is_blocked_turf(exclude_mobs = FALSE, source_atom = controller.pawn))
		return

	controller.queue_behavior(attack_behaviour, target_key)
	// Don't cancel future planning, maybe we can move now

/datum/ai_behavior/attack_obstructions/trooper/include_mobs
	action_cooldown = 1.2 SECONDS

/datum/ai_behavior/attack_obstructions/trooper/include_mobs/attack_in_direction(datum/ai_controller/controller, mob/living/basic/basic_mob, direction)
	var/turf/next_step = get_step(basic_mob, direction)
	// Use exclude_mobs = FALSE to detect mobs blocking the path
	if (!next_step.is_blocked_turf(exclude_mobs = FALSE, source_atom = controller.pawn))
		return FALSE

	// First check for mobs blocking the path and attack them
	for (var/mob/living/blocking_mob in next_step)
		if (blocking_mob == basic_mob)
			continue
		// Attack the blocking mob
		basic_mob.melee_attack(blocking_mob)
		return TRUE

	// Then check for objects (original behavior)
	for (var/obj/object as anything in next_step.contents)
		if (!can_smash_object(basic_mob, object))
			continue
		basic_mob.melee_attack(object)
		return TRUE

	if (can_attack_turfs)
		basic_mob.melee_attack(next_step)
		return TRUE
	return FALSE

/**
 * Trooper AI controller variant that patrols door-to-door when not in combat.
 * Uses JPS pathfinding for reliable navigation through ship interiors.
 * Includes room exploration: searches lockers and visits waypoints in each room.
 */
/datum/ai_controller/basic_controller/trooper/patrolling
	ai_movement = /datum/ai_movement/jps  // JPS pathfinding instead of basic_avoidance
	planning_subtrees = list(
		/datum/ai_planning_subtree/escape_captivity,
		/datum/ai_planning_subtree/aggressive_find_target,
		/datum/ai_planning_subtree/attack_obstacle_in_path/trooper/include_mobs,
		/datum/ai_planning_subtree/basic_melee_attack_subtree,
		/datum/ai_planning_subtree/handle_blocking_door,
		/datum/ai_planning_subtree/explore_room,           // Room exploration - after door handling, before patrol
		/datum/ai_planning_subtree/patrol_path,
		/datum/ai_planning_subtree/try_open_door_in_path,
		/datum/ai_planning_subtree/attack_patrol_door,
	)

/datum/ai_controller/basic_controller/trooper/ranged/patrolling
	ai_movement = /datum/ai_movement/jps
	planning_subtrees = list(
		/datum/ai_planning_subtree/escape_captivity,
		/datum/ai_planning_subtree/aggressive_find_target,
		/datum/ai_planning_subtree/attack_obstacle_in_path/trooper/include_mobs,
		/datum/ai_planning_subtree/basic_ranged_attack_subtree/trooper,
		/datum/ai_planning_subtree/handle_blocking_door,
		/datum/ai_planning_subtree/explore_room,           // Room exploration - after door handling, before patrol
		/datum/ai_planning_subtree/patrol_path,
		/datum/ai_planning_subtree/try_open_door_in_path,
		/datum/ai_planning_subtree/attack_patrol_door,
	)

/// Patrolling version for melee boss mobs
/datum/ai_controller/basic_controller/trooper/patrolling/boss
	ai_movement = /datum/ai_movement/jps
	planning_subtrees = list(
		/datum/ai_planning_subtree/escape_captivity,
		/datum/ai_planning_subtree/aggressive_find_target,
		/datum/ai_planning_subtree/attack_obstacle_in_path/trooper/include_mobs,
		/datum/ai_planning_subtree/basic_melee_attack_subtree,
		/datum/ai_planning_subtree/handle_blocking_door,
		/datum/ai_planning_subtree/explore_room,           // Room exploration - after door handling, before patrol
		/datum/ai_planning_subtree/patrol_path,
		/datum/ai_planning_subtree/try_open_door_in_path,
		/datum/ai_planning_subtree/attack_patrol_door,
	)

/// Patrolling version for ranged boss mobs
/datum/ai_controller/basic_controller/trooper/ranged/patrolling/boss
	ai_movement = /datum/ai_movement/jps
	planning_subtrees = list(
		/datum/ai_planning_subtree/escape_captivity,
		/datum/ai_planning_subtree/aggressive_find_target,
		/datum/ai_planning_subtree/attack_obstacle_in_path/trooper/include_mobs,
		/datum/ai_planning_subtree/basic_ranged_attack_subtree/trooper,
		/datum/ai_planning_subtree/handle_blocking_door,
		/datum/ai_planning_subtree/explore_room,           // Room exploration - after door handling, before patrol
		/datum/ai_planning_subtree/patrol_path,
		/datum/ai_planning_subtree/try_open_door_in_path,
		/datum/ai_planning_subtree/attack_patrol_door,
	)
