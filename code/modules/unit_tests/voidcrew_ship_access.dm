/**
 * # Ship interiors have no internal access control
 *
 * A crewed hull opens every lock inside it for anyone aboard, because a five
 * person crew holds one department's ID between them and stock /tg/ department
 * locks just wall the medic off from a toolbox.
 *
 * Two carve-outs are the part that regresses quietly. An AI-run hull keeps its
 * locks, so a pirate frigate's doors are still shut until the crew claims the
 * ship with a ship key; claiming clears the ship's ai_controller, and that is
 * the only thing standing between a boarding party and a free run of the hull.
 * And "anyone aboard" means the crew: a clientless mob gets no waiver, because
 * an access-locked door is the only thing holding wildlife - a slime in its
 * xenobiology pen, a boarder, a carp - where it belongs.
 */
/datum/unit_test/voidcrew_ship_access

/datum/unit_test/voidcrew_ship_access/Run()
	var/obj/machinery/door/airlock/instant/door = allocate(/obj/machinery/door/airlock/instant)
	door.req_access = list(ACCESS_ENGINEERING)

	// Nothing has been made into a ship yet, so this is the plain upstream answer.
	TEST_ASSERT(!door.check_access_list(list()), "a locked airlock outside any ship opened for an ID with no access at all")

	var/turf/door_turf = get_turf(door)
	var/area/original_area = door_turf.loc
	var/area/shuttle/voidcrew/ship_area = new
	door_turf.change_area(original_area, ship_area)

	var/obj/docking_port/mobile/voidcrew/port = allocate(/obj/docking_port/mobile/voidcrew)
	var/obj/structure/overmap/ship/ship = allocate(/obj/structure/overmap/ship)

	// A ship area with no hull attached to it yet is still just an area.
	TEST_ASSERT(!door.check_access_list(list()), "a ship area with no docking port bypassed access")

	ship_area.shuttle_port = port
	TEST_ASSERT(!door.check_access_list(list()), "a docking port with no overmap ship bypassed access")

	port.current_ship = ship
	TEST_ASSERT(door.check_access_list(list()), "a locked airlock aboard a crewed hull stayed locked")
	TEST_ASSERT(door.allowed(null), "allowed() did not follow check_access_list() aboard a crewed hull")

	// The waiver is for the crew, and a crewmember has a client. Anything else that
	// bumps the door - a boarder, a carp in through a breach, a slime out of its
	// xenobiology pen - has to show real access the way it would upstream. An
	// access-locked windoor is the only thing containing a slime, so this assertion
	// is what keeps the Phalanx pens shut.
	var/mob/living/basic/critter = allocate(/mob/living/basic)
	TEST_ASSERT(!door.allowed(critter), "the crewed-hull waiver held an access-locked door open for a clientless mob")
	door.req_access = list()
	TEST_ASSERT(door.allowed(critter), "a door mapped with no access at all turned an ID-less mob away")
	door.req_access = list(ACCESS_ENGINEERING)

	// An AI-run hull is somebody else's ship. Its locks hold.
	ship.ai_controller = new /datum/ai_controller()
	TEST_ASSERT(!door.check_access_list(list()), "an AI-run hull gave up its locks without being claimed")

	// Claiming an NPC ship clears ai_controller, and that alone opens the hull.
	QDEL_NULL(ship.ai_controller)
	TEST_ASSERT(door.check_access_list(list()), "clearing ai_controller, which is all claiming a ship does, did not open the hull")

	door_turf.change_area(ship_area, original_area)
	ship_area.shuttle_port = null
	qdel(ship_area)

/**
 * # Lockers carry no access restriction anywhere
 *
 * Secure closets ignore req_access outright, on a ship or off one, so the ship
 * rule above never gets a say in whether a locker opens. The access list stays on
 * the closet so deconstructing it still yields electronics that mean something.
 */
/datum/unit_test/voidcrew_locker_access

/datum/unit_test/voidcrew_locker_access/Run()
	var/obj/structure/closet/secure_closet/engineering_electrical/locker = allocate(/obj/structure/closet/secure_closet/engineering_electrical)
	TEST_ASSERT(length(locker.req_access), "the test locker carries no req_access, so it cannot tell a bypass from stock behaviour")

	TEST_ASSERT(locker.check_access_list(list()), "a secure locker turned away an ID carrying no access")
	TEST_ASSERT(locker.allowed(null), "allowed() did not follow check_access_list() on a secure locker")

	// The locker is sitting in a plain station area, well away from any hull.
	var/area/locker_area = get_area(locker)
	TEST_ASSERT(!istype(locker_area, /area/shuttle/voidcrew), "the test locker spawned inside a ship area, so it cannot tell the locker rule from the ship rule")

	// The path a player actually takes: right click a locked locker while holding nothing.
	var/mob/living/carbon/human/consistent/crewmember = allocate(/mob/living/carbon/human/consistent)
	TEST_ASSERT(locker.locked, "the test locker did not start locked")
	locker.togglelock(crewmember, silent = TRUE)
	TEST_ASSERT(!locker.locked, "a crewmember carrying no ID could not unlock a secure locker")
