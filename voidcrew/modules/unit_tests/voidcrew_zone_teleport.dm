/// Teleports never cross an overmap zone boundary, forced or not (voidcrew zone_teleport.dm).
/datum/unit_test/voidcrew_zone_teleport
	var/list/original_areas = list()
	var/list/ship_areas = list()
	var/list/ships = list()
	var/list/overmap_turfs = list()
	var/zones_were_active

/datum/unit_test/voidcrew_zone_teleport/Destroy()
	SSovermap_zones.zones_active = zones_were_active
	for(var/obj/structure/overmap/ship/ship as anything in ships)
		var/obj/docking_port/mobile/voidcrew/port = ship.shuttle
		ship.shuttle = null
		port.current_ship = null
		qdel(port, force = TRUE)
	for(var/turf/changed_turf as anything in original_areas)
		changed_turf.change_area(get_area(changed_turf), original_areas[changed_turf])
	QDEL_LIST(ship_areas)
	for(var/turf/open/overmap/changed_turf as anything in overmap_turfs)
		changed_turf.current_zone = null
		changed_turf.ChangeTurf(overmap_turfs[changed_turf])
	return ..()

/datum/unit_test/voidcrew_zone_teleport/proc/make_ship(turf/ship_turf, turf/token_turf)
	var/area/shuttle/voidcrew/ship_area = new
	ship_areas += ship_area
	original_areas[ship_turf] = get_area(ship_turf)
	ship_turf.change_area(get_area(ship_turf), ship_area)
	var/obj/docking_port/mobile/voidcrew/port = new(ship_turf)
	port.shuttle_areas[ship_area] = TRUE
	port.register()
	ship_area.shuttle_port = port
	var/obj/structure/overmap/ship/ship = allocate(/obj/structure/overmap/ship, token_turf)
	ship.shuttle = port
	port.current_ship = ship
	ships += ship
	return ship

/datum/unit_test/voidcrew_zone_teleport/proc/make_zone_turf(turf/location, zone_type)
	var/old_type = location.type
	var/turf/open/overmap/zone_turf = location.ChangeTurf(/turf/open/overmap)
	overmap_turfs[zone_turf] = old_type
	zone_turf.current_zone = allocate(/datum/overmap_zone, zone_type)
	return zone_turf

/datum/unit_test/voidcrew_zone_teleport/Run()
	zones_were_active = SSovermap_zones.zones_active
	SSovermap_zones.zones_active = TRUE
	var/turf/red_hull = run_loc_floor_bottom_left
	var/turf/other_red_hull = get_step(red_hull, EAST)
	var/turf/green_hull = get_step(other_red_hull, EAST)
	var/turf/unzoned = get_step(green_hull, EAST)
	// Voidcrew defines are included after unit tests: GREEN = 1, RED = 3.
	var/turf/red_tile = make_zone_turf(get_step(red_hull, NORTH), 3)
	var/turf/green_tile = make_zone_turf(get_step(green_hull, NORTH), 1)
	make_ship(red_hull, red_tile)
	make_ship(other_red_hull, red_tile)
	make_ship(green_hull, green_tile)

	TEST_ASSERT(teleport_crosses_zone(red_hull, green_hull), "A red hull to a green hull should cross zones")
	TEST_ASSERT(!teleport_crosses_zone(red_hull, other_red_hull), "Two hulls in red should not cross zones")
	TEST_ASSERT(!teleport_crosses_zone(red_hull, unzoned), "Ground with no zone should never count as a crossing")

	var/mob/living/carbon/human/consistent/crew = allocate(/mob/living/carbon/human/consistent, red_hull)
	TEST_ASSERT(!check_teleport_valid(crew, green_hull, TELEPORT_CHANNEL_BLUESPACE), "check_teleport_valid() should refuse a zone crossing")
	TEST_ASSERT(!do_teleport(crew, green_hull, channel = TELEPORT_CHANNEL_BLUESPACE, no_effects = TRUE), "An unforced teleport should not cross zones")
	TEST_ASSERT(!do_teleport(crew, green_hull, channel = TELEPORT_CHANNEL_QUANTUM, no_effects = TRUE, forced = TRUE), "A forced teleport should not cross zones")
	TEST_ASSERT_EQUAL(get_turf(crew), red_hull, "The refused teleports should leave the mob where it was")
	TEST_ASSERT(do_teleport(crew, other_red_hull, channel = TELEPORT_CHANNEL_BLUESPACE, no_effects = TRUE), "A teleport inside one zone should still work")
	TEST_ASSERT_EQUAL(get_turf(crew), other_red_hull, "A teleport inside one zone should arrive")

	// Cargo does not cross either
	var/obj/item/wrench/cargo = allocate(/obj/item/wrench, red_hull)
	TEST_ASSERT(!do_teleport(cargo, green_hull, channel = TELEPORT_CHANNEL_QUANTUM, no_effects = TRUE), "Cargo should not teleport across zones")
	TEST_ASSERT_EQUAL(get_turf(cargo), red_hull, "Refused cargo should stay where it was")

	// A quantum pad linked into another zone refuses before it charges up
	var/obj/machinery/quantumpad/red_pad = allocate(/obj/machinery/quantumpad, red_hull)
	var/obj/machinery/quantumpad/green_pad = allocate(/obj/machinery/quantumpad, green_hull)
	red_pad.doteleport(null, green_pad)
	TEST_ASSERT(!red_pad.teleporting, "A quantum pad should refuse a target pad in another zone")
