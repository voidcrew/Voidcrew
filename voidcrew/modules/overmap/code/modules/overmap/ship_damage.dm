/**
 * Ship Damage System
 *
 * Handles ship integrity and damage from hazards.
 * Ships take damage when flying through dangerous overmap objects like
 * ion storms, electrical storms, and meteor fields.
 *
 * Ship health is purely turf-based:
 * - Damage = turfs being destroyed (explosions, meteors, etc.)
 * - Repair = turfs being rebuilt (construction)
 * - SSovermap.fire() calls calculate_mass() every second to update integrity
 */

/obj/structure/overmap/ship
	/// Cooldown for hazard damage ticks
	COOLDOWN_DECLARE(hazard_damage_cooldown)
	/// Whether ship integrity has been initialized from mass
	var/integrity_initialized = FALSE

/obj/structure/overmap/ship/Initialize(mapload, datum/map_template/shuttle/voidcrew/template)
	. = ..()
	if(.)
		// Mass calculation is handled by SSovermap.fire() every second
		// Register signal listeners for damage feedback
		RegisterSignal(src, COMSIG_SHIP_DAMAGE_THRESHOLD, PROC_REF(on_damage_threshold))

/obj/structure/overmap/ship/Destroy()
	UnregisterSignal(src, COMSIG_SHIP_DAMAGE_THRESHOLD)
	return ..()

/**
 * Signal handler for damage thresholds - handles announcements, sounds, and effects
 */
/obj/structure/overmap/ship/proc/on_damage_threshold(datum/source, threshold, display_percent)
	SIGNAL_HANDLER

	switch(threshold)
		if(SHIP_THRESHOLD_MINOR)
			ship_announce("Minor hull damage detected. Integrity at [display_percent]%.", "Damage Report", TRUE, 'sound/machines/beep/triple_beep.ogg')
			play_ship_sound('sound/machines/beep/triple_beep.ogg')

		if(SHIP_THRESHOLD_MODERATE)
			ship_announce("Moderate hull damage sustained. Integrity at [display_percent]%.", "Damage Alert", TRUE, 'sound/machines/warning-buzzer.ogg')
			play_ship_sound('sound/machines/warning-buzzer.ogg')

		if(SHIP_THRESHOLD_SERIOUS)
			ship_announce("WARNING: Serious hull damage! Integrity at [display_percent]%.", "Hull Warning", TRUE, 'sound/machines/warning-buzzer.ogg')
			play_ship_sound('sound/machines/warning-buzzer.ogg')
			shake_ship(10, 2)

		if(SHIP_THRESHOLD_CRITICAL)
			ship_announce("CRITICAL: Hull integrity failing! Integrity at [display_percent]%! Seek immediate repairs!", "Critical Alert", TRUE, 'sound/machines/engine_alert/engine_alert1.ogg')
			play_ship_sound('sound/machines/engine_alert/engine_alert1.ogg')
			shake_ship(20, 3)

		if(SHIP_THRESHOLD_EMERGENCY)
			ship_announce("EMERGENCY: Hull breach imminent! Integrity at [display_percent]%! All hands brace for impact!", "EMERGENCY", TRUE, 'sound/machines/engine_alert/engine_alert2.ogg')
			play_ship_sound('sound/machines/engine_alert/engine_alert2.ogg')
			shake_ship(25, 4)

/**
 * Returns the current integrity as a percentage for UI display
 * Scaled so 50% actual turfs = 0% displayed, 100% actual = 100% displayed
 * This way the health bar hits 0% when the ship is destroyed at 50% mass
 */
/obj/structure/overmap/ship/proc/get_integrity_percent()
	var/raw_percent = (integrity / max_integrity) * 100
	// Scale 50-100% to 0-100%
	var/scaled = ((raw_percent - 50) / 50) * 100
	return round(clamp(scaled, 0, 100))

/**
 * Called when ship integrity reaches 0
 * Strands the ship and triggers cascade failures
 */
/obj/structure/overmap/ship/proc/on_ship_destroyed()
	// Stop the ship dead
	speed[1] = 0
	speed[2] = 0
	if(movement_callback_id)
		deltimer(movement_callback_id)
		movement_callback_id = null

	ship_announce("CATASTROPHIC FAILURE: All systems offline! Hull integrity critical!", "MAYDAY", TRUE, 'sound/machines/warning-buzzer.ogg')

	// Cascade failures - fires, explosions, EMPs throughout the ship
	var/failure_count = rand(8, 15)
	for(var/i in 1 to failure_count)
		var/turf/target = get_random_ship_turf()
		if(!target)
			continue

		switch(rand(1, 4))
			if(1) // Fire
				new /obj/effect/hotspot(target)
			if(2) // Explosion
				explosion(target, light_impact_range = 1, flash_range = 2, adminlog = FALSE)
			if(3) // EMP
				empulse(target, 2, 4)
				playsound(target, 'sound/effects/empulse.ogg', 50, TRUE)
			if(4) // Sparks
				do_sparks(5, FALSE, target)

		playsound(target, 'sound/effects/bang.ogg', 50, TRUE)

	// Shake everyone violently and knock them down
	for(var/mob/living/crew_member in get_all_ship_mobs())
		shake_camera(crew_member, 30, 5)
		crew_member.Knockdown(5 SECONDS)
		to_chat(crew_member, span_userdanger("The ship shudders violently as critical systems fail!"))

	// Dock into a "crashed ship" location so others can find and help/raid
	crash_land()

	// Signal that the ship has been destroyed
	SEND_SIGNAL(src, COMSIG_SHIP_DESTROYED)

/**
 * Emergency docks the ship into a crashed ship location on the overmap
 */
/obj/structure/overmap/ship/proc/crash_land()
	if(!shuttle)
		return

	// Create crashed ship marker at current location
	var/obj/structure/overmap/planet/crashed_ship/crash_site = new(get_turf(src))

	// Load the level
	if(!crash_site.loaded && !crash_site.loading)
		crash_site.load_level()

	// Wait for level to load then dock
	if(crash_site.loading)
		addtimer(CALLBACK(src, PROC_REF(finish_crash_land), crash_site), 2 SECONDS)
		return

	finish_crash_land(crash_site)

/**
 * Finishes the crash landing after the level loads
 */
/obj/structure/overmap/ship/proc/finish_crash_land(obj/structure/overmap/planet/crashed_ship/crash_site)
	if(!crash_site || !shuttle)
		return

	// Get a dock
	var/obj/docking_port/stationary/dock_to_use = null
	if(crash_site.reserve_dock && !crash_site.first_dock_taken)
		dock_to_use = crash_site.reserve_dock
		crash_site.first_dock_taken = TRUE
		dock_index = 1
	else if(crash_site.reserve_dock_secondary && !crash_site.second_dock_taken)
		dock_to_use = crash_site.reserve_dock_secondary
		crash_site.second_dock_taken = TRUE
		dock_index = 2

	if(!dock_to_use)
		return

	shuttle.port_destinations = dock_to_use
	crash_site.adjust_dock_to_shuttle(dock_to_use, shuttle)
	dock(crash_site, dock_to_use)

/**
 * Called when the ship enters a tile - checks for hazards
 */
/obj/structure/overmap/ship/proc/check_hazards()
	for(var/obj/structure/overmap/event/hazard in loc)
		apply_hazard_effect(hazard)

/**
 * Applies the effect of a hazard to the ship
 */
/obj/structure/overmap/ship/proc/apply_hazard_effect(obj/structure/overmap/event/hazard)
	// Meteors always trigger per tile - no cooldown
	if(istype(hazard, /obj/structure/overmap/event/meteor))
		apply_meteor_damage(hazard)
		return

	// Other hazards have a cooldown to prevent spam
	if(!COOLDOWN_FINISHED(src, hazard_damage_cooldown))
		return

	COOLDOWN_START(src, hazard_damage_cooldown, 3 SECONDS)

	if(istype(hazard, /obj/structure/overmap/event/emp))
		apply_ion_storm_damage(hazard)
	else if(istype(hazard, /obj/structure/overmap/event/electric))
		apply_electrical_storm_damage(hazard)
	else if(istype(hazard, /obj/structure/overmap/event/nebula))
		apply_nebula_effect(hazard)

/**
 * Ion Storm Effect
 * EMPs random areas of the ship - no direct hull damage, but EMP can destroy electronics
 * Hull damage comes from destroyed equipment/turfs, detected by calculate_mass()
 */
/obj/structure/overmap/ship/proc/apply_ion_storm_damage(obj/structure/overmap/event/emp/storm)
	var/intensity = storm.intensity
	var/emp_count = 2 + (intensity * 2)

	ship_announce("Ion storm interference detected! Electronic systems may be affected.", "Ion Storm Warning", TRUE, 'sound/effects/empulse.ogg')

	// Create EMPs at random locations in the ship - these can destroy equipment
	for(var/i in 1 to emp_count)
		var/turf/target = get_random_ship_turf()
		if(target)
			// empulse handles the visual effect when heavy_range > 1
			empulse(target, 2 * intensity, 4 * intensity)
			playsound(target, 'sound/effects/empulse.ogg', 50, TRUE)

	// Trigger immediate mass recalculation to detect any destroyed turfs/equipment
	calculate_mass()

/**
 * Electrical Storm Effect
 * Overloads ship lighting fixtures and strikes the ship with real lightning bolts
 * Lights spark and shock nearby crew, while thunderbolts strike random locations
 */
/obj/structure/overmap/ship/proc/apply_electrical_storm_damage(obj/structure/overmap/event/electric/storm)
	var/intensity = storm.intensity

	ship_announce("Electrical storm detected! Lighting systems overloading!", "Electrical Storm Warning", TRUE, 'sound/effects/sparks/sparks1.ogg')

	// Spawn real lightning strikes - but not on minor storms
	// Minor: no lightning, Moderate: 1 strike (40% chance each), Major: 2-3 strikes
	if(!istype(storm, /obj/structure/overmap/event/electric/minor))
		var/lightning_count = intensity // 1 for moderate, 2 for major
		for(var/i in 1 to lightning_count)
			// Moderate storms have lower chance per bolt
			var/strike_chance = (intensity == 1) ? 40 : 100
			if(!prob(strike_chance))
				continue
			var/turf/strike_target = get_random_ship_turf()
			if(strike_target)
				// Stagger the strikes for dramatic effect
				addtimer(CALLBACK(src, PROC_REF(lightning_strike), strike_target), rand(0.5 SECONDS, 3 SECONDS))

	// Find all lights on the ship that are currently on
	var/list/ship_lights = list()
	for(var/area/ship_area as anything in shuttle.shuttle_areas)
		for(var/obj/machinery/light/light in ship_area)
			if(light.on)
				ship_lights += light

	if(!length(ship_lights))
		// No lights? Just do random sparks
		for(var/i in 1 to 3)
			var/turf/target = get_random_ship_turf()
			if(target)
				do_sparks(5, FALSE, target)
		return

	// Overload a number of lights based on intensity
	var/lights_to_overload = min(length(ship_lights), 3 + (intensity * 2))
	var/list/chosen_lights = list()

	for(var/i in 1 to lights_to_overload)
		if(!length(ship_lights))
			break
		chosen_lights += pick_n_take(ship_lights)

	// Make lights spark and schedule lightning strikes
	for(var/obj/machinery/light/light as anything in chosen_lights)
		light.visible_message(span_boldwarning("[light] suddenly flares brightly and begins to spark!"))
		var/datum/effect_system/spark_spread/light_sparks = new /datum/effect_system/spark_spread()
		light_sparks.set_up(4, 0, light)
		light_sparks.start()
		light.flicker(10)
		// Schedule the lightning strike from light
		addtimer(CALLBACK(src, PROC_REF(electrical_storm_shock), light, intensity), rand(1 SECONDS, 2 SECONDS))

	// Trigger immediate mass recalculation
	calculate_mass()

/**
 * Spawns a real lightning bolt strike at the target turf
 * Same effect as rain storm thunder - visual, damage, explosion
 */
/obj/structure/overmap/ship/proc/lightning_strike(turf/target)
	if(!target)
		return

	// Create the thunderbolt visual effect
	var/obj/effect/temp_visual/thunderbolt/thunder = new(target)
	thunder.flash_lighting_fx(6, 2, duration = thunder.duration)

	// Electrocute anyone standing on the turf
	for(var/mob/living/hit_mob in target)
		to_chat(hit_mob, span_userdanger("You've been struck by lightning!"))
		hit_mob.electrocute_act(50, "lightning", flags = SHOCK_TESLA|SHOCK_NOGLOVES)

	// Damage objects on the turf
	for(var/obj/hit_thing in target)
		if(QDELETED(hit_thing))
			continue
		if(!hit_thing.uses_integrity)
			continue
		if(hit_thing.invisibility != INVISIBILITY_NONE)
			continue
		if(HAS_TRAIT(hit_thing, TRAIT_UNDERFLOOR))
			continue
		hit_thing.take_damage(20, BURN, ENERGY, FALSE)

	// Sound and message
	playsound(target, 'sound/effects/magic/lightningbolt.ogg', 100, extrarange = 10, falloff_distance = 10)
	target.visible_message(span_danger("A thunderbolt strikes [target]!"))

	// Small explosion and fire
	explosion(target, light_impact_range = 1, flame_range = 1, silent = TRUE, adminlog = FALSE)

/**
 * Called after delay - makes a light shoot lightning at nearby crew
 */
/obj/structure/overmap/ship/proc/electrical_storm_shock(obj/machinery/light/source_light, intensity)
	if(QDELETED(source_light))
		return

	// Chance for this light to actually discharge lightning
	// Minor/Moderate (intensity 1): 50% chance
	// Major (intensity 2): 75% chance
	if(!prob(25 + (intensity * 25)))
		return

	var/shock_range = 2 + intensity
	var/shock_damage = 10 + (intensity * 5)

	// Find and shock nearby crew
	for(var/mob/living/carbon/victim in view(shock_range, source_light))
		// Draw lightning beam
		source_light.Beam(victim, icon_state = "lightning[rand(1,12)]", time = 0.5 SECONDS)
		// Shock them
		victim.electrocute_act(shock_damage, source_light, flags = SHOCK_NOGLOVES)
		do_sparks(4, FALSE, victim)
		playsound(victim, 'sound/effects/magic/lightningshock.ogg', 50, TRUE)

	// Chance to break the light based on intensity
	if(prob(20 * intensity))
		source_light.break_light_tube()

/**
 * Meteor Storm Effect
 * Spawns a single meteor that crashes through the ship
 */
/obj/structure/overmap/ship/proc/apply_meteor_damage(obj/structure/overmap/event/meteor/storm)
	if(!shuttle)
		return

	var/meteor_type = /obj/effect/meteor/medium

	if(istype(storm, /obj/structure/overmap/event/meteor/majour))
		meteor_type = /obj/effect/meteor/big
	else if(istype(storm, /obj/structure/overmap/event/meteor/minor))
		meteor_type = /obj/effect/meteor/medium

	// Spawn one meteor aimed at the ship
	spawn_meteor_at_ship(meteor_type)

	// Schedule mass recalculation after meteor has time to hit (meteors take a moment to travel)
	addtimer(CALLBACK(src, PROC_REF(calculate_mass)), 3 SECONDS)

/**
 * Spawns a single meteor from outside the ship aimed at a random ship turf
 */
/obj/structure/overmap/ship/proc/spawn_meteor_at_ship(meteor_type)
	// Pick a random target inside the ship
	var/turf/target = get_random_ship_turf()
	if(!target)
		return

	var/target_z = target.z
	var/target_x = target.x
	var/target_y = target.y

	// Pick a random direction and spawn from that side
	var/turf/spawn_turf
	var/spawn_distance = 15

	switch(pick(1, 2, 3, 4))
		if(1) // From North
			spawn_turf = locate(target_x, target_y + spawn_distance, target_z)
		if(2) // From South
			spawn_turf = locate(target_x, target_y - spawn_distance, target_z)
		if(3) // From East
			spawn_turf = locate(target_x + spawn_distance, target_y, target_z)
		if(4) // From West
			spawn_turf = locate(target_x - spawn_distance, target_y, target_z)

	if(!spawn_turf)
		return

	// Spawn meteor - pass target as second arg (becomes mapload, but meteor still chases it)
	var/obj/effect/meteor/M = new meteor_type(spawn_turf, target)
	// Add traits to let it move through hyperspace/cordon areas without being deleted or drifted
	ADD_TRAIT(M, TRAIT_FREE_HYPERSPACE_MOVEMENT, INNATE_TRAIT)
	ADD_TRAIT(M, TRAIT_FREE_HYPERSPACE_SOFTCORDON_MOVEMENT, INNATE_TRAIT)
	ADD_TRAIT(M, TRAIT_HYPERSPACED, INNATE_TRAIT) // Prevent shuttle_cling component

/**
 * Nebula Effect
 * Reduces sensor effectiveness, minor atmos contamination
 */
/obj/structure/overmap/ship/proc/apply_nebula_effect(obj/structure/overmap/event/nebula/cloud)
	// Nebulas don't deal damage but can contaminate atmosphere
	// For now just a visual/atmospheric effect
	var/turf/target = get_random_ship_turf()
	if(target && prob(30))
		// Add some plasma to the air if the nebula is plasma-based
		var/datum/gas_mixture/air = target.return_air()
		if(air)
			air.assert_gas(/datum/gas/plasma)
			air.gases[/datum/gas/plasma][MOLES] += 0.5

/**
 * Gets a random turf inside the ship for targeting effects
 * Uses direct area iteration instead of get_area_turfs() to avoid
 * returning turfs from other ships with the same area types
 */
/obj/structure/overmap/ship/proc/get_random_ship_turf()
	if(!shuttle?.shuttle_areas?.len)
		return null

	// Collect all turfs from this ship's areas only
	// We iterate through the area contents directly, not by area type
	var/list/all_turfs = list()
	for(var/area/ship_area as anything in shuttle.shuttle_areas)
		for(var/turf/T in ship_area)
			all_turfs += T

	if(!length(all_turfs))
		return null

	return pick(all_turfs)

/**
 * Gets all living mobs currently on the ship
 */
/obj/structure/overmap/ship/proc/get_all_ship_mobs()
	var/list/mobs = list()
	if(!shuttle?.shuttle_areas?.len)
		return mobs

	for(var/area/ship_area as anything in shuttle.shuttle_areas)
		for(var/mob/living/crew in ship_area)
			mobs += crew

	return mobs

/**
 * Plays a sound to all mobs on the ship
 */
/obj/structure/overmap/ship/proc/play_ship_sound(sound_file, volume = 50)
	for(var/mob/living/crew in get_all_ship_mobs())
		SEND_SOUND(crew, sound(sound_file, volume = volume))

/**
 * Shakes the camera for all mobs on the ship
 * @param duration - How long to shake (in ticks)
 * @param strength - How intense the shake is
 */
/obj/structure/overmap/ship/proc/shake_ship(duration = 10, strength = 2)
	for(var/mob/living/crew in get_all_ship_mobs())
		shake_camera(crew, duration, strength)
