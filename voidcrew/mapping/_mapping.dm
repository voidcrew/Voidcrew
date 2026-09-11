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
 * The z-level ceiling actually in force right now, i.e. max_z_levels after population
 * scaling. THIS, not the raw config entry, is what every decision should read.
 *
 * A z-level's ~49-76 MB is only one of the things eating a 32-bit server's ~3500 MB of
 * address space; the rest of it scales with how many people are aboard. A 118-player round
 * found the flat ceiling of 24 sitting comfortably ABOVE the real wall - the levels were
 * within budget and the server still died, because the budget was written for a 40-player
 * round. So the ceiling comes down as pop climbs: one level per max_z_levels_pop_scale_per
 * clients past max_z_levels_pop_scale_start, never below max_z_levels_pop_floor and never
 * above the configured number. On the defaults that is 24 levels up to 80 players, 20 at
 * 120, and 18 (the floor) from 140 up.
 *
 * `pop` is an argument so the unit tests can drive the whole curve without clients; left
 * null it reads length(GLOB.clients), which is a plain list length. Deliberately not
 * get_active_player_count(), which builds a filtered list on every call - this runs on
 * every allocation attempt of a busy round.
 *
 * A return of <= 0 means "no ceiling", which every caller already handles.
 */
/datum/controller/subsystem/mapping/proc/effective_z_ceiling(pop)
	if(isnull(pop))
		pop = length(GLOB.clients)

	var/base = CONFIG_GET(number/max_z_levels)
	if(base <= 0) // ceiling disabled, scaling something disabled is still disabled
		return base

	var/start = CONFIG_GET(number/max_z_levels_pop_scale_start)
	var/per = CONFIG_GET(number/max_z_levels_pop_scale_per)
	if(start <= 0 || per <= 0) // pop scaling disabled
		return base

	// round() with one argument is floor: the ceiling only steps down on a whole `per`
	// past `start`, never part way.
	var/effective = base - round(max(0, pop - start) / per)

	var/floor_at = CONFIG_GET(number/max_z_levels_pop_floor)
	if(floor_at > 0)
		effective = max(effective, floor_at)
	else
		// No floor still does not mean a NEGATIVE ceiling: <= 0 is the "ceiling disabled"
		// signal every caller reads, so an extreme pop scaling past zero would silently turn
		// the cap OFF at exactly the population it exists for. 1 is the honest bottom - it
		// refuses everything, world.maxz never being less than 1.
		effective = max(effective, 1)
	// The floor is a floor on the SCALING, not a licence to exceed the configured ceiling -
	// a host who sets max_z_levels below the floor meant the smaller number.
	return min(effective, base)

/**
 * Whether world.maxz is at its effective ceiling, i.e. whether minting another z-level
 * is allowed right now.
 *
 * BYOND never frees a z-level: every one ever created keeps its full 255x255 turf plane
 * for the rest of the round - ~49 MB bare, ~76 MB carrying a site - and nothing in the
 * tree limited how many could be made. A round that churned encounters simply climbed
 * until the 32-bit wall killed it. See /datum/config_entry/number/max_z_levels and
 * effective_z_ceiling() above for why the enforced number moves with population.
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
	if(!config) // reachable before config load; nothing to enforce yet
		return FALSE

	var/ceiling = effective_z_ceiling()
	if(ceiling <= 0) // ceiling disabled
		return FALSE

	var/warn_at = CONFIG_GET(number/max_z_levels_warn_at)
	if(warn_at > 0 && world.maxz >= warn_at && world.maxz > z_ceiling_last_warned)
		z_ceiling_last_warned = world.maxz
		log_mapping("SSmapping: world.maxz has reached [world.maxz] against a ceiling of [describe_z_ceiling(ceiling)]. Each level is roughly 49 MB of \
			permanently committed turf plane that BYOND will never free - if this keeps climbing, sites are not recycling.")

	if(world.maxz < ceiling)
		return FALSE

	if(COOLDOWN_FINISHED(src, z_ceiling_admin_cooldown))
		COOLDOWN_START(src, z_ceiling_admin_cooldown, Z_CEILING_ADMIN_INTERVAL)
		var/cap_message = "SSmapping: world.maxz is at its ceiling of [describe_z_ceiling(ceiling)] - new map volume is being REFUSED. \
			Sites that ask for it will wait and retry rather than fail, but nothing new can be charted until something recycles. \
			Raise MAX_Z_LEVELS only if this host has the memory for it (~49 MB per level, never reclaimed)."
		log_mapping(cap_message)
		message_admins(cap_message)
	return TRUE

#undef Z_CEILING_ADMIN_INTERVAL

/**
 * A ceiling as a log line reads: "20" normally, "20 (configured 24, pop-scaled for 112
 * clients)" when the two numbers have parted company. A host reading "at your ceiling of 20"
 * with 24 in their config file otherwise has no way to tell whether the cap or the config is
 * lying to them.
 *
 * Built only where a message is actually being written - at_z_level_ceiling() is asked on
 * every allocation attempt of a busy round and must not format strings for nothing.
 */
/datum/controller/subsystem/mapping/proc/describe_z_ceiling(ceiling)
	var/configured = CONFIG_GET(number/max_z_levels)
	if(ceiling == configured)
		return "[ceiling]"
	return "[ceiling] (configured [configured], pop-scaled for [length(GLOB.clients)] clients)"

/**
 * Whether minting `levels_needed` more z-levels right now stays inside the effective
 * ceiling. The multi-level counterpart to at_z_level_ceiling(), which only ever answers
 * for one.
 *
 * A caller that mints several levels in a loop cannot use the single-level predicate: it
 * passes when there is room for one and then takes several, which is exactly how the
 * colosseum walked two levels past the gate. Ask for the whole stack up front, and refuse
 * the whole stack - half a venue is worse than none.
 */
/datum/controller/subsystem/mapping/proc/z_headroom(levels_needed = 1)
	if(!config) // reachable before config load, same as the predicate above
		return TRUE
	var/ceiling = effective_z_ceiling()
	if(ceiling <= 0) // ceiling disabled
		return TRUE
	return (world.maxz + levels_needed) <= ceiling

/**
 * Reports a z-level mint that has already happened, from inside add_new_zlevel() itself.
 *
 * The gate (at_z_level_ceiling / z_headroom) is a predicate a caller has to remember to
 * ask. add_new_zlevel() enforces nothing, so any code path that forgets mints silently and
 * the round dies to a climb nobody can see in the logs. This is the backstop: it cannot
 * refuse the mint (the level exists by the time it runs) but it makes every one of them
 * visible, and shouts about the ones that came from outside the gate.
 *
 * Kept cheap - it runs on every mint, including the boot-time ones.
 */
/datum/controller/subsystem/mapping/proc/report_z_mint(name)
	if(!config) // boot-time mints, before there is anything to compare against
		return

	var/ceiling = effective_z_ceiling()
	if(ceiling > 0 && world.maxz > ceiling)
		var/past_message = "SSmapping: z-level \"[name]\" was minted PAST the effective ceiling by a code path outside the capacity \
			gate - world.maxz is now [world.maxz] against a ceiling of [describe_z_ceiling(ceiling)]. That is ~49 MB of address \
			space this round can never get back. Whatever minted it needs to ask SSmapping.z_headroom() first."
		log_mapping(past_message)
		message_admins(past_message)
		return

	var/warn_at = CONFIG_GET(number/max_z_levels_warn_at)
	if(warn_at > 0 && world.maxz >= warn_at)
		log_mapping("SSmapping: minted z-level \"[name]\", world.maxz now [world.maxz][ceiling > 0 ? " of [ceiling]" : ""].")

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
	var/list/preloaded = list(
		list("lava", lava_planet_count, /datum/overmap/planet/lava),
		list("ice", ice_planet_count, /datum/overmap/planet/ice),
		list("jungle", jungle_planet_count, /datum/overmap/planet/jungle),
		list("beach", beach_planet_count, /datum/overmap/planet/beach),
		list("wasteland", wasteland_planet_count, /datum/overmap/planet/wasteland),
	)
	for(var/list/entry as anything in preloaded)
		var/planet_name = entry[1]
		var/overmap_type = entry[3]
		var/datum/overmap/planet/registration = new overmap_type
		if(registration.planet_definition_error)
			log_mapping("Preloaded planet '[planet_name]' was not generated: [registration.planet_definition_error]")
			qdel(registration)
			continue
		var/datum/planet/definition = new registration.planet_template
		var/datum/planet_environment/environment = new definition.environment
		for(var/i in 1 to entry[2])
			var/list/lower_traits = environment.level_traits()
			var/list/upper_traits = environment.level_traits()
			lower_traits[ZTRAIT_UP] = 1
			upper_traits[ZTRAIT_DOWN] = 1
			if(registration.ruin_type)
				lower_traits[registration.ruin_type] = TRUE
				upper_traits[registration.ruin_type] = TRUE
			LoadGroup(FailedZs, "Planet [planet_name] [i]", "map_files/voidcrew", "[planet_name].dmm", list(lower_traits, upper_traits))
			z_count += 2
			planets["[planet_name] [i]"] = list("type" = overmap_type, "z" = z_count, "zone_band" = next_planet_zone_band())
		qdel(environment)
		qdel(definition)
		qdel(registration)

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

	for(var/planet_key in planets)
		var/list/record = planets[planet_key]
		var/overmap_type = record["type"]
		if(!ispath(overmap_type, /datum/overmap/planet))
			continue
		var/datum/overmap/planet/planet_info = new overmap_type
		var/planet_z = record["z"]
		generate_planet_ruins(planet_info.planet_template, list(planet_z, planet_z - 1), list(planet_info.surface_area))
		qdel(planet_info)

/datum/controller/subsystem/mapping/setup_rivers()
	for(var/planet_key in planets)
		var/list/record = planets[planet_key]
		var/overmap_type = record["type"]
		if(!ispath(overmap_type, /datum/overmap/planet))
			continue
		var/datum/overmap/planet/planet_info = new overmap_type
		var/planet_type = planet_info.planet_template
		var/list/whitelist_areas = list(planet_info.surface_area, /area/overmap_encounter/planetoid/cave)
		var/planet_z = record["z"]
		qdel(planet_info)
		// Existing roundstart templates have two levels. Both previously received rivers.
		generate_planet_rivers(planet_type, planet_z, whitelist_areas)
		generate_planet_rivers(planet_type, planet_z - 1, whitelist_areas)

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
