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
	/// This site's rectangle inside the map zone's level - the slot it was dealt. Every
	/// "is this turf mine?" question is answered from here rather than from the z-level,
	/// which a packed level shares with up to three neighbours. See /datum/map_footprint.
	var/datum/map_footprint/footprint
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
	/// This planet's entry in SSweather's site registry - its climate, its storm, its
	/// cooldown. Registered in apply_planet_level_traits(), torn down in remove_mapzone().
	var/datum/weather_site/weather_site
	/// The overmap zone band this planet belongs to. Its terrain is scaled to this, so
	/// it is kept across relocations rather than re-rolled from wherever it lands.
	var/zone_band
	/// Suffix telling this planet apart from the others of its type ("II", "III"...).
	/// Null when the round only has one of each. Applied in apply_planet_identity().
	var/designation
	/// Key identifying this planet's SSplanet_mobs tracker while it is loaded
	var/planet_key
	/// Stoppable timer id for the unload countdown
	var/despawn_timer_id
	/// TRUE while the planet is tearing its z-levels down, blocks ship_act() and reload
	var/unloading = FALSE

/obj/structure/overmap/planet/get_interior_footprint()
	return footprint

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
	//
	// COMSIG_VOIDCREW_PLANET_LOADED goes out on these branches too, but only on the
	// FALSE -> TRUE transition. That signal means "this planet's interior just became
	// available", and it is the one-shot every waiting-for-the-site listener hangs off:
	// mission field objectives (/datum/mission_target/planet/notify_when_loaded), the
	// survey computer, the drug-run lab hook. Planets are pre-built during the lobby, so
	// `mapzone` is already standing on almost every planet in the round and the first ship
	// to dock one comes through here rather than through the build below - which used to
	// send SITE_LOAD_FINISHED and nothing else. A mission whose field step had already
	// armed and was waiting on the load callback therefore never spawned its objective:
	// no creature on the surface, no quest atom, and a GPS tapped on the mission board
	// reading "linked - no objective marked yet" for the rest of the round.
	if(mapzone && !reserve_dock)
		var/became_loaded = !loaded
		create_docking_ports()
		loaded = TRUE
		if(became_loaded)
			SEND_SIGNAL(src, COMSIG_VOIDCREW_PLANET_LOADED, TRUE)
		SEND_SIGNAL(src, COMSIG_VOIDCREW_SITE_LOAD_FINISHED, TRUE)
		return
	if(mapzone)
		var/became_loaded = !loaded
		loaded = TRUE
		if(became_loaded)
			SEND_SIGNAL(src, COMSIG_VOIDCREW_PLANET_LOADED, TRUE)
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
		if(!build_planet(load_probe))
			// Refused before it started: no free slot, or world.maxz at its ceiling. The
			// slot has already been handed back, so nothing here is holding memory - but a
			// silent success would leave `loaded` set on a planet with no interior and
			// every later Dock press would bounce off it.
			SSovermap.worldgen_release(src)
			loading = FALSE
			worldgen_end(load_probe, "no-interior")
			site_load_refused_for_capacity(waiting_ship)
			SEND_SIGNAL(src, COMSIG_VOIDCREW_SITE_LOAD_FINISHED, FALSE)
			return "No charting capacity free - try again shortly."
		// Caves and ruin interiors queue a lighting object apiece; until SSlighting drains
		// them the crew docks into black rooms. Hold the dock (callers show "survey in
		// progress") so arrivals land on a rendered surface.
		//
		// Scoped to OUR footprint. The SSlighting queues are global and the rest of the
		// world feeds them nonstop, so the unscoped version waited on the entire server
		// going quiet and simply burned its whole cap on every planet loaded after
		// roundstart - 90 seconds a planet, measured on every ice planet in round 1068.
		//
		// Deliberately inside the worldgen claim. Releasing first would let the next
		// build start pouring its own light sources onto the same level, and this wait
		// would never see the bottom of it.
		SSovermap.wait_for_lighting_settle(cap = 90 SECONDS, wait_footprint = footprint)
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
		var/list/dynamic_encounter_values = SSovermap.spawn_dynamic_encounter(planet, TRUE, ruin_type = template, zone_band = SSovermap.get_zone_band_for_turf(get_turf(src)), throttled = queued_encounter, tenant_owner = src)
		if(queued_encounter)
			SSovermap.worldgen_release(src)
		// A failed build must drop the loading flag on its way out: this branch has
		// no worldgen-queue watchdog, so a wedged flag reads "survey in progress"
		// for the rest of the round with nothing left to ever clear it.
		if(length(dynamic_encounter_values) < 3 || !dynamic_encounter_values[1] || !dynamic_encounter_values[2])
			loading = FALSE
			log_mapping("SSovermap: dynamic encounter build failed for '[display_name || name]' at ([x],[y]) - dock aborted")
			worldgen_end(load_probe, "failed")
			// Almost always "no free map slot": world.maxz is at its ceiling and nothing has
			// recycled yet. Say so and retry on our own timer rather than leaving the crew
			// with a Dock button that silently does nothing.
			site_load_refused_for_capacity(waiting_ship)
			SEND_SIGNAL(src, COMSIG_VOIDCREW_SITE_LOAD_FINISHED, FALSE)
			return "Dock site failed to initialize, try again."
		mapzone = dynamic_encounter_values[1]
		reserve_dock = dynamic_encounter_values[2]
		reserve_dock_secondary = dynamic_encounter_values[3]
		// The slot this encounter was dealt. Everything that used to ask "is this on my
		// z-level" asks this instead - on a packed level the z is shared with up to three
		// other encounters.
		footprint = LAZYACCESS(dynamic_encounter_values, 4)
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
 *
 * Returns TRUE when the planet actually got an interior. FALSE means the build was refused
 * before it started - no free map slot, no z-level, or world.maxz at its ceiling - and the
 * caller must not report a loaded planet. Every FALSE path hands the slot back first.
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
	// Claimed here, before anything below is allowed to sleep, and not after the level
	// is minted. add_new_zlevel() blocks on its own spinlock whenever another level is
	// being made, and an unclaimed slot held across that sleep is exactly what
	// find_free_slot() hands to the next caller - two encounters on one footprint,
	// and whichever is abandoned first wipes the other's live surface.
	//
	// ONE class for every terrain planet, biome irrelevant: a lava, an ice and two jungle
	// planets pack onto one level. The thing that used to force a per-biome key was
	// ZTRAIT_BASETURF - one value per z, and the ground every dug-up turf falls back to - and
	// that is now carried on the footprint below and resolved per turf by
	// footprint_baseturf_for_turf(). Capacity 4 (map_slot_capacity_for_class).
	footprint = SSovermap.claim_free_slot(MAP_TENANT_CLASS_PLANET, src, zone_name = "Planet")
	if(isnull(footprint))
		log_mapping("SSovermap: planet '[display_name || name]' could not claim a map slot - build aborted")
		worldgen_end(build_probe, "no-slot")
		return FALSE
	// A unique native alliance per footprint. Enabled before any turf population or ruin
	// load so every living mob created on this surface can inherit it in Initialize().
	footprint.enable_planetary_faction()
	// Stamped before a single turf of ours exists, and before anything below can sleep.
	// Every scrape, dig, explosion and floor break inside this rectangle bottoms out here
	// for the rest of the planet's life, whoever else is on the level.
	footprint.baseturf = ground_baseturf
	var/datum/map_zone/zone = footprint.zone
	mapzone = zone
	// Whether WE are the tenant that publishes this level's traits, decided here rather than
	// inside apply_planet_level_traits(). claim_free_slot() is atomic and does not sleep, so
	// right now "the zone holds one tenant" is exactly "that tenant is me". Derived after the
	// add_new_zlevel() below it would not be: that call sleeps, a co-tenant claiming during
	// the sleep is attached by add_space_level(), and both planets would then see two
	// footprints, decide somebody else had already published, and leave a recycled level
	// carrying the PREVIOUS occupant's traits - including no ZTRAIT_MINING.
	var/level_first_tenant = zone.used_slot_count() <= 1

	if(length(zone.z_levels))
		// A recycled zone, still carrying the previous occupant's traits
		surface_level = zone.z_levels[1]
	else if(SSmapping.at_z_level_ceiling())
		// claim_free_slot() refuses to mint a zone at the ceiling, but a zone dealt from the
		// recycled pool can still turn out to have no level yet. Hand the slot straight back
		// rather than leaving it claimed against nothing - the caller retries.
		log_mapping("SSovermap: planet '[display_name || name]' refused - world.maxz is at its configured ceiling and its zone has no level yet")
		var/datum/map_footprint/unlevelled_footprint = footprint
		footprint = null
		mapzone = null
		zone.release_slot(unlevelled_footprint)
		worldgen_end(build_probe, "z-ceiling")
		return FALSE
	else
		surface_level = SSmapping.add_new_zlevel("Planet surface", surface_traits)
		zone.add_space_level(surface_level)
	footprint.attach_level(surface_level)

	if(!apply_planet_level_traits(surface_level, surface_traits, weather_trait, level_first_tenant))
		// The level is unusable (no level at all). A trait MISMATCH is no longer a failure:
		// a later tenant of any biome takes the level as it finds it, because the ground it
		// publishes is its footprint's, not the level's. See apply_planet_level_traits().
		log_mapping("SSovermap: planet '[display_name || name]' could not apply level traits to z[surface_level?.z_value] - build aborted")
		var/datum/map_footprint/rejected_footprint = footprint
		footprint = null
		mapzone = null
		zone.release_slot(rejected_footprint)
		worldgen_end(build_probe, "no-level")
		return FALSE

	// Confine the planet to its OWN slot and wall off everything outside the lattice.
	//
	// Anchored, not centred: set_bounds() centres the rect on the level, and there is only
	// one centre - a packed co-tenant has to keep the rectangle it was dealt or it lands on
	// top of its neighbour. min() against the slot for the same reason: a planet datum
	// asking for more than MAP_SLOT_SIDE must be clamped down, never grown into the gutter.
	// A whole-level tenant (a SOLO or roundstart planet) still centres, exactly as before.
	if(footprint.is_whole_level())
		surface_level.set_bounds(planet_size, planet_size)
	else
		surface_level.set_bounds_at(
			footprint.low_x,
			footprint.low_y,
			min(planet_size, footprint.get_width()),
			min(planet_size, footprint.get_height()),
			footprint,
		)
	var/area/surface_area = surface_level.fill_in(area_override = surface_area_type, footprint = footprint)
	// Scope the weather site to our surface the moment that surface exists, rather than
	// waiting for the full owned-areas list further down. Until this line the site owns
	// nothing, and an area-scoped site that owns nothing is held out of the scheduler
	// (SSweather.fire() -> awaiting_owned_areas()) - this is the line that arms us. The cave
	// areas join the list once terrain has carved them.
	if(weather_site && surface_area)
		weather_site.add_owned_area(surface_area)
	// Once per level, from the complement of the whole lattice - a second tenant arriving
	// finds the band already painted and never repaints over live ground.
	surface_level.place_cordon()

	// Terrain first: this lays biome turfs down and tags each one with the biome it came
	// from, which everything below reads.
	var/datum/worldgen_probe/stage_probe = worldgen_begin("stage", "terrain", build_probe.id)
	surface_area?.RunTerrainGeneration()
	worldgen_end(stage_probe)

	// Register before populating - population hands its mob spawn turfs to SSplanet_mobs.
	// The footprint has already been narrowed to planet_size by set_bounds() above, so the
	// tracker gets the planet's real rectangle; the band is carried across rather than
	// looked up per z, which only ever answered for roundstart planets.
	planet_key = "[REF(src)]"
	SSplanet_mobs.register_planet(planet_key, surface_level.z_value, footprint, zone_band)

	stage_probe = worldgen_begin("stage", "populate", build_probe.id)
	populate_planet_level(surface_level)
	worldgen_end(stage_probe)

	// One walk of our own block, used twice: the ruin seeder whitelists these instances, and
	// the weather site storms only these areas. Without the second, setup_weather_areas()
	// falls back to get_areas(/area/overmap_encounter/planetoid), which matches a co-tenant's
	// surface and caves just as happily as ours - one planet's ash storm would paint all four.
	var/list/owned_planet_areas = get_owned_planet_areas(surface_level)
	if(weather_site)
		var/list/storm_areas = list()
		for(var/area/owned_area as anything in owned_planet_areas)
			storm_areas += owned_area
		weather_site.set_owned_areas(storm_areas)

	// Before ruins, not after: seedRuins() reads NO_RUINS while it picks placements, and a
	// flag set afterwards would be too late to move anything.
	reserve_dock_strip(surface_level)

	stage_probe = worldgen_begin("stage", "ruins", build_probe.id)
	seed_planet_ruins(surface_level, ruin_trait, surface_area_type, owned_planet_areas)
	worldgen_end(stage_probe)
	generate_ruin_terrain(surface_level)
	light_ruin_terrain(surface_level, surface_area)

	stage_probe = worldgen_begin("stage", "rivers", build_probe.id)
	spawn_planet_rivers_for(surface_level, ruin_trait, surface_area_type)
	worldgen_end(stage_probe)

	// Mapped ruin mobs normally inherited during Initialize(). This post-load pass also
	// covers any loader or generator that initialized an occupant before registration.
	footprint.add_planetary_faction_to_existing_mobs()

	create_docking_ports()

	log_mapping("SSovermap: Built planet '[name]' band [zone_band] on z [surface_level.z_value], [planet_size]x[planet_size]")
	worldgen_end(build_probe)
	return TRUE

/**
 * Points a z-level's traits at this planet and registers the planet's own weather site.
 *
 * Idempotent, because a level can hold up to four planets of ANY MIX of biomes:
 *
 * - The FIRST tenant on the level owns the trait dict. It clears whatever the last occupant
 *   left behind and publishes ZTRAIT_BASETURF, ZTRAIT_MINING, ZTRAIT_LINKAGE and the ruin
 *   trait, plus the climate traits the ambience element reads.
 * - A LATER tenant, of any biome, takes the level exactly as it finds it: it reads nothing,
 *   asserts nothing and writes nothing into the trait dict. It does not need to. Everything
 *   in there is either the same answer for every planet (ZTRAIT_MINING, ZTRAIT_LINKAGE),
 *   read from the planet's own pool rather than from the level (the ruin trait - see
 *   seed_planet_ruins(), which indexes SSmapping.themed_ruins with its OWN ruin_type), or
 *   superseded per-tenant:
 *
 *   * ZTRAIT_BASETURF is now only a FALLBACK. The authority for "what does a hole in the
 *     ground bottom out into" is /datum/map_footprint.baseturf, stamped in build_planet()
 *     and resolved per turf by footprint_baseturf_for_turf() inside /turf/ChangeTurf. That
 *     is what makes a lava planet and an ice planet co-tenants without either crew ever
 *     scraping up the other's ground.
 *   * weather is a per-tenant /datum/weather_site (below) with its own weight table,
 *     cooldown, storm and owned areas.
 *
 *   The level's climate traits therefore stay whatever the first tenant published. They
 *   feed exactly one thing: /datum/element/weather_listener's z-keyed ambience loop. A
 *   second tenant of a different biome hears the first one's weather ambience - a cosmetic
 *   residue, and the ONLY one mixing biomes leaves. Adding the second climate to the level
 *   instead would be worse, not better: level traits are also how admin/global weather picks
 *   its z-levels (SSweather.run_weather -> levels_by_trait), so a lava level would become
 *   eligible for snowstorms.
 *
 * Weather is per tenant either way. Every planet registers its OWN /datum/weather_site with
 * its own weight table, cooldown and storm, scoped to its own footprint rectangle - so a
 * storm on one packed planet is not a storm on the other three.
 *
 * * first_tenant - whether this planet is the one that publishes the level's traits. Passed
 *   in by build_planet(), which knows it at claim time; null recomputes it from the level's
 *   footprint register, which is only safe when nothing has slept since the claim.
 *
 * Returns TRUE when the level is usable by this planet, FALSE only when there is no level.
 */
/obj/structure/overmap/planet/proc/apply_planet_level_traits(datum/space_level/level, list/new_traits, weather_trait, first_tenant = null)
	if(isnull(level))
		return FALSE
	// build_planet() decides this at claim time, which is the only race-free moment (see the
	// comment there). Null means "work it out from the level": our own footprint is attached
	// by now, so that reads as "nobody else is registered here".
	if(isnull(first_tenant))
		first_tenant = length(level.footprints) <= 1

	if(first_tenant)
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

		// The previous occupant's site, storm and cooldown. Only the first tenant may do
		// this: unregister_z_level() kills every site on the level, co-tenants' included.
		SSweather.unregister_z_level(level.z_value)

	// Red-band planets carry radiation storms on top of their own climate. Both sit in the
	// site's weight table and SSweather picks between them by probability (see
	// /datum/weather/rad_storm/planetary). The trait-dict reassignment above is what clears
	// this from a recycled level that used to be a red planet.
	var/list/weather_traits = list()
	if(weather_trait)
		weather_traits[weather_trait] = TRUE
	if(zone_band == ZONE_RED)
		weather_traits[ZTRAIT_RADSTORM] = TRUE

	// Level traits are the AMBIENCE channel (/datum/element/weather_listener reads climate
	// off the z-level), and there is one of those per level, so only the first tenant sets
	// it. A co-tenant of a different biome deliberately does NOT add its own: the same trait
	// dict is what SSweather.run_weather() and levels_by_trait() use to pick z-levels for
	// admin and global weather, and publishing two climates on one level would make each
	// planet eligible for the other's storms. The per-tenant weather_site below is where a
	// co-tenant's real weather lives; what it loses is the ambience loop.
	if(first_tenant)
		for(var/climate_trait in weather_traits)
			level.set_trait(climate_trait, TRUE)

	weather_site = SSweather.register_weather_site_for_level(
		level,
		weather_traits,
		SSovermap_zones.weather_downtime_multiplier_for_zone(zone_band),
		"planet-[REF(src)]",
	)

	// Our storms live and die inside the areas we own, and we have none yet: the surface area
	// is not created until fill_in() returns, minutes from here. SSweather makes a site
	// eligible the moment it is registered, so without this flag the storm rolled during our
	// own build would find no owned areas, fall back to
	// get_areas(/area/overmap_encounter/planetoid) and hit every planet on this level.
	// See /datum/weather_site.area_scoped.
	weather_site?.set_area_scoped()

	// Scope the site to our rectangle, so a storm telegraphs, paints and alerts on THIS
	// planet only. A whole-level tenant deliberately stays rect-less: a footprinted site is
	// invisible to SSweather's z-keyed legacy entry points (get_level_weather_site() and
	// friends), which is exactly right for a packed tenant and exactly wrong for a planet
	// that is the level.
	if(weather_site && footprint && !isnull(footprint.low_x) && !footprint.is_whole_level())
		weather_site.add_footprint_rect(footprint.low_x, footprint.low_y, footprint.high_x, footprint.high_y)

	return TRUE

/**
 * Runs terrain population over every area inside THIS planet's footprint.
 *
 * It can't just be the area we filled in with: generate_terrain() carves its cave
 * pockets out into freshly-made cave areas, and those hold most of the turfs by the
 * time population runs. Roundstart got this for free by sweeping every area in the
 * world; here the areas are found from the planet's own turfs.
 *
 * The footprint, not the level: a packed level carries up to four planets, and the level
 * block is all four of them plus the cordon. Walking it would be 65k iterations instead of
 * 15k, would run population a second time over ground a neighbour is standing on, and -
 * worst - would stamp OUR zone_band onto THEIR area instance, re-tiering their loot, their
 * ore yields and their storm severity to our danger rating.
 */
/obj/structure/overmap/planet/proc/populate_planet_level(datum/space_level/level)
	var/list/block_turfs = footprint?.get_block() || level?.get_block()
	if(!block_turfs)
		return
	var/list/areas_on_level = list()
	for(var/turf/tile as anything in block_turfs)
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
 * ABSOLUTE Y coordinate of the top of the strip this planet's reserve docks occupy,
 * clearance included.
 *
 * Both docks sit side by side along the bottom edge of the footprint, anchored
 * RESERVE_DOCK_DEFAULT_PADDING + 1 in from the corner - see create_docking_ports().
 * adjust_dock_to_shuttle() may rotate a port to fit a shuttle, but every rotation case
 * re-anchors on one of the port's own corners and swaps its height and width together, so
 * a rotated port covers the same rectangle it started in. This line therefore bounds every
 * turf a docked ship can end up on.
 *
 * Measured from the FOOTPRINT's low edge, matching create_docking_ports(). The level's low
 * edge is the whole packed lattice, so on a shared level it would name a strip in the
 * bottom-left tenant's ground no matter which planet asked. `zlevel` stays in the signature
 * as the fallback for a planet with no footprint.
 */
/obj/structure/overmap/planet/proc/get_dock_strip_top_y(datum/space_level/zlevel)
	var/anchor_low_y = isnull(footprint?.low_y) ? zlevel?.low_y : footprint.low_y
	if(isnull(anchor_low_y))
		return null
	return anchor_low_y + RESERVE_DOCK_DEFAULT_PADDING + RESERVE_DOCK_MAX_SIZE_SHORT + PLANET_DOCK_RUIN_CLEARANCE

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
 *
 * Scoped to OUR footprint: the strip is the bottom of the planet, and on a packed level the
 * level's bottom edge belongs to whichever tenant holds slot 1. Flagging the level's strip
 * would leave our own berths open to ruins (the bug this proc exists to stop) while sterilising
 * a band across a neighbour's world that has no berths in it.
 */
/obj/structure/overmap/planet/proc/reserve_dock_strip(datum/space_level/surface_level)
	var/has_footprint = !isnull(footprint?.low_x)
	var/strip_low_x = has_footprint ? footprint.low_x : surface_level.low_x
	var/strip_low_y = has_footprint ? footprint.low_y : surface_level.low_y
	var/strip_high_x = has_footprint ? footprint.high_x : surface_level.high_x
	var/strip_high_y = has_footprint ? footprint.high_y : surface_level.high_y
	var/strip_top = get_dock_strip_top_y(surface_level)
	if(isnull(strip_top) || isnull(strip_low_x))
		return
	var/strip_top_y = min(strip_top, strip_high_y)
	var/turf/strip_bottom_left = locate(strip_low_x, strip_low_y, surface_level.z_value)
	var/turf/strip_top_right = locate(strip_high_x, strip_top_y, surface_level.z_value)
	if(!strip_bottom_left || !strip_top_right)
		return
	for(var/turf/reserved as anything in block(strip_bottom_left, strip_top_right))
		reserved.turf_flags |= NO_RUINS
		CHECK_TICK

/**
 * The rectangle every terrain pass on this planet has to stay inside, as the inclusive
 * list(low_x, low_y, high_x, high_y) that seedRuins() and spawn_planet_rivers() take.
 *
 * The footprint is the authority: a z-level can carry more than one tenant, and the
 * level's own low_x/high_x pair is a derived mirror that widens to the whole z the moment
 * a second tenant lands on it (see /datum/space_level/sync_level_bounds). The level is
 * only a fallback for a planet built before it had a footprint.
 */
/obj/structure/overmap/planet/proc/get_terrain_bounds(datum/space_level/level)
	if(!isnull(footprint?.low_x))
		return list(footprint.low_x, footprint.low_y, footprint.high_x, footprint.high_y)
	if(level)
		return list(level.low_x, level.low_y, level.high_x, level.high_y)
	return null

/**
 * Every /area/overmap_encounter/planetoid instance sitting inside this planet's footprint:
 * the surface area fill_in() made, plus the cave areas terrain generation carved out of it.
 *
 * This is what the ruin seeder whitelists, by INSTANCE rather than by type. A typecache
 * matches on type and includes subtypes, and every planet's cave area is exactly
 * /area/overmap_encounter/planetoid/cave - so on a shared z-level a type whitelist happily
 * hands a ruin the co-tenant's caves. Ruin areas are left out because they are not
 * planetoid areas, which is the same set the old type whitelist excluded.
 */
/obj/structure/overmap/planet/proc/get_owned_planet_areas(datum/space_level/level)
	var/list/found_areas = list()
	var/list/block_turfs = footprint?.get_block() || level?.get_block()
	if(!block_turfs)
		return found_areas
	var/list/seen_areas = list()
	for(var/turf/tile as anything in block_turfs)
		var/area/tile_area = tile.loc
		if(isnull(tile_area) || seen_areas[tile_area])
			continue
		seen_areas[tile_area] = TRUE
		if(istype(tile_area, /area/overmap_encounter/planetoid))
			found_areas[tile_area] = TRUE
		// Throttled yield, not CHECK_TICK - see worldgen_yield() in worldgen_queue.dm
		SSovermap.worldgen_yield()
	return found_areas

// ---- Per-load ruin areas on planets --------------------------------------------------
//
// /area/ruin and every subtype of it carry UNIQUE_AREA (code/game/area/areas/ruins/_ruins.dm),
// which means /area/New() files the first instance in GLOB.areas_by_type and the map loader
// (code/modules/mapping/reader.dm) hands every later load of that template the SAME instance.
//
// One area instance spanning two planets breaks three things at once:
//
//  * generate_ruin_terrain() skips an area whose map_generator has already been instantiated,
//    so only the FIRST planet to roll a template ever fills in its /turf/open/genturf tiles -
//    the second's copy stays bare rock for the round. (True across z-levels already; packing
//    makes it intra-z and far more likely.)
//  * Weather, ambience, power and every other area-scoped system then treats both planets'
//    copies as one place.
//  * A teardown that empties the area on one planet empties the bookkeeping for both.
//
// The fix is scoped as tightly as it can be: instancing is switched on per Z-LEVEL, only for
// the duration of a planet's own seedRuins() call, and only bites when the cached singleton
// is actually in use somewhere. Station and space-ruin loading never sets the flag and is
// completely untouched; a planet that is the only user of a template still gets the singleton,
// so the common case mints no extra area datums at all.

/// z-level number (as text) -> depth of the in-flight planet ruin-seeding passes on it.
/// A depth rather than a boolean so overlapping passes can never switch each other off.
GLOBAL_LIST_EMPTY(planet_ruin_area_instancing)

/// Starts instancing ruin areas per load on `z_value`. Always pair with the _end().
/proc/planet_ruin_area_instancing_begin(z_value)
	var/key = "[z_value]"
	GLOB.planet_ruin_area_instancing[key] = (GLOB.planet_ruin_area_instancing[key] || 0) + 1

/proc/planet_ruin_area_instancing_end(z_value)
	var/key = "[z_value]"
	var/depth = (GLOB.planet_ruin_area_instancing[key] || 0) - 1
	if(depth > 0)
		GLOB.planet_ruin_area_instancing[key] = depth
	else
		GLOB.planet_ruin_area_instancing -= key

/// Whether the map loader should give `z_value` its own instance of a ruin area rather than
/// the UNIQUE_AREA singleton. Read once per loaded area tile, so it stays a list index.
/proc/planet_ruin_area_instancing_on_z(z_value)
	return !isnull(GLOB.planet_ruin_area_instancing["[z_value]"])

/**
 * A fresh, non-singleton instance of a ruin area type, for a planet load that cannot use the
 * shared one.
 *
 * UNIQUE_AREA is stripped from the instance so it does not replace the type's entry in
 * GLOB.areas_by_type - otherwise the NEXT loader to ask for this type (a station ruin, a
 * space ruin, another planet) would be handed this planet's copy. /area/New() files it before
 * we get control, so the previous entry is put back by hand. This mirrors what
 * /area/overmap_encounter already does by simply not declaring UNIQUE_AREA at all, which is
 * the invariant planet packing rests on.
 */
/proc/new_planet_ruin_area(area_type)
	var/area/previous_singleton = GLOB.areas_by_type[area_type]
	var/area/created = new area_type(null)
	if(!created)
		return null
	created.area_flags &= ~UNIQUE_AREA
	if(GLOB.areas_by_type[area_type] == created)
		GLOB.areas_by_type[area_type] = previous_singleton
	return created

/**
 * Seeds ruins on the surface, using the same budget and ore-vent preset the preloaded
 * planets got. Ruins are placed by rejection sampling against the whitelisted areas,
 * bounded to this planet's footprint.
 *
 * The bounds are what keeps a ruin off a co-tenant: the cordon used to do it on its own,
 * but a packed z-level has cordon only in the thin gutter between slots, and a ruin
 * centred near the footprint edge writes straight across it. try_to_place() re-anchors
 * its sampling on the rect with the same margin it uses against the world edge, so the
 * template and its border land wholly inside.
 *
 * The cave areas have to be whitelisted alongside the surface: terrain generation has
 * already run by this point and moved half the surface into /cave pockets (see
 * populate_planet_level()), and the cave type is a SIBLING of the surface type, not a
 * subtype, so the typecache doesn't cover it. With the surface alone, nearly every
 * candidate footprint touches a cave turf and is rejected - the seeder then burns its
 * full PLACEMENT_TRIES * PLACEMENT_TRIES sample budget per ruin scanning footprints
 * that can never pass. Roundstart seeding (setup_ruins()) correctly whitelists only the
 * surface because it runs BEFORE the terrain sweep carves any caves.
 *
 * They are passed as area INSTANCES, not types - see get_owned_planet_areas(). The type
 * list is still handed over as the fallback for a planet with no footprint.
 *
 * * owned_areas - the instance whitelist, when the caller has already walked the block for
 *   it. Omitted, it is derived here, which costs one extra ~15k-turf walk.
 */
/obj/structure/overmap/planet/proc/seed_planet_ruins(datum/space_level/surface_level, ruin_trait, area/surface_area_type, list/owned_areas)
	if(!ruin_trait)
		return
	var/list/ruin_templates = SSmapping.themed_ruins[ruin_trait]
	if(!length(ruin_templates))
		return
	if(isnull(owned_areas))
		owned_areas = get_owned_planet_areas(surface_level)
	// Ruin /area subtypes keep UNIQUE_AREA, so the map loader hands every load of the same
	// template the SAME area instance. Two planets rolling one template then share an area
	// straddling both of them, and generate_ruin_terrain()'s "has this generator run yet?"
	// test means only the first planet's copy ever fills in its genturf tiles. Instance them
	// per load for the duration of OUR seeding, on OUR z only - see the proc's doc comment.
	planet_ruin_area_instancing_begin(surface_level.z_value)
	seedRuins(
		list(surface_level.z_value),
		CONFIG_GET(number/lavaland_budget),
		list(surface_area_type, /area/overmap_encounter/planetoid/cave),
		ruin_templates,
		clear_below = TRUE,
		mineral_budget = 15,
		mineral_budget_update = OREGEN_PRESET_LAVALAND,
		bounds = get_terrain_bounds(surface_level),
		area_whitelist_instances = owned_areas,
	)
	planet_ruin_area_instancing_end(surface_level.z_value)

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
 * pass would rewrite the surface out from under everything standing on it.
 *
 * Walks OUR footprint, not the level, and generates only the turfs that walk found. On a
 * packed level the level block is every co-tenant, so a level-wide walk would run a
 * neighbour's ruin generators - and, because /area/RunTerrainGeneration() iterates the
 * whole area instance rather than the block that found it, would rewrite ruin floors a
 * crew may be standing on. That is why nothing here calls RunTerrainGeneration() any more:
 * the generator is driven directly over the turf list this walk collected.
 *
 * An already-instantiated generator is REUSED rather than skipped. `map_generator` stops
 * being a typepath the moment anything instantiates it, and the genturf-bearing ruins do
 * not map their genturf into /area/ruin subtypes at all - icemoon_surface_asteroid (the
 * clockwork one) puts it in /area/lavaland/surface/outdoors/unexplored/frozen_planet, the
 * abandoned homestead and the plasma facility in /area/icemoon/underground/unexplored/rivers.
 * Those are UNIQUE_AREA mining areas, so the per-load instancing in the map loader - which
 * only covers /area/ruin, see planet_ruin_area_instancing_begin - does not reach them and
 * every planet in the round shares one instance apiece. The first planet to roll such a
 * ruin instantiates the generator; behind an `ispath()` gate every later planet's copy was
 * skipped and its genturf stayed on the ground for the rest of the round as bright green
 * "green ungenerated turf" tiles ringing the ruin.
 */
/obj/structure/overmap/planet/proc/generate_ruin_terrain(datum/space_level/level)
	var/list/block_turfs = footprint?.get_block() || level?.get_block()
	if(!block_turfs)
		return
	/// area instance -> the turfs of it that lie inside OUR footprint
	var/list/ruin_area_turfs = list()
	/// areas already ruled out, so the type tests run once per area rather than per turf
	var/list/rejected_areas = list()
	for(var/turf/tile as anything in block_turfs)
		var/area/tile_area = tile.loc
		if(isnull(tile_area) || rejected_areas[tile_area])
			continue
		if(!ruin_area_turfs[tile_area])
			if(istype(tile_area, /area/overmap_encounter/planetoid) || !tile_area.map_generator)
				rejected_areas[tile_area] = TRUE
				continue
			ruin_area_turfs[tile_area] = list()
		ruin_area_turfs[tile_area] += tile
		CHECK_TICK
	for(var/area/ruin_area as anything in ruin_area_turfs)
		generate_one_ruin_area(ruin_area, ruin_area_turfs[ruin_area])
		CHECK_TICK
	fill_orphaned_genturf(block_turfs)

/**
 * Paves any /turf/open/genturf still standing inside this planet's footprint with the
 * planet's own ground.
 *
 * A backstop, not the mechanism: everything that ships genturf is supposed to be filled by
 * generate_ruin_terrain() above. This catches what that cannot reach by construction - a
 * template that maps genturf into an area with no map_generator at all, a generator that
 * refuses the area (the cave generators return early without CAVES_ALLOWED), or a ruin
 * whose genturf tiles were pushed outside their own area by a later load. Nothing else in
 * the round ever comes back for those tiles, and they render as bright green
 * "green ungenerated turf" a crew can stand on, so the planet's ground is a strictly
 * better answer than leaving them.
 *
 * `footprint.baseturf` is the ground the planet datum published, i.e. exactly what a hole
 * dug anywhere in this rectangle already bottoms out into.
 */
/obj/structure/overmap/planet/proc/fill_orphaned_genturf(list/block_turfs)
	var/turf/ground_type = footprint?.baseturf
	if(!ground_type || !length(block_turfs))
		return 0
	var/filled = 0
	for(var/turf/tile as anything in block_turfs)
		// Turf refs are locational, so entries the generators above replaced read as
		// whatever now stands at those coordinates rather than as the old datum.
		if(!istype(tile, /turf/open/genturf))
			continue
		tile.ChangeTurf(ground_type, ground_type)
		filled++
		CHECK_TICK
	if(filled)
		log_mapping("SSovermap: planet '[display_name || name]' paved [filled] orphaned genturf tile(s) with [ground_type]")
	return filled

/**
 * Runs one ruin area's own terrain generator, with the lighting objects on the tiles it
 * is about to rewrite taken down first and rebuilt afterwards.
 *
 * The cave generators lay their turfs down with a raw `new turf_type(gen_turf)` rather
 * than ChangeTurf (code/datums/mapgen/CaveGenerator.dm), on the upstream assumption that
 * this only ever runs at mapload, before SSlighting exists. On a planet it runs MID-ROUND,
 * and a raw `new` hands the tile a fresh turf datum: `lighting_object` and all four
 * `lighting_corner_*` refs come back null, while the /datum/lighting_object itself lives
 * on with `affected_turf` still pointing at the tile - turf refs are locational, so it now
 * points at the replacement. Nothing owns it and nothing can ever update it again, but if
 * it was still sitting in SSlighting's queue when the turf was swapped it gets one last
 * update() off corners that no longer exist, paints a flat "lighting_dark" underlay onto
 * the new tile and sets its luminosity to 0. That is a permanently black tile whose
 * contents are culled out of view, and no light source, no lighting rebuild and no ambient
 * bleed can undo it - a rebuilt lighting object only ever removes its OWN underlay.
 *
 * Clearing first is what makes that impossible: /datum/lighting_object/Destroy() pulls its
 * underlay back off the turf and restores luminosity, so the generator writes onto clean
 * tiles and the rebuild below is the only object any of them ever holds.
 *
 * This bug is NOT caused by the ambient lighting port - it is pre-existing on any
 * mid-round ruin generation. What the port changed is that a tile orphaned this way can no
 * longer be re-lit by anything, because the ground around it no longer emits.
 */
/obj/structure/overmap/planet/proc/generate_one_ruin_area(area/ruin_area, list/generated_turfs)
	// Our footprint's tiles of this area, handed down by the caller's walk. The area
	// INSTANCE is frequently shared - the mining areas the genturf ruins use keep
	// UNIQUE_AREA and the loader's per-load instancing only covers /area/ruin - so
	// sweeping the whole of `contents` (which is what /area/RunTerrainGeneration() does)
	// would regenerate the co-tenant's, or a previous planet's, ground out from under it.
	if(isnull(generated_turfs))
		generated_turfs = ruin_area.get_turfs_from_all_zlevels()
	if(!length(generated_turfs))
		return
	for(var/turf/tile as anything in generated_turfs)
		tile.lighting_clear_overlay()
		CHECK_TICK

	// The instantiation /area/RunTerrainGeneration() would have done, except that a
	// generator somebody else already instantiated is reused instead of being skipped.
	var/datum/map_generator/ruin_generator = ruin_area.map_generator
	if(ispath(ruin_generator))
		ruin_generator = new ruin_generator()
		ruin_area.map_generator = ruin_generator
	if(ruin_generator)
		ruin_generator.generate_terrain(generated_turfs, ruin_area)

	if(!ruin_area.static_lighting)
		return
	for(var/turf/tile as anything in generated_turfs)
		if(tile.space_lit || tile.lighting_object || tile.skips_lighting_object())
			continue
		tile.lighting_build_overlay()
		CHECK_TICK

/**
 * Puts the daylight back on the ground a ruin brought with it.
 *
 * A ruin's own areas stay statically lit, deliberately - darkness inside a ruin is a
 * mechanic, and the ambient lighting on the planet surface stops dead at the surface
 * area's border. But a ruin footprint is not all interior: the yard around a lodge, the
 * snow an ore vent sits in, the ground a mining site is pitched on are all mapped into the
 * ruin's own OUTDOOR areas, and none of the ruin .dmms place `/lit` turfs there (checked:
 * zero across every icemoon ruin). They were daylit for free before the ambient lighting
 * port, because the planet ground beside them was /lit turfs whose range-2 light reached in.
 *
 * With the surface painted by an area overlay instead, nothing reaches in, and those tiles
 * render pitch black with a razor edge against bright ground - a whole ruin footprint at a
 * time. Ambient bleed cannot cover it either: it is a one-tile boundary ring by design,
 * where these are yards several tiles deep.
 *
 * So each open ground tile in an outdoor ruin area emits the planet's own daylight, which
 * is precisely what the /lit turfs around it used to do. `outdoors` is the codebase's own
 * "open to the sky" flag - the one weather already reads - so a ruin's roofed interior
 * areas are untouched and stay as dark as the mapper built them.
 *
 * Real light on the TURF rather than base_lighting_alpha on the ruin area, on purpose:
 * an area-level tint would follow the ruin type onto planets of a different biome, and it
 * would leave the ground mechanically dark to get_lumcount(), so a yard would look daylit
 * while every darkness check (reading, plant growth, nightvision) disagreed.
 *
 * The planet's own areas are skipped whole: the surface areas paint themselves ambient,
 * caves are meant to be dark, and /area/overmap_encounter/planet_ruin is a ruin interior
 * that only inherits `outdoors` from its parent.
 */
/obj/structure/overmap/planet/proc/light_ruin_terrain(datum/space_level/level, area/surface_area)
	if(!surface_area?.base_lighting_alpha)
		return
	// VOIDCREW PACKING EDIT: our footprint, not the level. A packed level carries up to four
	// tenants of DIFFERENT biomes, so walking the level block would paint a neighbour's ruin
	// yards in OUR daylight colour - and whichever planet built first would win, since the
	// light_range test below skips anything already lit. Same scoping generate_ruin_terrain()
	// uses directly above, and for the same reason.
	var/list/block_turfs = footprint?.get_block() || level?.get_block()
	if(!block_turfs)
		return
	var/daylight_power = RUIN_DAYLIGHT_POWER(surface_area.base_lighting_alpha)
	var/daylight_color = surface_area.base_lighting_color
	// Same sentinel /area/proc/add_base_lighting() honours: an area painted in
	// COLOR_STARLIGHT actually renders in the live, nebula-tinted GLOB.starlight_color.
	if(daylight_color == COLOR_STARLIGHT)
		daylight_color = GLOB.starlight_color

	for(var/turf/tile as anything in block_turfs)
		// Throttled yield, not CHECK_TICK - see worldgen_yield() in worldgen_queue.dm
		SSovermap.worldgen_yield()
		var/area/tile_area = tile.loc
		if(isnull(tile_area) || istype(tile_area, /area/overmap_encounter))
			continue
		if(!tile_area.outdoors || tile_area.ambient_lighting)
			continue
		// Closed turfs were never lit either - the biome tables only ever picked /lit for
		// their OPEN types, and a rock face is lit by the ground around it through the
		// corners they share. A turf that already lights itself (a lava river, a fallout
		// tile, a light floor a mapper placed) is left exactly as the mapper left it.
		if(!isopenturf(tile) || tile.light_range)
			continue
		tile.set_light(l_range = RUIN_DAYLIGHT_RANGE, l_power = daylight_power, l_color = daylight_color, l_on = TRUE)

/// Lava and ice planets get their rivers, bounded to the planet's footprint.
/// The generic cave area is whitelisted too: terrain generation carves rock pockets out
/// into one, and a river that stopped dead at every outcrop would look wrong.
///
/// The rect is passed twice on purpose: once as the min/max the river NODES are dropped
/// between, and once as `bounds`, the rect the river walk and its spread may not leave.
/// The area whitelist cannot do the second job - it is type-based, and on a shared z-level
/// the neighbour's caves are the same type as ours, so a river reaching the footprint edge
/// would carve into their ground.
/obj/structure/overmap/planet/proc/spawn_planet_rivers_for(datum/space_level/surface_level, ruin_trait, area/surface_area_type)
	var/river_turf
	switch(ruin_trait)
		if(ZTRAIT_LAVA_RUINS)
			river_turf = /turf/open/lava/smooth/lava_land_surface/planetary
		if(ZTRAIT_ICE_RUINS)
			river_turf = /turf/open/lava/plasma/planetary
	if(!river_turf)
		return
	var/list/river_bounds = get_terrain_bounds(surface_level)
	if(!river_bounds)
		return
	spawn_planet_rivers(
		surface_level.z_value,
		4,
		river_turf,
		list(surface_area_type, /area/overmap_encounter/planetoid/cave),
		river_bounds[1],
		river_bounds[2],
		river_bounds[3],
		river_bounds[4],
		bounds = river_bounds,
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
	// Berths are anchored off THIS site's footprint, never off the z-level. Two tenants
	// reading the level's rect would build their berths on exactly the same tiles, and
	// this is the arrival path - so it is not optional. A site with no footprint (nothing
	// builds one that way, but admin verbs and old saves can) falls back to the level,
	// which is what the level rect means for a single tenant anyway.
	var/anchor_low_x = footprint ? footprint.low_x : zlevel.low_x
	var/anchor_low_y = footprint ? footprint.low_y : zlevel.low_y
	if(isnull(anchor_low_x) || isnull(anchor_low_y))
		return

	// locates the first dock in the bottom left, accounting for padding and the border
	var/turf/primary_docking_turf = locate(
		anchor_low_x + RESERVE_DOCK_DEFAULT_PADDING + 1,
		anchor_low_y + RESERVE_DOCK_DEFAULT_PADDING + 1,
		zlevel.z_value
	)
	if(!primary_docking_turf)
		log_mapping("SSovermap: create_docking_ports() found no berth turf for '[display_name || name]' at ([anchor_low_x],[anchor_low_y]) on z[zlevel.z_value]")
		return
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
		// The middle of OUR footprint. The world centre is the gutter on a packed level -
		// indestructible cordon - or the neighbour's ground.
		var/turf/planet_turf = footprint?.get_center_turf() || locate(round((z_level.low_x + z_level.high_x)/2), round((z_level.low_y + z_level.high_y)/2), z_level.z_value)
		if(!planet_turf)
			return
		user.forceMove(planet_turf)
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

	// Footprint-scoped, not z-scoped: on a shared level the z-wide answer counts the
	// NEIGHBOUR's crew, which fuses the two tenants' lifecycles - neither ever recycles
	// until both are empty. Falls back to the z-wide answer when there is no footprint.
	if(length(mapzone.get_mind_mobs_in(footprint)))
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
	// Ends this planet's storm and cancels its cooldown. clear_reservation() below wipes
	// every site on the level anyway, but going through our own site first is the teardown
	// that stays correct once a level can hold more than one planet.
	SSweather.unregister_weather_site(weather_site)
	weather_site = null
	if(mapzone)
		// Per-slot teardown: only this tenant's rectangle is reset, and only the LAST
		// tenant out sweeps the whole level (cordon included) so the recycled zone comes
		// back clean. The order matters - the footprint has to still be registered while
		// the sweep runs, since that is what tells it which ground is ours.
		var/datum/map_zone/departing_zone = mapzone
		var/datum/map_footprint/departing_footprint = footprint
		departing_zone.clear_reservation(throttled, departing_footprint)
		departing_zone.release_slot(departing_footprint)
		mapzone = null
		footprint = null

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
///
/// Our only caller is on_ship_undocked()'s one-shot 3-second timer, so a refusal here
/// used to end the planet's lifecycle for good: one crewmate left behind, one ghost role,
/// one mission mob with a mind still on the surface at T+3s and the z-level stayed
/// resident for the rest of the round unless another ship happened to dock and leave
/// again. Re-arm instead, the same way check_and_respawn() and the field teardown do.
/obj/structure/overmap/planet/proc/check_start_despawn()
	// Terminal: a preserved level never releases, and one with no mapzone is already
	// unloaded - there is nothing left to count down to. Everything else is a "not yet".
	if(preserve_level || !mapzone)
		return
	// An armed countdown IS the retry; attempt_despawn() re-arms itself if it refuses.
	if(despawn_timer_id)
		return
	// A teardown already in flight, or loading, either berth, a ship still inside,
	// anyone with a mind on the surface. Deliberately the same test unload_level() will
	// apply in five minutes. An in-flight teardown can still abort (see unload_level's
	// post-claim re-check), so it retries rather than ending here.
	if(unloading || !can_release_interior())
		addtimer(CALLBACK(src, PROC_REF(check_start_despawn)), 30 SECONDS, TIMER_UNIQUE)
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
		// The countdown that got us here is spent, so a refusal at this exact instant
		// (someone came back, a build is in flight, the queue timed out) would otherwise
		// leave the level resident until the next visitor undocks. preserve_level and an
		// already-unloaded planet never release and must not spin. TIMER_UNIQUE dedupes
		// against unload_level()'s own queue-timeout re-arm - it is this same callback.
		if(!preserve_level && mapzone)
			addtimer(CALLBACK(src, PROC_REF(attempt_despawn)), 30 SECONDS, TIMER_UNIQUE)
		return
	log_mapping("SSovermap: Planet '[name]' unloaded after being abandoned, relocated to ([x], [y])")

/obj/structure/overmap/planet/proc/remove_docks()
	if(reserve_dock)
		qdel(reserve_dock, TRUE)
		reserve_dock = null
	if(reserve_dock_secondary)
		qdel(reserve_dock_secondary, TRUE)
		reserve_dock_secondary = null
