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

/// The board in the front room and the one in the yard: shows the soonest inmate release (M:SS), or blank
/obj/machinery/status_display/outpost_berth/lockup
	name = "lockup board"
	desc = "The lockup's board."
	/// The wing this board reports on
	var/datum/outpost_prison/prison

/obj/machinery/status_display/outpost_berth/lockup/Initialize(mapload, ndir, building)
	. = ..()
	var/datum/outpost_prison/found = prison || get_outpost_prison(src)
	found?.register_lockup_board(src)

/obj/machinery/status_display/outpost_berth/lockup/Destroy()
	if(prison)
		prison.boards -= src
		prison = null
	return ..()

/obj/machinery/status_display/outpost_berth/lockup/examine(mob/user)
	. = ..()
	var/datum/outpost_prison/holder = prison || get_outpost_prison(src)
	var/own_time = holder?.inmate_remaining_text(user)
	if(own_time)
		. += span_notice("Your name is on the board. [own_time].")

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

/obj/machinery/door/airlock/security/prison_staff/processing/lets_leaving_prisoner(atom/movable/mover)
	return FALSE

// Whoever Processing is working for walks through (and anyone a crossing staff member pulls in hand); nobody else steps or paths into the room from outside unless the door is breached.
/obj/machinery/door/airlock/security/prison_staff/processing/lets_prisoner(atom/movable/mover)
	if(..())
		return TRUE
	var/datum/outpost_prison/prison = get_outpost_prison(src)
	if(!prison)
		return FALSE
	if(prison.processing_who() == mover)
		return TRUE
	return prison.processing_state == OUTPOST_PROCESSING_BOOK && prison.booking_mover_ref?.resolve() == mover

/obj/machinery/door/airlock/security/prison_staff/processing/CanAllowThrough(atom/movable/mover, border_dir)
	if(istype(mover, /mob/living/basic/bot/cleanbot))
		var/mob/living/basic/bot/cleanbot/bot = mover
		if(isnull(bot.client) && isnull(bot.mind) && !bot.moving_from_pull)
			var/datum/outpost_prison/prison = get_outpost_prison(src)
			if(prison && !prison.in_processing(bot) && get_turf(bot) != loc)
				return FALSE
	if((lockup_breached() || get_outpost_prison(src)?.corpse_doors_open()) && !density)
		return ..()
	if(isliving(mover) && !lets_prisoner(mover))
		var/mob/living/living_mover = mover
		var/datum/outpost_prison/prison = get_outpost_prison(src)
		var/mob/living/who = prison?.processing_who()
		var/towed_by_who = prison?.processing_state == OUTPOST_PROCESSING_CROSS && isliving(who) && who.pulling == living_mover && living_mover.pulledby == who && (living_mover.moving_from_pull == who || HAS_TRAIT(living_mover, TRAIT_RESTRAINED) || living_mover.stat != CONSCIOUS || living_mover.body_position == LYING_DOWN)
		if(prison && !towed_by_who && !prison.in_processing(living_mover) && get_turf(living_mover) != loc)
			return FALSE
	return ..()

/obj/machinery/door/airlock/security/prison_staff/processing/CanAStarPass(to_dir, datum/can_pass_info/pass_info)
	var/atom/requester = pass_info?.requester_ref?.resolve()
	if(istype(requester, /mob/living/basic/bot/cleanbot))
		var/mob/living/basic/bot/cleanbot/bot = requester
		if(isnull(bot.client) && isnull(bot.mind))
			var/datum/outpost_prison/prison = get_outpost_prison(src)
			return !density && !!prison && (prison.in_processing(bot) || get_turf(bot) == loc)
	if(lockup_breached() && (!density || rioter_broken))
		return TRUE
	if(!density)
		if(lets_prisoner(requester))
			return TRUE
		if(isliving(requester) && !is_outpost_prisoner(requester))
			var/datum/outpost_prison/prison = get_outpost_prison(src)
			if(prison?.corpse_doors_open())
				return TRUE
			return !!prison && (prison.in_processing(requester) || get_turf(requester) == loc)
	return FALSE

/// The front room side
/obj/machinery/door/airlock/security/prison_staff/processing/outer

/obj/machinery/door/airlock/security/prison_staff/processing/outer/lets_prisoner(atom/movable/mover)
	if(..())
		return TRUE
	var/datum/outpost_prison/prison = get_outpost_prison(src)
	return !!prison && prison.claim_lets_enter(mover)

/obj/machinery/door/airlock/security/prison_staff/processing/outer/Bumped(atom/movable/AM)
	var/mob/living/mover = AM
	if(istype(mover) && density)
		var/datum/outpost_prison/prison = get_outpost_prison(src)
		if(prison)
			if(prison.in_processing(mover) && (WEAKREF(mover) in prison.processing_release_refs))
				prison.try_start_processing_release(mover)
				return
			var/mob/living/deliverer
			if(prison.claim_held_catch(mover))
				deliverer = mover
			else if(isliving(mover.pulledby) && mover.pulledby.pulling == mover)
				deliverer = mover.pulledby
			else if(isliving(mover.buckled))
				deliverer = mover.buckled
			if(deliverer && prison.in_front_room(deliverer) && prison.try_start_processing_claim(deliverer))
				return
	return ..()

/obj/machinery/door/airlock/security/prison_staff/processing/outer/try_to_activate_door(mob/living/user, access_bypass = FALSE)
	if(isliving(user) && density && !access_bypass)
		var/datum/outpost_prison/prison = get_outpost_prison(src)
		if(prison && prison.in_front_room(user) && prison.claim_held_catch(user) && prison.try_start_processing_claim(user))
			add_fingerprint(user)
			return
	return ..()

/// The yard side
/obj/machinery/door/airlock/security/prison_staff/processing/inner

/obj/machinery/door/airlock/security/prison_staff/processing/inner/Bumped(atom/movable/AM)
	. = ..()
	var/mob/living/mover = AM
	if(istype(mover) && density)
		var/datum/outpost_prison/prison = get_outpost_prison(src)
		if(!prison)
			return
		if(WEAKREF(mover) in prison.processing_release_refs)
			prison.try_start_processing_release(mover)
		else if(prison.is_inmate(mover) && prison.in_processing(mover))
			prison.try_start_processing_inmate_in(mover)

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
	/// Cached front-room floor turfs (turf = TRUE), flooded from alcove_turfs without crossing doors or tables
	var/list/front_room_cache

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
	front_room_cache = null
	if(outpost?.prison == src)
		outpost.prison = null

/// Open ground of the front room (turf = TRUE), flooded from the lift alcove without crossing doors or the front desk
/datum/outpost_prison/proc/front_room_ground()
	if(!isnull(front_room_cache))
		return front_room_cache
	var/list/found = list()
	var/list/queue = list()
	for(var/turf/start as anything in alcove_turfs)
		if(isturf(start) && contains_turf(start) && !isclosedturf(start) && !found[start])
			found[start] = TRUE
			queue += start
	var/head = 1
	while(head <= length(queue))
		var/turf/here = queue[head++]
		for(var/direction in GLOB.cardinals)
			var/turf/next = get_step(here, direction)
			if(!next || found[next] || !contains_turf(next) || isclosedturf(next))
				continue
			if((locate(/obj/machinery/door) in next) || (locate(/obj/structure/table) in next))
				continue
			found[next] = TRUE
			queue += next
	front_room_cache = found
	return found

/// Whether `thing` stands in the wing's front room (outside Processing, the office and the cell block)
/datum/outpost_prison/proc/in_front_room(atom/thing)
	var/turf/spot = get_turf(thing)
	return !!spot && !!front_room_ground()[spot]

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
