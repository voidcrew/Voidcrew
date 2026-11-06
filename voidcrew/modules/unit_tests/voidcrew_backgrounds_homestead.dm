/// Backgrounds: owned by P6.

// Homesteader, the Frontier and the family. Unit tests compile before voidcrew defines: literals,
// each named. The homestead's own tick is stopped while a test runs; tests drive it by hand on a
// homestead of their own over the test room, and never wait for an NPC to walk anywhere.

/// Shared set-up: a homestead over the test room, the round's own one held still meanwhile
/datum/unit_test/voidcrew_homestead
	abstract_type = /datum/unit_test/voidcrew_homestead
	/// The test room's homestead
	var/datum/homestead/homestead
	/// A block on another level, for being somewhere off the "Frontier"
	var/datum/turf_reservation/elsewhere
	/// Whether the round's own homestead was ticking
	var/was_paused

/datum/unit_test/voidcrew_homestead/New()
	. = ..()
	if(GLOB.homestead)
		was_paused = GLOB.homestead.paused
		GLOB.homestead.paused = TRUE

/datum/unit_test/voidcrew_homestead/Destroy()
	if(GLOB.homestead && GLOB.homestead != homestead)
		GLOB.homestead.paused = was_paused
	QDEL_NULL(homestead)
	QDEL_NULL(elsewhere)
	return ..()

/// A homestead whose ground is the test room and whose "Frontier" is the test room's level
/datum/unit_test/voidcrew_homestead/proc/make_homestead()
	var/turf/low = run_loc_floor_bottom_left
	var/turf/high = run_loc_floor_top_right
	homestead = new(list(low.x, low.y, high.x, high.y, low.z), low.z, 0)
	homestead.paused = TRUE
	return homestead

/// A turf on another level
/datum/unit_test/voidcrew_homestead/proc/off_frontier_turf()
	if(!elsewhere)
		elsewhere = SSmapping.request_turf_block_reservation(3, 3, 1)
	var/turf/corner = elsewhere?.bottom_left_turfs[1]
	return corner

// =========================================================================
// THE PLANET
// =========================================================================

/// The Frontier resolves through its definition the way every planet does (voidcrew_planet_definitions)
/datum/unit_test/voidcrew_frontier_definition/Run()
	var/datum/overmap/planet/frontier/registration = allocate(/datum/overmap/planet/frontier)
	TEST_ASSERT_NULL(registration.planet_definition_error, "The Frontier's definition is invalid")
	var/datum/planet/definition = allocate(registration.planet_template)
	var/datum/planet_environment/environment = allocate(definition.environment)
	var/datum/planet_ruins/ruins = allocate(definition.ruin_settings)
	var/datum/planet_rivers/rivers = allocate(definition.river_settings)
	TEST_ASSERT_NULL(environment.validation_error(), "Invalid Frontier environment")
	TEST_ASSERT_NULL(ruins.validation_error(), "Invalid Frontier ruins")
	TEST_ASSERT_NULL(rivers.validation_error(), "Invalid Frontier rivers")
	TEST_ASSERT_EQUAL(registration.mapgen, definition.terrain_generator, "Terrain bypassed the definition")
	TEST_ASSERT_EQUAL(registration.surface_area, environment.area_type, "Surface area bypassed the environment")
	TEST_ASSERT_EQUAL(registration.baseturf, environment.baseturf, "Base turf bypassed the environment")
	TEST_ASSERT_EQUAL(registration.weather_controller_type, environment.weather_type, "Weather bypassed the environment")
	TEST_ASSERT_EQUAL(registration.ruin_type, ruins.theme, "Ruin theme bypassed the settings")
	TEST_ASSERT(!rivers.enabled, "The Frontier acquired rivers")
	var/area/overmap_encounter/planetoid/surface = new environment.area_type
	allocated += surface
	TEST_ASSERT_EQUAL(surface.map_generator, definition.terrain_generator, "Area terrain bypassed the definition")
	TEST_ASSERT_EQUAL(surface.base_lighting_color, environment.light_color, "Daylight color bypassed the environment")
	TEST_ASSERT_EQUAL(surface.default_gravity, environment.gravity, "Gravity bypassed the environment")
	// No mines and no portals on the surface
	for(var/biome_band in definition.overworld_biomes)
		var/list/row = definition.overworld_biomes[biome_band]
		for(var/humidity in row)
			var/datum/biome/biome = SSmapping.biomes[row[humidity]]
			TEST_ASSERT_NOTNULL(biome, "Frontier biome [row[humidity]] is not registered")
			for(var/feature in biome.feature_spawn_list)
				TEST_ASSERT(!ispath(feature, /obj/effect/mine) && !ispath(feature, /obj/structure/spawner), "Frontier surface biome [biome.type] seeds [feature]")

/// The Frontier was built at boot: a green record on a real z pair, the cave without a storm site
/datum/unit_test/voidcrew_frontier_boot/Run()
	var/list/record = frontier_record()
	TEST_ASSERT_NOTNULL(record, "No Frontier in SSmapping.planets")
	TEST_ASSERT_EQUAL(record["zone_band"], 1, "The Frontier is not green") // ZONE_GREEN
	var/surface_z = frontier_surface_z()
	TEST_ASSERT(surface_z > 1 && surface_z <= world.maxz, "The Frontier's z ([surface_z]) is not a real level")
	TEST_ASSERT_EQUAL(frontier_cave_z(), surface_z - 1, "The cave is not just below the surface")
	TEST_ASSERT(SSmapping.level_trait(surface_z, "Down"), "The surface does not link down") // ZTRAIT_DOWN
	TEST_ASSERT(SSmapping.level_trait(surface_z - 1, "Up"), "The cave does not link up") // ZTRAIT_UP
	TEST_ASSERT(!SSmapping.level_trait(surface_z - 1, "Weather_Sandstorm"), "The cave has a sandstorm") // ZTRAIT_SANDSTORM
	// Any tile: generated rock formations take the generic cave area, so no fixed corner is safe
	var/frontier_tiles = 0
	for(var/area/overmap_encounter/planetoid/frontier/ground in GLOB.areas)
		frontier_tiles += length(ground.get_turfs_by_zlevel(surface_z))
	TEST_ASSERT(frontier_tiles > 0, "The surface is not Frontier ground")

/// The cave belongs to the Frontier's marker, and both levels have fauna trackers
/datum/unit_test/voidcrew_frontier_cave/Run()
	var/surface_z = frontier_surface_z()
	TEST_ASSERT(surface_z, "No Frontier")
	var/obj/structure/overmap/planet/frontier
	for(var/obj/structure/overmap/planet/planet as anything in GLOB.overmap_planets)
		if(planet.planet == /datum/overmap/planet/frontier)
			frontier = planet
			break
	TEST_ASSERT_NOTNULL(frontier, "The Frontier has no marker")
	TEST_ASSERT(frontier.preserve_level, "The Frontier can unload")
	TEST_ASSERT_NOTNULL(frontier.cave_footprint, "The Frontier has no cave footprint")
	var/turf/cave_turf = locate(20, 200, surface_z - 1)
	TEST_ASSERT_EQUAL(SSovermap_zones.get_overmap_object_for_turf(cave_turf), frontier, "A cave turf does not resolve to the Frontier")
	TEST_ASSERT(frontier.cave_footprint.zone == frontier.mapzone, "The cave footprint is not the Frontier zone's")
	TEST_ASSERT(SSmapping.get_level(surface_z - 1) in frontier.mapzone.z_levels, "The cave level is not in the Frontier's zone")
	var/datum/planet_mob_tracker/surface = SSplanet_mobs.tracked_planets["frontier_surface"]
	var/datum/planet_mob_tracker/cave = SSplanet_mobs.tracked_planets["frontier_cave"]
	TEST_ASSERT_NOTNULL(surface, "No surface tracker")
	TEST_ASSERT_NOTNULL(cave, "No cave tracker")
	TEST_ASSERT_EQUAL(surface.surface_z, surface_z, "The surface tracker watches the wrong level")
	TEST_ASSERT_EQUAL(cave.surface_z, surface_z - 1, "The cave tracker watches the wrong level")
	TEST_ASSERT_EQUAL(cave.footprint, frontier.cave_footprint, "The cave tracker has no footprint")

// =========================================================================
// THE FAMILY
// =========================================================================

/// Neither the family nor the livestock are swept with the fauna
/datum/unit_test/voidcrew_homestead/residents_stay/Run()
	make_homestead()
	var/mob/living/basic/ambient_npc/homestead/child/child = allocate(/mob/living/basic/ambient_npc/homestead/child, run_loc_floor_bottom_left, homestead)
	var/mob/living/basic/cow/homestead/cow = allocate(/mob/living/basic/cow/homestead)
	var/mob/living/basic/cow/stray = allocate(/mob/living/basic/cow)
	TEST_ASSERT(HAS_TRAIT(child, "homestead_resident"), "The child is not a resident") // TRAIT_HOMESTEAD_RESIDENT
	TEST_ASSERT(HAS_TRAIT(cow, "homestead_resident"), "The cow is not a resident")
	TEST_ASSERT(!SSplanet_mobs.can_despawn(child, TRUE), "The planet sweep would take the child")
	TEST_ASSERT(!SSplanet_mobs.can_despawn(cow, TRUE), "The planet sweep would take the cow")
	TEST_ASSERT(SSplanet_mobs.can_despawn(stray, TRUE), "The sweep takes nothing at all: the test proves nothing")
	TEST_ASSERT(!child.should_inherit_planetary_faction(), "The child sides with the wildlife")
	TEST_ASSERT(!cow.should_inherit_planetary_faction(), "The cow sides with the wildlife")
	TEST_ASSERT(child in homestead.living_members(), "The child is not one of the family")
	TEST_ASSERT(findtext(child.real_name, homestead.surname), "The child does not carry the family name")

/// A child stays small across the looks that reset a transform
/datum/unit_test/voidcrew_homestead/child_scale/Run()
	make_homestead()
	var/mob/living/basic/ambient_npc/homestead/child/child = allocate(/mob/living/basic/ambient_npc/homestead/child, run_loc_floor_bottom_left, homestead)
	TEST_ASSERT_EQUAL(child.transform.a, 0.75, "The child starts full size")
	child.look_dead()
	child.look_alive()
	TEST_ASSERT_EQUAL(child.transform.a, 0.75, "Getting up made the child full size")

/// The family refuses teleports, forced ones too (TEL-1)
/datum/unit_test/voidcrew_homestead/family_teleport/Run()
	make_homestead()
	var/mob/living/basic/ambient_npc/homestead/spouse/spouse = allocate(/mob/living/basic/ambient_npc/homestead/spouse, run_loc_floor_bottom_left, homestead)
	var/turf/start = get_turf(spouse)
	do_teleport(spouse, run_loc_floor_top_right, channel = TELEPORT_CHANNEL_BLUESPACE, forced = TRUE)
	TEST_ASSERT_EQUAL(get_turf(spouse), start, "A forced teleport took the spouse")

/// Carried off the Frontier, a family member is put back home on the next tick (MOV-1)
/datum/unit_test/voidcrew_homestead/family_leash/Run()
	make_homestead()
	var/mob/living/basic/ambient_npc/homestead/child/child = allocate(/mob/living/basic/ambient_npc/homestead/child, run_loc_floor_bottom_left, homestead)
	var/turf/home = child.home
	var/turf/away = off_frontier_turf()
	TEST_ASSERT_NOTNULL(away, "No turf off the test Frontier")
	child.forceMove(away)
	homestead.tend_family()
	TEST_ASSERT_EQUAL(get_turf(child), home, "The child was not brought home")

/// Hostiles by the house: not safe, and the family hides; gone, safe again
/datum/unit_test/voidcrew_homestead/safe_toggle/Run()
	make_homestead()
	var/mob/living/basic/ambient_npc/homestead/spouse/spouse = allocate(/mob/living/basic/ambient_npc/homestead/spouse, run_loc_floor_bottom_left, homestead)
	homestead.update_needs()
	TEST_ASSERT(homestead.safe, "The empty test room is not safe")
	var/mob/living/simple_animal/hostile/asteroid/hermit/ranged/gunslinger/raider = allocate(/mob/living/simple_animal/hostile/asteroid/hermit/ranged/gunslinger, run_loc_floor_top_right)
	raider.toggle_ai(AI_OFF)
	homestead.update_needs()
	TEST_ASSERT(!homestead.safe, "A gunslinger by the house is safe")
	TEST_ASSERT(istype(spouse.activity, /datum/ambient_activity/homestead_hide), "The spouse did not hide")
	qdel(raider)
	homestead.update_needs()
	TEST_ASSERT(homestead.safe, "Safe did not come back")

/// Food in the fridge: fed; taken out: not
/datum/unit_test/voidcrew_homestead/fed_toggle/Run()
	make_homestead()
	var/obj/machinery/smartfridge/fridge = allocate(/obj/machinery/smartfridge)
	var/obj/structure/table/table = allocate(/obj/structure/table, run_loc_floor_top_right)
	homestead.fridge_ref = WEAKREF(fridge)
	homestead.table_refs = list(WEAKREF(table))
	homestead.update_needs()
	TEST_ASSERT(!homestead.fed, "An empty kitchen is fed")
	var/list/food = list()
	for(var/i in 1 to 3) // BACKGROUND_HOMESTEAD_FOOD_MIN
		food += allocate(/obj/item/food/grown/potato, fridge)
	homestead.update_needs()
	TEST_ASSERT(homestead.fed, "Three potatoes in the fridge are not enough")
	QDEL_LIST(food)
	var/obj/item/food/meal = allocate(/obj/item/food/butterbiscuit, run_loc_floor_top_right)
	homestead.update_needs()
	TEST_ASSERT(!homestead.fed, "One biscuit on the table is enough")
	TEST_ASSERT_EQUAL(homestead.find_food(), meal, "The family cannot find the biscuit on the table")

/// A homesteader coming near the family is greeted by name
/datum/unit_test/voidcrew_homestead/greeting/Run()
	make_homestead()
	var/mob/living/basic/ambient_npc/homestead/spouse/spouse = allocate(/mob/living/basic/ambient_npc/homestead/spouse, run_loc_floor_bottom_left, homestead)
	var/mob/living/carbon/human/settler = bg_test_human(run_loc_floor_top_right)
	bg_test_state(settler, "homesteader") // BACKGROUND_HOMESTEADER
	homestead.tend_family()
	TEST_ASSERT(istype(spouse.activity, /datum/ambient_activity/homestead_greet), "The spouse did not greet the homesteader")
	spouse.end_activity()
	homestead.tend_family()
	TEST_ASSERT(!istype(spouse.activity, /datum/ambient_activity/homestead_greet), "The spouse greeted twice in a row")

// =========================================================================
// THE HOMESTEADER
// =========================================================================

/// Taken off the Frontier in cuffs, the goal stays open; walking off it, it fails (MOV-2)
/datum/unit_test/voidcrew_homestead/departure/Run()
	make_homestead()
	var/mob/living/carbon/human/settler = bg_test_human(run_loc_floor_bottom_left)
	var/datum/background_state/state = bg_test_state(settler, "homesteader") // BACKGROUND_HOMESTEADER
	TEST_ASSERT_NOTNULL(state, "No background state")
	var/turf/away = off_frontier_turf()
	TEST_ASSERT_NOTNULL(away, "No turf off the test Frontier")
	// Cuffed on the homestead, carried off
	ADD_TRAIT(settler, TRAIT_RESTRAINED, "homestead_test")
	homestead.tend_homesteaders()
	settler.forceMove(away)
	REMOVE_TRAIT(settler, TRAIT_RESTRAINED, "homestead_test")
	homestead.next_departure_check = 0
	homestead.tend_homesteaders()
	TEST_ASSERT_EQUAL(state.outcome, "ongoing", "Being carried off failed the goal") // BACKGROUND_OUTCOME_ONGOING
	// Home again, then off on their own feet
	settler.forceMove(run_loc_floor_bottom_left)
	homestead.tend_homesteaders()
	settler.forceMove(away)
	homestead.next_departure_check = 0
	homestead.tend_homesteaders()
	TEST_ASSERT_EQUAL(state.outcome, "failed", "Leaving on their own did not fail the goal") // BACKGROUND_OUTCOME_FAILED

/// A homesteader refuses a teleport off the Frontier, and takes one on it (TEL-1)
/datum/unit_test/voidcrew_homestead/settler_teleport/Run()
	var/surface_z = frontier_surface_z()
	if(!surface_z)
		TEST_NOTICE(src, "No Frontier this run: the teleport refusal was not tested")
		return
	var/turf/frontier_turf = locate(20, 200, surface_z)
	var/mob/living/carbon/human/settler = bg_test_human(frontier_turf)
	var/datum/background_state/state = bg_test_state(settler, "homesteader") // BACKGROUND_HOMESTEADER
	var/datum/background/homesteader/background = background_by_key("homesteader")
	background.on_started(settler.mind, state)
	do_teleport(settler, run_loc_floor_top_right, channel = TELEPORT_CHANNEL_BLUESPACE, forced = TRUE)
	TEST_ASSERT_EQUAL(get_turf(settler), frontier_turf, "A teleport took the homesteader off the Frontier")
	var/turf/nearby = locate(22, 200, surface_z)
	do_teleport(settler, nearby, channel = TELEPORT_CHANNEL_BLUESPACE, forced = TRUE)
	TEST_ASSERT_EQUAL(get_turf(settler), nearby, "A teleport across the Frontier was refused")

/// With no homesteader on the Frontier, no raid sets out (ECO-14)
/datum/unit_test/voidcrew_homestead/no_raid_alone/Run()
	make_homestead()
	homestead.next_raid_at = 1
	homestead.tend_raids()
	TEST_ASSERT_NULL(homestead.raid_spot, "A raid set out with nobody home")
	TEST_ASSERT(!length(homestead.raiders), "Raiders came with nobody home")
	TEST_ASSERT_EQUAL(homestead.next_raid_at, 0, "The raid clock ran with nobody home")

/// The background's join entry and job slots
/datum/unit_test/voidcrew_homestead/jobs/Run()
	var/datum/background/homesteader/background = background_by_key("homesteader") // BACKGROUND_HOMESTEADER
	TEST_ASSERT_NOTNULL(background, "No homesteader background")
	var/list/jobs = background.get_jobs()
	TEST_ASSERT_EQUAL(length(jobs), 2, "The homestead does not have two jobs")
	var/total = 0
	for(var/datum/job/job as anything in jobs)
		total += jobs[job]
	TEST_ASSERT_EQUAL(total, 4, "The homestead does not have four places") // BACKGROUND_MAX_HOMESTEADERS
	var/list/options = background.latejoin_options(null)
	TEST_ASSERT_EQUAL(length(options), 1, "The homestead offers more than one start")
	var/list/entry = options[1]
	TEST_ASSERT_EQUAL(entry["id"], "homesteader", "Wrong start id")
	TEST_ASSERT_EQUAL(entry["name"], "Frontier homestead", "Wrong start name")

// =========================================================================
// FIXTURES
// =========================================================================

/// A crop helper for the test: wheat
/obj/effect/mapping_helpers/homestead_crop/test_wheat
	crop = /obj/item/seeds/wheat

/// The crop helper leaves the soil under it ripe; the nesting box keeps eggs
/datum/unit_test/voidcrew_homestead/fixtures/Run()
	var/obj/machinery/hydroponics/soil/soil = allocate(/obj/machinery/hydroponics/soil)
	var/obj/effect/mapping_helpers/homestead_crop/test_wheat/helper = new(run_loc_floor_bottom_left)
	TEST_ASSERT(QDELETED(helper), "The crop helper stayed")
	TEST_ASSERT_NOTNULL(soil.myseed, "Nothing was planted")
	TEST_ASSERT(istype(soil.myseed, /obj/item/seeds/wheat), "The wrong crop was planted")
	TEST_ASSERT_EQUAL(soil.plant_status, "growing", "The crop is not growing") // HYDROTRAY_PLANT_GROWING
	TEST_ASSERT_EQUAL(soil.age, round(soil.myseed.maturation / 2), "The crop is not half grown")
	TEST_ASSERT(soil.age < soil.myseed.lifespan, "The crop starts old")
	var/obj/structure/homestead_coop/coop = allocate(/obj/structure/homestead_coop, run_loc_floor_top_right)
	var/obj/item/food/egg/egg = allocate(/obj/item/food/egg)
	TEST_ASSERT(coop.add_egg(egg), "The nesting box refused an egg")
	TEST_ASSERT_EQUAL(coop.egg_count(), 1, "The egg is not in the nesting box")

/// The field is worked without a player: a ripe plot is harvested and sown again, a dead one cleared and sown
/datum/unit_test/voidcrew_homestead/field_tending/Run()
	make_homestead()
	var/mob/living/basic/ambient_npc/homestead/spouse/spouse = allocate(/mob/living/basic/ambient_npc/homestead/spouse, run_loc_floor_bottom_left, homestead)
	var/obj/machinery/hydroponics/soil/soil = allocate(/obj/machinery/hydroponics/soil, run_loc_floor_top_right)
	soil.waterlevel = soil.maxwater
	homestead.plot_crops[get_turf(soil)] = /obj/item/seeds/wheat
	homestead.sow_plot(soil, /obj/item/seeds/wheat)
	TEST_ASSERT(istype(soil.myseed, /obj/item/seeds/wheat), "Sowing planted nothing")
	TEST_ASSERT(soil.self_sustaining, "A homestead plot was sown without its upkeep")
	TEST_ASSERT_NULL(homestead.next_field_job(spouse), "A growing, watered plot needs work")
	// Ripe: harvested, and sown again at once
	soil.set_plant_status("harvestable") // HYDROTRAY_PLANT_HARVESTABLE
	var/list/work = homestead.next_field_job(spouse)
	TEST_ASSERT_EQUAL(length(work), 2, "The ripe plot was not found")
	TEST_ASSERT_EQUAL(work[1], soil, "The wrong plot was found")
	TEST_ASSERT_EQUAL(work[2], "harvest", "The ripe plot was not due a harvest")
	var/list/harvest = homestead.tend_plot(soil, spouse)
	TEST_ASSERT(length(harvest), "The harvest gave nothing")
	TEST_ASSERT(istype(harvest[1], /obj/item/food/grown/wheat), "The harvest was not wheat")
	TEST_ASSERT(istype(soil.myseed, /obj/item/seeds/wheat), "The plot was not sown again")
	TEST_ASSERT_EQUAL(soil.plant_status, "growing", "The new crop is not growing") // HYDROTRAY_PLANT_GROWING
	TEST_ASSERT(soil.self_sustaining, "The harvest left the plot without its upkeep")
	// Dead: cleared and sown again
	soil.plantdies()
	TEST_ASSERT_EQUAL(homestead.plot_job(soil), "replant", "A dead plot is not due sowing")
	homestead.tend_plot(soil, spouse)
	TEST_ASSERT_EQUAL(soil.plant_status, "growing", "The dead plot was not sown again") // HYDROTRAY_PLANT_GROWING
	// Emptied by a player: sown from the stock
	soil.set_seed(null)
	homestead.tend_plot(soil, spouse)
	TEST_ASSERT(istype(soil.myseed, /obj/item/seeds/wheat), "An emptied plot was not sown from the stock")
	// The harvest goes in the fridge
	var/obj/machinery/smartfridge/fridge = allocate(/obj/machinery/smartfridge, run_loc_floor_top_right)
	var/obj/structure/table/table = allocate(/obj/structure/table, run_loc_floor_top_right)
	homestead.fridge_ref = WEAKREF(fridge)
	homestead.table_refs = list(WEAKREF(table))
	homestead.store_harvest(harvest)
	var/stored = 0
	for(var/obj/item/food/grown/wheat/sheaf in fridge.contents)
		stored++
	TEST_ASSERT_EQUAL(stored, length(harvest), "The harvest did not go in the fridge")

/// Animals cannot open the homestead's doors, the family and bandits can; the cellar is barred in a raid
/datum/unit_test/voidcrew_homestead/doors/Run()
	make_homestead()
	var/obj/machinery/door/airlock/wood/house_door = allocate(/obj/machinery/door/airlock/wood, run_loc_floor_bottom_left)
	var/obj/machinery/door/airlock/wood/cellar_door = allocate(/obj/machinery/door/airlock/wood, run_loc_floor_top_right)
	homestead.watch_door(house_door)
	homestead.watch_door(cellar_door, TRUE)
	var/mob/living/basic/chicken/homestead/hen = allocate(/mob/living/basic/chicken/homestead)
	var/mob/living/basic/ambient_npc/homestead/child/child = allocate(/mob/living/basic/ambient_npc/homestead/child, run_loc_floor_bottom_left, homestead)
	var/mob/living/simple_animal/hostile/asteroid/hermit/ranged/gunslinger/raider = allocate(/mob/living/simple_animal/hostile/asteroid/hermit/ranged/gunslinger)
	raider.toggle_ai(AI_OFF)
	var/mob/living/carbon/human/visitor = allocate(/mob/living/carbon/human/consistent)
	var/mob/living/carbon/human/settler = bg_test_human(run_loc_floor_bottom_left)
	bg_test_state(settler, "homesteader") // BACKGROUND_HOMESTEADER
	TEST_ASSERT(!house_door.allowed(hen), "A hen opens the house door")
	TEST_ASSERT(house_door.allowed(child), "The family cannot open the house door")
	TEST_ASSERT(house_door.allowed(raider), "Bandits cannot open the house door")
	TEST_ASSERT(house_door.allowed(visitor), "A visitor cannot open the house door")
	homestead.safe = TRUE
	homestead.safe_since = 0
	TEST_ASSERT(cellar_door.allowed(visitor), "The cellar is barred with nothing near")
	homestead.safe = FALSE
	TEST_ASSERT(!cellar_door.allowed(raider), "Raiders open the barred cellar")
	TEST_ASSERT(!cellar_door.allowed(visitor), "A stranger opens the barred cellar")
	TEST_ASSERT(cellar_door.allowed(child), "The family is barred out of its own cellar")
	TEST_ASSERT(cellar_door.allowed(settler), "A homesteader is barred out of the cellar")
	TEST_ASSERT(homestead.bar_cellar(), "Nobody barred the cellar")
	TEST_ASSERT(!homestead.bar_cellar(), "The cellar was barred twice in one raid")

/// Raiders at the kitchen take food, one thing each
/datum/unit_test/voidcrew_homestead/raiders_take_food/Run()
	make_homestead()
	var/obj/machinery/smartfridge/fridge = allocate(/obj/machinery/smartfridge, run_loc_floor_top_right)
	var/obj/structure/table/table = allocate(/obj/structure/table, run_loc_floor_top_right)
	homestead.fridge_ref = WEAKREF(fridge)
	homestead.table_refs = list(WEAKREF(table))
	var/obj/item/food/grown/potato/first = allocate(/obj/item/food/grown/potato, fridge)
	var/obj/item/food/grown/potato/second = allocate(/obj/item/food/grown/potato, fridge)
	var/mob/living/simple_animal/hostile/asteroid/hermit/ranged/gunslinger/raider = allocate(/mob/living/simple_animal/hostile/asteroid/hermit/ranged/gunslinger, run_loc_floor_top_right)
	raider.toggle_ai(AI_OFF)
	homestead.raiders = list(WEAKREF(raider))
	homestead.raiders_loot()
	TEST_ASSERT(QDELETED(first) != QDELETED(second), "The raider did not take exactly one thing")
	homestead.raiders_loot()
	TEST_ASSERT(QDELETED(first) != QDELETED(second), "The raider took a second thing")

// =========================================================================
// THE MAP (map-contracts.md M4)
// =========================================================================

/// The homestead template carries what the code relies on. Skipped on P0's placeholder.
/datum/unit_test/voidcrew_homestead_map
	/// The block the homestead is loaded into
	var/datum/turf_reservation/reserve

/datum/unit_test/voidcrew_homestead_map/Destroy()
	QDEL_NULL(reserve)
	return ..()

/datum/unit_test/voidcrew_homestead_map/Run()
	var/datum/map_template/ruin/frontier_homestead/template = new
	if(template.width < 36 || template.height < 30)
		TEST_NOTICE(src, "The homestead map is P0's [template.width]x[template.height] placeholder: the map contract was not tested")
		return
	reserve = SSmapping.request_turf_block_reservation(template.width + 2, template.height + 2, 1)
	TEST_ASSERT_NOTNULL(reserve, "Could not reserve a block for the homestead")
	var/turf/corner = reserve.bottom_left_turfs[1]
	var/turf/origin = locate(corner.x + 1, corner.y + 1, corner.z)
	TEST_ASSERT(template.load(origin), "The homestead did not load")
	var/list/turf/tiles = block(origin, locate(origin.x + template.width - 1, origin.y + template.height - 1, origin.z))

	var/list/counts = list()
	var/static/list/forbidden = list(
		/mob/living/simple_animal/hostile,
		/obj/effect/mob_spawn,
		/obj/machinery/power/apc,
		/obj/machinery/power/port_gen,
		/obj/item/gun,
		/obj/item/ammo_box,
		/obj/item/ammo_casing,
		/obj/item/clothing/suit/armor,
		/obj/item/stack/spacecash,
		/obj/structure/ladder,
	)
	var/static/list/counted = list(
		/obj/structure/homestead_coop,
		/obj/effect/landmark/homestead/spouse,
		/obj/effect/landmark/homestead/child,
		/obj/effect/landmark/homestead/settler,
		/obj/effect/landmark/homestead/settler/rancher,
		/obj/structure/water_source/homestead_well,
		/mob/living/basic/cow/homestead,
		/mob/living/basic/chicken/homestead,
		/mob/living/basic/goat/homestead,
		/mob/living/basic/pony/syndicate/homestead,
		/mob/living/basic/pet/dog/corgi/homestead,
	)
	var/sustaining_soil = 0
	var/planted_soil = 0
	var/list/turf/cellar_tiles = list()
	for(var/turf/tile as anything in tiles)
		var/area/tile_area = tile.loc
		TEST_ASSERT(istype(tile_area, /area/voidcrew/homestead), "[tile.x - origin.x + 1],[tile.y - origin.y + 1] is in [tile_area.type], not a homestead area")
		TEST_ASSERT(tile_area.area_flags & NOTELEPORT, "[tile_area.type] allows teleports")
		TEST_ASSERT(!istype(tile, /turf/template_noop), "A template_noop turf inside the homestead")
		if(istype(tile_area, /area/voidcrew/homestead/cellar))
			cellar_tiles += tile
		// Shell: a wall of the house, barn or cellar facing the yard is indestructible
		if(isclosedturf(tile) && !istype(tile_area, /area/voidcrew/homestead/yard))
			for(var/direction in GLOB.cardinals)
				var/turf/neighbour = get_step(tile, direction)
				if(neighbour && istype(neighbour.loc, /area/voidcrew/homestead/yard) && isopenturf(neighbour))
					TEST_ASSERT(istype(tile, /turf/closed/indestructible), "Shell wall at [tile.x - origin.x + 1],[tile.y - origin.y + 1] is [tile.type]")
					break
		for(var/atom/movable/thing as anything in tile)
			for(var/bad_type in forbidden)
				TEST_ASSERT(!istype(thing, bad_type), "Forbidden [thing.type] at [tile.x - origin.x + 1],[tile.y - origin.y + 1]")
			if(thing.type in counted)
				counts[thing.type] = (counts[thing.type] || 0) + 1
			if(istype(thing, /obj/machinery/hydroponics/soil))
				var/obj/machinery/hydroponics/soil/soil = thing
				if(soil.self_sustaining)
					sustaining_soil++
				if(soil.myseed)
					planted_soil++

	TEST_ASSERT_EQUAL(counts[/obj/structure/homestead_coop], 1, "Nesting boxes")
	TEST_ASSERT_EQUAL(counts[/obj/effect/landmark/homestead/spouse], 1, "Spouse markers")
	TEST_ASSERT_EQUAL(counts[/obj/effect/landmark/homestead/child], 2, "Child markers")
	TEST_ASSERT_EQUAL(counts[/obj/effect/landmark/homestead/settler/rancher], 1, "Rancher markers")
	TEST_ASSERT_EQUAL(counts[/obj/effect/landmark/homestead/settler], 3, "Hand markers")
	TEST_ASSERT_EQUAL(counts[/obj/structure/water_source/homestead_well], 1, "Wells")
	TEST_ASSERT_EQUAL(counts[/mob/living/basic/cow/homestead], 2, "Cows")
	TEST_ASSERT_EQUAL(counts[/mob/living/basic/chicken/homestead], 3, "Chickens")
	TEST_ASSERT_EQUAL(counts[/mob/living/basic/goat/homestead], 1, "Goats")
	TEST_ASSERT_EQUAL(counts[/mob/living/basic/pony/syndicate/homestead], 1, "Ponies")
	TEST_ASSERT_EQUAL(counts[/mob/living/basic/pet/dog/corgi/homestead], 1, "Dogs")
	TEST_ASSERT(sustaining_soil >= 16, "Only [sustaining_soil] self-sustaining soil beds")
	TEST_ASSERT_EQUAL(planted_soil, 12, "Planted beds")
	// The cellar is reached from the house through one door
	TEST_ASSERT(length(cellar_tiles), "No storm cellar")
	var/cellar_doors = 0
	for(var/turf/tile as anything in tiles)
		var/obj/door = (locate(/obj/machinery/door/airlock) in tile) || (locate(/obj/structure/mineral_door) in tile)
		if(!door)
			continue
		var/touches_cellar = FALSE
		var/touches_house = FALSE
		for(var/direction in GLOB.cardinals)
			var/turf/neighbour = get_step(tile, direction)
			if(istype(neighbour?.loc, /area/voidcrew/homestead/cellar))
				touches_cellar = TRUE
			else if(istype(neighbour?.loc, /area/voidcrew/homestead/house))
				touches_house = TRUE
		if(touches_cellar && touches_house)
			cellar_doors++
	TEST_ASSERT_EQUAL(cellar_doors, 1, "Doors between the house and the cellar")
