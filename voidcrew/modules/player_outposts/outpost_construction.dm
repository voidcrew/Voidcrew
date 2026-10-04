/**
 * # Outpost Construction Console
 *
 * The ship construction console rebound to a player outpost: same internal
 * RCD/RTD/RPD/RLD tools and ore-silo plumbing, same remote drone, but the
 * build envelope is the outpost's fixed rectangular build region instead of
 * shuttle areas, so all the shuttle-expansion machinery is switched off.
 * Nothing here flies, so there is no docked-state gate either.
 *
 * Access is per-ckey: the outpost owner plus anyone they authorize at the
 * management console.
 */

/obj/item/circuitboard/computer/player_outpost_construction
	name = "Outpost Construction (Computer Board)"
	greyscale_colors = CIRCUIT_COLOR_ENGINEERING
	build_path = /obj/machinery/computer/camera_advanced/base_construction/ship/outpost

/obj/machinery/computer/camera_advanced/base_construction/ship/outpost
	name = "outpost construction console"
	desc = "A console for building out the outpost. Control a remote drone to construct and modify anything within the claim's survey bounds."
	circuit = /obj/item/circuitboard/computer/player_outpost_construction
	/// The outpost this console builds for (set by link_interior_machinery, or found on Initialize for rebuilt consoles)
	var/obj/structure/overmap/dynamic/player_outpost/outpost

/obj/machinery/computer/camera_advanced/base_construction/ship/outpost/Destroy()
	stop_elevator_planning()
	if(outpost?.construction_console == src)
		outpost.construction_console = null
	outpost = null
	return ..()

/// Rebuilt consoles relink to the claim containing their actual footprint.
/obj/machinery/computer/camera_advanced/base_construction/ship/outpost/attempt_ship_connection()
	outpost = get_outpost_from_atom(src)
	if(outpost && !outpost.construction_console)
		outpost.construction_console = src
	return !!outpost

/obj/machinery/computer/camera_advanced/base_construction/ship/outpost/connect_to_shuttle(mapload, obj/docking_port/mobile/voidcrew/port, obj/docking_port/stationary/dock)
	return // not shuttle machinery

/// Builder authorization instead of ship crew membership
/obj/machinery/computer/camera_advanced/base_construction/ship/outpost/is_crew_member(mob/user)
	if(isAdminGhostAI(user))
		return TRUE
	if(!attempt_ship_connection())
		return FALSE
	return outpost.can_build(user)

/// Outposts don't fly: operable whenever linked
/obj/machinery/computer/camera_advanced/base_construction/ship/outpost/can_operate()
	return attempt_ship_connection()

/obj/machinery/computer/camera_advanced/base_construction/ship/outpost/get_operate_error()
	return "No outpost registry link established."

/obj/machinery/computer/camera_advanced/base_construction/ship/outpost/get_docking_port()
	return null

/obj/machinery/computer/camera_advanced/base_construction/ship/outpost/find_spawn_spot()
	if(outpost?.arrival_turf)
		return outpost.arrival_turf
	return get_turf(src)

// "Inside" = already adopted into the outpost's powered area, or an installed service room's own
// area: it was outpost_area before its room joined it (outpost_room_power.dm), and the drone should
// keep treating it as inside the same way. Building on anything else routes through the expansion
// branch of the build actions (expand_shuttle_to_turf on !was_in_shuttle), which adopts the new turf
// into the area so it gets APC power coverage and gravity.
/obj/machinery/computer/camera_advanced/base_construction/ship/outpost/is_in_shuttle_area(turf/T)
	if(outpost?.outpost_area && (get_area(T) == outpost.outpost_area))
		return TRUE
	var/datum/outpost_upgrade/service/room = outpost?.upgrade_at_turf(T)
	return istype(room) && room.installed && (get_area(T) == room.installed_area)

/obj/machinery/computer/camera_advanced/base_construction/ship/outpost/is_adjacent_to_shuttle(turf/T)
	return FALSE

/obj/machinery/computer/camera_advanced/base_construction/ship/outpost/can_move_to(turf/T)
	return T && outpost?.is_turf_buildable(T)

/// The docked cargo ferry is not outpost ground (outpost_cargo_dock.dm).
/obj/machinery/computer/camera_advanced/base_construction/ship/outpost/can_build_at(turf/T)
	return T && outpost?.is_turf_buildable(T) && !outpost.cargo_ferry_covers(T)

// No shuttle to grow: "expansion" just pulls the freshly built turf into the
// outpost's area
/obj/machinery/computer/camera_advanced/base_construction/ship/outpost/expand_shuttle_to_turf(turf/T, mob/user)
	if(!outpost)
		return FALSE
	outpost.adopt_turf(T)
	return TRUE

// Expansion is bounded by the claim's survey region, not shuttle dimensions
/obj/machinery/computer/camera_advanced/base_construction/ship/outpost/check_expansion_dimensions(turf/new_turf, obj/docking_port/mobile/port)
	return outpost?.is_turf_buildable(new_turf)

/obj/machinery/computer/camera_advanced/base_construction/ship/outpost/cleanup_deconstructed_turfs()
	return

/obj/machinery/computer/camera_advanced/base_construction/ship/outpost/reset_fans()
	last_operation_message = "Outposts have no edge airlocks to fan."
	last_operation_success = FALSE
	return FALSE

/obj/machinery/computer/camera_advanced/base_construction/ship/outpost/relocate_docking_port(obj/machinery/door/new_door)
	last_operation_message = "Outpost docking pads are fixed."
	last_operation_success = FALSE
	return FALSE

// The ship construction UI (port relocator, ship status, ship name) has nothing
// relevant to say about an outpost - skip it and drop straight into drone mode.
/obj/machinery/computer/camera_advanced/base_construction/ship/outpost/attack_hand(mob/user, list/modifiers)
	if(machine_stat & (NOPOWER|BROKEN))
		return
	enter_construction_mode(user)

// ===== SERVICE ROOM WALLS AND FLOORS =====

/**
 * Whether `the_rcd` may take `target`, an indestructible wall or floor, down to plating.
 *
 * Service room walls and floors are indestructible turfs (outpost_service_rooms.dm), so nothing a
 * visitor carries can take them apart. The outpost's own construction drone can, so the owner and
 * their builders rework a room like the rest of the outpost. The rule lives on the turfs' RCD procs
 * below, which every drone tool reaches, rather than in the drone's tool code.
 *
 * * Only this outpost's console, run by one of its builders, on a tile of one of its installed service
 *   rooms inside its build region. Hand RCDs, ship consoles, the ship bay console and every other site
 *   (trader outposts, berths, derelicts) never match.
 * * A tile holding a room fixture is refused, so fixtures keep the floor they stand on.
 * * Nothing is refunded. The room came with its walls, and a refund would make every room a pile of
 *   free metal. The drone's refund (get_deconstruction_materials()) pays nothing for these types.
 */
/proc/outpost_drone_may_strip(turf/target, obj/item/construction/rcd/the_rcd, mob/user)
	if(!istype(the_rcd, /obj/item/construction/rcd/internal/ship))
		return FALSE
	var/obj/item/construction/rcd/internal/ship/drone_rcd = the_rcd
	var/obj/machinery/computer/camera_advanced/base_construction/ship/outpost/console = drone_rcd.ship_console
	if(!istype(console) || QDELETED(console) || !console.attempt_ship_connection())
		return FALSE
	if(!console.is_crew_member(user) || !console.can_build_at(target))
		return FALSE
	var/datum/outpost_upgrade/service/room = console.outpost.upgrade_at_turf(target)
	if(!istype(room) || !room.installed)
		return FALSE
	for(var/obj/fixture in target)
		// Outpost cable is protected but never a fixture (outpost_room_power.dm): the drone strips
		// the floor or wall under it, and the cable is left showing on the plating.
		if(istype(fixture, /obj/structure/cable))
			continue
		if((ismachinery(fixture) || isstructure(fixture)) && ((fixture.resistance_flags & INDESTRUCTIBLE) || HAS_TRAIT(fixture, TRAIT_OUTPOST_PROPERTY)))
			return FALSE
	return TRUE

/// Takes a service room wall or floor down to plating over the ground the room was built on
/proc/outpost_strip_service_turf(turf/target)
	var/list/ground = list()
	for(var/layer in (islist(target.baseturfs) ? target.baseturfs : list(target.baseturfs)))
		// Never leave an indestructible layer for the next deconstruction to uncover
		if(!ispath(layer, /turf/closed/indestructible) && !ispath(layer, /turf/open/indestructible))
			ground += layer
	if(!length(ground))
		ground += /turf/baseturf_bottom
	return !!target.ChangeTurf(/turf/open/floor/plating, ground, CHANGETURF_INHERIT_AIR)

// Delays match the ordinary wall and floor (walls.dm, floor.dm)
/turf/closed/indestructible/rcd_vals(mob/user, obj/item/construction/rcd/the_rcd)
	if(the_rcd?.mode == RCD_DECONSTRUCT && outpost_drone_may_strip(src, the_rcd, user))
		return list("delay" = 4 SECONDS, "cost" = 0)
	return ..()

/turf/closed/indestructible/rcd_act(mob/user, obj/item/construction/rcd/the_rcd, list/rcd_data)
	if(rcd_data["[RCD_DESIGN_MODE]"] == RCD_DECONSTRUCT && outpost_drone_may_strip(src, the_rcd, user))
		return outpost_strip_service_turf(src)
	return ..()

/turf/open/indestructible/rcd_vals(mob/user, obj/item/construction/rcd/the_rcd)
	if(the_rcd?.mode == RCD_DECONSTRUCT && outpost_drone_may_strip(src, the_rcd, user))
		return list("delay" = 5 SECONDS, "cost" = 0)
	return ..()

/turf/open/indestructible/rcd_act(mob/user, obj/item/construction/rcd/the_rcd, list/rcd_data)
	if(rcd_data["[RCD_DESIGN_MODE]"] == RCD_DECONSTRUCT && outpost_drone_may_strip(src, the_rcd, user))
		return outpost_strip_service_turf(src)
	return ..()

/**
 * Only the outpost's own people build inside a service room (outpost_service_build_allowed(), abuse
 * review B-12), plus the builders the owner named. The room's floors turned every RCD away until the
 * drone stripped one; the plating left behind would take a visitor's walls and grilles.
 */
/obj/item/construction/rcd/rcd_create(atom/target, mob/user)
	if(mode != RCD_DECONSTRUCT && !outpost_service_build_allowed(user, target))
		var/obj/structure/overmap/dynamic/player_outpost/home = get_outpost_from_atom(target)
		if(!home?.can_build(user))
			balloon_alert(user, "outpost property!")
			return ITEM_INTERACT_BLOCKING
	return ..()
