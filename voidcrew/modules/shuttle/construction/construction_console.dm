/**
 * Ship Construction Console
 *
 * A console for managing ship construction and modifications.
 * Inherits from the base construction console to provide RCD-based building
 * within shuttle areas and one tile adjacent (for expansion).
 *
 * Features:
 * - Remote construction drone control
 * - RCD building within shuttle and adjacent tiles
 * - Automatic shuttle expansion when building adjacent
 * - Automatic shuttle shrinking when deconstructing
 * - Docking port relocation
 * - Ore silo resource link
 */

/// How much material per RCD unit when using silo link (1/4 sheet per unit)
#define SHIP_RCD_SILO_USE_AMOUNT (SHEET_MATERIAL_AMOUNT / 4)

// ============================================
// Ship Internal RCD - bypasses account checks
// ============================================

/// Ship-specific internal RCD that bypasses ore silo account checks
/// This is needed because remote construction doesn't have a user with an ID card
/obj/item/construction/rcd/internal/ship
	name = "ship internal RCD"
	/// Reference to the ship construction console for drone tracking
	var/obj/machinery/computer/camera_advanced/base_construction/ship/ship_console

/// Override build_delay to cancel if the drone moves
/obj/item/construction/rcd/internal/ship/build_delay(mob/user, delay, atom/target)
	if(delay <= 0)
		return TRUE

	// Get the drone's current location to track movement
	var/mob/eye/camera/remote/drone = ship_console?.eyeobj
	if(!drone)
		return ..()

	var/turf/drone_start_turf = get_turf(drone)

	// Create a callback that checks if the drone moved
	var/datum/callback/drone_check = CALLBACK(src, PROC_REF(check_drone_stationary), drone, drone_start_turf)

	return do_after(user, delay, target, extra_checks = drone_check)

/// Callback to check if drone is still on the same turf
/obj/item/construction/rcd/internal/ship/proc/check_drone_stationary(mob/eye/camera/remote/drone, turf/start_turf)
	if(QDELETED(drone))
		return FALSE
	return get_turf(drone) == start_turf

/// Override to bypass account check when using silo - ships use SILICON_OVERRIDE
/obj/item/construction/rcd/internal/ship/useResource(amount, mob/user)
	if(!silo_mats || !silo_link)
		return ..()

	if(!silo_mats.mat_container)
		if(user)
			balloon_alert(user, "no silo detected!")
		return FALSE

	if(!silo_mats.mat_container.has_enough_of_material(/datum/material/iron, amount * SHIP_RCD_SILO_USE_AMOUNT))
		if(user)
			balloon_alert(user, "not enough silo material!")
		return FALSE

	// Use SILICON_OVERRIDE to bypass account check for ship construction
	var/list/user_data = ID_DATA(user)
	user_data[SILICON_OVERRIDE] = SILICON_OVERRIDE
	silo_mats.use_materials(list(/datum/material/iron = SHIP_RCD_SILO_USE_AMOUNT), multiplier = amount, action = "build", name = "ship construction", user_data = user_data)
	return TRUE

/// Override to bypass account check when checking resources
/obj/item/construction/rcd/internal/ship/checkResource(amount, mob/user)
	if(!silo_mats || !silo_mats.mat_container || !silo_link)
		return ..()

	// Use SILICON_OVERRIDE to bypass account check for ship construction
	var/list/user_data = ID_DATA(user)
	user_data[SILICON_OVERRIDE] = SILICON_OVERRIDE
	if(!silo_mats.can_use_resource(user_data = user_data))
		return FALSE
	. = silo_mats.mat_container.has_enough_of_material(/datum/material/iron, amount * SHIP_RCD_SILO_USE_AMOUNT)
	if(!. && user)
		balloon_alert(user, "low ammo!")
		if(has_ammobar)
			flick("[icon_state]_empty", src)
	return .

/obj/machinery/computer/camera_advanced/base_construction/ship
	name = "ship construction console"
	desc = "A console for managing ship construction and modifications. Control a remote drone to build and modify your ship."
	icon = 'voidcrew/modules/shuttle/icons/computer.dmi'
	icon_screen = "construction"
	icon_keyboard = "power_key"
	circuit = /obj/item/circuitboard/computer/ship_construction
	light_color = LIGHT_COLOR_CYAN
	// Ships don't use camera networks - the drone doesn't need visibility checks
	networks = list()

	/// The ship we are connected to
	var/obj/structure/overmap/ship/current_ship
	/// Status message for last operation
	var/last_operation_message = ""
	/// Whether the last operation succeeded
	var/last_operation_success = TRUE
	/// Console ambient sounds
	var/datum/console_ambience/console_ambience
	/// UI theme preference
	var/theme

// ============================================
// Initialization
// ============================================

/obj/machinery/computer/camera_advanced/base_construction/ship/Initialize(mapload)
	// Create ship-specific internal RCD with silo link capability
	// Uses /ship subtype to bypass ore silo account checks
	var/obj/item/construction/rcd/internal/ship/ship_rcd = new(src)
	ship_rcd.ship_console = src
	internal_rcd = ship_rcd
	internal_rcd.construction_upgrades |= RCD_UPGRADE_SILO_LINK
	// Add the remote materials component to the RCD so it can link to a silo
	// The silo_mats needs to be added after setting the upgrade flag
	internal_rcd.silo_mats = internal_rcd.AddComponent(/datum/component/remote_materials, mapload, FALSE)
	. = ..()
	// Console ambient sounds
	console_ambience = new(src, get_console_ambience_sounds())
	console_ambience.start()

/obj/machinery/computer/camera_advanced/base_construction/ship/Destroy()
	QDEL_NULL(console_ambience)
	return ..()

/// Forward multitool interactions to the internal RCD for silo linking
/obj/machinery/computer/camera_advanced/base_construction/ship/multitool_act(mob/living/user, obj/item/multitool/M)
	. = ..()
	if(!internal_rcd?.silo_mats)
		return .

	// Forward the multitool interaction to the internal RCD's remote_materials component
	if(!QDELETED(M.buffer) && istype(M.buffer, /obj/machinery/ore_silo))
		var/obj/machinery/ore_silo/silo = M.buffer
		if(internal_rcd.silo_mats.silo == silo)
			balloon_alert(user, "already linked")
			to_chat(user, span_warning("[src]'s RCD is already connected to [silo]."))
			return ITEM_INTERACT_SUCCESS

		internal_rcd.silo_mats.disconnect()
		silo.connect_receptacle(internal_rcd.silo_mats, internal_rcd)
		internal_rcd.silo_link = TRUE  // Enable silo link mode
		balloon_alert(user, "linked")
		to_chat(user, span_notice("You connect [src]'s RCD to [silo]."))
		return ITEM_INTERACT_SUCCESS

	return .

/obj/machinery/computer/camera_advanced/base_construction/ship/LateInitialize()
	. = ..()
	attempt_ship_connection()

/obj/machinery/computer/camera_advanced/base_construction/ship/connect_to_shuttle(mapload, obj/docking_port/mobile/voidcrew/port, obj/docking_port/stationary/dock)
	if(!istype(port))
		return
	current_ship = port.current_ship

/obj/machinery/computer/camera_advanced/base_construction/ship/populate_actions_list()
	actions += new /datum/action/innate/construction/ship/configure_mode(src)
	actions += new /datum/action/innate/construction/ship/build(src)
	actions += new /datum/action/innate/construction/ship/deconstruct(src)

/// Override to show UI instead of immediately entering construction mode
/// We skip the camera_advanced parent's attack_hand which would enter camera mode
/obj/machinery/computer/camera_advanced/base_construction/ship/attack_hand(mob/user, list/modifiers)
	// Do basic machinery interaction check (skip camera_advanced parent)
	if(machine_stat & (NOPOWER|BROKEN))
		return
	// Open the UI instead of entering camera mode
	ui_interact(user)

/// Actually enter construction mode - called from UI button
/obj/machinery/computer/camera_advanced/base_construction/ship/proc/enter_construction_mode(mob/user)
	if(!can_use(user))
		return FALSE
	if(isnull(user.client))
		return FALSE
	if(!QDELETED(current_user))
		to_chat(user, span_warning("The console is already in use!"))
		return FALSE

	var/turf/spawn_spot = find_spawn_spot()
	if(!spawn_spot)
		to_chat(user, span_warning("Unable to find a valid location to deploy the construction drone."))
		return FALSE

	if(!CreateEye())
		return FALSE

	give_eye_control(user)
	eyeobj.setLoc(spawn_spot, TRUE)
	return TRUE

/obj/machinery/computer/camera_advanced/base_construction/ship/restock_materials()
	if(internal_rcd)
		internal_rcd.matter = internal_rcd.max_matter

/obj/machinery/computer/camera_advanced/base_construction/ship/find_spawn_spot()
	var/obj/docking_port/mobile/port = get_docking_port()
	if(!port)
		return get_turf(src)

	// Find a valid turf within the shuttle to spawn the drone
	for(var/area/shuttle_area as anything in port.shuttle_areas)
		for(var/turf/T in shuttle_area)
			if(!T.density && !T.is_blocked_turf())
				return T

	return get_turf(src)

/obj/machinery/computer/camera_advanced/base_construction/ship/CreateEye()
	var/turf/spawn_spot = find_spawn_spot()
	if(!spawn_spot)
		return FALSE
	eyeobj = new /mob/eye/camera/remote/base_construction/ship(spawn_spot, src)
	return TRUE

/obj/machinery/computer/camera_advanced/base_construction/ship/can_use(mob/living/user)
	. = ..()
	if(!.)
		return FALSE

	// Must be connected to a ship
	if(!current_ship && !attempt_ship_connection())
		to_chat(user, span_warning("No ship connection established."))
		return FALSE

	// Must be a crew member
	if(!is_crew_member(user))
		to_chat(user, span_warning("Access denied. Crew authorization required."))
		return FALSE

	// Must be docked to use construction features
	if(!can_operate())
		to_chat(user, span_warning("[get_operate_error()]"))
		return FALSE

	return TRUE

// ============================================
// Ship Connection
// ============================================

/**
 * Attempts to connect this console to its containing ship
 */
/obj/machinery/computer/camera_advanced/base_construction/ship/proc/attempt_ship_connection()
	if(current_ship)
		return TRUE

	current_ship = get_ship_from_atom(src)
	return !!current_ship

/**
 * Checks if the given user is a member of this ship's crew
 */
/obj/machinery/computer/camera_advanced/base_construction/ship/proc/is_crew_member(mob/user)
	if(!ismob(user))
		return FALSE
	// Allow admin ghosts with AI interaction enabled
	if(isAdminGhostAI(user))
		return TRUE
	var/mob/living/living_user = user
	if(!istype(living_user) || !living_user.mind)
		return FALSE
	if(!current_ship || !current_ship.ship_team)
		return TRUE // No ship team set up, allow access
	return (living_user.mind in current_ship.ship_team.members)

/**
 * Checks if the console can perform operations (ship must be docked and not force-docked from interdiction)
 */
/obj/machinery/computer/camera_advanced/base_construction/ship/proc/can_operate()
	if(!current_ship)
		return FALSE
	if(current_ship.state != OVERMAP_SHIP_IDLE)
		return FALSE
	// Cannot operate while force-docked from interdiction
	if(!COOLDOWN_FINISHED(current_ship, interdiction_undock_lockout))
		return FALSE
	return TRUE

/**
 * Returns an error message explaining why can_operate() failed
 */
/obj/machinery/computer/camera_advanced/base_construction/ship/proc/get_operate_error()
	if(!current_ship)
		return "No ship connection established."
	if(current_ship.state != OVERMAP_SHIP_IDLE)
		return "Ship must be docked to use construction features."
	if(!COOLDOWN_FINISHED(current_ship, interdiction_undock_lockout))
		return "Construction disabled while docked with another ship."
	return "Unknown error."

/**
 * Gets the docking port for the current ship
 */
/obj/machinery/computer/camera_advanced/base_construction/ship/proc/get_docking_port()
	if(!current_ship)
		return null
	return current_ship.shuttle

// ============================================
// Location Validation
// ============================================

/**
 * Checks if a turf is within the shuttle's areas
 */
/obj/machinery/computer/camera_advanced/base_construction/ship/proc/is_in_shuttle_area(turf/T)
	var/obj/docking_port/mobile/port = get_docking_port()
	if(!port)
		return FALSE

	var/area/target_area = get_area(T)
	return (target_area in port.shuttle_areas)

/**
 * Checks if a turf is adjacent to the shuttle (cardinally)
 */
/obj/machinery/computer/camera_advanced/base_construction/ship/proc/is_adjacent_to_shuttle(turf/T)
	var/obj/docking_port/mobile/port = get_docking_port()
	if(!port)
		return FALSE

	for(var/check_dir in GLOB.cardinals)
		var/turf/adjacent = get_step(T, check_dir)
		if(get_area(adjacent) in port.shuttle_areas)
			return TRUE

	return FALSE

/**
 * Checks if a turf is a valid area type for expansion building
 * (space or planetoid, not ruin, not other shuttle)
 */
/obj/machinery/computer/camera_advanced/base_construction/ship/proc/is_valid_expansion_area(turf/T)
	var/area/target_area = get_area(T)

	// Must be space or planetoid area
	if(!istype(target_area, /area/space) && !istype(target_area, /area/overmap_encounter/planetoid))
		return FALSE

	// NOT a ruin area
	if(istype(target_area, /area/ruin))
		return FALSE

	// NOT another shuttle
	if(isshuttleturf(T))
		return FALSE

	return TRUE

/**
 * Checks if the drone can move to a destination turf
 */
/obj/machinery/computer/camera_advanced/base_construction/ship/proc/can_move_to(turf/T)
	if(!T)
		return FALSE

	// Always allow movement within shuttle
	if(is_in_shuttle_area(T))
		return TRUE

	// Allow movement to adjacent tiles if they're valid expansion areas
	if(is_adjacent_to_shuttle(T) && is_valid_expansion_area(T))
		return TRUE

	return FALSE

/**
 * Checks if building is allowed at a specific turf
 */
/obj/machinery/computer/camera_advanced/base_construction/ship/proc/can_build_at(turf/T)
	if(!T)
		return FALSE

	var/obj/docking_port/mobile/port = get_docking_port()
	if(!port)
		return FALSE

	// Always allow building within shuttle
	if(is_in_shuttle_area(T))
		return TRUE

	// For adjacent tiles, additional checks apply
	if(!is_adjacent_to_shuttle(T))
		return FALSE

	// Must not be a dense turf (wall)
	if(T.density)
		return FALSE

	// Must be a valid expansion area
	if(!is_valid_expansion_area(T))
		return FALSE

	return TRUE

// ============================================
// Shuttle Expansion
// ============================================

/**
 * Expands the shuttle to include a new turf
 */
/obj/machinery/computer/camera_advanced/base_construction/ship/proc/expand_shuttle_to_turf(turf/T, mob/user)
	var/obj/docking_port/mobile/port = get_docking_port()
	if(!port)
		return FALSE

	// Don't expand if already in shuttle
	if(is_in_shuttle_area(T))
		return FALSE

	// Check if adding this turf would exceed max dimensions
	if(!check_expansion_dimensions(T, port, user))
		return FALSE

	// Use the existing expand_shuttle helper
	var/list/turfs = list()
	turfs[T] = TRUE
	expand_shuttle(user, port, turfs, list())

	return TRUE

/**
 * Checks if adding a turf would exceed shuttle dimension limits
 * Returns TRUE if expansion is allowed, FALSE if it would exceed limits
 */
/obj/machinery/computer/camera_advanced/base_construction/ship/proc/check_expansion_dimensions(turf/new_turf, obj/docking_port/mobile/port)
	if(!port)
		return FALSE

	// Get current shuttle bounds (normalize since return_coords order depends on direction)
	var/list/bounds = port.return_coords()
	var/x0 = min(bounds[1], bounds[3])
	var/y0 = min(bounds[2], bounds[4])
	var/x1 = max(bounds[1], bounds[3])
	var/y1 = max(bounds[2], bounds[4])

	// Calculate new bounds if we add this turf
	var/new_x0 = min(x0, new_turf.x)
	var/new_y0 = min(y0, new_turf.y)
	var/new_x1 = max(x1, new_turf.x)
	var/new_y1 = max(y1, new_turf.y)

	// Calculate new dimensions
	var/new_width = new_x1 - new_x0 + 1
	var/new_height = new_y1 - new_y0 + 1

	// Check against voidcrew dimension limits
	// Neither dimension can exceed RESERVE_DOCK_MAX_SIZE_LONG (56)
	if(new_width > RESERVE_DOCK_MAX_SIZE_LONG || new_height > RESERVE_DOCK_MAX_SIZE_LONG)
		return FALSE

	// Only one dimension can exceed RESERVE_DOCK_MAX_SIZE_SHORT (40)
	if(new_width > RESERVE_DOCK_MAX_SIZE_SHORT && new_height > RESERVE_DOCK_MAX_SIZE_SHORT)
		return FALSE

	return TRUE

/**
 * Cleans up empty shuttle turfs after deconstruction
 */
/obj/machinery/computer/camera_advanced/base_construction/ship/proc/cleanup_deconstructed_turfs()
	var/obj/docking_port/mobile/port = get_docking_port()
	if(!port)
		return

	clear_empty_shuttle_turfs(port)

// ============================================
// Mobile Port Relocation
// ============================================

/**
 * Checks if an airlock is on the edge of the shuttle (has adjacent non-shuttle turf)
 */
/obj/machinery/computer/camera_advanced/base_construction/ship/proc/is_edge_airlock(obj/machinery/door/airlock/airlock, obj/docking_port/mobile/port)
	var/turf/airlock_turf = get_turf(airlock)
	if(!airlock_turf)
		return FALSE

	// Check cardinal directions for non-shuttle areas
	for(var/check_dir in GLOB.cardinals)
		var/turf/adjacent = get_step(airlock_turf, check_dir)
		if(!adjacent)
			continue
		var/area/adj_area = get_area(adjacent)
		if(!(adj_area in port.shuttle_areas))
			return TRUE // This airlock is on the edge

	return FALSE

/**
 * Checks if the docking port is on the edge of the shuttle
 * The docking port must have non-shuttle area in the direction it faces for docking to work
 */
/obj/machinery/computer/camera_advanced/base_construction/ship/proc/is_docking_port_on_edge()
	var/obj/docking_port/mobile/port = get_docking_port()
	if(!port)
		return FALSE

	var/turf/port_turf = get_turf(port)
	if(!port_turf)
		return FALSE

	// The docking port's dir points INTO the ship
	// So the docking entrance is in the REVERSE direction
	var/docking_dir = REVERSE_DIR(port.dir)

	// Check if the tile in the docking direction is outside the shuttle
	var/turf/dock_facing_turf = get_step(port_turf, docking_dir)
	if(!dock_facing_turf)
		return TRUE // Edge of map, technically on edge

	var/area/facing_area = get_area(dock_facing_turf)
	return !(facing_area in port.shuttle_areas)

/**
 * Gets a list of all valid edge airlocks on this ship
 */
/obj/machinery/computer/camera_advanced/base_construction/ship/proc/get_valid_airlocks()
	var/list/valid_airlocks = list()

	var/obj/docking_port/mobile/port = get_docking_port()
	if(!port)
		return valid_airlocks

	// Iterate through shuttle areas to find airlocks
	for(var/area/shuttle_area as anything in port.shuttle_areas)
		for(var/obj/machinery/door/airlock/airlock in shuttle_area)
			// Check if airlock is on the edge (has adjacent non-shuttle turf)
			if(is_edge_airlock(airlock, port))
				valid_airlocks += airlock

	return valid_airlocks

/**
 * Resets tiny fans - removes all existing fans and adds new ones to all edge airlocks
 */
/obj/machinery/computer/camera_advanced/base_construction/ship/proc/reset_fans()
	if(!can_operate())
		last_operation_message = "Cannot modify ship while in flight."
		last_operation_success = FALSE
		return FALSE

	var/obj/docking_port/mobile/port = get_docking_port()
	if(!port)
		last_operation_message = "No shuttle detected."
		last_operation_success = FALSE
		return FALSE

	var/fans_removed = 0
	var/fans_added = 0
	var/fans_preserved = 0

	// Remove all existing tiny fans in shuttle areas (except those on blast doors)
	for(var/area/shuttle_area as anything in port.shuttle_areas)
		for(var/obj/structure/fans/tiny/fan in shuttle_area)
			var/turf/fan_turf = get_turf(fan)
			// Preserve fans on blast doors (poddoors)
			var/on_blast_door = FALSE
			for(var/obj/machinery/door/poddoor/door in fan_turf)
				on_blast_door = TRUE
				break
			if(on_blast_door)
				fans_preserved++
				continue
			qdel(fan)
			fans_removed++

	// Add new tiny fans to all edge airlocks
	for(var/obj/machinery/door/airlock/airlock in get_valid_airlocks())
		var/turf/airlock_turf = get_turf(airlock)
		if(!airlock_turf)
			continue
		// Check if there's already a fan here (shouldn't be after removal, but safety check)
		var/has_fan = FALSE
		for(var/obj/structure/fans/tiny/existing in airlock_turf)
			has_fan = TRUE
			break
		if(!has_fan)
			new /obj/structure/fans/tiny(airlock_turf)
			fans_added++

	var/preserved_msg = fans_preserved ? ", [fans_preserved] preserved on blast doors" : ""
	last_operation_message = "Fans reset: [fans_removed] removed, [fans_added] added to edge airlocks[preserved_msg]."
	last_operation_success = TRUE
	return TRUE

/**
 * Gets information about the current docking port location
 */
/obj/machinery/computer/camera_advanced/base_construction/ship/proc/get_current_docking_port_info()
	var/obj/docking_port/mobile/port = get_docking_port()
	if(!port)
		return null

	var/turf/port_turf = get_turf(port)

	return list(
		"x" = port_turf ? port_turf.x : 0,
		"y" = port_turf ? port_turf.y : 0,
		"dir" = dir2text(port.dir),
		"port_direction" = dir2text(port.port_direction)
	)

/**
 * Relocates the docking port to a new airlock
 */
/obj/machinery/computer/camera_advanced/base_construction/ship/proc/relocate_docking_port(obj/machinery/door/airlock/new_airlock)
	if(!can_operate())
		last_operation_message = "Cannot modify ship while in flight."
		last_operation_success = FALSE
		return FALSE

	var/obj/docking_port/mobile/port = get_docking_port()
	if(!port)
		last_operation_message = "No ship connection."
		last_operation_success = FALSE
		return FALSE

	// Validate the airlock is in our shuttle
	var/area/airlock_area = get_area(new_airlock)
	if(!(airlock_area in port.shuttle_areas))
		last_operation_message = "Airlock is not part of this ship."
		last_operation_success = FALSE
		return FALSE

	// Validate it's an edge airlock
	if(!is_edge_airlock(new_airlock, port))
		last_operation_message = "Airlock must be on the edge of the ship."
		last_operation_success = FALSE
		return FALSE

	// Calculate new direction based on adjacent tiles
	var/turf/airlock_turf = get_turf(new_airlock)
	var/outside_dir

	for(var/check_dir in GLOB.cardinals)
		var/turf/adjacent = get_step(airlock_turf, check_dir)
		var/area/adj_area = get_area(adjacent)
		if(!(adj_area in port.shuttle_areas))
			outside_dir = check_dir
			break

	if(!outside_dir)
		last_operation_message = "Could not determine docking direction."
		last_operation_success = FALSE
		return FALSE

	// Calculate new dir (points INTO the ship, away from docking entrance)
	var/new_dir = REVERSE_DIR(outside_dir)

	// Calculate new port_direction (ship-relative direction)
	var/world_port_facing = REVERSE_DIR(new_dir)
	var/angle_diff = SIMPLIFY_DEGREES(dir2angle(world_port_facing) - dir2angle(port.preferred_direction))
	var/new_port_direction = angle2dir(angle_diff)

	// Move the port and update variables
	port.forceMove(airlock_turf)
	port.dir = new_dir
	port.port_direction = new_port_direction

	// Recalculate dimensions
	port.calculate_docking_port_information()

	// Clear cached transit dock so it regenerates with new orientation
	if(!QDELETED(port.assigned_transit))
		qdel(port.assigned_transit, force = TRUE)
		port.assigned_transit = null

	last_operation_message = "Docking port relocated successfully. Changes will take effect on next dock."
	last_operation_success = TRUE
	return TRUE

// ============================================
// TGUI Integration
// ============================================

/obj/machinery/computer/camera_advanced/base_construction/ship/ui_interact(mob/user, datum/tgui/ui)
	if(!current_ship && !attempt_ship_connection())
		to_chat(user, span_warning("No ship connection."))
		return FALSE

	ui = SStgui.try_update_ui(user, src, ui)
	if(!ui)
		ui = new(user, src, "ShipConstructionConsole", name)
		ui.open()
		ui.set_autoupdate(TRUE)

/obj/machinery/computer/camera_advanced/base_construction/ship/ui_data(mob/user)
	var/list/data = list()

	data["canOperate"] = can_operate()
	data["shipState"] = current_ship ? current_ship.state : null
	data["isNotCrew"] = !is_crew_member(user)
	data["lastMessage"] = last_operation_message
	data["lastSuccess"] = last_operation_success

	// RCD info - show silo materials when using silo link, otherwise internal matter
	if(internal_rcd)
		if(internal_rcd.silo_link && internal_rcd.silo_mats?.mat_container)
			// Show silo iron as RCD-equivalent units
			data["rcdMatter"] = internal_rcd.get_silo_iron()
			data["rcdMaxMatter"] = 0  // Silo has no max, hide the max display
			data["usingSilo"] = TRUE
		else
			data["rcdMatter"] = internal_rcd.matter
			data["rcdMaxMatter"] = internal_rcd.max_matter
			data["usingSilo"] = FALSE
	else
		data["rcdMatter"] = 0
		data["rcdMaxMatter"] = 0
		data["usingSilo"] = FALSE

	// Ship dimensions
	var/obj/docking_port/mobile/port = get_docking_port()
	if(port)
		var/list/bounds = port.return_coords()
		var/x0 = min(bounds[1], bounds[3])
		var/y0 = min(bounds[2], bounds[4])
		var/x1 = max(bounds[1], bounds[3])
		var/y1 = max(bounds[2], bounds[4])
		data["shipWidth"] = x1 - x0 + 1
		data["shipHeight"] = y1 - y0 + 1
	else
		data["shipWidth"] = 0
		data["shipHeight"] = 0
	data["maxDimensionLong"] = RESERVE_DOCK_MAX_SIZE_LONG
	data["maxDimensionShort"] = RESERVE_DOCK_MAX_SIZE_SHORT

	// Ship mass info
	if(current_ship)
		data["shipMass"] = current_ship.mass || 0
		data["maxIntegrity"] = current_ship.max_integrity || 0
		data["integrity"] = current_ship.get_integrity_percent()
		data["overhealth"] = current_ship.get_overhealth_percent()
	else
		data["shipMass"] = 0
		data["maxIntegrity"] = 0
		data["integrity"] = 100
		data["overhealth"] = 0

	// Current docking port info
	data["currentPort"] = get_current_docking_port_info()
	data["dockingPortOnEdge"] = is_docking_port_on_edge()

	// Get the current port turf for comparison
	var/turf/current_port_turf = get_turf(port)

	// Available airlocks
	var/list/airlock_data = list()
	for(var/obj/machinery/door/airlock/airlock in get_valid_airlocks())
		var/turf/T = get_turf(airlock)
		var/is_current = (T == current_port_turf)
		var/area/airlock_area = get_area(airlock)
		airlock_data += list(list(
			"name" = airlock.name,
			"ref" = REF(airlock),
			"x" = T ? T.x : 0,
			"y" = T ? T.y : 0,
			"isCurrent" = is_current,
			"areaName" = airlock_area ? airlock_area.name : "Unknown"
		))
	data["airlocks"] = airlock_data

	// Check if user is in construction mode (controlling drone)
	data["isInConstructionMode"] = (eyeobj && user.remote_control == eyeobj)

	// Theme preference
	data["theme"] = theme

	return data

/obj/machinery/computer/camera_advanced/base_construction/ship/ui_static_data(mob/user)
	var/list/data = list()

	data["shipName"] = current_ship ? current_ship.display_name : null

	return data

/obj/machinery/computer/camera_advanced/base_construction/ship/ui_act(action, list/params, datum/tgui/ui, datum/ui_state/state)
	. = ..()
	if(.)
		return

	// Server-side crew check
	if(!is_crew_member(usr))
		say("ERROR: Access denied. Crew authorization required.")
		return

	switch(action)
		if("relocate_port")
			var/obj/machinery/door/airlock/target = locate(params["airlock_ref"])
			if(!target)
				last_operation_message = "Invalid airlock selected."
				last_operation_success = FALSE
				return TRUE
			relocate_docking_port(target)
			return TRUE
		if("clear_message")
			last_operation_message = ""
			return TRUE
		if("enter_construction_mode")
			if(!can_operate())
				to_chat(usr, span_warning("[get_operate_error()]"))
				return TRUE
			enter_construction_mode(usr)
			return TRUE
		if("reset_fans")
			reset_fans()
			return TRUE
		if("setTheme")
			theme = params["theme"]
			return TRUE

	return FALSE
