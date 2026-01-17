// Ship Combat Missile Effect
// Flying missile projectile that travels toward a target turf
// Based on meteor movement patterns - spawns at edge of target ship and flies in

/// Global proc to create a ship missile after a delay (called via timer from launcher)
/proc/create_ship_missile(effect_type, turf/spawn_turf, turf/target, obj/structure/overmap/ship/target_ship, obj/structure/overmap/ship/source_ship, damage, devastation, heavy, light, flame, icon_state, obj/item/grenade/chem_grenade/grenade)
	if(!spawn_turf || !target)
		return
	new effect_type(
		spawn_turf,
		target,
		target_ship,
		source_ship,
		damage,
		devastation,
		heavy,
		light,
		flame,
		icon_state,
		grenade,
	)

/obj/effect/ship_missile
	name = "ship missile"
	desc = "A ship-to-ship missile streaking through space."
	icon = 'voidcrew/icons/obj/supplypods.dmi'
	icon_state = "missile"
	density = TRUE
	anchored = TRUE
	pass_flags = PASSTABLE
	layer = ABOVE_MOB_LAYER

	/// The target turf we're flying toward
	var/turf/target_turf
	/// The ship we're targeting (for signal purposes)
	var/obj/structure/overmap/ship/target_ship
	/// The ship that fired us
	var/obj/structure/overmap/ship/source_ship
	/// Damage dealt on impact
	var/damage = MISSILE_DAMAGE_STANDARD
	/// Explosion devastation range
	var/explosion_devastation = MISSILE_EXPLOSION_DEVASTATION
	/// Explosion heavy range
	var/explosion_heavy = MISSILE_EXPLOSION_HEAVY
	/// Explosion light range
	var/explosion_light = MISSILE_EXPLOSION_LIGHT
	/// Explosion flame range
	var/explosion_flame = MISSILE_EXPLOSION_FLAME
	/// Sound to play on impact
	var/impact_sound = 'sound/effects/meteorimpact.ogg'
	/// Our starting z level
	var/z_original
	/// Lifetime before auto-deletion (in deciseconds)
	var/lifetime = MISSILE_FLIGHT_LIFETIME
	/// Have we already exploded?
	var/exploded = FALSE

/obj/effect/ship_missile/New()
	// Add hyperspace traits in New() BEFORE the object is placed on the turf
	// This is critical because transit turfs check for TRAIT_HYPERSPACED on COMSIG_ATOM_ENTERED
	// which fires before Initialize() runs
	ADD_TRAIT(src, TRAIT_FREE_HYPERSPACE_MOVEMENT, INNATE_TRAIT)
	ADD_TRAIT(src, TRAIT_FREE_HYPERSPACE_SOFTCORDON_MOVEMENT, INNATE_TRAIT)
	ADD_TRAIT(src, TRAIT_HYPERSPACED, INNATE_TRAIT)
	return ..()

/obj/effect/ship_missile/Initialize(mapload, turf/target, obj/structure/overmap/ship/target_ship_ref, obj/structure/overmap/ship/source_ship_ref, missile_damage, dev_range, heavy_range, light_range, flame_range, missile_icon)
	. = ..()

	// Store our starting z-level (we're spawned directly at our start position by the launcher)
	z_original = z

	target_turf = target
	target_ship = target_ship_ref
	source_ship = source_ship_ref

	// Apply damage parameters if provided
	if(missile_damage)
		damage = missile_damage
	if(!isnull(dev_range))
		explosion_devastation = dev_range
	if(!isnull(heavy_range))
		explosion_heavy = heavy_range
	if(!isnull(light_range))
		explosion_light = light_range
	if(!isnull(flame_range))
		explosion_flame = flame_range
	if(missile_icon)
		icon_state = missile_icon

	// Set direction to face the target using directional sprites
	if(target_turf)
		var/turf/our_turf = get_turf(src)
		if(our_turf)
			// Use dir for 4-directional sprites instead of matrix rotation
			// get_dir gives us the cardinal/diagonal direction
			var/target_dir = get_dir(our_turf, target_turf)
			// Convert to cardinal direction (missile sprites only have 4 dirs)
			// Diagonals get converted to the dominant axis
			switch(target_dir)
				if(NORTH, SOUTH, EAST, WEST)
					dir = target_dir
				if(NORTHEAST, NORTHWEST)
					dir = NORTH
				if(SOUTHEAST, SOUTHWEST)
					dir = SOUTH

	// Start moving toward target
	if(target_turf)
		chase_target(target_turf)
		// Play incoming whistle at target location so people at the impact site hear the warning
		// Ship-limited to prevent sound bleed to other ships in reserved space
		playsound_ship(target_turf, 'voidcrew/sound/machines/rocket/rocket_whistle.ogg', 80, TRUE, 30, target_ship)

	// Send fired signal
	if(source_ship)
		SEND_SIGNAL(source_ship, COMSIG_SHIP_MISSILE_FIRED, src, target_ship)
		SEND_SIGNAL(source_ship, COMSIG_SHIP_WEAPON_FIRED)

/obj/effect/ship_missile/Destroy()
	var/datum/move_loop/moveloop = GLOB.move_manager.processing_on(src, SSmovement)
	if(!isnull(moveloop))
		UnregisterSignal(moveloop, COMSIG_MOVELOOP_STOP)
	target_turf = null
	target_ship = null
	source_ship = null
	return ..()

/obj/effect/ship_missile/Moved(atom/old_loc, movement_dir, forced, list/old_locs, momentum_change = TRUE)
	. = ..()
	if(QDELETED(src))
		return

	// Check if we've left the z-level (but only after we've been set up)
	if(z_original && z != z_original)
		qdel(src)
		return

	// Check if we've hit the target turf
	// Shield walls will physically intercept via Bump() if shields are active
	var/turf/current = get_turf(src)
	if(current == target_turf)
		impact()

/obj/effect/ship_missile/Process_Spacemove(movement_dir = 0, continuous_move = FALSE)
	return TRUE // Don't drift

/// Allow other missiles to pass through us - prevents missile-on-missile collisions
/obj/effect/ship_missile/CanAllowThrough(atom/movable/mover, border_dir)
	if(istype(mover, /obj/effect/ship_missile))
		return TRUE
	return ..()

/obj/effect/ship_missile/Bump(atom/A)
	// Ignore collisions with other missiles
	if(istype(A, /obj/effect/ship_missile))
		return ..()

	// Call parent first - this triggers Bumped() on whatever we hit
	// Shield walls use Bumped() to absorb damage and set exploded = TRUE
	. = ..()

	// If already handled by shield wall (exploded flag set), don't explode again
	if(exploded || QDELETED(src))
		return

	// If we hit something dense, we need to explode ON it, not next to it in space
	if(A && A.density)
		// Get the turf of the thing we hit
		var/turf/impact_turf = get_turf(A)
		if(impact_turf)
			// Force move to that turf so the explosion epicenter is on the ship
			forceMove(impact_turf)
		impact()

/// Start chasing the target turf
/obj/effect/ship_missile/proc/chase_target(atom/chasing)
	if(!isatom(chasing))
		return
	var/datum/move_loop/new_loop = GLOB.move_manager.move_towards(src, chasing, MISSILE_SPEED, FALSE, lifetime)
	if(new_loop)
		RegisterSignal(new_loop, COMSIG_MOVELOOP_STOP, PROC_REF(on_loop_stopped))

/obj/effect/ship_missile/proc/on_loop_stopped(datum/source)
	SIGNAL_HANDLER
	if(!exploded)
		impact()

/// Called when the missile reaches its target or hits something
/// Shield walls physically intercept missiles via Bump() before this is called
/obj/effect/ship_missile/proc/impact()
	if(exploded)
		return

	var/turf/impact_loc = get_turf(src)
	exploded = TRUE

	// Play impact sound - limited to target ship's areas to prevent bleed to other ships in reserved space
	var/sound_range
	switch(damage)
		if(MISSILE_DAMAGE_HEAVY to INFINITY)
			sound_range = 20
		if(MISSILE_DAMAGE_STANDARD to MISSILE_DAMAGE_HEAVY - 1)
			sound_range = 15
		else
			sound_range = 10
	playsound_ship(impact_loc, impact_sound, 80, TRUE, sound_range, target_ship)

	// Create explosion - ignorecap = TRUE so ship missiles bypass the server bomb cap
	// silent = TRUE to prevent z-level wide sound/shake, we handle those with ship-limited procs
	explosion(
		impact_loc,
		devastation_range = explosion_devastation,
		heavy_impact_range = explosion_heavy,
		light_impact_range = explosion_light,
		flame_range = explosion_flame,
		flash_range = explosion_light + 1,
		adminlog = TRUE,
		ignorecap = TRUE,
		silent = TRUE,
		explosion_cause = src
	)

	// Ship-limited explosion effects (sound + screenshake) - only affects mobs on the target ship
	ship_explosion_effects(impact_loc, target_ship, quake_factor = explosion_devastation, echo_factor = explosion_heavy)

	// Screen shake for nearby players on the target ship only
	shake_camera_ship(impact_loc, 7, 3, 2, target_ship)

	// Signal that hull was hit (for combat camera static updates)
	if(target_ship)
		SEND_SIGNAL(target_ship, COMSIG_SHIP_HULL_HIT, impact_loc)
		// Signal for NPC mass recalculation - missiles destroy turfs via explosion
		SEND_SIGNAL(target_ship, COMSIG_SHIP_EXPLOSIVE_DAMAGE, impact_loc)

	qdel(src)

/// Called when the missile hits a shield - creates explosion effects without hull damage
/// Shield has already absorbed the damage, this is just for visual/audio feedback
/obj/effect/ship_missile/proc/shield_impact()
	if(exploded)
		return

	var/turf/impact_loc = get_turf(src)
	exploded = TRUE

	// Play impact sound - limited to target ship's areas
	playsound_ship(impact_loc, impact_sound, 80, TRUE, 10, target_ship)

	// Create explosion visual - reduced damage since shield absorbed it
	// The explosion still happens visually but with minimal structural damage
	// silent = TRUE to prevent z-level wide sound/shake
	explosion(
		impact_loc,
		devastation_range = 0,  // No devastation - shield absorbed it
		heavy_impact_range = 0,  // No heavy damage - shield absorbed it
		light_impact_range = max(1, explosion_light),  // Small light damage for visual effect
		flame_range = explosion_flame,  // Keep flame for visual
		flash_range = explosion_light + 2,  // Bigger flash to show shield impact
		adminlog = TRUE,
		ignorecap = TRUE,
		silent = TRUE,
		explosion_cause = src
	)

	// Ship-limited explosion effects
	ship_explosion_effects(impact_loc, target_ship)

	// Screen shake for nearby players on the target ship only
	shake_camera_ship(impact_loc, 7, 3, 2, target_ship)

	qdel(src)

// ========== CHEMICAL MISSILE VARIANT ==========

/obj/effect/ship_missile/chemical
	name = "chemical ship missile"
	desc = "A chemical warhead missile streaking through space."
	/// The grenade payload to detonate on impact
	var/obj/item/grenade/chem_grenade/payload_grenade

/obj/effect/ship_missile/chemical/Initialize(mapload, turf/target, obj/structure/overmap/ship/target_ship_ref, obj/structure/overmap/ship/source_ship_ref, missile_damage, dev_range, heavy_range, light_range, flame_range, missile_icon, obj/item/grenade/chem_grenade/grenade)
	. = ..()
	if(grenade)
		payload_grenade = grenade
		// Move the grenade into the missile so it travels with us
		grenade.forceMove(src)

/obj/effect/ship_missile/chemical/Destroy()
	payload_grenade = null
	return ..()

/obj/effect/ship_missile/chemical/impact()
	if(exploded)
		return

	var/turf/impact_loc = get_turf(src)
	exploded = TRUE

	// Play impact sound - limited to target ship's areas
	playsound_ship(impact_loc, impact_sound, 80, TRUE, 10, target_ship)

	// Create small explosion first
	// silent = TRUE to prevent z-level wide sound/shake
	explosion(
		impact_loc,
		devastation_range = 0,
		heavy_impact_range = 0,
		light_impact_range = explosion_light,
		flame_range = 0,
		flash_range = 2,
		adminlog = TRUE,
		ignorecap = TRUE,
		silent = TRUE,
		explosion_cause = src
	)

	// Ship-limited explosion effects
	ship_explosion_effects(impact_loc, target_ship)

	// Detonate the chemical grenade at the impact location
	if(payload_grenade && !QDELETED(payload_grenade))
		// Move grenade to impact location and trigger native detonation
		payload_grenade.forceMove(impact_loc)
		payload_grenade.detonate()

	// Screen shake for nearby players on the target ship only
	shake_camera_ship(impact_loc, 7, 2, 1, target_ship)

	qdel(src)

/obj/effect/ship_missile/chemical/shield_impact()
	if(exploded)
		return

	var/turf/impact_loc = get_turf(src)
	exploded = TRUE

	// Play impact sound - limited to target ship's areas
	playsound_ship(impact_loc, impact_sound, 80, TRUE, 10, target_ship)

	// Visual explosion against shield - chemicals are blocked
	// silent = TRUE to prevent z-level wide sound/shake
	explosion(
		impact_loc,
		devastation_range = 0,
		heavy_impact_range = 0,
		light_impact_range = 1,
		flame_range = 0,
		flash_range = 3,
		adminlog = TRUE,
		ignorecap = TRUE,
		silent = TRUE,
		explosion_cause = src
	)

	// Ship-limited explosion effects
	ship_explosion_effects(impact_loc, target_ship)

	// Chemical payload is blocked by shields - grenade does NOT detonate
	// The grenade is simply destroyed along with the missile
	if(payload_grenade && !QDELETED(payload_grenade))
		qdel(payload_grenade)

	// Screen shake on target ship only
	shake_camera_ship(impact_loc, 7, 2, 1, target_ship)

	qdel(src)

// ========== MISSILE LAUNCH VISUAL EFFECT ==========
// Purely cosmetic missile that fires from the launcher and flies off-screen
// Similar to turret_laser_visual but for missiles

/obj/effect/temp_visual/missile_launch_visual
	name = "missile"
	desc = "A missile launching into space."
	icon = 'voidcrew/icons/obj/supplypods.dmi'
	icon_state = "missile"
	duration = 30  // 3 seconds
	layer = ABOVE_ALL_MOB_LAYER
	plane = ABOVE_GAME_PLANE
	mouse_opacity = MOUSE_OPACITY_TRANSPARENT
	randomdir = FALSE
	// Explicit pixel offsets to prevent animate() from affecting other objects on same turf
	pixel_x = 0
	pixel_y = 0
	/// Direction to fire (NORTH, SOUTH, EAST, WEST)
	var/fire_dir = SOUTH

/obj/effect/temp_visual/missile_launch_visual/Initialize(mapload, direction = SOUTH, offset_x = -16, offset_y = -16)
	. = ..()
	fire_dir = direction

	// Set starting position from launcher's configured offsets
	pixel_x = offset_x
	pixel_y = offset_y

	// Use directional sprites instead of matrix rotation
	dir = fire_dir

	// Start flying animation after short delay
	addtimer(CALLBACK(src, PROC_REF(start_flying)), 0.1 SECONDS)

/// Animates the missile flying off-screen
/obj/effect/temp_visual/missile_launch_visual/proc/start_flying()
	if(QDELETED(src))
		return

	var/turf/start_turf = get_turf(src)
	if(!start_turf)
		return

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

	// Calculate travel distance based on direction
	var/travel_distance = 0

	switch(fire_dir)
		if(NORTH)
			travel_distance = max_y - start_turf.y
		if(SOUTH)
			travel_distance = start_turf.y - min_y
		if(EAST)
			travel_distance = max_x - start_turf.x
		if(WEST)
			travel_distance = start_turf.x - min_x

	// Calculate pixel offset to reach destination
	var/pixel_dest_x = 0
	var/pixel_dest_y = 0
	switch(fire_dir)
		if(NORTH)
			pixel_dest_y = travel_distance * 32
		if(SOUTH)
			pixel_dest_y = -travel_distance * 32
		if(EAST)
			pixel_dest_x = travel_distance * 32
		if(WEST)
			pixel_dest_x = -travel_distance * 32

	// Animate the missile flying off screen
	// Speed: roughly 2 tiles per decisecond (similar to missile speed)
	var/flight_time = max(5, travel_distance * 0.5)  // Min 0.5 seconds, scales with distance
	animate(src, pixel_x = pixel_dest_x, pixel_y = pixel_dest_y, time = flight_time, easing = LINEAR_EASING)

	// Delete after animation completes
	QDEL_IN(src, flight_time + 1)
