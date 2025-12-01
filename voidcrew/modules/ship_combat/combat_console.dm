// Ship Combat Console
// Central control interface for ship-to-ship combat
// - Links to missile launchers via multitool
// - Shows camera view of target ship for manual targeting
// - Player clicks on camera to select impact point
// - Commands linked launchers to fire

/obj/machinery/computer/ship_combat
	name = "ship combat console"
	desc = "A tactical combat console for ship-to-ship warfare. Link missile launchers with a multitool and select targets to fire upon."
	icon_screen = "tactical"
	icon_keyboard = "tech_key"
	circuit = /obj/item/circuitboard/computer/ship_combat
	light_color = LIGHT_COLOR_INTENSE_RED

	/// Our ship reference
	var/obj/structure/overmap/ship/current_ship
	/// Currently targeted enemy ship
	var/obj/structure/overmap/ship/target_ship
	/// Currently selected impact turf on target ship
	var/turf/target_turf
	/// List of linked missile launchers (weakrefs)
	var/list/linked_launchers = list()
	/// Camera screen for viewing target ship
	var/atom/movable/screen/map_view/camera/target_cam_screen
	/// Map name for our targeting camera
	var/target_map_name
	/// Is cloaking device active?
	var/cloak_active = FALSE

/obj/machinery/computer/ship_combat/Initialize(mapload)
	. = ..()
	// Initialize targeting camera
	target_map_name = "combat_target_[REF(src)]"
	target_cam_screen = new /atom/movable/screen/map_view/camera()
	target_cam_screen.generate_view(target_map_name)

/obj/machinery/computer/ship_combat/Destroy()
	clear_target()
	for(var/datum/weakref/ref in linked_launchers)
		var/obj/machinery/ship_combat/missile_launcher/launcher = ref.resolve()
		if(launcher)
			launcher.unlink_console()
	linked_launchers.Cut()
	QDEL_NULL(target_cam_screen)
	current_ship = null
	return ..()

/obj/machinery/computer/ship_combat/examine(mob/user)
	. = ..()
	. += span_notice("Linked launchers: [length(linked_launchers)]")
	if(target_ship)
		. += span_notice("Current target: [target_ship.name]")
	else
		. += span_warning("No target selected.")
	if(target_turf)
		. += span_notice("Impact point selected.")

// ========== SHIP CONNECTION ==========

/obj/machinery/computer/ship_combat/proc/attempt_ship_connection()
	var/area/ship_area = get_area(src)
	if(!ship_area)
		return FALSE

	for(var/obj/structure/overmap/ship/S in SSovermap.simulated_ships)
		if(!S.shuttle)
			continue
		for(var/area/A in S.shuttle.shuttle_areas)
			if(A == ship_area)
				current_ship = S
				return TRUE
	return FALSE

// ========== MULTITOOL LINKING ==========

/obj/machinery/computer/ship_combat/multitool_act(mob/living/user, obj/item/multitool/tool)
	. = ..()
	if(!tool.buffer)
		balloon_alert(user, "nothing buffered")
		return TRUE

	if(!istype(tool.buffer, /obj/machinery/ship_combat/missile_launcher))
		balloon_alert(user, "invalid device")
		return TRUE

	var/obj/machinery/ship_combat/missile_launcher/launcher = tool.buffer
	if(launcher in linked_launchers)
		balloon_alert(user, "already linked")
		return TRUE

	// Link the launcher
	if(launcher.link_console(src))
		linked_launchers += WEAKREF(launcher)
		balloon_alert(user, "launcher linked")
		to_chat(user, span_notice("Linked [launcher] to [src]."))
	else
		balloon_alert(user, "link failed")

	return TRUE

// ========== TARGET SELECTION ==========

/// Sets a new target ship
/obj/machinery/computer/ship_combat/proc/set_target_ship(obj/structure/overmap/ship/new_target)
	if(new_target == current_ship)
		return FALSE // Can't target self

	clear_target()
	target_ship = new_target

	if(target_ship)
		RegisterSignal(target_ship, COMSIG_QDELETING, PROC_REF(on_target_deleted))
		update_target_camera()

	return TRUE

/// Clears the current target
/obj/machinery/computer/ship_combat/proc/clear_target()
	if(target_ship)
		UnregisterSignal(target_ship, COMSIG_QDELETING)
	target_ship = null
	target_turf = null
	target_cam_screen?.show_camera_static()

/obj/machinery/computer/ship_combat/proc/on_target_deleted(datum/source)
	SIGNAL_HANDLER
	clear_target()

/// Sets the specific turf to target on the enemy ship
/obj/machinery/computer/ship_combat/proc/set_target_turf(turf/T)
	if(!target_ship)
		return FALSE
	// Verify the turf belongs to the target ship
	var/area/turf_area = get_area(T)
	if(!turf_area || !(turf_area in target_ship.shuttle?.shuttle_areas))
		return FALSE
	target_turf = T
	return TRUE

// ========== TARGET CAMERA ==========

/// Updates the camera view of the target ship
/obj/machinery/computer/ship_combat/proc/update_target_camera()
	if(!target_ship?.shuttle)
		target_cam_screen?.show_camera_static()
		return

	var/list/visible_turfs = list()

	// Get all turfs from the target ship's shuttle areas
	for(var/area/A in target_ship.shuttle.shuttle_areas)
		for(var/turf/T in A)
			visible_turfs += T

	if(!length(visible_turfs))
		target_cam_screen?.show_camera_static()
		return

	var/list/bbox = get_bbox_of_atoms(visible_turfs)
	var/size_x = bbox[3] - bbox[1] + 1
	var/size_y = bbox[4] - bbox[2] + 1

	target_cam_screen.show_camera(visible_turfs, size_x, size_y)

// ========== FIRING ==========

/// Fire at the selected target with all ready launchers
/obj/machinery/computer/ship_combat/proc/fire_all(mob/user)
	if(!target_ship || !target_turf)
		if(user)
			to_chat(user, span_warning("No target selected!"))
		return 0

	var/fired_count = 0
	for(var/datum/weakref/ref in linked_launchers)
		var/obj/machinery/ship_combat/missile_launcher/launcher = ref.resolve()
		if(!launcher)
			linked_launchers -= ref
			continue
		if(launcher.fire(target_turf, target_ship, current_ship, user))
			fired_count++

	// Firing breaks cloak
	if(fired_count > 0 && current_ship)
		SEND_SIGNAL(current_ship, COMSIG_SHIP_WEAPON_FIRED)

	return fired_count

/// Fire a specific launcher
/obj/machinery/computer/ship_combat/proc/fire_launcher(launcher_id, mob/user)
	if(!target_ship || !target_turf)
		if(user)
			to_chat(user, span_warning("No target selected!"))
		return FALSE

	for(var/datum/weakref/ref in linked_launchers)
		var/obj/machinery/ship_combat/missile_launcher/launcher = ref.resolve()
		if(!launcher)
			linked_launchers -= ref
			continue
		if(launcher.launcher_id == launcher_id)
			var/result = launcher.fire(target_turf, target_ship, current_ship, user)
			if(result && current_ship)
				SEND_SIGNAL(current_ship, COMSIG_SHIP_WEAPON_FIRED)
			return result

	return FALSE

// ========== UI ==========

/obj/machinery/computer/ship_combat/ui_interact(mob/user, datum/tgui/ui)
	if(!current_ship && !attempt_ship_connection())
		to_chat(user, span_warning("Unable to connect to ship systems!"))
		return

	ui = SStgui.try_update_ui(user, src, ui)
	if(!ui)
		ui = new(user, src, "ShipCombatConsole", name)
		ui.open()
		ui.set_autoupdate(TRUE)

	// Display target camera to user
	if(target_ship)
		update_target_camera()
		target_cam_screen.display_to(user, ui.window)
	else
		target_cam_screen.show_camera_static()
		target_cam_screen.display_to(user, ui.window)

/obj/machinery/computer/ship_combat/ui_close(mob/user)
	. = ..()
	target_cam_screen?.hide_from(user)

/obj/machinery/computer/ship_combat/ui_data(mob/user)
	var/list/data = list()

	// Our ship info
	data["shipName"] = current_ship?.display_name || "Unknown"
	data["shipIntegrity"] = current_ship?.get_integrity_percent() || 0

	// Target info
	data["hasTarget"] = !!target_ship
	data["targetName"] = target_ship?.display_name
	data["targetIntegrity"] = target_ship?.get_integrity_percent()
	data["hasTargetTurf"] = !!target_turf
	data["targetMapRef"] = target_map_name

	// Available targets (ships in range)
	data["availableTargets"] = list()
	if(current_ship?.close_overmap_objects)
		for(var/obj/structure/overmap/ship/S in current_ship.close_overmap_objects)
			data["availableTargets"] += list(list(
				"name" = S.display_name || S.name,
				"integrity" = S.get_integrity_percent(),
				"ref" = REF(S)
			))

	// Launcher info
	data["launchers"] = list()
	for(var/datum/weakref/ref in linked_launchers)
		var/obj/machinery/ship_combat/missile_launcher/launcher = ref.resolve()
		if(!launcher)
			continue
		data["launchers"] += list(launcher.get_status())

	// Cloak status
	data["cloakActive"] = cloak_active

	return data

/obj/machinery/computer/ship_combat/ui_static_data(mob/user)
	var/list/data = list()
	data["mapRef"] = target_map_name
	return data

/obj/machinery/computer/ship_combat/ui_act(action, list/params, datum/tgui/ui)
	. = ..()
	if(.)
		return

	switch(action)
		// Select a target ship
		if("select_target")
			var/obj/structure/overmap/ship/new_target = locate(params["ref"])
			if(new_target && istype(new_target))
				set_target_ship(new_target)
				return TRUE

		// Clear target
		if("clear_target")
			clear_target()
			return TRUE

		// Fire all launchers
		if("fire_all")
			fire_all(usr)
			return TRUE

		// Fire specific launcher
		if("fire_launcher")
			fire_launcher(params["id"], usr)
			return TRUE

		// Handle click on target camera (set impact point)
		if("set_target_turf")
			var/turf/T = locate(params["ref"])
			if(T && isturf(T))
				set_target_turf(T)
				return TRUE

		// Refresh target camera
		if("refresh_camera")
			update_target_camera()
			return TRUE

// ========== CIRCUIT BOARD ==========

/obj/item/circuitboard/computer/ship_combat
	name = "Ship Combat Console"
	greyscale_colors = CIRCUIT_COLOR_COMMAND
	build_path = /obj/machinery/computer/ship_combat
