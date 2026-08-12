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
	/// The turf reservation for this ruin (smaller than full z-level)
	var/datum/turf_reservation/reservation
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

/obj/structure/overmap/space_ruin/Initialize(mapload, datum/map_template/ruin/space/template)
	. = ..()
	GLOB.space_ruin_signals += src
	if(template)
		set_ruin_template(template)

/obj/structure/overmap/space_ruin/Destroy()
	GLOB.space_ruin_signals -= src
	ruin_bottom_left = null
	return ..()

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
 * Load the ruin using a turf reservation (smaller than full z-level)
 */
/obj/structure/overmap/space_ruin/proc/load_level()
	if(reservation)
		return
	if(loading)
		return
	if(!ruin_template)
		return

	loading = TRUE

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
			return

	// Calculate reservation size: ruin size + buffer for docking on two sides
	// Use the same dock sizes as planets to support large ships
	var/reserve_width = ruin_template.width + (RESERVE_DOCK_MAX_SIZE_LONG * 2) + (RESERVE_DOCK_DEFAULT_PADDING * 2)
	var/reserve_height = ruin_template.height + (RESERVE_DOCK_MAX_SIZE_SHORT * 2) + (RESERVE_DOCK_DEFAULT_PADDING * 2)

	// Asking for a block no reservation z-level can hold is not a retryable "full right
	// now": request_turf_block_reservation() reads it that way, allocates a fresh
	// 255x255 z-level, fails on that too and returns null while keeping the level - so
	// every attempt leaks one. Bail before that. Templates this big are meant to be
	// unpickable (see /datum/map_template/ruin/space/oldstation) and the
	// voidcrew_ruin_reservation_fit unit test keeps them out of the spawn pools, so
	// reaching here means one surfaced by chart, mission or admin spawn instead.
	if(!SSmapping.reservation_can_ever_fit(reserve_width, reserve_height))
		log_mapping("SPACE RUIN: '[ruin_template.name]' is [ruin_template.width]x[ruin_template.height], \
			needing a [reserve_width]x[reserve_height] reservation - too large to ever fit. Ruin is unboardable.")
		loading = FALSE
		return

	// Request a turf reservation instead of a full z-level
	reservation = SSmapping.request_turf_block_reservation(reserve_width, reserve_height, 1)
	if(!reservation)
		loading = FALSE
		return

	var/turf/bottom_left = reservation.bottom_left_turfs[1]

	// Load the ruin with buffer space around it
	var/ruin_x = bottom_left.x + RESERVE_DOCK_MAX_SIZE_LONG + RESERVE_DOCK_DEFAULT_PADDING
	var/ruin_y = bottom_left.y + RESERVE_DOCK_MAX_SIZE_SHORT + RESERVE_DOCK_DEFAULT_PADDING
	var/turf/ruin_turf = locate(ruin_x, ruin_y, bottom_left.z)
	ruin_bottom_left = ruin_turf

	// Try to load the ruin, handle failures gracefully
	var/load_success = FALSE
	try
		load_success = ruin_template.load(ruin_turf)
	catch(var/exception/e)
		log_mapping("SPACE RUIN: Failed to load '[ruin_template.name]': [e]")
		load_success = FALSE

	if(!load_success)
		// Clean up the reservation if loading failed
		qdel(reservation)
		reservation = null
		ruin_bottom_left = null
		loading = FALSE
		return

	// The reservation's buffer space (everything outside the ruin's own footprint)
	// is left as uninitialized /turf/open/space/basic - fix it up before anyone can reach it
	initialize_reservation_space_turfs()

	// Create docking ports on opposite sides of the ruin (same size as planets)
	var/turf/primary_dock_turf = locate(
		bottom_left.x + RESERVE_DOCK_DEFAULT_PADDING,
		bottom_left.y + RESERVE_DOCK_DEFAULT_PADDING,
		bottom_left.z
	)
	reserve_dock = new /obj/docking_port/stationary(primary_dock_turf)
	reserve_dock.dir = NORTH
	reserve_dock.name = "\improper Space Ruin"
	reserve_dock.width = RESERVE_DOCK_MAX_SIZE_LONG
	reserve_dock.height = RESERVE_DOCK_MAX_SIZE_SHORT
	reserve_dock.dheight = 0
	reserve_dock.dwidth = 0

	var/turf/secondary_dock_turf = locate(
		bottom_left.x + reserve_width - RESERVE_DOCK_MAX_SIZE_LONG - RESERVE_DOCK_DEFAULT_PADDING,
		bottom_left.y + reserve_height - RESERVE_DOCK_MAX_SIZE_SHORT - RESERVE_DOCK_DEFAULT_PADDING,
		bottom_left.z
	)
	reserve_dock_secondary = new /obj/docking_port/stationary(secondary_dock_turf)
	reserve_dock_secondary.dir = NORTH
	reserve_dock_secondary.name = "\improper Space Ruin"
	reserve_dock_secondary.width = RESERVE_DOCK_MAX_SIZE_LONG
	reserve_dock_secondary.height = RESERVE_DOCK_MAX_SIZE_SHORT
	reserve_dock_secondary.dheight = 0
	reserve_dock_secondary.dwidth = 0

	// Both berths get moved and resized to fit every ship that visits; record where they started
	// so the next arrival is placed from this layout rather than the last visitor's offset.
	reserve_dock.mark_reserve_home()
	reserve_dock_secondary.mark_reserve_home()

	loaded = TRUE
	loading = FALSE
	visited = TRUE

	SEND_SIGNAL(src, COMSIG_VOIDCREW_PLANET_LOADED, TRUE)

/obj/structure/overmap/space_ruin/attack_ghost(mob/user)
	if(reserve_dock)
		user.forceMove(get_turf(reserve_dock))
		return TRUE
	else if(reservation)
		var/turf/bottom_left = reservation.bottom_left_turfs[1]
		if(!bottom_left)
			return
		// Go to center of reservation
		var/turf/center = locate(
			bottom_left.x + round(reservation.width / 2),
			bottom_left.y + round(reservation.height / 2),
			bottom_left.z
		)
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
	// dock() refuses interdicted ships only after the dock slot below is claimed
	// and the ship is locked into ACTING - refuse up front instead
	if(acting.is_interdicted)
		to_chat(user, span_warning("Cannot dock while interdicted!"))
		return
	if(concerned)
		to_chat(user, span_notice("Too much traffic, try again later!"))
		return
	concerned = TRUE

	var/prev_state = acting.state
	acting.state = OVERMAP_SHIP_ACTING
	balloon_alert(user, "starting docking process..")

	// Load the level first
	load_level()

	if(!reservation || !reserve_dock)
		acting.state = prev_state
		concerned = FALSE
		to_chat(user, span_warning("Failed to load the location."))
		return

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
		acting.state = prev_state
		concerned = FALSE
		to_chat(user, span_notice("All potential docking locations occupied."))
		return

	// Adjust dock and check if shuttle can fit BEFORE committing to docking
	if(!is_survey)
		adjust_dock_to_shuttle(dock_to_use, acting.shuttle)

	// Check if shuttle can actually fit in the dock
	if(acting.shuttle.height > dock_to_use.height || acting.shuttle.width > dock_to_use.width)
		acting.state = prev_state
		concerned = FALSE
		to_chat(user, span_warning("Ship is too large to dock at this location."))
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
		to_chat(user, span_notice("[dock_result]"))

	concerned = FALSE

	if(optional_partner)
		ship_act(user, optional_partner)

/**
 * Adjusts dock position for the shuttle (shared helper; see _HELPERS/docking.dm)
 */
/obj/structure/overmap/space_ruin/proc/adjust_dock_to_shuttle(obj/docking_port/stationary/dock_to_adjust, obj/docking_port/mobile/shuttle)
	adjust_reserve_dock_to_shuttle(dock_to_adjust, shuttle)

/**
 * Whether the ruin's reservation is genuinely abandoned, ignoring the in-progress flag
 * the caller manages itself. Asked once before joining the worldgen queue and again on
 * the way out of it, because the wait is long enough for the answer to change.
 */
/obj/structure/overmap/space_ruin/proc/can_release_interior()
	if(!reservation)
		return FALSE

	// Check if any ships are still docked here (docked ships move INTO the ruin, so check contents)
	for(var/obj/structure/overmap/ship/docked_ship in contents)
		return FALSE

	// Check for players within the reservation bounds (not the whole z-level since reservations share z-levels)
	if(has_players_in_reservation())
		return FALSE

	// No ship hull may overlap the reservation. The overmap token leaves a full second
	// before the interior physically moves (complete_undock_warmup schedules both), and
	// the undock recycling fires 0.5s after the token leaves - so both checks above are
	// blind to an interior still mid-departure, and a teardown landing in that window
	// resets turfs out from under the transplant, or deletes whatever a bad move
	// stranded (round 803: Delta's four thrusters died to exactly this).
	var/turf/reservation_bottom_left = reservation.bottom_left_turfs[1]
	var/turf/reservation_top_right = reservation.top_right_turfs[1]
	if(reservation_bottom_left && reservation_top_right)
		var/res_z = reservation_bottom_left.z
		for(var/obj/docking_port/mobile/port as anything in SSshuttle.mobile_docking_ports)
			if(port.z == res_z)
				var/list/port_rect = port.return_coords()
				if(max(port_rect[1], port_rect[3]) >= reservation_bottom_left.x \
					&& min(port_rect[1], port_rect[3]) <= reservation_top_right.x \
					&& max(port_rect[2], port_rect[4]) >= reservation_bottom_left.y \
					&& min(port_rect[2], port_rect[4]) <= reservation_top_right.y)
					log_mapping("SSovermap: Space ruin '[name]' teardown refused - [port.name] still overlaps the reservation (parked or mid-departure)")
					return FALSE
			// Stranded hull: a registered ship area still holding turfs inside our block
			for(var/area/ship_area as anything in port.shuttle_areas)
				for(var/turf/held_turf as anything in ship_area.get_turfs_by_zlevel(res_z))
					if(held_turf.x >= reservation_bottom_left.x && held_turf.x <= reservation_top_right.x \
						&& held_turf.y >= reservation_bottom_left.y && held_turf.y <= reservation_top_right.y)
						log_mapping("SSovermap: Space ruin '[name]' teardown refused - [port.name]'s [ship_area.type] still holds [held_turf] at [AREACOORD(held_turf)]")
						return FALSE
			// Stranded engines: connected thrusters standing in our block (their tile may
			// sit in an orphaned area the sweep above can't see)
			for(var/obj/machinery/power/shuttle_engine/engine as anything in port.engine_list)
				var/turf/engine_turf = get_turf(engine)
				if(engine_turf?.z == res_z \
					&& engine_turf.x >= reservation_bottom_left.x && engine_turf.x <= reservation_top_right.x \
					&& engine_turf.y >= reservation_bottom_left.y && engine_turf.y <= reservation_top_right.y)
					log_mapping("SSovermap: Space ruin '[name]' teardown refused - [port.name]'s [engine] is standing at [AREACOORD(engine_turf)]")
					return FALSE

	return TRUE

/**
 * Frees the ruin's interior, under the worldgen queue, if it is genuinely abandoned.
 *
 * Every teardown path funnels through here - undock recycling, mission cleanup, event
 * retirement, and the subtypes that keep their own variants. They differ only in what
 * happens *after* the reservation is gone (relocate, hold position, respawn a
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

	concerned = TRUE

	// Announce the teardown before anything is actually torn down, and with the
	// loaded flag already down so a listener that re-arms itself waits for the
	// next load rather than spawning into turfs that are about to be recycled.
	loaded = FALSE
	SEND_SIGNAL(src, COMSIG_VOIDCREW_RUIN_UNLOADING)

	remove_docks()
	remove_reservation()

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
 * Sweeps the reservation for uninitialized turfs (leftover /turf/open/space/basic)
 * and initializes them so players can interact with the buffer space around the ruin.
 */
/obj/structure/overmap/space_ruin/proc/initialize_reservation_space_turfs()
	if(!reservation)
		return
	initialize_uninitialized_block_turfs(reservation.bottom_left_turfs[1], reservation.top_right_turfs[1])

/obj/structure/overmap/space_ruin/proc/remove_reservation()
	if(reservation)
		qdel(reservation)
		reservation = null
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
 * Checks if any players with clients are within the reservation bounds.
 * Thin wrapper around the shared helper (see map_zones.dm) - kept as an instance
 * proc since several ruin subtypes (contested_cache, vestige) call it by name.
 */
/obj/structure/overmap/space_ruin/proc/has_players_in_reservation()
	return turf_reservation_has_players(reservation)

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

	// Guards, queues and frees the reservation, or refuses because somebody is still
	// aboard. Nothing below may run unless it actually went through. A refusal is
	// usually the departing ship's interior still mid-move (the hull-overlap guard in
	// can_release_interior()), so try again once the departure has finished rather
	// than holding the reservation until the next visitor undocks.
	if(!release_interior())
		addtimer(CALLBACK(src, PROC_REF(check_and_respawn)), 30 SECONDS, TIMER_UNIQUE)
		return

	// A live contract is pointed here. The interior is gone either way - it was
	// empty, and holding a reservation open for a crew that may never come back
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

	// Build pickable list excluding the old template if it doesn't allow duplicates
	var/list/ruin_pool = list()
	for(var/ruin_id in available_ruins)
		var/datum/map_template/ruin/space/ruin = available_ruins[ruin_id]
		if(!istype(ruin) || ruin.unpickable)
			continue
		// Skip the excluded template to add variety (unless it allows duplicates)
		if(ruin == excluded_template && !ruin.allow_duplicates)
			continue
		ruin_pool += ruin

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
