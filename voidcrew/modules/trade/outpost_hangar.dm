/**
 * # Outpost Hangar Berths
 *
 * Every ship that docks at a trader outpost gets its own dynamically allocated
 * hangar berth: a turf reservation sized to the ship, with the hangar generated
 * into it and a stationary docking port aligned to the ship's own port. Each
 * berth is a "floor" reachable via the hangar elevator (see outpost_elevator.dm);
 * floor 0 is the outpost concourse itself. Player outposts build the same berth
 * in a fixed berth zone on their own level instead of a reservation
 * (berths_on_level(), outpost_level_layout.dm).
 *
 * Standard berths (allocate_berth) are built per visit: the walls, deck and landing
 * pad come from /datum/outpost_berth_layout, with the fixed exit strip (airlock,
 * elevator alcove and panel, berth displays) set into the south wall. Player
 * outpost ship bays keep their full-size mapped hangars.
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
	flags_1 = NONE
	ambience_index = AMBIENCE_AWAY
	// The hangar deck is where a beast that stowed away aboard a docking ship
	// would step out; see voidcrew/area/megafauna_ban.dm
	repels_megafauna = TRUE

/// A standard per-visit berth. Ships park here; they are only extended in a ship bay.
/area/voidcrew/outpost_hangar/berth

/// Marks the bottom-left tile of a berth's landing rect; consumed at load
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
 * Static hangar signage for the full-size mapped hangars (ship bays): a 56x40
 * pad puts every wall outside view range of a small hull in its middle, so these say
 * which way the way out is. Standard berths are sized to the ship and need none. Text is
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
	/// The reserved turf block holding the hangar. Only claiming and releasing touch it;
	/// everything that asks where the berth is uses the ground procs (GROUND below).
	var/datum/turf_reservation/reservation
	/// The zone on the host's own level holding the hangar instead of a reservation (player outposts)
	var/datum/outpost_zone/zone
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
	/// Size of the loaded hangar; a zoned berth's ground is exactly this rectangle
	var/hangar_width = 0
	var/hangar_height = 0
	/// Landing rect size the dock is built with, along x and y
	var/pad_width = RESERVE_DOCK_MAX_SIZE_LONG
	var/pad_height = RESERVE_DOCK_MAX_SIZE_SHORT
	/// TRUE while the hangar map is loading into the reservation
	var/building = FALSE
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
	if(outpost?.berths && berth_number && berth_number <= length(outpost.berths) && outpost.berths[berth_number] == src)
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
		if(building)
			// The loader is still writing into these turfs. build_standard_hangar() frees
			// them as soon as it returns; the timer only covers a load that never does.
			QDEL_IN(reservation, 30 SECONDS)
		else
			qdel(reservation) // async turf wipe deletes the hangar's contents
		reservation = null
	if(zone)
		if(building)
			// Same for a zone: build_standard_hangar() gives it back once the loader returns.
			addtimer(CALLBACK(zone, TYPE_PROC_REF(/datum/outpost_zone, release_stalled_build)), 60 SECONDS)
		else if(zone.is_held_by(src))
			zone.release() // async wipe deletes the hangar's contents
		zone = null
	hangar_bottom_left = null
	alcove_turfs = null
	outpost?.refresh_elevator_uis()
	outpost = null
	return ..()

// ===== GROUND =====
// The one rectangle of turfs a berth holds: its hangar, the pad and whatever is docked on it.
// Every question about where a berth is goes through these procs. The ground is the berth's
// turf reservation, or for a berth in a zone on its host's level the hangar loaded into it.

/// Whether the berth holds ground right now: claimed and not yet given back.
/datum/outpost_berth/proc/has_ground()
	if(zone)
		return !isnull(hangar_bottom_left)
	return !QDELETED(reservation)

/// Bottom-left turf of the berth's ground, or null when it holds none.
/datum/outpost_berth/proc/get_bottom_left()
	if(!has_ground())
		return null
	if(zone)
		return hangar_bottom_left
	if(!length(reservation.bottom_left_turfs))
		return null
	return reservation.bottom_left_turfs[1]

/// Top-right turf of the berth's ground, or null when it holds none.
/datum/outpost_berth/proc/get_top_right()
	if(!has_ground())
		return null
	if(zone)
		return locate(hangar_bottom_left.x + hangar_width - 1, hangar_bottom_left.y + hangar_height - 1, hangar_bottom_left.z)
	if(!length(reservation.top_right_turfs))
		return null
	return reservation.top_right_turfs[1]

/// Width of the berth's ground in tiles; 0 when it holds none.
/datum/outpost_berth/proc/get_width()
	var/turf/bottom_left = get_bottom_left()
	var/turf/top_right = get_top_right()
	return bottom_left && top_right ? top_right.x - bottom_left.x + 1 : 0

/// Height of the berth's ground in tiles; 0 when it holds none.
/datum/outpost_berth/proc/get_height()
	var/turf/bottom_left = get_bottom_left()
	var/turf/top_right = get_top_right()
	return bottom_left && top_right ? top_right.y - bottom_left.y + 1 : 0

/// Whether `location` lies on the berth's ground. Coordinates only, so a docked hull's tiles count.
/datum/outpost_berth/proc/contains_turf(turf/location)
	if(!location)
		return FALSE
	var/turf/bottom_left = get_bottom_left()
	var/turf/top_right = get_top_right()
	if(!bottom_left || !top_right || location.z != bottom_left.z)
		return FALSE
	return location.x >= bottom_left.x && location.x <= top_right.x && location.y >= bottom_left.y && location.y <= top_right.y

/// Every turf of the berth's ground in block() order (rows from the bottom); empty when it holds none.
/datum/outpost_berth/proc/get_block()
	var/turf/bottom_left = get_bottom_left()
	var/turf/top_right = get_top_right()
	if(!bottom_left || !top_right)
		return list()
	return block(bottom_left, top_right)

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
	ship.ship_notify("Docked at [outpost.name], Hangar Berth [berth_number]. The airlock in the hangar's south wall leads to the elevator up to the concourse. Only your crew can take the elevator down to this berth.", "DOCKING", SHIP_NOTIFY_NOTICE, 'voidcrew/sound/notify.ogg', 50)

/datum/outpost_berth/proc/on_ship_deleted(datum/source)
	SIGNAL_HANDLER
	UnregisterSignal(ship, list(COMSIG_VOIDCREW_SHIP_DOCKED, COMSIG_QDELETING))
	ship = null
	release(force = TRUE)

/**
 * Whether the elevator may bring this mob down to the berth. A standard berth takes
 * only its own ship's crew, until the ship is abandoned and anyone may claim it.
 * Whoever rides down with a crew member comes along as their guest (see
 * /obj/machinery/outpost_elevator/proc/complete_ride).
 */
/datum/outpost_berth/proc/allows_entry(mob/visitor)
	if(!ship || ship.abandoned)
		return TRUE
	return !!(ship.ship_team && (ship.ship_team in visitor?.mind?.ship_teams))

/// A ship bay is the outpost's own room, not a visitor's berth, so the elevator takes anyone there.
/datum/outpost_berth/ship_bay/allows_entry(mob/visitor)
	return TRUE

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
	var/list/turf/hangar_turfs = get_block()
	if(!length(hangar_turfs))
		return FALSE
	var/turf/dock_turf
	for(var/turf/hangar_turf as anything in hangar_turfs)
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
	dock.width = pad_width
	dock.height = pad_height
	dock.dwidth = 0
	dock.dheight = 0
	if(zone)
		// On the host's own level the map region is the whole outpost, so a dock dragged along
		// with a hull is kept inside its hangar instead (clamp_reserve_dock_to_site()).
		var/turf/ground_low = get_bottom_left()
		var/turf/ground_high = get_top_right()
		dock.site_rect = list(ground_low.x, ground_low.y, ground_high.x, ground_high.y)

	for(var/obj/machinery/status_display/outpost_berth/sign as anything in status_signs)
		sign.set_messages("BERTH [berth_number]", ship?.name || "FREIGHT")
	return TRUE

/**
 * Moves everyone (and anything carrying someone) out of the hangar to the
 * outpost lobby before the reservation wipe force-deletes them.
 */
/datum/outpost_berth/proc/eject_occupants()
	if(!has_ground() || !outpost)
		return
	var/list/turf/eject_to = outpost.get_floor_alcove(0)
	var/turf/fallback = outpost.template_bottom_left
	if(!length(eject_to) && !fallback)
		return
	for(var/turf/hangar_turf as anything in get_block())
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

/// Whether this host builds its berths in zones on its own level (berth_zone_for()) instead of
/// turf reservations. Player outposts do; trader outposts and the Colosseum do not.
/obj/structure/overmap/proc/berths_on_level()
	return FALSE

/// How many hangar berths this host can hold at once. Also the elevator's berth floors.
/obj/structure/overmap/proc/berth_capacity()
	return OUTPOST_MAX_BERTHS

/// The zone berth `berth_number` loads into, on a berths_on_level() host
/obj/structure/overmap/proc/berth_zone_for(berth_number)
	return null

/**
 * Allocates the lowest free berth for a ship: reserves a hangar sized to the ship (or takes
 * the berth's zone on a berths_on_level() host), builds it and wires everything up. Returns
 * the berth, or null if the outpost is full, the ship cannot fit a berth, or the build failed.
 */
/obj/structure/overmap/proc/allocate_berth(obj/structure/overmap/ship/ship)
	var/obj/docking_port/mobile/measured = ship?.shuttle
	var/list/pad_size = outpost_berth_pad_size(measured)
	if(!pad_size)
		return null
	var/datum/map_template/outpost_berth_strip/strip = get_outpost_berth_strip()
	if(!strip.width || !strip.height)
		log_mapping("OUTPOST BERTH: exit strip template has no dimensions, cannot allocate.")
		return null
	var/datum/outpost_berth_layout/layout = new(pad_size[1], pad_size[2], strip.width, strip.height)

	// Pick the slot and its ground with no yield before both are claimed below.
	if(!berths)
		berths = new /list(OUTPOST_MAX_BERTHS)
	var/on_level = berths_on_level()
	var/berth_number = 0
	var/datum/outpost_zone/zone
	for(var/i in 1 to min(berth_capacity(), length(berths)))
		if(berths[i])
			continue
		if(on_level)
			zone = berth_zone_for(i)
			// A zone still being wiped after its last visitor is skipped, not waited on.
			if(!zone?.is_vacant())
				zone = null
				continue
		berth_number = i
		break
	if(!berth_number)
		return null
	if(zone && (layout.width > zone.get_width() || layout.height > zone.get_height()))
		log_mapping("OUTPOST BERTH: a [layout.width]x[layout.height] berth does not fit the [zone.get_width()]x[zone.get_height()] zone at [src].")
		return null

	var/datum/outpost_berth/berth = new(src, berth_number, ship)
	// Claim the slot before the build yields, so a second arrival cannot take it too.
	berths[berth_number] = berth
	if(zone)
		zone.claim(berth)
		berth.zone = zone
	// Watch the ship from the start: its deletion, or a build that never finishes, frees the slot.
	berth.setup_signals()
	var/built = berth.build_standard_hangar(layout, strip)
	// The pad was sized for this hull; a replaced or deleted one needs a new berth.
	if(!built || QDELETED(src) || QDELETED(berth) || QDELETED(ship) || ship.shuttle != measured || (measured && QDELETED(measured)))
		if(!QDELETED(berth))
			qdel(berth) // Destroy() frees the slot and the reservation
		return null

	refresh_elevator_uis()
	return berth

/**
 * Reserves this berth's hangar and builds it in one load: generated walls, deck and pad
 * with the exit strip in the middle of the south wall. A berth with a zone loads into it
 * instead, on the zone's south edge and centred, so the exit strip is in the same place for
 * every ship. Parsing, reserving and loading all yield, and the berth can be torn down in any
 * of those gaps; each one is checked.
 */
/datum/outpost_berth/proc/build_standard_hangar(datum/outpost_berth_layout/layout, datum/map_template/outpost_berth_strip/strip)
	pad_width = layout.pad_width
	pad_height = layout.pad_height
	var/datum/outpost_zone/building_zone = zone
	var/datum/map_template/outpost_berth_body/body = new
	body.generate(layout, strip)
	if(QDELETED(src))
		return FALSE
	var/datum/turf_reservation/claimed
	var/turf/bottom_left
	if(building_zone)
		bottom_left = locate(building_zone.low_x + round((building_zone.get_width() - layout.width) / 2), building_zone.low_y, building_zone.z_value)
	else
		claimed = SSmapping.request_turf_block_reservation(layout.width, layout.height, 1, requester = "outpost hangar berth for '[ship?.name]' at '[outpost?.name]'")
		if(!claimed)
			return FALSE
		// A berth torn down while reserving has nobody left to free this.
		if(QDELETED(src))
			qdel(claimed)
			return FALSE
		reservation = claimed
		bottom_left = get_bottom_left()
	hangar_bottom_left = bottom_left
	hangar_width = layout.width
	hangar_height = layout.height
	building = TRUE
	var/loaded = body.load(bottom_left)
	building = FALSE
	if(QDELETED(src))
		// Destroy() left the ground alone while the loader was writing into it.
		if(claimed)
			qdel(claimed)
		building_zone?.release()
		return FALSE
	if(!loaded)
		return FALSE
	if(!link_hangar_contents())
		return FALSE
	building_zone?.occupy()
	return TRUE

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

/// Resolves a floor id to its berth, or null for the concourse and floors that don't currently exist.
/obj/structure/overmap/proc/get_floor_berth(floor_id)
	if(floor_id < 1 || floor_id > length(berths))
		return null
	return berths[floor_id]

/// Pushes fresh data to every elevator panel UI (floor list changed).
/obj/structure/overmap/proc/refresh_elevator_uis()
	for(var/obj/machinery/outpost_elevator/lobby_panel as anything in lobby_panels)
		SStgui.update_uis(lobby_panel)
	for(var/datum/outpost_berth/berth as anything in berths)
		if(berth?.panel)
			SStgui.update_uis(berth.panel)
