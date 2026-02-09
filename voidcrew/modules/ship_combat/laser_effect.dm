// Ship Combat Laser Beam Effect
// Visual beam that travels from off-screen to target like missiles/meteors
// Uses the same pathfinding logic as missiles to find holes in the ship
// Uses projectiles_tracer.dmi sprites: beam_omni for single, plasmacutter for multi
// Uses projectiles_impact.dmi sprites: impact_omni for single, impact_plasmacutter for multi

/// The main laser beam controller - spawns at the turret, calculates path, creates visuals
/obj/effect/ship_laser_beam
	name = "laser beam"
	desc = "A powerful laser beam."
	icon = 'icons/obj/weapons/guns/projectiles_tracer.dmi'
	icon_state = "beam_omni"
	layer = ABOVE_MOB_LAYER
	mouse_opacity = MOUSE_OPACITY_TRANSPARENT
	anchored = TRUE
	invisibility = INVISIBILITY_ABSTRACT  // Controller is invisible

	/// The target turf we're aiming at
	var/turf/target_turf
	/// The ship we're targeting
	var/obj/structure/overmap/ship/target_ship
	/// The ship that fired us
	var/obj/structure/overmap/ship/source_ship
	/// Damage to deal
	var/damage = LASER_DAMAGE_BASE
	/// Power level (0.25 to 2.0) - affects wall damage
	var/power_level = 1
	/// List of beam segment effects we've created
	var/list/beam_segments = list()
	/// The end cap effect
	var/obj/effect/temp_visual/ship_laser_impact/end_cap
	/// Direction the beam is coming from
	var/approach_direction
	/// Whether this is a multi-beam (combined fire from multiple turrets)
	var/is_multi_beam = FALSE

/obj/effect/ship_laser_beam/Initialize(mapload, turf/target, obj/structure/overmap/ship/target_ship_ref, obj/structure/overmap/ship/source_ship_ref, laser_damage, laser_power_level = 1, multi_beam = FALSE, forced_direction = null)
	. = ..()

	target_turf = target
	target_ship = target_ship_ref
	source_ship = source_ship_ref
	power_level = laser_power_level
	is_multi_beam = multi_beam
	// If a direction is forced, use it instead of calculating one
	if(forced_direction)
		approach_direction = forced_direction

	if(laser_damage)
		damage = laser_damage

	// Fire the laser after a short delay to allow positioning
	addtimer(CALLBACK(src, PROC_REF(fire_laser)), 0.1 SECONDS)

/obj/effect/ship_laser_beam/Destroy()
	// Clean up beam segments
	for(var/obj/effect/segment in beam_segments)
		qdel(segment)
	beam_segments.Cut()
	end_cap = null
	target_turf = null
	target_ship = null
	source_ship = null
	return ..()

/// Calculates spawn position outside the target ship using missile-style pathfinding
/obj/effect/ship_laser_beam/proc/get_laser_spawn_turf()
	if(!target_turf)
		return null

	// Get ship bounds from the docking port
	var/min_x = target_turf.x
	var/max_x = target_turf.x
	var/min_y = target_turf.y
	var/max_y = target_turf.y

	if(target_ship?.shuttle)
		var/list/bounds = target_ship.shuttle.return_coords()
		if(bounds?.len >= 4)
			min_x = min(bounds[1], bounds[3])
			max_x = max(bounds[1], bounds[3])
			min_y = min(bounds[2], bounds[4])
			max_y = max(bounds[2], bounds[4])

	// How far outside the ship to spawn
	var/spawn_dist = 10

	// Find the best approach direction (looking for holes like missiles do)
	// Skip if a direction was already forced in Initialize
	if(!approach_direction)
		approach_direction = find_clear_approach_direction(target_turf, min_x, max_x, min_y, max_y, spawn_dist)

	var/spawn_x = target_turf.x
	var/spawn_y = target_turf.y

	// Spawn from the selected direction (all beams use same path, pixel offset handles spread)
	switch(approach_direction)
		if(NORTH)
			spawn_y = max_y + spawn_dist
		if(SOUTH)
			spawn_y = min_y - spawn_dist
		if(EAST)
			spawn_x = max_x + spawn_dist
		if(WEST)
			spawn_x = min_x - spawn_dist

	return locate(spawn_x, spawn_y, target_turf.z)

/// Finds the best approach direction for the laser
/// Prioritizes clear paths (through hull breaches), then picks the shortest among them
/// If no clear paths exist, falls back to the shortest path overall
/obj/effect/ship_laser_beam/proc/find_clear_approach_direction(turf/target, min_x, max_x, min_y, max_y, spawn_dist)
	var/list/clear_directions = list()
	var/list/direction_distances = list()

	// Calculate path distance and clearance for each direction
	for(var/check_dir in list(NORTH, SOUTH, EAST, WEST))
		var/spawn_x = target.x
		var/spawn_y = target.y
		var/distance

		switch(check_dir)
			if(NORTH)
				spawn_y = max_y + spawn_dist
				distance = spawn_y - target.y
			if(SOUTH)
				spawn_y = min_y - spawn_dist
				distance = target.y - spawn_y
			if(EAST)
				spawn_x = max_x + spawn_dist
				distance = spawn_x - target.x
			if(WEST)
				spawn_x = min_x - spawn_dist
				distance = target.x - spawn_x

		var/turf/spawn_turf = locate(spawn_x, spawn_y, target.z)
		if(!spawn_turf)
			continue

		direction_distances["[check_dir]"] = distance

		// Check if path from spawn to target is clear
		if(check_path_clear(spawn_turf, target))
			clear_directions += check_dir

	// If we found clear paths, return the shortest one
	if(length(clear_directions))
		var/best_dir
		var/best_distance = INFINITY
		for(var/dir in clear_directions)
			var/dist = direction_distances["[dir]"]
			if(dist < best_distance)
				best_distance = dist
				best_dir = dir
		return best_dir

	// No clear paths - return the shortest direction overall (will hit walls)
	var/best_dir
	var/best_distance = INFINITY
	for(var/dir_key in direction_distances)
		var/dist = direction_distances[dir_key]
		if(dist < best_distance)
			best_distance = dist
			best_dir = text2num(dir_key)
	return best_dir

/// Checks if there's a clear line-of-sight path between two turfs
/// Lasers can pass through windows, grilles, tables, and railings
/obj/effect/ship_laser_beam/proc/check_path_clear(turf/start, turf/end)
	if(!start || !end)
		return FALSE

	var/list/path_turfs = get_line(start, end)

	for(var/turf/T in path_turfs)
		if(T == start || T == end)
			continue

		if(T.density)
			return FALSE

		for(var/obj/O in T)
			if(!O.density)
				continue
			// Lasers pass through glass/windows
			if(istype(O, /obj/structure/window))
				continue
			// Lasers pass through grilles
			if(istype(O, /obj/structure/grille))
				continue
			// Lasers pass through tables
			if(istype(O, /obj/structure/table))
				continue
			// Lasers pass through railings
			if(istype(O, /obj/structure/railing))
				continue
			// Dense object blocks the path
			return FALSE

	return TRUE

/// Fires the laser beam towards the target
/obj/effect/ship_laser_beam/proc/fire_laser()
	if(!target_turf || QDELETED(src))
		qdel(src)
		return

	// Get spawn position using missile-style pathfinding
	var/turf/start_turf = get_laser_spawn_turf()
	if(!start_turf)
		qdel(src)
		return

	// Get the path from start to target
	var/list/path = get_line(start_turf, target_turf)
	if(!length(path))
		qdel(src)
		return

	// Check for obstacles along the path (shields, walls, dense objects)
	// Lasers can pass through: glass, grilles, tables (like normal laser projectiles)
	var/turf/impact_turf = target_turf
	var/hit_shield = FALSE
	var/hit_obstacle = FALSE
	var/obj/structure/ship_shield_wall/shield_hit

	for(var/turf/T in path)
		// Skip the starting turf
		if(T == start_turf)
			continue

		// Check for shield walls first (highest priority)
		for(var/obj/structure/ship_shield_wall/wall in T)
			shield_hit = wall
			impact_turf = T
			hit_shield = TRUE
			break
		if(hit_shield)
			break

		// Check if the turf itself is dense (walls)
		if(T.density)
			impact_turf = T
			hit_obstacle = TRUE
			break

		// Check for dense objects that would block lasers
		for(var/obj/O in T)
			if(!O.density)
				continue
			// Lasers pass through glass/windows
			if(istype(O, /obj/structure/window))
				continue
			// Lasers pass through grilles
			if(istype(O, /obj/structure/grille))
				continue
			// Lasers pass through tables
			if(istype(O, /obj/structure/table))
				continue
			// Lasers pass through railings
			if(istype(O, /obj/structure/railing))
				continue
			// Dense object blocks the laser
			impact_turf = T
			hit_obstacle = TRUE
			break
		if(hit_obstacle)
			break

	// Truncate path to impact point for beam visuals and damage
	// This avoids recalculating get_line() multiple times
	var/list/impact_path = list()
	for(var/turf/T in path)
		impact_path += T
		if(T == impact_turf)
			break

	// Create beam segments from start to impact (reuse path)
	var/beam_angle = create_beam_visuals(start_turf, impact_turf, is_multi_beam, impact_path)

	// Create end cap at impact point (using same angle as beam)
	create_end_cap(impact_turf, beam_angle, is_multi_beam)

	// Play firing sound at impact location - limited to target ship's areas to prevent bleed
	playsound_ship(impact_turf, 'sound/items/weapons/beam_sniper.ogg', 80, TRUE, 10, target_ship)

	// Damage everything along the beam path (mobs and objects) - reuse path
	damage_along_path(start_turf, impact_turf, impact_path)

	// Deal final impact damage based on what we hit
	if(hit_shield && shield_hit)
		// Hit shields - they absorb with laser multiplier
		shield_hit.absorb_laser_damage(damage, impact_turf)
		// Visual effect at shield impact
		new /obj/effect/temp_visual/ship_laser_hit_shield(impact_turf)
	else
		// Hit the ship/obstacle - deal damage at impact point
		impact_ship(impact_turf)

	// Clean up after beam fades (beam segments have their own duration)
	QDEL_IN(src, 10)

/// Creates the visual beam segments along the path
/// Returns the beam angle for use by the end cap
/// If path_turfs is provided, uses that instead of recalculating get_line()
/obj/effect/ship_laser_beam/proc/create_beam_visuals(turf/start, turf/end, multi_beam = FALSE, list/path_turfs = null)
	// Calculate the angle for rotation first
	var/angle = get_angle(start, end)

	// Use provided path or calculate if not given
	var/list/path = path_turfs || get_line(start, end)
	if(!length(path))
		return angle

	// Create a beam segment on each turf along the path
	for(var/turf/T in path)
		// Don't put beam on the final impact turf (that gets the impact effect)
		if(T == end)
			continue
		var/obj/effect/temp_visual/ship_laser_segment/segment = new(T, multi_beam)
		segment.set_beam_angle(angle)
		beam_segments += segment

	// Return the angle so end cap can use the same rotation
	return angle

/// Creates the impact effect at the impact point
/obj/effect/ship_laser_beam/proc/create_end_cap(turf/impact_loc, beam_angle, multi_beam = FALSE)
	if(!impact_loc)
		return

	end_cap = new /obj/effect/temp_visual/ship_laser_impact(impact_loc, multi_beam)
	end_cap.set_impact_angle(beam_angle)

/// Damages all mobs and objects along the beam path
/// If path_turfs is provided, uses that instead of recalculating get_line()
/obj/effect/ship_laser_beam/proc/damage_along_path(turf/start, turf/end, list/path_turfs = null)
	if(!start || !end)
		return

	// Use provided path or calculate if not given
	var/list/path = path_turfs || get_line(start, end)

	for(var/turf/T in path)
		// Skip the starting turf (outside the ship)
		if(T == start)
			continue
		// Skip the end turf - that gets handled by impact_ship()
		if(T == end)
			continue

		// Damage all mobs and objects on this turf
		for(var/atom/movable/AM in T)
			if(isliving(AM))
				var/mob/living/victim = AM
				victim.adjustFireLoss(damage * 0.5)
				to_chat(victim, span_userdanger("A ship laser burns through you!"))
			else if(isobj(AM))
				var/obj/O = AM
				// Don't damage things lasers pass through (windows, grilles, tables, railings)
				if(istype(O, /obj/structure/window))
					continue
				if(istype(O, /obj/structure/grille))
					continue
				if(istype(O, /obj/structure/table))
					continue
				if(istype(O, /obj/structure/railing))
					continue
				O.take_damage(damage, BURN, LASER)

/// Deals damage to the ship at the impact location
/obj/effect/ship_laser_beam/proc/impact_ship(turf/impact_loc)
	if(!impact_loc)
		return


	// Deal damage to objects/mobs at impact location
	for(var/atom/movable/AM in impact_loc)
		if(isliving(AM))
			var/mob/living/victim = AM
			victim.adjustFireLoss(damage * 0.5)
			to_chat(victim, span_userdanger("You're hit by a ship laser!"))
		else if(isobj(AM))
			var/obj/O = AM
			O.take_damage(damage, BURN, LASER)

	// Damage walls/turfs based on power level
	// At low power (below 150%), minimal wall damage
	// At high power (150%+), significant wall damage that scales with power
	if(impact_loc.density)
		var/wall_damage = 0
		if(power_level >= 1.5)
			// High power mode: walls take significant damage
			// At 150% power: 1.5x base damage
			// At 200% power: 3x base damage (scales quadratically for dramatic effect)
			var/power_bonus = (power_level - 1) * 2  // 0.5 at 150%, 1.0 at 200%
			wall_damage = damage * (1 + power_bonus)
		else
			// Low power: only 10% damage to walls
			wall_damage = damage * 0.1

		if(wall_damage > 0)
			impact_loc.take_damage(wall_damage, BURN, LASER)

	// Small fire effect
	new /obj/effect/hotspot(impact_loc)

	// Screen shake for nearby players on target ship only - stronger at high power
	var/shake_intensity = power_level >= 1.5 ? 2 : 1
	shake_camera_ship(impact_loc, 5, shake_intensity, shake_intensity, target_ship)

	// Signal that hull was hit (for combat camera static updates)
	if(target_ship)
		SEND_SIGNAL(target_ship, COMSIG_SHIP_HULL_HIT, impact_loc)

// ========== BEAM SEGMENT EFFECT ==========

/// Individual beam segment - uses beam_omni for single, plasmacutter for multi
/obj/effect/temp_visual/ship_laser_segment
	name = "laser beam"
	icon = 'icons/obj/weapons/guns/projectiles_tracer.dmi'
	icon_state = "beam_omni"
	duration = 8
	layer = ABOVE_MOB_LAYER
	plane = GAME_PLANE
	light_range = 2
	light_power = 1
	light_color = "#ff3300"

/obj/effect/temp_visual/ship_laser_segment/Initialize(mapload, multi_beam = FALSE)
	. = ..()
	// Use plasmacutter sprite for multi-beam (combined turret fire)
	if(multi_beam)
		icon_state = "plasmacutter"
		light_range = 3
		light_power = 1.5
	// Fade out animation
	animate(src, alpha = 0, time = duration, easing = EASE_OUT)

/// Sets the rotation angle for the beam segment
/obj/effect/temp_visual/ship_laser_segment/proc/set_beam_angle(angle)
	var/matrix/M = matrix()
	// Scale longer (1.5x) to ensure segments overlap and form continuous beam
	// This is needed because diagonal beams would otherwise have gaps between tiles
	// M.Scale(1.5, 1)
	M.Turn(angle)
	transform = M

// ========== BEAM IMPACT EFFECT ==========

/// Impact effect - uses impact_omni for single, impact_plasmacutter for multi
/obj/effect/temp_visual/ship_laser_impact
	name = "laser impact"
	icon = 'icons/obj/weapons/guns/projectiles_impact.dmi'
	icon_state = "impact_omni"
	duration = 8
	layer = ABOVE_MOB_LAYER
	plane = GAME_PLANE
	light_range = 3
	light_power = 1.5
	light_color = "#ff6600"
	randomdir = FALSE
	/// Whether this is a multi-beam impact (stored for animation after angle set)
	var/is_multi_beam = FALSE

/obj/effect/temp_visual/ship_laser_impact/Initialize(mapload, multi_beam = FALSE)
	. = ..()
	is_multi_beam = multi_beam
	// Use plasmacutter impact sprite for multi-beam
	if(multi_beam)
		icon_state = "impact_plasmacutter"
		light_range = 4
		light_power = 2
	// Fade out animation
	animate(src, alpha = 0, time = duration, easing = EASE_OUT)

/// Sets the rotation angle for the impact effect to face towards the beam's source
/obj/effect/temp_visual/ship_laser_impact/proc/set_impact_angle(angle)
	var/matrix/M = matrix()
	M.Turn(angle)
	transform = M

// ========== OTHER VISUAL EFFECTS ==========

/// Blue flash when laser hits shields
/obj/effect/temp_visual/ship_laser_hit_shield
	name = "shield impact"
	desc = "A flash of energy as the laser hits the shields."
	icon = 'icons/effects/effects.dmi'
	icon_state = "shield-flash"
	color = "#00ffff"
	duration = 6
	alpha = 255
	layer = ABOVE_MOB_LAYER
	plane = GAME_PLANE

/obj/effect/temp_visual/ship_laser_hit_shield/Initialize(mapload)
	. = ..()
	animate(src, alpha = 0, time = duration, easing = EASE_OUT)

/// Red/orange flash when laser hits ship hull (legacy, now using ship_laser_impact)
/obj/effect/temp_visual/ship_laser_hit
	name = "laser impact"
	desc = "Superheated metal from a laser strike."
	icon = 'icons/obj/weapons/guns/projectiles_impact.dmi'
	icon_state = "impact_omni"
	color = "#ff6600"
	duration = 10
	alpha = 255
	layer = ABOVE_MOB_LAYER
	plane = GAME_PLANE

/obj/effect/temp_visual/ship_laser_hit/Initialize(mapload)
	. = ..()
	var/matrix/M = matrix()
	M.Turn(90)
	// M.Scale(1.5, 1.5)
	animate(src, alpha = 0, time = duration, easing = EASE_OUT)

// ========== TURRET MUZZLE FLASH EFFECT ==========

/// Muzzle flash effect for turret firing - rotates to match turret direction
/obj/effect/temp_visual/turret_muzzle_flash
	name = "muzzle flash"
	icon = 'icons/obj/weapons/guns/projectiles_muzzle.dmi'
	icon_state = "muzzle_omni"
	duration = 8
	layer = ABOVE_ALL_MOB_LAYER
	plane = ABOVE_GAME_PLANE
	light_range = 3
	light_power = 2
	light_color = "#ff6600"
	mouse_opacity = MOUSE_OPACITY_TRANSPARENT
	randomdir = FALSE

/obj/effect/temp_visual/turret_muzzle_flash/Initialize(mapload, direction = SOUTH)
	. = ..()
	// Rotate and offset based on direction (sprite default faces NORTH)
	// Each direction has custom offsets to match the turret barrel position
	var/angle
	switch(direction)
		if(NORTH)
			angle = 0
			pixel_y = 29
			pixel_x = 0
		if(SOUTH)
			angle = 180
			pixel_y = -14
			pixel_x = 0
		if(EAST)
			angle = 90
			pixel_x = 24
			pixel_y = 5
		if(WEST)
			angle = -90
			pixel_x = -24
			pixel_y = 5
		else
			angle = 0
	var/matrix/M = matrix()
	M.Turn(angle)
	transform = M
	// Quick fade out
	animate(src, alpha = 0, time = duration, easing = EASE_OUT)

// ========== TURRET FIRING VISUAL EFFECT ==========
// Purely cosmetic laser that fires from the turret - does not collide or damage anything
// Visible over everything, passes through walls

/// Creates a visual-only laser beam from a turret in the direction it's facing
/// This is purely cosmetic - it doesn't collide with anything or deal damage
/obj/effect/temp_visual/turret_laser_visual
	name = "laser beam"
	icon = 'icons/obj/weapons/guns/projectiles_tracer.dmi'
	icon_state = "beam_omni"
	duration = 8
	layer = ABOVE_ALL_MOB_LAYER
	plane = ABOVE_GAME_PLANE
	light_range = 2
	light_power = 1
	light_color = "#ff3300"
	mouse_opacity = MOUSE_OPACITY_TRANSPARENT
	randomdir = FALSE
	/// Direction to fire (NORTH, SOUTH, EAST, WEST)
	var/fire_dir = SOUTH
	/// Whether this is a multi-beam effect
	var/is_multi_beam = FALSE
	/// List of beam segments we've created
	var/list/beam_segments = list()
	/// Pixel X offset for beam origin (perpendicular offset applied to all segments)
	var/beam_offset_x = 0
	/// Pixel Y offset for beam origin (perpendicular offset applied to all segments)
	var/beam_offset_y = 0

/obj/effect/temp_visual/turret_laser_visual/Initialize(mapload, direction = SOUTH, multi_beam = FALSE)
	. = ..()
	fire_dir = direction
	is_multi_beam = multi_beam
	// Set beam origin offsets based on direction (to align with turret barrel)
	switch(direction)
		if(NORTH)
			beam_offset_x = 0
			beam_offset_y = 29
		if(SOUTH)
			beam_offset_x = 0
			beam_offset_y = -14
		if(EAST)
			beam_offset_x = 24
			beam_offset_y = 5
		if(WEST)
			beam_offset_x = -24
			beam_offset_y = 5
	// Make controller invisible - segments are visible
	invisibility = INVISIBILITY_ABSTRACT
	// Create the beam after short delay
	addtimer(CALLBACK(src, PROC_REF(create_beam)), 0.1 SECONDS)

/obj/effect/temp_visual/turret_laser_visual/Destroy()
	for(var/obj/effect/segment in beam_segments)
		qdel(segment)
	beam_segments.Cut()
	return ..()

/// Creates the visual beam segments extending from the turret
/obj/effect/temp_visual/turret_laser_visual/proc/create_beam()
	var/turf/start_turf = get_turf(src)
	if(!start_turf)
		return

	// Calculate the angle based on direction
	var/angle
	switch(fire_dir)
		if(NORTH)
			angle = 0
		if(SOUTH)
			angle = 180
		if(EAST)
			angle = 90
		if(WEST)
			angle = -90
		else
			angle = 0

	// Get virtual level bounds from the turf reservation (if in transit/reserved space)
	var/datum/turf_reservation/reservation = SSmapping.get_reservation_from_turf(start_turf)
	var/min_x = 1
	var/max_x = world.maxx
	var/min_y = 1
	var/max_y = world.maxy
	if(reservation && length(reservation.bottom_left_turfs) && length(reservation.top_right_turfs))
		var/turf/bottom_left = reservation.bottom_left_turfs[1]
		var/turf/top_right = reservation.top_right_turfs[1]
		min_x = bottom_left.x
		max_x = top_right.x
		min_y = bottom_left.y
		max_y = top_right.y

	// Get step direction offsets and calculate distance to boundary
	var/dx = 0
	var/dy = 0
	var/max_distance = 0
	switch(fire_dir)
		if(NORTH)
			dy = 1
			max_distance = max_y - start_turf.y
		if(SOUTH)
			dy = -1
			max_distance = start_turf.y - min_y
		if(EAST)
			dx = 1
			max_distance = max_x - start_turf.x
		if(WEST)
			dx = -1
			max_distance = start_turf.x - min_x

	// Create beam segments extending to the virtual level boundary
	var/turf/current = start_turf
	for(var/i in 1 to max_distance)
		var/turf/next = locate(current.x + dx, current.y + dy, current.z)
		if(!next)
			break
		// Stop at cordon turfs (virtual level boundary)
		if(istype(next, /turf/cordon))
			break
		current = next

		var/obj/effect/temp_visual/turret_laser_segment/segment = new(current, is_multi_beam, beam_offset_x, beam_offset_y)
		segment.set_beam_angle(angle)
		beam_segments += segment

/// Individual segment for turret visual beam - purely cosmetic
/obj/effect/temp_visual/turret_laser_segment
	name = "laser beam"
	icon = 'icons/obj/weapons/guns/projectiles_tracer.dmi'
	icon_state = "beam_omni"
	duration = 8
	layer = ABOVE_ALL_MOB_LAYER
	plane = ABOVE_GAME_PLANE
	light_range = 2
	light_power = 1
	light_color = "#ff3300"
	mouse_opacity = MOUSE_OPACITY_TRANSPARENT
	randomdir = FALSE

/obj/effect/temp_visual/turret_laser_segment/Initialize(mapload, multi_beam = FALSE, offset_x = 0, offset_y = 0)
	. = ..()
	if(multi_beam)
		icon_state = "plasmacutter"
		light_range = 3
		light_power = 1.5
	// Apply pixel offsets (to align beam with turret barrel)
	pixel_x = offset_x
	pixel_y = offset_y
	// Fade out animation
	animate(src, alpha = 0, time = duration, easing = EASE_OUT)

/// Sets the rotation angle for the beam segment
/obj/effect/temp_visual/turret_laser_segment/proc/set_beam_angle(angle)
	var/matrix/M = matrix()
	M.Turn(angle)
	transform = M

// ========== OVERMAP LASER EFFECTS ==========
// These are used for the visual beam between ships on the overmap

/// Muzzle flash effect for overmap laser beam - appears at the firing ship
/// Single = omni, Multi (fire all) = plasmacutter
/obj/effect/temp_visual/overmap_muzzle_flash
	name = "muzzle flash"
	icon = 'icons/obj/weapons/guns/projectiles_muzzle.dmi'
	icon_state = "muzzle_omni"
	duration = 5
	layer = ABOVE_MOB_LAYER + 0.1
	plane = GAME_PLANE
	light_range = 3
	light_power = 2
	light_color = "#ff6600"
	mouse_opacity = MOUSE_OPACITY_TRANSPARENT
	randomdir = FALSE

/obj/effect/temp_visual/overmap_muzzle_flash/Initialize(target_atom, multi_beam = FALSE)
	. = ..()
	var/atom/target = target_atom
	// Set sprite based on single vs multi-beam
	if(multi_beam)
		icon_state = "muzzle_plasmacutter"
	else
		icon_state = "muzzle_omni"
	// Rotate to face target (beam travel direction)
	if(isatom(target))
		var/angle = get_angle(src, target)
		var/matrix/M = matrix()
		M.Turn(angle)
		transform = M
	animate(src, alpha = 0, time = duration, easing = EASE_OUT)

/// Impact effect for overmap laser beam - appears at the target ship
/// Single = omni, Multi (fire all) = plasmacutter
/obj/effect/temp_visual/overmap_laser_impact
	name = "laser impact"
	icon = 'icons/obj/weapons/guns/projectiles_impact.dmi'
	icon_state = "impact_omni"
	duration = 5
	layer = ABOVE_MOB_LAYER + 0.1
	plane = GAME_PLANE
	light_range = 3
	light_power = 1.5
	light_color = "#ff6600"
	mouse_opacity = MOUSE_OPACITY_TRANSPARENT
	randomdir = FALSE

/obj/effect/temp_visual/overmap_laser_impact/Initialize(source_atom, multi_beam = FALSE)
	. = ..()
	var/atom/source = source_atom
	// Set sprite based on single vs multi-beam
	if(multi_beam)
		icon_state = "impact_plasmacutter"
	else
		icon_state = "impact_omni"
	// Rotate to face back toward source (where beam came from)
	if(isatom(source))
		var/angle = get_angle(src, source)
		var/matrix/M = matrix()
		M.Turn(angle)
		transform = M
	animate(src, alpha = 0, time = duration, easing = EASE_OUT)
