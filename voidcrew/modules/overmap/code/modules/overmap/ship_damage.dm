/**
 * Ship Damage System
 *
 * Handles ship integrity and damage from hazards.
 * Ships take damage when flying through dangerous overmap objects like
 * ion storms, electrical storms, and meteor fields.
 *
 * Ship health is purely turf-based:
 * - Damage = turfs being destroyed (explosions, meteors, etc.)
 * - Repair = turfs being rebuilt (construction)
 *
 * Mass tracking is event-driven via signals (see setup_mass_tracking in ship.dm):
 * - COMSIG_TURF_CHANGE: tracks turf type changes (wall->floor, floor->space)
 * - COMSIG_TURF_REMOVED_FROM_SHUTTLE: tracks turfs removed from shuttle
 * - COMSIG_SHUTTLE_EXPANDED: tracks new turfs added via expansion
 * This is ~750x more efficient than the old polling approach.
 */

/// How often a ship sitting in a radioactive nebula takes a dose. Also throttles the
/// shielder poll that goes with it, since polling one costs it power and a puff of tritium.
#define NEBULA_RADIATION_INTERVAL (20 SECONDS)

/obj/structure/overmap/ship
	/// Cooldown for hazard damage ticks
	COOLDOWN_DECLARE(hazard_damage_cooldown)
	/// Cooldown between radiation doses from a tritium nebula. See apply_nebula_radiation().
	COOLDOWN_DECLARE(nebula_radiation_cooldown)
	/// Cooldown preventing undocking after a hull failure. See enter_integrity_failure().
	COOLDOWN_DECLARE(integrity_undock_lockout)
	/// Whether ship integrity has been initialized from mass
	var/integrity_initialized = FALSE
	/// Latched alarm band - one of the SHIP_INTEGRITY_* states. See evaluate_integrity().
	var/integrity_state = SHIP_INTEGRITY_NOMINAL
	/// TRUE while a threshold evaluation is already scheduled for the end of this tick.
	var/integrity_eval_queued = FALSE
	/// DEPRECATED - No longer used. max_integrity now scales with ship expansion.
	var/overhealth = 0
	/// Whether the ship has already crash landed (prevents multiple crashes)
	var/has_crash_landed = FALSE
	/// Integrity (mass) value when the ship crashed (for repair progress calculation)
	var/crashed_at_integrity = 0
	/// Timer ID for critical state alert loop
	var/critical_alert_timer


/**
 * Returns the current integrity as a percentage for UI display
 * Shows actual turf percentage - ship crashes at 50%
 * max_integrity scales with ship expansion, so this is always 0-100%
 */
/obj/structure/overmap/ship/proc/get_integrity_percent()
	if(max_integrity <= 0)
		return 100
	return round((integrity / max_integrity) * 100)

/**
 * Returns just the overhealth portion as a percentage
 * No longer used - max_integrity now scales with ship expansion
 */
/obj/structure/overmap/ship/proc/get_overhealth_percent()
	return 0

/**
 * Starts the critical alert loop - plays warning sound repeatedly
 */
/obj/structure/overmap/ship/proc/start_critical_alert()
	if(critical_alert_timer)
		return // Already running
	// Play immediately, then loop every 3 seconds

	play_ship_sound('sound/machines/engine_alert/engine_alert3.ogg', 85)
	play_ship_vox(list("alert", "critical", "damage"))
	critical_alert_timer = addtimer(CALLBACK(src, PROC_REF(critical_alert_tick)), 5 SECONDS, TIMER_LOOP | TIMER_STOPPABLE)

/**
 * Called each tick of the critical alert loop
 */
/obj/structure/overmap/ship/proc/critical_alert_tick()
	play_ship_sound('sound/machines/engine_alert/engine_alert3.ogg', 85)
	play_ship_vox(list("failure", "immediate"))

/**
 * Stops the critical alert loop
 */
/obj/structure/overmap/ship/proc/stop_critical_alert()
	if(critical_alert_timer)
		deltimer(critical_alert_timer)
		critical_alert_timer = null

/**
 * Called once, on the transition out of SHIP_INTEGRITY_DISABLED.
 *
 * Clearing has_crash_landed here is what lets the ship be lost again later. It used to be
 * cleared only on undock, which left a repaired-but-still-docked hull permanently flagged as
 * crashed: on_ship_destroyed() would refuse to run a second time, and the helm kept reporting
 * a wreck the crew had already rebuilt.
 */
/obj/structure/overmap/ship/proc/on_ship_recovered()
	has_crash_landed = FALSE
	crashed_at_integrity = 0
	play_ship_sound('sound/machines/computer/computer_start.ogg', 15)

	// "Systems operational" on its own sends the crew straight to a refused undock, because the
	// post-failure lockout outlives the damage that armed it. Say so in the same breath.
	var/restored = "Hull integrity restored. Ship systems operational."
	if(!COOLDOWN_FINISHED(src, integrity_undock_lockout))
		restored += " Docking clamps remain locked for structural recertification - [DisplayTimeText(COOLDOWN_TIMELEFT(src, integrity_undock_lockout))] remaining."
	ship_notify(restored, "SYSTEMS", SHIP_NOTIFY_NOTICE, 'voidcrew/sound/notify.ogg', 50)

/**
 * The single entry point into SHIP_INTEGRITY_DISABLED.
 *
 * Everything that can lose a hull goes through here so the post-failure undock lockout is
 * armed by the same act that latches the state, rather than by each caller remembering to.
 *
 * The lockout runs from the failure, not from the repair. A hull that fails is grounded for
 * SHIP_INTEGRITY_UNDOCK_LOCKOUT whatever the crew does to it in the meantime - welding the
 * last breach shut brings the ship back to 100% and still does not open the clamps. Repairs
 * that take longer than the lockout cost nothing extra; the timer has simply already run.
 */
/obj/structure/overmap/ship/proc/enter_integrity_failure()
	integrity_state = SHIP_INTEGRITY_DISABLED
	COOLDOWN_START(src, integrity_undock_lockout, SHIP_INTEGRITY_UNDOCK_LOCKOUT)
	stop_critical_alert()
	on_ship_destroyed()

/**
 * Called when ship integrity reaches 0
 * Strands the ship and triggers cascade failures
 */
/obj/structure/overmap/ship/proc/on_ship_destroyed()
	// Prevent multiple crash landings
	if(has_crash_landed)
		return
	has_crash_landed = TRUE
	// Record current integrity for repair progress calculation
	crashed_at_integrity = integrity

	// Stop the ship dead
	speed[1] = 0
	speed[2] = 0
	if(movement_callback_id)
		deltimer(movement_callback_id)
		movement_callback_id = null
	update_flight_parallax() // dead in the water: stop the starfield scroll

	// Cascade failures - fires, explosions, EMPs throughout the ship
	var/failure_count = rand(1, 7)
	for(var/i in 1 to failure_count)
		var/turf/target = get_random_ship_turf()
		if(!target)
			continue

		do_sparks(5, FALSE, target)

	// Dock into a "crashed ship" location so others can find and help/raid
	crash_land()

	// Signal that the ship has been destroyed
	SEND_SIGNAL(src, COMSIG_SHIP_DESTROYED)

/**
 * Emergency docks the ship - either onto a planet if above one, or creates a crash site
 */
/obj/structure/overmap/ship/proc/crash_land()
	if(!shuttle)
		return

	// Don't crash land if already docked (e.g., ship-to-ship docking)
	// The other ship can help/rescue without needing to create a crash site
	if(state == OVERMAP_SHIP_IDLE || state == OVERMAP_SHIP_DOCKING)
		ship_notify("Ship critically damaged! Emergency systems holding. Seek immediate repairs.", "CRITICAL", SHIP_NOTIFY_DANGER, 'voidcrew/sound/warn3.ogg', 25)
		return

	// Check if we're above a planet - if so, crash onto it
	// First check close_overmap_objects (tracked when objects share a tile)
	for(var/obj/structure/overmap/planet/planet_below in close_overmap_objects)
		if(istype(planet_below, /obj/structure/overmap/planet/empty))
			continue
		// A planet mid-teardown is deleting every atom on its level - a hull docked
		// into that gets wiped along with the terrain. Crash into open space instead.
		if(planet_below.unloading)
			continue
		crash_land_on_planet(planet_below)
		return
	// Also check turf contents directly
	var/turf/our_turf = get_turf(src)
	if(our_turf)
		for(var/obj/structure/overmap/planet/planet_below in our_turf.contents)
			if(istype(planet_below, /obj/structure/overmap/planet/empty))
				continue
			if(planet_below.unloading)
				continue
			crash_land_on_planet(planet_below)
			return

	// No planet - create crashed ship marker at current location
	make_crash_site()

/**
 * Creates a fresh crashed-ship site at the ship's current overmap tile and docks the
 * hull into it. The no-planet crash path, and the fallback for every planet-crash
 * attempt that finds its planet missing, tearing down, or never finishing its build -
 * those used to just return, leaving the hull stranded on the transit level with
 * has_crash_landed latched and no way to ever land it.
 */
/obj/structure/overmap/ship/proc/make_crash_site()
	var/turf/site_turf = get_turf(src)
	if(!site_turf)
		return
	var/obj/structure/overmap/planet/empty/crashed_ship/crash_site = new(site_turf)

	play_ship_sound('sound/items/weapons/mortar_long_whistle.ogg')

	// Load the level
	if(!crash_site.loaded && !crash_site.loading)
		crash_site.load_level()

	// Wait for level to load then dock
	if(crash_site.loading)
		addtimer(CALLBACK(src, PROC_REF(finish_crash_land), crash_site), 2 SECONDS)
		return

	finish_crash_land(crash_site)

/**
 * Crash lands the ship onto an existing planet at a random location
 * Doesn't care about docking ports - just slams down wherever
 */
/obj/structure/overmap/ship/proc/crash_land_on_planet(obj/structure/overmap/planet/planet)
	if(!planet || !shuttle)
		return

	ship_notify("EMERGENCY: Crash landing on [planet.name]!", "MAYDAY", SHIP_NOTIFY_DANGER, 'voidcrew/sound/warn3.ogg', 25)
	play_ship_sound('sound/items/weapons/mortar_long_whistle.ogg')

	// Load the planet if not already loaded
	if(!planet.loaded && !planet.loading)
		planet.load_level()

	// Wait for level to load then dock
	if(planet.loading)
		addtimer(CALLBACK(src, PROC_REF(finish_crash_land_on_planet), planet), 2 SECONDS)
		return

	finish_crash_land_on_planet(planet)

/**
 * Finishes the crash landing onto a planet - picks a random spot and slams down.
 *
 * Every bail-out goes through make_crash_site() rather than a bare return: a bare
 * return leaves the hull stranded on the transit level with has_crash_landed latched,
 * unlandable and unfindable for the rest of the round.
 *
 * `retries` counts the 2-second waits spent on a planet that is still building. A
 * queued terrain build holds the worldgen queue for upwards of a minute, and docking
 * into a half-generated level is how a hull gets overwritten by the terrain fill or
 * entombed by the cordon pass that runs late in the build.
 */
/obj/structure/overmap/ship/proc/finish_crash_land_on_planet(obj/structure/overmap/planet/planet, retries = 0)
	if(!shuttle)
		return

	// The planet can be gone, or tearing its level down, by the time we fall - never
	// dock into a level that is being wiped.
	if(!planet || QDELETED(planet) || planet.unloading || !planet.mapzone)
		make_crash_site()
		return

	// Still building - wait it out (up to 3 minutes), then give up and crash in space
	if(planet.loading || !planet.loaded)
		if(retries < 90)
			addtimer(CALLBACK(src, PROC_REF(finish_crash_land_on_planet), planet, retries + 1), 2 SECONDS)
		else
			make_crash_site()
		return

	// Get the planet's z-level
	var/datum/space_level/zlevel = planet.mapzone.z_levels[1]
	if(!zlevel || isnull(zlevel.low_x))
		make_crash_site()
		return

	// Pick a random spot that keeps the whole hull inside THIS PLANET's footprint.
	//
	// The site rect bounds the buildable surface; everything outside it is either
	// indestructible cordon or - on a packed z-level - a different planet's ground. A hull
	// force-docked into the cordon is sealed in for good, and one force-docked onto the
	// neighbour lands on a world its crew never surveyed, past a cordon they cannot cross,
	// while :317-320 below records it as docked to THIS planet. The bounds were once
	// low + world.maxx/maxy, which on a 128x128 planet put roughly half the random range in
	// the cordon (or off the map) - round 4's 10-hour hull was entombed exactly that way by
	// its own derelict auto-crash. The level's rect is the same class of mistake once a level
	// is shared, since it widens to the whole z the moment a second tenant lands.
	var/datum/map_footprint/site = planet.footprint
	var/has_footprint = site && !isnull(site.low_x) && site.z_value
	var/site_low_x = has_footprint ? site.low_x : zlevel.low_x
	var/site_low_y = has_footprint ? site.low_y : zlevel.low_y
	var/site_high_x = has_footprint ? site.high_x : zlevel.high_x
	var/site_high_y = has_footprint ? site.high_y : zlevel.high_y
	var/site_z = has_footprint ? site.z_value : zlevel.z_value
	var/padding = max(shuttle.width, shuttle.height) + 5
	var/min_x = site_low_x + padding
	var/max_x = site_high_x - padding
	var/min_y = site_low_y + padding
	var/max_y = site_high_y - padding
	var/target_x
	var/target_y
	if(min_x > max_x || min_y > max_y)
		// Hull too large for a padded pick - aim for the middle of the footprint
		target_x = round((site_low_x + site_high_x) / 2)
		target_y = round((site_low_y + site_high_y) / 2)
	else
		target_x = rand(min_x, max_x)
		target_y = rand(min_y, max_y)
	var/turf/crash_turf = locate(target_x, target_y, site_z)

	if(!crash_turf)
		make_crash_site()
		return

	// Create a temporary docking port at the crash site
	var/obj/docking_port/stationary/crash_dock = new(crash_turf)
	crash_dock.dir = shuttle.dir
	crash_dock.name = "Crash Site"
	crash_dock.height = shuttle.height
	crash_dock.width = shuttle.width
	crash_dock.dheight = shuttle.dheight
	crash_dock.dwidth = shuttle.dwidth

	// Force dock - don't care what's there, we're crashing
	shuttle.initiate_docking(crash_dock, shuttle.dir, force = TRUE)

	// Update ship state
	forceMove(planet)
	state = OVERMAP_SHIP_IDLE
	docked = planet
	// The crash ends whatever course the helm was holding - without this the
	// rose stays lit on a hull embedded in a planet, and a latched zone crossing
	// would try to fly it out again
	commanded_course = BURN_NONE
	zone_resume_burn = BURN_NONE

	// Clean up the temporary dock - forced, or docking_port/Destroy answers with
	// QDEL_HINT_LETMELIVE and the port leaks in SSshuttle.stationary_docking_ports
	qdel(crash_dock, force = TRUE)

	// Crash effects
	on_crash_dock_complete()

/**
 * Finishes the crash landing after the level loads
 */
/obj/structure/overmap/ship/proc/finish_crash_land(obj/structure/overmap/planet/empty/crashed_ship/crash_site)
	if(!crash_site || !shuttle)
		return

	// Get a dock
	var/obj/docking_port/stationary/dock_to_use = null
	if(crash_site.reserve_dock && !crash_site.first_dock_taken)
		dock_to_use = crash_site.reserve_dock
		crash_site.first_dock_taken = TRUE
		dock_index = 1
	else if(crash_site.reserve_dock_secondary && !crash_site.second_dock_taken)
		dock_to_use = crash_site.reserve_dock_secondary
		crash_site.second_dock_taken = TRUE
		dock_index = 2

	if(!dock_to_use)
		return

	shuttle.port_destinations = dock_to_use
	crash_site.adjust_dock_to_shuttle(dock_to_use, shuttle)

	// Register for dock completion signal - effects happen the instant we land
	RegisterSignal(src, COMSIG_VOIDCREW_SHIP_DOCKED, PROC_REF(on_crash_dock_complete))

	dock(crash_site, dock_to_use, instant = TRUE)

/**
 * Signal handler - crash effects the instant docking completes
 */
/obj/structure/overmap/ship/proc/on_crash_dock_complete(datum/source)
	SIGNAL_HANDLER
	UnregisterSignal(src, COMSIG_VOIDCREW_SHIP_DOCKED)

	// Both crash paths land here, so this is the one place to catch a hull that has
	// somehow ended up against the reservation cordon.
	audit_cordon_seal("crash landing")

	// Play explosion sound to all crew
	play_ship_sound('sound/effects/explosion/explosioncreak1.ogg', 100)

	// Violent shake
	// shake_ship(30, 5)

	// Fling everything on the ship violently - simulates crash impact
	crash_throw_contents()

/**
 * Loud alarm for a hull sealed in by the reservation cordon.
 *
 * Scans the shuttle's footprint plus a one-tile border for /turf/cordon. The cordon
 * ring is indestructible, so a hull whose rect touches it cannot be recovered by the
 * crew - only an admin can move it - and the only way to end up there is a lifecycle
 * bug, which is exactly why it has to be reported the moment it happens instead of
 * being discovered by a ghost hours later (round 4, "Shithole").
 */
/obj/structure/overmap/ship/proc/audit_cordon_seal(context = "docking")
	if(!shuttle)
		return
	var/turf/origin = get_turf(shuttle)
	if(!origin)
		return
	var/list/coords = shuttle.return_coords()
	if(!coords || coords.len < 4)
		return
	var/scan_min_x = max(1, min(coords[1], coords[3]) - 1)
	var/scan_min_y = max(1, min(coords[2], coords[4]) - 1)
	var/scan_max_x = min(world.maxx, max(coords[1], coords[3]) + 1)
	var/scan_max_y = min(world.maxy, max(coords[2], coords[4]) + 1)
	for(var/turf/scanned as anything in block(locate(scan_min_x, scan_min_y, origin.z), locate(scan_max_x, scan_max_y, origin.z)))
		if(!istype(scanned, /turf/cordon))
			continue
		log_shuttle("[name]: hull touches the reservation cordon after [context] - footprint ([scan_min_x],[scan_min_y]) to ([scan_max_x],[scan_max_y]) on z[origin.z], first cordon turf at ([scanned.x],[scanned.y]). The ship is likely sealed in and needs admin recovery.")
		message_admins("\[SHUTTLE]: [name] is touching the reservation cordon after [context] and is likely sealed in! [ADMIN_COORDJMP(origin)]")
		return

/**
 * Restores ship systems after crash landing
 */
/obj/structure/overmap/ship/proc/restore_ship_systems(list/machines)
	for(var/obj/machinery/M as anything in machines)
		if(QDELETED(M))
			continue
		M.set_machine_stat(M.machine_stat & ~EMPED)

	ship_notify("Emergency systems restored. Ship systems coming back online.", "SYSTEMS", SHIP_NOTIFY_NOTICE, 'voidcrew/sound/notify.ogg', 50)

/**
 * Throws all unanchored objects and mobs on the ship during a crash landing
 * Similar to lateShuttleMove but for crash impacts
 */
/obj/structure/overmap/ship/proc/crash_throw_contents(throwing_force = 20, throw_dir = WEST, message = "The ship crashes violently, throwing you across the room!")
	if(!shuttle?.shuttle_areas)
		return

	for(var/area/ship_area as anything in shuttle.shuttle_areas)
		for(var/atom/movable/AM in ship_area)
			if(QDELETED(AM))
				continue
			if(AM.anchored)
				continue
			// Skip intangible things like effects
			if(AM.pass_flags & PASSGLASS)
				continue

			// Mobs get extra effects
			if(isliving(AM))
				var/mob/living/L = AM
				shake_camera(L, 30, 5)
				if(message)
					to_chat(L, span_userdanger("[message]"))

			// Throw in the specified direction - based on lateShuttleMove logic
			var/turf/target = get_edge_target_turf(AM, throw_dir)
			var/range = throwing_force * 2
			range = CEILING(rand(range - 1, range + 1), 1)
			var/speed = max(range / 3, 1)
			AM.safe_throw_at(target, range, speed, force = MOVE_FORCE_EXTREMELY_STRONG)

/**
 * Called when the ship enters a tile - checks for hazards
 */
/obj/structure/overmap/ship/proc/check_hazards()
	for(var/obj/structure/overmap/event/hazard in loc)
		apply_hazard_effect(hazard)

/**
 * Applies the effect of a hazard to the ship
 */
/obj/structure/overmap/ship/proc/apply_hazard_effect(obj/structure/overmap/event/hazard)
	// Send signal that we've entered a hazard (decloaks ship, etc.)
	SEND_SIGNAL(src, COMSIG_SHIP_HAZARD_TRIGGERED, hazard)

	// A plotted course routes around storms, so ending up inside one means the
	// route was planned before we could see it. Hand the ship back rather than
	// fly deeper in. Nebulas are not a threat and don't count (ship_autopilot.dm).
	if(!istype(hazard, /obj/structure/overmap/event/nebula))
		interrupt_autopilot("[hazard.name] ahead")

	// Meteors always trigger per tile - no cooldown
	if(istype(hazard, /obj/structure/overmap/event/meteor))
		apply_meteor_damage(hazard)
		return

	// Other hazards have a cooldown to prevent spam
	if(!COOLDOWN_FINISHED(src, hazard_damage_cooldown))
		return

	COOLDOWN_START(src, hazard_damage_cooldown, 3 SECONDS)

	if(istype(hazard, /obj/structure/overmap/event/emp))
		apply_ion_storm_damage(hazard)
	else if(istype(hazard, /obj/structure/overmap/event/electric))
		apply_electrical_storm_damage(hazard)
	else if(istype(hazard, /obj/structure/overmap/event/nebula))
		apply_nebula_effect(hazard)

/// TRUE only for the length of an ion storm's EMP burst, which is a synchronous
/// loop of empulse() calls - nothing between the two writes below sleeps, so this
/// cannot be left raised or observed by an unrelated EMP. Read by the SMES
/// emp_act() override in voidcrew/edits/machinery/power.dm; see there for why the
/// SMES is treated differently from everything else the burst touches.
GLOBAL_VAR_INIT(ion_storm_pulse_active, FALSE)

/**
 * Ion Storm Effect
 * EMPs random areas of the ship - no direct hull damage, but EMP can destroy electronics
 * If turfs are destroyed, delta tracking will automatically update mass
 *
 * The front also takes the ship's velocity. Braking is a helm command, the helm is
 * a computer, and the burst below is about to take every computer in its radius
 * offline for a minute (see /obj/machinery/power/apc/emp_act) - so a ship that kept
 * its velocity here would coast on with no way to stop, taking a fresh burst on
 * every storm tile it crossed and ending up somewhere else entirely. Killing the
 * velocity is what makes a storm a place the crew can be rather than something that
 * happens to them on the way past; surveying one needs 60 uninterrupted seconds
 * parked on the tile (survey_computer.dm), which was otherwise unreachable.
 */
/obj/structure/overmap/ship/proc/apply_ion_storm_damage(obj/structure/overmap/event/emp/storm)
	var/intensity = storm.intensity
	var/emp_count = 2 + (intensity * 2)

	var/was_moving = !is_still()
	full_stop()

	if(was_moving)
		ship_notify("Ion front impact! Ship velocity lost. Electronic systems may be affected.", "HAZARD", SHIP_NOTIFY_WARNING, 'sound/effects/empulse.ogg', 50)
	else
		ship_notify("Ion storm interference detected! Electronic systems may be affected.", "HAZARD", SHIP_NOTIFY_WARNING, 'sound/effects/empulse.ogg', 50)

	// Create EMPs at random locations in the ship - these can destroy equipment
	GLOB.ion_storm_pulse_active = TRUE
	for(var/i in 1 to emp_count)
		var/turf/target = get_random_ship_turf()
		if(target)
			// empulse handles the visual effect when heavy_range > 1
			empulse(target, 2 * intensity, 4 * intensity)
			playsound(target, 'sound/effects/empulse.ogg', 50, TRUE)
	GLOB.ion_storm_pulse_active = FALSE

/**
 * Electrical Storm Effect
 * Overloads ship lighting fixtures and strikes the ship with real lightning bolts
 * Lights spark and shock nearby crew, while thunderbolts strike random locations
 */
/obj/structure/overmap/ship/proc/apply_electrical_storm_damage(obj/structure/overmap/event/electric/storm)
	var/intensity = storm.intensity

	ship_notify("Electrical storm detected! Lighting systems overloading!", "HAZARD", SHIP_NOTIFY_WARNING, 'sound/effects/sparks/sparks1.ogg', 50)

	// Silver lining: the charged atmosphere passively feeds the ship's power storage
	// Minor: 0.5x, Moderate: 1x, Majour: 2x (via intensity)
	var/charge_mult = intensity
	if(istype(storm, /obj/structure/overmap/event/electric/minor))
		charge_mult = ELECTRICAL_STORM_SMES_CHARGE_MULT_MINOR
	electrical_storm_charge_smes(charge_mult)

	// Spawn real lightning strikes - but not on minor storms
	// Minor: no lightning, Moderate: 1 strike (40% chance each), Major: 2-3 strikes
	if(!istype(storm, /obj/structure/overmap/event/electric/minor))
		var/lightning_count = intensity // 1 for moderate, 2 for major
		for(var/i in 1 to lightning_count)
			// Moderate storms have lower chance per bolt
			var/strike_chance = (intensity == 1) ? 40 : 100
			if(!prob(strike_chance))
				continue
			var/turf/strike_target = get_random_ship_turf()
			if(strike_target)
				// Stagger the strikes for dramatic effect
				addtimer(CALLBACK(src, PROC_REF(lightning_strike), strike_target), rand(0.5 SECONDS, 3 SECONDS))

	// Find all lights on the ship that are currently on
	var/list/ship_lights = list()
	for(var/area/ship_area as anything in shuttle.shuttle_areas)
		for(var/obj/machinery/light/light in ship_area)
			if(light.on)
				ship_lights += light

	if(!length(ship_lights))
		// No lights? Just do random sparks
		for(var/i in 1 to 3)
			var/turf/target = get_random_ship_turf()
			if(target)
				do_sparks(5, FALSE, target)
		return

	// Overload a number of lights based on intensity
	var/lights_to_overload = min(length(ship_lights), 3 + (intensity * 2))
	var/list/chosen_lights = list()

	for(var/i in 1 to lights_to_overload)
		if(!length(ship_lights))
			break
		chosen_lights += pick_n_take(ship_lights)

	// Make lights spark and schedule lightning strikes
	for(var/obj/machinery/light/light as anything in chosen_lights)
		light.visible_message(span_boldwarning("[light] suddenly flares brightly and begins to spark!"))
		var/datum/effect_system/spark_spread/light_sparks = new /datum/effect_system/spark_spread()
		light_sparks.set_up(4, 0, light)
		light_sparks.start()
		light.flicker(10)
		// Schedule the lightning strike from light
		addtimer(CALLBACK(src, PROC_REF(electrical_storm_shock), light, intensity), rand(1 SECONDS, 2 SECONDS))
	// Note: Mass updates are handled by delta tracking when turfs change

/**
 * Finds the grounding rod that should take a storm bolt aimed at target, or null if none does.
 *
 * A rod only counts if it is on THIS hull (its area is one of ours), on the same z, within
 * ELECTRICAL_STORM_ROD_RANGE of the strike, anchored, and buttoned up - the same two-state test
 * tesla_zap and supermatter_zap use before they hand an arc to a rod
 * (code/modules/power/tesla/coil.dm - grounding_rod/zap_act). An unwrenched rod or one with its
 * maintenance panel open does nothing, exactly as it does nothing against a tesla arc.
 * Nearest qualifying rod wins.
 */
/obj/structure/overmap/ship/proc/find_storm_grounding_rod(turf/target)
	if(!target)
		return null
	var/list/hull_areas = shuttle?.shuttle_areas
	if(!length(hull_areas))
		return null

	var/obj/machinery/power/energy_accumulator/grounding_rod/closest_rod
	var/closest_dist = ELECTRICAL_STORM_ROD_RANGE + 1
	for(var/obj/machinery/power/energy_accumulator/grounding_rod/rod in range(ELECTRICAL_STORM_ROD_RANGE, target))
		if(QDELETED(rod) || !rod.anchored || rod.panel_open)
			continue
		var/turf/rod_turf = get_turf(rod)
		if(!rod_turf || rod_turf.z != target.z)
			continue
		// range() does not care whose hull it crosses; this is what keeps a docked neighbour's
		// rod from covering us.
		if(!hull_areas[get_area(rod_turf)])
			continue
		var/rod_dist = get_dist(target, rod_turf)
		if(rod_dist >= closest_dist)
			continue
		closest_rod = rod
		closest_dist = rod_dist
	return closest_rod

/**
 * A grounding rod eats the bolt instead of the deck.
 *
 * Same thunderbolt visual and sound the unshielded strike uses, moved onto the rod, plus the
 * rod's own hit animation and energy bank via zap_act() - i.e. the bolt is absorbed exactly the
 * way a tesla arc landing on the rod would be. Nothing on the original turf is electrocuted,
 * damaged or exploded.
 */
/obj/structure/overmap/ship/proc/ground_lightning_strike(obj/machinery/power/energy_accumulator/grounding_rod/rod)
	var/turf/rod_turf = get_turf(rod)
	if(!rod_turf)
		return

	var/obj/effect/temp_visual/thunderbolt/thunder = new(rod_turf)
	thunder.flash_lighting_fx(6, 2, duration = thunder.duration)

	// grounding_rod/zap_act() flicks "grounding_rodhit", shocks anyone buckled to it and banks
	// the energy. It ignores zap_flags on the anchored/closed path, but pass the honest set.
	rod.zap_act(ELECTRICAL_STORM_ROD_BOLT_ENERGY, ZAP_DEFAULT_FLAGS)

	playsound(rod_turf, 'sound/effects/magic/lightningbolt.ogg', 100, extrarange = 10, falloff_distance = 10)
	rod_turf.visible_message(span_danger("A thunderbolt lances down and earths itself in [rod]!"))

/**
 * Spawns a real lightning bolt strike at the target turf
 * Same effect as rain storm thunder - visual, damage, explosion
 */
/obj/structure/overmap/ship/proc/lightning_strike(turf/target)
	if(!target)
		return

	// A grounding rod on this hull, within arc range of where the bolt was going, takes it
	// instead. Everything below - crew shock, object damage, explosion - is skipped for this bolt.
	var/obj/machinery/power/energy_accumulator/grounding_rod/rod = find_storm_grounding_rod(target)
	if(rod)
		ground_lightning_strike(rod)
		return

	// Create the thunderbolt visual effect
	var/obj/effect/temp_visual/thunderbolt/thunder = new(target)
	thunder.flash_lighting_fx(6, 2, duration = thunder.duration)

	// Electrocute anyone standing on the turf
	for(var/mob/living/hit_mob in target)
		to_chat(hit_mob, span_userdanger("You've been struck by lightning!"))
		hit_mob.electrocute_act(50, "lightning", flags = SHOCK_TESLA|SHOCK_NOGLOVES)

	// Damage objects on the turf
	for(var/obj/hit_thing in target)
		if(QDELETED(hit_thing))
			continue
		if(!hit_thing.uses_integrity)
			continue
		if(hit_thing.invisibility != INVISIBILITY_NONE)
			continue
		if(HAS_TRAIT(hit_thing, TRAIT_UNDERFLOOR))
			continue
		hit_thing.take_damage(20, BURN, ENERGY, FALSE)

	// Sound and message
	playsound(target, 'sound/effects/magic/lightningbolt.ogg', 100, extrarange = 10, falloff_distance = 10)
	target.visible_message(span_danger("A thunderbolt strikes [target]!"))

	// Small explosion and fire
	explosion(target, light_impact_range = 1, flame_range = 1, silent = TRUE, adminlog = FALSE)

/**
 * Called after delay - makes a light shoot lightning at nearby crew
 */
/obj/structure/overmap/ship/proc/electrical_storm_shock(obj/machinery/light/source_light, intensity)
	if(QDELETED(source_light))
		return

	// Chance for this light to actually discharge lightning
	// Minor/Moderate (intensity 1): 50% chance
	// Major (intensity 2): 75% chance
	if(!prob(25 + (intensity * 25)))
		return

	var/shock_range = 2 + intensity
	var/shock_damage = 10 + (intensity * 5)

	// Find and shock nearby crew
	for(var/mob/living/carbon/victim in view(shock_range, source_light))
		// Draw lightning beam
		source_light.Beam(victim, icon_state = "lightning[rand(1,12)]", time = 0.5 SECONDS)
		// Shock them
		victim.electrocute_act(shock_damage, source_light, flags = SHOCK_NOGLOVES)
		do_sparks(4, FALSE, victim)
		playsound(victim, 'sound/effects/magic/lightningshock.ogg', 50, TRUE)

	// Chance to break the light based on intensity
	if(prob(20 * intensity))
		source_light.break_light_tube()

/**
 * Electrical Storm Silver Lining
 * The storm's charged particles induce current in the ship's SMES units,
 * passively charging them - an upside to braving the storm.
 * charge_mult scales with storm severity. Capacity caps are respected by adjust_charge().
 */
/obj/structure/overmap/ship/proc/electrical_storm_charge_smes(charge_mult = 1)
	if(!shuttle?.shuttle_areas)
		return

	for(var/area/ship_area as anything in shuttle.shuttle_areas)
		for(var/obj/machinery/power/smes/unit in ship_area)
			if(QDELETED(unit) || (unit.machine_stat & (BROKEN | EMPED)))
				continue
			var/gained = unit.adjust_charge(ELECTRICAL_STORM_SMES_CHARGE * charge_mult)
			if(gained > 0)
				// Small visual telegraph that the storm is feeding the unit
				do_sparks(2, TRUE, unit)

/**
 * Meteor Storm Effect
 * Spawns a single meteor that crashes through the ship
 */
/obj/structure/overmap/ship/proc/apply_meteor_damage(obj/structure/overmap/event/meteor/storm)
	if(!shuttle)
		return

	var/meteor_type = /obj/effect/meteor/medium

	if(istype(storm, /obj/structure/overmap/event/meteor/majour))
		meteor_type = /obj/effect/meteor/big
	else if(istype(storm, /obj/structure/overmap/event/meteor/minor))
		meteor_type = /obj/effect/meteor

	// Spawn one meteor aimed at the ship
	// Note: Mass updates are handled by delta tracking when meteor destroys turfs
	spawn_meteor_at_ship(meteor_type)

/**
 * Spawns a single meteor just outside the hull, aimed at a random ship turf.
 * Shield walls will physically intercept the meteor if shields are active.
 *
 * Launching goes through the dynamic-events debris corridor (see
 * voidcrew/modules/dynamic_events/ship_debris.dm), which confines the rock to this
 * ship's own footprint. Rocks used to be spawned on the reservation edge with no
 * termination condition at all: one that missed kept flying for its full three-minute
 * lifetime, straight across the transit z-level and into whatever ship was parked next
 * to us, and on reaching the reservation's hard cordon was teleported onto a live
 * space z-level rather than deleted.
 */
/obj/structure/overmap/ship/proc/spawn_meteor_at_ship(meteor_type)
	return launch_ship_debris(meteor_type)

/**
 * Nebula Effect
 *
 * A little of the cloud seeps into the hull, and a tritium cloud doses the crew on the way
 * past. Nebulas still deal no hull damage - they are cover and fuel, not a storm.
 */
/obj/structure/overmap/ship/proc/apply_nebula_effect(obj/structure/overmap/event/nebula/cloud)
	// Seep a little of the cloud's own gas into the ship. This used to spawn plasma whatever
	// the nebula was made of, so flying through a tritium bank vented plasma into your air.
	var/turf/target = get_random_ship_turf()
	if(target && cloud?.gas_type && prob(30))
		var/datum/gas_mixture/air = target.return_air()
		if(air)
			air.assert_gas(cloud.gas_type)
			air.gases[cloud.gas_type][MOLES] += 0.5

	apply_nebula_radiation(cloud)

/**
 * Doses the crew for standing in a radioactive cloud.
 *
 * Only tritium clouds carry anything (GLOB.nebula_gas_radioactivity), and a radioactive
 * nebula shielder aboard cancels it - the machine's strength is subtracted from the cloud's,
 * so one working unit is enough for any of them. What goes out is an ordinary radiation
 * pulse, so rad-protective clothing and putting walls between yourself and the hull work the
 * way they always do. Self-throttling on NEBULA_RADIATION_INTERVAL, since this is called
 * both on flying into a cloud and on every tick a ram scoop is running inside one.
 *
 * Returns TRUE if a dose actually went out.
 */
/obj/structure/overmap/ship/proc/apply_nebula_radiation(obj/structure/overmap/event/nebula/cloud)
	var/intensity = GLOB.nebula_gas_radioactivity[cloud?.gas_type]
	if(!intensity)
		return FALSE
	if(!COOLDOWN_FINISHED(src, nebula_radiation_cooldown))
		return FALSE

	intensity -= get_nebula_shielding_level()
	if(intensity <= 0)
		// Spend the cooldown anyway: the shielders were polled, charged and paid out for it
		COOLDOWN_START(src, nebula_radiation_cooldown, NEBULA_RADIATION_INTERVAL)
		return FALSE

	var/turf/target = get_random_ship_turf()
	if(!target)
		return FALSE
	COOLDOWN_START(src, nebula_radiation_cooldown, NEBULA_RADIATION_INTERVAL)

	// Same dose profile a uranium airlock puts out: light, blocked by walls, beaten by
	// rad-protective clothing. It is a reason to fix the shielder, not an execution.
	radiation_pulse(target, max_range = 2 + intensity, threshold = RAD_LIGHT_INSULATION)
	ship_notify("Radiation alarm. The [cloud.get_gas_name()] cloud outside is dosing the hull.", "HAZARD", SHIP_NOTIFY_WARNING)
	return TRUE

/**
 * How much nebula shielding this hull is running.
 *
 * Walks the ship's own areas rather than its z-level, because every ship z is a station
 * level here and a z check would let a docked neighbour's shielder cover us. Polling a
 * shielder is also what makes it draw power and vent its tritium, so this is called on a
 * cadence (see apply_nebula_radiation) rather than every tick.
 */
/obj/structure/overmap/ship/proc/get_nebula_shielding_level()
	var/shielding = 0
	for(var/obj/machinery/nebula_shielding/shielder as anything in get_ship_machines(/obj/machinery/nebula_shielding))
		// A shielder that is unpowered, broken or open returns null rather than 0
		shielding += (shielder.get_nebula_shielding() || 0)
	return shielding

/**
 * Gets a random turf inside the ship for targeting effects
 * Uses direct area iteration instead of get_area_turfs() to avoid
 * returning turfs from other ships with the same area types
 */
/obj/structure/overmap/ship/proc/get_random_ship_turf()
	if(!shuttle?.shuttle_areas?.len)
		return null

	// Collect all turfs from this ship's areas only
	// We iterate through the area contents directly, not by area type
	var/list/all_turfs = list()
	for(var/area/ship_area as anything in shuttle.shuttle_areas)
		for(var/turf/T in ship_area)
			all_turfs += T

	if(!length(all_turfs))
		return null

	return pick(all_turfs)

/**
 * Gets all living mobs currently on the ship
 * First checks registered crew members, then falls back to checking shuttle areas
 */
/obj/structure/overmap/ship/proc/get_all_ship_mobs()
	var/list/mobs = list()

	// First get registered crew members
	if(ship_team?.members?.len)
		for(var/datum/mind/shipmate as anything in ship_team.members)
			var/mob/living/crewmate = shipmate.current
			if(!crewmate || !isliving(crewmate))
				continue
			mobs += crewmate

	// Also check shuttle areas for any mobs not in the team (visitors, etc)
	if(shuttle?.shuttle_areas?.len)
		for(var/area/ship_area as anything in shuttle.shuttle_areas)
			for(var/mob/living/crew in ship_area)
				if(!(crew in mobs))
					mobs += crew

	return mobs

/**
 * Plays a sound to all mobs on the ship
 */
/obj/structure/overmap/ship/proc/play_ship_sound(sound_file, volume = 50)
	for(var/mob/living/crew in get_all_ship_mobs())
		SEND_SOUND(crew, sound(sound_file, volume = volume))

/**
 * Shakes the camera for all mobs on the ship
 * @param duration - How long to shake (in ticks)
 * @param strength - How intense the shake is
 */
/obj/structure/overmap/ship/proc/shake_ship(duration = 10, strength = 2)
	for(var/mob/living/crew in get_all_ship_mobs())
		shake_camera(crew, duration, strength)

/**
 * Plays a sequence of VOX words to all mobs on the ship
 * @param words - List of words to play in sequence
 */
/obj/structure/overmap/ship/proc/play_ship_vox(list/words)
	var/delay = 0
	for(var/word in words)
		addtimer(CALLBACK(src, PROC_REF(play_vox_word_to_ship), word), delay)
		delay += 0.5 SECONDS // Small delay between words

/**
 * Plays a single VOX word to all mobs on the ship
 */
/obj/structure/overmap/ship/proc/play_vox_word_to_ship(word)
	word = LOWER_TEXT(word)
	if(!GLOB.vox_sounds[word])
		return FALSE

	if(!ship_team)
		return FALSE

	if(!ship_team.members?.len)
		return FALSE

	var/sound_file = GLOB.vox_sounds[word]

	for(var/datum/mind/shipmate as anything in ship_team.members)
		var/mob/living/crew = shipmate.current
		if(!crew)
			continue
		if(!crew.client)
			continue
		if(!crew.can_hear())
			continue
		// Default to 50 if preference not set
		var/pref_volume = safe_read_pref(crew.client, /datum/preference/numeric/volume/sound_ai_vox) || 50
		var/sound/voice = sound(sound_file, wait = 1, channel = CHANNEL_VOX, volume = pref_volume)
		voice.status = SOUND_STREAM
		SEND_SOUND(crew, voice)
	return TRUE
