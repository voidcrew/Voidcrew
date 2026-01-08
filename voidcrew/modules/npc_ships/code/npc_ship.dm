/**
 * NPC Ship - AI-controlled ships that can engage players in combat
 *
 * These ships spawn dynamically in RED zones and use territorial AI
 * to attack player ships that come within range.
 */
/obj/structure/overmap/ship/npc
	name = "unidentified vessel"
	desc = "An AI-controlled vessel."

	/// Combat interface for firing weapons
	var/datum/npc_combat_interface/combat_interface

	// ========== PER-SHIP CONFIGURABLE VARS ==========
	// Override these in subtypes to create different ship behaviors

	/// Whether this ship is hostile and attacks on sight
	var/hostile = TRUE

	/// How close player ships need to be to trigger aggression (in tiles)
	var/territory_range = 2

	/// Ship color tint for faction identification (set in subtypes)
	var/ship_color = null

	/// Movement speed cap for this NPC ship (tiles per tick)
	var/speed_limit = 0.5

	/// Acceleration per engine burn for this NPC ship
	var/thrust_power = 0.3

	/// Time to acquire weapons lock (deciseconds)
	var/lock_time = 5 SECONDS

	/// Cooldown between laser volleys (deciseconds)
	var/laser_cooldown_time = 5 SECONDS

	/// Cooldown between missile launches (deciseconds)
	var/missile_cooldown_time = 10 SECONDS

	/// Minimum crew to spawn
	var/crew_min = 3

	/// Maximum crew to spawn
	var/crew_max = 6

	/// List of mob types to spawn as crew (picked randomly)
	var/list/crew_types = list()

	// ========== INTERNAL STATE ==========

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

	// ========== MASS CACHING (Performance optimization) ==========
	// Instead of iterating all turfs every second, we cache mass and only
	// recalculate when the ship takes hull damage

	/// Cached mass value - avoids iterating all turfs every second
	var/cached_mass = 0
	/// Whether cached_mass has been initialized
	var/mass_initialized = FALSE
	/// Whether mass needs recalculation (set TRUE when ship takes damage)
	var/mass_dirty = FALSE
	/// Cooldown to prevent mass recalc spam when taking multiple hits
	COOLDOWN_DECLARE(mass_recalc_cooldown)

/obj/structure/overmap/ship/npc/Initialize(mapload, datum/map_template/shuttle/voidcrew/template)
	. = ..()
	// Apply faction color tint
	if(ship_color)
		color = ship_color
		chat_color = ship_color
	// AI initialization happens after shuttle is fully loaded via signal or explicit call

/obj/structure/overmap/ship/npc/Destroy()
	QDEL_NULL(ai_controller)
	QDEL_NULL(combat_interface)
	// Clean up from dirty queue if we were in it
	SSovermap.dirty_npc_ships -= src
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
	// Only recalc mass on explosive damage (missiles) - lasers don't destroy enough turfs to matter
	RegisterSignal(src, COMSIG_SHIP_EXPLOSIVE_DAMAGE, PROC_REF(on_hull_damaged))

	// Calculate and cache initial mass (avoids per-second recalculation)
	mass_dirty = TRUE  // Force initial calculation
	calculate_mass()
	mass_initialized = TRUE

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
 * Sets up chase mode. Ship will chase targets and return to patrol when done.
 * Note: Chase is now automatic when targets are detected, this just sets the mode.
 */
/obj/structure/overmap/ship/npc/proc/set_chase_mode()
	set_movement_mode(NPC_MOVEMENT_CHASE)

/**
 * Sets up patrol mode. Waypoints will be auto-generated.
 */
/obj/structure/overmap/ship/npc/proc/set_patrol_mode()
	set_movement_mode(NPC_MOVEMENT_PATROL)

/**
 * Spawns crew aboard the ship using per-ship crew configuration.
 * Override crew_min, crew_max, and crew_types in subtypes for different crews.
 */
/obj/structure/overmap/ship/npc/proc/spawn_crew()
	if(!shuttle?.shuttle_areas)
		return

	// No crew types defined = no crew to spawn
	if(!length(crew_types))
		return

	var/crew_count = rand(crew_min, crew_max)
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

	// Spawn crew from configured types
	for(var/i in 1 to min(crew_count, length(valid_turfs)))
		var/turf/spawn_loc = pick_n_take(valid_turfs)
		var/mob_type = pick(crew_types)
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
 * Override burn_engines to use per-ship acceleration while still requiring working engines.
 * This bypasses the complex thrust/mass calculation but ensures the ship has functional
 * engines before allowing movement.
 */
/obj/structure/overmap/ship/npc/burn_engines(n_dir = null, percentage = 100)
	if(state != OVERMAP_SHIP_FLYING)
		return

	// Must have at least one working engine with fuel
	if(!can_thrust())
		return

	// Decelerate
	if(!n_dir)
		decelerate(thrust_power * (percentage / 100))
		return

	// Accelerate using per-ship thrust power
	accelerate(n_dir, thrust_power * (percentage / 100))

	// Cap at per-ship speed limit
	var/current_magnitude = MAGNITUDE(speed[1], speed[2])
	if(current_magnitude > speed_limit)
		var/scale = speed_limit / current_magnitude
		speed[1] *= scale
		speed[2] *= scale

// ========== MASS CALCULATION OVERRIDE ==========

/**
 * Override calculate_mass to use cached value for performance.
 * Instead of iterating all turfs every second, we only recalculate when:
 * 1. Mass hasn't been initialized yet
 * 2. Ship has taken hull damage (mass_dirty = TRUE)
 * 3. Cooldown has expired (prevents spam recalc when taking multiple hits)
 *
 * This saves thousands of turf iterations per second across all NPC ships.
 */
/obj/structure/overmap/ship/npc/calculate_mass()
	// If not dirty and initialized, return cached value
	if(!mass_dirty && mass_initialized)
		return cached_mass

	// Even if dirty, respect cooldown to prevent spam (unless first init)
	if(mass_initialized && !COOLDOWN_FINISHED(src, mass_recalc_cooldown))
		return cached_mass

	// Recalculate using parent proc
	cached_mass = ..()
	mass_dirty = FALSE

	// Start cooldown - won't recalc again for 6 seconds even if hit more
	COOLDOWN_START(src, mass_recalc_cooldown, 6 SECONDS)

	// Remove from dirty queue if we were in it
	SSovermap.dirty_npc_ships -= src

	return cached_mass

/**
 * Signal handler for when the ship takes hull damage.
 * Marks mass as dirty so it will be recalculated.
 */
/obj/structure/overmap/ship/npc/proc/on_hull_damaged(datum/source, turf/impact_location)
	SIGNAL_HANDLER

	// Don't queue if already dirty
	if(mass_dirty)
		return

	mass_dirty = TRUE
	SSovermap.dirty_npc_ships |= src

// ========== SHIP TYPE SUBTYPES ==========

/**
 * Pirate Ship - Hostile vessels that attack on sight
 *
 * Pirates are aggressive, attack any player ships in range,
 * and spawn with armed pirate crew.
 */
/obj/structure/overmap/ship/npc/pirate
	name = "pirate vessel"
	desc = "A hostile vessel operated by pirates."

	// Pirates are hostile and attack on sight
	hostile = TRUE
	territory_range = 2

	// Red color for pirate faction
	ship_color = NPC_COLOR_PIRATE

	// Combat stats
	lock_time = 5 SECONDS
	laser_cooldown_time = 5 SECONDS
	missile_cooldown_time = 10 SECONDS

	// Movement stats
	speed_limit = 0.5
	thrust_power = 0.3

	// Crew configuration
	crew_min = 3
	crew_max = 6
	crew_types = list(
		/mob/living/basic/trooper/pirate/melee/space,
		/mob/living/basic/trooper/pirate/ranged/space,
	)

	// Faction
	faction = list(FACTION_PIRATE)

