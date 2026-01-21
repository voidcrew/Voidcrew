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
	var/datum/weakref/linked_ship_ref
	/// Cooldown before we can re-cloak after decloaking
	COOLDOWN_DECLARE(recloak_cooldown)
	/// How long before we can recloak (base 1 minute, reduced by micro-lasers)
	var/recloak_delay = SHIP_CLOAK_RECLOAK_DELAY
	/// The invisibility ID we use
	var/cloak_id = "ship_cloak_device"
	/// Base duration of cloak in deciseconds (30 seconds base)
	var/base_cloak_duration = SHIP_CLOAK_BASE_DURATION
	/// Extra duration per capacitor tier (15 seconds per tier)
	var/duration_per_tier = SHIP_CLOAK_DURATION_PER_TIER
	/// Current maximum cloak duration (calculated from parts)
	var/max_cloak_duration = SHIP_CLOAK_BASE_DURATION
	/// When the cloak will expire
	var/cloak_expire_time = 0
	/// Timer ID for cloak expiration
	var/cloak_timer_id
	/// Cached ship mass for power calculations
	var/cached_ship_mass = 100
	/// Calculated power efficiency multiplier (from parts, 0-1 range, lower = more efficient)
	var/power_efficiency = 1
	/// Real-time positional sound when cloak is active
	var/datum/realtime_positional_sound/cloak_sound
	/// Whether this device failed to link due to duplicate on ship
	var/link_failed_duplicate = FALSE
	/// Reference to linked combat console
	var/datum/weakref/linked_console_ref

/obj/machinery/ship_combat/cloak_device/Initialize(mapload)
	. = ..()
	cloak_sound = new(src, 'voidcrew/sound/machines/cloaking/on.ogg', 7, 7)

/obj/machinery/ship_combat/cloak_device/LateInitialize()
	. = ..()
	// Try to auto-link after a short delay
	addtimer(CALLBACK(src, PROC_REF(attempt_auto_link)), 2 SECONDS)

/obj/machinery/ship_combat/cloak_device/Destroy()
	if(cloak_timer_id)
		deltimer(cloak_timer_id)
		cloak_timer_id = null
	if(cloak_active)
		deactivate_cloak(silent = TRUE)
	QDEL_NULL(cloak_sound)
	unlink_console()
	unlink_ship()
	return ..()

/obj/machinery/ship_combat/cloak_device/RefreshParts()
	. = ..()

	// Try to auto-link if not already connected (handles mid-round construction)
	if(!linked_ship_ref?.resolve() || !linked_console_ref?.resolve())
		attempt_auto_link()

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
	recloak_delay = max(recloak_delay, SHIP_CLOAK_MIN_RECLOAK_DELAY)

	// Base duration + extra per capacitor tier
	// With 2 T1 capacitors: 30s + (2 * 15s) = 60s
	// With 2 T4 capacitors: 30s + (8 * 15s) = 150s (2.5 minutes)
	max_cloak_duration = base_cloak_duration + (capacitor_rating * duration_per_tier)

/obj/machinery/ship_combat/cloak_device/examine(mob/user)
	. = ..()
	if(link_failed_duplicate)
		. += span_boldwarning("OFFLINE: Another cloaking device is already installed on this ship!")
		. += span_warning("Only one cloaking device can operate per ship. Remove the other device first.")
		return
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
	var/obj/structure/overmap/ship/linked_ship = linked_ship_ref?.resolve()
	if(linked_ship)
		. += span_notice("Linked to: [linked_ship.display_name]")
	else
		. += span_warning("Not linked to any ship.")
	var/obj/machinery/computer/camera_advanced/ship_combat/linked_console = linked_console_ref?.resolve()
	if(linked_console)
		. += span_notice("Linked to: [linked_console]")
	else
		. += span_warning("Not linked to a weapons console. Use a multitool to link, or wait for auto-link.")

// ========== SHIP CONNECTION ==========

/obj/machinery/ship_combat/cloak_device/proc/attempt_ship_connection()
	var/obj/structure/overmap/ship/ship = get_ship_from_atom(src)
	if(!ship)
		return FALSE

	if(!link_ship(ship))
		// Failed to link - likely a duplicate exists
		link_failed_duplicate = TRUE
		return FALSE
	return TRUE

/// Checks if a cloaking device already exists on the given ship
/obj/machinery/ship_combat/cloak_device/proc/find_existing_cloak_device(obj/structure/overmap/ship/ship)
	if(!ship?.shuttle?.shuttle_areas)
		return null
	for(var/area/ship_area in ship.shuttle.shuttle_areas)
		for(var/obj/machinery/ship_combat/cloak_device/existing in ship_area)
			if(existing != src && !QDELETED(existing) && !existing.link_failed_duplicate)
				return existing
	return null

/obj/machinery/ship_combat/cloak_device/proc/link_ship(obj/structure/overmap/ship/ship)
	if(linked_ship_ref?.resolve())
		unlink_ship()

	// Check if there's already a cloaking device on this ship
	if(ship.linked_cloak_device && ship.linked_cloak_device != src)
		return FALSE

	linked_ship_ref = WEAKREF(ship)
	ship.linked_cloak_device = src
	link_failed_duplicate = FALSE
	update_ship_mass()
	RegisterSignal(ship, COMSIG_SHIP_WEAPON_FIRED, PROC_REF(on_weapon_fired))
	RegisterSignal(ship, COMSIG_SHIP_HAZARD_TRIGGERED, PROC_REF(on_hazard_triggered))
	RegisterSignal(ship, COMSIG_SHIP_WEAPONS_LOCKED, PROC_REF(on_weapons_locked))
	RegisterSignal(ship, COMSIG_QDELETING, PROC_REF(on_ship_deleted))
	return TRUE

/obj/machinery/ship_combat/cloak_device/proc/unlink_ship()
	var/obj/structure/overmap/ship/linked_ship = linked_ship_ref?.resolve()
	if(linked_ship)
		UnregisterSignal(linked_ship, list(COMSIG_SHIP_WEAPON_FIRED, COMSIG_SHIP_HAZARD_TRIGGERED, COMSIG_SHIP_WEAPONS_LOCKED, COMSIG_QDELETING))
		if(linked_ship.linked_cloak_device == src)
			linked_ship.linked_cloak_device = null
	linked_ship_ref = null

/// Links this device to a combat console
/obj/machinery/ship_combat/cloak_device/proc/link_console(obj/machinery/computer/camera_advanced/ship_combat/console)
	if(!console)
		return FALSE
	unlink_console()
	linked_console_ref = WEAKREF(console)
	return TRUE

/// Unlinks this device from a combat console
/obj/machinery/ship_combat/cloak_device/proc/unlink_console()
	var/obj/machinery/computer/camera_advanced/ship_combat/console = linked_console_ref?.resolve()
	if(console)
		console.linked_cloak_ref = null
	linked_console_ref = null

/// Attempts to auto-link to a combat console on the same ship
/obj/machinery/ship_combat/cloak_device/proc/attempt_auto_link()
	// Already linked to console
	if(linked_console_ref?.resolve())
		return

	// First ensure we're connected to a ship
	var/obj/structure/overmap/ship/linked_ship = linked_ship_ref?.resolve()
	if(!linked_ship)
		attempt_ship_connection()

	linked_ship = linked_ship_ref?.resolve()
	if(!linked_ship)
		return

	// Find a combat console on this ship
	for(var/area/ship_area in linked_ship.shuttle.shuttle_areas)
		for(var/obj/machinery/computer/camera_advanced/ship_combat/console in ship_area)
			// Check if console already has a cloak device
			if(console.linked_cloak_ref?.resolve())
				continue
			// Found one - link to it
			if(link_console(console))
				console.linked_cloak_ref = WEAKREF(src)
				return

/obj/machinery/ship_combat/cloak_device/proc/on_ship_deleted(datum/source)
	SIGNAL_HANDLER
	if(cloak_active)
		deactivate_cloak(silent = TRUE)
	linked_ship_ref = null

// ========== POWER CALCULATIONS ==========

/// Updates cached ship mass from the linked ship
/obj/machinery/ship_combat/cloak_device/proc/update_ship_mass()
	var/obj/structure/overmap/ship/linked_ship = linked_ship_ref?.resolve()
	if(linked_ship)
		cached_ship_mass = max(linked_ship.mass, 50)  // Minimum 50 mass
	else
		cached_ship_mass = 100  // Default

/// Returns the current power draw based on ship mass and efficiency
/// Formula: (BASE_COST + mass * POWER_PER_MASS) * efficiency
/obj/machinery/ship_combat/cloak_device/proc/get_power_draw()
	return (SHIP_CLOAK_BASE_POWER_COST + cached_ship_mass * SHIP_CLOAK_POWER_PER_MASS) * power_efficiency

// ========== CLOAK ACTIVATION ==========

/// Returns TRUE if the cloak can be activated right now
/obj/machinery/ship_combat/cloak_device/proc/can_activate_cloak()
	if(cloak_active)
		return FALSE
	if(link_failed_duplicate)
		return FALSE
	var/obj/structure/overmap/ship/linked_ship = linked_ship_ref?.resolve()
	if(!linked_ship)
		return FALSE
	if(machine_stat & (BROKEN|NOPOWER))
		return FALSE
	if(available_energy() < get_power_draw())
		return FALSE
	if(!COOLDOWN_FINISHED(src, recloak_cooldown))
		return FALSE
	if(linked_ship.is_interdicted)
		return FALSE
	if(length(linked_ship.locked_on_by))
		return FALSE
	return TRUE

/obj/machinery/ship_combat/cloak_device/attack_hand(mob/user, list/modifiers)
	. = ..()
	if(.)
		return

	// Cloak device must be controlled from the weapons system console
	to_chat(user, span_notice("The cloaking device must be controlled from the weapons system console. Link it with a multitool."))
	balloon_alert(user, "use console")

/// Activates the cloaking device
/obj/machinery/ship_combat/cloak_device/proc/activate_cloak(mob/user)
	if(cloak_active)
		if(user)
			to_chat(user, span_warning("The cloaking device is already active!"))
		return FALSE

	if(link_failed_duplicate)
		if(user)
			to_chat(user, span_warning("This cloaking device is offline! Another cloaking device is already installed on this ship."))
		return FALSE

	var/obj/structure/overmap/ship/linked_ship = linked_ship_ref?.resolve()
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

	// Cannot cloak while being interdicted
	if(linked_ship.is_interdicted)
		if(user)
			to_chat(user, span_warning("Cannot activate cloaking device while interdicted!"))
		playsound(src, 'sound/machines/buzz/buzz-sigh.ogg', 40, TRUE)
		return FALSE

	// Cloak and shields are mutually exclusive - deactivate shields first
	if(linked_ship.shields_active)
		for(var/obj/machinery/ship_combat/shield_generator/gen in linked_ship.linked_shield_generators)
			gen.deactivate_generator(skip_break = TRUE)
		linked_ship.shields_active = FALSE
		if(user)
			to_chat(user, span_warning("Shield generators deactivated - cloaking device cannot operate with shields active."))
		linked_ship.ship_notify("Shields offline - cloaking device activated.", "SHIELDS", SHIP_NOTIFY_NOTICE, 'voidcrew/sound/notify.ogg', 50)

	cloak_active = TRUE

	// Hide the ship on the overmap
	linked_ship.SetInvisibility(INVISIBILITY_ABSTRACT, cloak_id, 100)

	// Start high power drain - must use update_mode_power_usage to properly register with APC
	update_mode_power_usage(ACTIVE_POWER_USE, power_needed)
	update_use_power(ACTIVE_POWER_USE)

	// Start cloak duration timer
	// NPC ships can override duration for balance purposes
	var/actual_duration = max_cloak_duration
	if(istype(linked_ship, /obj/structure/overmap/ship/npc))
		var/obj/structure/overmap/ship/npc/npc_ship = linked_ship
		if(npc_ship.npc_cloak_duration > 0)
			actual_duration = npc_ship.npc_cloak_duration
	cloak_expire_time = world.time + actual_duration
	cloak_timer_id = addtimer(CALLBACK(src, PROC_REF(on_cloak_expired)), actual_duration, TIMER_STOPPABLE)

	// Visual and audio feedback
	visible_message(span_notice("[src] hums to life as the cloaking field activates."))
	playsound(src, 'sound/effects/EMPulse.ogg', 50, TRUE)
	cloak_sound?.start()

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
	var/obj/structure/overmap/ship/linked_ship = linked_ship_ref?.resolve()
	if(linked_ship)
		linked_ship.RemoveInvisibility(cloak_id)
		SEND_SIGNAL(linked_ship, COMSIG_SHIP_CLOAK_CHANGED, FALSE)

	// Stop high power drain - reset to idle
	update_mode_power_usage(ACTIVE_POWER_USE, 0)
	update_use_power(IDLE_POWER_USE)
	cloak_sound?.stop()

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
	if(!cloak_active)
		return
	// Nebulas don't interfere with cloaking - they actually help conceal ships
	if(istype(hazard, /obj/structure/overmap/event/nebula))
		return
	// Other hazards break cloak
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
	// Multitool linking
	if(istype(W, /obj/item/multitool))
		var/obj/item/multitool/tool = W
		tool.buffer = src
		balloon_alert(user, "cloaking device buffered")
		to_chat(user, span_notice("You buffer [src] to the multitool. Use on a weapons system to link."))
		return TRUE

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
