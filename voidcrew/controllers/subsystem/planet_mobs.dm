/**
 * # Planet Mob Manager Subsystem
 *
 * Manages mob spawning/despawning on planets based on player presence.
 * Instead of spawning all planet mobs at round start, this subsystem:
 * 1. Collects valid spawn turfs during terrain generation
 * 2. Spawns mobs when players arrive on a planet
 * 3. Despawns mobs after players leave (with a grace period)
 */
SUBSYSTEM_DEF(planet_mobs)
	name = "Planet Mobs"
	init_order = INIT_ORDER_PLANET_MOBS
	wait = 10 SECONDS
	flags = SS_BACKGROUND | SS_POST_FIRE_TIMING | SS_NO_INIT
	priority = FIRE_PRIORITY_PLANET_MOBS
	runlevels = RUNLEVEL_GAME | RUNLEVEL_POSTGAME

	/// Max mobs across ALL planets
	var/global_mob_cap = 150
	/// Max mobs per z-level (surface and cave each get this many)
	var/per_zlevel_mob_cap = 15
	/// Time after players leave before despawning
	var/despawn_grace_period = 3 MINUTES

	/// planet_name -> /datum/planet_mob_tracker
	var/list/tracked_planets = list()
	/// z-level number (as string) -> planet_name (lookup helper)
	var/list/z_to_planet = list()
	/// Running total of managed mobs
	var/total_managed_mobs = 0
	/// Cache of biome type -> filtered mob spawn list (excluding structure spawners and megafauna sentinel)
	var/list/filtered_mob_cache = list()

/**
 * Tracks mob spawning state for a single planet (surface + cave z-levels).
 */
/datum/planet_mob_tracker
	/// Planet identifier (e.g. "lava 1")
	var/name
	/// Surface z-level number
	var/surface_z = 0
	/// Cave z-level number
	var/cave_z = 0
	/// Pre-indexed candidate turfs for surface mob spawning
	var/list/surface_spawn_turfs = list()
	/// Pre-indexed candidate turfs for cave mob spawning
	var/list/cave_spawn_turfs = list()
	/// Whether mobs currently exist on this planet
	var/populated = FALSE
	/// Whether players are currently present
	var/has_players = FALSE
	/// world.time when players last left (0 = players haven't left)
	var/player_left_time = 0

/**
 * Build planet trackers from SSmapping.planets data.
 * Called from loadWorld() after all planet z-levels are created.
 */
/datum/controller/subsystem/planet_mobs/proc/setup_tracking()
	for(var/planet_name in SSmapping.planets)
		var/list/planet_data = SSmapping.planets[planet_name]
		var/datum/planet_mob_tracker/tracker = new
		tracker.name = planet_name
		tracker.surface_z = planet_data["z"]
		tracker.cave_z = planet_data["cave_z"]
		tracked_planets[planet_name] = tracker
		z_to_planet["[tracker.surface_z]"] = planet_name
		z_to_planet["[tracker.cave_z]"] = planet_name

/**
 * Register a turf as a valid mob spawn point.
 * Called from populate_terrain() instead of immediately spawning mobs.
 */
/datum/controller/subsystem/planet_mobs/proc/register_spawn_turf(turf/T)
	var/planet_name = z_to_planet["[T.z]"]
	if(!planet_name)
		return
	var/datum/planet_mob_tracker/tracker = tracked_planets[planet_name]
	if(!tracker)
		return
	if(T.z == tracker.surface_z)
		tracker.surface_spawn_turfs += T
	else
		tracker.cave_spawn_turfs += T

/datum/controller/subsystem/planet_mobs/fire(resumed)
	for(var/planet_name in tracked_planets)
		var/datum/planet_mob_tracker/tracker = tracked_planets[planet_name]

		// Check player presence on either z-level
		var/players_present = check_players(tracker)

		if(players_present)
			tracker.has_players = TRUE
			tracker.player_left_time = 0
			if(!tracker.populated)
				spawn_planet_mobs(tracker)
		else
			if(tracker.has_players)
				// Players just left - start grace period
				tracker.has_players = FALSE
				tracker.player_left_time = world.time
			if(tracker.populated && tracker.player_left_time && (world.time - tracker.player_left_time >= despawn_grace_period))
				despawn_planet_mobs(tracker)

/**
 * Check if any player clients are on the planet's z-levels.
 */
/datum/controller/subsystem/planet_mobs/proc/check_players(datum/planet_mob_tracker/tracker)
	if(!islist(SSmobs.clients_by_zlevel))
		return FALSE
	if(tracker.surface_z <= length(SSmobs.clients_by_zlevel) && length(SSmobs.clients_by_zlevel[tracker.surface_z]))
		return TRUE
	if(tracker.cave_z <= length(SSmobs.clients_by_zlevel) && length(SSmobs.clients_by_zlevel[tracker.cave_z]))
		return TRUE
	return FALSE

/**
 * Spawn mobs on a planet by picking from pre-indexed spawn turfs.
 * Spawns up to per_zlevel_mob_cap on each z-level (surface and cave separately).
 */
/datum/controller/subsystem/planet_mobs/proc/spawn_planet_mobs(datum/planet_mob_tracker/tracker)
	spawn_on_zlevel(tracker.surface_spawn_turfs)
	spawn_on_zlevel(tracker.cave_spawn_turfs)
	tracker.populated = TRUE

/**
 * Spawn mobs on a single z-level from the given turf list.
 */
/datum/controller/subsystem/planet_mobs/proc/spawn_on_zlevel(list/spawn_turfs)
	if(!length(spawn_turfs))
		return

	var/spawned = 0
	var/list/available_turfs = spawn_turfs.Copy()

	while(spawned < per_zlevel_mob_cap && total_managed_mobs < global_mob_cap && length(available_turfs))
		var/turf/T = pick_n_take(available_turfs)
		if(!isturf(T))
			continue

		var/datum/biome/biome = T.generating_biome
		if(!biome?.mob_spawn_list || !length(biome.mob_spawn_list))
			continue

		// Get filtered mob list (no structure spawners or megafauna sentinel)
		var/list/mob_list = get_filtered_mob_list(biome)
		if(!length(mob_list))
			continue

		var/mob_type = pickweight(mob_list)
		if(!mob_type)
			continue

		new mob_type(T)
		spawned++
		total_managed_mobs++

/**
 * Get a biome's mob_spawn_list filtered to exclude /obj/structure/spawner paths
 * and the SPAWN_MEGAFAUNA sentinel. Results are cached per biome type.
 */
/datum/controller/subsystem/planet_mobs/proc/get_filtered_mob_list(datum/biome/biome)
	if(filtered_mob_cache[biome.type])
		return filtered_mob_cache[biome.type]

	var/list/filtered = list()
	for(var/entry in biome.mob_spawn_list)
		if(entry == SPAWN_MEGAFAUNA)
			continue
		if(ispath(entry, /obj/structure/spawner))
			continue
		filtered[entry] = biome.mob_spawn_list[entry]

	filtered_mob_cache[biome.type] = filtered
	return filtered

/**
 * Despawn managed mobs on a planet after the grace period.
 * Skips player mobs, dead mobs, megafauna, and mobs in containers.
 */
/datum/controller/subsystem/planet_mobs/proc/despawn_planet_mobs(datum/planet_mob_tracker/tracker)
	// Double-check no players arrived during the grace period
	if(check_players(tracker))
		tracker.has_players = TRUE
		tracker.player_left_time = 0
		return

	var/despawned = 0
	for(var/mob/living/L as anything in GLOB.mob_living_list)
		if(L.z != tracker.surface_z && L.z != tracker.cave_z)
			continue
		if(!can_despawn(L))
			continue
		qdel(L)
		despawned++
		CHECK_TICK

	total_managed_mobs = max(0, total_managed_mobs - despawned)
	tracker.populated = FALSE
	tracker.player_left_time = 0

/**
 * Check if a mob is eligible for despawning.
 */
/datum/controller/subsystem/planet_mobs/proc/can_despawn(mob/living/L)
	if(L.ckey)
		return FALSE
	if(L.mind)
		return FALSE
	if(L.stat == DEAD)
		return FALSE
	if(!isturf(L.loc))
		return FALSE
	if(istype(L, /mob/living/simple_animal/hostile/megafauna))
		return FALSE
	return TRUE

/**
 * Resets spawn turf lists for a planet so regeneration can re-register new turfs.
 * Called during planet recycling before RunTerrainPopulation() re-registers turfs.
 */
/datum/controller/subsystem/planet_mobs/proc/rebuild_planet_spawn_turfs(planet_name)
	var/datum/planet_mob_tracker/tracker = tracked_planets[planet_name]
	if(!tracker)
		return
	tracker.surface_spawn_turfs = list()
	tracker.cave_spawn_turfs = list()
	tracker.populated = FALSE
	tracker.has_players = FALSE
	tracker.player_left_time = 0

/datum/controller/subsystem/planet_mobs/stat_entry(msg)
	var/active = 0
	var/total_alive = 0
	for(var/planet_name in tracked_planets)
		var/datum/planet_mob_tracker/tracker = tracked_planets[planet_name]
		if(tracker.populated)
			active++
			total_alive += count_planet_mobs(tracker)
	msg = "Alive:[total_alive] Spawned:[total_managed_mobs]/[global_mob_cap] Planets:[active]/[length(tracked_planets)]"
	return ..()

/**
 * Count actual living mobs on a planet's z-levels (surface + cave).
 * Only counts mobs that would be eligible for despawning (i.e. managed mobs).
 */
/datum/controller/subsystem/planet_mobs/proc/count_planet_mobs(datum/planet_mob_tracker/tracker)
	var/count = 0
	for(var/mob/living/L as anything in GLOB.mob_living_list)
		if(L.z != tracker.surface_z && L.z != tracker.cave_z)
			continue
		if(!can_despawn(L))
			continue
		count++
	return count
