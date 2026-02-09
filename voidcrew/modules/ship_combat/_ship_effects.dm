// Ship-Limited Effects
// Helper procs for playing sounds and screen shakes that respect ship boundaries
// in hyperspace/reserved space where multiple ships share a z-level

/// Plays a sound only to mobs within a specific ship's areas
/// This prevents sounds from bleeding across to other ships in reserved space
/proc/playsound_ship(turf/source_turf, sound, volume = 100, vary = TRUE, extrarange = 0, obj/structure/overmap/ship/target_ship)
	if(!source_turf || !target_ship?.shuttle?.shuttle_areas)
		// Fallback to normal playsound if no ship context
		playsound(source_turf, sound, volume, vary, extrarange = extrarange, pressure_affected = FALSE)
		return

	var/list/ship_areas = target_ship.shuttle.shuttle_areas

	// Calculate the effective hearing range
	var/range = world.view + extrarange

	for(var/mob/listener in get_hearers_in_range(range, source_turf))
		if(!listener.client)
			continue

		// Check if listener is within the target ship's areas
		var/area/listener_area = get_area(listener)
		if(!(listener_area in ship_areas))
			continue

		// Calculate distance-based volume falloff
		var/distance = get_dist(source_turf, get_turf(listener))
		var/adjusted_volume = volume
		if(distance > world.view)
			// Reduce volume for distant listeners (within extrarange)
			adjusted_volume = max(volume * 0.5, volume - (distance - world.view) * 5)

		// Play the sound to this specific listener
		var/sound/played_sound = sound(sound)
		played_sound.volume = adjusted_volume
		if(vary)
			played_sound.frequency = rand(75, 125) / 100
		SEND_SOUND(listener, played_sound)

/// Shakes cameras only for mobs within a specific ship's areas
/// This prevents screen shakes from affecting players on other ships in reserved space
/proc/shake_camera_ship(turf/epicenter, shake_range = 7, duration = 3, strength = 2, obj/structure/overmap/ship/target_ship)
	if(!epicenter)
		return

	// If no ship context, check for mobs in range but filter by area
	var/list/ship_areas
	if(target_ship?.shuttle?.shuttle_areas)
		ship_areas = target_ship.shuttle.shuttle_areas

	for(var/mob/living/victim in range(shake_range, epicenter))
		// If we have ship areas, filter to only those within the ship
		if(ship_areas)
			var/area/victim_area = get_area(victim)
			if(!(victim_area in ship_areas))
				continue

		shake_camera(victim, duration, strength)

/// Combined explosion effects (sound + screenshake) limited to a specific ship
/// Use this after calling explosion() with silent = TRUE
/proc/ship_explosion_effects(turf/epicenter, obj/structure/overmap/ship/target_ship, near_sound = 'sound/effects/explosion/explosion2.ogg', far_sound = 'sound/effects/explosion/explosionfar.ogg', near_range = 7, far_range = 14, quake_factor = 0, echo_factor = 0)
	if(!epicenter)
		return

	// Get ship areas if available
	var/list/ship_areas
	if(target_ship?.shuttle?.shuttle_areas)
		ship_areas = target_ship.shuttle.shuttle_areas

	// Sound ranges
	var/near_dist = world.view + near_range
	var/far_dist = world.view + far_range

	// Screenshake caps (matching TG's shake_the_room)
	var/near_shake_cap = 5
	var/far_shake_cap = 1.5
	var/near_shake_duration = 1.5 SECONDS
	var/far_shake_duration = 1 SECONDS

	for(var/mob/listener as anything in GLOB.player_list)
		var/turf/listener_turf = get_turf(listener)
		if(!listener_turf)
			continue

		// Must be on same z-level
		if(listener_turf.z != epicenter.z)
			continue

		// If we have ship areas, filter to only those within the ship
		if(ship_areas)
			var/area/listener_area = get_area(listener_turf)
			if(!(listener_area in ship_areas))
				continue

		var/distance = get_dist(epicenter, listener_turf)

		// Near range - full explosion sound and strong shake
		if(distance <= near_dist)
			var/sound/explosion_sound = sound(near_sound)
			SEND_SOUND(listener, explosion_sound)

			// Screenshake - scales with quake_factor but caps at near_shake_cap
			if(quake_factor > 0)
				var/shake_strength = min(quake_factor, near_shake_cap)
				shake_camera(listener, near_shake_duration, shake_strength)
			else
				// Default shake for explosions
				shake_camera(listener, near_shake_duration, min(2, near_shake_cap))

		// Far range - distant explosion sound and mild shake
		else if(distance <= far_dist)
			var/sound/explosion_sound = sound(far_sound)
			explosion_sound.volume = 50  // Quieter at distance
			SEND_SOUND(listener, explosion_sound)

			// Mild screenshake at distance
			if(quake_factor > 0 || echo_factor > 0)
				var/shake_strength = min(max(quake_factor * 0.3, echo_factor * 0.2), far_shake_cap)
				if(shake_strength > 0)
					shake_camera(listener, far_shake_duration, shake_strength)
