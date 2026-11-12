/**
 * Outpost floors (voidcrew/modules/trade_floors/): tests of package P1.
 * Owner: P1. Subtype /datum/unit_test/voidcrew_outpost_floors and use the helpers in
 * voidcrew_outpost_floors_helpers.dm (P0, frozen). Fork defines are included after the tests: write the literal
 * value with a comment naming the define. Pin other packages' outputs directly and never wait for an AI walk.
 *
 * The shell maps are P7's and come later, so these tests load a shell built in code to the contract in
 * trade_floors/floor_shell.dm. Everything after the load (the link, the host, the lease) is the real thing.
 */

// ===== FIXTURES =====

/// A floor's shell built in code: hull, deck, a 9 by 5 landing at the south wall and every fixture the link reads
/datum/map_template/outpost_floor/unit_test
	name = "Outpost Floor (unit test)"
	width = 46 // OUTPOST_FLOOR_WIDTH
	height = 40 // OUTPOST_FLOOR_HEIGHT

/datum/map_template/outpost_floor/unit_test/load(turf/corner, centered = FALSE)
	if(!corner)
		return FALSE
	var/west = corner.x
	var/south = corner.y
	var/z = corner.z
	var/east = west + width - 1
	var/north = south + height - 1
	var/area/voidcrew/player_outpost/floor/shell_area = new
	for(var/turf/tile as anything in block(west, south, z, east, north, z))
		var/dx = tile.x - west
		var/dy = tile.y - south
		var/hull = (tile.x == west || tile.x == east || tile.y == south || tile.y == north)
		// The landing's own walls: columns 18 and 26 and row 5, with the front door's gap at 22, 5
		if(dy >= 1 && dy <= 5 && (dx == 18 || dx == 26))
			hull = TRUE
		if(dy == 5 && dx >= 18 && dx <= 26 && dx != 22)
			hull = TRUE
		tile.ChangeTurf(hull ? /turf/closed/wall/outpost_floor_hull : /turf/open/floor/plating/outpost_deck)
		tile.change_area(tile.loc, shell_area)
	shell_area.reg_in_areas_in_z()
	// A mapped tile in the foyer: it must come up to bare deck, never to what tg puts under iron
	var/turf/foyer_tile = locate(west + 20, south + 4, z)
	foyer_tile.ChangeTurf(/turf/open/floor/iron)
	for(var/turf/alcove_tile as anything in block(west + 21, south + 1, z, west + 23, south + 3, z))
		new /obj/effect/landmark/outpost_floor_alcove(alcove_tile)
	new /obj/machinery/outpost_elevator(locate(west + 20, south + 2, z))
	new /obj/machinery/door/airlock/outpost_floor_front(locate(west + 22, south + 5, z))
	for(var/turf/goods_tile as anything in block(west + 28, south + 1, z, west + 31, south + 1, z))
		new /obj/effect/landmark/outpost_floor_goods(goods_tile)
	new /obj/structure/outpost_goods_lift(locate(west + 28, south + 1, z))
	new /obj/effect/landmark/player_outpost_arrival(locate(west + 22, south + 8, z))
	new /obj/machinery/computer/player_outpost_management(locate(west + 10, south + 2, z))
	new /obj/machinery/computer/camera_advanced/base_construction/ship/outpost(locate(west + 11, south + 2, z))
	new /obj/machinery/computer/voidcrew_cargo(locate(west + 12, south + 2, z))
	new /obj/machinery/computer/bank_machine(locate(west + 13, south + 2, z))
	new /obj/machinery/cryopod(locate(west + 14, south + 2, z))
	new /obj/machinery/ore_silo(locate(west + 15, south + 2, z))
	new /obj/machinery/power/outpost_mains(locate(west + 16, south + 2, z))
	return TRUE

/// A shell whose load is refused, after the ground is reserved
/datum/map_template/outpost_floor/unit_test/refused/load(turf/corner, centered = FALSE)
	return FALSE

/// A shell that takes a while to load, so a second buyer can come to the counter meanwhile
/datum/map_template/outpost_floor/unit_test/slow/load(turf/corner, centered = FALSE)
	sleep(2 SECONDS)
	return ..()

/// The lease as the shelf sells it, paid from an account the test holds instead of a ship's
/datum/shop_sku/outpost_floor/unit_test
	var/datum/bank_account/test_account

/datum/shop_sku/outpost_floor/unit_test/get_account(mob/living/user, obj/structure/overmap/ship/crew_ship = get_crew_ship(user))
	return test_account

/datum/shop_sku/outpost_floor/unit_test/Destroy()
	test_account = null
	return ..()

/// Parent of P1's tests: players with a key and a mind, a crew, a trader outpost with its six floors and the lease on its shelf
/datum/unit_test/voidcrew_outpost_floors/core
	abstract_type = /datum/unit_test/voidcrew_outpost_floors/core
	/// Everyone given a key, to take it back
	var/list/mob/living/keyed = list()
	var/datum/bank_account/purse

/datum/unit_test/voidcrew_outpost_floors/core/Destroy()
	for(var/mob/living/player as anything in keyed)
		if(!QDELETED(player))
			player.key = null
	keyed.Cut()
	QDEL_NULL(purse)
	return ..()

/// A player: a body with a key and a mind, standing at `where`
/datum/unit_test/voidcrew_outpost_floors/core/proc/test_player(key, turf/where)
	var/mob/living/carbon/human/player = test_person(where || run_loc_floor_bottom_left)
	player.key = key
	player.mind_initialize()
	keyed += player
	return player

/// A ship crew of `members`, with a ship named `ship_name`
/datum/unit_test/voidcrew_outpost_floors/core/proc/test_crew(ship_name, list/mob/living/members)
	var/obj/structure/overmap/ship/ship = allocate(/obj/structure/overmap/ship)
	var/datum/team/voidcrew/crew = allocate(/datum/team/voidcrew)
	ship.name = ship_name
	ship.ship_team = crew
	crew.ship = ship
	for(var/mob/living/member as anything in members)
		crew.add_member(member.mind)
	return ship

/// A trader outpost with its six floors made, each loading the shell built in code (or `shell_type`)
/datum/unit_test/voidcrew_outpost_floors/core/proc/test_building(shell_type = /datum/map_template/outpost_floor/unit_test)
	var/obj/structure/overmap/trader_outpost/outpost = test_outpost()
	outpost.make_floors()
	for(var/datum/outpost_floor/floor in outpost.floors)
		floor.shell_type = shell_type
	return outpost

/// The lease on `outpost`'s shelf, paid from the test's purse, which starts with `credits`
/datum/unit_test/voidcrew_outpost_floors/core/proc/test_lease(obj/structure/overmap/trader_outpost/outpost, credits = 10000)
	if(!purse)
		purse = new("Outpost floors unit test", player_account = FALSE)
		purse.adjust_money(credits, "Outpost floors unit test")
	var/datum/shop_sku/outpost_floor/unit_test/lease = new
	lease.shop = outpost.shop
	lease.test_account = purse
	outpost.shop.skus += lease
	return lease

/// Puts `amount` trade vouchers in `player`'s hands
/datum/unit_test/voidcrew_outpost_floors/core/proc/give_vouchers(mob/living/player, amount = 2)
	var/obj/item/stack/trade_voucher/chits = new(player.drop_location(), amount, FALSE)
	player.put_in_hands(chits)
	return chits

/// Lets floor `number` of `outpost` to `buyer` without the counter, as the lease does once it is paid. The floor, or null and a failure.
/datum/unit_test/voidcrew_outpost_floors/core/proc/let_floor(obj/structure/overmap/trader_outpost/outpost, mob/living/buyer, number = 1)
	var/datum/outpost_floor/floor = outpost.floors[number]
	floor.state = "letting" // OUTPOST_FLOOR_STATE_LETTING
	floor.shell_lessee = WEAKREF(buyer.mind)
	if(!floor.let_to(buyer))
		TEST_FAIL("Floor [number] could not be let to its buyer")
		return null
	return floor

/// The tile of a shell-loaded floor at `dx`, `dy` from its bottom left corner
/datum/unit_test/voidcrew_outpost_floors/core/proc/shell_tile(datum/outpost_floor/floor, dx, dy)
	return locate(floor.bounds[1] + dx, floor.bounds[2] + dy, floor.bounds[5])

// ===== THE SIX FLOORS =====

/// An outpost makes its six floors once, unlet and with no ground, and sells the lowest first
/datum/unit_test/voidcrew_outpost_floors/core/make_floors

/datum/unit_test/voidcrew_outpost_floors/core/make_floors/Run()
	var/obj/structure/overmap/trader_outpost/outpost = test_outpost()
	TEST_ASSERT_EQUAL(length(outpost.floors), 0, "A trader outpost has floors before it makes them")
	// Asking for a floor to let makes them
	var/datum/outpost_floor/first = outpost.floor_to_let()
	TEST_ASSERT_EQUAL(length(outpost.floors), 6, "A trader outpost did not make OUTPOST_FLOORS_PER_OUTPOST floors")
	TEST_ASSERT_EQUAL(outpost.count_floors_to_let(), 6, "A new outpost does not have six floors to let")
	for(var/number in 1 to 6)
		var/datum/outpost_floor/floor = outpost.floors[number]
		TEST_ASSERT_NOTNULL(floor, "Floor [number] was not made")
		TEST_ASSERT_EQUAL(floor.number, number, "Floor [number] has the wrong number")
		TEST_ASSERT_EQUAL(floor.outpost, outpost, "Floor [number] does not know its outpost")
		TEST_ASSERT_EQUAL(floor.state, "tenant", "A new floor is not let to a tenant") // OUTPOST_FLOOR_STATE_TENANT
		TEST_ASSERT_NULL(floor.bounds, "A floor nobody has bought has ground")
		TEST_ASSERT_NULL(floor.host, "A floor nobody has bought has a host")
		TEST_ASSERT_EQUAL(outpost.floor_by_id(100 + number), floor, "Floor [number] is not found by its lift id") // OUTPOST_FLOOR_ID_BASE
	TEST_ASSERT_EQUAL(first, outpost.floors[1], "The first floor to let is not floor 1")
	TEST_ASSERT_EQUAL(length(GLOB.outpost_floors_on_ground & outpost.floors), 0, "An unlet floor is in the list of floors with ground")
	outpost.make_floors()
	TEST_ASSERT_EQUAL(outpost.floors[1], first, "Making the floors twice replaced one")
	first.state = "owned" // OUTPOST_FLOOR_STATE_OWNED
	TEST_ASSERT_EQUAL(outpost.floor_to_let(), outpost.floors[2], "The next floor to let is not the lowest unlet one")
	var/datum/outpost_floor/given_up = outpost.floors[2]
	given_up.state = "vacant" // OUTPOST_FLOOR_STATE_VACANT
	TEST_ASSERT_EQUAL(outpost.floor_to_let(), outpost.floors[3], "A floor its owner gave up is sold at the counter")
	TEST_ASSERT_EQUAL(outpost.count_floors_to_let(), 4, "The count of floors to let includes one that is owned or given up")
	// A deleted floor stays gone
	qdel(outpost.floors[3])
	outpost.make_floors()
	TEST_ASSERT_NULL(outpost.floors[3], "A deleted floor was made again")
	TEST_ASSERT_EQUAL(outpost.floor_to_let(), outpost.floors[4], "The outpost does not skip a deleted floor")

// ===== BUYING =====

/// The lease at the counter: charged, the floor reserved, loaded and linked, the buyer its owner and their crew its people
/datum/unit_test/voidcrew_outpost_floors/core/buy

/datum/unit_test/voidcrew_outpost_floors/core/buy/Run()
	var/obj/structure/overmap/trader_outpost/outpost = test_building()
	var/datum/shop_sku/outpost_floor/unit_test/lease = test_lease(outpost)
	var/mob/living/buyer = test_player("floorscorebuyer")
	var/mob/living/crewmate = test_player("floorscorecrew")
	var/mob/living/stranger = test_player("floorscorestranger")
	test_crew("The Unreasonably Long Marigold", list(buyer, crewmate))
	test_crew("Sable", list(stranger))
	give_vouchers(buyer, 3)

	TEST_ASSERT_NULL(lease.get_denial_reason(buyer), "The lease is refused to someone who can pay for a vacant floor")
	TEST_ASSERT_EQUAL(lease.stock, 6, "The lease's stock is not the floors left to let")
	TEST_ASSERT(lease.try_purchase(buyer, null), "A paid lease did not go through")

	var/datum/outpost_floor/floor = outpost.floors[1]
	var/obj/structure/overmap/dynamic/player_outpost/floor/host = floor.host
	TEST_ASSERT_EQUAL(floor.state, "owned", "A bought floor is not owned") // OUTPOST_FLOOR_STATE_OWNED
	TEST_ASSERT_NOTNULL(host, "A bought floor has no host")
	TEST_ASSERT_EQUAL(purse.account_balance, 4000, "The lease did not cost OUTPOST_FLOOR_COST_CREDITS")
	TEST_ASSERT_EQUAL(count_trade_vouchers(buyer), 1, "The lease did not cost OUTPOST_FLOOR_COST_VOUCHERS")
	TEST_ASSERT_EQUAL(lease.stock, 5, "The lease's stock did not follow the sale")
	TEST_ASSERT_NULL(floor.shell_lessee, "A sold floor is still marked as being let")
	TEST_ASSERT(host.is_owner(buyer) && host.can_manage(buyer), "The buyer is not the floor's owner")
	TEST_ASSERT(floor.is_member(buyer) && floor.is_member(crewmate), "The buyer's crew are not the floor's people")
	TEST_ASSERT(host.is_resident(crewmate) && host.can_build(crewmate), "The buyer's crew are not residents who may build")
	TEST_ASSERT(!host.can_manage(crewmate) && !host.can_spend(crewmate), "The buyer's crew got the console or the treasury")
	TEST_ASSERT(!floor.is_member(stranger), "A stranger is one of the floor's people")
	TEST_ASSERT_EQUAL(floor.floor_name, "The Unreasonably Long Ma", "A floor does not start with its buyer's ship name cut to OUTPOST_FLOOR_NAME_MAX")
	TEST_ASSERT_EQUAL(host.name, floor.floor_name, "The host is not named for its floor")
	TEST_ASSERT_EQUAL(floor.crew_name(), "The Unreasonably Long Marigold", "The floor's crew is not named for the owner's ship")
	TEST_ASSERT_EQUAL(floor.entry_policy, "crew", "A new floor is not crew only") // OUTPOST_FLOOR_ENTRY_CREW
	TEST_ASSERT_NULL(host.loc, "A floor's host is on the map")
	TEST_ASSERT_NOTNULL(locate(/obj/item/paper) in buyer.held_items, "No lease slip was handed over")
	TEST_ASSERT_EQUAL(lease.get_denial_reason(buyer), "You already hold a floor.", "The lease is offered again to someone who holds a floor")

/// A floor that cannot be loaded pays its buyer back exactly, credits and vouchers, and is for sale again (A29)
/datum/unit_test/voidcrew_outpost_floors/core/refund

/datum/unit_test/voidcrew_outpost_floors/core/refund/Run()
	var/obj/structure/overmap/trader_outpost/outpost = test_building(/datum/map_template/outpost_floor/unit_test/refused)
	var/datum/shop_sku/outpost_floor/unit_test/lease = test_lease(outpost)
	var/mob/living/buyer = test_player("floorscorerefund")
	give_vouchers(buyer, 2)
	var/datum/outpost_floor/floor = outpost.floors[1]

	TEST_ASSERT(!lease.try_purchase(buyer, null), "A lease whose floor could not be loaded went through")
	TEST_ASSERT_EQUAL(purse.account_balance, 10000, "A failed lease kept the buyer's credits")
	TEST_ASSERT_EQUAL(count_trade_vouchers(buyer), 2, "A failed lease kept the buyer's vouchers")
	TEST_ASSERT_EQUAL(floor.state, "tenant", "A floor that could not be loaded is not for sale again") // OUTPOST_FLOOR_STATE_TENANT
	TEST_ASSERT_NULL(floor.host, "A failed lease left a host")
	TEST_ASSERT_NULL(floor.reservation, "A failed lease kept the floor's ground")
	TEST_ASSERT_NULL(floor.bounds, "A failed lease left the floor with bounds")
	TEST_ASSERT(!(floor in GLOB.outpost_floors_on_ground), "A failed lease left the floor in the list of floors with ground")
	TEST_ASSERT_NULL(floor.shell_lessee, "A failed lease left the floor marked for its buyer")
	TEST_ASSERT_NULL(floor_holder_denial(buyer), "A failed lease counts as holding a floor")
	TEST_ASSERT_EQUAL(lease.sync_stock(), 6, "A failed lease took a floor off the shelf")
	for(var/obj/structure/overmap/dynamic/player_outpost/floor/left_over in GLOB.player_outposts)
		TEST_ASSERT(left_over.floor != floor, "A failed lease left a floor host in the world")

	// Without the price nothing is marked or reserved at all
	purse.adjust_money(-9000, "Outpost floors unit test")
	TEST_ASSERT(!lease.try_purchase(buyer, null), "A lease went through without the credits")
	TEST_ASSERT_EQUAL(floor.state, "tenant", "A refused sale left its floor marked") // OUTPOST_FLOOR_STATE_TENANT
	TEST_ASSERT_EQUAL(count_trade_vouchers(buyer), 2, "A refused sale took vouchers")
	purse.adjust_money(9000, "Outpost floors unit test")

	// The same floor sells once its shell loads
	floor.shell_type = /datum/map_template/outpost_floor/unit_test
	TEST_ASSERT(lease.try_purchase(buyer, null), "A floor that failed once cannot be sold")
	TEST_ASSERT_EQUAL(floor.state, "owned", "The floor that failed once is not its buyer's") // OUTPOST_FLOOR_STATE_OWNED
	TEST_ASSERT_EQUAL(purse.account_balance, 4000, "The second attempt was not charged once")

/// Two buyers for the last floor: the floor is marked before anything yields, so the second is turned away unpaid (A29)
/datum/unit_test/voidcrew_outpost_floors/core/two_buyers

/datum/unit_test/voidcrew_outpost_floors/core/two_buyers/Run()
	var/obj/structure/overmap/trader_outpost/outpost = test_building(/datum/map_template/outpost_floor/unit_test/slow)
	var/datum/shop_sku/outpost_floor/unit_test/lease = test_lease(outpost, 20000)
	var/mob/living/first = test_player("floorscorefirst")
	var/mob/living/second = test_player("floorscoresecond")
	give_vouchers(first, 2)
	give_vouchers(second, 2)
	// One floor left
	for(var/number in 2 to 6)
		var/datum/outpost_floor/taken = outpost.floors[number]
		taken.state = "owned" // OUTPOST_FLOOR_STATE_OWNED
	var/datum/outpost_floor/last = outpost.floors[1]

	INVOKE_ASYNC(lease, TYPE_PROC_REF(/datum/shop_sku, try_purchase), first, null)
	TEST_ASSERT_EQUAL(last.state, "letting", "A sale that is still loading has not marked its floor") // OUTPOST_FLOOR_STATE_LETTING
	TEST_ASSERT_EQUAL(purse.account_balance, 14000, "The first buyer was not charged before the load")
	TEST_ASSERT_EQUAL(lease.get_denial_reason(second), "No vacancies.", "A floor being sold is offered to a second buyer")
	TEST_ASSERT(!lease.try_purchase(second, null), "Two buyers bought one floor")
	TEST_ASSERT_EQUAL(purse.account_balance, 14000, "The second buyer was charged for a floor already being sold")
	TEST_ASSERT_EQUAL(count_trade_vouchers(second), 2, "The second buyer lost vouchers for a floor already being sold")
	TEST_ASSERT_EQUAL(floor_holder_denial(first), "You already hold a floor.", "A buyer whose floor is still loading may buy another (A24)")

	var/deadline = world.time + 30 SECONDS
	UNTIL(last.state != "letting" || world.time > deadline) // OUTPOST_FLOOR_STATE_LETTING
	TEST_ASSERT_EQUAL(last.state, "owned", "The first buyer's floor never finished loading") // OUTPOST_FLOOR_STATE_OWNED
	TEST_ASSERT(last.host?.is_owner(first), "The last floor is not the first buyer's")
	TEST_ASSERT_EQUAL(purse.account_balance, 14000, "The last floor was paid for more than once")
	TEST_ASSERT_EQUAL(lease.get_denial_reason(second), "No vacancies.", "A sold-out outpost offers a lease")

/// One floor a crew: the owner and everyone on a ship crew with them are refused another, at any outpost (A24)
/datum/unit_test/voidcrew_outpost_floors/core/one_a_crew

/datum/unit_test/voidcrew_outpost_floors/core/one_a_crew/Run()
	var/obj/structure/overmap/trader_outpost/outpost = test_building()
	var/obj/structure/overmap/trader_outpost/elsewhere = test_building()
	var/datum/shop_sku/outpost_floor/unit_test/lease = test_lease(elsewhere)
	var/mob/living/owner = test_player("floorscoreowner")
	var/mob/living/crewmate = test_player("floorscoremate")
	var/mob/living/stranger = test_player("floorscoreother")
	test_crew("Marigold", list(owner, crewmate))
	test_crew("Sable", list(stranger))
	give_vouchers(crewmate, 2)

	TEST_ASSERT_NULL(floor_holder_denial(owner), "Someone with no floor is refused one")
	TEST_ASSERT_NULL(floor_holder_denial(null), "Nobody is refused a floor with a reason")

	// Being bought this moment already counts, for the buyer and their crew
	var/datum/outpost_floor/floor = outpost.floors[1]
	floor.state = "letting" // OUTPOST_FLOOR_STATE_LETTING
	floor.shell_lessee = WEAKREF(owner.mind)
	TEST_ASSERT_EQUAL(floor_holder_denial(owner), "You already hold a floor.", "A buyer mid-sale may buy a second floor")
	TEST_ASSERT_EQUAL(floor_holder_denial(crewmate), "You already hold a floor.", "A crewmate of a buyer mid-sale may buy a floor")
	TEST_ASSERT_NULL(floor_holder_denial(stranger), "A stranger is refused because someone else is buying")

	TEST_ASSERT(floor.let_to(owner), "The floor could not be let")
	TEST_ASSERT_EQUAL(floor_holder_denial(owner), "You already hold a floor.", "An owner may hold two floors")
	TEST_ASSERT_EQUAL(floor_holder_denial(crewmate), "You already hold a floor.", "An owner's crewmate may hold a floor of their own")
	TEST_ASSERT_NULL(floor_holder_denial(stranger), "Another crew is refused a floor")
	// The floor changing hands is not counted against the one taking it (takeover, a gift)
	TEST_ASSERT_NULL(floor_holder_denial(crewmate, floor), "A crewmate cannot take over their own crew's floor")

	// At another outpost's counter too, and nothing is charged or marked
	TEST_ASSERT_EQUAL(lease.get_denial_reason(crewmate), "You already hold a floor.", "Another outpost offers a second floor to the same crew")
	TEST_ASSERT(!lease.try_purchase(crewmate, null), "A crew bought a second floor at another outpost")
	TEST_ASSERT_EQUAL(purse.account_balance, 10000, "A refused second floor was charged")
	TEST_ASSERT_EQUAL(count_trade_vouchers(crewmate), 2, "A refused second floor took vouchers")
	TEST_ASSERT_EQUAL(elsewhere.count_floors_to_let(), 6, "A refused second floor was marked")

	// A floor with no owner is nobody's
	floor.host.founder_ckey = null
	TEST_ASSERT(!floor.is_member(owner), "A floor with no owner has people")
	TEST_ASSERT_EQUAL(floor.crew_name(), "", "A floor with no owner has a crew's name")
	TEST_ASSERT_NULL(floor_holder_denial(owner), "A floor its owner no longer holds still counts against them")

// ===== THE SHELL =====

/// A loaded shell is a working outpost: `loaded`, the home bundle, the lift, the landing, the goods lift and the front door (A61)
/datum/unit_test/voidcrew_outpost_floors/core/shell_loaded

/datum/unit_test/voidcrew_outpost_floors/core/shell_loaded/Run()
	var/obj/structure/overmap/trader_outpost/outpost = test_building()
	var/mob/living/owner = test_player("floorscoreshell")
	var/mob/living/stranger = test_player("floorscoreshellother")
	var/datum/outpost_floor/floor = let_floor(outpost, owner, 2)
	if(!floor)
		return
	var/obj/structure/overmap/dynamic/player_outpost/floor/host = floor.host
	TEST_ASSERT(host.loaded && !host.loading, "A floor whose shell loaded is not loaded")
	TEST_ASSERT(host.home_bundle_installed, "A loaded shell did not install the home bundle (A61)")
	TEST_ASSERT_NOTNULL(host.treasury, "A floor has no treasury")
	TEST_ASSERT(istype(host.freight, /datum/voidcrew_cargo_shuttle/outpost/floor), "A floor's freight is the outpost ferry, not the goods lift")
	TEST_ASSERT_NOTNULL(host.management_console, "The management console is not linked")
	TEST_ASSERT_EQUAL(host.management_console.outpost, host, "The management console serves another outpost")
	TEST_ASSERT_NOTNULL(host.construction_console, "The construction console is not linked")
	TEST_ASSERT_NOTNULL(host.arrival_turf, "The floor has no arrival point")
	TEST_ASSERT(istype(host.outpost_area, /area/voidcrew/player_outpost/floor), "The floor's area is not linked")
	TEST_ASSERT_EQUAL(length(host.resident_pods), 1, "The shell's cryopod is not a resident pod")
	TEST_ASSERT_EQUAL(host.upgrade_level_z(), floor.bounds[5], "Rooms are not placed on the floor's own level")
	TEST_ASSERT_NULL(host.mapzone, "A floor has a level of its own")
	TEST_ASSERT_EQUAL(floor.bounds[3] - floor.bounds[1] + 1, 46, "The floor is not OUTPOST_FLOOR_WIDTH wide")
	TEST_ASSERT_EQUAL(floor.bounds[4] - floor.bounds[2] + 1, 40, "The floor is not OUTPOST_FLOOR_HEIGHT high")
	TEST_ASSERT(floor in GLOB.outpost_floors_on_ground, "A let floor is not in the list of floors with ground")

	// The lift
	var/obj/machinery/outpost_elevator/panel = floor.panel
	TEST_ASSERT_NOTNULL(panel, "The floor's lift panel is not linked")
	TEST_ASSERT_EQUAL(panel.floor, floor, "The lift panel does not know its floor")
	TEST_ASSERT_EQUAL(panel.outpost, outpost, "The lift panel serves the host, not the trader outpost's lift")
	TEST_ASSERT_EQUAL(panel.get_current_floor(), 102, "The lift panel does not read floor 2") // OUTPOST_FLOOR_ID_BASE + 2
	TEST_ASSERT_EQUAL(length(floor.alcove_turfs), 9, "The lift alcove is not its nine tiles")
	TEST_ASSERT_EQUAL(floor.alcove_turfs[1], shell_tile(floor, 21, 1), "The alcove is not collected from its bottom left tile")
	TEST_ASSERT_EQUAL(floor.alcove_turfs[9], shell_tile(floor, 23, 3), "The alcove is not collected row by row")
	TEST_ASSERT_NULL(locate(/obj/effect/landmark/outpost_floor_alcove) in shell_tile(floor, 22, 2), "An alcove landmark was left behind")

	// The landing: nine by five inside the south hull, centred on the alcove (OUTPOST_FLOOR_LANDING_WIDTH, _HEIGHT)
	TEST_ASSERT_EQUAL(floor.landing_bounds[1], floor.bounds[1] + 18, "The landing does not start four tiles west of the alcove's middle")
	TEST_ASSERT_EQUAL(floor.landing_bounds[3], floor.bounds[1] + 26, "The landing is not nine tiles wide")
	TEST_ASSERT_EQUAL(floor.landing_bounds[2], floor.bounds[2] + 1, "The landing does not start inside the south hull")
	TEST_ASSERT_EQUAL(floor.landing_bounds[4], floor.bounds[2] + 5, "The landing is not five tiles deep")
	TEST_ASSERT_EQUAL(length(floor.goods_turfs), 4, "The goods lift is not its four tiles") // OUTPOST_FLOOR_GOODS_CRATES

	// What a crew may build on: the deck, less the hull, the landing and the goods lift (A5)
	TEST_ASSERT(host.is_turf_buildable(shell_tile(floor, 5, 20)), "The deck is not buildable")
	TEST_ASSERT(host.is_turf_buildable(shell_tile(floor, 22, 6)), "The deck outside the front door is not buildable")
	TEST_ASSERT(host.is_turf_buildable(shell_tile(floor, 17, 1)), "The deck beside the landing is not buildable")
	TEST_ASSERT(host.is_turf_buildable(shell_tile(floor, 44, 38)), "The deck's far corner is not buildable")
	for(var/list/spot as anything in list(list(0, 0), list(45, 39), list(0, 20), list(22, 39), list(22, 2), list(19, 4), list(18, 3), list(22, 5), list(26, 5), list(28, 1), list(31, 1)))
		TEST_ASSERT(!host.is_turf_buildable(shell_tile(floor, spot[1], spot[2])), "The hull, the landing or the goods lift is buildable at [spot[1]],[spot[2]] (A5)")
	TEST_ASSERT(!host.is_turf_buildable(run_loc_floor_bottom_left), "A tile off the floor is buildable")
	TEST_ASSERT_EQUAL(get_outpost_from_atom(shell_tile(floor, 22, 2)), host, "A service on the landing does not find its floor")

	// Everything the shell placed is outpost property; the crew's own wiring is not
	for(var/obj/fixture as anything in list(host.management_console, host.construction_console, panel, locate(/obj/machinery/ore_silo) in shell_tile(floor, 15, 2), locate(/obj/machinery/power/outpost_mains) in shell_tile(floor, 16, 2), locate(/obj/structure/outpost_goods_lift) in shell_tile(floor, 28, 1)))
		TEST_ASSERT_NOTNULL(fixture, "A fixture of the shell is missing")
		TEST_ASSERT(HAS_TRAIT(fixture, "outpost_property"), "[fixture] is not outpost property (A12)") // TRAIT_OUTPOST_PROPERTY

	// The front door: members only, free from the deck side, and the crew's to change (spec 5.1)
	var/obj/machinery/door/airlock/outpost_floor_front/door = locate() in shell_tile(floor, 22, 5)
	TEST_ASSERT_NOTNULL(door, "The shell has no front door")
	TEST_ASSERT(HAS_TRAIT(door, "outpost_property"), "The front door is not outpost property (A5)") // TRAIT_OUTPOST_PROPERTY
	var/datum/component/outpost_door_access/lock = door.GetComponent(/datum/component/outpost_door_access)
	TEST_ASSERT_NOTNULL(lock, "The front door carries no setting")
	TEST_ASSERT_EQUAL(lock.access, "members", "The front door does not start members only") // OUTPOST_DOOR_MEMBERS
	TEST_ASSERT_EQUAL(lock.free_side, NORTH, "The front door's free side is not the deck's")
	TEST_ASSERT(!lock.admits(stranger, shell_tile(floor, 22, 4)), "The front door lets a stranger in from the foyer")
	TEST_ASSERT(lock.admits(stranger, shell_tile(floor, 22, 6)), "The front door shuts a stranger in on the deck")
	TEST_ASSERT(lock.admits(owner, shell_tile(floor, 22, 4)), "The front door refuses the floor's owner")
	TEST_ASSERT_NULL(host.door_access_fixed(door), "The crew cannot change the front door's setting")
	TEST_ASSERT_NULL(host.set_door_access(owner, door, "public"), "The owner could not open the front door to the public") // OUTPOST_DOOR_PUBLIC
	TEST_ASSERT_NULL(door.GetComponent(/datum/component/outpost_door_access), "A public front door still carries a setting")
	host.reset_door_access()
	lock = door.GetComponent(/datum/component/outpost_door_access)
	TEST_ASSERT_EQUAL(lock?.access, "members", "The front door's default is not members only") // OUTPOST_DOOR_MEMBERS

	// Nothing docks at a floor, and its notices reach nobody off it
	host.ship_act(owner, null, null, null)
	TEST_ASSERT_EQUAL(length(host.announcement_listeners(null)), 0, "A floor with no players on it has listeners")

/// A shell with no lift alcove is refused, and the sale falls through cleanly
/datum/map_template/outpost_floor/unit_test/no_lift/load(turf/corner, centered = FALSE)
	. = ..()
	for(var/turf/alcove_tile as anything in block(corner.x + 21, corner.y + 1, corner.z, corner.x + 23, corner.y + 3, corner.z))
		for(var/obj/effect/landmark/outpost_floor_alcove/mark in alcove_tile)
			qdel(mark)

/datum/unit_test/voidcrew_outpost_floors/core/shell_refused

/datum/unit_test/voidcrew_outpost_floors/core/shell_refused/Run()
	var/obj/structure/overmap/trader_outpost/outpost = test_building(/datum/map_template/outpost_floor/unit_test/no_lift)
	var/mob/living/owner = test_player("floorscorenolift")
	var/datum/outpost_floor/floor = outpost.floors[1]
	floor.state = "letting" // OUTPOST_FLOOR_STATE_LETTING
	floor.shell_lessee = WEAKREF(owner.mind)
	TEST_ASSERT(!floor.let_to(owner), "A shell with no lift alcove was let")
	TEST_ASSERT_EQUAL(floor.state, "tenant", "A refused shell left its floor off the list") // OUTPOST_FLOOR_STATE_TENANT
	TEST_ASSERT_NULL(floor.bounds, "A refused shell kept its ground")
	TEST_ASSERT_NULL(floor.host, "A refused shell kept its host")
	TEST_ASSERT_NULL(floor.panel, "A refused shell kept its lift panel")
	// A floor that is not marked is never let
	TEST_ASSERT(!floor.let_to(owner), "A floor nobody marked was let")

// ===== THE DECK =====

/// Nothing goes through the deck, and whatever is laid or built on it comes back off to bare deck (A4)
/datum/unit_test/voidcrew_outpost_floors/core/deck

/datum/unit_test/voidcrew_outpost_floors/core/deck/Run()
	var/obj/structure/overmap/trader_outpost/outpost = test_building()
	var/mob/living/carbon/human/owner = test_player("floorscoredeck")
	var/datum/outpost_floor/floor = let_floor(outpost, owner)
	if(!floor)
		return
	var/turf/open/floor/plating/outpost_deck/deck = shell_tile(floor, 6, 20)
	owner.forceMove(shell_tile(floor, 6, 21))
	TEST_ASSERT(istype(deck), "The deck is not deck")
	TEST_ASSERT_EQUAL(deck.baseturfs, /turf/open/floor/plating/outpost_deck, "The deck is not its own baseturf")

	// Scraped, blasted, burnt, eaten and taken apart
	deck.ScrapeAway()
	deck.ScrapeAway(5)
	EX_ACT(deck, EXPLODE_DEVASTATE)
	EX_ACT(deck, EXPLODE_HEAVY)
	EX_ACT(deck, EXPLODE_LIGHT)
	deck.ex_act(EXPLODE_DEVASTATE, deck)
	TEST_ASSERT(!deck.acid_act(100, 100), "Acid takes to the deck")
	deck.acid_melt()
	deck.Melt()
	deck.singularity_act()
	deck.rust_heretic_act(10)
	deck.rust_turf()
	deck.TerraformTurf(/turf/open/space)
	var/obj/item/construction/rcd/rcd = allocate(/obj/item/construction/rcd)
	rcd.mode = RCD_DECONSTRUCT
	TEST_ASSERT(!deck.rcd_act(owner, rcd, list("[RCD_DESIGN_MODE]" = RCD_DECONSTRUCT)), "An RCD takes up the deck")
	TEST_ASSERT_EQUAL(deck.type, /turf/open/floor/plating/outpost_deck, "The deck did not survive")
	TEST_ASSERT(!deck.broken && !deck.burnt, "A blast marked the deck")

	// A tile goes on it by hand and pries back off to bare deck
	var/obj/item/stack/tile/iron/tiles = allocate(/obj/item/stack/tile/iron, owner.drop_location())
	tiles.place_tile(deck, owner)
	var/turf/open/floor/tiled = shell_tile(floor, 6, 20)
	TEST_ASSERT(istype(tiled, /turf/open/floor/iron), "A floor tile does not go on the deck")
	var/obj/item/crowbar/crowbar = allocate(/obj/item/crowbar)
	tiled.pry_tile(crowbar, owner, TRUE)
	TEST_ASSERT_EQUAL(deck.type, /turf/open/floor/plating/outpost_deck, "A pried tile did not leave bare deck")

	// A blast takes the tile and stops at the deck
	deck.place_on_top(/turf/open/floor/iron)
	EX_ACT(deck, EXPLODE_DEVASTATE)
	TEST_ASSERT_EQUAL(deck.type, /turf/open/floor/plating/outpost_deck, "A blast on a tile went through the deck under it (A4)")

	// A crew wall comes down to deck however it goes
	deck.place_on_top(/turf/closed/wall)
	var/turf/closed/wall/crew_wall = deck
	crew_wall.dismantle_wall()
	TEST_ASSERT_EQUAL(deck.type, /turf/open/floor/plating/outpost_deck, "A dismantled crew wall did not leave bare deck")
	deck.place_on_top(/turf/closed/wall)
	EX_ACT(deck, EXPLODE_DEVASTATE)
	TEST_ASSERT_EQUAL(deck.type, /turf/open/floor/plating/outpost_deck, "A blasted crew wall did not leave bare deck")

	// A tile the shell map laid comes up to deck too, not to tg's plating and what is under that
	var/turf/open/floor/mapped = shell_tile(floor, 20, 4)
	TEST_ASSERT(istype(mapped, /turf/open/floor/iron), "The shell's mapped tile is missing")
	mapped.ScrapeAway()
	TEST_ASSERT_EQUAL(mapped.type, /turf/open/floor/plating/outpost_deck, "A mapped tile came up to something other than deck (A4)")
	mapped.ScrapeAway(3)
	TEST_ASSERT_EQUAL(mapped.type, /turf/open/floor/plating/outpost_deck, "Under a mapped tile's deck there is something else")

// ===== THE HULL =====

/// Every way a wall is broken, tried on the hull (A93)
/datum/unit_test/voidcrew_outpost_floors/core/hull

/datum/unit_test/voidcrew_outpost_floors/core/hull/Run()
	var/obj/structure/overmap/trader_outpost/outpost = test_outpost()
	var/datum/outpost_floor/floor = test_floor(outpost, 1)
	if(!floor)
		return
	var/turf/closed/wall/outpost_floor_hull/hull = floor_tile(floor, 0, 5)
	var/mob/living/carbon/human/vandal = test_person(floor_tile(floor, 1, 5))
	TEST_ASSERT(istype(hull), "The hull is not hull")
	TEST_ASSERT(iswallturf(hull), "The hull is not a wall: nothing will hang on it")

	var/list/routes = list()
	hull.dismantle_wall()
	routes += "taking it apart"
	hull.dismantle_wall(TRUE, TRUE)
	routes += "smashing it"
	hull.ScrapeAway()
	hull.ScrapeAway(4)
	routes += "scraping it away"
	EX_ACT(hull, EXPLODE_DEVASTATE)
	EX_ACT(hull, EXPLODE_HEAVY)
	EX_ACT(hull, EXPLODE_LIGHT)
	hull.ex_act(EXPLODE_LIGHT, hull)
	routes += "a blast"
	TEST_ASSERT(!hull.acid_act(200, 200), "Acid takes to the hull")
	hull.acid_melt()
	routes += "acid"
	hull.Melt()
	routes += "melting"
	hull.AddComponent(/datum/component/thermite, 200)
	var/datum/component/thermite/thermite = hull.GetComponent(/datum/component/thermite)
	thermite?.burn_parent(null)
	routes += "thermite"
	hull.TerraformTurf(/turf/open/space)
	routes += "terraforming"
	hull.rust_heretic_act(10)
	hull.rust_turf()
	hull.rust_turf()
	routes += "rust"
	hull.singularity_act()
	for(var/pull in 1 to 20)
		hull.wall_singularity_pull(STAGE_FIVE)
	routes += "a singularity"
	hull.narsie_act(TRUE, TRUE, 100)
	routes += "a god"
	for(var/hit in 1 to 20)
		hull.blob_act(null)
	routes += "a blob"
	for(var/hit in 1 to 20)
		hull.attack_hulk(vandal)
	routes += "a hulk"
	hull.drill_act(null, vandal)
	routes += "a mech drill"
	var/obj/item/weldingtool/welder = allocate(/obj/item/weldingtool)
	TEST_ASSERT(!hull.try_decon(welder, vandal), "A welder starts on the hull")
	routes += "a welder"
	var/obj/item/construction/rcd/rcd = allocate(/obj/item/construction/rcd)
	rcd.mode = RCD_DECONSTRUCT
	TEST_ASSERT(!hull.rcd_vals(vandal, rcd), "An RCD offers to take the hull down")
	TEST_ASSERT(!hull.rcd_act(vandal, rcd, list("[RCD_DESIGN_MODE]" = RCD_DECONSTRUCT)), "An RCD takes the hull down")
	routes += "an RCD"
	hull.atom_destruction(MELEE)
	routes += "being beaten down"
	TEST_ASSERT_EQUAL(hull.type, /turf/closed/wall/outpost_floor_hull, "The hull did not survive [english_list(routes)]")
	TEST_ASSERT_NULL(locate(/obj/structure/girder) in hull, "The hull left a girder")
	TEST_ASSERT_NULL(locate(/obj/item/stack/sheet) in hull, "The hull dropped sheets")

/// A real blast far bigger than the floor leaves every hull and deck tile as it was, and still breaks what a crew built (A3, L18, L28)
/datum/unit_test/voidcrew_outpost_floors/core/blast

/datum/unit_test/voidcrew_outpost_floors/core/blast/Run()
	var/obj/structure/overmap/trader_outpost/outpost = test_outpost()
	var/datum/outpost_floor/floor = test_floor(outpost, 1)
	if(!floor)
		return
	// The helper's box is laid on reserved space; a shell's link does this for a real floor
	floor.lay_ground(/turf/open/floor/plating/outpost_deck)
	hold_blasts()
	var/turf/epicenter = floor_tile(floor, 6, 6)
	var/turf/crew_wall = floor_tile(floor, 8, 6)
	var/turf/crew_tile = floor_tile(floor, 6, 8)
	var/list/ground = list()
	for(var/turf/tile as anything in block(floor.bounds[1], floor.bounds[2], floor.bounds[5], floor.bounds[3], floor.bounds[4], floor.bounds[5]))
		ground[tile] = tile.type
	var/was_reactionary = CONFIG_GET(flag/reactionary_explosions)
	for(var/reactionary in list(TRUE, FALSE))
		CONFIG_SET(flag/reactionary_explosions, reactionary)
		crew_wall.place_on_top(/turf/closed/wall)
		crew_tile.place_on_top(/turf/open/floor/iron)
		var/obj/structure/table/table = allocate(/obj/structure/table, floor_tile(floor, 5, 6))
		// Devastation over the whole 14 by 12 box, hull included
		explosion(epicenter, devastation_range = 20, heavy_impact_range = 25, light_impact_range = 30, flame_range = 0, flash_range = 0, adminlog = FALSE, ignorecap = TRUE, silent = TRUE)
		var/list/turf/hit_turfs = blasted_turfs()
		var/hull_hit = 0
		for(var/turf/hit as anything in hit_turfs)
			if(istype(hit, /turf/closed/wall/outpost_floor_hull))
				hull_hit++
		apply_blast()
		CONFIG_SET(flag/reactionary_explosions, was_reactionary)
		TEST_ASSERT(length(hit_turfs) > 0, "The bomb did not go off (reactionary [reactionary])")
		if(!reactionary)
			TEST_ASSERT(hull_hit > 0, "The blast never reached the hull, so the hull was not tried")
		TEST_ASSERT(!istype(crew_wall, /turf/closed/wall), "A blast on a floor left a crew wall standing (L18, reactionary [reactionary])")
		TEST_ASSERT(QDELETED(table) || table.get_integrity() < table.max_integrity, "A blast on a floor left a table beside the bomb untouched (reactionary [reactionary])")
		for(var/turf/tile as anything in ground)
			if(tile.type != ground[tile])
				TEST_FAIL("A blast changed the floor's own ground at [tile.x - floor.bounds[1]],[tile.y - floor.bounds[2]] from [ground[tile]] to [tile.type] (A3, reactionary [reactionary])")
				return

/// A light fixture hangs on the hull (L29): the hull is a real wall for wall mounts
/datum/unit_test/voidcrew_outpost_floors/core/wall_mount

/datum/unit_test/voidcrew_outpost_floors/core/wall_mount/Run()
	var/obj/structure/overmap/trader_outpost/outpost = test_building()
	var/mob/living/carbon/human/owner = test_player("floorscoremount")
	var/datum/outpost_floor/floor = let_floor(outpost, owner)
	if(!floor)
		return
	var/turf/closed/wall/outpost_floor_hull/hull = shell_tile(floor, 0, 20)
	var/turf/beside = shell_tile(floor, 1, 20)
	owner.forceMove(beside)
	var/obj/item/wallframe/light_fixture/frame = allocate(/obj/item/wallframe/light_fixture, beside)
	owner.put_in_active_hand(frame)
	TEST_ASSERT(frame.try_build(hull, owner), "A light fixture frame will not go on the hull")
	hull.item_interaction(owner, frame, list())
	var/obj/structure/light_construct/fitting = locate() in beside
	TEST_ASSERT_NOTNULL(fitting, "A light fixture did not mount on the hull")
	TEST_ASSERT_EQUAL(fitting.dir, WEST, "The light fixture does not face the hull it hangs on")
	TEST_ASSERT_EQUAL(hull.type, /turf/closed/wall/outpost_floor_hull, "Hanging a light changed the hull")
	// And an RCD may hang one too, though it takes nothing down
	var/obj/item/construction/rcd/rcd = allocate(/obj/item/construction/rcd)
	rcd.mode = RCD_WALLFRAME
	TEST_ASSERT(hull.rcd_vals(owner, rcd), "An RCD will not hang a wall mount on the hull")

// ===== DELETION =====

/// Deleting a floor's host, or the floor, with people aboard: they are put in the lobby, the ground is freed and every ref is cleared (A10, A36)
/datum/unit_test/voidcrew_outpost_floors/core/delete_aboard

/datum/unit_test/voidcrew_outpost_floors/core/delete_aboard/Run()
	var/obj/structure/overmap/trader_outpost/outpost = test_building()
	var/datum/turf_reservation/lobby_ground = test_ground(5, 5)
	if(!lobby_ground)
		return
	var/turf/lobby_corner = lobby_ground.bottom_left_turfs[1]
	var/list/turf/lobby = block(lobby_corner.x + 1, lobby_corner.y + 1, lobby_corner.z, lobby_corner.x + 3, lobby_corner.y + 3, lobby_corner.z)
	for(var/turf/tile as anything in lobby)
		tile.ChangeTurf(/turf/open/floor/plating)
	outpost.lobby_alcove_turfs = lobby.Copy()

	var/mob/living/owner = test_player("floorscoredelete")
	var/mob/living/visitor = test_person(run_loc_floor_bottom_left)
	var/mob/living/stowaway = test_person(run_loc_floor_bottom_left)
	var/datum/outpost_floor/floor = let_floor(outpost, owner)
	if(!floor)
		return
	var/obj/structure/overmap/dynamic/player_outpost/floor/host = floor.host
	var/obj/machinery/outpost_elevator/panel = floor.panel
	var/datum/turf_reservation/ground = floor.reservation
	var/turf/deck = shell_tile(floor, 10, 20)
	owner.forceMove(deck)
	visitor.forceMove(shell_tile(floor, 22, 2))
	var/obj/structure/closet/locker = allocate(/obj/structure/closet, shell_tile(floor, 12, 20))
	stowaway.forceMove(locker)

	qdel(host)
	TEST_ASSERT(owner.loc in lobby, "Someone on a deleted floor's deck was not put in the lobby (A10)")
	TEST_ASSERT(visitor.loc in lobby, "Someone in a deleted floor's lift alcove was not put in the lobby")
	TEST_ASSERT(locker.loc in lobby, "A locker with someone in it was left on a deleted floor")
	TEST_ASSERT_EQUAL(stowaway.loc, locker, "Someone was tipped out of the locker they rode down in")
	TEST_ASSERT(QDELETED(ground), "A deleted floor kept its ground")
	TEST_ASSERT_NULL(floor.reservation, "A deleted floor still points at its ground")
	TEST_ASSERT_NULL(floor.bounds, "A deleted floor still has bounds")
	TEST_ASSERT_NULL(floor.host, "A deleted host is still its floor's")
	TEST_ASSERT_NULL(host.floor, "A deleted host still points at its floor")
	TEST_ASSERT_NULL(floor.panel, "A deleted floor still has its lift panel")
	TEST_ASSERT_NULL(panel.floor, "The lift panel still points at a floor with no ground")
	TEST_ASSERT_EQUAL(length(floor.alcove_turfs), 0, "A deleted floor still has a lift alcove")
	TEST_ASSERT_NULL(floor.landing_bounds, "A deleted floor still has a landing")
	TEST_ASSERT_NULL(get_outpost_floor_for_turf(deck), "A deleted floor is still found on its old ground")
	TEST_ASSERT_NULL(get_outpost_from_atom(deck), "A deleted floor's ground still has a host")
	TEST_ASSERT(!(host in GLOB.player_outposts), "A deleted floor host is still a player outpost")
	TEST_ASSERT_EQUAL(floor.state, "tenant", "A floor whose host was deleted is not unlet") // OUTPOST_FLOOR_STATE_TENANT
	TEST_ASSERT_NULL(floor.floor_name, "A floor whose host was deleted kept its name")
	TEST_ASSERT_EQUAL(outpost.floors[1], floor, "Deleting a host took its floor out of the outpost")
	TEST_ASSERT_NULL(floor_holder_denial(owner), "A deleted floor still counts against its owner")

	// The same floor is let again on fresh ground, and this time the floor itself is deleted, under warrant
	floor = let_floor(outpost, owner)
	if(!floor)
		return
	host = floor.host
	ground = floor.reservation
	owner.forceMove(shell_tile(floor, 10, 20))
	floor.warrant_in_force = TRUE
	floor.public_ground = TRUE
	floor.guests += owner.mind
	qdel(floor)
	TEST_ASSERT(owner.loc in lobby, "Someone on a deleted floor was not put in the lobby")
	TEST_ASSERT(QDELETED(host), "A deleted floor left its host")
	TEST_ASSERT(QDELETED(ground), "A deleted floor kept its ground")
	TEST_ASSERT_NULL(outpost.floors[1], "A deleted floor is still in its outpost's list")
	TEST_ASSERT(!(floor in GLOB.outpost_floors_on_ground), "A deleted floor is still in the list of floors with ground")
	TEST_ASSERT(!floor.warrant_in_force && !floor.public_ground, "A floor deleted under warrant is still ground of the law (A51)")
	TEST_ASSERT_NULL(floor.outpost, "A deleted floor still points at its outpost")
	TEST_ASSERT_EQUAL(length(floor.guests), 0, "A deleted floor kept its guest list")
