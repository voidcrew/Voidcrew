/**
 * Planet anomalies.
 *
 * Anomalies used to arrive as a ship-scoped dynamic event: one materialised inside the
 * hull, the crew got an area name, and then they lived with it in their own corridors
 * until it timed out. There was no version of that a crew could play well, a shuttle
 * has one route between compartments, so "avoid the gravitational anomaly" and "reach
 * engineering" were frequently the same tile.
 *
 * The same object on open planet ground is the opposite proposition. Nothing brought it
 * to the crew, the crew walked to it, and a crew that researched Anomaly Research
 * (tier 3) and printed a neutralizer turns it into an anomaly core.
 *
 * These are the ONLY anomalies that spawn naturally. The ship-scoped controls in
 * voidcrew/modules/dynamic_events/events/anomalies.dm are all weight 0 / admin-only.
 * Boffin's anomaly charts (voidcrew/modules/trade/anomaly_charts.dm) spawn the same
 * subtypes inside derelicts and on planets.
 *
 * Every anomaly type can turn up, with its stock behaviour: they wander, the vortex eats
 * what it reaches and the dimensional anomaly rewrites the ground around it. Planets are
 * rebuilt when a crew leaves, so the damage does not outlast the visit. What differs
 * from the station versions:
 *
 * - `immortal`: planets are prebuilt in the lobby and released minutes into the round,
 *   so a normal ANOMALY_COUNTDOWN_TIMER anomaly would detonate and vanish long before
 *   anybody could land and look at it. Immortal also suppresses detonate(), so the
 *   payoff for finding one is the core, not the explosion.
 * - `site_bound`: the anomaly stays on its own site (see /datum/component/anomaly_site_leash).
 *   It never wanders into the cordon, onto a neighbour's site on a shared z-level, onto a
 *   docked ship or into a planet's landing strip, and the dimensional anomaly relocates
 *   within the site instead of across the sector.
 * - the pyroclastic anomaly spits short jets of flame instead of venting plasma. The
 *   stock version's gas release gives every planet turf it spreads to a private air
 *   mix that never goes back to the shared one (voidcrew/edits/planetary_shared_air.dm),
 *   so a wandering one leaves an ever-growing trail of active air. The jets are
 *   visual effects plus direct burns: they never touch atmos.
 * - hallucination decoys stay off. Decoys are separate, unbound anomalies with their own
 *   timers, spawned in a cluster around the real one; on a planet they would wander off
 *   the site like any unbound anomaly.
 */

/**
 * Weighted table of anomaly types a planet may seed, in three rarity bands that match
 * the price bands Boffin sells their cores and charts in. Whether a planet gets one at
 * all is a per-zone roll (ZONE_PLANET_ANOMALY_CHANCE_*, see planet_anomaly_chance()).
 */
GLOBAL_LIST_INIT(voidcrew_planet_anomalies, list(
	// Common
	/obj/effect/anomaly/flux/planetary = 25,
	/obj/effect/anomaly/grav/planetary = 25,
	/obj/effect/anomaly/hallucination/planetary = 25,
	/obj/effect/anomaly/pyro/planetary = 25,
	// Uncommon
	/obj/effect/anomaly/bioscrambler/planetary = 12,
	/obj/effect/anomaly/ectoplasm/planetary = 12,
	/obj/effect/anomaly/dimensional/planetary = 12,
	// Rare
	/obj/effect/anomaly/bluespace/planetary = 5,
	/obj/effect/anomaly/bhole/planetary = 5,
))

/// Percent chance a planet in `zone_band` seeds its one anomaly
/proc/planet_anomaly_chance(zone_band)
	switch(zone_band)
		if(ZONE_YELLOW)
			return ZONE_PLANET_ANOMALY_CHANCE_YELLOW
		if(ZONE_RED)
			return ZONE_PLANET_ANOMALY_CHANCE_RED
	return ZONE_PLANET_ANOMALY_CHANCE_GREEN

/obj/effect/anomaly
	/// Whether this anomaly is leashed to the site it formed on (see anomaly_site_leash)
	var/site_bound = FALSE

// Chains onto the upstream Initialize: runs after it, before any subtype's own body.
/obj/effect/anomaly/Initialize(mapload, new_lifespan)
	. = ..()
	if(site_bound && . != INITIALIZE_HINT_QDEL)
		AddComponent(/datum/component/anomaly_site_leash)

/obj/effect/anomaly/flux/planetary
	immortal = TRUE
	site_bound = TRUE

/obj/effect/anomaly/grav/planetary
	immortal = TRUE
	site_bound = TRUE

/obj/effect/anomaly/hallucination/planetary
	immortal = TRUE
	site_bound = TRUE
	spawn_decoys = FALSE

/**
 * Every few seconds it spits one to three jets of flame, three or four tiles long,
 * stopped by anything dense and by the edge of its site. Anyone in a jet or standing
 * next to the anomaly at the burst is set alight and takes a light burn. The flames
 * are temp visuals only: no gas, no hotspots, nothing for SSair to process.
 */
/obj/effect/anomaly/pyro/planetary
	immortal = TRUE
	site_bound = TRUE
	/// Seconds between bursts
	var/burst_delay = 4
	/// Seconds since the last burst
	var/burst_timer = 0
	/// Most jets in one burst
	var/max_jets = 3
	/// Jet length range, in tiles
	var/jet_length_min = 3
	var/jet_length_max = 4
	/// Fire stacks given to anyone caught
	var/burn_stacks = 3
	/// Burn damage dealt to anyone caught
	var/burn_damage = 5

/obj/effect/anomaly/pyro/planetary/anomalyEffect(seconds_per_tick)
	// No ..(): the parent vents plasma. Only the base proc's drift is kept.
#ifndef UNIT_TESTS
	if(SPT_PROB(move_chance, seconds_per_tick))
		move_anomaly()
#endif
	burst_timer += seconds_per_tick
	if(burst_timer < burst_delay)
		return
	burst_timer = 0
	spit_flames()

/obj/effect/anomaly/pyro/planetary/proc/spit_flames()
	var/turf/origin = get_turf(src)
	if(!origin)
		return
	var/datum/component/anomaly_site_leash/leash = GetComponent(/datum/component/anomaly_site_leash)
	var/list/burned = list()
	for(var/turf/adjacent in range(1, origin))
		burn_turf(adjacent, burned)
	var/list/directions = GLOB.alldirs.Copy()
	for(var/_ in 1 to rand(1, max_jets))
		var/jet_dir = pick_n_take(directions)
		var/turf/current = origin
		for(var/__ in 1 to rand(jet_length_min, jet_length_max))
			var/turf/next = get_step(current, jet_dir)
			if(!next || next.is_blocked_turf(exclude_mobs = TRUE))
				break
			if(leash && !leash.allows(next))
				break
			new /obj/effect/temp_visual/fire(next)
			burn_turf(next, burned)
			current = next
	playsound(src, 'sound/effects/fire_puff.ogg', 50, TRUE)

/// Sets anyone living on `target` alight, once per burst
/obj/effect/anomaly/pyro/planetary/proc/burn_turf(turf/target, list/burned)
	for(var/mob/living/victim in target)
		if(victim in burned)
			continue
		burned += victim
		victim.adjust_fire_stacks(burn_stacks)
		victim.ignite_mob()
		victim.apply_damage(burn_damage, BURN)

/obj/effect/anomaly/bioscrambler/planetary
	immortal = TRUE
	site_bound = TRUE

/obj/effect/anomaly/ectoplasm/planetary
	immortal = TRUE
	site_bound = TRUE

/obj/effect/anomaly/dimensional/planetary
	immortal = TRUE
	site_bound = TRUE

/// Never converts ground off its own site: no docked hull, no cordon, no neighbour.
/obj/effect/anomaly/dimensional/planetary/prepare_area(new_theme_path)
	. = ..()
	var/datum/component/anomaly_site_leash/leash = GetComponent(/datum/component/anomaly_site_leash)
	if(!leash)
		return
	for(var/turf/target as anything in target_turfs.Copy())
		if(!leash.allows(target))
			target_turfs -= target

/// Upstream relocates to a random station area with a sector-wide announcement. Here it
/// jumps to another spot on the same site, quietly.
/obj/effect/anomaly/dimensional/planetary/relocate()
	var/datum/component/anomaly_site_leash/leash = GetComponent(/datum/component/anomaly_site_leash)
	var/turf/new_turf = leash?.random_open_turf()
	if(new_turf)
		forceMove(new_turf)
	prepare_area()

/obj/effect/anomaly/bluespace/planetary
	immortal = TRUE
	site_bound = TRUE

/obj/effect/anomaly/bhole/planetary
	immortal = TRUE
	site_bound = TRUE

/**
 * # Anomaly site leash
 *
 * Keeps a wandering anomaly on the site it formed on. Bounds are taken from the site's
 * map footprint when the anomaly appears: the whole footprint for a planet, minus the
 * landing strip along its bottom, or the ruin template's own rectangle for a space
 * ruin. On top of that it never enters a ship (/area/shuttle), the cordon or open space
 * (/area/space), or another z-level.
 *
 * Every way an anomaly moves itself (random drift, the bioscrambler's pursuit, deadchat
 * steering of the ectoplasm anomaly) goes through Move(), so blocking PRE_MOVE covers
 * them. The dimensional anomaly's forceMove relocation asks random_open_turf() instead.
 */
/datum/component/anomaly_site_leash
	/// The z-level the anomaly formed on
	var/home_z
	/// Inclusive bounds, null when the anomaly formed outside any known site
	var/low_x
	var/low_y
	var/high_x
	var/high_y

/datum/component/anomaly_site_leash/Initialize()
	if(!istype(parent, /obj/effect/anomaly))
		return COMPONENT_INCOMPATIBLE
	var/turf/home = get_turf(parent)
	if(!home)
		return COMPONENT_INCOMPATIBLE
	home_z = home.z
	derive_bounds(home)

/datum/component/anomaly_site_leash/RegisterWithParent()
	RegisterSignal(parent, COMSIG_MOVABLE_PRE_MOVE, PROC_REF(on_pre_move))

/datum/component/anomaly_site_leash/UnregisterFromParent()
	UnregisterSignal(parent, COMSIG_MOVABLE_PRE_MOVE)

/datum/component/anomaly_site_leash/proc/derive_bounds(turf/home)
	var/datum/map_footprint/footprint = map_region_for_turf(home)
	if(!istype(footprint))
		return
	low_x = footprint.low_x
	low_y = footprint.low_y
	high_x = footprint.high_x
	high_y = footprint.high_y
	if(istype(footprint.owner, /obj/structure/overmap/planet))
		var/obj/structure/overmap/planet/planet = footprint.owner
		var/strip_top = planet.get_dock_strip_top_y(footprint.level)
		// An anomaly placed inside the strip by hand keeps the full footprint rather
		// than being frozen in place.
		if(!isnull(strip_top) && home.y > strip_top)
			low_y = max(low_y, strip_top + 1)
	else if(istype(footprint.owner, /obj/structure/overmap/space_ruin))
		var/obj/structure/overmap/space_ruin/ruin = footprint.owner
		var/turf/corner = ruin.ruin_bottom_left
		if(corner && ruin.ruin_template?.width && ruin.ruin_template?.height)
			low_x = max(low_x, corner.x)
			low_y = max(low_y, corner.y)
			high_x = min(high_x, corner.x + ruin.ruin_template.width - 1)
			high_y = min(high_y, corner.y + ruin.ruin_template.height - 1)

/// Whether the anomaly may stand on `destination`
/datum/component/anomaly_site_leash/proc/allows(turf/destination)
	if(!isturf(destination) || destination.z != home_z)
		return FALSE
	if(!isnull(low_x) && (destination.x < low_x || destination.x > high_x || destination.y < low_y || destination.y > high_y))
		return FALSE
	if(istype(destination, /turf/cordon))
		return FALSE
	var/area/destination_area = get_area(destination)
	if(istype(destination_area, /area/shuttle) || istype(destination_area, /area/space))
		return FALSE
	return TRUE

/datum/component/anomaly_site_leash/proc/on_pre_move(atom/movable/source, atom/new_loc)
	SIGNAL_HANDLER
	if(!allows(new_loc))
		return COMPONENT_MOVABLE_BLOCK_PRE_MOVE

/// A random open, walkable turf the anomaly may stand on, or null
/datum/component/anomaly_site_leash/proc/random_open_turf(attempts = 60)
	if(isnull(low_x))
		return null
	for(var/_ in 1 to attempts)
		var/turf/candidate = locate(rand(low_x, high_x), rand(low_y, high_y), home_z)
		if(!isopenturf(candidate) || isgroundlessturf(candidate) || candidate.density)
			continue
		if(!allows(candidate))
			continue
		return candidate
	return null
