///Threshold above which it uses the ship sprites instead of the shuttle sprites
#define SHIP_SIZE_THRESHOLD 150

// The ship proc set lives in this folder: shields, engines, crew, lifecycle, docking,
// movement and mass sit in their own ship/*.dm sidecars; this file keeps the type
// definition, lifecycle hooks, notifications and the combat/mission surface.

/obj/structure/overmap/ship
	name = "overmap vessel"
	desc = "A spacefaring vessel."
	icon_state = "ship"
	base_icon_state = "ship" //Prefix of all the icons used by the ship. (ex. [base_icon_state]_moving)
	layer = ABOVE_MOB_LAYER // Render ships above other overmap objects in popup map views

	/**
	 * Template and docking port.
	 */
	///The docking port of the linked shuttle
	var/obj/docking_port/mobile/voidcrew/shuttle
	///The map template the shuttle was spawned from, if it was indeed created from a template. CAN BE NULL (ex. custom-built ships).
	var/datum/map_template/shuttle/voidcrew/source_template

	/**
	 * Ship states and deletion.
	 */
	///State of the shuttle: idle, flying, docking, or undocking
	var/state = OVERMAP_SHIP_FLYING
	// display_name (name with faction appended) is declared on /obj/structure/overmap
	/// Whether this ship has been abandoned (no crew, claimable by anyone)
	var/abandoned = FALSE
	/// world.time abandon_ship() ran. The derelict-despawn clock: once it is
	/// SHIP_DERELICT_DESPAWN_TIME old, SSovermap's sweep deletes the hull for good.
	/// Cleared by claim_abandoned_ship().
	var/abandoned_at = 0
	/// world.time SSovermap's sweep first found no living, connected player aboard;
	/// 0 while anyone is. At SHIP_CREWLESS_ABANDON_TIME the hull is abandoned - this
	/// is the trigger crew death alone never provided (log off, cryo, walk away).
	var/crewless_since = 0
	/// world.time the sweep first found this hull berthed at a dynamic encounter with
	/// nothing alive at the site: nobody aboard, no living player anywhere on the site's
	/// own z-levels, and no living NPC crew of its own. 0 whenever that stops holding.
	/// At SHIP_SITE_DEAD_UNDOCK_TIME the hull is force-undocked so the site can release.
	var/site_dead_since = 0
	/// TRUE while the force-undock above is being refused (a cooldown, a hull overhang),
	/// so the retry logs its reason once per streak instead of once a minute.
	var/site_dead_undock_refused = FALSE

	/**
	 * Player-facing Ship stuff.
	 */
	///Shipwide bank account
	var/datum/bank_account/ship/ship_account
	///Credits the shipwide account is seeded with when the ship is set up.
	var/starting_credits = 1000
	///Voidcrew-unique team we link everyone's mind to.
	var/datum/team/voidcrew/ship_team

	///Name of the ship.
	var/map_name
	///Short memo of the ship, set by the crew, and shown to latejoiners.
	var/memo

	///Timer between job managing delays
	COOLDOWN_DECLARE(job_slot_adjustment_cooldown)
	///The overmap object the ship is docked to, if any
	var/obj/structure/overmap/docked
	///Cache key of the overmap parallax context last broadcast to the crew (see update_crew_parallax_context)
	var/parallax_context_key
	///Manifest list of people on the ship
	var/list/manifest = list()
	///Assoc list of remaining open job slots (job = remaining slots)
	var/list/job_slots
	///Assoc list of initial job slot counts (job = initial slots) - used for max slot calculations
	var/list/initial_job_slots
	///Assoc list of selected ship upgrades (slot_key = /datum/ship_upgrade_module)
	var/list/upgrade_selections = list()
	/// Theme of this ship (e.g., "pirate", "science"). Used to load themed module variants.
	var/theme = null

	/**
	 * Movement stuff
	 */

	///Vessel approximate mass
	var/mass


	/// Which docking port the ship is occupying
	var/dock_index
	///~~If we need to render a map for cameras and helms for this object~~ basically can you look at and use this as a ship or station
	var/render_map = TRUE
	/**
	 * Stuff needed to render the map
	 */
	/// The actual map screen (using camera subtype for proper rendering). Unused
	/// since the helm chart moved client-side; see the note in Initialize().
	var/atom/movable/screen/map_view/camera/cam_screen
	/// Helm consoles bound to this ship. Each is pushed a UI frame as the ship
	/// crosses a tile so the chart's glide stays in step with the move loop.
	var/list/obj/machinery/computer/helm/helm_consoles

	var/datum/weakref/survey_console
	var/datum/survey_research/survey_data

	// ===== MISSIONS =====
	/// Available missions this ship can accept
	var/list/datum/mission/available_missions = list()
	/// Currently active missions this ship has accepted
	var/list/datum/mission/active_missions = list()
	/// Maximum number of active missions (captain can adjust)
	var/max_missions = DEFAULT_MAX_ACTIVE_MISSIONS
	/// World time of the last manual mission refresh (rate-limited)
	var/last_mission_refresh = 0


	/// Weakref to the overmap site we're waiting on to finish generating (see
	/// request_site_load). The helm is never held while a site generates - the
	/// approach resumes automatically off COMSIG_VOIDCREW_SITE_LOAD_FINISHED.
	var/datum/weakref/awaiting_load_site
	/// Weakref to the mob that asked for that approach; used to resume it (may be null).
	var/datum/weakref/awaiting_load_user


	/// Weakref to the NPC pirate ship currently engaging this ship (only one pirate can engage at a time)
	var/datum/weakref/engaging_pirate_ref


	/// Mission pads installed on this ship (for pirate tribute delivery, mission rewards, etc.)
	var/list/obj/machinery/mission_pad/linked_mission_pads = list()

	/// List of ships that currently have a weapons lock on us (prevents cloaking)
	var/list/locked_on_by = list()

	/// Combat alarm that plays when weapons are locked on this ship
	var/datum/combat_alarm/combat_alarm



	/// Cooldown preventing undocking shortly after docking
	COOLDOWN_DECLARE(undock_cooldown)

/// Process tick for ship - handles shield regeneration and continuous thrust
/// Uses SSfastprocess (0.2s) when thrusting, SSobj (2s) when only shields active
/obj/structure/overmap/ship/process(seconds_per_tick)
	// Handle continuous thrust (only when actively thrusting)
	if(thrust_processing && burn_direction != BURN_NONE)
		if(state != OVERMAP_SHIP_FLYING || zone_transitioning)
			// Stop thrusting if we can't fly. Leaving the flying state drops the
			// commanded course with it; a zone transition doesn't - the latch
			// (zone_resume_burn) owns the course for the length of the crossing.
			if(state != OVERMAP_SHIP_FLYING)
				commanded_course = BURN_NONE
			burn_direction = BURN_NONE
		else if(burn_direction == BURN_STOP)
			// Active braking - decelerate toward zero
			if(is_still())
				burn_direction = BURN_NONE
			else
				burn_engines(null, burn_percentage, seconds_per_tick)
		else if(can_thrust())
			burn_engines(burn_direction, burn_percentage, seconds_per_tick)
			check_cruise()
		else if(!hidden_in_nebula)
			// The crew is holding a heading and getting nothing. can_thrust() failing
			// is invisible from the helm (the gauges can look healthy), so say so.
			// Nebula concealment is excluded: refusing to thrust there is deliberate.
			warn_no_thrust()

	// Handle shield regeneration
	if(shields_active && !shields_broken)
		regenerate_shields(seconds_per_tick)

	// Check for shield cooldown recovery
	if(shields_broken && COOLDOWN_FINISHED(src, shield_reactivation_cooldown))
		reactivate_ship_shields()

	// Update which subsystem we should be on based on current needs
	update_ship_processing()

/obj/structure/overmap/ship/Initialize(mapload, datum/map_template/shuttle/voidcrew/template)
	. = ..()
	// Template setup is now handled by setup_from_template() called from create_ship
	// This allows proper template passing without relying on Initialize arg chain
	if(template)
		setup_from_template(template)

/**
 * Sets up the ship from a template. Called after Initialize.
 * If a theme is provided, uses the theme's job_slots instead of template's.
 * Returns TRUE on success, FALSE on failure.
 */
/obj/structure/overmap/ship/proc/setup_from_template(datum/map_template/shuttle/voidcrew/template, datum/ship_theme/selected_theme)
	if(!template)
		return FALSE

	if(source_template) // Already set up
		return TRUE

	src.source_template = template

	ship_team = new()
	ship_team.name = template.name
	ship_team.ship = src

	// Pick a random bright color for ship runechat
	var/static/list/ship_chat_colors = list(
		COLOR_SOFT_RED,
		COLOR_ORANGE,
		COLOR_VIVID_YELLOW,
		COLOR_LIME,
		COLOR_JADE,
		COLOR_CYAN,
		COLOR_BLUE_LIGHT,
		COLOR_BRIGHT_BLUE,
		COLOR_FADED_PINK,
		COLOR_VIOLET,
	)
	chat_color = pick(ship_chat_colors)

	// Build job slots from theme if provided, otherwise from template
	var/list/job_slot_definitions
	if(selected_theme?.job_slots && length(selected_theme.job_slots))
		job_slot_definitions = selected_theme.job_slots.Copy()
	else
		job_slot_definitions = source_template.job_slots.Copy()

	// Modules can contribute extra crew via job_slots_add; appended after the theme's
	// own slots so the first entry (the captain) stays the supervisor
	if(source_template.has_upgrade_slots)
		var/list/slot_ids = selected_theme?.upgrade_slot_ids || source_template.upgrade_slot_ids
		job_slot_definitions += get_module_job_definitions(source_template.type, upgrade_selections, slot_ids, selected_theme?.id)

	job_slots = assemble_job_slots_from_list(job_slot_definitions)

	// Store initial slot counts for max slot calculations in cryo console
	// This is an assoc list (job datum -> slot count), same format as job_slots
	initial_job_slots = job_slots.Copy()

	//then the account, which relies on there having a job, as we set it to the captain's.
	ship_account = new(newname = ship_team.name, job = job_slots[1], player_account = FALSE)
	if(starting_credits > 0)
		ship_account.adjust_money(starting_credits, "Fleet: commissioning funds")

	display_name = template.name

	// The helm used to render the overmap through this camera map instance; it now
	// draws the chart client-side from get_contact_snapshot(), and nothing else
	// consumed cam_screen. Left unallocated so update_screen() short-circuits and
	// the move loop stops paying for a view() sweep nobody looks at. Re-enable
	// here if a console ever needs a real camera feed of the overmap again.

	SSovermap.simulated_ships += src
	// Anything already broadcasting to the galaxy (the Verdigris, the Colosseum, a
	// contested cache) charted itself onto the fleet before this hull existed;
	// collect those now so a mid-round ship's helm isn't blind to them.
	receive_fleet_waypoints()
	survey_data = new()

	// Initialize combat alarm system
	combat_alarm = new(src)
	RegisterSignal(src, COMSIG_SHIP_WEAPONS_LOCKED, PROC_REF(on_weapons_locked))
	RegisterSignal(src, COMSIG_SHIP_WEAPONS_LOCK_LOST, PROC_REF(on_weapons_lock_lost))

	// Player ships have no access requirements on doors
	clear_door_access()

	return TRUE

/**
 * Removes all access requirements from doors on this ship.
 * Called when player ships spawn and when NPC ships are claimed.
 */
/obj/structure/overmap/ship/proc/clear_door_access()
	if(!shuttle?.shuttle_areas)
		return
	for(var/area/shuttle_area as anything in shuttle.shuttle_areas)
		for(var/obj/machinery/door/door in shuttle_area)
			door.req_access = null
			door.req_one_access = null

/obj/structure/overmap/ship/Destroy()
	GLOB.crew_locked_ships -= src
	QDEL_LIST(crew_applications)
	source_template = null
	var/obj/docking_port/mobile/owned_shuttle = detach_shuttle()
	owned_shuttle?.intoTheSunset()
	SSovermap.simulated_ships -= src
	QDEL_NULL(ship_account)
	manifest?.Cut()
	job_slots?.Cut()
	initial_job_slots?.Cut()
	QDEL_NULL(ship_team)
	QDEL_NULL(cam_screen) // cam_background is inside cam_screen and deleted with it
	LAZYNULL(helm_consoles)
	contact_snapshot = null
	discovered_contacts = null
	dismissed_contacts = null
	identified_ships = null
	surveyed_tiles = null
	QDEL_NULL(combat_alarm)
	// A destroyed or despawned hull stops calling for help: drops the repeat
	// timer, the Wideband transmitter and the sprite filter (distress.dm).
	clear_distress_beacon()
	// Clean up processing (thrust and/or shields)
	burn_direction = BURN_NONE
	commanded_course = BURN_NONE
	thrust_processing = FALSE
	autopilot_engaged = FALSE
	autopilot_path = null
	if(autopilot_poll_timer)
		deltimer(autopilot_poll_timer)
		autopilot_poll_timer = null
	STOP_PROCESSING(SSfastprocess, src)
	STOP_PROCESSING(SSobj, src)
	// Clean up missions
	QDEL_LIST(available_missions)
	QDEL_LIST(active_missions)
	QDEL_LIST(waypoints)
	QDEL_LIST(pending_rumors)
	return ..()

/obj/structure/overmap/ship/attack_ghost(mob/user)
	if(shuttle)
		user.forceMove(get_turf(shuttle))
		return TRUE
	else
		return

/// Updates the screen for the helm console
/obj/structure/overmap/ship/proc/update_screen()
	if(!cam_screen)
		return

	var/list/visible_turfs = list()
	var/turf/ship_turf = get_turf(src)
	var/list/visible_things = view(SHIP_VIEW_RANGE, ship_turf)

	for(var/turf/visible_turf in visible_things)
		visible_turfs += visible_turf

	// Handle empty view - show static
	if(!length(visible_turfs))
		cam_screen.show_camera_static()
		return

	var/list/bbox = get_bbox_of_atoms(visible_turfs)
	var/size_x = bbox[3] - bbox[1] + 1
	var/size_y = bbox[4] - bbox[2] + 1

	// Use camera subtype's show_camera method for proper rendering
	cam_screen.show_camera(visible_turfs, size_x, size_y)


/**
 * Pushes a UI frame to every helm bound to this ship, so the chart starts a fresh
 * glide the instant the ship crosses a tile.
 *
 * SStgui's own heartbeat is 0.9s while tick_move() runs at 1/speed deciseconds.
 * Far faster than that under any real burn. Without this the client would see the
 * ship teleport several tiles per update and the interpolation would lurch.
 */
/obj/structure/overmap/ship/proc/push_helm_frame()
	for(var/obj/machinery/computer/helm/console as anything in helm_consoles)
		SStgui.update_uis(console)

/obj/structure/overmap/ship/newtonian_move(direction, instant, start_delay, drift_force, controlled_cap, force_loop)
	return // we don't want ships to endlessly drift in space

/**
 * Minimalist ship notification - sends a styled chat message to all crew members.
 * Much less intrusive than ship_notify/priority_announce.
 *
 * Arguments:
 * * message - The notification message
 * * category - Short category label (e.g. "SCANNER", "COMBAT", "TARGETING")
 * * alert_level - SHIP_NOTIFY_NOTICE (blue), SHIP_NOTIFY_WARNING (orange), or SHIP_NOTIFY_DANGER (red)
 * * sound_file - Optional sound to play. If null, no sound is played.
 * * volume - Volume of the sound (0-100). Defaults to 100.
 */
/obj/structure/overmap/ship/ship_notify(message, category = "ALERT", alert_level = SHIP_NOTIFY_NOTICE, sound_file = null, volume = 100)
	var/formatted
	switch(alert_level)
		if(SHIP_NOTIFY_DANGER)
			formatted = span_bolddanger("[message]")
		if(SHIP_NOTIFY_WARNING)
			formatted = span_boldwarning("[message]")
		else
			formatted = span_boldnotice("[message]")

	for(var/datum/mind/shipmate as anything in ship_team?.members)
		var/mob/crewmate = shipmate.current
		if(!crewmate)
			continue
		to_chat(crewmate, formatted)
		if(sound_file)
			var/pref_volume = crewmate.client?.prefs.read_preference(/datum/preference/numeric/volume/sound_ship_ambience_volume)
			if(!pref_volume)
				continue
			var/sound/S = sound(sound_file)
			S.volume = volume * (pref_volume / 100)
			SEND_SOUND(crewmate, S)

// ===== COMBAT TARGET API (see /obj/structure/overmap base hooks) =====

/obj/structure/overmap/ship/is_combat_targetable()
	return TRUE

/obj/structure/overmap/ship/get_combat_target_areas()
	return shuttle?.shuttle_areas

/obj/structure/overmap/ship/get_combat_bounds()
	if(!shuttle)
		return null
	var/list/bounds = shuttle.return_coords()
	if(!bounds || bounds.len < 4)
		return null
	return list(min(bounds[1], bounds[3]), min(bounds[2], bounds[4]), max(bounds[1], bounds[3]), max(bounds[2], bounds[4]))

/obj/structure/overmap/ship/combat_camera_can_view(turf/T)
	if(!shuttle)
		return FALSE
	var/area/dest_area = get_area(T)
	return dest_area && (dest_area in shuttle.shuttle_areas)

/obj/structure/overmap/ship/get_combat_camera_turfs()
	if(!shuttle?.shuttle_areas)
		return null
	. = list()
	for(var/area/ship_area in shuttle.shuttle_areas)
		for(var/turf/T in ship_area)
			. += T

/obj/structure/overmap/ship/get_combat_default_turf()
	if(shuttle)
		return get_turf(shuttle)
	return null

// ship_broadcast_runechat() moved to transmissions.dm. It used to paint a
// maptext overlay onto this atom for the helm's camera map to render; that camera
// is gone, so the overlay had no renderer and hails were invisible to everyone.
// Transmissions are data the helm reads now.

// The death-triggered deletion timer that used to live here is gone, and with it
// /datum/team/voidcrew/is_active_team(), its only caller. It armed a fire-and-forget
// ten-minute abandon_ship() the moment a crewman died with nobody left on the hull's
// z-level, and nothing but that same crewman being revived, or a latejoin, could call
// it off - a crew that fought its way back aboard in the meantime lost the ship
// anyway, and a hull could go derelict in ten minutes flat while the crewless clock
// still read twenty. SSovermap.sweep_derelicts() covers every way a hull empties,
// death included, re-reads occupancy every minute instead of committing up front, and
// is the only abandonment path now. register_crewmember() no longer hooks
// COMSIG_LIVING_DEATH at all.



/obj/structure/overmap/ship/update_icon_state()
	if(mass < SHIP_SIZE_THRESHOLD)
		base_icon_state = "shuttle"
	else
		base_icon_state = "ship"
	if(!is_still())
		icon_state = "[base_icon_state]_moving"
		dir = get_heading()
	else
		icon_state = base_icon_state
	return ..()

/// Global helper to get the ship an atom is currently on
/// Returns null if the atom is not on a ship
/proc/get_ship_from_atom(atom/source)
	var/obj/docking_port/mobile/voidcrew/port = SSshuttle.get_containing_shuttle(source)
	return istype(port) ? port.current_ship : null

// ===== MISSION PROCS =====

/**
 * Accepts a mission, moving it from available to active.
 * * mission - The mission to accept
 * Returns TRUE on success, error string on failure.
 */
/obj/structure/overmap/ship/proc/accept_mission(datum/mission/mission)
	if(!mission)
		return "Invalid mission."
	if(!(mission in available_missions))
		return "Mission not available."
	if(length(active_missions) >= max_missions)
		return "Your ship's active mission limit reached ([max_missions])."
	if(mission.active)
		return "Mission already accepted."
	// Boards can hold more copies of a capped contract than the cap allows (the
	// roll only counts live missions), so the cap has to hold here too or N ships
	// run the same "limit 1" job at once.
	if(!mission_type_within_limit(mission.type, mission))
		return "Global contract limit reached for this type (all ships)."

	if(!mission.start_mission(src))
		return "Failed to start mission."

	return TRUE

/**
 * Completes a mission via turn-in.
 * * mission - The mission to complete
 * * reward_anchor - The turn-in machine (ship mission pad or outpost contract board)
 * * item - Optional item being turned in
 * Returns TRUE on success, error string on failure.
 */
/obj/structure/overmap/ship/proc/complete_mission(datum/mission/mission, atom/reward_anchor, obj/item/item)
	if(!mission)
		return "Invalid mission."
	if(!(mission in active_missions))
		return "Mission not active on this ship."

	// Pre-validate before attempting turn-in for better error messages
	if(!mission.can_turn_in_at(reward_anchor))
		return mission.get_wrong_location_reason(reward_anchor)
	if(mission.requires_item)
		if(!mission.can_turn_in(item))
			return mission.get_failure_reason(item)
	else
		if(!mission.can_complete())
			return mission.get_failure_reason(item)

	if(!mission.turn_in(reward_anchor, item))
		return "Failed to complete mission."

	return TRUE

// ===== COMBAT ALARM SIGNAL HANDLERS =====

/// Called when a ship acquires a weapons lock on us
/obj/structure/overmap/ship/proc/on_weapons_locked(datum/source, obj/structure/overmap/ship/attacker)
	SIGNAL_HANDLER
	if(!attacker)
		return
	if(attacker in locked_on_by)
		return // Already tracking this attacker

	locked_on_by += attacker
	// Track when the attacker is deleted so we can clean up
	RegisterSignal(attacker, COMSIG_QDELETING, PROC_REF(on_attacker_deleted))

	// Nobody should be flying a plotted course while someone has a firing solution
	// on them (see autopilot.dm).
	interrupt_autopilot("weapons lock detected")

	// Start the combat alarm if this is the first lock
	// if(length(locked_on_by) == 1 && combat_alarm)
	// 	combat_alarm.start()

/// Called when a ship loses their weapons lock on us
/obj/structure/overmap/ship/proc/on_weapons_lock_lost(datum/source, obj/structure/overmap/ship/attacker)
	SIGNAL_HANDLER
	if(!attacker)
		return
	if(!(attacker in locked_on_by))
		return // Not tracking this attacker

	locked_on_by -= attacker
	UnregisterSignal(attacker, COMSIG_QDELETING)

	// Stop the combat alarm if no more locks
	if(!length(locked_on_by) && combat_alarm)
		combat_alarm.stop()

/// Called when an attacker that had us locked is deleted
/obj/structure/overmap/ship/proc/on_attacker_deleted(obj/structure/overmap/ship/attacker)
	SIGNAL_HANDLER
	if(!(attacker in locked_on_by))
		return
	locked_on_by -= attacker

	// Stop the combat alarm if no more locks
	if(!length(locked_on_by) && combat_alarm)
		combat_alarm.stop()

#undef SHIP_SIZE_THRESHOLD
