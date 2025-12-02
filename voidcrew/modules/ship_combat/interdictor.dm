// Ship Combat Interdictor
// A machine that can lock onto nearby ships and force them to dock
// Requires 5 seconds of lock-on time, slows target during lock

/obj/machinery/ship_combat/interdictor
	name = "ship interdictor"
	desc = "A tractor beam system that can lock onto nearby ships and force them to dock. The target ship will be slowed during lock-on."
	icon = 'voidcrew/modules/shuttle/icons/shuttle.dmi'
	icon_state = "dvoid"
	density = TRUE
	anchored = TRUE
	power_channel = AREA_USAGE_EQUIP
	circuit = /obj/item/circuitboard/machine/ship_combat/interdictor

	/// Our connected ship
	var/obj/structure/overmap/ship/current_ship
	/// The ship we're targeting
	var/datum/weakref/target_ship_ref
	/// Is interdiction currently active?
	var/interdiction_active = FALSE
	/// Progress of the interdiction (0-100)
	var/interdiction_progress = 0
	/// Timer ID for processing interdiction
	var/interdiction_timer
	/// Cooldown between interdiction attempts
	COOLDOWN_DECLARE(interdict_cooldown)

/obj/machinery/ship_combat/interdictor/Initialize(mapload)
	. = ..()
	return INITIALIZE_HINT_LATELOAD

/obj/machinery/ship_combat/interdictor/LateInitialize()
	. = ..()
	attempt_ship_connection()

/obj/machinery/ship_combat/interdictor/Destroy()
	cancel_interdiction()
	current_ship = null
	return ..()

/// Attempts to find and connect to our ship
/obj/machinery/ship_combat/interdictor/proc/attempt_ship_connection()
	var/area/ship_area = get_area(src)
	if(!ship_area)
		return FALSE

	for(var/obj/structure/overmap/ship/S in SSovermap.simulated_ships)
		if(!S.shuttle)
			continue
		if(ship_area in S.shuttle.shuttle_areas)
			current_ship = S
			return TRUE
	return FALSE

/obj/machinery/ship_combat/interdictor/examine(mob/user)
	. = ..()
	if(!current_ship)
		. += span_warning("Not connected to ship systems.")
		return
	. += span_notice("Connected to: [current_ship.display_name]")
	if(interdiction_active)
		var/obj/structure/overmap/ship/target = target_ship_ref?.resolve()
		. += span_warning("INTERDICTING: [target?.display_name || "Unknown"] ([interdiction_progress]%)")
	else if(!COOLDOWN_FINISHED(src, interdict_cooldown))
		. += span_warning("Cooldown: [DisplayTimeText(COOLDOWN_TIMELEFT(src, interdict_cooldown))]")
	else
		. += span_notice("Ready to interdict.")

// ========== UI ==========

/obj/machinery/ship_combat/interdictor/ui_interact(mob/user, datum/tgui/ui)
	ui = SStgui.try_update_ui(user, src, ui)
	if(!ui)
		ui = new(user, src, "ShipInterdictor", name)
		ui.open()

/obj/machinery/ship_combat/interdictor/ui_data(mob/user)
	var/list/data = list()

	data["connected"] = !!current_ship
	data["ship_name"] = current_ship?.display_name

	// Get nearby ships (on same tile)
	var/list/nearby_ships = list()
	if(current_ship?.state == OVERMAP_SHIP_FLYING)
		for(var/obj/structure/overmap/ship/S in current_ship.close_overmap_objects)
			if(S == current_ship)
				continue
			if(S.state != OVERMAP_SHIP_FLYING)
				continue
			// Must be on the same tile
			if(get_turf(S) != get_turf(current_ship))
				continue
			nearby_ships += list(list(
				"name" = S.display_name || S.name,
				"ref" = REF(S)
			))

	data["nearby_ships"] = nearby_ships

	// Target info
	var/obj/structure/overmap/ship/target = target_ship_ref?.resolve()
	data["target_name"] = target?.display_name
	data["target_ref"] = target ? REF(target) : null

	// Interdiction status
	data["interdiction_active"] = interdiction_active
	data["interdiction_progress"] = interdiction_progress
	data["cooldown_active"] = !COOLDOWN_FINISHED(src, interdict_cooldown)
	data["cooldown_remaining"] = COOLDOWN_TIMELEFT(src, interdict_cooldown)

	return data

/obj/machinery/ship_combat/interdictor/ui_act(action, list/params)
	. = ..()
	if(.)
		return

	switch(action)
		if("select_target")
			var/obj/structure/overmap/ship/target = locate(params["ref"]) in SSovermap.simulated_ships
			if(!target || target == current_ship)
				return FALSE
			target_ship_ref = WEAKREF(target)
			return TRUE

		if("clear_target")
			if(interdiction_active)
				cancel_interdiction()
			target_ship_ref = null
			return TRUE

		if("start_interdict")
			return start_interdiction(usr)

		if("cancel_interdict")
			cancel_interdiction()
			return TRUE

	return FALSE

// ========== INTERDICTION LOGIC ==========

/// Starts the interdiction process
/obj/machinery/ship_combat/interdictor/proc/start_interdiction(mob/user)
	if(machine_stat & (BROKEN|NOPOWER))
		if(user)
			to_chat(user, span_warning("[src] is not operational!"))
		return FALSE

	if(!current_ship)
		if(user)
			to_chat(user, span_warning("[src] is not connected to ship systems!"))
		return FALSE

	if(interdiction_active)
		if(user)
			to_chat(user, span_warning("Interdiction already in progress!"))
		return FALSE

	if(!COOLDOWN_FINISHED(src, interdict_cooldown))
		if(user)
			to_chat(user, span_warning("Interdictor is recharging! Available in [DisplayTimeText(COOLDOWN_TIMELEFT(src, interdict_cooldown))]."))
		return FALSE

	var/obj/structure/overmap/ship/target = target_ship_ref?.resolve()
	if(!target)
		if(user)
			to_chat(user, span_warning("No target selected!"))
		return FALSE

	// Verify target is still on same tile
	if(get_turf(target) != get_turf(current_ship))
		if(user)
			to_chat(user, span_warning("Target ship is no longer in range!"))
		target_ship_ref = null
		return FALSE

	// Verify target is still flying
	if(target.state != OVERMAP_SHIP_FLYING)
		if(user)
			to_chat(user, span_warning("Target ship cannot be interdicted!"))
		return FALSE

	// Start interdiction
	interdiction_active = TRUE
	interdiction_progress = 0

	// Apply slowdown to target
	target.speed_multiplier = INTERDICTOR_SPEED_REDUCTION

	// Send signal and alert target crew
	SEND_SIGNAL(target, COMSIG_SHIP_INTERDICTED, src)
	target.ship_announce("WARNING: YOUR SHIP IS BEING INTERDICTED! ENGINES AT [INTERDICTOR_SPEED_REDUCTION * 100]% EFFICIENCY!", "INTERDICTION ALERT", sound('sound/announcer/alarm/announce.ogg'))

	// Alert our crew
	if(user)
		to_chat(user, span_notice("Interdiction lock initiated on [target.display_name]. Locking on..."))
	current_ship.ship_announce("Interdiction lock initiated on [target.display_name].", "Interdictor")

	// Start processing
	interdiction_timer = addtimer(CALLBACK(src, PROC_REF(process_interdiction)), 0.5 SECONDS, TIMER_STOPPABLE | TIMER_LOOP)

	update_appearance()
	return TRUE

/// Called every 0.5 seconds during interdiction
/obj/machinery/ship_combat/interdictor/proc/process_interdiction()
	if(!interdiction_active)
		return

	if(machine_stat & (BROKEN|NOPOWER))
		cancel_interdiction("Interdictor lost power!")
		return

	var/obj/structure/overmap/ship/target = target_ship_ref?.resolve()
	if(!target)
		cancel_interdiction("Target lost!")
		return

	// Check if target escaped (moved to different tile)
	if(get_turf(target) != get_turf(current_ship))
		cancel_interdiction("Target escaped interdiction range!")
		return

	// Check if target is no longer flying (already docked somewhere)
	if(target.state != OVERMAP_SHIP_FLYING)
		cancel_interdiction("Target is no longer flying!")
		return

	// Use power
	use_energy(INTERDICTOR_POWER_ACTIVE * 0.5) // Half power per tick

	// Increment progress (10% per 0.5 seconds = 5 seconds total)
	interdiction_progress += 10

	if(interdiction_progress >= 100)
		complete_interdiction()

/// Cancels the interdiction process
/obj/machinery/ship_combat/interdictor/proc/cancel_interdiction(reason)
	if(!interdiction_active)
		return

	interdiction_active = FALSE
	interdiction_progress = 0

	if(interdiction_timer)
		deltimer(interdiction_timer)
		interdiction_timer = null

	// Remove slowdown from target
	var/obj/structure/overmap/ship/target = target_ship_ref?.resolve()
	if(target)
		target.speed_multiplier = 1
		SEND_SIGNAL(target, COMSIG_SHIP_INTERDICTION_ENDED)
		target.ship_announce("Interdiction lock broken. Engines restored to full power.", "Interdiction Ended")

	if(reason && current_ship)
		current_ship.ship_announce("[reason]", "Interdiction Failed")

	update_appearance()

/// Completes interdiction and forces docking
/obj/machinery/ship_combat/interdictor/proc/complete_interdiction()
	if(!interdiction_active)
		return

	var/obj/structure/overmap/ship/target = target_ship_ref?.resolve()
	if(!target)
		cancel_interdiction("Target lost at final moment!")
		return

	interdiction_active = FALSE
	interdiction_progress = 100

	if(interdiction_timer)
		deltimer(interdiction_timer)
		interdiction_timer = null

	// Remove slowdown
	target.speed_multiplier = 1
	SEND_SIGNAL(target, COMSIG_SHIP_INTERDICTION_ENDED)

	// Announce success
	current_ship.ship_announce("Interdiction complete! Forcing [target.display_name] to dock!", "Interdiction Success")
	target.ship_announce("INTERDICTION COMPLETE! Forced docking initiated!", "INTERDICTION ALERT")

	// Force dock the ships together
	var/result = current_ship.dock_ships_directly(target, null)
	if(result)
		// Docking failed for some reason
		current_ship.ship_announce("Forced docking failed: [result]", "Docking Error")
		target.ship_announce("Forced docking failed. Engines restored.", "Interdiction Ended")
	else
		// Success - play alarm on target ship
		playsound(src, 'sound/machines/airlock/airlockopening.ogg', 50, TRUE)

	// Start cooldown
	COOLDOWN_START(src, interdict_cooldown, INTERDICTOR_COOLDOWN)

	// Clear target
	target_ship_ref = null

	update_appearance()

// ========== OVERLAYS ==========

/obj/machinery/ship_combat/interdictor/update_overlays()
	. = ..()
	if(interdiction_active)
		. += mutable_appearance('icons/effects/effects.dmi', "yourselfl") // glowing effect
	if(!COOLDOWN_FINISHED(src, interdict_cooldown))
		. += mutable_appearance('icons/effects/effects.dmi', "sparks")

// ========== CIRCUIT BOARD ==========

/obj/item/circuitboard/machine/ship_combat/interdictor
	name = "Ship Interdictor"
	greyscale_colors = CIRCUIT_COLOR_SECURITY
	build_path = /obj/machinery/ship_combat/interdictor
	req_components = list(
		/datum/stock_part/capacitor = 2,
		/datum/stock_part/scanning_module = 1,
	)
