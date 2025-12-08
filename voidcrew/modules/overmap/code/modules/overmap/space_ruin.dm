/**
 * Space Ruin Overmap Object
 *
 * Represents a space ruin that appears as a mysterious signal on the overmap.
 * When surveyed, reveals its true nature (derelict, station, asteroid, etc.).
 * Ships can dock and explore the ruin.
 */
/obj/structure/overmap/space_ruin
	name = "unknown signal"
	desc = "A faint signal of unknown origin. Survey to learn more."
	icon_state = "strange_event"

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
	/// Category for grouping (derelict, station, asteroid, syndicate, misc)
	var/ruin_category = "unknown"

/obj/structure/overmap/space_ruin/Initialize(mapload, datum/map_template/ruin/space/template)
	. = ..()
	if(template)
		set_ruin_template(template)

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

	var/ruin_id = ruin_template.id
	var/ruin_name = lowertext(ruin_template.name)

	// Check for category keywords
	if(findtext(ruin_id, "derelict") || findtext(ruin_name, "derelict"))
		ruin_category = "derelict"
	else if(findtext(ruin_id, "asteroid") || findtext(ruin_name, "asteroid"))
		ruin_category = "asteroid"
	else if(findtext(ruin_id, "syndicate") || findtext(ruin_name, "syndicate") || findtext(ruin_id, "listening") || findtext(ruin_id, "infiltrator"))
		ruin_category = "syndicate"
	else if(findtext(ruin_name, "station") || findtext(ruin_name, "outpost") || findtext(ruin_name, "hotel") || findtext(ruin_name, "waystation"))
		ruin_category = "station"
	else if(findtext(ruin_name, "ship") || findtext(ruin_name, "shuttle") || findtext(ruin_name, "frigate") || findtext(ruin_name, "transport"))
		ruin_category = "ship"
	else if(findtext(ruin_name, "research") || findtext(ruin_name, "lab") || findtext(ruin_name, "facility"))
		ruin_category = "research"
	else
		ruin_category = "unknown"

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
		if("asteroid")
			icon_state = "asteroid"
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
		loading = FALSE
		return

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
/obj/structure/overmap/space_ruin/ship_act(mob/user, obj/structure/overmap/ship/acting, obj/structure/overmap/ship/optional_partner)
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

	to_chat(user, span_notice("[acting.dock(src, dock_to_use)]"))

	concerned = FALSE

	if(optional_partner)
		ship_act(user, optional_partner)

/**
 * Adjusts dock position for the shuttle (copied from planet.dm)
 */
/obj/structure/overmap/space_ruin/proc/adjust_dock_to_shuttle(obj/docking_port/stationary/dock_to_adjust, obj/docking_port/mobile/shuttle)
	var/shuttle_true_height = shuttle.height
	var/shuttle_true_width = shuttle.width
	if(EWCOMPONENT(shuttle.port_direction))
		shuttle_true_height = shuttle.width
		shuttle_true_width = shuttle.height
	var/final_facing_dir = angle2dir(dir2angle(shuttle_true_height > shuttle_true_width ? EAST : NORTH)+dir2angle(shuttle.port_direction)+180)
	var/list/old_corners = dock_to_adjust.return_coords()
	var/list/new_dock_location
	if(final_facing_dir == dock_to_adjust.dir)
		new_dock_location = list(old_corners[1], old_corners[2])
	else if(final_facing_dir == angle2dir(dir2angle(dock_to_adjust.dir)+180))
		new_dock_location = list(old_corners[3], old_corners[4])
	else
		var/combined_dirs = final_facing_dir | dock_to_adjust.dir
		if(combined_dirs == (NORTH|EAST) || combined_dirs == (SOUTH|WEST))
			new_dock_location = list(old_corners[1], old_corners[4])
		else
			new_dock_location = list(old_corners[3], old_corners[2])
		var/dock_height_store = dock_to_adjust.height
		dock_to_adjust.height = dock_to_adjust.width
		dock_to_adjust.width = dock_height_store

	dock_to_adjust.dir = final_facing_dir

	var/new_dheight = round((dock_to_adjust.height-shuttle.height)/2) + shuttle.dheight
	var/new_dwidth = round((dock_to_adjust.width-shuttle.width)/2) + shuttle.dwidth

	switch(final_facing_dir)
		if(NORTH)
			new_dock_location[1] += new_dwidth
			new_dock_location[2] += new_dheight
		if(SOUTH)
			new_dock_location[1] -= new_dwidth
			new_dock_location[2] -= new_dheight
		if(EAST)
			new_dock_location[1] += new_dheight
			new_dock_location[2] -= new_dwidth
		if(WEST)
			new_dock_location[1] -= new_dheight
			new_dock_location[2] += new_dwidth

	dock_to_adjust.forceMove(locate(new_dock_location[1], new_dock_location[2], dock_to_adjust.z))
	dock_to_adjust.dheight = new_dheight
	dock_to_adjust.dwidth = new_dwidth

/**
 * Unloads the ruin level when no longer needed
 */
/obj/structure/overmap/space_ruin/proc/unload_level()
	if(concerned || !reservation)
		return

	// Check if any ships are still docked
	for(var/obj/structure/overmap/ship/docked_ship in contents)
		return

	// Check for players in the reservation's z-level
	var/turf/bottom_left = reservation.bottom_left_turfs[1]
	if(bottom_left && length(SSmobs.clients_by_zlevel[bottom_left.z]))
		return

	concerned = TRUE

	remove_docks()
	remove_reservation()

	forceMove(SSovermap.get_unused_overmap_square())
	concerned = FALSE

/obj/structure/overmap/space_ruin/proc/remove_reservation()
	if(reservation)
		qdel(reservation)
		reservation = null

/obj/structure/overmap/space_ruin/proc/remove_docks()
	if(reserve_dock)
		qdel(reserve_dock, TRUE)
		reserve_dock = null
	if(reserve_dock_secondary)
		qdel(reserve_dock_secondary, TRUE)
		reserve_dock_secondary = null

/**
 * Checks if any players with clients are within the reservation bounds
 */
/obj/structure/overmap/space_ruin/proc/has_players_in_reservation()
	if(!reservation)
		return FALSE

	var/turf/bottom_left = reservation.bottom_left_turfs[1]
	if(!bottom_left)
		return FALSE

	// Get the reservation bounds
	var/min_x = bottom_left.x
	var/min_y = bottom_left.y
	var/max_x = min_x + reservation.width - 1
	var/max_y = min_y + reservation.height - 1
	var/res_z = bottom_left.z

	// Check all clients on this z-level to see if any are within bounds
	for(var/mob/player in SSmobs.clients_by_zlevel[res_z])
		var/turf/player_turf = get_turf(player)
		if(!player_turf)
			continue
		if(player_turf.x >= min_x && player_turf.x <= max_x && player_turf.y >= min_y && player_turf.y <= max_y)
			return TRUE

	return FALSE

/**
 * Called when a ship undocks - checks if the ruin should be cleaned up and respawned
 * If no living players remain in the ruin, unloads it and spawns a new one elsewhere
 */
/obj/structure/overmap/space_ruin/proc/check_and_respawn()
	// Don't do anything if reservation doesn't exist (never loaded)
	if(!reservation)
		return

	// Check if any ships are still docked here (docked ships move INTO the ruin, so check contents)
	for(var/obj/structure/overmap/ship/docked_ship in contents)
		return // A ship is still docked here, don't clean up

	// Check for players within the reservation bounds (not the whole z-level since reservations share z-levels)
	if(has_players_in_reservation())
		return // Someone's still there, don't clean up

	// No one left - clean up and respawn
	log_mapping("SSovermap: Space ruin '[name]' is empty, unloading and respawning")

	// Store the ruin template before we clean up
	var/datum/map_template/ruin/space/old_template = ruin_template

	// Clean up the reservation
	remove_docks()
	remove_reservation()
	loaded = FALSE

	// Spawn a new ruin somewhere else on the overmap BEFORE we delete ourselves
	spawn_replacement_ruin(old_template)

	// Delete this overmap object
	qdel(src)

/**
 * Spawns a new space ruin on the overmap to replace one that was cleaned up
 * Tries to pick a different ruin template if possible
 */
/proc/spawn_replacement_ruin(datum/map_template/ruin/space/excluded_template)
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
