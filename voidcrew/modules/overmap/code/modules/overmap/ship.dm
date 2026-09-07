///Threshold above which it uses the ship sprites instead of the shuttle sprites
#define SHIP_SIZE_THRESHOLD 150

// SHIP_VIEW_RANGE now lives in voidcrew/_DEFINES/overmap.dm, the helm's sensor
// code needs it too, and a file-local define was going out of scope before it.
#define SHIP_SPEED_MULTIPLIER_DEFAULT 1
/// How long crews must wait between ship renames
#define SHIP_RENAME_COOLDOWN (5 MINUTES)

/// Burn direction constants for throttle system
#define BURN_NONE 0
#define BURN_STOP -1

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
	///Timer ID of the looping movement timer
	var/movement_callback_id

	/**
	 * Player-facing Ship stuff.
	 */
	///Shipwide bank account
	var/datum/bank_account/ship/ship_account
	///Credits the shipwide account is seeded with when the ship is set up.
	var/starting_credits = 1000
	///Voidcrew-unique team we link everyone's mind to.
	var/datum/team/voidcrew/ship_team

	///Boolean on whether players are allowed to latejoin into this ship, toggled by the job managing console.
	var/joining_allowed = TRUE
	///Password required to latejoin this ship, set by the captain. Null = open to everyone.
	///Only player-created hulls (purchased, requisitioned, commissioned) may carry one;
	///the roundstart fleet stays public - see can_have_join_password().
	var/join_password
	///Assoc list of ckeys (ckey = TRUE) cleared to join: the buyer, past crew, invitees,
	///approved applicants, and anyone who entered the password. Survives respawning,
	///but is cleared when the password changes or the captain resets join access.
	var/list/password_cleared_ckeys = list()
	///Whether this ship's airlocks refuse anyone who is not crew. Off by default, and
	///only settable on hulls that may carry a join password - the roundstart fleet stays
	///public either way (see can_have_join_password()). Maintained together with
	///GLOB.crew_locked_ships by set_crew_only_airlocks(); never write it directly.
	var/crew_only_airlocks = FALSE
	///Name of the ship.
	var/map_name
	///Short memo of the ship, set by the crew, and shown to latejoiners.
	var/memo
	///Whether the crew has already picked a custom name. The first rename is quiet; later ones are broadcast galaxy-wide.
	var/renamed_once = FALSE
	///ONLY USED FOR NON-SIMULATED SHIPS. The amount per burn that this ship accelerates
	var/acceleration_speed = 0.02
	///Cooldown until the ship can be renamed again
	COOLDOWN_DECLARE(rename_cooldown)
	///Cooldown between sending crew invites
	COOLDOWN_DECLARE(invite_cooldown)
	///List of pending crew invites: ckey -> invite_time
	var/list/pending_invites = list()
	///Open /datum/ship_application requests to join this ship from the lobby. Only a
	///password-locked hull ever collects any - see voidcrew/modules/captain_management.
	var/list/crew_applications = list()
	/// Mind of whoever claimed this ship (for NPC ships without job_slots)
	var/datum/mind/claimed_captain
	/// Mind of the crew member holding acting command: the first joiner on a ship with
	/// no captain. Revoked the moment a real captain (officer job spawn or claim) arrives.
	var/datum/mind/acting_captain
	/// TRUE while an offer of command is waiting on an answer. One at a time per ship.
	var/command_offer_pending = FALSE
	/// TRUE while a command election is running. One at a time per ship.
	var/election_in_progress = FALSE
	///Cooldown after a failed command election, before another may be called
	COOLDOWN_DECLARE(election_cooldown)

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
	/// The direction currently being burned (0 = none, direction = thrust, -1 = active braking)
	var/burn_direction = 0
	/// Both the engine burn intensity (1-100) and the cruise-speed target as a
	/// percentage of max_speed, one throttle for how hard to burn and how fast
	/// to end up going. 100 = flat out.
	var/burn_percentage = 100
	/// The course the pilot has commanded via the helm (dir bits), independent of
	/// burn_direction: it persists while the engines coast at cruise, and
	/// BURN_NONE means no course is held. Never holds BURN_STOP.
	var/commanded_course = BURN_NONE
	/// Course latched when a zone transition seizes the ship, re-commanded when
	/// the crossing completes so a hand-flown hull doesn't come out the far side
	/// dead in space.
	var/zone_resume_burn = BURN_NONE
	/// Whether we're currently registered with SSfastprocess for thrust
	var/thrust_processing = FALSE

	///Vessel approximate mass
	var/mass

	/// Linked shield generators for ship defense (multiple generators stack)
	var/list/obj/machinery/ship_combat/shield_generator/linked_shield_generators = list()

	/// Linked cloaking device (only one per ship)
	var/obj/machinery/ship_combat/cloak_device/linked_cloak_device

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
	/// Stored shield health for reactivation (preserved on graceful shutdown, reset to 0 on break)
	var/stored_shield_health = 0

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

	var/pending_dock = FALSE
	var/pending_dock_timer
	/// The ship we sent a docking request to (if any)
	var/obj/structure/overmap/ship/pending_dock_target

	/// Weakref to the overmap site we're waiting on to finish generating (see
	/// request_site_load). The helm is never held while a site generates - the
	/// approach resumes automatically off COMSIG_VOIDCREW_SITE_LOAD_FINISHED.
	var/datum/weakref/awaiting_load_site
	/// Weakref to the mob that asked for that approach; used to resume it (may be null).
	var/datum/weakref/awaiting_load_user

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

	/// Weakref to the NPC pirate ship currently engaging this ship (only one pirate can engage at a time)
	var/datum/weakref/engaging_pirate_ref

	/// List of interdictor machines installed on this ship
	var/list/linked_interdictors = list()

	/// Mission pads installed on this ship (for pirate tribute delivery, mission rewards, etc.)
	var/list/obj/machinery/mission_pad/linked_mission_pads = list()

	/// List of ships that currently have a weapons lock on us (prevents cloaking)
	var/list/locked_on_by = list()

	/// Combat alarm that plays when weapons are locked on this ship
	var/datum/combat_alarm/combat_alarm

	/// Whether this ship is currently hidden inside a nebula
	var/hidden_in_nebula = FALSE
	/// Timer ID for nebula hide warmup
	var/nebula_hide_timer
	/// world.time of the last tick a mounted nebula ram scoop actually harvested.
	/// Concealment stays blocked while this is recent (see is_scoop_hot())
	var/last_scoop_activity = 0

	// ===== ZONE TRANSITION =====
	/// Whether we're currently transitioning between zones (10 second delay)
	var/zone_transitioning = FALSE
	/// Timer ID for zone transition completion
	var/zone_transition_timer
	/// The target turf we're trying to transition to
	var/turf/zone_transition_target
	/// When the zone transition started (for progress calculation)
	var/zone_transition_start_time

	/// Cooldown preventing undocking shortly after docking
	COOLDOWN_DECLARE(undock_cooldown)
	/// Rate limit on the "engines producing no thrust" crew warning
	COOLDOWN_DECLARE(no_thrust_warning)
	/// Timer ID for dock warmup
	var/dock_warmup_timer
	/// Timer ID for undock warmup
	var/undock_warmup_timer
	/// The site complete_undock_warmup() launched us away from, kept so check_manoeuvre_stalled()
	/// can restart a lost undock with the same argument the timer chain was carrying - without it
	/// the recovery cannot hand the berth back, because `docked` is cleared on the way out. Weak
	/// because the site can be torn down the moment we leave it. Null whenever we are not undocking.
	var/datum/weakref/undock_origin
	/// Transitional state check_manoeuvre_stalled() last saw us in, and when it first saw it.
	/// Watchdog bookkeeping only - observed by the poll rather than stamped at each `state`
	/// assignment, so a new assignment site cannot forget to arm it.
	var/manoeuvre_watch_state
	var/manoeuvre_watch_since = 0

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
	// Same for banked overhealth - its ceiling scales off max health
	shield_overhealth = min(shield_overhealth, shield_max_health * SHIP_SHIELD_MAX_OVERHEALTH_MULT)

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
		// Generate overhealth when at max and power > 100% - capped like the main pool,
		// or a ship idling at 200% banks an unbounded buffer that absorbs before health
		// and makes the break check unreachable
		var/excess = shield_power_allocation - 1
		var/overhealth_rate = shield_regen_rate * excess * seconds_per_tick
		shield_overhealth = min(shield_overhealth + overhealth_rate, shield_max_health * SHIP_SHIELD_MAX_OVERHEALTH_MULT)

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
		break_ship_shields(graceful = FALSE)  // Damage break - stored health resets to 0

	return TRUE

/// Called when shields go offline (either depleted or manually turned off)
/// graceful = TRUE: Manual shutdown, preserves current health for reactivation
/// graceful = FALSE: Damage break or shield pop, resets stored health to 0
/obj/structure/overmap/ship/proc/break_ship_shields(graceful = FALSE)
	if(!shields_active)
		return

	// Store or reset health based on shutdown type
	if(graceful)
		stored_shield_health = shield_health  // Preserve for manual shutdown
	else
		stored_shield_health = 0  // Reset for damage break or shield pop

	shields_active = FALSE
	shields_broken = TRUE
	shield_health = 0
	shield_overhealth = 0

	// Start cooldown
	COOLDOWN_START(src, shield_reactivation_cooldown, SHIP_SHIELD_BROKEN_COOLDOWN)

	// Round 4: a silent collapse was indistinguishable from shields refusing to come
	// online. Every collapse tells the crew what happened and when they can retry.
	if(graceful)
		ship_notify("Shields are down. They can be raised again in [DisplayTimeText(SHIP_SHIELD_BROKEN_COOLDOWN)].", "SHIELDS", SHIP_NOTIFY_NOTICE, 'voidcrew/sound/notify.ogg', 30)
	else
		ship_notify("Shields have collapsed! Generators resetting - [DisplayTimeText(SHIP_SHIELD_BROKEN_COOLDOWN)] before they can be raised again.", "SHIELDS", SHIP_NOTIFY_DANGER, 'voidcrew/sound/alert2.ogg', 40)

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
		// Restore stored health (capped to max in case generators changed), but never
		// come back below the raise charge floor. Returning at 0 HP meant the first
		// hit re-broke the pool and re-armed the full cooldown, so under sustained
		// fire (round 4 meteor shower) shields could never re-establish.
		shield_health = clamp(max(stored_shield_health, shield_max_health * SHIP_SHIELD_RAISE_CHARGE_MULT), 0, shield_max_health)

		// Spawn shield walls from first active generator
		if(first_active_gen)
			first_active_gen.spawn_shield_walls()

		SEND_SIGNAL(src, COMSIG_SHIP_SHIELD_RESTORED)
		playsound(first_active_gen || src, 'sound/vehicles/mecha/mech_shield_raise.ogg', 100, TRUE)
		ship_notify("Shields are back online.", "SHIELDS", SHIP_NOTIFY_NOTICE, 'voidcrew/sound/notify.ogg', 30)
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

/**
 * Why can't shields come up right now? Returns a player-facing reason string, or null
 * if nothing is blocking activation. Round 4: every path that refused activation did
 * so silently, which read as "shields refuse to work" - anything that acts on a
 * player's request for shields should surface this instead of doing nothing.
 */
/obj/structure/overmap/ship/proc/get_shield_blocker_reason()
	if(!length(linked_shield_generators))
		return "No shield generators are linked to the ship."
	if(shields_broken)
		if(!COOLDOWN_FINISHED(src, shield_reactivation_cooldown))
			return "Shield generators are resetting - [DisplayTimeText(COOLDOWN_TIMELEFT(src, shield_reactivation_cooldown))] before shields can be raised."
		return "Shield generators are resetting."
	if(is_in_ship_to_ship_dock())
		return "Shields cannot be raised while docked to another ship."
	var/gen_count = 0
	var/unpowered = 0
	var/dock_latched = 0
	for(var/obj/machinery/ship_combat/shield_generator/gen in linked_shield_generators)
		gen_count++
		if(gen.machine_stat & NOPOWER)
			unpowered++
		if(gen.in_ship_to_ship_dock)
			dock_latched++
	if(gen_count && unpowered == gen_count)
		return "No linked shield generator has power."
	// The generators keep their own ship-to-ship dock latch (signal-driven); if it is
	// stuck out of step with the ship's real state, surface it rather than letting
	// every activation attempt die silently
	if(gen_count && dock_latched == gen_count)
		return "Shields cannot be raised while docked to another ship."
	return null

/// Returns aggregated shield status for UI
/obj/structure/overmap/ship/proc/get_shield_status()
	// Calculate total power draw and efficiency
	var/total_power_draw = 0
	var/total_efficiency_bonus = 0
	var/gen_count = 0

	for(var/obj/machinery/ship_combat/shield_generator/gen in linked_shield_generators)
		if(!(gen.machine_stat & (BROKEN|NOPOWER)))
			// Only active generators actually draw - update_power_draw() zeroes the
			// usage while inactive (break cooldown, ship-to-ship dock), so summing
			// inactive ones overstates the readout against the real grid load
			if(gen.active)
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

/// Counts laser turrets linked to any combat console aboard this ship.
/// LASER_MAX_TURRETS is a per-hull cap, but the linked lists live on the consoles -
/// counting only one console's list lets a second console double the ceiling.
/obj/structure/overmap/ship/proc/count_linked_turrets()
	if(!shuttle)
		return 0
	var/list/counted = list()
	for(var/area/ship_area in shuttle.shuttle_areas)
		for(var/obj/machinery/computer/camera_advanced/ship_combat/console in ship_area)
			for(var/datum/weakref/ref in console.linked_turrets)
				var/obj/machinery/ship_combat/laser_turret/turret = ref.resolve()
				if(turret)
					counted |= turret
	return length(counted)

/// Starts shield processing on this ship (called when shields activate)
/obj/structure/overmap/ship/proc/start_shield_processing()
	update_ship_processing()

/// Stops shield processing on this ship (called when shields deactivate)
/obj/structure/overmap/ship/proc/stop_shield_processing()
	update_ship_processing()

/**
 * Updates which subsystem the ship is registered with based on current needs.
 * Uses SSfastprocess (0.2s) when thrusting for responsive controls.
 * Uses SSobj (2s) when only shields are active (slower is fine for regen).
 * Stops processing entirely when neither is needed.
 */
/obj/structure/overmap/ship/proc/update_ship_processing()
	var/needs_fast = thrust_processing && burn_direction != BURN_NONE
	var/needs_slow = shields_active || shields_broken

	if(needs_fast)
		// Need fast processing for thrust - use SSfastprocess
		if(datum_flags & DF_ISPROCESSING)
			// Already processing somewhere, check if we need to switch
			if(!(src in SSfastprocess.processing))
				STOP_PROCESSING(SSobj, src)
				START_PROCESSING(SSfastprocess, src)
		else
			START_PROCESSING(SSfastprocess, src)
	else if(needs_slow)
		// Only need slow processing for shields - use SSobj
		if(datum_flags & DF_ISPROCESSING)
			// Already processing somewhere, check if we need to switch
			if(!(src in SSobj.processing))
				STOP_PROCESSING(SSfastprocess, src)
				START_PROCESSING(SSobj, src)
		else
			START_PROCESSING(SSobj, src)
	else
		// Don't need any processing
		if(datum_flags & DF_ISPROCESSING)
			// Try stopping from both (one will be a no-op)
			STOP_PROCESSING(SSfastprocess, src)
			STOP_PROCESSING(SSobj, src)
		thrust_processing = FALSE

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
		job_slot_definitions += get_module_job_definitions(source_template.type, upgrade_selections, slot_ids)

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
	shuttle?.intoTheSunset()
	shuttle = null
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
	// timer, the Wideband transmitter and the sprite filter (ship_distress.dm).
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

/**
  * Just double checks all the engines on the shuttle
  */
/obj/structure/overmap/ship/proc/refresh_engines()
	if(!shuttle)
		est_thrust = 0
		return
	// A hull mid-move is geometrically untestable: takeoff() relocates the port's tile
	// (x/y/z all updated) early in initiate_docking(), but setDir(new_dock.dir) is that
	// proc's LAST line, after cleanup_runway()'s per-turf CHECK_TICK yields - so on any
	// rotated move there are whole ticks where return_coords() projects the old heading
	// from the new position and the rect misses the hull entirely. Round 4 (2026-08-15
	// 04:39:22): a refresh landed in that window during an undock from the round's only
	// dir-rotated berth and unsynced all four of D 19's thrusters while they stood on
	// their own registered deck tiles - and the rebind sweep below could not save them,
	// because get_containing_shuttle() runs the same poisoned rect. Nothing about the
	// roster can be learned mid-move; keep the list and let the first post-move refresh
	// judge it against honest geometry.
	if(shuttle.move_in_flight())
		return
	var/calculated_thrust = 0
	// Cutting from engine_list mid-loop shifts the loop's internal index down and makes
	// it skip the next entry, so a live engine sitting behind a dropped one silently
	// stops counting toward thrust for that pass. Collect first, cut after.
	var/list/obj/machinery/power/shuttle_engine/ship/dropped = list()
	for(var/obj/machinery/power/shuttle_engine/ship/E in shuttle.engine_list)
		// Remove deleted engines
		if(QDELETED(E))
			dropped += E
			continue
		// Membership is judged purely geometrically (bounding box + z). Deliberately NOT
		// is_in_shuttle_bounds(): the mobile override layers a shuttle_areas instance
		// test on top, and turf-area bookkeeping can go wrong while the hull itself is
		// fine - another shuttle's footprint overlapping ours reassigns turfs into its
		// area until it leaves, and round 803 lost all four Delta thrusters to hull
		// tiles stranded in an orphaned same-type area instance. This proc runs every
		// helm UI tick, so an area test here turns any one bad frame into an engine
		// unbound for the rest of the round.
		if(!shuttle.is_in_shuttle_bounds_geometric(E))
			dropped += E
			continue
		var/area/engine_area = get_area(E)
		if(!(engine_area in shuttle.shuttle_areas))
			// Aboard geometrically, so keep it working - but this state is the trigger
			// behind every engine-disconnect report, so name the foreign area once per
			// episode rather than every UI tick.
			if(!E.logged_area_mismatch)
				E.logged_area_mismatch = TRUE
				log_shuttle("[name]: engine [E] at [AREACOORD(E)] is inside ship bounds but its area ([engine_area_name(E)]) is not one of the ship's areas - keeping it connected")
		else
			E.logged_area_mismatch = FALSE
		E.update_engine()
		if(E.enabled)
			calculated_thrust += E.engine_power
	for(var/obj/machinery/power/shuttle_engine/ship/E as anything in dropped)
		shuttle.engine_list -= E
		if(QDELETED(E))
			continue
		E.unsync_ship()
		// Off our hull for real. If it stands on some other ship's deck now (wrong-bind
		// while docked ship-to-ship, hull sections traded away), hand it over instead of
		// leaving it orphaned - the connect_loc relink unsync_ship() arms only fires on
		// admin/blueprint hull expansion, never in normal play.
		var/obj/docking_port/mobile/new_home = SSshuttle.get_containing_shuttle(E)
		if(new_home)
			E.connect_to_shuttle(port = new_home)
			log_shuttle("[name]: engine [E] at [AREACOORD(E)] left ship bounds - rebound to [new_home.name]")
		else
			log_shuttle("[name]: engine [E] at [AREACOORD(E)] left ship bounds - unsynced")
	est_thrust = calculated_thrust

/// Area name for the drop log above, kept separate so the log line stays readable.
/obj/structure/overmap/ship/proc/engine_area_name(obj/machinery/power/shuttle_engine/ship/E)
	var/area/engine_area = get_area(E)
	return engine_area ? "[engine_area.type]" : "nullspace"

/// How many diagnostic lines one engine refresh will read back before it stops.
#define ENGINE_DIAGNOSTIC_MAX_LINES 8

/**
 * Names every thruster on or beside the hull that the helm cannot use, and why.
 *
 * refresh_engines() silently prunes and silently ignores; a thruster bolted on a tile
 * the ship does not own simply never appears anywhere, and the round-6 crew burned
 * fifteen minutes theorising about cables and SMES units because nothing would say
 * "that tile is not your ship". This is the saying-it: run from the helm's manual
 * engine refresh (a button press, never the burn path - the sweep walks the whole
 * footprint plus a one-tile ring, which is exactly where nacelles get bolted on).
 *
 * Returns a list of player-facing strings; empty means nothing to complain about.
 */
/obj/structure/overmap/ship/proc/engine_diagnostic_report()
	var/list/lines = list()
	if(!shuttle)
		return lines
	// Same guard as refresh_engines(): mid-move the port's rect projects the old
	// heading from the new position and every geometric answer is wrong.
	if(shuttle.move_in_flight())
		lines += "Hull is mid-manoeuvre - engine survey unavailable until it settles."
		return lines
	var/turf/port_turf = get_turf(shuttle)
	if(!port_turf)
		return lines
	var/list/rect = shuttle.return_coords()
	var/min_x = max(1, min(rect[1], rect[3]) - 1)
	var/min_y = max(1, min(rect[2], rect[4]) - 1)
	var/max_x = min(world.maxx, max(rect[1], rect[3]) + 1)
	var/max_y = min(world.maxy, max(rect[2], rect[4]) + 1)

	// Everything registered, plus everything physically on or hugging the footprint -
	// the one-tile ring is where an unclaimed nacelle row sits.
	var/list/obj/machinery/power/shuttle_engine/ship/candidates = list()
	for(var/obj/machinery/power/shuttle_engine/ship/registered in shuttle.engine_list)
		candidates |= registered
	for(var/turf/tile as anything in block(locate(min_x, min_y, port_turf.z), locate(max_x, max_y, port_turf.z)))
		for(var/obj/machinery/power/shuttle_engine/ship/found in tile)
			candidates |= found

	for(var/obj/machinery/power/shuttle_engine/ship/engine as anything in candidates)
		if(QDELETED(engine))
			continue
		// A ship docked against us parks its own nacelles inside our ring - their
		// engines are their business, not a fault on our report.
		var/obj/docking_port/mobile/owner = engine.connected_ship_ref?.resolve()
		if(owner && owner != shuttle)
			continue
		var/reason = engine.link_refusal_reason(shuttle)
		if(!reason)
			continue
		lines += "[engine.name] at ([engine.x], [engine.y]): [reason]"
		if(length(lines) >= ENGINE_DIAGNOSTIC_MAX_LINES)
			break
	return lines

#undef ENGINE_DIAGNOSTIC_MAX_LINES

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
	// Remember crew across respawns until the password changes or join access is reset.
	if(crewmate.ckey)
		password_cleared_ckeys[crewmate.ckey] = TRUE

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
 * Puts an already-spawned player on this ship's crew roster, the same way accepting a
 * captain's invite does: team membership, manifest entry, and a saved password
 * clearance for their ckey (every crew-adding path must grant that - see the join
 * password rules above).
 *
 * NOT register_crewmember(): that is for fresh spawns only - it wipes the mind's
 * memory and folds their bank account into ours, which would trash the character of
 * anyone who already has a life on another ship. This also deliberately leaves their
 * other crew memberships alone: founding or being handed a second hull should not
 * strip a player off their first one.
 *
 * Returns TRUE if they ended up on the roster.
 */
/obj/structure/overmap/ship/proc/enlist_crewmember(mob/living/crewmate)
	if(!crewmate?.mind || !ship_team)
		return FALSE
	ship_team.add_member(crewmate.mind) // no-op if they are already aboard
	if(!(crewmate.real_name in manifest))
		manifest += crewmate.real_name
	if(crewmate.ckey)
		password_cleared_ckeys[crewmate.ckey] = TRUE
	return TRUE

/**
 * ##destroy_ship
 *
 * Deletes the ship, if there's no humans on.
 */
/**
 * Abandons the ship - clears ownership and makes it claimable by anyone.
 * Called when all crew die/leave and the deletion timer fires.
 * * crash - If TRUE, crash the ship if it's currently flying
 */
/obj/structure/overmap/ship/proc/abandon_ship(crash = TRUE)
	if(abandoned)
		return // Already abandoned

	abandoned = TRUE
	abandoned_at = world.time // starts the derelict-despawn clock (SSovermap.sweep_derelicts)
	joining_allowed = FALSE // Disable cryopod spawning until claimed
	// A derelict is public salvage - the old crew's lock dies with their tenure
	join_password = null
	password_cleared_ckeys = list()
	// ...and so does the crew-only airlock lock. Set directly rather than through
	// set_crew_only_airlocks(): the roster is about to be emptied, so its crew
	// announcement would reach nobody anyway.
	crew_only_airlocks = FALSE
	GLOB.crew_locked_ships -= src

	// Clear all crew members properly (removes antag datums). Snapshot the roster
	// first: the announcement at the bottom has to reach these players, and by the
	// time it runs the team is empty.
	var/list/former_members
	if(ship_team)
		former_members = ship_team.members?.Copy()
		for(var/datum/mind/member in former_members)
			ship_team.remove_member(member)

	// If flying and crash requested, trigger crash landing. Drive the latch along with it, or
	// the hull reads sound while sitting in a crash site and the next real hit is swallowed by
	// on_ship_destroyed()'s re-entry guard.
	if(crash && (state in list(OVERMAP_SHIP_FLYING, OVERMAP_SHIP_UNDOCKING, OVERMAP_SHIP_ACTING)))
		enter_integrity_failure()

	// Crash docking finishes asynchronously. Follow the shuttle itself so this link
	// still reaches the hull after it leaves the coordinates where it was abandoned.
	message_admins("\[SHUTTLE]: [name] has been abandoned and is now claimable! It will despawn in [SHIP_DERELICT_DESPAWN_TIME / 600] minutes if unclaimed. [ADMIN_FLW(shuttle)]")
	log_shuttle("[name] has been abandoned and is claimable; despawn due in [SHIP_DERELICT_DESPAWN_TIME / 600] minutes.")

	// Use the saved roster because ship_notify() would see the now-empty team.
	for(var/mob/player_mob as anything in get_abandonment_recipients(former_members))
		to_chat(player_mob, span_boldwarning("Your ship, [name], has been abandoned: it went too long with no living crew aboard. It no longer appears in the ship join list, but it is still out there - anyone who reaches it can claim it from its helm console."))
		SEND_SOUND(player_mob, sound('voidcrew/sound/warn.ogg', volume = 25))

/// Find the players still playing (or ghosting) the characters on the former roster.
/obj/structure/overmap/ship/proc/get_abandonment_recipients(list/former_members)
	var/list/recipients = list()
	for(var/datum/mind/member as anything in former_members)
		if(!member?.key)
			continue
		var/mob/player_mob = get_mob_by_ckey(ckey(member.key))
		// Old minds keep their key after respawning. An account match alone can
		// notify a different crew's character, once per old life on this roster.
		// Ghosts retain the body's mind, so this still reaches dead crewmembers.
		if(!player_mob || player_mob.mind != member)
			continue
		recipients |= player_mob
	return recipients

// ===== CAPTAIN MANAGEMENT =====

/**
 * Check if a mob is the captain of this ship.
 * Returns TRUE if the mob holds the officer role for this ship,
 * or if they are the claimed_captain (for NPC ships without job_slots).
 */
/obj/structure/overmap/ship/proc/is_ship_captain(mob/living/check_mob)
	return is_ship_captain_mind(check_mob?.mind)

/// Mind-based command check, also used by the admin roster for offline crew.
/obj/structure/overmap/ship/proc/is_ship_captain_mind(datum/mind/check_mind)
	if(!check_mind)
		return FALSE
	if(!(check_mind in ship_team?.members))
		return FALSE

	// An explicit claim is authoritative AND exclusive. Claiming a derelict lands
	// here, and so does every command transfer and election, so on a ship where
	// command has been handed over exactly one person answers TRUE - the officer job
	// stops conferring it, and a revived former captain does not get it back unless
	// command is transferred to them again. A claimed captain who leaves the roster
	// clears the var (see /datum/team/voidcrew/remove_member), so this can never lock
	// a crew out of their own bridge.
	if(claimed_captain)
		return check_mind == claimed_captain

	// Acting captain: first joiner on a captainless ship. Holds command only while
	// no real captain exists - their authority ends the moment one arrives.
	if(acting_captain && check_mind == acting_captain && !has_real_captain())
		return TRUE

	var/datum/job/captain_job = get_captain_job()
	if(!captain_job)
		return FALSE

	// Ship slots are distinct datums even when their outfits use the same job type:
	// the Pill's Head Prisoner and Prisoner are both /datum/job/prisoner.
	return check_mind.assigned_role == captain_job

/**
 * Get the captain job datum for this ship.
 * Returns the first job with officer = TRUE, or the first job as fallback.
 */
/obj/structure/overmap/ship/proc/get_captain_job()
	for(var/datum/job/job in job_slots)
		if(job.officer)
			return job
	// Fallback to first job if no officer defined
	if(length(job_slots))
		for(var/datum/job/job in job_slots)
			return job
	return null

/**
 * Get the current captain mob if they are online.
 */
/obj/structure/overmap/ship/proc/get_captain()
	for(var/datum/mind/member in ship_team?.members)
		if(member.current?.client && is_ship_captain_mind(member))
			return member.current
	return null

/**
 * Whether the ship has a real captain: a crew member holding the officer job,
 * or a claimed captain (NPC/abandoned hulls). While FALSE, an acting captain
 * holds command authority.
 */
/obj/structure/overmap/ship/proc/has_real_captain()
	if(claimed_captain && (claimed_captain in ship_team?.members))
		return TRUE
	var/datum/job/captain_job = get_captain_job()
	if(!captain_job)
		return FALSE
	for(var/datum/mind/member in ship_team?.members)
		if(member.assigned_role == captain_job)
			return TRUE
	return FALSE

/**
 * Hands acting command of a captainless ship to a crew member: they get the Ship
 * Management button and captain-level checks until a real captain arrives.
 * Returns TRUE if they were given acting command.
 */
/obj/structure/overmap/ship/proc/make_acting_captain(mob/living/holder)
	if(!holder?.mind)
		return FALSE
	if(has_real_captain())
		return FALSE
	if(acting_captain && (acting_captain in ship_team?.members))
		return FALSE // someone already holds acting command
	acting_captain = holder.mind
	grant_captain_management(holder, src)
	to_chat(holder, span_boldnotice("No captain is registered aboard [name]. Command authority falls to you until a [get_captain_job()?.title || "captain"] joins."))
	ship_notify("[holder.real_name] has assumed acting command of the vessel.", "SHIP SYSTEMS", SHIP_NOTIFY_NOTICE, 'voidcrew/sound/notify.ogg', 50)
	log_game("[key_name(holder)] assumed acting command of [name] (no captain aboard)")
	return TRUE

/**
 * Revokes acting command, because a real captain has arrived. The former acting
 * captain loses the Ship Management button; a real captain who already held acting
 * command over their own ship keeps theirs.
 */
/obj/structure/overmap/ship/proc/clear_acting_captain(mob/living/real_captain)
	if(!acting_captain)
		return
	var/mob/living/former_holder = acting_captain.current
	acting_captain = null
	if(!former_holder || former_holder == real_captain)
		return
	remove_captain_management(former_holder, src)
	to_chat(former_holder, span_boldwarning("[real_captain.real_name] has taken command of [name] - your acting command is over."))
	ship_notify("Command authority transferred to [real_captain.real_name]. [former_holder.real_name] stands down from acting command.", "SHIP SYSTEMS", SHIP_NOTIFY_NOTICE, 'voidcrew/sound/notify.ogg', 50)
	log_game("[key_name(former_holder)] lost acting command of [name]: [key_name(real_captain)] took command")

/**
 * Whether this mob may rename the ship: the captain always can; if no captain is
 * available to object (dead, offline, or none assigned), any crew member can.
 */
/obj/structure/overmap/ship/proc/can_rename_ship(mob/living/user)
	if(!user?.mind || !(user.mind in ship_team?.members))
		return FALSE
	if(is_ship_captain(user))
		return TRUE
	// A claimed captain who is alive and connected keeps rename authority to themselves
	var/mob/living/claimed = claimed_captain?.current
	if(claimed?.client && claimed.stat != DEAD)
		return FALSE
	// Same for an acting captain
	var/mob/living/acting = acting_captain?.current
	if(acting?.client && acting.stat != DEAD)
		return FALSE
	// Same for a role-assigned captain
	var/mob/living/captain_mob = get_captain()
	if(captain_mob && captain_mob.stat != DEAD)
		return FALSE
	return TRUE

// ===== JOIN PASSWORD =====

/**
 * Whether this hull may carry a join password at all. The roundstart fleet is the public
 * fleet - locking one would let a crew privatize a hull the round spawned for everyone -
 * so only player-created ships (purchased, requisitioned, commissioned) qualify.
 */
/obj/structure/overmap/ship/proc/can_have_join_password()
	return !(src in SSovermap.initial_ships)

/// Whether a ckey may board without being asked for the password.
/obj/structure/overmap/ship/proc/is_password_cleared(ckey)
	if(!join_password)
		return TRUE
	if(!ckey)
		return FALSE
	return (ckey in password_cleared_ckeys)

/**
 * Whether an attempt matches the join password. Case-insensitive and trimmed - the
 * password travels by being typed into another chat window, so exact casing is the
 * kind of thing that locks friends out over nothing.
 */
/obj/structure/overmap/ship/proc/check_join_password(attempt)
	if(!join_password)
		return TRUE
	return lowertext(trim("[attempt || ""]")) == lowertext(join_password)

/**
 * Sets (or clears, on null/empty) the join password. Changing it also revokes saved
 * join access, including approved applications. Returns TRUE on success.
 * The caller is responsible for authorization; this only enforces which hulls
 * may carry a password at all.
 */
/obj/structure/overmap/ship/proc/set_join_password(new_password, mob/user)
	if(!can_have_join_password())
		if(user)
			to_chat(user, span_warning("[name] is a fleet-issued vessel - joining stays public."))
		return FALSE
	new_password = trim("[new_password || ""]", SHIP_JOIN_PASSWORD_MAX_LEN + 1)
	if(!length(new_password))
		if(!join_password)
			return TRUE
		join_password = null
		reset_join_access()
		if(user)
			to_chat(user, span_notice("Join password cleared - anyone may join [name] again."))
		log_game("[key_name(user)] cleared the join password of ship [name]")
		return TRUE
	if(join_password && check_join_password(new_password))
		return TRUE
	join_password = new_password
	reset_join_access()
	if(user)
		to_chat(user, span_notice("Join password set and saved join access cleared. Players joining [name] from the lobby must enter the new password or receive a new approval or invitation."))
	log_game("[key_name(user)] set a join password on ship [name]")
	return TRUE

/**
 * Revokes remembered passwords, invitations, and application approvals without
 * removing anyone from the crew roster. Authorization is the caller's responsibility.
 */
/obj/structure/overmap/ship/proc/reset_join_access(mob/user)
	password_cleared_ckeys.Cut()
	if(user)
		to_chat(user, span_notice("Saved join access and application approvals for [name] have been cleared. Players must enter the current password or receive a new approval or invitation to rejoin. Crew already aboard remain on the roster."))
		log_game("[key_name(user)] reset saved join access and application approvals for ship [name]")
	return TRUE

// ===== CREW-ONLY AIRLOCKS =====

/**
 * Whether a mob counts as this ship's crew.
 *
 * Two things make you crew and either one is enough: your mind is on the ship's team
 * (you serve aboard right now), or your ckey is cleared past the join password - you
 * bought the hull, you were invited, you typed the password, or you served aboard
 * earlier this round, since the last password change or join access reset. The ckey
 * clause is what keeps a crewman who died and came back
 * through the lobby from being locked out of their own airlocks while the new body's
 * mind is still being put on the roster.
 *
 * Deliberately takes a plain /mob: ghosts and non-human crew ask this too.
 */
/obj/structure/overmap/ship/proc/is_ship_crew(mob/checking)
	if(!checking)
		return FALSE
	if(checking.mind && (checking.mind in ship_team?.members))
		return TRUE
	var/checking_ckey = checking.ckey
	if(!checking_ckey)
		return FALSE
	return (checking_ckey in password_cleared_ckeys)

/**
 * Turns the crew-only airlock lock on or off. Returns TRUE if the state changed.
 *
 * Same hull rule as the join password: the roundstart fleet is the public fleet and
 * cannot be locked, so a crew cannot privatize a hull the round spawned for everyone.
 * Authorization (captain, alive, aboard) is the caller's job; this only enforces which
 * hulls may carry the lock at all, and keeps GLOB.crew_locked_ships in step so the
 * door hot path can skip the whole feature while no ship is using it.
 */
/obj/structure/overmap/ship/proc/set_crew_only_airlocks(new_state, mob/user)
	new_state = !!new_state
	if(new_state && !can_have_join_password())
		if(user)
			to_chat(user, span_warning("[name] is a fleet-issued vessel - its airlocks stay open to everyone."))
		return FALSE
	if(crew_only_airlocks == new_state)
		return FALSE
	crew_only_airlocks = new_state
	if(new_state)
		GLOB.crew_locked_ships |= src
	else
		GLOB.crew_locked_ships -= src
	if(user)
		log_game("[key_name(user)] turned crew-only airlocks [new_state ? "on" : "off"] aboard ship [name]")
	var/lock_message = new_state \
		? "Airlock control is now keyed to the crew roster. Anyone not on it will be refused at the doors." \
		: "Airlock control is no longer keyed to the crew roster. The doors open for anyone again."
	ship_notify(lock_message, "SHIP SYSTEMS", SHIP_NOTIFY_NOTICE, 'voidcrew/sound/notify.ogg', 30)
	return TRUE

/**
 * Claims an abandoned ship for a new owner.
 * * claimer - The mob claiming the ship
 */
/obj/structure/overmap/ship/proc/claim_abandoned_ship(mob/living/claimer)
	if(!abandoned)
		return FALSE
	if(!claimer?.mind)
		return FALSE

	// Reset abandoned state, stopping the derelict-despawn clock
	abandoned = FALSE
	abandoned_at = 0
	crewless_since = 0
	joining_allowed = TRUE // Re-enable cryopod spawning

	// Create new ship team or use existing (cleared) one
	if(!ship_team)
		ship_team = new /datum/team/voidcrew()
		ship_team.name = name
		ship_team.ship = src

	// Add claimer to ship team. Every crew-adding path also clears the ckey through
	// the join password gate - the claimer must never be locked out of the hull they
	// now command if they die and respawn through the lobby.
	ship_team.add_member(claimer.mind)
	if(claimer.ckey)
		password_cleared_ckeys[claimer.ckey] = TRUE

	// Set the claimer as captain
	claimed_captain = claimer.mind

	// A claimed captain supersedes any acting command
	clear_acting_captain(claimer)

	// Grant the Captain Management action button
	grant_captain_management(claimer, src)

	// Announce
	ship_notify("NOTICE: Command authorization restored. New commanding officer: [claimer.real_name].", "SHIP SYSTEMS", SHIP_NOTIFY_NOTICE, 'voidcrew/sound/notify.ogg', 50)

	to_chat(claimer, span_notice("You have claimed command of [name]!"))
	log_game("[key_name(claimer)] claimed abandoned ship [name] at [AREACOORD(src)]")

	return TRUE

/**
 * Removes the ship from the round.
 *
 * force = TRUE deletes the hull outright; otherwise the ship is left behind as an
 * abandoned derelict for someone else to claim.
 *
 * ignore_crew exists for the bluespace jump, which is meant to take the crew with
 * it - the helm asks for confirmation first, and extraction runs before the call.
 * Without it the crew check below rejected every jump ever attempted, silently:
 * anyone flying the ship is by definition standing on it, and do_jump() is the
 * only caller there has ever been.
 */
/obj/structure/overmap/ship/proc/destroy_ship(force, ignore_crew = FALSE)
	// For backward compatibility, redirect to abandon_ship unless forced
	if(force)
		if(!ignore_crew && length(shuttle?.get_all_humans()) > 0)
			return FALSE
		message_admins("\[SHUTTLE]: [shuttle?.name] has been FORCE deleted!")
		log_shuttle("[shuttle?.name] has been force deleted!")
		shuttle?.jumpToNullSpace()
		qdel(src)
		return TRUE

	// Normal case: abandon instead of delete
	abandon_ship()
	return TRUE

/**
 * Deletes a derelict hull and releases everything it was pinning: the berth flags at
 * whatever it is docked to (which is what lets that site's own unload machinery tear
 * down its map zone - a derelict never undocks, so without this every abandoned ship
 * pinned a zone and eventually a whole z-level for the rest of the round), its transit
 * reservation, and its overmap datum.
 *
 * Called only by SSovermap.sweep_derelicts() once the claim window is over. Anyone
 * physically aboard aborts the teardown; the sweep simply tries again a minute later.
 */
/obj/structure/overmap/ship/proc/despawn_derelict()
	if(QDELETED(src))
		return FALSE
	// Any connected player physically aboard holds the teardown - dead ones too,
	// deliberately: a body with a player behind it may be mid-rescue, and unlike the
	// abandonment clock this check costs nothing to be generous with.
	for(var/mob/player as anything in GLOB.player_list)
		if(isliving(player) && is_aboard(player))
			return FALSE
	// A ship docked to us ship-to-ship parks its overmap token in our contents.
	// Deleting the host would strand the guest inside a deleted loc.
	for(var/obj/structure/overmap/ship/guest in src)
		return FALSE

	log_shuttle("[name]: derelict despawned (abandoned [(world.time - abandoned_at) / 600] minutes ago).")
	message_admins("\[SHUTTLE]: Derelict [name] has despawned. [ADMIN_COORDJMP(shuttle?.loc)]")

	// Hand our berth back before the hull goes - the subset of complete_dock()'s
	// undocking branch that releases the site. can_release_interior() reads these
	// flags, and a deleted ship never runs the undock path that clears them.
	var/obj/structure/overmap/site = docked
	if(site)
		if(istype(site, /obj/structure/overmap/ship))
			var/obj/structure/overmap/ship/host = site
			if(host.shuttle && host.shuttle != shuttle)
				host.shuttle.shuttle_areas -= shuttle.shuttle_areas
			SEND_SIGNAL(host, COMSIG_VOIDCREW_SHIP_UNDOCKED_BY, src)
		release_berth_flags(site)
		site.on_ship_undock_complete(src) // frees hangar berths at outposts; no-op elsewhere
		if(istype(site, /obj/structure/overmap/space_ruin))
			addtimer(CALLBACK(site, TYPE_PROC_REF(/obj/structure/overmap/space_ruin, check_and_respawn)), 5 SECONDS)
		else if(istype(site, /obj/structure/overmap/event/meteor))
			addtimer(CALLBACK(site, TYPE_PROC_REF(/obj/structure/overmap/event/meteor, unload_level)), 5 SECONDS)
		// Planets and empty-space placeholders (crash sites included) registered
		// on_ship_undocked() on us when we entered; this is what schedules their own
		// unload once the hull is gone.
		SEND_SIGNAL(src, COMSIG_VOIDCREW_SHIP_UNDOCKED)
		docked = null

	// Drop the hard refs other ships hold on us. A stale entry keeps the datum from
	// garbage collecting and hands SSgarbage an expensive hard delete instead.
	for(var/obj/structure/overmap/ship/other as anything in SSovermap.simulated_ships)
		if(other == src)
			continue
		LAZYREMOVE(other.close_overmap_objects, src)
		if(other.pending_dock_target == src)
			other.pending_dock_target = null

	// intoTheSunset() rather than a bare jumpToNullSpace(): it ghostizes every mob aboard
	// first, corpses included. A mind-holding corpse left on the site's turfs would fail
	// get_mind_mobs() and pin the map zone anyway. It ends in jumpToNullSpace(), which
	// frees the transit reservation and the port.
	//
	// But it moves those mobs to NULLSPACE rather than deleting them, and it does so
	// BEFORE jumpToNullSpace()'s per-turf empty() pass - so every mob aboard survives the
	// teardown in GLOB.mob_list/mob_living_list for the rest of the round. That is correct
	// for the round-end escape shuttle it was written for (those mobs are still players
	// being scored) and a straight leak here: 3-6 pirates or a dead crew per despawned
	// hull. Clear them out ourselves first. Nothing with a connected player behind it can
	// be here - the guard at the top of this proc already refused - so this is NPCs,
	// corpses, and the bodies of crew who logged off, which ARE the abandoned ship.
	if(shuttle)
		for(var/turf/hull_turf as anything in shuttle.return_turfs())
			if(!hull_turf)
				continue
			for(var/mob/living/aboard in hull_turf.get_all_contents())
				if(QDELETED(aboard))
					continue
				aboard.ghostize(FALSE) // a disconnected player's body still holds their key
				qdel(aboard)
		shuttle.intoTheSunset()
	qdel(src)
	return TRUE

/**
 * The dynamic encounter this hull should be force-undocked from, or null if it should
 * stay where it is.
 *
 * Only called for hulls SSovermap's sweep has already found crewless, so "no active crew"
 * is a given here and is deliberately not re-tested - has_active_crew() walks the player
 * list and this hull's roster, and the sweep has just paid for it. Note that clears the
 * away-team case on its own: a hull berthed at a site its crew is exploring shares that
 * site's z, so the crew hold it and this never runs against them.
 *
 * Restricted to the encounters that mint an interior and cannot give it back while a hull
 * sits in their contents. Trader outposts, player outposts and the colosseum are permanent
 * fixtures with nothing to free, and a ship-to-ship dock is two crews' business rather
 * than a pinned site.
 */
/obj/structure/overmap/ship/proc/get_dead_site_undock_target()
	// Cheap checks first: this runs once a minute for every crewless hull in the fleet,
	// and the site-wide player scan below is the only part that costs anything.
	if(QDELETED(src) || !shuttle)
		return null
	// Anything other than IDLE is a hull in flight, mid-dock or already undocking.
	if(state != OVERMAP_SHIP_IDLE)
		return null
	var/obj/structure/overmap/site = docked
	if(!site || QDELETED(site))
		return null
	// Never while the site is busy with its own load or teardown - `concerned` is the
	// shared latch, the rest are per-family and each of the three declares its own.
	if(site.concerned)
		return null
	if(istype(site, /obj/structure/overmap/planet))
		var/obj/structure/overmap/planet/planet_site = site
		if(planet_site.loading || planet_site.unloading)
			return null
	else if(istype(site, /obj/structure/overmap/space_ruin))
		var/obj/structure/overmap/space_ruin/ruin_site = site
		if(ruin_site.loading)
			return null
	else if(istype(site, /obj/structure/overmap/event/meteor))
		var/obj/structure/overmap/event/meteor/field_site = site
		if(field_site.loading)
			return null
	else
		return null // outpost, colosseum, another ship: nothing pinned, nothing to do

	// Two hulls sharing an empty-space encounter are berthed to a /planet/empty and pass
	// the gate above, so this has to be asked even though a ship is never `docked` to
	// another ship's type here. A rendezvous is the two crews' business, not ours.
	if(is_in_ship_to_ship_dock())
		return null

	// An NPC hull whose own crew is still alive keeps its "board it and finish the job"
	// window, however dead the hull is - the pirate pool frees its slot on a crew wipe or
	// on the key, never on a hull kill, and towing the wreck out of its crash site would
	// take the fight with it.
	var/obj/structure/overmap/ship/npc/npc_self = src
	if(istype(npc_self) && npc_self.count_live_crew_aboard())
		return null

	if(site_has_living_players(site))
		return null
	return site

/**
 * Whether anyone still counts as manning this hull, for the derelict clocks in
 * SSovermap.sweep_derelicts(). TRUE keeps both clocks rewound.
 *
 * Two ways to qualify, and both want a living, client-connected player:
 *
 * 1. Physically aboard - get_event_crew(), any player at all, roster or not. Someone
 *    standing in the engine room is someone the hull is not empty of, and a boarder
 *    who has taken up residence is a crew as far as the teardown is concerned.
 * 2. On the hull's own z-level, and on this hull's roster. A landing party is not an
 *    abandoned crew: they walked out through their own airlock, they are alive, they
 *    are connected, and their ship is thirty tiles away. Aboard-only read that as
 *    derelict and handed their hull to whoever found it while they were standing on
 *    it - so the crewless clock now needs them to be gone, not merely outdoors.
 *
 * The roster scoping in 2 is load-bearing, not decoration. Ship z-levels are shared:
 * a flying hull sits on a transit level with every other hull in flight, and a berthed
 * one sits on an encounter level packed with up to three neighbouring sites. A bare
 * "is any player on this z" test reads the crew of the ship parked next door as ours
 * and no hull in a busy round would ever go derelict. ship_team.members is the only
 * list that says whose crew this is.
 *
 * Deliberately unchanged: crews that are dead, ghosted, cryoed out or logged off do
 * not count under either clause, which is the whole point of the sweep. Cryo takes the
 * mind off the roster on despawn (detach_from_crews()), so a pod full of logged-off
 * crew empties the hull exactly as it should.
 *
 * Not folded into get_event_crew(): that answers "who is inside this ship" for dynamic
 * events, which need mobs they can actually afflict, not a headcount of the away team.
 */
/obj/structure/overmap/ship/proc/has_active_crew()
	if(length(get_event_crew()))
		return TRUE
	if(!LAZYLEN(ship_team?.members))
		return FALSE
	// The hull's own z, not the overmap token's. get_turf() rather than shuttle.z so a
	// port mid-transit or with no loc reads as "no answer" instead of z 0, which would
	// match every mob that is also nowhere.
	var/turf/hull_turf = get_turf(shuttle)
	if(!hull_turf)
		return FALSE
	for(var/datum/mind/member as anything in ship_team.members)
		// `as anything` skips the istype filter, and a hard-deleted mind is nulled in
		// place in this list rather than removed from it.
		var/mob/living/body = member?.current
		if(QDELETED(body) || !isliving(body))
			continue
		// A ghosted player's mind still points at the body they left, so DEAD covers
		// the corpse and the client check covers everyone who logged off or aghosted.
		if(body.stat == DEAD || !body.client)
			continue
		// get_turf() again: a player inside a locker, a mech or a bodybag reads z 0 off
		// the mob itself.
		var/turf/body_turf = get_turf(body)
		if(body_turf?.z == hull_turf.z)
			return TRUE
	return FALSE

/**
 * Whether any living, connected player is standing anywhere inside `site`'s interior.
 *
 * Every site with an interior is scoped to a rectangle: a map footprint, one slot of up to
 * four on a shared z-level. A bare z match reads the neighbouring encounter's away team as
 * ours (the same reasoning as turf_footprint_has_players()). Only a site allocated outside
 * the slot register falls back to matching its map zone's whole level, which is what it
 * always did.
 *
 * GLOB.player_list is connected players only and runs a few dozen entries at most, so one
 * pass over it beats walking either interior. get_turf() rather than the mob's own z: a
 * player inside a locker, a mech or a bodybag reads z 0 off the mob.
 */
/obj/structure/overmap/ship/proc/site_has_living_players(obj/structure/overmap/site)
	var/list/site_z_values
	// Rectangle bounds, when the site is scoped to one. Every site with an interior now
	// answers with a map footprint (get_interior_footprint()) - a slot on a level it shares
	// with up to three neighbours, so the bare z match this used to do on some branches
	// reads a neighbour's crew as ours.
	var/min_x = 0
	var/min_y = 0
	var/max_x = 0
	var/max_y = 0
	var/bounded = FALSE
	var/datum/map_footprint/site_footprint = site?.get_interior_footprint()
	if(site_footprint && !isnull(site_footprint.low_x) && site_footprint.z_value)
		min_x = site_footprint.low_x
		min_y = site_footprint.low_y
		max_x = site_footprint.high_x
		max_y = site_footprint.high_y
		site_z_values = list(site_footprint.z_value)
		bounded = TRUE
	else if(istype(site, /obj/structure/overmap/planet))
		// A site with a map zone but no footprint: allocated outside the slot register, so
		// the whole level is the answer, exactly as it was before packing.
		var/obj/structure/overmap/planet/planet_site = site
		if(planet_site.mapzone)
			site_z_values = list()
			for(var/datum/space_level/zlevel as anything in planet_site.mapzone.z_levels)
				site_z_values += zlevel.z_value

	// No interior to stand in. A hull berthed at a site that has nothing loaded is exactly
	// the stranded case this exists for, so read it as empty rather than as blocking.
	if(!length(site_z_values))
		return FALSE

	for(var/mob/player as anything in GLOB.player_list)
		if(!isliving(player))
			continue
		var/mob/living/living_player = player
		if(living_player.stat == DEAD)
			continue
		var/turf/player_turf = get_turf(living_player)
		if(!player_turf)
			continue
		if(!(player_turf.z in site_z_values))
			continue
		if(bounded && (player_turf.x < min_x || player_turf.x > max_x || player_turf.y < min_y || player_turf.y > max_y))
			continue
		return TRUE
	return FALSE

/**
 * Runs the SHIP_SITE_DEAD_UNDOCK_TIME clock and force-undocks when it runs out.
 *
 * Called once a minute from SSovermap.sweep_derelicts(), for crewless hulls only. Returns
 * TRUE only when an undock was actually started.
 *
 * The undock goes through the ordinary undock() - warmup, state machine, and on completion
 * the same COMSIG_VOIDCREW_SHIP_UNDOCKED that releases the site when a crew leaves under
 * its own power. Nothing here is special-cased past the trigger.
 */
/obj/structure/overmap/ship/proc/check_dead_site_undock()
	var/obj/structure/overmap/site = get_dead_site_undock_target()
	if(!site)
		site_dead_since = 0
		site_dead_undock_refused = FALSE
		return FALSE
	if(!site_dead_since)
		site_dead_since = world.time
		return FALSE
	if(world.time - site_dead_since < SHIP_SITE_DEAD_UNDOCK_TIME)
		return FALSE

	var/refusal = undock()
	if(refusal)
		// Every refusal undock() can give here either expires on its own (the post-dock
		// stabilization cooldown, an interdiction lockout, the structural recertification
		// a failed hull is held for) or needs a crew that isn't here (a hull built out past
		// its docking port with no door to reseat to). Keep the stamp and try again next
		// sweep; say why once per streak rather than once a minute for as long as it runs.
		if(!site_dead_undock_refused)
			site_dead_undock_refused = TRUE
			log_shuttle("[name]: force-undock from [site] refused - [refusal] Retrying each sweep.")
		return FALSE

	log_shuttle("[name]: force-undocking from [site] - no living crew at the site for [(world.time - site_dead_since) / 600] minutes.")
	site_dead_since = 0
	site_dead_undock_refused = FALSE
	return TRUE

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

// ship_broadcast_runechat() moved to ship_transmissions.dm. It used to paint a
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

	interrupt_autopilot("interdiction field")

	// Cancel nebula hide warmup if interdicted during it
	if(nebula_hide_timer)
		cancel_nebula_hide()
		ship_notify("Interdiction field disrupted nebula concealment!", "WARNING", SHIP_NOTIFY_WARNING, 'voidcrew/sound/warn.ogg', 25)

	// Force unhide from nebula if interdicted while hidden
	if(hidden_in_nebula)
		unhide_from_nebula()
		ship_notify("Interdiction field forcing emergence from nebula!", "WARNING", SHIP_NOTIFY_WARNING, 'voidcrew/sound/warn.ogg', 25)

/**
  * Clears the interdiction effect on this ship.
  * Called when interdiction ends for any reason.
  */
/obj/structure/overmap/ship/proc/clear_interdiction()
	interdicting_machine_ref = null
	speed_multiplier = SHIP_SPEED_MULTIPLIER_DEFAULT
	interdiction_strength = 0
	is_interdicted = FALSE

/// Base shield health cost for shield burst (one generator's worth)
#define SHIELD_BURST_BASE_COST 500

/**
 * Gets the shield health required to burst free from current interdiction.
 * Cost scales with interdictor power level and upgrades: base_cost * power_level * effect_mult
 * Returns 0 if not interdicted.
 */
/obj/structure/overmap/ship/proc/get_burst_shield_cost()
	if(!is_interdicted)
		return 0
	var/obj/machinery/ship_combat/interdictor/interdictor = interdicting_machine_ref?.resolve()
	if(!interdictor)
		return SHIELD_BURST_BASE_COST  // Fallback to base cost
	return SHIELD_BURST_BASE_COST * interdictor.power_allocation * interdictor.effect_mult

/**
 * Checks if the ship can perform a shield burst to break interdiction.
 * Requirements:
 * - Ship must be interdicted, by a field that has finished locking
 * - Shields must be active (not broken)
 * - Shield health must meet the cost (base * interdictor power level)
 */
/obj/structure/overmap/ship/proc/can_burst_shields()
	if(!is_interdicted)
		return FALSE
	// is_interdicted is raised at warmup start (see start_interdiction's race-condition
	// note), which used to let a target burst out before the attacker ever earned the
	// lock - and still charged the attacker the full re-interdiction cooldown. A field
	// that is still warming up is escaped by flying out of range, not by dumping the
	// shield pool; bursting is only meaningful against a completed lock.
	var/obj/machinery/ship_combat/interdictor/interdicting_machine = interdicting_machine_ref?.resolve()
	if(interdicting_machine && !interdicting_machine.interdiction_active)
		return FALSE
	if(!shields_active || shields_broken)
		return FALSE
	var/required = get_burst_shield_cost()
	// Overhealth counts - the burst consumes the whole pool, overhealth included
	if(shield_health + shield_overhealth < required)
		return FALSE
	return TRUE

/**
 * Sacrifices all shield energy to break free from interdiction.
 * Drains shields to 0, puts them in broken/cooldown state, and clears interdiction.
 * Returns TRUE on success, FALSE if requirements not met.
 */
/obj/structure/overmap/ship/proc/burst_shields_break_interdiction()
	if(!can_burst_shields())
		return FALSE

	// Get the interdictor that's affecting us so we can notify it
	var/obj/machinery/ship_combat/interdictor/interdictor = interdicting_machine_ref?.resolve()

	// Break our shields - shield pop is NOT graceful, stored health resets to 0
	break_ship_shields(graceful = FALSE)

	// Clear our interdiction state
	clear_interdiction()

	// Tell the interdictor to stop (if it still exists)
	if(interdictor)
		interdictor.on_target_broke_free()

	// Announce to the ship
	ship_notify("SHIELD BURST SUCCESSFUL! Interdiction field disrupted. Shields offline - recharging.", "EMERGENCY MANEUVER", SHIP_NOTIFY_NOTICE, 'voidcrew/sound/notify.ogg', 50)

	return TRUE

// ===== LINE OF SIGHT CHECKS =====

/// Checks if this ship has line of sight to another ship (not blocked by nebulas or other opaque objects)
/obj/structure/overmap/ship/proc/has_los_to(obj/structure/overmap/ship/target)
	var/turf/our_turf = get_turf(src)
	var/turf/their_turf = get_turf(target)

	if(!our_turf || !their_turf)
		return FALSE

	// Same tile = always LOS
	if(our_turf == their_turf)
		return TRUE

	// Adjacent = skip the expensive checks
	if(get_dist(our_turf, their_turf) <= 1)
		return TRUE

	// Check all turfs between ships (excluding endpoints) for opaque blockers
	var/list/line = get_line(our_turf, their_turf)
	var/line_length = length(line)

	for(var/i in 2 to (line_length - 1)) // Skip first and last turf (the ships themselves)
		var/turf/T = line[i]
		// Check turf opacity (shouldn't happen on overmap but just in case)
		if(T.opacity)
			return FALSE
		// Check for opaque objects on the turf (nebulas have opacity = TRUE)
		for(var/atom/A in T)
			if(A.opacity && A != src && A != target)
				return FALSE

	return TRUE

// ===== NEBULA CONCEALMENT =====

/// Warmup time for nebula concealment in deciseconds
#define NEBULA_HIDE_WARMUP_TIME (10 SECONDS)
/// How long after a ram scoop harvest tick the ship stays too loud to conceal
#define SCOOP_EMISSIONS_LOCKOUT (10 SECONDS)

/// Whether recent ram scoop activity is lighting the ship up (blocks nebula concealment)
/obj/structure/overmap/ship/proc/is_scoop_hot()
	return world.time < last_scoop_activity + SCOOP_EMISSIONS_LOCKOUT

/**
 * Called by a mounted nebula ram scoop every tick it actually harvests gas.
 * Scooping is deliberately loud. It blocks new concealment attempts and rips
 * away any active concealment, so the fuel stop is also the ambush spot.
 */
/obj/structure/overmap/ship/proc/notify_scoop_activity()
	last_scoop_activity = world.time
	if(nebula_hide_timer)
		cancel_nebula_hide()
		ship_notify("Ram scoop emissions disrupted nebula concealment!", "WARNING", SHIP_NOTIFY_WARNING, 'voidcrew/sound/warn.ogg', 25)
	if(hidden_in_nebula)
		unhide_from_nebula()
		ship_notify("Ram scoop emissions have revealed the ship!", "WARNING", SHIP_NOTIFY_WARNING, 'voidcrew/sound/warn.ogg', 25)

/// Checks if the ship can start hiding in a nebula
/obj/structure/overmap/ship/proc/can_hide_in_nebula()
	// Already hidden or in process of hiding
	if(hidden_in_nebula || nebula_hide_timer)
		return FALSE

	// Can't hide while interdicted
	if(is_interdicted)
		return FALSE

	// Active ram scoop emissions light the ship up
	if(is_scoop_hot())
		return FALSE

	// Must be on a nebula tile
	var/turf/our_turf = get_turf(src)
	if(!our_turf)
		return FALSE

	for(var/obj/structure/overmap/event/nebula/N in our_turf)
		return TRUE

	return FALSE

/// Starts the nebula hide warmup process (10 seconds)
/obj/structure/overmap/ship/proc/hide_in_nebula()
	if(!can_hide_in_nebula())
		return FALSE

	// Stop all movement first - we're holding position to hide
	speed[1] = 0
	speed[2] = 0
	update_flight_parallax() // holding position means the starfield stops too

	// Start the warmup timer
	nebula_hide_timer = addtimer(CALLBACK(src, PROC_REF(complete_nebula_hide)), NEBULA_HIDE_WARMUP_TIME, TIMER_STOPPABLE)

	// Announce to crew
	ship_notify("Entering the nebula in [NEBULA_HIDE_WARMUP_TIME / 10] seconds", "HELM", SHIP_NOTIFY_NOTICE, 'voidcrew/sound/notify.ogg', 50)

	return TRUE

/// Completes the nebula hide process after warmup
/obj/structure/overmap/ship/proc/complete_nebula_hide()
	nebula_hide_timer = null

	// Verify we're still on a nebula and can hide
	var/turf/our_turf = get_turf(src)
	var/on_nebula = FALSE
	if(our_turf)
		for(var/obj/structure/overmap/event/nebula/N in our_turf)
			on_nebula = TRUE
			break

	if(!on_nebula || is_interdicted || is_scoop_hot())
		return FALSE

	hidden_in_nebula = TRUE

	// Make the ship invisible using managed invisibility (so it stacks properly with cloak)
	SetInvisibility(INVISIBILITY_ABSTRACT, "nebula_concealment", 100)

	// Send signal to drop all combat connections
	SEND_SIGNAL(src, COMSIG_SHIP_GOING_DARK)

	return TRUE

/// Cancels an in-progress nebula hide attempt
/obj/structure/overmap/ship/proc/cancel_nebula_hide()
	if(!nebula_hide_timer)
		return FALSE

	deltimer(nebula_hide_timer)
	nebula_hide_timer = null

	return TRUE

/// Checks if the ship can emerge from nebula concealment
/obj/structure/overmap/ship/proc/can_unhide_from_nebula()
	return hidden_in_nebula

/// Emerges from nebula concealment - makes the ship visible again
/obj/structure/overmap/ship/proc/unhide_from_nebula()
	if(!can_unhide_from_nebula())
		return FALSE

	hidden_in_nebula = FALSE

	// Remove the nebula invisibility source (may still be invisible if cloaked)
	RemoveInvisibility("nebula_concealment")

	// Send signal that we're emerging
	SEND_SIGNAL(src, COMSIG_SHIP_EMERGING_FROM_NEBULA)

	// Announce to crew
	ship_notify("Emerging from nebula concealment.", "HELM", SHIP_NOTIFY_NOTICE, 'voidcrew/sound/notify.ogg', 50)

	return TRUE

/// How many one-second complete_dock() retries to spend waiting for the shuttle to
/// physically finish a move before giving up and putting the ship back into a state the
/// helm can actually drive. A healthy move lands on the next SSshuttle fire; a shuttle
/// waiting on a transit reservation retries every 2 seconds and may never get one (the
/// global budget, MAX_TRANSIT_TILE_COUNT, is finite and shared by every flying ship), and
/// the old code retried forever - leaving `state` pinned at DOCKING/UNDOCKING, which the
/// helm's ui_act has no branch for, so every button on the console silently did nothing.
#define DOCK_MOVE_MAX_ATTEMPTS 30

/// How long a ship may sit in one transitional overmap state - DOCKING, UNDOCKING or ACTING -
/// before SSovermap's poll treats the sequence as lost and reconciles the ship against where its
/// hull physically is. Every one of those states greys out all four helm ops buttons and the
/// cargo console's call button, so a sequence that quietly stops advancing is a dead ship for the
/// rest of the round; today the only exit is an admin editing `state` by hand.
///
/// Generous on purpose. A healthy dock is the warmup plus at most DOCK_MOVE_MAX_ATTEMPTS of
/// retries, and the waits that legitimately run longer than that - a destination still generating
/// its interior, a sector build somebody else is holding the worldgen queue for - hold the clock
/// rather than counting against it. Reaching this means nothing is coming.
#define MANOEUVRE_STALL_TIMEOUT (90 SECONDS)

/// Dock warmup time in deciseconds
#define DOCK_WARMUP_TIME (10 SECONDS)
/// Undock warmup time in deciseconds
#define UNDOCK_WARMUP_TIME (10 SECONDS)
/// Undock cooldown time in deciseconds (after docking, before can undock)
#define UNDOCK_COOLDOWN_TIME (20 SECONDS)

/**
 * Messaging only, no flow change: request() (mobile_port.dm) drops a dock call on the
 * floor when its berth check fails - no return value and no player-facing sign, so the
 * sequence just sits until the stall watchdog reconciles it and the crew invents a
 * reason. Run the same side-effect-free geometry check request() is about to run and
 * TELL the crew when the request is going to be refused. Changes no state and blocks
 * nothing - the caller still issues the request exactly as before.
 *
 * Returns TRUE when a refusal was detected (and broadcast), FALSE when the request
 * should go through.
 */
/obj/structure/overmap/ship/proc/explain_dock_refusal(obj/docking_port/stationary/dock_to_use)
	if(!shuttle || !dock_to_use)
		return FALSE
	var/status = shuttle.canDock(dock_to_use)
	// ALREADY_DOCKED is benign - request() treats it as "nothing to do", not a fault
	if(status == SHUTTLE_CAN_DOCK || status == SHUTTLE_ALREADY_DOCKED)
		return FALSE
	var/reason
	switch(status)
		if(SHUTTLE_DWIDTH_TOO_LARGE, SHUTTLE_WIDTH_TOO_LARGE, SHUTTLE_DHEIGHT_TOO_LARGE, SHUTTLE_HEIGHT_TOO_LARGE)
			reason = "this ship does not fit that berth ([status]). A hull extension can outgrow a berth's clearance."
		if(SHUTTLE_SOMEONE_ELSE_DOCKED)
			reason = "another vessel is already occupying that berth."
		else
			reason = "the berth rejected the request ([status])."
	ship_notify("DOCKING FAULT: [reason]", "DOCKING", SHIP_NOTIFY_WARNING, 'voidcrew/sound/warn.ogg', 25)
	return TRUE

/**
  * Docks the shuttle by requesting a port at the requested spot.
  * * to_dock - The [/obj/structure/overmap] to dock to.
  * * dock_to_use - The [/obj/docking_port/mobile] to dock to.
  * * instant - If TRUE, bypasses the dock warmup (used for force dock)
  */
/obj/structure/overmap/ship/proc/dock(obj/structure/overmap/to_dock, obj/docking_port/stationary/dock_to_use, instant = FALSE)
	// Can't dock while being interdicted (unless it's a force dock)
	if(is_interdicted && !instant)
		// ship_act() callers pre-check interdiction, but if a refused dock still
		// reaches here with the ship locked into ACTING, restore it - a ship left
		// in ACTING can never move, dock, or undock again
		if(state == OVERMAP_SHIP_ACTING)
			state = OVERMAP_SHIP_FLYING
		ship_notify("DOCKING ABORTED: Interdiction field preventing dock sequence!", "NAVIGATION", SHIP_NOTIFY_WARNING, 'voidcrew/sound/warn.ogg', 25)
		return "Cannot dock while interdicted!"

	refresh_engines()

	// Clear thrust when docking, and the commanded course with it - a berth is
	// where every course ends
	burn_direction = BURN_NONE
	commanded_course = BURN_NONE
	thrust_processing = FALSE
	update_ship_processing()

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
		// Messaging only - the request below is issued either way, and the stall
		// watchdog still owns recovery. See explain_dock_refusal().
		var/refused = explain_dock_refusal(dock_to_use)
		shuttle.request(dock_to_use)
		shuttle.setTimer(1 SECONDS)
		addtimer(CALLBACK(src, PROC_REF(complete_dock), WEAKREF(to_dock)), 1 SECONDS)
		// On a refusal the fault broadcast has already said everything; don't follow it
		// with a contradictory "Commencing docking..." echo
		return refused ? null : "Commencing docking..."

	// Start dock warmup. Return nothing: ship_notify() has already told the whole crew,
	// including whoever pressed the button, and callers echo a returned string straight
	// back to that person - returning the same line printed it twice, once bold from the
	// broadcast and once plain from the echo. Only refusals get a return value now.
	ship_notify("Initiating docking sequence. Docking in [DOCK_WARMUP_TIME / 10] seconds.", "DOCKING", SHIP_NOTIFY_NOTICE, 'voidcrew/sound/notify.ogg', 50)
	dock_warmup_timer = addtimer(CALLBACK(src, PROC_REF(complete_dock_warmup), dock_to_use, WEAKREF(to_dock)), DOCK_WARMUP_TIME, TIMER_STOPPABLE)
	return null

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
		ship_notify("Docking aborted: destination no longer available.", "DOCKING", SHIP_NOTIFY_WARNING, 'voidcrew/sound/warn.ogg', 25)
		return

	var/obj/structure/overmap/dynamic/player_outpost/home = astype(to_dock)
	if(home)
		var/denial = home.get_docking_denial(src)
		if(denial)
			home.on_ship_undock_complete(src)
			state = OVERMAP_SHIP_FLYING
			docked = null
			ship_notify(denial, "DOCKING", SHIP_NOTIFY_WARNING)
			return
	SEND_SIGNAL(src, COMSIG_VOIDCREW_SHIP_ABOUT_TO_DOCK)
	// Messaging only - the request is issued either way and the stall watchdog still
	// owns recovery. On a refusal, skip the "Docking now." line so the crew isn't told
	// a move is happening right after being told why it can't.
	var/refused = explain_dock_refusal(dock_to_use)
	shuttle.request(dock_to_use)
	if(!refused)
		ship_notify("Docking now.", "DOCKING", SHIP_NOTIFY_NOTICE, 'voidcrew/sound/notify.ogg', 50)
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
	ship_notify("Destination loaded. Docking in [DOCK_WARMUP_TIME / 10] seconds.", "DOCKING", SHIP_NOTIFY_NOTICE, 'voidcrew/sound/notify.ogg', 50)
	dock_warmup_timer = addtimer(CALLBACK(src, PROC_REF(complete_dock_warmup), dock_to_use, WEAKREF(source)), DOCK_WARMUP_TIME, TIMER_STOPPABLE)

/**
 * Requests generation of an ungenerated site's interior WITHOUT holding the helm:
 * the ship stays fully controllable, progress is broadcast crew-wide, and the
 * docking approach resumes on its own when the site charts.
 *
 * Called from the ship_act() of planets, space ruins and meteor fields when their
 * interior isn't generated yet. Completion (success or failure) arrives via
 * COMSIG_VOIDCREW_SITE_LOAD_FINISHED; while queued, progress comes from
 * worldgen_claim()'s notify_ship routing.
 *
 * * site - the overmap object that needs its interior generated.
 * * user - the mob that pressed Dock, if any; kept by weakref for the resume.
 */
/obj/structure/overmap/ship/proc/request_site_load(obj/structure/overmap/site, mob/user)
	// A second destination while one is already queued supersedes the first rather
	// than stacking: only the newest approach gets to auto-resume.
	var/obj/structure/overmap/old_site = awaiting_load_site?.resolve()
	if(old_site == site)
		awaiting_load_user = WEAKREF(user)
		ship_notify("Survey of [site.get_site_label()] is already underway - the approach resumes on its own when it charts.", "SURVEY", SHIP_NOTIFY_NOTICE, 'voidcrew/sound/notify.ogg', 50)
		return
	if(old_site)
		UnregisterSignal(old_site, list(COMSIG_VOIDCREW_SITE_LOAD_FINISHED, COMSIG_QDELETING))
		ship_notify("Survey request for [old_site.get_site_label()] superseded by a new approach.", "SURVEY", SHIP_NOTIFY_NOTICE)

	awaiting_load_site = WEAKREF(site)
	awaiting_load_user = WEAKREF(user)
	RegisterSignal(site, COMSIG_VOIDCREW_SITE_LOAD_FINISHED, PROC_REF(on_site_load_finished))
	RegisterSignal(site, COMSIG_QDELETING, PROC_REF(on_site_load_qdeleting))

	// The site may have finished loading between the helm's check and now - never
	// sit waiting for a signal that already fired.
	if(site.is_loaded())
		UnregisterSignal(site, list(COMSIG_VOIDCREW_SITE_LOAD_FINISHED, COMSIG_QDELETING))
		awaiting_load_site = null
		awaiting_load_user = null
		INVOKE_ASYNC(site, TYPE_PROC_REF(/obj/structure/overmap, ship_act), user, src)
		return

	var/queue_depth = SSovermap.worldgen_queue_length() + (SSovermap.worldgen_owner ? 1 : 0)
	var/queue_status = queue_depth ? "[queue_depth] survey operation[queue_depth == 1 ? "" : "s"] ahead of us." : "The survey starts immediately."
	ship_notify("Survey request logged for [site.get_site_label()]. [queue_status] Helm remains free - we will broadcast when the site is charted.", "SURVEY", SHIP_NOTIFY_NOTICE, 'voidcrew/sound/notify.ogg', 50)

	if(site.is_loading())
		// Another crew (or our own earlier press) already started this one; its
		// load sends the same completion signal we just registered for.
		ship_notify("A survey of this site is already underway - the approach resumes on its own when it charts.", "SURVEY", SHIP_NOTIFY_NOTICE)
	else
		site.start_level_load(user, src)

/**
 * Signal handler - a site we were waiting on finished (or failed) its generation.
 * Resumes the docking approach if the ship is still in a position to take it:
 * flying, stationary, on the site's tile, and not interdicted. Anything else gets
 * a "dock when ready" broadcast instead - the ship may have moved on deliberately.
 */
/obj/structure/overmap/ship/proc/on_site_load_finished(obj/structure/overmap/site, success)
	SIGNAL_HANDLER
	UnregisterSignal(site, list(COMSIG_VOIDCREW_SITE_LOAD_FINISHED, COMSIG_QDELETING))
	awaiting_load_site = null
	var/mob/user = awaiting_load_user?.resolve()
	awaiting_load_user = null

	if(QDELETED(site))
		return
	if(!success)
		ship_notify("Survey of [site.get_site_label()] could not be completed right now - sector traffic is too heavy. Helm remains free; try docking again shortly.", "SURVEY", SHIP_NOTIFY_WARNING, 'voidcrew/sound/warn.ogg', 25)
		return

	if(state == OVERMAP_SHIP_FLYING && is_still() && site.x == x && site.y == y && !is_interdicted && site.is_loaded())
		ship_notify("Chart complete: [site.get_site_label()]. Resuming docking approach.", "SURVEY", SHIP_NOTIFY_NOTICE, 'voidcrew/sound/notify.ogg', 50)
		INVOKE_ASYNC(site, TYPE_PROC_REF(/obj/structure/overmap, ship_act), user, src)
	else
		ship_notify("Chart complete: [site.get_site_label()]. It will hold position - dock when ready.", "SURVEY", SHIP_NOTIFY_NOTICE, 'voidcrew/sound/notify.ogg', 50)

/**
 * Signal handler - the site we were waiting on was deleted mid-survey.
 */
/obj/structure/overmap/ship/proc/on_site_load_qdeleting(obj/structure/overmap/site)
	SIGNAL_HANDLER
	UnregisterSignal(site, list(COMSIG_VOIDCREW_SITE_LOAD_FINISHED, COMSIG_QDELETING))
	awaiting_load_site = null
	awaiting_load_user = null
	ship_notify("Survey target lost from the chart. Approach cancelled.", "SURVEY", SHIP_NOTIFY_WARNING, 'voidcrew/sound/warn.ogg', 25)

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
	// Check post-failure lockout. Deliberately not cleared by repairing the hull - see
	// SHIP_INTEGRITY_UNDOCK_LOCKOUT - so this can still refuse a ship reading 100%.
	if(!COOLDOWN_FINISHED(src, integrity_undock_lockout))
		return "Hull failure logged! Structural recertification in progress, [DisplayTimeText(COOLDOWN_TIMELEFT(src, integrity_undock_lockout))] remaining."

	// Hull standing out past the docking port lands inside whatever the ship berths against
	// (hull_port_overhang() in hull_survey.dm has the geometry), so it cannot be allowed to
	// leave in that state.
	//
	// The reckoning is here rather than at the moment the hull grows because a build-time
	// refusal is unsatisfiable: the first tile built past the port already overhangs it, so a
	// crew could never reach the point of having a door out on the new outer face. Building
	// out is legal; leaving with the port still buried is not. This is also the last moment
	// the ship is guaranteed to be sitting still and reachable by its own construction gear.
	//
	// Reseat rather than refuse wherever the hull allows it. By the time there is a door on the
	// outermost plating the crew has done everything that makes the hull legal, and all that is
	// left is bookkeeping they would otherwise have to know to do by hand on the construction
	// console - a console they may well have just built over, or lost. A refusal is kept for the
	// hull with genuinely nowhere to put its port, which is the only case a message can help.
	//
	// Placed after the cooldown checks on purpose: the scan walks every turf of every hull area,
	// and there is no reason to pay for it on an undock that is about to be refused anyway.
	var/list/undock_overhang = hull_port_overhang(shuttle, null)
	if(undock_overhang[1] > 0)
		var/turf/reseat_to = hull_port_reseat_target(shuttle, null)
		if(!reseat_to)
			return "Launch refused: [undock_overhang[1]] metre\s of hull stand out past the docking \
				port, and there is no door on the outermost plating to move it to. Fit an airlock or \
				a firelock on that face - until then this ship would be driven through anything it \
				berths against."
		// Moves the port, drags the berth we are still standing on with it, recalculates the
		// hull's bounds and drops the stale transit reservation - which matters here more than
		// anywhere, since transit is where we are about to go.
		hull_reseat_port(shuttle, reseat_to)
		var/obj/machinery/door/reseated_door = hull_port_door(reseat_to)
		ship_notify("Hull extends past the old docking port. Port reseated to [reseated_door ? "the [reseated_door.name]" : "the outer hull"] \
			at ([reseat_to.x], [reseat_to.y]) - that door is now where other ships berth.", "DOCKING", SHIP_NOTIFY_NOTICE, 'voidcrew/sound/notify.ogg', 50)
		log_shuttle("[shuttle] reseated its docking port to ([reseat_to.x], [reseat_to.y]) on undock, clearing a [undock_overhang[1]] tile overhang.")

	// Start undock warmup. Returns nothing for the same reason dock() does - the
	// broadcast below already reaches everyone, and the helm speaks any returned
	// string, so returning this line said it twice.
	state = OVERMAP_SHIP_UNDOCKING
	ship_notify("Initiating undocking sequence. Undocking in [UNDOCK_WARMUP_TIME / 10] seconds.", "UNDOCKING", SHIP_NOTIFY_NOTICE, 'voidcrew/sound/notify.ogg', 50)
	undock_warmup_timer = addtimer(CALLBACK(src, PROC_REF(complete_undock_warmup)), UNDOCK_WARMUP_TIME, TIMER_STOPPABLE)
	return null

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
	// Kept on the ship as well as in the callback: if the chain below is ever lost, the
	// timer's copy goes with it, and check_manoeuvre_stalled() has no other way to learn
	// which berth to hand back.
	undock_origin = WEAKREF(undock_from)
	addtimer(CALLBACK(src, PROC_REF(complete_dock), undock_origin), 1 SECONDS)
	// Crash state is not cleared here. The integrity latch re-arms itself when the hull is
	// repaired back past its recovery threshold (see on_ship_recovered), and clearing the flag
	// on undock as well used to desync the two: the ship stopped reporting as a wreck while
	// still latched DISABLED, which meant a further hit could never fire on_ship_destroyed again.

/**
  * Sets the ship, shuttle, and shuttle areas to a new name.
  */

/**
  * Called after the shuttle docks, and finishes the transfer to the new location.
  */
/obj/structure/overmap/ship/proc/complete_dock(datum/weakref/to_dock, attempt = 1)
	// Commented out as it was being used by deleting planets during undock
	// var/old_loc = loc
	switch(state)
		if(OVERMAP_SHIP_DOCKING) //so that the shuttle is truly docked first
			// The honest "did the hull actually move?" test, and the exact inverse of the one
			// the UNDOCKING branch below already uses (see shuttle_is_in_transit's docstring).
			// The mode check this replaced could not tell the two ends of the move apart:
			// SHUTTLE_CALL is a voidcrew port's resting state in open flight and SHUTTLE_IDLE
			// is its resting state once berthed, and request() leaves a flying port on
			// SHUTTLE_CALL - so the test passed a second after the request exactly as readily
			// as it did after the arrival, and walked the overmap token onto the site whether
			// or not the hull followed. That is a ship the chart calls docked with its crew
			// still in transit, it made abort_stalled_dock() below unreachable, and it hid a
			// live race: complete_dock() is armed for warmup + 1s while the hull waits for the
			// next SSshuttle fire after setTimer(1 SECONDS), and which lands first is not
			// deterministic.
			//
			// Every dock in this fork starts from flight - the helm only offers docking in
			// OVERMAP_SHIP_FLYING, and both ship-to-ship paths dock two flying hulls into
			// empty space - so "no longer standing on a transit dock" is exactly "arrived".
			if(!shuttle_is_in_transit())
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
				// The counterpart to the "complete_dock UNDOCKING" line further down, whose
				// absence is why a round-4 strand could not be diagnosed from the logs at all:
				// 168 undock lines and not one for docking. The attempt count is the useful
				// part now that a dock can legitimately take more than one.
				log_shuttle("complete_dock DOCKING: [name] docked at [docking_target] after [attempt] attempt\s, hull on [shuttle.get_docked() || "NO DOCK"], mode=[shuttle.mode]")
			else
				// Still standing on the transit dock: SSshuttle has not moved the hull yet, or
				// cannot. check_transit_zone() refuses outright while the global transit budget
				// is spent and initiate_docking() can be refused by a blocked berth or the
				// port's own move lock, in which case check() just retries every 2 seconds.
				// Wait for the hull rather than declaring the dock finished without it - and
				// give up eventually, because "never" is one of the outcomes.
				if(attempt >= DOCK_MOVE_MAX_ATTEMPTS)
					abort_stalled_dock(to_dock?.resolve())
					return
				addtimer(CALLBACK(src, PROC_REF(complete_dock), to_dock, attempt + 1), 1 SECONDS)
				return
		if(OVERMAP_SHIP_UNDOCKING)
			// Get the location we're undocking from (passed via weakref from undock())
			var/obj/structure/overmap/old_docked_location = to_dock?.resolve()
			// The hull leaves under SSshuttle's power, not ours: complete_undock_warmup()
			// only sets the port to SHUTTLE_IGNITING, and it cannot move until
			// check_transit_zone() hands it a transit reservation - which takes at least
			// one SSshuttle fire, retries on a 2 second cadence, and is refused outright
			// while the global transit budget is spent. This branch used to fire one
			// second later regardless and walk the overmap token off the dock anyway,
			// stranding the hull (and its crew) inside the site it had just "left" while
			// the chart showed the ship flying. Confirm the move actually happened.
			// A site that vanished under us (null weakref) still takes the old path -
			// there is nothing left to stay docked to, so leaving is the lesser evil.
			if(!isnull(old_docked_location) && !shuttle_is_in_transit())
				if(attempt >= DOCK_MOVE_MAX_ATTEMPTS)
					abort_stalled_undock(old_docked_location)
					return
				addtimer(CALLBACK(src, PROC_REF(complete_dock), to_dock, attempt + 1), 1 SECONDS)
				return
			if(!isturf(loc))
				if(istype(loc, /obj/structure/overmap/ship)) //Even more hardcoded, even more bad
					var/obj/structure/overmap/ship/S = loc
					adjust_speed(S.speed[1], S.speed[2])
					// Notify the target ship that we undocked from them
					SEND_SIGNAL(S, COMSIG_VOIDCREW_SHIP_UNDOCKED_BY, src)
				var/turf/target_turf = get_turf(loc)
				log_shuttle("complete_dock UNDOCKING: Moving ship [src] from [loc] to turf [target_turf]")
				forceMove(target_turf)
			else
				log_shuttle("complete_dock UNDOCKING: Ship [src] already on turf [loc]")

			// Hand our areas back. complete_dock() used to do this only while we were still
			// inside the host's contents, so an undock that found us already on a turf left
			// the host holding our areas in its shuttle_areas forever. That list decides
			// what the host's shuttle moves carry (area/beforeShuttleMove() grants
			// MOVE_AREA from it) and what refresh_engines() treats as aboard, so stale
			// entries make the host claim our decks in every later move and teardown.
			// Removing areas that were never added is a no-op, so reconcile
			// unconditionally against the host.
			if(istype(old_docked_location, /obj/structure/overmap/ship))
				var/obj/structure/overmap/ship/old_host = old_docked_location
				if(old_host.shuttle && old_host.shuttle != shuttle)
					old_host.shuttle.shuttle_areas -= shuttle.shuttle_areas

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

			// Free the ship's hangar berth (the outpost itself never unloads, it's permanent)
			// (trader outposts and player outposts with a hangar elevator; no-op elsewhere)
			old_docked_location?.on_ship_undock_complete(src)

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

			// Handle landable asteroid field (meteor storm) dock flags and cleanup - unlike
			// space ruins, the event itself never respawns/relocates, only its reservation frees up
			if(istype(old_docked_location, /obj/structure/overmap/event/meteor))
				var/obj/structure/overmap/event/meteor/field_place = old_docked_location
				if(dock_index == 1)
					field_place.first_dock_taken = FALSE
				else if(dock_index == 2)
					field_place.second_dock_taken = FALSE
				dock_index = 0
				// Check if we should unload the field (small delay to ensure ship is fully moved)
				addtimer(CALLBACK(field_place, TYPE_PROC_REF(/obj/structure/overmap/event/meteor, unload_level)), 0.5 SECONDS)

			// Always set state to FLYING when undocking completes
			state = OVERMAP_SHIP_FLYING
			undock_origin = null
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
		else
			// complete_dock() is the only thing that can move a ship out of DOCKING or
			// UNDOCKING, and it is driven by one non-repeating timer per attempt. A callback
			// that lands in any other state is a sequence that ended somewhere it did not
			// announce, and it used to leave nothing behind at all - no log line, no runtime,
			// nothing to tell the strand apart from a dock that simply never started.
			log_shuttle("complete_dock: [name] fired in unexpected state [state] (to_dock=[to_dock?.resolve() || "gone"], attempt=[attempt]) - no action taken")
			stack_trace("complete_dock in state [state]")

	// With area-based mass tracking, no re-registration needed - areas persist through shuttle movement
	update_appearance(UPDATE_ICON_STATE)
	update_screen()

/// Human-readable name for the ship's current overmap state, for consoles that need to
/// explain why they are refusing input.
/obj/structure/overmap/ship/proc/get_state_readout()
	switch(state)
		if(OVERMAP_SHIP_DOCKING)
			return "docking sequence in progress"
		if(OVERMAP_SHIP_UNDOCKING)
			return "undocking sequence in progress"
		if(OVERMAP_SHIP_ACTING)
			return "plotting approach vector"
		if(OVERMAP_SHIP_IDLE)
			return "docked"
	return "underway"

/**
 * TRUE while the hull is physically parked on a transit dock - the state a voidcrew ship
 * is in whenever it is flying the overmap rather than sitting in somebody's berth.
 *
 * This is the honest "did the shuttle actually move?" test. The port's `mode` is not:
 * enterTransit() only warns when its initiate_docking() is refused, so a shuttle can
 * reach SHUTTLE_CALL with an infinite timer - open flight, as far as every mode check
 * goes - while its hull never left the dock it was standing on.
 */
/obj/structure/overmap/ship/proc/shuttle_is_in_transit()
	return istype(shuttle?.get_docked(), /obj/docking_port/stationary/transit)

/**
 * The hull could not leave the site we were undocking from before we ran out of retries.
 * Almost always because the shuttle never got a transit reservation (the global budget
 * is finite; see release_assigned_transit() for how it used to be leaked away).
 *
 * Put the ship back into the state it is physically in - still berthed - instead of
 * walking the overmap token off and leaving the crew inside a site the chart says they
 * left. The berth flags and dock_index were never cleared (that happens further down the
 * undock branch we bailed out of), so the berth is still ours and nothing needs reclaiming.
 */
/obj/structure/overmap/ship/proc/abort_stalled_undock(obj/structure/overmap/old_docked_location)
	var/stuck_mode = shuttle?.mode
	docked = old_docked_location // complete_undock_warmup() cleared this on the way out
	undock_origin = null
	state = OVERMAP_SHIP_IDLE
	// Leave the port in the resting state a docked shuttle sits in, rather than the
	// SHUTTLE_IGNITING it is stuck retrying from - otherwise the next undock's request()
	// lands on a port that thinks a launch is already in progress.
	if(shuttle)
		shuttle.mode = SHUTTLE_IDLE
		shuttle.destination = null
		shuttle.timer = 0
	log_shuttle("[name]: undock from [old_docked_location] ABORTED - shuttle never entered transit after [DOCK_MOVE_MAX_ATTEMPTS] seconds (mode=[stuck_mode], assigned_transit=[shuttle?.assigned_transit || "null"]). Ship restored to docked.")
	message_admins("\[SHUTTLE]: [display_name] failed to undock from [old_docked_location] - no transit space available. Ship left docked. [ADMIN_COORDJMP(shuttle?.loc)]")
	ship_notify(
		"UNDOCK FAILED: Bluespace corridor could not be established. Moorings still attached - try again shortly.",
		"UNDOCKING",
		SHIP_NOTIFY_WARNING,
		'voidcrew/sound/warn.ogg',
		25,
	)
	update_appearance(UPDATE_ICON_STATE)
	update_screen()

/**
 * Hands back whichever of a site's two berths we had claimed.
 *
 * The four dockable overmap types each declare their own first_dock_taken/second_dock_taken
 * rather than inheriting them, so this has to name them individually - update_docked_bools()
 * gets away with a single /obj/structure/overmap/dynamic cast only because DM resolves the
 * var by name at runtime, which quietly runtimes on any type that happens not to have it.
 */
/obj/structure/overmap/ship/proc/release_berth_flags(obj/structure/overmap/site)
	if(!dock_index)
		return
	if(!istype(site, /obj/structure/overmap/dynamic) \
		&& !istype(site, /obj/structure/overmap/planet) \
		&& !istype(site, /obj/structure/overmap/space_ruin) \
		&& !istype(site, /obj/structure/overmap/event/meteor))
		dock_index = 0
		return
	var/obj/structure/overmap/dynamic/berth = site // all four declare the same two vars
	if(dock_index == 1)
		berth.first_dock_taken = FALSE
	else if(dock_index == 2)
		berth.second_dock_taken = FALSE
	dock_index = 0

/**
 * Mirror of abort_stalled_undock() for a dock that never completed: the hull is still
 * flying, so give the berth back and hand the helm its flight controls again rather than
 * pinning `state` at DOCKING, which the console has no branch for at all.
 */
/obj/structure/overmap/ship/proc/abort_stalled_dock(obj/structure/overmap/docking_target)
	release_berth_flags(docking_target || docked)
	docked = null
	state = OVERMAP_SHIP_FLYING
	// Open flight for a voidcrew port is SHUTTLE_CALL with no destination and an infinite
	// timer (see /obj/docking_port/mobile/voidcrew/postregister) - the hull never left its
	// transit dock, so that is exactly where it still is.
	if(shuttle)
		shuttle.mode = SHUTTLE_CALL
		shuttle.destination = null
		shuttle.timer = INFINITY
	log_shuttle("[name]: dock to [docking_target || "unknown"] ABORTED - shuttle never completed its move after [DOCK_MOVE_MAX_ATTEMPTS] seconds (assigned_transit=[shuttle?.assigned_transit || "null"]). Ship restored to flight.")
	message_admins("\[SHUTTLE]: [display_name] failed to dock at [docking_target || "unknown"] - no transit space available. Ship left flying. [ADMIN_COORDJMP(shuttle?.loc)]")
	ship_notify(
		"DOCKING FAILED: Bluespace corridor could not be established. Holding position - try again shortly.",
		"DOCKING",
		SHIP_NOTIFY_WARNING,
		'voidcrew/sound/warn.ogg',
		25,
	)
	update_appearance(UPDATE_ICON_STATE)
	update_screen()

/**
 * Polled once a second by SSovermap for a manoeuvre that has stopped advancing.
 *
 * DOCKING, UNDOCKING and ACTING all grey out every helm ops control and the cargo console's
 * call button, and every exit from them runs on a one-shot timer or a one-shot signal:
 * complete_dock()'s retry chain, complete_dock_warmup(), on_planet_loaded(), and the
 * `acting.state = prev_state` restores at the bottom of each site's ship_act(). A runtime
 * anywhere in those unwinds the proc without arming the next step, and DM says nothing. The
 * ship is then pinned in a dead state for the rest of the round - the only exit today is an
 * admin editing `state` by hand.
 *
 * So this is a poll, not a timer: the failure being covered IS a lost callback, and a recovery
 * that depends on one is covering nothing. It is also driven off the state it observes rather
 * than a deadline stamped at each `state =` assignment, so a new assignment site cannot forget
 * to arm it - the cost is up to a second of lag against a 90 second timeout.
 *
 * Recovery reconciles against the hull's own docking port, which is the only honest source of
 * truth here (`state`, `docked` and `loc` are all bookkeeping that can and did drift from it).
 * Returns TRUE if it acted.
 */
/obj/structure/overmap/ship/proc/check_manoeuvre_stalled()
	if(state != OVERMAP_SHIP_DOCKING && state != OVERMAP_SHIP_UNDOCKING && state != OVERMAP_SHIP_ACTING)
		manoeuvre_watch_state = null
		manoeuvre_watch_since = 0
		return FALSE

	// First sighting, or a state that changed under us: start the clock. Every transition
	// between transitional states is progress by definition.
	if(manoeuvre_watch_state != state)
		manoeuvre_watch_state = state
		manoeuvre_watch_since = world.time
		return FALSE

	// Legal waits that outlast the timeout, held rather than counted. A destination still
	// generating its interior is progress, just slow (dock() parks in DOCKING on
	// COMSIG_VOIDCREW_PLANET_LOADED for exactly as long as that takes)...
	var/obj/structure/overmap/planet/loading_target = docked
	if(istype(loading_target) && loading_target.loading)
		manoeuvre_watch_since = world.time
		return FALSE
	// ...and ACTING with worldgen work active is a legal wait, not a stall. Legacy:
	// ship_act() used to hold ships in ACTING while their survey queued; surveys now
	// run in the background off request_site_load() and the ship never leaves FLYING.
	// This remains as a safety net for anything that still sets ACTING near a build.
	if(state == OVERMAP_SHIP_ACTING && (SSovermap.worldgen_owner || SSovermap.worldgen_queue_length()))
		manoeuvre_watch_since = world.time
		return FALSE

	if(world.time - manoeuvre_watch_since < MANOEUVRE_STALL_TIMEOUT)
		return FALSE

	var/stalled_for = world.time - manoeuvre_watch_since
	// Restart the clock before acting: a recovery can need a second pass (complete_dock()
	// spends up to DOCK_MOVE_MAX_ATTEMPTS before it gives up), and this must not re-fire on
	// every SSovermap fire while that runs.
	manoeuvre_watch_since = world.time

	log_shuttle("[name]: STRANDED in state [state] for [stalled_for / 10]s (loc=[loc], docked=[docked || "null"], \
		hull on [shuttle?.get_docked() || "NO DOCK"], mode=[shuttle?.mode]) - reconciling against the hull")
	message_admins("\[SHUTTLE]: [display_name] was stuck in [get_state_readout()] for [stalled_for / 10]s and is being resynchronised. [ADMIN_COORDJMP(shuttle?.loc)]")

	switch(state)
		if(OVERMAP_SHIP_ACTING)
			// Nothing has moved the hull in ACTING - a site sets it, loads, and hands over to
			// dock(), which sets DOCKING itself. Give the helm back. A site that does get
			// there late simply sets its own state again.
			state = OVERMAP_SHIP_FLYING
			ship_notify("Approach plot timed out - navigation control restored.", "NAVIGATION", SHIP_NOTIFY_WARNING, 'voidcrew/sound/warn.ogg', 25)
			update_appearance(UPDATE_ICON_STATE)
			update_screen()
		if(OVERMAP_SHIP_DOCKING)
			if(shuttle_is_in_transit())
				// The hull never left flight, whatever the chart says.
				abort_stalled_dock(docked)
			else
				// The hull is berthed and only the paperwork is missing. Hand it to the branch
				// that does the paperwork, which now agrees with the hull.
				ship_notify("Docking computer desynchronised from the hull - resynchronising.", "DOCKING", SHIP_NOTIFY_WARNING, 'voidcrew/sound/warn.ogg', 25)
				INVOKE_ASYNC(src, PROC_REF(complete_dock), WEAKREF(docked))
		if(OVERMAP_SHIP_UNDOCKING)
			// complete_dock()'s UNDOCKING branch already tests transit and calls
			// abort_stalled_undock() on its own, so restarting the lost chain with the berth
			// we launched from is the whole recovery.
			INVOKE_ASYNC(src, PROC_REF(complete_dock), undock_origin)
	return TRUE

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

/**
 * Renames the ship, propagating the new name to everything that stores a copy of it:
 * the overmap token, the nav/combat display name, the shuttle docking port, the crew
 * team, the ship bank account, and crew paycheck departments. Everything else
 * (comms tags, hails, sensors, dock listings) reads `name`/`display_name` live.
 *
 * Input is trimmed and validated here so every caller gets the same rules.
 * Returns TRUE on success, FALSE otherwise (bad name, same name, or on cooldown).
 *
 * Arguments:
 * * new_name - The requested name. Trimmed, and rejected if empty/too long/bad characters.
 * * user - The mob performing the rename, for feedback and logging. May be null for code/admin calls.
 * * ignore_cooldown - Skips the cooldown check and does not start a new cooldown (code/admin use).
 */
/obj/structure/overmap/ship/proc/set_ship_name(new_name, mob/user, ignore_cooldown = FALSE)
	if(!new_name)
		return FALSE
	new_name = reject_bad_text(trim(new_name), MAX_NAME_LEN)
	if(!new_name)
		if(user)
			to_chat(user, span_warning("Invalid ship name."))
		return FALSE
	if(new_name == name)
		return FALSE
	if(!ignore_cooldown && !COOLDOWN_FINISHED(src, rename_cooldown))
		if(user)
			to_chat(user, span_warning("The registry was updated too recently. [DisplayTimeText(COOLDOWN_TIMELEFT(src, rename_cooldown))] until this ship can be renamed again."))
		return FALSE

	var/old_name = name
	var/old_team_name = ship_team?.name
	name = new_name
	display_name = new_name
	if(shuttle)
		shuttle.name = new_name
	if(ship_team)
		ship_team.name = new_name
		// Keep crew paychecks pointed at the renamed ship budget
		for(var/datum/mind/crewmate as anything in ship_team.members)
			if(crewmate.assigned_role?.paycheck_department == old_team_name)
				crewmate.assigned_role.paycheck_department = new_name
	if(ship_account)
		SSeconomy.department_accounts -= list("[ship_account.account_holder]" = "[ship_account.account_holder] Budget")
		ship_account.account_holder = new_name
		SSeconomy.department_accounts += list("[new_name]" = "[new_name] Budget")

	if(!ignore_cooldown)
		COOLDOWN_START(src, rename_cooldown, SHIP_RENAME_COOLDOWN)

	// The first custom name is free and quiet; changing an established identity is
	// broadcast galaxy-wide so a rename can't quietly shed a reputation.
	if(renamed_once)
		priority_announce("The vessel formerly registered as [old_name] has been renamed to [new_name].", "Galactic Registry")
	renamed_once = TRUE

	ship_notify("Vessel registry updated: [old_name] is now registered as [new_name].", "SHIP SYSTEMS", SHIP_NOTIFY_NOTICE, 'voidcrew/sound/notify.ogg', 50)
	if(user)
		message_admins("[key_name_admin(user)] renamed vessel '[old_name]' to '[new_name]'")
		log_shuttle("[key_name(user)] renamed ship [old_name] to [new_name]")
	return TRUE

/obj/structure/overmap/ship/proc/adjust_speed(n_x, n_y)
	var/offset = 1
	if(movement_callback_id)
		var/magnitude = MAGNITUDE(speed[1], speed[2])
		if(magnitude > 0)
			var/previous_time = 1 / magnitude
			offset = timeleft(movement_callback_id) / previous_time
		deltimer(movement_callback_id)
		movement_callback_id = null //just in case

	speed[1] += n_x
	speed[2] += n_y

	// Hard ceiling on velocity: the burn loop integrates thrust every 0.2s with no
	// other bound, so light hulls (the pill masses 4 turfs) would otherwise sail to
	// several times max_speed. Scaling both axes by the same positive factor keeps
	// the heading, tick_move() only reads the SIGNs.
	var/new_magnitude = MAGNITUDE(speed[1], speed[2])
	if(new_magnitude > max_speed)
		var/rescale = max_speed / new_magnitude
		speed[1] *= rescale
		speed[2] *= rescale

	update_icon_state()
	update_flight_parallax()

	if(QDELETED(src))
		return

	if(is_still() || movement_callback_id)
		// Coming to a stop is a change the chart has to hear about too, or it keeps
		// gliding the token toward a tile the ship is no longer heading for.
		push_helm_frame()
		return

	var/timer = 1 / MAGNITUDE(speed[1], speed[2]) * offset
	movement_callback_id = addtimer(CALLBACK(src, PROC_REF(tick_move)), timer, TIMER_STOPPABLE)
	// The chart glides over exactly get_move_interval(), which this call has just
	// rewritten. Push it now rather than letting the console wait for the next tile
	// crossing: otherwise a throttle change keeps interpolating at the old rate and
	// the ship visibly snaps forward when it arrives early.
	push_helm_frame()

/**
  * Called by /proc/adjust_speed(), this continually moves the ship according to it's speed
  */
/obj/structure/overmap/ship/proc/tick_move()
	if(is_still() || QDELETED(src))
		deltimer(movement_callback_id)
		movement_callback_id = null
		return

	var/new_x = overmap_wrap_x(x + SIGN(speed[1]))
	var/new_y = overmap_wrap_y(y + SIGN(speed[2]))
	var/turf/newloc = locate(new_x, new_y, z)
	if(autopilot_engaged && !autopilot_can_enter(newloc))
		full_stop()
		autopilot_path = null
		autopilot_steer()
		return

	// The crossing is enforced here, on the step that actually leaves the zone.
	//
	// burn_engines() has its own copy of this check, but it only runs while the
	// engines are lit, and the ordinary way to fly is to burn up to speed and
	// then coast, at which point burn_direction is BURN_NONE, process() stops
	// calling burn_engines() at all, and nothing was left watching where the
	// ship went. Every coasting hull crossed zone lines for free, and the
	// autopilot did it every time: autopilot_steer() deliberately drops the burn
	// once it is up to cruise and pointed the right way, so its normal cruise is
	// exactly the state the old gate couldn't see.
	//
	// start_zone_transition() cuts the velocity and kills the movement timer
	// itself, so there is nothing left to reschedule on this path.
	var/datum/overmap_zone/crossing = zone_crossing(get_turf(src), newloc)
	if(crossing)
		start_zone_transition(newloc, crossing)
		update_screen()
		push_helm_frame()
		return

	if(newloc)
		forceMove(newloc)
		check_hazards()

	reschedule_movement()
	update_screen()
	push_helm_frame()
	// One tile crossed is one steering decision. There is no sub-tile position to
	// steer with in between (see ship_autopilot.dm).
	if(autopilot_engaged)
		autopilot_steer()

/**
  * Deciseconds the ship takes to cross one overmap tile at its current speed, or
  * 0 when it isn't moving. Single source of truth for both the movement timer and
  * the interval the helm chart glides its token over, so the two can't drift.
  */
/obj/structure/overmap/ship/proc/get_move_interval()
	var/current_speed = MAGNITUDE(speed[1], speed[2])
	if(!current_speed)
		return 0

	// Apply speed multiplier as hard cap (for interdiction effects)
	if(speed_multiplier < SHIP_SPEED_MULTIPLIER_DEFAULT)
		current_speed *= speed_multiplier

	return 1 / current_speed

/**
  * Helper proc to reschedule the movement timer
  */
/obj/structure/overmap/ship/proc/reschedule_movement()
	if(movement_callback_id)
		deltimer(movement_callback_id)

	var/timer = get_move_interval()
	if(!timer)
		return

	movement_callback_id = addtimer(CALLBACK(src, PROC_REF(tick_move)), timer, TIMER_STOPPABLE)

/**
 * Keeps the interior space parallax scrolling to match the ship's overmap heading
 * while it flies through transit space.
 *
 * Only acts while the shuttle interior is parked at its transit dock (i.e. the ship
 * is in flight); docked/landed interiors keep upstream behavior (no scroll). The
 * current scroll direction is kept as long as it still describes our motion, which
 * avoids direction flip-flopping during diagonal burns; a fresh direction is picked
 * from the dominant velocity axis otherwise. A still ship (no speed on either axis)
 * gets NONE, which makes set_parallax_movedir() ease the scroll to a stop, no
 * thrust means no drifting stars.
 */
/obj/structure/overmap/ship/proc/update_flight_parallax()
	if(!shuttle)
		return
	if(!istype(shuttle.get_docked(), /obj/docking_port/stationary/transit))
		return

	// Ground truth for what's currently applied. Any shuttle area will do
	var/current_dir = NONE
	for(var/area/shuttle_area as anything in shuttle.shuttle_areas)
		current_dir = shuttle_area.parallax_movedir
		break

	// Keep the current direction while it still matches our motion on that axis
	if(current_dir && !is_still())
		var/current_component = (current_dir & (EAST|WEST)) ? speed[1] : speed[2]
		if((current_dir & (NORTH|EAST)) ? (current_component > 0) : (current_component < 0))
			return

	// No thrust, no drift: a still ship stops the starfield (NONE = upstream ease-out)
	var/new_dir = NONE
	if(speed[1] && abs(speed[1]) >= abs(speed[2]))
		new_dir = speed[1] > 0 ? EAST : WEST
	else if(speed[2])
		new_dir = speed[2] > 0 ? NORTH : SOUTH

	if(new_dir == current_dir)
		return

	for(var/area/shuttle_area as anything in shuttle.shuttle_areas)
		shuttle_area.parallax_movedir = new_dir
	if(shuttle.assigned_transit?.assigned_area)
		shuttle.assigned_transit.assigned_area.parallax_movedir = new_dir

	// Poke every client aboard so their parallax picks up the new direction
	for(var/turf/shuttle_turf as anything in shuttle.return_ordered_turfs(shuttle.x, shuttle.y, shuttle.z, shuttle.dir))
		if(!shuttle_turf || !istype(shuttle_turf.loc, shuttle.area_type))
			continue
		for(var/atom/movable/movable as anything in shuttle_turf)
			if(movable.client_mobs_in_contents)
				movable.update_parallax_contents()

// ===== CONTEXT-AWARE PARALLAX (see _overmap.dm for the system overview) =====

/**
 * The overmap object theming this ship's exterior view right now: whatever we're
 * docked to (following carrier ships to THEIR context), else the first themed
 * object sharing our overmap tile. Null = plain space.
 */
/obj/structure/overmap/ship/proc/get_parallax_source()
	if(docked)
		if(istype(docked, /obj/structure/overmap/ship))
			var/obj/structure/overmap/ship/carrier = docked
			if(carrier == src) // should be impossible, but never recurse into ourselves
				return null
			return carrier.get_parallax_source()
		return docked.parallax_theme ? docked : null
	var/turf/tile = loc
	if(!istype(tile, /turf/open/overmap))
		return null
	for(var/obj/structure/overmap/object in tile)
		if(object == src || !object.parallax_theme)
			continue
		return object
	return null

/// Overmap token moved: record zone crossings and refresh the crew's parallax.
/obj/structure/overmap/ship/Moved(atom/old_loc, movement_dir, forced, list/old_locs, momentum_change = TRUE)
	var/old_zone_type = SSovermap_zones?.get_zone_type(get_turf(old_loc))
	. = ..()
	log_zone_crossing(old_zone_type, SSovermap_zones?.get_zone_type(get_turf(src)))
	update_crew_parallax_context()

/**
 * Re-resolves the ship's parallax context and re-themes every client aboard if it
 * changed. Cheap no-op while the context is stable, so it's safe to call from every
 * token move. Also forwards to ships docked to us, so a carrier flying into a nebula
 * updates its passengers' crews too.
 */
/obj/structure/overmap/ship/proc/update_crew_parallax_context()
	if(!shuttle)
		return
	var/obj/structure/overmap/source = get_parallax_source()
	var/new_key = source ? "[source.parallax_theme]-[REF(source)]" : null
	if(new_key != parallax_context_key)
		parallax_context_key = new_key
		// Same crew-enumeration pattern as update_flight_parallax()
		for(var/turf/shuttle_turf as anything in shuttle.return_ordered_turfs(shuttle.x, shuttle.y, shuttle.z, shuttle.dir))
			if(!shuttle_turf || !istype(shuttle_turf.loc, shuttle.area_type))
				continue
			for(var/atom/movable/movable as anything in shuttle_turf)
				if(!movable.client_mobs_in_contents)
					continue
				for(var/mob/client_mob as anything in movable.client_mobs_in_contents)
					if(client_mob?.hud_used)
						client_mob.hud_used.update_overmap_parallax(client_mob)
	// Ships docked to us live in our contents and see whatever we see
	for(var/obj/structure/overmap/ship/rider in contents)
		rider.update_crew_parallax_context()

// ===== ZONE TRANSITION PROCS =====

/**
  * The zone `target` belongs to, but only when stepping onto it from `origin` is
  * actually a change of zone. Null for a step within one zone, for a tile with no
  * zone, and before SSovermap_zones is up.
  *
  * Shared by the two places a crossing can happen, ordering a burn towards a
  * boundary, and the tile step that carries the ship over one, so the two can't
  * disagree about what counts as leaving a zone.
  */
/obj/structure/overmap/ship/proc/zone_crossing(turf/origin, turf/target)
	if(!SSovermap_zones?.initialized || !origin || !target)
		return null
	var/datum/overmap_zone/from_zone = SSovermap_zones.get_zone(origin)
	var/datum/overmap_zone/to_zone = SSovermap_zones.get_zone(target)
	if(!from_zone || !to_zone || from_zone.zone_type == to_zone.zone_type)
		return null
	return to_zone

/**
  * Starts a zone transition - ship must wait 10 seconds before crossing into a new zone.
  * Engines are cut and ship stops during transition.
  * * target - The turf we're trying to move to
  * * target_zone - The zone datum of the target turf
  */
/obj/structure/overmap/ship/proc/start_zone_transition(turf/target, datum/overmap_zone/target_zone)
	if(zone_transitioning)
		return

	if(autopilot_engaged && !autopilot_can_enter(target))
		full_stop()
		autopilot_path = null
		schedule_autopilot_poll()
		return

	zone_transitioning = TRUE
	zone_transition_target = target
	zone_transition_start_time = world.time

	// Latch the course to re-command on the far side, while the velocity still
	// exists to read. A braking ship asked to stop - honor it. A commanded ship
	// gets its course back; a hand-flown coasting hull resumes the course its
	// velocity was carrying, or it comes out the far side dead in space. The
	// autopilot never uses the latch: its poll re-steers by itself.
	if(burn_direction == BURN_STOP)
		zone_resume_burn = BURN_NONE
	else
		zone_resume_burn = commanded_course || get_heading()
	commanded_course = BURN_NONE

	// Clear thrust when entering zone transition
	burn_direction = BURN_NONE
	thrust_processing = FALSE
	update_ship_processing()

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
	ship_notify("Entering [target_zone.name]. Zone transition in progress - [ZONE_TRANSITION_TIME / 10] seconds.", "ZONE TRANSITION", SHIP_NOTIFY_NOTICE, 'voidcrew/sound/notify.ogg', 50)

	// ...and, if this crew has nothing to meet the far side with, say so while
	// the crossing can still be cancelled (voidcrew/modules/onboarding)
	warn_zone_unprepared(target_zone)

	// Signal that zone transition has started (used by pirate AI to cancel hails)
	SEND_SIGNAL(src, COMSIG_VOIDCREW_SHIP_ZONE_TRANSITION_START, target_zone)

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

	// The weather or allowed zones may have changed during the crossing delay.
	if(autopilot_engaged && !autopilot_can_enter(target))
		zone_resume_burn = BURN_NONE
		full_stop()
		autopilot_path = null
		autopilot_steer()
		return

	// Actually move to the target turf
	if(target && !QDELETED(src))
		forceMove(target)
		check_hazards()
		// Re-command the course the crossing latched, so a hand-flown hull
		// carries on across the boundary the way an autopilot one does.
		// Autopilot ships skip this: autopilot_steer()'s poll picks the course
		// back up itself.
		if(zone_resume_burn != BURN_NONE && !autopilot_engaged && state == OVERMAP_SHIP_FLYING && can_thrust())
			command_course(zone_resume_burn)
			ship_notify("Zone transition complete. Resuming course.", "ZONE TRANSITION", SHIP_NOTIFY_NOTICE, 'voidcrew/sound/notify.ogg', 50)
		else
			ship_notify("Zone transition complete.", "ZONE TRANSITION", SHIP_NOTIFY_NOTICE, 'voidcrew/sound/notify.ogg', 50)
		update_icon_state()
		update_screen()
	zone_resume_burn = BURN_NONE

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
	// The crew pulled out of the crossing; nothing to resume on a far side we
	// are no longer going to
	zone_resume_burn = BURN_NONE

	// Reset icon to stationary
	update_icon_state()

	ship_notify("Zone transition cancelled.", "ZONE TRANSITION", SHIP_NOTIFY_WARNING, 'voidcrew/sound/warn.ogg', 25)

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

		// Restore any stale dock geometry left over from a previous ship-to-ship
		// or cargo-shuttle pairing before computing our placement
		E.reset_free_reserve_docks()

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

		// Someone is still parked in here - typically an NPC hulk the crew boarded,
		// undocked from, and came straight back to. Once a ship docks it leaves the
		// overmap tile for the placeholder's contents, so it stops being a contact and
		// ship_act()'s exit-to-exit handshake is unreachable on the way back in; this
		// button is all the crew has. Berth them against that ship rather than dropping
		// them at the encounter's default port, a map away from the airlock they were
		// just using.
		var/obj/docking_port/stationary/occupied_dock = E.get_occupied_reserve_dock(dock_to_use)
		if(occupied_dock && position_dock_across_from(E, occupied_dock, dock_to_use, shuttle))
			return dock(E, dock_to_use)

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

	// dock() refuses interdicted ships AFTER we've claimed the dock flags below -
	// check up front so an abort can't leave the encounter's docks marked taken forever
	if(!instant && (is_interdicted || other_ship.is_interdicted))
		return "Cannot dock while interdicted!"

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

	// Position docks for exit-to-exit docking. A refusal here means one of the two hulls
	// stands out past its own docking port and would be driven through the other; roll the
	// dock claims back so the caller's fallback to separate reserve berths can take them.
	if(!position_docks_for_direct_docking(E, E.reserve_dock, E.reserve_dock_secondary, shuttle, other_ship.shuttle))
		E.first_dock_taken = FALSE
		E.second_dock_taken = FALSE
		dock_index = 0
		other_ship.dock_index = 0
		return "One of the ships has hull built out past its docking port."

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

	// dock() refuses interdicted ships AFTER we've claimed the dock flags below -
	// check up front so an abort can't leave the encounter's docks marked taken forever
	if(!instant && (is_interdicted || other_ship.is_interdicted))
		return "Cannot dock while interdicted!"

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

	// Restore any stale dock geometry left over from a previous ship-to-ship
	// or cargo-shuttle pairing before computing placement
	E.reset_free_reserve_docks()

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
  * TRUE if `shuttle` can take an exit-to-exit berth without ramming its neighbour.
  *
  * Null shuttles pass: an empty anchor dock is not an obstruction. `context` is logged, not
  * shown to players - the crew-facing explanation belongs on the console that can fix it.
  */
/proc/ship_port_clear_to_berth(obj/docking_port/mobile/shuttle, context)
	if(!shuttle)
		return TRUE
	var/list/overhang = hull_port_overhang(shuttle, null)
	if(overhang[1] <= 0)
		return TRUE
	log_shuttle("[shuttle] refused an exit-to-exit berth ([context]): [overhang[1]] tiles of hull \
		stand out past its docking port. Move the port onto the outermost hull door.")
	return FALSE

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

	// Neither hull may stand out past its own docking port, or it lands inside the other ship.
	// Checked before anything is moved so a refusal leaves both docks where the caller found
	// them and it can fall back to separate reserve berths.
	if(!ship_port_clear_to_berth(shuttle_a, "exit-to-exit with [shuttle_b]"))
		return FALSE
	if(!ship_port_clear_to_berth(shuttle_b, "exit-to-exit with [shuttle_a]"))
		return FALSE

	// Centre of the ENCOUNTER'S OWN FOOTPRINT, not of the z-level. The old world.maxx/2
	// pick predates bounds tracking entirely; on a packed level it lands squarely in the
	// gutter between slots - indestructible cordon, so both hulls would be sealed in - or
	// on a neighbouring encounter's ground. Two maximum-size hulls berthed exit-to-exit
	// span ~112 turfs, which fits inside a MAP_SLOT_SIDE (123) square.
	var/datum/map_footprint/footprint = empty_planet.footprint
	var/turf/center_turf = footprint?.get_center_turf()
	if(!center_turf)
		center_turf = locate(round((zlevel.low_x + zlevel.high_x) / 2), round((zlevel.low_y + zlevel.high_y) / 2), zlevel.z_value)
	if(!center_turf)
		log_shuttle("WARNING: No centre turf for ship-to-ship docking on z[zlevel.z_value]")
		return FALSE

	// Position dock_a at center, let adjust_dock_to_shuttle handle orientation
	dock_a.forceMove(center_turf)
	empty_planet.adjust_dock_to_shuttle(dock_a, shuttle_a)

	// Put dock_b right across from it so the two shuttles end up exit-to-exit
	return position_dock_across_from(empty_planet, dock_a, dock_b, shuttle_b)

/**
  * Places a free stationary dock exit-to-exit against another dock, so a shuttle sent
  * to it ends up with its airlock touching whatever is parked on the anchor.
  *
  * anchor_dock.dir points INTO the ship parked there, so that ship's exit - and the
  * berth we want - is one tile away in REVERSE_DIR. Facing the placed dock the same
  * way puts the two shuttle bodies back to back with their exits meeting in between.
  *
  * Used both when pairing two ships up front and when a ship arrives into an
  * encounter someone else is already sitting in.
  *
  * * empty_planet - The encounter, for its z-level bounds. Optional; skips the fit check.
  * * anchor_dock - The dock to berth against. Never moved: something is parked on it.
  * * dock_to_place - The free dock to reposition.
  * * shuttle_to_place - The mobile port that will dock at dock_to_place.
  *
  * Returns TRUE if the dock was placed, FALSE (leaving it untouched) if the berth
  * would fall outside the encounter.
  */
/obj/structure/overmap/ship/proc/position_dock_across_from(obj/structure/overmap/planet/empty/empty_planet, obj/docking_port/stationary/anchor_dock, obj/docking_port/stationary/dock_to_place, obj/docking_port/mobile/shuttle_to_place)
	if(!anchor_dock || !dock_to_place || !shuttle_to_place)
		return FALSE

	// Exit-to-exit only leaves one tile between the two hulls, so neither ship may have
	// plating standing out past its own docking port - that plating lands inside the other
	// ship and overwrites it (hull_port_overhang() in hull_survey.dm has the full reasoning).
	// canDock() cannot see this, because the dwidth/dheight we set below are derived from the
	// mobile port's own, so its bounds test compares a number with itself.
	if(!ship_port_clear_to_berth(shuttle_to_place, "berthing beside [anchor_dock]"))
		return FALSE
	if(!ship_port_clear_to_berth(anchor_dock.get_docked(), "parked on [anchor_dock]"))
		return FALSE

	var/new_dir = REVERSE_DIR(anchor_dock.dir)
	var/new_x = anchor_dock.x
	var/new_y = anchor_dock.y
	switch(new_dir)
		if(NORTH)
			new_y = anchor_dock.y + 1
		if(SOUTH)
			new_y = anchor_dock.y - 1
		if(EAST)
			new_x = anchor_dock.x + 1
		if(WEST)
			new_x = anchor_dock.x - 1

	var/turf/new_loc = locate(new_x, new_y, anchor_dock.z)
	if(!new_loc)
		log_shuttle("WARNING: Could not position [dock_to_place] at ([new_x], [new_y], [anchor_dock.z]) for ship-to-ship docking")
		return FALSE

	// Square footprint: the dock gets rotated to face the anchor rather than sized along
	// a fixed axis, so its long side has to clear the shuttle whichever way it lands
	var/new_size = max(shuttle_to_place.width, shuttle_to_place.height)

	// return_coords() reads the port's own footprint, so these have to be in place before
	// we can ask where the berth would actually land. Snapshot them: a berth that turns
	// out not to fit leaves the dock exactly as we found it for the caller's fallback.
	var/old_width = dock_to_place.width
	var/old_height = dock_to_place.height
	var/old_dwidth = dock_to_place.dwidth
	var/old_dheight = dock_to_place.dheight

	dock_to_place.width = new_size
	dock_to_place.height = new_size
	dock_to_place.dwidth = round((new_size - shuttle_to_place.width) / 2) + shuttle_to_place.dwidth
	dock_to_place.dheight = round((new_size - shuttle_to_place.height) / 2) + shuttle_to_place.dheight

	var/datum/space_level/zlevel
	if(empty_planet?.mapzone && length(empty_planet.mapzone.z_levels))
		zlevel = empty_planet.mapzone.z_levels[1]
	// The ENCOUNTER's rectangle, not the level's. Flat encounters pack four to a z-level, and
	// the level's rect widens to the whole z as soon as a second one lands - which turns this
	// fit test from "does the berth stay on our ground" into "is it anywhere on the map", and
	// lets a berth be laid into the cordon gutter or straight onto a neighbour's encounter.
	var/datum/map_footprint/site = empty_planet?.footprint
	var/site_low_x = isnull(site?.low_x) ? zlevel?.low_x : site.low_x
	var/site_low_y = isnull(site?.low_x) ? zlevel?.low_y : site.low_y
	var/site_high_x = isnull(site?.low_x) ? zlevel?.high_x : site.high_x
	var/site_high_y = isnull(site?.low_x) ? zlevel?.high_y : site.high_y
	if(zlevel && !isnull(site_low_x))
		var/list/corners = dock_to_place.return_coords(new_x, new_y, new_dir)
		if(min(corners[1], corners[3]) < site_low_x || max(corners[1], corners[3]) > site_high_x \
			|| min(corners[2], corners[4]) < site_low_y || max(corners[2], corners[4]) > site_high_y)
			dock_to_place.width = old_width
			dock_to_place.height = old_height
			dock_to_place.dwidth = old_dwidth
			dock_to_place.dheight = old_dheight
			log_shuttle("WARNING: berth for [shuttle_to_place] beside [anchor_dock] falls outside the encounter, using the default port instead")
			return FALSE

	dock_to_place.dir = new_dir
	dock_to_place.forceMove(new_loc)
	return TRUE

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

	// If the acting ship has an interdictor locked onto the target, force dock instead
	for(var/obj/machinery/ship_combat/interdictor/interdictor in acting_ship.linked_interdictors)
		if(interdictor.interdiction_active && interdictor.interdicted_ship_ref?.resolve() == src)
			interdictor.force_dock_target(user)
			return

	// If target ship is a disabled NPC ship, allow direct docking without mutual request.
	// An abandoned hull docks the same way and for the same reason: the handshake below
	// needs a helm with someone at it, an abandoned hull has no crew left to answer, and
	// the claim console inside (claim_abandoned_ship()) is only reachable by boarding it.
	// Without this the whole SHIP_DERELICT_DESPAWN_TIME claim window was unreachable by
	// any ordinary means - only an interdictor lock could put a boarding party aboard.
	var/obj/structure/overmap/ship/npc/npc_target = src
	var/target_disabled = istype(npc_target) && npc_target.is_disabled
	if(target_disabled || abandoned)
		// Clear any pending dock requests
		clear_pending_dock()
		acting_ship.clear_pending_dock()

		// The derelict cannot answer, so tell the boarders what is happening instead.
		// Not for the disabled-NPC case, which has always been silent here.
		if(!target_disabled)
			acting_ship.ship_notify("[name] is not responding - registered as an abandoned derelict. Docking directly.", "DOCKING", SHIP_NOTIFY_NOTICE, 'voidcrew/sound/notify.ogg', 50)

		// Dock directly - no mutual request needed for disabled ships
		var/result = dock_ships_directly(acting_ship, user)
		if(result)
			// Direct docking failed, fall back to reserve port docking
			var/fallback_result = dock_ships_to_reserve_ports(acting_ship, user)
			if(fallback_result)
				to_chat(user, "<span class='warning'>Docking failed: [fallback_result]</span>")
		return

	// Check if acting_ship is clicking on a ship it already requested to dock with
	// If so, cancel the request
	if(acting_ship.pending_dock && acting_ship.pending_dock_target == src)
		acting_ship.clear_pending_dock()
		acting_ship.ship_notify("Docking request to [name] has been cancelled.", "DOCKING", SHIP_NOTIFY_NOTICE, 'voidcrew/sound/notify2.ogg', 50)
		ship_notify("[acting_ship.name] has cancelled their docking request.", "DOCKING", SHIP_NOTIFY_NOTICE, 'voidcrew/sound/notify2.ogg', 50)
		return

	// Check if the target (src) already sent a request to acting_ship
	// If src.pending_dock is TRUE and target is acting_ship, complete the handshake
	if(pending_dock && pending_dock_target == acting_ship)
		ship_notify("Initiating docking procedures with [acting_ship.name]...", "DOCKING", SHIP_NOTIFY_NOTICE, 'voidcrew/sound/notify.ogg', 50)
		acting_ship.ship_notify("Initiating docking procedures with [name]...", "DOCKING", SHIP_NOTIFY_NOTICE, 'voidcrew/sound/notify.ogg', 50)

		// Clear pending status and timers for both ships
		clear_pending_dock()
		acting_ship.clear_pending_dock()

		// Dock both ships directly exit-to-exit
		var/result = dock_ships_directly(acting_ship, user)
		if(result)
			// Direct docking failed, fall back to reserve port docking
			ship_notify("Direct docking failed, using reserve ports instead.", "DOCKING", SHIP_NOTIFY_NOTICE, 'voidcrew/sound/notify2.ogg', 50)
			acting_ship.ship_notify("Direct docking failed, using reserve ports instead.", "DOCKING", SHIP_NOTIFY_NOTICE, 'voidcrew/sound/notify2.ogg', 50)
			var/fallback_result = dock_ships_to_reserve_ports(acting_ship, user)
			if(fallback_result)
				to_chat(user, "<span class='warning'>Docking failed: [fallback_result]</span>")
				ship_notify("Docking failed: [fallback_result]", "DOCKING", SHIP_NOTIFY_WARNING, 'voidcrew/sound/warn.ogg', 25)
				acting_ship.ship_notify("Docking failed: [fallback_result]", "DOCKING", SHIP_NOTIFY_WARNING, 'voidcrew/sound/warn.ogg', 25)
	else
		// If acting_ship already has a pending request to a DIFFERENT ship, cancel it first
		if(acting_ship.pending_dock && acting_ship.pending_dock_target != src)
			var/obj/structure/overmap/ship/old_target = acting_ship.pending_dock_target
			acting_ship.clear_pending_dock()
			acting_ship.ship_notify("Docking request to [old_target?.name] has been cancelled.", "DOCKING", SHIP_NOTIFY_NOTICE, 'voidcrew/sound/notify2.ogg', 50)
			if(old_target)
				old_target.ship_notify("[acting_ship.name] has cancelled their docking request.", "DOCKING", SHIP_NOTIFY_NOTICE, 'voidcrew/sound/notify2.ogg', 50)

		// New request - acting_ship wants to dock with src (target)
		log_admin("[key_name(user)] requested ship-to-ship docking from [acting_ship.name] to [name]")
		// Announce to the acting ship (the one making the request)
		acting_ship.ship_notify("Your ship has requested to dock with [name]. They must also request docking to proceed.", "DOCKING", SHIP_NOTIFY_NOTICE, 'voidcrew/sound/notify.ogg', 50)
		// Announce to the target ship (src) that they have an incoming request
		ship_notify("[acting_ship.name] has requested to dock with your ship. Use your helm console to accept.", "DOCKING", SHIP_NOTIFY_NOTICE, 'voidcrew/sound/notify.ogg', 50)
		// Set pending on acting_ship - this marks that acting_ship is waiting for src to respond
		acting_ship.pending_dock = TRUE
		acting_ship.pending_dock_target = src

		// Set a 30 second timer to clear the pending dock request on acting_ship
		acting_ship.pending_dock_timer = addtimer(CALLBACK(acting_ship, PROC_REF(clear_pending_dock)), 30 SECONDS, TIMER_STOPPABLE)
		acting_ship.ship_notify("Docking request will expire in 30 seconds.", "DOCKING", SHIP_NOTIFY_NOTICE, 'voidcrew/sound/notify2.ogg', 50)
/**
 * Calculates the mass based on the amount of turfs in the shuttle's areas
 * Ship health is based on current turfs vs original turfs
 * Losing turfs = losing health, rebuilding = healing
 *
 * NOTE: This is now only called ONCE during ship initialization to establish baseline.
 * After that, mass is tracked via event-driven delta updates (see setup_mass_tracking).
 * Do NOT call this in a loop - the per-turf signal handlers keep mass current, and
 * apply_mass_delta() feeds the threshold latch.
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

	// First calculation - the hull as built is the baseline, and it starts at full health.
	if(!integrity_initialized)
		mass = .
		max_integrity = mass
		integrity = mass
		integrity_initialized = TRUE
		update_icon_state()
	else
		// A resync rather than a first read: route the difference through the same rule the
		// per-turf handlers use, so a recount can never move the baseline in a direction the
		// incremental path would not have.
		apply_mass_delta(. - mass)

	// Set up event-driven mass tracking after first calculation
	if(integrity_initialized && !mass_tracking_initialized)
		setup_mass_tracking()

/**
 * Returns the mass weight contribution for a turf type
 * Used by delta tracking to update mass without full iteration
 */
/proc/get_turf_mass_weight(turf_type)
	if(ispath(turf_type, /turf/open/space))
		return 0
	if(ispath(turf_type, /turf/closed/wall/r_wall))
		return 3
	if(ispath(turf_type, /turf/closed/wall))
		return 2
	// Non-space turfs (floors, etc)
	if(ispath(turf_type, /turf/open) || ispath(turf_type, /turf/closed))
		return 1
	return 0

/**
 * Returns the mass weight for an actual turf instance
 * Checks if it's a valid shuttle turf before returning weight
 */
/proc/get_turf_mass_weight_instance(turf/T)
	if(!T)
		return 0
	if(isspaceturf(T))
		return 0
	if(!isshuttleturf(T))
		return 0
	if(istype(T, /turf/closed/wall/r_wall))
		return 3
	if(istype(T, /turf/closed/wall))
		return 2
	return 1

/obj/structure/overmap/ship
	/// Whether mass tracking signals have been set up
	var/mass_tracking_initialized = FALSE

/**
 * Sets up event-driven mass tracking by registering signals on shuttle AREAS
 * Areas persist through shuttle movement, so we only register once - no re-registration needed on dock/undock
 * Called once after the initial calculate_mass() establishes the baseline
 */
/obj/structure/overmap/ship/proc/setup_mass_tracking()
	if(mass_tracking_initialized)
		return
	if(!shuttle?.shuttle_areas)
		return

	mass_tracking_initialized = TRUE

	// Register on shuttle areas - these persist through shuttle movement
	for(var/area/shuttle_area as anything in shuttle.shuttle_areas)
		track_hull_area(shuttle_area)

/// New compartments need the same damage tracking as the ship's original areas.
/obj/structure/overmap/ship/proc/track_hull_area(area/shuttle_area)
	RegisterSignal(shuttle_area, COMSIG_AREA_TURF_ADDED, PROC_REF(on_area_turf_added), override = TRUE)
	RegisterSignal(shuttle_area, COMSIG_AREA_TURF_REMOVED, PROC_REF(on_area_turf_removed), override = TRUE)
	for(var/turf/tile in shuttle_area)
		RegisterSignal(tile, COMSIG_TURF_CHANGE, PROC_REF(on_shuttle_turf_change), override = TRUE)

/**
 * Signal handler for when a turf joins a shuttle area
 * Handles: shuttle movement arrival, new construction, shuttle expansion
 */
/obj/structure/overmap/ship/proc/on_area_turf_added(area/source, turf/T, area/old_area)
	SIGNAL_HANDLER

	var/obj/machinery/computer/camera_advanced/base_construction/ship/repair_controller = shuttle?.ship_repair_controller?.resolve()
	if(repair_controller?.repair_tracking && !(source in repair_controller.repair_areas))
		repair_controller.refresh_repair_areas()

	if(!integrity_initialized)
		return

	// Register for in-place type changes on this turf (including space turfs for future repairs)
	RegisterSignal(T, COMSIG_TURF_CHANGE, PROC_REF(on_shuttle_turf_change), override = TRUE)
	// Reassigning a room within this hull neither adds mass nor repairs damage.
	if(shuttle?.shuttle_areas[old_area])
		return

	// Space turfs don't contribute mass, but we still registered for future changes above
	if(isspaceturf(T))
		return

	apply_mass_delta(get_turf_mass_weight_instance(T))

/**
 * Signal handler for when a turf leaves a shuttle area
 * Handles: shuttle movement departure, turf destruction, area changes
 */
/obj/structure/overmap/ship/proc/on_area_turf_removed(area/source, turf/T, area/new_area)
	SIGNAL_HANDLER

	if(!integrity_initialized)
		return
	// Keep the turf's damage tracking when only its compartment changes.
	if(shuttle?.shuttle_areas[new_area])
		return

	// Unregister turf change signal (we register on all turfs including space)
	UnregisterSignal(T, COMSIG_TURF_CHANGE)

	// Space turfs don't contribute mass
	if(isspaceturf(T))
		return

	apply_mass_delta(-get_turf_mass_weight_instance(T))

/**
 * Signal handler for when a shuttle turf changes type in-place
 * Handles: wall -> floor, floor -> space, etc. (without changing area)
 */
/obj/structure/overmap/ship/proc/on_shuttle_turf_change(turf/old_turf, path, list/new_baseturfs, flags, list/post_change_callbacks)
	SIGNAL_HANDLER

	var/obj/machinery/computer/camera_advanced/base_construction/ship/repair_controller = shuttle?.ship_repair_controller?.resolve()
	repair_controller?.on_repair_turf_change(old_turf, path)

	if(!integrity_initialized)
		return

	// Calculate the delta between old and new turf types
	apply_mass_delta(get_turf_mass_weight(path) - get_turf_mass_weight_instance(old_turf))

/**
 * TRUE while mass the hull *loses* should be treated as the crew remodelling rather than as
 * damage, and so should take the baseline down with it.
 *
 * The discriminator is simply whether the ship is parked. A docked, stationary hull is a
 * drydock: cutting a wall out, pulling a module, opening a room up - all of that is the crew
 * choosing to have less ship, and none of it is an injury. Under way, mass only leaves a hull
 * because something took it.
 *
 * Getting this wrong in the lenient direction is what made ordinary construction read as
 * battle damage. max_integrity used to be a pure high-water mark, so building a wall raised
 * the baseline and then removing that same wall did not lower it again: every build-and-undo
 * cycle cost the ship a permanent notch of health, and pulling a fitted ship module - which
 * can be forty-odd mass - dropped a Goon far enough in one action to trip the crash alarm
 * while it sat safely in a berth.
 */
/obj/structure/overmap/ship/proc/hull_baseline_follows_losses()
	return state == OVERMAP_SHIP_IDLE

/**
 * How much mass this hull may lose before it is disabled.
 *
 * Fraction of the baseline for anything of a normal size, with an absolute floor underneath
 * for hulls small enough that a percentage stops being a meaningful quantity of ship.
 */
/obj/structure/overmap/ship/proc/integrity_damage_allowance()
	return max(SHIP_INTEGRITY_MIN_ALLOWANCE, max_integrity * SHIP_INTEGRITY_ALLOWANCE_FRACTION)

/// Mass at or below which the hull is disabled.
/obj/structure/overmap/ship/proc/integrity_disabled_threshold()
	return max_integrity - integrity_damage_allowance()

/// Mass the hull must be repaired back to before an alarm clears.
/obj/structure/overmap/ship/proc/integrity_recovery_threshold()
	return max_integrity - (integrity_damage_allowance() * SHIP_INTEGRITY_RECOVERY_FRACTION)

/**
 * The one place mass is allowed to move.
 *
 * Every caller - the three turf signal handlers and the full recount - funnels through here so
 * the baseline rule is applied per change rather than per evaluation. That distinction matters
 * during a shuttle move, which removes and re-adds several hundred turfs one at a time: the
 * baseline has to see each -w followed by its +w to stay put, where a rule applied to the
 * accumulated total would sample the hull mid-swing.
 */
/obj/structure/overmap/ship/proc/apply_mass_delta(delta)
	if(!delta)
		return
	mass += delta

	if(!integrity_initialized)
		return

	if(delta > 0)
		// Repairs close the gap to the existing baseline without moving it; only mass beyond
		// the baseline is new hull, and only that raises it.
		max_integrity = max(max_integrity, mass)
	else if(hull_baseline_follows_losses())
		// Deliberate deconstruction. The baseline drops by exactly what was removed, so the
		// hull's damage deficit is carried across the change untouched - a ship that docked
		// with a hole in it still has that hole afterwards, and one that docked sound stays
		// sound no matter how much of itself the crew cuts away.
		max_integrity = max(0, max_integrity + delta)

	queue_integrity_eval()

/**
 * Schedules a threshold evaluation for the end of the tick.
 *
 * Bulk turf work - a shuttle move, an explosion, a map module loading - lands hundreds of
 * mass changes in a single tick. Evaluating each one meant hundreds of COMSIG_SHIP_INTEGRITY_CHANGED
 * signals and, through the helm's handler, hundreds of SStgui.update_uis() calls per dock cycle.
 * Coalescing to one evaluation also means transient mid-operation states are never seen.
 */
/obj/structure/overmap/ship/proc/queue_integrity_eval()
	if(!integrity_initialized || integrity_eval_queued)
		return
	integrity_eval_queued = TRUE
	addtimer(CALLBACK(src, PROC_REF(evaluate_integrity)), 0)

/**
 * Publishes the current integrity and advances the alarm latch.
 *
 * The latch is the whole point: thresholds are compared against the state the ship is
 * already in, so each band is entered once and announced once. The old code re-derived the
 * answer from the last two mass values, which meant a hull hovering near a boundary - exactly
 * where a crew doing repairs spends its time - re-announced on every tile that crossed it.
 */
/obj/structure/overmap/ship/proc/evaluate_integrity()
	integrity_eval_queued = FALSE
	if(QDELETED(src) || !integrity_initialized)
		return

	var/old_integrity = integrity
	integrity = mass

	if(max_integrity > 0 && integrity != old_integrity)
		SEND_SIGNAL(src, COMSIG_SHIP_INTEGRITY_CHANGED, integrity, max_integrity, get_integrity_percent())

	if(max_integrity > 0)
		var/disabled_at = integrity_disabled_threshold()
		var/recovered_at = integrity_recovery_threshold()
		var/critical_at = max_integrity - (integrity_damage_allowance() * SHIP_INTEGRITY_CRITICAL_FRACTION)

		switch(integrity_state)
			if(SHIP_INTEGRITY_NOMINAL)
				if(integrity <= disabled_at)
					enter_integrity_failure()
				else if(integrity <= critical_at)
					integrity_state = SHIP_INTEGRITY_CRITICAL
					start_critical_alert()
			if(SHIP_INTEGRITY_CRITICAL)
				if(integrity <= disabled_at)
					enter_integrity_failure()
				else if(integrity >= recovered_at)
					integrity_state = SHIP_INTEGRITY_NOMINAL
					stop_critical_alert()
			if(SHIP_INTEGRITY_DISABLED)
				if(integrity >= recovered_at)
					integrity_state = SHIP_INTEGRITY_NOMINAL
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
	if(!shuttle)
		avg_fuel_amnt = 0
		return
	var/fuel_avg = 0
	var/engine_amnt = 0
	for(var/obj/machinery/power/shuttle_engine/ship/E in shuttle.engine_list)
		if(!E.enabled || E.thruster_active == 0)
			continue
		var/fuel_cap = E.return_fuel_cap()
		if(!fuel_cap) //no (or zero) capacity reported - can't divide by it
			continue
		fuel_avg += clamp(E.return_fuel() / fuel_cap, 0, 1)
		engine_amnt++
	if(!engine_amnt || !fuel_avg)
		avg_fuel_amnt = 0
		return
	avg_fuel_amnt = round(fuel_avg / engine_amnt * 100)

///Returns TRUE if the ship has at least one working engine with fuel available.
/obj/structure/overmap/ship/proc/can_thrust()
	if(!shuttle)
		return FALSE
	// Can't thrust while hidden in a nebula
	if(hidden_in_nebula)
		return FALSE
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

/**
 * Kills all velocity in one call, rather than shedding it a tick at a time.
 *
 * The same thing `decelerate(max_speed)` already does at the dock, on undock and
 * on a zone transition, given a name so the autopilot can ask for it directly.
 *
 * Routed through adjust_speed() rather than writing `speed` so the movement timer,
 * the flight parallax and the helm chart all hear about it, the chart in
 * particular keeps gliding its token toward a tile the ship is no longer heading
 * for otherwise.
 */
/obj/structure/overmap/ship/proc/full_stop()
	// Cleared before the early return below: a still ship can be holding a stale
	// course, and "full stop" has to kill the course too or the rose stays lit.
	commanded_course = BURN_NONE
	if(burn_direction != BURN_NONE)
		change_heading(BURN_NONE)
	if(is_still())
		return
	adjust_speed(-speed[1], -speed[2])

/**
 * Zeroes one or both axes of the velocity and leaves the other alone.
 *
 * What a turn actually needs. tick_move() steps by the SIGN of each axis, so
 * changing course is a matter of getting the two signs right rather than of
 * shedding speed, and an axis already carrying the ship the right way should keep
 * every bit of the speed it has instead of being braked along with the bad one.
 */
/obj/structure/overmap/ship/proc/kill_drift(kill_x = FALSE, kill_y = FALSE)
	if(!kill_x && !kill_y)
		return
	adjust_speed(kill_x ? -speed[1] : 0, kill_y ? -speed[2] : 0)

/**
 * Trims the velocity to a magnitude ceiling, keeping its direction.
 *
 * Scaling both axes by the same factor is what preserves the heading: tick_move()
 * reads the SIGNS, and scaling by a positive factor cannot change one.
 */
/obj/structure/overmap/ship/proc/clamp_speed(ceiling)
	var/magnitude = MAGNITUDE(speed[1], speed[2])
	if(!magnitude || magnitude <= ceiling)
		return
	var/scale = ceiling / magnitude
	adjust_speed(speed[1] * (scale - 1), speed[2] * (scale - 1))

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
 * * percentage - Throttle percentage (1-100)
 * * burn_seconds - How many seconds of burn this call represents (fuel costs are per second of full burn)
 */
/obj/structure/overmap/ship/proc/burn_engines(n_dir = null, percentage = 100, burn_seconds = 1)
	if(state != OVERMAP_SHIP_FLYING)
		return

	// Can't thrust while transitioning zones
	if(zone_transitioning)
		return

	SEND_SIGNAL(src, COMSIG_VOIDCREW_SHIP_MOVED)

	// Clear any pending dock requests when moving
	if(pending_dock)
		clear_pending_dock()
		ship_notify("Docking request cancelled due to ship movement.", "DOCKING", SHIP_NOTIFY_WARNING, 'voidcrew/sound/warn.ogg', 25)

	// Decelerate without using fuel
	if(!n_dir)
		decelerate(acceleration_speed * (percentage / 100))
		return

	// Manual burns retain the early crossing shortcut. Autopilot turns can burn
	// just one missing axis: that is not its course, so only tick_move() may
	// choose the crossing tile for an automated ship.
	if(!autopilot_engaged)
		var/target_x = overmap_wrap_x(x + ((n_dir & EAST) ? 1 : 0) - ((n_dir & WEST) ? 1 : 0))
		var/target_y = overmap_wrap_y(y + ((n_dir & NORTH) ? 1 : 0) - ((n_dir & SOUTH) ? 1 : 0))
		var/turf/target_turf = locate(target_x, target_y, z)
		var/datum/overmap_zone/crossing = zone_crossing(get_turf(src), target_turf)
		if(crossing)
			start_zone_transition(target_turf, crossing)
			return

	var/thrust_used = 0 //The amount of thrust that the engines will provide with one burn
	refresh_engines()

	if(!shuttle)
		return

	if(!mass)
		calculate_mass()
	calculate_avg_fuel()

	for(var/obj/machinery/power/shuttle_engine/ship/E in shuttle.engine_list)
		if(!E.enabled || E.thruster_active == 0)
			continue
		thrust_used += E.burn_engine(percentage, mass, burn_seconds)
	est_thrust = thrust_used //cheeky way of rechecking the thrust, check it every time it's used

	// No thrust means no movement - engines need fuel/power to work
	if(thrust_used <= 0)
		warn_no_thrust()
		return

	thrust_used = thrust_used / max(mass * 100, 1) //do not know why this minimum check is here, but I clearly ran into an issue here before

	// Apply speed multiplier (for effects like interdiction)
	thrust_used *= speed_multiplier

	if(n_dir)
		accelerate(n_dir, thrust_used)

/**
 * Rate-limited crew warning for burn attempts that produce nothing (dead power grid,
 * disabled/damaged engines, empty fuel). Without it the failure is silent: an ion
 * engine's helm gauge reads stored SMES charge, but burns draw live wire power, so
 * the display can sit at 100% while the ship refuses to move.
 */
/obj/structure/overmap/ship/proc/warn_no_thrust()
	if(!COOLDOWN_FINISHED(src, no_thrust_warning))
		return
	COOLDOWN_START(src, no_thrust_warning, 15 SECONDS)
	ship_notify("Engines are producing no thrust! Check engine power, fuel, and status.", "ENGINES", SHIP_NOTIFY_WARNING, 'voidcrew/sound/warn.ogg', 25)

/**
 * Changes the burn direction for continuous thrust.
 * Call with a direction to start thrusting, BURN_STOP to actively brake, or BURN_NONE to stop.
 * Uses SSfastprocess (0.2s ticks) for responsive controls.
 * * direction - The direction to burn in, or BURN_STOP/BURN_NONE
 */
/obj/structure/overmap/ship/proc/change_heading(direction)
	burn_direction = direction
	if(burn_direction != BURN_NONE)
		thrust_processing = TRUE
	update_ship_processing()

/// Cruise-speed ceiling the fly-by-wire layer holds, set by the throttle.
/obj/structure/overmap/ship/proc/cruise_target_speed()
	return max_speed * burn_percentage / 100

/**
 * The fly-by-wire entry point every manual control routes through: the pilot
 * commands a COURSE, and the ship works out what the engines owe it.
 *
 * tick_move() reads only the SIGNS of the velocity, so a turn is two different
 * jobs: zero the axis carrying the ship the wrong way, and burn up the axis
 * still missing. Both are done here with the same primitives the autopilot
 * steers with (autopilot_aim_drift()) - deliberate parity rather than a cheat,
 * so a hand-flown hull turns exactly as well as an automated one and no better.
 *
 * The course outlives the burn. Once every commanded axis is moving the right
 * way and the throttle's cruise target is met, the engines go cold and the ship
 * coasts - commanded_course stays set, which is what the helm's compass rose
 * lights from, and check_cruise() is what gets a running burn there.
 *
 * BURN_NONE and BURN_STOP drop the course and pass straight through to
 * change_heading(): coasting and braking are engine states, not courses.
 */
/obj/structure/overmap/ship/proc/command_course(direction)
	if(direction == BURN_NONE || direction == BURN_STOP)
		commanded_course = BURN_NONE
		change_heading(direction)
		push_helm_frame()
		return
	if(state != OVERMAP_SHIP_FLYING || zone_transitioning)
		return

	commanded_course = direction
	// Where the velocity has to point, axis by axis - the same pattern
	// autopilot_steer() uses.
	var/want_x = ((direction & EAST) ? 1 : 0) - ((direction & WEST) ? 1 : 0)
	var/want_y = ((direction & NORTH) ? 1 : 0) - ((direction & SOUTH) ? 1 : 0)
	var/burn = autopilot_aim_drift(want_x, want_y)
	if(burn)
		// Burn only the axes still missing, exactly as the autopilot does.
		change_heading(burn)
	else
		// Drift already serves every commanded axis. Trim to the cruise target
		// if the ship came in hot, top up if it came in slow, coast if it's there.
		// Same 0.1% tolerance as check_cruise(), so a ship already sitting at
		// cruise isn't sent back to the engines over a float rounding.
		clamp_speed(cruise_target_speed())
		if(MAGNITUDE(speed[1], speed[2]) < cruise_target_speed() * 0.999)
			change_heading(direction)
		else
			change_heading(BURN_NONE)
	// The rose lights from commanded_course; without a push the console waits
	// for the next tile crossing to hear about it.
	push_helm_frame()

/**
 * The cruise governor, run every thrust tick from process().
 *
 * A burn integrates thrust every 0.2s with nothing else watching it, so this is
 * what turns "hold the button" into "reach the commanded speed and coast": the
 * moment every commanded axis is moving the right way and the throttle's target
 * is met, the engines are cut and the course rides on velocity alone. It is
 * also why holding a course no longer burns fuel forever at the speed cap.
 */
/obj/structure/overmap/ship/proc/check_cruise()
	if(commanded_course == BURN_NONE || burn_direction == BURN_NONE || burn_direction == BURN_STOP)
		return
	var/want_x = ((commanded_course & EAST) ? 1 : 0) - ((commanded_course & WEST) ? 1 : 0)
	var/want_y = ((commanded_course & NORTH) ? 1 : 0) - ((commanded_course & SOUTH) ? 1 : 0)
	// Still turning: an axis isn't carrying the ship the commanded way yet.
	if(want_x && SIGN(speed[1]) != want_x)
		return
	if(want_y && SIGN(speed[2]) != want_y)
		return
	// 0.1% under the target counts as arrived. adjust_speed()'s cap rescales the
	// vector through single-precision floats, so demanding the exact ceiling can
	// park the magnitude one rounding step under max_speed with the burn never
	// going cold - the precise forever-burn this governor exists to end.
	if(MAGNITUDE(speed[1], speed[2]) < cruise_target_speed() * 0.999)
		return
	// Up to speed and pointed right: trim off what the last tick overshot by and
	// go cold. commanded_course stays set - that IS the cruise state.
	clamp_speed(cruise_target_speed())
	change_heading(BURN_NONE)
	push_helm_frame()

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
	// on them (see ship_autopilot.dm).
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
#undef SHIP_SPEED_MULTIPLIER_DEFAULT
#undef SHIP_RENAME_COOLDOWN

#undef DOCK_MOVE_MAX_ATTEMPTS
#undef MANOEUVRE_STALL_TIMEOUT
#undef DOCK_WARMUP_TIME
#undef UNDOCK_WARMUP_TIME
#undef UNDOCK_COOLDOWN_TIME
