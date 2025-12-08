// Ship Combat Missile Launcher
// A machine that holds and fires missiles at enemy ships
// Must be linked to a combat console via multitool
// Missiles are loaded by dragging an armed missile structure onto the launcher

/obj/machinery/ship_combat/missile_launcher
	name = "missile launcher"
	desc = "A ship-mounted missile launcher system. Drag armed missiles onto it to load, then link to a combat console with a multitool. Holds up to 4 missiles."
	icon = 'voidcrew/icons/obj/machines/missile_launcher.dmi'
	icon_state = "0"
	density = TRUE
	anchored = TRUE
	power_channel = AREA_USAGE_EQUIP
	circuit = /obj/item/circuitboard/machine/ship_combat/missile_launcher

	/// List of loaded missile data (each entry is a list of missile properties)
	var/list/loaded_missiles = list()
	/// Maximum number of missiles that can be loaded
	var/max_missiles = 4
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
	loaded_missiles.Cut()
	unlink_console()
	return ..()

/obj/machinery/ship_combat/missile_launcher/examine(mob/user)
	. = ..()
	. += span_notice("Launcher ID: [launcher_id]")
	. += span_notice("Missiles: [length(loaded_missiles)]/[max_missiles]")
	if(length(loaded_missiles))
		for(var/list/missile_data in loaded_missiles)
			. += span_notice(" - [missile_data["name"]]: [missile_data["damage"]] damage")
	else
		. += span_warning("No missiles loaded. Drag armed missiles onto the launcher.")
	var/obj/machinery/computer/camera_advanced/ship_combat/linked_console = linked_console_ref?.resolve()
	if(linked_console)
		. += span_notice("Linked to: [linked_console]")
	else
		. += span_warning("Not linked to a combat console. Use a multitool to link.")

/obj/machinery/ship_combat/missile_launcher/update_icon_state()
	. = ..()
	icon_state = "[length(loaded_missiles)]"

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
	if(length(loaded_missiles) >= max_missiles)
		to_chat(user, span_warning("[src] is fully loaded!"))
		return
	if(missile.construction_state != MISSILE_STATE_ARMED)
		to_chat(user, span_warning("[missile] isn't armed! It needs a payload."))
		return

	var/list/fire_data = missile.get_fire_data()
	if(!fire_data)
		to_chat(user, span_warning("[missile] has no valid payload!"))
		return

	to_chat(user, span_notice("You begin loading [missile] into [src]..."))
	playsound(src, 'sound/machines/terminal/terminal_insert_disc.ogg', 50, TRUE)

	if(!do_after(user, missile.load_time, src))
		to_chat(user, span_warning("You stop loading the missile."))
		return

	// Verify everything is still valid
	if(QDELETED(missile) || !Adjacent(missile))
		return
	if(length(loaded_missiles) >= max_missiles)
		return
	if(missile.construction_state != MISSILE_STATE_ARMED)
		return

	// Load the missile - store both the fire data and the name
	var/list/missile_data = missile.get_fire_data()
	missile_data["name"] = missile.name
	loaded_missiles += list(missile_data)

	user.visible_message(
		span_notice("[user] loads [missile] into [src]."),
		span_notice("You load [missile] into [src]. ([length(loaded_missiles)]/[max_missiles])")
	)
	playsound(src, 'sound/machines/click.ogg', 50, TRUE)

	// Delete the missile structure
	qdel(missile)
	update_appearance()

/obj/machinery/ship_combat/missile_launcher/attackby(obj/item/W, mob/user, list/modifiers, list/attack_modifiers)
	// Multitool linking - add to launcher buffer list
	if(istype(W, /obj/item/multitool))
		var/obj/item/multitool/tool = W
		// Initialize the launcher buffer list if needed
		if(!islist(tool.buffer))
			tool.buffer = list()
		var/list/launcher_buffer = tool.buffer
		// Check if already in buffer
		if(src in launcher_buffer)
			balloon_alert(user, "already buffered")
			return
		launcher_buffer += src
		balloon_alert(user, "launcher buffered ([length(launcher_buffer)])")
		to_chat(user, span_notice("You buffer [src] to the multitool. [length(launcher_buffer)] launcher(s) buffered. Use on a combat console to link all."))
		return

	// Standard deconstruction - only allow if empty
	if(!length(loaded_missiles))
		if(default_deconstruction_screwdriver(user, icon_state, icon_state, W))
			return
	if(default_deconstruction_crowbar(W))
		return
	return ..()

/obj/machinery/ship_combat/missile_launcher/on_deconstruction(disassembled)
	// Loaded missiles are just lost on deconstruction
	loaded_missiles.Cut()

// ========== UNLOADING ==========

/obj/machinery/ship_combat/missile_launcher/attack_hand(mob/user, list/modifiers)
	. = ..()
	if(.)
		return

	if(!length(loaded_missiles))
		to_chat(user, span_warning("No missiles loaded."))
		return

	// Create a new armed missile with the stored warhead data
	to_chat(user, span_notice("You begin removing a missile from [src]..."))

	if(!do_after(user, 2 SECONDS, src))
		return

	if(!length(loaded_missiles))
		return

	// Get the last loaded missile data
	var/list/missile_data = loaded_missiles[length(loaded_missiles)]

	// Spawn a new armed missile structure
	var/obj/structure/ship_missile/new_missile = new(drop_location())

	// Create tracking circuit
	new_missile.tracking = new /obj/item/electronics/ship_missile_tracking(new_missile)

	// Create the appropriate warhead (bomb core)
	var/effect_type = missile_data["effect_type"]
	var/warhead_type
	if(effect_type == /obj/effect/ship_missile/emp)
		warhead_type = /obj/item/bombcore/missile/emp
	else if(effect_type == /obj/effect/ship_missile/chemical)
		warhead_type = /obj/item/bombcore/missile/chemical
	else
		// Determine by damage
		var/damage = missile_data["damage"]
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

	// Remove from loaded missiles
	loaded_missiles.len--

	user.visible_message(
		span_notice("[user] removes a missile from [src]."),
		span_notice("You remove a missile from [src]. ([length(loaded_missiles)]/[max_missiles])")
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

/// Attempts to fire a loaded missile at the target turf
/// spawn_offset_x/y are used to stagger missile spawn positions for volleys
/// approach_dir is the direction missiles come FROM (NORTH means missiles come from north, fly south)
/// missile_index specifies which missile to fire (1-based index, default 1 = first missile)
/obj/machinery/ship_combat/missile_launcher/proc/fire(turf/target, obj/structure/overmap/ship/target_ship, obj/structure/overmap/ship/source_ship, mob/user, spawn_offset_x = 0, spawn_offset_y = 0, approach_dir = null, missile_index = 1)
	if(!can_fire())
		return FALSE

	if(!target)
		if(user)
			to_chat(user, span_warning("No target selected!"))
		return FALSE

	// Validate missile index
	if(missile_index < 1 || missile_index > length(loaded_missiles))
		missile_index = 1

	// Get the specified missile
	var/list/missile_data = loaded_missiles[missile_index]

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
	var/effect_type = missile_data["effect_type"]
	new effect_type(
		spawn_turf,
		target,
		target_ship,
		source_ship,
		missile_data["damage"],
		missile_data["devastation"],
		missile_data["heavy"],
		missile_data["light"],
		missile_data["flame"],
		missile_data["icon_state"],
		missile_data["chem_reagents"],  // For chemical missiles
		missile_data["chem_area"],
		missile_data["chem_temp"]
	)

	// Remove the fired missile from the list
	loaded_missiles.Cut(missile_index, missile_index + 1)

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
/// approach_dir: If provided, missiles spawn from this direction. Otherwise auto-calculated.
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

	// Use provided direction, or pick random if none specified
	var/dir = approach_dir || pick(GLOB.cardinals)

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

/// Checks if the launcher can fire
/obj/machinery/ship_combat/missile_launcher/proc/can_fire()
	if(machine_stat & (BROKEN|NOPOWER))
		return FALSE
	if(!anchored)
		return FALSE
	if(!length(loaded_missiles))
		return FALSE
	return TRUE

/// Returns status info for the combat console UI
/obj/machinery/ship_combat/missile_launcher/proc/get_status()
	var/list/first_missile = length(loaded_missiles) ? loaded_missiles[1] : null
	return list(
		"id" = launcher_id,
		"name" = name,
		"loaded" = length(loaded_missiles),
		"max_missiles" = max_missiles,
		"missile_name" = first_missile ? first_missile["name"] : null,
		"missile_damage" = first_missile ? first_missile["damage"] : null,
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
