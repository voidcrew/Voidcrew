// Ship Combat Shield Generator
// Protects the ship from missiles and meteors
// Power scales with ship mass, upgradable via stock parts
// Controlled via combat console power slider (0-200%)

/obj/machinery/ship_combat/shield_generator
	name = "ship shield generator"
	desc = "A ship-mounted deflector shield generator. Protects against missiles and meteors. Link to a weapons system with a multitool to control."
	icon = 'icons/obj/machines/shield_generator.dmi'  // Placeholder - TODO: custom icon
	icon_state = "shield_wall_gen"  // Placeholder
	density = TRUE
	anchored = TRUE
	power_channel = AREA_USAGE_EQUIP
	circuit = /obj/item/circuitboard/machine/ship_combat/shield_generator
	/// No power draw when shields are off - active draw is set dynamically via update_power_draw()
	idle_power_usage = 0

	// Stock part integration
	// Capacitors: +50% max shield health per tier
	// Micro-lasers: +30% base regen rate per tier
	// Servos: -15% power consumption per tier

	/// This generator's max shield health contribution (from base + parts)
	var/max_shield_health = SHIP_SHIELD_BASE_HEALTH
	/// This generator's regeneration rate contribution per second (from base + parts)
	var/regen_rate = SHIP_SHIELD_BASE_REGEN
	/// Calculated power efficiency multiplier (from parts, 0-1 range, lower = more efficient)
	var/power_efficiency = 1

	/// Power allocation set by combat console (0.0 to 2.0) - starts at 0 (off)
	/// This is synced with the ship's shield_power_allocation
	var/power_allocation = 0

	/// Is this generator contributing to the shield pool?
	var/active = FALSE

	/// Reference to linked combat console
	var/datum/weakref/linked_console_ref
	/// Reference to our ship
	var/datum/weakref/linked_ship_ref

	/// Cached ship mass for power calculations
	var/cached_ship_mass = 500

	/// List of active shield wall structures
	var/list/obj/structure/ship_shield_wall/shield_walls = list()

	/// Debug logging for shield direction calculations (disable for performance)
	var/debug_shield_directions = FALSE

	/// Real-time positional sound when generator is active
	var/datum/realtime_positional_sound/generator_sound

	/// Cached boundary turfs for this ship (expensive to calculate)
	var/list/cached_boundary_turfs
	/// Whether the boundary cache is valid
	var/boundary_cache_valid = FALSE

	/// Flag: walls were destroyed and need respawning after shuttle move completes
	var/pending_wall_respawn = FALSE
	/// Flag: shuttle move has completed, waiting for dock info
	var/shuttle_move_done = FALSE
	/// Flag: we are currently in a ship-to-ship dock (set/cleared ONLY by signals at correct timing)
	var/in_ship_to_ship_dock = FALSE

/obj/machinery/ship_combat/shield_generator/Initialize(mapload)
	. = ..()
	generator_sound = new(src, 'voidcrew/sound/machines/forcefield/shieldgen.ogg', 15, 7)
	// Register for shuttle move signals - destroy walls right before move, respawn after
	RegisterSignal(src, COMSIG_ATOM_BEFORE_SHUTTLE_MOVE, PROC_REF(on_shuttle_move_start))
	RegisterSignal(src, COMSIG_ATOM_AFTER_SHUTTLE_MOVE, PROC_REF(on_shuttle_move_complete))
	// Start processing for regeneration
	begin_processing()
	// Try to auto-link after a short delay
	addtimer(CALLBACK(src, PROC_REF(attempt_auto_link)), 2 SECONDS)

/obj/machinery/ship_combat/shield_generator/Destroy()
	destroy_shield_walls()
	QDEL_NULL(generator_sound)
	unlink_console()
	unlink_ship()
	invalidate_boundary_cache()
	return ..()

/obj/machinery/ship_combat/shield_generator/RefreshParts()
	. = ..()

	// Reset to base values
	max_shield_health = SHIP_SHIELD_BASE_HEALTH
	regen_rate = SHIP_SHIELD_BASE_REGEN
	power_efficiency = 1

	// Apply stock part modifiers
	// Each part tier above 1 adds a bonus
	for(var/datum/stock_part/capacitor/cap in component_parts)
		max_shield_health += SHIP_SHIELD_BASE_HEALTH * SHIELD_CAPACITOR_HEALTH_MULT * (cap.tier - 1)

	for(var/datum/stock_part/micro_laser/laser in component_parts)
		regen_rate += SHIP_SHIELD_BASE_REGEN * SHIELD_LASER_REGEN_MULT * (laser.tier - 1)

	for(var/datum/stock_part/servo/servo in component_parts)
		power_efficiency -= SHIELD_SERVO_EFFICIENCY_MULT * (servo.tier - 1)

	// Clamp efficiency to prevent negative power
	power_efficiency = max(power_efficiency, 0.1)

	// Update power draw since efficiency changed
	update_power_draw()

/obj/machinery/ship_combat/shield_generator/examine(mob/user)
	. = ..()
	var/obj/structure/overmap/ship/ship = linked_ship_ref?.resolve()
	. += span_notice("Generator Status: [active ? "ACTIVE" : "OFFLINE"]")
	if(ship)
		. += span_notice("Ship Shield Status: [ship.shields_active ? "ACTIVE" : (ship.shields_broken ? "RECHARGING" : "OFFLINE")]")
		if(ship.shields_active)
			. += span_notice("Shield Health: [round(ship.shield_health)]/[round(ship.shield_max_health)][ship.shield_overhealth > 0 ? " (+[round(ship.shield_overhealth)] overhealth)" : ""]")
			. += span_notice("Regeneration: [round(ship.shield_regen_rate * ship.shield_power_allocation, 0.1)]/sec")
		if(ship.shields_broken)
			if(!COOLDOWN_FINISHED(ship, shield_reactivation_cooldown))
				. += span_warning("Cooldown: [DisplayTimeText(COOLDOWN_TIMELEFT(ship, shield_reactivation_cooldown))] remaining")
			else
				. += span_notice("Ready to reactivate.")
	. += span_notice("This generator contributes: [round(max_shield_health)] max health, [round(regen_rate, 0.1)]/sec regen")
	. += span_notice("Power Draw: [round(get_power_draw())]W")
	. += span_notice("Power Allocation: [round(power_allocation * 100)]%")
	. += span_notice("Efficiency: [round((1 - power_efficiency) * 100)]% power reduction")

	var/obj/machinery/computer/camera_advanced/ship_combat/console = linked_console_ref?.resolve()
	if(console)
		. += span_notice("Linked to: [console]")
	else
		. += span_warning("Not linked to a weapons system. Use a multitool to link.")

/obj/machinery/ship_combat/shield_generator/update_icon_state()
	. = ..()
	if(machine_stat & BROKEN)
		icon_state = "shield_wall_gen"
	else if(active)
		icon_state = "shield_wall_gen_on"
	else
		icon_state = "shield_wall_gen"

// ========== PROCESSING ==========

/obj/machinery/ship_combat/shield_generator/process(seconds_per_tick)
	// Check for power loss
	if(machine_stat & NOPOWER)
		if(active)
			power_loss_shutdown()
		return

	// If allocation is 0, shields are off
	if(power_allocation <= 0)
		if(active)
			deactivate_generator()
		return

	// Can't run shields while docked to another ship
	if(is_docked_to_ship())
		if(active)
			deactivate_generator()
		return

	// Check if ship shields are broken (on cooldown) - can't activate during cooldown
	var/obj/structure/overmap/ship/ship = linked_ship_ref?.resolve()
	if(ship?.shields_broken)
		return

	// Activate this generator if not already
	if(!active)
		activate_generator()

	// Shield regeneration is handled by ship.process() - no need to coordinate here

// ========== POWER CALCULATIONS ==========

/// Returns the current power draw based on ship mass, allocation, and efficiency
/// Formula: (BASE_COST + mass * POWER_PER_MASS) * allocation * efficiency
/obj/machinery/ship_combat/shield_generator/proc/get_power_draw()
	return (SHIP_SHIELD_BASE_POWER_COST + cached_ship_mass * SHIP_SHIELD_POWER_PER_MASS) * power_allocation * power_efficiency

/// Updates cached ship mass from the linked ship
/obj/machinery/ship_combat/shield_generator/proc/update_ship_mass()
	var/obj/structure/overmap/ship/ship = linked_ship_ref?.resolve()
	if(ship)
		cached_ship_mass = max(ship.mass, 100)  // Minimum 100 mass
	else
		cached_ship_mass = 500  // Default

/// Invalidates the cached boundary turfs, forcing recalculation on next use
/// Call this if ship structure changes (hull breach, expansion, etc.)
/obj/machinery/ship_combat/shield_generator/proc/invalidate_boundary_cache()
	boundary_cache_valid = FALSE
	cached_boundary_turfs = null

/// Returns a list of SPACE turfs adjacent to the ship (where shield walls will spawn)
/// Results are cached for performance - call invalidate_boundary_cache() if ship structure changes
/obj/machinery/ship_combat/shield_generator/proc/get_ship_boundary_turfs()
	// Return cached result if valid
	if(boundary_cache_valid && cached_boundary_turfs)
		return cached_boundary_turfs

	var/list/boundary_turfs = list()
	var/obj/structure/overmap/ship/ship = linked_ship_ref?.resolve()
	if(!ship?.shuttle?.shuttle_areas)
		return boundary_turfs

	var/list/ship_areas = ship.shuttle.shuttle_areas

	// First pass: Get all turfs in ship areas and find cardinally adjacent space turfs
	// Uses CHECK_TICK to yield periodically and prevent frame drops on large ships
	var/list/candidate_turfs = list()
	var/min_x = INFINITY
	var/min_y = INFINITY
	var/max_x = 0
	var/max_y = 0
	var/our_z = 0
	for(var/area/ship_area in ship_areas)
		for(var/turf/T in ship_area)
			CHECK_TICK
			// Track bounding box of ship
			min_x = min(min_x, T.x)
			min_y = min(min_y, T.y)
			max_x = max(max_x, T.x)
			max_y = max(max_y, T.y)
			our_z = T.z
			// Check each cardinal direction for non-ship turfs
			for(var/dir in GLOB.cardinals)
				var/turf/neighbor = get_step(T, dir)
				// If neighbor is NOT part of ship (space or planet turfs), add it as a candidate boundary turf
				if(neighbor && !(get_area(neighbor) in ship_areas))
					candidate_turfs |= neighbor  // Use |= to avoid duplicates

	debug_log("=== BOUNDARY DETECTION START ===")
	debug_log("Found [length(candidate_turfs)] candidate turfs before filtering")
	debug_log("Ship bounding box: ([min_x],[min_y]) to ([max_x],[max_y]) on z=[our_z]")

	// EXTERIOR DETECTION: Flood fill from outside the ship to find all exterior space
	// This ensures we only generate shields on the OUTER boundary, not inside internal holes
	var/list/exterior_space = list()
	var/list/flood_queue = list()

	// Expand bounding box by 2 for flood fill starting points
	var/flood_min_x = max(1, min_x - 2)
	var/flood_min_y = max(1, min_y - 2)
	var/flood_max_x = min(world.maxx, max_x + 2)
	var/flood_max_y = min(world.maxy, max_y + 2)

	// Seed the flood fill with all non-ship turfs along the edges of the bounding box
	// These are definitely exterior (outside the ship boundary)
	// Use area-based check instead of isspaceturf() so this works on planets too
	for(var/x_coord in flood_min_x to flood_max_x)
		var/turf/top_edge = locate(x_coord, flood_max_y, our_z)
		var/turf/bottom_edge = locate(x_coord, flood_min_y, our_z)
		if(top_edge && !(get_area(top_edge) in ship_areas))
			flood_queue += top_edge
			exterior_space[top_edge] = TRUE
		if(bottom_edge && !(get_area(bottom_edge) in ship_areas))
			flood_queue += bottom_edge
			exterior_space[bottom_edge] = TRUE
	for(var/y_coord in flood_min_y to flood_max_y)
		var/turf/left_edge = locate(flood_min_x, y_coord, our_z)
		var/turf/right_edge = locate(flood_max_x, y_coord, our_z)
		if(left_edge && !(get_area(left_edge) in ship_areas))
			flood_queue += left_edge
			exterior_space[left_edge] = TRUE
		if(right_edge && !(get_area(right_edge) in ship_areas))
			flood_queue += right_edge
			exterior_space[right_edge] = TRUE

	debug_log("Flood fill starting with [length(flood_queue)] edge turfs")

	// Validate that bounding box was actually calculated (min values should have been set)
	if(min_x == INFINITY || min_y == INFINITY)
		log_shuttle("SHIELD ERROR: Bounding box calculation failed - min_x=[min_x], min_y=[min_y]. Ship has no valid turfs in shuttle_areas.")
		return boundary_turfs

	// Flood fill to find all connected exterior space
	// Uses CHECK_TICK to yield periodically and prevent frame drops on large ships
	var/flood_iterations = 0
	var/max_flood_iterations = 10000  // Safety limit
	while(length(flood_queue) && flood_iterations < max_flood_iterations)
		flood_iterations++
		var/turf/current = flood_queue[1]
		flood_queue -= current

		// Check all 4 cardinal neighbors
		for(var/dir in GLOB.cardinals)
			var/turf/neighbor = get_step(current, dir)
			if(!neighbor)
				continue
			// Skip if already processed
			if(exterior_space[neighbor])
				continue
			// Skip if inside ship area
			if(get_area(neighbor) in ship_areas)
				continue
			// Stay within expanded bounding box
			if(neighbor.x < flood_min_x || neighbor.x > flood_max_x)
				continue
			if(neighbor.y < flood_min_y || neighbor.y > flood_max_y)
				continue

			// This is exterior (not part of ship) - works on space AND planet turfs
			exterior_space[neighbor] = TRUE
			flood_queue += neighbor

		// Yield periodically to prevent frame drops on large ships
		CHECK_TICK

	debug_log("Flood fill complete: [length(exterior_space)] exterior space turfs found in [flood_iterations] iterations")

	// Filter candidates to only include turfs that are EXTERIOR (connected to outside)
	var/list/exterior_candidates = list()
	var/interior_rejected = 0
	for(var/turf/candidate in candidate_turfs)
		if(exterior_space[candidate])
			exterior_candidates += candidate
		else
			interior_rejected++
			debug_log("REJECTED INTERIOR ([candidate.x],[candidate.y]): not connected to exterior space")

	debug_log("Interior filtering: [length(exterior_candidates)] exterior, [interior_rejected] rejected as interior")

	// Filter out "pocket turfs" - space turfs surrounded by ship on 3+ sides
	// Also filter "tunnel turfs" - space turfs with ship on opposite cardinal sides (N+S or E+W)
	// These are narrow indentations/corridors where we want the shield to bridge across instead
	// Uses CHECK_TICK to yield periodically and prevent frame drops
	var/list/rejected_pockets = list()
	for(var/turf/candidate in exterior_candidates)
		CHECK_TICK
		var/ship_neighbor_dirs = NONE
		var/ship_neighbor_count = 0
		var/list/ship_dirs = list()
		for(var/dir in GLOB.cardinals)
			var/turf/neighbor = get_step(candidate, dir)
			if(neighbor && (get_area(neighbor) in ship_areas))
				ship_neighbor_count++
				ship_neighbor_dirs |= dir
				ship_dirs += dir_to_string(dir)

		// Check for tunnel condition: ship on opposite sides (N+S or E+W)
		var/is_tunnel = FALSE
		if((ship_neighbor_dirs & NORTH) && (ship_neighbor_dirs & SOUTH))
			is_tunnel = TRUE
		if((ship_neighbor_dirs & EAST) && (ship_neighbor_dirs & WEST))
			is_tunnel = TRUE

		// If surrounded on 3+ sides, it's a pocket - skip it so shield bridges across
		// If ship is on opposite sides, it's a tunnel - skip it
		if(ship_neighbor_count >= 3)
			rejected_pockets += candidate
			debug_log("REJECTED POCKET ([candidate.x],[candidate.y]): [ship_neighbor_count] ship neighbors ([ship_dirs.Join(",")])")
		else if(is_tunnel)
			rejected_pockets += candidate
			debug_log("REJECTED TUNNEL ([candidate.x],[candidate.y]): ship on opposite sides ([ship_dirs.Join(",")])")
		else
			boundary_turfs |= candidate
			debug_log("ACCEPTED ([candidate.x],[candidate.y]): [ship_neighbor_count] ship neighbors ([ship_dirs.Join(",")])")

	debug_log("Pocket filtering: [length(boundary_turfs)] accepted, [length(rejected_pockets)] rejected as pockets")

	// Second pass: Find gap turfs that are only DIAGONALLY adjacent to ship
	// These occur on diagonal ship edges where turfs don't touch ship cardinally
	// but still need shields to complete the boundary
	// We iterate until no new gaps are found, since gap turfs can chain together
	// Uses CHECK_TICK to yield periodically and prevent frame drops
	var/found_new = TRUE
	var/max_iterations = 10  // Safety limit
	var/iteration = 0
	while(found_new && iteration < max_iterations)
		iteration++
		found_new = FALSE
		var/list/gap_turfs = list()

		for(var/turf/boundary_turf in boundary_turfs)
			CHECK_TICK
			// Check cardinal neighbors of each boundary turf for potential gaps
			for(var/card_dir in GLOB.cardinals)
				var/turf/card_neighbor = get_step(boundary_turf, card_dir)
				if(!card_neighbor)
					continue
				// Skip if already in boundary or part of ship
				if(card_neighbor in boundary_turfs)
					continue
				// Skip if part of ship (we want exterior turfs - space or planet)
				if(get_area(card_neighbor) in ship_areas)
					continue

				// Check if this turf is diagonally adjacent to ship
				// (has ship turf in at least one diagonal direction)
				var/has_diagonal_ship = FALSE
				for(var/check_diag in GLOB.diagonals)
					var/turf/check_neighbor = get_step(card_neighbor, check_diag)
					if(check_neighbor && (get_area(check_neighbor) in ship_areas))
						has_diagonal_ship = TRUE
						break

				// Also check if it has ship in a cardinal direction (shouldn't happen but check anyway)
				if(!has_diagonal_ship)
					continue

				// Verify this turf is NOT cardinally adjacent to ship (those are already detected)
				var/has_cardinal_ship = FALSE
				for(var/check_card in GLOB.cardinals)
					var/turf/check_neighbor = get_step(card_neighbor, check_card)
					if(check_neighbor && (get_area(check_neighbor) in ship_areas))
						has_cardinal_ship = TRUE
						break

				if(has_cardinal_ship)
					continue  // Already should be in boundary from first pass

				// Check how many boundary neighbors this gap turf would have
				// - 1 neighbor = dead end (creates disconnected C shapes) - skip
				// - 2 neighbors = normal corner connection - allow
				// - 3 neighbors = T-junction - allow (wall spawning code handles these)
				// - 4 neighbors = 4-way junction - skip (too complex)
				var/boundary_neighbor_count = 0
				for(var/check_dir in GLOB.cardinals)
					var/turf/potential_neighbor = get_step(card_neighbor, check_dir)
					if(potential_neighbor in boundary_turfs)
						boundary_neighbor_count++
				if(boundary_neighbor_count < 2)
					debug_log("SKIPPED GAP ([card_neighbor.x],[card_neighbor.y]): only [boundary_neighbor_count] boundary neighbor (dead end)")
					continue
				if(boundary_neighbor_count >= 4)
					debug_log("SKIPPED GAP ([card_neighbor.x],[card_neighbor.y]): [boundary_neighbor_count] boundary neighbors (4-way junction)")
					continue

				// This is a valid gap turf - diagonally adjacent to ship with 2-3 boundary neighbors
				gap_turfs |= card_neighbor

		// Add gap turfs to boundary
		if(length(gap_turfs))
			found_new = TRUE
			boundary_turfs |= gap_turfs
			debug_log("Gap iteration [iteration]: Added [length(gap_turfs)] gap turfs")
			for(var/turf/gt in gap_turfs)
				debug_log("  GAP TURF ([gt.x],[gt.y])")

	// Final pass: Remove isolated boundary turfs (turfs with NO boundary neighbors)
	// These are typically corridor entrances that lead into internal spaces
	// where all adjacent turfs were rejected as tunnels/pockets
	// Uses CHECK_TICK to yield periodically and prevent frame drops
	var/list/isolated_turfs = list()
	for(var/turf/bt in boundary_turfs)
		CHECK_TICK
		var/has_boundary_neighbor = FALSE
		for(var/dir in GLOB.cardinals)
			var/turf/neighbor = get_step(bt, dir)
			if((neighbor in boundary_turfs) && !(neighbor in isolated_turfs))
				has_boundary_neighbor = TRUE
				break
		if(!has_boundary_neighbor)
			isolated_turfs += bt
			debug_log("REJECTED ISOLATED ([bt.x],[bt.y]): no boundary neighbors")

	// Remove isolated turfs
	boundary_turfs -= isolated_turfs
	if(length(isolated_turfs))
		debug_log("Isolated filtering: removed [length(isolated_turfs)] isolated turfs")

	debug_log("=== BOUNDARY DETECTION COMPLETE ===")
	debug_log("Final boundary: [length(boundary_turfs)] turfs")
	for(var/turf/bt in boundary_turfs)
		debug_log("  BOUNDARY ([bt.x],[bt.y])")

	// Cache the result for future calls
	cached_boundary_turfs = boundary_turfs
	boundary_cache_valid = TRUE

	return boundary_turfs

/// Returns random boundary turfs for visual effects (up to max_count)
/obj/machinery/ship_combat/shield_generator/proc/get_random_boundary_turfs(max_count = 5)
	var/list/boundary = get_ship_boundary_turfs()
	if(!length(boundary))
		// Fallback to machine location
		var/turf/T = get_turf(src)
		if(T)
			return list(T)
		return list()

	// Shuffle and take up to max_count
	boundary = shuffle(boundary)
	if(length(boundary) > max_count)
		boundary.len = max_count
	return boundary

/// Returns the nearest boundary turf to the given location
/obj/machinery/ship_combat/shield_generator/proc/get_nearest_boundary_turf(turf/from_loc)
	if(!from_loc)
		var/list/fallback = get_random_boundary_turfs(1)
		return length(fallback) ? fallback[1] : get_turf(src)

	var/list/boundary = get_ship_boundary_turfs()
	if(!length(boundary))
		return from_loc  // Fallback to original location

	var/turf/nearest
	var/nearest_dist = INFINITY
	for(var/turf/T in boundary)
		var/dist = get_dist(from_loc, T)
		if(dist < nearest_dist)
			nearest_dist = dist
			nearest = T

	return nearest ? nearest : from_loc

/// Returns the nearest ship turf to the given location (for directional sound)
/obj/machinery/ship_combat/shield_generator/proc/get_nearest_ship_turf(turf/from_loc)
	if(!from_loc)
		return get_turf(src)

	var/obj/structure/overmap/ship/ship = linked_ship_ref?.resolve()
	if(!ship?.shuttle?.shuttle_areas)
		return get_turf(src)

	// Check cardinal neighbors first (most likely for boundary turfs)
	for(var/dir in GLOB.cardinals)
		var/turf/neighbor = get_step(from_loc, dir)
		if(neighbor && (get_area(neighbor) in ship.shuttle.shuttle_areas))
			return neighbor

	// Fallback to generator location
	return get_turf(src)

// ========== SHIELD WALL MANAGEMENT ==========

/// Helper to convert direction to readable string
/obj/machinery/ship_combat/shield_generator/proc/dir_to_string(dir)
	switch(dir)
		if(NORTH)
			return "N"
		if(SOUTH)
			return "S"
		if(EAST)
			return "E"
		if(WEST)
			return "W"
		if(NORTHEAST)
			return "NE"
		if(SOUTHEAST)
			return "SE"
		if(SOUTHWEST)
			return "SW"
		if(NORTHWEST)
			return "NW"
		if(NONE)
			return "NONE"
	// Handle combined dirs
	var/list/parts = list()
	if(dir & NORTH)
		parts += "N"
	if(dir & SOUTH)
		parts += "S"
	if(dir & EAST)
		parts += "E"
	if(dir & WEST)
		parts += "W"
	return parts.Join("+")

/// Debug log for shield direction decisions
/obj/machinery/ship_combat/shield_generator/proc/debug_log(message)
	if(!debug_shield_directions)
		return
	log_shuttle("SHIELD DEBUG: [message]")

/// Calculate the direction a shield wall should face
/// Uses boundary-neighbor awareness: connects TO adjacent shields
/// L-piece directions: NW=left+up, NE=right+up, SW=left+down, SE=right+down
/obj/machinery/ship_combat/shield_generator/proc/get_wall_direction(turf/wall_turf, list/ship_areas, list/boundary)
	// First check boundary neighbors (other shields to connect to)
	var/boundary_dirs = NONE
	for(var/dir in GLOB.cardinals)
		var/turf/neighbor = get_step(wall_turf, dir)
		if(neighbor in boundary)
			boundary_dirs |= dir

	debug_log("([wall_turf.x],[wall_turf.y]) boundary_dirs=[dir_to_string(boundary_dirs)]")

	// Count boundary neighbors
	var/boundary_count = 0
	if(boundary_dirs & NORTH)
		boundary_count++
	if(boundary_dirs & SOUTH)
		boundary_count++
	if(boundary_dirs & EAST)
		boundary_count++
	if(boundary_dirs & WEST)
		boundary_count++

	// T-JUNCTIONS: three boundary neighbors - need special handling
	// We can only connect 2 directions, so we need to pick which 2
	// Priority: connect to corner pieces over continuing straight lines
	if(boundary_count == 3)
		// Find the "odd" direction (not part of a straight line)
		var/odd_dir = NONE
		var/straight_dir1 = NONE
		var/straight_dir2 = NONE
		if((boundary_dirs & NORTH) && (boundary_dirs & SOUTH))
			// N+S straight line, odd is E or W
			straight_dir1 = NORTH
			straight_dir2 = SOUTH
			odd_dir = (boundary_dirs & EAST) ? EAST : WEST
		else if((boundary_dirs & EAST) && (boundary_dirs & WEST))
			// E+W straight line, odd is N or S
			straight_dir1 = EAST
			straight_dir2 = WEST
			odd_dir = (boundary_dirs & NORTH) ? NORTH : SOUTH

		if(odd_dir)
			// Check if the odd direction leads to a corner piece that NEEDS this connection
			var/turf/odd_neighbor = get_step(wall_turf, odd_dir)
			var/odd_neighbor_is_corner = FALSE
			if(odd_neighbor in boundary)
				// Check what direction the odd neighbor expects
				// If it's a corner piece pointing toward us, we MUST connect to it
				var/odd_neighbor_boundary_dirs = NONE
				for(var/dir in GLOB.cardinals)
					var/turf/nn = get_step(odd_neighbor, dir)
					if(nn in boundary)
						odd_neighbor_boundary_dirs |= dir
				// Count odd neighbor's boundary neighbors
				var/odd_neighbor_count = 0
				if(odd_neighbor_boundary_dirs & NORTH) odd_neighbor_count++
				if(odd_neighbor_boundary_dirs & SOUTH) odd_neighbor_count++
				if(odd_neighbor_boundary_dirs & EAST) odd_neighbor_count++
				if(odd_neighbor_boundary_dirs & WEST) odd_neighbor_count++
				// If odd neighbor has exactly 2 boundary neighbors, it's a corner
				if(odd_neighbor_count == 2)
					odd_neighbor_is_corner = TRUE

			if(odd_neighbor_is_corner)
				// Connect to the corner (odd_dir) and one of the straight dirs
				// Pick the straight dir that has a corner/endpoint, not middle of a line
				var/turf/straight1_neighbor = get_step(wall_turf, straight_dir1)
				var/turf/straight2_neighbor = get_step(wall_turf, straight_dir2)

				// Check which straight neighbor is an endpoint (has fewer boundary neighbors)
				var/s1_count = 0
				var/s2_count = 0
				if(straight1_neighbor in boundary)
					for(var/dir in GLOB.cardinals)
						if(get_step(straight1_neighbor, dir) in boundary)
							s1_count++
				if(straight2_neighbor in boundary)
					for(var/dir in GLOB.cardinals)
						if(get_step(straight2_neighbor, dir) in boundary)
							s2_count++

				// Prefer connecting to the neighbor with fewer connections (endpoint)
				var/keep_straight = (s1_count <= s2_count) ? straight_dir1 : straight_dir2
				var/result = get_connector_for_dirs(odd_dir, keep_straight)
				debug_log("  -> T-JUNCTION with corner at [dir_to_string(odd_dir)], connecting [dir_to_string(odd_dir)]+[dir_to_string(keep_straight)], returning [dir_to_string(result)]")
				return result
			else
				// Odd neighbor is not a corner, use straight bar
				if(straight_dir1 == NORTH || straight_dir1 == SOUTH)
					debug_log("  -> T-JUNCTION, odd [dir_to_string(odd_dir)] not corner, returning SOUTH (vertical bar)")
					return SOUTH
				else
					debug_log("  -> T-JUNCTION, odd [dir_to_string(odd_dir)] not corner, returning EAST (horizontal bar)")
					return EAST

	// FOUR-WAY JUNCTION: all four boundary neighbors - must check BEFORE straight edges
	// because straight edge check (N && S) would also match N+S+E+W
	if(boundary_count == 4)
		// Look at which neighbors have EXISTING shields with arms pointing toward us
		// Only trust actual shields, not predictions (too complex for T-junctions)
		var/needed_dirs = NONE
		for(var/dir in GLOB.cardinals)
			var/turf/neighbor = get_step(wall_turf, dir)
			if(!(neighbor in boundary))
				continue

			// Check what shield direction this neighbor actually has (already spawned)
			var/neighbor_shield_dir = NONE
			for(var/obj/structure/ship_shield_wall/existing in neighbor)
				neighbor_shield_dir = existing.dir
				break

			if(!neighbor_shield_dir)
				// Neighbor doesn't have a shield yet - only predict simple cases (2 neighbors)
				var/neighbor_boundary_dirs = NONE
				for(var/ndir in GLOB.cardinals)
					var/turf/nn = get_step(neighbor, ndir)
					if(nn in boundary)
						neighbor_boundary_dirs |= ndir
				// Count neighbor's boundary neighbors
				var/nb_count = 0
				if(neighbor_boundary_dirs & NORTH) nb_count++
				if(neighbor_boundary_dirs & SOUTH) nb_count++
				if(neighbor_boundary_dirs & EAST) nb_count++
				if(neighbor_boundary_dirs & WEST) nb_count++

				// Only predict simple 2-neighbor cases (corners and bars)
				if(nb_count == 2)
					if(neighbor_boundary_dirs == (NORTH|WEST))
						neighbor_shield_dir = NORTHWEST
					else if(neighbor_boundary_dirs == (NORTH|EAST))
						neighbor_shield_dir = NORTHEAST
					else if(neighbor_boundary_dirs == (SOUTH|WEST))
						neighbor_shield_dir = SOUTHWEST
					else if(neighbor_boundary_dirs == (SOUTH|EAST))
						neighbor_shield_dir = SOUTHEAST
					else if(neighbor_boundary_dirs == (NORTH|SOUTH))
						neighbor_shield_dir = SOUTH
					else if(neighbor_boundary_dirs == (EAST|WEST))
						neighbor_shield_dir = EAST
				// Skip prediction for T-junctions (nb_count==3) - too complex

			if(!neighbor_shield_dir)
				continue  // Can't determine, skip this neighbor

			// What direction would neighbor's arm need to point to reach us?
			var/opposite = NONE
			switch(dir)
				if(NORTH) opposite = SOUTH  // neighbor to our N needs S arm to point at us
				if(SOUTH) opposite = NORTH  // neighbor to our S needs N arm to point at us
				if(EAST) opposite = WEST    // neighbor to our E needs W arm to point at us
				if(WEST) opposite = EAST    // neighbor to our W needs E arm to point at us

			// Get the arms of the neighbor's shield
			var/neighbor_arms = NONE
			switch(neighbor_shield_dir)
				if(NORTH, SOUTH)
					neighbor_arms = NORTH|SOUTH
				if(EAST, WEST)
					neighbor_arms = EAST|WEST
				if(NORTHEAST)
					neighbor_arms = NORTH|EAST
				if(NORTHWEST)
					neighbor_arms = NORTH|WEST
				if(SOUTHEAST)
					neighbor_arms = SOUTH|EAST
				if(SOUTHWEST)
					neighbor_arms = SOUTH|WEST

			if(neighbor_arms & opposite)
				// Neighbor has arm pointing at us, we need arm pointing at them
				needed_dirs |= dir
				debug_log("  4-WAY: neighbor at [dir_to_string(dir)] ([dir_to_string(neighbor_shield_dir)]) has arm toward us, need [dir_to_string(dir)]")

		// Return L-connector for the needed directions
		if(needed_dirs)
			var/result = get_connector_for_dirs_from_bits(needed_dirs)
			if(result)
				debug_log("  -> FOUR-WAY JUNCTION, neighbors need [dir_to_string(needed_dirs)], returning [dir_to_string(result)]")
				return result

		// Fallback if we couldn't determine - just use horizontal bar
		debug_log("  -> FOUR-WAY JUNCTION (fallback), returning EAST (horizontal bar)")
		return EAST

	// STRAIGHT EDGES: boundary neighbors in opposite directions → bar
	if((boundary_dirs & NORTH) && (boundary_dirs & SOUTH))
		debug_log("  -> STRAIGHT N+S, returning SOUTH (vertical bar)")
		return SOUTH  // Vertical bar
	if((boundary_dirs & EAST) && (boundary_dirs & WEST))
		debug_log("  -> STRAIGHT E+W, returning EAST (horizontal bar)")
		return EAST   // Horizontal bar

	// TRUE CORNERS: boundary neighbors in perpendicular directions
	// L-connector direction is determined SOLELY by boundary_dirs
	// The L "opens" toward the direction it faces, arms extend perpendicular
	// N+E boundary neighbors need L with arms pointing N and E = NORTHEAST direction
	if((boundary_dirs & NORTH) && (boundary_dirs & EAST))
		debug_log("  -> CORNER N+E, returning NORTHEAST")
		return NORTHEAST
	if((boundary_dirs & NORTH) && (boundary_dirs & WEST))
		debug_log("  -> CORNER N+W, returning NORTHWEST")
		return NORTHWEST
	if((boundary_dirs & SOUTH) && (boundary_dirs & EAST))
		debug_log("  -> CORNER S+E, returning SOUTHEAST")
		return SOUTHEAST
	if((boundary_dirs & SOUTH) && (boundary_dirs & WEST))
		debug_log("  -> CORNER S+W, returning SOUTHWEST")
		return SOUTHWEST

	// END CAPS: only one boundary neighbor
	// But first check if ship is diagonal - if so, this is a transition point
	// and needs an L-connector, not a bar
	if(boundary_dirs == NORTH || boundary_dirs == SOUTH || boundary_dirs == EAST || boundary_dirs == WEST)
		// Check ship position for diagonal transition
		var/ship_dirs = NONE
		for(var/dir in GLOB.cardinals)
			var/turf/neighbor = get_step(wall_turf, dir)
			if(neighbor && (get_area(neighbor) in ship_areas))
				ship_dirs |= dir

		debug_log("  END CAP: boundary_dirs=[dir_to_string(boundary_dirs)], ship_dirs=[dir_to_string(ship_dirs)]")

		// If ship is diagonal, return L-connector that connects to boundary neighbor + toward SPACE
		// The L should curve AWAY from the ship (toward open space), not into it
		// Ship at S+E means space is at N+W, ship at S+W means space is at N+E, etc.
		if(ship_dirs == (SOUTH|EAST))
			// Ship at S+E, space at N+W - curve toward NW
			if(boundary_dirs == NORTH)
				debug_log("  -> DIAG TRANSITION S+E with N neighbor, returning NORTHWEST (curve to space)")
				return NORTHWEST  // Connect N + W (toward space)
			if(boundary_dirs == WEST)
				debug_log("  -> DIAG TRANSITION S+E with W neighbor, returning NORTHWEST (curve to space)")
				return NORTHWEST  // Connect W + N (toward space)
		if(ship_dirs == (SOUTH|WEST))
			// Ship at S+W, space at N+E - curve toward NE
			if(boundary_dirs == NORTH)
				debug_log("  -> DIAG TRANSITION S+W with N neighbor, returning NORTHEAST (curve to space)")
				return NORTHEAST  // Connect N + E (toward space)
			if(boundary_dirs == EAST)
				debug_log("  -> DIAG TRANSITION S+W with E neighbor, returning NORTHEAST (curve to space)")
				return NORTHEAST  // Connect E + N (toward space)
		if(ship_dirs == (NORTH|EAST))
			// Ship at N+E, space at S+W - curve toward SW
			if(boundary_dirs == SOUTH)
				debug_log("  -> DIAG TRANSITION N+E with S neighbor, returning SOUTHWEST (curve to space)")
				return SOUTHWEST  // Connect S + W (toward space)
			if(boundary_dirs == WEST)
				debug_log("  -> DIAG TRANSITION N+E with W neighbor, returning SOUTHWEST (curve to space)")
				return SOUTHWEST  // Connect W + S (toward space)
		if(ship_dirs == (NORTH|WEST))
			// Ship at N+W, space at S+E - curve toward SE
			if(boundary_dirs == SOUTH)
				debug_log("  -> DIAG TRANSITION N+W with S neighbor, returning SOUTHEAST (curve to space)")
				return SOUTHEAST  // Connect S + E (toward space)
			if(boundary_dirs == EAST)
				debug_log("  -> DIAG TRANSITION N+W with E neighbor, returning SOUTHEAST (curve to space)")
				return SOUTHEAST  // Connect E + S (toward space)

		// Not a diagonal transition, use bar
		if(boundary_dirs == NORTH || boundary_dirs == SOUTH)
			debug_log("  -> END CAP vertical bar, returning SOUTH")
			return SOUTH  // Vertical bar
		if(boundary_dirs == EAST || boundary_dirs == WEST)
			debug_log("  -> END CAP horizontal bar, returning EAST")
			return EAST   // Horizontal bar

	// FALLBACK: No boundary neighbors, use ship-direction logic
	// (for isolated turfs or gap turfs)
	var/ship_dirs = NONE
	for(var/dir in GLOB.cardinals)
		var/turf/neighbor = get_step(wall_turf, dir)
		if(neighbor && (get_area(neighbor) in ship_areas))
			ship_dirs |= dir

	debug_log("  FALLBACK: ship_dirs=[dir_to_string(ship_dirs)]")

	// Straight edges based on ship position
	if(ship_dirs == NORTH || ship_dirs == SOUTH)
		debug_log("  -> FALLBACK straight N/S, returning EAST (horizontal bar)")
		return EAST  // Horizontal bar
	if(ship_dirs == EAST || ship_dirs == WEST)
		debug_log("  -> FALLBACK straight E/W, returning SOUTH (vertical bar)")
		return SOUTH  // Vertical bar

	// Diagonal edges - use alternating L-connector chain
	var/parity = (wall_turf.x + wall_turf.y) % 2

	if(ship_dirs == (SOUTH|EAST))
		var/result = parity ? NORTHWEST : SOUTHEAST
		debug_log("  -> FALLBACK diagonal S+E, parity=[parity], returning [dir_to_string(result)]")
		return result
	if(ship_dirs == (SOUTH|WEST))
		var/result = parity ? NORTHEAST : SOUTHWEST
		debug_log("  -> FALLBACK diagonal S+W, parity=[parity], returning [dir_to_string(result)]")
		return result
	if(ship_dirs == (NORTH|EAST))
		var/result = parity ? SOUTHWEST : NORTHEAST
		debug_log("  -> FALLBACK diagonal N+E, parity=[parity], returning [dir_to_string(result)]")
		return result
	if(ship_dirs == (NORTH|WEST))
		var/result = parity ? SOUTHEAST : NORTHWEST
		debug_log("  -> FALLBACK diagonal N+W, parity=[parity], returning [dir_to_string(result)]")
		return result

	// Default to horizontal
	debug_log("  -> DEFAULT returning EAST")
	return EAST

/// Determines direction for a gap turf based on neighboring boundary turfs
/// Gap turfs aren't cardinally adjacent to ship, so we use diagonal neighbor analysis
/obj/machinery/ship_combat/shield_generator/proc/get_gap_direction(turf/gap_turf, list/boundary)
	var/parity = (gap_turf.x + gap_turf.y) % 2

	// Check which diagonal directions have boundary turfs
	var/has_ne = (get_step(gap_turf, NORTHEAST) in boundary)
	var/has_nw = (get_step(gap_turf, NORTHWEST) in boundary)
	var/has_se = (get_step(gap_turf, SOUTHEAST) in boundary)
	var/has_sw = (get_step(gap_turf, SOUTHWEST) in boundary)

	// Also check cardinal directions for boundary turfs
	var/has_n = (get_step(gap_turf, NORTH) in boundary)
	var/has_s = (get_step(gap_turf, SOUTH) in boundary)
	var/has_e = (get_step(gap_turf, EAST) in boundary)
	var/has_w = (get_step(gap_turf, WEST) in boundary)

	// Determine diagonal chain direction based on which neighbors have boundary turfs
	// NE-SW diagonal chain
	if((has_ne && has_sw) || (has_n && has_e && has_s && has_w))
		return parity ? NORTHEAST : SOUTHWEST
	if(has_ne || (has_n && has_e))
		return parity ? NORTHWEST : SOUTHEAST
	if(has_sw || (has_s && has_w))
		return parity ? NORTHWEST : SOUTHEAST

	// NW-SE diagonal chain
	if(has_nw && has_se)
		return parity ? NORTHWEST : SOUTHEAST
	if(has_nw || (has_n && has_w))
		return parity ? NORTHEAST : SOUTHWEST
	if(has_se || (has_s && has_e))
		return parity ? NORTHEAST : SOUTHWEST

	// Fallback based on cardinal neighbors
	if(has_n && has_e)
		return parity ? NORTHWEST : SOUTHEAST
	if(has_n && has_w)
		return parity ? NORTHEAST : SOUTHWEST
	if(has_s && has_e)
		return parity ? NORTHEAST : SOUTHWEST
	if(has_s && has_w)
		return parity ? NORTHWEST : SOUTHEAST

	// Ultimate fallback
	return parity ? NORTHWEST : SOUTHEAST

/// Spawns shield walls on all boundary turfs with correct directions
/obj/machinery/ship_combat/shield_generator/proc/spawn_shield_walls()
	destroy_shield_walls()
	var/obj/structure/overmap/ship/ship = linked_ship_ref?.resolve()
	if(!ship?.shuttle?.shuttle_areas)
		return

	var/list/ship_areas = ship.shuttle.shuttle_areas
	var/list/boundary = get_ship_boundary_turfs()

	// Filter boundary to only include turfs where we'll actually spawn shields
	// This excludes turfs inside ship areas (hull breaches) so direction calculations are correct
	var/list/spawnable_boundary = list()
	for(var/turf/T in boundary)
		if(!(get_area(T) in ship_areas))
			spawnable_boundary += T

	debug_log("=== WALL SPAWNING START ===")
	debug_log("Boundary turfs: [length(boundary)], Spawnable: [length(spawnable_boundary)]")

	// First pass: spawn shields on all spawnable boundary turfs
	for(var/turf/T in spawnable_boundary)
		var/wall_dir = get_wall_direction(T, ship_areas, spawnable_boundary)
		var/obj/structure/ship_shield_wall/wall = new(T)
		wall.generator_ref = WEAKREF(src)
		wall.setDir(wall_dir)
		shield_walls += wall
		debug_log("SPAWNED WALL ([T.x],[T.y]) dir=[dir_to_string(wall_dir)]")

	// Second pass: build snake chains for TRUE diagonal ship edges
	// Detect diagonal edges by checking boundary turfs where ship is in 2 perpendicular cardinal directions
	var/list/processed_chain_starts = list()  // Track which chains we've started
	for(var/turf/T in spawnable_boundary)
		// Skip if already part of a chain
		if(T in processed_chain_starts)
			continue

		// Check ship configuration - is ship in exactly 2 perpendicular cardinal directions?
		var/ship_dirs = NONE
		for(var/dir in GLOB.cardinals)
			var/turf/neighbor = get_step(T, dir)
			if(neighbor && (get_area(neighbor) in ship_areas))
				ship_dirs |= dir

		// Must be exactly 2 perpendicular directions (diagonal configuration)
		var/diagonal_dir = NONE
		switch(ship_dirs)
			if(NORTH|EAST)
				diagonal_dir = NORTHEAST
			if(NORTH|WEST)
				diagonal_dir = NORTHWEST
			if(SOUTH|EAST)
				diagonal_dir = SOUTHEAST
			if(SOUTH|WEST)
				diagonal_dir = SOUTHWEST

		if(!diagonal_dir)
			continue

		// Verify this diagonal continues (not just a single corner)
		// Check if adjacent boundary turfs ALSO have diagonal ship config
		var/continues = FALSE
		var/list/cardinal_components = list()
		if(ship_dirs & NORTH)
			cardinal_components += NORTH
		if(ship_dirs & SOUTH)
			cardinal_components += SOUTH
		if(ship_dirs & EAST)
			cardinal_components += EAST
		if(ship_dirs & WEST)
			cardinal_components += WEST

		for(var/check_dir in cardinal_components)
			var/turf/adj_boundary = get_step(T, check_dir)
			if(!adj_boundary || !(adj_boundary in spawnable_boundary))
				continue

			// Check if this adjacent boundary ALSO has diagonal ship config
			var/adj_ship_dirs = NONE
			for(var/dir in GLOB.cardinals)
				var/turf/n = get_step(adj_boundary, dir)
				if(n && (get_area(n) in ship_areas))
					adj_ship_dirs |= dir

			if(adj_ship_dirs == ship_dirs)
				continues = TRUE
				break

		// Only build snake chain for TRUE diagonal edges that continue
		if(!continues)
			continue

		debug_log("DIAGONAL EDGE at ([T.x],[T.y]) ship_dirs=[dir_to_string(ship_dirs)] diagonal_dir=[dir_to_string(diagonal_dir)]")

		// Mark this turf as processed
		processed_chain_starts += T

		// The existing shield at T might need to be part of a snake chain
		// Find where to start the chain extension (exterior turf in diagonal direction)
		var/turf/chain_start = get_step(T, diagonal_dir)
		if(!chain_start || (get_area(chain_start) in ship_areas))
			debug_log("  No valid chain start - chain_start is null or part of ship")
			continue

		// Build the snake chain extending into space
		debug_log("  Building chain from ([chain_start.x],[chain_start.y])")
		build_diagonal_shield_chain(chain_start, diagonal_dir, spawnable_boundary)

	debug_log("=== VALIDATION PASS ===")
	// Third pass: validate all shield connections and fix any mismatches
	validate_shield_connections()

/// Builds a snake chain of alternating L-connectors for a diagonal wall section
/// Extends from start_turf in the diagonal direction until hitting existing boundary
/obj/machinery/ship_combat/shield_generator/proc/build_diagonal_shield_chain(turf/start_turf, diagonal_dir, list/boundary)
	// Determine the snake pattern based on diagonal direction
	// Each diagonal has two cardinal components we alternate moving in
	// And two L-connector directions we alternate between
	var/move_dir_1
	var/move_dir_2
	var/connector_1
	var/connector_2

	switch(diagonal_dir)
		if(NORTHEAST)
			// Going top-right: move RIGHT then UP, connectors NORTHWEST/SOUTHEAST
			move_dir_1 = EAST
			move_dir_2 = NORTH
			connector_1 = NORTHWEST  // LEFT+UP
			connector_2 = SOUTHEAST  // DOWN+RIGHT
		if(SOUTHEAST)
			// Going bottom-right: move RIGHT then DOWN, connectors NORTHEAST/SOUTHWEST
			move_dir_1 = EAST
			move_dir_2 = SOUTH
			connector_1 = NORTHEAST  // RIGHT+UP
			connector_2 = SOUTHWEST  // LEFT+DOWN
		if(SOUTHWEST)
			// Going bottom-left: move LEFT then DOWN, connectors SOUTHEAST/NORTHWEST
			move_dir_1 = WEST
			move_dir_2 = SOUTH
			connector_1 = SOUTHEAST  // DOWN+RIGHT
			connector_2 = NORTHWEST  // LEFT+UP
		if(NORTHWEST)
			// Going top-left: move LEFT then UP, connectors SOUTHWEST/NORTHEAST
			move_dir_1 = WEST
			move_dir_2 = NORTH
			connector_1 = SOUTHWEST  // LEFT+DOWN
			connector_2 = NORTHEAST  // RIGHT+UP

	// Build the snake chain
	var/turf/current = start_turf
	var/use_first_connector = TRUE
	var/use_first_move = TRUE
	var/max_iterations = 50  // Safety limit

	// Check for adjacent existing shields to determine starting connector
	// We want to connect TO existing shields, so start with the opposite of what they have
	for(var/dir in GLOB.cardinals)
		var/turf/adj = get_step(start_turf, dir)
		if(!adj)
			continue
		for(var/obj/structure/ship_shield_wall/existing in adj)
			// Found an existing shield - check its direction
			// If it's connector_1, we should start with connector_2 to connect
			// If it's connector_2, we should start with connector_1
			if(existing.dir == connector_1)
				use_first_connector = FALSE
				// Also adjust starting move direction based on where existing shield is
				if(dir == move_dir_1)
					use_first_move = FALSE
				break
			else if(existing.dir == connector_2)
				use_first_connector = TRUE
				if(dir == move_dir_2)
					use_first_move = TRUE
				break

	// Get ship areas to avoid spawning inside ship
	var/obj/structure/overmap/ship/ship = linked_ship_ref?.resolve()
	var/list/ship_areas = ship?.shuttle?.shuttle_areas

	for(var/i in 1 to max_iterations)
		if(!current)
			break
		// Stop if we've reached an existing boundary turf
		if(current in boundary)
			break
		// Never spawn shields inside ship areas
		if(ship_areas && (get_area(current) in ship_areas))
			break
		// Stop if there's already a shield here
		var/already_has_shield = FALSE
		for(var/obj/structure/ship_shield_wall/existing in current)
			already_has_shield = TRUE
			break
		if(already_has_shield)
			break

		// Spawn the shield with alternating connector direction
		var/chain_dir = use_first_connector ? connector_1 : connector_2
		var/obj/structure/ship_shield_wall/wall = new(current)
		wall.generator_ref = WEAKREF(src)
		wall.setDir(chain_dir)
		shield_walls += wall
		debug_log("  CHAIN WALL ([current.x],[current.y]) dir=[dir_to_string(chain_dir)]")

		// Move to next position (alternating between the two move directions)
		var/next_move = use_first_move ? move_dir_1 : move_dir_2
		current = get_step(current, next_move)

		// Alternate for next iteration
		use_first_connector = !use_first_connector
		use_first_move = !use_first_move

/// Returns which cardinal directions a shield direction connects to
/// E.g., NORTHEAST connects NORTH and EAST, SOUTH bar connects NORTH and SOUTH
/obj/machinery/ship_combat/shield_generator/proc/get_connection_dirs(shield_dir)
	switch(shield_dir)
		// L-connectors connect two perpendicular directions
		if(NORTHEAST)
			return list(NORTH, EAST)
		if(NORTHWEST)
			return list(NORTH, WEST)
		if(SOUTHEAST)
			return list(SOUTH, EAST)
		if(SOUTHWEST)
			return list(SOUTH, WEST)
		// Bars connect two opposite directions
		if(NORTH, SOUTH)
			return list(NORTH, SOUTH)  // Vertical bar
		if(EAST, WEST)
			return list(EAST, WEST)    // Horizontal bar
	return list()

/// Checks if a shield direction connects in the given cardinal direction
/obj/machinery/ship_combat/shield_generator/proc/dir_connects(shield_dir, check_dir)
	return check_dir in get_connection_dirs(shield_dir)

/// Returns the shield direction that connects two given cardinal directions
/obj/machinery/ship_combat/shield_generator/proc/get_connector_for_dirs(dir1, dir2)
	// Sort dirs for consistent lookup
	var/combo = dir1 | dir2
	switch(combo)
		if(NORTH|EAST)
			return NORTHEAST
		if(NORTH|WEST)
			return NORTHWEST
		if(SOUTH|EAST)
			return SOUTHEAST
		if(SOUTH|WEST)
			return SOUTHWEST
		if(NORTH|SOUTH)
			return SOUTH  // Vertical bar
		if(EAST|WEST)
			return EAST   // Horizontal bar
	return EAST  // Fallback

/// Returns the shield direction for a bitfield of needed directions
/// Handles case where more than 2 directions are needed by picking the best L-connector
/obj/machinery/ship_combat/shield_generator/proc/get_connector_for_dirs_from_bits(needed_dirs)
	// Count how many directions are needed
	var/count = 0
	if(needed_dirs & NORTH) count++
	if(needed_dirs & SOUTH) count++
	if(needed_dirs & EAST) count++
	if(needed_dirs & WEST) count++

	if(count <= 2)
		// Simple case - just use the existing function
		return get_connector_for_dirs(needed_dirs, NONE)

	// More than 2 directions needed - pick the best pair
	// Prioritize L-connectors (perpendicular) over straight bars
	// Check for perpendicular pairs first
	if((needed_dirs & NORTH) && (needed_dirs & EAST))
		return NORTHEAST
	if((needed_dirs & NORTH) && (needed_dirs & WEST))
		return NORTHWEST
	if((needed_dirs & SOUTH) && (needed_dirs & EAST))
		return SOUTHEAST
	if((needed_dirs & SOUTH) && (needed_dirs & WEST))
		return SOUTHWEST
	// Fallback to straight bars
	if((needed_dirs & NORTH) && (needed_dirs & SOUTH))
		return SOUTH
	if((needed_dirs & EAST) && (needed_dirs & WEST))
		return EAST

	return EAST  // Final fallback

/// Gets the shield wall at a turf location
/obj/machinery/ship_combat/shield_generator/proc/get_shield_at(turf/T)
	if(!T)
		return null
	for(var/obj/structure/ship_shield_wall/wall in T)
		if(wall in shield_walls)
			return wall
	return null

/// Validation pass: walk the boundary and ensure all shields connect properly
/// Fixes any mismatched L-connectors to maintain curve continuity
/obj/machinery/ship_combat/shield_generator/proc/validate_shield_connections()
	if(!length(shield_walls))
		return

	var/list/visited = list()
	var/list/to_process = list()
	var/fixes_made = 0

	// Start from first shield
	to_process += shield_walls[1]

	while(length(to_process))
		var/obj/structure/ship_shield_wall/current = to_process[1]
		to_process -= current

		if(current in visited)
			continue
		visited += current

		var/turf/current_turf = get_turf(current)
		if(!current_turf)
			continue

		// Get which directions this shield expects neighbors
		var/list/my_connections = get_connection_dirs(current.dir)

		// Check each connection direction
		for(var/conn_dir in my_connections)
			var/turf/neighbor_turf = get_step(current_turf, conn_dir)
			var/obj/structure/ship_shield_wall/neighbor = get_shield_at(neighbor_turf)

			if(!neighbor)
				continue

			// Add neighbor to processing queue
			if(!(neighbor in visited))
				to_process += neighbor

			// Check if neighbor connects back to us
			var/reverse_dir = REVERSE_DIR(conn_dir)
			if(!dir_connects(neighbor.dir, reverse_dir))
				// Mismatch! Neighbor doesn't connect back to us

				// Don't try to fix shields that have already been visited - that causes flip-flopping
				if(neighbor in visited)
					debug_log("VALIDATE SKIP: ([neighbor_turf.x],[neighbor_turf.y]) already visited, won't re-fix")
					continue

				// Count how many shield neighbors this shield has - if 3+, it's a T-junction
				// and we can't fix it (would just cause flip-flopping)
				var/neighbor_shield_count = 0
				for(var/check_dir in GLOB.cardinals)
					if(get_shield_at(get_step(neighbor_turf, check_dir)))
						neighbor_shield_count++
				if(neighbor_shield_count >= 3)
					debug_log("VALIDATE SKIP: ([neighbor_turf.x],[neighbor_turf.y]) has [neighbor_shield_count] shield neighbors (T-junction)")
					continue

				// Fix the neighbor to connect properly while keeping its other connection
				var/list/neighbor_connections = get_connection_dirs(neighbor.dir)

				// Find which direction the neighbor DOES connect (that isn't toward us)
				var/other_connection = NONE
				for(var/nc in neighbor_connections)
					if(nc != reverse_dir)
						other_connection = nc
						break

				// If neighbor has another connection, create new dir connecting both
				// Otherwise, just make it connect to us
				var/new_dir
				if(other_connection)
					new_dir = get_connector_for_dirs(reverse_dir, other_connection)
				else
					// No other connection - check what neighbors IT has
					var/list/potential_connections = list()
					for(var/check_dir in GLOB.cardinals)
						if(check_dir == reverse_dir)
							continue
						var/obj/structure/ship_shield_wall/potential = get_shield_at(get_step(neighbor_turf, check_dir))
						if(potential)
							potential_connections += check_dir

					if(length(potential_connections))
						new_dir = get_connector_for_dirs(reverse_dir, potential_connections[1])
					else
						new_dir = get_connector_for_dirs(reverse_dir, reverse_dir)  // Will just be a bar

				if(new_dir != neighbor.dir)
					debug_log("VALIDATE FIX: ([neighbor_turf.x],[neighbor_turf.y]) [dir_to_string(neighbor.dir)] -> [dir_to_string(new_dir)]")
					neighbor.setDir(new_dir)
					fixes_made++

	debug_log("Validation complete: [fixes_made] fixes made, [length(visited)]/[length(shield_walls)] shields checked")

/// Removes ALL shield wall structures at once
/obj/machinery/ship_combat/shield_generator/proc/destroy_shield_walls()
	for(var/obj/structure/ship_shield_wall/wall in shield_walls)
		qdel(wall)
	shield_walls.Cut()

// ========== SHIELD STATE ==========

/// Activates this generator to contribute to the ship's shared shield pool
/// Returns FALSE if activation failed (docked, ship shields broken, etc.)
/obj/machinery/ship_combat/shield_generator/proc/activate_generator()
	log_shuttle("SHIELD DEBUG activate_generator: active=[active], shields_broken=[linked_ship_ref?.resolve()?.shields_broken], is_docked_to_ship=[is_docked_to_ship()]")
	if(active)
		log_shuttle("SHIELD DEBUG: Already active, returning TRUE")
		return TRUE
	var/obj/structure/overmap/ship/ship = linked_ship_ref?.resolve()
	// Can't activate while ship shields are broken/on cooldown
	if(ship?.shields_broken)
		log_shuttle("SHIELD DEBUG: shields_broken=TRUE, returning FALSE")
		return FALSE
	// Can't activate while docked to another ship
	if(is_docked_to_ship())
		log_shuttle("SHIELD DEBUG: is_docked_to_ship=TRUE, returning FALSE")
		return FALSE

	active = TRUE

	update_appearance()
	update_power_draw()
	generator_sound?.start()

	// Recalculate ship shield stats with this generator now contributing
	if(ship)
		ship.recalculate_shield_stats()

		// If this is the first generator coming online, initialize ship shields
		log_shuttle("SHIELD DEBUG activate_generator: ship.shields_active=[ship.shields_active], ship.shields_broken=[ship.shields_broken]")
		if(!ship.shields_active && !ship.shields_broken)
			log_shuttle("SHIELD DEBUG: First generator online, initializing shields")
			ship.shields_active = TRUE
			ship.shield_health = 0  // Start at 0, shields must regenerate

			// Start ship processing for shield regen
			ship.start_shield_processing()

			// Spawn shield walls
			if(!ship_has_active_shield_walls())
				log_shuttle("SHIELD DEBUG: Spawning shield walls")
				spawn_shield_walls()

			playsound(src, 'sound/vehicles/mecha/mech_shield_raise.ogg', 100, TRUE)
			ship.ship_announce("Shields online.", "Shield Status")
			SEND_SIGNAL(ship, COMSIG_SHIP_SHIELD_RESTORED)
		else if(ship.shields_active)
			log_shuttle("SHIELD DEBUG: shields_active already TRUE, skipping wall spawn")
			// Just announce new generator online
			playsound(src, 'sound/vehicles/mecha/mech_shield_raise.ogg', 50, TRUE)

	return TRUE

/// Deactivates this generator (called when power_allocation set to 0)
/// If skip_break is TRUE, won't trigger shield break cooldown (used for docking transitions)
/obj/machinery/ship_combat/shield_generator/proc/deactivate_generator(skip_break = FALSE)
	if(!active)
		return

	active = FALSE

	update_appearance()
	update_power_draw()
	generator_sound?.stop()

	var/obj/structure/overmap/ship/ship = linked_ship_ref?.resolve()
	if(ship)
		// Recalculate ship shield stats without this generator
		ship.recalculate_shield_stats()

		// If no generators are active, ship shields go down (unless skipping for dock transition)
		if(count_active_generators() == 0 && !skip_break)
			// Trigger ship shield break (starts cooldown)
			ship.break_ship_shields()

/// Called by ship when shared shield pool breaks
/obj/machinery/ship_combat/shield_generator/proc/on_ship_shields_broken()
	active = FALSE
	update_appearance()
	update_power_draw()
	generator_sound?.stop()
	// Audio effect for each generator
	playsound(src, 'sound/vehicles/mecha/mech_shield_drop.ogg', 100, TRUE, extrarange = 10, pressure_affected = FALSE)

/// Called when this generator shuts down due to power loss
/obj/machinery/ship_combat/shield_generator/proc/power_loss_shutdown()
	if(!active)
		return

	active = FALSE

	update_appearance()
	update_power_draw()
	generator_sound?.stop()

	// Visual and audio effects on ship boundary
	var/list/boundary_turfs = get_random_boundary_turfs(5)
	for(var/turf/T in boundary_turfs)
		new /obj/effect/temp_visual/ship_shield_powerdown(T)
	playsound(src, 'sound/machines/terminal/terminal_off.ogg', 50, TRUE, pressure_affected = FALSE)

	var/obj/structure/overmap/ship/ship = linked_ship_ref?.resolve()
	if(ship)
		// Recalculate ship shield stats
		ship.recalculate_shield_stats()

		// If no generators are active, ship shields go down
		if(count_active_generators() == 0)
			ship.break_ship_shields()

/// Returns the count of active shield generators on this ship
/obj/machinery/ship_combat/shield_generator/proc/count_active_generators()
	var/obj/structure/overmap/ship/ship = linked_ship_ref?.resolve()
	if(!ship)
		return 0
	var/count = 0
	for(var/obj/machinery/ship_combat/shield_generator/gen in ship.linked_shield_generators)
		if(gen.active)
			count++
	return count

/// Returns TRUE if any generator on this ship already has shield walls spawned
/obj/machinery/ship_combat/shield_generator/proc/ship_has_active_shield_walls()
	var/obj/structure/overmap/ship/ship = linked_ship_ref?.resolve()
	if(!ship)
		return FALSE
	for(var/obj/machinery/ship_combat/shield_generator/gen in ship.linked_shield_generators)
		if(gen != src && length(gen.shield_walls))
			return TRUE
	return FALSE

/// Destroys all shield walls from all generators on this ship
/obj/machinery/ship_combat/shield_generator/proc/destroy_all_ship_shield_walls()
	var/obj/structure/overmap/ship/ship = linked_ship_ref?.resolve()
	if(!ship)
		destroy_shield_walls()
		return
	for(var/obj/machinery/ship_combat/shield_generator/gen in ship.linked_shield_generators)
		gen.destroy_shield_walls()

// ========== DAMAGE HANDLING ==========

/// Absorbs incoming damage - redirects to ship's shared shield pool
/// Returns TRUE if damage was absorbed, FALSE if shields were down
/obj/machinery/ship_combat/shield_generator/proc/absorb_damage(damage, turf/impact_loc)
	var/obj/structure/overmap/ship/ship = linked_ship_ref?.resolve()
	if(!ship)
		return FALSE
	return ship.absorb_shield_damage(damage, impact_loc)

/// Returns TRUE if this generator is active and contributing to shields
/obj/machinery/ship_combat/shield_generator/proc/is_shield_active()
	return active

// ========== CONSOLE LINKING ==========

/// Links this generator to a combat console
/obj/machinery/ship_combat/shield_generator/proc/link_console(obj/machinery/computer/camera_advanced/ship_combat/console)
	if(!console)
		return FALSE
	unlink_console()
	linked_console_ref = WEAKREF(console)
	RegisterSignal(console, COMSIG_QDELETING, PROC_REF(on_console_deleted))

	// Also link to the ship
	if(console.current_ship)
		link_ship(console.current_ship)

	return TRUE

/// Unlinks from the current console
/obj/machinery/ship_combat/shield_generator/proc/unlink_console()
	var/obj/machinery/computer/camera_advanced/ship_combat/console = linked_console_ref?.resolve()
	if(console)
		UnregisterSignal(console, COMSIG_QDELETING)
	linked_console_ref = null

/obj/machinery/ship_combat/shield_generator/proc/on_console_deleted(datum/source)
	SIGNAL_HANDLER
	linked_console_ref = null
	unlink_ship()

/// Links to a ship
/obj/machinery/ship_combat/shield_generator/proc/link_ship(obj/structure/overmap/ship/ship)
	if(!ship)
		return
	unlink_ship()
	linked_ship_ref = WEAKREF(ship)
	ship.linked_shield_generators |= src  // Add to list (|= avoids duplicates)
	update_ship_mass()

	// Sync power allocation with the ship's power allocation
	if(ship.shield_power_allocation > 0)
		set_power_allocation(ship.shield_power_allocation)

	// Recalculate ship shield stats with this generator now contributing
	ship.recalculate_shield_stats()

	// Register for docking signals
	RegisterSignal(ship, COMSIG_VOIDCREW_SHIP_ABOUT_TO_DOCK, PROC_REF(on_ship_about_to_dock))
	RegisterSignal(ship, COMSIG_VOIDCREW_SHIP_DOCKED, PROC_REF(on_ship_docked))
	RegisterSignal(ship, COMSIG_VOIDCREW_SHIP_UNDOCKED, PROC_REF(on_ship_undocked))
	// Register for when OTHER ships dock to US
	RegisterSignal(ship, COMSIG_VOIDCREW_SHIP_DOCKED_BY, PROC_REF(on_other_ship_docked_to_us))
	RegisterSignal(ship, COMSIG_VOIDCREW_SHIP_UNDOCKED_BY, PROC_REF(on_other_ship_undocked_from_us))
	// Initialize ship-to-ship dock flag based on current state
	in_ship_to_ship_dock = ship.is_in_ship_to_ship_dock()
	// If already in ship-to-ship dock, deactivate generator
	if(in_ship_to_ship_dock)
		deactivate_generator()

/// Unlinks from the current ship
/obj/machinery/ship_combat/shield_generator/proc/unlink_ship()
	var/obj/structure/overmap/ship/ship = linked_ship_ref?.resolve()
	if(ship)
		UnregisterSignal(ship, list(COMSIG_VOIDCREW_SHIP_ABOUT_TO_DOCK, COMSIG_VOIDCREW_SHIP_DOCKED, COMSIG_VOIDCREW_SHIP_UNDOCKED, COMSIG_VOIDCREW_SHIP_DOCKED_BY, COMSIG_VOIDCREW_SHIP_UNDOCKED_BY))
		ship.linked_shield_generators -= src  // Remove from list
		// Recalculate ship shield stats without this generator
		ship.recalculate_shield_stats()
		// If no generators are left active, ship shields go down
		if(active && count_active_generators() == 0)
			ship.break_ship_shields()
	linked_ship_ref = null
	invalidate_boundary_cache()

/// Returns TRUE if the ship is currently docked
/obj/machinery/ship_combat/shield_generator/proc/is_ship_docked()
	var/obj/structure/overmap/ship/ship = linked_ship_ref?.resolve()
	if(!ship)
		return FALSE
	return !isnull(ship.docked)

/// Returns TRUE if the ship is in a ship-to-ship dock (either we docked to them, or they docked to us)
/// Shields cannot operate during ship-to-ship docking
/obj/machinery/ship_combat/shield_generator/proc/is_docked_to_ship()
	// Use the flag that's set/cleared by signals at the correct timing
	// This avoids timing issues with state-based checks
	return in_ship_to_ship_dock

/// Called right before ship physically docks - no longer used for wall destruction
/// Wall destruction is now handled by on_shuttle_move_start for better timing
/obj/machinery/ship_combat/shield_generator/proc/on_ship_about_to_dock(datum/source)
	SIGNAL_HANDLER
	// Walls are now destroyed by COMSIG_ATOM_BEFORE_SHUTTLE_MOVE for tighter timing

/// Called right before the shuttle physically moves this generator - destroy walls
/obj/machinery/ship_combat/shield_generator/proc/on_shuttle_move_start(datum/source, turf/new_turf, rotation, move_mode, obj/docking_port/mobile/moving_dock)
	SIGNAL_HANDLER
	log_shuttle("SHIELD DEBUG on_shuttle_move_start: active=[active], destroying walls")
	// Track that we need to respawn walls after move (if shields were active)
	if(active && length(shield_walls))
		pending_wall_respawn = TRUE
		shuttle_move_done = FALSE
	destroy_shield_walls()

/// Called when ship docks - deactivate if ship-to-ship, otherwise respawn walls when shuttle move is done
/obj/machinery/ship_combat/shield_generator/proc/on_ship_docked(datum/source)
	SIGNAL_HANDLER
	var/obj/structure/overmap/ship/ship = linked_ship_ref?.resolve()
	if(!ship)
		return

	// Update our ship-to-ship dock flag based on actual state NOW (after physical move)
	in_ship_to_ship_dock = ship.is_in_ship_to_ship_dock()
	log_shuttle("SHIELD DEBUG on_ship_docked: ship=[ship], active=[active], docked=[ship?.docked], docked_type=[ship?.docked?.type], pending=[pending_wall_respawn], shuttle_done=[shuttle_move_done], in_ship_to_ship_dock=[in_ship_to_ship_dock]")

	// If in a ship-to-ship dock situation, shields must go down completely
	if(in_ship_to_ship_dock)
		log_shuttle("SHIELD DEBUG on_ship_docked: in ship-to-ship dock, deactivating")
		pending_wall_respawn = FALSE
		shuttle_move_done = FALSE
		deactivate_generator()
		return

	// Docked to planet/ruin/empty space alone - respawn walls if shuttle move is done
	// If shuttle move isn't done yet, on_shuttle_move_complete will handle it
	if(pending_wall_respawn && shuttle_move_done)
		log_shuttle("SHIELD DEBUG on_ship_docked: shuttle move done, respawning walls now")
		try_respawn_walls()

/// Called when this generator is physically moved by the shuttle system
/obj/machinery/ship_combat/shield_generator/proc/on_shuttle_move_complete(datum/source, turf/old_turf)
	SIGNAL_HANDLER
	log_shuttle("SHIELD DEBUG on_shuttle_move_complete: active=[active], pending=[pending_wall_respawn], old_turf=[old_turf]")

	// Always invalidate cache after shuttle move
	invalidate_boundary_cache()

	if(!active || !pending_wall_respawn)
		return

	// Mark that shuttle move is complete
	shuttle_move_done = TRUE

	var/obj/structure/overmap/ship/ship = linked_ship_ref?.resolve()
	if(!ship)
		return

	// If ship.docked is already set (on_ship_docked already fired), handle respawn now
	// Check if in ship-to-ship dock - if so, don't respawn (deactivate was already called)
	if(ship.docked)
		if(is_docked_to_ship())
			log_shuttle("SHIELD DEBUG on_shuttle_move_complete: in ship-to-ship dock, not respawning")
			pending_wall_respawn = FALSE
			return
		// Docked to planet/ruin/empty alone - respawn walls
		log_shuttle("SHIELD DEBUG on_shuttle_move_complete: dock info ready, respawning walls now")
		try_respawn_walls()
	else
		log_shuttle("SHIELD DEBUG on_shuttle_move_complete: waiting for on_ship_docked")

/// Helper to respawn walls and clear flags
/obj/machinery/ship_combat/shield_generator/proc/try_respawn_walls()
	pending_wall_respawn = FALSE
	shuttle_move_done = FALSE
	if(!active)
		return
	// Only first generator spawns walls
	if(!ship_has_active_shield_walls())
		log_shuttle("SHIELD DEBUG try_respawn_walls: spawning walls")
		spawn_shield_walls()
	else
		log_shuttle("SHIELD DEBUG try_respawn_walls: ship already has walls")

/// Called when ANOTHER ship docks TO us - we must deactivate shields
/obj/machinery/ship_combat/shield_generator/proc/on_other_ship_docked_to_us(datum/source, obj/structure/overmap/ship/docking_ship)
	SIGNAL_HANDLER
	// Update flag - we're now in a ship-to-ship dock
	in_ship_to_ship_dock = TRUE
	log_shuttle("SHIELD DEBUG on_other_ship_docked_to_us: [docking_ship] docked to our ship, in_ship_to_ship_dock=[in_ship_to_ship_dock], deactivating shields")
	deactivate_generator()

/// Called when a ship that was docked to us undocks - we can reactivate shields
/obj/machinery/ship_combat/shield_generator/proc/on_other_ship_undocked_from_us(datum/source, obj/structure/overmap/ship/undocking_ship)
	SIGNAL_HANDLER
	var/obj/structure/overmap/ship/ship = linked_ship_ref?.resolve()
	// Update flag based on whether any other ships are still docked
	// At this point, the undocking ship has physically left, so is_in_ship_to_ship_dock() gives accurate result
	in_ship_to_ship_dock = ship?.is_in_ship_to_ship_dock() || FALSE
	log_shuttle("SHIELD DEBUG on_other_ship_undocked_from_us: [undocking_ship] undocked from our ship, in_ship_to_ship_dock=[in_ship_to_ship_dock]")
	// Shields don't auto-reactivate - crew must manually enable

/// Called when ship undocks - shields can be reactivated
/obj/machinery/ship_combat/shield_generator/proc/on_ship_undocked(datum/source)
	SIGNAL_HANDLER
	// We're undocking, so we're no longer in any ship-to-ship dock
	in_ship_to_ship_dock = FALSE
	log_shuttle("SHIELD DEBUG on_ship_undocked: in_ship_to_ship_dock=[in_ship_to_ship_dock]")
	// Invalidate boundary cache in case ship was modified while docked (e.g., construction console)
	invalidate_boundary_cache()
	// Shields don't auto-activate on undock - crew must manually enable

/// Attempts to auto-link to a combat console on the same ship
/obj/machinery/ship_combat/shield_generator/proc/attempt_auto_link()
	var/area/our_area = get_area(src)
	if(!our_area)
		return

	var/obj/structure/overmap/ship/our_ship
	for(var/obj/structure/overmap/ship/S in SSovermap.simulated_ships)
		if(!S.shuttle)
			continue
		if(our_area in S.shuttle.shuttle_areas)
			our_ship = S
			break

	if(!our_ship)
		return

	// Always link to the ship directly (critical for signal registration)
	if(!linked_ship_ref?.resolve())
		link_ship(our_ship)

	// Try to find and link a combat console on this ship
	if(!linked_console_ref?.resolve())
		for(var/area/ship_area in our_ship.shuttle.shuttle_areas)
			for(var/obj/machinery/computer/camera_advanced/ship_combat/console in ship_area)
				if(link_console(console))
					console.link_shield_generator(src)
					return

// ========== TOOL INTERACTIONS ==========

/// Attempts to shock the user if the generator is active
/// Returns TRUE if the user was shocked, FALSE otherwise
/obj/machinery/ship_combat/shield_generator/proc/shock_user(mob/living/user, shock_probability = 100)
	if(!active)
		return FALSE
	if(!isliving(user))
		return FALSE
	// electrocute_mob handles insulated gloves check internally via wearing_shock_proof_gloves()
	if(!prob(shock_probability))
		return FALSE
	// Use the area as power source since shield generators draw from ship power
	if(electrocute_mob(user, get_area(src), src, siemens_coeff = 1, dist_check = TRUE))
		do_sparks(5, TRUE, src)
		return TRUE
	return FALSE

/obj/machinery/ship_combat/shield_generator/attackby(obj/item/W, mob/user, params)
	// Multitool linking
	if(istype(W, /obj/item/multitool))
		var/obj/item/multitool/tool = W
		tool.buffer = src
		balloon_alert(user, "generator buffered")
		to_chat(user, span_notice("You buffer [src] to the multitool. Use on a weapons system to link."))
		return TRUE

	// Standard deconstruction
	if(default_deconstruction_screwdriver(user, icon_state, icon_state, W))
		return
	if(default_deconstruction_crowbar(W))
		return
	return ..()

/obj/machinery/ship_combat/shield_generator/screwdriver_act(mob/living/user, obj/item/tool)
	if(shock_user(user))
		return ITEM_INTERACT_BLOCKING
	return ..()

/obj/machinery/ship_combat/shield_generator/crowbar_act(mob/living/user, obj/item/tool)
	if(shock_user(user))
		return ITEM_INTERACT_BLOCKING
	return ..()

/obj/machinery/ship_combat/shield_generator/wrench_act(mob/living/user, obj/item/tool)
	. = ITEM_INTERACT_BLOCKING
	if(active)
		if(shock_user(user))
			return
		to_chat(user, span_warning("Deactivate the shields first!"))
		return
	default_unfasten_wrench(user, tool)
	return ITEM_INTERACT_SUCCESS

// ========== STATUS FOR UI ==========

/// Returns per-generator status data (for debugging/detailed view)
/// For main UI, use ship.get_shield_status() instead
/obj/machinery/ship_combat/shield_generator/proc/get_status()
	return list(
		"active" = active,
		"max_health_contribution" = round(max_shield_health),
		"regen_contribution" = round(regen_rate, 0.1),
		"power_allocation" = power_allocation,
		"power_draw" = round(get_power_draw()),
		"efficiency" = round((1 - power_efficiency) * 100),
	)

/// Sets power allocation from console (0.0 to 2.0)
/obj/machinery/ship_combat/shield_generator/proc/set_power_allocation(new_allocation)
	power_allocation = clamp(new_allocation, SHIP_SHIELD_MIN_POWER_MULT, SHIP_SHIELD_MAX_POWER_MULT)
	update_power_draw()

/// Updates the machine's power draw based on current settings
/obj/machinery/ship_combat/shield_generator/proc/update_power_draw()
	var/new_power = get_power_draw()
	if(power_allocation > 0 && active)
		update_mode_power_usage(ACTIVE_POWER_USE, new_power)
		update_use_power(ACTIVE_POWER_USE)
	else
		update_mode_power_usage(ACTIVE_POWER_USE, 0)
		update_use_power(IDLE_POWER_USE)

// ========== CIRCUIT BOARD ==========

/obj/item/circuitboard/machine/ship_combat/shield_generator
	name = "Ship Shield Generator"
	greyscale_colors = CIRCUIT_COLOR_COMMAND
	build_path = /obj/machinery/ship_combat/shield_generator
	req_components = list(
		/datum/stock_part/capacitor = 2,
		/datum/stock_part/micro_laser = 2,
		/datum/stock_part/servo = 1,
	)

