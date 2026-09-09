/// Abandonment follows the crew's characters, including ghosts, across account reuse.
/datum/unit_test/voidcrew_ship_abandonment_recipients

/datum/unit_test/voidcrew_ship_abandonment_recipients/Run()
	var/obj/structure/overmap/ship/ship = allocate(/obj/structure/overmap/ship)
	var/datum/client_interface/player = allocate(/datum/client_interface)
	var/mob/living/carbon/human/consistent/crewmember = allocate(/mob/living/carbon/human/consistent)
	crewmember.mind_initialize()
	crewmember.mind.key = player.key
	var/list/former_members = list(crewmember.mind)

	player.persistent_client.set_mob(crewmember)
	var/list/recipients = ship.get_abandonment_recipients(former_members)
	TEST_ASSERT_EQUAL(length(recipients), 1, "a character still on the former roster should receive the notice")
	TEST_ASSERT(crewmember in recipients, "the notice did not reach the crewmember's current body")

	// Observers reference the body's mind without becoming mind.current.
	var/mob/dead/observer/ghost = allocate(/mob/dead/observer, crewmember)
	player.persistent_client.set_mob(ghost)
	recipients = ship.get_abandonment_recipients(former_members)
	TEST_ASSERT_EQUAL(length(recipients), 1, "a ghosting crewmember should receive the notice")
	TEST_ASSERT(ghost in recipients, "the notice reached the corpse instead of its ghost")

	// A second life on another crew uses the same account but a different mind.
	var/mob/living/carbon/human/consistent/respawned = allocate(/mob/living/carbon/human/consistent)
	respawned.mind_initialize()
	respawned.mind.key = player.key
	player.persistent_client.set_mob(respawned)
	recipients = ship.get_abandonment_recipients(former_members)
	TEST_ASSERT_EQUAL(length(recipients), 0, "the old ship notified a new character on the same account")

	// Multiple old lives on the roster must not cause duplicate notices.
	var/datum/mind/older_life = allocate(/datum/mind, player.key)
	former_members += older_life
	recipients = ship.get_abandonment_recipients(former_members)
	TEST_ASSERT_EQUAL(length(recipients), 0, "multiple old lives notified an unrelated character")
	former_members += respawned.mind
	recipients = ship.get_abandonment_recipients(former_members)
	TEST_ASSERT_EQUAL(length(recipients), 1, "a player who rejoins the same crew should receive exactly one notice")
	TEST_ASSERT(respawned in recipients, "a returning crew member did not receive the notice")

	ghost.mind = respawned.mind
	player.persistent_client.set_mob(ghost)
	recipients = ship.get_abandonment_recipients(list(crewmember.mind, older_life))
	TEST_ASSERT_EQUAL(length(recipients), 0, "the old ship notified the ghost of a different character")
	ghost.mind = null
	player.persistent_client.set_mob(null)
	recipients = ship.get_abandonment_recipients(list(null, allocate(/datum/mind)))
	TEST_ASSERT_EQUAL(length(recipients), 0, "missing or unkeyed minds should not receive notices")

/// Visiting a facility through its hangar elevator must preserve the crew's ship.
/datum/unit_test/voidcrew_ship_abandonment_sites
	var/list/test_reservations = list()
	var/obj/structure/overmap/ship/ship
	var/obj/docking_port/mobile/voidcrew/port

/datum/unit_test/voidcrew_ship_abandonment_sites/Destroy()
	// These are bounds-only fixtures, not allocations of the live map.
	for(var/datum/turf_reservation/reservation as anything in test_reservations)
		reservation.bottom_left_turfs.Cut()
		reservation.top_right_turfs.Cut()
	if(ship)
		ship.shuttle = null
		ship.docked = null
	if(port)
		port.current_ship = null
		port.shuttle_areas = list()
		qdel(port, force = TRUE)
	return ..()

/datum/unit_test/voidcrew_ship_abandonment_sites/proc/reserve_test_bounds(turf/origin)
	var/datum/turf_reservation/reservation = allocate(/datum/turf_reservation)
	reservation.bottom_left_turfs = list(origin)
	reservation.top_right_turfs = list(locate(origin.x + 2, origin.y + 2, origin.z))
	test_reservations += reservation
	return reservation

/datum/unit_test/voidcrew_ship_abandonment_sites/Run()
	var/turf/concourse = run_loc_floor_bottom_left
	var/other_z = concourse.z == 1 ? 2 : 1
	var/turf/hangar = locate(1, 1, other_z)
	var/turf/neighbor_hangar = locate(6, 1, other_z)
	var/turf/other_concourse = run_loc_floor_top_right
	port = allocate(/obj/docking_port/mobile/voidcrew, hangar)
	port.shuttle_areas = list()
	port.register()
	ship = allocate(/obj/structure/overmap/ship)
	ship.shuttle = port
	ship.state = "idle" // OVERMAP_SHIP_IDLE; fork defines follow unit test includes.
	ship.ship_team = new /datum/team/voidcrew
	ship.ship_team.ship = ship
	var/mob/living/carbon/human/consistent/crewmember = allocate(/mob/living/carbon/human/consistent, concourse)
	crewmember.mind_initialize()
	var/datum/client_interface/player = allocate(/datum/client_interface)
	crewmember.mock_client = player
	ship.ship_team.add_member(crewmember.mind)

	var/obj/structure/overmap/trader_outpost/market = allocate(/obj/structure/overmap/trader_outpost)
	market.reservation = reserve_test_bounds(concourse)
	var/datum/outpost_berth/berth = allocate(/datum/outpost_berth, market, 1, ship)
	berth.reservation = reserve_test_bounds(hangar)
	market.berths[1] = berth
	ship.docked = market
	TEST_ASSERT(ship.has_active_crew(), "Crew visiting a trader concourse on another level must protect their parked ship")

	// The actual sweep must rewind a timer that began before the crew returned.
	ship.crewless_since = world.time - 21 MINUTES
	var/list/previous_ships = SSovermap.simulated_ships
	SSovermap.simulated_ships = list(ship)
	SSovermap.sweep_derelicts()
	SSovermap.simulated_ships = previous_ships
	TEST_ASSERT(!ship.abandoned, "The derelict sweep abandoned a ship whose crew were in its connected concourse")
	TEST_ASSERT_EQUAL(ship.crewless_since, 0, "Returning to the facility did not reset the abandonment timer")

	var/obj/structure/overmap/trader_outpost/other_market = allocate(/obj/structure/overmap/trader_outpost)
	other_market.reservation = reserve_test_bounds(other_concourse)
	var/datum/outpost_berth/other_berth = allocate(/datum/outpost_berth, other_market, 1, null)
	other_berth.reservation = reserve_test_bounds(neighbor_hangar)
	other_market.berths[1] = other_berth
	crewmember.forceMove(neighbor_hangar)
	TEST_ASSERT(!ship.has_active_crew(), "A different facility's hangar on the ship's z-level must not count as this site")
	crewmember.forceMove(other_concourse)
	TEST_ASSERT(!ship.has_active_crew(), "A neighboring concourse must not protect this ship")
	crewmember.forceMove(hangar)
	TEST_ASSERT(ship.has_active_crew(), "Crew waiting in their hangar must protect the ship")

	// A second elevator destination belongs to the same facility even across levels.
	var/datum/outpost_berth/second_berth = allocate(/datum/outpost_berth, market, 2, null)
	second_berth.reservation = reserve_test_bounds(other_concourse)
	market.berths[2] = second_berth
	crewmember.forceMove(other_concourse)
	TEST_ASSERT(ship.has_active_crew(), "Crew visiting another connected berth must protect their ship")
	market.berths[2] = null

	var/obj/structure/overmap/dynamic/player_outpost/home = allocate(/obj/structure/overmap/dynamic/player_outpost)
	home.footprint = allocate(/datum/map_footprint)
	home.footprint.z_value = concourse.z
	home.footprint.set_rect(concourse.x, concourse.y, 3, 3)
	home.berths = list(berth)
	ship.docked = home
	crewmember.forceMove(concourse)
	TEST_ASSERT(ship.has_active_crew(), "Crew inside a player outpost on another level must protect their ship")
	home.freight_berth = second_berth
	crewmember.forceMove(other_concourse)
	TEST_ASSERT(ship.has_active_crew(), "The player outpost's freight elevator destination must count as part of the site")
	home.freight_berth = null
	home.berths = null

	var/obj/structure/overmap/colosseum/venue = allocate(/obj/structure/overmap/colosseum)
	venue.interior_levels = list(SSmapping.z_list[concourse.z], SSmapping.z_list[other_z])
	ship.docked = venue
	crewmember.forceMove(concourse)
	TEST_ASSERT(ship.has_active_crew(), "Crew visiting the arena must protect their parked ship")
	crewmember.forceMove(hangar)
	TEST_ASSERT(ship.has_active_crew(), "Crew visiting another floor of the venue must protect their ship")
	venue.interior_levels = null
	TEST_ASSERT(!ship.has_active_crew(), "An unloaded venue must not count a shared hangar level as its interior")

	ship.docked = market
	crewmember.forceMove(concourse)
	crewmember.stat = DEAD
	TEST_ASSERT(!ship.has_active_crew(), "Dead crew in the concourse must not prevent abandonment")
	crewmember.stat = CONSCIOUS
	crewmember.mock_client = null
	TEST_ASSERT(!ship.has_active_crew(), "Disconnected or ghosted crew must not prevent abandonment")
	crewmember.mock_client = player
	ship.ship_team.remove_member(crewmember.mind)
	TEST_ASSERT(!ship.has_active_crew(), "A living visitor who is not on this ship's roster must not protect it remotely")
	ship.ship_team.add_member(crewmember.mind)
	ship.docked = null
	TEST_ASSERT(!ship.has_active_crew(), "Crew remaining at a facility must stop protecting a ship that has left")
	crewmember.forceMove(hangar)
	TEST_ASSERT(ship.has_active_crew(), "Away crew on the hull's level outside a hangar facility must still count")
	crewmember.mock_client = null
