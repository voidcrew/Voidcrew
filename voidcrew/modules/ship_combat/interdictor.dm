// Ship Combat Interdictor
// A machine that slows enemy ships by creating an interdiction field
// Must be linked to a combat console via multitool
// Power level controls interdiction strength (higher power = slower target)
// Has 5-second warmup before full effect
// Prevents target from cloaking while interdicted

/obj/machinery/ship_combat/interdictor
	name = "interdiction system"
	desc = "A ship-mounted gravitic field generator that slows enemy vessels. Link to a weapons system with a multitool. Higher power levels create stronger interdiction fields."
	icon = 'voidcrew/icons/obj/machines/interdictor.dmi'
	icon_state = "off"
	density = TRUE
	anchored = TRUE
	power_channel = AREA_USAGE_EQUIP
	circuit = /obj/item/circuitboard/machine/ship_combat/interdictor
	idle_power_usage = 0
	active_power_usage = BASE_MACHINE_ACTIVE_CONSUMPTION
	max_integrity = 250
	integrity_failure = 0.5
	armor_type = /datum/armor/ship_interdictor

	/// Reference to our linked combat console
	var/datum/weakref/linked_console_ref
	/// Reference to our ship
	var/datum/weakref/linked_ship_ref
	/// Our unique ID for console linking
	var/interdictor_id
	/// Power allocation set by combat console (0.25 to 2.0)
	var/power_allocation = 1
	/// Cached ship mass for power calculations
	var/cached_ship_mass = 100

	// ===== INTERDICTION STATE =====
	/// Is interdiction currently active?
	var/interdiction_active = FALSE
	/// Is warmup in progress?
	var/interdiction_warming_up = FALSE
	/// Warmup progress (0 to 1)
	var/warmup_progress = 0
	/// When warmup started (for calculating progress)
	var/warmup_start_time = 0
	/// Reference to the ship we're interdicting
	var/datum/weakref/interdicted_ship_ref
	/// The beam effect on the overmap
	var/datum/beam/interdiction_beam
	/// List of kinesis effect objects around the target ship
	var/list/obj/effect/interdiction_kinesis_effects = list()
	/// List of mobs that currently have the interdiction fullscreen overlay
	var/list/mob/interdiction_overlay_mobs = list()
	/// Real-time positional sound on the interdictor machine itself
	var/datum/realtime_positional_sound/machine_sound
	/// Timer ID for the target ship sound loop
	var/target_sound_timer
	/// Reference to the target ship for sound playback
	var/datum/weakref/target_sound_ship_ref
	/// Cooldown between interdiction attempts
	COOLDOWN_DECLARE(interdict_cooldown)

	// ===== STOCK PART MODIFIERS =====
	/// Effect strength multiplier from capacitors (higher = more slowdown)
	var/effect_mult = 1
	/// Power efficiency multiplier from micro-lasers (lower = less power draw)
	var/efficiency_mult = 1
	/// Cooldown multiplier from servos (lower = faster cooldown)
	var/cooldown_mult = 1


/obj/machinery/ship_combat/interdictor/Initialize(mapload)
	. = ..()
	interdictor_id = "[rand(1000, 9999)]"
	name = "[initial(name)] ([interdictor_id])"
	machine_sound = new(src, 'voidcrew/sound/machines/interdictor/on.ogg', 7, 7)
	RefreshParts()
	// Register for power loss signal
	RegisterSignal(src, COMSIG_MACHINERY_POWER_LOST, PROC_REF(on_power_lost))
	// Try to auto-link after a short delay
	addtimer(CALLBACK(src, PROC_REF(attempt_auto_link)), 2 SECONDS)

/// Called when power is lost - ensures interdiction stops immediately
/obj/machinery/ship_combat/interdictor/proc/on_power_lost(datum/source)
	SIGNAL_HANDLER
	if(interdiction_active || interdiction_warming_up)
		INVOKE_ASYNC(src, PROC_REF(cancel_interdiction), "Power loss!")

/obj/machinery/ship_combat/interdictor/Destroy()
	cancel_interdiction("Interdictor destroyed!")
	destroy_kinesis_effects()
	clear_all_interdiction_overlays()
	QDEL_NULL(machine_sound)
	stop_target_sound()
	unlink_console()
	unlink_ship()
	return ..()

/obj/machinery/ship_combat/interdictor/process(seconds_per_tick)
	// Update power draw
	update_power_draw()

	// Handle power loss
	if(machine_stat & (BROKEN|NOPOWER))
		if(interdiction_active || interdiction_warming_up)
			cancel_interdiction("Power loss!")
		return

	// Handle warmup phase
	if(interdiction_warming_up)
		process_warmup(seconds_per_tick)
		return

	// Handle active interdiction
	if(interdiction_active)
		process_interdiction(seconds_per_tick)

/obj/machinery/ship_combat/interdictor/RefreshParts()
	. = ..()

	// Reset to base values
	effect_mult = 1
	efficiency_mult = 1
	cooldown_mult = 1

	// Apply capacitor bonuses (effect strength)
	for(var/datum/stock_part/capacitor/cap in component_parts)
		effect_mult += INTERDICTOR_CAPACITOR_EFFECT_MULT * (cap.tier - 1)

	// Apply micro-laser bonuses (power efficiency)
	for(var/datum/stock_part/micro_laser/laser in component_parts)
		efficiency_mult -= INTERDICTOR_LASER_EFFICIENCY_MULT * (laser.tier - 1)

	// Apply servo bonuses (cooldown reduction)
	for(var/datum/stock_part/servo/servo in component_parts)
		cooldown_mult -= INTERDICTOR_SERVO_COOLDOWN_MULT * (servo.tier - 1)

	// Clamp values
	efficiency_mult = max(efficiency_mult, 0.3)
	cooldown_mult = max(cooldown_mult, 0.3)

	update_power_draw()

/obj/machinery/ship_combat/interdictor/examine(mob/user)
	. = ..()
	. += span_notice("Interdictor ID: [interdictor_id]")
	. += span_notice("Power Allocation: [round(power_allocation * 100)]%")
	. += span_notice("Effect Strength: [round(effect_mult * 100)]%")
	. += span_notice("Power Efficiency: [round((1 - efficiency_mult) * 100)]% reduction")
	. += span_notice("Cooldown Reduction: [round((1 - cooldown_mult) * 100)]%")

	if(interdiction_active)
		var/obj/structure/overmap/ship/target = interdicted_ship_ref?.resolve()
		. += span_boldnotice("STATUS: INTERDICTING [target?.display_name || "UNKNOWN"]")
		. += span_notice("Target Speed Cap: [round(get_current_speed_multiplier() * 100)]%")
	else if(interdiction_warming_up)
		. += span_warning("STATUS: LOCKING ON ([round(warmup_progress * 100)]%)")
	else if(!COOLDOWN_FINISHED(src, interdict_cooldown))
		. += span_warning("STATUS: RECHARGING ([round(COOLDOWN_TIMELEFT(src, interdict_cooldown) / 10, 0.1)]s)")
	else
		. += span_notice("STATUS: READY")

	var/obj/machinery/computer/camera_advanced/ship_combat/console = linked_console_ref?.resolve()
	if(console)
		. += span_notice("Linked to: [console]")
	else
		. += span_warning("Not linked to a weapons system. Use a multitool to link.")

/obj/machinery/ship_combat/interdictor/update_icon_state()
	. = ..()
	if(machine_stat & (BROKEN|NOPOWER))
		icon_state = "off"
	else
		icon_state = "on"

// ========== POWER CALCULATIONS ==========

/// Returns the current power draw based on state and allocation
/obj/machinery/ship_combat/interdictor/proc/get_power_draw()
	if(!interdiction_active && !interdiction_warming_up)
		return 0

	var/base_power = INTERDICTOR_BASE_POWER_COST + (cached_ship_mass * INTERDICTOR_POWER_PER_MASS)
	return base_power * power_allocation * efficiency_mult

/// Updates machine power usage
/obj/machinery/ship_combat/interdictor/proc/update_power_draw()
	var/power_needed = get_power_draw()
	if(power_needed > 0)
		update_mode_power_usage(ACTIVE_POWER_USE, power_needed)
		update_use_power(ACTIVE_POWER_USE)
	else
		update_mode_power_usage(ACTIVE_POWER_USE, 0)
		update_use_power(IDLE_POWER_USE)

/// Calculates the speed multiplier applied to the target based on power and upgrades
/// Returns a value between 0.15 and 0.75 (lower = slower target)
/obj/machinery/ship_combat/interdictor/proc/get_target_speed_multiplier()
	// Base reduction at 100% power is 0.5 (50% speed)
	// With higher power allocation, target is slower
	// With better capacitors (higher effect_mult), target is slower

	// At power_allocation = 1.0 (100%), base = 0.5
	// At power_allocation = 2.0 (200%), base = 0.25
	// At power_allocation = 0.25 (25%), base = 0.75

	// Linear interpolation: at 25% power = 75% speed, at 200% power = 25% speed
	var/base_multiplier = 1 - (0.5 * power_allocation)  // 0.75 at 25%, 0.5 at 100%, 0 at 200%
	base_multiplier = clamp(base_multiplier, 0.25, 0.75)

	// Apply effect multiplier from capacitors (higher effect = lower speed)
	var/final_multiplier = base_multiplier / effect_mult

	// Clamp to reasonable range
	return clamp(final_multiplier, 0.15, 0.75)

/// Returns the current effective speed multiplier (accounting for warmup)
/obj/machinery/ship_combat/interdictor/proc/get_current_speed_multiplier()
	var/target_mult = get_target_speed_multiplier()
	if(interdiction_warming_up)
		// During warmup, lerp from 1.0 to target
		return 1 - ((1 - target_mult) * warmup_progress)
	return target_mult

// ========== CONSOLE LINKING ==========

/// Links this interdictor to a combat console
/obj/machinery/ship_combat/interdictor/proc/link_console(obj/machinery/computer/camera_advanced/ship_combat/console)
	if(!console)
		return FALSE
	unlink_console()
	linked_console_ref = WEAKREF(console)
	RegisterSignal(console, COMSIG_QDELETING, PROC_REF(on_console_deleted))
	return TRUE

/// Unlinks from the current console
/obj/machinery/ship_combat/interdictor/proc/unlink_console()
	var/obj/machinery/computer/camera_advanced/ship_combat/console = linked_console_ref?.resolve()
	if(console)
		UnregisterSignal(console, COMSIG_QDELETING)
	linked_console_ref = null

/obj/machinery/ship_combat/interdictor/proc/on_console_deleted(datum/source)
	SIGNAL_HANDLER
	linked_console_ref = null

/// Links to our owning ship
/obj/machinery/ship_combat/interdictor/proc/link_ship(obj/structure/overmap/ship/ship)
	if(!ship)
		return FALSE
	unlink_ship()
	linked_ship_ref = WEAKREF(ship)
	ship.linked_interdictors |= src
	cached_ship_mass = ship.mass
	RegisterSignal(ship, COMSIG_VOIDCREW_SHIP_DOCKED, PROC_REF(on_our_ship_docked))
	return TRUE

/// Unlinks from our ship
/obj/machinery/ship_combat/interdictor/proc/unlink_ship()
	var/obj/structure/overmap/ship/ship = linked_ship_ref?.resolve()
	if(ship)
		ship.linked_interdictors -= src
		UnregisterSignal(ship, COMSIG_VOIDCREW_SHIP_DOCKED)
	linked_ship_ref = null

/// Attempts to auto-link to a combat console on the same ship
/obj/machinery/ship_combat/interdictor/proc/attempt_auto_link()
	// Already linked
	if(linked_console_ref?.resolve())
		return

	// Find what ship we're on by checking areas
	var/area/our_area = get_area(src)
	if(!our_area)
		return

	var/obj/structure/overmap/ship/our_ship
	for(var/obj/structure/overmap/ship/S in SSovermap.simulated_ships)
		if(!S.shuttle)
			continue
		if(our_area in S.shuttle.shuttle_areas)
			our_ship = S
			break

	if(!our_ship)
		return

	// Link to ship
	link_ship(our_ship)

	// Find a combat console on this ship
	for(var/area/ship_area in our_ship.shuttle.shuttle_areas)
		for(var/obj/machinery/computer/camera_advanced/ship_combat/console in ship_area)
			// Check if console already has an interdictor
			if(console.linked_interdictor_ref?.resolve())
				continue
			// Found one - link to it
			if(link_console(console))
				console.linked_interdictor_ref = WEAKREF(src)
				return

// ========== INTERDICTION ==========

/// Checks if we can start interdiction
/obj/machinery/ship_combat/interdictor/proc/can_interdict()
	if(machine_stat & (BROKEN|NOPOWER))
		return FALSE
	if(!anchored)
		return FALSE
	if(!COOLDOWN_FINISHED(src, interdict_cooldown))
		return FALSE
	if(interdiction_active || interdiction_warming_up)
		return FALSE
	// Can't interdict while our own ship is docked or not flying
	var/obj/structure/overmap/ship/our_ship = linked_ship_ref?.resolve()
	if(our_ship && our_ship.state != OVERMAP_SHIP_FLYING)
		return FALSE
	// Zone restriction check - interdiction disabled in neutral zones only
	if(!SSovermap_zones.interdiction_allowed_at(src))
		return FALSE
	return TRUE

/// Starts interdiction on a target ship
/obj/machinery/ship_combat/interdictor/proc/start_interdiction(obj/structure/overmap/ship/target, mob/user)
	if(!can_interdict())
		if(user)
			if(machine_stat & (BROKEN|NOPOWER))
				to_chat(user, span_warning("[src] is not operational!"))
			else if(!anchored)
				to_chat(user, span_warning("[src] must be anchored!"))
			else if(!COOLDOWN_FINISHED(src, interdict_cooldown))
				to_chat(user, span_warning("[src] is recharging! Available in [DisplayTimeText(COOLDOWN_TIMELEFT(src, interdict_cooldown))]."))
			else if(interdiction_active || interdiction_warming_up)
				to_chat(user, span_warning("[src] is already interdicting!"))
			else if(!SSovermap_zones.interdiction_allowed_at(src))
				to_chat(user, span_warning("Interdiction is prohibited in this zone!"))
			else
				var/obj/structure/overmap/ship/our_ship = linked_ship_ref?.resolve()
				if(our_ship && our_ship.state != OVERMAP_SHIP_FLYING)
					to_chat(user, span_warning("Cannot activate interdictor while docked!"))
		return FALSE

	if(!target)
		if(user)
			to_chat(user, span_warning("No target selected!"))
		return FALSE

	// Can't interdict a ship already being interdicted
	if(target.is_interdicted)
		if(user)
			to_chat(user, span_warning("Target is already being interdicted by another ship!"))
		return FALSE

	var/obj/structure/overmap/ship/our_ship = linked_ship_ref?.resolve()
	if(!our_ship)
		if(user)
			to_chat(user, span_warning("[src] is not linked to a ship!"))
		return FALSE

	// Can't interdict while being interdicted ourselves
	if(our_ship.is_interdicted)
		if(user)
			to_chat(user, span_warning("Cannot activate interdictor while our ship is being interdicted!"))
		return FALSE

	// Check range
	var/turf/our_turf = get_turf(our_ship)
	var/turf/target_turf = get_turf(target)
	if(!our_turf || !target_turf)
		if(user)
			to_chat(user, span_warning("Cannot determine ship positions!"))
		return FALSE

	var/distance = get_dist(our_turf, target_turf)
	if(distance > INTERDICTOR_RANGE)
		if(user)
			to_chat(user, span_warning("Target is too far away! Move within [INTERDICTOR_RANGE] tiles."))
		return FALSE

	// Check target is flying
	if(target.state != OVERMAP_SHIP_FLYING)
		if(user)
			to_chat(user, span_warning("Target cannot be interdicted!"))
		return FALSE

	// Start warmup phase
	interdiction_warming_up = TRUE
	warmup_progress = 0
	warmup_start_time = world.time
	interdicted_ship_ref = WEAKREF(target)

	// Mark target as interdicted immediately to prevent race conditions
	// (another ship starting interdiction before our first process tick)
	target.update_interdiction(src, 1, 0)

	// Play startup sound
	playsound(src, 'voidcrew/sound/machines/interdictor/startup1.ogg', 17, FALSE)

	// Start processing for warmup ticks
	begin_processing()

	// Register signals on target
	RegisterSignal(target, COMSIG_QDELETING, PROC_REF(on_target_deleted))
	RegisterSignal(target, COMSIG_VOIDCREW_SHIP_MOVED, PROC_REF(on_target_moved))
	RegisterSignal(our_ship, COMSIG_VOIDCREW_SHIP_MOVED, PROC_REF(on_our_ship_moved))

	// Create beam effect
	interdiction_beam = our_ship.Beam(
		target,
		icon_state = "lichbeam",
		icon = 'icons/effects/beam.dmi',
		emissive = TRUE
	)

	// Notify target
	target.ship_notify("INTERDICTION LOCK DETECTED! Evasive maneuvers recommended!", "INTERDICTION", SHIP_NOTIFY_DANGER, 'voidcrew/sound/alert4.ogg', 25)

	// Notify our crew
	if(user)
		to_chat(user, span_notice("Interdiction lock initiated on [target.display_name]. Warming up..."))
	our_ship.ship_notify("Interdiction lock initiated on [target.display_name]. Lock completing in [INTERDICTOR_LOCK_TIME / 10] seconds.", "INTERDICTOR", SHIP_NOTIFY_NOTICE, 'voidcrew/sound/notify.ogg', 50)

	update_appearance()
	update_power_draw()

	return TRUE

/// Processes the warmup phase
/obj/machinery/ship_combat/interdictor/proc/process_warmup(seconds_per_tick)
	var/obj/structure/overmap/ship/target = interdicted_ship_ref?.resolve()
	if(!target)
		cancel_interdiction("Target lost!")
		return

	// Calculate warmup progress
	var/elapsed = world.time - warmup_start_time
	var/lock_time = INTERDICTOR_LOCK_TIME  // Store in variable to avoid macro expansion issues
	warmup_progress = min(elapsed / max(lock_time, 1), 1)

	// Apply partial effect during warmup
	var/current_mult = get_current_speed_multiplier()
	var/strength = 1 - current_mult
	target.update_interdiction(src, current_mult, strength * warmup_progress)

	// Check if warmup complete
	if(warmup_progress >= 1)
		complete_warmup()

/// Completes warmup and starts full interdiction
/obj/machinery/ship_combat/interdictor/proc/complete_warmup()
	interdiction_warming_up = FALSE
	interdiction_active = TRUE
	warmup_progress = 1

	// Play lock complete sound
	playsound(src, 'voidcrew/sound/machines/interdictor/beep.ogg', 17, FALSE)

	var/obj/structure/overmap/ship/target = interdicted_ship_ref?.resolve()
	var/obj/structure/overmap/ship/our_ship = linked_ship_ref?.resolve()

	if(!target)
		cancel_interdiction("Target lost!")
		return

	// Apply full effect
	var/speed_mult = get_target_speed_multiplier()
	var/strength = 1 - speed_mult
	target.update_interdiction(src, speed_mult, strength)

	// Check if ship had meaningful momentum before stopping
	// Use is_still() first as a definitive check, then speed magnitude as backup
	var/was_moving = !target.is_still()
	var/old_speed_x = target.speed[1]
	var/old_speed_y = target.speed[2]
	var/speed_magnitude = sqrt(old_speed_x * old_speed_x + old_speed_y * old_speed_y)

	// Kill all target momentum - they have to re-engage engines
	target.adjust_speed(-target.speed[1], -target.speed[2])

	// If ship was moving at meaningful speed, throw everything inside due to inertia
	// Require both is_still() to be false AND speed magnitude > 0.5 to prevent false positives
	if(was_moving && speed_magnitude > 0.5)
		// Calculate throw direction (inertia continues in direction of travel)
		var/throw_dir = NONE
		if(old_speed_x > 0)
			throw_dir |= EAST
		else if(old_speed_x < 0)
			throw_dir |= WEST
		if(old_speed_y > 0)
			throw_dir |= NORTH
		else if(old_speed_y < 0)
			throw_dir |= SOUTH
		// Throw force based on speed magnitude
		var/throw_force = clamp(round(speed_magnitude * 2), 1, 10)
		target.crash_throw_contents(throw_force, throw_dir, "The ship lurches violently as it's pulled out of motion!")

	// Spawn kinesis effects around target ship
	spawn_kinesis_effects(target)

	// Start looping sounds
	machine_sound?.start()
	// Start playing sound to all mobs on the target ship
	start_target_sound(target)

	// Apply undock lockout
	COOLDOWN_START(target, interdiction_undock_lockout, INTERDICTOR_UNDOCK_LOCKOUT)

	// Notify
	SEND_SIGNAL(target, COMSIG_SHIP_INTERDICTED, src, power_allocation)
	target.ship_notify("INTERDICTION LOCK COMPLETE! Engines limited to [round(speed_mult * 100)]% efficiency! Cloaking disabled!", "INTERDICTION", SHIP_NOTIFY_DANGER)

	if(our_ship)
		our_ship.ship_notify("Interdiction lock complete on [target.display_name]. Target speed capped at [round(speed_mult * 100)]%.", "INTERDICTOR", SHIP_NOTIFY_NOTICE)

	update_appearance()

/// Processes active interdiction
/obj/machinery/ship_combat/interdictor/proc/process_interdiction(seconds_per_tick)
	var/obj/structure/overmap/ship/target = interdicted_ship_ref?.resolve()
	if(!target)
		cancel_interdiction("Target lost!")
		return

	// Update target's speed multiplier (in case power allocation changed)
	var/speed_mult = get_target_speed_multiplier()
	var/strength = 1 - speed_mult
	target.update_interdiction(src, speed_mult, strength)

/// Cancels interdiction for any reason
/obj/machinery/ship_combat/interdictor/proc/cancel_interdiction(reason)
	// Start cooldown only if interdiction was fully active (not just warming up)
	if(interdiction_active)
		var/effective_cooldown = INTERDICTOR_COOLDOWN * cooldown_mult
		COOLDOWN_START(src, interdict_cooldown, effective_cooldown)

	interdiction_active = FALSE
	interdiction_warming_up = FALSE
	warmup_progress = 0

	// Stop processing
	end_processing()

	// Remove beam
	QDEL_NULL(interdiction_beam)

	// Remove kinesis effects
	destroy_kinesis_effects()

	// Remove fullscreen overlays from all mobs
	clear_all_interdiction_overlays()

	// Stop looping sounds
	machine_sound?.stop()
	stop_target_sound()

	// Play shutdown sounds
	playsound(src, 'voidcrew/sound/machines/interdictor/beep2.ogg', 17, FALSE)
	addtimer(CALLBACK(GLOBAL_PROC, GLOBAL_PROC_REF(playsound), src, 'voidcrew/sound/machines/interdictor/off.ogg', 17, FALSE), 0.5 SECONDS)

	// Unregister signals from our ship
	var/obj/structure/overmap/ship/our_ship = linked_ship_ref?.resolve()
	if(our_ship)
		UnregisterSignal(our_ship, COMSIG_VOIDCREW_SHIP_MOVED)

	// Clean up target
	var/obj/structure/overmap/ship/target = interdicted_ship_ref?.resolve()
	if(target)
		UnregisterSignal(target, list(COMSIG_QDELETING, COMSIG_VOIDCREW_SHIP_MOVED))
		target.clear_interdiction()
		SEND_SIGNAL(target, COMSIG_SHIP_INTERDICTION_ENDED)
		target.ship_notify("Interdiction field collapsed. Engines restored to full power.", "INTERDICTION", SHIP_NOTIFY_NOTICE, 'voidcrew/sound/notify.ogg', 50)

	interdicted_ship_ref = null

	update_appearance()
	update_power_draw()

/// Called when the target ship breaks free via shield burst
/// Similar to cancel_interdiction but doesn't clear interdiction on target (they already did that)
/obj/machinery/ship_combat/interdictor/proc/on_target_broke_free()
	var/was_locked = interdiction_active
	interdiction_active = FALSE
	interdiction_warming_up = FALSE
	warmup_progress = 0

	// A burst out of a completed lock leaves the target shieldless for ~47s - rearm fast
	// enough to contest that window rather than eating the full 5-minute cooldown for an
	// engagement the target paid its whole shield pool to escape. A break during warmup
	// charges nothing, mirroring cancel_interdiction(): the lock never completed.
	if(was_locked)
		COOLDOWN_START(src, interdict_cooldown, INTERDICTOR_BURST_BREAK_COOLDOWN * cooldown_mult)

	// Stop processing
	end_processing()

	// Remove beam
	QDEL_NULL(interdiction_beam)

	// Remove kinesis effects
	destroy_kinesis_effects()

	// Remove fullscreen overlays from all mobs
	clear_all_interdiction_overlays()

	// Stop looping sounds
	machine_sound?.stop()
	stop_target_sound()

	// Play shutdown sounds
	playsound(src, 'voidcrew/sound/machines/interdictor/beep2.ogg', 17, FALSE)
	addtimer(CALLBACK(GLOBAL_PROC, GLOBAL_PROC_REF(playsound), src, 'voidcrew/sound/machines/interdictor/off.ogg', 17, FALSE), 0.5 SECONDS)

	// Unregister signals from our ship
	var/obj/structure/overmap/ship/our_ship = linked_ship_ref?.resolve()
	if(our_ship)
		UnregisterSignal(our_ship, COMSIG_VOIDCREW_SHIP_MOVED)

	// Unregister signals from target (but don't clear their interdiction - they already did)
	var/obj/structure/overmap/ship/target = interdicted_ship_ref?.resolve()
	if(target)
		UnregisterSignal(target, list(COMSIG_QDELETING, COMSIG_VOIDCREW_SHIP_MOVED))
		SEND_SIGNAL(target, COMSIG_SHIP_INTERDICTION_ENDED)

	interdicted_ship_ref = null

	// Announce to our ship
	var/obj/structure/overmap/ship/ship = linked_ship_ref?.resolve()
	if(ship)
		ship.ship_notify("Target vessel performed emergency shield burst! Interdiction lock broken.", "INTERDICTOR", SHIP_NOTIFY_WARNING, 'voidcrew/sound/notify2.ogg', 50)

	update_appearance()
	update_power_draw()

/// Sets power allocation (called by combat console)
/obj/machinery/ship_combat/interdictor/proc/set_power_allocation(new_power)
	power_allocation = clamp(new_power, INTERDICTOR_POWER_MIN, INTERDICTOR_POWER_MAX)
	update_power_draw()

	// If actively interdicting, update target immediately
	if(interdiction_active)
		var/obj/structure/overmap/ship/target = interdicted_ship_ref?.resolve()
		if(target)
			var/speed_mult = get_target_speed_multiplier()
			var/strength = 1 - speed_mult
			target.update_interdiction(src, speed_mult, strength)

// ========== SIGNAL HANDLERS ==========

/obj/machinery/ship_combat/interdictor/proc/on_target_deleted(datum/source)
	SIGNAL_HANDLER
	cancel_interdiction("Target destroyed!")

/obj/machinery/ship_combat/interdictor/proc/on_target_moved(datum/source)
	SIGNAL_HANDLER
	check_interdiction_range()

/obj/machinery/ship_combat/interdictor/proc/on_our_ship_moved(datum/source)
	SIGNAL_HANDLER
	check_interdiction_range()

/obj/machinery/ship_combat/interdictor/proc/on_our_ship_docked(datum/source)
	SIGNAL_HANDLER
	cancel_interdiction("Ship docked - interdiction disabled.")

/// Checks if target is still in range
/obj/machinery/ship_combat/interdictor/proc/check_interdiction_range()
	if(!interdiction_active && !interdiction_warming_up)
		return

	var/obj/structure/overmap/ship/target = interdicted_ship_ref?.resolve()
	var/obj/structure/overmap/ship/our_ship = linked_ship_ref?.resolve()

	if(!target || !our_ship)
		return

	var/turf/our_turf = get_turf(our_ship)
	var/turf/target_turf = get_turf(target)

	if(!our_turf || !target_turf)
		return

	var/distance = get_dist(our_turf, target_turf)
	if(distance > INTERDICTOR_RANGE)
		cancel_interdiction("Target escaped interdiction range!")

// ========== FORCE DOCK ==========

/// Forces the interdicted target to dock with us
/obj/machinery/ship_combat/interdictor/proc/force_dock_target(mob/user)
	if(!interdiction_active)
		if(user)
			to_chat(user, span_warning("No ship is currently being interdicted!"))
		return FALSE

	var/obj/structure/overmap/ship/target = interdicted_ship_ref?.resolve()
	var/obj/structure/overmap/ship/our_ship = linked_ship_ref?.resolve()

	if(!target || !our_ship)
		if(user)
			to_chat(user, span_warning("Ship reference lost!"))
		return FALSE

	// Check range for force dock (same tile)
	var/turf/our_turf = get_turf(our_ship)
	var/turf/target_turf = get_turf(target)

	if(!our_turf || !target_turf)
		if(user)
			to_chat(user, span_warning("Cannot determine ship positions!"))
		return FALSE

	var/distance = get_dist(our_turf, target_turf)
	if(distance > INTERDICTOR_FORCE_DOCK_RANGE)
		if(user)
			to_chat(user, span_warning("Target is not on the same tile! Move to their position to force dock."))
		return FALSE

	// Verify target is still flying
	if(target.state != OVERMAP_SHIP_FLYING)
		if(user)
			to_chat(user, span_warning("Target is no longer flying!"))
		cancel_interdiction()
		return FALSE

	// Store reference before cancelling
	var/obj/structure/overmap/ship/dock_target = target

	// Cancel interdiction (removes beam, resets target speed)
	cancel_interdiction()

	// Announce force dock
	our_ship.ship_notify("Forcing [dock_target.display_name] to dock!", "INTERDICTOR", SHIP_NOTIFY_NOTICE, 'voidcrew/sound/notify.ogg', 50)
	dock_target.ship_notify("FORCED DOCKING INITIATED!", "INTERDICTION", SHIP_NOTIFY_DANGER, 'voidcrew/sound/warn2.ogg', 25)

	// Apply extended undock lockout
	COOLDOWN_START(dock_target, interdiction_undock_lockout, INTERDICTOR_FORCE_DOCK_LOCKOUT)

	// Force dock the ships together (instant = TRUE bypasses dock warmup)
	var/result = our_ship.dock_ships_directly(dock_target, null, TRUE)
	if(result)
		// Direct docking failed, fall back to reserve port docking
		our_ship.ship_notify("Direct docking failed, using reserve ports.", "DOCKING", SHIP_NOTIFY_NOTICE, 'voidcrew/sound/notify2.ogg', 50)
		dock_target.ship_notify("Direct docking failed, using reserve ports.", "INTERDICTION", SHIP_NOTIFY_WARNING, 'voidcrew/sound/notify2.ogg', 50)
		var/fallback_result = our_ship.dock_ships_to_reserve_ports(dock_target, null, TRUE)
		if(fallback_result)
			our_ship.ship_notify("Forced docking failed: [fallback_result]", "DOCKING", SHIP_NOTIFY_WARNING, 'voidcrew/sound/notify2.ogg', 50)
			dock_target.ship_notify("Forced docking failed.", "DOCKING", SHIP_NOTIFY_WARNING, 'voidcrew/sound/notify2.ogg', 50)
			return FALSE
		else
			playsound(src, 'sound/machines/airlock/airlockopen.ogg', 50, TRUE)
			if(user)
				to_chat(user, span_notice("Force dock successful (reserve ports)! Target cannot undock for [DisplayTimeText(INTERDICTOR_FORCE_DOCK_LOCKOUT)]."))
			return TRUE
	else
		playsound(src, 'sound/machines/airlock/airlockopen.ogg', 50, TRUE)
		if(user)
			to_chat(user, span_notice("Force dock successful! Target cannot undock for [DisplayTimeText(INTERDICTOR_FORCE_DOCK_LOCKOUT)]."))
		return TRUE

// ========== UTILITY ==========

/// Returns status info for the combat console UI
/obj/machinery/ship_combat/interdictor/proc/get_status()
	var/obj/structure/overmap/ship/target = interdicted_ship_ref?.resolve()
	return list(
		"id" = interdictor_id,
		"name" = name,
		"power_allocation" = power_allocation,
		"power_draw" = round(get_power_draw()),
		"effect_mult" = effect_mult,
		"efficiency_mult" = efficiency_mult,
		"cooldown_mult" = cooldown_mult,
		"interdiction_active" = interdiction_active,
		"warming_up" = interdiction_warming_up,
		"warmup_progress" = warmup_progress,
		"target_name" = target?.display_name,
		"target_speed_cap" = interdiction_active ? round(get_target_speed_multiplier() * 100) : null,
		"cooldown_remaining" = COOLDOWN_FINISHED(src, interdict_cooldown) ? 0 : round(COOLDOWN_TIMELEFT(src, interdict_cooldown) / 10, 0.1),
		"ready" = can_interdict(),
	)

// ========== TOOL INTERACTIONS ==========

/obj/machinery/ship_combat/interdictor/wrench_act(mob/living/user, obj/item/tool)
	. = ITEM_INTERACT_BLOCKING
	if(interdiction_active || interdiction_warming_up)
		to_chat(user, span_warning("Cannot unwrench while interdiction is active!"))
		return ITEM_INTERACT_BLOCKING
	default_unfasten_wrench(user, tool)
	return ITEM_INTERACT_SUCCESS

/obj/machinery/ship_combat/interdictor/attackby(obj/item/W, mob/user, list/modifiers, list/attack_modifiers)
	if(istype(W, /obj/item/multitool))
		var/obj/item/multitool/tool = W
		tool.set_buffer(src)
		balloon_alert(user, "interdictor buffered")
		to_chat(user, span_notice("You buffer [src] to the multitool. Use on a weapons system to link."))
		return TRUE

	if(default_deconstruction_screwdriver(user, W))
		return
	if(default_deconstruction_crowbar(user, W))
		return
	return ..()

// ========== DAMAGE HANDLING ==========

/obj/machinery/ship_combat/interdictor/atom_break(damage_flag)
	. = ..()
	if(.)
		cancel_interdiction("Interdictor destroyed!")
		visible_message(span_danger("[src] sparks and breaks down!"))
		playsound(src, 'sound/effects/sparks/sparks1.ogg', 70, TRUE)
		do_sparks(5, TRUE, src)
		update_appearance()

/obj/machinery/ship_combat/interdictor/emp_act(severity)
	. = ..()
	if(. & EMP_PROTECT_SELF)
		return
	if(machine_stat & BROKEN)
		return

	// EMP breaks interdiction
	if(interdiction_active || interdiction_warming_up)
		cancel_interdiction("EMP disruption!")

	visible_message(span_danger("[src] crackles and sparks from the EMP!"))
	playsound(src, 'sound/effects/sparks/sparks1.ogg', 50, TRUE)
	do_sparks(3, TRUE, src)

	// Apply extended cooldown from EMP
	var/emp_cooldown = rand(30 SECONDS, 60 SECONDS) / severity
	if(!COOLDOWN_FINISHED(src, interdict_cooldown))
		// Add to existing cooldown
		COOLDOWN_START(src, interdict_cooldown, COOLDOWN_TIMELEFT(src, interdict_cooldown) + emp_cooldown)
	else
		COOLDOWN_START(src, interdict_cooldown, emp_cooldown)

	update_appearance()

// ========== KINESIS EFFECTS ==========

/// Spawns interdiction effects around the target ship's boundary
/obj/machinery/ship_combat/interdictor/proc/spawn_kinesis_effects(obj/structure/overmap/ship/target)
	destroy_kinesis_effects()

	if(!target?.shuttle?.shuttle_areas)
		return

	var/list/ship_areas = target.shuttle.shuttle_areas

	// Build associative list of ship turfs for O(1) lookup
	var/list/ship_turfs = list()
	for(var/area/ship_area in ship_areas)
		for(var/turf/T in ship_area)
			ship_turfs[T] = TRUE

	// Find edge turfs only (ship turfs with at least one space neighbor)
	var/list/edge_turfs = list()
	for(var/turf/T as anything in ship_turfs)
		for(var/dir in GLOB.cardinals)
			var/turf/neighbor = get_step(T, dir)
			if(neighbor && isspaceturf(neighbor) && !ship_turfs[neighbor])
				edge_turfs[T] = TRUE
				break

	// Expand outward up to 3 tiles from edge turfs only (much fewer iterations)
	var/list/boundary_turfs = list()
	for(var/turf/edge_turf as anything in edge_turfs)
		for(var/turf/space_turf in RANGE_TURFS(3, edge_turf))
			if(isspaceturf(space_turf) && !ship_turfs[space_turf])
				boundary_turfs[space_turf] = TRUE

	if(!length(boundary_turfs))
		return

	// Spawn count scales with power allocation (25% power = 25% of turfs, 200% power = 100% of turfs)
	var/power_ratio = clamp(power_allocation / INTERDICTOR_POWER_MAX, 0.25, 1)
	var/target_count = max(1, round(length(boundary_turfs) * power_ratio))
	var/list/shuffled_turfs = list()
	for(var/turf/T as anything in boundary_turfs)
		shuffled_turfs += T
	shuffle_inplace(shuffled_turfs)

	// Spawn effects with staggered start times
	var/current_delay = 0
	for(var/i in 1 to target_count)
		var/turf/T = shuffled_turfs[i]
		var/obj/effect/abstract/interdiction_kinesis/effect = new(T, shuffled_turfs)
		interdiction_kinesis_effects += effect
		// Stagger the animation start (random 0-20 deciseconds between each)
		effect.start_animation_delayed(current_delay)
		current_delay += rand(0, 20)

/// Destroys all kinesis effects
/obj/machinery/ship_combat/interdictor/proc/destroy_kinesis_effects()
	for(var/obj/effect/abstract/interdiction_kinesis/effect in interdiction_kinesis_effects)
		qdel(effect)
	interdiction_kinesis_effects.Cut()

/// The visual effect around interdicted ships
/// Uses /obj/effect/abstract to avoid being moved by hyperspace/shuttle systems
/obj/effect/abstract/interdiction_kinesis
	name = "interdiction field"
	desc = "A shimmering gravitational distortion."
	icon = 'voidcrew/icons/effects/effects.dmi'
	icon_state = "interdict"
	layer = ABOVE_MOB_LAYER
	mouse_opacity = MOUSE_OPACITY_TRANSPARENT
	/// All available turfs this effect can appear on
	var/list/available_turfs
	/// Animation cycle duration in deciseconds (12 frames: 4x1 + 4x1 + 4x15 = 68ds)
	var/animation_cycle_time = 68

/obj/effect/abstract/interdiction_kinesis/Initialize(mapload, list/turfs)
	. = ..()
	available_turfs = turfs
	// Randomly pick between interdict sprites for variety
	icon_state = pick("interdict", "interdict2")
	// Prevent hyperspace drift from moving these effects
	ADD_TRAIT(src, TRAIT_HYPERSPACED, INNATE_TRAIT)
	// Start invisible - will be shown by start_animation_delayed
	alpha = 0

/// Starts the animation cycle after a delay (for staggering)
/obj/effect/abstract/interdiction_kinesis/proc/start_animation_delayed(delay)
	if(delay > 0)
		addtimer(CALLBACK(src, PROC_REF(begin_animation_cycle)), delay)
	else
		begin_animation_cycle()

/// Begins an animation cycle and schedules relocation
/obj/effect/abstract/interdiction_kinesis/proc/begin_animation_cycle()
	if(QDELETED(src))
		return
	// Show the effect
	alpha = 180
	// After animation completes, relocate to a new turf
	addtimer(CALLBACK(src, PROC_REF(relocate_and_restart)), animation_cycle_time)

/// Relocates to a random available turf and restarts animation
/obj/effect/abstract/interdiction_kinesis/proc/relocate_and_restart()
	if(QDELETED(src) || !length(available_turfs))
		return
	// Pick a random new turf and validate it exists
	var/turf/new_turf = pick(available_turfs)
	if(!isturf(new_turf))
		return
	forceMove(new_turf)
	// Restart animation cycle
	begin_animation_cycle()

// ========== FULLSCREEN OVERLAY ==========

/// Adds the interdiction fullscreen overlay to a mob
/obj/machinery/ship_combat/interdictor/proc/add_interdiction_overlay(mob/target)
	if(!target?.client)
		return
	if(target in interdiction_overlay_mobs)
		return  // Already has overlay
	interdiction_overlay_mobs += target
	RegisterSignal(target, COMSIG_QDELETING, PROC_REF(on_overlay_mob_deleted))
	var/atom/movable/screen/fullscreen/interdiction/overlay = target.overlay_fullscreen("interdiction", /atom/movable/screen/fullscreen/interdiction)
	overlay?.start_strobe()

/// Removes the interdiction fullscreen overlay from a mob
/obj/machinery/ship_combat/interdictor/proc/remove_interdiction_overlay(mob/target)
	if(!target)
		return
	if(!(target in interdiction_overlay_mobs))
		return
	interdiction_overlay_mobs -= target
	UnregisterSignal(target, COMSIG_QDELETING)
	target.clear_fullscreen("interdiction")

/// Clears interdiction overlays from all tracked mobs
/obj/machinery/ship_combat/interdictor/proc/clear_all_interdiction_overlays()
	for(var/mob/M in interdiction_overlay_mobs)
		UnregisterSignal(M, COMSIG_QDELETING)
		M.clear_fullscreen("interdiction")
	interdiction_overlay_mobs.Cut()

/// Called when a mob with our overlay is deleted
/obj/machinery/ship_combat/interdictor/proc/on_overlay_mob_deleted(datum/source)
	SIGNAL_HANDLER
	interdiction_overlay_mobs -= source

/// The fullscreen overlay shown to mobs on interdicted ships
/atom/movable/screen/fullscreen/interdiction
	icon = 'icons/hud/screen_gen.dmi'
	icon_state = "flash"
	screen_loc = "WEST,SOUTH to EAST,NORTH"
	color = COLOR_GREEN
	alpha = 0
	show_when_dead = TRUE  // Ghosts can see it too

/// Starts the strobe animation
/atom/movable/screen/fullscreen/interdiction/proc/start_strobe()
	animate(src, alpha = 40, time = 1.5 SECONDS, loop = -1, easing = SINE_EASING)
	animate(alpha = 0, time = 1.5 SECONDS, easing = SINE_EASING)

// ========== CIRCUIT BOARD ==========

/obj/item/circuitboard/machine/ship_combat/interdictor
	name = "Interdiction System"
	greyscale_colors = CIRCUIT_COLOR_COMMAND
	build_path = /obj/machinery/ship_combat/interdictor
	req_components = list(
		/datum/stock_part/capacitor = 2,
		/datum/stock_part/micro_laser = 1,
		/datum/stock_part/servo = 1,
	)

// ========== ARMOR ==========

/datum/armor/ship_interdictor
	melee = 30
	bullet = 30
	laser = 30
	energy = 40
	bomb = 25
	fire = 80
	acid = 50

// ========== TARGET SHIP SOUND ==========

/// Starts playing the interdiction sound to all mobs on the target ship
/obj/machinery/ship_combat/interdictor/proc/start_target_sound(obj/structure/overmap/ship/target)
	stop_target_sound()
	if(!target?.shuttle?.shuttle_areas)
		return
	target_sound_ship_ref = WEAKREF(target)
	// Play immediately, then loop
	play_target_sound_loop()

/// Stops the interdiction sound loop
/obj/machinery/ship_combat/interdictor/proc/stop_target_sound()
	if(target_sound_timer)
		deltimer(target_sound_timer)
		target_sound_timer = null
	target_sound_ship_ref = null

/// Plays the sound to all mobs on the target ship and schedules the next play
/obj/machinery/ship_combat/interdictor/proc/play_target_sound_loop()
	target_sound_timer = null

	var/obj/structure/overmap/ship/target = target_sound_ship_ref?.resolve()
	if(!target?.shuttle?.shuttle_areas)
		stop_target_sound()
		return

	// Track which mobs are currently in ship areas
	var/list/mobs_in_ship = list()

	// Play to all mobs with clients in the ship's areas (living and ghosts)
	// Also add interdiction overlay to new mobs
	for(var/area/ship_area in target.shuttle.shuttle_areas)
		for(var/mob/M in ship_area)
			if(!M.client?.prefs)
				continue
			// Only living mobs and ghosts
			if(!isliving(M) && !isobserver(M))
				continue
			mobs_in_ship += M
			// Add interdiction overlay if they don't have it
			add_interdiction_overlay(M)
			// Skip deaf living mobs for sound
			if(isliving(M) && HAS_TRAIT(M, TRAIT_DEAF))
				continue
			// Check volume preference
			var/pref_volume = M.client.prefs.read_preference(/datum/preference/numeric/volume/sound_ship_ambience_volume)
			if(!pref_volume)
				continue
			// Play directly to mob (no positional audio)
			var/actual_volume = 20 * (pref_volume / 100)
			SEND_SOUND(M, sound('voidcrew/sound/machines/interdictor/shield.ogg', volume = actual_volume))

	// Remove overlays from mobs who left the ship
	var/list/mobs_to_remove = interdiction_overlay_mobs - mobs_in_ship
	for(var/mob/M in mobs_to_remove)
		remove_interdiction_overlay(M)

	// Schedule next play (2 second loop)
	target_sound_timer = addtimer(CALLBACK(src, PROC_REF(play_target_sound_loop)), 2 SECONDS, TIMER_STOPPABLE)
