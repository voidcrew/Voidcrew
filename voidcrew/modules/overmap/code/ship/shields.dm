///
/// Ship shield pool.
///
/// The shared shield pool every linked shield_generator contributes to: stat
/// recalculation, regeneration, damage absorption, the broken/reactivate cooldown
/// cycle, and the aggregated UI readout. The generator machines themselves live in
/// voidcrew/modules/ship_combat; this is the ship-side pool they share.

/obj/structure/overmap/ship
	/// Linked shield generators for ship defense (multiple generators stack)
	var/list/obj/machinery/ship_combat/shield_generator/linked_shield_generators = list()

	/// Linked cloaking device (only one per ship)
	var/obj/machinery/ship_combat/cloak_device/linked_cloak_device

	// ===== SHARED SHIELD POOL =====
	/// Current shared shield health (all generators contribute to this pool)
	var/shield_health = 0
	/// Maximum shared shield health (sum of all generator max_health)
	var/shield_max_health = 0
	/// Current overhealth (extra shield beyond max from >100% power)
	var/shield_overhealth = 0
	/// Combined regeneration rate (sum of all generator regen_rates)
	var/shield_regen_rate = 0
	/// Are shields currently active? (any generator online)
	var/shields_active = FALSE
	/// Are shields broken? (health reached 0, on cooldown)
	var/shields_broken = FALSE
	/// Cooldown for shield reactivation after breaking
	COOLDOWN_DECLARE(shield_reactivation_cooldown)
	/// Current power allocation for shields (0.0 to 2.0) - synchronized across all generators
	var/shield_power_allocation = 0
	/// Stored shield health for reactivation (preserved on graceful shutdown, reset to 0 on break)
	var/stored_shield_health = 0

// ===== SHARED SHIELD POOL PROCS =====

/// Recalculates shield stats from all linked generators
/// Call this when generators are added/removed or parts upgraded
/obj/structure/overmap/ship/proc/recalculate_shield_stats()
	var/new_max_health = 0
	var/new_regen_rate = 0

	for(var/obj/machinery/ship_combat/shield_generator/gen in linked_shield_generators)
		if(gen.machine_stat & (BROKEN|NOPOWER))
			continue
		// Each generator contributes its stats
		new_max_health += gen.max_shield_health
		new_regen_rate += gen.regen_rate

	shield_max_health = new_max_health
	shield_regen_rate = new_regen_rate

	// If max health decreased and current health exceeds it, cap it
	if(shield_health > shield_max_health)
		shield_health = shield_max_health
	// Same for banked overhealth - its ceiling scales off max health
	shield_overhealth = min(shield_overhealth, shield_max_health * SHIP_SHIELD_MAX_OVERHEALTH_MULT)

	// Note: shields_active is managed by activate_generator()/deactivate_generator()
	// This proc only updates stats, not activation state

/// Regenerates the shared shield pool - called by shield generators during process()
/obj/structure/overmap/ship/proc/regenerate_shields(seconds_per_tick)
	if(!shields_active || shields_broken)
		return

	// Calculate effective regen rate based on power allocation
	var/effective_regen = shield_regen_rate * shield_power_allocation * seconds_per_tick

	if(shield_health < shield_max_health)
		shield_health = min(shield_health + effective_regen, shield_max_health)
	else if(shield_power_allocation > 1)
		// Generate overhealth when at max and power > 100% - capped like the main pool,
		// or a ship idling at 200% banks an unbounded buffer that absorbs before health
		// and makes the break check unreachable
		var/excess = shield_power_allocation - 1
		var/overhealth_rate = shield_regen_rate * excess * seconds_per_tick
		shield_overhealth = min(shield_overhealth + overhealth_rate, shield_max_health * SHIP_SHIELD_MAX_OVERHEALTH_MULT)

/// Absorbs incoming damage to the shared shield pool
/// Returns TRUE if damage was absorbed (even partially), FALSE if shields were down
/obj/structure/overmap/ship/proc/absorb_shield_damage(damage, turf/impact_loc)
	if(!shields_active || shields_broken)
		return FALSE

	// First absorb from overhealth
	if(shield_overhealth > 0)
		var/overhealth_absorbed = min(damage, shield_overhealth)
		shield_overhealth -= overhealth_absorbed
		damage -= overhealth_absorbed

	// Then from regular health
	shield_health -= damage

	// Visual and audio effects at impact location
	do_shield_hit_effects(impact_loc)

	// Signal that shield was hit
	SEND_SIGNAL(src, COMSIG_SHIP_SHIELD_HIT, damage, impact_loc)

	// Check for shield break
	if(shield_health <= 0)
		shield_health = 0
		break_ship_shields(graceful = FALSE)  // Damage break - stored health resets to 0

	return TRUE

/// Called when shields go offline (either depleted or manually turned off)
/// graceful = TRUE: Manual shutdown, preserves current health for reactivation
/// graceful = FALSE: Damage break or shield pop, resets stored health to 0
/obj/structure/overmap/ship/proc/break_ship_shields(graceful = FALSE)
	if(!shields_active)
		return

	// Store or reset health based on shutdown type
	if(graceful)
		stored_shield_health = shield_health  // Preserve for manual shutdown
	else
		stored_shield_health = 0  // Reset for damage break or shield pop

	shields_active = FALSE
	shields_broken = TRUE
	shield_health = 0
	shield_overhealth = 0

	// Start cooldown
	COOLDOWN_START(src, shield_reactivation_cooldown, SHIP_SHIELD_BROKEN_COOLDOWN)

	// Round 4: a silent collapse was indistinguishable from shields refusing to come
	// online. Every collapse tells the crew what happened and when they can retry.
	if(graceful)
		ship_notify("Shields are down. They can be raised again in [DisplayTimeText(SHIP_SHIELD_BROKEN_COOLDOWN)].", "SHIELDS", SHIP_NOTIFY_NOTICE, 'voidcrew/sound/notify.ogg', 30)
	else
		ship_notify("Shields have collapsed! Generators resetting - [DisplayTimeText(SHIP_SHIELD_BROKEN_COOLDOWN)] before they can be raised again.", "SHIELDS", SHIP_NOTIFY_DANGER, 'voidcrew/sound/alert2.ogg', 40)

	// Ensure ship keeps processing so it can check cooldown and reactivate
	start_shield_processing()

	// Notify all generators
	for(var/obj/machinery/ship_combat/shield_generator/gen in linked_shield_generators)
		gen.on_ship_shields_broken()

	// Remove shield walls (first generator with walls handles this)
	for(var/obj/machinery/ship_combat/shield_generator/gen in linked_shield_generators)
		if(length(gen.shield_walls))
			gen.destroy_shield_walls()
			break

	SEND_SIGNAL(src, COMSIG_SHIP_SHIELD_BROKEN)

/// Called to reactivate shields after cooldown ends
/obj/structure/overmap/ship/proc/reactivate_ship_shields()
	if(!shields_broken)
		return
	if(!COOLDOWN_FINISHED(src, shield_reactivation_cooldown))
		return

	// Can't reactivate while docked - just clear broken status and stop processing
	if(!isnull(docked))
		shields_broken = FALSE
		stop_shield_processing()
		return

	shields_broken = FALSE

	// Reactivate all generators that want to be active (have power allocation)
	var/any_activated = FALSE
	var/obj/machinery/ship_combat/shield_generator/first_active_gen
	for(var/obj/machinery/ship_combat/shield_generator/gen in linked_shield_generators)
		if(gen.power_allocation > 0 && !(gen.machine_stat & (BROKEN|NOPOWER)))
			gen.active = TRUE
			gen.update_appearance()
			gen.update_power_draw()
			gen.generator_sound?.start()
			if(!first_active_gen)
				first_active_gen = gen
			any_activated = TRUE

	if(any_activated)
		// Recalculate stats and activate
		recalculate_shield_stats()
		shields_active = TRUE
		// Restore stored health (capped to max in case generators changed), but never
		// come back below the raise charge floor. Returning at 0 HP meant the first
		// hit re-broke the pool and re-armed the full cooldown, so under sustained
		// fire (round 4 meteor shower) shields could never re-establish.
		shield_health = clamp(max(stored_shield_health, shield_max_health * SHIP_SHIELD_RAISE_CHARGE_MULT), 0, shield_max_health)

		// Spawn shield walls from first active generator
		if(first_active_gen)
			first_active_gen.spawn_shield_walls()

		SEND_SIGNAL(src, COMSIG_SHIP_SHIELD_RESTORED)
		playsound(first_active_gen || src, 'sound/vehicles/mecha/mech_shield_raise.ogg', 100, TRUE)
		ship_notify("Shields are back online.", "SHIELDS", SHIP_NOTIFY_NOTICE, 'voidcrew/sound/notify.ogg', 30)
	else
		// No generators want to activate - stop processing
		stop_shield_processing()

/// Sets power allocation for all generators and the ship
/obj/structure/overmap/ship/proc/set_shield_power_allocation(new_allocation)
	shield_power_allocation = clamp(new_allocation, SHIP_SHIELD_MIN_POWER_MULT, SHIP_SHIELD_MAX_POWER_MULT)
	for(var/obj/machinery/ship_combat/shield_generator/gen in linked_shield_generators)
		gen.set_power_allocation(shield_power_allocation)

/// Visual and audio effects for shield hit
/obj/structure/overmap/ship/proc/do_shield_hit_effects(turf/impact_loc)
	// Find the nearest boundary turf for visual effect
	var/turf/effect_loc = impact_loc
	for(var/obj/machinery/ship_combat/shield_generator/gen in linked_shield_generators)
		if(gen.active)
			effect_loc = gen.get_nearest_boundary_turf(impact_loc)
			break

	if(effect_loc)
		new /obj/effect/temp_visual/ship_shield_hit(effect_loc)
		var/sound_file = pick(
			'voidcrew/sound/machines/forcefield/hit1.ogg',
			'voidcrew/sound/machines/forcefield/hit2.ogg',
			'voidcrew/sound/machines/forcefield/hit3.ogg',
			'voidcrew/sound/machines/forcefield/hit4.ogg',
			'sound/vehicles/mecha/mech_shield_deflect.ogg',
		)
		playsound(effect_loc, sound_file, 60, TRUE, extrarange = 10, pressure_affected = FALSE)

/**
 * Why can't shields come up right now? Returns a player-facing reason string, or null
 * if nothing is blocking activation. Round 4: every path that refused activation did
 * so silently, which read as "shields refuse to work" - anything that acts on a
 * player's request for shields should surface this instead of doing nothing.
 */
/obj/structure/overmap/ship/proc/get_shield_blocker_reason()
	if(!length(linked_shield_generators))
		return "No shield generators are linked to the ship."
	if(shields_broken)
		if(!COOLDOWN_FINISHED(src, shield_reactivation_cooldown))
			return "Shield generators are resetting - [DisplayTimeText(COOLDOWN_TIMELEFT(src, shield_reactivation_cooldown))] before shields can be raised."
		return "Shield generators are resetting."
	if(is_in_ship_to_ship_dock())
		return "Shields cannot be raised while docked to another ship."
	var/gen_count = 0
	var/unpowered = 0
	var/dock_latched = 0
	for(var/obj/machinery/ship_combat/shield_generator/gen in linked_shield_generators)
		gen_count++
		if(gen.machine_stat & NOPOWER)
			unpowered++
		if(gen.in_ship_to_ship_dock)
			dock_latched++
	if(gen_count && unpowered == gen_count)
		return "No linked shield generator has power."
	// The generators keep their own ship-to-ship dock latch (signal-driven); if it is
	// stuck out of step with the ship's real state, surface it rather than letting
	// every activation attempt die silently
	if(gen_count && dock_latched == gen_count)
		return "Shields cannot be raised while docked to another ship."
	return null

/// Returns aggregated shield status for UI
/obj/structure/overmap/ship/proc/get_shield_status()
	// Calculate total power draw and efficiency
	var/total_power_draw = 0
	var/total_efficiency_bonus = 0
	var/gen_count = 0

	for(var/obj/machinery/ship_combat/shield_generator/gen in linked_shield_generators)
		if(!(gen.machine_stat & (BROKEN|NOPOWER)))
			// Only active generators actually draw - update_power_draw() zeroes the
			// usage while inactive (break cooldown, ship-to-ship dock), so summing
			// inactive ones overstates the readout against the real grid load
			if(gen.active)
				total_power_draw += gen.get_power_draw()
			total_efficiency_bonus += (1 - gen.power_efficiency)
			gen_count++

	var/avg_efficiency = gen_count ? (total_efficiency_bonus / gen_count) * 100 : 0

	return list(
		"active" = shields_active,
		"broken" = shields_broken,
		"health" = round(shield_health),
		"max_health" = round(shield_max_health),
		"overhealth" = round(shield_overhealth),
		"power_allocation" = shield_power_allocation,
		"regen_rate" = round(shield_regen_rate * shield_power_allocation, 0.1),
		"power_draw" = round(total_power_draw),
		"efficiency" = round(avg_efficiency),
		"cooldown_active" = shields_broken && !COOLDOWN_FINISHED(src, shield_reactivation_cooldown),
		"cooldown_remaining" = COOLDOWN_TIMELEFT(src, shield_reactivation_cooldown),
		"generator_count" = length(linked_shield_generators),
	)

/// Counts laser turrets linked to any combat console aboard this ship.
/// LASER_MAX_TURRETS is a per-hull cap, but the linked lists live on the consoles -
/// counting only one console's list lets a second console double the ceiling.
/obj/structure/overmap/ship/proc/count_linked_turrets()
	if(!shuttle)
		return 0
	var/list/counted = list()
	for(var/area/ship_area in shuttle.shuttle_areas)
		for(var/obj/machinery/computer/camera_advanced/ship_combat/console in ship_area)
			for(var/datum/weakref/ref in console.linked_turrets)
				var/obj/machinery/ship_combat/laser_turret/turret = ref.resolve()
				if(turret)
					counted |= turret
	return length(counted)

/// Starts shield processing on this ship (called when shields activate)
/obj/structure/overmap/ship/proc/start_shield_processing()
	update_ship_processing()

/// Stops shield processing on this ship (called when shields deactivate)
/obj/structure/overmap/ship/proc/stop_shield_processing()
	update_ship_processing()

/**
 * Updates which subsystem the ship is registered with based on current needs.
 * Uses SSfastprocess (0.2s) when thrusting for responsive controls.
 * Uses SSobj (2s) when only shields are active (slower is fine for regen).
 * Stops processing entirely when neither is needed.
 */
/obj/structure/overmap/ship/proc/update_ship_processing()
	var/needs_fast = thrust_processing && burn_direction != BURN_NONE
	var/needs_slow = shields_active || shields_broken

	if(needs_fast)
		// Need fast processing for thrust - use SSfastprocess
		if(datum_flags & DF_ISPROCESSING)
			// Already processing somewhere, check if we need to switch
			if(!(src in SSfastprocess.processing))
				STOP_PROCESSING(SSobj, src)
				START_PROCESSING(SSfastprocess, src)
		else
			START_PROCESSING(SSfastprocess, src)
	else if(needs_slow)
		// Only need slow processing for shields - use SSobj
		if(datum_flags & DF_ISPROCESSING)
			// Already processing somewhere, check if we need to switch
			if(!(src in SSobj.processing))
				STOP_PROCESSING(SSfastprocess, src)
				START_PROCESSING(SSobj, src)
		else
			START_PROCESSING(SSobj, src)
	else
		// Don't need any processing
		if(datum_flags & DF_ISPROCESSING)
			// Try stopping from both (one will be a no-op)
			STOP_PROCESSING(SSfastprocess, src)
			STOP_PROCESSING(SSobj, src)
		thrust_processing = FALSE
