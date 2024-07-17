/**
 * We are modularly making stuff we don't want, early return.
 * We can manually re-add whatever we need here as well.
 */
/datum/controller/subsystem/mapping
	///List of all ships that can be purchased.
	var/list/datum/map_template/shuttle/voidcrew/ship_purchase_list = list()
	///List of all Nanotrasen ships, one is randomly selected to spawn at start.
	var/list/datum/map_template/shuttle/voidcrew/nt_ship_list = list()
	///List of all Syndicate ships, one is randomly selected to spawn at start.
	var/list/datum/map_template/shuttle/voidcrew/syn_ship_list = list()

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

/datum/controller/subsystem/mapping/Initialize(timeofday)
	load_ship_templates()
	return ..()

#define INIT_ANNOUNCE(X) to_chat(world, span_boldannounce("[X]")); log_world(X)
/datum/controller/subsystem/mapping/loadWorld()
	InitializeDefaultZLevels()
	var/list/FailedZs = list()
	var/list/planet_types = list("lava", "ice", "jungle", "beach", "wasteland")

	// for(var/planet_type in planet_types)
	// 	for(var/i in 0 to 2)
	// 		LoadGroup(FailedZs, "Planet [planet_type] [i]", "map_files/voidcrew", "[planet_type].dmm", default_traits = list(ZTRAIT_MINING))

	for(var/i in 1 to 15)
		LoadGroup(FailedZs, "Planet lava 1", "map_files/voidcrew", "lava.dmm", default_traits = list(ZTRAIT_MINING, ZTRAIT_LAVA_RUINS))

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
	if(config.minetype == "lavaland")
		banned += generateMapList("lavaruinblacklist.txt")
	else if(config.blacklist_file)
		banned += generateMapList(config.blacklist_file)

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

/datum/controller/subsystem/mapping/setup_rivers()
	// Generate mining ruins
	var/list/lava_ruins = levels_by_trait(ZTRAIT_LAVA_RUINS)
	for (var/lava_z in lava_ruins)
		spawn_rivers(lava_z, 4, /turf/open/lava/smooth/lava_land_surface, /area/lavaland/surface/outdoors/unexplored)

	var/list/ice_ruins = levels_by_trait(ZTRAIT_ICE_RUINS)
	for (var/ice_z in ice_ruins)
		var/river_type = HAS_TRAIT(SSstation, STATION_TRAIT_FORESTED) ? /turf/open/lava/plasma/ice_moon : /turf/open/openspace/icemoon
		spawn_rivers(ice_z, 4, river_type, /area/icemoon/surface/outdoors/unexplored/rivers)

	var/list/ice_ruins_underground = levels_by_trait(ZTRAIT_ICE_RUINS_UNDERGROUND)
	for (var/ice_z in ice_ruins_underground)
		spawn_rivers(ice_z, 4, level_trait(ice_z, ZTRAIT_BASETURF), /area/icemoon/underground/unexplored/rivers)

/datum/controller/subsystem/mapping/proc/load_ship_templates()
	SHOULD_CALL_PARENT(TRUE)
	if(ship_purchase_list.len) //don't build repeatedly
		return

	for(var/datum/map_template/shuttle/voidcrew/shuttles as anything in subtypesof(/datum/map_template/shuttle/voidcrew))
		ship_purchase_list["[initial(shuttles.name)] ([initial(shuttles.faction_prefix)] [initial(shuttles.part_cost)] part\s)"] = shuttles

		switch(initial(shuttles.faction_prefix))
			if(NANOTRASEN_SHIP)
				nt_ship_list[initial(shuttles.name)] = shuttles
			if(SYNDICATE_SHIP)
				syn_ship_list[initial(shuttles.name)] = shuttles

/datum/controller/subsystem/mapping/get_station_center()
	return SSovermap.overmap_centre || locate(OVERMAP_LEFT_SIDE_COORD, OVERMAP_NORTH_SIDE_COORD, OVERMAP_Z_LEVEL)
