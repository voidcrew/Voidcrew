/**
 * NPC Ship - AI-controlled ships that can engage players in combat
 *
 * These ships spawn in any zone and use territorial AI to attack
 * player ships that come within range. The zone determines behavior:
 * - Yellow zone: scan -> hail -> negotiate -> interdict + siphon (economic threat)
 * - Red zone: hail -> negotiate -> boarding waves -> boss (lethal threat)
 */
/obj/structure/overmap/ship/npc
	name = "unidentified vessel"
	desc = "An AI-controlled vessel."
	/// The commissioning grant is for player crews; an NPC hull funds itself from
	/// hold_credits_min/max instead, which is zone-scaled and rolled per ship.
	starting_credits = 0

	/// Lower bound on what this hull is carrying when it spawns. This is what a
	/// crew can take back off it with a data siphon, so a faction that demands
	/// big ransoms should be worth robbing in turn. Zero means an empty hull.
	var/hold_credits_min = 0
	/// Upper bound on the spawn hold roll.
	var/hold_credits_max = 0

	/// Combat interface for firing weapons
	var/datum/npc_combat_interface/combat_interface

	// ========== PER-SHIP CONFIGURABLE VARS ==========
	// Override these in subtypes to create different ship behaviors

	/// Whether this ship is hostile and attacks on sight
	var/hostile = TRUE

	/// How close player ships need to be to trigger aggression (in tiles)
	var/territory_range = 3
	/// Whether this ship is confined to the zone it spawned in. Hunter-type
	/// ships (customs patrols) clear this to chase a quarry across the map.
	var/zone_confined = TRUE

	/// Ship color tint for faction identification (set in subtypes)
	var/ship_color = null

	/// Movement speed cap for this NPC ship (tiles per tick)
	var/speed_limit = 0.5

	/// Acceleration per engine burn for this NPC ship
	var/thrust_power = 0.3

	/// Time to acquire weapons lock (deciseconds)
	var/lock_time = 5 SECONDS

	/// Cooldown between laser volleys (deciseconds)
	var/laser_cooldown_time = 5 SECONDS

	/// Cooldown between missile launches (deciseconds)
	var/missile_cooldown_time = 10 SECONDS

	/// Global cooldown between ANY weapon firing (missiles, lasers, boarding pods)
	/// This prevents rapid-fire spam across different weapon types
	var/global_weapon_cooldown_time = 10 SECONDS

	/// Override cloak duration for this NPC ship type (0 = use device's calculated value)
	var/npc_cloak_duration = 0

	/// Whether to retreat when all weapons are destroyed (FALSE = stay and use interdictor/siphon)
	var/retreat_without_weapons = TRUE

	/// Percentage of target's money to steal before retreating (0 = no limit, steal forever)
	var/siphon_goal_percent = 25

	/// How long the wealth scan takes (deciseconds)
	var/scan_time = 6 SECONDS

	/// Minimum credits target must have to be worth engaging
	var/min_target_wealth = 100

	/// Minimum crew to spawn
	var/crew_min = 3

	/// Maximum crew to spawn
	var/crew_max = 6

	/// List of mob types to spawn as crew (picked randomly)
	var/list/crew_types = list()

	/// Captain mob type - always spawns one with the ship key
	var/captain_type = null

	/// Shuttle template to use for this ship type (set in subtypes)
	var/shuttle_template = null

	// ========== INTERNAL STATE ==========

	/// Whether this ship can currently be boarded (disabled or interdicted)
	var/can_board = FALSE

	/// Whether this ship has been disabled (boss killed in phased combat)
	var/is_disabled = FALSE

	/// Cooldown for laser firing
	COOLDOWN_DECLARE(laser_cooldown)

	/// Cooldown for missile firing
	COOLDOWN_DECLARE(missile_cooldown)

	/// Global cooldown - prevents ALL weapons from firing (shared across lasers, missiles, pods)
	COOLDOWN_DECLARE(global_weapon_cooldown)

	/// Set faction for pirate hostility
	faction = list(FACTION_PIRATE)

	/// Default movement mode for this ship type
	var/default_movement_mode = NPC_MOVEMENT_PATROL

	/// Whether this ship has been claimed by a player (uses normal movement physics)
	var/player_controlled = FALSE

	// ========== CREW TRACKING & ABANDONMENT ==========

	/// List of all spawned crew members for tracking deaths
	var/list/mob/living/tracked_crew = list()

	/// Timer for abandonment after all crew die (gives players time to claim)
	var/abandonment_timer

	/// Delay before ship becomes abandoned after all crew die
	var/abandonment_delay = 10 MINUTES

	/// Whether the spawner has already been notified to spawn a replacement
	var/spawner_resolved = FALSE

	// ========== MASS CACHING (Performance optimization) ==========
	// Instead of iterating all turfs every second, we cache mass and only
	// recalculate when the ship takes hull damage

	/// Cached mass value - avoids iterating all turfs every second
	var/cached_mass = 0
	/// Whether cached_mass has been initialized
	var/mass_initialized = FALSE
	/// Whether mass needs recalculation (set TRUE when ship takes damage)
	var/mass_dirty = FALSE
	/// Cooldown to prevent mass recalc spam when taking multiple hits
	COOLDOWN_DECLARE(mass_recalc_cooldown)

/obj/structure/overmap/ship/npc/Initialize(mapload, datum/map_template/shuttle/voidcrew/template)
	. = ..()
	// Apply faction color tint
	if(ship_color)
		color = ship_color
		chat_color = ship_color
	// AI initialization happens after shuttle is fully loaded via signal or explicit call

/obj/structure/overmap/ship/npc/setup_from_template(datum/map_template/shuttle/voidcrew/template, datum/ship_theme/selected_theme)
	. = ..()
	if(!.)
		return
	fund_hold()

/**
 * Rolls this hull's spawn balance into its ship account.
 *
 * Called once, straight after the account exists. Pirates used to spawn broke,
 * which made them immune to the very siphon they carry - a crew that won the
 * fight had nothing to drain. The roll is scaled by the zone the hull spawned
 * in; ships created off the overmap (mission dispatch, admin spawns) fall back
 * to the yellow multiplier.
 */
/obj/structure/overmap/ship/npc/proc/fund_hold()
	if(!ship_account || hold_credits_max <= 0)
		return

	var/rolled = rand(hold_credits_min, hold_credits_max)
	var/zone_type = SSovermap_zones.get_zone_type(get_turf(src))
	switch(zone_type)
		if(ZONE_GREEN)
			rolled *= NPC_HOLD_ZONE_MULT_GREEN
		if(ZONE_RED)
			rolled *= NPC_HOLD_ZONE_MULT_RED
		else
			rolled *= NPC_HOLD_ZONE_MULT_YELLOW

	ship_account.adjust_money(round(rolled), "Hold: unaccounted takings")

/obj/structure/overmap/ship/npc/Destroy()
	QDEL_NULL(ai_controller)
	QDEL_NULL(combat_interface)
	// Clean up from dirty queue if we were in it
	SSovermap.dirty_npc_ships -= src
	// Notify spawner to spawn replacement (guard prevents double-notify if already resolved)
	notify_spawner_resolved()
	// Untrack from spawner subsystem
	SSnpc_ships.untrack_ship(src)
	// Cancel abandonment timer if running
	if(abandonment_timer)
		deltimer(abandonment_timer)
		abandonment_timer = null
	// Clear crew tracking
	tracked_crew.Cut()
	return ..()

/**
 * Initializes the AI controller and combat systems for this NPC ship.
 * Should be called after the shuttle is fully loaded and all machinery is in place.
 */
/obj/structure/overmap/ship/npc/proc/initialize_ai()
	if(ai_controller)
		return // Already initialized

	// Create combat interface to find and manage weapons
	combat_interface = new()
	combat_interface.initialize_from_ship(src)

	// Set static power levels - shields at 100%
	set_shield_power_allocation(1.0)

	// Create and attach AI controller
	ai_controller = new /datum/ai_controller/npc_ship(src)

	// Set default movement mode
	set_movement_mode(default_movement_mode)

	// Register for signals we care about
	RegisterSignal(src, COMSIG_SHIP_INTEGRITY_CHANGED, PROC_REF(on_integrity_changed))
	RegisterSignal(src, COMSIG_SHIP_INTERDICTED, PROC_REF(on_interdicted))
	// Only recalc mass on explosive damage (missiles) - lasers don't destroy enough turfs to matter
	RegisterSignal(src, COMSIG_SHIP_EXPLOSIVE_DAMAGE, PROC_REF(on_hull_damaged))
	// Clear combat when docked (e.g., force-docked by a player interdictor)
	RegisterSignal(src, COMSIG_VOIDCREW_SHIP_DOCKED, PROC_REF(on_ship_docked))

	// Calculate and cache initial mass (avoids per-second recalculation)
	mass_dirty = TRUE  // Force initial calculation
	calculate_mass()
	mass_initialized = TRUE

	// Spawn pirate crew
	spawn_crew()

/obj/structure/overmap/ship/npc/examine(mob/user)
	. = ..()
	// Debug info for admins
	if(!check_rights_for(user.client, R_DEBUG))
		return
	. += span_notice("--- NPC DEBUG INFO ---")
	if(!ai_controller)
		. += span_warning("AI Controller: NOT INITIALIZED")
		return
	var/datum/ai_controller/npc_ship/controller = ai_controller
	var/combat_state = controller.blackboard[BB_NPC_COMBAT_STATE] || "null"
	var/movement_mode = controller.blackboard[BB_NPC_MOVEMENT_MODE] || "null"
	var/has_target = controller.blackboard[BB_NPC_TARGET] ? "YES" : "NO"
	var/has_lock = controller.blackboard[BB_NPC_TARGET_LOCKED] ? "YES" : "NO"
	. += span_notice("Combat State: [combat_state]")
	. += span_notice("Movement Mode: [movement_mode]")
	. += span_notice("Has Target: [has_target]")
	. += span_notice("Weapons Lock: [has_lock]")
	if(combat_interface)
		var/laser_count = length(combat_interface.linked_laser_turrets)
		var/missile_count = length(combat_interface.linked_missile_launchers)
		. += span_notice("Lasers: [laser_count] | Missiles: [missile_count]")
	else
		. += span_warning("Combat Interface: NOT INITIALIZED")

/**
 * Sets the movement mode for this NPC ship.
 * Valid modes: NPC_MOVEMENT_IDLE, NPC_MOVEMENT_ORBIT, NPC_MOVEMENT_PATROL, NPC_MOVEMENT_CHASE
 */
/obj/structure/overmap/ship/npc/proc/set_movement_mode(mode)
	if(!ai_controller)
		return
	var/datum/ai_controller/npc_ship/controller = ai_controller
	controller.set_blackboard_key(BB_NPC_MOVEMENT_MODE, mode)

/**
 * Sets up chase mode. Ship will chase targets and return to patrol when done.
 * Note: Chase is now automatic when targets are detected, this just sets the mode.
 */
/obj/structure/overmap/ship/npc/proc/set_chase_mode()
	set_movement_mode(NPC_MOVEMENT_CHASE)

/**
 * Sets up patrol mode. Waypoints will be auto-generated.
 */
/obj/structure/overmap/ship/npc/proc/set_patrol_mode()
	set_movement_mode(NPC_MOVEMENT_PATROL)

/**
 * Scales up a freshly spawned NPC ship pirate's health pool.
 *
 * NPC ship crew and boarding pod mobs are the same types the ruin zone spawners,
 * planet spawns and bounty missions use, and those are balanced per zone band -
 * so the "fighting a ship" difficulty lives here at the spawn site instead of on
 * the mob definitions. It also picks up bosses that set their health in
 * Initialize() rather than as a var default.
 *
 * Only valid on an undamaged mob: health is rebuilt from the new maxHealth.
 */
/proc/scale_npc_ship_pirate_health(mob/living/pirate, multiplier = NPC_PIRATE_CREW_HEALTH_MULT)
	if(QDELETED(pirate) || multiplier <= 1)
		return
	pirate.maxHealth = round(pirate.maxHealth * multiplier)
	pirate.updatehealth()

/**
 * Spawns crew aboard the ship using per-ship crew configuration.
 * Override crew_min, crew_max, and crew_types in subtypes for different crews.
 */
/obj/structure/overmap/ship/npc/proc/spawn_crew()
	if(!shuttle?.shuttle_areas)
		return

	// No crew types defined = no crew to spawn
	if(!length(crew_types))
		return

	var/crew_count = rand(crew_min, crew_max)
	var/list/valid_turfs = list()

	// Find valid spawn turfs (floor tiles that aren't blocked)
	for(var/area/shuttle_area as anything in shuttle.shuttle_areas)
		for(var/turf/T in shuttle_area)
			// Skip space
			if(isspaceturf(T))
				continue
			// Skip dense turfs (walls, etc.)
			if(T.density)
				continue
			// Must be an open floor type
			if(!isfloorturf(T))
				continue
			// Check for dense objects blocking the turf
			var/blocked = FALSE
			for(var/obj/O in T)
				if(O.density)
					blocked = TRUE
					break
			if(blocked)
				continue
			valid_turfs += T

	if(!length(valid_turfs))
		return

	// Spawn captain first with ship key
	if(captain_type && length(valid_turfs))
		var/turf/captain_loc = pick_n_take(valid_turfs)
		var/mob/living/basic/captain = new captain_type(captain_loc)
		scale_npc_ship_pirate_health(captain)
		// Give captain the ship key - stored in contents, drops on death
		var/obj/item/ship_key/key = new(null, src)
		key.forceMove(captain)
		// Track captain and register death signal
		tracked_crew += captain
		RegisterSignal(captain, COMSIG_LIVING_DEATH, PROC_REF(on_crew_death))
		crew_count--  // Captain counts toward crew count

	// Spawn rest of crew from configured types
	for(var/i in 1 to min(crew_count, length(valid_turfs)))
		var/turf/spawn_loc = pick_n_take(valid_turfs)
		var/mob_type = pick(crew_types)
		var/mob/living/crewmember = new mob_type(spawn_loc)
		scale_npc_ship_pirate_health(crewmember)
		// Track crew and register death signal
		tracked_crew += crewmember
		RegisterSignal(crewmember, COMSIG_LIVING_DEATH, PROC_REF(on_crew_death))

/**
 * Signal handler for when any crew member dies.
 * Tracks deaths and triggers abandonment when all crew are dead.
 */
/obj/structure/overmap/ship/npc/proc/on_crew_death(mob/living/victim, gibbed)
	SIGNAL_HANDLER
	UnregisterSignal(victim, COMSIG_LIVING_DEATH)

	// Drop ship key if the victim has one (captain)
	var/turf/drop_loc = get_turf(victim)
	if(drop_loc)
		for(var/obj/item/ship_key/key in victim.contents)
			key.forceMove(drop_loc)

	// Remove from tracked crew list
	tracked_crew -= victim

	// Check if all crew are dead
	if(!length(tracked_crew))
		start_abandonment_timer()

/**
 * Starts a timer to abandon the ship after all crew die.
 * Gives players a window to find and use the ship key to claim.
 */
/obj/structure/overmap/ship/npc/proc/start_abandonment_timer()
	if(abandonment_timer)
		return // Already started
	if(abandoned || player_controlled)
		return // Already claimed or converted

	message_admins("\[NPC SHIP]: [name] crew eliminated! Ship will be abandoned in [abandonment_delay / 600] minutes. [ADMIN_COORDJMP(src)]")
	abandonment_timer = addtimer(CALLBACK(src, PROC_REF(abandon_ship), TRUE), abandonment_delay, TIMER_STOPPABLE)

/**
 * Cancels the abandonment timer (e.g., if ship is claimed before timer fires).
 */
/obj/structure/overmap/ship/npc/proc/cancel_abandonment_timer()
	if(abandonment_timer)
		deltimer(abandonment_timer)
		abandonment_timer = null

/**
 * Override abandon_ship to notify spawner that this pirate is resolved.
 * When an NPC ship is abandoned, we immediately spawn a replacement.
 * The abandoned ship stays as a derelict that players can still claim.
 */
/obj/structure/overmap/ship/npc/abandon_ship(crash = TRUE)
	// Notify spawner before calling parent (spawns replacement pirate)
	notify_spawner_resolved()

	// Call parent implementation
	return ..()

/**
 * Notifies the spawner subsystem that this pirate ship is no longer active.
 * Triggers spawning of a replacement pirate.
 * Only notifies once per ship to prevent duplicate replacements.
 */
/obj/structure/overmap/ship/npc/proc/notify_spawner_resolved()
	if(spawner_resolved)
		return
	// Don't notify if already player-controlled (was claimed)
	if(player_controlled)
		return

	spawner_resolved = TRUE
	var/turf/ship_turf = get_turf(src)
	var/datum/overmap_zone/zone = SSovermap_zones.get_zone(ship_turf)
	SSnpc_ships.on_pirate_resolved(type, zone?.zone_type)

/**
 * Signal handler for ship integrity changes.
 * Updates boarding state when ship is damaged enough.
 */
/obj/structure/overmap/ship/npc/proc/on_integrity_changed(datum/source, new_integrity, max_integrity, display_percent)
	SIGNAL_HANDLER
	update_boarding_state()

/**
 * Signal handler for when the ship is docked (e.g., force-docked by player interdictor).
 * Clears all combat state so the NPC ship doesn't attack while docked.
 */
/obj/structure/overmap/ship/npc/proc/on_ship_docked(datum/source)
	SIGNAL_HANDLER
	var/datum/ai_controller/npc_ship/controller = ai_controller
	if(controller)
		INVOKE_ASYNC(controller, TYPE_PROC_REF(/datum/ai_controller/npc_ship, clear_target))

/**
 * Signal handler for when ship is interdicted.
 * Marks ship as boardable when interdicted.
 */
/obj/structure/overmap/ship/npc/proc/on_interdicted(datum/source, obj/machinery/ship_combat/interdictor/interdictor, power_level)
	SIGNAL_HANDLER
	// When interdicted, the ship becomes boardable via force dock
	update_boarding_state()

/**
 * Updates whether this ship can be boarded based on current state.
 * Ship is boardable when:
 * 1. Integrity <= 75% (disabled), OR
 * 2. Ship is currently interdicted, OR
 * 3. All engines are destroyed/non-functional
 */
/obj/structure/overmap/ship/npc/proc/update_boarding_state()
	// Check integrity - ship is disabled at 75% or below
	if(max_integrity > 0)
		var/integrity_percent = (integrity / max_integrity) * 100
		if(integrity_percent <= 75)
			can_board = TRUE
			return

	// Check interdiction
	if(is_interdicted)
		can_board = TRUE
		return

	// Check engines - no working engines means dead in the water
	if(!can_thrust())
		can_board = TRUE
		return

	can_board = FALSE

/**
 * Sets the ship into disabled state (boss was killed).
 * In this state:
 * - Ship stops attacking
 * - Ship can be boarded by players
 * - AI is paused
 */
/obj/structure/overmap/ship/npc/proc/set_disabled_state()
	is_disabled = TRUE
	can_board = TRUE

	// Notify player ship that pirate is disabled
	var/datum/ai_controller/npc_ship/controller = ai_controller
	if(controller)
		var/obj/structure/overmap/ship/target = controller.get_target()
		if(target && !QDELETED(target))
			target.ship_notify("[name] has been disabled! You may now board and claim the vessel.", "COMBAT", SHIP_NOTIFY_NOTICE, 'voidcrew/sound/notify.ogg', 50)
		controller.set_combat_state(NPC_COMBAT_DISABLED)

	// Announce to this ship
	ship_notify("All hands lost. Ship systems failing.", "CRITICAL", SHIP_NOTIFY_DANGER, 'voidcrew/sound/warn3.ogg', 25)

/**
 * Override burn_engines to use per-ship acceleration while still requiring working engines.
 * This bypasses the complex thrust/mass calculation but ensures the ship has functional
 * engines before allowing movement.
 *
 * When player_controlled is TRUE, uses normal engine physics instead.
 */
/obj/structure/overmap/ship/npc/burn_engines(n_dir = null, percentage = 100)
	// If player-controlled, use normal engine physics
	if(player_controlled)
		return ..()

	if(state != OVERMAP_SHIP_FLYING)
		return

	// Must have at least one working engine with fuel
	if(!can_thrust())
		return

	// Decelerate
	if(!n_dir)
		decelerate(thrust_power * (percentage / 100))
		return

	// Accelerate using per-ship thrust power
	accelerate(n_dir, thrust_power * (percentage / 100))

	// Cap at per-ship speed limit
	var/current_magnitude = MAGNITUDE(speed[1], speed[2])
	if(current_magnitude > speed_limit)
		var/scale = speed_limit / current_magnitude
		speed[1] *= scale
		speed[2] *= scale

// ========== MASS CALCULATION OVERRIDE ==========

/**
 * NPC hulls never remodel themselves, so nothing they lose is construction.
 *
 * Without this an NPC pirate would heal as it was taken apart: interdicting one leaves it
 * docked and IDLE, which is precisely the state a boarding party wrecks it in, and the base
 * rule would read every breached wall as the owners choosing to have less ship. Its baseline
 * would track the damage down, integrity would sit at 100%, and update_boarding_state() would
 * pull can_board back to FALSE with the boarders already aboard.
 */
/obj/structure/overmap/ship/npc/hull_baseline_follows_losses()
	return FALSE

/**
 * Override calculate_mass to use cached value for performance.
 * Instead of iterating all turfs every second, we only recalculate when:
 * 1. Mass hasn't been initialized yet
 * 2. Ship has taken hull damage (mass_dirty = TRUE)
 * 3. Cooldown has expired (prevents spam recalc when taking multiple hits)
 *
 * This saves thousands of turf iterations per second across all NPC ships.
 */
/obj/structure/overmap/ship/npc/calculate_mass()
	// If not dirty and initialized, return cached value
	if(!mass_dirty && mass_initialized)
		return cached_mass

	// Even if dirty, respect cooldown to prevent spam (unless first init)
	if(mass_initialized && !COOLDOWN_FINISHED(src, mass_recalc_cooldown))
		return cached_mass

	// Recalculate using parent proc
	cached_mass = ..()
	mass_dirty = FALSE

	// Start cooldown - won't recalc again for 6 seconds even if hit more
	COOLDOWN_START(src, mass_recalc_cooldown, 6 SECONDS)

	// Remove from dirty queue if we were in it
	SSovermap.dirty_npc_ships -= src

	return cached_mass

/**
 * Signal handler for when the ship takes hull damage.
 * Marks mass as dirty so it will be recalculated.
 */
/obj/structure/overmap/ship/npc/proc/on_hull_damaged(datum/source, turf/impact_location)
	SIGNAL_HANDLER

	// Check if engines were destroyed (makes ship boardable)
	update_boarding_state()

	// Don't queue if already dirty
	if(mass_dirty)
		return

	mass_dirty = TRUE
	SSovermap.dirty_npc_ships |= src

// ========== SHIP TYPE SUBTYPES ==========

/**
 * Pirate Ship - Hostile vessels that attack on sight
 *
 * Pirates are aggressive, attack any player ships in range,
 * and spawn with armed pirate crew.
 */
/obj/structure/overmap/ship/npc/pirate
	name = "pirate vessel"
	desc = "A hostile vessel operated by pirates."

	// Pirates are hostile and attack on sight
	hostile = TRUE
	territory_range = 3

	// Red color for pirate faction
	ship_color = NPC_COLOR_PIRATE

	shuttle_template = /datum/map_template/shuttle/voidcrew/pirate_default

	// Combat stats - balanced for gameplay
	lock_time = 5 SECONDS
	laser_cooldown_time = 6 SECONDS  // Increased from 5s for balance
	missile_cooldown_time = 15 SECONDS  // Increased from 10s for balance
	npc_cloak_duration = 5 SECONDS  // Short cloak for pirates

	// Movement stats
	speed_limit = 0.5
	thrust_power = 0.3

	// Crew configuration
	crew_min = 3
	crew_max = 6
	captain_type = /mob/living/basic/trooper/pirate/ranged/space
	crew_types = list(
		/mob/living/basic/trooper/pirate/melee/space,
		/mob/living/basic/trooper/pirate/ranged/space,
	)

	// Faction
	faction = list(FACTION_PIRATE)

	// Takings aboard - roughly tracks the faction's ransom appetite below, so the
	// crews that demand the most are also the ones worth siphoning back
	hold_credits_min = 1200
	hold_credits_max = 2600

	// ========== NEGOTIATION CONFIG ==========
	/// Whether this pirate accepts negotiations (can be hailed)
	var/accepts_negotiation = TRUE
	/// Faction dialog type for negotiation personality
	var/negotiation_dialog_type
	/// Minimum credits to demand in negotiation
	var/min_negotiation_demand = 500
	/// Maximum credits to demand in negotiation
	var/max_negotiation_demand = 10000
	/// Faction identifier for dialog and appearance
	var/pirate_faction
	/// Fixed negotiation item demand as list(type, quantity, name), set by
	/// mission dispatch code so the ship asks for specific cargo instead of a
	/// random pick (e.g. a customs patrol demanding the contraband itself)
	var/list/fixed_item_demand

	// ========== BOARDING POD CONFIG ==========
	/// Whether this pirate can launch boarding pods
	var/boarding_pods_enabled = TRUE
	/// Minimum number of pods to launch at once
	var/boarding_pods_min = 1
	/// Maximum number of pods to launch at once
	var/boarding_pods_max = 3
	/// Cooldown between boarding pod salvos
	var/boarding_pod_cooldown_time = 30 SECONDS
	/// List of mob types to spawn in boarding pods (uses crew_types if empty)
	var/list/boarding_pod_mob_types = list()
	/// Cooldown tracker for boarding pod launches
	COOLDOWN_DECLARE(boarding_pod_cooldown)

	// ========== PHASED BOARDING COMBAT CONFIG ==========
	/// Whether this pirate uses the phased boarding system (negotiation fail -> waves -> boss)
	var/uses_boarding_phases = TRUE
	/// Wave sizes by wave number - list of list(min, max) per wave
	/// Default scales with crew count, these are base values
	var/list/boarding_wave_sizes = list(
		list(2, 3),  // Wave 1
		list(3, 4),  // Wave 2
		list(3, 5),  // Wave 3
	)
	/// Boss mob type for this faction
	var/boss_type
	/// Minimum crew on target ship to bother attacking (small ship protection)
	var/min_target_crew = 1
	/// Said over comms when a yellow-zone wealth scan comes back empty and the
	/// pirate boards for cargo instead of credits.
	var/list/broke_lines = list(
		"No money, huh? Let's see if my boys can find something to steal on your ship then. Maybe your life?",
		"Empty accounts. Fine - we'll take it out of your hold. Stand by to be boarded.",
	)
	/// Wave taunts - played during cooldown between waves
	var/list/wave_taunts = list(
		list(  // Wave 1 -> 2 cooldown
			"Your resistance is noted. Reinforcements inbound.",
			"You fight well for cargo haulers. Let's see how long that lasts.",
		),
		list(  // Wave 2 -> 3 cooldown
			"This is your final warning. Surrender now.",
			"Impressive. But the next wave won't be so gentle.",
		),
		list(  // Boss spawn
			"You've forced my hand. I'm coming personally.",
			"Enough games. Prepare to meet your end.",
		),
	)

