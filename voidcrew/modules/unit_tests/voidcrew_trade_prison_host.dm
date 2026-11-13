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
	var/obj/machinery/door/window/brigdoor/outpost_prison_staff/hatch_door = locate() in prison_spot(home, 13, 6)
	TEST_ASSERT_NOTNULL(hatch_door, "The serving hatch's staff window is not where the map puts it")
	prisoner.trouble = "loose" // PRISONER_TROUBLE_LOOSE
	TEST_ASSERT(!staff_door.CanAStarPass(NORTH, new /datum/can_pass_info(prisoner)), "A loose prisoner's pathing treated a shut staff airlock as passable")
	TEST_ASSERT(!staff_door.CanAStarPass(NORTH, new /datum/can_pass_info(visitor)), "A visitor's pathing treated a shut staff airlock as passable")
	TEST_ASSERT(staff_door.CanAStarPass(NORTH, new /datum/can_pass_info(guard)), "A guard's pathing could not pass a shut staff airlock")
	TEST_ASSERT(!hatch_door.CanAStarPass(hatch_door.dir, new /datum/can_pass_info(prisoner)), "A loose prisoner's pathing treated a shut hatch window as passable")
	TEST_ASSERT(!hatch_door.CanAStarPass(hatch_door.dir, new /datum/can_pass_info(visitor)), "A visitor's pathing treated a shut hatch window as passable")
	TEST_ASSERT(hatch_door.CanAStarPass(hatch_door.dir, new /datum/can_pass_info(guard)), "A guard's pathing could not pass a shut hatch window")
	prisoner.trouble = null

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

/**
 * The Lockup lift stop on a mapped wing (Quartermain Depot): the row every panel lists, the ride both ways, a
 * prisoner left behind by the car; the guards coming on shift in the staff closet with the wing's cleanbot; and
 * the outpost deleted with a wing full of people (abuse 28).
 */
/datum/unit_test/voidcrew_trade_prison_lift
	parent_type = /datum/unit_test/voidcrew_outpost_management

/datum/unit_test/voidcrew_trade_prison_lift/proc/lockup_row(list/rows)
	for(var/list/row as anything in rows)
		if(row["id"] == 90) // OUTPOST_LIFT_LOCKUP
			return row
	return null

/datum/unit_test/voidcrew_trade_prison_lift/Run()
	var/obj/structure/overmap/trader_outpost/outpost = lockup_test_outpost()
	TEST_ASSERT_NOTNULL(outpost, "Quartermain Depot's interior did not load")
	var/datum/outpost_prison/prison = outpost.prison
	TEST_ASSERT_NOTNULL(prison, "Quartermain Depot has no lockup")
	TEST_ASSERT_EQUAL(length(outpost.lobby_alcove_turfs), 9, "The concourse lift car lost tiles to the lockup's")
	TEST_ASSERT(length(outpost.lobby_panels), "Quartermain Depot has no concourse lift panel")
	var/obj/machinery/outpost_elevator/lobby_panel = outpost.lobby_panels[1]
	var/obj/machinery/outpost_elevator/lockup/wing_panel = prison.lift_panel

	// The row: one, named Lockup, on the host's list and so on every panel's
	var/mob/living/carbon/human/rider = make_player(outpost.lobby_alcove_turfs[1], "lockuprider")
	var/list/row = lockup_row(outpost.extra_floor_rows(rider))
	TEST_ASSERT_NOTNULL(row, "The lift does not list the lockup")
	TEST_ASSERT_EQUAL(row["name"], "Lockup", "The lockup's lift row is named [row["name"]]")
	TEST_ASSERT(row["occupied"], "The lockup's lift row cannot be picked")
	TEST_ASSERT(!row["kind"], "The lockup's lift row is listed as a leased floor")
	var/list/lobby_data = lobby_panel.ui_data(rider)
	TEST_ASSERT_NOTNULL(lockup_row(lobby_data["floors"]), "The concourse panel does not list the lockup")
	var/list/wing_data = wing_panel.ui_data(rider)
	TEST_ASSERT_NOTNULL(lockup_row(wing_data["floors"]), "The lockup's own panel does not list the lockup")
	TEST_ASSERT_EQUAL(wing_data["current_floor"], 90, "The lockup's panel does not know it is at the lockup")
	TEST_ASSERT(wing_data["linked"], "The lockup's panel is not linked")
	var/list/told = wing_panel.examine(rider)
	TEST_ASSERT(findtext(jointext(told, " "), "LOCKUP"), "The lockup's panel does not read LOCKUP")

	// Where it goes, and who may go: anyone
	TEST_ASSERT_EQUAL(outpost.get_floor_alcove(90), prison.alcove_turfs, "The lockup's lift stop is not the wing's alcove")
	TEST_ASSERT_EQUAL(wing_panel.get_own_alcove(), prison.alcove_turfs, "The lockup's panel does not stand at the wing's alcove")
	TEST_ASSERT(outpost.may_enter_floor(90, rider), "A visitor may not ride to the lockup")
	TEST_ASSERT_EQUAL(outpost.lift_car_at(prison.alcove_turfs[5]), prison.alcove_turfs, "The lockup's alcove is not known as a lift car")
	TEST_ASSERT(wing_panel in outpost.lift_panels(), "The lockup's panel is not one of the outpost's lift panels")

	// The ride up and the ride back
	lobby_panel.complete_ride(90, WEAKREF(rider))
	TEST_ASSERT(get_turf(rider) in prison.alcove_turfs, "The ride to the lockup did not set the rider down in its alcove")
	TEST_ASSERT_EQUAL(get_turf(rider), prison.alcove_turfs[1], "The ride did not keep the rider's place in the car")
	// The car leaves the wing's prisoners behind
	var/mob/living/carbon/human/npc/outpost_prisoner/stowaway = new(prison.alcove_turfs[2])
	prison.admit(stowaway)
	wing_panel.complete_ride(0, WEAKREF(rider))
	TEST_ASSERT(get_turf(rider) in outpost.lobby_alcove_turfs, "The ride from the lockup did not set the rider down on the concourse")
	TEST_ASSERT_EQUAL(get_turf(stowaway), prison.alcove_turfs[2], "The lift carried a prisoner out of the lockup")

	// Guards come on shift in the staff closet, its door shut, and the wing's cleanbot with them
	prison.roster_kept = TRUE
	prison.bot_kept = TRUE
	var/obj/machinery/door/airlock/closet_door = prison.staff_closet_door()
	TEST_ASSERT(closet_door.density, "The staff closet's door is open on a wing nobody has used")
	prison.guards_tick(1)
	TEST_ASSERT_EQUAL(length(prison.guard_records), 2, "A wing keeping its roster has [length(prison.guard_records)] guards on its books, not 2") // OUTPOST_GUARD_MAX
	TEST_ASSERT_EQUAL(length(prison.guard_mobs), 2, "[length(prison.guard_mobs)] guards came on shift, not 2")
	var/list/datum/weakref/people = list(WEAKREF(stowaway))
	for(var/mob/living/carbon/human/npc/outpost_prison_guard/guard as anything in prison.guard_mobs)
		TEST_ASSERT(get_turf(guard) in prison.staff_closet_turfs, "A guard came on shift outside the staff closet")
		TEST_ASSERT_EQUAL(guard.phase, "present", "A guard on shift is [guard.phase]") // OUTPOST_GUARD_PRESENT
		TEST_ASSERT(guard.fresh_on_shift, "A guard still in the staff closet has already said hello")
		TEST_ASSERT(closet_door.allowed(guard), "The staff closet's door would not open for a guard")
		people += WEAKREF(guard)
	var/mob/living/basic/bot/cleanbot/bot = prison.cleanbot()
	TEST_ASSERT_NOTNULL(bot, "No cleanbot came with the guards")
	TEST_ASSERT(get_turf(bot) in prison.staff_closet_turfs, "The cleanbot did not come in by the staff closet")
	TEST_ASSERT(closet_door.allowed(bot), "The staff closet's door would not open for the wing's cleanbot")
	var/obj/machinery/door/airlock/inner = prison.processing_door(TRUE)
	TEST_ASSERT(!inner.allowed(bot), "Processing's inner door would open for a cleanbot")
	people += WEAKREF(bot)
	prison.guards_tick(1)
	TEST_ASSERT_EQUAL(length(prison.guard_records), 2, "The roster grew past 2")
	// With the closet full nobody else is made in it
	TEST_ASSERT_NULL(prison.guard_arrival_spot(), "A third guard could be made in a full staff closet")
	bot = null

	// The outpost goes, with the wing full: nothing of the wing is left behind (abuse 28)
	var/area/voidcrew/outpost_lockup/wing = prison.wing
	qdel(outpost)
	TEST_ASSERT(QDELETED(prison), "The lockup outlived its outpost")
	TEST_ASSERT(!(prison in GLOB.outpost_prisons), "A deleted lockup is still on the list of prisons")
	TEST_ASSERT_NULL(outpost.prison, "A deleted outpost still points at its lockup")
	TEST_ASSERT_NULL(wing.prison, "The lockup's area still points at a deleted prison")
	TEST_ASSERT_NULL(wing_panel.prison, "The lockup's lift panel still points at a deleted prison")
	for(var/datum/weakref/person as anything in people)
		TEST_ASSERT(is_qdeleted_ref(person), "One of the lockup's people outlived it")
	TEST_ASSERT_EQUAL(length(prison.prisoners), 0, "A deleted lockup kept its prisoners")
	TEST_ASSERT_EQUAL(length(prison.guard_mobs), 0, "A deleted lockup kept its guards")
	TEST_ASSERT_EQUAL(length(prison.guard_records), 0, "A deleted lockup kept its roster")
	TEST_ASSERT_EQUAL(length(prison.cells), 0, "A deleted lockup kept its cells")
	TEST_ASSERT_EQUAL(length(prison.alcove_turfs) + length(prison.processing_turfs) + length(prison.staff_closet_turfs), 0, "A deleted lockup kept its mapped places")
	TEST_ASSERT_EQUAL(length(prison.processing_leavers), 0, "A deleted lockup kept its leavers")
	TEST_ASSERT_NULL(prison.lift_panel, "A deleted lockup kept its lift panel")

/**
 * The wing keeps itself (D11, D13), on the fixture wing: the galley stocks each hatch one thing a minute, a meal
 * then a clean uniform in turn, never past the counter's capacity; and the roster is always two, a dead guard's
 * place going to exactly one newcomer.
 */
/datum/unit_test/voidcrew_trade_prison_keeping
	parent_type = /datum/unit_test/voidcrew_outpost_management
	var/list/bot_heard = list()

/datum/unit_test/voidcrew_trade_prison_keeping/proc/on_bot_say(datum/source, list/speech_args)
	SIGNAL_HANDLER
	bot_heard += speech_args[SPEECH_MESSAGE]

/datum/unit_test/voidcrew_trade_prison_keeping/proc/galley_count_on(obj/structure/table/reinforced/prison_hatch/hatch, item_type)
	. = 0
	for(var/obj/item/thing in hatch.loc)
		if(istype(thing, item_type))
			.++

/datum/unit_test/voidcrew_trade_prison_keeping/Run()
	var/obj/structure/overmap/trader_outpost/prison_test_host/home = prison_test_claim("lockupkeeping")
	TEST_ASSERT_NOTNULL(home, "The test wing did not load")
	var/datum/outpost_prison/prison = test_prison(home)
	var/list/obj/structure/table/reinforced/prison_hatch/hatches = prison.hatches()
	TEST_ASSERT_EQUAL(length(hatches), 2, "The fixture wing should have two serving hatches")

	// Off, the galley does nothing
	prison.tick(120)
	for(var/obj/structure/table/reinforced/prison_hatch/hatch as anything in hatches)
		TEST_ASSERT_EQUAL(hatch.stock_count(), 0, "A hatch was stocked with the galley off")

	// On: nothing for 59 seconds, then one meal on each hatch (OUTPOST_PRISON_GALLEY_GAP 60)
	prison.galley_on = TRUE
	prison.tick(59)
	for(var/obj/structure/table/reinforced/prison_hatch/hatch as anything in hatches)
		TEST_ASSERT_EQUAL(hatch.stock_count(), 0, "The galley stocked a hatch early")
	prison.tick(1)
	for(var/obj/structure/table/reinforced/prison_hatch/hatch as anything in hatches)
		TEST_ASSERT_EQUAL(hatch.stock_count(), 1, "A hatch at 0 has [hatch.stock_count()] items after a minute, not 1")
		TEST_ASSERT_EQUAL(galley_count_on(hatch, /obj/item/food/prison_ration), 1, "The first round of the galley was not a meal")
	// A long step is still one round
	prison.tick(600)
	for(var/obj/structure/table/reinforced/prison_hatch/hatch as anything in hatches)
		TEST_ASSERT_EQUAL(hatch.stock_count(), 2, "Ten minutes in one step stocked [hatch.stock_count() - 1] items, not 1")
		TEST_ASSERT_EQUAL(galley_count_on(hatch, /obj/item/clothing/under/rank/prisoner/outpost), 1, "The second round of the galley was not a clean uniform")
	// Never past capacity, and each kind up to its share: 7 meals and 3 uniforms on a counter of 10
	// (OUTPOST_PRISON_HATCH_CAPACITY, OUTPOST_PRISON_FILL_MEAL_SHARE)
	for(var/i in 1 to 30)
		prison.galley_tick(60)
		for(var/obj/structure/table/reinforced/prison_hatch/hatch as anything in hatches)
			TEST_ASSERT(hatch.stock_count() <= 10, "The galley stocked a hatch to [hatch.stock_count()], past its capacity")
	for(var/obj/structure/table/reinforced/prison_hatch/hatch as anything in hatches)
		TEST_ASSERT_EQUAL(hatch.stock_count(), 10, "The galley left a hatch at [hatch.stock_count()] after half an hour, not full")
		TEST_ASSERT_EQUAL(galley_count_on(hatch, /obj/item/food/prison_ration), 7, "A full hatch holds [galley_count_on(hatch, /obj/item/food/prison_ration)] meals, not 7")
		TEST_ASSERT_EQUAL(galley_count_on(hatch, /obj/item/clothing/under/rank/prisoner/outpost), 3, "A full hatch holds [galley_count_on(hatch, /obj/item/clothing/under/rank/prisoner/outpost)] uniforms, not 3")
		TEST_ASSERT_NULL(prison.galley_serve(hatch), "The galley served a full hatch")
	// A counter full of dirty uniforms does not end the meals: one goes back to the wash for each thing served
	var/obj/structure/table/reinforced/prison_hatch/clogged = hatches[1]
	for(var/obj/item/thing in clogged.loc)
		qdel(thing)
	for(var/i in 1 to 10)
		var/obj/item/clothing/under/rank/prisoner/outpost/dirty = new(clogged.loc)
		dirty.set_grime(80) // PRISONER_GRIME_DIRTY 50
	TEST_ASSERT_EQUAL(clogged.room_left(), 0, "Ten dirty uniforms did not fill the counter")
	var/obj/item/served = prison.galley_serve(clogged)
	TEST_ASSERT_NOTNULL(served, "The galley gave up on a counter full of dirty uniforms")
	TEST_ASSERT_EQUAL(clogged.stock_count(), 10, "Serving a clogged counter left [clogged.stock_count()] items on it, not 10")
	prison.galley_on = FALSE

	// The roster: two with nobody hiring them, and it stays two
	TEST_ASSERT_EQUAL(length(prison.guard_records), 0, "The fixture wing has guards before its roster is kept")
	prison.roster_kept = TRUE
	prison.guards_tick(1)
	TEST_ASSERT_EQUAL(length(prison.guard_records), 2, "A fresh wing has [length(prison.guard_records)] guards on its books, not 2") // OUTPOST_GUARD_MAX
	TEST_ASSERT_EQUAL(length(prison.guard_mobs), 2, "A fresh wing has [length(prison.guard_mobs)] guards on shift, not 2")
	prison.guards_tick(5)
	TEST_ASSERT_EQUAL(length(prison.guard_records), 2, "The roster grew to [length(prison.guard_records)]")
	TEST_ASSERT_EQUAL(length(prison.guard_mobs), 2, "A third guard came on shift")

	// Killing one schedules exactly one replacement, ten minutes off (OUTPOST_GUARD_RETURN_TIME)
	var/datum/outpost_guard_record/doomed_record = prison.guard_records[1]
	var/mob/living/carbon/human/npc/outpost_prison_guard/doomed = doomed_record.guard
	doomed.death()
	TEST_ASSERT_EQUAL(length(prison.guard_records), 2, "Killing a guard left [length(prison.guard_records)] slots, not 2")
	var/empty_slots = 0
	for(var/datum/outpost_guard_record/record as anything in prison.guard_records)
		if(record.guard)
			continue
		empty_slots++
		TEST_ASSERT_EQUAL(record.away_left, 600, "A dead guard is replaced in [record.away_left] s, not 600")
	TEST_ASSERT_EQUAL(empty_slots, 1, "Killing one guard emptied [empty_slots] slots")
	prison.guards_tick(599)
	TEST_ASSERT_EQUAL(length(prison.guard_mobs), 2, "A replacement came early, or the body was taken")
	prison.guards_tick(1)
	TEST_ASSERT_EQUAL(length(prison.guard_records), 2, "A replacement changed the roster to [length(prison.guard_records)]")
	TEST_ASSERT_EQUAL(length(prison.guard_mobs), 3, "No replacement came after ten minutes (the body stays: 3 in all)")
	for(var/datum/outpost_guard_record/record as anything in prison.guard_records)
		TEST_ASSERT_NOTNULL(record.guard, "A slot is still empty after its replacement was due")
		TEST_ASSERT(record.guard != doomed, "The dead guard is back on the roster")
	prison.guards_tick(700)
	TEST_ASSERT_EQUAL(length(prison.guard_mobs), 3, "A second replacement came for one death")

	// The lockup's cleanbot cannot be hijacked remotely or possessed, skips bolted cells, and dispatches silently past walls
	prison.bot_kept = TRUE
	var/mob/living/basic/bot/cleanbot/outpost_lockup/bot = prison.keep_cleanbot(prison_spot(home, 14, 11))
	TEST_ASSERT_NOTNULL(bot, "keep_cleanbot() did not make a cleanbot")
	TEST_ASSERT(!(bot.bot_mode_flags & BOT_MODE_REMOTE_ENABLED), "The lockup cleanbot accepts remote PDA control")
	bot.bot_control("patrolon", null)
	TEST_ASSERT(!(bot.bot_mode_flags & BOT_MODE_AUTOPATROL), "Remote PDA control turned autopatrol on for the lockup cleanbot")
	bot.enable_possession(null)
	TEST_ASSERT(!bot.can_be_possessed, "The lockup cleanbot allowed ghost possession")
	RegisterSignal(bot, COMSIG_MOB_SAY, PROC_REF(on_bot_say))
	var/turf/cell_mess_tile = prison_spot(home, 14, 13)
	var/obj/effect/decal/cleanable/dirt/cell_mess = new(cell_mess_tile)
	var/obj/machinery/door/airlock/cell_four_door = prison.cells[4].door()
	cell_four_door.bolt()
	prison.cleanbot_tick(60) // OUTPOST_PRISON_BOT_CALL_GAP
	TEST_ASSERT_EQUAL(bot.mode, BOT_IDLE, "The cleanbot was sent after a mess shut inside a bolted cell")
	cell_four_door.unbolt()
	prison.cleanbot_tick(60) // OUTPOST_PRISON_BOT_CALL_GAP
	TEST_ASSERT_EQUAL(bot.mode, BOT_SUMMON, "The cleanbot was not sent to a mess two tiles off behind a cell wall")
	TEST_ASSERT_EQUAL(bot.ai_controller.blackboard[BB_BOT_SUMMON_TARGET], cell_mess_tile, "The cleanbot was sent to the wrong tile")
	TEST_ASSERT_EQUAL(length(bot_heard), 0, "Sending the lockup cleanbot to a mess made it speak aloud")
	qdel(cell_mess)
	bot = null
	settle_prison_air(home)
