// Ship Cloaking Device
// Hides the ship's icon on the overmap when active
// Automatically decloaks when weapons are fired

/obj/machinery/ship_combat/cloak_device
	name = "cloaking device"
	desc = "An advanced cloaking device that hides the ship from detection on the overmap. Will automatically deactivate when weapons are fired."
	icon = 'icons/obj/machines/research.dmi'
	icon_state = "dvd"
	density = TRUE
	anchored = TRUE
	power_channel = AREA_USAGE_EQUIP
	circuit = /obj/item/circuitboard/machine/ship_combat/cloak_device

	/// Is the cloak currently active?
	var/cloak_active = FALSE
	/// Power consumption when cloaked (in watts)
	var/cloak_power_cost = 500
	/// Reference to our ship
	var/obj/structure/overmap/ship/linked_ship
	/// Cooldown before we can re-cloak after decloaking
	COOLDOWN_DECLARE(recloak_cooldown)
	/// How long before we can recloak
	var/recloak_delay = 30 SECONDS
	/// The invisibility ID we use
	var/cloak_id = "ship_cloak_device"

/obj/machinery/ship_combat/cloak_device/Initialize(mapload)
	. = ..()
	// Try to find our ship on init
	attempt_ship_connection()

/obj/machinery/ship_combat/cloak_device/Destroy()
	if(cloak_active)
		deactivate_cloak(silent = TRUE)
	unlink_ship()
	return ..()

/obj/machinery/ship_combat/cloak_device/examine(mob/user)
	. = ..()
	if(cloak_active)
		. += span_notice("Status: [span_green("CLOAKED")]")
		. += span_notice("Power draw: [cloak_power_cost]W")
	else
		. += span_warning("Status: [span_red("VISIBLE")]")
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
	RegisterSignal(linked_ship, COMSIG_SHIP_WEAPON_FIRED, PROC_REF(on_weapon_fired))
	RegisterSignal(linked_ship, COMSIG_QDELETING, PROC_REF(on_ship_deleted))

/obj/machinery/ship_combat/cloak_device/proc/unlink_ship()
	if(linked_ship)
		UnregisterSignal(linked_ship, list(COMSIG_SHIP_WEAPON_FIRED, COMSIG_QDELETING))
		linked_ship = null

/obj/machinery/ship_combat/cloak_device/proc/on_ship_deleted(datum/source)
	SIGNAL_HANDLER
	if(cloak_active)
		deactivate_cloak(silent = TRUE)
	linked_ship = null

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

	if(!COOLDOWN_FINISHED(src, recloak_cooldown))
		if(user)
			to_chat(user, span_warning("Cloak recharging! Available in [DisplayTimeText(COOLDOWN_TIMELEFT(src, recloak_cooldown))]."))
		return FALSE

	cloak_active = TRUE

	// Hide the ship on the overmap
	linked_ship.SetInvisibility(INVISIBILITY_ABSTRACT, cloak_id, 100)

	// Start power drain
	update_use_power(ACTIVE_POWER_USE)
	active_power_usage = cloak_power_cost

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

	// Show the ship on the overmap
	if(linked_ship)
		linked_ship.RemoveInvisibility(cloak_id)
		SEND_SIGNAL(linked_ship, COMSIG_SHIP_CLOAK_CHANGED, FALSE)

	// Stop power drain
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
		INVOKE_ASYNC(src, PROC_REF(emergency_decloak))

/obj/machinery/ship_combat/cloak_device/proc/emergency_decloak()
	visible_message(span_danger("[src] overloads! Weapons discharge detected - emergency decloak!"))
	deactivate_cloak()

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
