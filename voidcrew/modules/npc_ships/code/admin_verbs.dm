/**
 * Admin verbs for NPC pirate mob spawning
 */

/// Mapping of faction names to their mob types: the human NPC ship crews (faction_pirate_humans.dm)
GLOBAL_LIST_INIT(npc_pirate_factions, list(
	"Silverscale" = list(
		"Melee (Duelist)" = /mob/living/carbon/human/npc/faction_pirate/silverscale/melee,
		"Ranged (Marksman)" = /mob/living/carbon/human/npc/faction_pirate/silverscale/ranged,
		"Captain (Noble)" = /mob/living/carbon/human/npc/faction_pirate/silverscale/captain,
		"Boss (Highlord)" = /mob/living/carbon/human/npc/faction_pirate/silverscale/boss,
	),
	"Skeleton" = list(
		"Melee (Swashbuckler)" = /mob/living/carbon/human/npc/faction_pirate/skeleton/melee,
		"Ranged (Gunner)" = /mob/living/carbon/human/npc/faction_pirate/skeleton/ranged,
		"Captain" = /mob/living/carbon/human/npc/faction_pirate/skeleton/captain,
		"Boss (Davy Jones)" = /mob/living/carbon/human/npc/faction_pirate/skeleton/boss,
	),
	"Grey Tide" = list(
		"Melee (Grey Tider)" = /mob/living/carbon/human/npc/faction_pirate/grey/melee,
		"Ranged (Gunner)" = /mob/living/carbon/human/npc/faction_pirate/grey/ranged,
		"Captain (Tidemaster)" = /mob/living/carbon/human/npc/faction_pirate/grey/captain,
		"Boss (The Robust One)" = /mob/living/carbon/human/npc/faction_pirate/grey/boss,
	),
	"Lustrous" = list(
		"Melee (Scintillant)" = /mob/living/carbon/human/npc/faction_pirate/lustrous/melee,
		"Ranged (Coruscant)" = /mob/living/carbon/human/npc/faction_pirate/lustrous/ranged,
		"Captain (Radiant)" = /mob/living/carbon/human/npc/faction_pirate/lustrous/captain,
		"Boss (The Radiant One)" = /mob/living/carbon/human/npc/faction_pirate/lustrous/boss,
	),
	"Interdyne" = list(
		"Melee (Enforcer)" = /mob/living/carbon/human/npc/faction_pirate/interdyne/melee,
		"Ranged (Pharmacist)" = /mob/living/carbon/human/npc/faction_pirate/interdyne/ranged,
		"Captain (Director)" = /mob/living/carbon/human/npc/faction_pirate/interdyne/captain,
		"Boss (Director Prime)" = /mob/living/carbon/human/npc/faction_pirate/interdyne/boss,
	),
	"IRS" = list(
		"Melee (Enforcer)" = /mob/living/carbon/human/npc/faction_pirate/irs/melee,
		"Ranged (Agent)" = /mob/living/carbon/human/npc/faction_pirate/irs/ranged,
		"Captain (Head Auditor)" = /mob/living/carbon/human/npc/faction_pirate/irs/captain,
		"Boss (Chief Auditor)" = /mob/living/carbon/human/npc/faction_pirate/irs/boss,
	),
	"Medieval" = list(
		"Melee (Footsoldier)" = /mob/living/carbon/human/npc/faction_pirate/medieval/melee,
		"Ranged (Crossbowman)" = /mob/living/carbon/human/npc/faction_pirate/medieval/ranged,
		"Captain (Warlord)" = /mob/living/carbon/human/npc/faction_pirate/medieval/captain,
		"Boss (The Black Knight)" = /mob/living/carbon/human/npc/faction_pirate/medieval/boss,
	),
))

ADMIN_VERB(spawn_npc_pirate, R_SPAWN|R_DEBUG, "Spawn NPC Pirate", "Spawn an NPC pirate mob, optionally as a boarder hunting the crew of the ship you stand on.", ADMIN_CATEGORY_DEBUG)
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

	// Step 3: Ask whether it boards the ship we're standing on
	var/setup_raid = tgui_alert(user, "Send it after the crew of the ship you're standing on, as a boarder?", "Boarder AI", list("Yes", "No"))

	// Spawn the pirate: a human NPC is built at once, dressed as a boarder if it is boarding
	var/datum/npc_spawn_context/context = new(spawn_turf, null, "ordinary")
	var/mob/living/spawned_pirate
	if(ispath(mob_path, /mob/living/carbon/human/npc))
		var/datum/human_npc_order/order = spawn_human_npc(mob_path, spawn_turf, outfit = (setup_raid == "Yes" ? boarding_outfit_for(mob_path) : null), context = context, immediate = TRUE)
		spawned_pirate = order?.spawned_ref?.resolve()
		if(spawned_pirate)
			spawned_pirate.flags_1 |= ADMIN_SPAWNED_1
	else
		spawned_pirate = spawn_npc_in_zone(mob_path, spawn_turf, context, FALSE)
	if(!spawned_pirate)
		to_chat(user, span_warning("Failed to spawn pirate."))
		return

	// Enlist it in the raid on this ship, exactly as a pod boarder would be (pirate_crew.dm)
	if(setup_raid == "Yes")
		var/obj/structure/overmap/ship/found_ship = pirate_crew_ship_at(spawn_turf)
		if(!found_ship)
			var/area/current_area = get_area(spawn_turf)
			for(var/obj/structure/overmap/ship/candidate in SSovermap.simulated_ships)
				var/list/candidate_areas = candidate.shuttle?.shuttle_areas
				if(candidate_areas && candidate_areas[current_area])
					found_ship = candidate
					break

		if(found_ship)
			if(pirate_crew_enlist_raider(spawned_pirate, found_ship))
				to_chat(user, span_notice("Spawned [spawned_pirate.name] ([selected_faction] - [selected_type]) as a boarder on [found_ship.name]."))
			else
				to_chat(user, span_warning("Spawned [spawned_pirate.name] but it could not join a raid on [found_ship.name]."))
		else
			to_chat(user, span_warning("Spawned [spawned_pirate.name] but could not find a ship here. Stand on a ship to spawn a boarder."))
	else
		to_chat(user, span_notice("Spawned [spawned_pirate.name] ([selected_faction] - [selected_type]) with its own AI."))

	if(!ispath(mob_path, /mob/living/carbon/human/npc))
		context.finalize()
	message_admins("[key_name_admin(user)] spawned NPC pirate: [spawned_pirate.name] ([selected_faction] - [selected_type]) at [AREACOORD(spawn_turf)]")
	log_admin("[key_name(user)] spawned NPC pirate: [spawned_pirate.name] ([selected_faction] - [selected_type]) at [AREACOORD(spawn_turf)]")
	BLACKBOX_LOG_ADMIN_VERB("Spawn NPC Pirate")

/**
 * Force-docks the ship the admin stands on to a live NPC pirate, wherever it is on the overmap:
 * the pirate is moved onto our tile and docked exactly as an interdictor's force dock would
 * (exit-to-exit, reserve berths if that fails), with the same undock lockout on the pirate.
 * For testing boarding fights without the chase and the interdiction.
 */
ADMIN_VERB(force_dock_npc_pirate, R_DEBUG, "Force Dock NPC Pirate", "Force-dock the ship you're standing on to an NPC pirate, ignoring distance.", ADMIN_CATEGORY_DEBUG)
	var/turf/here = get_turf(user.mob)
	var/obj/structure/overmap/ship/our_ship = here && pirate_crew_ship_at(here)
	if(!our_ship)
		to_chat(user, span_warning("Stand on a ship first."))
		return
	if(istype(our_ship, /obj/structure/overmap/ship/npc) && our_ship.ai_controller)
		to_chat(user, span_warning("[our_ship.name] is an NPC ship. Stand on a player ship."))
		return
	if(our_ship.state != OVERMAP_SHIP_FLYING)
		to_chat(user, span_warning("[our_ship.name] has to be flying, not docked or in transit."))
		return

	var/list/choices = list()
	for(var/obj/structure/overmap/ship/npc/pirate as anything in SSnpc_ships.active_ships)
		if(QDELETED(pirate) || pirate == our_ship || pirate.player_controlled || !pirate.ai_controller)
			continue
		if(pirate.state != OVERMAP_SHIP_FLYING || pirate.count_live_crew_aboard() <= 0)
			continue
		choices["[pirate.name] ([length(pirate.tracked_crew)] crew)"] = pirate
	if(!length(choices))
		to_chat(user, span_warning("No flying NPC pirate with a live crew to dock with."))
		return
	var/list/options = list("Random") + choices
	var/picked = tgui_input_list(user, "Which pirate?", "Force Dock NPC Pirate", options, "Random")
	if(!picked)
		return
	var/obj/structure/overmap/ship/npc/pirate = picked == "Random" ? choices[pick(choices)] : choices[picked]
	// Everything can change while the list was open
	if(QDELETED(pirate) || QDELETED(our_ship) || pirate.state != OVERMAP_SHIP_FLYING || our_ship.state != OVERMAP_SHIP_FLYING)
		to_chat(user, span_warning("One of the ships stopped flying. Try again."))
		return

	// Each overmap tile has one ship-to-ship meeting point. A pirate from an earlier dock stays
	// berthed there after we undock (NPC hulls only leave after a few minutes), so move to
	// clear space nearby rather than fail.
	var/turf/spot = get_turf(our_ship)
	if(!pirate_dock_spot_free(spot))
		spot = find_free_pirate_dock_spot(our_ship)
		if(!spot)
			to_chat(user, span_warning("The meeting point here is taken and there's no clear space within 5 tiles. Fly somewhere emptier and try again."))
			return
		our_ship.forceMove(spot)
		our_ship.update_screen()
		our_ship.push_helm_frame()
		to_chat(user, span_notice("The meeting point here was taken, so [our_ship.name] moved to clear space nearby."))
	pirate.forceMove(spot)
	var/result = our_ship.dock_ships_directly(pirate, null, TRUE)
	// The meeting point loads its level on first use; give it a few seconds
	for(var/attempt in 1 to 10)
		if(!result || !findtext(result, "loading"))
			break
		sleep(1 SECONDS)
		if(QDELETED(pirate) || QDELETED(our_ship))
			return
		result = our_ship.dock_ships_directly(pirate, null, TRUE)
	if(result)
		var/fallback = our_ship.dock_ships_to_reserve_ports(pirate, null, TRUE)
		if(fallback)
			to_chat(user, span_warning("Docking failed: [result] Reserve berths: [fallback]"))
			return
		to_chat(user, span_notice("Docked [our_ship.name] to [pirate.name] at separate berths (the airlocks don't touch)."))
	else
		to_chat(user, span_notice("Docked [our_ship.name] to [pirate.name], airlock to airlock."))
	COOLDOWN_START(pirate, interdiction_undock_lockout, INTERDICTOR_FORCE_DOCK_LOCKOUT)
	our_ship.ship_notify("Forced docking with [pirate.display_name].", "DOCKING", SHIP_NOTIFY_NOTICE, 'voidcrew/sound/notify.ogg', 50)
	message_admins("[key_name_admin(user)] force-docked [our_ship.name] to NPC pirate [pirate.name]. [ADMIN_COORDJMP(pirate)]")
	log_admin("[key_name(user)] force-docked [our_ship.name] to NPC pirate [pirate.name]")
	BLACKBOX_LOG_ADMIN_VERB("Force Dock NPC Pirate")

/// Whether the ship-to-ship meeting point on overmap tile `spot`, if it has one, has both berths free
/proc/pirate_dock_spot_free(turf/spot)
	var/obj/structure/overmap/planet/empty/meeting = locate() in spot
	if(!meeting)
		return TRUE
	if(meeting.first_dock_taken || meeting.second_dock_taken || meeting.loading)
		return FALSE
	if(meeting.reserve_dock?.get_docked() || meeting.reserve_dock_secondary?.get_docked())
		return FALSE
	return TRUE

/// The nearest empty overmap tile within 5 of `ship`, on the same side of any zone line
/proc/find_free_pirate_dock_spot(obj/structure/overmap/ship/ship)
	var/turf/origin = get_turf(ship)
	if(!origin)
		return null
	for(var/radius in 1 to 5)
		for(var/turf/open/overmap/candidate in orange(radius, origin))
			if(get_dist(candidate, origin) != radius)
				continue
			if(locate(/obj/structure/overmap) in candidate)
				continue
			if(ship.zone_crossing(origin, candidate))
				continue
			return candidate
	return null

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

// tg idles an AI unless a living mob with a client is in its nearby grid cells. A ghost isn't living and the
// activator dummy has no client, so on a forced-active level the AI would sit idle and never plan.
/datum/ai_controller/should_idle()
	var/turf/pawn_turf = get_turf(pawn)
	if(pawn_turf && GLOB.z_level_activator_dummies["[pawn_turf.z]"])
		return FALSE
	return ..()

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

/**
 * What every NPC pirate crew and each of its members is doing right now: alert state, known
 * hostiles, and per pirate its AI status, behaviours, target, quarry and any door it is breaking.
 * Also written to the shuttle log, so a playtest's report can be read afterwards.
 */
ADMIN_VERB(pirate_crew_status, R_DEBUG, "Pirate Crew Status", "Show what every NPC pirate crew and its members are doing.", ADMIN_CATEGORY_DEBUG)
	var/list/crews = list()
	for(var/key in GLOB.pirate_defending_crews)
		crews += GLOB.pirate_defending_crews[key]
	for(var/key in GLOB.pirate_raiding_crews)
		crews += GLOB.pirate_raiding_crews[key]
	var/list/lines = list()
	for(var/datum/pirate_crew/crew as anything in crews)
		if(!QDELETED(crew))
			lines += crew.status_report()
	if(!length(lines))
		lines += "No pirate crews."
	var/list/shown = list()
	for(var/line in lines)
		shown += html_encode(line)
	to_chat(user, boxed_message(jointext(shown, "<br>")))
	for(var/line in lines)
		log_shuttle("PIRATE_CREW_STATUS: [line]")
	BLACKBOX_LOG_ADMIN_VERB("Pirate Crew Status")
