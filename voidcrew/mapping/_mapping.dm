/**
 * We are modularly making stuff we don't want, early return.
 * We can manually re-add whatever we need here as well.
 */
/datum/controller/subsystem/mapping
	///List of all ships that can be purchased.
	var/list/datum/map_template/shuttle/voidcrew/ship_purchase_list = list()

	/**
	 * RUIN TEMPLATES
	 */
	var/list/space_ruins_templates = list()
	var/list/lava_ruins_templates = list()
	var/list/ice_ruins_templates = list()
	var/list/jungle_ruins_templates = list()
	var/list/beach_ruins_templates = list()
	var/list/wasteland_ruins_templates = list()
	var/list/yellow_ruins_templates = list()

	// PRELOADED planets: generated in full at boot by loadWorld() below, one surface +
	// one cave z-level each, held in memory for the whole round whether or not a single
	// crew ever lands on them. All zeroed on purpose. The round's planet supply comes
	// from dynamic markers instead (SSovermap.dynamic_planets_per_type, one set of every
	// type per pass), which generate their surface on first visit. Raise a count here only
	// to pin a specific planet type to a pre-generated, fully seeded z-pair, and budget ~2
	// z-levels of memory for it. Note it REPLACES the dynamic supply for that type rather
	// than adding to it: setup_planets() drops every dynamic marker of a preloaded type.
	var/lava_planet_count = 0
	var/ice_planet_count = 0
	var/jungle_planet_count = 0
	var/beach_planet_count = 0
	var/wasteland_planet_count = 0

	var/list/planets = list()

	/// Working pool for dealing roundstart planets their overmap zone bands (see next_planet_zone_band())
	var/list/planet_zone_band_pool = list()

	/// Highest world.maxz the z-ceiling warning has already been logged for, so the
	/// approach to the cap is reported once per level rather than once per allocation.
	var/z_ceiling_last_warned = 0
	/// Rate limit on the at-cap admin message - every refused allocation reaches it.
	COOLDOWN_DECLARE(z_ceiling_admin_cooldown)

/datum/controller/subsystem/mapping/Initialize(timeofday)
	load_ship_templates()
	return ..()

/// How often the at-cap message may reach admins. Every refused allocation asks, and a
/// busy round refuses several a minute.
#define Z_CEILING_ADMIN_INTERVAL (5 MINUTES)

/**
 * Whether world.maxz is at its configured ceiling, i.e. whether minting another z-level
 * is allowed right now.
 *
 * BYOND never frees a z-level: every one ever created keeps its full 255x255 turf plane
 * for the rest of the round - ~49 MB bare, ~76 MB carrying a site - and nothing in the
 * tree limited how many could be made. A round that churned encounters simply climbed
 * until the 32-bit wall killed it. See /datum/config_entry/number/max_z_levels.
 *
 * Asked at the two runtime mint points that carry the growth: claim_free_slot() (the map
 * zone lattice, i.e. every encounter, planet and outpost) and
 * request_turf_block_reservation()'s add_reservation_zlevel() fallback. Both answer a
 * refusal by returning null, which their callers already treat as "not right now" and
 * retry - it is a slot-availability wait, never a hard failure and never a queue wait.
 *
 * Logging is a side effect on purpose: this proc is the only place that sees the pressure,
 * and it is asked exactly when it matters.
 */
/datum/controller/subsystem/mapping/proc/at_z_level_ceiling()
	var/ceiling = CONFIG_GET(number/max_z_levels)
	if(ceiling <= 0) // ceiling disabled
		return FALSE

	var/warn_at = CONFIG_GET(number/max_z_levels_warn_at)
	if(warn_at > 0 && world.maxz >= warn_at && world.maxz > z_ceiling_last_warned)
		z_ceiling_last_warned = world.maxz
		log_mapping("SSmapping: world.maxz has reached [world.maxz] against a ceiling of [ceiling]. Each level is roughly 49 MB of \
			permanently committed turf plane that BYOND will never free - if this keeps climbing, sites are not recycling.")

	if(world.maxz < ceiling)
		return FALSE

	if(COOLDOWN_FINISHED(src, z_ceiling_admin_cooldown))
		COOLDOWN_START(src, z_ceiling_admin_cooldown, Z_CEILING_ADMIN_INTERVAL)
		var/cap_message = "SSmapping: world.maxz is at its configured ceiling of [ceiling] - new map volume is being REFUSED. \
			Sites that ask for it will wait and retry rather than fail, but nothing new can be charted until something recycles. \
			Raise MAX_Z_LEVELS only if this host has the memory for it (~49 MB per level, never reclaimed)."
		log_mapping(cap_message)
		message_admins(cap_message)
	return TRUE

#undef Z_CEILING_ADMIN_INTERVAL

/**
 * TRUE if a turf block of this size could ever be reserved, on a completely empty
 * reservation z-level.
 *
 * request_turf_block_reservation() answers "no room right now" by adding a fresh
 * reservation z-level and retrying - so a block that is merely too big for any
 * z-level makes it allocate a whole new 255x255 level, fail again, and return null,
 * leaking that level permanently. Every retry leaks another one. Callers that build
 * their reservation size from map template dimensions must check here first.
 *
 * Only turfs in [SHUTTLE_TRANSIT_BORDER, maxx - SHUTTLE_TRANSIT_BORDER] are ever
 * flagged UNUSED_RESERVATION_TURF (see initialize_reserved_level), and
 * calculate_cordon_turfs() demands an unused ring one turf outside the block on
 * every side - so the block itself must start at BORDER + 1 and its far cordon
 * column must still land on BORDER's mirror. That leaves maxx - 2*BORDER - 1.
 */
/datum/controller/subsystem/mapping/proc/reservation_can_ever_fit(width, height)
	if(width < 1 || height < 1)
		return FALSE
	var/max_width = world.maxx - (SHUTTLE_TRANSIT_BORDER * 2) - 1
	var/max_height = world.maxy - (SHUTTLE_TRANSIT_BORDER * 2) - 1
	return width <= max_width && height <= max_height

/**
 * Deals out a zone band (ZONE_GREEN/YELLOW/RED) for the next roundstart planet.
 *
 * Preloaded planet z-levels are generated and populated during SSmapping init,
 * BEFORE SSovermap places the planets on the overmap, so the zone must be
 * decided up front. The band is stored on the planet's SSmapping.planets entry;
 * SSovermap.setup_planets() then places the planet on an overmap tile inside
 * that band, keeping the pre-generated content honest.
 *
 * Dynamic planets draw from the same pool when setup_planets() places them, so
 * the two supply models can't both crowd into the same ring.
 *
 * Bands are dealt from a reshuffled set of all three, so every round gets at
 * least one planet per band while the ordering stays random.
 */
/datum/controller/subsystem/mapping/proc/next_planet_zone_band()
	if(!length(planet_zone_band_pool))
		planet_zone_band_pool = shuffle(list(ZONE_GREEN, ZONE_YELLOW, ZONE_RED))
	var/band = planet_zone_band_pool[1]
	planet_zone_band_pool.Cut(1, 2)
	return band

/**
 * The zone band of the planet that owns a turf, or null when the turf isn't on one.
 *
 * The turf, not its z-level, is the question a caller actually has. A z-level used to be
 * one planet, so "which band is z 14" and "which band is this rock" were the same lookup;
 * a packed level carries several planets and they can sit in different bands.
 *
 * Resolution order:
 *  1. The planetoid area under the turf. Its `zone_band` is stamped per planet at build
 *     (see populate_planet_level() in planet.dm) and a packed level gives every planet its
 *     own area instances, so this is the answer that stays right as levels fill up.
 *  2. The roundstart planet registry, which is keyed by z. Roundstart planets are dealt
 *     dedicated z-level pairs by loadWorld() and are never packed tenants, so a z match is
 *     exact for them - it is just blind to everything else.
 */
/datum/controller/subsystem/mapping/proc/get_planet_zone_band_for_turf(turf/checked_turf)
	if(!checked_turf)
		return null
	var/area/overmap_encounter/planetoid/planetoid_area = get_area(checked_turf)
	if(istype(planetoid_area) && !isnull(planetoid_area.zone_band))
		return planetoid_area.zone_band
	return get_planet_zone_band_for_z(checked_turf.z)

/**
 * The pre-assigned zone band for a roundstart planet z-level, or null if the
 * z-level isn't one. Each planet loads as a pair of z-levels (surface = the
 * stored z, underground = z - 1), so both resolve to the planet's band.
 *
 * Only ever answers for the planets in `planets`, i.e. the ones loadWorld() pre-generated
 * onto their own z-levels. Dynamic planets - every planet in a live round, since all the
 * *_planet_count vars are 0 - are not in this registry and come back null here. Prefer
 * get_planet_zone_band_for_turf(), which asks the planet's own area first; this is kept
 * both as that proc's fallback and for the callers that genuinely only hold a z.
 */
/datum/controller/subsystem/mapping/proc/get_planet_zone_band_for_z(z)
	if(!z)
		return null
	for(var/planet_key in planets)
		var/list/planet_info = planets[planet_key]
		var/planet_z = planet_info["z"]
		if(z == planet_z || z == planet_z - 1)
			return planet_info["zone_band"]
	return null

#define INIT_ANNOUNCE(X) to_chat(world, span_boldannounce("[X]")); log_world(X)
/datum/controller/subsystem/mapping/loadWorld()
	InitializeDefaultZLevels()
	var/list/FailedZs = list()
	var/z_count = 1
	for(var/i in 1 to lava_planet_count)
		LoadGroup(FailedZs, "Planet lava [i]", "map_files/voidcrew", "lava.dmm", list(list(ZTRAIT_UP=1, ZTRAIT_MINING = TRUE, ZTRAIT_LAVA_RUINS, ZTRAIT_ASHSTORM, ZTRAIT_BASETURF = /turf/open/misc/asteroid/basalt/lava_land_surface/lit), list(ZTRAIT_DOWN=1, ZTRAIT_MINING = TRUE, ZTRAIT_LAVA_RUINS, ZTRAIT_ASHSTORM, ZTRAIT_BASETURF = /turf/open/misc/asteroid/basalt/lava_land_surface/lit)))
		z_count += 2
		var/list/p = list(type = /datum/overmap/planet/lava, z = z_count, zone_band = next_planet_zone_band())
		planets += list("lava [i]" = p)

	for(var/i in 1 to ice_planet_count)
		LoadGroup(FailedZs, "Planet ice [i]", "map_files/voidcrew", "ice.dmm", list(list(ZTRAIT_UP=1, ZTRAIT_MINING = TRUE, ZTRAIT_ICE_RUINS, ZTRAIT_SNOWSTORM, ZTRAIT_BASETURF = /turf/open/misc/asteroid/snow/icemoon/breathable/lit), list(ZTRAIT_DOWN=1, ZTRAIT_MINING = TRUE, ZTRAIT_ICE_RUINS, ZTRAIT_SNOWSTORM, ZTRAIT_BASETURF = /turf/open/misc/asteroid/snow/icemoon/breathable/lit)))
		z_count += 2
		var/list/p = list(type = /datum/overmap/planet/ice, z = z_count, zone_band = next_planet_zone_band())
		planets += list("ice [i]" = p)

	// VOIDCREW: jungle/beach/wasteland carry their weather traits here so SSweather
	// schedules storms on them like it already does for lava/ice (their /datum/overmap/planet
	// entries always declared these weather types, but the roundstart z-levels never got the traits)
	for(var/i in 1 to jungle_planet_count)
		LoadGroup(FailedZs, "Planet jungle [i]", "map_files/voidcrew", "jungle.dmm", list(list(ZTRAIT_UP=1, ZTRAIT_MINING = TRUE, ZTRAIT_JUNGLE_RUINS, ZTRAIT_RAINSTORM, ZTRAIT_BASETURF = /turf/open/misc/dirt/jungle/lit), list(ZTRAIT_DOWN=1, ZTRAIT_MINING = TRUE, ZTRAIT_JUNGLE_RUINS, ZTRAIT_RAINSTORM, ZTRAIT_BASETURF = /turf/open/misc/dirt/jungle/lit)))
		z_count += 2
		var/list/p = list(type = /datum/overmap/planet/jungle, z = z_count, zone_band = next_planet_zone_band())
		planets += list("jungle [i]" = p)

	for(var/i in 1 to beach_planet_count)
		LoadGroup(FailedZs, "Planet beach [i]", "map_files/voidcrew", "beach.dmm", list(list(ZTRAIT_UP=1, ZTRAIT_MINING = TRUE, ZTRAIT_BEACH_RUINS, ZTRAIT_RAINSTORM, ZTRAIT_BASETURF = /turf/open/misc/asteroid/sand/beach/lit), list(ZTRAIT_DOWN=1, ZTRAIT_MINING = TRUE, ZTRAIT_BEACH_RUINS, ZTRAIT_RAINSTORM, ZTRAIT_BASETURF = /turf/open/misc/asteroid/sand/beach/lit)))
		z_count += 2
		var/list/p = list(type = /datum/overmap/planet/beach, z = z_count, zone_band = next_planet_zone_band())
		planets += list("beach [i]" = p)

	for(var/i in 1 to wasteland_planet_count)
		LoadGroup(FailedZs, "Planet wasteland [i]", "map_files/voidcrew", "wasteland.dmm", list(list(ZTRAIT_UP=1, ZTRAIT_MINING = TRUE, ZTRAIT_WASTELAND_RUINS, ZTRAIT_SANDSTORM, ZTRAIT_BASETURF = /turf/open/misc/wasteland/lit), list(ZTRAIT_DOWN=1, ZTRAIT_MINING = TRUE, ZTRAIT_WASTELAND_RUINS, ZTRAIT_SANDSTORM, ZTRAIT_BASETURF = /turf/open/misc/wasteland/lit)))
		z_count += 2
		var/list/p = list(type = /datum/overmap/planet/wasteland, z = z_count, zone_band = next_planet_zone_band())
		planets += list("wasteland [i]" = p)

	if(LAZYLEN(FailedZs)) //but seriously, unless the server's filesystem is messed up this will never happen
		var/msg = "RED ALERT! The following map files failed to load: [FailedZs[1]]"
		if(FailedZs.len > 1)
			for(var/I in 2 to FailedZs.len)
				msg += ", [FailedZs[I]]"
		msg += ". Yell at your server host!"
		INIT_ANNOUNCE(msg)
#undef INIT_ANNOUNCE

/datum/controller/subsystem/mapping/run_map_terrain_generation()
	for(var/area/A as anything in GLOB.areas)
		CHECK_TICK
		A.RunTerrainGeneration()

/datum/controller/subsystem/mapping/preloadRuinTemplates()
	/* This is all taken from parent */
	// Still supporting bans by filename
	var/list/banned = generateMapList("spaceruinblacklist.txt")
	// TODO: Fix config.minetype and blacklist_file
	//if(config.minetype == "lavaland")
	//	banned += generateMapList("lavaruinblacklist.txt")
	//else if(config.blacklist_file)
	//	banned += generateMapList(config.blacklist_file)

	for(var/item in sort_list(subtypesof(/datum/map_template/ruin), GLOBAL_PROC_REF(cmp_ruincost_priority)))
		var/datum/map_template/ruin/ruin_type = item
		// screen out the abstract subtypes
		if(!initial(ruin_type.id))
			continue
		var/datum/map_template/ruin/R = new ruin_type()

		if(banned.Find(R.mappath))
			continue

		map_templates[R.name] = R
		ruins_templates[R.name] = R

		if (!(R.ruin_type in themed_ruins))
			themed_ruins[R.ruin_type] = list()
		themed_ruins[R.ruin_type][R.name] = R

		/* Custom code below. */
		if(istype(R, /datum/map_template/ruin/lavaland))
			lava_ruins_templates[R.name] = R
		else if(istype(R, /datum/map_template/ruin/jungle))
			jungle_ruins_templates[R.name] = R
		else if(istype(R, /datum/map_template/ruin/beach))
			beach_ruins_templates[R.name] = R
		else if(istype(R, /datum/map_template/ruin/wasteland))
			wasteland_ruins_templates[R.name] = R

		else if(istype(R, /datum/map_template/ruin/icemoon))
			ice_ruins_templates[R.name] = R
		else if(istype(R, /datum/map_template/ruin/space))
			space_ruins_templates[R.name] = R
		else if(istype(R, /datum/map_template/ruin/reebe))
			yellow_ruins_templates[R.name] = R

/datum/controller/subsystem/mapping/setup_map_transitions()
	return

///generates the list of GLOB.the_station_areas - We don't have a station, maybe we can make use of this one day for ships.
/datum/controller/subsystem/mapping/generate_station_area_list()
	return

/// Only thing we want to do here is setup planetary atmos as needed
/datum/controller/subsystem/mapping/setup_ruins()
	var/datum/gas_mixture/immutable/planetary/lavaland_air = new
	lavaland_air.parse_string_immutable(LAVALAND_DEFAULT_ATMOS)
	SSair.planetary[LAVALAND_DEFAULT_ATMOS] = lavaland_air

	var/list/lava_levels = levels_by_trait(ZTRAIT_LAVA_RUINS)
	if (lava_levels.len)
		seedRuins(lava_levels, CONFIG_GET(number/lavaland_budget), list(/area/overmap_encounter/planetoid/lava), themed_ruins[ZTRAIT_LAVA_RUINS], clear_below = TRUE, mineral_budget = 15, mineral_budget_update = OREGEN_PRESET_LAVALAND)

	var/list/ice_levels = levels_by_trait(ZTRAIT_ICE_RUINS)
	if (ice_levels.len)
		seedRuins(ice_levels, CONFIG_GET(number/lavaland_budget), list(/area/overmap_encounter/planetoid/ice), themed_ruins[ZTRAIT_ICE_RUINS], clear_below = TRUE, mineral_budget = 15, mineral_budget_update = OREGEN_PRESET_LAVALAND)

	var/list/beach_levels = levels_by_trait(ZTRAIT_BEACH_RUINS)
	if (beach_levels.len)
		seedRuins(beach_levels, CONFIG_GET(number/lavaland_budget), list(/area/overmap_encounter/planetoid/beach), themed_ruins[ZTRAIT_BEACH_RUINS], clear_below = TRUE, mineral_budget = 15, mineral_budget_update = OREGEN_PRESET_LAVALAND)

	var/list/jungle_levels = levels_by_trait(ZTRAIT_JUNGLE_RUINS)
	if (jungle_levels.len)
		seedRuins(jungle_levels, CONFIG_GET(number/lavaland_budget), list(/area/overmap_encounter/planetoid/jungle), themed_ruins[ZTRAIT_JUNGLE_RUINS], clear_below = TRUE, mineral_budget = 15, mineral_budget_update = OREGEN_PRESET_LAVALAND)

	var/list/wasteland_levels = levels_by_trait(ZTRAIT_WASTELAND_RUINS)
	if (wasteland_levels.len)
		seedRuins(wasteland_levels, CONFIG_GET(number/lavaland_budget), list(/area/overmap_encounter/planetoid/wasteland), themed_ruins[ZTRAIT_WASTELAND_RUINS], clear_below = TRUE, mineral_budget = 15, mineral_budget_update = OREGEN_PRESET_LAVALAND)

/datum/controller/subsystem/mapping/setup_rivers()
	var/list/lava_ruins = levels_by_trait(ZTRAIT_LAVA_RUINS)
	for (var/lava_z in lava_ruins)
		spawn_planet_rivers(lava_z, 4, /turf/open/lava/smooth/lava_land_surface/planetary, list(/area/overmap_encounter/planetoid/lava, /area/overmap_encounter/planetoid/cave))

	var/list/ice_ruins = levels_by_trait(ZTRAIT_ICE_RUINS)
	for (var/ice_z in ice_ruins)
		spawn_planet_rivers(ice_z, 4, /turf/open/lava/plasma/planetary, list(/area/overmap_encounter/planetoid/ice, /area/overmap_encounter/planetoid/cave/ice))

/datum/controller/subsystem/mapping/proc/load_ship_templates()
	SHOULD_CALL_PARENT(TRUE)
	if(ship_purchase_list.len) //don't build repeatedly
		return

	for(var/datum/map_template/shuttle/voidcrew/shuttles as anything in subtypesof(/datum/map_template/shuttle/voidcrew))
		// Build requirements summary from class-based part_requirements
		var/list/req_parts = list()
		var/list/part_reqs = initial(shuttles.part_requirements)
		if(part_reqs)
			for(var/part_class in part_reqs)
				var/count = part_reqs[part_class]
				if(count > 0)
					req_parts += "[count] [part_class]"

		var/cost_str = length(req_parts) ? req_parts.Join(", ") : "Free"
		ship_purchase_list["[initial(shuttles.name)] ([cost_str])"] = shuttles

/datum/controller/subsystem/mapping/get_station_center()
	return SSovermap.overmap_centre || locate(OVERMAP_LEFT_SIDE_COORD, OVERMAP_NORTH_SIDE_COORD, OVERMAP_Z_LEVEL)
