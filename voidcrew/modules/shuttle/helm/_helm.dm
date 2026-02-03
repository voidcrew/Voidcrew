#define JUMP_STATE_OFF 0
#define JUMP_STATE_CHARGING 1
#define JUMP_STATE_IONIZING 2
#define JUMP_STATE_FIRING 3
#define JUMP_STATE_FINALIZED 4
#define JUMP_CHARGE_DELAY (20 SECONDS)
#define JUMP_CHARGEUP_TIME (3 MINUTES)

/datum/armor/computer_helm
	melee = 50
	bullet = 30
	laser = 30
	energy = 30
	bomb = 50
	fire = 80
	acid = 70

/obj/machinery/computer/helm
	name = "helm control console"
	desc = "Used to view or control the ship."
	icon = 'voidcrew/modules/shuttle/icons/computer.dmi'
	icon_screen = "navigation"
	icon_keyboard = "tech_key"
	circuit = /obj/item/circuitboard/computer/shuttle/helm
	light_color = LIGHT_COLOR_FLARE
	// Helm consoles are critical ship infrastructure - make them tough
	max_integrity = 500
	armor_type = /datum/armor/computer_helm

	/// The ship we reside on for ease of access
	var/obj/structure/overmap/ship/current_ship //voidcrew todo: ship functionality
	/// All users currently using this
	var/list/concurrent_users = list()
	/// Is this console view only? I.E. cant dock/etc
	var/viewer = FALSE
	/// When are we allowed to jump
	var/jump_allowed
	/// Current state of our jump
	var/jump_state = JUMP_STATE_OFF
	///if we are calibrating the jump
	var/calibrating = FALSE
	///holding jump timer ID
	var/jump_timer
	/// Last known ship state for detecting changes
	var/last_ship_state
	/// Last known integrity percent for threshold detection
	var/last_integrity_percent = 100
	/// Whether we've played the 55% alert already
	var/played_55_alert = FALSE
	/// Console ambient sounds
	var/datum/console_ambience/console_ambience

/obj/machinery/computer/helm/Initialize(mapload)
	. = ..()
	// Console ambient sounds (not for viewscreens)
	if(!viewer)
		console_ambience = new(src, get_console_ambience_sounds())
		console_ambience.start()

/obj/machinery/computer/helm/Destroy()
	QDEL_NULL(console_ambience)
	return ..()

/obj/machinery/computer/helm/viewscreen
	name = "ship viewscreen"
	icon = 'icons/obj/wallmounts.dmi'
	icon_state = "telescreen"
	icon_keyboard = null
	icon_screen = null
	layer = SIGN_LAYER
	density = FALSE
	viewer = TRUE

/obj/machinery/computer/helm/attackby(obj/item/I, mob/living/user, params)
	// Handle ship authorization key
	if(istype(I, /obj/item/ship_key))
		attempt_claim_ship(I, user)
		return TRUE
	return ..()

/// Attempts to claim the ship using an authorization key
/obj/machinery/computer/helm/proc/attempt_claim_ship(obj/item/ship_key/key, mob/living/user)
	if(!current_ship && !attempt_ship_connection(last_resort = TRUE))
		to_chat(user, span_warning("This console is not connected to a ship!"))
		return FALSE

	// Check if key matches this ship
	var/obj/structure/overmap/ship/npc/npc_ship = key.get_ship()
	if(npc_ship != current_ship)
		to_chat(user, span_warning("This key is for a different vessel: [key.ship_name]"))
		return FALSE

	// Check if key is valid (has AI controller) OR ship is abandoned OR ship is disabled (all claimable)
	if(!key.is_valid() && !current_ship.abandoned && !npc_ship?.is_disabled)
		to_chat(user, span_warning("This authorization key is no longer valid."))
		return FALSE

	// Claim the ship!
	if(claim_npc_ship(npc_ship, user))
		to_chat(user, span_notice("Ship authorization accepted. You now have command of [npc_ship.name]."))
		playsound(src, 'sound/machines/terminal/terminal_on.ogg', 50, TRUE)
		// Send signal that key was used before destroying
		SEND_SIGNAL(key, COMSIG_SHIP_KEY_USED, npc_ship, user)
		// Mark destruction reason and consume the key
		key.mark_destruction_reason(KEY_DESTROYED_CLAIMED)
		qdel(key)
		return TRUE
	else
		to_chat(user, span_warning("Failed to claim ship. Try again."))
		return FALSE

/// Converts an NPC ship to player control
/obj/machinery/computer/helm/proc/claim_npc_ship(obj/structure/overmap/ship/npc/npc_ship, mob/living/claimer)
	if(!istype(npc_ship))
		return FALSE

	// Cancel abandonment timer if one is running
	if(npc_ship.abandonment_timer)
		npc_ship.cancel_abandonment_timer()

	// Reset abandoned state if ship was abandoned
	if(npc_ship.abandoned)
		npc_ship.abandoned = FALSE
		npc_ship.joining_allowed = TRUE

	// Remove the AI controller
	if(npc_ship.ai_controller)
		QDEL_NULL(npc_ship.ai_controller)

	// Remove the combat interface (no longer needed for AI)
	if(npc_ship.combat_interface)
		QDEL_NULL(npc_ship.combat_interface)

	// Clear NPC-specific state
	npc_ship.hostile = FALSE

	// Remove NPC color tint
	npc_ship.color = null
	npc_ship.chat_color = null

	// Convert ship areas to require power (NPC ships don't need power, player ships do)
	// Also convert any pirate turrets to be player-friendly
	if(npc_ship.shuttle?.shuttle_areas)
		for(var/area/shuttle_area as anything in npc_ship.shuttle.shuttle_areas)
			shuttle_area.requires_power = TRUE
			// Update all machinery in the area to respect power requirements
			shuttle_area.power_change()
			// Turn off pirate turrets - syndicate-based turrets can't be made safe
			// (their assess_perp always returns 10), but players can deconstruct
			// and rebuild them as standard turrets
			for(var/obj/machinery/porta_turret/syndicate/turret in shuttle_area)
				turret.toggle_on(FALSE)

	// Remove access requirements from all doors (player ships have open access)
	npc_ship.clear_door_access()

	// Reset ship movement state (NPC ships have different movement mechanics)
	npc_ship.speed = list(0, 0)
	npc_ship.speed_multiplier = 1
	npc_ship.is_interdicted = FALSE
	npc_ship.interdiction_strength = 0
	npc_ship.player_controlled = TRUE  // Use normal engine physics instead of NPC simplified movement

	// Announce the change of ownership
	npc_ship.ship_notify("NOTICE: Command authorization transferred. New commanding officer recognized.", "SHIP SYSTEMS", SHIP_NOTIFY_NOTICE, 'voidcrew/sound/notify.ogg', 50)

	// Add claimer to ship team if it exists, or create one
	// Note: Players can be members of multiple ship teams simultaneously
	if(claimer?.mind)
		if(!npc_ship.ship_team)
			// Create a ship team if one doesn't exist
			npc_ship.ship_team = new /datum/team/voidcrew()
			npc_ship.ship_team.name = npc_ship.name
			npc_ship.ship_team.ship = npc_ship
		npc_ship.ship_team.add_member(claimer.mind)

		// Set the claimer as captain (for NPC ships without job_slots)
		npc_ship.claimed_captain = claimer.mind

		// Grant the Captain Management action button
		var/datum/action/innate/captain_management/captain_action = new(claimer, npc_ship)
		captain_action.Grant(claimer)

	// Log the claim
	log_game("[key_name(claimer)] claimed NPC ship [npc_ship.name] at [AREACOORD(npc_ship)]")

	return TRUE

/obj/machinery/computer/helm/ui_interact(mob/user, datum/tgui/ui)
	. = ..()
	if(!current_ship && !attempt_ship_connection(last_resort = TRUE))
		return FALSE

	ui = SStgui.try_update_ui(user, src, ui)
	if(!ui)
		ui = new(user, src, "HelmComputer", name)
		ui.open()
		ui.set_autoupdate(TRUE) // Enable continuous UI updates
		// Register map after UI opens, passing window so it waits for visibility
		current_ship.cam_screen.display_to(user, ui.window)
	else
		// For existing UI, just refresh the display
		current_ship.cam_screen.display_to(user)

	// Update screen content after display registration
	current_ship.update_screen()

/obj/machinery/computer/helm/ui_close(mob/user)
	. = ..()
	current_ship.cam_screen.hide_from(user)
/*
/obj/machinery/computer/helm/ui_act(action, list/params)
	. = ..()

	switch(action)
		if ("north")
			current_ship.apply_thrust(y = 1)
		if ("northeast")
			current_ship.apply_thrust(x = 1, y = 1)
		if ("east")
			current_ship.apply_thrust(x = 1)
		if ("southeast")
			current_ship.apply_thrust(x = 1, y = -1)
		if ("south")
			current_ship.apply_thrust(y = -1)
		if ("southwest")
			current_ship.apply_thrust(x = -1, y = -1)
		if ("west")
			current_ship.apply_thrust(x = -1)
		if ("northwest")
			current_ship.apply_thrust(x = -1, y = 1)
		if ("reset")
			current_ship.reset_thrust()
*/
/obj/machinery/computer/helm/ui_data(mob/user)
	// var/list/data = list()
	var/list/data = ..()

	data["thrust"] = current_ship.calculate_thrust()
	data["integrity"] = current_ship.get_integrity_percent()
	data["overhealth"] = current_ship.get_overhealth_percent()

	// Calculate raw integrity for crash state checks
	var/raw_percent = current_ship.max_integrity > 0 ? round((current_ship.integrity / current_ship.max_integrity) * 100) : 100
	data["shipDisabled"] = raw_percent <= 50
	data["shipCrashed"] = current_ship.has_crash_landed && raw_percent < 65

	// Repair progress as tile counts - shows exact mass repaired vs needed
	if(data["shipCrashed"])
		var/target_integrity = round(0.65 * current_ship.max_integrity)
		data["repairCurrent"] = max(0, current_ship.integrity - current_ship.crashed_at_integrity)
		data["repairTotal"] = max(1, target_integrity - current_ship.crashed_at_integrity)
	else
		data["repairCurrent"] = 0
		data["repairTotal"] = 0

	data["calibrating"] = calibrating
	data["canThrust"] = current_ship.can_thrust()
	data["otherInfo"] = list()
	for (var/obj/structure/overmap/object as anything in current_ship.close_overmap_objects)
		var/other_integrity = object.integrity
		// For ships, use percentage-based integrity
		if(istype(object, /obj/structure/overmap/ship))
			var/obj/structure/overmap/ship/other_ship = object
			other_integrity = other_ship.get_integrity_percent()
		var/list/other_data = list(
			name = object.name,
			integrity = other_integrity,
			ref = REF(object)
		)
		data["otherInfo"] += list(other_data)
	var/turf/T = get_turf(current_ship)
	// Convert absolute turf coordinates to relative overmap coordinates (1-based)
	data["x"] = T.x - OVERMAP_LEFT_SIDE_COORD + 1
	data["y"] = T.y - OVERMAP_SOUTH_SIDE_COORD + 1
	data["state"] = current_ship.state
	data["docked"] = isturf(current_ship.loc) ? FALSE : TRUE
	data["heading"] = dir2text(current_ship.get_heading()) || "None"
	data["speed"] = current_ship.get_speed()
	data["eta"] = current_ship.get_eta()
	data["est_thrust"] = current_ship.est_thrust
	data["burnDirection"] = current_ship.burn_direction
	data["burnPercentage"] = current_ship.burn_percentage
	data["engineInfo"] = list()
	data["canLand"] = current_ship.shuttle.port_destinations ? TRUE : FALSE

	// Undock cooldown data (after docking)
	data["undockCooldown"] = !COOLDOWN_FINISHED(current_ship, undock_cooldown)
	data["undockCooldownRemaining"] = COOLDOWN_TIMELEFT(current_ship, undock_cooldown)

	// Interdiction undock lockout data
	data["undockLocked"] = !COOLDOWN_FINISHED(current_ship, interdiction_undock_lockout)
	data["undockLockoutRemaining"] = COOLDOWN_TIMELEFT(current_ship, interdiction_undock_lockout)

	// Dock warmup data
	data["dockWarmup"] = !!current_ship.dock_warmup_timer
	data["dockWarmupRemaining"] = current_ship.dock_warmup_timer ? timeleft(current_ship.dock_warmup_timer) : 0

	// Undock warmup data
	data["undockWarmup"] = !!current_ship.undock_warmup_timer
	data["undockWarmupRemaining"] = current_ship.undock_warmup_timer ? timeleft(current_ship.undock_warmup_timer) : 0

	// Cargo shuttle status - block undock if shuttle is present
	var/datum/voidcrew_cargo_shuttle/cargo_shuttle = current_ship.get_cargo_shuttle()
	data["cargoShuttlePresent"] = cargo_shuttle && cargo_shuttle.state != CARGO_SHUTTLE_AWAY

	// Interdiction status
	data["isInterdicted"] = current_ship.is_interdicted
	data["interdictionStrength"] = current_ship.interdiction_strength
	data["speedMultiplier"] = current_ship.speed_multiplier

	// Nebula concealment status
	data["hiddenInNebula"] = current_ship.hidden_in_nebula
	data["nebulaHideWarmup"] = !!current_ship.nebula_hide_timer
	data["nebulaHideRemaining"] = current_ship.nebula_hide_timer ? timeleft(current_ship.nebula_hide_timer) : 0
	// Check if we're on a nebula tile (can hide)
	var/on_nebula = FALSE
	for(var/obj/structure/overmap/event/nebula/N in T)
		on_nebula = TRUE
		break
	data["onNebula"] = on_nebula

	// Zone information
	if(SSovermap_zones.zones_active)
		var/datum/overmap_zone/zone = SSovermap_zones.get_zone(T)
		if(zone)
			data["zone_type"] = zone.zone_type
			data["zone_name"] = zone.name
			data["zone_color"] = zone.get_color()
			data["zone_description"] = zone.get_description()
			data["weapons_allowed"] = zone.weapons_allowed()
			data["interdiction_allowed"] = zone.interdiction_allowed()
		else
			data["zone_type"] = null
			data["zone_name"] = "Unknown"
			data["zone_color"] = "#ffffff"
			data["zone_description"] = "Zone data unavailable."
			data["weapons_allowed"] = TRUE
			data["interdiction_allowed"] = TRUE
		// Zone transition info (when crossing between zones)
		data["zone_transitioning"] = current_ship.zone_transitioning
		if(current_ship.zone_transitioning && current_ship.zone_transition_start_time)
			var/elapsed = world.time - current_ship.zone_transition_start_time
			var/progress = clamp((elapsed / ZONE_TRANSITION_TIME) * 100, 0, 100)
			var/remaining = max(0, ZONE_TRANSITION_TIME - elapsed) / 10
			data["zone_transition_progress"] = round(progress)
			data["zone_transition_remaining"] = round(remaining, 0.1)
			// Get target zone name
			if(current_ship.zone_transition_target)
				var/datum/overmap_zone/target_zone = SSovermap_zones.get_zone(current_ship.zone_transition_target)
				data["zone_transition_target"] = target_zone?.name || "Unknown Zone"
			else
				data["zone_transition_target"] = "Unknown Zone"
		else
			data["zone_transition_progress"] = 0
			data["zone_transition_remaining"] = 0
			data["zone_transition_target"] = null
	else
		data["zone_type"] = null
		data["zone_name"] = "Inactive"
		data["zone_color"] = "#888888"
		data["zone_description"] = "Zone system inactive."
		data["weapons_allowed"] = TRUE
		data["interdiction_allowed"] = TRUE
		data["zone_shift_seconds"] = 0
		data["zone_shift_minutes"] = 0
		data["zone_shift_remaining_seconds"] = 0
		data["zone_transitioning"] = FALSE
		data["zone_transition_progress"] = 0
		data["zone_transition_remaining"] = 0
		data["zone_transition_target"] = null

	for(var/obj/machinery/power/shuttle_engine/ship/E in current_ship.shuttle.engine_list)
		if(QDELETED(E))
			continue
		var/list/engine_data
		if(!E.thruster_active)
			engine_data = list(
				name = E.name,
				fuel = 0,
				maxFuel = 100,
				enabled = E.enabled,
				ref = REF(E)
			)
		else
			engine_data = list(
				name = E.name,
				fuel = E.return_fuel(),
				maxFuel = E.return_fuel_cap(),
				enabled = E.enabled,
				ref = REF(E)
			)
		data["engineInfo"] += list(engine_data)

	return data

/obj/machinery/computer/helm/ui_static_data(mob/user)
	var/list/data = list()

	data["mapRef"] = current_ship.map_name
	data["isViewer"] = viewer
	data["mapRef"] = current_ship.map_name
	data["shipInfo"] = list(
		name = current_ship.display_name,
		class = current_ship.source_template?.name,
		mass = current_ship.mass,
		//sensor_range = current_ship.sensor_range
	)
	data["canFly"] = TRUE

	// Check if user is a crew member of this ship
	data["isNotCrew"] = !is_crew_member(user)

	// Abandoned ship status
	data["isAbandoned"] = current_ship?.abandoned

	return data

/**
 * Checks if the given user is a member of this ship's crew
 */
/obj/machinery/computer/helm/proc/is_crew_member(mob/user)
	if(!ismob(user))
		return FALSE
	// Allow admin ghosts with AI interaction enabled
	if(isAdminGhostAI(user))
		return TRUE
	var/mob/living/living_user = user
	if(!istype(living_user) || !living_user.mind)
		return FALSE
	if(!current_ship?.ship_team)
		return TRUE // No ship team set up, allow access
	if(current_ship.abandoned)
		return TRUE // Abandoned ships allow anyone to access for claiming
	return (living_user.mind in current_ship.ship_team.members)

/obj/machinery/computer/helm/LateInitialize()
	. = ..()
	attempt_ship_connection()

/obj/machinery/computer/helm/proc/calibrate_jump(inline = FALSE)
	if(jump_allowed < 0)
		say("Bluespace Jump Calibration offline. Please contact your system administrator.")
		return
	if(current_ship.state != OVERMAP_SHIP_FLYING)
		say("Bluespace Jump Calibration detected interference in the local area.")
		return
	if(world.time < jump_allowed)
		var/jump_wait = DisplayTimeText(jump_allowed - world.time)
		say("Bluespace Jump Calibration is currently recharging. ETA: [jump_wait].")
		return
	if(jump_state != JUMP_STATE_OFF && !inline)
		return // This exists to prefent Href exploits to call process_jump more than once by a client
	message_admins("[ADMIN_LOOKUPFLW(usr)] has initiated a bluespace jump in [ADMIN_VERBOSEJMP(src)]")
	jump_timer = addtimer(CALLBACK(src, PROC_REF(jump_sequence), TRUE), JUMP_CHARGEUP_TIME, TIMER_STOPPABLE)
	current_ship?.ship_notify("Bluespace jump calibration initialized. Calibration completion in [JUMP_CHARGEUP_TIME/600] minutes.", "BLUESPACE", SHIP_NOTIFY_NOTICE, 'voidcrew/sound/notify.ogg', 50)
	calibrating = TRUE
	return TRUE

/obj/machinery/computer/helm/proc/cancel_jump()
	current_ship?.ship_notify("Pylon Disengaged. Jump cancelled.", "BLUESPACE", SHIP_NOTIFY_WARNING, 'voidcrew/sound/notify.ogg', 50)
	calibrating = FALSE
	deltimer(jump_timer)

/obj/machinery/computer/helm/proc/jump_sequence()
	switch(jump_state)
		if(JUMP_STATE_OFF)
			jump_state = JUMP_STATE_CHARGING
			SStgui.close_uis(src)
		if(JUMP_STATE_CHARGING)
			jump_state = JUMP_STATE_IONIZING
			current_ship?.ship_notify("Bluespace Jump Calibration completed. Ionizing Bluespace Pylon.", "BLUESPACE", SHIP_NOTIFY_NOTICE, 'voidcrew/sound/notify.ogg', 50)
		if(JUMP_STATE_IONIZING)
			jump_state = JUMP_STATE_FIRING
			current_ship?.ship_notify("Bluespace Ionization finalized; preparing to fire Bluespace Pylon.", "BLUESPACE", SHIP_NOTIFY_NOTICE, 'voidcrew/sound/notify.ogg', 50)
		if(JUMP_STATE_FIRING)
			jump_state = JUMP_STATE_FINALIZED
			current_ship?.ship_notify("Bluespace Pylon launched.", "BLUESPACE", SHIP_NOTIFY_NOTICE, 'sound/effects/magic/lightning_chargeup.ogg', 50)
			addtimer(CALLBACK(src, PROC_REF(do_jump)), 10 SECONDS)
			return
	addtimer(CALLBACK(src, PROC_REF(jump_sequence), TRUE), JUMP_CHARGE_DELAY)

/obj/machinery/computer/helm/proc/do_jump()
	current_ship?.ship_notify("Bluespace Jump Initiated.", "BLUESPACE", SHIP_NOTIFY_NOTICE, 'voidcrew/sound/notify.ogg', 50)
	// Extract ship parts from all players on the ship before jumping
	if(current_ship)
		extract_ship_parts_from_ship(current_ship, "bluespace_jump")
	current_ship.destroy_ship(TRUE)

/obj/machinery/computer/helm/connect_to_shuttle(mapload, obj/docking_port/mobile/voidcrew/port, obj/docking_port/stationary/dock)
	if(!istype(port))
		return
	set_current_ship(port.current_ship)

/**
 * This proc manually rechecks that the helm computer is connected to a proper ship
 */
/obj/machinery/computer/helm/proc/attempt_ship_connection(last_resort = FALSE)
	if(current_ship && current_ship.shuttle.z == z)
		// Already connected, but ensure signal is registered
		RegisterSignal(current_ship, COMSIG_SHIP_INTEGRITY_CHANGED, PROC_REF(on_ship_integrity_changed), override = TRUE)
		return TRUE

	var/obj/structure/overmap/ship/ship = get_ship_from_atom(src)
	if(!ship && last_resort)
		stack_trace("Failed to connect a helm to its ship, this is almost certainly a bug!")

	set_current_ship(ship)
	return !!current_ship

/**
 * Sets the current ship and registers signal listeners
 */
/obj/machinery/computer/helm/proc/set_current_ship(obj/structure/overmap/ship/new_ship)
	// Unregister from old ship
	if(current_ship)
		UnregisterSignal(current_ship, COMSIG_SHIP_INTEGRITY_CHANGED)

	current_ship = new_ship

	// Register to new ship for auto UI updates
	if(current_ship)
		RegisterSignal(current_ship, COMSIG_SHIP_INTEGRITY_CHANGED, PROC_REF(on_ship_integrity_changed))

/**
 * Signal handler - refreshes UI when ship integrity changes
 */
/obj/machinery/computer/helm/proc/on_ship_integrity_changed(datum/source, new_integrity, max_integrity, display_percent)
	SIGNAL_HANDLER
	SStgui.update_uis(src)

	// Play alert sound when crossing 55% threshold (going down)
	if(last_integrity_percent > 55 && display_percent <= 55 && !played_55_alert)
		played_55_alert = TRUE
		playsound(src, 'sound/effects/alert.ogg', 75, FALSE)

	// Reset the alert flag if we repair above 55%
	if(display_percent > 55)
		played_55_alert = FALSE

	last_integrity_percent = display_percent

/**
 * This proc manually rechecks that the helm computer is connected to a proper ship
 */
/obj/machinery/computer/helm/proc/reload_ship()
	var/obj/structure/overmap/ship/ship = get_ship_from_atom(src)
	if(ship)
		current_ship = ship
	return TRUE

/obj/machinery/computer/helm/ui_act(action, list/params, datum/tgui/ui, datum/ui_state/state)
	. = ..()
	if(.)
		return
	if(viewer)
		return
	// Server-side crew check as safety net
	if(!is_crew_member(usr))
		say("ERROR: Access denied. Crew authorization required.")
		return
	switch(action) // Universal topics
		if("rename_ship")
			var/new_name = params["newName"]
			var/old_name = current_ship.name
			if(!new_name)
				return
			new_name = trim(new_name)
			if (!length(new_name) || new_name == current_ship.name)
				return
			if(!reject_bad_text(new_name, MAX_CHARTER_LEN))
				say("Error: Replacement designation rejected by system.")
				return
			if(!current_ship.set_ship_name(new_name))
				say("Error: [COOLDOWN_TIMELEFT(current_ship, rename_cooldown)/10] seconds until ship designation can be changed..")
			else
				log_shuttle("[usr] changed shuttle [old_name] to [new_name]")
			update_static_data(usr, ui)
			return
			/*
		if("toggle_kos")
			current_ship.set_ship_faction("KOS")
			update_static_data(usr, ui)
			return
		if("return")
			current_ship.set_ship_faction("return")
			update_static_data(usr, ui)
			return
			*/
		if("reload_ship")
			reload_ship()
			current_ship.calculate_mass() // Refresh health based on current turfs
			update_static_data(usr, ui)
			return
		if("reload_engines")
			current_ship.refresh_engines()
			return
		if("typing_sound")
			playsound(src, pick('sound/machines/terminal/terminal_button01.ogg', 'sound/machines/terminal/terminal_button02.ogg', 'sound/machines/terminal/terminal_button03.ogg', 'sound/machines/terminal/terminal_button04.ogg', 'sound/machines/terminal/terminal_button05.ogg', 'sound/machines/terminal/terminal_button06.ogg', 'sound/machines/terminal/terminal_button07.ogg', 'sound/machines/terminal/terminal_button08.ogg'), 10, TRUE)
			return
		if("broadcast")
			var/message = params["message"]
			if(!message)
				return
			message = trim(message)
			if(!length(message))
				return
			current_ship.ship_broadcast_runechat(message)
			return
		if("claim_abandoned")
			if(!current_ship?.abandoned)
				say("ERROR: This ship is not abandoned.")
				return
			var/mob/living/living_user = usr
			if(!istype(living_user))
				return
			if(current_ship.claim_abandoned_ship(living_user))
				playsound(src, 'sound/machines/terminal/terminal_on.ogg', 50, TRUE)
				update_static_data(usr, ui)
			else
				say("ERROR: Failed to claim ship.")
			return

	// Prevent operation if ship is destroyed (at or below 50% integrity)
	if(current_ship.get_integrity_percent() <= 50)
		say("ERROR: Hull integrity critical. All systems offline.")
		return

	switch(current_ship.state) // Ship state-limited topics
		if(OVERMAP_SHIP_FLYING)
			switch(action)
				if("act_overmap")
					var/obj/structure/overmap/to_act = locate(params["ship_to_act"])
					say(current_ship.overmap_object_act(usr, to_act))
					return
				if("toggle_engine")
					var/obj/machinery/power/shuttle_engine/ship/E = locate(params["engine"])
					E.enabled = !E.enabled
					current_ship.refresh_engines()
					return
				if("change_heading")
					var/new_direction = text2num(params["dir"])
					// Toggle off if clicking same direction
					if(new_direction == current_ship.burn_direction)
						current_ship.change_heading(BURN_NONE)
					else
						current_ship.change_heading(new_direction)
					return
				if("change_burn_percentage")
					var/new_percentage = clamp(text2num(params["percentage"]), 1, 100)
					current_ship.burn_percentage = new_percentage
					return
				if("stop")
					// Cancel zone transition if in progress
					if(current_ship.zone_transitioning)
						current_ship.cancel_zone_transition()
						return
					// Toggle between no thrust and active braking
					if(current_ship.burn_direction == BURN_NONE)
						current_ship.change_heading(BURN_STOP)
					else
						current_ship.change_heading(BURN_NONE)
					return
				if("bluespace_jump")
					if(calibrating)
						cancel_jump()
						return
					else
						if(tgui_alert(usr, "Do you want to bluespace jump? Your ship and everything on it will be removed from the round.", "Jump Confirmation", list("Yes", "No")) != "Yes")
							return
						calibrate_jump()
						return
				if("dock_empty")
					if(length(current_ship.close_overmap_objects))
						for(var/obj/structure/overmap/o in current_ship.close_overmap_objects)
							if(!istype(o, /obj/structure/overmap/planet/empty) && !istype(o, /obj/structure/overmap/ship))
								playsound(src, 'sound/machines/terminal/terminal_error.ogg', 20)
								balloon_alert(usr, "something is in the way!")
								return
					say(current_ship.dock_in_empty_space(usr))
					return
				if("hide_in_nebula")
					if(!current_ship.can_hide_in_nebula())
						if(current_ship.hidden_in_nebula)
							say("ERROR: Already concealed in nebula.")
						else if(current_ship.nebula_hide_timer)
							say("ERROR: Nebula concealment already in progress...")
						else if(current_ship.is_interdicted)
							say("ERROR: Cannot hide while interdicted!")
						else
							say("ERROR: Must be inside a nebula to engage concealment.")
						return
					if(current_ship.hide_in_nebula())
						say("Initiating nebula concealment sequence...")
					return
				if("cancel_nebula_hide")
					if(current_ship.cancel_nebula_hide())
						say("Nebula concealment cancelled.")
					return
				if("unhide_from_nebula")
					if(!current_ship.can_unhide_from_nebula())
						say("ERROR: Ship is not in concealment mode.")
						return
					if(current_ship.unhide_from_nebula())
						say("Emerging from nebula concealment. Combat systems online.")
					return
		if(OVERMAP_SHIP_IDLE)
			if(action == "undock")
				// Check if cargo shuttle is still present
				var/datum/voidcrew_cargo_shuttle/cargo_shuttle = current_ship.get_cargo_shuttle()
				if(cargo_shuttle && cargo_shuttle.state != CARGO_SHUTTLE_AWAY)
					say("ERROR: Cannot undock while cargo shuttle is present. Send the cargo shuttle away first.")
					return
				current_ship.calculate_avg_fuel()
				if(current_ship.avg_fuel_amnt < 25 && tgui_alert(usr, "Ship only has ~[round(current_ship.avg_fuel_amnt)]% fuel remaining! Are you sure you want to undock?", name, list("Yes", "No")) != "Yes")
					return
				say(current_ship.undock())
				return



#undef JUMP_STATE_OFF
#undef JUMP_STATE_CHARGING
#undef JUMP_STATE_IONIZING
#undef JUMP_STATE_FIRING
#undef JUMP_STATE_FINALIZED
#undef JUMP_CHARGE_DELAY
#undef JUMP_CHARGEUP_TIME
