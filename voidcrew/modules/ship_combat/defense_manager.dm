// Ship Defense Manager
// Unified coordination of shields, interdiction resistance, and cloaking for a ship.
// Created per-ship to simplify state management and provide centralized access to defensive systems.

/**
 * # Ship Defense Manager
 *
 * A datum that coordinates all defensive systems on a ship, including:
 * - Shield generators (multiple allowed, health pools)
 * - Interdictor (interdiction resistance, only one per ship)
 * - Cloaking device (only one per ship)
 *
 * This provides a unified API for checking defense status and coordinating
 * between different defensive systems on a ship.
 */
/datum/ship_defense_manager
	/// Weakref to the ship this manager belongs to
	var/datum/weakref/ship_ref

	/// List of weakrefs to all shield generators on this ship
	var/list/datum/weakref/shield_generator_refs = list()

	/// Weakref to the ship's interdictor (if any)
	var/datum/weakref/interdictor_ref

	/// Weakref to the ship's cloaking device (if any)
	var/datum/weakref/cloak_device_ref

/datum/ship_defense_manager/New(obj/structure/overmap/ship/owner_ship)
	. = ..()
	if(!owner_ship)
		stack_trace("Ship defense manager created without a ship!")
		qdel(src)
		return
	ship_ref = WEAKREF(owner_ship)

/datum/ship_defense_manager/Destroy(force)
	// Clear all weakrefs
	ship_ref = null
	shield_generator_refs.Cut()
	interdictor_ref = null
	cloak_device_ref = null
	return ..()

// ========== SHIELD GENERATOR MANAGEMENT ==========

/**
 * Registers a shield generator with this defense manager.
 * Multiple shield generators can be registered per ship.
 *
 * Arguments:
 * * generator - The shield generator to register
 *
 * Returns TRUE if registration succeeded, FALSE otherwise.
 */
/datum/ship_defense_manager/proc/register_shield_generator(obj/machinery/ship_combat/shield_generator/generator)
	if(!generator)
		return FALSE

	// Check if already registered
	for(var/datum/weakref/existing_ref in shield_generator_refs)
		if(existing_ref.resolve() == generator)
			return FALSE // Already registered

	shield_generator_refs += WEAKREF(generator)
	return TRUE

/**
 * Unregisters a shield generator from this defense manager.
 *
 * Arguments:
 * * generator - The shield generator to unregister
 *
 * Returns TRUE if unregistration succeeded, FALSE if generator wasn't registered.
 */
/datum/ship_defense_manager/proc/unregister_shield_generator(obj/machinery/ship_combat/shield_generator/generator)
	if(!generator)
		return FALSE

	for(var/datum/weakref/ref in shield_generator_refs)
		if(ref.resolve() == generator)
			shield_generator_refs -= ref
			return TRUE

	return FALSE

/**
 * Returns the sum of current shield health from all generators.
 * This queries the ship's shared shield pool.
 */
/datum/ship_defense_manager/proc/get_total_shield_health()
	var/obj/structure/overmap/ship/ship = ship_ref?.resolve()
	if(!ship)
		return 0
	return ship.shield_health + ship.shield_overhealth

/**
 * Returns the sum of max shield health from all generators.
 * This queries the ship's shared shield pool maximum.
 */
/datum/ship_defense_manager/proc/get_max_shield_health()
	var/obj/structure/overmap/ship/ship = ship_ref?.resolve()
	if(!ship)
		return 0
	return ship.shield_max_health

/**
 * Returns TRUE if any shield generator has active shields.
 */
/datum/ship_defense_manager/proc/is_shields_active()
	var/obj/structure/overmap/ship/ship = ship_ref?.resolve()
	if(!ship)
		return FALSE
	return ship.shields_active

/**
 * Returns a list of all currently registered and valid shield generators.
 * Automatically cleans up stale weakrefs.
 */
/datum/ship_defense_manager/proc/get_shield_generators()
	var/list/generators = list()
	var/list/stale_refs = list()

	for(var/datum/weakref/ref in shield_generator_refs)
		var/obj/machinery/ship_combat/shield_generator/gen = ref.resolve()
		if(gen)
			generators += gen
		else
			stale_refs += ref

	// Clean up stale refs
	shield_generator_refs -= stale_refs

	return generators

/**
 * Returns the count of active shield generators.
 */
/datum/ship_defense_manager/proc/get_active_generator_count()
	var/count = 0
	for(var/obj/machinery/ship_combat/shield_generator/gen in get_shield_generators())
		if(gen.active)
			count++
	return count

// ========== CLOAK DEVICE MANAGEMENT ==========

/**
 * Registers a cloaking device with this defense manager.
 * Only one cloaking device can be registered per ship.
 *
 * Arguments:
 * * device - The cloaking device to register
 *
 * Returns TRUE if registration succeeded, FALSE if another device is already registered.
 */
/datum/ship_defense_manager/proc/register_cloak_device(obj/machinery/ship_combat/cloak_device/device)
	if(!device)
		return FALSE

	// Check if we already have a cloak device
	var/existing = cloak_device_ref?.resolve()
	if(existing)
		return FALSE // Only one cloak device allowed

	cloak_device_ref = WEAKREF(device)
	return TRUE

/**
 * Unregisters a cloaking device from this defense manager.
 *
 * Arguments:
 * * device - The cloaking device to unregister
 *
 * Returns TRUE if unregistration succeeded, FALSE if device wasn't registered.
 */
/datum/ship_defense_manager/proc/unregister_cloak_device(obj/machinery/ship_combat/cloak_device/device)
	if(!device)
		return FALSE

	if(cloak_device_ref?.resolve() == device)
		cloak_device_ref = null
		return TRUE

	return FALSE

/**
 * Returns TRUE if the ship's cloak is currently active.
 */
/datum/ship_defense_manager/proc/is_cloaked()
	var/obj/machinery/ship_combat/cloak_device/device = cloak_device_ref?.resolve()
	if(!device)
		return FALSE
	return device.cloak_active

/**
 * Returns the registered cloak device, or null if none.
 */
/datum/ship_defense_manager/proc/get_cloak_device()
	return cloak_device_ref?.resolve()

// ========== INTERDICTOR MANAGEMENT ==========

/**
 * Registers an interdictor with this defense manager.
 * Only one interdictor can be registered per ship.
 *
 * Arguments:
 * * interdictor - The interdictor to register
 *
 * Returns TRUE if registration succeeded, FALSE if another interdictor is already registered.
 */
/datum/ship_defense_manager/proc/register_interdictor(obj/machinery/ship_combat/interdictor/interdictor)
	if(!interdictor)
		return FALSE

	// Check if we already have an interdictor
	var/existing = interdictor_ref?.resolve()
	if(existing)
		return FALSE // Only one interdictor allowed

	interdictor_ref = WEAKREF(interdictor)
	return TRUE

/**
 * Unregisters an interdictor from this defense manager.
 *
 * Arguments:
 * * interdictor - The interdictor to unregister
 *
 * Returns TRUE if unregistration succeeded, FALSE if interdictor wasn't registered.
 */
/datum/ship_defense_manager/proc/unregister_interdictor(obj/machinery/ship_combat/interdictor/interdictor)
	if(!interdictor)
		return FALSE

	if(interdictor_ref?.resolve() == interdictor)
		interdictor_ref = null
		return TRUE

	return FALSE

/**
 * Returns TRUE if the ship is currently being interdicted by another ship.
 */
/datum/ship_defense_manager/proc/is_interdicted()
	var/obj/structure/overmap/ship/ship = ship_ref?.resolve()
	if(!ship)
		return FALSE
	return ship.is_interdicted

/**
 * Returns the registered interdictor, or null if none.
 */
/datum/ship_defense_manager/proc/get_interdictor()
	return interdictor_ref?.resolve()

/**
 * Returns TRUE if the ship's interdictor is actively interdicting another ship.
 */
/datum/ship_defense_manager/proc/is_interdicting()
	var/obj/machinery/ship_combat/interdictor/device = interdictor_ref?.resolve()
	if(!device)
		return FALSE
	return device.interdiction_active

// ========== UTILITY PROCS ==========

/**
 * Returns the ship this defense manager belongs to.
 */
/datum/ship_defense_manager/proc/get_ship()
	return ship_ref?.resolve()

/**
 * Returns a comprehensive status list of all defensive systems.
 * Useful for UI displays and debugging.
 */
/datum/ship_defense_manager/proc/get_defense_status()
	var/obj/structure/overmap/ship/ship = ship_ref?.resolve()

	var/list/status = list(
		"ship_valid" = !isnull(ship),
		// Shield status
		"shields_active" = is_shields_active(),
		"shield_health" = get_total_shield_health(),
		"shield_max_health" = get_max_shield_health(),
		"shield_generator_count" = length(get_shield_generators()),
		"shield_generators_active" = get_active_generator_count(),
		// Cloak status
		"has_cloak" = !isnull(cloak_device_ref?.resolve()),
		"is_cloaked" = is_cloaked(),
		// Interdiction status
		"has_interdictor" = !isnull(interdictor_ref?.resolve()),
		"is_interdicted" = is_interdicted(),
		"is_interdicting" = is_interdicting(),
	)

	return status
