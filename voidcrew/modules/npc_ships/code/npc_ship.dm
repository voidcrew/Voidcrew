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
		log_shuttle("NPC SHIP AI: [src] - AI already initialized")
		return // Already initialized

	log_shuttle("NPC SHIP AI: [src] - Initializing AI controller...")

	// Create combat interface to find and manage weapons
	combat_interface = new()
	combat_interface.initialize_from_ship(src)

	// Set static power levels - shields at 100%
	set_shield_power_allocation(1.0)

	// Create and attach AI controller
	ai_controller = new /datum/ai_controller/npc_ship(src)

	log_shuttle("NPC SHIP AI: [src] - AI controller created: [ai_controller]")

	// Register for signals we care about
	RegisterSignal(src, COMSIG_SHIP_INTEGRITY_CHANGED, PROC_REF(on_integrity_changed))
	RegisterSignal(src, COMSIG_SHIP_INTERDICTED, PROC_REF(on_interdicted))

	// Spawn pirate crew
	spawn_crew()

/**
 * Spawns hostile pirate crew aboard the ship.
 */
/obj/structure/overmap/ship/npc/proc/spawn_crew()
	if(!shuttle?.shuttle_areas)
		return

	var/crew_count = rand(NPC_SHIP_CREW_MIN, NPC_SHIP_CREW_MAX)
	var/list/valid_turfs = list()

	// Find valid spawn turfs (non-space, walkable)
	for(var/area/shuttle_area as anything in shuttle.shuttle_areas)
		for(var/turf/T in shuttle_area)
			if(isspaceturf(T))
				continue
			if(T.density)
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
