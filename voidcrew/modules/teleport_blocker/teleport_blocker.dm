/**
 * Bluespace damper: a ship machine that stops teleports onto or off its hull.
 *
 * A transporter with the Pattern Targeting node can lift anything off a docked or
 * orbiting ship, or drop boarders onto one. A damper standing on a ship refuses any
 * teleport with either end on that ship, unless both ends are on it, so the crew's own
 * deck-to-deck teleports still work.
 *
 * The block lives in check_teleport_valid() (code/datums/helper_datums/teleport.dm), so it
 * covers every unforced do_teleport() at once: transporters, hand teleporter portals,
 * quantum pads, wormholes, implants. Forced teleports skip it, the same as they skip
 * NOTELEPORT areas; the drop pod, the only forced teleport a player aims, checks it itself.
 *
 * Attackers knock dampers out with the Pattern Bleed exploit (teleport_blocker_hack.dm),
 * an EMP, or by walking up and switching it off.
 *
 * The crew gets through its own field two ways, both keyed to the damper's link_key
 * (teleport_blocker_pass.dm): a field pass clipped to a uniform lets its wearer through, and
 * a transporter pad linked to the damper carries its whole beam through. Resetting the key
 * with a multitool cuts off every pass and pad linked before.
 */

/// Every bluespace damper in the world. Teleport checks skip all of this while it is empty.
GLOBAL_LIST_EMPTY(teleport_blockers)

/obj/structure/overmap/ship
	/// world.time until which a Pattern Bleed hack holds this ship's dampers down
	var/teleport_field_hacked_until = 0

/obj/machinery/teleport_blocker
	name = "bluespace damper"
	desc = "A drum of humming coils that fills the hull around it with bluespace noise. Transporter crews hate it."
	icon = 'voidcrew/modules/teleport_blocker/icons/teleport_blocker.dmi'
	icon_state = "scrambler_off"
	base_icon_state = "scrambler"
	density = TRUE
	anchored = TRUE
	use_power = IDLE_POWER_USE
	idle_power_usage = BASE_MACHINE_IDLE_CONSUMPTION
	active_power_usage = BASE_MACHINE_ACTIVE_CONSUMPTION * 15
	circuit = /obj/item/circuitboard/machine/teleport_blocker
	/// Whether the crew has switched the field on
	var/field_on = FALSE
	/// world.time until which an EMP keeps the field down
	var/emp_until = 0
	/// Shared by every field pass and transporter pad linked to this damper. Resetting it revokes them all.
	var/link_key
	/// Ship found by the slow lookup, for dampers standing in an area that is not a voidcrew ship area
	var/datum/weakref/fallback_ship_ref
	COOLDOWN_DECLARE(ship_lookup_cooldown)

/obj/machinery/teleport_blocker/Initialize(mapload)
	. = ..()
	GLOB.teleport_blockers += src
	reset_link_key()
	update_appearance(UPDATE_ICON_STATE)

/// Issues a new link key, so every pass and pad linked to the old one stops working.
/obj/machinery/teleport_blocker/proc/reset_link_key()
	link_key = "[rand(100000, 999999)]-[world.time]"

/obj/machinery/teleport_blocker/Destroy()
	GLOB.teleport_blockers -= src
	fallback_ship_ref = null
	return ..()

/**
 * The ship this damper stands on, or null. Re-resolved on every call from the area it stands
 * in, so a damper carried to another hull, or a hull whose port changes ship, follows along.
 */
/obj/machinery/teleport_blocker/proc/get_protected_ship()
	var/area/here = get_area(src)
	if(!here)
		return null
	var/obj/structure/overmap/ship/ship
	if(istype(here, /area/shuttle/voidcrew))
		var/area/shuttle/voidcrew/ship_area = here
		ship = ship_area.shuttle_port?.current_ship
	else
		ship = fallback_ship_ref?.resolve()
		if(!ship && COOLDOWN_FINISHED(src, ship_lookup_cooldown))
			COOLDOWN_START(src, ship_lookup_cooldown, 5 SECONDS)
			ship = get_voidcrew_ship_for_turf(get_turf(src))
			fallback_ship_ref = ship ? WEAKREF(ship) : null
	if(QDELETED(ship) || !ship.shuttle?.shuttle_areas[here])
		return null
	return ship

/// Whether the machine is switched on and able to run, ignoring hacks.
/obj/machinery/teleport_blocker/proc/is_running()
	return field_on && anchored && !panel_open && is_operational && emp_until <= world.time

/// The ship this damper is shielding right now, or null when the field is down for any reason.
/obj/machinery/teleport_blocker/proc/get_blocked_ship()
	if(!is_running())
		return null
	var/obj/structure/overmap/ship/ship = get_protected_ship()
	if(!ship || ship.teleport_field_hacked_until > world.time)
		return null
	return ship

/obj/machinery/teleport_blocker/proc/toggle_field(mob/user)
	if(!anchored)
		balloon_alert(user, "not secured!")
		return
	if(panel_open)
		balloon_alert(user, "panel open!")
		return
	field_on = !field_on
	update_use_power(field_on ? ACTIVE_POWER_USE : IDLE_POWER_USE)
	balloon_alert(user, field_on ? "field up" : "field down")
	playsound(src, 'sound/machines/click.ogg', 40, TRUE)
	log_game("[key_name(user)] turned [src] [field_on ? "on" : "off"] at [AREACOORD(src)]")
	update_appearance(UPDATE_ICON_STATE)

/obj/machinery/teleport_blocker/interact(mob/user)
	. = ..()
	toggle_field(user)

/obj/machinery/teleport_blocker/click_alt(mob/user)
	toggle_field(user)
	return CLICK_ACTION_SUCCESS

/obj/machinery/teleport_blocker/item_interaction(mob/living/user, obj/item/tool, list/modifiers)
	if(istype(tool, /obj/item/clothing/accessory/field_pass))
		var/obj/item/clothing/accessory/field_pass/pass = tool
		pass.link_to(src)
		balloon_alert(user, "pass keyed")
		playsound(src, 'sound/machines/beep/twobeep.ogg', 30, TRUE)
		return ITEM_INTERACT_SUCCESS
	return ..()

/**
 * A multitool holding a transporter pad keys that pad to this damper. Any other multitool
 * resets the key, revoking every pass and pad keyed before.
 */
/obj/machinery/teleport_blocker/multitool_act(mob/living/user, obj/item/multitool/multi_tool)
	var/obj/machinery/transporter_pad/pad = multi_tool.buffer
	if(istype(pad))
		if(QDELETED(pad) || pad.get_protected_ship_for_link() != get_protected_ship())
			balloon_alert(user, "pad not aboard!")
			return ITEM_INTERACT_BLOCKING
		pad.link_to_blocker(src)
		balloon_alert(user, "pad keyed")
		playsound(src, 'sound/machines/beep/twobeep.ogg', 30, TRUE)
		return ITEM_INTERACT_SUCCESS
	balloon_alert(user, "resetting codes...")
	if(!multi_tool.use_tool(src, user, 3 SECONDS, volume = 50))
		return ITEM_INTERACT_BLOCKING
	reset_link_key()
	balloon_alert(user, "codes reset")
	log_game("[key_name(user)] reset the link key of [src] at [AREACOORD(src)]")
	return ITEM_INTERACT_SUCCESS

/obj/machinery/teleport_blocker/emp_act(severity)
	. = ..()
	if(. & EMP_PROTECT_SELF)
		return
	emp_until = max(emp_until, world.time + (1 MINUTES / max(severity, 1)))
	do_sparks(3, TRUE, src)
	update_appearance(UPDATE_ICON_STATE)

/// Picks up the end of an EMP or a hack, which nothing else announces to the machine.
/obj/machinery/teleport_blocker/process(seconds_per_tick)
	if(icon_state != current_icon_state())
		update_appearance(UPDATE_ICON_STATE)

/obj/machinery/teleport_blocker/proc/current_icon_state()
	if(panel_open)
		return "[base_icon_state]_open"
	if(!is_running())
		return "[base_icon_state]_off"
	var/obj/structure/overmap/ship/ship = get_protected_ship()
	if(ship && ship.teleport_field_hacked_until > world.time)
		return "[base_icon_state]_hacked"
	return base_icon_state

/obj/machinery/teleport_blocker/update_icon_state()
	icon_state = current_icon_state()
	return ..()

/obj/machinery/teleport_blocker/on_set_is_operational(old_value)
	update_appearance(UPDATE_ICON_STATE)

/obj/machinery/teleport_blocker/wrench_act(mob/living/user, obj/item/tool)
	if(default_unfasten_wrench(user, tool) == SUCCESSFUL_UNFASTEN)
		update_appearance(UPDATE_ICON_STATE)
	return ITEM_INTERACT_SUCCESS

/obj/machinery/teleport_blocker/screwdriver_act(mob/living/user, obj/item/tool)
	if(!default_deconstruction_screwdriver(user, "[base_icon_state]_open", "[base_icon_state]_off", tool))
		return NONE
	update_appearance(UPDATE_ICON_STATE)
	return ITEM_INTERACT_SUCCESS

/obj/machinery/teleport_blocker/crowbar_act(mob/living/user, obj/item/tool)
	if(default_deconstruction_crowbar(tool))
		return ITEM_INTERACT_SUCCESS
	return NONE

/obj/item/circuitboard/machine/teleport_blocker
	name = "Bluespace Damper"
	greyscale_colors = CIRCUIT_COLOR_SCIENCE
	build_path = /obj/machinery/teleport_blocker
	req_components = list(
		/obj/item/stack/ore/bluespace_crystal = 2,
		/datum/stock_part/capacitor = 2,
		/datum/stock_part/scanning_module = 1,
		/obj/item/stack/cable_coil = 5,
	)
	def_components = list(/obj/item/stack/ore/bluespace_crystal = /obj/item/stack/ore/bluespace_crystal/artificial)

/datum/design/board/teleport_blocker
	name = "Machine Design (Bluespace Damper)"
	desc = "The circuit board for a bluespace damper."
	id = "teleport_blocker"
	build_path = /obj/item/circuitboard/machine/teleport_blocker
	materials = list(
		/datum/material/glass = SHEET_MATERIAL_AMOUNT,
		/datum/material/gold = HALF_SHEET_MATERIAL_AMOUNT,
		/datum/material/bluespace = SHEET_MATERIAL_AMOUNT,
	)
	category = list(
		RND_CATEGORY_MACHINE + RND_SUBCATEGORY_MACHINE_TELEPORT,
	)
	departmental_flags = DEPARTMENT_BITFLAG_SCIENCE | DEPARTMENT_BITFLAG_ENGINEERING

// ---------------------------------------------------------------------------
// The teleport check
// ---------------------------------------------------------------------------

/// The ship whose live damper covers this turf, or null.
/proc/get_teleport_blocked_ship(turf/checked)
	var/area/checked_area = get_area(checked)
	if(!checked_area)
		return null
	for(var/obj/machinery/teleport_blocker/blocker as anything in GLOB.teleport_blockers)
		var/obj/structure/overmap/ship/ship = blocker.get_blocked_ship()
		if(ship?.shuttle?.shuttle_areas[checked_area])
			return ship
	return null

/**
 * Whether a damper refuses a teleport from `origin` to `destination`. Refused when either end
 * is on a ship with a live damper, unless both ends are on that same ship, or `teleported`
 * holds a pass for that ship, or a pad keyed to that ship's damper is running the beam.
 */
/proc/teleport_blocked_by_ship(atom/origin, atom/destination, atom/movable/teleported)
	if(!length(GLOB.teleport_blockers))
		return FALSE
	var/turf/origin_turf = get_turf(origin)
	var/turf/destination_turf = get_turf(destination)
	if(!origin_turf || !destination_turf)
		return FALSE
	var/obj/structure/overmap/ship/origin_ship = get_teleport_blocked_ship(origin_turf)
	var/obj/structure/overmap/ship/destination_ship = get_teleport_blocked_ship(destination_turf)
	if(origin_ship == destination_ship)
		return FALSE
	if(origin_ship && !teleport_field_lets_through(origin_ship, teleported))
		return TRUE
	if(destination_ship && !teleport_field_lets_through(destination_ship, teleported))
		return TRUE
	return FALSE

/// Every damper standing on a ship, live or not.
/proc/get_ship_teleport_blockers(obj/structure/overmap/ship/ship)
	. = list()
	if(!ship)
		return
	for(var/obj/machinery/teleport_blocker/blocker as anything in GLOB.teleport_blockers)
		if(blocker.get_protected_ship() == ship)
			. += blocker
