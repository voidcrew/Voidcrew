/**
 * NPC Combat Interface - Wraps ship weapons for AI control
 *
 * This datum provides a simplified interface for NPC ships to fire weapons
 * without needing to track inventories or use the combat console UI.
 * Weapons are found automatically from the ship's shuttle areas.
 */
/datum/npc_combat_interface
	/// Reference to the NPC ship we're attached to
	var/obj/structure/overmap/ship/npc/owner_ship

	/// List of laser turrets on this ship
	var/list/obj/machinery/ship_combat/laser_turret/linked_laser_turrets = list()

	/// List of missile launchers on this ship
	var/list/obj/machinery/ship_combat/missile_launcher/linked_missile_launchers = list()

	/// The interdictor on this ship (if any)
	var/obj/machinery/ship_combat/interdictor/linked_interdictor

	/// The cloaking device on this ship (if any)
	var/obj/machinery/ship_combat/cloak_device/linked_cloak_device

	/// Default missile type for this NPC (light, standard, heavy)
	var/default_missile_type = "standard"

	/// TRUE once this ship has ever scanned in an intact weapon. Disarmament checks
	/// (pool reconcile) key on this so a hypothetical template mapped with no weapons
	/// at all reads as "never armed", not "disarmed" - otherwise it would resolve its
	/// pool slot at birth and churn the spawner in a loop.
	var/ever_had_weapons = FALSE

/datum/npc_combat_interface/Destroy()
	owner_ship = null
	linked_laser_turrets.Cut()
	linked_missile_launchers.Cut()
	linked_interdictor = null
	linked_cloak_device = null
	return ..()

/**
 * Initializes the combat interface by finding all weapons on the given ship.
 */
/datum/npc_combat_interface/proc/initialize_from_ship(obj/structure/overmap/ship/npc/ship)
	if(!ship)
		return FALSE

	owner_ship = ship

	if(!ship.shuttle?.shuttle_areas)
		return FALSE

	// Search all ship areas for combat equipment
	for(var/area/ship_area as anything in ship.shuttle.shuttle_areas)
		for(var/obj/machinery/ship_combat/equipment in ship_area)
			track_weapon(equipment)
			if(istype(equipment, /obj/machinery/ship_combat/laser_turret))
				linked_laser_turrets += equipment
				max_out_turret(equipment)
			else if(istype(equipment, /obj/machinery/ship_combat/missile_launcher))
				linked_missile_launchers += equipment
			else if(istype(equipment, /obj/machinery/ship_combat/interdictor))
				linked_interdictor = equipment
			else if(istype(equipment, /obj/machinery/ship_combat/cloak_device))
				linked_cloak_device = equipment

	// Pre-load all missile launchers with virtual missiles
	load_all_launchers()

	if(length(linked_laser_turrets) || length(linked_missile_launchers))
		ever_had_weapons = TRUE

	return TRUE

/**
 * Tracks a scanned weapon so the hard ref drops the moment it deletes. The hull's
 * machines are torn down one by one (intoTheSunset, clear_reservation) while this
 * datum survives on the overmap token - an unpruned entry hard-deletes the weapon.
 */
/datum/npc_combat_interface/proc/track_weapon(obj/machinery/ship_combat/equipment)
	RegisterSignal(equipment, COMSIG_QDELETING, PROC_REF(on_weapon_deleted), override = TRUE)

/datum/npc_combat_interface/proc/on_weapon_deleted(datum/source)
	SIGNAL_HANDLER
	linked_laser_turrets -= source
	linked_missile_launchers -= source
	if(linked_interdictor == source)
		linked_interdictor = null
	if(linked_cloak_device == source)
		linked_cloak_device = null

/**
 * Rescans the ship for weapons. Use this after adding equipment post-spawn.
 */
/datum/npc_combat_interface/proc/rescan_weapons()
	if(!owner_ship?.shuttle?.shuttle_areas)
		return FALSE

	// Clear existing lists
	linked_laser_turrets.Cut()
	linked_missile_launchers.Cut()
	linked_interdictor = null
	linked_cloak_device = null

	// Re-scan all ship areas
	for(var/area/ship_area as anything in owner_ship.shuttle.shuttle_areas)
		for(var/obj/machinery/ship_combat/equipment in ship_area)
			track_weapon(equipment)
			if(istype(equipment, /obj/machinery/ship_combat/laser_turret))
				linked_laser_turrets += equipment
				max_out_turret(equipment)
			else if(istype(equipment, /obj/machinery/ship_combat/missile_launcher))
				linked_missile_launchers += equipment
			else if(istype(equipment, /obj/machinery/ship_combat/interdictor))
				linked_interdictor = equipment
			else if(istype(equipment, /obj/machinery/ship_combat/cloak_device))
				linked_cloak_device = equipment

	// Re-load all missile launchers
	load_all_launchers()

	if(length(linked_laser_turrets) || length(linked_missile_launchers))
		ever_had_weapons = TRUE

	return TRUE

/**
 * Brings an NPC turret up to maximum specification: tier 4 stock parts and full power
 * level. Pirate hulls map bare turrets, so every NPC in the galaxy otherwise fires the
 * same tier-1 50-damage shot regardless of how dangerous its class is meant to be.
 *
 * Tier 4 micro-lasers take the turret to 125 damage (the board wants two of them), and
 * LASER_POWER_MAX doubles that again. Servos only shorten the turret's own cooldown,
 * which sits well under the AI's laser_cooldown_time gate, so cadence is unchanged.
 */
/datum/npc_combat_interface/proc/max_out_turret(obj/machinery/ship_combat/laser_turret/turret)
	if(QDELETED(turret))
		return

	// Rebuilt rather than edited in place: the board asks for two micro-lasers and both
	// entries are the same singleton datum, so removing "the" old part is ambiguous.
	var/list/upgraded_parts = list()
	for(var/part in turret.component_parts)
		if(istype(part, /datum/stock_part/micro_laser))
			upgraded_parts += GLOB.stock_part_datums[/datum/stock_part/micro_laser/tier4]
		else if(istype(part, /datum/stock_part/capacitor))
			upgraded_parts += GLOB.stock_part_datums[/datum/stock_part/capacitor/tier4]
		else if(istype(part, /datum/stock_part/servo))
			upgraded_parts += GLOB.stock_part_datums[/datum/stock_part/servo/tier4]
		else
			upgraded_parts += part  // the power cell is a physical obj - keep it
	turret.component_parts = upgraded_parts

	turret.RefreshParts()
	turret.set_power_level(LASER_POWER_MAX)

	// The cell, not the APC, is what actually paces an NPC: it trickles back at
	// charge_rate while a maxed shot costs thousands, so a pirate would fire an opening
	// burst and then go quiet for as long as the refill takes. Same infinite-ammo
	// treatment the missile launchers already get.
	turret.infinite_power = TRUE
	turret.update_appearance()

// ========== VIRTUAL MISSILE SYSTEM ==========

/**
 * Generates virtual missile data matching the format used by real missiles.
 * This allows NPCs to use the standard launcher.fire() code path.
 */
/datum/npc_combat_interface/proc/get_virtual_missile_data(missile_type = "standard")
	var/list/data = list()

	switch(missile_type)
		if("light")
			data = list(
				"effect_type" = /obj/effect/ship_missile,
				"payload_type" = "light",
				"damage" = MISSILE_DAMAGE_LIGHT,
				"devastation" = 1,
				"heavy" = 2,
				"light" = 3,
				"flame" = 1,
				"icon_state" = "smissile",
			)
		if("heavy")
			data = list(
				"effect_type" = /obj/effect/ship_missile,
				"payload_type" = "heavy",
				"damage" = MISSILE_DAMAGE_HEAVY,
				"devastation" = 3,
				"heavy" = 5,
				"light" = 7,
				"flame" = 4,
				"icon_state" = "missile",
			)
		else // standard
			data = list(
				"effect_type" = /obj/effect/ship_missile,
				"payload_type" = "standard",
				"damage" = MISSILE_DAMAGE_STANDARD,
				"devastation" = 2,
				"heavy" = 3,
				"light" = 5,
				"flame" = 3,
				"icon_state" = "missile",
			)

	return data

/**
 * Loads all missile launchers with virtual missiles.
 */
/datum/npc_combat_interface/proc/load_all_launchers(missile_type)
	if(!missile_type)
		missile_type = default_missile_type

	var/list/missile_data = get_virtual_missile_data(missile_type)

	for(var/obj/machinery/ship_combat/missile_launcher/launcher as anything in linked_missile_launchers)
		if(QDELETED(launcher))
			continue
		load_launcher(launcher, missile_data)

/**
 * Loads a single launcher with virtual missile data.
 */
/datum/npc_combat_interface/proc/load_launcher(obj/machinery/ship_combat/missile_launcher/launcher, list/missile_data)
	if(!launcher || !missile_data)
		return FALSE

	// Set the loaded missile data (same format as real missiles use)
	launcher.loaded_missile = missile_data.Copy()
	launcher.update_appearance()
	return TRUE

// ========== WEAPON COUNTING ==========

/**
 * Returns the number of functional laser turrets.
 */
/datum/npc_combat_interface/proc/get_working_laser_count()
	var/count = 0
	for(var/obj/machinery/ship_combat/laser_turret/turret as anything in linked_laser_turrets)
		if(QDELETED(turret))
			continue
		if(turret.can_fire())
			count++
	return count

/**
 * Returns the number of functional missile launchers that are loaded.
 */
/datum/npc_combat_interface/proc/get_working_launcher_count()
	var/count = 0
	for(var/obj/machinery/ship_combat/missile_launcher/launcher as anything in linked_missile_launchers)
		if(QDELETED(launcher))
			continue
		if(launcher.machine_stat & (BROKEN|NOPOWER))
			continue
		if(!launcher.anchored)
			continue
		if(!launcher.is_on_exterior())
			continue
		// Check if loaded (we auto-reload, but check anyway)
		if(!launcher.loaded_missile)
			continue
		count++
	return count

/**
 * Returns whether we have a working interdictor.
 */
/datum/npc_combat_interface/proc/has_working_interdictor()
	if(QDELETED(linked_interdictor))
		return FALSE
	return linked_interdictor.can_interdict()

/**
 * Returns whether we have ANY working weapons (lasers OR missiles).
 * Used to determine if the ship should retreat.
 */
/datum/npc_combat_interface/proc/has_any_weapons()
	return get_working_laser_count() > 0 || get_working_launcher_count() > 0

/**
 * Returns whether the ship still physically HAS weapons - an intact turret or launcher
 * aboard, regardless of whether it could fire this instant. Deliberately cheaper and
 * dumber than has_any_weapons(): can_fire() folds in fire cooldowns, power and the
 * zone's weapons_allowed check, so a fully-armed ship reads as weaponless while its
 * turrets cycle or whenever it sits in a band that forbids firing. A ship that fled
 * on destroyed guns must never read as re-armed, and an armed ship idling in a yellow
 * band must never read as disarmed - both of those bugs loop the AI.
 */
/datum/npc_combat_interface/proc/has_intact_weapons()
	for(var/obj/machinery/ship_combat/laser_turret/turret as anything in linked_laser_turrets)
		if(QDELETED(turret))
			continue
		if(turret.machine_stat & BROKEN)
			continue
		return TRUE
	for(var/obj/machinery/ship_combat/missile_launcher/launcher as anything in linked_missile_launchers)
		if(QDELETED(launcher))
			continue
		if(launcher.machine_stat & BROKEN)
			continue
		return TRUE
	return FALSE

/**
 * Returns whether we have a working cloak device that can activate.
 */
/datum/npc_combat_interface/proc/has_working_cloak()
	if(QDELETED(linked_cloak_device))
		return FALSE
	return linked_cloak_device.can_activate_cloak()

/**
 * Attempts to activate the cloak device.
 * Returns TRUE if cloak was activated.
 */
/datum/npc_combat_interface/proc/activate_cloak()
	if(!has_working_cloak())
		return FALSE
	return linked_cloak_device.activate_cloak()

// ========== FIRING WEAPONS ==========

/**
 * Fires lasers at the target ship.
 * Returns TRUE if at least one laser was fired.
 *
 * Arguments:
 * * target_ship - The ship to fire at
 * * fire_all - If TRUE, fires all available lasers. If FALSE, fires one laser.
 */
/datum/npc_combat_interface/proc/fire_lasers(obj/structure/overmap/ship/target_ship, fire_all = FALSE)
	if(!target_ship || !owner_ship)
		return FALSE

	// Get a random target turf on the enemy ship
	var/turf/target_turf = get_random_target_turf(target_ship)
	if(!target_turf)
		return FALSE

	// Clean up destroyed turrets
	for(var/obj/machinery/ship_combat/laser_turret/turret as anything in linked_laser_turrets)
		if(QDELETED(turret))
			linked_laser_turrets -= turret

	var/fired_any = FALSE

	if(fire_all)
		// Fire all available lasers
		for(var/obj/machinery/ship_combat/laser_turret/turret as anything in linked_laser_turrets)
			if(turret.can_fire())
				// Get new random target turf for each laser for spread effect
				var/turf/laser_target = get_random_target_turf(target_ship)
				if(turret.fire(laser_target, target_ship, owner_ship, null))
					fired_any = TRUE
	else
		// Fire a single random laser
		var/list/available_turrets = list()
		for(var/obj/machinery/ship_combat/laser_turret/turret as anything in linked_laser_turrets)
			if(turret.can_fire())
				available_turrets += turret

		if(length(available_turrets))
			var/obj/machinery/ship_combat/laser_turret/chosen = pick(available_turrets)
			if(chosen.fire(target_turf, target_ship, owner_ship, null))
				fired_any = TRUE

	return fired_any

/**
 * Fires a missile at the target ship using the standard launcher fire code.
 * NPCs have infinite ammo - launchers are auto-reloaded after each shot.
 * Returns TRUE if a missile was fired.
 *
 * Arguments:
 * * target_ship - The ship to fire at
 * * missile_type - Optional: "light", "standard", or "heavy". Uses default if not specified.
 */
/datum/npc_combat_interface/proc/fire_missile(obj/structure/overmap/ship/target_ship, missile_type)
	if(!target_ship || !owner_ship)
		return FALSE

	if(!missile_type)
		missile_type = default_missile_type

	// Clean up destroyed launchers and find one to fire
	var/obj/machinery/ship_combat/missile_launcher/chosen_launcher
	for(var/obj/machinery/ship_combat/missile_launcher/launcher as anything in linked_missile_launchers)
		if(QDELETED(launcher))
			linked_missile_launchers -= launcher
			continue
		if(launcher.machine_stat & (BROKEN|NOPOWER))
			continue
		if(!launcher.anchored)
			continue
		if(!launcher.is_on_exterior())
			continue
		// Ensure it's loaded
		if(!launcher.loaded_missile)
			load_launcher(launcher, get_virtual_missile_data(missile_type))
		chosen_launcher = launcher
		break

	if(!chosen_launcher)
		return FALSE

	// Get a random target turf on the enemy ship
	var/turf/target_turf = get_random_target_turf(target_ship)
	if(!target_turf)
		return FALSE

	// Fire using the standard launcher code path
	// This ensures identical visuals and behavior to player missiles
	var/success = chosen_launcher.fire(target_turf, target_ship, owner_ship, null)

	if(success)
		// Signal weapon fired (breaks cloak)
		SEND_SIGNAL(owner_ship, COMSIG_SHIP_WEAPON_FIRED)
		// Auto-reload for next shot (infinite ammo for NPCs)
		load_launcher(chosen_launcher, get_virtual_missile_data(missile_type))

	return success

/**
 * Starts interdiction on the target ship.
 * Returns TRUE if interdiction started successfully.
 */
/datum/npc_combat_interface/proc/start_interdiction(obj/structure/overmap/ship/target_ship)
	if(!target_ship)
		return FALSE

	if(QDELETED(linked_interdictor))
		return FALSE

	return linked_interdictor.start_interdiction(target_ship, null)

/**
 * Cancels any active interdiction.
 */
/datum/npc_combat_interface/proc/cancel_interdiction()
	if(QDELETED(linked_interdictor))
		return
	if(linked_interdictor.interdiction_active || linked_interdictor.interdiction_warming_up)
		linked_interdictor.cancel_interdiction("Target lost!")

// ========== BOARDING PODS ==========

/**
 * Fires boarding pods at the target ship, delivering hostile mobs.
 * Uses the supplypod system for dramatic drop-from-above delivery.
 * Returns TRUE if at least one pod was launched.
 *
 * Arguments:
 * * target_ship - The ship to board
 * * pod_count - Number of pods to launch (1-5)
 * * mob_types - List of mob types to spawn in pods (uses ship's configured types if null)
 */
/datum/npc_combat_interface/proc/fire_boarding_pods(obj/structure/overmap/ship/target_ship, pod_count = 1, list/mob_types = null)
	if(QDELETED(target_ship) || QDELETED(owner_ship))
		return FALSE
	if(target_ship.state != OVERMAP_SHIP_FLYING || owner_ship.state != OVERMAP_SHIP_FLYING)
		return FALSE

	// Clamp pod count
	pod_count = clamp(pod_count, 1, 5)

	// Get mob types to spawn - use ship's configured types if not provided
	var/list/spawn_types = mob_types
	if(!spawn_types || !length(spawn_types))
		var/obj/structure/overmap/ship/npc/pirate/pirate_ship = owner_ship
		if(istype(pirate_ship))
			// Use boarding pod specific types, or fall back to crew types
			if(length(pirate_ship.boarding_pod_mob_types))
				spawn_types = pirate_ship.boarding_pod_mob_types.Copy()
			else if(length(pirate_ship.crew_types))
				spawn_types = pirate_ship.crew_types.Copy()

	if(!spawn_types || !length(spawn_types))
		return FALSE

	// Set up patrol distribution for this wave
	GLOB.boarding_spawn_index = 0
	GLOB.boarding_spawn_total = pod_count

	var/pods_launched = 0

	// Launch pods at different locations on the target ship
	for(var/i in 1 to pod_count)
		var/turf/target_turf = get_random_target_turf(target_ship)
		if(!target_turf)
			continue

		// Pick a random mob type for this pod
		var/mob_type = pick(spawn_types)

		// Create the boarding pod with a slight delay between launches
		// Uses supplypod system - pod falls from above, lands, opens to reveal mob
		var/launch_delay = (i - 1) * 0.5 SECONDS
		addtimer(CALLBACK(GLOBAL_PROC, GLOBAL_PROC_REF(create_boarding_pod), target_turf, target_ship, owner_ship, mob_type), launch_delay)
		pods_launched++

	if(pods_launched > 0)
		// Signal weapon fired (breaks cloak)
		SEND_SIGNAL(owner_ship, COMSIG_SHIP_WEAPON_FIRED)
		// Notify our ship
		owner_ship.ship_notify("Launching [pods_launched] boarding pod[pods_launched > 1 ? "s" : ""]!", "TACTICAL", SHIP_NOTIFY_NOTICE)

	return pods_launched > 0

// ========== UTILITY ==========

/**
 * Gets a random valid turf on the target ship for weapon targeting.
 */
/datum/npc_combat_interface/proc/get_random_target_turf(obj/structure/overmap/ship/target_ship)
	if(!target_ship?.shuttle?.shuttle_areas)
		return null

	var/list/valid_turfs = list()
	for(var/area/ship_area as anything in target_ship.shuttle.shuttle_areas)
		for(var/turf/T in ship_area)
			if(!isspaceturf(T))
				valid_turfs += T

	if(!length(valid_turfs))
		return null

	return pick(valid_turfs)
