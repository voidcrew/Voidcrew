///Threshold above which it uses the ship sprites instead of the shuttle sprites
#define SHIP_SIZE_THRESHOLD 150

#define SHIP_RUIN (10 MINUTES)
#define SHIP_DELETE (10 MINUTES)
#define SHIP_VIEW_RANGE 4
#define SHIP_SPEED_MULTIPLIER_DEFAULT 1

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
	///Name of the Ship with the faction appended to it
	var/display_name
	///How long until the ship will delete itself.
	var/deletion_timer
	///Timer ID of the looping movement timer
	var/movement_callback_id

	/**
	 * Player-facing Ship stuff.
	 */
	///Shipwide bank account
	var/datum/bank_account/ship/ship_account
	///Voidcrew-unique team we link everyone's mind to.
	var/datum/team/voidcrew/ship_team

	///Boolean on whether players are allowed to latejoin into this ship, toggled by the job managing console.
	var/joining_allowed = TRUE
	///Name of the ship.
	var/map_name
	///Short memo of the ship, set by the crew, and shown to latejoiners.
	var/memo
	///ONLY USED FOR NON-SIMULATED SHIPS. The amount per burn that this ship accelerates
	var/acceleration_speed = 0.02
	///Cooldown until the ship can be renamed again
	COOLDOWN_DECLARE(rename_cooldown)

	///Timer between job managing delays
	COOLDOWN_DECLARE(job_slot_adjustment_cooldown)
	///The overmap object the ship is docked to, if any
	var/obj/structure/overmap/docked
	///Manifest list of people on the ship
	var/list/manifest = list()
	///Assoc list of remaining open job slots (job = remaining slots)
	var/list/job_slots

	/**
	 * Movement stuff
	 */
	var/y_thrust = 0
	var/x_thrust = 0
		///Max possible speed (1 tile per second)
	var/static/max_speed = 1/(1 SECONDS)
	///Minimum speed. Any lower is rounded down. (0.5 tiles per minute)
	var/static/min_speed = 1/(2 MINUTES)
	///The current speed in x/y direction in grid squares per minute
	var/list/speed[2]
	///Vessel estimated thrust
	var/est_thrust
	///Average fuel fullness percentage
	var/avg_fuel_amnt = 100

	///Vessel approximate mass
	var/mass

	/// Linked shield generators for ship defense (multiple generators stack)
	var/list/obj/machinery/ship_combat/shield_generator/linked_shield_generators = list()

	// ===== SHARED SHIELD POOL =====
	/// Current shared shield health (all generators contribute to this pool)
	var/shield_health = 0
	/// Maximum shared shield health (sum of all generator max_health)
	var/shield_max_health = 0
	/// Current overhealth (extra shield beyond max from >100% power)
	var/shield_overhealth = 0
	/// Combined regeneration rate (sum of all generator regen_rates)
	var/shield_regen_rate = 0
	/// Are shields currently active? (any generator online)
	var/shields_active = FALSE
	/// Are shields broken? (health reached 0, on cooldown)
	var/shields_broken = FALSE
	/// Cooldown for shield reactivation after breaking
	COOLDOWN_DECLARE(shield_reactivation_cooldown)
	/// Current power allocation for shields (0.0 to 2.0) - synchronized across all generators
	var/shield_power_allocation = 0

	/// Which docking port the ship is occupying
	var/dock_index
	///~~If we need to render a map for cameras and helms for this object~~ basically can you look at and use this as a ship or station
	var/render_map = TRUE
	/**
	 * Stuff needed to render the map
	 */
	/// The actual map screen (using camera subtype for proper rendering)
	var/atom/movable/screen/map_view/camera/cam_screen

	var/datum/weakref/survey_console
	var/datum/survey_research/survey_data

	// ===== MISSIONS =====
	/// Available missions this ship can accept
	var/list/datum/mission/available_missions = list()
	/// Currently active missions this ship has accepted
	var/list/datum/mission/active_missions = list()
	/// Maximum number of active missions (captain can adjust)
	var/max_missions = DEFAULT_MAX_ACTIVE_MISSIONS

	var/pending_dock = FALSE
	var/pending_dock_timer
	/// The ship we sent a docking request to (if any)
	var/obj/structure/overmap/ship/pending_dock_target

	/// Speed multiplier for external effects like interdiction (1 = normal, 0.5 = half speed)
	var/speed_multiplier = SHIP_SPEED_MULTIPLIER_DEFAULT
	/// Whether this ship is currently being interdicted
	var/is_interdicted = FALSE
	/// Cooldown preventing undocking after being interdicted
	COOLDOWN_DECLARE(interdiction_undock_lockout)
	/// Weakref to the interdictor machine currently affecting this ship
	var/datum/weakref/interdicting_machine_ref
	/// Current interdiction strength for UI display (0 to 1, where 1 = maximum effect)
	var/interdiction_strength = 0

	/// List of interdictor machines installed on this ship
	var/list/linked_interdictors = list()

	// ===== ZONE TRANSITION =====
	/// Whether we're currently transitioning between zones (10 second delay)
	var/zone_transitioning = FALSE
	/// Timer ID for zone transition completion
	var/zone_transition_timer
	/// The target turf we're trying to transition to
	var/turf/zone_transition_target
	/// When the zone transition started (for progress calculation)
	var/zone_transition_start_time

	// ===== RADIATION SHIELDING =====
	/// Current radiation shielding level (SHIP_SHIELDING_NONE, STANDARD, or HEAVY)
	var/radiation_shielding_level = SHIP_SHIELDING_NONE
	/// Linked techweb for radiation shielding auto-upgrades
	var/datum/techweb/linked_techweb

	/// Cooldown preventing undocking shortly after docking
	COOLDOWN_DECLARE(undock_cooldown)
	/// Timer ID for dock warmup
	var/dock_warmup_timer
	/// Timer ID for undock warmup
	var/undock_warmup_timer

// ===== SHARED SHIELD POOL PROCS =====

/// Recalculates shield stats from all linked generators
/// Call this when generators are added/removed or parts upgraded
/obj/structure/overmap/ship/proc/recalculate_shield_stats()
	var/new_max_health = 0
	var/new_regen_rate = 0

	for(var/obj/machinery/ship_combat/shield_generator/gen in linked_shield_generators)
		if(gen.machine_stat & (BROKEN|NOPOWER))
			continue
		// Each generator contributes its stats
		new_max_health += gen.max_shield_health
		new_regen_rate += gen.regen_rate

	shield_max_health = new_max_health
	shield_regen_rate = new_regen_rate

	// If max health decreased and current health exceeds it, cap it
	if(shield_health > shield_max_health)
		shield_health = shield_max_health

	// Note: shields_active is managed by activate_generator()/deactivate_generator()
	// This proc only updates stats, not activation state

/// Regenerates the shared shield pool - called by shield generators during process()
/obj/structure/overmap/ship/proc/regenerate_shields(seconds_per_tick)
	if(!shields_active || shields_broken)
		return

	// Calculate effective regen rate based on power allocation
	var/effective_regen = shield_regen_rate * shield_power_allocation * seconds_per_tick

	if(shield_health < shield_max_health)
		shield_health = min(shield_health + effective_regen, shield_max_health)
	else if(shield_power_allocation > 1)
		// Generate overhealth when at max and power > 100%
		var/excess = shield_power_allocation - 1
		var/overhealth_rate = shield_regen_rate * excess * seconds_per_tick
		shield_overhealth += overhealth_rate

/// Absorbs incoming damage to the shared shield pool
/// Returns TRUE if damage was absorbed (even partially), FALSE if shields were down
/obj/structure/overmap/ship/proc/absorb_shield_damage(damage, turf/impact_loc)
	if(!shields_active || shields_broken)
		return FALSE

	// First absorb from overhealth
	if(shield_overhealth > 0)
		var/overhealth_absorbed = min(damage, shield_overhealth)
		shield_overhealth -= overhealth_absorbed
		damage -= overhealth_absorbed

	// Then from regular health
	shield_health -= damage

	// Visual and audio effects at impact location
	do_shield_hit_effects(impact_loc)

	// Signal that shield was hit
	SEND_SIGNAL(src, COMSIG_SHIP_SHIELD_HIT, damage, impact_loc)

	// Check for shield break
	if(shield_health <= 0)
		shield_health = 0
		break_ship_shields()

	return TRUE

/// Called when the shared shield pool is depleted
/obj/structure/overmap/ship/proc/break_ship_shields()
	if(!shields_active)
		return

	shields_active = FALSE
	shields_broken = TRUE
	shield_health = 0
	shield_overhealth = 0

	// Start cooldown
	COOLDOWN_START(src, shield_reactivation_cooldown, SHIP_SHIELD_BROKEN_COOLDOWN)

	// Ensure ship keeps processing so it can check cooldown and reactivate
	start_shield_processing()

	// Notify all generators
	for(var/obj/machinery/ship_combat/shield_generator/gen in linked_shield_generators)
		gen.on_ship_shields_broken()

	// Remove shield walls (first generator with walls handles this)
	for(var/obj/machinery/ship_combat/shield_generator/gen in linked_shield_generators)
		if(length(gen.shield_walls))
			gen.destroy_shield_walls()
			break

	SEND_SIGNAL(src, COMSIG_SHIP_SHIELD_BROKEN)

/// Called to reactivate shields after cooldown ends
/obj/structure/overmap/ship/proc/reactivate_ship_shields()
	if(!shields_broken)
		return
	if(!COOLDOWN_FINISHED(src, shield_reactivation_cooldown))
		return

	// Can't reactivate while docked - just clear broken status and stop processing
	if(!isnull(docked))
		shields_broken = FALSE
		stop_shield_processing()
		return

	shields_broken = FALSE

	// Reactivate all generators that want to be active (have power allocation)
	var/any_activated = FALSE
	var/obj/machinery/ship_combat/shield_generator/first_active_gen
	for(var/obj/machinery/ship_combat/shield_generator/gen in linked_shield_generators)
		if(gen.power_allocation > 0 && !(gen.machine_stat & (BROKEN|NOPOWER)))
			gen.active = TRUE
			gen.update_appearance()
			gen.update_power_draw()
			gen.generator_sound?.start()
			if(!first_active_gen)
				first_active_gen = gen
			any_activated = TRUE

	if(any_activated)
		// Recalculate stats and activate
		recalculate_shield_stats()
		shields_active = TRUE
		// Start at 50% health
		shield_health = shield_max_health * 0.5

		// Spawn shield walls from first active generator
		if(first_active_gen)
			first_active_gen.spawn_shield_walls()

		SEND_SIGNAL(src, COMSIG_SHIP_SHIELD_RESTORED)
		playsound(first_active_gen || src, 'sound/vehicles/mecha/mech_shield_raise.ogg', 100, TRUE)
	else
		// No generators want to activate - stop processing
		stop_shield_processing()

/// Sets power allocation for all generators and the ship
/obj/structure/overmap/ship/proc/set_shield_power_allocation(new_allocation)
	shield_power_allocation = clamp(new_allocation, SHIP_SHIELD_MIN_POWER_MULT, SHIP_SHIELD_MAX_POWER_MULT)
	for(var/obj/machinery/ship_combat/shield_generator/gen in linked_shield_generators)
		gen.set_power_allocation(shield_power_allocation)

/// Visual and audio effects for shield hit
/obj/structure/overmap/ship/proc/do_shield_hit_effects(turf/impact_loc)
	// Find the nearest boundary turf for visual effect
	var/turf/effect_loc = impact_loc
	for(var/obj/machinery/ship_combat/shield_generator/gen in linked_shield_generators)
		if(gen.active)
			effect_loc = gen.get_nearest_boundary_turf(impact_loc)
			break

	if(effect_loc)
		new /obj/effect/temp_visual/ship_shield_hit(effect_loc)
		var/sound_file = pick(
			'voidcrew/sound/machines/forcefield/hit1.ogg',
			'voidcrew/sound/machines/forcefield/hit2.ogg',
			'voidcrew/sound/machines/forcefield/hit3.ogg',
			'voidcrew/sound/machines/forcefield/hit4.ogg',
			'sound/vehicles/mecha/mech_shield_deflect.ogg',
		)
		playsound(effect_loc, sound_file, 60, TRUE, extrarange = 10, pressure_affected = FALSE)

/// Returns aggregated shield status for UI
/obj/structure/overmap/ship/proc/get_shield_status()
	// Calculate total power draw and efficiency
	var/total_power_draw = 0
	var/total_efficiency_bonus = 0
	var/gen_count = 0

	for(var/obj/machinery/ship_combat/shield_generator/gen in linked_shield_generators)
		if(!(gen.machine_stat & (BROKEN|NOPOWER)))
			total_power_draw += gen.get_power_draw()
			total_efficiency_bonus += (1 - gen.power_efficiency)
			gen_count++

	var/avg_efficiency = gen_count ? (total_efficiency_bonus / gen_count) * 100 : 0

	return list(
		"active" = shields_active,
		"broken" = shields_broken,
		"health" = round(shield_health),
		"max_health" = round(shield_max_health),
		"overhealth" = round(shield_overhealth),
		"power_allocation" = shield_power_allocation,
		"regen_rate" = round(shield_regen_rate * shield_power_allocation, 0.1),
		"power_draw" = round(total_power_draw),
		"efficiency" = round(avg_efficiency),
		"cooldown_active" = shields_broken && !COOLDOWN_FINISHED(src, shield_reactivation_cooldown),
		"cooldown_remaining" = COOLDOWN_TIMELEFT(src, shield_reactivation_cooldown),
		"generator_count" = length(linked_shield_generators),
	)

/// Starts shield processing on this ship (called when shields activate)
/obj/structure/overmap/ship/proc/start_shield_processing()
	START_PROCESSING(SSobj, src)

/// Stops shield processing on this ship (called when shields deactivate)
/obj/structure/overmap/ship/proc/stop_shield_processing()
	STOP_PROCESSING(SSobj, src)

/// Returns TRUE if this ship is involved in ship-to-ship docking (either we docked to them, or they docked to us)
/// Only counts ships that have COMPLETED docking (state == IDLE), not ships still in transit
/obj/structure/overmap/ship/proc/is_in_ship_to_ship_dock()
	// We must be fully docked (IDLE state) to be in a ship-to-ship dock
	if(state != OVERMAP_SHIP_IDLE)
		return FALSE
	// Check if we are docked to another ship directly
	if(istype(docked, /obj/structure/overmap/ship))
		return TRUE
	// Check if any ship is docked to us directly (and has completed docking)
	for(var/obj/structure/overmap/ship/other_ship in SSovermap.simulated_ships)
		if(other_ship == src)
			continue
		if(other_ship.docked == src && other_ship.state == OVERMAP_SHIP_IDLE)
			return TRUE
	// Check if we're docked to the same empty space as another ship (consensual helm dock)
	// Only count other ships that have completed docking
	if(istype(docked, /obj/structure/overmap/planet/empty))
		for(var/obj/structure/overmap/ship/other_ship in SSovermap.simulated_ships)
			if(other_ship == src)
				continue
			if(other_ship.docked == docked && other_ship.state == OVERMAP_SHIP_IDLE)
				return TRUE
	return FALSE

/// Process tick for ship - handles shield regeneration
/obj/structure/overmap/ship/process(seconds_per_tick)
	// Handle shield regeneration
	if(shields_active && !shields_broken)
		regenerate_shields(seconds_per_tick)

	// Check for shield cooldown recovery
	if(shields_broken && COOLDOWN_FINISHED(src, shield_reactivation_cooldown))
		reactivate_ship_shields()

	// If shields are no longer active and not broken, stop processing
	if(!shields_active && !shields_broken)
		stop_shield_processing()

/obj/structure/overmap/ship/Initialize(mapload, datum/map_template/shuttle/voidcrew/template)
	. = ..()
	// Template setup is now handled by setup_from_template() called from create_ship
	// This allows proper template passing without relying on Initialize arg chain
	if(template)
		setup_from_template(template)

/**
 * Sets up the ship from a template. Called after Initialize.
 * Returns TRUE on success, FALSE on failure.
 */
/obj/structure/overmap/ship/proc/setup_from_template(datum/map_template/shuttle/voidcrew/template)
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

	//now build the job slots.
	job_slots = source_template.assemble_job_slots()

	//then the account, which relies on there having a job, as we set it to the captain's.
	ship_account = new(newname = ship_team.name, job = job_slots[1], player_account = FALSE)

	display_name = template.name

	if(render_map)	// Initialize map objects
		map_name = "overmap_[REF(src)]_map"

		// Use camera subtype which properly handles cam_background internally
		cam_screen = new /atom/movable/screen/map_view/camera()
		cam_screen.generate_view(map_name)
		update_screen()

	SSovermap.simulated_ships += src
	survey_data = new()

	return TRUE

/obj/structure/overmap/ship/Destroy()
	source_template = null
	shuttle?.intoTheSunset()
	shuttle = null
	SSovermap.simulated_ships -= src
	QDEL_NULL(ship_account)
	manifest?.Cut()
	job_slots?.Cut()
	QDEL_NULL(ship_team)
	QDEL_NULL(cam_screen) // cam_background is inside cam_screen and deleted with it
	// Clean up missions
	QDEL_LIST(available_missions)
	QDEL_LIST(active_missions)
	return ..()

/obj/structure/overmap/ship/attack_ghost(mob/user)
	if(shuttle)
		user.forceMove(get_turf(shuttle))
		return TRUE
	else
		return

/**
  * Just double checks all the engines on the shuttle
  */
/obj/structure/overmap/ship/proc/refresh_engines()
	var/calculated_thrust
	for(var/obj/machinery/power/shuttle_engine/ship/E in shuttle.engine_list)
		if (QDELETED(E)) //Garant that we has no ghost engines.
			shuttle.engine_list -= E
			continue
		E.update_engine()
		if(E.enabled)
			calculated_thrust += E.engine_power
	est_thrust = calculated_thrust

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


/// Resets the ships thrust back to zero
/obj/structure/overmap/ship/proc/reset_thrust()
	if (abs(x_thrust) > 1)
		x_thrust += (1 * ((x_thrust > 0) ? -1 : 1))
	else
		x_thrust = 0

	if (abs(y_thrust) > 1)
		y_thrust += (1 * ((y_thrust > 0) ? -1 : 1))
	else
		y_thrust = 0

/// Move the ship object
/obj/structure/overmap/ship/proc/try_move()
	var/x_dir = (x_thrust > 0) ? 1 : -1
	var/y_dir = (y_thrust > 0) ? 1 : -1
	if (!x_thrust)
		x_dir = 0
	if (!y_thrust)
		y_dir = 0

	Move(locate(x + x_dir, y + y_dir, z))

/// Apply thrust to the ship object
/obj/structure/overmap/ship/proc/apply_thrust(x = 0, y = 0)
	if (x_thrust == 0 && y_thrust == 0)
		addtimer(CALLBACK(src, PROC_REF(do_move)), 0.5 SECONDS)
	x_thrust += x
	y_thrust += y

/// Fires the ship move loop
/obj/structure/overmap/ship/proc/do_move()
	if (x_thrust == 0 && y_thrust == 0)
		return

	try_move()
	update_screen()
	addtimer(CALLBACK(src, PROC_REF(do_move)), (1 / calculate_thrust()) SECONDS)

/// Calculates the current thrust of the ship
/obj/structure/overmap/ship/proc/calculate_thrust()
	return sqrt((x_thrust ** 2) + (y_thrust ** 2))

/obj/structure/overmap/ship/newtonian_move(direction, instant, start_delay)
	return // we don't want ships to endlessly drift in space

/**
  * Bastardized version of GLOB.manifest.manifest_inject, but used per ship
  */
/obj/structure/overmap/ship/proc/manifest_inject(mob/living/carbon/human/H, datum/job/human_job)
	set waitfor = FALSE
	if(H.mind && !length(H.mind.special_roles)) // Check if not an antag
		manifest[H.real_name] = human_job
	register_crewmember(H)

/obj/structure/overmap/ship/proc/register_crewmember(mob/living/carbon/human/crewmate)
	ship_team.add_member(crewmate.mind)
	RegisterSignal(crewmate, COMSIG_LIVING_DEATH, PROC_REF(on_member_death))

	//set their ID to use our bank account
	var/obj/item/card/id/card = crewmate.wear_id
	if(!istype(card))
		return
	var/datum/bank_account/account = SSeconomy.bank_accounts_by_id["[crewmate.account_id]"]
	if(account)
		qdel(account) //delete the individual account.
		card.registered_account = ship_account
		ship_account.bank_cards += card

	crewmate.mind.wipe_memory() //clears ALL memories, but currently all they have is their old bank account.
	crewmate.mind.assigned_role.paycheck_department = ship_team.name

/**
 * ##destroy_ship
 *
 * Deletes the ship, if there's no humans on.
 */
/obj/structure/overmap/ship/proc/destroy_ship(force)
	if(!force && (length(shuttle.get_all_humans()) > 0))
		return
	message_admins("\[SHUTTLE]: [shuttle.name] has been deleted!")
	log_shuttle("[shuttle.name] has been deleted!")
	shuttle.jumpToNullSpace()
//	update_docked_bools() //voidcrew todo: ship functionality
	qdel(src)

/obj/structure/overmap/ship/proc/ship_announce(message, title, must_be_same_z_level = FALSE, sound)
	var/list/announce_targets = list()
	for(var/datum/mind/shipmate as anything in ship_team.members)
		var/mob/crewmate = shipmate.current
		if(!crewmate)
			continue
		if(must_be_same_z_level && crewmate.z != z)
			continue
		announce_targets += crewmate
	priority_announce(message, title, sound || 'sound/announcer/default/attention.ogg', null, "[name] Announcement", players = announce_targets)

/**
 * Broadcasts a message as runechat above the ship on the overmap.
 * All crew members will see the floating text appear above the ship.
 */
/obj/structure/overmap/ship/proc/ship_broadcast_runechat(message)
	// Create a mutable appearance for the text overlay
	var/mutable_appearance/text_overlay = new
	text_overlay.plane = RUNECHAT_PLANE
	text_overlay.appearance_flags = APPEARANCE_UI_IGNORE_ALPHA | KEEP_APART | RESET_TRANSFORM
	text_overlay.alpha = 255
	text_overlay.pixel_y = 32
	text_overlay.maptext_width = 128
	text_overlay.maptext_height = 48
	text_overlay.maptext_x = -48
	text_overlay.maptext = MAPTEXT("<span style='text-align: center; color: [chat_color || "#FFFFFF"]'>[message]</span>")

	// Add as overlay to ship (visible through cam_screen vis_contents)
	overlays += text_overlay

	// Remove after delay
	addtimer(CALLBACK(src, PROC_REF(remove_broadcast_overlay), text_overlay), 3 SECONDS)

/// Removes a broadcast overlay from the ship
/obj/structure/overmap/ship/proc/remove_broadcast_overlay(mutable_appearance/text_overlay)
	overlays -= text_overlay

/**
 * Mob death/revive
 *
 * Handles when a mob is killed and revived, to check if a ship should be deleted or not.
 */
/obj/structure/overmap/ship/proc/on_member_death(mob/living/target, gibbed)
	SIGNAL_HANDLER
	RegisterSignal(target, COMSIG_LIVING_REVIVE, PROC_REF(on_member_revive)) //if they come back.

	if(!ship_team.is_active_team(src) && !deletion_timer)
		start_deletion_timer()

/obj/structure/overmap/ship/proc/on_member_revive(mob/living/target, gibbed)
	SIGNAL_HANDLER

	if(deletion_timer)
		end_deletion_timer()

	UnregisterSignal(target, COMSIG_LIVING_REVIVE)

/**
 * Start/end deletion timers
 *
 * Starts and ends the timers to delete the ship
 */
/obj/structure/overmap/ship/proc/start_deletion_timer()
	switch(state)
		if(OVERMAP_SHIP_FLYING, OVERMAP_SHIP_UNDOCKING, OVERMAP_SHIP_ACTING)
			message_admins("\[SHUTTLE]: [display_name] has been queued for deletion in [SHIP_DELETE / 600] minutes! [ADMIN_COORDJMP(shuttle.loc)]")
			deletion_timer = addtimer(CALLBACK(src, PROC_REF(destroy_ship)), SHIP_DELETE, (TIMER_STOPPABLE|TIMER_UNIQUE))
		if(OVERMAP_SHIP_IDLE, OVERMAP_SHIP_DOCKING)
			message_admins("\[SHUTTLE]: [display_name] has been queued for ruin conversion in [SHIP_RUIN / 600] minutes! [ADMIN_COORDJMP(shuttle.loc)]")
			deletion_timer = addtimer(CALLBACK(shuttle, TYPE_PROC_REF(/obj/docking_port/mobile/voidcrew/, mothball)), SHIP_RUIN, (TIMER_STOPPABLE|TIMER_UNIQUE))

/obj/structure/overmap/ship/proc/end_deletion_timer()
	deltimer(deletion_timer)
	deletion_timer = null



/**
  * Acts on the specified option. Used for docking.
  * * user - Mob that started the action
  * * object - Overmap object to act on
  */
/obj/structure/overmap/ship/proc/overmap_object_act(mob/user, obj/structure/overmap/object, obj/structure/overmap/ship/optional_partner)
	if(!is_still() || state != OVERMAP_SHIP_FLYING)
		to_chat(user, "<span class='warning'>Ship must be still to interact!</span>")
		return

	INVOKE_ASYNC(object, TYPE_PROC_REF(/obj/structure/overmap, ship_act), user, src, optional_partner)

// ===== INTERDICTION PROCS =====

/**
  * Updates the interdiction effect on this ship from an interdictor machine.
  * Called by the interdictor machine when power level changes or warmup progresses.
  * * source - The interdictor machine affecting us
  * * new_multiplier - The new speed multiplier (1 = normal, 0.5 = 50% speed, etc.)
  * * strength - The interdiction strength for UI display (0 to 1)
  */
/obj/structure/overmap/ship/proc/update_interdiction(source, new_multiplier, strength)
	if(!source)
		return
	interdicting_machine_ref = WEAKREF(source)
	speed_multiplier = new_multiplier
	interdiction_strength = strength
	is_interdicted = TRUE

/**
  * Clears the interdiction effect on this ship.
  * Called when interdiction ends for any reason.
  */
/obj/structure/overmap/ship/proc/clear_interdiction()
	interdicting_machine_ref = null
	speed_multiplier = SHIP_SPEED_MULTIPLIER_DEFAULT
	interdiction_strength = 0
	is_interdicted = FALSE

/// Dock warmup time in deciseconds
#define DOCK_WARMUP_TIME (10 SECONDS)
/// Undock warmup time in deciseconds
#define UNDOCK_WARMUP_TIME (10 SECONDS)
/// Undock cooldown time in deciseconds (after docking, before can undock)
#define UNDOCK_COOLDOWN_TIME (20 SECONDS)

/**
  * Docks the shuttle by requesting a port at the requested spot.
  * * to_dock - The [/obj/structure/overmap] to dock to.
  * * dock_to_use - The [/obj/docking_port/mobile] to dock to.
  * * instant - If TRUE, bypasses the dock warmup (used for force dock)
  */
/obj/structure/overmap/ship/proc/dock(obj/structure/overmap/to_dock, obj/docking_port/stationary/dock_to_use, instant = FALSE)
	// Can't dock while being interdicted (unless it's a force dock)
	if(is_interdicted && !instant)
		ship_announce("DOCKING ABORTED: Interdiction field preventing dock sequence!", "Navigation Alert")
		return "Cannot dock while interdicted!"

	refresh_engines()

	docked = to_dock
	state = OVERMAP_SHIP_DOCKING

	// Check if target is a planet that's still loading
	if(istype(to_dock, /obj/structure/overmap/planet))
		var/obj/structure/overmap/planet/current_planet = to_dock
		current_planet.visited = TRUE
		if(current_planet.loading)
			// Register signal to complete dock when planet finishes loading
			RegisterSignal(current_planet, COMSIG_VOIDCREW_PLANET_LOADED, PROC_REF(on_planet_loaded))
			return "Commencing docking, awaiting zone loading..."

	// Instant dock (force dock) - bypass warmup
	if(instant)
		SEND_SIGNAL(src, COMSIG_VOIDCREW_SHIP_ABOUT_TO_DOCK)
		shuttle.request(dock_to_use)
		shuttle.setTimer(1 SECONDS)
		addtimer(CALLBACK(src, PROC_REF(complete_dock), WEAKREF(to_dock)), 1 SECONDS)
		return "Commencing docking..."

	// Start dock warmup
	ship_announce("Initiating docking sequence. Docking in [DOCK_WARMUP_TIME / 10] seconds.", "Docking Announcement")
	dock_warmup_timer = addtimer(CALLBACK(src, PROC_REF(complete_dock_warmup), dock_to_use, WEAKREF(to_dock)), DOCK_WARMUP_TIME, TIMER_STOPPABLE)
	return "Initiating docking sequence. Docking in [DOCK_WARMUP_TIME / 10] seconds."

/**
  * Called after dock warmup completes - actually begins the shuttle dock
  */
/obj/structure/overmap/ship/proc/complete_dock_warmup(obj/docking_port/stationary/dock_to_use, datum/weakref/to_dock_ref)
	dock_warmup_timer = null

	// Check if we're still in docking state (might have been cancelled)
	if(state != OVERMAP_SHIP_DOCKING)
		return

	var/obj/structure/overmap/to_dock = to_dock_ref?.resolve()
	if(!to_dock)
		state = OVERMAP_SHIP_FLYING
		docked = null
		ship_announce("Docking aborted: destination no longer available.", "Docking Error")
		return

	SEND_SIGNAL(src, COMSIG_VOIDCREW_SHIP_ABOUT_TO_DOCK)
	shuttle.request(dock_to_use)
	ship_announce("Docking now.", "Docking Announcement")
	shuttle.setTimer(1 SECONDS)
	addtimer(CALLBACK(src, PROC_REF(complete_dock), to_dock_ref), 1 SECONDS)

/**
  * Signal handler - completes docking when a planet finishes loading.
  */
/obj/structure/overmap/ship/proc/on_planet_loaded(obj/structure/overmap/planet/source)
	SIGNAL_HANDLER
	UnregisterSignal(source, COMSIG_VOIDCREW_PLANET_LOADED)

	if(state != OVERMAP_SHIP_DOCKING || docked != source)
		return // Ship state changed, abort

	// Get the dock port to use
	var/obj/docking_port/stationary/dock_to_use = shuttle.port_destinations

	// Start dock warmup
	ship_announce("Destination loaded. Docking in [DOCK_WARMUP_TIME / 10] seconds.", "Docking Announcement")
	dock_warmup_timer = addtimer(CALLBACK(src, PROC_REF(complete_dock_warmup), dock_to_use, WEAKREF(source)), DOCK_WARMUP_TIME, TIMER_STOPPABLE)

/**
  * Proc called after a shuttle is moved, used for checking a ship's location when it's moved manually (E.G. calling the mining shuttle via a console)
  */
/obj/structure/overmap/ship/proc/check_loc()
	var/docked_object = shuttle.current_ship
	if(docked_object == loc) //The docked object is correct, move along
		return TRUE
	if(state == OVERMAP_SHIP_DOCKING || state == OVERMAP_SHIP_UNDOCKING)
		return
	if(!istype(loc, /obj/structure/overmap) && is_reserved_level(shuttle)) //The object isn't currently docked, and doesn't think it is. This is correct.
		return TRUE
	if(!istype(loc, /obj/structure/overmap) && !docked_object) //The overmap object thinks it's docked to something, but it really isn't. Move to a random tile on the overmap
		forceMove(SSovermap.get_unused_overmap_square())
		state = OVERMAP_SHIP_FLYING
		update_screen()
		return FALSE
	if(isturf(loc) && docked_object) //The overmap object thinks it's NOT docked to something, but it actually is. Move to the correct place.
		forceMove(docked_object)
		state = OVERMAP_SHIP_IDLE
		decelerate(max_speed)
		update_screen()
		return FALSE
	return TRUE

/**
*	To properly fix the bug of two ships docking at the same time causing issues,
*	we need to keep track of whether or not a ship is requesting to dock at a
*	port IMMEDIATELY after the command is issued.
*	This also includes keeping track of when the ship is no longer there, upon which
*	the bools need to be set to false.
*	This function should be called whenever an action occurs that would remove a ship from the map
*/
/obj/structure/overmap/ship/proc/update_docked_bools()
	var/obj/structure/overmap/dynamic/dockable_place = docked
	if (!dockable_place)
		return
	if (dock_index == 1)
		dockable_place.first_dock_taken = FALSE
		dock_index = 0
	else if (dock_index == 2)
		dockable_place.second_dock_taken = FALSE
		dock_index = 0

/**
  * Undocks the shuttle by launching the shuttle with no destination (this causes it to remain in transit)
  */
/obj/structure/overmap/ship/proc/undock()
	if(!is_still()) //how the hell is it even moving (is the question I've asked multiple times) //fuck you past me this didn't help at all
		decelerate(max_speed)
	if(isturf(loc))
		check_loc()
		return "Ship not docked!"
	if(!shuttle)
		return "Shuttle not found!"
	// Already undocking
	if(state == OVERMAP_SHIP_UNDOCKING)
		return "Already undocking!"
	// Check undock cooldown (after docking)
	if(!COOLDOWN_FINISHED(src, undock_cooldown))
		return "Undock systems stabilizing! [DisplayTimeText(COOLDOWN_TIMELEFT(src, undock_cooldown))] remaining."
	// Check interdiction undock lockout
	if(!COOLDOWN_FINISHED(src, interdiction_undock_lockout))
		return "Undocking systems locked! [DisplayTimeText(COOLDOWN_TIMELEFT(src, interdiction_undock_lockout))] remaining."

	// Start undock warmup
	state = OVERMAP_SHIP_UNDOCKING
	ship_announce("Initiating undocking sequence. Undocking in [UNDOCK_WARMUP_TIME / 10] seconds.", "Undocking Announcement")
	undock_warmup_timer = addtimer(CALLBACK(src, PROC_REF(complete_undock_warmup)), UNDOCK_WARMUP_TIME, TIMER_STOPPABLE)
	return "Initiating undocking sequence. Undocking in [UNDOCK_WARMUP_TIME / 10] seconds."

/**
  * Called after undock warmup completes - actually begins the shuttle undock
  */
/obj/structure/overmap/ship/proc/complete_undock_warmup()
	undock_warmup_timer = null

	// Check if we're still in undocking state (might have been cancelled)
	if(state != OVERMAP_SHIP_UNDOCKING)
		return

	// Don't clear dock flags here - wait until shuttle has actually moved in complete_dock
	// Otherwise the z-level might be unloaded while we're still on it
	// Clear port destinations when undocking from empty space to prevent confusion
	if(istype(docked, /obj/structure/overmap/planet/empty))
		shuttle.port_destinations = null
	// Store docked location for complete_dock to use, then clear it
	var/obj/structure/overmap/undock_from = docked
	docked = null
	shuttle.destination = null
	shuttle.mode = SHUTTLE_IGNITING
	shuttle.setTimer(1 SECONDS)
	addtimer(CALLBACK(src, PROC_REF(complete_dock), WEAKREF(undock_from)), 1 SECONDS)
	// Reset crash flag so ship can crash again if damaged
	has_crash_landed = FALSE

/**
  * Sets the ship, shuttle, and shuttle areas to a new name.
  */

/**
  * Called after the shuttle docks, and finishes the transfer to the new location.
  */
/obj/structure/overmap/ship/proc/complete_dock(datum/weakref/to_dock)
	// Commented out as it was being used by deleting planets during undock
	// var/old_loc = loc
	switch(state)
		if(OVERMAP_SHIP_DOCKING) //so that the shuttle is truly docked first
			if(shuttle.mode == SHUTTLE_CALL || shuttle.mode == SHUTTLE_IDLE)
				var/obj/structure/overmap/docking_target = to_dock?.resolve()
				if(!docking_target) //Panic, somehow the docking target is gone but the shuttle has likely docked somewhere, get it out quickly
					state = OVERMAP_SHIP_FLYING
					shuttle.enterTransit()
					return

				if(istype(docking_target, /obj/structure/overmap/ship)) //hardcoded and bad
					var/obj/structure/overmap/ship/S = docking_target
					S.shuttle.shuttle_areas |= shuttle.shuttle_areas
					// Notify the target ship that we docked to them
					SEND_SIGNAL(S, COMSIG_VOIDCREW_SHIP_DOCKED_BY, src)
				// If docking to empty space, notify any other ships already docked there
				// This creates a ship-to-ship dock situation via shared empty space
				else if(istype(docking_target, /obj/structure/overmap/planet/empty))
					for(var/obj/structure/overmap/ship/other_ship in SSovermap.simulated_ships)
						if(other_ship == src)
							continue
						if(other_ship.docked == docking_target)
							// Another ship is already docked to this empty space - notify them
							SEND_SIGNAL(other_ship, COMSIG_VOIDCREW_SHIP_DOCKED_BY, src)
				forceMove(docking_target)
				state = OVERMAP_SHIP_IDLE
				// Start undock cooldown
				COOLDOWN_START(src, undock_cooldown, UNDOCK_COOLDOWN_TIME)
				SEND_SIGNAL(src, COMSIG_VOIDCREW_SHIP_DOCKED)
			else
				addtimer(CALLBACK(src, PROC_REF(complete_dock), to_dock), 1 SECONDS) //This should never happen, yet it does sometimes.
		if(OVERMAP_SHIP_UNDOCKING)
			// Get the location we're undocking from (passed via weakref from undock())
			var/obj/structure/overmap/old_docked_location = to_dock?.resolve()
			if(!isturf(loc))
				if(istype(loc, /obj/structure/overmap/ship)) //Even more hardcoded, even more bad
					var/obj/structure/overmap/ship/S = loc
					S.shuttle.shuttle_areas -= shuttle.shuttle_areas
					adjust_speed(S.speed[1], S.speed[2])
					// Notify the target ship that we undocked from them
					SEND_SIGNAL(S, COMSIG_VOIDCREW_SHIP_UNDOCKED_BY, src)
				var/turf/target_turf = get_turf(loc)
				log_shuttle("complete_dock UNDOCKING: Moving ship [src] from [loc] to turf [target_turf]")
				forceMove(target_turf)
			else
				log_shuttle("complete_dock UNDOCKING: Ship [src] already on turf [loc]")

			// Now that the ship has moved, clear dock flags on the old location
			// This must happen AFTER move but BEFORE unload_level check
			// Note: Both /obj/structure/overmap/dynamic and /obj/structure/overmap/planet have dock flags
			if(istype(old_docked_location, /obj/structure/overmap/dynamic))
				var/obj/structure/overmap/dynamic/dockable_place = old_docked_location
				if(dock_index == 1)
					dockable_place.first_dock_taken = FALSE
				else if(dock_index == 2)
					dockable_place.second_dock_taken = FALSE
				dock_index = 0
			else if(istype(old_docked_location, /obj/structure/overmap/planet))
				var/obj/structure/overmap/planet/planet_place = old_docked_location
				if(dock_index == 1)
					planet_place.first_dock_taken = FALSE
				else if(dock_index == 2)
					planet_place.second_dock_taken = FALSE
				dock_index = 0

			// Note: Empty space cleanup is now handled via COMSIG_VOIDCREW_SHIP_UNDOCKED signal
			// registered in /obj/structure/overmap/planet/empty/Entered()

			// If undocking from empty space, notify any other ships still docked there
			// This allows them to reactivate shields now that they're alone
			if(istype(old_docked_location, /obj/structure/overmap/planet/empty))
				for(var/obj/structure/overmap/ship/other_ship in SSovermap.simulated_ships)
					if(other_ship == src)
						continue
					if(other_ship.docked == old_docked_location)
						// Another ship is still docked to this empty space - notify them we left
						SEND_SIGNAL(other_ship, COMSIG_VOIDCREW_SHIP_UNDOCKED_BY, src)

			// Handle space ruin dock flags and cleanup
			if(istype(old_docked_location, /obj/structure/overmap/space_ruin))
				var/obj/structure/overmap/space_ruin/ruin_place = old_docked_location
				if(dock_index == 1)
					ruin_place.first_dock_taken = FALSE
				else if(dock_index == 2)
					ruin_place.second_dock_taken = FALSE
				dock_index = 0
				// Check if we should unload and respawn (small delay to ensure ship is fully moved)
				addtimer(CALLBACK(ruin_place, TYPE_PROC_REF(/obj/structure/overmap/space_ruin, check_and_respawn)), 0.5 SECONDS)

			// Always set state to FLYING when undocking completes
			state = OVERMAP_SHIP_FLYING
			SEND_SIGNAL(src, COMSIG_VOIDCREW_SHIP_UNDOCKED)
			// Force refresh close_overmap_objects for all ships on this turf
			var/turf/our_turf = get_turf(src)
			if(our_turf)
				for(var/obj/structure/overmap/other in our_turf)
					if(other == src)
						continue
					LAZYOR(other.close_overmap_objects, src)
					LAZYOR(close_overmap_objects, other)
			//if(repair_timer)
				//deltimer(repair_timer)
			//addtimer(CALLBACK(src, TYPE_PROC_REF(/obj/structure/overmap/ship, tick_autopilot)), 5 SECONDS) //TODO: Improve this SOMEHOW
	calculate_mass()
	update_appearance(UPDATE_ICON_STATE)
	update_screen()

/**
 * Initializes uninitialized space turfs around the shuttle so they can be built on.
 * /turf/open/space/basic turfs skip initialization for performance, but that breaks interactions.
 */
/obj/structure/overmap/ship/proc/initialize_nearby_space_turfs()
	if(!shuttle)
		return

	var/ship_z = shuttle.z

	// Get ship boundaries from shuttle areas
	var/min_x = INFINITY
	var/min_y = INFINITY
	var/max_x = 0
	var/max_y = 0

	for(var/area/shuttle_area as anything in shuttle.shuttle_areas)
		for(var/turf/T in shuttle_area)
			if(T.z != ship_z)
				continue
			min_x = min(min_x, T.x)
			min_y = min(min_y, T.y)
			max_x = max(max_x, T.x)
			max_y = max(max_y, T.y)

	if(min_x == INFINITY)
		return

	// Expand boundaries by 5 tiles
	var/expanded_min_x = max(1, min_x - 5)
	var/expanded_min_y = max(1, min_y - 5)
	var/expanded_max_x = min(world.maxx, max_x + 5)
	var/expanded_max_y = min(world.maxy, max_y + 5)

	var/list/turfs_to_init = list()

	// Get all turfs in the expanded area and find uninitialized space turfs
	for(var/turf/open/space/S in block(locate(expanded_min_x, expanded_min_y, ship_z), locate(expanded_max_x, expanded_max_y, ship_z)))
		if(!(S.flags_1 & INITIALIZED_1))
			turfs_to_init += S

	if(length(turfs_to_init))
		SSatoms.InitializeAtoms(turfs_to_init)

/obj/structure/overmap/ship/proc/set_ship_name(new_name, ignore_cooldown = FALSE, bypass_same_name = FALSE)
	if(bypass_same_name == FALSE)
		if(!new_name || new_name == name)
			return
	if(!COOLDOWN_FINISHED(src, rename_cooldown))
		return
	if(name != initial(name))
		priority_announce("The [name] has been renamed to the [new_name].", "Docking Announcement", sender_override = display_name)
	message_admins("[key_name_admin(usr)] renamned vessel '[name]' to '[new_name]'")
	name = new_name
	shuttle.name = new_name
	display_name = name
	if(!ignore_cooldown)
		COOLDOWN_START(src, rename_cooldown, 5 MINUTES)
	for(var/area/shuttle_area as anything in shuttle.shuttle_areas)
//		shuttle_area.rename_area("[display_name] [initial(shuttle_area.name)]")
	return TRUE

/obj/structure/overmap/ship/proc/adjust_speed(n_x, n_y)
	var/offset = 1
	if(movement_callback_id)
		var/previous_time = 1 / MAGNITUDE(speed[1], speed[2])
		offset = timeleft(movement_callback_id) / previous_time
		deltimer(movement_callback_id)
		movement_callback_id = null //just in case

	speed[1] += n_x
	speed[2] += n_y

	update_icon_state()

	if(is_still() || QDELETED(src) || movement_callback_id)
		return

	var/timer = 1 / MAGNITUDE(speed[1], speed[2]) * offset
	movement_callback_id = addtimer(CALLBACK(src, PROC_REF(tick_move)), timer, TIMER_STOPPABLE)

/**
  * Called by /proc/adjust_speed(), this continually moves the ship according to it's speed
  */
/obj/structure/overmap/ship/proc/tick_move()
	if(is_still() || QDELETED(src))
		deltimer(movement_callback_id)
		movement_callback_id = null
		return

	var/new_x = x + SIGN(speed[1])
	var/new_y = y + SIGN(speed[2])

	// Handle wraparound at edges
	var/low_x = OVERMAP_LEFT_SIDE_COORD + 1  // 2
	var/high_x = OVERMAP_RIGHT_SIDE_COORD - 1  // 24
	var/low_y = OVERMAP_SOUTH_SIDE_COORD + 1
	var/high_y = OVERMAP_NORTH_SIDE_COORD - 1

	if(new_x <= OVERMAP_LEFT_SIDE_COORD)
		new_x = high_x
	else if(new_x >= OVERMAP_RIGHT_SIDE_COORD)
		new_x = low_x

	if(new_y <= OVERMAP_SOUTH_SIDE_COORD)
		new_y = high_y
	else if(new_y >= OVERMAP_NORTH_SIDE_COORD)
		new_y = low_y

	var/turf/newloc = locate(new_x, new_y, z)

	if(newloc)
		forceMove(newloc)
		check_hazards()

	reschedule_movement()
	update_screen()

/**
  * Helper proc to reschedule the movement timer
  */
/obj/structure/overmap/ship/proc/reschedule_movement()
	if(movement_callback_id)
		deltimer(movement_callback_id)

	var/current_speed = MAGNITUDE(speed[1], speed[2])
	if(!current_speed)
		return

	// Apply speed multiplier as hard cap (for interdiction effects)
	if(speed_multiplier < SHIP_SPEED_MULTIPLIER_DEFAULT)
		current_speed *= speed_multiplier

	var/timer = 1 / current_speed
	movement_callback_id = addtimer(CALLBACK(src, PROC_REF(tick_move)), timer, TIMER_STOPPABLE)

// ===== ZONE TRANSITION PROCS =====

/**
  * Starts a zone transition - ship must wait 10 seconds before crossing into a new zone.
  * Engines are cut and ship stops during transition.
  * * target - The turf we're trying to move to
  * * target_zone - The zone datum of the target turf
  */
/obj/structure/overmap/ship/proc/start_zone_transition(turf/target, datum/overmap_zone/target_zone)
	if(zone_transitioning)
		return

	zone_transitioning = TRUE
	zone_transition_target = target
	zone_transition_start_time = world.time

	// Stop the ship - cut engines
	decelerate(max_speed)

	// Cancel any movement timer
	if(movement_callback_id)
		deltimer(movement_callback_id)
		movement_callback_id = null

	// Rotate ship to face the target zone
	var/transition_dir = get_dir(src, target)
	if(transition_dir)
		dir = transition_dir
		// Show moving icon during transition
		icon_state = "[base_icon_state]_moving"

	// Announce to ship
	ship_announce("Entering [target_zone.name]. Zone transition in progress - [ZONE_TRANSITION_TIME / 10] seconds.", "Zone Transition")

	// Start completion timer
	zone_transition_timer = addtimer(CALLBACK(src, PROC_REF(complete_zone_transition)), ZONE_TRANSITION_TIME, TIMER_STOPPABLE)

/**
  * Completes the zone transition - ship moves into the new zone.
  */
/obj/structure/overmap/ship/proc/complete_zone_transition()
	if(!zone_transitioning || !zone_transition_target)
		return

	var/turf/target = zone_transition_target

	// Clear transition state
	zone_transitioning = FALSE
	zone_transition_target = null
	zone_transition_start_time = null
	zone_transition_timer = null

	// Actually move to the target turf
	if(target && !QDELETED(src))
		forceMove(target)
		check_hazards()
		ship_announce("Zone transition complete.", "Zone Transition")
		update_icon_state()
		update_screen()

/**
  * Cancels the zone transition - player pressed stop.
  */
/obj/structure/overmap/ship/proc/cancel_zone_transition()
	if(!zone_transitioning)
		return

	// Cancel the timer
	if(zone_transition_timer)
		deltimer(zone_transition_timer)
		zone_transition_timer = null

	// Clear transition state
	zone_transitioning = FALSE
	zone_transition_target = null
	zone_transition_start_time = null

	// Reset icon to stationary
	update_icon_state()

	ship_announce("Zone transition cancelled.", "Zone Transition")

/**
  * Returns whether or not the ship is moving in any direction.
  */
/obj/structure/overmap/ship/proc/is_still()
	return !speed[1] && !speed[2]

/**
  * Docks to an empty dynamic encounter. Used for intership interaction, structural modifications, and such
  * * user - The user that initiated the action
  */
/obj/structure/overmap/ship/proc/dock_in_empty_space(mob/user)
	// Cannot dock while interdicted
	if(is_interdicted)
		return "Cannot dock while interdicted!"

	var/obj/structure/overmap/planet/empty/E
	E = locate() in get_turf(src)
	if(!E)
		E = new(get_turf(src))
	if(E)
		// Load the level first to ensure docking ports exist
		if(!E.loaded && !E.loading)
			E.load_level()

		// Wait for level to load
		if(E.loading)
			return "Empty space is loading, try again in a moment."

		// Assign port destinations and immediately dock
		var/obj/docking_port/stationary/dock_to_use = null
		if(E.reserve_dock && !E.first_dock_taken && !E.reserve_dock.get_docked())
			dock_to_use = E.reserve_dock
			E.first_dock_taken = TRUE
			dock_index = 1
		else if(E.reserve_dock_secondary && !E.second_dock_taken && !E.reserve_dock_secondary.get_docked())
			dock_to_use = E.reserve_dock_secondary
			E.second_dock_taken = TRUE
			dock_index = 2
		else
			return "No available docking ports in empty space."

		// Set port destinations for helm UI
		shuttle.port_destinations = dock_to_use

		// Adjust dock to shuttle size and immediately start docking
		E.adjust_dock_to_shuttle(dock_to_use, shuttle)
		return dock(E, dock_to_use)

/**
  * Clears pending dock request and timer
  */
/obj/structure/overmap/ship/proc/clear_pending_dock()
	pending_dock = FALSE
	pending_dock_target = null
	if(pending_dock_timer)
		deltimer(pending_dock_timer)
		pending_dock_timer = null

/**
  * Docks two ships directly exit-to-exit. Creates a shared empty space zone
  * and positions the docking ports so the ships' exits face each other.
  * * other_ship - The other ship to dock with
  * * user - The user who initiated the docking
  * * instant - If TRUE, bypasses the dock warmup (used for force dock)
  * Returns an error string on failure, null on success.
  */
/obj/structure/overmap/ship/proc/dock_ships_directly(obj/structure/overmap/ship/other_ship, mob/user, instant = FALSE)
	if(!other_ship || !shuttle || !other_ship.shuttle)
		return "Invalid ships for docking."

	// Create or find shared empty space
	var/obj/structure/overmap/planet/empty/E = locate() in get_turf(src)
	if(!E)
		E = new(get_turf(src))

	// Load the level first to ensure docking ports exist
	if(!E.loaded && !E.loading)
		E.load_level()

	// Wait for level to load
	if(E.loading)
		return "Empty space is loading, try again in a moment."

	if(!E.reserve_dock || !E.reserve_dock_secondary)
		return "No docking ports available in empty space."

	// Check dock availability
	if(E.first_dock_taken || E.reserve_dock.get_docked())
		return "Primary docking port already in use."
	if(E.second_dock_taken || E.reserve_dock_secondary.get_docked())
		return "Secondary docking port already in use."

	// Mark both docks as taken
	E.first_dock_taken = TRUE
	E.second_dock_taken = TRUE
	dock_index = 1
	other_ship.dock_index = 2

	// Position docks for exit-to-exit docking
	position_docks_for_direct_docking(E, E.reserve_dock, E.reserve_dock_secondary, shuttle, other_ship.shuttle)

	// Set port destinations for helm UI
	shuttle.port_destinations = E.reserve_dock
	other_ship.shuttle.port_destinations = E.reserve_dock_secondary

	// Dock both ships
	dock(E, E.reserve_dock, instant)
	other_ship.dock(E, E.reserve_dock_secondary, instant)

	return null

/**
  * Fallback docking: Docks two ships to the same empty space's reserve ports separately.
  * Used when direct exit-to-exit docking fails. Ships will be in the same location
  * but their airlocks won't be touching.
  * * other_ship - The other ship to dock with
  * * user - The user who initiated the docking (optional)
  * * instant - If TRUE, bypasses the dock warmup (used for force dock)
  * Returns an error string on failure, null on success.
  */
/obj/structure/overmap/ship/proc/dock_ships_to_reserve_ports(obj/structure/overmap/ship/other_ship, mob/user, instant = FALSE)
	if(!other_ship || !shuttle || !other_ship.shuttle)
		return "Invalid ships for docking."

	// Create or find shared empty space
	var/obj/structure/overmap/planet/empty/E = locate() in get_turf(src)
	if(!E)
		E = new(get_turf(src))

	// Load the level first to ensure docking ports exist
	if(!E.loaded && !E.loading)
		E.load_level()

	// Wait for level to load
	if(E.loading)
		return "Empty space is loading, try again in a moment."

	if(!E.reserve_dock || !E.reserve_dock_secondary)
		return "No docking ports available in empty space."

	// Check if at least one dock is available for each ship
	var/obj/docking_port/stationary/dock_for_us
	var/obj/docking_port/stationary/dock_for_them

	if(!E.first_dock_taken && !E.reserve_dock.get_docked())
		dock_for_us = E.reserve_dock
		E.first_dock_taken = TRUE
		dock_index = 1
	else if(!E.second_dock_taken && !E.reserve_dock_secondary.get_docked())
		dock_for_us = E.reserve_dock_secondary
		E.second_dock_taken = TRUE
		dock_index = 2

	if(!dock_for_us)
		return "No available docking ports for our ship."

	// Find dock for the other ship
	if(!E.first_dock_taken && !E.reserve_dock.get_docked())
		dock_for_them = E.reserve_dock
		E.first_dock_taken = TRUE
		other_ship.dock_index = 1
	else if(!E.second_dock_taken && !E.reserve_dock_secondary.get_docked())
		dock_for_them = E.reserve_dock_secondary
		E.second_dock_taken = TRUE
		other_ship.dock_index = 2

	if(!dock_for_them)
		// Rollback our dock allocation
		if(dock_index == 1)
			E.first_dock_taken = FALSE
		else
			E.second_dock_taken = FALSE
		dock_index = 0
		return "No available docking ports for target ship."

	// Adjust docks to fit each shuttle
	E.adjust_dock_to_shuttle(dock_for_us, shuttle)
	E.adjust_dock_to_shuttle(dock_for_them, other_ship.shuttle)

	// Set port destinations for helm UI
	shuttle.port_destinations = dock_for_us
	other_ship.shuttle.port_destinations = dock_for_them

	// Dock both ships
	dock(E, dock_for_us, instant)
	other_ship.dock(E, dock_for_them, instant)

	return null

/**
  * Positions two stationary docks so that two shuttles will dock exit-to-exit (airlocks touching).
  * * empty_planet - The empty space planet (for calling adjust_dock_to_shuttle)
  * * dock_a - First stationary dock (for shuttle_a)
  * * dock_b - Second stationary dock (for shuttle_b)
  * * shuttle_a - First shuttle's mobile dock
  * * shuttle_b - Second shuttle's mobile dock
  */
/obj/structure/overmap/ship/proc/position_docks_for_direct_docking(obj/structure/overmap/planet/empty/empty_planet, obj/docking_port/stationary/dock_a, obj/docking_port/stationary/dock_b, obj/docking_port/mobile/shuttle_a, obj/docking_port/mobile/shuttle_b)
	// For ship-to-ship docking, we need both shuttles to fit in the same area
	// First, move dock_a to the center of the z-level with plenty of clearance
	var/datum/map_zone/mapzone = empty_planet.mapzone
	if(!mapzone || !length(mapzone.z_levels))
		log_shuttle("WARNING: No mapzone for ship-to-ship docking")
		return
	var/datum/space_level/zlevel = mapzone.z_levels[1]

	// Calculate center position - use world.maxx/maxy as bounds since space_level doesn't track exact bounds
	// The z-level should be large enough for both shuttles
	var/center_x = round(world.maxx / 2)
	var/center_y = round(world.maxy / 2)

	// Position dock_a at center, let adjust_dock_to_shuttle handle orientation
	dock_a.forceMove(locate(center_x, center_y, zlevel.z_value))
	empty_planet.adjust_dock_to_shuttle(dock_a, shuttle_a)

	// For exit-to-exit docking, dock_b faces OPPOSITE to dock_a
	// Set direction first so the shuttle body extends correctly
	dock_b.dir = REVERSE_DIR(dock_a.dir)

	// Size dock_b to fit shuttle_b (use max of dimensions for safety)
	var/shuttle_max_dim = max(shuttle_b.width, shuttle_b.height)
	dock_b.width = shuttle_max_dim
	dock_b.height = shuttle_max_dim

	// Calculate offsets to center shuttle_b within dock area
	dock_b.dwidth = round((dock_b.width - shuttle_b.width) / 2) + shuttle_b.dwidth
	dock_b.dheight = round((dock_b.height - shuttle_b.height) / 2) + shuttle_b.dheight

	// Position dock_b adjacent to dock_a (exit-to-exit docking)
	// dock_a.dir points INTO shuttle_a, shuttle_a extends in REVERSE_DIR(dock_a.dir)
	// dock_b should be in that direction so shuttles face each other
	// The +1 offset puts the docking ports adjacent - shuttle bodies extend away from each other
	var/offset_dir = REVERSE_DIR(dock_a.dir)
	var/dock_b_x = dock_a.x
	var/dock_b_y = dock_a.y

	switch(offset_dir)
		if(NORTH)
			dock_b_y = dock_a.y + 1
		if(SOUTH)
			dock_b_y = dock_a.y - 1
		if(EAST)
			dock_b_x = dock_a.x + 1
		if(WEST)
			dock_b_x = dock_a.x - 1

	var/turf/new_loc = locate(dock_b_x, dock_b_y, dock_a.z)
	if(new_loc)
		dock_b.forceMove(new_loc)
	else
		log_shuttle("WARNING: Could not position dock_b at ([dock_b_x], [dock_b_y]) for ship-to-ship docking")

/**
  * Ship-to-ship interaction. Creates shared empty space and docks both ships together.
  * * user - The user that initiated the action
  * * acting_ship - The ship that initiated the interaction
  */
/obj/structure/overmap/ship/ship_act(mob/user, obj/structure/overmap/ship/acting_ship)
	if(!acting_ship || acting_ship == src)
		return

	// Both ships must be still to interact
	if(!acting_ship.is_still() || !is_still())
		to_chat(user, "<span class='warning'>Both ships must be stationary to dock together!</span>")
		return

	// Both ships must be flying (not already docked)
	if(acting_ship.state != OVERMAP_SHIP_FLYING || state != OVERMAP_SHIP_FLYING)
		to_chat(user, "<span class='warning'>Both ships must be undocked to perform ship-to-ship docking!</span>")
		return

	// Check if acting_ship is clicking on a ship it already requested to dock with
	// If so, cancel the request
	if(acting_ship.pending_dock && acting_ship.pending_dock_target == src)
		acting_ship.clear_pending_dock()
		acting_ship.ship_announce("Docking request to [name] has been cancelled.", "Docking Cancelled")
		ship_announce("[acting_ship.name] has cancelled their docking request.", "Docking Cancelled")
		return

	// Check if the target (src) already sent a request to acting_ship
	// If src.pending_dock is TRUE and target is acting_ship, complete the handshake
	if(pending_dock && pending_dock_target == acting_ship)
		ship_announce("Initiating docking procedures with [acting_ship.name]...", "Docking")
		acting_ship.ship_announce("Initiating docking procedures with [name]...", "Docking")

		// Clear pending status and timers for both ships
		clear_pending_dock()
		acting_ship.clear_pending_dock()

		// Dock both ships directly exit-to-exit
		var/result = dock_ships_directly(acting_ship, user)
		if(result)
			// Direct docking failed, fall back to reserve port docking
			ship_announce("Direct docking failed, using reserve ports instead.", "Docking")
			acting_ship.ship_announce("Direct docking failed, using reserve ports instead.", "Docking")
			var/fallback_result = dock_ships_to_reserve_ports(acting_ship, user)
			if(fallback_result)
				to_chat(user, "<span class='warning'>Docking failed: [fallback_result]</span>")
				ship_announce("Docking failed: [fallback_result]", "Docking Error")
				acting_ship.ship_announce("Docking failed: [fallback_result]", "Docking Error")
	else
		// If acting_ship already has a pending request to a DIFFERENT ship, cancel it first
		if(acting_ship.pending_dock && acting_ship.pending_dock_target != src)
			var/obj/structure/overmap/ship/old_target = acting_ship.pending_dock_target
			acting_ship.clear_pending_dock()
			acting_ship.ship_announce("Docking request to [old_target?.name] has been cancelled.", "Docking Cancelled")
			if(old_target)
				old_target.ship_announce("[acting_ship.name] has cancelled their docking request.", "Docking Cancelled")

		// New request - acting_ship wants to dock with src (target)
		log_admin("[key_name(user)] requested ship-to-ship docking from [acting_ship.name] to [name]")
		// Announce to the acting ship (the one making the request)
		acting_ship.ship_announce("Your ship has requested to dock with [name]. They must also request docking to proceed.", "Docking Request")
		// Announce to the target ship (src) that they have an incoming request
		ship_announce("[acting_ship.name] has requested to dock with your ship. Use your helm console to accept.", "Incoming Docking Request")
		// Set pending on acting_ship - this marks that acting_ship is waiting for src to respond
		acting_ship.pending_dock = TRUE
		acting_ship.pending_dock_target = src

		// Set a 30 second timer to clear the pending dock request on acting_ship
		acting_ship.pending_dock_timer = addtimer(CALLBACK(acting_ship, PROC_REF(clear_pending_dock)), 30 SECONDS, TIMER_STOPPABLE)
		acting_ship.ship_announce("Docking request will expire in 30 seconds.", "Docking Request Timer")
/**
  * Calculates the mass based on the amount of turfs in the shuttle's areas
  * Ship health is based on current turfs vs original turfs
  * Losing turfs = losing health, rebuilding = healing
  */
/obj/structure/overmap/ship/proc/calculate_mass()
	if(!shuttle)
		return 0
	. = 0
	var/list/areas = shuttle.shuttle_areas
	for(var/area/shuttleArea in areas)
		for(var/turf/T in shuttleArea)
			if(isspaceturf(T))
				continue
			// Only count actual shuttle turfs (have baseturf_skipover/shuttle in baseturfs)
			// This prevents planet/ruin turfs from being counted after crash landing
			if(!isshuttleturf(T))
				continue
			// Tiered health: reinforced walls > walls > floors
			if(istype(T, /turf/closed/wall/r_wall))
				. += 3  // Reinforced walls
			else if(istype(T, /turf/closed/wall))
				. += 2  // Regular walls
			else
				.++  // Floors and other turfs

	var/old_integrity = integrity
	mass = .

	// First calculation - set original mass as max_integrity and start at full health
	if(!integrity_initialized)
		max_integrity = mass
		integrity = mass // Start at 100% health
		overhealth = 0
		integrity_initialized = TRUE
	else
		// Subsequent calculations - health = current turfs (capped at original max)
		integrity = min(mass, max_integrity)
		// Overhealth = turfs beyond original ship size (from expansion)
		overhealth = max(0, mass - max_integrity)

	// Check for integrity changes and send signals
	if(integrity != old_integrity && max_integrity > 0)
		// Raw percentages for internal threshold checks
		var/raw_percent = round((integrity / max_integrity) * 100)
		var/old_raw_percent = round((old_integrity / max_integrity) * 100)
		// Scaled percentage for UI/announcements (50% raw = 0% display)
		var/display_percent = get_integrity_percent()

		// Send signal that integrity changed - listeners handle all effects
		SEND_SIGNAL(src, COMSIG_SHIP_INTEGRITY_CHANGED, integrity, max_integrity, display_percent)

		// Check thresholds (only when health dropped)
		if(integrity < old_integrity)
			// 60% raw (20% displayed) - Critical damage - start alert loop
			if(old_raw_percent > 60 && raw_percent <= 60)
				start_critical_alert()

			// Ship destruction at 50% raw (0% displayed)
			if(old_raw_percent > 50 && raw_percent <= 50)
				stop_critical_alert()
				on_ship_destroyed()

		// Check for recovery - ship must be repaired to 65% to restart
		if(integrity > old_integrity && has_crash_landed)
			if(old_raw_percent < 65 && raw_percent >= 65)
				stop_critical_alert()
				on_ship_recovered()

	update_icon_state()

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

/**
  * Calculates the average fuel fullness of all engines.
  */
/obj/structure/overmap/ship/proc/calculate_avg_fuel()
	var/fuel_avg = 0
	var/engine_amnt = 0
	for(var/obj/machinery/power/shuttle_engine/ship/E in shuttle.engine_list)
		if(!E.enabled || E.thruster_active == 0)
			continue
		fuel_avg += E.return_fuel() / E.return_fuel_cap()
		engine_amnt++
	if(!engine_amnt || !fuel_avg)
		avg_fuel_amnt = 0
		return
	avg_fuel_amnt = round(fuel_avg / engine_amnt * 100)

///Returns TRUE if the ship has at least one working engine with fuel available.
/obj/structure/overmap/ship/proc/can_thrust()
	refresh_engines()
	for(var/obj/machinery/power/shuttle_engine/ship/engine in shuttle.engine_list)
		if(!engine.enabled || !engine.thruster_active)
			continue
		var/fuel = engine.return_fuel()
		var/fuel_cap = engine.return_fuel_cap()
		if(fuel > 0 || !fuel_cap)
			return TRUE
	return FALSE

/**
  * Returns the total speed in all directions.
  *
  * The equation for acceleration is as follows:
  * 60 SECONDS / (1 / ([ship's speed] / ([ship's mass] * 100)))
  */
/obj/structure/overmap/ship/proc/get_speed()
	if(is_still())
		return 0
	return 60 SECONDS / (1 / MAGNITUDE(speed[1], speed[2])) //It's per minute, which is 60 seconds

/**
  * Returns the direction the ship is moving in terms of dirs
  */
/obj/structure/overmap/ship/proc/get_heading()
	var/direction = 0
	if(speed[1])
		if(speed[1] > 0)
			direction |= EAST
		else
			direction |= WEST
	if(speed[2])
		if(speed[2] > 0)
			direction |= NORTH
		else
			direction |= SOUTH
	return direction

/**
  * Returns the estimated time in deciseconds to the next tile at current speed, or approx. time until reaching the destination when on autopilot
  */
/obj/structure/overmap/ship/proc/get_eta()

	. += timeleft(movement_callback_id)
	if(!.)
		return "--:--"
	. /= 10 //they're in deciseconds
	return "[add_leading(num2text((. / 60) % 60), 2, "0")]:[add_leading(num2text(. % 60), 2, "0")]"

/**
  * Change the speed in a specified dir.
  * * direction - dir to accelerate in (NORTH, SOUTH, SOUTHEAST, etc.)
  * * acceleration - How much to accelerate by
  */
/obj/structure/overmap/ship/proc/accelerate(direction, acceleration)
	var/heading = get_heading()
	if(!(direction in GLOB.cardinals))
		acceleration *= 0.5 //Makes it so going diagonally isn't 2x as efficient
	if(heading && (direction & REVERSE_DIR(heading))) //This is so if you burn in the opposite direction you're moving, you can actually reach zero
		if(EWCOMPONENT(direction))
			acceleration = min(acceleration, abs(speed[1]))
		else
			acceleration = min(acceleration, abs(speed[2]))
	if(direction & EAST)
		adjust_speed(acceleration, 0)
	if(direction & WEST)
		adjust_speed(-acceleration, 0)
	if(direction & NORTH)
		adjust_speed(0, acceleration)
	if(direction & SOUTH)
		adjust_speed(0, -acceleration)

/**
  * Reduce the speed or stop in all directions.
  * * acceleration - How much to decelerate by
  */
/obj/structure/overmap/ship/proc/decelerate(acceleration)
	if(speed[1] && speed[2]) //another check to make sure that deceleration isn't 2x as fast when moving diagonally
		adjust_speed(-SIGN(speed[1]) * min(acceleration * 0.5, abs(speed[1])), -SIGN(speed[2]) * min(acceleration * 0.5, abs(speed[2])))
	else if(speed[1])
		adjust_speed(-SIGN(speed[1]) * min(acceleration, abs(speed[1])), 0)
	else if(speed[2])
		adjust_speed(0, -SIGN(speed[2]) * min(acceleration, abs(speed[2])))

/obj/structure/overmap/ship/Bump(atom/A)
/*
	if(istype(A, /turf/open/overmap/edge))
		handle_wraparound()
	..()
	*/

/**
  * Check if the ship is flying into the border of the overmap.
  */
/obj/structure/overmap/ship/proc/handle_wraparound()
	var/nx = x
	var/ny = y
	var/low_edge = 2
	var/high_edge = SSovermap.size - 1

	if((dir & WEST) && x == low_edge)
		nx = high_edge
	else if((dir & EAST) && x == high_edge)
		nx = low_edge
	if((dir & SOUTH)  && y == low_edge)
		ny = high_edge
	else if((dir & NORTH) && y == high_edge)
		ny = low_edge
	if((x == nx) && (y == ny))
		return //we're not flying off anywhere

	var/turf/T = locate(nx,ny,z)
	if(T)
		forceMove(T)

/**
 * Burns the engines in one direction, accelerating in that direction.
 * Unsimulated ships use the acceleration_speed var, simulated ships check eacch engine's thrust and fuel.
 * If no dir variable is provided, it decelerates the vessel.
 * * n_dir - The direction to move in
 */
/obj/structure/overmap/ship/proc/burn_engines(n_dir = null, percentage = 100)
	if(state != OVERMAP_SHIP_FLYING)
		return

	// Can't thrust while transitioning zones
	if(zone_transitioning)
		return

	SEND_SIGNAL(src, COMSIG_VOIDCREW_SHIP_MOVED)

	// Clear any pending dock requests when moving
	if(pending_dock)
		clear_pending_dock()
		ship_announce("Docking request cancelled due to ship movement.", "Docking Cancelled")

	// Decelerate without using fuel
	if(!n_dir)
		decelerate(acceleration_speed * (percentage / 100))
		return

	// Check if thrusting towards a zone boundary
	if(SSovermap_zones?.initialized)
		var/turf/current_turf = get_turf(src)
		var/datum/overmap_zone/current_zone = SSovermap_zones.get_zone(current_turf)
		if(current_zone)
			// Calculate target tile in thrust direction
			var/target_x = x
			var/target_y = y
			if(n_dir & EAST)
				target_x++
			if(n_dir & WEST)
				target_x--
			if(n_dir & NORTH)
				target_y++
			if(n_dir & SOUTH)
				target_y--
			var/turf/target_turf = locate(target_x, target_y, z)
			if(target_turf)
				var/datum/overmap_zone/target_zone = SSovermap_zones.get_zone(target_turf)
				// If target tile is in a different zone, start transition instead of thrusting
				if(target_zone && current_zone.zone_type != target_zone.zone_type)
					start_zone_transition(target_turf, target_zone)
					return

	var/thrust_used = 0 //The amount of thrust that the engines will provide with one burn
	refresh_engines()

	if(!mass)
		calculate_mass()
	calculate_avg_fuel()

	for(var/obj/machinery/power/shuttle_engine/ship/E in shuttle.engine_list)
		if(!E.enabled || E.thruster_active == 0)
			continue
		thrust_used += E.burn_engine(percentage, mass)
	est_thrust = thrust_used //cheeky way of rechecking the thrust, check it every time it's used

	// No thrust means no movement - engines need fuel/power to work
	if(thrust_used <= 0)
		return

	thrust_used = thrust_used / max(mass * 100, 1) //do not know why this minimum check is here, but I clearly ran into an issue here before

	// Apply speed multiplier (for effects like interdiction)
	thrust_used *= speed_multiplier

	if(n_dir)
		accelerate(n_dir, thrust_used)

/// Global helper to get the ship an atom is currently on
/// Returns null if the atom is not on a ship
/proc/get_ship_from_atom(atom/source)
	var/obj/docking_port/mobile/voidcrew/port = SSshuttle.get_containing_shuttle(source)
	return port?.current_ship

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
		return "Maximum active missions reached ([max_missions])."
	if(mission.active)
		return "Mission already accepted."

	if(!mission.start_mission(src))
		return "Failed to start mission."

	return TRUE

/**
 * Completes a mission via turn-in.
 * * mission - The mission to complete
 * * pad - The mission pad used for turn-in
 * * item - Optional item being turned in
 * Returns TRUE on success, error string on failure.
 */
/obj/structure/overmap/ship/proc/complete_mission(datum/mission/mission, obj/machinery/mission_pad/pad, obj/item/item)
	if(!mission)
		return "Invalid mission."
	if(!(mission in active_missions))
		return "Mission not active on this ship."

	// Pre-validate before attempting turn-in for better error messages
	if(mission.requires_item)
		if(!mission.can_turn_in(item))
			return mission.get_failure_reason(item)
	else
		if(!mission.can_complete())
			return mission.get_failure_reason(item)

	if(!mission.turn_in(pad, item))
		return "Failed to complete mission."

	return TRUE

/**
 * Abandons/gives up on a mission.
 * * mission - The mission to abandon
 */
/obj/structure/overmap/ship/proc/abandon_mission(datum/mission/mission)
	if(!mission)
		return "Invalid mission."
	if(!(mission in active_missions))
		return "Mission not active on this ship."

	mission.give_up()
	return TRUE

#undef SHIP_SIZE_THRESHOLD
#undef SHIP_SPEED_MULTIPLIER_DEFAULT

#undef SHIP_RUIN
#undef SHIP_DELETE
#undef SHIP_VIEW_RANGE
#undef DOCK_WARMUP_TIME
#undef UNDOCK_WARMUP_TIME
#undef UNDOCK_COOLDOWN_TIME
