// Ship Combat Missile Launcher
// A machine that holds and fires missiles at enemy ships
// Must be linked to a combat console via multitool
// Missiles are loaded by dragging an armed missile structure onto the launcher

/obj/machinery/ship_combat/missile_launcher
	name = "missile launcher"
	desc = "A ship-mounted missile launcher system. Drag an armed missile onto it to load, then link to a weapons system with a multitool. Use a wrench to secure or unsecure, or drag it onto a hull wall to sink it into the plating."
	icon = 'voidcrew/icons/obj/machines/missile_launcher.dmi'
	icon_state = "unloaded"
	density = TRUE
	anchored = TRUE
	dir = 4
	drag_slowdown = 2  // Heavy machinery
	power_channel = AREA_USAGE_EQUIP
	idle_power_usage = 0
	circuit = /obj/item/circuitboard/machine/ship_combat/missile_launcher
	pixel_x = -16
	pixel_y = -16
	wall_mountable = TRUE
	/// Loaded missile data (list of missile properties, or null if empty)
	var/list/loaded_missile
	/// Reference to our linked combat console
	var/datum/weakref/linked_console_ref
	/// Our unique ID for console linking
	var/launcher_id
	/// Time to load a missile
	var/load_time = MISSILE_LAUNCHER_LOAD_TIME

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

// Override shuttle rotation to prevent pixel offset rotation
// For centered 64x64 sprites, offset should always be -16, -16
/obj/machinery/ship_combat/missile_launcher/shuttleRotate(rotation, params)
	params &= ~ROTATE_OFFSET  // Don't rotate pixel offsets for this sprite
	return ..()

/obj/machinery/ship_combat/missile_launcher/examine(mob/user)
	. = ..()
	. += span_notice("Launcher ID: [launcher_id]")
	if(loaded_missile)
		. += span_notice("Loaded: [loaded_missile["name"]] ([loaded_missile["damage"]] damage)")
	else
		. += span_warning("No missile loaded. Drag an armed missile onto the launcher.")
	if(!is_on_exterior())
		. += span_warning("NOT ON EXTERIOR - Must be adjacent to outside of ship to fire!")
	var/obj/machinery/computer/camera_advanced/ship_combat/linked_console = linked_console_ref?.resolve()
	if(linked_console)
		. += span_notice("Linked to: [linked_console]")
	else
		. += span_warning("Not linked to a weapons system. Use a multitool to link.")

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

	// Get fire data AFTER do_after succeeds to avoid orphaning grenades on failure
	var/list/fire_data = missile.get_fire_data()
	if(!fire_data)
		to_chat(user, span_warning("[missile] has no valid payload!"))
		return

	// If this is a chemical missile, move the grenade into the launcher to protect it from qdel
	var/obj/item/grenade/chem_grenade/extracted_grenade = fire_data["grenade"]
	if(extracted_grenade)
		extracted_grenade.forceMove(src)  // Move into launcher - hidden from view and safe from missile qdel

	// Load the missile
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

// Wrench to anchor/unanchor
/obj/machinery/ship_combat/missile_launcher/wrench_act(mob/living/user, obj/item/tool)
	. = ITEM_INTERACT_BLOCKING
	if(loaded_missile)
		to_chat(user, span_warning("Unload the missile first!"))
		return
	default_unfasten_wrench(user, tool)
	invalidate_exterior_cache()  // Position may have changed
	eject_from_wall(user)  // Loose inside hull plating is a dead end - pop it onto the deck
	return ITEM_INTERACT_SUCCESS

/obj/machinery/ship_combat/missile_launcher/after_wall_mount(mob/user)
	attempt_auto_link()

// Alt+click to rotate when unwrenched
/obj/machinery/ship_combat/missile_launcher/click_alt(mob/user)
	if(!user.can_perform_action(src, NEED_HANDS))
		return CLICK_ACTION_BLOCKING
	if(anchored)
		to_chat(user, span_warning("Unwrench [src] first to rotate it!"))
		return CLICK_ACTION_BLOCKING
	if(loaded_missile)
		to_chat(user, span_warning("Unload the missile first!"))
		return CLICK_ACTION_BLOCKING
	// Rotate through cardinal directions
	setDir(turn(dir, -90))
	balloon_alert(user, "rotated [dir2text(dir)]")
	return CLICK_ACTION_SUCCESS

/obj/machinery/ship_combat/missile_launcher/attackby(obj/item/W, mob/user, list/modifiers, list/attack_modifiers)
	// Multitool linking - store self in buffer
	if(istype(W, /obj/item/multitool))
		var/obj/item/multitool/tool = W
		// Store just this launcher in the buffer (single item, not list)
		tool.buffer = src
		balloon_alert(user, "launcher buffered")
		to_chat(user, span_notice("You buffer [src] to the multitool. Use on a weapons system to link."))
		return TRUE

	// Standard deconstruction - only allow if empty
	if(!loaded_missile)
		if(default_deconstruction_screwdriver(user, icon_state, icon_state, W))
			return
	if(default_deconstruction_crowbar(W))
		return
	return ..()

/obj/machinery/ship_combat/missile_launcher/on_deconstruction(disassembled)
	// Clean up any chemical grenades stored in the launcher
	for(var/obj/item/grenade/chem_grenade/grenade in contents)
		if(disassembled)
			grenade.forceMove(drop_location())  // Drop grenade if disassembled cleanly
		else
			qdel(grenade)  // Delete grenade if destroyed
	// Loaded missile data is lost on deconstruction
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
	if(!new_missile)
		return

	// Create tracking circuit
	new_missile.tracking = new /obj/item/electronics/ship_missile_tracking(new_missile)

	// Create the appropriate warhead (bomb core)
	// Note: Chemical missiles use grenades which can't be recreated from stored data
	var/effect_type = loaded_missile["effect_type"]
	var/warhead_type
	if(effect_type == /obj/effect/ship_missile/chemical)
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
	// Check if SSovermap is initialized
	if(!SSovermap?.initialized)
		return

	// Already linked
	if(linked_console_ref?.resolve())
		return

	// Only auto-link if on exterior of ship
	if(!is_on_exterior())
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
/obj/machinery/ship_combat/missile_launcher/proc/fire(turf/target, obj/structure/overmap/target_ship, obj/structure/overmap/ship/source_ship, mob/user, spawn_offset_x = 0, spawn_offset_y = 0, approach_dir = null)
	if(!can_fire(target_ship))
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

	// Store missile data before clearing
	var/effect_type = loaded_missile["effect_type"]
	var/obj/item/grenade/chem_grenade/grenade_to_pass = loaded_missile["grenade"]
	var/missile_damage = loaded_missile["damage"]
	var/missile_devastation = loaded_missile["devastation"]
	var/missile_heavy = loaded_missile["heavy"]
	var/missile_light = loaded_missile["light"]
	var/missile_flame = loaded_missile["flame"]
	var/missile_icon_state = loaded_missile["icon_state"]

	// Clear the loaded missile
	loaded_missile = null

	// Use power
	use_energy(MISSILE_LAUNCHER_POWER_FIRE)

	// Play sound (extrarange so it's audible, pressure_affected = FALSE for space)
	playsound(src, 'voidcrew/sound/machines/rocket/rocket_launch.ogg', 100, TRUE, extrarange = 20, pressure_affected = FALSE)

	// Create visual effect of missile flying off-screen from the launcher
	var/offset_x = -16
	var/offset_y = -16
	switch(dir)
		if(NORTH)
			offset_x = -16
			offset_y = 0
		if(SOUTH)
			offset_x = -16
			offset_y = -32
		if(EAST)
			offset_x = 0
			offset_y = -16
		if(WEST)
			offset_x = -32
			offset_y = -16
	new /obj/effect/temp_visual/missile_launch_visual(get_turf(src), dir, offset_x, offset_y)

	// Visual feedback
	visible_message(span_danger("[src] fires a missile!"))
	if(user)
		to_chat(user, span_notice("Missile away! Target: [target_ship ? target_ship.name : "unknown"]"))

	// Delay actual missile spawn so the launch visual can fly off-screen first
	addtimer(CALLBACK(GLOBAL_PROC, GLOBAL_PROC_REF(create_ship_missile), effect_type, spawn_turf, target, target_ship, source_ship, missile_damage, missile_devastation, missile_heavy, missile_light, missile_flame, missile_icon_state, grenade_to_pass), 1.5 SECONDS)

	update_appearance()
	return TRUE

/// Checks if the launcher can fire. Pass the console's locked target (if any)
/// so the yellow-zone siege exception can be evaluated.
/obj/machinery/ship_combat/missile_launcher/proc/can_fire(obj/structure/overmap/locked_target = null)
	if(machine_stat & (BROKEN|NOPOWER))
		return FALSE
	if(!anchored)
		return FALSE
	if(!loaded_missile)
		return FALSE
	if(!is_on_exterior())
		return FALSE
	// Zone restriction check - weapons disabled in neutral and contested zones,
	// unless this is a siege shot against a raidable player outpost
	if(!SSovermap_zones.weapons_allowed_at(src) && !is_siege_shot_allowed(locked_target))
		return FALSE
	return TRUE

/**
 * The yellow-zone siege exception: missile launchers may fire outside the red
 * zone when (and only when) the locked target is a raidable player outpost and
 * the firing ship isn't sitting in patrolled green space. Define-gated so it
 * can be flipped off if it warps ship-vs-ship balance.
 */
/obj/machinery/ship_combat/missile_launcher/proc/is_siege_shot_allowed(obj/structure/overmap/locked_target)
#ifdef PLAYER_OUTPOST_YELLOW_SIEGE_ENABLED
	if(!istype(locked_target, /obj/structure/overmap/dynamic/player_outpost))
		return FALSE
	var/obj/structure/overmap/dynamic/player_outpost/outpost = locked_target
	if(!outpost.raidable)
		return FALSE
	var/obj/structure/overmap/ship/our_ship = get_ship_from_atom(src)
	if(!our_ship)
		return FALSE
	var/zone_type = SSovermap_zones.get_zone_type(get_turf(our_ship))
	return zone_type == ZONE_YELLOW || zone_type == ZONE_RED
#else
	return FALSE
#endif

/// Returns status info for the combat console UI
/obj/machinery/ship_combat/missile_launcher/proc/get_status(obj/structure/overmap/locked_target = null)
	var/on_ext = is_on_exterior()
	return list(
		"id" = launcher_id,
		"name" = name,
		"loaded" = loaded_missile ? 1 : 0,
		"missile_name" = loaded_missile ? loaded_missile["name"] : null,
		"missile_damage" = loaded_missile ? loaded_missile["damage"] : null,
		"ready" = can_fire(locked_target),
		"on_exterior" = on_ext,
		"enabled" = on_ext && anchored && !(machine_stat & (BROKEN|NOPOWER)),  // Can potentially fire (positioned correctly)
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
