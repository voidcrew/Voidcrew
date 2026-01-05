/**
 * NPC Ship - AI-controlled ships that can engage players in combat
 *
 * These ships spawn dynamically in YELLOW/RED zones and use territorial AI
 * to attack player ships that come within range.
 */
/obj/structure/overmap/ship/npc
	name = "pirate vessel"
	desc = "A hostile vessel operated by pirates."

	/// Combat interface for firing weapons
	var/datum/npc_combat_interface/combat_interface

	/// How close player ships need to be to trigger aggression (in tiles)
	var/territory_range = NPC_SHIP_TERRITORY_RANGE

	/// Whether this ship can currently be boarded (disabled or interdicted)
	var/can_board = FALSE

	/// Cooldown for laser firing
	COOLDOWN_DECLARE(laser_cooldown)

	/// Cooldown for missile firing
	COOLDOWN_DECLARE(missile_cooldown)

	/// Set faction for pirate hostility
	faction = list(FACTION_PIRATE)

	/// Default movement mode for this ship type
	var/default_movement_mode = NPC_MOVEMENT_PATROL

/obj/structure/overmap/ship/npc/Initialize(mapload, datum/map_template/shuttle/voidcrew/template)
	. = ..()
	// AI initialization happens after shuttle is fully loaded via signal or explicit call

/obj/structure/overmap/ship/npc/Destroy()
	QDEL_NULL(ai_controller)
	QDEL_NULL(combat_interface)
	return ..()

/**
 * Initializes the AI controller and combat systems for this NPC ship.
 * Should be called after the shuttle is fully loaded and all machinery is in place.
 */
/obj/structure/overmap/ship/npc/proc/initialize_ai()
	if(ai_controller)
		return // Already initialized

	// Create combat interface to find and manage weapons
	combat_interface = new()
	combat_interface.initialize_from_ship(src)

	// Set static power levels - shields at 100%
	set_shield_power_allocation(1.0)

	// Create and attach AI controller
	ai_controller = new /datum/ai_controller/npc_ship(src)

	// Set default movement mode
	set_movement_mode(default_movement_mode)

	// Register for signals we care about
	RegisterSignal(src, COMSIG_SHIP_INTEGRITY_CHANGED, PROC_REF(on_integrity_changed))
	RegisterSignal(src, COMSIG_SHIP_INTERDICTED, PROC_REF(on_interdicted))

	// Spawn pirate crew
	spawn_crew()

/**
 * Sets the movement mode for this NPC ship.
 * Valid modes: NPC_MOVEMENT_IDLE, NPC_MOVEMENT_ORBIT, NPC_MOVEMENT_PATROL, NPC_MOVEMENT_CHASE
 */
/obj/structure/overmap/ship/npc/proc/set_movement_mode(mode)
	if(!ai_controller)
		return
	var/datum/ai_controller/npc_ship/controller = ai_controller
	controller.set_blackboard_key(BB_NPC_MOVEMENT_MODE, mode)

/**
 * Sets up orbit mode around a celestial object.
 * @param target The object to orbit (star, planet, etc.)
 * @param distance The desired orbit distance in tiles
 */
/obj/structure/overmap/ship/npc/proc/set_orbit_target(atom/target, distance = NPC_SHIP_ORBIT_DISTANCE)
	if(!ai_controller)
		return
	var/datum/ai_controller/npc_ship/controller = ai_controller
	controller.set_blackboard_key(BB_NPC_ORBIT_TARGET, target)
	controller.set_blackboard_key(BB_NPC_ORBIT_DISTANCE, distance)
	set_movement_mode(NPC_MOVEMENT_ORBIT)

/**
 * Sets up chase mode with a boundary limit.
 * @param chase_range Maximum tiles to chase from home position
 */
/obj/structure/overmap/ship/npc/proc/set_chase_mode(chase_range = NPC_SHIP_CHASE_RANGE)
	if(!ai_controller)
		return
	var/datum/ai_controller/npc_ship/controller = ai_controller
	controller.set_blackboard_key(BB_NPC_CHASE_BOUNDARY, chase_range)
	controller.set_blackboard_key(BB_NPC_HOME_TURF, get_turf(src))
	set_movement_mode(NPC_MOVEMENT_CHASE)

/**
 * Sets up patrol mode. Waypoints will be auto-generated.
 */
/obj/structure/overmap/ship/npc/proc/set_patrol_mode()
	set_movement_mode(NPC_MOVEMENT_PATROL)

/**
 * Spawns hostile pirate crew aboard the ship.
 */
/obj/structure/overmap/ship/npc/proc/spawn_crew()
	if(!shuttle?.shuttle_areas)
		return

	var/crew_count = rand(NPC_SHIP_CREW_MIN, NPC_SHIP_CREW_MAX)
	var/list/valid_turfs = list()

	// Find valid spawn turfs (floor tiles that aren't blocked)
	for(var/area/shuttle_area as anything in shuttle.shuttle_areas)
		for(var/turf/T in shuttle_area)
			// Skip space
			if(isspaceturf(T))
				continue
			// Skip dense turfs (walls, etc.)
			if(T.density)
				continue
			// Must be an open floor type
			if(!isfloorturf(T))
				continue
			// Check for dense objects blocking the turf
			var/blocked = FALSE
			for(var/obj/O in T)
				if(O.density)
					blocked = TRUE
					break
			if(blocked)
				continue
			valid_turfs += T

	if(!length(valid_turfs))
		return

	// Spawn pirates
	for(var/i in 1 to min(crew_count, length(valid_turfs)))
		var/turf/spawn_loc = pick_n_take(valid_turfs)
		var/mob_type = pick(
			/mob/living/basic/trooper/pirate/melee/space,
			/mob/living/basic/trooper/pirate/ranged/space,
		)
		new mob_type(spawn_loc)

/**
 * Signal handler for ship integrity changes.
 * Updates boarding state when ship is damaged enough.
 */
/obj/structure/overmap/ship/npc/proc/on_integrity_changed(datum/source, new_integrity, max_integrity, display_percent)
	SIGNAL_HANDLER
	update_boarding_state()

/**
 * Signal handler for when ship is interdicted.
 * Marks ship as boardable when interdicted.
 */
/obj/structure/overmap/ship/npc/proc/on_interdicted(datum/source, obj/machinery/ship_combat/interdictor/interdictor, power_level)
	SIGNAL_HANDLER
	// When interdicted, the ship becomes boardable via force dock
	update_boarding_state()

/**
 * Updates whether this ship can be boarded based on current state.
 * Ship is boardable when:
 * 1. Integrity <= 50% (disabled), OR
 * 2. Ship is currently interdicted
 */
/obj/structure/overmap/ship/npc/proc/update_boarding_state()
	// Check integrity - ship is disabled at 50% or below
	if(max_integrity > 0)
		var/integrity_percent = (integrity / max_integrity) * 100
		if(integrity_percent <= 50)
			can_board = TRUE
			return

	// Check interdiction
	if(is_interdicted)
		can_board = TRUE
		return

	can_board = FALSE

/**
 * Override accelerate to enforce NPC speed cap.
 * NPCs move slower than player ships for gameplay balance.
 */
/obj/structure/overmap/ship/npc/accelerate(direction, acceleration)
	. = ..()
	// Cap speed at NPC max
	var/current_magnitude = MAGNITUDE(speed[1], speed[2])
	if(current_magnitude > NPC_SHIP_MAX_SPEED)
		var/scale = NPC_SHIP_MAX_SPEED / current_magnitude
		speed[1] *= scale
		speed[2] *= scale
