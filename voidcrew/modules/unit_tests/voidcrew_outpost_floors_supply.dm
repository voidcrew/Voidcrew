/**
 * Outpost floors (voidcrew/modules/trade_floors/): tests of package P13.
 * Owner: P13. Subtype /datum/unit_test/voidcrew_outpost_floors and use the helpers in
 * voidcrew_outpost_floors_helpers.dm (P0, frozen). Fork defines are included after the tests: write the literal
 * value with a comment naming the define. Pin other packages' outputs directly and never wait for an AI walk.
 *
 * The floor's own people are pinned as its owner: host.founder_ckey and a person with that key. The goods lift's
 * tiles are four deck tiles east of the test box's landing; the shell link (P1) sets them on a real floor.
 */

/// An RCD that does its real work without the wait
/obj/item/construction/rcd/loaded/floor_supply_test

/obj/item/construction/rcd/loaded/floor_supply_test/build_delay(mob/user, delay, atom/target)
	return TRUE

/// A person at `where` playing as `player_key`
/datum/unit_test/voidcrew_outpost_floors/proc/supply_person(turf/where, player_key)
	var/mob/living/carbon/human/person = test_person(where)
	person.key = player_key
	person.mind_initialize()
	return person

/**
 * Gives `floor` (made with a host) an owner, a goods lift of four tiles, a treasury holding `balance` and the
 * floor's own freight, which it returns. P1's ensure_home_services() makes that freight on a real floor; it is
 * pinned here so these tests do not lean on that.
 */
/datum/unit_test/voidcrew_outpost_floors/proc/supply_freight(datum/outpost_floor/floor, owner_key, balance)
	var/obj/structure/overmap/dynamic/player_outpost/floor/host = floor.host
	host.founder_ckey = owner_key
	floor.goods_turfs = list(floor_tile(floor, 9, 1), floor_tile(floor, 10, 1), floor_tile(floor, 11, 1), floor_tile(floor, 12, 1))
	host.ensure_home_services()
	if(!istype(host.freight, /datum/voidcrew_cargo_shuttle/outpost/floor))
		QDEL_NULL(host.freight)
		host.freight = new /datum/voidcrew_cargo_shuttle/outpost/floor(host)
	host.treasury.account_balance = balance
	return host.freight

/// Puts `amount` orders of `pack` in the floor's cart and returns them
/datum/unit_test/voidcrew_outpost_floors/proc/supply_orders(datum/outpost_floor/floor, datum/supply_pack/pack, amount)
	var/list/datum/supply_order/orders = list()
	for(var/count in 1 to amount)
		var/datum/supply_order/order = new(pack)
		order.manifest_can_fail = FALSE
		floor.host.cargo_cart += order
		orders += order
	return orders

/// How many crates and lockers stand on the floor's goods lift
/datum/unit_test/voidcrew_outpost_floors/proc/supply_crates_on_lift(datum/outpost_floor/floor)
	var/count = 0
	for(var/turf/tile as anything in floor.goods_turfs)
		for(var/obj/structure/closet/crate in tile)
			count++
	return count

/// Takes every crate off the floor's goods lift
/datum/unit_test/voidcrew_outpost_floors/proc/supply_clear_lift(datum/outpost_floor/floor)
	for(var/turf/tile as anything in floor.goods_turfs)
		for(var/obj/structure/closet/crate in tile)
			qdel(crate)

/// An order pays the treasury and lands four crates on the goods lift; a fifth waits for the next delivery (L30, A84)
/datum/unit_test/voidcrew_outpost_floors/supply_delivery
	/// SSeconomy's import total as it was
	var/saved_imports

/datum/unit_test/voidcrew_outpost_floors/supply_delivery/Destroy()
	if(!isnull(saved_imports))
		SSeconomy.import_total = saved_imports
	return ..()

/datum/unit_test/voidcrew_outpost_floors/supply_delivery/Run()
	saved_imports = SSeconomy.import_total
	var/obj/structure/overmap/trader_outpost/outpost = test_outpost()
	var/datum/outpost_floor/floor = test_floor(outpost, 1, 14, 12, TRUE)
	if(!floor)
		return
	var/datum/voidcrew_cargo_shuttle/outpost/floor/lift = supply_freight(floor, "floorsupplyowner", 10000)
	var/obj/structure/overmap/dynamic/player_outpost/floor/host = floor.host
	var/datum/bank_account/treasury = host.treasury
	var/obj/structure/outpost_goods_lift/hatch = allocate(/obj/structure/outpost_goods_lift, floor.goods_turfs[1])
	TEST_ASSERT(HAS_TRAIT(hatch, "outpost_property"), "The goods lift's hatch is not outpost property") // TRAIT_OUTPOST_PROPERTY
	TEST_ASSERT(!hatch.density, "The goods lift's hatch blocks the tile its crate arrives on")
	TEST_ASSERT(hatch.resistance_flags & INDESTRUCTIBLE, "The goods lift's hatch can be broken")

	TEST_ASSERT_EQUAL(lift.call_shuttle(), "No orders in cart", "The goods lift started with nothing ordered")
	var/datum/supply_pack/pack = allocate(/datum/supply_pack/outpost_fitout/lighting)
	var/list/datum/supply_order/orders = supply_orders(floor, pack, 5)
	var/datum/supply_order/fifth = orders[5]
	var/price = fifth.get_final_cost()
	TEST_ASSERT(price > 0, "The test order is free")

	TEST_ASSERT_NULL(lift.call_shuttle(), "A floor's supply order was refused")
	TEST_ASSERT_EQUAL(treasury.account_balance, 10000 - 4 * price, "The order did not charge the treasury for four crates")
	TEST_ASSERT_NULL(fifth.ship_paid_cost, "The fifth order was paid for with the first four")
	TEST_ASSERT_EQUAL(lift.state, 1, "The goods lift is not on its way") // CARGO_SHUTTLE_ARRIVING
	var/wait = lift.get_remaining_time()
	TEST_ASSERT(wait > 40 && wait <= 45, "The goods lift takes [wait] seconds, not 45") // OUTPOST_FLOOR_GOODS_TIME
	TEST_ASSERT_NOTNULL(lift.call_shuttle(), "A second delivery started while one was on its way")
	TEST_ASSERT_EQUAL(treasury.account_balance, 10000 - 4 * price, "A refused second delivery charged the treasury")
	TEST_ASSERT_EQUAL(supply_crates_on_lift(floor), 0, "Crates stood on the goods lift before it came up")

	deltimer(lift.warmup_timer)
	TEST_ASSERT(lift.complete_arrival(), "The goods lift brought nothing up")
	for(var/turf/tile as anything in floor.goods_turfs)
		var/crates_here = 0
		for(var/obj/structure/closet/crate/crate in tile)
			crates_here++
			TEST_ASSERT(!crate.locked, "An ordered crate arrived locked")
			TEST_ASSERT_NOTNULL(locate(/obj/item/wallframe/light_fixture) in crate, "An ordered crate arrived without its goods")
		TEST_ASSERT_EQUAL(crates_here, 1, "A goods lift tile holds [crates_here] crates after a delivery of four")
	TEST_ASSERT_EQUAL(lift.state, 0, "The goods lift did not go back down") // CARGO_SHUTTLE_AWAY
	TEST_ASSERT_EQUAL(length(host.cargo_cart), 1, "The cart holds [length(host.cargo_cart)] orders after four of five came up")
	TEST_ASSERT(fifth in host.cargo_cart, "The fifth order was lost")
	TEST_ASSERT_EQUAL(treasury.account_balance, 10000 - 4 * price, "The delivery changed what the treasury had paid")

	// A delivery is refused while a crate stands there, and nothing is ever sent back down
	TEST_ASSERT_EQUAL(lift.call_shuttle(), "Clear the goods lift", "A delivery was taken with crates still on the goods lift")
	TEST_ASSERT_EQUAL(treasury.account_balance, 10000 - 4 * price, "A refused delivery charged the treasury")
	TEST_ASSERT(!lift.send_shuttle(), "A floor's freight can be sent away")
	TEST_ASSERT(!lift.complete_departure(), "A floor's freight exports")
	TEST_ASSERT_NULL(lift.shuttle_port, "A floor's freight has a ferry")

	supply_clear_lift(floor)
	TEST_ASSERT_NULL(lift.call_shuttle(), "The waiting order was refused on a clear goods lift")
	TEST_ASSERT_EQUAL(treasury.account_balance, 10000 - 5 * price, "The fifth order did not charge the treasury")
	deltimer(lift.warmup_timer)
	TEST_ASSERT(lift.complete_arrival(), "The fifth order never came up")
	TEST_ASSERT_EQUAL(supply_crates_on_lift(floor), 1, "The fifth order did not land one crate")
	TEST_ASSERT_EQUAL(length(host.cargo_cart), 0, "A delivered order stayed in the cart")

/// A delivery waits while a crate stands on the goods lift, paid for and untouched, and lands when it is clear (A84)
/datum/unit_test/voidcrew_outpost_floors/supply_lift_held
	/// SSeconomy's import total as it was
	var/saved_imports

/datum/unit_test/voidcrew_outpost_floors/supply_lift_held/Destroy()
	if(!isnull(saved_imports))
		SSeconomy.import_total = saved_imports
	return ..()

/datum/unit_test/voidcrew_outpost_floors/supply_lift_held/Run()
	saved_imports = SSeconomy.import_total
	var/obj/structure/overmap/trader_outpost/outpost = test_outpost()
	var/datum/outpost_floor/floor = test_floor(outpost, 1, 14, 12, TRUE)
	if(!floor)
		return
	var/datum/voidcrew_cargo_shuttle/outpost/floor/lift = supply_freight(floor, "floorheldowner", 5000)
	var/obj/structure/overmap/dynamic/player_outpost/floor/host = floor.host
	var/datum/bank_account/treasury = host.treasury
	var/obj/machinery/computer/voidcrew_cargo/console = allocate(/obj/machinery/computer/voidcrew_cargo, deck_tile(floor, 2))
	TEST_ASSERT_EQUAL(console.cargo_account(), treasury, "A supply console on a floor does not pay from the floor's treasury")
	TEST_ASSERT_EQUAL(console.get_cargo_shuttle(), lift, "A supply console on a floor does not order by the goods lift")
	TEST_ASSERT_NULL(console.get_shuttle_error_message(), "A floor's supply console refuses orders with a clear goods lift")

	var/datum/supply_pack/pack = allocate(/datum/supply_pack/outpost_fitout/signwriter)
	var/list/datum/supply_order/orders = supply_orders(floor, pack, 1)
	var/datum/supply_order/order = orders[1]
	var/price = order.get_final_cost()
	TEST_ASSERT_NULL(lift.call_shuttle(), "A floor's supply order was refused")

	// Somebody shoves a crate onto the lift while the order is on its way
	var/obj/structure/closet/crate/stray = allocate(/obj/structure/closet/crate, floor.goods_turfs[2])
	deltimer(lift.warmup_timer)
	TEST_ASSERT(!lift.complete_arrival(), "A delivery came up onto a goods lift with a crate on it")
	TEST_ASSERT_EQUAL(supply_crates_on_lift(floor), 1, "A held delivery put a crate on the goods lift")
	TEST_ASSERT_EQUAL(lift.state, 1, "A held delivery was dropped") // CARGO_SHUTTLE_ARRIVING
	TEST_ASSERT_EQUAL(order.ship_paid_cost, price, "A held delivery was refunded")
	TEST_ASSERT_EQUAL(treasury.account_balance, 5000 - price, "A held delivery changed the treasury")
	TEST_ASSERT_NOTNULL(lift.warmup_timer, "A held delivery will never look at the goods lift again")
	TEST_ASSERT_EQUAL(console.get_shuttle_error_message(), "Clear the goods lift", "The supply console does not say why the delivery waits")
	TEST_ASSERT(!lift.check_stalled(), "A delivery waiting for a clear goods lift was thrown away as stalled")

	stray.forceMove(deck_tile(floor, 3))
	deltimer(lift.warmup_timer)
	TEST_ASSERT(lift.complete_arrival(), "The held delivery did not come up once the goods lift was clear")
	TEST_ASSERT_EQUAL(supply_crates_on_lift(floor), 1, "The held delivery did not land its one crate")
	TEST_ASSERT_EQUAL(treasury.account_balance, 5000 - price, "The held delivery was charged twice or refunded")
	TEST_ASSERT_EQUAL(length(host.cargo_cart), 0, "A delivered order stayed in the cart")

/// What is paid for and has not come up is refunded exactly when the floor is given up, and when it is deleted
/datum/unit_test/voidcrew_outpost_floors/supply_refund

/datum/unit_test/voidcrew_outpost_floors/supply_refund/Run()
	var/obj/structure/overmap/trader_outpost/outpost = test_outpost()
	var/datum/outpost_floor/floor = test_floor(outpost, 1, 14, 12, TRUE)
	if(!floor)
		return
	var/datum/voidcrew_cargo_shuttle/outpost/floor/lift = supply_freight(floor, "floorrefundowner", 3000)
	var/obj/structure/overmap/dynamic/player_outpost/floor/host = floor.host
	var/datum/bank_account/treasury = host.treasury
	var/datum/supply_pack/pack = allocate(/datum/supply_pack/outpost_fitout/decorator)
	var/list/datum/supply_order/orders = supply_orders(floor, pack, 2)
	var/datum/supply_order/first = orders[1]
	var/price = first.get_final_cost()

	// Given up with an order on its way: abandon() calls cancel_pending() and clears the owner (player_outpost.dm)
	TEST_ASSERT_NULL(lift.call_shuttle(), "A floor's supply order was refused")
	TEST_ASSERT_EQUAL(treasury.account_balance, 3000 - 2 * price, "The order did not charge the treasury")
	lift.cancel_pending()
	host.founder_ckey = null
	TEST_ASSERT_EQUAL(treasury.account_balance, 3000, "Giving a floor up did not refund the order on its way")
	deltimer(lift.warmup_timer)
	TEST_ASSERT(!lift.complete_arrival(), "A refunded order came up the goods lift")
	TEST_ASSERT_EQUAL(supply_crates_on_lift(floor), 0, "A refunded order left a crate on the goods lift")
	TEST_ASSERT_EQUAL(lift.state, 0, "The goods lift is still on its way after a refund") // CARGO_SHUTTLE_AWAY
	TEST_ASSERT_EQUAL(length(host.cargo_cart), 2, "A refunded order left the cart")
	TEST_ASSERT_NULL(first.ship_paid_cost, "A refunded order is still marked paid")
	TEST_ASSERT_NOTNULL(lift.call_shuttle(), "A floor nobody holds took a supply order")
	TEST_ASSERT_EQUAL(treasury.account_balance, 3000, "A refused order charged the treasury")

	// The floor goes first: nothing comes up, and the treasury is made whole before it goes
	host.founder_ckey = "floorrefundowner"
	TEST_ASSERT_NULL(lift.call_shuttle(), "A floor's second supply order was refused")
	TEST_ASSERT_EQUAL(treasury.account_balance, 3000 - 2 * price, "The second order did not charge the treasury")
	qdel(floor)
	TEST_ASSERT(QDELETED(lift), "A deleted floor left its freight behind")
	TEST_ASSERT_EQUAL(treasury.account_balance, 3000, "Deleting a floor did not refund the order on its way")
	TEST_ASSERT(!lift.complete_arrival(), "A deleted floor's order still came up")

/// Only a floor's people and named builders build, bolt down, lay cable or RCD on it, deconstruct included, and
/// nobody does on the hull, the landing or the goods lift (L29, A5, A77)
/datum/unit_test/voidcrew_outpost_floors/supply_build_rules

/datum/unit_test/voidcrew_outpost_floors/supply_build_rules/Run()
	var/obj/structure/overmap/trader_outpost/outpost = test_outpost()
	var/datum/outpost_floor/floor = test_floor(outpost, 1, 14, 12, TRUE)
	if(!floor)
		return
	supply_freight(floor, "floorbuildowner", 0)
	var/obj/structure/overmap/dynamic/player_outpost/floor/host = floor.host
	host.authorized_builder_ckeys |= "floorbuildhand"
	floor.entry_policy = "open" // OUTPOST_FLOOR_ENTRY_OPEN: the rule holds in every setting, and this is the one with strangers
	var/turf/deck = deck_tile(floor, 2)
	var/turf/landing = floor_tile(floor, 4, 2)
	var/turf/hull = floor_tile(floor, 0, 5)
	var/turf/goods = floor.goods_turfs[1]
	var/mob/living/carbon/human/owner = supply_person(deck, "floorbuildowner")
	var/mob/living/carbon/human/builder = supply_person(deck, "floorbuildhand")
	var/mob/living/carbon/human/visitor = test_person(deck)

	// The rule itself
	TEST_ASSERT(outpost_floor_build_allowed(owner, deck), "A floor's owner may not build on its deck")
	TEST_ASSERT(outpost_floor_build_allowed(builder, deck), "A named builder may not build on the deck")
	TEST_ASSERT(!outpost_floor_build_allowed(visitor, deck), "A visitor may build on somebody's floor")
	TEST_ASSERT(!outpost_floor_build_allowed(null, deck), "Nobody at all may build on somebody's floor")
	TEST_ASSERT(outpost_service_build_allowed(owner, deck), "The build guard refuses a floor's owner")
	TEST_ASSERT(!outpost_service_build_allowed(visitor, deck), "The build guard lets a visitor build on a floor")
	for(var/turf/outpost_ground as anything in list(landing, hull, goods))
		var/spot = "[outpost_ground.x - floor.bounds[1]], [outpost_ground.y - floor.bounds[2]]"
		TEST_ASSERT(!outpost_floor_build_allowed(owner, outpost_ground), "A floor's owner may build at [spot]: the landing, the hull and the goods lift are the outpost's")
		TEST_ASSERT(!outpost_service_build_allowed(owner, outpost_ground), "The build guard lets a floor's owner build at [spot], on the outpost's ground")
	TEST_ASSERT(outpost_floor_build_allowed(visitor, run_loc_floor_bottom_left), "Building is refused off any floor")
	host.founder_ckey = null
	TEST_ASSERT(!outpost_floor_build_allowed(owner, deck), "A floor nobody holds is still its last owner's to build on")
	host.founder_ckey = "floorbuildowner"

	// A girder (stack recipes ask about the builder's own tile)
	var/datum/stack_recipe/girder
	for(var/datum/stack_recipe/recipe in GLOB.metal_recipes)
		if(recipe.result_type == /obj/structure/girder)
			girder = recipe
			break
	TEST_ASSERT_NOTNULL(girder, "No girder recipe to test with")
	var/obj/item/stack/sheet/iron/sheets = allocate(/obj/item/stack/sheet/iron, deck, 10)
	TEST_ASSERT(!sheets.building_checks(visitor, girder, 1), "A visitor may build a girder on a floor")
	TEST_ASSERT(sheets.building_checks(owner, girder, 1), "A floor's owner may not build a girder on the deck")

	// Cable
	var/obj/item/stack/cable_coil/coil = allocate(/obj/item/stack/cable_coil, deck)
	coil.place_turf(deck, visitor)
	TEST_ASSERT_NULL(locate(/obj/structure/cable) in deck, "A visitor laid cable on a floor")
	coil.place_turf(deck, owner)
	TEST_ASSERT_NOTNULL(locate(/obj/structure/cable) in deck, "A floor's owner could not lay cable on the deck")

	// A wrench: bolting down is building, unbolting is not
	var/turf/bench = deck_tile(floor, 4)
	var/obj/item/wrench/wrench = allocate(/obj/item/wrench, bench)
	var/obj/structure/frame/computer/frame = allocate(/obj/structure/frame/computer, bench)
	frame.set_anchored(FALSE)
	TEST_ASSERT_EQUAL(frame.default_unfasten_wrench(visitor, wrench, 0), FAILED_UNFASTEN, "A visitor's wrench was not turned away")
	TEST_ASSERT(!frame.anchored, "A visitor bolted something down on a floor")
	TEST_ASSERT_EQUAL(frame.default_unfasten_wrench(owner, wrench, 0), SUCCESSFUL_UNFASTEN, "A floor's owner could not bolt a frame to the deck")
	TEST_ASSERT(frame.anchored, "The owner's frame is not bolted down")
	TEST_ASSERT_EQUAL(frame.default_unfasten_wrench(visitor, wrench, 0), SUCCESSFUL_UNFASTEN, "Unbolting was refused: tools are not building")
	frame.forceMove(landing)
	TEST_ASSERT_EQUAL(frame.default_unfasten_wrench(owner, wrench, 0), FAILED_UNFASTEN, "A floor's owner bolted something down on the landing")
	frame.forceMove(goods)
	TEST_ASSERT_EQUAL(frame.default_unfasten_wrench(owner, wrench, 0), FAILED_UNFASTEN, "A floor's owner bolted something down on the goods lift")
	TEST_ASSERT(!frame.anchored, "Something is bolted to the outpost's ground")
	frame.forceMove(run_loc_floor_bottom_left)
	TEST_ASSERT_EQUAL(frame.default_unfasten_wrench(visitor, wrench, 0), SUCCESSFUL_UNFASTEN, "A wrench bolts nothing down off a floor any more")

	// An RCD, building and taking apart
	var/turf/site = deck_tile(floor, 6)
	var/obj/item/construction/rcd/loaded/floor_supply_test/rcd = allocate(/obj/item/construction/rcd/loaded/floor_supply_test, deck)
	rcd.mode = RCD_STRUCTURE
	rcd.rcd_design_path = /obj/structure/chair/stool/bar
	TEST_ASSERT_EQUAL(rcd.rcd_create(site, visitor), ITEM_INTERACT_BLOCKING, "A visitor's RCD was not turned away")
	TEST_ASSERT_NULL(locate(/obj/structure/chair/stool/bar) in site, "A visitor's RCD built on a floor")
	rcd.rcd_create(site, owner)
	var/obj/structure/chair/stool/bar/stool = locate() in site
	TEST_ASSERT_NOTNULL(stool, "A floor's owner could not build with an RCD on the deck")
	rcd.mode = RCD_DECONSTRUCT
	TEST_ASSERT_EQUAL(rcd.rcd_create(stool, visitor), ITEM_INTERACT_BLOCKING, "A visitor's RCD was not turned away from taking a floor apart")
	TEST_ASSERT(!QDELETED(stool), "A visitor's RCD took a floor's furniture apart")
	TEST_ASSERT_EQUAL(rcd.rcd_create(site, visitor), ITEM_INTERACT_BLOCKING, "A visitor's RCD was not turned away from the deck")

/**
 * Nothing is built on the landing or the goods lift, by the floor's owner either (A5). The RCD seam in
 * outpost_construction.dm lets through anyone can_build() names after the build guard has said no. Until that
 * seam asks outpost_floor_build_allowed() again, or those tiles refuse an RCD by their own type, this fails.
 */
/datum/unit_test/voidcrew_outpost_floors/supply_landing_rcd

/datum/unit_test/voidcrew_outpost_floors/supply_landing_rcd/Run()
	var/obj/structure/overmap/trader_outpost/outpost = test_outpost()
	var/datum/outpost_floor/floor = test_floor(outpost, 1, 14, 12, TRUE)
	if(!floor)
		return
	supply_freight(floor, "floorlandingowner", 0)
	var/mob/living/carbon/human/owner = supply_person(deck_tile(floor, 2), "floorlandingowner")
	var/obj/item/construction/rcd/loaded/floor_supply_test/rcd = allocate(/obj/item/construction/rcd/loaded/floor_supply_test, deck_tile(floor, 2))
	rcd.mode = RCD_STRUCTURE
	rcd.rcd_design_path = /obj/structure/chair/stool/bar
	for(var/turf/outpost_ground as anything in list(floor_tile(floor, 4, 2), floor.goods_turfs[1]))
		var/spot = "[outpost_ground.x - floor.bounds[1]], [outpost_ground.y - floor.bounds[2]]"
		rcd.rcd_create(outpost_ground, owner)
		TEST_ASSERT_NULL(locate(/obj/structure/chair/stool/bar) in outpost_ground, "A floor's owner built with an RCD on the outpost's ground at [spot]")

/// tg's own decorating works on a floor: a decal and paint on the deck, paint, a sign and a light on the hull (3b.1)
/datum/unit_test/voidcrew_outpost_floors/supply_decor

/datum/unit_test/voidcrew_outpost_floors/supply_decor/Run()
	var/obj/structure/overmap/trader_outpost/outpost = test_outpost()
	var/datum/outpost_floor/floor = test_floor(outpost, 1, 14, 12, TRUE)
	if(!floor)
		return
	supply_freight(floor, "floordecorowner", 0)
	// One tile in from the west hull, so the hull is in reach
	var/turf/stand = floor_tile(floor, 1, 5)
	var/turf/deck = floor_tile(floor, 2, 5)
	var/turf/hull = floor_tile(floor, 0, 5)
	var/mob/living/carbon/human/owner = supply_person(stand, "floordecorowner")
	TEST_ASSERT(isfloorturf(deck) && iswallturf(hull), "The test floor's deck and hull are not a floor and a wall")

	var/obj/item/airlock_painter/decal/painter = allocate(/obj/item/airlock_painter/decal, stand)
	TEST_ASSERT_EQUAL(painter.interact_with_atom(deck, owner, list()), ITEM_INTERACT_SUCCESS, "A decal painter does nothing on the deck")

	var/obj/item/paint/red/bucket = allocate(/obj/item/paint/red, stand)
	var/paint = bucket.paintleft
	TEST_ASSERT_EQUAL(bucket.interact_with_atom(deck, owner, list()), ITEM_INTERACT_SUCCESS, "Paint does not take on the deck")
	TEST_ASSERT_EQUAL(bucket.interact_with_atom(hull, owner, list()), ITEM_INTERACT_SUCCESS, "Paint does not take on the hull")
	TEST_ASSERT_EQUAL(bucket.paintleft, paint - 2, "Painting the deck and the hull used no paint")

	var/obj/item/sign/backing = allocate(/obj/item/sign, stand)
	TEST_ASSERT_EQUAL(backing.interact_with_atom(hull, owner, list()), ITEM_INTERACT_SUCCESS, "A sign backing does not hang on the hull")
	TEST_ASSERT_NOTNULL(locate(/obj/structure/sign) in stand, "No sign hangs where one was fastened to the hull")

	// The RLD waits a second for each light, as it does in a player's hands
	var/obj/item/construction/rld/lighter = allocate(/obj/item/construction/rld, stand)
	TEST_ASSERT_EQUAL(lighter.interact_with_atom(hull, owner, list()), ITEM_INTERACT_SUCCESS, "An RLD hangs no light on the hull")
	TEST_ASSERT_NOTNULL(locate(/obj/machinery/light) in stand, "No light hangs where the RLD put one on the hull")
	TEST_ASSERT_EQUAL(lighter.interact_with_atom(deck, owner, list()), ITEM_INTERACT_SUCCESS, "An RLD sets no floor light in the deck")
	TEST_ASSERT_NOTNULL(locate(/obj/machinery/light/floor) in deck, "No floor light is set in the deck")

/// tg's restaurant portal stays shut on a floor: it opens no venue, and no robot customer ever comes out of it (L37, A86)
/datum/unit_test/voidcrew_outpost_floors/supply_portal_shut
	/// The restaurant venue, which the whole game shares
	var/datum/venue/venue
	/// Its portals and its customers as they were
	var/list/saved_portals
	var/list/saved_customers

/datum/unit_test/voidcrew_outpost_floors/supply_portal_shut/Destroy()
	if(venue)
		for(var/mob/living/basic/robot_customer/robot in venue.current_visitors)
			qdel(robot)
		if(venue.open)
			venue.close()
		if(saved_portals)
			venue.restaurant_portals = saved_portals
		if(saved_customers)
			venue.customer_types = saved_customers
	venue = null
	saved_portals = null
	saved_customers = null
	return ..()

/datum/unit_test/voidcrew_outpost_floors/supply_portal_shut/Run()
	var/obj/structure/overmap/trader_outpost/outpost = test_outpost()
	var/datum/outpost_floor/floor = test_floor(outpost, 1, 14, 12, TRUE)
	if(!floor)
		return
	supply_freight(floor, "floorportalowner", 0)
	var/turf/deck = deck_tile(floor, 2)
	var/mob/living/carbon/human/owner = supply_person(deck, "floorportalowner")
	var/obj/machinery/restaurant_portal/restaurant/upstairs = allocate(/obj/machinery/restaurant_portal/restaurant, deck)
	var/obj/machinery/restaurant_portal/restaurant/downstairs = allocate(/obj/machinery/restaurant_portal/restaurant, run_loc_floor_bottom_left)
	TEST_ASSERT_NOTNULL(upstairs.linked_venue, "The test portal has no venue")
	TEST_ASSERT(!upstairs.linked_venue.open, "The restaurant venue was open before the test")
	TEST_ASSERT(upstairs.on_outpost_floor() && !downstairs.on_outpost_floor(), "The test portals are not one on a floor and one off")
	// The venue is the whole game's: from here on it has this test's portals only, and Destroy() puts it back
	venue = upstairs.linked_venue
	saved_portals = venue.restaurant_portals
	saved_customers = venue.customer_types.Copy()
	venue.restaurant_portals = list(upstairs, downstairs)
	var/list/both = venue.restaurant_portals

	// A card that opens a venue anywhere else opens nothing on a floor
	var/obj/item/card/id/advanced/gold/captains_spare/card = allocate(/obj/item/card/id/advanced/gold/captains_spare, deck)
	TEST_ASSERT(owner.put_in_hands(card), "The owner could not hold the test card")
	upstairs.attack_hand(owner, list())
	TEST_ASSERT(!venue.open, "A restaurant portal on a floor opened its venue")
	downstairs.attack_hand(owner, list())
	TEST_ASSERT(venue.open, "The test card opens no venue off a floor either, so the check above proves nothing")

	// Open from somewhere else, every customer comes out of the portal that is not on a floor
	for(var/count in 1 to 4)
		venue.create_new_customer()
	TEST_ASSERT(venue.restaurant_portals == both && length(both) == 2, "The venue's list of portals changed while a customer arrived")
	var/arrived = 0
	for(var/mob/living/basic/robot_customer/robot in venue.current_visitors)
		arrived++
		TEST_ASSERT(!get_outpost_floor_for_turf(get_turf(robot)), "A robot customer arrived on a floor")
	TEST_ASSERT(arrived > 0, "No robot customer came out of a portal off the floor")

	// With the floor's portal the only one, nobody comes
	venue.restaurant_portals = list(upstairs)
	var/list/only_upstairs = venue.restaurant_portals
	venue.create_new_customer()
	TEST_ASSERT_EQUAL(length(venue.current_visitors), arrived, "A robot customer came out of a portal on a floor")
	TEST_ASSERT(venue.restaurant_portals == only_upstairs, "The venue lost its list of portals")

/// The fit-out crates are on the supply console, at a price no crate resale beats (spec 3b.2, 3b.4)
/datum/unit_test/voidcrew_outpost_floors/supply_fitout_packs

/datum/unit_test/voidcrew_outpost_floors/supply_fitout_packs/Run()
	var/obj/machinery/computer/voidcrew_cargo/console = allocate(/obj/machinery/computer/voidcrew_cargo)
	var/list/fitout = list(
		/datum/supply_pack/outpost_fitout/decorator,
		/datum/supply_pack/outpost_fitout/lighting,
		/datum/supply_pack/outpost_fitout/signwriter,
		/datum/supply_pack/outpost_fitout/shop_fittings,
		/datum/supply_pack/outpost_fitout/till,
		/datum/supply_pack/outpost_fitout/shelves,
		/datum/supply_pack/outpost_fitout/signs,
	)
	for(var/pack_type in fitout)
		var/datum/supply_pack/pack = SSshuttle.supply_packs[pack_type]
		TEST_ASSERT_NOTNULL(pack, "[pack_type] is not in the supply catalogue")
		TEST_ASSERT(console.can_order_pack(pack), "[pack_type] cannot be ordered at a supply console")
		TEST_ASSERT(pack.get_cost() >= CARGO_MINIMUM_COST, "[pack_type] costs less than its crate is worth")
		TEST_ASSERT(!pack.goody && !pack.contraband && !pack.hidden, "[pack_type] is not an ordinary crate")
		for(var/item_type in pack.contains)
			TEST_ASSERT(ispath(item_type, /obj/item), "[pack_type] holds [item_type], which is not an item")
	TEST_ASSERT_NULL(SSshuttle.supply_packs[/datum/supply_pack/outpost_fitout], "The fit-out crates' parent type is on sale")
	var/datum/supply_pack/fittings = SSshuttle.supply_packs[/datum/supply_pack/outpost_fitout/shop_fittings]
	TEST_ASSERT_EQUAL(fittings.contains[/obj/item/outpost_floor_kit/till], 1, "The shop fittings crate does not hold one till")
	TEST_ASSERT_EQUAL(fittings.contains[/obj/item/outpost_floor_kit/shelf], 4, "The shop fittings crate does not hold four shelves")
	TEST_ASSERT_EQUAL(fittings.contains[/obj/item/outpost_floor_kit/sign], 1, "The shop fittings crate does not hold one sign")
