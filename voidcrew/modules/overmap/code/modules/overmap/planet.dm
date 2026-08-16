/obj/structure/overmap/planet
	name = "weak energy signature"
	desc = "A very weak energy signature."
	icon_state = "strange_event"
	sensor_detectable = TRUE
	sensor_category = "Planets"
	survey_value = 500

	/// Datum containing all of the information about this planet
	var/datum/overmap/planet/planet
	///The active turf reservation, if there is one
	var/datum/map_zone/mapzone
	///The preset ruin template to load, if/when it is loaded.
	var/datum/map_template/template
	///The docking port in the reserve
	var/obj/docking_port/stationary/reserve_dock
	///The docking port in the reserve
	var/obj/docking_port/stationary/reserve_dock_secondary
	///If the level should be preserved. Useful for if you want to build an autismfort or something.
	var/preserve_level = FALSE
	///Keep track of whether or not the docks have been reserved by a ship. This is required to prevent issues where two ships will attempt to dock in the same place due to unfortunate timing
	var/first_dock_taken = FALSE
	var/second_dock_taken = FALSE
	var/loaded = FALSE
	var/loading = FALSE
	var/visited = FALSE
	/// Which docking port the ship is occupying
	var/dock_index
	var/datum/weather/weather_type
	/// The overmap zone band this planet belongs to. Its terrain is scaled to this, so
	/// it is kept across relocations rather than re-rolled from wherever it lands.
	var/zone_band
	/// Whether the lobby pre-build pass generates this planet's surface before the round
	/// starts. Set on one planet of each type; the rest of the round's planets stay
	/// unloaded contacts so extra planets cost nothing but overmap tiles until visited.
	var/prebuild_at_roundstart = FALSE
	/// Suffix telling this planet apart from the others of its type ("II", "III"...).
	/// Null when the round only has one of each. Applied in apply_planet_identity().
	var/designation
	/// Key identifying this planet's SSplanet_mobs tracker while it is loaded
	var/planet_key
	/// Stoppable timer id for the unload countdown
	var/despawn_timer_id
	/// TRUE while the planet is tearing its z-levels down, blocks ship_act() and reload
	var/unloading = FALSE

/// The chart colours planets by terrain, and the terrain is the planet datum's business.
/obj/structure/overmap/planet/get_contact_variant()
	return planet ? initial(planet.chart_variant) : null

/**
 * Copies the planet datum's identity - name, description, appearance, weather, parallax -
 * onto the overmap contact.
 *
 * Called from Initialize(), and again by hand from SSovermap.setup_planets(). Both paths
 * go through here so the designation suffix survives the second copy instead of being
 * overwritten by the datum's bare name. (The hand call dates from when SSovermap
 * initialized before SSatoms and a marker it spawned sat on the chart as a nameless "weak
 * energy signature" until SSatoms drained its queue; SSovermap now depends on SSatoms.)
 */
/obj/structure/overmap/planet/proc/apply_planet_identity()
	if(!planet)
		return
	var/datum/overmap/planet/planet_info = new planet
	name = designation ? "[planet_info.name] [designation]" : planet_info.name
	desc = planet_info.desc
	icon_state = planet_info.icon_state
	color = planet_info.color
	weather_type = planet_info.weather_controller_type
	if(isnull(parallax_theme)) // context-aware parallax: the planet datum carries the theme
		parallax_theme = planet_info.parallax_theme
	qdel(planet_info)
	// Planets never carry a display_name of their own, and the base Initialize() latches
	// it from name before the copy above runs - leaving it on "weak energy signature".
	display_name = name

/// Whether this is a real terrain planet (surface + caves) rather than a flat encounter
/// like empty space or a crashed ship, which have no areas to generate into.
/obj/structure/overmap/planet/proc/is_terrain_planet()
	return planet && initial(planet.surface_area)

/// Terrain planets pull a landed ship down with the surface areas' own gravity
/// (/area/overmap_encounter/planetoid is STANDARD_GRAVITY). Flat encounters.
/// Empty space, crashed ships, weak signals. Are just space with a dock in it.
/obj/structure/overmap/planet/has_ambient_gravity()
	return is_terrain_planet()

/**
  * Load a level for a ship that's visiting the level.
  * * user - The mob that asked, if any. Told where it stands if the worldgen queue is
  *   busy; a build can hold for minutes and a silent wait just looks like a locked helm.
  * * queue_timeout - How long to wait for the worldgen queue. Null takes the default;
  *   UI callers that cannot hold an interface open pass WORLDGEN_QUEUE_NO_WAIT.
  * * waiting_ship - The ship holding a docking approach on this planet; routed to
  *   worldgen_claim()'s notify_ship so queue progress reaches the whole crew.
  *
  * Sends COMSIG_VOIDCREW_SITE_LOAD_FINISHED (TRUE/FALSE) on every exit except the
  * in-flight `loading` guard (that load owns the signal) - ships holding an approach
  * resume (or give up) off that signal, and a silent exit would latch them out of
  * this planet for the rest of the round.
  */
/obj/structure/overmap/planet/proc/load_level(mob/user, queue_timeout, obj/structure/overmap/ship/waiting_ship)
	// Busy. Returning truthy aborts the caller's docking attempt cleanly - falling
	// through would hand it a null reserve_dock. Planets are pre-built during the lobby
	// and rebuilt after being abandoned, so arriving mid-build is a real possibility.
	//
	// These are tested ahead of the mapzone checks below because both in-progress states
	// pass through a window where mapzone is set and reserve_dock is not: build_planet()
	// claims its zone long before it stands up the docks, and unload_level() removes the
	// docks before it drops the zone. In the other order, anything arriving in either
	// window falls into the create_docking_ports() branch and builds ports onto a level
	// that is still half-generated, or already half-deleted.
	if(loading)
		return "Planetary survey in progress, stand by." // the in-flight load sends the completion signal
	if(unloading)
		// A waiter shouldn't be able to register during a teardown (ship_act refuses on
		// unloading before it requests), but if one is, a silent exit latches it out of
		// this planet for the round - failure is always safe to over-report.
		SEND_SIGNAL(src, COMSIG_VOIDCREW_SITE_LOAD_FINISHED, FALSE)
		return "Orbit is being recalculated, stand by."
	// Materially loaded already: mapzone stands and neither in-progress flag is up. This
	// is the lobby-prebuilt planet standing its docks up on first visit, or the wreckage
	// of a watchdog-released build (mapzone assigned, `loaded` never set). Both end with
	// a dockable planet, so complete the state and say so - request_site_load() may have
	// a ship registered for the signal, and returning silently would strand it while
	// every later Dock press reads "survey already underway" off its own registration.
	if(mapzone && !reserve_dock)
		create_docking_ports()
		loaded = TRUE
		SEND_SIGNAL(src, COMSIG_VOIDCREW_SITE_LOAD_FINISHED, TRUE)
		return
	if(mapzone)
		loaded = TRUE
		SEND_SIGNAL(src, COMSIG_VOIDCREW_SITE_LOAD_FINISHED, TRUE)
		return

	// Flagged before queueing rather than after: from here on this planet is loading,
	// it is simply waiting its turn, and every other caller has to see that instead of
	// starting a second build behind our back.
	loading = TRUE

	var/datum/worldgen_probe/load_probe = worldgen_begin("planet-load", "[display_name || name]")

	if(is_terrain_planet())
		// Terrain generation is the heaviest job there is - see worldgen_queue.dm.
		if(!SSovermap.worldgen_claim(src, "planet build ([display_name || name])", user, queue_timeout, waiting_ship))
			loading = FALSE
			worldgen_end(load_probe, "queue-timeout")
			SEND_SIGNAL(src, COMSIG_VOIDCREW_SITE_LOAD_FINISHED, FALSE)
			return "Survey queue is backed up, try again shortly."

		// Generation is throttled to a slice of each tick, so this is the better part of
		// a minute - say what is going on. The helm is NOT held anymore (the ship keeps
		// flying and the approach resumes on its own); this is why the wait exists.
		var/survey_message = "Orbital survey of [display_name || name] underway. Mapping a surface takes about a minute; the approach resumes on its own when it finishes."
		if(waiting_ship)
			waiting_ship.ship_notify(survey_message, "SURVEY", SHIP_NOTIFY_NOTICE)
		else if(user)
			to_chat(user, span_notice(survey_message))
		build_planet(load_probe)
		// Terrain queues a light source per surface turf; until SSlighting drains that,
		// the planet is pitch black. Hold the dock (callers show "survey in progress")
		// so arrivals land on a lit surface. Short cap: mid-round the queues are
		// near-empty besides our own build, and a stall shouldn't strand the ship.
		//
		// Deliberately inside the worldgen claim. Releasing first would let the next
		// build start pouring its own light sources into the same queue, and this wait
		// would never see the bottom of it.
		SSovermap.wait_for_lighting_settle(cap = 90 SECONDS)
		SSovermap.worldgen_release(src)
	else
		// Flat encounters split in two. Empty space, crashed ships and weak signals are
		// stood up for routine ship-to-ship and cargo docking, and may never wait behind
		// somebody else's survey (the design rule in worldgen_queue.dm). Anything carrying
		// its own map generator - the large asteroid's cave level - is survey-scale work
		// and queues like every other heavy job.
		var/queued_encounter = planet && initial(planet.mapgen)
		if(queued_encounter && !SSovermap.worldgen_claim(src, "encounter build ([display_name || name])", user, queue_timeout, waiting_ship))
			loading = FALSE
			worldgen_end(load_probe, "queue-timeout")
			SEND_SIGNAL(src, COMSIG_VOIDCREW_SITE_LOAD_FINISHED, FALSE)
			return "Survey queue is backed up, try again shortly."
		var/list/dynamic_encounter_values = SSovermap.spawn_dynamic_encounter(planet, TRUE, ruin_type = template, zone_band = SSovermap.get_zone_band_for_turf(get_turf(src)), throttled = queued_encounter)
		if(queued_encounter)
			SSovermap.worldgen_release(src)
		// A failed build must drop the loading flag on its way out: this branch has
		// no worldgen-queue watchdog, so a wedged flag reads "survey in progress"
		// for the rest of the round with nothing left to ever clear it.
		if(length(dynamic_encounter_values) < 3 || !dynamic_encounter_values[1] || !dynamic_encounter_values[2])
			loading = FALSE
			log_mapping("SSovermap: dynamic encounter build failed for '[display_name || name]' at ([x],[y]) - dock aborted")
			worldgen_end(load_probe, "failed")
			SEND_SIGNAL(src, COMSIG_VOIDCREW_SITE_LOAD_FINISHED, FALSE)
			return "Dock site failed to initialize, try again."
		mapzone = dynamic_encounter_values[1]
		reserve_dock = dynamic_encounter_values[2]
		reserve_dock_secondary = dynamic_encounter_values[3]
	worldgen_end(load_probe)
	loaded = TRUE
	loading = FALSE
	SEND_SIGNAL(src, COMSIG_VOIDCREW_PLANET_LOADED, TRUE)
	SEND_SIGNAL(src, COMSIG_VOIDCREW_SITE_LOAD_FINISHED, TRUE)

/obj/structure/overmap/planet/start_level_load(mob/user, obj/structure/overmap/ship/waiting_ship)
	INVOKE_ASYNC(src, PROC_REF(load_level), user, null, waiting_ship)

/obj/structure/overmap/planet/is_loading()
	return loading

/obj/structure/overmap/planet/is_loaded()
	return loaded

/**
 * Builds this planet's interior: one surface z-level, confined to a planet_size region
 * with everything outside it cordoned off.
 *
 * This is the sequence SSmapping used to run at boot for preloaded planets - terrain,
 * budgeted ruins with ore vents, rivers and weather - so a planet generated on arrival
 * carries the same content as one that had been sitting in memory since roundstart. It
 * just costs nothing until someone actually comes looking.
 *
 * Deliberately a SINGLE z-level. Planets used to build a surface + underground cave pair
 * with linked entrances, which doubled generation time and made the load stall long
 * enough to be felt server-wide. Rock and ore still appear on the surface as cave
 * pockets, which is where the mining content lives now.
 *
 * parent_probe - the enclosing load_level() worldgen probe; stage timings are logged
 * as its children so a laggy build shows which stage burned the time.
 */
/obj/structure/overmap/planet/proc/build_planet(datum/worldgen_probe/parent_probe)
	var/datum/worldgen_probe/build_probe = worldgen_begin("planet-build", "[display_name || name]", parent_probe?.id)
	var/datum/overmap/planet/planet_info = new planet
	var/planet_size = planet_info.planet_size
	var/ruin_trait = planet_info.ruin_type
	var/weather_trait = planet_info.weather_trait
	var/area/surface_area_type = planet_info.surface_area
	var/turf/ground_baseturf = planet_info.baseturf
	qdel(planet_info)

	if(isnull(zone_band))
		zone_band = SSovermap.get_zone_band_for_turf(get_turf(src))

	var/list/surface_traits = list(ZTRAIT_MINING = TRUE, ZTRAIT_LINKAGE = UNAFFECTED)
	if(ruin_trait)
		surface_traits[ruin_trait] = TRUE
	// What a removed turf falls back to. Without this the level has no ZTRAIT_BASETURF and
	// ChangeTurf bottoms every baseturfs chain out in /turf/open/space - a broken ruin floor
	// or a dug-up patch of dirt becomes a hole into vacuum on the ground. See
	// /datum/overmap/planet/baseturf.
	if(ground_baseturf)
		surface_traits[ZTRAIT_BASETURF] = ground_baseturf

	var/datum/space_level/surface_level
	var/datum/map_zone/zone = SSovermap.find_free_mapzone()
	if(isnull(zone))
		zone = SSovermap.create_map_zone("Planet")

	// Claimed here, before anything below is allowed to sleep, and not after the level
	// is minted. add_new_zlevel() blocks on its own spinlock whenever another level is
	// being made, and an unclaimed zone held across that sleep is exactly what
	// find_free_mapzone() hands to the next caller - two encounters on one map zone,
	// and whichever is abandoned first wipes the other's live surface.
	zone.taken = TRUE
	mapzone = zone

	if(length(zone.z_levels))
		// A recycled zone, still carrying the previous occupant's traits
		surface_level = zone.z_levels[1]
	else
		surface_level = SSmapping.add_new_zlevel("Planet surface", surface_traits)
		zone.add_space_level(surface_level)

	apply_planet_level_traits(surface_level, surface_traits, weather_trait)

	// Confine the level to the planet's footprint and wall off everything outside it
	surface_level.set_bounds(planet_size, planet_size)
	var/area/surface_area = surface_level.fill_in(area_override = surface_area_type)
	surface_level.place_cordon()

	// Terrain first: this lays biome turfs down and tags each one with the biome it came
	// from, which everything below reads.
	var/datum/worldgen_probe/stage_probe = worldgen_begin("stage", "terrain", build_probe.id)
	surface_area?.RunTerrainGeneration()
	worldgen_end(stage_probe)

	// Register before populating - population hands its mob spawn turfs to SSplanet_mobs
	planet_key = "[REF(src)]"
	SSplanet_mobs.register_planet(planet_key, surface_level.z_value)

	stage_probe = worldgen_begin("stage", "populate", build_probe.id)
	populate_planet_level(surface_level)
	worldgen_end(stage_probe)

	// Before ruins, not after: seedRuins() reads NO_RUINS while it picks placements, and a
	// flag set afterwards would be too late to move anything.
	reserve_dock_strip(surface_level)

	stage_probe = worldgen_begin("stage", "ruins", build_probe.id)
	seed_planet_ruins(surface_level, ruin_trait, surface_area_type)
	worldgen_end(stage_probe)
	generate_ruin_terrain(surface_level)

	stage_probe = worldgen_begin("stage", "rivers", build_probe.id)
	spawn_planet_rivers_for(surface_level, ruin_trait, surface_area_type)
	worldgen_end(stage_probe)

	create_docking_ports()

	log_mapping("SSovermap: Built planet '[name]' band [zone_band] on z [surface_level.z_value], [planet_size]x[planet_size]")
	worldgen_end(build_probe)

/**
 * Points a z-level's traits at this planet, clearing whatever the last occupant left
 * behind. Weather goes through SSweather so its scheduling and any running storm are
 * torn down with the trait.
 */
/obj/structure/overmap/planet/proc/apply_planet_level_traits(datum/space_level/level, list/new_traits, weather_trait)
	for(var/old_trait in level.traits)
		var/list/trait_levels = SSmapping.z_trait_levels[old_trait]
		if(trait_levels)
			trait_levels -= level.z_value

	level.traits = new_traits.Copy()

	for(var/new_trait in level.traits)
		var/list/trait_levels = SSmapping.z_trait_levels[new_trait]
		if(!trait_levels)
			trait_levels = list()
			SSmapping.z_trait_levels[new_trait] = trait_levels
		trait_levels |= list(level.z_value)

	SSweather.set_z_level_weather_trait(level, weather_trait)

	// Red-band planets carry radiation storms on top of their own climate, so both sit in
	// the level's random-weather rotation and SSweather picks between them by probability
	// (see /datum/weather/rad_storm/planetary).
	//
	// This has to run AFTER set_z_level_weather_trait(): that proc strips every
	// random-weather trait off the level before setting the one it was handed, which is
	// also what clears this trait from a recycled z-level that used to be a red planet.
	if(zone_band == ZONE_RED)
		add_random_weather_trait(level, ZTRAIT_RADSTORM)

/**
 * Adds one more random-weather trait to a level that already has its climate trait set,
 * and re-registers the level so SSweather picks the new type up.
 *
 * set_z_level_weather_trait() only handles the single climate trait; anything a planet
 * carries in addition to that goes through here.
 */
/obj/structure/overmap/planet/proc/add_random_weather_trait(datum/space_level/level, weather_trait)
	if(!weather_trait)
		return
	level.traits[weather_trait] = TRUE
	var/list/trait_levels = SSmapping.z_trait_levels[weather_trait]
	if(!trait_levels)
		trait_levels = list()
		SSmapping.z_trait_levels[weather_trait] = trait_levels
	trait_levels |= list(level.z_value)
	SSweather.update_z_level(level)

/**
 * Runs terrain population over every area on a planet z-level.
 *
 * It can't just be the area we filled in with: generate_terrain() carves its cave
 * pockets out into freshly-made cave areas, and those hold most of the turfs by the
 * time population runs. Roundstart got this for free by sweeping every area in the
 * world; here the areas are found from the level's own turfs.
 */
/obj/structure/overmap/planet/proc/populate_planet_level(datum/space_level/level)
	var/list/areas_on_level = list()
	for(var/turf/tile as anything in level.get_block())
		var/area/tile_area = tile.loc
		if(!tile_area || areas_on_level[tile_area])
			continue
		areas_on_level[tile_area] = TRUE
		// Throttled yield, not CHECK_TICK - see worldgen_yield() in worldgen_queue.dm
		SSovermap.worldgen_yield()

	for(var/area/planet_area as anything in areas_on_level)
		if(istype(planet_area, /area/overmap_encounter/planetoid))
			var/area/overmap_encounter/planetoid/planetoid_area = planet_area
			planetoid_area.zone_band = zone_band
		planet_area.RunTerrainPopulation()

/**
 * Y coordinate of the top of the strip the reserve docks occupy, clearance included.
 *
 * Both docks sit side by side along the bottom edge of the footprint, anchored
 * RESERVE_DOCK_DEFAULT_PADDING + 1 in from the corner - see create_docking_ports().
 * adjust_dock_to_shuttle() may rotate a port to fit a shuttle, but every rotation case
 * re-anchors on one of the port's own corners and swaps its height and width together, so
 * a rotated port covers the same rectangle it started in. This line therefore bounds every
 * turf a docked ship can end up on.
 */
/obj/structure/overmap/planet/proc/get_dock_strip_top_y(datum/space_level/zlevel)
	return zlevel.low_y + RESERVE_DOCK_DEFAULT_PADDING + RESERVE_DOCK_MAX_SIZE_SHORT + PLANET_DOCK_RUIN_CLEARANCE

/**
 * Flags the docking strip along the bottom of the planet NO_RUINS, so ruins only seed
 * above where ships park.
 *
 * try_to_place() rejects any placement whose footprint touches a NO_RUINS turf - the same
 * mechanism ruins use to keep off each other. Without it a ruin can land squarely on a
 * berth, and since an arriving shuttle overwrites the turfs it lands on, the ruin is
 * destroyed by the first ship to visit, taking its loot and mobs with it.
 *
 * The full width of the strip is taken rather than the two dock rectangles alone. They run
 * from low_x + 4 to low_x + 118 of a footprint that is at least PLANET_MIN_SIZE across, and
 * the slivers left either side are a handful of turfs wide - nothing fits in them anyway.
 */
/obj/structure/overmap/planet/proc/reserve_dock_strip(datum/space_level/surface_level)
	var/strip_top_y = min(get_dock_strip_top_y(surface_level), surface_level.high_y)
	var/turf/strip_bottom_left = locate(surface_level.low_x, surface_level.low_y, surface_level.z_value)
	var/turf/strip_top_right = locate(surface_level.high_x, strip_top_y, surface_level.z_value)
	if(!strip_bottom_left || !strip_top_right)
		return
	for(var/turf/reserved as anything in block(strip_bottom_left, strip_top_right))
		reserved.turf_flags |= NO_RUINS
		CHECK_TICK

/**
 * Seeds ruins on the surface, using the same budget and ore-vent preset the preloaded
 * planets got. Ruins are placed by rejection sampling against the whitelisted area, so
 * the cordon outside the planet keeps them inside the footprint on its own.
 *
 * The cave sibling area has to be whitelisted alongside the surface: terrain generation
 * has already run by this point and moved half the surface into /cave pockets (see
 * populate_planet_level()), and the cave type is a SIBLING of the surface type, not a
 * subtype, so the typecache doesn't cover it. With the surface alone, nearly every
 * candidate footprint touches a cave turf and is rejected - the seeder then burns its
 * full PLACEMENT_TRIES * PLACEMENT_TRIES sample budget per ruin scanning footprints
 * that can never pass. Roundstart seeding (setup_ruins()) correctly whitelists only the
 * surface because it runs BEFORE the terrain sweep carves any caves.
 */
/obj/structure/overmap/planet/proc/seed_planet_ruins(datum/space_level/surface_level, ruin_trait, area/surface_area_type)
	if(!ruin_trait)
		return
	var/list/ruin_templates = SSmapping.themed_ruins[ruin_trait]
	if(!length(ruin_templates))
		return
	seedRuins(
		list(surface_level.z_value),
		CONFIG_GET(number/lavaland_budget),
		list(surface_area_type, /area/overmap_encounter/planetoid/cave),
		ruin_templates,
		clear_below = TRUE,
		mineral_budget = 15,
		mineral_budget_update = OREGEN_PRESET_LAVALAND,
	)

/**
 * Runs terrain generation over the areas a ruin brought with it.
 *
 * Several mining ruins ship /turf/open/genturf tiles and leave their own area's
 * generator to fill them in. Roundstart gets that for free. Ruins are seeded before
 * the world-wide generation sweep, which is why SSmapping runs them in that order.
 * A planet is built the other way round: its terrain is already down before a ruin
 * lands on it, so a ruin's own areas have to be generated here or those tiles sit
 * there as bare genturf for the rest of the round.
 *
 * The planet's own areas are skipped, they generated at build time, and a second
 * pass would rewrite the surface out from under everything standing on it. So is any
 * area whose generator has already run: map_generator stops being a typepath the
 * moment RunTerrainGeneration() instantiates it.
 */
/obj/structure/overmap/planet/proc/generate_ruin_terrain(datum/space_level/level)
	var/list/generated_areas = list()
	for(var/turf/tile as anything in level.get_block())
		var/area/tile_area = tile.loc
		if(isnull(tile_area) || generated_areas[tile_area])
			continue
		generated_areas[tile_area] = TRUE
		if(istype(tile_area, /area/overmap_encounter/planetoid))
			continue
		if(!ispath(tile_area.map_generator))
			continue
		tile_area.RunTerrainGeneration()
		CHECK_TICK

/// Lava and ice planets get their rivers, bounded to the planet's footprint.
/// The generic cave area is whitelisted too: terrain generation carves rock pockets out
/// into one, and a river that stopped dead at every outcrop would look wrong.
/obj/structure/overmap/planet/proc/spawn_planet_rivers_for(datum/space_level/surface_level, ruin_trait, area/surface_area_type)
	var/river_turf
	switch(ruin_trait)
		if(ZTRAIT_LAVA_RUINS)
			river_turf = /turf/open/lava/smooth/lava_land_surface/planetary
		if(ZTRAIT_ICE_RUINS)
			river_turf = /turf/open/lava/plasma/planetary
	if(!river_turf)
		return
	spawn_planet_rivers(
		surface_level.z_value,
		4,
		river_turf,
		list(surface_area_type, /area/overmap_encounter/planetoid/cave),
		surface_level.low_x,
		surface_level.low_y,
		surface_level.high_x,
		surface_level.high_y,
	)

/**
  * Creates docking ports for an existing mapzone that doesn't have them.
  * Used for pre-configured planets that have z-levels but no docking ports.
  */
/obj/structure/overmap/planet/proc/create_docking_ports()
	if(!mapzone || !length(mapzone.z_levels))
		return
	var/datum/space_level/zlevel = mapzone.z_levels[1]
	if(!zlevel)
		return

	// locates the first dock in the bottom left, accounting for padding and the border
	var/turf/primary_docking_turf = locate(
		zlevel.low_x + RESERVE_DOCK_DEFAULT_PADDING + 1,
		zlevel.low_y + RESERVE_DOCK_DEFAULT_PADDING + 1,
		zlevel.z_value
	)
	// now we need to offset to account for the first dock
	var/turf/secondary_docking_turf = locate(
		primary_docking_turf.x + RESERVE_DOCK_MAX_SIZE_LONG + RESERVE_DOCK_DEFAULT_PADDING,
		primary_docking_turf.y,
		primary_docking_turf.z
	)

	reserve_dock = new /obj/docking_port/stationary(primary_docking_turf)
	reserve_dock.dir = NORTH
	reserve_dock.name = "\improper Uncharted Space"
	reserve_dock.height = RESERVE_DOCK_MAX_SIZE_SHORT
	reserve_dock.width = RESERVE_DOCK_MAX_SIZE_LONG
	reserve_dock.dheight = 0
	reserve_dock.dwidth = 0

	reserve_dock_secondary = new /obj/docking_port/stationary(secondary_docking_turf)
	reserve_dock_secondary.dir = NORTH
	reserve_dock_secondary.name = "\improper Uncharted Space"
	reserve_dock_secondary.height = RESERVE_DOCK_MAX_SIZE_SHORT
	reserve_dock_secondary.width = RESERVE_DOCK_MAX_SIZE_LONG
	reserve_dock_secondary.dheight = 0
	reserve_dock_secondary.dwidth = 0

/obj/structure/overmap/planet/attack_ghost(mob/user)
	if(reserve_dock)
		user.forceMove(get_turf(reserve_dock))
		return TRUE
	else if(mapzone)
		var/datum/space_level/z_level = mapzone.z_levels[1]
		if(!z_level)
			return
		var/planet_turf = locate(round(world.maxx/2), round(world.maxy/2), z_level.z_value)
		if(!planet_turf)
			return
		user.forceMove(get_turf(planet_turf))
	else
		return

/**
 * Alters the position and orientation of a stationary docking port to ensure that any mobile port small enough can dock within its bounds
 */
/obj/structure/overmap/planet/proc/adjust_dock_to_shuttle(obj/docking_port/stationary/dock_to_adjust, obj/docking_port/mobile/shuttle)
	adjust_reserve_dock_to_shuttle(dock_to_adjust, shuttle)
	if(shuttle.height > dock_to_adjust.height || shuttle.width > dock_to_adjust.width)
		CRASH("Shuttle cannot fit in dock!")

/obj/structure/overmap/planet/get_dock_description()
	return "[display_name || name] (planetfall)"

/obj/structure/overmap/planet/ship_act(mob/user, obj/structure/overmap/ship/acting, obj/structure/overmap/ship/optional_partner)
	// dock() refuses interdicted ships only after the dock slot below is claimed -
	// refuse up front instead
	if(acting.is_interdicted)
		if(user)
			to_chat(user, span_warning("Cannot dock while interdicted!"))
		else
			acting.ship_notify("Cannot dock while interdicted!", "DOCKING", SHIP_NOTIFY_WARNING, 'voidcrew/sound/warn.ogg', 25)
		return
	if(concerned || unloading)
		var/busy_message = unloading ? "Orbit is being recalculated, stand by." : "Too much traffic, try again later!"
		if(user)
			to_chat(user, "<span class='notice'>[busy_message]</span>")
		else
			acting.ship_notify("Approach on [display_name || name] aborted: [busy_message]", "DOCKING", SHIP_NOTIFY_WARNING, 'voidcrew/sound/warn.ogg', 25)
		return

	// Interior not generated yet: request it in the background and return the helm
	// immediately. The ship stays fully controllable; request_site_load() broadcasts
	// the survey's progress and resumes this approach itself when the planet charts.
	if(!loaded)
		acting.request_site_load(src, user)
		return

	concerned = TRUE
	// Someone is coming back before the countdown ran out - the interior stays put
	cancel_despawn_timer()

	// Lobby-prebuilt planets own a mapzone but only stand their docks up when visited
	if(mapzone && !reserve_dock)
		create_docking_ports()

	if(user)
		balloon_alert(user, "starting docking process..")

	var/is_survey = FALSE
	var/dock_to_use = null
	// Berths do not stay where they were built - see reset_free_reserve_docks_for(). Put the
	// free ones back before choosing one, or the last visitor's offset is carried into this
	// placement and compounds on every arrival.
	reset_free_reserve_docks_for(reserve_dock, reserve_dock_secondary, first_dock_taken, second_dock_taken)
	// Port destinations are set by our survey console
	if (acting.shuttle.port_destinations)
		dock_to_use = acting.shuttle.port_destinations
		is_survey = TRUE
	else
		if(!reserve_dock.get_docked() && !first_dock_taken)
			dock_to_use = reserve_dock //This assigns what port the shuttle will eventually try to dock into, but it does not immediately update the port's docked status
			first_dock_taken = TRUE
			acting.dock_index = 1
		else if(!reserve_dock_secondary.get_docked() && !second_dock_taken)
			dock_to_use = reserve_dock_secondary
			second_dock_taken = TRUE
			acting.dock_index = 2
	if(!dock_to_use)
		concerned = FALSE
		// Two berths is a hard layout limit: PLANET_MIN_SIZE is sized to exactly two
		// max-size berth rectangles plus padding (see planet_defines.dm), so a third
		// fixed berth cannot fit on the dock strip, and packing berths by actual hull
		// size instead is a rework of the shared reserve-dock lifecycle (dock_index
		// release flags, cargo shuttle claims, reserve-home resets), not a tweak.
		// Until that lands, at least tell the refused crew who is occupying the
		// ground and what their options are, instead of a bare "occupied".
		var/list/parked_names = list()
		for(var/obj/docking_port/stationary/berth in list(reserve_dock, reserve_dock_secondary))
			var/obj/docking_port/mobile/parked = berth.get_docked()
			if(!parked)
				continue
			// Not everything that parks here is a player hull - a cargo delivery holds a
			// berth too, and its port is a stock /supply one with no current_ship var at
			// all, so the hull name has to come off an istype'd local rather than a
			// blind typed cast.
			var/parked_name = "[parked]"
			if(istype(parked, /obj/docking_port/mobile/voidcrew))
				var/obj/docking_port/mobile/voidcrew/hull_port = parked
				if(hull_port.current_ship)
					parked_name = "[hull_port.current_ship]"
			parked_names += parked_name
		var/blocked_by = length(parked_names) ? " The berths are taken by [english_list(parked_names)]." : ""
		var/no_berths_message = "No free landing berths.[blocked_by] Try again when one lifts off - ships abandoned on the surface are eventually cleared away - or plot a custom landing site with an upgraded orbital survey console."
		if(user)
			to_chat(user, span_warning(no_berths_message))
		else
			acting.ship_notify(no_berths_message, "DOCKING", SHIP_NOTIFY_WARNING, 'voidcrew/sound/warn.ogg', 25)
		return

	if(!is_survey)
		adjust_dock_to_shuttle(dock_to_use, acting.shuttle)
	// dock() only returns a string when it refuses; a successful start is
	// announced to the whole crew by ship_notify()
	var/dock_result = acting.dock(src, dock_to_use)
	if(dock_result)
		if(user)
			to_chat(user, span_notice("[dock_result]"))
		else
			acting.ship_notify("[dock_result]", "DOCKING", SHIP_NOTIFY_WARNING, 'voidcrew/sound/warn.ogg', 25)
	concerned = FALSE
	// For request docking
	if (optional_partner)
		ship_act(user, optional_partner)

/**
 * Whether this planet's interior is genuinely abandoned and safe to delete, ignoring
 * the in-progress flags the caller manages itself.
 *
 * Split out because it has to be asked twice: once before joining the worldgen queue,
 * and again once the claim comes back. Waiting in that queue takes real time, and a
 * planet that was empty when it got in line need not still be empty at the front of it.
 */
/obj/structure/overmap/planet/proc/can_release_interior()
	if(preserve_level || !mapzone)
		return FALSE

	// Never mid-build: build_planet() assigns mapzone long before the surface is done,
	// and worldgen_claim() is reentrant by requester, so a teardown fired during the
	// load would be granted the queue instantly (both claim as src) and sweep the
	// level out from under the generator.
	if(loading)
		return FALSE

	if(first_dock_taken || second_dock_taken)
		return FALSE

	// Check if any ships are still docked inside (catches race conditions with async unload)
	for(var/obj/structure/overmap/ship/docked_ship in contents)
		return FALSE

	if(length(mapzone.get_mind_mobs()))
		return FALSE //Dont fuck over stranded people? tbh this shouldn't be called on this condition, instead of bandaiding it inside

	return TRUE

/**
  * Unloads the reserve, deletes the linked docking port, and moves to a random location if there's no client-having, alive mobs.
  */
/obj/structure/overmap/planet/proc/unload_level()
	if(concerned || unloading)
		return

	if(!can_release_interior())
		return

	var/datum/worldgen_probe/teardown_probe = worldgen_begin("planet-teardown", "[display_name || name]")

	// TERRAIN teardown is as expensive as generation and just as unwelcome alongside
	// it: the contents sweep in clear_reservation() cannot yield, so landing it in the
	// middle of somebody else's build stalls both - queue it. Queued on the same test
	// the build queued on: terrain planets AND mapgen-bearing flat encounters (the
	// large asteroid's cave level); tearing down unqueued what was built queued lands
	// that sweep on top of whatever the queue is currently building. Plain flat
	// encounters (weak signals, crashed ships) are cheap by comparison and, by design
	// rule, may never wait behind a planet build.
	var/queue_teardown = is_terrain_planet() || (planet && initial(planet.mapgen))
	if(queue_teardown)
		// The in-progress flags are only raised once the claim is granted: the wait can
		// run for minutes, and holding them through it would read "Orbit is being
		// recalculated" to every arriving ship for a teardown that may yet stand down.
		// An arrival mid-wait claims a berth, which the re-check below refuses on.
		//
		// A queue timeout must re-arm itself: the despawn timer that got us here has
		// already fired, so giving up silently would leave the level resident until
		// roundend.
		if(!SSovermap.worldgen_claim(src, "planet teardown ([display_name || name])"))
			worldgen_end(teardown_probe, "queue-timeout")
			addtimer(CALLBACK(src, PROC_REF(attempt_despawn)), 30 SECONDS, TIMER_UNIQUE)
			return

		unloading = TRUE
		concerned = TRUE //Prevent someone to act with this while it reloads

		// No ship can have docked and STAYED past the re-check - but a ghost role, a
		// drop pod or a transporter beam is enough to put someone back down there, and
		// we are about to delete every atom on the level.
		if(!can_release_interior())
			SSovermap.worldgen_release(src)
			unloading = FALSE
			concerned = FALSE
			worldgen_end(teardown_probe, "aborted")
			return
	else
		unloading = TRUE
		concerned = TRUE //Prevent someone to act with this while it reloads

	if(planet_key)
		SSplanet_mobs.unregister_planet(planet_key)
		planet_key = null

	remove_docks()
	remove_mapzone(throttled = queue_teardown) //Take a lot of time

	// Released here rather than at the end: the relocation below only moves a token
	// around the overmap grid and has no business holding up the next build.
	if(queue_teardown)
		SSovermap.worldgen_release(src)

	// Back to an undiscovered contact somewhere else in the same band. The band is kept
	// so a planet the crew rated as red-zone dangerous doesn't quietly turn into a green
	// one, and so its terrain scales the same way when it is next generated.
	var/turf/new_home = SSovermap.get_unused_overmap_square_in_zone_band(zone_band, tries = 80) || SSovermap.get_unused_overmap_square()
	if(new_home)
		forceMove(new_home)

	loaded = FALSE
	visited = FALSE
	first_dock_taken = FALSE
	second_dock_taken = FALSE
	unloading = FALSE
	concerned = FALSE //Now it can be raided again
	worldgen_end(teardown_probe)
	return TRUE

/// A wedged build or teardown leaves these set, and every entry point to the planet
/// tests them - the contact would stay "survey in progress" for the rest of the round.
/// Ships registered for the completion signal get the failure here too: the job that
/// was going to send it is the thing that just died, and an unanswered registration
/// holds its ship's approach forever.
/obj/structure/overmap/planet/on_worldgen_timeout()
	loading = FALSE
	unloading = FALSE
	concerned = FALSE
	SEND_SIGNAL(src, COMSIG_VOIDCREW_SITE_LOAD_FINISHED, FALSE)

/// `throttled` = whether the sweep shares the queued worldgen job's tick budget;
/// unqueued flat-encounter teardowns pass FALSE - see worldgen_yield().
/obj/structure/overmap/planet/proc/remove_mapzone(throttled = TRUE)
	if(mapzone)
		mapzone.clear_reservation(throttled)
		mapzone.taken = FALSE
		mapzone = null

// ---- Planet lifecycle: release the interior once everybody has left ----

/// A ship arriving cancels any pending unload, and we watch it for the trip home.
/obj/structure/overmap/planet/Entered(atom/movable/arrived, atom/old_loc, list/atom/old_locs)
	. = ..()
	if(!istype(arrived, /obj/structure/overmap/ship))
		return
	RegisterSignal(arrived, COMSIG_VOIDCREW_SHIP_UNDOCKED, PROC_REF(on_ship_undocked))
	cancel_despawn_timer()

/// Signal handler - a ship that was docked here has finished undocking.
/obj/structure/overmap/planet/proc/on_ship_undocked(obj/structure/overmap/ship/source)
	SIGNAL_HANDLER
	UnregisterSignal(source, COMSIG_VOIDCREW_SHIP_UNDOCKED)
	// Let the shuttle finish moving out before deciding the planet is empty
	addtimer(CALLBACK(src, PROC_REF(check_start_despawn)), 3 SECONDS)

/// Starts the countdown, if the planet really is empty.
/obj/structure/overmap/planet/proc/check_start_despawn()
	if(preserve_level || unloading || !mapzone || despawn_timer_id)
		return
	if(first_dock_taken || second_dock_taken)
		return
	for(var/obj/structure/overmap/ship/docked_ship in contents)
		return
	if(length(mapzone.get_mind_mobs()))
		return
	despawn_timer_id = addtimer(CALLBACK(src, PROC_REF(attempt_despawn)), PLANET_DESPAWN_TIMER, TIMER_STOPPABLE)

/obj/structure/overmap/planet/proc/cancel_despawn_timer()
	if(!despawn_timer_id)
		return
	deltimer(despawn_timer_id)
	despawn_timer_id = null

/// Countdown elapsed. unload_level() re-checks everything before it wipes anything.
/obj/structure/overmap/planet/proc/attempt_despawn()
	despawn_timer_id = null
	if(!unload_level())
		return
	log_mapping("SSovermap: Planet '[name]' unloaded after being abandoned, relocated to ([x], [y])")

/obj/structure/overmap/planet/proc/remove_docks()
	if(reserve_dock)
		qdel(reserve_dock, TRUE)
		reserve_dock = null
	if(reserve_dock_secondary)
		qdel(reserve_dock_secondary, TRUE)
		reserve_dock_secondary = null

