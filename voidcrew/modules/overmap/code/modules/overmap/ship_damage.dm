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

	// Check for ship destruction
	if(integrity <= 0)
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
 * Currently just sets integrity to 1 and announces - full destruction can be implemented later
 */
/obj/structure/overmap/ship/proc/on_ship_destroyed()
	integrity = 1 // Prevent actual destruction for now, just leave at 1%
	ship_announce("EMERGENCY: Hull breach imminent! All systems failing!", "Hull Breach", TRUE, 'sound/machines/warning-buzzer.ogg')

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
	if(!COOLDOWN_FINISHED(src, hazard_damage_cooldown))
		return

	COOLDOWN_START(src, hazard_damage_cooldown, 3 SECONDS)

	if(istype(hazard, /obj/structure/overmap/event/emp))
		apply_ion_storm_damage(hazard)
	else if(istype(hazard, /obj/structure/overmap/event/electric))
		apply_electrical_storm_damage(hazard)
	else if(istype(hazard, /obj/structure/overmap/event/meteor))
		apply_meteor_damage(hazard)
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
			// Create EMP effect at that location
			empulse(target, 2 * intensity, 4 * intensity)
			new /obj/effect/temp_visual/emp(target)

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
 * Creates meteor impacts on the ship, causes screen shake and knockdowns
 */
/obj/structure/overmap/ship/proc/apply_meteor_damage(obj/structure/overmap/event/meteor/storm)
	var/damage = 5
	var/shake_duration = 10
	var/shake_strength = 2
	var/knockdown_chance = 20
	var/knockdown_duration = 2 SECONDS
	var/impact_count = 1
	var/impact_severity = "minor" // minor, moderate, major

	if(istype(storm, /obj/structure/overmap/event/meteor/majour))
		damage = 10
		shake_duration = 20
		shake_strength = 4
		knockdown_chance = 50
		knockdown_duration = 4 SECONDS
		impact_count = rand(2, 4)
		impact_severity = "major"
	else if(istype(storm, /obj/structure/overmap/event/meteor/minor))
		damage = 2
		shake_duration = 5
		shake_strength = 1
		knockdown_chance = 10
		knockdown_duration = 1 SECONDS
		impact_count = 1
		impact_severity = "minor"
	else
		impact_severity = "moderate"

	receive_damage(damage, "meteor impact")

	// Shake the screen and knock down crew members
	for(var/mob/living/crew_member in get_all_ship_mobs())
		shake_camera(crew_member, shake_duration, shake_strength)
		if(prob(knockdown_chance))
			crew_member.Knockdown(knockdown_duration)
			to_chat(crew_member, span_danger("The impact throws you off your feet!"))

	// Create meteor impacts directly on the ship
	for(var/i in 1 to impact_count)
		create_meteor_impact(impact_severity)

/**
 * Creates a meteor impact effect directly on a random ship turf
 * This avoids issues with spawning moving meteors in transit/hyperspace
 */
/obj/structure/overmap/ship/proc/create_meteor_impact(severity = "moderate")
	var/turf/target = get_random_ship_turf()
	if(!target)
		return

	// Sound effect
	playsound(target, 'sound/effects/meteorimpact.ogg', 60, TRUE)

	switch(severity)
		if("minor")
			// Minor impact - just visual and sound, maybe break a light
			new /obj/effect/temp_visual/explosion(target)
			for(var/obj/machinery/light/L in range(2, target))
				if(prob(30))
					L.break_light_tube()

		if("moderate")
			// Moderate impact - small explosion, can break floor tiles
			new /obj/effect/temp_visual/explosion(target)
			if(prob(40) && istype(target, /turf/open/floor))
				var/turf/open/floor/F = target
				F.break_tile()
			// Damage nearby objects
			for(var/obj/O in range(1, target))
				if(prob(25))
					O.take_damage(15, BRUTE)

		if("major")
			// Major impact - real explosion
			explosion(target, light_impact_range = 1, flash_range = 2, adminlog = FALSE)
			// Higher chance to breach hull
			if(prob(60) && istype(target, /turf/open/floor))
				var/turf/open/floor/F = target
				F.break_tile()
			// Can start fires
			if(prob(25))
				new /obj/effect/hotspot(target)

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

	var/area/chosen_area = pick(shuttle.shuttle_areas)
	var/list/area_turfs = get_area_turfs(chosen_area)

	if(!length(area_turfs))
		return null

	return pick(area_turfs)

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
