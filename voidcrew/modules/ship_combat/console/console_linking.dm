// ========== SHIP CONNECTION & LINKING ==========

/obj/machinery/computer/camera_advanced/ship_combat/proc/attempt_ship_connection()
	if(current_ship)
		return TRUE

	current_ship = get_ship_from_atom(src)
	if(!current_ship)
		return FALSE

	RegisterSignal(current_ship, COMSIG_SHIP_CLOAK_CHANGED, PROC_REF(on_cloak_changed))
	RegisterSignal(current_ship, COMSIG_VOIDCREW_SHIP_DOCKED, PROC_REF(on_our_ship_docked))
	RegisterSignal(current_ship, COMSIG_SHIP_ZONE_CHANGED, PROC_REF(on_our_ship_zone_changed))
	return TRUE

/obj/machinery/computer/camera_advanced/ship_combat/proc/on_cloak_changed(datum/source, new_state)
	SIGNAL_HANDLER
	cloak_active = new_state

/// Called when our ship docks - clear all outgoing targeting/locks
/obj/machinery/computer/camera_advanced/ship_combat/proc/on_our_ship_docked(datum/source)
	SIGNAL_HANDLER
	// Clear any in-progress targeting
	if(is_targeting)
		INVOKE_ASYNC(src, PROC_REF(cancel_targeting))
	// Clear any existing target lock
	if(target_ship)
		INVOKE_ASYNC(src, PROC_REF(clear_target))

// ========== MULTITOOL LINKING ==========

/obj/machinery/computer/camera_advanced/ship_combat/attackby(obj/item/W, mob/user, list/modifiers)
	if(istype(W, /obj/item/multitool))
		var/result = multitool_act(user, W)
		if(result)
			return
	return ..()

/obj/machinery/computer/camera_advanced/ship_combat/multitool_act(mob/living/user, obj/item/multitool/tool)
	if(!istype(tool))
		return NONE

	if(!tool.buffer)
		return ..() // Let parent handle empty buffer

	// Handle list buffer (could be launchers or other things)
	if(islist(tool.buffer))
		var/list/buffer_list = tool.buffer
		if(!length(buffer_list))
			return ..() // Let parent handle empty list

		// Check if this list contains any launchers
		var/has_launchers = FALSE
		for(var/obj/machinery/ship_combat/missile_launcher/L in buffer_list)
			has_launchers = TRUE
			break

		// If no launchers, let parent handle it (could be turrets, etc)
		if(!has_launchers)
			return ..()

		// Process launchers
		var/linked_count = 0
		var/already_linked_count = 0
		for(var/obj/machinery/ship_combat/missile_launcher/launcher in buffer_list)
			// Check if already linked
			var/already_linked = FALSE
			for(var/datum/weakref/ref in linked_launchers)
				if(ref.resolve() == launcher)
					already_linked = TRUE
					already_linked_count++
					break
			if(already_linked)
				continue

			// Link the launcher
			if(launcher.link_console(src))
				linked_launchers += WEAKREF(launcher)
				linked_count++

		// Clear only the launchers from buffer
		for(var/obj/machinery/ship_combat/missile_launcher/launcher in buffer_list)
			buffer_list -= launcher

		if(linked_count > 0)
			balloon_alert(user, "[linked_count] launcher(s) linked")
			to_chat(user, span_notice("Linked [linked_count] launcher(s) to [src]. Total launchers: [length(linked_launchers)]"))
		else if(already_linked_count > 0)
			balloon_alert(user, "all already linked")

		return ITEM_INTERACT_SUCCESS

	// Handle single launcher
	if(istype(tool.buffer, /obj/machinery/ship_combat/missile_launcher))
		var/obj/machinery/ship_combat/missile_launcher/launcher = tool.buffer

		// Check if already linked
		for(var/datum/weakref/ref in linked_launchers)
			if(ref.resolve() == launcher)
				balloon_alert(user, "already linked")
				return ITEM_INTERACT_BLOCKING

		// Link the launcher
		if(launcher.link_console(src))
			linked_launchers += WEAKREF(launcher)
			balloon_alert(user, "launcher linked")
			to_chat(user, span_notice("Linked [launcher] to [src]. Total launchers: [length(linked_launchers)]"))
		else
			balloon_alert(user, "link failed")

		return ITEM_INTERACT_SUCCESS

	// Handle shield generator linking
	if(istype(tool.buffer, /obj/machinery/ship_combat/shield_generator))
		var/obj/machinery/ship_combat/shield_generator/gen = tool.buffer

		// Check if already linked
		var/obj/machinery/ship_combat/shield_generator/current_shield = linked_shield_ref?.resolve()
		if(current_shield == gen)
			balloon_alert(user, "already linked")
			return ITEM_INTERACT_BLOCKING

		// Link the generator
		if(link_shield_generator(gen))
			balloon_alert(user, "shield generator linked")
			to_chat(user, span_notice("Linked [gen] to [src]."))
		else
			balloon_alert(user, "link failed")

		return ITEM_INTERACT_SUCCESS

	// Handle laser turret linking
	if(istype(tool.buffer, /obj/machinery/ship_combat/laser_turret))
		var/obj/machinery/ship_combat/laser_turret/turret = tool.buffer

		// Check if at max turrets
		if(length(linked_turrets) >= LASER_MAX_TURRETS)
			balloon_alert(user, "max turrets reached")
			to_chat(user, span_warning("Cannot link more than [LASER_MAX_TURRETS] laser turrets to one ship!"))
			return ITEM_INTERACT_BLOCKING

		// Check if already linked
		for(var/datum/weakref/ref in linked_turrets)
			if(ref.resolve() == turret)
				balloon_alert(user, "already linked")
				return ITEM_INTERACT_BLOCKING

		// Link the turret
		if(turret.link_console(src))
			linked_turrets += WEAKREF(turret)
			turret.set_power_level(turret_power_level)  // Apply current power level
			balloon_alert(user, "turret linked")
			to_chat(user, span_notice("Linked [turret] to [src]. Total turrets: [length(linked_turrets)]"))
		else
			balloon_alert(user, "link failed")

		return ITEM_INTERACT_SUCCESS

	// Handle interdictor linking
	if(istype(tool.buffer, /obj/machinery/ship_combat/interdictor))
		var/obj/machinery/ship_combat/interdictor/interdictor = tool.buffer

		// Check if already linked
		var/obj/machinery/ship_combat/interdictor/current = linked_interdictor_ref?.resolve()
		if(current == interdictor)
			balloon_alert(user, "already linked")
			return ITEM_INTERACT_BLOCKING

		// Link the interdictor
		if(link_interdictor(interdictor))
			balloon_alert(user, "interdictor linked")
			to_chat(user, span_notice("Linked [interdictor] to [src]."))
		else
			balloon_alert(user, "link failed")

		return ITEM_INTERACT_SUCCESS

	// Handle cloaking device linking
	if(istype(tool.buffer, /obj/machinery/ship_combat/cloak_device))
		var/obj/machinery/ship_combat/cloak_device/cloak = tool.buffer

		// Check if already linked
		var/obj/machinery/ship_combat/cloak_device/current_cloak = linked_cloak_ref?.resolve()
		if(current_cloak == cloak)
			balloon_alert(user, "already linked")
			return ITEM_INTERACT_BLOCKING

		// Link the cloaking device
		if(link_cloak_device(cloak))
			balloon_alert(user, "cloaking device linked")
			to_chat(user, span_notice("Linked [cloak] to [src]."))
		else
			balloon_alert(user, "link failed")

		return ITEM_INTERACT_SUCCESS

	// Not something we handle, let parent try
	return ..()

/// Links an interdictor to this console
/obj/machinery/computer/camera_advanced/ship_combat/proc/link_interdictor(obj/machinery/ship_combat/interdictor/interdictor)
	if(!interdictor)
		return FALSE

	// Unlink any existing interdictor
	var/obj/machinery/ship_combat/interdictor/old = linked_interdictor_ref?.resolve()
	if(old)
		old.unlink_console()

	linked_interdictor_ref = WEAKREF(interdictor)
	interdictor.link_console(src)

	// Link to our ship
	if(current_ship)
		interdictor.link_ship(current_ship)

	return TRUE

/// Links a shield generator to this console
/obj/machinery/computer/camera_advanced/ship_combat/proc/link_shield_generator(obj/machinery/ship_combat/shield_generator/gen)
	if(!gen)
		return FALSE

	// Unlink any existing generator
	var/obj/machinery/ship_combat/shield_generator/old_gen = linked_shield_ref?.resolve()
	if(old_gen)
		old_gen.unlink_console()

	linked_shield_ref = WEAKREF(gen)

	// Link to our ship
	if(current_ship)
		gen.link_ship(current_ship)

	return TRUE

/// Links a cloaking device to this console
/obj/machinery/computer/camera_advanced/ship_combat/proc/link_cloak_device(obj/machinery/ship_combat/cloak_device/cloak)
	if(!cloak)
		return FALSE

	// Unlink any existing cloaking device
	var/obj/machinery/ship_combat/cloak_device/old_cloak = linked_cloak_ref?.resolve()
	if(old_cloak)
		old_cloak.unlink_console()

	linked_cloak_ref = WEAKREF(cloak)

	// Ensure cloak device is connected to the same ship
	if(current_ship && !cloak.linked_ship_ref?.resolve())
		cloak.link_ship(current_ship)

	return TRUE

/// Returns aggregated shield status from the ship's shared shield pool
/// Uses caching for performance - refreshes every 0.5s or when marked dirty
/obj/machinery/computer/camera_advanced/ship_combat/proc/get_aggregated_shield_status()
	if(!current_ship)
		return list()

	// Check if we can use cached data (valid for 0.5 seconds unless marked dirty)
	var/cache_age = world.time - shield_status_last_update
	if(!shield_status_dirty && cached_shield_status && cache_age < 5)  // 0.5 seconds = 5 deciseconds
		return cached_shield_status

	// Refresh the cache
	var/list/result = current_ship.get_shield_status()
	// Add active_count for UI (count of active generators)
	var/active_count = 0
	for(var/obj/machinery/ship_combat/shield_generator/gen in current_ship.linked_shield_generators)
		if(gen.active)
			active_count++
	result["active_count"] = active_count

	// Store in cache
	cached_shield_status = result
	shield_status_dirty = FALSE
	shield_status_last_update = world.time

	return result

/// Marks shield status cache as dirty, forcing refresh on next query
/obj/machinery/computer/camera_advanced/ship_combat/proc/invalidate_shield_cache()
	shield_status_dirty = TRUE
