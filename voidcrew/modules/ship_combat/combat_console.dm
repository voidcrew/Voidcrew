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
	/// Reference to our console
	var/obj/machinery/computer/camera_advanced/ship_combat/console
	/// The ship we're allowed to view
	var/obj/structure/overmap/ship/target_ship

/mob/eye/camera/remote/ship_combat/Initialize(mapload, obj/machinery/computer/camera_advanced/ship_combat/origin)
	. = ..()
	console = origin

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
	icon_screen = "tactical"
	icon_keyboard = "security_key"
	circuit = /obj/item/circuitboard/computer/ship_combat_console
	light_color = LIGHT_COLOR_INTENSE_RED
	networks = list() // We don't use the camera network

	/// Our ship reference
	var/obj/structure/overmap/ship/current_ship
	/// Currently targeted enemy ship
	var/obj/structure/overmap/ship/target_ship
	/// List of linked missile launchers (weakrefs)
	var/list/linked_launchers = list()
	/// Is cloaking device active on our ship?
	var/cloak_active = FALSE
	/// The targeting reticle shown on screen
	var/atom/movable/screen/ship_combat/targeting_reticle/reticle
	/// Are we currently in attack mode (camera view)?
	var/attack_mode = FALSE

	// ===== INTERDICTOR VARIABLES =====
	/// Is interdiction currently active?
	var/interdiction_active = FALSE
	/// Progress of the interdiction (0-100)
	var/interdiction_progress = 0
	/// Timer ID for processing interdiction
	var/interdiction_timer
	/// Cooldown between interdiction attempts
	COOLDOWN_DECLARE(interdict_cooldown)

/obj/machinery/computer/camera_advanced/ship_combat/Initialize(mapload)
	. = ..()
	// Add our custom actions
	actions += new /datum/action/innate/ship_combat/fire_missile(src)
	actions += new /datum/action/innate/ship_combat/fire_all(src)
	actions += new /datum/action/innate/ship_combat/exit_targeting(src)

	reticle = new(null, src)

/obj/machinery/computer/camera_advanced/ship_combat/Destroy()
	cancel_interdiction()
	clear_target()
	for(var/datum/weakref/ref in linked_launchers)
		var/obj/machinery/ship_combat/missile_launcher/launcher = ref.resolve()
		if(launcher)
			launcher.unlink_console()
	linked_launchers.Cut()
	QDEL_NULL(reticle)
	current_ship = null
	return ..()

/obj/machinery/computer/camera_advanced/ship_combat/examine(mob/user)
	. = ..()
	. += span_notice("Linked launchers: [length(linked_launchers)]")
	if(target_ship)
		. += span_notice("Current target: [target_ship.display_name]")
	else
		. += span_warning("No target selected. Use the console to select a target ship.")
	if(!is_crew_member(user))
		. += span_warning("You are not authorized to use this console.")

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

	// Get nearby ships
	var/list/nearby_ships = list()
	if(current_ship?.close_overmap_objects)
		for(var/obj/structure/overmap/other in current_ship.close_overmap_objects)
			if(!istype(other, /obj/structure/overmap/ship))
				continue
			var/obj/structure/overmap/ship/S = other
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

	// Interdictor data
	data["interdiction_active"] = interdiction_active
	data["interdiction_progress"] = interdiction_progress
	data["interdict_cooldown_active"] = !COOLDOWN_FINISHED(src, interdict_cooldown)
	data["interdict_cooldown_remaining"] = COOLDOWN_TIMELEFT(src, interdict_cooldown)

	// Check if target is on same tile (required for interdiction)
	var/target_same_tile = FALSE
	if(target_ship && current_ship)
		target_same_tile = (get_turf(target_ship) == get_turf(current_ship))
	data["target_same_tile"] = target_same_tile

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
			clear_target()
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
	// Only show turfs and structures, not mobs (tactical view)
	user.add_sight(SEE_TURFS)

/obj/machinery/computer/camera_advanced/ship_combat/remove_eye_control(mob/living/user)
	UnregisterSignal(user, COMSIG_MOB_CLICKON)
	if(user.client)
		user.client.screen -= reticle
	// Remove the tactical sight
	user.clear_sight(SEE_TURFS)
	return ..()

// ========== ATTACK MODE ==========

/// Enters attack mode - takes over user's view to target ship
/obj/machinery/computer/camera_advanced/ship_combat/proc/enter_attack_mode(mob/user)
	if(!target_ship)
		to_chat(user, span_warning("No target selected!"))
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

/obj/machinery/computer/camera_advanced/ship_combat/multitool_act(mob/living/user, obj/item/multitool/tool)
	if(!istype(tool))
		return NONE

	if(!tool.buffer)
		balloon_alert(user, "nothing buffered")
		return ITEM_INTERACT_BLOCKING

	// Handle list of launchers (new behavior)
	if(islist(tool.buffer))
		var/list/launcher_buffer = tool.buffer
		if(!length(launcher_buffer))
			balloon_alert(user, "nothing buffered")
			return ITEM_INTERACT_BLOCKING

		var/linked_count = 0
		var/already_linked_count = 0
		for(var/obj/machinery/ship_combat/missile_launcher/launcher in launcher_buffer)
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

		// Clear the buffer after linking
		launcher_buffer.Cut()

		if(linked_count > 0)
			balloon_alert(user, "[linked_count] launcher(s) linked")
			to_chat(user, span_notice("Linked [linked_count] launcher(s) to [src]. Total launchers: [length(linked_launchers)]"))
		else if(already_linked_count > 0)
			balloon_alert(user, "all already linked")
		else
			balloon_alert(user, "no valid launchers")

		return ITEM_INTERACT_SUCCESS

	// Handle single launcher (legacy behavior / backwards compatibility)
	if(!istype(tool.buffer, /obj/machinery/ship_combat/missile_launcher))
		balloon_alert(user, "invalid device")
		return ITEM_INTERACT_BLOCKING

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

// ========== TARGET SELECTION ==========

/// Sets a new target ship
/obj/machinery/computer/camera_advanced/ship_combat/proc/set_target_ship(obj/structure/overmap/ship/new_target, mob/user)
	if(new_target == current_ship)
		if(user)
			to_chat(user, span_warning("Cannot target your own ship!"))
		return FALSE

	clear_target()
	target_ship = new_target

	if(target_ship)
		RegisterSignal(target_ship, COMSIG_QDELETING, PROC_REF(on_target_deleted))

		// Set the eye's allowed ship if it exists
		var/mob/eye/camera/remote/ship_combat/combat_eye = eyeobj
		if(combat_eye)
			combat_eye.target_ship = target_ship

		if(user)
			to_chat(user, span_notice("Target acquired: [target_ship.display_name]. Use 'Attack' to enter targeting mode."))

	return TRUE

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

/// Fire at the current target location with all ready launchers
/obj/machinery/computer/camera_advanced/ship_combat/proc/fire_all(mob/user)
	if(!attack_mode)
		to_chat(user, span_warning("Enter attack mode first!"))
		return 0

	var/turf/target_turf = get_target_turf()
	if(!target_ship || !target_turf)
		if(user)
			to_chat(user, span_warning("No target selected!"))
		return 0

	// Count ready launchers first so we can spread them out
	var/list/ready_launchers = list()
	for(var/datum/weakref/ref in linked_launchers)
		var/obj/machinery/ship_combat/missile_launcher/launcher = ref.resolve()
		if(!launcher)
			linked_launchers -= ref
			continue
		if(launcher.can_fire())
			ready_launchers += launcher

	// Build list of staggered target positions (3 wide x 2 tall spread)
	var/list/stagger_offsets = list(
		list(0, 0),    // center
		list(-1, 0),   // left
		list(1, 0),    // right
		list(0, 1),    // up
		list(-1, 1),   // up-left
		list(1, 1),    // up-right
	)

	var/fired_count = 0
	var/offset_index = 1
	for(var/obj/machinery/ship_combat/missile_launcher/launcher in ready_launchers)
		// Get staggered target position
		var/list/offset = stagger_offsets[offset_index]
		var/turf/staggered_target = locate(target_turf.x + offset[1], target_turf.y + offset[2], target_turf.z)
		if(!staggered_target)
			staggered_target = target_turf

		if(launcher.fire(staggered_target, target_ship, current_ship, user))
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

/// Fire the first ready launcher
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
		if(launcher.fire(target_turf, target_ship, current_ship, user))
			// Firing breaks cloak
			if(current_ship)
				SEND_SIGNAL(current_ship, COMSIG_SHIP_WEAPON_FIRED)
			if(user)
				to_chat(user, span_danger("Missile away!"))
			return TRUE

	if(user)
		to_chat(user, span_warning("No launchers ready to fire!"))
	return FALSE

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

/// Starts the interdiction process
/obj/machinery/computer/camera_advanced/ship_combat/proc/start_interdiction(mob/user)
	if(machine_stat & (BROKEN|NOPOWER))
		if(user)
			to_chat(user, span_warning("[src] is not operational!"))
		return FALSE

	if(!current_ship)
		if(user)
			to_chat(user, span_warning("[src] is not connected to ship systems!"))
		return FALSE

	if(interdiction_active)
		if(user)
			to_chat(user, span_warning("Interdiction already in progress!"))
		return FALSE

	if(!COOLDOWN_FINISHED(src, interdict_cooldown))
		if(user)
			to_chat(user, span_warning("Interdictor is recharging! Available in [DisplayTimeText(COOLDOWN_TIMELEFT(src, interdict_cooldown))]."))
		return FALSE

	if(!target_ship)
		if(user)
			to_chat(user, span_warning("No target selected!"))
		return FALSE

	// Verify target is on the same tile
	if(get_turf(target_ship) != get_turf(current_ship))
		if(user)
			to_chat(user, span_warning("Target ship is not on the same tile! Move closer to interdict."))
		return FALSE

	// Verify target is still flying
	if(target_ship.state != OVERMAP_SHIP_FLYING)
		if(user)
			to_chat(user, span_warning("Target ship cannot be interdicted!"))
		return FALSE

	// Start interdiction
	interdiction_active = TRUE
	interdiction_progress = 0

	// Apply slowdown to target
	target_ship.speed_multiplier = INTERDICTOR_SPEED_REDUCTION

	// Send signal and alert target crew
	SEND_SIGNAL(target_ship, COMSIG_SHIP_INTERDICTED, src)
	target_ship.ship_announce("WARNING: YOUR SHIP IS BEING INTERDICTED! ENGINES AT [INTERDICTOR_SPEED_REDUCTION * 100]% EFFICIENCY!", "INTERDICTION ALERT", sound('sound/effects/alert.ogg'))

	// Alert our crew
	if(user)
		to_chat(user, span_notice("Interdiction lock initiated on [target_ship.display_name]. Locking on..."))
	current_ship.ship_announce("Interdiction lock initiated on [target_ship.display_name].", "Interdictor")

	// Start processing
	interdiction_timer = addtimer(CALLBACK(src, PROC_REF(process_interdiction)), 0.5 SECONDS, TIMER_STOPPABLE | TIMER_LOOP)

	return TRUE

/// Called every 0.5 seconds during interdiction
/obj/machinery/computer/camera_advanced/ship_combat/proc/process_interdiction()
	if(!interdiction_active)
		return

	if(machine_stat & (BROKEN|NOPOWER))
		cancel_interdiction("Interdictor lost power!")
		return

	if(!target_ship)
		cancel_interdiction("Target lost!")
		return

	// Check if target escaped (moved to different tile)
	if(get_turf(target_ship) != get_turf(current_ship))
		cancel_interdiction("Target escaped interdiction range!")
		return

	// Check if target is no longer flying (already docked somewhere)
	if(target_ship.state != OVERMAP_SHIP_FLYING)
		cancel_interdiction("Target is no longer flying!")
		return

	// Increment progress (10% per 0.5 seconds = 5 seconds total)
	interdiction_progress += 10

	if(interdiction_progress >= 100)
		complete_interdiction()

/// Cancels the interdiction process
/obj/machinery/computer/camera_advanced/ship_combat/proc/cancel_interdiction(reason)
	if(!interdiction_active)
		return

	interdiction_active = FALSE
	interdiction_progress = 0

	if(interdiction_timer)
		deltimer(interdiction_timer)
		interdiction_timer = null

	// Remove slowdown from target
	if(target_ship)
		target_ship.speed_multiplier = 1
		SEND_SIGNAL(target_ship, COMSIG_SHIP_INTERDICTION_ENDED)
		target_ship.ship_announce("Interdiction lock broken. Engines restored to full power.", "Interdiction Ended")

	if(reason && current_ship)
		current_ship.ship_announce("[reason]", "Interdiction Failed")

/// Completes interdiction and forces docking
/obj/machinery/computer/camera_advanced/ship_combat/proc/complete_interdiction()
	if(!interdiction_active)
		return

	if(!target_ship)
		cancel_interdiction("Target lost at final moment!")
		return

	interdiction_active = FALSE
	interdiction_progress = 100

	if(interdiction_timer)
		deltimer(interdiction_timer)
		interdiction_timer = null

	// Remove slowdown
	target_ship.speed_multiplier = 1
	SEND_SIGNAL(target_ship, COMSIG_SHIP_INTERDICTION_ENDED)

	// Announce success
	current_ship.ship_announce("Interdiction complete! Forcing [target_ship.display_name] to dock!", "Interdiction Success")
	target_ship.ship_announce("INTERDICTION COMPLETE! Forced docking initiated!", "INTERDICTION ALERT")

	// Apply undock lockout to target ship BEFORE docking
	COOLDOWN_START(target_ship, interdiction_undock_lockout, INTERDICTOR_UNDOCK_LOCKOUT)

	// Force dock the ships together
	var/result = current_ship.dock_ships_directly(target_ship, null)
	if(result)
		// Docking failed for some reason
		current_ship.ship_announce("Forced docking failed: [result]", "Docking Error")
		target_ship.ship_announce("Forced docking failed. Engines restored.", "Interdiction Ended")
	else
		// Success - play alarm on target ship and notify of lockout
		playsound(src, 'sound/machines/airlock/airlockopen.ogg', 50, TRUE)
		target_ship.ship_announce("Undocking systems locked for [DisplayTimeText(INTERDICTOR_UNDOCK_LOCKOUT)]!", "SYSTEMS LOCKED")

	// Start cooldown
	COOLDOWN_START(src, interdict_cooldown, INTERDICTOR_COOLDOWN)

// ========== TARGETING RETICLE ==========

/atom/movable/screen/ship_combat
	icon = 'icons/hud/screen_gen.dmi'
	mouse_opacity = MOUSE_OPACITY_TRANSPARENT

/atom/movable/screen/ship_combat/targeting_reticle
	name = "targeting reticle"
	icon_state = "movemarker" // Using existing marker, can be replaced with custom
	screen_loc = "CENTER"
	color = "#ff0000"
	layer = ABOVE_MOB_LAYER

/atom/movable/screen/ship_combat/targeting_reticle/Initialize(mapload, obj/machinery/computer/camera_advanced/ship_combat/console)
	. = ..()
	// Add a pulsing effect
	animate(src, alpha = 128, time = 0.5 SECONDS, loop = -1)
	animate(alpha = 255, time = 0.5 SECONDS)

// ========== ACTION BUTTONS ==========

/datum/action/innate/ship_combat
	button_icon = 'icons/mob/actions/actions_items.dmi'
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

// Fire single missile
/datum/action/innate/ship_combat/fire_missile
	name = "Fire Missile"
	desc = "Fire one missile at the targeted location."
	button_icon_state = "rocket"

/datum/action/innate/ship_combat/fire_missile/Activate()
	if(!console || !isliving(owner))
		return
	console.fire_one(owner)

// Fire all missiles
/datum/action/innate/ship_combat/fire_all
	name = "Fire All Missiles"
	desc = "Fire all ready missiles at the targeted location."
	button_icon_state = "yourstation"

/datum/action/innate/ship_combat/fire_all/Activate()
	if(!console || !isliving(owner))
		return
	console.fire_all(owner)

// Exit targeting
/datum/action/innate/ship_combat/exit_targeting
	name = "Exit Targeting"
	desc = "Exit the targeting system and return to normal view."
	button_icon_state = "yourstation"

/datum/action/innate/ship_combat/exit_targeting/Activate()
	if(!console || !isliving(owner))
		return
	console.exit_attack_mode(owner)

// ========== CIRCUIT BOARD ==========

/obj/item/circuitboard/computer/ship_combat_console
	name = "Ship Combat Console"
	greyscale_colors = CIRCUIT_COLOR_COMMAND
	build_path = /obj/machinery/computer/camera_advanced/ship_combat
