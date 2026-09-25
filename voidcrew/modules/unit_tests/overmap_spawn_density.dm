/// Zone literals are used because unit tests are included before Voidcrew defines.
/datum/unit_test/overmap_density_allocation/Run()
	var/list/bands = list(1, 2, 3)
	var/list/sizes = list("1" = 221, "2" = 640, "3" = 1540)
	var/list/counts = list("1" = 5, "2" = 0, "3" = 0)
	for(var/i in 1 to 25)
		var/band = SSovermap.least_dense_band(bands, counts, sizes)
		counts["[band]"]++
	TEST_ASSERT_EQUAL(counts["1"], 5, "The starting biome guarantee must count against later allocations")
	TEST_ASSERT(counts["2"] >= 7, "The middle zone lost its planet supply")
	TEST_ASSERT(counts["3"] >= 17, "The outer zone must receive an area-based share")
	TEST_ASSERT_EQUAL(SSovermap.least_dense_band(list(2, 3), list("2" = 200, "3" = 250), sizes), 3, "Higher raw count must not outweigh lower density")
	TEST_ASSERT_EQUAL(SSovermap.least_dense_band(list(1), counts, list("1" = 0)), null, "A zero-area band cannot accept spawns")

/datum/unit_test/overmap_layout_repair/Run()
	var/turf/origin = SSovermap.overmap_centre
	var/list/chart = block(locate(origin.x - 4, origin.y - 4, origin.z), locate(origin.x + 4, origin.y + 4, origin.z))
	var/datum/overmap_layout/layout = allocate(/datum/overmap_layout, chart)
	// An unbroken wall must get a local opening, without moving the destination.
	for(var/turf/spot as anything in chart)
		if(spot.x == origin.x)
			layout.add_hazard(spot, /obj/structure/overmap/event/electric)
	var/turf/destination = locate(origin.x + 2, origin.y, origin.z)
	layout.record_destination(destination, "planet")
	TEST_ASSERT(layout.ensure_connected(), "A repairable wall was left in place")
	TEST_ASSERT_EQUAL(layout.repaired_tiles, 1, "Only one tile is needed to open this wall")
	TEST_ASSERT_EQUAL(layout.destinations[destination], "planet", "Repairs must preserve destinations")
	var/list/clear = layout.free_tiles()
	TEST_ASSERT_EQUAL(length(layout.flood(clear[1])), length(clear), "Repair left disconnected clear space")
	// Four cardinal hazards isolate this tile even though diagonals look open.
	var/datum/overmap_layout/pocket = allocate(/datum/overmap_layout, chart)
	for(var/direction in GLOB.cardinals)
		pocket.add_hazard(get_step(origin, direction), /obj/structure/overmap/event/meteor)
	TEST_ASSERT(pocket.ensure_connected(), "A pocket requiring cardinal access was left isolated")
	TEST_ASSERT_EQUAL(pocket.repaired_tiles, 1, "A single opening should reconnect the pocket")
	var/datum/overmap_layout/permanent = allocate(/datum/overmap_layout, chart)
	for(var/turf/spot as anything in chart)
		if(spot.x == origin.x)
			permanent.obstacles[spot] = TRUE
	TEST_ASSERT(!permanent.ensure_connected(), "Permanent obstacles must not be silently removed")
	TEST_ASSERT_EQUAL(length(permanent.obstacles), 9, "Repair changed permanent obstacles")

/// Exercise the actual planner repeatedly without loading planets or creating event atoms.
/datum/unit_test/overmap_layout_batch/Run()
	var/total_destinations = 0
	var/destinations_on_spokes = 0
	var/total_hazards_on_spokes = 0
	for(var/sample in 1 to 32)
		var/datum/overmap_layout/layout = SSovermap.get_overmap_layout(FALSE)
		var/list/counts = list("1" = 0, "2" = 0, "3" = 0)
		for(var/i in 1 to 30)
			var/band = i <= 5 ? 1 : SSovermap.least_dense_band(list(1, 2, 3), counts, layout.band_sizes)
			var/turf/spot = layout.pick_destination(band)
			TEST_ASSERT(spot, "Planet allocation exhausted the chart")
			layout.record_destination(spot, "planet")
			counts["[band]"]++
		var/ruin_count = 48 + (sample % 3) * 12
		var/list/ruins = layout.plan_destinations(ruin_count)
		TEST_ASSERT_EQUAL(length(ruins), ruin_count, "Ruin allocation exhausted the chart")
		TEST_ASSERT_EQUAL(layout.destination_coverage_penalty(), 0, "A large destination-free region survived layout sampling")
		for(var/band in list(1, 2, 3))
			layout.record_destination(layout.pick_destination(band), "outpost")
		TEST_ASSERT(layout.generate_hazards(), "Sample [sample] could not produce navigable space")
		check_layout(layout, "sample [sample]")
		for(var/turf/spot as anything in layout.destinations)
			total_destinations++
			var/dx = abs(spot.x - SSovermap.overmap_centre.x)
			var/dy = abs(spot.y - SSovermap.overmap_centre.y)
			if(dx <= 1 || dy <= 1 || abs(dx - dy) <= 1)
				destinations_on_spokes++
		for(var/turf/spot as anything in layout.hazards)
			var/dx = abs(spot.x - SSovermap.overmap_centre.x)
			var/dy = abs(spot.y - SSovermap.overmap_centre.y)
			if(dx <= 1 || dy <= 1 || abs(dx - dy) <= 1)
				total_hazards_on_spokes++
		if(fexists("data/overmap-layout-previews.enabled"))
			var/list/snapshot = list()
			for(var/turf/spot as anything in layout.tiles)
				snapshot += list(list(spot.x, spot.y, layout.tiles[spot], layout.destinations[spot], "[layout.hazards[spot]]", !!layout.obstacles[spot]))
			var/path = "data/overmap-layout-work/sample-[sample].json"
			fdel(path)
			text2file(json_encode(snapshot), path)
		qdel(layout)
		CHECK_TICK
	TEST_ASSERT(destinations_on_spokes < total_destinations * 0.40, "Destinations are still strongly attracted to the old spokes")
	TEST_ASSERT(total_hazards_on_spokes > 1000, "The old spokes are still implicitly reserved")

/datum/unit_test/overmap_layout_batch/proc/check_layout(datum/overmap_layout/layout, label)
	var/list/clear = layout.free_tiles()
	var/list/reached = layout.flood(clear[1])
	TEST_ASSERT_EQUAL(length(reached), length(clear), "[label]: all clear space must be connected without event crossings")
	for(var/turf/spot as anything in layout.destinations)
		TEST_ASSERT(reached[spot], "[label]: a destination cannot be reached safely")
	for(var/turf/spot as anything in layout.hazards)
		var/has_approach = FALSE
		for(var/turf/adjacent as anything in layout.neighbors[spot])
			if(reached[adjacent])
				has_approach = TRUE
				break
		TEST_ASSERT(has_approach, "[label]: an event has no hazard-free approach")
	for(var/band in list(1, 2, 3))
		var/list/band_clear = layout.free_tiles(band)
		TEST_ASSERT_EQUAL(length(layout.flood(band_clear[1], band)), length(band_clear), "[label]: zone [band] contains isolated clear space")
		var/density = layout.hazard_counts["[band]"] / layout.band_sizes["[band]"]
		TEST_ASSERT(density <= (band == 1 ? 0.15 : 0.30), "[label]: hazard budget exceeded")
		TEST_ASSERT(density >= (band == 1 ? 0.08 : 0.22), "[label]: navigation repair removed too much content from zone [band]")
	var/list/types = layout.event_counts()
	var/meteors = 0
	for(var/path in types)
		if(ispath(path, /obj/structure/overmap/event/meteor))
			meteors += types[path]
	TEST_ASSERT(meteors >= 18, "[label]: insufficient mining fields")
	for(var/path in GLOB.overmap_event_guaranteed_list)
		TEST_ASSERT(types[path], "[label]: a guaranteed event type is absent")

/// Check real boot objects too, including delayed sites and the starting fleet.
/datum/unit_test/overmap_generated_density/Run()
	var/datum/overmap_layout/layout = SSovermap.get_overmap_layout()
	allocated += layout
	var/list/clear = layout.free_tiles()
	var/list/reached = layout.flood(clear[1])
	TEST_ASSERT_EQUAL(length(reached), length(clear), "The spawned chart contains inaccessible clear space")
	for(var/turf/spot as anything in layout.destinations)
		TEST_ASSERT(reached[spot], "A spawned destination has no hazard-free route")
	for(var/obj/structure/overmap/ship/ship as anything in SSovermap.initial_ships)
		var/turf/spot = get_turf(ship)
		TEST_ASSERT(reached[spot], "A starting ship cannot reach the safe navigation network")
		TEST_ASSERT_EQUAL(layout.tiles[spot], 1, "A starting ship is outside green")
	var/list/green_biomes = list()
	for(var/turf/spot as anything in layout.tiles)
		if(layout.tiles[spot] != 1)
			continue
		for(var/obj/structure/overmap/planet/planet in spot)
			green_biomes |= planet.type
	TEST_ASSERT(length(green_biomes) >= 5, "The default starting zone needs every dynamic biome")
