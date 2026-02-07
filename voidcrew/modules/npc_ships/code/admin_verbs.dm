/**
 * Admin verbs for NPC pirate mob spawning
 */

/// Mapping of faction names to their mob types
GLOBAL_LIST_INIT(npc_pirate_factions, list(
	"Silverscale" = list(
		"Melee (Duelist)" = /mob/living/basic/trooper/pirate/faction/silverscale/melee,
		"Ranged (Marksman)" = /mob/living/basic/trooper/pirate/faction/silverscale/ranged,
		"Captain (Noble)" = /mob/living/basic/trooper/pirate/faction/silverscale/captain,
		"Boss (Highlord)" = /mob/living/basic/trooper/pirate/faction/boss/silverscale,
	),
	"Skeleton" = list(
		"Melee (Swashbuckler)" = /mob/living/basic/trooper/pirate/faction/skeleton/melee,
		"Ranged (Gunner)" = /mob/living/basic/trooper/pirate/faction/skeleton/ranged,
		"Captain" = /mob/living/basic/trooper/pirate/faction/skeleton/captain,
		"Boss (Davy Jones)" = /mob/living/basic/trooper/pirate/faction/boss/skeleton,
	),
	"Grey Tide" = list(
		"Melee (Grey Tider)" = /mob/living/basic/trooper/pirate/faction/grey/melee,
		"Ranged (Gunner)" = /mob/living/basic/trooper/pirate/faction/grey/ranged,
		"Captain (Tidemaster)" = /mob/living/basic/trooper/pirate/faction/grey/captain,
		"Boss (The Robust One)" = /mob/living/basic/trooper/pirate/faction/boss/grey,
	),
	"Lustrous" = list(
		"Melee (Scintillant)" = /mob/living/basic/trooper/pirate/faction/lustrous/melee,
		"Ranged (Coruscant)" = /mob/living/basic/trooper/pirate/faction/lustrous/ranged,
		"Captain (Radiant)" = /mob/living/basic/trooper/pirate/faction/lustrous/captain,
		"Boss (The Radiant One)" = /mob/living/basic/trooper/pirate/faction/boss/lustrous,
	),
	"Interdyne" = list(
		"Melee (Enforcer)" = /mob/living/basic/trooper/pirate/faction/interdyne/melee,
		"Ranged (Pharmacist)" = /mob/living/basic/trooper/pirate/faction/interdyne/ranged,
		"Captain (Director)" = /mob/living/basic/trooper/pirate/faction/interdyne/captain,
		"Boss (Director Prime)" = /mob/living/basic/trooper/pirate/faction/boss/interdyne,
	),
	"IRS" = list(
		"Melee (Enforcer)" = /mob/living/basic/trooper/pirate/faction/irs/melee,
		"Ranged (Agent)" = /mob/living/basic/trooper/pirate/faction/irs/ranged,
		"Captain (Head Auditor)" = /mob/living/basic/trooper/pirate/faction/irs/captain,
		"Boss (Chief Auditor)" = /mob/living/basic/trooper/pirate/faction/boss/irs,
	),
	"Medieval" = list(
		"Melee (Footsoldier)" = /mob/living/basic/trooper/pirate/faction/medieval/melee,
		"Ranged (Crossbowman)" = /mob/living/basic/trooper/pirate/faction/medieval/ranged,
		"Captain (Warlord)" = /mob/living/basic/trooper/pirate/faction/medieval/captain,
		"Boss (The Black Knight)" = /mob/living/basic/trooper/pirate/faction/boss/medieval,
	),
))

ADMIN_VERB(spawn_npc_pirate, R_SPAWN|R_DEBUG, "Spawn NPC Pirate", "Spawn an NPC pirate mob with patrol AI.", ADMIN_CATEGORY_DEBUG)
	var/mob/admin_mob = user.mob
	if(!admin_mob)
		to_chat(user, span_warning("You need a mob to spawn pirates."))
		return

	var/turf/spawn_turf = get_turf(admin_mob)
	if(!spawn_turf)
		to_chat(user, span_warning("Could not find a valid turf to spawn on."))
		return

	// Step 1: Select faction
	var/list/faction_names = list()
	for(var/faction_name in GLOB.npc_pirate_factions)
		faction_names += faction_name

	var/selected_faction = tgui_input_list(user, "Select a pirate faction:", "Spawn NPC Pirate", faction_names)
	if(!selected_faction)
		return

	// Step 2: Select pirate type from that faction
	var/list/pirate_types = GLOB.npc_pirate_factions[selected_faction]
	if(!length(pirate_types))
		to_chat(user, span_warning("No pirate types found for faction [selected_faction]."))
		return

	var/list/type_names = list()
	for(var/type_name in pirate_types)
		type_names += type_name

	var/selected_type = tgui_input_list(user, "Select a pirate type:", "Spawn NPC Pirate - [selected_faction]", type_names)
	if(!selected_type)
		return

	var/mob_path = pirate_types[selected_type]
	if(!mob_path)
		to_chat(user, span_warning("Invalid pirate type selected."))
		return

	// Step 3: Ask about patrol AI setup
	var/setup_patrol = tgui_alert(user, "Set up door-to-door patrol AI? (Requires being on a ship)", "Patrol AI", list("Yes", "No"))

	// Spawn the pirate
	var/mob/living/basic/trooper/pirate/spawned_pirate = new mob_path(spawn_turf)
	if(!spawned_pirate)
		to_chat(user, span_warning("Failed to spawn pirate."))
		return

	// Set up patrol AI if requested
	if(setup_patrol == "Yes")
		// Find the ship we're on
		var/area/current_area = get_area(spawn_turf)
		var/obj/structure/overmap/ship/found_ship = null

		if(current_area)
			for(var/obj/structure/overmap/ship/S in SSovermap.simulated_ships)
				if(!S.shuttle?.shuttle_areas)
					continue
				if(current_area in S.shuttle.shuttle_areas)
					found_ship = S
					break

		if(found_ship)
			// Swap to patrolling AI controller
			var/is_ranged = istype(spawned_pirate.ai_controller, /datum/ai_controller/basic_controller/trooper/ranged)
			var/is_boss = istype(spawned_pirate, /mob/living/basic/trooper/pirate/faction/boss)

			var/new_controller_type
			if(is_boss)
				if(is_ranged)
					new_controller_type = /datum/ai_controller/basic_controller/trooper/ranged/patrolling/boss
				else
					new_controller_type = /datum/ai_controller/basic_controller/trooper/patrolling/boss
			else
				if(is_ranged)
					new_controller_type = /datum/ai_controller/basic_controller/trooper/ranged/patrolling
				else
					new_controller_type = /datum/ai_controller/basic_controller/trooper/patrolling

			// Replace the AI controller
			if(spawned_pirate.ai_controller)
				QDEL_NULL(spawned_pirate.ai_controller)
			spawned_pirate.ai_controller = new new_controller_type(spawned_pirate)

			// Assign patrol path
			if(assign_mob_to_patrol(spawned_pirate, found_ship))
				to_chat(user, span_notice("Spawned [spawned_pirate.name] ([selected_faction] - [selected_type]) with patrol AI on [found_ship.name]."))
			else
				to_chat(user, span_warning("Spawned [spawned_pirate.name] but failed to assign patrol path. Ship may not have enough doors."))
		else
			to_chat(user, span_warning("Spawned [spawned_pirate.name] but could not find a ship to patrol. Standing on a ship area is required for patrol AI."))
	else
		to_chat(user, span_notice("Spawned [spawned_pirate.name] ([selected_faction] - [selected_type]) without patrol AI."))

	message_admins("[key_name_admin(user)] spawned NPC pirate: [spawned_pirate.name] ([selected_faction] - [selected_type]) at [AREACOORD(spawn_turf)]")
	log_admin("[key_name(user)] spawned NPC pirate: [spawned_pirate.name] ([selected_faction] - [selected_type]) at [AREACOORD(spawn_turf)]")
	BLACKBOX_LOG_ADMIN_VERB("Spawn NPC Pirate")

/// Global list of dummy mobs keeping z-levels active for debugging
GLOBAL_LIST_EMPTY(z_level_activator_dummies)

ADMIN_VERB(force_z_level_active, R_DEBUG, "Force Z-Level Active", "Keep a z-level active for AI even while ghosted.", ADMIN_CATEGORY_DEBUG)
	var/mob/admin_mob = user.mob
	var/turf/admin_turf = get_turf(admin_mob)
	var/current_z = admin_turf ? admin_turf.z : null

	var/z_level = input(user, "Which z-level? (Current: [current_z || "none"])", "Force Z-Level Active", current_z) as num|null
	if(!z_level)
		return

	// Check if already active
	var/mob/living/existing = GLOB.z_level_activator_dummies["[z_level]"]
	if(existing)
		// Toggle off
		SSmobs.clients_by_zlevel[z_level] -= existing
		qdel(existing)
		GLOB.z_level_activator_dummies -= "[z_level]"
		to_chat(user, span_adminnotice("Z-level [z_level] no longer forced active."))
		// Put AI back to sleep
		for(var/datum/ai_controller/controller as anything in GLOB.ai_controllers_by_zlevel[z_level])
			controller.set_ai_status(controller.get_expected_ai_status())
		return

	// Create dummy mob to trick the system
	var/turf/target_turf = locate(1, 1, z_level)
	if(!target_turf)
		to_chat(user, span_warning("Invalid z-level."))
		return

	var/mob/living/dummy = new(target_turf)
	dummy.name = "Z-Level Activator (z[z_level])"
	dummy.invisibility = INVISIBILITY_ABSTRACT
	ADD_TRAIT(dummy, TRAIT_NO_TRANSFORM, ADMIN_TRAIT)

	GLOB.z_level_activator_dummies["[z_level]"] = dummy
	SSmobs.clients_by_zlevel[z_level] += dummy

	// Wake up all AI on that z-level
	for(var/datum/ai_controller/controller as anything in GLOB.ai_controllers_by_zlevel[z_level])
		controller.set_ai_status(controller.get_expected_ai_status())

	to_chat(user, span_adminnotice("Z-level [z_level] forced active. Run verb again to deactivate."))
	message_admins("[key_name_admin(user)] forced z-level [z_level] active for AI debugging.")
	BLACKBOX_LOG_ADMIN_VERB("Force Z-Level Active")

/// Global list of room visualization overlays (ship_ref -> list of overlay images)
GLOBAL_LIST_EMPTY(room_visualization_overlays)

/// Distinct colors for room visualization (enough for ~30 rooms)
GLOBAL_LIST_INIT(room_colors, list(
	"#FF0000", // Red
	"#00FF00", // Green
	"#0000FF", // Blue
	"#FFFF00", // Yellow
	"#FF00FF", // Magenta
	"#00FFFF", // Cyan
	"#FF8000", // Orange
	"#8000FF", // Purple
	"#00FF80", // Spring Green
	"#FF0080", // Hot Pink
	"#80FF00", // Lime
	"#0080FF", // Sky Blue
	"#FF8080", // Light Red
	"#80FF80", // Light Green
	"#8080FF", // Light Blue
	"#FFFF80", // Light Yellow
	"#FF80FF", // Light Magenta
	"#80FFFF", // Light Cyan
	"#804000", // Brown
	"#008040", // Teal
	"#400080", // Indigo
	"#408000", // Olive
	"#800040", // Maroon
	"#004080", // Navy
	"#C0C0C0", // Silver
	"#808000", // Dark Yellow
	"#008080", // Dark Cyan
	"#800080", // Dark Magenta
	"#404040", // Dark Gray
	"#C08040", // Tan
))

ADMIN_VERB(visualize_rooms, R_DEBUG, "Visualize Ship Rooms", "Toggle room visualization on/off for the current ship.", ADMIN_CATEGORY_DEBUG)
	var/mob/admin_mob = user.mob
	if(!admin_mob)
		to_chat(user, span_warning("You need a mob to use this."))
		return

	var/turf/admin_turf = get_turf(admin_mob)
	if(!admin_turf)
		to_chat(user, span_warning("Could not find your location."))
		return

	// Find the ship we're on
	var/area/current_area = get_area(admin_turf)
	var/obj/structure/overmap/ship/found_ship = null

	if(current_area)
		for(var/obj/structure/overmap/ship/S in SSovermap.simulated_ships)
			if(!S.shuttle?.shuttle_areas)
				continue
			if(current_area in S.shuttle.shuttle_areas)
				found_ship = S
				break

	if(!found_ship)
		to_chat(user, span_warning("You must be standing on a ship to visualize rooms."))
		return

	var/ship_ref = REF(found_ship)

	// Check if visualization is already active - toggle off
	if(GLOB.room_visualization_overlays[ship_ref])
		clear_room_visualization(ship_ref)
		to_chat(user, span_adminnotice("Room visualization disabled for [found_ship.name]."))
		return

	// Check if room data exists
	if(!GLOB.ship_rooms[ship_ref])
		to_chat(user, span_warning("No room data found for [found_ship.name]. Generating patrol path first..."))
		var/path = generate_ship_patrol_path(found_ship)
		if(!path)
			to_chat(user, span_warning("Failed to generate patrol path/room data."))
			return

	// Visualize the rooms
	var/room_count = visualize_ship_rooms(found_ship)
	to_chat(user, span_adminnotice("Room visualization enabled for [found_ship.name]. [room_count] rooms colored. Run again to disable."))
	message_admins("[key_name_admin(user)] enabled room visualization for [found_ship.name].")
	BLACKBOX_LOG_ADMIN_VERB("Visualize Ship Rooms")

/**
 * Visualize all rooms on a ship by coloring their turfs.
 * Each room gets a unique color overlay.
 *
 * @param target_ship The ship to visualize
 * @return Number of rooms visualized
 */
/proc/visualize_ship_rooms(obj/structure/overmap/ship/target_ship)
	if(!target_ship)
		return 0

	var/ship_ref = REF(target_ship)
	var/list/room_data = GLOB.ship_rooms[ship_ref]
	if(!room_data)
		return 0

	// Clear any existing visualization
	clear_room_visualization(ship_ref)

	// Initialize overlay storage
	GLOB.room_visualization_overlays[ship_ref] = list()

	var/room_index = 0
	var/color_count = length(GLOB.room_colors)

	for(var/room_id in room_data)
		var/list/room = room_data[room_id]
		var/list/turfs = room["turfs"]
		if(!length(turfs))
			continue

		// Pick a color (cycle through if more rooms than colors)
		var/color = GLOB.room_colors[(room_index % color_count) + 1]
		room_index++

		// Create overlay for each turf in the room
		for(var/turf/T as anything in turfs)
			// Create a semi-transparent colored overlay
			var/image/room_overlay = image('icons/effects/effects.dmi', T, "yourfloor") // Use a simple square icon state
			room_overlay.color = color
			room_overlay.alpha = 100 // Semi-transparent
			room_overlay.plane = ABOVE_LIGHTING_PLANE
			room_overlay.layer = ABOVE_MOB_LAYER

			// Add to all clients (admin visibility)
			for(var/client/C in GLOB.clients)
				C.images += room_overlay

			GLOB.room_visualization_overlays[ship_ref] += room_overlay

	return room_index

/**
 * Clear room visualization overlays for a ship.
 *
 * @param ship_ref REF() of the ship
 */
/proc/clear_room_visualization(ship_ref)
	var/list/overlays = GLOB.room_visualization_overlays[ship_ref]
	if(!overlays)
		return

	// Remove overlays from all clients
	for(var/image/overlay as anything in overlays)
		for(var/client/C in GLOB.clients)
			C.images -= overlay
		qdel(overlay)

	GLOB.room_visualization_overlays -= ship_ref

/// Tracks which ships have had their turfs directly colored for room debugging
GLOBAL_LIST_EMPTY(room_colored_ships)

ADMIN_VERB(colorize_rooms_direct, R_DEBUG, "Colorize Ship Rooms (Direct)", "Toggle direct turf coloring for room visualization. Modifies actual turf color var.", ADMIN_CATEGORY_DEBUG)
	var/mob/admin_mob = user.mob
	if(!admin_mob)
		to_chat(user, span_warning("You need a mob to use this."))
		return

	var/turf/admin_turf = get_turf(admin_mob)
	if(!admin_turf)
		to_chat(user, span_warning("Could not find your location."))
		return

	// Find the ship we're on
	var/area/current_area = get_area(admin_turf)
	var/obj/structure/overmap/ship/found_ship = null

	if(current_area)
		for(var/obj/structure/overmap/ship/S in SSovermap.simulated_ships)
			if(!S.shuttle?.shuttle_areas)
				continue
			if(current_area in S.shuttle.shuttle_areas)
				found_ship = S
				break

	if(!found_ship)
		to_chat(user, span_warning("You must be standing on a ship to colorize rooms."))
		return

	var/ship_ref = REF(found_ship)

	// Check if already colored - toggle off
	if(GLOB.room_colored_ships[ship_ref])
		clear_room_colors_direct(ship_ref)
		to_chat(user, span_adminnotice("Room colors cleared for [found_ship.name]."))
		return

	// Generate room data if needed, with colorize = TRUE
	if(GLOB.ship_rooms[ship_ref])
		// Room data exists but turfs aren't colored - color them now
		colorize_ship_rooms_direct(found_ship)
	else
		// Generate fresh with colorize enabled
		to_chat(user, span_notice("Generating room data with colorization..."))
		// First generate the patrol path (which calls compute_ship_rooms)
		var/path = generate_ship_patrol_path(found_ship)
		if(!path)
			to_chat(user, span_warning("Failed to generate patrol path/room data."))
			return
		// Now colorize since compute_ship_rooms was called without colorize flag
		colorize_ship_rooms_direct(found_ship)

	GLOB.room_colored_ships[ship_ref] = TRUE
	var/room_count = length(GLOB.ship_rooms[ship_ref])
	to_chat(user, span_adminnotice("Directly colored [room_count] rooms on [found_ship.name]. Run again to clear."))
	message_admins("[key_name_admin(user)] colorized room turfs for [found_ship.name].")
	BLACKBOX_LOG_ADMIN_VERB("Colorize Ship Rooms Direct")

/**
 * Directly color all room turfs on a ship using turf.color var.
 * Each room gets a unique color.
 *
 * @param target_ship The ship to colorize
 */
/proc/colorize_ship_rooms_direct(obj/structure/overmap/ship/target_ship)
	if(!target_ship)
		log_shuttle("COLORIZE: No target ship!")
		return

	var/ship_ref = REF(target_ship)
	var/list/room_data = GLOB.ship_rooms[ship_ref]
	if(!room_data)
		log_shuttle("COLORIZE: No room data for ship [target_ship]!")
		return

	var/room_index = 0
	var/color_count = length(GLOB.room_colors)

	log_shuttle("COLORIZE: Starting colorization for [target_ship], [length(room_data)] rooms, [color_count] colors available")

	for(var/room_id in room_data)
		var/list/room = room_data[room_id]
		var/list/turfs = room["turfs"]
		if(!length(turfs))
			continue

		// Pick a color (cycle through if more rooms than colors)
		var/room_color = GLOB.room_colors[(room_index % color_count) + 1]
		room_index++

		// Directly set turf color
		for(var/turf/T as anything in turfs)
			T.color = room_color

/**
 * Clear direct turf coloring for a ship.
 *
 * @param ship_ref REF() of the ship
 */
/proc/clear_room_colors_direct(ship_ref)
	var/list/room_data = GLOB.ship_rooms[ship_ref]
	if(!room_data)
		GLOB.room_colored_ships -= ship_ref
		return

	// Reset all turf colors to null
	for(var/room_id in room_data)
		var/list/room = room_data[room_id]
		var/list/turfs = room["turfs"]
		for(var/turf/T as anything in turfs)
			T.color = null

	GLOB.room_colored_ships -= ship_ref
