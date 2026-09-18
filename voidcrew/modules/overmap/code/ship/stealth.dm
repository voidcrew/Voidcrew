///
/// Interdiction, line of sight and nebula concealment.
///
/// The speed-limiting interdiction field (and the shield burst that breaks it),
/// overmap LOS, and hiding a hull inside a nebula - including the ram scoop's
/// loud emissions that rip the concealment away.

/obj/structure/overmap/ship
	/// Speed multiplier for external effects like interdiction (1 = normal, 0.5 = half speed)
	var/speed_multiplier = SHIP_SPEED_MULTIPLIER_DEFAULT
	/// Whether this ship is currently being interdicted
	var/is_interdicted = FALSE
	/// Cooldown preventing undocking after being interdicted
	COOLDOWN_DECLARE(interdiction_undock_lockout)
	/// Weakref to the interdictor machine currently affecting this ship
	var/datum/weakref/interdicting_machine_ref
	/// Current interdiction strength for UI display (0 to 1, where 1 = maximum effect)
	var/interdiction_strength = 0

/obj/structure/overmap/ship
	/// List of interdictor machines installed on this ship
	var/list/linked_interdictors = list()

/obj/structure/overmap/ship
	/// Whether this ship is currently hidden inside a nebula
	var/hidden_in_nebula = FALSE
	/// Timer ID for nebula hide warmup
	var/nebula_hide_timer
	/// world.time of the last tick a mounted nebula ram scoop actually harvested.
	/// Concealment stays blocked while this is recent (see is_scoop_hot())
	var/last_scoop_activity = 0

// ===== INTERDICTION PROCS =====

/**
  * Updates the interdiction effect on this ship from an interdictor machine.
  * Called by the interdictor machine when power level changes or warmup progresses.
  * * source - The interdictor machine affecting us
  * * new_multiplier - The new speed multiplier (1 = normal, 0.5 = 50% speed, etc.)
  * * strength - The interdiction strength for UI display (0 to 1)
  */
/obj/structure/overmap/ship/proc/update_interdiction(source, new_multiplier, strength)
	if(!source)
		return
	interdicting_machine_ref = WEAKREF(source)
	speed_multiplier = new_multiplier
	interdiction_strength = strength
	is_interdicted = TRUE

	interrupt_autopilot("interdiction field")

	// Cancel nebula hide warmup if interdicted during it
	if(nebula_hide_timer)
		cancel_nebula_hide()
		ship_notify("Interdiction field disrupted nebula concealment!", "WARNING", SHIP_NOTIFY_WARNING, 'voidcrew/sound/warn.ogg', 25)

	// Force unhide from nebula if interdicted while hidden
	if(hidden_in_nebula)
		unhide_from_nebula()
		ship_notify("Interdiction field forcing emergence from nebula!", "WARNING", SHIP_NOTIFY_WARNING, 'voidcrew/sound/warn.ogg', 25)

/**
  * Clears the interdiction effect on this ship.
  * Called when interdiction ends for any reason.
  */
/obj/structure/overmap/ship/proc/clear_interdiction()
	interdicting_machine_ref = null
	speed_multiplier = SHIP_SPEED_MULTIPLIER_DEFAULT
	interdiction_strength = 0
	is_interdicted = FALSE

/// Base shield health cost for shield burst (one generator's worth)
#define SHIELD_BURST_BASE_COST 500

/**
 * Gets the shield health required to burst free from current interdiction.
 * Cost scales with interdictor power level and upgrades: base_cost * power_level * effect_mult
 * Returns 0 if not interdicted.
 */
/obj/structure/overmap/ship/proc/get_burst_shield_cost()
	if(!is_interdicted)
		return 0
	var/obj/machinery/ship_combat/interdictor/interdictor = interdicting_machine_ref?.resolve()
	if(!interdictor)
		return SHIELD_BURST_BASE_COST  // Fallback to base cost
	return SHIELD_BURST_BASE_COST * interdictor.power_allocation * interdictor.effect_mult

/**
 * Checks if the ship can perform a shield burst to break interdiction.
 * Requirements:
 * - Ship must be interdicted, by a field that has finished locking
 * - Shields must be active (not broken)
 * - Shield health must meet the cost (base * interdictor power level)
 */
/obj/structure/overmap/ship/proc/can_burst_shields()
	if(!is_interdicted)
		return FALSE
	// is_interdicted is raised at warmup start (see start_interdiction's race-condition
	// note), which used to let a target burst out before the attacker ever earned the
	// lock - and still charged the attacker the full re-interdiction cooldown. A field
	// that is still warming up is escaped by flying out of range, not by dumping the
	// shield pool; bursting is only meaningful against a completed lock.
	var/obj/machinery/ship_combat/interdictor/interdicting_machine = interdicting_machine_ref?.resolve()
	if(interdicting_machine && !interdicting_machine.interdiction_active)
		return FALSE
	if(!shields_active || shields_broken)
		return FALSE
	var/required = get_burst_shield_cost()
	// Overhealth counts - the burst consumes the whole pool, overhealth included
	if(shield_health + shield_overhealth < required)
		return FALSE
	return TRUE

/**
 * Sacrifices all shield energy to break free from interdiction.
 * Drains shields to 0, puts them in broken/cooldown state, and clears interdiction.
 * Returns TRUE on success, FALSE if requirements not met.
 */
/obj/structure/overmap/ship/proc/burst_shields_break_interdiction()
	if(!can_burst_shields())
		return FALSE

	// Get the interdictor that's affecting us so we can notify it
	var/obj/machinery/ship_combat/interdictor/interdictor = interdicting_machine_ref?.resolve()

	// Break our shields - shield pop is NOT graceful, stored health resets to 0
	break_ship_shields(graceful = FALSE)

	// Clear our interdiction state
	clear_interdiction()

	// Tell the interdictor to stop (if it still exists)
	if(interdictor)
		interdictor.on_target_broke_free()

	// Announce to the ship
	ship_notify("SHIELD BURST SUCCESSFUL! Interdiction field disrupted. Shields offline - recharging.", "EMERGENCY MANEUVER", SHIP_NOTIFY_NOTICE, 'voidcrew/sound/notify.ogg', 50)

	return TRUE

// ===== LINE OF SIGHT CHECKS =====

/// Checks if this ship has line of sight to another ship (not blocked by nebulas or other opaque objects)
/obj/structure/overmap/ship/proc/has_los_to(obj/structure/overmap/ship/target)
	var/turf/our_turf = get_turf(src)
	var/turf/their_turf = get_turf(target)

	if(!our_turf || !their_turf)
		return FALSE

	// Same tile = always LOS
	if(our_turf == their_turf)
		return TRUE

	// Adjacent = skip the expensive checks
	if(get_dist(our_turf, their_turf) <= 1)
		return TRUE

	// Check all turfs between ships (excluding endpoints) for opaque blockers
	var/list/line = get_line(our_turf, their_turf)
	var/line_length = length(line)

	for(var/i in 2 to (line_length - 1)) // Skip first and last turf (the ships themselves)
		var/turf/T = line[i]
		// Check turf opacity (shouldn't happen on overmap but just in case)
		if(T.opacity)
			return FALSE
		// Check for opaque objects on the turf (nebulas have opacity = TRUE)
		for(var/atom/A in T)
			if(A.opacity && A != src && A != target)
				return FALSE

	return TRUE

// ===== NEBULA CONCEALMENT =====

/// Warmup time for nebula concealment in deciseconds
#define NEBULA_HIDE_WARMUP_TIME (10 SECONDS)
/// How long after a ram scoop harvest tick the ship stays too loud to conceal
#define SCOOP_EMISSIONS_LOCKOUT (10 SECONDS)

/// Whether recent ram scoop activity is lighting the ship up (blocks nebula concealment)
/obj/structure/overmap/ship/proc/is_scoop_hot()
	return world.time < last_scoop_activity + SCOOP_EMISSIONS_LOCKOUT

/**
 * Called by a mounted nebula ram scoop every tick it actually harvests gas.
 * Scooping is deliberately loud. It blocks new concealment attempts and rips
 * away any active concealment, so the fuel stop is also the ambush spot.
 */
/obj/structure/overmap/ship/proc/notify_scoop_activity()
	last_scoop_activity = world.time
	if(nebula_hide_timer)
		cancel_nebula_hide()
		ship_notify("Ram scoop emissions disrupted nebula concealment!", "WARNING", SHIP_NOTIFY_WARNING, 'voidcrew/sound/warn.ogg', 25)
	if(hidden_in_nebula)
		unhide_from_nebula()
		ship_notify("Ram scoop emissions have revealed the ship!", "WARNING", SHIP_NOTIFY_WARNING, 'voidcrew/sound/warn.ogg', 25)

/// Checks if the ship can start hiding in a nebula
/obj/structure/overmap/ship/proc/can_hide_in_nebula()
	// Already hidden or in process of hiding
	if(hidden_in_nebula || nebula_hide_timer)
		return FALSE

	// Can't hide while interdicted
	if(is_interdicted)
		return FALSE

	// Active ram scoop emissions light the ship up
	if(is_scoop_hot())
		return FALSE

	// Must be on a nebula tile
	var/turf/our_turf = get_turf(src)
	if(!our_turf)
		return FALSE

	for(var/obj/structure/overmap/event/nebula/N in our_turf)
		return TRUE

	return FALSE

/// Starts the nebula hide warmup process (10 seconds)
/obj/structure/overmap/ship/proc/hide_in_nebula()
	if(!can_hide_in_nebula())
		return FALSE

	// Stop all movement first - we're holding position to hide
	speed[1] = 0
	speed[2] = 0
	update_flight_parallax() // holding position means the starfield stops too

	// Start the warmup timer
	nebula_hide_timer = addtimer(CALLBACK(src, PROC_REF(complete_nebula_hide)), NEBULA_HIDE_WARMUP_TIME, TIMER_STOPPABLE)

	// Announce to crew
	ship_notify("Entering the nebula in [NEBULA_HIDE_WARMUP_TIME / 10] seconds", "HELM", SHIP_NOTIFY_NOTICE, 'voidcrew/sound/notify.ogg', 50)

	return TRUE

/// Completes the nebula hide process after warmup
/obj/structure/overmap/ship/proc/complete_nebula_hide()
	nebula_hide_timer = null

	// Verify we're still on a nebula and can hide
	var/turf/our_turf = get_turf(src)
	var/on_nebula = FALSE
	if(our_turf)
		for(var/obj/structure/overmap/event/nebula/N in our_turf)
			on_nebula = TRUE
			break

	if(!on_nebula || is_interdicted || is_scoop_hot())
		return FALSE

	hidden_in_nebula = TRUE

	// Make the ship invisible using managed invisibility (so it stacks properly with cloak)
	SetInvisibility(INVISIBILITY_ABSTRACT, "nebula_concealment", 100)

	// Send signal to drop all combat connections
	SEND_SIGNAL(src, COMSIG_SHIP_GOING_DARK)

	return TRUE

/// Cancels an in-progress nebula hide attempt
/obj/structure/overmap/ship/proc/cancel_nebula_hide()
	if(!nebula_hide_timer)
		return FALSE

	deltimer(nebula_hide_timer)
	nebula_hide_timer = null

	return TRUE

/// Checks if the ship can emerge from nebula concealment
/obj/structure/overmap/ship/proc/can_unhide_from_nebula()
	return hidden_in_nebula

/// Emerges from nebula concealment - makes the ship visible again
/obj/structure/overmap/ship/proc/unhide_from_nebula()
	if(!can_unhide_from_nebula())
		return FALSE

	hidden_in_nebula = FALSE

	// Remove the nebula invisibility source (may still be invisible if cloaked)
	RemoveInvisibility("nebula_concealment")

	// Send signal that we're emerging
	SEND_SIGNAL(src, COMSIG_SHIP_EMERGING_FROM_NEBULA)

	// Announce to crew
	ship_notify("Emerging from nebula concealment.", "HELM", SHIP_NOTIFY_NOTICE, 'voidcrew/sound/notify.ogg', 50)

	return TRUE

#undef NEBULA_HIDE_WARMUP_TIME
#undef SCOOP_EMISSIONS_LOCKOUT
#undef SHIELD_BURST_BASE_COST
