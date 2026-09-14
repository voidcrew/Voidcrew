/// Includes hidden contacts and ships nested inside other contacts.
GLOBAL_LIST_EMPTY(overmap_objects)

/obj/structure/overmap
	name = "overmap object"
	desc = "An unknown celestial object."
	icon = 'voidcrew/modules/overmap/icons/effects/overmap.dmi'
	icon_state = "object"
	// Disable emissive blockers - they cause visual artifacts (duplication, color inversion)
	// when viewed through popup map views like the helm console
	blocks_emissive = EMISSIVE_BLOCK_NONE

	/// Check that someone already act with this.
	var/concerned = FALSE
	/// Current integrity (turf count for ships). Updated via event-driven delta tracking.
	var/integrity = 100

	///List of other overmap objects in the same tile
	var/list/close_overmap_objects
	var/surveyed = FALSE
	/// Research points (and credits) an orbital survey of this object banks, before the
	/// first-survey bonus and console tier multipliers (see survey_computer.dm
	/// get_survey_value). Set it on the family's base type and every subtype inherits it,
	/// so storm severities, planet terrains and star classes are all worth what their
	/// family is worth. 0 is "nothing to learn here" - the default for everything that
	/// isn't a celestial body: other ships, outposts, the colosseum.
	var/survey_value = 0
	/// Display name used by nav/combat UIs; defaults to name on Initialize. Ships keep theirs synced on rename.
	var/display_name
	/// world.time gate on the "no charting capacity" crew notification, so the 30-second
	/// capacity retries do not each replay the warning klaxon. 0 = the next refusal is a
	/// fresh hold and warns loudly; see site_load_refused_for_capacity().
	var/capacity_notice_next = 0

	// Hangar berth / elevator host state (see voidcrew/modules/trade/outpost_hangar.dm).
	// Trader outposts always host berths; player outposts do once a hangar elevator
	// is placed via the construction console.
	/// Bottom-left turf of this object's loaded interior template footprint, if any
	var/turf/template_bottom_left
	/// Hangar berth slots; berths[i] is the /datum/outpost_berth in slot i or null.
	/// Stays null until this object first hosts berths.
	var/list/berths
	/// Elevator alcove turfs on the concourse/lobby floor, in block() order
	var/list/turf/lobby_alcove_turfs = list()
	/// Backing-wall turfs behind the current elevator panel, reverted to plating if the elevator moves
	var/list/turf/lobby_wall_turfs = list()
	/// Concourse-side elevator panels
	var/list/obj/machinery/outpost_elevator/lobby_panels = list()

// voidcrew TODO: add the rest of overmap shit later

/obj/structure/overmap/proc/ship_act(mob/user, obj/structure/overmap/ship/acting)
	to_chat(user, "<span class='notice'>You don't think there's anything you can do here.</span>")

/**
 * What the helm's Dock button means when this object shares the ship's tile,
 * a short noun phrase ("Trader Halcyon", "derelict signal"), or null if a ship
 * can't dock with this at all.
 *
 * Null is the default and covers everything a ship flies past rather than lands
 * on: storms, and nebulas (whose ship_act conceals rather than docks, that's the
 * Cloak control's job). Other vessels are excluded by the helm itself, since
 * ship-to-ship docking is a consensual flow with its own request/accept handshake.
 *
 * Overriding this is what puts an object on the Dock button. If you give a new
 * overmap type a docking ship_act(), give it one of these too or the helm will
 * offer to dock into empty space right on top of it.
 */
/obj/structure/overmap/proc/get_dock_description()
	return null

/**
 * What crew-facing survey broadcasts call this object. Falls back through
 * display_name to name for objects that deliberately are not Dock-button targets:
 * the dock-in-empty-space placeholder returns null from get_dock_description() by
 * design, and a null would otherwise interpolate as a blank into every
 * request_site_load() message ("Survey request logged for .").
 */
/obj/structure/overmap/proc/get_site_label()
	return get_dock_description() || display_name || name

/**
 * Kicks off generation of this object's interior in the background, if it has one.
 *
 * Overridden by planets, space ruins and meteor fields to INVOKE_ASYNC their own
 * load_level() (whose signatures differ per type). The caller - a ship's
 * request_site_load() - has already registered for COMSIG_VOIDCREW_SITE_LOAD_FINISHED,
 * which every load path sends on success and failure, so this never needs to return
 * a status. Base: the object has no loadable interior, nothing happens.
 *
 * * user - The mob that asked, if any. Told where it stands if the worldgen queue is busy.
 * * waiting_ship - The ship holding a docking approach on this object; routed to
 *   worldgen_claim()'s notify_ship so queue progress reaches the whole crew.
 */
/obj/structure/overmap/proc/start_level_load(mob/user, obj/structure/overmap/ship/waiting_ship)
	return

/// Whether this object's interior is currently being generated. Base: it never is.
/obj/structure/overmap/proc/is_loading()
	return FALSE

/// Whether this object's interior is generated and dockable. Base: it never is.
/obj/structure/overmap/proc/is_loaded()
	return FALSE

/**
 * The map-zone slot this object's loaded interior occupies, or null when it has none.
 *
 * The single answer to "which turfs are this site's" for every caller that used to
 * open-code an istype chain over planet.footprint / ruin.reservation / field.reservation.
 * A z-level is shared by up to four tenants, so the rectangle - not the z - is the
 * boundary; see /datum/map_footprint.
 *
 * Null means "this site is not scoped to a rectangle", and callers must read it the way
 * they always did: as the whole level. Trader outposts (still on turf reservations) and
 * unloaded sites both answer null.
 */
/obj/structure/overmap/proc/get_interior_footprint()
	return null

/// Whether a visitor is inside this site or one of its elevator-connected hangars.
/// Reservations can share z-levels, so each part must use its own bounds.
/obj/structure/overmap/proc/contains_site_turf(turf/location)
	if(!location)
		return FALSE
	if(get_interior_footprint()?.contains_turf(location))
		return TRUE
	for(var/datum/outpost_berth/berth as anything in berths)
		if(berth?.reservation?.contains_turf(location))
			return TRUE
	return FALSE

/**
 * Standard response to a site load that was refused for want of MAP VOLUME rather than
 * for anything the crew did.
 *
 * BYOND never frees a z-level, so world.maxz carries a configured ceiling
 * (/datum/config_entry/number/max_z_levels) and the allocator answers "not right now" once
 * it is reached. That is a wait, not a failure: slots free up constantly as sites recycle,
 * so the site says so, arms its own retry and gets on with it.
 *
 * The retry is armed AFTER the worldgen queue has been released by the caller, and is a
 * plain timer rather than a queue entry - a routine dock may never end up waiting behind
 * somebody else's minute-long survey (the design rule in worldgen_queue.dm).
 */
/obj/structure/overmap/proc/site_load_refused_for_capacity(obj/structure/overmap/ship/waiting_ship)
	// The first refusal of a hold warns loudly, with the sound. The 30-second retries
	// after it stay quiet, with a soft reminder every few minutes so a long hold is
	// still distinguishable from a hang. Without the gate every retry replayed the
	// warning klaxon - a crew camped on a busy chart was pinged twenty times in ten
	// minutes for a condition the first message already told them to sit out.
	// retry_capacity_wait() zeroes the gate when the hold ends, so the NEXT hold's
	// first refusal is loud again.
	if(!QDELETED(waiting_ship) && world.time >= capacity_notice_next)
		if(capacity_notice_next)
			waiting_ship.ship_notify("Still waiting on charting capacity for [display_name || name]. The attempt keeps repeating on its own - nothing to do at the helm.", "SURVEY", SHIP_NOTIFY_NOTICE)
		else
			waiting_ship.ship_notify("Charting [display_name || name] is held up: every mapping volume in the sector is committed right now. \
				The attempt repeats on its own shortly - nothing to do at the helm.", "SURVEY", SHIP_NOTIFY_WARNING, 'voidcrew/sound/warn.ogg', 25)
		capacity_notice_next = world.time + SITE_CAPACITY_RENOTIFY_INTERVAL
	log_mapping("SSovermap: '[display_name || name]' load refused for want of map volume - re-arming a retry")
	addtimer(CALLBACK(src, PROC_REF(retry_capacity_wait)), SITE_CAPACITY_RETRY_DELAY, TIMER_UNIQUE)

/**
 * The capacity retry itself.
 *
 * Only fires while a ship is still sitting on this contact's overmap tile. An unattended
 * retry would build an interior nobody asked for and pin the very slot it was waiting on;
 * a crew that flew off simply presses Dock again, which starts a fresh attempt. No hard
 * ref to the original ship is kept for the same reason - a timer holding one for thirty
 * seconds is a hard-delete blocker on a hull that may be being scrapped.
 */
/obj/structure/overmap/proc/retry_capacity_wait()
	// Either exit means the hold is over - the interior came up, or the crew flew off.
	// Zero the notification gate so the next hold's first refusal warns loudly again
	// instead of arriving as a mid-hold reminder.
	if(QDELETED(src) || is_loading() || is_loaded())
		capacity_notice_next = 0
		return
	var/obj/structure/overmap/ship/still_waiting = locate() in loc
	if(!still_waiting)
		capacity_notice_next = 0
		return
	start_level_load(null, still_waiting)

/**
 * Whether a ship parked at this object is standing in gravity that comes from the
 * location rather than from its own deck plating, a planet surface, an outpost deck.
 *
 * Ship gravity is `default_gravity` on the shuttle areas, so anything that switches
 * the ship's plating off is only meaningful where the ship is the sole source of
 * gravity. FALSE is the right default: space, ruins, wrecks and other ships all
 * leave a docked crew weightless the moment their own plating quits.
 */
/obj/structure/overmap/proc/has_ambient_gravity()
	return FALSE

// Empty planets inherit ship_act from parent planet class to enable proper docking

/obj/structure/overmap/Initialize(mapload)
	. = ..()
	GLOB.overmap_objects += src
	if(isnull(display_name))
		display_name = name
	var/static/list/loc_connections = list(
		COMSIG_ATOM_ENTERED = PROC_REF(on_entered),
		COMSIG_ATOM_EXITED = PROC_REF(on_exited),
	)
	AddElement(/datum/element/connect_loc, loc_connections)

/obj/structure/overmap/Destroy()
	GLOB.overmap_objects -= src
	for(var/obj/structure/overmap/other as anything in close_overmap_objects)
		LAZYREMOVE(other.close_overmap_objects, src)
	close_overmap_objects = null
	return ..()

// ===== COMBAT TARGET API =====
// Ship weapons historically targeted only ships; these hooks let other overmap
// objects (raidable player outposts) opt in. See voidcrew/modules/ship_combat.

/// Notification hook used by combat/docking systems. Ships notify their crew,
/// player outposts their occupants and owner. No-op by default.
/obj/structure/overmap/proc/ship_notify(message, category = "ALERT", alert_level = SHIP_NOTIFY_NOTICE, sound_file = null, volume = 100)
	return

/// Whether ship weapons may acquire a lock on this object
/obj/structure/overmap/proc/is_combat_targetable()
	return FALSE

/// Areas that scope combat sounds/shakes/camera static to the target.
/// Null means "don't filter", correct for targets that own their whole z-level.
/obj/structure/overmap/proc/get_combat_target_areas()
	return null

/// Interior rect for missile approach calculations: list(min_x, min_y, max_x, max_y), or null
/obj/structure/overmap/proc/get_combat_bounds()
	return null

/// Whether the combat camera eye may sit on the given turf of this target
/obj/structure/overmap/proc/combat_camera_can_view(turf/T)
	return FALSE

/// Turfs the combat camera generates interior static over; null = none
/obj/structure/overmap/proc/get_combat_camera_turfs()
	return null

/// A safe default aim turf on this target (fallback when no reticle position exists)
/obj/structure/overmap/proc/get_combat_default_turf()
	return null

// ===== BERTH HOST API =====
// Elevator panels and berth machinery back-reference their host loosely, so any
// overmap object that fills in the berth-host vars can serve hangar floors.
// The berth lifecycle procs themselves live in voidcrew/modules/trade/outpost_hangar.dm.

/// Called when someone attacks host-owned service machinery (elevator panels,
/// outpost doors). Trader outposts escalate to embargo/turrets; no-op by default.
/obj/structure/overmap/proc/register_aggression(mob/living/offender)
	return
/**
  * When something crosses another overmap object, add it to the nearby objects list, which are used by events and docking
  */
/obj/structure/overmap/proc/on_entered(datum/source, atom/movable/AM)
	SIGNAL_HANDLER
	if(istype(loc, /turf/) && istype(AM, /obj/structure/overmap))
		var/obj/structure/overmap/other = AM
		if(other == src)
			return
		LAZYOR(other.close_overmap_objects, src)
		LAZYOR(close_overmap_objects, other)

/**
  * See [/obj/structure/overmap/Crossed]
  */
/obj/structure/overmap/proc/on_exited(datum/source, atom/movable/AM)
	if(istype(loc, /turf/) && istype(AM, /obj/structure/overmap))
		var/obj/structure/overmap/other = AM
		if(other == src)
			return
		LAZYREMOVE(other.close_overmap_objects, src)
		LAZYREMOVE(close_overmap_objects, other)

/**
  * Mutually syncs the close-objects lists with every overmap object already sharing
  * this object's turf. on_entered only fires on movement, so an object spawned onto
  * an occupied tile (e.g. a freshly founded outpost under a still ship) is invisible
  * to docking and sensors until something re-crosses. Call this to register it now.
  */
/obj/structure/overmap/proc/sync_close_overmap_objects()
	var/turf/our_turf = loc
	if(!istype(our_turf))
		return
	for(var/obj/structure/overmap/other in our_turf)
		if(other == src)
			continue
		LAZYOR(close_overmap_objects, other)
		LAZYOR(other.close_overmap_objects, src)

// ===================== CONTEXT-AWARE OVERMAP PARALLAX =====================
//
// What a crew sees out the windows follows what their ship is flying over: sitting on
// (or docked to / landed inside) an asteroid field shows drifting asteroids, a gas
// nebula shows tinted space gas, an ice planet hangs an icemoon backdrop in the sky,
// a lava planet a scorched planet backdrop, and plain space stays plain stars.
//
// HOW THE MAPPING WORKS
// Every /obj/structure/overmap has a `parallax_theme` var (a PARALLAX_THEME_* define,
// see voidcrew/_DEFINES/overmap.dm). Null means "plain space". The theme is turned
// into concrete layer typepaths by get_overmap_parallax_layer_types() below. Planets
// carry their theme on the /datum/overmap/planet info datum (behaviour/planets.dm)
// and copy it onto the overmap object at Initialize, so theming another planet type
// is one line on its datum; any other overmap object type is one line on the type
// itself (see events.dm for the meteor/nebula lines).
//
// HOW IT REACHES THE CLIENT
// Context layers are per-client instances kept in client.overmap_parallax_layers,
// appended after the pref-capped base layers (see the VOIDCREW EDITs in
// code/_onclick/hud/parallax/parallax.dm create_parallax()). They are (re)resolved by
// /datum/hud/proc/update_overmap_parallax below, triggered from:
// - update_parallax()'s z-change branch (boarding/leaving encounters, ghosting,
//   login, teleports) - VOIDCREW EDIT in parallax.dm
// - /obj/structure/overmap/ship/proc/update_crew_parallax_context (ship.dm), poked
//   from the ship token's Moved() (overmap tile crossings, dock/undock completion)

/obj/structure/overmap
	/// Parallax theme (PARALLAX_THEME_* define) crews see while their ship sits on
	/// this object's overmap tile or inside its loaded interior. Null = plain space.
	var/parallax_theme

/// Layer typepaths composing a theme. All types reuse stock icons/effects/parallax.dmi states.
/proc/get_overmap_parallax_layer_types(theme)
	switch(theme)
		if(PARALLAX_THEME_ASTEROIDS)
			return list(/atom/movable/screen/parallax_layer/random/asteroids)
		if(PARALLAX_THEME_SPACE_GAS)
			return list(/atom/movable/screen/parallax_layer/random/space_gas)
		if(PARALLAX_THEME_ICEMOON)
			return list(/atom/movable/screen/parallax_layer/overmap_backdrop/icemoon)
		if(PARALLAX_THEME_PLANET)
			return list(/atom/movable/screen/parallax_layer/overmap_backdrop/planet)
	return null

/// Post-creation hook to customize a freshly built context layer instance
/// (e.g. nebulas tint their gas layer, see events.dm). No-op by default.
/obj/structure/overmap/proc/configure_parallax_layer(atom/movable/screen/parallax_layer/layer)
	return

/**
 * A single, untiled celestial backdrop (planet/moon sprite) hanging in the parallax.
 * Unlike the star layers this is NOT tiled by update_o(), so it must never join the
 * in-transit 480px scroll loop - hence scroll_loops = FALSE (see the VOIDCREW EDITs
 * in code/_onclick/hud/parallax/parallax.dm set_parallax_movedir()).
 */
/atom/movable/screen/parallax_layer/overmap_backdrop
	blend_mode = BLEND_OVERLAY
	speed = 0.4
	layer = 30
	scroll_loops = FALSE

/atom/movable/screen/parallax_layer/overmap_backdrop/update_o(view)
	return // single centered sprite, no tiling

/atom/movable/screen/parallax_layer/overmap_backdrop/icemoon
	icon_state = "icemoon"

/atom/movable/screen/parallax_layer/overmap_backdrop/planet
	icon_state = "planet"

/**
 * Finds the voidcrew player ship whose interior contains the given turf.
 * Exact-z shuttle bounds first (the cheap common case), then the stacked
 * z-levels of multi-z ships, which get_containing_shuttle() can't see.
 */
/proc/get_voidcrew_ship_for_turf(turf/checked_turf)
	if(!checked_turf)
		return null
	var/obj/docking_port/mobile/voidcrew/port = SSshuttle.get_containing_shuttle(checked_turf)
	if(istype(port) && port.current_ship)
		return port.current_ship
	for(var/obj/structure/overmap/ship/ship as anything in SSovermap.simulated_ships)
		var/obj/docking_port/mobile/voidcrew/ship_port = ship.shuttle
		if(!istype(ship_port) || ship_port.z == checked_turf.z) // exact z handled above
			continue
		if(checked_turf.z < ship_port.z - ship_port.z_levels_below || checked_turf.z > ship_port.z + ship_port.z_levels_above)
			continue
		var/list/bounds = ship_port.return_coords()
		if(checked_turf.x >= min(bounds[1], bounds[3]) && checked_turf.x <= max(bounds[1], bounds[3]) \
			&& checked_turf.y >= min(bounds[2], bounds[4]) && checked_turf.y <= max(bounds[2], bounds[4]))
			return ship
	return null

/**
 * The overmap object that should theme parallax for a viewer standing on `viewed_turf`,
 * or null for plain space. Aboard a ship, the ship's overmap situation decides;
 * off-ship, the overmap object owning the loaded interior around the turf does.
 */
/proc/get_overmap_parallax_source(turf/viewed_turf)
	if(!viewed_turf)
		return null
	var/obj/structure/overmap/ship/ship = get_voidcrew_ship_for_turf(viewed_turf)
	if(ship)
		return ship.get_parallax_source()
	var/obj/structure/overmap/holder = SSovermap_zones.get_overmap_object_for_turf(viewed_turf)
	if(holder?.parallax_theme)
		return holder
	return null

/client
	/// Overmap-context parallax layer instances currently applied to this client.
	/// Kept out of parallax_layers_cached so the pref-based layer cap never eats them.
	var/list/overmap_parallax_layers
	/// Cache key ("theme-ref") of the applied overmap parallax context; null = plain space
	var/overmap_parallax_key

/**
 * Resolves the viewer's overmap context and swaps the client's context layers if it
 * changed. Safe to call often - it early-outs on an unchanged context key.
 */
/datum/hud/proc/update_overmap_parallax(mob/viewmob)
	var/mob/screenmob = viewmob || mymob
	var/client/C = screenmob?.client
	if(!C)
		return
	var/turf/posobj = get_turf(C.eye)
	var/obj/structure/overmap/source = get_overmap_parallax_source(posobj)
	var/new_key = source ? "[source.parallax_theme]-[REF(source)]" : null
	if(new_key == C.overmap_parallax_key)
		return
	C.overmap_parallax_key = new_key

	// Tear down the previous context's layers
	if(length(C.overmap_parallax_layers))
		for(var/atom/movable/screen/parallax_layer/old_layer as anything in C.overmap_parallax_layers)
			if(C.parallax_layers)
				C.parallax_layers -= old_layer
			if(C.parallax_rock)
				C.parallax_rock.vis_contents -= old_layer
			qdel(old_layer)
	C.overmap_parallax_layers = null

	if(!source)
		return
	var/list/layer_types = get_overmap_parallax_layer_types(source.parallax_theme)
	if(!length(layer_types))
		return
	if(isnull(C.parallax_rock) || isnull(C.parallax_layers))
		return // parallax not built for this client (pref-disabled, NOPARALLAX z); nothing to attach to

	C.overmap_parallax_layers = list()
	for(var/layer_type in layer_types)
		var/atom/movable/screen/parallax_layer/layer = new layer_type(null, src)
		if(QDELETED(layer)) // no canon client - see parallax_layer/Initialize
			continue
		source.configure_parallax_layer(layer)
		C.overmap_parallax_layers += layer
		C.parallax_layers += layer
		C.parallax_rock.vis_contents += layer

	// If an in-transit scroll is already running, fold the new tiled layers into the
	// same loop set_parallax_movedir()/update_parallax_motionblur() would have set up
	if(C.parallax_movedir)
		var/matrix/scroll_transform
		switch(C.parallax_movedir)
			if(NORTH)
				scroll_transform = matrix(1, 0, 0, 0, 1, 480)
			if(SOUTH)
				scroll_transform = matrix(1, 0, 0, 0, 1, -480)
			if(EAST)
				scroll_transform = matrix(1, 0, 480, 0, 1, 0)
			if(WEST)
				scroll_transform = matrix(1, 0, -480, 0, 1, 0)
		if(scroll_transform)
			for(var/atom/movable/screen/parallax_layer/layer as anything in C.overmap_parallax_layers)
				if(layer.scroll_loops)
					update_parallax_motionblur(C, layer, C.parallax_movedir, scroll_transform)
/obj/structure/overmap/proc/get_docking_ships()
	var/list/ships = list()
	// Include contents as well as the simulation registry during docking transitions.
	for(var/obj/structure/overmap/ship/ship as anything in (SSovermap.simulated_ships | contents))
		if(!istype(ship) || QDELETED(ship) || ship == src)
			continue
		if(ship.docked == src || ship.loc == src || ship.pending_dock_target == src)
			ships += ship
	return ships

/// Shared by teardown guards and the admin view, so the explanation matches the gate.
/obj/structure/overmap/proc/get_docking_blocker()
	for(var/obj/structure/overmap/ship/ship as anything in get_docking_ships())
		if(ship.admin_operation == "delete")
			return "[ship.name] is being deleted. Wait for removal to finish."
		switch(ship.presence_at(src))
			if("Departing")
				return "[ship.name] is departing. Wait for it to leave."
			if("Arriving")
				return "[ship.name] is arriving. Wait for docking to finish, then move or delete the ship."
		return "[ship.name] is docked here. Move or delete the ship first."
	return null

/obj/structure/overmap/ship/proc/presence_at(obj/structure/overmap/site)
	if(state == OVERMAP_SHIP_UNDOCKING)
		return "Departing"
	if(state == OVERMAP_SHIP_DOCKING || (pending_dock_target == site && docked != site && loc != site))
		return "Arriving"
	return "Docked"
