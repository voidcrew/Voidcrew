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
	for(var/i in 0 to 20)
		LoadGroup(FailedZs, "Planet [i]", "map_files/voidcrew", "debug.dmm", default_traits = list(ZTRAIT_MINING))
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
	. = ..()
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
