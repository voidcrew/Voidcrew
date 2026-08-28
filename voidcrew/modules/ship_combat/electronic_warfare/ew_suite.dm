/**
 * Electronic Warfare Suite - executes exploit payloads against locked ships
 *
 * Links to the weapons console with a multitool, exactly like the data siphon.
 * Exploit software is loaded as physical cartridges (/obj/item/ew_exploit);
 * the crew executes them from the weapons console while holding a target lock.
 *
 * Every execution builds signature on the suite. At EW_SIGNATURE_MAX the
 * target traces the connection: the suite locks out for EW_TRACE_LOCKOUT and
 * the target crew is told exactly who was attacking them.
 */
/obj/machinery/ship_combat/ew_suite
	name = "electronic warfare suite"
	desc = "A rack of intrusion hardware for attacking a locked ship's onboard systems. Link it to a weapons system with a multitool, then load exploit cartridges to make them available at the console."
	icon = 'icons/obj/machines/telecomms.dmi'
	icon_state = "bus"
	density = TRUE
	anchored = TRUE
	power_channel = AREA_USAGE_EQUIP
	circuit = /obj/item/circuitboard/machine/ship_combat/ew_suite
	idle_power_usage = 0
	active_power_usage = BASE_MACHINE_ACTIVE_CONSUMPTION
	max_integrity = 250
	integrity_failure = 0.5
	armor_type = /datum/armor/ship_ew_suite

	/// Reference to our linked combat console (weakref)
	var/datum/weakref/linked_console_ref
	/// Reference to the ship this suite is installed on (weakref)
	var/datum/weakref/owner_ship_ref
	/// Exploit cartridges physically loaded into the suite (objs, live in contents)
	var/list/loaded_chips = list()
	/// Current signature buildup (0..EW_SIGNATURE_MAX); decays while idle
	var/signature = 0
	/// world.time deadline of the trace lockout; no execution while in the future
	var/traced_until = 0

	// ===== EXECUTION STATE =====
	/// Cartridge currently being executed (weakref)
	var/datum/weakref/executing_chip
	/// Mode string the current execution was started with
	var/execute_mode
	/// Target the current execution was aimed at when warmup began (weakref)
	var/datum/weakref/executing_target_ref
	/// world.time when the current warmup started
	var/warmup_start_time = 0
	/// Effective warmup length of the current execution (deciseconds)
	var/warmup_total = 0
	/// Timer id for the warmup completion callback
	var/warmup_timer_id
	/// Per-payload-type cooldowns: assoc payload typepath -> world.time when ready again
	var/list/payload_cooldowns = list()
	/// Weakrefs to payload instances we launched that may still be running
	var/list/launched_payloads = list()
	/// The last ship we executed a payload against (weakref) - named by the trace
	var/datum/weakref/last_target_ref

	// ===== STOCK PART MODIFIERS =====
	/// Signature cost multiplier from capacitors (lower = quieter executions)
	var/signature_mult = 1
	/// Power efficiency multiplier from micro-lasers (lower = less power draw)
	var/efficiency_mult = 1
	/// Warmup time multiplier from servos (lower = faster warmup)
	var/warmup_mult = 1

/obj/machinery/ship_combat/ew_suite/Initialize(mapload)
	. = ..()
	RefreshParts()
	RegisterSignal(src, COMSIG_MACHINERY_POWER_LOST, PROC_REF(on_power_lost))
	addtimer(CALLBACK(src, PROC_REF(attempt_auto_link)), 2 SECONDS)

/obj/machinery/ship_combat/ew_suite/Destroy()
	if(warmup_timer_id)
		deltimer(warmup_timer_id)
		warmup_timer_id = null
	unlink_console()
	owner_ship_ref = null
	executing_chip = null
	executing_target_ref = null
	last_target_ref = null
	loaded_chips.Cut()
	launched_payloads.Cut()
	return ..()

/// Called when power is lost - aborts any in-flight execution immediately
/obj/machinery/ship_combat/ew_suite/proc/on_power_lost(datum/source)
	SIGNAL_HANDLER
	if(is_executing())
		INVOKE_ASYNC(src, PROC_REF(abort_execution), "power failure")

/// Loaded cartridges survive tool deconstruction instead of dying with the frame
/obj/machinery/ship_combat/ew_suite/on_deconstruction(disassembled)
	for(var/obj/item/ew_exploit/chip in loaded_chips)
		chip.forceMove(drop_location())
	return ..()

// ========== STOCK PARTS ==========

/obj/machinery/ship_combat/ew_suite/RefreshParts()
	. = ..()

	// Reset to base values
	signature_mult = 1
	efficiency_mult = 1
	warmup_mult = 1

	// Apply capacitor bonuses (signature cost reduction)
	for(var/datum/stock_part/capacitor/cap in component_parts)
		signature_mult -= EW_CAPACITOR_SIGNATURE_MULT * (cap.tier - 1)

	// Apply micro-laser bonuses (power efficiency)
	for(var/datum/stock_part/micro_laser/laser in component_parts)
		efficiency_mult -= EW_LASER_EFFICIENCY_MULT * (laser.tier - 1)

	// Apply servo bonuses (warmup reduction)
	for(var/datum/stock_part/servo/servo in component_parts)
		warmup_mult -= EW_SERVO_WARMUP_MULT * (servo.tier - 1)

	// Clamp values
	signature_mult = max(signature_mult, 0.25)
	efficiency_mult = max(efficiency_mult, 0.3)
	warmup_mult = max(warmup_mult, 0.3)

	update_power_draw()

// ========== POWER MANAGEMENT ==========

/// Updates machine power usage based on current state
/obj/machinery/ship_combat/ew_suite/proc/update_power_draw()
	if(is_executing() || has_live_launched_payload())
		var/power_needed = EW_BASE_POWER_COST * efficiency_mult
		update_mode_power_usage(ACTIVE_POWER_USE, power_needed)
		update_use_power(ACTIVE_POWER_USE)
	else
		update_mode_power_usage(ACTIVE_POWER_USE, 0)
		update_use_power(IDLE_POWER_USE)

// ========== CONSOLE LINKING ==========

/// Links this suite to a combat console
/obj/machinery/ship_combat/ew_suite/proc/link_console(obj/machinery/computer/camera_advanced/ship_combat/console)
	if(!console)
		return FALSE
	unlink_console()
	linked_console_ref = WEAKREF(console)
	RegisterSignal(console, COMSIG_QDELETING, PROC_REF(on_console_deleted))
	return TRUE

/// Unlinks from the current console, clearing the console's side of the link too
/obj/machinery/ship_combat/ew_suite/proc/unlink_console()
	var/obj/machinery/computer/camera_advanced/ship_combat/console = linked_console_ref?.resolve()
	if(console)
		UnregisterSignal(console, COMSIG_QDELETING)
		if(console.linked_ew_ref?.resolve() == src)
			console.linked_ew_ref = null
	linked_console_ref = null

/// Attempts to auto-link to a combat console on the same ship
/obj/machinery/ship_combat/ew_suite/proc/attempt_auto_link()
	// Already linked
	if(linked_console_ref?.resolve())
		return

	var/obj/structure/overmap/ship/our_ship = find_owner_ship()
	if(!our_ship)
		return

	// Find a combat console on this ship that doesn't have a suite linked
	for(var/area/ship_area in our_ship.shuttle.shuttle_areas)
		for(var/obj/machinery/computer/camera_advanced/ship_combat/console in ship_area)
			if(console.linked_ew_ref?.resolve())
				continue
			// Found one - link both sides
			if(link_console(console))
				console.linked_ew_ref = WEAKREF(src)
				return

/// Called when the linked combat console is deleted
/obj/machinery/ship_combat/ew_suite/proc/on_console_deleted(datum/source)
	SIGNAL_HANDLER
	UnregisterSignal(source, COMSIG_QDELETING)
	linked_console_ref = null
	if(is_executing())
		INVOKE_ASYNC(src, PROC_REF(abort_execution), "weapons system lost")

// ========== SHIP FINDING ==========

/// Attempts to find the ship this suite belongs to (lazy initialization)
/obj/machinery/ship_combat/ew_suite/proc/find_owner_ship()
	// Already found
	if(owner_ship_ref?.resolve())
		return owner_ship_ref.resolve()

	var/area/our_area = get_area(src)
	if(!our_area)
		return null

	for(var/obj/structure/overmap/ship/ship as anything in SSovermap.simulated_ships)
		if(!ship.shuttle?.shuttle_areas)
			continue
		if(our_area in ship.shuttle.shuttle_areas)
			owner_ship_ref = WEAKREF(ship)
			return ship

	return null

/// Gets the owner ship (finds it lazily if not cached)
/obj/machinery/ship_combat/ew_suite/proc/get_owner_ship()
	var/obj/structure/overmap/ship/owner = owner_ship_ref?.resolve()
	if(!owner)
		owner = find_owner_ship()
	return owner

// ========== TOOL INTERACTIONS ==========

/obj/machinery/ship_combat/ew_suite/wrench_act(mob/living/user, obj/item/tool)
	. = ITEM_INTERACT_BLOCKING
	if(is_executing())
		to_chat(user, span_warning("Cannot unwrench while an exploit is executing!"))
		return ITEM_INTERACT_BLOCKING
	default_unfasten_wrench(user, tool)
	return ITEM_INTERACT_SUCCESS

/obj/machinery/ship_combat/ew_suite/attackby(obj/item/W, mob/living/user, list/modifiers, list/attack_modifiers)
	if(istype(W, /obj/item/multitool))
		var/obj/item/multitool/tool = W
		tool.set_buffer(src)
		balloon_alert(user, "suite buffered")
		to_chat(user, span_notice("You buffer [src] to the multitool. Use it on a weapons system to link."))
		return TRUE

	if(istype(W, /obj/item/ew_exploit))
		if(!user.transferItemToLoc(W, src))
			balloon_alert(user, "it's stuck to your hand!")
			return TRUE
		balloon_alert(user, "cartridge loaded")
		to_chat(user, span_notice("You slot [W] into [src]. Its exploit is now available at the linked weapons system."))
		playsound(src, 'sound/machines/terminal/terminal_button01.ogg', 40, TRUE)
		return TRUE

	if(default_deconstruction_screwdriver(user, W))
		return
	if(default_deconstruction_crowbar(user, W))
		return
	return ..()

// ========== CHIP TRACKING ==========

// Bookkeeping lives on the contents boundary so every insertion/removal path
// (attackby, UI eject, deconstruction, qdel of a loaded chip) stays consistent.

/obj/machinery/ship_combat/ew_suite/Entered(atom/movable/arrived, atom/old_loc, list/atom/old_locs)
	. = ..()
	if(istype(arrived, /obj/item/ew_exploit))
		loaded_chips |= arrived

/obj/machinery/ship_combat/ew_suite/Exited(atom/movable/gone, direction)
	. = ..()
	if(!istype(gone, /obj/item/ew_exploit))
		return
	loaded_chips -= gone
	if(executing_chip?.resolve() == gone)
		abort_execution("cartridge removed")

/// Ejects a loaded cartridge to the user's hands (if adjacent) or the suite's turf
/obj/machinery/ship_combat/ew_suite/proc/eject_chip(obj/item/ew_exploit/chip, mob/user)
	if(!chip || !(chip in loaded_chips))
		return FALSE
	if(executing_chip?.resolve() == chip)
		abort_execution("cartridge ejected")
	if(user && Adjacent(user))
		user.put_in_hands(chip)
	else
		chip.forceMove(drop_location())
	playsound(src, 'sound/machines/terminal/terminal_button01.ogg', 40, TRUE)
	return TRUE

// ========== EXECUTION ==========

/// TRUE while the trace lockout deadline is in the future
/obj/machinery/ship_combat/ew_suite/proc/is_traced()
	return world.time < traced_until

/// TRUE while a warmup is in progress
/obj/machinery/ship_combat/ew_suite/proc/is_executing()
	return !!warmup_timer_id

/**
 * Validates and starts execution of a loaded exploit cartridge.
 *
 * Called from the linked weapons console's ui_act ("ew_execute").
 * Returns TRUE if warmup started, FALSE (with user feedback) otherwise.
 */
/obj/machinery/ship_combat/ew_suite/proc/execute_payload(obj/item/ew_exploit/chip, mob/user, mode)
	// 1. Suite state
	if(machine_stat & (BROKEN|NOPOWER) || !anchored)
		to_chat(user, span_warning("The electronic warfare suite is offline."))
		return FALSE
	if(is_traced())
		to_chat(user, span_warning("Suite locked out - connection was traced. [round((traced_until - world.time) / 10)] seconds remaining."))
		return FALSE
	if(is_executing())
		to_chat(user, span_warning("An exploit is already executing."))
		return FALSE

	// 2. Cartridge state
	if(!chip || !(chip in loaded_chips))
		to_chat(user, span_warning("That cartridge is not loaded in the suite."))
		return FALSE
	if(chip.is_spent())
		to_chat(user, span_warning("That cartridge is burned out."))
		return FALSE
	var/datum/ew_payload/proto = chip.get_prototype()
	if(!proto)
		to_chat(user, span_warning("The cartridge's software is unreadable."))
		return FALSE

	// 3. Console and target lock
	var/obj/machinery/computer/camera_advanced/ship_combat/console = linked_console_ref?.resolve()
	if(!console)
		to_chat(user, span_warning("The suite is not linked to a weapons system."))
		return FALSE
	if(!console.target_ship)
		to_chat(user, span_warning("No target locked. Acquire a weapons lock first."))
		return FALSE
	var/obj/structure/overmap/ship/target = console.target_ship
	if(!istype(target))
		to_chat(user, span_warning("Intrusion protocols require a ship-class target."))
		return FALSE

	// 4. Range
	var/obj/structure/overmap/ship/owner = get_owner_ship()
	if(!owner)
		to_chat(user, span_warning("The suite cannot resolve its host ship."))
		return FALSE
	var/turf/our_turf = get_turf(owner)
	var/turf/target_turf = get_turf(target)
	if(!our_turf || !target_turf || get_dist(our_turf, target_turf) > COMBAT_MISSILE_LOCK_RANGE)
		to_chat(user, span_warning("Target is out of intrusion range."))
		return FALSE

	// 5. Zone restrictions
	var/zone_error = get_zone_block_reason(owner, target)
	if(zone_error)
		to_chat(user, span_warning(zone_error))
		return FALSE

	// 6. Payload-specific gates
	var/ready_at = payload_cooldowns[chip.payload_type]
	if(ready_at && world.time < ready_at)
		to_chat(user, span_warning("[proto.name] is recompiling. Ready in [round((ready_at - world.time) / 10)] seconds."))
		return FALSE
	if(!proto.works_on_npc && istype(target, /obj/structure/overmap/ship/npc))
		to_chat(user, span_warning("[proto.name] cannot attach to that vessel's systems."))
		return FALSE
	var/datum/component/ship_ew_intrusion/intrusion = target.GetComponent(/datum/component/ship_ew_intrusion)
	if(intrusion?.is_hardened())
		to_chat(user, span_warning("Target firewalls are hardened. Connection refused."))
		return FALSE
	var/can_apply_result = proto.can_apply(target, owner)
	if(can_apply_result != TRUE)
		to_chat(user, span_warning(istext(can_apply_result) ? can_apply_result : "The exploit cannot attach to that target."))
		return FALSE

	// Normalize the mode against the payload's mode list
	if(proto.modes)
		if(!mode || !(mode in proto.modes))
			mode = proto.modes[1]
	else
		mode = null

	// Start warmup - the completion callback revalidates everything
	executing_chip = WEAKREF(chip)
	executing_target_ref = WEAKREF(target)
	execute_mode = mode
	warmup_total = max(1, proto.warmup * warmup_mult)
	warmup_start_time = world.time
	warmup_timer_id = addtimer(CALLBACK(src, PROC_REF(on_warmup_complete)), warmup_total, TIMER_STOPPABLE)
	START_PROCESSING(SSobj, src)
	update_power_draw()

	balloon_alert(user, "executing [proto.name]")
	to_chat(user, span_notice("Executing [proto.name] against [target.display_name]. Payload lands in [round(warmup_total / 10, 0.1)] seconds."))
	playsound(src, 'sound/machines/terminal/terminal_button01.ogg', 50, TRUE)
	return TRUE

/**
 * Warmup completion callback. Revalidates the full execution state - the
 * schedule is not trusted - then instantiates the payload on the target.
 */
/obj/machinery/ship_combat/ew_suite/proc/on_warmup_complete()
	warmup_timer_id = null

	var/obj/item/ew_exploit/chip = executing_chip?.resolve()
	var/obj/structure/overmap/ship/target = executing_target_ref?.resolve()
	var/mode = execute_mode

	// Revalidate - any of this can have changed during warmup
	if(machine_stat & (BROKEN|NOPOWER) || !anchored)
		abort_execution("power failure")
		return
	if(!chip || !(chip in loaded_chips) || chip.is_spent())
		abort_execution("cartridge unavailable")
		return
	var/datum/ew_payload/proto = chip.get_prototype()
	if(!proto)
		abort_execution("cartridge unreadable")
		return
	if(!target || QDELETED(target))
		abort_execution("target lost")
		return
	var/obj/machinery/computer/camera_advanced/ship_combat/console = linked_console_ref?.resolve()
	if(!console || console.target_ship != target)
		abort_execution("weapons lock lost")
		return
	var/obj/structure/overmap/ship/owner = get_owner_ship()
	if(!owner)
		abort_execution("host ship lost")
		return
	var/turf/our_turf = get_turf(owner)
	var/turf/target_turf = get_turf(target)
	if(!our_turf || !target_turf || get_dist(our_turf, target_turf) > COMBAT_MISSILE_LOCK_RANGE)
		abort_execution("target out of range")
		return
	var/zone_error = get_zone_block_reason(owner, target)
	if(zone_error)
		abort_execution("zone restrictions")
		return
	var/datum/component/ship_ew_intrusion/existing_intrusion = target.GetComponent(/datum/component/ship_ew_intrusion)
	if(existing_intrusion?.is_hardened())
		abort_execution("target firewalls hardened")
		return
	if(proto.can_apply(target, owner) != TRUE)
		abort_execution("target rejected the payload")
		return

	// Launch - the payload applies itself to the target in New()
	var/datum/ew_payload/payload = new chip.payload_type(target, owner, mode)
	chip.use_charge()
	payload_cooldowns[chip.payload_type] = world.time + proto.cooldown
	launched_payloads += WEAKREF(payload)
	last_target_ref = WEAKREF(target)

	visible_message(span_notice("[src] chimes: [proto.name] deployed."))
	playsound(src, 'sound/machines/terminal/terminal_alert.ogg', 50, TRUE)

	end_execution()
	// Signature last - a trace triggered here must not clobber a live warmup
	add_signature(proto.signature_cost * signature_mult)

/// Cancels an in-progress warmup at the operator's request
/obj/machinery/ship_combat/ew_suite/proc/cancel_execution(mob/user)
	if(!is_executing())
		return FALSE
	deltimer(warmup_timer_id)
	warmup_timer_id = null
	end_execution()
	if(user)
		to_chat(user, span_notice("Exploit execution cancelled."))
	balloon_alert_to_viewers("execution cancelled")
	return TRUE

/// Aborts an in-progress warmup with a reason, announcing it to the owner ship
/obj/machinery/ship_combat/ew_suite/proc/abort_execution(reason)
	if(warmup_timer_id)
		deltimer(warmup_timer_id)
		warmup_timer_id = null
	else if(!executing_chip)
		return // Nothing in flight
	end_execution()
	var/obj/structure/overmap/ship/owner = get_owner_ship()
	owner?.ship_notify("Exploit execution aborted: [reason].", "EW", SHIP_NOTIFY_WARNING, 'voidcrew/sound/warn.ogg', 25)

/// Clears all per-execution state and re-evaluates power draw
/obj/machinery/ship_combat/ew_suite/proc/end_execution()
	executing_chip = null
	executing_target_ref = null
	execute_mode = null
	warmup_start_time = 0
	warmup_total = 0
	update_power_draw()

// ========== ZONE RULES ==========

/// Returns a user-facing error string if zone rules block execution, or null if clear.
/// Mirrors the console's can_target logic: neither ship in the Neutral Zone, and
/// the attacker's zone must allow weapons fire.
/obj/machinery/ship_combat/ew_suite/proc/get_zone_block_reason(obj/structure/overmap/ship/owner, obj/structure/overmap/ship/target)
	if(!SSovermap_zones.zones_active)
		return null
	var/datum/overmap_zone/our_zone = SSovermap_zones.get_zone(get_turf(owner))
	var/datum/overmap_zone/target_zone = SSovermap_zones.get_zone(get_turf(target))
	if(our_zone?.zone_type == ZONE_GREEN || target_zone?.zone_type == ZONE_GREEN)
		return "Intrusion systems are disabled in the Neutral Zone."
	if(our_zone && !our_zone.weapons_allowed())
		return "Offensive systems are disabled in [our_zone.name]."
	return null

// ========== SIGNATURE & TRACING ==========

/**
 * Adds signature to the suite, clamped to EW_SIGNATURE_MAX.
 * Reaching the ceiling triggers on_traced().
 */
/obj/machinery/ship_combat/ew_suite/proc/add_signature(amount)
	if(amount <= 0)
		return
	signature = min(signature + amount, EW_SIGNATURE_MAX)
	if(signature >= EW_SIGNATURE_MAX)
		on_traced()
	else
		START_PROCESSING(SSobj, src) // Ensure decay keeps ticking

/**
 * The target traced our connection: lock the suite out, reset signature,
 * and tell BOTH crews - the attacker that they were traced, the target
 * exactly who was attacking them.
 */
/obj/machinery/ship_combat/ew_suite/proc/on_traced()
	if(warmup_timer_id)
		deltimer(warmup_timer_id)
		warmup_timer_id = null
	end_execution()
	traced_until = world.time + EW_TRACE_LOCKOUT
	signature = 0

	do_sparks(4, TRUE, src)
	playsound(src, 'sound/machines/warning-buzzer.ogg', 60, TRUE)

	var/obj/structure/overmap/ship/owner = get_owner_ship()
	var/obj/structure/overmap/ship/target = last_target_ref?.resolve()
	owner?.ship_notify("WARNING: Intrusion connection traced by target countermeasures. Electronic warfare suite locked out for [round(EW_TRACE_LOCKOUT / 600)] minutes.", "EW", SHIP_NOTIFY_WARNING, 'voidcrew/sound/warn.ogg', 50)
	if(target && !QDELETED(target) && owner)
		target.ship_notify("Trace complete. Intrusion source identified: [owner.display_name].", "INTRUSION", SHIP_NOTIFY_DANGER, 'voidcrew/sound/alert2.ogg', 25)
	if(owner)
		SEND_SIGNAL(owner, COMSIG_SHIP_EW_TRACED, target)

// ========== STATUS ==========

/// TRUE if any payload we launched is still running (prunes dead entries)
/obj/machinery/ship_combat/ew_suite/proc/has_live_launched_payload()
	var/found = FALSE
	for(var/datum/weakref/ref in launched_payloads.Copy())
		var/datum/ew_payload/payload = ref.resolve()
		if(!payload || payload.expired)
			launched_payloads -= ref
			continue
		found = TRUE
	return found

/// Returns status data for the combat console UI - keys match the EW UI contract
/obj/machinery/ship_combat/ew_suite/proc/get_status()
	var/list/status = list()
	var/traced = is_traced()

	status["signature"] = round(signature, 0.1)
	status["traced"] = traced
	status["trace_remaining"] = traced ? round((traced_until - world.time) / 10) : 0
	status["executing"] = is_executing()

	// Executing payload name and warmup progress
	var/obj/item/ew_exploit/active_chip = executing_chip?.resolve()
	var/datum/ew_payload/active_proto = active_chip?.get_prototype()
	status["executing_name"] = (is_executing() && active_proto) ? active_proto.name : null
	if(is_executing() && warmup_start_time && warmup_total)
		status["warmup_progress"] = clamp(((world.time - warmup_start_time) / warmup_total) * 100, 0, 100)
	else
		status["warmup_progress"] = 0

	status["power_draw"] = (is_executing() || has_live_launched_payload()) ? round(EW_BASE_POWER_COST * efficiency_mult) : 0

	// Loaded cartridges
	var/list/chips = list()
	for(var/obj/item/ew_exploit/chip in loaded_chips)
		var/datum/ew_payload/proto = chip.get_prototype()
		var/ready_at = payload_cooldowns[chip.payload_type]
		var/cooldown_remaining = (ready_at && world.time < ready_at) ? (ready_at - world.time) : 0
		chips += list(list(
			"ref" = REF(chip),
			"name" = (chip.is_spent() || !proto) ? chip.name : proto.name,
			"desc" = proto ? proto.desc : chip.desc,
			"tier" = proto ? proto.tier : 1,
			"subsystem" = proto ? proto.subsystem_name : "unknown",
			"charges" = chip.charges,
			"max_charges" = chip.max_charges,
			"ready" = !chip.is_spent() && !cooldown_remaining && !traced && !!proto,
			"cooldown_remaining" = round(cooldown_remaining / 10),
			"duration" = proto ? round(proto.duration / 10) : 0,
			"modes" = proto?.modes,
		))
	status["chips"] = chips

	// Upgrade tiers from stock parts
	var/capacitor_tier = 0
	var/laser_tier = 0
	var/servo_tier = 0
	for(var/datum/stock_part/capacitor/cap in component_parts)
		capacitor_tier += cap.tier
	for(var/datum/stock_part/micro_laser/laser in component_parts)
		laser_tier += laser.tier
	for(var/datum/stock_part/servo/servo in component_parts)
		servo_tier += servo.tier
	status["upgrades"] = list(
		"capacitor_tier" = capacitor_tier,
		"laser_tier" = laser_tier,
		"servo_tier" = servo_tier,
	)

	return status

/obj/machinery/ship_combat/ew_suite/examine(mob/user)
	. = ..()
	if(is_traced())
		. += span_warning("LOCKED OUT - the last connection was traced. [round((traced_until - world.time) / 10)] seconds remaining.")
	else if(is_executing())
		. += span_warning("Executing an exploit. [round(max(0, warmup_start_time + warmup_total - world.time) / 10, 0.1)] seconds to payload.")
	. += span_notice("Signature: [round(signature)]/[EW_SIGNATURE_MAX]")
	. += span_notice("Loaded cartridges: [length(loaded_chips)]")
	. += span_notice("Signature Dampening: [round((1 - signature_mult) * 100)]% reduction")
	. += span_notice("Power Efficiency: [round((1 - efficiency_mult) * 100)]% reduction")
	. += span_notice("Warmup Time: [round((1 - warmup_mult) * 100)]% reduction")
	var/obj/machinery/computer/camera_advanced/ship_combat/console = linked_console_ref?.resolve()
	if(console)
		. += span_notice("Linked to: [console]")
	else
		. += span_warning("Not linked to a weapons system. Use a multitool to link.")

// ========== PROCESSING ==========

/obj/machinery/ship_combat/ew_suite/process(seconds_per_tick)
	update_power_draw()

	// Power loss aborts an in-flight execution (signature still decays below)
	if(machine_stat & (BROKEN|NOPOWER))
		if(is_executing())
			abort_execution("power failure")

	// Signature decays while not executing
	if(!is_executing() && signature > 0)
		signature = max(0, signature - EW_SIGNATURE_DECAY * seconds_per_tick)

	// Nothing left to tick for
	if(!is_executing() && signature <= 0 && !has_live_launched_payload())
		update_power_draw()
		return PROCESS_KILL

// ========== CIRCUIT BOARD ==========

/obj/item/circuitboard/machine/ship_combat/ew_suite
	name = "Electronic Warfare Suite"
	greyscale_colors = CIRCUIT_COLOR_COMMAND
	build_path = /obj/machinery/ship_combat/ew_suite
	req_components = list(
		/datum/stock_part/capacitor = 2,
		/datum/stock_part/micro_laser = 1,
		/datum/stock_part/servo = 1,
	)

// ========== ARMOR ==========

/datum/armor/ship_ew_suite
	melee = 30
	bullet = 30
	laser = 30
	energy = 40
	bomb = 25
	fire = 80
	acid = 50
