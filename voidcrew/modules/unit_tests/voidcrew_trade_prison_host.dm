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
	TEST_ASSERT(!prison.has_audience(), "A wing nobody is at has an audience before presence_tick()")
	TEST_ASSERT_EQUAL(length(prison.wing_clients()), 0, "A host with no map of its own counts clients")

	// Staff are the wing's own AI people, never a player or another wing's guard
	var/obj/machinery/door/airlock/security/prison_staff/staff_door = locate() in prison_spot(home, 9, 6)
	TEST_ASSERT_NOTNULL(staff_door, "The staff door is not where the map puts it")
	var/mob/living/carbon/human/visitor = make_player(yard_tile, "lockupvisitor")
	TEST_ASSERT_NOTNULL(visitor.mind, "The test player has no mind")
	TEST_ASSERT(!prison.is_staff(visitor), "A player counts as staff")
	TEST_ASSERT(!prison.is_inmate(visitor), "A player nobody booked counts as an inmate")
	TEST_ASSERT(!may_use_outpost_prison_staff_door(staff_door, visitor), "A visitor may use the staff doors")
	TEST_ASSERT(!may_use_outpost_prison_staff_door(staff_door, null), "Nobody at all may use a wing's staff door")
	TEST_ASSERT(!may_use_outpost_prison_staff_door(outside, null), "Nobody at all may use an unhosted staff door")
	var/datum/outpost_guard_record/record = prison.add_guard_record(TRUE)
	var/mob/living/carbon/human/npc/outpost_prison_guard/guard = record.guard
	TEST_ASSERT_NOTNULL(guard, "The test guard did not arrive")
	TEST_ASSERT(is_ai_outpost_prison_guard(guard), "An NPC guard is not an AI guard")
	TEST_ASSERT(prison.is_staff(guard), "A guard of the wing is not staff")
	TEST_ASSERT(may_use_outpost_prison_staff_door(staff_door, guard), "A guard of the wing cannot use its staff door")
	TEST_ASSERT(!prison.is_inmate(guard), "A guard counts as an inmate")
	var/mob/living/carbon/human/npc/outpost_prisoner/prisoner = test_prisoner(prison, yard_tile)
	TEST_ASSERT(!prison.is_staff(prisoner), "A prisoner counts as staff")
	TEST_ASSERT(!prison.is_inmate(prisoner), "An NPC prisoner counts as a player inmate")
	TEST_ASSERT_EQUAL(prison.guard_max(), 2, "The roster is not two guards") // OUTPOST_GUARD_MAX

	// Another wing's guard cannot open this wing's staff doors, and a player possessing a guard or officer loses staff privileges
	var/mob/living/carbon/human/npc/outpost_prison_guard/other_guard = allocate(/mob/living/carbon/human/npc/outpost_prison_guard, yard_tile)
	TEST_ASSERT(!prison.is_staff(other_guard), "A guard not on this wing's roster counts as its staff")
	TEST_ASSERT(!may_use_outpost_prison_staff_door(staff_door, other_guard), "Another wing's guard opened this wing's staff door")
	TEST_ASSERT(may_use_outpost_prison_staff_door(outside, other_guard), "An unhosted staff door refused an AI guard")
	other_guard.prison = prison
	TEST_ASSERT(prison.is_staff(other_guard) && may_use_outpost_prison_staff_door(staff_door, other_guard), "A guard assigned to the wing could not use its staff door")
	other_guard.key = "possessedguard"
	other_guard.mind_initialize()
	TEST_ASSERT(!is_ai_outpost_prison_guard(other_guard), "A player-possessed guard still counts as an AI guard")
	TEST_ASSERT(!prison.is_staff(other_guard), "A player-possessed guard counts as staff")
	TEST_ASSERT(!may_use_outpost_prison_staff_door(staff_door, other_guard), "A player-possessed guard opened the wing's staff door")
	TEST_ASSERT(!may_use_outpost_prison_staff_door(outside, other_guard), "A player-possessed guard opened an unhosted staff door")
	TEST_ASSERT_EQUAL(outpost_prison_turret_verdict(guard, null), 1, "A turret did not spare an AI guard") // OUTPOST_PRISON_TURRET_SPARE
	TEST_ASSERT_EQUAL(outpost_prison_turret_verdict(other_guard, null), 0, "A turret spared a player-possessed guard") // OUTPOST_PRISON_TURRET_NOT_MINE
	TEST_ASSERT(!prisoner.hit_by_staff(guard), "An AI guard's blow cost a calm prisoner mood")
	var/mood_before = prisoner.mood
	TEST_ASSERT(prisoner.hit_by_staff(other_guard), "A player-possessed guard hit a calm prisoner with no staff penalty")
	TEST_ASSERT(prisoner.mood < mood_before, "A player-possessed guard's unprovoked blow did not drop prisoner mood")
	other_guard.prison = null

	var/mob/living/carbon/human/npc/ambient_npc/outpost/police/beat/officer = allocate(/mob/living/carbon/human/npc/ambient_npc/outpost/police/beat, yard_tile)
	TEST_ASSERT(!prison.is_staff(officer), "An unlinked police officer counts as this wing's staff")
	officer.police = home.ensure_police()
	TEST_ASSERT(prison.is_staff(officer) && may_use_outpost_prison_staff_door(staff_door, officer), "The host outpost's AI officer cannot use the wing's staff door")
	officer.key = "possessedofficer"
	officer.mind_initialize()
	TEST_ASSERT(!prison.is_staff(officer) && !may_use_outpost_prison_staff_door(staff_door, officer), "A player-possessed police officer kept staff privileges")
	officer.police = null

	// A client mob outside the wing and outpost wakes nothing; inside the wing it wakes has_audience(), find_audience(), ai_running() and AI controllers
	var/mob/living/carbon/human/consistent/onlooker = allocate(/mob/living/carbon/human/consistent, outside)
	SSmobs.clients_by_zlevel[yard_tile.z] += onlooker
	prisoner.ai_controller.reset_ai_status()
	guard.ai_controller.reset_ai_status()
	var/outside_clients = length(prison.wing_clients())
	var/outside_audience = prison.find_audience()
	var/outside_has_audience = prison.has_audience()
	var/outside_running = prisoner.ai_running()
	var/outside_guard_running = guard.ai_running()
	var/outside_prisoner_status = prisoner.ai_controller.ai_status
	var/outside_guard_status = guard.ai_controller.ai_status
	onlooker.forceMove(yard_tile)
	prison.presence_tick(1)
	var/inside_counted = (onlooker in prison.wing_clients())
	var/inside_audience = prison.find_audience()
	var/inside_has_audience = prison.has_audience()
	var/inside_running = prisoner.ai_running()
	var/inside_guard_running = guard.ai_running()
	var/inside_prisoner_status = prisoner.ai_controller.ai_status
	var/inside_guard_status = guard.ai_controller.ai_status
	onlooker.forceMove(outside)
	prison.presence_tick(1)
	var/left_has_audience = prison.has_audience()
	var/left_running = prisoner.ai_running()
	var/left_guard_running = guard.ai_running()
	var/left_prisoner_status = prisoner.ai_controller.ai_status
	var/left_guard_status = guard.ai_controller.ai_status
	SSmobs.clients_by_zlevel[yard_tile.z] -= onlooker
	TEST_ASSERT_EQUAL(outside_clients, 0, "A client mob outside the wing and outpost was counted in wing_clients()")
	TEST_ASSERT(!outside_audience && !outside_has_audience && !outside_running && !outside_guard_running, "A client mob outside the wing woke has_audience(), find_audience() or ai_running()")
	TEST_ASSERT(outside_prisoner_status == AI_STATUS_OFF && outside_guard_status == AI_STATUS_OFF, "A client mob outside the wing woke prisoner or guard AI controllers")
	TEST_ASSERT(inside_counted, "A client mob inside the wing was not counted in wing_clients()")
	TEST_ASSERT(inside_audience && inside_has_audience && inside_running && inside_guard_running, "A client mob inside the wing did not wake has_audience(), find_audience() and ai_running()")
	TEST_ASSERT(inside_prisoner_status == AI_STATUS_ON && inside_guard_status == AI_STATUS_ON, "presence_tick() did not wake prisoner and guard AI controllers on the same z-level")
	TEST_ASSERT(!left_has_audience && !left_running && !left_guard_running, "Audience or ai_running() stayed true after the last client mob left the wing")
	TEST_ASSERT(left_prisoner_status == AI_STATUS_OFF && left_guard_status == AI_STATUS_OFF, "presence_tick() did not rest prisoner and guard AI controllers after the audience left")

	// Game log formatting strips \improper from trader outpost names
	var/saved_name = home.name
	home.name = "\improper Waystation Halcyon"
	TEST_ASSERT_EQUAL(prison.outpost_log_name(), "Waystation Halcyon", "outpost_log_name() left an improper marker in '[prison.outpost_log_name()]'")
	home.name = saved_name

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

	// Deleting the prison lets go of the area, the door watches, the roster and the list
	TEST_ASSERT(length(prison.door_watch_turfs) > 0, "The prison was not watching its door turfs")
	var/datum/weakref/guard_ref = WEAKREF(guard)
	var/datum/weakref/prisoner_ref = WEAKREF(prisoner)
	guard = null
	prisoner = null
	home.fixture_prison = null
	qdel(prison)
	TEST_ASSERT_EQUAL(length(prison.door_watch_turfs), 0, "A deleted prison still holds watched door turfs")
	TEST_ASSERT_EQUAL(length(prison.staff_door_turfs), 0, "A deleted prison still holds staff door turfs")
	TEST_ASSERT_NULL(wing.prison, "A deleted prison is still on its area")
	TEST_ASSERT(!(prison in GLOB.outpost_prisons), "A deleted prison is still on the list of prisons")
	TEST_ASSERT_NULL(get_outpost_prison(yard_tile), "A deleted prison is still found from its yard")
	TEST_ASSERT(is_qdeleted_ref(guard_ref), "A deleted prison left its guard behind")
	TEST_ASSERT(is_qdeleted_ref(prisoner_ref), "A deleted prison left its prisoner behind")

	// Deleting the host outpost deletes its prison too, even without the test host's Destroy()
	var/obj/structure/overmap/trader_outpost/plain_host = allocate(/obj/structure/overmap/trader_outpost)
	var/datum/outpost_prison/hosted_prison = new(plain_host, wing)
	STOP_PROCESSING(SSprocessing, hosted_prison)
	var/datum/weakref/hosted_ref = WEAKREF(hosted_prison)
	hosted_prison = null
	qdel(plain_host)
	TEST_ASSERT(is_qdeleted_ref(hosted_ref), "Deleting a host outpost left its prison behind")
	TEST_ASSERT_NULL(wing.prison, "A prison deleted with its host outpost stayed on its area")
	settle_prison_air(home)
