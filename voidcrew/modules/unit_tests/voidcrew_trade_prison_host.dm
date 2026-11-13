/**
 * The lockup's host: a prison runs on a trader outpost's lockup area, with no owner behind it.
 * The fixture is prison_test_claim() in voidcrew_outpost_prison_helpers.dm.
 */
/datum/unit_test/voidcrew_trade_prison_host
	parent_type = /datum/unit_test/voidcrew_outpost_management

/datum/unit_test/voidcrew_trade_prison_host/Run()
	var/obj/structure/overmap/trader_outpost/prison_test_host/home = prison_test_claim("lockuphost")
	TEST_ASSERT_NOTNULL(home, "The test wing did not load")
	var/datum/outpost_prison/prison = test_prison(home)
	TEST_ASSERT_NOTNULL(prison, "The test wing has no prison")
	TEST_ASSERT_EQUAL(prison.outpost, home, "The prison's outpost is not its host")
	TEST_ASSERT(prison in GLOB.outpost_prisons, "A running prison is not on the list of prisons")

	// The cells: the fixture has four, numbered from 1
	TEST_ASSERT_EQUAL(length(prison.cells), 4, "The fixture wing does not have four cells")
	TEST_ASSERT_EQUAL(prison.capacity, 4, "A four-cell wing does not hold four")
	for(var/index in 1 to 4)
		var/datum/outpost_prison_cell/cell = prison.cells[index]
		TEST_ASSERT_EQUAL(cell.number, index, "The cells are not in number order")

	// The wing is its area's turfs: no more, no fewer, and the list is the caller's own copy
	var/area/voidcrew/outpost_lockup/wing = prison.wing
	TEST_ASSERT(istype(wing), "The prison's wing is a [wing?.type]")
	TEST_ASSERT_EQUAL(wing.prison, prison, "The wing's area does not know its prison")
	var/list/area_turfs = list()
	for(var/list/level_turfs as anything in wing.get_zlevel_turf_lists())
		area_turfs += level_turfs
	var/list/wing_turfs = prison.wing_turfs()
	TEST_ASSERT_EQUAL(length(wing_turfs), length(area_turfs), "wing_turfs() is not the area's turfs")
	TEST_ASSERT_EQUAL(length(wing_turfs - area_turfs), 0, "wing_turfs() holds a tile outside the area")
	wing_turfs.Cut()
	TEST_ASSERT(length(prison.wing_turfs()), "Emptying a caller's copy emptied the wing's own list")

	// Finding the wing from a tile
	var/turf/yard_tile = prison_spot(home, 9, 9)
	TEST_ASSERT(prison.contains_turf(yard_tile), "A yard tile is not in the wing")
	TEST_ASSERT_EQUAL(get_outpost_prison(yard_tile), prison, "A yard tile does not find its wing")
	TEST_ASSERT(prison.in_cell_block(yard_tile), "The yard is not in the cell block")
	var/turf/outside = run_loc_floor_bottom_left
	TEST_ASSERT(!prison.contains_turf(outside), "A tile outside the wing is in it")
	TEST_ASSERT_NULL(get_outpost_prison(outside), "A tile outside the wing finds a wing")
	TEST_ASSERT(!prison.contains_turf(null), "No tile at all is in the wing")
	TEST_ASSERT_EQUAL(prison.wing_z(), yard_tile.z, "wing_z() is not the wing's level")

	// Somebody there to see it: the override both ways, and nobody in a world with no clients
	prison.audience_override = TRUE
	TEST_ASSERT(prison.has_audience(), "The audience override on does not count as someone there")
	prison.audience_override = FALSE
	TEST_ASSERT(!prison.has_audience(), "The audience override off still counts as someone there")
	prison.audience_override = null
	prison.presence_tick(1)
	TEST_ASSERT(!prison.has_audience(), "A wing nobody is at has an audience")
	TEST_ASSERT_EQUAL(length(prison.wing_clients()), 0, "A host with no map of its own counts clients")

	// Staff are the wing's own people, never a player
	var/mob/living/carbon/human/visitor = make_player(yard_tile, "lockupvisitor")
	TEST_ASSERT_NOTNULL(visitor.mind, "The test player has no mind")
	TEST_ASSERT(!prison.is_staff(visitor), "A player counts as staff")
	TEST_ASSERT(!prison.is_inmate(visitor), "A player nobody booked counts as an inmate")
	TEST_ASSERT(!may_use_outpost_prison_staff_door(yard_tile, visitor), "A visitor may use the staff doors")
	var/datum/outpost_guard_record/record = prison.add_guard_record(TRUE)
	var/mob/living/carbon/human/npc/outpost_prison_guard/guard = record.guard
	TEST_ASSERT_NOTNULL(guard, "The test guard did not arrive")
	TEST_ASSERT(prison.is_staff(guard), "A guard of the wing is not staff")
	TEST_ASSERT(!prison.is_inmate(guard), "A guard counts as an inmate")
	var/mob/living/carbon/human/npc/outpost_prisoner/prisoner = test_prisoner(prison, yard_tile)
	TEST_ASSERT(!prison.is_staff(prisoner), "A prisoner counts as staff")
	TEST_ASSERT(!prison.is_inmate(prisoner), "An NPC prisoner counts as a player inmate")
	TEST_ASSERT_EQUAL(prison.guard_max(), 2, "The roster is not two guards") // OUTPOST_GUARD_MAX

	// A client mob outside the wing and outpost wakes nothing; inside the wing it wakes find_audience() and ai_running() at once
	var/mob/living/carbon/human/consistent/onlooker = allocate(/mob/living/carbon/human/consistent, outside)
	SSmobs.clients_by_zlevel[yard_tile.z] += onlooker
	var/outside_clients = length(prison.wing_clients())
	var/outside_audience = prison.find_audience()
	var/outside_running = prisoner.ai_running()
	onlooker.forceMove(yard_tile)
	var/inside_counted = (onlooker in prison.wing_clients())
	var/inside_audience = prison.find_audience()
	var/inside_running = prisoner.ai_running()
	SSmobs.clients_by_zlevel[yard_tile.z] -= onlooker
	TEST_ASSERT_EQUAL(outside_clients, 0, "A client mob outside the wing and outpost was counted in wing_clients()")
	TEST_ASSERT(!outside_audience && !outside_running, "A client mob outside the wing woke find_audience() or ai_running()")
	TEST_ASSERT(inside_counted, "A client mob inside the wing was not counted in wing_clients()")
	TEST_ASSERT(inside_audience && inside_running, "A client mob inside the wing did not wake find_audience() and ai_running()")

	// A plain prison judges the tests' own player as the game would
	var/mob/living/carbon/human/member = make_player(yard_tile, "lockuphost")
	TEST_ASSERT(prison.is_staff(member), "The fixture does not let its own player stand in for staff")
	var/datum/outpost_prison/unit_test/fixture = prison
	fixture.member_key = null
	TEST_ASSERT(!prison.is_staff(member), "With no stand-in, a player is staff")
	TEST_ASSERT(!prison.is_inmate(member), "With no stand-in, a player is an inmate")

	// Intake: shut by the fixture, and nothing but power and the switch decides it
	TEST_ASSERT_EQUAL(prison.intake_state(), "closed", "The fixture's intake is not shut")
	TEST_ASSERT(prison.set_intake(TRUE), "Intake would not open")
	TEST_ASSERT_EQUAL(prison.intake_state(), "open", "Open intake does not read open")
	TEST_ASSERT(prison.arrivals_allowed(), "A powered wing with intake open takes nobody")
	prison.set_intake(FALSE)

	// Deleting the prison lets go of the area, the roster and the list
	var/datum/weakref/guard_ref = WEAKREF(guard)
	var/datum/weakref/prisoner_ref = WEAKREF(prisoner)
	home.fixture_prison = null
	qdel(prison)
	TEST_ASSERT_NULL(wing.prison, "A deleted prison is still on its area")
	TEST_ASSERT(!(prison in GLOB.outpost_prisons), "A deleted prison is still on the list of prisons")
	TEST_ASSERT_NULL(get_outpost_prison(yard_tile), "A deleted prison is still found from its yard")
	TEST_ASSERT(is_qdeleted_ref(guard_ref), "A deleted prison left its guard behind")
	TEST_ASSERT(is_qdeleted_ref(prisoner_ref), "A deleted prison left its prisoner behind")
	settle_prison_air(home)
