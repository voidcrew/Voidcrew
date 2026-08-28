/**
 * # Outpost Hangar Berths
 *
 * Every ship that docks at a trader outpost gets its own dynamically allocated
 * hangar berth: a turf reservation with the hangar template loaded into it and
 * a stationary docking port aligned to the ship's own port. Each berth is a
 * "floor" reachable via the hangar elevator (see outpost_elevator.dm); floor 0
 * is the outpost concourse itself.
 *
 * Lifecycle: allocated synchronously in ship_act() before the dock warmup
 * starts; released when the ship finishes undocking (on_ship_undock_complete),
 * when the ship is deleted, or when the ship never arrives (arrival watchdog).
 * All teardown funnels through /datum/outpost_berth/Destroy().
 */

GLOBAL_DATUM(outpost_hangar_template, /datum/map_template/outpost_hangar)

/datum/map_template/outpost_hangar
	name = "Outpost Hangar Berth"
	mappath = "voidcrew/_maps/map_files/outposts/outpost_hangar.dmm"

// Deliberately NOT UNIQUE_AREA: the template loads once per berth, and each
// load must get its own area instance (UNIQUE_AREA map loads are global
// singletons, six berths would merge into one area).
/area/voidcrew/outpost_hangar
	name = "\improper Outpost Hangar"
	icon_state = "away"
	static_lighting = TRUE
	// Soft ambient floodlight: the pad is too wide for wall tubes to reach its
	// center, and nothing can be placed inside the landing rect.
	base_lighting_alpha = 110
	base_lighting_color = "#d5e3ff"
	requires_power = FALSE
	default_gravity = STANDARD_GRAVITY
	area_flags = NOTELEPORT
	area_flags_mapping = NONE
	flags_1 = NONE
	ambience_index = AMBIENCE_AWAY
	// The hangar deck is where a beast that stowed away aboard a docking ship
	// would step out; see voidcrew/area/megafauna_ban.dm
	repels_megafauna = TRUE

/// Marks the bottom-left tile of a berth's 56x40 landing rect; consumed at load
/obj/effect/landmark/outpost_berth_dock
	name = "outpost berth dock"

/// Marks one elevator alcove tile (used in both hangars and outpost lobbies); consumed at load
/obj/effect/landmark/outpost_elevator_alcove
	name = "outpost elevator alcove"

/// Berth wayfinding sign: "BERTH 3 / SHIPNAME"
/obj/machinery/status_display/outpost_berth
	name = "berth display"
	current_mode = SD_MESSAGE
	use_power = NO_POWER_USE
	resistance_flags = INDESTRUCTIBLE | LAVA_PROOF | FIRE_PROOF | UNACIDABLE | ACID_PROOF

MAPPING_DIRECTIONAL_HELPERS(/obj/machinery/status_display/outpost_berth, 32)

// INDESTRUCTIBLE doesn't cover the wrench: /obj/machinery/status_display's
// wrench_act_secondary deconstructs regardless of resistance flags, and outpost
// signage that the first visitor can pocket isn't signage.
/obj/machinery/status_display/outpost_berth/wrench_act_secondary(mob/living/user, obj/item/tool)
	balloon_alert(user, "bolted to the hull!")
	return ITEM_INTERACT_BLOCKING

/**
 * Static hangar signage. The berth pad is 56x40 and ships land dead centre of it,
 * so a crew stepping off a small hull is standing in the middle of an empty field
 * with every wall outside view range. These say which way the way out is. Text is
 * mapper-set and never changes, so no host wiring: unlike the berth display these
 * are deliberately NOT an /outpost_berth subtype, so link_hangar_contents() leaves
 * them alone.
 */
/obj/machinery/status_display/outpost_sign
	name = "wayfinding display"
	desc = "A hangar wayfinding display."
	current_mode = SD_MESSAGE
	use_power = NO_POWER_USE
	resistance_flags = INDESTRUCTIBLE | LAVA_PROOF | FIRE_PROOF | UNACIDABLE | ACID_PROOF
	/// Top line of the sign
	var/top_line = "EXIT"
	/// Bottom line of the sign
	var/bottom_line = "SOUTH SIDE"

/obj/machinery/status_display/outpost_sign/Initialize(mapload, ndir, building)
	. = ..()
	set_messages(top_line, bottom_line)

/obj/machinery/status_display/outpost_sign/wrench_act_secondary(mob/living/user, obj/item/tool)
	balloon_alert(user, "bolted to the hull!")
	return ITEM_INTERACT_BLOCKING

MAPPING_DIRECTIONAL_HELPERS(/obj/machinery/status_display/outpost_sign, 32)

/// The sign hung beside the hangar's one airlock, so the exit reads as the exit up close.
/obj/machinery/status_display/outpost_sign/elevator
	top_line = "EXIT"
	bottom_line = "ELEVATOR"

MAPPING_DIRECTIONAL_HELPERS(/obj/machinery/status_display/outpost_sign/elevator, 32)

/**
 * One allocated hangar berth. Owns the reservation, the docking port and the
 * links to the hangar's elevator machinery.
 */
/datum/outpost_berth
	/// Berth host that owns this berth (trader outpost or player outpost)
	var/obj/structure/overmap/outpost
	/// Slot index in outpost.berths (1-based); doubles as the floor number
	var/berth_number = 0
	/// Ship assigned to this berth (cleared via COMSIG_QDELETING)
	var/obj/structure/overmap/ship/ship
	/// The reserved turf block holding the hangar
	var/datum/turf_reservation/reservation
	/// The stationary port the ship lands on
	var/obj/docking_port/stationary/dock
	/// Elevator alcove turfs inside the hangar, in block() order (y then x ascending)
	var/list/turf/alcove_turfs = list()
	/// Hangar-side elevator panel
	var/obj/machinery/outpost_elevator/panel
	/// Berth number signs, one per wall the hangar hangs one on
	var/list/obj/machinery/status_display/outpost_berth/status_signs = list()
	/// Bottom-left turf of the loaded hangar template
	var/turf/hangar_bottom_left
	/// Whether the ship has actually landed here
	var/arrived = FALSE
	/// Bounded retries while waiting for the departing shuttle to physically leave
	var/release_retries = 0
	/// Timer that frees the berth if the ship never shows up (TIMER_STOPPABLE)
	var/arrival_watchdog

/datum/outpost_berth/New(obj/structure/overmap/outpost, berth_number, obj/structure/overmap/ship/ship)
	src.outpost = outpost
	src.berth_number = berth_number
	src.ship = ship

/datum/outpost_berth/Destroy()
	if(arrival_watchdog)
		deltimer(arrival_watchdog)
		arrival_watchdog = null
	if(ship)
		UnregisterSignal(ship, list(COMSIG_VOIDCREW_SHIP_DOCKED, COMSIG_QDELETING))
		ship = null
	// Deregister the floor first so the elevator stops offering it, then get
	// everyone out, releasing the reservation force-deletes living mobs.
	if(outpost?.berths && berth_number && outpost.berths[berth_number] == src)
		outpost.berths[berth_number] = null
	eject_occupants()
	if(panel)
		panel.berth = null
		panel = null
	status_signs = null
	if(dock)
		qdel(dock, TRUE) // stationary ports refuse non-forced qdel
		dock = null
	if(reservation)
		qdel(reservation) // async turf wipe deletes the hangar's contents
		reservation = null
	hangar_bottom_left = null
	alcove_turfs = null
	outpost?.refresh_elevator_uis()
	outpost = null
	return ..()

/**
 * Politely frees the berth: waits (bounded) for the departing shuttle to
 * physically leave the pad before tearing the hangar down, since wiping the
 * reservation under a live shuttle would shred it.
 */
/datum/outpost_berth/proc/release(force = FALSE)
	if(QDELETED(src))
		return
	if(!force && dock?.get_docked())
		if(release_retries < 10)
			release_retries++
			addtimer(CALLBACK(src, PROC_REF(release)), 1 SECONDS, TIMER_UNIQUE)
			return
		log_shuttle("OUTPOST BERTH: releasing berth [berth_number] at [outpost] with a shuttle still docked after [release_retries] retries.")
	qdel(src)

/// Registers the ship-side signals and the arrival watchdog. Called once by allocate_berth().
/datum/outpost_berth/proc/setup_signals()
	RegisterSignal(ship, COMSIG_VOIDCREW_SHIP_DOCKED, PROC_REF(on_ship_docked))
	RegisterSignal(ship, COMSIG_QDELETING, PROC_REF(on_ship_deleted))
	arrival_watchdog = addtimer(CALLBACK(src, PROC_REF(check_arrival)), OUTPOST_BERTH_ARRIVAL_GRACE, TIMER_STOPPABLE)

/datum/outpost_berth/proc/on_ship_docked(datum/source)
	SIGNAL_HANDLER
	// The ship could complete a dock elsewhere if this attempt was aborted,
	// only count an arrival that is physically on our port.
	if(dock?.get_docked() != ship.shuttle)
		return
	arrived = TRUE
	if(arrival_watchdog)
		deltimer(arrival_watchdog)
		arrival_watchdog = null
	ship.ship_notify("Docked at [outpost.name], Hangar Berth [berth_number]. Follow the painted arrows to the hangar's south wall; the airlock there leads to the elevator, which connects to the concourse and the other berths.", "DOCKING", SHIP_NOTIFY_NOTICE, 'voidcrew/sound/notify.ogg', 50)

/datum/outpost_berth/proc/on_ship_deleted(datum/source)
	SIGNAL_HANDLER
	UnregisterSignal(ship, list(COMSIG_VOIDCREW_SHIP_DOCKED, COMSIG_QDELETING))
	ship = null
	release(force = TRUE)

/// Arrival watchdog: the dock attempt can silently die (state reset, target
/// lost) with no cancel signal, which would leak the berth forever.
/datum/outpost_berth/proc/check_arrival()
	arrival_watchdog = null
	if(dock?.get_docked())
		// Something landed after all: the berth is in use.
		arrived = TRUE
		return
	log_shuttle("OUTPOST BERTH: [ship] never arrived at [outpost] berth [berth_number], freeing.")
	release(force = TRUE)

/**
 * Scans the freshly loaded hangar footprint for its landmarks and machinery,
 * wires them to this berth and spawns the docking port. Returns FALSE if the
 * template is missing a required piece (bad map).
 */
/datum/outpost_berth/proc/link_hangar_contents()
	var/datum/map_template/outpost_hangar/hangar_template = GLOB.outpost_hangar_template
	var/turf/top_right = locate(
		hangar_bottom_left.x + hangar_template.width - 1,
		hangar_bottom_left.y + hangar_template.height - 1,
		hangar_bottom_left.z
	)
	if(!top_right)
		return FALSE
	var/turf/dock_turf
	for(var/turf/hangar_turf as anything in block(hangar_bottom_left, top_right))
		for(var/obj/effect/landmark/outpost_berth_dock/dock_mark in hangar_turf)
			dock_turf = hangar_turf
			qdel(dock_mark)
		// block() iterates y-major then x, so alcove turfs collect in the same
		// deterministic order on every floor, the ride maps turf i to turf i.
		for(var/obj/effect/landmark/outpost_elevator_alcove/alcove_mark in hangar_turf)
			alcove_turfs += hangar_turf
			qdel(alcove_mark)
		for(var/obj/machinery/machine in hangar_turf)
			if(istype(machine, /obj/machinery/outpost_elevator))
				panel = machine
				panel.outpost = outpost
				panel.berth = src
			else if(istype(machine, /obj/machinery/status_display/outpost_berth))
				status_signs += machine
			else if(istype(machine, /obj/machinery/door/airlock/outpost))
				var/obj/machinery/door/airlock/outpost/door = machine
				door.outpost = outpost
		// Berth fixtures (lights, signage, the lift panel) are outpost property.
		// The docked ship arrives after this sweep, so its own machinery and
		// structures stay player-serviceable.
		for(var/obj/fixture in hangar_turf)
			if(ismachinery(fixture) || isstructure(fixture))
				fixture.AddElement(/datum/element/outpost_property)
	if(!dock_turf)
		log_mapping("OUTPOST BERTH: hangar template has no /obj/effect/landmark/outpost_berth_dock.")
		return FALSE
	if(!length(alcove_turfs))
		log_mapping("OUTPOST BERTH: hangar template has no elevator alcove landmarks.")
		return FALSE
	if(!panel)
		log_mapping("OUTPOST BERTH: hangar template has no /obj/machinery/outpost_elevator.")
		return FALSE

	dock = new /obj/docking_port/stationary(dock_turf)
	dock.dir = NORTH
	dock.name = "[outpost.name] Berth [berth_number]"
	dock.width = RESERVE_DOCK_MAX_SIZE_LONG
	dock.height = RESERVE_DOCK_MAX_SIZE_SHORT
	dock.dwidth = 0
	dock.dheight = 0

	for(var/obj/machinery/status_display/outpost_berth/sign as anything in status_signs)
		sign.set_messages("BERTH [berth_number]", ship.name)
	return TRUE

/**
 * Moves everyone (and anything carrying someone) out of the hangar to the
 * outpost lobby before the reservation wipe force-deletes them.
 */
/datum/outpost_berth/proc/eject_occupants()
	if(!reservation || !outpost)
		return
	var/list/turf/eject_to = outpost.get_floor_alcove(0)
	var/turf/fallback = outpost.template_bottom_left
	if(!length(eject_to) && !fallback)
		return
	var/turf/bottom_left = reservation.bottom_left_turfs[1]
	var/turf/top_right = locate(
		bottom_left.x + reservation.width - 1,
		bottom_left.y + reservation.height - 1,
		bottom_left.z
	)
	if(!top_right)
		return
	for(var/turf/hangar_turf as anything in block(bottom_left, top_right))
		for(var/atom/movable/occupant as anything in hangar_turf.contents.Copy())
			var/eject = FALSE
			if(ismob(occupant))
				// Observers pass through the wipe unharmed; everyone else rides out
				eject = !isobserver(occupant)
			else if(!occupant.anchored && length(occupant.contents) && (locate(/mob/living) in occupant.get_all_contents()))
				// Mechs, closets, anything else with someone inside travels whole
				eject = TRUE
			if(!eject)
				continue
			var/turf/destination = length(eject_to) ? pick(eject_to) : fallback
			occupant.forceMove(destination)
			if(ismob(occupant))
				to_chat(occupant, span_warning("Berth [berth_number] is being cleared for departure, outpost staff usher you back to the concourse."))
			else
				for(var/mob/living/rider in occupant.get_all_contents())
					to_chat(rider, span_warning("Berth [berth_number] is being cleared for departure, outpost staff haul you back to the concourse."))

// ===== HOST-SIDE BERTH MANAGEMENT =====
// Defined on the overmap base so both trader outposts and player outposts
// (once they place a hangar elevator) can host berths.

/**
 * Allocates the lowest free berth for a ship: reserves space, loads the hangar
 * template into it and wires everything up. Returns the berth, or null if the
 * outpost is full or the load failed.
 */
/obj/structure/overmap/proc/allocate_berth(obj/structure/overmap/ship/ship)
	if(!berths)
		berths = new /list(OUTPOST_MAX_BERTHS)
	var/berth_number = 0
	for(var/i in 1 to OUTPOST_MAX_BERTHS)
		if(!berths[i])
			berth_number = i
			break
	if(!berth_number)
		return null

	if(!GLOB.outpost_hangar_template)
		GLOB.outpost_hangar_template = new
	var/datum/map_template/outpost_hangar/hangar_template = GLOB.outpost_hangar_template
	if(!hangar_template.width || !hangar_template.height)
		log_mapping("OUTPOST BERTH: hangar template has no dimensions, cannot allocate.")
		return null

	var/datum/turf_reservation/hangar_reservation = SSmapping.request_turf_block_reservation(hangar_template.width, hangar_template.height, 1)
	if(!hangar_reservation)
		return null

	var/turf/bottom_left = hangar_reservation.bottom_left_turfs[1]
	var/load_success = FALSE
	try
		load_success = hangar_template.load(bottom_left)
	catch(var/exception/e)
		log_mapping("OUTPOST BERTH: failed to load hangar template: [e]")
		load_success = FALSE
	if(!load_success)
		qdel(hangar_reservation)
		return null

	var/datum/outpost_berth/berth = new(src, berth_number, ship)
	berth.reservation = hangar_reservation
	berth.hangar_bottom_left = bottom_left
	if(!berth.link_hangar_contents())
		qdel(berth) // Destroy() frees the reservation
		return null

	berth.setup_signals()
	berths[berth_number] = berth
	refresh_elevator_uis()
	return berth

/// Called from complete_dock() once the ship has fully left the outpost.
/obj/structure/overmap/proc/on_ship_undock_complete(obj/structure/overmap/ship/ship)
	for(var/datum/outpost_berth/berth as anything in berths)
		if(berth?.ship == ship)
			berth.release()
			return

/// Resolves a floor id to its elevator alcove turfs: 0 = concourse lobby, 1..N = berths. Null if that floor doesn't currently exist.
/obj/structure/overmap/proc/get_floor_alcove(floor_id)
	if(floor_id == 0)
		return length(lobby_alcove_turfs) ? lobby_alcove_turfs : null
	if(floor_id < 1 || floor_id > length(berths))
		return null
	var/datum/outpost_berth/berth = berths[floor_id]
	if(!berth || !length(berth.alcove_turfs))
		return null
	return berth.alcove_turfs

/// Pushes fresh data to every elevator panel UI (floor list changed).
/obj/structure/overmap/proc/refresh_elevator_uis()
	for(var/obj/machinery/outpost_elevator/lobby_panel as anything in lobby_panels)
		SStgui.update_uis(lobby_panel)
	for(var/datum/outpost_berth/berth as anything in berths)
		if(berth?.panel)
			SStgui.update_uis(berth.panel)
