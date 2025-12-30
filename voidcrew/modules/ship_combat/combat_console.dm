// Ship Weapons System
// Central control interface for ship-to-ship combat
// Two-phase operation:
// 1. TGUI interface for selecting target ship and viewing launcher status
// 2. Camera eye system for targeting specific locations on enemy ship

// ========== CAMERA EYE ==========

/mob/eye/camera/remote/ship_combat
	name = "tactical targeting system"
	visible_to_user = TRUE
	use_visibility = FALSE // Don't check camera network - we view ships directly
	sight = SEE_TURFS | SEE_OBJS // See turfs and objects, not mobs
	/// Reference to our console
	var/obj/machinery/computer/camera_advanced/ship_combat/console
	/// The ship we're allowed to view
	var/obj/structure/overmap/ship/target_ship
	/// Static images applied to interior turfs (non-edge turfs)
	var/list/image/interior_static_images

/mob/eye/camera/remote/ship_combat/Initialize(mapload, obj/machinery/computer/camera_advanced/ship_combat/origin)
	. = ..()
	console = origin

/// Override Destroy to handle non-living mobs (admin ghosts)
/mob/eye/camera/remote/ship_combat/Destroy()
	var/mob/user = user_ref?.resolve()
	if(console && user)
		console.remove_eye_control(user)
	assign_user(null)
	clear_interior_static()
	if(target_ship)
		UnregisterSignal(target_ship, COMSIG_SHIP_HULL_HIT)
	console = null
	target_ship = null
	return ..()

/// Generates static overlay images for all interior turfs (turfs not adjacent to space)
/// Only the ship's exterior outline (turfs touching space) will be visible
/mob/eye/camera/remote/ship_combat/proc/generate_interior_static()
	clear_interior_static()
	if(!target_ship?.shuttle?.shuttle_areas)
		return

	interior_static_images = list()

	// Get the z-level for plane offset calculation
	var/z_level
	for(var/area/ship_area in target_ship.shuttle.shuttle_areas)
		for(var/turf/T in ship_area)
			z_level = T.z
			break
		if(z_level)
			break

	if(!z_level)
		return

	// Create the base static image to clone from
	var/image/base_static = new('icons/effects/cameravis.dmi')
	SET_PLANE_W_SCALAR(base_static, CAMERA_STATIC_PLANE, GET_Z_PLANE_OFFSET(z_level))
	base_static.appearance_flags = RESET_TRANSFORM | RESET_ALPHA | RESET_COLOR | KEEP_APART
	base_static.override = TRUE

	// Iterate through all turfs in the target ship
	for(var/area/ship_area in target_ship.shuttle.shuttle_areas)
		for(var/turf/ship_turf in ship_area)
			// Check if this turf is on the exterior (adjacent to space)
			if(is_exterior_turf(ship_turf))
				continue // Skip exterior turfs - they should be visible

			// This is an interior turf - add static
			var/image/static_image = new /image(base_static)
			static_image.loc = ship_turf
			interior_static_images += static_image

/// Checks if a turf is visible (within COMBAT_CAMERA_VISIBILITY_RANGE tiles of space)
/// When range is 0, only turfs directly adjacent to space are visible
/// When range is 1+, turfs within that many tiles of space are also visible
/mob/eye/camera/remote/ship_combat/proc/is_exterior_turf(turf/T)
	return is_near_space(T, COMBAT_CAMERA_VISIBILITY_RANGE)

/// Checks if a turf is within 'range' tiles of any space turf
/mob/eye/camera/remote/ship_combat/proc/is_near_space(turf/T, range = 0)
	// Check all turfs within range for space
	for(var/turf/check_turf in RANGE_TURFS(range, T))
		if(isspaceturf(check_turf))
			return TRUE
	return FALSE

/// Clears all interior static images
/mob/eye/camera/remote/ship_combat/proc/clear_interior_static()
	var/client/client = GetViewerClient()
	if(client && interior_static_images)
		client.images -= interior_static_images
	interior_static_images = null

/// Applies the interior static images to the current viewer
/mob/eye/camera/remote/ship_combat/proc/apply_interior_static()
	var/client/client = GetViewerClient()
	if(client && interior_static_images)
		client.images += interior_static_images

/// Refreshes static overlay - called when hull damage reveals new areas
/mob/eye/camera/remote/ship_combat/proc/refresh_interior_static()
	var/client/client = GetViewerClient()
	if(!client)
		return
	// Remove old static, regenerate, and reapply
	if(interior_static_images)
		client.images -= interior_static_images
	generate_interior_static()
	if(interior_static_images)
		client.images += interior_static_images

/// Signal handler for when the target ship's hull is hit
/mob/eye/camera/remote/ship_combat/proc/on_target_hull_hit(datum/source, turf/impact_loc)
	SIGNAL_HANDLER
	// Refresh static after a short delay to allow turf destruction to complete
	addtimer(CALLBACK(src, PROC_REF(refresh_interior_static)), 0.5 SECONDS, TIMER_UNIQUE | TIMER_OVERRIDE)

/// Override to allow assigning non-living mobs (admin ghosts)
/mob/eye/camera/remote/ship_combat/assign_user(mob/new_user)
	var/mob/old_user = user_ref?.resolve()
	SEND_SIGNAL(src, COMSIG_REMOTE_CAMERA_ASSIGN_USER, new_user, old_user)
	if(old_user)
		// Reset perspective BEFORE clearing remote_control
		// This prevents TGUI from closing when it checks ui_state
		old_user.reset_perspective(null)
		old_user.remote_control = null
		name = initial(src.name)

		var/client/old_user_client = GetViewerClient()
		if(user_image && old_user_client)
			old_user_client.images -= user_image
		clear_camera_chunks()

	user_ref = WEAKREF(new_user)

	if(new_user)
		new_user.remote_control = src
		new_user.reset_perspective(src)
		name = "Camera Eye ([new_user.name])"

		var/client/new_user_client = GetViewerClient()
		if(user_image && new_user_client)
			new_user_client.images += user_image
		if(use_visibility)
			update_visibility()

/// Override to show turfs and objects but not mobs
/mob/eye/camera/remote/ship_combat/update_remote_sight(mob/user)
	user.set_sight(SEE_TURFS | SEE_OBJS | BLIND)
	return TRUE

/mob/eye/camera/remote/ship_combat/setLoc(turf/destination, force_update = FALSE)
	if(!destination)
		return ..()

	// If no target ship set yet, allow any movement (for initial placement)
	if(!target_ship?.shuttle)
		return ..()

	// Only allow movement within the target ship's areas
	var/area/dest_area = get_area(destination)
	if(dest_area && (dest_area in target_ship.shuttle.shuttle_areas))
		return ..()

	// Block movement outside target ship
	return FALSE

/mob/eye/camera/remote/ship_combat/can_z_move(direction, turf/start, turf/destination, z_move_flags = NONE, mob/living/rider)
	return FALSE // No z-movement for ship targeting

// ========== MAIN CONSOLE ==========

/obj/machinery/computer/camera_advanced/ship_combat
	name = "weapons system"
	desc = "A tactical weapons system for ship-to-ship combat. Link missile launchers with a multitool, select a target ship, then use the targeting system to aim and fire."
	icon = 'voidcrew/modules/shuttle/icons/computer.dmi'
	icon_screen = "targeting"
	icon_keyboard = "syndie_key"
	circuit = /obj/item/circuitboard/computer/ship_combat_console
	light_color = LIGHT_COLOR_INTENSE_RED
	networks = list() // We don't use the camera network
	appearance_flags = KEEP_TOGETHER

	/// Our ship reference
	var/obj/structure/overmap/ship/current_ship
	/// Currently targeted enemy ship (fully locked)
	var/obj/structure/overmap/ship/target_ship
	/// Ship we're currently acquiring a lock on
	var/obj/structure/overmap/ship/targeting_ship
	/// Are we currently acquiring a target lock?
	var/is_targeting = FALSE
	/// World time when targeting started
	var/targeting_start_time
	/// Timer ID for the targeting process
	var/targeting_timer_id
	/// List of linked missile launchers (weakrefs)
	var/list/linked_launchers = list()
	/// List of linked laser turrets (weakrefs)
	var/list/linked_turrets = list()
	/// Linked shield generator (weakref)
	var/datum/weakref/linked_shield_ref
	/// Global power level for all turrets (0.25 to 2.0)
	var/turret_power_level = 1
	/// Is cloaking device active on our ship?
	var/cloak_active = FALSE
	/// The targeting reticle shown on screen
	var/atom/movable/screen/ship_combat/targeting_reticle/reticle
	/// Are we currently in attack mode (camera view)?
	var/attack_mode = FALSE
	/// Currently selected missile type filter (null = fire any)
	var/selected_missile_type
	/// Selected approach direction for missiles and lasers (NORTH/SOUTH/EAST/WEST or null for auto)
	var/selected_approach_direction
	/// UI theme preference
	var/theme

	// ===== INTERDICTOR VARIABLES =====
	/// Linked interdictor machine (weakref)
	var/datum/weakref/linked_interdictor_ref

	// ===== CLOAKING DEVICE VARIABLES =====
	/// Linked cloaking device machine (weakref)
	var/datum/weakref/linked_cloak_ref

	// ===== UI CACHING =====
	/// Cached shield status data (for performance)
	var/list/cached_shield_status
	/// Whether shield cache needs refresh
	var/shield_status_dirty = TRUE
	/// Last time shield status was refreshed (world.time)
	var/shield_status_last_update = 0

	/// Console ambient sounds
	var/datum/console_ambience/console_ambience

	jump_action = null
	off_action = null  // We use TGUI to exit attack mode, not the parent's camera_off action

/obj/machinery/computer/camera_advanced/ship_combat/Initialize(mapload)
	. = ..()
	// Add our custom actions
	actions += new /datum/action/innate/ship_combat/exit_camera(src)  // Exit first so it's easily accessible
	actions += new /datum/action/innate/ship_combat/select_missile(src)
	actions += new /datum/action/innate/ship_combat/select_direction(src)
	actions += new /datum/action/innate/ship_combat/fire_missile(src)
	actions += new /datum/action/innate/ship_combat/fire_all(src)
	actions += new /datum/action/innate/ship_combat/fire_laser(src)
	actions += new /datum/action/innate/ship_combat/fire_all_lasers(src)
	actions += new /datum/action/innate/ship_combat/adjust_laser_power(src)

	reticle = new(null, src)

	// Console ambient sounds
	console_ambience = new(src, get_console_ambience_sounds())
	console_ambience.start()

/obj/machinery/computer/camera_advanced/ship_combat/Destroy()
	QDEL_NULL(console_ambience)
	cancel_targeting()
	// Unlink interdictor
	var/obj/machinery/ship_combat/interdictor/interdictor = linked_interdictor_ref?.resolve()
	if(interdictor)
		interdictor.unlink_console()
	linked_interdictor_ref = null
	// Unlink cloaking device
	var/obj/machinery/ship_combat/cloak_device/cloak = linked_cloak_ref?.resolve()
	if(cloak)
		cloak.unlink_console()
	linked_cloak_ref = null
	clear_target()
	for(var/datum/weakref/ref in linked_launchers)
		var/obj/machinery/ship_combat/missile_launcher/launcher = ref.resolve()
		if(launcher)
			launcher.unlink_console()
	linked_launchers.Cut()
	for(var/datum/weakref/ref in linked_turrets)
		var/obj/machinery/ship_combat/laser_turret/turret = ref.resolve()
		if(turret)
			turret.unlink_console()
	linked_turrets.Cut()
	QDEL_NULL(reticle)
	current_ship = null
	return ..()

/obj/machinery/computer/camera_advanced/ship_combat/examine(mob/user)
	. = ..()
	. += span_notice("Linked launchers: [length(linked_launchers)]")
	. += span_notice("Linked laser turrets: [length(linked_turrets)]")
	var/obj/machinery/ship_combat/interdictor/interdictor = linked_interdictor_ref?.resolve()
	if(interdictor)
		. += span_notice("Linked interdictor: [interdictor.name]")
	else
		. += span_warning("No interdictor linked. Use a multitool to link an interdiction system.")
	var/obj/machinery/ship_combat/cloak_device/cloak = linked_cloak_ref?.resolve()
	if(cloak)
		. += span_notice("Linked cloaking device: [cloak.name]")
	else
		. += span_warning("No cloaking device linked. Use a multitool to link a cloaking device.")
	if(target_ship)
		. += span_notice("Current target: [target_ship.display_name]")
	else
		. += span_warning("No target selected. Use the console to select a target ship.")
	if(!is_crew_member(user))
		. += span_warning("You are not authorized to use this console.")

// ========== GHOST ADMIN OVERRIDES ==========

/obj/machinery/computer/camera_advanced/ship_combat/can_use(mob/user)
	// Allow admin ghosts with AI interact
	if(isAdminGhostAI(user))
		return TRUE
	// Allow the current camera user to keep using the console while in attack mode
	// This prevents process() from kicking them out due to distance checks
	if(attack_mode && current_user == user && eyeobj && user.remote_control == eyeobj)
		return TRUE
	return ..()

/// Override to allow granting actions to non-living mobs (admin ghosts)
/obj/machinery/computer/camera_advanced/ship_combat/GrantActions(mob/user)
	for(var/datum/action/to_grant as anything in actions)
		to_grant.Grant(user)

// ========== SHIP CONNECTION ==========

/obj/machinery/computer/camera_advanced/ship_combat/proc/attempt_ship_connection()
	if(current_ship)
		return TRUE

	current_ship = get_ship_from_atom(src)
	if(!current_ship)
		return FALSE

	RegisterSignal(current_ship, COMSIG_SHIP_CLOAK_CHANGED, PROC_REF(on_cloak_changed))
	RegisterSignal(current_ship, COMSIG_VOIDCREW_SHIP_DOCKED, PROC_REF(on_our_ship_docked))
	return TRUE

/obj/machinery/computer/camera_advanced/ship_combat/proc/on_cloak_changed(datum/source, new_state)
	SIGNAL_HANDLER
	cloak_active = new_state

/// Called when our ship docks - clear all outgoing targeting/locks
/obj/machinery/computer/camera_advanced/ship_combat/proc/on_our_ship_docked(datum/source)
	SIGNAL_HANDLER
	// Clear any in-progress targeting
	if(is_targeting)
		INVOKE_ASYNC(src, PROC_REF(cancel_targeting))
	// Clear any existing target lock
	if(target_ship)
		INVOKE_ASYNC(src, PROC_REF(clear_target))

// ========== CREW MEMBERSHIP CHECK ==========

/// Checks if the given user is a member of this ship's crew (admin ghosts with AI interact bypass)
/obj/machinery/computer/camera_advanced/ship_combat/proc/is_crew_member(mob/user)
	if(!ismob(user))
		return FALSE
	// Admin ghosts with AI interact toggle have access
	if(isAdminGhostAI(user))
		return TRUE
	var/mob/living/living_user = user
	if(!istype(living_user) || !living_user.mind)
		return FALSE
	if(!current_ship?.ship_team)
		return TRUE // No ship team set up, allow access
	return (living_user.mind in current_ship.ship_team.members)

// ========== TGUI INTERFACE ==========

/obj/machinery/computer/camera_advanced/ship_combat/attack_hand(mob/user, list/modifiers)
	// Don't call parent - we handle our own UI
	if(machine_stat & (NOPOWER|BROKEN))
		return

	attempt_ship_connection()

	// Check crew membership
	if(!is_crew_member(user))
		to_chat(user, span_warning("Access denied. Crew authorization required."))
		return

	ui_interact(user)

/obj/machinery/computer/camera_advanced/ship_combat/ui_interact(mob/user, datum/tgui/ui)
	ui = SStgui.try_update_ui(user, src, ui)
	if(!ui)
		ui = new(user, src, "ShipCombatConsole")
		ui.open()

/obj/machinery/computer/camera_advanced/ship_combat/ui_state(mob/user)
	// Allow UI interaction while in camera mode (attack mode)
	// Server-side crew checks are still enforced in ui_act
	if(eyeobj && user.remote_control == eyeobj)
		return GLOB.always_state
	return GLOB.default_state

/obj/machinery/computer/camera_advanced/ship_combat/ui_status(mob/user, datum/ui_state/state)
	// When user is viewing through our camera eye, always allow interaction
	// This bypasses the stored ui_state which may be outdated
	if(eyeobj && user.remote_control == eyeobj)
		return UI_INTERACTIVE
	return ..()  // Fall back to normal state-based checks

/obj/machinery/computer/camera_advanced/ship_combat/ui_data(mob/user)
	var/list/data = list()

	data["connected"] = !!current_ship
	data["ship_name"] = current_ship?.display_name
	data["ship_docked"] = current_ship?.is_in_ship_to_ship_dock()  // Block shields when in ship-to-ship dock (either direction)
	data["cloak_active"] = cloak_active
	data["attack_mode"] = attack_mode
	data["is_in_attack_mode"] = (eyeobj && user.remote_control == eyeobj)
	data["target_name"] = target_ship?.display_name
	data["target_ref"] = target_ship ? REF(target_ship) : null

	// Targeting lock-in-progress data
	data["is_targeting"] = is_targeting
	data["targeting_ship_name"] = targeting_ship?.display_name
	data["targeting_ship_ref"] = targeting_ship ? REF(targeting_ship) : null
	if(is_targeting && targeting_start_time)
		var/elapsed = world.time - targeting_start_time
		var/total_time = COMBAT_TARGETING_TIME // Evaluate macro fully before division
		var/progress = min(100, (elapsed / total_time) * 100)
		var/remaining = max(0, total_time - elapsed)
		data["targeting_progress"] = progress
		data["targeting_time_remaining"] = remaining / 10 // Convert to seconds
	else
		data["targeting_progress"] = 0
		data["targeting_time_remaining"] = 0

	// Get nearby ships within sensor range (3 tiles)
	var/list/nearby_ships = list()
	if(current_ship)
		var/turf/our_turf = get_turf(current_ship)
		if(our_turf)
			for(var/obj/structure/overmap/ship/S in range(COMBAT_TARGETING_RANGE, our_turf))
				if(S == current_ship)
					continue
				// Check if ship is visible (not cloaked)
				if(S.invisibility > INVISIBILITY_NONE)
					continue
				// Calculate distance
				var/turf/target_turf = get_turf(S)
				var/distance = target_turf ? get_dist(our_turf, target_turf) : 0
				nearby_ships += list(list(
					"name" = S.display_name || S.name,
					"ref" = REF(S),
					"shields" = S.shield_health,
					"shields_max" = S.shield_max_health,
					"integrity" = 100,  // Ship integrity - placeholder, ships don't have a direct integrity stat
					"integrity_max" = 100,
					"distance" = distance,
					"speed" = round(S.get_speed(), 0.1),  // Speed in spM (spaces per minute) - same as helm
				))
	data["nearby_ships"] = nearby_ships

	// Get launcher status
	var/list/launchers = list()
	var/ready_count = 0
	var/total_count = 0
	for(var/datum/weakref/ref in linked_launchers)
		var/obj/machinery/ship_combat/missile_launcher/launcher = ref.resolve()
		if(!launcher)
			linked_launchers -= ref
			continue
		total_count++
		var/is_ready = launcher.can_fire()
		if(is_ready)
			ready_count++
		launchers += list(launcher.get_status())
	data["launchers"] = launchers
	data["launchers_ready"] = ready_count
	data["launchers_total"] = total_count

	// Get laser turret status
	var/list/turrets = list()
	var/turrets_ready_count = 0
	var/turrets_total_count = 0
	var/turret_power_available = 0
	var/turret_power_max = 0
	for(var/datum/weakref/ref in linked_turrets)
		var/obj/machinery/ship_combat/laser_turret/turret = ref.resolve()
		if(!turret)
			linked_turrets -= ref
			continue
		turrets_total_count++
		if(turret.can_fire())
			turrets_ready_count++
		turret_power_available += turret.get_cell_charge()
		turret_power_max += turret.get_cell_max()
		turrets += list(turret.get_status())
	data["turrets"] = turrets
	data["turrets_ready"] = turrets_ready_count
	data["turrets_total"] = turrets_total_count
	data["turret_power_level"] = turret_power_level
	data["turret_power_available"] = round(turret_power_available)
	data["turret_power_max"] = round(turret_power_max)

	// Interdictor data - get from linked machine
	var/obj/machinery/ship_combat/interdictor/interdictor = linked_interdictor_ref?.resolve()
	data["interdictor_linked"] = !!interdictor
	if(interdictor)
		var/list/interdictor_status = interdictor.get_status()
		data["interdiction_active"] = interdictor_status["interdiction_active"]
		data["interdiction_warming_up"] = interdictor_status["warming_up"]
		data["interdiction_warmup_progress"] = interdictor_status["warmup_progress"]
		data["interdictor_power_level"] = interdictor_status["power_allocation"]
		data["interdictor_power_draw"] = interdictor_status["power_draw"]
		data["interdictor_target_name"] = interdictor_status["target_name"]
		data["interdictor_target_speed_cap"] = interdictor_status["target_speed_cap"]
		data["interdict_cooldown_active"] = interdictor_status["cooldown_remaining"] > 0
		data["interdict_cooldown_remaining"] = interdictor_status["cooldown_remaining"] * 10  // Convert to deciseconds for UI
		data["interdictor_ready"] = interdictor_status["ready"]
	else
		data["interdiction_active"] = FALSE
		data["interdiction_warming_up"] = FALSE
		data["interdictor_power_level"] = 1
		data["interdict_cooldown_active"] = FALSE
		data["interdict_cooldown_remaining"] = 0
		data["interdictor_ready"] = FALSE

	// Check if WE are being interdicted (for display)
	if(current_ship?.is_interdicted)
		data["being_interdicted"] = TRUE
		data["our_interdiction_strength"] = round(current_ship.interdiction_strength * 100)
	else
		data["being_interdicted"] = FALSE

	// Check target distance for interdiction, force dock, and missile lock
	var/target_in_interdict_range = FALSE
	var/target_in_force_dock_range = FALSE
	var/target_in_missile_range = FALSE
	if(target_ship && current_ship)
		var/turf/our_turf = get_turf(current_ship)
		var/turf/target_turf = get_turf(target_ship)
		if(our_turf && target_turf)
			var/distance = get_dist(our_turf, target_turf)
			target_in_interdict_range = (distance <= INTERDICTOR_RANGE)
			target_in_force_dock_range = (distance <= INTERDICTOR_FORCE_DOCK_RANGE)
			target_in_missile_range = (distance <= COMBAT_MISSILE_LOCK_RANGE)
	data["target_in_interdict_range"] = target_in_interdict_range
	data["target_in_force_dock_range"] = target_in_force_dock_range
	data["target_in_missile_range"] = target_in_missile_range

	// Shield data - aggregate from all generators on the ship
	var/has_any_generators = current_ship && length(current_ship.linked_shield_generators)
	data["shield_linked"] = has_any_generators
	if(has_any_generators)
		var/list/aggregated = get_aggregated_shield_status()
		data["shield_active"] = aggregated["active"]
		data["shield_broken"] = aggregated["broken"]
		data["shield_health"] = aggregated["health"]
		data["shield_max_health"] = aggregated["max_health"]
		data["shield_overhealth"] = aggregated["overhealth"]
		data["shield_power_allocation"] = aggregated["power_allocation"]
		data["shield_regen_rate"] = aggregated["regen_rate"]
		data["shield_power_draw"] = aggregated["power_draw"]
		data["shield_efficiency"] = aggregated["efficiency"]
		data["shield_cooldown_active"] = aggregated["cooldown_active"]
		data["shield_cooldown_remaining"] = aggregated["cooldown_remaining"]
		data["shield_generator_count"] = aggregated["generator_count"]
		data["shield_active_count"] = aggregated["active_count"]
		// Individual generator data with upgrades
		var/list/generators = list()
		for(var/obj/machinery/ship_combat/shield_generator/gen in current_ship.linked_shield_generators)
			var/list/gen_status = gen.get_status()
			gen_status["id"] = REF(gen)
			gen_status["name"] = gen.name
			gen_status["ref"] = REF(gen)
			// Calculate upgrade tiers from stock parts
			var/gen_capacitor_tier = 0
			var/gen_laser_tier = 0
			var/gen_servo_tier = 0
			for(var/datum/stock_part/capacitor/cap in gen.component_parts)
				gen_capacitor_tier += cap.tier
			for(var/datum/stock_part/micro_laser/laser in gen.component_parts)
				gen_laser_tier += laser.tier
			for(var/datum/stock_part/servo/servo in gen.component_parts)
				gen_servo_tier += servo.tier
			gen_status["upgrades"] = list(
				"capacitor_tier" = gen_capacitor_tier,
				"laser_tier" = gen_laser_tier,
				"servo_tier" = gen_servo_tier,
			)
			generators += list(gen_status)
		data["shield_generators"] = generators

	// Cloaking device data - get from linked machine
	var/obj/machinery/ship_combat/cloak_device/cloak = linked_cloak_ref?.resolve()
	data["cloak_linked"] = !!cloak
	// Cloak is unlocked if we have a linked cloak device (no research requirement)
	data["cloak_unlocked"] = !!cloak
	if(cloak)
		// Calculate upgrade tiers from stock parts
		var/capacitor_tier = 0
		var/laser_tier = 0
		var/scanning_tier = 0
		for(var/datum/stock_part/capacitor/cap in cloak.component_parts)
			capacitor_tier += cap.tier
		for(var/datum/stock_part/micro_laser/laser in cloak.component_parts)
			laser_tier += laser.tier
		for(var/datum/stock_part/scanning_module/scanner in cloak.component_parts)
			scanning_tier += scanner.tier

		// Duration remaining
		var/duration_remaining = 0
		if(cloak.cloak_active && cloak.cloak_expire_time > world.time)
			duration_remaining = (cloak.cloak_expire_time - world.time) / 10  // Convert to seconds

		// Cooldown remaining
		var/cooldown_remaining = 0
		if(!COOLDOWN_FINISHED(cloak, recloak_cooldown))
			cooldown_remaining = COOLDOWN_TIMELEFT(cloak, recloak_cooldown) / 10  // Convert to seconds

		// Send as a single cloak_device object matching TGUI CloakDevice type
		data["cloak_device"] = list(
			"active" = cloak.cloak_active,
			"can_activate" = cloak.can_activate_cloak(),
			"duration_remaining" = duration_remaining,
			"duration_max" = cloak.max_cloak_duration / 10,  // Convert to seconds
			"cooldown_remaining" = cooldown_remaining,
			"cooldown_max" = cloak.recloak_delay / 10,  // Convert to seconds
			"upgrades" = list(
				"capacitor_tier" = capacitor_tier,
				"laser_tier" = laser_tier,
				"scanning_tier" = scanning_tier,
			),
		)
	else
		data["cloak_device"] = null

	// Theme preference
	data["theme"] = theme

	return data

/obj/machinery/computer/camera_advanced/ship_combat/ui_act(action, list/params, datum/tgui/ui)
	. = ..()
	if(.)
		return

	// Server-side crew check as safety net
	if(!is_crew_member(ui.user))
		to_chat(ui.user, span_warning("Access denied. Crew authorization required."))
		return TRUE

	switch(action)
		if("select_target")
			var/target_ref = params["ref"]
			if(!target_ref)
				return FALSE
			var/obj/structure/overmap/ship/new_target = locate(target_ref) in SSovermap.simulated_ships
			if(!new_target || new_target == current_ship)
				return FALSE
			set_target_ship(new_target, ui.user)
			return TRUE

		if("clear_target")
			cancel_targeting()
			clear_target()
			return TRUE

		if("cancel_targeting")
			cancel_targeting()
			return TRUE

		if("activate")
			if(!target_ship)
				to_chat(ui.user, span_warning("Select a target first!"))
				return FALSE
			enter_attack_mode(ui.user)
			return TRUE

		if("deactivate")
			exit_attack_mode(ui.user)
			return TRUE

		if("fire_missile")
			fire_one(ui.user)
			return TRUE

		if("fire_all")
			fire_all(ui.user)
			return TRUE

		if("start_interdict")
			var/obj/machinery/ship_combat/interdictor/interdictor = linked_interdictor_ref?.resolve()
			if(!interdictor)
				to_chat(ui.user, span_warning("No interdictor linked! Link an interdiction system with a multitool."))
				return FALSE
			return interdictor.start_interdiction(target_ship, ui.user)

		if("cancel_interdict")
			var/obj/machinery/ship_combat/interdictor/interdictor = linked_interdictor_ref?.resolve()
			if(interdictor)
				interdictor.cancel_interdiction("Cancelled by operator.")
			return TRUE

		if("force_dock")
			var/obj/machinery/ship_combat/interdictor/interdictor = linked_interdictor_ref?.resolve()
			if(!interdictor)
				to_chat(ui.user, span_warning("No interdictor linked!"))
				return FALSE
			return interdictor.force_dock_target(ui.user)

		if("set_interdictor_power")
			var/obj/machinery/ship_combat/interdictor/interdictor = linked_interdictor_ref?.resolve()
			if(!interdictor)
				return FALSE
			var/new_power = params["power"]
			if(!isnum(new_power))
				return FALSE
			// Convert from percentage (25-200) to multiplier (0.25-2)
			interdictor.set_power_allocation(new_power / 100)
			return TRUE

		// Shield power allocation (0-200%) - applies to ship's shared shield pool
		if("set_shield_power")
			if(!current_ship || !length(current_ship.linked_shield_generators))
				return FALSE
			var/new_power = params["power"]
			if(!isnum(new_power))
				return FALSE
			// Convert from percentage (0-200) to multiplier (0-2)
			var/power_mult = new_power / 100
			current_ship.set_shield_power_allocation(power_mult)
			invalidate_shield_cache()  // Force immediate UI refresh
			return TRUE

		// Laser turret power allocation (25-200%) - applies to ALL turrets
		if("set_turret_power")
			var/new_power = params["power"]
			if(!isnum(new_power))
				return FALSE
			// Convert from percentage (25-200) to multiplier (0.25-2) and apply to all turrets
			turret_power_level = clamp(new_power / 100, LASER_POWER_MIN, LASER_POWER_MAX)
			for(var/datum/weakref/ref in linked_turrets)
				var/obj/machinery/ship_combat/laser_turret/turret = ref.resolve()
				if(turret)
					turret.set_power_level(turret_power_level)
			return TRUE

		// Fire one laser at current target
		if("fire_laser")
			fire_laser_one(ui.user)
			return TRUE

		// Fire all lasers at current target
		if("fire_all_lasers")
			fire_all_lasers(ui.user)
			return TRUE

		// Cloaking device controls
		if("cloak_activate")
			var/obj/machinery/ship_combat/cloak_device/cloak = linked_cloak_ref?.resolve()
			if(!cloak)
				to_chat(ui.user, span_warning("No cloaking device linked! Link a cloaking device with a multitool."))
				return FALSE
			return cloak.activate_cloak(ui.user)

		if("cloak_deactivate")
			var/obj/machinery/ship_combat/cloak_device/cloak = linked_cloak_ref?.resolve()
			if(!cloak)
				return FALSE
			return cloak.deactivate_cloak()

		if("setTheme")
			theme = params["theme"]
			return TRUE

	return FALSE

// ========== CAMERA EYE CREATION ==========

/obj/machinery/computer/camera_advanced/ship_combat/CreateEye()
	eyeobj = new /mob/eye/camera/remote/ship_combat(get_turf(src), src)
	return TRUE

/obj/machinery/computer/camera_advanced/ship_combat/give_eye_control(mob/user)
	. = ..()
	// Register click handler
	RegisterSignal(user, COMSIG_MOB_CLICKON, PROC_REF(on_user_click))
	// Show reticle
	if(user.client)
		user.client.screen += reticle
	// Update reticle position
	update_reticle()
	// Show turfs and objects but hide mobs
	user.set_sight(SEE_TURFS | SEE_OBJS | BLIND)

/// Override to allow removing eye control from non-living mobs (admin ghosts)
/obj/machinery/computer/camera_advanced/ship_combat/remove_eye_control(mob/user)
	UnregisterSignal(user, COMSIG_MOB_CLICKON)
	if(user?.client)
		user.client.screen -= reticle
		user.client.view_size.unsupress()

	for(var/datum/action/actions_removed as anything in actions)
		actions_removed.Remove(user)

	// Clear static overlay and unregister hull hit signal before removing control
	var/mob/eye/camera/remote/ship_combat/combat_eye = eyeobj
	if(combat_eye)
		combat_eye.clear_interior_static()
		if(combat_eye.target_ship)
			combat_eye.UnregisterSignal(combat_eye.target_ship, COMSIG_SHIP_HULL_HIT)

	if(eyeobj)
		eyeobj.assign_user(null)
	current_user = null
	attack_mode = FALSE  // Ensure attack mode is reset when eye control is removed

	// Restore interdiction overlay if the player had one
	var/atom/movable/screen/fullscreen/interdiction/interdict_screen = user?.screens["interdiction"]
	if(interdict_screen)
		interdict_screen.start_strobe()

	playsound(src, 'sound/machines/terminal/terminal_off.ogg', 25, FALSE)

// ========== ATTACK MODE ==========

/// Enters attack mode - takes over user's view to target ship
/obj/machinery/computer/camera_advanced/ship_combat/proc/enter_attack_mode(mob/user)
	if(!target_ship)
		to_chat(user, span_warning("No target selected!"))
		return FALSE

	// Check range for missile lock
	if(current_ship)
		var/turf/our_turf = get_turf(current_ship)
		var/turf/target_turf = get_turf(target_ship)
		if(our_turf && target_turf)
			var/distance = get_dist(our_turf, target_turf)
			if(distance > COMBAT_MISSILE_LOCK_RANGE)
				to_chat(user, span_warning("Target is too far for missile lock! Move within [COMBAT_MISSILE_LOCK_RANGE] tiles."))
				return FALSE

	if(!can_use(user))
		return FALSE
	if(isnull(user.client))
		return FALSE
	if(!QDELETED(current_user))
		to_chat(user, span_warning("The targeting system is already in use!"))
		return FALSE

	// Create eye if needed
	if(!eyeobj)
		if(!CreateEye())
			to_chat(user, span_warning("Targeting system malfunction!"))
			return FALSE
		SEND_SIGNAL(src, COMSIG_ADVANCED_CAMERA_EYE_CREATED, eyeobj)

	// Set the eye's target ship
	var/mob/eye/camera/remote/ship_combat/combat_eye = eyeobj
	if(combat_eye)
		combat_eye.target_ship = target_ship
		// Generate static overlay for interior turfs - only ship outline will be visible
		combat_eye.generate_interior_static()
		// Register for hull damage to update static when breaches occur
		combat_eye.RegisterSignal(target_ship, COMSIG_SHIP_HULL_HIT, TYPE_PROC_REF(/mob/eye/camera/remote/ship_combat, on_target_hull_hit))

	// Register for ship movement to detect when ships move out of range
	// Use COMSIG_MOVABLE_MOVED to catch both engine burns AND momentum-based movement
	RegisterSignal(target_ship, COMSIG_MOVABLE_MOVED, PROC_REF(on_target_ship_moved_attack))
	if(current_ship)
		RegisterSignal(current_ship, COMSIG_MOVABLE_MOVED, PROC_REF(on_our_ship_moved_attack))

	// Get the mobile docking port turf for the TARGET ship
	var/turf/target_turf = get_target_ship_port_turf()
	if(!target_turf)
		// Fall back to any turf on the ship
		target_turf = get_target_ship_turf()
	if(!target_turf)
		to_chat(user, span_warning("Cannot locate target ship interior!"))
		return FALSE

	attack_mode = TRUE

	// Hide interdiction overlay while in camera view
	var/atom/movable/screen/fullscreen/interdiction/interdict_screen = user.screens["interdiction"]
	if(interdict_screen)
		animate(interdict_screen)  // Stop any running animations
		interdict_screen.alpha = 0

	// Give control and move to target
	give_eye_control(user)
	eyeobj.setLoc(target_turf, TRUE)

	// Apply static overlay to the user's client
	if(combat_eye)
		combat_eye.apply_interior_static()

	to_chat(user, span_notice("Targeting system active. Move to aim, use action buttons to fire."))
	return TRUE

/// Exits attack mode - returns user to normal view
/obj/machinery/computer/camera_advanced/ship_combat/proc/exit_attack_mode(mob/user)
	attack_mode = FALSE

	// Unregister ship movement signals
	if(target_ship)
		UnregisterSignal(target_ship, COMSIG_MOVABLE_MOVED)
	if(current_ship)
		UnregisterSignal(current_ship, COMSIG_MOVABLE_MOVED)

	if(current_user == user)
		remove_eye_control(user)  // This also restores interdiction overlay
		// Don't call unset_machine() - it would double-call remove_eye_control
		// and end_processing, which can cause UI issues
		end_processing()
	to_chat(user, span_notice("Exiting attack mode."))

// ========== MULTITOOL LINKING ==========

/obj/machinery/computer/camera_advanced/ship_combat/attackby(obj/item/W, mob/user, list/modifiers)
	if(istype(W, /obj/item/multitool))
		var/result = multitool_act(user, W)
		if(result)
			return
	return ..()

/obj/machinery/computer/camera_advanced/ship_combat/multitool_act(mob/living/user, obj/item/multitool/tool)
	if(!istype(tool))
		return NONE

	if(!tool.buffer)
		return ..() // Let parent handle empty buffer

	// Handle list buffer (could be launchers or other things)
	if(islist(tool.buffer))
		var/list/buffer_list = tool.buffer
		if(!length(buffer_list))
			return ..() // Let parent handle empty list

		// Check if this list contains any launchers
		var/has_launchers = FALSE
		for(var/obj/machinery/ship_combat/missile_launcher/L in buffer_list)
			has_launchers = TRUE
			break

		// If no launchers, let parent handle it (could be turrets, etc)
		if(!has_launchers)
			return ..()

		// Process launchers
		var/linked_count = 0
		var/already_linked_count = 0
		for(var/obj/machinery/ship_combat/missile_launcher/launcher in buffer_list)
			// Check if already linked
			var/already_linked = FALSE
			for(var/datum/weakref/ref in linked_launchers)
				if(ref.resolve() == launcher)
					already_linked = TRUE
					already_linked_count++
					break
			if(already_linked)
				continue

			// Link the launcher
			if(launcher.link_console(src))
				linked_launchers += WEAKREF(launcher)
				linked_count++

		// Clear only the launchers from buffer
		for(var/obj/machinery/ship_combat/missile_launcher/launcher in buffer_list)
			buffer_list -= launcher

		if(linked_count > 0)
			balloon_alert(user, "[linked_count] launcher(s) linked")
			to_chat(user, span_notice("Linked [linked_count] launcher(s) to [src]. Total launchers: [length(linked_launchers)]"))
		else if(already_linked_count > 0)
			balloon_alert(user, "all already linked")

		return ITEM_INTERACT_SUCCESS

	// Handle single launcher
	if(istype(tool.buffer, /obj/machinery/ship_combat/missile_launcher))
		var/obj/machinery/ship_combat/missile_launcher/launcher = tool.buffer

		// Check if already linked
		for(var/datum/weakref/ref in linked_launchers)
			if(ref.resolve() == launcher)
				balloon_alert(user, "already linked")
				return ITEM_INTERACT_BLOCKING

		// Link the launcher
		if(launcher.link_console(src))
			linked_launchers += WEAKREF(launcher)
			balloon_alert(user, "launcher linked")
			to_chat(user, span_notice("Linked [launcher] to [src]. Total launchers: [length(linked_launchers)]"))
		else
			balloon_alert(user, "link failed")

		return ITEM_INTERACT_SUCCESS

	// Handle shield generator linking
	if(istype(tool.buffer, /obj/machinery/ship_combat/shield_generator))
		var/obj/machinery/ship_combat/shield_generator/gen = tool.buffer

		// Check if already linked
		var/obj/machinery/ship_combat/shield_generator/current_shield = linked_shield_ref?.resolve()
		if(current_shield == gen)
			balloon_alert(user, "already linked")
			return ITEM_INTERACT_BLOCKING

		// Link the generator
		if(link_shield_generator(gen))
			balloon_alert(user, "shield generator linked")
			to_chat(user, span_notice("Linked [gen] to [src]."))
		else
			balloon_alert(user, "link failed")

		return ITEM_INTERACT_SUCCESS

	// Handle laser turret linking
	if(istype(tool.buffer, /obj/machinery/ship_combat/laser_turret))
		var/obj/machinery/ship_combat/laser_turret/turret = tool.buffer

		// Check if at max turrets
		if(length(linked_turrets) >= LASER_MAX_TURRETS)
			balloon_alert(user, "max turrets reached")
			to_chat(user, span_warning("Cannot link more than [LASER_MAX_TURRETS] laser turrets to one ship!"))
			return ITEM_INTERACT_BLOCKING

		// Check if already linked
		for(var/datum/weakref/ref in linked_turrets)
			if(ref.resolve() == turret)
				balloon_alert(user, "already linked")
				return ITEM_INTERACT_BLOCKING

		// Link the turret
		if(turret.link_console(src))
			linked_turrets += WEAKREF(turret)
			turret.set_power_level(turret_power_level)  // Apply current power level
			balloon_alert(user, "turret linked")
			to_chat(user, span_notice("Linked [turret] to [src]. Total turrets: [length(linked_turrets)]"))
		else
			balloon_alert(user, "link failed")

		return ITEM_INTERACT_SUCCESS

	// Handle interdictor linking
	if(istype(tool.buffer, /obj/machinery/ship_combat/interdictor))
		var/obj/machinery/ship_combat/interdictor/interdictor = tool.buffer

		// Check if already linked
		var/obj/machinery/ship_combat/interdictor/current = linked_interdictor_ref?.resolve()
		if(current == interdictor)
			balloon_alert(user, "already linked")
			return ITEM_INTERACT_BLOCKING

		// Link the interdictor
		if(link_interdictor(interdictor))
			balloon_alert(user, "interdictor linked")
			to_chat(user, span_notice("Linked [interdictor] to [src]."))
		else
			balloon_alert(user, "link failed")

		return ITEM_INTERACT_SUCCESS

	// Handle cloaking device linking
	if(istype(tool.buffer, /obj/machinery/ship_combat/cloak_device))
		var/obj/machinery/ship_combat/cloak_device/cloak = tool.buffer

		// Check if already linked
		var/obj/machinery/ship_combat/cloak_device/current_cloak = linked_cloak_ref?.resolve()
		if(current_cloak == cloak)
			balloon_alert(user, "already linked")
			return ITEM_INTERACT_BLOCKING

		// Link the cloaking device
		if(link_cloak_device(cloak))
			balloon_alert(user, "cloaking device linked")
			to_chat(user, span_notice("Linked [cloak] to [src]."))
		else
			balloon_alert(user, "link failed")

		return ITEM_INTERACT_SUCCESS

	// Not something we handle, let parent try
	return ..()

/// Links an interdictor to this console
/obj/machinery/computer/camera_advanced/ship_combat/proc/link_interdictor(obj/machinery/ship_combat/interdictor/interdictor)
	if(!interdictor)
		return FALSE

	// Unlink any existing interdictor
	var/obj/machinery/ship_combat/interdictor/old = linked_interdictor_ref?.resolve()
	if(old)
		old.unlink_console()

	linked_interdictor_ref = WEAKREF(interdictor)
	interdictor.link_console(src)

	// Link to our ship
	if(current_ship)
		interdictor.link_ship(current_ship)

	return TRUE

/// Links a shield generator to this console
/obj/machinery/computer/camera_advanced/ship_combat/proc/link_shield_generator(obj/machinery/ship_combat/shield_generator/gen)
	if(!gen)
		return FALSE

	// Unlink any existing generator
	var/obj/machinery/ship_combat/shield_generator/old_gen = linked_shield_ref?.resolve()
	if(old_gen)
		old_gen.unlink_console()

	linked_shield_ref = WEAKREF(gen)

	// Link to our ship
	if(current_ship)
		gen.link_ship(current_ship)

	return TRUE

/// Links a cloaking device to this console
/obj/machinery/computer/camera_advanced/ship_combat/proc/link_cloak_device(obj/machinery/ship_combat/cloak_device/cloak)
	if(!cloak)
		return FALSE

	// Unlink any existing cloaking device
	var/obj/machinery/ship_combat/cloak_device/old_cloak = linked_cloak_ref?.resolve()
	if(old_cloak)
		old_cloak.unlink_console()

	linked_cloak_ref = WEAKREF(cloak)

	// Ensure cloak device is connected to the same ship
	if(current_ship && !cloak.linked_ship_ref?.resolve())
		cloak.link_ship(current_ship)

	return TRUE

/// Returns aggregated shield status from the ship's shared shield pool
/// Uses caching for performance - refreshes every 0.5s or when marked dirty
/obj/machinery/computer/camera_advanced/ship_combat/proc/get_aggregated_shield_status()
	if(!current_ship)
		return list()

	// Check if we can use cached data (valid for 0.5 seconds unless marked dirty)
	var/cache_age = world.time - shield_status_last_update
	if(!shield_status_dirty && cached_shield_status && cache_age < 5)  // 0.5 seconds = 5 deciseconds
		return cached_shield_status

	// Refresh the cache
	var/list/result = current_ship.get_shield_status()
	// Add active_count for UI (count of active generators)
	var/active_count = 0
	for(var/obj/machinery/ship_combat/shield_generator/gen in current_ship.linked_shield_generators)
		if(gen.active)
			active_count++
	result["active_count"] = active_count

	// Store in cache
	cached_shield_status = result
	shield_status_dirty = FALSE
	shield_status_last_update = world.time

	return result

/// Marks shield status cache as dirty, forcing refresh on next query
/obj/machinery/computer/camera_advanced/ship_combat/proc/invalidate_shield_cache()
	shield_status_dirty = TRUE

// ========== TARGET SELECTION ==========

/// Starts the targeting process for a new ship (takes time and warns the target)
/obj/machinery/computer/camera_advanced/ship_combat/proc/start_targeting(obj/structure/overmap/ship/new_target, mob/user)
	if(new_target == current_ship)
		if(user)
			to_chat(user, span_warning("Cannot target your own ship!"))
		return FALSE

	// Can't acquire locks while docked
	if(current_ship?.docked)
		if(user)
			to_chat(user, span_warning("Cannot acquire target lock while docked!"))
		return FALSE

	// Cancel any existing targeting
	cancel_targeting()

	// If we already have this ship locked, no need to re-target
	if(target_ship == new_target)
		if(user)
			to_chat(user, span_notice("Already have target lock on [new_target.display_name]."))
		return FALSE

	// Start the targeting process
	targeting_ship = new_target
	is_targeting = TRUE
	targeting_start_time = world.time

	// Play targeting lock sound
	playsound(src, 'voidcrew/sound/machines/interdictor/startup2.ogg', 30, FALSE)
	playsound(src, 'voidcrew/sound/machines/interdictor/terminal.ogg', 30, FALSE)

	// Register for target deletion and movement during targeting
	RegisterSignal(targeting_ship, COMSIG_QDELETING, PROC_REF(on_targeting_ship_deleted))
	RegisterSignal(targeting_ship, COMSIG_VOIDCREW_SHIP_MOVED, PROC_REF(on_targeting_ship_moved))
	if(current_ship)
		RegisterSignal(current_ship, COMSIG_VOIDCREW_SHIP_MOVED, PROC_REF(on_our_ship_moved_targeting))

	// Warn the target ship
	SEND_SIGNAL(targeting_ship, COMSIG_SHIP_BEING_TARGETED, current_ship)
	targeting_ship.ship_announce("Hostile ship acquiring weapons lock!", "WARNING", FALSE, sound('sound/effects/alert.ogg'))

	// Notify our crew
	if(user)
		to_chat(user, span_notice("Acquiring target lock on [targeting_ship.display_name]... ([COMBAT_TARGETING_TIME / 10] seconds)"))

	// Start the targeting timer
	targeting_timer_id = addtimer(CALLBACK(src, PROC_REF(complete_targeting), user), COMBAT_TARGETING_TIME, TIMER_STOPPABLE)

	return TRUE

/// Called when targeting timer completes - finalizes the target lock
/obj/machinery/computer/camera_advanced/ship_combat/proc/complete_targeting(mob/user)
	if(!is_targeting || !targeting_ship)
		return FALSE

	var/obj/structure/overmap/ship/locked_target = targeting_ship

	// Clean up targeting state
	UnregisterSignal(targeting_ship, list(COMSIG_QDELETING, COMSIG_VOIDCREW_SHIP_MOVED))
	if(current_ship)
		UnregisterSignal(current_ship, COMSIG_VOIDCREW_SHIP_MOVED)
	is_targeting = FALSE
	targeting_ship = null
	targeting_timer_id = null
	targeting_start_time = null

	// Clear any previous target
	clear_target()

	// Set the new target
	target_ship = locked_target
	RegisterSignal(target_ship, COMSIG_QDELETING, PROC_REF(on_target_deleted))

	// Set the eye's allowed ship if it exists
	var/mob/eye/camera/remote/ship_combat/combat_eye = eyeobj
	if(combat_eye)
		combat_eye.target_ship = target_ship

	// Notify the target ship that lock is complete (this breaks their cloak)
	SEND_SIGNAL(target_ship, COMSIG_SHIP_TARGETING_STOPPED, current_ship)
	SEND_SIGNAL(target_ship, COMSIG_SHIP_WEAPONS_LOCKED, current_ship)

	// Notify our crew
	if(user)
		to_chat(user, span_danger("Target lock acquired on [target_ship.display_name]!"))
	current_ship?.ship_announce("Target lock acquired: [target_ship.display_name]")

	return TRUE

/// Cancels an in-progress targeting attempt
/obj/machinery/computer/camera_advanced/ship_combat/proc/cancel_targeting()
	if(!is_targeting)
		return

	// Stop the timer
	if(targeting_timer_id)
		deltimer(targeting_timer_id)
		targeting_timer_id = null

	// Unregister movement signal from our ship
	if(current_ship)
		UnregisterSignal(current_ship, COMSIG_VOIDCREW_SHIP_MOVED)

	// Notify the target they're no longer being targeted
	if(targeting_ship)
		SEND_SIGNAL(targeting_ship, COMSIG_SHIP_TARGETING_STOPPED, current_ship)
		targeting_ship.ship_announce("Hostile targeting signal lost.", "Threat Alert")
		UnregisterSignal(targeting_ship, list(COMSIG_QDELETING, COMSIG_VOIDCREW_SHIP_MOVED))

	is_targeting = FALSE
	targeting_ship = null
	targeting_start_time = null

/// Called when the target ship moves during targeting - check range
/obj/machinery/computer/camera_advanced/ship_combat/proc/on_targeting_ship_moved(datum/source)
	SIGNAL_HANDLER
	check_targeting_range()

/// Called when our ship moves during targeting - check range
/obj/machinery/computer/camera_advanced/ship_combat/proc/on_our_ship_moved_targeting(datum/source)
	SIGNAL_HANDLER
	check_targeting_range()

/// Checks if targeting should be cancelled due to range
/obj/machinery/computer/camera_advanced/ship_combat/proc/check_targeting_range()
	if(!is_targeting || !targeting_ship || !current_ship)
		return

	var/turf/our_turf = get_turf(current_ship)
	var/turf/target_turf = get_turf(targeting_ship)
	if(!our_turf || !target_turf)
		return

	var/distance = get_dist(our_turf, target_turf)
	if(distance > COMBAT_TARGETING_RANGE)
		var/target_name = targeting_ship.display_name
		cancel_targeting()
		if(current_user)
			to_chat(current_user, span_warning("Target lock lost - [target_name] moved out of sensor range!"))
		current_ship?.ship_announce("Target lock failed - target escaped sensor range.", "Targeting System")

/// Called when the target ship moves during attack mode - check range
/obj/machinery/computer/camera_advanced/ship_combat/proc/on_target_ship_moved_attack(datum/source)
	SIGNAL_HANDLER
	check_attack_range()

/// Called when our ship moves during attack mode - check range
/obj/machinery/computer/camera_advanced/ship_combat/proc/on_our_ship_moved_attack(datum/source)
	SIGNAL_HANDLER
	check_attack_range()

/// Checks if attack mode should end due to ships moving out of range
/obj/machinery/computer/camera_advanced/ship_combat/proc/check_attack_range()
	if(!attack_mode || !target_ship || !current_ship)
		return

	var/turf/our_turf = get_turf(current_ship)
	var/turf/target_turf = get_turf(target_ship)
	if(!our_turf || !target_turf)
		return

	var/distance = get_dist(our_turf, target_turf)
	if(distance > COMBAT_MISSILE_LOCK_RANGE)
		var/target_name = target_ship.display_name
		if(current_user)
			to_chat(current_user, span_warning("Target lock lost - [target_name] moved out of weapons range!"))
			INVOKE_ASYNC(src, PROC_REF(exit_attack_mode), current_user)
		current_ship?.ship_announce("Weapons lock lost - target escaped range.", "Targeting System")

/// Called when the ship we're targeting is deleted mid-lock
/obj/machinery/computer/camera_advanced/ship_combat/proc/on_targeting_ship_deleted(datum/source)
	SIGNAL_HANDLER
	cancel_targeting()
	if(current_user)
		to_chat(current_user, span_danger("Target lost!"))

/// Sets a new target ship (legacy - now just calls start_targeting)
/obj/machinery/computer/camera_advanced/ship_combat/proc/set_target_ship(obj/structure/overmap/ship/new_target, mob/user)
	return start_targeting(new_target, user)

/// Gets a turf at the target ship's mobile docking port
/obj/machinery/computer/camera_advanced/ship_combat/proc/get_target_ship_port_turf()
	if(!target_ship?.shuttle)
		return null
	return get_turf(target_ship.shuttle)

/// Gets any valid turf on the target ship (fallback)
/obj/machinery/computer/camera_advanced/ship_combat/proc/get_target_ship_turf()
	if(!target_ship?.shuttle?.shuttle_areas)
		return null

	for(var/area/A in target_ship.shuttle.shuttle_areas)
		for(var/turf/T in A)
			if(!isclosedturf(T))
				return T
	return null

/// Clears the current target
/obj/machinery/computer/camera_advanced/ship_combat/proc/clear_target()
	if(target_ship)
		UnregisterSignal(target_ship, COMSIG_QDELETING)
	target_ship = null

	var/mob/eye/camera/remote/ship_combat/combat_eye = eyeobj
	if(combat_eye)
		combat_eye.target_ship = null

/obj/machinery/computer/camera_advanced/ship_combat/proc/on_target_deleted(datum/source)
	SIGNAL_HANDLER
	clear_target()
	if(current_user)
		to_chat(current_user, span_danger("Target destroyed!"))
		exit_attack_mode(current_user)

// ========== CLICK HANDLING ==========

/obj/machinery/computer/camera_advanced/ship_combat/proc/on_user_click(mob/source, atom/target, turf/location, control, params, mouseparams)
	SIGNAL_HANDLER

	// Only handle clicks in the game window, not UI
	if(!location)
		return NONE

	// Check if this turf is on the target ship
	if(!target_ship?.shuttle)
		return NONE

	var/area/click_area = get_area(location)
	if(!click_area || !(click_area in target_ship.shuttle.shuttle_areas))
		return NONE

	// Move the eye to the clicked location
	if(eyeobj)
		eyeobj.setLoc(location, TRUE)
		update_reticle()

	return NONE // Don't block the click

/obj/machinery/computer/camera_advanced/ship_combat/proc/update_reticle()
	if(!reticle || !eyeobj)
		return
	// Reticle follows the eye
	reticle.screen_loc = "CENTER"

// ========== FIRING ==========

/// Get the turf the user is currently targeting (where the eye is)
/obj/machinery/computer/camera_advanced/ship_combat/proc/get_target_turf()
	if(!eyeobj)
		return null
	return get_turf(eyeobj)

/// Fire at the current target location with all missiles from all launchers
/obj/machinery/computer/camera_advanced/ship_combat/proc/fire_all(mob/user)
	if(!attack_mode)
		to_chat(user, span_warning("Enter attack mode first!"))
		return 0

	var/turf/target_turf = get_target_turf()
	if(!target_ship || !target_turf)
		if(user)
			to_chat(user, span_warning("No target selected!"))
		return 0

	// Build list of staggered SPAWN positions (missiles converge on same target)
	// Spread missiles in a grid pattern at their spawn point
	var/list/stagger_offsets = list(
		list(0, 0),    // center
		list(-3, 0),   // left
		list(3, 0),    // right
		list(0, 3),    // up
		list(-3, 3),   // up-left
		list(3, 3),    // up-right
		list(0, -3),   // down
		list(-3, -3),  // down-left
		list(3, -3),   // down-right
	)

	var/fired_count = 0
	var/offset_index = 1

	// Fire ALL missiles from ALL launchers
	for(var/datum/weakref/ref in linked_launchers)
		var/obj/machinery/ship_combat/missile_launcher/launcher = ref.resolve()
		if(!launcher)
			linked_launchers -= ref
			continue

		// Keep firing from this launcher until it's empty
		while(launcher.can_fire())
			// Get spawn offset for this missile
			var/list/offset = stagger_offsets[offset_index]

			// Fire at the SAME target, but with staggered spawn positions
			if(launcher.fire(target_turf, target_ship, current_ship, user, offset[1], offset[2], selected_approach_direction))
				fired_count++

			// Cycle through offsets
			offset_index++
			if(offset_index > length(stagger_offsets))
				offset_index = 1

	// Firing breaks cloak
	if(fired_count > 0 && current_ship)
		SEND_SIGNAL(current_ship, COMSIG_SHIP_WEAPON_FIRED)

	if(user && fired_count > 0)
		to_chat(user, span_danger("Fired [fired_count] missile[fired_count > 1 ? "s" : ""]!"))

	return fired_count

/// Fire the first ready launcher (optionally filtered by selected missile type)
/obj/machinery/computer/camera_advanced/ship_combat/proc/fire_one(mob/user)
	if(!attack_mode)
		to_chat(user, span_warning("Enter attack mode first!"))
		return FALSE

	var/turf/target_turf = get_target_turf()
	if(!target_ship || !target_turf)
		if(user)
			to_chat(user, span_warning("No target selected!"))
		return FALSE

	for(var/datum/weakref/ref in linked_launchers)
		var/obj/machinery/ship_combat/missile_launcher/launcher = ref.resolve()
		if(!launcher)
			linked_launchers -= ref
			continue
		if(!launcher.can_fire())
			continue
		// Filter by selected missile type if set
		if(selected_missile_type && launcher.loaded_missile)
			if(launcher.loaded_missile["payload_type"] != selected_missile_type)
				continue // Missile type doesn't match
		if(launcher.fire(target_turf, target_ship, current_ship, user, approach_dir = selected_approach_direction))
			// Firing breaks cloak
			if(current_ship)
				SEND_SIGNAL(current_ship, COMSIG_SHIP_WEAPON_FIRED)
			if(user)
				to_chat(user, span_danger("Missile away!"))
			return TRUE

	if(user)
		if(selected_missile_type)
			to_chat(user, span_warning("No [selected_missile_type] missiles ready to fire!"))
		else
			to_chat(user, span_warning("No launchers ready to fire!"))
	return FALSE

/// Fire one ready laser turret at the current target location
/obj/machinery/computer/camera_advanced/ship_combat/proc/fire_laser_one(mob/user)
	if(!attack_mode)
		to_chat(user, span_warning("Enter attack mode first!"))
		return FALSE

	var/turf/target_turf = get_target_turf()
	if(!target_ship || !target_turf)
		if(user)
			to_chat(user, span_warning("No target selected!"))
		return FALSE

	for(var/datum/weakref/ref in linked_turrets)
		var/obj/machinery/ship_combat/laser_turret/turret = ref.resolve()
		if(!turret)
			linked_turrets -= ref
			continue
		if(!turret.can_fire())
			continue
		if(turret.fire(target_turf, target_ship, current_ship, user, approach_direction = selected_approach_direction))
			return TRUE

	if(user)
		to_chat(user, span_warning("No laser turrets ready to fire!"))
	return FALSE

/// Fire all ready laser turrets as a single combined beam at the current target
/// Combines damage from all ready turrets into one powerful multi-beam shot
/obj/machinery/computer/camera_advanced/ship_combat/proc/fire_all_lasers(mob/user)
	if(!attack_mode)
		to_chat(user, span_warning("Enter attack mode first!"))
		return 0

	var/turf/target_turf = get_target_turf()
	if(!target_ship || !target_turf)
		if(user)
			to_chat(user, span_warning("No target selected!"))
		return 0

	// Collect all ready turrets and calculate combined damage
	var/list/ready_turrets = list()
	var/combined_damage = 0
	for(var/datum/weakref/ref in linked_turrets)
		var/obj/machinery/ship_combat/laser_turret/turret = ref.resolve()
		if(!turret)
			linked_turrets -= ref
			continue
		if(!turret.can_fire())
			continue
		ready_turrets += turret
		combined_damage += turret.get_effective_damage()

	if(!length(ready_turrets))
		if(user)
			to_chat(user, span_warning("No laser turrets ready to fire!"))
		return 0

	var/turret_count = length(ready_turrets)
	var/is_multi_beam = turret_count > 1

	// Use the first turret to actually fire, but drain power and start cooldown on ALL turrets
	var/obj/machinery/ship_combat/laser_turret/primary_turret = ready_turrets[1]

	// Drain power, start cooldown, and create visual effects on all turrets
	for(var/obj/machinery/ship_combat/laser_turret/turret in ready_turrets)
		var/power_needed = turret.get_power_per_shot()
		turret.cell?.use(power_needed)
		COOLDOWN_START(turret, fire_cooldown, turret.get_effective_cooldown())
		turret.update_appearance()
		// Create visual effects at each turret (always single beam at source turrets)
		// The multi-beam effect is only shown at the target ship
		new /obj/effect/temp_visual/turret_muzzle_flash(get_turf(turret), turret.dir)
		new /obj/effect/temp_visual/turret_laser_visual(get_turf(turret), turret.dir, FALSE)

	// Fire a single combined beam from the primary turret
	// Skip the normal fire() power/cooldown handling since we did it manually
	new /obj/effect/ship_laser_beam(
		get_turf(primary_turret),
		target_turf,
		target_ship,
		current_ship,
		combined_damage,
		primary_turret.power_level,
		is_multi_beam,
		selected_approach_direction,
	)

	// Create visual beam on the overmap between ships (only if not on same tile)
	if(current_ship && target_ship && get_turf(current_ship) != get_turf(target_ship))
		current_ship.Beam(
			target_ship,
			icon_state = "beam_omni",
			icon = 'icons/obj/weapons/guns/projectiles_tracer.dmi',
			emissive = TRUE,
			time = 0.5 SECONDS,
		)

	// Play sound (extrarange and ignore_walls so it's audible from inside the ship)
	playsound(primary_turret, 'sound/items/weapons/beam_sniper.ogg', 100, TRUE, extrarange = 50, ignore_walls = TRUE)

	// Visual feedback
	primary_turret.visible_message(span_danger("[turret_count > 1 ? "Multiple turrets fire" : "[primary_turret] fires"] a [is_multi_beam ? "concentrated" : ""] laser beam!"))

	// Firing breaks cloak
	if(current_ship)
		SEND_SIGNAL(current_ship, COMSIG_SHIP_WEAPON_FIRED)
		SEND_SIGNAL(current_ship, COMSIG_SHIP_LASER_FIRED, primary_turret, target_ship)

	if(user)
		to_chat(user, span_danger("Fired [turret_count] turret[turret_count > 1 ? "s" : ""] as combined beam! ([round(combined_damage)] damage)"))

	return turret_count

/// Opens a power level selection for laser turrets
/obj/machinery/computer/camera_advanced/ship_combat/proc/open_laser_power_radial(mob/user)
	var/list/options = list("25%", "50%", "75%", "100%", "125%", "150%", "175%", "200%")

	var/choice = tgui_input_list(user, "Select laser power level:", "Laser Power", options)
	if(!choice)
		return

	var/new_level = text2num(choice) / 100
	turret_power_level = clamp(new_level, LASER_POWER_MIN, LASER_POWER_MAX)

	// Apply to all linked turrets
	for(var/datum/weakref/ref in linked_turrets)
		var/obj/machinery/ship_combat/laser_turret/turret = ref.resolve()
		if(turret)
			turret.set_power_level(turret_power_level)

	to_chat(user, span_notice("Laser power set to [choice]. Damage: [round(LASER_DAMAGE_BASE * turret_power_level)], Power/shot: [round(LASER_POWER_BASE * turret_power_level)]W"))

/// Opens a selection menu to choose which missile type to fire
/obj/machinery/computer/camera_advanced/ship_combat/proc/open_missile_radial(mob/user)
	// Get available missile types from loaded launchers
	var/list/available_types = list()
	for(var/datum/weakref/ref in linked_launchers)
		var/obj/machinery/ship_combat/missile_launcher/launcher = ref.resolve()
		if(!launcher?.loaded_missile)
			continue
		var/payload_type = launcher.loaded_missile["payload_type"]
		if(payload_type && !(payload_type in available_types))
			available_types += payload_type

	if(!length(available_types))
		to_chat(user, span_warning("No missiles loaded in any launcher!"))
		return

	// Build selection options - capitalize for display
	var/list/options = list("Any")
	for(var/payload_type in available_types)
		options += capitalize(payload_type)

	// Use tgui_input_list which works reliably with camera eye control
	var/choice = tgui_input_list(user, "Select missile type to fire:", "Missile Selection", options)
	if(!choice)
		return

	if(choice == "Any")
		selected_missile_type = null
		to_chat(user, span_notice("Will fire any available missile."))
	else
		// Convert back to lowercase payload_type
		selected_missile_type = lowertext(choice)
		to_chat(user, span_notice("Will fire [choice] missiles."))

/// Gets an icon state for a payload type
/obj/machinery/computer/camera_advanced/ship_combat/proc/get_missile_type_icon(payload_type)
	switch(payload_type)
		if("light")
			return "low_yield_rocket"
		if("standard")
			return "84mm-heap"
		if("heavy")
			return "srm-8"
		if("EMP")
			return "disruptor-ammo"
		if("chemical")
			return "84mm-heap"
	return "84mm-heap"

/// Opens a selection menu to choose missile approach direction
/obj/machinery/computer/camera_advanced/ship_combat/proc/open_direction_radial(mob/user)
	var/list/options = list("Auto", "North", "South", "East", "West")

	// Use tgui_input_list which works reliably with camera eye control
	var/choice = tgui_input_list(user, "Select direction missiles approach from:", "Missile Direction", options)
	if(!choice)
		return

	switch(choice)
		if("Auto")
			selected_approach_direction = null
			to_chat(user, span_notice("Missiles will approach from the closest edge to target."))
		if("North")
			selected_approach_direction = NORTH
			to_chat(user, span_notice("Missiles will approach from the North."))
		if("South")
			selected_approach_direction = SOUTH
			to_chat(user, span_notice("Missiles will approach from the South."))
		if("East")
			selected_approach_direction = EAST
			to_chat(user, span_notice("Missiles will approach from the East."))
		if("West")
			selected_approach_direction = WEST
			to_chat(user, span_notice("Missiles will approach from the West."))

/// Get status of all linked launchers
/obj/machinery/computer/camera_advanced/ship_combat/proc/get_launcher_status()
	var/list/status = list()
	var/ready_count = 0
	var/total_count = 0

	for(var/datum/weakref/ref in linked_launchers)
		var/obj/machinery/ship_combat/missile_launcher/launcher = ref.resolve()
		if(!launcher)
			linked_launchers -= ref
			continue
		total_count++
		if(launcher.can_fire())
			ready_count++

	status["ready"] = ready_count
	status["total"] = total_count
	return status

// ========== TARGETING RETICLE ==========

/atom/movable/screen/ship_combat
	icon = 'icons/hud/screen_gen.dmi'
	mouse_opacity = MOUSE_OPACITY_TRANSPARENT

/atom/movable/screen/ship_combat/targeting_reticle
	name = "targeting reticle"
	icon_state = "selector"
	screen_loc = "CENTER"
	color = "#ff0000"
	plane = HUD_PLANE
	layer = ABOVE_MOB_LAYER

/atom/movable/screen/ship_combat/targeting_reticle/Initialize(mapload, obj/machinery/computer/camera_advanced/ship_combat/console)
	. = ..()
	// Add a pulsing effect
	animate(src, alpha = 128, time = 0.5 SECONDS, loop = -1)
	animate(alpha = 255, time = 0.5 SECONDS)

// ========== ACTION BUTTONS ==========

/datum/action/innate/ship_combat
	button_icon = 'icons/mob/actions/actions_mecha.dmi'
	check_flags = NONE
	var/obj/machinery/computer/camera_advanced/ship_combat/console

/datum/action/innate/ship_combat/New(Target)
	. = ..()
	console = Target

/datum/action/innate/ship_combat/IsAvailable(feedback = FALSE)
	if(!console || QDELETED(console))
		return FALSE
	if(!console.attack_mode)
		return FALSE
	return ..()

// Select missile type
/datum/action/innate/ship_combat/select_missile
	name = "Select Missile"
	desc = "Select which type of missile to fire from loaded launchers."
	button_icon_state = "mech_cycle_equip_off"

/datum/action/innate/ship_combat/select_missile/Activate()
	if(!console || !ismob(owner))
		return
	console.open_missile_radial(owner)

// Select approach direction for missiles and lasers
/datum/action/innate/ship_combat/select_direction
	name = "Select Direction"
	desc = "Select which direction missiles and lasers will approach from."
	button_icon_state = "change_direction"
	button_icon = 'voidcrew/icons/mob/actions/ship_combat.dmi'

/datum/action/innate/ship_combat/select_direction/Activate()
	if(!console || !ismob(owner))
		return
	console.open_direction_radial(owner)

// Fire single missile
/datum/action/innate/ship_combat/fire_missile
	name = "Fire Missile"
	desc = "Fire one missile at the targeted location."
	button_icon_state = "missile"
	button_icon = 'voidcrew/icons/mob/actions/ship_combat.dmi'

/datum/action/innate/ship_combat/fire_missile/Activate()
	if(!console || !ismob(owner))
		return
	console.fire_one(owner)

// Fire all missiles
/datum/action/innate/ship_combat/fire_all
	name = "Fire All Missiles"
	desc = "Fire all ready missiles at the targeted location."
	button_icon = 'voidcrew/icons/mob/actions/ship_combat.dmi'
	button_icon_state = "missiles"

/datum/action/innate/ship_combat/fire_all/Activate()
	if(!console || !ismob(owner))
		return
	console.fire_all(owner)

// Fire single laser
/datum/action/innate/ship_combat/fire_laser
	name = "Fire Laser"
	desc = "Fire one laser turret at the targeted location."
	button_icon_state = "laser"
	button_icon = 'voidcrew/icons/mob/actions/ship_combat.dmi'

/datum/action/innate/ship_combat/fire_laser/Activate()
	if(!console || !ismob(owner))
		return
	console.fire_laser_one(owner)

// Fire all lasers
/datum/action/innate/ship_combat/fire_all_lasers
	name = "Fire All Lasers"
	desc = "Fire all ready laser turrets at the targeted location."
	button_icon_state = "lasers"
	button_icon = 'voidcrew/icons/mob/actions/ship_combat.dmi'

/datum/action/innate/ship_combat/fire_all_lasers/Activate()
	if(!console || !ismob(owner))
		return
	console.fire_all_lasers(owner)

// Adjust laser power
/datum/action/innate/ship_combat/adjust_laser_power
	name = "Laser Power"
	desc = "Adjust power level for all laser turrets. Higher power = more damage but more power usage."
	button_icon_state = "power"
	button_icon = 'voidcrew/icons/mob/actions/ship_combat.dmi'

/datum/action/innate/ship_combat/adjust_laser_power/Activate()
	if(!console || !ismob(owner))
		return
	console.open_laser_power_radial(owner)

// Exit camera mode - doesn't inherit attack_mode check from parent
/datum/action/innate/ship_combat/exit_camera
	name = "Exit Camera"
	desc = "Exit the targeting camera and return to normal view."
	button_icon_state = "camera_off"
	button_icon = 'icons/mob/actions/actions_silicon.dmi'

/datum/action/innate/ship_combat/exit_camera/IsAvailable(feedback = FALSE)
	// Override parent's check - exit should always be available when granted
	if(!console || QDELETED(console))
		return FALSE
	return TRUE

/datum/action/innate/ship_combat/exit_camera/Activate()
	if(!console || !ismob(owner))
		return
	console.exit_attack_mode(owner)

// ========== CIRCUIT BOARD ==========

/obj/item/circuitboard/computer/ship_combat_console
	name = "Weapons System"
	greyscale_colors = CIRCUIT_COLOR_COMMAND
	build_path = /obj/machinery/computer/camera_advanced/ship_combat
