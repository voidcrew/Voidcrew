///
/// Hull mass and structural integrity.
///
/// Event-driven mass tracking: turf signals feed apply_mass_delta(), which
/// coalesces into a threshold evaluation driving the integrity latch (nominal/
/// critical/disabled) that damage.dm's hazard code and the helm read.

/**
 * Calculates the mass based on the amount of turfs in the shuttle's areas
 * Ship health is based on current turfs vs original turfs
 * Losing turfs = losing health, rebuilding = healing
 *
 * NOTE: This is now only called ONCE during ship initialization to establish baseline.
 * After that, mass is tracked via event-driven delta updates (see setup_mass_tracking).
 * Do NOT call this in a loop - the per-turf signal handlers keep mass current, and
 * apply_mass_delta() feeds the threshold latch.
 */
/obj/structure/overmap/ship/proc/calculate_mass()
	if(!shuttle)
		return 0
	. = 0
	var/list/areas = shuttle.shuttle_areas
	for(var/area/shuttleArea in areas)
		for(var/turf/T in shuttleArea)
			if(isspaceturf(T))
				continue
			// Only count actual shuttle turfs (have baseturf_skipover/shuttle in baseturfs)
			// This prevents planet/ruin turfs from being counted after crash landing
			if(!isshuttleturf(T))
				continue
			// Tiered health: reinforced walls > walls > floors
			if(istype(T, /turf/closed/wall/r_wall))
				. += 3  // Reinforced walls
			else if(istype(T, /turf/closed/wall))
				. += 2  // Regular walls
			else
				.++  // Floors and other turfs

	// First calculation - the hull as built is the baseline, and it starts at full health.
	if(!integrity_initialized)
		mass = .
		max_integrity = mass
		integrity = mass
		integrity_initialized = TRUE
		update_icon_state()
	else
		// A resync rather than a first read: route the difference through the same rule the
		// per-turf handlers use, so a recount can never move the baseline in a direction the
		// incremental path would not have.
		apply_mass_delta(. - mass)

	// Set up event-driven mass tracking after first calculation
	if(integrity_initialized && !mass_tracking_initialized)
		setup_mass_tracking()

/**
 * Returns the mass weight contribution for a turf type
 * Used by delta tracking to update mass without full iteration
 */
/proc/get_turf_mass_weight(turf_type)
	if(ispath(turf_type, /turf/open/space))
		return 0
	if(ispath(turf_type, /turf/closed/wall/r_wall))
		return 3
	if(ispath(turf_type, /turf/closed/wall))
		return 2
	// Non-space turfs (floors, etc)
	if(ispath(turf_type, /turf/open) || ispath(turf_type, /turf/closed))
		return 1
	return 0

/**
 * Returns the mass weight for an actual turf instance
 * Checks if it's a valid shuttle turf before returning weight
 */
/proc/get_turf_mass_weight_instance(turf/T)
	if(!T)
		return 0
	if(isspaceturf(T))
		return 0
	if(!isshuttleturf(T))
		return 0
	if(istype(T, /turf/closed/wall/r_wall))
		return 3
	if(istype(T, /turf/closed/wall))
		return 2
	return 1

/obj/structure/overmap/ship
	/// Whether mass tracking signals have been set up
	var/mass_tracking_initialized = FALSE

/**
 * Sets up event-driven mass tracking by registering signals on shuttle AREAS
 * Areas persist through shuttle movement, so we only register once - no re-registration needed on dock/undock
 * Called once after the initial calculate_mass() establishes the baseline
 */
/obj/structure/overmap/ship/proc/setup_mass_tracking()
	if(mass_tracking_initialized)
		return
	if(!shuttle?.shuttle_areas)
		return

	mass_tracking_initialized = TRUE

	// Register on shuttle areas - these persist through shuttle movement
	for(var/area/shuttle_area as anything in shuttle.shuttle_areas)
		track_hull_area(shuttle_area)

/// New compartments need the same damage tracking as the ship's original areas.
/obj/structure/overmap/ship/proc/track_hull_area(area/shuttle_area)
	RegisterSignal(shuttle_area, COMSIG_AREA_TURF_ADDED, PROC_REF(on_area_turf_added), override = TRUE)
	RegisterSignal(shuttle_area, COMSIG_AREA_TURF_REMOVED, PROC_REF(on_area_turf_removed), override = TRUE)
	for(var/turf/tile in shuttle_area)
		RegisterSignal(tile, COMSIG_TURF_CHANGE, PROC_REF(on_shuttle_turf_change), override = TRUE)

/**
 * Signal handler for when a turf joins a shuttle area
 * Handles: shuttle movement arrival, new construction, shuttle expansion
 */
/obj/structure/overmap/ship/proc/on_area_turf_added(area/source, turf/T, area/old_area)
	SIGNAL_HANDLER

	var/obj/machinery/computer/camera_advanced/base_construction/ship/repair_controller = shuttle?.ship_repair_controller?.resolve()
	if(repair_controller?.repair_tracking && !(source in repair_controller.repair_areas))
		repair_controller.refresh_repair_areas()

	if(!integrity_initialized)
		return

	// Register for in-place type changes on this turf (including space turfs for future repairs)
	RegisterSignal(T, COMSIG_TURF_CHANGE, PROC_REF(on_shuttle_turf_change), override = TRUE)
	// Reassigning a room within this hull neither adds mass nor repairs damage.
	if(shuttle?.shuttle_areas[old_area])
		return

	// Space turfs don't contribute mass, but we still registered for future changes above
	if(isspaceturf(T))
		return

	apply_mass_delta(get_turf_mass_weight_instance(T))

/**
 * Signal handler for when a turf leaves a shuttle area
 * Handles: shuttle movement departure, turf destruction, area changes
 */
/obj/structure/overmap/ship/proc/on_area_turf_removed(area/source, turf/T, area/new_area)
	SIGNAL_HANDLER

	if(!integrity_initialized)
		return
	// Keep the turf's damage tracking when only its compartment changes.
	if(shuttle?.shuttle_areas[new_area])
		return

	// Unregister turf change signal (we register on all turfs including space)
	UnregisterSignal(T, COMSIG_TURF_CHANGE)

	// Space turfs don't contribute mass
	if(isspaceturf(T))
		return

	apply_mass_delta(-get_turf_mass_weight_instance(T))

/**
 * Signal handler for when a shuttle turf changes type in-place
 * Handles: wall -> floor, floor -> space, etc. (without changing area)
 */
/obj/structure/overmap/ship/proc/on_shuttle_turf_change(turf/old_turf, path, list/new_baseturfs, flags, list/post_change_callbacks)
	SIGNAL_HANDLER

	var/obj/machinery/computer/camera_advanced/base_construction/ship/repair_controller = shuttle?.ship_repair_controller?.resolve()
	repair_controller?.on_repair_turf_change(old_turf, path)

	if(!integrity_initialized)
		return

	// Calculate the delta between old and new turf types
	apply_mass_delta(get_turf_mass_weight(path) - get_turf_mass_weight_instance(old_turf))

/**
 * TRUE while mass the hull *loses* should be treated as the crew remodelling rather than as
 * damage, and so should take the baseline down with it.
 *
 * The discriminator is simply whether the ship is parked. A docked, stationary hull is a
 * drydock: cutting a wall out, pulling a module, opening a room up - all of that is the crew
 * choosing to have less ship, and none of it is an injury. Under way, mass only leaves a hull
 * because something took it.
 *
 * Getting this wrong in the lenient direction is what made ordinary construction read as
 * battle damage. max_integrity used to be a pure high-water mark, so building a wall raised
 * the baseline and then removing that same wall did not lower it again: every build-and-undo
 * cycle cost the ship a permanent notch of health, and pulling a fitted ship module - which
 * can be forty-odd mass - dropped a Goon far enough in one action to trip the crash alarm
 * while it sat safely in a berth.
 */
/obj/structure/overmap/ship/proc/hull_baseline_follows_losses()
	return state == OVERMAP_SHIP_IDLE

/**
 * How much mass this hull may lose before it is disabled.
 *
 * Fraction of the baseline for anything of a normal size, with an absolute floor underneath
 * for hulls small enough that a percentage stops being a meaningful quantity of ship.
 */
/obj/structure/overmap/ship/proc/integrity_damage_allowance()
	return max(SHIP_INTEGRITY_MIN_ALLOWANCE, max_integrity * SHIP_INTEGRITY_ALLOWANCE_FRACTION)

/// Mass at or below which the hull is disabled.
/obj/structure/overmap/ship/proc/integrity_disabled_threshold()
	return max_integrity - integrity_damage_allowance()

/// Mass the hull must be repaired back to before an alarm clears.
/obj/structure/overmap/ship/proc/integrity_recovery_threshold()
	return max_integrity - (integrity_damage_allowance() * SHIP_INTEGRITY_RECOVERY_FRACTION)

/**
 * The one place mass is allowed to move.
 *
 * Every caller - the three turf signal handlers and the full recount - funnels through here so
 * the baseline rule is applied per change rather than per evaluation. That distinction matters
 * during a shuttle move, which removes and re-adds several hundred turfs one at a time: the
 * baseline has to see each -w followed by its +w to stay put, where a rule applied to the
 * accumulated total would sample the hull mid-swing.
 */
/obj/structure/overmap/ship/proc/apply_mass_delta(delta)
	if(!delta)
		return
	mass += delta

	if(!integrity_initialized)
		return

	if(delta > 0)
		// Repairs close the gap to the existing baseline without moving it; only mass beyond
		// the baseline is new hull, and only that raises it.
		max_integrity = max(max_integrity, mass)
	else if(hull_baseline_follows_losses())
		// Deliberate deconstruction. The baseline drops by exactly what was removed, so the
		// hull's damage deficit is carried across the change untouched - a ship that docked
		// with a hole in it still has that hole afterwards, and one that docked sound stays
		// sound no matter how much of itself the crew cuts away.
		max_integrity = max(0, max_integrity + delta)

	queue_integrity_eval()

/**
 * Schedules a threshold evaluation for the end of the tick.
 *
 * Bulk turf work - a shuttle move, an explosion, a map module loading - lands hundreds of
 * mass changes in a single tick. Evaluating each one meant hundreds of COMSIG_SHIP_INTEGRITY_CHANGED
 * signals and, through the helm's handler, hundreds of SStgui.update_uis() calls per dock cycle.
 * Coalescing to one evaluation also means transient mid-operation states are never seen.
 */
/obj/structure/overmap/ship/proc/queue_integrity_eval()
	if(!integrity_initialized || integrity_eval_queued)
		return
	integrity_eval_queued = TRUE
	addtimer(CALLBACK(src, PROC_REF(evaluate_integrity)), 0)

/**
 * Publishes the current integrity and advances the alarm latch.
 *
 * The latch is the whole point: thresholds are compared against the state the ship is
 * already in, so each band is entered once and announced once. The old code re-derived the
 * answer from the last two mass values, which meant a hull hovering near a boundary - exactly
 * where a crew doing repairs spends its time - re-announced on every tile that crossed it.
 */
/obj/structure/overmap/ship/proc/evaluate_integrity()
	integrity_eval_queued = FALSE
	if(QDELETED(src) || !integrity_initialized)
		return

	var/old_integrity = integrity
	integrity = mass

	if(max_integrity > 0 && integrity != old_integrity)
		SEND_SIGNAL(src, COMSIG_SHIP_INTEGRITY_CHANGED, integrity, max_integrity, get_integrity_percent())

	if(max_integrity > 0)
		var/disabled_at = integrity_disabled_threshold()
		var/recovered_at = integrity_recovery_threshold()
		var/critical_at = max_integrity - (integrity_damage_allowance() * SHIP_INTEGRITY_CRITICAL_FRACTION)

		switch(integrity_state)
			if(SHIP_INTEGRITY_NOMINAL)
				if(integrity <= disabled_at)
					enter_integrity_failure()
				else if(integrity <= critical_at)
					integrity_state = SHIP_INTEGRITY_CRITICAL
					start_critical_alert()
			if(SHIP_INTEGRITY_CRITICAL)
				if(integrity <= disabled_at)
					enter_integrity_failure()
				else if(integrity >= recovered_at)
					integrity_state = SHIP_INTEGRITY_NOMINAL
					stop_critical_alert()
			if(SHIP_INTEGRITY_DISABLED)
				if(integrity >= recovered_at)
					integrity_state = SHIP_INTEGRITY_NOMINAL
					stop_critical_alert()
					on_ship_recovered()

	update_icon_state()
