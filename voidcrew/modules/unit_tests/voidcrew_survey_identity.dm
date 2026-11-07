/// Old discoveries must remain distinct when BYOND reuses a deleted atom's ref.
/datum/unit_test/voidcrew_survey_identity/Run()
	var/datum/survey_research/original = allocate(/datum/survey_research)
	var/datum/survey_research/copied = allocate(/datum/survey_research)
	var/obj/structure/overmap/star/survey_reference_reuse/first = allocate(/obj/structure/overmap/star/survey_reference_reuse)
	first.name = "Original discovery"
	original.update_survey_data(first)
	copied.merge_completed_surveys(original)
	var/first_ref = ref(first)
	first.force_reference_reuse = TRUE
	qdel(first)
	var/obj/structure/overmap/star/survey_reference_reuse/replacement
	for(var/attempt in 1 to 128)
		var/obj/structure/overmap/star/survey_reference_reuse/candidate = allocate(/obj/structure/overmap/star/survey_reference_reuse)
		if(ref(candidate) == first_ref)
			replacement = candidate
			break
	TEST_ASSERT_NOTNULL(replacement, "The fixture could not obtain the deleted atom's recycled reference")
	replacement.name = "New discovery"
	original.update_survey_data(replacement)
	TEST_ASSERT_EQUAL(length(original.survey_objects_by_type["stars"]), 2, "A recycled reference replaced an unrelated completed discovery")
	TEST_ASSERT_EQUAL(length(copied.survey_objects_by_type["stars"]), 1, "An independent archive changed before synchronization")
	copied.merge_completed_surveys(original)
	TEST_ASSERT_EQUAL(length(copied.survey_objects_by_type["stars"]), 2, "Synchronization merged two different discoveries with a recycled reference")
	original.merge_completed_surveys(copied)
	copied.merge_completed_surveys(original)
	TEST_ASSERT_EQUAL(length(copied.survey_objects_by_type["stars"]), 2, "Repeating synchronization duplicated completed discoveries")
	var/datum/surveyed_celestial_object/old_record = copied.survey_objects_by_type["stars"][1]
	TEST_ASSERT_EQUAL(old_record.object_name, "Original discovery", "Losing the original object erased its surviving record")

/// Explicitly armed only by this test; generic construction retains normal cleanup.
/obj/structure/overmap/star/survey_reference_reuse
	var/force_reference_reuse = FALSE

/obj/structure/overmap/star/survey_reference_reuse/Destroy()
	. = ..()
	if(force_reference_reuse)
		return QDEL_HINT_HARDDEL_NOW

/// Small physical interiors exercise the real site resolver without generating whole maps.
/datum/unit_test/voidcrew_survey_scanner
	abstract_type = /datum/unit_test/voidcrew_survey_scanner
	var/list/test_sites = list()
	var/list/test_ports = list()

/datum/unit_test/voidcrew_survey_scanner/Destroy()
	for(var/obj/structure/overmap/site as anything in test_sites)
		if(QDELETED(site))
			continue
		// These synthetic rectangles own no terrain to tear down.
		site.vars["footprint"] = null
		site.vars["mapzone"] = null
	test_sites = null
	for(var/obj/docking_port/mobile/voidcrew/port as anything in test_ports)
		port.current_ship = null
		port.shuttle_areas = list()
		qdel(port, force = TRUE)
	test_ports = null
	return ..()

/datum/unit_test/voidcrew_survey_scanner/proc/make_footprint(obj/structure/overmap/site, turf/tile)
	var/datum/map_footprint/footprint = allocate(/datum/map_footprint)
	footprint.z_value = tile.z
	footprint.set_rect(tile.x, tile.y, 1, 1)
	footprint.set_owner(site)
	return footprint

/datum/unit_test/voidcrew_survey_scanner/proc/make_site(site_type, turf/tile)
	var/obj/structure/overmap/site = allocate(site_type)
	site.vars["footprint"] = make_footprint(site, tile)
	site.vars["mapzone"] = allocate(/datum/map_zone)
	test_sites += site
	return site

/datum/unit_test/voidcrew_survey_scanner/proc/make_scanner(turf/tile)
	var/obj/machinery/survey_scanner/scanner = allocate(/obj/machinery/survey_scanner, tile)
	scanner.set_anchored(TRUE)
	scanner.cell = allocate(/obj/item/stock_parts/power_store/cell/bluespace, scanner)
	return scanner

/datum/unit_test/voidcrew_survey_scanner/proc/make_ship_turf(turf/tile)
	var/obj/docking_port/mobile/voidcrew/port = new(tile)
	port.width = 1
	port.height = 1
	port.dwidth = 0
	port.dheight = 0
	port.shuttle_areas = list()
	port.shuttle_areas[get_area(tile)] = TRUE
	port.current_ship = allocate(/obj/structure/overmap/ship)
	port.register()
	test_ports += port
	return port

/// Drive a paid scan without waiting for the cadence; process() itself is unchanged.
/datum/unit_test/voidcrew_survey_scanner/proc/scan_now(obj/machinery/survey_scanner/scanner)
	scanner.next_scan = world.time
	scanner.process(2)

/datum/unit_test/voidcrew_survey_scanner/servo_outputs/Run()
	var/turf/tile = run_loc_floor_bottom_left
	var/obj/structure/overmap/site = make_site(/obj/structure/overmap/planet/lava, tile)
	var/obj/machinery/survey_scanner/scanner = make_scanner(tile)
	var/list/servo_objects = list(/obj/item/stock_parts/servo, /obj/item/stock_parts/servo/nano, /obj/item/stock_parts/servo/pico, /obj/item/stock_parts/servo/femto)
	var/list/servo_datums = list(/datum/stock_part/servo, /datum/stock_part/servo/tier2, /datum/stock_part/servo/tier3, /datum/stock_part/servo/tier4)
	var/list/expected_outputs = list(9, 12, 15, 18)
	for(var/datum/part as anything in scanner.component_parts.Copy())
		if(istype(part, /obj/item/stock_parts/servo) || istype(part, /datum/stock_part/servo))
			scanner.component_parts -= part
			if(isitem(part))
				qdel(part)
	for(var/use_datums in list(FALSE, TRUE))
		for(var/tier in 1 to 4)
			var/datum/servo
			if(use_datums)
				servo = GLOB.stock_part_datums[servo_datums[tier]]
			else
				servo = allocate(servo_objects[tier], scanner)
			scanner.component_parts += servo
			scanner.RefreshParts()
			TEST_ASSERT_EQUAL(scanner.research_gain, expected_outputs[tier], "Incorrect servo output at tier [tier] (datum: [use_datums])")
			var/points_before = scanner.stored_points
			var/scans_before = site.survey_scans_completed
			scan_now(scanner)
			var/expected_gain = expected_outputs[tier] * (1 - scans_before * 0.04)
			TEST_ASSERT(abs(scanner.stored_points - points_before - expected_gain) < 0.001, "A paid scan did not use the tier [tier] output and existing depletion")
			scanner.component_parts -= servo
			if(isitem(servo))
				qdel(servo)
	// A tick before the next scan still consumes power, but cannot pay or deplete the site.
	var/points_before = scanner.stored_points
	var/scans_before = site.survey_scans_completed
	var/charge_before = scanner.cell.charge
	scanner.process(2)
	TEST_ASSERT_EQUAL(scanner.next_scan, world.time + 10 SECONDS, "The scan cadence changed")
	TEST_ASSERT_EQUAL(scanner.stored_points, points_before, "A scan paid before its ten-second interval")
	TEST_ASSERT_EQUAL(site.survey_scans_completed, scans_before, "An idle tick depleted the site")
	TEST_ASSERT_EQUAL(scanner.cell.charge, charge_before - scanner.active_power_usage * 2, "Idle scanning stopped billing its cell")

/datum/unit_test/voidcrew_survey_scanner/parts_and_power/Run()
	var/turf/tile = run_loc_floor_bottom_left
	var/obj/structure/overmap/site = make_site(/obj/structure/overmap/planet/lava, tile)
	var/obj/machinery/survey_scanner/scanner = make_scanner(tile)
	for(var/datum/part as anything in scanner.component_parts.Copy())
		if(istype(part, /obj/item/stock_parts/matter_bin) || istype(part, /datum/stock_part/matter_bin) || istype(part, /obj/item/stock_parts/micro_laser) || istype(part, /datum/stock_part/micro_laser))
			scanner.component_parts -= part
			if(isitem(part))
				qdel(part)
	scanner.component_parts += GLOB.stock_part_datums[/datum/stock_part/matter_bin/tier4]
	scanner.component_parts += GLOB.stock_part_datums[/datum/stock_part/micro_laser/tier4]
	scanner.RefreshParts()
	TEST_ASSERT_EQUAL(scanner.research_power, 4, "An upgraded matter bin lost its decay effect")
	TEST_ASSERT_EQUAL(scanner.active_power_usage, initial(scanner.active_power_usage) / 5, "An upgraded laser changed its power effect")
	scanner.enable()
	scan_now(scanner)
	TEST_ASSERT_EQUAL(scanner.stored_points, 9, "A matter bin multiplied the first scan's payout")
	scan_now(scanner)
	TEST_ASSERT(abs(scanner.stored_points - 17.91) < 0.001, "A matter bin did not divide depletion")
	var/points_before = scanner.stored_points
	scanner.cell.charge = 0
	scan_now(scanner)
	TEST_ASSERT(!scanner.enabled, "An empty cell did not stop scanning")
	TEST_ASSERT_EQUAL(scanner.stored_points, points_before, "An unpaid scan generated research")
	TEST_ASSERT_EQUAL(site.survey_scans_completed, 2, "An unpaid scan depleted the site")

/datum/unit_test/voidcrew_survey_scanner/shared_depletion/Run()
	var/turf/tile = run_loc_floor_bottom_left
	var/turf/neighbor = get_step(tile, EAST)
	var/obj/structure/overmap/site = make_site(/obj/structure/overmap/planet/lava, tile)
	var/obj/structure/overmap/other_site = make_site(/obj/structure/overmap/planet/ice, neighbor)
	var/obj/machinery/survey_scanner/first = make_scanner(tile)
	var/obj/machinery/survey_scanner/second = make_scanner(tile)
	first.enable()
	second.enable()
	TEST_ASSERT(first.enabled && second.enabled, "Scanners could not start on natural ground")
	TEST_ASSERT_EQUAL(site.survey_scans_completed, 0, "Enabling a scanner depleted the site")
	scan_now(first)
	scan_now(second)
	TEST_ASSERT_EQUAL(first.stored_points, 9, "The first scan did not start at full value")
	TEST_ASSERT(abs(second.stored_points - 8.64) < 0.001, "A second scanner did not share the first scanner's depletion")
	TEST_ASSERT_EQUAL(site.survey_scans_completed, 2, "Successful scanners did not increment one shared counter")
	second.forceMove(neighbor)
	var/points_before = second.stored_points
	scan_now(second)
	TEST_ASSERT(abs(second.stored_points - points_before - 9) < 0.001, "A neighboring site on the same level inherited depletion")
	TEST_ASSERT_EQUAL(other_site.survey_scans_completed, 1, "The neighboring site did not retain its own counter")
	first.disable()
	qdel(first)
	var/obj/machinery/survey_scanner/replacement = make_scanner(tile)
	replacement.enable()
	scan_now(replacement)
	TEST_ASSERT(abs(replacement.stored_points - 8.28) < 0.001, "Replacing the machine refreshed its site")
	// Replace the temporary interior while retaining the persistent overmap contact.
	var/obj/structure/overmap/planet/planet = site
	QDEL_NULL(planet.footprint)
	QDEL_NULL(planet.mapzone)
	planet.mapzone = allocate(/datum/map_zone)
	planet.footprint = make_footprint(planet, tile)
	points_before = replacement.stored_points
	scan_now(replacement)
	TEST_ASSERT(abs(replacement.stored_points - points_before - 7.92) < 0.001, "Reloading the interior refreshed depletion")
	TEST_ASSERT_EQUAL(site.survey_scans_completed, 4, "Replacing the interior lost completed scans")
	// Exhaust the site with the replacement machine, then try another fresh machine.
	for(var/attempt in 1 to 30)
		if(!replacement.enabled)
			break
		scan_now(replacement)
	TEST_ASSERT(!replacement.enabled, "A depleted site never stopped producing")
	TEST_ASSERT_EQUAL(site.survey_scans_completed, 21, "The existing 0.20 cutoff changed")
	var/obj/machinery/survey_scanner/fresh = make_scanner(tile)
	fresh.enable()
	scan_now(fresh)
	TEST_ASSERT(!fresh.enabled && !fresh.stored_points, "A fresh scanner produced from an exhausted site")
	TEST_ASSERT_EQUAL(site.survey_scans_completed, 21, "A failed scan incremented the site counter")
	// Reuse the old rectangle for a different contact: it starts with its own history.
	planet.footprint = null
	planet.mapzone = null
	var/obj/structure/overmap/new_site = make_site(/obj/structure/overmap/planet/lava, tile)
	fresh.enable()
	scan_now(fresh)
	TEST_ASSERT_EQUAL(fresh.stored_points, 9, "Recycled ground inherited another contact's exhaustion")
	TEST_ASSERT_EQUAL(new_site.survey_scans_completed, 1, "Recycled ground did not update its new contact")

/datum/unit_test/voidcrew_survey_scanner/site_validation/Run()
	var/turf/tile = run_loc_floor_bottom_left
	var/obj/machinery/survey_scanner/scanner = make_scanner(tile)
	scanner.enable()
	TEST_ASSERT(!scanner.enabled, "Unowned ground accepted a scanner")
	TEST_ASSERT_NULL(scanner.get_scan_site(), "Unowned ground resolved through a z-level fallback")
	scan_now(scanner)
	TEST_ASSERT(!scanner.stored_points, "Unowned ground produced research")
	// The shared resolver can identify legacy tenants by z; scanners must not accept that.
	var/obj/structure/overmap/planet/legacy = make_site(/obj/structure/overmap/planet/lava, tile)
	QDEL_NULL(legacy.footprint)
	legacy.mapzone.z_levels += reservation
	TEST_ASSERT_EQUAL(SSovermap_zones.get_overmap_object_for_turf(tile), legacy, "The legacy z-level fallback fixture did not resolve")
	TEST_ASSERT_NULL(scanner.get_scan_site(), "A planet without a physical footprint accepted unowned ground")
	scanner.enable()
	TEST_ASSERT(!scanner.enabled, "A z-level fallback enabled scanning")
	scan_now(scanner)
	TEST_ASSERT(!scanner.stored_points && !legacy.survey_scans_completed, "A z-level fallback produced a paid scan")
	legacy.mapzone.z_levels.Cut()
	var/list/accepted = list(/obj/structure/overmap/planet/lava, /obj/structure/overmap/space_ruin, /obj/structure/overmap/event/meteor)
	var/list/rejected = list(/obj/structure/overmap/dynamic/player_outpost, /obj/structure/overmap/planet/empty, /obj/structure/overmap/planet/empty/crashed_ship, /obj/structure/overmap/planet/energy_signal)
	for(var/site_type in accepted + rejected)
		var/obj/structure/overmap/site = make_site(site_type, tile)
		var/should_scan = (site_type in accepted)
		TEST_ASSERT_EQUAL(scanner.get_scan_site(), should_scan ? site : null, "Incorrect survey eligibility for [site_type]")
		scanner.enable()
		TEST_ASSERT_EQUAL(scanner.enabled, should_scan, "Incorrect startup eligibility for [site_type]")
		if(should_scan)
			scanner.disable()
		// A scanner already running must also reject a move onto ineligible ground.
		scanner.enabled = TRUE
		var/points_before = scanner.stored_points
		scan_now(scanner)
		TEST_ASSERT_EQUAL(site.survey_scans_completed, should_scan ? 1 : 0, "Incorrect paid-scan eligibility for [site_type]")
		if(!should_scan)
			TEST_ASSERT(!scanner.enabled, "A running scanner did not stop at [site_type]")
			TEST_ASSERT_EQUAL(scanner.stored_points, points_before, "An ineligible site produced research")
		scanner.disable()
		site.vars["footprint"] = null
		site.vars["mapzone"] = null
	// The site's rectangle includes a docked hull; hull ownership must win.
	var/obj/structure/overmap/site = make_site(/obj/structure/overmap/planet/lava, tile)
	var/datum/map_footprint/footprint = site.get_interior_footprint()
	footprint.set_rect(tile.x, tile.y, 2, 1)
	scanner.enable()
	TEST_ASSERT(scanner.enabled, "The natural site did not start before boarding")
	var/turf/ship_tile = get_step(tile, EAST)
	make_ship_turf(ship_tile)
	scanner.forceMove(ship_tile)
	TEST_ASSERT_NULL(scanner.get_scan_site(), "A docked hull was accepted as planetary ground")
	var/points_before = scanner.stored_points
	var/charge_before = scanner.cell.charge
	scan_now(scanner)
	TEST_ASSERT(!scanner.enabled, "A scanner moved aboard a docked ship kept running")
	TEST_ASSERT_EQUAL(scanner.stored_points, points_before, "A scanner paid aboard a docked ship")
	TEST_ASSERT_EQUAL(scanner.cell.charge, charge_before, "An invalid site consumed scan power")
	TEST_ASSERT_EQUAL(site.survey_scans_completed, 0, "A shipboard scan depleted the ground below it")
	scanner.enable()
	TEST_ASSERT(!scanner.enabled, "A shipboard scanner could be enabled")

/datum/unit_test/voidcrew_survey_scanner/checkpoint_defaults/Run()
	var/turf/tile = run_loc_floor_bottom_left
	var/obj/machinery/survey_scanner/source = make_scanner(tile)
	source.enabled = TRUE
	source.stored_points = 100
	var/datum/ship_checkpoint/snapshot = allocate(/datum/ship_checkpoint)
	var/saved_text = snapshot.atom_text(source)
	TEST_ASSERT(!findtext(saved_text, "enabled") && !findtext(saved_text, "stored_points") && !findtext(saved_text, "cell"), "Checkpoint serialized live scanner stock or running state")
	var/obj/machinery/survey_scanner/rebuilt = allocate(source.checkpoint_type(), tile)
	TEST_ASSERT(!rebuilt.enabled, "A checkpoint-built scanner started enabled")
	TEST_ASSERT_NULL(rebuilt.cell, "A checkpoint-built scanner supplied a charged cell")
	TEST_ASSERT(!rebuilt.stored_points, "A checkpoint-built scanner supplied research")
	make_site(/obj/structure/overmap/planet/lava, tile)
	make_ship_turf(tile)
	rebuilt.cell = allocate(/obj/item/stock_parts/power_store/cell/bluespace, rebuilt)
	rebuilt.enable()
	TEST_ASSERT(!rebuilt.enabled, "A refueled checkpoint-built scanner started aboard its hull")
	scan_now(rebuilt)
	TEST_ASSERT(!rebuilt.stored_points, "A checkpoint-built scanner generated research aboard its hull")
