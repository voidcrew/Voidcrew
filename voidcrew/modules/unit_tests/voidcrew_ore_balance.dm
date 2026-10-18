// Zone literals: the test harness is included before Voidcrew defines.
/datum/unit_test/voidcrew_ore_balance
	var/list/sites = list()
	var/list/changed_turfs = list()
	var/list/original_areas = list()
	var/list/original_blocked = list()

/datum/unit_test/voidcrew_ore_balance/Destroy()
	for(var/obj/structure/ore_vent/vent in allocated)
		SSore_generation.processed_vents -= vent
	for(var/obj/structure/overmap/event/meteor/field in allocated)
		field.mapzone = null
		field.footprint = null
	for(var/obj/structure/overmap/planet/site in sites)
		site.mapzone = null
		site.footprint = null
	for(var/turf/changed as anything in original_areas)
		changed.change_area(get_area(changed), original_areas[changed])
	for(var/turf/changed as anything in changed_turfs)
		if(istype(changed, /turf/open/overmap))
			var/turf/open/overmap/chart = changed
			chart.current_zone = null
		changed.ChangeTurf(changed_turfs[changed])
	. = ..()
	for(var/turf/chart as anything in original_blocked)
		if(original_blocked[chart])
			GLOB.overmap_blocked_turfs[chart] = original_blocked[chart]
		else
			GLOB.overmap_blocked_turfs -= chart

/datum/unit_test/voidcrew_ore_balance/proc/change(turf/location, turf_type)
	var/old_type = location.type
	var/turf/result = location.ChangeTurf(turf_type)
	if(!changed_turfs[result])
		changed_turfs[result] = old_type
	return result

/datum/unit_test/voidcrew_ore_balance/proc/planet_at(turf/surface, turf/token, zone_type)
	var/turf/open/overmap/chart = change(token, /turf/open/overmap)
	chart.current_zone = allocate(/datum/overmap_zone, zone_type)
	var/obj/structure/overmap/planet/site = allocate(/obj/structure/overmap/planet, chart)
	site.zone_band = zone_type
	var/datum/map_zone/zone = allocate(/datum/map_zone)
	zone.z_levels = list(reservation)
	var/datum/map_footprint/footprint = allocate(/datum/map_footprint)
	footprint.z_value = surface.z
	footprint.set_rect(surface.x, surface.y, 1, 1)
	site.mapzone = zone
	site.footprint = footprint
	sites += site
	return site

/datum/unit_test/voidcrew_ore_balance/Run()
	var/list/expected = list(
		list(110, 40, 16, 16, 8, 5, 2, 2, 1),
		list(80, 40, 20, 20, 16, 12, 6, 4, 2),
		list(50, 36, 24, 24, 24, 20, 12, 8, 2),
	)
	var/list/ores = list(/obj/item/stack/ore/iron, /obj/item/stack/ore/plasma, /obj/item/stack/ore/silver, /obj/item/stack/ore/titanium, /obj/item/stack/ore/gold, /obj/item/stack/ore/uranium, /obj/item/stack/ore/diamond, /obj/item/stack/ore/bluespace_crystal, /obj/item/stack/ore/bananium)
	for(var/zone_type in 1 to 3)
		var/list/weights = ordinary_ore_weights(zone_type)
		var/list/row = expected[zone_type]
		TEST_ASSERT_EQUAL(length(weights), 9, "Every profile must contain all nine ordinary ores")
		for(var/index in 1 to length(ores))
			TEST_ASSERT_EQUAL(weights[ores[index]], row[index], "Incorrect zone ore weight")
			TEST_ASSERT(weights[ores[index]] > 0, "An ordinary ore is zone-exclusive")
			TEST_ASSERT(is_ordinary_ore(ores[index]), "The ordinary ore classifier lost a profile entry")
		weights[/obj/item/stack/ore/iron] = -1
		var/list/fresh = ordinary_ore_weights(zone_type)
		TEST_ASSERT_EQUAL(fresh[/obj/item/stack/ore/iron], row[1], "A caller mutated the profile")
	TEST_ASSERT_EQUAL(ordinary_ore_zone(null), 1, "Unzoned rock must use green")
	TEST_ASSERT_EQUAL(ordinary_ore_zone(99), 1, "Unknown rock must use green")
	TEST_ASSERT(!is_ordinary_ore(null) && !is_ordinary_ore(/obj/item/boulder/gulag), "Special rock was classified as ordinary ore")
	var/list/severity_rows = list(list(60, 30, 10), list(25, 50, 25), list(10, 30, 60))
	var/list/meteor_types = list(/obj/structure/overmap/event/meteor/minor, /obj/structure/overmap/event/meteor, /obj/structure/overmap/event/meteor/majour)
	for(var/zone_type in 1 to 3)
		var/list/weights = meteor_severity_weights(zone_type)
		var/list/row = severity_rows[zone_type]
		var/list/applied = meteor_event_weights(GLOB.overmap_event_pick_list, zone_type)
		var/old_total = 0
		var/new_total = 0
		for(var/index in 1 to 3)
			var/path = meteor_types[index]
			TEST_ASSERT_EQUAL(weights[path], row[index], "Incorrect meteor severity weight")
			old_total += GLOB.overmap_event_pick_list[path]
			new_total += applied[path]
		TEST_ASSERT_EQUAL(new_total, old_total, "Severity changed the total meteor selection weight")

// Suppress special turf replacements in this fixture, while using production profiles.
/turf/closed/mineral/random/ore_balance_probe
	var/test_zone = 1
	var/allow_test_roll = FALSE

/turf/closed/mineral/random/ore_balance_probe/ore_profile_zone()
	return test_zone

/turf/closed/mineral/random/ore_balance_probe/mineral_chances()
	return list(/turf/closed/mineral/glacial = 5)

/turf/closed/mineral/random/ore_balance_probe/ore_initial_roll(percentile = rand(1, 100))
	if(!allow_test_roll)
		return FALSE
	return ..()

/datum/unit_test/voidcrew_ore_balance/walls/Run()
	var/turf/closed/mineral/random/ore_balance_probe/wall = change(run_loc_floor_bottom_left, /turf/closed/mineral/random/ore_balance_probe)
	var/list/chances = list(8, 12, 16)
	for(var/zone_type in 1 to 3)
		wall.test_zone = zone_type
		wall.allow_test_roll = TRUE
		TEST_ASSERT_EQUAL(wall.ore_roll_chance(), chances[zone_type], "Incorrect initial planet wall chance")
		TEST_ASSERT(wall.ore_initial_roll(chances[zone_type]), "The final successful percentile failed")
		TEST_ASSERT(!wall.ore_initial_roll(chances[zone_type] + 1), "The first failed percentile succeeded")
		var/list/choices = wall.ore_spawn_choices()
		var/list/counts = list()
		for(var/choice in choices)
			counts[choice]++
		var/list/expected = ordinary_ore_weights(zone_type)
		for(var/ore in expected)
			TEST_ASSERT_EQUAL(counts[ore], expected[ore], "The subtype cache leaked a different zone profile")
		TEST_ASSERT_EQUAL(counts[/turf/closed/mineral/glacial], 5, "An authored special vein lost its weight")
		for(var/iteration in 1 to 30)
			wall.Change_Ore(/obj/item/stack/ore/iron, iteration % 2)
			TEST_ASSERT(wall.mineralAmt >= 1 && wall.mineralAmt <= 3, "A direct or spread-style Change_Ore used the old amount")
	var/obj/structure/ore_vent/vent = allocate(/obj/structure/ore_vent, get_step(wall, NORTH))
	wall.test_zone = 1
	TEST_ASSERT_EQUAL(wall.ore_roll_chance(), 8, "A nearby vent changed the wall chance")
	for(var/iteration in 1 to 20)
		TEST_ASSERT(wall.ordinary_ore_amount(wall.mineralType) in list(1, 2, 3), "A nearby vent changed the wall yield")
	vent.forceMove(get_step(wall, EAST))
	TEST_ASSERT_EQUAL(wall.ore_roll_chance(), 8, "Moving a vent changed the wall chance")
	var/turf/closed/mineral/gibtonite/gib = change(get_step(wall, EAST), /turf/closed/mineral/gibtonite)
	TEST_ASSERT_EQUAL(gib.ordinary_ore_amount(null), initial(gib.mineralAmt), "Gibtonite bookkeeping was treated as ore")
	wall.mineralAmt = 7
	wall.Change_Ore(/obj/item/boulder/gulag)
	TEST_ASSERT_EQUAL(wall.mineralAmt, 7, "A gulag boulder was treated as ordinary ore")

/turf/closed/mineral/random/asteroid_field/ore_balance_probe
	var/test_zone = 1
	var/roll_calls = 0

/turf/closed/mineral/random/asteroid_field/ore_balance_probe/ore_profile_zone()
	return test_zone

/turf/closed/mineral/random/asteroid_field/ore_balance_probe/ore_initial_roll(percentile = rand(1, 100))
	roll_calls++
	return FALSE

/turf/closed/mineral/random/asteroid_field/minor/ore_balance_probe/ore_initial_roll(percentile = rand(1, 100))
	return FALSE

/turf/closed/mineral/random/asteroid_field/majour/ore_balance_probe/ore_initial_roll(percentile = rand(1, 100))
	return FALSE

/datum/map_generator/cave_generator/asteroid_field/ore_balance_probe
	weighted_closed_turf_types = list(/turf/closed/mineral/random/asteroid_field/ore_balance_probe = 1)
	blob_count_min = 1
	blob_count_max = 1
	blob_radius_min = 3
	blob_radius_max = 3
	initial_closed_chance = 100
	smoothing_iterations = 0
	mob_spawn_chance = 0
	flora_spawn_chance = 0
	feature_spawn_chance = 0

/datum/unit_test/voidcrew_ore_balance/asteroids/Run()
	var/list/generators = list(/datum/map_generator/cave_generator/asteroid_field/minor, /datum/map_generator/cave_generator/asteroid_field, /datum/map_generator/cave_generator/asteroid_field/majour)
	var/list/walls = list(/turf/closed/mineral/random/asteroid_field/minor, /turf/closed/mineral/random/asteroid_field, /turf/closed/mineral/random/asteroid_field/majour)
	for(var/index in 1 to 3)
		var/datum/map_generator/cave_generator/asteroid_field/generator = allocate(generators[index])
		TEST_ASSERT_EQUAL(generator.closed_turf_types[1], walls[index], "Severity was not configured before wall initialization")
	var/turf/closed/mineral/random/asteroid_field/minor_rock = change(run_loc_floor_bottom_left, /turf/closed/mineral/random/asteroid_field/minor/ore_balance_probe)
	TEST_ASSERT_EQUAL(minor_rock.ore_roll_chance(), 10, "Incorrect minor storm chance")
	var/turf/closed/mineral/random/asteroid_field/major_rock = change(run_loc_floor_bottom_left, /turf/closed/mineral/random/asteroid_field/majour/ore_balance_probe)
	TEST_ASSERT_EQUAL(major_rock.ore_roll_chance(), 15, "Incorrect major storm chance")
	var/turf/closed/mineral/random/asteroid_field/ore_balance_probe/wall = change(run_loc_floor_bottom_left, /turf/closed/mineral/random/asteroid_field/ore_balance_probe)
	TEST_ASSERT_EQUAL(wall.ore_roll_chance(), 12, "Incorrect moderate storm chance")
	TEST_ASSERT_EQUAL(wall.roll_calls, 1, "Asteroid initialization rolled ore more than once")
	TEST_ASSERT_NULL(wall.mineralType, "A failed initial roll was topped up")
	for(var/zone_type in 1 to 3)
		wall.test_zone = zone_type
		for(var/iteration in 1 to 30)
			wall.Change_Ore(/obj/item/stack/ore/diamond)
			TEST_ASSERT(wall.mineralAmt >= (zone_type == 3 ? 2 : 1) && wall.mineralAmt <= (zone_type == 1 ? 2 : 3), "Incorrect asteroid zone quantity")
	var/turf/closed/mineral/random/asteroid_field/ore_balance_probe/spread_wall = change(get_step(wall, EAST), /turf/closed/mineral/random/asteroid_field/ore_balance_probe)
	spread_wall.mineralAmt = 99
	wall.Change_Ore(/obj/item/stack/ore/iron)
	// Exercise classic spreading itself, with ample attempts at the unchanged 20% roll.
	for(var/iteration in 1 to 200)
		wall.Spread_Vein()
		if(spread_wall.mineralType)
			break
	TEST_ASSERT_EQUAL(spread_wall.mineralType, /obj/item/stack/ore/iron, "Classic vein spreading no longer reaches adjacent random rock")
	TEST_ASSERT(spread_wall.mineralAmt >= 1 && spread_wall.mineralAmt <= 2, "A spread-created asteroid wall retained its old quantity")
	var/datum/map_generator/cave_generator/asteroid_field/generator = allocate(/datum/map_generator/cave_generator/asteroid_field/ore_balance_probe)
	var/area/centcom/asteroid/voidcrew/field_area = new
	allocated += field_area
	var/turf/bottom_left = get_step(get_step(run_loc_floor_bottom_left, NORTH), NORTH)
	var/list/candidates = block(bottom_left, locate(bottom_left.x + 12, bottom_left.y + 12, bottom_left.z))
	for(var/turf/candidate as anything in candidates)
		changed_turfs[candidate] = candidate.type
		original_areas[candidate] = get_area(candidate)
	var/list/generated = generator.generate_terrain(candidates, field_area)
	generator.populate_terrain(generated, field_area)
	var/rock_count = 0
	for(var/turf/closed/mineral/random/asteroid_field/ore_balance_probe/rock in generated)
		rock_count++
		TEST_ASSERT_EQUAL(rock.roll_calls, 1, "Generation seeded the same asteroid wall twice")
		TEST_ASSERT_NULL(rock.mineralType, "Generation topped up an unsuccessful wall roll")
	TEST_ASSERT(rock_count > 0, "The asteroid generation fixture produced no rock")

/datum/unit_test/voidcrew_ore_balance/vents/Run()
	var/turf/green_surface = run_loc_floor_bottom_left
	var/turf/red_surface = get_step(green_surface, EAST)
	var/obj/structure/overmap/planet/green = planet_at(green_surface, get_step(green_surface, NORTH), 1)
	var/obj/structure/overmap/planet/red = planet_at(red_surface, get_step(red_surface, NORTH), 3)
	var/turf/yellow_surface = get_step(red_surface, EAST)
	var/obj/structure/overmap/planet/yellow_site = planet_at(yellow_surface, get_step(yellow_surface, NORTH), 2)
	var/turf/closed/mineral/green_rock = change(green_surface, /turf/closed/mineral)
	var/turf/closed/mineral/red_rock = change(red_surface, /turf/closed/mineral)
	TEST_ASSERT_EQUAL(green_rock.ore_profile_zone(), 1, "Green rock inherited its packed neighbour's profile")
	TEST_ASSERT_EQUAL(red_rock.ore_profile_zone(), 3, "Red rock inherited its packed neighbour's profile")
	var/obj/structure/ore_vent/first = allocate(/obj/structure/ore_vent, green_surface)
	var/obj/structure/ore_vent/second = allocate(/obj/structure/ore_vent, green_surface)
	var/obj/structure/ore_vent/other = allocate(/obj/structure/ore_vent, red_surface)
	var/obj/structure/ore_vent/yellow_vent = allocate(/obj/structure/ore_vent, yellow_surface)
	TEST_ASSERT_EQUAL(first.boulders_remaining, 20, "Incorrect green vent cap")
	TEST_ASSERT_EQUAL(other.boulders_remaining, 40, "Incorrect red vent cap")
	TEST_ASSERT_EQUAL(yellow_vent.boulders_remaining, 30, "Incorrect yellow vent cap")
	TEST_ASSERT_EQUAL(green.ore_reserve.sheets_remaining, 3000, "Incorrect green reserve")
	TEST_ASSERT_EQUAL(red.ore_reserve.sheets_remaining, 10000, "Incorrect red reserve")
	TEST_ASSERT_EQUAL(yellow_site.ore_reserve.sheets_remaining, 6000, "Incorrect yellow reserve")
	first.mineral_breakdown = list(/datum/material/iron = 1)
	second.mineral_breakdown = first.mineral_breakdown.Copy()
	green.ore_reserve.sheets_remaining = 2
	SSore_generation.processed_vents |= list(first, second)
	var/obj/item/boulder/last = first.produce_boulder(TRUE)
	TEST_ASSERT(last, "The final partial boulder was refused")
	allocated += last
	var/total = 0
	for(var/material in last.custom_materials)
		total += last.custom_materials[material]
	TEST_ASSERT_EQUAL(total / SHEET_MATERIAL_AMOUNT, 2, "The final boulder exceeded the shared reserve")
	TEST_ASSERT_EQUAL(first.boulders_remaining, 19, "A partial boulder did not debit the vent counter once")
	TEST_ASSERT_EQUAL(green.ore_reserve.sheets_remaining, 0, "Manual extraction did not debit the shared reserve")
	TEST_ASSERT_NULL(second.produce_boulder(), "Automatic production bypassed the shared reserve")
	TEST_ASSERT_EQUAL(second.boulders_remaining, 20, "Failed extraction consumed a vent counter")
	assert_spent_vent(second)
	TEST_ASSERT(!(first in SSore_generation.processed_vents) && !(second in SSore_generation.processed_vents), "Exhausted vents remained in automatic processing")
	TEST_ASSERT_EQUAL(red.ore_reserve.sheets_remaining, 10000, "Packed neighbour reserves were shared")
	first.forceMove(red_surface)
	TEST_ASSERT_EQUAL(first.bound_ore_reserve(), green.ore_reserve, "An imported vent rebound to its destination")
	var/datum/map_zone/old_zone = green.mapzone
	var/datum/map_footprint/old_footprint = green.footprint
	green.mapzone = null
	green.footprint = null
	TEST_ASSERT_EQUAL(green.get_ore_reserve().sheets_remaining, 0, "Unloading refilled the planet reserve")
	green.mapzone = old_zone
	green.footprint = old_footprint
	var/obj/structure/ore_vent/replacement = allocate(/obj/structure/ore_vent, green_surface)
	TEST_ASSERT_EQUAL(replacement.bound_ore_reserve(), green.ore_reserve, "Reload or replacement created a new reserve")
	TEST_ASSERT_NULL(replacement.produce_boulder(TRUE), "Replacement refilled the reserve")
	other.mineral_breakdown = list(/datum/material/iron = 1)
	var/list/empty_payload = list(/datum/material/iron = SHEET_MATERIAL_AMOUNT - 1)
	var/unchanged_balance = red.ore_reserve.sheets_remaining
	var/unchanged_counter = other.boulders_remaining
	TEST_ASSERT(!other.commit_ore_payload(empty_payload), "A payload without a whole sheet produced a boulder")
	TEST_ASSERT_EQUAL(red.ore_reserve.sheets_remaining, unchanged_balance, "An empty payload debited the reserve")
	TEST_ASSERT_EQUAL(other.boulders_remaining, unchanged_counter, "An empty payload debited the vent counter")
	other.boulders_remaining = 1
	SSore_generation.processed_vents |= other
	var/obj/item/boulder/final_automatic = other.produce_boulder()
	TEST_ASSERT(final_automatic, "Automatic extraction failed with both limits available")
	allocated += final_automatic
	var/balance = red.ore_reserve.sheets_remaining
	TEST_ASSERT_NULL(other.produce_boulder(TRUE), "Manual extraction bypassed the automatic vent counter")
	TEST_ASSERT_EQUAL(red.ore_reserve.sheets_remaining, balance, "Failed manual extraction debited the reserve")
	TEST_ASSERT(!(other in SSore_generation.processed_vents), "A capped vent remained in automatic processing")
	assert_spent_vent(other)

/// Both local exhaustion and an exhausted shared reserve must refuse before do_after.
/datum/unit_test/voidcrew_ore_balance/proc/assert_spent_vent(obj/structure/ore_vent/vent)
	var/mob/living/carbon/human/miner = allocate(/mob/living/carbon/human/consistent, get_turf(vent))
	ADD_TRAIT(miner, TRAIT_BOULDER_BREAKER, TRAIT_SOURCE_UNIT_TESTS)
	vent.discovered = TRUE
	var/examine_text = jointext(vent.examine(miner), "\n")
	TEST_ASSERT(findtext(examine_text, "The seam is spent."), "An exhausted vent did not describe the spent seam")
	TEST_ASSERT(!findtext(examine_text, "This vent produces"), "An exhausted vent advertised boulder production")
	var/start_tick = world.time
	var/start_stamina = miner.getStaminaLoss()
	var/start_count = vent.boulders_remaining
	var/datum/planet_ore_reserve/reserve = vent.bound_ore_reserve()
	var/start_reserve = reserve.sheets_remaining
	vent.attack_hand(miner, list())
	TEST_ASSERT_EQUAL(world.time, start_tick, "Striking an exhausted vent entered the delay")
	TEST_ASSERT_EQUAL(miner.getStaminaLoss(), start_stamina, "Striking an exhausted vent spent stamina")
	TEST_ASSERT_NULL(vent.produce_boulder(TRUE), "An exhausted vent produced a manual boulder")
	TEST_ASSERT_NULL(vent.produce_boulder(), "An exhausted vent produced an automatic boulder")
	TEST_ASSERT_EQUAL(vent.boulders_remaining, start_count, "Refused production consumed a vent counter")
	TEST_ASSERT_EQUAL(reserve.sheets_remaining, start_reserve, "Refused production debited the reserve")

/datum/unit_test/voidcrew_ore_balance/vent_retrieval
	var/list/old_processed_vents
	var/list/old_exhausted_vents
	var/list/old_available_boulders

/datum/unit_test/voidcrew_ore_balance/vent_retrieval/New()
	..()
	// Fire the real subsystem without producing or collecting any other site's stock.
	old_processed_vents = SSore_generation.processed_vents
	old_exhausted_vents = SSore_generation.exhausted_vents
	old_available_boulders = SSore_generation.available_boulders
	SSore_generation.processed_vents = list()
	SSore_generation.exhausted_vents = list()
	SSore_generation.available_boulders = list()

/datum/unit_test/voidcrew_ore_balance/vent_retrieval/Destroy()
	SSore_generation.processed_vents = old_processed_vents
	SSore_generation.exhausted_vents = old_exhausted_vents
	SSore_generation.available_boulders = old_available_boulders
	return ..()

/datum/unit_test/voidcrew_ore_balance/vent_retrieval/Run()
	var/turf/vent_turf = run_loc_floor_bottom_left
	var/turf/partner_turf = get_step(vent_turf, EAST)
	var/turf/retrieval_turf = get_step(partner_turf, EAST)
	var/obj/structure/overmap/planet/site = planet_at(vent_turf, get_step(vent_turf, NORTH), 1)
	site.footprint.set_rect(vent_turf.x, vent_turf.y, 2, 1)
	for(var/exhaust_reserve in list(FALSE, TRUE))
		// A unique vent is absent from possible_vents, but its stock must remain discoverable too.
		var/obj/structure/ore_vent/vent = allocate(/obj/structure/ore_vent/starter_resources, vent_turf)
		var/obj/item/boulder/old_rock = vent.produce_boulder()
		TEST_ASSERT(old_rock, "The retrieval fixture failed to produce its initial boulder")
		allocated += old_rock
		var/obj/structure/ore_vent/partner
		var/obj/item/boulder/partner_rock
		if(exhaust_reserve)
			partner = allocate(/obj/structure/ore_vent, partner_turf)
			partner.mineral_breakdown = list(/datum/material/iron = 1)
			partner.tapped = TRUE
			SSore_generation.processed_vents |= partner
			partner_rock = partner.produce_boulder()
			TEST_ASSERT(partner_rock, "The shared-reserve fixture failed to produce its initial boulder")
			allocated += partner_rock
			site.ore_reserve.sheets_remaining = 1
		else
			vent.boulders_remaining = 1

		SSore_generation.fire(FALSE)
		allocated |= SSore_generation.available_boulders
		var/expected_stock = exhaust_reserve ? 3 : 2
		TEST_ASSERT(!(null in SSore_generation.available_boulders), "Exhaustion added a null boulder to retrieval stock")
		TEST_ASSERT(!(vent in SSore_generation.processed_vents), "An exhausted vent kept producing")
		TEST_ASSERT(old_rock in SSore_generation.available_boulders, "Exhaustion hid a vent's existing boulder")
		TEST_ASSERT_EQUAL(length(SSore_generation.available_boulders), expected_stock, "The exhaustion tick lost or duplicated a boulder")
		if(exhaust_reserve)
			TEST_ASSERT(!(partner in SSore_generation.processed_vents), "A shared-reserve vent kept producing")
			TEST_ASSERT(partner_rock in SSore_generation.available_boulders, "Shared exhaustion hid another vent's stock")
		var/remaining_sheets = site.ore_reserve.sheets_remaining
		var/remaining_boulders = vent.boulders_remaining
		for(var/iteration in 1 to 2)
			SSore_generation.fire(FALSE)
			TEST_ASSERT(old_rock in SSore_generation.available_boulders, "A later subsystem tick hid an exhausted vent's boulder")
			TEST_ASSERT_EQUAL(length(SSore_generation.available_boulders), expected_stock, "A later tick lost stock or produced extra boulders")
		TEST_ASSERT_EQUAL(site.ore_reserve.sheets_remaining, remaining_sheets, "Discovery debited an exhausted reserve")
		TEST_ASSERT_EQUAL(vent.boulders_remaining, remaining_boulders, "Discovery debited an exhausted vent")

		var/obj/machinery/brm/retriever = allocate(/obj/machinery/brm, retrieval_turf)
		retriever.set_machine_stat(NONE)
		retriever.toggled_on = TRUE
		retriever.boulders_processing_max = 1
		retriever.process()
		var/obj/item/boulder/collected = locate() in retrieval_turf
		TEST_ASSERT(collected, "A retrieval machine could not collect an exhausted vent's boulder")
		TEST_ASSERT(!(collected in SSore_generation.available_boulders), "Collection left the boulder listed")
		SSore_generation.fire(FALSE)
		TEST_ASSERT(!(collected in SSore_generation.available_boulders), "A collected boulder was rediscovered")
		TEST_ASSERT_EQUAL(length(SSore_generation.available_boulders), expected_stock - 1, "Collection hid the remaining boulders")
		for(var/obj/item/boulder/rock in SSore_generation.available_boulders.Copy())
			qdel(rock)
		TEST_ASSERT_EQUAL(length(SSore_generation.available_boulders), 0, "Deleted boulders remained listed")
		SSore_generation.fire(FALSE)
		TEST_ASSERT_EQUAL(length(SSore_generation.available_boulders), 0, "Deleted boulders were rediscovered")
		qdel(collected)
		qdel(retriever)
		qdel(vent)
		if(partner)
			qdel(partner)
		TEST_ASSERT_EQUAL(length(SSore_generation.exhausted_vents), 0, "Deleted vents remained in boulder discovery")

/datum/unit_test/voidcrew_ore_balance/vent_weights/Run()
	var/list/old_pool = SSore_generation.ore_vent_minerals
	var/obj/structure/ore_vent/vent = allocate(/obj/structure/ore_vent)
	// One positive option makes weighted selection deterministic; uniform pick can select zero.
	SSore_generation.ore_vent_minerals = list(/datum/material/iron = 2, /datum/material/gold = 0)
	var/first = vent.select_vent_mineral(TRUE)
	var/remaining = SSore_generation.ore_vent_minerals[/datum/material/iron]
	var/second = vent.select_vent_mineral(TRUE)
	var/empty = length(SSore_generation.ore_vent_minerals)
	// Exercise the branch where this vent already owns every remaining allocation.
	SSore_generation.ore_vent_minerals = list(/datum/material/iron = 1)
	vent.mineral_breakdown = list(/datum/material/iron = 1)
	var/fallback = vent.select_vent_mineral(TRUE)
	var/after_fallback = length(SSore_generation.ore_vent_minerals)
	var/list/old_fallback = GLOB.ore_vent_minerals_lavaland
	GLOB.ore_vent_minerals_lavaland = list(/datum/material/iron = 1000, /datum/material/gold = 1)
	SSore_generation.ore_vent_minerals = list(/datum/material/iron = 1000000, /datum/material/gold = 1000)
	vent.mineral_breakdown = list()
	var/mapload_iron = 0
	var/dynamic_iron = 0
	for(var/iteration in 1 to 256)
		if(vent.select_vent_mineral(TRUE) == /datum/material/iron)
			mapload_iron++
		if(vent.select_vent_mineral(FALSE) == /datum/material/iron)
			dynamic_iron++
	GLOB.ore_vent_minerals_lavaland = old_fallback
	SSore_generation.ore_vent_minerals = old_pool
	TEST_ASSERT_EQUAL(first, /datum/material/iron, "Mapload selection ignored the available weighted pool")
	TEST_ASSERT_EQUAL(second, /datum/material/iron, "An allocation count was removed before exhaustion")
	TEST_ASSERT_EQUAL(remaining, 1, "Allocation did not decrement by one")
	TEST_ASSERT_EQUAL(empty, 0, "Exhausted allocations were retained")
	TEST_ASSERT(fallback && fallback != /datum/material/iron, "Empty available pool selected a null or duplicate material")
	TEST_ASSERT_EQUAL(after_fallback, 0, "Fallback did not spend its surrogate allocation")
	TEST_ASSERT(mapload_iron >= 240, "Mapload allocation used uniform rather than weighted selection")
	TEST_ASSERT(dynamic_iron >= 240, "Dynamic allocation used uniform rather than weighted selection")

// Borrow the test room without sweeping it; exercise the real unload state machine.
/obj/structure/overmap/event/meteor/ore_balance_probe
	var/docks_removed_while_retiring = FALSE
	var/footprint_released_while_claimed = FALSE

/obj/structure/overmap/event/meteor/ore_balance_probe/remove_docks()
	docks_removed_while_retiring = retiring && !loaded
	return ..()

/obj/structure/overmap/event/meteor/ore_balance_probe/remove_mapzone()
	footprint_released_while_claimed = retiring && SSovermap.worldgen_owner == src && !reserve_dock
	mapzone = null
	footprint = null

/datum/unit_test/voidcrew_ore_balance/teardown/Run()
	var/turf/inside = run_loc_floor_bottom_left
	var/obj/structure/overmap/event/meteor/ore_balance_probe/field = allocate(/obj/structure/overmap/event/meteor/ore_balance_probe)
	var/datum/map_zone/zone = allocate(/datum/map_zone)
	zone.z_levels = list(reservation)
	var/datum/map_footprint/footprint = allocate(/datum/map_footprint)
	footprint.z_value = inside.z
	footprint.set_rect(inside.x, inside.y, 1, 1)
	field.mapzone = zone
	field.footprint = footprint
	field.loaded = TRUE
	field.reserve_dock = allocate(/obj/docking_port/stationary, inside)
	field.first_dock_taken = TRUE
	field.unload_level()
	TEST_ASSERT(!field.retiring && field.loaded, "An occupied berth was torn down")
	field.first_dock_taken = FALSE
	var/mob/living/basic/player = allocate(/mob/living/basic, inside)
	// The teardown guard reads the connected-mob index, not GLOB.player_list.
	var/list/players_on_level = SSmobs.clients_by_zlevel[inside.z]
	players_on_level |= player
	var/player_blocked = !field.can_release_interior()
	player.forceMove(get_step(inside, EAST))
	var/neighbour_blocked = !field.can_release_interior()
	players_on_level -= player
	TEST_ASSERT(player_blocked, "A connected occupant did not prevent teardown")
	TEST_ASSERT(!neighbour_blocked, "A player outside the footprint prevented teardown")
	field.load_level() // The loaded field must be reused, never regenerated.
	TEST_ASSERT_EQUAL(field.footprint, footprint, "Redocking replaced an existing field")
	var/fields_before = length(GLOB.meteor_fields)
	original_blocked[inside] = GLOB.overmap_blocked_turfs[inside]
	GLOB.overmap_blocked_turfs[inside] = TRUE
	field.unload_level()
	TEST_ASSERT(field.docks_removed_while_retiring, "Docks were removed before marking the field terminal")
	TEST_ASSERT(field.footprint_released_while_claimed, "Footprint release lost the worldgen claim")
	TEST_ASSERT(QDELETED(field), "Successful unloading left the event alive")
	TEST_ASSERT_EQUAL(length(GLOB.meteor_fields), fields_before - 1, "Teardown generated a replacement field")
	TEST_ASSERT(!GLOB.overmap_blocked_turfs[inside], "A retired field left a phantom route obstruction")
	TEST_ASSERT(SSovermap.worldgen_owner != field, "Successful teardown leaked its worldgen lock")
	var/obj/structure/overmap/event/meteor/retired = allocate(/obj/structure/overmap/event/meteor)
	retired.retiring = TRUE
	retired.load_level()
	TEST_ASSERT_NULL(retired.mapzone, "Loading regenerated a retiring field")
