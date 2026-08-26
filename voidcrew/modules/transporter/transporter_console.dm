/**
 * # Transporter control console
 *
 * Aims the pad. A pad on its own can't do anything - it has no idea what the ship is
 * orbiting, and no way to pick a spot on it. The console holds the orbital lock, the
 * transponder register and the research gating.
 *
 * Without the targeting node it can only drop people onto open ground the computer
 * picks for them, and only recover people who are carrying a transponder and standing
 * in the open. With it, the operator picks the exact turf at either end, which is what
 * makes the transporter a weapon as well as a lift.
 */
/obj/machinery/computer/transporter
	name = "transporter control console"
	desc = "Runs a transporter pad. Holds an orbital pattern lock on whatever the ship is circling, keeps a register of the transponders the crew took down with them, and decides where a beam comes out."
	icon_screen = "teleport"
	icon_keyboard = "teleport_key"
	light_color = LIGHT_COLOR_BLUE
	circuit = /obj/item/circuitboard/computer/transporter

	/// The pad this console drives.
	var/obj/machinery/transporter_pad/linked_pad
	/// Techweb this console reads its unlocks from. Linked with a multitool.
	var/datum/techweb/linked_techweb

	/// Cached overmap ship. Resolved lazily, because it doesn't exist at Initialize.
	var/obj/structure/overmap/ship/linked_ship
	/// Rate limits the (not free) search for our containing shuttle.
	COOLDOWN_DECLARE(ship_lookup_cooldown)

	/// Locked coordinates on the orbited object. Stored loose rather than as a turf ref
	/// so terrain being rebuilt underneath the lock can't leave us holding a dead turf.
	var/locked_x = 0
	var/locked_y = 0
	var/locked_z = 0

	/// The targeting scanner eye, while someone is using it.
	var/mob/eye/camera/remote/transporter/eyeobj
	/// Whoever is currently driving the scanner.
	var/mob/living/current_user
	/// Actions handed to the scanner operator.
	var/list/actions = list()

	/// Admin/testing switch. Treats every research node as unlocked.
	var/debug_mode = FALSE

/obj/machinery/computer/transporter/Initialize(mapload)
	. = ..()
	actions += new /datum/action/innate/transporter_lock(src)
	actions += new /datum/action/innate/transporter_scanner_off(src)
	// Machines don't initialise in map order, so give the pad a moment to exist.
	addtimer(CALLBACK(src, PROC_REF(find_nearby_pad)), 1 SECONDS)

/obj/machinery/computer/transporter/Destroy()
	if(current_user)
		remove_eye_control(current_user)
	QDEL_NULL(eyeobj)
	QDEL_LIST(actions)
	unsync_research_servers()
	if(linked_pad?.linked_console == src)
		linked_pad.linked_console = null
	linked_pad = null
	if(linked_ship)
		UnregisterSignal(linked_ship, COMSIG_VOIDCREW_SHIP_MOVED)
		linked_ship = null
	return ..()

/obj/machinery/computer/transporter/unsync_research_servers()
	if(linked_techweb)
		linked_techweb.connected_machines -= src
		linked_techweb = null

/obj/machinery/computer/transporter/examine(mob/user)
	. = ..()
	. += span_notice("It is [linked_pad ? "driving a transporter pad" : "not connected to a transporter pad"].")
	. += span_notice("Research uplink is [linked_techweb ? "connected" : "unlinked - a multitool will carry the link over from an R&D server"].")

/// TRUE if the console's research uplink has the given node.
/obj/machinery/computer/transporter/proc/has_research(node_id)
	if(debug_mode)
		return TRUE
	if(!linked_techweb)
		return FALSE
	return (node_id in linked_techweb.researched_nodes)

// ---------------------------------------------------------------------------
// Linking
// ---------------------------------------------------------------------------

/obj/machinery/computer/transporter/multitool_act(mob/living/user, obj/item/multitool/multi_tool)
	if(istype(multi_tool.buffer, /datum/techweb))
		if(linked_techweb == multi_tool.buffer)
			balloon_alert(user, "already linked")
			return ITEM_INTERACT_BLOCKING
		unsync_research_servers()
		linked_techweb = multi_tool.buffer
		linked_techweb.connected_machines += src
		balloon_alert(user, "research uplink set")
		return ITEM_INTERACT_SUCCESS

	if(istype(multi_tool.buffer, /obj/machinery/transporter_pad))
		var/obj/machinery/transporter_pad/pad = multi_tool.buffer
		if(SSshuttle.get_containing_shuttle(pad) != SSshuttle.get_containing_shuttle(src))
			balloon_alert(user, "pad is on another vessel!")
			return ITEM_INTERACT_BLOCKING
		link_pad(pad)
		balloon_alert(user, "pad linked")
		return ITEM_INTERACT_SUCCESS

	balloon_alert(user, "no pad or research data in buffer!")
	return ITEM_INTERACT_BLOCKING

/// Claims a pad, dropping whatever console held it before.
/obj/machinery/computer/transporter/proc/link_pad(obj/machinery/transporter_pad/pad)
	if(QDELETED(pad))
		return
	if(linked_pad?.linked_console == src)
		linked_pad.linked_console = null
	if(pad.linked_console && pad.linked_console != src)
		pad.linked_console.linked_pad = null
	linked_pad = pad
	pad.linked_console = src

/// Grabs an unclaimed pad sitting next to us, so a mapped-in pair works out of the box.
/obj/machinery/computer/transporter/proc/find_nearby_pad()
	if(linked_pad)
		return
	for(var/obj/machinery/transporter_pad/pad in range(5, src))
		if(pad.linked_console)
			continue
		link_pad(pad)
		return

// ---------------------------------------------------------------------------
// Orbital lock
// ---------------------------------------------------------------------------

/// The overmap ship this console is installed on, or null if it isn't on one.
/obj/machinery/computer/transporter/proc/get_ship()
	if(linked_ship)
		return linked_ship
	if(!COOLDOWN_FINISHED(src, ship_lookup_cooldown))
		return null
	COOLDOWN_START(src, ship_lookup_cooldown, 5 SECONDS)

	var/obj/docking_port/mobile/voidcrew/port = SSshuttle.get_containing_shuttle(src)
	if(!istype(port) || !port.current_ship)
		return null

	linked_ship = port.current_ship
	RegisterSignal(linked_ship, COMSIG_VOIDCREW_SHIP_MOVED, PROC_REF(on_ship_moved))
	return linked_ship

/// Whatever the ship is close enough to beam onto, or null.
/obj/machinery/computer/transporter/proc/get_orbited_object()
	var/obj/structure/overmap/ship/ship = get_ship()
	if(!ship)
		return null
	for(var/obj/structure/overmap/object as anything in ship.close_overmap_objects)
		if(istype(object, /obj/structure/overmap/ship))
			continue
		if(!debug_mode && istype(object, /obj/structure/overmap/planet/empty))
			continue
		if(istype(object, /obj/structure/overmap/planet))
			return object
		if(istype(object, /obj/structure/overmap/space_ruin))
			return object
		if(istype(object, /obj/structure/overmap/event/meteor))
			return object
	return null

/// An orbital lock only holds while the ship holds still. Moving drops everything.
/obj/machinery/computer/transporter/proc/on_ship_moved()
	SIGNAL_HANDLER
	clear_lock()
	if(current_user)
		to_chat(current_user, span_warning("The ship comes about and the targeting scanner loses its lock."))
		remove_eye_control(current_user)

/**
 * TRUE if a turf belongs to the object the ship is currently orbiting.
 *
 * Every branch is scoped to the orbited object's own footprint, never to "the same
 * z-level". Space ruins and meteor fields sit on shared reserved z-levels alongside
 * other crews' reservations; planets and flat encounters now share a z-level with up
 * to three co-tenants of their own (see /datum/map_footprint). Either way a bare
 * z-match would let a console reach into a site the ship is nowhere near - and this
 * proc is the console's security gate: validate_site(), get_locked_site() and
 * get_reachable_transponders() all sit behind it.
 */
/obj/machinery/computer/transporter/proc/turf_in_range(turf/tile)
	if(!tile)
		return FALSE
	var/obj/structure/overmap/target = get_orbited_object()
	if(!target)
		return FALSE

	if(istype(target, /obj/structure/overmap/planet))
		var/obj/structure/overmap/planet/planet = target
		if(!planet.mapzone)
			return FALSE
		// The planet's slot on its level, which is what "the planet below" means once a
		// level holds more than one of them. A site with no footprint (nothing has dealt
		// it a slot) falls back to the z-match this always used.
		if(planet.footprint)
			return planet.footprint.contains_turf(tile)
		for(var/datum/space_level/level as anything in planet.mapzone.z_levels)
			if(level.z_value == tile.z)
				return TRUE
		return FALSE

	// Sites on the slot lattice answer with a rectangle; the remaining reservation tenants
	// answer with their block. Both are the same question - "is this turf the target's".
	var/datum/map_footprint/site_footprint = target?.get_interior_footprint()
	if(site_footprint)
		return site_footprint.contains_turf(tile)

	return FALSE

/**
 * TRUE for terrain with open sky above it, which is all a coarse pattern lock can
 * find. Caves are roofed and planet ruins have a structure over them, so neither
 * counts until the targeting node can thread a beam through one.
 */
/obj/machinery/computer/transporter/proc/is_open_ground(area/site_area)
	if(istype(site_area, /area/overmap_encounter/planetoid/cave))
		return FALSE
	if(istype(site_area, /area/overmap_encounter/planetoid))
		return TRUE
	return istype(site_area, /area/space)

/// Whether a beam can terminate on this turf, as a TRANSPORTER_SITE_* code.
/obj/machinery/computer/transporter/proc/validate_site(turf/tile)
	if(!tile || !turf_in_range(tile))
		return TRANSPORTER_SITE_NO_LOCK

	var/area/site_area = get_area(tile)
	if(!site_area)
		return TRANSPORTER_SITE_NO_LOCK

	// Planet surfaces and caves are ordinary ground and carry no teleport flags, so they
	// need no exception here. Anything that does set NOTELEPORT - a shielded ruin
	// interior, a lich lair, an arena - is a deliberately shielded place and stays that
	// way, and LOCAL_TELEPORT always means "no beams in or out". Roofs are a separate
	// problem, handled by the targeting node below.
	if(site_area.area_flags & (LOCAL_TELEPORT | NOTELEPORT))
		return TRANSPORTER_SITE_SHIELDED

	// A raw pattern lock can only find open sky. Threading a beam through a roof is
	// what the targeting node buys.
	if(!has_research(TECHWEB_NODE_TRANSPORTER_TARGETING) && !is_open_ground(site_area))
		return TRANSPORTER_SITE_SEALED

	if(tile.density || isgroundlessturf(tile))
		return TRANSPORTER_SITE_BLOCKED

	for(var/atom/movable/thing in tile)
		if(thing.density && thing.anchored)
			return TRANSPORTER_SITE_BLOCKED
		if(GLOB.transporter_mass_blacklist[thing.type])
			return TRANSPORTER_SITE_BLOCKED

	return TRANSPORTER_SITE_CLEAR

/// Human readable version of a TRANSPORTER_SITE_* code.
/obj/machinery/computer/transporter/proc/site_status_text(code)
	switch(code)
		if(TRANSPORTER_SITE_CLEAR)
			return "clear"
		if(TRANSPORTER_SITE_BLOCKED)
			return "something is standing in the way"
		if(TRANSPORTER_SITE_SEALED)
			return "no line to open sky - precision targeting required"
		if(TRANSPORTER_SITE_SHIELDED)
			return "the site refuses a pattern lock"
	return "outside the orbital lock"

// ---------------------------------------------------------------------------
// Site selection
// ---------------------------------------------------------------------------

/// The site currently locked in, or null if there isn't a usable one.
/obj/machinery/computer/transporter/proc/get_locked_site()
	if(!locked_z)
		return null
	var/turf/site = locate(locked_x, locked_y, locked_z)
	if(!site || !turf_in_range(site))
		clear_lock()
		return null
	return site

/obj/machinery/computer/transporter/proc/clear_lock()
	locked_x = 0
	locked_y = 0
	locked_z = 0

/**
 * Picks somewhere on the surface at random.
 *
 * Planets only. On anything else the computer has no charted open ground to fall back
 * on, so the operator has to aim it themselves.
 */
/obj/machinery/computer/transporter/proc/get_random_site()
	var/obj/structure/overmap/planet/planet = get_orbited_object()
	if(!istype(planet) || !planet.mapzone)
		return null

	// This planet's slot on its level. Everything below is scoped to it: the level is
	// shared with up to three co-tenants, whose surface areas are registered under the
	// same z AND, for a same-biome neighbour, are the same area TYPE.
	var/datum/map_footprint/footprint = planet.footprint

	// Area INSTANCE to the z-level we want it on. Keying by type collapsed two
	// same-biome tenants into one entry, and the carried z - which used to be what kept
	// this off other crews' worlds - no longer distinguishes them either. The footprint
	// filter below is what does that now; the z is still carried because get_area_turfs()
	// needs it.
	var/list/candidate_areas = list()
	for(var/datum/space_level/level as anything in planet.mapzone.z_levels)
		for(var/area/site_area as anything in SSmapping.areas_in_z["[level.z_value]"])
			// Caves are open ground but dropping someone into an unlit tunnel at
			// random is a death sentence, so the computer won't choose one.
			if(istype(site_area, /area/overmap_encounter/planetoid/cave))
				continue
			if(istype(site_area, /area/overmap_encounter/planetoid))
				candidate_areas[site_area] = level.z_value
	if(!length(candidate_areas))
		return null

	// One turf list per area, reused across attempts. get_area_turfs() copies every
	// turf of the area on that z - roughly 16,000 on a 128x128 surface - and re-picking
	// the same area used to pay for that again. Reusing the list also carries the Cut()s
	// forward, so a later attempt never re-tests a turf an earlier one already rejected.
	var/list/turfs_by_area = list()
	for(var/attempt in 1 to 5)
		var/area/chosen = pick(candidate_areas)
		var/list/turf/tiles = turfs_by_area[chosen]
		if(isnull(tiles))
			tiles = get_area_turfs(chosen, candidate_areas[chosen])
			// get_area_turfs() collapses its argument back to a TYPEPATH, so what comes
			// back is every area of that type on the z - the co-tenant's ground included.
			// Filtered once here rather than leaned on validate_site(), so a run of
			// samples cannot be spent entirely on turfs that were never ours.
			if(footprint && length(tiles))
				var/list/turf/inside = list()
				for(var/turf/tile as anything in tiles)
					if(footprint.contains_turf(tile))
						inside += tile
				tiles = inside
			turfs_by_area[chosen] = tiles
		for(var/sample in 1 to 40)
			if(!length(tiles))
				break
			var/index = rand(1, length(tiles))
			var/turf/candidate = tiles[index]
			if(validate_site(candidate) == TRANSPORTER_SITE_CLEAR)
				return candidate
			tiles.Cut(index, index + 1)

	return null

/// Transponders on the surface below, in range of the current lock.
/obj/machinery/computer/transporter/proc/get_reachable_transponders()
	var/list/found = list()
	if(!linked_pad)
		return found
	for(var/obj/item/transporter_transponder/transponder as anything in linked_pad.paired_transponders)
		if(QDELETED(transponder))
			continue
		var/turf/where = get_turf(transponder)
		if(!where || !turf_in_range(where))
			continue
		found += transponder
	return found

// ---------------------------------------------------------------------------
// Running a beam
// ---------------------------------------------------------------------------

/**
 * Common entry point for every beam this console can order.
 * Returns null on success, or a short reason it couldn't.
 */
/obj/machinery/computer/transporter/proc/execute_beam(turf/source, turf/destination, mob/user)
	if(!linked_pad)
		return "no transporter pad linked"
	var/reason = linked_pad.blocking_reason()
	if(reason)
		return reason
	if(!source || !destination)
		return "no pattern lock"

	// Only the surface end gets validated. The pad end is a machine on a powered deck.
	var/turf/surface_end = (source == get_turf(linked_pad)) ? destination : source
	var/status = validate_site(surface_end)
	if(status != TRANSPORTER_SITE_CLEAR)
		return site_status_text(status)

	if(!linked_pad.begin_transport(source, destination, user))
		return "nothing in the pattern buffer"
	return null

/// Sends whatever is standing on the pad down to the surface.
/obj/machinery/computer/transporter/proc/beam_down(mob/user, use_lock = TRUE)
	if(!linked_pad)
		return "no transporter pad linked"
	// The pad's own gate first. get_random_site() copies whole planet surface areas
	// turf by turf, and the button that reaches this stays clickable for the entire
	// recharge - searching for a landing site the pad can't use yet is work nobody
	// asked for, repeatable as fast as the operator can click.
	var/reason = linked_pad.blocking_reason()
	if(reason)
		return reason
	var/turf/destination = use_lock ? get_locked_site() : get_random_site()
	if(!destination && use_lock)
		destination = get_random_site()
	if(!destination)
		return "no viable landing site on the surface"
	return execute_beam(get_turf(linked_pad), destination, user)

/// Pulls whatever is standing on the locked coordinates up onto the pad.
/obj/machinery/computer/transporter/proc/beam_up_site(mob/user)
	if(!linked_pad)
		return "no transporter pad linked"
	if(!has_research(TECHWEB_NODE_TRANSPORTER_TARGETING))
		return "precision targeting not researched"
	var/turf/source = get_locked_site()
	if(!source)
		return "no coordinates locked"
	return execute_beam(source, get_turf(linked_pad), user)

/// Pulls up whoever is carrying the given transponder.
/obj/machinery/computer/transporter/proc/beam_up_transponder(obj/item/transporter_transponder/transponder, mob/user)
	if(!linked_pad)
		return "no transporter pad linked"
	if(QDELETED(transponder) || !(transponder in linked_pad.paired_transponders))
		return "transponder is not on the register"
	var/turf/source = get_turf(transponder)
	if(!source)
		return "transponder signal lost"
	return execute_beam(source, get_turf(linked_pad), user)

/**
 * Called by a transponder on the surface asking to come home.
 * Returns null on success, or a short reason it couldn't.
 */
/obj/machinery/computer/transporter/proc/request_beam_up(obj/item/transporter_transponder/transponder, mob/user)
	if(!is_operational)
		return "control console is offline"
	return beam_up_transponder(transponder, user)

// ---------------------------------------------------------------------------
// Targeting scanner
// ---------------------------------------------------------------------------

/// Where the scanner opens. The surface dock is where the crew would be, if any are.
/obj/machinery/computer/transporter/proc/get_targeting_anchor()
	var/obj/structure/overmap/target = get_orbited_object()
	if(!target)
		return null

	// Targeting a planet, ruin or hazard field forces a build of somewhere the ship never
	// docked at, which is the whole point of the scanner - but it opens an interface, so
	// every branch takes the worldgen queue only if the queue is free. Behind somebody
	// else's survey it reports no target rather than holding the window open until they
	// are finished.
	if(istype(target, /obj/structure/overmap/planet))
		var/obj/structure/overmap/planet/planet = target
		planet.load_level(queue_timeout = WORLDGEN_QUEUE_NO_WAIT)
		if(!planet.mapzone)
			return null
		if(planet.reserve_dock)
			return get_turf(planet.reserve_dock)
		// The middle of THIS planet's slot. The middle of the z-level is the gutter
		// between tenants - indestructible cordon, and turf_in_range() refuses it, so
		// the scanner eye would open onto a turf it is then not allowed to leave.
		var/turf/center = planet.footprint?.get_center_turf()
		if(center)
			return center
		var/datum/space_level/level = planet.mapzone.z_levels[1]
		return locate(round(world.maxx * 0.5), round(world.maxy * 0.5), level.z_value)

	if(istype(target, /obj/structure/overmap/space_ruin))
		var/obj/structure/overmap/space_ruin/ruin = target
		ruin.load_level(queue_timeout = WORLDGEN_QUEUE_NO_WAIT)
		if(!ruin.mapzone)
			return null
		return ruin.reserve_dock ? get_turf(ruin.reserve_dock) : ruin.footprint?.get_center_turf()

	if(istype(target, /obj/structure/overmap/event/meteor))
		var/obj/structure/overmap/event/meteor/field = target
		field.load_level(queue_timeout = WORLDGEN_QUEUE_NO_WAIT)
		if(!field.mapzone)
			return null
		return field.reserve_dock ? get_turf(field.reserve_dock) : field.footprint?.get_center_turf()

	return null

/obj/machinery/computer/transporter/proc/can_use(mob/living/user)
	if(QDELETED(user) || !isliving(user))
		return FALSE
	return can_interact(user)

/obj/machinery/computer/transporter/proc/start_targeting(mob/living/user)
	if(!can_use(user) || isnull(user.client))
		return
	if(!has_research(TECHWEB_NODE_TRANSPORTER_TARGETING))
		balloon_alert(user, "precision targeting not researched!")
		return
	if(!QDELETED(current_user))
		to_chat(user, span_warning("The targeting scanner is already in use."))
		return

	var/turf/anchor = get_targeting_anchor()
	if(!anchor)
		balloon_alert(user, "nothing in transporter range!")
		playsound(src, 'sound/machines/terminal/terminal_error.ogg', 40)
		return

	if(!eyeobj)
		eyeobj = new(get_turf(src), src)
	if(!eyeobj)
		return

	give_eye_control(user)
	eyeobj.setLoc(anchor, TRUE)

/obj/machinery/computer/transporter/proc/give_eye_control(mob/living/user)
	if(isnull(user?.client))
		return
	current_user = user
	eyeobj.assign_user(user)
	for(var/datum/action/to_grant as anything in actions)
		to_grant.Grant(user)
	// Aiming a beam at someone means being able to see them.
	user.add_sight(SEE_MOBS|SEE_OBJS)
	if(eyeobj.placement_image)
		user.client.images += eyeobj.placement_image
	RegisterSignal(user, COMSIG_MOVABLE_MOVED, PROC_REF(on_user_moved))
	playsound(src, 'sound/machines/terminal/terminal_on.ogg', 25, FALSE)

/obj/machinery/computer/transporter/remove_eye_control(mob/living/user)
	// Runs even if the user has gone or lost their client, or the console stays flagged
	// as in use forever and the eye leaks.
	if(user)
		UnregisterSignal(user, COMSIG_MOVABLE_MOVED)
		for(var/datum/action/to_remove as anything in actions)
			to_remove.Remove(user)
		if(user.client && eyeobj?.placement_image)
			user.client.images -= eyeobj.placement_image
	// Drop the user before deleting the eye, or the eye's Destroy() calls us back.
	eyeobj?.assign_user(null)
	current_user = null
	playsound(src, 'sound/machines/terminal/terminal_off.ogg', 25, FALSE)
	QDEL_NULL(eyeobj)

/// Walking away from the console drops the scanner.
/obj/machinery/computer/transporter/proc/on_user_moved()
	SIGNAL_HANDLER
	if(current_user)
		INVOKE_ASYNC(src, PROC_REF(remove_eye_control), current_user)

/// Recolours the crosshair as the scanner passes over turfs.
/obj/machinery/computer/transporter/proc/update_targeting_image(turf/tile)
	if(!eyeobj?.placement_image)
		return
	eyeobj.placement_image.loc = tile
	eyeobj.placement_image.icon_state = (validate_site(tile) == TRANSPORTER_SITE_CLEAR) ? "green" : "red"

/// Writes the scanner's current turf into the console's lock.
/obj/machinery/computer/transporter/proc/lock_coordinates(mob/living/user)
	var/turf/candidate = get_turf(eyeobj)
	var/status = validate_site(candidate)
	if(status != TRANSPORTER_SITE_CLEAR)
		to_chat(user, span_warning("Pattern lock refused: [site_status_text(status)]."))
		playsound(src, 'sound/machines/terminal/terminal_error.ogg', 40)
		return

	locked_x = candidate.x
	locked_y = candidate.y
	locked_z = candidate.z
	playsound(src, 'sound/machines/ping.ogg', 40)
	to_chat(user, span_notice("Pattern lock set on [get_area_name(candidate)], [locked_x]/[locked_y]."))
	remove_eye_control(user)
	ui_interact(user)

/**
 * The scanner eye. Confined to the object the ship is orbiting, which matters for
 * space ruins - those share reserved z-levels with other crews' reservations, and
 * without the confinement an operator could scroll into one.
 */
/mob/eye/camera/remote/transporter
	name = "transporter targeting scanner"
	use_visibility = FALSE
	move_on_shuttle = FALSE
	/// The crosshair drawn on the turf under the scanner.
	var/image/placement_image

/mob/eye/camera/remote/transporter/Initialize(mapload, obj/machinery/creator)
	. = ..()
	if(. == INITIALIZE_HINT_QDEL)
		return
	placement_image = image('icons/effects/alphacolors.dmi', src, "red")
	placement_image.layer = ABOVE_NORMAL_TURF_LAYER
	SET_PLANE_EXPLICIT(placement_image, ABOVE_GAME_PLANE, src)
	placement_image.mouse_opacity = MOUSE_OPACITY_TRANSPARENT

/mob/eye/camera/remote/transporter/Destroy()
	// Pull the crosshair off the viewer before the parent drops the user reference,
	// so an eye deleted by any path other than remove_eye_control can't leave a
	// stuck image on someone's screen.
	var/client/viewer = GetViewerClient()
	if(viewer && placement_image)
		viewer.images -= placement_image
	. = ..()
	placement_image = null

/mob/eye/camera/remote/transporter/setLoc(turf/destination, force_update = FALSE)
	var/obj/machinery/computer/transporter/console = origin_ref?.resolve()
	// Null console means we're still being built - let the initial placement through.
	if(istype(console) && !console.turf_in_range(destination))
		return
	. = ..()
	console?.update_targeting_image(get_turf(src))

/datum/action/innate/transporter_lock
	name = "Set Pattern Lock"
	button_icon = 'icons/mob/actions/actions_mecha.dmi'
	button_icon_state = "mech_zoom_off"

/datum/action/innate/transporter_lock/Activate()
	if(QDELETED(owner) || !isliving(owner))
		return
	var/mob/eye/camera/remote/transporter/scanner = owner.remote_control
	if(!istype(scanner))
		return
	var/obj/machinery/computer/transporter/console = scanner.origin_ref?.resolve()
	if(istype(console))
		console.lock_coordinates(owner)

/datum/action/innate/transporter_scanner_off
	name = "Close Targeting Scanner"
	button_icon = 'icons/mob/actions/actions_silicon.dmi'
	button_icon_state = "camera_off"

/datum/action/innate/transporter_scanner_off/Activate()
	if(QDELETED(owner) || !isliving(owner))
		return
	var/mob/eye/camera/remote/transporter/scanner = owner.remote_control
	if(!istype(scanner))
		return
	var/obj/machinery/computer/transporter/console = scanner.origin_ref?.resolve()
	if(istype(console))
		console.remove_eye_control(owner)

// ---------------------------------------------------------------------------
// Interface
// ---------------------------------------------------------------------------

/obj/machinery/computer/transporter/ui_interact(mob/user, datum/tgui/ui)
	. = ..()
	if(!linked_pad)
		find_nearby_pad()
	ui = SStgui.try_update_ui(user, src, ui)
	if(!ui)
		ui = new(user, src, "TransporterConsole", name)
		ui.open()

/obj/machinery/computer/transporter/ui_data(mob/user)
	var/list/data = list()

	data["padLinked"] = linked_pad ? TRUE : FALSE
	data["researchLinked"] = linked_techweb ? TRUE : FALSE
	data["targetingUnlocked"] = has_research(TECHWEB_NODE_TRANSPORTER_TARGETING)
	data["diagnosticsUnlocked"] = has_research(TECHWEB_NODE_TRANSPORTER_BIOFILTER)

	if(linked_pad)
		data["padStatus"] = linked_pad.blocking_reason() || "ready"
		data["padReady"] = isnull(linked_pad.blocking_reason())
		data["cooldownLeft"] = round(COOLDOWN_TIMELEFT(linked_pad, transport_recharge) / 10)
		data["beamSeconds"] = round(linked_pad.beam_time / 10, 0.1)
		data["bufferSize"] = linked_pad.pattern_buffer
		// Only a console with the biofilter matrix can tell a sabotaged pad from a
		// working one. Below that tier, a cut interlock looks exactly like nothing.
		if(has_research(TECHWEB_NODE_TRANSPORTER_BIOFILTER))
			data["patternIntegrity"] = (linked_pad.obj_flags & EMAGGED) ? "corrupted" : "nominal"
		else
			data["patternIntegrity"] = "unknown"

		var/list/manifest = list()
		for(var/atom/movable/thing as anything in linked_pad.gather_payload(get_turf(linked_pad)))
			manifest += list(list("name" = thing.name, "living" = isliving(thing)))
		data["padContents"] = manifest
	else
		data["padStatus"] = "no pad linked"
		data["padReady"] = FALSE
		data["cooldownLeft"] = 0
		data["beamSeconds"] = 0
		data["bufferSize"] = 0
		data["patternIntegrity"] = "unknown"
		data["padContents"] = list()

	var/obj/structure/overmap/target = get_orbited_object()
	data["targetName"] = target ? target.name : null

	var/turf/site = get_locked_site()
	if(site)
		data["lockedSite"] = "[get_area_name(site)] ([site.x]/[site.y])"
		data["lockedSiteClear"] = validate_site(site) == TRANSPORTER_SITE_CLEAR
	else
		data["lockedSite"] = null
		data["lockedSiteClear"] = FALSE

	var/list/transponders = list()
	for(var/obj/item/transporter_transponder/transponder as anything in get_reachable_transponders())
		var/turf/where = get_turf(transponder)
		var/atom/holder = transponder.loc
		var/carrier = ismob(holder) ? holder.name : null
		if(!carrier && istype(holder, /obj/item/storage))
			var/atom/outer = holder.loc
			carrier = ismob(outer) ? outer.name : null
		var/site_status = validate_site(where)
		transponders += list(list(
			"ref" = REF(transponder),
			"name" = transponder.name,
			"carrier" = carrier,
			"area" = get_area_name(where),
			"status" = site_status_text(site_status),
			"ready" = site_status == TRANSPORTER_SITE_CLEAR,
		))
	data["transponders"] = transponders

	return data

/obj/machinery/computer/transporter/ui_act(action, list/params, datum/tgui/ui)
	. = ..()
	if(.)
		return

	var/mob/user = ui.user
	var/failure

	switch(action)
		if("beamDown")
			failure = beam_down(user, use_lock = TRUE)
		if("beamDownRandom")
			failure = beam_down(user, use_lock = FALSE)
		if("beamUpSite")
			failure = beam_up_site(user)
		if("beamUpTransponder")
			if(!linked_pad)
				failure = "no transporter pad linked"
			else
				var/obj/item/transporter_transponder/transponder = locate(params["ref"]) in linked_pad.paired_transponders
				failure = beam_up_transponder(transponder, user)
		if("openScanner")
			ui.close()
			start_targeting(user)
			return TRUE
		if("clearLock")
			clear_lock()
			playsound(src, 'sound/machines/terminal/terminal_prompt_deny.ogg', 30)
			return TRUE
		else
			return TRUE

	if(failure)
		balloon_alert(user, failure)
		playsound(src, 'sound/machines/terminal/terminal_error.ogg', 40)
	return TRUE

/**
 * Circuit board.
 */
/obj/item/circuitboard/computer/transporter
	name = "Transporter Control Console"
	greyscale_colors = CIRCUIT_COLOR_SCIENCE
	build_path = /obj/machinery/computer/transporter
	// Mirrors /datum/design/board/transporter_console, the way upstream boards mirror theirs
	// (see /obj/item/circuitboard/computer/robotics). Without this the board keeps the generic
	// half sheet of glass every circuitboard starts with.
	custom_materials = list(
		/datum/material/glass = SHEET_MATERIAL_AMOUNT,
		/datum/material/gold = HALF_SHEET_MATERIAL_AMOUNT,
		/datum/material/bluespace = SHEET_MATERIAL_AMOUNT,
	)
