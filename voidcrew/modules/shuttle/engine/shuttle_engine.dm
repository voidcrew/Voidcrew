/obj/machinery/power/shuttle_engine/connect_to_shuttle(mapload, obj/docking_port/mobile/port, obj/docking_port/stationary/dock)
	if(!port)
		return FALSE
	connected_ship_ref = WEAKREF(port)
	port.engine_list |= src
	port.current_engine_power += engine_power
	if(mapload)
		port.initial_engine_power += engine_power
	// We are on a ship again, so stop listening for one. Leaving the element on would
	// re-run this proc on the next COMSIG_TURF_ADDED_TO_SHUTTLE and double-count power.
	RemoveElement(/datum/element/connect_loc, connections)

/**
 * Full replacement for tg's unsync_ship() (code/game/shuttle_engines.dm) - this file is
 * included after it, so this body is the one that runs.
 *
 * tg only unsyncs on Destroy() or when a player unwrenches an engine, where leaving it
 * orphaned is correct. Voidcrew also unsyncs from /obj/structure/overmap/ship/refresh_engines(),
 * which runs on *every burn* - and tg's version removes the connect_loc element that is the
 * only automatic path back onto a ship. A mapped engine never had that element to begin with
 * (it is only added when a freshly built engine fails to find a shuttle), so one bad frame
 * used to unbind a thruster for the rest of the round, with no message and no way back short
 * of a player unwrenching and re-wrenching it.
 *
 * Re-arm the listener instead, so the engine rejoins the moment its turf belongs to a ship
 * again - which is exactly what tg does for a new engine that found no shuttle.
 */
/obj/machinery/power/shuttle_engine/unsync_ship()
	var/obj/docking_port/mobile/port = connected_ship_ref?.resolve()
	if(port)
		port.engine_list -= src
		port.current_engine_power -= initial(engine_power)
	connected_ship_ref = null
	// Not while being deleted, and not for an engine a player has deliberately unbolted.
	if(QDELETED(src) || !anchored)
		RemoveElement(/datum/element/connect_loc, connections)
		return
	AddElement(/datum/element/connect_loc, connections)

/**
  * ## Engine Thrusters
  * The workhorse of any movable ship, these engines (usually) take in some kind fuel and produce thrust to move ships.
  * Voidcrew subtype is to add unique icons, and being able to enable/disable it at will.
  */
/obj/machinery/power/shuttle_engine/ship
	name = "shuttle thruster"
	desc = "A thruster for shuttles."
	icon = 'voidcrew/modules/shuttle/icons/shuttle.dmi'
	circuit = /obj/item/circuitboard/machine/engine
	can_atmos_pass = ATMOS_PASS_NO //so people can actually tend to their engines

	///How much thrust this engine generates when burned fully.
	engine_power = 0

	///Whether or not the engine is enabled and can be used. Controlled from helm consoles and by hitting with a multitool.
	var/enabled = TRUE
	///I don't really know what this is but it's used a lot
	var/thruster_active = FALSE
	///One-shot latch so refresh_engines() logs an area/bounds mismatch once per episode, not every helm UI tick.
	var/logged_area_mismatch = FALSE

	///Icon when the machine is screwdrivered open, takes priority over the other two
	var/icon_state_open = "burst_plasma_open"
	///The icon when the machine is closed and active.
	var/icon_state_closed = "burst_plasma"
	///The icon when the machine is closed, but NOT active.
	var/icon_state_off = "burst_plasma_off"

/**
  * Uses up a specified percentage of the fuel cost, and returns the amount of thrust if successful.
  * Fuel consumption scales with ship mass - heavier ships use more fuel per burn.
  * * percentage - The percentage of total thrust that should be used
  * * ship_mass - The mass of the ship, used to scale fuel consumption
  * * burn_seconds - How many seconds of burn this call represents; fuel costs are per second of full burn
  */
/obj/machinery/power/shuttle_engine/ship/proc/burn_engine(percentage = 100, ship_mass = REFERENCE_SHIP_MASS, burn_seconds = 1)
	SHOULD_CALL_PARENT(TRUE)
	update_appearance(UPDATE_ICON)
	return FALSE

/**
  * Helper to calculate the mass multiplier for fuel consumption.
  * Returns a value >= 1 that scales fuel usage based on ship mass.
  * * ship_mass - The mass of the ship
  */
/obj/machinery/power/shuttle_engine/ship/proc/get_mass_fuel_multiplier(ship_mass)
	if(ship_mass <= 0)
		return 1
	return max(ship_mass / REFERENCE_SHIP_MASS, 0.5) // Minimum 0.5x for very small ships

/**
  * Returns how much "Fuel" is left. (For use with engine displays.)
  */
/obj/machinery/power/shuttle_engine/ship/proc/return_fuel()
	return

/**
  * Returns how much "Fuel" can be held. (For use with engine displays.)
  */
/obj/machinery/power/shuttle_engine/ship/proc/return_fuel_cap()
	return

/**
  * Updates the engine state.
  * All functions should return if the parent function returns false.
  */
/obj/machinery/power/shuttle_engine/ship/proc/update_engine()
	thruster_active = !panel_open
	return thruster_active

/**
  * Updates the engine's icon and engine state.
  */
/obj/machinery/power/shuttle_engine/ship/update_icon_state()
	. = ..()
	update_engine() //Calls this so it sets the accurate icon
	if(panel_open)
		icon_state = icon_state_open
	else if(thruster_active)
		icon_state = icon_state_closed
	else
		icon_state = icon_state_off

/obj/machinery/power/shuttle_engine/ship/Initialize(mapload)
	. = ..()
	update_appearance(UPDATE_ICON)

/**
 * The placement rule, said out loud. A thruster only registers once the tile beneath it
 * belongs to a ship's hull, and on a scratch-built hull that is exactly the tile players
 * bolt them onto LAST - the nacelle row outside the surveyed room. The failure used to be
 * completely silent (the helm just lists nothing), which cost a round-6 crew fifteen
 * minutes of cable/SMES/terminal/welding folklore before an admin explained it.
 */
/obj/machinery/power/shuttle_engine/ship/examine(mob/user)
	. = ..()
	var/obj/docking_port/mobile/port = connected_ship_ref?.resolve()
	if(port)
		. += span_notice("It is registered to [port.name].")
	else
		. += span_warning("It is not registered to any vessel. A thruster only counts once the tile \
			under it is part of a ship's hull - bolt it down on the ship's own deck, normally along \
			the outer edge. On a scratch-built ship, plating outside the surveyed hull does not \
			count until a hull survey claims it.")
	if(!enabled)
		. += span_warning("It has been switched off by hand. Click it to switch it back on.")

/**
 * Why this thruster is missing from the helm, or registered but producing nothing - one
 * plain sentence for the helm's engine refresh to read back, or null when it is healthy.
 * `port` is the hull doing the asking.
 */
/obj/machinery/power/shuttle_engine/ship/proc/link_refusal_reason(obj/docking_port/mobile/port)
	if(!port)
		return null
	if(!(src in port.engine_list))
		if(!anchored)
			return "not wrenched to the deck."
		var/area/mount_area = get_area(src)
		if(!port.shuttle_areas[mount_area])
			return "the tile under it is not part of the hull. A thruster only registers on the \
				ship's own deck - claim that tile into the hull with a hull survey, then refresh again."
		return "not registered. Wrench it loose and bolt it back down to re-register it."
	update_engine()
	if(panel_open)
		return "its maintenance panel is open."
	if(!enabled)
		return "switched off by hand. Click it in person to switch it back on."
	return thrust_refusal_reason()

/**
 * The thrust-specific half of link_refusal_reason(), split out so each engine family can
 * name its own missing prerequisite instead of a generic shrug. Null when healthy.
 */
/obj/machinery/power/shuttle_engine/ship/proc/thrust_refusal_reason()
	if(!thruster_active)
		return "not producing thrust."
	return null

/**
 * A thruster bolted down on ground no ship owns will never appear on any helm, and
 * nothing else ever says so - the wrench click is the one moment the builder is standing
 * right there, so tell them now instead of letting the helm list nothing later.
 */
/obj/machinery/power/shuttle_engine/ship/default_unfasten_wrench(mob/user, obj/item/tool, time = 20)
	. = ..()
	if(. == SUCCESSFUL_UNFASTEN && anchored && !connected_ship_ref?.resolve())
		balloon_alert(user, "no vessel claims this tile!")
		to_chat(user, span_warning("[src] is bolted down, but the tile under it is not part of any \
			ship's hull, so no helm will register it. Mount it on your ship's own deck - on a \
			scratch-built hull, the tile has to be claimed by a hull survey first."))

/obj/machinery/power/shuttle_engine/ship/attack_hand(mob/living/user, list/modifiers)
	. = ..()
	if(!do_after(user, MIN_TOOL_SOUND_DELAY, target=src))
		return ..()
	enabled = !enabled
	to_chat(user, span_notice("You [enabled ? "enable" : "disable"] \the [src]."))
	update_appearance(UPDATE_ICON)

/obj/machinery/power/shuttle_engine/ship/screwdriver_act(mob/living/user, obj/item/tool)
	. = ..()
	if(default_deconstruction_screwdriver(user, icon_state_open, icon_state_closed, tool))
		return TRUE
	update_appearance(UPDATE_ICON)
	return FALSE

/obj/machinery/power/shuttle_engine/ship/crowbar_act(mob/living/user, obj/item/tool)
	. = ..()
	if(!panel_open)
		user.balloon_alert(user, "open panel first!")
		return FALSE
	if(default_deconstruction_crowbar(tool))
		return TRUE
	return FALSE
