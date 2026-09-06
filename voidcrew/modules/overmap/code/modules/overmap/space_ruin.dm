/**
 * Space Ruin Overmap Object
 *
 * Represents a space ruin that appears as a mysterious signal on the overmap.
 * When surveyed, reveals its true nature (derelict, station, syndicate, etc.).
 * Ships can dock and explore the ruin. Asteroid mining lives elsewhere now -
 * see /obj/structure/overmap/event/meteor in events.dm for landable asteroid fields.
 */

/// All space ruin signals currently on the overmap (used by recovery missions to pick targets)
GLOBAL_LIST_EMPTY(space_ruin_signals)

/obj/structure/overmap/space_ruin
	name = "unknown signal"
	desc = "A faint signal of unknown origin. Survey to learn more."
	icon_state = "strange_event"
	sensor_detectable = TRUE
	sensor_category = "Ruins"
	survey_value = 300

	/// The ruin template this object will spawn
	var/datum/map_template/ruin/space/ruin_template
	/// The map zone backing this ruin's interior, once loaded
	var/datum/map_zone/mapzone
	/// This ruin's rectangle inside that zone's level - the slot it was dealt. Every
	/// "is this turf mine?" question is answered from here rather than from the z-level,
	/// which a packed level shares with up to three neighbours. See /datum/map_footprint.
	var/datum/map_footprint/footprint
	/// Primary docking port
	var/obj/docking_port/stationary/reserve_dock
	/// Secondary docking port
	var/obj/docking_port/stationary/reserve_dock_secondary
	/// Whether the ruin has been loaded
	var/loaded = FALSE
	/// Whether the ruin is currently loading
	var/loading = FALSE
	/// Whether this ruin has been visited
	var/visited = FALSE
	/// Track dock usage
	var/first_dock_taken = FALSE
	var/second_dock_taken = FALSE
	/// Which docking port the ship is occupying
	var/dock_index
	/// The true name of the ruin (revealed on survey)
	var/true_name
	/// The true description of the ruin (revealed on survey)
	var/true_desc
	/// Category for grouping (derelict, station, syndicate, misc). "asteroid" retired -
	/// asteroid-flavored templates (asteroid1-6 etc.) now fall through to "unknown";
	/// dedicated mining sites are landable meteor storm events (see events.dm) instead.
	var/ruin_category = "unknown"
	/// Bottom-left turf of the loaded ruin template footprint (set by load_level, cleared on unload)
	var/turf/ruin_bottom_left
	/// Rare ruins come from rumor charts, not natural seeding: tinted gold on
	/// the map, and cleaning one out never spawns a replacement.
	var/rare = FALSE
	/// Live missions currently pointed at this ruin; target picks prefer unclaimed ruins
	var/mission_claims = 0
	/// A mission owns this ruin's lifecycle: the empty-ruin cleanup in
	/// check_and_respawn() is suppressed until the mission releases it
	var/mission_locked = FALSE
	/// One contract has taken this ruin for its own and no other contract may aim
	/// here while it holds. Used by the jobs whose objective is a living thing that
	/// somebody else's spawns would kill (see /datum/mission/var/exclusive_site).
	var/mission_exclusive = FALSE

/obj/structure/overmap/space_ruin/Initialize(mapload, datum/map_template/ruin/space/template)
	. = ..()
	GLOB.space_ruin_signals += src
	if(template)
		set_ruin_template(template)

/obj/structure/overmap/space_ruin/Destroy()
	GLOB.space_ruin_signals -= src
	ruin_bottom_left = null
	// The orderly teardowns (release_interior -> remove_mapzone) leave both of these null.
	// What lands here with either still set is a ruin deleted OUT of that path - an admin
	// Del, a runtime mid-build, a subtype qdel'ing itself - and with four slots to a level
	// a leaked one is a quarter of a z-level nobody can ever be dealt again. The ground is
	// deliberately NOT swept: Destroy() can be reentrant and can run mid-build, and the
	// sweeps yield, so the next tenant's own fill repaints it instead.
	if(footprint || mapzone)
		var/datum/map_footprint/departing_footprint = footprint
		var/datum/map_zone/departing_zone = mapzone || departing_footprint?.zone
		log_mapping("SSovermap: space ruin '[name]' was deleted while still holding [departing_footprint ? departing_footprint.describe() : "a map zone with no footprint"] - releasing the slot without a teardown sweep")
		footprint = null
		mapzone = null
		departing_zone?.release_slot(departing_footprint)
	return ..()

/obj/structure/overmap/space_ruin/get_interior_footprint()
	return footprint

/**
 * Sets the ruin template and extracts relevant info
 */
/obj/structure/overmap/space_ruin/proc/set_ruin_template(datum/map_template/ruin/space/template)
	ruin_template = template
	true_name = template.name
	true_desc = template.description

	// Categorize based on the ruin's id/name
	categorize_ruin()

	// Set appropriate icon based on category
	update_icon_for_category()

/**
 * Categorizes the ruin based on its id or name
 */
/obj/structure/overmap/space_ruin/proc/categorize_ruin()
	if(!ruin_template)
		return
	ruin_category = space_ruin_template_category(ruin_template)

/**
 * Returns the overmap category ("derelict", "station", ...) a space ruin template falls into,
 * based on keywords in its id/name. Shared by the overmap signal object and by
 * setup_space_ruins(). No longer matches "asteroid" - those templates (asteroid1-6 etc.)
 * fall through to "unknown" like any other generic ruin; dedicated asteroid mining moved to
 * landable meteor storm field events (see events.dm) so ruin signals no longer double as it.
 */
/proc/space_ruin_template_category(datum/map_template/ruin/space/template)
	var/ruin_id = template.id
	var/ruin_name = lowertext(template.name)

	// Check for category keywords
	if(findtext(ruin_id, "derelict") || findtext(ruin_name, "derelict"))
		return "derelict"
	else if(findtext(ruin_id, "syndicate") || findtext(ruin_name, "syndicate") || findtext(ruin_id, "listening") || findtext(ruin_id, "infiltrator"))
		return "syndicate"
	else if(findtext(ruin_name, "station") || findtext(ruin_name, "outpost") || findtext(ruin_name, "hotel") || findtext(ruin_name, "waystation"))
		return "station"
	else if(findtext(ruin_name, "ship") || findtext(ruin_name, "shuttle") || findtext(ruin_name, "frigate") || findtext(ruin_name, "transport"))
		return "ship"
	else if(findtext(ruin_name, "research") || findtext(ruin_name, "lab") || findtext(ruin_name, "facility"))
		return "research"
	return "unknown"

/**
 * Flags this signal as a rumor-chart rare ruin: gold on every map view, and
 * exempt from the replacement-respawn cycle. Call after set_ruin_template.
 */
/obj/structure/overmap/space_ruin/proc/mark_rare()
	rare = TRUE
	name = "encrypted signal"
	desc = "A signal buried under heavy encryption. Whoever hid this didn't want casual traffic finding it."
	color = "#ffc94d"

/**
 * What the chart draws this signal as. An unsurveyed ruin is a signal and nothing
 * more, so it deliberately gives up nothing but the encryption, which is already
 * public, being the whole point of a rumour chart.
 */
/obj/structure/overmap/space_ruin/get_contact_variant()
	if(!surveyed)
		return rare ? "encrypted" : null
	return ruin_category

/**
 * Updates the icon based on category and survey status
 */
/obj/structure/overmap/space_ruin/proc/update_icon_for_category()
	if(!surveyed)
		// Unsurveyed - show as mysterious signal
		icon_state = "strange_event"
		return

	// Surveyed - show category-appropriate icon
	switch(ruin_category)
		if("derelict", "ship")
			icon_state = "object"
		if("station", "research")
			icon_state = "object"
		if("syndicate")
			icon_state = "strange_event"
		else
			icon_state = "object"

/obj/structure/overmap/space_ruin/examine(mob/user)
	. = ..()
	if(surveyed)
		. += span_notice("Survey data indicates this is: [true_name]")
		if(true_desc)
			. += span_notice("[true_desc]")
		if(visited)
			. += span_notice("This location has been explored.")
	else
		. += span_warning("Survey this signal to learn more about it.")
	if(rare)
		. += span_boldnotice("The encryption on this signal is the kind used to hide something valuable.")

/**
 * Called when the ruin is surveyed - reveals true nature
 */
/obj/structure/overmap/space_ruin/proc/on_surveyed()
	if(surveyed)
		return
	surveyed = TRUE
	name = true_name || "surveyed signal"
	desc = true_desc || "A surveyed space anomaly."
	update_icon_for_category()

/**
 * Loads the ruin's interior into a map-zone slot, under the worldgen queue.
 *
 * * user - The mob that asked, if any. Told where it stands if the worldgen queue is busy.
 * * waiting_ship - The ship holding a docking approach on this ruin; routed to
 *   worldgen_claim()'s notify_ship so queue progress reaches the whole crew.
 * * queue_timeout - How long to wait for the worldgen queue. Null takes the default;
 *   UI callers that cannot hold an interface open pass WORLDGEN_QUEUE_NO_WAIT.
 *
 * Sends COMSIG_VOIDCREW_SITE_LOAD_FINISHED (TRUE/FALSE) on every exit except the
 * in-flight guard (that load owns the signal) - a ship may already be registered for
 * it by request_site_load() when this is entered, and a silent exit latches that ship
 * out of this site for the rest of the round.
 */
/obj/structure/overmap/space_ruin/proc/load_level(mob/user, obj/structure/overmap/ship/waiting_ship, queue_timeout)
	if(mapzone)
		SEND_SIGNAL(src, COMSIG_VOIDCREW_SITE_LOAD_FINISHED, is_loaded())
		return
	if(loading)
		return // the in-flight load sends the completion signal
	if(!ruin_template)
		SEND_SIGNAL(src, COMSIG_VOIDCREW_SITE_LOAD_FINISHED, FALSE)
		return

	loading = TRUE

	var/datum/worldgen_probe/probe = worldgen_begin("ruin", "[name] ([ruin_template.name])")

	// Check if ruin template has valid dimensions
	if(!ruin_template.width || !ruin_template.height)
		// Template dimensions not loaded yet - need to preload
		var/template_path = ruin_template.mappath
		if(!template_path && ruin_template.prefix && ruin_template.suffix)
			template_path = ruin_template.prefix + ruin_template.suffix
		if(template_path)
			ruin_template.preload_size(template_path, TRUE)
		else
			loading = FALSE
			worldgen_end(probe, "preload-failed")
			SEND_SIGNAL(src, COMSIG_VOIDCREW_SITE_LOAD_FINISHED, FALSE)
			return

	// A template that fits a lattice slot's build region packs FOUR to a z-level; one
	// that does not takes a whole level to itself, which is exactly what every ruin used
	// to cost. Measured 2026-08-20 over the live template list: 112 of 113 pack, the sole
	// outlier being russian_derelict at 83x111. See ruin_fits_in_slot().
	//
	// This replaces the old reservation-size gate. A ruin used to ask for
	// template + 118 x template + 86 - two maximum-size berths' worth of padding on BOTH
	// sides of BOTH axes - against a 222x222 reservation ceiling, which is why the
	// smallest map in the pool still could not share a z-level with anything.
	var/tenant_class = SSovermap.ruin_fits_in_slot(ruin_template) ? MAP_TENANT_CLASS_FLAT : MAP_TENANT_CLASS_SOLO
	if(!SSovermap.ruin_fits_in_level(ruin_template))
		// Too big even for a whole z-level. Bail before allocating one: passing an
		// unplaceable template through leaves a slot claimed and a ruinless site, and
		// through the caller's loading flag bricks the tile for the round.
		log_mapping("SPACE RUIN: '[ruin_template.name]' is [ruin_template.width]x[ruin_template.height] - larger than a whole z-level's build region. Ruin is unboardable.")
		loading = FALSE
		worldgen_end(probe, "too-large")
		SEND_SIGNAL(src, COMSIG_VOIDCREW_SITE_LOAD_FINISHED, FALSE)
		return

	// Heavy work from here on - take the worldgen queue like every other survey.
	if(!SSovermap.worldgen_claim(src, "ruin survey ([name])", user, queue_timeout, waiting_ship))
		loading = FALSE
		worldgen_end(probe, "queue-timeout")
		SEND_SIGNAL(src, COMSIG_VOIDCREW_SITE_LOAD_FINISHED, FALSE)
		return

	// The world moved while we queued: another caller may have loaded us already.
	if(mapzone)
		SSovermap.worldgen_release(src)
		loading = FALSE
		worldgen_end(probe, "already-loaded")
		SEND_SIGNAL(src, COMSIG_VOIDCREW_SITE_LOAD_FINISHED, TRUE)
		return

	// The whole build - slot claim, cordon, template stamp (wrapped in the per-load ruin
	// area instancing window), space init and both berths - happens in here. throttled =
	// TRUE because we already hold the worldgen queue and the build shares that budget.
	//
	// Deliberately NO try/catch around the template load, here or inside: try/catch around
	// template.load() swallows a partial stamp and leaves a dead map behind.
	var/list/encounter_values = SSovermap.spawn_dynamic_encounter(null, TRUE, ruin_type = ruin_template, throttled = TRUE, tenant_class = tenant_class, tenant_owner = src)
	if(length(encounter_values) < 4 || !encounter_values[1] || !encounter_values[2] || !encounter_values[4])
		// Queue released FIRST, then the retry armed: the wait is for a free SLOT, not for
		// the worldgen queue, and a ruin must never end up queued behind a planet build.
		SSovermap.worldgen_release(src)
		loading = FALSE
		worldgen_end(probe, "slot-failed")
		site_load_refused_for_capacity(waiting_ship)
		SEND_SIGNAL(src, COMSIG_VOIDCREW_SITE_LOAD_FINISHED, FALSE)
		return

	mapzone = encounter_values[1]
	reserve_dock = encounter_values[2]
	reserve_dock_secondary = encounter_values[3]
	footprint = encounter_values[4]
	// Where the template actually landed. Missions, the contested cache's vault link and
	// the lich's interior index all measure from here, so it comes back from the placer
	// rather than being re-derived from arithmetic that would then have to be kept in step.
	ruin_bottom_left = LAZYACCESS(encounter_values, 5)

	if(!ruin_bottom_left)
		// The slot was built but the template never went down. A ruin with no interior is
		// not a boardable site, so hand the ground straight back rather than leaving a
		// dockable empty box on the chart.
		log_mapping("SPACE RUIN: '[ruin_template.name]' ([ruin_template.width]x[ruin_template.height]) could not be placed inside [footprint.describe()] - site aborted")
		remove_docks()
		remove_mapzone()
		SSovermap.worldgen_release(src)
		loading = FALSE
		worldgen_end(probe, "load-failed")
		SEND_SIGNAL(src, COMSIG_VOIDCREW_SITE_LOAD_FINISHED, FALSE)
		return

	worldgen_end(probe)
	loaded = TRUE
	loading = FALSE
	visited = TRUE
	SSovermap.worldgen_release(src)

	SEND_SIGNAL(src, COMSIG_VOIDCREW_PLANET_LOADED, TRUE)
	SEND_SIGNAL(src, COMSIG_VOIDCREW_SITE_LOAD_FINISHED, TRUE)

/obj/structure/overmap/space_ruin/start_level_load(mob/user, obj/structure/overmap/ship/waiting_ship)
	INVOKE_ASYNC(src, PROC_REF(load_level), user, waiting_ship)

/obj/structure/overmap/space_ruin/is_loading()
	return loading

/obj/structure/overmap/space_ruin/is_loaded()
	// All three, not just the flag: ship_act()'s dock path needs the slot and a berth to
	// exist, and request_site_load()'s fast path re-invokes ship_act off this answer -
	// answering "loaded" while the slot is gone would bounce the two procs off each other
	// in an unbroken INVOKE_ASYNC loop.
	return loaded && mapzone && reserve_dock

/// A wedged load or teardown leaves these flags latched (the watchdog force-released
/// the queue, but nothing else ever resets them), and ships may be registered for a
/// completion signal the dead job will now never send - so send the failure here, or
/// the site reads "survey underway" and holds its waiters for the rest of the round.
/obj/structure/overmap/space_ruin/on_worldgen_timeout()
	loading = FALSE
	concerned = FALSE
	SEND_SIGNAL(src, COMSIG_VOIDCREW_SITE_LOAD_FINISHED, FALSE)

/obj/structure/overmap/space_ruin/attack_ghost(mob/user)
	if(reserve_dock)
		user.forceMove(get_turf(reserve_dock))
		return TRUE
	else if(footprint)
		// The footprint's centre, not the level's: locate(world.maxx/2, world.maxy/2, z)
		// lands in the cordon gutter on a packed level.
		var/turf/center = footprint.get_center_turf()
		if(!center)
			return
		user.forceMove(center)
		return TRUE
	return

/**
 * Handles ship interaction with this ruin
 */
/obj/structure/overmap/space_ruin/get_dock_description()
	// Deliberately whatever the helm currently calls it: an unidentified ruin stays
	// "unknown signal" on the Dock button too, rather than leaking its true name.
	return "[name] (boarding)"

/obj/structure/overmap/space_ruin/ship_act(mob/user, obj/structure/overmap/ship/acting, obj/structure/overmap/ship/optional_partner)
	// dock() refuses interdicted ships only after the dock slot below is claimed -
	// refuse up front instead
	if(acting.is_interdicted)
		if(user)
			to_chat(user, span_warning("Cannot dock while interdicted!"))
		else
			acting.ship_notify("Cannot dock while interdicted!", "DOCKING", SHIP_NOTIFY_WARNING, 'voidcrew/sound/warn.ogg', 25)
		return
	if(concerned)
		if(user)
			to_chat(user, span_notice("Too much traffic, try again later!"))
		else
			acting.ship_notify("Approach on [name] aborted: too much traffic, try again later!", "DOCKING", SHIP_NOTIFY_WARNING, 'voidcrew/sound/warn.ogg', 25)
		return

	// Interior not generated yet (or torn back down): request it in the background and
	// return the helm immediately. The ship stays fully controllable; request_site_load()
	// broadcasts the survey's progress and resumes this approach itself when the ruin
	// charts. Gated on the same is_loaded() the resume path re-checks, so the two can
	// never disagree about whether this ruin is dockable.
	if(!is_loaded())
		acting.request_site_load(src, user)
		return

	concerned = TRUE
	if(user)
		balloon_alert(user, "starting docking process..")

	var/is_survey = FALSE
	var/obj/docking_port/stationary/dock_to_use = null
	var/selected_dock_index = 0

	// Berths do not stay where they were built - see reset_free_reserve_docks_for(). Put the free
	// ones back before choosing one, or the last visitor's offset is carried into this placement
	// and compounds on every arrival.
	reset_free_reserve_docks_for(reserve_dock, reserve_dock_secondary, first_dock_taken, second_dock_taken)

	// Port destinations are set by survey console
	if(acting.shuttle.port_destinations)
		dock_to_use = acting.shuttle.port_destinations
		is_survey = TRUE
	else
		if(!reserve_dock.get_docked() && !first_dock_taken)
			dock_to_use = reserve_dock
			selected_dock_index = 1
		else if(!reserve_dock_secondary.get_docked() && !second_dock_taken)
			dock_to_use = reserve_dock_secondary
			selected_dock_index = 2

	if(!dock_to_use)
		concerned = FALSE
		if(user)
			to_chat(user, span_notice("All potential docking locations occupied."))
		else
			acting.ship_notify("All potential docking locations at [name] are occupied.", "DOCKING", SHIP_NOTIFY_WARNING, 'voidcrew/sound/warn.ogg', 25)
		return

	// Adjust dock and check if shuttle can fit BEFORE committing to docking
	if(!is_survey)
		adjust_dock_to_shuttle(dock_to_use, acting.shuttle)

	// Check if shuttle can actually fit in the dock
	if(acting.shuttle.height > dock_to_use.height || acting.shuttle.width > dock_to_use.width)
		concerned = FALSE
		if(user)
			to_chat(user, span_warning("Ship is too large to dock at this location."))
		else
			acting.ship_notify("Ship is too large to dock at [name].", "DOCKING", SHIP_NOTIFY_WARNING, 'voidcrew/sound/warn.ogg', 25)
		return

	// Now that we know docking will work, set the flags
	if(selected_dock_index == 1)
		first_dock_taken = TRUE
		acting.dock_index = 1
	else if(selected_dock_index == 2)
		second_dock_taken = TRUE
		acting.dock_index = 2

	// dock() only returns a string when it refuses; a successful start is announced
	// to the whole crew by ship_notify()
	var/dock_result = acting.dock(src, dock_to_use)
	if(dock_result)
		if(user)
			to_chat(user, span_notice("[dock_result]"))
		else
			acting.ship_notify("[dock_result]", "DOCKING", SHIP_NOTIFY_WARNING, 'voidcrew/sound/warn.ogg', 25)

	concerned = FALSE

	if(optional_partner)
		ship_act(user, optional_partner)

/**
 * Adjusts dock position for the shuttle (shared helper; see _HELPERS/docking.dm)
 */
/obj/structure/overmap/space_ruin/proc/adjust_dock_to_shuttle(obj/docking_port/stationary/dock_to_adjust, obj/docking_port/mobile/shuttle)
	adjust_reserve_dock_to_shuttle(dock_to_adjust, shuttle)

/**
 * Whether the ruin's slot is genuinely abandoned, ignoring the in-progress flag the
 * caller manages itself. Asked once before joining the worldgen queue and again on the
 * way out of it, because the wait is long enough for the answer to change.
 */
/obj/structure/overmap/space_ruin/proc/can_release_interior()
	if(!mapzone || !footprint)
		return FALSE

	// Never while the interior is still being generated. worldgen_claim() is reentrant
	// by requester, so a teardown fired mid-load would be granted the queue instantly
	// (load and teardown both claim as src) and reset the ground out from under the
	// template still stamping into it.
	if(loading)
		return FALSE

	// A claimed berth means a ship is somewhere between "approach started" and "undock
	// complete" - possibly in hyperspace transit, which the contents and hull-overlap
	// checks below are both blind to.
	if(first_dock_taken || second_dock_taken)
		return FALSE

	// Check if any ships are still docked here (docked ships move INTO the ruin, so check contents)
	for(var/obj/structure/overmap/ship/docked_ship in contents)
		return FALSE

	// Players inside OUR rectangle - a packed level carries up to three neighbours, and a
	// level-wide check would keep this site pinned for as long as any of them has a crew
	// standing on it.
	if(has_players_in_site())
		return FALSE

	// Anyone with a mind standing on our ground, client or not: the same gate the flat
	// encounters use, scoped to the slot rather than the z (map_zones.dm get_mind_mobs_in).
	// Catches a crewman who disconnected inside the ruin, whom the client sweep above
	// cannot see and whose body the teardown would delete.
	if(length(mapzone.get_mind_mobs_in(footprint)))
		return FALSE

	// No ship hull may overlap the slot. The overmap token leaves a full second before the
	// interior physically moves (complete_undock_warmup schedules both), and the undock
	// recycling fires 0.5s after the token leaves - so both checks above are blind to an
	// interior still mid-departure, and a teardown landing in that window resets turfs out
	// from under the transplant, or deletes whatever a bad move stranded (round 803:
	// Delta's four thrusters died to exactly this). Shared with the asteroid field, which
	// used to have no such guard at all - see footprint_blocking_hull_reason().
	var/blocking_reason = footprint_blocking_hull_reason(footprint)
	if(blocking_reason)
		log_mapping("SSovermap: Space ruin '[name]' teardown refused - [blocking_reason]")
		return FALSE

	return TRUE

/**
 * Frees the ruin's interior, under the worldgen queue, if it is genuinely abandoned.
 *
 * Every teardown path funnels through here - undock recycling, mission cleanup, event
 * retirement, and the subtypes that keep their own variants. They differ only in what
 * happens *after* the interior is gone (relocate, hold position, respawn a
 * replacement, delete the signal), so the guarding, queueing and re-checking are done
 * once, here, rather than in four copies that each have to remember all three.
 *
 * Returns TRUE if the interior was released. Returns FALSE if the ruin was busy, if
 * somebody is still inside, or if the queue timed out - callers must not run their
 * tail behaviour on FALSE, and should retry later if they have somewhere to retry from.
 */
/obj/structure/overmap/space_ruin/proc/release_interior()
	if(concerned)
		return FALSE

	if(!can_release_interior())
		return FALSE

	// The teardown qdels every atom standing on our slot - far too heavy to
	// run alongside a planet build or another survey, so it takes the worldgen queue
	// like every other job. A timeout is a soft failure: callers retry later.
	//
	// `concerned` is only raised once the claim is granted: the wait can run for
	// minutes, and holding the flag through it would refuse every arriving ship for
	// a teardown that may yet stand down. An arrival mid-wait claims a berth, which
	// the re-check below reads as "occupied" and aborts on.
	if(!SSovermap.worldgen_claim(src, "ruin teardown ([name])"))
		return FALSE

	concerned = TRUE

	// Asked twice, once before joining the queue and again now that we hold it: the
	// wait can run for minutes, and someone sneaking back aboard mid-wait must stop
	// the teardown - we are about to delete every atom on our slot.
	if(!can_release_interior())
		SSovermap.worldgen_release(src)
		concerned = FALSE
		return FALSE

	// Announce the teardown before anything is actually torn down, and with the
	// loaded flag already down so a listener that re-arms itself waits for the
	// next load rather than spawning into turfs that are about to be recycled.
	loaded = FALSE
	SEND_SIGNAL(src, COMSIG_VOIDCREW_RUIN_UNLOADING)

	remove_docks()
	remove_mapzone()

	SSovermap.worldgen_release(src)
	concerned = FALSE
	return TRUE

/**
 * Unloads the ruin level when no longer needed
 */
/obj/structure/overmap/space_ruin/proc/unload_level()
	if(!release_interior())
		return

	forceMove(SSovermap.get_unused_overmap_square())

/**
 * Sweeps our slot for uninitialized turfs (leftover /turf/open/space/basic) and
 * initializes them so players can interact with the space around the ruin.
 *
 * spawn_dynamic_encounter() already does this on the way in, AFTER the template is
 * stamped; this stays as the hook for anything that lays more ground down later.
 */
/obj/structure/overmap/space_ruin/proc/initialize_site_space_turfs()
	if(!footprint)
		return
	footprint.level?.initialize_space_turfs(footprint)

/**
 * Hands the ruin's ground and its slot back.
 *
 * Deliberately here rather than in release_interior(), so the harness's forced path and
 * every subtype that frees its interior by hand get the full sequence.
 */
/obj/structure/overmap/space_ruin/proc/remove_mapzone()
	if(mapzone)
		var/datum/map_zone/departing_zone = mapzone
		var/datum/map_footprint/departing_footprint = footprint
		// Ports FIRST, while the footprint still knows where it is. Neither teardown sweep
		// will touch an /obj/docking_port - clear_reservation() goes through
		// /turf/proc/empty(), which excludes them, and a non-forced qdel on a port answers
		// QDEL_HINT_LETMELIVE - so the ports this ruin's TEMPLATE brought with it (the
		// Cyborg Mothership's, the pirate cutter's) outlive the slot unless taken by name,
		// and then permanently pin the coordinates against every later tenant's teardown.
		// See reap_footprint_docking_ports().
		reap_footprint_docking_ports(departing_footprint)
		// clear_reservation() rather than clear_to_uninitialized_space(): a ruin interior
		// is dense content (walls, machinery, cables, atmos), and this is the ChangeTurf
		// path that runs each turf's own Destroy - the same wipe the reservation Release()
		// used to give it, and what planets (the other content-heavy tenant) use. Per-slot:
		// only our rectangle is reset unless we are the last tenant, in which case the
		// whole level including the cordon goes back so the zone recycles clean.
		//
		// throttled = TRUE: release_interior() holds the worldgen queue over this call.
		departing_zone.clear_reservation(TRUE, departing_footprint)
		departing_zone.release_slot(departing_footprint)
		mapzone = null
		footprint = null
	ruin_bottom_left = null

/**
 * Picks a random non-dense, non-space turf inside the loaded ruin's template footprint.
 * Used by recovery missions to place objectives. Returns null if the ruin isn't loaded.
 */
/obj/structure/overmap/space_ruin/proc/get_random_interior_turf()
	if(!loaded || !ruin_bottom_left || !ruin_template?.width || !ruin_template?.height)
		return null
	var/turf/top_right = locate(
		ruin_bottom_left.x + ruin_template.width - 1,
		ruin_bottom_left.y + ruin_template.height - 1,
		ruin_bottom_left.z
	)
	if(!top_right)
		return null
	var/list/candidates = list()
	for(var/turf/interior_turf as anything in block(ruin_bottom_left, top_right))
		if(interior_turf.density)
			continue
		// Templates aren't rectangular; skip the empty space inside the bounding box
		if(isspaceturf(interior_turf))
			continue
		// A ship parked over the footprint has open, undense floor of its own. Spawn
		// a mission objective on it and the ship flies away with it when it undocks.
		if(istype(get_area(interior_turf), /area/shuttle))
			continue
		// And never outside our own slot. The template rect is inside it by construction,
		// but a hand-set ruin_bottom_left or a template that grew past its preloaded size
		// would otherwise put a mission objective on the neighbour's ground.
		if(footprint && !footprint.contains_turf(interior_turf))
			continue
		candidates += interior_turf
	if(!length(candidates))
		return null
	return pick(candidates)

/obj/structure/overmap/space_ruin/proc/remove_docks()
	if(reserve_dock)
		qdel(reserve_dock, TRUE)
		reserve_dock = null
	if(reserve_dock_secondary)
		qdel(reserve_dock_secondary, TRUE)
		reserve_dock_secondary = null

/**
 * Checks if any players with clients are standing inside this ruin's own slot.
 * Thin wrapper around the shared helper (see map_zones.dm) - kept as an instance
 * proc so subtypes can override or call it by name.
 */
/obj/structure/overmap/space_ruin/proc/has_players_in_site()
	return turf_footprint_has_players(footprint)

/**
 * Called when a ship undocks - checks if the ruin should be cleaned up and respawned
 * If no living players remain in the ruin, unloads it and spawns a new one elsewhere
 */
/obj/structure/overmap/space_ruin/proc/check_and_respawn()
	// A live mission still needs this site; its cleanup path clears the lock
	// and re-runs this check when it's done with the ruin
	if(mission_locked)
		return

	// Store the ruin template before we clean up
	var/datum/map_template/ruin/space/old_template = ruin_template

	// Guards, queues and frees the slot, or refuses because somebody is still
	// aboard. Nothing below may run unless it actually went through. A refusal is
	// usually the departing ship's interior still mid-move (the hull-overlap guard in
	// can_release_interior()), so try again once the departure has finished rather
	// than holding the slot until the next visitor undocks.
	if(!release_interior())
		addtimer(CALLBACK(src, PROC_REF(check_and_respawn)), 30 SECONDS, TIMER_UNIQUE)
		return

	// A live contract is pointed here. The interior is gone either way - it was
	// empty, and holding a slot open for a crew that may never come back
	// is what the recycle exists to stop - but the signal itself stays put, on
	// the same tile the contract charted. Deleting it would move the job to a
	// different ruin the moment its crew undocked, which from the helm reads as
	// the contract vanishing off the chart.
	if(mission_claims > 0)
		log_mapping("SSovermap: Space ruin '[name]' was empty and unloaded, but [mission_claims] contract(s) still point here - holding position")
		return

	log_mapping("SSovermap: Space ruin '[name]' was empty, unloaded and respawning")

	// Spawn a new ruin somewhere else on the overmap BEFORE we delete ourselves.
	// Rare rumor ruins are one-shots: clearing one doesn't seed anything new.
	if(!rare)
		spawn_replacement_ruin(old_template)

	// Delete this overmap object
	qdel(src)

/**
 * Spawns a new space ruin on the overmap to replace one that was cleaned up
 * Tries to pick a different ruin template if possible
 *
 * If preserved_category is set, only templates of that category are considered,
 * falling back to the full pool if no template of the category is available.
 * Unused by the normal respawn path (ruin categories no longer need to be preserved
 * now that "asteroid" was retired) but kept generic in case a future category needs it.
 */
/proc/spawn_replacement_ruin(datum/map_template/ruin/space/excluded_template, preserved_category = null)
	var/list/available_ruins = SSmapping.space_ruins_templates
	if(!available_ruins || !length(available_ruins))
		return

	// Every template a signal on the chart is already using. Roundstart seeding tracks
	// this (used_ruins, setup_space_ruins) but the respawn path never did, so the same
	// template accumulated copies over a round - which under packing is the collision
	// case that matters: two co-tenants of one z-level rolling one template share an
	// /area/ruin instance unless the loader is told to instance it per load.
	var/list/live_templates = list()
	for(var/obj/structure/overmap/space_ruin/live as anything in GLOB.space_ruin_signals)
		if(QDELETED(live) || !live.ruin_template)
			continue
		live_templates[live.ruin_template] = TRUE

	// Build pickable list excluding the old template if it doesn't allow duplicates
	var/list/ruin_pool = list()
	var/list/duplicate_pool = list()
	for(var/ruin_id in available_ruins)
		var/datum/map_template/ruin/space/ruin = available_ruins[ruin_id]
		if(!istype(ruin) || ruin.unpickable)
			continue
		// Skip the excluded template to add variety (unless it allows duplicates)
		if(ruin == excluded_template && !ruin.allow_duplicates)
			continue
		if(live_templates[ruin])
			// A hard rule when the template forbids duplicates, a preference otherwise:
			// held back so the sector keeps its variety and only used if the pool would
			// otherwise be empty. (The pre-existing excluded_template test above cannot
			// do this on its own - allow_duplicates defaults to TRUE, so it never fires.)
			if(ruin.allow_duplicates)
				duplicate_pool += ruin
			continue
		ruin_pool += ruin

	if(!length(ruin_pool))
		ruin_pool = duplicate_pool

	if(preserved_category)
		var/list/category_pool = list()
		for(var/datum/map_template/ruin/space/ruin in ruin_pool)
			if(space_ruin_template_category(ruin) == preserved_category)
				category_pool += ruin
		if(length(category_pool))
			ruin_pool = category_pool
		else if(excluded_template && space_ruin_template_category(excluded_template) == preserved_category)
			// Only one template of this category exists - reuse it
			ruin_pool = list(excluded_template)

	if(!length(ruin_pool))
		// Fall back to including the excluded template
		ruin_pool += excluded_template

	// Use weighted selection
	var/list/weighted_ruins = list()
	for(var/datum/map_template/ruin/space/ruin in ruin_pool)
		weighted_ruins[ruin] = ruin.placement_weight || 1
	var/datum/map_template/ruin/space/selected_ruin = pick_weight(weighted_ruins)

	if(!selected_ruin)
		return

	// Find a spot on the overmap
	var/turf/spawn_turf = SSovermap.get_unused_overmap_square()
	if(!spawn_turf)
		return

	// Create the new ruin
	var/obj/structure/overmap/space_ruin/new_ruin = new(spawn_turf)
	new_ruin.set_ruin_template(selected_ruin)
	log_mapping("SSovermap: Spawned replacement space ruin '[selected_ruin.name]'")
