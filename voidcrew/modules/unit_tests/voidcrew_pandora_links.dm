/datum/unit_test/voidcrew_pandora_links/Run()
	var/datum/map_template/ruin/wasteland/pandora/template = allocate(/datum/map_template/ruin/wasteland/pandora)
	var/list/portals = list()
	var/list/destinations = list()
	var/list/guardians = list()
	var/list/doors = list()
	for(var/instance in 1 to 2)
		var/turf/entry = locate(run_loc_floor_bottom_left.x + (instance - 1) * 3, run_loc_floor_bottom_left.y, run_loc_floor_bottom_left.z)
		var/turf/exit = get_step(entry, NORTH)
		var/obj/effect/portal/permanent/one_way/portal = allocate(/obj/effect/portal/permanent/one_way, entry)
		portal.id = "pandora_entrance"
		var/obj/effect/landmark/portal_exit/destination = allocate(/obj/effect/landmark/portal_exit, exit)
		destination.id = "pandora_entrance"
		var/mob/living/simple_animal/hostile/asteroid/elite/pandora/guardian = allocate(/mob/living/simple_animal/hostile/asteroid/elite/pandora, exit)
		var/obj/machinery/door/poddoor/shutters/indestructible/door = allocate(/obj/machinery/door/poddoor/shutters/indestructible, exit)
		door.id = "pandora_dead"
		template.link_arena(list(entry, exit))
		portals += portal
		destinations += exit
		guardians += guardian
		doors += door
	for(var/instance in 1 to 2)
		var/obj/effect/portal/permanent/one_way/portal = portals[instance]
		portal.set_linked()
		TEST_ASSERT_EQUAL(portal.hard_target, destinations[instance], "Arena entrance linked to a different instance on the same z-level")
	var/mob/living/first_guardian = guardians[1]
	first_guardian.death()
	sleep(2 SECONDS)
	var/obj/machinery/door/poddoor/first_door = doors[1]
	var/obj/machinery/door/poddoor/second_door = doors[2]
	TEST_ASSERT(!first_door.density, "Defeating Pandora did not open its exits")
	TEST_ASSERT(second_door.density, "Defeating one Pandora opened another arena")
