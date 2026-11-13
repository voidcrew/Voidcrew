/**
 * # The lockup on its outpost
 *
 * A trader outpost's lockup is a sealed block on the outpost's own map, in /area/voidcrew/outpost_lockup. No door
 * joins it to the concourse or the lobby: people come by the outpost lift, at a stop named Lockup, and the wing's
 * own people come and go through two closed rooms (Processing, outpost_prison_processing.dm, and the staff closet,
 * outpost_prison_guards.dm).
 *
 * This file holds what the map places for it (landmarks, the lift panel, the Processing doors, the boards) and
 * ensure_prison(), which finds the mapped wing when the outpost's interior loads and starts its prison. The lift's
 * side is in trade/outpost_elevator.dm and trade_floors/floor_lift.dm.
 *
 * SSovermap loads outpost interiors before SSatoms has initialised anything, so ensure_prison() only looks things
 * up. Prisoners, guards and the cleanbot are made by the prison's clock (tick()), which starts with the round.
 */

// ===== WHAT THE MAP PLACES =====

/// One tile of the Lockup stop's lift car: nine in a 3x3, like the concourse's. Consumed at load.
/obj/effect/landmark/outpost_lockup_alcove
	name = "lockup lift alcove"

/// One tile of Processing, the two-door room between the front room and the yard. Consumed at load.
/obj/effect/landmark/outpost_lockup_processing
	name = "lockup processing"

/// Where the warden stands, behind the front desk. Consumed at load.
/obj/effect/landmark/outpost_lockup_desk
	name = "lockup desk"

/// The front desk itself: where what the warden hands over is put down. Consumed at load.
/obj/effect/landmark/outpost_lockup_claim
	name = "lockup desk counter"

/// One tile of the staff closet, where a new guard comes on shift. Consumed at load.
/obj/effect/landmark/outpost_lockup_staff
	name = "lockup staff closet"

/// The lift panel in the lockup's front room
/obj/machinery/outpost_elevator/lockup
	name = "elevator panel"
	desc = "Controls the outpost's elevator. Step into the alcove, pick a floor, mind the gap."
	/// The wing whose front room this panel is in (ensure_prison())
	var/datum/outpost_prison/prison

MAPPING_DIRECTIONAL_HELPERS(/obj/machinery/outpost_elevator/lockup, 32)

/obj/machinery/outpost_elevator/lockup/Destroy()
	if(prison?.lift_panel == src)
		prison.lift_panel = null
	prison = null
	return ..()

/obj/machinery/outpost_elevator/lockup/get_current_floor()
	return (prison && outpost) ? OUTPOST_LIFT_LOCKUP : -1

/obj/machinery/outpost_elevator/lockup/get_own_alcove()
	return length(prison?.alcove_turfs) ? prison.alcove_turfs : null

/// The board in the front room and the one in the yard. Blank for now.
/obj/machinery/status_display/outpost_berth/lockup
	name = "lockup board"
	desc = "The lockup's board."

MAPPING_DIRECTIONAL_HELPERS(/obj/machinery/status_display/outpost_berth/lockup, 32)

// ===== PROCESSING'S DOORS =====

/**
 * Processing's two doors: real airlocks, opened and shut by Processing (outpost_prison_processing.dm) through the
 * airlock's own open() and close(), with its sounds and its bolts, power and wires as on any door. Nobody's ID
 * opens one. They are staff doors, so the cell block ends at the inner one.
 */
/obj/machinery/door/airlock/security/prison_staff/processing
	name = "Processing"
	desc = "The lockup's way in and out."

/obj/machinery/door/airlock/security/prison_staff/processing/allowed(mob/accessor)
	return isAdminGhostAI(accessor)

// Whoever Processing is working for walks through; nobody else steps or paths into the room from outside.
/obj/machinery/door/airlock/security/prison_staff/processing/lets_prisoner(atom/movable/mover)
	var/datum/outpost_prison/prison = get_outpost_prison(src)
	return !!prison && prison.processing_who() == mover

/obj/machinery/door/airlock/security/prison_staff/processing/CanAllowThrough(atom/movable/mover, border_dir)
	if(isliving(mover) && !lets_prisoner(mover))
		var/datum/outpost_prison/prison = get_outpost_prison(src)
		if(prison && !prison.in_processing(mover) && get_turf(mover) != loc)
			return FALSE
	return ..()

/obj/machinery/door/airlock/security/prison_staff/processing/CanAStarPass(to_dir, datum/can_pass_info/pass_info)
	var/atom/requester = pass_info?.requester_ref?.resolve()
	if(!density)
		if(lets_prisoner(requester))
			return TRUE
		if(isliving(requester) && !is_outpost_prisoner(requester))
			var/datum/outpost_prison/prison = get_outpost_prison(src)
			return !!prison && (prison.in_processing(requester) || get_turf(requester) == loc)
	return FALSE

/// The front room side. Anyone other than a prisoner ever caught inside may let themselves back out once the yard door is shut.
/obj/machinery/door/airlock/security/prison_staff/processing/outer

/obj/machinery/door/airlock/security/prison_staff/processing/outer/allowed(mob/accessor)
	if(..())
		return TRUE
	if(!isliving(accessor) || is_outpost_prisoner(accessor))
		return FALSE
	var/datum/outpost_prison/prison = get_outpost_prison(src)
	return !!prison && prison.in_processing(accessor) && prison.processing_shut(prison.processing_door(TRUE))

/obj/machinery/door/airlock/security/prison_staff/processing/outer/CanAStarPass(to_dir, datum/can_pass_info/pass_info)
	if(..())
		return TRUE
	if(!density || locked || welded || !hasPower() || pass_info?.no_id)
		return FALSE
	var/mob/living/requester = pass_info?.requester_ref?.resolve()
	return istype(requester) && allowed(requester)

/// The yard side
/obj/machinery/door/airlock/security/prison_staff/processing/inner

// ===== THE PRISON'S SIDE =====

/datum/outpost_prison
	/// The Lockup stop's lift car, in the order the lift maps cars tile to tile (rows from the south, each west to east)
	var/list/turf/alcove_turfs = list()
	/// Processing's tiles
	var/list/turf/processing_turfs = list()
	/// The staff closet's tiles
	var/list/turf/staff_closet_turfs = list()
	/// Where the warden stands, behind the desk
	var/turf/desk_turf
	/// The desk: where what the warden hands over is put down
	var/turf/claim_turf
	/// The lift panel in the front room
	var/obj/machinery/outpost_elevator/lockup/lift_panel

/// Lets go of the mapped places and the lift panel (Destroy())
/datum/outpost_prison/proc/host_destroy()
	if(lift_panel?.prison == src)
		lift_panel.prison = null
	lift_panel = null
	alcove_turfs = list()
	processing_turfs = list()
	staff_closet_turfs = list()
	desk_turf = null
	claim_turf = null
	if(outpost?.prison == src)
		outpost.prison = null

// ===== THE OUTPOST'S SIDE =====

/**
 * Finds the lockup the interior template placed and starts its prison: the area instance, the landmarks (collected
 * into the prison's lists and deleted) and the lift panel. An outpost whose map has no lockup has no prison. Called
 * as the interior links (link_interior_machinery()), which at round start is before any atom has initialised, so it
 * only looks things up; a runtime here would otherwise undo the whole outpost load, so one is caught and the
 * outpost goes without its wing.
 */
/obj/structure/overmap/trader_outpost/proc/ensure_prison()
	if(prison)
		return prison
	if(!template_bottom_left || !outpost_template?.width || !outpost_template?.height)
		return null
	var/turf/top_right = locate(
		template_bottom_left.x + outpost_template.width - 1,
		template_bottom_left.y + outpost_template.height - 1,
		template_bottom_left.z
	)
	if(!top_right)
		return null
	var/area/voidcrew/outpost_lockup/wing_area
	var/list/turf/alcove = list()
	var/list/turf/processing = list()
	var/list/turf/closet = list()
	var/turf/desk
	var/turf/claim
	var/obj/machinery/outpost_elevator/lockup/panel
	// block() goes row by row from the south, each row west to east: the order every lift car is collected in
	for(var/turf/tile as anything in block(template_bottom_left, top_right))
		var/area/voidcrew/outpost_lockup/here = tile.loc
		if(!istype(here))
			continue
		wing_area ||= here
		if(here != wing_area)
			continue
		for(var/obj/effect/landmark/mark in tile)
			if(istype(mark, /obj/effect/landmark/outpost_lockup_alcove))
				alcove += tile
			else if(istype(mark, /obj/effect/landmark/outpost_lockup_processing))
				processing += tile
			else if(istype(mark, /obj/effect/landmark/outpost_lockup_staff))
				closet += tile
			else if(istype(mark, /obj/effect/landmark/outpost_lockup_desk))
				desk = tile
			else if(istype(mark, /obj/effect/landmark/outpost_lockup_claim))
				claim = tile
			else
				continue
			qdel(mark)
		panel ||= locate(/obj/machinery/outpost_elevator/lockup) in tile
	if(!wing_area || wing_area.prison)
		return null
	var/datum/outpost_prison/wing_prison
	try
		wing_prison = new /datum/outpost_prison(src, wing_area)
	catch(var/exception/failure)
		stack_trace("OUTPOST LOCKUP: '[format_text(name)]' could not start its lockup: [failure] ([failure.file]:[failure.line])")
		if(wing_area.prison)
			qdel(wing_area.prison)
		return null
	prison = wing_prison
	prison.alcove_turfs = alcove
	prison.processing_turfs = processing
	prison.staff_closet_turfs = closet
	prison.desk_turf = desk
	prison.claim_turf = claim
	if(panel)
		panel.outpost = src
		panel.prison = prison
		prison.lift_panel = panel
	return prison
