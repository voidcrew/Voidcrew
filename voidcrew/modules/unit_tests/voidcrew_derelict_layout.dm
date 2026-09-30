/// Derelict outpost tests. Owner: P2. Voidcrew defines are not visible here: literals, with the define named beside them.

/datum/unit_test/voidcrew_derelict_prison_joined
	parent_type = /datum/unit_test/voidcrew_derelict

/datum/unit_test/voidcrew_derelict_prison_joined/Run()
	for(var/shell_type in list(/datum/map_template/player_outpost/rundown, /datum/map_template/player_outpost/clean))
		var/obj/structure/overmap/dynamic/player_outpost/derelict/site = built_derelict(shell_type, null)
		TEST_ASSERT(site, "The [shell_type] derelict did not build")
		var/datum/outpost_upgrade/prison/wing = site.outpost_upgrades["prison"]
		TEST_ASSERT(wing?.installed, "The prison wing was not installed for [shell_type]")
		var/datum/powernet/wing_net = wing.room_apc()?.terminal?.powernet
		TEST_ASSERT_NOTNULL(wing_net, "The joined prison wing has no powernet for [shell_type]")
		TEST_ASSERT_EQUAL(wing_net, site.outpost_area.apc?.terminal?.powernet, "The joined prison wing's APC did not join the habitat grid for [shell_type]")
		var/obj/machinery/door/airlock/external/door = site.derelict_prison_airlock?.resolve()
		TEST_ASSERT(istype(door), "The joined prison airlock did not resolve for [shell_type]")
		TEST_ASSERT_EQUAL(get_area(door), site.outpost_area, "The joined prison airlock is not in the outpost area for [shell_type]")
		var/turf/staff_turf
		for(var/direction in GLOB.cardinals)
			var/turf/neighbour = get_step(door, direction)
			if(locate(/obj/machinery/door/airlock/security/prison_staff) in neighbour)
				staff_turf = neighbour
				break
		TEST_ASSERT(staff_turf, "No cardinal neighbour of the joined airlock holds the staff door for [shell_type]")
		var/list/reached = derelict_reach(site, site.lobby_alcove_turfs[1])
		TEST_ASSERT(reached[staff_turf], "The prison staff door is not reachable from the lobby alcove for [shell_type]")

/datum/unit_test/voidcrew_derelict_dead_power
	parent_type = /datum/unit_test/voidcrew_derelict

/datum/unit_test/voidcrew_derelict_dead_power/Run()
	var/obj/structure/overmap/dynamic/player_outpost/derelict/site = built_derelict(/datum/map_template/player_outpost/rundown, null)
	TEST_ASSERT(site, "The rundown derelict did not build")

	for(var/area/place as anything in site.derelict_areas())
		TEST_ASSERT(place.apc, "A derelict area has no APC")
		TEST_ASSERT_EQUAL(place.apc.cell?.charge, 0, "A derelict APC cell was not drained")
		TEST_ASSERT(!place.powered(AREA_USAGE_EQUIP), "A derelict area kept equipment power after the drain")

	for(var/obj/machinery/power/smes/smes in site.outpost_area)
		TEST_ASSERT_EQUAL(smes.charge, 0, "A habitat SMES was not drained")

	var/obj/machinery/power/port_gen/pacman/generator = site.derelict_generator()
	TEST_ASSERT(generator, "The derelict has no generator")
	TEST_ASSERT(!generator.anchored, "The generator is still anchored")
	TEST_ASSERT_EQUAL(generator.sheets, 0, "The generator kept its sheets")
	TEST_ASSERT(!generator.active, "The generator is still active")

	TEST_ASSERT_EQUAL(length(site.derelict_fuel_spots), 2, "Not DERELICT_FUEL_STACKS fuel spots were left")
	for(var/turf/spot as anything in site.derelict_fuel_spots)
		var/obj/item/stack/sheet/mineral/plasma/stack = locate() in spot
		TEST_ASSERT(stack, "A fuel spot holds no plasma stack")
		TEST_ASSERT_EQUAL(stack.amount, 5, "A fuel stack is not DERELICT_FUEL_SHEETS sheets")
		if(get_area(spot) == site.outpost_area)
			TEST_ASSERT(get_dist(spot, generator) >= 8, "The habitat fuel stack is closer than DERELICT_FUEL_MIN_DISTANCE to the generator")

	for(var/obj/item/stack/sheet/mineral/plasma/plasma in site.outpost_area)
		TEST_ASSERT(get_turf(plasma) in site.derelict_fuel_spots, "Plasma exists on a habitat turf outside the fuel spots")

	for(var/area/place as anything in site.derelict_areas())
		for(var/obj/machinery/light/fixture in place)
			TEST_ASSERT(!fixture.has_emergency_power(1), "A light kept emergency power after the drain")

	for(var/obj/machinery/outpost_elevator/panel as anything in site.lobby_panels)
		TEST_ASSERT(!(panel.machine_stat & NOPOWER), "A lobby elevator panel lost power")

	TEST_ASSERT(site.management_console.machine_stat & NOPOWER, "The management console kept power after the drain")

	generator.set_anchored(TRUE)
	TEST_ASSERT(generator.powernet, "The generator has no powernet once anchored")
	TEST_ASSERT_EQUAL(generator.powernet, site.outpost_area.apc.terminal.powernet, "The generator's powernet does not match the outpost APC's grid")

	// Once the habitat is fuelled and running again, the joined prison wing powers up with it too.
	var/datum/outpost_upgrade/prison/wing = site.outpost_upgrades["prison"]
	TEST_ASSERT_EQUAL(wing.room_apc()?.terminal?.powernet, generator.powernet, "The prison wing's APC net does not match the habitat's once refuelled")

/datum/unit_test/voidcrew_derelict_berth_dark
	parent_type = /datum/unit_test/voidcrew_derelict

/datum/unit_test/voidcrew_derelict_berth_dark/Run()
	var/obj/structure/overmap/dynamic/player_outpost/derelict/site = built_derelict(/datum/map_template/player_outpost/clean, null)
	TEST_ASSERT(site, "The clean derelict did not build")

	var/datum/outpost_berth/berth = new(site, 1, null)
	site.berths = new /list(6) // OUTPOST_MAX_BERTHS
	site.berths[1] = berth
	berth.zone = site.berth_zone(1)
	berth.zone.claim(berth)
	var/datum/map_template/outpost_berth_strip/strip = get_outpost_berth_strip()
	TEST_ASSERT(berth.build_standard_hangar(new /datum/outpost_berth_layout(10, 10, strip.width, strip.height), strip), "The berth hangar did not build")

	var/list/hangar_areas = list()
	for(var/turf/tile as anything in berth.get_block())
		var/area/voidcrew/outpost_hangar/place = get_area(tile)
		if(istype(place))
			hangar_areas[place] = TRUE
	TEST_ASSERT(length(hangar_areas), "No hangar area was found on the built berth block")
	// Some tubes spawn broken at random (light.dm post_machine_initialize); only working ones must come back
	var/list/obj/machinery/light/working = list()
	for(var/area/voidcrew/outpost_hangar/place as anything in hangar_areas)
		for(var/obj/machinery/light/fixture in place)
			if(fixture.on)
				working += fixture
	TEST_ASSERT(length(working), "The berth has no working lights to darken")

	site.set_berth_dark(berth, TRUE)
	for(var/area/voidcrew/outpost_hangar/place as anything in hangar_areas)
		TEST_ASSERT(!place.lightswitch, "A dark berth area kept its lightswitch on")
		TEST_ASSERT_EQUAL(place.base_lighting_alpha, 0, "A dark berth area kept its floodlight")
		for(var/obj/machinery/light/fixture in place)
			TEST_ASSERT(!fixture.on, "A light stayed on in a dark berth")
		for(var/obj/machinery/status_display/display in place)
			TEST_ASSERT_EQUAL(display.current_mode, SD_BLANK, "A status display stayed lit in a dark berth")

	site.relight_berths()
	for(var/area/voidcrew/outpost_hangar/place as anything in hangar_areas)
		TEST_ASSERT(place.lightswitch, "A relit berth area kept its lightswitch off")
		TEST_ASSERT_EQUAL(place.base_lighting_alpha, 110, "A relit berth area did not restore its floodlight")
		for(var/obj/machinery/status_display/outpost_berth/sign in place)
			TEST_ASSERT_EQUAL(sign.current_mode, SD_MESSAGE, "A berth sign did not relight")
	for(var/obj/machinery/light/fixture as anything in working)
		TEST_ASSERT(fixture.on, "A light stayed off in a relit berth (status [fixture.status])")

	qdel(berth)
