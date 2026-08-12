/**
 * # Planet Mob Manager Subsystem
 *
 * Keeps planet fauna tied to player presence instead of leaving it standing around for
 * the whole round. Terrain population doesn't spawn ordinary mobs any more - it registers
 * the turfs they would have used (see planet_generator/populate_terrain). This subsystem
 * then:
 *
 * 1. spawns mobs on those turfs when a player arrives on the planet,
 * 2. despawns them again once the planet has been empty for the grace period.
 *
 * Planets register themselves as they load and unregister as they unload, so a planet
 * nobody has visited costs nothing here.
 *
 * Structure spawners and megafauna are deliberately NOT managed - they are terrain, and
 * deleting a tendril or a colossus out from under the round would be its own bug.
 */
SUBSYSTEM_DEF(planet_mobs)
	name = "Planet Mobs"
	init_order = INIT_ORDER_PLANET_MOBS
	wait = 10 SECONDS
	flags = SS_BACKGROUND | SS_POST_FIRE_TIMING | SS_NO_INIT
	priority = FIRE_PRIORITY_PLANET_MOBS
	runlevels = RUNLEVEL_GAME | RUNLEVEL_POSTGAME

	/// Max managed mobs across ALL planets
	var/global_mob_cap = 150
	/// Max managed mobs on any one planet
	var/per_zlevel_mob_cap = 15
	/// How long a planet must sit empty before its fauna is cleared out
	var/despawn_grace_period = 3 MINUTES

	/// planet key -> /datum/planet_mob_tracker
	var/list/tracked_planets = list()
	/// z-level number (as text) -> planet key
	var/list/z_to_planet = list()
	/// Running total of managed mobs
	var/total_managed_mobs = 0
	/// Cache of biome type -> mob spawn list minus structure spawners and the megafauna sentinel
	var/list/filtered_mob_cache = list()

/// Tracks mob spawning state for a single planet.
/datum/planet_mob_tracker
	/// Planet identifier, unique per loaded planet
	var/name
	/// The planet's z-level number
	var/surface_z = 0
	/// Pre-indexed candidate turfs for mob spawning: turf -> the mob type rolled for it
	var/list/surface_spawn_turfs = list()
	/// Whether mobs currently exist on this planet
	var/populated = FALSE
	/// Whether players are currently present
	var/has_players = FALSE
	/// world.time when players last left (0 = they haven't)
	var/player_left_time = 0

/**
 * Starts tracking a planet's z-level. Called as the planet builds its terrain, BEFORE
 * population runs, so register_spawn_turf() has somewhere to file its turfs.
 */
/datum/controller/subsystem/planet_mobs/proc/register_planet(planet_key, surface_z)
	if(!planet_key || !surface_z)
		return
	var/datum/planet_mob_tracker/tracker = new
	tracker.name = planet_key
	tracker.surface_z = surface_z
	tracked_planets[planet_key] = tracker
	z_to_planet["[surface_z]"] = planet_key
	return tracker

/**
 * Stops tracking a planet and forgets its turfs. Called when a planet unloads - the
 * z-level is about to be wiped and handed back to the pool, so nothing here may outlive
 * it. Mobs are not deleted; clearing the z-level does that.
 */
/datum/controller/subsystem/planet_mobs/proc/unregister_planet(planet_key)
	var/datum/planet_mob_tracker/tracker = tracked_planets[planet_key]
	if(!tracker)
		return
	if(tracker.populated)
		total_managed_mobs = max(0, total_managed_mobs - count_planet_mobs(tracker))
	z_to_planet -= "[tracker.surface_z]"
	tracked_planets -= planet_key
	qdel(tracker)

/**
 * Files a turf as a candidate mob spawn point, along with the mob the terrain pass
 * rolled for it. The pick has to be carried: zone danger scaling can upgrade it to the
 * biome's meaner tier, and re-rolling from the base table later would throw that away.
 * Returns TRUE if it was taken, FALSE if this z-level isn't tracked - in which case the
 * caller should spawn its mob directly.
 */
/datum/controller/subsystem/planet_mobs/proc/register_spawn_turf(turf/candidate, mob_type)
	var/planet_key = z_to_planet["[candidate.z]"]
	if(!planet_key)
		return FALSE
	var/datum/planet_mob_tracker/tracker = tracked_planets[planet_key]
	if(!tracker)
		return FALSE
	tracker.surface_spawn_turfs[candidate] = mob_type
	return TRUE

/datum/controller/subsystem/planet_mobs/fire(resumed)
	for(var/planet_key in tracked_planets)
		var/datum/planet_mob_tracker/tracker = tracked_planets[planet_key]

		if(check_players(tracker))
			tracker.has_players = TRUE
			tracker.player_left_time = 0
			if(!tracker.populated)
				spawn_planet_mobs(tracker)
			continue

		if(tracker.has_players)
			// Players just left - start the grace period
			tracker.has_players = FALSE
			tracker.player_left_time = world.time
		if(tracker.populated && tracker.player_left_time && (world.time - tracker.player_left_time >= despawn_grace_period))
			despawn_planet_mobs(tracker)

/// Whether any player client is on the planet's z-level.
/datum/controller/subsystem/planet_mobs/proc/check_players(datum/planet_mob_tracker/tracker)
	if(!islist(SSmobs.clients_by_zlevel))
		return FALSE
	if(tracker.surface_z <= length(SSmobs.clients_by_zlevel) && length(SSmobs.clients_by_zlevel[tracker.surface_z]))
		return TRUE
	return FALSE

/// Populates the planet from its pre-indexed spawn turfs.
/datum/controller/subsystem/planet_mobs/proc/spawn_planet_mobs(datum/planet_mob_tracker/tracker)
	spawn_on_zlevel(tracker.surface_spawn_turfs, tracker.surface_z)
	tracker.populated = TRUE

/// Spawns up to the zone-scaled per-planet cap from the given candidate turfs.
/datum/controller/subsystem/planet_mobs/proc/spawn_on_zlevel(list/spawn_turfs, surface_z)
	if(!length(spawn_turfs))
		return

	// A flat cap muted the density half of danger scaling: deeper bands roll more
	// spawns, then the cap threw the surplus away. Scale it modestly instead.
	// The global cap still bounds the whole galaxy.
	var/planet_cap = per_zlevel_mob_cap
	switch(surface_z ? SSmapping.get_planet_zone_band_for_z(surface_z) : null)
		if(ZONE_YELLOW)
			planet_cap = round(per_zlevel_mob_cap * 1.2) // 18 at the default 15
		if(ZONE_RED)
			planet_cap = round(per_zlevel_mob_cap * 1.5) // 22 at the default 15

	var/spawned = 0
	var/list/available_turfs = spawn_turfs.Copy()

	while(spawned < planet_cap && total_managed_mobs < global_mob_cap && length(available_turfs))
		var/turf/candidate = pick_n_take(available_turfs)
		if(!isturf(candidate))
			continue

		// Landed ships copy their turfs over the surface; the candidate refs survive
		// that and now point inside the hull. Skip them - takeoff scrapes the ship
		// turfs away and the candidate becomes a valid surface turf again. Density
		// covers walls raised over a candidate by ruins or construction.
		if(candidate.density || istype(get_area(candidate), /area/shuttle))
			continue

		// The mob the terrain pass rolled for this turf, zone upgrade and all. Only
		// turfs filed before this proc learned to carry one fall through to the
		// biome table.
		var/mob_type = spawn_turfs[candidate]
		if(!mob_type)
			var/datum/biome/biome = candidate.generating_biome
			if(!length(biome?.mob_spawn_list))
				continue

			var/list/mob_list = get_filtered_mob_list(biome)
			if(!length(mob_list))
				continue

			mob_type = pickweight(mob_list)

		if(!mob_type)
			continue

		new mob_type(candidate)
		spawned++
		total_managed_mobs++

/**
 * A biome's mob_spawn_list minus structure spawners and the SPAWN_MEGAFAUNA sentinel -
 * both of those are placed once at generation time and are not ours to manage.
 * Cached per biome type.
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

/// Clears a planet's managed fauna after the grace period.
/datum/controller/subsystem/planet_mobs/proc/despawn_planet_mobs(datum/planet_mob_tracker/tracker)
	// Re-check: someone may have landed during the grace period
	if(check_players(tracker))
		tracker.has_players = TRUE
		tracker.player_left_time = 0
		return

	var/despawned = 0
	for(var/mob/living/candidate as anything in GLOB.mob_living_list)
		if(candidate.z != tracker.surface_z)
			continue
		if(!can_despawn(candidate))
			continue
		qdel(candidate)
		despawned++
		CHECK_TICK

	total_managed_mobs = max(0, total_managed_mobs - despawned)
	tracker.populated = FALSE
	tracker.player_left_time = 0

/**
 * Whether a mob may be despawned. Anything a player is attached to, anything dead
 * (bodies are evidence and loot), anything inside something else, megafauna and
 * contract mobs are all off limits.
 *
 * This sweep is indiscriminate by design, it walks every living mob on the
 * z-level, not a list of the ones it spawned, so anything else that puts a mob
 * on a planet is caught in it. A mission's marked specimen is exactly that: it
 * spawns from the objective chain, not from the biome tables, and deleting it
 * voids the contract three minutes after the crew steps off the surface.
 */
/datum/controller/subsystem/planet_mobs/proc/can_despawn(mob/living/candidate)
	if(candidate.ckey)
		return FALSE
	if(candidate.mind)
		return FALSE
	if(candidate.stat == DEAD)
		return FALSE
	if(!isturf(candidate.loc))
		return FALSE
	if(istype(candidate, /mob/living/simple_animal/hostile/megafauna))
		return FALSE
	if(HAS_TRAIT(candidate, TRAIT_MISSION_FIELD_MOB))
		return FALSE
	return TRUE

/// Counts the managed (despawnable) mobs currently alive on a planet.
/datum/controller/subsystem/planet_mobs/proc/count_planet_mobs(datum/planet_mob_tracker/tracker)
	var/count = 0
	for(var/mob/living/candidate as anything in GLOB.mob_living_list)
		if(candidate.z != tracker.surface_z)
			continue
		if(!can_despawn(candidate))
			continue
		count++
	return count

/datum/controller/subsystem/planet_mobs/stat_entry(msg)
	var/active = 0
	var/total_alive = 0
	for(var/planet_key in tracked_planets)
		var/datum/planet_mob_tracker/tracker = tracked_planets[planet_key]
		if(tracker.populated)
			active++
			total_alive += count_planet_mobs(tracker)
	msg = "Alive:[total_alive] Spawned:[total_managed_mobs]/[global_mob_cap] Planets:[active]/[length(tracked_planets)]"
	return ..()
