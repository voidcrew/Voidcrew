// Ship Cloaking Device
// Hides the ship's icon on the overmap when active
// Automatically decloaks when weapons are fired or a hostile acquires weapons lock

/obj/machinery/ship_combat/cloak_device
	name = "cloaking device"
	desc = "An advanced cloaking device that hides the ship from detection on the overmap. Power scales with ship mass. Will automatically deactivate when weapons are fired, a hostile acquires weapons lock, the duration expires, or power runs out."
	icon = 'icons/obj/machines/research.dmi'
	icon_state = "explosive_compressor"
	density = TRUE
	anchored = TRUE
	power_channel = AREA_USAGE_EQUIP
	circuit = /obj/item/circuitboard/machine/ship_combat/cloak_device
	/// No power draw when not cloaking - active draw is set dynamically via get_power_draw()
	idle_power_usage = 0

	/// Is the cloak currently active?
	var/cloak_active = FALSE
	/// Reference to our ship
	var/obj/structure/overmap/ship/linked_ship
	/// Cooldown before we can re-cloak after decloaking
	COOLDOWN_DECLARE(recloak_cooldown)
	/// How long before we can recloak (base 1 minute, reduced by micro-lasers)
	var/recloak_delay = 1 MINUTES
	/// The invisibility ID we use
	var/cloak_id = "ship_cloak_device"
	/// Base duration of cloak in deciseconds (30 seconds base)
	var/base_cloak_duration = 30 SECONDS
	/// Extra duration per capacitor tier (15 seconds per tier)
	var/duration_per_tier = 15 SECONDS
	/// Current maximum cloak duration (calculated from parts)
	var/max_cloak_duration = 30 SECONDS
	/// When the cloak will expire
	var/cloak_expire_time = 0
	/// Timer ID for cloak expiration
	var/cloak_timer_id
	/// Cached ship mass for power calculations
	var/cached_ship_mass = 100
	/// Calculated power efficiency multiplier (from parts, 0-1 range, lower = more efficient)
	var/power_efficiency = 1

/obj/machinery/ship_combat/cloak_device/Initialize(mapload)
	. = ..()
	// Try to find our ship on init
	attempt_ship_connection()

/obj/machinery/ship_combat/cloak_device/Destroy()
	if(cloak_timer_id)
		deltimer(cloak_timer_id)
		cloak_timer_id = null
	if(cloak_active)
		deactivate_cloak(silent = TRUE)
	unlink_ship()
	return ..()

/obj/machinery/ship_combat/cloak_device/RefreshParts()
	. = ..()

	// Reset to base values
	power_efficiency = 1
	recloak_delay = initial(recloak_delay)

	var/capacitor_rating = 0
	for(var/datum/stock_part/capacitor/cap in component_parts)
		capacitor_rating += cap.tier

	// Scanning modules improve power efficiency (15% reduction per tier above 1)
	for(var/datum/stock_part/scanning_module/scanner in component_parts)
		power_efficiency -= 0.15 * (scanner.tier - 1)

	// Micro-lasers reduce recloak cooldown (5 seconds per tier above 1)
	// 2x T1: 60s, 2x T4: 30s
	for(var/datum/stock_part/micro_laser/laser in component_parts)
		recloak_delay -= 5 SECONDS * (laser.tier - 1)

	// Clamp values
	power_efficiency = max(power_efficiency, 0.1)
	recloak_delay = max(recloak_delay, 30 SECONDS)

	// Base duration + extra per capacitor tier
	// With 2 T1 capacitors: 30s + (2 * 15s) = 60s
	// With 2 T4 capacitors: 30s + (8 * 15s) = 150s (2.5 minutes)
	max_cloak_duration = base_cloak_duration + (capacitor_rating * duration_per_tier)

/obj/machinery/ship_combat/cloak_device/examine(mob/user)
	. = ..()
	if(cloak_active)
		. += span_notice("Status: [span_green("CLOAKED")]")
		. += span_notice("Power draw: [display_power(get_power_draw())]")
		var/time_remaining = cloak_expire_time - world.time
		if(time_remaining > 0)
			. += span_notice("Time remaining: [DisplayTimeText(time_remaining)]")
	else
		. += span_warning("Status: [span_red("VISIBLE")]")
	. += span_notice("Maximum cloak duration: [DisplayTimeText(max_cloak_duration)]")
	. += span_notice("Power required: [display_power(get_power_draw())]")
	. += span_notice("Efficiency: [round((1 - power_efficiency) * 100)]% power reduction")
	if(!COOLDOWN_FINISHED(src, recloak_cooldown))
		. += span_warning("Recloak available in: [DisplayTimeText(COOLDOWN_TIMELEFT(src, recloak_cooldown))]")
	if(linked_ship)
		. += span_notice("Linked to: [linked_ship.display_name]")
	else
		. += span_warning("Not linked to any ship.")

// ========== SHIP CONNECTION ==========

/obj/machinery/ship_combat/cloak_device/proc/attempt_ship_connection()
	var/area/ship_area = get_area(src)
	if(!ship_area)
		return FALSE

	for(var/obj/structure/overmap/ship/S in SSovermap.simulated_ships)
		if(!S.shuttle)
			continue
		for(var/area/A in S.shuttle.shuttle_areas)
			if(A == ship_area)
				link_ship(S)
				return TRUE
	return FALSE

/obj/machinery/ship_combat/cloak_device/proc/link_ship(obj/structure/overmap/ship/ship)
	if(linked_ship)
		unlink_ship()
	linked_ship = ship
	update_ship_mass()
	RegisterSignal(linked_ship, COMSIG_SHIP_WEAPON_FIRED, PROC_REF(on_weapon_fired))
	RegisterSignal(linked_ship, COMSIG_SHIP_HAZARD_TRIGGERED, PROC_REF(on_hazard_triggered))
	RegisterSignal(linked_ship, COMSIG_SHIP_WEAPONS_LOCKED, PROC_REF(on_weapons_locked))
	RegisterSignal(linked_ship, COMSIG_QDELETING, PROC_REF(on_ship_deleted))

/obj/machinery/ship_combat/cloak_device/proc/unlink_ship()
	if(linked_ship)
		UnregisterSignal(linked_ship, list(COMSIG_SHIP_WEAPON_FIRED, COMSIG_SHIP_HAZARD_TRIGGERED, COMSIG_SHIP_WEAPONS_LOCKED, COMSIG_QDELETING))
		linked_ship = null

/obj/machinery/ship_combat/cloak_device/proc/on_ship_deleted(datum/source)
	SIGNAL_HANDLER
	if(cloak_active)
		deactivate_cloak(silent = TRUE)
	linked_ship = null

// ========== POWER CALCULATIONS ==========

/// Updates cached ship mass from the linked ship
/obj/machinery/ship_combat/cloak_device/proc/update_ship_mass()
	if(linked_ship)
		cached_ship_mass = max(linked_ship.mass, 50)  // Minimum 50 mass
	else
		cached_ship_mass = 100  // Default

/// Returns the current power draw based on ship mass and efficiency
/// Formula: (BASE_COST + mass * POWER_PER_MASS) * efficiency
/obj/machinery/ship_combat/cloak_device/proc/get_power_draw()
	return (SHIP_CLOAK_BASE_POWER_COST + cached_ship_mass * SHIP_CLOAK_POWER_PER_MASS) * power_efficiency

// ========== CLOAK ACTIVATION ==========

/obj/machinery/ship_combat/cloak_device/attack_hand(mob/user, list/modifiers)
	. = ..()
	if(.)
		return

	if(!linked_ship)
		if(!attempt_ship_connection())
			to_chat(user, span_warning("Unable to connect to ship systems!"))
			return

	if(cloak_active)
		deactivate_cloak()
		balloon_alert(user, "cloak deactivated")
	else
		if(activate_cloak(user))
			balloon_alert(user, "cloak activated")
		else
			balloon_alert(user, "cannot activate")

/// Activates the cloaking device
/obj/machinery/ship_combat/cloak_device/proc/activate_cloak(mob/user)
	if(cloak_active)
		return FALSE

	if(!linked_ship)
		if(user)
			to_chat(user, span_warning("Not connected to ship!"))
		return FALSE

	if(machine_stat & (BROKEN|NOPOWER))
		if(user)
			to_chat(user, span_warning("[src] has no power!"))
		return FALSE

	var/power_needed = get_power_draw()

	// Check if there's enough power available
	if(available_energy() < power_needed)
		if(user)
			to_chat(user, span_warning("Insufficient power! Need [display_power(power_needed)]."))
		return FALSE

	if(!COOLDOWN_FINISHED(src, recloak_cooldown))
		if(user)
			to_chat(user, span_warning("Cloak recharging! Available in [DisplayTimeText(COOLDOWN_TIMELEFT(src, recloak_cooldown))]."))
		return FALSE

	cloak_active = TRUE

	// Hide the ship on the overmap
	linked_ship.SetInvisibility(INVISIBILITY_ABSTRACT, cloak_id, 100)

	// Start high power drain - must use update_mode_power_usage to properly register with APC
	update_mode_power_usage(ACTIVE_POWER_USE, power_needed)
	update_use_power(ACTIVE_POWER_USE)

	// Start cloak duration timer
	cloak_expire_time = world.time + max_cloak_duration
	cloak_timer_id = addtimer(CALLBACK(src, PROC_REF(on_cloak_expired)), max_cloak_duration, TIMER_STOPPABLE)

	// Visual and audio feedback
	visible_message(span_notice("[src] hums to life as the cloaking field activates."))
	playsound(src, 'sound/effects/EMPulse.ogg', 50, TRUE)

	// Send signal
	SEND_SIGNAL(linked_ship, COMSIG_SHIP_CLOAK_CHANGED, TRUE)

	update_appearance()
	return TRUE

/// Deactivates the cloaking device
/obj/machinery/ship_combat/cloak_device/proc/deactivate_cloak(silent = FALSE, forced = FALSE)
	if(!cloak_active)
		return FALSE

	cloak_active = FALSE

	// Cancel the expiration timer
	if(cloak_timer_id)
		deltimer(cloak_timer_id)
		cloak_timer_id = null
	cloak_expire_time = 0

	// Show the ship on the overmap
	if(linked_ship)
		linked_ship.RemoveInvisibility(cloak_id)
		SEND_SIGNAL(linked_ship, COMSIG_SHIP_CLOAK_CHANGED, FALSE)

	// Stop high power drain - reset to idle
	update_mode_power_usage(ACTIVE_POWER_USE, 0)
	update_use_power(IDLE_POWER_USE)

	// Start recloak cooldown
	COOLDOWN_START(src, recloak_cooldown, recloak_delay)

	if(!silent)
		visible_message(span_warning("[src] powers down as the cloaking field collapses!"))
		playsound(src, 'sound/machines/buzz/buzz-sigh.ogg', 50, TRUE)

	update_appearance()
	return TRUE

// ========== WEAPON FIRE DETECTION ==========

/obj/machinery/ship_combat/cloak_device/proc/on_weapon_fired(datum/source)
	SIGNAL_HANDLER
	if(cloak_active)
		// Weapons fire breaks cloak!
		INVOKE_ASYNC(src, PROC_REF(emergency_decloak), "Weapons discharge detected")

// ========== WEAPONS LOCK DETECTION ==========

/obj/machinery/ship_combat/cloak_device/proc/on_weapons_locked(datum/source, obj/structure/overmap/ship/attacker)
	SIGNAL_HANDLER
	if(cloak_active)
		// Being locked on breaks cloak!
		INVOKE_ASYNC(src, PROC_REF(emergency_decloak), "Hostile targeting lock detected")

// ========== HAZARD DETECTION ==========

/obj/machinery/ship_combat/cloak_device/proc/on_hazard_triggered(datum/source, obj/structure/overmap/event/hazard)
	SIGNAL_HANDLER
	if(cloak_active)
		// Entering a hazard breaks cloak!
		INVOKE_ASYNC(src, PROC_REF(emergency_decloak), "Hazard interference detected")

/obj/machinery/ship_combat/cloak_device/proc/emergency_decloak(reason = "Unknown interference")
	visible_message(span_danger("[src] overloads! [reason] - emergency decloak!"))
	deactivate_cloak()

// ========== DURATION EXPIRATION ==========

/// Called when the cloak duration expires
/obj/machinery/ship_combat/cloak_device/proc/on_cloak_expired()
	cloak_timer_id = null
	if(!cloak_active)
		return
	visible_message(span_warning("[src] powers down as the cloaking field destabilizes! Duration limit reached."))
	playsound(src, 'sound/machines/buzz/buzz-sigh.ogg', 50, TRUE)
	deactivate_cloak(silent = TRUE) // Already gave a message above

// ========== POWER HANDLING ==========

/obj/machinery/ship_combat/cloak_device/process(seconds_per_tick)
	if(!cloak_active)
		return

	// Check if we still have power
	if(machine_stat & NOPOWER)
		visible_message(span_danger("[src] loses power! Cloaking field failing!"))
		deactivate_cloak()
		return

// ========== APPEARANCE ==========

/obj/machinery/ship_combat/cloak_device/update_overlays()
	. = ..()
	if(cloak_active)
		. += mutable_appearance('icons/effects/effects.dmi', "electricity")
		. += emissive_appearance('icons/effects/effects.dmi', "electricity", src)

// ========== TOOL INTERACTIONS ==========

/obj/machinery/ship_combat/cloak_device/attackby(obj/item/W, mob/user, params)
	// Standard deconstruction
	if(default_deconstruction_screwdriver(user, icon_state, icon_state, W))
		return
	if(default_deconstruction_crowbar(W))
		return
	return ..()

/obj/machinery/ship_combat/cloak_device/wrench_act(mob/living/user, obj/item/tool)
	. = ITEM_INTERACT_BLOCKING
	if(cloak_active)
		to_chat(user, span_warning("Deactivate the cloak first!"))
		return
	default_unfasten_wrench(user, tool)
	return ITEM_INTERACT_SUCCESS

// ========== CIRCUIT BOARD ==========

/obj/item/circuitboard/machine/ship_combat/cloak_device
	name = "Cloaking Device"
	greyscale_colors = CIRCUIT_COLOR_SCIENCE
	build_path = /obj/machinery/ship_combat/cloak_device
	req_components = list(
		/datum/stock_part/capacitor = 2,
		/datum/stock_part/micro_laser = 2,
		/datum/stock_part/scanning_module = 1,
	)
