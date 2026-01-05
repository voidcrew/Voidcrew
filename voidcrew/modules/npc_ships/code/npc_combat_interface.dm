/**
 * NPC Combat Interface - Wraps ship weapons for AI control
 *
 * This datum provides a simplified interface for NPC ships to fire weapons
 * without needing to track inventories or use the combat console UI.
 * Weapons are found automatically from the ship's shuttle areas.
 */
/datum/npc_combat_interface
	/// Reference to the NPC ship we're attached to
	var/obj/structure/overmap/ship/npc/owner_ship

	/// List of laser turrets on this ship
	var/list/obj/machinery/ship_combat/laser_turret/linked_laser_turrets = list()

	/// List of missile launchers on this ship
	var/list/obj/machinery/ship_combat/missile_launcher/linked_missile_launchers = list()

	/// The interdictor on this ship (if any)
	var/obj/machinery/ship_combat/interdictor/linked_interdictor

/datum/npc_combat_interface/Destroy()
	owner_ship = null
	linked_laser_turrets.Cut()
	linked_missile_launchers.Cut()
	linked_interdictor = null
	return ..()

/**
 * Initializes the combat interface by finding all weapons on the given ship.
 */
/datum/npc_combat_interface/proc/initialize_from_ship(obj/structure/overmap/ship/npc/ship)
	if(!ship)
		return FALSE

	owner_ship = ship

	if(!ship.shuttle?.shuttle_areas)
		return FALSE

	// Search all ship areas for combat equipment
	for(var/area/ship_area as anything in ship.shuttle.shuttle_areas)
		for(var/obj/machinery/ship_combat/equipment in ship_area)
			if(istype(equipment, /obj/machinery/ship_combat/laser_turret))
				linked_laser_turrets += equipment
			else if(istype(equipment, /obj/machinery/ship_combat/missile_launcher))
				linked_missile_launchers += equipment
			else if(istype(equipment, /obj/machinery/ship_combat/interdictor))
				linked_interdictor = equipment

	return TRUE

// ========== WEAPON COUNTING ==========

/**
 * Returns the number of functional laser turrets.
 */
/datum/npc_combat_interface/proc/get_working_laser_count()
	var/count = 0
	for(var/obj/machinery/ship_combat/laser_turret/turret as anything in linked_laser_turrets)
		if(QDELETED(turret))
			continue
		if(turret.can_fire())
			count++
	return count

/**
 * Returns the number of functional missile launchers.
 * Note: For NPCs, we don't check loaded_missile - we spawn missiles directly.
 */
/datum/npc_combat_interface/proc/get_working_launcher_count()
	var/count = 0
	for(var/obj/machinery/ship_combat/missile_launcher/launcher as anything in linked_missile_launchers)
		if(QDELETED(launcher))
			continue
		// Check basic functionality but NOT loaded_missile - NPCs spawn missiles directly
		if(launcher.machine_stat & (BROKEN|NOPOWER))
			continue
		if(!launcher.anchored)
			continue
		if(!launcher.is_on_exterior())
			continue
		count++
	return count

/**
 * Returns whether we have a working interdictor.
 */
/datum/npc_combat_interface/proc/has_working_interdictor()
	if(QDELETED(linked_interdictor))
		return FALSE
	return linked_interdictor.can_interdict()

// ========== FIRING WEAPONS ==========

/**
 * Fires lasers at the target ship.
 * Returns TRUE if at least one laser was fired.
 *
 * Arguments:
 * * target_ship - The ship to fire at
 * * fire_all - If TRUE, fires all available lasers. If FALSE, fires one laser.
 */
/datum/npc_combat_interface/proc/fire_lasers(obj/structure/overmap/ship/target_ship, fire_all = FALSE)
	if(!target_ship || !owner_ship)
		return FALSE

	// Get a random target turf on the enemy ship
	var/turf/target_turf = get_random_target_turf(target_ship)
	if(!target_turf)
		return FALSE

	// Clean up destroyed turrets
	for(var/obj/machinery/ship_combat/laser_turret/turret as anything in linked_laser_turrets)
		if(QDELETED(turret))
			linked_laser_turrets -= turret

	var/fired_any = FALSE

	if(fire_all)
		// Fire all available lasers
		for(var/obj/machinery/ship_combat/laser_turret/turret as anything in linked_laser_turrets)
			if(turret.can_fire())
				// Get new random target turf for each laser for spread effect
				var/turf/laser_target = get_random_target_turf(target_ship)
				if(turret.fire(laser_target, target_ship, owner_ship, null))
					fired_any = TRUE
	else
		// Fire a single random laser
		var/list/available_turrets = list()
		for(var/obj/machinery/ship_combat/laser_turret/turret as anything in linked_laser_turrets)
			if(turret.can_fire())
				available_turrets += turret

		if(length(available_turrets))
			var/obj/machinery/ship_combat/laser_turret/chosen = pick(available_turrets)
			if(chosen.fire(target_turf, target_ship, owner_ship, null))
				fired_any = TRUE

	return fired_any

/**
 * Fires a missile at the target ship.
 * NPCs don't track missile inventory - they spawn missiles directly using cooldowns.
 * Returns TRUE if a missile was fired.
 *
 * Arguments:
 * * target_ship - The ship to fire at
 * * missile_type - Optional: "light", "standard", or "heavy". Random if not specified.
 */
/datum/npc_combat_interface/proc/fire_missile(obj/structure/overmap/ship/target_ship, missile_type)
	if(!target_ship || !owner_ship)
		return FALSE

	// Check if we have at least one working launcher
	if(get_working_launcher_count() < 1)
		return FALSE

	// Pick missile type if not specified
	if(!missile_type)
		missile_type = pick("light", "standard", "heavy")

	// Configure missile parameters based on type
	var/effect_type = /obj/effect/ship_missile
	var/damage
	var/devastation
	var/heavy
	var/light
	var/flame
	var/icon_state

	switch(missile_type)
		if("light")
			damage = MISSILE_DAMAGE_LIGHT
			devastation = 1
			heavy = 2
			light = 3
			flame = 1
			icon_state = "smissile"
		if("heavy")
			damage = MISSILE_DAMAGE_HEAVY
			devastation = 3
			heavy = 5
			light = 7
			flame = 4
			icon_state = "missile"
		else // standard
			damage = MISSILE_DAMAGE_STANDARD
			devastation = 2
			heavy = 3
			light = 5
			flame = 3
			icon_state = "missile"

	// Get a random target turf on the enemy ship
	var/turf/target_turf = get_random_target_turf(target_ship)
	if(!target_turf)
		return FALSE

	// Calculate spawn turf (outside target ship)
	var/turf/spawn_turf = get_missile_spawn_turf(target_turf, target_ship)
	if(!spawn_turf)
		spawn_turf = target_turf

	// Play launch sound from our ship
	if(owner_ship?.shuttle?.shuttle_areas)
		// Find a turf on our ship to play sound from
		for(var/area/ship_area as anything in owner_ship.shuttle.shuttle_areas)
			var/list/area_turfs = get_area_turfs(ship_area)
			if(length(area_turfs))
				var/turf/sound_turf = pick(area_turfs)
				playsound(sound_turf, 'voidcrew/sound/machines/rocket/rocket_launch.ogg', 100, TRUE, extrarange = 20, pressure_affected = FALSE)
				break

	// Signal weapon fired (breaks cloak)
	SEND_SIGNAL(owner_ship, COMSIG_SHIP_WEAPON_FIRED)

	// Spawn the missile after a short delay (simulates launch visual)
	addtimer(CALLBACK(
		GLOBAL_PROC,
		GLOBAL_PROC_REF(create_ship_missile),
		effect_type,
		spawn_turf,
		target_turf,
		target_ship,
		owner_ship,
		damage,
		devastation,
		heavy,
		light,
		flame,
		icon_state,
		null  // No chemical grenade for NPC missiles
	), 1.5 SECONDS)

	return TRUE

/**
 * Starts interdiction on the target ship.
 * Returns TRUE if interdiction started successfully.
 */
/datum/npc_combat_interface/proc/start_interdiction(obj/structure/overmap/ship/target_ship)
	if(!target_ship)
		return FALSE

	if(QDELETED(linked_interdictor))
		return FALSE

	return linked_interdictor.start_interdiction(target_ship, null)

// ========== UTILITY ==========

/**
 * Gets a random valid turf on the target ship for weapon targeting.
 */
/datum/npc_combat_interface/proc/get_random_target_turf(obj/structure/overmap/ship/target_ship)
	if(!target_ship?.shuttle?.shuttle_areas)
		return null

	var/list/valid_turfs = list()
	for(var/area/ship_area as anything in target_ship.shuttle.shuttle_areas)
		for(var/turf/T in ship_area)
			if(!isspaceturf(T))
				valid_turfs += T

	if(!length(valid_turfs))
		return null

	return pick(valid_turfs)

/**
 * Calculates spawn position for missiles - outside the target ship.
 */
/datum/npc_combat_interface/proc/get_missile_spawn_turf(turf/target, obj/structure/overmap/ship/target_ship)
	if(!target)
		return null

	// Get ship bounds from docking port
	var/min_x = target.x
	var/max_x = target.x
	var/min_y = target.y
	var/max_y = target.y

	if(target_ship?.shuttle)
		var/list/bounds = target_ship.shuttle.return_coords()
		if(bounds?.len >= 4)
			min_x = min(bounds[1], bounds[3])
			max_x = max(bounds[1], bounds[3])
			min_y = min(bounds[2], bounds[4])
			max_y = max(bounds[2], bounds[4])

	// Spawn distance outside ship
	var/spawn_dist = 10

	// Pick a random cardinal direction to come from
	var/approach_dir = pick(NORTH, SOUTH, EAST, WEST)

	var/spawn_x = target.x
	var/spawn_y = target.y

	switch(approach_dir)
		if(NORTH)
			spawn_y = max_y + spawn_dist
			spawn_x = target.x
		if(SOUTH)
			spawn_y = min_y - spawn_dist
			spawn_x = target.x
		if(EAST)
			spawn_x = max_x + spawn_dist
			spawn_y = target.y
		if(WEST)
			spawn_x = min_x - spawn_dist
			spawn_y = target.y

	return locate(spawn_x, spawn_y, target.z)
