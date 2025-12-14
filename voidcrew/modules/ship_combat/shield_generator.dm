// Ship Combat Shield Generator
// Protects the ship from missiles and meteors
// Power scales with ship mass, upgradable via stock parts
// Controlled via combat console power slider (0-200%)

/obj/machinery/ship_combat/shield_generator
	name = "ship shield generator"
	desc = "A ship-mounted deflector shield generator. Protects against missiles and meteors. Link to a combat console with a multitool to control."
	icon = 'icons/obj/machines/shield_generator.dmi'  // Placeholder - TODO: custom icon
	icon_state = "shield_wall_gen"  // Placeholder
	density = TRUE
	anchored = TRUE
	power_channel = AREA_USAGE_EQUIP
	circuit = /obj/item/circuitboard/machine/ship_combat/shield_generator

	// Stock part integration
	// Capacitors: +50% max shield health per tier
	// Micro-lasers: +30% base regen rate per tier
	// Servos: -15% power consumption per tier

	/// Current shield health
	var/shield_health = 0
	/// Current overhealth (extra shield beyond max)
	var/overhealth = 0
	/// Calculated max shield health (from base + parts)
	var/max_shield_health = SHIP_SHIELD_BASE_HEALTH
	/// Calculated regeneration rate per second (from base + parts)
	var/regen_rate = SHIP_SHIELD_BASE_REGEN
	/// Calculated power efficiency multiplier (from parts, 0-1 range, lower = more efficient)
	var/power_efficiency = 1

	/// Power allocation set by combat console (0.0 to 2.0) - starts at 0 (off)
	var/power_allocation = 0

	/// Is the shield currently protecting? (power_allocation > 0 and not broken)
	var/active = FALSE
	/// Is the shield broken (health reached 0)?
	var/broken = FALSE

	/// Reference to linked combat console
	var/datum/weakref/linked_console_ref
	/// Reference to our ship
	var/datum/weakref/linked_ship_ref

	/// Cooldown for reactivation after breaking
	COOLDOWN_DECLARE(reactivation_cooldown)

	/// Cached ship mass for power calculations
	var/cached_ship_mass = 500

	/// List of active shield wall structures
	var/list/obj/structure/ship_shield_wall/shield_walls = list()

	/// Debug logging for shield direction calculations
	var/debug_shield_directions = FALSE

/obj/machinery/ship_combat/shield_generator/Initialize(mapload)
	. = ..()
	// Start processing for regeneration
	begin_processing()
	// Try to auto-link after a short delay
	addtimer(CALLBACK(src, PROC_REF(attempt_auto_link)), 2 SECONDS)

/obj/machinery/ship_combat/shield_generator/Destroy()
	destroy_shield_walls()
	unlink_console()
	unlink_ship()
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

/obj/machinery/ship_combat/shield_generator/examine(mob/user)
	. = ..()
	. += span_notice("Shield Status: [active ? "ACTIVE" : (broken ? "BROKEN" : "OFFLINE")]")
	if(active)
		. += span_notice("Shield Health: [round(shield_health)]/[round(max_shield_health)][overhealth > 0 ? " (+[round(overhealth)] overhealth)" : ""]")
		. += span_notice("Regeneration: [round(get_effective_regen_rate(), 0.1)]/sec")
		. += span_notice("Power Draw: [round(get_power_draw())]W")
	if(broken)
		if(!COOLDOWN_FINISHED(src, reactivation_cooldown))
			. += span_warning("Cooldown: [DisplayTimeText(COOLDOWN_TIMELEFT(src, reactivation_cooldown))] remaining")
		else
			. += span_notice("Ready to reactivate.")
	. += span_notice("Power Allocation: [round(power_allocation * 100)]%")
	. += span_notice("Efficiency: [round((1 - power_efficiency) * 100)]% power reduction")

	var/obj/machinery/computer/camera_advanced/ship_combat/console = linked_console_ref?.resolve()
	if(console)
		. += span_notice("Linked to: [console]")
	else
		. += span_warning("Not linked to a combat console. Use a multitool to link.")

/obj/machinery/ship_combat/shield_generator/update_icon_state()
	. = ..()
	if(machine_stat & BROKEN)
		icon_state = "shield_wall_gen"
	else if(broken)
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
			deactivate_shields()
		return

	// Can't run shields while docked
	if(is_ship_docked())
		if(active)
			deactivate_shields()
		return

	// If broken and on cooldown, can't do anything
	if(broken)
		if(COOLDOWN_FINISHED(src, reactivation_cooldown))
			// Ready to reactivate, but need manual trigger from console
			broken = FALSE
		return

	// Draw power
	var/power_draw = get_power_draw()
	if(!use_energy(power_draw * seconds_per_tick))
		power_loss_shutdown()
		return

	// Activate if not already
	if(!active)
		activate_shields()

	// Regenerate shield health
	var/effective_regen = get_effective_regen_rate() * seconds_per_tick
	if(shield_health < max_shield_health)
		shield_health = min(shield_health + effective_regen, max_shield_health)
	else if(power_allocation > 1)
		// Generate overhealth when at max and power > 100%
		var/overhealth_rate = get_overhealth_rate() * seconds_per_tick
		overhealth += overhealth_rate

// ========== POWER CALCULATIONS ==========

/// Returns the current power draw based on ship mass, allocation, and efficiency
/obj/machinery/ship_combat/shield_generator/proc/get_power_draw()
	return cached_ship_mass * SHIP_SHIELD_POWER_PER_MASS * power_allocation * power_efficiency

/// Returns the effective regeneration rate based on base rate and power allocation
/obj/machinery/ship_combat/shield_generator/proc/get_effective_regen_rate()
	return regen_rate * power_allocation

/// Returns the overhealth generation rate (only when power > 100%)
/obj/machinery/ship_combat/shield_generator/proc/get_overhealth_rate()
	if(power_allocation <= 1)
		return 0
	// Excess power above 100% generates overhealth
	// At 200% power, generate at same rate as regen
	var/excess = power_allocation - 1
	return regen_rate * excess

/// Returns the cooldown modifier based on power allocation
/// Higher power = faster cooldown recovery
/obj/machinery/ship_combat/shield_generator/proc/get_cooldown_modifier()
	// At 50% power: 1.5x longer cooldown
	// At 100% power: 1x cooldown
	// At 200% power: 0.5x cooldown
	if(power_allocation <= 0)
		return 2
	return 1 / power_allocation

/// Updates cached ship mass from the linked ship
/obj/machinery/ship_combat/shield_generator/proc/update_ship_mass()
	var/obj/structure/overmap/ship/ship = linked_ship_ref?.resolve()
	if(ship)
		cached_ship_mass = max(ship.mass, 100)  // Minimum 100 mass
	else
		cached_ship_mass = 500  // Default

/// Returns a list of SPACE turfs adjacent to the ship (where shield walls will spawn)
/obj/machinery/ship_combat/shield_generator/proc/get_ship_boundary_turfs()
	var/list/boundary_turfs = list()
	var/obj/structure/overmap/ship/ship = linked_ship_ref?.resolve()
	if(!ship?.shuttle?.shuttle_areas)
		return boundary_turfs

	var/list/ship_areas = ship.shuttle.shuttle_areas

	// First pass: Get all turfs in ship areas and find cardinally adjacent space turfs
	for(var/area/ship_area in ship_areas)
		for(var/turf/T in ship_area)
			// Check each cardinal direction for space turfs
			for(var/dir in GLOB.cardinals)
				var/turf/neighbor = get_step(T, dir)
				// If neighbor is space (not part of ship), add it as a boundary turf
				if(neighbor && (isspaceturf(neighbor) || !(get_area(neighbor) in ship_areas)))
					boundary_turfs |= neighbor  // Use |= to avoid duplicates

	// Second pass: Find gap turfs that are only DIAGONALLY adjacent to ship
	// These occur on diagonal ship edges where turfs don't touch ship cardinally
	// but still need shields to complete the boundary
	// We iterate until no new gaps are found, since gap turfs can chain together
	var/found_new = TRUE
	var/max_iterations = 10  // Safety limit
	var/iteration = 0
	while(found_new && iteration < max_iterations)
		iteration++
		found_new = FALSE
		var/list/gap_turfs = list()

		for(var/turf/boundary_turf in boundary_turfs)
			// Check cardinal neighbors of each boundary turf for potential gaps
			for(var/card_dir in GLOB.cardinals)
				var/turf/card_neighbor = get_step(boundary_turf, card_dir)
				if(!card_neighbor)
					continue
				// Skip if already in boundary or part of ship
				if(card_neighbor in boundary_turfs)
					continue
				if(get_area(card_neighbor) in ship_areas)
					continue
				// Skip if not space
				if(!isspaceturf(card_neighbor))
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

				// This is a valid gap turf - diagonally adjacent to ship but not cardinally
				gap_turfs |= card_neighbor

		// Add gap turfs to boundary
		if(length(gap_turfs))
			found_new = TRUE
			boundary_turfs |= gap_turfs

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
	log_admin("SHIELD DEBUG: [message]")

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

	// STRAIGHT EDGES: boundary neighbors in opposite directions → bar
	if((boundary_dirs & NORTH) && (boundary_dirs & SOUTH))
		debug_log("  -> STRAIGHT N+S, returning SOUTH (vertical bar)")
		return SOUTH  // Vertical bar
	if((boundary_dirs & EAST) && (boundary_dirs & WEST))
		debug_log("  -> STRAIGHT E+W, returning EAST (horizontal bar)")
		return EAST   // Horizontal bar

	// T-JUNCTIONS: three boundary neighbors
	// Return bar perpendicular to the missing direction
	var/boundary_count = 0
	if(boundary_dirs & NORTH)
		boundary_count++
	if(boundary_dirs & SOUTH)
		boundary_count++
	if(boundary_dirs & EAST)
		boundary_count++
	if(boundary_dirs & WEST)
		boundary_count++

	if(boundary_count == 3)
		if(!(boundary_dirs & SOUTH))
			debug_log("  -> T-JUNCTION missing S, returning SOUTH (vertical bar)")
			return SOUTH
		if(!(boundary_dirs & NORTH))
			debug_log("  -> T-JUNCTION missing N, returning SOUTH (vertical bar)")
			return SOUTH
		if(!(boundary_dirs & EAST))
			debug_log("  -> T-JUNCTION missing E, returning EAST (horizontal bar)")
			return EAST
		if(!(boundary_dirs & WEST))
			debug_log("  -> T-JUNCTION missing W, returning EAST (horizontal bar)")
			return EAST

	// FOUR-WAY JUNCTION: all four boundary neighbors
	if(boundary_count == 4)
		debug_log("  -> FOUR-WAY JUNCTION, returning EAST (horizontal bar)")
		return EAST

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

		// If ship is diagonal, return L-connector that connects to boundary neighbor + toward diagonal
		if(ship_dirs == (SOUTH|EAST))
			if(boundary_dirs == NORTH)
				debug_log("  -> DIAG TRANSITION S+E with N neighbor, returning NORTHEAST")
				return NORTHEAST  // Connect UP + RIGHT
			if(boundary_dirs == WEST)
				debug_log("  -> DIAG TRANSITION S+E with W neighbor, returning SOUTHWEST")
				return SOUTHWEST  // Connect LEFT + DOWN
		if(ship_dirs == (SOUTH|WEST))
			if(boundary_dirs == NORTH)
				debug_log("  -> DIAG TRANSITION S+W with N neighbor, returning NORTHWEST")
				return NORTHWEST  // Connect UP + LEFT
			if(boundary_dirs == EAST)
				debug_log("  -> DIAG TRANSITION S+W with E neighbor, returning SOUTHEAST")
				return SOUTHEAST  // Connect RIGHT + DOWN
		if(ship_dirs == (NORTH|EAST))
			if(boundary_dirs == SOUTH)
				debug_log("  -> DIAG TRANSITION N+E with S neighbor, returning SOUTHEAST")
				return SOUTHEAST  // Connect DOWN + RIGHT
			if(boundary_dirs == WEST)
				debug_log("  -> DIAG TRANSITION N+E with W neighbor, returning NORTHWEST")
				return NORTHWEST  // Connect LEFT + UP
		if(ship_dirs == (NORTH|WEST))
			if(boundary_dirs == SOUTH)
				debug_log("  -> DIAG TRANSITION N+W with S neighbor, returning SOUTHWEST")
				return SOUTHWEST  // Connect DOWN + LEFT
			if(boundary_dirs == EAST)
				debug_log("  -> DIAG TRANSITION N+W with E neighbor, returning NORTHEAST")
				return NORTHEAST  // Connect RIGHT + UP

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

	// First pass: spawn shields on all detected boundary turfs
	for(var/turf/T in boundary)
		var/wall_dir = get_wall_direction(T, ship_areas, boundary)
		var/obj/structure/ship_shield_wall/wall = new(T)
		wall.generator_ref = WEAKREF(src)
		wall.setDir(wall_dir)
		shield_walls += wall

	// Second pass: build snake chains for TRUE diagonal ship edges
	// Detect diagonal edges by checking boundary turfs where ship is in 2 perpendicular cardinal directions
	var/list/processed_chain_starts = list()  // Track which chains we've started
	for(var/turf/T in boundary)
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
			if(!adj_boundary || !(adj_boundary in boundary))
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

		// Mark this turf as processed
		processed_chain_starts += T

		// The existing shield at T might need to be part of a snake chain
		// Find where to start the chain extension (space turf in diagonal direction)
		var/turf/chain_start = get_step(T, diagonal_dir)
		if(!chain_start || !isspaceturf(chain_start))
			continue

		// Build the snake chain extending into space
		build_diagonal_shield_chain(chain_start, diagonal_dir, boundary)

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

	for(var/i in 1 to max_iterations)
		if(!current || !isspaceturf(current))
			break
		// Stop if we've reached an existing boundary turf
		if(current in boundary)
			break
		// Stop if there's already a shield here
		var/already_has_shield = FALSE
		for(var/obj/structure/ship_shield_wall/existing in current)
			already_has_shield = TRUE
			break
		if(already_has_shield)
			break

		// Spawn the shield with alternating connector direction
		var/obj/structure/ship_shield_wall/wall = new(current)
		wall.generator_ref = WEAKREF(src)
		wall.setDir(use_first_connector ? connector_1 : connector_2)
		shield_walls += wall

		// Move to next position (alternating between the two move directions)
		current = get_step(current, use_first_move ? move_dir_1 : move_dir_2)

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

/// Activates shields (called when power_allocation > 0 and not broken)
/// Returns FALSE if activation failed (docked, broken, etc.)
/obj/machinery/ship_combat/shield_generator/proc/activate_shields()
	if(active)
		return TRUE
	if(broken && !COOLDOWN_FINISHED(src, reactivation_cooldown))
		return FALSE
	// Can't activate while docked
	if(is_ship_docked())
		return FALSE

	active = TRUE
	broken = FALSE

	// Start at 50% health on activation
	if(shield_health <= 0)
		shield_health = max_shield_health * 0.5

	// Spawn physical shield walls at ship boundary
	spawn_shield_walls()

	update_appearance()
	playsound(src, 'sound/machines/computer/computer_start.ogg', 50, TRUE)

	var/obj/structure/overmap/ship/ship = linked_ship_ref?.resolve()
	if(ship)
		SEND_SIGNAL(ship, COMSIG_SHIP_SHIELD_RESTORED)
		ship.ship_announce("Shields online.", "Shield Status")

/// Deactivates shields (called when power_allocation set to 0)
/obj/machinery/ship_combat/shield_generator/proc/deactivate_shields()
	if(!active)
		return

	active = FALSE

	// Remove physical shield walls
	destroy_shield_walls()

	update_appearance()
	playsound(src, 'sound/machines/terminal/terminal_off.ogg', 25, FALSE)

/// Called when shields are depleted by damage
/obj/machinery/ship_combat/shield_generator/proc/break_shields()
	if(!active)
		return

	active = FALSE
	broken = TRUE
	shield_health = 0
	overhealth = 0

	// Start cooldown (modified by power allocation)
	var/cooldown_time = SHIP_SHIELD_BROKEN_COOLDOWN * get_cooldown_modifier()
	COOLDOWN_START(src, reactivation_cooldown, cooldown_time)

	// Remove all shield walls at once
	destroy_shield_walls()

	update_appearance()

	// Visual and audio effects on ship boundary
	var/list/boundary_turfs = get_random_boundary_turfs(8)
	for(var/turf/T in boundary_turfs)
		new /obj/effect/temp_visual/ship_shield_break(T)
	playsound(src, 'sound/effects/glass/glassbr1.ogg', 80, TRUE)

	var/obj/structure/overmap/ship/ship = linked_ship_ref?.resolve()
	if(ship)
		SEND_SIGNAL(ship, COMSIG_SHIP_SHIELD_BROKEN)
		ship.ship_announce("WARNING: Shields collapsed! Reactivation available in [DisplayTimeText(cooldown_time)].", "Shield Alert", TRUE, 'sound/machines/engine_alert/engine_alert3.ogg')

/// Called when shields shut down due to power loss
/obj/machinery/ship_combat/shield_generator/proc/power_loss_shutdown()
	if(!active)
		return

	active = FALSE

	// Remove all shield walls at once
	destroy_shield_walls()

	update_appearance()

	// Visual and audio effects on ship boundary
	var/list/boundary_turfs = get_random_boundary_turfs(5)
	for(var/turf/T in boundary_turfs)
		new /obj/effect/temp_visual/ship_shield_powerdown(T)
	playsound(src, 'sound/machines/terminal/terminal_off.ogg', 50, TRUE)

	var/obj/structure/overmap/ship/ship = linked_ship_ref?.resolve()
	if(ship)
		SEND_SIGNAL(ship, COMSIG_SHIP_SHIELD_POWERDOWN)
		ship.ship_announce("Shields offline - insufficient power.", "Shield Alert")

// ========== DAMAGE HANDLING ==========

/// Absorbs incoming damage. Returns TRUE if damage was fully absorbed.
/obj/machinery/ship_combat/shield_generator/proc/absorb_damage(damage, turf/impact_loc)
	if(!active || broken)
		return FALSE

	// First absorb from overhealth
	if(overhealth > 0)
		var/overhealth_absorbed = min(damage, overhealth)
		overhealth -= overhealth_absorbed
		damage -= overhealth_absorbed

	// Then from regular health
	shield_health -= damage

	// Find nearest boundary turf for visual effect (shields appear at ship edge)
	var/turf/effect_loc = get_nearest_boundary_turf(impact_loc)
	if(effect_loc)
		new /obj/effect/temp_visual/ship_shield_hit(effect_loc)
		// Random shield hit sound
		var/sound_file = pick(
			'voidcrew/sound/machines/forcefield/hit1.ogg',
			'voidcrew/sound/machines/forcefield/hit2.ogg',
			'voidcrew/sound/machines/forcefield/hit3.ogg',
			'voidcrew/sound/machines/forcefield/hit4.ogg',
		)
		// Play sound from nearest ship tile to impact (so crew hears directional audio)
		var/turf/sound_loc = get_nearest_ship_turf(effect_loc)
		playsound(sound_loc || src, sound_file, 60, TRUE, 20, ignore_walls = TRUE)

	// Signal that shield was hit
	var/obj/structure/overmap/ship/ship = linked_ship_ref?.resolve()
	if(ship)
		SEND_SIGNAL(ship, COMSIG_SHIP_SHIELD_HIT, damage, effect_loc)

	// Check for shield break
	if(shield_health <= 0)
		shield_health = 0
		break_shields()

	return TRUE  // Damage was absorbed (even if shield broke)

/// Returns TRUE if shields are currently active and can absorb damage
/obj/machinery/ship_combat/shield_generator/proc/is_shield_active()
	return active && !broken && shield_health > 0

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
	ship.linked_shield_generator = src
	update_ship_mass()
	// Register for docking signals
	RegisterSignal(ship, COMSIG_VOIDCREW_SHIP_DOCKED, PROC_REF(on_ship_docked))
	RegisterSignal(ship, COMSIG_VOIDCREW_SHIP_UNDOCKED, PROC_REF(on_ship_undocked))
	// If already docked, deactivate shields
	if(is_ship_docked())
		deactivate_shields()

/// Unlinks from the current ship
/obj/machinery/ship_combat/shield_generator/proc/unlink_ship()
	var/obj/structure/overmap/ship/ship = linked_ship_ref?.resolve()
	if(ship)
		UnregisterSignal(ship, list(COMSIG_VOIDCREW_SHIP_DOCKED, COMSIG_VOIDCREW_SHIP_UNDOCKED))
		if(ship.linked_shield_generator == src)
			ship.linked_shield_generator = null
	linked_ship_ref = null

/// Returns TRUE if the ship is currently docked
/obj/machinery/ship_combat/shield_generator/proc/is_ship_docked()
	var/obj/structure/overmap/ship/ship = linked_ship_ref?.resolve()
	if(!ship)
		return FALSE
	return !isnull(ship.docked)

/// Called when ship docks - deactivate shields
/obj/machinery/ship_combat/shield_generator/proc/on_ship_docked(datum/source)
	SIGNAL_HANDLER
	deactivate_shields()

/// Called when ship undocks - shields can be reactivated
/obj/machinery/ship_combat/shield_generator/proc/on_ship_undocked(datum/source)
	SIGNAL_HANDLER
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

/obj/machinery/ship_combat/shield_generator/attackby(obj/item/W, mob/user, params)
	// Multitool linking
	if(istype(W, /obj/item/multitool))
		var/obj/item/multitool/tool = W
		tool.buffer = src
		balloon_alert(user, "generator buffered")
		to_chat(user, span_notice("You buffer [src] to the multitool. Use on a combat console to link."))
		return TRUE

	// Standard deconstruction
	if(default_deconstruction_screwdriver(user, icon_state, icon_state, W))
		return
	if(default_deconstruction_crowbar(W))
		return
	return ..()

/obj/machinery/ship_combat/shield_generator/wrench_act(mob/living/user, obj/item/tool)
	. = ITEM_INTERACT_BLOCKING
	if(active)
		to_chat(user, span_warning("Deactivate the shields first!"))
		return
	default_unfasten_wrench(user, tool)
	return ITEM_INTERACT_SUCCESS

// ========== STATUS FOR UI ==========

/// Returns status data for combat console UI
/obj/machinery/ship_combat/shield_generator/proc/get_status()
	return list(
		"active" = active,
		"broken" = broken,
		"health" = round(shield_health),
		"max_health" = round(max_shield_health),
		"overhealth" = round(overhealth),
		"power_allocation" = power_allocation,
		"regen_rate" = round(get_effective_regen_rate(), 0.1),
		"power_draw" = round(get_power_draw()),
		"efficiency" = round((1 - power_efficiency) * 100),
		"cooldown_active" = broken && !COOLDOWN_FINISHED(src, reactivation_cooldown),
		"cooldown_remaining" = COOLDOWN_TIMELEFT(src, reactivation_cooldown),
	)

/// Sets power allocation from console (0.0 to 2.0)
/obj/machinery/ship_combat/shield_generator/proc/set_power_allocation(new_allocation)
	power_allocation = clamp(new_allocation, SHIP_SHIELD_MIN_POWER_MULT, SHIP_SHIELD_MAX_POWER_MULT)

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
