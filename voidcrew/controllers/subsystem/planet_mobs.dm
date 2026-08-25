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
	ss_flags = SS_BACKGROUND | SS_POST_FIRE_TIMING | SS_NO_INIT
	priority = FIRE_PRIORITY_PLANET_MOBS
	runlevels = RUNLEVEL_GAME | RUNLEVEL_POSTGAME

	/// Max managed mobs across ALL planets
	var/global_mob_cap = 150
	/// Base cap on managed mobs for any one planet, before the zone-band scaling in
	/// mob_cap_for_band(). Per PLANET, not per z-level: a packed level can hold several
	/// tenants and each of them gets its own budget, exactly as it would have on a level
	/// of its own.
	var/per_planet_mob_cap = 15
	/// How long a planet must sit empty before its fauna is cleared out
	var/despawn_grace_period = 3 MINUTES

	/// planet key -> /datum/planet_mob_tracker
	var/list/tracked_planets = list()
	/// z-level number (as text) -> list of /datum/planet_mob_tracker living on that z.
	///
	/// A list, not a single key. Under map packing a z-level holds up to four tenants, and
	/// the single-valued version failed in both directions: the second register_planet()
	/// on a z overwrote the first, so tenant A's turfs silently stopped registering and its
	/// fauna spawned eagerly and unmanaged for the round; and the first unregister_planet()
	/// deleted the key out from under everyone still on the level.
	var/list/z_to_planets = list()
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
	/// The planet's rectangle on that z-level, handed over by build_planet(). Null (or a
	/// whole-level rect) means "the whole z is mine", which is what every planet was before
	/// packing - see contains_turf().
	var/datum/map_footprint/footprint
	/// The zone band the planet was built in, carried from the overmap object at register
	/// time. SSmapping.get_planet_zone_band_for_z() only ever answered for pre-generated
	/// roundstart planets (it returns null for every dynamic one, which in a live round is
	/// all of them), and under packing it would answer for the neighbour instead of us.
	var/zone_band
	/// This planet's own share of the mob budget, resolved from zone_band at register time.
	var/mob_cap = 0
	/// Pre-indexed candidate turfs for mob spawning: turf -> the mob type rolled for it
	var/list/surface_spawn_turfs = list()
	/// Whether mobs currently exist on this planet
	var/populated = FALSE
	/// Whether players are currently present
	var/has_players = FALSE
	/// world.time when players last left (0 = they haven't)
	var/player_left_time = 0
	/// How many mobs this planet has drawn from the global budget. Counted at spawn and
	/// handed back whole when the planet depopulates or unregisters, rather than derived
	/// from a headcount: a headcount cannot see the ones players killed, and the budget
	/// they were charged against would ratchet up until the global cap saturated and
	/// every planet in the round quietly stopped spawning fauna.
	var/spawned_count = 0

/datum/planet_mob_tracker/Destroy(force)
	// The footprint outlives us by design (the map zone releases the slot after the planet
	// unregisters); hold no ref to it past our own lifetime.
	footprint = null
	surface_spawn_turfs = null
	return ..()

/**
 * Whether a turf belongs to THIS planet.
 *
 * The primitive H6/H7 turn on. With a footprint this is a rectangle test; without one - or
 * with a whole-level rect, which is what a planet holding a level to itself gets - it is
 * the bare z-match this used to be, so a single-tenant level behaves exactly as before.
 */
/datum/planet_mob_tracker/proc/contains_turf(turf/candidate)
	if(!candidate)
		return FALSE
	if(footprint && !QDELETED(footprint) && footprint.z_value)
		return footprint.contains_turf(candidate)
	return candidate.z == surface_z

/// Whether contains_turf() is doing anything a bare z-match would not. Lets the hot paths
/// skip per-mob rect work entirely on the levels that still hold one planet each.
/datum/planet_mob_tracker/proc/is_footprint_scoped()
	if(!footprint || QDELETED(footprint) || !footprint.z_value)
		return FALSE
	return !footprint.is_whole_level()

/**
 * Starts tracking a planet's z-level. Called as the planet builds its terrain, BEFORE
 * population runs, so register_spawn_turf() has somewhere to file its turfs.
 *
 * `footprint` is the planet's rectangle on that z (build_planet() has already narrowed it
 * with set_bounds() by the time this is called); `zone_band` is the band the planet was
 * built in. Both may be null, in which case the tracker falls back to owning the whole z
 * and to the unscaled cap - the pre-packing behaviour.
 */
/datum/controller/subsystem/planet_mobs/proc/register_planet(planet_key, surface_z, datum/map_footprint/footprint, zone_band)
	if(!planet_key || !surface_z)
		return
	var/datum/planet_mob_tracker/tracker = new
	tracker.name = planet_key
	tracker.surface_z = surface_z
	tracker.footprint = footprint
	tracker.zone_band = zone_band
	tracker.mob_cap = mob_cap_for_band(zone_band)
	tracked_planets[planet_key] = tracker

	var/z_key = "[surface_z]"
	var/list/trackers_here = z_to_planets[z_key]
	if(!trackers_here)
		trackers_here = list()
		z_to_planets[z_key] = trackers_here
	trackers_here |= tracker
	return tracker

/**
 * A planet's share of the mob budget for its zone band.
 *
 * A flat cap muted the density half of danger scaling: deeper bands roll more spawns, then
 * the cap threw the surplus away. Scale it modestly instead. The global cap still bounds
 * the whole galaxy.
 */
/datum/controller/subsystem/planet_mobs/proc/mob_cap_for_band(zone_band)
	switch(zone_band)
		if(ZONE_YELLOW)
			return round(per_planet_mob_cap * 1.2) // 18 at the default 15
		if(ZONE_RED)
			return round(per_planet_mob_cap * 1.5) // 22 at the default 15
	return per_planet_mob_cap

/**
 * Stops tracking a planet and forgets its turfs. Called when a planet unloads - the
 * z-level is about to be wiped and handed back to the pool, so nothing here may outlive
 * it. Mobs are not deleted; clearing the z-level does that.
 */
/datum/controller/subsystem/planet_mobs/proc/unregister_planet(planet_key)
	var/datum/planet_mob_tracker/tracker = tracked_planets[planet_key]
	if(!tracker)
		return
	total_managed_mobs = max(0, total_managed_mobs - tracker.spawned_count)
	tracker.spawned_count = 0

	// Drop ourselves out of the z's tenant list rather than deleting the key: on a packed
	// level the other tenants are still standing on it.
	var/z_key = "[tracker.surface_z]"
	var/list/trackers_here = z_to_planets[z_key]
	if(trackers_here)
		trackers_here -= tracker
		if(!length(trackers_here))
			z_to_planets -= z_key

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
	var/datum/planet_mob_tracker/tracker = tracker_for_turf(candidate)
	if(!tracker)
		return FALSE
	tracker.surface_spawn_turfs[candidate] = mob_type
	return TRUE

/**
 * The tracked planet a turf belongs to, or null.
 *
 * Resolves by footprint containment among the trackers registered on the turf's z-level.
 * On a level with one tenant this is the single tracker and its whole-level (or planet-rect)
 * containment test, i.e. exactly the old "is this z tracked?" lookup.
 */
/datum/controller/subsystem/planet_mobs/proc/tracker_for_turf(turf/candidate)
	if(!candidate)
		return null
	var/list/trackers_here = z_to_planets["[candidate.z]"]
	if(!length(trackers_here))
		return null
	for(var/datum/planet_mob_tracker/tracker as anything in trackers_here)
		if(tracker?.contains_turf(candidate))
			return tracker
	return null

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

/**
 * Whether any player client is standing on THIS planet.
 *
 * The z's client list is the cheap-out: no clients on the level means no clients on any of
 * its tenants, and that is the answer for the overwhelming majority of ticks. Only when
 * somebody is on the level - and only when the level is actually shared - does this pay for
 * a rectangle test per client.
 */
/datum/controller/subsystem/planet_mobs/proc/check_players(datum/planet_mob_tracker/tracker)
	if(!islist(SSmobs.clients_by_zlevel))
		return FALSE
	if(tracker.surface_z <= 0 || tracker.surface_z > length(SSmobs.clients_by_zlevel))
		return FALSE
	var/list/clients_here = SSmobs.clients_by_zlevel[tracker.surface_z]
	if(!length(clients_here))
		return FALSE
	if(!tracker.is_footprint_scoped())
		return TRUE
	for(var/mob/player as anything in clients_here)
		if(QDELETED(player))
			continue
		// get_turf() rather than the mob's own z: a player inside a locker, a mech or a
		// bodybag reads z 0 off the mob itself.
		if(tracker.contains_turf(get_turf(player)))
			return TRUE
	return FALSE

/// Populates the planet from its pre-indexed spawn turfs.
/datum/controller/subsystem/planet_mobs/proc/spawn_planet_mobs(datum/planet_mob_tracker/tracker)
	tracker.spawned_count += spawn_for_tracker(tracker)
	tracker.populated = TRUE

/// Spawns up to this planet's own zone-scaled cap from its candidate turfs.
/// Returns how many mobs it actually spawned.
/datum/controller/subsystem/planet_mobs/proc/spawn_for_tracker(datum/planet_mob_tracker/tracker)
	var/list/spawn_turfs = tracker.surface_spawn_turfs
	if(!length(spawn_turfs))
		return 0

	// Per PLANET, resolved from the band the tracker carries. Identical to the old per-z
	// figure while a level holds one planet; under packing each tenant keeps its own budget
	// instead of four of them splitting one z's worth.
	var/planet_cap = tracker.mob_cap || per_planet_mob_cap

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

	return spawned

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

	// Copy, and let the typed loop filter: qdel() below edits GLOB.mob_living_list, and
	// walking the live list means every deletion shifts it and skips the next mob.
	// allow_dead: corpses are evidence and loot while there is somebody around to read
	// them. There is not - the zone has been empty for the grace period and was just
	// re-checked - and the alternative is leaving them there for the rest of the round,
	// because nothing else in the game reaps a body. Minds and clients are still refused.
	//
	// The z-match is only a cheap pre-filter now. A z-wide sweep on a packed level deletes
	// the NEIGHBOUR's fauna, and with allow_dead its corpses and their loot, three minutes
	// after our own crew leaves - while the neighbour's crew is standing there. The
	// footprint test is what confines it to our own ground.
	var/footprint_scoped = tracker.is_footprint_scoped()
	for(var/mob/living/candidate in GLOB.mob_living_list.Copy())
		if(candidate.z != tracker.surface_z)
			continue
		if(footprint_scoped && !tracker.contains_turf(get_turf(candidate)))
			continue
		if(!can_despawn(candidate, allow_dead = TRUE))
			continue
		qdel(candidate)
		CHECK_TICK

	// The whole budget this planet drew goes back, not just the headcount deleted here:
	// the mobs players killed were charged against it too.
	total_managed_mobs = max(0, total_managed_mobs - tracker.spawned_count)
	tracker.spawned_count = 0
	tracker.populated = FALSE
	tracker.player_left_time = 0

/**
 * Whether a mob may be despawned. Anything a player is attached to, anything dead
 * (bodies are evidence and loot), anything inside something else, megafauna and
 * contract mobs are all off limits.
 *
 * `allow_dead` is for the grace-period sweep only, which runs on a zone nobody has been
 * on for three minutes: there is no one left for a body to be evidence for, and nothing
 * anywhere in the game reaps a corpse, so refusing there just means the planet keeps
 * every body it ever produced. Everything with a mind or a client is still refused, dead
 * or not. Never pass TRUE for a zone that has players on it.
 *
 * This sweep is indiscriminate by design, it walks every living mob inside the
 * planet's footprint, not a list of the ones it spawned, so anything else that puts a mob
 * on a planet is caught in it. A mission's marked specimen is exactly that: it
 * spawns from the objective chain, not from the biome tables, and deleting it
 * voids the contract three minutes after the crew steps off the surface.
 */
/datum/controller/subsystem/planet_mobs/proc/can_despawn(mob/living/candidate, allow_dead = FALSE)
	if(candidate.ckey)
		return FALSE
	if(candidate.mind)
		return FALSE
	if(candidate.stat == DEAD && !allow_dead)
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
	var/footprint_scoped = tracker.is_footprint_scoped()
	for(var/mob/living/candidate as anything in GLOB.mob_living_list)
		if(QDELETED(candidate))
			continue
		if(candidate.z != tracker.surface_z)
			continue
		if(footprint_scoped && !tracker.contains_turf(get_turf(candidate)))
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

// map_footprint_at_turf() and footprint_holds_any_client() used to live here; they are
// generic footprint geometry and now sit with the datum, in voidcrew/datums/map_footprint.dm.
// Both are free procs, so spawner.dm and idle_npc_wakeup.dm call them unchanged.
