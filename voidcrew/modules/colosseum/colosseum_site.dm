/**
 * # The Grand Colosseum — overmap site
 *
 * A monumental PvP event venue surfaced mid-round by the Grand Colosseum
 * dynamic event (colosseum_event.dm), never at roundstart. One per round.
 *
 * Mirrors the trader-outpost pattern: the interior template loads permanently
 * into a turf reservation, ships dock into per-ship hangar berths
 * (voidcrew/modules/trade/outpost_hangar.dm) and ride the alcove elevator up to
 * the concourse. The building itself is indestructible by construction — every
 * structural turf in the template is /turf/closed/indestructible or
 * /turf/open/indestructible, and the only ways onto the fighting floor are the
 * ten id-tagged poddoors this site collects at load.
 *
 * Unlike trader outposts the site is event-spawned, but like them it never
 * unloads once open: matches must be repeatable indefinitely, so the interior
 * (and all match state on it) stays for the rest of the round.
 */

/// The one colosseum this round, or null. Guards against double-spawns
/// (event + admin verb) — UNIQUE_AREA interiors cannot coexist anyway.
GLOBAL_DATUM(colosseum_site, /obj/structure/overmap/colosseum)

/datum/map_template/colosseum
	name = "Grand Colosseum"
	mappath = "voidcrew/_maps/map_files/events/grand_colosseum_main.dmm"

// ===== INTERIOR LANDMARKS =====
// Consumed (or indexed) by link_interior(). All are optional in the map:
// every consumer has a geometric fallback so hand-edits can't brick the venue.

/obj/effect/landmark/colosseum
	name = "colosseum landmark"

/// Contestant seating spot in the red team ready room.
/obj/effect/landmark/colosseum/spawn_red
	name = "colosseum red seating"

/// Contestant seating spot in the blue team ready room.
/obj/effect/landmark/colosseum/spawn_blue
	name = "colosseum blue seating"

/// Contestant seating spot in one solo cell (one landmark per cell).
/obj/effect/landmark/colosseum/spawn_cell
	name = "colosseum cell seating"

/// Red CTF flag plinth (arena west).
/obj/effect/landmark/colosseum/flag_red
	name = "colosseum red flag plinth"

/// Blue CTF flag plinth (arena east).
/obj/effect/landmark/colosseum/flag_blue
	name = "colosseum blue flag plinth"

/// King-of-the-hill dais marker (arena center).
/obj/effect/landmark/colosseum/koth
	name = "colosseum dais marker"

/// Candidate spot for dynamic arena events (crate drops, hazards, cover).
/obj/effect/landmark/colosseum/arena_event
	name = "colosseum arena event spot"

/// Where corpses are laid out for retrieval after the claim window.
/obj/effect/landmark/colosseum/infirmary
	name = "colosseum infirmary berth"

// ===== THE OVERMAP SITE =====

/obj/structure/overmap/colosseum
	name = "the Grand Colosseum"
	desc = "An ancient monumental arena drum, carved into a bedrock shard. Its hull has shrugged off worse than your weapons. A standing broadcast invites all comers: fight, wager, spectate."
	icon_state = "station"
	color = "#e8b84a"

	/// The interior template instance
	var/datum/map_template/colosseum/template
	/// The permanent turf reservation holding the interior
	var/datum/turf_reservation/reservation
	/// Whether the interior has been loaded
	var/loaded = FALSE
	/// Whether the interior is currently loading
	var/loading = FALSE
	/// Internal wideband transmitter for galaxy-wide announcements
	var/obj/item/radio/headset/radio
	/// The match controller running this venue's state machine
	var/datum/colosseum_controller/controller
	/// The concourse signup console (mapped, or fallback-spawned at link)
	var/obj/machinery/computer/colosseum_signup/signup_console
	/// The spoils vault (mapped, or fallback-spawned at link)
	var/obj/machinery/colosseum_vault/spoils_vault

	/// Arena gate poddoors, keyed by mapped id ("colo_gate_red" -> list of doors)
	var/list/gate_doors = list()
	/// All interior turfs per colosseum area typepath (area typepath -> list of turfs)
	var/list/area_turfs = list()
	/// Landmark-marked turfs, keyed by landmark typepath -> list of turfs.
	/// Landmarks are deleted at link; only their turfs are kept.
	var/list/landmark_turfs = list()

/obj/structure/overmap/colosseum/Initialize(mapload)
	. = ..()
	if(GLOB.colosseum_site && GLOB.colosseum_site != src)
		stack_trace("Second colosseum spawned while one already exists — deleting the newcomer.")
		return INITIALIZE_HINT_QDEL
	GLOB.colosseum_site = src
	berths = new /list(OUTPOST_MAX_BERTHS)
	radio = new(src)
	radio.subspace_transmission = TRUE
	radio.canhear_range = 0
	radio.set_listening(FALSE)
	radio.recalculateChannels()

/obj/structure/overmap/colosseum/Destroy()
	if(GLOB.colosseum_site == src)
		GLOB.colosseum_site = null
	clear_waypoints()
	QDEL_NULL(controller)
	QDEL_NULL(radio)
	signup_console = null
	spoils_vault = null
	// Admin deletion must not leak hangar reservations
	for(var/datum/outpost_berth/berth as anything in berths)
		if(berth)
			berth.release(force = TRUE)
	berths = null
	lobby_alcove_turfs.Cut()
	lobby_wall_turfs.Cut()
	lobby_panels.Cut()
	gate_doors.Cut()
	area_turfs.Cut()
	landmark_turfs.Cut()
	template_bottom_left = null
	return ..()

/obj/structure/overmap/colosseum/examine(mob/user)
	. = ..()
	. += span_notice("All vessels welcome. Contestants register at the concourse; spectators watch from behind the glass.")

// ===== ANNOUNCEMENTS =====

/**
 * Galaxy-wide broadcast: a Wideband transmission (in-fiction, reaches every
 * headset) plus a priority announcement (guaranteed delivery to players without
 * radios). Wideband is unscoped, so the site's z-level doesn't matter — see
 * voidcrew/modules/comms/comms.dm.
 */
/obj/structure/overmap/colosseum/proc/broadcast_galaxy(message, title = "Grand Colosseum")
	priority_announce(message, title, sender_override = "Grand Colosseum Master of Games")
	radio?.talk_into(src, message, RADIO_CHANNEL_WIDEBAND)

/// Unique helm-waypoint key for the venue.
/obj/structure/overmap/colosseum/proc/waypoint_key()
	return "colosseum_[REF(src)]"

/// Human-readable overmap grid position for announcements.
/obj/structure/overmap/colosseum/proc/coords_text()
	var/list/coords = get_relative_overmap_coords()
	return coords ? "grid [coords[1]], [coords[2]]" : "an unknown position"

/**
 * Opens the venue: loads the interior, reveals the site, pushes a helm waypoint
 * to every crewed ship and tells the galaxy the games are on. Called once by
 * the spawn event (or the admin force-spawn) right after placement.
 */
/obj/structure/overmap/colosseum/proc/open_venue()
	load_level()
	if(!loaded)
		log_mapping("COLOSSEUM: interior failed to load, retiring the site.")
		qdel(src)
		return FALSE
	surveyed = TRUE
	controller = new(src)

	var/list/coords = get_relative_overmap_coords()
	broadcast_galaxy("Hear ye, spacers! The Grand Colosseum has surfaced at [coords_text()]. Glory and prizes await contestants; wagering and refreshments await everyone else. Dock and register at the concourse.")
	for(var/obj/structure/overmap/ship/ship as anything in SSovermap.simulated_ships)
		if(QDELETED(ship))
			continue
		ship.add_waypoint(waypoint_key(), "Grand Colosseum", coords ? coords[1] : 0, coords ? coords[2] : 0, "Events", track_target = src)
	notify_ghosts("The Grand Colosseum has surfaced — blood and prizes at [coords_text()]!", source = src, header = "Grand Colosseum")
	log_game("Grand Colosseum surfaced at overmap [coords_text()].")
	return TRUE

/// Removes the venue waypoint from every ship's helm readout.
/obj/structure/overmap/colosseum/proc/clear_waypoints()
	if(!SSovermap)
		return
	for(var/obj/structure/overmap/ship/ship as anything in SSovermap.simulated_ships)
		if(QDELETED(ship))
			continue
		ship.remove_waypoint(waypoint_key())

// ===== INTERIOR LOAD / LINK =====

/**
 * Loads the colosseum interior into a permanent turf reservation.
 * Same approach as trader outposts: load once, keep for the round.
 */
/obj/structure/overmap/colosseum/proc/load_level()
	if(reservation || loading)
		return
	loading = TRUE

	if(!template)
		template = new

	if(!template.width || !template.height)
		log_mapping("COLOSSEUM: template has no dimensions, cannot load.")
		loading = FALSE
		return

	reservation = SSmapping.request_turf_block_reservation(template.width, template.height, 1)
	if(!reservation)
		loading = FALSE
		return

	var/turf/bottom_left = reservation.bottom_left_turfs[1]
	template_bottom_left = bottom_left

	var/load_success = FALSE
	try
		load_success = template.load(bottom_left)
	catch(var/exception/e)
		log_mapping("COLOSSEUM: failed to load template: [e]")
		load_success = FALSE

	if(!load_success)
		qdel(reservation)
		reservation = null
		template_bottom_left = null
		loading = FALSE
		return

	link_interior()

	loaded = TRUE
	loading = FALSE

/// Resolves a template-local coordinate (1-based, as in DESIGN.md) to a live turf.
/obj/structure/overmap/colosseum/proc/local_turf(x, y)
	if(!template_bottom_left)
		return null
	return locate(template_bottom_left.x + x - 1, template_bottom_left.y + y - 1, template_bottom_left.z)

/**
 * Scans the freshly loaded footprint and indexes everything match logic needs:
 * elevator alcove/panels (berth-host wiring), the ten gate poddoors by id,
 * per-area turf lists and all colosseum landmarks. Idempotent by construction —
 * it only ever runs once per load, but collections are rebuilt from scratch.
 */
/obj/structure/overmap/colosseum/proc/link_interior()
	if(!template_bottom_left || !template?.width || !template?.height)
		return
	var/turf/top_right = locate(
		template_bottom_left.x + template.width - 1,
		template_bottom_left.y + template.height - 1,
		template_bottom_left.z
	)
	if(!top_right)
		return
	gate_doors = list()
	area_turfs = list()
	landmark_turfs = list()
	for(var/turf/interior_turf as anything in block(template_bottom_left, top_right))
		var/area/turf_area = interior_turf.loc
		if(istype(turf_area, /area/voidcrew/colosseum))
			LAZYADDASSOCLIST(area_turfs, turf_area.type, interior_turf)
		// block() iterates y-major then x — same order the hangar-side alcove
		// collects in, so the elevator can map alcove turf i to alcove turf i.
		for(var/obj/effect/landmark/outpost_elevator_alcove/alcove_mark in interior_turf)
			lobby_alcove_turfs += interior_turf
			qdel(alcove_mark)
		for(var/obj/effect/landmark/colosseum/colo_mark in interior_turf)
			LAZYADDASSOCLIST(landmark_turfs, colo_mark.type, interior_turf)
			qdel(colo_mark)
		for(var/obj/machinery/machine in interior_turf)
			if(istype(machine, /obj/machinery/outpost_elevator))
				var/obj/machinery/outpost_elevator/panel = machine
				panel.outpost = src
				panel.is_lobby = TRUE
				lobby_panels += panel
			else if(istype(machine, /obj/machinery/door/poddoor))
				var/obj/machinery/door/poddoor/gate = machine
				if(istext(gate.id) && findtext(gate.id, "colo_"))
					LAZYADDASSOCLIST(gate_doors, gate.id, gate)
			else if(istype(machine, /obj/machinery/computer/colosseum_signup))
				var/obj/machinery/computer/colosseum_signup/console = machine
				console.site = src
				signup_console = console
			else if(istype(machine, /obj/machinery/colosseum_vault))
				var/obj/machinery/colosseum_vault/vault = machine
				vault.site = src
				spoils_vault = vault
	// The venue must function even if a map edit loses the service machinery —
	// fall back to spawning it on any clear concourse tile.
	if(!signup_console)
		var/turf/console_turf = get_random_lobby_turf()
		if(console_turf)
			signup_console = new(console_turf)
			signup_console.site = src
			log_mapping("COLOSSEUM: template has no signup console — fallback-spawned one at ([console_turf.x], [console_turf.y]).")
	if(!spoils_vault)
		var/turf/vault_turf = get_random_lobby_turf()
		if(vault_turf)
			spoils_vault = new(vault_turf)
			spoils_vault.site = src
			log_mapping("COLOSSEUM: template has no spoils vault — fallback-spawned one at ([vault_turf.x], [vault_turf.y]).")
	if(!length(lobby_alcove_turfs))
		log_mapping("COLOSSEUM: template has no elevator alcove landmarks — ships cannot reach the concourse.")
	if(!length(lobby_panels))
		log_mapping("COLOSSEUM: template has no concourse elevator panel.")
	for(var/expected_id in list(COLOSSEUM_GATE_RED, COLOSSEUM_GATE_BLUE, COLOSSEUM_GATE_SOLO, COLOSSEUM_SEAL))
		if(!length(gate_doors[expected_id]))
			log_mapping("COLOSSEUM: no poddoors found with id '[expected_id]'.")

/// All interior turfs belonging to the given colosseum area typepath.
/obj/structure/overmap/colosseum/proc/get_area_turfs_cached(area_type)
	return area_turfs[area_type] || list()

/// Landmark-marked turfs of the given landmark typepath (may be empty).
/obj/structure/overmap/colosseum/proc/get_landmark_turfs(landmark_type)
	return landmark_turfs[landmark_type] || list()

/// A random clear standing spot in the given colosseum area (null if none).
/obj/structure/overmap/colosseum/proc/get_random_clear_turf(area_type, tries = 20)
	var/list/candidates = get_area_turfs_cached(area_type)
	if(!length(candidates))
		return null
	for(var/_ in 1 to tries)
		var/turf/candidate = pick(candidates)
		if(!candidate.is_blocked_turf())
			return candidate
	return null

/// A random clear concourse tile — ejection destination and machinery fallback.
/obj/structure/overmap/colosseum/proc/get_random_lobby_turf()
	return get_random_clear_turf(/area/voidcrew/colosseum/lobby) || (length(lobby_alcove_turfs) ? pick(lobby_alcove_turfs) : null)

/**
 * Infirmary berth turfs for laying out the dead. Prefers mapped infirmary
 * landmarks; falls back to the infirmary's mid-row per DESIGN.md (x49..55 y23),
 * then any clear lobby tile.
 */
/obj/structure/overmap/colosseum/proc/get_infirmary_turfs()
	var/list/marked = get_landmark_turfs(/obj/effect/landmark/colosseum/infirmary)
	if(length(marked))
		return marked
	var/list/fallback = list()
	for(var/x in 49 to 55)
		var/turf/T = local_turf(x, 23)
		if(T && !T.is_blocked_turf())
			fallback += T
	if(length(fallback))
		return fallback
	var/turf/last_resort = get_random_lobby_turf()
	return last_resort ? list(last_resort) : list()

/// Sends a chat line to every player currently inside the venue.
/obj/structure/overmap/colosseum/proc/venue_message(message)
	for(var/mob/player as anything in GLOB.player_list)
		if(istype(get_area(player), /area/voidcrew/colosseum))
			to_chat(player, message)

// ===== GATE CONTROL =====
// Event code drives the mapped ids directly; the referee-box buttons keep
// working independently because they share the same ids.

/// Opens or closes every poddoor mapped with the given id.
/obj/structure/overmap/colosseum/proc/set_gates(gate_id, open)
	for(var/obj/machinery/door/poddoor/gate as anything in gate_doors[gate_id])
		if(QDELETED(gate))
			continue
		INVOKE_ASYNC(gate, open ? TYPE_PROC_REF(/obj/machinery/door, open) : TYPE_PROC_REF(/obj/machinery/door, close))

/// Closes every arena gate and reopens the staging rear seals (idle posture).
/obj/structure/overmap/colosseum/proc/gates_to_idle()
	set_gates(COLOSSEUM_GATE_RED, FALSE)
	set_gates(COLOSSEUM_GATE_BLUE, FALSE)
	set_gates(COLOSSEUM_GATE_SOLO, FALSE)
	set_gates(COLOSSEUM_SEAL, TRUE)

// ===== DOCKING =====

/obj/structure/overmap/colosseum/attack_ghost(mob/user)
	if(length(lobby_alcove_turfs))
		user.forceMove(pick(lobby_alcove_turfs))
		return TRUE
	if(template_bottom_left)
		user.forceMove(template_bottom_left)
		return TRUE
	return

/**
 * Handles ship docking: allocates the ship its own hangar berth (see
 * outpost_hangar.dm) and docks it there. The interior is already loaded —
 * open_venue() ran at spawn — but load_level() is retried defensively.
 */
/obj/structure/overmap/colosseum/ship_act(mob/user, obj/structure/overmap/ship/acting, obj/structure/overmap/ship/optional_partner)
	if(concerned)
		to_chat(user, span_notice("Too much traffic, try again later!"))
		return
	concerned = TRUE

	var/prev_state = acting.state
	acting.state = OVERMAP_SHIP_ACTING
	balloon_alert(user, "starting docking process..")

	load_level()

	if(!reservation || !loaded)
		acting.state = prev_state
		concerned = FALSE
		to_chat(user, span_warning("Failed to load the location."))
		return

	var/obj/docking_port/stationary/dock_to_use = null
	var/datum/outpost_berth/berth = null

	// Port destinations are set by survey console
	if(acting.shuttle.port_destinations)
		dock_to_use = acting.shuttle.port_destinations
	else
		// Cheap size gate before spending a reservation on a ship that can't fit
		var/long_axis = max(acting.shuttle.width, acting.shuttle.height)
		var/short_axis = min(acting.shuttle.width, acting.shuttle.height)
		if(long_axis > RESERVE_DOCK_MAX_SIZE_LONG || short_axis > RESERVE_DOCK_MAX_SIZE_SHORT)
			acting.state = prev_state
			concerned = FALSE
			to_chat(user, span_warning("Ship is too large for [name]'s hangar berths."))
			return

		berth = allocate_berth(acting)
		if(!berth)
			acting.state = prev_state
			concerned = FALSE
			to_chat(user, span_notice("[name] traffic control: all hangar berths are occupied. Try again later."))
			return
		adjust_reserve_dock_to_shuttle(berth.dock, acting.shuttle)
		dock_to_use = berth.dock

	if(acting.shuttle.height > dock_to_use.height || acting.shuttle.width > dock_to_use.width)
		berth?.release(force = TRUE) // nothing has landed yet, safe to free immediately
		acting.state = prev_state
		concerned = FALSE
		to_chat(user, span_warning("Ship is too large to dock at this location."))
		return

	to_chat(user, span_notice("[acting.dock(src, dock_to_use)]"))

	concerned = FALSE

	if(optional_partner)
		ship_act(user, optional_partner)
