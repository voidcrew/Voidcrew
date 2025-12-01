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
	var/obj/machinery/computer/ship_combat/console = linked_console_ref?.resolve()
	if(console)
		. += span_notice("Linked to: [console]")
	else
		. += span_warning("Not linked to a combat console. Use a multitool to link.")
	if(!COOLDOWN_FINISHED(src, fire_cooldown))
		. += span_warning("Reloading: [DisplayTimeText(COOLDOWN_TIMELEFT(src, fire_cooldown))]")

/obj/machinery/ship_combat/missile_launcher/update_overlays()
	. = ..()
	if(loaded_missile)
		. += mutable_appearance('icons/obj/weapons/guns/ammo.dmi', "rocketwarhead")
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
/obj/machinery/ship_combat/missile_launcher/proc/link_console(obj/machinery/computer/ship_combat/console)
	if(!console)
		return FALSE
	unlink_console()
	linked_console_ref = WEAKREF(console)
	RegisterSignal(console, COMSIG_QDELETING, PROC_REF(on_console_deleted))
	return TRUE

/// Unlinks from the current console
/obj/machinery/ship_combat/missile_launcher/proc/unlink_console()
	var/obj/machinery/computer/ship_combat/console = linked_console_ref?.resolve()
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

	// Get launch position (in front of launcher based on direction)
	var/turf/launch_turf = get_step(src, dir)
	if(!launch_turf)
		launch_turf = get_turf(src)

	// Create missile effect
	new loaded_missile.missile_effect_type(
		launch_turf,
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
