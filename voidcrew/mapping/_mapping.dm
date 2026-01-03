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

	// This is a balancing act.
	// Each planet will consume a significant amount of memory,
	// so we need to be careful about how many starting planets we include
	var/lava_planet_count = 0
	var/ice_planet_count = 0
	var/jungle_planet_count = 0
	var/beach_planet_count = 0
	var/wasteland_planet_count = 0

	var/list/planets = list()

/datum/controller/subsystem/mapping/Initialize(timeofday)
	load_ship_templates()
	return ..()

#define INIT_ANNOUNCE(X) to_chat(world, span_boldannounce("[X]")); log_world(X)
/datum/controller/subsystem/mapping/loadWorld()
	InitializeDefaultZLevels()
	var/list/FailedZs = list()
	var/z_count = 1
	for(var/i in 1 to lava_planet_count)
		LoadGroup(FailedZs, "Planet lava [i]", "map_files/voidcrew", "lava.dmm", list(list(ZTRAIT_UP=1, ZTRAIT_MINING, ZTRAIT_LAVA_RUINS, ZTRAIT_ASHSTORM), list(ZTRAIT_DOWN=1, ZTRAIT_MINING, ZTRAIT_LAVA_RUINS, ZTRAIT_ASHSTORM)))
		z_count += 2
		var/list/p = list(type = /datum/overmap/planet/lava, z = z_count)
		planets += list("lava [i]" = p)

	for(var/i in 1 to ice_planet_count)
		LoadGroup(FailedZs, "Planet ice [i]", "map_files/voidcrew", "ice.dmm", list(list(ZTRAIT_UP=1, ZTRAIT_MINING, ZTRAIT_ICE_RUINS, ZTRAIT_SNOWSTORM), list(ZTRAIT_DOWN=1, ZTRAIT_MINING, ZTRAIT_ICE_RUINS, ZTRAIT_SNOWSTORM)))
		z_count += 2
		var/list/p = list(type = /datum/overmap/planet/ice, z = z_count)
		planets += list("ice [i]" = p)

	for(var/i in 1 to jungle_planet_count)
		LoadGroup(FailedZs, "Planet jungle [i]", "map_files/voidcrew", "jungle.dmm", list(list(ZTRAIT_UP=1, ZTRAIT_MINING, ZTRAIT_JUNGLE_RUINS), list(ZTRAIT_DOWN=1, ZTRAIT_MINING, ZTRAIT_JUNGLE_RUINS)))
		z_count += 2
		var/list/p = list(type = /datum/overmap/planet/jungle, z = z_count)
		planets += list("jungle [i]" = p)

	for(var/i in 1 to beach_planet_count)
		LoadGroup(FailedZs, "Planet beach [i]", "map_files/voidcrew", "beach.dmm", list(list(ZTRAIT_UP=1, ZTRAIT_MINING, ZTRAIT_BEACH_RUINS), list(ZTRAIT_DOWN=1, ZTRAIT_MINING, ZTRAIT_BEACH_RUINS)))
		z_count += 2
		var/list/p = list(type = /datum/overmap/planet/beach, z = z_count)
		planets += list("beach [i]" = p)

	for(var/i in 1 to wasteland_planet_count)
		LoadGroup(FailedZs, "Planet wasteland [i]", "map_files/voidcrew", "wasteland.dmm", list(list(ZTRAIT_UP=1, ZTRAIT_MINING, ZTRAIT_WASTELAND_RUINS), list(ZTRAIT_DOWN=1, ZTRAIT_MINING, ZTRAIT_WASTELAND_RUINS)))
		z_count += 2
		var/list/p = list(type = /datum/overmap/planet/wasteland, z = z_count)
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
