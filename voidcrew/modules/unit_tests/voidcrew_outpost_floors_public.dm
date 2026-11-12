/**
 * Outpost floors (voidcrew/modules/trade_floors/): tests of package P11.
 * Owner: P11. Subtype /datum/unit_test/voidcrew_outpost_floors and use the helpers in
 * voidcrew_outpost_floors_helpers.dm (P0, frozen). Fork defines are included after the tests: write the literal
 * value with a comment naming the define. Pin other packages' outputs directly and never wait for an AI walk.
 *
 * P11 is the directory board, the NPC budget, and the customers and patrons (floor_directory.dm, floor_customers.dm).
 * The sale itself (npc_buy(), npc_sale_points(), shop_open()) is P12's: these tests stand a plain object in for a sale
 * point and check P11's own gates one by one, since a test floor has no Shop room.
 */

/// Parent of P11's tests
/datum/unit_test/voidcrew_outpost_floors/public
	abstract_type = /datum/unit_test/voidcrew_outpost_floors/public
	/// People given a key, to take it back
	var/list/mob/living/keyed = list()

/datum/unit_test/voidcrew_outpost_floors/public/Destroy()
	for(var/mob/living/person as anything in keyed)
		if(!QDELETED(person))
			person.key = null
	keyed.Cut()
	return ..()

/// A person with a key and a mind at `where`
/datum/unit_test/voidcrew_outpost_floors/public/proc/keyed_person(key, turf/where)
	var/mob/living/carbon/human/person = test_person(where)
	person.key = key
	person.mind_initialize()
	keyed += person
	return person

/// The budget: OUTPOST_FLOOR_NPC_BUDGET (100) a window at most, OUTPOST_FLOOR_NPC_ITEM_MAX (60) a thing at most, one
/// clock a floor that no setting, re-let or number of sale points raises (A64, A76)
/datum/unit_test/voidcrew_outpost_floors/public/budget

/datum/unit_test/voidcrew_outpost_floors/public/budget/Run()
	var/obj/structure/overmap/trader_outpost/outpost = test_outpost()
	var/datum/outpost_floor/floor = test_floor(outpost, 1, with_host = TRUE)
	if(!floor)
		return
	// An hour with no custom: the budget is full, and no fuller
	floor.npc_ready_at = world.time - 1 HOURS
	TEST_ASSERT_EQUAL(floor.npc_budget_left(), 100, "An hour unspent left other than OUTPOST_FLOOR_NPC_BUDGET to spend")
	TEST_ASSERT(!floor.npc_budget_spend(61), "An NPC paid more than OUTPOST_FLOOR_NPC_ITEM_MAX for one thing")
	TEST_ASSERT(!floor.npc_budget_spend(0), "The budget took a sale of nothing")
	TEST_ASSERT(!floor.npc_budget_spend(-5), "The budget took a negative sale")
	TEST_ASSERT_EQUAL(floor.npc_budget_left(), 100, "A refused sale took from the budget")
	TEST_ASSERT(floor.npc_budget_spend(60), "A full budget refused a sale at OUTPOST_FLOOR_NPC_ITEM_MAX")
	TEST_ASSERT_EQUAL(floor.npc_budget_left(), 40, "A 60 cr sale did not leave 40 of 100")
	TEST_ASSERT(!floor.npc_budget_spend(41), "The budget paid more than it had")

	// Settings, identity, hands and a re-let floor leave the clock alone
	floor.entry_policy = "invited" // OUTPOST_FLOOR_ENTRY_INVITED
	floor.entry_policy = "open" // OUTPOST_FLOOR_ENTRY_OPEN
	floor.set_accent("teal") // OUTPOST_FLOOR_ACCENT_TEAL
	floor.floor_name = "Renamed"
	floor.reset_lease()
	floor.state = "owned" // OUTPOST_FLOOR_STATE_OWNED
	floor.entry_policy = "open" // OUTPOST_FLOOR_ENTRY_OPEN
	TEST_ASSERT_EQUAL(floor.npc_budget_left(), 40, "A change of setting, name, colour or lease refilled the budget")

	// Twenty sale points (tills, shelves, patrons) all draw on the one budget: 40 left covers eight sales of 5
	var/sold = 0
	for(var/point in 1 to 20)
		if(floor.npc_budget_spend(5))
			sold++
	TEST_ASSERT_EQUAL(sold, 8, "Twenty sale points sold more than the one budget covered")
	TEST_ASSERT_EQUAL(floor.npc_budget_left(), 0, "The budget was not spent out")

	// The clock: half a window (OUTPOST_FLOOR_NPC_BUDGET_WINDOW, 15 minutes) later half is back; a window later all of it
	var/empty_until = floor.npc_ready_at
	floor.npc_ready_at = empty_until - 7.5 MINUTES
	TEST_ASSERT_EQUAL(floor.npc_budget_left(), 50, "Half a window did not bring back half the budget")
	floor.npc_ready_at = empty_until - 15 MINUTES
	TEST_ASSERT_EQUAL(floor.npc_budget_left(), 100, "A window did not bring back the whole budget")
	floor.npc_ready_at = empty_until - 4 HOURS
	TEST_ASSERT_EQUAL(floor.npc_budget_left(), 100, "Hours unspent were saved up past the budget")

/// No customer on an Invited floor, a shut shop, an unminded floor, or for a sale point behind a Members door
/datum/unit_test/voidcrew_outpost_floors/public/no_customer

/datum/unit_test/voidcrew_outpost_floors/public/no_customer/Run()
	var/obj/structure/overmap/trader_outpost/outpost = test_outpost()
	var/datum/outpost_floor/floor = test_floor(outpost, 1, with_host = TRUE)
	if(!floor)
		return
	floor.host.founder_ckey = "p11floorowner"
	var/mob/living/carbon/human/owner = keyed_person("p11floorowner", deck_tile(floor, 3))
	var/mob/living/carbon/human/stranger = test_person(deck_tile(floor, 5))
	// A stand-in for a till: a table out on the deck
	var/obj/structure/table/point = allocate(/obj/structure/table, floor_tile(floor, 7, 8))

	floor.entry_policy = "crew" // OUTPOST_FLOOR_ENTRY_CREW
	TEST_ASSERT_EQUAL(floor.npc_custom_denial(list(owner), list(point)), "setting", "A customer may come up to a Crew only floor")
	floor.entry_policy = "invited" // OUTPOST_FLOOR_ENTRY_INVITED
	TEST_ASSERT_EQUAL(floor.npc_custom_denial(list(owner), list(point)), "setting", "A customer may come up to an Invited floor")
	floor.entry_policy = "open" // OUTPOST_FLOOR_ENTRY_OPEN
	// A test floor has no Shop room: its shop is shut
	TEST_ASSERT_EQUAL(floor.npc_custom_denial(list(owner), list(point)), "shut", "A customer may come up to a shut shop")
	floor.state = "vacant" // OUTPOST_FLOOR_STATE_VACANT
	TEST_ASSERT_EQUAL(floor.npc_custom_denial(list(owner), list(point)), "unlet", "A customer may come up to a vacant floor")
	floor.state = "owned" // OUTPOST_FLOOR_STATE_OWNED

	// Minded: one of the floor's own people on the floor, not a stranger, not someone downstairs
	TEST_ASSERT(!floor.npc_minded(list()), "An empty floor counts as minded")
	TEST_ASSERT(!floor.npc_minded(list(stranger)), "A stranger minds the shop")
	TEST_ASSERT(floor.npc_minded(list(owner)), "The owner on their floor does not mind the shop")
	owner.forceMove(run_loc_floor_bottom_left)
	TEST_ASSERT(!floor.npc_minded(list(owner)), "The owner minds the shop from off the floor")
	owner.forceMove(deck_tile(floor, 3))
	owner.death()
	TEST_ASSERT(!floor.npc_minded(list(owner)), "A dead owner minds the shop")

	// A wall across the deck with one airlock: through it is the sale point
	var/list/bounds = floor.bounds
	var/door_dx = round((bounds[1] + bounds[3]) / 2) - bounds[1]
	for(var/dx in 1 to 12)
		if(dx != door_dx)
			var/turf/wall_tile = floor_tile(floor, dx, 5)
			wall_tile.ChangeTurf(/turf/closed/wall)
	var/obj/machinery/door/airlock/door = allocate(/obj/machinery/door/airlock, floor_tile(floor, door_dx, 5))
	var/list/reach = floor.npc_reach()
	TEST_ASSERT(length(floor.npc_points_in_reach(reach, list(point))), "A sale point through a public door is out of a visitor's reach")
	TEST_ASSERT(!reach[get_turf(point)], "A visitor's route goes over a table")

	// Keyed to members, opening only from the far side: no route, no customer
	door.AddComponent(/datum/component/outpost_door_access, "members", NORTH, floor.host) // OUTPOST_DOOR_MEMBERS
	reach = floor.npc_reach()
	TEST_ASSERT(!length(floor.npc_points_in_reach(reach, list(point))), "A sale point behind a Members door is in a visitor's reach")
	TEST_ASSERT(!reach[floor_tile(floor, door_dx, 6)], "A visitor's route goes through a Members door")
	TEST_ASSERT(reach[floor_tile(floor, door_dx, 4)], "A visitor's route does not reach the near side of the door")

	// A door that wants an ID is no way through either
	qdel(door.GetComponent(/datum/component/outpost_door_access))
	door.req_access = list(ACCESS_COMMAND)
	reach = floor.npc_reach()
	TEST_ASSERT(!length(floor.npc_points_in_reach(reach, list(point))), "A sale point behind an ID-locked door is in a visitor's reach")

	// The search keeps to the floor's own rectangle
	for(var/turf/tile as anything in reach)
		if(!floor.contains_turf(tile))
			TEST_FAIL("A visitor's route left the floor at [tile.x],[tile.y]")
			break

/// The board's rows: every kind by the contract, long names cut, nothing private shown
/datum/unit_test/voidcrew_outpost_floors/public/directory

/datum/unit_test/voidcrew_outpost_floors/public/directory/Run()
	var/obj/structure/overmap/trader_outpost/outpost = test_outpost()
	var/datum/outpost_floor/open_floor = test_floor(outpost, 1, with_host = TRUE)
	var/datum/outpost_floor/invited_floor = test_floor(outpost, 2, with_host = TRUE)
	var/datum/outpost_floor/private_floor = test_floor(outpost, 3, with_host = TRUE)
	var/datum/outpost_floor/vacant_floor = test_floor(outpost, 4)
	var/datum/outpost_floor/tenant_floor = test_floor(outpost, 5)
	if(!open_floor || !invited_floor || !private_floor || !vacant_floor || !tenant_floor)
		return
	open_floor.entry_policy = "open" // OUTPOST_FLOOR_ENTRY_OPEN
	open_floor.floor_name = "WWWWWWWWWWWWWWWWWWWWWWWWWWWWWW"
	open_floor.board_line = "Fresh noodles, cold drinks."
	invited_floor.entry_policy = "invited" // OUTPOST_FLOOR_ENTRY_INVITED
	invited_floor.floor_name = "The Back Room"
	invited_floor.board_line = "Members only, sorry."
	private_floor.floor_name = "Secret Workshop"
	vacant_floor.state = "vacant" // OUTPOST_FLOOR_STATE_VACANT
	tenant_floor.state = "tenant" // OUTPOST_FLOOR_STATE_TENANT
	tenant_floor.tenant_name = "Halvorsen Customs Brokers"

	var/obj/machinery/outpost_directory/board = allocate(/obj/machinery/outpost_directory, run_loc_floor_bottom_left)
	board.outpost_ref = WEAKREF(outpost)
	var/list/rows = board.directory_rows()
	TEST_ASSERT_EQUAL(length(rows), 5, "The board does not list every floor")
	if(length(rows) != 5)
		return
	for(var/number in 1 to 5)
		var/list/row = rows[number]
		TEST_ASSERT_EQUAL(row["number"], number, "The board's rows are out of floor order")

	var/list/open_row = rows[1]
	TEST_ASSERT_EQUAL(open_row["kind"], "open", "An Open floor is not listed as open")
	TEST_ASSERT(length_char(open_row["name"]) <= 24, "A floor's name runs past OUTPOST_FLOOR_NAME_MAX on the board")
	TEST_ASSERT_EQUAL(open_row["line"], "Fresh noodles, cold drinks.", "An Open floor's line is not on the board")
	TEST_ASSERT_EQUAL(open_row["accent"], open_floor.accent_colour(), "An Open floor's colour is not its accent")
	TEST_ASSERT(islist(open_row["offers"]), "An Open floor's offers are not a list")

	var/list/invited_row = rows[2]
	TEST_ASSERT_EQUAL(invited_row["kind"], "invited", "An Invited floor is not listed as by invitation")
	TEST_ASSERT_EQUAL(invited_row["name"], "The Back Room", "An Invited floor's name is not on the board")
	TEST_ASSERT_NULL(invited_row["line"], "An Invited floor's line is on the board")
	TEST_ASSERT_EQUAL(length(invited_row["offers"]), 0, "An Invited floor lists what it offers")
	TEST_ASSERT(!invited_row["busy"], "An Invited floor reads Busy")

	var/list/private_row = rows[3]
	TEST_ASSERT_EQUAL(private_row["kind"], "private", "A Crew only floor is not listed as private")
	TEST_ASSERT_NULL(private_row["name"], "A private floor's name is on the board")
	TEST_ASSERT_NULL(private_row["crew"], "A private floor's crew is on the board")
	TEST_ASSERT_NULL(private_row["accent"], "A private floor's colour is on the board")

	var/list/vacant_row = rows[4]
	TEST_ASSERT_EQUAL(vacant_row["kind"], "vacant", "A given-up floor is not listed as vacant")
	TEST_ASSERT_NULL(vacant_row["name"], "A vacant floor has a name on the board")

	var/list/tenant_row = rows[5]
	TEST_ASSERT_EQUAL(tenant_row["kind"], "tenant", "A tenant's floor is not listed as the tenant's")
	TEST_ASSERT_EQUAL(tenant_row["name"], "Halvorsen Customs Brokers", "A tenant's business is not on the board")

	var/list/data = board.ui_data(null)
	TEST_ASSERT_EQUAL(length(data["rows"]), 5, "The board's window does not list every floor")

/// The fallback board hangs on the same wall as the lift panel, off the lift's own tiles where it can
/datum/unit_test/voidcrew_outpost_floors/public/directory_spot

/datum/unit_test/voidcrew_outpost_floors/public/directory_spot/Run()
	var/obj/structure/overmap/trader_outpost/outpost = test_outpost()
	var/datum/outpost_floor/floor = test_floor(outpost, 1)
	if(!floor)
		return
	// The middle of the test floor's alcove, its panel on the south hull
	var/turf/panel_turf = floor.alcove_turfs[2]
	var/turf/spot = directory_spot_beside(panel_turf, SOUTH, floor.alcove_turfs)
	TEST_ASSERT_NOTNULL(spot, "No spot for the board beside the lift panel")
	if(!spot)
		return
	TEST_ASSERT(!(spot in floor.alcove_turfs), "The board hangs in the lift alcove when a wall beside it is free")
	TEST_ASSERT(isclosedturf(get_step(spot, SOUTH)), "The board does not hang on a wall")
	TEST_ASSERT_EQUAL(spot.y, panel_turf.y, "The board is not along the panel's wall")

/// A patron really eats and drinks what they bought, through tg's own bite and gulp, and leaves the empty
/datum/unit_test/voidcrew_outpost_floors/public/patron

/datum/unit_test/voidcrew_outpost_floors/public/patron/Run()
	var/turf/here = run_loc_floor_bottom_left
	var/mob/living/carbon/human/npc/ambient_npc/floor_customer/patron = allocate(/mob/living/carbon/human/npc/ambient_npc/floor_customer, here)
	var/obj/item/food/donut/plain/donut = allocate(/obj/item/food/donut/plain, here)
	patron.took(donut, TRUE)
	TEST_ASSERT(patron.is_holding(donut), "A patron is not holding what they bought")
	TEST_ASSERT_EQUAL(patron.visit_stage, "eating", "Food did not make a customer a patron")
	var/before = donut.reagents.total_volume
	TEST_ASSERT(patron.take_bite(), "A patron could not take a bite of a donut")
	TEST_ASSERT(QDELETED(donut) || donut.reagents.total_volume < before, "A patron's bite took nothing from the food")
	// Eaten up
	for(var/bite in 1 to 20)
		if(!patron.take_bite())
			break
	TEST_ASSERT(QDELETED(donut), "A patron did not finish a donut")

	// A can is opened by hand, then drunk from
	var/obj/item/reagent_containers/cup/soda_cans/cola/can = allocate(/obj/item/reagent_containers/cup/soda_cans/cola, here)
	can.fizziness = 0
	patron.took(can, TRUE)
	TEST_ASSERT_EQUAL(patron.visit_stage, "eating", "A drink did not make a customer a patron")
	var/full = can.reagents.total_volume
	TEST_ASSERT(patron.take_bite(), "A patron could not drink from a can")
	TEST_ASSERT(can.spillable, "A patron drank from a can without opening it")
	TEST_ASSERT(can.reagents.total_volume < full, "A patron's gulp took nothing from the can")
	for(var/gulp in 1 to 30)
		if(!patron.take_bite())
			break
	TEST_ASSERT_EQUAL(can.reagents.total_volume, 0, "A patron did not finish a can")

	// The empty goes on the table beside them
	var/obj/structure/table/table = allocate(/obj/structure/table, get_step(here, EAST))
	patron.set_down_empties(table)
	TEST_ASSERT_EQUAL(can.loc, table.loc, "A patron did not leave the empty can on the table")

	// Something that is not food stays theirs, and a customer with it is no patron
	var/obj/item/pen/pen = allocate(/obj/item/pen, here)
	patron.took(pen, FALSE)
	TEST_ASSERT_EQUAL(patron.visit_stage, "done", "A customer who bought a pen sat down to eat it")
	patron.set_down_empties(table)
	TEST_ASSERT(patron.is_holding(pen), "A customer left what they bought on the table")
