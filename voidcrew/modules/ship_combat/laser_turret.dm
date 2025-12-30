// Ship Combat Laser Turret
// A machine that fires lasers at enemy ships
// Must be linked to a combat console via multitool
// Power level is adjustable via the console
// Primarily effective against shields
// Has internal power cell that charges from powernet

/obj/machinery/ship_combat/laser_turret
	name = "laser turret"
	desc = "A ship-mounted laser weapon system. Effective against shields. Link to a weapons system with a multitool and control power levels from there. Has an internal power cell that can be replaced."
	icon = 'icons/obj/weapons/turrets.dmi'
	icon_state = "standard_off"
	density = TRUE
	anchored = TRUE
	power_channel = AREA_USAGE_EQUIP
	circuit = /obj/item/circuitboard/machine/ship_combat/laser_turret
	/// How much power we draw from the grid to charge our cell per process tick
	idle_power_usage = 0
	active_power_usage = BASE_MACHINE_ACTIVE_CONSUMPTION * 2
	/// Turret health
	max_integrity = 200
	/// Breaks at 50% health
	integrity_failure = 0.5
	/// Armor - resistant to lasers since it's a laser turret
	armor_type = /datum/armor/ship_laser_turret

	/// Reference to our linked combat console
	var/datum/weakref/linked_console_ref
	/// Our unique ID for console linking
	var/turret_id
	/// Power level set by combat console (0.25 to 2.0)
	var/power_level = 1
	/// Calculated damage (from base + parts + power level)
	var/current_damage = LASER_DAMAGE_BASE
	/// Calculated cooldown multiplier (from parts, 0-1 range, lower = faster)
	var/cooldown_mult = 1
	/// Cooldown between shots
	COOLDOWN_DECLARE(fire_cooldown)
	/// Our internal power cell
	var/obj/item/stock_parts/power_store/cell/cell
	/// How much power we transfer from powernet to cell per second (affected by capacitor upgrades)
	var/charge_rate = LASER_CHARGE_RATE_BASE
	/// Whether we had enough power to fire last tick (for detecting power loss)
	var/had_power = FALSE
	/// Cached exterior check result (turrets don't move while anchored)
	var/cached_exterior_check
	/// Whether the exterior cache is valid
	var/exterior_cache_valid = FALSE

/obj/machinery/ship_combat/laser_turret/Initialize(mapload)
	. = ..()
	turret_id = "[rand(1000, 9999)]"
	name = "[initial(name)] ([turret_id])"
	RefreshParts()
	// Initialize power state based on cell
	had_power = cell && cell.charge >= get_power_per_shot()
	update_power_draw()
	// Try to auto-link to a combat console on the same ship after a short delay
	addtimer(CALLBACK(src, PROC_REF(attempt_auto_link)), 2 SECONDS)

/obj/machinery/ship_combat/laser_turret/Destroy()
	unlink_console()
	cell = null  // Cell is part of component_parts, will be handled by parent
	return ..()

/obj/machinery/ship_combat/laser_turret/process(seconds_per_tick)
	// Check for power state transitions
	var/has_power_now = cell && cell.charge >= get_power_per_shot()
	if(had_power && !has_power_now)
		// Lost power - play shutdown sound
		playsound(src, 'sound/items/xbow_lock.ogg', 50, TRUE)
		visible_message(span_warning("[src] powers down - insufficient charge."))
		update_appearance()
	else if(!had_power && has_power_now)
		// Gained power - play power up sound
		playsound(src, 'sound/items/eshield_recharge.ogg', 50, TRUE)
		update_appearance()
	had_power = has_power_now

	// Update power draw based on charging needs
	update_power_draw()

	// Charge our internal cell from the powernet
	if(!cell)
		return
	if(machine_stat & (BROKEN|NOPOWER))
		return
	if(cell.charge >= cell.maxcharge)
		return  // Already full

	// Calculate how much to charge this tick
	// Power is being drawn automatically via update_mode_power_usage
	var/charge_amount = charge_rate * seconds_per_tick
	cell.charge = min(cell.charge + charge_amount, cell.maxcharge)

/obj/machinery/ship_combat/laser_turret/RefreshParts()
	. = ..()

	// Reset to base values
	current_damage = LASER_DAMAGE_BASE
	charge_rate = LASER_CHARGE_RATE_BASE
	cooldown_mult = 1

	// Find the power cell from component parts
	cell = null
	for(var/obj/item/stock_parts/power_store/cell/found_cell in component_parts)
		cell = found_cell
		break

	// Apply stock part modifiers
	// Each part tier above 1 adds a bonus
	for(var/datum/stock_part/micro_laser/laser in component_parts)
		current_damage += LASER_DAMAGE_BASE * LASER_MICROLASER_DAMAGE_MULT * (laser.tier - 1)

	for(var/datum/stock_part/capacitor/cap in component_parts)
		charge_rate += LASER_CHARGE_RATE_BASE * LASER_CAPACITOR_CHARGE_MULT * (cap.tier - 1)

	for(var/datum/stock_part/servo/servo in component_parts)
		cooldown_mult -= LASER_SERVO_COOLDOWN_MULT * (servo.tier - 1)

	// Clamp values
	cooldown_mult = max(cooldown_mult, 0.3)

	// Update power draw since charge rate may have changed
	update_power_draw()

/obj/machinery/ship_combat/laser_turret/examine(mob/user)
	. = ..()
	. += span_notice("Turret ID: [turret_id]")
	. += span_notice("Power Level: [round(power_level * 100)]%")
	. += span_notice("Damage: [round(get_effective_damage())]")
	. += span_notice("Cooldown: [round(get_effective_cooldown() / 10, 0.1)]s")
	. += span_notice("Power per Shot: [round(get_power_per_shot())]")
	. += span_notice("Charge Rate: [round(charge_rate)]/s")
	if(cell)
		. += span_notice("Cell Charge: [round(cell.charge)]/[cell.maxcharge] ([round(cell.percent())]%)")
	else
		. += span_warning("No power cell installed!")
	if(can_fire())
		. += span_notice("Status: READY")
	else if(!is_on_exterior())
		. += span_warning("Status: NOT ON EXTERIOR - Must be adjacent to outside of ship!")
	else if(!COOLDOWN_FINISHED(src, fire_cooldown))
		. += span_warning("Recharging: [round(COOLDOWN_TIMELEFT(src, fire_cooldown) / 10, 0.1)]s remaining")
	else if(!cell || cell.charge < get_power_per_shot())
		. += span_warning("Status: INSUFFICIENT POWER")
	else if(machine_stat & NOPOWER)
		. += span_warning("Status: NO POWER")
	else if(!anchored)
		. += span_warning("Status: NOT ANCHORED")
	var/obj/machinery/computer/camera_advanced/ship_combat/linked_console = linked_console_ref?.resolve()
	if(linked_console)
		. += span_notice("Linked to: [linked_console]")
	else
		. += span_warning("Not linked to a weapons system. Use a multitool to link.")

/obj/machinery/ship_combat/laser_turret/update_icon_state()
	. = ..()
	if(machine_stat & (BROKEN))
		icon_state = "standard_broken"
	else if(machine_stat & (NOPOWER))
		icon_state = "standard_off"
	else if(!cell || cell.charge < get_power_per_shot())
		icon_state = "standard_off"
	else if(!COOLDOWN_FINISHED(src, fire_cooldown))
		icon_state = "standard_lethal"
	else
		icon_state = "standard_stun"

// ========== POWER CALCULATIONS ==========

/// Returns the effective damage based on power level and parts
/obj/machinery/ship_combat/laser_turret/proc/get_effective_damage()
	return current_damage * power_level

/// Returns the power draw per shot based on power level
/obj/machinery/ship_combat/laser_turret/proc/get_power_per_shot()
	return LASER_POWER_BASE * power_level

/// Returns the cooldown time based on parts
/obj/machinery/ship_combat/laser_turret/proc/get_effective_cooldown()
	return LASER_COOLDOWN_BASE * cooldown_mult

/// Returns the current cell charge
/obj/machinery/ship_combat/laser_turret/proc/get_cell_charge()
	return cell?.charge || 0

/// Returns the max cell charge
/obj/machinery/ship_combat/laser_turret/proc/get_cell_max()
	return cell?.maxcharge || 0

/// Updates the machine's power draw based on charging state
/obj/machinery/ship_combat/laser_turret/proc/update_power_draw()
	// Determine if we need to charge
	var/needs_charging = cell && cell.charge < cell.maxcharge && !(machine_stat & BROKEN)

	if(needs_charging)
		update_mode_power_usage(ACTIVE_POWER_USE, charge_rate)
		update_use_power(ACTIVE_POWER_USE)
	else
		update_mode_power_usage(ACTIVE_POWER_USE, 0)
		update_use_power(IDLE_POWER_USE)

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
	// SSovermap must be initialized before we can search for ships
	if(!SSovermap?.initialized)
		return

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
			// Check if console is at max turrets
			if(length(console.linked_turrets) >= LASER_MAX_TURRETS)
				continue
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

/// Checks if this weapon is on the exterior of the ship (adjacent to non-shuttle-area tile)
/// Weapons must be on the exterior to fire - they need line of sight to space/outside
/// Result is cached while anchored since turrets don't move
/obj/machinery/ship_combat/laser_turret/proc/is_on_exterior()
	// Return cached result if valid (only valid while anchored)
	if(exterior_cache_valid && anchored)
		return cached_exterior_check

	var/turf/our_turf = get_turf(src)
	if(!our_turf)
		return FALSE

	// Get the shuttle areas for our ship
	var/area/our_area = get_area(src)
	var/list/shuttle_areas
	for(var/obj/structure/overmap/ship/S in SSovermap.simulated_ships)
		if(!S.shuttle)
			continue
		if(our_area in S.shuttle.shuttle_areas)
			shuttle_areas = S.shuttle.shuttle_areas
			break

	// Check all adjacent tiles (including diagonals)
	var/result = FALSE
	for(var/turf/T in range(1, our_turf))
		if(T == our_turf)
			continue
		var/area/tile_area = get_area(T)
		// If adjacent tile is not in shuttle areas, we're on exterior
		if(!tile_area || !(tile_area in shuttle_areas))
			result = TRUE
			break

	// Cache the result
	cached_exterior_check = result
	exterior_cache_valid = TRUE

	return result

/// Invalidates the exterior check cache (call when turret is moved/anchored)
/obj/machinery/ship_combat/laser_turret/proc/invalidate_exterior_cache()
	exterior_cache_valid = FALSE

/// Checks if the turret can fire
/obj/machinery/ship_combat/laser_turret/proc/can_fire()
	if(machine_stat & (BROKEN|NOPOWER))
		return FALSE
	if(!anchored)
		return FALSE
	if(!COOLDOWN_FINISHED(src, fire_cooldown))
		return FALSE
	if(!cell)
		return FALSE
	if(cell.charge < get_power_per_shot())
		return FALSE
	if(!is_on_exterior())
		return FALSE
	return TRUE

/// Fires the laser at the target turf
/// Returns TRUE if fired successfully
/// multi_beam: If TRUE, uses multi-beam sprites (for combined turret fire)
/// override_damage: If provided, uses this damage value instead of calculating from turret stats
/// approach_direction: If provided, forces the laser to come from this direction instead of auto-calculating
/obj/machinery/ship_combat/laser_turret/proc/fire(turf/target, obj/structure/overmap/ship/target_ship, obj/structure/overmap/ship/source_ship, mob/user, multi_beam = FALSE, override_damage = 0, approach_direction = null)
	if(!can_fire())
		return FALSE

	if(!target)
		if(user)
			to_chat(user, span_warning("No target selected!"))
		return FALSE

	// Use power from internal cell
	var/power_needed = get_power_per_shot()
	if(!cell || cell.charge < power_needed)
		if(user)
			to_chat(user, span_warning("[src] doesn't have enough power! ([round(cell?.charge || 0)]/[round(power_needed)] required)"))
		return FALSE

	// Drain the cell
	cell.use(power_needed)

	// Start cooldown
	COOLDOWN_START(src, fire_cooldown, get_effective_cooldown())

	// Calculate damage - use override if provided (for combined fire)
	var/damage = override_damage > 0 ? override_damage : get_effective_damage()

	// Create the laser beam effect - it will handle hitting shields or the target
	new /obj/effect/ship_laser_beam(
		get_turf(src),
		target,
		target_ship,
		source_ship,
		damage,
		power_level,
		multi_beam,
		approach_direction,
	)

	// Create visual beam on the overmap between ships (only if not on same tile)
	if(source_ship && target_ship && get_turf(source_ship) != get_turf(target_ship))
		source_ship.Beam(
			target_ship,
			icon_state = "beam_omni",
			icon = 'icons/obj/weapons/guns/projectiles_tracer.dmi',
			emissive = TRUE,
			time = 0.5 SECONDS,
		)

	// Create visual effects at the turret (purely cosmetic, visible to crew)
	new /obj/effect/temp_visual/turret_muzzle_flash(get_turf(src), dir)
	new /obj/effect/temp_visual/turret_laser_visual(get_turf(src), dir, multi_beam)

	// Play sound (extrarange so it's audible, pressure_affected = FALSE for space)
	playsound(src, 'sound/items/weapons/beam_sniper.ogg', 100, TRUE, extrarange = 50, pressure_affected = FALSE)

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
	// Calculate upgrade tiers from stock parts
	var/capacitor_tier = 0
	var/laser_tier = 0
	var/servo_tier = 0
	for(var/datum/stock_part/capacitor/cap in component_parts)
		capacitor_tier += cap.tier
	for(var/datum/stock_part/micro_laser/laser in component_parts)
		laser_tier += laser.tier
	for(var/datum/stock_part/servo/servo in component_parts)
		servo_tier += servo.tier

	return list(
		"id" = turret_id,
		"name" = name,
		"power_level" = power_level,
		"damage" = round(get_effective_damage()),
		"cooldown" = round(get_effective_cooldown() / 10, 0.1),
		"power_per_shot" = round(get_power_per_shot()),
		"ready" = can_fire(),
		"on_exterior" = is_on_exterior(),
		"cooldown_remaining" = COOLDOWN_FINISHED(src, fire_cooldown) ? 0 : round(COOLDOWN_TIMELEFT(src, fire_cooldown) / 10, 0.1),
		"cell_charge" = round(cell?.charge || 0),
		"cell_max" = round(cell?.maxcharge || 0),
		"upgrades" = list(
			"capacitor_tier" = capacitor_tier,
			"laser_tier" = laser_tier,
			"servo_tier" = servo_tier,
		),
	)

// ========== TOOL INTERACTIONS ==========

// Wrench to anchor/unanchor
/obj/machinery/ship_combat/laser_turret/wrench_act(mob/living/user, obj/item/tool)
	. = ITEM_INTERACT_BLOCKING
	default_unfasten_wrench(user, tool)
	invalidate_exterior_cache()  // Position may have changed
	return ITEM_INTERACT_SUCCESS

// Alt+click to rotate when unwrenched
/obj/machinery/ship_combat/laser_turret/click_alt(mob/user)
	if(!user.can_perform_action(src, NEED_HANDS))
		return CLICK_ACTION_BLOCKING
	if(anchored)
		to_chat(user, span_warning("Unwrench [src] first to rotate it!"))
		return CLICK_ACTION_BLOCKING
	// Rotate through cardinal directions
	setDir(turn(dir, -90))
	balloon_alert(user, "rotated [dir2text(dir)]")
	return CLICK_ACTION_SUCCESS

/obj/machinery/ship_combat/laser_turret/attackby(obj/item/W, mob/user, list/modifiers, list/attack_modifiers)
	// Multitool linking - store self in buffer
	if(istype(W, /obj/item/multitool))
		var/obj/item/multitool/tool = W
		// Store just this turret in the buffer (single item, not list)
		tool.buffer = src
		balloon_alert(user, "turret buffered")
		to_chat(user, span_notice("You buffer [src] to the multitool. Use on a weapons system to link."))
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
		/obj/item/stock_parts/power_store/cell = 1,
	)

// ========== ARMOR ==========

/datum/armor/ship_laser_turret
	melee = 30
	bullet = 30
	laser = 50
	energy = 30
	bomb = 20
	fire = 80
	acid = 50

// ========== DAMAGE HANDLING ==========

/obj/machinery/ship_combat/laser_turret/atom_break(damage_flag)
	. = ..()
	if(.)
		visible_message(span_danger("[src] sparks and breaks down!"))
		playsound(src, 'sound/effects/sparks/sparks1.ogg', 70, TRUE)
		do_sparks(5, TRUE, src)
		update_appearance()

/obj/machinery/ship_combat/laser_turret/emp_act(severity)
	. = ..()
	if(. & EMP_PROTECT_SELF)
		return
	if(machine_stat & BROKEN)
		return

	// Visual feedback
	visible_message(span_danger("[src] crackles and sparks from the EMP!"))
	playsound(src, 'sound/effects/sparks/sparks1.ogg', 50, TRUE)
	do_sparks(3, TRUE, src)

	// Drain cell charge based on severity (heavy EMP = more drain)
	if(cell)
		var/drain_amount = cell.maxcharge * (0.5 / severity)  // 50% drain for severity 1, 25% for severity 2
		cell.use(drain_amount)

	// Disable turret temporarily - longer for stronger EMP
	var/disable_time = rand(5 SECONDS, 15 SECONDS) / severity
	COOLDOWN_START(src, fire_cooldown, disable_time)

	update_appearance()
