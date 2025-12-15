// Ship Combat Console
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

/mob/eye/camera/remote/ship_combat/Initialize(mapload, obj/machinery/computer/camera_advanced/ship_combat/origin)
	. = ..()
	console = origin

/// Override Destroy to handle non-living mobs (admin ghosts)
/mob/eye/camera/remote/ship_combat/Destroy()
	var/mob/user = user_ref?.resolve()
	if(console && user)
		console.remove_eye_control(user)
	assign_user(null)
	console = null
	target_ship = null
	return ..()

/// Override to allow assigning non-living mobs (admin ghosts)
/mob/eye/camera/remote/ship_combat/assign_user(mob/new_user)
	var/mob/old_user = user_ref?.resolve()
	SEND_SIGNAL(src, COMSIG_REMOTE_CAMERA_ASSIGN_USER, new_user, old_user)
	if(old_user)
		old_user.remote_control = null
		old_user.reset_perspective(null)
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
	name = "ship combat console"
	desc = "A tactical combat console for ship-to-ship warfare. Link missile launchers with a multitool, select a target ship, then use the targeting system to aim and fire."
	icon_screen = "generic"
	icon_keyboard = "generic_key"
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
	/// Selected direction for missile approach (NORTH, SOUTH, EAST, WEST, or null for auto)
	var/selected_missile_direction

	// ===== INTERDICTOR VARIABLES =====
	/// Is interdiction currently active (slowing target)?
	var/interdiction_active = FALSE
	/// The ship currently being interdicted (slowed)
	var/obj/structure/overmap/ship/interdicted_ship
	/// Cooldown between interdiction attempts
	COOLDOWN_DECLARE(interdict_cooldown)
	/// The beam effect showing the interdiction link on the overmap
	var/datum/beam/interdiction_beam

	// ===== RESEARCH INTEGRATION =====
	/// Linked techweb for research upgrades
	var/datum/techweb/linked_techweb
	/// Cached list of unlocked upgrades
	var/list/unlocked_upgrades

	// ===== DEBUG MODE (Admin only) =====
	/// Debug mode - bypasses research requirements
	var/debug_mode = FALSE
	/// Debug: Force unlock interdictor
	var/debug_interdictor = FALSE
	/// Debug: Force unlock shields
	var/debug_shields = FALSE

	jump_action = null

/obj/machinery/computer/camera_advanced/ship_combat/Initialize(mapload)
	. = ..()
	// Add our custom actions
	actions += new /datum/action/innate/ship_combat/select_missile(src)
	actions += new /datum/action/innate/ship_combat/select_direction(src)
	actions += new /datum/action/innate/ship_combat/fire_missile(src)
	actions += new /datum/action/innate/ship_combat/fire_all(src)
	actions += new /datum/action/innate/ship_combat/fire_laser(src)
	actions += new /datum/action/innate/ship_combat/fire_all_lasers(src)
	actions += new /datum/action/innate/ship_combat/adjust_laser_power(src)

	reticle = new(null, src)

/obj/machinery/computer/camera_advanced/ship_combat/Destroy()
	cancel_targeting()
	cancel_interdiction()
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
	if(target_ship)
		. += span_notice("Current target: [target_ship.display_name]")
	else
		. += span_warning("No target selected. Use the console to select a target ship.")
	if(!is_crew_member(user))
		. += span_warning("You are not authorized to use this console.")
	if(linked_techweb)
		. += span_notice("Connected to research network.")
	else
		. += span_warning("Not connected to research network. Use a multitool to link to an R&D server.")

// ========== RESEARCH INTEGRATION ==========

/// Disconnects from the current research network
/obj/machinery/computer/camera_advanced/ship_combat/unsync_research_servers()
	if(linked_techweb)
		linked_techweb.connected_machines -= src
		linked_techweb = null
		unlocked_upgrades = null


/// Updates the list of unlocked upgrades from the linked techweb
/obj/machinery/computer/camera_advanced/ship_combat/proc/update_unlocked_upgrades()
	unlocked_upgrades = list()
	if(!linked_techweb)
		return

	// Check for combat console upgrade nodes
	var/list/upgrade_nodes = list(
		TECHWEB_NODE_SHIP_COMBAT_INTERDICTOR,
		TECHWEB_NODE_SHIP_COMBAT_ADVANCED,
		TECHWEB_NODE_SHIP_COMBAT_SHIELDS,
	)

	for(var/node_id in linked_techweb.researched_nodes)
		if(node_id in upgrade_nodes)
			unlocked_upgrades += node_id

/// Checks if a specific upgrade is unlocked
/obj/machinery/computer/camera_advanced/ship_combat/proc/has_upgrade(upgrade_id)
	// Debug mode overrides
	if(debug_mode)
		if(upgrade_id == TECHWEB_NODE_SHIP_COMBAT_INTERDICTOR && debug_interdictor)
			return TRUE
		if(upgrade_id == TECHWEB_NODE_SHIP_COMBAT_SHIELDS && debug_shields)
			return TRUE
	update_unlocked_upgrades()
	return (upgrade_id in unlocked_upgrades)

// ========== GHOST ADMIN OVERRIDES ==========

/obj/machinery/computer/camera_advanced/ship_combat/can_use(mob/user)
	// Allow admin ghosts with AI interact
	if(isAdminGhostAI(user))
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

	var/area/ship_area = get_area(src)
	if(!ship_area)
		return FALSE

	for(var/obj/structure/overmap/ship/S in SSovermap.simulated_ships)
		if(!S.shuttle)
			continue
		for(var/area/A in S.shuttle.shuttle_areas)
			if(A == ship_area)
				current_ship = S
				RegisterSignal(current_ship, COMSIG_SHIP_CLOAK_CHANGED, PROC_REF(on_cloak_changed))
				return TRUE
	return FALSE

/obj/machinery/computer/camera_advanced/ship_combat/proc/on_cloak_changed(datum/source, new_state)
	SIGNAL_HANDLER
	cloak_active = new_state

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
	return GLOB.default_state

/obj/machinery/computer/camera_advanced/ship_combat/ui_data(mob/user)
	var/list/data = list()

	data["connected"] = !!current_ship
	data["ship_name"] = current_ship?.display_name
	data["cloak_active"] = cloak_active
	data["target_name"] = target_ship?.display_name
	data["target_ref"] = target_ship ? REF(target_ship) : null

	// Targeting lock-in-progress data
	data["is_targeting"] = is_targeting
	data["targeting_ship_name"] = targeting_ship?.display_name
	data["targeting_ship_ref"] = targeting_ship ? REF(targeting_ship) : null
	if(is_targeting && targeting_start_time)
		var/elapsed = world.time - targeting_start_time
		var/progress = min(100, (elapsed / COMBAT_TARGETING_TIME) * 100)
		var/remaining = max(0, COMBAT_TARGETING_TIME - elapsed)
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
				nearby_ships += list(list(
					"name" = S.display_name || S.name,
					"ref" = REF(S),
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
	for(var/datum/weakref/ref in linked_turrets)
		var/obj/machinery/ship_combat/laser_turret/turret = ref.resolve()
		if(!turret)
			linked_turrets -= ref
			continue
		turrets_total_count++
		if(turret.can_fire())
			turrets_ready_count++
		turrets += list(turret.get_status())
	data["turrets"] = turrets
	data["turrets_ready"] = turrets_ready_count
	data["turrets_total"] = turrets_total_count
	data["turret_power_level"] = turret_power_level

	// Interdictor data
	data["interdiction_active"] = interdiction_active
	data["interdict_cooldown_active"] = !COOLDOWN_FINISHED(src, interdict_cooldown)
	data["interdict_cooldown_remaining"] = COOLDOWN_TIMELEFT(src, interdict_cooldown)
	data["interdictor_unlocked"] = has_upgrade(TECHWEB_NODE_SHIP_COMBAT_INTERDICTOR)

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
	data["shield_unlocked"] = has_upgrade(TECHWEB_NODE_SHIP_COMBAT_SHIELDS)
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

	// Debug mode data (admin only)
	var/is_admin = check_rights_for(user?.client, R_ADMIN, FALSE)
	data["is_admin"] = is_admin
	data["debug_mode"] = debug_mode
	data["debug_interdictor"] = debug_interdictor
	data["debug_shields"] = debug_shields

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

		if("fire_missile")
			fire_one(ui.user)
			return TRUE

		if("fire_all")
			fire_all(ui.user)
			return TRUE

		if("start_interdict")
			return start_interdiction(ui.user)

		if("cancel_interdict")
			cancel_interdiction()
			return TRUE

		if("force_dock")
			return force_dock_target(ui.user)

		// Shield power allocation (0-200%) - applies to ALL generators
		if("set_shield_power")
			if(!current_ship || !length(current_ship.linked_shield_generators))
				return FALSE
			var/new_power = params["power"]
			if(!isnum(new_power))
				return FALSE
			// Convert from percentage (0-200) to multiplier (0-2) and apply to all generators
			var/power_mult = new_power / 100
			for(var/obj/machinery/ship_combat/shield_generator/gen in current_ship.linked_shield_generators)
				gen.set_power_allocation(power_mult)
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

		// Debug actions (admin only)
		if("toggle_debug")
			if(!check_rights_for(ui.user?.client, R_ADMIN, FALSE))
				return FALSE
			debug_mode = !debug_mode
			return TRUE

		if("toggle_debug_interdictor")
			if(!check_rights_for(ui.user?.client, R_ADMIN, FALSE))
				return FALSE
			debug_interdictor = !debug_interdictor
			return TRUE

		if("toggle_debug_shields")
			if(!check_rights_for(ui.user?.client, R_ADMIN, FALSE))
				return FALSE
			debug_shields = !debug_shields
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

	if(eyeobj)
		eyeobj.assign_user(null)
	current_user = null

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

	// Get the mobile docking port turf for the TARGET ship
	var/turf/target_turf = get_target_ship_port_turf()
	if(!target_turf)
		// Fall back to any turf on the ship
		target_turf = get_target_ship_turf()
	if(!target_turf)
		to_chat(user, span_warning("Cannot locate target ship interior!"))
		return FALSE

	attack_mode = TRUE

	// Close all UIs for this user before entering camera mode
	SStgui.close_user_uis(user)

	// Give control and move to target
	give_eye_control(user)
	eyeobj.setLoc(target_turf, TRUE)

	to_chat(user, span_notice("Targeting system active. Move to aim, use action buttons to fire."))
	return TRUE

/// Exits attack mode - returns user to normal view
/obj/machinery/computer/camera_advanced/ship_combat/proc/exit_attack_mode(mob/user)
	attack_mode = FALSE
	if(current_user == user)
		remove_eye_control(user)
		unset_machine()
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

	// Handle techweb linking for research integration
	if(!QDELETED(tool.buffer) && istype(tool.buffer, /datum/techweb))
		if(linked_techweb)
			if(linked_techweb == tool.buffer)
				say("Already linked to this research network!")
				return ITEM_INTERACT_SUCCESS
			unsync_research_servers()

		linked_techweb = tool.buffer
		linked_techweb.connected_machines += src
		update_unlocked_upgrades()
		say("Linked to research network!")
		return ITEM_INTERACT_SUCCESS

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

	// Not something we handle, let parent try
	return ..()

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

/// Returns aggregated shield status from all generators on the ship
/obj/machinery/computer/camera_advanced/ship_combat/proc/get_aggregated_shield_status()
	var/list/result = list()
	if(!current_ship || !length(current_ship.linked_shield_generators))
		return result

	var/total_health = 0
	var/total_max_health = 0
	var/total_overhealth = 0
	var/total_regen = 0
	var/total_power_draw = 0
	var/any_active = FALSE
	var/all_broken = TRUE
	var/any_cooldown = FALSE
	var/max_cooldown_remaining = 0
	var/power_allocation = 0
	var/efficiency_sum = 0
	var/generator_count = 0
	var/active_count = 0

	for(var/obj/machinery/ship_combat/shield_generator/gen in current_ship.linked_shield_generators)
		generator_count++
		var/list/status = gen.get_status()
		total_health += status["health"]
		total_max_health += status["max_health"]
		total_overhealth += status["overhealth"]
		total_regen += status["regen_rate"]
		total_power_draw += status["power_draw"]
		efficiency_sum += status["efficiency"]
		power_allocation = status["power_allocation"]  // Use last one (they should all be the same)

		if(status["active"])
			any_active = TRUE
			active_count++
		if(!status["broken"])
			all_broken = FALSE
		if(status["cooldown_active"])
			any_cooldown = TRUE
			max_cooldown_remaining = max(max_cooldown_remaining, status["cooldown_remaining"])

	result["active"] = any_active
	result["broken"] = all_broken && generator_count > 0
	result["health"] = round(total_health)
	result["max_health"] = round(total_max_health)
	result["overhealth"] = round(total_overhealth)
	result["power_allocation"] = power_allocation
	result["regen_rate"] = round(total_regen, 0.1)
	result["power_draw"] = round(total_power_draw)
	result["efficiency"] = generator_count > 0 ? round(efficiency_sum / generator_count) : 0
	result["cooldown_active"] = any_cooldown
	result["cooldown_remaining"] = max_cooldown_remaining
	result["generator_count"] = generator_count
	result["active_count"] = active_count

	return result

// ========== TARGET SELECTION ==========

/// Starts the targeting process for a new ship (takes time and warns the target)
/obj/machinery/computer/camera_advanced/ship_combat/proc/start_targeting(obj/structure/overmap/ship/new_target, mob/user)
	if(new_target == current_ship)
		if(user)
			to_chat(user, span_warning("Cannot target your own ship!"))
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

	// Register for target deletion and movement during targeting
	RegisterSignal(targeting_ship, COMSIG_QDELETING, PROC_REF(on_targeting_ship_deleted))
	RegisterSignal(targeting_ship, COMSIG_VOIDCREW_SHIP_MOVED, PROC_REF(on_targeting_ship_moved))
	if(current_ship)
		RegisterSignal(current_ship, COMSIG_VOIDCREW_SHIP_MOVED, PROC_REF(on_our_ship_moved_targeting))

	// Warn the target ship
	SEND_SIGNAL(targeting_ship, COMSIG_SHIP_BEING_TARGETED, current_ship)
	targeting_ship.ship_announce("WARNING: HOSTILE TARGETING DETECTED! A ship is acquiring weapons lock!", "THREAT ALERT", FALSE, sound('sound/effects/alert.ogg'))

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

	// Notify the target ship that lock is complete
	SEND_SIGNAL(target_ship, COMSIG_SHIP_TARGETING_STOPPED, current_ship)
	target_ship.ship_announce("WEAPONS LOCK CONFIRMED! Hostile ship has missile lock on this vessel!", "TARGET LOCK", FALSE, sound('sound/effects/alert.ogg'))

	// Notify our crew
	if(user)
		to_chat(user, span_danger("Target lock acquired on [target_ship.display_name]! Use 'Attack' to enter targeting mode."))
	current_ship?.ship_announce("Target lock acquired: [target_ship.display_name]", "Targeting System")

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
			if(launcher.fire(target_turf, target_ship, current_ship, user, offset[1], offset[2], selected_missile_direction))
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
		if(launcher.fire(target_turf, target_ship, current_ship, user, approach_dir = selected_missile_direction))
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
		if(turret.fire(target_turf, target_ship, current_ship, user))
			return TRUE

	if(user)
		to_chat(user, span_warning("No laser turrets ready to fire!"))
	return FALSE

/// Fire all ready laser turrets at the current target location
/// Lasers are spread out at their spawn point but converge on the same target
/obj/machinery/computer/camera_advanced/ship_combat/proc/fire_all_lasers(mob/user)
	if(!attack_mode)
		to_chat(user, span_warning("Enter attack mode first!"))
		return 0

	var/turf/target_turf = get_target_turf()
	if(!target_ship || !target_turf)
		if(user)
			to_chat(user, span_warning("No target selected!"))
		return 0

	// First, collect all ready turrets
	var/list/ready_turrets = list()
	for(var/datum/weakref/ref in linked_turrets)
		var/obj/machinery/ship_combat/laser_turret/turret = ref.resolve()
		if(!turret)
			linked_turrets -= ref
			continue
		if(!turret.can_fire())
			continue
		ready_turrets += turret

	if(!length(ready_turrets))
		if(user)
			to_chat(user, span_warning("No laser turrets ready to fire!"))
		return 0

	// Calculate spread offsets centered around 0
	// For N turrets: offsets are -(N-1)/2, ..., -1, 0, 1, ..., (N-1)/2
	// This ensures beams spread symmetrically and converge on target
	var/turret_count = length(ready_turrets)
	var/half_count = (turret_count - 1) / 2

	var/fired_count = 0
	var/turret_index = 0
	for(var/obj/machinery/ship_combat/laser_turret/turret in ready_turrets)
		// Calculate spread offset: goes from -half_count to +half_count
		var/spread_offset = turret_index - half_count
		if(turret.fire(target_turf, target_ship, current_ship, user, spread_offset))
			fired_count++
		turret_index++

	if(user && fired_count > 0)
		to_chat(user, span_danger("Fired [fired_count] laser[fired_count > 1 ? "s" : ""]!"))

	return fired_count

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
			selected_missile_direction = null
			to_chat(user, span_notice("Missiles will approach from the closest edge to target."))
		if("North")
			selected_missile_direction = NORTH
			to_chat(user, span_notice("Missiles will approach from the North."))
		if("South")
			selected_missile_direction = SOUTH
			to_chat(user, span_notice("Missiles will approach from the South."))
		if("East")
			selected_missile_direction = EAST
			to_chat(user, span_notice("Missiles will approach from the East."))
		if("West")
			selected_missile_direction = WEST
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

// ========== INTERDICTION ==========

/// Starts the interdiction process - slows target ship
/obj/machinery/computer/camera_advanced/ship_combat/proc/start_interdiction(mob/user)
	if(machine_stat & (BROKEN|NOPOWER))
		if(user)
			to_chat(user, span_warning("[src] is not operational!"))
		return FALSE

	if(!current_ship)
		if(user)
			to_chat(user, span_warning("[src] is not connected to ship systems!"))
		return FALSE

	// Check research unlock
	if(!has_upgrade(TECHWEB_NODE_SHIP_COMBAT_INTERDICTOR))
		if(user)
			to_chat(user, span_warning("Interdiction systems not unlocked! Research 'Ship Interdiction Systems' and link to a research network."))
		return FALSE

	if(interdiction_active)
		if(user)
			to_chat(user, span_warning("Interdiction already active!"))
		return FALSE

	if(!COOLDOWN_FINISHED(src, interdict_cooldown))
		if(user)
			to_chat(user, span_warning("Interdictor is recharging! Available in [DisplayTimeText(COOLDOWN_TIMELEFT(src, interdict_cooldown))]."))
		return FALSE

	if(!target_ship)
		if(user)
			to_chat(user, span_warning("No target selected!"))
		return FALSE

	// Check range for interdiction (2 tiles)
	var/turf/our_turf = get_turf(current_ship)
	var/turf/target_turf = get_turf(target_ship)
	if(!our_turf || !target_turf)
		if(user)
			to_chat(user, span_warning("Cannot determine ship positions!"))
		return FALSE

	var/distance = get_dist(our_turf, target_turf)
	if(distance > INTERDICTOR_RANGE)
		if(user)
			to_chat(user, span_warning("Target ship is too far away! Move within [INTERDICTOR_RANGE] tiles to interdict."))
		return FALSE

	// Verify target is still flying
	if(target_ship.state != OVERMAP_SHIP_FLYING)
		if(user)
			to_chat(user, span_warning("Target ship cannot be interdicted!"))
		return FALSE

	// Start interdiction - immediately applies slowdown
	interdiction_active = TRUE
	interdicted_ship = target_ship

	// Apply slowdown to target - affects new thrust
	target_ship.speed_multiplier = INTERDICTOR_SPEED_REDUCTION

	// Also immediately reduce existing speed
	if(target_ship.speed && length(target_ship.speed) >= 2)
		target_ship.speed[1] *= INTERDICTOR_SPEED_REDUCTION
		target_ship.speed[2] *= INTERDICTOR_SPEED_REDUCTION

	// Register for target deletion and movement (both ships)
	RegisterSignal(interdicted_ship, COMSIG_QDELETING, PROC_REF(on_interdicted_ship_deleted))
	RegisterSignal(interdicted_ship, COMSIG_VOIDCREW_SHIP_MOVED, PROC_REF(on_interdicted_ship_moved))
	RegisterSignal(current_ship, COMSIG_VOIDCREW_SHIP_MOVED, PROC_REF(on_our_ship_moved))

	// Create the interdiction beam on the overmap between the two ships
	if(current_ship && target_ship)
		interdiction_beam = current_ship.Beam(
			target_ship,
			icon_state = "kinesis",
			icon = 'icons/effects/beam.dmi',
			emissive = TRUE
		)

	// Set emergency lighting on target ship
	set_ship_emergency_lights(target_ship, TRUE)

	// Send signal and alert target crew
	SEND_SIGNAL(target_ship, COMSIG_SHIP_INTERDICTED, src)
	target_ship.ship_announce("WARNING: YOUR SHIP IS BEING INTERDICTED! ENGINES AT [INTERDICTOR_SPEED_REDUCTION * 100]% EFFICIENCY!", "INTERDICTION ALERT", sound('sound/effects/alert.ogg'))

	// Alert our crew
	if(user)
		to_chat(user, span_notice("Interdiction field active! [target_ship.display_name] is slowed. Close in and use Force Dock when within range."))
	current_ship.ship_announce("Interdiction field active on [target_ship.display_name]. Target engines reduced to [INTERDICTOR_SPEED_REDUCTION * 100]%.", "Interdictor")

	// Start cooldown immediately when interdiction starts
	COOLDOWN_START(src, interdict_cooldown, INTERDICTOR_COOLDOWN)

	return TRUE

/// Called when the interdicted ship is deleted
/obj/machinery/computer/camera_advanced/ship_combat/proc/on_interdicted_ship_deleted(datum/source)
	SIGNAL_HANDLER
	cancel_interdiction("Target destroyed!")

/// Called when the interdicted ship moves - check if they escaped range
/obj/machinery/computer/camera_advanced/ship_combat/proc/on_interdicted_ship_moved(datum/source)
	SIGNAL_HANDLER
	check_interdiction_range()

/// Called when our ship moves - check if we left interdiction range
/obj/machinery/computer/camera_advanced/ship_combat/proc/on_our_ship_moved(datum/source)
	SIGNAL_HANDLER
	check_interdiction_range()

/// Checks if interdiction should be cancelled due to range
/obj/machinery/computer/camera_advanced/ship_combat/proc/check_interdiction_range()
	if(!interdiction_active || !interdicted_ship || !current_ship)
		return

	var/turf/our_turf = get_turf(current_ship)
	var/turf/target_turf = get_turf(interdicted_ship)
	if(!our_turf || !target_turf)
		return

	var/distance = get_dist(our_turf, target_turf)
	if(distance > INTERDICTOR_RANGE)
		cancel_interdiction("Target escaped interdiction range!")

/// Cancels the interdiction - removes slowdown from target
/obj/machinery/computer/camera_advanced/ship_combat/proc/cancel_interdiction(reason)
	if(!interdiction_active)
		return

	interdiction_active = FALSE

	// Remove the interdiction beam
	QDEL_NULL(interdiction_beam)

	// Unregister signal from our ship
	if(current_ship)
		UnregisterSignal(current_ship, COMSIG_VOIDCREW_SHIP_MOVED)

	// Remove slowdown from target and restore normal lighting
	if(interdicted_ship)
		UnregisterSignal(interdicted_ship, list(COMSIG_QDELETING, COMSIG_VOIDCREW_SHIP_MOVED))
		interdicted_ship.speed_multiplier = 1
		set_ship_emergency_lights(interdicted_ship, FALSE)
		SEND_SIGNAL(interdicted_ship, COMSIG_SHIP_INTERDICTION_ENDED)
		interdicted_ship.ship_announce("Interdiction field collapsed. Engines restored to full power.", "Interdiction Ended")

	interdicted_ship = null

	if(reason && current_ship)
		current_ship.ship_announce("[reason]", "Interdiction Ended")

/// Forces the interdicted target to dock with us - requires same tile
/obj/machinery/computer/camera_advanced/ship_combat/proc/force_dock_target(mob/user)
	if(machine_stat & (BROKEN|NOPOWER))
		if(user)
			to_chat(user, span_warning("[src] is not operational!"))
		return FALSE

	if(!current_ship)
		if(user)
			to_chat(user, span_warning("[src] is not connected to ship systems!"))
		return FALSE

	if(!interdiction_active || !interdicted_ship)
		if(user)
			to_chat(user, span_warning("No ship is currently being interdicted! Interdict a target first."))
		return FALSE

	// Check range for force dock (same tile)
	var/turf/our_turf = get_turf(current_ship)
	var/turf/target_turf = get_turf(interdicted_ship)
	if(!our_turf || !target_turf)
		if(user)
			to_chat(user, span_warning("Cannot determine ship positions!"))
		return FALSE

	var/distance = get_dist(our_turf, target_turf)
	if(distance > INTERDICTOR_FORCE_DOCK_RANGE)
		if(user)
			to_chat(user, span_warning("Target ship is not on the same tile! Move to their position to force dock."))
		return FALSE

	// Verify target is still flying
	if(interdicted_ship.state != OVERMAP_SHIP_FLYING)
		if(user)
			to_chat(user, span_warning("Target ship is no longer flying!"))
		cancel_interdiction()
		return FALSE

	// Store reference before cancelling interdiction
	var/obj/structure/overmap/ship/dock_target = interdicted_ship

	// Cancel interdiction (removes slowdown, beam, and emergency lights)
	interdiction_active = FALSE
	QDEL_NULL(interdiction_beam)
	if(current_ship)
		UnregisterSignal(current_ship, COMSIG_VOIDCREW_SHIP_MOVED)
	UnregisterSignal(interdicted_ship, list(COMSIG_QDELETING, COMSIG_VOIDCREW_SHIP_MOVED))
	interdicted_ship.speed_multiplier = 1
	set_ship_emergency_lights(interdicted_ship, FALSE)
	SEND_SIGNAL(interdicted_ship, COMSIG_SHIP_INTERDICTION_ENDED)
	interdicted_ship = null

	// Announce force dock
	current_ship.ship_announce("Forcing [dock_target.display_name] to dock!", "Force Dock Initiated")
	dock_target.ship_announce("FORCED DOCKING INITIATED!", "INTERDICTION ALERT")

	// Apply undock lockout to target ship BEFORE docking
	COOLDOWN_START(dock_target, interdiction_undock_lockout, INTERDICTOR_UNDOCK_LOCKOUT)

	// Force dock the ships together
	var/result = current_ship.dock_ships_directly(dock_target, null)
	if(result)
		// Docking failed for some reason
		current_ship.ship_announce("Forced docking failed: [result]", "Docking Error")
		dock_target.ship_announce("Forced docking failed.", "Docking Error")
		return FALSE
	else
		// Success - play alarm on target ship and notify of lockout
		playsound(src, 'sound/machines/airlock/airlockopen.ogg', 50, TRUE)
		dock_target.ship_announce("Undocking systems locked for [DisplayTimeText(INTERDICTOR_UNDOCK_LOCKOUT)]!", "SYSTEMS LOCKED")
		if(user)
			to_chat(user, span_notice("Force dock successful! Target ship is now docked and cannot undock for [DisplayTimeText(INTERDICTOR_UNDOCK_LOCKOUT)]."))
		return TRUE

/// Sets or unsets emergency lighting on all lights in a ship's areas
/obj/machinery/computer/camera_advanced/ship_combat/proc/set_ship_emergency_lights(obj/structure/overmap/ship/target, enable = TRUE)
	if(!target?.shuttle?.shuttle_areas)
		return
	for(var/area/ship_area in target.shuttle.shuttle_areas)
		for(var/obj/machinery/light/light in ship_area)
			if(enable)
				light.set_major_emergency_light()
			else
				light.unset_major_emergency_light()

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

// Select missile approach direction
/datum/action/innate/ship_combat/select_direction
	name = "Select Direction"
	desc = "Select which direction missiles will approach from."
	button_icon_state = "mech_view_stats"

/datum/action/innate/ship_combat/select_direction/Activate()
	if(!console || !ismob(owner))
		return
	console.open_direction_radial(owner)

// Fire single missile
/datum/action/innate/ship_combat/fire_missile
	name = "Fire Missile"
	desc = "Fire one missile at the targeted location."
	button_icon_state = "mech_zoom_off"

/datum/action/innate/ship_combat/fire_missile/Activate()
	if(!console || !ismob(owner))
		return
	console.fire_one(owner)

// Fire all missiles
/datum/action/innate/ship_combat/fire_all
	name = "Fire All Missiles"
	desc = "Fire all ready missiles at the targeted location."
	button_icon_state = "mech_zoom_on"

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
	button_icon_state = "mech_air_on"

/datum/action/innate/ship_combat/fire_all_lasers/Activate()
	if(!console || !ismob(owner))
		return
	console.fire_all_lasers(owner)

// Adjust laser power
/datum/action/innate/ship_combat/adjust_laser_power
	name = "Laser Power"
	desc = "Adjust power level for all laser turrets. Higher power = more damage but more power usage."
	button_icon_state = "mech_internals_on"

/datum/action/innate/ship_combat/adjust_laser_power/Activate()
	if(!console || !ismob(owner))
		return
	console.open_laser_power_radial(owner)

// ========== CIRCUIT BOARD ==========

/obj/item/circuitboard/computer/ship_combat_console
	name = "Ship Combat Console"
	greyscale_colors = CIRCUIT_COLOR_COMMAND
	build_path = /obj/machinery/computer/camera_advanced/ship_combat
