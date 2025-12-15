// Ship Combat Laser Turret
// A machine that fires lasers at enemy ships
// Must be linked to a combat console via multitool
// Power level is adjustable via the console
// Primarily effective against shields

/obj/machinery/ship_combat/laser_turret
	name = "laser turret"
	desc = "A ship-mounted laser weapon system. Effective against shields. Link to a combat console with a multitool and control power levels from there."
	icon = 'icons/obj/weapons/turrets.dmi'
	icon_state = "standard_off"
	density = TRUE
	anchored = TRUE
	power_channel = AREA_USAGE_EQUIP
	circuit = /obj/item/circuitboard/machine/ship_combat/laser_turret

	/// Reference to our linked combat console
	var/datum/weakref/linked_console_ref
	/// Our unique ID for console linking
	var/turret_id
	/// Power level set by combat console (0.25 to 2.0)
	var/power_level = 1
	/// Calculated damage (from base + parts + power level)
	var/current_damage = LASER_DAMAGE_BASE
	/// Calculated power efficiency multiplier (from parts, 0-1 range, lower = more efficient)
	var/power_efficiency = 1
	/// Calculated cooldown multiplier (from parts, 0-1 range, lower = faster)
	var/cooldown_mult = 1
	/// Cooldown between shots
	COOLDOWN_DECLARE(fire_cooldown)

/obj/machinery/ship_combat/laser_turret/Initialize(mapload)
	. = ..()
	turret_id = "[rand(1000, 9999)]"
	name = "[initial(name)] ([turret_id])"
	RefreshParts()
	// Try to auto-link to a combat console on the same ship after a short delay
	addtimer(CALLBACK(src, PROC_REF(attempt_auto_link)), 2 SECONDS)

/obj/machinery/ship_combat/laser_turret/Destroy()
	unlink_console()
	return ..()

/obj/machinery/ship_combat/laser_turret/RefreshParts()
	. = ..()

	// Reset to base values
	current_damage = LASER_DAMAGE_BASE
	power_efficiency = 1
	cooldown_mult = 1

	// Apply stock part modifiers
	// Each part tier above 1 adds a bonus
	for(var/datum/stock_part/micro_laser/laser in component_parts)
		current_damage += LASER_DAMAGE_BASE * LASER_MICROLASER_DAMAGE_MULT * (laser.tier - 1)

	for(var/datum/stock_part/capacitor/cap in component_parts)
		power_efficiency -= LASER_CAPACITOR_EFFICIENCY_MULT * (cap.tier - 1)

	for(var/datum/stock_part/servo/servo in component_parts)
		cooldown_mult -= LASER_SERVO_COOLDOWN_MULT * (servo.tier - 1)

	// Clamp values to prevent negative/zero
	power_efficiency = max(power_efficiency, 0.1)
	cooldown_mult = max(cooldown_mult, 0.3)

/obj/machinery/ship_combat/laser_turret/examine(mob/user)
	. = ..()
	. += span_notice("Turret ID: [turret_id]")
	. += span_notice("Power Level: [round(power_level * 100)]%")
	. += span_notice("Damage: [round(get_effective_damage())]")
	. += span_notice("Cooldown: [round(get_effective_cooldown() / 10, 0.1)]s")
	. += span_notice("Power per Shot: [round(get_power_per_shot())]W")
	if(can_fire())
		. += span_notice("Status: READY")
	else if(!COOLDOWN_FINISHED(src, fire_cooldown))
		. += span_warning("Recharging: [round(COOLDOWN_TIMELEFT(src, fire_cooldown) / 10, 0.1)]s remaining")
	else if(machine_stat & NOPOWER)
		. += span_warning("Status: NO POWER")
	else if(!anchored)
		. += span_warning("Status: NOT ANCHORED")
	var/obj/machinery/computer/camera_advanced/ship_combat/linked_console = linked_console_ref?.resolve()
	if(linked_console)
		. += span_notice("Linked to: [linked_console]")
	else
		. += span_warning("Not linked to a combat console. Use a multitool to link.")

/obj/machinery/ship_combat/laser_turret/update_icon_state()
	. = ..()
	if(machine_stat & (BROKEN))
		icon_state = "standard_broken"
	else if(machine_stat & (NOPOWER))
		icon_state = "standard_off"
	else if(!COOLDOWN_FINISHED(src, fire_cooldown))
		icon_state = "standard_lethal"
	else
		icon_state = "standard_stun"

// ========== POWER CALCULATIONS ==========

/// Returns the effective damage based on power level and parts
/obj/machinery/ship_combat/laser_turret/proc/get_effective_damage()
	return current_damage * power_level

/// Returns the power draw per shot based on power level and efficiency
/obj/machinery/ship_combat/laser_turret/proc/get_power_per_shot()
	return LASER_POWER_BASE * power_level * power_efficiency

/// Returns the cooldown time based on parts
/obj/machinery/ship_combat/laser_turret/proc/get_effective_cooldown()
	return LASER_COOLDOWN_BASE * cooldown_mult

// ========== CONSOLE LINKING ==========

/// Links this turret to a combat console
/obj/machinery/ship_combat/laser_turret/proc/link_console(obj/machinery/computer/camera_advanced/ship_combat/console)
	if(!console)
		return FALSE
	unlink_console()
	linked_console_ref = WEAKREF(console)
	RegisterSignal(console, COMSIG_QDELETING, PROC_REF(on_console_deleted))
	return TRUE

/// Unlinks from the current console
/obj/machinery/ship_combat/laser_turret/proc/unlink_console()
	var/obj/machinery/computer/camera_advanced/ship_combat/console = linked_console_ref?.resolve()
	if(console)
		UnregisterSignal(console, COMSIG_QDELETING)
	linked_console_ref = null

/obj/machinery/ship_combat/laser_turret/proc/on_console_deleted(datum/source)
	SIGNAL_HANDLER
	linked_console_ref = null

/// Attempts to auto-link to a combat console on the same ship
/obj/machinery/ship_combat/laser_turret/proc/attempt_auto_link()
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

	// Find a combat console on this ship
	for(var/area/ship_area in our_ship.shuttle.shuttle_areas)
		for(var/obj/machinery/computer/camera_advanced/ship_combat/console in ship_area)
			// Found one - link to it
			if(link_console(console))
				// Also add ourselves to the console's turret list
				var/already_linked = FALSE
				for(var/datum/weakref/ref in console.linked_turrets)
					if(ref.resolve() == src)
						already_linked = TRUE
						break
				if(!already_linked)
					console.linked_turrets += WEAKREF(src)
				return

// ========== FIRING ==========

/// Checks if the turret can fire
/obj/machinery/ship_combat/laser_turret/proc/can_fire()
	if(machine_stat & (BROKEN|NOPOWER))
		return FALSE
	if(!anchored)
		return FALSE
	if(!COOLDOWN_FINISHED(src, fire_cooldown))
		return FALSE
	return TRUE

/// Fires the laser at the target turf
/// Returns TRUE if fired successfully
/// spread_offset: For multi-laser volleys, offsets the beam start position perpendicular to the firing direction
/obj/machinery/ship_combat/laser_turret/proc/fire(turf/target, obj/structure/overmap/ship/target_ship, obj/structure/overmap/ship/source_ship, mob/user, spread_offset = 0)
	if(!can_fire())
		return FALSE

	if(!target)
		if(user)
			to_chat(user, span_warning("No target selected!"))
		return FALSE

	// Use power for the shot
	var/power_needed = get_power_per_shot()
	if(!use_energy(power_needed))
		if(user)
			to_chat(user, span_warning("[src] doesn't have enough power!"))
		return FALSE

	// Start cooldown
	COOLDOWN_START(src, fire_cooldown, get_effective_cooldown())

	// Calculate damage
	var/damage = get_effective_damage()

	// Create the laser beam effect - it will handle hitting shields or the target
	new /obj/effect/ship_laser_beam(
		get_turf(src),
		target,
		target_ship,
		source_ship,
		damage,
		spread_offset,
		power_level,
	)

	// Play sound
	playsound(src, 'sound/items/weapons/beam_sniper.ogg', 80, TRUE)

	// Visual feedback
	visible_message(span_danger("[src] fires a laser beam!"))
	if(user)
		to_chat(user, span_notice("Laser fired! Target: [target_ship ? target_ship.name : "unknown"]"))

	// Firing breaks cloak
	if(source_ship)
		SEND_SIGNAL(source_ship, COMSIG_SHIP_WEAPON_FIRED)
		SEND_SIGNAL(source_ship, COMSIG_SHIP_LASER_FIRED, src, target_ship)

	update_appearance()
	return TRUE

/// Sets the power level (0.25 to 2.0)
/obj/machinery/ship_combat/laser_turret/proc/set_power_level(new_level)
	power_level = clamp(new_level, LASER_POWER_MIN, LASER_POWER_MAX)

/// Returns status info for the combat console UI
/obj/machinery/ship_combat/laser_turret/proc/get_status()
	return list(
		"id" = turret_id,
		"name" = name,
		"power_level" = power_level,
		"damage" = round(get_effective_damage()),
		"cooldown" = round(get_effective_cooldown() / 10, 0.1),
		"power_per_shot" = round(get_power_per_shot()),
		"ready" = can_fire(),
		"cooldown_remaining" = COOLDOWN_FINISHED(src, fire_cooldown) ? 0 : round(COOLDOWN_TIMELEFT(src, fire_cooldown) / 10, 0.1),
	)

// ========== TOOL INTERACTIONS ==========

// Wrench to anchor/unanchor
/obj/machinery/ship_combat/laser_turret/wrench_act(mob/living/user, obj/item/tool)
	. = ITEM_INTERACT_BLOCKING
	default_unfasten_wrench(user, tool)
	return ITEM_INTERACT_SUCCESS

/obj/machinery/ship_combat/laser_turret/attackby(obj/item/W, mob/user, list/modifiers, list/attack_modifiers)
	// Multitool linking - store self in buffer
	if(istype(W, /obj/item/multitool))
		var/obj/item/multitool/tool = W
		// Store just this turret in the buffer (single item, not list)
		tool.buffer = src
		balloon_alert(user, "turret buffered")
		to_chat(user, span_notice("You buffer [src] to the multitool. Use on a combat console to link."))
		return TRUE

	// Standard deconstruction
	if(default_deconstruction_screwdriver(user, icon_state, icon_state, W))
		return
	if(default_deconstruction_crowbar(W))
		return
	return ..()

// ========== CIRCUIT BOARD ==========

/obj/item/circuitboard/machine/ship_combat/laser_turret
	name = "Laser Turret"
	greyscale_colors = CIRCUIT_COLOR_COMMAND
	build_path = /obj/machinery/ship_combat/laser_turret
	req_components = list(
		/datum/stock_part/micro_laser = 2,
		/datum/stock_part/capacitor = 1,
		/datum/stock_part/servo = 1,
	)
