/**
 * Ship Damage System
 *
 * Handles ship integrity, damage from hazards, and health regeneration.
 * Ships take damage when flying through dangerous overmap objects like
 * ion storms, electrical storms, and meteor fields.
 */

/// How often the ship regenerates health (in deciseconds)
#define SHIP_REGEN_INTERVAL (30 SECONDS)
/// How much integrity the ship regenerates per tick
#define SHIP_REGEN_AMOUNT 2
/// Minimum integrity before the ship is considered critically damaged
#define SHIP_CRITICAL_THRESHOLD 25
/// Maximum integrity
#define SHIP_MAX_INTEGRITY 100

/obj/structure/overmap/ship
	/// Timer ID for the health regeneration loop
	var/regen_timer_id
	/// Whether the ship is currently taking hazard damage (prevents regen)
	var/in_hazard = FALSE
	/// Cooldown for hazard damage ticks
	COOLDOWN_DECLARE(hazard_damage_cooldown)

/obj/structure/overmap/ship/Initialize(mapload, datum/map_template/shuttle/voidcrew/template)
	. = ..()
	if(.)
		start_regen_timer()

/obj/structure/overmap/ship/Destroy()
	stop_regen_timer()
	return ..()

/**
 * Starts the health regeneration timer
 */
/obj/structure/overmap/ship/proc/start_regen_timer()
	if(regen_timer_id)
		return
	regen_timer_id = addtimer(CALLBACK(src, PROC_REF(regen_tick)), SHIP_REGEN_INTERVAL, TIMER_STOPPABLE | TIMER_LOOP)

/**
 * Stops the health regeneration timer
 */
/obj/structure/overmap/ship/proc/stop_regen_timer()
	if(regen_timer_id)
		deltimer(regen_timer_id)
		regen_timer_id = null

/**
 * Called every SHIP_REGEN_INTERVAL to regenerate ship health
 */
/obj/structure/overmap/ship/proc/regen_tick()
	if(in_hazard)
		return // Don't regen while in a hazard
	if(integrity >= SHIP_MAX_INTEGRITY)
		return // Already at max

	integrity = min(integrity + SHIP_REGEN_AMOUNT, SHIP_MAX_INTEGRITY)

/**
 * Deals damage to the ship's integrity
 * @param amount - How much damage to deal
 * @param damage_type - Type of damage for logging/effects
 * @param silent - If TRUE, doesn't announce damage
 */
/obj/structure/overmap/ship/proc/receive_damage(amount, damage_type = "unknown", silent = FALSE)
	if(amount <= 0)
		return

	var/old_integrity = integrity
	integrity = max(0, integrity - amount)

	if(!silent)
		var/severity = "minor"
		if(amount >= 15)
			severity = "severe"
		else if(amount >= 8)
			severity = "moderate"

		ship_announce("Hull integrity compromised! [severity] [damage_type] damage sustained. Hull at [integrity]%.", "Damage Alert", TRUE, 'sound/machines/warning-buzzer.ogg')

	// Check for critical damage threshold crossing
	if(old_integrity > SHIP_CRITICAL_THRESHOLD && integrity <= SHIP_CRITICAL_THRESHOLD)
		ship_announce("WARNING: Hull integrity critical! Seek repairs immediately!", "Critical Damage", TRUE, 'sound/machines/warning-buzzer.ogg')

	// Check for ship destruction - only trigger once when first reaching 0
	if(old_integrity > 0 && integrity <= 0)
		on_ship_destroyed()

/**
 * Repairs the ship's hull integrity
 * @param amount - How much to repair
 */
/obj/structure/overmap/ship/proc/repair_hull(amount)
	if(amount <= 0)
		return

	integrity = min(integrity + amount, SHIP_MAX_INTEGRITY)

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
	in_hazard = FALSE

	for(var/obj/structure/overmap/event/hazard in loc)
		in_hazard = TRUE
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
 * EMPs random areas of the ship and deals moderate hull damage
 */
/obj/structure/overmap/ship/proc/apply_ion_storm_damage(obj/structure/overmap/event/emp/storm)
	var/intensity = storm.intensity
	var/damage = 5 * intensity
	var/emp_count = 1 + intensity

	receive_damage(damage, "ion storm")

	// Create EMPs at random locations in the ship
	for(var/i in 1 to emp_count)
		var/turf/target = get_random_ship_turf()
		if(target)
			// empulse handles the visual effect when heavy_range > 1
			empulse(target, 2 * intensity, 4 * intensity)
			playsound(target, 'sound/effects/empulse.ogg', 50, TRUE)

/**
 * Electrical Storm Effect
 * Causes power fluctuations and sparks, deals light hull damage
 */
/obj/structure/overmap/ship/proc/apply_electrical_storm_damage(obj/structure/overmap/event/electric/storm)
	var/intensity = storm.intensity
	var/damage = 3 * intensity

	receive_damage(damage, "electrical storm")

	// Create electrical effects at random locations
	var/spark_count = 2 + (intensity * 2)
	for(var/i in 1 to spark_count)
		var/turf/target = get_random_ship_turf()
		if(target)
			do_sparks(3, FALSE, target)
			// Small chance to shock nearby mobs
			if(prob(20 * intensity))
				for(var/mob/living/victim in range(1, target))
					victim.electrocute_act(10 * intensity, "electrical storm", flags = SHOCK_NOGLOVES)

/**
 * Meteor Storm Effect
 * Spawns a single meteor that crashes through the ship
 */
/obj/structure/overmap/ship/proc/apply_meteor_damage(obj/structure/overmap/event/meteor/storm)
	if(!shuttle)
		return

	var/damage = 5
	var/meteor_type = /obj/effect/meteor/medium

	if(istype(storm, /obj/structure/overmap/event/meteor/majour))
		damage = 10
		meteor_type = /obj/effect/meteor/big
	else if(istype(storm, /obj/structure/overmap/event/meteor/minor))
		damage = 2
		// Still use medium meteor for proper sound, just less hull damage
		meteor_type = /obj/effect/meteor/medium

	receive_damage(damage, "meteor impact")

	// Spawn one meteor aimed at the ship
	spawn_meteor_at_ship(meteor_type)

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
	ADD_TRAIT(M, TRAIT_FREE_HYPERSPACE_MOVEMENT, INNATE_TRAIT)

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
 */
/obj/structure/overmap/ship/proc/get_random_ship_turf()
	if(!shuttle?.shuttle_areas?.len)
		return null

	// Collect all turfs from all ship areas to ensure we find one
	var/list/all_turfs = list()
	for(var/area/ship_area as anything in shuttle.shuttle_areas)
		all_turfs += get_area_turfs(ship_area)

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

#undef SHIP_REGEN_INTERVAL
#undef SHIP_REGEN_AMOUNT
#undef SHIP_CRITICAL_THRESHOLD
#undef SHIP_MAX_INTEGRITY
