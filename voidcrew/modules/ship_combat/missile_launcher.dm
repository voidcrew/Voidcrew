// Ship Combat Missile Launcher
// A machine that holds and fires missiles at enemy ships
// Must be linked to a combat console via multitool
// Missiles are loaded by dragging an armed missile structure onto the launcher

/obj/machinery/ship_combat/missile_launcher
	name = "missile launcher"
	desc = "A ship-mounted missile launcher system. Drag an armed missile onto it to load, then link to a combat console with a multitool."
	icon = 'voidcrew/icons/obj/machines/missile_launcher.dmi'
	icon_state = "unloaded"
	density = TRUE
	anchored = TRUE
	power_channel = AREA_USAGE_EQUIP
	circuit = /obj/item/circuitboard/machine/ship_combat/missile_launcher
	pixel_x = -16
	pixel_y = -16
	/// Loaded missile data (list of missile properties, or null if empty)
	var/list/loaded_missile
	/// Reference to our linked combat console
	var/datum/weakref/linked_console_ref
	/// Our unique ID for console linking
	var/launcher_id
	/// Time to load a missile
	var/load_time = 4 SECONDS

/obj/machinery/ship_combat/missile_launcher/Initialize(mapload)
	. = ..()
	launcher_id = "[rand(1000, 9999)]"
	name = "[initial(name)] ([launcher_id])"
	// Try to auto-link to a combat console on the same ship after a short delay
	addtimer(CALLBACK(src, PROC_REF(attempt_auto_link)), 2 SECONDS)

/obj/machinery/ship_combat/missile_launcher/Destroy()
	loaded_missile = null
	unlink_console()
	return ..()

/obj/machinery/ship_combat/missile_launcher/examine(mob/user)
	. = ..()
	. += span_notice("Launcher ID: [launcher_id]")
	if(loaded_missile)
		. += span_notice("Loaded: [loaded_missile["name"]] ([loaded_missile["damage"]] damage)")
	else
		. += span_warning("No missile loaded. Drag an armed missile onto the launcher.")
	var/obj/machinery/computer/camera_advanced/ship_combat/linked_console = linked_console_ref?.resolve()
	if(linked_console)
		. += span_notice("Linked to: [linked_console]")
	else
		. += span_warning("Not linked to a combat console. Use a multitool to link.")

/obj/machinery/ship_combat/missile_launcher/update_icon_state()
	. = ..()
	icon_state = loaded_missile ? "loaded" : "unloaded"

// ========== LOADING MECHANICS ==========

// Handle missiles being dragged onto the launcher
/obj/machinery/ship_combat/missile_launcher/mouse_drop_receive(atom/dropped, mob/user, params)
	var/obj/structure/ship_missile/missile = dropped
	if(!istype(missile))
		return
	if(!Adjacent(user) || !user.Adjacent(missile))
		to_chat(user, span_warning("You need to be next to both the missile and the launcher!"))
		return
	if(machine_stat & BROKEN)
		to_chat(user, span_warning("[src] is broken!"))
		return
	if(!anchored)
		to_chat(user, span_warning("[src] isn't secured to the deck!"))
		return
	if(loaded_missile)
		to_chat(user, span_warning("[src] already has a missile loaded!"))
		return
	if(missile.construction_state != MISSILE_STATE_ARMED)
		to_chat(user, span_warning("[missile] isn't armed! It needs a payload."))
		return

	var/list/fire_data = missile.get_fire_data()
	if(!fire_data)
		to_chat(user, span_warning("[missile] has no valid payload!"))
		return

	// If this is a chemical missile, move the grenade into the launcher to protect it from qdel
	var/obj/item/grenade/chem_grenade/extracted_grenade = fire_data["grenade"]
	if(extracted_grenade)
		extracted_grenade.forceMove(src)  // Move into launcher - hidden from view and safe from missile qdel

	to_chat(user, span_notice("You begin loading [missile] into [src]..."))
	playsound(src, 'sound/machines/terminal/terminal_insert_disc.ogg', 50, TRUE)

	if(!do_after(user, missile.load_time, src))
		to_chat(user, span_warning("You stop loading the missile."))
		return

	// Verify everything is still valid
	if(QDELETED(missile) || !Adjacent(user) || !user.Adjacent(missile))
		return
	if(loaded_missile)
		return
	if(missile.construction_state != MISSILE_STATE_ARMED)
		return

	// Load the missile - use the fire_data we already got (don't call get_fire_data again!)
	// For chemical grenades, get_fire_data extracts the grenade, so calling it twice would fail
	loaded_missile = fire_data
	loaded_missile["name"] = missile.name

	user.visible_message(
		span_notice("[user] loads [missile] into [src]."),
		span_notice("You load [missile] into [src].")
	)
	playsound(src, 'sound/machines/click.ogg', 50, TRUE)

	// Delete the missile structure
	qdel(missile)
	update_appearance()

/obj/machinery/ship_combat/missile_launcher/attackby(obj/item/W, mob/user, list/modifiers, list/attack_modifiers)
	// Multitool linking - store self in buffer
	if(istype(W, /obj/item/multitool))
		var/obj/item/multitool/tool = W
		// Store just this launcher in the buffer (single item, not list)
		tool.buffer = src
		balloon_alert(user, "launcher buffered")
		to_chat(user, span_notice("You buffer [src] to the multitool. Use on a combat console to link."))
		return TRUE

	// Standard deconstruction - only allow if empty
	if(!loaded_missile)
		if(default_deconstruction_screwdriver(user, icon_state, icon_state, W))
			return
	if(default_deconstruction_crowbar(W))
		return
	return ..()

/obj/machinery/ship_combat/missile_launcher/on_deconstruction(disassembled)
	// Loaded missile is just lost on deconstruction
	loaded_missile = null

// ========== UNLOADING ==========

/obj/machinery/ship_combat/missile_launcher/attack_hand(mob/user, list/modifiers)
	. = ..()
	if(.)
		return

	if(!loaded_missile)
		to_chat(user, span_warning("No missile loaded."))
		return

	// Create a new armed missile with the stored warhead data
	to_chat(user, span_notice("You begin removing the missile from [src]..."))

	if(!do_after(user, 2 SECONDS, src))
		return

	if(!loaded_missile)
		return

	// Spawn a new armed missile structure
	var/obj/structure/ship_missile/new_missile = new(drop_location())

	// Create tracking circuit
	new_missile.tracking = new /obj/item/electronics/ship_missile_tracking(new_missile)

	// Create the appropriate warhead (bomb core)
	// Note: Chemical missiles use grenades which can't be recreated from stored data
	var/effect_type = loaded_missile["effect_type"]
	var/warhead_type
	if(effect_type == /obj/effect/ship_missile/emp)
		warhead_type = /obj/item/bombcore/missile/emp
	else if(effect_type == /obj/effect/ship_missile/chemical)
		// Chemical grenades can't be recreated - their reagents are unique
		// The missile is unloadable but will be empty (just the frame)
		to_chat(user, span_warning("The chemical payload cannot be recovered - the grenade was consumed."))
		new_missile.construction_state = MISSILE_STATE_TRACKING
		new_missile.update_appearance()
		loaded_missile = null
		update_appearance()
		return
	else
		// Determine by damage
		var/damage = loaded_missile["damage"]
		switch(damage)
			if(MISSILE_DAMAGE_LIGHT)
				warhead_type = /obj/item/bombcore/missile/light
			if(MISSILE_DAMAGE_HEAVY)
				warhead_type = /obj/item/bombcore/missile/heavy
			else
				warhead_type = /obj/item/bombcore/missile

	new_missile.warhead = new warhead_type(new_missile)
	new_missile.construction_state = MISSILE_STATE_ARMED
	new_missile.update_appearance()

	// Clear the loaded missile
	loaded_missile = null

	user.visible_message(
		span_notice("[user] removes a missile from [src]."),
		span_notice("You remove the missile from [src].")
	)
	update_appearance()

// ========== CONSOLE LINKING ==========

/// Links this launcher to a combat console
/obj/machinery/ship_combat/missile_launcher/proc/link_console(obj/machinery/computer/camera_advanced/ship_combat/console)
	if(!console)
		return FALSE
	unlink_console()
	linked_console_ref = WEAKREF(console)
	RegisterSignal(console, COMSIG_QDELETING, PROC_REF(on_console_deleted))
	return TRUE

/// Unlinks from the current console
/obj/machinery/ship_combat/missile_launcher/proc/unlink_console()
	var/obj/machinery/computer/camera_advanced/ship_combat/console = linked_console_ref?.resolve()
	if(console)
		UnregisterSignal(console, COMSIG_QDELETING)
	linked_console_ref = null

/obj/machinery/ship_combat/missile_launcher/proc/on_console_deleted(datum/source)
	SIGNAL_HANDLER
	linked_console_ref = null

/// Attempts to auto-link to a combat console on the same ship
/obj/machinery/ship_combat/missile_launcher/proc/attempt_auto_link()
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
				// Also add ourselves to the console's launcher list
				var/already_linked = FALSE
				for(var/datum/weakref/ref in console.linked_launchers)
					if(ref.resolve() == src)
						already_linked = TRUE
						break
				if(!already_linked)
					console.linked_launchers += WEAKREF(src)
				return

// ========== FIRING ==========

/// Attempts to fire the loaded missile at the target turf
/// spawn_offset_x/y are used to stagger missile spawn positions for volleys
/// approach_dir is the direction missiles come FROM (NORTH means missiles come from north, fly south)
/obj/machinery/ship_combat/missile_launcher/proc/fire(turf/target, obj/structure/overmap/ship/target_ship, obj/structure/overmap/ship/source_ship, mob/user, spawn_offset_x = 0, spawn_offset_y = 0, approach_dir = null)
	if(!can_fire())
		return FALSE

	if(!target)
		if(user)
			to_chat(user, span_warning("No target selected!"))
		return FALSE

	// Calculate spawn position on the target ship's z-level
	// The missile will spawn outside the target ship and fly in
	var/turf/spawn_turf = get_missile_spawn_turf(target, target_ship, approach_dir)
	if(!spawn_turf)
		// Fallback to near the target if calculation fails
		spawn_turf = target

	// Apply spawn offset for staggered volleys
	if(spawn_offset_x || spawn_offset_y)
		var/turf/offset_turf = locate(spawn_turf.x + spawn_offset_x, spawn_turf.y + spawn_offset_y, spawn_turf.z)
		if(offset_turf)
			spawn_turf = offset_turf

	// Create missile effect using stored data
	var/effect_type = loaded_missile["effect_type"]
	var/obj/item/grenade/chem_grenade/grenade_to_pass = loaded_missile["grenade"]
	new effect_type(
		spawn_turf,
		target,
		target_ship,
		source_ship,
		loaded_missile["damage"],
		loaded_missile["devastation"],
		loaded_missile["heavy"],
		loaded_missile["light"],
		loaded_missile["flame"],
		loaded_missile["icon_state"],
		grenade_to_pass,  // For chemical missiles - pass the actual grenade
	)

	// Clear the loaded missile
	loaded_missile = null

	// Use power
	use_energy(MISSILE_LAUNCHER_POWER_FIRE)

	// Play sound
	playsound(src, 'sound/vehicles/rocketlaunch.ogg', 80, TRUE)

	// Visual feedback
	visible_message(span_danger("[src] fires a missile!"))
	if(user)
		to_chat(user, span_notice("Missile away! Target: [target_ship ? target_ship.name : "unknown"]"))

	update_appearance()
	return TRUE

/// Calculates where to spawn a missile - outside the target ship, in the transit space
/// approach_dir: If provided, missiles spawn from this direction. Otherwise auto-calculated to find a clear path.
/obj/machinery/ship_combat/missile_launcher/proc/get_missile_spawn_turf(turf/target, obj/structure/overmap/ship/tgt_ship, approach_dir = null)
	if(!target)
		return null

	// Get ship bounds from the docking port
	var/min_x = target.x
	var/max_x = target.x
	var/min_y = target.y
	var/max_y = target.y

	if(tgt_ship?.shuttle)
		var/list/bounds = tgt_ship.shuttle.return_coords()
		if(bounds?.len >= 4)
			min_x = min(bounds[1], bounds[3])
			max_x = max(bounds[1], bounds[3])
			min_y = min(bounds[2], bounds[4])
			max_y = max(bounds[2], bounds[4])

	// How far outside the ship to spawn (between ship edge and black wall)
	var/spawn_dist = 10

	var/spawn_x = target.x
	var/spawn_y = target.y

	// Calculate direction if not provided - find a clear path through hull breaches
	var/dir = approach_dir
	if(!dir)
		dir = find_clear_approach_direction(target, min_x, max_x, min_y, max_y, spawn_dist)

	// Spawn missiles from the selected direction
	switch(dir)
		if(NORTH)
			// Missiles come FROM the north, spawn above the ship
			spawn_y = max_y + spawn_dist
			spawn_x = target.x
		if(SOUTH)
			// Missiles come FROM the south, spawn below the ship
			spawn_y = min_y - spawn_dist
			spawn_x = target.x
		if(EAST)
			// Missiles come FROM the east, spawn to the right of the ship
			spawn_x = max_x + spawn_dist
			spawn_y = target.y
		if(WEST)
			// Missiles come FROM the west, spawn to the left of the ship
			spawn_x = min_x - spawn_dist
			spawn_y = target.y

	return locate(spawn_x, spawn_y, target.z)

/// Finds the best approach direction for a missile to reach an interior target
/// Checks each cardinal direction for a clear line-of-sight path (through hull breaches)
/// Returns a direction constant (NORTH, SOUTH, EAST, WEST)
/obj/machinery/ship_combat/missile_launcher/proc/find_clear_approach_direction(turf/target, min_x, max_x, min_y, max_y, spawn_dist)
	var/list/directions = list(NORTH, SOUTH, EAST, WEST)
	var/list/clear_directions = list()

	// Check each direction for a clear path
	for(var/check_dir in directions)
		var/spawn_x = target.x
		var/spawn_y = target.y

		switch(check_dir)
			if(NORTH)
				spawn_y = max_y + spawn_dist
			if(SOUTH)
				spawn_y = min_y - spawn_dist
			if(EAST)
				spawn_x = max_x + spawn_dist
			if(WEST)
				spawn_x = min_x - spawn_dist

		var/turf/spawn_turf = locate(spawn_x, spawn_y, target.z)
		if(!spawn_turf)
			continue

		// Check if path from spawn to target is clear (no dense walls blocking)
		if(check_path_clear(spawn_turf, target))
			clear_directions += check_dir

	// If we found clear paths, pick the best one
	if(length(clear_directions))
		// Prefer the direction closest to the target's offset from ship center
		var/center_x = (min_x + max_x) / 2
		var/center_y = (min_y + max_y) / 2
		var/offset_x = target.x - center_x
		var/offset_y = target.y - center_y

		// Check if our preferred direction is clear
		var/preferred_dir
		if(abs(offset_x) > abs(offset_y))
			preferred_dir = (offset_x > 0) ? EAST : WEST
		else
			preferred_dir = (offset_y > 0) ? NORTH : SOUTH

		if(preferred_dir in clear_directions)
			return preferred_dir

		// Otherwise return the first clear direction
		return clear_directions[1]

	// No clear paths found - fall back to the original logic (closest edge)
	var/center_x = (min_x + max_x) / 2
	var/center_y = (min_y + max_y) / 2
	var/offset_x = target.x - center_x
	var/offset_y = target.y - center_y

	if(abs(offset_x) > abs(offset_y))
		return (offset_x > 0) ? EAST : WEST
	else
		return (offset_y > 0) ? NORTH : SOUTH

/// Checks if there's a clear line-of-sight path between two turfs
/// Returns TRUE if the path is clear (no dense walls), FALSE otherwise
/obj/machinery/ship_combat/missile_launcher/proc/check_path_clear(turf/start, turf/end)
	if(!start || !end)
		return FALSE

	// Get all turfs in the line from start to end
	var/list/path_turfs = get_line(start, end)

	for(var/turf/T in path_turfs)
		// Skip the start and end turfs
		if(T == start || T == end)
			continue

		// Check if this turf itself is dense (like a wall turf)
		if(T.density)
			return FALSE

		// Check for dense objects on this turf (walls, airlocks, etc)
		for(var/obj/O in T)
			// Skip objects that missiles can pass through
			if(!O.density)
				continue
			// Windows and grilles can be broken through - consider them passable
			if(istype(O, /obj/structure/window) || istype(O, /obj/structure/grille))
				continue
			// Dense object blocks the path
			return FALSE

	return TRUE

/// Checks if the launcher can fire
/obj/machinery/ship_combat/missile_launcher/proc/can_fire()
	if(machine_stat & (BROKEN|NOPOWER))
		return FALSE
	if(!anchored)
		return FALSE
	if(!loaded_missile)
		return FALSE
	return TRUE

/// Returns status info for the combat console UI
/obj/machinery/ship_combat/missile_launcher/proc/get_status()
	return list(
		"id" = launcher_id,
		"name" = name,
		"loaded" = loaded_missile ? 1 : 0,
		"missile_name" = loaded_missile ? loaded_missile["name"] : null,
		"missile_damage" = loaded_missile ? loaded_missile["damage"] : null,
		"ready" = can_fire(),
	)

// ========== CIRCUIT BOARD ==========

/obj/item/circuitboard/machine/ship_combat/missile_launcher
	name = "Missile Launcher"
	greyscale_colors = CIRCUIT_COLOR_COMMAND
	build_path = /obj/machinery/ship_combat/missile_launcher
	req_components = list(
		/datum/stock_part/servo = 2,
		/datum/stock_part/capacitor = 1,
	)
