// Xenoarchaeology tests: dig.
//
// Test files compile before voidcrew/_DEFINES, so the values below are literals. They mirror
// voidcrew/_DEFINES/xenoarch.dm:
//   bands (ZONE_*): green 1, yellow 2, red 3
//   finds per site (large, small): green 1 + 3, yellow 1 + 3, red 2 + 2; 3 sites a planet
//   XENOARCH_FIND_LARGE 1, XENOARCH_FIND_SMALL 2
//   XENOARCH_CRYSTAL_LIFETIME 90 minutes = 54000 deciseconds
//   curio values: shell 40, fossil 50, pottery 80, statuette and instrument 150, strange object 200

/// The reserve holds a fixed supply: seeding happens once, finds come out one at a time, and a
/// boulder cut loose stays counted until it is opened or lost.
/datum/unit_test/voidcrew_xenoarch_dig_reserve/Run()
	var/datum/planet_dig_reserve/red = allocate(/datum/planet_dig_reserve, 3)
	TEST_ASSERT(red.seed(/datum/planet/lava), "the first build did not seed the reserve")
	TEST_ASSERT(!red.seed(/datum/planet/lava), "a rebuild seeded the reserve again")
	TEST_ASSERT_EQUAL(length(red.sites), 3, "a planet should hold three sites")
	TEST_ASSERT_EQUAL(red.finds_left(), 12, "a red planet should hold twelve finds")
	var/datum/dig_site_record/site = red.sites[1]
	TEST_ASSERT_EQUAL(site.large_left, 2, "a red site should hold two large finds")
	TEST_ASSERT_EQUAL(site.small_left, 2, "a red site should hold two small finds")
	TEST_ASSERT_EQUAL(site.band, 3, "a red site was not stamped red")

	var/datum/planet_dig_reserve/green = allocate(/datum/planet_dig_reserve, 1)
	green.seed(/datum/planet/beach)
	var/datum/dig_site_record/green_site = green.sites[1]
	TEST_ASSERT_EQUAL(green_site.large_left, 1, "a green site should hold one large find")
	TEST_ASSERT_EQUAL(green_site.small_left, 3, "a green site should hold three small finds")

	TEST_ASSERT(site.take_find(1), "a large find could not be taken")
	TEST_ASSERT(site.take_find(1), "the second large find could not be taken")
	TEST_ASSERT(!site.take_find(1), "a third large find came out of a two-find site")
	var/datum/dig_boulder_record/boulder = site.cut_boulder()
	TEST_ASSERT_EQUAL(site.finds_left(), 3, "a boulder cut loose was not counted as still to come")
	TEST_ASSERT_EQUAL(boulder.band, 3, "a red boulder was not stamped red")
	TEST_ASSERT(boulder.target_depth >= 25 && boulder.target_depth <= 200, "boulder depth [boulder.target_depth] out of range")
	TEST_ASSERT(boulder.field in GLOB.xenoarch_stabilising_fields, "boulder rolled unknown field [boulder.field]")
	TEST_ASSERT(boulder.serial, "boulder has no catalogue number")
	site.settle_boulder(boulder)
	TEST_ASSERT_EQUAL(site.finds_left(), 2, "an opened boulder still counted")
	qdel(boulder)
	TEST_ASSERT_EQUAL(length(red.sites_with_finds()), 3, "a site with finds left was skipped")
	site.small_left = 0
	TEST_ASSERT_EQUAL(length(red.sites_with_finds()), 2, "an emptied site would be rebuilt")

/// Mining a site wall frees its find and debits the record; an unopened boulder survives its own
/// deletion (a planet teardown) and comes back as it was.
/datum/unit_test/voidcrew_xenoarch_site_wall
	/// Turfs this test turned to rock -> their original type, put back even if an assertion fails
	var/list/changed_turfs = list()

/datum/unit_test/voidcrew_xenoarch_site_wall/Destroy()
	for(var/turf/changed as anything in changed_turfs)
		changed.ChangeTurf(changed_turfs[changed])
	changed_turfs = null
	return ..()

/datum/unit_test/voidcrew_xenoarch_site_wall/Run()
	var/datum/dig_site_record/site = allocate(/datum/dig_site_record, 2, "house")
	site.large_left = 1
	site.small_left = 1
	var/turf/large_spot = run_loc_floor_bottom_left
	var/turf/small_spot = get_step(run_loc_floor_bottom_left, EAST)
	changed_turfs[large_spot] = large_spot.type
	changed_turfs[small_spot] = small_spot.type

	var/turf/closed/mineral/large_wall = large_spot.ChangeTurf(/turf/closed/mineral)
	large_wall.make_dig_site_wall(site, 1)
	TEST_ASSERT_EQUAL(large_wall.mineralType, null, "a site wall kept ore")
	TEST_ASSERT_EQUAL(large_wall.scan_state, "xenoarch_site", "a site wall has no scanner mark")
	TEST_ASSERT(!ambient_ore_wall_ok(large_wall), "NPC miners would dig a site wall")
	large_wall.gets_drilled()
	var/obj/structure/xenoarch_boulder/boulder = locate() in large_spot
	TEST_ASSERT_NOTNULL(boulder, "mining a large-find wall left no boulder")
	TEST_ASSERT_EQUAL(site.large_left, 0, "the large find was not taken from the record")
	TEST_ASSERT_EQUAL(length(site.loose), 1, "the cut boulder was not kept in the record")
	var/datum/dig_boulder_record/kept = site.loose[1]
	TEST_ASSERT_EQUAL(boulder.record, kept, "the boulder does not draw its record")
	kept.dug = 40
	var/serial = kept.serial
	qdel(boulder)
	TEST_ASSERT(!QDELETED(kept), "a torn-down boulder deleted its record")
	TEST_ASSERT_EQUAL(length(site.loose), 1, "a torn-down boulder left its site")
	var/obj/structure/xenoarch_boulder/rebuilt = new(large_spot, kept, site)
	TEST_ASSERT_EQUAL(rebuilt.record.serial, serial, "the rebuilt boulder has a new catalogue number")
	TEST_ASSERT_EQUAL(rebuilt.record.dug, 40, "the rebuilt boulder lost its cut depth")
	TEST_ASSERT_EQUAL(rebuilt.cut_stage(), 1, "40 cm cut should show the second stage")
	qdel(rebuilt)

	var/turf/closed/mineral/small_wall = small_spot.ChangeTurf(/turf/closed/mineral)
	small_wall.make_dig_site_wall(site, 2)
	small_wall.gets_drilled()
	var/obj/item/strange_rock/rock = locate() in small_spot
	TEST_ASSERT_NOTNULL(rock, "mining a small-find wall left no strange rock")
	TEST_ASSERT_EQUAL(rock?.band, 2, "the strange rock was not stamped with its site's band")
	TEST_ASSERT_EQUAL(site.small_left, 0, "the small find was not taken from the record")

	// A flagged wall whose record ran dry gives nothing.
	var/turf/closed/mineral/spent_wall = small_spot.ChangeTurf(/turf/closed/mineral)
	spent_wall.make_dig_site_wall(site, 2)
	spent_wall.gets_drilled()
	var/count = 0
	for(var/obj/item/strange_rock/extra in small_spot)
		count++
	TEST_ASSERT_EQUAL(count, 1, "an emptied site gave another rock")

/// Brushed at the right depth with the right field, the find comes out whole, stamped and with the
/// boulder's number; cut past it, nothing comes out at all.
/datum/unit_test/voidcrew_xenoarch_boulder/Run()
	var/obj/structure/xenoarch_boulder/boulder = allocate(/obj/structure/xenoarch_boulder)
	var/datum/dig_boulder_record/record = boulder.record
	// Green: no ambush can wake in a test.
	record.band = 1
	record.find_type = /obj/machinery/artifact
	record.target_depth = 30
	record.dug = 30
	record.stabilised = TRUE
	var/obj/machinery/artifact/find = boulder.free_find(null)
	TEST_ASSERT(istype(find), "a stabilised boulder at depth gave no artifact")
	TEST_ASSERT(QDELETED(boulder), "the boulder outlived its find")
	TEST_ASSERT_EQUAL(find?.origin_band, 1, "the find was not stamped with the boulder's band")
	TEST_ASSERT_EQUAL(find?.serial, record.serial, "the find did not keep the boulder's catalogue number")
	TEST_ASSERT(!find?.damaged, "a stabilised find came out damaged")
	qdel(find)

	var/obj/structure/xenoarch_boulder/overcut = allocate(/obj/structure/xenoarch_boulder)
	overcut.record.band = 1
	overcut.record.find_type = /obj/machinery/artifact
	overcut.record.target_depth = 30
	overcut.record.dug = 28
	overcut.cut(5, null)
	TEST_ASSERT(QDELETED(overcut), "a boulder cut past its find survived")
	TEST_ASSERT_NULL(locate(/obj/machinery/artifact) in run_loc_floor_bottom_left, "a boulder cut past its find still gave an artifact")

	// Without the right field it either comes apart or comes out damaged, never whole.
	for(var/i in 1 to 6)
		var/obj/structure/xenoarch_boulder/loose = allocate(/obj/structure/xenoarch_boulder)
		loose.record.band = 1
		loose.record.find_type = /obj/machinery/artifact
		loose.record.target_depth = 25
		loose.record.dug = 25
		loose.record.stabilised = FALSE
		var/obj/machinery/artifact/unheld = loose.free_find(null)
		TEST_ASSERT(QDELETED(loose), "an unstabilised boulder survived being freed")
		if(unheld)
			TEST_ASSERT(unheld.damaged, "an unstabilised find came out whole")
			qdel(unheld)

	// It shrinks by depth cut, never by depth left.
	var/obj/structure/xenoarch_boulder/shrinking = allocate(/obj/structure/xenoarch_boulder)
	shrinking.record.dug = 25
	TEST_ASSERT_EQUAL(shrinking.cut_stage(), 0, "25 cm cut should still show the first stage")
	shrinking.record.dug = 150
	TEST_ASSERT_EQUAL(shrinking.cut_stage(), 3, "150 cm cut should show the last stage")

	// A find dug in another band keeps that band wherever it is freed.
	var/obj/machinery/artifact/yellow = xenoarch_spawn_large_find(/obj/machinery/artifact, run_loc_floor_bottom_left, 2, TRUE, "Tau-1001")
	TEST_ASSERT_EQUAL(yellow?.origin_band, 2, "a yellow find was not stamped yellow")
	TEST_ASSERT_EQUAL(yellow?.serial, "Tau-1001", "a find did not take the catalogue number it was given")
	TEST_ASSERT(yellow?.damaged, "a find freed damaged came out whole")
	qdel(yellow)

/// A strange rock frees a stamped, marked curio at depth and nothing past it.
/datum/unit_test/voidcrew_xenoarch_strange_rock/Run()
	var/obj/item/strange_rock/rock = allocate(/obj/item/strange_rock, run_loc_floor_bottom_left, 2, "house")
	TEST_ASSERT_EQUAL(rock.band, 2, "a yellow rock was not stamped yellow")
	TEST_ASSERT(rock.tier >= 1 && rock.tier <= 3, "rock tier [rock.tier] out of range")
	rock.find_type = /obj/item/xenoarch_curio/bowl
	rock.target_depth = 10
	rock.dug = 10
	var/obj/item/xenoarch_curio/bowl = rock.free_find(null)
	TEST_ASSERT(istype(bowl), "a rock at depth gave no curio")
	TEST_ASSERT_EQUAL(bowl?.origin_band, 2, "the curio was not stamped with its rock's band")
	TEST_ASSERT_EQUAL(xenoarch_curio_value(bowl), 80, "a bowl was not marked at the pottery price")
	TEST_ASSERT_EQUAL(xenoarch_find_band(bowl), 2, "xenoarch_find_band() can't read a curio")
	qdel(bowl)

	var/obj/item/xenoarch_curio/spawned = allocate(/obj/item/xenoarch_curio/shell)
	TEST_ASSERT_NULL(xenoarch_find_band(spawned), "a curio that never came out of the ground reads as dug")

	var/obj/item/strange_rock/overcut = allocate(/obj/item/strange_rock, run_loc_floor_bottom_left, 1, "garden")
	overcut.find_type = /obj/item/xenoarch_curio/shell
	overcut.target_depth = 10
	overcut.dug = 11
	overcut.lose_find(null)
	TEST_ASSERT(QDELETED(overcut), "a rock cut past its find survived")
	var/count = 0
	for(var/obj/item/xenoarch_curio/shell/shell in run_loc_floor_bottom_left)
		if(shell != spawned)
			count++
	TEST_ASSERT_EQUAL(count, 0, "a rock cut past its find still gave a curio")

	// Every site kind and tier gives something real.
	for(var/kind in list("garden", "animal", "house", "technical", "temple", "war"))
		for(var/tier in 1 to 3)
			var/find_type = xenoarch_small_find(kind, tier)
			TEST_ASSERT(ispath(find_type, /atom/movable) || find_type == /datum/xenoarch_research_draw, "[kind] tier [tier] gives [find_type]")

/// Large finds other than artifacts: shares by band, stamps, and what each one comes out as.
/datum/unit_test/voidcrew_xenoarch_large_finds/Run()
	for(var/i in 1 to 400)
		var/find_type = xenoarch_roll_large_find(1)
		TEST_ASSERT(!ispath(find_type, /obj/vehicle/sealed/mecha), "a green site rolled an exosuit")
		TEST_ASSERT(ispath(find_type, /atom/movable), "a green site rolled [find_type]")

	var/turf/spot = run_loc_floor_bottom_left
	var/obj/machinery/power/charged_crystal/crystal = xenoarch_spawn_large_find(/obj/machinery/power/charged_crystal, spot, 3, TRUE)
	TEST_ASSERT(istype(crystal), "no charged crystal came out")
	TEST_ASSERT_EQUAL(crystal?.origin_band, 3, "the crystal was not stamped")
	TEST_ASSERT_EQUAL(crystal?.charge_left, 27000, "a damaged crystal should hold half its charge")
	TEST_ASSERT(!crystal?.can_run(), "an unwired, loose crystal would run")
	crystal.wired = TRUE
	crystal.set_anchored(TRUE)
	TEST_ASSERT(!crystal.can_run(), "a crystal with no cable under it would run")
	crystal.charge_left = 0
	TEST_ASSERT(crystal.is_dull(), "a spent crystal is not dull")
	qdel(crystal)

	var/obj/machinery/artifact/bluespace_formation/formation = xenoarch_spawn_large_find(/obj/machinery/artifact/bluespace_formation, spot, 2, FALSE, "Sigma-1234")
	TEST_ASSERT(istype(formation), "no formation came out")
	TEST_ASSERT_EQUAL(formation?.origin_band, 2, "the formation was not stamped")
	TEST_ASSERT_NULL(formation?.main_effect, "a formation rolled an artifact effect")
	qdel(formation)

	var/obj/structure/closet/crate/zone_loot/research/case = xenoarch_spawn_large_find(/obj/structure/closet/crate/zone_loot/research, spot, 3)
	TEST_ASSERT_EQUAL(case?.loot_zone, 3, "a sealed case was not tiered by where it was dug")
	qdel(case)

	var/obj/vehicle/sealed/mecha/gygax/wreck = xenoarch_spawn_large_find(/obj/vehicle/sealed/mecha/gygax, spot, 3)
	TEST_ASSERT(istype(wreck), "no exosuit came out")
	TEST_ASSERT(wreck.get_integrity() <= wreck.max_integrity * 0.4, "the exosuit came out undamaged")
	TEST_ASSERT(!wreck.cell || wreck.cell.charge <= wreck.cell.maxcharge * 0.2, "the exosuit came out with a full cell")
	qdel(wreck)

/// Every sprite state the dig code can ask for exists.
/datum/unit_test/voidcrew_xenoarch_dig_icons/Run()
	var/site_icon = 'voidcrew/modules/xenoarch/icons/dig_site.dmi'
	for(var/variant in 1 to 4)
		for(var/stage in 0 to 3)
			TEST_ASSERT(icon_exists(site_icon, "boulder[variant]_[stage]"), "missing boulder[variant]_[stage]")
			TEST_ASSERT(icon_exists(site_icon, "boulder[variant]_[stage]_vein"), "missing boulder[variant]_[stage]_vein")
	for(var/state in list("vein1", "vein2", "vein3", "stake_orange", "stake_red", "spoil1", "spoil2", "field", "holotag", "survey_pin"))
		TEST_ASSERT(icon_exists(site_icon, state), "missing dig site state [state]")
	var/tool_icon = 'voidcrew/modules/xenoarch/icons/dig_tools.dmi'
	for(var/head in list(1, 2, 4, 6, 10))
		TEST_ASSERT(icon_exists(tool_icon, "hammer_[head]"), "missing hammer_[head]")
	for(var/state in list("brush", "brush_quick", "depth_scanner", "depth_scanner_adv", "sampler", "sampler_full", "stabiliser", "stabiliser_lamp", "find_bag"))
		TEST_ASSERT(icon_exists(tool_icon, state), "missing tool state [state]")
	for(var/state in list("charged_crystal", "charged_crystal_active", "charged_crystal_dull", "charged_crystal_wires"))
		TEST_ASSERT(icon_exists('voidcrew/modules/xenoarch/icons/dig_finds.dmi', state), "missing crystal state [state]")
	for(var/state in list("spectrometer", "spectrometer_processing", "spectrometer_open"))
		TEST_ASSERT(icon_exists('voidcrew/modules/xenoarch/icons/dig_machines.dmi', state), "missing spectrometer state [state]")
	TEST_ASSERT(icon_exists('voidcrew/modules/xenoarch/icons/dig_scan.dmi', "xenoarch_site"), "missing scanner mark")
	for(var/stage in 0 to 2)
		TEST_ASSERT(icon_exists('voidcrew/modules/xenoarch/icons/curios.dmi', "strange_rock_[stage]"), "missing strange_rock_[stage]")
	for(var/obj/item/xenoarch_curio/curio_type as anything in subtypesof(/obj/item/xenoarch_curio))
		var/obj/item/xenoarch_curio/curio = new curio_type(run_loc_floor_bottom_left)
		for(var/state in curio.variants)
			TEST_ASSERT(icon_exists(curio.icon, state), "[curio_type] has no sprite state [state]")
		qdel(curio)
