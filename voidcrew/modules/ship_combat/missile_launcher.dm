// Ship Combat Missile Launcher
// A machine that holds and fires missiles at enemy ships
// Must be linked to a combat console via multitool

/obj/machinery/ship_combat/missile_launcher
	name = "missile launcher"
	desc = "A ship-mounted missile launcher system. Load missiles and link to a combat console with a multitool."
	icon = 'voidcrew/modules/shuttle/icons/shuttle.dmi'
	icon_state = "heater"
	density = TRUE
	anchored = TRUE
	power_channel = AREA_USAGE_EQUIP
	circuit = /obj/item/circuitboard/machine/ship_combat/missile_launcher

	/// Currently loaded missile
	var/obj/item/ship_combat_missile/loaded_missile
	/// Reference to our linked combat console
	var/datum/weakref/linked_console_ref
	/// Cooldown between fires
	COOLDOWN_DECLARE(fire_cooldown)
	/// Our unique ID for console linking
	var/launcher_id

/obj/machinery/ship_combat/missile_launcher/Initialize(mapload)
	. = ..()
	launcher_id = "[rand(1000, 9999)]"
	name = "[initial(name)] ([launcher_id])"

/obj/machinery/ship_combat/missile_launcher/Destroy()
	if(loaded_missile)
		QDEL_NULL(loaded_missile)
	unlink_console()
	return ..()

/obj/machinery/ship_combat/missile_launcher/examine(mob/user)
	. = ..()
	. += span_notice("Launcher ID: [launcher_id]")
	if(loaded_missile)
		. += span_notice("Loaded: [loaded_missile]")
		. += span_notice("Damage: [loaded_missile.damage]")
	else
		. += span_warning("No missile loaded.")
	var/obj/machinery/computer/camera_advanced/ship_combat/linked_console = linked_console_ref?.resolve()
	if(linked_console)
		. += span_notice("Linked to: [linked_console]")
	else
		. += span_warning("Not linked to a combat console. Use a multitool to link.")
	if(!COOLDOWN_FINISHED(src, fire_cooldown))
		. += span_warning("Reloading: [DisplayTimeText(COOLDOWN_TIMELEFT(src, fire_cooldown))]")

/obj/machinery/ship_combat/missile_launcher/update_overlays()
	. = ..()
	if(loaded_missile)
		. += mutable_appearance('icons/obj/weapons/guns/ammo.dmi', "84mm-heap")
	if(!COOLDOWN_FINISHED(src, fire_cooldown))
		. += mutable_appearance('icons/effects/effects.dmi', "sparks")

// ========== LOADING MECHANICS ==========

/obj/machinery/ship_combat/missile_launcher/attackby(obj/item/W, mob/user, list/modifiers, list/attack_modifiers)
	// Loading a missile
	if(istype(W, /obj/item/ship_combat_missile))
		if(machine_stat & BROKEN)
			to_chat(user, span_warning("[src] is broken!"))
			return
		if(!anchored)
			to_chat(user, span_warning("[src] isn't secured to the deck!"))
			return
		if(loaded_missile)
			to_chat(user, span_warning("There is already a missile loaded!"))
			return
		if(!user.transferItemToLoc(W, src))
			return

		loaded_missile = W
		user.visible_message(
			span_notice("[user] loads [W] into [src]."),
			span_notice("You load [W] into [src].")
		)
		update_appearance()
		return

	// Multitool linking
	if(istype(W, /obj/item/multitool))
		var/obj/item/multitool/tool = W
		tool.set_buffer(src)
		balloon_alert(user, "launcher buffered")
		to_chat(user, span_notice("You buffer [src] to the multitool. Use it on a combat console to link."))
		return

	// Standard deconstruction
	if(!loaded_missile)
		if(default_deconstruction_screwdriver(user, icon_state, icon_state, W))
			return
	if(default_deconstruction_crowbar(W))
		return
	return ..()

/obj/machinery/ship_combat/missile_launcher/on_deconstruction(disassembled)
	if(loaded_missile)
		loaded_missile.forceMove(drop_location())
		loaded_missile = null

// ========== UNLOADING ==========

/obj/machinery/ship_combat/missile_launcher/attack_hand(mob/user, list/modifiers)
	. = ..()
	if(.)
		return

	if(!loaded_missile)
		to_chat(user, span_warning("No missile to remove."))
		return

	user.put_in_hands(loaded_missile)
	user.visible_message(
		span_notice("[user] removes [loaded_missile] from [src]."),
		span_notice("You remove [loaded_missile] from [src].")
	)
	loaded_missile = null
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

// ========== FIRING ==========

/// Attempts to fire the loaded missile at the target turf
/obj/machinery/ship_combat/missile_launcher/proc/fire(turf/target, obj/structure/overmap/ship/target_ship, obj/structure/overmap/ship/source_ship, mob/user)
	if(!can_fire())
		return FALSE

	if(!target)
		if(user)
			to_chat(user, span_warning("No target selected!"))
		return FALSE

	// Calculate spawn position on the target ship's z-level
	// The missile will spawn outside the target ship and fly in
	var/turf/spawn_turf = get_missile_spawn_turf(target, target_ship)
	if(!spawn_turf)
		// Fallback to near the target if calculation fails
		spawn_turf = target

	// Create missile effect directly at the spawn location
	new loaded_missile.missile_effect_type(
		spawn_turf,
		target,
		target_ship,
		source_ship,
		loaded_missile.damage,
		loaded_missile.explosion_devastation,
		loaded_missile.explosion_heavy,
		loaded_missile.explosion_light,
		loaded_missile.explosion_flame
	)

	// Consume the loaded missile
	QDEL_NULL(loaded_missile)

	// Start cooldown
	COOLDOWN_START(src, fire_cooldown, MISSILE_LAUNCHER_COOLDOWN)

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
/obj/machinery/ship_combat/missile_launcher/proc/get_missile_spawn_turf(turf/target, obj/structure/overmap/ship/tgt_ship)
	if(!target)
		return null

	// Get ship bounds from the docking port
	var/min_x = target.x
	var/max_x = target.x
	var/min_y = target.y
	var/max_y = target.y
	var/center_x = target.x
	var/center_y = target.y

	if(tgt_ship?.shuttle)
		var/list/bounds = tgt_ship.shuttle.return_coords()
		if(bounds?.len >= 4)
			min_x = min(bounds[1], bounds[3])
			max_x = max(bounds[1], bounds[3])
			min_y = min(bounds[2], bounds[4])
			max_y = max(bounds[2], bounds[4])
			center_x = (min_x + max_x) / 2
			center_y = (min_y + max_y) / 2

	// Determine which direction the target is from the ship's center
	var/dx = target.x - center_x
	var/dy = target.y - center_y

	// How far outside the ship to spawn (between ship edge and black wall)
	var/spawn_dist = 10

	var/spawn_x = target.x
	var/spawn_y = target.y

	// The missile should come FROM the direction the target is in (relative to ship center)
	if(abs(dx) > abs(dy))
		// Flying east/west
		if(dx > 0)
			spawn_x = max_x + spawn_dist
		else
			spawn_x = min_x - spawn_dist
		spawn_y = target.y
	else if(abs(dy) > abs(dx))
		// Flying north/south
		if(dy > 0)
			spawn_y = max_y + spawn_dist
		else
			spawn_y = min_y - spawn_dist
		spawn_x = target.x
	else if(dx != 0)
		if(dx > 0)
			spawn_x = max_x + spawn_dist
		else
			spawn_x = min_x - spawn_dist
		spawn_y = target.y
	else if(dy != 0)
		if(dy > 0)
			spawn_y = max_y + spawn_dist
		else
			spawn_y = min_y - spawn_dist
		spawn_x = target.x
	else
		// Target is at ship center - pick random direction
		var/dir = pick(GLOB.cardinals)
		switch(dir)
			if(NORTH)
				spawn_y = max_y + spawn_dist
			if(SOUTH)
				spawn_y = min_y - spawn_dist
			if(EAST)
				spawn_x = max_x + spawn_dist
			if(WEST)
				spawn_x = min_x - spawn_dist

	return locate(spawn_x, spawn_y, target.z)

/// Checks if the launcher can fire
/obj/machinery/ship_combat/missile_launcher/proc/can_fire()
	if(machine_stat & (BROKEN|NOPOWER))
		return FALSE
	if(!anchored)
		return FALSE
	if(!loaded_missile)
		return FALSE
	if(!COOLDOWN_FINISHED(src, fire_cooldown))
		return FALSE
	return TRUE

/// Returns status info for the combat console UI
/obj/machinery/ship_combat/missile_launcher/proc/get_status()
	return list(
		"id" = launcher_id,
		"name" = name,
		"loaded" = !!loaded_missile,
		"missile_name" = loaded_missile?.name,
		"missile_damage" = loaded_missile?.damage,
		"ready" = can_fire(),
		"cooldown" = !COOLDOWN_FINISHED(src, fire_cooldown),
		"cooldown_time" = COOLDOWN_TIMELEFT(src, fire_cooldown),
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

// ========================================
// HELLFIRE MISSILE LAUNCHER
// An upgraded launcher that holds and fires multiple missiles at once
// ========================================

/obj/machinery/ship_combat/missile_launcher/hellfire
	name = "hellfire missile launcher"
	desc = "An advanced multi-missile launcher system. Can load and fire multiple missiles simultaneously for devastating barrages."
	icon_state = "heater" // TODO: unique icon
	circuit = /obj/item/circuitboard/machine/ship_combat/missile_launcher/hellfire

	/// Maximum number of missiles this launcher can hold
	var/max_missiles = 4
	/// List of loaded missiles
	var/list/obj/item/ship_combat_missile/loaded_missiles = list()

/obj/machinery/ship_combat/missile_launcher/hellfire/Initialize(mapload)
	. = ..()
	loaded_missiles = list()

/obj/machinery/ship_combat/missile_launcher/hellfire/Destroy()
	QDEL_LIST(loaded_missiles)
	return ..()

/obj/machinery/ship_combat/missile_launcher/hellfire/examine(mob/user)
	. = list()
	. += ..() // Get base examine text from /obj level
	. += span_notice("Launcher ID: [launcher_id]")
	. += span_notice("Missiles loaded: [length(loaded_missiles)]/[max_missiles]")
	if(length(loaded_missiles))
		for(var/obj/item/ship_combat_missile/missile in loaded_missiles)
			. += span_notice("  - [missile.name] ([missile.damage] damage)")
	else
		. += span_warning("No missiles loaded.")
	var/obj/machinery/computer/camera_advanced/ship_combat/linked_console = linked_console_ref?.resolve()
	if(linked_console)
		. += span_notice("Linked to: [linked_console]")
	else
		. += span_warning("Not linked to a combat console. Use a multitool to link.")
	if(!COOLDOWN_FINISHED(src, fire_cooldown))
		. += span_warning("Reloading: [DisplayTimeText(COOLDOWN_TIMELEFT(src, fire_cooldown))]")

/obj/machinery/ship_combat/missile_launcher/hellfire/update_overlays()
	. = ..()
	// Show missile count indicator
	if(length(loaded_missiles) >= 1)
		. += mutable_appearance('icons/obj/weapons/guns/ammo.dmi', "84mm-heap")
	if(length(loaded_missiles) >= 2)
		. += mutable_appearance('icons/effects/effects.dmi', "yourselfl") // glow effect for more missiles
	if(!COOLDOWN_FINISHED(src, fire_cooldown))
		. += mutable_appearance('icons/effects/effects.dmi', "sparks")

// ========== LOADING MECHANICS ==========

/obj/machinery/ship_combat/missile_launcher/hellfire/attackby(obj/item/W, mob/user, list/modifiers, list/attack_modifiers)
	// Loading a missile
	if(istype(W, /obj/item/ship_combat_missile))
		if(machine_stat & BROKEN)
			to_chat(user, span_warning("[src] is broken!"))
			return
		if(!anchored)
			to_chat(user, span_warning("[src] isn't secured to the deck!"))
			return
		if(length(loaded_missiles) >= max_missiles)
			to_chat(user, span_warning("[src] is fully loaded! ([max_missiles]/[max_missiles] missiles)"))
			return
		if(!user.transferItemToLoc(W, src))
			return

		loaded_missiles += W
		user.visible_message(
			span_notice("[user] loads [W] into [src]."),
			span_notice("You load [W] into [src]. ([length(loaded_missiles)]/[max_missiles])")
		)
		update_appearance()
		return

	// Multitool linking
	if(istype(W, /obj/item/multitool))
		var/obj/item/multitool/tool = W
		tool.set_buffer(src)
		balloon_alert(user, "launcher buffered")
		to_chat(user, span_notice("You buffer [src] to the multitool. Use it on a combat console to link."))
		return

	// Standard deconstruction
	if(!length(loaded_missiles))
		if(default_deconstruction_screwdriver(user, icon_state, icon_state, W))
			return
	if(default_deconstruction_crowbar(W))
		return
	return

/obj/machinery/ship_combat/missile_launcher/hellfire/on_deconstruction(disassembled)
	for(var/obj/item/ship_combat_missile/missile in loaded_missiles)
		missile.forceMove(drop_location())
	loaded_missiles.Cut()

// ========== UNLOADING ==========

/obj/machinery/ship_combat/missile_launcher/hellfire/attack_hand(mob/user, list/modifiers)
	if(machine_stat & (BROKEN|NOPOWER))
		return ..()

	if(!length(loaded_missiles))
		to_chat(user, span_warning("No missiles to remove."))
		return

	var/obj/item/ship_combat_missile/missile = loaded_missiles[length(loaded_missiles)]
	loaded_missiles -= missile
	user.put_in_hands(missile)
	user.visible_message(
		span_notice("[user] removes [missile] from [src]."),
		span_notice("You remove [missile] from [src]. ([length(loaded_missiles)]/[max_missiles] remaining)")
	)
	update_appearance()

// ========== FIRING ==========

/// Fires ALL loaded missiles at the target
/obj/machinery/ship_combat/missile_launcher/hellfire/fire(turf/target, obj/structure/overmap/ship/target_ship, obj/structure/overmap/ship/source_ship, mob/user)
	if(!can_fire())
		return FALSE

	if(!target)
		if(user)
			to_chat(user, span_warning("No target selected!"))
		return FALSE

	var/turf/spawn_turf = get_missile_spawn_turf(target, target_ship)
	if(!spawn_turf)
		spawn_turf = target

	// Stagger offsets for spread pattern (3 wide x 2 tall)
	var/list/stagger_offsets = list(
		list(0, 0),    // center
		list(-1, 0),   // left
		list(1, 0),    // right
		list(0, 1),    // up
	)

	var/missiles_fired = 0
	var/offset_index = 1
	for(var/obj/item/ship_combat_missile/missile in loaded_missiles)
		// Get staggered target position
		var/list/offset = stagger_offsets[offset_index]
		var/turf/offset_target = locate(target.x + offset[1], target.y + offset[2], target.z)
		if(!offset_target)
			offset_target = target

		new missile.missile_effect_type(
			spawn_turf,
			offset_target,
			target_ship,
			source_ship,
			missile.damage,
			missile.explosion_devastation,
			missile.explosion_heavy,
			missile.explosion_light,
			missile.explosion_flame
		)
		missiles_fired++

		// Cycle through offsets
		offset_index++
		if(offset_index > length(stagger_offsets))
			offset_index = 1

	// Consume all missiles
	QDEL_LIST(loaded_missiles)
	loaded_missiles = list()

	// Start cooldown (longer for hellfire)
	COOLDOWN_START(src, fire_cooldown, MISSILE_LAUNCHER_COOLDOWN * 1.5)

	// Use more power
	use_energy(MISSILE_LAUNCHER_POWER_FIRE * missiles_fired)

	// Play sound
	playsound(src, 'sound/vehicles/rocketlaunch.ogg', 100, TRUE)

	// Visual feedback
	visible_message(span_danger("[src] unleashes a barrage of [missiles_fired] missiles!"))
	if(user)
		to_chat(user, span_danger("Hellfire barrage away! [missiles_fired] missiles launched at [target_ship ? target_ship.name : "unknown"]!"))

	update_appearance()
	return TRUE

/// Checks if the launcher can fire
/obj/machinery/ship_combat/missile_launcher/hellfire/can_fire()
	if(machine_stat & (BROKEN|NOPOWER))
		return FALSE
	if(!anchored)
		return FALSE
	if(!length(loaded_missiles))
		return FALSE
	if(!COOLDOWN_FINISHED(src, fire_cooldown))
		return FALSE
	return TRUE

/// Returns status info for the combat console UI
/obj/machinery/ship_combat/missile_launcher/hellfire/get_status()
	var/total_damage = 0
	for(var/obj/item/ship_combat_missile/missile in loaded_missiles)
		total_damage += missile.damage
	return list(
		"id" = launcher_id,
		"name" = name,
		"loaded" = !!length(loaded_missiles),
		"missile_name" = length(loaded_missiles) ? "[length(loaded_missiles)]x missiles" : null,
		"missile_damage" = total_damage,
		"ready" = can_fire(),
		"cooldown" = !COOLDOWN_FINISHED(src, fire_cooldown),
		"cooldown_time" = COOLDOWN_TIMELEFT(src, fire_cooldown),
	)

// ========== CIRCUIT BOARD ==========

/obj/item/circuitboard/machine/ship_combat/missile_launcher/hellfire
	name = "Hellfire Missile Launcher"
	greyscale_colors = CIRCUIT_COLOR_SECURITY
	build_path = /obj/machinery/ship_combat/missile_launcher/hellfire
	req_components = list(
		/datum/stock_part/servo = 4,
		/datum/stock_part/capacitor = 2,
		/datum/stock_part/micro_laser = 2,
	)
