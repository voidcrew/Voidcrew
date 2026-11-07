/// A deterministic miss on every random sample, followed by the real exhaustive pass.
/datum/map_generator/planet_generator/anomaly_test
	var/turf/forced_sample
	var/sample_calls = 0

/datum/map_generator/planet_generator/anomaly_test/pick_anomaly_turf(list/turfs)
	// Deliberately replace random sampling; placement and all safety checks remain real.
	sample_calls++
	return forced_sample

/// Small, reversible ground fixtures on the unit-test level, with harmless anomaly types.
/datum/unit_test/voidcrew_planet_anomalies
	abstract_type = /datum/unit_test/voidcrew_planet_anomalies
	var/datum/biome/ground_biome
	var/list/original_turfs = list()
	var/list/remembered_turfs = list()
	var/list/original_anomalies
	var/list/obj/structure/overmap/planet/planets = list()

/datum/unit_test/voidcrew_planet_anomalies/New()
	. = ..()
	ground_biome = allocate(/datum/biome)
	ground_biome.open_turf_types = list(/turf/open/floor/plating = 1)
	ground_biome.flora_spawn_chance = 0
	ground_biome.feature_spawn_chance = 0
	ground_biome.mob_spawn_chance = 0
	original_anomalies = GLOB.voidcrew_planet_anomalies
	GLOB.voidcrew_planet_anomalies = list(/obj/effect/anomaly/grav/planetary = 1)

/datum/unit_test/voidcrew_planet_anomalies/Destroy()
	GLOB.voidcrew_planet_anomalies = original_anomalies
	original_anomalies = null
	for(var/obj/structure/overmap/planet/planet as anything in planets)
		// These fixtures borrow the test level, never its teardown authority.
		planet.footprint = null
		planet.mapzone = null
	planets.Cut()
	QDEL_LIST(allocated)
	for(var/list/snapshot as anything in original_turfs)
		var/turf/target = locate(snapshot[1], snapshot[2], snapshot[3])
		for(var/obj/effect/anomaly/anomaly in target)
			qdel(anomaly)
		if(target.type != snapshot[4])
			target = target.ChangeTurf(snapshot[4])
		target.change_area(get_area(target), snapshot[8])
		target.turf_flags = snapshot[5]
		target.generating_biome = snapshot[6]
		target.planet_river = snapshot[7]
		target.density = snapshot[9]
	original_turfs.Cut()
	remembered_turfs.Cut()
	ground_biome = null
	return ..()

/datum/unit_test/voidcrew_planet_anomalies/proc/remember_turf(turf/target)
	var/key = "[target.x],[target.y],[target.z]"
	if(remembered_turfs[key])
		return
	remembered_turfs[key] = TRUE
	original_turfs += list(list(target.x, target.y, target.z, target.type, target.turf_flags, target.generating_biome, target.planet_river, get_area(target), target.density))

/datum/unit_test/voidcrew_planet_anomalies/proc/ground(x, y)
	var/turf/target = locate(x, y, run_loc_floor_bottom_left.z)
	remember_turf(target)
	target = target.ChangeTurf(/turf/open/floor/plating)
	target.change_area(get_area(target), get_area(run_loc_floor_bottom_left))
	target.generating_biome = ground_biome
	target.turf_flags &= ~NO_RUINS
	target.planet_river = FALSE
	return target

/datum/unit_test/voidcrew_planet_anomalies/proc/anomalies_on(list/turfs)
	var/list/found = list()
	for(var/turf/target as anything in turfs)
		for(var/obj/effect/anomaly/anomaly in target)
			found += anomaly
	return found

/// Drive populate_terrain itself, so a correct define behind a leftover chance roll fails.
/datum/unit_test/voidcrew_planet_anomalies/counts/Run()
	var/list/turfs = list(ground(40, 40), ground(60, 40), ground(80, 40))
	var/datum/map_generator/planet_generator/generator = allocate(/datum/map_generator/planet_generator)
	generator.throttled = FALSE
	// Literals 1/2/3 are ZONE_GREEN/YELLOW/RED; fork defines are included after tests.
	for(var/band in 1 to 3)
		generator.populate_terrain(turfs, get_area(turfs[1]), band)
		var/list/spawned = anomalies_on(turfs)
		TEST_ASSERT_EQUAL(length(spawned), band, "Band [band] did not seed its natural anomaly count")
		QDEL_LIST(spawned)

/// Exhaustive placement recovers all missed sites, while keeping every rejection intact.
/datum/unit_test/voidcrew_planet_anomalies/sampling_misses/Run()
	var/turf/river = ground(40, 40)
	river.planet_river = TRUE
	var/turf/dense = ground(41, 40)
	dense.density = TRUE
	var/turf/no_biome = ground(42, 40)
	no_biome.generating_biome = null
	var/turf/wrong_ground = ground(43, 40)
	var/datum/biome/other_biome = allocate(/datum/biome)
	other_biome.open_turf_types = list(/turf/open/space = 1)
	wrong_ground.generating_biome = other_biome
	var/turf/structure = ground(44, 40)
	allocate(/obj/structure, structure)
	var/turf/occupied = ground(45, 40)
	allocate(/mob/living/basic, occupied)
	var/list/rejected = list(river, dense, no_biome, wrong_ground, structure, occupied)
	var/list/legal = list(ground(40, 60), ground(60, 60), ground(80, 60))
	var/datum/map_generator/planet_generator/anomaly_test/generator = allocate(/datum/map_generator/planet_generator/anomaly_test)
	generator.throttled = FALSE
	generator.forced_sample = river
	TEST_ASSERT_EQUAL(generator.place_budgeted_anomalies(rejected + legal, 3), 3, "Sampling misses lost a safely placeable anomaly")
	TEST_ASSERT_EQUAL(generator.sample_calls, 400, "The fixture did not exhaust PLANET_ANOMALY_PLACEMENT_ATTEMPTS")
	TEST_ASSERT_EQUAL(length(anomalies_on(legal)), 3, "The fallback did not fill all legal sites")
	TEST_ASSERT_EQUAL(length(anomalies_on(rejected)), 0, "The fallback put an anomaly on unsafe ground")
	dense.density = FALSE

/// Geometry may leave a shortfall; 19 tiles is too close, exactly 20 is legal.
/datum/unit_test/voidcrew_planet_anomalies/shortfall/Run()
	var/turf/first = ground(40, 40)
	var/turf/too_close = ground(59, 40)
	var/turf/boundary = ground(60, 40)
	var/datum/map_generator/planet_generator/anomaly_test/generator = allocate(/datum/map_generator/planet_generator/anomaly_test)
	generator.throttled = FALSE
	generator.forced_sample = first
	TEST_ASSERT_EQUAL(generator.place_budgeted_anomalies(list(first, too_close, boundary), 3), 2, "A shortfall forced an anomaly inside the separation limit")
	TEST_ASSERT_NULL(locate(/obj/effect/anomaly) in too_close, "An anomaly was placed within 20 tiles")
	TEST_ASSERT_NOTNULL(locate(/obj/effect/anomaly) in boundary, "An anomaly exactly 20 tiles away was refused")
	TEST_ASSERT_EQUAL(generator.place_budgeted_anomalies(list(), 1), 0, "Empty ground filled an anomaly budget")
	TEST_ASSERT_EQUAL(generator.place_budgeted_anomalies(list(first), 0), 0, "A zero budget placed an anomaly")

/// Real landing-strip flags and leashes stay local to two neighbouring footprints.
/datum/unit_test/voidcrew_planet_anomalies/landing_neighbours/Run()
	var/datum/space_level/level = SSmapping.z_list[run_loc_floor_bottom_left.z]
	var/list/sites = list()
	var/list/strips = list()
	for(var/index in 1 to 2)
		var/obj/structure/overmap/planet/planet = allocate(/obj/structure/overmap/planet)
		planets += planet
		var/datum/map_footprint/footprint = allocate(/datum/map_footprint, null, "planet", index, planet)
		footprint.attach_level(level)
		footprint.set_rect(40 + (index - 1) * 10, 40, 5, 60)
		planet.footprint = footprint
		var/strip_top = planet.get_dock_strip_top_y(level)
		strips += ground(footprint.low_x, strip_top)
		sites += ground(footprint.low_x, strip_top + 1)
		for(var/turf/target as anything in footprint.get_block())
			remember_turf(target)

	var/datum/map_generator/planet_generator/anomaly_test/generator = allocate(/datum/map_generator/planet_generator/anomaly_test)
	generator.throttled = FALSE
	for(var/index in 1 to 2)
		var/obj/structure/overmap/planet/planet = planets[index]
		planet.reserve_dock_strip(level)
		var/turf/strip = strips[index]
		TEST_ASSERT(strip.turf_flags & NO_RUINS, "The landing-clearance boundary was not reserved")
		if(index == 1)
			var/turf/neighbour_strip = strips[2]
			TEST_ASSERT(!(neighbour_strip.turf_flags & NO_RUINS), "Reserving one strip changed its neighbour")
		generator.forced_sample = strip
		TEST_ASSERT_EQUAL(generator.place_budgeted_anomalies(list(strip, sites[index]), 1), 1, "The strip consumed a planet's anomaly budget")
		TEST_ASSERT_NULL(locate(/obj/effect/anomaly) in strip, "An anomaly formed in the landing clearance")

	TEST_ASSERT(get_dist(sites[1], sites[2]) < 20, "The fixture must put the two sites within natural separation distance")
	for(var/index in 1 to 2)
		var/obj/effect/anomaly/anomaly = locate(/obj/effect/anomaly) in sites[index]
		TEST_ASSERT_NOTNULL(anomaly, "A neighbour's anomaly consumed this planet's allowance")
		var/datum/component/anomaly_site_leash/leash = anomaly.GetComponent(/datum/component/anomaly_site_leash)
		TEST_ASSERT_NOTNULL(leash, "The natural anomaly has no site leash")
		TEST_ASSERT(leash.allows(sites[index]), "The anomaly cannot stand on its own site")
		TEST_ASSERT(!leash.allows(strips[index]), "The anomaly can enter its landing strip")
		TEST_ASSERT(!leash.allows(sites[3 - index]), "The anomaly can enter the neighbouring footprint")

/// A purchased arrival adds one anomaly alongside the already-filled natural allowance.
/datum/unit_test/voidcrew_planet_anomalies/chart_budget/Run()
	var/list/natural_sites = list(ground(40, 40), ground(60, 40), ground(80, 40))
	var/turf/chart_site = ground(100, 40)
	var/datum/map_generator/planet_generator/generator = allocate(/datum/map_generator/planet_generator)
	generator.throttled = FALSE
	generator.populate_terrain(natural_sites, get_area(natural_sites[1]), 3) // ZONE_RED
	TEST_ASSERT_EQUAL(length(anomalies_on(natural_sites)), 3, "The natural budget was not filled before arrival")
	var/obj/structure/overmap/ship/buyer = allocate(/obj/structure/overmap/ship)
	var/obj/structure/overmap/space_ruin/site = allocate(/obj/structure/overmap/space_ruin)
	var/datum/rumor_chart/anomaly/unit_test/chart = new
	chart.anomaly_type = /obj/effect/anomaly/grav/planetary
	chart.test_site = site
	chart.test_turf = chart_site
	buyer.add_pending_rumor(chart)
	TEST_ASSERT_EQUAL(buyer.reveal_pending_rumor(chart), site, "The purchased chart did not reveal")
	buyer.docked = site
	SEND_SIGNAL(buyer, "voidcrew_ship_docked")
	TEST_ASSERT_EQUAL(length(anomalies_on(natural_sites + list(chart_site))), 4, "The chart shared the natural budget")
	SEND_SIGNAL(buyer, "voidcrew_ship_docked")
	TEST_ASSERT_EQUAL(length(anomalies_on(natural_sites + list(chart_site))), 4, "A spent chart surfaced twice")
	buyer.docked = null
